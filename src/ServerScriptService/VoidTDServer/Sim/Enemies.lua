--!nocheck
-- VOID TD :: Sim.Enemies
-- Враги: спавн, движение и особое поведение (фаза, щит, рывок, туман, призыв), урон и его модификаторы
-- (броня, участки брони, фаза/щит/метка), пороги HP (слом брони, ярость), DoT, замедление, заморозка,
-- выбор целей и данные для Sync.

return function(Sim)
	local Config, Path, S = Sim.Config, Sim.Path, Sim.S
	local enemies = Sim.enemies
	local rng = Sim.rng
	local flat = Path.FlatDistance

	local function enemyPos(e)
		return (Path.OffsetPositionAt(e.Dist, e.Lateral))
	end
	Sim.EnemyPos = enemyPos

	local function setState(k, v)
		if Sim.State then
			Sim.State:SetAttribute(k, v)
		end
	end

	-- полоса босса: самый «толстый» живой босс
	function Sim.RefreshBoss()
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
			setState("BossMaxHP", 0)
		end
	end

	function Sim.SpawnEnemy(typeId, startDist, lateral)
		local def = Config.Enemies[typeId]
		if not def then
			return nil
		end
		Sim.ids.Enemy += 1
		local t0 = Sim.now()
		local hp = math.floor(def.Health * Config.WaveHPMult(math.max(Sim.Wave, 1)) * Sim.D.HP)
		local e = {
			Id = Sim.ids.Enemy,
			Type = typeId,
			Def = def,
			MaxHealth = hp,
			Health = hp,
			Speed = def.Speed * Sim.D.Speed,
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
			Wave = Sim.Wave,
		}
		e.BaseArmor = e.Armor
		if def.Summon then
			e.NextSummon = t0 + def.Summon.Interval
		end
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
		Sim.Remotes.EnemySpawn:FireAllClients({ e.Id, typeId, hp, e.Speed, e.Lateral, e.Dist })
		if e.IsBoss then
			Sim.RefreshBoss()
		end
		return e
	end

	function Sim.RemoveEnemy(e, reason)
		if not e.Alive then
			return
		end
		e.Alive = false
		enemies[e.Id] = nil
		Sim.rmBuf[#Sim.rmBuf + 1] = { e.Id, reason }
		if e.IsBoss then
			Sim.RefreshBoss()
		end
	end

	function Sim.ClearEnemies()
		for _, e in pairs(enemies) do
			e.Alive = false
			Sim.rmBuf[#Sim.rmBuf + 1] = { e.Id, "clear" }
		end
		table.clear(enemies)
		table.clear(Sim.zones)
		table.clear(Sim.pending)
		Sim.RefreshBoss()
	end

	-- враги есть, пока кто-то жив или ждёт спавна (минионы с OnDeath/Enrage)
	function Sim.HasEnemies()
		return next(enemies) ~= nil or #Sim.pending > 0
	end

	function Sim.EnemySnapshot()
		local list = {}
		for _, e in pairs(enemies) do
			list[#list + 1] = { e.Id, e.Type, e.MaxHealth, e.Speed, e.Lateral, e.Dist, e.Health }
		end
		return list
	end

	function Sim.EnemySyncList(t)
		local list = {}
		for _, e in pairs(enemies) do
			list[#list + 1] = e.Id
			list[#list + 1] = math.floor(e.Dist * 100) / 100
			list[#list + 1] = math.max(0, e.Health)
			list[#list + 1] = ((e.FrozenUntil or 0) > t) and 2 or ((e.SlowUntil > t) and 1 or 0)
		end
		return list
	end

	function Sim.EnemyState(e, state, dur)
		Sim.Impact({ K = "EnemyState", I = e.Id, S = state, DUR = dur, P = e.Pos })
	end

	local function queueSpawn(typeId, n, startDist, fxPos, fxKind)
		Sim.pending[#Sim.pending + 1] = { typeId, n, startDist, fxPos, fxKind }
	end

	------------------------------------------------------------------------
	-- УРОН
	------------------------------------------------------------------------
	-- множитель получаемого урона: фаза призрака, защита, метка проклятия
	local function takenMult(e, t)
		local m = 1
		if (e.PhasedUntil or 0) > t then
			m *= e.Def.Phase.Taken
		end
		if (e.ShieldUntil or 0) > t then
			m *= e.Def.Shield.Taken
		end
		if (e.MarkUntil or 0) > t then
			m *= 1 + (e.Mark or 0)
		end
		return m
	end

	-- броня с учётом участков дороги (Проклятый монарх)
	local function armorOf(e)
		local a = e.Armor
		local zones = e.Def.ArmorZones
		if zones then
			local f = Path.Fraction(e.Dist)
			for _, z in ipairs(zones) do
				if f >= z[1] and f <= z[2] then
					a += z[3]
				end
			end
		end
		return math.min(a, 0.9)
	end

	-- пороги HP: шкала брони, слом брони, ярость (+ подкрепление)
	local function checkThresholds(e)
		local def = e.Def
		local ratio = e.Health / e.MaxHealth
		if def.ArmorScale then
			e.Armor = e.BaseArmor * math.max(ratio, 0)
		end
		if def.ArmorBreak and not e.ArmorBroken and ratio <= def.ArmorBreak.At then
			e.ArmorBroken = true
			e.Armor = def.ArmorBreak.Armor
			Sim.EnemyState(e, "ArmorBreak")
		end
		if def.Enrage and not e.Enraged and ratio <= def.Enrage.At then
			e.Enraged = true
			e.EnrageSpeed = def.Enrage.Speed or 0
			Sim.EnemyState(e, "Enrage")
			if def.Enrage.Spawn then
				queueSpawn(def.Enrage.Spawn[1], def.Enrage.Spawn[2], math.max(e.Dist - 4, 0), e.Pos, "Fire")
			end
		end
	end

	local function killEnemy(e)
		local reward = math.floor(e.Def.Reward * (1 + S.KillRewardScalePerWave * (math.max(e.Wave, 1) - 1)) * Sim.D.Money + 0.5)
		if e.Def.OnDeath then
			queueSpawn(e.Def.OnDeath.Enemy, e.Def.OnDeath.Count, e.Dist + 1.5, e.Pos, "Straw")
		end
		Sim.RemoveEnemy(e, "kill")
		if Sim.Hooks.OnKill then
			Sim.Hooks.OnKill(e, reward)
		end
	end

	local function pushDamage(id, amount, flag)
		Sim.dmgBuf[#Sim.dmgBuf + 1] = { id, amount, flag }
	end

	-- урон с бронёй и модификаторами. flag в Sync: 0 обычный, 1 крит, 2 уклонение.
	-- -> нанесено (без перебора), уклонился?
	function Sim.DamageEnemy(e, amount, crit, unit, noDodge)
		if not e or not e.Alive then
			return 0, false
		end
		if not noDodge and e.Dodge > 0 and rng:NextNumber() < e.Dodge then
			pushDamage(e.Id, 0, 2)
			return 0, true
		end
		local dmg = math.max(1, math.floor(amount * (1 - armorOf(e)) * takenMult(e, Sim.now()) + 0.5))
		e.Health -= dmg
		pushDamage(e.Id, dmg, crit and 1 or 0)
		local dealt = math.min(dmg, dmg + e.Health)
		if unit then
			unit.DamageDealt += dealt
		end
		if e.Health <= 0 then
			killEnemy(e)
		else
			checkThresholds(e)
		end
		return dealt, false
	end

	-- чистый урон без брони и уклонения (столкновение с союзником). HP врага остаётся целым.
	function Sim.RawDamage(e, amount, unit)
		if not e.Alive or amount <= 0 then
			return 0
		end
		local dmg = math.min(amount, e.Health)
		if e.Health - dmg < 0.5 then
			dmg = e.Health
		else
			dmg = math.floor(dmg + 0.5)
		end
		if dmg <= 0 then
			return 0
		end
		e.Health -= dmg
		pushDamage(e.Id, dmg, 0)
		if unit and unit.Alive then
			unit.DamageDealt += dmg
		end
		if e.Health <= 0 then
			e.Health = 0
			killEnemy(e)
		else
			checkThresholds(e)
		end
		return dmg
	end

	function Sim.RollDamage(stats)
		local dmg = stats.Damage
		if stats.CritChance and rng:NextNumber() < stats.CritChance then
			return dmg * (stats.CritMult or 2), true
		end
		return dmg, false
	end

	------------------------------------------------------------------------
	-- ЭФФЕКТЫ: DoT, замедление, заморозка
	------------------------------------------------------------------------
	-- один источник обновляет свой эффект, разные юниты/виды стакаются
	function Sim.ApplyDot(e, dps, duration, u, kind)
		if not e or not e.Alive or not dps or dps <= 0 then
			return
		end
		local key = tostring(u and u.Uid or 0) .. ":" .. kind
		e.Dots[key] = { Dps = dps, Until = Sim.now() + duration, Unit = u }
	end

	-- не суммируется: сильнейшее и самое долгое; боссы — вполсилы
	function Sim.ApplySlow(e, amount, duration)
		if not e or not e.Alive or not amount then
			return
		end
		local t = Sim.now()
		amount *= e.IsBoss and S.BossSlowResist or 1
		if e.SlowUntil < t then
			e.SlowAmount = 0
		end
		e.SlowAmount = math.max(e.SlowAmount, amount)
		e.SlowUntil = math.max(e.SlowUntil, t + duration)
	end

	function Sim.Freeze(e, duration, t)
		e.FrozenUntil = t + duration
		e.FreezeImmuneUntil = t + duration + (S.FreezeImmunity or 3)
	end

	-- тик DoT раз в 0.5 с; урон делится между источниками по вкладу; DoT проданного юнита исчезает
	local shares = {}
	function Sim.UpdateDots(t)
		for _, e in pairs(enemies) do
			if next(e.Dots) and t >= e.NextDot then
				e.NextDot = t + 0.5
				local total = 0
				table.clear(shares)
				for key, d in pairs(e.Dots) do
					if t >= d.Until or (d.Unit and not d.Unit.Alive) then
						e.Dots[key] = nil
					else
						local part = d.Dps * 0.5
						total += part
						if d.Unit then
							shares[d.Unit] = (shares[d.Unit] or 0) + part
						end
					end
				end
				if total > 0 then
					local dealt = Sim.DamageEnemy(e, total, false, nil, true)
					for u, part in pairs(shares) do
						u.DamageDealt += dealt * part / total
					end
				end
			end
		end
	end

	------------------------------------------------------------------------
	-- ДВИЖЕНИЕ И ПОВЕДЕНИЕ
	------------------------------------------------------------------------
	local reached = {}
	function Sim.UpdateEnemies(t, dt)
		table.clear(reached)
		for _, e in pairs(enemies) do
			local def = e.Def
			local mult = 1
			if (e.FrozenUntil or 0) > t then
				mult = 0
			elseif e.SlowUntil > t then
				mult = 1 - e.SlowAmount
			else
				e.SlowAmount = 0
			end
			-- ускорения: туман, рывок босса, ярость (замедление и заморозка действуют поверх)
			local boost = e.EnrageSpeed or 0
			if (e.FogUntil or 0) > t then
				boost += e.FogAmount or 0
			end
			if (e.HasteUntil or 0) > t then
				boost += def.Haste.Speed
			end
			mult *= 1 + boost
			if e.NextPhase and t >= e.NextPhase then
				e.NextPhase = t + def.Phase.Every
				e.PhasedUntil = t + def.Phase.Duration
				Sim.EnemyState(e, "Phase", def.Phase.Duration)
			end
			if e.NextShield and t >= e.NextShield then
				e.NextShield = t + def.Shield.Every
				e.ShieldUntil = t + def.Shield.Duration
				Sim.EnemyState(e, "Shield", def.Shield.Duration)
			end
			if e.NextHaste and t >= e.NextHaste then
				e.NextHaste = t + def.Haste.Every
				e.HasteUntil = t + def.Haste.Duration
				Sim.EnemyState(e, "Haste", def.Haste.Duration)
			end
			if e.NextFog and t >= e.NextFog then
				-- туман: враги рядом (и сам колдун) ускоряются; одинаковый туман не суммируется
				local fog = def.Fog
				e.NextFog = t + fog.Every
				for _, o in pairs(enemies) do
					if flat(o.Pos, e.Pos) <= fog.Radius then
						o.FogAmount = math.max((o.FogUntil or 0) > t and o.FogAmount or 0, fog.Speed)
						o.FogUntil = math.max(o.FogUntil or 0, t + fog.Duration)
					end
				end
				Sim.Impact({ K = "Fog", P = e.Pos, R = fog.Radius, I = e.Id, DUR = fog.Duration })
			end
			e.Dist += e.Speed * mult * dt
			e.Pos = enemyPos(e)
			if e.NextSummon and t >= e.NextSummon then
				e.NextSummon = t + def.Summon.Interval
				queueSpawn(def.Summon.Enemy, def.Summon.Count, math.max(e.Dist - 3, 0), e.Pos)
			end
			if e.Dist >= Path.Length then
				reached[#reached + 1] = e
			end
		end
		for _, e in ipairs(reached) do
			if e.Alive then
				Sim.RemoveEnemy(e, "core")
				if Sim.Hooks.OnCore then
					Sim.Hooks.OnCore(e, e.Def.CoreDamage)
				end
			end
		end
		table.clear(reached)
		Sim.FlushSpawns()
	end

	-- отложенные спавны (не вставляем врагов, пока кто-то обходит enemies); после поражения — не спавним
	function Sim.FlushSpawns()
		if #Sim.pending == 0 or not Sim.Running then
			return
		end
		local list = Sim.pending
		Sim.pending = {}
		for _, s in ipairs(list) do
			Sim.Impact({ K = s[5] or "Summon", P = s[4], R = 6 })
			for k = 1, s[2] do
				Sim.SpawnEnemy(s[1], math.max(0, s[3] - k * 1.5))
			end
		end
	end

	------------------------------------------------------------------------
	-- ЦЕЛИ
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
	local function byD(a, b)
		return a._d < b._d
	end

	-- живые враги в радиусе юнита, отсортированные по режиму прицеливания
	function Sim.Candidates(u, range)
		local list = {}
		for _, e in pairs(enemies) do
			if e.Alive then
				local d = flat(e.Pos, u.Pos)
				if d <= range then
					e._d = d
					list[#list + 1] = e
				end
			end
		end
		if #list > 1 then
			table.sort(list, sorters[u.TargetMode] or byD)
		end
		return list
	end

	local function byDr(a, b)
		return a._dr < b._dr
	end
	-- ближайшие к точке (без exclude), не больше maxCount
	function Sim.NearestTo(center, radius, exclude, maxCount)
		local list = {}
		for _, e in pairs(enemies) do
			if e.Alive and not exclude[e] then
				local d = flat(e.Pos, center)
				if d <= radius + (e.IsBoss and 1 or 0.3) then
					e._dr = d
					list[#list + 1] = e
				end
			end
		end
		table.sort(list, byDr)
		for i = #list, math.max(maxCount, 0) + 1, -1 do
			list[i] = nil
		end
		return list
	end

	-- расстояние от точки до отрезка (XZ)
	function Sim.DistToSegment(p, a, b)
		local abx, abz = b.X - a.X, b.Z - a.Z
		local lenSq = abx * abx + abz * abz
		local t = 0
		if lenSq > 0 then
			t = math.clamp(((p.X - a.X) * abx + (p.Z - a.Z) * abz) / lenSq, 0, 1)
		end
		local cx, cz = a.X + abx * t, a.Z + abz * t
		local dx, dz = p.X - cx, p.Z - cz
		return math.sqrt(dx * dx + dz * dz)
	end
end
