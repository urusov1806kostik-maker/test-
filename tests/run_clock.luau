--!nocheck
-- Проверка Проклятого часовщика на сервере: таймеры трёх способностей, остановка/откат врагов,
-- ускорение только своих юнитов, буря 15 с + перезарядка 90 с, остановка таймеров при продаже.
local M = require("./mock")
local E = require("./env")
local env = E.make()
local game = env.game
local RS = M.services.ReplicatedStorage
local V3 = M.Vector3

local events = {}
M.log = function(name, payload)
	if name == "Impact" or name == "Attack" then
		events[#events + 1] = { name, payload, M.now }
	end
end
M.raycast = function(origin)
	local top = M.workspace:FindFirstChild("VoidTDMap").Ground.IslandTop
	return { Instance = top, Position = V3.new(origin.X, 60, origin.Z) }
end

E.runInstaller()
local Config = env.require(RS.VoidTD.Config)
local PathUtil = env.require(RS.VoidTD.PathUtil)
local UnitModels = env.require(RS.VoidTD.UnitModels)
for lv = 1, 5 do
	local rig = UnitModels.Build("CursedClockmaker", lv)
	assert(rig.Muzzle and rig.SpinRates and rig.Motors.ClockHour and rig.Motors.GearAxe, "clockmaker rig lv" .. lv)
end
local p1 = M.newPlayer("Clock", 1)
local p2 = M.newPlayer("Other", 2)
E.load(game:GetService("ServerScriptService").VoidTDServer)()
M.runDue()
local GS = env.require(game:GetService("ServerScriptService").VoidTDServer.GameService)
local DS = env.require(game:GetService("ServerScriptService").VoidTDServer.DataService)
local request = RS.VoidTD.Remotes.Request
local function req(pl, action, data)
	return rawget(request, "_props").OnServerInvoke(pl, action, data)
end
for _, pl in ipairs({ p1, p2 }) do
	local prof = DS.Get(pl)
	for _, id in ipairs(Config.UnitOrder) do prof.Inventory[id] = 1 end
end
assert(req(p1, "Equip", { Unit = "CursedClockmaker", Slot = 1 }))
assert(req(p1, "Equip", { Unit = "VoidSoldier", Slot = 2 }))
assert(req(p2, "Equip", { Unit = "VoidSoldier", Slot = 1 }))
assert(req(p1, "JoinMatch", { Difficulty = "Medium" }))
assert(req(p2, "JoinMatch", { Difficulty = "Medium" }))
p1:SetAttribute("Money", 1e7)
p2:SetAttribute("Money", 1e7)

-- место у дороги и соседние точки
local spots = {}
for x = -120, 120, 2 do
	for z = -94, 94, 2 do
		local pos = V3.new(x, 60, z)
		if PathUtil.IsPlacementClear(pos) and PathUtil.DistanceToPath(pos) < 7 then
			spots[#spots + 1] = pos
		end
	end
end
local okC, cUid
local cPos
for _, s in ipairs(spots) do
	okC, cUid = req(p1, "Place", { Unit = "CursedClockmaker", Position = s, Rotation = 0 })
	if okC then cPos = s break end
end
assert(okC, "clockmaker not placed")
local function placeNear(pl, id, minD, maxD)
	for _, s in ipairs(spots) do
		local d = PathUtil.FlatDistance(s, cPos)
		if d >= minD and d <= maxD then
			local ok, uid = req(pl, "Place", { Unit = id, Position = s, Rotation = 0 })
			if ok then return uid end
		end
	end
end
local mine = placeNear(p1, "VoidSoldier", 4, 12)
local far = placeNear(p1, "VoidSoldier", 20, 40)
local theirs = placeNear(p2, "VoidSoldier", 4, 12)
assert(mine and far and theirs, "allies not placed")

local D = GS.Debug()
local clock = D.Units[cUid]
local t0 = clock.PlacedAt

-- живучие враги возле часовщика (медленные, чтобы видеть остановку и откат)
local function nearestDist()
	local best, bd = 0, math.huge
	for dist = 0, PathUtil.Length, 1 do
		local d = PathUtil.FlatDistance(PathUtil.PositionAt(dist), cPos)
		if d < bd then best, bd = dist, d end
	end
	return best
end
local base = nearestDist()
local lastDist = {}
local function refill()
	-- враги медленно ползут вперёд; уползших возвращаем к часовщику (это не откат способности)
	for _, e in pairs(D.Enemies) do
		if e.Alive and e.Dist > base + 5 then
			e.Dist = base - 3
			lastDist[e] = e.Dist
		end
	end
	local n = 0
	for _, e in pairs(D.Enemies) do if e.Alive then n = n + 1 end end
	for i = n + 1, 8 do
		local e = D.Spawn(i == 1 and "CorruptedTitan" or "LostSoul", math.max(0, base - 4 + i * 0.8), 0)
		e.Health, e.MaxHealth = 1e12, 1e12
		e.Speed = 0.6
	end
end
refill()

local RunService = M.services.RunService
local dt = 0.05
local function run(seconds, each)
	local stop = M.now + seconds
	while M.now < stop do
		M.now = M.now + dt
		M.runDue()
		RunService.Heartbeat:Fire(dt)
		if each then each() end
	end
end

-- следим за врагами: остановка не дольше 1.5 с (боссы 0.5 с), откат ровно на 2 studs
local maxFrozenNormal, maxFrozenBoss, frozenNow = 0, 0, 0
local rewinds = {}
local function watch()
	local t = D.Now()
	local nf = 0
	for _, e in pairs(D.Enemies) do
		if (e.FrozenUntil or 0) > t then
			local left = e.FrozenUntil - t
			if e.IsBoss then maxFrozenBoss = math.max(maxFrozenBoss, left) else maxFrozenNormal = math.max(maxFrozenNormal, left); nf = nf + 1 end
		end
		local prev = lastDist[e]
		if prev and e.Dist < prev - 0.5 then
			rewinds[#rewinds + 1] = { e, prev - e.Dist, t, e.IsBoss }
		end
		lastDist[e] = e.Dist
	end
	frozenNow = math.max(frozenNow, nf)
	refill()
end

local hasteSeen = { mine = false, far = false, theirs = false, self = false }
local function watchHaste()
	watch()
	local t = D.Now()
	if (D.Units[mine].HasteUntil or 0) > t then hasteSeen.mine = D.Units[mine].Haste end
	if (D.Units[far].HasteUntil or 0) > t then hasteSeen.far = true end
	if (D.Units[theirs].HasteUntil or 0) > t then hasteSeen.theirs = true end
	if (clock.HasteUntil or 0) > t then hasteSeen.self = true end
end

run(200, watchHaste)

-- разбор событий
local haste, storms, stormEnds, breaks, bursts, discs = {}, {}, {}, {}, {}, 0
for _, ev in ipairs(events) do
	local name, p, at = ev[1], ev[2], ev[3] - t0
	if p.U == cUid then
		if name == "Impact" and p.K == "TimeHaste" then haste[#haste + 1] = at end
		if name == "Impact" and p.K == "TimeStorm" then storms[#storms + 1] = at end
		if name == "Impact" and p.K == "TimeBreak" then breaks[#breaks + 1] = at end
		if name == "Impact" and p.K == "ChronoBurst" then bursts[#bursts + 1] = at end
		if name == "Attack" and not p.AB then discs = discs + 1 end
	end
end
print("haste at:", table.concat(haste, ", "))
print("storm at:", table.concat(storms, ", "))
print("breaks at:", table.concat(breaks, ", "))
print("disc attacks:", discs, "storm bursts:", #bursts)

local function near(a, b, tol) return math.abs(a - b) <= (tol or 0.2) end
-- 2. ускорение: 30, 60, 90 ... (перезарядка ровно 30 с)
assert(#haste >= 6 and near(haste[1], 30) and near(haste[2], 60) and near(haste[6], 180), "haste timers")
assert(hasteSeen.mine == 0.06, "own nearby unit gets +6% at lv1")
assert(not hasteSeen.far and not hasteSeen.theirs and not hasteSeen.self, "haste only own units in radius, not self")
-- 3. буря: 90 с после установки, 15 с, следующая через 90 с после окончания (195 с)
assert(#storms == 2 and near(storms[1], 90) and near(storms[2], 195), "storm timers")
for _, b in ipairs(bursts) do
	assert((b >= 90 and b <= 105.6) or (b >= 195 and b <= 200.6), "AOE burst outside storm at " .. b)
end
assert(#bursts > 3, "storm AOE must trigger on attacks")
-- 1. поломка времени: не чаще раза в 18 с, остановка ≤ 4 обычных врагов
for i = 2, #breaks do
	assert(breaks[i] - breaks[i - 1] >= 17.9, "time break too often")
end
assert(#breaks >= 3, "time break must trigger")
assert(frozenNow <= 4 and frozenNow >= 1, "freeze up to 4 normal enemies, got " .. frozenNow)
assert(maxFrozenNormal <= 1.5 + 1e-6 and maxFrozenNormal > 1.3, "normal freeze 1.5s")
assert(maxFrozenBoss <= 0.5 + 1e-6 and maxFrozenBoss > 0.3, "boss freeze 0.5s")
for _, r in ipairs(rewinds) do
	assert(not r[4], "bosses are not rewound")
	assert(r[2] <= 2.0 + 1e-6, "rewind 2 studs max")
end
assert(#rewinds >= 1, "rewind must happen")

-- продажа: таймеры часовщика останавливаются
assert(req(p1, "Sell", { Uid = cUid }))
local before = #events
run(60, watch)
for i = before + 1, #events do
	assert(events[i][2].U ~= cUid, "sold clockmaker must not act")
end
print("CLOCK TEST OK")
