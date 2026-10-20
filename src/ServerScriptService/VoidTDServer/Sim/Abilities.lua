--!nocheck
-- VOID TD :: Sim.Abilities
-- Способности юнитов: Чёрная дыра, Кровавая луна, зоны урона (яд / чума), Power (Хэллоуин: способность
-- вместо каждой N-й атаки), способности времени Проклятого часовщика (Поломка, Ускорение, Буря).

return function(Sim)
	local Path, S = Sim.Path, Sim.S
	local enemies, units, zones = Sim.enemies, Sim.units, Sim.zones
	local flat = Path.FlatDistance

	local STORM_FX_RADIUS = 6 -- радиус визуального вихря вокруг часовщика (не боевой)

	------------------------------------------------------------------------
	-- ЗОНЫ
	------------------------------------------------------------------------
	-- ядовитая/огненная зона: урон раз в 0.5 с всем внутри
	function Sim.PoisonZone(u, pos, radius, duration, dps, kind, delay)
		if not dps or dps <= 0 then
			return
		end
		local t = Sim.now() + (delay or 0)
		zones[#zones + 1] = {
			Pos = pos, Radius = radius, Until = t + duration, NextTick = t, Tick = 0.5,
			TickDamage = dps * 0.5, Slow = 0, Unit = u,
		}
		Sim.Impact({ K = kind, P = pos, R = radius, DUR = duration, DL = delay, U = u.Uid, L = u.Level })
	end

	function Sim.UpdateZones(t)
		for i = #zones, 1, -1 do
			local z = zones[i]
			if t >= z.Until or not z.Unit.Alive then
				table.remove(zones, i)
			elseif t >= z.NextTick then
				z.NextTick += z.Tick
				for _, e in pairs(enemies) do
					if e.Alive and flat(e.Pos, z.Pos) <= z.Radius then
						if z.Slow and z.Slow > 0 then
							-- как обычное замедление: сильнейшее и самое долгое (не обрезает чужое)
							local slow = z.Slow * (e.IsBoss and S.BossSlowResist or 1)
							e.SlowAmount = math.max(e.SlowUntil > t and e.SlowAmount or 0, slow)
							e.SlowUntil = math.max(e.SlowUntil, t + z.Tick + 0.15)
						end
						Sim.DamageEnemy(e, z.TickDamage, false, z.Unit, true)
					end
				end
			end
		end
	end

	------------------------------------------------------------------------
	-- ЧЁРНАЯ ДЫРА / КРОВАВАЯ ЛУНА
	------------------------------------------------------------------------
	function Sim.CastBlackHole(u, stats, list)
		local bh = stats.BlackHole
		local target = list[1]
		local pos = Path.PositionAt(math.min(target.Dist + 4, Path.Length - 1))
		local t = Sim.now()
		zones[#zones + 1] = {
			Pos = pos, Radius = bh.Radius, Until = t + 0.6 + bh.Duration, NextTick = t + 0.6,
			Tick = bh.Tick, TickDamage = bh.TickDamage, Slow = bh.Slow, Unit = u,
		}
		Sim.Attack({ U = u.Uid, T = { target.Id }, L = u.Level, D = 0.6, AB = true })
		Sim.Impact({ K = "BlackHole", P = pos, R = bh.Radius, L = u.Level, U = u.Uid, DUR = bh.Duration, DL = 0.6 })
	end

	function Sim.CastBloodMoon(u, stats, list)
		local bm = stats.BloodMoon
		local target = list[1]
		local pos = Path.PositionAt(math.min(target.Dist + 3, Path.Length - 1))
		Sim.Attack({ U = u.Uid, T = { target.Id }, L = u.Level, D = 0.6, AB = true })
		Sim.Impact({ K = "BloodMoonFall", P = pos, R = bm.Radius, L = u.Level, U = u.Uid, DL = 1.0 })
		Sim.Later(u, 1.0, function()
			local big = { Damage = stats.Damage * (bm.Mult or 3) }
			Sim.AoeHit(u, pos, bm.Radius, big, "BloodMoon", { Bleed = bm.Bleed, BleedTime = bm.BleedTime })
		end)
	end

	------------------------------------------------------------------------
	-- POWER: способность вместо каждой N-й обычной атаки (руны не срабатывают)
	------------------------------------------------------------------------
	function Sim.CastPower(u, stats, list)
		local P = u.Def.Power
		local target = list[1]
		local delay = P.Delay or 0.45
		local saved = target.Pos
		-- длинная анимация способности не обрывается следующей атакой
		u.NextAttack = math.max(u.NextAttack, Sim.now() + delay + 0.25)
		Sim.Attack({ U = u.Uid, T = { target.Id }, L = u.Level, D = delay, AB = P.Anim })
		Sim.Later(u, delay, function()
			local center = target.Alive and target.Pos or saved
			if P.Mode == "Single" then
				local e = target.Alive and target or Sim.Candidates(u, stats.Range + 2)[1]
				if not e then
					return
				end
				Sim.Impact({ K = P.Kind, P = e.Pos, I = e.Id, U = u.Uid, L = u.Level, DUR = P.MarkTime })
				-- метка до урона: этот удар уже усилен
				if P.Mark then
					e.Mark = P.Mark
					e.MarkUntil = Sim.now() + (P.MarkTime or 3)
				end
				local dmg = Sim.RollDamage(stats)
				Sim.DamageEnemy(e, dmg * (P.Mult or 1), true, u)
			elseif P.Mode == "Zone" then
				local radius = (stats.Explode or 5) * (P.RadiusMult or 1.5)
				Sim.AoeHit(u, center, radius, stats, P.Kind .. "Burst", { Mult = 0.5 })
				Sim.PoisonZone(u, center, radius, P.Duration or 5, (stats.PoisonDps or stats.Damage * 0.3) * (P.Mult or 1), P.Kind)
			else
				local radius = stats.PowerRadius or P.Radius or ((stats.AOERadius or 5) + (P.RadiusAdd or 0))
				if P.Mode == "Self" then
					center = u.Pos
					radius = stats.PowerRadius or P.Radius or ((stats.AOERadius or stats.Range) + (P.RadiusAdd or 1))
				end
				Sim.AoeHit(u, center, radius, stats, P.Kind, {
					Mult = P.Mult, Slow = P.Slow, SlowTime = P.SlowTime,
					Bleed = P.Burn and stats.Damage * P.Burn or nil, BleedTime = P.BurnTime, DotKind = "Burn",
				})
			end
		end)
	end

	------------------------------------------------------------------------
	-- СПОСОБНОСТИ ВРЕМЕНИ (Проклятый часовщик)
	------------------------------------------------------------------------
	-- Остановка не суммируется: замороженного не морозим повторно, после заморозки — иммунитет.
	-- После остановки до MaxRewind обычных врагов отматываются назад по дороге (боссы — нет).
	function Sim.CastTimeBreak(u, stats)
		local tb = u.Def.TimeBreak
		local list = Sim.Candidates(u, stats.Range + 2)
		if #list == 0 then
			return
		end
		local t = Sim.now()
		local center = list[1].Pos
		local normal, bosses = {}, {}
		for _, e in pairs(enemies) do
			if e.Alive and t >= (e.FreezeImmuneUntil or 0) and (e.FrozenUntil or 0) <= t then
				local d = flat(e.Pos, center)
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
			Sim.Freeze(normal[i], tb.Freeze, t)
			frozen[i] = normal[i]
		end
		for _, b in ipairs(bosses) do
			Sim.Freeze(b, tb.BossFreeze, t)
		end
		Sim.Attack({ U = u.Uid, T = { list[1].Id }, L = u.Level, D = 0.5, AB = "TimeBreak" })
		Sim.Impact({ K = "TimeBreak", P = center, R = tb.Radius, DUR = tb.Freeze, U = u.Uid, L = u.Level })
		Sim.Later(u, tb.Freeze, function()
			for i = 1, math.min(tb.MaxRewind, #frozen) do
				local e = frozen[i]
				if e.Alive then
					e.Dist = math.max(0, e.Dist - tb.Rewind)
					e.Pos = Sim.EnemyPos(e)
				end
			end
		end)
	end

	-- ускорение своих юнитов рядом (не самого часовщика): кулдаун / (1 + Haste), урон прежний
	function Sim.CastTimeHaste(u, stats)
		local th = u.Def.TimeHaste
		local t = Sim.now()
		local ids = {}
		for _, o in pairs(units) do
			if o ~= u and o.Alive and o.Owner == u.Owner and flat(o.Pos, u.Pos) <= th.Radius then
				-- одинаковые ускорения не суммируются: действует самое сильное
				if (o.HasteUntil or 0) > t then
					o.Haste = math.max(o.Haste or 0, stats.Haste)
				else
					o.Haste = stats.Haste
				end
				o.HasteUntil = math.max(o.HasteUntil or 0, t + stats.HasteTime)
				ids[#ids + 1] = o.Uid
			end
		end
		Sim.Attack({ U = u.Uid, T = {}, L = u.Level, D = 0.4, AB = "TimeHaste" })
		Sim.Impact({ K = "TimeHaste", P = u.Pos, R = th.Radius, A = ids, DUR = stats.HasteTime, U = u.Uid, L = u.Level })
	end

	function Sim.StartTimeStorm(u, t)
		local ts = u.Def.TimeStorm
		u.StormUntil = t + ts.Duration
		u.NextStorm = u.StormUntil + ts.Cooldown
		u.Folder:SetAttribute("Storm", true)
		Sim.Attack({ U = u.Uid, T = {}, L = u.Level, D = 1.2, AB = "TimeStorm" })
		Sim.Impact({ K = "TimeStorm", P = u.Pos, R = STORM_FX_RADIUS, DL = 1.3, U = u.Uid, L = u.Level })
	end

	function Sim.UpdateChrono(u, stats, t)
		local def = u.Def
		if def.TimeStorm then
			if u.StormUntil and t >= u.StormUntil then
				u.StormUntil = nil
				u.Folder:SetAttribute("Storm", false)
			end
			if not u.StormUntil and t >= u.NextStorm then
				Sim.StartTimeStorm(u, t)
				u.NextAttack = math.max(u.NextAttack, t + 1.4)
			end
		end
		if def.TimeHaste and t >= u.NextHaste then
			Sim.CastTimeHaste(u, stats)
			u.NextHaste = t + def.TimeHaste.Interval
			u.NextAttack = math.max(u.NextAttack, t + 0.6)
		end
	end
end
