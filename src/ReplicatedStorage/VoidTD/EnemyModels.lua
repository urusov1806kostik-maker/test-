--!nocheck
-- VOID TD :: EnemyModels
-- Блочные модели врагов. EnemyModels.Build(enemyId) -> rig { Model, Motors, Base, Style, HipHeight, Height }

local UnitModels = require(script.Parent.UnitModels)
local Config = require(script.Parent.Config)

local Rig = UnitModels.Rig
local P = UnitModels.Palette

local V = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles
local rad = math.rad

local M = {
	Plastic = Enum.Material.SmoothPlastic,
	Metal = Enum.Material.Metal,
	Neon = Enum.Material.Neon,
	Fabric = Enum.Material.Fabric,
	Slate = Enum.Material.Slate,
}

local EnemyModels = {}

------------------------------------------------------------------------
-- Существо без человеческого скелета: Root -> Body (мотор "Root")
------------------------------------------------------------------------
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

local function finishCreature(self, scale, hip, height, style)
	self:Finish(scale)
	self.HipHeight = hip * scale
	self.Height = height * scale
	self.Style = style
	self.Model:SetAttribute("HipHeight", self.HipHeight)
	return self
end

local function finishBiped(self, scale, style)
	-- self:Finish(...) уже вызван
	self.Height = (3 + 1 + self.HeadSize.Y + 0.6) * scale
	self.Style = style or "Biped"
	return self
end

------------------------------------------------------------------------
-- 1. LOST SOUL — маленький призрачный огонёк
------------------------------------------------------------------------
local function LostSoul(scale)
	local r = newCreature("LostSoul", V(1.6, 1.6, 1.4), P.Pale)
	local B = r.Torso
	B.Transparency = 0.25
	table.insert(r.Pending, B) -- тело-эллипсоид
	r.Head = B
	r.HeadSize = B.Size
	r:Eyes(P.Neon, { Y = 0.15, Spacing = 0.32, Size = V(0.3, 0.3, 0.06) })
	r:Sphere(B, V(0.45, 0.3, 0.1), CF(0, -0.3, -0.68), P.Black) -- рот
	r:Wedge(B, V(1.2, 0.9, 1.0), CF(0, -1.2, 0.1) * ANG(0, 0, math.pi), P.Pale, M.Plastic, { Transparency = 0.35 })
	r:Wedge(B, V(0.6, 0.7, 0.6), CF(0.1, -1.8, 0.4) * ANG(0, 0, math.pi), P.Pale, M.Plastic, { Transparency = 0.5 })
	r:Joint("ArmR", B, V(0.35, 0.9, 0.35), CF(0.8, 0, 0), CF(0.25, -0.35, 0) * ANG(0, 0, rad(25)), P.Pale)
	r:Joint("ArmL", B, V(0.35, 0.8, 0.35), CF(-0.8, 0, 0), CF(-0.25, -0.35, 0) * ANG(0, 0, rad(-25)), P.Pale)
	r:Glow(B, P.Neon, 6, 0.8)
	return finishCreature(r, scale, 2.4, 3.2, "Float")
end

------------------------------------------------------------------------
-- 2. VOID CRAWLER — четырёхлапый жук
------------------------------------------------------------------------
local function VoidCrawler(scale)
	local r = newCreature("VoidCrawler", V(2.2, 1.0, 2.8), P.DeepViolet)
	local B = r.Torso
	r:Sphere(B, V(2.3, 1.1, 2.8), CF(0, 0.5, 0.15) * ANG(rad(-4), 0, 0), P.Coal, M.Metal) -- панцирь
	r:Sphere(B, V(1.3, 0.6, 1.2), CF(0.1, 0.95, 0.5), P.Black, M.Metal)
	r:Neon(B, V(0.1, 0.12, 2.2), CF(0, 0.88, 0.1), P.Neon)
	r:Sphere(B, V(1.35, 0.95, 1.1), CF(0, 0.05, -1.75), P.Coal)
	r:Wedge(B, V(0.25, 0.3, 0.8), CF(-0.4, -0.25, -2.5) * ANG(0, 0, 0), P.Pale)
	r:Wedge(B, V(0.25, 0.3, 0.7), CF(0.42, -0.22, -2.45), P.Pale)
	r:Ball(B, 0.26, CF(-0.33, 0.2, -2.22), P.Neon, M.Neon)
	r:Ball(B, 0.26, CF(0.35, 0.22, -2.22), P.Neon, M.Neon)
	r:Ball(B, 0.2, CF(0.05, 0.4, -2.2), P.NeonPink, M.Neon)
	local legs = { { "FR", 1, -0.8 }, { "FL", -1, -0.8 }, { "BR", 1, 0.8 }, { "BL", -1, 0.8 } }
	for _, l in ipairs(legs) do
		local leg = r:Joint(l[1], B, V(0.32, 1.5, 0.32), CF(1.05 * l[2], -0.1, l[3]), CF(0.45 * l[2], -0.6, 0) * ANG(0, 0, rad(32 * l[2])), P.Black)
		r:Box(leg, V(0.3, 0.6, 0.3), CF(0, -0.85, 0) * ANG(0, 0, rad(-40 * l[2])), P.Coal)
	end
	return finishCreature(r, scale, 1.3, 2.4, "Quad")
end

------------------------------------------------------------------------
-- 3. SHADOW BEAST — быстрый теневой волк
------------------------------------------------------------------------
local function ShadowBeast(scale)
	local r = newCreature("ShadowBeast", V(1.6, 1.4, 3.0), P.Black)
	local B = r.Torso
	r.Head = r:Joint("Neck", B, V(1.3, 1.2, 1.4), CF(0, 0.4, -1.4), CF(0, 0.2, -0.6), P.Black)
	r.HeadSize = r.Head.Size
	r:Box(r.Head, V(0.8, 0.6, 0.9), CF(0, -0.25, -1.0), P.Coal)
	r:Box(r.Head, V(0.75, 0.15, 0.85), CF(0, -0.6, -0.95), P.Maroon)
	r:Wedge(r.Head, V(0.3, 0.6, 0.4), CF(-0.42, 0.85, 0.2), P.Black)
	r:Wedge(r.Head, V(0.3, 0.55, 0.4), CF(0.42, 0.8, 0.25) * ANG(0, 0, rad(-12)), P.Black)
	r:Eyes(P.Neon, { Y = 0.2, Spacing = 0.33, Size = V(0.28, 0.12, 0.06), Tilt = -15 })
	for i = 0, 3 do
		r:Wedge(B, V(0.25, 0.4 + (i % 2) * 0.2, 0.5), CF(0, 0.85, -0.9 + i * 0.6), P.DeepViolet)
	end
	r:Chain(B, { V(0, 0.4, 1.5), V(0, 0.8, 2.2), V(0.2, 1.3, 2.6) }, 0.32, P.Black, M.Plastic, 0.75, true)
	r:Sphere(r.Head, V(0.5, 0.4, 0.4), CF(0, -0.2, -1.5), P.Black) -- нос
	local legs = { { "FR", 0.55, -1.1 }, { "FL", -0.55, -1.1 }, { "BR", 0.55, 1.1 }, { "BL", -0.55, 1.1 } }
	for _, l in ipairs(legs) do
		local leg = r:Joint(l[1], B, V(0.5, 1.5, 0.5), CF(l[2], -0.5, l[3]), CF(0, -0.75, 0), P.Black)
		r:Box(leg, V(0.55, 0.25, 0.7), CF(0, -0.68, -0.1), P.Coal)
	end
	r:Sparkles(B, P.DeepViolet, { Rate = 6, Size = 0.4 })
	return finishCreature(r, scale, 2.0, 3.2, "Quad")
end

------------------------------------------------------------------------
-- 4. ARMORED HORROR — бронированный
------------------------------------------------------------------------
local function ArmoredHorror(scale)
	local r = Rig.new({ Name = "ArmoredHorror", Torso = P.Steel, Arm = P.Dark, Leg = P.Dark, Head = P.Coal, TorsoMat = M.Metal })
	local T, H, RA, LA, RL, LL = r.Torso, r.Head, r.RArm, r.LArm, r.RLeg, r.LLeg
	r:Box(T, V(2.5, 2.1, 1.5), CF(0, 0.1, 0), P.Steel, M.Metal)
	r:Box(T, V(2.2, 0.3, 0.2), CF(0, 0.2, -0.8), P.Neon, M.Neon)
	r:Box(H, V(1.55, 1.5, 1.55), CF(0, 0.05, 0), P.Gray, M.Metal)
	r:Box(H, V(1.1, 0.12, 0.08), CF(0, 0.05, -0.8), P.NeonPink, M.Neon)
	for i = -1, 1 do
		r:Wedge(H, V(0.25, 0.6, 0.4), CF(i * 0.5, 1.05, 0), P.Steel, M.Metal)
	end
	r:Pauldron(RA, 1, 1.0, P.Gray, P.Steel)
	r:Pauldron(LA, -1, 0.95, P.Gray, P.Steel)
	r:Cyl(LA, 0.3, 2.6, CF(-0.7, -0.6, -0.2), P.Steel, M.Metal, "X") -- круглый щит
	r:Cyl(LA, 0.2, 2.8, CF(-0.66, -0.6, -0.2), P.Dark, M.Metal, "X")
	r:Sphere(LA, V(0.3, 0.8, 0.8), CF(-0.88, -0.6, -0.2), P.Neon, M.Neon)
	r:Box(RL, V(1.15, 1.2, 1.2), CF(0, -0.4, 0), P.Gray, M.Metal)
	r:Box(LL, V(1.15, 1.2, 1.2), CF(0, -0.4, 0), P.Gray, M.Metal)
	r:Box(RA, V(1.15, 1.2, 1.15), CF(0, -0.4, 0), P.Steel, M.Metal)
	return finishBiped(r:Finish(scale), scale)
end

------------------------------------------------------------------------
-- 5. RIFT PHANTOM — призрачный
------------------------------------------------------------------------
local function RiftPhantom(scale)
	local r = newCreature("RiftPhantom", V(1.8, 2.0, 1.1), P.DeepViolet)
	local B = r.Torso
	B.Transparency = 0.35
	r.Head = r:Joint("Neck", B, V(1.3, 1.3, 1.3), CF(0, 1.0, 0), CF(0, 0.65, 0), P.Black)
	r.HeadSize = r.Head.Size
	r:Box(r.Head, V(1.55, 0.3, 1.55), CF(0, 0.75, 0.05), P.DeepViolet, M.Fabric, { Transparency = 0.3 })
	r:Box(r.Head, V(0.25, 1.4, 1.55), CF(-0.72, 0.0, 0.05), P.DeepViolet, M.Fabric, { Transparency = 0.3 })
	r:Box(r.Head, V(0.25, 1.4, 1.55), CF(0.72, 0.0, 0.05), P.DeepViolet, M.Fabric, { Transparency = 0.3 })
	r:Wedge(r.Head, V(0.7, 1.2, 1.0), CF(0, 0.8, 0.7) * ANG(rad(-30), 0, 0), P.DeepViolet, M.Fabric, { Transparency = 0.3 })
	r:Eyes(P.NeonSoft, { Y = 0.0, Spacing = 0.28, Size = V(0.3, 0.1, 0.06), Tilt = 10 })
	-- плащ сужается книзу
	for i = 1, 4 do
		local w = 1.8 - i * 0.32
		r:Cyl(B, 0.6, w, CF(0.05 * (i % 2), -1.0 - i * 0.5, 0.05 * i), P.DeepViolet, M.Fabric, "Y", { Transparency = 0.3 + i * 0.1 })
	end
	r:Neon(B, V(0.12, 1.8, 0.06), CF(0.4, 0, -0.58), P.Neon, { Transparency = 0.2 })
	for _, s in ipairs({ 1, -1 }) do
		local arm = r:Joint(s == 1 and "ArmR" or "ArmL", B, V(0.5, 2.2, 0.5), CF(1.1 * s, 0.7, 0), CF(0.1 * s, -1.0, 0), P.DeepViolet)
		arm.Transparency = 0.3
		for k = -1, 1 do
			r:Wedge(arm, V(0.12, 0.5, 0.2), CF(k * 0.15, -1.3, -0.1) * ANG(0, 0, math.pi), P.NeonSoft, M.Neon)
		end
	end
	r:Sparkles(B, P.Neon, { Rate = 10, Size = 0.35 })
	r:Glow(B, P.Neon, 8, 1)
	return finishCreature(r, scale, 3.3, 4.6, "Float")
end

------------------------------------------------------------------------
-- 6. ABYSS BRUTE — много здоровья
------------------------------------------------------------------------
local function AbyssBrute(scale)
	local r = Rig.new({ Name = "AbyssBrute", Torso = P.Maroon, Arm = P.Maroon, Leg = P.Coal, Head = P.Maroon, HeadSize = V(1.2, 1.1, 1.2) })
	local T, H, RA, LA, RL, LL = r.Torso, r.Head, r.RArm, r.LArm, r.RLeg, r.LLeg
	r:Box(T, V(2.6, 1.6, 1.5), CF(0, 0.45, 0.1), P.Maroon)
	r:Box(T, V(2.2, 0.5, 1.3), CF(0, -0.8, 0), P.Black, M.Metal)
	r:Neon(T, V(0.6, 0.6, 0.08), CF(0, 0.4, -0.67) * ANG(0, 0, rad(45)), P.NeonPink)
	for i = -1, 1 do
		r:Wedge(T, V(0.3, 0.7, 0.6), CF(i * 0.7, 1.4, 0.6) * ANG(rad(-20), 0, 0), P.Pale)
	end
	r:Box(H, V(1.3, 0.5, 0.2), CF(0, -0.3, -0.6), P.Black)
	r:Wedge(H, V(0.12, 0.3, 0.15), CF(-0.3, -0.62, -0.68) * ANG(0, 0, math.pi), P.White)
	r:Wedge(H, V(0.12, 0.3, 0.15), CF(0.32, -0.62, -0.68) * ANG(0, 0, math.pi), P.White)
	r:Eyes(P.NeonPink, { Y = 0.15, Spacing = 0.28, Size = V(0.22, 0.12, 0.06), Tilt = -12 })
	r:Horn(H, 1, V(0.55, 0.3, 0), 0.7, P.Pale)
	r:Horn(H, -1, V(-0.55, 0.3, 0), 0.6, P.Pale)
	-- огромные руки
	r:Box(RA, V(1.7, 2.2, 1.7), CF(0.15, -0.6, 0), P.Maroon)
	r:Box(LA, V(1.6, 2.1, 1.6), CF(-0.15, -0.6, 0), P.Maroon)
	r:Box(RA, V(1.8, 0.6, 1.8), CF(0.15, -1.6, 0), P.Black, M.Metal)
	r:Box(LA, V(1.7, 0.6, 1.7), CF(-0.15, -1.6, 0), P.Black, M.Metal)
	r:Box(RL, V(1.2, 1.0, 1.2), CF(0, -0.55, 0), P.Black, M.Metal)
	r:Box(LL, V(1.2, 1.0, 1.2), CF(0, -0.55, 0), P.Black, M.Metal)
	r:Finish(scale, { Root = { 10, 0, 0 }, Neck = { -10, 0, 0 } })
	return finishBiped(r, scale)
end

------------------------------------------------------------------------
-- 7. CORRUPTED TITAN — мини-босс
------------------------------------------------------------------------
local function CorruptedTitan(scale)
	local r = Rig.new({ Name = "CorruptedTitan", Torso = P.Coal, Arm = P.Coal, Leg = P.Black, Head = P.Coal, HeadSize = V(1.4, 1.4, 1.4), TorsoMat = M.Slate })
	local T, H, RA, LA, RL, LL = r.Torso, r.Head, r.RArm, r.LArm, r.RLeg, r.LLeg
	r:Box(T, V(2.7, 2.2, 1.6), CF(0, 0.15, 0), P.Coal, M.Slate)
	r:Seg(T, V(-1.0, 1.0, -0.82), V(0.1, 0.0, -0.82), 0.12, P.Neon, M.Neon)
	r:Seg(T, V(0.1, 0.0, -0.82), V(-0.3, -0.9, -0.82), 0.12, P.Neon, M.Neon)
	r:Seg(T, V(0.9, 0.8, -0.82), V(0.4, -0.3, -0.82), 0.12, P.Neon, M.Neon)
	r:Box(H, V(1.6, 1.0, 1.6), CF(0, 0.3, 0), P.Black, M.Slate)
	r:Box(H, V(1.2, 0.14, 0.08), CF(0, -0.05, -0.72), P.Neon, M.Neon)
	local spikes = { -0.6, -0.2, 0.25, 0.6 }
	for i, x in ipairs(spikes) do
		r:Box(H, V(0.25, 0.5 + (i % 2) * 0.35, 0.25), CF(x, 1.0 + (i % 2) * 0.15, -0.5), P.Steel, M.Metal)
	end
	r:Pauldron(RA, 1, 1.15, P.Black, P.Neon, 0, M.Neon)
	r:Pauldron(LA, -1, 1.05, P.Black)
	r:Box(RL, V(1.2, 1.3, 1.2), CF(0, -0.35, 0), P.Coal, M.Slate)
	r:Box(LL, V(1.2, 1.3, 1.2), CF(0, -0.35, 0), P.Coal, M.Slate)
	-- дубина
	r:Cyl(RA, 1.2, 0.38, CF(0, -1.05, -0.2), P.Maroon, M.Fabric, "Z")
	r:Cyl(RA, 2.6, 1.1, CF(0, -1.05, -2.0), P.Black, M.Slate, "Z") -- дубина
	r:Ball(RA, 1.3, CF(0, -1.05, -3.3), P.Black, M.Slate)
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2
		r:Wedge(RA, V(0.3, 0.5, 0.3), CF(math.cos(a) * 0.6, -1.05 + math.sin(a) * 0.6, -2.4 - (i % 2) * 0.6) * ANG(0, 0, a - math.pi / 2), P.Steel, M.Metal)
	end
	r:Cyl(RA, 0.15, 1.15, CF(0, -1.05, -1.4), P.Neon, M.Neon, "Z")
	r:Sparkles(T, P.Neon, { Rate = 12, Size = 0.5 })
	r:Glow(T, P.Neon, 14, 1.5)
	return finishBiped(r:Finish(scale), scale)
end

------------------------------------------------------------------------
-- 8. VOID DEVOURER — огромная пасть
------------------------------------------------------------------------
local function VoidDevourer(scale)
	local r = newCreature("VoidDevourer", V(4.0, 2.6, 4.2), P.DeepViolet)
	local B = r.Torso
	r:Box(B, V(4.2, 1.0, 4.0), CF(0, 1.6, 0.1) * ANG(rad(-5), 0, rad(2)), P.Black, M.Slate)
	r:Box(B, V(2.4, 0.9, 2.2), CF(0.3, 2.3, 0.6), P.Coal, M.Slate)
	-- глаза (асимметричные)
	local eyes = { { -1.2, 0.8, 0.5 }, { 1.1, 0.9, 0.42 }, { -0.4, 1.2, 0.3 }, { 0.5, 0.6, 0.3 }, { 1.6, 0.4, 0.25 } }
	for _, e in ipairs(eyes) do
		r:Ball(B, e[3] * 1.2, CF(e[1], e[2], -2.08), P.NeonPink, M.Neon)
	end
	-- верхние зубы
	for i = -3, 3 do
		r:Wedge(B, V(0.35, 0.6, 0.4), CF(i * 0.55, -1.55, -1.9) * ANG(0, 0, math.pi), P.White)
	end
	-- нижняя челюсть на моторе
	local jaw = r:Joint("Jaw", B, V(3.8, 0.8, 3.8), CF(0, -1.2, 1.6), CF(0, -0.4, -1.7), P.Coal)
	for i = -3, 3 do
		r:Wedge(jaw, V(0.32, 0.55, 0.35), CF(i * 0.52, 0.65, -1.65), P.White)
	end
	r:Neon(jaw, V(3.0, 0.1, 2.6), CF(0, 0.41, -0.2), P.Maroon, { Material = M.Plastic })
	-- лапы
	local legs = { { "FR", 1.6, -1.2 }, { "FL", -1.6, -1.2 }, { "BR", 1.6, 1.4 }, { "BL", -1.6, 1.4 } }
	for _, l in ipairs(legs) do
		local leg = r:Joint(l[1], B, V(1.0, 1.8, 1.0), CF(l[2], -1.0, l[3]), CF(0, -0.9, 0), P.Black)
		r:Wedge(leg, V(0.9, 0.4, 0.4), CF(0, -0.9, -0.6) * ANG(0, math.pi, 0), P.Pale)
	end
	-- щупальца на спине
	for i, x in ipairs({ -1.2, 0, 1.2 }) do
		local lift = 1.6 + (i % 2) * 0.6
		r:Chain(B, { V(x, 1.8, 1.6), V(x * 1.3, 1.8 + lift * 0.6, 2.4), V(x * 1.6, 1.8 + lift, 3.4) }, 0.48, P.Black, M.Plastic, 0.7, true)
		r:Ball(B, 0.4, CF(x * 1.6, 1.8 + lift, 3.4), P.NeonPink, M.Neon)
	end
	r:Sparkles(B, P.NeonPink, { Rate = 14, Size = 0.6 })
	r:Glow(B, P.NeonPink, 16, 1.5)
	return finishCreature(r, scale, 2.6, 5.0, "Quad")
end

------------------------------------------------------------------------
-- 9. THE ENTITY — финальный босс
------------------------------------------------------------------------
local function TheEntity(scale)
	local r = Rig.new({ Name = "TheEntity", Torso = P.Black, Arm = P.Black, Leg = P.Black, Head = P.Black, HeadSize = V(1.3, 1.6, 1.3) })
	local T, H, RA, LA, RL, LL = r.Torso, r.Head, r.RArm, r.LArm, r.RLeg, r.LLeg
	-- вместо ног — рваный шлейф
	RL.Transparency = 1
	LL.Transparency = 1
	for i = 1, 5 do
		local w = 2.2 - i * 0.35
		r:Cyl(T, 0.7, w, CF(math.sin(i) * 0.15, -1.2 - i * 0.6, 0.1 * i), P.Black, M.Plastic, "Y", { Transparency = (i - 1) * 0.12 })
	end
	r:Neon(T, V(0.15, 1.6, 0.06), CF(0, 0.1, -0.52), P.White)
	r:Seg(T, V(-0.8, 0.8, -0.52), V(0, 0.1, -0.52), 0.1, P.Neon, M.Neon)
	r:Seg(T, V(0.8, 0.8, -0.52), V(0, 0.1, -0.52), 0.1, P.Neon, M.Neon)
	-- лицо: белые светящиеся глаза и трещина-рот
	r:Eyes(P.White, { Y = 0.25, Spacing = 0.3, Size = V(0.2, 0.32, 0.06) })
	r:Neon(H, V(0.7, 0.08, 0.06), CF(0, -0.35, -0.68) * ANG(0, 0, rad(-6)), P.Neon)
	-- лишние руки
	for _, s in ipairs({ 1, -1 }) do
		local arm = r:Joint(s == 1 and "ArmR2" or "ArmL2", T, V(0.7, 2.6, 0.7), CF(1.1 * s, -0.2, 0.3), CF(0.5 * s, -1.0, 0) * ANG(0, 0, rad(30 * s)), P.Black)
		r:Neon(arm, V(0.12, 1.8, 0.12), CF(0, 0, -0.36), P.Neon)
	end
	for _, A in ipairs({ RA, LA }) do
		r:Box(A, V(0.6, 1.2, 0.6), CF(0, -1.5, 0), P.Black)
		r:Neon(A, V(0.12, 1.6, 0.06), CF(0, -0.4, -0.52), P.Neon)
	end
	-- кольцо осколков вокруг головы (крутится)
	local halo = r:Joint("Halo", H, V(0.3, 0.3, 0.3), CF(0, 0.6, 0.3), CF(), P.Black)
	halo.Transparency = 1
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		r:Neon(halo, V(0.3, 0.8, 0.12), CF(math.cos(a) * 1.5, 0, math.sin(a) * 1.5) * ANG(0, -a, rad(20)), i % 2 == 0 and P.White or P.Neon)
	end
	r:Sparkles(T, P.Neon, { Rate = 20, Size = 0.6, Up = 2 })
	r:Glow(T, P.White, 18, 1.2)
	r:Finish(scale)
	r.HipHeight = 4.2 * scale
	r.Height = 7 * scale
	r.Style = "Float"
	r.Model:SetAttribute("HipHeight", r.HipHeight)
	return r
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
			d.CastShadow = def.IsBoss == true or d.Name == "Torso"
		end
	end
	return rig
end

return EnemyModels
