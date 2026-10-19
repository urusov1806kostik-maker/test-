--!nocheck
-- VOID TD :: UnitModels
-- Процедурные модели юнитов в стиле Roblox R6. Без внешних ассетов.
-- UnitModels.Build(unitId, level) -> rig { Model, Motors, Base, Idle, Muzzle, ... }

local UnitModels = {}
-- Облегчённый режим: без мелких деталей, частиц, подсветки и шлейфов (меняется на клиенте)
UnitModels.Lite = false

-- общий набор угловатых деталей (фаска, шипы, ромбы, наплечники) — см. ModelKit
local Kit = require(script.Parent.ModelKit)
Kit.IsLite = function()
	return UnitModels.Lite
end
UnitModels.Kit = Kit

local V = Vector3.new
local V2 = Vector2.new
local CF = CFrame.new
local ANG = CFrame.Angles
local rad = math.rad

local M = {
	Plastic = Enum.Material.SmoothPlastic,
	Metal = Enum.Material.Metal,
	Neon = Enum.Material.Neon,
	Fabric = Enum.Material.Fabric,
	Slate = Enum.Material.Slate,
	Glass = Enum.Material.Glass,
	Wood = Enum.Material.Wood,
}

local P = {
	Black = Color3.fromRGB(20, 18, 26),
	Coal = Color3.fromRGB(33, 30, 41),
	Dark = Color3.fromRGB(48, 44, 58),
	Steel = Color3.fromRGB(74, 72, 86),
	Gray = Color3.fromRGB(108, 106, 120),
	Pale = Color3.fromRGB(168, 163, 180),
	Violet = Color3.fromRGB(70, 30, 110),
	DeepViolet = Color3.fromRGB(42, 18, 66),
	Purple = Color3.fromRGB(112, 52, 172),
	Neon = Color3.fromRGB(180, 80, 255),
	NeonSoft = Color3.fromRGB(210, 150, 255),
	NeonPink = Color3.fromRGB(255, 60, 170),
	Maroon = Color3.fromRGB(88, 20, 36),
	Crimson = Color3.fromRGB(140, 28, 48),
	White = Color3.fromRGB(245, 240, 255),
	Gold = Color3.fromRGB(200, 156, 60),
	DarkGold = Color3.fromRGB(140, 104, 40),
	Skin = Color3.fromRGB(140, 132, 146),
}
UnitModels.Palette = P

------------------------------------------------------------------------
-- RIG
------------------------------------------------------------------------
local Rig = {}
Rig.__index = Rig

local function basePart(className, size, color, material)
	local p = Instance.new(className)
	p.Size = size
	p.Color = color
	p.Material = material or M.Plastic
	p.Anchored = false
	p.CanCollide = false
	p.CanTouch = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	return p
end

function Rig.new(o)
	local self = setmetatable({}, Rig)
	local model = Instance.new("Model")
	model.Name = o.Name or "Unit"
	self.Model = model
	self.Motors = {}
	self.Base = {}

	local root = basePart("Part", V(2, 2, 1), Color3.new(), nil)
	root.Name = "HumanoidRootPart"
	root.Transparency = 1
	root.Anchored = true
	root.CFrame = CF()
	root.Parent = model
	self.Root = root

	local hs = o.HeadSize or V(1.3, 1.3, 1.3)
	self.HeadSize = hs

	local function limb(name, size, cf, color, mat)
		local p = basePart("Part", size, color, mat)
		p.Name = name
		p.CFrame = cf
		p.Parent = model
		return p
	end

	self.Torso = limb("Torso", V(2, 2, 1), CF(), o.Torso or P.Dark, o.TorsoMat)
	self.Head = limb("Head", hs, CF(0, 1 + hs.Y / 2, 0), o.Head or P.Skin)
	self.RArm = limb("Right Arm", V(1, 2, 1), CF(1.5, 0, 0), o.Arm or o.Torso or P.Dark)
	self.LArm = limb("Left Arm", V(1, 2, 1), CF(-1.5, 0, 0), o.Arm or o.Torso or P.Dark)
	self.RLeg = limb("Right Leg", V(1, 2, 1), CF(0.5, -2, 0), o.Leg or P.Black)
	self.LLeg = limb("Left Leg", V(1, 2, 1), CF(-0.5, -2, 0), o.Leg or P.Black)
	self.Pending = {}
	self.PendingTrails = {}

	local function motor(name, p0, p1, c0, c1)
		local m = Instance.new("Motor6D")
		m.Name = name
		m.Part0 = p0
		m.Part1 = p1
		m.C0 = c0
		m.C1 = c1
		m.Parent = p0
		self.Motors[name] = m
	end
	motor("Root", root, self.Torso, CF(), CF())
	motor("Neck", self.Torso, self.Head, CF(0, 1, 0), CF(0, -hs.Y / 2, 0))
	motor("RS", self.Torso, self.RArm, CF(1.5, 0.5, 0), CF(0, 0.5, 0))
	motor("LS", self.Torso, self.LArm, CF(-1.5, 0.5, 0), CF(0, 0.5, 0))
	motor("RH", self.Torso, self.RLeg, CF(0.5, -1, 0), CF(0, 1, 0))
	motor("LH", self.Torso, self.LLeg, CF(-0.5, -1, 0), CF(0, 1, 0))
	if o.RoundHead then
		-- круглая голова-цилиндр в стиле классического Roblox; детали крепятся к невидимому кубу Head
		self.Head.Transparency = 1
		self:Cyl(self.Head, hs.Y, math.max(hs.X, hs.Z), CF(), o.Head or P.Skin, M.Plastic, "Y").Name = "HeadShape"
	end
	return self
end

-- Деталь, приваренная к части тела. offset задаётся в локальных координатах limb.
function Rig:Add(limb, className, size, offset, color, material, props)
	local p = basePart(className, size, color, material)
	p.Name = "Detail"
	if props then
		for k, v in pairs(props) do
			p[k] = v
		end
	end
	p.CFrame = limb.CFrame * offset
	local w = Instance.new("Weld")
	w.Part0 = limb
	w.Part1 = p
	w.C0 = offset
	w.Parent = p
	p.Parent = self.Model
	return p
end

function Rig:Box(limb, size, offset, color, material, props)
	return self:Add(limb, "Part", size, offset, color, material, props)
end

local AXIS = {
	X = CF(),
	Y = ANG(0, 0, rad(90)),
	Z = ANG(0, rad(90), 0),
}

-- Цилиндр: длина len вдоль оси axis ("X" | "Y" | "Z"), диаметр d
function Rig:Cyl(limb, len, d, offset, color, material, axis, props)
	props = props or {}
	props.Shape = Enum.PartType.Cylinder
	return self:Add(limb, "Part", V(len, d, d), offset * AXIS[axis or "X"], color, material, props)
end

-- Эллипсоид (купол наплечника, круглое тело). Меш создаётся в Finish после масштабирования.
function Rig:Sphere(limb, size, offset, color, material, props)
	local p = self:Add(limb, "Part", size, offset, color, material, props)
	table.insert(self.Pending, p)
	return p
end

-- Круглый наплечник: купол-эллипсоид + обод
function Rig:Pauldron(limb, side, size, color, rim, lift, rimMat)
	size = size or 1
	local off = CF(0.12 * side, 0.82 + (lift or 0), 0) * ANG(0, 0, rad(-14 * side))
	self:Sphere(limb, V(1.55, 1.0, 1.5) * size, off, color or P.Black, M.Metal)
	if rim then
		self:Cyl(limb, 0.16, 1.6 * size, off * CF(0, -0.18 * size, 0), rim, rimMat or M.Metal, "Y")
	end
end

function Rig:Wedge(limb, size, offset, color, material, props)
	return self:Add(limb, "WedgePart", size, offset, color, material, props)
end

function Rig:Ball(limb, d, offset, color, material, props)
	props = props or {}
	props.Shape = Enum.PartType.Ball
	return self:Add(limb, "Part", V(d, d, d), offset, color, material, props)
end

function Rig:Neon(limb, size, offset, color, props)
	return self:Add(limb, "Part", size, offset, color or P.Neon, M.Neon, props)
end

-- Брусок между двумя точками (в координатах limb)
function Rig:Seg(limb, a, b, thick, color, material, props)
	local dir = b - a
	local len = dir.Magnitude
	local up = V(0, 1, 0)
	if math.abs(dir.Unit.Y) > 0.98 then
		up = V(0, 0, 1)
	end
	local cf = CFrame.lookAt((a + b) / 2, b, up)
	local tx, ty = thick, thick
	if typeof(thick) == "Vector2" then
		tx, ty = thick.X, thick.Y
	end
	if props and props.Round then
		props.Round = nil
		props.Shape = Enum.PartType.Cylinder
		return self:Add(limb, "Part", V(len, tx, tx), cf * AXIS.Z, color, material, props)
	end
	return self:Add(limb, "Part", V(tx, ty, len), cf, color, material, props)
end

-- Круглый стержень между точками (древки, рога, щупальца)
function Rig:Rod(limb, a, b, d, color, material, props)
	props = props or {}
	props.Round = true
	return self:Seg(limb, a, b, d, color, material, props)
end

-- Цепочка брусков (рога, щупальца, изогнутые лезвия)
function Rig:Chain(limb, points, thick, color, material, taper, round)
	local parts = {}
	local t = thick
	for i = 1, #points - 1 do
		parts[#parts + 1] = self:Seg(limb, points[i], points[i + 1], t, color, material, round and { Round = true } or nil)
		if round and i > 1 then
			self:Ball(limb, t * 1.02, CF(points[i]), color, material)
		end
		if taper then
			t = math.max(t * taper, 0.08)
		end
	end
	return parts
end

-- Подвижная часть на собственном Motor6D (крылья, челюсти)
function Rig:Joint(name, limb, size, pivot, fromPivot, color, material)
	local p = basePart("Part", size, color, material)
	p.Name = name
	p.CFrame = limb.CFrame * pivot * fromPivot
	p.Parent = self.Model
	local m = Instance.new("Motor6D")
	m.Name = name
	m.Part0 = limb
	m.Part1 = p
	m.C0 = pivot
	m.C1 = fromPivot:Inverse()
	m.Parent = limb
	self.Motors[name] = m
	return p
end

function Rig:Eyes(color, o)
	o = o or {}
	local hs = self.HeadSize
	local y = o.Y or 0.08
	local sp = o.Spacing or 0.3
	local size = o.Size or V(0.28, 0.14, 0.06)
	local z = -hs.Z / 2 - 0.02 + (o.Inset or 0)
	local l = self:Neon(self.Head, size, CF(-sp, y + (o.LeftLift or 0), z) * ANG(0, 0, rad(o.Tilt or 0)), color)
	local r = self:Neon(self.Head, o.RightSize or size, CF(sp, y, z) * ANG(0, 0, rad(-(o.Tilt or 0))), color)
	return l, r
end

function Rig:Glow(part, color, range, brightness)
	if UnitModels.Lite then
		return nil
	end
	local l = Instance.new("PointLight")
	l.Color = color or P.Neon
	l.Range = range or 8
	l.Brightness = brightness or 1.5
	l.Shadows = false
	l.Parent = part
	return l
end

function Rig:Sparkles(part, color, o)
	if UnitModels.Lite then
		return nil
	end
	o = o or {}
	local e = Instance.new("ParticleEmitter")
	e.Name = "Sparkles"
	e.Color = ColorSequence.new(color or P.Neon)
	e.LightEmission = 1
	e.LightInfluence = 0
	e.Rate = o.Rate or 8
	e.Lifetime = NumberRange.new(o.LifeMin or 0.5, o.LifeMax or 1)
	e.Speed = NumberRange.new(o.SpeedMin or 0.5, o.SpeedMax or 1.5)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, o.Size or 0.25),
		NumberSequenceKeypoint.new(1, 0),
	})
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	if o.Up then
		e.EmissionDirection = Enum.NormalId.Top
		e.SpreadAngle = Vector2.new(25, 25)
		e.Acceleration = V(0, o.Up, 0)
	end
	e.Parent = part
	return e
end

-- Меч в руке. Клинок направлен вперёд (-Z локально руки), ширина по Y.
function Rig:Sword(limb, o)
	o = o or {}
	local len = o.Length or 3
	local w = o.Width or 0.42
	local y = o.Y or -1.05
	self:Cyl(limb, 0.9, 0.26, CF(0, y, 0.05), o.Handle or P.Black, M.Fabric, "Z")
	self:Ball(limb, 0.4, CF(0, y, 0.55), o.Pommel or o.Guard or P.Steel, M.Metal)
	local gw = o.GuardWidth or w + 0.6
	self:Box(limb, V(0.3, gw, 0.26), CF(0, y, -0.45), o.Guard or P.Steel, M.Metal)
	self:Ball(limb, 0.34, CF(0, y + gw / 2, -0.45), o.Guard or P.Steel, M.Metal)
	self:Ball(limb, 0.34, CF(0, y - gw / 2, -0.45), o.Guard or P.Steel, M.Metal)
	self:Ball(limb, 0.34, CF(0, y, -0.45), o.Gem or o.Edge or P.Neon, M.Neon) -- камень в гарде
	local blade = self:Box(limb, V(0.14, w, len), CF(0, y, -0.58 - len / 2), o.Blade or P.Gray, o.BladeMat or M.Metal)
	blade.Name = "Blade"
	if not o.Core then
		self:Box(limb, V(0.16, math.max(w * 0.22, 0.07), len * 0.72), CF(0, y, -0.58 - len * 0.42), P.Black, M.Metal) -- желобок
	end
	for i = 1, (o.Runes or 0) do
		self:Neon(limb, V(0.17, 0.1, 0.18), CF(0, y - w * 0.22, -0.58 - len * (0.15 + i * 0.16)), o.Edge or P.Neon)
	end
	self:WeaponTrail(limb, V(0, y, -0.75), V(0, y, -0.58 - len), o.Edge or o.Core or P.NeonSoft)
	self:Wedge(limb, V(0.14, w, w * 1.3), CF(0, y, -0.58 - len - w * 0.65) * ANG(0, math.pi, 0), o.Blade or P.Gray, o.BladeMat or M.Metal)
	if o.Edge then
		self:Neon(limb, V(0.16, 0.09, len), CF(0, y + w / 2 - 0.02, -0.58 - len / 2), o.Edge)
	end
	if o.Core then
		self:Neon(limb, V(0.17, math.max(w * 0.25, 0.08), len * 0.8), CF(0, y, -0.58 - len * 0.45), o.Core)
	end
	local tip = self:Box(limb, V(0.2, 0.2, 0.2), CF(0, y, -0.58 - len), P.Black, M.Plastic, { Transparency = 1, Name = "Muzzle" })
	self.Muzzle = tip
	return blade
end

-- Светящийся шлейф оружия (включается Renderer'ом во время анимаций)
function Rig:WeaponTrail(limb, a, b, color)
	if UnitModels.Lite then
		return
	end
	table.insert(self.PendingTrails, { limb, a, b, color or P.NeonSoft })
end

-- Лицо: брови и рот. mood: "angry" | "calm" | "old"
function Rig:Face(o)
	if UnitModels.Lite then
		return
	end
	local hs = self.HeadSize
	local z = -hs.Z / 2 - 0.03
	local y = (o.EyeY or 0.08) + 0.2
	local sp = o.Spacing or 0.3
	local tilt = o.Mood == "angry" and 18 or (o.Mood == "old" and -10 or 4)
	local size = o.Mood == "old" and V(0.36, 0.13, 0.08) or V(0.3, 0.08, 0.06)
	self:Box(self.Head, size, CF(-sp, y, z) * ANG(0, 0, rad(-tilt)), o.BrowColor or P.Black)
	self:Box(self.Head, size, CF(sp, y, z) * ANG(0, 0, rad(tilt)), o.BrowColor or P.Black)
	if o.Mouth ~= false then
		self:Box(self.Head, V(o.Mood == "angry" and 0.4 or 0.3, 0.07, 0.06), CF(0, -0.32, z), o.MouthColor or P.Coal)
	end
end

-- Округлые кисти рук
function Rig:Hands(color, material)
	if UnitModels.Lite then
		return
	end
	for _, A in ipairs({ self.RArm, self.LArm }) do
		self:Sphere(A, V(1.08, 0.52, 1.08), CF(0, -0.93, 0), color or P.Coal, material or M.Plastic)
	end
end

function Rig:Horn(limb, side, base, size, color)
	local s = size or 1
	local pts = {
		base,
		base + V(0.35 * side, 0.45, 0.05) * s,
		base + V(0.55 * side, 0.95, 0.2) * s,
		base + V(0.45 * side, 1.4, 0.45) * s,
	}
	self:Ball(limb, 0.4 * s, CF(base), color or P.Black)
	self:Chain(limb, pts, 0.34 * s, color or P.Black, M.Plastic, 0.72, true)
	local d = pts[4] - pts[3]
	self:Seg(limb, pts[4], pts[4] + d.Unit * 0.35 * s, 0.12 * s, color or P.Black, M.Plastic, { Round = true })
end

-- Плащ на собственном моторе: развевается в анимации
function Rig:Cape(width, length, color, tatter)
	local T = self.Torso
	color = color or P.DeepViolet
	local l1 = length * 0.58
	local l2 = length - l1
	local cape = self:Joint("Cape", T, V(width, l1, 0.12), CF(0, 0.95, 0.58), ANG(rad(7), 0, 0) * CF(0, -l1 / 2, 0.02), color, M.Fabric)
	-- нижняя часть плаща на своём моторе: колышется с запаздыванием
	local cape2 = self:Joint("Cape2", cape, V(width * 0.98, l2, 0.12), CF(0, -l1 / 2, 0), CF(0, -l2 / 2, 0), color, M.Fabric)
	-- застёжки плаща
	self:Box(T, V(0.3, 0.3, 0.2), CF(-0.75, 0.85, 0.55), P.Gold, M.Metal)
	self:Box(T, V(0.3, 0.3, 0.2), CF(0.75, 0.85, 0.55), P.Gold, M.Metal)
	if tatter and not UnitModels.Lite then
		local seed = 0
		for i = -2, 2 do
			seed = seed + 1
			local h = 0.4 + ((seed * 37) % 5) * 0.12
			self:Wedge(cape2, V(width / 5.2, h, 0.12), CF(i * width / 5, -l2 / 2 - h / 2 + 0.02, 0) * ANG(0, 0, math.pi), color, M.Fabric)
		end
		-- кайма
		self:Box(cape, V(width + 0.04, 0.12, 0.14), CF(0, l1 / 2 - 0.25, 0), color:Lerp(P.Black, 0.4), M.Fabric)
		self:Box(cape2, V(width * 0.98 + 0.04, 0.1, 0.14), CF(0, -l2 / 2 + 0.15, 0), color:Lerp(P.White, 0.25), M.Fabric)
	end
	return cape
end

-- Кольцо вращающихся деталей (души, осколки, камни). Крутится в Renderer (моторы "Orbit*").
function Rig:Orbit(name, limb, offset, radius, count, size, color, material, transparency)
	local hub = self:Joint(name, limb, V(0.2, 0.2, 0.2), offset, CF(), P.Black)
	hub.Transparency = 1
	for i = 0, count - 1 do
		local a = i / count * math.pi * 2
		self:Add(hub, "Part", V(size, size * 1.3, size), CF(math.cos(a) * radius, math.sin(a * 2) * 0.15, math.sin(a) * radius) * ANG(rad(45), a, rad(30)),
			color or P.Neon, material or M.Neon, { Transparency = transparency or 0 })
	end
	return hub
end

function Rig:Pouch(limb, offset, color)
	color = color or P.Maroon
	self:Box(limb, V(0.42, 0.42, 0.28), offset, color, M.Fabric)
	self:Box(limb, V(0.44, 0.14, 0.3), offset * CF(0, 0.2, -0.01), color:Lerp(P.Black, 0.35), M.Fabric)
end

-- Поворачивает конечности в позу idle прямо в CFrame деталей: статичные превью (ViewportFrame)
-- и призрак размещения выглядят так же, как анимированная модель в игре.
function Rig:BakePose(pose)
	local attached = {}
	local limbMotors = { Root = true, Neck = true, RS = true, LS = true, RH = true, LH = true }
	for _, d in ipairs(self.Model:GetDescendants()) do
		if (d:IsA("Weld") or (d:IsA("Motor6D") and not limbMotors[d.Name])) and d.Part0 and d.Part1 then
			attached[d.Part0] = attached[d.Part0] or {}
			table.insert(attached[d.Part0], d.Part1)
		end
	end
	for name, ang in pairs(pose) do
		local m = self.Motors[name]
		if m and name ~= "Root" then
			local rot = ANG(rad(ang[1]), rad(ang[2]), rad(ang[3]))
			local limb = m.Part1
			local delta = (m.Part0.CFrame * m.C0 * rot * m.C1:Inverse()) * limb.CFrame:Inverse()
			local function move(p)
				p.CFrame = delta * p.CFrame
				for _, c in ipairs(attached[p] or {}) do
					move(c)
				end
			end
			move(limb)
			m.C0 = m.C0 * rot
		end
	end
end

function Rig:Finish(scale, idle)
	local model = self.Model
	model.PrimaryPart = self.Root
	scale = scale or 1
	if scale ~= 1 then
		model:ScaleTo(scale)
	end
	-- эллипсоиды: меш добавляем после ScaleTo, чтобы масштаб не применился дважды
	for _, p in ipairs(self.Pending or {}) do
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
	end
	self.Pending = {}
	for _, t in ipairs(self.PendingTrails or {}) do
		local limb = t[1]
		local a0 = Instance.new("Attachment")
		a0.Name = "TrailA"
		a0.Position = t[2] * scale
		a0.Parent = limb
		local a1 = Instance.new("Attachment")
		a1.Name = "TrailB"
		a1.Position = t[3] * scale
		a1.Parent = limb
		local trail = Instance.new("Trail")
		trail.Name = "WeaponTrail"
		trail.Attachment0 = a0
		trail.Attachment1 = a1
		trail.Color = ColorSequence.new(t[4])
		trail.LightEmission = 1
		trail.LightInfluence = 0
		trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
		trail.Lifetime = 0.22
		trail.MinLength = 0.05
		trail.Enabled = false
		trail.Parent = limb
	end
	self.PendingTrails = {}
	self.Scale = scale
	for name, m in pairs(self.Motors) do
		self.Base[name] = m.C0
	end
	if idle then
		self:BakePose(idle)
	end
	model:SetAttribute("HipHeight", 3 * scale)
	self.HipHeight = 3 * scale
	self.Idle = idle or {}
	if not self.Muzzle then
		self.Muzzle = self.RArm
	end
	return self
end

UnitModels.Rig = Rig

------------------------------------------------------------------------
-- ОБЩИЕ ЭФФЕКТЫ ПРОКАЧКИ
------------------------------------------------------------------------
local function levelAura(r, lv, color)
	color = color or P.Neon
	if lv >= 4 and r.Muzzle and r.Muzzle:IsA("BasePart") then
		r:Sparkles(r.Muzzle, color, { Rate = 6, Size = 0.25 })
	end
	if lv >= 5 then
		r:Add(r.Torso, "Part", V(0.08, 3.8, 3.8), CF(0, -2.96, 0) * ANG(0, 0, rad(90)), color, M.Neon,
			{ Shape = Enum.PartType.Cylinder, Transparency = 0.78, Name = "AuraRing" })
		r:Sparkles(r.Torso, color, { Rate = 10, Up = 3, Size = 0.3, LifeMin = 0.8, LifeMax = 1.4 })
		r:Glow(r.Torso, color, 10, 1.2)
	end
end


------------------------------------------------------------------------
-- R6-ФИГУРЫ В УГЛОВАТОМ СТИЛЕ (по референсу): тело — блоки R6 с фаской и светлым кантом,
-- поверх — броня, капюшоны, шлемы, плащи и оружие из блоков, клиньев и кристаллов-ромбов.
------------------------------------------------------------------------
local AC = Kit.Colors
local PI = math.pi
local GRIP = -1.05 -- точка хвата в кисти (локально в руке)

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

-- Базовая R6-фигура. pal: Torso, Arm, Leg, Skin, Edge
local function figure(name, pal)
	local r = Rig.new({ Name = name, HeadSize = V(1.2, 1.2, 1.2), Torso = pal.Torso, Arm = pal.Arm or pal.Torso, Leg = pal.Leg or pal.Torso, Head = pal.Skin or pal.Torso })
	for _, L in ipairs({ r.Torso, r.Head, r.RArm, r.LArm, r.RLeg, r.LLeg }) do
		L.Transparency = 1
	end
	local e = pal.Edge or AC.Edge
	Kit.bevel(r, r.Torso, V(2, 2, 1), CF(), pal.Torso, e)
	Kit.bevel(r, r.RArm, V(1, 2, 1), CF(), pal.Arm or pal.Torso, e)
	Kit.bevel(r, r.LArm, V(1, 2, 1), CF(), pal.Arm or pal.Torso, e)
	Kit.bevel(r, r.RLeg, V(1, 2, 1), CF(), pal.Leg or pal.Torso, e)
	Kit.bevel(r, r.LLeg, V(1, 2, 1), CF(), pal.Leg or pal.Torso, e)
	r:Box(r.Head, V(1.2, 1.2, 1.2), CF(), pal.Skin or rgb(70, 62, 80), M.Plastic)
	r.Pal = pal
	return r
end

-- Глаза: светящиеся или тёмные щели
local function eyes(r, color, glow, y)
	for _, s in ipairs({ -1, 1 }) do
		local f = glow and r.Neon or r.Box
		f(r, r.Head, V(0.22, 0.12, 0.05), CF(0.24 * s, y or 0.08, -0.61), color)
	end
end

-- Нагрудник, пояс с пряжкой, набедренники
local function chest(r, color, edge, gemColor)
	Kit.bevel(r, r.Torso, V(2.14, 1.05, 1.16), CF(0, 0.5, 0), color, edge)
	if gemColor then
		Kit.gem(r, r.Torso, 0.36, CF(0, 0.5, -0.62), gemColor, edge)
	end
end

local function belt(r, color, buckle, gemColor)
	Kit.bevel(r, r.Torso, V(2.1, 0.3, 1.12), CF(0, -0.82, 0), color, false, M.Fabric)
	Kit.bevel(r, r.Torso, V(0.42, 0.4, 0.12), CF(0, -0.82, -0.6), buckle, false)
	if gemColor then
		Kit.gem(r, r.Torso, 0.16, CF(0, -0.82, -0.68), gemColor)
	end
end

local function tassets(r, color, edge)
	for _, s in ipairs({ -1, 1 }) do
		Kit.bevel(r, r.Torso, V(0.85, 0.75, 0.2), CF(0.5 * s, -1.32, -0.56) * ANG(rad(-6), 0, 0), color, edge)
	end
end

-- Длинная юбка-мантия с рваным краем (поверх ног)
local function robe(r, color, trim, len)
	len = len or 1.8
	Kit.bevel(r, r.Torso, V(2.12, len, 1.14), CF(0, -1 - len / 2 + 0.1, 0), color, trim, M.Fabric)
	Kit.tatter(r, r.Torso, -1 - len + 0.1, -0.57, 2.1, 5, color, M.Fabric, 3)
	if trim then
		r:Box(r.Torso, V(0.3, len, 0.05), CF(0, -1 - len / 2 + 0.1, -0.58), trim, M.Fabric)
	end
end

-- Накидка на плечи
local function mantle(r, color, edge)
	Kit.bevel(r, r.Torso, V(2.35, 0.4, 1.3), CF(0, 0.88, 0), color, edge, M.Fabric)
	for _, s in ipairs({ -1, 1 }) do
		Kit.bevel(r, s == 1 and r.RArm or r.LArm, V(1.18, 0.7, 1.18), CF(0.05 * s, 0.68, 0), color, edge, M.Fabric)
	end
end

-- Капюшон: тёмное лицо, глаза светятся
local function hood(r, color, edge, eyeColor, peak)
	local H = r.Head
	Kit.bevel(r, H, V(1.44, 0.28, 1.44), CF(0, 0.72, 0.03), color, edge, M.Fabric)
	for _, s in ipairs({ -1, 1 }) do
		Kit.bevel(r, H, V(0.22, 1.32, 1.44), CF(0.72 * s, 0.06, 0.03), color, edge, M.Fabric)
	end
	Kit.bevel(r, H, V(1.44, 1.32, 0.22), CF(0, 0.06, 0.72), color, edge, M.Fabric)
	r:Wedge(H, V(1.44, 0.32, 0.4), CF(0, 0.58, -0.62), color, M.Fabric)
	if peak ~= false then
		Kit.spike(r, H, V(0, 0.8, 0.45), V(0, 1.15, 1.0), 0.7, color, M.Fabric, true, 0.2)
	end
	r:Box(H, V(1.04, 1.02, 0.05), CF(0, -0.02, -0.61), rgb(12, 9, 18), M.Plastic)
	eyes(r, eyeColor, true, 0.06)
end

-- Шлем рыцаря: блок с фаской и Т-визором
local function helm(r, color, edge, visor, crest, tall)
	local H = r.Head
	Kit.bevel(r, H, V(1.32, tall and 1.45 or 1.32, 1.34), CF(0, tall and 0.1 or 0.03, 0), color, edge)
	r:Neon(H, V(0.6, 0.09, 0.05), CF(0, 0.14, -0.68), visor)
	r:Neon(H, V(0.09, 0.42, 0.05), CF(0, -0.08, -0.68), visor)
	if crest then
		Kit.spike(r, H, V(0, 0.6 + (tall and 0.1 or 0), -0.25), V(0, 1.25 + (tall and 0.15 or 0), 0.25), 0.75, crest, M.Metal, true, 0.12)
	end
end

-- Остроконечная шляпа мага/ведьмы из уступов
local function wizardHat(r, color, band, edge)
	local H = r.Head
	Kit.bevel(r, H, V(2.3, 0.14, 2.3), CF(0, 0.64, 0), color, edge, M.Fabric)
	Kit.bevel(r, H, V(1.4, 0.24, 1.4), CF(0, 0.82, 0), band, false, M.Fabric)
	Kit.bevel(r, H, V(1.3, 0.55, 1.3), CF(0, 1.18, 0), color, edge, M.Fabric)
	Kit.bevel(r, H, V(0.95, 0.5, 0.95), CF(0.06, 1.6, 0.08) * ANG(rad(-8), 0, rad(-6)), color, edge, M.Fabric)
	Kit.bevel(r, H, V(0.6, 0.45, 0.6), CF(0.18, 1.98, 0.22) * ANG(rad(-18), 0, rad(-14)), color, edge, M.Fabric)
	Kit.spike(r, H, V(0.26, 2.15, 0.3), V(0.55, 2.55, 0.65), 0.5, color, M.Fabric)
end

-- Корона: четыре планки и зубцы с камнями
local function crown(r, color, gemColor, h)
	local H = r.Head
	h = h or 0.75
	for i = 0, 3 do
		r:Box(H, V(1.42, 0.26, 0.12), CF(0, 0.72, 0) * ANG(0, i * PI / 2, 0) * CF(0, 0, -0.66), color, M.Metal)
	end
	for i = 0, 7 do
		local a = i / 8 * PI * 2
		local p = V(math.sin(a) * 0.66, 0.8, -math.cos(a) * 0.66)
		local hh = (i % 2 == 0) and h or h * 0.6
		Kit.spike(r, H, p, p + V(0, hh, 0), 0.32, color, M.Metal, true, 0.1)
	end
	Kit.gem(r, H, 0.24, CF(0, 0.74, -0.73), gemColor)
end

-- Самурайский кабуто: купол, наплечная юбка-сикоро, маска, рога-кувагата
local function kabuto(r, color, edge, horn, mask)
	local H = r.Head
	Kit.bevel(r, H, V(1.38, 0.62, 1.42), CF(0, 0.5, 0.02), color, edge)
	for i = 0, 1 do
		Kit.bevel(r, H, V(1.62 + i * 0.2, 0.26, 0.26), CF(0, 0.05 - i * 0.26, 0.74 + i * 0.08) * ANG(rad(25), 0, 0), color, edge)
		for _, s in ipairs({ -1, 1 }) do
			Kit.bevel(r, H, V(0.26, 0.26, 1.2 + i * 0.15), CF(s * (0.78 + i * 0.08), 0.05 - i * 0.26, 0.12) * ANG(0, 0, rad(-25 * s)), color, edge)
		end
	end
	r:Box(H, V(0.96, 0.46, 0.08), CF(0, -0.3, -0.63), mask, M.Metal)
	r:Neon(H, V(0.46, 0.05, 0.05), CF(0, -0.36, -0.68), horn)
	for _, s in ipairs({ -1, 1 }) do
		Kit.hornA(r, H, { V(0.2 * s, 0.6, -0.7), V(0.45 * s, 0.95, -0.85), V(0.7 * s, 1.45, -0.8), V(0.75 * s, 1.85, -0.65) }, 0.14, horn, M.Metal)
	end
	eyes(r, horn, true, 0.12)
end

-- Простой наплечник-плита
local function plateShoulders(r, color, edge, s)
	s = s or 1
	for _, side in ipairs({ 1, -1 }) do
		local A = side == 1 and r.RArm or r.LArm
		Kit.bevel(r, A, V(1.3, 0.5, 1.25) * s, CF(0.12 * side, 0.9, 0) * ANG(0, 0, rad(-12 * side)), color, edge)
	end
end

-- Наплечники-ступени (из ModelKit)
local function bigShoulders(r, color, edge, glow, size, spikes)
	Kit.pauldron(r, r.RArm, 1, size or 1, color, edge, glow, spikes or 1)
	Kit.pauldron(r, r.LArm, -1, size or 1, color, edge, glow, spikes or 1)
end

-- Латные наручи и поножи
local function bracers(r, color, edge)
	for _, A in ipairs({ r.RArm, r.LArm }) do
		Kit.bevel(r, A, V(1.14, 0.75, 1.14), CF(0, -0.55, 0), color, edge)
	end
end

local function greaves(r, color, edge, boots)
	for _, L in ipairs({ r.RLeg, r.LLeg }) do
		Kit.bevel(r, L, V(1.12, 0.7, 1.14), CF(0, -0.35, 0), color, edge)
		if boots then
			Kit.bootA(r, L, color, edge, 1.12)
		end
	end
end

-- Крылья из перьев-пластин на моторах WingR/WingL
local function wings(r, color, edge, glow, span)
	span = span or 1
	for _, side in ipairs({ 1, -1 }) do
		local w = r:Joint(side == 1 and "WingR" or "WingL", r.Torso, V(0.3, 0.3, 0.3), CF(0.45 * side, 0.6, 0.6), CF(), color)
		w.Transparency = 1
		local lens = { 2.8, 2.5, 2.1, 1.7, 1.3 }
		for i, L in ipairs(lens) do
			local th = rad(28 + (i - 1) * 24)
			L = L * span
			local c = V(side * math.sin(th) * L / 2, math.cos(th) * L / 2, 0.15 + i * 0.03)
			Kit.bevel(r, w, V(0.5, L, 0.16), CF(c) * ANG(0, 0, -side * th), color, edge, M.Plastic)
			if glow and i <= 2 then
				r:Neon(w, V(0.08, L * 0.8, 0.18), CF(c) * ANG(0, 0, -side * th) * CF(0.2 * side, 0, 0), glow)
			end
		end
	end
end

------------------------------------------------------------------------
-- ОРУЖИЕ (правая рука: клинок вперёд по -Z; древковое — вертикально перед кулаком)
------------------------------------------------------------------------
local function muzzle(r, limb, cf)
	local m = r:Box(limb, V(0.2, 0.2, 0.2), cf, P.Black, M.Plastic, { Transparency = 1, Name = "Muzzle" })
	r.Muzzle = m
	return m
end

local function blade(r, A, o)
	local y = o.Y or GRIP
	local len, w = o.Len or 3, o.W or 0.5
	local z0 = -0.56
	r:Box(A, V(0.22, 0.22, 0.85), CF(0, y, 0.1), o.Grip or AC.ClothDark, M.Fabric)
	r:Box(A, V(0.3, 0.3, 0.25), CF(0, y, 0.6) * ANG(0, 0, rad(45)), o.Guard or AC.Armor, M.Metal)
	Kit.bevel(r, A, V(0.28, o.GuardW or (w + 0.7), 0.28), CF(0, y, -0.42), o.Guard or AC.Armor, o.Edge)
	r:Box(A, V(0.12, w, len), CF(0, y, z0 - len / 2), o.Blade or AC.ArmorMid, M.Metal)
	if o.Glow then
		r:Neon(A, V(0.14, 0.07, len * 0.96), CF(0, y + w / 2 - 0.03, z0 - len / 2), o.Glow)
		r:Neon(A, V(0.14, 0.07, len * 0.96), CF(0, y - w / 2 + 0.03, z0 - len / 2), o.Glow)
	end
	if o.Core then
		r:Neon(A, V(0.14, 0.08, len * 0.7), CF(0, y, z0 - len * 0.42), o.Core)
	end
	Kit.spike(r, A, V(0, y, z0 - len + 0.02), V(0, y, z0 - len - w * 1.2), w, o.Blade or AC.ArmorMid, M.Metal, true, 0.12)
	r:WeaponTrail(A, V(0, y, z0 - 0.15), V(0, y, z0 - len - w), o.Trail or o.Glow or P.NeonSoft)
	return muzzle(r, A, CF(0, y, z0 - len - w))
end

-- Вертикальное древко перед кулаком
local function shaft(r, A, bottom, top, color, d)
	d = d or 0.2
	r:Box(A, V(d, top - bottom, d), CF(0, (top + bottom) / 2, -0.5), color or rgb(44, 32, 30), M.Wood)
	return V(0, top, -0.5)
end

local function staff(r, A, o)
	local top = shaft(r, A, -2.5, o.Top or 2.4, o.Wood, 0.2)
	local c = top + V(0, 0.45, 0)
	for k = 0, 3 do
		local a = k / 4 * PI * 2 + PI / 4
		Kit.spike(r, A, top + V(math.cos(a) * 0.15, -0.1, math.sin(a) * 0.15), c + V(math.cos(a) * 0.35, 0.35, math.sin(a) * 0.35), 0.16, o.Prong or AC.Armor, M.Metal, true, 0.08)
	end
	local g = r:Neon(A, V(0.45, 0.45, 0.45), CF(c) * ANG(rad(45), 0, rad(45)), o.Glow)
	if o.Big then
		r:Box(A, V(0.7, 0.7, 0.7), CF(c) * ANG(rad(45), 0, rad(45)), o.Glow, M.Glass, { Transparency = 0.6 })
	end
	muzzle(r, A, CF(c))
	return g
end

local function scythe(r, A, o)
	local top = shaft(r, A, -2.6, 2.6, o.Wood, 0.2)
	local pts = { top + V(0, -0.05, 0.1), top + V(0, 0.25, -0.8), top + V(0, 0.05, -1.7), top + V(0, -0.4, -2.4) }
	for i = 1, #pts - 1 do
		Kit.bar(r, A, pts[i], pts[i + 1], V2(0.12, 0.42 - i * 0.07), o.Blade or AC.ArmorMid)
		if o.Glow then
			Kit.bar(r, A, pts[i] + V(0, -0.2 + i * 0.03, 0), pts[i + 1] + V(0, -0.17 + i * 0.03, 0), V2(0.14, 0.06), o.Glow, M.Neon)
		end
	end
	Kit.spike(r, A, pts[4], pts[4] + V(0, -0.55, -0.4), 0.26, o.Blade or AC.ArmorMid, M.Metal, true, 0.12)
	r:WeaponTrail(A, top + V(0, 0, -0.8), pts[4], o.Glow or P.NeonSoft)
	return muzzle(r, A, CF(pts[4]))
end

local function spear(r, A, o)
	local top = shaft(r, A, -2.4, o.Top or 2.6, o.Wood, 0.2)
	Kit.bevel(r, A, V(0.34, 0.3, 0.34), CF(top), o.Metal or AC.Armor, o.Edge)
	Kit.spike(r, A, top + V(0, 0.1, 0), top + V(0, 1.1, 0), 0.5, o.Head or AC.ArmorMid, M.Metal)
	if o.Glow then
		r:Neon(A, V(0.08, 0.6, 0.08), CF(top + V(0, 0.45, -0.13)), o.Glow)
	end
	if o.Axe then
		Kit.bevel(r, A, V(0.12, 0.8, 0.7), CF(top + V(0, -0.2, -0.45)), o.Head or AC.ArmorMid, o.Edge)
		Kit.spike(r, A, top + V(0, -0.2, -0.75), top + V(0, -0.2, -1.2), 0.8, o.Head or AC.ArmorMid, M.Metal, true, 0.12)
	end
	if o.Wing then
		for _, s in ipairs({ -1, 1 }) do
			Kit.spike(r, A, top + V(0.1 * s, 0, 0), top + V(0.55 * s, 0.35, 0), 0.22, o.Metal or AC.Armor, M.Metal, true, 0.08)
		end
	end
	r:WeaponTrail(A, top, top + V(0, 1.1, 0), o.Glow or P.NeonSoft)
	return muzzle(r, A, CF(top + V(0, 1.1, 0)))
end

local function hammer(r, A, o)
	local top = shaft(r, A, -2.2, 2.0, o.Wood or AC.Armor, 0.24)
	local c = top + V(0, 0.35, 0)
	Kit.bevel(r, A, V(0.95, 0.95, 1.8), CF(c), o.Head, o.Edge)
	for _, z in ipairs({ -0.65, 0.65 }) do
		Kit.bevel(r, A, V(1.05, 1.05, 0.18), CF(c + V(0, 0, z)), o.Trim or o.Edge, false)
	end
	Kit.gem(r, A, 0.45, CF(c + V(-0.49, 0, 0)) * ANG(0, PI / 2, 0), o.Glow)
	Kit.gem(r, A, 0.45, CF(c + V(0.49, 0, 0)) * ANG(0, -PI / 2, 0), o.Glow)
	Kit.spike(r, A, c + V(0, 0.45, 0), c + V(0, 1.0, 0), 0.4, o.Trim or o.Head, M.Metal)
	r:WeaponTrail(A, top, c + V(0, 0, -0.9), o.Glow)
	return muzzle(r, A, CF(c))
end

local function axe(r, A, o)
	local top = shaft(r, A, -2.2, 2.2, o.Wood, 0.22)
	Kit.bevel(r, A, V(0.14, 1.3, 1.0), CF(top + V(0, -0.35, -0.55)), o.Head, o.Edge)
	Kit.spike(r, A, top + V(0, -0.35, -1.0), top + V(0, -0.35, -1.6), 1.5, o.Head, M.Metal, true, 0.14)
	if o.Glow then
		r:Neon(A, V(0.16, 1.4, 0.08), CF(top + V(0, -0.35, -1.08)), o.Glow)
	end
	Kit.spike(r, A, top, top + V(0, 0.6, 0), 0.3, o.Head, M.Metal)
	r:WeaponTrail(A, top + V(0, -0.35, -0.8), top + V(0, -0.35, -1.6), o.Glow or P.NeonSoft)
	return muzzle(r, A, CF(top + V(0, -0.35, -1.5)))
end

-- Лук в левой руке (вертикально, тетива к стрелку)
local function bow(r, A, o)
	local y = GRIP
	local g = V(0, y, -0.45)
	r:Box(A, V(0.2, 0.5, 0.2), CF(g), o.Grip or AC.ClothDark, M.Fabric)
	local tips = {}
	for _, s in ipairs({ 1, -1 }) do
		local m = g + V(0, 0.9 * s, -0.2)
		local t = g + V(0, 1.75 * s, 0.25)
		Kit.bar(r, A, g, m, V2(0.14, 0.2), o.Wood)
		Kit.bar(r, A, m, t, V2(0.12, 0.16), o.Wood)
		if o.Glow then
			Kit.bar(r, A, g + V(0, 0.1 * s, -0.08), m + V(0, 0, -0.08), V2(0.15, 0.05), o.Glow, M.Neon)
		end
		Kit.spike(r, A, t, t + V(0, 0.3 * s, 0.15), 0.16, o.Tip or o.Wood, M.Metal, true, 0.08)
		tips[#tips + 1] = t
	end
	r:Box(A, V(0.04, (tips[1] - tips[2]).Magnitude, 0.04), CF((tips[1] + tips[2]) / 2), o.String or rgb(220, 210, 230), M.Plastic)
	return muzzle(r, A, CF(g + V(0, 0, -0.2)))
end

local function quiver(r, color, tips)
	Kit.bevel(r, r.Torso, V(0.5, 1.6, 0.5), CF(0.45, 0.2, 0.75) * ANG(0, 0, rad(-25)), color, false, M.Fabric)
	for k = -1, 1 do
		Kit.spike(r, r.Torso, V(0.75 + k * 0.1, 1.05, 0.75 + k * 0.08), V(0.95 + k * 0.1, 1.45, 0.75 + k * 0.08), 0.18, tips, M.Plastic, true, 0.05)
	end
end

-- Оружие для вытянутых вперёд рук: строится вдоль руки (локальная -Y), ствол смотрит вперёд,
-- когда рука поднята (idle RS ~75°). F переводит «вперёд» оружия в «вниз» руки.
local AIM = CF(0, GRIP, 0) * ANG(rad(-90), 0, 0)

local function crossbow(r, A, o)
	local F = AIM
	Kit.bevel(r, A, V(0.32, 0.32, 1.9), F * CF(0, 0, -0.75), o.Stock, o.Edge)
	local f = -1.55
	for _, s in ipairs({ -1, 1 }) do
		Kit.bar(r, A, F * V(0, 0.05, f), F * V(0.6 * s, 0.05, f + 0.15), V2(0.18, 0.14), o.Prong)
		Kit.bar(r, A, F * V(0.6 * s, 0.05, f + 0.15), F * V(1.1 * s, 0.05, f + 0.4), V2(0.14, 0.12), o.Prong)
		Kit.spike(r, A, F * V(1.1 * s, 0.05, f + 0.4), F * V(1.35 * s, 0.05, f + 0.25), 0.2, o.Glow, M.Neon, true, 0.08)
	end
	r:Box(A, V(2.2, 0.03, 0.03), F * CF(0, 0.05, f + 0.4), rgb(200, 220, 255), M.Plastic)
	r:Neon(A, V(0.1, 0.1, 1.2), F * CF(0, 0.22, -1.1), o.Glow)
	Kit.spike(r, A, F * V(0, 0.22, -1.7), F * V(0, 0.22, -2.1), 0.22, o.Glow, M.Neon)
	return muzzle(r, A, F * CF(0, 0.22, -2.1))
end

local function rifle(r, A, o)
	local F = AIM
	Kit.bevel(r, A, V(0.42, 0.55, 1.9), F * CF(0, 0.05, -0.75), o.Body, o.Edge)
	Kit.bevel(r, A, V(0.32, 0.5, 0.75), F * CF(0, -0.05, 0.45), o.Body, o.Edge)
	r:Box(A, V(0.24, 0.24, 1.5), F * CF(0, 0.15, -2.4), o.Barrel or AC.ArmorMid, M.Metal)
	Kit.bevel(r, A, V(0.2, 0.2, 0.8), F * CF(0, 0.45, -0.7), o.Body, o.Edge)
	r:Neon(A, V(0.08, 0.08, 0.08), F * CF(0, 0.45, -1.12), o.Glow)
	for k = 0, 2 do
		r:Neon(A, V(0.32, 0.32, 0.08), F * CF(0, 0.15, -1.9 - k * 0.38), o.Glow)
	end
	r:Box(A, V(0.3, 0.6, 0.2), F * CF(0, -0.45, -0.6), o.Body, M.Metal)
	return muzzle(r, A, F * CF(0, 0.15, -3.2))
end

local function dagger(r, A, glow, len, color)
	return blade(r, A, { Len = len or 1.2, W = 0.32, GuardW = 0.7, Blade = color or AC.ArmorMid, Glow = glow, Guard = AC.Armor })
end

local function shield(r, A, o)
	local x = -0.68
	Kit.bevel(r, A, V(0.24, o.H or 2.0, o.W or 1.4), CF(x, -0.5, -0.1), o.Color, o.Edge)
	Kit.spike(r, A, V(x, -0.5 - (o.H or 2.0) / 2 + 0.02, -0.1), V(x, -0.5 - (o.H or 2.0) / 2 - 0.6, -0.1), o.W or 1.4, o.Color, M.Metal, true, 0.24)
	if o.Rim then
		r:Box(A, V(0.26, (o.H or 2.0) * 0.8, 0.12), CF(x - 0.01, -0.5, -0.1), o.Rim, M.Metal)
		r:Box(A, V(0.26, 0.12, (o.W or 1.4) * 0.8), CF(x - 0.01, -0.3, -0.1), o.Rim, M.Metal)
	end
	if o.Gem then
		Kit.gem(r, A, 0.45, CF(x - 0.14, -0.3, -0.1) * ANG(0, PI / 2, 0), o.Gem, o.Edge)
	end
end

-- Плащ с эмблемой
local function capeWith(r, w, len, color, emblem)
	local cape = r:Cape(w, len, color, true)
	if emblem then
		Kit.gem(r, cape, 0.5, CF(0, 0.1, 0.08) * ANG(0, PI, 0), emblem)
	end
	return cape
end

------------------------------------------------------------------------
-- VOID CASE
------------------------------------------------------------------------
local VOID = P.Neon

local function VoidSoldier(lv)
	local r = figure("VoidSoldier", { Torso = AC.Armor, Arm = AC.Armor, Leg = rgb(28, 26, 34), Edge = AC.Edge })
	chest(r, AC.ArmorMid, AC.Edge, lv >= 3 and VOID or nil)
	belt(r, rgb(40, 30, 38), AC.Edge, lv >= 2 and VOID or nil)
	tassets(r, AC.ArmorMid, AC.Edge)
	helm(r, AC.Armor, AC.Edge, VOID, lv >= 3 and AC.Armor or nil)
	if lv >= 2 then
		plateShoulders(r, AC.ArmorMid, AC.Edge, lv >= 4 and 1.15 or 1)
	end
	bracers(r, AC.ArmorMid, AC.Edge)
	greaves(r, AC.ArmorMid, AC.Edge, true)
	blade(r, r.RArm, { Len = 2.6 + (lv >= 4 and 0.4 or 0), W = 0.45, Blade = lv >= 5 and AC.Cloth or AC.ArmorMid, Glow = lv >= 3 and VOID or nil, Edge = AC.Edge })
	shield(r, r.LArm, { Color = lv >= 3 and AC.Cloth or AC.ArmorMid, Edge = AC.Edge, H = lv >= 3 and 2.2 or 1.7, W = lv >= 3 and 1.5 or 1.25, Rim = lv >= 2 and AC.Edge or nil, Gem = lv >= 3 and VOID or nil })
	if lv >= 4 then
		r:Box(r.Torso, V(0.9, 1.1, 0.06), CF(0, -1.5, -0.6), AC.Cloth, M.Fabric)
		Kit.tatter(r, r.Torso, -2.05, -0.6, 0.9, 3, AC.Cloth, M.Fabric, 2)
	end
	if lv >= 5 then
		for _, s in ipairs({ -1, 1 }) do
			Kit.hornA(r, r.Head, { V(0.6 * s, 0.35, 0), V(0.9 * s, 0.6, 0.05), V(0.95 * s, 1.1, -0.05) }, 0.2, AC.Armor, M.Metal)
		end
		capeWith(r, 1.9, 2.8, AC.ClothDark, VOID)
	end
	levelAura(r, lv)
	return r:Finish(1, { RS = { 15, 0, 0 } })
end

local function ShadowArcher(lv)
	local r = figure("ShadowArcher", { Torso = rgb(30, 26, 36), Arm = rgb(30, 26, 36), Leg = rgb(24, 22, 30), Edge = rgb(90, 84, 104) })
	hood(r, AC.ClothDark, AC.Edge, VOID)
	Kit.bevel(r, r.Torso, V(2.12, 1.2, 1.12), CF(0, 0.35, 0), rgb(40, 32, 44), AC.Edge, M.Fabric)
	Kit.bar(r, r.Torso, V(-0.9, 0.95, -0.58), V(0.9, -0.6, -0.58), V2(0.2, 0.06), rgb(70, 50, 40))
	belt(r, rgb(50, 36, 30), AC.Edge)
	quiver(r, rgb(50, 36, 30), lv >= 3 and VOID or AC.Edge)
	if lv >= 2 then
		Kit.bevel(r, r.LArm, V(1.2, 0.5, 1.2), CF(-0.1, 0.9, 0) * ANG(0, 0, rad(12)), AC.ArmorMid, AC.Edge)
	end
	bracers(r, rgb(50, 36, 30), AC.Edge)
	greaves(r, rgb(34, 30, 40), AC.Edge, true)
	bow(r, r.LArm, { Wood = lv >= 4 and AC.Armor or rgb(56, 40, 34), Glow = lv >= 3 and VOID or nil, Tip = AC.Edge })
	if lv >= 4 then
		capeWith(r, 1.9, 3.0, AC.ClothDark, nil)
	end
	if lv >= 5 then
		r:Box(r.Head, V(1.06, 0.4, 0.08), CF(0, -0.3, -0.64), AC.Armor, M.Metal)
		mantle(r, AC.Cloth, AC.Edge)
	end
	levelAura(r, lv)
	return r:Finish(1, { LS = { 20, 0, 0 } })
end

local function LostMage(lv)
	local r = figure("LostMage", { Torso = AC.ClothDark, Arm = AC.ClothDark, Leg = AC.ClothDark, Skin = rgb(64, 56, 72), Edge = AC.Edge })
	r:Box(r.Head, V(1.04, 1.0, 0.05), CF(0, -0.05, -0.61), rgb(14, 10, 20), M.Plastic)
	eyes(r, VOID, true, 0.05)
	wizardHat(r, lv >= 4 and AC.Cloth or AC.ClothDark, lv >= 3 and rgb(150, 110, 60) or rgb(60, 44, 70), AC.Edge)
	robe(r, AC.ClothDark, lv >= 2 and AC.Cloth or nil, 1.8)
	belt(r, rgb(50, 36, 30), AC.Edge, lv >= 3 and VOID or nil)
	if lv >= 2 then
		mantle(r, AC.Cloth, AC.Edge)
	end
	-- книга на поясе
	Kit.bevel(r, r.Torso, V(0.2, 0.6, 0.5), CF(-1.08, -0.9, -0.1), rgb(70, 40, 30), AC.Edge)
	staff(r, r.RArm, { Glow = VOID, Top = 2.2 + (lv >= 4 and 0.4 or 0), Big = lv >= 4 })
	if lv >= 5 then
		r:Orbit("OrbitStaff", r.Torso, CF(0, 0.4, 0), 2.0, 4, 0.3, P.NeonSoft)
		capeWith(r, 1.9, 2.8, AC.Cloth, VOID)
	end
	levelAura(r, lv)
	return r:Finish(1, { RS = { 10, 0, 0 }, LS = { 8, 0, 0 } })
end

local function DarkGunner(lv)
	local r = figure("DarkGunner", { Torso = rgb(30, 28, 36), Arm = rgb(30, 28, 36), Leg = rgb(26, 24, 30), Edge = rgb(96, 92, 112) })
	-- шлем-кепи с очками
	Kit.bevel(r, r.Head, V(1.3, 0.55, 1.32), CF(0, 0.42, 0.02), AC.ArmorMid, AC.Edge)
	Kit.bevel(r, r.Head, V(1.32, 0.12, 0.5), CF(0, 0.2, -0.82), AC.ArmorMid, AC.Edge)
	r:Box(r.Head, V(1.2, 0.28, 0.08), CF(0, 0.06, -0.62), rgb(14, 10, 20), M.Plastic)
	for _, s in ipairs({ -1, 1 }) do
		r:Neon(r.Head, V(0.34, 0.18, 0.06), CF(0.27 * s, 0.06, -0.66), VOID)
	end
	r:Box(r.Head, V(1.1, 0.4, 0.08), CF(0, -0.32, -0.62), AC.Armor, M.Metal)
	-- бронежилет, подсумки, полы плаща
	chest(r, AC.ArmorMid, AC.Edge, lv >= 3 and VOID or nil)
	for k = -1, 1, 2 do
		Kit.bevel(r, r.Torso, V(0.42, 0.4, 0.2), CF(0.6 * k, -0.35, -0.6), rgb(50, 40, 36), false, M.Fabric)
	end
	belt(r, rgb(46, 36, 32), AC.Edge)
	for _, s in ipairs({ -1, 1 }) do
		Kit.bevel(r, r.Torso, V(0.95, 1.4, 0.18), CF(0.55 * s, -1.55, 0.45), AC.ClothDark, false, M.Fabric)
	end
	if lv >= 2 then
		plateShoulders(r, AC.ArmorMid, AC.Edge)
	end
	bracers(r, AC.ArmorMid, AC.Edge)
	greaves(r, rgb(40, 36, 46), AC.Edge, true)
	rifle(r, r.RArm, { Body = lv >= 4 and AC.Cloth or AC.ArmorMid, Edge = AC.Edge, Glow = VOID, Barrel = AC.Armor })
	if lv >= 4 then
		Kit.bevel(r, r.Torso, V(1.4, 1.3, 0.5), CF(0, 0.2, 0.78), AC.ArmorMid, AC.Edge)
		r:Neon(r.Torso, V(0.9, 0.12, 0.06), CF(0, 0.5, 1.04), VOID)
	end
	if lv >= 5 then
		capeWith(r, 1.8, 2.6, AC.ClothDark, VOID)
	end
	levelAura(r, lv)
	return r:Finish(1.05, { RS = { 75, 0, 0 }, LS = { 70, 0, -25 }, Neck = { 0, 0, 0 } })
end

local function AbyssReaper(lv)
	local cloth = rgb(26, 20, 32)
	local r = figure("AbyssReaper", { Torso = cloth, Arm = cloth, Leg = cloth, Skin = rgb(200, 190, 175), Edge = rgb(80, 70, 96) })
	hood(r, cloth, rgb(80, 70, 96), VOID, true)
	-- костяная маска-череп
	r:Box(r.Head, V(0.9, 0.85, 0.06), CF(0, -0.05, -0.63), rgb(200, 190, 175), M.Plastic)
	for _, s in ipairs({ -1, 1 }) do
		r:Box(r.Head, V(0.24, 0.22, 0.04), CF(0.2 * s, 0.07, -0.66), rgb(10, 8, 14))
		r:Neon(r.Head, V(0.1, 0.1, 0.04), CF(0.2 * s, 0.07, -0.68), VOID)
	end
	for k = -1, 1 do
		r:Box(r.Head, V(0.08, 0.16, 0.04), CF(k * 0.14, -0.35, -0.66), rgb(10, 8, 14))
	end
	robe(r, cloth, rgb(80, 70, 96), 2.0)
	mantle(r, rgb(36, 28, 44), rgb(80, 70, 96))
	belt(r, rgb(40, 30, 38), AC.Edge, VOID)
	if lv >= 2 then
		for _, side in ipairs({ 1, -1 }) do
			local A = side == 1 and r.RArm or r.LArm
			Kit.bevel(r, A, V(1.25, 0.45, 1.2), CF(0.15 * side, 1.12, 0) * ANG(0, 0, rad(-14 * side)), rgb(200, 190, 175), rgb(120, 110, 100), M.Plastic)
			Kit.spike(r, A, V(0.4 * side, 1.3, 0), V(0.8 * side, 1.85, 0), 0.3, rgb(200, 190, 175), M.Plastic, true, 0.1)
		end
	end
	if lv >= 3 then
		Kit.chain(r, r.Torso, 4, 0.26, nil, CF(0.7, -1.0, -0.6))
	end
	scythe(r, r.RArm, { Blade = lv >= 5 and AC.Cloth or AC.ArmorMid, Glow = lv >= 3 and VOID or nil, Wood = rgb(36, 28, 32) })
	if lv >= 4 then
		capeWith(r, 2.0, 3.4, cloth, nil)
	end
	if lv >= 5 then
		r:Orbit("OrbitSouls", r.Torso, CF(0, 0.6, 0), 2.3, 4, 0.32, P.NeonSoft, M.Neon, 0.25)
	end
	levelAura(r, lv)
	return r:Finish(1.15, { RS = { 8, 0, 0 } })
end

local function CorruptedSamurai(lv)
	local red, black, gold = rgb(130, 22, 30), rgb(26, 20, 24), rgb(190, 150, 70)
	local edge = rgb(150, 110, 110)
	local r = figure("CorruptedSamurai", { Torso = black, Arm = black, Leg = black, Edge = edge })
	kabuto(r, black, edge, lv >= 3 and gold or rgb(150, 120, 80), red)
	-- до: пластины-ламели
	for i = 0, 2 do
		Kit.bevel(r, r.Torso, V(2.14, 0.34, 1.16), CF(0, 0.75 - i * 0.36, 0), i % 2 == 0 and red or black, edge)
	end
	belt(r, rgb(60, 30, 30), gold)
	-- кусадзури: юбка из пластин
	for i, x in ipairs({ -0.62, 0, 0.62 }) do
		for k = 0, 1 do
			Kit.bevel(r, r.Torso, V(0.62, 0.36, 0.18), CF(x, -1.2 - k * 0.36, -0.58 - k * 0.04) * ANG(rad(-6), 0, 0), (i + k) % 2 == 0 and red or black, edge)
		end
	end
	-- содэ: наплечники из пластин
	for _, side in ipairs({ 1, -1 }) do
		local A = side == 1 and r.RArm or r.LArm
		for k = 0, lv >= 2 and 2 or 1 do
			Kit.bevel(r, A, V(0.25, 0.38, 1.3), CF(0.62 * side, 0.82 - k * 0.38, 0) * ANG(0, 0, rad(-12 * side)), k % 2 == 0 and red or black, edge)
		end
	end
	bracers(r, red, edge)
	greaves(r, black, edge, true)
	-- катана и ножны
	blade(r, r.RArm, { Len = 3.4 + (lv >= 4 and 0.4 or 0), W = 0.24, GuardW = 0.55, Blade = rgb(180, 180, 195), Glow = lv >= 3 and rgb(255, 50, 60) or nil, Guard = gold, Grip = red })
	Kit.bevel(r, r.Torso, V(0.2, 0.22, 2.6), CF(-0.9, -0.85, -0.2) * ANG(rad(-20), rad(10), 0), black, edge)
	if lv >= 4 then
		capeWith(r, 1.9, 3.0, red, nil)
	end
	if lv >= 5 then
		Kit.crack(r, r.Torso, { V(-0.8, 0.95, -0.59), V(-0.4, 0.5, -0.59), V(-0.6, 0.1, -0.59) }, 0.06, rgb(255, 50, 60))
	end
	levelAura(r, lv, rgb(255, 50, 60))
	return r:Finish(1.1, { RS = { 25, 0, 0 }, LS = { 10, 0, 0 } })
end

local function EclipseGuardian(lv)
	local gold, goldD, white, black = rgb(200, 158, 70), rgb(140, 104, 44), rgb(220, 214, 226), rgb(30, 26, 34)
	local edge = rgb(250, 225, 160)
	local r = figure("EclipseGuardian", { Torso = black, Arm = gold, Leg = black, Edge = edge })
	helm(r, gold, edge, rgb(255, 220, 140), nil, true)
	for _, s in ipairs({ -1, 1 }) do
		-- крылья на шлеме
		for k = 0, 2 do
			Kit.bevel(r, r.Head, V(0.12, 0.7 - k * 0.15, 0.22), CF(0.72 * s, 0.4 + k * 0.25, 0.1 + k * 0.15) * ANG(rad(-30 - k * 10), 0, rad(-20 * s)), gold, edge)
		end
	end
	chest(r, gold, edge, nil)
	-- эмблема затмения: тёмный ромб в золотой оправе
	Kit.gem(r, r.Torso, 0.55, CF(0, 0.5, -0.62), black, gold)
	r:Neon(r.Torso, V(0.15, 0.15, 0.06), CF(0, 0.5, -0.72) * ANG(0, 0, rad(45)), rgb(255, 220, 140))
	belt(r, goldD, gold)
	-- белый табард
	r:Box(r.Torso, V(1.0, 1.5, 0.06), CF(0, -1.6, -0.6), white, M.Fabric)
	Kit.tatter(r, r.Torso, -2.35, -0.6, 1.0, 3, white, M.Fabric, 4)
	bigShoulders(r, gold, edge, lv >= 3 and rgb(255, 220, 140) or nil, lv >= 4 and 1.15 or 1, lv >= 5 and 2 or 1)
	bracers(r, goldD, edge)
	greaves(r, gold, edge, true)
	spear(r, r.RArm, { Top = 2.8, Head = gold, Metal = goldD, Edge = edge, Glow = lv >= 3 and rgb(255, 220, 140) or nil, Axe = lv >= 2, Wing = lv >= 4, Wood = black })
	if lv >= 4 then
		capeWith(r, 2.1, 3.4, white, gold)
	end
	levelAura(r, lv, rgb(255, 210, 110))
	return r:Finish(1.3, { RS = { 30, 0, 0 } })
end

local function FallenAngel(lv)
	local silver, white, edge = rgb(170, 168, 186), rgb(232, 228, 238), rgb(255, 255, 255)
	local r = figure("FallenAngel", { Torso = silver, Arm = silver, Leg = rgb(60, 56, 72), Skin = rgb(226, 214, 208), Edge = edge })
	-- лицо и белые волосы
	eyes(r, VOID, true, 0.06)
	Kit.bevel(r, r.Head, V(1.32, 0.35, 1.34), CF(0, 0.62, 0.02), white, false, M.Plastic)
	Kit.bevel(r, r.Head, V(1.32, 1.1, 0.3), CF(0, 0.1, 0.55), white, false, M.Plastic)
	for _, s in ipairs({ -1, 1 }) do
		Kit.bevel(r, r.Head, V(0.18, 1.0, 0.9), CF(0.62 * s, 0.1, 0.2), white, false, M.Plastic)
		Kit.spike(r, r.Head, V(0.5 * s, -0.4, 0.5), V(0.6 * s, -1.2, 0.65), 0.35, white, M.Plastic, true, 0.12)
	end
	chest(r, white, edge, VOID)
	belt(r, rgb(70, 60, 90), edge, VOID)
	robe(r, rgb(60, 50, 84), white, 1.6)
	bigShoulders(r, white, edge, lv >= 3 and VOID or nil, lv >= 4 and 1.1 or 1, 1)
	bracers(r, white, edge)
	wings(r, lv >= 5 and rgb(200, 190, 230) or white, edge, lv >= 3 and VOID or nil, 0.9 + lv * 0.06)
	staff(r, r.RArm, { Glow = VOID, Prong = white, Wood = silver, Top = 2.6, Big = lv >= 4 })
	if lv >= 5 then
		-- сломанный нимб
		r:Orbit("OrbitHalo", r.Head, CF(0, 1.1, 0.1), 0.85, 6, 0.2, rgb(240, 230, 255))
	end
	levelAura(r, lv)
	return r:Finish(1.25, { RS = { 10, 0, 0 } })
end

local function VoidEmperor(lv)
	local royal, gold, black = rgb(66, 30, 110), rgb(196, 150, 64), rgb(26, 22, 34)
	local edge = rgb(150, 120, 200)
	local r = figure("VoidEmperor", { Torso = black, Arm = royal, Leg = black, Skin = rgb(54, 48, 64), Edge = edge })
	r:Box(r.Head, V(1.04, 0.9, 0.05), CF(0, -0.05, -0.61), rgb(12, 9, 18), M.Plastic)
	eyes(r, VOID, true, 0.04)
	crown(r, gold, VOID, 0.8 + lv * 0.08)
	chest(r, royal, gold, VOID)
	belt(r, rgb(50, 36, 30), gold, VOID)
	robe(r, royal, gold, 1.9)
	bigShoulders(r, black, gold, VOID, 1.1 + (lv >= 4 and 0.1 or 0), lv >= 3 and 2 or 1)
	bracers(r, black, gold)
	capeWith(r, 2.4, 4.0, royal, gold)
	-- скипетр
	staff(r, r.RArm, { Glow = VOID, Prong = gold, Wood = gold, Top = 2.6, Big = true })
	if lv >= 4 then
		r:Orbit("OrbitCrown", r.Head, CF(0, 1.5, 0), 1.4, 5, 0.26, P.NeonSoft)
	end
	levelAura(r, lv)
	return r:Finish(1.4, { RS = { 15, 0, 0 } })
end

local function AbyssOverlord(lv)
	local black, mid, edge = rgb(26, 22, 32), rgb(44, 38, 56), rgb(130, 110, 160)
	local r = figure("AbyssOverlord", { Torso = black, Arm = black, Leg = black, Edge = edge })
	helm(r, black, edge, VOID, nil, true)
	for _, s in ipairs({ -1, 1 }) do
		Kit.hornA(r, r.Head, { V(0.62 * s, 0.35, 0), V(1.1 * s, 0.6, 0.05), V(1.3 * s, 1.2, 0), V(1.1 * s, 1.9 + lv * 0.1, -0.15) }, 0.3, mid, M.Metal)
	end
	chest(r, mid, edge, VOID)
	Kit.crack(r, r.Torso, { V(-0.85, 0.95, -0.59), V(-0.45, 0.45, -0.6), V(-0.7, -0.05, -0.59) }, 0.06)
	Kit.crack(r, r.Torso, { V(0.7, 0.9, -0.59), V(0.85, 0.35, -0.59) }, 0.05)
	belt(r, black, edge, VOID)
	tassets(r, mid, edge)
	bigShoulders(r, black, edge, VOID, 1.2 + (lv >= 4 and 0.1 or 0), lv >= 3 and 3 or 2)
	bracers(r, mid, edge)
	greaves(r, mid, edge, true)
	blade(r, r.RArm, { Len = 4.2 + lv * 0.15, W = 0.85, GuardW = 1.8, Blade = black, Glow = VOID, Core = lv >= 3 and P.NeonSoft or nil, Guard = mid, Edge = edge })
	capeWith(r, 2.3, 3.6, rgb(40, 18, 64), VOID)
	if lv >= 4 then
		r:Orbit("OrbitRocks", r.Torso, CF(0, 0.3, 0), 3.0, lv >= 5 and 6 or 4, 0.5, mid, M.Slate)
	end
	levelAura(r, lv)
	return r:Finish(1.55, { RS = { 12, 0, 8 }, LS = { 12, 0, -8 } })
end

------------------------------------------------------------------------
-- SHATTERED REALITY CASE
------------------------------------------------------------------------
local BLUE, BLUE_SOFT = rgb(90, 150, 255), rgb(170, 210, 255)
local NAVY, NAVY_D = rgb(30, 40, 84), rgb(18, 22, 46)
local SH_EDGE = rgb(110, 130, 176)

local function RiftScout(lv)
	local r = figure("RiftScout", { Torso = NAVY_D, Arm = NAVY_D, Leg = rgb(22, 24, 36), Edge = SH_EDGE })
	hood(r, NAVY, SH_EDGE, BLUE)
	-- шарф
	Kit.bevel(r, r.Torso, V(1.6, 0.35, 1.2), CF(0, 0.92, 0), BLUE:Lerp(NAVY, 0.6), false, M.Fabric)
	Kit.bevel(r, r.Torso, V(1.9, 0.9, 1.1), CF(0, 0.4, 0), rgb(36, 40, 60), SH_EDGE, M.Fabric)
	belt(r, rgb(40, 34, 40), SH_EDGE, lv >= 3 and BLUE or nil)
	if lv >= 2 then
		Kit.bevel(r, r.RArm, V(1.2, 0.45, 1.2), CF(0.1, 0.9, 0) * ANG(0, 0, rad(-12)), NAVY, SH_EDGE)
	end
	bracers(r, NAVY, SH_EDGE)
	greaves(r, NAVY, SH_EDGE, true)
	dagger(r, r.RArm, lv >= 2 and BLUE or nil, 1.2 + (lv >= 4 and 0.3 or 0), BLUE_SOFT:Lerp(AC.ArmorMid, 0.6))
	-- кинжал в левой руке (без Muzzle)
	local A = r.LArm
	r:Box(A, V(0.2, 0.2, 0.7), CF(0, GRIP, 0.05), AC.ClothDark, M.Fabric)
	r:Box(A, V(0.12, 0.3, 1.1), CF(0, GRIP, -0.9), BLUE_SOFT:Lerp(AC.ArmorMid, 0.6), M.Metal)
	if lv >= 2 then
		r:Neon(A, V(0.14, 0.06, 1.05), CF(0, GRIP + 0.12, -0.9), BLUE)
	end
	Kit.spike(r, A, V(0, GRIP, -1.44), V(0, GRIP, -1.85), 0.3, BLUE_SOFT:Lerp(AC.ArmorMid, 0.6), M.Metal, true, 0.12)
	if lv >= 4 then
		capeWith(r, 1.7, 2.6, NAVY, nil)
	end
	if lv >= 5 then
		r:Orbit("OrbitShards", r.Torso, CF(0, 0.3, 0), 1.9, 3, 0.25, BLUE)
	end
	levelAura(r, lv, BLUE)
	return r:Finish(1, { RS = { 25, 0, 10 }, LS = { 25, 0, -10 } })
end

local function CrystalHunter(lv)
	local r = figure("CrystalHunter", { Torso = rgb(26, 26, 36), Arm = rgb(26, 26, 36), Leg = rgb(22, 22, 30), Edge = SH_EDGE })
	helm(r, rgb(30, 32, 46), SH_EDGE, BLUE, nil)
	chest(r, rgb(40, 44, 62), SH_EDGE, BLUE)
	belt(r, rgb(40, 34, 40), SH_EDGE)
	plateShoulders(r, rgb(40, 44, 62), SH_EDGE)
	-- кристаллы на плечах и спине
	for _, side in ipairs({ 1, -1 }) do
		local A = side == 1 and r.RArm or r.LArm
		for k = 0, (lv >= 3 and 2 or 1) do
			Kit.spike(r, A, V(0.3 * side, 1.1, -0.3 + k * 0.4), V((0.65 + k * 0.1) * side, 1.75 + k * 0.1, -0.35 + k * 0.5), 0.3, BLUE, M.Neon)
		end
	end
	if lv >= 2 then
		for k = -1, 1 do
			Kit.spike(r, r.Torso, V(k * 0.5, 0.6, 0.5), V(k * 0.7, 1.4 - math.abs(k) * 0.3, 1.0), 0.35, BLUE, M.Neon)
		end
	end
	bracers(r, rgb(40, 44, 62), SH_EDGE)
	greaves(r, rgb(40, 44, 62), SH_EDGE, true)
	crossbow(r, r.RArm, { Stock = rgb(40, 44, 62), Edge = SH_EDGE, Prong = rgb(30, 32, 46), Glow = BLUE })
	if lv >= 4 then
		capeWith(r, 1.8, 2.8, NAVY, BLUE)
	end
	if lv >= 5 then
		r:Orbit("OrbitCrystals", r.Torso, CF(0, 0.5, 0), 2.0, 4, 0.3, BLUE)
	end
	levelAura(r, lv, BLUE)
	return r:Finish(1, { RS = { 75, 0, 0 }, LS = { 65, 0, -25 } })
end

local function VoidPuppeteer(lv)
	local cloth = rgb(34, 22, 52)
	local r = figure("VoidPuppeteer", { Torso = cloth, Arm = cloth, Leg = cloth, Skin = rgb(220, 214, 226), Edge = AC.Edge })
	hood(r, rgb(46, 28, 72), AC.Edge, VOID, true)
	-- белая маска-улыбка
	r:Box(r.Head, V(0.86, 0.86, 0.06), CF(0, -0.04, -0.64), rgb(226, 220, 232), M.Plastic)
	for _, s in ipairs({ -1, 1 }) do
		r:Neon(r.Head, V(0.18, 0.08, 0.04), CF(0.2 * s, 0.1, -0.68) * ANG(0, 0, rad(-14 * s)), VOID)
	end
	r:Box(r.Head, V(0.4, 0.06, 0.04), CF(0, -0.25, -0.68), rgb(20, 14, 26))
	robe(r, cloth, AC.Edge, 1.8)
	mantle(r, rgb(46, 28, 72), AC.Edge)
	belt(r, rgb(50, 36, 30), AC.Edge, VOID)
	-- сферы-ромбы в руках и нити
	for _, side in ipairs({ 1, -1 }) do
		local A = side == 1 and r.RArm or r.LArm
		r:Neon(A, V(0.45, 0.45, 0.45), CF(0, -1.45, -0.2) * ANG(rad(45), 0, rad(45)), VOID)
		if side == 1 then
			muzzle(r, A, CF(0, -1.45, -0.2))
		end
		for k = -1, 1 do
			r:Neon(A, V(0.03, 1.3, 0.03), CF(k * 0.18, -2.1, -0.2), P.NeonSoft)
		end
	end
	-- куклы на орбите
	local n = lv >= 4 and 3 or 2
	local hub = r:Orbit("OrbitPuppets", r.Torso, CF(0, -0.2, 0), 2.4, 0, 0.2, VOID)
	for i = 0, n - 1 do
		local a = i / n * PI * 2
		local p = V(math.cos(a) * 2.4, 0, math.sin(a) * 2.4)
		r:Box(hub, V(0.5, 0.55, 0.3), CF(p), rgb(120, 90, 70), M.Wood)
		r:Box(hub, V(0.36, 0.36, 0.36), CF(p + V(0, 0.48, 0)), rgb(226, 220, 232), M.Plastic)
		r:Box(hub, V(0.16, 0.45, 0.16), CF(p + V(-0.18, -0.48, 0)), rgb(120, 90, 70), M.Wood)
		r:Box(hub, V(0.16, 0.45, 0.16), CF(p + V(0.18, -0.48, 0)), rgb(120, 90, 70), M.Wood)
		r:Neon(hub, V(0.03, 1.2, 0.03), CF(p + V(0, 1.2, 0)), P.NeonSoft)
	end
	if lv >= 3 then
		capeWith(r, 2.0, 3.2, rgb(46, 28, 72), VOID)
	end
	levelAura(r, lv)
	return r:Finish(1.05, { RS = { 40, 0, 20 }, LS = { 40, 0, -20 } })
end

local function Starbreaker(lv)
	local gold, white, edge = rgb(200, 160, 74), rgb(226, 222, 234), rgb(255, 235, 180)
	local r = figure("Starbreaker", { Torso = white, Arm = gold, Leg = white, Edge = edge })
	helm(r, gold, edge, BLUE, gold, true)
	chest(r, gold, edge, BLUE)
	-- звёздная эмблема
	for k = 0, 3 do
		Kit.spike(r, r.Torso, V(0, 0.5, -0.66), V(0, 0.5, -0.66) + V(math.cos(k * PI / 2), math.sin(k * PI / 2), 0) * 0.45, 0.2, rgb(255, 240, 200), M.Metal, true, 0.06)
	end
	belt(r, rgb(60, 50, 40), gold, BLUE)
	tassets(r, gold, edge)
	bigShoulders(r, white, edge, BLUE, lv >= 4 and 1.2 or 1.05, lv >= 3 and 2 or 1)
	bracers(r, gold, edge)
	greaves(r, gold, edge, true)
	hammer(r, r.RArm, { Head = white, Edge = edge, Trim = gold, Glow = BLUE, Wood = rgb(60, 50, 40) })
	capeWith(r, 2.1, 3.3, NAVY, lv >= 3 and BLUE or nil)
	if lv >= 5 then
		r:Orbit("OrbitStars", r.Head, CF(0, 1.3, 0), 1.6, 5, 0.3, rgb(255, 225, 140))
	end
	levelAura(r, lv, rgb(255, 210, 110))
	return r:Finish(1.3, { RS = { 30, 0, 0 }, LS = { 20, 0, 0 } })
end

local function RiftMonarch(lv)
	local royal, black, edge = rgb(46, 40, 110), rgb(22, 22, 40), rgb(140, 150, 220)
	local r = figure("RiftMonarch", { Torso = black, Arm = royal, Leg = black, Edge = edge })
	helm(r, royal, edge, BLUE, nil, true)
	crown(r, rgb(200, 210, 255), BLUE, 0.6 + lv * 0.06)
	chest(r, royal, edge, BLUE)
	belt(r, black, edge, VOID)
	robe(r, royal, edge, 1.7)
	bigShoulders(r, black, edge, BLUE, 1.2, lv >= 3 and 2 or 1)
	bracers(r, royal, edge)
	capeWith(r, 2.3, 3.8, rgb(36, 30, 90), VOID)
	staff(r, r.RArm, { Glow = BLUE, Prong = edge, Wood = black, Top = 2.6, Big = true })
	-- кольца-порталы за спиной
	for i, color in ipairs({ BLUE, VOID }) do
		if i == 1 or lv >= 3 then
			local radius = 1.0 + i * 0.35
			local hub = r:Orbit("OrbitRift" .. i, r.Torso, CF(0, 0.6, 1.6) * ANG(rad(90), 0, 0), radius, 0, 0.2, color)
			Kit.ring(r, hub, ANG(rad(90), 0, 0), radius, 14, 0.1, 0.1, color, M.Neon, function(k)
				return k % 5 == 4
			end)
		end
	end
	levelAura(r, lv, BLUE)
	return r:Finish(1.4, { RS = { 12, 0, 0 } })
end

local function RealityDestroyer(lv)
	local RED, black, mid, edge = rgb(255, 40, 50), rgb(24, 18, 22), rgb(44, 30, 36), rgb(160, 100, 110)
	local r = figure("RealityDestroyer", { Torso = black, Arm = black, Leg = black, Edge = edge })
	helm(r, black, edge, RED, nil, true)
	for _, s in ipairs({ -1, 1 }) do
		Kit.hornA(r, r.Head, { V(0.6 * s, 0.4, 0), V(1.0 * s, 0.7, 0), V(1.1 * s, 1.3, -0.05), V(0.9 * s, 1.8 + lv * 0.08, -0.2) }, 0.26, mid, M.Metal)
	end
	chest(r, mid, edge, RED)
	Kit.crack(r, r.Torso, { V(-0.85, 0.95, -0.59), V(-0.45, 0.45, -0.6), V(-0.7, -0.05, -0.59) }, 0.06, RED)
	Kit.crack(r, r.Torso, { V(0.7, 0.9, -0.59), V(0.85, 0.35, -0.59) }, 0.05, RED)
	belt(r, black, edge, RED)
	tassets(r, mid, edge)
	bigShoulders(r, black, edge, RED, 1.2 + (lv >= 4 and 0.1 or 0), lv >= 3 and 3 or 2)
	bracers(r, mid, edge)
	greaves(r, mid, edge, true)
	blade(r, r.RArm, { Len = 4.0 + lv * 0.15, W = 0.75, GuardW = 1.7, Blade = black, Glow = RED, Core = lv >= 3 and rgb(255, 150, 150) or nil, Guard = mid, Edge = edge, Trail = RED })
	capeWith(r, 2.3, 3.6, rgb(90, 10, 20), RED)
	if lv >= 4 then
		r:Orbit("OrbitShards", r.Torso, CF(0, 0.6, 0), 2.6, lv >= 5 and 6 or 4, 0.3, RED)
	end
	levelAura(r, lv, RED)
	return r:Finish(1.5, { RS = { 25, 0, 0 } })
end

------------------------------------------------------------------------
-- BLOOD MOON CASE
------------------------------------------------------------------------
local BLOOD, BLOOD_SOFT = rgb(235, 40, 56), rgb(255, 130, 140)
local CRIMSON, CRIMSON_D = rgb(96, 14, 24), rgb(52, 9, 16)
local BL_EDGE = rgb(160, 110, 116)
local BL_DARK = rgb(28, 20, 24)

local function BloodAcolyte(lv)
	local r = figure("BloodAcolyte", { Torso = CRIMSON_D, Arm = CRIMSON_D, Leg = BL_DARK, Edge = BL_EDGE })
	hood(r, CRIMSON, BL_EDGE, BLOOD)
	robe(r, CRIMSON_D, lv >= 3 and CRIMSON or nil, 1.6)
	belt(r, rgb(40, 26, 26), BL_EDGE, lv >= 2 and BLOOD or nil)
	if lv >= 2 then
		mantle(r, CRIMSON, BL_EDGE)
	end
	bracers(r, BL_DARK, BL_EDGE)
	-- глефа с серповидным лезвием
	local top = shaft(r, r.RArm, -2.4, 2.2, rgb(40, 26, 26), 0.2)
	local pts = { top, top + V(0, 0.45, -0.5), top + V(0, 0.3, -1.1), top + V(0, -0.15, -1.4) }
	for i = 1, 3 do
		Kit.bar(r, r.RArm, pts[i], pts[i + 1], V2(0.12, 0.34 - i * 0.06), lv >= 5 and CRIMSON or AC.ArmorMid)
	end
	if lv >= 3 then
		Kit.bar(r, r.RArm, pts[2] + V(0, -0.15, 0), pts[3] + V(0, -0.12, 0), V2(0.14, 0.05), BLOOD, M.Neon)
	end
	Kit.spike(r, r.RArm, top + V(0, 0.1, 0), top + V(0, 0.8, 0), 0.3, AC.ArmorMid, M.Metal)
	r:WeaponTrail(r.RArm, top + V(0, 0.3, -0.5), pts[4], BLOOD)
	muzzle(r, r.RArm, CF(pts[4]))
	if lv >= 4 then
		capeWith(r, 1.9, 3.0, CRIMSON, nil)
	end
	if lv >= 5 then
		r:Orbit("OrbitBlood", r.Torso, CF(0, 0.5, 0), 1.8, 3, 0.3, BLOOD)
	end
	levelAura(r, lv, BLOOD)
	return r:Finish(1, { RS = { 20, 0, 0 } })
end

-- Scarlet Hunter (CrimsonGunslinger): красный охотник с луком
local function CrimsonGunslinger(lv)
	local r = figure("CrimsonGunslinger", { Torso = BL_DARK, Arm = BL_DARK, Leg = BL_DARK, Edge = BL_EDGE })
	hood(r, CRIMSON, BL_EDGE, BLOOD)
	Kit.bevel(r, r.Torso, V(2.12, 1.2, 1.12), CF(0, 0.35, 0), rgb(50, 26, 30), BL_EDGE, M.Fabric)
	Kit.bar(r, r.Torso, V(-0.9, 0.95, -0.58), V(0.9, -0.6, -0.58), V2(0.2, 0.06), rgb(70, 40, 34))
	belt(r, rgb(50, 30, 28), BL_EDGE, lv >= 3 and BLOOD or nil)
	quiver(r, rgb(60, 30, 28), BLOOD)
	mantle(r, CRIMSON, BL_EDGE)
	bracers(r, rgb(60, 30, 28), BL_EDGE)
	greaves(r, BL_DARK, BL_EDGE, true)
	bow(r, r.LArm, { Wood = lv >= 4 and CRIMSON_D or rgb(60, 34, 30), Glow = lv >= 2 and BLOOD or nil, Tip = BL_EDGE })
	if lv >= 4 then
		capeWith(r, 1.9, 3.0, CRIMSON, nil)
	end
	if lv >= 5 then
		r:Box(r.Head, V(1.06, 0.4, 0.08), CF(0, -0.3, -0.64), BL_DARK, M.Metal)
	end
	levelAura(r, lv, BLOOD)
	return r:Finish(1, { LS = { 20, 0, 0 } })
end

-- Crimson Witch (MoonWitch): ведьма в остроконечной шляпе с посохом-полумесяцем
local function MoonWitch(lv)
	local r = figure("MoonWitch", { Torso = CRIMSON_D, Arm = CRIMSON_D, Leg = BL_DARK, Skin = rgb(220, 196, 190), Edge = BL_EDGE })
	eyes(r, BLOOD, true, 0.06)
	-- волосы
	Kit.bevel(r, r.Head, V(1.3, 1.1, 0.3), CF(0, -0.1, 0.52), rgb(30, 18, 22), false, M.Plastic)
	wizardHat(r, BL_DARK, CRIMSON, BL_EDGE)
	robe(r, CRIMSON_D, CRIMSON, 1.8)
	belt(r, rgb(40, 24, 26), BL_EDGE, BLOOD)
	if lv >= 2 then
		mantle(r, CRIMSON, BL_EDGE)
	end
	-- посох с полумесяцем
	local top = shaft(r, r.RArm, -2.4, 2.3, rgb(40, 24, 26), 0.2)
	local c = top + V(0, 0.6, 0)
	for k = 0, 4 do
		local a1, a2 = rad(200 + k * 28), rad(200 + (k + 1) * 28)
		Kit.bar(r, r.RArm, c + V(0, math.sin(a1) * 0.55, math.cos(a1) * 0.55), c + V(0, math.sin(a2) * 0.55, math.cos(a2) * 0.55), V2(0.12, 0.14), BLOOD, M.Neon)
	end
	r:Neon(r.RArm, V(0.3, 0.3, 0.3), CF(c) * ANG(rad(45), 0, rad(45)), BLOOD_SOFT)
	muzzle(r, r.RArm, CF(c))
	if lv >= 4 then
		capeWith(r, 1.9, 3.0, CRIMSON, BLOOD)
	end
	if lv >= 5 then
		r:Orbit("OrbitMoon", r.Torso, CF(0, 1.4, 0), 1.9, 3, 0.3, BLOOD_SOFT)
	end
	levelAura(r, lv, BLOOD)
	return r:Finish(1.05, { RS = { 10, 0, 0 }, LS = { 10, 0, -10 } })
end

-- Blood Paladin (BloodfangWarlord): красная броня, башенный щит, топор
local function BloodfangWarlord(lv)
	local r = figure("BloodfangWarlord", { Torso = BL_DARK, Arm = CRIMSON, Leg = BL_DARK, Edge = BL_EDGE })
	helm(r, CRIMSON, BL_EDGE, BLOOD, BL_DARK, true)
	if lv >= 3 then
		for _, s in ipairs({ -1, 1 }) do
			Kit.hornA(r, r.Head, { V(0.6 * s, 0.45, 0), V(0.9 * s, 0.7, 0), V(0.95 * s, 1.2, -0.1) }, 0.22, BL_DARK, M.Metal)
		end
	end
	chest(r, CRIMSON, BL_EDGE, BLOOD)
	belt(r, rgb(40, 24, 26), BL_EDGE, BLOOD)
	tassets(r, CRIMSON, BL_EDGE)
	bigShoulders(r, CRIMSON, BL_EDGE, lv >= 3 and BLOOD or nil, lv >= 4 and 1.2 or 1.05, lv >= 4 and 2 or 1)
	bracers(r, BL_DARK, BL_EDGE)
	greaves(r, CRIMSON, BL_EDGE, true)
	axe(r, r.RArm, { Head = AC.ArmorMid, Edge = BL_EDGE, Glow = BLOOD, Wood = rgb(40, 24, 26) })
	shield(r, r.LArm, { Color = CRIMSON, Edge = BL_EDGE, H = 2.8, W = 1.7, Rim = BL_DARK, Gem = BLOOD })
	capeWith(r, 2.1, 3.3, CRIMSON_D, lv >= 3 and BLOOD or nil)
	levelAura(r, lv, BLOOD)
	return r:Finish(1.3, { RS = { 30, 0, 0 } })
end

-- Moon Devourer (LunarSeraph): рогатая тёмная броня, парные клинки-полумесяцы, кровавая луна за спиной
local function LunarSeraph(lv)
	local r = figure("LunarSeraph", { Torso = BL_DARK, Arm = BL_DARK, Leg = BL_DARK, Edge = BL_EDGE })
	helm(r, BL_DARK, BL_EDGE, BLOOD, nil, true)
	for _, s in ipairs({ -1, 1 }) do
		Kit.hornA(r, r.Head, { V(0.62 * s, 0.4, 0), V(1.1 * s, 0.75, 0.1), V(1.25 * s, 1.4, 0.05), V(1.0 * s, 2.0 + lv * 0.08, -0.15) }, 0.28, CRIMSON_D, M.Metal)
	end
	chest(r, CRIMSON_D, BL_EDGE, BLOOD)
	Kit.crack(r, r.Torso, { V(-0.8, 0.95, -0.59), V(-0.4, 0.5, -0.6), V(-0.65, 0.05, -0.59) }, 0.05, BLOOD)
	belt(r, BL_DARK, BL_EDGE, BLOOD)
	tassets(r, CRIMSON_D, BL_EDGE)
	bigShoulders(r, BL_DARK, BL_EDGE, BLOOD, 1.2, lv >= 3 and 3 or 2)
	bracers(r, CRIMSON_D, BL_EDGE)
	greaves(r, CRIMSON_D, BL_EDGE, true)
	-- клинки-полумесяцы в обеих руках
	for _, A in ipairs({ r.RArm, r.LArm }) do
		r:Box(A, V(0.22, 0.22, 0.7), CF(0, GRIP, 0.05), BL_DARK, M.Fabric)
		local c = V(0, GRIP, -0.9)
		for k = 0, 4 do
			local a1, a2 = rad(-80 + k * 32), rad(-80 + (k + 1) * 32)
			Kit.bar(r, A, c + V(0, math.sin(a1) * 0.9, -math.cos(a1) * 0.5), c + V(0, math.sin(a2) * 0.9, -math.cos(a2) * 0.5), V2(0.12, 0.2), AC.ArmorMid)
			Kit.bar(r, A, c + V(0, math.sin(a1) * 1.0, -math.cos(a1) * 0.6), c + V(0, math.sin(a2) * 1.0, -math.cos(a2) * 0.6), V2(0.13, 0.05), BLOOD, M.Neon)
		end
	end
	muzzle(r, r.RArm, CF(0, GRIP, -1.5))
	-- кровавая луна за спиной
	local moon = r:Joint("MoonBack", r.Torso, V(0.2, 0.2, 0.2), CF(0, 1.2, 1.2), CF(), BLOOD)
	moon.Transparency = 1
	Kit.ring(r, moon, CF(), 1.5 + lv * 0.08, 16, 0.18, 0.14, BLOOD, M.Neon, function(k)
		return k >= 11
	end)
	capeWith(r, 2.2, 3.5, CRIMSON_D, BLOOD)
	levelAura(r, lv, BLOOD)
	return r:Finish(1.35, { RS = { 10, 0, 0 } })
end

-- Scarlet Eclipse (CrimsonEclipse): капюшон, кольцо затмения за головой, двойная коса-глефа
local function CrimsonEclipse(lv)
	local r = figure("CrimsonEclipse", { Torso = BL_DARK, Arm = BL_DARK, Leg = BL_DARK, Edge = BL_EDGE })
	hood(r, CRIMSON_D, BL_EDGE, BLOOD, true)
	r:Box(r.Head, V(0.9, 0.4, 0.06), CF(0, -0.28, -0.64), BL_DARK, M.Metal)
	chest(r, CRIMSON_D, BL_EDGE, BLOOD)
	belt(r, BL_DARK, BL_EDGE, BLOOD)
	robe(r, BL_DARK, CRIMSON, 2.0)
	bigShoulders(r, CRIMSON_D, BL_EDGE, BLOOD, 1.15, lv >= 3 and 3 or 2)
	bracers(r, CRIMSON_D, BL_EDGE)
	-- кольцо затмения: тёмный круг в кровавом ободе
	local ecl = r:Joint("SpinEclipse", r.Head, V(0.2, 0.2, 0.2), CF(0, 0.3, 0.95), CF(), BLOOD)
	ecl.Transparency = 1
	Kit.ring(r, ecl, CF(), 1.25, 16, 0.2, 0.12, BLOOD, M.Neon)
	r:Box(ecl, V(1.7, 1.7, 0.08), CF(0, 0, 0.06) * ANG(0, 0, rad(45)), rgb(10, 6, 8), M.Plastic)
	-- двойная глефа
	local A = r.RArm
	local top = shaft(r, A, -2.2, 2.2, BL_DARK, 0.2)
	local bottom = V(0, -2.2, -0.5)
	for _, base in ipairs({ top, bottom }) do
		local dir = base.Y > 0 and 1 or -1
		local pts = { base, base + V(0, 0.4 * dir, -0.6), base + V(0, 0.2 * dir, -1.4), base + V(0, -0.3 * dir, -1.9) }
		for i = 1, 3 do
			Kit.bar(r, A, pts[i], pts[i + 1], V2(0.12, 0.4 - i * 0.07), CRIMSON_D)
			Kit.bar(r, A, pts[i] + V(0, -0.15 * dir, 0), pts[i + 1] + V(0, -0.12 * dir, 0), V2(0.14, 0.05), BLOOD, M.Neon)
		end
	end
	r:WeaponTrail(A, top + V(0, 0.3, -0.6), top + V(0, -0.3, -1.9), BLOOD)
	muzzle(r, A, CF(top + V(0, -0.3, -1.9)))
	capeWith(r, 2.2, 3.6, CRIMSON_D, BLOOD)
	if lv >= 4 then
		r:Orbit("OrbitBlood", r.Torso, CF(0, 0.5, 0), 2.4, lv >= 5 and 6 or 4, 0.3, BLOOD)
	end
	levelAura(r, lv, BLOOD)
	return r:Finish(1.5, { RS = { 8, 0, 0 } })
end

------------------------------------------------------------------------
-- VOID KNIGHT (по концепту)
------------------------------------------------------------------------
-- Угловатый клинок Пустоты: тёмный клинок с неоновыми кромками, гарда с рогами и самоцветом
local function voidBlade(r, A, lv)
	local K, AC = Kit, Kit.Colors
	local y = -1.05
	local len = 3.5 + (lv >= 4 and 0.5 or 0) + (lv >= 5 and 0.4 or 0)
	local w = 0.62 + (lv >= 3 and 0.08 or 0)
	local glow = lv >= 5 and P.NeonSoft or P.Neon
	-- рукоять, навершие
	r:Box(A, V(0.24, 0.24, 0.95), CF(0, y, 0.1), AC.ClothDark, M.Fabric)
	r:Box(A, V(0.34, 0.34, 0.3), CF(0, y, 0.65) * ANG(0, 0, rad(45)), AC.Armor, M.Metal)
	-- гарда с загнутыми рогами и самоцветом
	K.bevel(r, A, V(0.32, 1.4, 0.32), CF(0, y, -0.45), AC.Armor, AC.Edge)
	for _, s in ipairs({ -1, 1 }) do
		K.spike(r, A, V(0, y + 0.62 * s, -0.45), V(0, y + 0.95 * s, -0.85), 0.32, AC.Armor, M.Metal, true, 0.14)
	end
	K.gem(r, A, 0.3, CF(-0.17, y, -0.45) * ANG(0, math.pi / 2, 0), P.Neon)
	K.gem(r, A, 0.3, CF(0.17, y, -0.45) * ANG(0, -math.pi / 2, 0), P.Neon)
	-- клинок: тёмное тело, светящиеся кромки и дол
	local z0 = -0.6
	r:Box(A, V(0.14, w, len), CF(0, y, z0 - len / 2), lv >= 5 and AC.Cloth or AC.ArmorMid, M.Metal)
	r:Neon(A, V(0.16, 0.08, len * 0.97), CF(0, y + w / 2 - 0.03, z0 - len / 2), glow)
	r:Neon(A, V(0.16, 0.08, len * 0.97), CF(0, y - w / 2 + 0.03, z0 - len / 2), glow)
	if lv >= 3 then
		r:Neon(A, V(0.17, 0.08, len * 0.7), CF(0, y, z0 - len * 0.42), P.NeonSoft)
	end
	K.spike(r, A, V(0, y, z0 - len + 0.02), V(0, y, z0 - len - w * 1.3), w, lv >= 5 and AC.Cloth or AC.ArmorMid, M.Metal, true, 0.14)
	K.spike(r, A, V(0, y, z0 - len + 0.02), V(0, y, z0 - len - w * 1.15), w * 0.75, glow, M.Neon, true, 0.16)
	local tip = r:Box(A, V(0.2, 0.2, 0.2), CF(0, y, z0 - len - w), P.Black, M.Plastic, { Transparency = 1, Name = "Muzzle" })
	r.Muzzle = tip
	r:WeaponTrail(A, V(0, y, z0 - 0.15), V(0, y, z0 - len - w), P.NeonSoft)
	return tip
end

local function VoidKnight(lv)
	local K, AC = Kit, Kit.Colors
	local r = Rig.new({ Name = "VoidKnight", Torso = AC.Armor, Arm = AC.Armor, Leg = AC.Armor, Head = AC.Armor, TorsoMat = M.Metal })
	local T, H, RA, LA, RL, LL = r.Torso, r.Head, r.RArm, r.LArm, r.RLeg, r.LLeg
	for _, L in ipairs({ T, H, RA, LA, RL, LL }) do
		L.Transparency = 1
	end
	local leather = Color3.fromRGB(40, 30, 38)
	-- КИРАСА
	K.bevel(r, T, V(2.05, 2.0, 1.05), CF(), AC.Armor, AC.Edge)
	K.bevel(r, T, V(2.25, 1.0, 1.25), CF(0, 0.5, -0.02), AC.ArmorMid, AC.Edge)
	K.bevel(r, T, V(1.85, 0.32, 1.15), CF(0, -0.15, 0), AC.ArmorMid, AC.Edge)
	K.bevel(r, T, V(1.8, 0.32, 1.12), CF(0, -0.45, 0), AC.Armor, AC.Edge)
	if lv >= 2 then
		K.bevel(r, T, V(0.34, 0.95, 0.18), CF(0, 0.5, -0.7), AC.Armor, AC.Edge)
		K.gem(r, T, 0.42, CF(0, 0.55, -0.8), P.Neon, AC.Edge)
	end
	if lv >= 3 then
		K.crack(r, T, { V(-0.85, 0.85, -0.66), V(-0.5, 0.45, -0.66), V(-0.7, 0.1, -0.66) }, 0.06)
		K.crack(r, T, { V(0.55, 0.9, -0.66), V(0.8, 0.4, -0.66) }, 0.05)
	end
	-- пояс с пряжкой, табард, набедренники
	K.bevel(r, T, V(2.15, 0.32, 1.2), CF(0, -0.8, 0), leather, AC.Edge, M.Fabric)
	K.bevel(r, T, V(0.48, 0.44, 0.14), CF(0, -0.8, -0.66), AC.Edge, AC.ArmorMid)
	K.gem(r, T, 0.2, CF(0, -0.8, -0.75), P.Neon)
	r:Box(T, V(0.95, 1.0, 0.08), CF(0, -1.45, -0.6), AC.Cloth, M.Fabric)
	if lv >= 2 then
		K.tatter(r, T, -1.95, -0.6, 0.95, 3, AC.Cloth, M.Fabric, 1)
	end
	for _, s in ipairs({ -1, 1 }) do
		K.bevel(r, T, V(0.75, 0.7, 0.95), CF(0.78 * s, -1.25, -0.02) * ANG(0, 0, rad(10 * s)), AC.ArmorMid, AC.Edge)
	end
	if lv >= 3 then
		K.chain(r, T, 4, 0.26, nil, CF(0.75, -1.0, -0.62))
		K.chain(r, T, 3, 0.26, nil, CF(-0.7, -1.0, 0.62))
	end
	-- ШЛЕМ: гранёный, лицевая пластина, Т-визор, гребень, нащёчники
	K.bevel(r, H, V(1.35, 1.4, 1.4), CF(0, 0.05, 0), AC.Armor, AC.Edge)
	K.bevel(r, H, V(1.12, 1.05, 0.22), CF(0, -0.05, -0.72), AC.ArmorMid, AC.Edge)
	r:Neon(H, V(0.5, 0.09, 0.06), CF(0, 0.2, -0.84), P.Neon)
	r:Neon(H, V(0.1, 0.62, 0.06), CF(0, -0.08, -0.84), P.Neon)
	-- двускатный верх шлема
	r:Wedge(H, V(1.36, 0.42, 0.7), CF(0, 0.96, -0.35), AC.Armor, M.Metal)
	r:Wedge(H, V(1.36, 0.42, 0.7), CF(0, 0.96, 0.35) * ANG(0, math.pi, 0), AC.Armor, M.Metal)
	r:Box(H, V(1.38, 0.06, 0.06), CF(0, 1.16, 0), AC.Edge, M.Metal)
	for _, s in ipairs({ -1, 1 }) do
		r:Wedge(H, V(0.28, 0.55, 0.55), CF(0.58 * s, -0.5, -0.5) * ANG(math.pi, 0, 0), AC.Armor, M.Metal)
	end
	if lv >= 2 then
		K.spike(r, H, V(0, 1.0, -0.3), V(0, 1.45 + lv * 0.12, 0.2), 0.8, AC.Armor, M.Metal, true, 0.14)
	end
	if lv >= 2 then
		local big = lv >= 5 and 1.6 or (lv >= 4 and 1.2 or 0.85)
		for _, s in ipairs({ -1, 1 }) do
			K.hornA(r, H, { V(0.6 * s, 0.3, 0), V(0.95 * s, 0.45 + 0.1 * big, 0.05), V(1.05 * s, 0.8 * big, 0.05), V(0.85 * s, 1.35 * big, -0.1) }, 0.24 + 0.04 * big, AC.Armor, M.Metal)
			if lv >= 5 then
				K.spike(r, H, V(0.95 * s, 1.0 * big, -0.05), V(0.85 * s, 1.35 * big, -0.1), 0.2, P.Neon, M.Neon, false, 0.1)
			end
		end
	end
	-- НАПЛЕЧНИКИ
	for _, a in ipairs({ { RA, 1 }, { LA, -1 } }) do
		local A, s = a[1], a[2]
		if lv == 1 then
			K.bevel(r, A, V(1.35, 0.55, 1.3), CF(0.12 * s, 0.85, 0) * ANG(0, 0, rad(-12 * s)), AC.ArmorMid, AC.Edge)
		else
			local size = lv >= 5 and 1.22 or (lv >= 4 and 1.1 or 1.0)
			K.pauldron(r, A, s, size, AC.Armor, AC.Edge, lv >= 3 and P.Neon or nil, lv >= 5 and 3 or (lv >= 4 and 2 or 1))
		end
		-- рука: плечо, наруч с манжетой, латная перчатка
		K.bevel(r, A, V(1.0, 0.9, 1.0), CF(0, 0.15, 0), AC.Armor, AC.Edge)
		K.bevel(r, A, V(1.15, 0.85, 1.15), CF(0, -0.55, 0), AC.ArmorMid, AC.Edge)
		K.bevel(r, A, V(1.28, 0.24, 1.28), CF(0, -0.15, 0), AC.Armor, AC.Edge)
		K.bevel(r, A, V(1.02, 0.42, 1.02), CF(0, -1.12, 0), AC.Armor, AC.Edge)
		if lv >= 3 then
			K.spike(r, A, V(0.55 * s, -0.5, 0), V(0.95 * s, -0.4, 0.15), 0.32, AC.Armor, M.Metal, true, 0.1)
		end
	end
	-- НОГИ
	for _, Lg in ipairs({ RL, LL }) do
		K.bevel(r, Lg, V(1.0, 0.95, 1.02), CF(0, 0.45, 0), AC.Armor, AC.Edge)
		if lv >= 2 then
			K.bevel(r, Lg, V(0.75, 0.45, 0.25), CF(0, 0.0, -0.58), AC.ArmorMid, AC.Edge)
		end
		K.bevel(r, Lg, V(1.08, 0.7, 1.1), CF(0, -0.38, 0), AC.ArmorMid, AC.Edge)
		K.bootA(r, Lg, AC.Armor, AC.Edge, 1.1)
	end
	-- МЕЧ
	local blade = voidBlade(r, RA, lv)
	if lv >= 3 then
		r:Sparkles(blade, P.Neon, { Rate = 10, Size = 0.3 })
	end
	-- рваный плащ с эмблемой
	if lv >= 4 then
		local cape = r:Cape(2.1, 3.5, AC.Cloth, true)
		K.gem(r, cape, 0.55, CF(0, 0.1, 0.08) * ANG(0, math.pi, 0), P.NeonSoft)
	end
	levelAura(r, lv)
	return r:Finish(1.1, { RS = { 20, 0, 0 } })
end

------------------------------------------------------------------------
-- HALLOWEEN: ПРОКЛЯТЫЙ ЧАСОВЩИК (SECRET)
-- Голова — старинные механические часы, стрелки и шестерёнки на моторах Clock*/Gear*
-- (крутятся в Renderer, быстрее во время способностей). Оружие — Хроносекира.
------------------------------------------------------------------------
local CLK = {
	Black = rgb(20, 18, 24),
	Suit = rgb(34, 30, 40),
	Gold = rgb(214, 168, 72),
	GoldDark = rgb(150, 112, 50),
	Bronze = rgb(160, 106, 52),
	Silver = rgb(172, 174, 188),
	Steel = rgb(58, 54, 64),
	Dial = rgb(14, 12, 18),
	Orange = rgb(255, 140, 40),
	OrangeDim = rgb(140, 70, 24),
}

-- Восьмиугольник из 4 брусков в плоскости XY узла cf (a — расстояние от центра до грани)
local function octa(r, limb, a, depth, cf, color, mat)
	local parts = {}
	for k = 0, 3 do
		parts[#parts + 1] = r:Box(limb, V(2 * a, 0.8284 * a, depth), cf * ANG(0, 0, k * PI / 4), color, mat or M.Metal)
	end
	return parts
end

-- Шестерёнка в плоскости XY. С именем — на своём моторе (крутится вокруг оси Z узла).
local function gear(r, limb, name, pivot, a, depth, color, hubColor, rate, mat)
	local host, base = limb, pivot
	if name then
		host = r:Joint(name, limb, V(0.1, 0.1, 0.1), pivot, CF(), color)
		host.Transparency = 1
		base = CF()
		r.SpinRates[name] = rate or 1
	end
	octa(r, host, a, depth, base, color, mat)
	for k = 0, 7 do
		local ang = k * PI / 4
		r:Box(host, V(a * 0.36, a * 0.34, depth), base * CF(math.cos(ang) * a * 1.08, math.sin(ang) * a * 1.08, 0) * ANG(0, 0, ang), color, mat or M.Metal)
	end
	local hub = r:Box(host, V(a * 0.42, a * 0.42, depth + 0.04), base * ANG(0, 0, PI / 4), hubColor or CLK.Black, (hubColor == CLK.Orange) and M.Neon or M.Metal)
	return host, hub
end

-- Циферблат: рама, чёрный диск, деления, стрелки на моторах <prefix>Hour / <prefix>Minute
local function clockFace(r, limb, cf, a, frame, prefix, handColor, glowHands)
	octa(r, limb, a, 0.5, cf, frame)
	octa(r, limb, a * 0.84, 0.54, cf, CLK.Dial, M.Plastic)
	for k = 0, 11 do
		local ang = k * PI / 6
		local big = k % 3 == 0
		r:Box(limb, V(a * 0.07, a * (big and 0.2 or 0.12), 0.04), cf * CF(math.cos(ang) * a * 0.68, math.sin(ang) * a * 0.68, -0.28) * ANG(0, 0, ang + PI / 2), handColor, M.Metal)
	end
	local hands = {}
	for i, h in ipairs({ { "Hour", 0.45, 0.11, 0.22 }, { "Minute", 0.68, 0.07, 1.6 } }) do
		local name = prefix .. h[1]
		local hub = r:Joint(name, limb, V(0.1, 0.1, 0.1), cf * CF(0, 0, -0.3 - i * 0.02), CF(), handColor)
		hub.Transparency = 1
		r.SpinRates[name] = h[4]
		local f = glowHands and r.Neon or r.Box
		hands[i] = f(r, hub, V(a * h[3], a * h[2], 0.04), CF(0, a * h[2] * 0.42, 0), glowHands and CLK.Orange or handColor)
	end
	r:Box(limb, V(a * 0.16, a * 0.16, 0.08), cf * CF(0, 0, -0.36) * ANG(0, 0, PI / 4), CLK.Gold, M.Metal)
	return hands
end

-- Хроносекира: длинная тёмная рукоять, два полукруглых зубчатых лезвия, центральная шестерня
local function chronoaxe(r, A, lv)
	local z = -0.5
	local bottom, top = -2.5, 2.3
	r:Box(A, V(0.22, top - bottom, 0.22), CF(0, (top + bottom) / 2, z), CLK.Steel, M.Metal)
	for _, y in ipairs({ -1.6, -0.2, 1.2 }) do
		Kit.bevel(r, A, V(0.34, 0.16, 0.34), CF(0, y, z), CLK.Bronze, false)
	end
	Kit.spike(r, A, V(0, bottom + 0.05, z), V(0, bottom - 0.5, z), 0.3, CLK.Bronze, M.Metal)
	local c = V(0, top + 0.2, z)
	local R = ({ 0.95, 1.15, 1.15, 1.3, 1.45 })[lv]
	local blade = lv >= 5 and CLK.Black or CLK.Steel
	local rimColor = lv >= 4 and CLK.Orange or CLK.OrangeDim
	for _, side in ipairs({ -1, 1 }) do
		local prev
		for k = 0, 6 do
			local phi = rad(-78 + k * 26)
			local dir = V(0, math.sin(phi), side * math.cos(phi))
			Kit.bar(r, A, c + dir * 0.3, c + dir * R, V2(0.1, 2 * R * math.sin(rad(13)) + 0.1), blade, M.Metal)
			Kit.spike(r, A, c + dir * (R - 0.02), c + dir * (R + 0.22), 0.2, CLK.Gold, M.Metal, true, 0.1)
			local rim = c + dir * (R * 0.9)
			if prev then
				local g = Kit.bar(r, A, prev, rim, V2(0.12, 0.07), rimColor, M.Neon)
				g:SetAttribute("AxeGlow", true)
			end
			prev = rim
		end
		-- бронзовая накладка у основания лезвия
		Kit.bevel(r, A, V(0.14, 0.5, 0.35), CF(c + V(0, 0, side * 0.42)), CLK.Bronze, false)
	end
	-- центральная шестерня (вращается) и малые механизмы
	local _, hub = gear(r, A, "GearAxe", CF(c) * ANG(0, PI / 2, 0), 0.38, 0.16, lv >= 3 and CLK.Gold or CLK.Bronze, CLK.Orange, 2.2)
	hub:SetAttribute("AxeGlow", true)
	gear(r, A, "GearAxeS1", CF(c + V(0, 0.5, -0.3)) * ANG(0, PI / 2, 0), 0.15, 0.12, CLK.Bronze, CLK.Black, -3.5)
	gear(r, A, "GearAxeS2", CF(c + V(0, -0.5, 0.3)) * ANG(0, PI / 2, 0), 0.15, 0.12, CLK.Bronze, CLK.Black, 3.5)
	r:Sparkles(hub, CLK.Orange, { Rate = lv >= 4 and 8 or 4, Size = 0.18 })
	r:WeaponTrail(A, c + V(0, 0, -0.4), c + V(0, 0, -R), CLK.Orange)
	return muzzle(r, A, CF(c))
end

-- Маленькие часы (для орбиты вокруг персонажа)
local function miniClock(r, limb, cf, a)
	octa(r, limb, a, 0.12, cf, CLK.Gold)
	octa(r, limb, a * 0.8, 0.14, cf, CLK.Dial, M.Plastic)
	r:Box(limb, V(a * 0.12, a * 0.6, 0.04), cf * CF(0, a * 0.25, -0.09), CLK.Gold, M.Metal)
	r:Box(limb, V(a * 0.5, a * 0.1, 0.04), cf * CF(a * 0.2, 0, -0.1), CLK.Gold, M.Metal)
end

local function CursedClockmaker(lv)
	local edge = CLK.GoldDark
	local r = Rig.new({ Name = "CursedClockmaker", HeadSize = V(1.2, 1.2, 1.2), Torso = CLK.Black, Arm = CLK.Black, Leg = CLK.Black, Head = CLK.Black })
	r.SpinRates = {}
	for _, L in ipairs({ r.Torso, r.Head, r.RArm, r.LArm, r.RLeg, r.LLeg }) do
		L.Transparency = 1
	end
	local T, H, RA, LA, RL, LL = r.Torso, r.Head, r.RArm, r.LArm, r.RLeg, r.LLeg
	local gearColor = lv >= 3 and CLK.Gold or (lv >= 2 and CLK.Silver or CLK.Bronze)
	local frame = lv >= 3 and CLK.Gold or CLK.Bronze

	-- R6-ТЕЛО: чёрный костюм с золотым кантом
	Kit.bevel(r, T, V(2, 2, 1), CF(), CLK.Black, edge)
	Kit.bevel(r, RA, V(1, 2, 1), CF(), CLK.Black, edge)
	Kit.bevel(r, LA, V(1, 2, 1), CF(), CLK.Black, edge)
	Kit.bevel(r, RL, V(1, 2, 1), CF(), CLK.Black, edge)
	Kit.bevel(r, LL, V(1, 2, 1), CF(), CLK.Black, edge)
	-- жилет, лацканы, пуговицы, брошь
	Kit.bevel(r, T, V(1.5, 1.7, 1.08), CF(0, 0.1, 0), CLK.Suit, edge, M.Fabric)
	for _, s in ipairs({ -1, 1 }) do
		Kit.bar(r, T, V(0.25 * s, 0.98, -0.56), V(0.62 * s, -0.4, -0.56), V2(0.12, 0.05), CLK.Gold, M.Metal)
	end
	for k = 0, 2 do
		r:Box(T, V(0.12, 0.12, 0.06), CF(0, 0.45 - k * 0.38, -0.57) * ANG(0, 0, PI / 4), CLK.Gold, M.Metal)
	end
	Kit.gem(r, T, 0.26, CF(0, 0.82, -0.6), CLK.Orange, CLK.Gold)
	-- золотые цепочки и карманные часы
	Kit.bar(r, T, V(0, 0.07, -0.58), V(-0.45, -0.3, -0.58), V2(0.06, 0.06), CLK.Gold, M.Metal)
	Kit.bar(r, T, V(-0.45, -0.3, -0.58), V(-0.75, -0.05, -0.58), V2(0.06, 0.06), CLK.Gold, M.Metal)
	miniClock(r, T, CF(-0.78, -0.25, -0.58), 0.18)
	-- пояс с пряжкой-шестерёнкой
	Kit.bevel(r, T, V(2.1, 0.3, 1.12), CF(0, -0.82, 0), CLK.Black, edge)
	gear(r, T, nil, CF(0, -0.82, -0.6), 0.16, 0.08, CLK.Gold, CLK.Orange)
	-- полы длинного сюртука
	for _, s in ipairs({ -1, 1 }) do
		Kit.bevel(r, T, V(0.95, 1.6, 0.16), CF(0.52 * s, -1.75, 0.46), CLK.Suit, edge, M.Fabric)
	end
	Kit.tatter(r, T, -2.55, 0.46, 2.0, 4, CLK.Suit, M.Fabric, 5)

	-- ГОЛОВА-ЧАСЫ
	local a = lv >= 5 and 1.0 or 0.92
	local headCF = CF(0, 0.35, 0)
	clockFace(r, H, headCF, a, frame, "Clock", CLK.Gold, lv >= 4)
	-- светящиеся механизмы на циферблате и по бокам
	gear(r, H, "GearHeadA", headCF * CF(0, -a * 0.38, -0.29), a * 0.16, 0.04, CLK.Orange, CLK.Dial, 3, M.Neon)
	for _, s in ipairs({ -1, 1 }) do
		gear(r, H, s == 1 and "GearHeadR" or "GearHeadL", headCF * CF(a * 0.98 * s, a * 0.45, 0), a * 0.24, 0.2, gearColor, CLK.Orange, 1.4 * s)
	end
	-- заводная головка сверху
	Kit.bevel(r, H, V(0.3, 0.3, 0.3), headCF * CF(0, a + 0.1, 0), frame, false)
	Kit.bevel(r, H, V(0.44, 0.12, 0.44), headCF * CF(0, a + 0.3, 0), frame, false)

	-- НАПЛЕЧНИКИ
	if lv >= 3 then
		Kit.pauldron(r, RA, 1, lv >= 5 and 1.2 or 1.05, CLK.Black, CLK.Gold, CLK.Orange, lv >= 5 and 2 or 1)
		Kit.pauldron(r, LA, -1, lv >= 5 and 1.2 or 1.05, CLK.Black, CLK.Gold, CLK.Orange, lv >= 5 and 2 or 1)
	else
		for _, side in ipairs({ 1, -1 }) do
			local A = side == 1 and RA or LA
			Kit.bevel(r, A, V(1.3, 0.45, 1.25) * (lv >= 2 and 1.1 or 1), CF(0.12 * side, 0.9, 0) * ANG(0, 0, rad(-12 * side)), CLK.Steel, lv >= 2 and CLK.Silver or CLK.Bronze)
			gear(r, A, nil, CF(0.62 * side, 0.85, 0) * ANG(0, PI / 2, 0), 0.2, 0.08, gearColor, CLK.Black)
		end
	end
	-- рукава с золотыми манжетами, перчатки
	for _, A in ipairs({ RA, LA }) do
		Kit.bevel(r, A, V(1.16, 0.3, 1.16), CF(0, -0.55, 0), CLK.Gold, false)
		Kit.bevel(r, A, V(1.04, 0.42, 1.04), CF(0, -0.82, 0), lv >= 2 and CLK.Steel or CLK.Bronze, edge)
		if lv >= 2 then
			Kit.bevel(r, A, V(1.12, 0.5, 1.12), CF(0, -0.2, 0), CLK.Steel, CLK.Silver)
		end
	end
	-- ноги: брюки, наколенники (с 2 ур.), сапоги с золотом
	for _, Lg in ipairs({ RL, LL }) do
		if lv >= 2 then
			Kit.bevel(r, Lg, V(0.8, 0.45, 0.26), CF(0, 0.0, -0.58), CLK.Steel, CLK.Silver)
		end
		Kit.bootA(r, Lg, CLK.Black, CLK.Gold, 1.12)
	end

	-- МЕХАНИЗМ НА СПИНЕ
	gear(r, T, "GearBack", CF(0, 0.3, 0.7), 0.7, 0.2, gearColor, CLK.Orange, 0.8)
	if lv >= 3 then
		gear(r, T, "GearBack2", CF(0.75, -0.35, 0.82), 0.42, 0.18, CLK.Bronze, CLK.Black, -1.4)
		gear(r, T, "GearBack3", CF(-0.7, -0.45, 0.82), 0.32, 0.18, CLK.Bronze, CLK.Black, 1.9)
		for _, s in ipairs({ -1, 1 }) do
			r:Box(T, V(0.14, 1.4, 0.14), CF(0.55 * s, 0.4, 0.66), CLK.Bronze, M.Metal)
		end
	end
	-- ПЛАЩ (роскошный с 4 ур.)
	local cape = r:Cape(lv >= 4 and 2.3 or 2.0, lv >= 4 and 4.2 or 3.6, lv >= 4 and rgb(26, 16, 30) or CLK.Black, true)
	if lv >= 4 then
		Kit.gem(r, cape, 0.5, CF(0, 0.1, 0.08) * ANG(0, PI, 0), CLK.Orange, CLK.Gold)
		r:Box(cape, V(2.34, 0.1, 0.14), CF(0, 0.9, 0), CLK.Gold, M.Metal)
	end
	-- ОГРОМНЫЕ ЧАСЫ ЗА СПИНОЙ (MAX)
	if lv >= 5 then
		clockFace(r, T, CF(0, 1.5, 1.15), 1.9, CLK.Gold, "ClockBig", CLK.Gold, true)
	end
	-- парящие золотые часы
	local orb = r:Orbit("OrbitClocks", T, CF(0, 0.5, 0), 2.6, 0, 0.2, CLK.Gold)
	local n = lv >= 5 and 5 or (lv >= 3 and 4 or 3)
	for i = 0, n - 1 do
		local ang = i / n * PI * 2
		miniClock(r, orb, CF(math.cos(ang) * 2.6, math.sin(ang * 2) * 0.4, math.sin(ang) * 2.6) * ANG(0, -ang + PI / 2, 0), 0.3)
	end
	-- вращающиеся золотые кольца (с 4 ур.)
	if lv >= 4 then
		local ringHub = r:Orbit("OrbitGoldRing", T, CF(0, -0.2, 0), 2.1, 0, 0.2, CLK.Gold)
		Kit.ring(r, ringHub, ANG(rad(90), 0, 0), 2.1, 16, 0.08, 0.14, CLK.Gold, M.Metal, function(k)
			return k % 4 == 3
		end)
	end
	-- шестерни бури (видны только во время «Временной бури»)
	local storm = r:Orbit("OrbitStormGears", T, CF(0, 0.2, 0), 3.2, 0, 0.2, CLK.Gold)
	local before = #r.Model:GetChildren()
	for i = 0, 5 do
		local ang = i / 6 * PI * 2
		gear(r, storm, nil, CF(math.cos(ang) * 3.2, math.sin(ang * 3) * 0.5, math.sin(ang) * 3.2) * ANG(0, -ang, 0), 0.3, 0.1, CLK.Gold, CLK.Orange)
	end
	local all = r.Model:GetChildren()
	for i = before + 1, #all do
		local d = all[i]
		if d:IsA("BasePart") then
			d:SetAttribute("StormFX", d.Transparency)
			d.Transparency = 1
		end
	end

	-- ХРОНОСЕКИРА в правой руке
	chronoaxe(r, RA, lv)
	levelAura(r, lv, CLK.Orange)
	return r:Finish(1.45, { RS = { 20, 0, 0 }, LS = { 10, 0, -5 } })
end

local Builders = {
	VoidSoldier = VoidSoldier,
	ShadowArcher = ShadowArcher,
	LostMage = LostMage,
	VoidKnight = VoidKnight,
	DarkGunner = DarkGunner,
	AbyssReaper = AbyssReaper,
	CorruptedSamurai = CorruptedSamurai,
	EclipseGuardian = EclipseGuardian,
	FallenAngel = FallenAngel,
	VoidEmperor = VoidEmperor,
	AbyssOverlord = AbyssOverlord,
	RiftScout = RiftScout,
	CrystalHunter = CrystalHunter,
	VoidPuppeteer = VoidPuppeteer,
	Starbreaker = Starbreaker,
	RiftMonarch = RiftMonarch,
	RealityDestroyer = RealityDestroyer,
	BloodAcolyte = BloodAcolyte,
	CrimsonGunslinger = CrimsonGunslinger,
	MoonWitch = MoonWitch,
	BloodfangWarlord = BloodfangWarlord,
	LunarSeraph = LunarSeraph,
	CrimsonEclipse = CrimsonEclipse,
	CursedClockmaker = CursedClockmaker,
}

-- Построить модель юнита. Модель стоит в начале координат, ноги на высоте -HipHeight.
-- Аура редкости у ног: Epic — фиолетовые искры, Legendary — золото, Mythic — красно-фиолетовый вихрь
local applyLevelSkin
local UNIT_RARITY = {
	AbyssReaper = "Epic", CorruptedSamurai = "Epic", VoidPuppeteer = "Epic", MoonWitch = "Epic",
	EclipseGuardian = "Legendary", FallenAngel = "Legendary", Starbreaker = "Legendary", BloodfangWarlord = "Legendary",
	VoidEmperor = "Mythic", AbyssOverlord = "Mythic", RiftMonarch = "Mythic", LunarSeraph = "Mythic",
	RealityDestroyer = "Secret", CrimsonEclipse = "Secret", CursedClockmaker = "Secret",
}
local RARITY_AURA = {
	Epic = { Color = ColorSequence.new(Color3.fromRGB(170, 80, 255)), Rate = 3, Size = 0.22 },
	Legendary = { Color = ColorSequence.new(Color3.fromRGB(255, 205, 70), Color3.fromRGB(190, 110, 255)), Rate = 5, Size = 0.28 },
	Mythic = { Color = ColorSequence.new(Color3.fromRGB(255, 50, 150), Color3.fromRGB(150, 60, 255)), Rate = 8, Size = 0.34 },
	Secret = { Color = ColorSequence.new(Color3.fromRGB(255, 20, 40), Color3.fromRGB(20, 0, 0)), Rate = 14, Size = 0.45 },
}

-- Материалы меняются с уровнем: 1 — потёртый ржавый металл, 2–3 — металл, 4–5 — блестящая фольга,
-- на 5-м уровне броня ещё и подсвечивается цветом редкости.
local RARITY_TINT = {
	Epic = Color3.fromRGB(150, 80, 230), Legendary = Color3.fromRGB(230, 180, 60),
	Mythic = Color3.fromRGB(150, 70, 230), Secret = Color3.fromRGB(230, 30, 40),
}
applyLevelSkin = function(model, lv, rarity)
	local tint = RARITY_TINT[rarity or ""]
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and d.Transparency < 1 then
			local mat = d.Material
			if mat == M.Metal then
				if lv == 1 then
					d.Material = Enum.Material.CorrodedMetal
				elseif lv >= 4 then
					d.Material = Enum.Material.Foil
					if lv >= 5 and tint then
						d.Color = d.Color:Lerp(tint, 0.1)
					end
				end
			elseif mat == M.Plastic and lv == 1 then
				d.Material = Enum.Material.Plastic
			elseif mat == M.Fabric and lv >= 5 and tint then
				d.Color = d.Color:Lerp(tint, 0.06)
			end
		end
	end
end

-- Хелперы для модулей-расширений (HalloweenModels): тот же R6-стиль и те же детали
UnitModels.H = {
	figure = figure, eyes = eyes, chest = chest, belt = belt, tassets = tassets, robe = robe, mantle = mantle,
	hood = hood, helm = helm, wizardHat = wizardHat, crown = crown, kabuto = kabuto,
	plateShoulders = plateShoulders, bigShoulders = bigShoulders, bracers = bracers, greaves = greaves, wings = wings,
	muzzle = muzzle, blade = blade, shaft = shaft, staff = staff, scythe = scythe, spear = spear, hammer = hammer,
	axe = axe, bow = bow, quiver = quiver, crossbow = crossbow, rifle = rifle, dagger = dagger, shield = shield,
	capeWith = capeWith, levelAura = levelAura, octa = octa, gear = gear, clockFace = clockFace, miniClock = miniClock,
	rgb = rgb, GRIP = GRIP, AIM = AIM, M = M, P = P, AC = AC,
}

-- Регистрация юнита из модуля-расширения
function UnitModels.Register(unitId, builder, rarity)
	Builders[unitId] = builder
	UNIT_RARITY[unitId] = rarity
end

function UnitModels.Has(unitId)
	return Builders[unitId] ~= nil
end

function UnitModels.Build(unitId, level)
	local builder = Builders[unitId]
	if not builder then
		error("Unknown unit " .. tostring(unitId))
	end
	local lv = math.clamp(level or 1, 1, 5)
	local rig = builder(lv)
	rig.Model.Name = unitId
	applyLevelSkin(rig.Model, lv, UNIT_RARITY[unitId])
	Kit.Calm(rig.Model)
	local aura = not UnitModels.Lite and RARITY_AURA[UNIT_RARITY[unitId] or ""]
	if aura then
		local at = Instance.new("Attachment")
		at.Name = "AuraPoint"
		at.Position = V(0, -rig.HipHeight + 0.2, 0)
		at.Parent = rig.Root
		local e = Instance.new("ParticleEmitter")
		e.Name = "RarityAura"
		e.Color = aura.Color
		e.LightEmission = 1
		e.LightInfluence = 0
		e.Rate = aura.Rate
		e.Lifetime = NumberRange.new(1.2, 2)
		e.Speed = NumberRange.new(0.6, 1.6)
		e.EmissionDirection = Enum.NormalId.Top
		e.SpreadAngle = Vector2.new(70, 70)
		e.Acceleration = V(0, 1.2, 0)
		e.RotSpeed = NumberRange.new(-90, 90)
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, aura.Size), NumberSequenceKeypoint.new(1, 0) })
		e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
		e.Parent = at
	end
	rig.Model:SetAttribute("UnitId", unitId)
	rig.Model:SetAttribute("Level", level or 1)
	return rig
end

-- Хэллоуинские юниты, союзники-призывы и руны
require(script.Parent:WaitForChild("HalloweenModels"))(UnitModels)

return UnitModels
