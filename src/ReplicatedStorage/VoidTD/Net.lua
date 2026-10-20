--!nocheck
-- VOID TD :: Net
-- Имена сетевых объектов и протокол. Сервер создаёт папку VoidTD.Remotes (Net.Setup),
-- клиент и сервер получают её через Net.Remotes().
--
-- Протокол (не менять — клиент и сервер читают одинаково):
--   EnemySpawn  { id, typeId, maxHp, speed, lateral, dist [, hp] }
--   Sync        { T, E = {id, dist, hp, flag, ...}, DMG = {{id, amount, flag}}, RM = {{id, reason}},
--                 AL = {id, dist, hp, allyIndex (Config.AllyOrder), maxHp, ...} | nil, RA = {{id, reason}} | nil }
--   Attack      { U, T = {enemyIds}, L, D, AB, EC, PW, TR, TRS, SG, TT, I, E, SP, ST }
--   Impact      { K, P, R, L, U, N, DUR, DL, I, A, S, G, E, F, H }
--   Notify      { Type = Toast|WaveStart|WaveClear|BossDown|CoreHit|Victory|Defeat|Fade|Purchase|Reset, ... }
--   Profile     { Gems, Inventory, Equipped ("1".."6"), Stats, Settings, DailyReadyAt, HalloweenCoins, Runes, RuneSlots }
--   Request     RemoteFunction (action, data) -> ok, resultOrError

local Net = {}

Net.FolderName = "Remotes"

-- RemoteEvent'ы (порядок создания как в legacy)
Net.Events = { "EnemySpawn", "Sync", "Attack", "Impact", "Notify", "Profile" }

-- RemoteFunction для запросов клиента
Net.Function = "Request"

-- действия запроса Request(action, data)
Net.Actions = {
	"GetProfile", "GetEnemies", "Place", "Upgrade", "Sell", "SetTarget", "JoinMatch", "LeaveMatch", "GetMatchInfo",
	"SetLite", "ClaimDaily", "BuyGems", "StartWave", "Summon", "Equip", "EquipRune", "Teleport",
	"QueueDifficulty", "QueueStart", "QueueLeave",
}

Net.ActionSet = {}
for _, name in ipairs(Net.Actions) do
	Net.ActionSet[name] = true
end

-- флаг врага в Sync.E
Net.EnemyFlag = { Normal = 0, Slowed = 1, Frozen = 2 }
-- флаг урона в Sync.DMG
Net.DamageFlag = { Normal = 0, Crit = 1, Dodge = 2 }

-- причины удаления врага (Sync.RM) и союзника (Sync.RA)
Net.RemoveReasons = { "kill", "core", "clear" }
Net.AllyRemoveReasons = { "dead", "portal", "sold", "replaced", "clear" }

local function shared()
	return game:GetService("ReplicatedStorage"):WaitForChild("VoidTD")
end

function Net.IsAction(name)
	return type(name) == "string" and Net.ActionSet[name] == true
end

-- Сервер: создать (или переиспользовать) папку Remotes со всеми событиями и функцией.
-- Существующие объекты не пересоздаются, чтобы клиент не схватил устаревшую копию.
function Net.Setup()
	local root = shared()
	local folder = root:FindFirstChild(Net.FolderName)
	if folder and not folder:IsA("Folder") then
		folder:Destroy()
		folder = nil
	end
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = Net.FolderName
		folder.Parent = root
	end
	local function ensure(name, class)
		local obj = folder:FindFirstChild(name)
		if obj and not obj:IsA(class) then
			obj:Destroy()
			obj = nil
		end
		if not obj then
			obj = Instance.new(class)
			obj.Name = name
			obj.Parent = folder
		end
		return obj
	end
	for _, name in ipairs(Net.Events) do
		ensure(name, "RemoteEvent")
	end
	ensure(Net.Function, "RemoteFunction")
	return folder
end

-- Клиент/сервер: папка Remotes. Дожидается всех событий и функции,
-- поэтому дальше можно обращаться напрямую: Remotes.Sync, Remotes.Request.
function Net.Remotes()
	local folder = shared():WaitForChild(Net.FolderName)
	for _, name in ipairs(Net.Events) do
		folder:WaitForChild(name)
	end
	folder:WaitForChild(Net.Function)
	return folder
end

-- Один объект по имени ("Sync", "Request", ...)
function Net.Get(name)
	return Net.Remotes():WaitForChild(name)
end

return Net
