--!nocheck
-- VOID TD :: Models/Cases (CaseModels)
-- 3D-модели кейсов: витрины в лобби/на острове и анимация открытия. Все детали заякорены, без коллизий.
-- Модель стоит на y≈0 в начале координат, лицевая сторона смотрит в -Z.
--
-- CaseModels.Build(caseId) -> r
--   r.Model (Model "Case_<id>", PrimaryPart = Body, WorldPivot = CFrame.new()), r.Body, r.Lid, r.Core,
--   r.Shards {parts} (парящие кристаллы/сферы), r.Cracks {parts}, r.Base {[BasePart] = исходный CFrame}
--   Halloween дополнительно: r.Chains {parts} (цепи, замок и скважина — разлетаются при открытии),
--   r.Eyes {parts}, r.Fire {ParticleEmitter "CursedFire"}, r.LidParts {parts}, r.Hinge (CFrame петли крышки)
--   Кейсы: VoidCase ShatteredReality BloodMoon Halloween; неизвестный id -> VoidCase (с предупреждением).
-- Неон приглушается (lerp 0.3 к тёмному) один раз; модель помечается атрибутом "Calmed", чтобы общий
-- проход Kit.Calm мира не приглушил её второй раз. r.Base снимается после приглушения.

local CaseModels = {}

local V = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles
local rad = math.rad
local PI = math.pi

local MAT = Enum.Material
local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local CALM_DARK = rgb(14, 10, 22)
local CALM_AMOUNT = 0.3

------------------------------------------------------------------------
-- ДЕТАЛИ
------------------------------------------------------------------------
local function setup(p, size, cf, color, material, props)
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or MAT.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if props then
		for k, v in pairs(props) do
			p[k] = v
		end
	end
	return p
end

local function part(parent, size, cf, color, material, props)
	local p = setup(Instance.new("Part"), size, cf, color, material, props)
	p.Parent = parent
	return p
end

local function wedge(parent, size, cf, color, material)
	local w = setup(Instance.new("WedgePart"), size, cf, color, material)
	w.Parent = parent
	return w
end

local function neon(parent, size, cf, color, props)
	local p = part(parent, size, cf, color, MAT.Neon, props)
	p.CastShadow = false
	return p
end

local BALL = { Shape = Enum.PartType.Ball }

local function newCase()
	return { Shards = {}, Cracks = {} }
end

------------------------------------------------------------------------
-- VOID CASE: тёмный сундук с фиолетовым светящимся замком и сферой Пустоты
------------------------------------------------------------------------
local function VoidCase(m)
	local r = newCase()
	local dark, violet, glow, gold = rgb(28, 22, 38), rgb(70, 30, 110), rgb(180, 80, 255), rgb(200, 160, 60)
	r.Body = part(m, V(4, 2.4, 3), CF(0, 1.2, 0), dark, MAT.Metal)
	part(m, V(4.15, 0.35, 3.15), CF(0, 0.2, 0), violet, MAT.Metal)
	r.Lid = part(m, V(4.1, 1.0, 3.1), CF(0, 2.9, 0), violet, MAT.Metal)
	part(m, V(4.2, 0.2, 3.2), CF(0, 2.45, 0), gold, MAT.Metal)
	for _, x in ipairs({ -1.6, 1.6 }) do
		part(m, V(0.35, 3.4, 3.2), CF(x, 1.7, 0), gold, MAT.Metal) -- ремни
	end
	r.Core = neon(m, V(0.9, 0.9, 0.3), CF(0, 1.9, -1.6) * ANG(0, 0, rad(45)), glow) -- замок-ромб
	r.Shards[1] = neon(m, V(1.4, 1.4, 1.4), CF(0, 4.6, 0), glow, { Shape = Enum.PartType.Ball, Transparency = 0.2 }) -- сфера
	for i = 0, 3 do
		local a = i / 4 * PI * 2
		r.Shards[#r.Shards + 1] = neon(m, V(0.4, 0.8, 0.4), CF(math.cos(a) * 2.6, 3.6, math.sin(a) * 2.6) * ANG(rad(30), a, 0), glow)
	end
	return r
end

------------------------------------------------------------------------
-- SHATTERED REALITY: кубический сундук с трещинами, парящим кристаллом и осколками
------------------------------------------------------------------------
local SHATTER_CRACKS = {
	{ V(-1.0, 2.6, -1.82), V(0.1, 1.6, -1.82) }, { V(0.1, 1.6, -1.82), V(-0.3, 0.6, -1.82) },
	{ V(0.1, 1.6, -1.82), V(1.1, 1.1, -1.82) }, { V(1.82, 2.8, -0.8), V(1.82, 1.4, 0.4) },
	{ V(1.82, 1.4, 0.4), V(1.82, 0.5, 1.1) }, { V(-1.82, 2.2, 0.9), V(-1.82, 0.9, -0.4) },
}

local function ShatteredReality(m)
	local r = newCase()
	local dark, purple, glow, alt = rgb(26, 14, 44), rgb(60, 20, 110), rgb(170, 70, 255), rgb(220, 170, 255)
	r.Body = part(m, V(3.6, 3.6, 3.6), CF(0, 1.8, 0), dark, MAT.Slate)
	r.Lid = part(m, V(3.8, 0.5, 3.8), CF(0, 3.75, 0), purple, MAT.Slate)
	part(m, V(3.8, 0.4, 3.8), CF(0, 0.2, 0), purple, MAT.Slate)
	for _, x in ipairs({ -1.75, 1.75 }) do -- угловые рёбра
		for _, z in ipairs({ -1.75, 1.75 }) do
			part(m, V(0.35, 3.8, 0.35), CF(x, 1.9, z), purple, MAT.Metal)
		end
	end
	for _, c in ipairs(SHATTER_CRACKS) do -- фиолетовые трещины на гранях
		local a, b = c[1], c[2]
		local d = b - a
		local up = math.abs(d.Unit.Y) > 0.98 and V(0, 0, 1) or V(0, 1, 0)
		r.Cracks[#r.Cracks + 1] = neon(m, V(0.14, 0.14, d.Magnitude), CFrame.lookAt((a + b) / 2, b, up), glow)
	end
	r.Core = neon(m, V(1.2, 1.9, 1.2), CF(0, 5.0, 0) * ANG(0, rad(45), 0), glow)
	for i = 0, 5 do
		local a = i / 6 * PI * 2
		r.Shards[#r.Shards + 1] = neon(m, V(0.35, 0.7, 0.2), CF(math.cos(a) * 2.8, 4.2 + (i % 2) * 0.8, math.sin(a) * 2.8) * ANG(rad(25), a, rad(20)), i % 2 == 0 and glow or alt)
	end
	return r
end

------------------------------------------------------------------------
-- BLOOD MOON: чёрный алтарь-сундук с клыками и кровавой луной в затмении над ним
------------------------------------------------------------------------
local function BloodMoon(m)
	local r = newCase()
	local black, crimson, glow, fang = rgb(20, 8, 12), rgb(110, 15, 28), rgb(255, 40, 60), rgb(235, 225, 215)
	r.Body = part(m, V(3.8, 2.6, 3.2), CF(0, 1.3, 0), black, MAT.Slate)
	r.Lid = part(m, V(4.0, 0.8, 3.4), CF(0, 3.0, 0), crimson, MAT.Metal)
	part(m, V(4.2, 0.3, 3.6), CF(0, 0.15, 0), crimson, MAT.Metal)
	for i = -1, 1 do -- клыки под крышкой
		wedge(m, V(0.3, 0.7, 0.4), CF(i * 1.2, 2.35, -1.75) * ANG(0, 0, PI), fang)
	end
	r.Core = neon(m, V(0.8, 0.8, 0.3), CF(0, 1.5, -1.65) * ANG(0, 0, rad(45)), glow)
	r.Shards[1] = neon(m, V(2.4, 2.4, 2.4), CF(0, 5.6, 0), glow, BALL) -- луна
	part(m, V(2.45, 2.45, 2.45), CF(0.55, 5.8, -0.2), black, MAT.SmoothPlastic, { Shape = Enum.PartType.Ball, Transparency = 0.15 }) -- тень затмения
	for i = 0, 4 do
		local a = i / 5 * PI * 2
		r.Shards[#r.Shards + 1] = neon(m, V(0.3, 0.3, 0.3), CF(math.cos(a) * 2.4, 4.0, math.sin(a) * 2.4), glow, BALL)
	end
	return r
end

------------------------------------------------------------------------
-- HALLOWEEN: чёрно-золотой проклятый сундук — светящиеся глаза, клыкастая пасть, цепи с замком,
-- оранжевый огонь. Крышка — отдельный набор деталей (LidParts) на петле Hinge (заднее верхнее ребро).
------------------------------------------------------------------------
local HW = { W = 4.0, H = 2.4, D = 2.8 }

-- цепь из звеньев между точками a и b (чередуются повороты на 90°)
local function chainLinks(parent, list, a, b, color)
	local d = b - a
	local n = math.max(2, math.floor(d.Magnitude / 0.36))
	local up = math.abs(d.Unit.Y) > 0.98 and V(0, 0, 1) or V(0, 1, 0)
	for i = 0, n - 1 do
		local p = a + d * ((i + 0.5) / n)
		local cf = CFrame.lookAt(p, p + d, up) * ANG(0, 0, (i % 2 == 0) and 0 or PI / 2)
		list[#list + 1] = part(parent, V(0.3, 0.1, 0.44), cf, color, MAT.Metal)
	end
end

-- проклятый огонь: невидимый носитель + эмиттер "CursedFire" вверх
local function fireEmitter(parent, list, cf, size, rate)
	local p = part(parent, V(size, 0.2, size), cf, Color3.new(), MAT.SmoothPlastic, { Transparency = 1 })
	local e = Instance.new("ParticleEmitter")
	e.Name = "CursedFire"
	e.Color = ColorSequence.new(rgb(255, 200, 90), rgb(255, 70, 20))
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

-- крышка: плита, скос, золотые обода, рога, камень-око (все детали — в r.LidParts)
local function halloweenLid(m, r, c)
	local W, D = HW.W, HW.D
	local lidY = 0.3 + HW.H
	local function lid(p)
		r.LidParts[#r.LidParts + 1] = p
		return p
	end
	r.Lid = lid(part(m, V(W + 0.1, 0.55, D + 0.1), CF(0, lidY + 0.28, 0), c.black, MAT.Slate))
	lid(part(m, V(W - 0.3, 0.42, D - 0.5), CF(0, lidY + 0.76, 0), c.coal, MAT.Slate))
	lid(wedge(m, V(W - 0.3, 0.42, 0.25), CF(0, lidY + 0.76, -D / 2 + 0.12), c.coal, MAT.Slate))
	lid(wedge(m, V(W - 0.3, 0.42, 0.25), CF(0, lidY + 0.76, D / 2 - 0.12) * ANG(0, PI, 0), c.coal, MAT.Slate))
	lid(part(m, V(W + 0.2, 0.16, D + 0.2), CF(0, lidY + 0.06, 0), c.gold, MAT.Metal))
	lid(part(m, V(W - 0.2, 0.12, 0.3), CF(0, lidY + 0.98, 0), c.gold, MAT.Metal))
	for _, x in ipairs({ -1, 1 }) do
		lid(part(m, V(0.3, 0.62, D + 0.16), CF(x * (W / 2 - 0.1), lidY + 0.3, 0), c.gold, MAT.Metal))
		local base = V(x * (W / 2 - 0.35), lidY + 1.0, -D / 2 + 0.4) -- рога по углам
		lid(wedge(m, V(0.3, 0.7, 0.4), CF(base + V(x * 0.15, 0.3, 0)) * ANG(0, 0, rad(-25 * x)) * ANG(0, PI, 0), c.gold, MAT.Metal))
	end
	lid(neon(m, V(0.42, 0.42, 0.14), CF(0, lidY + 0.3, -D / 2 - 0.1) * ANG(0, 0, rad(45)), c.orange))
	for _, x in ipairs({ -1.2, 1.2 }) do -- петли (не часть крышки)
		part(m, V(0.5, 0.3, 0.2), CF(x, lidY, D / 2 + 0.08), c.gold, MAT.Metal)
	end
	r.Hinge = CF(0, lidY, D / 2)
	return lidY
end

local function Halloween(m)
	local r = newCase()
	r.Chains, r.Eyes, r.Fire, r.LidParts = {}, {}, {}, {}
	local c = {
		black = rgb(20, 14, 22), coal = rgb(38, 26, 40), gold = rgb(214, 168, 70), goldDark = rgb(140, 100, 40),
		orange = rgb(255, 130, 30), ember = rgb(255, 190, 80), iron = rgb(70, 64, 76),
	}
	local W, Hh, D = HW.W, HW.H, HW.D
	-- корпус на золотом цоколе
	r.Body = part(m, V(W, Hh, D), CF(0, 0.3 + Hh / 2, 0), c.black, MAT.Slate)
	part(m, V(W + 0.3, 0.35, D + 0.3), CF(0, 0.18, 0), c.gold, MAT.Metal)
	part(m, V(W - 0.4, 0.12, D - 0.4), CF(0, 0.02, 0), c.goldDark, MAT.Metal)
	for _, x in ipairs({ -1, 1 }) do
		for _, z in ipairs({ -1, 1 }) do
			-- ножки-когти и золотые угловые рёбра
			wedge(m, V(0.5, 0.45, 0.5), CF(x * (W / 2 - 0.1), 0, z * (D / 2 - 0.1)) * ANG(0, z < 0 and 0 or PI, 0) * ANG(PI, 0, 0), c.gold, MAT.Metal)
			part(m, V(0.3, Hh + 0.05, 0.3), CF(x * (W / 2 - 0.08), 0.3 + Hh / 2, z * (D / 2 - 0.08)), c.gold, MAT.Metal)
		end
	end
	for _, y in ipairs({ 0.95, 1.75 }) do -- тёмные доски
		part(m, V(W - 0.4, 0.06, 0.06), CF(0, y, -D / 2 - 0.01), c.coal, MAT.Wood)
	end
	part(m, V(W + 0.06, 0.2, D + 0.06), CF(0, 0.3 + Hh - 0.1, 0), c.gold, MAT.Metal)
	-- светящиеся глаза со злыми бровями
	for _, s in ipairs({ -1, 1 }) do
		r.Eyes[#r.Eyes + 1] = neon(m, V(0.62, 0.3, 0.12), CF(0.85 * s, 1.95, -D / 2 - 0.04) * ANG(0, 0, rad(-14 * s)), c.orange)
		r.Eyes[#r.Eyes + 1] = neon(m, V(0.16, 0.16, 0.14), CF(0.85 * s, 1.93, -D / 2 - 0.06) * ANG(0, 0, rad(45)), c.ember)
		part(m, V(0.8, 0.14, 0.12), CF(0.8 * s, 2.22, -D / 2 - 0.05) * ANG(0, 0, rad(22 * s)), c.gold, MAT.Metal)
	end
	-- клыкастая пасть под глазами
	part(m, V(2.2, 0.32, 0.08), CF(0, 1.52, -D / 2 - 0.02), rgb(60, 16, 10))
	for k = -3, 3 do
		wedge(m, V(0.08, 0.22, 0.2), CF(k * 0.3, 1.57, -D / 2 - 0.08) * ANG(0, PI / 2, 0) * ANG(PI, 0, 0), rgb(230, 220, 200))
	end
	-- цепи крест-накрест по фасаду, по бокам, замок со скважиной (Core тоже разлетается с цепями)
	local fz = -D / 2 - 0.12
	chainLinks(m, r.Chains, V(-W / 2 + 0.2, 0.5, fz), V(-0.3, 1.0, fz), c.iron)
	chainLinks(m, r.Chains, V(W / 2 - 0.2, 0.5, fz), V(0.3, 1.0, fz), c.iron)
	chainLinks(m, r.Chains, V(0, 1.35, fz - 0.05), V(0, 2.65, fz - 0.05), c.iron)
	for _, x in ipairs({ -1, 1 }) do
		chainLinks(m, r.Chains, V(x * (W / 2 + 0.1), 2.6, -D / 2 + 0.2), V(x * (W / 2 + 0.1), 0.45, D / 2 - 0.2), c.iron)
	end
	r.Chains[#r.Chains + 1] = part(m, V(0.8, 0.75, 0.3), CF(0, 0.95, fz - 0.15), c.gold, MAT.Metal)
	for _, s in ipairs({ -1, 1 }) do
		r.Chains[#r.Chains + 1] = part(m, V(0.12, 0.4, 0.12), CF(0.25 * s, 1.45, fz - 0.15), c.goldDark, MAT.Metal)
	end
	r.Chains[#r.Chains + 1] = part(m, V(0.62, 0.12, 0.12), CF(0, 1.62, fz - 0.15), c.goldDark, MAT.Metal)
	r.Core = neon(m, V(0.2, 0.32, 0.08), CF(0, 0.9, fz - 0.32), c.orange)
	r.Chains[#r.Chains + 1] = r.Core
	local lidY = halloweenLid(m, r, c)
	-- огонь у передних углов и на рогах крышки
	for _, x in ipairs({ -1, 1 }) do
		fireEmitter(m, r.Fire, CF(x * (W / 2 + 0.2), 0.45, -D / 2 - 0.2), 0.5, 12)
		fireEmitter(m, r.Fire, CF(x * (W / 2 - 0.35), lidY + 1.35, -D / 2 + 0.4), 0.3, 8)
	end
	-- парящие угли
	for i = 0, 3 do
		local a = i / 4 * PI * 2 + 0.4
		r.Shards[#r.Shards + 1] = neon(m, V(0.25, 0.25, 0.25), CF(math.cos(a) * 2.8, 3.4 + (i % 2) * 0.6, math.sin(a) * 2.6) * ANG(rad(45), a, rad(45)), c.ember)
	end
	return r
end

------------------------------------------------------------------------
-- API
------------------------------------------------------------------------
local Builders = { VoidCase = VoidCase, ShatteredReality = ShatteredReality, BloodMoon = BloodMoon, Halloween = Halloween }
CaseModels.Ids = { "VoidCase", "ShatteredReality", "BloodMoon", "Halloween" }

local warned = {}

function CaseModels.Has(caseId)
	return Builders[caseId] ~= nil
end

function CaseModels.Build(caseId)
	local m = Instance.new("Model")
	m.Name = "Case_" .. tostring(caseId)
	local builder = Builders[caseId]
	if not builder then
		if not warned[tostring(caseId)] then
			warned[tostring(caseId)] = true
			warn("[CaseModels] unknown case " .. tostring(caseId) .. ", using VoidCase")
		end
		builder = VoidCase
	end
	local r = builder(m)
	r.Model = m
	r.CaseId = caseId
	m.PrimaryPart = r.Body
	m.WorldPivot = CF() -- точка опоры — центр основания (Body.PivotOffset)
	-- приглушённый неон (один раз; общий Kit.Calm мира пропустит модель по атрибуту)
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") and d.Material == MAT.Neon then
			d.Color = d.Color:Lerp(CALM_DARK, CALM_AMOUNT)
		end
	end
	m:SetAttribute("Calmed", CALM_AMOUNT)
	-- исходные позиции для тряски и открытия
	r.Base = {}
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			r.Base[d] = d.CFrame
		end
	end
	return r
end

return CaseModels
