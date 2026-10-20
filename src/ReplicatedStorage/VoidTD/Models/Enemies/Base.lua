--!nocheck
-- VOID TD :: Models/Enemies/Base
-- Базовые хелперы врагов: существа (Root -> невидимый Torso + узлы-моторы) и R6-бипеды с невидимыми
-- конечностями, поверх которых строится форма из деталей Kit (bevel, spike, gem, crack, ring, tatter...).
-- Модули семейств Enemies/Void и Enemies/Halloween строят ТОЛЬКО на этом API + Kit.
--
-- ПАЛИТРЫ / КОНСТАНТЫ
--   Base.C  (Пустота) Obsidian Night Deep Mid Lilac Ghost GhostMid Bone BoneDark Gun GunLight Gold GoldDark Flesh
--           FleshLight FleshDark Stone StoneLight Neon NeonSoft Magenta White Steel
--   Base.HC (Хэллоуин) Pumpkin PumpkinHi PumpkinDark Burnt Stem Fire FireSoft Green GreenSoft Rot RotDark RotHi Rag RagHi
--           Purple PurpleHi PurpleGlow Burgundy BurgundyHi Gold GoldDark Straw StrawDark Sack SackDark Ghost GhostMid
--           GhostDeep Iron IronHi Rust Stone StoneHi StoneDark Moss Fog FogDark Red Crow
--   Base.AC (= Kit.Colors: Armor ArmorMid Edge Cloth ClothDark)   Base.M (= Kit.M: Plastic Metal Neon Fabric Slate Glass Wood Grass Foil CorrodedMetal)
--   Base.rgb(r,g,b)   Base.lite() -> bool   Base.SMOKE_TEXTURE (встроенная текстура дыма клиента)
--
-- RIG ВРАГА (поля, которые читает Renderer; заполняются setup/finish*)
--   Style "Biped"|"Heavy"|"Crawl"|"Gallop"|"Float"; Gait {Speed, Stride, Bob, Sway, Lean, Shake}; Sec {motor -> {Amp, Speed}}
--   (по префиксу имени мотора: Sway* Cape* Orbit* Spin* Bob* Twitch*); Phases {{At, Reveal, Break, Emit, Lights, Aggro}};
--   DeathStyle "Dissipate"|"Scatter"|"Collapse"|"Topple"|"Implode"; SpawnStyle "Rise"|"Fade"|"Titan"; DeathFX; SpawnFX;
--   HipHeight Height Scale Idle Base Motors Root Model (+ бипед: Torso Head RArm LArm RLeg LLeg HeadSize Muzzle)
--   Моторы походки: Crawl/Gallop — FR FL BR BL; Float — ArmR ArmL (ArmR2 ArmL2); бипед — Root Neck RS LS RH LH.
--   Phases: списки могут содержать nil (emitter/Glow в Lite) — EnemyModels.Build их уплотняет и сортирует по At.
--
-- ХЕЛПЕРЫ
--   newCreature(name, bodySize) -> r        Root "HumanoidRootPart" (1³, якорь) -> мотор "Root" -> невидимый "Torso" bodySize
--   newBiped(name, headSize=V(1.3)^3) -> r  Kit.Rig.new, все 6 конечностей невидимы (форма строится поверх)
--   setup(r, {Style, Gait, Death="Topple", Spawn="Rise", DeathFX?, SpawnFX?})   поля rig + пустые Sec / Phases
--   hub(r, name, limb, pivot, sec?) -> part  невидимый узел на моторе name (sec = {Amp, Speed} -> r.Sec[name])
--   emitter(part, color, {Smoke, Rate=8, LifeMin=0.6, LifeMax=1.2, SpeedMin=0.3, SpeedMax=1.2, Size=0.4, SizeEnd=0,
--           T0=0.2, Accel, Off, Name}) -> ParticleEmitter "EnemyFX" | nil (Lite)
--   emitPoint(r, limb, offset, size=V(0.6)^3) -> part   невидимый носитель частиц "Emit"
--   darkTrail(r, limb, a, b, color)         шлейф (после finish: "EnemyTrail", включён); не в Lite
--   finishCreature(r, scale, hip, height) -> r   Finish(scale); HipHeight = hip*scale (+атрибут), Height = height*scale
--   finishBiped(r, scale, idle, height?) -> r    Finish(scale, idle); Height = (height or 3+1+HeadSize.Y+0.6)*scale
--   mark(parts, attr) -> parts               атрибут attr = true (Outline, Crown ...)
--   list(...) -> {}                           список без nil (для Phases.Emit / Lights / Reveal)
--   outline(parts, edgePart?) -> parts       пометить контур Outline: кант bevel (2-й результат bevel), а в Lite /
--                                            без канта — сами детали
--   pumpkin(r, limb, cf, s, {Color, Dark, Glow, Edge, Stem}) -> all, eyes, mouth   гранёная тыква с горящим лицом (-Z)
--   deepHood(r, limb, w, h, color, edge, y=0) -> faceZ   глубокий капюшон с тёмным провалом
--   claws(r, A, color, n=3, len=0.5)         когти-шипы на кисти

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("VoidTD")
local Kit = require(Shared.Models.Kit)

local Base = {}

local V = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles
local rad = math.rad

local rgb = Kit.rgb
local M = Kit.M
local bevel, bar, spike = Kit.bevel, Kit.bar, Kit.spike

local C = {
	Obsidian = rgb(22, 16, 30), Night = rgb(32, 23, 46), Deep = rgb(46, 31, 70), Mid = rgb(74, 50, 112),
	Lilac = rgb(122, 92, 170), Ghost = rgb(206, 192, 245), GhostMid = rgb(160, 132, 222), Bone = rgb(214, 204, 186),
	BoneDark = rgb(150, 138, 122), Gun = rgb(52, 50, 66), GunLight = rgb(92, 90, 112), Gold = rgb(196, 150, 64),
	GoldDark = rgb(130, 94, 40), Flesh = rgb(86, 26, 48), FleshLight = rgb(128, 44, 70), FleshDark = rgb(52, 16, 32),
	Stone = rgb(64, 60, 78), StoneLight = rgb(98, 92, 116), Neon = rgb(180, 80, 255), NeonSoft = rgb(222, 170, 255),
	Magenta = rgb(255, 60, 170), White = rgb(250, 244, 255), Steel = rgb(110, 110, 128),
}

local HC = {
	Pumpkin = rgb(214, 102, 26), PumpkinHi = rgb(250, 150, 60), PumpkinDark = rgb(150, 62, 18), Burnt = rgb(70, 34, 20),
	Stem = rgb(58, 70, 32), Fire = rgb(255, 140, 30), FireSoft = rgb(255, 196, 90), Green = rgb(130, 255, 90),
	GreenSoft = rgb(190, 255, 150), Rot = rgb(84, 104, 72), RotDark = rgb(50, 62, 44), RotHi = rgb(130, 146, 104),
	Rag = rgb(54, 48, 44), RagHi = rgb(96, 86, 74), Purple = rgb(44, 24, 62), PurpleHi = rgb(96, 62, 128),
	PurpleGlow = rgb(170, 90, 255), Burgundy = rgb(92, 20, 34), BurgundyHi = rgb(150, 50, 66), Gold = rgb(214, 166, 64),
	GoldDark = rgb(140, 100, 36), Straw = rgb(214, 178, 92), StrawDark = rgb(160, 122, 54), Sack = rgb(176, 148, 104),
	SackDark = rgb(120, 96, 64), Ghost = rgb(150, 226, 218), GhostMid = rgb(96, 170, 172), GhostDeep = rgb(34, 60, 70),
	Iron = rgb(58, 58, 66), IronHi = rgb(116, 116, 128), Rust = rgb(110, 62, 38), Stone = rgb(80, 80, 86),
	StoneHi = rgb(130, 130, 136), StoneDark = rgb(52, 52, 58), Moss = rgb(66, 92, 50), Fog = rgb(150, 160, 150),
	FogDark = rgb(70, 78, 74), Red = rgb(255, 40, 40), Crow = rgb(22, 20, 26),
}

-- встроенная текстура дыма клиента Roblox (content/textures/particles), не ассет из каталога
local SMOKE_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"

Base.C, Base.HC, Base.AC, Base.M, Base.rgb, Base.SMOKE_TEXTURE = C, HC, Kit.Colors, M, rgb, SMOKE_TEXTURE
Base.Kit = Kit

local function lite()
	return Kit.IsLite()
end
Base.lite = lite

------------------------------------------------------------------------
-- RIG
------------------------------------------------------------------------
-- Существо без человеческого скелета: Root -> Torso (мотор "Root"); форма — детали на Torso и узлах
function Base.newCreature(name, bodySize)
	local r = Kit.Rig.bare(name)
	local model = r.Model
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
	r.Root = root

	local body = Instance.new("Part")
	body.Name = "Torso"
	body.Size = bodySize or V(1, 1, 1)
	body.Color = C.Night
	body.Transparency = 1 -- форма тела строится деталями
	body.Anchored = false
	body.CanCollide = false
	body.CanTouch = false
	body.Massless = true
	body.TopSurface = Enum.SurfaceType.Smooth
	body.BottomSurface = Enum.SurfaceType.Smooth
	body.CFrame = CF()
	body.Parent = model
	r.Torso = body
	r.Parts[#r.Parts + 1] = body
	r:Motor("Root", root, body, CF(), CF())
	return r
end

-- Скелет R6 с невидимыми базовыми конечностями: форма строится поверх
function Base.newBiped(name, headSize)
	local r = Kit.Rig.new({ Name = name, HeadSize = headSize or V(1.3, 1.3, 1.3), Torso = C.Night, Arm = C.Night, Leg = C.Night, Head = C.Night })
	for _, L in ipairs({ r.Torso, r.Head, r.RArm, r.LArm, r.RLeg, r.LLeg }) do
		L.Transparency = 1
	end
	return r
end

function Base.setup(r, o)
	o = o or {}
	r.Style = o.Style or "Biped"
	r.Gait = o.Gait or {}
	r.Sec = r.Sec or {}
	r.Phases = r.Phases or {}
	r.DeathStyle = o.Death or "Topple"
	r.SpawnStyle = o.Spawn or "Rise"
	if o.DeathFX then
		r.DeathFX = o.DeathFX
	end
	if o.SpawnFX then
		r.SpawnFX = o.SpawnFX
	end
	return r
end

-- Невидимый узел на моторе name
function Base.hub(r, name, limb, pivot, sec)
	local h = r:Joint(name, limb, V(0.2, 0.2, 0.2), pivot, CF(), C.Obsidian)
	h.Transparency = 1
	if sec then
		r.Sec = r.Sec or {}
		r.Sec[name] = sec
	end
	return h
end

------------------------------------------------------------------------
-- ЧАСТИЦЫ И ШЛЕЙФЫ
------------------------------------------------------------------------
function Base.emitter(part, color, o)
	if lite() or not part then
		return nil
	end
	o = o or {}
	local e = Instance.new("ParticleEmitter")
	e.Name = o.Name or "EnemyFX"
	if o.Smoke then
		e.Texture = SMOKE_TEXTURE
	end
	e.Color = typeof(color) == "ColorSequence" and color or ColorSequence.new(color or C.Neon)
	e.LightEmission = o.Smoke and 0.3 or 1
	e.LightInfluence = o.Smoke and 0.4 or 0
	e.Rate = o.Rate or 8
	e.Lifetime = NumberRange.new(o.LifeMin or 0.6, o.LifeMax or 1.2)
	e.Speed = NumberRange.new(o.SpeedMin or 0.3, o.SpeedMax or 1.2)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-40, 40)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, o.Size or 0.4), NumberSequenceKeypoint.new(1, o.SizeEnd or 0) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, o.T0 or 0.2), NumberSequenceKeypoint.new(1, 1) })
	if o.Accel then
		e.Acceleration = o.Accel
	end
	if o.Off then
		e.Enabled = false
	end
	e.Parent = part
	return e
end

function Base.emitPoint(r, limb, offset, size)
	return r:Box(limb, size or V(0.6, 0.6, 0.6), offset or CF(), C.Obsidian, M.Plastic, { Transparency = 1, Name = "Emit" })
end

function Base.darkTrail(r, limb, a, b, color)
	if lite() then
		return
	end
	r.PendingTrails[#r.PendingTrails + 1] = { limb, a, b, color or C.Neon }
end

-- Шлейфы врагов всегда включены и короче, чем у оружия юнитов
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

function Base.finishCreature(r, scale, hip, height)
	scale = scale or 1
	r:Finish(scale)
	r.HipHeight = (hip or 3) * scale
	r.Height = (height or 4) * scale
	r.Model:SetAttribute("HipHeight", r.HipHeight)
	afterFinish(r)
	return r
end

function Base.finishBiped(r, scale, idle, height)
	scale = scale or 1
	r:Finish(scale, idle)
	r.Height = (height or (3 + 1 + r.HeadSize.Y + 0.6)) * scale
	afterFinish(r)
	return r
end

------------------------------------------------------------------------
-- СПИСКИ И АТРИБУТЫ
------------------------------------------------------------------------
-- Список без nil (числовые ключи по порядку): {nil, aura} -> {aura}
local function compact(t)
	if type(t) ~= "table" then
		return {}
	end
	local keys = {}
	for k, v in pairs(t) do
		if type(k) == "number" and v ~= nil then
			keys[#keys + 1] = k
		end
	end
	table.sort(keys)
	local out = {}
	for i, k in ipairs(keys) do
		out[i] = t[k]
	end
	return out
end
Base.compact = compact

function Base.list(...)
	return compact(table.pack(...))
end

function Base.mark(parts, attr)
	for _, p in ipairs(parts or {}) do
		p:SetAttribute(attr, true)
	end
	return parts or {}
end

-- Контур, который остаётся видимым в фазе невидимости: кант bevel; в Lite канта нет — помечаются сами детали
function Base.outline(parts, edgePart)
	if edgePart then
		edgePart:SetAttribute("Outline", true)
		return { edgePart }
	end
	return Base.mark(parts, "Outline")
end

------------------------------------------------------------------------
-- ХЭЛЛОУИНСКИЕ ДЕТАЛИ
------------------------------------------------------------------------
-- Угловатая тыква: крест из двух брусков с фаской, борозды, хвостик, вырезанное светящееся лицо (в -Z cf)
function Base.pumpkin(r, limb, cf, s, o)
	o = o or {}
	local col, dark, glow = o.Color or HC.Pumpkin, o.Dark or HC.PumpkinDark, o.Glow or HC.Fire
	local all, eyes, mouth = {}, {}, {}
	local function add(list)
		for _, p in ipairs(list) do
			all[#all + 1] = p
		end
	end
	add(bevel(r, limb, V(1.75, 1.2, 1.2) * s, cf, col, o.Edge or HC.PumpkinHi, M.Plastic))
	add(bevel(r, limb, V(1.2, 1.28, 1.6) * s, cf, col, o.Edge or HC.PumpkinHi, M.Plastic))
	if not Kit.Cheap then -- тёмные борозды между дольками
		for _, x in ipairs({ -0.66, 0.66 }) do
			all[#all + 1] = r:Box(limb, V(0.1, 1.15, 0.05) * s, cf * CF(x * s, 0, -0.6 * s), dark, M.Plastic)
			all[#all + 1] = r:Box(limb, V(0.05, 1.15, 0.1) * s, cf * CF(x * 1.33 * s, 0, 0), dark, M.Plastic)
		end
	end
	all[#all + 1] = r:Box(limb, V(1.1, 0.2, 1.05) * s, cf * CF(0, 0.66 * s, 0), dark, M.Plastic)
	all[#all + 1] = bar(r, limb, (cf * CF(0, 0.7 * s, 0)).Position, (cf * CF(0.12 * s, 1.1 * s, 0.1 * s)).Position, 0.18 * s, o.Stem or HC.Stem)
	local z = -0.81 * s
	for _, side in ipairs({ -1, 1 }) do
		local e = r:Neon(limb, V(0.36, 0.3, 0.06) * s, cf * CF(0.36 * side * s, 0.18 * s, z) * ANG(0, 0, rad(30 * side)), glow)
		eyes[#eyes + 1] = e
		all[#all + 1] = e
	end
	all[#all + 1] = r:Neon(limb, V(0.16, 0.16, 0.06) * s, cf * CF(0, -0.02 * s, z) * ANG(0, 0, rad(45)), glow)
	local m1 = r:Neon(limb, V(1.0, 0.22, 0.06) * s, cf * CF(0, -0.32 * s, z), glow)
	mouth[1] = m1
	all[#all + 1] = m1
	for _, x in ipairs({ -0.25, 0.22 }) do -- зубы
		all[#all + 1] = r:Box(limb, V(0.13, 0.14, 0.07) * s, cf * CF(x * s, -0.25 * s, z - 0.01 * s), dark, M.Plastic)
	end
	return all, eyes, mouth
end

-- Глубокий капюшон: верх, бока, спинка, козырёк; лицо утоплено внутрь (возвращает z лица)
function Base.deepHood(r, limb, w, h, color, edge, y)
	y = y or 0
	bevel(r, limb, V(w, 0.3, w), CF(0, y + h / 2 - 0.15, 0.05), color, edge, M.Fabric)
	for _, s in ipairs({ -1, 1 }) do
		bevel(r, limb, V(0.26, h, w), CF((w / 2 - 0.13) * s, y, 0.05), color, edge, M.Fabric)
	end
	bevel(r, limb, V(w, h, 0.26), CF(0, y, w / 2 - 0.08), color, edge, M.Fabric)
	r:Wedge(limb, V(w, 0.35, 0.45), CF(0, y + h / 2 - 0.45, -w / 2 + 0.15), color, M.Fabric)
	r:Box(limb, V(w - 0.4, h - 0.3, 0.1), CF(0, y - 0.05, 0.1), rgb(8, 6, 12), M.Plastic)
	return -w / 2 + 0.3
end

-- Когти-шипы на кисти руки A
function Base.claws(r, A, color, n, len)
	n = n or 3
	local parts = {}
	for k = 1, n do
		local x = (k - n / 2 - 0.5) * 0.28
		for _, p in ipairs(spike(r, A, V(x, -1.0, -0.2), V(x * 1.2, -1.15, -0.2 - (len or 0.5)), 0.16, color, M.Plastic, true, 0.06)) do
			parts[#parts + 1] = p
		end
	end
	return parts
end

return Base
