--!nocheck
-- VOID TD :: World.Kit
-- Строительные помощники мира: детали, свет, частицы, вывески, круги зон, статуи юнитов,
-- приглушение неона (Calm) и общий декор (кристаллы, деревья, руины, тыквы, надгробия, фонари...).
-- Всё из примитивов; единственная текстура — встроенный дым.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("VoidTD")

local Kit = {}

local V, CF, ANG, rad = Vector3.new, CFrame.new, CFrame.Angles, math.rad
local rgb = Color3.fromRGB
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"

-- палитра Void
Kit.C = {
	Ground = rgb(38, 34, 48), Ground2 = rgb(46, 38, 60), Moss = rgb(52, 34, 72), Rock = rgb(30, 27, 38),
	Rock2 = rgb(44, 40, 54), Path = rgb(72, 64, 84), PathEdge = rgb(56, 50, 66), Stone = rgb(88, 84, 98),
	Stone2 = rgb(64, 60, 74), Neon = rgb(170, 70, 255), NeonPink = rgb(255, 70, 180), NeonSoft = rgb(210, 150, 255),
	Bark = rgb(28, 22, 30), Leaf = rgb(46, 22, 64), Leaf2 = rgb(30, 16, 44), Black = rgb(12, 8, 18),
}
-- палитра Хэллоуина
Kit.H = {
	Black = rgb(14, 10, 16), Ground = rgb(34, 26, 36), Ground2 = rgb(44, 30, 40), Grass = rgb(46, 34, 30), GrassP = rgb(42, 24, 54),
	Rock = rgb(30, 24, 32), Rock2 = rgb(44, 36, 46), Stone = rgb(78, 70, 82), Stone2 = rgb(58, 52, 64), Road = rgb(64, 54, 58),
	RoadEdge = rgb(44, 36, 42), Purple = rgb(70, 30, 110), DeepPurple = rgb(36, 18, 56), Orange = rgb(255, 130, 30),
	Ember = rgb(255, 90, 20), Pumpkin = rgb(220, 110, 30), PumpkinD = rgb(170, 70, 20), Stem = rgb(60, 70, 30),
	Burgundy = rgb(100, 20, 34), Gold = rgb(200, 156, 60), Bark = rgb(32, 24, 26), Bone = rgb(200, 192, 176),
	Ghost = rgb(220, 225, 255), Fog = rgb(150, 140, 170), Moon = rgb(255, 214, 150), Window = rgb(255, 160, 60), Rune = rgb(170, 70, 255),
}
local C, H = Kit.C, Kit.H

------------------------------------------------------------------------
-- БАЗА
------------------------------------------------------------------------
-- деталь: Class Size CFrame Color Material Shape Transparency CanCollide CastShadow Name (+ Query=false — не мешает рейкастам)
function Kit.Part(parent, o)
	local p = Instance.new(o.Class or "Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = o.Material or Enum.Material.SmoothPlastic
	p.Color = o.Color or C.Ground
	if o.Shape then
		p.Shape = o.Shape
	end
	p.Size = o.Size or V(4, 4, 4)
	p.CFrame = o.CFrame or CF()
	p.Transparency = o.Transparency or 0
	p.CanCollide = o.CanCollide ~= false
	p.CastShadow = o.CastShadow ~= false and p.Material ~= Enum.Material.Neon
	if o.Query == false then
		p.CanQuery = false
		p.CanTouch = false
	end
	p.Name = o.Name or "Part"
	p.Parent = parent
	return p
end
local part = Kit.Part

-- сокращения: блок, неон (без коллизии), клин
function Kit.Block(parent, size, cf, color, mat, extra)
	local o = { Size = size, CFrame = cf, Color = color, Material = mat or Enum.Material.Slate }
	if extra then
		for k, v in pairs(extra) do
			o[k] = v
		end
	end
	return part(parent, o)
end
local block = Kit.Block

function Kit.Neon(parent, size, cf, color, extra)
	local o = { CanCollide = false }
	if extra then
		for k, v in pairs(extra) do
			o[k] = v
		end
	end
	return block(parent, size, cf, color, Enum.Material.Neon, o)
end
local neon = Kit.Neon

function Kit.Wedge(parent, size, cf, color, mat, collide)
	return part(parent, { Class = "WedgePart", Size = size, CFrame = cf, Color = color, Material = mat or Enum.Material.Slate, CanCollide = collide == true })
end
local wedge = Kit.Wedge

-- невидимый помощник (свет/частицы): не мешает ни коллизии, ни рейкастам
function Kit.Ghost(parent, size, pos, name)
	return part(parent, { Size = size, CFrame = CF(pos), Transparency = 1, CanCollide = false, Query = false, CastShadow = false, Name = name or "Helper" })
end

function Kit.Light(p, color, range, brightness)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Shadows = false
	l.Parent = p
	return l
end
local light = Kit.Light

function Kit.Emitter(p, color, o)
	o = o or {}
	local e = Instance.new("ParticleEmitter")
	e.Color = ColorSequence.new(color)
	e.LightEmission = 1
	e.LightInfluence = 0
	e.Rate = o.Rate or 10
	e.Lifetime = NumberRange.new(o.LifeMin or 1, o.LifeMax or 2)
	e.Speed = NumberRange.new(o.SpeedMin or 1, o.SpeedMax or 3)
	e.SpreadAngle = Vector2.new(o.Spread or 180, o.Spread or 180)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, o.Size or 0.5), NumberSequenceKeypoint.new(1, 0) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	if o.Accel then
		e.Acceleration = o.Accel
	end
	if o.Dir then
		e.EmissionDirection = o.Dir
	end
	e.Parent = p
	return e
end
local emitter = Kit.Emitter

-- стелющийся туман (встроенная текстура дыма)
function Kit.Fog(p, color, rate, size)
	size = size or 6
	local e = Instance.new("ParticleEmitter")
	e.Name = "Fog"
	e.Texture = SMOKE
	e.Color = ColorSequence.new(color or H.Fog)
	e.LightEmission = 0.1
	e.LightInfluence = 0.6
	e.Rate = rate or 2
	e.Lifetime = NumberRange.new(5, 8)
	e.Speed = NumberRange.new(0.3, 1)
	e.SpreadAngle = Vector2.new(180, 10)
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-10, 10)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size), NumberSequenceKeypoint.new(1, size * 1.8) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.75), NumberSequenceKeypoint.new(1, 1) })
	e.Parent = p
	return e
end

-- вертикальный диск (ось цилиндра = X детали; локальный +X смотрит вверх)
function Kit.CylY(parent, name, r, h, center, color, mat, o)
	o = o or {}
	return part(parent, {
		Name = name, Shape = Enum.PartType.Cylinder, Size = V(h, r * 2, r * 2), CFrame = CF(center) * ANG(0, 0, rad(90)),
		Color = color, Material = mat or Enum.Material.Slate, CanCollide = o.CanCollide, Transparency = o.Transparency,
		Query = o.Query,
	})
end
local cylY = Kit.CylY

function Kit.Cyl(parent, name, size, cf, color, mat, o)
	o = o or {}
	return part(parent, {
		Name = name, Shape = Enum.PartType.Cylinder, Size = size, CFrame = cf, Color = color,
		Material = mat or Enum.Material.Slate, CanCollide = o.CanCollide, Transparency = o.Transparency,
	})
end

function Kit.Ball(parent, name, d, pos, color, mat, o)
	o = o or {}
	return part(parent, {
		Name = name, Shape = Enum.PartType.Ball, Size = V(d, d, d), CFrame = CF(pos), Color = color,
		Material = mat or Enum.Material.Neon, CanCollide = o.CanCollide == true, Transparency = o.Transparency,
	})
end

local function textLabel(parent, text, color, font)
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Font = font
	t.TextScaled = true
	t.Text = text
	t.TextColor3 = color
	t.TextStrokeTransparency = 0
	t.Parent = parent
	return t
end

-- парящая подпись над точкой
function Kit.Billboard(parent, pos, title, subtitle, color, size)
	size = size or 14
	local anchor = Kit.Ghost(parent, V(1, 1, 1), pos, "Label")
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.new(size, 0, size * 0.4, 0)
	bb.LightInfluence = 0
	bb.MaxDistance = 250
	bb.Parent = anchor
	local t = textLabel(bb, title, color, Enum.Font.FredokaOne)
	t.TextStrokeColor3 = rgb(15, 0, 25)
	t.Size = UDim2.fromScale(1, subtitle and 0.65 or 1)
	if subtitle then
		local s = textLabel(bb, subtitle, rgb(235, 225, 255), Enum.Font.GothamBold)
		s.TextStrokeColor3 = rgb(15, 0, 25)
		s.Position = UDim2.fromScale(0, 0.65)
		s.Size = UDim2.fromScale(1, 0.35)
	end
	return anchor
end

-- вывеска: чёрная плита, неоновая рамка сзади, текст на лицевой (Front = LookVector) стороне
function Kit.Sign(parent, cf, size, title, sub, titleColor, frameColor, subColor)
	local p = block(parent, size, cf, H.Black, Enum.Material.Slate, { Name = "Sign" })
	neon(parent, V(size.X + 1, size.Y + 1, 0.3), cf * CF(0, 0, size.Z / 2 + 0.1), frameColor or H.Orange, { Name = "SignFrame" })
	local g = Instance.new("SurfaceGui")
	g.Face = Enum.NormalId.Front
	g.LightInfluence = 0
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = 30
	g.Parent = p
	local t = textLabel(g, title, titleColor or H.Orange, Enum.Font.FredokaOne)
	t.RichText = true
	t.Size = UDim2.fromScale(1, sub and 0.62 or 1)
	if sub then
		local s = textLabel(g, sub, subColor or rgb(245, 230, 210), Enum.Font.GothamBold)
		s.RichText = true
		s.Position = UDim2.fromScale(0.04, 0.62)
		s.Size = UDim2.fromScale(0.92, 0.34)
	end
	return p
end

-- Модуль модели по имени (без вечного ожидания); nil — нет или упал
local function model(name)
	local models = Shared:FindFirstChild("Models")
	local m = models and models:FindFirstChild(name)
	if not m then
		return nil
	end
	local ok, res = pcall(require, m)
	return ok and res or nil
end
Kit.Model = model

local function anchorAll(m)
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
		end
	end
end
Kit.AnchorAll = anchorAll

-- статуя юнита (уровень 5) на постаменте, повёрнута к lookAt (только по рысканью)
function Kit.Statue(parent, unitId, pos, lookAt, pedH)
	pedH = pedH or 3
	local UnitModels = model("Units")
	if not UnitModels then
		return nil
	end
	local ok, rig = pcall(UnitModels.Build, unitId, 5)
	if not ok or not rig then
		warn("[VOID TD] Статуя " .. tostring(unitId) .. " не построена: " .. tostring(rig))
		return nil
	end
	block(parent, V(5, pedH, 5), CF(pos + V(0, pedH / 2, 0)), C.Stone2, nil, { Name = "Pedestal" })
	block(parent, V(5.6, 0.5, 5.6), CF(pos + V(0, pedH + 0.25, 0)), C.Stone, nil, { Name = "PedestalTop" })
	neon(parent, V(5.7, 0.25, 5.7), CF(pos + V(0, pedH - 0.6, 0)), C.Neon, { Name = "PedestalRune" })
	local m = rig.Model
	m.Name = "Statue_" .. unitId
	local base = pos + V(0, pedH + 0.5 + (rig.HipHeight or 0), 0)
	m:PivotTo(CFrame.lookAt(base, V(lookAt.X, base.Y, lookAt.Z)))
	anchorAll(m)
	m.Parent = parent
	return m
end

-- приглушение неона и света (один раз на корень)
local CALM_TO = rgb(14, 10, 22)
function Kit.Calm(root)
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("BasePart") and d.Material == Enum.Material.Neon then
			d.Color = d.Color:Lerp(CALM_TO, 0.3)
		elseif d:IsA("PointLight") then
			d.Brightness *= 0.65
		end
	end
end

-- вращение/покачивание (клиент читает атрибуты)
function Kit.Spin(obj, spin, axis, bobAmp, bobSpeed)
	if spin then
		obj:SetAttribute("Spin", spin)
		obj:SetAttribute("SpinAxis", axis or "Y")
	end
	if bobAmp then
		obj:SetAttribute("BobAmp", bobAmp)
	end
	if bobSpeed then
		obj:SetAttribute("BobSpeed", bobSpeed)
	end
	return obj
end
local spinAttr = Kit.Spin

-- круг зоны: каменная база, неоновый край, стеклянная площадка, столб света, подпись
function Kit.ZoneCircle(parent, key, z, zc, subtitle, padColor)
	local zm = Instance.new("Model")
	zm.Name = key
	cylY(zm, "PadBase", z.Radius + 1.2, 0.6, zc + V(0, 0.3, 0), C.Stone2)
	cylY(zm, "PadEdge", z.Radius + 0.5, 0.65, zc + V(0, 0.33, 0), z.Color, Enum.Material.Neon)
	local pad = cylY(zm, "Pad", z.Radius, 0.7, zc + V(0, 0.36, 0), padColor or rgb(25, 15, 40), Enum.Material.Glass, { Transparency = 0.15 })
	local beam = cylY(zm, "LightBeam", z.Radius * 0.9, 26, zc + V(0, 13, 0), z.Color, Enum.Material.Neon, { CanCollide = false, Transparency = 0.88, Query = false })
	beam.CastShadow = false
	emitter(pad, z.Color, { Rate = 14, Size = 0.5, SpeedMin = 2, SpeedMax = 4, Spread = 10, Dir = Enum.NormalId.Right, LifeMin = 1.5, LifeMax = 2.5 })
	light(pad, z.Color, 18, 2)
	Kit.Billboard(zm, zc + V(0, 8.5, 0), z.Title, subtitle or (z.Teleport and "войди в портал" or "встань в круг"), z.Color, 12)
	zm:SetAttribute("Zone", key)
	zm.Parent = parent
	return zm
end

-- каменное кольцо-портал (декор) с вихрем
function Kit.RingPortal(parent, center, facing)
	local R = 9
	local base = CFrame.lookAt(center, center + facing)
	local rng = Random.new(7)
	for i = 0, 15 do
		local a = i / 16 * math.pi * 2
		local off = CF(math.cos(a) * R, math.sin(a) * R, 0)
		block(parent, V(3.4, 3, 2.6), base * off * ANG(0, 0, a + rad(rng:NextNumber(-3, 3))), i % 2 == 0 and C.Stone or C.Stone2, nil, { Name = "PortalStone" })
		if i % 4 == 0 then
			neon(parent, V(0.6, 1.3, 0.3), base * off * ANG(0, 0, a) * CF(0, 0, -1.35), C.Neon, { Name = "Rune" })
		end
	end
	local disc = Kit.Cyl(parent, "PortalDisc", V(0.4, 15.6, 15.6), base * ANG(0, rad(90), 0), rgb(120, 40, 210), Enum.Material.Neon, { CanCollide = false, Transparency = 0.2 })
	for i = 1, 3 do
		local s = neon(parent, V(0.6, 14.4, 0.7), base * ANG(0, 0, rad(i * 60)) * CF(0, 0, -0.4), C.NeonSoft, { Name = "Swirl", Transparency = 0.35 })
		spinAttr(s, -1.4 - i * 0.3, "Z")
	end
	light(disc, C.Neon, 40, 4)
	emitter(disc, C.Neon, { Rate = 30, Size = 0.7, SpeedMin = 2, SpeedMax = 5 })
	return disc
end

------------------------------------------------------------------------
-- ДЕКОР VOID
------------------------------------------------------------------------
function Kit.CrystalCluster(parent, rng, p, scale)
	local m = Instance.new("Model")
	m.Name = "CrystalCluster"
	local colors = { C.Neon, C.NeonSoft, C.NeonPink }
	local first
	for i = 1, rng:NextInteger(3, 5) do
		local h = rng:NextNumber(2.5, 6) * scale * (i == 1 and 1.4 or 1)
		local w = h * rng:NextNumber(0.25, 0.4)
		local off = V(rng:NextNumber(-1.6, 1.6), 0, rng:NextNumber(-1.6, 1.6)) * scale
		local cf = CF(p + off + V(0, h * 0.4, 0)) * ANG(rad(rng:NextNumber(-25, 25)), rad(rng:NextNumber(0, 90)), rad(rng:NextNumber(-25, 25)))
		local cr = part(m, { Name = "Crystal", Size = V(w, h, w), CFrame = cf, Material = Enum.Material.Neon, Color = colors[rng:NextInteger(1, i == 1 and 1 or 3)] })
		first = first or cr
	end
	block(m, V(3.5, 1.2, 3) * scale, CF(p + V(0, 0.4, 0)) * ANG(0, rad(rng:NextNumber(0, 90)), 0), C.Rock2, nil, { Name = "Rock" })
	light(first, C.Neon, 16 * scale, 1.6)
	m.Parent = parent
	return m
end

local function sphereMesh(p)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
end

function Kit.DarkTree(parent, rng, p)
	local m = Instance.new("Model")
	m.Name = "DarkTree"
	local wood = Enum.Material.Wood
	local h = rng:NextNumber(9, 14)
	local lean = rad(rng:NextNumber(-8, 8))
	local trunkCF = CF(p + V(0, h / 2, 0)) * ANG(lean, rad(rng:NextNumber(0, 180)), lean * 0.5)
	block(m, V(1.6, h, 1.6), trunkCF, C.Bark, wood, { Name = "Trunk" })
	block(m, V(3.2, 1, 3.2), CF(p + V(0, 0.4, 0)) * ANG(0, rad(rng:NextNumber(0, 90)), 0), C.Bark, wood, { Name = "Root" })
	local topCF = trunkCF * CF(0, h / 2, 0)
	for i = 1, 3 do
		local a = rad(i * 120 + rng:NextNumber(-20, 20))
		local len = rng:NextNumber(3, 5)
		local br = topCF * ANG(0, a, 0) * CF(0, -0.6 * i, 0) * ANG(rad(55), 0, 0) * CF(0, len / 2, 0)
		block(m, V(0.7, len, 0.7), br, C.Bark, wood, { Name = "Branch" })
		local size = V(rng:NextNumber(3.5, 5.5), rng:NextNumber(2.5, 3.5), rng:NextNumber(3.5, 5.5))
		local lf = block(m, size, br * CF(0, len / 2 + 0.6, 0) * ANG(rad(rng:NextNumber(-15, 15)), rad(rng:NextNumber(0, 90)), 0), i % 2 == 0 and C.Leaf or C.Leaf2, Enum.Material.Grass, { Name = "Leaves" })
		sphereMesh(lf)
	end
	local crown = block(m, V(5.5, 4, 5.5), topCF * CF(0, 1.4, 0) * ANG(0, rad(rng:NextNumber(0, 90)), rad(rng:NextNumber(-8, 8))), C.Leaf, Enum.Material.Grass, { Name = "Crown" })
	sphereMesh(crown)
	if rng:NextNumber() < 0.5 then
		local g = part(m, { Name = "Glow", Shape = Enum.PartType.Ball, Size = V(0.8, 0.8, 0.8), CFrame = topCF * CF(1.5, 0, -1.8), Material = Enum.Material.Neon, Color = C.NeonPink, CanCollide = false })
		light(g, C.NeonPink, 8, 1)
	end
	m.Parent = parent
	return m
end

function Kit.Ruin(parent, rng, p)
	local m = Instance.new("Model")
	m.Name = "Ruins"
	local base = CF(p) * ANG(0, rad(rng:NextNumber(0, 180)), 0)
	local cols = rng:NextInteger(3, 5)
	local heights = {}
	for x = 1, cols do
		local hh = rng:NextInteger(1, 4)
		heights[x] = hh
		for y = 1, hh do
			if not (x == 2 and y <= 2) then -- проём
				block(m, V(2.8, 1.6, 1.6), base * CF((x - cols / 2) * 2.9, 0.8 + (y - 1) * 1.65, 0) * ANG(0, rad(rng:NextNumber(-4, 4)), 0), (x + y) % 2 == 0 and C.Stone or C.Stone2, nil, { Name = "Brick" })
			end
		end
	end
	block(m, V(6.2, 1.2, 1.8), base * CF((2 - cols / 2) * 2.9, 4.0, 0) * ANG(0, 0, rad(rng:NextNumber(-6, 6))), C.Stone, nil, { Name = "Lintel" })
	for _ = 1, 4 do
		local s = rng:NextNumber(0.8, 1.8)
		block(m, V(1.6 * s, s, 1.2 * s), base * CF(rng:NextNumber(-6, 6), s / 2, rng:NextNumber(1.5, 4)) * ANG(rad(rng:NextNumber(-20, 20)), rad(rng:NextNumber(0, 90)), rad(rng:NextNumber(-20, 20))), C.Stone2, nil, { Name = "Rubble" })
	end
	-- руна на последней колонне (не висит в воздухе: на уровне её верха)
	local runeY = math.min(2.2, 0.8 + (heights[cols] - 1) * 1.65)
	local rune = neon(m, V(1, 1, 0.2), base * CF((cols - cols / 2) * 2.9, runeY, -0.85), C.Neon, { Name = "Rune" })
	light(rune, C.Neon, 8, 1)
	m.Parent = parent
	return m
end

function Kit.BrokenColumn(parent, rng, p)
	local m = Instance.new("Model")
	m.Name = "BrokenColumn"
	local h = rng:NextNumber(4, 12)
	block(m, V(4, 1, 4), CF(p + V(0, 0.5, 0)), C.Stone2, nil, { Name = "Base" })
	Kit.Cyl(m, "Shaft", V(h, 2.6, 2.6), CF(p + V(0, 1 + h / 2, 0)) * ANG(0, 0, rad(90)) * ANG(rad(rng:NextNumber(-3, 3)), 0, 0), C.Stone)
	block(m, V(2.4, 0.9, 2.4), CF(p + V(0.3, 1 + h + 0.2, 0)) * ANG(rad(14), rad(30), rad(-10)), C.Stone2, nil, { Name = "Break" })
	local len = rng:NextNumber(3, 6)
	local a = rad(rng:NextNumber(0, 360))
	Kit.Cyl(m, "FallenPiece", V(len, 2.4, 2.4), CF(p + V(math.cos(a) * 4, 1.2, math.sin(a) * 4)) * ANG(0, a, 0), C.Stone2)
	m.Parent = parent
	return m
end

function Kit.FloatingIsland(parent, rng, p, s)
	local m = Instance.new("Model")
	m.Name = "FloatingIsland"
	block(m, V(14, 3, 12) * s, CF(p) * ANG(0, rad(rng:NextNumber(0, 90)), 0), C.Ground2, nil, { Name = "Top" })
	block(m, V(10, 5, 8) * s, CF(p - V(0, 3.5 * s, 0)) * ANG(0, rad(rng:NextNumber(0, 90)), 0), C.Rock, nil, { Name = "Mid" })
	block(m, V(5, 6, 4) * s, CF(p - V(0, 8 * s, 0)) * ANG(rad(10), rad(rng:NextNumber(0, 90)), 0), C.Rock2, nil, { Name = "Bottom" })
	Kit.CrystalCluster(m, rng, p + V(0, 1.5 * s, 0), s)
	spinAttr(m, nil, nil, rng:NextNumber(1.2, 2.5), rng:NextNumber(0.3, 0.6))
	m.WorldPivot = CF(p)
	m.Parent = parent
	return m
end

------------------------------------------------------------------------
-- ДЕКОР ХЭЛЛОУИНА
------------------------------------------------------------------------
function Kit.Pumpkin(parent, pos, s, carved, yaw)
	local m = Instance.new("Model")
	m.Name = "Pumpkin"
	local base = CF(pos + V(0, 0.55 * s, 0)) * ANG(0, yaw or 0, 0)
	local first
	for i = 0, 5 do
		local p = block(m, V(0.62 * s, 1.0 * s, 0.62 * s), base * ANG(0, rad(i * 60), 0) * CF(0, 0, -0.38 * s), i % 2 == 0 and H.Pumpkin or H.PumpkinD, Enum.Material.SmoothPlastic, { CanCollide = false })
		first = first or p
	end
	block(m, V(0.18 * s, 0.4 * s, 0.18 * s), base * CF(0, 0.62 * s, 0) * ANG(0, 0, rad(12)), H.Stem, Enum.Material.Wood, { CanCollide = false })
	if carved then
		local f = base * CF(0, 0, -0.72 * s)
		for sx = -1, 1, 2 do
			neon(m, V(0.2 * s, 0.2 * s, 0.06), f * CF(sx * 0.2 * s, 0.15 * s, 0) * ANG(0, 0, rad(45)), H.Orange)
		end
		neon(m, V(0.5 * s, 0.1 * s, 0.06), f * CF(0, -0.2 * s, 0), H.Orange)
		if s >= 1.2 then
			light(first, H.Orange, 8 * s, 0.8)
		end
	end
	m.Parent = parent
	return m
end

function Kit.DeadTree(parent, rng, pos, s)
	s = s or 1
	local m = Instance.new("Model")
	m.Name = "DeadTree"
	local wood = Enum.Material.Wood
	local h = rng:NextNumber(9, 14) * s
	local lean = rad(rng:NextNumber(-6, 6))
	local trunk = CF(pos) * ANG(lean, rng:NextNumber(0, 6), lean * 0.5)
	block(m, V(1.4 * s, h, 1.4 * s), trunk * CF(0, h / 2, 0), H.Bark, wood)
	block(m, V(2.4 * s, 1.2 * s, 2.4 * s), trunk * CF(0, 0.4 * s, 0) * ANG(0, rad(45), 0), H.Bark, wood)
	for i = 1, 4 do
		local a = i / 4 * math.pi * 2 + rng:NextNumber(-0.4, 0.4)
		local y = h * rng:NextNumber(0.5, 0.95)
		local L = rng:NextNumber(3, 5.5) * s
		local br = trunk * CF(0, y, 0) * ANG(0, a, 0) * ANG(0, 0, rad(rng:NextNumber(45, 65)))
		block(m, V(0.5 * s, L, 0.5 * s), br * CF(0, L / 2, 0), H.Bark, wood, { CanCollide = false })
		block(m, V(0.3 * s, 0.5 * L, 0.3 * s), br * CF(0, L, 0) * ANG(0, 0, rad(-35)) * CF(0, 0.25 * L, 0), H.Bark, wood, { CanCollide = false })
	end
	m.Parent = parent
	return m
end

function Kit.Tombstone(parent, rng, pos, yaw)
	local kind = rng:NextInteger(1, 3)
	local cf = CF(pos) * ANG(rad(rng:NextNumber(-6, 6)), yaw, rad(rng:NextNumber(-8, 8)))
	if kind == 1 then
		block(parent, V(2, 2.6, 0.5), cf * CF(0, 1.3, 0), H.Stone2)
		block(parent, V(1.6, 0.6, 0.5), cf * CF(0, 2.8, 0) * ANG(0, 0, rad(45)), H.Stone2)
	elseif kind == 2 then
		block(parent, V(0.45, 3.2, 0.45), cf * CF(0, 1.6, 0), H.Stone)
		block(parent, V(1.8, 0.45, 0.45), cf * CF(0, 2.3, 0), H.Stone)
	else
		block(parent, V(2.4, 1.6, 0.7), cf * CF(0, 0.8, 0), H.Stone2)
		block(parent, V(2.6, 0.3, 0.9), cf * CF(0, 1.7, 0), H.Stone)
	end
	block(parent, V(2.2, 0.4, 3.6), cf * CF(0, 0.15, 1.9), H.Grass, Enum.Material.Ground, { CanCollide = false })
end

function Kit.Fence(parent, a, b, color)
	color = color or H.Black
	local d = b - a
	local n = math.max(1, math.floor(d.Magnitude / 2.2))
	for i = 0, n do
		local p = a + d * (i / n)
		block(parent, V(0.3, 2.6, 0.3), CF(p + V(0, 1.3, 0)), color, Enum.Material.Metal)
		wedge(parent, V(0.3, 0.5, 0.3), CF(p + V(0, 2.85, 0)), color, Enum.Material.Metal)
	end
	local mid = (a + b) / 2
	for _, y in ipairs({ 2.1, 0.8 }) do
		block(parent, V(0.18, 0.18, d.Magnitude), CFrame.lookAt(mid + V(0, y, 0), b + V(0, y, 0)), color, Enum.Material.Metal)
	end
end

-- фонарь на столбе; dir — куда смотрит кронштейн (по умолчанию +X)
function Kit.LanternPost(parent, pos, h, dir)
	h = h or 7
	local metal = Enum.Material.Metal
	local base = CF(pos)
	if dir and dir.Magnitude > 0 then
		base = CFrame.lookAt(pos, pos + V(dir.Z, 0, -dir.X)) -- локальный +X = dir
	end
	block(parent, V(0.5, h, 0.5), base * CF(0, h / 2, 0), H.Black, metal)
	block(parent, V(1.8, 0.3, 0.3), base * CF(0.6, h - 0.3, 0), H.Black, metal)
	local cage = block(parent, V(0.9, 1.1, 0.9), base * CF(1.3, h - 1.2, 0), H.Black, metal, { Transparency = 0.2, CanCollide = false })
	local flame = neon(parent, V(0.55, 0.7, 0.55), base * CF(1.3, h - 1.2, 0), H.Orange)
	light(flame, H.Orange, 16, 1.4)
	wedge(parent, V(1.1, 0.5, 1.1), base * CF(1.3, h - 0.45, 0), H.Black, metal)
	return cage
end

-- летучая мышь кружит вокруг pos: опорная точка модели — центр орбиты (PrimaryPart не ставим)
function Kit.Bat(parent, pos, r, speed)
	local m = Instance.new("Model")
	m.Name = "Bat"
	block(m, V(0.6, 0.5, 0.9), CF(pos + V(r, 0, 0)), H.Black, Enum.Material.SmoothPlastic, { CanCollide = false, Name = "Body" })
	for s = -1, 1, 2 do
		local w = wedge(m, V(0.1, 0.6, 1.6), CF(pos + V(r + s * 0.9, 0.1, 0)) * ANG(0, 0, rad(-70 * s)), H.Black, Enum.Material.SmoothPlastic)
		w.Name = "Wing"
	end
	neon(m, V(0.3, 0.1, 0.05), CF(pos + V(r, 0.08, -0.46)), H.Ember, { Name = "Eyes" })
	m.WorldPivot = CF(pos)
	spinAttr(m, speed, "Y", 0.8, 2.2)
	m.Parent = parent
	return m
end

function Kit.Crow(parent, pos, yaw)
	local cf = CF(pos) * ANG(0, yaw or 0, 0)
	local sp = Enum.Material.SmoothPlastic
	block(parent, V(0.5, 0.5, 0.9), cf * CF(0, 0.35, 0), H.Black, sp, { CanCollide = false })
	block(parent, V(0.4, 0.4, 0.4), cf * CF(0, 0.75, -0.4), H.Black, sp, { CanCollide = false })
	wedge(parent, V(0.15, 0.15, 0.4), cf * CF(0, 0.7, -0.75) * ANG(rad(90), 0, 0), H.Gold, sp)
	wedge(parent, V(0.3, 0.12, 0.6), cf * CF(0, 0.3, 0.6) * ANG(rad(180), 0, 0), H.Black, sp)
end

function Kit.GhostFigure(parent, pos, s)
	s = s or 1
	local m = Instance.new("Model")
	m.Name = "Ghost"
	local cf = CF(pos)
	local o = { Transparency = 0.55, CanCollide = false }
	local sp = Enum.Material.SmoothPlastic
	local body = block(m, V(2.2 * s, 2.4 * s, 1.8 * s), cf * CF(0, 1.6 * s, 0), H.Ghost, sp, o)
	block(m, V(1.8 * s, 1.6 * s, 1.6 * s), cf * CF(0, 3.4 * s, 0), H.Ghost, sp, o)
	for i = -1, 1 do
		local w = wedge(m, V(0.7 * s, 0.9 * s, 1.6 * s), cf * CF(i * 0.7 * s, 0.05, 0) * ANG(0, 0, rad(180)), H.Ghost, sp)
		w.Transparency = 0.55
	end
	for sx = -1, 1, 2 do
		block(m, V(0.3 * s, 0.45 * s, 0.05), cf * CF(sx * 0.35 * s, 3.5 * s, -0.81 * s), H.Black, sp, { CanCollide = false })
	end
	m.PrimaryPart = body
	spinAttr(m, nil, nil, 1.2, 1.1)
	m.Parent = parent
	return m
end

function Kit.Spire(parent, cf, w, h, color)
	color = color or H.DeepPurple
	for i = 0, 4 do
		local k = 1 - i / 5
		block(parent, V(w * k, h / 5, w * k), cf * CF(0, h / 5 * (i + 0.5), 0) * ANG(0, i % 2 == 1 and rad(45) or 0, 0), color)
	end
	block(parent, V(0.3, 0.35 * h, 0.3), cf * CF(0, h + 0.17 * h, 0), H.Gold, Enum.Material.Metal, { CanCollide = false })
end

function Kit.Tower(parent, base, w, h, ruined, rng)
	block(parent, V(w, h, w), CF(base + V(0, h / 2, 0)), H.Stone2)
	for i = 1, math.floor(h / 7) do
		for k = 0, 3 do
			local cf = CF(base + V(0, 7 * i - 2, 0)) * ANG(0, rad(k * 90), 0) * CF(0, 0, -w / 2 - 0.05)
			neon(parent, V(1.1, 2.2, 0.1), cf, H.Window)
			local wg = wedge(parent, V(1.1, 0.7, 0.12), cf * CF(0, 1.45, 0), H.Window, Enum.Material.Neon)
			wg.CastShadow = false
		end
	end
	if ruined then
		for i = 1, 5 do
			local a = i / 5 * math.pi * 2
			local hh = rng:NextNumber(1, 4)
			block(parent, V(w * 0.35, hh, w * 0.35), CF(base + V(math.cos(a) * 0.35 * w, h + hh / 2, math.sin(a) * 0.35 * w)) * ANG(0, a, rad(rng:NextNumber(-10, 10))), H.Stone2)
		end
	else
		block(parent, V(w + 1.2, 1, w + 1.2), CF(base + V(0, h + 0.5, 0)), H.Stone)
		Kit.Spire(parent, CF(base + V(0, h + 1, 0)), w + 0.4, 2.2 * w, H.DeepPurple)
	end
end

function Kit.House(parent, pos, yaw, s)
	s = s or 1
	local cf = CF(pos) * ANG(0, yaw, 0)
	block(parent, V(10 * s, 7 * s, 8 * s), cf * CF(0, 3.5 * s, 0), H.Rock2, Enum.Material.WoodPlanks)
	for side = -1, 1, 2 do
		wedge(parent, V(10.6 * s, 4.5 * s, 4.6 * s), cf * CF(0, 9.25 * s, side * 2.3 * s) * ANG(0, side > 0 and math.pi or 0, 0), H.Burgundy, Enum.Material.Slate, true)
	end
	block(parent, V(1.2 * s, 4 * s, 1.2 * s), cf * CF(3 * s, 10 * s, 1.5 * s), H.Stone2)
	block(parent, V(2.2 * s, 3.8 * s, 0.2), cf * CF(0, 1.9 * s, -4.05 * s), H.Bark, Enum.Material.Wood)
	for sx = -1, 1, 2 do
		neon(parent, V(1.6 * s, 1.6 * s, 0.1), cf * CF(sx * 3 * s, 4 * s, -4.05 * s), H.Window)
	end
	local g = Kit.Ghost(parent, V(0.5, 0.5, 0.5), (cf * CF(0, 4 * s, -5 * s)).Position)
	light(g, H.Window, 14, 1)
end

function Kit.RuneCircle(parent, pos, r, color)
	color = color or H.Rune
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		neon(parent, V(0.5, 0.06, 1.4), CF(pos + V(math.cos(a) * r, 0.06, math.sin(a) * r)) * ANG(0, -a, 0), color)
	end
	for i = 0, 2 do
		neon(parent, V(1.6 * r, 0.05, 0.25), CF(pos + V(0, 0.05, 0)) * ANG(0, rad(i * 60), 0), color, { Transparency = 0.3 })
	end
end

-- круглый остров с ярусами снизу, кромкой и светящимся кончиком
function Kit.IslandDisc(parent, center, R, rng, placeable)
	local top = cylY(parent, "IslandTop", R, 4, center - V(0, 2, 0), H.Ground)
	if placeable then
		top:SetAttribute("Placeable", true)
	end
	local layers = { { 0.95, 10, -8 }, { 0.78, 14, -19 }, { 0.56, 16, -33 }, { 0.32, 16, -48 }, { 0.14, 14, -62 } }
	for i, L in ipairs(layers) do
		cylY(parent, "Bedrock" .. i, R * L[1], L[2], center + V(rng:NextNumber(-4, 4), L[3], rng:NextNumber(-4, 4)), i % 2 == 0 and H.Rock or H.Rock2)
	end
	for i = 0, 23 do
		local a = i / 24 * math.pi * 2
		local s = rng:NextNumber(10, 18)
		block(parent, V(s, rng:NextNumber(5, 8), s), CF(center + V(math.cos(a) * (R - 4), -3.5, math.sin(a) * (R - 4))) * ANG(0, a + rng:NextNumber(-0.3, 0.3), 0), i % 2 == 0 and H.Rock or H.Rock2, nil, { Name = "EdgeRock" })
	end
	local tip = neon(parent, V(8, 18, 8), CF(center - V(0, 76, 0)) * ANG(rad(8), rad(45), 0), H.Ember, { Name = "IslandTip" })
	light(tip, H.Orange, 40, 2)
	return top
end

-- пятна травы на круглом острове
function Kit.Patches(parent, center, R, rng, n, placeable)
	for i = 1, n do
		local a, d = rng:NextNumber(0, math.pi * 2), rng:NextNumber(0, R - 14)
		local w, l = rng:NextNumber(10, 26), rng:NextNumber(10, 22)
		local p = part(parent, {
			Name = "Patch", Size = V(w, 0.2, l), CFrame = CF(center + V(math.cos(a) * d, 0.02 + 0.004 * i, math.sin(a) * d)) * ANG(0, rng:NextNumber(0, 3), 0),
			Color = i % 3 == 0 and H.GrassP or (i % 3 == 1 and H.Grass or H.Ground2), Material = Enum.Material.Grass, CastShadow = false,
		})
		if placeable then
			p:SetAttribute("Placeable", true)
		end
	end
end

-- дорога по точкам: полотно + бордюр; extra(i, a, b, cf, len, dir) — украшения сегмента
function Kit.Road(parent, points, y, w, roadColor, edgeColor, extra)
	for i = 2, #points do
		local a, b = points[i - 1], points[i]
		local mid = (a + b) / 2
		local len = (b - a).Magnitude
		local cf = CFrame.lookAt(V(mid.X, y + 0.15, mid.Z), V(b.X, y + 0.15, b.Z))
		block(parent, V(w, 0.3, len + w), cf, roadColor, Enum.Material.Cobblestone, { Name = "Road" })
		block(parent, V(w + 1.6, 0.22, len + w + 1.6), cf * CF(0, -0.06, 0), edgeColor, Enum.Material.Slate, { Name = "RoadEdge" })
		if extra then
			extra(i, a, b, cf, len, (b - a).Unit)
		end
	end
end

-- телепорт-подсказка: квадрат прибытия со свечением
function Kit.ArrivalPad(parent, pos, color, glow)
	block(parent, V(8, 1, 8), CF(pos + V(0, 0.5, 0)), color, nil, { Name = "BattlePad" })
	neon(parent, V(7, 0.05, 7), CF(pos + V(0, 1.03, 0)), glow, { Name = "BattlePadGlow", Transparency = 0.6 })
end

return Kit
