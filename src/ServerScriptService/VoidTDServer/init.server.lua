--!nocheck
-- VOID TD :: Server bootstrap

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("VoidTD")
local Config = require(Shared:WaitForChild("Config"))

local MapBuilder = require(script:WaitForChild("MapBuilder"))
local DataService = require(script:WaitForChild("DataService"))
local GameService = require(script:WaitForChild("GameService"))

-- Remotes / State
local function folder(parent, name)
	local f = parent:FindFirstChild(name)
	if f then
		f:Destroy()
	end
	f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

local remotesFolder = folder(Shared, "Remotes")
local remotes = {}
for _, name in ipairs({ "EnemySpawn", "Sync", "Attack", "Impact", "Notify", "Profile" }) do
	local r = Instance.new("RemoteEvent")
	r.Name = name
	r.Parent = remotesFolder
	remotes[name] = r
end
local request = Instance.new("RemoteFunction")
request.Name = "Request"
request.Parent = remotesFolder
remotes.Request = request

local state = folder(Shared, "State")
local unitsFolder = folder(Shared, "Units")

local map = MapBuilder.Build()
GameService.Init(remotes, state, unitsFolder, map)

local function pushProfile(player)
	local snap = DataService.Snapshot(player)
	if snap then
		remotes.Profile:FireClient(player, snap)
	end
end

local function onPlayerAdded(player)
	DataService.Load(player)
	GameService.PlayerAdded(player)
	player:SetAttribute("VoidReady", true)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, p in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, p)
end

Players.PlayerRemoving:Connect(function(player)
	GameService.PlayerRemoving(player)
	DataService.Release(player)
end)

game:BindToClose(function()
	for _, p in ipairs(Players:GetPlayers()) do
		DataService.Save(p, true)
	end
	task.wait(2)
end)

-- Простое ограничение частоты запросов
local budget = {}
local function allow(player)
	local t = os.clock()
	local b = budget[player]
	if not b or t - b.Start > 1 then
		budget[player] = { Start = t, Count = 1 }
		return true
	end
	b.Count = b.Count + 1
	return b.Count <= 25
end
Players.PlayerRemoving:Connect(function(p)
	budget[p] = nil
end)

local handlers = {}

handlers.GetProfile = function(player)
	return true, DataService.Snapshot(player)
end

handlers.GetEnemies = function()
	return true, GameService.GetEnemySnapshot()
end

handlers.Place = function(player, data)
	if type(data) ~= "table" then
		return false, "Неверный запрос"
	end
	return GameService.PlaceUnit(player, data.Unit, data.Position, data.Rotation)
end

handlers.Upgrade = function(player, data)
	return GameService.UpgradeUnit(player, type(data) == "table" and data.Uid or data)
end

handlers.Sell = function(player, data)
	return GameService.SellUnit(player, type(data) == "table" and data.Uid or data)
end

handlers.SetTarget = function(player, data)
	if type(data) ~= "table" then
		return false, "Неверный запрос"
	end
	return GameService.SetTargetMode(player, data.Uid, data.Mode)
end

handlers.JoinMatch = function(player, data)
	return GameService.JoinMatch(player, type(data) == "table" and data.Difficulty or nil)
end

handlers.LeaveMatch = function(player)
	return GameService.LeaveMatch(player)
end

handlers.GetMatchInfo = function()
	return true, GameService.GetMatchInfo()
end

handlers.SetLite = function(player, data)
	local prof = DataService.Get(player)
	prof.Settings = prof.Settings or {}
	prof.Settings.Lite = type(data) == "table" and data.On == true
	DataService.Save(player)
	return true
end

handlers.StartWave = function(player)
	return GameService.RequestStartWave(player)
end

handlers.Summon = function(player, data)
	local count = (type(data) == "table" and data.Count == 10) and 10 or 1
	local ok, result = DataService.Summon(player, count)
	if ok then
		pushProfile(player)
	end
	return ok, result
end

handlers.Equip = function(player, data)
	if type(data) ~= "table" then
		return false, "Неверный запрос"
	end
	local ok, err = DataService.Equip(player, data.Unit, data.Slot)
	if ok then
		pushProfile(player)
	end
	return ok, err
end

request.OnServerInvoke = function(player, action, data)
	if not allow(player) then
		return false, "Слишком много запросов"
	end
	if not DataService.Get(player) then
		return false, "Профиль ещё загружается"
	end
	local h = handlers[action]
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

-- Гемы меняются от наград за волны — периодически отправляем профиль
task.spawn(function()
	while true do
		task.wait(5)
		for _, p in ipairs(Players:GetPlayers()) do
			local prof = DataService.Get(p)
			if prof and p:GetAttribute("LastGems") ~= prof.Gems then
				p:SetAttribute("LastGems", prof.Gems)
				pushProfile(p)
				DataService.Save(p)
			end
		end
	end
end)

print("[VOID TD] Сервер запущен. Карта: " .. Config.Map.Name)
