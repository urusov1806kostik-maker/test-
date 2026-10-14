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
local ZONE_MODAL = { Summon = "Summon", Units = "Inventory", Play = "Mode" }
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
			UI.Show(ZONE_MODAL[key], inside)
			if inside then
				FX.Sound("Ping", 0.3, 1.1)
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
local SOUNDS = {
	Slash = "rbxasset://sounds/swordslash.wav",
	Lunge = "rbxasset://sounds/swordlunge.wav",
	Place = "rbxasset://sounds/unsheath.wav",
	Ping = "rbxasset://sounds/electronicpingshort.wav",
}
local lastSound = {}

function FX.Sound(name, volume, pitch, pos)
	local id = SOUNDS[name]
	if not id then
		return
	end
	local t = os.clock()
	if lastSound[name] and t - lastSound[name] < 0.07 then
		return
	end
	-- приглушаем далёкие звуки
	if pos then
		local cam = workspace.CurrentCamera
		local d = cam and (cam.CFrame.Position - pos).Magnitude or 0
		if d > 120 then
			return
		end
		volume = (volume or 0.4) * math.clamp(1 - d / 120, 0.15, 1)
	end
	lastSound[name] = t
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume or 0.4
	s.PlaybackSpeed = pitch or 1
	s.Parent = SoundService
	s:Play()
	task.delay(3, function()
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
	p.CFrame = CFrame.lookAt(from, last)
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
function FX.Shockwave(pos, radius, lv)
	local g = V(pos.X, pos.Y + 0.2, pos.Z)
	FX.Sound("Lunge", 0.6, 0.55, pos)
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
function FX.Reap(unitPos, center, radius, lv)
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
	FX.Sound("Slash", 0.5, 0.8 + (hitIndex or 1) * 0.08, pos)
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
		FX.Sound("Lunge", 0.7, 0.4, pos)
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
	FX.Sound("Ping", 0.4, 1.3, pos)
	FX.Ring(pos + V(0, 0.2, 0), 4, color or NEON, 0.6, 0.3)
	local col = FX.Part({ Shape = Enum.PartType.Cylinder, Size = V(0.2, 3, 3), CFrame = CF(pos + V(0, 0.3, 0)) * ANG(0, 0, rad(90)), Color = color or NEON, Transparency = 0.2 })
	tween(col, 0.7, { CFrame = CF(pos + V(0, 7, 0)) * ANG(0, 0, rad(90)), Transparency = 1, Size = V(0.1, 4.5, 4.5) })
	cleanup(col, 0.75)
	FX.Burst(pos + V(0, 3, 0), color or NEON_SOFT, 14, 0.35, 7, 0.7)
end

function FX.Place(pos)
	FX.Sound("Place", 0.5, 1, pos)
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

local FIDGETS = {
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
			elseif name == "WingR" or name == "WingL" then
				local side = name == "WingR" and 1 or -1
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
	}
	local pos, dir = PathUtil.OffsetPositionAt(dist, lateral)
	view.CF = CFrame.lookAt(pos + V(0, rig.HipHeight, 0), pos + dir + V(0, rig.HipHeight, 0))
	view.SpawnT = os.clock()
	view.Emerge = dist <= 1
	if Config.Enemies[typeId].IsBoss then
		view.RoarT = os.clock() + 0.6
		task.delay(0.6, function()
			FX.Sound("Lunge", 0.8, 0.3)
			FX.Shake(0.5, 0.9)
		end)
	end
	rig.Root.CFrame = view.CF
	makeHealthBar(view)
	rig.Model.Parent = enemyFolder
	enemyViews[id] = view
	if dist <= 1 then
		FX.Burst(pos + V(0, 2, 0), FX.Colors.Neon, 6, 0.3, 5)
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
	FX.Poof(root.Position + V(0, 0.5, 0), FX.Colors.Neon, size)
	if def.IsBoss then
		FX.Shockwave(root.Position - V(0, rig.HipHeight - 0.2, 0), 10 * size, 5)
	end
	local start = os.clock()
	local startCF = root.CFrame
	local life = def.IsBoss and 1.4 or 0.6
	local parts = {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and d.Transparency < 1 then
			parts[#parts + 1] = { d, d.Transparency }
		elseif d:IsA("ParticleEmitter") then
			d.Enabled = false
		end
	end
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local a = math.clamp((os.clock() - start) / life, 0, 1)
		root.CFrame = startCF * CF(0, -a * rig.HipHeight * 0.8, 0) * ANG(rad(-75 * ease(a)), 0, rad(15 * a))
		for _, p in ipairs(parts) do
			p[1].Transparency = p[2] + (1 - p[2]) * a
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

local function animateEnemy(view, t, dt)
	local rig = view.Rig
	local base = rig.Base
	local m = rig.Motors
	-- отшатывание от удара
	local hitA = t - (view.HitT or -10)
	local flinch = hitA < 0.2 and (1 - hitA / 0.2) * 0.22 or 0
	local def = Config.Enemies[view.Type]
	local freq = (view.Speed * (view.Slowed and 0.5 or 1)) / math.max(def.Scale or 1, 0.5) * 1.1
	local w = t * freq + view.Phase
	local s = math.sin(w)
	if rig.Style == "Biped" then
		if m.RH then
			m.RH.C0 = base.RH * ANG(s * 0.6, 0, 0)
			m.LH.C0 = base.LH * ANG(-s * 0.6, 0, 0)
			m.RS.C0 = base.RS * ANG(-s * 0.5, 0, 0)
			m.LS.C0 = base.LS * ANG(s * 0.5, 0, 0)
			local idle = rig.Idle.Root
			local tilt = idle and rad(idle[1]) or 0
			m.Root.C0 = base.Root * CF(0, math.abs(s) * 0.12 * (rig.Scale or 1), 0) * ANG(tilt, 0, s * 0.04)
		end
	elseif rig.Style == "Quad" then
		if m.FR then
			m.FR.C0 = base.FR * ANG(s * 0.6, 0, 0)
			m.BL.C0 = base.BL * ANG(s * 0.6, 0, 0)
			m.FL.C0 = base.FL * ANG(-s * 0.6, 0, 0)
			m.BR.C0 = base.BR * ANG(-s * 0.6, 0, 0)
		end
		m.Root.C0 = base.Root * CF(0, math.abs(s) * 0.1 * (rig.Scale or 1), 0) * ANG(s * 0.03, 0, 0)
		if m.Neck then
			m.Neck.C0 = base.Neck * ANG(math.sin(w * 2) * 0.06, 0, 0)
		end
	else -- Float
		m.Root.C0 = base.Root * CF(0, math.sin(t * 2 + view.Phase) * 0.3 * (rig.Scale or 1), 0) * ANG(0.12, 0, math.sin(t * 1.3 + view.Phase) * 0.06)
		for _, name in ipairs({ "ArmR", "ArmL", "ArmR2", "ArmL2", "RS", "LS" }) do
			if m[name] and base[name] then
				local side = (name:sub(-1) == "R" or name == "RS" or name == "ArmR2") and 1 or -1
				m[name].C0 = base[name] * ANG(math.sin(t * 2.2 + view.Phase + side) * 0.3 + 0.3, 0, math.sin(t * 1.7) * 0.15 * side)
			end
		end
	end
	if flinch > 0 then
		m.Root.C0 = m.Root.C0 * ANG(-flinch, 0, flinch * 0.3)
	end
	-- рёв босса при появлении
	local roarA = t - (view.RoarT or -10)
	local roar = (roarA > 0 and roarA < 1.4) and math.sin(roarA / 1.4 * math.pi) or 0
	if roar > 0 then
		if m.RS and base.RS then
			m.RS.C0 = base.RS * ANG(rad(150 * roar), 0, rad(30 * roar))
			m.LS.C0 = base.LS * ANG(rad(150 * roar), 0, rad(-30 * roar))
		end
		if m.Neck and base.Neck then
			m.Neck.C0 = base.Neck * ANG(rad(-30 * roar), 0, 0)
		end
		m.Root.C0 = m.Root.C0 * ANG(rad(-12 * roar), 0, 0)
	end
	if m.Jaw then
		m.Jaw.C0 = base.Jaw * ANG(math.max(0, math.sin(t * 3 + view.Phase)) * 0.45 + roar * 0.6, 0, 0)
	end
	if m.Halo then
		m.Halo.C0 = base.Halo * ANG(0, t * 1.5, 0)
	end
end

local function updateEnemies(t, dt)
	local nowc = os.clock()
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
		v.Rig.Root.CFrame = v.CF - V(0, rise, 0)
		animateEnemy(v, t, dt)
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

	if def.AttackType == "Projectile" then
		at(h, function()
			if not view.Rig or not view.Rig.Model.Parent then
				return
			end
			local from = muzzlePos(view)
			FX.Sound("Lunge", def.Projectile == "Bolt" and 0.12 or 0.25, def.Projectile == "Bolt" and 1.8 or 1.3, from)
			FX.Projectile(def.Projectile, from, function()
				return Renderer.EnemyCenter(firstId)
			end, p.TR or 0.2, function(pos)
				FX.Burst(pos, def.Projectile == "Orb" and FX.Colors.Neon or FX.Colors.Soft, def.Projectile == "Orb" and 8 or 4, 0.3, 5)
				if def.Projectile == "Orb" then
					FX.Sphere(pos, 1.4 + lv * 0.15, FX.Colors.Neon, 0.25)
				end
			end, lv)
			if def.Projectile == "Bolt" then
				FX.Sphere(from, 0.6, FX.Colors.Soft, 0.12)
			end
		end)
	elseif def.AttackType == "Laser" then
		at(h, function()
			local target = Renderer.EnemyCenter(firstId) or tpos
			if target and view.Rig.Model.Parent then
				FX.Sound("Lunge", 0.5, 0.7, target)
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
			local big = view.UnitId == "AbyssOverlord"
			FX.Arc(cf, reach, rad(15), rad(150), big and FX.Colors.Neon or FX.Colors.Soft, big and 1 or (0.4 + lv * 0.05), 0.3)
			FX.Sound("Slash", 0.35, big and 0.7 or 1.1, target)
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
					FX.Sound("Slash", 0.35, 1.25, target)
					if lv >= 3 then
						FX.SlashMark(target, rad(i % 2 == 0 and 40 or -40), 5 + lv * 0.5, 0.35, FX.Colors.Neon, 0.3)
					end
				else
					-- Void Emperor: вспышка на мече, сам разрез — в Impact
					FX.Sphere(muzzlePos(view), 1.6, FX.Colors.Pink, 0.2)
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
		FX.Reap(view and view.Pos or p.P, p.P, p.R, lv)
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
FILES[#FILES + 1] = { "StarterPlayerScripts", { "VoidTDClient", "UI" }, "ModuleScript", [======[
--!nocheck
-- VOID TD :: UI (клиент)
-- Весь интерфейс создаётся кодом: HUD, хотбар, панель юнита, Summon, инвентарь, уведомления.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local UI = {}

local ctx, Config, UnitModels, Renderer, FX
local player = Players.LocalPlayer

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
	cam.CFrame = CFrame.lookAt(center + Vector3.new(4.2, 2.0, -10.5) * s, center)
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
	refs.Money = label({ Parent = cur, Size = UDim2.new(1, -20, 0, 38), Position = UDim2.fromOffset(12, 6), Text = "💰 0", TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = THEME.Good })
	refs.Gems = label({ Parent = cur, Size = UDim2.new(1, -20, 0, 34), Position = UDim2.fromOffset(12, 50), Text = "💎 0", TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(120, 200, 255) })

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

	-- инвентарь всегда на экране
	refs.InvButton = button({ Parent = gui, Size = UDim2.fromOffset(150, 44), Position = UDim2.fromOffset(16, 118), Text = "☰ ЮНИТЫ (G)", BackgroundColor3 = THEME.BG3 }, function()
		UI.Toggle("Inventory")
	end)

	-- облегчённая графика
	refs.LiteButton = button({ Parent = gui, AnchorPoint = Vector2.new(1, 0), Size = UDim2.fromOffset(190, 40), Position = UDim2.new(1, -16, 0, 16), Text = "⚙ ГРАФИКА: ПОЛНАЯ", BackgroundColor3 = THEME.BG3 }, function()
		ctx.SetLite(not ctx.Lite, true)
	end)

	-- выход из матча в лобби
	refs.Leave = button({ Parent = gui, Size = UDim2.fromOffset(150, 44), Position = UDim2.fromOffset(16, 170), Text = "⟵ В ЛОББИ", BackgroundColor3 = Color3.fromRGB(110, 35, 55), StrokeColor = THEME.Bad }, function()
		ctx.Placement.Stop()
		local ok = ctx.Request("LeaveMatch")
		if ok then
			UI.CloseUnit()
		end
	end)

	-- подсказка в лобби
	local hint = panel({ Parent = gui, AnchorPoint = Vector2.new(0.5, 1), Size = UDim2.fromOffset(640, 86), Position = UDim2.new(0.5, 0, 1, -18), StrokeColor = THEME.Accent })
	refs.LobbyHint = hint
	label({ Parent = hint, Size = UDim2.new(1, -20, 0, 36), Position = UDim2.fromOffset(10, 6), Text = "ЛОББИ", TextColor3 = THEME.Accent })
	label({ Parent = hint, Size = UDim2.new(1, -20, 0, 32), Position = UDim2.fromOffset(10, 46), Font = Enum.Font.GothamBold, Text = "Встань в круг:  ✦ SUMMON — призыв   •   ▶ ИГРАТЬ — в бой   •   ☰ ЮНИТЫ — кнопка слева или G" })

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
	local p = panel({ Parent = gui, AnchorPoint = Vector2.new(1, 0.5), Size = UDim2.fromOffset(310, 470), Position = UDim2.new(1, -16, 0.45, 0), Visible = false })
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

local function modal(name, title, size)
	local m = panel({ Parent = gui, AnchorPoint = Vector2.new(0.5, 0.5), Size = size, Position = UDim2.fromScale(0.5, 0.5), Visible = false, BackgroundTransparency = 0.04, ZIndex = 5 })
	new("UIScale", { Parent = m })
	label({ Parent = m, Size = UDim2.new(1, -80, 0, 44), Position = UDim2.fromOffset(18, 10), Text = title, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = THEME.Accent })
	button({ Parent = m, Size = UDim2.fromOffset(40, 40), Position = UDim2.new(1, -52, 0, 12), Text = "✕", BackgroundColor3 = Color3.fromRGB(120, 30, 50) }, function()
		m.Visible = false
	end)
	modals[name] = m
	return m
end

------------------------------------------------------------------------
-- SUMMON
------------------------------------------------------------------------
local function showSummonResults(results)
	local overlay = new("Frame", { Parent = gui, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(5, 0, 10), BackgroundTransparency = 0.25, ZIndex = 20 })
	local best = 1
	for _, r in ipairs(results) do
		best = math.max(best, Config.Rarities[Config.Units[r.Id].Rarity].Order)
	end
	local bestName = Config.RarityOrder[best]
	local flash = new("Frame", { Parent = overlay, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Config.Rarities[bestName].Color, BackgroundTransparency = 0.3, ZIndex = 21 })
	tween(flash, 0.8, { BackgroundTransparency = 1 })
	label({ Parent = overlay, AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.fromOffset(600, 60), Position = UDim2.new(0.5, 0, 0.08, 0), Text = best >= 4 and (bestName:upper() .. "!") or "SUMMON", TextColor3 = Config.Rarities[bestName].Color, ZIndex = 22, StrokeThickness = 3 })
	local grid = new("Frame", { Parent = overlay, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(5 * 150, (#results > 5 and 2 or 1) * 200), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 22 }, {
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
			FX.Sound("Ping", 0.3, 0.8 + Config.Rarities[def.Rarity].Order * 0.15)
		end)
	end
	task.delay(0.15 * #results + 0.4, function()
		button({ Parent = overlay, AnchorPoint = Vector2.new(0.5, 1), Size = UDim2.fromOffset(200, 54), Position = UDim2.new(0.5, 0, 0.92, 0), Text = "OK", ZIndex = 25 }, function()
			overlay:Destroy()
		end)
	end)
end

local function buildSummon()
	local m = modal("Summon", "✦ VOID SUMMON", UDim2.fromOffset(760, 520))
	label({ Parent = m, Size = UDim2.new(1, -36, 0, 20), Position = UDim2.fromOffset(18, 54), Text = "Призови воинов Пустоты. В x10 гарантирован минимум один Rare+.", TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = THEME.Dim, Font = Enum.Font.GothamBold, ZIndex = 6 })
	local list = new("ScrollingFrame", { Parent = m, BackgroundTransparency = 1, Size = UDim2.new(1, -36, 0, 330), Position = UDim2.fromOffset(18, 82), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 6, BorderSizePixel = 0, ZIndex = 6 }, {
		new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	for order, rarity in ipairs(Config.RarityOrder) do
		local r = Config.Rarities[rarity]
		local row = panel({ Parent = list, Size = UDim2.new(1, -10, 0, 74), BackgroundColor3 = THEME.BG2, StrokeColor = r.Color, LayoutOrder = order, ZIndex = 6 })
		label({ Parent = row, Size = UDim2.fromOffset(130, 30), Position = UDim2.fromOffset(12, 8), Text = rarity:upper(), TextColor3 = r.Color, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 7 })
		label({ Parent = row, Size = UDim2.fromOffset(130, 24), Position = UDim2.fromOffset(12, 40), Text = string.format("%.1f%%", r.Rate), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = THEME.Text, ZIndex = 7 })
		local x = 150
		for _, id in ipairs(Config.UnitOrder) do
			if Config.Units[id].Rarity == rarity then
				local cell = new("Frame", { Parent = row, BackgroundColor3 = THEME.BG, BackgroundTransparency = 0.3, Size = UDim2.fromOffset(160, 64), Position = UDim2.fromOffset(x, 5), ZIndex = 7 }, { corner(6) })
				viewport(cell, id, 1, { Size = UDim2.fromOffset(60, 64), ZIndex = 8 })
				label({ Parent = cell, Size = UDim2.new(1, -64, 0, 22), Position = UDim2.fromOffset(62, 21), Text = Config.Units[id].Name, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 8 })
				x = x + 168
			end
		end
	end
	refs.SummonGems = label({ Parent = m, Size = UDim2.fromOffset(240, 36), Position = UDim2.new(0, 18, 1, -70), Text = "💎 0", TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(120, 200, 255), ZIndex = 6 })
	local busy = false
	local function summon(count)
		if busy then
			return
		end
		busy = true
		local ok, res = ctx.Request("Summon", { Count = count })
		busy = false
		if ok then
			showSummonResults(res)
		end
	end
	button({ Parent = m, AnchorPoint = Vector2.new(1, 1), Size = UDim2.fromOffset(200, 56), Position = UDim2.new(1, -238, 1, -16), Text = "x1  💎" .. Config.Settings.SummonCost1, BackgroundColor3 = THEME.AccentDark, ZIndex = 6 }, function()
		summon(1)
	end)
	button({ Parent = m, AnchorPoint = Vector2.new(1, 1), Size = UDim2.fromOffset(210, 56), Position = UDim2.new(1, -18, 1, -16), Text = "x10  💎" .. Config.Settings.SummonCost10, BackgroundColor3 = Color3.fromRGB(150, 60, 200), StrokeColor = THEME.Gold, ZIndex = 6 }, function()
		summon(10)
	end)
end

------------------------------------------------------------------------
-- ИНВЕНТАРЬ И ЭКИПИРОВКА
------------------------------------------------------------------------
local invSelected

local function buildInventory()
	local m = modal("Inventory", "☰ ЮНИТЫ", UDim2.fromOffset(860, 560))
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
		if not invSelected then
			return
		end
		local prof = ctx.Profile
		local equippedSlot
		for i = 1, Config.Settings.EquipSlots do
			if prof.Equipped[tostring(i)] == invSelected then
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
			ctx.Request("Equip", { Unit = invSelected, Slot = free })
		end
	end)
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
	local ok = ctx.Request("JoinMatch", { Difficulty = diffKey })
	if ok then
		UI.Show("Mode", false)
		FX.Sound("Ping", 0.5, 0.8)
	end
end

local function buildMode()
	local m = modal("Mode", "▶ ВЫБОР СЛОЖНОСТИ", UDim2.fromOffset(880, 430))
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
		FX.Sound("Ping", 0.35, p.Boss and 0.6 or 1)
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
		end
		local f = refs.CoreFill
		f.BackgroundColor3 = THEME.Bad
		tween(f, 0.4, { BackgroundColor3 = THEME.Accent })
	elseif t == "Victory" then
		showEnd(true, p)
	elseif t == "Defeat" then
		showEnd(false, p)
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
	refs.LiteButton.Text = on and "⚙ ГРАФИКА: ЛЁГКАЯ" or "⚙ ГРАФИКА: ПОЛНАЯ"
	refs.LiteButton.BackgroundColor3 = on and Color3.fromRGB(60, 110, 70) or THEME.BG3
end

function UI.SetProfile(prof)
	ctx.Profile = prof
	refreshHotbar()
	if modals.Inventory and modals.Inventory.Visible then
		UI.RefreshInventory()
	end
end

local lastRefresh = 0
function UI.Update(dt)
	local State = ctx.State
	local money = player:GetAttribute("Money") or 0
	refs.Money.Text = "💰 " .. Config.FormatNumber(money)
	local gems = player:GetAttribute("Gems") or (ctx.Profile and ctx.Profile.Gems) or 0
	refs.Gems.Text = "💎 " .. Config.FormatNumber(gems)
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
	refs.Gems.Position = UDim2.fromOffset(12, inMatch and 50 or 8)
	refs.InvButton.Position = UDim2.fromOffset(16, inMatch and 118 or 76)
	refs.LobbyHint.Visible = not inMatch and not (modals.Mode.Visible or modals.Summon.Visible or modals.Inventory.Visible)
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
	buildSummon()
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
