--!nocheck
-- VOID TD :: FX/Halloween — эффекты события Haunted Hollow
-- Регистрирует: FX.HColors; снаряды FX.ProjectileMakers (CurseBullet Flask Card Pumpkin); удары Impact
-- (LightFlash LanternBeam DirtBurst LeafStorm CurseMark BellWave MidnightToll FlaskSplash Poison PlagueCloud
-- PlagueCloudBurst GhostSlash GhostSword MirrorShatter ThreadSnap FireCrack Execution PumpkinBlast GhostPumpkin
-- LanternHeart CursedThreads PhantomEcho CursedCircle SummonPortal AllyHit Fog Straw Fire EnemyState);
-- именованные эффекты FX.Fn:
--   HalloweenAttack(view, def, p, h, lv) -> handled   -- вылет атаки юнитов события (урон — по Impact)
--   EchoGhost(view)                                   -- «Призрачная корона»: синяя копия юнита
--   ThronePlace(pos)                                  -- трон Короля фонарей при установке
--   EnemyDeath(view, reason) / EnemySpawn(view, atStart) -- по rig.DeathFX / rig.SpawnFX
--   CrowCircle(pos, r, n, life, color) / CrowFly(from, getTarget, travel, onHit)

return function(FX)
	local V = Vector3.new
	local CF = CFrame.new
	local ANG = CFrame.Angles
	local rad = math.rad
	local rng = FX.Rng
	local rgb = Color3.fromRGB
	local Mat = Enum.Material
	local CYL = Enum.PartType.Cylinder
	local FLAT = ANG(0, 0, rad(90))
	local Quad, In = Enum.EasingStyle.Quad, Enum.EasingDirection.In

	local COL = {
		Orange = rgb(255, 140, 40), Ember = rgb(255, 90, 20), Fire = rgb(255, 180, 70), Light = rgb(255, 235, 170),
		Green = rgb(120, 255, 110), Poison = rgb(140, 230, 80), PoisonDark = rgb(60, 110, 40), Blue = rgb(90, 170, 255),
		Ghost = rgb(170, 220, 255), Purple = rgb(180, 90, 255), Red = rgb(230, 30, 50), Gold = rgb(255, 205, 80),
		Straw = rgb(220, 190, 110), Dirt = rgb(110, 85, 60), Stone = rgb(120, 112, 104), Leaf = rgb(230, 140, 40),
		Bell = rgb(190, 160, 255), Bone = rgb(230, 222, 205), Black = rgb(16, 12, 18), Smoke = rgb(90, 90, 96),
		FogC = rgb(160, 170, 160),
	}
	FX.HColors = COL
	local PUMPKIN = rgb(230, 110, 30)
	local GLASS = rgb(220, 210, 255)

	local ground = FX.Ground
	local debris, smoke, flash = FX.Debris, FX.Smoke, FX.Flash
	local function R()
		return FX.Env.Renderer
	end
	local function center(id)
		return FX.EnemyCenter(id)
	end
	local function enemyView(id)
		local r = R()
		return r and r.EnemyViews and r.EnemyViews[id]
	end

	------------------------------------------------------------------------
	-- ВОРОНЫ
	------------------------------------------------------------------------
	local function bird(color)
		local m = Instance.new("Model")
		m.Name = "Crow"
		local body = FX.Part({ Size = V(0.5, 0.45, 0.9), Color = color or COL.Black, Material = Mat.SmoothPlastic, Parent = m })
		for _, s in ipairs({ -1, 1 }) do
			local w = FX.Part({ Class = "WedgePart", Size = V(0.1, 0.5, 1.2), Color = color or COL.Black, Material = Mat.SmoothPlastic, Parent = m })
			w.Name = s == 1 and "WR" or "WL"
		end
		m.PrimaryPart = body
		m.Parent = FX.Folder
		return m
	end

	local function placeBird(m, cf, flap)
		m.PrimaryPart.CFrame = cf
		m.WR.CFrame = cf * CF(0.55, 0.1, 0) * ANG(0, 0, rad(-60 + flap))
		m.WL.CFrame = cf * CF(-0.55, 0.1, 0) * ANG(0, 0, rad(60 - flap))
	end

	-- вороны кружат вокруг точки
	local function crowCircle(pos, r, n, life, color)
		if FX.Lite then
			n = 1
		end
		local birds = {}
		for i = 1, n do
			birds[i] = { bird(color), i / n * math.pi * 2, rng:NextNumber(2, 4.5) }
		end
		FX.Run(function(t)
			if t >= life then
				for _, b in ipairs(birds) do
					b[1]:Destroy()
				end
				return true
			end
			for _, b in ipairs(birds) do
				local a = b[2] + t * 2.4
				local p = pos + V(math.cos(a) * r, b[3] + math.sin(t * 3 + b[2]) * 0.4, math.sin(a) * r)
				placeBird(b[1], CFrame.lookAt(p, p + V(-math.sin(a), 0, math.cos(a))), math.sin(t * 18 + b[2]) * 40)
			end
			return false
		end)
	end
	FX.Fn.CrowCircle = crowCircle

	-- ворон летит к цели (снаряд пугала)
	local function crowFly(from, getTarget, travel, onHit)
		local m = bird()
		local last = getTarget() or from
		local dur = math.max(travel or 0.3, 0.05)
		FX.Run(function(el, _, now)
			local a = math.clamp(el / dur, 0, 1)
			local target = getTarget() or last
			last = target
			local p = from:Lerp(target, a) + V(0, math.sin(a * math.pi) * 2, 0)
			placeBird(m, ((target - p).Magnitude > 0.05) and CFrame.lookAt(p, target) or CF(p), math.sin(now * 25) * 45)
			if a >= 1 then
				m:Destroy()
				if onHit then
					onHit(target)
				end
				return true
			end
			return false
		end)
	end
	FX.Fn.CrowFly = crowFly

	------------------------------------------------------------------------
	-- СНАРЯДЫ
	------------------------------------------------------------------------
	local PM = FX.ProjectileMakers
	PM.CurseBullet = function()
		local p = FX.Part({ Size = V(0.22, 0.22, 1.1), Color = COL.Green })
		FX.Light(p, COL.Green, 6, 2)
		return p, COL.Green
	end
	PM.Flask = function()
		local p = FX.Part({ Size = V(0.5, 0.7, 0.5), Color = COL.Poison, Material = Mat.Glass, Transparency = 0.2 })
		local cork = FX.Part({ Size = V(0.25, 0.25, 0.25), Color = COL.Dirt, Material = Mat.Wood, Parent = p })
		cork.Name = "Tip"
		FX.Light(p, COL.Poison, 6, 1.5)
		return p, COL.Poison, CF(0, 0.45, 0)
	end
	PM.Card = function()
		local p = FX.Part({ Size = V(0.6, 0.06, 0.9), Color = rgb(245, 240, 250), Material = Mat.SmoothPlastic })
		local mark = FX.Part({ Size = V(0.25, 0.08, 0.25), Color = COL.Purple, Parent = p })
		mark.Name = "Tip"
		return p, COL.Purple, CF(0, 0, 0)
	end
	PM.Pumpkin = function(lv)
		local s = 1 + (lv or 1) * 0.08
		local p = FX.Part({ Size = V(1.1 * s, 0.9 * s, 1.1 * s), Color = PUMPKIN, Material = Mat.SmoothPlastic })
		local face = FX.Part({ Size = V(0.6 * s, 0.25 * s, 0.1), Color = COL.Fire, Parent = p })
		face.Name = "Tip"
		FX.Light(p, COL.Orange, 10, 2.5)
		return p, COL.Ember, CF(0, 0, -0.56 * s)
	end

	------------------------------------------------------------------------
	-- УДАРЫ
	------------------------------------------------------------------------
	local I = FX.RegisterImpact

	I("LightFlash", function(p)
		local g = ground(p.P)
		flash(g + V(0, 1.5, 0), COL.Light, p.R * 0.6, 0.3)
		FX.Ring(g, p.R, COL.Light, 0.35, 0.2, 0.5, 0.3)
		FX.Sound("Magic", 0.6, 1.6, g)
	end)

	I("LanternBeam", function(p)
		local g = ground(p.P)
		local beam = FX.Part({ Shape = CYL, Size = V(30, 0.5, 0.5), CFrame = CF(g + V(0, 15, 0)) * FLAT, Color = COL.Light, Transparency = 0.2 })
		FX.Tween(beam, 0.15, { Size = V(30, p.R * 1.2, p.R * 1.2) })
		task.delay(0.2, function()
			FX.Fade(beam, 0.4, { Size = V(30, 0.2, 0.2) })
		end)
		FX.Ring(g, p.R, COL.Fire, 0.5, 0.3, 1, 0.1)
		flash(g + V(0, 2, 0), COL.Light, p.R * 0.7, 0.45)
		FX.Burst(g + V(0, 1, 0), COL.Fire, 12, 0.35, 9)
		FX.Sound("Laser", 0.8, 1.4, g)
	end)

	I("DirtBurst", function(p)
		local g = ground(p.P)
		FX.Ring(g, p.R, COL.Dirt, 0.45, 0.4, 1, 0.1)
		FX.Cracks(g, p.R, rgb(70, 50, 36), 6, 1.1)
		debris(g + V(0, 0.5, 0), COL.Stone, 8, 0.6, 9, 0.9)
		debris(g + V(0, 0.5, 0), COL.Dirt, 6, 0.45, 7, 0.8, Mat.Ground)
		smoke(g + V(0, 1, 0), rgb(120, 100, 80), 4, 3, 0.9, 2.5)
		FX.Sound("HeavyHit", 0.8, 0.8, g)
	end)

	I("LeafStorm", function(p)
		local g = ground(p.P)
		FX.Ring(g, p.R, COL.Leaf, 0.6, 0.25, 1, 0.3)
		local leaves = {}
		for i = 1, FX.Lite and 6 or 18 do
			local part = FX.Part({ Size = V(0.5, 0.06, 0.35), Color = (i % 3 == 0) and COL.Ember or COL.Leaf, Material = Mat.SmoothPlastic, CFrame = CF(g) })
			leaves[i] = { part, rng:NextNumber(0, 6.28), rng:NextNumber(0.5, 1) }
		end
		FX.Run(function(t)
			if t >= 1.3 then
				for _, l in ipairs(leaves) do
					l[1]:Destroy()
				end
				return true
			end
			for _, l in ipairs(leaves) do
				local a = l[2] + t * 7
				local r = p.R * l[3] * (0.4 + t * 0.5)
				l[1].CFrame = CF(g + V(math.cos(a) * r, t * 4 * l[3] + 0.5, math.sin(a) * r)) * ANG(t * 9, a, 0)
				l[1].Transparency = math.clamp((t - 0.9) / 0.4, 0, 1)
			end
			return false
		end)
		crowCircle(g, p.R * 0.6, 2, 1.3)
		FX.Sound("Slash", 0.6, 0.6, g)
	end)

	I("CurseMark", function(p)
		local id = p.I
		local c = center(id) or p.P
		flash(c, COL.Green, 2.5, 0.3)
		FX.Burst(c, COL.Green, 10, 0.35, 8)
		-- знак проклятия над головой врага
		local mark = FX.Part({ Size = V(1, 1, 0.15), Color = COL.Green, CFrame = CF(c) })
		local inner = FX.Part({ Size = V(0.45, 0.45, 0.2), Color = COL.Black, Material = Mat.SmoothPlastic, CFrame = CF(c) })
		local dur = p.DUR or 3
		FX.Run(function(t)
			local view = enemyView(id)
			if t >= dur or not view or not view.Rig.Model.Parent then
				FX.Fade(mark, 0.2)
				FX.Fade(inner, 0.2)
				return true
			end
			local rig = view.Rig
			local cf = CF(rig.Root.Position + V(0, (rig.Height or 5) - (rig.HipHeight or 0) + 1.2, 0)) * ANG(0, t * 3, rad(45))
			mark.CFrame = cf
			inner.CFrame = cf
			return false
		end)
		FX.Sound("Magic", 0.8, 0.6, c)
	end)

	I("BellWave", function(p)
		local g = ground(p.P)
		FX.Ring(g + V(0, 0.2, 0), p.R, COL.Bell, 0.55, 0.5, 1, 0.25)
		task.delay(0.12, function()
			FX.Ring(g + V(0, 0.6, 0), p.R * 0.8, rgb(230, 220, 255), 0.45, 0.3, 1, 0.4)
		end)
		FX.Sound("Magic", 0.8, 0.45, g)
	end)

	I("MidnightToll", function(p)
		local g = ground(p.P)
		for i = 0, 2 do
			task.delay(i * 0.15, function()
				FX.Ring(g + V(0, 0.3 + i * 0.4, 0), p.R * (1 - i * 0.12), i == 1 and COL.Purple or COL.Bell, 0.7, 0.6, 1, 0.15)
			end)
		end
		flash(g + V(0, 3, 0), COL.Bell, 4, 0.5)
		if FX.TinyClock then
			for i = 0, 2 do
				local a = i / 3 * math.pi * 2
				FX.TinyClock(g + V(math.cos(a) * p.R * 0.5, 3.5, math.sin(a) * p.R * 0.5), 1.4, 1.4, 4)
			end
		end
		FX.Shake(0.15, 0.3)
		FX.Sound("Boss", 0.5, 1.6, g)
	end)

	I("FlaskSplash", function(p)
		local g = ground(p.P)
		FX.Burst(g + V(0, 1, 0), COL.Poison, 10, 0.35, 8)
		FX.Ring(g, p.R, COL.Poison, 0.4, 0.25, 0.5, 0.3)
		debris(g + V(0, 1, 0), rgb(200, 255, 200), 4, 0.25, 6, 0.5, Mat.Glass)
		FX.Sound("Magic", 0.6, 1.2, g)
	end)

	-- ядовитое облако: лужа, клубы (шары в Roblox всегда круглые — утоплены в землю), частицы
	local function poisonCloud(p, big)
		local g = ground(p.P)
		local dur = p.DUR or 3
		local pool = FX.Part({ Shape = CYL, Size = V(0.1, 0.5, 0.5), CFrame = CF(g + V(0, 0.05, 0)) * FLAT, Color = COL.PoisonDark, Transparency = 0.35 })
		FX.Tween(pool, 0.3, { Size = V(0.1, p.R * 2, p.R * 2) })
		local balls = {}
		local n = FX.Lite and 2 or (big and 8 or 3)
		for i = 1, n do
			local a = i / n * math.pi * 2
			local s = p.R * (big and 0.9 or 0.7)
			balls[i] = FX.Part({ Shape = Enum.PartType.Ball, Size = V(s, s, s), CFrame = CF(g + V(math.cos(a) * p.R * 0.45, s * 0.1, math.sin(a) * p.R * 0.45)),
				Color = big and rgb(120, 200, 70) or COL.Poison, Material = Mat.SmoothPlastic, Transparency = 0.6 })
		end
		local em
		if not FX.Lite then
			em = Instance.new("ParticleEmitter")
			em.Color = ColorSequence.new(COL.Poison)
			em.LightEmission = 0.6
			em.Rate = big and 30 or 12
			em.Lifetime = NumberRange.new(0.6, 1.2)
			em.Speed = NumberRange.new(1, 3)
			em.SpreadAngle = Vector2.new(30, 30)
			em.EmissionDirection = Enum.NormalId.Right -- у лежащего цилиндра ось X смотрит вверх
			em.Size = NumberSequence.new(0.35, 0)
			em.Parent = pool
		end
		if big then
			crowCircle(g, p.R * 0.8, 3, dur)
		end
		task.delay(dur, function()
			if em then
				em.Enabled = false
			end
			FX.Fade(pool, 0.5)
			for _, b in ipairs(balls) do
				FX.Fade(b, 0.5, { Size = b.Size * 1.3 })
			end
		end)
	end

	I("Poison", function(p) poisonCloud(p, false) end)
	I("PlagueCloud", function(p)
		poisonCloud(p, true)
		FX.Sound("Magic", 0.8, 0.5, p.P)
	end)
	I("PlagueCloudBurst", function(p)
		local g = ground(p.P) + V(0, 1, 0)
		FX.Sphere(g, p.R * 0.8, COL.Poison, 0.45, nil, 0.3)
		FX.Burst(g, COL.Poison, 14, 0.4, 10)
	end)

	I("GhostSlash", function(p)
		local e = p.E or p.P
		local from, to = p.P + V(0, 1.5, 0), V(e.X, p.P.Y + 1.5, e.Z)
		FX.Beam(from, to, 1.1, COL.Blue, 0.35)
		local crescent = FX.Part({ Size = V(3.5, 0.2, 1.2), CFrame = CFrame.lookAt(from, to), Color = COL.Ghost, Transparency = 0.2 })
		FX.Tween(crescent, 0.25, { CFrame = CFrame.lookAt(to, to + (to - from)) })
		task.delay(0.25, function()
			FX.Fade(crescent, 0.2)
		end)
		FX.Sound("Slash", 1, 0.9, (from + to) / 2)
		FX.Sphere(from, 1.6, COL.Blue, 0.25)
	end)

	I("GhostSword", function(p)
		local g = ground(p.P)
		local h = 14
		local list = {
			FX.Part({ Size = V(1.4, h, 0.4), CFrame = CF(g + V(0, h / 2 + 18, 0)), Color = COL.Ghost, Transparency = 0.35 }),
			FX.Part({ Size = V(5, 0.6, 0.8), CFrame = CF(g + V(0, h + 18, 0)), Color = COL.Blue, Transparency = 0.3 }),
			FX.Part({ Size = V(0.6, 3, 0.6), CFrame = CF(g + V(0, h + 19.8, 0)), Color = COL.Blue, Transparency = 0.3 }),
		}
		for _, q in ipairs(list) do
			FX.Tween(q, 0.3, { CFrame = q.CFrame - V(0, 18 + h * 0.3, 0) }, Quad, In)
		end
		task.delay(0.3, function()
			FX.Ring(g, p.R, COL.Blue, 0.6, 0.5, 1, 0.1)
			FX.Cracks(g, p.R, COL.Blue, 8, 1.2)
			flash(g + V(0, 2, 0), COL.Ghost, p.R * 0.6, 0.45)
			FX.Burst(g + V(0, 1, 0), COL.Ghost, 16, 0.4, 12)
			FX.Shake(0.35, 0.35)
			FX.Sound("Explosion", 1, 0.8, g)
			task.delay(0.35, function()
				for _, q in ipairs(list) do
					FX.Fade(q, 0.4)
				end
			end)
		end)
	end)

	I("MirrorShatter", function(p)
		local g = ground(p.P)
		FX.PortalDisc(g + V(0, 3.5, 0), 2.6, COL.Purple, 0.8, rgb(230, 200, 255))
		FX.Ring(g, p.R, COL.Purple, 0.5, 0.3, 1, 0.15)
		debris(g + V(0, 3, 0), GLASS, 10, 0.5, 11, 0.9, Mat.Glass)
		FX.Burst(g + V(0, 2, 0), COL.Purple, 10, 0.35, 10)
		FX.Sound("Explosion", 0.7, 1.3, g)
	end)

	I("ThreadSnap", function(p)
		local g = ground(p.P) + V(0, 2.5, 0)
		for i = 1, FX.Lite and 4 or 8 do
			local a = i / 8 * math.pi * 2
			FX.Thread(g + V(0, 6, 0), g + V(math.cos(a) * p.R, rng:NextNumber(-2, 1), math.sin(a) * p.R), COL.Red)
		end
		FX.Ring(ground(p.P), p.R, COL.Red, 0.4, 0.2, 1, 0.2)
		FX.Burst(g, COL.Red, 14, 0.3, 10)
		FX.Sound("Slash", 1, 1.4, g)
	end)

	I("FireCrack", function(p)
		local g = ground(p.P)
		FX.Cracks(g, p.R, COL.Ember, 6, 1.2)
		FX.Ring(g, p.R, COL.Orange, 0.4, 0.3, 1, 0.2)
		FX.Burst(g + V(0, 1, 0), COL.Fire, 10, 0.4, 8)
		smoke(g + V(0, 1, 0), rgb(60, 40, 36), 3, 2.5, 0.8, 3)
		FX.Sound("HeavyHit", 1, 0.6, g)
	end)

	I("Execution", function(p)
		local g = ground(p.P)
		FX.Cracks(g, p.R, COL.Ember, 12, 1.6)
		FX.Ring(g, p.R, COL.Ember, 0.6, 0.6, 1, 0.05)
		flash(g + V(0, 2, 0), COL.Fire, p.R * 0.5, 0.4)
		for i = 1, FX.Lite and 2 or 5 do
			local a = i / 5 * math.pi * 2
			local q = g + V(math.cos(a) * p.R * 0.6, 0, math.sin(a) * p.R * 0.6)
			local pillar = FX.Part({ Size = V(1.2, 0.5, 1.2), CFrame = CF(q), Color = COL.Orange, Transparency = 0.2 })
			FX.Tween(pillar, 0.25, { Size = V(1.2, 7, 1.2), CFrame = CF(q + V(0, 3.5, 0)) })
			task.delay(0.3, function()
				FX.Fade(pillar, 0.4, { Size = V(0.2, 9, 0.2) })
			end)
		end
		debris(g + V(0, 0.5, 0), COL.Stone, 8, 0.6, 10, 0.9)
		FX.Shake(0.45, 0.4)
		FX.Sound("Explosion", 1, 0.55, g)
	end)

	I("PumpkinBlast", function(p)
		local g = ground(p.P) + V(0, 1, 0)
		FX.Sphere(g, p.R * 0.8, COL.Orange, 0.35)
		FX.Burst(g, COL.Ember, 10, 0.4, 9)
		debris(g, PUMPKIN, 5, 0.5, 8, 0.7, Mat.SmoothPlastic)
		FX.Sound("Explosion", 0.6, 1.1, g)
	end)

	I("GhostPumpkin", function(p)
		local g = ground(p.P)
		local s = 6
		local top = g + V(0, 22, 0)
		local pk = FX.Part({ Size = V(s, s * 0.85, s), CFrame = CF(top), Color = COL.Ghost, Transparency = 0.4 })
		local list = {
			pk,
			FX.Part({ Size = V(s * 0.6, s * 0.25, 0.2), CFrame = CF(top + V(0, -0.3, -s / 2)), Color = COL.Orange }),
			FX.Part({ Size = V(0.9, 0.9, 0.2), CFrame = CF(top + V(-1.2, 1, -s / 2)) * ANG(0, 0, rad(45)), Color = COL.Orange }),
			FX.Part({ Size = V(0.9, 0.9, 0.2), CFrame = CF(top + V(1.2, 1, -s / 2)) * ANG(0, 0, rad(45)), Color = COL.Orange }),
		}
		FX.Light(pk, COL.Orange, 30, 3)
		for _, q in ipairs(list) do
			FX.Tween(q, 0.45, { CFrame = q.CFrame - V(0, 19, 0) }, Quad, In)
		end
		task.delay(0.45, function()
			for _, q in ipairs(list) do
				q:Destroy()
			end
			FX.Sphere(g + V(0, 2, 0), p.R, COL.Orange, 0.6, nil, 0.05)
			FX.Sphere(g + V(0, 2, 0), p.R * 0.7, COL.Ghost, 0.5, nil, 0.3)
			FX.Ring(g, p.R * 1.2, COL.Ember, 0.7, 0.6, 1, 0.05)
			FX.Cracks(g, p.R, COL.Ember, 10, 1.6)
			FX.Burst(g + V(0, 2, 0), COL.Fire, 24, 0.6, 16, 0.8)
			debris(g + V(0, 1, 0), PUMPKIN, 8, 0.8, 12, 1.0, Mat.SmoothPlastic)
			flash(g + V(0, 3, 0), COL.Fire, p.R, 0.6)
			FX.Shake(0.6, 0.5)
			FX.Sound("Explosion", 1, 0.45, g)
		end)
	end)

	-- руны
	I("LanternHeart", function(p)
		local g = ground(p.P) + V(0, 1.2, 0)
		FX.Sphere(g, p.R, COL.Orange, 0.35, nil, 0.15)
		FX.Ring(ground(p.P), p.R, COL.Ember, 0.35, 0.25, 0.5, 0.2)
		FX.Burst(g, COL.Fire, 8, 0.3, 7)
		FX.Sound("Explosion", 0.4, 1.4, g)
	end)

	I("CursedThreads", function(p)
		local c = p.P + V(0, 7, 0)
		for _, id in ipairs(p.A or {}) do
			local e = center(id)
			if e then
				FX.Thread(c, e, COL.Red)
				FX.Ring(ground(e), 1.6, COL.Red, 0.5, 0.2, 0.3, 0.2)
			end
		end
		FX.Sound("Magic", 0.7, 0.5, p.P)
	end)

	-- копия юнита рисуется по атаке с флагом EC; здесь — отблеск
	I("PhantomEcho", function(p)
		FX.Burst(p.P + V(0, 2, 0), COL.Ghost, 5, 0.25, 4)
	end)

	I("CursedCircle", function(p)
		local g = ground(p.P)
		FX.RuneRing(g, 4, COL.Red, 2.2)
		flash(g + V(0, 1.5, 0), COL.Red, 3, 0.5)
		FX.Burst(g + V(0, 1, 0), COL.Red, 12, 0.35, 6)
		FX.Sound("Magic", 0.8, 0.4, g)
	end)

	I("SummonPortal", function(p)
		local g = ground(p.P)
		if p.S == "Illusion" then
			FX.PortalDisc(g + V(0, 4, 0), 3.4, COL.Purple, 1.4, rgb(230, 200, 255))
			FX.RuneRing(g, 3.5, COL.Purple, 1.6)
			debris(g + V(0, 3, 0), GLASS, 6, 0.35, 6, 0.8, Mat.Glass)
		else
			-- кукловод: красные нити опускают марионеток сверху
			for i = 1, 5 do
				local a = i / 5 * math.pi * 2
				FX.Thread(g + V(math.cos(a) * 1.5, 14, math.sin(a) * 1.5), g + V(math.cos(a) * 1.2, 2, math.sin(a) * 1.2), COL.Red)
			end
			FX.RuneRing(g, 3, COL.Red, 1.4)
			if p.G then
				flash(g + V(0, 3, 0), COL.Gold, 5, 0.7)
				FX.Burst(g + V(0, 2, 0), COL.Gold, 20, 0.4, 10, 0.8)
			end
		end
		FX.Sound("Portal", 0.8, 1.2, g)
	end)

	I("AllyHit", function(p)
		local pos = p.P + V(0, 2, 0)
		FX.Burst(pos, p.F and COL.Orange or COL.Light, 6, 0.3, 7)
		FX.Sphere(pos, 1.4, p.F and COL.Ember or rgb(255, 255, 255), 0.18)
		FX.Sound("Slash", 0.5, 1.2, pos)
		local r = R()
		local av = r and r.AllyViews and r.AllyViews[p.I]
		if av then
			av.HitT = os.clock()
		end
	end)

	I("Fog", function(p)
		local g = ground(p.P)
		FX.Ring(g, p.R, COL.FogC, 0.9, 0.2, 1, 0.5)
		smoke(g + V(0, 1, 0), COL.FogC, 5, p.R * 0.6, 1.4, 1)
		local view = enemyView(p.I)
		if view and view.Rig.Model.Parent then
			for _, d in ipairs(view.Rig.Model:GetDescendants()) do
				if d.Name == "FogFX" and d:IsA("ParticleEmitter") then
					d:Emit(18)
				end
			end
		end
	end)

	I("Straw", function(p)
		local g = ground(p.P) + V(0, 1.5, 0)
		debris(g, COL.Straw, 10, 0.35, 8, 0.9, Mat.Fabric)
		FX.Burst(g, COL.Straw, 8, 0.3, 6)
	end)

	I("Fire", function(p)
		local g = ground(p.P)
		FX.Ring(g, 7, COL.Ember, 0.6, 0.4, 1, 0.1)
		FX.Burst(g + V(0, 2, 0), COL.Fire, 18, 0.5, 10)
		flash(g + V(0, 3, 0), COL.Orange, 6, 0.5)
	end)

	------------------------------------------------------------------------
	-- СОСТОЯНИЯ ВРАГОВ (токен: перекрывающиеся состояния не снимаются раньше времени)
	------------------------------------------------------------------------
	local function setPhased(view, on)
		local model = view.Rig.Model
		if on then
			view.PhaseSave = view.PhaseSave or {}
			for _, d in ipairs(model:GetDescendants()) do
				if d:IsA("BasePart") and d.Transparency < 1 and not view.PhaseSave[d] then
					view.PhaseSave[d] = { d.Transparency, d.Color, d.Material }
					if d:GetAttribute("Outline") then
						d.Color = COL.Ghost
						d.Material = Mat.Neon
					else
						d.Transparency = 0.9
					end
				end
			end
		elseif view.PhaseSave then
			for d, s in pairs(view.PhaseSave) do
				if d.Parent then
					d.Transparency, d.Color, d.Material = s[1], s[2], s[3]
				end
			end
			view.PhaseSave = nil
		end
	end

	local function setShield(view, on)
		for _, d in ipairs(view.Rig.Model:GetDescendants()) do
			if d.Name == "ShieldFX" and d:IsA("BasePart") then
				FX.Tween(d, 0.25, { Transparency = on and (d:GetAttribute("PT") or 0.6) or 1 })
			end
		end
	end

	-- снять состояние через dur, если за это время не наложили новое того же вида
	local function expire(view, key, dur, fn)
		local token = (view[key] or 0) + 1
		view[key] = token
		task.delay(dur, function()
			if view[key] == token and view.Rig.Model.Parent then
				fn()
			end
		end)
	end

	I("EnemyState", function(p)
		local view = enemyView(p.I)
		if not view then
			return
		end
		local c = center(p.I) or p.P
		local s = p.S
		if s == "Phase" then
			setPhased(view, true)
			FX.Burst(c, COL.Ghost, 6, 0.25, 4)
			expire(view, "PhaseToken", p.DUR or 1.5, function() setPhased(view, false) end)
		elseif s == "Shield" then
			setShield(view, true)
			FX.Sphere(c, 3 * (view.Rig.Scale or 1), COL.Purple, 0.35, nil, 0.4)
			expire(view, "ShieldToken", p.DUR or 3, function() setShield(view, false) end)
		elseif s == "Haste" then
			view.HasteUntil = os.clock() + (p.DUR or 3)
			FX.Burst(c, COL.Red, 10, 0.3, 10)
			FX.Ring(ground(c), 4, COL.Red, 0.4, 0.2, 1, 0.2)
		elseif s == "Enrage" then
			flash(c, COL.Red, 6, 0.6)
			FX.Ring(ground(c), 10, COL.Red, 0.7, 0.5, 1, 0.1)
			FX.Shake(0.5, 0.6)
			FX.Sound("Boss", 1, 0.9, c)
		elseif s == "ArmorBreak" then
			debris(c, COL.Bone, 8, 0.45, 9, 0.9, Mat.SmoothPlastic)
			debris(c, rgb(90, 88, 100), 5, 0.5, 8, 0.9, Mat.Metal)
			FX.Sound("HeavyHit", 0.8, 1.3, c)
		end
	end)

	------------------------------------------------------------------------
	-- СМЕРТЬ И ПОЯВЛЕНИЕ ВРАГОВ
	------------------------------------------------------------------------
	local DEATH = {
		GreenSmoke = function(pos, s)
			smoke(pos, rgb(90, 200, 100), 5, 2.4 * s, 1.1, 3)
			FX.Burst(pos, COL.Green, 6, 0.3, 4)
		end,
		PumpkinBurst = function(pos, s)
			debris(pos, PUMPKIN, 7, 0.5 * s, 9, 0.9, Mat.SmoothPlastic)
			FX.Burst(pos, COL.Fire, 10, 0.35, 8)
			FX.Sphere(pos, 1.6 * s, COL.Orange, 0.3)
		end,
		Ghost = function(pos, s)
			smoke(pos, COL.Ghost, 4, 2 * s, 0.9, 4)
			FX.Burst(pos, COL.Ghost, 8, 0.3, 5)
		end,
		BoneShards = function(pos, s)
			debris(pos, COL.Bone, 9, 0.4 * s, 9, 1.0, Mat.SmoothPlastic)
		end,
		Straw = function(pos, s)
			debris(pos, COL.Straw, 10, 0.35 * s, 8, 1.0, Mat.Fabric)
		end,
		Fog = function(pos, s)
			smoke(pos, COL.FogC, 6, 2.6 * s, 1.3, 2)
		end,
		Reaper = function(pos, s)
			smoke(pos, rgb(70, 40, 110), 6, 2.6 * s, 1.2, 4)
			FX.Burst(pos, COL.Purple, 14, 0.4, 9)
			FX.Ring(ground(pos), 6, COL.Purple, 0.6, 0.3, 1, 0.2)
		end,
		GraveBreak = function(pos)
			debris(pos, COL.Stone, 14, 0.9, 11, 1.2)
			smoke(pos, rgb(110, 105, 100), 6, 3.5, 1.4, 3)
			FX.Ring(ground(pos), 12, rgb(150, 255, 140), 0.8, 0.5, 1, 0.1)
			FX.Shake(0.5, 0.6)
		end,
		MonarchDeath = function(pos)
			flash(pos + V(0, 4, 0), COL.Fire, 14, 1.2)
			FX.Ring(ground(pos), 20, COL.Ember, 1.2, 0.8, 1, 0.05)
			FX.Burst(pos + V(0, 4, 0), COL.Gold, 24, 0.5, 12, 1)
			debris(pos + V(0, 6, 0), COL.Gold, 10, 0.6, 9, 1.4, Mat.Metal)
			smoke(pos, rgb(60, 30, 20), 8, 5, 2.2, 6)
			FX.Shake(0.9, 1.2)
			FX.Sound("Secret", 0.8, 0.8, pos)
		end,
	}

	FX.Fn.EnemyDeath = function(view, reason)
		local name = view.Rig.DeathFX
		local fn = name and DEATH[name]
		if not fn or reason == "clear" then
			return
		end
		local def = FX.Env.Config.Enemies[view.Type] or {}
		local pos = view.Rig.Root.Position
		if name == "MonarchDeath" then
			-- детали короны отрываются и падают
			for _, d in ipairs(view.Rig.Model:GetDescendants()) do
				if d:IsA("BasePart") and d:GetAttribute("Crown") and d.Transparency < 1 then
					local c = d:Clone()
					c:ClearAllChildren()
					c.Anchored = true
					c.Parent = FX.Folder
					d.Transparency = 1
					FX.Fade(c, 1.4, { CFrame = c.CFrame * CF(rng:NextNumber(-3, 3), -4, rng:NextNumber(-3, 3)) * ANG(rng:NextNumber(-2, 2), 0, rng:NextNumber(-2, 2)) })
				end
			end
		end
		fn(pos, def.Scale or 1)
	end

	FX.Fn.EnemySpawn = function(view, atStart)
		local name = view.Rig.SpawnFX
		if not name or not atStart then
			return
		end
		local g = ground(view.Rig.Root.Position)
		if name == "GraveBreak" then
			-- плита могилы поднимается и раскалывается
			local slab = FX.Part({ Size = V(6, 0.8, 9), CFrame = CF(g + V(0, 0.4, 0)), Color = COL.Stone, Material = Mat.Slate })
			FX.Tween(slab, 0.5, { CFrame = CF(g + V(0, 2.5, 0)) * ANG(rad(25), 0, rad(-10)) })
			task.delay(0.55, function()
				slab:Destroy()
				debris(g + V(0, 2.5, 0), COL.Stone, 12, 1.1, 12, 1.3)
				smoke(g + V(0, 1, 0), rgb(110, 105, 100), 6, 4, 1.4, 3)
				FX.Ring(g, 10, rgb(150, 255, 140), 0.7, 0.4, 1, 0.1)
				FX.Shake(0.6, 0.6)
			end)
		elseif name == "FogVortex" then
			-- вихрь тумана сгущается в жнеца
			local n = FX.Lite and 4 or 12
			local balls = {}
			for i = 1, n do
				balls[i] = { FX.Part({ Shape = Enum.PartType.Ball, Size = V(3, 3, 3), Color = COL.FogC, Material = Mat.SmoothPlastic, Transparency = 0.6, CFrame = CF(g) }), i / n * math.pi * 2, rng:NextNumber(0, 6) }
			end
			FX.Run(function(t)
				if t >= 1.4 then
					for _, b in ipairs(balls) do
						b[1]:Destroy()
					end
					FX.Sphere(g + V(0, 4, 0), 7, COL.Red, 0.4, nil, 0.4)
					return true
				end
				local r = math.max(0.5, 10 - t * 7)
				for _, b in ipairs(balls) do
					local a = b[2] + t * 5
					b[1].CFrame = CF(g + V(math.cos(a) * r, 1 + b[3] * 0.6 + t * 2, math.sin(a) * r))
					b[1].Transparency = 0.6 + math.clamp((t - 1) / 0.4, 0, 0.4)
				end
				return false
			end)
		elseif name == "MonarchPortal" then
			-- монарх выходит из огненного портала
			FX.PortalDisc(g + V(0, 9, 0), 8, rgb(150, 50, 15), 2.0, COL.Fire)
			task.delay(1.1, function()
				FX.Cracks(g, 12, COL.Ember, 12, 2)
				FX.Ring(g, 16, COL.Ember, 0.8, 0.6, 1, 0.05)
				FX.Burst(g + V(0, 1, 0), COL.Fire, 20, 0.5, 12)
				FX.Shake(0.7, 0.7)
				FX.Sound("Explosion", 1, 0.4, g)
			end)
		end
	end

	------------------------------------------------------------------------
	-- АТАКИ ЮНИТОВ СОБЫТИЯ (вылет; урон и области — по Impact)
	------------------------------------------------------------------------
	FX.Fn.HalloweenAttack = function(view, def, p, h, lv)
		if def.Event ~= "Halloween" or def.AttackType == "Chrono" then
			return false
		end
		local rend = R()
		local firstId = p.T and p.T[1]
		local id = view.UnitId
		local kind = def.AttackType
		local muzzle0 = rend.MuzzlePos(view)
		local function alive()
			return view.Rig and view.Rig.Model.Parent ~= nil
		end
		local function at(d, fn)
			task.delay(d, function()
				if alive() then
					fn()
				end
			end)
		end
		local function arcTo(target, up, mult, minR, a0, a1, color, th, life)
			local origin = view.Rig.Root.Position + V(0, up, 0)
			local flat = V(target.X, origin.Y, target.Z)
			FX.Arc(CFrame.lookAt(origin, flat), math.max((flat - origin).Magnitude * mult, minR), rad(a0), rad(a1), color, th, life)
		end
		if kind == "Melee" then
			at(h, function()
				local target = center(firstId)
				if target then
					arcTo(target, 1, 0.6, 3, 20, 150, COL.Dirt, 0.6, 0.3)
					debris(ground(target) + V(0, 0.5, 0), COL.Dirt, 3, 0.35, 5, 0.6, Mat.Ground)
					FX.Sound("HeavyHit", 0.8, 1, target)
				end
			end)
		elseif kind == "Pulse" then
			at(h, function()
				flash(muzzle0, COL.Bell, 1.6, 0.25)
			end)
		elseif kind == "Flask" then
			at(h, function()
				FX.Projectile("Flask", rend.MuzzlePos(view), function() return center(firstId) end, p.TR or 0.4, nil, lv)
			end)
		elseif kind == "Pierce" then
			at(h, function()
				FX.Sphere(rend.MuzzlePos(view), 1.8, COL.Blue, 0.25)
			end)
		elseif kind == "Thread" then
			at(h, function()
				for _, tid in ipairs(p.T or {}) do
					local target = center(tid)
					if target then
						FX.Thread(rend.MuzzlePos(view), target, def.ThreadColor or COL.Red)
					end
				end
				FX.Sound("Magic", 0.8, 0.7, view.Pos)
			end)
		elseif kind == "AOE" then
			at(h, function()
				if id == "NightWatchman" then
					flash(rend.MuzzlePos(view), COL.Light, 1.5, 0.2)
				elseif id == "HeadlessExecutioner" then
					local target = center(firstId)
					if target then
						arcTo(target, 2, 0.7, 4, 10, 160, COL.Ember, 1.1, 0.35)
					end
				end
			end)
		elseif kind == "Projectile" and def.Projectile == "Crow" then
			for si, tid in ipairs(p.T or { firstId }) do
				local travel = (p.TRS and p.TRS[si]) or p.TR or 0.3
				at(h + (si - 1) * (p.SG or 0.12), function()
					crowFly(rend.MuzzlePos(view), function() return center(tid) end, travel, function(pos)
						FX.Burst(pos, COL.Black, 5, 0.3, 5)
					end)
				end)
			end
		else
			return false
		end
		return true
	end

	------------------------------------------------------------------------
	-- «Призрачная корона»: синяя копия юнита за спиной повторяет атаку
	------------------------------------------------------------------------
	local STRIP = { ParticleEmitter = true, BillboardGui = true, PointLight = true, Trail = true, Motor6D = true, Highlight = true }
	FX.Fn.EchoGhost = function(view)
		if not view.Rig or not view.Rig.Model.Parent or (FX.Lite and rng:NextNumber() < 0.5) then
			return
		end
		local model = view.Rig.Model
		local was = model.Archivable
		model.Archivable = true
		local ok, clone = pcall(function() return model:Clone() end)
		model.Archivable = was
		if not ok or not clone then
			return
		end
		local parts = {}
		for _, d in ipairs(clone:GetDescendants()) do
			if d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = false
				d.CanQuery = false
				d.CanTouch = false
				d.CastShadow = false
				if d.Transparency < 1 then
					d.Color = COL.Ghost
					d.Material = Mat.Neon
					d.Transparency = 0.55
					parts[#parts + 1] = d
				end
			elseif STRIP[d.ClassName] then
				d:Destroy()
			end
		end
		local root = view.Rig.Root.CFrame
		local back = root * CF(0, 0.3, 2.4)
		local fwd = root * CF(0, 0.3, -0.6)
		clone:PivotTo(back)
		clone.Parent = FX.Folder
		FX.Run(function(t)
			if t >= 0.7 or not clone.Parent then
				clone:Destroy()
				return true
			end
			clone:PivotTo(back:Lerp(fwd, math.clamp(t / 0.25, 0, 1) * 0.7))
			local tr = 0.55 + math.clamp((t - 0.35) / 0.35, 0, 1) * 0.45
			for _, d in ipairs(parts) do
				d.Transparency = tr
			end
			return false
		end)
	end

	------------------------------------------------------------------------
	-- Король фонарей: трон поднимается из огня
	------------------------------------------------------------------------
	FX.Fn.ThronePlace = function(pos)
		local g = ground(pos)
		local low = V(0, 3, 0)
		local list = {
			FX.Part({ Size = V(4, 0.6, 3.5), CFrame = CF(g - low), Color = COL.Black, Material = Mat.Slate }),
			FX.Part({ Size = V(4, 6, 0.6), CFrame = CF(g + V(0, 0, 1.6) - low), Color = COL.Black, Material = Mat.Slate }),
			FX.Part({ Size = V(4.3, 0.3, 0.7), CFrame = CF(g + V(0, 3, 1.6) - low), Color = COL.Gold }),
		}
		for _, q in ipairs(list) do
			local up = q.CFrame + V(0, 3.3, 0)
			FX.Tween(q, 0.6, { CFrame = up }, Enum.EasingStyle.Back)
			task.delay(1.6, function()
				FX.Fade(q, 0.6, { CFrame = up - V(0, 2, 0) })
			end)
		end
		FX.Ring(g, 6, COL.Ember, 0.8, 0.5, 1, 0.1)
		FX.Burst(g + V(0, 1, 0), COL.Fire, 20, 0.45, 10, 0.8)
		for i = 0, 5 do
			local a = i / 6 * math.pi * 2
			local q = g + V(math.cos(a) * 4, 0, math.sin(a) * 4)
			local pk = FX.Part({ Size = V(1, 0.8, 1), CFrame = CF(q - V(0, 1, 0)), Color = PUMPKIN, Material = Mat.SmoothPlastic })
			FX.Tween(pk, 0.5, { CFrame = CF(q + V(0, 0.4, 0)) }, Enum.EasingStyle.Back)
			task.delay(1.8, function()
				FX.Fade(pk, 0.5)
			end)
		end
		flash(g + V(0, 3, 0), COL.Orange, 5, 0.8)
		FX.Sound("Secret", 0.6, 1.2, g)
	end
end
