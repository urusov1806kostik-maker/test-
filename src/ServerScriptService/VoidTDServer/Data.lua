--!nocheck
-- VOID TD :: Data
-- Профиль игрока: кристаллы, Halloween Coins, инвентарь юнитов, экипировка, руны, статистика.
-- DataStore с безопасным фолбэком: если загрузка не удалась, профиль работает в памяти и НЕ сохраняется
-- (иначе дефолт затёр бы настоящее сохранение). Сохранение — UpdateAsync, без потерь при троттлинге
-- (отложенная запись вместо пропуска), одна запись на игрока одновременно.
--
-- API: Load Get Save Release Snapshot AddGems AddCurrency Summon ClaimDaily GrantPurchase SaveNow
--      Equip IsEquipped GetRune EquipRune Flush(timeout)

local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("VoidTD")
local Config = require(Shared:WaitForChild("Config"))
local Util = require(Shared:WaitForChild("Util"))

local S = Config.Settings
local SAVE_THROTTLE = 8 -- с между обычными сохранениями
local LOAD_TRIES = 3
local MAX_RECEIPTS = 200 -- старые чеки обрезаются (лимит 4 МБ на ключ)

local Data = {}
Data.Profiles = {}

local meta = {} -- player -> { Last, Inflight, Dirty, Timer, NoSave, Studio = {id=true}, Profile }
local inflight = 0

local store
do
	local ok = pcall(function()
		store = DataStoreService:GetDataStore(S.DataStoreName)
	end)
	if not ok then
		store = nil
	end
end

local function key(player)
	return "u_" .. player.UserId
end

local deepCopy = Util.DeepCopy

local function isNum(n)
	return Util.IsFinite(n)
end

------------------------------------------------------------------------
-- ПРОФИЛЬ ПО УМОЛЧАНИЮ И ОЧИСТКА
------------------------------------------------------------------------
local function defaultProfile()
	local p = {
		Gems = S.StartGems,
		Inventory = {},
		Equipped = {},
		Stats = { Wins = 0, BestWave = 0, Summons = 0 },
		Settings = {},
		LastDaily = 0,
		Receipts = {},
		HalloweenCoins = 0,
		Runes = {},     -- RuneId -> количество
		RuneSlots = {}, -- UnitId -> RuneId (1 руна на тип юнита)
	}
	for i, id in ipairs(S.StarterUnits) do
		p.Inventory[id] = 1
		p.Equipped[i] = id
	end
	return p
end

local function count(n)
	n = tonumber(n)
	if not isNum(n) then
		return 0
	end
	return math.max(0, math.floor(n))
end

local function sortedKeys(t)
	local keys = {}
	for k in pairs(t) do
		if type(k) == "string" then
			keys[#keys + 1] = k
		end
	end
	table.sort(keys)
	return keys
end

local function sanitize(p)
	local d = defaultProfile()
	if type(p) ~= "table" then
		return d
	end
	local out = {}
	local gems = tonumber(p.Gems)
	out.Gems = isNum(gems) and math.max(0, math.floor(gems)) or d.Gems
	-- инвентарь: только известные юниты с числом > 0
	out.Inventory = {}
	if type(p.Inventory) == "table" then
		for id, n in pairs(p.Inventory) do
			if type(id) == "string" and Config.Units[id] and count(n) > 0 then
				out.Inventory[id] = count(n)
			end
		end
	end
	if next(out.Inventory) == nil then
		-- пустой инвентарь — стартовые юниты заново
		out.Inventory = d.Inventory
		p.Equipped = d.Equipped
	end
	local st = type(p.Stats) == "table" and p.Stats or {}
	out.Stats = { Wins = count(st.Wins), BestWave = count(st.BestWave), Summons = count(st.Summons) }
	out.Settings = {}
	if type(p.Settings) == "table" then
		for k, v in pairs(p.Settings) do
			if type(k) == "string" and (type(v) == "boolean" or isNum(v) or type(v) == "string") then
				out.Settings[k] = v
			end
		end
	end
	local ld = tonumber(p.LastDaily)
	out.LastDaily = isNum(ld) and ld or 0
	out.Receipts = {}
	if type(p.Receipts) == "table" then
		for k, v in pairs(p.Receipts) do
			if type(k) == "string" and v then
				out.Receipts[k] = true
			end
		end
	end
	out.HalloweenCoins = count(p.HalloweenCoins)
	-- руны: только известные; слоты — только у своих юнитов и не больше, чем рун есть (порядок детерминирован)
	out.Runes = {}
	if type(p.Runes) == "table" then
		for id, n in pairs(p.Runes) do
			if type(id) == "string" and Config.Runes[id] and count(n) > 0 then
				out.Runes[id] = count(n)
			end
		end
	end
	out.RuneSlots = {}
	if type(p.RuneSlots) == "table" then
		local used = {}
		for _, unitId in ipairs(sortedKeys(p.RuneSlots)) do
			local runeId = p.RuneSlots[unitId]
			if out.Inventory[unitId] and type(runeId) == "string" and out.Runes[runeId] and (used[runeId] or 0) < out.Runes[runeId] then
				out.RuneSlots[unitId] = runeId
				used[runeId] = (used[runeId] or 0) + 1
			end
		end
	end
	-- экипировка: читаем и числовые, и строковые (JSON) ключи; дубли выкидываем
	out.Equipped = {}
	local eq = type(p.Equipped) == "table" and p.Equipped or {}
	local seen = {}
	for i = 1, S.EquipSlots do
		local id = eq[i] or eq[tostring(i)]
		if type(id) == "string" and out.Inventory[id] and not seen[id] then
			out.Equipped[i] = id
			seen[id] = true
		end
	end
	return out
end

------------------------------------------------------------------------
-- ЗАГРУЗКА / СОХРАНЕНИЕ
------------------------------------------------------------------------
function Data.Load(player)
	local raw, failed = nil, false
	if store then
		failed = true
		for attempt = 1, LOAD_TRIES do
			local ok, result = pcall(function()
				return store:GetAsync(key(player))
			end)
			if ok then
				raw, failed = result, false
				break
			end
			if attempt < LOAD_TRIES then
				task.wait(1)
			end
		end
		if failed then
			warn("[VOID TD] DataStore недоступен (в Studio включи API Services). Используются данные по умолчанию.")
		end
	end
	-- игрок ушёл, пока грузился профиль — ничего не создаём
	if not player.Parent then
		return nil
	end
	local profile = sanitize(type(raw) == "table" and deepCopy(raw) or nil)
	local m = { Last = 0, NoSave = failed, Studio = {}, Profile = profile }
	-- Studio: тестовые юниты в инвентаре (в сохранение не попадают)
	if RunService:IsStudio() then
		for _, id in ipairs(S.StudioGrantUnits or {}) do
			if Config.Units[id] and (profile.Inventory[id] or 0) == 0 then
				profile.Inventory[id] = 1
				m.Studio[id] = true
			end
		end
	end
	meta[player] = m
	Data.Profiles[player] = profile
	player:SetAttribute("Gems", profile.Gems)
	player:SetAttribute("HalloweenCoins", profile.HalloweenCoins)
	return profile
end

function Data.Get(player)
	return Data.Profiles[player]
end

-- копия для DataStore: ключи экипировки строками, без студийных выдач, чеков не больше MAX_RECEIPTS
local function serialize(profile, m)
	local data = deepCopy(profile)
	for id in pairs(m.Studio) do
		local n = (data.Inventory[id] or 0) - 1
		if n <= 0 then
			data.Inventory[id] = nil
			data.RuneSlots[id] = nil
			for i = 1, S.EquipSlots do
				if data.Equipped[i] == id then
					data.Equipped[i] = nil
				end
			end
		else
			data.Inventory[id] = n
		end
	end
	local eq = {}
	for i, id in pairs(data.Equipped) do
		eq[tostring(i)] = id
	end
	data.Equipped = eq
	local ids = sortedKeys(data.Receipts)
	if #ids > MAX_RECEIPTS then
		for i = 1, #ids - MAX_RECEIPTS do
			data.Receipts[ids[i]] = nil
		end
	end
	return data
end

local function writeNow(player, m)
	local data = serialize(m.Profile, m)
	local ok, err = pcall(function()
		store:UpdateAsync(key(player), function()
			return data
		end)
	end)
	if not ok and not RunService:IsStudio() then
		warn("[VOID TD] Ошибка сохранения: " .. tostring(err))
	end
	return ok
end

local function write(player, m)
	m.Inflight = true
	m.Last = os.clock()
	inflight += 1
	task.spawn(function()
		writeNow(player, m)
		inflight -= 1
		m.Inflight = false
		if m.Dirty then
			m.Dirty = false
			write(player, m)
		end
	end)
end

-- force = true — сразу (с очередью, если запись уже идёт); иначе не чаще раза в 8 с, лишнее откладывается
function Data.Save(player, force)
	local m = meta[player]
	if not m or not store or m.NoSave then
		return
	end
	if m.Inflight then
		m.Dirty = true
		return
	end
	local since = os.clock() - m.Last
	if not force and since < SAVE_THROTTLE then
		if not m.Timer then
			m.Timer = true
			task.delay(SAVE_THROTTLE - since, function()
				m.Timer = false
				if meta[player] == m then
					Data.Save(player, true)
				end
			end)
		end
		return
	end
	write(player, m)
end

-- синхронная запись (покупки): true — данные в DataStore (или DataStore не используется)
function Data.SaveNow(player)
	local m = meta[player]
	if not m then
		return false
	end
	if not store then
		return true
	end
	if m.NoSave then
		return false
	end
	m.Last = os.clock()
	return writeNow(player, m)
end

function Data.Release(player)
	Data.Save(player, true)
	Data.Profiles[player] = nil
	meta[player] = nil
end

-- дождаться всех записей (BindToClose)
function Data.Flush(timeout)
	local t0 = os.clock()
	while inflight > 0 and os.clock() - t0 < (timeout or 25) do
		task.wait(0.1)
	end
end

------------------------------------------------------------------------
-- ВАЛЮТЫ
------------------------------------------------------------------------
function Data.AddGems(player, amount)
	local p = Data.Profiles[player]
	if not p or not isNum(amount) then
		return
	end
	p.Gems = math.max(0, math.floor(p.Gems + amount))
	player:SetAttribute("Gems", p.Gems)
end

function Data.AddCurrency(player, currency, amount)
	local p = Data.Profiles[player]
	if not p or not isNum(amount) then
		return
	end
	if currency == "Gems" then
		Data.AddGems(player, amount)
		return
	end
	p[currency] = math.max(0, (p[currency] or 0) + math.floor(amount))
	player:SetAttribute(currency, p[currency])
end

-- Публичная версия профиля для клиента
function Data.Snapshot(player)
	local p = Data.Profiles[player]
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
		Settings = deepCopy(p.Settings),
		DailyReadyAt = (tonumber(p.LastDaily) or 0) + S.DailyCooldown,
		HalloweenCoins = p.HalloweenCoins or 0,
		Runes = deepCopy(p.Runes),
		RuneSlots = deepCopy(p.RuneSlots),
	}
end

------------------------------------------------------------------------
-- ЭКИПИРОВКА
------------------------------------------------------------------------
local function owns(p, unitId)
	return type(unitId) == "string" and Config.Units[unitId] ~= nil and (p.Inventory[unitId] or 0) > 0
end

local function autoEquip(p, id)
	for slot = 1, S.EquipSlots do
		if not p.Equipped[slot] then
			p.Equipped[slot] = id
			return
		end
	end
end

function Data.Equip(player, unitId, slot)
	local p = Data.Profiles[player]
	if not p then
		return false, "Профиль не загружен"
	end
	slot = tonumber(slot)
	if not Util.IsIntInRange(slot, 1, S.EquipSlots) then
		return false, "Неверный слот"
	end
	if unitId == nil then
		p.Equipped[slot] = nil
		Data.Save(player)
		return true
	end
	if not owns(p, unitId) then
		return false, "Юнита нет в инвентаре"
	end
	for i = 1, S.EquipSlots do
		if p.Equipped[i] == unitId then
			p.Equipped[i] = nil
		end
	end
	p.Equipped[slot] = unitId
	Data.Save(player)
	return true
end

function Data.IsEquipped(player, unitId)
	local p = Data.Profiles[player]
	if not p then
		return false
	end
	for i = 1, S.EquipSlots do
		if p.Equipped[i] == unitId then
			return true
		end
	end
	return false
end

------------------------------------------------------------------------
-- РУНЫ: 1 руна на юнита, снимается и переносится на другого, работает только надетой
------------------------------------------------------------------------
function Data.GetRune(player, unitId)
	local p = Data.Profiles[player]
	return p and p.RuneSlots[unitId] or nil
end

local function runesUsed(p, runeId, exceptUnit)
	local n = 0
	for unitId, r in pairs(p.RuneSlots) do
		if r == runeId and unitId ~= exceptUnit then
			n += 1
		end
	end
	return n
end

-- runeId = nil — снять руну с юнита
function Data.EquipRune(player, unitId, runeId)
	local p = Data.Profiles[player]
	if not p then
		return false, "Профиль не загружен"
	end
	if not owns(p, unitId) then
		return false, "Юнита нет в инвентаре"
	end
	if runeId == nil then
		p.RuneSlots[unitId] = nil
		Data.Save(player)
		return true
	end
	if type(runeId) ~= "string" or not Config.Runes[runeId] then
		return false, "Неизвестная руна"
	end
	if runesUsed(p, runeId, unitId) >= (p.Runes[runeId] or 0) then
		return false, "Все такие руны уже надеты — сними руну с другого юнита"
	end
	p.RuneSlots[unitId] = runeId
	Data.Save(player)
	return true
end

------------------------------------------------------------------------
-- КЕЙСЫ (SUMMON)
------------------------------------------------------------------------
local rng = Random.new()

local function unitsByRarity(case)
	local map = {}
	for _, id in ipairs(case.Units or {}) do
		local def = Config.Units[id]
		if def then
			map[def.Rarity] = map[def.Rarity] or {}
			table.insert(map[def.Rarity], id)
		end
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
			total += case.Rates[name] or 0
		end
	end
	local roll = rng:NextNumber() * total
	local acc, last = 0, nil
	for _, name in ipairs(Config.RarityOrder) do
		if rollable(pool, name, unitRates) then
			acc += case.Rates[name] or 0
			last = name
			if roll <= acc then
				return name
			end
		end
	end
	return last or "Common"
end

local function rollFixed(case)
	if not case.UnitRates then
		return nil
	end
	local roll, acc = rng:NextNumber() * 100, 0
	for _, id in ipairs(sortedKeys(case.UnitRates)) do
		acc += case.UnitRates[id]
		if roll < acc then
			return id
		end
	end
	return nil
end

-- кейс с полным списком наград (юниты и руны): один бросок на открытие
local function rollReward(p, case)
	local pick = Util.WeightedPick(case.Rewards, "Rate", rng:NextNumber())
	if pick.Rune then
		local isNew = (p.Runes[pick.Rune] or 0) == 0
		p.Runes[pick.Rune] = (p.Runes[pick.Rune] or 0) + 1
		return { Rune = pick.Rune, New = isNew }
	end
	local id = pick.Unit
	local isNew = (p.Inventory[id] or 0) == 0
	p.Inventory[id] = (p.Inventory[id] or 0) + 1
	if isNew then
		autoEquip(p, id)
	end
	return { Id = id, New = isNew }
end

-- проверка кейса до списания: награды существуют
local function caseValid(case)
	if case.Rewards then
		if #case.Rewards == 0 then
			return false
		end
		for _, r in ipairs(case.Rewards) do
			if not ((r.Rune and Config.Runes[r.Rune]) or (r.Unit and Config.Units[r.Unit])) then
				return false
			end
		end
		return true
	end
	local pool = unitsByRarity(case)
	for _, name in ipairs(Config.RarityOrder) do
		if (case.Rates[name] or 0) > 0 and rollable(pool, name, case.UnitRates) then
			return true
		end
	end
	return false
end

function Data.Summon(player, caseId, n)
	local p = Data.Profiles[player]
	if not p then
		return false, "Профиль не загружен"
	end
	local case = type(caseId) == "string" and Config.Cases[caseId]
	if not case then
		return false, "Неизвестный кейс"
	end
	if case.Enabled == false then
		return false, "Кейс пока недоступен"
	end
	local amount = (n == 10) and 10 or 1
	if case.Single and amount ~= 1 then
		return false, "Этот кейс открывается по одному"
	end
	local cost = (amount == 10) and case.Cost10 or case.Cost1
	if not cost or not caseValid(case) then
		return false, "Неверный запрос"
	end
	local currency = case.Currency or "Gems"
	if (p[currency] or 0) < cost then
		return false, currency == "Gems" and "Недостаточно кристаллов" or "Недостаточно Halloween Coins"
	end
	p[currency] = p[currency] - cost
	player:SetAttribute(currency, p[currency])

	if case.Rewards then
		local result = rollReward(p, case)
		p.Stats.Summons += 1
		Data.Save(player, true)
		return true, { result }
	end

	local pool = unitsByRarity(case)
	local results = {}
	local bestOrder = 0
	for i = 1, amount do
		-- отдельный шанс конкретных юнитов (UnitRates, в процентах), иначе — по редкостям
		local fixed = rollFixed(case)
		local rarity = fixed and Config.Units[fixed].Rarity or rollRarity(case, pool, case.UnitRates)
		-- гарантия: в x10 минимум один Rare+
		if amount == 10 and i == 10 and bestOrder < 2 and not fixed and rollable(pool, "Rare", case.UnitRates) then
			rarity = "Rare"
		end
		bestOrder = math.max(bestOrder, Config.Rarities[rarity].Order)
		local id = fixed
		if not id then
			local list = {}
			for _, u in ipairs(pool[rarity] or {}) do
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
			autoEquip(p, id)
		end
	end
	p.Stats.Summons += amount
	Data.Save(player)
	return true, results
end

------------------------------------------------------------------------
-- МАГАЗИН
------------------------------------------------------------------------
function Data.ClaimDaily(player)
	local p = Data.Profiles[player]
	if not p then
		return false, "Профиль не загружен"
	end
	local now = os.time()
	local left = (p.LastDaily + S.DailyCooldown) - now
	if left > 0 then
		return false, string.format("Подарок будет через %d ч %d мин", left // 3600, (left % 3600) // 60)
	end
	p.LastDaily = now
	Data.AddGems(player, S.DailyGems)
	Data.Save(player, true)
	return true, S.DailyGems
end

-- Выдача кристаллов за покупку. receiptId защищает от повторной выдачи.
-- Возвращает ok, already (чек уже был выдан). С receiptId запись синхронная: ok = данные сохранены.
function Data.GrantPurchase(player, gems, receiptId)
	local p = Data.Profiles[player]
	if not p then
		return false
	end
	if receiptId then
		receiptId = tostring(receiptId)
		if p.Receipts[receiptId] then
			return Data.SaveNow(player), true
		end
		p.Receipts[receiptId] = true
		Data.AddGems(player, gems)
		return Data.SaveNow(player), false
	end
	Data.AddGems(player, gems)
	Data.Save(player, true)
	return true, false
end

return Data
