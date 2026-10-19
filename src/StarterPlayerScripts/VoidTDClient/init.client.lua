--!nocheck
-- VOID TD :: Client bootstrap

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

local Shared = ReplicatedStorage:WaitForChild("VoidTD")
local Remotes = Shared:WaitForChild("Remotes")
local State = Shared:WaitForChild("State")
local UnitsFolder = Shared:WaitForChild("Units")

local ctx = {
	Config = require(Shared:WaitForChild("Config")),
	PathUtil = require(Shared:WaitForChild("PathUtil")),
	UnitModels = require(Shared:WaitForChild("UnitModels")),
	EnemyModels = require(Shared:WaitForChild("EnemyModels")),
	CaseModels = require(Shared:WaitForChild("CaseModels")),
	FX = require(script:WaitForChild("FX")),
	HFX = require(script:WaitForChild("HalloweenFX")),
	HalloweenAnims = require(script:WaitForChild("HalloweenAnims")),
	Renderer = require(script:WaitForChild("Renderer")),
	UI = require(script:WaitForChild("UI")),
	Placement = require(script:WaitForChild("Placement")),
	Remotes = Remotes,
	State = State,
	UnitsFolder = UnitsFolder,
	Profile = nil,
}

local UI, Renderer, Placement, FX = ctx.UI, ctx.Renderer, ctx.Placement, ctx.FX
local requestFn = Remotes:WaitForChild("Request")

function ctx.Request(action, data)
	local ok, a, b = pcall(function()
		return requestFn:InvokeServer(action, data)
	end)
	if not ok then
		UI.Toast("Нет связи с сервером", "error")
		return false
	end
	if a == false and b then
		UI.Toast(tostring(b), "error")
	end
	return a, b
end

------------------------------------------------------------------------
-- ОБЛЕГЧЁННАЯ ГРАФИКА
------------------------------------------------------------------------
local Lighting = game:GetService("Lighting")
ctx.Lite = false

local function applyWorldLite(on)
	for _, name in ipairs({ "VoidTDMap", "VoidTDLobby", "VoidTDHalloween", "VoidTDHalloweenMap" }) do
		local root = workspace:FindFirstChild(name)
		if root then
			for _, d in ipairs(root:GetDescendants()) do
				if d:IsA("ParticleEmitter") then
					d.Enabled = not on
				elseif d:IsA("PointLight") then
					-- оставляем только самые яркие источники
					d.Enabled = not on or d.Range >= 30
				end
			end
		end
	end
	-- на клиенте изменения Lighting локальные
	Lighting.GlobalShadows = not on
	local bloom = Lighting:FindFirstChild("VoidBloom")
	if bloom then
		bloom.Enabled = not on
	end
end

function ctx.SetLite(on, save)
	ctx.Lite = on
	ctx.UnitModels.Lite = on
	FX.Lite = on
	applyWorldLite(on)
	Renderer.RebuildUnits()
	UI.SetLiteText(on)
	if save then
		ctx.Request("SetLite", { On = on })
		UI.Toast(on and "Лёгкая графика включена" or "Полная графика включена", "good")
	end
end

FX.Init()
Renderer.Init(ctx)
UI.Init(ctx)
Placement.Init(ctx)

-- профиль
while not player:GetAttribute("VoidReady") do
	task.wait(0.1)
end
local ok, prof = ctx.Request("GetProfile")
if ok and prof then
	UI.SetProfile(prof)
end
-- режим графики: из профиля, иначе на телефонах сразу лёгкий
do
	local saved = prof and prof.Settings and prof.Settings.Lite
	local mobile = UserInputService.TouchEnabled and not UserInputService.MouseEnabled
	local on = (saved == nil and mobile) or saved == true
	task.spawn(function()
		workspace:WaitForChild("VoidTDMap", 20)
		workspace:WaitForChild("VoidTDLobby", 20)
		ctx.SetLite(on, false)
	end)
end
Remotes.Profile.OnClientEvent:Connect(function(p)
	UI.SetProfile(p)
end)

-- враги
Remotes.EnemySpawn.OnClientEvent:Connect(Renderer.SpawnEnemy)
Remotes.Sync.OnClientEvent:Connect(Renderer.OnSync)
Remotes.Attack.OnClientEvent:Connect(Renderer.OnAttack)
Remotes.Impact.OnClientEvent:Connect(Renderer.OnImpact)
Remotes.Notify.OnClientEvent:Connect(function(p)
	UI.OnNotify(p)
	if p.Type == "CoreHit" then
		local map = Renderer.ActiveMap()
		local core = map and map:FindFirstChild("VoidCore")
		local c = core and core:GetAttribute("CoreCenter")
		if c then
			FX.Sphere(c, 6, FX.Colors.Pink, 0.4)
			FX.Burst(c, FX.Colors.Pink, 10, 0.6, 10)
		end
	elseif p.Type == "Reset" then
		Placement.Stop()
	elseif p.Type == "WaveClear" or p.Type == "Victory" then
		Renderer.Cheer()
	end
end)
local okE, list = ctx.Request("GetEnemies")
if okE and list then
	for _, e in ipairs(list) do
		Renderer.SpawnEnemy(e)
	end
end

-- юниты
for _, f in ipairs(UnitsFolder:GetChildren()) do
	Renderer.AddUnit(f)
end
UnitsFolder.ChildAdded:Connect(function(f)
	-- атрибуты приходят вместе с объектом, но подстрахуемся
	task.defer(Renderer.AddUnit, f, true)
end)
UnitsFolder.ChildRemoved:Connect(Renderer.RemoveUnit)

------------------------------------------------------------------------
-- ВВОД
------------------------------------------------------------------------
local hoverHL = Instance.new("Highlight")
hoverHL.FillTransparency = 1
hoverHL.OutlineColor = Color3.fromRGB(220, 160, 255)
hoverHL.OutlineTransparency = 0.1
hoverHL.DepthMode = Enum.HighlightDepthMode.Occluded

local unitParams = RaycastParams.new()
unitParams.FilterType = Enum.RaycastFilterType.Include

local function unitUnder(screenPos, isTouch)
	local cam = workspace.CurrentCamera
	local ray = isTouch and cam:ScreenPointToRay(screenPos.X, screenPos.Y) or cam:ViewportPointToRay(screenPos.X, screenPos.Y)
	unitParams.FilterDescendantsInstances = { Renderer.UnitFolder }
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 600, unitParams)
	if hit then
		local m = hit.Instance:FindFirstAncestorOfClass("Model")
		while m and not m:GetAttribute("Uid") do
			m = m.Parent and m.Parent:FindFirstAncestorOfClass("Model")
		end
		if m then
			return m:GetAttribute("Uid"), m
		end
	end
	return nil
end

local keySlots = {
	[Enum.KeyCode.One] = 1, [Enum.KeyCode.Two] = 2, [Enum.KeyCode.Three] = 3,
	[Enum.KeyCode.Four] = 4, [Enum.KeyCode.Five] = 5, [Enum.KeyCode.Six] = 6,
}

UserInputService.InputBegan:Connect(function(input, gp)
	if gp then
		return
	end
	local t = input.UserInputType
	if t == Enum.UserInputType.Keyboard then
		local k = input.KeyCode
		if keySlots[k] then
			local id = UI.EquippedAt(keySlots[k])
			if id then
				Placement.Start(id)
			end
		elseif k == Enum.KeyCode.Q or k == Enum.KeyCode.Escape then
			if Placement.Active then
				Placement.Stop()
			else
				UI.CloseUnit()
			end
		elseif k == Enum.KeyCode.R and Placement.Active then
			Placement.Rotate()
		elseif k == Enum.KeyCode.E then
			UI.UpgradeSelected()
		elseif k == Enum.KeyCode.X then
			UI.SellSelected()
		elseif k == Enum.KeyCode.T then
			UI.CycleTarget()
		elseif k == Enum.KeyCode.G then
			UI.Toggle("Inventory")
		end
	elseif t == Enum.UserInputType.MouseButton1 then
		if Placement.Active then
			Placement.Confirm()
		else
			local uid = unitUnder(UserInputService:GetMouseLocation(), false)
			if uid then
				UI.OpenUnit(uid)
			else
				UI.CloseUnit()
			end
		end
	elseif t == Enum.UserInputType.MouseButton2 then
		if Placement.Active then
			Placement.Stop()
		end
	elseif t == Enum.UserInputType.Touch then
		local pos = Vector2.new(input.Position.X, input.Position.Y)
		if Placement.Active then
			Placement.SetTouch(pos)
		else
			local uid = unitUnder(pos, true)
			if uid then
				UI.OpenUnit(uid)
			end
		end
	end
end)

------------------------------------------------------------------------
-- ДЕКОР КАРТЫ: вращение и покачивание
------------------------------------------------------------------------
local spinners = {}
local function collectSpinners(map)
	if not map then
		return
	end
	for _, d in ipairs(map:GetDescendants()) do
		if (d:IsA("BasePart") or d:IsA("Model")) and (d:GetAttribute("Spin") or d:GetAttribute("BobAmp")) then
			local base = d:IsA("Model") and d:GetPivot() or d.CFrame
			spinners[#spinners + 1] = {
				Obj = d,
				Base = base,
				Spin = d:GetAttribute("Spin") or 0,
				Axis = d:GetAttribute("SpinAxis") or "Y",
				Bob = d:GetAttribute("BobAmp") or 0,
				BobSpeed = d:GetAttribute("BobSpeed") or 1,
				Phase = math.random() * 6,
			}
		end
	end
end
task.spawn(function()
	local map = workspace:WaitForChild("VoidTDMap", 30)
	local lobby = workspace:WaitForChild("VoidTDLobby", 30)
	task.wait(1)
	collectSpinners(map)
	collectSpinners(lobby)
	collectSpinners(workspace:WaitForChild("VoidTDHalloween", 30))
	collectSpinners(workspace:WaitForChild("VoidTDHalloweenMap", 30))
end)

------------------------------------------------------------------------
-- КАРТА МАТЧА: Void или Haunted Hollow (дорога пересчитывается у всех одинаково)
------------------------------------------------------------------------
local function applyMap()
	local key = State:GetAttribute("Map") or "Void"
	if ctx.PathUtil.MapKey ~= key then
		Renderer.ClearEnemies()
		ctx.HFX.ClearAllies()
		ctx.PathUtil.SetMap(key)
	end
	UI.SetMapMode(key)
end
State:GetAttributeChangedSignal("Map"):Connect(applyMap)
applyMap()

local function updateSpinners(t)
	for _, s in ipairs(spinners) do
		local a = t * s.Spin
		local rot
		if s.Axis == "X" then
			rot = CFrame.Angles(a, 0, 0)
		elseif s.Axis == "Z" then
			rot = CFrame.Angles(0, 0, a)
		else
			rot = CFrame.Angles(0, a, 0)
		end
		local bob = CFrame.new(0, math.sin(t * s.BobSpeed + s.Phase) * s.Bob, 0)
		local cf = bob * s.Base * rot
		if s.Obj:IsA("Model") then
			s.Obj:PivotTo(cf)
		else
			s.Obj.CFrame = cf
		end
	end
end

------------------------------------------------------------------------
-- КРУГИ В ЛОББИ: встал в круг — открылось меню, вышел — закрылось
------------------------------------------------------------------------
local ZONE_MODAL = { Units = "Inventory", Play = "Mode", Bestiary = "Bestiary", HalloweenUnits = "Inventory" }
-- зоны главного лобби и Хэллоуин-острова
local ZONE_SETS = {
	{ Prefix = "", Center = ctx.Config.Lobby.Center, Zones = ctx.Config.Lobby.Zones },
	{ Prefix = "H_", Center = ctx.Config.HalloweenIsland.Center, Zones = ctx.Config.HalloweenIsland.Zones },
}
for _, set in ipairs(ZONE_SETS) do
	for key, z in pairs(set.Zones) do
		if z.Case then
			ZONE_MODAL[set.Prefix .. key] = "Summon"
		elseif ZONE_MODAL[key] then
			ZONE_MODAL[set.Prefix .. key] = ZONE_MODAL[key]
		end
	end
end
local zoneState = {}
local teleportCooldown = 0

local function updateZones()
	if player:GetAttribute("InMatch") then
		if next(zoneState) then
			for key in pairs(zoneState) do
				if ZONE_MODAL[key] then
					UI.Show(ZONE_MODAL[key], false)
				end
			end
			zoneState = {}
		end
		return
	end
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local pos = root.Position
	for _, set in ipairs(ZONE_SETS) do
		for key, z in pairs(set.Zones) do
			local id = set.Prefix .. key
			local c = set.Center + z.Offset
			local flat = Vector3.new(pos.X - c.X, 0, pos.Z - c.Z).Magnitude
			local inside = flat <= z.Radius + 0.5 and math.abs(pos.Y - c.Y) < 8
			if inside ~= (zoneState[id] == true) then
				zoneState[id] = inside or nil
				if z.Teleport then
					-- портал: телепорт на остров / в лобби
					if inside and os.clock() > teleportCooldown then
						teleportCooldown = os.clock() + 2
						FX.Sound("Portal", 1, 1)
						UI.Fade(z.Teleport == "Halloween" and "HALLOWEEN" or "ЛОББИ")
						task.delay(0.35, function()
							ctx.Request("Teleport", { To = z.Teleport })
						end)
					end
				else
					if inside and z.Case then
						UI.SelectCase(z.Case)
					end
					if inside and z.EventUnits then
						UI.SetInventoryFilter(z.EventUnits)
					elseif inside and key == "Units" then
						UI.SetInventoryFilter(nil)
					end
					if ZONE_MODAL[id] then
						UI.Show(ZONE_MODAL[id], inside)
					end
					if inside then
						FX.Sound("Click", 1, 1)
					end
				end
			end
		end
	end
	UI.UpdateQueue()
end

------------------------------------------------------------------------
-- ГЛАВНЫЙ ЦИКЛ
------------------------------------------------------------------------
local hoverTimer = 0
RunService.RenderStepped:Connect(function(dt)
	local t = os.clock()
	Renderer.Update(dt)
	UI.Update(dt)
	updateSpinners(t)
	updateZones()
	hoverTimer = hoverTimer + dt
	if hoverTimer > 0.05 then
		hoverTimer = 0
		if Placement.Active or not UserInputService.MouseEnabled then
			hoverHL.Parent = nil
		else
			local _, model = unitUnder(UserInputService:GetMouseLocation(), false)
			if model then
				hoverHL.Adornee = model
				hoverHL.Parent = model
			else
				hoverHL.Parent = nil
			end
		end
	end
end)

UI.Toast("Добро пожаловать в VOID TD! Встань в круг ИГРАТЬ, чтобы начать бой", "good")
