--!nocheck
-- VOID TD :: Sim.Units
-- Юниты на карте: установка (все проверки сервера), улучшение, продажа, режим цели, такт юнита
-- (способности, призывы, атака по кулдауну). Каждый юнит — Folder в ReplicatedStorage.VoidTD.Units
-- с атрибутами UnitId Level OwnerId OwnerName Position Rotation TargetMode Spent Damage [Rune Storm].

return function(Sim)
	local Config, Path, S = Sim.Config, Sim.Path, Sim.S
	local units = Sim.units
	local flat = Path.FlatDistance

	local function isFinite(n)
		return type(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge
	end

	local function counts(player, unitId)
		local total, same = 0, 0
		for _, u in pairs(units) do
			if u.Owner == player then
				total += 1
				if u.Id == unitId then
					same += 1
				end
			end
		end
		return total, same
	end

	function Sim.RemoveUnit(u)
		u.Alive = false
		units[u.Uid] = nil
		if u.Folder then
			u.Folder:Destroy()
		end
		-- проданный юнит забирает своих союзников; его зоны и DoT гаснут сами
		for _, a in pairs(Sim.allies) do
			if a.Owner == u then
				Sim.RemoveAlly(a, "sold")
			end
		end
	end

	function Sim.RemovePlayerUnits(player)
		for _, u in pairs(units) do
			if u.Owner == player then
				Sim.RemoveUnit(u)
			end
		end
	end

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Include

	-- Проверка фазы и участия в матче — Match.CanPlace (Router вызывает до этого)
	function Sim.PlaceUnit(player, unitId, pos, rotation)
		local def = type(unitId) == "string" and Config.Units[unitId]
		if not def or typeof(pos) ~= "Vector3" then
			return false, "Неверный запрос"
		end
		if not (isFinite(pos.X) and isFinite(pos.Y) and isFinite(pos.Z)) then
			return false, "Неверная позиция"
		end
		if not Sim.Data.IsEquipped(player, unitId) then
			return false, "Юнит не экипирован"
		end
		local cost = def.Levels[1].Cost
		if not Sim.Economy.Has(player, cost) then
			return false, "Недостаточно денег"
		end
		local total, same = counts(player, unitId)
		if total >= S.MaxUnitsPerPlayer then
			return false, "Лимит юнитов: " .. S.MaxUnitsPerPlayer
		end
		local rarity = Config.Rarities[def.Rarity]
		local limit = rarity and rarity.PlacementLimit or 1
		if same >= limit then
			return false, "Лимит " .. def.Name .. ": " .. limit
		end
		local ok, why = Path.IsPlacementClear(pos)
		if not ok then
			return false, why
		end
		-- под ногами — остров текущей карты
		local mapModel = Sim.Maps[Sim.Mode]
		if not mapModel then
			return false, "Сюда ставить нельзя"
		end
		rayParams.FilterDescendantsInstances = { mapModel }
		local hit = workspace:Raycast(Vector3.new(pos.X, Path.Map.GroundY + 30, pos.Z), Vector3.new(0, -60, 0), rayParams)
		if not hit or not hit.Instance:GetAttribute("Placeable") then
			return false, "Сюда ставить нельзя"
		end
		local ground = Vector3.new(pos.X, hit.Position.Y, pos.Z)
		for _, o in pairs(units) do
			if flat(o.Pos, ground) < S.PlacementSpacing then
				return false, "Слишком близко к другому юниту"
			end
		end
		rotation = tonumber(rotation)
		if not isFinite(rotation) then
			rotation = 0
		end
		rotation = rotation % 360

		Sim.Economy.Add(player, -cost)
		Sim.ids.Unit += 1
		local t = Sim.now()
		local u = {
			Uid = Sim.ids.Unit,
			Id = unitId,
			Def = def,
			Owner = player,
			Level = 1,
			Pos = ground,
			Rotation = rotation,
			TargetMode = def.DefaultTarget or "First",
			NextAttack = t + 0.6,
			NextAbility = t + 1.5,
			PlacedAt = t,
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
		f:SetAttribute("Rotation", rotation)
		f:SetAttribute("TargetMode", u.TargetMode)
		f:SetAttribute("Spent", cost)
		f:SetAttribute("Damage", 0)
		u.Folder = f
		-- таймеры способностей времени стартуют после установки
		if def.TimeHaste then
			u.NextHaste = t + def.TimeHaste.FirstDelay
		end
		if def.TimeStorm then
			u.NextStorm = t + def.TimeStorm.FirstDelay
			f:SetAttribute("Storm", false)
		end
		-- призыв союзников: первый — через интервал 1-го уровня
		if def.Summon then
			u.NextSummon = t + def.Summon.Levels[1].Interval
			u.SummonCount = 0
		end
		-- руна читается из профиля в момент установки
		u.Rune = Sim.Data.GetRune(player, unitId)
		if u.Rune then
			f:SetAttribute("Rune", u.Rune)
			if u.Rune == "CursedThreads" then
				u.NextRuneSummon = t + Config.Runes.CursedThreads.Summon.Interval
			end
		end
		f.Parent = Sim.UnitsFolder
		units[u.Uid] = u
		return true, u.Uid
	end

	local function ownedUnit(player, uid)
		uid = tonumber(uid)
		local u = isFinite(uid) and units[uid]
		if not u then
			return nil, "Юнит не найден"
		end
		if u.Owner ~= player then
			return nil, "Это не твой юнит"
		end
		return u
	end

	function Sim.UpgradeUnit(player, uid)
		local u, err = ownedUnit(player, uid)
		if not u then
			return false, err
		end
		if u.Level >= #u.Def.Levels then
			return false, "Максимальный уровень"
		end
		local cost = u.Def.Levels[u.Level + 1].Cost
		if not Sim.Economy.Has(player, cost) then
			return false, "Недостаточно денег"
		end
		Sim.Economy.Add(player, -cost)
		u.Level += 1
		u.Spent += cost
		u.Folder:SetAttribute("Level", u.Level)
		u.Folder:SetAttribute("Spent", u.Spent)
		return true, u.Level
	end

	function Sim.SellUnit(player, uid)
		local u, err = ownedUnit(player, uid)
		if not u then
			return false, err
		end
		local refund = math.floor(u.Spent * S.SellRefund)
		Sim.Economy.Add(player, refund)
		Sim.RemoveUnit(u)
		return true, refund
	end

	function Sim.SetTargetMode(player, uid, mode)
		local u, err = ownedUnit(player, uid)
		if not u then
			return false, err
		end
		if type(mode) ~= "string" or not table.find(Config.TargetModes, mode) then
			return false, "Неверный режим"
		end
		u.TargetMode = mode
		u.Folder:SetAttribute("TargetMode", mode)
		return true
	end

	------------------------------------------------------------------------
	-- ТАКТ ЮНИТОВ
	------------------------------------------------------------------------
	local function normalAttack(u, stats, list)
		Sim.DoAttack(u, stats, list)
		if u.Rune then
			Sim.RuneAfterAttack(u, stats, list)
		end
	end

	local function tickUnit(u, t)
		local def = u.Def
		local stats = def.Levels[u.Level]
		if stats.BlackHole and t >= u.NextAbility then
			local list = Sim.Candidates(u, stats.Range + (def.BlackHoleExtraRange or 6))
			if #list > 0 then
				Sim.CastBlackHole(u, stats, list)
				u.NextAbility = t + stats.BlackHole.Cooldown
				u.NextAttack = math.max(u.NextAttack, t + 0.9)
			end
		end
		if stats.BloodMoon and t >= u.NextAbility then
			local list = Sim.Candidates(u, stats.Range + (def.AbilityExtraRange or 6))
			if #list > 0 then
				Sim.CastBloodMoon(u, stats, list)
				u.NextAbility = t + stats.BloodMoon.Cooldown
				u.NextAttack = math.max(u.NextAttack, t + 1.0)
			end
		end
		if def.TimeHaste or def.TimeStorm then
			Sim.UpdateChrono(u, stats, t)
		end
		if def.Summon and t >= u.NextSummon then
			Sim.CastSummon(u, t)
		end
		if u.NextRuneSummon and t >= u.NextRuneSummon then
			Sim.RuneSummon(u, t)
		end
		if t >= u.NextAttack then
			local list = Sim.Candidates(u, stats.Range)
			if #list > 0 then
				-- ускорение времени: атакует чаще, урон за удар прежний
				local cd = stats.Cooldown
				if (u.HasteUntil or 0) > t then
					cd /= 1 + (u.Haste or 0)
				end
				u.NextAttack = t + cd
				local P = def.Power
				if P then
					u.PowerCount = (u.PowerCount or 0) + 1
				end
				if P and u.PowerCount % P.N == 0 then
					Sim.CastPower(u, stats, list)
				else
					normalAttack(u, stats, list)
				end
			end
		end
	end

	-- ошибка одного юнита не останавливает остальных (warn не чаще раза в 5 с)
	local lastWarn = -math.huge
	function Sim.UpdateUnits(t)
		for _, u in pairs(units) do
			if u.Alive then
				local ok, err = pcall(tickUnit, u, t)
				if not ok and os.clock() - lastWarn > 5 then
					lastWarn = os.clock()
					warn("[VOID TD] unit " .. tostring(u.Id) .. ": " .. tostring(err))
				end
			end
		end
	end
end
