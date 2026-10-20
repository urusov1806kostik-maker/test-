--!nocheck
-- VOID TD :: Models/Enemies (EnemyModels)
-- Процедурные модели врагов в угловатом стиле. Модели — только визуал: урон и попадания считаются на сервере
-- по дистанции пути. Хелперы — дочерний модуль Base; строители — дочерние модули Void и Halloween
-- (каждый: `return function(EnemyModels, Kit, Base) ... end`, вызывает EnemyModels.Register).
-- Отсутствующий модуль пропускается; ошибка загрузки — warn + EnemyModels.LoadErrors[name].
--
-- API
--   EnemyModels.Lite (bool)                 = Kit.Lite (запись меняет Kit.Lite)
--   EnemyModels.Build(enemyId) -> rig        поля rig — см. заголовок Base (Style Gait Sec Phases DeathStyle SpawnStyle
--                                            DeathFX SpawnFX HipHeight Height Scale ...), + rig.EnemyId, rig.IsBoss;
--                                            атрибуты модели EnemyId, HipHeight
--   EnemyModels.Has(enemyId) -> bool
--   EnemyModels.Register(enemyId, builder)  builder(scale, enemyId, def) -> rig (через Base.finishCreature / finishBiped)
--   EnemyModels.Kit, .Base (= .H), .LoadErrors
--
-- Build: Config.Enemies[id] обязателен; не-боссы (IsBoss ~= true, в т.ч. мини-босс NightReaper) строятся с
-- Kit.Cheap = true (фаска из 2 деталей, плоские шипы, без борозд тыкв); Model.Name = id; Kit.Calm (0.3);
-- все детали CanQuery = false, CanTouch = false, CastShadow = только у боссов.
-- Phases уплотняются (nil из Lite выкидываются), сортируются по убыванию At; яркость Lights умножается на
-- Kit.CALM_LIGHT, чтобы скачок яркости фазы совпадал с задуманным относительно приглушённого света.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("VoidTD")
local Config = require(Shared.Config)
local Kit = require(Shared.Models.Kit)
local Base = require(script:WaitForChild("Base"))

local EnemyModels = {}
EnemyModels.Kit = Kit
EnemyModels.Base = Base
EnemyModels.H = Base
EnemyModels.LoadErrors = {}

setmetatable(EnemyModels, {
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

local Builders = {}

function EnemyModels.Register(enemyId, builder)
	assert(type(enemyId) == "string" and type(builder) == "function", "EnemyModels.Register(enemyId, builder)")
	Builders[enemyId] = builder
end

function EnemyModels.Has(enemyId)
	return Builders[enemyId] ~= nil
end

-- Фазы босса: без nil (emitter/Glow возвращают nil в Lite), по убыванию порога
local function normalizePhases(rig)
	local phases = Base.compact(rig.Phases)
	for _, ph in ipairs(phases) do
		ph.At = tonumber(ph.At) or 0
		ph.Reveal = Base.compact(ph.Reveal)
		ph.Break = Base.compact(ph.Break)
		ph.Emit = Base.compact(ph.Emit)
		local lights = {}
		for _, entry in ipairs(Base.compact(ph.Lights)) do
			if type(entry) == "table" and entry[1] ~= nil then
				lights[#lights + 1] = { entry[1], (tonumber(entry[2]) or entry[1].Brightness) * Kit.CALM_LIGHT }
			end
		end
		ph.Lights = lights
	end
	table.sort(phases, function(a, b)
		return a.At > b.At
	end)
	rig.Phases = phases
end

function EnemyModels.Build(enemyId)
	local def = Config.Enemies and Config.Enemies[enemyId]
	local builder = Builders[enemyId]
	if not def or not builder then
		error("Unknown enemy " .. tostring(enemyId), 2)
	end
	local boss = def.IsBoss == true
	-- обычные враги идут толпами: для них фаска дешевле (2 детали вместо 4), шипы плоские
	local rig = Kit.WithCheap(not boss, builder, def.Scale or 1, enemyId, def)
	assert(type(rig) == "table" and rig.Model, "enemy builder " .. enemyId .. " returned no rig")
	local model = rig.Model
	model.Name = enemyId
	Kit.Calm(model)
	normalizePhases(rig)
	rig.Style = rig.Style or "Biped"
	rig.Gait = rig.Gait or {}
	rig.Sec = rig.Sec or {}
	rig.DeathStyle = rig.DeathStyle or "Topple"
	rig.SpawnStyle = rig.SpawnStyle or "Rise"
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CanQuery = false
			d.CanTouch = false
			d.CastShadow = boss
		end
	end
	model:SetAttribute("EnemyId", enemyId)
	rig.EnemyId = enemyId
	rig.IsBoss = boss
	return rig
end

local CHILDREN = { "Void", "Halloween" }
for _, name in ipairs(CHILDREN) do
	local mod = script:FindFirstChild(name)
	if mod and mod:IsA("ModuleScript") then
		local ok, err = xpcall(function()
			local install = require(mod)
			assert(type(install) == "function", "module must return function(EnemyModels, Kit, Base)")
			install(EnemyModels, Kit, Base)
		end, debug.traceback)
		if not ok then
			EnemyModels.LoadErrors[name] = tostring(err)
			warn("[EnemyModels] " .. name .. ": " .. tostring(err))
		end
	end
end

return EnemyModels
