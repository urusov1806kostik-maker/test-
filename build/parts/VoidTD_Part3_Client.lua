-- VOID TD — установщик, часть 3/3 (3_Client). Вставляй части по порядку 1 -> 2 -> 3.
local RS = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")
local SPS = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")
local SERVICES = { ReplicatedStorage = RS, ServerScriptService = SSS, StarterPlayerScripts = SPS }
local old = SERVICES["StarterPlayerScripts"]:FindFirstChild("VoidTDClient")
if old then old:Destroy() end
local function ensure(parent, name, className)
	local obj = parent:FindFirstChild(name)
	if not obj then
		obj = Instance.new(className)
		obj.Name = name
		obj.Parent = parent
	end
	return obj
end

local function install(service, path, className, source)
	local parent = SERVICES[service]
	for i = 1, #path - 1 do
		parent = ensure(parent, path[i], "Folder")
	end
	local name = path[#path]
	local obj = parent:FindFirstChild(name)
	if obj and obj.ClassName ~= className then
		-- папка-заглушка, созданная для детей: заменяем на скрипт и переносим детей
		local real = Instance.new(className)
		real.Name = name
		for _, child in ipairs(obj:GetChildren()) do child.Parent = real end
		obj:Destroy()
		real.Parent = parent
		obj = real
	elseif not obj then
		obj = Instance.new(className)
		obj.Name = name
		obj.Parent = parent
	end
	obj.Source = source
	return obj
end

local FILES = {}
FILES[#FILES + 1] = { "StarterPlayerScripts", { "VoidTDClient" }, "LocalScript", [======[
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
	for _, name in ipairs({ "VoidTDMap", "VoidTDLobby" }) do
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
		local core = workspace:FindFirstChild("VoidTDMap") and workspace.VoidTDMap:FindFirstChild("VoidCore")
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
end)

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
local ZONE_MODAL = { Units = "Inventory", Play = "Mode" }
for key, z in pairs(ctx.Config.Lobby.Zones) do
	if z.Case then
		ZONE_MODAL[key] = "Summon"
	end
end
local zoneState = {}

local function updateZones()
	if player:GetAttribute("InMatch") then
		if next(zoneState) then
			for key in pairs(zoneState) do
				UI.Show(ZONE_MODAL[key], false)
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
	local L = ctx.Config.Lobby
	local pos = root.Position
	for key, z in pairs(L.Zones) do
		local c = L.Center + z.Offset
		local flat = Vector3.new(pos.X - c.X, 0, pos.Z - c.Z).Magnitude
		local inside = flat <= z.Radius + 0.5 and math.abs(pos.Y - c.Y) < 8
		if inside ~= (zoneState[key] == true) then
			zoneState[key] = inside or nil
			if inside and z.Case then
				UI.SelectCase(z.Case)
			end
			UI.Show(ZONE_MODAL[key], inside)
			if inside then
				FX.Sound("Click", 1, 1)
			end
		end
	end
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
]======] }
FILES[#FILES + 1] = { "StarterPlayerScripts", { "VoidTDClient", "FX" }, "ModuleScript", [======[
--!nocheck
-- VOID TD :: FX (клиент)
-- Все визуальные эффекты способностей. Урон считается на сервере, тут только картинка.

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local FX = {}
FX.Lite = false -- облегчённый режим: меньше частиц и обломков

local V = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles
local rad = math.rad

local NEON = Color3.fromRGB(180, 80, 255)
local NEON_SOFT = Color3.fromRGB(215, 160, 255)
local NEON_PINK = Color3.fromRGB(255, 60, 170)
local WHITE = Color3.fromRGB(250, 245, 255)
FX.Colors = { Neon = NEON, Soft = NEON_SOFT, Pink = NEON_PINK, White = WHITE }

local folder
local rng = Random.new()
local numberCount = 0

------------------------------------------------------------------------
-- ЗВУКИ (встроенные звуки клиента Roblox, без загрузки ассетов)
------------------------------------------------------------------------
local SoundService = game:GetService("SoundService")
local SoundConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("VoidTD"):WaitForChild("Config")).Sounds
local lastSound = {}

-- Играет звук события из Config.Sounds. volume/pitch — множители (по умолчанию 1).
-- Если у события указан Custom ("rbxassetid://..."), играет свой звук, иначе встроенный.
function FX.Sound(name, volume, pitch, pos)
	local def = SoundConfig[name]
	if not def then
		return
	end
	local t = os.clock()
	if lastSound[name] and t - lastSound[name] < 0.07 then
		return
	end
	volume = (volume or 1) * (def.Volume or 0.4)
	-- приглушаем далёкие звуки
	if pos then
		local cam = workspace.CurrentCamera
		local d = cam and (cam.CFrame.Position - pos).Magnitude or 0
		if d > 140 then
			return
		end
		volume = volume * math.clamp(1 - d / 140, 0.15, 1)
	end
	lastSound[name] = t
	local custom = def.Custom and def.Custom ~= ""
	local s = Instance.new("Sound")
	s.SoundId = custom and def.Custom or def.Id
	s.Volume = volume
	s.PlaybackSpeed = (pitch or 1) * (custom and 1 or (def.Pitch or 1))
	s.Parent = SoundService
	s:Play()
	task.delay(4, function()
		s:Destroy()
	end)
end

------------------------------------------------------------------------
-- ТРЯСКА КАМЕРЫ
------------------------------------------------------------------------
local shakeUntil, shakeDur, shakeMag = 0, 1, 0

function FX.Shake(magnitude, duration)
	local t = os.clock()
	if t + duration > shakeUntil or magnitude > shakeMag then
		shakeUntil = t + duration
		shakeDur = duration
		shakeMag = magnitude
	end
end

function FX.Init()
	folder = workspace:FindFirstChild("VoidTD_FX") or Instance.new("Folder")
	folder.Name = "VoidTD_FX"
	folder.Parent = workspace
	RunService:BindToRenderStep("VoidTD_Shake", Enum.RenderPriority.Camera.Value + 1, function()
		local t = os.clock()
		if t < shakeUntil then
			local k = (shakeUntil - t) / shakeDur * shakeMag
			local cam = workspace.CurrentCamera
			cam.CFrame = cam.CFrame * CFrame.new(rng:NextNumber(-k, k), rng:NextNumber(-k, k), 0) * CFrame.Angles(0, 0, rng:NextNumber(-k, k) * 0.03)
		end
	end)
end

local function tween(obj, time, goal, style, dir)
	local t = TweenService:Create(obj, TweenInfo.new(time, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), goal)
	t:Play()
	return t
end
FX.Tween = tween

function FX.Part(props)
	local p = Instance.new(props.Class or "Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = props.Material or Enum.Material.Neon
	p.Color = props.Color or NEON
	p.Size = props.Size or V(1, 1, 1)
	if props.Shape then
		p.Shape = props.Shape
	end
	p.Transparency = props.Transparency or 0
	p.CFrame = props.CFrame or CF()
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = props.Parent or folder
	return p
end

local function cleanup(obj, t)
	task.delay(t, function()
		if obj then
			obj:Destroy()
		end
	end)
end

local function light(parent, color, range, brightness, life)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Shadows = false
	l.Parent = parent
	if life then
		tween(l, life, { Brightness = 0 })
	end
	return l
end

------------------------------------------------------------------------
-- БАЗОВЫЕ ЭФФЕКТЫ
------------------------------------------------------------------------
function FX.Burst(pos, color, count, size, speed, life)
	count = count or 8
	if FX.Lite then
		count = math.min(math.ceil(count / 3), 4)
	end
	size = size or 0.4
	speed = speed or 6
	life = life or 0.45
	for _ = 1, count do
		local dir = V(rng:NextNumber(-1, 1), rng:NextNumber(-0.2, 1), rng:NextNumber(-1, 1)).Unit
		local p = FX.Part({
			Size = V(size, size, size),
			CFrame = CF(pos) * ANG(rng:NextNumber(0, 6), rng:NextNumber(0, 6), 0),
			Color = color or NEON,
		})
		tween(p, life, {
			CFrame = CF(pos + dir * speed * life) * ANG(rng:NextNumber(0, 6), rng:NextNumber(0, 6), 0),
			Transparency = 1,
			Size = V(0.05, 0.05, 0.05),
		})
		cleanup(p, life + 0.05)
	end
end

-- Плоское кольцо, расширяющееся по земле
function FX.Ring(pos, radius, color, life, height, startRadius, transparency)
	life = life or 0.5
	height = height or 0.3
	local r0 = startRadius or 0.5
	local p = FX.Part({
		Shape = Enum.PartType.Cylinder,
		Size = V(height, r0 * 2, r0 * 2),
		CFrame = CF(pos) * ANG(0, 0, rad(90)),
		Color = color or NEON,
		Transparency = transparency or 0.15,
	})
	tween(p, life, { Size = V(height * 0.4, radius * 2, radius * 2), Transparency = 1 })
	cleanup(p, life + 0.05)
	return p
end

function FX.Sphere(pos, radius, color, life, material, startT)
	local p = FX.Part({
		Shape = Enum.PartType.Ball,
		Size = V(0.5, 0.5, 0.5),
		CFrame = CF(pos),
		Color = color or NEON,
		Material = material or Enum.Material.Neon,
		Transparency = startT or 0.1,
	})
	tween(p, life, { Size = V(radius * 2, radius * 2, radius * 2), Transparency = 1 })
	cleanup(p, life + 0.05)
	return p
end

-- Дуга из сегментов (след от оружия)
function FX.Arc(cf, radius, a0, a1, color, thickness, life, horizontal)
	local segs = 9
	thickness = thickness or 0.35
	life = life or 0.35
	local prev
	for i = 0, segs do
		local a = a0 + (a1 - a0) * (i / segs)
		local pt
		if horizontal then
			pt = (cf * CF(math.sin(a) * radius, 0, -math.cos(a) * radius)).Position
		else
			pt = (cf * CF(0, math.cos(a) * radius, -math.sin(a) * radius)).Position
		end
		if prev then
			local len = (pt - prev).Magnitude
			local w = thickness * (0.35 + 0.65 * math.sin(math.pi * i / segs))
			local p = FX.Part({
				Size = V(w, w * 0.5, len + w),
				CFrame = CFrame.lookAt((pt + prev) / 2, pt),
				Color = color or NEON,
				Transparency = 0.05,
			})
			local delay = i / segs * 0.06
			task.delay(delay, function()
				tween(p, life, { Transparency = 1, Size = V(w * 0.2, w * 0.1, len) })
			end)
			cleanup(p, life + delay + 0.05)
		end
		prev = pt
	end
end

-- Вертикальная полоса-разрез (для катаны / императора)
function FX.SlashMark(pos, angle, length, width, color, life)
	life = life or 0.35
	local cf = CF(pos) * ANG(0, rng:NextNumber(0, math.pi), 0) * ANG(0, 0, angle)
	local p = FX.Part({ Size = V(width, length * 0.3, 0.12), CFrame = cf, Color = color or NEON })
	local core = FX.Part({ Size = V(width * 0.35, length * 0.3, 0.14), CFrame = cf, Color = WHITE })
	tween(p, life * 0.35, { Size = V(width, length, 0.12) }, Enum.EasingStyle.Back)
	tween(core, life * 0.35, { Size = V(width * 0.35, length, 0.14) }, Enum.EasingStyle.Back)
	task.delay(life * 0.35, function()
		tween(p, life * 0.65, { Transparency = 1, Size = V(0.05, length * 1.1, 0.05) })
		tween(core, life * 0.65, { Transparency = 1, Size = V(0.02, length * 1.1, 0.02) })
	end)
	cleanup(p, life + 0.05)
	cleanup(core, life + 0.05)
end

function FX.Cracks(pos, radius, color, count, life)
	if FX.Lite then
		return
	end
	count = count or 8
	life = life or 1.4
	for i = 1, count do
		local a = (i / count) * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
		local len = radius * rng:NextNumber(0.5, 0.95)
		local dir = V(math.cos(a), 0, math.sin(a))
		local mid = pos + dir * (len / 2 + 0.6)
		local p = FX.Part({
			Size = V(rng:NextNumber(0.25, 0.5), 0.08, len),
			CFrame = CFrame.lookAt(mid, mid + dir) * ANG(0, rng:NextNumber(-0.15, 0.15), 0),
			Color = color or NEON,
		})
		-- маленькое ответвление
		local bdir = (dir + V(-dir.Z, 0, dir.X) * rng:NextNumber(-0.8, 0.8)).Unit
		local bmid = pos + dir * len * 0.6 + bdir * len * 0.2
		local b = FX.Part({ Size = V(0.2, 0.08, len * 0.4), CFrame = CFrame.lookAt(bmid, bmid + bdir), Color = color or NEON })
		task.delay(life * 0.5, function()
			tween(p, life * 0.5, { Transparency = 1 })
			tween(b, life * 0.5, { Transparency = 1 })
		end)
		cleanup(p, life + 0.05)
		cleanup(b, life + 0.05)
	end
	local scorch = FX.Part({
		Shape = Enum.PartType.Cylinder,
		Size = V(0.06, radius * 0.9, radius * 0.9),
		CFrame = CF(pos) * ANG(0, 0, rad(90)),
		Color = Color3.fromRGB(10, 5, 15),
		Material = Enum.Material.SmoothPlastic,
		Transparency = 0.3,
	})
	tween(scorch, life, { Transparency = 1 })
	cleanup(scorch, life + 0.05)
end

------------------------------------------------------------------------
-- СНАРЯДЫ И ЛУЧИ
------------------------------------------------------------------------
-- getTarget() -> Vector3 | nil (текущая позиция цели)
function FX.Projectile(kind, from, getTarget, travel, onHit, lv)
	lv = lv or 1
	local p
	if kind == "Arrow" then
		p = FX.Part({ Size = V(0.18, 0.18, 2.2), Color = lv >= 4 and NEON or NEON_SOFT })
		local tipP = FX.Part({ Size = V(0.35, 0.35, 0.35), Color = NEON, Parent = p })
		tipP.Name = "Tip"
	elseif kind == "Orb" then
		local s = 0.7 + lv * 0.1
		p = FX.Part({ Shape = Enum.PartType.Ball, Size = V(s, s, s), Color = NEON })
		light(p, NEON, 8, 2)
	elseif kind == "Crystal" then
		p = FX.Part({ Size = V(0.4, 0.4, 1.3), Color = Color3.fromRGB(110, 190, 255) })
		light(p, Color3.fromRGB(80, 170, 255), 7, 2)
	elseif kind == "Bullet" then
		p = FX.Part({ Size = V(0.15, 0.15, 0.9), Color = Color3.fromRGB(255, 90, 80) })
	elseif kind == "Moon" then
		p = FX.Part({ Size = V(0.2, 1.2, 1.2), Shape = Enum.PartType.Cylinder, Color = Color3.fromRGB(255, 200, 215) })
		light(p, Color3.fromRGB(255, 120, 150), 8, 2)
	else
		p = FX.Part({ Size = V(0.25, 0.25, 1.4 + lv * 0.15), Color = lv >= 5 and NEON_PINK or NEON_SOFT })
	end
	local a0 = Instance.new("Attachment")
	a0.Position = V(0, 0.12, 0)
	a0.Parent = p
	local a1 = Instance.new("Attachment")
	a1.Position = V(0, -0.12, 0)
	a1.Parent = p
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Color = ColorSequence.new(kind == "Orb" and NEON or NEON_SOFT)
	trail.LightEmission = 1
	trail.Lifetime = 0.18
	trail.Transparency = NumberSequence.new(0.2, 1)
	trail.WidthScale = NumberSequence.new(kind == "Orb" and 3 or 1, 0)
	trail.Parent = p

	local start = os.clock()
	local last = getTarget() or from
	if (last - from).Magnitude > 0.01 then
		p.CFrame = CFrame.lookAt(from, last)
	else
		p.CFrame = CF(from)
	end
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local alpha = math.clamp((os.clock() - start) / math.max(travel, 0.01), 0, 1)
		local target = getTarget() or last
		last = target
		local pos = from:Lerp(target, alpha)
		if kind == "Arrow" then
			pos = pos + V(0, math.sin(alpha * math.pi) * 1.2, 0)
		end
		if (target - pos).Magnitude > 0.01 then
			p.CFrame = CFrame.lookAt(pos, target)
		else
			p.CFrame = CF(pos)
		end
		if p:FindFirstChild("Tip") then
			p.Tip.CFrame = p.CFrame * CF(0, 0, -1.1)
		end
		if alpha >= 1 then
			conn:Disconnect()
			if onHit then
				onHit(target)
			end
			p:Destroy()
		end
	end)
end

function FX.Beam(from, to, width, color, life, big)
	life = life or 0.45
	local len = (to - from).Magnitude
	local cf = CFrame.lookAt((from + to) / 2, to)
	local outer = FX.Part({ Shape = Enum.PartType.Cylinder, Size = V(len, width * 0.2, width * 0.2), CFrame = cf * ANG(0, rad(90), 0), Color = color or NEON, Transparency = 0.15 })
	local inner = FX.Part({ Shape = Enum.PartType.Cylinder, Size = V(len, width * 0.1, width * 0.1), CFrame = cf * ANG(0, rad(90), 0), Color = WHITE })
	tween(outer, 0.1, { Size = V(len, width, width) }, Enum.EasingStyle.Back)
	tween(inner, 0.1, { Size = V(len, width * 0.45, width * 0.45) }, Enum.EasingStyle.Back)
	light(inner, color or NEON, 16, 4, life)
	task.delay(0.12, function()
		tween(outer, life, { Size = V(len, 0.05, 0.05), Transparency = 1 })
		tween(inner, life, { Size = V(len, 0.02, 0.02), Transparency = 1 })
	end)
	cleanup(outer, life + 0.2)
	cleanup(inner, life + 0.2)
	-- кольца вдоль луча
	local rings = FX.Lite and 1 or (big and 6 or 3)
	for i = 1, rings do
		local pt = from:Lerp(to, i / (rings + 1))
		local ring = FX.Part({ Shape = Enum.PartType.Cylinder, Size = V(0.15, width * 1.6, width * 1.6), CFrame = CFrame.lookAt(pt, to) * ANG(0, rad(90), 0), Color = color or NEON, Transparency = 0.3 })
		tween(ring, life, { Size = V(0.05, width * 3.5, width * 3.5), Transparency = 1 })
		cleanup(ring, life + 0.05)
	end
	FX.Sphere(to, width * 1.8, color or NEON, 0.35)
	FX.Burst(to, color or NEON, big and 16 or 8, 0.5, 10)
	FX.Sphere(from, width, WHITE, 0.25)
end

------------------------------------------------------------------------
-- СПОСОБНОСТИ
------------------------------------------------------------------------
-- ECLIPSE SHOCKWAVE
function FX.Shockwave(pos, radius, lv, color, soft)
	local NEON = color or NEON
	local NEON_SOFT = soft or NEON_SOFT
	local g = V(pos.X, pos.Y + 0.2, pos.Z)
	FX.Sound("Explosion", 1, 1, pos)
	local cam = workspace.CurrentCamera
	if cam and (cam.CFrame.Position - pos).Magnitude < 70 then
		FX.Shake(lv >= 5 and 0.5 or 0.25, 0.35)
	end
	FX.Ring(g, radius, NEON, 0.55, 0.5, 1, 0.05)
	FX.Ring(g + V(0, 0.15, 0), radius * 0.75, WHITE, 0.4, 0.3, 0.5, 0.2)
	task.delay(0.08, function()
		FX.Ring(g + V(0, 0.1, 0), radius * 1.05, NEON_SOFT, 0.6, 0.25, radius * 0.4, 0.4)
	end)
	FX.Cracks(g, radius, NEON, 6 + lv * 2, 1.4)
	-- пыль/осколки
	for _ = 1, FX.Lite and 0 or (6 + lv) do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(1, radius * 0.8)
		local p = g + V(math.cos(a) * r, 0, math.sin(a) * r)
		local rock = FX.Part({ Size = V(0.6, 0.6, 0.6), CFrame = CF(p), Color = Color3.fromRGB(50, 44, 60), Material = Enum.Material.Slate })
		tween(rock, 0.25, { CFrame = CF(p + V(0, rng:NextNumber(1.5, 3), 0)) * ANG(1, 2, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		task.delay(0.25, function()
			tween(rock, 0.3, { CFrame = CF(p) * ANG(2, 1, 1), Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		end)
		cleanup(rock, 0.6)
	end
	local flash = FX.Part({ Size = V(0.2, 0.2, 0.2), CFrame = CF(g + V(0, 2, 0)), Transparency = 1 })
	light(flash, NEON, radius * 2.5, 5, 0.6)
	cleanup(flash, 0.7)
	if lv >= 5 then
		-- большой фиолетовый взрыв
		FX.Sphere(g, radius * 0.7, NEON, 0.6)
		FX.Sphere(g, radius * 0.45, WHITE, 0.4)
		local pillar = FX.Part({ Shape = Enum.PartType.Cylinder, Size = V(18, 3, 3), CFrame = CF(g + V(0, 9, 0)) * ANG(0, 0, rad(90)), Color = NEON, Transparency = 0.2 })
		tween(pillar, 0.6, { Size = V(26, 0.2, 0.2), Transparency = 1 })
		cleanup(pillar, 0.7)
		FX.Burst(g + V(0, 1, 0), NEON_SOFT, 20, 0.6, 16, 0.6)
	end
end

-- Удар косы: горизонтальная дуга + область
function FX.Reap(unitPos, center, radius, lv, color)
	local NEON = color or NEON
	local dir = (center - unitPos)
	dir = V(dir.X, 0, dir.Z)
	if dir.Magnitude < 0.1 then
		dir = V(0, 0, -1)
	end
	local cf = CFrame.lookAt(V(center.X, center.Y + 1.5, center.Z) - dir.Unit * 1.5, V(center.X, center.Y + 1.5, center.Z) + dir.Unit)
	FX.Arc(cf, radius * 0.9, rad(-80), rad(80), NEON, 0.6 + lv * 0.08, 0.4, true)
	FX.Arc(cf * CF(0, -0.4, 0), radius * 0.75, rad(-70), rad(70), Color3.fromRGB(30, 10, 50), 0.5, 0.45, true)
	FX.Ring(V(center.X, center.Y + 0.15, center.Z), radius, Color3.fromRGB(90, 30, 150), 0.4, 0.2, radius * 0.3, 0.45)
	if lv >= 4 then
		FX.Burst(center + V(0, 1, 0), NEON, 10, 0.4, 8)
	end
end

-- VOID JUDGEMENT: энергетический разрез по врагу
function FX.Judgement(pos, lv, hitIndex)
	FX.Sound("Magic", 1, 0.9 + (hitIndex or 1) * 0.08, pos)
	local color = (hitIndex or 1) % 2 == 0 and NEON or NEON_PINK
	local p = pos + V(0, 2, 0)
	FX.SlashMark(p, rad(35 + rng:NextNumber(-10, 10)), 9 + lv, 0.7 + lv * 0.08, color, 0.45)
	if lv >= 3 then
		FX.SlashMark(p, rad(-35 + rng:NextNumber(-10, 10)), 8 + lv, 0.6, NEON, 0.4)
	end
	-- луч с неба
	local beam = FX.Part({ Shape = Enum.PartType.Cylinder, Size = V(30, 1.4, 1.4), CFrame = CF(pos + V(0, 15, 0)) * ANG(0, 0, rad(90)), Color = color, Transparency = 0.3 })
	tween(beam, 0.35, { Size = V(30, 0.1, 0.1), Transparency = 1 })
	cleanup(beam, 0.4)
	FX.Burst(p, color, 8, 0.45, 9)
	FX.Ring(V(pos.X, pos.Y + 0.15, pos.Z), 3 + lv * 0.4, color, 0.4, 0.25)
end

-- BLACK HOLE
function FX.BlackHole(pos, radius, duration, lv, delay)
	task.delay(delay or 0, function()
		FX.Sound("Portal", 1, 1, pos)
		local center = pos + V(0, 2.2, 0)
		local m = Instance.new("Model")
		m.Name = "BlackHole"
		m.Parent = folder
		local core = FX.Part({ Shape = Enum.PartType.Ball, Size = V(0.5, 0.5, 0.5), CFrame = CF(center), Color = Color3.fromRGB(0, 0, 0), Material = Enum.Material.SmoothPlastic, Parent = m })
		local glow = FX.Part({ Shape = Enum.PartType.Ball, Size = V(0.6, 0.6, 0.6), CFrame = CF(center), Color = NEON, Transparency = 0.55, Parent = m })
		local disk = FX.Part({ Shape = Enum.PartType.Cylinder, Size = V(0.15, 1, 1), CFrame = CF(pos + V(0, 0.2, 0)) * ANG(0, 0, rad(90)), Color = Color3.fromRGB(60, 20, 100), Transparency = 0.35, Parent = m })
		local edge = FX.Part({ Shape = Enum.PartType.Cylinder, Size = V(0.1, 1, 1), CFrame = CF(pos + V(0, 0.25, 0)) * ANG(0, 0, rad(90)), Color = NEON, Transparency = 0.5, Parent = m })
		light(glow, NEON, radius * 2.5, 3)
		local coreSize = 2.2 + lv * 0.35
		tween(core, 0.4, { Size = V(coreSize, coreSize, coreSize) }, Enum.EasingStyle.Back)
		tween(glow, 0.4, { Size = V(coreSize * 1.5, coreSize * 1.5, coreSize * 1.5) }, Enum.EasingStyle.Back)
		tween(disk, 0.4, { Size = V(0.15, radius * 2, radius * 2) })
		tween(edge, 0.4, { Size = V(0.1, radius * 2 + 0.6, radius * 2 + 0.6) })
		-- закручивающиеся рукава
		local arms = {}
		for i = 1, FX.Lite and 2 or (4 + (lv >= 5 and 2 or 0)) do
			arms[i] = FX.Part({ Size = V(0.35, 0.2, radius * 0.9), Color = (i % 2 == 0) and NEON or NEON_SOFT, Transparency = 0.2, Parent = m })
		end
		local emitter = Instance.new("ParticleEmitter")
		emitter.Color = ColorSequence.new(NEON)
		emitter.LightEmission = 1
		emitter.Rate = 30 + lv * 8
		emitter.Lifetime = NumberRange.new(0.5, 0.8)
		emitter.Speed = NumberRange.new(-radius * 1.6, -radius * 1.2)
		emitter.SpreadAngle = Vector2.new(180, 180)
		emitter.Size = NumberSequence.new(0.5, 0)
		emitter.Parent = glow
		local start = os.clock()
		local conn
		conn = RunService.RenderStepped:Connect(function()
			local t = os.clock() - start
			if t > duration then
				conn:Disconnect()
				return
			end
			for i, a in ipairs(arms) do
				local ang = t * 4 + i / #arms * math.pi * 2
				local r = radius * 0.55
				local p = center + V(math.cos(ang) * r, -1.6 + math.sin(t * 3 + i) * 0.3, math.sin(ang) * r)
				a.CFrame = CFrame.lookAt(p, center + V(0, -1.6, 0)) * ANG(0, rad(70), 0)
			end
			local pulse = 1 + math.sin(t * 8) * 0.06
			glow.Size = V(coreSize * 1.5, coreSize * 1.5, coreSize * 1.5) * pulse
		end)
		task.delay(duration, function()
			emitter.Enabled = false
			for _, d in ipairs(m:GetChildren()) do
				if d:IsA("BasePart") then
					tween(d, 0.35, { Size = V(0.05, 0.05, 0.05), Transparency = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
				end
			end
			task.delay(0.3, function()
				FX.Sphere(center, radius * 0.6, NEON, 0.35)
			end)
			cleanup(m, 0.8)
		end)
	end)
end

function FX.Summon(pos, radius)
	FX.Ring(V(pos.X, pos.Y + 0.2, pos.Z), radius or 6, NEON, 0.6, 0.4)
	FX.Burst(pos + V(0, 1, 0), NEON, 12, 0.5, 8)
end

function FX.Poof(pos, color, size)
	size = size or 1
	FX.Sphere(pos, 1.5 * size, color or NEON, 0.35)
	FX.Burst(pos, color or NEON, math.floor(6 + size * 4), 0.35 * size, 6 * size, 0.5)
end

function FX.LevelUp(pos, color)
	FX.Sound("Upgrade", 1, 1, pos)
	FX.Ring(pos + V(0, 0.2, 0), 4, color or NEON, 0.6, 0.3)
	local col = FX.Part({ Shape = Enum.PartType.Cylinder, Size = V(0.2, 3, 3), CFrame = CF(pos + V(0, 0.3, 0)) * ANG(0, 0, rad(90)), Color = color or NEON, Transparency = 0.2 })
	tween(col, 0.7, { CFrame = CF(pos + V(0, 7, 0)) * ANG(0, 0, rad(90)), Transparency = 1, Size = V(0.1, 4.5, 4.5) })
	cleanup(col, 0.75)
	FX.Burst(pos + V(0, 3, 0), color or NEON_SOFT, 14, 0.35, 7, 0.7)
end

function FX.Place(pos)
	FX.Sound("Place", 1, 1, pos)
	FX.Ring(pos + V(0, 0.2, 0), 3.5, NEON_SOFT, 0.45, 0.25)
	FX.Burst(pos + V(0, 0.5, 0), Color3.fromRGB(70, 60, 80), 8, 0.4, 5)
end

------------------------------------------------------------------------
-- ЦИФРЫ УРОНА
------------------------------------------------------------------------
function FX.DamageNumber(pos, amount, flag)
	if numberCount > (FX.Lite and 20 or 70) then
		return
	end
	numberCount = numberCount + 1
	local anchor = FX.Part({ Size = V(0.1, 0.1, 0.1), CFrame = CF(pos), Transparency = 1 })
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(120, 40)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 220
	gui.StudsOffsetWorldSpace = V(rng:NextNumber(-0.8, 0.8), 0, rng:NextNumber(-0.8, 0.8))
	gui.Parent = anchor
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = Color3.fromRGB(20, 0, 30)
	if flag == 2 then
		label.Text = "PHASE"
		label.TextColor3 = Color3.fromRGB(170, 170, 200)
		gui.Size = UDim2.fromOffset(80, 26)
	elseif flag == 1 then
		label.Text = tostring(amount) .. "!"
		label.TextColor3 = Color3.fromRGB(255, 210, 70)
		gui.Size = UDim2.fromOffset(150, 50)
	else
		label.Text = tostring(amount)
		label.TextColor3 = Color3.fromRGB(240, 220, 255)
		gui.Size = UDim2.fromOffset(90, 30)
	end
	label.Parent = gui
	tween(gui, 0.8, { StudsOffsetWorldSpace = gui.StudsOffsetWorldSpace + V(0, 2.5, 0) })
	task.delay(0.35, function()
		tween(label, 0.45, { TextTransparency = 1, TextStrokeTransparency = 1 })
	end)
	task.delay(0.85, function()
		numberCount = numberCount - 1
		anchor:Destroy()
	end)
end

------------------------------------------------------------------------
-- ЭФФЕКТЫ НОВЫХ ЮНИТОВ
------------------------------------------------------------------------
local RED = Color3.fromRGB(255, 35, 55)
local GOLD = Color3.fromRGB(255, 205, 80)
local BLUE = Color3.fromRGB(90, 180, 255)
FX.Colors.Red, FX.Colors.Gold, FX.Colors.Blue = RED, GOLD, BLUE

-- нить кукловода от руки к цели
function FX.Thread(from, to, color)
	local len = (to - from).Magnitude
	if len < 0.1 then
		return
	end
	local p = FX.Part({ Size = V(0.08, 0.08, len), CFrame = CFrame.lookAt((from + to) / 2, to), Color = color or NEON_SOFT })
	tween(p, 0.5, { Transparency = 1, Size = V(0.02, 0.02, len) })
	cleanup(p, 0.55)
	FX.Ring(to - V(0, 1, 0), 2, color or NEON, 0.35, 0.2)
end

-- взрыв кристалла
function FX.CrystalBurst(pos, radius)
	FX.Sphere(pos, radius * 0.6, BLUE, 0.3)
	FX.Ring(V(pos.X, pos.Y + 0.2, pos.Z), radius, Color3.fromRGB(170, 225, 255), 0.35, 0.25)
	FX.Burst(pos + V(0, 1, 0), BLUE, 8, 0.35, 8)
	FX.Sound("Explosion", 0.5, 1.6, pos)
end

-- падающий звёздный осколок
function FX.FallingShard(pos, radius, color)
	color = color or GOLD
	local top = pos + V(rng:NextNumber(-3, 3), 22, rng:NextNumber(-3, 3))
	local shard = FX.Part({ Size = V(0.7, 2.2, 0.7), CFrame = CF(top) * ANG(0, rng:NextNumber(0, 6), rad(15)), Color = color })
	tween(shard, 0.28, { CFrame = CF(pos + V(0, 1, 0)) * ANG(0, 2, rad(15)) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	task.delay(0.28, function()
		shard:Destroy()
		FX.Ring(V(pos.X, pos.Y + 0.2, pos.Z), radius, color, 0.35, 0.3)
		FX.Sphere(pos + V(0, 0.5, 0), radius * 0.4, Color3.fromRGB(255, 240, 200), 0.25)
		FX.Burst(pos + V(0, 1, 0), color, 6, 0.4, 8)
	end)
end

-- маленький портал с разрезом (RIFT STORM)
function FX.RiftPortal(pos, lv)
	local c = pos + V(0, 3.5, 0)
	local ring = FX.Part({ Shape = Enum.PartType.Cylinder, Size = V(0.2, 0.5, 0.5), CFrame = CF(c) * ANG(0, rng:NextNumber(0, 6), 0), Color = NEON })
	tween(ring, 0.15, { Size = V(0.2, 3.2, 3.2) }, Enum.EasingStyle.Back)
	local core = FX.Part({ Shape = Enum.PartType.Cylinder, Size = V(0.25, 0.3, 0.3), CFrame = ring.CFrame, Color = Color3.fromRGB(15, 0, 30) })
	tween(core, 0.15, { Size = V(0.25, 2.4, 2.4) }, Enum.EasingStyle.Back)
	task.delay(0.15, function()
		FX.SlashMark(pos + V(0, 1.5, 0), rad(rng:NextNumber(-50, 50)), 6 + lv * 0.5, 0.5, NEON_PINK, 0.3)
		FX.Burst(pos + V(0, 1, 0), NEON, 6, 0.35, 7)
		tween(ring, 0.25, { Size = V(0.1, 0.2, 0.2), Transparency = 1 })
		tween(core, 0.25, { Size = V(0.1, 0.1, 0.1), Transparency = 1 })
	end)
	cleanup(ring, 0.45)
	cleanup(core, 0.45)
	FX.Sound("Portal", 0.5, 1.4, pos)
end

-- большой центральный разлом
function FX.BigRift(pos, radius)
	local g = V(pos.X, pos.Y + 0.2, pos.Z)
	local disk = FX.Part({ Shape = Enum.PartType.Cylinder, Size = V(0.2, 1, 1), CFrame = CF(g) * ANG(0, 0, rad(90)), Color = Color3.fromRGB(15, 0, 30) })
	tween(disk, 0.25, { Size = V(0.2, radius * 2, radius * 2) }, Enum.EasingStyle.Back)
	FX.Ring(g, radius * 1.1, NEON, 0.6, 0.5, 1, 0.05)
	FX.Ring(g + V(0, 0.1, 0), radius * 0.8, NEON_PINK, 0.5, 0.3, 0.5)
	for i = 1, 4 do
		task.delay(i * 0.05, function()
			FX.SlashMark(g + V(rng:NextNumber(-radius / 2, radius / 2), 2, rng:NextNumber(-radius / 2, radius / 2)), rad(rng:NextNumber(-60, 60)), 9, 0.7, NEON, 0.4)
		end)
	end
	task.delay(0.35, function()
		tween(disk, 0.35, { Size = V(0.1, 0.5, 0.5), Transparency = 1 })
	end)
	cleanup(disk, 0.8)
	FX.Shake(0.4, 0.4)
	FX.Sound("Explosion", 1, 0.7, pos)
end

-- RED SPLASH: расширяющаяся красная волна, вспышка и осколки из меча
function FX.RedSplash(pos, radius, from)
	local g = V(pos.X, pos.Y + 0.2, pos.Z)
	FX.Ring(g, radius, RED, 0.5, 0.5, 1, 0.05)
	FX.Ring(g + V(0, 0.12, 0), radius * 0.7, Color3.fromRGB(255, 150, 150), 0.35, 0.25, 0.5, 0.2)
	local flash = FX.Part({ Shape = Enum.PartType.Cylinder, Size = V(0.08, radius * 1.6, radius * 1.6), CFrame = CF(g + V(0, 0.05, 0)) * ANG(0, 0, rad(90)), Color = RED, Transparency = 0.3 })
	tween(flash, 0.3, { Transparency = 1 })
	cleanup(flash, 0.35)
	FX.Sphere(pos + V(0, 1, 0), 2.5, RED, 0.25)
	if from then
		for _ = 1, FX.Lite and 2 or 6 do
			local to = g + V(rng:NextNumber(-radius, radius) * 0.7, 0.5, rng:NextNumber(-radius, radius) * 0.7)
			local shard = FX.Part({ Size = V(0.25, 0.25, 1.1), CFrame = CFrame.lookAt(from, to), Color = RED })
			tween(shard, 0.25, { CFrame = CFrame.lookAt(to, to + (to - from)), Transparency = 0.6 })
			cleanup(shard, 0.27)
		end
	end
	FX.Cracks(g, radius * 0.8, RED, 6, 0.9)
	FX.Sound("HeavyHit", 1, 0.9, pos)
end

-- рассекающий удар топора
function FX.Cleave(unitPos, center, radius, color)
	FX.Reap(unitPos, center, radius, 4, color or RED)
	FX.Ring(V(center.X, center.Y + 0.2, center.Z), radius, color or RED, 0.4, 0.3)
	FX.Sound("HeavyHit", 1, 1, center)
end

-- молот Starbreaker
function FX.Hammer(pos, radius, lv)
	FX.Shockwave(pos, radius, lv, GOLD, Color3.fromRGB(200, 140, 255))
end

-- кровавая луна падает с неба и взрывается
function FX.BloodMoonFall(pos, radius, delay)
	delay = delay or 1
	local moon = FX.Part({ Shape = Enum.PartType.Ball, Size = V(5, 5, 5), CFrame = CF(pos + V(0, 45, 0)), Color = RED })
	light(moon, RED, 40, 4)
	local mark = FX.Part({ Shape = Enum.PartType.Cylinder, Size = V(0.1, radius * 2, radius * 2), CFrame = CF(pos + V(0, 0.25, 0)) * ANG(0, 0, rad(90)), Color = RED, Transparency = 0.75 })
	tween(moon, delay, { CFrame = CF(pos + V(0, 2, 0)), Size = V(7, 7, 7) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	tween(mark, delay, { Transparency = 0.4 })
	task.delay(delay, function()
		moon:Destroy()
		mark:Destroy()
	end)
	FX.Sound("Boss", 0.6, 1.4, pos)
end

function FX.BloodMoonBoom(pos, radius)
	FX.Shockwave(pos, radius, 5, RED, Color3.fromRGB(255, 140, 140))
	FX.Sphere(pos + V(0, 2, 0), radius * 0.6, Color3.fromRGB(120, 0, 15), 0.6, Enum.Material.Neon, 0.3)
	FX.Shake(0.6, 0.6)
end

-- пробивающий лунный луч
function FX.PierceBeam(from, to)
	FX.Beam(from + V(0, 3, 0), to + V(0, 1.5, 0), 2.2, Color3.fromRGB(255, 190, 215), 0.45, true)
	FX.Sound("Laser", 1, 1.2, from)
end

return FX
]======] }
FILES[#FILES + 1] = { "StarterPlayerScripts", { "VoidTDClient", "Renderer" }, "ModuleScript", [======[
--!nocheck
-- VOID TD :: Renderer (клиент)
-- Визуализация врагов и юнитов: модели, плавное движение, анимации, полоски HP.

local RunService = game:GetService("RunService")

local Renderer = {}

local V = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles
local rad = math.rad

local ctx, Config, PathUtil, UnitModels, EnemyModels, FX
local enemyFolder, unitFolder
local enemyViews = {}
local unitViews = {}
Renderer.EnemyViews = enemyViews
Renderer.UnitViews = unitViews

------------------------------------------------------------------------
-- АНИМАЦИИ ЮНИТОВ (ключевые кадры, углы в градусах)
------------------------------------------------------------------------
local Anims = {}

Anims.Slash = function(h)
	return {
		{ 0, {} },
		{ h * 0.75, { RS = { 150, 0, 12 }, Root = { 0, -15, 0 } } },
		{ h, { RS = { 25, 0, -12 }, LS = { -20, 0, 0 }, Root = { 4, 15, 0 } } },
		{ h + 0.2, { RS = { 15, 0, -5 } } },
		{ h + 0.5, {} },
	}
end

Anims.HeavySlash = function(h)
	return {
		{ 0, {} },
		{ h * 0.8, { RS = { 168, 0, 15 }, LS = { 40, 0, -10 }, Root = { -8, -22, 0 } } },
		{ h, { RS = { 18, 0, -15 }, LS = { 30, 0, 0 }, Root = { 12, 20, 0, -0.15 } } },
		{ h + 0.3, { RS = { 15, 0, -5 }, Root = { 6, 10, 0 } } },
		{ h + 0.65, {} },
	}
end

Anims.Bow = function(h)
	return {
		{ 0, {} },
		{ h * 0.6, { LS = { 90, 0, 0 }, RS = { 90, 0, -30 }, Root = { 0, -20, 0 } } },
		{ h, { LS = { 90, 0, 0 }, RS = { 75, 0, -65 }, Root = { 0, -20, 0 } } },
		{ h + 0.06, { LS = { 92, 0, 0 }, RS = { 95, 0, -15 }, Root = { 0, -20, 0 } } },
		{ h + 0.45, {} },
	}
end

Anims.Cast = function(h)
	return {
		{ 0, {} },
		{ h * 0.7, { RS = { 145, 0, 0 }, LS = { 30, 0, -20 }, Neck = { 12, 0, 0 } } },
		{ h, { RS = { 90, 0, 0 }, LS = { 55, 0, -25 } } },
		{ h + 0.45, {} },
	}
end

Anims.Gun = function(h)
	return {
		{ 0, {} },
		{ h, { RS = { 92, 0, 0 }, LS = { 88, 0, -30 } } },
		{ h + 0.05, { RS = { 104, 0, 0 }, LS = { 98, 0, -30 }, Root = { -5, 0, 0 } } },
		{ h + 0.18, { RS = { 92, 0, 0 }, LS = { 88, 0, -30 } } },
		{ h + 0.5, {} },
	}
end

Anims.Reap = function(h)
	return {
		{ 0, {} },
		{ h * 0.7, { RS = { 60, 0, 25 }, LS = { 50, 0, -10 }, Root = { 0, -70, 0 } } },
		{ h, { RS = { 75, 0, -15 }, LS = { 65, 0, 10 }, Root = { 6, 80, 0 } } },
		{ h + 0.25, { RS = { 60, 0, -10 }, Root = { 3, 60, 0 } } },
		{ h + 0.65, {} },
	}
end

Anims.Katana = function(h, hits, interval)
	local k = { { 0, {} }, { h * 0.7, { RS = { 125, 0, 40 }, Root = { 0, -25, 0 } } } }
	hits = hits or 1
	for i = 1, hits do
		local t = h + (i - 1) * (interval or 0.16)
		local dir = (i % 2 == 1) and 1 or -1
		k[#k + 1] = { t, { RS = { 45, 0, -50 * dir }, Root = { 4, 30 * dir, 0 } } }
		if i < hits then
			k[#k + 1] = { t + (interval or 0.16) * 0.6, { RS = { 120, 0, 40 * -dir }, Root = { 0, -20 * dir, 0 } } }
		end
	end
	local last = h + (hits - 1) * (interval or 0.16)
	k[#k + 1] = { last + 0.15, { RS = { 30, 0, -30 } } }
	k[#k + 1] = { last + 0.4, {} }
	return k
end

Anims.Slam = function(h)
	return {
		{ 0, {} },
		{ h * 0.65, { RS = { 172, 0, 10 }, LS = { 165, 0, -10 }, Root = { -10, 0, 0, 0.15 }, Neck = { -10, 0, 0 } } },
		{ h, { RS = { 55, 0, 0 }, LS = { 50, 0, 0 }, Root = { 16, 0, 0, -0.45 } } },
		{ h + 0.35, { RS = { 48, 0, 0 }, LS = { 45, 0, 0 }, Root = { 12, 0, 0, -0.35 } } },
		{ h + 0.85, {} },
	}
end

Anims.Beam = function(h)
	return {
		{ 0, {} },
		{ h * 0.6, { RS = { 55, 0, 0 }, Root = { -6, 0, 0 }, WingR = { 0, 25, 0 }, WingL = { 0, -25, 0 } } },
		{ h, { RS = { 96, 0, 0 }, LS = { 60, 0, -20 }, Root = { 4, 0, 0 }, WingR = { 0, -15, 10 }, WingL = { 0, 15, -10 } } },
		{ h + 0.45, { RS = { 94, 0, 0 }, LS = { 55, 0, -20 } } },
		{ h + 0.85, {} },
	}
end

Anims.Judgement = function(h, hits, interval)
	local hold = h + (hits or 3) * (interval or 0.18)
	return {
		{ 0, {} },
		{ h * 0.8, { RS = { 178, 0, 5 }, LS = { 35, 0, -35 }, Neck = { 18, 0, 0 }, Root = { -6, 0, 0, 0.2 } } },
		{ hold, { RS = { 172, 0, 5 }, LS = { 40, 0, -40 }, Neck = { 15, 0, 0 }, Root = { -4, 0, 0, 0.2 } } },
		{ hold + 0.2, { RS = { 40, 0, -10 }, Root = { 10, 0, 0 } } },
		{ hold + 0.6, {} },
	}
end

Anims.Smash = function(h)
	return {
		{ 0, {} },
		{ h * 0.7, { RS = { 160, 0, 10 }, Root = { -8, -18, 0 } } },
		{ h, { RS = { 40, 0, -10 }, LS = { 30, 0, 0 }, Root = { 14, 18, 0, -0.3 } } },
		{ h + 0.45, {} },
	}
end

Anims.BlackHoleCast = function(h)
	return {
		{ 0, {} },
		{ h * 0.7, { RS = { 150, 0, 30 }, LS = { 150, 0, -30 }, Neck = { 25, 0, 0 }, Root = { -8, 0, 0, 0.2 } } },
		{ h, { RS = { 110, 0, 40 }, LS = { 110, 0, -40 }, Root = { 6, 0, 0 } } },
		{ h + 0.5, {} },
	}
end

-- Анимации в простое (fidget), повышения уровня, празднования и приземления
Anims.LookAround = function()
	return { { 0, {} }, { 0.5, { Neck = { 0, 40, 0 } } }, { 1.2, { Neck = { 5, -40, 0 } } }, { 1.8, {} } }
end

Anims.Twirl = function()
	return {
		{ 0, {} },
		{ 0.25, { RS = { 85, 0, 0 } } },
		{ 0.45, { RS = { 85, 120, 0 } } },
		{ 0.65, { RS = { 85, 240, 0 } } },
		{ 0.85, { RS = { 85, 360, 0 } } },
		{ 1.2, { RS = { 15, 360, 0 } } },
	}
end

Anims.Flex = function()
	return {
		{ 0, {} },
		{ 0.35, { RS = { 0, 0, 95 }, LS = { 0, 0, -95 }, Root = { -4, 0, 0 } } },
		{ 0.6, { RS = { 0, 0, 80 }, LS = { 0, 0, -80 }, Root = { -6, 0, 0, 0.1 } } },
		{ 1.1, {} },
	}
end

Anims.Stretch = function()
	return {
		{ 0, {} },
		{ 0.5, { RS = { 170, 0, 15 }, LS = { 170, 0, -15 }, Root = { -8, 0, 0, 0.15 }, Neck = { -15, 0, 0 } } },
		{ 1.1, { RS = { 165, 0, 20 }, LS = { 165, 0, -20 }, Root = { -6, 0, 0, 0.1 }, Neck = { -10, 0, 0 } } },
		{ 1.6, {} },
	}
end

Anims.StaffTap = function()
	return {
		{ 0, {} },
		{ 0.25, { RS = { 35, 0, 0 } } },
		{ 0.4, { RS = { -5, 0, 0 }, Root = { 0, 0, 0, -0.08 } } },
		{ 0.55, { RS = { 25, 0, 0 } } },
		{ 0.7, { RS = { -5, 0, 0 }, Root = { 0, 0, 0, -0.08 } } },
		{ 1.1, {} },
	}
end

Anims.CheckBow = function()
	return {
		{ 0, {} },
		{ 0.4, { LS = { 75, 0, 35 }, Neck = { 20, -25, 0 }, RS = { 40, 0, -20 } } },
		{ 1.3, { LS = { 70, 0, 30 }, Neck = { 22, -20, 0 }, RS = { 45, 0, -25 } } },
		{ 1.7, {} },
	}
end

Anims.Reload = function()
	return {
		{ 0, {} },
		{ 0.3, { RS = { 45, 0, -30 }, LS = { 60, 0, 25 }, Neck = { 25, 0, 0 } } },
		{ 0.5, { RS = { 45, 0, -30 }, LS = { 40, 0, 10 }, Neck = { 25, 0, 0 } } },
		{ 0.7, { RS = { 45, 0, -30 }, LS = { 65, 0, 25 }, Neck = { 25, 0, 0 } } },
		{ 1.2, {} },
	}
end

Anims.WingSpread = function()
	return {
		{ 0, {} },
		{ 0.4, { WingR = { 0, -35, 20 }, WingL = { 0, 35, -20 }, Neck = { -15, 0, 0 }, Root = { 0, 0, 0, 0.3 } } },
		{ 1.0, { WingR = { 0, -30, 15 }, WingL = { 0, 30, -15 }, Neck = { -10, 0, 0 }, Root = { 0, 0, 0, 0.25 } } },
		{ 1.5, {} },
	}
end

Anims.Cheer = function()
	return {
		{ 0, {} },
		{ 0.2, { RS = { 165, 0, 25 }, LS = { 165, 0, -25 }, Root = { 0, 0, 0, 0.6 } } },
		{ 0.4, { RS = { 150, 0, 30 }, LS = { 150, 0, -30 }, Root = { 0, 0, 0, 0 } } },
		{ 0.6, { RS = { 165, 0, 25 }, LS = { 165, 0, -25 }, Root = { 0, 0, 0, 0.6 } } },
		{ 0.8, { RS = { 150, 0, 30 }, LS = { 150, 0, -30 }, Root = { 0, 0, 0, 0 } } },
		{ 1.2, {} },
	}
end

Anims.PowerUp = function()
	return {
		{ 0, {} },
		{ 0.25, { Root = { 12, 0, 0, -0.45 }, RS = { 30, 0, 35 }, LS = { 30, 0, -35 }, Neck = { 15, 0, 0 } } },
		{ 0.5, { Root = { -10, 0, 0, 0.6 }, RS = { 160, 0, 40 }, LS = { 160, 0, -40 }, Neck = { -20, 0, 0 } } },
		{ 0.9, { Root = { -6, 0, 0, 0.3 }, RS = { 150, 0, 35 }, LS = { 150, 0, -35 } } },
		{ 1.3, {} },
	}
end

Anims.Land = function()
	return {
		{ 0, { Root = { 10, 0, 0, -0.45 }, RS = { 20, 0, 45 }, LS = { 20, 0, -45 } } },
		{ 0.45, {} },
	}
end

-- анимации новых юнитов
Anims.DualDagger = function(h)
	return {
		{ 0, {} },
		{ h * 0.6, { RS = { 110, 0, 20 }, LS = { 40, 0, -10 }, Root = { 0, -20, 0 } } },
		{ h, { RS = { 60, 0, -20 }, LS = { 100, 0, -20 }, Root = { 4, 20, 0 } } },
		{ h + 0.12, { RS = { 75, 0, 0 }, LS = { 70, 0, 0 } } },
		{ h + 0.3, {} },
	}
end
Anims.Crossbow = function(h)
	return {
		{ 0, {} },
		{ h, { RS = { 88, 0, 0 }, LS = { 82, 0, -28 }, Neck = { 6, 0, 0 } } },
		{ h + 0.06, { RS = { 105, 0, 0 }, LS = { 96, 0, -28 }, Root = { -6, 0, 0 } } },
		{ h + 0.3, { RS = { 88, 0, 0 }, LS = { 82, 0, -28 } } },
		{ h + 0.6, {} },
	}
end
Anims.Puppet = function(h)
	return {
		{ 0, {} },
		{ h * 0.7, { RS = { 85, 0, 35 }, LS = { 85, 0, -35 }, Neck = { 10, 0, 0 } } },
		{ h, { RS = { 105, 0, 12 }, LS = { 105, 0, -12 } } },
		{ h + 0.15, { RS = { 90, 0, 28 }, LS = { 90, 0, -28 } } },
		{ h + 0.5, {} },
	}
end
Anims.Hammer = Anims.Slam
Anims.RiftStorm = Anims.Judgement
Anims.RedSplash = Anims.HeavySlash
Anims.Sickle = Anims.Slash
Anims.Axe = Anims.HeavySlash
Anims.Revolver = function(h)
	return {
		{ 0, {} },
		{ h, { RS = { 95, 0, 0 }, LS = { 70, 0, 0 } } },
		{ h + 0.05, { RS = { 112, 0, 0 }, LS = { 70, 0, 0 }, Root = { -3, 0, 0 } } },
		{ h + 0.12, { RS = { 92, 0, 0 }, LS = { 95, 0, 0 } } },
		{ h + 0.17, { RS = { 92, 0, 0 }, LS = { 112, 0, 0 }, Root = { -3, 0, 0 } } },
		{ h + 0.45, {} },
	}
end

local FIDGETS = {
	DualDagger = { "Twirl", "LookAround", "Flex" },
	Crossbow = { "Reload", "LookAround" },
	Puppet = { "Stretch", "LookAround" },
	Hammer = { "Flex", "Stretch", "LookAround" },
	RiftStorm = { "LookAround", "Stretch" },
	RedSplash = { "Twirl", "Flex" },
	Sickle = { "Twirl", "LookAround" },
	Revolver = { "Twirl", "Reload" },
	Axe = { "Flex", "LookAround" },
	Slash = { "Twirl", "LookAround", "Flex" },
	HeavySlash = { "Twirl", "LookAround", "Stretch" },
	Katana = { "Twirl", "LookAround" },
	Judgement = { "Twirl", "LookAround", "Flex" },
	Bow = { "CheckBow", "LookAround" },
	Cast = { "StaffTap", "LookAround", "Stretch" },
	Gun = { "Reload", "LookAround" },
	Reap = { "Twirl", "LookAround" },
	Slam = { "Flex", "LookAround", "Stretch" },
	Smash = { "Flex", "LookAround" },
	Beam = { "WingSpread", "LookAround", "Stretch" },
}

local function ease(a)
	return a * a * (3 - 2 * a)
end

local function getAngle(pose, idle, joint)
	return pose[joint] or idle[joint]
end

local function evalPose(view, t)
	local idle = view.Rig.Idle
	local anim = view.Anim
	if not anim then
		return idle
	end
	local el = t - anim.Start
	local frames = anim.Frames
	if el >= frames[#frames][1] then
		view.Anim = nil
		return idle
	end
	local k = 1
	for i = 1, #frames - 1 do
		if el >= frames[i][1] then
			k = i
		end
	end
	local f0, f1 = frames[k], frames[k + 1]
	local span = math.max(f1[1] - f0[1], 0.001)
	local a = ease(math.clamp((el - f0[1]) / span, 0, 1))
	local out = {}
	local joints = {}
	for j in pairs(f0[2]) do
		joints[j] = true
	end
	for j in pairs(f1[2]) do
		joints[j] = true
	end
	for j in pairs(idle) do
		joints[j] = true
	end
	for j in pairs(joints) do
		local p0 = getAngle(f0[2], idle, j) or { 0, 0, 0, 0 }
		local p1 = getAngle(f1[2], idle, j) or { 0, 0, 0, 0 }
		out[j] = {
			p0[1] + (p1[1] - p0[1]) * a,
			p0[2] + (p1[2] - p0[2]) * a,
			p0[3] + (p1[3] - p0[3]) * a,
			(p0[4] or 0) + ((p1[4] or 0) - (p0[4] or 0)) * a,
		}
	end
	return out
end

local function applyPose(rig, pose, t, phase)
	local base = rig.Base
	local s = rig.Scale or 1
	local breathe = math.sin(t * 2 + phase)
	for name, motor in pairs(rig.Motors) do
		local b = base[name]
		if b then
			local p = pose[name]
			local cf = b
			if name == "Root" then
				local dy = (p and p[4] or 0) * s + breathe * 0.04 * s
				cf = b * CF(0, dy, 0)
			end
			if p then
				cf = cf * ANG(rad(p[1]), rad(p[2]), rad(p[3]))
			end
			if name == "RS" or name == "LS" then
				local side = name == "RS" and 1 or -1
				cf = cf * ANG(rad(breathe * 2), 0, rad(breathe * 1.5 * side))
			elseif name:sub(1, 4) == "Wing" then
				local side = name:sub(5, 5) == "R" and 1 or -1
				cf = cf * ANG(0, math.sin(t * 2.4 + phase) * 0.12 * side, math.sin(t * 2.4 + phase) * 0.1 * side)
			elseif name == "Neck" then
				cf = cf * ANG(0, math.sin(t * 0.7 + phase) * 0.08, 0)
			elseif name == "Cape" or name == "Scarf" then
				local gust = (rig.Gust or 0)
				cf = cf * ANG(rad(6 + math.sin(t * 1.7 + phase) * 4 + gust * 22), 0, rad(math.sin(t * 1.1 + phase) * 3))
			elseif name == "Cape2" then
				-- нижняя часть плаща догоняет верхнюю с запаздыванием
				local gust = (rig.Gust or 0)
				cf = cf * ANG(rad(5 + math.sin(t * 1.7 + phase - 0.8) * 7 + gust * 28), 0, rad(math.sin(t * 1.1 + phase - 0.6) * 5))
			elseif name:sub(1, 5) == "Orbit" then
				cf = cf * ANG(0, t * 1.4 + phase, 0)
			end
			motor.C0 = cf
		end
	end
end

------------------------------------------------------------------------
-- ВРАГИ
------------------------------------------------------------------------
local function makeHealthBar(view)
	local def = Config.Enemies[view.Type]
	local gui = Instance.new("BillboardGui")
	gui.Name = "HPBar"
	gui.Size = UDim2.fromOffset(def.IsBoss and 120 or 60, def.IsBoss and 12 or 7)
	gui.StudsOffsetWorldSpace = V(0, view.Rig.Height - view.Rig.HipHeight + 1.2, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 180
	gui.LightInfluence = 0
	gui.Adornee = view.Rig.Root
	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Color3.fromRGB(20, 10, 25)
	bg.BorderSizePixel = 0
	bg.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 3)
	corner.Parent = bg
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = def.IsBoss and Color3.fromRGB(235, 50, 130) or Color3.fromRGB(190, 80, 255)
	fill.BorderSizePixel = 0
	fill.Parent = bg
	local c2 = corner:Clone()
	c2.Parent = fill
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(0, 0, 0)
	stroke.Thickness = 1
	stroke.Parent = bg
	gui.Parent = view.Rig.Root
	view.Fill = fill
end

------------------------------------------------------------------------
-- ВТОРИЧНОЕ ДВИЖЕНИЕ (по префиксу имени мотора, см. EnemyModels)
------------------------------------------------------------------------
local SEC_KINDS = { "Sway", "Cape", "Orbit", "Spin", "Bob", "Twitch" }
local LOD_DISTANCE = 200 -- дальше этого от камеры вторичная анимация не считается

local function collectSecondary(rig)
	local list = {}
	for name, motor in pairs(rig.Motors) do
		for _, kind in ipairs(SEC_KINDS) do
			if name:sub(1, #kind) == kind and rig.Base[name] then
				local p = (rig.Sec and rig.Sec[name]) or {}
				list[#list + 1] = { Motor = motor, Base = rig.Base[name], Kind = kind, Amp = p.Amp or 0.2, Speed = p.Speed or 1.5, Phase = math.random() * 6 }
				break
			end
		end
	end
	return list
end

local function applySecondary(view, t, dt)
	local sc = view.Rig.Scale or 1
	local aggro = view.Aggro or 1
	for _, s in ipairs(view.Sec) do
		local k, ph = s.Kind, s.Phase
		local cf
		if k == "Sway" or k == "Cape" then
			local sp = s.Speed * (0.8 + 0.2 * aggro)
			cf = s.Base * ANG(math.sin(t * sp + ph) * s.Amp + (k == "Cape" and s.Amp * 0.8 or 0), 0, math.sin(t * sp * 0.7 + ph) * s.Amp * 0.5)
		elseif k == "Orbit" then
			cf = s.Base * ANG(0, t * s.Speed * aggro + ph, 0)
		elseif k == "Spin" then
			cf = s.Base * ANG(0, 0, t * s.Speed * aggro + ph)
		elseif k == "Bob" then
			cf = s.Base * CF(0, math.sin(t * s.Speed + ph) * s.Amp * sc, 0) * ANG(0, math.sin(t * s.Speed * 0.5 + ph) * 0.25, 0)
		else -- Twitch: резкий поворот к случайной цели, пауза, снова рывок
			if t >= (s.Next or 0) then
				s.Next = t + 0.25 + math.random() * 0.7
				s.TY = (math.random() * 2 - 1) * s.Amp
				s.TP = (math.random() * 2 - 1) * s.Amp * 0.5
			end
			local a = math.min(1, dt * 22)
			s.Y = (s.Y or 0) + ((s.TY or 0) - (s.Y or 0)) * a
			s.P = (s.P or 0) + ((s.TP or 0) - (s.P or 0)) * a
			cf = s.Base * ANG(s.P, s.Y, 0)
		end
		s.Motor.C0 = cf
	end
end

------------------------------------------------------------------------
-- ВИЗУАЛЬНЫЕ ФАЗЫ БОССОВ (только внешний вид, без новых способностей)
------------------------------------------------------------------------
local function groundOf(view)
	return view.Rig.Root.Position - V(0, view.Rig.HipHeight - 0.3, 0)
end

-- Деталь отрывается от модели и падает на землю
local function breakPart(view, p, silent)
	if not p or not p.Parent then
		return
	end
	local cf = p.CFrame
	for _, w in ipairs(p:GetChildren()) do
		if w:IsA("Weld") then
			w:Destroy()
		end
	end
	if silent or FX.Lite then
		p:Destroy()
		return
	end
	p.Anchored = true
	p.CFrame = cf
	p.Parent = workspace:FindFirstChild("VoidTD_FX") or workspace
	local root = view.Rig.Root.Position
	local out = V(cf.Position.X - root.X, 0, cf.Position.Z - root.Z)
	out = out.Magnitude > 0.01 and out.Unit or V(0, 0, 1)
	local groundY = root.Y - view.Rig.HipHeight + p.Size.Y * 0.3
	local dest = V(cf.Position.X, groundY, cf.Position.Z) + out * (2 + math.random() * 4)
	FX.Tween(p, 0.35, { CFrame = cf + out * 1.5 + V(0, 1.5, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	task.delay(0.35, function()
		if p.Parent then
			FX.Tween(p, 0.6, { CFrame = CF(dest) * ANG(math.random() * 3, math.random() * 3, math.random() * 3) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		end
	end)
	task.delay(1.6, function()
		if p.Parent then
			FX.Tween(p, 0.8, { Transparency = 1 })
		end
	end)
	task.delay(2.5, function()
		p:Destroy()
	end)
end

local function applyPhase(view, idx, silent)
	local ph = view.Rig.Phases[idx]
	view.VisualPhase = idx + 1
	view.Aggro = ph.Aggro or view.Aggro
	for _, p in ipairs(ph.Reveal or {}) do
		local target = p:GetAttribute("PT") or 0
		if silent or FX.Lite then
			p.Transparency = target
		else
			FX.Tween(p, 0.6, { Transparency = target })
		end
	end
	for _, e in ipairs(ph.Emit or {}) do
		if e then
			if e.Enabled then
				e.Rate = e.Rate * 1.8
			else
				e.Enabled = true
			end
		end
	end
	for _, l in ipairs(ph.Lights or {}) do
		if l[1] then
			l[1].Brightness = l[2]
			l[1].Range = l[1].Range * 1.25
		end
	end
	for _, p in ipairs(ph.Break or {}) do
		breakPart(view, p, silent)
	end
	if silent then
		return
	end
	-- переход: рёв, волна энергии, вспышка
	local sc = view.Rig.Scale or 1
	local center = Renderer.EnemyCenter(view.Id) or view.Rig.Root.Position
	view.RoarT = os.clock()
	FX.Sound("Boss", 1, 0.8 + idx * 0.12, center)
	FX.Shake(0.3 + idx * 0.15, 0.6)
	FX.Ring(groundOf(view), 8 * sc, FX.Colors.Neon, 0.8, 0.5, 1, 0.05)
	FX.Sphere(center, 2.5 * sc, FX.Colors.Soft, 0.5)
	FX.Burst(center, FX.Colors.Neon, 16, 0.4 * sc, 9 * sc, 0.7)
end

local function checkPhases(view, silent)
	local phases = view.Rig.Phases
	if not phases then
		return
	end
	local ratio = view.HP / math.max(view.MaxHP, 1)
	while phases[view.NextPhase] and ratio <= phases[view.NextPhase].At do
		applyPhase(view, view.NextPhase, silent)
		view.NextPhase = view.NextPhase + 1
	end
end

------------------------------------------------------------------------
-- ПОЯВЛЕНИЕ
------------------------------------------------------------------------
-- Вступление босса: портал вспыхивает, по земле идёт волна энергии
local function portalSurge(isFinal)
	local map = workspace:FindFirstChild("VoidTDMap")
	local portal = map and map:FindFirstChild("VoidPortal")
	if not portal then
		return
	end
	local disc = portal:FindFirstChild("PortalDisc")
	local core = portal:FindFirstChild("PortalCore")
	local light = core and core:FindFirstChildOfClass("PointLight")
	if light then
		local b = light.Brightness
		light.Brightness = b * 3
		FX.Tween(light, 1.8, { Brightness = b })
	end
	if disc then
		local col = disc.Color
		disc.Color = Color3.fromRGB(235, 200, 255)
		FX.Tween(disc, 1.2, { Color = col })
		local pos = disc.Position
		local gy = Config.Map.GroundY
		FX.Sphere(pos, isFinal and 16 or 11, FX.Colors.Neon, 0.8, nil, 0.3)
		FX.Ring(V(pos.X, gy + 0.3, pos.Z), isFinal and 45 or 30, FX.Colors.Neon, 1.1, 0.6, 3, 0.05)
		task.delay(0.15, function()
			FX.Ring(V(pos.X, gy + 0.4, pos.Z), isFinal and 32 or 22, FX.Colors.White, 0.9, 0.3, 2, 0.2)
		end)
		FX.Burst(pos, FX.Colors.Soft, isFinal and 30 or 18, 0.7, 18, 0.9)
	end
	FX.Sound("Portal", 1.2, isFinal and 0.7 or 0.85)
end

function Renderer.SpawnEnemy(data)
	local id, typeId, maxHp, speed, lateral, dist, hp = data[1], data[2], data[3], data[4], data[5], data[6], data[7]
	if enemyViews[id] then
		return
	end
	local ok, rig = pcall(EnemyModels.Build, typeId)
	if not ok then
		warn(rig)
		return
	end
	local def = Config.Enemies[typeId]
	local view = {
		Id = id,
		Type = typeId,
		Rig = rig,
		MaxHP = maxHp,
		HP = hp or maxHp,
		Speed = speed,
		Lateral = lateral,
		Dist = dist,
		ServerDist = dist,
		LastSync = os.clock(),
		Slowed = false,
		Phase = math.random() * 10,
		Aggro = 1,
		NextPhase = 1,
		VisualPhase = 1,
	}
	view.Sec = collectSecondary(rig)
	local pos, dir = PathUtil.OffsetPositionAt(dist, lateral)
	view.CF = CFrame.lookAt(pos + V(0, rig.HipHeight, 0), pos + dir + V(0, rig.HipHeight, 0))
	view.SpawnT = os.clock()
	view.Emerge = dist <= 1
	-- если враг пришёл уже раненым (переподключение) — фазы применяются без эффектов
	checkPhases(view, true)
	if def.IsBoss then
		view.RoarT = os.clock() + (rig.SpawnStyle == "Titan" and 1.1 or 0.6)
		if dist <= 1 then
			portalSurge(typeId == "TheEntity")
		end
		task.delay(0.6, function()
			FX.Sound("Boss", 1, typeId == "TheEntity" and 0.75 or 1)
			FX.Shake(typeId == "TheEntity" and 0.8 or 0.5, 1.0)
		end)
	end
	-- появление из дыма: прозрачность плавно возвращается
	if rig.SpawnStyle == "Fade" and not FX.Lite then
		view.FadeParts = {}
		for _, d in ipairs(rig.Model:GetDescendants()) do
			if d:IsA("BasePart") and d.Transparency < 1 then
				view.FadeParts[#view.FadeParts + 1] = { d, d.Transparency }
				d.Transparency = 1
			end
		end
	end
	rig.Root.CFrame = view.CF
	makeHealthBar(view)
	rig.Model.Parent = enemyFolder
	enemyViews[id] = view
	if dist <= 1 then
		FX.Burst(pos + V(0, 2, 0), FX.Colors.Neon, 6, 0.3, 5)
		if rig.SpawnStyle == "Titan" then
			-- мини-босс выбирается из земли и выпрямляется, кристалл в груди вспыхивает
			FX.Cracks(pos + V(0, 0.2, 0), 7, FX.Colors.Neon, 10, 1.6)
			task.delay(1.1, function()
				local c = Renderer.EnemyCenter(id)
				if c then
					FX.Sphere(c, 4, FX.Colors.Neon, 0.5)
					FX.Burst(c, FX.Colors.Soft, 14, 0.5, 10, 0.6)
				end
			end)
		end
	end
end

function Renderer.EnemyPosition(id)
	local v = enemyViews[id]
	if v then
		return v.Rig.Root.Position
	end
	return nil
end

function Renderer.EnemyCenter(id)
	local v = enemyViews[id]
	if v then
		return v.Rig.Root.Position + V(0, (v.Rig.Height - v.Rig.HipHeight) * 0.35, 0)
	end
	return nil
end

------------------------------------------------------------------------
-- СМЕРТЬ (своя анимация для каждого типа)
------------------------------------------------------------------------
local DEATH_LIFE = { Dissipate = 0.7, Scatter = 0.85, Collapse = 0.75, Topple = 1.0, Implode = 2.4 }
local LEGS = { FR = 1, BR = 1, FL = -1, BL = -1 }

local function deathAnim(view, reason)
	local rig = view.Rig
	local model = rig.Model
	local root = rig.Root
	local gui = root:FindFirstChild("HPBar")
	if gui then
		gui:Destroy()
	end
	local def = Config.Enemies[view.Type]
	local size = def.Scale or 1
	if reason == "core" then
		FX.Poof(root.Position, FX.Colors.Pink, size)
		model:Destroy()
		return
	end
	local style = rig.DeathStyle or "Topple"
	local sc = rig.Scale or 1
	local hip = rig.HipHeight
	if style ~= "Implode" then
		FX.Poof(root.Position + V(0, 0.5, 0), FX.Colors.Neon, size)
	end
	FX.Sound("EnemyDeath", 1, 1 / math.max(size, 0.6), root.Position)
	if def.IsBoss and style ~= "Implode" then
		FX.Shockwave(root.Position - V(0, hip - 0.2, 0), 10 * size, 5)
	end
	local start = os.clock()
	local startCF = root.CFrame
	local life = DEATH_LIFE[style] or 1
	if def.IsBoss and style == "Topple" then
		life = 1.5
	end
	local parts = {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and d.Transparency < 1 then
			parts[#parts + 1] = { d, d.Transparency }
		elseif d:IsA("ParticleEmitter") or d:IsA("Trail") then
			d.Enabled = false
		end
	end
	-- исходные C0 моторов (для разлёта частей и подкашивания лап)
	local motors = {}
	for name, m in pairs(rig.Motors) do
		if name ~= "Root" then
			local dir = V(math.random() - 0.5, math.random() * 0.6, math.random() - 0.5)
			motors[#motors + 1] = { m, m.C0, name, dir.Magnitude > 0.01 and dir.Unit or V(0, 1, 0) }
		end
	end
	if style == "Dissipate" then
		FX.Burst(root.Position, FX.Colors.Soft, 10, 0.4 * size, 4, 0.9)
	elseif style == "Implode" then
		FX.Sound("Boss", 1.2, 0.6, root.Position)
		FX.Shake(0.6, life)
	end
	local exploded = false
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local a = math.clamp((os.clock() - start) / life, 0, 1)
		local fade = a
		if style == "Dissipate" then
			-- дух растворяется вверх, закручиваясь
			root.CFrame = startCF * CF(0, ease(a) * 2.5 * sc, 0) * ANG(0, a * 4, 0)
		elseif style == "Scatter" then
			-- разделённые части разлетаются в стороны
			root.CFrame = startCF * CF(0, a * 1.2 * sc, 0)
			for _, mm in ipairs(motors) do
				mm[1].C0 = mm[2] * CF(mm[4] * ease(a) * 3 * sc) * ANG(a * mm[4].X * 4, a * 3, a * mm[4].Z * 4)
			end
		elseif style == "Collapse" then
			-- лапы разъезжаются, тело падает на землю
			root.CFrame = startCF * CF(0, -ease(a) * hip * 0.7, 0) * ANG(rad(-8 * a), 0, rad(20 * ease(a)))
			for _, mm in ipairs(motors) do
				local side = LEGS[mm[3]]
				if side then
					mm[1].C0 = mm[2] * ANG(0, 0, side * ease(a) * 1.1)
				end
			end
			fade = math.clamp((a - 0.4) / 0.6, 0, 1)
		elseif style == "Implode" then
			-- финальный босс: дрожит, поднимается, раскидывает руки, затем коллапсирует во вспышке
			if a < 0.55 then
				local k = a / 0.55
				root.CFrame = startCF * CF((math.random() - 0.5) * 0.4 * k * sc, k * 1.5 * sc, 0) * ANG(rad(-15 * k), 0, 0)
				for _, mm in ipairs(motors) do
					if mm[3] == "RS" or mm[3] == "LS" then
						mm[1].C0 = mm[2] * ANG(rad(120 * k), 0, rad((mm[3] == "RS" and 40 or -40) * k))
					end
				end
				if math.random() < 0.25 and not FX.Lite then
					FX.Burst(root.Position + V((math.random() - 0.5) * 6 * sc, (math.random() - 0.3) * 6 * sc, (math.random() - 0.5) * 6 * sc), FX.Colors.Neon, 3, 0.4 * sc, 6, 0.4)
				end
				fade = 0
			else
				if not exploded then
					exploded = true
					local g = root.Position - V(0, hip - 0.2, 0)
					FX.Sphere(root.Position, 9 * sc, FX.Colors.White, 0.6)
					FX.Sphere(root.Position, 14 * sc, FX.Colors.Neon, 0.9, nil, 0.2)
					FX.Shockwave(g, 14 * size, 5)
					FX.Burst(root.Position, FX.Colors.Soft, 30, 0.8, 22, 1)
					FX.Shake(1.2, 0.8)
				end
				local k = (a - 0.55) / 0.45
				root.CFrame = startCF * CF(0, 1.5 * sc - ease(k) * hip * 0.6, 0) * ANG(rad(-15 + 30 * k), k * 2, 0)
				fade = k
			end
		else -- Topple: колени подгибаются, тело валится вперёд
			root.CFrame = startCF * CF(0, -a * hip * 0.8, 0) * ANG(rad(-75 * ease(a)), 0, rad(15 * a))
			for _, mm in ipairs(motors) do
				if mm[3] == "RS" or mm[3] == "LS" then
					mm[1].C0 = mm[2] * ANG(rad(70 * ease(a)), 0, 0)
				elseif mm[3] == "RH" or mm[3] == "LH" then
					mm[1].C0 = mm[2] * ANG(rad(40 * ease(a)), 0, 0)
				end
			end
			fade = math.clamp((a - 0.3) / 0.7, 0, 1)
		end
		for _, p in ipairs(parts) do
			p[1].Transparency = p[2] + (1 - p[2]) * fade
		end
		if a >= 1 then
			conn:Disconnect()
			model:Destroy()
		end
	end)
end

function Renderer.RemoveEnemy(id, reason)
	local view = enemyViews[id]
	if not view then
		return
	end
	enemyViews[id] = nil
	if reason == "clear" then
		FX.Poof(view.Rig.Root.Position, FX.Colors.Neon, 0.8)
		view.Rig.Model:Destroy()
	else
		deathAnim(view, reason)
	end
end

function Renderer.OnSync(payload)
	local list = payload.E
	local nowc = os.clock()
	for i = 1, #list, 4 do
		local v = enemyViews[list[i]]
		if v then
			v.ServerDist = list[i + 1]
			if list[i + 2] < v.HP then
				v.HitT = nowc
			end
			v.HP = list[i + 2]
			v.Slowed = list[i + 3] == 1
			v.LastSync = nowc
		end
	end
	for _, d in ipairs(payload.DMG or {}) do
		local pos = Renderer.EnemyCenter(d[1])
		if pos then
			FX.DamageNumber(pos + V(0, 1.5, 0), d[2], d[3])
		end
	end
	for _, r in ipairs(payload.RM or {}) do
		Renderer.RemoveEnemy(r[1], r[2])
	end
end

------------------------------------------------------------------------
-- ХОДЬБА / ПАРЕНИЕ
------------------------------------------------------------------------
local DUST = Color3.fromRGB(70, 60, 82)

local function heavyStep(view, power, camDist)
	if camDist < 90 then
		FX.Shake(power * (1 - camDist / 90), 0.18)
	end
	if not FX.Lite and camDist < 120 then
		local sc = view.Rig.Scale or 1
		FX.Ring(groundOf(view), 2.2 * sc, DUST, 0.45, 0.2, 0.4 * sc, 0.45)
	end
end

local CRAWL_LEGS = { { "FR", 1, 0 }, { "BL", -1, 0 }, { "FL", -1, math.pi }, { "BR", 1, math.pi } }
local FLOAT_ARMS = { "ArmR", "ArmL", "ArmR2", "ArmL2", "RS", "LS" }

local function animateEnemy(view, t, dt, camDist)
	local rig = view.Rig
	local base = rig.Base
	local m = rig.Motors
	local g = rig.Gait or {}
	local sc = rig.Scale or 1
	local idle = rig.Idle or {}
	local def = Config.Enemies[view.Type]
	local aggro = view.Aggro or 1
	local far = camDist > LOD_DISTANCE
	local spd = view.Speed * (view.Slowed and 0.5 or 1)
	-- частота шага привязана к скорости врага
	local freq = spd / math.max(def.Scale or 1, 0.5) * 1.1 * (g.Speed or 1) * (1 + (aggro - 1) * 0.3)
	view.W = (view.W or view.Phase) + dt * freq
	local w = view.W
	local s = math.sin(w)
	local stride = (g.Stride or 0.55) * (0.85 + 0.15 * aggro)
	local bob = (g.Bob or 0.12) * sc
	local hitA = t - (view.HitT or -10)
	local flinch = hitA < 0.22 and (1 - hitA / 0.22) * (def.IsBoss and 0.35 or 1) or 0

	local function pose(name, x, y, z)
		local b = base[name]
		if not b or not m[name] then
			return
		end
		local id = idle[name]
		if id then
			m[name].C0 = b * ANG(rad(id[1]) + x, rad(id[2]) + y, rad(id[3]) + z)
		else
			m[name].C0 = b * ANG(x, y, z)
		end
	end
	local idleRoot = idle.Root and rad(idle.Root[1]) or 0

	local rootCF
	local style = rig.Style
	if style == "Biped" or style == "Heavy" then
		local heavy = style == "Heavy"
		pose("RH", s * stride, 0, 0)
		pose("LH", -s * stride, 0, 0)
		local arm = stride * (heavy and 0.55 or 0.8) * aggro
		pose("RS", -s * arm, 0, heavy and math.abs(s) * 0.08 or 0)
		pose("LS", s * arm, 0, heavy and -math.abs(s) * 0.08 or 0)
		local sway = g.Sway or 0.04
		local lean = rad((g.Lean or 0) + (aggro - 1) * 20)
		-- тяжёлые проседают на каждом шаге, лёгкие подпрыгивают
		local y = heavy and ((1 - math.abs(s)) * bob - bob * 0.5) or math.abs(s) * bob
		rootCF = base.Root * CF(0, y, 0) * ANG(idleRoot + lean, s * sway * 0.5, -s * sway)
		pose("Neck", heavy and -math.abs(s) * 0.05 or 0, 0, s * sway * 0.8)
		local c = math.cos(w)
		if g.Shake and not far and view.LastC and (view.LastC > 0) ~= (c > 0) then
			heavyStep(view, g.Shake * (0.8 + 0.2 * aggro), camDist)
		end
		view.LastC = c
	elseif style == "Gallop" then
		-- галоп: передние лапы парой, задние парой со сдвигом
		pose("FR", s * stride, 0, 0)
		pose("FL", math.sin(w + 0.35) * stride, 0, 0)
		pose("BR", math.sin(w - 1.6) * stride, 0, 0)
		pose("BL", math.sin(w - 1.25) * stride, 0, 0)
		rootCF = base.Root * CF(0, math.abs(s) * bob, 0) * ANG(math.cos(w) * 0.09, 0, 0)
		pose("Neck", -math.cos(w) * 0.12, 0, 0)
	elseif style == "Crawl" then
		-- диагональные пары лап: мах вперёд-назад + подъём
		for _, l in ipairs(CRAWL_LEGS) do
			local p = w + l[3]
			pose(l[1], 0, math.sin(p) * stride * l[2], math.max(0, math.cos(p)) * 0.35 * l[2])
		end
		rootCF = base.Root * CF(0, math.abs(math.sin(w * 2)) * bob, 0) * ANG(0, s * 0.06, s * (g.Sway or 0.05))
	elseif style == "Quad" then
		pose("FR", s * 0.6, 0, 0)
		pose("BL", s * 0.6, 0, 0)
		pose("FL", -s * 0.6, 0, 0)
		pose("BR", -s * 0.6, 0, 0)
		rootCF = base.Root * CF(0, math.abs(s) * 0.1 * sc, 0) * ANG(s * 0.03, 0, 0)
		pose("Neck", math.sin(w * 2) * 0.06, 0, 0)
	else -- Float
		local amp = (g.Bob or 0.3) * sc
		rootCF = base.Root * CF(0, math.sin(t * 2 + view.Phase) * amp, 0) * ANG(0.12 + (aggro - 1) * 0.2, 0, math.sin(t * 1.3 + view.Phase) * 0.06)
		for _, name in ipairs(FLOAT_ARMS) do
			if m[name] and base[name] then
				local side = (name:sub(-1) == "R" or name == "RS" or name == "ArmR2") and 1 or -1
				pose(name, math.sin(t * 2.2 + view.Phase + side) * 0.3 + 0.3, 0, math.sin(t * 1.7) * 0.15 * side)
			end
		end
	end

	-- особое появление мини-босса: выбирается из земли согнувшись и выпрямляется
	if rig.SpawnStyle == "Titan" then
		local sa = (t - view.SpawnT) / 1.6
		if sa < 1 then
			local k = 1 - ease(math.clamp(sa, 0, 1))
			rootCF = rootCF * CF(0, -k * 1.2 * sc, 0) * ANG(rad(40) * k, 0, 0)
			pose("RS", rad(-30) * k, 0, rad(20) * k)
			pose("LS", rad(-30) * k, 0, rad(-20) * k)
		end
	end
	-- отшатывание от удара
	if flinch > 0 then
		rootCF = rootCF * CF(0, 0, flinch * 0.25 * sc) * ANG(-flinch * 0.25, 0, flinch * 0.08)
		if m.Neck and base.Neck then
			m.Neck.C0 = m.Neck.C0 * ANG(-flinch * 0.3, 0, 0)
		end
	end
	-- рёв босса (появление, смена фазы)
	local roarA = t - (view.RoarT or -10)
	local roar = (roarA > 0 and roarA < 1.4) and math.sin(roarA / 1.4 * math.pi) or 0
	if roar > 0 then
		if m.RS and base.RS then
			pose("RS", rad(150 * roar), 0, rad(30 * roar))
			pose("LS", rad(150 * roar), 0, rad(-30 * roar))
		end
		if m.Neck and base.Neck then
			m.Neck.C0 = base.Neck * ANG(rad(-30 * roar), 0, 0)
		end
		rootCF = rootCF * ANG(rad(-12 * roar), 0, 0)
	end
	m.Root.C0 = rootCF
	if m.Jaw then
		m.Jaw.C0 = base.Jaw * ANG(math.max(0, math.sin(t * 3 + view.Phase)) * 0.4 + roar * 0.6 + flinch * 0.3, 0, 0)
	end
	if not far then
		applySecondary(view, t, dt)
	end
end

local function updateEnemies(t, dt)
	local nowc = os.clock()
	local cam = workspace.CurrentCamera
	local camPos = cam and cam.CFrame.Position or V()
	for _, v in pairs(enemyViews) do
		local speed = v.Speed * (v.Slowed and 0.5 or 1)
		local predicted = v.ServerDist + speed * math.min(nowc - v.LastSync, 0.35)
		v.Dist = v.Dist + speed * dt
		v.Dist = v.Dist + (predicted - v.Dist) * math.min(1, dt * 5)
		local pos, dir = PathUtil.OffsetPositionAt(v.Dist, v.Lateral)
		local hip = v.Rig.HipHeight
		local target = CFrame.lookAt(pos + V(0, hip, 0), pos + dir + V(0, hip, 0))
		v.CF = v.CF:Lerp(target, math.min(1, dt * 9))
		local rise = 0
		if v.Emerge then
			local a = math.clamp((t - v.SpawnT) / 0.6, 0, 1)
			rise = (1 - ease(a)) * (hip + 1.5)
			if a >= 1 then
				v.Emerge = false
			end
		end
		if v.FadeParts then
			local a = math.clamp((t - v.SpawnT) / 0.7, 0, 1)
			for _, p in ipairs(v.FadeParts) do
				p[1].Transparency = 1 - (1 - p[2]) * a
			end
			if a >= 1 then
				v.FadeParts = nil
			end
		end
		v.Rig.Root.CFrame = v.CF - V(0, rise, 0)
		checkPhases(v, false)
		animateEnemy(v, t, dt, (camPos - pos).Magnitude)
		if v.Fill then
			v.Fill.Size = UDim2.fromScale(math.clamp(v.HP / v.MaxHP, 0, 1), 1)
		end
	end
end

------------------------------------------------------------------------
-- ЮНИТЫ
------------------------------------------------------------------------
local function yawTo(from, to)
	local d = to - from
	return math.atan2(-d.X, -d.Z)
end

local function prepareUnitModel(model, uid)
	model:SetAttribute("Uid", uid)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CanQuery = true
			d.CanTouch = false
		end
	end
end

local function buildUnitView(view)
	if view.Rig then
		view.Rig.Model:Destroy()
	end
	local rig = UnitModels.Build(view.UnitId, view.Level)
	view.Rig = rig
	prepareUnitModel(rig.Model, view.Uid)
	rig.Root.CFrame = CF(view.Pos + V(0, rig.HipHeight, 0)) * ANG(0, view.Yaw, 0)
	rig.Model.Parent = unitFolder
	view.Trails = {}
	view.TrailOn = false
	for _, d in ipairs(rig.Model:GetDescendants()) do
		if d:IsA("Trail") then
			table.insert(view.Trails, d)
		end
	end
	-- метка владельца
	local gui = Instance.new("BillboardGui")
	gui.Name = "Tag"
	gui.Size = UDim2.fromOffset(110, 34)
	gui.StudsOffsetWorldSpace = V(0, 2.7 * rig.Scale + 1.2, 0)
	gui.MaxDistance = (ctx and ctx.Lite) and 30 or 70
	gui.LightInfluence = 0
	gui.Adornee = rig.Root
	local def = Config.Units[view.UnitId]
	local rcolor = Config.Rarities[def.Rarity].Color
	local lv = Instance.new("TextLabel")
	lv.BackgroundTransparency = 1
	lv.Size = UDim2.fromScale(1, 0.55)
	lv.Font = Enum.Font.FredokaOne
	lv.TextScaled = true
	lv.Text = string.rep("★", view.Level) .. string.rep("☆", 5 - view.Level)
	lv.TextColor3 = rcolor
	lv.TextStrokeTransparency = 0.2
	lv.Parent = gui
	local own = Instance.new("TextLabel")
	own.BackgroundTransparency = 1
	own.Position = UDim2.fromScale(0, 0.55)
	own.Size = UDim2.fromScale(1, 0.45)
	own.Font = Enum.Font.GothamBold
	own.TextScaled = true
	own.Text = view.Folder:GetAttribute("OwnerName") or ""
	own.TextColor3 = Color3.fromRGB(220, 210, 235)
	own.TextStrokeTransparency = 0.4
	own.Parent = gui
	gui.Parent = rig.Root
end

function Renderer.AddUnit(folder, isNew)
	local uid = tonumber(folder.Name)
	if not uid or unitViews[uid] then
		return
	end
	local view = {
		Uid = uid,
		Folder = folder,
		UnitId = folder:GetAttribute("UnitId"),
		Level = folder:GetAttribute("Level") or 1,
		Pos = folder:GetAttribute("Position"),
		Yaw = rad(folder:GetAttribute("Rotation") or 0),
		Phase = math.random() * 10,
	}
	view.TargetYaw = view.Yaw
	if not view.UnitId or not view.Pos then
		return
	end
	unitViews[uid] = view
	buildUnitView(view)
	view.NextFidget = os.clock() + 4 + math.random() * 8
	if isNew then
		view.DropT = os.clock()
	else
		FX.Place(view.Pos)
	end
	view.Conn = folder.AttributeChanged:Connect(function(attr)
		if attr == "Level" then
			local newLevel = folder:GetAttribute("Level")
			if newLevel ~= view.Level then
				view.Level = newLevel
				buildUnitView(view)
				FX.LevelUp(view.Pos, Config.Rarities[Config.Units[view.UnitId].Rarity].Color)
				view.Anim = { Start = os.clock(), Frames = Anims.PowerUp() }
				if Renderer.OnUnitChanged then
					Renderer.OnUnitChanged(uid)
				end
			end
		elseif Renderer.OnUnitChanged then
			Renderer.OnUnitChanged(uid)
		end
	end)
end

function Renderer.RemoveUnit(folder)
	local uid = tonumber(folder.Name)
	local view = uid and unitViews[uid]
	if not view then
		return
	end
	unitViews[uid] = nil
	if view.Conn then
		view.Conn:Disconnect()
	end
	FX.Poof(view.Pos + V(0, 2, 0), FX.Colors.Soft, 1)
	view.Rig.Model:Destroy()
	if Renderer.OnUnitRemoved then
		Renderer.OnUnitRemoved(uid)
	end
end

local function muzzlePos(view)
	local m = view.Rig.Muzzle
	if m and m.Parent then
		return m.Position
	end
	return view.Rig.Root.Position + V(0, 1, 0)
end

local function playAnim(view, name, h, hits, interval)
	local builder = Anims[name]
	if not builder then
		return
	end
	view.Anim = { Start = os.clock(), Frames = builder(h, hits, interval) }
end

------------------------------------------------------------------------
-- ПРЕДПРОСМОТР (окно юнита в инвентаре): те же позы и анимации, что в бою
------------------------------------------------------------------------
function Renderer.PreviewStep(state, t)
	applyPose(state.Rig, evalPose(state, t), t, state.Phase or 0)
end

function Renderer.PreviewAttack(state, unitId, level)
	local def = Config.Units[unitId]
	local st = def.Levels[math.clamp(level or 1, 1, #def.Levels)]
	playAnim(state, def.Anim, def.HitDelay or 0.2, st.Hits or 1, def.HitInterval)
end

function Renderer.PreviewFidget(state, unitId)
	local list = FIDGETS[Config.Units[unitId].Anim] or { "LookAround" }
	local pick = list[math.random(1, #list)]
	state.Anim = { Start = os.clock(), Frames = Anims[pick]() }
end

function Renderer.OnAttack(p)
	local view = unitViews[p.U]
	if not view then
		return
	end
	local def = Config.Units[view.UnitId]
	local lv = p.L or view.Level
	local h = p.D or def.HitDelay or 0.2
	local firstId = p.T and p.T[1]
	local tpos = firstId and Renderer.EnemyPosition(firstId)
	if tpos then
		view.TargetYaw = yawTo(view.Pos, tpos)
	end

	if p.AB then
		playAnim(view, "BlackHoleCast", h)
		local crystal = view.Rig.Model:FindFirstChild("Crystal")
		if crystal then
			FX.Sphere(crystal.Position, 3, FX.Colors.Neon, 0.5)
		end
		return
	end

	local hits = p.T and #p.T or 1
	playAnim(view, def.Anim, h, hits, p.I)
	view.GustT = os.clock()
	view.NextFidget = os.clock() + 6 + math.random() * 6

	local function at(delay, fn)
		task.delay(delay, fn)
	end

	local impactColor = def.ImpactColor or FX.Colors.Neon
	if def.AttackType == "Projectile" then
		for si, id in ipairs(p.T or { firstId }) do
			local travel = (p.TRS and p.TRS[si]) or p.TR or 0.2
			at(h + (si - 1) * (p.SG or 0.12), function()
				if not view.Rig or not view.Rig.Model.Parent then
					return
				end
				local from = muzzlePos(view)
				FX.Sound("Shoot", def.Projectile == "Bolt" and 0.6 or 1, def.Projectile == "Bullet" and 0.8 or 1, from)
				FX.Projectile(def.Projectile, from, function()
					return Renderer.EnemyCenter(id)
				end, travel, function(pos)
					local orb = def.Projectile == "Orb"
					FX.Burst(pos, orb and FX.Colors.Neon or impactColor, orb and 8 or 4, 0.3, 5)
					if orb then
						FX.Sphere(pos, 1.4 + lv * 0.15, FX.Colors.Neon, 0.25)
					end
				end, lv)
				if def.Projectile == "Bolt" or def.Projectile == "Bullet" then
					FX.Sphere(from, 0.6, impactColor, 0.12)
				end
			end)
		end
	elseif def.AttackType == "Chain" then
		-- лунный серп летит от цели к цели
		local times = p.TT or {}
		for i, id in ipairs(p.T or {}) do
			local prevT = i == 1 and h or times[i - 1]
			at(prevT, function()
				if not view.Rig.Model.Parent then
					return
				end
				local from = i == 1 and muzzlePos(view) or Renderer.EnemyCenter(p.T[i - 1])
				if not from then
					return
				end
				FX.Sound("Magic", 0.8, 1.3 + i * 0.1, from)
				FX.Projectile("Moon", from, function()
					return Renderer.EnemyCenter(id)
				end, math.max((times[i] or prevT) - prevT, 0.05), function(pos)
					FX.Burst(pos, impactColor, 6, 0.3, 6)
					FX.Ring(pos - V(0, 1, 0), 2.5, impactColor, 0.3, 0.2)
				end, lv)
			end)
		end
	elseif def.AttackType == "Thread" then
		at(h, function()
			if not view.Rig.Model.Parent then
				return
			end
			FX.Sound("Magic", 0.8, 0.7, view.Pos)
			for _, id in ipairs(p.T or {}) do
				local target = Renderer.EnemyCenter(id)
				if target then
					FX.Thread(muzzlePos(view), target, FX.Colors.Soft)
				end
			end
		end)
	elseif def.AttackType == "Splash" then
		at(h, function()
			if view.Rig.Model.Parent then
				FX.Sphere(muzzlePos(view), 2.2, FX.Colors.Red, 0.25)
			end
		end)
	elseif def.AttackType == "Pierce" then
		at(h, function()
			if view.Rig.Model.Parent then
				FX.Sphere(muzzlePos(view), 2, Color3.fromRGB(255, 190, 215), 0.3)
			end
		end)
	elseif def.AttackType == "Laser" then
		at(h, function()
			local target = Renderer.EnemyCenter(firstId) or tpos
			if target and view.Rig.Model.Parent then
				FX.Sound("Laser", 1, 1, target)
				FX.Beam(muzzlePos(view), target, (lv >= 5) and 2.6 or (1.2 + lv * 0.2), (lv >= 5) and FX.Colors.Soft or FX.Colors.Neon, 0.45, lv >= 5)
			end
		end)
	elseif def.AttackType == "Melee" then
		at(h, function()
			local target = Renderer.EnemyCenter(firstId) or tpos
			if not target then
				return
			end
			local origin = view.Rig.Root.Position + V(0, 1, 0)
			local cf = CFrame.lookAt(origin, V(target.X, origin.Y, target.Z))
			local reach = math.max((V(target.X, origin.Y, target.Z) - origin).Magnitude * 0.6, 3)
			local big = view.UnitId == "AbyssOverlord" or p.PW
			local arcColor = def.ImpactColor or (big and FX.Colors.Neon or FX.Colors.Soft)
			if p.PW then
				arcColor = FX.Colors.Pink
				FX.Sphere(target, 2.2, FX.Colors.Pink, 0.25)
			end
			FX.Arc(cf, reach, rad(15), rad(150), arcColor, big and 1 or (0.4 + lv * 0.05), 0.3)
			if def.Anim == "DualDagger" then
				FX.Arc(cf * ANG(0, 0, rad(60)), reach * 0.9, rad(20), rad(140), FX.Colors.Neon, 0.35, 0.25)
			end
			FX.Sound(big and "HeavyHit" or "Slash", 1, 1, target)
			FX.Burst(target, FX.Colors.Neon, big and 12 or 5, big and 0.6 or 0.3, big and 10 or 5)
			if big then
				FX.Ring(V(target.X, view.Pos.Y + 0.2, target.Z), 4, FX.Colors.Neon, 0.35, 0.3)
			end
			if view.UnitId == "VoidKnight" and lv >= 3 then
				FX.Sphere(target, 1.5 + lv * 0.3, Color3.fromRGB(70, 20, 120), 0.35)
				FX.Burst(target, Color3.fromRGB(40, 10, 70), 8, 0.5, 6)
			end
		end)
	elseif def.AttackType == "AOE" then
		-- сама область рисуется по событию Impact (точный центр с сервера)
		at(h, function()
			if not view.Rig.Model.Parent then
				return
			end
			if view.UnitId == "EclipseGuardian" then
				FX.Sphere(muzzlePos(view), 2, FX.Colors.Neon, 0.25)
			elseif view.UnitId == "AbyssOverlord" then
				local target = Renderer.EnemyCenter(firstId) or tpos
				if target then
					local origin = view.Rig.Root.Position + Vector3.new(0, 1, 0)
					local cf = CFrame.lookAt(origin, Vector3.new(target.X, origin.Y, target.Z))
					FX.Arc(cf, math.max((Vector3.new(target.X, origin.Y, target.Z) - origin).Magnitude * 0.6, 3), rad(15), rad(150), FX.Colors.Neon, 1, 0.3)
				end
			end
		end)
	elseif def.AttackType == "MultiHit" then
		local interval = p.I or def.HitInterval or 0.16
		for i, id in ipairs(p.T or {}) do
			at(h + (i - 1) * interval, function()
				local target = Renderer.EnemyCenter(id)
				if not target or not view.Rig.Model.Parent then
					return
				end
				if view.UnitId == "CorruptedSamurai" then
					local origin = view.Rig.Root.Position + V(0, 1, 0)
					local cf = CFrame.lookAt(origin, V(target.X, origin.Y, target.Z)) * ANG(0, 0, rad(i % 2 == 0 and 50 or -50))
					local reach = math.max((V(target.X, origin.Y, target.Z) - origin).Magnitude * 0.6, 3)
					FX.Arc(cf, reach, rad(10), rad(140), lv >= 5 and FX.Colors.Pink or FX.Colors.Neon, 0.35 + lv * 0.05, 0.25)
					FX.Sound("Slash", 1, 1.15, target)
					if lv >= 3 then
						FX.SlashMark(target, rad(i % 2 == 0 and 40 or -40), 5 + lv * 0.5, 0.35, FX.Colors.Neon, 0.3)
					end
				else
					-- Void Emperor / Rift Monarch: вспышка на оружии, сам удар — в Impact
					FX.Sphere(muzzlePos(view), 1.6, def.ImpactKind == "Rift" and FX.Colors.Neon or FX.Colors.Pink, 0.2)
				end
			end)
		end
	end
end

function Renderer.OnImpact(p)
	local k = p.K
	local lv = p.L or 1
	if k == "Shockwave" then
		FX.Shockwave(p.P, p.R, lv)
	elseif k == "Reap" then
		local view = unitViews[p.U]
		local def = view and Config.Units[view.UnitId]
		FX.Reap(view and view.Pos or p.P, p.P, p.R, lv, def and def.ImpactColor)
		FX.Sound("Slash", 1, 0.8, p.P)
	elseif k == "Crystal" then
		FX.CrystalBurst(p.P, p.R)
	elseif k == "Hammer" then
		FX.Hammer(p.P, p.R, lv)
	elseif k == "Shard" then
		FX.FallingShard(p.P, p.R)
	elseif k == "Rift" then
		FX.RiftPortal(p.P, lv)
	elseif k == "BigRift" then
		FX.BigRift(p.P, p.R)
	elseif k == "Splash" then
		local view = unitViews[p.U]
		FX.RedSplash(p.P, p.R, view and muzzlePos(view))
	elseif k == "Cleave" then
		local view = unitViews[p.U]
		FX.Cleave(view and view.Pos or p.P, p.P, p.R)
	elseif k == "BloodMoonFall" then
		FX.BloodMoonFall(p.P, p.R, p.DL)
	elseif k == "BloodMoon" then
		FX.BloodMoonBoom(p.P, p.R)
	elseif k == "Pierce" then
		FX.PierceBeam(p.P, p.E)
	elseif k == "Smash" then
		local g = Vector3.new(p.P.X, p.P.Y + 0.2, p.P.Z)
		FX.Ring(g, p.R, FX.Colors.Neon, 0.4, 0.4, 1, 0.1)
		FX.Cracks(g, p.R, FX.Colors.Neon, 5 + lv, 1.0)
		FX.Burst(g + Vector3.new(0, 1, 0), Color3.fromRGB(60, 50, 70), 8 + lv, 0.5, 9)
	elseif k == "Judgement" then
		FX.Judgement(p.P, lv, p.H)
	elseif k == "BlackHole" then
		FX.BlackHole(p.P, p.R, p.DUR, lv, p.DL)
	elseif k == "Summon" then
		FX.Summon(p.P, p.R)
	end
end

local function nearestEnemyYaw(v, range)
	local best, bestD
	for _, e in pairs(enemyViews) do
		local p = e.Rig.Root.Position
		local d = PathUtil.FlatDistance(p, v.Pos)
		if d <= range and (not bestD or d < bestD) then
			best, bestD = p, d
		end
	end
	return best and yawTo(v.Pos, best)
end

local function updateUnits(t, dt)
	for _, v in pairs(unitViews) do
		local rig = v.Rig
		if rig then
			-- следим за ближайшим врагом даже до атаки
			v.TrackT = (v.TrackT or 0) - dt
			if v.TrackT <= 0 then
				v.TrackT = 0.3
				local def = Config.Units[v.UnitId]
				local yaw = nearestEnemyYaw(v, def.Levels[v.Level].Range + 6)
				if yaw and not v.Anim then
					v.TargetYaw = yaw
				end
			end
			-- случайные действия в простое
			if not v.Anim and t >= (v.NextFidget or 0) then
				local list = FIDGETS[Config.Units[v.UnitId].Anim] or { "LookAround" }
				local pick = list[math.random(1, #list)]
				v.Anim = { Start = t, Frames = Anims[pick]() }
				v.NextFidget = t + 6 + math.random() * 8
			end
			-- плащ развевается сильнее во время атаки
			rig.Gust = math.max(0, 1 - (t - (v.GustT or -10)) / 0.8)
			local diff = (v.TargetYaw - v.Yaw + math.pi) % (2 * math.pi) - math.pi
			v.Yaw = v.Yaw + diff * math.min(1, dt * 8)
			-- приземление после установки
			local drop = 0
			if v.DropT then
				local a = math.clamp((t - v.DropT) / 0.3, 0, 1)
				drop = (1 - a * a) * 7
				if a >= 1 then
					v.DropT = nil
					v.Anim = { Start = t, Frames = Anims.Land() }
					FX.Place(v.Pos)
				end
			end
			rig.Root.CFrame = CF(v.Pos + V(0, rig.HipHeight + drop, 0)) * ANG(0, v.Yaw, 0)
			applyPose(rig, evalPose(v, t), t, v.Phase)
			-- шлейф оружия виден только во время анимаций
			local on = v.Anim ~= nil
			if on ~= v.TrailOn then
				v.TrailOn = on
				for _, tr in ipairs(v.Trails or {}) do
					tr.Enabled = on
				end
			end
		end
	end
end

-- Перестроить все модели юнитов (после смены режима графики)
function Renderer.RebuildUnits()
	for _, v in pairs(unitViews) do
		buildUnitView(v)
	end
end

function Renderer.Cheer()
	for _, v in pairs(unitViews) do
		task.delay(math.random() * 0.3, function()
			if v.Rig then
				v.Anim = { Start = os.clock(), Frames = Anims.Cheer() }
			end
		end)
	end
end

------------------------------------------------------------------------
function Renderer.Update(dt)
	local t = os.clock()
	updateEnemies(t, dt)
	updateUnits(t, dt)
end

function Renderer.ClearEnemies()
	for id in pairs(enemyViews) do
		Renderer.RemoveEnemy(id, "clear")
	end
end

function Renderer.Init(c)
	ctx = c
	Config, PathUtil, UnitModels, EnemyModels, FX = c.Config, c.PathUtil, c.UnitModels, c.EnemyModels, c.FX
	enemyFolder = Instance.new("Folder")
	enemyFolder.Name = "VoidTD_Enemies"
	enemyFolder.Parent = workspace
	unitFolder = Instance.new("Folder")
	unitFolder.Name = "VoidTD_Units"
	unitFolder.Parent = workspace
	Renderer.UnitFolder = unitFolder
	Renderer.EnemyFolder = enemyFolder
end

return Renderer
]======] }
FILES[#FILES + 1] = { "StarterPlayerScripts", { "VoidTDClient", "UnitViewer" }, "ModuleScript", [======[
--!nocheck
-- VOID TD :: UnitViewer (клиент)
-- Большое окно просмотра юнита: 3D-модель в ViewportFrame + WorldModel (работают моторы и анимации),
-- вращение мышью/пальцем, зум колёсиком/щипком, переключатель уровней, анимации, характеристики,
-- кнопка экипировки, эффекты редкости. Показывается копия модели, а не юнит с карты.
-- Переключение уровней в предпросмотре ничего не покупает и не улучшает.

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local UnitViewer = {}

local V = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles
local rad = math.rad

local ctx, UI, K, Config, UnitModels, Renderer, FX
local THEME

-- подсветка по редкости (по ТЗ: эпические — синие, легендарные — золотые, мифические — фиолетовые)
local GLOW = {
	Common = Color3.fromRGB(150, 140, 170),
	Rare = Color3.fromRGB(90, 150, 255),
	Epic = Color3.fromRGB(70, 140, 255),
	Legendary = Color3.fromRGB(255, 200, 70),
	Mythic = Color3.fromRGB(190, 80, 255),
	Secret = Color3.fromRGB(255, 40, 60),
}

local LEVEL_TABS = { "LVL 1", "LVL 2", "LVL 3", "LVL 4", "MAX" }

local window -- корневая рамка (создаётся один раз)
local refs = {}
local state -- текущее открытие: { Id, Level, Rig, Yaw, Pitch, Dist, ... }
local conns = {} -- соединения, живущие только пока окно открыто

------------------------------------------------------------------------
-- 3D-сцена
------------------------------------------------------------------------
local function clearScene()
	if state and state.Rig then
		state.Rig.Model:Destroy()
		state.Rig = nil
	end
	if refs.World then
		for _, c in ipairs(refs.World:GetChildren()) do
			c:Destroy()
		end
	end
end

-- Габариты модели (по видимым деталям) — камера настраивается под размер юнита
local function bounds(model)
	local lo, hi
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and d.Transparency < 1 then
			local p, s = d.Position, d.Size
			local r = math.max(s.X, s.Y, s.Z) * 0.5
			local a, b = p - V(r, r, r), p + V(r, r, r)
			lo = lo and V(math.min(lo.X, a.X), math.min(lo.Y, a.Y), math.min(lo.Z, a.Z)) or a
			hi = hi and V(math.max(hi.X, b.X), math.max(hi.Y, b.Y), math.max(hi.Z, b.Z)) or b
		end
	end
	return lo or V(-2, -3, -2), hi or V(2, 3, 2)
end

local function part(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do
		p[k] = v
	end
	p.Parent = refs.World
	return p
end

-- Круглая платформа под юнитом с кольцом цвета редкости
local function buildPlatform(groundY, radius, glow)
	local disc = ANG(0, 0, rad(90))
	part({ Name = "Platform", Shape = Enum.PartType.Cylinder, Size = V(0.6, radius * 2, radius * 2), CFrame = CF(0, groundY - 0.3, 0) * disc, Color = Color3.fromRGB(24, 20, 32), Material = Enum.Material.Slate })
	part({ Name = "PlatformTop", Shape = Enum.PartType.Cylinder, Size = V(0.62, radius * 1.7, radius * 1.7), CFrame = CF(0, groundY - 0.29, 0) * disc, Color = Color3.fromRGB(40, 34, 54), Material = Enum.Material.Slate })
	part({ Name = "PlatformRing", Shape = Enum.PartType.Cylinder, Size = V(0.64, radius * 2.06, radius * 2.06), CFrame = CF(0, groundY - 0.36, 0) * disc, Color = glow:Lerp(Color3.new(0, 0, 0), 0.35), Material = Enum.Material.SmoothPlastic })
	-- руны по кругу
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		part({ Name = "Rune", Size = V(0.12, 0.62, radius * 0.18), CFrame = CF(math.cos(a) * radius * 0.93, groundY - 0.3, math.sin(a) * radius * 0.93) * ANG(0, -a, 0), Color = glow:Lerp(Color3.new(0, 0, 0), 0.45), Material = Enum.Material.Neon })
	end
end

local function updateCamera()
	if not state or not refs.Cam then
		return
	end
	local c = state.Center
	local dir = V(math.sin(state.Yaw) * math.cos(state.Pitch), math.sin(state.Pitch), -math.cos(state.Yaw) * math.cos(state.Pitch))
	refs.Cam.CFrame = CFrame.lookAt(c + dir * state.Dist, c)
end

local function buildModel(keepCamera)
	clearScene()
	local id, lv = state.Id, state.Level
	local ok, rig = pcall(UnitModels.Build, id, lv)
	if not ok then
		warn("[VOID TD] Предпросмотр: " .. tostring(rig))
		return
	end
	-- частицы, свет и шлейфы во ViewportFrame не рисуются — убираем их из копии
	for _, d in ipairs(rig.Model:GetDescendants()) do
		if d:IsA("ParticleEmitter") or d:IsA("PointLight") or d:IsA("Trail") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.CanQuery = false
		end
	end
	rig.Root.CFrame = CF(0, rig.HipHeight, 0)
	rig.Model.Parent = refs.World
	state.Rig = rig
	state.Anim = nil
	state.Phase = 0
	local glow = GLOW[Config.Units[id].Rarity] or THEME.Accent
	local lo, hi = bounds(rig.Model)
	local size = hi - lo
	buildPlatform(0, math.max(size.X, size.Z, 4) * 0.62, glow)
	state.Center = V(0, (lo.Y + hi.Y) * 0.5, 0)
	-- дистанция, при которой модель целиком входит в кадр при FOV 32
	state.BaseDist = math.max(size.Y, size.X * 0.9) * 1.95 + 2
	if not keepCamera then
		state.Yaw = math.rad(200)
		state.Pitch = math.rad(12)
		state.Zoom = 1
	end
	state.Dist = state.BaseDist * state.Zoom
	refs.VF.LightColor = Color3.new(1, 0.97, 1):Lerp(glow, 0.2)
	updateCamera()
end

------------------------------------------------------------------------
-- ИНФОРМАЦИЯ
------------------------------------------------------------------------
local function fmt(n)
	return Config.FormatNumber(n)
end

local function totalCost(def, lv)
	local sum = 0
	for i = 1, lv do
		sum = sum + def.Levels[i].Cost
	end
	return sum
end

local function refreshInfo()
	local id, lv = state.Id, state.Level
	local def = Config.Units[id]
	local st = def.Levels[lv]
	local rc = Config.Rarities[def.Rarity].Color
	refs.Name.Text = def.Name
	refs.Rarity.Text = def.Rarity:upper()
	refs.Rarity.TextColor3 = rc
	refs.RarityBar.BackgroundColor3 = rc
	refs.Desc.Text = def.Description or ""
	refs.StatDamage.Text = fmt(st.Damage) .. ((st.Hits and st.Hits > 1) and ("  x" .. st.Hits) or "")
	refs.StatRange.Text = tostring(st.Range)
	refs.StatSpeed.Text = string.format("%.2f/с  (%.2f с)", 1 / st.Cooldown, st.Cooldown)
	refs.StatCost.Text = "$" .. fmt(def.Levels[1].Cost)
	if lv > 1 then
		refs.StatUpgrade.Text = string.format("$%s  (всего $%s)", fmt(st.Cost), fmt(totalCost(def, lv)))
	else
		refs.StatUpgrade.Text = "—"
	end
	local ability = UI.SpecialText and UI.SpecialText(def, st) or def.AttackType
	refs.Ability.Text = (def.Ability and (def.Ability .. "\n") or "") .. ability
	for i, b in ipairs(refs.Tabs) do
		local on = i == lv
		b.BackgroundColor3 = on and THEME.Accent or THEME.BG3
		b.TextColor3 = on and Color3.new(1, 1, 1) or THEME.Dim
	end
	-- экипировка
	local prof = ctx.Profile
	local owned = prof and (prof.Inventory[id] or 0) > 0
	local equipped = false
	if prof then
		for i = 1, Config.Settings.EquipSlots do
			if prof.Equipped[tostring(i)] == id then
				equipped = true
			end
		end
	end
	refs.Equip.Text = not owned and "НЕТ В КОЛЛЕКЦИИ" or (equipped and "СНЯТЬ" or "ЭКИПИРОВАТЬ")
	refs.Equip.BackgroundColor3 = not owned and Color3.fromRGB(50, 44, 60) or (equipped and Color3.fromRGB(130, 50, 60) or Color3.fromRGB(70, 40, 140))
	refs.Equip.AutoButtonColor = false
	refs.Equip.Active = owned
end

------------------------------------------------------------------------
-- ЭФФЕКТЫ РЕДКОСТИ (лёгкие, в 2D поверх сцены)
------------------------------------------------------------------------
local function setGlow(color)
	for i, g in ipairs(refs.Glows) do
		g.BackgroundColor3 = color
		g.BackgroundTransparency = 0.84 + i * 0.04
	end
	refs.SceneStroke.Color = color
end

local function spawnParticles(color, count)
	for _, p in ipairs(refs.Particles) do
		p:Destroy()
	end
	refs.Particles = {}
	for i = 1, count do
		local p = K.new("Frame", {
			Parent = refs.Scene,
			Size = UDim2.fromOffset(6 + (i % 3) * 2, 6 + (i % 3) * 2),
			BackgroundColor3 = color,
			BackgroundTransparency = 0.2,
			BorderSizePixel = 0,
			Rotation = 45,
			ZIndex = 24,
		})
		p:SetAttribute("Seed", i * 0.6180339 % 1)
		refs.Particles[#refs.Particles + 1] = p
	end
end

local function stepParticles(t)
	for i, p in ipairs(refs.Particles) do
		local seed = p:GetAttribute("Seed") or 0
		local a = (t * (0.08 + seed * 0.06) + seed) % 1
		p.Position = UDim2.new(0.12 + seed * 0.76 + math.sin(t * 1.3 + i) * 0.02, 0, 0.95 - a * 0.9, 0)
		p.BackgroundTransparency = 0.15 + a * 0.85
	end
end

-- Короткое появление секретного юнита: затемнение, красная вспышка, надпись
local function secretIntro()
	local ov = refs.Intro
	ov.Visible = true
	ov.BackgroundTransparency = 0
	refs.IntroText.TextTransparency = 1
	refs.IntroText.Text = "✦ SECRET ✦"
	refs.IntroRing.Size = UDim2.fromScale(0.05, 0.05)
	refs.IntroRing.BackgroundTransparency = 0.1
	state.Zoom = 2.2
	K.tween(refs.IntroText, 0.35, { TextTransparency = 0 })
	K.tween(refs.IntroRing, 0.7, { Size = UDim2.fromScale(1.6, 1.6), BackgroundTransparency = 1 }, Enum.EasingStyle.Quad)
	if FX then
		FX.Sound("Secret", 0.8, 1)
	end
	task.delay(0.55, function()
		if ov.Parent then
			K.tween(ov, 0.6, { BackgroundTransparency = 1 })
			K.tween(refs.IntroText, 0.6, { TextTransparency = 1 })
		end
	end)
	task.delay(1.25, function()
		if ov.Parent then
			ov.Visible = false
		end
	end)
end

local function applyRarityFx(first)
	local rarity = Config.Units[state.Id].Rarity
	local glow = GLOW[rarity] or THEME.Accent
	setGlow(glow)
	if rarity == "Mythic" then
		spawnParticles(glow, 14)
	elseif rarity == "Secret" then
		spawnParticles(glow, 10)
	else
		spawnParticles(glow, 0)
	end
	if first and rarity == "Secret" then
		secretIntro()
	end
end

------------------------------------------------------------------------
-- ОКНО
------------------------------------------------------------------------
local function statRow(parent, order, name)
	local row = K.new("Frame", { Parent = parent, BackgroundColor3 = THEME.BG2, BackgroundTransparency = 0.2, Size = UDim2.new(1, 0, 0, 30), LayoutOrder = order, ZIndex = 23 })
	K.corner(6).Parent = row
	K.label({ Parent = row, Size = UDim2.new(0.5, -8, 1, -8), Position = UDim2.fromOffset(10, 4), Text = name, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = THEME.Dim, Font = Enum.Font.GothamBold, ZIndex = 24 })
	return K.label({ Parent = row, Size = UDim2.new(0.5, -10, 1, -8), Position = UDim2.new(0.5, 0, 0, 4), Text = "", TextXAlignment = Enum.TextXAlignment.Right, Font = Enum.Font.GothamBold, ZIndex = 24 })
end

local function build()
	window = K.new("Frame", { Name = "UnitViewer", Parent = UI.Root, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(1020, 620), BackgroundColor3 = Color3.fromRGB(10, 6, 18), BackgroundTransparency = 0.02, Visible = false, ZIndex = 20 })
	K.corner(14).Parent = window
	K.stroke(THEME.Accent, 2).Parent = window
	K.new("UIGradient", { Parent = window, Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(40, 22, 64), Color3.fromRGB(8, 4, 14)) })
	refs.Scale = K.new("UIScale", { Parent = window })
	-- затемнение фона за окном (клик по нему закрывает)
	refs.Dim = K.new("TextButton", { Name = "ViewerDim", Parent = UI.Root, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, Text = "", AutoButtonColor = false, Visible = false, ZIndex = 19 })
	refs.Dim.Activated:Connect(function()
		UnitViewer.Close()
	end)

	-- ЛЕВАЯ ЧАСТЬ: сцена
	local scene = K.new("Frame", { Parent = window, Position = UDim2.fromOffset(16, 16), Size = UDim2.new(0, 560, 1, -32), BackgroundColor3 = Color3.fromRGB(14, 9, 24), ClipsDescendants = true, ZIndex = 21 })
	refs.Scene = scene
	K.corner(12).Parent = scene
	refs.SceneStroke = K.stroke(THEME.AccentDark, 2)
	refs.SceneStroke.Parent = scene
	K.new("UIGradient", { Parent = scene, Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(34, 20, 56), Color3.fromRGB(6, 4, 12)) })
	-- мягкое свечение за моделью: концентрические круги
	refs.Glows = {}
	for i = 1, 3 do
		local sz = 0.95 - i * 0.2
		local g = K.new("Frame", { Parent = scene, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(sz, sz * 0.9), BackgroundColor3 = THEME.Accent, BackgroundTransparency = 0.8, BorderSizePixel = 0, ZIndex = 21 })
		K.new("UICorner", { Parent = g, CornerRadius = UDim.new(0.5, 0) })
		refs.Glows[i] = g
	end
	refs.Particles = {}
	local vf = K.new("ViewportFrame", { Parent = scene, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Ambient = Color3.fromRGB(120, 105, 150), LightColor = Color3.fromRGB(255, 245, 255), LightDirection = V(-0.5, -1, -0.7), ZIndex = 22, Active = true })
	refs.VF = vf
	refs.World = K.new("WorldModel", { Parent = vf })
	refs.Cam = Instance.new("Camera")
	refs.Cam.FieldOfView = 32
	refs.Cam.Parent = vf
	vf.CurrentCamera = refs.Cam
	K.label({ Parent = scene, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -8), Size = UDim2.new(1, -20, 0, 18), Text = "Тяни мышью или пальцем — вращать  •  колесо / щипок — приблизить", TextColor3 = THEME.Dim, Font = Enum.Font.Gotham, ZIndex = 24 })
	-- анимации
	local animRow = K.new("Frame", { Parent = scene, Position = UDim2.fromOffset(10, 10), Size = UDim2.fromOffset(330, 34), BackgroundTransparency = 1, ZIndex = 24 }, {
		K.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6) }),
	})
	for i, a in ipairs({ { "IDLE", "Idle" }, { "АТАКА", "Attack" }, { "ПОЗА", "Fidget" } }) do
		K.button({ Parent = animRow, Size = UDim2.fromOffset(104, 32), Text = a[1], LayoutOrder = i, BackgroundColor3 = THEME.BG3, ZIndex = 25 }, function()
			UnitViewer.PlayAnim(a[2])
		end)
	end
	K.button({ Parent = scene, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 10), Size = UDim2.fromOffset(40, 32), Text = "⟲", BackgroundColor3 = THEME.BG3, ZIndex = 25 }, function()
		if state then
			state.Yaw, state.Pitch, state.Zoom = math.rad(200), math.rad(12), 1
			state.Dist = state.BaseDist
			state.Idle = 0
		end
	end)
	-- вступление секретного юнита
	refs.Intro = K.new("Frame", { Parent = scene, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), Visible = false, ZIndex = 30 })
	refs.IntroRing = K.new("Frame", { Parent = refs.Intro, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.05, 0.05), BackgroundColor3 = GLOW.Secret, BorderSizePixel = 0, ZIndex = 31 })
	K.new("UICorner", { Parent = refs.IntroRing, CornerRadius = UDim.new(0.5, 0) })
	K.new("UIAspectRatioConstraint", { Parent = refs.IntroRing })
	refs.IntroText = K.label({ Parent = refs.Intro, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, 0, 0, 60), Text = "", TextColor3 = GLOW.Secret, ZIndex = 32 })

	-- ПРАВАЯ ЧАСТЬ: информация
	local info = K.new("Frame", { Parent = window, Position = UDim2.fromOffset(592, 16), Size = UDim2.new(1, -608, 1, -32), BackgroundTransparency = 1, ZIndex = 21 })
	K.button({ Parent = window, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 14), Size = UDim2.fromOffset(40, 40), Text = "✕", BackgroundColor3 = Color3.fromRGB(120, 30, 50), ZIndex = 26 }, function()
		UnitViewer.Close()
	end)
	refs.RarityBar = K.new("Frame", { Parent = info, Size = UDim2.fromOffset(6, 64), BorderSizePixel = 0, ZIndex = 22 })
	refs.Name = K.label({ Parent = info, Position = UDim2.fromOffset(16, 0), Size = UDim2.new(1, -70, 0, 40), Text = "", TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 22 })
	refs.Rarity = K.label({ Parent = info, Position = UDim2.fromOffset(16, 40), Size = UDim2.new(1, -70, 0, 24), Text = "", TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 22 })
	refs.Desc = K.label({ Parent = info, Position = UDim2.fromOffset(0, 72), Size = UDim2.new(1, 0, 0, 40), Text = "", TextScaled = false, TextSize = 14, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Font = Enum.Font.Gotham, TextColor3 = THEME.Dim, ZIndex = 22 })
	-- переключатель уровней
	local tabs = K.new("Frame", { Parent = info, Position = UDim2.fromOffset(0, 118), Size = UDim2.new(1, 0, 0, 36), BackgroundTransparency = 1, ZIndex = 22 }, {
		K.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6) }),
	})
	refs.Tabs = {}
	for i, name in ipairs(LEVEL_TABS) do
		refs.Tabs[i] = K.button({ Parent = tabs, Size = UDim2.new(0.2, -5, 1, 0), Text = name, LayoutOrder = i, BackgroundColor3 = THEME.BG3, ZIndex = 23 }, function()
			UnitViewer.SetLevel(i)
		end)
	end
	K.label({ Parent = info, Position = UDim2.fromOffset(0, 156), Size = UDim2.new(1, 0, 0, 16), Text = "Предпросмотр: уровень ничего не покупает и не улучшает", TextColor3 = THEME.Dim, Font = Enum.Font.Gotham, ZIndex = 22 })
	-- характеристики
	local stats = K.new("Frame", { Parent = info, Position = UDim2.fromOffset(0, 178), Size = UDim2.new(1, 0, 0, 180), BackgroundTransparency = 1, ZIndex = 22 }, {
		K.new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	refs.StatDamage = statRow(stats, 1, "Урон")
	refs.StatRange = statRow(stats, 2, "Радиус")
	refs.StatSpeed = statRow(stats, 3, "Скорость атаки")
	refs.StatCost = statRow(stats, 4, "Установка")
	refs.StatUpgrade = statRow(stats, 5, "Улучшение")
	-- способности
	local ab = K.new("Frame", { Parent = info, Position = UDim2.fromOffset(0, 364), Size = UDim2.new(1, 0, 0, 108), BackgroundColor3 = THEME.BG2, BackgroundTransparency = 0.2, ZIndex = 22 })
	K.corner(8).Parent = ab
	K.label({ Parent = ab, Position = UDim2.fromOffset(10, 6), Size = UDim2.new(1, -20, 0, 20), Text = "СПОСОБНОСТИ", TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = THEME.Accent, ZIndex = 23 })
	refs.Ability = K.label({ Parent = ab, Position = UDim2.fromOffset(10, 30), Size = UDim2.new(1, -20, 1, -36), Text = "", TextScaled = false, TextSize = 15, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Font = Enum.Font.GothamBold, ZIndex = 23 })
	-- экипировка
	refs.Equip = K.button({ Parent = info, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, 54), Text = "ЭКИПИРОВАТЬ", BackgroundColor3 = Color3.fromRGB(70, 40, 140), ZIndex = 23 }, function()
		if state and UI.ToggleEquip then
			UI.ToggleEquip(state.Id)
		end
	end)
end

------------------------------------------------------------------------
-- ВВОД: вращение и зум
------------------------------------------------------------------------
local function bindInput()
	local dragging, last = false, nil
	conns[#conns + 1] = refs.VF.InputBegan:Connect(function(input)
		local t = input.UserInputType
		if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
			dragging, last = true, input.Position
			state.Idle = 0
		end
	end)
	conns[#conns + 1] = refs.VF.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseWheel then
			state.Zoom = math.clamp(state.Zoom * (input.Position.Z > 0 and 0.88 or 1.14), 0.45, 1.8)
			state.Idle = 0
		end
	end)
	conns[#conns + 1] = UserInputService.InputChanged:Connect(function(input)
		if not dragging or not last then
			return
		end
		local t = input.UserInputType
		if t == Enum.UserInputType.MouseMovement or t == Enum.UserInputType.Touch then
			local d = input.Position - last
			last = input.Position
			state.Yaw = state.Yaw - d.X * 0.012
			state.Pitch = math.clamp(state.Pitch + d.Y * 0.008, math.rad(-15), math.rad(60))
			state.Idle = 0
		end
	end)
	conns[#conns + 1] = UserInputService.InputEnded:Connect(function(input)
		local t = input.UserInputType
		if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
	conns[#conns + 1] = UserInputService.TouchPinch:Connect(function(_, scale, _, inputState)
		if inputState == Enum.UserInputState.Change and scale and scale > 0 then
			state.Zoom = math.clamp(state.Zoom / (1 + (scale - 1) * 0.08), 0.45, 1.8)
			state.Idle = 0
		end
	end)
end

local function step(dt)
	if not state or not state.Rig then
		return
	end
	local t = os.clock()
	state.Idle = (state.Idle or 0) + dt
	-- плавное автовращение, пока игрок не трогает модель
	if state.Idle > 2.5 then
		state.Yaw = state.Yaw + dt * 0.45
	end
	state.Dist = state.Dist + (state.BaseDist * state.Zoom - state.Dist) * math.min(1, dt * 8)
	updateCamera()
	-- анимация модели (те же позы, что в бою)
	Renderer.PreviewStep(state, t)
	if #refs.Particles > 0 then
		stepParticles(t)
	end
end

------------------------------------------------------------------------
-- API
------------------------------------------------------------------------
function UnitViewer.Open(unitId, level)
	if not Config.Units[unitId] then
		return
	end
	-- 3D-просмотр открывается только для юнитов, которые уже есть в коллекции
	local prof = ctx.Profile
	if not prof or (prof.Inventory[unitId] or 0) <= 0 then
		return
	end
	if not window then
		build()
	end
	state = state or {}
	state.Id = unitId
	state.Level = math.clamp(level or 1, 1, 5)
	state.Idle = 0
	window.Visible = true
	refs.Dim.Visible = true
	refs.Scale.Scale = 0.88
	K.tween(refs.Scale, 0.22, { Scale = 1 }, Enum.EasingStyle.Back)
	buildModel(false)
	refreshInfo()
	applyRarityFx(true)
	-- соединения живут только пока окно открыто
	for _, c in ipairs(conns) do
		c:Disconnect()
	end
	conns = {}
	bindInput()
	conns[#conns + 1] = RunService.RenderStepped:Connect(step)
	if FX then
		FX.Sound("Click", 1, 1.1)
	end
end

function UnitViewer.SetLevel(lv)
	if not state then
		return
	end
	state.Level = math.clamp(lv, 1, 5)
	buildModel(true)
	refreshInfo()
	if FX then
		FX.Sound("Upgrade", 0.6, 0.9 + lv * 0.05)
	end
end

function UnitViewer.PlayAnim(kind)
	if not state or not state.Rig then
		return
	end
	if kind == "Idle" then
		state.Anim = nil
	elseif kind == "Attack" then
		Renderer.PreviewAttack(state, state.Id, state.Level)
	else
		Renderer.PreviewFidget(state, state.Id)
	end
end

function UnitViewer.Refresh()
	if window and window.Visible and state then
		refreshInfo()
	end
end

function UnitViewer.IsOpen()
	return window ~= nil and window.Visible
end

-- Закрытие: копия модели удаляется, все соединения отключаются — утечек нет
function UnitViewer.Close()
	if not window then
		return
	end
	window.Visible = false
	refs.Dim.Visible = false
	for _, c in ipairs(conns) do
		c:Disconnect()
	end
	conns = {}
	clearScene()
	spawnParticles(THEME.Accent, 0)
	refs.Intro.Visible = false
	state = nil
end

function UnitViewer.Init(c, ui)
	ctx, UI = c, ui
	K = ui.Kit
	THEME = ui.Theme
	Config, UnitModels, Renderer, FX = c.Config, c.UnitModels, c.Renderer, c.FX
	UserInputService.InputBegan:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.Escape and UnitViewer.IsOpen() then
			UnitViewer.Close()
		end
	end)
end

return UnitViewer
]======] }
FILES[#FILES + 1] = { "StarterPlayerScripts", { "VoidTDClient", "UI" }, "ModuleScript", [======[
--!nocheck
-- VOID TD :: UI (клиент)
-- Весь интерфейс создаётся кодом: HUD, хотбар, панель юнита, Summon, инвентарь, уведомления.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local UI = {}

local ctx, Config, UnitModels, Renderer, FX
local player = Players.LocalPlayer
local UnitViewer = require(script.Parent:WaitForChild("UnitViewer"))

local THEME = {
	BG = Color3.fromRGB(16, 10, 26),
	BG2 = Color3.fromRGB(32, 20, 50),
	BG3 = Color3.fromRGB(48, 30, 72),
	Accent = Color3.fromRGB(170, 80, 255),
	AccentDark = Color3.fromRGB(90, 40, 150),
	Text = Color3.fromRGB(242, 234, 255),
	Dim = Color3.fromRGB(170, 155, 195),
	Good = Color3.fromRGB(90, 220, 140),
	Bad = Color3.fromRGB(255, 80, 110),
	Gold = Color3.fromRGB(255, 205, 70),
	Pink = Color3.fromRGB(255, 70, 170),
}
UI.Theme = THEME

local gui
local refs = {}

------------------------------------------------------------------------
-- КОНСТРУКТОРЫ
------------------------------------------------------------------------
local CUSTOM = { Parent = true, Radius = true, StrokeColor = true, StrokeThickness = true }

local function new(class, props, children)
	local o = Instance.new(class)
	for k, v in pairs(props or {}) do
		if not CUSTOM[k] then
			o[k] = v
		end
	end
	for _, c in ipairs(children or {}) do
		c.Parent = o
	end
	if props and props.Parent then
		o.Parent = props.Parent
	end
	return o
end

local function corner(r)
	return new("UICorner", { CornerRadius = UDim.new(0, r or 8) })
end

local function stroke(color, th, transparency)
	return new("UIStroke", { Name = "Border", Color = color or THEME.Accent, Thickness = th or 2, Transparency = transparency or 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end

local function textStroke(th)
	return new("UIStroke", { Color = Color3.fromRGB(10, 0, 20), Thickness = th or 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual })
end

local function pad(px)
	return new("UIPadding", { PaddingLeft = UDim.new(0, px), PaddingRight = UDim.new(0, px), PaddingTop = UDim.new(0, px), PaddingBottom = UDim.new(0, px) })
end

local function tween(o, t, goal, style, dir)
	local tw = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), goal)
	tw:Play()
	return tw
end

local function panel(props)
	props.BackgroundColor3 = props.BackgroundColor3 or THEME.BG
	props.BackgroundTransparency = props.BackgroundTransparency or 0.12
	props.BorderSizePixel = 0
	local f = new("Frame", props)
	corner(props.Radius or 10).Parent = f
	stroke(props.StrokeColor or THEME.AccentDark, 2).Parent = f
	return f
end

local function label(props)
	props.BackgroundTransparency = 1
	props.Font = props.Font or Enum.Font.FredokaOne
	props.TextColor3 = props.TextColor3 or THEME.Text
	if props.TextScaled == nil then
		props.TextScaled = true
	end
	local l = new("TextLabel", props)
	textStroke(props.StrokeThickness).Parent = l
	return l
end

local function button(props, onClick)
	props.BackgroundColor3 = props.BackgroundColor3 or THEME.BG3
	props.BorderSizePixel = 0
	props.AutoButtonColor = false
	props.Font = props.Font or Enum.Font.FredokaOne
	props.TextColor3 = props.TextColor3 or THEME.Text
	if props.TextScaled == nil then
		props.TextScaled = true
	end
	local b = new("TextButton", props)
	corner(props.Radius or 8).Parent = b
	stroke(props.StrokeColor or THEME.Accent, 2).Parent = b
	textStroke().Parent = b
	local scale = new("UIScale", { Parent = b })
	b.MouseEnter:Connect(function()
		tween(scale, 0.12, { Scale = 1.06 })
	end)
	b.MouseLeave:Connect(function()
		tween(scale, 0.12, { Scale = 1 })
	end)
	b.MouseButton1Down:Connect(function()
		tween(scale, 0.06, { Scale = 0.94 })
	end)
	b.MouseButton1Up:Connect(function()
		tween(scale, 0.1, { Scale = 1.04 })
	end)
	if onClick then
		b.Activated:Connect(onClick)
	end
	return b
end

------------------------------------------------------------------------
-- ИКОНКИ: рисуются из фигур (без эмодзи и загруженных картинок)
------------------------------------------------------------------------
-- фигура в долях контейнера: центр (x, y), размер (w, h), поворот, скругление
local function shape(parent, x, y, w, h, color, rot, round, z, props)
	local f = new("Frame", {
		Parent = parent,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(x, y),
		Size = UDim2.fromScale(w, h),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Rotation = rot or 0,
		ZIndex = z or 1,
	})
	if round then
		new("UICorner", { Parent = f, CornerRadius = UDim.new(round, 0) })
	end
	for k, v in pairs(props or {}) do
		f[k] = v
	end
	return f
end

local function shade(f, top, bottom, rot)
	new("UIGradient", { Parent = f, Rotation = rot or 90, Color = ColorSequence.new(top, bottom) })
end

local ICONS = {}

-- кристалл: огранённый ромб с бликом
function ICONS.Gem(c, z)
	local o = shape(c, 0.5, 0.52, 0.6, 0.6, Color3.new(1, 1, 1), 45, 0.12, z)
	shade(o, Color3.fromRGB(150, 210, 255), Color3.fromRGB(80, 70, 220), 45)
	new("UIStroke", { Parent = o, Color = Color3.fromRGB(20, 14, 50), Thickness = 2 })
	shape(c, 0.5, 0.4, 0.28, 0.28, Color3.fromRGB(215, 240, 255), 45, 0.1, z + 1, { BackgroundTransparency = 0.15 })
	shape(c, 0.38, 0.38, 0.08, 0.16, Color3.new(1, 1, 1), 45, 0.5, z + 2, { BackgroundTransparency = 0.1 })
end

-- монета
function ICONS.Coin(c, z)
	local o = shape(c, 0.5, 0.5, 0.74, 0.74, Color3.new(1, 1, 1), 0, 0.5, z)
	shade(o, Color3.fromRGB(255, 225, 110), Color3.fromRGB(190, 120, 30))
	new("UIStroke", { Parent = o, Color = Color3.fromRGB(70, 40, 10), Thickness = 2 })
	local i = shape(c, 0.5, 0.5, 0.5, 0.5, Color3.fromRGB(215, 150, 45), 0, 0.5, z + 1)
	new("TextLabel", { Parent = i, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "$", TextScaled = true, Font = Enum.Font.FredokaOne, TextColor3 = Color3.fromRGB(90, 50, 10), ZIndex = z + 2 })
end

-- шлем рыцаря Пустоты с Т-визором
function ICONS.Helmet(c, z)
	local acc = Color3.fromRGB(196, 130, 255)
	for _, sx in ipairs({ -1, 1 }) do
		shape(c, 0.5 + 0.26 * sx, 0.26, 0.09, 0.3, Color3.fromRGB(215, 205, 190), 28 * sx, 0.3, z)
	end
	local h = shape(c, 0.5, 0.55, 0.54, 0.62, Color3.new(1, 1, 1), 0, 0.22, z + 1)
	shade(h, Color3.fromRGB(110, 106, 130), Color3.fromRGB(40, 36, 54))
	new("UIStroke", { Parent = h, Color = Color3.fromRGB(16, 12, 24), Thickness = 2 })
	shape(c, 0.5, 0.2, 0.1, 0.18, Color3.fromRGB(90, 86, 110), 0, 0.3, z)
	shape(c, 0.5, 0.48, 0.38, 0.07, acc, 0, 0.5, z + 2)
	shape(c, 0.5, 0.6, 0.07, 0.24, acc, 0, 0.5, z + 2)
end

-- шестерёнка настроек
function ICONS.Gear(c, z)
	local col = Color3.fromRGB(190, 186, 210)
	for k = 0, 7 do
		local a = k / 8 * math.pi * 2
		shape(c, 0.5 + math.cos(a) * 0.3, 0.5 + math.sin(a) * 0.3, 0.16, 0.16, col, math.deg(a), 0.15, z)
	end
	shape(c, 0.5, 0.5, 0.6, 0.6, col, 0, 0.5, z + 1)
	shape(c, 0.5, 0.5, 0.26, 0.26, Color3.fromRGB(34, 30, 48), 0, 0.5, z + 2)
end

-- стрелка «назад»
function ICONS.Back(c, z)
	local col = Color3.fromRGB(255, 235, 240)
	shape(c, 0.56, 0.5, 0.5, 0.12, col, 0, 0.5, z)
	shape(c, 0.34, 0.37, 0.32, 0.12, col, -42, 0.5, z)
	shape(c, 0.34, 0.63, 0.32, 0.12, col, 42, 0.5, z)
end

-- контейнер с иконкой (квадратный)
local function icon(kind, parent, props)
	local c = new("Frame", { Parent = parent, Name = "Icon" .. kind, BackgroundTransparency = 1, Size = props.Size, Position = props.Position or UDim2.new(), AnchorPoint = props.AnchorPoint or Vector2.new(), ZIndex = props.ZIndex or 1 })
	new("UIAspectRatioConstraint", { Parent = c })
	ICONS[kind](c, (props.ZIndex or 1) + 1)
	return c
end
UI.Icon = icon

-- Квадратная кнопка-иконка с подписью (панель справа)
local function iconButton(parent, order, kind, caption, top, bottom, edge, onClick, size)
	size = size or 76
	local b = new("TextButton", {
		Parent = parent,
		Name = kind .. "Button",
		LayoutOrder = order,
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
	})
	corner(16).Parent = b
	stroke(edge, 2).Parent = b
	new("UIGradient", { Parent = b, Rotation = 90, Color = ColorSequence.new(top, bottom) })
	-- мягкий блик сверху
	local shine = new("Frame", { Parent = b, BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.9, BorderSizePixel = 0, Position = UDim2.fromOffset(4, 4), Size = UDim2.new(1, -8, 0.4, 0) })
	corner(12).Parent = shine
	icon(kind, b, { Size = UDim2.fromScale(0.72, 0.72), Position = UDim2.fromScale(0.5, 0.48), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 2 })
	local cap = label({ Parent = b, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, 3), Size = UDim2.new(1, 16, 0, math.max(14, size * 0.2)), Text = caption, Font = Enum.Font.GothamBold })
	local scale = new("UIScale", { Parent = b })
	b.MouseEnter:Connect(function()
		tween(scale, 0.12, { Scale = 1.08 })
	end)
	b.MouseLeave:Connect(function()
		tween(scale, 0.12, { Scale = 1 })
	end)
	b.MouseButton1Down:Connect(function()
		tween(scale, 0.06, { Scale = 0.93 })
	end)
	b.MouseButton1Up:Connect(function()
		tween(scale, 0.1, { Scale = 1.04 })
	end)
	if onClick then
		b.Activated:Connect(onClick)
	end
	return b, cap
end

local function rarityColor(id)
	return Config.Rarities[Config.Units[id].Rarity].Color
end

-- 3D превью юнита
local function viewport(parent, unitId, level, props)
	props = props or {}
	local vf = new("ViewportFrame", {
		Parent = parent,
		BackgroundTransparency = 1,
		Size = props.Size or UDim2.fromScale(1, 1),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.new(),
		Ambient = Color3.fromRGB(150, 130, 185),
		LightColor = Color3.fromRGB(255, 245, 255),
		LightDirection = Vector3.new(-0.6, -1, -0.8),
		ZIndex = props.ZIndex or 1,
	})
	local ok, rig = pcall(UnitModels.Build, unitId, level or 1)
	if not ok then
		return vf
	end
	for _, d in ipairs(rig.Model:GetDescendants()) do
		if d:IsA("ParticleEmitter") or d:IsA("PointLight") or d:IsA("Trail") then
			d:Destroy()
		end
	end
	rig.Model.Parent = vf
	local cam = Instance.new("Camera")
	cam.FieldOfView = 34
	local s = rig.Scale
	local center = Vector3.new(0, -0.1 * s, 0)
	-- камера дальше, чтобы юнит с оружием целиком помещался в превью
	cam.CFrame = CFrame.lookAt(center + Vector3.new(5.6, 2.6, -14.5) * s, center)
	cam.Parent = vf
	vf.CurrentCamera = cam
	if props.Silhouette then
		vf.ImageColor3 = Color3.fromRGB(0, 0, 0)
		vf.ImageTransparency = 0.2
	end
	return vf
end
UI.Viewport = viewport

------------------------------------------------------------------------
-- УВЕДОМЛЕНИЯ
------------------------------------------------------------------------
function UI.Toast(text, kind)
	local color = THEME.Accent
	if kind == "error" then
		color = THEME.Bad
	elseif kind == "good" then
		color = THEME.Good
	elseif kind == "boss" then
		color = THEME.Pink
	elseif kind == "gold" then
		color = THEME.Gold
	end
	local t = panel({ Parent = refs.Toasts, Size = UDim2.fromOffset(380, 38), StrokeColor = color, BackgroundTransparency = 0.05 })
	local l = label({ Parent = t, Size = UDim2.new(1, -16, 1, -10), Position = UDim2.fromOffset(8, 5), Text = text, TextColor3 = color })
	local sc = new("UIScale", { Parent = t, Scale = 0.6 })
	tween(sc, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
	task.delay(2.6, function()
		tween(t, 0.3, { BackgroundTransparency = 1 })
		tween(l, 0.3, { TextTransparency = 1 })
		task.wait(0.32)
		t:Destroy()
	end)
end

function UI.Announce(title, subtitle, color)
	local holder = refs.Announce
	holder:ClearAllChildren()
	local sc = new("UIScale", { Parent = holder, Scale = 0.3 })
	local t = label({ Parent = holder, Size = UDim2.new(1, 0, 0.62, 0), Text = title, TextColor3 = color or THEME.Text, StrokeThickness = 3 })
	local s
	if subtitle then
		s = label({ Parent = holder, Size = UDim2.new(1, 0, 0.32, 0), Position = UDim2.fromScale(0, 0.66), Text = subtitle, TextColor3 = THEME.Dim })
	end
	holder.Visible = true
	tween(sc, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	task.delay(2.2, function()
		if t.Parent then
			tween(t, 0.4, { TextTransparency = 1 })
			if s then
				tween(s, 0.4, { TextTransparency = 1 })
			end
		end
	end)
end

------------------------------------------------------------------------
-- HUD
------------------------------------------------------------------------
local function buildHUD()
	-- деньги и гемы
	local cur = panel({ Parent = gui, Size = UDim2.fromOffset(230, 92), Position = UDim2.fromOffset(16, 16) })
	refs.Currency = cur
	refs.Money = label({ Parent = cur, Size = UDim2.new(1, -60, 0, 36), Position = UDim2.fromOffset(52, 6), Text = "0", TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(255, 220, 120) })
	refs.MoneyIcon = icon("Coin", cur, { Size = UDim2.fromOffset(34, 34), Position = UDim2.fromOffset(10, 7) })
	refs.Gems = label({ Parent = cur, Size = UDim2.new(1, -60, 0, 32), Position = UDim2.fromOffset(52, 50), Text = "0", TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(150, 200, 255) })
	refs.GemsIcon = icon("Gem", cur, { Size = UDim2.fromOffset(34, 34), Position = UDim2.fromOffset(10, 49) })

	-- волна и ядро
	local top = panel({ Parent = gui, AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.fromOffset(420, 104), Position = UDim2.new(0.5, 0, 0, 12) })
	refs.Top = top
	refs.Wave = label({ Parent = top, Size = UDim2.new(1, -20, 0, 40), Position = UDim2.fromOffset(10, 4), Text = "WAVE 0 / 30" })
	refs.Status = label({ Parent = top, Size = UDim2.new(1, -20, 0, 22), Position = UDim2.fromOffset(10, 44), Text = "", TextColor3 = THEME.Dim, Font = Enum.Font.GothamBold })
	local coreBg = new("Frame", { Parent = top, Size = UDim2.new(1, -24, 0, 24), Position = UDim2.fromOffset(12, 72), BackgroundColor3 = Color3.fromRGB(25, 12, 32), BorderSizePixel = 0 }, { corner(6) })
	refs.CoreFill = new("Frame", { Parent = coreBg, Size = UDim2.fromScale(1, 1), BackgroundColor3 = THEME.Accent, BorderSizePixel = 0 }, { corner(6) })
	new("UIGradient", { Parent = refs.CoreFill, Color = ColorSequence.new(Color3.fromRGB(120, 50, 220), Color3.fromRGB(230, 120, 255)) })
	refs.CoreText = label({ Parent = coreBg, Size = UDim2.new(1, 0, 1, -4), Position = UDim2.fromOffset(0, 2), Text = "VOID CORE 100 / 100", ZIndex = 2 })

	-- босс
	local boss = panel({ Parent = gui, AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.fromOffset(560, 46), Position = UDim2.new(0.5, 0, 0, 124), StrokeColor = THEME.Pink, Visible = false })
	refs.Boss = boss
	local bossBg = new("Frame", { Parent = boss, Size = UDim2.new(1, -16, 0, 20), Position = UDim2.fromOffset(8, 20), BackgroundColor3 = Color3.fromRGB(30, 8, 20), BorderSizePixel = 0 }, { corner(5) })
	refs.BossFill = new("Frame", { Parent = bossBg, Size = UDim2.fromScale(1, 1), BackgroundColor3 = THEME.Pink, BorderSizePixel = 0 }, { corner(5) })
	refs.BossName = label({ Parent = boss, Size = UDim2.new(1, -16, 0, 18), Position = UDim2.fromOffset(8, 2), Text = "BOSS", TextColor3 = THEME.Pink })
	refs.BossHP = label({ Parent = bossBg, Size = UDim2.new(1, 0, 1, -4), Position = UDim2.fromOffset(0, 2), Text = "", ZIndex = 2 })

	-- уведомления и анонсы
	refs.Toasts = new("Frame", { Parent = gui, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.fromOffset(400, 300), Position = UDim2.new(0.5, 0, 0, 180) }, {
		new("UIListLayout", { Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	refs.Announce = new("Frame", { Parent = gui, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(700, 130), Position = UDim2.fromScale(0.5, 0.36), Visible = false })

	-- кнопка старта волны
	refs.Start = button({
		Parent = gui,
		AnchorPoint = Vector2.new(1, 1),
		Size = UDim2.fromOffset(220, 60),
		Position = UDim2.new(1, -18, 1, -150),
		Text = "▶ START WAVE",
		BackgroundColor3 = Color3.fromRGB(70, 150, 90),
		StrokeColor = THEME.Good,
	}, function()
		ctx.Request("StartWave")
	end)

	-- панель иконок справа: магазин, юниты, графика
	local dock = new("Frame", { Parent = gui, Name = "IconDock", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, -40), Size = UDim2.fromOffset(84, 290), BackgroundTransparency = 1 })
	new("UIListLayout", { Parent = dock, Padding = UDim.new(0, 12), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder })
	refs.ShopButton = iconButton(dock, 1, "Gem", "МАГАЗИН", Color3.fromRGB(44, 52, 92), Color3.fromRGB(18, 18, 36), Color3.fromRGB(110, 150, 230), function()
		UI.Toggle("Shop")
		FX.Sound("Click", 1, 1)
	end)
	refs.InvButton = iconButton(dock, 2, "Helmet", "ЮНИТЫ", Color3.fromRGB(66, 44, 100), Color3.fromRGB(22, 14, 36), Color3.fromRGB(150, 110, 210), function()
		UI.Toggle("Inventory")
	end)
	refs.LiteButton, refs.LiteCaption = iconButton(dock, 3, "Gear", "ГРАФИКА", Color3.fromRGB(56, 54, 72), Color3.fromRGB(22, 20, 30), Color3.fromRGB(120, 116, 140), function()
		ctx.SetLite(not ctx.Lite, true)
	end, 62)

	-- выход из матча в лобби
	refs.Leave = button({ Parent = gui, Name = "LeaveButton", Size = UDim2.fromOffset(150, 44), Position = UDim2.fromOffset(16, 118), Text = "    В ЛОББИ", BackgroundColor3 = Color3.fromRGB(80, 30, 46), StrokeColor = Color3.fromRGB(170, 70, 90) }, function()
		ctx.Placement.Stop()
		UI.CloseUnit()
		task.spawn(UI.FadeTransition, "ВОЗВРАЩЕНИЕ В ЛОББИ", function()
			return ctx.Request("LeaveMatch")
		end)
	end)
	icon("Back", refs.Leave, { Size = UDim2.fromOffset(26, 26), Position = UDim2.fromOffset(12, 9), ZIndex = 2 })

	-- подсказка размещения
	refs.PlaceHint = panel({ Parent = gui, AnchorPoint = Vector2.new(0.5, 1), Size = UDim2.fromOffset(520, 34), Position = UDim2.new(0.5, 0, 1, -150), Visible = false })
	label({ Parent = refs.PlaceHint, Size = UDim2.new(1, -16, 1, -8), Position = UDim2.fromOffset(8, 4), Font = Enum.Font.GothamBold, Text = "ЛКМ — поставить  •  R — повернуть  •  Q / ПКМ — отмена  •  Shift — несколько" })

	-- тач-кнопки размещения
	refs.TouchBar = new("Frame", { Parent = gui, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 1), Size = UDim2.fromOffset(380, 56), Position = UDim2.new(0.5, 0, 1, -190), Visible = false }, {
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10), HorizontalAlignment = Enum.HorizontalAlignment.Center }),
	})
	button({ Parent = refs.TouchBar, Size = UDim2.fromOffset(115, 52), Text = "PLACE", BackgroundColor3 = Color3.fromRGB(60, 140, 80) }, function()
		ctx.Placement.Confirm()
	end)
	button({ Parent = refs.TouchBar, Size = UDim2.fromOffset(115, 52), Text = "ROTATE" }, function()
		ctx.Placement.Rotate()
	end)
	button({ Parent = refs.TouchBar, Size = UDim2.fromOffset(115, 52), Text = "CANCEL", BackgroundColor3 = Color3.fromRGB(140, 40, 60) }, function()
		ctx.Placement.Stop()
	end)
end

function UI.ShowPlacementHint(on, touch)
	refs.PlaceHint.Visible = on and not touch
	refs.TouchBar.Visible = on and touch
end

------------------------------------------------------------------------
-- ХОТБАР
------------------------------------------------------------------------
local slotRefs = {}

local function buildHotbar()
	local bar = new("Frame", { Parent = gui, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 1), Size = UDim2.fromOffset(6 * 104, 128), Position = UDim2.new(0.5, 0, 1, -12) }, {
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), HorizontalAlignment = Enum.HorizontalAlignment.Center }),
	})
	refs.Hotbar = bar
	for i = 1, Config.Settings.EquipSlots do
		local slot = button({ Parent = bar, Size = UDim2.fromOffset(96, 124), Text = "", BackgroundColor3 = THEME.BG2, LayoutOrder = i }, function()
			local id = UI.EquippedAt(i)
			if id then
				ctx.Placement.Start(id)
			else
				UI.Toast("Пустой слот: экипируй юнитов в круге ЮНИТЫ в лобби", "error")
			end
		end)
		slotRefs[i] = { Button = slot }
	end
end

function UI.EquippedAt(i)
	local prof = ctx.Profile
	return prof and prof.Equipped and prof.Equipped[tostring(i)]
end

local function refreshHotbar()
	for i, s in ipairs(slotRefs) do
		local b = s.Button
		for _, c in ipairs(b:GetChildren()) do
			if c:IsA("ViewportFrame") or c:IsA("TextLabel") or c:IsA("Frame") then
				c:Destroy()
			end
		end
		local id = UI.EquippedAt(i)
		local st = b:FindFirstChild("Border")
		label({ Parent = b, Size = UDim2.fromOffset(20, 20), Position = UDim2.fromOffset(5, 3), Text = tostring(i), TextColor3 = THEME.Dim, ZIndex = 3 })
		if id then
			local def = Config.Units[id]
			local rc = rarityColor(id)
			st.Color = rc
			new("Frame", { Parent = b, Size = UDim2.new(1, -8, 0, 4), Position = UDim2.fromOffset(4, 4), BackgroundColor3 = rc, BorderSizePixel = 0, ZIndex = 2 }, { corner(2) })
			viewport(b, id, 1, { Size = UDim2.new(1, 0, 0, 82), Position = UDim2.fromOffset(0, 6) })
			label({ Parent = b, Size = UDim2.new(1, -6, 0, 16), Position = UDim2.fromOffset(3, 86), Text = def.Name, Font = Enum.Font.GothamBold, ZIndex = 2 })
			s.Cost = label({ Parent = b, Size = UDim2.new(1, -6, 0, 18), Position = UDim2.fromOffset(3, 102), Text = "$" .. Config.FormatNumber(def.Levels[1].Cost), TextColor3 = THEME.Good, ZIndex = 2 })
			s.Id = id
		else
			st.Color = THEME.AccentDark
			label({ Parent = b, Size = UDim2.new(1, -10, 0, 40), Position = UDim2.fromOffset(5, 40), Text = "+", TextColor3 = THEME.Dim })
			s.Id = nil
			s.Cost = nil
		end
	end
end

------------------------------------------------------------------------
-- ПАНЕЛЬ ЮНИТА
------------------------------------------------------------------------
local rangePart

local function showRange(pos, range)
	if not rangePart then
		rangePart = FX.Part({
			Shape = Enum.PartType.Cylinder,
			Color = THEME.Accent,
			Transparency = 0.75,
			Parent = workspace,
		})
		rangePart.Name = "VoidTD_Range"
	end
	rangePart.Size = Vector3.new(0.2, range * 2, range * 2)
	rangePart.CFrame = CFrame.new(pos + Vector3.new(0, 0.25, 0)) * CFrame.Angles(0, 0, math.rad(90))
	rangePart.Parent = workspace
end

local function hideRange()
	if rangePart then
		rangePart.Parent = nil
	end
end

local function statLine(parent, order, name)
	local row = new("Frame", { Parent = parent, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 24), LayoutOrder = order })
	label({ Parent = row, Size = UDim2.new(0.45, 0, 1, 0), Text = name, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = THEME.Dim, Font = Enum.Font.GothamBold })
	return label({ Parent = row, Size = UDim2.new(0.55, 0, 1, 0), Position = UDim2.fromScale(0.45, 0), Text = "", TextXAlignment = Enum.TextXAlignment.Right, Font = Enum.Font.GothamBold })
end

local function buildUnitPanel()
	local p = panel({ Parent = gui, AnchorPoint = Vector2.new(1, 0.5), Size = UDim2.fromOffset(310, 470), Position = UDim2.new(1, -112, 0.45, 0), Visible = false })
	refs.UnitPanel = p
	refs.UPName = label({ Parent = p, Size = UDim2.new(1, -60, 0, 32), Position = UDim2.fromOffset(12, 10), Text = "Unit", TextXAlignment = Enum.TextXAlignment.Left })
	button({ Parent = p, Size = UDim2.fromOffset(32, 32), Position = UDim2.new(1, -42, 0, 10), Text = "✕", BackgroundColor3 = Color3.fromRGB(120, 30, 50) }, function()
		UI.CloseUnit()
	end)
	refs.UPRarity = label({ Parent = p, Size = UDim2.new(1, -24, 0, 20), Position = UDim2.fromOffset(12, 42), Text = "", TextXAlignment = Enum.TextXAlignment.Left })
	refs.UPStars = label({ Parent = p, Size = UDim2.new(1, -24, 0, 24), Position = UDim2.fromOffset(12, 62), Text = "", TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = THEME.Gold })
	refs.UPView = new("Frame", { Parent = p, BackgroundColor3 = THEME.BG2, BackgroundTransparency = 0.3, Size = UDim2.new(1, -24, 0, 110), Position = UDim2.fromOffset(12, 90) }, { corner(8) })
	local stats = new("Frame", { Parent = p, BackgroundTransparency = 1, Size = UDim2.new(1, -24, 0, 160), Position = UDim2.fromOffset(12, 206) }, {
		new("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	refs.UPDamage = statLine(stats, 1, "Урон")
	refs.UPRange = statLine(stats, 2, "Дальность")
	refs.UPCooldown = statLine(stats, 3, "Перезарядка")
	refs.UPSpecial = statLine(stats, 4, "Особое")
	refs.UPDealt = statLine(stats, 5, "Нанесено")
	refs.UPOwner = statLine(stats, 6, "Владелец")
	local function cycleTarget()
		local uid = UI.SelectedUid
		local v = uid and Renderer.UnitViews[uid]
		if not v then
			return
		end
		local cur = v.Folder:GetAttribute("TargetMode") or "First"
		local idx = table.find(Config.TargetModes, cur) or 1
		local nextMode = Config.TargetModes[idx % #Config.TargetModes + 1]
		ctx.Request("SetTarget", { Uid = uid, Mode = nextMode })
	end
	UI.CycleTargetFn = cycleTarget
	refs.UPTarget = button({ Parent = p, Size = UDim2.new(1, -24, 0, 36), Position = UDim2.fromOffset(12, 362), Text = "TARGET: First", BackgroundColor3 = THEME.BG3 }, cycleTarget)
	refs.UPUpgrade = button({ Parent = p, Size = UDim2.new(0.6, -16, 0, 50), Position = UDim2.fromOffset(12, 406), Text = "UPGRADE", BackgroundColor3 = Color3.fromRGB(60, 130, 80), StrokeColor = THEME.Good }, function()
		UI.UpgradeSelected()
	end)
	refs.UPSell = button({ Parent = p, Size = UDim2.new(0.4, -12, 0, 50), Position = UDim2.new(0.6, 4, 0, 406), Text = "SELL", BackgroundColor3 = Color3.fromRGB(130, 40, 60), StrokeColor = THEME.Bad }, function()
		UI.SellSelected()
	end)
end

local function specialText(def, st)
	if st.BlackHole then
		return string.format("Black Hole r%d, %d/тик", st.BlackHole.Radius, st.BlackHole.TickDamage)
	elseif st.AOERadius then
		return string.format("AOE радиус %.1f", st.AOERadius)
	elseif st.Hits and st.Hits > 1 then
		local s = "x" .. st.Hits .. " удара"
		if st.CritChance then
			s = s .. string.format(", крит %d%%", st.CritChance * 100)
		end
		return s
	elseif st.CritChance then
		return string.format("Крит %d%% x%.1f", st.CritChance * 100, st.CritMult or 2)
	end
	return def.AttackType
end

function UI.RefreshUnitPanel()
	local uid = UI.SelectedUid
	local v = uid and Renderer.UnitViews[uid]
	if not v then
		UI.CloseUnit()
		return
	end
	local def = Config.Units[v.UnitId]
	local lv = v.Folder:GetAttribute("Level") or 1
	local st = def.Levels[lv]
	local nx = def.Levels[lv + 1]
	local rc = rarityColor(v.UnitId)
	refs.UPName.Text = def.Name
	refs.UPRarity.Text = def.Rarity:upper() .. (def.Ability and ("  •  " .. def.Ability) or "")
	refs.UPRarity.TextColor3 = rc
	refs.UPStars.Text = "Lv " .. lv .. "  " .. string.rep("★", lv) .. string.rep("☆", 5 - lv)
	refs.UnitPanel.Border.Color = rc
	local function arrow(a, b, fmt)
		fmt = fmt or "%s"
		if b and b ~= a then
			return string.format(fmt, a) .. "  →  " .. string.format(fmt, b)
		end
		return string.format(fmt, a)
	end
	refs.UPDamage.Text = arrow(Config.FormatNumber(st.Damage), nx and Config.FormatNumber(nx.Damage))
	refs.UPRange.Text = arrow(st.Range, nx and nx.Range)
	refs.UPCooldown.Text = arrow(st.Cooldown, nx and nx.Cooldown, "%.2fs")
	refs.UPSpecial.Text = specialText(def, st)
	refs.UPDealt.Text = Config.FormatNumber(v.Folder:GetAttribute("Damage") or 0)
	refs.UPOwner.Text = v.Folder:GetAttribute("OwnerName") or "?"
	refs.UPTarget.Text = "🎯 TARGET: " .. (v.Folder:GetAttribute("TargetMode") or "First")
	local mine = v.Folder:GetAttribute("OwnerId") == player.UserId
	refs.UPUpgrade.Visible = mine
	refs.UPSell.Visible = mine
	refs.UPTarget.Visible = mine
	if nx then
		refs.UPUpgrade.Text = "UPGRADE $" .. Config.FormatNumber(nx.Cost)
		local afford = (player:GetAttribute("Money") or 0) >= nx.Cost
		refs.UPUpgrade.BackgroundColor3 = afford and Color3.fromRGB(60, 130, 80) or Color3.fromRGB(60, 60, 70)
	else
		refs.UPUpgrade.Text = "MAX LEVEL"
		refs.UPUpgrade.BackgroundColor3 = Color3.fromRGB(120, 90, 30)
	end
	local spent = v.Folder:GetAttribute("Spent") or 0
	refs.UPSell.Text = "SELL $" .. Config.FormatNumber(math.floor(spent * Config.Settings.SellRefund))
	if refs.UPViewLevel ~= lv or refs.UPViewUid ~= uid then
		refs.UPViewLevel, refs.UPViewUid = lv, uid
		refs.UPView:ClearAllChildren()
		corner(8).Parent = refs.UPView
		viewport(refs.UPView, v.UnitId, lv)
	end
	showRange(v.Pos, st.Range)
end

function UI.OpenUnit(uid)
	UI.SelectedUid = uid
	refs.UnitPanel.Visible = true
	refs.UPViewUid = nil
	UI.RefreshUnitPanel()
end

function UI.CloseUnit()
	UI.SelectedUid = nil
	if refs.UnitPanel then
		refs.UnitPanel.Visible = false
	end
	hideRange()
end

function UI.UpgradeSelected()
	if UI.SelectedUid then
		local ok, res = ctx.Request("Upgrade", { Uid = UI.SelectedUid })
		if ok then
			UI.Toast("Улучшено до уровня " .. tostring(res) .. "!", "good")
		end
	end
end

function UI.SellSelected()
	if UI.SelectedUid then
		local ok, res = ctx.Request("Sell", { Uid = UI.SelectedUid })
		if ok then
			UI.Toast("Продано за $" .. Config.FormatNumber(res), "gold")
			FX.Sound("Sell", 1, 1)
			UI.CloseUnit()
		end
	end
end

function UI.CycleTarget()
	if UI.SelectedUid and refs.UPTarget.Visible then
		UI.CycleTargetFn()
	end
end

------------------------------------------------------------------------
-- МОДАЛЬНЫЕ ОКНА
------------------------------------------------------------------------
local modals = {}

function UI.Toggle(name)
	for n, m in pairs(modals) do
		if n == name then
			m.Visible = not m.Visible
			if m.Visible then
				local sc = m:FindFirstChildOfClass("UIScale")
				sc.Scale = 0.85
				tween(sc, 0.2, { Scale = 1 }, Enum.EasingStyle.Back)
				if name == "Inventory" then
					UI.RefreshInventory()
				elseif name == "Mode" then
					UI.RefreshMode()
				end
			end
		else
			m.Visible = false
		end
	end
end

function UI.Show(name, on)
	local m = modals[name]
	if not m then
		return
	end
	if on and not m.Visible then
		UI.Toggle(name)
	elseif not on then
		m.Visible = false
	end
end

local function modal(name, title, size, iconKind)
	local m = panel({ Parent = gui, AnchorPoint = Vector2.new(0.5, 0.5), Size = size, Position = UDim2.fromScale(0.5, 0.5), Visible = false, BackgroundTransparency = 0.04, ZIndex = 5 })
	new("UIScale", { Parent = m })
	local x = 18
	if iconKind then
		icon(iconKind, m, { Size = UDim2.fromOffset(38, 38), Position = UDim2.fromOffset(16, 13), ZIndex = 6 })
		x = 62
	end
	label({ Parent = m, Size = UDim2.new(1, -80 - x, 0, 44), Position = UDim2.fromOffset(x, 10), Text = title, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = THEME.Accent })
	button({ Parent = m, Size = UDim2.fromOffset(40, 40), Position = UDim2.new(1, -52, 0, 12), Text = "✕", BackgroundColor3 = Color3.fromRGB(120, 30, 50) }, function()
		m.Visible = false
	end)
	modals[name] = m
	return m
end

------------------------------------------------------------------------
-- ПЕРЕХОД: чёрный экран
------------------------------------------------------------------------
local fading = false

-- Затемнение -> действие (fn) -> плавное появление. fn может вернуть результат.
function UI.FadeTransition(text, fn)
	if fading then
		return fn and fn() or nil
	end
	fading = true
	local black = new("Frame", { Parent = UI.Gui, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, ZIndex = 200 })
	local t = new("TextLabel", { Parent = black, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(700, 60), Font = Enum.Font.FredokaOne, TextScaled = true, Text = text or "", TextColor3 = THEME.Accent, TextTransparency = 1, ZIndex = 201 })
	tween(black, 0.35, { BackgroundTransparency = 0 })
	tween(t, 0.35, { TextTransparency = 0 })
	FX.Sound("Portal", 0.8, 1)
	task.wait(0.4)
	local a, b
	if fn then
		a, b = fn()
	end
	task.wait(0.45)
	tween(black, 0.55, { BackgroundTransparency = 1 })
	tween(t, 0.4, { TextTransparency = 1 })
	task.delay(0.6, function()
		black:Destroy()
		fading = false
	end)
	return a, b
end

------------------------------------------------------------------------
-- КЕЙСЫ: витрина, шансы, анимации открытия
------------------------------------------------------------------------
local CaseModels
local selectedCase = "VoidCase"
local caseViews = {}

-- 3D-кейс во ViewportFrame
local function caseViewport(parent, caseId, props)
	props = props or {}
	local vf = new("ViewportFrame", {
		Parent = parent,
		BackgroundTransparency = 1,
		Size = props.Size or UDim2.fromScale(1, 1),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.new(),
		Ambient = Color3.fromRGB(160, 140, 190),
		LightColor = Color3.fromRGB(255, 245, 255),
		LightDirection = Vector3.new(-0.5, -1, -0.7),
		ZIndex = props.ZIndex or 1,
	})
	local r = CaseModels.Build(caseId)
	r.Model.Parent = vf
	local cam = Instance.new("Camera")
	cam.FieldOfView = 40
	cam.CFrame = CFrame.lookAt(Vector3.new(0, 4.5, -13), Vector3.new(0, 2.6, 0))
	cam.Parent = vf
	vf.CurrentCamera = cam
	r.Viewport = vf
	return r
end

local function rateText(case)
	local lines = {}
	for _, rarity in ipairs(Config.RarityOrder) do
		local rate = case.Rates[rarity]
		if rate and rate > 0 then
			lines[#lines + 1] = string.format('<font color="#%s">%s</font>  %s%%', Config.Rarities[rarity].Color:ToHex(), rarity:upper(), tostring(rate))
		end
	end
	return table.concat(lines, "\n")
end

function UI.SelectCase(caseId)
	if not Config.Cases[caseId] then
		return
	end
	selectedCase = caseId
	local case = Config.Cases[caseId]
	refs.CaseName.Text = case.Name
	refs.CaseName.TextColor3 = case.Color
	refs.CaseDesc.Text = case.Description
	refs.CaseRates.Text = rateText(case)
	refs.CaseBuy1.Text = "x1  💎" .. case.Cost1
	refs.CaseBuy10.Text = "x10  💎" .. case.Cost10
	refs.CaseBig:ClearAllChildren()
	caseViews.Big = caseViewport(refs.CaseBig, caseId)
	for id, b in pairs(refs.CaseTabs) do
		b.Border.Color = id == caseId and Config.Cases[id].Color or THEME.AccentDark
	end
	for _, c in ipairs(refs.CaseUnits:GetChildren()) do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	for i, id in ipairs(case.Units) do
		local def = Config.Units[id]
		local rc = rarityColor(id)
		local cell = panel({ Parent = refs.CaseUnits, Size = UDim2.fromOffset(100, 108), BackgroundColor3 = THEME.BG2, StrokeColor = rc, LayoutOrder = Config.Rarities[def.Rarity].Order * 100 + i, ZIndex = 7 })
		viewport(cell, id, 1, { Size = UDim2.new(1, 0, 0, 74), ZIndex = 8 })
		label({ Parent = cell, Size = UDim2.new(1, -6, 0, 16), Position = UDim2.fromOffset(3, 74), Text = def.Name, Font = Enum.Font.GothamBold, ZIndex = 8 })
		label({ Parent = cell, Size = UDim2.new(1, -6, 0, 14), Position = UDim2.fromOffset(3, 90), Text = def.Rarity, TextColor3 = rc, ZIndex = 8 })
	end
end

local function showCards(overlay, results)
	local grid = new("Frame", { Parent = overlay, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(5 * 150, (#results > 5 and 2 or 1) * 200), Position = UDim2.fromScale(0.5, 0.55), ZIndex = 22 }, {
		new("UIGridLayout", { CellSize = UDim2.fromOffset(140, 190), CellPadding = UDim2.fromOffset(10, 10), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	for i, r in ipairs(results) do
		task.delay(0.15 * i, function()
			local def = Config.Units[r.Id]
			local rc = rarityColor(r.Id)
			local card = panel({ Parent = grid, BackgroundColor3 = THEME.BG2, StrokeColor = rc, LayoutOrder = i, ZIndex = 23 })
			new("UIGradient", { Parent = card, Rotation = 90, Color = ColorSequence.new(rc:Lerp(THEME.BG, 0.55), THEME.BG) })
			local sc = new("UIScale", { Parent = card, Scale = 0 })
			viewport(card, r.Id, 1, { Size = UDim2.new(1, 0, 0, 120), Position = UDim2.fromOffset(0, 8), ZIndex = 24 })
			label({ Parent = card, Size = UDim2.new(1, -8, 0, 22), Position = UDim2.fromOffset(4, 130), Text = def.Name, ZIndex = 24 })
			label({ Parent = card, Size = UDim2.new(1, -8, 0, 18), Position = UDim2.fromOffset(4, 154), Text = def.Rarity:upper(), TextColor3 = rc, ZIndex = 24 })
			if r.New then
				local tag = label({ Parent = card, Size = UDim2.fromOffset(56, 22), Position = UDim2.fromOffset(6, 6), Text = "NEW!", TextColor3 = THEME.Gold, ZIndex = 25 })
				tag.Rotation = -12
			end
			tween(sc, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
			FX.Sound("Reveal", 1, 0.8 + Config.Rarities[def.Rarity].Order * 0.12)
		end)
	end
	task.delay(0.15 * #results + 0.4, function()
		button({ Parent = overlay, AnchorPoint = Vector2.new(0.5, 1), Size = UDim2.fromOffset(200, 54), Position = UDim2.new(0.5, 0, 0.95, 0), Text = "OK", ZIndex = 25 }, function()
			overlay:Destroy()
		end)
	end)
end

-- Анимация открытия: у каждого кейса своя
local function playCaseOpening(caseId, results)
	local case = Config.Cases[caseId]
	local best = 1
	for _, r in ipairs(results) do
		best = math.max(best, Config.Rarities[Config.Units[r.Id].Rarity].Order)
	end
	local bestName = Config.RarityOrder[best]
	local bestColor = Config.Rarities[bestName].Color
	local overlay = new("Frame", { Parent = gui, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(5, 0, 10), BackgroundTransparency = 0.15, ZIndex = 20 })
	local stage = new("Frame", { Parent = overlay, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(520, 520), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 21 })
	local r = caseViewport(stage, caseId, { ZIndex = 21 })
	local title = label({ Parent = overlay, AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.fromOffset(700, 56), Position = UDim2.new(0.5, 0, 0.06, 0), Text = case.Name, TextColor3 = case.Color, ZIndex = 22, StrokeThickness = 3 })
	local start = os.clock()
	local SHAKE, BURST = 1.4, 0.9
	local nextTick = 0
	local dirs = {}
	for p, base in pairs(r.Base) do
		local d = base.Position - Vector3.new(0, 2, 0)
		dirs[p] = (d.Magnitude > 0.1 and d.Unit or Vector3.new(0, 1, 0)) + Vector3.new(math.random() - 0.5, math.random() * 0.6, math.random() - 0.5)
	end
	local done = false
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - start
		if t < SHAKE then
			-- фаза 1: тряска, свечение, у каждого кейса своё
			local k = t / SHAKE
			local shake = CFrame.new((math.random() - 0.5) * k * 0.5, 0, (math.random() - 0.5) * k * 0.5) * CFrame.Angles(0, t * (1 + k * 6), (math.random() - 0.5) * k * 0.15)
			for p, base in pairs(r.Base) do
				p.CFrame = shake * base
			end
			if caseId == "VoidCase" and r.Lid then
				r.Lid.CFrame = shake * r.Base[r.Lid] * CFrame.new(0, k * 1.2, 0.6 * k) * CFrame.Angles(-k * 0.9, 0, 0)
			elseif caseId == "ShatteredReality" then
				for _, c in ipairs(r.Cracks) do
					c.Size = Vector3.new(0.14 + k * 0.3, 0.14 + k * 0.3, c.Size.Z)
				end
				if r.Core then
					r.Core.CFrame = shake * r.Base[r.Core] * CFrame.new(0, k * 1.5, 0) * CFrame.Angles(0, t * 8, 0)
				end
			elseif caseId == "BloodMoon" and r.Shards[1] then
				r.Shards[1].CFrame = shake * r.Base[r.Shards[1]] * CFrame.new(0, -k * 2.8, 0)
				overlay.BackgroundColor3 = Color3.fromRGB(5 + k * 60, 0, 10)
			end
			for i, s in ipairs(r.Shards) do
				if not (caseId == "BloodMoon" and i == 1) then
					s.CFrame = CFrame.Angles(0, t * (2 + k * 10), 0) * s.CFrame
				end
			end
			if t >= nextTick then
				nextTick = t + 0.45 - k * 0.3
				FX.Sound("CaseShake", 1, 0.8 + k * 0.8)
			end
		elseif t < SHAKE + BURST then
			-- фаза 2: разрушение — части разлетаются
			if not r.Burst then
				r.Burst = true
				FX.Sound("CaseOpen", 1, 1)
				local flash = new("Frame", { Parent = overlay, Size = UDim2.fromScale(1, 1), BackgroundColor3 = bestColor, BackgroundTransparency = 0.1, ZIndex = 30 })
				tween(flash, 0.8, { BackgroundTransparency = 1 })
				task.delay(0.85, function()
					flash:Destroy()
				end)
			end
			local k = (t - SHAKE) / BURST
			for p, base in pairs(r.Base) do
				local d = dirs[p]
				p.CFrame = CFrame.new(d * k * 14) * base * CFrame.Angles(k * 4 * d.X, k * 5, k * 4 * d.Z)
				p.Transparency = math.min(1, k * 1.3)
			end
		elseif not done then
			done = true
			conn:Disconnect()
			stage:Destroy()
			title.Text = best >= 4 and (bestName:upper() .. "!") or case.Name
			title.TextColor3 = bestColor
			if bestName == "Secret" then
				-- SECRET: чёрный экран, красные молнии, тряска
				FX.Sound("Secret", 1, 1)
				FX.Shake(0.8, 1.2)
				local black = new("Frame", { Parent = overlay, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), ZIndex = 40 })
				local big = label({ Parent = black, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(900, 160), Position = UDim2.fromScale(0.5, 0.5), Text = "SECRET!!", TextColor3 = Color3.fromRGB(255, 30, 50), ZIndex = 41, StrokeThickness = 4 })
				for i = 1, 8 do
					task.delay(i * 0.12, function()
						black.BackgroundColor3 = (i % 2 == 0) and Color3.fromRGB(120, 0, 10) or Color3.new(0, 0, 0)
						big.Rotation = (math.random() - 0.5) * 10
					end)
				end
				task.delay(1.4, function()
					tween(black, 0.4, { BackgroundTransparency = 1 })
					tween(big, 0.4, { TextTransparency = 1 })
					task.delay(0.45, function()
						black:Destroy()
					end)
					showCards(overlay, results)
				end)
			else
				showCards(overlay, results)
			end
		end
	end)
end

local function buildCases()
	local m = modal("Summon", "КЕЙСЫ", UDim2.fromOffset(980, 590), "Gem")
	refs.CaseTabs = {}
	local tabs = new("Frame", { Parent = m, BackgroundTransparency = 1, Size = UDim2.fromOffset(200, 480), Position = UDim2.fromOffset(18, 70), ZIndex = 6 }, {
		new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	for i, id in ipairs(Config.CaseOrder) do
		local case = Config.Cases[id]
		local b = button({ Parent = tabs, Size = UDim2.fromOffset(200, 140), Text = "", BackgroundColor3 = THEME.BG2, StrokeColor = case.Color, LayoutOrder = i, ZIndex = 7 }, function()
			UI.SelectCase(id)
			FX.Sound("Click", 1, 1)
		end)
		caseViewport(b, id, { Size = UDim2.new(1, 0, 0, 100), ZIndex = 8 })
		label({ Parent = b, Size = UDim2.new(1, -10, 0, 26), Position = UDim2.fromOffset(5, 104), Text = case.Name, TextColor3 = case.Color, ZIndex = 8 })
		refs.CaseTabs[id] = b
	end
	refs.CaseBig = new("Frame", { Parent = m, BackgroundColor3 = THEME.BG2, BackgroundTransparency = 0.3, Size = UDim2.fromOffset(300, 300), Position = UDim2.fromOffset(236, 70), ZIndex = 6 }, { corner(10) })
	refs.CaseName = label({ Parent = m, Size = UDim2.fromOffset(420, 40), Position = UDim2.fromOffset(548, 70), Text = "", TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 6 })
	refs.CaseDesc = label({ Parent = m, Size = UDim2.fromOffset(420, 40), Position = UDim2.fromOffset(548, 112), Text = "", TextScaled = false, TextSize = 15, TextWrapped = true, Font = Enum.Font.Gotham, TextColor3 = THEME.Dim, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 6 })
	refs.CaseRates = label({ Parent = m, Size = UDim2.fromOffset(420, 150), Position = UDim2.fromOffset(548, 156), Text = "", RichText = true, TextScaled = false, TextSize = 18, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 6 })
	label({ Parent = m, Size = UDim2.fromOffset(420, 20), Position = UDim2.fromOffset(548, 306), Text = "В x10 гарантирован минимум один Rare+", TextScaled = false, TextSize = 14, Font = Enum.Font.GothamBold, TextColor3 = THEME.Dim, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 6 })
	refs.CaseUnits = new("ScrollingFrame", { Parent = m, BackgroundTransparency = 1, Size = UDim2.fromOffset(732, 150), Position = UDim2.fromOffset(236, 380), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.X, ScrollingDirection = Enum.ScrollingDirection.X, ScrollBarThickness = 6, BorderSizePixel = 0, ZIndex = 6 }, {
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	refs.CaseUnitsLayoutCell = UDim2.fromOffset(100, 106)
	refs.SummonGems = label({ Parent = m, Size = UDim2.fromOffset(240, 36), Position = UDim2.new(0, 236, 1, -52), Text = "💎 0", TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(120, 200, 255), ZIndex = 6 })
	local busy = false
	local function open(count)
		if busy then
			return
		end
		busy = true
		local ok, res = ctx.Request("Summon", { Case = selectedCase, Count = count })
		busy = false
		if ok then
			playCaseOpening(selectedCase, res)
		end
	end
	refs.CaseBuy1 = button({ Parent = m, AnchorPoint = Vector2.new(1, 1), Size = UDim2.fromOffset(200, 50), Position = UDim2.new(1, -238, 1, -12), Text = "x1", BackgroundColor3 = THEME.AccentDark, ZIndex = 6 }, function()
		open(1)
	end)
	refs.CaseBuy10 = button({ Parent = m, AnchorPoint = Vector2.new(1, 1), Size = UDim2.fromOffset(210, 50), Position = UDim2.new(1, -18, 1, -12), Text = "x10", BackgroundColor3 = Color3.fromRGB(150, 60, 200), StrokeColor = THEME.Gold, ZIndex = 6 }, function()
		open(10)
	end)
	UI.SelectCase(selectedCase)
end

------------------------------------------------------------------------
-- МАГАЗИН КРИСТАЛЛОВ
------------------------------------------------------------------------
local function buildShop()
	local m = modal("Shop", "МАГАЗИН КРИСТАЛЛОВ", UDim2.fromOffset(920, 470), "Gem")
	local row = new("Frame", { Parent = m, BackgroundTransparency = 1, Size = UDim2.new(1, -36, 0, 270), Position = UDim2.fromOffset(18, 70), ZIndex = 6 }, {
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10), HorizontalAlignment = Enum.HorizontalAlignment.Center }),
	})
	for i, item in ipairs(Config.Shop) do
		local card = panel({ Parent = row, Size = UDim2.fromOffset(165, 266), BackgroundColor3 = THEME.BG2, StrokeColor = Color3.fromRGB(90, 180, 255), LayoutOrder = i, ZIndex = 6 })
		new("UIGradient", { Parent = card, Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(40, 70, 120), THEME.BG) })
		label({ Parent = card, Size = UDim2.new(1, 0, 0, 70), Position = UDim2.fromOffset(0, 12), Text = string.rep("💎", math.min(i, 3)), ZIndex = 7 })
		label({ Parent = card, Size = UDim2.new(1, -10, 0, 40), Position = UDim2.fromOffset(5, 86), Text = Config.FormatNumber(item.Gems), TextColor3 = Color3.fromRGB(130, 210, 255), ZIndex = 7 })
		label({ Parent = card, Size = UDim2.new(1, -10, 0, 34), Position = UDim2.fromOffset(5, 128), Text = item.Title, TextScaled = false, TextSize = 14, TextWrapped = true, Font = Enum.Font.GothamBold, ZIndex = 7 })
		if item.Bonus then
			local tag = label({ Parent = card, Size = UDim2.fromOffset(70, 24), Position = UDim2.new(1, -74, 0, 6), Text = item.Bonus, TextColor3 = THEME.Gold, ZIndex = 8 })
			tag.Rotation = 10
		end
		button({ Parent = card, AnchorPoint = Vector2.new(0.5, 1), Size = UDim2.new(1, -20, 0, 48), Position = UDim2.new(0.5, 0, 1, -12), Text = "R$ " .. item.Robux, BackgroundColor3 = Color3.fromRGB(50, 140, 80), StrokeColor = THEME.Good, ZIndex = 7 }, function()
			local ok, res = ctx.Request("BuyGems", { Key = item.Key })
			if ok and res ~= "prompt" then
				FX.Sound("Purchase", 1, 1)
				UI.Toast("+" .. Config.FormatNumber(res) .. " 💎 (тестовая покупка в Studio)", "good")
			end
		end)
	end
	-- ежедневный подарок
	local daily = panel({ Parent = m, Size = UDim2.new(1, -36, 0, 74), Position = UDim2.new(0, 18, 1, -90), BackgroundColor3 = THEME.BG2, StrokeColor = THEME.Gold, ZIndex = 6 })
	label({ Parent = daily, Size = UDim2.new(0.6, 0, 1, -16), Position = UDim2.fromOffset(14, 8), Text = "🎁 Бесплатный подарок: " .. Config.Settings.DailyGems .. " 💎", TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = THEME.Gold, ZIndex = 7 })
	refs.DailyButton = button({ Parent = daily, AnchorPoint = Vector2.new(1, 0.5), Size = UDim2.fromOffset(260, 52), Position = UDim2.new(1, -12, 0.5, 0), Text = "ЗАБРАТЬ", BackgroundColor3 = Color3.fromRGB(150, 110, 30), StrokeColor = THEME.Gold, ZIndex = 7 }, function()
		local ok, res = ctx.Request("ClaimDaily")
		if ok then
			FX.Sound("Purchase", 1, 1.2)
			UI.Toast("+" .. tostring(res) .. " 💎 Подарок получен!", "gold")
		end
	end)
end

function UI.UpdateShop()
	local prof = ctx.Profile
	if not refs.DailyButton or not prof then
		return
	end
	local left = (prof.DailyReadyAt or 0) - os.time()
	if left > 0 then
		refs.DailyButton.Text = string.format("через %d:%02d:%02d", left // 3600, (left % 3600) // 60, left % 60)
	else
		refs.DailyButton.Text = "ЗАБРАТЬ"
	end
end

function UI.SpinCases(t)
	local r = caseViews.Big
	if r and r.Model.Parent then
		r.Model:PivotTo(CFrame.Angles(0, t * 0.6, 0))
	end
end

------------------------------------------------------------------------
-- ИНВЕНТАРЬ И ЭКИПИРОВКА
------------------------------------------------------------------------
local invSelected

local function buildInventory()
	local m = modal("Inventory", "ЮНИТЫ", UDim2.fromOffset(860, 560), "Helmet")
	-- экипировка
	label({ Parent = m, Size = UDim2.fromOffset(300, 22), Position = UDim2.fromOffset(18, 56), Text = "ЭКИПИРОВКА (клик — снять)", TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = THEME.Dim, Font = Enum.Font.GothamBold, ZIndex = 6 })
	refs.EquipRow = new("Frame", { Parent = m, BackgroundTransparency = 1, Size = UDim2.new(1, -36, 0, 92), Position = UDim2.fromOffset(18, 80), ZIndex = 6 }, {
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8) }),
	})
	-- коллекция
	refs.InvGrid = new("ScrollingFrame", { Parent = m, BackgroundTransparency = 1, Size = UDim2.new(0, 500, 1, -196), Position = UDim2.fromOffset(18, 182), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 6, BorderSizePixel = 0, ZIndex = 6 }, {
		new("UIGridLayout", { CellSize = UDim2.fromOffset(112, 140), CellPadding = UDim2.fromOffset(10, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
		pad(4),
	})
	-- детали
	local d = panel({ Parent = m, BackgroundColor3 = THEME.BG2, Size = UDim2.new(1, -556, 1, -196), Position = UDim2.fromOffset(536, 182), ZIndex = 6 })
	refs.InvDetail = d
	refs.InvName = label({ Parent = d, Size = UDim2.new(1, -20, 0, 30), Position = UDim2.fromOffset(10, 8), Text = "Выбери юнита", TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 7 })
	refs.InvRarity = label({ Parent = d, Size = UDim2.new(1, -20, 0, 18), Position = UDim2.fromOffset(10, 38), Text = "", TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 7 })
	refs.InvDesc = label({ Parent = d, Size = UDim2.new(1, -20, 0, 48), Position = UDim2.fromOffset(10, 60), Text = "", TextScaled = false, TextSize = 14, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Font = Enum.Font.Gotham, TextColor3 = THEME.Dim, ZIndex = 7 })
	refs.InvStats = label({ Parent = d, Size = UDim2.new(1, -20, 0, 120), Position = UDim2.fromOffset(10, 110), Text = "", TextScaled = false, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Font = Enum.Font.Code, ZIndex = 7 })
	refs.InvEquip = button({ Parent = d, AnchorPoint = Vector2.new(0, 1), Size = UDim2.new(1, -20, 0, 44), Position = UDim2.new(0, 10, 1, -10), Text = "EQUIP", BackgroundColor3 = Color3.fromRGB(60, 130, 80), ZIndex = 7 }, function()
		if invSelected then
			UI.ToggleEquip(invSelected)
		end
	end)
end

-- Экипировать / снять юнита (из инвентаря и из окна просмотра)
function UI.ToggleEquip(unitId)
	local prof = ctx.Profile
	if not prof or (prof.Inventory[unitId] or 0) <= 0 then
		return
	end
	local equippedSlot
	for i = 1, Config.Settings.EquipSlots do
		if prof.Equipped[tostring(i)] == unitId then
			equippedSlot = i
		end
	end
	if equippedSlot then
		ctx.Request("Equip", { Unit = nil, Slot = equippedSlot })
	else
		local free
		for i = 1, Config.Settings.EquipSlots do
			if not prof.Equipped[tostring(i)] then
				free = i
				break
			end
		end
		if not free then
			UI.Toast("Все слоты заняты — сними юнита сверху", "error")
			return
		end
		ctx.Request("Equip", { Unit = unitId, Slot = free })
	end
end

local function selectInventory(id)
	invSelected = id
	local def = Config.Units[id]
	local prof = ctx.Profile
	local owned = (prof.Inventory[id] or 0) > 0
	refs.InvName.Text = def.Name
	refs.InvRarity.Text = def.Rarity:upper() .. (def.Ability and ("  •  " .. def.Ability) or "")
	refs.InvRarity.TextColor3 = rarityColor(id)
	refs.InvDesc.Text = def.Description
	local lines = { "LV   DMG     RNG   CD     COST" }
	for i, st in ipairs(def.Levels) do
		lines[#lines + 1] = string.format("%-4d %-7s %-5s %-6s $%s", i, Config.FormatNumber(st.Damage), tostring(st.Range), string.format("%.2f", st.Cooldown), Config.FormatNumber(st.Cost))
	end
	refs.InvStats.Text = table.concat(lines, "\n")
	local equipped = false
	for i = 1, Config.Settings.EquipSlots do
		if prof.Equipped[tostring(i)] == id then
			equipped = true
		end
	end
	refs.InvEquip.Visible = owned
	refs.InvEquip.Text = equipped and "UNEQUIP" or "EQUIP"
	refs.InvEquip.BackgroundColor3 = equipped and Color3.fromRGB(130, 50, 60) or Color3.fromRGB(60, 130, 80)
end

function UI.RefreshInventory()
	local prof = ctx.Profile
	if not prof or not refs.InvGrid then
		return
	end
	for _, c in ipairs(refs.EquipRow:GetChildren()) do
		if not c:IsA("UIListLayout") then
			c:Destroy()
		end
	end
	for i = 1, Config.Settings.EquipSlots do
		local id = prof.Equipped[tostring(i)]
		local b = button({ Parent = refs.EquipRow, Size = UDim2.fromOffset(92, 90), Text = "", BackgroundColor3 = THEME.BG2, StrokeColor = id and rarityColor(id) or THEME.AccentDark, LayoutOrder = i, ZIndex = 7 }, function()
			if id then
				ctx.Request("Equip", { Unit = nil, Slot = i })
			end
		end)
		if id then
			viewport(b, id, 1, { ZIndex = 8 })
		else
			label({ Parent = b, Size = UDim2.fromScale(1, 1), Text = tostring(i), TextColor3 = THEME.Dim, ZIndex = 8 })
		end
	end
	for _, c in ipairs(refs.InvGrid:GetChildren()) do
		if c:IsA("GuiButton") then
			c:Destroy()
		end
	end
	for order, id in ipairs(Config.UnitOrder) do
		local def = Config.Units[id]
		local count = prof.Inventory[id] or 0
		local rc = rarityColor(id)
		local b = button({ Parent = refs.InvGrid, Text = "", BackgroundColor3 = THEME.BG2, StrokeColor = count > 0 and rc or Color3.fromRGB(60, 50, 70), LayoutOrder = order, ZIndex = 7 }, function()
			selectInventory(id)
			if (ctx.Profile.Inventory[id] or 0) > 0 then
				UnitViewer.Open(id, 1)
			else
				UI.Toast("Сначала открой этого юнита в кейсе — тогда откроется 3D-просмотр", "error")
			end
		end)
		new("UIGradient", { Parent = b, Rotation = 90, Color = ColorSequence.new(rc:Lerp(THEME.BG, count > 0 and 0.6 or 0.9), THEME.BG) })
		viewport(b, id, 1, { Size = UDim2.new(1, 0, 0, 96), ZIndex = 8, Silhouette = count == 0 })
		label({ Parent = b, Size = UDim2.new(1, -8, 0, 18), Position = UDim2.fromOffset(4, 98), Text = count > 0 and def.Name or "???", Font = Enum.Font.GothamBold, ZIndex = 8 })
		label({ Parent = b, Size = UDim2.new(1, -8, 0, 16), Position = UDim2.fromOffset(4, 118), Text = def.Rarity, TextColor3 = rc, ZIndex = 8 })
		if count > 0 then
			label({ Parent = b, Size = UDim2.fromOffset(40, 20), Position = UDim2.new(1, -44, 0, 4), Text = "x" .. count, TextColor3 = THEME.Gold, ZIndex = 9 })
		end
	end
	if invSelected then
		selectInventory(invSelected)
	end
end

------------------------------------------------------------------------
-- ВЫБОР СЛОЖНОСТИ (круг ИГРАТЬ)
------------------------------------------------------------------------
local function joinMatch(diffKey)
	UI.Show("Mode", false)
	task.spawn(function()
		local ok = UI.FadeTransition("ПОРТАЛ ОТКРЫВАЕТСЯ...", function()
			return ctx.Request("JoinMatch", { Difficulty = diffKey })
		end)
		if not ok then
			UI.Show("Mode", true)
		end
	end)
end

local function buildMode()
	local m = modal("Mode", "ВЫБОР СЛОЖНОСТИ", UDim2.fromOffset(880, 430))
	local cards = new("Frame", { Parent = m, BackgroundTransparency = 1, Size = UDim2.new(1, -36, 0, 340), Position = UDim2.fromOffset(18, 70), ZIndex = 6 }, {
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 12), HorizontalAlignment = Enum.HorizontalAlignment.Center }),
	})
	refs.ModeCards = cards
	for i, key in ipairs(Config.DifficultyOrder) do
		local d = Config.Difficulties[key]
		local card = panel({ Parent = cards, Size = UDim2.fromOffset(200, 336), BackgroundColor3 = THEME.BG2, StrokeColor = d.Color, LayoutOrder = i, ZIndex = 6 })
		new("UIGradient", { Parent = card, Rotation = 90, Color = ColorSequence.new(d.Color:Lerp(THEME.BG, 0.6), THEME.BG) })
		label({ Parent = card, Size = UDim2.new(1, -16, 0, 40), Position = UDim2.fromOffset(8, 10), Text = d.Name, TextColor3 = d.Color, ZIndex = 7 })
		local lines = {
			string.format("HP врагов   x%.2g", d.HP),
			string.format("Скорость    x%.2g", d.Speed),
			string.format("Деньги      x%.2g", d.Money),
			string.format("Гемы        x%.2g", d.Gems),
			string.format("Ядро        %d HP", d.CoreHP),
		}
		label({ Parent = card, Size = UDim2.new(1, -20, 0, 110), Position = UDim2.fromOffset(10, 58), Text = table.concat(lines, "\n"), TextScaled = false, TextSize = 16, Font = Enum.Font.Code, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 7 })
		label({ Parent = card, Size = UDim2.new(1, -20, 0, 70), Position = UDim2.fromOffset(10, 176), Text = d.Description, TextScaled = false, TextSize = 14, TextWrapped = true, Font = Enum.Font.Gotham, TextColor3 = THEME.Dim, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 7 })
		button({ Parent = card, AnchorPoint = Vector2.new(0.5, 1), Size = UDim2.new(1, -24, 0, 50), Position = UDim2.new(0.5, 0, 1, -12), Text = "ИГРАТЬ", BackgroundColor3 = d.Color:Lerp(Color3.new(0, 0, 0), 0.45), StrokeColor = d.Color, ZIndex = 7 }, function()
			joinMatch(key)
		end)
	end
	-- если матч уже идёт — присоединиться
	local running = new("Frame", { Parent = m, BackgroundTransparency = 1, Size = UDim2.new(1, -36, 0, 300), Position = UDim2.fromOffset(18, 80), Visible = false, ZIndex = 6 })
	refs.ModeRunning = running
	refs.ModeRunningText = label({ Parent = running, Size = UDim2.new(1, 0, 0, 90), Position = UDim2.fromOffset(0, 40), Text = "", ZIndex = 7 })
	button({ Parent = running, AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.fromOffset(320, 64), Position = UDim2.new(0.5, 0, 0, 170), Text = "ПРИСОЕДИНИТЬСЯ", BackgroundColor3 = THEME.AccentDark, ZIndex = 7 }, function()
		joinMatch(nil)
	end)
end

function UI.RefreshMode()
	local phase = ctx.State:GetAttribute("Phase") or "Idle"
	local idle = phase == "Idle"
	refs.ModeCards.Visible = idle
	refs.ModeRunning.Visible = not idle
	if not idle then
		local d = Config.Difficulties[ctx.State:GetAttribute("Difficulty") or "Medium"] or Config.Difficulties.Medium
		local w = ctx.State:GetAttribute("Wave") or 0
		refs.ModeRunningText.Text = "Уже идёт бой: " .. d.Name .. ", волна " .. w .. "\nПрисоединяйся к команде!"
		refs.ModeRunningText.TextColor3 = d.Color
	end
end

------------------------------------------------------------------------
-- ПОБЕДА / ПОРАЖЕНИЕ
------------------------------------------------------------------------
local function showEnd(victory, payload)
	local overlay = new("Frame", { Parent = gui, Size = UDim2.fromScale(1, 1), BackgroundColor3 = victory and Color3.fromRGB(30, 10, 50) or Color3.fromRGB(40, 0, 10), BackgroundTransparency = 1, ZIndex = 30 })
	tween(overlay, 0.6, { BackgroundTransparency = 0.3 })
	local title = label({ Parent = overlay, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(800, 120), Position = UDim2.fromScale(0.5, 0.38), Text = victory and "VICTORY" or "DEFEAT", TextColor3 = victory and THEME.Gold or THEME.Bad, ZIndex = 31, StrokeThickness = 4 })
	local sc = new("UIScale", { Parent = title, Scale = 0.2 })
	tween(sc, 0.5, { Scale = 1 }, Enum.EasingStyle.Back)
	local sub = victory and ("Пустота отступила! Награда: 💎" .. tostring(payload.Gems)) or ("Ядро Пустоты разрушено на волне " .. tostring(payload.Wave))
	label({ Parent = overlay, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(800, 40), Position = UDim2.fromScale(0.5, 0.5), Text = sub, ZIndex = 31 })
	local timer = label({ Parent = overlay, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(600, 30), Position = UDim2.fromScale(0.5, 0.57), Text = "", TextColor3 = THEME.Dim, ZIndex = 31 })
	local reset = payload.Reset or 15
	task.spawn(function()
		for i = reset, 1, -1 do
			if not overlay.Parent then
				return
			end
			timer.Text = "Новая игра через " .. i .. " c"
			task.wait(1)
		end
	end)
	refs.EndOverlay = overlay
end

------------------------------------------------------------------------
-- СОБЫТИЯ
------------------------------------------------------------------------
function UI.OnNotify(p)
	local t = p.Type
	if t == "Toast" then
		UI.Toast(p.Text, p.Kind)
	elseif t == "WaveStart" then
		FX.Sound(p.Boss and "Boss" or "WaveStart", 1, 1)
		if p.Boss then
			FX.Shake(0.4, 0.8)
			UI.Announce("WAVE " .. p.Wave, "⚠ BOSS: " .. p.Boss, THEME.Pink)
		else
			UI.Announce("WAVE " .. p.Wave, nil, THEME.Text)
		end
	elseif t == "WaveClear" then
		UI.Toast(string.format("Волна %d пройдена! +$%s  +💎%d", p.Wave, Config.FormatNumber(p.Reward), p.Gems), "good")
	elseif t == "BossDown" then
		FX.Shake(0.6, 0.6)
	elseif t == "CoreHit" then
		if player:GetAttribute("InMatch") then
			FX.Shake(0.35, 0.3)
			FX.Sound("CoreHit", 1, 1)
		end
		local f = refs.CoreFill
		f.BackgroundColor3 = THEME.Bad
		tween(f, 0.4, { BackgroundColor3 = THEME.Accent })
	elseif t == "Victory" then
		FX.Sound("Victory", 1, 1)
		showEnd(true, p)
	elseif t == "Defeat" then
		FX.Sound("Defeat", 1, 1)
		showEnd(false, p)
	elseif t == "Fade" then
		task.spawn(UI.FadeTransition, p.Text or "")
	elseif t == "Purchase" then
		FX.Sound("Purchase", 1, 1)
		UI.Toast("Покупка: +" .. Config.FormatNumber(p.Gems or 0) .. " 💎", "gold")
	elseif t == "Reset" then
		if refs.EndOverlay then
			refs.EndOverlay:Destroy()
			refs.EndOverlay = nil
		end
		UI.CloseUnit()
		UI.Toast("Бой окончен. Ты в лобби — встань в круг ИГРАТЬ", "good")
	end
end

function UI.SetLiteText(on)
	refs.LiteCaption.Text = on and "ЛЁГКАЯ" or "ПОЛНАЯ"
	refs.LiteCaption.TextColor3 = on and THEME.Good or THEME.Text
end

function UI.SetProfile(prof)
	ctx.Profile = prof
	refreshHotbar()
	UnitViewer.Refresh()
	if modals.Inventory and modals.Inventory.Visible then
		UI.RefreshInventory()
	end
end

local lastRefresh = 0
function UI.Update(dt)
	local State = ctx.State
	local money = player:GetAttribute("Money") or 0
	refs.Money.Text = Config.FormatNumber(money)
	local gems = player:GetAttribute("Gems") or (ctx.Profile and ctx.Profile.Gems) or 0
	refs.Gems.Text = Config.FormatNumber(gems)
	if refs.SummonGems then
		refs.SummonGems.Text = "💎 " .. Config.FormatNumber(gems)
	end

	local wave = State:GetAttribute("Wave") or 0
	local maxWave = State:GetAttribute("MaxWave") or 30
	local phase = State:GetAttribute("Phase") or "Idle"
	local inMatch = player:GetAttribute("InMatch") == true
	refs.Top.Visible = inMatch
	refs.Hotbar.Visible = inMatch
	refs.Leave.Visible = inMatch
	refs.Money.Visible = inMatch
	refs.Currency.Size = UDim2.fromOffset(230, inMatch and 92 or 50)
	refs.Gems.Position = UDim2.fromOffset(52, inMatch and 50 or 8)
	refs.GemsIcon.Position = UDim2.fromOffset(10, inMatch and 49 or 7)
	refs.MoneyIcon.Visible = inMatch
	if not inMatch and UI.SelectedUid then
		UI.CloseUnit()
	end
	if modals.Mode.Visible then
		UI.RefreshMode()
	end
	local diff = Config.Difficulties[State:GetAttribute("Difficulty") or ""]
	refs.Wave.Text = "WAVE " .. wave .. " / " .. maxWave .. (diff and ("  •  " .. diff.Name) or "")
	refs.Wave.TextColor3 = diff and diff.Color or THEME.Text
	local count = 0
	for _ in pairs(Renderer.EnemyViews) do
		count = count + 1
	end
	if phase == "Prep" then
		refs.Status.Text = "Расставь юнитов и начни волну"
	elseif phase == "Intermission" then
		local left = math.max(0, math.ceil((State:GetAttribute("NextWaveAt") or 0) - workspace:GetServerTimeNow()))
		refs.Status.Text = "Следующая волна через " .. left .. " c"
		refs.Start.Text = "▶ START WAVE (" .. left .. ")"
	elseif phase == "Wave" then
		refs.Status.Text = "Врагов на поле: " .. count
	elseif phase == "Victory" then
		refs.Status.Text = "ПОБЕДА!"
	elseif phase == "Defeat" then
		refs.Status.Text = "Ядро разрушено"
	end
	if phase == "Prep" then
		refs.Start.Text = "▶ START WAVE"
	end
	refs.Start.Visible = inMatch and (phase == "Prep" or phase == "Intermission")

	local hp = State:GetAttribute("CoreHP") or 100
	local maxHp = State:GetAttribute("CoreMaxHP") or 100
	refs.CoreFill.Size = UDim2.fromScale(math.clamp(hp / maxHp, 0, 1), 1)
	refs.CoreText.Text = "VOID CORE  " .. hp .. " / " .. maxHp

	-- босс
	local bossId = State:GetAttribute("BossId") or 0
	local bv = bossId ~= 0 and Renderer.EnemyViews[bossId]
	if bv and inMatch then
		refs.Boss.Visible = true
		refs.BossName.Text = "☠ " .. (State:GetAttribute("BossName") or "BOSS"):upper()
		refs.BossFill.Size = UDim2.fromScale(math.clamp(bv.HP / bv.MaxHP, 0, 1), 1)
		refs.BossHP.Text = Config.FormatNumber(bv.HP) .. " / " .. Config.FormatNumber(bv.MaxHP)
	else
		refs.Boss.Visible = false
	end

	-- доступность слотов
	for _, s in ipairs(slotRefs) do
		if s.Id and s.Cost then
			local cost = Config.Units[s.Id].Levels[1].Cost
			s.Cost.TextColor3 = money >= cost and THEME.Good or THEME.Bad
		end
	end

	UI.SpinCases(os.clock())
	if modals.Shop and modals.Shop.Visible then
		UI.UpdateShop()
	end
	lastRefresh = lastRefresh + dt
	if lastRefresh > 0.25 then
		lastRefresh = 0
		if UI.SelectedUid then
			UI.RefreshUnitPanel()
		end
	end
end

function UI.Init(c)
	ctx = c
	Config, UnitModels, Renderer, FX = c.Config, c.UnitModels, c.Renderer, c.FX
	CaseModels = c.CaseModels
	local pg = player:WaitForChild("PlayerGui")
	local old = pg:FindFirstChild("VoidTD_UI")
	if old then
		old:Destroy()
	end
	local screen = new("ScreenGui", { Name = "VoidTD_UI", ResetOnSpawn = false, IgnoreGuiInset = true, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = pg })
	-- корневой контейнер: UIScale + размер 1/s дают ровно весь экран при любом масштабе
	gui = new("Frame", { Name = "Root", Parent = screen, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) })
	local uiScale = new("UIScale", { Parent = gui, Name = "Scale" })
	buildHUD()
	buildHotbar()
	buildUnitPanel()
	buildCases()
	buildShop()
	buildInventory()
	buildMode()
	-- адаптация под маленькие экраны
	local cam = workspace.CurrentCamera
	local function fit()
		local vs = cam.ViewportSize
		local s = math.clamp(math.min(vs.X / 1280, vs.Y / 760), 0.55, 1.15)
		uiScale.Scale = s
		gui.Size = UDim2.fromScale(1 / s, 1 / s)
	end
	fit()
	cam:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	Renderer.OnUnitRemoved = function(uid)
		if UI.SelectedUid == uid then
			UI.CloseUnit()
		end
	end
	UI.Gui = screen
	-- окно 3D-просмотра юнита
	UI.Root = gui
	UI.Kit = { new = new, corner = corner, stroke = stroke, label = label, button = button, panel = panel, tween = tween }
	UI.SpecialText = specialText
	UnitViewer.Init(c, UI)
end

return UI
]======] }
FILES[#FILES + 1] = { "StarterPlayerScripts", { "VoidTDClient", "Placement" }, "ModuleScript", [======[
--!nocheck
-- VOID TD :: Placement (клиент)
-- Полупрозрачный призрак юнита следует за курсором, круг радиуса показывает зелёный/красный статус.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Placement = {}
Placement.Active = false

local ctx, Config, PathUtil, UnitModels, FX, UI, Renderer
local player = Players.LocalPlayer

local V = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles
local rad = math.rad

local ghost, circle, inner, conn
local unitId
local rotation = 0
local valid = false
local lastPos
local touchPos
local reason = ""

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include

local GOOD = Color3.fromRGB(80, 230, 140)
local BAD = Color3.fromRGB(255, 70, 90)

local function isTouch()
	return UserInputService.TouchEnabled and not UserInputService.MouseEnabled
end

local function countMine(id)
	local total, same = 0, 0
	for _, v in pairs(Renderer.UnitViews) do
		if v.Folder:GetAttribute("OwnerId") == player.UserId then
			total = total + 1
			if v.UnitId == id then
				same = same + 1
			end
		end
	end
	return total, same
end

local function check(hit, pos)
	if not hit or not hit.Instance:GetAttribute("Placeable") then
		return false, "Сюда ставить нельзя"
	end
	local ok, why = PathUtil.IsPlacementClear(pos)
	if not ok then
		return false, why
	end
	for _, v in pairs(Renderer.UnitViews) do
		if PathUtil.FlatDistance(v.Pos, pos) < Config.Settings.PlacementSpacing then
			return false, "Слишком близко к другому юниту"
		end
	end
	local def = Config.Units[unitId]
	if (player:GetAttribute("Money") or 0) < def.Levels[1].Cost then
		return false, "Недостаточно денег"
	end
	local total, same = countMine(unitId)
	if total >= Config.Settings.MaxUnitsPerPlayer then
		return false, "Лимит юнитов"
	end
	if same >= Config.Rarities[def.Rarity].PlacementLimit then
		return false, "Лимит этого юнита"
	end
	return true
end

local function update()
	local cam = workspace.CurrentCamera
	local ray
	if touchPos then
		ray = cam:ScreenPointToRay(touchPos.X, touchPos.Y)
	else
		local screen = UserInputService:GetMouseLocation()
		ray = cam:ViewportPointToRay(screen.X, screen.Y)
	end
	local map = workspace:FindFirstChild("VoidTDMap")
	if not map then
		return
	end
	params.FilterDescendantsInstances = { map }
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 800, params)
	if not hit then
		valid = false
		return
	end
	local pos = hit.Position
	lastPos = pos
	valid, reason = check(hit, pos)
	local hip = ghost.HipHeight
	ghost.Root.CFrame = CF(pos + V(0, hip, 0)) * ANG(0, rad(rotation), 0)
	local color = valid and GOOD or BAD
	local range = Config.Units[unitId].Levels[1].Range
	circle.Size = V(0.15, range * 2, range * 2)
	circle.CFrame = CF(pos + V(0, 0.22, 0)) * ANG(0, 0, rad(90))
	circle.Color = color
	inner.CFrame = CF(pos + V(0, 0.25, 0)) * ANG(0, 0, rad(90))
	inner.Color = color
	for _, d in ipairs(ghost.Model:GetDescendants()) do
		if d:IsA("Highlight") then
			d.FillColor = color
			d.OutlineColor = color
		end
	end
end

function Placement.Start(id)
	if not id or not Config.Units[id] then
		return
	end
	Placement.Stop()
	local def = Config.Units[id]
	if (player:GetAttribute("Money") or 0) < def.Levels[1].Cost then
		UI.Toast("Недостаточно денег: нужно $" .. Config.FormatNumber(def.Levels[1].Cost), "error")
		return
	end
	local phase = ctx.State:GetAttribute("Phase")
	if phase == "Victory" or phase == "Defeat" or not player:GetAttribute("InMatch") then
		return
	end
	unitId = id
	ghost = UnitModels.Build(id, 1)
	for _, d in ipairs(ghost.Model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CanQuery = false
			d.CanTouch = false
			d.CastShadow = false
			if d.Transparency < 1 then
				d.Transparency = 0.35 + d.Transparency * 0.5
			end
		elseif d:IsA("ParticleEmitter") or d:IsA("PointLight") or d:IsA("Trail") then
			d:Destroy()
		end
	end
	local hl = Instance.new("Highlight")
	hl.FillTransparency = 0.75
	hl.OutlineTransparency = 0.2
	hl.DepthMode = Enum.HighlightDepthMode.Occluded
	hl.Parent = ghost.Model
	ghost.Model.Parent = workspace
	circle = FX.Part({ Shape = Enum.PartType.Cylinder, Transparency = 0.72, Parent = workspace })
	circle.Name = "VoidTD_GhostRange"
	inner = FX.Part({ Shape = Enum.PartType.Cylinder, Size = V(0.2, 2.6, 2.6), Transparency = 0.3, Parent = workspace })
	Placement.Active = true
	rotation = rotation or 0
	touchPos = nil
	UI.CloseUnit()
	UI.ShowPlacementHint(true, isTouch())
	conn = RunService.RenderStepped:Connect(update)
	update()
end

function Placement.Stop()
	Placement.Active = false
	if conn then
		conn:Disconnect()
		conn = nil
	end
	if ghost then
		ghost.Model:Destroy()
		ghost = nil
	end
	if circle then
		circle:Destroy()
		circle = nil
	end
	if inner then
		inner:Destroy()
		inner = nil
	end
	UI.ShowPlacementHint(false)
end

function Placement.Rotate()
	rotation = (rotation + 45) % 360
end

function Placement.Confirm()
	if not Placement.Active then
		return
	end
	update()
	if not valid then
		UI.Toast(reason ~= "" and reason or "Сюда ставить нельзя", "error")
		return
	end
	local id = unitId
	local ok = ctx.Request("Place", { Unit = id, Position = lastPos, Rotation = rotation })
	if ok then
		local keep = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
		local enough = (player:GetAttribute("Money") or 0) >= Config.Units[id].Levels[1].Cost
		if not (keep and enough) then
			Placement.Stop()
		end
	end
end

function Placement.SetTouch(pos)
	touchPos = pos
end

function Placement.Init(c)
	ctx = c
	Config, PathUtil, UnitModels, FX, UI, Renderer = c.Config, c.PathUtil, c.UnitModels, c.FX, c.UI, c.Renderer
end

return Placement
]======] }

for _, f in ipairs(FILES) do
	install(f[1], f[2], f[3], f[4])
end
print("[VOID TD] Часть 3/3 установлена" .. (2 == 2 and ". Готово! Сохрани место и нажми Play." or ". Вставь следующую часть."))
