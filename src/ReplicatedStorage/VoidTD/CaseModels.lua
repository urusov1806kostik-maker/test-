--!nocheck
-- VOID TD :: CaseModels
-- 3D-модели кейсов (витрины в лобби и анимация открытия). Все детали заякорены.
-- CaseModels.Build(caseId) -> { Model, Body, Lid, Core, Shards = {...}, Cracks = {...} }
-- Halloween дополнительно: Chains, Eyes, Fire (ParticleEmitter), LidParts, Hinge (CFrame петли крышки)

local CaseModels = {}

local V = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles
local rad = math.rad

local function part(parent, size, cf, color, material, props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if props then
		for k, v in pairs(props) do
			p[k] = v
		end
	end
	p.Parent = parent
	return p
end

local function neon(parent, size, cf, color, props)
	local p = part(parent, size, cf, color, Enum.Material.Neon, props)
	p.CastShadow = false
	return p
end

------------------------------------------------------------------------
-- VOID CASE: тёмный сундук с фиолетовым светящимся замком и сферой Пустоты
------------------------------------------------------------------------
local function VoidCase(m)
	local r = { Shards = {}, Cracks = {} }
	local dark, violet, glow = Color3.fromRGB(28, 22, 38), Color3.fromRGB(70, 30, 110), Color3.fromRGB(180, 80, 255)
	r.Body = part(m, V(4, 2.4, 3), CF(0, 1.2, 0), dark, Enum.Material.Metal)
	part(m, V(4.15, 0.35, 3.15), CF(0, 0.2, 0), violet, Enum.Material.Metal)
	r.Lid = part(m, V(4.1, 1.0, 3.1), CF(0, 2.9, 0), violet, Enum.Material.Metal)
	part(m, V(4.2, 0.2, 3.2), CF(0, 2.45, 0), Color3.fromRGB(200, 160, 60), Enum.Material.Metal)
	for _, x in ipairs({ -1.6, 1.6 }) do
		part(m, V(0.35, 3.4, 3.2), CF(x, 1.7, 0), Color3.fromRGB(200, 160, 60), Enum.Material.Metal)
	end
	r.Core = neon(m, V(0.9, 0.9, 0.3), CF(0, 1.9, -1.6) * ANG(0, 0, rad(45)), glow)
	local orb = neon(m, V(1.4, 1.4, 1.4), CF(0, 4.6, 0), glow, { Shape = Enum.PartType.Ball, Transparency = 0.2 })
	table.insert(r.Shards, orb)
	for i = 0, 3 do
		local a = i / 4 * math.pi * 2
		local s = neon(m, V(0.4, 0.8, 0.4), CF(math.cos(a) * 2.6, 3.6, math.sin(a) * 2.6) * ANG(rad(30), a, 0), glow)
		table.insert(r.Shards, s)
	end
	return r
end

------------------------------------------------------------------------
-- SHATTERED REALITY: кубический сундук с трещинами, кристаллом и осколками
------------------------------------------------------------------------
local function ShatteredReality(m)
	local r = { Shards = {}, Cracks = {} }
	local dark, purple, glow = Color3.fromRGB(26, 14, 44), Color3.fromRGB(60, 20, 110), Color3.fromRGB(170, 70, 255)
	r.Body = part(m, V(3.6, 3.6, 3.6), CF(0, 1.8, 0), dark, Enum.Material.Slate)
	r.Lid = part(m, V(3.8, 0.5, 3.8), CF(0, 3.75, 0), purple, Enum.Material.Slate)
	part(m, V(3.8, 0.4, 3.8), CF(0, 0.2, 0), purple, Enum.Material.Slate)
	-- угловые рёбра
	for _, x in ipairs({ -1.75, 1.75 }) do
		for _, z in ipairs({ -1.75, 1.75 }) do
			part(m, V(0.35, 3.8, 0.35), CF(x, 1.9, z), purple, Enum.Material.Metal)
		end
	end
	-- фиолетовые трещины на гранях
	local cracks = {
		{ V(-1.0, 2.6, -1.82), V(0.1, 1.6, -1.82) }, { V(0.1, 1.6, -1.82), V(-0.3, 0.6, -1.82) },
		{ V(0.1, 1.6, -1.82), V(1.1, 1.1, -1.82) }, { V(1.82, 2.8, -0.8), V(1.82, 1.4, 0.4) },
		{ V(1.82, 1.4, 0.4), V(1.82, 0.5, 1.1) }, { V(-1.82, 2.2, 0.9), V(-1.82, 0.9, -0.4) },
	}
	for _, c in ipairs(cracks) do
		local a, b = c[1], c[2]
		local len = (b - a).Magnitude
		local up = math.abs((b - a).Unit.Y) > 0.98 and V(0, 0, 1) or V(0, 1, 0)
		local cr = neon(m, V(0.14, 0.14, len), CFrame.lookAt((a + b) / 2, b, up), glow)
		table.insert(r.Cracks, cr)
	end
	r.Core = neon(m, V(1.2, 1.9, 1.2), CF(0, 5.0, 0) * ANG(0, rad(45), 0), glow)
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2
		local s = neon(m, V(0.35, 0.7, 0.2), CF(math.cos(a) * 2.8, 4.2 + (i % 2) * 0.8, math.sin(a) * 2.8) * ANG(rad(25), a, rad(20)), i % 2 == 0 and glow or Color3.fromRGB(220, 170, 255))
		table.insert(r.Shards, s)
	end
	return r
end

------------------------------------------------------------------------
-- BLOOD MOON: чёрный алтарь-сундук с кровавой луной над ним
------------------------------------------------------------------------
local function BloodMoon(m)
	local r = { Shards = {}, Cracks = {} }
	local black, crimson, glow = Color3.fromRGB(20, 8, 12), Color3.fromRGB(110, 15, 28), Color3.fromRGB(255, 40, 60)
	r.Body = part(m, V(3.8, 2.6, 3.2), CF(0, 1.3, 0), black, Enum.Material.Slate)
	r.Lid = part(m, V(4.0, 0.8, 3.4), CF(0, 3.0, 0), crimson, Enum.Material.Metal)
	part(m, V(4.2, 0.3, 3.6), CF(0, 0.15, 0), crimson, Enum.Material.Metal)
	-- клыки по краям крышки
	for i = -1, 1 do
		local w = Instance.new("WedgePart")
		w.Anchored = true
		w.CanCollide = false
		w.CanQuery = false
		w.Size = V(0.3, 0.7, 0.4)
		w.CFrame = CF(i * 1.2, 2.35, -1.75) * ANG(0, 0, math.pi)
		w.Color = Color3.fromRGB(235, 225, 215)
		w.Parent = m
	end
	r.Core = neon(m, V(0.8, 0.8, 0.3), CF(0, 1.5, -1.65) * ANG(0, 0, rad(45)), glow)
	local moon = neon(m, V(2.4, 2.4, 2.4), CF(0, 5.6, 0), glow, { Shape = Enum.PartType.Ball })
	part(m, V(2.45, 2.45, 2.45), CF(0.55, 5.8, -0.2), black, Enum.Material.SmoothPlastic, { Shape = Enum.PartType.Ball, Transparency = 0.15 })
	table.insert(r.Shards, moon)
	for i = 0, 4 do
		local a = i / 5 * math.pi * 2
		table.insert(r.Shards, neon(m, V(0.3, 0.3, 0.3), CF(math.cos(a) * 2.4, 4.0, math.sin(a) * 2.4), glow, { Shape = Enum.PartType.Ball }))
	end
	return r
end

------------------------------------------------------------------------
-- HALLOWEEN: чёрно-золотой проклятый сундук — светящиеся глаза, цепи с замком, оранжевый огонь.
-- Крышка — отдельный набор деталей (LidParts) с петлёй Hinge на заднем верхнем ребре корпуса.
------------------------------------------------------------------------
local function wedge(parent, size, cf, color, material)
	local w = Instance.new("WedgePart")
	w.Anchored = true
	w.CanCollide = false
	w.CanTouch = false
	w.CanQuery = false
	w.Size = size
	w.CFrame = cf
	w.Color = color
	w.Material = material or Enum.Material.SmoothPlastic
	w.Parent = parent
	return w
end

-- цепь из звеньев между точками a и b
local function chainLinks(parent, list, a, b, color)
	local d = b - a
	local n = math.max(2, math.floor(d.Magnitude / 0.36))
	local up = math.abs(d.Unit.Y) > 0.98 and V(0, 0, 1) or V(0, 1, 0)
	for i = 0, n - 1 do
		local p = a + d * ((i + 0.5) / n)
		local cf = CFrame.lookAt(p, p + d, up) * ANG(0, 0, (i % 2 == 0) and 0 or math.pi / 2)
		list[#list + 1] = part(parent, V(0.3, 0.1, 0.44), cf, color, Enum.Material.Metal)
	end
end

local function fireEmitter(parent, list, cf, size, rate)
	local p = part(parent, V(size, 0.2, size), cf, Color3.new(), Enum.Material.SmoothPlastic, { Transparency = 1 })
	local e = Instance.new("ParticleEmitter")
	e.Name = "CursedFire"
	e.Color = ColorSequence.new(Color3.fromRGB(255, 200, 90), Color3.fromRGB(255, 70, 20))
	e.LightEmission = 1
	e.LightInfluence = 0
	e.Rate = rate or 14
	e.Lifetime = NumberRange.new(0.5, 0.9)
	e.Speed = NumberRange.new(1.5, 3)
	e.EmissionDirection = Enum.NormalId.Top
	e.SpreadAngle = Vector2.new(12, 12)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 1) })
	e.Parent = p
	list[#list + 1] = e
	return p
end

local function Halloween(m)
	local r = { Shards = {}, Cracks = {}, Chains = {}, Eyes = {}, Fire = {}, LidParts = {} }
	local black, coal = Color3.fromRGB(20, 14, 22), Color3.fromRGB(38, 26, 40)
	local gold, goldDark = Color3.fromRGB(214, 168, 70), Color3.fromRGB(140, 100, 40)
	local orange, ember = Color3.fromRGB(255, 130, 30), Color3.fromRGB(255, 190, 80)
	local iron = Color3.fromRGB(70, 64, 76)
	local W, Hh, D = 4.0, 2.4, 2.8
	-- корпус
	r.Body = part(m, V(W, Hh, D), CF(0, 0.3 + Hh / 2, 0), black, Enum.Material.Slate)
	part(m, V(W + 0.3, 0.35, D + 0.3), CF(0, 0.18, 0), gold, Enum.Material.Metal)
	part(m, V(W - 0.4, 0.12, D - 0.4), CF(0, 0.02, 0), goldDark, Enum.Material.Metal)
	-- ножки-когти
	for _, x in ipairs({ -1, 1 }) do
		for _, z in ipairs({ -1, 1 }) do
			wedge(m, V(0.5, 0.45, 0.5), CF(x * (W / 2 - 0.1), 0.0, z * (D / 2 - 0.1)) * ANG(0, (z < 0) and 0 or math.pi, 0) * ANG(math.pi, 0, 0), gold, Enum.Material.Metal)
		end
	end
	-- золотые рёбра и тёмные доски
	for _, x in ipairs({ -1, 1 }) do
		for _, z in ipairs({ -1, 1 }) do
			part(m, V(0.3, Hh + 0.05, 0.3), CF(x * (W / 2 - 0.08), 0.3 + Hh / 2, z * (D / 2 - 0.08)), gold, Enum.Material.Metal)
		end
	end
	for _, y in ipairs({ 0.95, 1.75 }) do
		part(m, V(W - 0.4, 0.06, 0.06), CF(0, y, -D / 2 - 0.01), coal, Enum.Material.Wood)
	end
	part(m, V(W + 0.06, 0.2, D + 0.06), CF(0, 0.3 + Hh - 0.1, 0), gold, Enum.Material.Metal)
	-- светящиеся глаза со злыми бровями
	for _, s in ipairs({ -1, 1 }) do
		local eye = neon(m, V(0.62, 0.3, 0.12), CF(0.85 * s, 1.95, -D / 2 - 0.04) * ANG(0, 0, math.rad(-14 * s)), orange)
		table.insert(r.Eyes, eye)
		table.insert(r.Eyes, neon(m, V(0.16, 0.16, 0.14), CF(0.85 * s, 1.93, -D / 2 - 0.06) * ANG(0, 0, math.rad(45)), ember))
		part(m, V(0.8, 0.14, 0.12), CF(0.8 * s, 2.22, -D / 2 - 0.05) * ANG(0, 0, math.rad(22 * s)), gold, Enum.Material.Metal)
	end
	-- клыкастая пасть под глазами
	part(m, V(2.2, 0.32, 0.08), CF(0, 1.52, -D / 2 - 0.02), Color3.fromRGB(60, 16, 10))
	for k = -3, 3 do
		wedge(m, V(0.08, 0.22, 0.2), CF(k * 0.3, 1.57, -D / 2 - 0.08) * ANG(0, math.pi / 2, 0) * ANG(math.pi, 0, 0), Color3.fromRGB(230, 220, 200))
	end
	-- цепи крест-накрест по фасаду и замок
	local fz = -D / 2 - 0.12
	chainLinks(m, r.Chains, V(-W / 2 + 0.2, 0.5, fz), V(-0.3, 1.0, fz), iron)
	chainLinks(m, r.Chains, V(W / 2 - 0.2, 0.5, fz), V(0.3, 1.0, fz), iron)
	chainLinks(m, r.Chains, V(0, 1.35, fz - 0.05), V(0, 2.65, fz - 0.05), iron)
	-- цепи по бокам
	for _, x in ipairs({ -1, 1 }) do
		chainLinks(m, r.Chains, V(x * (W / 2 + 0.1), 2.6, -D / 2 + 0.2), V(x * (W / 2 + 0.1), 0.45, D / 2 - 0.2), iron)
	end
	local lock = part(m, V(0.8, 0.75, 0.3), CF(0, 0.95, fz - 0.15), gold, Enum.Material.Metal)
	table.insert(r.Chains, lock)
	for _, s in ipairs({ -1, 1 }) do
		table.insert(r.Chains, part(m, V(0.12, 0.4, 0.12), CF(0.25 * s, 1.45, fz - 0.15), goldDark, Enum.Material.Metal))
	end
	table.insert(r.Chains, part(m, V(0.62, 0.12, 0.12), CF(0, 1.62, fz - 0.15), goldDark, Enum.Material.Metal))
	r.Core = neon(m, V(0.2, 0.32, 0.08), CF(0, 0.9, fz - 0.32), orange)
	table.insert(r.Chains, r.Core)
	-- крышка (на петле сзади)
	local lidY = 0.3 + Hh
	local function lid(p)
		table.insert(r.LidParts, p)
		return p
	end
	r.Lid = lid(part(m, V(W + 0.1, 0.55, D + 0.1), CF(0, lidY + 0.28, 0), black, Enum.Material.Slate))
	lid(part(m, V(W - 0.3, 0.42, D - 0.5), CF(0, lidY + 0.76, 0), coal, Enum.Material.Slate))
	lid(wedge(m, V(W - 0.3, 0.42, 0.25), CF(0, lidY + 0.76, -D / 2 + 0.12), coal, Enum.Material.Slate))
	lid(wedge(m, V(W - 0.3, 0.42, 0.25), CF(0, lidY + 0.76, D / 2 - 0.12) * ANG(0, math.pi, 0), coal, Enum.Material.Slate))
	lid(part(m, V(W + 0.2, 0.16, D + 0.2), CF(0, lidY + 0.06, 0), gold, Enum.Material.Metal))
	lid(part(m, V(W - 0.2, 0.12, 0.3), CF(0, lidY + 0.98, 0), gold, Enum.Material.Metal))
	for _, x in ipairs({ -1, 1 }) do
		lid(part(m, V(0.3, 0.62, D + 0.16), CF(x * (W / 2 - 0.1), lidY + 0.3, 0), gold, Enum.Material.Metal))
		-- рога по углам крышки
		local base = V(x * (W / 2 - 0.35), lidY + 1.0, -D / 2 + 0.4)
		lid(wedge(m, V(0.3, 0.7, 0.4), CFrame.new(base + V(x * 0.15, 0.3, 0)) * ANG(0, 0, math.rad(-25 * x)) * ANG(0, math.pi, 0), gold, Enum.Material.Metal))
	end
	-- оранжевый камень-око на крышке
	lid(neon(m, V(0.42, 0.42, 0.14), CF(0, lidY + 0.3, -D / 2 - 0.1) * ANG(0, 0, math.rad(45)), orange))
	-- петли
	for _, x in ipairs({ -1.2, 1.2 }) do
		part(m, V(0.5, 0.3, 0.2), CF(x, lidY, D / 2 + 0.08), gold, Enum.Material.Metal)
	end
	r.Hinge = CF(0, lidY, D / 2)
	-- огонь по углам и угли вокруг
	for _, x in ipairs({ -1, 1 }) do
		fireEmitter(m, r.Fire, CF(x * (W / 2 + 0.2), 0.45, -D / 2 - 0.2), 0.5, 12)
		fireEmitter(m, r.Fire, CF(x * (W / 2 - 0.35), lidY + 1.35, -D / 2 + 0.4), 0.3, 8)
	end
	for i = 0, 3 do
		local a = i / 4 * math.pi * 2 + 0.4
		table.insert(r.Shards, neon(m, V(0.25, 0.25, 0.25), CF(math.cos(a) * 2.8, 3.4 + (i % 2) * 0.6, math.sin(a) * 2.6) * ANG(math.rad(45), a, math.rad(45)), ember))
	end
	return r
end

local Builders = { VoidCase = VoidCase, ShatteredReality = ShatteredReality, BloodMoon = BloodMoon, Halloween = Halloween }

function CaseModels.Build(caseId)
	local m = Instance.new("Model")
	m.Name = "Case_" .. tostring(caseId)
	local builder = Builders[caseId] or VoidCase
	local r = builder(m)
	m.PrimaryPart = r.Body
	m.WorldPivot = CF(0, 0, 0)
	r.Model = m
	-- приглушённый неон
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") and d.Material == Enum.Material.Neon then
			d.Color = d.Color:Lerp(Color3.fromRGB(14, 10, 22), 0.3)
		end
	end
	-- запоминаем исходные позиции для анимации
	r.Base = {}
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			r.Base[d] = d.CFrame
		end
	end
	return r
end

return CaseModels
