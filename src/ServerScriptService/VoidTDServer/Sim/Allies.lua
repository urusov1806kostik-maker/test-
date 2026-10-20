--!nocheck
-- VOID TD :: Sim.Allies
-- Союзники (призывы Кукловода / Иллюзиониста и руны «Проклятые нити»): идут по дороге от базы к порталу.
-- HP союзника — запас урона: при столкновении враг теряет min(HP/стоимость, HP врага), союзник — это × стоимость
-- (стоимость = FireAura врага, иначе 1). Отдельного события спавна нет: клиент узнаёт из Impact (A) и Sync (AL).

return function(Sim)
	local Config, Path, S = Sim.Config, Sim.Path, Sim.S
	local allies, enemies = Sim.allies, Sim.enemies
	local rng = Sim.rng

	local allyIndex = {}
	for i, id in ipairs(Config.AllyOrder or {}) do
		allyIndex[id] = i
	end

	local function startBack()
		return S.AllyStartBack or 4
	end

	-- точка появления союзников (у базы)
	function Sim.AllyGate()
		return (Path.PositionAt(Path.Length - startBack()))
	end

	function Sim.SpawnAlly(u, allyId, hp, source, index)
		Sim.ids.Ally += 1
		local a = {
			Id = Sim.ids.Ally,
			AllyId = allyId,
			HP = hp,
			MaxHP = hp,
			Dist = math.max(1, Path.Length - startBack() - (index or 0) * 2.2),
			Lateral = rng:NextNumber(-1.6, 1.6),
			Speed = S.AllySpeed or 6,
			Owner = u,
			Source = source,
			Born = Sim.now(),
			Alive = true,
		}
		a.Pos = Path.OffsetPositionAt(a.Dist, a.Lateral)
		allies[a.Id] = a
		return a
	end

	function Sim.RemoveAlly(a, reason)
		if not a.Alive then
			return
		end
		a.Alive = false
		allies[a.Id] = nil
		Sim.allyRm[#Sim.allyRm + 1] = { a.Id, reason }
	end

	-- живые союзники юнита из источника, от старых к новым
	function Sim.AlliesOf(u, source)
		local list = {}
		for _, a in pairs(allies) do
			if a.Owner == u and (source == nil or a.Source == source) then
				list[#list + 1] = a
			end
		end
		table.sort(list, function(x, y)
			return x.Id < y.Id
		end)
		return list
	end

	-- Призыв Кукловода / Иллюзиониста: не больше Max живых, лишние не появляются
	function Sim.CastSummon(u, t)
		local sm = u.Def.Summon
		local lv = sm.Levels[math.min(u.Level, #sm.Levels)]
		u.NextSummon = t + lv.Interval
		local count = math.min(lv.Count, sm.Max - #Sim.AlliesOf(u, "Summon"))
		if count <= 0 then
			return
		end
		u.SummonCount = (u.SummonCount or 0) + 1
		local golden = sm.Golden ~= nil and u.Level >= #u.Def.Levels and u.SummonCount % sm.Golden.Every == 0
		local ids = {}
		for i = 1, count do
			local a
			if golden and i == 1 then
				a = Sim.SpawnAlly(u, sm.Golden.Ally, sm.Golden.HP, "Summon", i - 1)
			else
				a = Sim.SpawnAlly(u, lv.Ally, lv.HP, "Summon", i - 1)
			end
			ids[i] = a.Id
		end
		Sim.Attack({ U = u.Uid, T = {}, L = u.Level, D = 0.6, AB = "Summon" })
		Sim.Impact({ K = "SummonPortal", S = sm.Portal, P = Sim.AllyGate(), U = u.Uid, L = u.Level, A = ids, G = golden or nil })
	end

	-- ближайшие по дороге враги — первыми (при большом dt столкновения в правильном порядке)
	local hits = {}
	local function byGap(x, y)
		return x._gap < y._gap
	end

	function Sim.UpdateAllies(t, dt)
		for _, a in pairs(allies) do
			if a.Alive then
				a.Dist -= a.Speed * dt
				if a.Dist <= 0 then
					Sim.RemoveAlly(a, "portal")
				else
					a.Pos = Path.OffsetPositionAt(a.Dist, a.Lateral)
					-- столкновение: враг дошёл до союзника (окно с запасом для большого dt)
					table.clear(hits)
					for _, e in pairs(enemies) do
						if e.Alive and e.Dist >= a.Dist - 1.4 - (e.IsBoss and 1.2 or 0) and e.Dist <= a.Dist + 3 then
							e._gap = math.abs(e.Dist - a.Dist)
							hits[#hits + 1] = e
						end
					end
					if #hits > 1 then
						table.sort(hits, byGap)
					end
					for _, e in ipairs(hits) do
						if e.Alive then
							local cost = e.Def.FireAura or 1
							local dealt = Sim.RawDamage(e, math.min(a.HP / cost, e.Health), a.Owner)
							a.HP -= dealt * cost
							Sim.Impact({ K = "AllyHit", P = a.Pos, I = a.Id, E = e.Id, F = cost > 1 or nil })
							if a.HP <= 0.5 or dealt <= 0 then
								Sim.RemoveAlly(a, "dead")
								break
							end
						end
					end
					table.clear(hits)
				end
			end
		end
	end

	function Sim.AllySyncList()
		local al = {}
		for _, a in pairs(allies) do
			al[#al + 1] = a.Id
			al[#al + 1] = math.floor(a.Dist * 100) / 100
			al[#al + 1] = math.floor(a.HP + 0.5)
			al[#al + 1] = allyIndex[a.AllyId] or 1
			al[#al + 1] = a.MaxHP
		end
		return al
	end
end
