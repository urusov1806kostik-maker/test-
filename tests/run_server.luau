--!nocheck
local PRESET, DIFF = ...
PRESET = PRESET or "strong"
DIFF = DIFF or "Medium"
local M = require("./mock")
local E = require("./env")
local env = E.make()
local game = env.game
local RS = M.services.ReplicatedStorage

-- лог событий
local counts = {}
M.log = function(name, payload)
	counts[name] = (counts[name] or 0) + 1
	local function check(v, depth)
		local t = M.typeof(v)
		if t == "function" or t == "thread" then error("non-serializable value in " .. name) end
		if t == "table" and depth < 6 then for k, x in pairs(v) do check(x, depth + 1) end end
	end
	check(payload, 0)
end

local GY
M.raycast = function(origin, dir, params)
	local map = M.workspace:FindFirstChild("VoidTDMap")
	local top = map.Ground.IslandTop
	return { Instance = top, Position = M.Vector3.new(origin.X, 60, origin.Z) }
end

E.runInstaller()
print("installed; parts:", M.partCount)
assert(M.workspace:FindFirstChild("VoidTDMap"), "map not built")

-- unit model build test (all units, all levels) + enemies
local UnitModels = env.require(RS.VoidTD.UnitModels)
local EnemyModels = env.require(RS.VoidTD.EnemyModels)
local Config = env.require(RS.VoidTD.Config)
for _, id in ipairs(Config.UnitOrder) do
	for lv = 1, 5 do
		local before = M.partCount
		local rig = UnitModels.Build(id, lv)
		assert(rig.Muzzle, id .. " no muzzle")
		assert(rig.Motors.RS and rig.Base.RS, id .. " no RS")
		if lv == 1 or lv == 5 then print(string.format("  unit %-18s lv%d parts=%d scale=%.2f", id, lv, M.partCount - before, rig.Scale)) end
	end
end
for _, id in ipairs(Config.EnemyOrder) do
	local before = M.partCount
	local rig = EnemyModels.Build(id)
	assert(rig.Style and rig.HipHeight and rig.Height, id .. " missing info")
	print(string.format("  enemy %-16s parts=%d style=%s hip=%.1f h=%.1f", id, M.partCount - before, rig.Style, rig.HipHeight, rig.Height))
end

-- игрок и сервер
local player = M.newPlayer("Tester", 1)
local serverScript = game:GetService("ServerScriptService").VoidTDServer
E.load(serverScript)()
M.runDue()
local Remotes = RS.VoidTD.Remotes
local request = Remotes.Request
local function req(action, data)
	return rawget(request, "_props").OnServerInvoke(player, action, data)
end
assert(player:GetAttribute("VoidReady"), "player not ready")
local ok, prof = req("GetProfile")
assert(ok and prof, "no profile")
print("profile gems", prof.Gems, "equipped", prof.Equipped["1"], prof.Equipped["2"], prof.Equipped["3"])

-- summon test
local ok1, res1 = req("Summon", { Count = 10 })
print("summon x10:", ok1, res1 and #res1)

-- выдаём все юниты для теста
local DS = env.require(game:GetService("ServerScriptService").VoidTDServer.DataService)
local p = DS.Get(player)
p.Gems = 99999
for _, id in ipairs(Config.UnitOrder) do p.Inventory[id] = 1 end
local STRAT = os.getenv and nil
local loadout = { "VoidSoldier", "ShadowArcher", "DarkGunner", "AbyssReaper", "FallenAngel", "AbyssOverlord" }
local PRESETS = {
	strong = { { "VoidSoldier", "ShadowArcher", "DarkGunner", "AbyssReaper", "FallenAngel", "AbyssOverlord" }, { "VoidSoldier", "ShadowArcher", "VoidSoldier", "ShadowArcher", "DarkGunner", "VoidSoldier", "AbyssReaper", "DarkGunner", "FallenAngel", "AbyssReaper", "AbyssOverlord", "FallenAngel", "AbyssOverlord", "DarkGunner", "AbyssReaper" } },
	common = { { "VoidSoldier", "ShadowArcher", "LostMage" }, { "VoidSoldier", "ShadowArcher", "VoidSoldier", "LostMage", "ShadowArcher", "VoidSoldier", "LostMage", "ShadowArcher", "LostMage", "VoidSoldier", "ShadowArcher", "LostMage", "VoidSoldier", "ShadowArcher", "LostMage" } },
	mid = { { "VoidSoldier", "ShadowArcher", "VoidKnight", "DarkGunner", "AbyssReaper", "CorruptedSamurai" }, { "VoidSoldier", "ShadowArcher", "VoidSoldier", "ShadowArcher", "DarkGunner", "VoidKnight", "DarkGunner", "AbyssReaper", "CorruptedSamurai", "AbyssReaper", "CorruptedSamurai", "DarkGunner", "VoidKnight", "AbyssReaper", "CorruptedSamurai" } },
	shattered = { { "RiftScout", "CrystalHunter", "VoidPuppeteer", "Starbreaker", "RiftMonarch", "RealityDestroyer" }, { "RiftScout", "CrystalHunter", "RiftScout", "CrystalHunter", "VoidPuppeteer", "RiftScout", "Starbreaker", "VoidPuppeteer", "RiftMonarch", "Starbreaker", "RealityDestroyer", "CrystalHunter", "RiftMonarch", "VoidPuppeteer", "CrystalHunter" } },
	blood = { { "BloodAcolyte", "CrimsonGunslinger", "MoonWitch", "BloodfangWarlord", "LunarSeraph", "CrimsonEclipse" }, { "BloodAcolyte", "CrimsonGunslinger", "BloodAcolyte", "CrimsonGunslinger", "MoonWitch", "BloodAcolyte", "BloodfangWarlord", "MoonWitch", "LunarSeraph", "BloodfangWarlord", "CrimsonEclipse", "CrimsonGunslinger", "LunarSeraph", "MoonWitch", "CrimsonGunslinger" } },
	clock = { { "VoidSoldier", "ShadowArcher", "DarkGunner", "AbyssReaper", "FallenAngel", "CursedClockmaker" }, { "VoidSoldier", "ShadowArcher", "VoidSoldier", "ShadowArcher", "DarkGunner", "VoidSoldier", "AbyssReaper", "DarkGunner", "FallenAngel", "AbyssReaper", "CursedClockmaker", "FallenAngel", "DarkGunner", "AbyssReaper", "FallenAngel" } },
	mythic = { { "VoidSoldier", "ShadowArcher", "DarkGunner", "EclipseGuardian", "VoidEmperor", "AbyssOverlord" }, { "VoidSoldier", "ShadowArcher", "VoidSoldier", "ShadowArcher", "DarkGunner", "DarkGunner", "EclipseGuardian", "VoidEmperor", "EclipseGuardian", "AbyssOverlord", "VoidEmperor", "EclipseGuardian", "AbyssOverlord", "DarkGunner", "DarkGunner" } },
}
local LOADOUT = PRESETS[PRESET][1]
for i, id in ipairs(LOADOUT) do assert(req("Equip", { Unit = id, Slot = i })) end

-- кандидаты позиций: близко к дороге
local PathUtil = env.require(RS.VoidTD.PathUtil)
local spots = {}
for x = -120, 120, 3 do
	for z = -94, 94, 3 do
		local pos = M.Vector3.new(x, 60, z)
		local ok2 = PathUtil.IsPlacementClear(pos)
		local d = PathUtil.DistanceToPath(pos)
		if ok2 and d < 8 then
			local cover = 0
			for s = 0, PathUtil.Length, 2 do
				if PathUtil.FlatDistance(PathUtil.PositionAt(s), pos) < 12 then cover = cover + 1 end
			end
			spots[#spots + 1] = { pos = pos, cover = cover }
		end
	end
end
table.sort(spots, function(a, b) return a.cover > b.cover end)
-- разреживаем
local picked = {}
for _, s in ipairs(spots) do
	local okS = true
	for _, q in ipairs(picked) do if PathUtil.FlatDistance(q.pos, s.pos) < 9 then okS = false break end end
	if okS then picked[#picked + 1] = s end
end
spots = picked
print("spots", #spots, "best cover", spots[1].cover, "worst", spots[#spots].cover)
local used = 1
local State = RS.VoidTD.State
local units = RS.VoidTD.Units
local function money() return player:GetAttribute("Money") end

local VERBOSE = false
local priority = PRESETS[PRESET][2] or { "VoidSoldier", "ShadowArcher", "VoidSoldier", "DarkGunner", "ShadowArcher", "AbyssReaper", "DarkGunner", "FallenAngel", "AbyssReaper", "AbyssOverlord", "FallenAngel", "DarkGunner", "AbyssOverlord", "AbyssReaper", "FallenAngel" }
local pi = 1
local function spend()
	-- ставим по приоритету, потом апгрейдим самого дешёвого
	local guard = 0
	while guard < 50 do
		guard = guard + 1
		local acted = false
		local id = priority[pi]
		if id then
			local cost = Config.Units[id].Levels[1].Cost
			if money() >= cost then
				while used <= #spots do
					local s = spots[used]; used = used + 1
					local okP, err = req("Place", { Unit = id, Position = s.pos, Rotation = 0 })
					if okP then pi = pi + 1; acted = true; break end
				end
			elseif #units:GetChildren() >= 3 then
				-- копим, но сперва апгрейды если дёшевы
			end
		end
		if not acted then
			local best, bestCost
			for _, f in ipairs(units:GetChildren()) do
				local def = Config.Units[f:GetAttribute("UnitId")]
				local lv = f:GetAttribute("Level")
				local nx = def.Levels[lv + 1]
				if nx and (not bestCost or nx.Cost < bestCost) then best, bestCost = f, nx.Cost end
			end
			local nextPlace = priority[pi] and Config.Units[priority[pi]].Levels[1].Cost or math.huge
			if best and money() >= bestCost and (bestCost < nextPlace * 0.35 or not priority[pi]) then
				assert(req("Upgrade", { Uid = tonumber(best.Name) }))
				acted = true
			end
		end
		if not acted then break end
	end
end

assert(State:GetAttribute("Phase") == "Idle", "server must start Idle")
assert(not req("Place", { Unit = "VoidSoldier", Position = M.Vector3.new(0, 60, 0), Rotation = 0 }), "placing outside match must fail")
assert(req("JoinMatch", { Difficulty = DIFF }))
assert(player:GetAttribute("InMatch") and State:GetAttribute("Phase") == "Prep", "join failed")
print("difficulty", State:GetAttribute("Difficulty"), "core", State:GetAttribute("CoreHP"), "money", money())
spend()
assert(req("StartWave"))
local RunService = M.services.RunService
local dt = 1 / 20
local lastWave = 0
local t0 = M.now
local maxEnemies = 0
local earned, lastMoney = 0, money()
while M.now - t0 < 60 * 120 do
	M.now = M.now + dt
	M.runDue()
	RunService.Heartbeat:Fire(dt)
	if money() > lastMoney then earned = earned + money() - lastMoney end
	lastMoney = money()
	local phase = State:GetAttribute("Phase")
	local w = State:GetAttribute("Wave")
	if w ~= lastWave then
		lastWave = w
	end
	if phase == "Intermission" then
		spend()
		lastMoney = money()
		req("StartWave")
		local lvsum = 0
		for _, f in ipairs(units:GetChildren()) do lvsum = lvsum + f:GetAttribute("Level") end
		if VERBOSE then
			for _, f in ipairs(units:GetChildren()) do
				local pos = f:GetAttribute("Position")
				print(string.format("    %-16s lv%d dmg=%d pathdist=%.1f", f:GetAttribute("UnitId"), f:GetAttribute("Level"), f:GetAttribute("Damage"), PathUtil.DistanceToPath(pos)))
			end
		end
		print(string.format("t=%5.0fs earned=%6d wave %2d cleared core=%3d money=%6d units=%d lvls=%d", M.now, earned, w, State:GetAttribute("CoreHP"), money(), #units:GetChildren(), lvsum))
	elseif phase == "Victory" or phase == "Defeat" then
		local agg = {}
		for _, f in ipairs(units:GetChildren()) do
			local id = f:GetAttribute("UnitId")
			agg[id] = agg[id] or { d = 0, s = 0, n = 0, lv = 0 }
			agg[id].d += f:GetAttribute("Damage"); agg[id].s += f:GetAttribute("Spent"); agg[id].n += 1; agg[id].lv += f:GetAttribute("Level")
		end
		for id, a in pairs(agg) do print(string.format("   %-17s n=%d avgLv=%.1f dmg=%8d spent=%7d dmg/$=%.2f", id, a.n, a.lv / a.n, a.d, a.s, a.d / a.s)) end
		print("RESULT:", phase, "wave", w, "core", State:GetAttribute("CoreHP"), "time", M.now)
		break
	end
end
-- sell + reset path
local f = units:GetChildren()[1]
if f then print("sell:", req("Sell", { Uid = tonumber(f.Name) })) end
for i = 1, 20 * 20 do M.now = M.now + dt; M.runDue(); RunService.Heartbeat:Fire(dt) end
print("after reset phase:", State:GetAttribute("Phase"), "units:", #units:GetChildren(), "money:", money(), "inMatch:", player:GetAttribute("InMatch"))
assert(State:GetAttribute("Phase") == "Idle" and not player:GetAttribute("InMatch"), "must return to lobby")
-- повторный вход + выход
assert(req("JoinMatch", { Difficulty = "Hardcore" }))
assert(State:GetAttribute("CoreHP") == 50)
assert(req("LeaveMatch"))
assert(State:GetAttribute("Phase") == "Idle", "leave of last player must reset")
for k, v in pairs(counts) do print("remote", k, v) end
