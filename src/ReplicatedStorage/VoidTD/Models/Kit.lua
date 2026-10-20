--!nocheck
-- VOID TD :: Models/Kit
-- Основа процедурных моделей: класс Rig (R6-скелет на Motor6D + приваренные детали) и угловатый набор
-- деталей в стиле концепта: блоки с фаской и светлым кантом, клинья-шипы, ромбы, ступенчатые наплечники,
-- рваная ткань, цепи. Используется Units (юниты, союзники), Enemies (враги) и Cases.
--
-- ФЛАГИ
--   Kit.Lite (bool) / Kit.IsLite()  облегчённый режим (клиент): фаска = 1 брусок, без лохмотьев, частиц, света,
--                                   шлейфов, лиц. UnitModels.Lite и EnemyModels.Lite читают/пишут Kit.Lite.
--   Kit.Cheap (bool)                дешёвая фаска (2 детали) и плоские шипы — для толп врагов и союзников;
--                                   выставляется только на время сборки (Enemies.Build / Units.BuildAlly).
--   Kit.WithCheap(on, fn, ...) -> ...   вызов fn с Kit.Cheap = on; прежнее значение восстанавливается и при ошибке
-- ПАЛИТРЫ
--   Kit.Colors (= AC) Armor ArmorMid Edge Cloth ClothDark;  Kit.C  Neon Steel;  Kit.P — палитра юнитов
--   (Black Coal Dark Steel Gray Pale Violet DeepViolet Purple Neon NeonSoft NeonPink Maroon Crimson White
--   Gold DarkGold Skin);  Kit.M Plastic(=SmoothPlastic) Metal Neon Fabric Slate Glass Wood Grass Foil CorrodedMetal;  Kit.rgb
--
-- RIG  (r = Kit.Rig.new(o); все offset/pivot — в локальных координатах детали-основы limb, до масштаба)
--   Kit.Rig.new{Name, HeadSize=V(1.3)^3, Torso, TorsoMat, Head, Arm, Leg, RoundHead} -> R6: HumanoidRootPart (якорь),
--       Torso, Head, "Right Arm", "Left Arm", "Right Leg", "Left Leg"; моторы Root Neck RS LS RH LH
--   Kit.Rig.bare(name)                    пустой rig (только Model и таблицы) — для существ (Enemies/Base)
--   поля: Model Root Torso Head RArm LArm RLeg LLeg HeadSize Motors{name->Motor6D} Base{name->C0} Parts{...}
--         после Finish: Scale HipHeight Height Idle Muzzle (по умолчанию RArm)
--   r:Add(limb, class, size, offset, color, mat, props) -> part   деталь "Detail" на Weld к limb (props копируются)
--   r:Box / r:Wedge (limb, size, offset, color, mat, props)        Part / WedgePart
--   r:Neon(limb, size, offset, color=P.Neon, props)                неоновый брусок
--   r:Cyl(limb, len, d, offset, color, mat, axis="X"|"Y"|"Z", props)   цилиндр длиной len вдоль оси
--   r:Ball(limb, d, offset, color, mat, props)                     шар
--   r:Sphere(limb, size, offset, color, mat, props)                эллипсоид (SpecialMesh добавляется в Finish)
--   r:Seg(limb, a, b, thick, color, mat, props) -> part   брусок a..b; thick число или V2(x,y); props.Round -> цилиндр
--   r:Rod(limb, a, b, d, color, mat, props)                        круглый стержень a..b
--   r:Chain(limb, points, thick, color, mat, taper?, round?) -> {parts}
--   r:Joint(name, limb, size, pivot, fromPivot, color, mat) -> part   подвижная деталь на своём Motor6D name
--   r:Orbit(name, limb, offset, radius, count, size, color=P.Neon, mat=Neon, transp=0) -> hub
--                                    невидимый узел-мотор (имя "Orbit*" — крутится по Y в Anims) + count кристаллов
--   r:Cape(width, length, color=P.DeepViolet, tatter?) -> cape     плащ на моторах "Cape" + "Cape2", золотые застёжки
--   r:Glow(part, color=P.Neon, range=8, brightness=1.5) -> PointLight | nil (Lite)
--   r:Sparkles(part, color, {Rate=8, Size=0.25, LifeMin=0.5, LifeMax=1, SpeedMin=0.5, SpeedMax=1.5, Up?}) -> emitter | nil (Lite)
--   r:WeaponTrail(limb, a, b, color=P.NeonSoft)                    шлейф "WeaponTrail" (Enabled=false), создаётся в Finish; не в Lite
--   r:Eyes(color, {Y, Spacing, Size, Inset, LeftLift, Tilt, RightSize})   неоновые глаза на Head
--   r:Face{Mood="angry"|"calm"|"old", EyeY, Spacing, BrowColor, MouthColor, Mouth}   брови/рот (не в Lite)
--   r:Hands(color, mat)  r:Horn(limb, side, base, size, color)  r:Pouch(limb, offset, color)
--   r:Pauldron(limb, side, size, color, rim, lift, rimMat)  r:Sword(limb, {Length, Width, Y, ...}) -> blade (ставит Muzzle)
--   r:Mark() -> n ; r:Since(n) -> {parts}   все детали, созданные после метки (явная пометка, напр. StormFX)
--   r:BakePose(pose)                 повернуть конечности в позу {Motor = {x,y,z}} (градусы) прямо в CFrame деталей
--   r:Finish(scale=1, idle?) -> r    ScaleTo (частицы/свет — явно, одинаково в Studio и моке), меши эллипсоидов, шлейфы,
--                                    Base = C0 (до позы), BakePose(idle), HipHeight = 3*scale (+ атрибут), Height, Idle, Muzzle
-- ДЕТАЛИ (r — rig, limb — деталь-основа; возвращают список созданных деталей, если не сказано иное)
--   Kit.bevel(r, limb, size, cf, color, edge?, mat=Metal, e?) -> parts, edgePart
--        3 тёмных бруска + светлый внутри (кант по 12 рёбрам); Cheap: брусок + кант сверху (кант — последний в списке);
--        Lite или edge == false: один брусок, edgePart = nil
--   Kit.spike(r, limb, base, tip, w, color, mat=Plastic, flat?, thick=w*0.34)   шип из клиньев (крестовой, если не flat и не Cheap)
--   Kit.bar(r, limb, a, b, t, color, mat=Plastic) -> part           брусок a..b с запасом на стыках
--   Kit.hornA(r, limb, pts, t0, color, mat)                         рог: сужающиеся бруски + шип
--   Kit.gem(r, limb, s, cf, color=C.Neon, frame?)                   кристалл-ромб (в оправе, если frame)
--   Kit.tatter(r, limb, y, z, w, n, color, mat=Fabric, seed=0)      рваный край из n лоскутов вниз ({} в Lite)
--   Kit.pauldron(r, A, side, s, color, edge, glow?, spikes=2)       ступенчатый наплечник (side 1 правый, -1 левый)
--   Kit.bootA(r, L, color, edge, w=1.15)                            латный сапог
--   Kit.squareRing(r, limb, cf, w, t, color)                        квадратное кольцо из 4 брусков
--   Kit.chain(r, limb, n, size, color=C.Steel, at=CF())             цепь из n звеньев вниз
--   Kit.crack(r, limb, pts, thick=0.08, color=C.Neon)               светящаяся трещина-ломаная
--   Kit.ring(r, limb, cf, radius, count, thick, depth, color, mat=Metal, skip?)   кольцо в плоскости XY cf (skip(i) — разрыв)
--   Kit.hide(parts, target?) -> parts   спрятать (Transparency 1, атрибут "PT" = целевая прозрачность для Reveal)
--   Kit.join(...) -> parts              склеить списки (nil пропускаются)
--   Kit.Calm(root, amount=0.3)          приглушить неон/свет/частицы; один раз на модель (атрибут "Calmed"),
--                                       вложенные уже приглушённые модели пропускаются

local Kit = {}

local V = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles
local rad = math.rad
local PI = math.pi

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end
Kit.rgb = rgb

local MAT = Enum.Material
local M = {
	Plastic = MAT.SmoothPlastic, Metal = MAT.Metal, Neon = MAT.Neon, Fabric = MAT.Fabric, Slate = MAT.Slate,
	Glass = MAT.Glass, Wood = MAT.Wood, Grass = MAT.Grass, Foil = MAT.Foil, CorrodedMetal = MAT.CorrodedMetal,
}
Kit.M = M

local C = { Neon = rgb(180, 80, 255), Steel = rgb(110, 110, 128) }
Kit.C = C

-- палитра брони (AC)
local AC = {
	Armor = rgb(34, 32, 42), ArmorMid = rgb(52, 50, 64), Edge = rgb(122, 118, 138),
	Cloth = rgb(62, 30, 104), ClothDark = rgb(36, 17, 62),
}
Kit.Colors = AC

-- палитра юнитов (UnitModels.Palette)
local P = {
	Black = rgb(20, 18, 26), Coal = rgb(33, 30, 41), Dark = rgb(48, 44, 58), Steel = rgb(74, 72, 86),
	Gray = rgb(108, 106, 120), Pale = rgb(168, 163, 180), Violet = rgb(70, 30, 110), DeepViolet = rgb(42, 18, 66),
	Purple = rgb(112, 52, 172), Neon = rgb(180, 80, 255), NeonSoft = rgb(210, 150, 255), NeonPink = rgb(255, 60, 170),
	Maroon = rgb(88, 20, 36), Crimson = rgb(140, 28, 48), White = rgb(245, 240, 255), Gold = rgb(200, 156, 60),
	DarkGold = rgb(140, 104, 40), Skin = rgb(140, 132, 146),
}
Kit.P = P

Kit.Lite = false
Kit.Cheap = false
function Kit.IsLite()
	return Kit.Lite == true
end

-- Вызвать fn(...) с заданным Kit.Cheap; прежнее значение восстанавливается и при ошибке (трассировка сохраняется)
function Kit.WithCheap(on, fn, ...)
	local prev = Kit.Cheap
	Kit.Cheap = on == true
	local res = table.pack(xpcall(fn, debug.traceback, ...))
	Kit.Cheap = prev
	if not res[1] then
		error(res[2], 0)
	end
	return table.unpack(res, 2, res.n)
end
local function lite()
	return Kit.Lite == true
end

------------------------------------------------------------------------
-- RIG
------------------------------------------------------------------------
local Rig = {}
Rig.__index = Rig
Kit.Rig = Rig

local AXIS = { X = CF(), Y = ANG(0, 0, rad(90)), Z = ANG(0, rad(90), 0) }
local LIMB_MOTORS = { Root = true, Neck = true, RS = true, LS = true, RH = true, LH = true }

local function newPart(className, size, color, material)
	local p = Instance.new(className)
	p.Size = size
	p.Color = color or P.Dark
	p.Material = material or M.Plastic
	p.Anchored = false
	p.CanCollide = false
	p.CanTouch = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	return p
end

local function copyProps(props)
	return props and table.clone(props) or {}
end

function Rig.bare(name)
	local self = setmetatable({}, Rig)
	local model = Instance.new("Model")
	model.Name = name or "Unit"
	self.Model = model
	self.Motors = {}
	self.Base = {}
	self.Parts = {}
	self.Pending = {}
	self.PendingTrails = {}
	return self
end

function Rig.new(o)
	o = o or {}
	local self = Rig.bare(o.Name or "Unit")
	local model = self.Model
	local root = newPart("Part", V(2, 2, 1), Color3.new(), M.Plastic)
	root.Name = "HumanoidRootPart"
	root.Transparency = 1
	root.Anchored = true
	root.CFrame = CF()
	root.Parent = model
	self.Root = root

	local hs = o.HeadSize or V(1.3, 1.3, 1.3)
	self.HeadSize = hs
	local function limb(name, size, cf, color, mat)
		local p = newPart("Part", size, color, mat)
		p.Name = name
		p.CFrame = cf
		p.Parent = model
		self.Parts[#self.Parts + 1] = p
		return p
	end
	self.Torso = limb("Torso", V(2, 2, 1), CF(), o.Torso or P.Dark, o.TorsoMat)
	self.Head = limb("Head", hs, CF(0, 1 + hs.Y / 2, 0), o.Head or P.Skin)
	self.RArm = limb("Right Arm", V(1, 2, 1), CF(1.5, 0, 0), o.Arm or o.Torso or P.Dark)
	self.LArm = limb("Left Arm", V(1, 2, 1), CF(-1.5, 0, 0), o.Arm or o.Torso or P.Dark)
	self.RLeg = limb("Right Leg", V(1, 2, 1), CF(0.5, -2, 0), o.Leg or P.Black)
	self.LLeg = limb("Left Leg", V(1, 2, 1), CF(-0.5, -2, 0), o.Leg or P.Black)

	self:Motor("Root", root, self.Torso, CF(), CF())
	self:Motor("Neck", self.Torso, self.Head, CF(0, 1, 0), CF(0, -hs.Y / 2, 0))
	self:Motor("RS", self.Torso, self.RArm, CF(1.5, 0.5, 0), CF(0, 0.5, 0))
	self:Motor("LS", self.Torso, self.LArm, CF(-1.5, 0.5, 0), CF(0, 0.5, 0))
	self:Motor("RH", self.Torso, self.RLeg, CF(0.5, -1, 0), CF(0, 1, 0))
	self:Motor("LH", self.Torso, self.LLeg, CF(-0.5, -1, 0), CF(0, 1, 0))
	if o.RoundHead then
		-- круглая голова-цилиндр; детали крепятся к невидимому кубу Head
		self.Head.Transparency = 1
		self:Cyl(self.Head, hs.Y, math.max(hs.X, hs.Z), CF(), o.Head or P.Skin, M.Plastic, "Y").Name = "HeadShape"
	end
	return self
end

-- Motor6D между готовыми деталями (родитель — Part0)
function Rig:Motor(name, p0, p1, c0, c1)
	local m = Instance.new("Motor6D")
	m.Name = name
	m.Part0 = p0
	m.Part1 = p1
	m.C0 = c0
	m.C1 = c1
	m.Parent = p0
	self.Motors[name] = m
	return m
end

-- Деталь, приваренная к limb; offset — в локальных координатах limb
function Rig:Add(limb, className, size, offset, color, material, props)
	local p = newPart(className, size, color, material)
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
	self.Parts[#self.Parts + 1] = p
	return p
end

function Rig:Box(limb, size, offset, color, material, props)
	return self:Add(limb, "Part", size, offset, color, material, props)
end

function Rig:Wedge(limb, size, offset, color, material, props)
	return self:Add(limb, "WedgePart", size, offset, color, material, props)
end

function Rig:Neon(limb, size, offset, color, props)
	return self:Add(limb, "Part", size, offset, color or P.Neon, M.Neon, props)
end

function Rig:Cyl(limb, len, d, offset, color, material, axis, props)
	local pr = copyProps(props)
	pr.Shape = Enum.PartType.Cylinder
	return self:Add(limb, "Part", V(len, d, d), offset * AXIS[axis or "X"], color, material, pr)
end

function Rig:Ball(limb, d, offset, color, material, props)
	local pr = copyProps(props)
	pr.Shape = Enum.PartType.Ball
	return self:Add(limb, "Part", V(d, d, d), offset, color, material, pr)
end

-- Эллипсоид: SpecialMesh(Sphere) ставится в Finish после масштабирования (иначе масштаб применится дважды)
function Rig:Sphere(limb, size, offset, color, material, props)
	local p = self:Add(limb, "Part", size, offset, color, material, props)
	self.Pending[#self.Pending + 1] = p
	return p
end

-- Брусок от a до b (точки в координатах limb)
function Rig:Seg(limb, a, b, thick, color, material, props)
	local dir = b - a
	local len = dir.Magnitude
	local tx, ty = thick, thick
	if typeof(thick) == "Vector2" then
		tx, ty = thick.X, thick.Y
	end
	local cf
	if len < 1e-4 then
		cf, len = CF(a), 0.05
	else
		local up = math.abs(dir.Y / len) > 0.98 and V(0, 0, 1) or V(0, 1, 0)
		cf = CFrame.lookAt((a + b) / 2, b, up)
	end
	if props and props.Round then
		local pr = copyProps(props)
		pr.Round = nil
		pr.Shape = Enum.PartType.Cylinder
		return self:Add(limb, "Part", V(len, tx, tx), cf * AXIS.Z, color, material, pr)
	end
	return self:Add(limb, "Part", V(tx, ty, len), cf, color, material, props)
end

function Rig:Rod(limb, a, b, d, color, material, props)
	local pr = copyProps(props)
	pr.Round = true
	return self:Seg(limb, a, b, d, color, material, pr)
end

-- Цепочка брусков по точкам (рога, щупальца, изогнутые лезвия)
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

-- Подвижная деталь на собственном Motor6D: C0 = pivot (в limb), C1 = fromPivot:Inverse()
function Rig:Joint(name, limb, size, pivot, fromPivot, color, material)
	local p = newPart("Part", size, color, material)
	p.Name = name
	p.CFrame = limb.CFrame * pivot * fromPivot
	p.Parent = self.Model
	self.Parts[#self.Parts + 1] = p
	self:Motor(name, limb, p, pivot, fromPivot:Inverse())
	return p
end

-- Кольцо вращающихся деталей; мотор с именем "Orbit*" крутится вокруг своей оси Y (Anims.Apply)
function Rig:Orbit(name, limb, offset, radius, count, size, color, material, transparency)
	local hub = self:Joint(name, limb, V(0.2, 0.2, 0.2), offset, CF(), P.Black)
	hub.Transparency = 1
	for i = 0, count - 1 do
		local a = i / count * PI * 2
		self:Add(hub, "Part", V(size, size * 1.3, size), CF(math.cos(a) * radius, math.sin(a * 2) * 0.15, math.sin(a) * radius) * ANG(rad(45), a, rad(30)),
			color or P.Neon, material or M.Neon, { Transparency = transparency or 0 })
	end
	return hub
end

-- Плащ из двух частей на моторах Cape/Cape2 (нижняя колышется с запаздыванием)
function Rig:Cape(width, length, color, tatter)
	local T = self.Torso
	color = color or P.DeepViolet
	local l1 = length * 0.58
	local l2 = length - l1
	local cape = self:Joint("Cape", T, V(width, l1, 0.12), CF(0, 0.95, 0.58), ANG(rad(7), 0, 0) * CF(0, -l1 / 2, 0.02), color, M.Fabric)
	local cape2 = self:Joint("Cape2", cape, V(width * 0.98, l2, 0.12), CF(0, -l1 / 2, 0), CF(0, -l2 / 2, 0), color, M.Fabric)
	for _, s in ipairs({ -1, 1 }) do
		self:Box(T, V(0.3, 0.3, 0.2), CF(0.75 * s, 0.85, 0.55), P.Gold, M.Metal) -- застёжки
	end
	if tatter and not lite() then
		for i = -2, 2 do
			local seed = i + 3
			local h = 0.4 + ((seed * 37) % 5) * 0.12
			self:Wedge(cape2, V(width / 5.2, h, 0.12), CF(i * width / 5, -l2 / 2 - h / 2 + 0.02, 0) * ANG(0, 0, PI), color, M.Fabric)
		end
		self:Box(cape, V(width + 0.04, 0.12, 0.14), CF(0, l1 / 2 - 0.25, 0), color:Lerp(P.Black, 0.4), M.Fabric) -- тёмная кайма
		self:Box(cape2, V(width * 0.98 + 0.04, 0.1, 0.14), CF(0, -l2 / 2 + 0.15, 0), color:Lerp(P.White, 0.25), M.Fabric) -- светлый подол
	end
	return cape
end

function Rig:Glow(part, color, range, brightness)
	if lite() then
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
	if lite() then
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
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, o.Size or 0.25), NumberSequenceKeypoint.new(1, 0) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	if o.Up then
		e.EmissionDirection = Enum.NormalId.Top
		e.SpreadAngle = Vector2.new(25, 25)
		e.Acceleration = V(0, o.Up, 0)
	end
	e.Parent = part
	return e
end

-- Шлейф оружия (Renderer включает его во время анимаций атаки)
function Rig:WeaponTrail(limb, a, b, color)
	if lite() then
		return
	end
	self.PendingTrails[#self.PendingTrails + 1] = { limb, a, b, color or P.NeonSoft }
end

function Rig:Eyes(color, o)
	o = o or {}
	local hs = self.HeadSize
	local y, sp = o.Y or 0.08, o.Spacing or 0.3
	local size = o.Size or V(0.28, 0.14, 0.06)
	local z = -hs.Z / 2 - 0.02 + (o.Inset or 0)
	local l = self:Neon(self.Head, size, CF(-sp, y + (o.LeftLift or 0), z) * ANG(0, 0, rad(o.Tilt or 0)), color)
	local r = self:Neon(self.Head, o.RightSize or size, CF(sp, y, z) * ANG(0, 0, rad(-(o.Tilt or 0))), color)
	return l, r
end

-- Брови и рот: Mood "angry" | "calm" | "old"
function Rig:Face(o)
	if lite() then
		return
	end
	o = o or {}
	local z = -self.HeadSize.Z / 2 - 0.03
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

function Rig:Hands(color, material)
	if lite() then
		return
	end
	for _, A in ipairs({ self.RArm, self.LArm }) do
		self:Sphere(A, V(1.08, 0.52, 1.08), CF(0, -0.93, 0), color or P.Coal, material or M.Plastic)
	end
end

function Rig:Horn(limb, side, base, size, color)
	local s = size or 1
	color = color or P.Black
	local pts = { base, base + V(0.35 * side, 0.45, 0.05) * s, base + V(0.55 * side, 0.95, 0.2) * s, base + V(0.45 * side, 1.4, 0.45) * s }
	self:Ball(limb, 0.4 * s, CF(base), color)
	self:Chain(limb, pts, 0.34 * s, color, M.Plastic, 0.72, true)
	local d = pts[4] - pts[3]
	self:Rod(limb, pts[4], pts[4] + d.Unit * 0.35 * s, 0.12 * s, color, M.Plastic)
end

function Rig:Pouch(limb, offset, color)
	color = color or P.Maroon
	self:Box(limb, V(0.42, 0.42, 0.28), offset, color, M.Fabric)
	self:Box(limb, V(0.44, 0.14, 0.3), offset * CF(0, 0.2, -0.01), color:Lerp(P.Black, 0.35), M.Fabric)
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

-- Классический меч (клинок вперёд по -Z руки); ставит Muzzle на остриё
function Rig:Sword(limb, o)
	o = o or {}
	local len, w, y = o.Length or 3, o.Width or 0.42, o.Y or -1.05
	local guard = o.Guard or P.Steel
	self:Cyl(limb, 0.9, 0.26, CF(0, y, 0.05), o.Handle or P.Black, M.Fabric, "Z")
	self:Ball(limb, 0.4, CF(0, y, 0.55), o.Pommel or guard, M.Metal)
	local gw = o.GuardWidth or w + 0.6
	self:Box(limb, V(0.3, gw, 0.26), CF(0, y, -0.45), guard, M.Metal)
	self:Ball(limb, 0.34, CF(0, y + gw / 2, -0.45), guard, M.Metal)
	self:Ball(limb, 0.34, CF(0, y - gw / 2, -0.45), guard, M.Metal)
	self:Ball(limb, 0.34, CF(0, y, -0.45), o.Gem or o.Edge or P.Neon, M.Neon)
	local blade = self:Box(limb, V(0.14, w, len), CF(0, y, -0.58 - len / 2), o.Blade or P.Gray, o.BladeMat or M.Metal)
	blade.Name = "Blade"
	if not o.Core then
		self:Box(limb, V(0.16, math.max(w * 0.22, 0.07), len * 0.72), CF(0, y, -0.58 - len * 0.42), P.Black, M.Metal)
	end
	for i = 1, (o.Runes or 0) do
		self:Neon(limb, V(0.17, 0.1, 0.18), CF(0, y - w * 0.22, -0.58 - len * (0.15 + i * 0.16)), o.Edge or P.Neon)
	end
	self:WeaponTrail(limb, V(0, y, -0.75), V(0, y, -0.58 - len), o.Edge or o.Core or P.NeonSoft)
	self:Wedge(limb, V(0.14, w, w * 1.3), CF(0, y, -0.58 - len - w * 0.65) * ANG(0, PI, 0), o.Blade or P.Gray, o.BladeMat or M.Metal)
	if o.Edge then
		self:Neon(limb, V(0.16, 0.09, len), CF(0, y + w / 2 - 0.02, -0.58 - len / 2), o.Edge)
	end
	if o.Core then
		self:Neon(limb, V(0.17, math.max(w * 0.25, 0.08), len * 0.8), CF(0, y, -0.58 - len * 0.45), o.Core)
	end
	self.Muzzle = self:Box(limb, V(0.2, 0.2, 0.2), CF(0, y, -0.58 - len), P.Black, M.Plastic, { Transparency = 1, Name = "Muzzle" })
	return blade
end

-- Метки для явной пометки деталей (вместо порядка GetChildren)
function Rig:Mark()
	return #self.Parts
end

function Rig:Since(mark)
	return table.move(self.Parts, mark + 1, #self.Parts, 1, {})
end

-- Поворачивает конечности в позу прямо в CFrame деталей (ViewportFrame и призрак размещения выглядят как в игре)
function Rig:BakePose(pose)
	if not pose then
		return
	end
	local attached = {}
	for _, d in ipairs(self.Model:GetDescendants()) do
		if (d:IsA("Weld") or (d:IsA("Motor6D") and not LIMB_MOTORS[d.Name])) and d.Part0 and d.Part1 then
			local list = attached[d.Part0]
			if not list then
				list = {}
				attached[d.Part0] = list
			end
			list[#list + 1] = d.Part1
		end
	end
	-- детерминированный порядок: сначала конечности, затем прочие моторы по имени
	local names = {}
	for name in pairs(pose) do
		if name ~= "Root" and self.Motors[name] then
			names[#names + 1] = name
		end
	end
	table.sort(names, function(a, b)
		local la, lb = LIMB_MOTORS[a] and 0 or 1, LIMB_MOTORS[b] and 0 or 1
		if la ~= lb then
			return la < lb
		end
		return a < b
	end)
	for _, name in ipairs(names) do
		local ang = pose[name]
		local m = self.Motors[name]
		local rot = ANG(rad(ang[1] or 0), rad(ang[2] or 0), rad(ang[3] or 0))
		local delta = (m.Part0.CFrame * m.C0 * rot * m.C1:Inverse()) * m.Part1.CFrame:Inverse()
		local seen = {}
		local function move(p)
			if seen[p] then
				return
			end
			seen[p] = true
			p.CFrame = delta * p.CFrame
			for _, c in ipairs(attached[p] or {}) do
				move(c)
			end
		end
		move(m.Part1)
		m.C0 = m.C0 * rot
	end
end

-- ScaleTo в Roblox масштабирует и частицы/свет, а мок — нет. Чтобы результат был одинаковым, значения
-- эффектов запоминаются до ScaleTo и после него выставляются явно (исходное * scale); порядок детей не меняется.
local FX_CLASSES = { ParticleEmitter = true, PointLight = true, SpotLight = true, SurfaceLight = true, Beam = true }

local function scaleSeq(seq, f)
	local kps = {}
	for i, k in ipairs(seq.Keypoints) do
		kps[i] = NumberSequenceKeypoint.new(k.Time, k.Value * f, k.Envelope * f)
	end
	return NumberSequence.new(kps)
end

local function fxSnapshot(d)
	if d:IsA("ParticleEmitter") then
		return { d.Size, d.Speed, d.Acceleration }
	elseif d:IsA("Beam") then
		return { d.Width0, d.Width1 }
	end
	return { d.Range }
end

local function fxRestore(d, s, f)
	if d:IsA("ParticleEmitter") then
		d.Size = scaleSeq(s[1], f)
		d.Speed = NumberRange.new(s[2].Min * f, s[2].Max * f)
		d.Acceleration = s[3] * f
	elseif d:IsA("Beam") then
		d.Width0 = s[1] * f
		d.Width1 = s[2] * f
	else
		d.Range = math.min(s[1] * f, 60)
	end
end

function Rig:Finish(scale, idle)
	local model = self.Model
	model.PrimaryPart = self.Root
	scale = scale or 1
	if scale ~= 1 then
		local fx = {}
		for _, d in ipairs(model:GetDescendants()) do
			if FX_CLASSES[d.ClassName] then
				fx[#fx + 1] = { d, fxSnapshot(d) }
			end
		end
		model:ScaleTo(scale)
		for _, e in ipairs(fx) do
			fxRestore(e[1], e[2], scale)
		end
	end
	for _, p in ipairs(self.Pending) do
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
	end
	self.Pending = {}
	for _, t in ipairs(self.PendingTrails) do
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
	-- Base — C0 в позе покоя (до BakePose): Anims считает C0 = Base * поза
	for name, m in pairs(self.Motors) do
		self.Base[name] = m.C0
	end
	self:BakePose(idle)
	self.HipHeight = 3 * scale
	model:SetAttribute("HipHeight", self.HipHeight)
	if self.HeadSize and not self.Height then
		self.Height = (3 + 1 + self.HeadSize.Y + 0.6) * scale
	end
	self.Idle = idle or {}
	self.Muzzle = self.Muzzle or self.RArm
	return self
end

------------------------------------------------------------------------
-- УГЛОВАТЫЕ ДЕТАЛИ
------------------------------------------------------------------------

-- Острый шип из клиньев: flat = 2 клина (плоский коготь/зуб), иначе 4 (крестовой шип)
local function spike(r, limb, base, tip, w, color, mat, flat, thick)
	local dir = tip - base
	local h = dir.Magnitude
	if h < 1e-4 then
		return {}
	end
	local up = math.abs(dir.Y / h) > 0.98 and V(0, 0, 1) or V(0, 1, 0)
	local F = CFrame.lookAt(base, tip, up) * ANG(-PI / 2, 0, 0)
	local t = thick or w * 0.34
	mat = mat or M.Plastic
	local parts = {}
	local function fin(rot)
		parts[#parts + 1] = r:Wedge(limb, V(t, h, w / 2), F * rot * CF(0, h / 2, -w / 4), color, mat)
		parts[#parts + 1] = r:Wedge(limb, V(t, h, w / 2), F * rot * CF(0, h / 2, w / 4) * ANG(0, PI, 0), color, mat)
	end
	fin(CF())
	if not flat and not Kit.Cheap then
		fin(ANG(0, PI / 2, 0))
	end
	return parts
end
Kit.spike = spike

local function crack(r, limb, pts, thick, color)
	local parts = {}
	for i = 1, #pts - 1 do
		parts[#parts + 1] = r:Seg(limb, pts[i], pts[i + 1], thick or 0.08, color or C.Neon, M.Neon)
	end
	return parts
end
Kit.crack = crack

local function ring(r, limb, cf, radius, count, thick, depth, color, mat, skip)
	local parts = {}
	local segLen = 2 * PI * radius / count * 1.06
	for i = 0, count - 1 do
		if not (skip and skip(i)) then
			local a = i / count * PI * 2
			parts[#parts + 1] = r:Box(limb, V(segLen, thick, depth), cf * CF(math.cos(a) * radius, math.sin(a) * radius, 0) * ANG(0, 0, a + PI / 2), color, mat or M.Metal)
		end
	end
	return parts
end
Kit.ring = ring

function Kit.hide(parts, target)
	for _, p in ipairs(parts or {}) do
		p:SetAttribute("PT", target or p.Transparency)
		p.Transparency = 1
	end
	return parts or {}
end

function Kit.join(...)
	local out = {}
	for i = 1, select("#", ...) do
		local list = select(i, ...)
		if list then
			for _, p in ipairs(list) do
				out[#out + 1] = p
			end
		end
	end
	return out
end

-- Блок с фаской: три тёмных бруска «выкусывают» рёбра, светлый брусок внутри даёт тонкий кант по 12 рёбрам
local function bevel(r, limb, size, cf, color, edge, mat, e)
	mat = mat or M.Metal
	if lite() or edge == false then
		return { r:Box(limb, size, cf, color, mat) }, nil
	end
	local x, y, z = size.X, size.Y, size.Z
	e = e or math.min(0.09, math.min(x, y, z) * 0.2)
	if Kit.Cheap then
		local main = r:Box(limb, size, cf, color, mat)
		local strip = r:Box(limb, V(x + 0.03, e, z + 0.03), cf * CF(0, y / 2 - e * 0.62, 0), edge or AC.Edge, mat)
		return { main, strip }, strip
	end
	local parts = {
		r:Box(limb, V(x, y - 2 * e, z - 2 * e), cf, color, mat),
		r:Box(limb, V(x - 2 * e, y, z - 2 * e), cf, color, mat),
		r:Box(limb, V(x - 2 * e, y - 2 * e, z), cf, color, mat),
	}
	local inner = r:Box(limb, V(x - e, y - e, z - e), cf, edge or AC.Edge, mat)
	parts[4] = inner
	return parts, inner
end
Kit.bevel = bevel

local function bar(r, limb, a, b, t, color, mat)
	local d = b - a
	d = d.Magnitude > 1e-6 and d.Unit or V(0, 1, 0)
	local tt = typeof(t) == "Vector2" and math.min(t.X, t.Y) or t
	return r:Seg(limb, a - d * tt * 0.4, b + d * tt * 0.4, t, color, mat or M.Plastic)
end
Kit.bar = bar

function Kit.hornA(r, limb, pts, t0, color, mat)
	local parts = {}
	local t = t0
	for i = 1, #pts - 2 do
		parts[#parts + 1] = bar(r, limb, pts[i], pts[i + 1], t, color, mat)
		t = t * 0.78
	end
	for _, p in ipairs(spike(r, limb, pts[#pts - 1], pts[#pts], t * 1.15, color, mat)) do
		parts[#parts + 1] = p
	end
	return parts
end

local function gem(r, limb, s, cf, color, frame)
	local parts = {}
	if frame then
		parts[#parts + 1] = r:Box(limb, V(s * 1.3, s * 1.3, 0.12), cf * CF(0, 0, 0.04) * ANG(0, 0, rad(45)), frame, M.Metal)
	end
	parts[#parts + 1] = r:Neon(limb, V(s, s, 0.14), cf * ANG(0, 0, rad(45)), color or C.Neon)
	return parts
end
Kit.gem = gem

-- Рваный край: n треугольных лоскутов вниз вдоль ширины w (в Lite — пустой список)
function Kit.tatter(r, limb, y, z, w, n, color, mat, seed)
	local parts = {}
	if lite() then
		return parts
	end
	for i = 0, n - 1 do
		local x = -w / 2 + (i + 0.5) * w / n
		local h = 0.3 + (((i + (seed or 0)) * 37) % 5) * 0.12
		for _, p in ipairs(spike(r, limb, V(x, y, z), V(x + 0.05, y - h, z), w / n * 1.05, color, mat or M.Fabric, true, 0.08)) do
			parts[#parts + 1] = p
		end
	end
	return parts
end

-- Ступенчатый наплечник: верхняя пластина, две ступени, боковой щиток, козырёк, шипы, самоцвет
function Kit.pauldron(r, A, side, s, color, edge, glow, spikes)
	local parts = {}
	local function add(list)
		for _, p in ipairs(list) do
			parts[#parts + 1] = p
		end
	end
	add(bevel(r, A, V(1.55, 0.5, 1.5) * s, CF(0.18 * side, 1.08, 0) * ANG(0, 0, rad(-14 * side)), color, edge))
	add(bevel(r, A, V(1.3, 0.32, 1.38) * s, CF(0.42 * side, 0.74, 0) * ANG(0, 0, rad(-26 * side)), AC.ArmorMid, edge))
	add(bevel(r, A, V(1.15, 0.3, 1.28) * s, CF(0.55 * side, 0.46, 0) * ANG(0, 0, rad(-34 * side)), color, edge))
	add(bevel(r, A, V(0.3, 1.05, 1.42) * s, CF(0.82 * side * s, 0.62, 0) * ANG(0, 0, rad(-10 * side)), color, edge))
	parts[#parts + 1] = r:Wedge(A, V(1.2 * s, 0.4 * s, 0.45 * s), CF(0.22 * side, 1.12, -0.92 * s) * ANG(0, PI, 0) * ANG(0, 0, rad(14 * side)), color, M.Metal)
	if glow then
		add(gem(r, A, 0.34 * s, CF(0.99 * side * s, 0.62, 0) * ANG(0, -side * PI / 2, 0) * ANG(0, 0, rad(10 * side)), glow, edge))
	end
	local n = spikes or 2
	for k = 1, n do
		local z = n == 1 and 0 or (-0.45 + (k - 1) * 0.9 / (n - 1))
		add(spike(r, A, V(0.4 * side, 1.3, z * s), V((0.85 + 0.1 * k) * side, 2.05 - 0.12 * k, z * 1.3 * s), 0.4 * s, color, M.Metal))
	end
	return parts
end

function Kit.bootA(r, L, color, edge, w)
	w = w or 1.15
	local parts = bevel(r, L, V(w, 0.5, 1.25), CF(0, -0.75, -0.08), color, edge)
	parts[#parts + 1] = r:Wedge(L, V(w * 0.9, 0.4, 0.55), CF(0, -0.8, -0.95), color, M.Metal)
	return parts
end

function Kit.squareRing(r, limb, cf, w, t, color)
	local parts = {}
	for i = 0, 3 do
		parts[#parts + 1] = r:Box(limb, V(w, t, t), cf * ANG(0, i * PI / 2, 0) * CF(0, 0, -w / 2 + t / 2), color, M.Metal)
	end
	return parts
end

function Kit.chain(r, limb, n, size, color, at)
	at = at or CF()
	color = color or C.Steel
	local parts = {}
	for i = 0, n - 1 do
		local cf = at * CF(0, -i * size * 1.1, 0) * ANG(0, i % 2 == 0 and 0 or PI / 2, 0)
		parts[#parts + 1] = r:Box(limb, V(size * 0.18, size * 1.2, size * 0.7), cf, color, M.Metal)
		parts[#parts + 1] = r:Box(limb, V(size * 0.18, size * 0.18, size * 0.7), cf * CF(0, size * 0.5, 0), color, M.Metal)
	end
	return parts
end

------------------------------------------------------------------------
-- ПРИГЛУШЕНИЕ: неон темнее, подсветка и частицы слабее (меньше «кислотности»)
------------------------------------------------------------------------
local CALM_DARK = rgb(14, 10, 22)
Kit.CALM_LIGHT = 0.65 -- множитель яркости PointLight
Kit.CALM_EMISSION = 0.6 -- множитель LightEmission частиц

-- Повторный вызов ничего не делает; вложенные уже приглушённые модели (статуи юнитов в лобби и т.п.) пропускаются
local function calmWalk(obj, amount)
	for _, d in ipairs(obj:GetChildren()) do
		if d:IsA("BasePart") then
			if d.Material == M.Neon then
				d.Color = d.Color:Lerp(CALM_DARK, amount)
			end
		elseif d:IsA("PointLight") then
			d.Brightness = d.Brightness * Kit.CALM_LIGHT
		elseif d:IsA("ParticleEmitter") then
			d.LightEmission = d.LightEmission * Kit.CALM_EMISSION
		end
		if not (d:IsA("Model") and d:GetAttribute("Calmed")) then
			calmWalk(d, amount)
		end
	end
end

function Kit.Calm(root, amount)
	if not root or root:GetAttribute("Calmed") then
		return
	end
	amount = amount or 0.3
	root:SetAttribute("Calmed", amount)
	calmWalk(root, amount)
end

return Kit
