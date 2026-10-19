--!nocheck
-- VOID TD :: HalloweenWorld
-- Хэллоуин-мир из примитивов (без внешних ассетов):
--   • огромный портал HALLOWEEN EVENT в главном лобби;
--   • Хэллоуин-остров: луна, готический замок, кладбище, тыквенные поля, мёртвые деревья, призраки,
--     летучие мыши, вороны, фонари, туман, руны, разрушенные башни, мост, домики; кейс, 4 квадрата
--     входа в бой, доска наград, превью хэллоуинских юнитов и бестиарий;
--   • карта Haunted Hollow: длинная извилистая дорога, кладбище, поля тыкв, готические здания, лес,
--     база игрока (VoidCore) и портал врагов (VoidPortal).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("VoidTD")
local Config = require(Shared:WaitForChild("Config"))
local PathUtil = require(Shared:WaitForChild("PathUtil"))

local HalloweenWorld = {}

local V = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles
local rad = math.rad

local H -- хелперы MapBuilder (part, light, emitter, cylinderY, billboard, statue, calm, zoneCircle)

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

-- палитра: чёрный, тёмно-фиолетовый, оранжевый, бордовый, золото
local C = {
	Black = rgb(14, 10, 16),
	Ground = rgb(34, 26, 36),
	Ground2 = rgb(44, 30, 40),
	Grass = rgb(46, 34, 30),
	GrassP = rgb(42, 24, 54),
	Rock = rgb(30, 24, 32),
	Rock2 = rgb(44, 36, 46),
	Stone = rgb(78, 70, 82),
	Stone2 = rgb(58, 52, 64),
	Road = rgb(64, 54, 58),
	RoadEdge = rgb(44, 36, 42),
	Purple = rgb(70, 30, 110),
	DeepPurple = rgb(36, 18, 56),
	Orange = rgb(255, 130, 30),
	Ember = rgb(255, 90, 20),
	Pumpkin = rgb(220, 110, 30),
	PumpkinD = rgb(170, 70, 20),
	Stem = rgb(60, 70, 30),
	Burgundy = rgb(100, 20, 34),
	Gold = rgb(200, 156, 60),
	Bark = rgb(32, 24, 26),
	Bone = rgb(200, 192, 176),
	Ghost = rgb(220, 225, 255),
	Fog = rgb(150, 140, 170),
	Moon = rgb(255, 214, 150),
	Window = rgb(255, 160, 60),
	Rune = rgb(170, 70, 255),
}

local SMOKE = "rbxasset://textures/particles/smoke_main.dds"

------------------------------------------------------------------------
-- ДЕТАЛИ
------------------------------------------------------------------------
local function block(parent, size, cf, color, mat, props)
	local o = { Size = size, CFrame = cf, Color = color, Material = mat or Enum.Material.Slate }
	if props then
		for k, v in pairs(props) do
			o[k] = v
		end
	end
	return H.part(parent, o)
end

local function neon(parent, size, cf, color, props)
	local o = { CanCollide = false }
	if props then
		for k, v in pairs(props) do
			o[k] = v
		end
	end
	return block(parent, size, cf, color, Enum.Material.Neon, o)
end

local function wedge(parent, size, cf, color, mat, collide)
	return H.part(parent, { Class = "WedgePart", Size = size, CFrame = cf, Color = color, Material = mat or Enum.Material.Slate, CanCollide = collide == true })
end

local function fogEmitter(p, color, rate, size)
	local e = Instance.new("ParticleEmitter")
	e.Name = "Fog"
	e.Texture = SMOKE
	e.Color = ColorSequence.new(color or C.Fog)
	e.LightEmission = 0.1
	e.LightInfluence = 0.6
	e.Rate = rate or 2
	e.Lifetime = NumberRange.new(5, 8)
	e.Speed = NumberRange.new(0.3, 1)
	e.SpreadAngle = Vector2.new(180, 10)
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-10, 10)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size or 6), NumberSequenceKeypoint.new(1, (size or 6) * 1.8) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.75), NumberSequenceKeypoint.new(1, 1) })
	e.Parent = p
	return e
end

-- угловатая тыква: 6 рёбер-долек вокруг оси, хвостик; carved — вырезанное светящееся лицо
local function pumpkin(parent, pos, s, carved, yaw)
	local m = Instance.new("Model")
	m.Name = "Pumpkin"
	m.Parent = parent
	local base = CF(pos + V(0, 0.55 * s, 0)) * ANG(0, yaw or 0, 0)
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2
		block(m, V(0.62 * s, 1.0 * s, 0.62 * s), base * ANG(0, a, 0) * CF(0, 0, -0.38 * s), (i % 2 == 0) and C.Pumpkin or C.PumpkinD, Enum.Material.SmoothPlastic, { CanCollide = false })
	end
	block(m, V(0.18 * s, 0.4 * s, 0.18 * s), base * CF(0, 0.62 * s, 0) * ANG(0, 0, rad(12)), C.Stem, Enum.Material.Wood, { CanCollide = false })
	if carved then
		local f = base * CF(0, 0, -0.72 * s)
		for _, sx in ipairs({ -1, 1 }) do
			neon(m, V(0.2 * s, 0.2 * s, 0.06), f * CF(0.2 * s * sx, 0.15 * s, 0) * ANG(0, 0, rad(45)), C.Orange)
		end
		neon(m, V(0.5 * s, 0.1 * s, 0.06), f * CF(0, -0.2 * s, 0), C.Orange)
		if s >= 1.2 then
			H.light(m:FindFirstChildWhichIsA("BasePart"), C.Orange, 8 * s, 0.8)
		end
	end
	return m
end

local function deadTree(parent, rng, pos, s)
	s = s or 1
	local m = Instance.new("Model")
	m.Name = "DeadTree"
	m.Parent = parent
	local h = rng:NextNumber(9, 14) * s
	local lean = rad(rng:NextNumber(-6, 6))
	local trunk = CF(pos) * ANG(lean, rng:NextNumber(0, 6), lean * 0.5)
	block(m, V(1.4 * s, h, 1.4 * s), trunk * CF(0, h / 2, 0), C.Bark, Enum.Material.Wood)
	block(m, V(2.4 * s, 1.2 * s, 2.4 * s), trunk * CF(0, 0.4 * s, 0) * ANG(0, rad(45), 0), C.Bark, Enum.Material.Wood)
	for i = 1, 4 do
		local a = i / 4 * math.pi * 2 + rng:NextNumber(-0.4, 0.4)
		local y = h * rng:NextNumber(0.5, 0.95)
		local L = rng:NextNumber(3, 5.5) * s
		local br = trunk * CF(0, y, 0) * ANG(0, a, 0) * ANG(0, 0, rad(rng:NextNumber(45, 65)))
		block(m, V(0.5 * s, L, 0.5 * s), br * CF(0, L / 2, 0), C.Bark, Enum.Material.Wood, { CanCollide = false })
		local tw = br * CF(0, L, 0) * ANG(0, 0, rad(-35))
		block(m, V(0.3 * s, L * 0.5, 0.3 * s), tw * CF(0, L * 0.25, 0), C.Bark, Enum.Material.Wood, { CanCollide = false })
	end
	return m
end

local function tombstone(parent, rng, pos, yaw)
	local kind = rng:NextInteger(1, 3)
	local cf = CF(pos) * ANG(rad(rng:NextNumber(-6, 6)), yaw or 0, rad(rng:NextNumber(-8, 8)))
	if kind == 1 then
		block(parent, V(2, 2.6, 0.5), cf * CF(0, 1.3, 0), C.Stone2)
		block(parent, V(1.6, 0.6, 0.5), cf * CF(0, 2.8, 0) * ANG(0, 0, rad(45)), C.Stone2)
	elseif kind == 2 then
		block(parent, V(0.45, 3.2, 0.45), cf * CF(0, 1.6, 0), C.Stone)
		block(parent, V(1.8, 0.45, 0.45), cf * CF(0, 2.3, 0), C.Stone)
	else
		block(parent, V(2.4, 1.6, 0.7), cf * CF(0, 0.8, 0), C.Stone2)
		block(parent, V(2.6, 0.3, 0.9), cf * CF(0, 1.7, 0), C.Stone)
	end
	-- холмик могилы
	block(parent, V(2.2, 0.4, 3.6), cf * CF(0, 0.15, 1.9), C.Grass, Enum.Material.Ground, { CanCollide = false })
end

local function fence(parent, a, b, color)
	local d = b - a
	local n = math.max(1, math.floor(d.Magnitude / 2.2))
	for i = 0, n do
		local p = a + d * (i / n)
		block(parent, V(0.3, 2.6, 0.3), CF(p + V(0, 1.3, 0)), color or C.Black, Enum.Material.Metal)
		wedge(parent, V(0.3, 0.5, 0.3), CF(p + V(0, 2.85, 0)), color or C.Black, Enum.Material.Metal)
	end
	local mid = (a + b) / 2
	local cf = CFrame.lookAt(mid, b)
	block(parent, V(0.18, 0.18, d.Magnitude), cf * CF(0, 2.1, 0), color or C.Black, Enum.Material.Metal)
	block(parent, V(0.18, 0.18, d.Magnitude), cf * CF(0, 0.8, 0), color or C.Black, Enum.Material.Metal)
end

local function lanternPost(parent, pos, h)
	h = h or 7
	block(parent, V(0.5, h, 0.5), CF(pos + V(0, h / 2, 0)), C.Black, Enum.Material.Metal)
	block(parent, V(1.8, 0.3, 0.3), CF(pos + V(0.6, h - 0.3, 0)), C.Black, Enum.Material.Metal)
	local cage = block(parent, V(0.9, 1.1, 0.9), CF(pos + V(1.3, h - 1.2, 0)), C.Black, Enum.Material.Metal, { CanCollide = false, Transparency = 0.2 })
	local flame = neon(parent, V(0.55, 0.7, 0.55), CF(pos + V(1.3, h - 1.2, 0)), C.Orange)
	H.light(flame, C.Orange, 16, 1.4)
	wedge(parent, V(1.1, 0.5, 1.1), CF(pos + V(1.3, h - 0.45, 0)), C.Black, Enum.Material.Metal)
	return cage
end

local function bat(parent, pos, r, speed)
	local m = Instance.new("Model")
	m.Name = "Bat"
	m.Parent = parent
	local body = block(m, V(0.6, 0.5, 0.9), CF(pos + V(r, 0, 0)), C.Black, Enum.Material.SmoothPlastic, { CanCollide = false })
	for _, s in ipairs({ -1, 1 }) do
		wedge(m, V(0.1, 0.6, 1.6), CF(pos + V(r + 0.9 * s, 0.1, 0)) * ANG(0, 0, rad(-70 * s)), C.Black, Enum.Material.SmoothPlastic)
	end
	neon(m, V(0.3, 0.1, 0.05), CF(pos + V(r, 0.08, -0.46)), C.Ember)
	-- летает по кругу вокруг pos (вращается вся модель)
	m.WorldPivot = CF(pos)
	m:SetAttribute("Spin", speed)
	m:SetAttribute("SpinAxis", "Y")
	m:SetAttribute("BobAmp", 0.8)
	m:SetAttribute("BobSpeed", 2.2)
	m.PrimaryPart = body
	return m
end

local function crow(parent, pos, yaw)
	local cf = CF(pos) * ANG(0, yaw or 0, 0)
	block(parent, V(0.5, 0.5, 0.9), cf * CF(0, 0.35, 0), C.Black, Enum.Material.SmoothPlastic, { CanCollide = false })
	block(parent, V(0.4, 0.4, 0.4), cf * CF(0, 0.75, -0.4), C.Black, Enum.Material.SmoothPlastic, { CanCollide = false })
	wedge(parent, V(0.15, 0.15, 0.4), cf * CF(0, 0.7, -0.75) * ANG(rad(90), 0, 0), C.Gold, Enum.Material.SmoothPlastic)
	wedge(parent, V(0.3, 0.12, 0.6), cf * CF(0, 0.3, 0.6) * ANG(rad(180), 0, 0), C.Black, Enum.Material.SmoothPlastic)
end

local function ghost(parent, pos, s)
	s = s or 1
	local m = Instance.new("Model")
	m.Name = "Ghost"
	m.Parent = parent
	local body = block(m, V(2.2 * s, 2.4 * s, 1.8 * s), CF(pos + V(0, 1.6 * s, 0)), C.Ghost, Enum.Material.SmoothPlastic, { CanCollide = false, Transparency = 0.55 })
	block(m, V(1.8 * s, 1.6 * s, 1.6 * s), CF(pos + V(0, 3.4 * s, 0)), C.Ghost, Enum.Material.SmoothPlastic, { CanCollide = false, Transparency = 0.55 })
	for i = -1, 1 do
		wedge(m, V(0.7 * s, 0.9 * s, 1.6 * s), CF(pos + V(i * 0.7 * s, 0.05, 0)) * ANG(0, 0, rad(180)), C.Ghost, Enum.Material.SmoothPlastic).Transparency = 0.55
	end
	for _, sx in ipairs({ -1, 1 }) do
		block(m, V(0.3 * s, 0.45 * s, 0.05), CF(pos + V(0.35 * s * sx, 3.5 * s, -0.81 * s)), C.Black, Enum.Material.SmoothPlastic, { CanCollide = false })
	end
	m.PrimaryPart = body
	m:SetAttribute("BobAmp", 1.2)
	m:SetAttribute("BobSpeed", 1.1)
	return m
end

-- готическая крыша-шпиль из уменьшающихся блоков
local function spire(parent, cf, w, h, color)
	local n = 5
	for i = 0, n - 1 do
		local k = 1 - i / n
		block(parent, V(w * k, h / n, w * k), cf * CF(0, h / n * (i + 0.5), 0) * ANG(0, rad(45 * (i % 2)), 0), color or C.DeepPurple)
	end
	block(parent, V(0.3, h * 0.35, 0.3), cf * CF(0, h + h * 0.17, 0), C.Gold, Enum.Material.Metal, { CanCollide = false })
end

local function tower(parent, base, w, h, ruined, rng)
	block(parent, V(w, h, w), CF(base + V(0, h / 2, 0)), C.Stone2)
	-- окна
	for i = 1, math.floor(h / 7) do
		for k = 0, 3 do
			local cf = CF(base + V(0, i * 7 - 2, 0)) * ANG(0, k * math.pi / 2, 0) * CF(0, 0, -w / 2 - 0.05)
			neon(parent, V(1.1, 2.2, 0.1), cf, C.Window)
			wedge(parent, V(1.1, 0.7, 0.12), cf * CF(0, 1.45, 0), C.Window, Enum.Material.Neon)
		end
	end
	if ruined then
		for i = 1, 5 do
			local a = i / 5 * math.pi * 2
			local hh = rng:NextNumber(1, 4)
			block(parent, V(w * 0.35, hh, w * 0.35), CF(base + V(math.cos(a) * w * 0.35, h + hh / 2, math.sin(a) * w * 0.35)) * ANG(0, a, rad(rng:NextNumber(-10, 10))), C.Stone2)
		end
	else
		block(parent, V(w + 1.2, 1, w + 1.2), CF(base + V(0, h + 0.5, 0)), C.Stone)
		spire(parent, CF(base + V(0, h + 1, 0)), w + 0.4, w * 2.2, C.DeepPurple)
	end
end

local function house(parent, pos, yaw, s)
	s = s or 1
	local cf = CF(pos) * ANG(0, yaw, 0)
	block(parent, V(10 * s, 7 * s, 8 * s), cf * CF(0, 3.5 * s, 0), C.Rock2, Enum.Material.WoodPlanks)
	for _, sx in ipairs({ -1, 1 }) do
		wedge(parent, V(10.6 * s, 4.5 * s, 4.6 * s), cf * CF(0, 9.25 * s, 2.3 * s * sx) * ANG(0, sx == 1 and math.pi or 0, 0), C.Burgundy, Enum.Material.Slate, true)
	end
	block(parent, V(1.2 * s, 4 * s, 1.2 * s), cf * CF(3 * s, 10 * s, 1.5 * s), C.Stone2)
	block(parent, V(2.2 * s, 3.8 * s, 0.2), cf * CF(0, 1.9 * s, -4.05 * s), C.Bark, Enum.Material.Wood)
	for _, sx in ipairs({ -1, 1 }) do
		neon(parent, V(1.6 * s, 1.6 * s, 0.1), cf * CF(3 * s * sx, 4 * s, -4.05 * s), C.Window)
	end
	H.light(block(parent, V(0.5, 0.5, 0.5), cf * CF(0, 4 * s, -5 * s), C.Black, Enum.Material.SmoothPlastic, { Transparency = 1, CanCollide = false }), C.Window, 14, 1)
end

local function runeCircle(parent, pos, r, color)
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		neon(parent, V(0.5, 0.06, 1.4), CF(pos + V(math.cos(a) * r, 0.06, math.sin(a) * r)) * ANG(0, -a, 0), color or C.Rune)
	end
	for i = 0, 2 do
		neon(parent, V(r * 1.6, 0.05, 0.25), CF(pos + V(0, 0.05, 0)) * ANG(0, i * math.pi / 3, 0), color or C.Rune, { Transparency = 0.3 })
	end
end

-- круглый остров со скальным низом
local function islandDisc(parent, center, R, rng, placeable)
	local top = H.cylinderY(parent, "IslandTop", R, 4, center + V(0, -2, 0), C.Ground)
	top:SetAttribute("Placeable", placeable or nil)
	local layers = { { 0.95, 10, -8 }, { 0.78, 14, -19 }, { 0.56, 16, -33 }, { 0.32, 16, -48 }, { 0.14, 14, -62 } }
	for i, l in ipairs(layers) do
		H.cylinderY(parent, "Bedrock" .. i, R * l[1], l[2], center + V(rng:NextNumber(-4, 4), l[3], rng:NextNumber(-4, 4)), (i % 2 == 0) and C.Rock or C.Rock2)
	end
	for i = 0, 23 do
		local a = i / 24 * math.pi * 2
		local s = rng:NextNumber(10, 18)
		block(parent, V(s, rng:NextNumber(5, 8), s), CF(center + V(math.cos(a) * (R - 4), -3.5, math.sin(a) * (R - 4))) * ANG(0, a + rng:NextNumber(-0.3, 0.3), 0), (i % 2 == 0) and C.Rock or C.Rock2)
	end
	local tip = neon(parent, V(8, 18, 8), CF(center + V(0, -76, 0)) * ANG(rad(8), rad(45), 0), C.Ember)
	H.light(tip, C.Orange, 40, 2)
	return top
end

local function patches(parent, center, R, rng, n, placeable)
	for i = 1, n do
		local a, d = rng:NextNumber(0, math.pi * 2), rng:NextNumber(0, R - 14)
		local w, l = rng:NextNumber(10, 26), rng:NextNumber(10, 22)
		local p = block(parent, V(w, 0.2, l), CF(center + V(math.cos(a) * d, 0.02 + i * 0.001, math.sin(a) * d)) * ANG(0, rng:NextNumber(0, 3), 0),
			(i % 3 == 0) and C.GrassP or ((i % 3 == 1) and C.Grass or C.Ground2), Enum.Material.Grass, { CastShadow = false })
		p:SetAttribute("Placeable", placeable or nil)
	end
end

local function surfaceSign(parent, cf, size, title, sub, titleColor, frameColor)
	local sign = block(parent, size, cf, C.Black)
	neon(parent, size + V(1, 1, -size.Z + 0.3), cf * CF(0, 0, size.Z / 2 + 0.1), frameColor or C.Orange)
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Front
	sg.LightInfluence = 0
	sg.PixelsPerStud = 30
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.Parent = sign
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, sub and 0.62 or 1)
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.RichText = true
	t.Text = title
	t.TextColor3 = titleColor or C.Orange
	t.TextStrokeTransparency = 0
	t.Parent = sg
	if sub then
		local st = t:Clone()
		st.Position = UDim2.fromScale(0.04, 0.62)
		st.Size = UDim2.fromScale(0.92, 0.34)
		st.Font = Enum.Font.GothamBold
		st.Text = sub
		st.TextColor3 = rgb(245, 230, 210)
		st.Parent = sg
	end
	return sign
end

------------------------------------------------------------------------
-- ПОРТАЛ HALLOWEEN EVENT В ГЛАВНОМ ЛОББИ
------------------------------------------------------------------------
local function buildLobbyPortal()
	local lobby = workspace:FindFirstChild("VoidTDLobby")
	if not lobby or lobby:FindFirstChild("HalloweenGate") then
		return
	end
	local L = Config.Lobby
	local z = L.Zones.HalloweenPortal
	if not z then
		return
	end
	local m = Instance.new("Model")
	m.Name = "HalloweenGate"
	local zc = L.Center + z.Offset
	local out = V(z.Offset.X, 0, z.Offset.Z).Unit
	local pc = zc + out * 9
	local face = CFrame.lookAt(pc, pc - out)
	local R = 13
	-- готическая арка: камни по окружности + шипы
	for i = 0, 19 do
		local a = i / 20 * math.pi * 2
		local cf = face * CF(math.cos(a) * R, R + 1 + math.sin(a) * R, 0) * ANG(0, 0, a)
		block(m, V(4, 3.4, 3), cf, (i % 2 == 0) and C.Stone2 or C.Black)
		if i % 2 == 0 then
			wedge(m, V(1.2, 2.4, 1.2), cf * CF(1.8, 0, 0) * ANG(0, 0, rad(-90)), C.Black, Enum.Material.Slate)
		end
		if i % 5 == 0 then
			neon(m, V(0.6, 1.4, 0.3), cf * CF(0, 0, -1.6), C.Orange)
		end
	end
	local disc = H.part(m, { Name = "PortalDisc", Shape = Enum.PartType.Cylinder, Size = V(0.4, R * 2 - 3, R * 2 - 3), CFrame = face * CF(0, R + 1, 0) * ANG(0, rad(90), 0), Color = rgb(150, 60, 20), Material = Enum.Material.Neon, Transparency = 0.25, CanCollide = false })
	for i = 0, 2 do
		local sw = neon(m, V(0.7, R * 1.7, 0.6), face * CF(0, R + 1, -0.4) * ANG(0, 0, rad(i * 60)), (i == 1) and C.Purple or C.Orange, { Transparency = 0.35 })
		sw:SetAttribute("Spin", -1.2 - i * 0.3)
		sw:SetAttribute("SpinAxis", "Z")
	end
	H.light(disc, C.Orange, 50, 3)
	H.emitter(disc, C.Orange, { Rate = 26, Size = 0.7, SpeedMin = 2, SpeedMax = 5 })
	fogEmitter(block(m, V(20, 1, 6), face * CF(0, 0.5, 0), C.Stone2), C.Fog, 3, 7)
	-- тыквы и фонари по сторонам
	for _, sx in ipairs({ -1, 1 }) do
		pumpkin(m, (face * CF(sx * 16, 0, 2)).Position, 2.2, true, 0)
		pumpkin(m, (face * CF(sx * 19, 0, -1)).Position, 1.4, true, 0.5)
		lanternPost(m, (face * CF(sx * 12, 0, 5)).Position, 9)
	end
	surfaceSign(m, face * CF(0, R * 2 + 7, 0) * ANG(0, math.pi, 0), V(30, 7, 1), "HALLOWEEN EVENT", "🎃 остров, кейс, боссы и Halloween Coins", C.Orange, C.Orange)
	for i = 1, 3 do
		bat(m, zc + V(0, 22 + i * 3, 0), 8 + i * 3, 0.6 + i * 0.2)
	end
	H.calm(m)
	m.Parent = lobby
end

------------------------------------------------------------------------
-- ХЭЛЛОУИН-ОСТРОВ
------------------------------------------------------------------------
local function buildIsland()
	local existing = workspace:FindFirstChild("VoidTDHalloween")
	if existing then
		return existing
	end
	local I = Config.HalloweenIsland
	local c = I.Center
	local rng = Random.new(1031)
	local m = Instance.new("Model")
	m.Name = "VoidTDHalloween"

	islandDisc(m, c, I.Radius, rng, false)
	patches(m, c, I.Radius, rng, 14, false)

	-- ЛУНА и туман
	local moon = neon(m, V(70, 70, 70), CF(c + V(-40, 150, -330)), C.Moon, { Shape = Enum.PartType.Ball })
	block(m, V(68, 68, 68), CF(c + V(-22, 156, -318)), rgb(20, 12, 28), Enum.Material.SmoothPlastic, { Shape = Enum.PartType.Ball, CanCollide = false, Transparency = 0.25 })
	H.light(moon, C.Moon, 60, 1)
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2
		fogEmitter(block(m, V(30, 1, 30), CF(c + V(math.cos(a) * 55, 0.5, math.sin(a) * 55)), C.Ground, Enum.Material.Slate, { Transparency = 1, CanCollide = false }), C.Fog, 1.5, 9)
	end

	-- ЗАМОК на дальнем краю
	local cz = c + V(0, 0, -90)
	block(m, V(46, 22, 16), CF(cz + V(0, 11, 0)), C.Stone2)
	block(m, V(48, 1.5, 18), CF(cz + V(0, 22.7, 0)), C.Stone)
	for i = -5, 5 do
		block(m, V(2.4, 2.4, 2), CF(cz + V(i * 4.2, 24.6, -8.2)), C.Stone2)
	end
	tower(m, cz + V(0, 0, 2), 12, 36, false, rng)
	tower(m, cz + V(-25, 0, 2), 9, 30, false, rng)
	tower(m, cz + V(25, 0, 2), 9, 30, false, rng)
	for _, sx in ipairs({ -1, 1 }) do
		for k = 0, 3 do
			local cf = CF(cz + V(sx * (6 + k * 4.5), 9, -8.05))
			neon(m, V(1.6, 4, 0.1), cf, C.Window)
			wedge(m, V(1.6, 1.2, 0.12), cf * CF(0, 2.6, 0), C.Window, Enum.Material.Neon)
		end
	end
	-- ворота замка
	block(m, V(8, 11, 0.6), CF(cz + V(0, 5.5, -8.3)), C.Bark, Enum.Material.Wood)
	neon(m, V(1, 1, 0.1), CF(cz + V(0, 7, -8.65)) * ANG(0, 0, rad(45)), C.Orange)
	surfaceSign(m, CF(cz + V(0, 30, -9)) * ANG(0, math.pi, 0), V(26, 6, 1), "HAUNTED HOLLOW", "Хэллоуин-остров VOID TD", C.Orange, C.Burgundy)
	-- разрушенные башни по краям
	tower(m, c + V(-78, 0, -48), 8, 18, true, rng)
	tower(m, c + V(80, 0, -44), 8, 22, true, rng)

	-- ЗОНЫ-КРУГИ
	local zf = Instance.new("Folder")
	zf.Name = "Zones"
	zf.Parent = m
	for key, z in pairs(I.Zones) do
		local sub = z.Case and "500 🎃 Halloween Coins" or nil
		H.zoneCircle(zf, key, z, c + z.Offset, sub, rgb(30, 14, 18))
	end

	-- КЕЙС: проклятый сундук на постаменте за кругом
	do
		local z = I.Zones.Case_Halloween
		local zc = c + z.Offset
		local out = V(z.Offset.X, 0, z.Offset.Z).Unit
		local sp = zc + out * 13
		H.part(m, { Name = "CaseStand", Shape = Enum.PartType.Cylinder, Size = V(2.5, 10, 10), CFrame = CF(sp + V(0, 1.25, 0)) * ANG(0, 0, rad(90)), Color = C.Black, Material = Enum.Material.Slate })
		H.part(m, { Name = "CaseStandRing", Shape = Enum.PartType.Cylinder, Size = V(0.3, 10.4, 10.4), CFrame = CF(sp + V(0, 2.4, 0)) * ANG(0, 0, rad(90)), Color = C.Gold, Material = Enum.Material.Neon, CanCollide = false })
		local okCM, CaseModels = pcall(require, Shared:WaitForChild("CaseModels"))
		if okCM then
			local cm = CaseModels.Build("Halloween").Model
			cm:ScaleTo(1.7)
			cm:PivotTo(CF(sp + V(0, 2.6, 0)) * CFrame.lookAt(Vector3.zero, -out).Rotation)
			cm:SetAttribute("Spin", 0.4)
			cm:SetAttribute("SpinAxis", "Y")
			cm.Parent = m
		end
		local glow = block(m, V(0.5, 0.5, 0.5), CF(sp + V(0, 6, 0)), C.Black, Enum.Material.SmoothPlastic, { Transparency = 1, CanCollide = false })
		H.light(glow, C.Orange, 24, 2)
		H.billboard(m, sp + V(0, 13.5, 0), "HALLOWEEN CASE", "🎃 500 Halloween Coins", C.Orange, 14)
		for i = 0, 5 do
			local a = i / 6 * math.pi * 2
			pumpkin(m, sp + V(math.cos(a) * 7.5, 0, math.sin(a) * 7.5), 1 + (i % 2) * 0.4, i % 2 == 0, a)
		end
	end

	-- ОЧЕРЕДЬ: 4 светящихся квадрата входа в бой
	do
		local Q = I.Queue
		local qc = c + Q.Offset
		block(m, V(30, 0.6, 22), CF(qc + V(0, 0.3, 0)), C.Black)
		for i, off in ipairs(Q.Pads) do
			local p = qc + off
			neon(m, V(Q.Pad + 0.6, 0.65, Q.Pad + 0.6), CF(p + V(0, 0.33, 0)), C.Orange)
			local pad = block(m, V(Q.Pad, 0.7, Q.Pad), CF(p + V(0, 0.36, 0)), rgb(40, 16, 10), Enum.Material.Glass, { Transparency = 0.15 })
			pad.Name = "QueuePad" .. i
			H.light(pad, C.Orange, 14, 1.5)
			H.emitter(pad, C.Orange, { Rate = 10, Size = 0.4, SpeedMin = 2, SpeedMax = 4, Spread = 15, Dir = Enum.NormalId.Top, LifeMin = 1, LifeMax = 2 })
			local beam = neon(m, V(Q.Pad * 0.8, 18, Q.Pad * 0.8), CF(p + V(0, 9, 0)), C.Orange, { Transparency = 0.9 })
			beam.CastShadow = false
		end
		-- арка над входом и вывеска
		for _, sx in ipairs({ -1, 1 }) do
			block(m, V(2.4, 16, 2.4), CF(qc + V(sx * 16, 8, -12)), C.Stone2)
			pumpkin(m, qc + V(sx * 16, 16, -12), 1.6, true, 0)
		end
		block(m, V(34, 2, 2.4), CF(qc + V(0, 15, -12)), C.Stone2)
		surfaceSign(m, CF(qc + V(0, 20, -12)) * ANG(0, math.pi, 0), V(26, 6, 1), "HALLOWEEN TD", "встань на квадрат • до 4 игроков • хост выбирает сложность", C.Orange, C.Orange)
		H.billboard(m, qc + V(0, 7, 0), "ВХОД В БОЙ", "встань на светящийся квадрат", C.Orange, 13)
		-- доска наград
		surfaceSign(m, CF(qc + V(24, 6, 6)) * ANG(0, rad(-90), 0) * ANG(0, math.pi, 0), V(12, 9, 0.8),
			"НАГРАДЫ", "ЛЁГКАЯ — 100 🎃\nСРЕДНЯЯ — 150 🎃\nСЛОЖНАЯ — 250 🎃\nтолько за победу", C.Gold, C.Gold)
		block(m, V(0.8, 2, 0.8), CF(qc + V(24, 1, 6)), C.Black)
	end

	-- ПРЕВЬЮ ХЭЛЛОУИНСКИХ ЮНИТОВ: статуи у круга
	do
		local uz = c + I.Zones.HalloweenUnits.Offset
		local list = { "LanternKing", "HalloweenPuppeteer", "HeadlessExecutioner", "PlagueDoctor", "PhantomKnight" }
		for i, id in ipairs(list) do
			local a = rad(140 + (i - 1) * 25)
			pcall(H.statue, m, id, uz + V(math.cos(a) * 15, 0, math.sin(a) * 15), uz, i == 1 and 4 or 3)
		end
	end

	-- БЕСТИАРИЙ: боссы на постаментах
	do
		local bz = c + I.Zones.Bestiary.Offset
		local okE, EnemyModels = pcall(require, Shared:WaitForChild("EnemyModels"))
		if okE then
			for i, id in ipairs({ "GraveWarden", "FogReaper", "CursedMonarch" }) do
				local pos = bz + V(16, 0, (i - 2) * 12)
				block(m, V(7, 3, 7), CF(pos + V(0, 1.5, 0)), C.Stone2)
				neon(m, V(7.4, 0.25, 7.4), CF(pos + V(0, 2.6, 0)), ({ rgb(90, 220, 120), rgb(255, 205, 70), rgb(255, 90, 80) })[i])
				local ok, rig = pcall(EnemyModels.Build, id)
				if ok and rig then
					local model = rig.Model
					model:ScaleTo(0.75)
					local hip = (rig.HipHeight or 3) * 0.75
					local base = pos + V(0, 3 + hip, 0)
					model:PivotTo(CFrame.lookAt(base, V(bz.X, base.Y, bz.Z)))
					for _, d in ipairs(model:GetDescendants()) do
						if d:IsA("BasePart") then
							d.Anchored = true
							d.CanCollide = false
						end
					end
					model.Name = "Bestiary_" .. id
					model.Parent = m
				end
				H.billboard(m, pos + V(0, 13, 0), Config.Enemies[id].Name, ({ "босс ЛЁГКОЙ", "босс СРЕДНЕЙ", "босс СЛОЖНОЙ" })[i], ({ rgb(90, 220, 120), rgb(255, 205, 70), rgb(255, 90, 80) })[i], 10)
			end
		end
	end

	-- КЛАДБИЩЕ (восток)
	do
		local g = c + V(52, 0, 44)
		for x = 0, 3 do
			for zz = 0, 2 do
				tombstone(m, rng, g + V(x * 6 - 9, 0, zz * 7 - 7), rng:NextNumber(-0.3, 0.3))
			end
		end
		fence(m, g + V(-14, 0, -12), g + V(14, 0, -12))
		fence(m, g + V(14, 0, -12), g + V(14, 0, 14))
		fence(m, g + V(-14, 0, 14), g + V(14, 0, 14))
		crow(m, g + V(14, 2.9, 2), rad(-90))
		crow(m, g + V(-6, 2.9, -12), 0)
		ghost(m, g + V(2, 2, 2), 1.1)
		fogEmitter(block(m, V(26, 1, 24), CF(g + V(0, 0.5, 0)), C.Ground, Enum.Material.Slate, { Transparency = 1, CanCollide = false }), rgb(120, 200, 130), 2, 6)
	end

	-- ТЫКВЕННОЕ ПОЛЕ (юго-запад)
	do
		local f = c + V(-50, 0, 58)
		block(m, V(30, 0.25, 20), CF(f + V(0, 0.12, 0)), rgb(40, 28, 20), Enum.Material.Ground, { CanCollide = false })
		for x = 0, 4 do
			for zz = 0, 3 do
				pumpkin(m, f + V(x * 6 - 12 + rng:NextNumber(-1, 1), 0, zz * 5 - 7.5 + rng:NextNumber(-1, 1)), rng:NextNumber(0.8, 1.5), rng:NextInteger(1, 4) == 1, rng:NextNumber(0, 6))
			end
		end
		-- пугало
		block(m, V(0.5, 8, 0.5), CF(f + V(0, 4, -11)), C.Bark, Enum.Material.Wood)
		block(m, V(6, 0.5, 0.5), CF(f + V(0, 6, -11)), C.Bark, Enum.Material.Wood)
		block(m, V(2.2, 3, 1.2), CF(f + V(0, 5, -11)), rgb(90, 60, 40), Enum.Material.Fabric)
		pumpkin(m, f + V(0, 6.6, -11), 1.5, true, 0)
		crow(m, f + V(2.6, 6.3, -11), 0.4)
	end

	-- ДОМИКИ, МОСТ, ДЕРЕВЬЯ, ФОНАРИ, ПРИЗРАКИ, МЫШИ, РУНЫ
	house(m, c + V(-80, 0, 0), rad(80), 1)
	house(m, c + V(78, 0, 8), rad(-85), 0.9)
	-- мост к маленькому парящему островку с руинами
	do
		local a = c + V(-96, 0, -20)
		local b = a + V(-28, 0, -6)
		local mid = (a + b) / 2
		local cf = CFrame.lookAt(mid, b)
		for i = -6, 6 do
			block(m, V(5, 0.4, 1.8), cf * CF(0, -0.1 + math.abs(i) * 0.08, i * 2.1) , C.Bark, Enum.Material.WoodPlanks)
		end
		for _, sx in ipairs({ -1, 1 }) do
			block(m, V(0.2, 0.2, 28), cf * CF(sx * 2.4, 1.6, 0), C.Bark, Enum.Material.Wood, { CanCollide = false })
		end
		local isl = b + V(-8, 0, -2)
		H.cylinderY(m, "Islet", 12, 4, isl + V(0, -2, 0), C.Ground)
		H.cylinderY(m, "IsletRock", 8, 12, isl + V(0, -10, 0), C.Rock)
		tower(m, isl, 7, 14, true, rng)
		runeCircle(m, isl + V(0, 0, 8), 4, C.Rune)
	end
	local taken = { c + V(0, 0, 70) }
	for _, z in pairs(I.Zones) do
		taken[#taken + 1] = c + z.Offset
	end
	taken[#taken + 1] = c + I.Queue.Offset
	for i = 1, 26 do
		local a = rng:NextNumber(0, math.pi * 2)
		local d = rng:NextNumber(70, I.Radius - 6)
		local p = c + V(math.cos(a) * d, 0, math.sin(a) * d)
		local free = p.Z > c.Z - 70
		for _, t in ipairs(taken) do
			if (V(p.X - t.X, 0, p.Z - t.Z)).Magnitude < 15 then
				free = false
			end
		end
		if free then
			taken[#taken + 1] = p
			deadTree(m, rng, p, rng:NextNumber(0.9, 1.3))
		end
	end
	for i = 0, 9 do
		local a = i / 10 * math.pi * 2 + 0.2
		lanternPost(m, c + V(math.cos(a) * 34, 0, math.sin(a) * 34), 7)
	end
	ghost(m, c + V(-30, 3, -40), 1.3)
	ghost(m, c + V(36, 4, -60), 1)
	ghost(m, c + V(-70, 2, 30), 0.9)
	for i = 1, 6 do
		bat(m, c + V(rng:NextNumber(-60, 60), rng:NextNumber(26, 40), rng:NextNumber(-70, 40)), rng:NextNumber(8, 18), rng:NextNumber(0.5, 1.2))
	end
	runeCircle(m, c + V(0, 0, 18), 8, C.Rune)
	runeCircle(m, c + V(-20, 0, -64), 5, C.Orange)

	-- точка прибытия (не SpawnLocation: игроки появляются в главном лобби)
	block(m, V(10, 1, 10), CF(I.Spawn + V(0, 0.5, 0)), rgb(60, 26, 20))
	H.cylinderY(m, "SpawnGlow", 4.6, 0.08, I.Spawn + V(0, 1.03, 0), C.Orange, Enum.Material.Neon, { CanCollide = false, Transparency = 0.5 })
	-- портал в лобби
	do
		local z = I.Zones.ReturnPortal
		local zc = c + z.Offset
		local face = CFrame.lookAt(zc + V(0, 0, 8), zc)
		for i = 0, 11 do
			local a = i / 12 * math.pi * 2
			block(m, V(2.6, 2.2, 1.8), face * CF(math.cos(a) * 7, 8 + math.sin(a) * 7, 0) * ANG(0, 0, a), (i % 2 == 0) and C.Stone or C.Stone2)
		end
		local disc = H.part(m, { Name = "ReturnDisc", Shape = Enum.PartType.Cylinder, Size = V(0.4, 12, 12), CFrame = face * CF(0, 8, 0) * ANG(0, rad(90), 0), Color = rgb(120, 40, 210), Material = Enum.Material.Neon, Transparency = 0.25, CanCollide = false })
		H.light(disc, rgb(170, 80, 255), 24, 2)
	end

	m.WorldPivot = CF(c)
	H.calm(m)
	m.Parent = workspace
	return m
end

------------------------------------------------------------------------
-- КАРТА HAUNTED HOLLOW
------------------------------------------------------------------------
local function buildMap()
	local existing = workspace:FindFirstChild("VoidTDHalloweenMap")
	if existing then
		return existing
	end
	local MC = Config.Maps.Halloween
	local c = MC.Center
	local GY = MC.GroundY
	local size = MC.IslandSize
	local rng = Random.new(666)
	PathUtil.SetMap("Halloween")
	local m = Instance.new("Model")
	m.Name = "VoidTDHalloweenMap"

	-- земля (на неё можно ставить юнитов)
	local ground = Instance.new("Folder")
	ground.Name = "Ground"
	ground.Parent = m
	local top = block(ground, V(size.X, 4, size.Y), CF(c.X, GY - 2, c.Z), C.Ground)
	top.Name = "IslandTop"
	top:SetAttribute("Placeable", true)
	for i = 1, 22 do
		local w, d = rng:NextNumber(14, 34), rng:NextNumber(14, 30)
		local x = rng:NextNumber(-size.X / 2 + w / 2 + 2, size.X / 2 - w / 2 - 2)
		local z = rng:NextNumber(-size.Y / 2 + d / 2 + 2, size.Y / 2 - d / 2 - 2)
		local p = block(ground, V(w, 0.2, d), CF(c.X + x, GY + 0.02 + i * 0.001, c.Z + z) * ANG(0, rad(rng:NextNumber(-20, 20)), 0),
			(i % 3 == 0) and C.GrassP or ((i % 3 == 1) and C.Grass or C.Ground2), Enum.Material.Grass, { CastShadow = false })
		p:SetAttribute("Placeable", true)
	end
	-- скальный низ
	local under = Instance.new("Folder")
	under.Name = "Underside"
	under.Parent = m
	for i, l in ipairs({ { 0.92, 12, -9 }, { 0.72, 16, -22 }, { 0.5, 18, -38 }, { 0.28, 18, -55 } }) do
		block(under, V(size.X * l[1], l[2], size.Y * l[1]), CF(c.X + rng:NextNumber(-6, 6), GY + l[3], c.Z + rng:NextNumber(-6, 6)) * ANG(0, rad(rng:NextNumber(-8, 8)), 0), (i % 2 == 0) and C.Rock or C.Rock2)
	end
	for x = -size.X / 2, size.X / 2, 18 do
		for _, zs in ipairs({ -1, 1 }) do
			local s = rng:NextNumber(10, 18)
			block(under, V(s, rng:NextNumber(5, 8), s), CF(c.X + x, GY - 3.5, c.Z + zs * size.Y / 2) * ANG(0, rng:NextNumber(0, 2), 0), C.Rock2)
		end
	end
	for z = -size.Y / 2 + 18, size.Y / 2 - 18, 18 do
		for _, xs in ipairs({ -1, 1 }) do
			local s = rng:NextNumber(10, 18)
			block(under, V(s, rng:NextNumber(5, 8), s), CF(c.X + xs * size.X / 2, GY - 3.5, c.Z + z) * ANG(0, rng:NextNumber(0, 2), 0), C.Rock)
		end
	end

	-- ДОРОГА: тёмная брусчатка, оранжевые трещины, фонари по краям
	local road = Instance.new("Folder")
	road.Name = "Path"
	road.Parent = m
	local pts = PathUtil.Points
	local w = MC.PathWidth
	for i = 2, #pts do
		local a, b = pts[i - 1], pts[i]
		local len = (b - a).Magnitude
		local mid = (a + b) / 2
		local cf = CFrame.lookAt(V(mid.X, GY + 0.15, mid.Z), V(b.X, GY + 0.15, b.Z))
		block(road, V(w, 0.3, len + w), cf, C.Road, Enum.Material.Cobblestone).Name = "Road"
		block(road, V(w + 1.6, 0.22, len + w + 1.6), cf * CF(0, -0.06, 0), C.RoadEdge).Name = "RoadEdge"
		if i % 2 == 0 then
			neon(road, V(0.35, 0.05, math.min(len * 0.4, 12)), cf * CF(rng:NextNumber(-2, 2), 0.16, 0) * ANG(0, rad(rng:NextNumber(-25, 25)), 0), C.Ember)
		end
		local steps = math.floor(len / 26)
		local dir = (b - a).Unit
		local right = V(-dir.Z, 0, dir.X)
		for s2 = 1, steps do
			local p = a:Lerp(b, s2 / (steps + 1)) + right * ((s2 % 2 == 0) and 1 or -1) * (w / 2 + 2)
			lanternPost(road, V(p.X, GY, p.Z), 6)
		end
	end

	-- ПОРТАЛ ВРАГОВ (VoidPortal: PortalDisc/PortalCore нужны для вспышки при боссе)
	do
		local pm = Instance.new("Model")
		pm.Name = "VoidPortal"
		pm.Parent = m
		local start = pts[1]
		local dir = (pts[2] - start).Unit
		local R = 10
		local center = start - dir * 4 + V(0, R + 1, 0)
		local face = CFrame.lookAt(center, center + dir)
		for i = 0, 17 do
			local a = i / 18 * math.pi * 2
			local cf = face * CF(math.cos(a) * R, math.sin(a) * R, 0) * ANG(0, 0, a)
			block(pm, V(3.4, 3, 2.6), cf, (i % 2 == 0) and C.Stone2 or C.Black)
			if i % 3 == 0 then
				wedge(pm, V(1, 2.2, 1), cf * CF(1.6, 0, 0) * ANG(0, 0, rad(-90)), C.Bone, Enum.Material.SmoothPlastic)
			end
		end
		local disc = H.part(pm, { Name = "PortalDisc", Shape = Enum.PartType.Cylinder, Size = V(0.4, R * 2 - 2.4, R * 2 - 2.4), CFrame = face * ANG(0, rad(90), 0), Color = rgb(140, 50, 20), Material = Enum.Material.Neon, Transparency = 0.2, CanCollide = false })
		local core = neon(pm, V(2, 2, 2), face * CF(0, 0, -0.3) * ANG(rad(45), rad(45), 0), C.Orange)
		core.Name = "PortalCore"
		H.light(core, C.Orange, 40, 3)
		H.emitter(disc, C.Ember, { Rate = 26, Size = 0.7, SpeedMin = 2, SpeedMax = 5 })
		for i = 0, 2 do
			local sw = neon(pm, V(0.6, R * 1.6, 0.7), face * ANG(0, 0, rad(i * 60)) * CF(0, 0, -0.4), (i == 1) and C.Purple or C.Orange, { Transparency = 0.35 })
			sw:SetAttribute("Spin", -1.4 - i * 0.3)
			sw:SetAttribute("SpinAxis", "Z")
		end
		fogEmitter(disc, C.Fog, 3, 6)
	end

	-- БАЗА ИГРОКА (VoidCore): святилище-фонарь
	do
		local cm = Instance.new("Model")
		cm.Name = "VoidCore"
		cm.Parent = m
		local pos = pts[#pts]
		H.cylinderY(cm, "CoreBase", 9, 1.5, pos + V(0, 0.75, 0), C.Stone2)
		H.cylinderY(cm, "CoreRing", 9.4, 0.4, pos + V(0, 1.6, 0), C.Gold, Enum.Material.Neon, { CanCollide = false })
		for k = 0, 3 do
			local a = k / 4 * math.pi * 2 + rad(45)
			local pp = pos + V(math.cos(a) * 6.5, 0, math.sin(a) * 6.5)
			block(cm, V(1.6, 14, 1.6), CF(pp + V(0, 7, 0)), C.Black, Enum.Material.Metal)
			pumpkin(cm, pp + V(0, 14, 0), 1.3, true, a)
		end
		block(cm, V(10, 1, 10), CF(pos + V(0, 14.5, 0)) * ANG(0, rad(45), 0), C.Black, Enum.Material.Metal)
		spire(cm, CF(pos + V(0, 15, 0)), 9, 9, C.Burgundy)
		local flame = neon(cm, V(4, 6, 4), CF(pos + V(0, 8, 0)) * ANG(0, rad(45), 0), C.Orange, { Transparency = 0.15 })
		flame.Name = "CoreCrystal"
		flame:SetAttribute("Spin", 0.6)
		flame:SetAttribute("SpinAxis", "Y")
		H.light(flame, C.Orange, 40, 3)
		H.emitter(flame, C.Ember, { Rate = 20, Size = 0.6, SpeedMin = 1, SpeedMax = 3, Accel = V(0, 3, 0) })
		cm:SetAttribute("CoreCenter", pos + V(0, 8, 0))
	end

	-- ДЕКОР: кладбище, тыквенные поля, готические здания, лес — только вдали от дороги
	local taken = { pts[1], pts[#pts], MC.BattleSpawn }
	local function free(p, pathDist, sep)
		if PathUtil.DistanceToPath(p) < pathDist then
			return false
		end
		if math.abs(p.X - c.X) > size.X / 2 - 6 or math.abs(p.Z - c.Z) > size.Y / 2 - 6 then
			return false
		end
		for _, t in ipairs(taken) do
			if V(p.X - t.X, 0, p.Z - t.Z).Magnitude < sep then
				return false
			end
		end
		return true
	end
	local function spot(pathDist, sep, tries)
		for _ = 1, tries or 40 do
			local p = V(c.X + rng:NextNumber(-size.X / 2, size.X / 2), GY, c.Z + rng:NextNumber(-size.Y / 2, size.Y / 2))
			if free(p, pathDist, sep) then
				taken[#taken + 1] = p
				return p
			end
		end
	end
	local decor = Instance.new("Folder")
	decor.Name = "Decor"
	decor.Parent = m
	-- кладбище
	for _ = 1, 3 do
		local g = spot(16, 26)
		if g then
			for k = 1, 6 do
				tombstone(decor, rng, g + V(rng:NextNumber(-7, 7), 0, rng:NextNumber(-7, 7)), rng:NextNumber(-0.4, 0.4))
			end
			if rng:NextInteger(1, 2) == 1 then
				crow(decor, g + V(0, 2.9, 0), rng:NextNumber(0, 6))
			end
			fogEmitter(block(decor, V(16, 1, 16), CF(g + V(0, 0.5, 0)), C.Ground, Enum.Material.Slate, { Transparency = 1, CanCollide = false }), rgb(120, 200, 130), 1, 5)
		end
	end
	-- поля тыкв
	for _ = 1, 4 do
		local f = spot(12, 20)
		if f then
			for k = 1, 7 do
				pumpkin(decor, f + V(rng:NextNumber(-6, 6), 0, rng:NextNumber(-6, 6)), rng:NextNumber(0.8, 1.6), rng:NextInteger(1, 3) == 1, rng:NextNumber(0, 6))
			end
		end
	end
	-- готические здания
	for k = 1, 3 do
		local p = spot(22, 34)
		if p then
			if k == 1 then
				tower(decor, p, 10, 26, false, rng)
			elseif k == 2 then
				house(decor, p, rng:NextNumber(0, 6), 1.1)
			else
				tower(decor, p, 8, 16, true, rng)
			end
		end
	end
	-- лес мёртвых деревьев
	for _ = 1, 30 do
		local p = spot(9, 9, 12)
		if p then
			deadTree(decor, rng, p, rng:NextNumber(0.8, 1.3))
		end
	end
	-- призраки, мыши, туман, руны
	for _ = 1, 4 do
		local p = spot(10, 12, 12)
		if p then
			ghost(decor, p + V(0, 3, 0), rng:NextNumber(0.8, 1.2))
		end
	end
	for _ = 1, 6 do
		bat(decor, V(c.X + rng:NextNumber(-110, 110), GY + rng:NextNumber(24, 40), c.Z + rng:NextNumber(-90, 90)), rng:NextNumber(8, 16), rng:NextNumber(0.5, 1.2))
	end
	for i = 0, 5 do
		fogEmitter(block(decor, V(40, 1, 40), CF(c.X + (i % 3 - 1) * 85, GY + 0.5, c.Z + (i < 3 and -50 or 50)), C.Ground, Enum.Material.Slate, { Transparency = 1, CanCollide = false }), C.Fog, 1.2, 9)
	end
	local moon = neon(decor, V(60, 60, 60), CF(c + V(60, 140, -300)), C.Moon, { Shape = Enum.PartType.Ball })
	H.light(moon, C.Moon, 60, 1)

	-- площадка прибытия
	local bs = MC.BattleSpawn
	block(m, V(8, 1, 8), CF(bs.X, GY + 0.5, bs.Z), rgb(60, 26, 20)).Name = "BattlePad"
	neon(m, V(7, 0.05, 7), CF(bs.X, GY + 1.03, bs.Z), C.Orange, { Transparency = 0.6 }).Name = "BattlePadGlow"

	PathUtil.SetMap("Void")
	H.calm(m)
	m.Parent = workspace
	return m
end

function HalloweenWorld.Build(helpers)
	H = helpers
	buildLobbyPortal()
	buildIsland()
	return buildMap()
end

return HalloweenWorld
