--!nocheck
-- VOID TD :: Economy
-- Деньги матча (атрибут игрока Money + leaderstats.Money) и раздача наград всем участникам матча.
-- Награды не делятся: каждый игрок в матче получает полную сумму.

local Players = game:GetService("Players")

local Economy = {}

local Data

function Economy.Init(ctx)
	Data = ctx.Data
end

function Economy.Get(player)
	return player:GetAttribute("Money") or 0
end

function Economy.Set(player, amount)
	amount = tonumber(amount) or 0
	if amount ~= amount then
		amount = 0
	end
	amount = math.max(0, math.floor(amount))
	player:SetAttribute("Money", amount)
	local ls = player:FindFirstChild("leaderstats")
	local v = ls and ls:FindFirstChild("Money")
	if v then
		v.Value = amount
	end
	return amount
end

function Economy.Add(player, amount)
	return Economy.Set(player, Economy.Get(player) + amount)
end

-- можно ли списать
function Economy.Has(player, amount)
	return Economy.Get(player) >= amount
end

function Economy.InMatch(player)
	return player:GetAttribute("InMatch") == true
end

function Economy.MatchPlayers()
	local list = {}
	for _, pl in ipairs(Players:GetPlayers()) do
		if Economy.InMatch(pl) then
			list[#list + 1] = pl
		end
	end
	return list
end

function Economy.AddAll(amount)
	for _, pl in ipairs(Economy.MatchPlayers()) do
		Economy.Add(pl, amount)
	end
end

-- кристаллы всем в матче с множителем сложности; возвращает итоговое (округлённое) число
function Economy.AddGemsAll(base, gemsMult)
	local amount = math.floor(base * (gemsMult or 1) + 0.5)
	for _, pl in ipairs(Economy.MatchPlayers()) do
		Data.AddGems(pl, amount)
	end
	return amount
end

return Economy
