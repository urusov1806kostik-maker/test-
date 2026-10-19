--!nocheck
-- Клиент + сервер вместе в мок-окружении: Хэллоуин-остров, порталы, кейс (юнит, руна, SECRET),
-- руны в инвентаре, очередь, бестиарий, матч на Haunted Hollow со всеми эффектами, союзниками и эхо.
local M = require("./mock")
local E = require("./env")
local env = E.make()
local game = env.game
local RS = M.services.ReplicatedStorage
local Inst = M.Inst
local V3 = M.Vector3

Inst.FireAllClients = function(self, ...) self.OnClientEvent:Fire(...) end
Inst.FireClient = function(self, pl, ...) self.OnClientEvent:Fire(...) end
M.raycast = function(origin, dir, params)
	local filt = params and params.FilterDescendantsInstances
	if filt and filt[1] and filt[1].Name == "VoidTD_Units" then return nil end
	local map = M.workspace:FindFirstChild("VoidTDHalloweenMap") or M.workspace:FindFirstChild("VoidTDMap")
	return { Instance = map.Ground.IslandTop, Position = V3.new(origin.X, 60, origin.Z) }
end

E.runInstaller()
local player = M.newPlayer("Tester", 1)
M.services.Players.LocalPlayer = player
local char = env.Instance.new("Model")
char.Name = "Character"
local hrp = env.Instance.new("Part")
hrp.Name = "HumanoidRootPart"
hrp.Parent = char
char.PrimaryPart = hrp
char.Parent = M.workspace
player.Character = char
E.load(game:GetService("ServerScriptService").VoidTDServer)()
M.runDue()
local Config = env.require(RS.VoidTD.Config)
local DS = env.require(game:GetService("ServerScriptService").VoidTDServer.DataService)
local prof = DS.Get(player)
for _, id in ipairs(Config.UnitOrder) do prof.Inventory[id] = 1 end
prof.Runes = { LanternHeart = 1, CursedThreads = 1, PhantomCrown = 1 }
prof.HalloweenCoins = 5000

local clientScript = M.services.StarterPlayer.StarterPlayerScripts.VoidTDClient
local co = coroutine.create(E.load(clientScript))
local ok, err = coroutine.resume(co)
if not ok then error(debug.traceback(co, err)) end
M.runDue()
local RunService = M.services.RunService
local function tick(sec)
	local dt = 1 / 30
	for _ = 1, math.floor(sec / dt) do
		M.now = M.now + dt
		M.runDue()
		RunService.Heartbeat:Fire(dt)
		RunService.RenderStepped:Fire(dt)
	end
end
local function req(action, data)
	return rawget(RS.VoidTD.Remotes.Request, "_props").OnServerInvoke(player, action, data)
end
local function findButton(prefix)
	for _, d in ipairs(player.PlayerGui:GetDescendants()) do
		if d.ClassName == "TextButton" and type(d.Text) == "string" and d.Text:sub(1, #prefix) == prefix then return d end
	end
end
local function hasText(text)
	for _, d in ipairs(player.PlayerGui:GetDescendants()) do
		if (d.ClassName == "TextLabel" or d.ClassName == "TextButton") and type(d.Text) == "string" and d.Text:find(text, 1, true) then return d end
	end
end
local function at(pos)
	char:PivotTo(env.CFrame.new(pos + V3.new(0, 3, 0)))
	tick(0.3)
end
RS.VoidTD.Remotes.Profile.OnClientEvent:Fire(DS.Snapshot(player))
tick(0.5)

-- портал в лобби -> остров
local L, I = Config.Lobby, Config.HalloweenIsland
at(L.Spawn)
at(L.Center + L.Zones.HalloweenPortal.Offset)
tick(1.2)
assert((hrp.Position - I.Spawn).Magnitude < 8, "portal zone teleports to island")
assert(player:GetAttribute("Island"), "island flag")
print("portal ok")

-- кейс на острове: открытие (юнит или руна) + SECRET сцена напрямую
at(I.Center + I.Zones.Case_Halloween.Offset)
assert(hasText("Lantern") or hasText("LANTERN KING"), "case rewards list shown")
local before = DS.Get(player).HalloweenCoins
findButton("ОТКРЫТЬ").Activated:Fire()
tick(5)
assert(DS.Get(player).HalloweenCoins == before - 500, "case charged once")
local okBtn = findButton("OK")
assert(okBtn, "reveal finished with OK")
okBtn.Activated:Fire()
local HUI = env.require(M.services.StarterPlayer.StarterPlayerScripts.VoidTDClient.HalloweenUI)
HUI.PlayOpening({ { Id = "LanternKing", New = true } })
tick(6)
assert(hasText("SECRET") or findButton("OK"), "secret cinematic")
findButton("OK").Activated:Fire()
HUI.PlayOpening({ { Rune = "PhantomCrown", New = false } })
tick(5)
assert(hasText("Призрачная корона"), "rune reveal")
findButton("OK").Activated:Fire()
print("case ok")

-- руны в инвентаре
HUI.OpenRunePicker("NightWatchman")
tick(0.2)
findButton("НАДЕТЬ").Activated:Fire()
tick(0.2)
assert(DS.GetRune(player, "NightWatchman"), "rune equipped from picker")
print("runes ok", DS.GetRune(player, "NightWatchman"))

-- хэллоуинские юниты и бестиарий
at(I.Center + I.Zones.HalloweenUnits.Offset)
assert(hasText("🎃 HALLOWEEN"), "halloween tag on cards")
at(I.Center + I.Zones.Bestiary.Offset)
tick(0.5)
assert(hasText("Cursed Monarch"), "bestiary")
print("tags + bestiary ok")

-- 3D-просмотр: способности, галерея призыва (Кукловод 6, Иллюзионист 5), проклятые люди руны
local UV = env.require(M.services.StarterPlayer.StarterPlayerScripts.VoidTDClient.UnitViewer)
assert(req("EquipRune", { Unit = "Gravedigger", Rune = "CursedThreads" }))
RS.VoidTD.Remotes.Profile.OnClientEvent:Fire(DS.Snapshot(player))
for _, case in ipairs({ { "HalloweenPuppeteer", "ПОСМОТРЕТЬ ПРИЗЫВ", 6 }, { "DarkIllusionist", "ПОСМОТРЕТЬ ПРИЗЫВ", 5 }, { "Gravedigger", "ПРОКЛЯТЫЕ ЛЮДИ", 5 } }) do
	UV.Open(case[1], 5)
	tick(0.3)
	for _, ab in ipairs(Config.Units[case[1]].PreviewAbilities or {}) do
		UV.PlayAnim(ab[1])
		tick(1.5)
	end
	local b = findButton(case[2])
	assert(b and b.Visible, "gallery button for " .. case[1])
	b.Activated:Fire()
	tick(0.5)
	local n = 0
	for _, d in ipairs(player.PlayerGui:GetDescendants()) do
		if d.ClassName == "Model" and d:GetAttribute("AllyId") then n = n + 1 end
	end
	assert(n == case[3], case[1] .. " gallery shows " .. n)
	assert(hasText("HP"), "gallery shows HP")
	findButton("← К ЮНИТУ").Activated:Fire()
	tick(0.2)
	UV.Close()
	tick(0.1)
end
assert(req("EquipRune", { Unit = "Gravedigger" }))
print("viewer gallery ok")

-- очередь
local loadout = { "NightWatchman", "PhantomKnight", "DarkIllusionist", "HalloweenPuppeteer", "HeadlessExecutioner", "LanternKing" }
for i, id in ipairs(loadout) do assert(req("Equip", { Unit = id, Slot = i })) end
assert(req("EquipRune", { Unit = "LanternKing", Rune = "PhantomCrown" }))
assert(req("EquipRune", { Unit = "PhantomKnight", Rune = "CursedThreads" }))
local qc = I.Center + I.Queue.Offset
at(qc + I.Queue.Pads[1])
tick(0.6)
assert(hasText("HALLOWEEN TD") and hasText("👑 Tester"), "queue panel")
findButton("СТАРТ").Activated:Fire()
tick(4)
assert(player:GetAttribute("InMatch") and RS.VoidTD.State:GetAttribute("Map") == "Halloween", "in halloween match")
local PathUtil = env.require(RS.VoidTD.PathUtil)
assert(PathUtil.MapKey == "Halloween", "client path switched")
print("queue ok")

-- бой: ставим юнитов у дороги и играем несколько волн
player:SetAttribute("Money", 200000)
local MC = Config.Maps.Halloween
local placed = 0
for x = -130, 130, 4 do
	for z = -100, 100, 4 do
		if placed >= 10 then break end
		local pos = V3.new(MC.Center.X + x, 60, MC.Center.Z + z)
		if PathUtil.IsPlacementClear(pos) and PathUtil.DistanceToPath(pos) < 7 then
			local id = loadout[(placed % #loadout) + 1]
			local okP, uid = req("Place", { Unit = id, Position = pos, Rotation = 0 })
			if okP then
				placed = placed + 1
				for _ = 1, 4 do req("Upgrade", { Uid = uid }) end
			end
		end
	end
end
assert(placed >= 6, "placed " .. placed)
tick(1)
local HFX = env.require(M.services.StarterPlayer.StarterPlayerScripts.VoidTDClient.HalloweenFX)
local Renderer = env.require(M.services.StarterPlayer.StarterPlayerScripts.VoidTDClient.Renderer)
assert(req("StartWave"))
local maxAllies, enemyTypes = 0, {}
for _ = 1, 240 do
	tick(1)
	local n = 0
	for _ in pairs(HFX.Allies) do n = n + 1 end
	maxAllies = math.max(maxAllies, n)
	for _, v in pairs(Renderer.EnemyViews) do enemyTypes[v.Type] = true end
	local ph = RS.VoidTD.State:GetAttribute("Phase")
	if ph == "Intermission" then req("StartWave") end
	if ph == "Victory" or ph == "Defeat" then break end
end
local nt = 0
for _ in pairs(enemyTypes) do nt = nt + 1 end
print("wave", RS.VoidTD.State:GetAttribute("Wave"), "client allies max", maxAllies, "enemy types seen", nt)
assert(maxAllies > 0, "allies rendered on client")
assert(nt >= 6, "halloween enemies rendered")

-- все виды ударов рисуются без ошибок
local kinds = { "LightFlash", "LanternBeam", "DirtBurst", "LeafStorm", "CurseMark", "BellWave", "MidnightToll", "FlaskSplash", "Poison",
	"PlagueCloud", "PlagueCloudBurst", "GhostSword", "MirrorShatter", "ThreadSnap", "FireCrack", "Execution", "PumpkinBlast",
	"GhostPumpkin", "LanternHeart", "CursedThreads", "PhantomEcho", "CursedCircle", "AllyHit", "Fog", "Straw", "Fire" }
local p0 = PathUtil.PositionAt(100)
for _, k in ipairs(kinds) do
	Renderer.OnImpact({ K = k, P = p0, R = 6, DUR = 1, L = 5, U = 1, A = {}, S = "Puppet", G = true })
end
Renderer.OnImpact({ K = "GhostSlash", P = p0, E = p0 + V3.new(10, 0, 0), L = 5 })
Renderer.OnImpact({ K = "SummonPortal", S = "Illusion", P = p0, L = 5 })
for _, s in ipairs({ "Phase", "Shield", "Haste", "Enrage", "ArmorBreak" }) do
	for id in pairs(Renderer.EnemyViews) do
		Renderer.OnImpact({ K = "EnemyState", I = id, S = s, DUR = 1, P = p0 })
		break
	end
end
tick(3)
-- спавн-эффекты боссов
local spawnId = 90000
for _, id in ipairs({ "GraveWarden", "FogReaper", "CursedMonarch" }) do
	spawnId = spawnId + 1
	Renderer.SpawnEnemy({ spawnId, id, 1000, 4, 0, 0 })
	tick(2)
	Renderer.RemoveEnemy(spawnId, "kill")
	tick(2.5)
end
print("fx ok")
-- выход из матча
assert(req("LeaveMatch"))
tick(2)
assert(RS.VoidTD.State:GetAttribute("Map") == "Void" and PathUtil.MapKey == "Void", "back to void map")
print("HALLOWEEN CLIENT TEST OK")
