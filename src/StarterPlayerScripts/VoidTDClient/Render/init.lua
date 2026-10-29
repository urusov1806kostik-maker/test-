--!nocheck
-- VOID TD :: Render — оркестратор отрисовки боя (клиент). Только картинка: урон и позиции считает сервер.
-- Дети: Enemies (враги), Units (юниты игроков), Allies (союзники-призывы на дороге).
--
-- API
--   Renderer.Init(ctx)
--   Renderer.SpawnEnemy(data) ; RemoveEnemy(id, reason) ; ClearEnemies()
--   Renderer.OnSync(p) ; OnAttack(p) ; OnImpact(p)
--   Renderer.AddUnit(folder, isNew) ; RemoveUnit(folder) ; RebuildUnits() ; Cheer()
--   Renderer.ClearAllies() ; Update(dt)
--   Renderer.EnemyViews / UnitViews / AllyViews ; EnemyCenter(id) ; EnemyPosition(id) ; MuzzlePos(view) ; ActiveMap()
--   Renderer.UnitFolder / EnemyFolder / AllyFolder ; хуки OnUnitChanged(uid), OnUnitRemoved(uid)
--   предпросмотр (окно юнита): PreviewStep(state, t), PreviewAttack(state, unitId, level),
--   PreviewAbility(state, name), PreviewFidget(state, unitId)

local Renderer = {}

local Enemies = require(script:WaitForChild("Enemies"))
local Units = require(script:WaitForChild("Units"))
local Allies = require(script:WaitForChild("Allies"))

local ctx, Config, Path, FX, Anims
local V = Vector3.new

Renderer.EnemyViews = Enemies.Views
Renderer.UnitViews = Units.Views
Renderer.AllyViews = Allies.Views

-- активная карта боя (по ключу Path)
function Renderer.ActiveMap()
	local name = (Path and Path.MapKey == "Halloween") and "VoidTDHalloweenMap" or "VoidTDMap"
	return workspace:FindFirstChild(name)
end

function Renderer.MuzzlePos(view)
	local rig = view and view.Rig
	if not rig then
		return nil
	end
	local m = rig.Muzzle
	if m and m.Parent then
		return m.Position
	end
	return rig.Root.Position + V(0, 1, 0)
end

Renderer.EnemyCenter = function(id)
	return Enemies.Center(id)
end
Renderer.EnemyPosition = function(id)
	return Enemies.Position(id)
end

------------------------------------------------------------------------
-- ВРАГИ
------------------------------------------------------------------------
function Renderer.SpawnEnemy(data)
	if type(data) ~= "table" then
		return
	end
	local ok, err = pcall(Enemies.Spawn, data)
	if not ok then
		warn("[VOID TD] SpawnEnemy: " .. tostring(err))
	end
end

function Renderer.RemoveEnemy(id, reason)
	Enemies.Remove(id, reason)
end

function Renderer.ClearEnemies()
	Enemies.Clear()
end

function Renderer.OnSync(p)
	if type(p) ~= "table" then
		return
	end
	if p.E then
		Enemies.Sync(p.E)
	end
	for _, d in ipairs(p.DMG or {}) do
		local pos = Enemies.Center(d[1])
		if pos then
			FX.DamageNumber(pos + V(0, 1.5, 0), d[2], d[3])
		end
	end
	for _, r in ipairs(p.RM or {}) do
		Enemies.Remove(r[1], r[2])
	end
	if p.AL or p.RA then
		Allies.Sync(p.AL, p.RA)
	end
end

------------------------------------------------------------------------
-- ЮНИТЫ
------------------------------------------------------------------------
function Renderer.AddUnit(folder, isNew)
	local ok, err = pcall(Units.Add, folder, isNew)
	if not ok then
		warn("[VOID TD] AddUnit: " .. tostring(err))
	end
end

function Renderer.RemoveUnit(folder)
	Units.Remove(folder)
end

function Renderer.RebuildUnits()
	Units.Rebuild()
end

function Renderer.Cheer()
	Units.Cheer()
end

function Renderer.OnAttack(p)
	if type(p) ~= "table" then
		return
	end
	local ok, err = pcall(Units.OnAttack, p)
	if not ok then
		warn("[VOID TD] Attack: " .. tostring(err))
	end
end

-- удары: все виды зарегистрированы в FX (ядро + Void/Chrono/Halloween)
function Renderer.OnImpact(p)
	if type(p) ~= "table" or typeof(p.P) ~= "Vector3" then
		return
	end
	FX.Impact(p)
end

------------------------------------------------------------------------
-- СОЮЗНИКИ
------------------------------------------------------------------------
function Renderer.ClearAllies()
	Allies.Clear()
end

------------------------------------------------------------------------
-- ПРЕДПРОСМОТР: те же позы, что в бою
------------------------------------------------------------------------
function Renderer.PreviewStep(state, t)
	if state and state.Rig then
		Anims.Apply(state.Rig, Anims.Eval(state, t), t, state.Phase or 0)
	end
end

function Renderer.PreviewAttack(state, unitId, level)
	local def = Config.Units[unitId]
	if not def or not state.Rig then
		return
	end
	local levels = def.Levels
	local st = levels[math.clamp(level or 1, 1, #levels)]
	Anims.Play(state, def.Anim, def.HitDelay or 0.2, st.Hits or 1, def.HitInterval)
end

-- способность: только анимация и ускоренные механизмы, без игровых эффектов
function Renderer.PreviewAbility(state, name)
	if state.Rig and Anims.Has(name) then
		Anims.Play(state, name)
		state.Rig.SpinBoostUntil = os.clock() + 2.2
	end
end

function Renderer.PreviewFidget(state, unitId)
	local def = Config.Units[unitId]
	if def and state.Rig then
		Anims.PlayFidget(state, def.Anim)
	end
end

------------------------------------------------------------------------
-- КАДР
------------------------------------------------------------------------
function Renderer.Update(dt)
	local t = os.clock()
	local cam = workspace.CurrentCamera
	local camPos = cam and cam.CFrame.Position or Vector3.zero
	Enemies.Update(t, dt, camPos)
	Units.Update(t, dt)
	Allies.Update(t, dt)
end

local function folder(name)
	local f = workspace:FindFirstChild(name)
	if f and f:IsA("Folder") then
		f:ClearAllChildren()
		return f
	end
	f = Instance.new("Folder")
	f.Name = name
	f.Parent = workspace
	return f
end

function Renderer.Init(c)
	ctx = c
	Config, Path, FX, Anims = c.Config, c.Path, c.FX, c.Anims
	Renderer.EnemyFolder = folder("VoidTD_Enemies")
	Renderer.UnitFolder = folder("VoidTD_Units")
	Renderer.AllyFolder = folder("VoidTD_Allies")
	Enemies.Init(Renderer, c)
	Units.Init(Renderer, c)
	Allies.Init(Renderer, c)
	return Renderer
end

return Renderer
