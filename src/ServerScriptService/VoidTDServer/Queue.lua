--!nocheck
-- VOID TD :: Queue
-- Очередь Хэллоуин-матча на 4 светящихся квадратах острова (хост = первый, выбирает сложность),
-- отсчёт 15 с (СТАРТ хоста — 3 с), порталы лобби ↔ остров.
-- State: HQ_Members (DisplayName через \n), HQ_Ids (UserId через ","), HQ_Count, HQ_Host, HQ_Diff, HQ_At, HQ_Busy.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("VoidTD")
local Config = require(Shared:WaitForChild("Config"))

local Q = Config.HalloweenIsland.Queue
local CENTER = Config.HalloweenIsland.Center + Q.Offset
local HALF = Q.Pad / 2 + 0.4
local TICK = 0.25

local Queue = {}

local Match, State
local queue = {} -- игроки по порядку входа; queue[1] — хост
local difficulty = "Easy"
local countdownAt = 0 -- серверное время телепорта (0 — нет отсчёта)
local leftUntil = {} -- player -> true: вышел кнопкой, вернётся только сойдя с квадратов

local function now()
	return workspace:GetServerTimeNow()
end

local function onPad(player)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end
	local p = root.Position
	if math.abs(p.Y - CENTER.Y) > 9 then
		return false
	end
	for _, off in ipairs(Q.Pads) do
		local c = CENTER + off
		if math.abs(p.X - c.X) <= HALF and math.abs(p.Z - c.Z) <= HALF then
			return true
		end
	end
	return false
end

local function publish()
	local names, ids = {}, {}
	for i, pl in ipairs(queue) do
		names[i] = pl.DisplayName
		ids[i] = tostring(pl.UserId)
	end
	State:SetAttribute("HQ_Members", table.concat(names, "\n"))
	State:SetAttribute("HQ_Ids", table.concat(ids, ","))
	State:SetAttribute("HQ_Count", #queue)
	State:SetAttribute("HQ_Host", queue[1] and queue[1].UserId or 0)
	State:SetAttribute("HQ_Diff", difficulty)
	State:SetAttribute("HQ_At", countdownAt)
	State:SetAttribute("HQ_Busy", not Match.CanStartHalloween())
end

local function remove(player)
	local i = table.find(queue, player)
	if i then
		table.remove(queue, i)
		if i == 1 then
			difficulty = "Easy" -- новый хост выбирает заново
		end
	end
	return i ~= nil
end

local function tick()
	local t = now()
	for i = #queue, 1, -1 do
		local pl = queue[i]
		if not pl.Parent or pl:GetAttribute("InMatch") or not onPad(pl) then
			remove(pl)
		end
	end
	for _, pl in ipairs(Players:GetPlayers()) do
		if not table.find(queue, pl) and not pl:GetAttribute("InMatch") then
			local standing = onPad(pl)
			if leftUntil[pl] and not standing then
				leftUntil[pl] = nil
			end
			if standing and not leftUntil[pl] and #queue < Q.MaxPlayers then
				queue[#queue + 1] = pl
				Match.Toast(pl, "Ты в очереди Хэллоуин-матча (" .. #queue .. "/" .. Q.MaxPlayers .. ")", "good")
			end
		end
	end
	if #queue == 0 or not Match.CanStartHalloween() then
		countdownAt = 0
	elseif countdownAt == 0 then
		countdownAt = t + Q.Countdown
	elseif t >= countdownAt then
		local list, diff = table.clone(queue), difficulty
		queue, countdownAt, difficulty = {}, 0, "Easy"
		local ok, err = Match.StartHalloween(list, diff)
		if not ok then
			for _, pl in ipairs(list) do
				Match.Toast(pl, err or "Не удалось начать матч", "error")
			end
		end
	end
	publish()
end
Queue._tick = tick

function Queue._queue()
	return queue, difficulty, countdownAt
end

function Queue.SetDifficulty(player, diff)
	if queue[1] ~= player then
		return false, "Сложность выбирает хост (первый в очереди)"
	end
	if type(diff) ~= "string" or not table.find(Config.Halloween.Difficulties, diff) then
		return false, "Неверная сложность"
	end
	difficulty = diff
	publish()
	return true
end

function Queue.StartNow(player)
	if queue[1] ~= player then
		return false, "Начать может только хост"
	end
	if countdownAt == 0 then
		return false, "Арена занята — подожди окончания матча"
	end
	countdownAt = math.min(countdownAt, now() + Q.StartNow)
	publish()
	return true
end

-- silent = игрок уходит с сервера: только убрать из очереди
function Queue.Leave(player, silent)
	if silent then
		remove(player)
		leftUntil[player] = nil
		if State then
			publish()
		end
		return true
	end
	if not remove(player) then
		return false, "Ты не в очереди"
	end
	leftUntil[player] = true
	Match.Teleport(player, CENTER + Vector3.new(0, 0, 16))
	publish()
	return true
end

-- портал лобби ↔ остров (сервер проверяет, что игрок рядом с порталом)
function Queue.Teleport(player, where)
	if player:GetAttribute("InMatch") then
		return false, "Сначала выйди из матча"
	end
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then
		return false, "Персонаж не загружен"
	end
	local zone, center
	if where == "Halloween" then
		zone, center = Config.Lobby.Zones.HalloweenPortal, Config.Lobby.Center
	elseif where == "Lobby" then
		zone, center = Config.HalloweenIsland.Zones.ReturnPortal, Config.HalloweenIsland.Center
	else
		return false, "Неверный портал"
	end
	local p, c = root.Position, center + zone.Offset
	local d = Vector2.new(p.X - c.X, p.Z - c.Z).Magnitude
	if d > zone.Radius + 8 then
		return false, "Подойди к порталу"
	end
	Match.ToLobby(player, where == "Halloween")
	return true
end

function Queue.Init(match, state)
	Match, State = match, state
	publish()
	task.spawn(function()
		while true do
			task.wait(TICK)
			local ok, err = pcall(tick)
			if not ok then
				warn("[VOID TD] Queue: " .. tostring(err))
			end
		end
	end)
end

return Queue
