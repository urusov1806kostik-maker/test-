--!nocheck
-- VOID TD :: Router
-- Обработчики Request(action, data) для всех Net.Actions: проверка аргументов, лимит 25 запросов/с,
-- pcall + текст ошибки (клиент показывает его тостом), покупки (ProcessReceipt), рассылка профиля.

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("VoidTD")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))

local Router = {}

local RATE = 25 -- запросов за окно 1 с
local PUSH_EVERY = 5

local Remotes, Data, Match, Sim, Queue
local budget = {} -- player -> { Start, Count }
local last = {} -- player -> { Gems, Coins } последнего отправленного профиля

local function allow(player)
	local now = os.clock()
	local b = budget[player]
	if not b or now - b.Start > 1 then
		budget[player] = { Start = now, Count = 1 }
		return true
	end
	b.Count += 1
	return b.Count <= RATE
end

function Router.PushProfile(player)
	local snap = Data.Snapshot(player)
	if snap then
		last[player] = { Gems = snap.Gems, Coins = snap.HalloweenCoins }
		Remotes.Profile:FireClient(player, snap)
	end
end

local function tbl(data)
	return type(data) == "table" and data or nil
end

-- uid: число или строка-число (клиент шлёт {Uid} или сам uid)
local function uidOf(data)
	local v = tbl(data) and data.Uid or data
	v = tonumber(v)
	if not v or v ~= v or v % 1 ~= 0 then
		return nil
	end
	return v
end

local function str(v, maxLen)
	return type(v) == "string" and #v <= (maxLen or 64) and v or nil
end

local function bad()
	return false, "Неверный запрос"
end

-- ok -> профиль клиенту
local function withPush(player, ok, res)
	if ok then
		Router.PushProfile(player)
	end
	return ok, res
end

local function shopItem(key)
	local found
	for _, it in ipairs(Config.Shop) do
		if it.Key == key then
			found = it -- как в legacy: берётся последний с этим ключом
		end
	end
	return found
end

local handlers = {}

function handlers.GetProfile(player)
	return true, Data.Snapshot(player)
end

function handlers.GetEnemies()
	return true, Sim.EnemySnapshot()
end

function handlers.Place(player, data)
	data = tbl(data)
	if not data or not str(data.Unit) or typeof(data.Position) ~= "Vector3" then
		return bad()
	end
	local ok, why = Match.CanPlace(player)
	if not ok then
		return false, why
	end
	return Sim.PlaceUnit(player, data.Unit, data.Position, data.Rotation)
end

function handlers.Upgrade(player, data)
	local uid = uidOf(data)
	if not uid then
		return bad()
	end
	return Sim.UpgradeUnit(player, uid)
end

function handlers.Sell(player, data)
	local uid = uidOf(data)
	if not uid then
		return bad()
	end
	return Sim.SellUnit(player, uid)
end

function handlers.SetTarget(player, data)
	data = tbl(data)
	local uid = data and uidOf(data)
	if not uid or not str(data.Mode) then
		return bad()
	end
	return Sim.SetTargetMode(player, uid, data.Mode)
end

function handlers.JoinMatch(player, data)
	return Match.JoinMatch(player, tbl(data) and str(data.Difficulty) or nil)
end

function handlers.LeaveMatch(player)
	return Match.LeaveMatch(player)
end

function handlers.GetMatchInfo()
	return true, Match.GetMatchInfo()
end

function handlers.SetLite(player, data)
	local prof = Data.Get(player)
	prof.Settings = prof.Settings or {}
	prof.Settings.Lite = (tbl(data) and data.On == true) or nil
	Data.Save(player)
	return true
end

function handlers.ClaimDaily(player)
	return withPush(player, Data.ClaimDaily(player))
end

function handlers.BuyGems(player, data)
	local item = tbl(data) and str(data.Key) and shopItem(data.Key)
	if not item then
		return false, "Неизвестный товар"
	end
	if (item.ProductId or 0) > 0 then
		MarketplaceService:PromptProductPurchase(player, item.ProductId)
		return true, "prompt"
	end
	if Config.Settings.ShopTestMode and RunService:IsStudio() then
		Data.GrantPurchase(player, item.Gems, nil)
		Router.PushProfile(player)
		return true, item.Gems
	end
	return false, "Товар не настроен: укажи ProductId в Config.Shop"
end

function handlers.StartWave(player)
	return Match.RequestStartWave(player)
end

function handlers.Summon(player, data)
	data = tbl(data)
	local count = (data and data.Count == 10) and 10 or 1
	local caseId = data and str(data.Case) or "VoidCase"
	return withPush(player, Data.Summon(player, caseId, count))
end

function handlers.Equip(player, data)
	data = tbl(data)
	if not data then
		return bad()
	end
	if data.Unit ~= nil and not str(data.Unit) then
		return bad()
	end
	return withPush(player, Data.Equip(player, data.Unit, data.Slot))
end

function handlers.EquipRune(player, data)
	data = tbl(data)
	if not data or not str(data.Unit) then
		return bad()
	end
	if data.Rune ~= nil and not str(data.Rune) then
		return bad() -- legacy молча снимал руну; теперь только явный nil снимает
	end
	return withPush(player, Data.EquipRune(player, data.Unit, data.Rune))
end

function handlers.Teleport(player, data)
	return Queue.Teleport(player, tbl(data) and str(data.To) or nil)
end

function handlers.QueueDifficulty(player, data)
	return Queue.SetDifficulty(player, tbl(data) and str(data.Difficulty) or nil)
end

function handlers.QueueStart(player)
	return Queue.StartNow(player)
end

function handlers.QueueLeave(player)
	return Queue.Leave(player)
end

Router.Handlers = handlers

local function dispatch(player, action, data)
	if not allow(player) then
		return false, "Слишком много запросов"
	end
	if not Data.Get(player) then
		return false, "Профиль ещё загружается"
	end
	local h = Net.IsAction(action) and handlers[action]
	if not h then
		return false, "Неизвестное действие"
	end
	local ok, a, b = pcall(h, player, data)
	if not ok then
		warn("[VOID TD] Ошибка обработки " .. tostring(action) .. ": " .. tostring(a))
		return false, "Ошибка сервера"
	end
	return a, b
end
Router.Dispatch = dispatch

-- покупка за Robux: выдаём только после сохранения в DataStore
local function processReceipt(info)
	local player = Players:GetPlayerByUserId(info.PlayerId)
	if not player or not Data.Get(player) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	for _, it in ipairs(Config.Shop) do
		if it.ProductId == info.ProductId then
			local saved, already = Data.GrantPurchase(player, it.Gems, info.PurchaseId)
			if not saved then
				return Enum.ProductPurchaseDecision.NotProcessedYet
			end
			if not already then
				Router.PushProfile(player)
				Remotes.Notify:FireClient(player, { Type = "Purchase", Gems = it.Gems })
			end
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
	end
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

function Router.PlayerRemoving(player)
	budget[player] = nil
	last[player] = nil
end

function Router.Init(ctx)
	Remotes, Data, Match, Sim, Queue = ctx.Remotes, ctx.Data, ctx.Match, ctx.Sim, ctx.Queue
	Remotes.Request.OnServerInvoke = dispatch
	MarketplaceService.ProcessReceipt = processReceipt
	-- кристаллы/монеты меняются наградами без явной рассылки — догоняем раз в 5 с
	task.spawn(function()
		while true do
			task.wait(PUSH_EVERY)
			for _, p in ipairs(Players:GetPlayers()) do
				local prof = Data.Get(p)
				local l = last[p]
				if prof and (not l or l.Gems ~= prof.Gems or l.Coins ~= prof.HalloweenCoins) then
					Router.PushProfile(p)
					Data.Save(p)
				end
			end
		end
	end)
end

return Router
