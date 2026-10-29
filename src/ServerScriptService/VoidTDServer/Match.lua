--!nocheck
-- VOID TD :: Match
-- Единственный матч сервера: фазы Idle → Prep → Wave ⇄ Intermission → Victory/Defeat → Idle,
-- волны, ядро, награды, телепорты лобби/остров/арена, Хэллоуин-матч из очереди (Queue).
-- Бой (враги, юниты, урон) — в Sim; здесь только поток матча.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("VoidTD")
local Config = require(Shared:WaitForChild("Config"))

local S = Config.Settings
local FADE_DELAY = 0.45 -- телепорт после затемнения экрана

local Match = {}
Match.OnProfileChanged = nil -- function(player), ставит бутстрап (Router.PushProfile)

local Remotes, State, Sim, Data, Economy, Maps
local rng = Random.new()

-- состояние матча
local phase = "Idle"
local diffKey = "Medium"
local D = Config.Difficulties.Medium
local wave = 0
local coreHP = S.CoreMaxHP
local matchId = 0
local waveSpawning = false
local nextWaveAt = 0
local mode = "Void"
local maxWave = S.MaxWave
local roster = {} -- UserId -> true (участники Хэллоуин-матча)
local coinsPaid = {} -- matchId -> true

local RUNNING = { Prep = true, Wave = true, Intermission = true }

local function now()
	return workspace:GetServerTimeNow()
end

local function setState(k, v)
	State:SetAttribute(k, v)
end

local function notifyAll(payload)
	Remotes.Notify:FireAllClients(payload)
end

local function setPhase(p)
	phase = p
	setState("Phase", p)
	Sim.Configure({ Running = RUNNING[p] == true })
end

function Match.Toast(player, text, kind)
	Remotes.Notify:FireClient(player, { Type = "Toast", Text = text, Kind = kind or "error" })
end

local function inMatch(player)
	return player:GetAttribute("InMatch") == true
end

local function pushProfile(player)
	if Match.OnProfileChanged then
		Match.OnProfileChanged(player)
	end
end

------------------------------------------------------------------------
-- ТЕЛЕПОРТЫ
------------------------------------------------------------------------
function Match.Teleport(player, pos)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	char:PivotTo(CFrame.new(pos + Vector3.new(rng:NextNumber(-3, 3), 3.5, rng:NextNumber(-3, 3))))
end

local function toBattle(player)
	local m = Config.Maps[mode] or Config.Map
	Match.Teleport(player, m.BattleSpawn or Config.BattleSpawn)
end

function Match.ToLobby(player, island)
	player:SetAttribute("Island", island == true)
	Match.Teleport(player, island and Config.HalloweenIsland.Spawn or Config.Lobby.Spawn)
end

------------------------------------------------------------------------
-- ИГРОКИ
------------------------------------------------------------------------
local function onCharacter(player, char)
	char:WaitForChild("HumanoidRootPart", 5)
	task.wait(0.2)
	if char.Parent == nil or player.Character ~= char then
		return
	end
	if inMatch(player) then
		toBattle(player)
	else
		Match.ToLobby(player, player:GetAttribute("Island") == true)
	end
end

function Match.PlayerAdded(player)
	if not player:FindFirstChild("leaderstats") then
		local ls = Instance.new("Folder")
		ls.Name = "leaderstats"
		local money = Instance.new("IntValue")
		money.Name = "Money"
		money.Parent = ls
		ls.Parent = player
	end
	player:SetAttribute("InMatch", false)
	Economy.Set(player, 0)
	player.CharacterAdded:Connect(function(char)
		onCharacter(player, char)
	end)
	if player.Character then
		task.spawn(onCharacter, player, player.Character)
	end
end

------------------------------------------------------------------------
-- СБРОС / НАЧАЛО
------------------------------------------------------------------------
local function clearMatch()
	matchId += 1
	Sim.Clear()
	wave = 0
	waveSpawning = false
	nextWaveAt = 0
	Sim.Configure({ Wave = 0 })
	setState("Wave", 0)
	setState("NextWaveAt", 0)
	setState("MatchId", matchId)
end

local function setMapMode(m)
	mode = m
	maxWave = (Config.Maps[m] and Config.Maps[m].MaxWave) or S.MaxWave
	Sim.Configure({ Mode = m })
	setState("Map", m)
	setState("MaxWave", maxWave)
end

local function resetMatch()
	local wasHalloween = mode == "Halloween"
	clearMatch()
	setPhase("Idle")
	setState("Difficulty", "")
	local myMatch = matchId
	for _, pl in ipairs(Players:GetPlayers()) do
		if inMatch(pl) then
			pl:SetAttribute("InMatch", false)
			Economy.Set(pl, 0)
			pl:SetAttribute("Island", wasHalloween)
			Remotes.Notify:FireClient(pl, { Type = "Fade", Text = wasHalloween and "HALLOWEEN" or "ЛОББИ" })
			task.delay(FADE_DELAY, function()
				-- игрок мог успеть зайти в новый матч — тогда не выдёргиваем
				if pl.Parent and not inMatch(pl) and matchId == myMatch then
					Match.ToLobby(pl, wasHalloween)
				end
			end)
		end
	end
	roster = {}
	setMapMode("Void")
	notifyAll({ Type = "Reset" })
end
Match._reset = resetMatch

local function startNewMatch(key, m)
	clearMatch()
	setMapMode(m or "Void")
	diffKey = key
	D = Config.Difficulties[key]
	coreHP = D.CoreHP
	Sim.Configure({ D = D })
	setState("Difficulty", key)
	setState("CoreMaxHP", coreHP)
	setState("CoreHP", coreHP)
	setPhase("Prep")
end

local function resetIfEmpty()
	if #Economy.MatchPlayers() == 0 and phase ~= "Idle" then
		resetMatch()
	end
end

------------------------------------------------------------------------
-- ВОЛНЫ
------------------------------------------------------------------------
local function waveGroups(w)
	local source = mode == "Halloween" and Config.Maps.Halloween.Waves or Config.Waves
	local groups = {}
	for i, g in ipairs(source[w] or {}) do
		if g[1] == "BOSS" then
			groups[i] = { Config.Halloween.Bosses[diffKey] or "GraveWarden", g[2], g[3] }
		else
			groups[i] = g
		end
	end
	return groups
end

local function startWave()
	if phase ~= "Prep" and phase ~= "Intermission" then
		return false
	end
	wave += 1
	Sim.Configure({ Wave = wave })
	setPhase("Wave")
	setState("Wave", wave)
	setState("NextWaveAt", 0)
	nextWaveAt = 0
	local groups = waveGroups(wave)
	-- имя босса для анонса: самый «толстый» босс волны (legacy брал последнего)
	local bossName, bossHP
	for _, g in ipairs(groups) do
		local def = Config.Enemies[g[1]]
		if def and def.IsBoss and (not bossHP or def.Health > bossHP) then
			bossName, bossHP = def.Name, def.Health
		end
	end
	notifyAll({ Type = "WaveStart", Wave = wave, Boss = bossName })
	waveSpawning = true
	local myMatch, myWave = matchId, wave
	task.spawn(function()
		for gi, g in ipairs(groups) do
			local id, count, interval = g[1], g[2], g[3]
			for i = 1, count do
				if matchId ~= myMatch or phase ~= "Wave" then
					return
				end
				Sim.SpawnEnemy(id)
				if i < count then
					task.wait(interval)
				end
			end
			if gi < #groups then
				task.wait(S.GroupDelay)
			end
		end
		if matchId == myMatch and wave == myWave then
			waveSpawning = false
		end
	end)
	return true
end

local function endMatch(victory)
	setPhase(victory and "Victory" or "Defeat")
	waveSpawning = false
	local myMatch = matchId
	local players = Economy.MatchPlayers()
	if victory then
		local g = Economy.AddGemsAll(S.VictoryGems, D.Gems)
		local coins = 0
		if mode == "Halloween" and not coinsPaid[myMatch] then
			coinsPaid[myMatch] = true
			coins = Config.Halloween.Coins[diffKey] or 0
		end
		for _, pl in ipairs(players) do
			local prof = Data.Get(pl)
			if prof then
				prof.Stats.Wins = (prof.Stats.Wins or 0) + 1
				prof.Stats.BestWave = math.max(prof.Stats.BestWave or 0, wave)
				if coins > 0 and roster[pl.UserId] then
					Data.AddCurrency(pl, "HalloweenCoins", coins)
				end
				Data.Save(pl, true)
				pushProfile(pl)
			end
		end
		notifyAll({
			Type = "Victory", Wave = wave, Gems = g, Coins = coins > 0 and coins or nil,
			Reset = S.ResetDelay, Difficulty = diffKey, Mode = mode,
		})
	else
		for _, pl in ipairs(players) do
			local prof = Data.Get(pl)
			if prof then
				prof.Stats.BestWave = math.max(prof.Stats.BestWave or 0, wave - 1)
				Data.Save(pl, true)
			end
		end
		notifyAll({ Type = "Defeat", Wave = wave, Reset = S.ResetDelay, Difficulty = diffKey, Mode = mode })
		Sim.ClearEnemies()
	end
	task.delay(S.ResetDelay, function()
		if matchId == myMatch then
			resetMatch()
		end
	end)
end

local function waveCleared()
	local reward = math.floor((S.WaveRewardBase + S.WaveRewardPerWave * wave) * D.Money + 0.5)
	Economy.AddAll(reward)
	local gems = Economy.AddGemsAll(S.WaveGemsBase + S.WaveGemsPerWave * wave, D.Gems)
	if wave >= maxWave then
		endMatch(true)
		return
	end
	nextWaveAt = now() + (D.Intermission or S.Intermission)
	setPhase("Intermission")
	setState("NextWaveAt", nextWaveAt)
	notifyAll({ Type = "WaveClear", Wave = wave, Reward = reward, Gems = gems })
end

local function damageCore(amount)
	if phase == "Victory" or phase == "Defeat" or phase == "Idle" then
		return
	end
	coreHP = math.max(0, coreHP - amount)
	setState("CoreHP", coreHP)
	notifyAll({ Type = "CoreHit", Amount = amount })
	if coreHP <= 0 then
		endMatch(false)
	end
end

local function onKill(e, reward)
	Economy.AddAll(reward)
	local bossGems = e.Def.BossGems
	if bossGems then
		local g = Economy.AddGemsAll(bossGems, D.Gems)
		notifyAll({ Type = "Toast", Text = e.Def.Name .. " повержен! +" .. g .. " гемов", Kind = "boss" })
		notifyAll({ Type = "BossDown" })
	end
end

local function step(dt)
	local t = now()
	Sim.Step(t, dt, RUNNING[phase] == true)
	if phase == "Wave" and not waveSpawning and not Sim.HasEnemies() then
		waveCleared()
	elseif phase == "Intermission" and t >= nextWaveAt then
		startWave()
	end
end
Match._step = step

------------------------------------------------------------------------
-- ЗАПРОСЫ
------------------------------------------------------------------------
function Match.JoinMatch(player, key)
	if inMatch(player) then
		return false, "Ты уже в матче"
	end
	if phase == "Victory" or phase == "Defeat" then
		return false, "Матч завершается, подожди пару секунд"
	end
	if phase ~= "Idle" and mode == "Halloween" then
		return false, "Сейчас идёт Хэллоуин-матч. Подожди, пока он закончится"
	end
	if phase == "Idle" then
		if type(key) ~= "string" or not Config.Difficulties[key] then
			return false, "Выбери сложность"
		end
		startNewMatch(key)
	end
	player:SetAttribute("InMatch", true)
	Economy.Set(player, (S.StartMoney + math.max(0, wave - 1) * 150) * D.Money)
	toBattle(player)
	notifyAll({ Type = "Toast", Text = player.DisplayName .. " вступил в бой (" .. D.Name .. ")", Kind = "good" })
	return true, diffKey
end

function Match.LeaveMatch(player)
	if not inMatch(player) then
		return false, "Ты не в матче"
	end
	Sim.RemovePlayerUnits(player)
	player:SetAttribute("InMatch", false)
	Economy.Set(player, 0)
	Match.ToLobby(player, mode == "Halloween")
	resetIfEmpty()
	return true
end

function Match.PlayerRemoving(player)
	Sim.RemovePlayerUnits(player)
	player:SetAttribute("InMatch", false)
	task.defer(resetIfEmpty)
end

function Match.RequestStartWave(player)
	if not inMatch(player) then
		return false, "Сначала зайди в матч через портал ИГРАТЬ"
	end
	if phase == "Prep" or phase == "Intermission" then
		startWave()
		return true
	end
	return false, "Волна уже идёт"
end

-- ставить юнитов можно только участнику идущего матча
function Match.CanPlace(player)
	if not inMatch(player) then
		return false, "Сначала зайди в матч через портал ИГРАТЬ"
	end
	if not RUNNING[phase] then
		return false, "Матч не идёт"
	end
	return true
end

function Match.GetMatchInfo()
	return { Phase = phase, Difficulty = diffKey, Wave = wave, Players = #Economy.MatchPlayers(), Mode = mode }
end

function Match.GetMode()
	return mode, phase
end

-- арена одна: Хэллоуин только когда никто не играет (и карта построена)
function Match.CanStartHalloween()
	return phase == "Idle" and Maps.Halloween ~= nil
end

function Match.StartHalloween(list, key)
	if phase ~= "Idle" then
		return false, "Арена занята — идёт другой матч"
	end
	if not Maps.Halloween then
		return false, "Хэллоуин-арена недоступна"
	end
	if type(key) ~= "string" or not table.find(Config.Halloween.Difficulties, key) then
		return false, "Неверная сложность"
	end
	startNewMatch(key, "Halloween")
	roster = {}
	local myMatch = matchId
	for _, pl in ipairs(list) do
		if pl.Parent and not inMatch(pl) then
			roster[pl.UserId] = true
			pl:SetAttribute("InMatch", true)
			Economy.Set(pl, S.StartMoney * D.Money)
			Remotes.Notify:FireClient(pl, { Type = "Fade", Text = "HAUNTED HOLLOW" })
			task.delay(FADE_DELAY, function()
				if pl.Parent and inMatch(pl) and matchId == myMatch then
					toBattle(pl)
				end
			end)
		end
	end
	if #Economy.MatchPlayers() == 0 then
		resetMatch()
		return false, "Никого нет в очереди"
	end
	notifyAll({ Type = "Toast", Text = "🎃 Хэллоуин-матч начался (" .. D.Name .. ")", Kind = "good" })
	return true
end

function Match.Debug()
	local d = Sim.Debug()
	d.Mode = function()
		return mode, roster
	end
	d.Phase = function()
		return phase
	end
	d.Reset = resetMatch
	return d
end

function Match.Init(ctx)
	Remotes, State, Sim, Data, Economy = ctx.Remotes, ctx.State, ctx.Sim, ctx.Data, ctx.Economy
	Maps = ctx.Maps or {}
	Sim.Hooks.OnKill = onKill
	Sim.Hooks.OnCore = function(_, dmg)
		damageCore(dmg)
	end
	setState("MaxWave", S.MaxWave)
	setState("CoreMaxHP", S.CoreMaxHP)
	setState("CoreHP", S.CoreMaxHP)
	setState("BossId", 0)
	setState("BossName", "")
	resetMatch()
	RunService.Heartbeat:Connect(step)
end

return Match
