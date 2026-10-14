--!nocheck
-- VOID TD :: EnemyModels
-- Процедурные модели врагов (без внешних ассетов). Модели — только визуал: урон и попадания
-- считаются на сервере по дистанции пути, поэтому размер брони не влияет на хитбокс.
--
-- EnemyModels.Build(enemyId) -> rig:
--   Model, Root, Motors, Base, Scale, Idle
--   Style      "Biped" | "Heavy" | "Crawl" | "Gallop" | "Float"
--   HipHeight, Height
--   Gait       { Speed, Stride, Bob, Sway, Lean, Shake }  параметры походки
--   Sec        { [motorName] = { Amp, Speed } }           вторичное движение (по префиксу имени мотора)
--              префиксы: Sway* (маятник), Cape* (плащ), Orbit* (вращение Y), Spin* (вращение Z),
--                        Bob* (парение вверх-вниз), Twitch* (резкие повороты головы)
--   Phases     { { At = 0.65, Reveal = {parts}, Break = {parts}, Emit = {emitters}, Lights = {{light, brightness}}, Aggro = 1.3 }, ... }
--              скрытые детали Reveal имеют Transparency = 1 и атрибут "PT" (целевая прозрачность)
--   DeathStyle "Dissipate" | "Scatter" | "Collapse" | "Topple" | "Implode"
--   SpawnStyle "Rise" | "Fade" | "Titan"

local UnitModels = require(script.Parent.UnitModels)
local Config = require(script.Parent.Config)

local Rig = UnitModels.Rig
local P = UnitModels.Palette

local V = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles
local rad = math.rad
local PI = math.pi

local M = {
	Plastic = Enum.Material.SmoothPlastic,
	Metal = Enum.Material.Metal,
	Neon = Enum.Material.Neon,
	Fabric = Enum.Material.Fabric,
	Slate = Enum.Material.Slate,
	Glass = Enum.Material.Glass,
	Basalt = Enum.Material.Basalt,
	Rock = Enum.Material.Rock,
}

local C = {
	Ghost = Color3.fromRGB(196, 182, 236),
	GhostDeep = Color3.fromRGB(122, 96, 178),
	Obsidian = Color3.fromRGB(13, 10, 19),
	Shell = Color3.fromRGB(30, 22, 42),
	Bone = Color3.fromRGB(186, 176, 162),
	Crystal = Color3.fromRGB(165, 85, 255),
	CrystalPale = Color3.fromRGB(215, 170, 255),
	Flesh = Color3.fromRGB(78, 22, 40),
	FleshDark = Color3.fromRGB(52, 14, 28),
	Iron = Color3.fromRGB(58, 56, 68),
	IronDark = Color3.fromRGB(36, 34, 44),
	Rune = Color3.fromRGB(200, 110, 255),
	Maw = Color3.fromRGB(255, 70, 200),
}

-- встроенная текстура дыма клиента Roblox (папка content/textures/particles, не ассет из каталога)
local SMOKE_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"

local EnemyModels = {}

local function lite()
	return UnitModels.Lite
end

------------------------------------------------------------------------
-- БАЗОВЫЕ ХЕЛПЕРЫ
------------------------------------------------------------------------

-- Существо без человеческого скелета: Root -> Torso (мотор "Root")
local function newCreature(name, bodySize, bodyColor, bodyMat)
	local self = setmetatable({}, Rig)
	local model = Instance.new("Model")
	model.Name = name
	self.Model = model
	self.Motors = {}
	self.Base = {}
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = V(1, 1, 1)
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanTouch = false
	root.CanQuery = false
	root.CFrame = CF()
	root.Parent = model
	self.Root = root

	local body = Instance.new("Part")
	body.Name = "Torso"
	body.Size = bodySize
	body.Color = bodyColor
	body.Material = bodyMat or M.Plastic
	body.CanCollide = false
	body.CanTouch = false
	body.Massless = true
	body.TopSurface = Enum.SurfaceType.Smooth
	body.BottomSurface = Enum.SurfaceType.Smooth
	body.CFrame = CF()
	body.Parent = model
	self.Torso = body
	self.Pending = {}
	self.PendingTrails = {}
	local m = Instance.new("Motor6D")
	m.Name = "Root"
	m.Part0 = root
	m.Part1 = body
	m.C0 = CF()
	m.C1 = CF()
	m.Parent = root
	self.Motors.Root = m
	return self
end

-- Общие поля, которые читает Renderer
local function setup(r, o)
	r.Style = o.Style
	r.Gait = o.Gait or {}
	r.Sec = r.Sec or {}
	r.Phases = r.Phases or {}
	r.DeathStyle = o.Death or "Topple"
	r.SpawnStyle = o.Spawn or "Rise"
end

-- Невидимый узел на моторе: к нему привариваются детали, которые двигаются вместе
local function hub(r, name, limb, pivot, sec)
	local h = r:Joint(name, limb, V(0.2, 0.2, 0.2), pivot, CF(), P.Black)
	h.Transparency = 1
	if sec then
		r.Sec = r.Sec or {}
		r.Sec[name] = sec
	end
	return h
end

-- Трещина из светящихся сегментов по точкам
local function crack(r, limb, pts, thick, color)
	local parts = {}
	for i = 1, #pts - 1 do
		parts[#parts + 1] = r:Seg(limb, pts[i], pts[i + 1], thick or 0.1, color or P.Neon, M.Neon)
	end
	return parts
end

-- Кольцо из сегментов в плоскости XY узла cf. skip(i) -> true пропускает сегмент (разлом)
local function ring(r, limb, cf, radius, count, thick, depth, color, mat, skip)
	local parts = {}
	local segLen = 2 * PI * radius / count * 1.08
	for i = 0, count - 1 do
		if not (skip and skip(i)) then
			local a = i / count * PI * 2
			local p = r:Box(limb, V(segLen, thick, depth), cf * CF(math.cos(a) * radius, math.sin(a) * radius, 0) * ANG(0, 0, a + PI / 2), color, mat or M.Metal)
			parts[#parts + 1] = p
		end
	end
	return parts
end

-- Скрыть детали до нужной фазы
local function hide(parts, target)
	for _, p in ipairs(parts) do
		p:SetAttribute("PT", target or p.Transparency)
		p.Transparency = 1
	end
	return parts
end

local function join(...)
	local out = {}
	for _, list in ipairs({ ... }) do
		for _, p in ipairs(list) do
			out[#out + 1] = p
		end
	end
	return out
end

-- Эмиттер частиц (nil в облегчённом режиме)
local function emitter(part, color, o)
	if lite() then
		return nil
	end
	o = o or {}
	local e = Instance.new("ParticleEmitter")
	e.Name = o.Name or "EnemyFX"
	if o.Smoke then
		e.Texture = SMOKE_TEXTURE
	end
	e.Color = ColorSequence.new(color, o.Color2 or color)
	e.LightEmission = o.Light or (o.Smoke and 0.3 or 1)
	e.LightInfluence = o.Smoke and 0.4 or 0
	e.Rate = o.Rate or 8
	e.Lifetime = NumberRange.new(o.LifeMin or 0.6, o.LifeMax or 1.2)
	e.Speed = NumberRange.new(o.SpeedMin or 0.3, o.SpeedMax or 1.2)
	e.SpreadAngle = Vector2.new(o.Spread or 180, o.Spread or 180)
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-40, 40)
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, o.Size or 0.4),
		NumberSequenceKeypoint.new(1, o.SizeEnd or 0),
	})
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, o.T0 or 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	if o.Accel then
		e.Acceleration = o.Accel
	end
	if o.Dir then
		e.EmissionDirection = o.Dir
	end
	if o.Off then
		e.Enabled = false
	end
	e.Parent = part
	return e
end

-- Невидимая точка-излучатель, приваренная к limb
local function emitPoint(r, limb, offset, size)
	return r:Box(limb, size or V(0.6, 0.6, 0.6), offset, P.Black, M.Plastic, { Transparency = 1, Name = "Emit" })
end

-- Тёмный шлейф (Trail). Создаётся в Finish, включается в afterFinish.
local function darkTrail(r, limb, a, b, color)
	if lite() then
		return
	end
	table.insert(r.PendingTrails, { limb, a, b, color })
end

local function afterFinish(r)
	for _, d in ipairs(r.Model:GetDescendants()) do
		if d:IsA("Trail") then
			d.Name = "EnemyTrail"
			d.Enabled = true
			d.Lifetime = 0.4
			d.LightEmission = 0.2
			d.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
		end
	end
end

local function finishCreature(r, scale, hip, height)
	r:Finish(scale)
	r.HipHeight = hip * scale
	r.Height = height * scale
	r.Model:SetAttribute("HipHeight", r.HipHeight)
	afterFinish(r)
	return r
end

local function finishBiped(r, scale, idle, height)
	r:Finish(scale, idle)
	r.Height = (height or (3 + 1 + r.HeadSize.Y + 0.6)) * scale
	afterFinish(r)
	return r
end

-- Свечение: возвращает {light, brightness} для таблицы фаз
local function glow(r, part, color, range, brightness)
	local l = r:Glow(part, color, range, brightness)
	return l
end

------------------------------------------------------------------------
-- 1. LOST SOUL — полупрозрачный дух, рваные края, фиолетовый дым
------------------------------------------------------------------------
local function LostSoul(scale)
	local r = newCreature("LostSoul", V(1.7, 1.8, 1.5), C.Ghost)
	setup(r, { Style = "Float", Gait = { Bob = 0.35, Speed = 1 }, Death = "Dissipate", Spawn = "Fade" })
	local B = r.Torso
	B.Transparency = 0.32
	table.insert(r.Pending, B)
	r.Head = B
	r.HeadSize = B.Size
	-- светящееся ядро внутри тела
	r:Sphere(B, V(0.75, 0.75, 0.65), CF(0, 0.05, 0.1), P.Neon, M.Neon, { Transparency = 0.45 })
	-- капюшон-оболочка
	r:Sphere(B, V(1.95, 1.25, 1.7), CF(0, 0.5, 0.1), C.Ghost, M.Plastic, { Transparency = 0.55 })
	-- глазницы и глаза
	for _, s in ipairs({ -1, 1 }) do
		r:Sphere(B, V(0.52, 0.62, 0.1), CF(0.33 * s, 0.18, -0.68) * ANG(0, 0, rad(-12 * s)), P.Black, M.Plastic, { Transparency = 0.15 })
		r:Sphere(B, V(0.3, 0.42, 0.12), CF(0.33 * s, 0.17, -0.72) * ANG(0, 0, rad(-12 * s)), P.Neon, M.Neon)
	end
	-- стонущий рот
	r:Sphere(B, V(0.34, 0.5, 0.1), CF(0, -0.36, -0.68), P.Black, M.Plastic, { Transparency = 0.1 })
	-- рваная юбка
	if not lite() then
		for i = 0, 7 do
			local a = i / 8 * PI * 2
			local h = 0.6 + ((i * 37) % 5) * 0.12
			r:Wedge(B, V(0.48, h, 0.12), CF(math.cos(a) * 0.7, -0.75 - h / 2, math.sin(a) * 0.6) * ANG(0, -a + PI / 2, 0) * ANG(0, 0, PI), C.Ghost, M.Plastic, { Transparency = 0.45 })
		end
	end
	-- хвосты-лоскуты на собственных моторах
	for i, x in ipairs({ -0.38, 0.05, 0.42 }) do
		local name = "SwayTail" .. i
		local t = r:Joint(name, B, V(0.5, 0.9, 0.14), CF(x, -0.85, 0.1 + i * 0.08), CF(0, -0.45, 0), C.Ghost)
		t.Transparency = 0.45
		r:Wedge(t, V(0.42, 0.85, 0.12), CF(0, -0.87, 0) * ANG(0, 0, PI), C.GhostDeep, M.Plastic, { Transparency = 0.55 })
		r.Sec[name] = { Amp = 0.35, Speed = 3 + i * 0.4 }
	end
	-- тонкие руки с когтями
	for _, s in ipairs({ 1, -1 }) do
		local arm = r:Joint(s == 1 and "ArmR" or "ArmL", B, V(0.3, 1.0, 0.3), CF(0.8 * s, 0.05, 0), CF(0.22 * s, -0.4, 0) * ANG(0, 0, rad(28 * s)), C.Ghost)
		arm.Transparency = 0.4
		for k = -1, 1 do
			r:Wedge(arm, V(0.08, 0.32, 0.12), CF(k * 0.09, -0.62, -0.05) * ANG(0, 0, PI), C.GhostDeep, M.Plastic, { Transparency = 0.3 })
		end
	end
	local e = emitPoint(r, B, CF(0, -1.3, 0.2), V(0.9, 0.3, 0.9))
	emitter(e, Color3.fromRGB(120, 60, 200), { Smoke = true, Rate = 7, Size = 0.9, SizeEnd = 1.6, LifeMin = 0.8, LifeMax = 1.4, SpeedMin = 0.2, SpeedMax = 0.6, Accel = V(0, 0.6, 0), T0 = 0.55 })
	glow(r, B, P.Neon, 7, 0.9)
	return finishCreature(r, scale, 2.4, 3.2)
end

------------------------------------------------------------------------
-- 2. VOID CRAWLER — низкий, 4 лапы-клешни, неровная спина, трещины, дёрганая голова
------------------------------------------------------------------------
local function VoidCrawler(scale)
	local r = newCreature("VoidCrawler", V(2.0, 0.9, 2.6), C.Shell, M.Slate)
	setup(r, { Style = "Crawl", Gait = { Speed = 1.7, Stride = 0.4, Bob = 0.08, Sway = 0.06 }, Death = "Collapse" })
	local B = r.Torso
	-- неровный панцирь
	r:Sphere(B, V(2.2, 1.05, 2.5), CF(0, 0.45, 0.2) * ANG(rad(-5), 0, rad(3)), C.Shell, M.Slate)
	r:Sphere(B, V(1.25, 0.85, 1.15), CF(0.4, 0.9, 0.55) * ANG(0, rad(20), rad(8)), P.Coal, M.Slate)
	r:Sphere(B, V(0.95, 0.65, 0.95), CF(-0.45, 0.82, -0.3), P.Coal, M.Slate)
	r:Sphere(B, V(1.15, 0.6, 0.8), CF(0.05, 0.7, 1.35), C.Shell, M.Slate)
	-- костяные шипы
	local spikes = { { -0.5, 1.05, -0.2, 0.7 }, { 0.15, 1.2, 0.25, 0.5 }, { 0.55, 1.25, 0.6, 0.9 }, { -0.25, 1.0, 0.9, 0.55 }, { 0.3, 0.95, 1.4, 0.45 } }
	for _, s in ipairs(spikes) do
		local base = V(s[1], s[2] - 0.15, s[3])
		r:Rod(B, base, base + V(s[1] * 0.25, s[4], 0.35), 0.18, C.Bone, M.Plastic)
	end
	-- фиолетовые трещины
	crack(r, B, { V(-0.75, 0.88, -0.75), V(-0.2, 0.98, -0.1), V(0.25, 0.98, 0.35), V(0.75, 0.82, 0.95) }, 0.09)
	crack(r, B, { V(-0.2, 0.98, -0.1), V(-0.7, 0.85, 0.6) }, 0.07)
	-- брюшко-хвост
	local tail = r:Joint("SwayTail", B, V(0.9, 0.6, 1.0), CF(0, 0.1, 1.3), CF(0, 0, 0.5), C.Shell, M.Slate)
	r:Sphere(tail, V(0.95, 0.65, 1.05), CF(), C.Shell, M.Slate)
	r:Rod(tail, V(0, 0.1, 0.4), V(0, 0.55, 1.0), 0.16, C.Bone)
	r:Neon(tail, V(0.08, 0.05, 0.7), CF(0, 0.33, 0), P.Neon)
	r.Sec.SwayTail = { Amp = 0.18, Speed = 5 }
	-- голова на моторе "Twitch": резкие короткие повороты
	local head = r:Joint("TwitchHead", B, V(1.05, 0.7, 0.95), CF(0, 0.15, -1.3), CF(0, 0, -0.42), P.Coal, M.Slate)
	r.Head = head
	r.HeadSize = head.Size
	r:Sphere(head, V(1.15, 0.8, 1.0), CF(0, 0.05, 0), P.Coal, M.Slate)
	for _, e in ipairs({ { -0.28, 0.12, 0.2 }, { 0.3, 0.14, 0.2 }, { 0, 0.3, 0.15 }, { -0.12, -0.02, 0.12 }, { 0.15, -0.03, 0.12 } }) do
		r:Ball(head, e[3], CF(e[1], e[2], -0.48), P.Neon, M.Neon)
	end
	-- жвалы
	for _, s in ipairs({ -1, 1 }) do
		r:Chain(head, { V(0.3 * s, -0.2, -0.35), V(0.42 * s, -0.25, -0.75), V(0.22 * s, -0.25, -1.05) }, 0.14, C.Bone, M.Plastic, 0.7, true)
		r:Rod(head, V(0.2 * s, 0.3, -0.3), V(0.5 * s, 0.85, -0.7), 0.06, P.Black)
	end
	r.Sec.TwitchHead = { Amp = 0.45, Speed = 1 }
	-- лапы: узел на моторе + бедро + голень + коготь
	local legs = { { "FR", 1, -0.75, 1.25 }, { "FL", -1, -0.75, 1.25 }, { "BR", 1, 0.85, 1 }, { "BL", -1, 0.85, 1 } }
	for _, l in ipairs(legs) do
		local s, big = l[2], l[4]
		local h = hub(r, l[1], B, CF(0.95 * s, 0, l[3]))
		local knee = V(0.95 * s, 0.6, l[3] < 0 and -0.2 or 0.15)
		local foot = V(1.45 * s, -1.25, l[3] < 0 and -0.45 or 0.3)
		r:Rod(h, V(0, 0, 0), knee, 0.34 * big, P.Coal, M.Slate)
		r:Ball(h, 0.36 * big, CF(knee), C.Shell, M.Slate)
		r:Rod(h, knee, foot, 0.24 * big, P.Black, M.Slate)
		r:Neon(h, V(0.06, 0.06, 0.5), CFrame.lookAt((knee + foot) / 2, foot) * CF(0, 0.12, 0), P.Neon)
		-- коготь
		r:Chain(h, { foot, foot + V(0.05 * s, 0.1, -0.35 * big), foot + V(-0.05 * s, -0.05, -0.6 * big) }, 0.12 * big, C.Bone, M.Plastic, 0.6, true)
	end
	return finishCreature(r, scale, 1.3, 2.4)
end

------------------------------------------------------------------------
-- 3. SHADOW BEAST — массивные передние лапы, шипы на спине, тёмный шлейф
------------------------------------------------------------------------
local function ShadowBeast(scale)
	local r = newCreature("ShadowBeast", V(1.6, 1.4, 2.8), C.Obsidian)
	setup(r, { Style = "Gallop", Gait = { Speed = 1, Stride = 0.6, Bob = 0.18 }, Death = "Collapse" })
	local B = r.Torso
	-- мощная грудь и поджарый зад
	r:Sphere(B, V(2.05, 1.85, 1.7), CF(0, 0.18, -0.8), C.Obsidian)
	r:Sphere(B, V(1.5, 1.25, 1.45), CF(0, 0.05, 0.95), C.Obsidian)
	r:Sphere(B, V(1.6, 0.5, 2.6), CF(0, -0.55, 0), P.Coal)
	-- шипы вдоль хребта
	for i = 0, 5 do
		local z = -1.2 + i * 0.5
		local h = 0.55 + ((i * 3) % 4) * 0.15
		r:Rod(B, V(0, 0.7 + (i < 3 and 0.2 or 0), z), V(0, 0.7 + h + (i < 3 and 0.2 or 0), z + 0.45), 0.2, P.DeepViolet, M.Slate)
	end
	r:Neon(B, V(0.08, 0.06, 2.4), CF(0, 0.95, -0.1), P.Neon, { Transparency = 0.2 })
	-- голова
	local head = r:Joint("Neck", B, V(1.15, 1.0, 1.25), CF(0, 0.5, -1.55), CF(0, 0.15, -0.55), C.Obsidian)
	r.Head = head
	r.HeadSize = head.Size
	r:Box(head, V(0.75, 0.5, 0.95), CF(0, -0.15, -0.95), P.Coal)
	r:Box(head, V(0.7, 0.16, 0.85), CF(0, -0.48, -0.9), P.Maroon)
	for i = -1, 1, 2 do
		r:Wedge(head, V(0.08, 0.22, 0.12), CF(i * 0.25, -0.33, -1.3) * ANG(0, 0, PI), P.White)
		r:Wedge(head, V(0.08, 0.18, 0.12), CF(i * 0.18, -0.55, -1.25), P.White)
	end
	r:Sphere(head, V(0.4, 0.3, 0.3), CF(0, -0.05, -1.45), P.Black)
	for _, s in ipairs({ -1, 1 }) do
		r:Wedge(head, V(0.28, 0.65, 0.42), CF(0.4 * s, 0.75, 0.2) * ANG(rad(-15), 0, rad(-10 * s)), C.Obsidian)
	end
	r:Eyes(P.Neon, { Y = 0.15, Spacing = 0.32, Size = V(0.3, 0.12, 0.06), Tilt = -18 })
	glow(r, head, P.Neon, 6, 1)
	-- массивные передние лапы
	for _, l in ipairs({ { "FR", 1 }, { "FL", -1 } }) do
		local s = l[2]
		r:Sphere(B, V(0.95, 1.35, 1.35), CF(0.8 * s, 0.05, -0.95), C.Obsidian)
		local leg = r:Joint(l[1], B, V(0.75, 1.7, 0.8), CF(0.78 * s, -0.25, -1.0), CF(0, -0.8, 0), C.Obsidian)
		r:Sphere(leg, V(0.95, 1.0, 1.0), CF(0, 0.2, 0), C.Obsidian)
		r:Box(leg, V(0.9, 0.32, 1.1), CF(0, -0.82, -0.15), P.Coal)
		for k = -1, 1 do
			r:Wedge(leg, V(0.12, 0.2, 0.35), CF(k * 0.28, -0.88, -0.78), C.Bone)
		end
	end
	-- задние лапы
	for _, l in ipairs({ { "BR", 1 }, { "BL", -1 } }) do
		local s = l[2]
		local leg = r:Joint(l[1], B, V(0.5, 1.5, 0.65), CF(0.55 * s, -0.4, 1.1), CF(0, -0.72, 0.1) * ANG(rad(-10), 0, 0), C.Obsidian)
		r:Box(leg, V(0.55, 0.25, 0.75), CF(0, -0.68, -0.12), P.Coal)
	end
	-- хвост
	local tail = r:Joint("SwayTail", B, V(0.3, 0.3, 0.3), CF(0, 0.45, 1.55), CF(), C.Obsidian)
	tail.Transparency = 1
	r:Chain(tail, { V(0, 0, 0), V(0, 0.4, 0.6), V(0.15, 0.85, 1.05), V(0.1, 1.1, 1.5) }, 0.32, C.Obsidian, M.Plastic, 0.75, true)
	r.Sec.SwayTail = { Amp = 0.3, Speed = 6 }
	-- тёмный шлейф и дымка
	darkTrail(r, B, V(0, 0.75, 1.4), V(0, -0.45, 1.4), P.DeepViolet)
	local e = emitPoint(r, B, CF(0, 0, 0.6), V(1.2, 1, 1.6))
	emitter(e, Color3.fromRGB(40, 16, 66), { Smoke = true, Rate = 6, Size = 0.7, SizeEnd = 1.3, LifeMin = 0.4, LifeMax = 0.8, T0 = 0.5 })
	return finishCreature(r, scale, 2.0, 3.2)
end

------------------------------------------------------------------------
-- 4. ARMORED HORROR — нагрудник, тяжёлые наплечники, шипы, светящиеся швы
------------------------------------------------------------------------
local function ArmoredHorror(scale)
	local r = Rig.new({ Name = "ArmoredHorror", Torso = C.Iron, Arm = C.IronDark, Leg = C.IronDark, Head = P.Coal, TorsoMat = M.Metal, HeadSize = V(1.2, 1.2, 1.2) })
	setup(r, { Style = "Heavy", Gait = { Speed = 0.9, Stride = 0.45, Bob = 0.16, Sway = 0.07 }, Death = "Topple" })
	local T, H, RA, LA, RL, LL = r.Torso, r.Head, r.RArm, r.LArm, r.RLeg, r.LLeg
	-- огромный нагрудник: верхняя плита, «киль», нижние пластины
	r:Box(T, V(2.75, 1.25, 1.75), CF(0, 0.45, -0.05), P.Steel, M.Metal)
	r:Wedge(T, V(2.6, 0.55, 0.45), CF(0, 0.85, -1.08) * ANG(0, PI, 0), P.Steel, M.Metal)
	r:Box(T, V(2.45, 0.5, 1.55), CF(0, -0.45, 0), C.Iron, M.Metal)
	r:Box(T, V(2.3, 0.35, 1.45), CF(0, -0.9, 0), C.IronDark, M.Metal)
	-- светящиеся швы между плитами
	r:Neon(T, V(2.55, 0.08, 1.6), CF(0, -0.17, 0), P.NeonPink)
	r:Neon(T, V(2.35, 0.06, 1.5), CF(0, -0.7, 0), P.NeonPink)
	crack(r, T, { V(-0.8, 0.95, -0.94), V(-0.35, 0.55, -0.94), V(-0.5, 0.15, -0.94) }, 0.07, P.NeonPink)
	crack(r, T, { V(0.55, 0.9, -0.94), V(0.75, 0.4, -0.94) }, 0.06, P.NeonPink)
	-- горжет
	r:Cyl(T, 0.4, 1.5, CF(0, 1.05, 0), C.IronDark, M.Metal, "Y")
	-- шлем
	r:Box(H, V(1.42, 1.35, 1.45), CF(0, 0.05, 0.02), P.Gray, M.Metal)
	r:Box(H, V(1.5, 0.3, 1.5), CF(0, -0.1, 0), C.Iron, M.Metal)
	r:Box(H, V(1.0, 0.1, 0.06), CF(0, 0.12, -0.76), P.NeonPink, M.Neon)
	for i = -1, 1 do
		r:Rod(H, V(i * 0.45, 0.65, 0.1), V(i * 0.6, 1.25 - math.abs(i) * 0.2, 0.45), 0.16, P.Steel, M.Metal)
	end
	-- тяжёлые наплечники с шипами
	for _, a in ipairs({ { RA, 1 }, { LA, -1 } }) do
		local A, s = a[1], a[2]
		r:Pauldron(A, s, 1.4, P.Steel, C.IronDark, 0.08)
		r:Pauldron(A, s, 1.05, C.Iron, nil, 0.45)
		for k = 0, 1 do
			r:Rod(A, V(0.3 * s, 1.1, -0.25 + k * 0.5), V(0.75 * s, 1.85, -0.35 + k * 0.6), 0.16, P.Gray, M.Metal)
		end
		-- толстые руки и латные перчатки
		r:Box(A, V(1.3, 1.25, 1.3), CF(0, -0.15, 0), C.Iron, M.Metal)
		r:Box(A, V(1.38, 0.75, 1.38), CF(0, -0.8, 0), P.Steel, M.Metal)
		r:Neon(A, V(1.32, 0.06, 1.32), CF(0, -0.5, 0), P.NeonPink)
		for k = -1, 1 do
			r:Rod(A, V(k * 0.35, -1.0, -0.62), V(k * 0.4, -1.1, -0.95), 0.1, P.Gray, M.Metal)
		end
	end
	-- поножи и наколенники
	for _, Lg in ipairs({ RL, LL }) do
		r:Box(Lg, V(1.2, 1.15, 1.25), CF(0, -0.45, -0.02), C.Iron, M.Metal)
		r:Sphere(Lg, V(0.8, 0.6, 0.4), CF(0, 0.15, -0.6), P.Steel, M.Metal)
		r:Box(Lg, V(1.25, 0.35, 1.45), CF(0, -0.85, -0.1), C.IronDark, M.Metal)
	end
	-- шипы на спине
	for i = -1, 1 do
		r:Rod(T, V(i * 0.6, 0.6, 0.85), V(i * 0.75, 1.1 - math.abs(i) * 0.2, 1.6), 0.18, P.Gray, M.Metal)
	end
	glow(r, T, P.NeonPink, 6, 0.8)
	return finishBiped(r, scale, { Root = { 6, 0, 0 } })
end

------------------------------------------------------------------------
-- 5. RIFT PHANTOM — разделённые парящие части тела, кольца энергии, шлейф частиц
------------------------------------------------------------------------
local function RiftPhantom(scale)
	local r = newCreature("RiftPhantom", V(1.4, 1.2, 0.9), P.DeepViolet)
	setup(r, { Style = "Float", Gait = { Bob = 0.3 }, Death = "Scatter", Spawn = "Fade" })
	local B = r.Torso
	B.Transparency = 0.3
	-- ядро груди
	r:Box(B, V(0.6, 0.6, 0.6), CF(0, 0.05, -0.2) * ANG(rad(45), rad(45), 0), P.Neon, M.Neon)
	r:Sphere(B, V(1.5, 1.3, 1.0), CF(0, 0, 0.1), P.DeepViolet, M.Plastic, { Transparency = 0.45 })
	glow(r, B, P.Neon, 9, 1.1)
	-- парящие плечи
	for _, s in ipairs({ 1, -1 }) do
		local name = s == 1 and "BobShoulderR" or "BobShoulderL"
		local sh = hub(r, name, B, CF(1.05 * s, 0.7, 0), { Amp = 0.12, Speed = 2.6 })
		r:Sphere(sh, V(0.9, 0.55, 0.9), CF(), P.DeepViolet, M.Plastic, { Transparency = 0.25 })
		r:Neon(sh, V(0.7, 0.06, 0.7), CF(0, -0.2, 0), P.NeonSoft, { Transparency = 0.3 })
	end
	-- парящая светящаяся голова в капюшоне
	local head = hub(r, "BobHead", B, CF(0, 1.55, 0), { Amp = 0.15, Speed = 2 })
	r.Head = head
	r:Sphere(head, V(0.95, 1.05, 0.95), CF(), P.NeonSoft, M.Neon, { Transparency = 0.1 })
	r:Box(head, V(0.62, 0.12, 0.08), CF(0, 0.05, -0.47), P.Black)
	r:Box(head, V(0.25, 0.32, 0.08), CF(0, -0.25, -0.46), P.Black)
	r:Sphere(head, V(1.4, 1.35, 1.35), CF(0, 0.12, 0.12), P.DeepViolet, M.Fabric, { Transparency = 0.35 })
	r:Wedge(head, V(0.6, 0.9, 0.8), CF(0, 0.65, 0.55) * ANG(rad(-35), 0, 0), P.DeepViolet, M.Fabric, { Transparency = 0.35 })
	glow(r, head, P.NeonSoft, 7, 1)
	-- отделённые руки-когти
	for _, s in ipairs({ 1, -1 }) do
		local arm = r:Joint(s == 1 and "ArmR" or "ArmL", B, V(0.45, 1.5, 0.45), CF(1.25 * s, 0.25, 0), CF(0.1 * s, -0.95, 0), P.DeepViolet)
		arm.Transparency = 0.3
		r:Neon(arm, V(0.08, 1.2, 0.08), CF(0, 0, -0.24), P.Neon, { Transparency = 0.3 })
		for k = -1, 1 do
			r:Wedge(arm, V(0.1, 0.55, 0.18), CF(k * 0.14, -1.05, -0.08) * ANG(0, 0, PI), P.NeonSoft, M.Neon)
		end
	end
	-- нижняя часть: парящие осколки-лоскуты
	for i = 1, 3 do
		local name = "BobShard" .. i
		local sd = hub(r, name, B, CF(0.08 * ((i % 2) * 2 - 1), -0.75 - i * 0.62, 0.08 * i), { Amp = 0.1 + i * 0.04, Speed = 2.4 + i * 0.3 })
		local w = 1.25 - i * 0.28
		r:Box(sd, V(w, 0.42, w * 0.7), CF() * ANG(0, rad(i * 25), 0), P.DeepViolet, M.Plastic, { Transparency = 0.25 + i * 0.12 })
		r:Neon(sd, V(w * 0.6, 0.05, w * 0.45), CF(0, 0.22, 0) * ANG(0, rad(i * 25), 0), P.Neon, { Transparency = 0.35 })
		if i == 3 then
			emitter(sd, P.Neon, { Rate = 14, Size = 0.35, LifeMin = 0.6, LifeMax = 1.1, SpeedMin = 0.1, SpeedMax = 0.5 })
		end
	end
	-- энергетические кольца
	local ring1 = hub(r, "OrbitRing1", B, CF(0, 0, 0), { Speed = 1.6 })
	ring(r, ring1, ANG(rad(90), 0, 0), 1.55, 14, 0.08, 0.08, P.Neon, M.Neon, function(i) return i % 4 == 3 end)
	local ring2 = hub(r, "OrbitRing2", B, CF(0, 0.2, 0) * ANG(rad(65), 0, rad(20)), { Speed = -2.2 })
	ring(r, ring2, ANG(rad(90), 0, 0), 1.9, 16, 0.06, 0.06, P.NeonSoft, M.Neon, function(i) return i % 5 == 4 end)
	return finishCreature(r, scale, 3.3, 4.6)
end

------------------------------------------------------------------------
-- 6. ABYSS BRUTE — гигантские руки, странная голова, кристаллы на спине, тряска шагов
------------------------------------------------------------------------
local function AbyssBrute(scale)
	local r = Rig.new({ Name = "AbyssBrute", Torso = C.Flesh, Arm = C.Flesh, Leg = P.Coal, Head = C.Flesh, HeadSize = V(1.2, 1.0, 1.2) })
	setup(r, { Style = "Heavy", Gait = { Speed = 0.75, Stride = 0.35, Bob = 0.24, Sway = 0.12, Shake = 0.12 }, Death = "Topple" })
	local T, H, RA, LA, RL, LL = r.Torso, r.Head, r.RArm, r.LArm, r.RLeg, r.LLeg
	-- горбатый торс
	r:Sphere(T, V(2.95, 2.05, 1.95), CF(0, 0.45, 0.12), C.Flesh)
	r:Sphere(T, V(2.25, 1.4, 1.55), CF(0, -0.45, -0.15), C.FleshDark)
	r:Box(T, V(2.3, 0.4, 1.45), CF(0, -0.85, 0), P.Black, M.Metal)
	r:Neon(T, V(0.5, 0.5, 0.08), CF(0, 0.35, -0.95) * ANG(0, 0, rad(45)), P.NeonPink)
	crack(r, T, { V(-0.7, 0.9, -0.85), V(-0.25, 0.4, -0.95), V(-0.55, -0.2, -0.85) }, 0.07, P.NeonPink)
	-- кристаллы на спине
	local crystals = { { -0.65, 0.9, 0.9, -0.4, 1.1, 0.42 }, { 0, 1.15, 0.85, 0.05, 1.5, 0.5 }, { 0.6, 0.95, 0.95, 0.35, 1.2, 0.4 }, { -0.3, 0.4, 1.05, -0.2, 0.8, 0.3 }, { 0.35, 0.45, 1.05, 0.25, 0.75, 0.28 } }
	for _, c in ipairs(crystals) do
		local base = V(c[1], c[2], c[3])
		local tip = base + V(c[4] * 0.5, c[5], 0.55)
		r:Ball(T, c[6] * 1.3, CF(base), C.Shell, M.Slate)
		r:Seg(T, base, tip, c[6], C.Crystal, M.Neon)
	end
	glow(r, T, C.Crystal, 9, 1.1)
	-- странная голова: низкая, широкая, три глаза, выпирающая челюсть с бивнями
	r:Sphere(H, V(1.55, 1.05, 1.4), CF(0, 0.05, 0), C.Flesh)
	r:Box(H, V(1.45, 0.45, 1.05), CF(0, -0.45, -0.25), C.FleshDark)
	for _, s in ipairs({ -1, 1 }) do
		r:Rod(H, V(0.5 * s, -0.4, -0.7), V(0.62 * s, 0.25, -0.95), 0.16, C.Bone)
		r:Ball(H, 0.18, CF(0.42 * s, 0.22, -0.66), P.NeonPink, M.Neon)
		r:Horn(H, s, V(0.65 * s, 0.25, 0.05), 0.65, C.Bone)
	end
	r:Ball(H, 0.32, CF(0, 0.3, -0.68), P.NeonPink, M.Neon)
	r:Box(H, V(0.55, 0.1, 0.06), CF(0, 0.55, -0.66) * ANG(0, 0, 0), P.Black)
	-- наплечная броня
	for _, a in ipairs({ { RA, 1 }, { LA, -1 } }) do
		local A, s = a[1], a[2]
		r:Pauldron(A, s, 1.35, P.Black, C.IronDark, 0.1)
		r:Box(A, V(0.25, 0.5, 1.2), CF(0.75 * s, 1.15, 0), C.IronDark, M.Metal)
		-- гигантские руки
		r:Sphere(A, V(1.75, 1.8, 1.75), CF(0.1 * s, -0.15, 0), C.Flesh)
		r:Sphere(A, V(1.95, 1.6, 1.95), CF(0.15 * s, -1.05, 0), C.Flesh)
		r:Box(A, V(1.7, 1.0, 1.7), CF(0.15 * s, -1.9, 0), P.Black, M.Metal)
		for k = -1, 1 do
			r:Ball(A, 0.45, CF(0.15 * s + k * 0.5, -2.4, -0.55), C.FleshDark)
		end
		r:Neon(A, V(1.72, 0.06, 1.72), CF(0.15 * s, -1.55, 0), P.NeonPink)
	end
	for _, Lg in ipairs({ RL, LL }) do
		r:Box(Lg, V(1.3, 1.2, 1.3), CF(0, -0.2, 0), C.FleshDark)
		r:Box(Lg, V(1.35, 0.4, 1.55), CF(0, -0.82, -0.12), P.Black, M.Metal)
	end
	return finishBiped(r, scale, { Root = { 14, 0, 0 }, Neck = { -14, 0, 0 }, RS = { 8, 0, 6 }, LS = { 8, 0, -6 } })
end

------------------------------------------------------------------------
-- 7. CORRUPTED TITAN (мини-босс) — рога, нагрудник, кулаки, кристалл, разломы энергии
------------------------------------------------------------------------
local function CorruptedTitan(scale)
	local r = Rig.new({ Name = "CorruptedTitan", Torso = P.Coal, Arm = P.Coal, Leg = P.Black, Head = P.Coal, HeadSize = V(1.4, 1.3, 1.4), TorsoMat = M.Slate })
	setup(r, { Style = "Heavy", Gait = { Speed = 0.8, Stride = 0.4, Bob = 0.2, Sway = 0.08, Shake = 0.2 }, Death = "Topple", Spawn = "Titan" })
	local T, H, RA, LA, RL, LL = r.Torso, r.Head, r.RArm, r.LArm, r.RLeg, r.LLeg
	-- нагрудник
	r:Box(T, V(2.75, 2.25, 1.6), CF(0, 0.12, 0), P.Coal, M.Slate)
	r:Box(T, V(2.55, 1.5, 0.35), CF(0, 0.4, -0.9), P.Black, M.Metal)
	r:Wedge(T, V(2.55, 0.5, 0.35), CF(0, -0.6, -0.9) * ANG(PI, 0, 0), P.Black, M.Metal)
	r:Box(T, V(2.6, 0.1, 0.38), CF(0, 1.12, -0.9), P.DarkGold, M.Metal)
	-- кристалл в груди
	local core = r:Box(T, V(0.7, 0.95, 0.5), CF(0, 0.4, -1.1) * ANG(0, 0, rad(45)), C.Crystal, M.Neon)
	r:Box(T, V(0.42, 0.6, 0.55), CF(0, 0.4, -1.12) * ANG(0, 0, rad(45)), C.CrystalPale, M.Neon)
	local coreLight = glow(r, core, C.Crystal, 14, 1.6)
	-- разломы энергии
	crack(r, T, { V(-1.2, 0.95, -0.82), V(-0.55, 0.45, -0.82), V(-0.75, -0.3, -0.82), V(-0.4, -1.0, -0.82) }, 0.11)
	crack(r, T, { V(1.15, 0.8, -0.82), V(0.6, 0.0, -0.82), V(0.85, -0.85, -0.82) }, 0.1)
	-- голова с рогами
	r:Box(H, V(1.55, 1.1, 1.55), CF(0, 0.15, 0), P.Black, M.Slate)
	r:Box(H, V(1.2, 0.14, 0.08), CF(0, -0.05, -0.79), P.Neon, M.Neon)
	r:Box(H, V(1.0, 0.45, 0.4), CF(0, -0.45, -0.6), P.Coal, M.Slate)
	for _, s in ipairs({ -1, 1 }) do
		r:Horn(H, s, V(0.7 * s, 0.45, 0), 1.15, P.Black)
		r:Horn(H, s, V(0.35 * s, 0.7, -0.2), 0.55, P.Coal)
	end
	-- наплечники
	r:Pauldron(RA, 1, 1.25, P.Black, P.Neon, 0, M.Neon)
	r:Pauldron(LA, -1, 1.15, P.Black, P.DarkGold, 0)
	-- гигантские кулаки
	for _, a in ipairs({ { RA, 1 }, { LA, -1 } }) do
		local A, s = a[1], a[2]
		r:Box(A, V(1.15, 1.1, 1.15), CF(0, 0, 0), P.Coal, M.Slate)
		r:Box(A, V(1.75, 1.45, 1.75), CF(0, -1.25, 0), P.Black, M.Metal)
		for k = -1, 1 do
			r:Box(A, V(0.42, 0.4, 0.4), CF(k * 0.55, -1.7, -0.85), P.Steel, M.Metal)
		end
		crack(r, A, { V(-0.4 * s, -0.6, -0.89), V(0.1 * s, -1.1, -0.89), V(-0.2 * s, -1.6, -0.89) }, 0.08)
	end
	for _, Lg in ipairs({ RL, LL }) do
		r:Box(Lg, V(1.25, 1.3, 1.25), CF(0, -0.35, 0), P.Coal, M.Slate)
		r:Box(Lg, V(1.3, 0.4, 1.5), CF(0, -0.85, -0.1), P.Black, M.Metal)
	end
	-- парящие осколки разлома вокруг корпуса
	r:Orbit("OrbitRift", T, CF(0, 0.3, 0), 2.6, 5, 0.4, C.Crystal, M.Neon, 0.1)
	r.Sec.OrbitRift = { Speed = 1.1 }
	local aura = emitter(T, C.Crystal, { Rate = 10, Size = 0.5, Accel = V(0, 2, 0) })
	-- фаза повреждений (50% HP): новые трещины, сильнее свечение, больше частиц
	local dmg = hide(join(
		crack(r, T, { V(0.2, 1.1, -0.82), V(-0.1, 0.6, -0.82), V(0.35, 0.2, -0.82) }, 0.09),
		crack(r, H, { V(-0.5, 0.6, -0.79), V(-0.2, 0.2, -0.79), V(-0.4, -0.2, -0.79) }, 0.07),
		crack(r, RL, { V(0.2, 0.3, -0.64), V(-0.1, -0.4, -0.64) }, 0.08),
		crack(r, LL, { V(-0.2, 0.2, -0.64), V(0.15, -0.5, -0.64) }, 0.08)
	))
	local dmgFx = emitter(T, P.NeonSoft, { Rate = 16, Size = 0.35, Off = true, SpeedMin = 2, SpeedMax = 4 })
	r.Phases = { { At = 0.5, Reveal = dmg, Emit = { dmgFx, aura }, Lights = { { coreLight, 3 } }, Aggro = 1.15 } }
	return finishBiped(r, scale)
end

------------------------------------------------------------------------
-- 8. VOID DEVOURER (босс) — высокий, массивные рога, слоистая броня, светящаяся пасть
------------------------------------------------------------------------
local function VoidDevourer(scale)
	local r = Rig.new({ Name = "VoidDevourer", Torso = C.Obsidian, Arm = C.Obsidian, Leg = C.Obsidian, Head = C.Obsidian, HeadSize = V(1.6, 1.35, 1.6), TorsoMat = M.Basalt })
	setup(r, { Style = "Heavy", Gait = { Speed = 0.7, Stride = 0.38, Bob = 0.22, Sway = 0.1, Lean = 4, Shake = 0.3 }, Death = "Topple" })
	local T, H, RA, LA, RL, LL = r.Torso, r.Head, r.RArm, r.LArm, r.RLeg, r.LLeg
	-- слоистая чёрная броня
	r:Box(T, V(2.6, 2.3, 1.5), CF(0, 0.1, 0), C.Obsidian, M.Basalt)
	local plateA = r:Box(T, V(2.7, 0.9, 1.7), CF(0, 0.75, -0.05), P.Black, M.Metal)
	local plateB = r:Box(T, V(2.5, 0.75, 1.65), CF(0, 0.05, -0.08), P.Coal, M.Metal)
	r:Box(T, V(2.3, 0.7, 1.6), CF(0, -0.65, -0.05), P.Black, M.Metal)
	r:Box(T, V(2.75, 0.08, 1.75), CF(0, 0.32, -0.05), C.Crystal, M.Neon)
	-- кристаллы
	local cr = {}
	for _, c in ipairs({ { -0.8, 1.0, 0.8, -0.4 }, { 0, 1.1, 0.85, 0 }, { 0.75, 0.95, 0.8, 0.35 }, { -0.35, 0.3, 0.85, -0.2 } }) do
		local base = V(c[1], c[2], c[3])
		cr[#cr + 1] = r:Seg(T, base, base + V(c[4], 1.1, 0.7), 0.42, C.Crystal, M.Neon)
	end
	glow(r, T, C.Crystal, 12, 1.2)
	-- голова: огромная светящаяся пасть
	r:Sphere(H, V(1.95, 1.5, 1.85), CF(0, 0.05, 0), C.Obsidian, M.Basalt)
	r:Box(H, V(1.7, 0.35, 1.0), CF(0, 0.55, -0.45), P.Black, M.Metal)
	r:Box(H, V(1.4, 0.55, 0.3), CF(0, -0.2, -0.8), C.Maw, M.Neon)
	for i = -3, 3 do
		r:Wedge(H, V(0.18, 0.4, 0.2), CF(i * 0.22, -0.02, -0.88) * ANG(0, 0, PI), P.White)
	end
	r:Eyes(C.Maw, { Y = 0.35, Spacing = 0.45, Size = V(0.32, 0.14, 0.06), Tilt = -20 })
	local mawLight = glow(r, H, C.Maw, 10, 1.4)
	local jaw = r:Joint("Jaw", H, V(1.55, 0.4, 1.35), CF(0, -0.55, 0.35), CF(0, -0.15, -0.65), C.Obsidian, M.Basalt)
	for i = -3, 3 do
		r:Wedge(jaw, V(0.17, 0.36, 0.2), CF(i * 0.21, 0.36, -0.55), P.White)
	end
	r:Neon(jaw, V(1.2, 0.08, 0.95), CF(0, 0.2, -0.05), C.Maw)
	-- массивные рога
	for _, s in ipairs({ -1, 1 }) do
		r:Horn(H, s, V(0.8 * s, 0.4, 0.1), 1.7, P.Black)
		r:Chain(H, { V(0.55 * s, 0.7, 0.4), V(0.85 * s, 1.2, 1.0), V(1.0 * s, 1.4, 1.7), V(0.95 * s, 1.2, 2.2) }, 0.28, P.Coal, M.Plastic, 0.75, true)
	end
	-- слоистые наплечники с кристаллами
	local pauldrons = {}
	for _, a in ipairs({ { RA, 1 }, { LA, -1 } }) do
		local A, s = a[1], a[2]
		r:Pauldron(A, s, 1.45, P.Black, C.IronDark, 0)
		local top = r:Box(A, V(1.2, 0.35, 1.4), CF(0.2 * s, 1.35, 0) * ANG(0, 0, rad(-18 * s)), P.Coal, M.Metal)
		pauldrons[#pauldrons + 1] = top
		cr[#cr + 1] = r:Seg(A, V(0.3 * s, 1.3, 0.2), V(0.75 * s, 2.1, 0.45), 0.32, C.Crystal, M.Neon)
		r:Box(A, V(1.3, 1.2, 1.3), CF(0, -0.15, 0), P.Black, M.Metal)
		r:Box(A, V(1.5, 0.9, 1.5), CF(0, -0.95, 0), C.Obsidian, M.Basalt)
		for k = -1, 1 do
			r:Rod(A, V(k * 0.4, -1.3, -0.6), V(k * 0.45, -1.6, -1.05), 0.14, C.Bone)
		end
	end
	for _, Lg in ipairs({ RL, LL }) do
		r:Box(Lg, V(1.25, 1.2, 1.3), CF(0, -0.35, 0), P.Black, M.Metal)
		r:Box(Lg, V(1.35, 0.45, 1.6), CF(0, -0.82, -0.15), C.Obsidian, M.Basalt)
	end
	-- парящие осколки за спиной
	r:Orbit("OrbitShards", T, CF(0, 0.9, 1.6), 1.5, 6, 0.45, C.Crystal, M.Neon, 0.05)
	r.Sec.OrbitShards = { Speed = 0.9 }
	local aura = emitter(T, C.Maw, { Rate = 12, Size = 0.55, Accel = V(0, 1.5, 0) })
	-- Фаза 2 (66%): светящиеся трещины по броне
	local cracks2 = hide(join(
		crack(r, T, { V(-1.0, 1.1, -0.91), V(-0.5, 0.6, -0.91), V(-0.7, 0.0, -0.91) }, 0.09, C.Maw),
		crack(r, T, { V(0.9, 0.9, -0.91), V(0.4, 0.35, -0.91), V(0.7, -0.4, -0.91) }, 0.09, C.Maw),
		crack(r, H, { V(-0.6, 0.6, -0.95), V(-0.25, 0.2, -0.95) }, 0.07, C.Maw)
	))
	-- Фаза 3 (33%): броня отваливается, под ней — кристаллическое ядро
	local inner = hide({
		r:Box(T, V(1.6, 0.6, 0.2), CF(0, 0.75, -0.8), C.Crystal, M.Neon),
		r:Box(T, V(1.2, 0.5, 0.2), CF(0, 0.05, -0.8), C.CrystalPale, M.Neon),
	})
	local burst = emitter(T, C.Crystal, { Rate = 22, Size = 0.4, SpeedMin = 3, SpeedMax = 6, Off = true })
	r.Phases = {
		{ At = 0.66, Reveal = cracks2, Emit = { aura }, Lights = { { mawLight, 2.4 } }, Aggro = 1.1 },
		{ At = 0.33, Reveal = inner, Break = join({ plateA, plateB }, pauldrons), Emit = { burst }, Aggro = 1.25 },
	}
	return finishBiped(r, scale, { Root = { 5, 0, 0 }, Neck = { -6, 0, 0 } }, 6.3)
end

------------------------------------------------------------------------
-- 9. THE ENTITY (финальный босс)
-- Сломанная корона, асимметричная броня, огромные руки, разбитое кольцо за спиной,
-- парящие камни, энергетическое ядро, цепи и руны. 3 визуальные фазы.
------------------------------------------------------------------------
local function TheEntity(scale)
	local r = Rig.new({ Name = "TheEntity", Torso = P.Black, Arm = P.Black, Leg = P.Black, Head = C.Obsidian, HeadSize = V(1.3, 1.5, 1.3), TorsoMat = M.Basalt })
	setup(r, { Style = "Heavy", Gait = { Speed = 0.75, Stride = 0.36, Bob = 0.2, Sway = 0.09, Lean = 3, Shake = 0.4 }, Death = "Implode" })
	local T, H, RA, LA, RL, LL = r.Torso, r.Head, r.RArm, r.LArm, r.RLeg, r.LLeg

	-- ТОРС: асимметричная броня (правая сторона тяжёлая, левая — открытая с цепями)
	r:Box(T, V(2.4, 2.2, 1.35), CF(0, 0.1, 0), C.Obsidian, M.Basalt)
	r:Box(T, V(1.55, 1.7, 1.6), CF(0.5, 0.35, -0.05) * ANG(0, 0, rad(-6)), P.Black, M.Metal)
	r:Wedge(T, V(1.2, 0.9, 1.55), CF(-0.55, 0.85, -0.05) * ANG(0, 0, rad(90)), P.Coal, M.Metal)
	r:Box(T, V(2.3, 0.45, 1.5), CF(0, -0.85, 0), P.Black, M.Metal)
	r:Box(T, V(2.4, 0.1, 1.55), CF(0, -0.6, 0), C.Rune, M.Neon)
	-- энергетическое ядро в клетке рёбер
	local core = r:Ball(T, 0.9, CF(-0.15, 0.25, -0.75), P.Neon, M.Neon)
	r:Ball(T, 0.55, CF(-0.15, 0.25, -0.98), P.White, M.Neon)
	for i = -2, 2 do
		r:Rod(T, V(-0.15 + i * 0.22, 0.85, -0.8), V(-0.15 + i * 0.28, -0.35, -0.85), 0.1, C.Bone)
	end
	local coreLight = glow(r, core, P.Neon, 18, 2)
	-- руны на броне
	for i, p in ipairs({ V(0.75, 0.9, -0.86), V(0.9, 0.3, -0.86), V(0.6, -0.25, -0.86), V(-0.9, -0.3, -0.7) }) do
		r:Neon(T, V(0.16, 0.34, 0.05), CF(p) * ANG(0, 0, rad(i * 30)), C.Rune)
		r:Neon(T, V(0.3, 0.06, 0.05), CF(p + V(0, 0.08, 0)), C.Rune)
	end
	-- плащ
	r:Cape(2.3, 4.2, C.Obsidian, true)
	r.Sec.Cape = { Amp = 0.12, Speed = 1.4 }
	r.Sec.Cape2 = { Amp = 0.18, Speed = 1.4 }

	-- ГОЛОВА: маска, фиолетовые глаза, рот-трещина
	r:Box(H, V(1.38, 1.55, 1.38), CF(0, 0, 0), C.Obsidian, M.Basalt)
	r:Wedge(H, V(1.3, 0.6, 0.5), CF(0, -0.55, -0.6) * ANG(PI, 0, 0), P.Black, M.Metal)
	r:Eyes(P.Neon, { Y = 0.2, Spacing = 0.32, Size = V(0.32, 0.16, 0.06), Tilt = -14 })
	r:Neon(H, V(0.75, 0.07, 0.05), CF(0, -0.3, -0.71) * ANG(0, 0, rad(-6)), P.Neon)
	glow(r, H, P.Neon, 8, 1.2)
	-- высокая сломанная корона
	r:Cyl(H, 0.35, 1.6, CF(0, 0.75, 0), P.DarkGold, M.Metal, "Y")
	local crownTall = {}
	local crownSpikes = { { 0, 2.0, 0 }, { 0.5, 1.5, 15 }, { -0.5, 1.6, -15 }, { 0.75, 0.6, 30, true }, { -0.75, 1.1, -30 }, { 0.3, 0.45, 8, true } }
	for _, s in ipairs(crownSpikes) do
		local base = V(s[1], 0.9, -0.55)
		local tip = base + V(math.sin(rad(s[3])) * s[2], s[2], 0)
		local p = r:Seg(H, base, tip, 0.2, P.DarkGold, M.Metal)
		local gem = r:Ball(H, 0.18, CF(tip), C.Rune, M.Neon)
		if s[4] then
			-- уже обломанный зубец
			r:Seg(H, tip, tip + V(0.2, 0.05, 0), 0.12, P.DarkGold, M.Metal)
		elseif s[2] >= 1.1 then
			crownTall[#crownTall + 1] = p
			crownTall[#crownTall + 1] = gem
		end
	end
	for i = -1, 1, 2 do
		r:Seg(H, V(i * 0.6, 0.9, 0.45), V(i * 0.75, 1.9, 0.6), 0.18, P.DarkGold, M.Metal)
	end

	-- РУКИ: правая — тяжёлая броня, левая — открытая плоть, цепи
	r:Pauldron(RA, 1, 1.55, P.Black, P.DarkGold, 0.1)
	r:Pauldron(RA, 1, 1.15, P.Coal, nil, 0.55)
	for k = 0, 2 do
		r:Rod(RA, V(0.3, 1.2, -0.4 + k * 0.4), V(0.9, 2.1 - k * 0.15, -0.5 + k * 0.45), 0.18, P.Black, M.Metal)
	end
	r:Box(LA, V(1.2, 0.5, 1.2), CF(-0.15, 0.85, 0), P.Coal, M.Metal)
	for _, a in ipairs({ { RA, 1 }, { LA, -1 } }) do
		local A, s = a[1], a[2]
		r:Sphere(A, V(1.45, 1.5, 1.45), CF(0, -0.1, 0), C.Obsidian, M.Basalt)
		r:Box(A, V(1.65, 1.35, 1.65), CF(0, -1.2, 0), s == 1 and P.Black or C.Obsidian, s == 1 and M.Metal or M.Basalt)
		-- когти
		for k = -1, 1 do
			r:Chain(A, { V(k * 0.45, -1.8, -0.55), V(k * 0.5, -2.2, -0.9), V(k * 0.4, -2.45, -1.15) }, 0.16, C.Bone, M.Plastic, 0.65, true)
		end
		r:Neon(A, V(0.1, 1.0, 0.05), CF(0.2 * s, -0.2, -0.75), C.Rune)
	end
	-- цепи, свисающие с левого запястья и пояса
	local function chainLinks(limb, n, size)
		for i = 0, n - 1 do
			r:Box(limb, V(size, size * 1.6, size * 0.35), CF(0, -i * size * 1.3, 0) * ANG(0, i % 2 == 0 and 0 or PI / 2, 0), P.Steel, M.Metal)
		end
	end
	local ch1 = r:Joint("SwayChainL", LA, V(0.2, 0.2, 0.2), CF(-0.2, -1.6, 0.3), CF(), P.Steel)
	ch1.Transparency = 1
	chainLinks(ch1, 6, 0.3)
	r.Sec.SwayChainL = { Amp = 0.25, Speed = 2.2 }
	for _, x in ipairs({ -0.85, 0.85 }) do
		local name = x < 0 and "SwayChainW1" or "SwayChainW2"
		local ch = r:Joint(name, T, V(0.2, 0.2, 0.2), CF(x, -1.05, -0.6), CF(), P.Steel)
		ch.Transparency = 1
		chainLinks(ch, 5, 0.26)
		r.Sec[name] = { Amp = 0.2, Speed = 2 + x }
	end
	-- набедренник
	local cloth = r:Joint("SwayCloth", T, V(1.4, 1.6, 0.12), CF(0, -1.0, -0.72), CF(0, -0.8, 0), C.Obsidian, M.Fabric)
	r:Neon(cloth, V(0.18, 1.2, 0.05), CF(0, -0.1, -0.08), C.Rune)
	r.Sec.SwayCloth = { Amp = 0.15, Speed = 1.8 }
	-- ноги в броне
	for _, Lg in ipairs({ RL, LL }) do
		r:Box(Lg, V(1.25, 1.2, 1.3), CF(0, -0.35, 0), P.Black, M.Metal)
		r:Sphere(Lg, V(0.85, 0.6, 0.4), CF(0, 0.2, -0.62), P.Coal, M.Metal)
		r:Box(Lg, V(1.35, 0.45, 1.6), CF(0, -0.82, -0.15), C.Obsidian, M.Basalt)
	end

	-- РАЗБИТОЕ КОЛЬЦО за спиной (медленно вращается)
	local halo = hub(r, "SpinHalo", T, CF(0, 1.4, 1.35), { Speed = 0.35 })
	local ringParts = ring(r, halo, CF(), 2.6, 18, 0.28, 0.22, P.DarkGold, M.Metal, function(i) return i == 4 or i == 11 end)
	ring(r, halo, CF(0, 0, -0.05), 2.35, 18, 0.07, 0.1, C.Rune, M.Neon, function(i) return i == 4 or i == 11 or i == 12 end)
	for i = 0, 5 do
		local a = i / 6 * PI * 2 + 0.3
		r:Neon(halo, V(0.25, 0.4, 0.1), CF(math.cos(a) * 2.6, math.sin(a) * 2.6, -0.15) * ANG(0, 0, a), C.Rune)
	end
	-- в фазе 3 кольцо разламывается: отпадает треть сегментов
	local ringBreak = {}
	for i, p in ipairs(ringParts) do
		if i % 3 == 0 then
			ringBreak[#ringBreak + 1] = p
		end
	end
	-- ПАРЯЩИЕ КАМНИ
	r:Orbit("OrbitStones", T, CF(0, -0.4, 0), 3.6, 6, 0.75, P.Coal, M.Slate)
	r.Sec.OrbitStones = { Speed = 0.6 }
	r:Orbit("OrbitShards", T, CF(0, 1.6, 0), 2.8, 5, 0.35, P.Neon, M.Neon, 0.1)
	r.Sec.OrbitShards = { Speed = -1.2 }

	emitter(T, P.Neon, { Rate = 10, Size = 0.6, Accel = V(0, 2, 0) })
	local smoke = emitter(emitPoint(r, T, CF(0, -3.2, 0), V(2.5, 0.4, 2.5)), Color3.fromRGB(50, 20, 80), { Smoke = true, Rate = 5, Size = 2, SizeEnd = 3.5, LifeMin = 1, LifeMax = 1.8, T0 = 0.6 })

	-- ФАЗА 2 (65% HP): дополнительные трещины и усиленное свечение
	local cracks2 = hide(join(
		crack(r, T, { V(-1.0, 1.0, -0.69), V(-0.6, 0.5, -0.69), V(-0.85, -0.1, -0.69), V(-0.5, -0.5, -0.69) }, 0.09),
		crack(r, T, { V(1.15, 1.0, -0.86), V(0.7, 0.55, -0.86), V(1.0, 0.0, -0.86) }, 0.09),
		crack(r, H, { V(0.45, 0.65, -0.7), V(0.2, 0.2, -0.7), V(0.4, -0.15, -0.7) }, 0.07),
		crack(r, RL, { V(0.3, 0.2, -0.66), V(-0.1, -0.5, -0.66) }, 0.08),
		crack(r, LL, { V(-0.3, 0.1, -0.66), V(0.15, -0.6, -0.66) }, 0.08)
	))
	local aura2 = emitter(T, C.CrystalPale, { Rate = 14, Size = 0.45, SpeedMin = 2, SpeedMax = 4, Off = true })
	-- ФАЗА 3 (30% HP): корона и кольцо ломаются, больше осколков, светятся обломки
	local stubs = {}
	for _, s in ipairs(crownSpikes) do
		if not s[4] and s[2] >= 1.1 then
			local base = V(s[1], 0.9, -0.55)
			stubs[#stubs + 1] = r:Seg(H, base, base + V(math.sin(rad(s[3])) * 0.45, 0.45, 0), 0.22, C.Rune, M.Neon)
		end
	end
	hide(stubs)
	local extraHub = hub(r, "OrbitShards3", T, CF(0, 0.4, 0), { Speed = 1.8 })
	local extra = {}
	for i = 0, 7 do
		local a = i / 8 * PI * 2
		extra[#extra + 1] = r:Box(extraHub, V(0.35, 0.7, 0.35), CF(math.cos(a) * 4.4, math.sin(a * 3) * 0.6, math.sin(a) * 4.4) * ANG(rad(30), a, rad(20)), C.Crystal, M.Neon)
	end
	hide(extra)
	local ringStub = hide(ring(r, halo, CF(0, 0, -0.1), 2.6, 18, 0.12, 0.3, P.Neon, M.Neon, function(i) return i % 3 ~= 0 end))
	local rage = emitter(T, P.NeonPink, { Rate = 20, Size = 0.5, SpeedMin = 3, SpeedMax = 7, Off = true })
	r.Phases = {
		{ At = 0.65, Reveal = cracks2, Emit = { aura2 }, Lights = { { coreLight, 3.5 } }, Aggro = 1.1 },
		{ At = 0.30, Reveal = join(stubs, extra, ringStub), Break = join(crownTall, ringBreak), Emit = { rage, smoke }, Lights = { { coreLight, 5 } }, Aggro = 1.4 },
	}
	local rig = finishBiped(r, scale, { Root = { 4, 0, 0 }, RS = { 6, 0, 10 }, LS = { 6, 0, -10 } }, 6.6)
	return rig
end

local Builders = {
	LostSoul = LostSoul,
	VoidCrawler = VoidCrawler,
	ShadowBeast = ShadowBeast,
	ArmoredHorror = ArmoredHorror,
	RiftPhantom = RiftPhantom,
	AbyssBrute = AbyssBrute,
	CorruptedTitan = CorruptedTitan,
	VoidDevourer = VoidDevourer,
	TheEntity = TheEntity,
}

function EnemyModels.Build(enemyId)
	local def = Config.Enemies[enemyId]
	local builder = Builders[enemyId]
	if not def or not builder then
		error("Unknown enemy " .. tostring(enemyId))
	end
	local rig = builder(def.Scale or 1)
	rig.Model.Name = enemyId
	for _, d in ipairs(rig.Model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CanQuery = false
			d.CanTouch = false
			d.CastShadow = def.IsBoss == true or d.Name == "Torso"
		end
	end
	return rig
end

return EnemyModels
