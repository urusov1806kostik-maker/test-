--!nocheck
-- VOID TD :: клиент (бутстрап)
-- Собирает ctx, запускает модули (FX, Render, UI, Placement, Zones, Input), подключает сеть,
-- держит лёгкую графику мира, вращение декора и смену карты. Вся логика — в модулях.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("VoidTD")
local Config = require(Shared:WaitForChild("Config"))
local Path = require(Shared:WaitForChild("Path"))
local Util = require(Shared:WaitForChild("Util"))
local SharedNet = require(Shared:WaitForChild("Net"))
local ModelsFolder = Shared:WaitForChild("Models")
local UnitModels = require(ModelsFolder:WaitForChild("Units"))
local EnemyModels = require(ModelsFolder:WaitForChild("Enemies"))
local CaseModels = require(ModelsFolder:WaitForChild("Cases"))

local Net = require(script:WaitForChild("Net"))
local Anims = require(script:WaitForChild("Anims"))
local FX = require(script:WaitForChild("FX"))
local Renderer = require(script:WaitForChild("Render"))
local UI = require(script:WaitForChild("UI"))
local Placement = require(script:WaitForChild("Placement"))
local Zones = require(script:WaitForChild("Zones"))
local Input = require(script:WaitForChild("Input"))

local Remotes = SharedNet.Remotes()
local State = Shared:WaitForChild("State")
local UnitsFolder = Shared:WaitForChild("Units")

local ctx = {
	Config = Config, Path = Path, Util = Util,
	UnitModels = UnitModels, EnemyModels = EnemyModels, CaseModels = CaseModels,
	FX = FX, Anims = Anims, Renderer = Renderer, UI = UI, Placement = Placement, Zones = Zones, Input = Input,
	Remotes = Remotes, State = State, UnitsFolder = UnitsFolder,
	Profile = nil, Lite = false, Player = player,
}
ctx.Request = Net.Init(ctx)

------------------------------------------------------------------------
-- ЛЁГКАЯ ГРАФИКА МИРА (запоминаем исходное состояние, чтобы вернуть как было)
------------------------------------------------------------------------
local WORLD_ROOTS = { "VoidTDMap", "VoidTDLobby", "VoidTDHalloween", "VoidTDHalloweenMap" }
local saved = setmetatable({}, { __mode = "k" })

local function liteObject(d, on)
	if d:IsA("ParticleEmitter") or d:IsA("PointLight") then
		if on then
			if saved[d] == nil then
				saved[d] = d.Enabled
			end
			d.Enabled = d:IsA("PointLight") and d.Range >= 30 and saved[d] or false
		elseif saved[d] ~= nil then
			d.Enabled = saved[d]
			saved[d] = nil
		end
	end
end

local function applyWorldLite(on)
	for _, name in ipairs(WORLD_ROOTS) do
		local root = workspace:FindFirstChild(name)
		if root then
			for _, d in ipairs(root:GetDescendants()) do
				liteObject(d, on)
			end
		end
	end
	Lighting.GlobalShadows = not on
	local bloom = Lighting:FindFirstChild("VoidBloom")
	if bloom then
		bloom.Enabled = not on
	end
end

function ctx.SetLite(on, save)
	on = on == true
	ctx.Lite = on
	UnitModels.Lite = on
	FX.SetLite(on)
	applyWorldLite(on)
	Renderer.RebuildUnits()
	UI.SetLiteText(on)
	if save then
		ctx.Request("SetLite", { On = on })
		UI.Toast(on and "Лёгкая графика включена" or "Полная графика включена", "good")
	end
end

------------------------------------------------------------------------
-- ДЕКОР: вращение и покачивание (атрибуты Spin SpinAxis BobAmp BobSpeed)
------------------------------------------------------------------------
local spinners = {}
local spinnerSet = setmetatable({}, { __mode = "k" })

local function addSpinner(obj)
	if spinnerSet[obj] then
		return
	end
	if not (obj:IsA("BasePart") or obj:IsA("Model")) then
		return
	end
	if obj:GetAttribute("Spin") == nil and obj:GetAttribute("BobAmp") == nil then
		return
	end
	spinnerSet[obj] = true
	spinners[#spinners + 1] = {
		Obj = obj,
		IsModel = obj:IsA("Model"),
		Base = obj:IsA("Model") and obj:GetPivot() or obj.CFrame,
		Spin = obj:GetAttribute("Spin") or 0,
		Axis = obj:GetAttribute("SpinAxis") or "Y",
		Bob = obj:GetAttribute("BobAmp") or 0,
		BobSpeed = obj:GetAttribute("BobSpeed") or 1,
		Phase = math.random() * 6,
	}
end

local function collectSpinners(root)
	addSpinner(root)
	for _, d in ipairs(root:GetDescendants()) do
		addSpinner(d)
	end
end

local function updateSpinners(t)
	for i = #spinners, 1, -1 do
		local s = spinners[i]
		local obj = s.Obj
		if not obj.Parent then
			-- объект удалён — убираем из списка
			spinners[i] = spinners[#spinners]
			spinners[#spinners] = nil
		else
			local a = t * s.Spin
			local rot = s.Axis == "X" and CFrame.Angles(a, 0, 0) or (s.Axis == "Z" and CFrame.Angles(0, 0, a) or CFrame.Angles(0, a, 0))
			local cf = CFrame.new(0, math.sin(t * s.BobSpeed + s.Phase) * s.Bob, 0) * s.Base * rot
			if s.IsModel then
				obj:PivotTo(cf)
			else
				obj.CFrame = cf
			end
		end
	end
end

-- корни мира: при появлении — собрать декор (после секунды на достройку) и применить лёгкую графику
local function onWorldRoot(root)
	if not table.find(WORLD_ROOTS, root.Name) then
		return
	end
	task.delay(1, function()
		if root.Parent then
			collectSpinners(root)
			if ctx.Lite then
				applyWorldLite(true)
			end
		end
	end)
end
for _, name in ipairs(WORLD_ROOTS) do
	local r = workspace:FindFirstChild(name)
	if r then
		onWorldRoot(r)
	end
end
workspace.ChildAdded:Connect(onWorldRoot)

------------------------------------------------------------------------
-- ЗАПУСК МОДУЛЕЙ
------------------------------------------------------------------------
FX.Init(ctx)
Renderer.Init(ctx)
UI.Init(ctx)
Placement.Init(ctx)
Zones.Init(ctx)
Input.Init(ctx)
Net.Connect(ctx)

-- смена карты боя (Void / Halloween)
local function applyMap()
	local key = State:GetAttribute("Map") or "Void"
	if Path.MapKey ~= key then
		Renderer.ClearEnemies()
		Renderer.ClearAllies()
		Path.SetMap(key)
	end
	UI.SetMapMode(key)
end
State:GetAttributeChangedSignal("Map"):Connect(applyMap)
applyMap()

-- главный цикл
RunService.RenderStepped:Connect(function(dt)
	Renderer.Update(dt)
	UI.Update(dt)
	updateSpinners(os.clock())
	Zones.Update()
	Input.Update(dt)
end)

------------------------------------------------------------------------
-- ПРОФИЛЬ И СОСТОЯНИЕ
------------------------------------------------------------------------
while not player:GetAttribute("VoidReady") do
	task.wait(0.1)
end

local okP, prof = ctx.Request("GetProfile")
if okP and type(prof) == "table" then
	UI.SetProfile(prof)
end

-- лёгкая графика: сохранённая настройка, иначе — по умолчанию на телефонах
do
	local savedLite = ctx.Profile and ctx.Profile.Settings and ctx.Profile.Settings.Lite
	local mobile = UserInputService.TouchEnabled and not UserInputService.MouseEnabled
	local on = (savedLite == nil and mobile) or savedLite == true
	ctx.SetLite(on, false)
end

local okE, list = ctx.Request("GetEnemies")
if okE and type(list) == "table" then
	for _, e in ipairs(list) do
		Renderer.SpawnEnemy(e)
	end
end

for _, f in ipairs(UnitsFolder:GetChildren()) do
	Renderer.AddUnit(f)
end
UnitsFolder.ChildAdded:Connect(function(f)
	task.defer(Renderer.AddUnit, f, true)
end)
UnitsFolder.ChildRemoved:Connect(function(f)
	Renderer.RemoveUnit(f)
end)

UI.Toast("Добро пожаловать в VOID TD! Встань в круг ИГРАТЬ, чтобы начать бой", "good")
