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
	teleport(player, Config.BattleSpawn)
end

local function toLobby(player)
	teleport(player, Config.Lobby.Spawn)
end

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
		Alive = true,
		Wave = wave,
	}
	if def.Summon then
		e.NextSummon = now() + def.Summon.Interval
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
	removeEnemy(e, "kill")
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
	local dmg = math.max(1, math.floor(amount * (1 - e.Armor) + 0.5))
	e.Health = e.Health - dmg
	pushDamage(e.Id, dmg, crit and 1 or 0)
	if unit then
		unit.DamageDealt = unit.DamageDealt + math.min(dmg, dmg + e.Health)
	end
	if e.Health <= 0 then
		killEnemy(e)
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
		notifyAll({ Type = "Victory", Wave = wave, Gems = g, Reset = S.ResetDelay, Difficulty = difficultyKey })
	else
		for _, pl in ipairs(matchPlayers()) do
			local prof = DataService.Get(pl)
			if prof then
				prof.Stats.BestWave = math.max(prof.Stats.BestWave or 0, wave - 1)
				DataService.Save(pl, true)
			end
		end
		notifyAll({ Type = "Defeat", Wave = wave, Reset = S.ResetDelay, Difficulty = difficultyKey })
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
	if wave >= S.MaxWave then
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
	local groups = Config.Waves[wave] or {}
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

local function removeUnit(u)
	u.Alive = false
	units[u.Uid] = nil
	if u.Folder then
		u.Folder:Destroy()
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
	raycastParams.FilterDescendantsInstances = { Map }
	local hit = workspace:Raycast(Vector3.new(pos.X, Config.Map.GroundY + 30, pos.Z), Vector3.new(0, -60, 0), raycastParams)
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
	local payload = { U = u.Uid, T = targetIds, L = u.Level }
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

local function aoeHit(u, center, radius, stats, kind)
	-- один удар = один набор целей: каждый враг получает урон ровно один раз
	local hitSet = {}
	for _, e in pairs(enemies) do
		if e.Alive and PathUtil.FlatDistance(e.Pos, center) <= radius + (e.IsBoss and 1.5 or 0.5) then
			hitSet[#hitSet + 1] = e
		end
	end
	Remotes.Impact:FireAllClients({ K = kind, P = center, R = radius, L = u.Level, U = u.Uid, N = #hitSet })
	for _, e in ipairs(hitSet) do
		local dmg, crit = rollDamage(stats)
		damageEnemy(e, dmg, crit, u)
	end
end

local function attack(u, stats, list)
	local def = u.Def
	local myMatch = matchId
	local hitDelay = def.HitDelay or 0.2
	local target = list[1]

	if def.AttackType == "Melee" or def.AttackType == "Laser" then
		fireAttack(u, { target.Id }, { D = hitDelay })
		task.delay(hitDelay, function()
			if valid(u, myMatch) and target.Alive then
				local dmg, crit = rollDamage(stats)
				damageEnemy(target, dmg, crit, u)
			end
		end)
	elseif def.AttackType == "Projectile" then
		local travel = PathUtil.FlatDistance(u.Pos, target.Pos) / (def.ProjectileSpeed or 80)
		fireAttack(u, { target.Id }, { D = hitDelay, TR = travel })
		task.delay(hitDelay + travel, function()
			if valid(u, myMatch) and target.Alive then
				local dmg, crit = rollDamage(stats)
				damageEnemy(target, dmg, crit, u)
			end
		end)
	elseif def.AttackType == "AOE" then
		local saved = target.Pos
		fireAttack(u, { target.Id }, { D = hitDelay })
		task.delay(hitDelay, function()
			if not valid(u, myMatch) then
				return
			end
			local center = target.Alive and target.Pos or saved
			local kind = def.ImpactKind or "Reap"
			aoeHit(u, center, stats.AOERadius or 6, stats, kind)
		end)
	elseif def.AttackType == "MultiHit" then
		local hits = stats.Hits or 1
		local interval = def.HitInterval or 0.15
		local spread = (u.Id == "VoidEmperor")
		local ids = {}
		local plan = {}
		for h = 1, hits do
			local e = spread and list[((h - 1) % #list) + 1] or target
			plan[h] = e
			ids[h] = e.Id
		end
		fireAttack(u, ids, { D = hitDelay, I = interval })
		for h = 1, hits do
			task.delay(hitDelay + (h - 1) * interval, function()
				if not valid(u, myMatch) then
					return
				end
				local e = plan[h]
				if not e.Alive then
					-- цель умерла — ищем следующую в радиусе
					local fresh = candidates(u, stats.Range)
					e = fresh[1]
				end
				if e then
					local dmg, crit = rollDamage(stats)
					if spread then
						Remotes.Impact:FireAllClients({ K = "Judgement", P = e.Pos, L = u.Level, U = u.Uid, H = h })
					end
					damageEnemy(e, dmg, crit, u)
				end
			end)
		end
	end
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
					local slow = z.Slow * (e.IsBoss and S.BossSlowResist or 1)
					e.SlowUntil = t + z.Tick + 0.15
					e.SlowAmount = math.max(slow, (e.SlowUntil > t and e.SlowAmount) or 0)
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
		if t >= u.NextAttack then
			local list = candidates(u, stats.Range)
			if #list > 0 then
				attack(u, stats, list)
				u.NextAttack = t + stats.Cooldown
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
		if e.SlowUntil > t then
			mult = 1 - e.SlowAmount
		else
			e.SlowAmount = 0
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
			Remotes.Impact:FireAllClients({ K = "Summon", P = s[4], R = 6 })
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
		list[#list + 1] = (e.SlowUntil > t) and 1 or 0
	end
	Remotes.Sync:FireAllClients({ T = t, E = list, DMG = damageBuffer, RM = removedBuffer })
	damageBuffer = {}
	removedBuffer = {}
end

local function step(dt)
	local t = now()
	if phase == "Wave" or phase == "Intermission" or phase == "Prep" then
		updateEnemies(t, dt)
		updateZones(t)
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
	wave = 0
	waveSpawning = false
	nextWaveAt = 0
	setState("Wave", 0)
	setState("NextWaveAt", 0)
	setState("MatchId", matchId)
end

-- Матч закончен (или все ушли): все возвращаются в лобби
resetMatch = function()
	clearMatch()
	phase = "Idle"
	setState("Phase", phase)
	setState("Difficulty", "")
	for _, pl in ipairs(Players:GetPlayers()) do
		if inMatch(pl) then
			pl:SetAttribute("InMatch", false)
			setMoney(pl, 0)
			toLobby(pl)
		end
	end
	notifyAll({ Type = "Reset" })
end

local function startNewMatch(diffKey)
	clearMatch()
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
	toLobby(player)
	if #matchPlayers() == 0 and phase ~= "Idle" then
		resetMatch()
	end
	return true
end

function GameService.GetMatchInfo()
	return { Phase = phase, Difficulty = difficultyKey, Wave = wave, Players = #matchPlayers() }
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
			toLobby(player)
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

function GameService.Init(remotes, state, unitsFolder, map)
	Remotes, State, UnitsFolder, Map = remotes, state, unitsFolder, map
	setState("MaxWave", S.MaxWave)
	setState("CoreMaxHP", S.CoreMaxHP)
	setState("CoreHP", S.CoreMaxHP)
	setState("BossId", 0)
	setState("BossName", "")
	resetMatch()
	RunService.Heartbeat:Connect(step)
end

return GameService
