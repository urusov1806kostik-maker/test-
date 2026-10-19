--!nocheck
-- Хэллоуин-обновление на сервере (мок-окружение):
--   кейс (одна награда, списание, шансы 15 наград), руны (надеть/снять/перенести), порталы,
--   очередь на 4 квадратах (хост, сложность, выход, отсчёт, один матч на всех),
--   матч на карте Haunted Hollow: все 8 врагов + босс сложности, союзники и их HP,
--   руны в бою (каждая 3-я / 5-я атака, ровно 60 с, ~30%), Halloween Coins за победу один раз.
local DIFF = ... or "Easy"
local M = require("./mock")
local E = require("./env")
local env = E.make()
local game = env.game
local RS = M.services.ReplicatedStorage
local V3 = M.Vector3

local events = {}
local counts = {}
M.log = function(name, payload)
	counts[name] = (counts[name] or 0) + 1
	if name == "Impact" or name == "Attack" or name == "EnemySpawn" or name == "Notify" then
		events[#events + 1] = { name, payload, M.now }
	end
end
M.raycast = function(origin)
	local map = M.workspace:FindFirstChild("VoidTDHalloweenMap")
	return { Instance = map.Ground.IslandTop, Position = V3.new(origin.X, 60, origin.Z) }
end

E.runInstaller()
local Config = env.require(RS.VoidTD.Config)
local PathUtil = env.require(RS.VoidTD.PathUtil)
assert(not table.find(Config.CaseOrder, "BloodMoon"), "Blood case must be removed from case menu")

local function char(pl)
	local m = M.newInstance("Model")
	m.Name = pl.Name
	local root = M.newInstance("Part")
	root.Name = "HumanoidRootPart"
	root.Parent = m
	m.PrimaryPart = root
	m.Parent = M.workspace
	pl.Character = m
	return root
end
local players, roots = {}, {}
for i = 1, 5 do
	players[i] = M.newPlayer("P" .. i, i)
	roots[i] = char(players[i])
end
E.load(game:GetService("ServerScriptService").VoidTDServer)()
M.runDue()
assert(M.workspace:FindFirstChild("VoidTDHalloween"), "island not built")
assert(M.workspace:FindFirstChild("VoidTDHalloweenMap"), "halloween map not built")
assert(M.workspace.VoidTDLobby:FindFirstChild("HalloweenGate"), "lobby portal not built")
assert(not M.workspace.VoidTDLobby.Zones:FindFirstChild("Case_BloodMoon"), "Blood case must be removed from lobby")
local SSS = game:GetService("ServerScriptService").VoidTDServer
local GS = env.require(SSS.GameService)
local DS = env.require(SSS.DataService)
local State = RS.VoidTD.State
local request = RS.VoidTD.Remotes.Request
local function req(pl, action, data)
	return rawget(request, "_props").OnServerInvoke(pl, action, data)
end
local RunService = M.services.RunService
local function advance(sec, dt)
	dt = dt or 1 / 20
	local t1 = M.now + sec
	while M.now < t1 do
		M.now = M.now + dt
		M.runDue()
		RunService.Heartbeat:Fire(dt)
	end
end

------------------------------------------------------------------------
-- 1. КЕЙС
------------------------------------------------------------------------
local p1 = players[1]
local prof1 = DS.Get(p1)
local okNo = req(p1, "Summon", { Case = "Halloween", Count = 1 })
assert(not okNo, "no coins -> must fail")
assert(prof1.HalloweenCoins == 0, "no charge on fail")
prof1.HalloweenCoins = 1200
assert(not req(p1, "Summon", { Case = "Halloween", Count = 10 }), "x10 not allowed")
assert(prof1.HalloweenCoins == 1200, "x10 must not charge")
local ok1, res = req(p1, "Summon", { Case = "Halloween", Count = 1 })
assert(ok1 and #res == 1, "one reward per open")
assert(prof1.HalloweenCoins == 700, "charged exactly 500")
assert(not req(p1, "Summon", { Case = "BloodMoon", Count = 1 }), "Blood case disabled")
-- шансы
local total = 0
for _, r in ipairs(Config.Cases.Halloween.Rewards) do total = total + r.Rate end
assert(math.abs(total - 100) < 1e-6, "rates must sum to 100, got " .. total)
local N = 200000
local freq = {}
prof1.HalloweenCoins = 500 * N
for i = 1, N do
	local ok, r = DS.Summon(p1, "Halloween", 1)
	assert(ok)
	local key = r[1].Rune or r[1].Id
	freq[key] = (freq[key] or 0) + 1
end
assert(prof1.HalloweenCoins == 0, "each open charges once")
for _, r in ipairs(Config.Cases.Halloween.Rewards) do
	local key = r.Rune or r.Unit
	local got = (freq[key] or 0) / N * 100
	local sigma = math.sqrt(r.Rate / 100 * (1 - r.Rate / 100) / N) * 100
	print(string.format("  odds %-20s want %5.2f%% got %6.3f%%", key, r.Rate, got))
	assert(math.abs(got - r.Rate) < 5 * sigma + 0.01, "odds off for " .. key)
end
assert((prof1.Inventory.LanternKing or 0) > 0 and (prof1.Runes.PhantomCrown or 0) > 0, "rewards saved to inventory")

------------------------------------------------------------------------
-- 2. РУНЫ
------------------------------------------------------------------------
for _, pl in ipairs(players) do
	local prof = DS.Get(pl)
	for _, id in ipairs(Config.UnitOrder) do prof.Inventory[id] = 1 end
	prof.Runes = { LanternHeart = 1, CursedThreads = 1, PhantomCrown = 1 }
	prof.RuneSlots = {}
end
assert(req(p1, "EquipRune", { Unit = "NightWatchman", Rune = "LanternHeart" }))
assert(not req(p1, "EquipRune", { Unit = "Gravedigger", Rune = "LanternHeart" }), "only 1 copy -> second equip fails")
assert(req(p1, "EquipRune", { Unit = "NightWatchman", Rune = "PhantomCrown" }), "replace rune on same unit")
assert(DS.GetRune(p1, "NightWatchman") == "PhantomCrown")
assert(req(p1, "EquipRune", { Unit = "Gravedigger", Rune = "LanternHeart" }), "freed rune can move")
assert(req(p1, "EquipRune", { Unit = "Gravedigger" }) and DS.GetRune(p1, "Gravedigger") == nil, "remove rune")
assert(not req(p1, "EquipRune", { Unit = "Gravedigger", Rune = "Nope" }))

------------------------------------------------------------------------
-- 3. ПОРТАЛЫ
------------------------------------------------------------------------
local L, I = Config.Lobby, Config.HalloweenIsland
local function at(i, pos)
	roots[i].CFrame = M.CFrame.new(pos.X, pos.Y + 3, pos.Z)
end
at(1, L.Spawn)
assert(not req(p1, "Teleport", { To = "Halloween" }), "far from portal")
at(1, L.Center + L.Zones.HalloweenPortal.Offset)
assert(req(p1, "Teleport", { To = "Halloween" }), "portal teleport")
assert((roots[1].Position - I.Spawn).Magnitude < 8, "arrived on island")
at(1, I.Center + I.Zones.ReturnPortal.Offset)
assert(req(p1, "Teleport", { To = "Lobby" }) and (roots[1].Position - L.Spawn).Magnitude < 8, "return portal")

------------------------------------------------------------------------
-- 4. ОЧЕРЕДЬ
------------------------------------------------------------------------
local Q = I.Queue
local qc = I.Center + Q.Offset
for i = 1, 5 do
	at(i, I.Spawn)
end
at(1, qc + Q.Pads[1])
advance(0.6)
assert(State:GetAttribute("HQ_Count") == 1 and State:GetAttribute("HQ_Host") == 1, "host in queue")
at(2, qc + Q.Pads[2])
at(3, qc + Q.Pads[3])
advance(0.6)
assert(State:GetAttribute("HQ_Count") == 3, "3 in queue")
assert(not req(players[2], "QueueDifficulty", { Difficulty = "Hard" }), "only host picks difficulty")
assert(req(p1, "QueueDifficulty", { Difficulty = DIFF }))
assert(State:GetAttribute("HQ_Diff") == DIFF)
assert(req(players[3], "QueueLeave"), "leave queue")
advance(0.6)
assert(State:GetAttribute("HQ_Count") == 2, "left player removed and not re-added")
-- 5-й игрок занят в обычном матче — Хэллоуин ждёт свободной арены
assert(State:GetAttribute("HQ_At") > 0, "countdown running")
local loadout = { "NightWatchman", "Gravedigger", "PlagueDoctor", "DarkIllusionist", "HalloweenPuppeteer", "LanternKing" }
for _, pl in ipairs({ players[1], players[2] }) do
	for i, id in ipairs(loadout) do assert(req(pl, "Equip", { Unit = id, Slot = i })) end
end
assert(req(p1, "EquipRune", { Unit = "NightWatchman", Rune = "LanternHeart" }))
assert(req(p1, "EquipRune", { Unit = "Gravedigger", Rune = "CursedThreads" }))
assert(req(p1, "EquipRune", { Unit = "PlagueDoctor", Rune = "PhantomCrown" }))
assert(req(p1, "QueueStart"))
advance(Q.StartNow + 0.6)
assert(State:GetAttribute("Phase") == "Prep" and State:GetAttribute("Map") == "Halloween", "halloween match started")
assert(players[1]:GetAttribute("InMatch") and players[2]:GetAttribute("InMatch") and not players[3]:GetAttribute("InMatch"), "queue -> same match")
assert(State:GetAttribute("MaxWave") == 20 and State:GetAttribute("Difficulty") == DIFF)
assert(not req(players[4], "JoinMatch", { Difficulty = "Easy" }), "normal join blocked during halloween match")
advance(0.6)
assert((roots[1].Position - Config.Maps.Halloween.BattleSpawn).Magnitude < 8, "teleported to halloween map")

------------------------------------------------------------------------
-- 5. БОЙ
------------------------------------------------------------------------
local coinsBefore = { DS.Get(players[1]).HalloweenCoins, DS.Get(players[2]).HalloweenCoins }
local MC = Config.Maps.Halloween
local spots = {}
for x = -130, 130, 3 do
	for z = -100, 100, 3 do
		local pos = V3.new(MC.Center.X + x, 60, MC.Center.Z + z)
		if PathUtil.IsPlacementClear(pos) and PathUtil.DistanceToPath(pos) < 8 then
			local cover = 0
			for s = 0, PathUtil.Length, 2 do
				if PathUtil.FlatDistance(PathUtil.PositionAt(s), pos) < 12 then cover = cover + 1 end
			end
			spots[#spots + 1] = { pos = pos, cover = cover }
		end
	end
end
table.sort(spots, function(a, b) return a.cover > b.cover end)
local picked = {}
for _, s in ipairs(spots) do
	local okS = true
	for _, q in ipairs(picked) do if PathUtil.FlatDistance(q.pos, s.pos) < 8 then okS = false break end end
	if okS then picked[#picked + 1] = s end
end
spots = picked
assert(#spots > 20, "not enough spots on halloween map: " .. #spots)
local units = RS.VoidTD.Units
local used = 1
local priority = {
	{ 1, "NightWatchman" }, { 2, "NightWatchman" }, { 1, "Gravedigger" }, { 2, "Gravedigger" }, { 1, "NightWatchman" },
	{ 1, "PlagueDoctor" }, { 2, "DarkIllusionist" }, { 1, "HalloweenPuppeteer" }, { 2, "PlagueDoctor" },
	{ 1, "LanternKing" }, { 2, "HalloweenPuppeteer" }, { 1, "DarkIllusionist" }, { 2, "LanternKing" }, { 1, "PlagueDoctor" },
}
local pi = 1
local function spend()
	for _ = 1, 40 do
		local acted = false
		local step = priority[pi]
		if step then
			local pl = players[step[1]]
			if pl:GetAttribute("Money") >= Config.Units[step[2]].Levels[1].Cost then
				while used <= #spots do
					local s = spots[used]; used = used + 1
					if req(pl, "Place", { Unit = step[2], Position = s.pos, Rotation = 0 }) then pi = pi + 1; acted = true; break end
				end
			end
		end
		if not acted then
			for _, f in ipairs(units:GetChildren()) do
				local pl = players[f:GetAttribute("OwnerId")]
				local def = Config.Units[f:GetAttribute("UnitId")]
				local nx = def.Levels[f:GetAttribute("Level") + 1]
				local nextPlace = priority[pi] and Config.Units[priority[pi][2]].Levels[1].Cost or math.huge
				if nx and pl:GetAttribute("Money") >= nx.Cost and (nx.Cost < nextPlace * 0.4 or not priority[pi]) then
					if req(pl, "Upgrade", { Uid = tonumber(f.Name) }) then acted = true break end
				end
			end
		end
		if not acted then break end
	end
end
spend()
assert(req(p1, "StartWave"))
local dbg = GS.Debug()
local allyHurt, allySeen, allyDamaged = {}, {}, 0
local runeUnitPlaced
local t0 = M.now
while M.now - t0 < 60 * 90 do
	advance(0.5)
	for id, a in pairs(dbg.Allies()) do
		if not allySeen[id] then allySeen[id] = a.MaxHP end
		if a.HP < a.MaxHP and not allyHurt[id] then allyHurt[id] = true; allyDamaged = allyDamaged + 1 end
		assert(a.HP <= a.MaxHP and a.HP > 0, "ally hp range")
	end
	local phase = State:GetAttribute("Phase")
	if phase == "Intermission" then
		spend()
		req(p1, "StartWave")
		print(string.format("t=%5.0fs wave %2d cleared core=%3d money=%6d/%6d units=%d", M.now - t0, State:GetAttribute("Wave"), State:GetAttribute("CoreHP"), players[1]:GetAttribute("Money"), players[2]:GetAttribute("Money"), #units:GetChildren()))
	elseif phase == "Victory" or phase == "Defeat" then
		print("RESULT:", phase, "wave", State:GetAttribute("Wave"), "core", State:GetAttribute("CoreHP"), "difficulty", DIFF)
		break
	end
end
local result = State:GetAttribute("Phase")

-- статистика событий
local spawned, kinds, attacksBy, echo = {}, {}, {}, 0
local runeSummons = {}
for _, ev in ipairs(events) do
	local name, p, t = ev[1], ev[2], ev[3]
	if name == "EnemySpawn" then
		spawned[p[2]] = (spawned[p[2]] or 0) + 1
	elseif name == "Impact" then
		kinds[p.K] = (kinds[p.K] or 0) + 1
		if p.K == "CursedCircle" then
			runeSummons[#runeSummons + 1] = t
		end
	elseif name == "Attack" then
		attacksBy[p.U] = attacksBy[p.U] or { n = 0, ec = 0, ab = 0 }
		local a = attacksBy[p.U]
		if p.EC then a.ec = a.ec + 1 elseif p.AB then a.ab = a.ab + 1 else a.n = a.n + 1 end
	end
end
for _, id in ipairs({ "CursedDead", "PumpkinRunner", "PhantomWarrior", "BoneGuard", "LivingScarecrow", "StrawMinion", "FogWarlock", "PumpkinBrute", "NightReaper" }) do
	assert((spawned[id] or 0) > 0, "enemy never spawned: " .. id)
end
local boss = Config.Halloween.Bosses[DIFF]
assert((spawned[boss] or 0) > 0 or result == "Defeat", "boss " .. boss .. " never spawned")
for k, v in pairs(kinds) do print("  impact", k, v) end
for _, f in ipairs(units:GetChildren()) do
	local a = attacksBy[tonumber(f.Name)] or { n = 0, ec = 0, ab = 0 }
	print(string.format("  unit %-20s lv%d rune=%-13s dmg=%8d attacks=%d echo=%d abil=%d", f:GetAttribute("UnitId"), f:GetAttribute("Level"), tostring(f:GetAttribute("Rune")), f:GetAttribute("Damage"), a.n, a.ec, a.ab))
end
for _, k in ipairs({ "SummonPortal", "AllyHit", "LanternHeart", "CursedThreads", "PhantomEcho", "CursedCircle", "EnemyState", "Fog", "Straw" }) do
	assert((kinds[k] or 0) > 0, "never happened: " .. k)
end
local nAllies = 0
for _ in pairs(allySeen) do nAllies = nAllies + 1 end
print("allies spawned", nAllies, "damaged", allyDamaged)
assert(nAllies > 0 and allyDamaged > 0, "allies must take damage from enemies")
-- руна «Проклятые нити»: ровно каждые 60 с от установки
for i = 2, #runeSummons do
	assert(math.abs(runeSummons[i] - runeSummons[i - 1] - 60) < 0.06, "rune summon interval must be 60 s: " .. (runeSummons[i] - runeSummons[i - 1]))
end
print("rune summons", #runeSummons)
-- «Призрачная корона»: ~30% обычных атак повторяются
local cn, ce = 0, 0
for uid, a in pairs(attacksBy) do
	if a.ec > 0 then
		cn, ce = cn + a.n, ce + a.ec
	end
end
print(string.format("  crown: normal=%d echo=%d ratio=%.2f", cn, ce, ce / math.max(cn, 1)))
assert(cn > 40 and ce / cn > 0.2 and ce / cn < 0.4, "echo ratio ~30%")
-- состояния врагов и боссов
local states = {}
for _, ev in ipairs(events) do
	if ev[1] == "Impact" and ev[2].K == "EnemyState" then
		states[ev[2].S] = (states[ev[2].S] or 0) + 1
	end
end
for k, v in pairs(states) do print("  state", k, v) end
for _, k in ipairs({ "Phase", "Shield", "ArmorBreak" }) do
	assert(states[k], "enemy state never happened: " .. k)
end
if result == "Victory" and DIFF ~= "Easy" then
	assert(states.Enrage, "boss phase 2 never happened")
end
if result == "Victory" and DIFF == "Medium" then
	assert(states.Haste, "Fog Reaper haste never happened")
end
if result == "Victory" and DIFF == "Hard" then
	assert((kinds.Fire or 0) > 0, "Cursed Monarch must summon 2 Pumpkin Brutes")
end

-- награда: только за победу, каждому, один раз
advance(1)
local c1, c2 = DS.Get(players[1]).HalloweenCoins, DS.Get(players[2]).HalloweenCoins
if result == "Victory" then
	assert(c1 - coinsBefore[1] == Config.Halloween.Coins[DIFF] and c2 - coinsBefore[2] == Config.Halloween.Coins[DIFF], "coins for each participant")
else
	assert(c1 == coinsBefore[1] and c2 == coinsBefore[2], "no coins on defeat")
end
advance(Config.Settings.ResetDelay + 2)
assert(State:GetAttribute("Phase") == "Idle" and State:GetAttribute("Map") == "Void", "reset to void")
assert(DS.Get(players[1]).HalloweenCoins == c1, "victory not paid twice")
assert((roots[1].Position - I.Spawn).Magnitude < 8, "back to island after halloween match")
-- обычный матч работает как раньше
assert(req(players[4], "JoinMatch", { Difficulty = "Easy" }))
assert(State:GetAttribute("Map") == "Void" and State:GetAttribute("MaxWave") == Config.Settings.MaxWave)
assert(req(players[4], "LeaveMatch"))
print("HALLOWEEN TEST OK", result)
