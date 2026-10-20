--!nocheck
-- VOID TD :: Models/Units (UnitModels)
-- Процедурные модели юнитов (R6 в угловатом стиле), союзников-призывов и 3D-иконок рун. Без внешних ассетов.
-- Реестр заполняют дочерние модули Void, Shattered, Blood, Clockmaker, Halloween, Allies, Runes
-- (каждый: `return function(UnitModels, Kit, Parts) ... end`); отсутствующий модуль пропускается,
-- ошибка загрузки модуля — warn + запись в UnitModels.LoadErrors (остальные семейства работают).
--
-- API
--   UnitModels.Lite (bool)                      облегчённый режим (= Kit.Lite; запись меняет Kit.Lite)
--   UnitModels.Build(unitId, level) -> rig       level 1..5 (зажимается); применяет скин уровня, Kit.Calm, ауру редкости
--                                                (не в Lite), атрибуты модели UnitId, Level; Model.Name = unitId
--   UnitModels.BuildAlly(allyId) -> rig          R6 с моторами RS LS RH LH Neck Root (ходьба), атрибут модели AllyId, rig.AllyId
--   UnitModels.BuildRune(runeId) -> { Model, Core }   заякоренные детали, центр (pivot) в начале координат, ~2.5 студа
--   UnitModels.Has(unitId)  HasAlly(allyId)  HasRune(runeId) -> bool
--   UnitModels.Rarity(unitId) -> "Common".."Secret" | nil   (Config.Units[id].Rarity; rarity из Register — запасной)
--   UnitModels.Scale(unitId) -> number           Config.Units[id].Scale or 1 — масштаб для r:Finish в строителях
--   UnitModels.Kit, .Parts (= .H), .Palette (= Kit.P), .Rig (= Kit.Rig), .LoadErrors {name -> текст}
--
-- РЕГИСТРАЦИЯ (из дочерних модулей)
--   UnitModels.Register(unitId, builder, rarity?)
--       builder(lv, unitId) -> rig   ГОТОВЫЙ rig: строитель сам вызывает Parts.levelAura(r, lv, color) и
--                                    r:Finish(UnitModels.Scale(unitId), idlePose); r.Muzzle — на острие оружия.
--   UnitModels.RegisterAlly(allyIdOrFamily, builder)
--       ключ — id союзника (приоритет) или семейство Config.Allies[id].Family ("Illusion" | "Puppet" | "Cursed").
--       builder(allyId, tier, def) -> r, glowColor?   rig БЕЗ Finish (BuildAlly сам вызывает r:Finish(scale, {}));
--       строится с Kit.Cheap = true. Масштаб: Tier > 5 или GoldenMarionette — 1.3, иначе 0.82 + 0.06 * min(Tier, 5).
--       После Finish: удаляются Trail/ParticleEmitter/PointLight, вне Lite — один PointLight цвета glow на Torso
--       (Range 6, Brightness 0.8), Kit.Calm, все детали CanQuery/CanTouch/CastShadow = false.
--   UnitModels.RegisterRune(runeId, builder)
--       builder(m) -> corePart   детали — Parts.rpart / Parts.rwedge прямо в Model m (имя "Rune_<id>"), свет — Parts.rlight;
--       BuildRune ставит PrimaryPart = core, pivot в начало координат и Kit.Calm(m, 0.2).
--
-- СКИН УРОВНЯ (все видимые детали + скрытые с атрибутами StormFX / PT, чтобы при показе они совпадали с остальными)
--   Metal: lv1 -> CorrodedMetal; lv>=4 -> Foil (+ lv5 оттенок редкости 0.1); SmoothPlastic lv1 -> Plastic;
--   Fabric lv5 -> оттенок редкости 0.06. Оттенок только для Epic / Legendary / Mythic / Secret.
-- АУРА РЕДКОСТИ: Attachment "AuraPoint" на Root у ног + ParticleEmitter "RarityAura" (создаётся после Calm).

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("VoidTD")
local Config = require(Shared.Config)
local Kit = require(Shared.Models.Kit)
local Parts = require(Shared.Models.Parts)

local V = Vector3.new
local CF = CFrame.new
local rgb = Kit.rgb

local UnitModels = {}
UnitModels.Kit = Kit
UnitModels.Parts = Parts
UnitModels.H = Parts
UnitModels.Palette = Kit.P
UnitModels.Rig = Kit.Rig
UnitModels.LoadErrors = {}

-- Lite — общий флаг Kit (его читают все хелперы); поле UnitModels.Lite лишь прокси
setmetatable(UnitModels, {
	__index = function(_, key)
		if key == "Lite" then
			return Kit.Lite == true
		end
		return nil
	end,
	__newindex = function(t, key, value)
		if key == "Lite" then
			Kit.Lite = value == true
		else
			rawset(t, key, value)
		end
	end,
})

local Builders, RegRarity = {}, {}
local AllyBuilders, RuneBuilders = {}, {}

------------------------------------------------------------------------
-- РЕЕСТР
------------------------------------------------------------------------
function UnitModels.Register(unitId, builder, rarity)
	assert(type(unitId) == "string" and type(builder) == "function", "UnitModels.Register(unitId, builder, rarity?)")
	Builders[unitId] = builder
	RegRarity[unitId] = rarity
end

function UnitModels.RegisterAlly(key, builder)
	assert(type(key) == "string" and type(builder) == "function", "UnitModels.RegisterAlly(allyIdOrFamily, builder)")
	AllyBuilders[key] = builder
end

function UnitModels.RegisterRune(runeId, builder)
	assert(type(runeId) == "string" and type(builder) == "function", "UnitModels.RegisterRune(runeId, builder)")
	RuneBuilders[runeId] = builder
end

function UnitModels.Has(unitId)
	return Builders[unitId] ~= nil
end

local function allyBuilder(allyId)
	local def = Config.Allies and Config.Allies[allyId]
	if not def then
		return nil, nil
	end
	return AllyBuilders[allyId] or AllyBuilders[def.Family], def
end

function UnitModels.HasAlly(allyId)
	return (allyBuilder(allyId)) ~= nil
end

function UnitModels.HasRune(runeId)
	return RuneBuilders[runeId] ~= nil
end

function UnitModels.Rarity(unitId)
	local def = Config.Units and Config.Units[unitId]
	return (def and def.Rarity) or RegRarity[unitId]
end

function UnitModels.Scale(unitId)
	local def = Config.Units and Config.Units[unitId]
	return (def and def.Scale) or 1
end

------------------------------------------------------------------------
-- СКИН УРОВНЯ И АУРА РЕДКОСТИ
------------------------------------------------------------------------
local MAT = Enum.Material
local RARITY_TINT = {
	Epic = rgb(150, 80, 230),
	Legendary = rgb(230, 180, 60),
	Mythic = rgb(150, 70, 230),
	Secret = rgb(230, 30, 40),
}

local RARITY_AURA = {
	Epic = { Color = ColorSequence.new(rgb(170, 80, 255)), Rate = 3, Size = 0.22 },
	Legendary = { Color = ColorSequence.new(rgb(255, 205, 70), rgb(190, 110, 255)), Rate = 5, Size = 0.28 },
	Mythic = { Color = ColorSequence.new(rgb(255, 50, 150), rgb(150, 60, 255)), Rate = 8, Size = 0.34 },
	Secret = { Color = ColorSequence.new(rgb(255, 20, 40), rgb(20, 0, 0)), Rate = 14, Size = 0.45 },
}
UnitModels.RarityTint = RARITY_TINT

-- 1 — потёртый ржавый металл, 2–3 — металл, 4–5 — блестящая фольга; на 5-м броня с оттенком редкости
local function applyLevelSkin(model, lv, rarity)
	local tint = RARITY_TINT[rarity or ""]
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart"
			and (d.Transparency < 1 or d:GetAttribute("StormFX") ~= nil or d:GetAttribute("PT") ~= nil) then
			local mat = d.Material
			if mat == MAT.Metal then
				if lv == 1 then
					d.Material = MAT.CorrodedMetal
				elseif lv >= 4 then
					d.Material = MAT.Foil
					if lv >= 5 and tint then
						d.Color = d.Color:Lerp(tint, 0.1)
					end
				end
			elseif mat == MAT.SmoothPlastic then
				if lv == 1 then
					d.Material = MAT.Plastic
				end
			elseif mat == MAT.Fabric then
				if lv >= 5 and tint then
					d.Color = d.Color:Lerp(tint, 0.06)
				end
			end
		end
	end
end
UnitModels.ApplyLevelSkin = applyLevelSkin

local function addRarityAura(rig, rarity)
	local aura = RARITY_AURA[rarity or ""]
	if not aura or Kit.IsLite() or not rig.Root then
		return nil
	end
	local at = Instance.new("Attachment")
	at.Name = "AuraPoint"
	at.Position = V(0, -(rig.HipHeight or 3) + 0.2, 0)
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
	return e
end

------------------------------------------------------------------------
-- ЮНИТЫ
------------------------------------------------------------------------
local function clampLevel(level)
	local lv = tonumber(level) or 1
	if lv ~= lv then
		lv = 1
	end
	return math.clamp(math.floor(lv), 1, 5)
end

-- Модель стоит в начале координат, ноги на высоте -HipHeight
function UnitModels.Build(unitId, level)
	local builder = Builders[unitId]
	if not builder then
		error("Unknown unit " .. tostring(unitId), 2)
	end
	local lv = clampLevel(level)
	local rig = Kit.WithCheap(false, builder, lv, unitId) -- юниты всегда в полной детализации
	assert(type(rig) == "table" and rig.Model, "unit builder " .. unitId .. " returned no rig")
	if not rig.Scale then
		rig:Finish(UnitModels.Scale(unitId), rig.Idle)
	end
	local model = rig.Model
	model.Name = unitId
	local rarity = UnitModels.Rarity(unitId)
	applyLevelSkin(model, lv, rarity)
	Kit.Calm(model)
	addRarityAura(rig, rarity) -- после Calm: аура не приглушается
	model:SetAttribute("UnitId", unitId)
	model:SetAttribute("Level", lv)
	rig.UnitId = unitId
	rig.Level = lv
	return rig
end

------------------------------------------------------------------------
-- СОЮЗНИКИ (призывы): лёгкие R6-фигуры, ходят толпой
------------------------------------------------------------------------
local function allyScale(allyId, def)
	local tier = tonumber(def.Tier) or 1
	if allyId == "GoldenMarionette" or tier > 5 then
		return 1.3
	end
	return 0.82 + 0.06 * math.min(tier, 5)
end

function UnitModels.BuildAlly(allyId)
	local builder, def = allyBuilder(allyId)
	if not def then
		error("Unknown ally " .. tostring(allyId), 2)
	end
	if not builder then
		error("No model for ally " .. tostring(allyId) .. " (family " .. tostring(def.Family) .. ")", 2)
	end
	-- союзники ходят группами: дешёвая фаска (2 детали), без частиц и шлейфов
	local r, glow = Kit.WithCheap(true, builder, allyId, def.Tier, def)
	assert(type(r) == "table" and r.Model, "ally builder " .. tostring(allyId) .. " returned no rig")
	if not r.Scale then
		r:Finish(allyScale(allyId, def), {})
	end
	local model = r.Model
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("Trail") or d:IsA("ParticleEmitter") or d:IsA("PointLight") then
			d:Destroy()
		end
	end
	if glow and not Kit.IsLite() and r.Torso then
		-- одна подсветка вместо частиц
		local l = Instance.new("PointLight")
		l.Color = glow
		l.Range = 6
		l.Brightness = 0.8
		l.Shadows = false
		l.Parent = r.Torso
	end
	Kit.Calm(model)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CanQuery = false
			d.CanTouch = false
			d.CastShadow = false
		end
	end
	model.Name = allyId
	model:SetAttribute("AllyId", allyId)
	r.AllyId = allyId
	r.Glow = glow
	return r
end

------------------------------------------------------------------------
-- РУНЫ (3D-иконки)
------------------------------------------------------------------------
function UnitModels.BuildRune(runeId)
	local builder = RuneBuilders[runeId]
	if not builder then
		error("Unknown rune " .. tostring(runeId), 2)
	end
	local m = Instance.new("Model")
	m.Name = "Rune_" .. runeId
	local core = builder(m)
	assert(typeof(core) == "Instance" and core:IsA("BasePart"), "rune builder " .. runeId .. " returned no core part")
	-- pivot иконки — начало координат (одинаково в Studio и в моке)
	core.PivotOffset = core.CFrame:Inverse()
	m.PrimaryPart = core
	m.WorldPivot = CF()
	Kit.Calm(m, 0.2)
	m:SetAttribute("RuneId", runeId)
	return { Model = m, Core = core }
end

------------------------------------------------------------------------
-- СЕМЕЙСТВА (дочерние модули)
------------------------------------------------------------------------
local CHILDREN = { "Void", "Shattered", "Blood", "Clockmaker", "Halloween", "Allies", "Runes" }
for _, name in ipairs(CHILDREN) do
	local mod = script:FindFirstChild(name)
	if mod and mod:IsA("ModuleScript") then
		local ok, err = xpcall(function()
			local install = require(mod)
			assert(type(install) == "function", "module must return function(UnitModels, Kit, Parts)")
			install(UnitModels, Kit, Parts)
		end, debug.traceback)
		if not ok then
			UnitModels.LoadErrors[name] = tostring(err)
			warn("[UnitModels] " .. name .. ": " .. tostring(err))
		end
	end
end

return UnitModels
