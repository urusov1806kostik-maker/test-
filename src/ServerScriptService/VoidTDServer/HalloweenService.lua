--!nocheck
-- VOID TD :: HalloweenService
-- Хэллоуин-остров: телепорты через порталы и очередь в Хэллоуин-матч на 4 светящихся квадратах.
-- Встал на квадрат — в очереди. Первый в очереди — хост: выбирает сложность и может ускорить старт.
-- После обратного отсчёта все из очереди попадают в один и тот же матч.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("VoidTD"):WaitForChild("Config"))

local HalloweenService = {}

local GameService, State
local Q = Config.HalloweenIsland.Queue
local queue = {}          -- игроки по порядку входа
local difficulty = "Easy"
local countdownAt = 0     -- серверное время телепорта (0 — отсчёт не идёт)
local leftUntil = {}      -- игрок нажал «Выйти»: не возвращаем в очередь, пока не сойдёт с квадрата

local function now()
	return workspace:GetServerTimeNow()
end

local function queueCenter()
	return Config.HalloweenIsland.Center + Q.Offset
end

-- стоит ли игрок на одном из квадратов
local function onPad(player)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end
	local c = queueCenter()
	local pos = root.Position
	if math.abs(pos.Y - c.Y) > 9 then
		return false
	end
	local half = Q.Pad / 2 + 0.4
	for _, off in ipairs(Q.Pads) do
		local p = c + off
		if math.abs(pos.X - p.X) <= half and math.abs(pos.Z - p.Z) <= half then
			return true
		end
	end
	return false
end

local function publish()
	local names = {}
	for _, pl in ipairs(queue) do
		names[#names + 1] = pl.DisplayName
	end
	State:SetAttribute("HQ_Members", table.concat(names, "\n"))
	State:SetAttribute("HQ_Count", #queue)
	State:SetAttribute("HQ_Host", queue[1] and queue[1].UserId or 0)
	State:SetAttribute("HQ_Diff", difficulty)
	State:SetAttribute("HQ_At", countdownAt)
	State:SetAttribute("HQ_Busy", not GameService.CanStartHalloween())
end

local function remove(player)
	local i = table.find(queue, player)
	if i then
		table.remove(queue, i)
		if i == 1 then
			difficulty = "Easy" -- новый хост выбирает заново
		end
	end
end

local function tick()
	local t = now()
	-- ушедшие с квадратов и вошедшие в матч выбывают
	for i = #queue, 1, -1 do
		local pl = queue[i]
		if not pl.Parent or pl:GetAttribute("InMatch") or not onPad(pl) then
			remove(pl)
		end
	end
	for _, pl in ipairs(Players:GetPlayers()) do
		if #queue >= Q.MaxPlayers then
			break
		end
		if not table.find(queue, pl) and not pl:GetAttribute("InMatch") then
			local standing = onPad(pl)
			if leftUntil[pl] and not standing then
				leftUntil[pl] = nil
			end
			if standing and not leftUntil[pl] then
				queue[#queue + 1] = pl
				GameService.Toast(pl, "Ты в очереди Хэллоуин-матча (" .. #queue .. "/" .. Q.MaxPlayers .. ")", "good")
			end
		end
	end
	if #queue == 0 or not GameService.CanStartHalloween() then
		countdownAt = 0
	elseif countdownAt == 0 then
		countdownAt = t + Q.Countdown
	elseif t >= countdownAt then
		local list = table.clone(queue)
		local diff = difficulty
		queue = {}
		countdownAt = 0
		difficulty = "Easy"
		local ok, err = GameService.StartHalloween(list, diff)
		if not ok then
			for _, pl in ipairs(list) do
				GameService.Toast(pl, err or "Не удалось начать матч")
			end
		end
	end
	publish()
end

------------------------------------------------------------------------
-- ЗАПРОСЫ КЛИЕНТА
------------------------------------------------------------------------
function HalloweenService.SetDifficulty(player, diff)
	if queue[1] ~= player then
		return false, "Сложность выбирает хост (первый в очереди)"
	end
	if not table.find(Config.Halloween.Difficulties, diff) then
		return false, "Неверная сложность"
	end
	difficulty = diff
	publish()
	return true
end

function HalloweenService.StartNow(player)
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

function HalloweenService.Leave(player)
	if not table.find(queue, player) then
		return false, "Ты не в очереди"
	end
	remove(player)
	leftUntil[player] = true
	-- отводим игрока с квадратов
	GameService.Teleport(player, queueCenter() + Vector3.new(0, 0, 16))
	publish()
	return true
end

-- Портал лобби <-> остров. Проверяем, что игрок стоит у портала и не в матче.
function HalloweenService.Teleport(player, where)
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
	local p = center + zone.Offset
	local d = Vector3.new(root.Position.X - p.X, 0, root.Position.Z - p.Z).Magnitude
	if d > zone.Radius + 8 then
		return false, "Подойди к порталу"
	end
	GameService.ToLobby(player, where == "Halloween")
	return true
end

function HalloweenService.Init(gameService, state)
	GameService, State = gameService, state
	Players.PlayerRemoving:Connect(function(pl)
		remove(pl)
		leftUntil[pl] = nil
	end)
	publish()
	task.spawn(function()
		while true do
			task.wait(0.25)
			local ok, err = pcall(tick)
			if not ok then
				warn("[VOID TD] HalloweenService: " .. tostring(err))
			end
		end
	end)
end

HalloweenService._tick = tick -- для автотестов
HalloweenService._queue = function()
	return queue, difficulty, countdownAt
end

return HalloweenService
