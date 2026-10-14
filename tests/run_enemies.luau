--!nocheck
-- Проверка моделей и анимаций врагов: постройка, фазы боссов, все стили смерти, облегчённый режим.
local M = require("./mock")
local E = require("./env")
local env = E.make()
local game = env.game
local RS = M.services.ReplicatedStorage

E.runInstaller()
local player = M.newPlayer("Tester", 1)
M.services.Players.LocalPlayer = player
E.load(game:GetService("ServerScriptService").VoidTDServer)()
M.runDue()
local Config = env.require(RS.VoidTD.Config)

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

local Renderer = env.require(clientScript.Renderer)
local EnemyModels = env.require(RS.VoidTD.EnemyModels)
local UnitModels = env.require(RS.VoidTD.UnitModels)
local ids = { "LostSoul", "VoidCrawler", "ShadowBeast", "ArmoredHorror", "RiftPhantom", "AbyssBrute", "CorruptedTitan", "VoidDevourer", "TheEntity" }

local function countParts(model)
	local n = 0
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then n += 1 end
	end
	return n
end

local full = {}
for _, id in ipairs(ids) do
	local rig = EnemyModels.Build(id)
	assert(rig.Model and rig.Root and rig.Motors.Root and rig.Base.Root, id .. ": rig API")
	assert(rig.Style and rig.HipHeight and rig.Height and rig.Height > rig.HipHeight, id .. ": style/height")
	for _, d in ipairs(rig.Model:GetDescendants()) do
		if d:IsA("BasePart") then assert(d.CanQuery == false, id .. ": CanQuery must be false") end
	end
	full[id] = countParts(rig.Model)
	print(string.format("%-15s parts %4d  style %-6s hip %.1f height %.1f phases %d death %s", id, full[id], rig.Style, rig.HipHeight, rig.Height, #rig.Phases, rig.DeathStyle))
end

-- спавн всех у портала
for i, id in ipairs(ids) do
	local def = Config.Enemies[id]
	Renderer.SpawnEnemy({ 1000 + i, id, def.Health, def.Speed, 0, 0.5, def.Health })
end
tick(2.5)
assert(#Renderer.EnemyFolder:GetChildren() == #ids, "all enemies spawned")

-- урон: фазы боссов
local function sync(frac)
	local list = {}
	for i, id in ipairs(ids) do
		local v = Renderer.EnemyViews[1000 + i]
		list[#list + 1] = 1000 + i
		list[#list + 1] = v.ServerDist + 5
		list[#list + 1] = Config.Enemies[id].Health * frac
		list[#list + 1] = 0
	end
	Renderer.OnSync({ E = list })
end
sync(0.6)
tick(1.5)
local ent = Renderer.EnemyViews[1009]
assert(ent.VisualPhase == 2, "Entity phase 2 at 60%")
sync(0.25)
tick(1.0)
assert(ent.VisualPhase == 3, "Entity phase 3 at 25%")
assert(Renderer.EnemyViews[1008].VisualPhase == 3, "Devourer phase 3")
assert(Renderer.EnemyViews[1007].VisualPhase == 2, "Titan damaged phase")
local fxFolder = M.workspace:FindFirstChild("VoidTD_FX")
local broken = 0
for _, d in ipairs(fxFolder:GetChildren()) do
	if d.Name == "Detail" then broken += 1 end
end
print("broken parts falling:", broken)
assert(broken > 0, "crown/ring/armor must break off")
tick(3)

-- смерть всех стилей
local rm = {}
for i = 1, #ids do rm[#rm + 1] = { 1000 + i, "kill" } end
Renderer.OnSync({ E = {}, RM = rm })
tick(3.5)
assert(#Renderer.EnemyFolder:GetChildren() == 0, "death animations must finish and clean up")

-- облегчённый режим
UnitModels.Lite = true
for _, id in ipairs(ids) do
	local n = countParts(EnemyModels.Build(id).Model)
	assert(n <= full[id], id .. ": lite must not add parts")
end
UnitModels.Lite = false
print("ENEMY TEST OK")
