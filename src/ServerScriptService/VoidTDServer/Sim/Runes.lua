--!nocheck
-- VOID TD :: Sim.Runes
-- Хэллоуин-руны (читаются из профиля при установке юнита). Срабатывают только от обычных атак:
-- не от Power и не от повтора «Призрачной короны».
--   LanternHeart  — каждая 3-я атака: огненный взрыв по дополнительным врагам рядом с целью
--   CursedThreads — каждая 5-я атака: замедление до 3 врагов; каждые 60 с — призыв проклятых
--   PhantomCrown  — 30%: призрачная копия повторяет атаку через 0.3 с

return function(Sim)
	local Config, Path = Sim.Config, Sim.Path
	local rng = Sim.rng

	local R = {}

	R.LanternHeart = function(u, stats, target, rune)
		u.RuneCount = (u.RuneCount or 0) + 1
		if u.RuneCount % rune.EveryNth ~= 0 then
			return
		end
		local saved = target.Pos
		Sim.Later(u, Sim.ImpactDelay(u, target), function()
			local center = target.Alive and target.Pos or saved
			local extra = Sim.NearestTo(center, rune.Radius, { [target] = true }, rune.MaxTargets)
			Sim.Impact({ K = "LanternHeart", P = center, R = rune.Radius, U = u.Uid, L = u.Level, N = #extra })
			for _, e in ipairs(extra) do
				Sim.DamageEnemy(e, stats.Damage * rune.Mult, false, u, true)
			end
		end)
	end

	R.CursedThreads = function(u, stats, target, rune)
		u.RuneCount = (u.RuneCount or 0) + 1
		if u.RuneCount % rune.EveryNth ~= 0 then
			return
		end
		Sim.Later(u, Sim.ImpactDelay(u, target), function()
			local first = target.Alive and target or nil
			local center = target.Pos -- у погибшей цели — точка гибели
			local list = first and { first } or {}
			for _, e in ipairs(Sim.NearestTo(center, 8, { [target] = true }, rune.MaxTargets - #list)) do
				list[#list + 1] = e
			end
			local ids = {}
			for i, e in ipairs(list) do
				Sim.ApplySlow(e, rune.Slow, rune.SlowTime)
				ids[i] = e.Id
			end
			Sim.Impact({ K = "CursedThreads", P = center, A = ids, U = u.Uid, L = u.Level, DUR = rune.SlowTime })
		end)
	end

	-- повтор атаки со 100% урона, не задерживая следующую атаку
	R.PhantomCrown = function(u, stats, target, rune)
		if rng:NextNumber() >= rune.Chance then
			return
		end
		Sim.Later(u, rune.Delay, function()
			if not Sim.Running then
				return
			end
			local pool = Sim.Candidates(u, stats.Range)
			if target.Alive and Path.FlatDistance(target.Pos, u.Pos) <= stats.Range then
				local i = table.find(pool, target)
				if i then
					table.remove(pool, i)
				end
				table.insert(pool, 1, target)
			end
			if #pool == 0 then
				return -- целей нет — повтор отменяется
			end
			Sim.Impact({ K = "PhantomEcho", P = u.Pos, U = u.Uid, L = u.Level })
			Sim.echo = true
			local ok, err = pcall(Sim.DoAttack, u, stats, pool)
			Sim.echo = false
			if not ok then
				warn("[VOID TD] echo: " .. tostring(err))
			end
		end)
	end

	function Sim.RuneAfterAttack(u, stats, list)
		local runeId = u.Rune
		local rune = runeId and Config.Runes[runeId]
		local fn = R[runeId]
		if not rune or not fn or Sim.echo or not list[1] then
			return
		end
		fn(u, stats, list[1], rune)
	end

	-- «Проклятые нити»: ровно каждые Interval с, не больше Max живых, лишний — самый старый — исчезает
	function Sim.RuneSummon(u, t)
		local sm = Config.Runes.CursedThreads.Summon
		u.NextRuneSummon += sm.Interval
		local lv = sm.Levels[math.min(u.Level, #sm.Levels)]
		local ids = {}
		for i = 1, lv.Count do
			ids[i] = Sim.SpawnAlly(u, lv.Ally, lv.HP, "Rune", i - 1).Id
		end
		local list = Sim.AlliesOf(u, "Rune")
		for i = 1, #list - sm.Max do
			Sim.RemoveAlly(list[i], "replaced")
		end
		Sim.Impact({ K = "CursedCircle", P = Sim.AllyGate(), U = u.Uid, L = u.Level, A = ids })
	end
end
