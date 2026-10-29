--!nocheck
-- Серверный бот-прогон v2: сервер + один игрок, бот ставит/апгрейдит юнитов по пресету и проходит матч.
-- Запуск: luau run_server.luau [-a PRESET DIFF]   (по умолчанию strong Medium → должна быть победа)
local E = require("./env")
local M = E.M
local P = M._.P

local args = { ... }
local PRESET, DIFF = args[1] or "strong", args[2] or "Medium"
local EXPECT = args[3] or (PRESET == "strong" and DIFF == "Medium" and "Victory" or nil)

local env = E.make()
E.install()
local RS = M.services.ReplicatedStorage
local SSS = M.services.ServerScriptService

-- все пакеты сервер → клиент должны сериализоваться
local counts = {}
M.log = function(name) counts[name] = (counts[name] or 0) + 1 end

E.startServer()
M.run(0.5, 1 / 30)
assert(M.workspace:FindFirstChild("VoidTDMap"), "map not built")
assert(M.workspace.VoidTDLobby:FindFirstChild("HalloweenGate"), "no HalloweenGate")
assert(not M.workspace.VoidTDLobby.Zones:FindFirstChild("Case_BloodMoon"), "BloodMoon zone must not exist")
assert(M.workspace.VoidTDMap.VoidCore:GetAttribute("CoreCenter"), "no CoreCenter")
print("parts:", M.partCount)

local player = M.newPlayer("Tester", 1)
M.spawnCharacter(player, M.workspace.VoidTDLobby.LobbySpawn.CFrame + M.Vector3.new(0, 4, 0))
M.run(0.5, 1 / 30)
assert(player:GetAttribute("VoidReady"), "player not ready")

local Server = SSS.VoidTDServer
local request = RS.VoidTD.Remotes.Request
local function req(action, data)
	return P(request).OnServerInvoke(player, action, data)
end
local ok, prof = req("GetProfile")
assert(ok and prof and prof.Equipped["1"], "no profile")
print("profile gems", prof.Gems, "equipped", prof.Equipped["1"], prof.Equipped["2"], prof.Equipped["3"])
local okS, res = req("Summon", { Count = 10 })
assert(okS and #res == 10, "summon x10")
assert(not req("Summon", { Case = "Nope" }), "unknown case must fail")

-- выдаём все юниты
local Data = env.require(Server.Data)
local Config = env.require(RS.VoidTD.Config)
local Path = env.require(RS.VoidTD.Path)
local p = Data.Get(player)
p.Gems = 99999
for _, id in ipairs(Config.UnitOrder) do p.Inventory[id] = 1 end

local PRESETS = {
	strong = { { "VoidSoldier", "ShadowArcher", "DarkGunner", "AbyssReaper", "FallenAngel", "AbyssOverlord" }, { "VoidSoldier", "ShadowArcher", "VoidSoldier", "ShadowArcher", "DarkGunner", "VoidSoldier", "AbyssReaper", "DarkGunner", "FallenAngel", "AbyssReaper", "AbyssOverlord", "FallenAngel", "AbyssOverlord", "DarkGunner", "AbyssReaper" } },
	common = { { "VoidSoldier", "ShadowArcher", "LostMage" }, { "VoidSoldier", "ShadowArcher", "VoidSoldier", "LostMage", "ShadowArcher", "VoidSoldier", "LostMage", "ShadowArcher", "LostMage", "VoidSoldier", "ShadowArcher", "LostMage", "VoidSoldier", "ShadowArcher", "LostMage" } },
	shattered = { { "RiftScout", "CrystalHunter", "VoidPuppeteer", "Starbreaker", "RiftMonarch", "RealityDestroyer" }, { "RiftScout", "CrystalHunter", "RiftScout", "CrystalHunter", "VoidPuppeteer", "RiftScout", "Starbreaker", "VoidPuppeteer", "RiftMonarch", "Starbreaker", "RealityDestroyer", "CrystalHunter", "RiftMonarch", "VoidPuppeteer", "CrystalHunter" } },
	blood = { { "BloodAcolyte", "CrimsonGunslinger", "MoonWitch", "BloodfangWarlord", "LunarSeraph", "CrimsonEclipse" }, { "BloodAcolyte", "CrimsonGunslinger", "BloodAcolyte", "CrimsonGunslinger", "MoonWitch", "BloodAcolyte", "BloodfangWarlord", "MoonWitch", "LunarSeraph", "BloodfangWarlord", "CrimsonEclipse", "CrimsonGunslinger", "LunarSeraph", "MoonWitch", "CrimsonGunslinger" } },
	clock = { { "VoidSoldier", "ShadowArcher", "DarkGunner", "AbyssReaper", "FallenAngel", "CursedClockmaker" }, { "VoidSoldier", "ShadowArcher", "VoidSoldier", "ShadowArcher", "DarkGunner", "VoidSoldier", "AbyssReaper", "DarkGunner", "FallenAngel", "AbyssReaper", "CursedClockmaker", "FallenAngel", "DarkGunner", "AbyssReaper", "FallenAngel" } },
	mythic = { { "VoidSoldier", "ShadowArcher", "DarkGunner", "EclipseGuardian", "VoidEmperor", "AbyssOverlord" }, { "VoidSoldier", "ShadowArcher", "VoidSoldier", "ShadowArcher", "DarkGunner", "DarkGunner", "EclipseGuardian", "VoidEmperor", "EclipseGuardian", "AbyssOverlord", "VoidEmperor", "EclipseGuardian", "AbyssOverlord", "DarkGunner", "DarkGunner" } },
}
local preset = assert(PRESETS[PRESET], "unknown preset " .. PRESET)
for i = 1, 6 do assert(req("Equip", { Unit = preset[1][i] or nil, Slot = i })) end

-- места: рядом с дорогой, сортировка по покрытию, разрежение 9 studs
local spots = {}
for x = -120, 120, 3 do
	for z = -94, 94, 3 do
		local pos = M.Vector3.new(x, 60, z)
		if Path.IsPlacementClear(pos) and Path.DistanceToPath(pos) < 8 then
			local cover = 0
			for s = 0, Path.Length, 2 do
				if Path.FlatDistance(Path.PositionAt(s), pos) < 12 then cover += 1 end
			end
			spots[#spots + 1] = { pos = pos, cover = cover }
		end
	end
end
table.sort(spots, function(a, b) return a.cover > b.cover end)
local picked = {}
for _, s in ipairs(spots) do
	local free = true
	for _, q in ipairs(picked) do if Path.FlatDistance(q.pos, s.pos) < 9 then free = false break end end
	if free then picked[#picked + 1] = s end
end
spots = picked
print("spots", #spots)

local State, units = RS.VoidTD.State, RS.VoidTD.Units
local function money() return player:GetAttribute("Money") end
local priority, pi, used = preset[2], 1, 1
local placeFails = {}
local function spend()
	for _ = 1, 50 do
		local acted = false
		local id = priority[pi]
		if id and money() >= Config.Units[id].Levels[1].Cost then
			while used <= #spots do
				local s = spots[used]
				used += 1
				local okP, err = req("Place", { Unit = id, Position = s.pos, Rotation = 0 })
				if okP then pi += 1; acted = true; break end
				placeFails[err] = (placeFails[err] or 0) + 1
			end
		end
		if not acted then
			local best, bestCost
			for _, f in ipairs(units:GetChildren()) do
				local nx = Config.Units[f:GetAttribute("UnitId")].Levels[f:GetAttribute("Level") + 1]
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
assert(not req("JoinMatch", { Difficulty = "Nope" }), "bad difficulty must fail")
assert(req("JoinMatch", { Difficulty = DIFF }))
assert(player:GetAttribute("InMatch") and State:GetAttribute("Phase") == "Prep", "join failed")
assert(not req("JoinMatch", { Difficulty = DIFF }), "double join must fail")
print("difficulty", State:GetAttribute("Difficulty"), "core", State:GetAttribute("CoreHP"), "money", money())
-- проверка аргументов
assert(not req("Place", { Unit = "VoidSoldier", Position = M.Vector3.new(0 / 0, 60, 0) }), "NaN must fail")
assert(not req("Place", "junk"), "junk must fail")
assert(not req("Upgrade", { Uid = 999 }), "foreign uid must fail")
assert(not req("NoSuchAction"), "unknown action must fail")
spend()
assert(#units:GetChildren() > 0, "nothing placed")
assert(req("StartWave"))
assert(not req("StartWave"), "wave already running")

local dt = 1 / 20
local t0 = M.now
local result
while M.now - t0 < 60 * 120 do
	M.step(dt)
	local phase = State:GetAttribute("Phase")
	local w = State:GetAttribute("Wave")
	if phase == "Intermission" then
		spend()
		req("StartWave")
		local lv = 0
		for _, f in ipairs(units:GetChildren()) do lv += f:GetAttribute("Level") end
		print(string.format("t=%5.0fs wave %2d cleared core=%3d money=%6d units=%d lvls=%d", M.now - t0, w, State:GetAttribute("CoreHP"), money(), #units:GetChildren(), lv))
	elseif phase == "Victory" or phase == "Defeat" then
		result = phase
		local agg = {}
		for _, f in ipairs(units:GetChildren()) do
			local id = f:GetAttribute("UnitId")
			agg[id] = agg[id] or { d = 0, s = 0, n = 0, lv = 0 }
			agg[id].d += f:GetAttribute("Damage"); agg[id].s += f:GetAttribute("Spent"); agg[id].n += 1; agg[id].lv += f:GetAttribute("Level")
		end
		for id, a in pairs(agg) do print(string.format("   %-17s n=%d avgLv=%.1f dmg=%8d spent=%7d", id, a.n, a.lv / a.n, a.d, a.s)) end
		print("RESULT:", phase, "wave", w, "core", State:GetAttribute("CoreHP"), "time", M.now - t0)
		break
	end
end
for e, n in pairs(placeFails) do print("place fail:", e, n) end
assert(result, "match did not finish")
if EXPECT then assert(result == EXPECT, "expected " .. EXPECT .. ", got " .. result) end
if result == "Victory" then assert(Data.Get(player).Stats.Wins >= 1, "no win recorded") end

-- продажа + сброс в лобби
local f = units:GetChildren()[1]
if f then print("sell:", req("Sell", { Uid = tonumber(f.Name) })) end
M.run(20, dt)
print("after reset phase:", State:GetAttribute("Phase"), "units:", #units:GetChildren(), "money:", money(), "inMatch:", player:GetAttribute("InMatch"))
assert(State:GetAttribute("Phase") == "Idle" and not player:GetAttribute("InMatch"), "must return to lobby")
assert(#units:GetChildren() == 0, "units must be cleared")
local root = player.Character.HumanoidRootPart.Position
assert((root - Config.Lobby.Spawn).Magnitude < 10, "player not in lobby: " .. tostring(root))

-- повторный вход + выход
assert(req("JoinMatch", { Difficulty = "Hardcore" }))
assert(State:GetAttribute("CoreHP") == 50, "hardcore core 50")
assert(req("LeaveMatch"))
assert(State:GetAttribute("Phase") == "Idle", "leave of last player must reset")

-- выход игрока посреди матча
assert(req("JoinMatch", { Difficulty = "Easy" }))
M.removePlayer(player)
M.run(1, dt)
assert(State:GetAttribute("Phase") == "Idle", "removing last player must reset")
assert(#M.errors == 0, "runtime errors: " .. tostring(M.errors[1]))
for k, v in pairs(counts) do print("remote", k, v) end
print("RUN_SERVER OK")
