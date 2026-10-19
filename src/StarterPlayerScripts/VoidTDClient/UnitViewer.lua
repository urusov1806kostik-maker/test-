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
