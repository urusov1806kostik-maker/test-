--!nocheck
-- VOID TD :: Sim
-- Ядро боя на сервере: враги, юниты, союзники, зоны, урон. Матч (Match) управляет фазами и вызывает Sim.Step.
-- Дочерние модули (Enemies Units Attacks Abilities Allies Runes) — `return function(Sim) ... end`,
-- добавляют свои функции в таблицу Sim и пользуются общим состоянием (Sim.enemies, Sim.units, ...).
--
-- API
--   Sim.Init({ Remotes, State, UnitsFolder, Maps = {Void, Halloween}, Data, Economy })
--   Sim.Configure({ D = difficulty, Mode = "Void"|"Halloween", Wave = n, Running = bool })
--   Sim.Clear()  Sim.ClearEnemies()  Sim.Step(t, dt, simulate?)
--   Sim.SpawnEnemy(typeId, startDist?, lateral?) -> e ; Sim.HasEnemies() ; Sim.EnemySnapshot()
--   Sim.PlaceUnit / UpgradeUnit / SellUnit / SetTargetMode / RemovePlayerUnits
--   Sim.Hooks.OnKill(e, reward), Sim.Hooks.OnCore(e, damage)   (ставит Match)
--   Sim.Debug() -> { Units, Enemies, Allies(), Spawn, Now }
-- Таблицы enemies/units/allies/zones никогда не пересоздаются (очистка на месте) — ссылки из Debug не устаревают.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("VoidTD")
local Config = require(Shared:WaitForChild("Config"))
local Path = require(Shared:WaitForChild("Path"))

local Sim = {}
Sim.Config = Config
Sim.Path = Path
Sim.S = Config.Settings
Sim.Hooks = {}
Sim.rng = Random.new()

-- состояние
Sim.enemies = {}   -- Id -> враг (только живые)
Sim.units = {}     -- Uid -> юнит
Sim.allies = {}    -- Id -> союзник
Sim.zones = {}     -- зоны урона (яд, чёрная дыра)
Sim.pending = {}   -- отложенные спавны { type, count, startDist, fxPos, fxKind }
Sim.dmgBuf = {}    -- { id, amount, flag }
Sim.rmBuf = {}     -- { id, reason }
Sim.allyRm = {}    -- { allyId, reason }
Sim.ids = { Enemy = 0, Unit = 0, Ally = 0 }
Sim.gen = 0        -- поколение матча: отложенные удары прошлого матча не срабатывают
Sim.D = Config.Difficulties.Medium
Sim.Mode = "Void"
Sim.Wave = 0
Sim.Running = false -- бой идёт (Prep / Wave / Intermission)
Sim.echo = false   -- true, пока синхронно выполняется повтор атаки «Призрачной короны»

local lastSync, lastFlush = 0, 0
local IDLE_SYNC = 1 -- вне боя пустой Sync не чаще раза в секунду

function Sim.now()
	return workspace:GetServerTimeNow()
end

function Sim.Impact(payload)
	Sim.Remotes.Impact:FireAllClients(payload)
end

function Sim.Attack(payload)
	Sim.Remotes.Attack:FireAllClients(payload)
end

-- юнит жив и матч тот же
function Sim.Valid(u, gen)
	return u.Alive and Sim.gen == gen
end

-- отложенный вызов с проверкой юнита и поколения
function Sim.Later(u, delay, fn)
	local gen = Sim.gen
	task.delay(delay, function()
		if Sim.Valid(u, gen) then
			fn()
		end
	end)
end

for _, name in ipairs({ "Enemies", "Allies", "Attacks", "Abilities", "Runes", "Units" }) do
	require(script:WaitForChild(name))(Sim)
end

function Sim.Init(ctx)
	Sim.Remotes = ctx.Remotes
	Sim.State = ctx.State
	Sim.UnitsFolder = ctx.UnitsFolder
	Sim.Maps = ctx.Maps or {}
	Sim.Data = ctx.Data
	Sim.Economy = ctx.Economy
end

function Sim.Configure(o)
	if o.D then
		Sim.D = o.D
	end
	if o.Mode and o.Mode ~= Sim.Mode then
		Sim.Mode = o.Mode
	end
	if o.Mode then
		Path.SetMap(o.Mode)
	end
	if o.Wave then
		Sim.Wave = o.Wave
	end
	if o.Running ~= nil then
		Sim.Running = o.Running
		if not o.Running then
			table.clear(Sim.pending)
		end
	end
end

-- всё убрать: враги ("clear"), юниты (их союзники — "sold"), сироты-союзники ("clear"), зоны
function Sim.Clear()
	Sim.gen += 1
	Sim.ClearEnemies()
	for _, u in pairs(Sim.units) do
		Sim.RemoveUnit(u)
	end
	table.clear(Sim.units)
	for _, a in pairs(Sim.allies) do
		Sim.RemoveAlly(a, "clear")
	end
	table.clear(Sim.allies)
	Sim.Wave = 0
end

local function sync(t)
	local al
	if next(Sim.allies) or #Sim.allyRm > 0 then
		al = Sim.AllySyncList()
	end
	Sim.Remotes.Sync:FireAllClients({
		T = t,
		E = Sim.EnemySyncList(t),
		DMG = Sim.dmgBuf,
		RM = Sim.rmBuf,
		AL = al,
		RA = #Sim.allyRm > 0 and Sim.allyRm or nil,
	})
	Sim.dmgBuf = {}
	Sim.rmBuf = {}
	Sim.allyRm = {}
end

-- simulate = false: бой стоит (Idle / Victory / Defeat), только рассылка
function Sim.Step(t, dt, simulate)
	if simulate == nil then
		simulate = Sim.Running
	end
	if simulate then
		Sim.UpdateEnemies(t, dt)
		Sim.UpdateAllies(t, dt)
		Sim.UpdateZones(t)
		Sim.UpdateDots(t)
		Sim.UpdateUnits(t)
	end
	local busy = simulate or next(Sim.enemies) or #Sim.dmgBuf > 0 or #Sim.rmBuf > 0 or #Sim.allyRm > 0
	if t - lastSync >= (busy and Sim.S.SyncRate or IDLE_SYNC) then
		lastSync = t
		sync(t)
	end
	if t - lastFlush >= 1 then
		lastFlush = t
		for _, u in pairs(Sim.units) do
			u.Folder:SetAttribute("Damage", math.floor(u.DamageDealt))
		end
	end
end

function Sim.Debug()
	return {
		Units = Sim.units,
		Enemies = Sim.enemies,
		Allies = function()
			return Sim.allies
		end,
		Zones = Sim.zones,
		Spawn = Sim.SpawnEnemy,
		Now = Sim.now,
	}
end

return Sim
