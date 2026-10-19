--!nocheck
-- VOID TD :: DataService
-- Профиль игрока: гемы, инвентарь юнитов, экипировка. DataStore с безопасным фолбэком для Studio.

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("VoidTD"):WaitForChild("Config"))

local DataService = {}
DataService.Profiles = {}

local store
local storeOk = pcall(function()
	store = DataStoreService:GetDataStore(Config.Settings.DataStoreName)
end)
if not storeOk then
	store = nil
end

local function deepCopy(t)
	local c = {}
	for k, v in pairs(t) do
		c[k] = type(v) == "table" and deepCopy(v) or v
	end
	return c
end

local function defaultProfile()
	local s = Config.Settings
	local p = {
		Gems = s.StartGems,
		Inventory = {},
		Equipped = {},
		Stats = { Wins = 0, BestWave = 0, Summons = 0 },
		Settings = {},
		LastDaily = 0,
		Receipts = {},
		HalloweenCoins = 0,
		Runes = {},       -- RuneId -> количество
		RuneSlots = {},   -- UnitId -> RuneId (1 руна на юнита)
	}
	for i, id in ipairs(s.StarterUnits) do
		p.Inventory[id] = 1
		p.Equipped[i] = id
	end
	return p
end

local function sanitize(p)
	local d = defaultProfile()
	if type(p) ~= "table" then
		return d
	end
	p.Gems = tonumber(p.Gems) or d.Gems
	p.Inventory = type(p.Inventory) == "table" and p.Inventory or d.Inventory
	p.Equipped = type(p.Equipped) == "table" and p.Equipped or d.Equipped
	p.Stats = type(p.Stats) == "table" and p.Stats or d.Stats
	p.Settings = type(p.Settings) == "table" and p.Settings or {}
	p.LastDaily = tonumber(p.LastDaily) or 0
	p.Receipts = type(p.Receipts) == "table" and p.Receipts or {}
	p.HalloweenCoins = math.max(0, math.floor(tonumber(p.HalloweenCoins) or 0))
	-- руны: только известные, слоты — только у своих юнитов и не больше, чем рун есть
	local runes = {}
	if type(p.Runes) == "table" then
		for id, n in pairs(p.Runes) do
			n = math.floor(tonumber(n) or 0)
			if Config.Runes[id] and n > 0 then
				runes[id] = n
			end
		end
	end
	p.Runes = runes
	local slots, used = {}, {}
	if type(p.RuneSlots) == "table" then
		for unitId, runeId in pairs(p.RuneSlots) do
			if Config.Units[unitId] and (p.Inventory[unitId] or 0) > 0 and runes[runeId] and (used[runeId] or 0) < runes[runeId] then
				slots[unitId] = runeId
				used[runeId] = (used[runeId] or 0) + 1
			end
		end
	end
	p.RuneSlots = slots
	-- убрать неизвестные юниты
	for id in pairs(p.Inventory) do
		if not Config.Units[id] then
			p.Inventory[id] = nil
		end
	end
	local eq = {}
	for i = 1, Config.Settings.EquipSlots do
		local id = p.Equipped[i] or p.Equipped[tostring(i)]
		if id and Config.Units[id] and (p.Inventory[id] or 0) > 0 then
			eq[i] = id
		end
	end
	p.Equipped = eq
	return p
end

function DataService.Load(player)
	local profile
	if store then
		local ok, result = pcall(function()
			return store:GetAsync("u_" .. player.UserId)
		end)
		if ok then
			profile = result
		else
			warn("[VOID TD] DataStore недоступен (в Studio включи API Services). Используются данные по умолчанию.")
		end
	end
	profile = sanitize(profile and deepCopy(profile) or nil)
	-- проверка в Studio: секретные юниты из настроек сразу в инвентаре
	if RunService:IsStudio() then
		for _, id in ipairs(Config.Settings.StudioGrantUnits or {}) do
			if Config.Units[id] and (profile.Inventory[id] or 0) == 0 then
				profile.Inventory[id] = 1
			end
		end
	end
	DataService.Profiles[player] = profile
	player:SetAttribute("Gems", profile.Gems)
	player:SetAttribute("HalloweenCoins", profile.HalloweenCoins)
	return profile
end

function DataService.Get(player)
	return DataService.Profiles[player]
end

local lastSave = {}
function DataService.Save(player, force)
	local profile = DataService.Profiles[player]
	if not profile or not store then
		return
	end
	local now = os.clock()
	if not force and lastSave[player] and now - lastSave[player] < 8 then
		return
	end
	lastSave[player] = now
	local data = deepCopy(profile)
	-- ключи экипировки -> строки для JSON
	local eq = {}
	for i, id in pairs(data.Equipped) do
		eq[tostring(i)] = id
	end
	data.Equipped = eq
	task.spawn(function()
		local ok, err = pcall(function()
			store:SetAsync("u_" .. player.UserId, data)
		end)
		if not ok and not RunService:IsStudio() then
			warn("[VOID TD] Ошибка сохранения: " .. tostring(err))
		end
	end)
end

function DataService.Release(player)
	DataService.Save(player, true)
	DataService.Profiles[player] = nil
	lastSave[player] = nil
end

function DataService.AddGems(player, amount)
	local p = DataService.Profiles[player]
	if not p then
		return
	end
	p.Gems = math.max(0, p.Gems + amount)
	player:SetAttribute("Gems", p.Gems)
end

-- Публичная версия профиля для клиента
function DataService.Snapshot(player)
	local p = DataService.Profiles[player]
	if not p then
		return nil
	end
	-- ключи экипировки строками: разреженные массивы плохо переживают RemoteEvent
	local eq = {}
	for i, id in pairs(p.Equipped) do
		eq[tostring(i)] = id
	end
	return {
		Gems = p.Gems,
		Inventory = deepCopy(p.Inventory),
		Equipped = eq,
		Stats = deepCopy(p.Stats),
		Settings = deepCopy(p.Settings or {}),
		DailyReadyAt = (tonumber(p.LastDaily) or 0) + Config.Settings.DailyCooldown,
		HalloweenCoins = p.HalloweenCoins or 0,
		Runes = deepCopy(p.Runes or {}),
		RuneSlots = deepCopy(p.RuneSlots or {}),
	}
end

function DataService.AddCurrency(player, currency, amount)
	local p = DataService.Profiles[player]
	if not p then
		return
	end
	if currency == "Gems" then
		DataService.AddGems(player, amount)
		return
	end
	p[currency] = math.max(0, (p[currency] or 0) + math.floor(amount))
	player:SetAttribute(currency, p[currency])
end

------------------------------------------------------------------------
-- РУНЫ: 1 руна на юнита, снимается и переносится на другого, работает только надетой
------------------------------------------------------------------------
function DataService.GetRune(player, unitId)
	local p = DataService.Profiles[player]
	return p and p.RuneSlots and p.RuneSlots[unitId] or nil
end

local function runesUsed(p, runeId, exceptUnit)
	local n = 0
	for unitId, r in pairs(p.RuneSlots) do
		if r == runeId and unitId ~= exceptUnit then
			n = n + 1
		end
	end
	return n
end

-- runeId = nil — снять руну с юнита
function DataService.EquipRune(player, unitId, runeId)
	local p = DataService.Profiles[player]
	if not p then
		return false, "Профиль не загружен"
	end
	if not Config.Units[unitId] or (p.Inventory[unitId] or 0) <= 0 then
		return false, "Юнита нет в инвентаре"
	end
	if runeId == nil then
		p.RuneSlots[unitId] = nil
		DataService.Save(player)
		return true
	end
	if not Config.Runes[runeId] then
		return false, "Неизвестная руна"
	end
	if runesUsed(p, runeId, unitId) >= (p.Runes[runeId] or 0) then
		return false, "Все такие руны уже надеты — сними руну с другого юнита"
	end
	p.RuneSlots[unitId] = runeId
	DataService.Save(player)
	return true
end

------------------------------------------------------------------------
-- КЕЙСЫ (SUMMON)
------------------------------------------------------------------------
local rng = Random.new()

local function unitsByRarity(case)
	local map = {}
	for _, id in ipairs(case.Units) do
		local r = Config.Units[id].Rarity
		map[r] = map[r] or {}
		table.insert(map[r], id)
	end
	return map
end

-- редкость есть в розыгрыше, если в ней есть юниты без отдельного шанса (UnitRates)
local function rollable(pool, name, unitRates)
	for _, id in ipairs(pool[name] or {}) do
		if not (unitRates and unitRates[id]) then
			return true
		end
	end
	return false
end

local function rollRarity(case, pool, unitRates)
	local total = 0
	for _, name in ipairs(Config.RarityOrder) do
		if rollable(pool, name, unitRates) then
			total = total + (case.Rates[name] or 0)
		end
	end
	local roll = rng:NextNumber() * total
	local acc = 0
	for _, name in ipairs(Config.RarityOrder) do
		if rollable(pool, name, unitRates) then
			acc = acc + (case.Rates[name] or 0)
			if roll <= acc then
				return name
			end
		end
	end
	return "Common"
end

function DataService.Summon(player, caseId, count)
	local p = DataService.Profiles[player]
	if not p then
		return false, "Профиль не загружен"
	end
	local case = Config.Cases[caseId]
	if not case then
		return false, "Неизвестный кейс"
	end
	if case.Enabled == false then
		return false, "Кейс пока недоступен"
	end
	local s = Config.Settings
	count = (count == 10) and 10 or 1
	if case.Single and count ~= 1 then
		return false, "Этот кейс открывается по одному"
	end
	local cost = (count == 10) and case.Cost10 or case.Cost1
	if not cost then
		return false, "Неверный запрос"
	end
	local currency = case.Currency or "Gems"
	if (p[currency] or 0) < cost then
		return false, currency == "Gems" and "Недостаточно кристаллов" or "Недостаточно Halloween Coins"
	end
	p[currency] = p[currency] - cost
	if currency == "Gems" then
		player:SetAttribute("Gems", p.Gems)
	end
	-- кейс с полным списком наград (юниты и руны): один бросок на открытие
	if case.Rewards then
		local total = 0
		for _, r in ipairs(case.Rewards) do
			total = total + r.Rate
		end
		local roll, acc, pick = rng:NextNumber() * total, 0, case.Rewards[#case.Rewards]
		for _, r in ipairs(case.Rewards) do
			acc = acc + r.Rate
			if roll < acc then
				pick = r
				break
			end
		end
		local result
		if pick.Rune then
			local isNew = (p.Runes[pick.Rune] or 0) == 0
			p.Runes[pick.Rune] = (p.Runes[pick.Rune] or 0) + 1
			result = { Rune = pick.Rune, New = isNew }
		else
			local id = pick.Unit
			local isNew = (p.Inventory[id] or 0) == 0
			p.Inventory[id] = (p.Inventory[id] or 0) + 1
			result = { Id = id, New = isNew }
			if isNew then
				for slot = 1, s.EquipSlots do
					if not p.Equipped[slot] then
						p.Equipped[slot] = id
						break
					end
				end
			end
		end
		if currency ~= "Gems" then
			player:SetAttribute(currency, p[currency])
		end
		p.Stats.Summons = (p.Stats.Summons or 0) + 1
		DataService.Save(player, true)
		return true, { result }
	end
	local pool = unitsByRarity(case)
	local results = {}
	local bestOrder = 0
	for i = 1, count do
		-- отдельный шанс конкретных юнитов (UnitRates, в процентах), иначе — по редкостям
		local fixed
		if case.UnitRates then
			local roll, acc = rng:NextNumber() * 100, 0
			for id, rate in pairs(case.UnitRates) do
				acc = acc + rate
				if roll < acc then
					fixed = id
					break
				end
			end
		end
		local rarity = fixed and Config.Units[fixed].Rarity or rollRarity(case, pool, case.UnitRates)
		-- гарантия: в x10 минимум один Rare+
		if count == 10 and i == 10 and bestOrder < 2 and not fixed and rollable(pool, "Rare", case.UnitRates) then
			rarity = "Rare"
		end
		bestOrder = math.max(bestOrder, Config.Rarities[rarity].Order)
		local id = fixed
		if not id then
			local list = {}
			for _, u in ipairs(pool[rarity]) do
				if not (case.UnitRates and case.UnitRates[u]) then
					list[#list + 1] = u
				end
			end
			id = list[rng:NextInteger(1, #list)]
		end
		local isNew = (p.Inventory[id] or 0) == 0
		p.Inventory[id] = (p.Inventory[id] or 0) + 1
		results[i] = { Id = id, New = isNew }
		if isNew then
			for slot = 1, s.EquipSlots do
				if not p.Equipped[slot] then
					p.Equipped[slot] = id
					break
				end
			end
		end
	end
	p.Stats.Summons = (p.Stats.Summons or 0) + count
	DataService.Save(player)
	return true, results
end

------------------------------------------------------------------------
-- МАГАЗИН
------------------------------------------------------------------------
function DataService.ClaimDaily(player)
	local p = DataService.Profiles[player]
	if not p then
		return false, "Профиль не загружен"
	end
	local now = os.time()
	local last = tonumber(p.LastDaily) or 0
	local left = (last + Config.Settings.DailyCooldown) - now
	if left > 0 then
		return false, string.format("Подарок будет через %d ч %d мин", left // 3600, (left % 3600) // 60)
	end
	p.LastDaily = now
	DataService.AddGems(player, Config.Settings.DailyGems)
	DataService.Save(player, true)
	return true, Config.Settings.DailyGems
end

-- Выдача кристаллов за покупку. receiptId защищает от повторной выдачи.
function DataService.GrantPurchase(player, gems, receiptId)
	local p = DataService.Profiles[player]
	if not p then
		return false
	end
	p.Receipts = p.Receipts or {}
	if receiptId and p.Receipts[receiptId] then
		return true
	end
	if receiptId then
		p.Receipts[receiptId] = true
	end
	DataService.AddGems(player, gems)
	DataService.Save(player, true)
	return true
end

function DataService.Equip(player, unitId, slot)
	local p = DataService.Profiles[player]
	if not p then
		return false, "Профиль не загружен"
	end
	slot = tonumber(slot)
	if not slot or slot < 1 or slot > Config.Settings.EquipSlots or slot ~= math.floor(slot) then
		return false, "Неверный слот"
	end
	if unitId == nil then
		p.Equipped[slot] = nil
		return true
	end
	if not Config.Units[unitId] or (p.Inventory[unitId] or 0) <= 0 then
		return false, "Юнита нет в инвентаре"
	end
	for i = 1, Config.Settings.EquipSlots do
		if p.Equipped[i] == unitId then
			p.Equipped[i] = nil
		end
	end
	p.Equipped[slot] = unitId
	DataService.Save(player)
	return true
end

function DataService.IsEquipped(player, unitId)
	local p = DataService.Profiles[player]
	if not p then
		return false
	end
	for i = 1, Config.Settings.EquipSlots do
		if p.Equipped[i] == unitId then
			return true
		end
	end
	return false
end

return DataService
