--!nocheck
local M = require("./mock")
local E = require("./env")
local env = E.make()
local game = env.game
local RS = M.services.ReplicatedStorage
local Inst = M.Inst

Inst.FireAllClients = function(self, ...) self.OnClientEvent:Fire(...) end
Inst.FireClient = function(self, pl, ...) self.OnClientEvent:Fire(...) end

M.raycast = function(origin, dir, params)
	local map = M.workspace:FindFirstChild("VoidTDMap")
	local filt = params and params.FilterDescendantsInstances
	if filt and filt[1] and filt[1].Name == "VoidTD_Units" then return nil end
	return { Instance = map.Ground.IslandTop, Position = M.Vector3.new(origin.X, 60, origin.Z) }
end

E.runInstaller()
local player = M.newPlayer("Tester", 1)
M.services.Players.LocalPlayer = player
E.load(game:GetService("ServerScriptService").VoidTDServer)()
M.runDue()

local Config = env.require(RS.VoidTD.Config)
local DS = env.require(game:GetService("ServerScriptService").VoidTDServer.DataService)
local prof = DS.Get(player)
prof.Gems = 99999
for _, id in ipairs(Config.UnitOrder) do prof.Inventory[id] = 1 end

-- клиент
local clientScript = M.services.StarterPlayer.StarterPlayerScripts.VoidTDClient
local co = coroutine.create(E.load(clientScript))
local ok, err = coroutine.resume(co)
if not ok then error(debug.traceback(co, err)) end
M.runDue()
print("client started; PlayerGui children:", #player.PlayerGui:GetChildren())

local RunService = M.services.RunService
local UIS = M.services.UserInputService
local function tick(sec)
	local dt = 1 / 30
	for _ = 1, math.floor(sec / dt) do
		M.now = M.now + dt
		M.runDue()
		RunService.Heartbeat:Fire(dt)
		RunService.RenderStepped:Fire(dt)
	end
end

local function findButton(prefix)
	for _, d in ipairs(player.PlayerGui:GetDescendants()) do
		if d.ClassName == "TextButton" and type(d.Text) == "string" and d.Text:sub(1, #prefix) == prefix then return d end
	end
end

-- экипировка через инвентарь
local ui = player.PlayerGui.VoidTD_UI
findButton("☰").Activated:Fire()
tick(0.2)
for i, id in ipairs({ "EclipseGuardian", "FallenAngel", "VoidEmperor", "AbyssOverlord", "CorruptedSamurai", "AbyssReaper" }) do
	local r = { rawget(RS.VoidTD.Remotes.Request, "_props").OnServerInvoke(player, "Equip", { Unit = id, Slot = i }) }
	assert(r[1], tostring(r[2]))
end
RS.VoidTD.Remotes.Profile.OnClientEvent:Fire(DS.Snapshot(player))
tick(0.2)
print("hotbar refreshed")

-- summon x10 через кнопку
findButton("✦").Activated:Fire()
findButton("x10").Activated:Fire()
tick(3)
local okBtn = findButton("OK")
assert(okBtn, "no OK button after summon")
okBtn.Activated:Fire()
print("summon UI ok")

do
	local UIm = env.require(clientScript.UI)
	local orig = UIm.Toast
	UIm.Toast = function(t, k) print("TOAST:", t, k); orig(t, k) end
	local PL = env.require(clientScript.Placement)
	local o2 = PL.Start
	PL.Start = function(id) print("Placement.Start", id); o2(id); print("  active", PL.Active) end
end
print("equipped1", env.require(clientScript.UI).EquippedAt(1), "handlers", #UIS.InputBegan.handlers, coroutine.status(co))
-- размещение: клавиша 1..6 + клик
player:SetAttribute("Money", 200000)
local positions = { { -40, -30 }, { -75, 20 }, { 0, 0 }, { 60, 0 }, { 20, -60 }, { -30, 70 } }
local function key(code) UIS.InputBegan:Fire({ UserInputType = env.Enum.UserInputType.Keyboard, KeyCode = env.Enum.KeyCode[code] }, false) end
local codes = { "One", "Two", "Three", "Four", "Five", "Six" }
for i = 1, 6 do
	M.raycast = function(origin, dir, params)
		local filt = params and params.FilterDescendantsInstances
		if filt and filt[1] and filt[1].Name == "VoidTD_Units" then return nil end
		local map = M.workspace:FindFirstChild("VoidTDMap")
		return { Instance = map.Ground.IslandTop, Position = M.Vector3.new(positions[i][1], 60, positions[i][2]) }
	end
	key(codes[i])
	tick(0.1)
	UIS.InputBegan:Fire({ UserInputType = env.Enum.UserInputType.MouseButton1 }, false)
	tick(0.3)
end
print("units placed:", #RS.VoidTD.Units:GetChildren())
assert(#RS.VoidTD.Units:GetChildren() == 6, "placement failed")

-- панель юнита, апгрейд, смена цели
local UI = env.require(clientScript.UI)
local Renderer = env.require(clientScript.Renderer)
for _, f in ipairs(RS.VoidTD.Units:GetChildren()) do
	UI.OpenUnit(tonumber(f.Name))
	for _ = 1, 4 do key("E"); tick(0.05) end
	key("T")
	tick(0.3)
end
print("upgrades done; levels:", (function() local s = 0 for _, f in ipairs(RS.VoidTD.Units:GetChildren()) do s = s + f:GetAttribute("Level") end return s end)())

-- волны с боссом
local GS = env.require(game:GetService("ServerScriptService").VoidTDServer.GameService)
local State = RS.VoidTD.State
findButton("▶").Activated:Fire()
local seen = {}
for _ = 1, 60 * 30 do
	tick(1 / 3)
	local ph = State:GetAttribute("Phase")
	if ph == "Intermission" then findButton("▶").Activated:Fire() end
	local w = State:GetAttribute("Wave")
	if not seen[w] then
		seen[w] = true
		local n = 0
		for _ in pairs(Renderer.EnemyViews) do n = n + 1 end
		print("wave", w, "phase", ph, "enemyViews", n, "fx children", #M.workspace.VoidTD_FX:GetChildren())
	end
	if w >= 12 or ph == "Defeat" or ph == "Victory" then break end
end
-- продажа
UI.OpenUnit(tonumber(RS.VoidTD.Units:GetChildren()[1].Name))
key("X")
tick(1)
print("after sell units:", #RS.VoidTD.Units:GetChildren())
local N = RS.VoidTD.Remotes.Notify
N.OnClientEvent:Fire({ Type = "CoreHit", Amount = 5 })
N.OnClientEvent:Fire({ Type = "Victory", Wave = 30, Gems = 1000, Reset = 3 })
tick(4)
N.OnClientEvent:Fire({ Type = "Reset" })
N.OnClientEvent:Fire({ Type = "Defeat", Wave = 17, Reset = 2 })
tick(3)
N.OnClientEvent:Fire({ Type = "Reset" })
N.OnClientEvent:Fire({ Type = "WaveStart", Wave = 30, Boss = "The Entity" })
tick(3)
-- тач-размещение
UIS.TouchEnabled = true
UIS.MouseEnabled = false
local PL = env.require(clientScript.Placement)
PL.Start("FallenAngel")
UIS.InputBegan:Fire({ UserInputType = env.Enum.UserInputType.Touch, Position = M.Vector3.new(300, 300, 0) }, false)
tick(0.2)
findButton("ROTATE").Activated:Fire()
findButton("CANCEL").Activated:Fire()
print("touch flow ok, active:", PL.Active)
print("CLIENT TEST OK")
