--!nocheck
-- VOID TD :: сервер (бутстрап)
-- Создаёт папки Remotes/State/Units, строит мир, запускает модули и связывает события игроков.
-- Вся логика — в модулях: Data, Economy, Sim, Match, Queue, Router, World.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("VoidTD")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))

local World = require(script:WaitForChild("World"))
local Data = require(script:WaitForChild("Data"))
local Economy = require(script:WaitForChild("Economy"))
local Sim = require(script:WaitForChild("Sim"))
local Match = require(script:WaitForChild("Match"))
local Queue = require(script:WaitForChild("Queue"))
local Router = require(script:WaitForChild("Router"))

-- папка: существующую переиспользуем (клиент мог уже схватить её через WaitForChild)
local function folder(name)
	local f = Shared:FindFirstChild(name)
	if f and not f:IsA("Folder") then
		f:Destroy()
		f = nil
	end
	if not f then
		f = Instance.new("Folder")
		f.Name = name
		f.Parent = Shared
	end
	return f
end

local remotes = Net.Setup()
local state = folder("State")
local unitsFolder = folder("Units")
for _, ch in ipairs(unitsFolder:GetChildren()) do
	ch:Destroy()
end

-- мир: Хэллоуин может не построиться — тогда Хэллоуин-матчи блокируются (Match.CanStartHalloween)
local okW, maps = pcall(World.Build)
if not okW then
	warn("[VOID TD] Мир не построен: " .. tostring(maps))
	maps = {}
end

Economy.Init({ Data = Data })
Sim.Init({
	Remotes = remotes,
	State = state,
	UnitsFolder = unitsFolder,
	Maps = { Void = maps.Void, Halloween = maps.Halloween },
	Data = Data,
	Economy = Economy,
})
Match.Init({ Remotes = remotes, State = state, Sim = Sim, Data = Data, Economy = Economy, Maps = maps })
Queue.Init(Match, state)
Router.Init({ Remotes = remotes, Data = Data, Match = Match, Sim = Sim, Queue = Queue, Economy = Economy })
Match.OnProfileChanged = Router.PushProfile

local function onPlayerAdded(player)
	Match.PlayerAdded(player)
	local profile = Data.Load(player)
	if not profile or not player.Parent then
		return
	end
	player:SetAttribute("VoidReady", true)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, p in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, p)
end

Players.PlayerRemoving:Connect(function(player)
	Match.PlayerRemoving(player)
	Queue.Leave(player, true)
	Router.PlayerRemoving(player)
	Data.Release(player)
end)

game:BindToClose(function()
	for _, p in ipairs(Players:GetPlayers()) do
		Data.Save(p, true)
	end
	Data.Flush(25)
end)

print("[VOID TD] Сервер запущен. Карта: " .. Config.Map.Name)
