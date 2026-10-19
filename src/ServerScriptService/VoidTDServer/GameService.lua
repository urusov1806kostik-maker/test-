--!nocheck
-- VOID TD :: GameService
-- Вся игровая логика на сервере: враги, волны, ядро, юниты, урон.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("VoidTD")
local Config = require(Shared:WaitForChild("Config"))
local PathUtil = require(Shared:WaitForChild("PathUtil"))
local DataService = require(script.Parent:WaitForChild("DataService"))

local S = Config.Settings

local GameService = {}

local Remotes, State, UnitsFolder, Map
local MapModels = {}
local rng = Random.new()

local enemies = {}
local nextEnemyId = 0
local units = {}
local nextUnitId = 0
local zones = {}
local damageBuffer = {}
local removedBuffer = {}
local pendingSpawns = {}

-- Фазы: Idle (никто не играет) -> Prep (расстановка до 1-й волны) -> Wave <-> Intermission -> Victory/Defeat
local phase = "Idle"
local difficultyKey = "Medium"
local D = Config.Difficulties.Medium
local wave = 0
local coreHP = S.CoreMaxHP
local matchId = 0
local waveSpawning = false
local nextWaveAt = 0
local lastSync = 0
local lastAttrFlush = 0
-- режим матча: Void (обычный) или Halloween (карта Haunted Hollow, вход только из очереди на острове)
local matchMode = "Void"
local maxWave = S.MaxWave
local roster = {}       -- участники Хэллоуин-матча (UserId -> true)
local coinsPaid = {}    -- matchId -> true: награда за победу выдана (повторно не платится)
-- союзники (призывы): идут по дороге от базы к порталу
local allies = {}
local nextAllyId = 0
local allyRemoved = {}
local allyIndex = {}
for i, id in ipairs(Config.AllyOrder or {}) do
	allyIndex[id] = i
end
local echoAttack = false -- true, пока выполняется повтор атаки «Призрачной короны»

local function now()
	return workspace:GetServerTimeNow()
end

local function setState(key, value)
	State:SetAttribute(key, value)
end

local function notifyAll(payload)
	Remotes.Notify:FireAllClients(payload)
end

local function toast(player, text, kind)
	Remotes.Notify:FireClient(player, { Type = "Toast", Text = text, Kind = kind or "error" })
end
GameService.Toast = toast

------------------------------------------------------------------------
-- ДЕНЬГИ
------------------------------------------------------------------------
local function getMoney(player)
	return player:GetAttribute("Money") or 0
end

local function setMoney(player, amount)
	amount = math.max(0, math.floor(amount))
	player:SetAttribute("Money", amount)
	local ls = player:FindFirstChild("leaderstats")
	if ls and ls:FindFirstChild("Money") then
		ls.Money.Value = amount
	end
end

local function inMatch(player)
	return player:GetAttribute("InMatch") == true
end

local function matchPlayers()
	local list = {}
	for _, pl in ipairs(Players:GetPlayers()) do
		if inMatch(pl) then
			list[#list + 1] = pl
		end
	end
	return list
end

local function addMoneyAll(amount)
	for _, pl in ipairs(matchPlayers()) do
		setMoney(pl, getMoney(pl) + amount)
	end
end

local function addGemsAll(amount)
	amount = math.floor(amount * D.Gems + 0.5)
	for _, pl in ipairs(matchPlayers()) do
		DataService.AddGems(pl, amount)
	end
	return amount
end

------------------------------------------------------------------------
-- ТЕЛЕПОРТ ЛОББИ <-> КАРТА
------------------------------------------------------------------------
local function teleport(player, pos)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if root then
		local jitter = Vector3.new(rng:NextNumber(-3, 3), 3.5, rng:NextNumber(-3, 3))
		char:PivotTo(CFrame.new(pos + jitter))
	end
end

local function toBattle(player)
	local m = Config.Maps[matchMode] or Config.Map
	teleport(player, m.BattleSpawn or Config.BattleSpawn)
end

local function toLobby(player, island)
	player:SetAttribute("Island", island == true)
	teleport(player, island and Config.HalloweenIsland.Spawn or Config.Lobby.Spawn)
end
GameService.ToLobby = toLobby
GameService.Teleport = teleport

------------------------------------------------------------------------
-- ВРАГИ
------------------------------------------------------------------------
local function enemyPos(e)
	return (PathUtil.OffsetPositionAt(e.Dist, e.Lateral))
end

local function refreshBoss()
	local best
	for _, e in pairs(enemies) do
		if e.IsBoss and (not best or e.MaxHealth > best.MaxHealth) then
			best = e
		end
	end
	if best then
		setState("BossId", best.Id)
		setState("BossName", best.Def.Name)
		setState("BossMaxHP", best.MaxHealth)
	else
		setState("BossId", 0)
		setState("BossName", "")
	end
end

local function spawnEnemy(typeId, startDist, lateral)
	local def = Config.Enemies[typeId]
	if not def then
		return
	end
	nextEnemyId = nextEnemyId + 1
	local hp = math.floor(def.Health * Config.WaveHPMult(math.max(wave, 1)) * D.HP)
	local e = {
		Id = nextEnemyId,
		Type = typeId,
		Def = def,
		MaxHealth = hp,
		Health = hp,
		Speed = def.Speed * D.Speed,
		Dist = startDist or 0,
		Lateral = lateral or (def.IsBoss and 0 or rng:NextNumber(-2.2, 2.2)),
		Armor = def.Armor or 0,
		Dodge = def.Dodge or 0,
		IsBoss = def.IsBoss == true,
		SlowUntil = 0,
		SlowAmount = 0,
		Dots = {},
		NextDot = 0,
		Alive = true,
		Wave = wave,
	}
	if def.Summon then
		e.NextSummon = now() + def.Summon.Interval
	end
	-- особое поведение хэллоуинских врагов
	local t0 = now()
	e.BaseArmor = e.Armor
	if def.Phase then
		e.NextPhase = t0 + def.Phase.Every * rng:NextNumber(0.5, 1)
	end
	if def.Fog then
		e.NextFog = t0 + def.Fog.Every * rng:NextNumber(0.4, 0.8)
	end
	if def.Shield then
		e.NextShield = t0 + def.Shield.Every * 0.6
	end
	if def.Haste then
		e.NextHaste = t0 + def.Haste.Every * 0.7
	end
	e.Pos = enemyPos(e)
	enemies[e.Id] = e
	Remotes.EnemySpawn:FireAllClients({ e.Id, typeId, hp, e.Speed, e.Lateral, e.Dist })
	if e.IsBoss then
		refreshBoss()
	end
	return e
end

local function removeEnemy(e, reason)
	if not e.Alive then
		return
	end
	e.Alive = false
	enemies[e.Id] = nil
	removedBuffer[#removedBuffer + 1] = { e.Id, reason }
	if e.IsBoss then
		refreshBoss()
	end
end

local function killEnemy(e)
	local reward = math.floor(e.Def.Reward * (1 + S.KillRewardScalePerWave * (math.max(e.Wave, 1) - 1)) * D.Money + 0.5)
	addMoneyAll(reward)
	if e.Def.BossGems then
		local g = addGemsAll(e.Def.BossGems)
		notifyAll({ Type = "Toast", Text = e.Def.Name .. " повержен! +" .. g .. " гемов", Kind = "boss" })
		notifyAll({ Type = "BossDown" })
	end
	if e.Def.OnDeath then
		pendingSpawns[#pendingSpawns + 1] = { e.Def.OnDeath.Enemy, e.Def.OnDeath.Count, e.Dist + 1.5, e.Pos, "Straw" }
	end
	removeEnemy(e, "kill")
end

local function enemyState(e, state, dur)
	Remotes.Impact:FireAllClients({ K = "EnemyState", I = e.Id, S = state, DUR = dur, P = e.Pos })
end

-- множитель получаемого урона: фаза призрака, защита, метка проклятия
local function takenMult(e, t)
	local m = 1
	if (e.PhasedUntil or 0) > t then
		m = m * e.Def.Phase.Taken
	end
	if (e.ShieldUntil or 0) > t then
		m = m * e.Def.Shield.Taken
	end
	if (e.MarkUntil or 0) > t then
		m = m * (1 + (e.Mark or 0))
	end
	return m
end

-- броня с учётом участков дороги (Проклятый монарх)
local function armorOf(e)
	local a = e.Armor
	local zones = e.Def.ArmorZones
	if zones then
		local f = PathUtil.Fraction(e.Dist)
		for _, z in ipairs(zones) do
			if f >= z[1] and f <= z[2] then
				a = a + z[3]
			end
		end
	end
	return math.min(a, 0.9)
end

-- пороги HP: ломается броня, ярость, вторая фаза
local function checkThresholds(e)
	local def = e.Def
	local ratio = e.Health / e.MaxHealth
	if def.ArmorScale then
		e.Armor = e.BaseArmor * math.max(ratio, 0)
	end
	if def.ArmorBreak and not e.ArmorBroken and ratio <= def.ArmorBreak.At then
		e.ArmorBroken = true
		e.Armor = def.ArmorBreak.Armor
		enemyState(e, "ArmorBreak")
	end
	if def.Enrage and not e.Enraged and ratio <= def.Enrage.At then
		e.Enraged = true
		e.EnrageSpeed = def.Enrage.Speed or 0
		enemyState(e, "Enrage")
		if def.Enrage.Spawn then
			pendingSpawns[#pendingSpawns + 1] = { def.Enrage.Spawn[1], def.Enrage.Spawn[2], math.max(e.Dist - 4, 0), e.Pos, "Fire" }
		end
	end
end

local function pushDamage(id, amount, flag)
	damageBuffer[#damageBuffer + 1] = { id, amount, flag }
end

-- flag: 0 обычный, 1 крит, 2 уклонение
local function damageEnemy(e, amount, crit, unit, noDodge)
	if not e or not e.Alive then
		return 0
	end
	if not noDodge and e.Dodge > 0 and rng:NextNumber() < e.Dodge then
		pushDamage(e.Id, 0, 2)
		return 0
	end
	local dmg = math.max(1, math.floor(amount * (1 - armorOf(e)) * takenMult(e, now()) + 0.5))
	e.Health = e.Health - dmg
	pushDamage(e.Id, dmg, crit and 1 or 0)
	if unit then
		unit.DamageDealt = unit.DamageDealt + math.min(dmg, dmg + e.Health)
	end
	if e.Health <= 0 then
		killEnemy(e)
	else
		checkThresholds(e)
	end
	return dmg
end

-- чистый урон без брони и уклонения (столкновение с союзником)
local function rawDamage(e, amount, unit)
	if not e.Alive or amount <= 0 then
		return 0
	end
	local dmg = math.min(amount, e.Health)
	e.Health = e.Health - dmg
	pushDamage(e.Id, math.floor(dmg + 0.5), 0)
	if unit and unit.Alive then
		unit.DamageDealt = unit.DamageDealt + dmg
	end
	if e.Health <= 0.5 then
		e.Health = 0
		killEnemy(e)
	else
		checkThresholds(e)
	end
	return dmg
end

local function clearEnemies()
	for _, e in pairs(enemies) do
		e.Alive = false
		removedBuffer[#removedBuffer + 1] = { e.Id, "clear" }
	end
	enemies = {}
	zones = {}
	refreshBoss()
end

------------------------------------------------------------------------
-- ФАЗЫ МАТЧА
------------------------------------------------------------------------
local resetMatch

local function endMatch(victory)
	phase = victory and "Victory" or "Defeat"
	setState("Phase", phase)
	waveSpawning = false
	local myMatch = matchId
	if victory then
		local g = addGemsAll(S.VictoryGems)
		for _, pl in ipairs(matchPlayers()) do
			local prof = DataService.Get(pl)
			if prof then
				prof.Stats.Wins = (prof.Stats.Wins or 0) + 1
				prof.Stats.BestWave = math.max(prof.Stats.BestWave or 0, wave)
				DataService.Save(pl, true)
			end
		end
		-- Halloween Coins: каждому участнику за победу, один раз за матч
		local coins = 0
		if matchMode == "Halloween" and not coinsPaid[myMatch] then
			coinsPaid[myMatch] = true
			coins = Config.Halloween.Coins[difficultyKey] or 0
			for _, pl in ipairs(matchPlayers()) do
				if roster[pl.UserId] then
					DataService.AddCurrency(pl, "HalloweenCoins", coins)
					DataService.Save(pl, true)
					if GameService.OnProfileChanged then
						GameService.OnProfileChanged(pl)
					end
				end
			end
		end
		notifyAll({ Type = "Victory", Wave = wave, Gems = g, Coins = coins > 0 and coins or nil, Reset = S.ResetDelay, Difficulty = difficultyKey, Mode = matchMode })
	else
		for _, pl in ipairs(matchPlayers()) do
			local prof = DataService.Get(pl)
			if prof then
				prof.Stats.BestWave = math.max(prof.Stats.BestWave or 0, wave - 1)
				DataService.Save(pl, true)
			end
		end
		notifyAll({ Type = "Defeat", Wave = wave, Reset = S.ResetDelay, Difficulty = difficultyKey, Mode = matchMode })
		clearEnemies()
	end
	task.delay(S.ResetDelay, function()
		if matchId == myMatch then
			resetMatch()
		end
	end)
end

local function damageCore(amount)
	if phase == "Victory" or phase == "Defeat" then
		return
	end
	coreHP = math.max(0, coreHP - amount)
	setState("CoreHP", coreHP)
	notifyAll({ Type = "CoreHit", Amount = amount })
	if coreHP <= 0 then
		endMatch(false)
	end
end

local function waveCleared()
	local reward = math.floor((S.WaveRewardBase + S.WaveRewardPerWave * wave) * D.Money + 0.5)
	addMoneyAll(reward)
	local gems = addGemsAll(S.WaveGemsBase + S.WaveGemsPerWave * wave)
	if wave >= maxWave then
		endMatch(true)
		return
	end
	phase = "Intermission"
	nextWaveAt = now() + (D.Intermission or S.Intermission)
	setState("Phase", phase)
	setState("NextWaveAt", nextWaveAt)
	notifyAll({ Type = "WaveClear", Wave = wave, Reward = reward, Gems = gems })
end

local function startWave()
	if phase ~= "Prep" and phase ~= "Intermission" then
		return false
	end
	wave = wave + 1
	phase = "Wave"
	setState("Wave", wave)
	setState("Phase", phase)
	setState("NextWaveAt", 0)
	local source = matchMode == "Halloween" and Config.Maps.Halloween.Waves or Config.Waves
	local groups = {}
	for i, g in ipairs(source[wave] or {}) do
		-- BOSS — финальный босс выбранной сложности
		groups[i] = g[1] == "BOSS" and { Config.Halloween.Bosses[difficultyKey] or "GraveWarden", g[2], g[3] } or g
	end
	local bossName
	for _, g in ipairs(groups) do
		local def = Config.Enemies[g[1]]
		if def and def.IsBoss then
			bossName = def.Name
		end
	end
	notifyAll({ Type = "WaveStart", Wave = wave, Boss = bossName })
	waveSpawning = true
	local myMatch, myWave = matchId, wave
	task.spawn(function()
		for gi, g in ipairs(groups) do
			for i = 1, g[2] do
				if matchId ~= myMatch or phase ~= "Wave" then
					return
				end
				spawnEnemy(g[1])
				if i < g[2] then
					task.wait(g[3])
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

function GameService.RequestStartWave(player)
	if not inMatch(player) then
		return false, "Сначала зайди в матч через портал ИГРАТЬ"
	end
	if phase == "Prep" or phase == "Intermission" then
		startWave()
		return true
	end
	return false, "Волна уже идёт"
end

------------------------------------------------------------------------
-- ЮНИТЫ
------------------------------------------------------------------------
local function unitCountFor(player, unitId)
	local total, same = 0, 0
	for _, u in pairs(units) do
		if u.Owner == player then
			total = total + 1
			if u.Id == unitId then
				same = same + 1
			end
		end
	end
	return total, same
end

local function removeAlly(a, reason)
	if not a.Alive then
		return
	end
	a.Alive = false
	allies[a.Id] = nil
	allyRemoved[#allyRemoved + 1] = { a.Id, reason }
end

local function removeUnit(u)
	u.Alive = false
	units[u.Uid] = nil
	if u.Folder then
		u.Folder:Destroy()
	end
	-- проданный юнит забирает своих союзников
	for _, a in pairs(allies) do
		if a.Owner == u then
			removeAlly(a, "sold")
		end
	end
end

local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Include

function GameService.PlaceUnit(player, unitId, pos, rotation)
	if phase == "Victory" or phase == "Defeat" or phase == "Idle" then
		return false, "Матч не идёт"
	end
	if not inMatch(player) then
		return false, "Ты не в матче"
	end
	local def = Config.Units[unitId]
	if not def or typeof(pos) ~= "Vector3" then
		return false, "Неверный запрос"
	end
	if pos.X ~= pos.X or pos.Z ~= pos.Z then
		return false, "Неверная позиция"
	end
	if not DataService.IsEquipped(player, unitId) then
		return false, "Юнит не экипирован"
	end
	local cost = def.Levels[1].Cost
	if getMoney(player) < cost then
		return false, "Недостаточно денег"
	end
	local total, same = unitCountFor(player, unitId)
	if total >= S.MaxUnitsPerPlayer then
		return false, "Лимит юнитов: " .. S.MaxUnitsPerPlayer
	end
	local limit = Config.Rarities[def.Rarity].PlacementLimit
	if same >= limit then
		return false, "Лимит " .. def.Name .. ": " .. limit
	end
	local ok, why = PathUtil.IsPlacementClear(pos)
	if not ok then
		return false, why
	end
	-- проверяем, что под ногами остров
	raycastParams.FilterDescendantsInstances = { MapModels[matchMode] or Map }
	local hit = workspace:Raycast(Vector3.new(pos.X, PathUtil.Map.GroundY + 30, pos.Z), Vector3.new(0, -60, 0), raycastParams)
	if not hit or not hit.Instance:GetAttribute("Placeable") then
		return false, "Сюда ставить нельзя"
	end
	local ground = Vector3.new(pos.X, hit.Position.Y, pos.Z)
	for _, u in pairs(units) do
		if PathUtil.FlatDistance(u.Pos, ground) < S.PlacementSpacing then
			return false, "Слишком близко к другому юниту"
		end
	end

	setMoney(player, getMoney(player) - cost)
	nextUnitId = nextUnitId + 1
	local u = {
		Uid = nextUnitId,
		Id = unitId,
		Def = def,
		Owner = player,
		Level = 1,
		Pos = ground,
		Rotation = tonumber(rotation) or 0,
		TargetMode = def.DefaultTarget or "First",
		NextAttack = now() + 0.6,
		NextAbility = now() + 1.5,
		PlacedAt = now(),
		Spent = cost,
		DamageDealt = 0,
		Alive = true,
	}
	local f = Instance.new("Folder")
	f.Name = tostring(u.Uid)
	f:SetAttribute("UnitId", unitId)
	f:SetAttribute("Level", 1)
	f:SetAttribute("OwnerId", player.UserId)
	f:SetAttribute("OwnerName", player.DisplayName)
	f:SetAttribute("Position", ground)
	f:SetAttribute("Rotation", u.Rotation)
	f:SetAttribute("TargetMode", u.TargetMode)
	f:SetAttribute("Spent", u.Spent)
	f:SetAttribute("Damage", 0)
	f.Parent = UnitsFolder
	u.Folder = f
	-- таймеры способностей времени стартуют после установки
	if def.TimeHaste then
		u.NextHaste = u.PlacedAt + def.TimeHaste.FirstDelay
	end
	if def.TimeStorm then
		u.NextStorm = u.PlacedAt + def.TimeStorm.FirstDelay
	end
	-- призыв союзников: первый — через интервал текущего уровня
	if def.Summon then
		u.NextSummon = u.PlacedAt + def.Summon.Levels[1].Interval
		u.SummonCount = 0
	end
	-- руна: читается из профиля в момент установки
	u.Rune = DataService.GetRune(player, unitId)
	if u.Rune then
		f:SetAttribute("Rune", u.Rune)
		if u.Rune == "CursedThreads" then
			u.NextRuneSummon = u.PlacedAt + Config.Runes.CursedThreads.Summon.Interval
		end
	end
	units[u.Uid] = u
	return true, u.Uid
end

local function ownedUnit(player, uid)
	local u = units[tonumber(uid) or -1]
	if not u then
		return nil, "Юнит не найден"
	end
	if u.Owner ~= player then
		return nil, "Это не твой юнит"
	end
	return u
end

function GameService.UpgradeUnit(player, uid)
	local u, err = ownedUnit(player, uid)
	if not u then
		return false, err
	end
	if u.Level >= #u.Def.Levels then
		return false, "Максимальный уровень"
	end
	local cost = u.Def.Levels[u.Level + 1].Cost
	if getMoney(player) < cost then
		return false, "Недостаточно денег"
	end
	setMoney(player, getMoney(player) - cost)
	u.Level = u.Level + 1
	u.Spent = u.Spent + cost
	u.Folder:SetAttribute("Level", u.Level)
	u.Folder:SetAttribute("Spent", u.Spent)
	return true, u.Level
end

function GameService.SellUnit(player, uid)
	local u, err = ownedUnit(player, uid)
	if not u then
		return false, err
	end
	local refund = math.floor(u.Spent * S.SellRefund)
	setMoney(player, getMoney(player) + refund)
	removeUnit(u)
	return true, refund
end

function GameService.SetTargetMode(player, uid, mode)
	local u, err = ownedUnit(player, uid)
	if not u then
		return false, err
	end
	if not table.find(Config.TargetModes, mode) then
		return false, "Неверный режим"
	end
	u.TargetMode = mode
	u.Folder:SetAttribute("TargetMode", mode)
	return true
end

------------------------------------------------------------------------
-- ВЫБОР ЦЕЛИ
------------------------------------------------------------------------
local sorters = {
	First = function(a, b)
		return a.Dist > b.Dist
	end,
	Last = function(a, b)
		return a.Dist < b.Dist
	end,
	Strongest = function(a, b)
		if a.Health == b.Health then
			return a.Dist > b.Dist
		end
		return a.Health > b.Health
	end,
	Weakest = function(a, b)
		if a.Health == b.Health then
			return a.Dist > b.Dist
		end
		return a.Health < b.Health
	end,
}

local function candidates(u, range)
	local list = {}
	for _, e in pairs(enemies) do
		if e.Alive then
			local d = PathUtil.FlatDistance(e.Pos, u.Pos)
			if d <= range then
				e._d = d
				list[#list + 1] = e
			end
		end
	end
	if #list > 1 then
		local sorter = sorters[u.TargetMode]
		if u.TargetMode == "Closest" or not sorter then
			table.sort(list, function(a, b)
				return a._d < b._d
			end)
		else
			table.sort(list, sorter)
		end
	end
	return list
end

------------------------------------------------------------------------
-- АТАКИ
------------------------------------------------------------------------
local function rollDamage(stats)
	local dmg = stats.Damage
	local crit = false
	if stats.CritChance and rng:NextNumber() < stats.CritChance then
		dmg = dmg * (stats.CritMult or 2)
		crit = true
	end
	return dmg, crit
end

local function fireAttack(u, targetIds, extra)
	local payload = { U = u.Uid, T = targetIds, L = u.Level, EC = echoAttack or nil }
	if extra then
		for k, v in pairs(extra) do
			payload[k] = v
		end
	end
	Remotes.Attack:FireAllClients(payload)
end

local function valid(u, myMatch)
	return u.Alive and matchId == myMatch
end

------------------------------------------------------------------------
-- ЭФФЕКТЫ НА ВРАГАХ: периодический урон (кровотечение, нити) и замедление
------------------------------------------------------------------------
local function applyDot(e, dps, duration, u, kind)
	if not e.Alive or not dps or dps <= 0 then
		return
	end
	-- один источник обновляет свой эффект, а не стакает бесконечно
	local key = tostring(u and u.Uid or 0) .. ":" .. kind
	e.Dots[key] = { Dps = dps, Until = now() + duration, Unit = u }
end

local function applySlow(e, amount, duration)
	if not e then
		return
	end
	if not e.Alive or not amount then
		return
	end
	local t = now()
	amount = amount * (e.IsBoss and S.BossSlowResist or 1)
	if e.SlowUntil < t then
		e.SlowAmount = 0
	end
	e.SlowAmount = math.max(e.SlowAmount, amount)
	e.SlowUntil = math.max(e.SlowUntil, t + duration)
end

local function updateDots(t)
	for _, e in pairs(enemies) do
		if next(e.Dots) and t >= e.NextDot then
			e.NextDot = t + 0.5
			local total, unit = 0, nil
			for key, d in pairs(e.Dots) do
				if t >= d.Until then
					e.Dots[key] = nil
				else
					total = total + d.Dps * 0.5
					unit = unit or d.Unit
				end
			end
			if total > 0 then
				damageEnemy(e, total, false, unit, true)
			end
		end
	end
end

-- AOE: каждый враг получает урон ровно один раз за удар.
-- opts: Exclude (враг без урона), Mult, Bleed/BleedTime, Color, Extra (доп. поля события)
local function aoeHit(u, center, radius, stats, kind, opts)
	opts = opts or {}
	local hitSet = {}
	for _, e in pairs(enemies) do
		if e.Alive and e ~= opts.Exclude and PathUtil.FlatDistance(e.Pos, center) <= radius + (e.IsBoss and 1.5 or 0.5) then
			hitSet[#hitSet + 1] = e
		end
	end
	local payload = { K = kind, P = center, R = radius, L = u.Level, U = u.Uid, N = #hitSet }
	for k, v in pairs(opts.Extra or {}) do
		payload[k] = v
	end
	Remotes.Impact:FireAllClients(payload)
	for _, e in ipairs(hitSet) do
		local dmg, crit = rollDamage(stats)
		if opts.Bleed then
			applyDot(e, opts.Bleed, opts.BleedTime or 3, u, opts.DotKind or "Bleed")
		end
		if opts.Slow then
			applySlow(e, opts.Slow, opts.SlowTime or 1.5)
		end
		damageEnemy(e, dmg * (opts.Mult or 1), crit, u)
	end
	return hitSet
end

local function distToSegment(p, a, b)
	local abx, abz = b.X - a.X, b.Z - a.Z
	local lenSq = abx * abx + abz * abz
	local t = 0
	if lenSq > 0 then
		t = math.clamp(((p.X - a.X) * abx + (p.Z - a.Z) * abz) / lenSq, 0, 1)
	end
	local cx, cz = a.X + abx * t, a.Z + abz * t
	return math.sqrt((p.X - cx) ^ 2 + (p.Z - cz) ^ 2)
end

------------------------------------------------------------------------
-- СПОСОБНОСТИ ВРЕМЕНИ (Проклятый часовщик)
------------------------------------------------------------------------
-- Остановка не суммируется: замороженного не морозим повторно, после заморозки — иммунитет
local function freezeEnemy(e, duration, t)
	e.FrozenUntil = t + duration
	e.FreezeImmuneUntil = t + duration + (S.FreezeImmunity or 3)
end

local function castTimeBreak(u, stats)
	local tb = u.Def.TimeBreak
	local list = candidates(u, stats.Range + 2)
	if #list == 0 then
		return
	end
	local t = now()
	local center = list[1].Pos
	local normal, bosses = {}, {}
	for _, e in pairs(enemies) do
		if e.Alive and t >= (e.FreezeImmuneUntil or 0) and (e.FrozenUntil or 0) <= t then
			local d = PathUtil.FlatDistance(e.Pos, center)
			if d <= tb.Radius + (e.IsBoss and 1.5 or 0) then
				e._dc = d
				table.insert(e.IsBoss and bosses or normal, e)
			end
		end
	end
	table.sort(normal, function(a, b)
		return a._dc < b._dc
	end)
	local frozen = {}
	for i = 1, math.min(tb.MaxFreeze, #normal) do
		freezeEnemy(normal[i], tb.Freeze, t)
		frozen[i] = normal[i]
	end
	for _, b in ipairs(bosses) do
		freezeEnemy(b, tb.BossFreeze, t)
	end
	Remotes.Attack:FireAllClients({ U = u.Uid, T = { list[1].Id }, L = u.Level, D = 0.5, AB = "TimeBreak" })
	Remotes.Impact:FireAllClients({ K = "TimeBreak", P = center, R = tb.Radius, DUR = tb.Freeze, U = u.Uid, L = u.Level })
	-- после остановки до 3 обычных врагов отматываются назад по дороге (боссы — нет)
	local myMatch = matchId
	task.delay(tb.Freeze, function()
		if matchId ~= myMatch then
			return
		end
		for i = 1, math.min(tb.MaxRewind, #frozen) do
			local e = frozen[i]
			if e.Alive then
				e.Dist = math.max(0, e.Dist - tb.Rewind)
				e.Pos = enemyPos(e)
			end
		end
	end)
end

local function castTimeHaste(u, stats)
	local th = u.Def.TimeHaste
	local t = now()
	local allies = {}
	for _, o in pairs(units) do
		-- только свои юниты того же игрока, не сам часовщик
		if o ~= u and o.Alive and o.Owner == u.Owner and PathUtil.FlatDistance(o.Pos, u.Pos) <= th.Radius then
			-- одинаковые ускорения не суммируются: действует самое сильное
			if (o.HasteUntil or 0) > t then
				o.Haste = math.max(o.Haste or 0, stats.Haste)
			else
				o.Haste = stats.Haste
			end
			o.HasteUntil = math.max(o.HasteUntil or 0, t + stats.HasteTime)
			allies[#allies + 1] = o.Uid
		end
	end
	Remotes.Attack:FireAllClients({ U = u.Uid, T = {}, L = u.Level, D = 0.4, AB = "TimeHaste" })
	Remotes.Impact:FireAllClients({ K = "TimeHaste", P = u.Pos, R = th.Radius, A = allies, DUR = stats.HasteTime, U = u.Uid, L = u.Level })
end

local function startTimeStorm(u, t)
	local ts = u.Def.TimeStorm
	u.StormUntil = t + ts.Duration
	u.NextStorm = u.StormUntil + ts.Cooldown
	u.Folder:SetAttribute("Storm", true)
	Remotes.Attack:FireAllClients({ U = u.Uid, T = {}, L = u.Level, D = 1.2, AB = "TimeStorm" })
	Remotes.Impact:FireAllClients({ K = "TimeStorm", P = u.Pos, R = 6, DL = 1.3, U = u.Uid, L = u.Level })
end

local function updateChrono(u, stats, t)
	local def = u.Def
	if def.TimeStorm then
		if u.StormUntil and t >= u.StormUntil then
			u.StormUntil = nil
			u.Folder:SetAttribute("Storm", false)
		end
		if not u.StormUntil and t >= u.NextStorm then
			startTimeStorm(u, t)
			u.NextAttack = math.max(u.NextAttack, t + 1.4)
		end
	end
	if def.TimeHaste and t >= u.NextHaste then
		castTimeHaste(u, stats)
		u.NextHaste = t + def.TimeHaste.Interval
		u.NextAttack = math.max(u.NextAttack, t + 0.6)
	end
end

-- ядовитая/огненная зона: урон раз в 0.5 с всем внутри
local function poisonZone(u, pos, radius, duration, dps, kind, delay)
	if dps <= 0 then
		return
	end
	local t = now() + (delay or 0)
	zones[#zones + 1] = {
		Pos = pos, Radius = radius, Until = t + duration, NextTick = t, Tick = 0.5,
		TickDamage = dps * 0.5, Slow = 0, Unit = u,
	}
	Remotes.Impact:FireAllClients({ K = kind, P = pos, R = radius, DUR = duration, DL = delay, U = u.Uid, L = u.Level })
end

local function attack(u, stats, list)
	list = list or {}
	if not list[1] then
		return
	end
	local def = u.Def
	local myMatch = matchId
	local hitDelay = def.HitDelay or 0.2
	local target = list[1]
	local atype = def.AttackType

	local function later(delay, fn)
		task.delay(delay, function()
			if valid(u, myMatch) then
				fn()
			end
		end)
	end

	-- урон + эффекты при попадании (кровотечение)
	local function strike(e, mult, forceCrit)
		if not e or not e.Alive then
			return
		end
		local dmg, crit = rollDamage(stats)
		if stats.Bleed then
			applyDot(e, stats.Bleed, stats.BleedTime or 3, u, "Bleed")
		end
		damageEnemy(e, dmg * (mult or 1), crit or forceCrit, u)
	end

	if atype == "Melee" or atype == "Laser" then
		local mult, power = 1, false
		if def.EveryNth and not echoAttack then
			u.HitCount = (u.HitCount or 0) + 1
			if u.HitCount % def.EveryNth.N == 0 then
				mult, power = def.EveryNth.Mult, true
			end
		end
		fireAttack(u, { target.Id }, { D = hitDelay, PW = power })
		later(hitDelay, function()
			strike(target, mult, power)
		end)
	elseif atype == "Projectile" then
		local shots = stats.Shots or 1
		local ids, travels = {}, {}
		for s = 1, shots do
			local e = list[((s - 1) % #list) + 1]
			ids[s] = e.Id
			travels[s] = PathUtil.FlatDistance(u.Pos, e.Pos) / (def.ProjectileSpeed or 80)
		end
		fireAttack(u, ids, { D = hitDelay, TR = travels[1], TRS = travels, SG = 0.12 })
		for s = 1, shots do
			local e = list[((s - 1) % #list) + 1]
			later(hitDelay + (s - 1) * 0.12 + travels[s], function()
				if not e.Alive then
					return
				end
				local center = e.Pos
				strike(e)
				if stats.Explode then
					aoeHit(u, center, stats.Explode, stats, def.ExplodeKind or "Crystal", { Exclude = e, Mult = def.ExplodeMult or 0.5 })
				end
			end)
		end
	elseif atype == "Chain" then
		-- лунный серп отскакивает к ближайшим врагам
		local seq, times = { target }, {}
		local used = { [target] = true }
		local speed = def.ProjectileSpeed or 60
		times[1] = hitDelay + PathUtil.FlatDistance(u.Pos, target.Pos) / speed
		for i = 2, stats.Bounces or 3 do
			local prev = seq[i - 1]
			local best, bestD
			for _, e in pairs(enemies) do
				if e.Alive and not used[e] then
					local d = PathUtil.FlatDistance(e.Pos, prev.Pos)
					if d <= (def.BounceRange or 12) and (not bestD or d < bestD) then
						best, bestD = e, d
					end
				end
			end
			if not best then
				break
			end
			used[best] = true
			seq[i] = best
			times[i] = times[i - 1] + bestD / speed
		end
		local ids = {}
		for i, e in ipairs(seq) do
			ids[i] = e.Id
		end
		fireAttack(u, ids, { D = hitDelay, TT = times })
		for i, e in ipairs(seq) do
			later(times[i], function()
				strike(e, (def.BounceMult or 0.8) ^ (i - 1))
			end)
		end
	elseif atype == "Thread" then
		local ids, targets = {}, {}
		for i = 1, math.min(stats.Targets or 1, #list) do
			targets[i] = list[i]
			ids[i] = list[i].Id
		end
		fireAttack(u, ids, { D = hitDelay })
		later(hitDelay, function()
			for _, e in ipairs(targets) do
				if e.Alive then
					applySlow(e, stats.Slow, stats.SlowTime or 1.5)
					applyDot(e, stats.Dot, stats.DotTime or 3, u, "Thread")
					strike(e)
				end
			end
		end)
	elseif atype == "AOE" then
		local saved = target.Pos
		fireAttack(u, { target.Id }, { D = hitDelay })
		later(hitDelay, function()
			local center = target.Alive and target.Pos or saved
			aoeHit(u, center, stats.AOERadius or 6, stats, def.ImpactKind or "Reap", { Bleed = stats.Bleed, BleedTime = stats.BleedTime })
			-- падающие звёздные осколки
			for k = 1, stats.Shards or 0 do
				later(0.35 + k * 0.15, function()
					local pool = candidates(u, stats.Range + 4)
					if #pool > 0 then
						local e = pool[math.random(1, #pool)]
						aoeHit(u, e.Pos, stats.ShardRadius or 4, stats, "Shard", { Mult = stats.ShardMult or 0.6 })
					end
				end)
			end
		end)
	elseif atype == "MultiHit" then
		local hits = stats.Hits or 1
		local interval = def.HitInterval or 0.15
		local spread = def.Spread or (u.Id == "VoidEmperor")
		local kind = def.ImpactKind or "Judgement"
		local ids = {}
		local plan = {}
		for h = 1, hits do
			local e = spread and list[((h - 1) % #list) + 1] or target
			plan[h] = e
			ids[h] = e.Id
		end
		fireAttack(u, ids, { D = hitDelay, I = interval })
		for h = 1, hits do
			later(hitDelay + (h - 1) * interval, function()
				local e = plan[h]
				if not e.Alive then
					e = candidates(u, stats.Range)[1]
				end
				if e then
					if spread then
						Remotes.Impact:FireAllClients({ K = kind, P = e.Pos, L = u.Level, U = u.Uid, H = h })
					end
					strike(e)
				end
			end)
		end
		if stats.BigRift then
			later(hitDelay + hits * interval + 0.2, function()
				local pool = candidates(u, stats.Range)
				if #pool > 0 then
					aoeHit(u, pool[1].Pos, stats.BigRift, stats, "BigRift", { Mult = stats.BigRiftMult or 1.5 })
				end
			end)
		end
	elseif atype == "Splash" then
		-- RED SPLASH: цель 100%, остальные в радиусе 50% (цель второй раз не задевается)
		fireAttack(u, { target.Id }, { D = hitDelay })
		local saved = target.Pos
		later(hitDelay, function()
			local center = target.Alive and target.Pos or saved
			local primary = target.Alive and target or nil
			strike(primary)
			aoeHit(u, center, stats.AOERadius or 8, stats, "Splash", { Exclude = target, Mult = def.SplashMult or 0.5 })
		end)
	elseif atype == "Chrono" then
		-- РАЗРЕЗ СЕКУНД: зубчатый диск летит по прямой и режет до DiscTargets врагов
		local t0 = now()
		local storm = u.StormUntil ~= nil and t0 < u.StormUntil
		local dir = Vector3.new(target.Pos.X - u.Pos.X, 0, target.Pos.Z - u.Pos.Z)
		if dir.Magnitude < 0.1 then
			dir = Vector3.new(0, 0, -1)
		end
		dir = dir.Unit
		local endPos = u.Pos + dir * (stats.Range + 3)
		local speed = def.ProjectileSpeed or 70
		local half = (def.DiscWidth or 3) / 2
		local line = {}
		for _, e in pairs(enemies) do
			if e.Alive and e ~= target and distToSegment(e.Pos, u.Pos, endPos) <= half + (e.IsBoss and 1.2 or 0) then
				e._along = (e.Pos.X - u.Pos.X) * dir.X + (e.Pos.Z - u.Pos.Z) * dir.Z
				line[#line + 1] = e
			end
		end
		table.sort(line, function(a, b)
			return a._along < b._along
		end)
		local hits = { target }
		local hitSet = { [target] = true }
		for _, e in ipairs(line) do
			if #hits >= (def.DiscTargets or 5) then
				break
			end
			hits[#hits + 1] = e
			hitSet[e] = true
		end
		fireAttack(u, { target.Id }, { D = hitDelay, E = endPos, SP = speed, ST = storm or nil })
		for _, e in ipairs(hits) do
			local along = math.max(0, (e.Pos.X - u.Pos.X) * dir.X + (e.Pos.Z - u.Pos.Z) * dir.Z)
			later(hitDelay + along / speed, function()
				if e.Alive then
					Remotes.Impact:FireAllClients({ K = "ChronoHit", P = e.Pos, L = u.Level, U = u.Uid })
					strike(e)
				end
			end)
		end
		-- ВРЕМЕННАЯ БУРЯ: основная цель 100% (диском), до 4 других врагов рядом с ней — по 50%.
		-- Эти попадания не считаются обычными атаками.
		if storm then
			local ts = def.TimeStorm
			local saved = target.Pos
			later(hitDelay + PathUtil.FlatDistance(u.Pos, target.Pos) / speed + 0.02, function()
				local center = target.Alive and target.Pos or saved
				local extra = {}
				for _, e in pairs(enemies) do
					if e.Alive and not hitSet[e] then
						local d = PathUtil.FlatDistance(e.Pos, center)
						if d <= ts.Radius + (e.IsBoss and 1 or 0.3) then
							e._dc = d
							extra[#extra + 1] = e
						end
					end
				end
				table.sort(extra, function(a, b)
					return a._dc < b._dc
				end)
				Remotes.Impact:FireAllClients({ K = "ChronoBurst", P = center, R = ts.Radius, L = u.Level, U = u.Uid })
				for i = 1, math.min(ts.Extra, #extra) do
					strike(extra[i], ts.Mult)
				end
			end)
		end
		-- ПОЛОМКА ВРЕМЕНИ: каждая 8-я обычная атака, но не чаще раза в 18 с
		local tb = def.TimeBreak
		if not echoAttack then
			u.ChronoCount = (u.ChronoCount or 0) + 1
		end
		if not echoAttack and u.ChronoCount >= tb.EveryNth and t0 - (u.LastBreak or -1e9) >= tb.MinInterval then
			u.ChronoCount = 0
			u.LastBreak = t0
			u.NextAttack = math.max(u.NextAttack or 0, t0 + 1.6)
			later(hitDelay + 0.45, function()
				castTimeBreak(u, stats)
			end)
		end
	elseif atype == "Pulse" then
		-- звуковая волна вокруг самого юнита
		fireAttack(u, { target.Id }, { D = hitDelay })
		later(hitDelay, function()
			aoeHit(u, u.Pos, stats.AOERadius or stats.Range, stats, def.ImpactKind or "BellWave")
		end)
	elseif atype == "Flask" then
		-- колба: взрыв по области и ядовитая лужа (урон по времени)
		local travel = PathUtil.FlatDistance(u.Pos, target.Pos) / (def.ProjectileSpeed or 45)
		local saved = target.Pos
		fireAttack(u, { target.Id }, { D = hitDelay, TR = travel })
		later(hitDelay + travel, function()
			local center = target.Alive and target.Pos or saved
			aoeHit(u, center, stats.Explode or 5, stats, "FlaskSplash")
			poisonZone(u, center, (stats.Explode or 5) * 0.8, def.PoisonTime or 3, stats.PoisonDps or 0, "Poison")
		end)
	elseif atype == "Pierce" then
		-- луч насквозь: все враги на линии от юнита через цель
		local dir = Vector3.new(target.Pos.X - u.Pos.X, 0, target.Pos.Z - u.Pos.Z)
		if dir.Magnitude < 0.1 then
			dir = Vector3.new(0, 0, -1)
		end
		local endPos = u.Pos + dir.Unit * (stats.Range + 4)
		fireAttack(u, { target.Id }, { D = hitDelay, E = endPos })
		later(hitDelay, function()
			Remotes.Impact:FireAllClients({ K = def.ImpactKindPierce or "Pierce", P = u.Pos, E = endPos, L = u.Level, U = u.Uid })
			local half = (def.PierceWidth or 3) / 2
			local hitSet = {}
			for _, e in pairs(enemies) do
				if e.Alive and distToSegment(e.Pos, u.Pos, endPos) <= half + (e.IsBoss and 1.2 or 0) then
					hitSet[#hitSet + 1] = e
				end
			end
			for _, e in ipairs(hitSet) do
				strike(e)
			end
		end)
	end
end

------------------------------------------------------------------------
-- HALLOWEEN: обычная атака с рунами, способности Power, союзники
------------------------------------------------------------------------
-- через сколько секунд обычная атака попадает в цель
local function impactDelay(u, target)
	local def = u.Def
	local d = def.HitDelay or 0.2
	if def.ProjectileSpeed and def.AttackType ~= "Chrono" then
		d = d + PathUtil.FlatDistance(u.Pos, target.Pos) / def.ProjectileSpeed
	elseif def.AttackType == "Chrono" then
		d = d + PathUtil.FlatDistance(u.Pos, target.Pos) / (def.ProjectileSpeed or 70)
	end
	return d
end

local function nearestTo(center, radius, exclude, maxCount)
	local list = {}
	for _, e in pairs(enemies) do
		if e.Alive and not exclude[e] then
			local d = PathUtil.FlatDistance(e.Pos, center)
			if d <= radius + (e.IsBoss and 1 or 0.3) then
				e._dr = d
				list[#list + 1] = e
			end
		end
	end
	table.sort(list, function(a, b)
		return a._dr < b._dr
	end)
	while #list > maxCount do
		table.remove(list)
	end
	return list
end

-- Руны после обычной атаки (повтор «Призрачной короны» руны не запускает)
local function runeAfterAttack(u, stats, list)
	local runeId = u.Rune
	local rune = runeId and Config.Runes[runeId]
	if not rune or echoAttack then
		return
	end
	local target = list[1]
	local myMatch = matchId
	if runeId == "LanternHeart" then
		-- каждая 3-я обычная атака: огненный взрыв 20% урона, радиус 4, до 4 дополнительных врагов
		u.RuneCount = (u.RuneCount or 0) + 1
		if u.RuneCount % rune.EveryNth == 0 then
			local saved = target.Pos
			task.delay(impactDelay(u, target), function()
				if not valid(u, myMatch) then
					return
				end
				local center = target.Alive and target.Pos or saved
				local extra = nearestTo(center, rune.Radius, { [target] = true }, rune.MaxTargets)
				Remotes.Impact:FireAllClients({ K = "LanternHeart", P = center, R = rune.Radius, U = u.Uid, L = u.Level, N = #extra })
				for _, e in ipairs(extra) do
					damageEnemy(e, stats.Damage * rune.Mult, false, u, true)
				end
			end)
		end
	elseif runeId == "CursedThreads" then
		-- каждая 5-я обычная атака: замедление до 3 врагов на 25% (боссы — вдвое слабее), не суммируется
		u.RuneCount = (u.RuneCount or 0) + 1
		if u.RuneCount % rune.EveryNth == 0 then
			task.delay(impactDelay(u, target), function()
				if not valid(u, myMatch) then
					return
				end
				local first = target.Alive and target or nil
				local center = first and first.Pos or target.Pos
				local list2 = first and { first } or {}
				for _, e in ipairs(nearestTo(center, 8, { [target] = true }, rune.MaxTargets - #list2)) do
					list2[#list2 + 1] = e
				end
				local ids = {}
				for i, e in ipairs(list2) do
					applySlow(e, rune.Slow, rune.SlowTime)
					ids[i] = e.Id
				end
				Remotes.Impact:FireAllClients({ K = "CursedThreads", P = center, A = ids, U = u.Uid, L = u.Level, DUR = rune.SlowTime })
			end)
		end
	elseif runeId == "PhantomCrown" then
		-- 30%: призрачная копия повторяет атаку через 0.3 с со 100% урона, не задерживая следующую атаку
		if rng:NextNumber() < rune.Chance then
			task.delay(rune.Delay, function()
				if not valid(u, myMatch) or phase ~= "Wave" and phase ~= "Intermission" and phase ~= "Prep" then
					return
				end
				local pool = candidates(u, stats.Range)
				if target.Alive and PathUtil.FlatDistance(target.Pos, u.Pos) <= stats.Range then
					for i, e in ipairs(pool) do
						if e == target then
							table.remove(pool, i)
							break
						end
					end
					table.insert(pool, 1, target)
				end
				if #pool == 0 then
					return -- целей нет — повтор отменяется
				end
				Remotes.Impact:FireAllClients({ K = "PhantomEcho", P = u.Pos, U = u.Uid, L = u.Level })
				echoAttack = true
				local ok, err = pcall(attack, u, stats, pool)
				echoAttack = false
				if not ok then
					warn("[VOID TD] echo: " .. tostring(err))
				end
			end)
		end
	end
end

local function normalAttack(u, stats, list)
	attack(u, stats, list)
	if u.Rune then
		runeAfterAttack(u, stats, list)
	end
end

-- Способность вместо каждой N-й обычной атаки
local function castPower(u, stats, list)
	local def = u.Def
	local P = def.Power
	local target = list[1]
	local myMatch = matchId
	local delay = P.Delay or 0.45
	local saved = target.Pos
	-- длинная анимация способности не обрывается следующей атакой
	u.NextAttack = math.max(u.NextAttack, now() + delay + 0.25)
	Remotes.Attack:FireAllClients({ U = u.Uid, T = { target.Id }, L = u.Level, D = delay, AB = P.Anim })
	task.delay(delay, function()
		if not valid(u, myMatch) then
			return
		end
		local center = target.Alive and target.Pos or saved
		if P.Mode == "Single" then
			local e = target.Alive and target or candidates(u, stats.Range + 2)[1]
			if not e then
				return
			end
			Remotes.Impact:FireAllClients({ K = P.Kind, P = e.Pos, I = e.Id, U = u.Uid, L = u.Level, DUR = P.MarkTime })
			if P.Mark then
				e.Mark = P.Mark
				e.MarkUntil = now() + (P.MarkTime or 3)
			end
			local dmg, crit = rollDamage(stats)
			damageEnemy(e, dmg * (P.Mult or 1), crit or true, u)
		elseif P.Mode == "Zone" then
			local radius = (stats.Explode or 5) * (P.RadiusMult or 1.5)
			aoeHit(u, center, radius, stats, P.Kind .. "Burst", { Mult = 0.5 })
			poisonZone(u, center, radius, P.Duration or 5, (stats.PoisonDps or stats.Damage * 0.3) * (P.Mult or 1), P.Kind)
		else
			local radius = stats.PowerRadius or P.Radius or ((stats.AOERadius or 5) + (P.RadiusAdd or 0))
			if P.Mode == "Self" then
				center = u.Pos
				radius = stats.PowerRadius or P.Radius or ((stats.AOERadius or stats.Range) + (P.RadiusAdd or 1))
			end
			aoeHit(u, center, radius, stats, P.Kind, {
				Mult = P.Mult, Slow = P.Slow, SlowTime = P.SlowTime,
				Bleed = P.Burn and stats.Damage * P.Burn or nil, BleedTime = P.BurnTime, DotKind = "Burn",
			})
		end
	end)
end

-- СОЮЗНИКИ
local function spawnAlly(u, allyId, hp, source, index)
	nextAllyId = nextAllyId + 1
	local a = {
		Id = nextAllyId,
		AllyId = allyId,
		HP = hp,
		MaxHP = hp,
		Dist = math.max(1, PathUtil.Length - (S.AllyStartBack or 4) - (index or 0) * 2.2),
		Lateral = rng:NextNumber(-1.6, 1.6),
		Speed = S.AllySpeed or 6,
		Owner = u,
		Source = source,
		Born = now(),
		Alive = true,
	}
	a.Pos = PathUtil.OffsetPositionAt(a.Dist, a.Lateral)
	allies[a.Id] = a
	return a
end

local function alliesOf(u, source)
	local list = {}
	for _, a in pairs(allies) do
		if a.Owner == u and a.Source == source then
			list[#list + 1] = a
		end
	end
	table.sort(list, function(x, y)
		return x.Id < y.Id
	end)
	return list
end

-- Призыв Кукловода / Иллюзиониста: не больше Max живых, лишние не появляются
local function castSummon(u, t)
	local sm = u.Def.Summon
	local lv = sm.Levels[u.Level]
	u.NextSummon = t + lv.Interval
	local alive = #alliesOf(u, "Summon")
	local count = math.min(lv.Count, sm.Max - alive)
	if count <= 0 then
		return
	end
	u.SummonCount = (u.SummonCount or 0) + 1
	local golden = sm.Golden and u.Level >= #u.Def.Levels and u.SummonCount % sm.Golden.Every == 0
	local ids = {}
	for i = 1, count do
		local a
		if golden and i == 1 then
			a = spawnAlly(u, sm.Golden.Ally, sm.Golden.HP, "Summon", i - 1)
		else
			a = spawnAlly(u, lv.Ally, lv.HP, "Summon", i - 1)
		end
		ids[i] = a.Id
	end
	Remotes.Attack:FireAllClients({ U = u.Uid, T = {}, L = u.Level, D = 0.6, AB = "Summon" })
	Remotes.Impact:FireAllClients({ K = "SummonPortal", S = sm.Portal, P = PathUtil.PositionAt(PathUtil.Length - (S.AllyStartBack or 4)), U = u.Uid, L = u.Level, A = ids, G = golden or nil })
end

-- «Проклятые нити»: ровно каждые 60 с, не больше 3 живых, лишний — самый старый — исчезает
local function runeSummon(u, t)
	local sm = Config.Runes.CursedThreads.Summon
	u.NextRuneSummon = u.NextRuneSummon + sm.Interval
	local lv = sm.Levels[u.Level]
	local ids = {}
	for i = 1, lv.Count do
		local a = spawnAlly(u, lv.Ally, lv.HP, "Rune", i - 1)
		ids[i] = a.Id
	end
	local list = alliesOf(u, "Rune")
	for i = 1, #list - sm.Max do
		removeAlly(list[i], "replaced")
	end
	Remotes.Impact:FireAllClients({ K = "CursedCircle", P = PathUtil.PositionAt(PathUtil.Length - (S.AllyStartBack or 4)), U = u.Uid, L = u.Level, A = ids })
end

local function updateAllies(t, dt)
	for _, a in pairs(allies) do
		if a.Alive then
			a.Dist = a.Dist - a.Speed * dt
			if a.Dist <= 0 then
				removeAlly(a, "portal")
			else
				a.Pos = PathUtil.OffsetPositionAt(a.Dist, a.Lateral)
				-- столкновение: враг дошёл до союзника (окно с запасом для большого dt)
				for _, e in pairs(enemies) do
					if e.Alive and e.Dist >= a.Dist - 1.4 - (e.IsBoss and 1.2 or 0) and e.Dist <= a.Dist + 3 then
						local cost = e.Def.FireAura or 1
						local dealt = rawDamage(e, math.min(a.HP / cost, e.Health), a.Owner)
						a.HP = a.HP - dealt * cost
						Remotes.Impact:FireAllClients({ K = "AllyHit", P = a.Pos, I = a.Id, E = e.Id, F = cost > 1 or nil })
						if a.HP <= 0.5 then
							removeAlly(a, "dead")
							break
						end
					end
				end
			end
		end
	end
end

local function castBloodMoon(u, stats, list)
	local bm = stats.BloodMoon
	local myMatch = matchId
	local target = list[1]
	local pos = PathUtil.PositionAt(math.min(target.Dist + 3, PathUtil.Length - 1))
	Remotes.Attack:FireAllClients({ U = u.Uid, T = { target.Id }, L = u.Level, D = 0.6, AB = true })
	Remotes.Impact:FireAllClients({ K = "BloodMoonFall", P = pos, R = bm.Radius, L = u.Level, U = u.Uid, DL = 1.0 })
	task.delay(1.0, function()
		if valid(u, myMatch) then
			local big = { Damage = stats.Damage * (bm.Mult or 3) }
			aoeHit(u, pos, bm.Radius, big, "BloodMoon", { Bleed = bm.Bleed, BleedTime = bm.BleedTime })
		end
	end)
end

local function castBlackHole(u, stats, list)
	local bh = stats.BlackHole
	local target = list[1]
	local pos = PathUtil.PositionAt(math.min(target.Dist + 4, PathUtil.Length - 1))
	local zone = {
		Pos = pos,
		Radius = bh.Radius,
		Until = now() + 0.6 + bh.Duration,
		NextTick = now() + 0.6,
		Tick = bh.Tick,
		TickDamage = bh.TickDamage,
		Slow = bh.Slow,
		Unit = u,
	}
	Remotes.Attack:FireAllClients({ U = u.Uid, T = { target.Id }, L = u.Level, D = 0.6, AB = true })
	Remotes.Impact:FireAllClients({ K = "BlackHole", P = pos, R = bh.Radius, L = u.Level, U = u.Uid, DUR = bh.Duration, DL = 0.6 })
	zones[#zones + 1] = zone
end

local function updateZones(t)
	for i = #zones, 1, -1 do
		local z = zones[i]
		if t >= z.Until or not z.Unit.Alive then
			table.remove(zones, i)
		elseif t >= z.NextTick then
			z.NextTick = z.NextTick + z.Tick
			for _, e in pairs(enemies) do
				if e.Alive and PathUtil.FlatDistance(e.Pos, z.Pos) <= z.Radius then
					if z.Slow and z.Slow > 0 then
						local slow = z.Slow * (e.IsBoss and S.BossSlowResist or 1)
						e.SlowUntil = t + z.Tick + 0.15
						e.SlowAmount = math.max(slow, (e.SlowUntil > t and e.SlowAmount) or 0)
					end
					damageEnemy(e, z.TickDamage, false, z.Unit, true)
				end
			end
		end
	end
end

local function updateUnits(t)
	for _, u in pairs(units) do
		local stats = u.Def.Levels[u.Level]
		if stats.BlackHole and t >= u.NextAbility then
			local list = candidates(u, stats.Range + (u.Def.BlackHoleExtraRange or 6))
			if #list > 0 then
				castBlackHole(u, stats, list)
				u.NextAbility = t + stats.BlackHole.Cooldown
				u.NextAttack = math.max(u.NextAttack, t + 0.9)
			end
		end
		if stats.BloodMoon and t >= u.NextAbility then
			local list = candidates(u, stats.Range + (u.Def.AbilityExtraRange or 6))
			if #list > 0 then
				castBloodMoon(u, stats, list)
				u.NextAbility = t + stats.BloodMoon.Cooldown
				u.NextAttack = math.max(u.NextAttack, t + 1.0)
			end
		end
		if u.Def.TimeHaste or u.Def.TimeStorm then
			updateChrono(u, stats, t)
		end
		if u.Def.Summon and t >= u.NextSummon then
			castSummon(u, t)
		end
		if u.NextRuneSummon and t >= u.NextRuneSummon then
			runeSummon(u, t)
		end
		if t >= u.NextAttack then
			local list = candidates(u, stats.Range)
			if #list > 0 then
				-- ускорение времени: союзник атакует чаще, урон за удар прежний
				local cd = stats.Cooldown
				if (u.HasteUntil or 0) > t then
					cd = cd / (1 + (u.Haste or 0))
				end
				u.NextAttack = t + cd
				local P = u.Def.Power
				if P then
					u.PowerCount = (u.PowerCount or 0) + 1
				end
				if P and u.PowerCount % P.N == 0 then
					castPower(u, stats, list)
				else
					normalAttack(u, stats, list)
				end
			end
		end
	end
end

------------------------------------------------------------------------
-- ЦИКЛ
------------------------------------------------------------------------
local function updateEnemies(t, dt)
	local reached = {}
	for _, e in pairs(enemies) do
		local mult = 1
		if (e.FrozenUntil or 0) > t then
			mult = 0
		elseif e.SlowUntil > t then
			mult = 1 - e.SlowAmount
		else
			e.SlowAmount = 0
		end
		-- ускорения: туман, рывок босса, ярость (замедление и заморозка действуют поверх)
		local boost = (e.EnrageSpeed or 0)
		if (e.FogUntil or 0) > t then
			boost = boost + (e.FogAmount or 0)
		end
		if (e.HasteUntil or 0) > t then
			boost = boost + e.Def.Haste.Speed
		end
		mult = mult * (1 + boost)
		local def = e.Def
		if e.NextPhase and t >= e.NextPhase then
			e.NextPhase = t + def.Phase.Every
			e.PhasedUntil = t + def.Phase.Duration
			enemyState(e, "Phase", def.Phase.Duration)
		end
		if e.NextShield and t >= e.NextShield then
			e.NextShield = t + def.Shield.Every
			e.ShieldUntil = t + def.Shield.Duration
			enemyState(e, "Shield", def.Shield.Duration)
		end
		if e.NextHaste and t >= e.NextHaste then
			e.NextHaste = t + def.Haste.Every
			e.HasteUntil = t + def.Haste.Duration
			enemyState(e, "Haste", def.Haste.Duration)
		end
		if e.NextFog and t >= e.NextFog then
			-- туман: враги рядом (и сам колдун) ускоряются; одинаковый туман не суммируется
			local fog = def.Fog
			e.NextFog = t + fog.Every
			for _, o in pairs(enemies) do
				if PathUtil.FlatDistance(o.Pos, e.Pos) <= fog.Radius then
					o.FogAmount = math.max((o.FogUntil or 0) > t and o.FogAmount or 0, fog.Speed)
					o.FogUntil = math.max(o.FogUntil or 0, t + fog.Duration)
				end
			end
			Remotes.Impact:FireAllClients({ K = "Fog", P = e.Pos, R = fog.Radius, I = e.Id, DUR = fog.Duration })
		end
		e.Dist = e.Dist + e.Speed * mult * dt
		e.Pos = enemyPos(e)
		if e.NextSummon and t >= e.NextSummon then
			e.NextSummon = t + e.Def.Summon.Interval
			pendingSpawns[#pendingSpawns + 1] = { e.Def.Summon.Enemy, e.Def.Summon.Count, math.max(e.Dist - 3, 0), e.Pos }
		end
		if e.Dist >= PathUtil.Length then
			reached[#reached + 1] = e
		end
	end
	for _, e in ipairs(reached) do
		removeEnemy(e, "core")
		damageCore(e.Def.CoreDamage)
	end
	if #pendingSpawns > 0 then
		local list = pendingSpawns
		pendingSpawns = {}
		for _, s in ipairs(list) do
			Remotes.Impact:FireAllClients({ K = s[5] or "Summon", P = s[4], R = 6 })
			for k = 1, s[2] do
				spawnEnemy(s[1], s[3] - k * 1.5)
			end
		end
	end
end

local function sync(t)
	local list = {}
	for _, e in pairs(enemies) do
		list[#list + 1] = e.Id
		list[#list + 1] = math.floor(e.Dist * 100) / 100
		list[#list + 1] = math.max(0, e.Health)
		list[#list + 1] = ((e.FrozenUntil or 0) > t) and 2 or ((e.SlowUntil > t) and 1 or 0)
	end
	-- союзники: id, дистанция, HP, тип (индекс в Config.AllyOrder), максимум HP
	local al
	if next(allies) or #allyRemoved > 0 then
		al = {}
		for _, a in pairs(allies) do
			al[#al + 1] = a.Id
			al[#al + 1] = math.floor(a.Dist * 100) / 100
			al[#al + 1] = math.floor(a.HP + 0.5)
			al[#al + 1] = allyIndex[a.AllyId] or 1
			al[#al + 1] = a.MaxHP
		end
	end
	Remotes.Sync:FireAllClients({ T = t, E = list, DMG = damageBuffer, RM = removedBuffer, AL = al, RA = #allyRemoved > 0 and allyRemoved or nil })
	damageBuffer = {}
	removedBuffer = {}
	allyRemoved = {}
end

local function step(dt)
	local t = now()
	if phase == "Wave" or phase == "Intermission" or phase == "Prep" then
		updateEnemies(t, dt)
		updateAllies(t, dt)
		updateZones(t)
		updateDots(t)
		updateUnits(t)
	end
	if phase == "Wave" and not waveSpawning and next(enemies) == nil then
		waveCleared()
	elseif phase == "Intermission" and t >= nextWaveAt then
		startWave()
	end
	if t - lastSync >= S.SyncRate then
		lastSync = t
		sync(t)
	end
	if t - lastAttrFlush >= 1 then
		lastAttrFlush = t
		for _, u in pairs(units) do
			u.Folder:SetAttribute("Damage", math.floor(u.DamageDealt))
		end
	end
end

local function clearMatch()
	matchId = matchId + 1
	clearEnemies()
	for _, u in pairs(units) do
		removeUnit(u)
	end
	units = {}
	for _, a in pairs(allies) do
		removeAlly(a, "clear")
	end
	allies = {}
	wave = 0
	waveSpawning = false
	nextWaveAt = 0
	setState("Wave", 0)
	setState("NextWaveAt", 0)
	setState("MatchId", matchId)
end

-- Матч закончен (или все ушли): все возвращаются в лобби
local function setMapMode(mode)
	matchMode = mode
	PathUtil.SetMap(mode)
	maxWave = (Config.Maps[mode] and Config.Maps[mode].MaxWave) or S.MaxWave
	setState("Map", mode)
	setState("MaxWave", maxWave)
end

resetMatch = function()
	local wasHalloween = matchMode == "Halloween"
	clearMatch()
	phase = "Idle"
	setState("Phase", phase)
	setState("Difficulty", "")
	for _, pl in ipairs(Players:GetPlayers()) do
		if inMatch(pl) then
			pl:SetAttribute("InMatch", false)
			setMoney(pl, 0)
			-- чёрный экран-переход, затем телепорт в лобби (после Хэллоуин-матча — на остров)
			Remotes.Notify:FireClient(pl, { Type = "Fade", Text = wasHalloween and "HALLOWEEN" or "ЛОББИ" })
			task.delay(0.45, function()
				toLobby(pl, wasHalloween)
			end)
		end
	end
	roster = {}
	setMapMode("Void")
	notifyAll({ Type = "Reset" })
end

local function startNewMatch(diffKey, mode)
	clearMatch()
	setMapMode(mode or "Void")
	difficultyKey = diffKey
	D = Config.Difficulties[diffKey]
	coreHP = D.CoreHP
	phase = "Prep"
	setState("Difficulty", diffKey)
	setState("CoreMaxHP", coreHP)
	setState("CoreHP", coreHP)
	setState("Phase", phase)
end

function GameService.JoinMatch(player, diffKey)
	if inMatch(player) then
		return false, "Ты уже в матче"
	end
	if phase == "Victory" or phase == "Defeat" then
		return false, "Матч завершается, подожди пару секунд"
	end
	if phase ~= "Idle" and matchMode == "Halloween" then
		return false, "Сейчас идёт Хэллоуин-матч. Подожди, пока он закончится"
	end
	if phase == "Idle" then
		if not Config.Difficulties[diffKey] then
			return false, "Выбери сложность"
		end
		startNewMatch(diffKey)
	end
	player:SetAttribute("InMatch", true)
	-- поздно зашедшим даём компенсацию за пропущенные волны
	setMoney(player, (S.StartMoney + math.max(0, wave - 1) * 150) * D.Money)
	toBattle(player)
	notifyAll({ Type = "Toast", Text = player.DisplayName .. " вступил в бой (" .. D.Name .. ")", Kind = "good" })
	return true, difficultyKey
end

-- Хэллоуин-матч: все игроки из очереди попадают в один матч
function GameService.CanStartHalloween()
	return phase == "Idle"
end

function GameService.StartHalloween(players, diffKey)
	if phase ~= "Idle" then
		return false, "Арена занята — идёт другой матч"
	end
	if not table.find(Config.Halloween.Difficulties, diffKey) then
		return false, "Неверная сложность"
	end
	startNewMatch(diffKey, "Halloween")
	roster = {}
	for _, pl in ipairs(players) do
		if pl.Parent and not inMatch(pl) then
			roster[pl.UserId] = true
			pl:SetAttribute("InMatch", true)
			setMoney(pl, S.StartMoney * D.Money)
			Remotes.Notify:FireClient(pl, { Type = "Fade", Text = "HAUNTED HOLLOW" })
			task.delay(0.45, function()
				toBattle(pl)
			end)
		end
	end
	if #matchPlayers() == 0 then
		resetMatch()
		return false, "Никого нет в очереди"
	end
	notifyAll({ Type = "Toast", Text = "🎃 Хэллоуин-матч начался (" .. D.Name .. ")", Kind = "good" })
	return true
end

function GameService.GetMode()
	return matchMode, phase
end

function GameService.LeaveMatch(player)
	if not inMatch(player) then
		return false, "Ты не в матче"
	end
	for _, u in pairs(units) do
		if u.Owner == player then
			removeUnit(u)
		end
	end
	player:SetAttribute("InMatch", false)
	setMoney(player, 0)
	toLobby(player, matchMode == "Halloween")
	if #matchPlayers() == 0 and phase ~= "Idle" then
		resetMatch()
	end
	return true
end

function GameService.GetMatchInfo()
	return { Phase = phase, Difficulty = difficultyKey, Wave = wave, Players = #matchPlayers(), Mode = matchMode }
end

------------------------------------------------------------------------
-- ИГРОКИ
------------------------------------------------------------------------
function GameService.PlayerAdded(player)
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	local money = Instance.new("IntValue")
	money.Name = "Money"
	money.Parent = ls
	ls.Parent = player
	player:SetAttribute("InMatch", false)
	setMoney(player, 0)
	-- после смерти игрок в матче возвращается на карту, остальные — в лобби
	player.CharacterAdded:Connect(function(char)
		char:WaitForChild("HumanoidRootPart", 5)
		task.wait(0.2)
		if inMatch(player) then
			toBattle(player)
		else
			toLobby(player, player:GetAttribute("Island") == true)
		end
	end)
end

function GameService.PlayerRemoving(player)
	for _, u in pairs(units) do
		if u.Owner == player then
			removeUnit(u)
		end
	end
	player:SetAttribute("InMatch", false)
	task.defer(function()
		if #matchPlayers() == 0 and phase ~= "Idle" then
			resetMatch()
		end
	end)
end

function GameService.GetEnemySnapshot()
	local list = {}
	for _, e in pairs(enemies) do
		list[#list + 1] = { e.Id, e.Type, e.MaxHealth, e.Speed, e.Lateral, e.Dist, e.Health }
	end
	return list
end

function GameService.Init(remotes, state, unitsFolder, map, maps)
	Remotes, State, UnitsFolder, Map = remotes, state, unitsFolder, map
	MapModels = maps or { Void = map }
	MapModels.Void = MapModels.Void or map
	setState("MaxWave", S.MaxWave)
	setState("CoreMaxHP", S.CoreMaxHP)
	setState("CoreHP", S.CoreMaxHP)
	setState("BossId", 0)
	setState("BossName", "")
	resetMatch()
	RunService.Heartbeat:Connect(step)
end

-- Доступ к внутреннему состоянию для автотестов (в игре не используется)
function GameService.Debug()
	return {
		Units = units, Enemies = enemies, Spawn = spawnEnemy, Now = now,
		Allies = function()
			return allies
		end,
		Mode = function()
			return matchMode, roster
		end,
	}
end

return GameService
