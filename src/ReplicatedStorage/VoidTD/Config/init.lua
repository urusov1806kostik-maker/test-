--!nocheck
-- VOID TD :: Config
-- Все цифры баланса собраны здесь. Меняй смело — остальной код читает только эту таблицу.
-- Таблица собирается из дочерних модулей (каждый возвращает свои ключи верхнего уровня):
--   Settings     — Settings
--   Rarities     — RarityOrder, Rarities
--   Cases        — CaseOrder, Cases
--   Shop         — Shop
--   Sounds       — Sounds
--   Difficulties — TargetModes, DifficultyOrder, Difficulties
--   World        — Lobby, BattleSpawn, Events, HalloweenIsland, Halloween, Map, Maps
--   Runes        — RuneRarity, RuneOrder, Runes, AllyOrder, Allies
--   Units        — UnitOrder, Units
--   Enemies      — EnemyOrder, Enemies
--   Waves        — Waves (карта Void; волны Хэллоуина — Maps.Halloween.Waves)

local Config = {}

Config.GameName = "VOID TD"

local PARTS = { "Settings", "Rarities", "Cases", "Shop", "Sounds", "Difficulties", "World", "Runes", "Units", "Enemies", "Waves" }

for _, name in ipairs(PARTS) do
	local part = require(script:WaitForChild(name))
	for key, value in pairs(part) do
		assert(Config[key] == nil, "[Config] ключ задан дважды: " .. tostring(key) .. " (" .. name .. ")")
		Config[key] = value
	end
end

-- Maps.Void — это та же самая таблица, что и Config.Map
assert(Config.Maps.Void == Config.Map, "[Config] Maps.Void должна быть Config.Map")

------------------------------------------------------------------------
-- Проверка ссылок между таблицами (опечатка в id ломает игру молча — здесь пишем warn)
------------------------------------------------------------------------
local function validate()
	local warnFn = warn or print
	local function check(ok, msg)
		if not ok then warnFn("[Config] " .. msg) end
	end
	local function sameSet(order, dict, what)
		local listed = {}
		for _, id in ipairs(order) do
			check(dict[id] ~= nil, what .. ": нет определения " .. tostring(id))
			listed[id] = true
		end
		for id in pairs(dict) do
			check(listed[id], what .. ": нет в порядке " .. tostring(id))
		end
	end
	sameSet(Config.RarityOrder, Config.Rarities, "Rarities")
	sameSet(Config.DifficultyOrder, Config.Difficulties, "Difficulties")
	sameSet(Config.EnemyOrder, Config.Enemies, "Enemies")
	sameSet(Config.RuneOrder, Config.Runes, "Runes")
	sameSet(Config.AllyOrder, Config.Allies, "Allies")

	for id, def in pairs(Config.Units) do
		check(Config.Rarities[def.Rarity] ~= nil, "юнит " .. id .. ": неизвестная редкость " .. tostring(def.Rarity))
		check(type(def.Levels) == "table" and #def.Levels >= 1, "юнит " .. id .. ": нет Levels")
		local summon = def.Summon
		if summon then
			for _, lv in ipairs(summon.Levels) do
				check(Config.Allies[lv.Ally] ~= nil, "юнит " .. id .. ": неизвестный союзник " .. tostring(lv.Ally))
			end
			check(not summon.Golden or Config.Allies[summon.Golden.Ally] ~= nil, "юнит " .. id .. ": неизвестный Golden")
		end
	end
	for _, list in ipairs({ Config.Settings.StarterUnits, Config.Settings.StudioGrantUnits }) do
		for _, id in ipairs(list) do
			check(Config.Units[id] ~= nil, "Settings: неизвестный юнит " .. tostring(id))
		end
	end
	for _, d in ipairs(Config.Halloween.Difficulties) do
		check(Config.Difficulties[d] ~= nil, "Halloween: неизвестная сложность " .. tostring(d))
	end
	for _, rune in pairs(Config.Runes) do
		for _, lv in ipairs(rune.Summon and rune.Summon.Levels or {}) do
			check(Config.Allies[lv.Ally] ~= nil, "руна: неизвестный союзник " .. tostring(lv.Ally))
		end
	end

	for key, case in pairs(Config.Cases) do
		local inUnits = {}
		for _, id in ipairs(case.Units) do
			check(Config.Units[id] ~= nil, "кейс " .. key .. ": неизвестный юнит " .. tostring(id))
			inUnits[id] = true
		end
		if case.Rewards then
			local inRewards = {}
			for _, r in ipairs(case.Rewards) do
				if r.Rune then
					check(Config.Runes[r.Rune] ~= nil, "кейс " .. key .. ": неизвестная руна " .. tostring(r.Rune))
				else
					check(Config.Units[r.Unit] ~= nil, "кейс " .. key .. ": неизвестный юнит " .. tostring(r.Unit))
					check(inUnits[r.Unit], "кейс " .. key .. ": " .. tostring(r.Unit) .. " есть в Rewards, но не в Units")
					inRewards[r.Unit] = true
				end
			end
			for id in pairs(inUnits) do
				check(inRewards[id], "кейс " .. key .. ": " .. id .. " показан, но не выпадает (нет в Rewards)")
			end
		end
	end
	for _, key in ipairs(Config.CaseOrder) do
		check(Config.Cases[key] ~= nil, "CaseOrder: неизвестный кейс " .. tostring(key))
	end

	local function enemy(id, where)
		check(Config.Enemies[id] ~= nil, where .. ": неизвестный враг " .. tostring(id))
	end
	local function waves(list, where)
		for w, groups in ipairs(list) do
			for _, g in ipairs(groups) do
				if g[1] ~= "BOSS" then enemy(g[1], where .. " волна " .. w) end
			end
		end
	end
	waves(Config.Waves, "Waves")
	for key, map in pairs(Config.Maps) do
		check(type(map.Path) == "table" and #map.Path >= 2, "карта " .. key .. ": в дороге меньше 2 точек")
		if map.Waves then waves(map.Waves, "Maps." .. key) end
	end
	for _, id in pairs(Config.Halloween.Bosses) do
		enemy(id, "Halloween.Bosses")
	end
	for id, def in pairs(Config.Enemies) do
		if def.Summon then enemy(def.Summon.Enemy, id .. ".Summon") end
		if def.OnDeath then enemy(def.OnDeath.Enemy, id .. ".OnDeath") end
		if def.Enrage and def.Enrage.Spawn then enemy(def.Enrage.Spawn[1], id .. ".Enrage") end
	end
end
validate()

------------------------------------------------------------------------
-- Утилиты
------------------------------------------------------------------------

-- Статы уровня юнита (уровень зажимается в 1..#Levels). nil — нет такого юнита.
function Config.GetUnitStats(unitId, level)
	local def = Config.Units[unitId]
	if not def then return nil end
	local lv = math.floor(tonumber(level) or 1)
	if lv ~= lv then lv = 1 end -- NaN
	return def.Levels[math.clamp(lv, 1, #def.Levels)]
end

-- Множитель HP врагов на волне: (1 + L*(w-1) + Q*(w-1)^2) * EnemyHealthMult
function Config.WaveHPMult(wave)
	local s = Config.Settings
	local w = math.max((tonumber(wave) or 1) - 1, 0)
	return (1 + s.EnemyHPScaleLinear * w + s.EnemyHPScaleQuad * w * w) * (s.EnemyHealthMult or 1)
end

-- 1234 -> "1,234"; 15000 -> "15.0K"; 1500000 -> "1.5M"; отрицательные — со знаком минус
function Config.FormatNumber(n)
	n = math.floor((tonumber(n) or 0) + 0.5)
	if n ~= n then return "0" end -- NaN
	if n < 0 then
		return "-" .. Config.FormatNumber(-n)
	end
	-- с 999 950 "%.1fK" дал бы "1000.0K" — сразу переходим на M
	if n >= 999950 then
		return string.format("%.1fM", n / 1e6)
	elseif n >= 1e4 then
		return string.format("%.1fK", n / 1e3)
	end
	local s = tostring(n)
	local formatted = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if formatted:sub(1, 1) == "," then formatted = formatted:sub(2) end
	return formatted
end

return Config
