--!nocheck
-- VOID TD :: Sim.Attacks
-- Обычные атаки юнитов по AttackType: Melee/Laser, Projectile, Chain, Thread, AOE, MultiHit, Splash,
-- Chrono, Pulse, Flask, Pierce. Урон считается на сервере с задержкой удара; клиент получает Attack/Impact.
-- Sim.echo = true во время синхронной части повтора «Призрачной короны» (EC в Attack, без счётчиков).

return function(Sim)
	local Path = Sim.Path
	local enemies = Sim.enemies
	local rng = Sim.rng
	local flat = Path.FlatDistance

	local function fireAttack(u, targetIds, extra)
		local payload = { U = u.Uid, T = targetIds, L = u.Level, EC = Sim.echo or nil }
		if extra then
			for k, v in pairs(extra) do
				payload[k] = v
			end
		end
		Sim.Attack(payload)
	end

	-- AOE: каждый враг получает урон ровно один раз за удар.
	-- opts: Exclude, Mult, Bleed/BleedTime/DotKind, Slow/SlowTime, Extra (доп. поля события)
	-- Кровотечение и замедление не накладываются, если удар был уклонён.
	function Sim.AoeHit(u, center, radius, stats, kind, opts)
		opts = opts or {}
		local hitSet = {}
		for _, e in pairs(enemies) do
			if e.Alive and e ~= opts.Exclude and flat(e.Pos, center) <= radius + (e.IsBoss and 1.5 or 0.5) then
				hitSet[#hitSet + 1] = e
			end
		end
		local payload = { K = kind, P = center, R = radius, L = u.Level, U = u.Uid, N = #hitSet }
		if opts.Extra then
			for k, v in pairs(opts.Extra) do
				payload[k] = v
			end
		end
		Sim.Impact(payload)
		for _, e in ipairs(hitSet) do
			local dmg, crit = Sim.RollDamage(stats)
			local _, dodged = Sim.DamageEnemy(e, dmg * (opts.Mult or 1), crit, u)
			if not dodged then
				if opts.Bleed then
					Sim.ApplyDot(e, opts.Bleed, opts.BleedTime or 3, u, opts.DotKind or "Bleed")
				end
				if opts.Slow then
					Sim.ApplySlow(e, opts.Slow, opts.SlowTime or 1.5)
				end
			end
		end
		return hitSet
	end

	-- направление от юнита к цели в XZ (запасное — -Z)
	local function flatDir(from, to)
		local dir = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
		if dir.Magnitude < 0.1 then
			return Vector3.new(0, 0, -1)
		end
		return dir.Unit
	end

	-- задержка попадания обычной атаки (для рун): HitDelay + полёт снаряда
	local SPEED_DEFAULT = { Projectile = 80, Chain = 60, Flask = 45, Chrono = 70 }
	function Sim.ImpactDelay(u, target)
		local def = u.Def
		local d = def.HitDelay or 0.2
		local speed = def.ProjectileSpeed or SPEED_DEFAULT[def.AttackType]
		if speed then
			d += flat(u.Pos, target.Pos) / speed
		end
		return d
	end

	local A = {} -- AttackType -> function(u, stats, list, ctx)

	A.Melee = function(u, stats, list, c)
		local def, target = u.Def, list[1]
		local mult, power = 1, false
		if def.EveryNth and not Sim.echo then
			u.HitCount = (u.HitCount or 0) + 1
			if u.HitCount % def.EveryNth.N == 0 then
				mult, power = def.EveryNth.Mult, true
			end
		end
		fireAttack(u, { target.Id }, { D = c.hitDelay, PW = power })
		c.later(c.hitDelay, function()
			c.strike(target, mult, power)
		end)
	end
	A.Laser = A.Melee

	A.Projectile = function(u, stats, list, c)
		local def = u.Def
		local shots = stats.Shots or 1
		local ids, travels, plan = {}, {}, {}
		for s = 1, shots do
			local e = list[((s - 1) % #list) + 1]
			plan[s] = e
			ids[s] = e.Id
			travels[s] = flat(u.Pos, e.Pos) / (def.ProjectileSpeed or 80)
		end
		fireAttack(u, ids, { D = c.hitDelay, TR = travels[1], TRS = travels, SG = 0.12 })
		for s = 1, shots do
			local e = plan[s]
			c.later(c.hitDelay + (s - 1) * 0.12 + travels[s], function()
				if not e.Alive then
					return
				end
				local center = e.Pos
				c.strike(e)
				if stats.Explode then
					Sim.AoeHit(u, center, stats.Explode, stats, def.ExplodeKind or "Crystal", { Exclude = e, Mult = def.ExplodeMult or 0.5 })
				end
			end)
		end
	end

	-- лунный серп отскакивает к ближайшим врагам
	A.Chain = function(u, stats, list, c)
		local def, target = u.Def, list[1]
		local seq, times = { target }, {}
		local used = { [target] = true }
		local speed = def.ProjectileSpeed or 60
		times[1] = c.hitDelay + flat(u.Pos, target.Pos) / speed
		for i = 2, stats.Bounces or 3 do
			local prev = seq[i - 1]
			local best, bestD
			for _, e in pairs(enemies) do
				if e.Alive and not used[e] then
					local d = flat(e.Pos, prev.Pos)
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
		fireAttack(u, ids, { D = c.hitDelay, TT = times })
		for i, e in ipairs(seq) do
			c.later(times[i], function()
				c.strike(e, (def.BounceMult or 0.8) ^ (i - 1))
			end)
		end
	end

	A.Thread = function(u, stats, list, c)
		local ids, targets = {}, {}
		for i = 1, math.min(stats.Targets or 1, #list) do
			targets[i] = list[i]
			ids[i] = list[i].Id
		end
		fireAttack(u, ids, { D = c.hitDelay })
		c.later(c.hitDelay, function()
			for _, e in ipairs(targets) do
				if e.Alive and not c.strike(e) then
					Sim.ApplySlow(e, stats.Slow, stats.SlowTime or 1.5)
					Sim.ApplyDot(e, stats.Dot, stats.DotTime or 3, u, "Thread")
				end
			end
		end)
	end

	A.AOE = function(u, stats, list, c)
		local def, target = u.Def, list[1]
		local saved = target.Pos
		fireAttack(u, { target.Id }, { D = c.hitDelay })
		c.later(c.hitDelay, function()
			local center = target.Alive and target.Pos or saved
			Sim.AoeHit(u, center, stats.AOERadius or 6, stats, def.ImpactKind or "Reap", { Bleed = stats.Bleed, BleedTime = stats.BleedTime })
			-- падающие звёздные осколки
			for k = 1, stats.Shards or 0 do
				c.later(0.35 + k * 0.15, function()
					local pool = Sim.Candidates(u, stats.Range + 4)
					if #pool > 0 then
						local e = pool[rng:NextInteger(1, #pool)]
						Sim.AoeHit(u, e.Pos, stats.ShardRadius or 4, stats, "Shard", { Mult = stats.ShardMult or 0.6 })
					end
				end)
			end
		end)
	end

	A.MultiHit = function(u, stats, list, c)
		local def, target = u.Def, list[1]
		local hits = stats.Hits or 1
		local interval = def.HitInterval or 0.15
		local spread = def.Spread or (u.Id == "VoidEmperor")
		local kind = def.ImpactKind or "Judgement"
		local ids, plan = {}, {}
		for h = 1, hits do
			local e = spread and list[((h - 1) % #list) + 1] or target
			plan[h] = e
			ids[h] = e.Id
		end
		fireAttack(u, ids, { D = c.hitDelay, I = interval })
		for h = 1, hits do
			c.later(c.hitDelay + (h - 1) * interval, function()
				local e = plan[h]
				if not e.Alive then
					e = Sim.Candidates(u, stats.Range)[1]
				end
				if e then
					if spread then
						Sim.Impact({ K = kind, P = e.Pos, L = u.Level, U = u.Uid, H = h })
					end
					c.strike(e)
				end
			end)
		end
		if stats.BigRift then
			c.later(c.hitDelay + hits * interval + 0.2, function()
				local pool = Sim.Candidates(u, stats.Range)
				if #pool > 0 then
					Sim.AoeHit(u, pool[1].Pos, stats.BigRift, stats, "BigRift", { Mult = stats.BigRiftMult or 1.5 })
				end
			end)
		end
	end

	-- RED SPLASH: цель 100%, остальные в радиусе 50% (цель второй раз не задевается)
	A.Splash = function(u, stats, list, c)
		local def, target = u.Def, list[1]
		fireAttack(u, { target.Id }, { D = c.hitDelay })
		local saved = target.Pos
		c.later(c.hitDelay, function()
			local center = target.Alive and target.Pos or saved
			if target.Alive then
				c.strike(target)
			end
			Sim.AoeHit(u, center, stats.AOERadius or 8, stats, "Splash", { Exclude = target, Mult = def.SplashMult or 0.5 })
		end)
	end

	-- РАЗРЕЗ СЕКУНД: зубчатый диск летит по прямой и режет до DiscTargets врагов (только впереди юнита)
	A.Chrono = function(u, stats, list, c)
		local def, target = u.Def, list[1]
		local t0 = Sim.now()
		local storm = u.StormUntil ~= nil and t0 < u.StormUntil
		local dir = flatDir(u.Pos, target.Pos)
		local endPos = u.Pos + dir * (stats.Range + 3)
		local speed = def.ProjectileSpeed or 70
		local half = (def.DiscWidth or 3) / 2
		local line = {}
		for _, e in pairs(enemies) do
			if e.Alive and e ~= target and Sim.DistToSegment(e.Pos, u.Pos, endPos) <= half + (e.IsBoss and 1.2 or 0) then
				e._along = (e.Pos.X - u.Pos.X) * dir.X + (e.Pos.Z - u.Pos.Z) * dir.Z
				if e._along >= 0 then
					line[#line + 1] = e
				end
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
		fireAttack(u, { target.Id }, { D = c.hitDelay, E = endPos, SP = speed, ST = storm or nil })
		for _, e in ipairs(hits) do
			local along = math.max(0, (e.Pos.X - u.Pos.X) * dir.X + (e.Pos.Z - u.Pos.Z) * dir.Z)
			c.later(c.hitDelay + along / speed, function()
				if e.Alive then
					Sim.Impact({ K = "ChronoHit", P = e.Pos, L = u.Level, U = u.Uid })
					c.strike(e)
				end
			end)
		end
		-- ВРЕМЕННАЯ БУРЯ: до Extra других врагов рядом с целью — по Mult (не считаются обычными атаками)
		if storm then
			local ts = def.TimeStorm
			local saved = target.Pos
			c.later(c.hitDelay + flat(u.Pos, target.Pos) / speed + 0.02, function()
				local center = target.Alive and target.Pos or saved
				local extra = Sim.NearestTo(center, ts.Radius, hitSet, ts.Extra)
				Sim.Impact({ K = "ChronoBurst", P = center, R = ts.Radius, L = u.Level, U = u.Uid })
				for _, e in ipairs(extra) do
					c.strike(e, ts.Mult)
				end
			end)
		end
		-- ПОЛОМКА ВРЕМЕНИ: после EveryNth обычных атак, но не чаще раза в MinInterval
		local tb = def.TimeBreak
		if tb and not Sim.echo then
			u.ChronoCount = (u.ChronoCount or 0) + 1
			if u.ChronoCount >= tb.EveryNth and t0 - (u.LastBreak or -1e9) >= tb.MinInterval then
				u.ChronoCount = 0
				u.LastBreak = t0
				u.NextAttack = math.max(u.NextAttack or 0, t0 + 1.6)
				c.later(c.hitDelay + 0.45, function()
					Sim.CastTimeBreak(u, stats)
				end)
			end
		end
	end

	-- звуковая волна вокруг самого юнита
	A.Pulse = function(u, stats, list, c)
		fireAttack(u, { list[1].Id }, { D = c.hitDelay })
		c.later(c.hitDelay, function()
			Sim.AoeHit(u, u.Pos, stats.AOERadius or stats.Range, stats, u.Def.ImpactKind or "BellWave")
		end)
	end

	-- колба: взрыв по области и ядовитая лужа
	A.Flask = function(u, stats, list, c)
		local def, target = u.Def, list[1]
		local travel = flat(u.Pos, target.Pos) / (def.ProjectileSpeed or 45)
		local saved = target.Pos
		fireAttack(u, { target.Id }, { D = c.hitDelay, TR = travel })
		c.later(c.hitDelay + travel, function()
			local center = target.Alive and target.Pos or saved
			local r = stats.Explode or 5
			Sim.AoeHit(u, center, r, stats, "FlaskSplash")
			Sim.PoisonZone(u, center, r * 0.8, def.PoisonTime or 3, stats.PoisonDps or 0, "Poison")
		end)
	end

	-- луч насквозь: все враги на линии от юнита через цель
	A.Pierce = function(u, stats, list, c)
		local def, target = u.Def, list[1]
		local dir = flatDir(u.Pos, target.Pos)
		local endPos = u.Pos + dir * (stats.Range + 4)
		fireAttack(u, { target.Id }, { D = c.hitDelay, E = endPos })
		c.later(c.hitDelay, function()
			Sim.Impact({ K = def.ImpactKindPierce or "Pierce", P = u.Pos, E = endPos, L = u.Level, U = u.Uid })
			local half = (def.PierceWidth or 3) / 2
			local hitSet = {}
			for _, e in pairs(enemies) do
				if e.Alive and Sim.DistToSegment(e.Pos, u.Pos, endPos) <= half + (e.IsBoss and 1.2 or 0) then
					hitSet[#hitSet + 1] = e
				end
			end
			for _, e in ipairs(hitSet) do
				c.strike(e)
			end
		end)
	end

	-- обычная атака по списку целей (list[1] — лучшая цель)
	function Sim.DoAttack(u, stats, list)
		if not list or not list[1] then
			return
		end
		local fn = A[u.Def.AttackType]
		if not fn then
			return
		end
		local c = { hitDelay = u.Def.HitDelay or 0.2 }
		function c.later(delay, f)
			Sim.Later(u, delay, f)
		end
		-- урон + кровотечение; -> уклонился?
		function c.strike(e, mult, forceCrit)
			if not e or not e.Alive then
				return true
			end
			local dmg, crit = Sim.RollDamage(stats)
			local _, dodged = Sim.DamageEnemy(e, dmg * (mult or 1), crit or forceCrit, u)
			if not dodged and stats.Bleed then
				Sim.ApplyDot(e, stats.Bleed, stats.BleedTime or 3, u, "Bleed")
			end
			return dodged
		end
		fn(u, stats, list, c)
	end
end
