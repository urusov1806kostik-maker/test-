--!nocheck
-- VOID TD :: UI.Kit (клиент) — тема, конструкторы, нарисованные иконки, 3D-превью, теги события
-- Весь интерфейс создаётся кодом: без картинок и эмодзи в иконках (иконки — из Frame).
--
-- ПОДКЛЮЧЕНИЕ
--   local Kit = require(script.Kit); Kit.Build(UI, ctx)   -- первым из детей UI
--   Build: Kit.UI = UI; UI.Kit = Kit; UI.Theme = Kit.Theme; UI.Modals = UI.Modals or {} (Kit.Modals — та же
--   таблица); модели берутся из ctx (UnitModels, EnemyModels, CaseModels), иначе из ReplicatedStorage.VoidTD.Models.
--   Окна (modal) кладутся в UI.Root (или Kit.Root, если задан); Kit.SetRoot(frame) — сменить вручную.
--
-- ТЕМА
--   Kit.Theme = { BG BG2 BG3 Accent AccentDark Text Dim Good Bad Gold Pink, Orange (255,130,30) HGold (255,205,80) }
--
-- КОНСТРУКТОРЫ (props — свойства экземпляра; Parent ставится ПОСЛЕДНИМ; служебные ключи
--   Radius / StrokeColor / StrokeThickness не пишутся в экземпляр)
--   Kit.new(class, props?, children?) -> Instance
--   Kit.corner(r=8) -> UICorner (offset)
--   Kit.stroke(color=Accent, th=2, transparency=0) -> UIStroke Name="Border" (Border mode; код меняет obj.Border.Color)
--   Kit.textStroke(th=1.5) -> UIStroke (10,0,20) Contextual
--   Kit.pad(px) -> UIPadding со всех сторон
--   Kit.tween(obj, t, goal, style=Quad, dir=Out) -> Tween (уже запущен)
--   Kit.panel(props) -> Frame  BG, прозрачность 0.12, угол Radius|10, рамка Border StrokeColor|AccentDark (2)
--   Kit.label(props) -> TextLabel  без фона, FredokaOne, цвет Text, TextScaled (если не false), обводка StrokeThickness
--   Kit.button(props, onClick?) -> TextButton  BG3, FredokaOne, угол Radius|8, рамка Border StrokeColor|Accent,
--        UIScale с анимацией наведения (1.06 / 1 / 0.94 / 1.04); onClick — на Activated
--   Kit.shape(parent, x, y, w, h, color, rot?, round?, z?, props?) -> Frame  фигура в долях контейнера (центр x,y)
--   Kit.shade(frame, top, bottom, rot=90) -> UIGradient
--
-- ИКОНКИ
--   Kit.icon(kind, parent, props?) -> Frame "Icon"..kind (квадрат, UIAspectRatioConstraint)
--        props: Size (по умолчанию scale 1,1), Position, AnchorPoint, ZIndex (фигуры рисуются с ZIndex+1..)
--        kind: Gem Coin Helmet Gear Back Pumpkin Rune; Kit.Icons[kind] = function(container, z) — свои иконки
--   Kit.iconButton(parent, order, kind, caption, top, bottom, edge, onClick?, size=76) -> button, captionLabel
--        TextButton Name = kind.."Button", градиент top->bottom, рамка edge, блик, иконка 0.72, подпись снизу
--
-- ОКНА
--   Kit.modal(name, title, size, iconKind?, parent?) -> Frame
--        панель по центру (ZIndex 5, скрыта, UIScale для анимации открытия), иконка 38x38, заголовок
--        (прямой ребёнок окна — по нему тесты ищут окна), кнопка "✕" прячет окно; регистрируется в UI.Modals[name]
--
-- 3D-ПРЕВЬЮ (ViewportFrame; частицы, свет, шлейфы, огонь/дым убираются — во ViewportFrame они не рисуются)
--   Kit.unitViewport(parent, unitId, level=1, props?) -> vf, rig|nil   (props.Silhouette — чёрный силуэт)
--   Kit.enemyViewport(parent, enemyId, props?) -> vf, rig|nil
--   Kit.runeViewport(parent, runeId, props?) -> vf, r|nil   (вращается в Kit.StepSpins; vf:GetAttribute("Spin"))
--   Kit.caseViewport(parent, caseId, props?) -> r   (r = CaseModels.Build(caseId) + r.Viewport; при ошибке —
--        заглушка { Model = пустая Model, Base = {}, Shards = {}, Cracks = {}, Failed = true, Viewport })
--   props: Size (scale 1,1), Position, AnchorPoint, ZIndex. Kit.viewport = Kit.unitViewport (как в легаси).
--
-- ПРОЧЕЕ
--   Kit.rarityColor(unitId) -> Color3 (цвет редкости; неизвестный юнит — Theme.Dim)
--   Kit.eventTag(parent, unitId, z=1, textPos?, textSize?)  -- только для юнитов события (def.Event):
--        тыква 22x22 в углу, подпись Events[ev].Tag (если textPos), 4 искры. Рамка остаётся цветом редкости.
--   Kit.eventSparks(parent, z, n=4)
--   Kit.StepSparks(t=os.clock())  -- каждый кадр из UI.Update: искры поднимаются и гаснут; также крутит руны
--   Kit.StepSpins(t=os.clock())   -- только вращение 3D-рун (видимых)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("VoidTD")
local Config = require(Shared:WaitForChild("Config"))

local Kit = {}
Kit.Modals = {}

local V2 = Vector2.new
local V3 = Vector3.new
local rgb = Color3.fromRGB
local WHITE = Color3.new(1, 1, 1)

local Theme = {
	BG = rgb(16, 10, 26),
	BG2 = rgb(32, 20, 50),
	BG3 = rgb(48, 30, 72),
	Accent = rgb(170, 80, 255),
	AccentDark = rgb(90, 40, 150),
	Text = rgb(242, 234, 255),
	Dim = rgb(170, 155, 195),
	Good = rgb(90, 220, 140),
	Bad = rgb(255, 80, 110),
	Gold = rgb(255, 205, 70),
	Pink = rgb(255, 70, 170),
	-- цвета события Хэллоуин
	Orange = rgb(255, 130, 30),
	HGold = rgb(255, 205, 80),
}
Kit.Theme = Theme

------------------------------------------------------------------------
-- ПОДКЛЮЧЕНИЕ
------------------------------------------------------------------------
local ctx

function Kit.Build(UI, c)
	ctx = c or ctx
	if UI then
		Kit.UI = UI
		UI.Kit = Kit
		UI.Theme = Theme
		local modals = UI.Modals or {}
		for name, m in pairs(Kit.Modals) do
			if modals[name] == nil then
				modals[name] = m
			end
		end
		UI.Modals = modals
		Kit.Modals = modals
	end
	return Kit
end

function Kit.SetRoot(frame)
	Kit.Root = frame
end

-- модели: из ctx, иначе напрямую из ReplicatedStorage
local function models(key, child)
	local m = ctx and ctx[key]
	if m then
		return m
	end
	local folder = Shared:FindFirstChild("Models")
	local mod = folder and folder:FindFirstChild(child)
	if mod then
		local ok, res = pcall(require, mod)
		if ok then
			return res
		end
	end
	return nil
end

------------------------------------------------------------------------
-- КОНСТРУКТОРЫ
------------------------------------------------------------------------
local CUSTOM = { Parent = true, Radius = true, StrokeColor = true, StrokeThickness = true }

local function new(class, props, children)
	local o = Instance.new(class)
	if props then
		for k, v in pairs(props) do
			if not CUSTOM[k] then
				o[k] = v
			end
		end
	end
	if children then
		for _, c in ipairs(children) do
			c.Parent = o
		end
	end
	if props and props.Parent then
		o.Parent = props.Parent
	end
	return o
end
Kit.new = new

-- копия props с значениями по умолчанию (исходную таблицу не трогаем)
local function with(props, defaults)
	local o = {}
	for k, v in pairs(defaults) do
		o[k] = v
	end
	if props then
		for k, v in pairs(props) do
			o[k] = v
		end
	end
	return o
end

function Kit.corner(r)
	return new("UICorner", { CornerRadius = UDim.new(0, r or 8) })
end

function Kit.stroke(color, th, transparency)
	return new("UIStroke", {
		Name = "Border",
		Color = color or Theme.Accent,
		Thickness = th or 2,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function Kit.textStroke(th)
	return new("UIStroke", { Color = rgb(10, 0, 20), Thickness = th or 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual })
end

function Kit.pad(px)
	local u = UDim.new(0, px or 0)
	return new("UIPadding", { PaddingLeft = u, PaddingRight = u, PaddingTop = u, PaddingBottom = u })
end

local function tween(o, t, goal, style, dir)
	local tw = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), goal)
	tw:Play()
	return tw
end
Kit.tween = tween

function Kit.panel(props)
	props = props or {}
	local p = with(props, { BackgroundColor3 = Theme.BG, BackgroundTransparency = 0.12 })
	p.BorderSizePixel = 0
	local parent = p.Parent
	p.Parent = nil
	local f = new("Frame", p)
	Kit.corner(props.Radius or 10).Parent = f
	Kit.stroke(props.StrokeColor or Theme.AccentDark, 2).Parent = f
	f.Parent = parent
	return f
end

function Kit.label(props)
	props = props or {}
	local p = with(props, { Font = Enum.Font.FredokaOne, TextColor3 = Theme.Text, TextScaled = true })
	p.BackgroundTransparency = 1
	local parent = p.Parent
	p.Parent = nil
	local l = new("TextLabel", p)
	Kit.textStroke(props.StrokeThickness).Parent = l
	l.Parent = parent
	return l
end

-- анимация наведения/нажатия через UIScale
local function hoverScale(b, over, down)
	local sc = new("UIScale", { Parent = b })
	b.MouseEnter:Connect(function()
		tween(sc, 0.12, { Scale = over })
	end)
	b.MouseLeave:Connect(function()
		tween(sc, 0.12, { Scale = 1 })
	end)
	b.MouseButton1Down:Connect(function()
		tween(sc, 0.06, { Scale = down })
	end)
	b.MouseButton1Up:Connect(function()
		tween(sc, 0.1, { Scale = 1.04 })
	end)
	return sc
end

function Kit.button(props, onClick)
	props = props or {}
	local p = with(props, { BackgroundColor3 = Theme.BG3, Font = Enum.Font.FredokaOne, TextColor3 = Theme.Text, TextScaled = true })
	p.BorderSizePixel = 0
	p.AutoButtonColor = false
	local parent = p.Parent
	p.Parent = nil
	local b = new("TextButton", p)
	Kit.corner(props.Radius or 8).Parent = b
	Kit.stroke(props.StrokeColor or Theme.Accent, 2).Parent = b
	Kit.textStroke().Parent = b
	hoverScale(b, 1.06, 0.94)
	if onClick then
		b.Activated:Connect(onClick)
	end
	b.Parent = parent
	return b
end

------------------------------------------------------------------------
-- ИКОНКИ ИЗ ФИГУР
------------------------------------------------------------------------
-- фигура в долях контейнера: центр (x, y), размер (w, h), поворот, скругление (доля)
local function shape(parent, x, y, w, h, color, rot, round, z, props)
	local f = new("Frame", {
		AnchorPoint = V2(0.5, 0.5),
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
	if props then
		for k, v in pairs(props) do
			f[k] = v
		end
	end
	f.Parent = parent
	return f
end
Kit.shape = shape

local function shade(f, top, bottom, rot)
	return new("UIGradient", { Parent = f, Rotation = rot or 90, Color = ColorSequence.new(top, bottom) })
end
Kit.shade = shade

local function edge(f, color, th)
	new("UIStroke", { Parent = f, Color = color, Thickness = th })
end

local Icons = {}
Kit.Icons = Icons

-- кристалл: огранённый ромб с бликом
function Icons.Gem(c, z)
	local o = shape(c, 0.5, 0.52, 0.6, 0.6, WHITE, 45, 0.12, z)
	shade(o, rgb(150, 210, 255), rgb(80, 70, 220), 45)
	edge(o, rgb(20, 14, 50), 2)
	shape(c, 0.5, 0.4, 0.28, 0.28, rgb(215, 240, 255), 45, 0.1, z + 1, { BackgroundTransparency = 0.15 })
	shape(c, 0.38, 0.38, 0.08, 0.16, WHITE, 45, 0.5, z + 2, { BackgroundTransparency = 0.1 })
end

-- монета со знаком $
function Icons.Coin(c, z)
	local o = shape(c, 0.5, 0.5, 0.74, 0.74, WHITE, 0, 0.5, z)
	shade(o, rgb(255, 225, 110), rgb(190, 120, 30))
	edge(o, rgb(70, 40, 10), 2)
	local i = shape(c, 0.5, 0.5, 0.5, 0.5, rgb(215, 150, 45), 0, 0.5, z + 1)
	new("TextLabel", {
		Parent = i,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "$",
		TextScaled = true,
		Font = Enum.Font.FredokaOne,
		TextColor3 = rgb(90, 50, 10),
		ZIndex = z + 2,
	})
end

-- шлем рыцаря Пустоты: рога, купол, гребень, Т-визор
function Icons.Helmet(c, z)
	local acc = rgb(196, 130, 255)
	for _, sx in ipairs({ -1, 1 }) do
		shape(c, 0.5 + 0.26 * sx, 0.26, 0.09, 0.3, rgb(215, 205, 190), 28 * sx, 0.3, z)
	end
	local h = shape(c, 0.5, 0.55, 0.54, 0.62, WHITE, 0, 0.22, z + 1)
	shade(h, rgb(110, 106, 130), rgb(40, 36, 54))
	edge(h, rgb(16, 12, 24), 2)
	shape(c, 0.5, 0.2, 0.1, 0.18, rgb(90, 86, 110), 0, 0.3, z)
	shape(c, 0.5, 0.48, 0.38, 0.07, acc, 0, 0.5, z + 2)
	shape(c, 0.5, 0.6, 0.07, 0.24, acc, 0, 0.5, z + 2)
end

-- шестерёнка настроек: 8 зубцов, диск, отверстие
function Icons.Gear(c, z)
	local col = rgb(190, 186, 210)
	for k = 0, 7 do
		local a = k / 8 * math.pi * 2
		shape(c, 0.5 + math.cos(a) * 0.3, 0.5 + math.sin(a) * 0.3, 0.16, 0.16, col, math.deg(a), 0.15, z)
	end
	shape(c, 0.5, 0.5, 0.6, 0.6, col, 0, 0.5, z + 1)
	shape(c, 0.5, 0.5, 0.26, 0.26, rgb(34, 30, 48), 0, 0.5, z + 2)
end

-- стрелка «назад»
function Icons.Back(c, z)
	local col = rgb(255, 235, 240)
	shape(c, 0.56, 0.5, 0.5, 0.12, col, 0, 0.5, z)
	shape(c, 0.34, 0.37, 0.32, 0.12, col, -42, 0.5, z)
	shape(c, 0.34, 0.63, 0.32, 0.12, col, 42, 0.5, z)
end

-- тыква: три дольки, хвостик, вырезанное лицо
function Icons.Pumpkin(c, z)
	for i, x in ipairs({ 0.3, 0.7, 0.5 }) do
		local mid = i == 3
		local o = shape(c, x, 0.58, mid and 0.42 or 0.38, 0.6, WHITE, 0, 0.45, z + (mid and 1 or 0))
		shade(o, rgb(255, 165, 60), rgb(190, 80, 20))
		edge(o, rgb(70, 25, 5), 1.5)
	end
	shape(c, 0.52, 0.22, 0.1, 0.18, rgb(80, 110, 40), 14, 0.3, z + 2)
	local eye = rgb(255, 230, 120)
	for _, x in ipairs({ 0.38, 0.62 }) do
		shape(c, x, 0.52, 0.12, 0.12, eye, 45, 0.1, z + 3)
	end
	shape(c, 0.5, 0.7, 0.34, 0.08, eye, 0, 0.4, z + 3)
end

-- руна: камень-ромб с символом
function Icons.Rune(c, z)
	local o = shape(c, 0.5, 0.5, 0.62, 0.62, WHITE, 45, 0.15, z)
	shade(o, rgb(255, 160, 60), rgb(120, 30, 40), 45)
	edge(o, rgb(40, 10, 10), 2)
	local glyph = rgb(255, 240, 200)
	shape(c, 0.5, 0.5, 0.08, 0.42, glyph, 0, 0.5, z + 1)
	shape(c, 0.5, 0.4, 0.3, 0.07, glyph, 30, 0.5, z + 1)
	shape(c, 0.5, 0.6, 0.3, 0.07, glyph, -30, 0.5, z + 1)
end

-- квадратный контейнер с иконкой
function Kit.icon(kind, parent, props)
	props = props or {}
	local z = props.ZIndex or 1
	local c = new("Frame", {
		Name = "Icon" .. tostring(kind),
		BackgroundTransparency = 1,
		Size = props.Size or UDim2.fromScale(1, 1),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or V2(0, 0),
		ZIndex = z,
	})
	new("UIAspectRatioConstraint", { Parent = c })
	local draw = Icons[kind]
	if draw then
		draw(c, z + 1)
	else
		warn("[UI.Kit] нет иконки " .. tostring(kind))
	end
	c.Parent = parent
	return c
end

-- квадратная кнопка-иконка с подписью (панель справа)
function Kit.iconButton(parent, order, kind, caption, top, bottom, edgeColor, onClick, size)
	size = size or 76
	local b = new("TextButton", {
		Name = kind .. "Button",
		LayoutOrder = order or 0,
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
	})
	Kit.corner(16).Parent = b
	Kit.stroke(edgeColor, 2).Parent = b
	new("UIGradient", { Parent = b, Rotation = 90, Color = ColorSequence.new(top, bottom) })
	-- мягкий блик сверху
	local shine = new("Frame", {
		Parent = b,
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 0.9,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(4, 4),
		Size = UDim2.new(1, -8, 0.4, 0),
	})
	Kit.corner(12).Parent = shine
	Kit.icon(kind, b, { Size = UDim2.fromScale(0.72, 0.72), Position = UDim2.fromScale(0.5, 0.48), AnchorPoint = V2(0.5, 0.5), ZIndex = 2 })
	local cap = Kit.label({
		Parent = b,
		AnchorPoint = V2(0.5, 0),
		Position = UDim2.new(0.5, 0, 1, 3),
		Size = UDim2.new(1, 16, 0, math.max(14, size * 0.2)),
		Text = caption or "",
		Font = Enum.Font.GothamBold,
	})
	hoverScale(b, 1.08, 0.93)
	if onClick then
		b.Activated:Connect(onClick)
	end
	b.Parent = parent
	return b, cap
end

------------------------------------------------------------------------
-- МОДАЛЬНЫЕ ОКНА
------------------------------------------------------------------------
local function rootFrame()
	local ui = Kit.UI
	return (ui and ui.Root) or Kit.Root
end

function Kit.modal(name, title, size, iconKind, parent)
	local m = Kit.panel({
		Name = "Modal_" .. tostring(name),
		AnchorPoint = V2(0.5, 0.5),
		Size = size,
		Position = UDim2.fromScale(0.5, 0.5),
		Visible = false,
		BackgroundTransparency = 0.04,
		ZIndex = 5,
	})
	new("UIScale", { Parent = m })
	local x = 18
	if iconKind then
		Kit.icon(iconKind, m, { Size = UDim2.fromOffset(38, 38), Position = UDim2.fromOffset(16, 13), ZIndex = 6 })
		x = 62
	end
	-- заголовок — прямой ребёнок окна (тесты ищут окно по нему)
	Kit.label({
		Parent = m,
		Name = "Title",
		Size = UDim2.new(1, -80 - x, 0, 44),
		Position = UDim2.fromOffset(x, 10),
		Text = title or "",
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Theme.Accent,
	})
	Kit.button({
		Parent = m,
		Name = "Close",
		Size = UDim2.fromOffset(40, 40),
		Position = UDim2.new(1, -52, 0, 12),
		Text = "✕",
		BackgroundColor3 = rgb(120, 30, 50),
	}, function()
		m.Visible = false
	end)
	Kit.Modals[name] = m
	m.Parent = parent or rootFrame()
	return m
end

------------------------------------------------------------------------
-- 3D-ПРЕВЬЮ
------------------------------------------------------------------------
-- во ViewportFrame не рисуются частицы, свет, шлейфы — убираем, чтобы не тратить память
local function strip(model)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("ParticleEmitter") or d:IsA("Light") or d:IsA("Trail") or d:IsA("Beam") or d:IsA("Fire") or d:IsA("Smoke") or d:IsA("Sparkles") then
			d:Destroy()
		end
	end
end
Kit.StripModel = strip

local function viewportFrame(parent, props, ambient, lightColor, lightDir)
	props = props or {}
	return new("ViewportFrame", {
		Parent = parent,
		BackgroundTransparency = 1,
		Size = props.Size or UDim2.fromScale(1, 1),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or V2(0, 0),
		Ambient = ambient,
		LightColor = lightColor,
		LightDirection = lightDir,
		ZIndex = props.ZIndex or 1,
	})
end

local function camera(vf, fov, cf)
	local cam = Instance.new("Camera")
	cam.FieldOfView = fov
	cam.CFrame = cf
	cam.Parent = vf
	vf.CurrentCamera = cam
	return cam
end

-- юнит: камера сбоку-спереди, дальше — чтобы оружие помещалось целиком
function Kit.unitViewport(parent, unitId, level, props)
	props = props or {}
	local vf = viewportFrame(parent, props, rgb(150, 130, 185), rgb(255, 245, 255), V3(-0.6, -1, -0.8))
	if props.Silhouette then
		vf.ImageColor3 = rgb(0, 0, 0)
		vf.ImageTransparency = 0.2
	end
	local UnitModels = models("UnitModels", "Units")
	if not UnitModels or not UnitModels.Build then
		return vf
	end
	local ok, rig = pcall(UnitModels.Build, unitId, level or 1)
	if not ok or type(rig) ~= "table" or not rig.Model then
		if not ok then
			warn("[UI.Kit] превью " .. tostring(unitId) .. ": " .. tostring(rig))
		end
		return vf
	end
	strip(rig.Model)
	rig.Model.Parent = vf
	local s = rig.Scale or 1
	local center = V3(0, -0.1 * s, 0)
	camera(vf, 34, CFrame.lookAt(center + V3(5.6, 2.6, -14.5) * s, center))
	return vf, rig
end
Kit.viewport = Kit.unitViewport

-- враг (бестиарий): камера по высоте модели
function Kit.enemyViewport(parent, enemyId, props)
	local vf = viewportFrame(parent, props, rgb(150, 130, 160), rgb(255, 240, 230), V3(-0.5, -1, -0.8))
	local EnemyModels = models("EnemyModels", "Enemies")
	if not EnemyModels or not EnemyModels.Build then
		return vf
	end
	local ok, rig = pcall(EnemyModels.Build, enemyId)
	if not ok or type(rig) ~= "table" or not rig.Model then
		if not ok then
			warn("[UI.Kit] превью врага " .. tostring(enemyId) .. ": " .. tostring(rig))
		end
		return vf
	end
	strip(rig.Model)
	rig.Model.Parent = vf
	local h = rig.Height or 5
	local c = V3(0, h * 0.5 - (rig.HipHeight or 0), 0)
	camera(vf, 34, CFrame.lookAt(c + V3(h * 0.45, h * 0.25, -h * 1.7), c))
	return vf, rig
end

-- руны медленно вращаются (Kit.StepSpins)
local spins = {}

function Kit.runeViewport(parent, runeId, props)
	local vf = viewportFrame(parent, props, rgb(170, 140, 130), rgb(255, 240, 220), V3(-0.5, -1, -0.7))
	local UnitModels = models("UnitModels", "Units")
	if not UnitModels or not UnitModels.BuildRune then
		return vf
	end
	local ok, r = pcall(UnitModels.BuildRune, runeId)
	if not ok or type(r) ~= "table" or not r.Model then
		if not ok then
			warn("[UI.Kit] руна " .. tostring(runeId) .. ": " .. tostring(r))
		end
		return vf
	end
	strip(r.Model)
	r.Model.Parent = vf
	camera(vf, 30, CFrame.lookAt(V3(2.2, 1.4, -6.5), V3(0, 0, 0)))
	vf:SetAttribute("Spin", true)
	spins[#spins + 1] = { Model = r.Model, VF = vf, Vis = true, Next = 0 }
	return vf, r
end

-- кейс: модель собирает CaseModels (части анимируются напрямую через CFrame)
function Kit.caseViewport(parent, caseId, props)
	local vf = viewportFrame(parent, props, rgb(160, 140, 190), rgb(255, 245, 255), V3(-0.5, -1, -0.7))
	local CaseModels = models("CaseModels", "Cases")
	local ok, r = false, nil
	if CaseModels and CaseModels.Build then
		ok, r = pcall(CaseModels.Build, caseId)
	end
	if not ok or type(r) ~= "table" or not r.Model then
		if CaseModels then
			warn("[UI.Kit] кейс " .. tostring(caseId) .. ": " .. tostring(r))
		end
		r = { Model = Instance.new("Model"), Base = {}, Shards = {}, Cracks = {}, Failed = true }
	end
	r.Base = r.Base or {}
	r.Shards = r.Shards or {}
	r.Cracks = r.Cracks or {}
	r.Model.Parent = vf
	camera(vf, 40, CFrame.lookAt(V3(0, 4.5, -13), V3(0, 2.6, 0)))
	r.Viewport = vf
	return r
end

------------------------------------------------------------------------
-- РЕДКОСТЬ И ТЕГ СОБЫТИЯ
------------------------------------------------------------------------
function Kit.rarityColor(unitId)
	local def = Config.Units and Config.Units[unitId]
	local r = def and Config.Rarities and Config.Rarities[def.Rarity]
	return (r and r.Color) or Theme.Dim
end

-- лёгкие оранжевые искры на карточках юнитов события (двигаются в Kit.StepSparks)
local sparks = {}
local SPARK = rgb(255, 160, 60)

function Kit.eventSparks(parent, z, n)
	for _ = 1, n or 4 do
		local f = new("Frame", {
			Name = "Spark",
			BackgroundColor3 = SPARK,
			BorderSizePixel = 0,
			Size = UDim2.fromOffset(3, 3),
			Rotation = 45,
			ZIndex = z or 1,
			BackgroundTransparency = 0.2,
		})
		local sp = { F = f, X = math.random(), P = math.random() * 3, S = 0.25 + math.random() * 0.25, Vis = true, Next = 0 }
		f.Position = UDim2.fromScale(sp.X, 1)
		f.Parent = parent
		sparks[#sparks + 1] = sp
	end
end

-- значок-тыква, подпись события и искры; рамка карточки остаётся цветом редкости
function Kit.eventTag(parent, unitId, z, textPos, textSize)
	local def = Config.Units and Config.Units[unitId]
	local ev = def and def.Event and Config.Events and Config.Events[def.Event]
	if not ev then
		return nil
	end
	z = z or 1
	local ic = Kit.icon("Pumpkin", parent, { Size = UDim2.fromOffset(22, 22), Position = UDim2.fromOffset(4, 4), ZIndex = z + 2 })
	local tag
	if textPos then
		tag = Kit.label({
			Parent = parent,
			Name = "EventTag",
			Size = textSize or UDim2.new(1, -8, 0, 13),
			Position = textPos,
			Text = ev.Tag,
			TextColor3 = ev.Color,
			Font = Enum.Font.GothamBold,
			ZIndex = z + 1,
		})
	end
	Kit.eventSparks(parent, z + 1, 4)
	return ic, tag
end

------------------------------------------------------------------------
-- ПОКАДРОВОЕ ОБНОВЛЕНИЕ
------------------------------------------------------------------------
-- виден ли элемент на экране (все GuiObject-предки Visible, есть ScreenGui/LayerCollector)
local function onScreen(obj)
	local o = obj
	while o do
		if o:IsA("LayerCollector") then
			return o.Enabled ~= false
		end
		if o:IsA("GuiObject") and not o.Visible then
			return false
		end
		o = o.Parent
	end
	return false
end

-- проверка видимости раз в 0.25 с, чтобы не обходить предков каждый кадр
local function visibleCached(it, t)
	if t >= it.Next then
		it.Next = t + 0.25
		it.Vis = onScreen(it.F or it.VF)
	end
	return it.Vis
end

function Kit.StepSpins(t)
	t = t or os.clock()
	local cf
	for i = #spins, 1, -1 do
		local it = spins[i]
		if not it.VF.Parent or not it.Model.Parent then
			spins[i] = spins[#spins]
			spins[#spins] = nil
		elseif visibleCached(it, t) then
			cf = cf or (CFrame.new(0, math.sin(t * 1.6) * 0.08, 0) * CFrame.Angles(0, t * 0.9, 0))
			it.Model:PivotTo(cf)
		end
	end
end

function Kit.StepSparks(t)
	t = t or os.clock()
	for i = #sparks, 1, -1 do
		local sp = sparks[i]
		local f = sp.F
		if not f.Parent then
			sparks[i] = sparks[#sparks]
			sparks[#sparks] = nil
		elseif visibleCached(sp, t) then
			-- поднимаются снизу вверх, покачиваясь, и гаснут
			local a = (t * sp.S + sp.P) % 1
			f.Position = UDim2.fromScale(sp.X + math.sin(t * 2 + sp.P) * 0.04, 1 - a)
			f.BackgroundTransparency = 0.2 + a * 0.8
		end
	end
	Kit.StepSpins(t)
end

function Kit.Step(t)
	Kit.StepSparks(t)
end

-- локальный игрок (для модулей UI)
Kit.Player = Players.LocalPlayer

return Kit
