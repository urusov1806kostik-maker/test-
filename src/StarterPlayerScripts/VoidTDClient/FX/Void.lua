--!nocheck
-- VOID TD :: FX/Void — эффекты способностей Пустоты, Расколотой реальности и Кровавой луны
-- Регистрирует FX.Shockwave, FX.Reap, FX.Judgement, FX.BlackHole, FX.CrystalBurst, FX.FallingShard,
-- FX.RiftPortal, FX.BigRift, FX.RedSplash, FX.Cleave, FX.Hammer, FX.BloodMoonFall, FX.BloodMoonBoom,
-- FX.PierceBeam (+ те же в FX.Fn) и удары Impact: Shockwave Reap Crystal Hammer Shard Rift BigRift Splash
-- Cleave BloodMoonFall BloodMoon Pierce Judgement BlackHole.

return function(FX)
	local V = Vector3.new
	local CF = CFrame.new
	local ANG = CFrame.Angles
	local rad = math.rad
	local rng = FX.Rng
	local C = FX.Colors
	local NEON, SOFT, PINK, WHITE, RED, GOLD, BLUE = C.Neon, C.Soft, C.Pink, C.White, C.Red, C.Gold, C.Blue
	local rgb = Color3.fromRGB
	local CYL = Enum.PartType.Cylinder
	local BALL = Enum.PartType.Ball
	local FLAT = ANG(0, 0, rad(90))
	local Quad, Back = Enum.EasingStyle.Quad, Enum.EasingStyle.Back
	local In = Enum.EasingDirection.In

	local function reg(name, fn)
		FX[name] = fn
		FX.Fn[name] = fn
	end

	-- ударная волна: кольца, трещины, камни, вспышка; на 5 уровне — столб и сферы
	reg("Shockwave", function(pos, radius, lv, color, soft)
		lv = lv or 1
		local col = color or NEON
		local sft = soft or SOFT
		local g = V(pos.X, pos.Y + 0.2, pos.Z)
		FX.Sound("Explosion", 1, 1, pos)
		local cam = workspace.CurrentCamera
		if cam and (cam.CFrame.Position - pos).Magnitude < 70 then
			FX.Shake(lv >= 5 and 0.5 or 0.25, 0.35)
		end
		FX.Ring(g, radius, col, 0.55, 0.5, 1, 0.05)
		FX.Ring(g + V(0, 0.15, 0), radius * 0.75, WHITE, 0.4, 0.3, 0.5, 0.2)
		task.delay(0.08, function()
			FX.Ring(g + V(0, 0.1, 0), radius * 1.05, sft, 0.6, 0.25, radius * 0.4, 0.4)
		end)
		FX.Cracks(g, radius, col, 6 + lv * 2, 1.4)
		if not FX.Lite then
			for _ = 1, 6 + lv do
				local a = rng:NextNumber(0, math.pi * 2)
				local r = rng:NextNumber(1, math.max(1, radius * 0.8))
				local p = g + V(math.cos(a) * r, 0, math.sin(a) * r)
				local rock = FX.Part({ Size = V(0.6, 0.6, 0.6), CFrame = CF(p), Color = rgb(50, 44, 60), Material = Enum.Material.Slate })
				FX.Tween(rock, 0.25, { CFrame = CF(p + V(0, rng:NextNumber(1.5, 3), 0)) * ANG(1, 2, 0) })
				task.delay(0.25, function()
					if rock.Parent then
						FX.Tween(rock, 0.3, { CFrame = CF(p) * ANG(2, 1, 1), Transparency = 1 }, Quad, In)
					end
				end)
				FX.Cleanup(rock, 0.6)
			end
		end
		local flash = FX.Part({ Size = V(0.2, 0.2, 0.2), CFrame = CF(g + V(0, 2, 0)), Transparency = 1 })
		FX.Light(flash, col, radius * 2.5, 5, 0.6)
		FX.Cleanup(flash, 0.7)
		if lv >= 5 then
			FX.Sphere(g, radius * 0.7, col, 0.6)
			FX.Sphere(g, radius * 0.45, WHITE, 0.4)
			local pillar = FX.Part({ Shape = CYL, Size = V(18, 3, 3), CFrame = CF(g + V(0, 9, 0)) * FLAT, Color = col, Transparency = 0.2 })
			FX.Tween(pillar, 0.6, { Size = V(26, 0.2, 0.2), Transparency = 1 })
			FX.Cleanup(pillar, 0.7)
			FX.Burst(g + V(0, 1, 0), sft, 20, 0.6, 16, 0.6)
		end
	end)

	-- удар косы: горизонтальная дуга + тёмная дуга + кольцо области
	reg("Reap", function(unitPos, center, radius, lv, color)
		lv = lv or 1
		local col = color or NEON
		local dir = center - unitPos
		dir = V(dir.X, 0, dir.Z)
		if dir.Magnitude < 0.1 then
			dir = V(0, 0, -1)
		end
		dir = dir.Unit
		local c = V(center.X, center.Y + 1.5, center.Z)
		local cf = CFrame.lookAt(c - dir * 1.5, c + dir)
		FX.Arc(cf, radius * 0.9, rad(-80), rad(80), col, 0.6 + lv * 0.08, 0.4, true)
		FX.Arc(cf * CF(0, -0.4, 0), radius * 0.75, rad(-70), rad(70), rgb(30, 10, 50), 0.5, 0.45, true)
		FX.Ring(V(center.X, center.Y + 0.15, center.Z), radius, rgb(90, 30, 150), 0.4, 0.2, radius * 0.3, 0.45)
		if lv >= 4 then
			FX.Burst(center + V(0, 1, 0), col, 10, 0.4, 8)
		end
	end)

	-- VOID JUDGEMENT: разрезы, луч с неба
	reg("Judgement", function(pos, lv, hitIndex)
		lv = lv or 1
		hitIndex = hitIndex or 1
		FX.Sound("Magic", 1, 0.9 + hitIndex * 0.08, pos)
		local col = hitIndex % 2 == 0 and NEON or PINK
		local p = pos + V(0, 2, 0)
		FX.SlashMark(p, rad(35 + rng:NextNumber(-10, 10)), 9 + lv, 0.7 + lv * 0.08, col, 0.45)
		if lv >= 3 then
			FX.SlashMark(p, rad(-35 + rng:NextNumber(-10, 10)), 8 + lv, 0.6, NEON, 0.4)
		end
		local beam = FX.Part({ Shape = CYL, Size = V(30, 1.4, 1.4), CFrame = CF(pos + V(0, 15, 0)) * FLAT, Color = col, Transparency = 0.3 })
		FX.Tween(beam, 0.35, { Size = V(30, 0.1, 0.1), Transparency = 1 })
		FX.Cleanup(beam, 0.4)
		FX.Burst(p, col, 8, 0.45, 9)
		FX.Ring(V(pos.X, pos.Y + 0.15, pos.Z), 3 + lv * 0.4, col, 0.4, 0.25)
	end)

	-- ЧЁРНАЯ ДЫРА: ядро, диск, вращающиеся рукава, частицы внутрь
	reg("BlackHole", function(pos, radius, duration, lv, delay)
		lv = lv or 1
		duration = duration or 2
		task.delay(delay or 0, function()
			FX.Sound("Portal", 1, 1, pos)
			local center = pos + V(0, 2.2, 0)
			local m = Instance.new("Model")
			m.Name = "BlackHole"
			m.Parent = FX.Folder
			local core = FX.Part({ Shape = BALL, Size = V(0.5, 0.5, 0.5), CFrame = CF(center), Color = rgb(0, 0, 0), Material = Enum.Material.SmoothPlastic, Parent = m })
			local glow = FX.Part({ Shape = BALL, Size = V(0.6, 0.6, 0.6), CFrame = CF(center), Color = NEON, Transparency = 0.55, Parent = m })
			local disk = FX.Part({ Shape = CYL, Size = V(0.15, 1, 1), CFrame = CF(pos + V(0, 0.2, 0)) * FLAT, Color = rgb(60, 20, 100), Transparency = 0.35, Parent = m })
			local edge = FX.Part({ Shape = CYL, Size = V(0.1, 1, 1), CFrame = CF(pos + V(0, 0.25, 0)) * FLAT, Color = NEON, Transparency = 0.5, Parent = m })
			FX.Light(glow, NEON, radius * 2.5, 3)
			local cs = 2.2 + lv * 0.35
			FX.Tween(core, 0.4, { Size = V(cs, cs, cs) }, Back)
			FX.Tween(disk, 0.4, { Size = V(0.15, radius * 2, radius * 2) })
			FX.Tween(edge, 0.4, { Size = V(0.1, radius * 2 + 0.6, radius * 2 + 0.6) })
			local arms = {}
			for i = 1, FX.Lite and 2 or (4 + (lv >= 5 and 2 or 0)) do
				arms[i] = FX.Part({ Size = V(0.35, 0.2, radius * 0.9), Color = (i % 2 == 0) and NEON or SOFT, Transparency = 0.2, Parent = m })
			end
			local em = Instance.new("ParticleEmitter")
			em.Color = ColorSequence.new(NEON)
			em.LightEmission = 1
			em.Rate = 30 + lv * 8
			em.Lifetime = NumberRange.new(0.5, 0.8)
			em.Speed = NumberRange.new(-radius * 1.6, -radius * 1.2)
			em.SpreadAngle = Vector2.new(180, 180)
			em.Size = NumberSequence.new(0.5, 0)
			em.Parent = glow
			local g15 = cs * 1.5
			local low = center + V(0, -1.6, 0)
			FX.Run(function(t)
				if t > duration or not m.Parent then
					return true
				end
				local n = #arms
				for i, a in ipairs(arms) do
					local ang = t * 4 + i / n * math.pi * 2
					local r = radius * 0.55
					local p = center + V(math.cos(ang) * r, -1.6 + math.sin(t * 3 + i) * 0.3, math.sin(ang) * r)
					a.CFrame = CFrame.lookAt(p, low) * ANG(0, rad(70), 0)
				end
				-- пульсация свечения
				local s = g15 * (1 + math.sin(t * 8) * 0.06)
				glow.Size = V(s, s, s)
				return false
			end)
			task.delay(duration, function()
				em.Enabled = false
				for _, d in ipairs(m:GetChildren()) do
					if d:IsA("BasePart") then
						FX.Tween(d, 0.35, { Size = V(0.05, 0.05, 0.05), Transparency = 1 }, Back, In)
					end
				end
				task.delay(0.3, function()
					FX.Sphere(center, radius * 0.6, NEON, 0.35)
				end)
				FX.Cleanup(m, 0.8)
			end)
		end)
	end)

	-- кристаллический взрыв (Crystal Hunter)
	reg("CrystalBurst", function(pos, radius)
		FX.Sphere(pos, radius * 0.6, BLUE, 0.3)
		FX.Ring(V(pos.X, pos.Y + 0.2, pos.Z), radius, rgb(170, 225, 255), 0.35, 0.25)
		FX.Burst(pos + V(0, 1, 0), BLUE, 8, 0.35, 8)
		FX.Sound("Explosion", 0.5, 1.6, pos)
	end)

	-- падающий звёздный осколок
	reg("FallingShard", function(pos, radius, color)
		local col = color or GOLD
		local top = pos + V(rng:NextNumber(-3, 3), 22, rng:NextNumber(-3, 3))
		local shard = FX.Part({ Size = V(0.7, 2.2, 0.7), CFrame = CF(top) * ANG(0, rng:NextNumber(0, 6), rad(15)), Color = col })
		FX.Tween(shard, 0.28, { CFrame = CF(pos + V(0, 1, 0)) * ANG(0, 2, rad(15)) }, Quad, In)
		task.delay(0.28, function()
			shard:Destroy()
			FX.Ring(V(pos.X, pos.Y + 0.2, pos.Z), radius, col, 0.35, 0.3)
			FX.Sphere(pos + V(0, 0.5, 0), radius * 0.4, rgb(255, 240, 200), 0.25)
			FX.Burst(pos + V(0, 1, 0), col, 6, 0.4, 8)
		end)
	end)

	-- маленький портал с разрезом (RIFT STORM)
	reg("RiftPortal", function(pos, lv)
		lv = lv or 1
		local c = pos + V(0, 3.5, 0)
		local cf = CF(c) * ANG(0, rng:NextNumber(0, 6), 0)
		local ring = FX.Part({ Shape = CYL, Size = V(0.2, 0.5, 0.5), CFrame = cf, Color = NEON })
		FX.Tween(ring, 0.15, { Size = V(0.2, 3.2, 3.2) }, Back)
		local core = FX.Part({ Shape = CYL, Size = V(0.25, 0.3, 0.3), CFrame = cf, Color = rgb(15, 0, 30) })
		FX.Tween(core, 0.15, { Size = V(0.25, 2.4, 2.4) }, Back)
		task.delay(0.15, function()
			FX.SlashMark(pos + V(0, 1.5, 0), rad(rng:NextNumber(-50, 50)), 6 + lv * 0.5, 0.5, PINK, 0.3)
			FX.Burst(pos + V(0, 1, 0), NEON, 6, 0.35, 7)
			if ring.Parent then
				FX.Tween(ring, 0.25, { Size = V(0.1, 0.2, 0.2), Transparency = 1 })
				FX.Tween(core, 0.25, { Size = V(0.1, 0.1, 0.1), Transparency = 1 })
			end
		end)
		FX.Cleanup(ring, 0.45)
		FX.Cleanup(core, 0.45)
		FX.Sound("Portal", 0.5, 1.4, pos)
	end)

	-- большой центральный разлом
	reg("BigRift", function(pos, radius)
		local g = V(pos.X, pos.Y + 0.2, pos.Z)
		local disk = FX.Part({ Shape = CYL, Size = V(0.2, 1, 1), CFrame = CF(g) * FLAT, Color = rgb(15, 0, 30) })
		FX.Tween(disk, 0.25, { Size = V(0.2, radius * 2, radius * 2) }, Back)
		FX.Ring(g, radius * 1.1, NEON, 0.6, 0.5, 1, 0.05)
		FX.Ring(g + V(0, 0.1, 0), radius * 0.8, PINK, 0.5, 0.3, 0.5)
		for i = 1, 4 do
			task.delay(i * 0.05, function()
				local off = V(rng:NextNumber(-radius / 2, radius / 2), 2, rng:NextNumber(-radius / 2, radius / 2))
				FX.SlashMark(g + off, rad(rng:NextNumber(-60, 60)), 9, 0.7, NEON, 0.4)
			end)
		end
		task.delay(0.35, function()
			if disk.Parent then
				FX.Tween(disk, 0.35, { Size = V(0.1, 0.5, 0.5), Transparency = 1 })
			end
		end)
		FX.Cleanup(disk, 0.8)
		FX.Shake(0.4, 0.4)
		FX.Sound("Explosion", 1, 0.7, pos)
	end)

	-- RED SPLASH: красная волна, вспышка и осколки из меча
	reg("RedSplash", function(pos, radius, from)
		local g = V(pos.X, pos.Y + 0.2, pos.Z)
		FX.Ring(g, radius, RED, 0.5, 0.5, 1, 0.05)
		FX.Ring(g + V(0, 0.12, 0), radius * 0.7, rgb(255, 150, 150), 0.35, 0.25, 0.5, 0.2)
		local flash = FX.Part({ Shape = CYL, Size = V(0.08, radius * 1.6, radius * 1.6), CFrame = CF(g + V(0, 0.05, 0)) * FLAT, Color = RED, Transparency = 0.3 })
		FX.Tween(flash, 0.3, { Transparency = 1 })
		FX.Cleanup(flash, 0.35)
		FX.Sphere(pos + V(0, 1, 0), 2.5, RED, 0.25)
		if from then
			for _ = 1, FX.Lite and 2 or 6 do
				local to = g + V(rng:NextNumber(-radius, radius) * 0.7, 0.5, rng:NextNumber(-radius, radius) * 0.7)
				local shard = FX.Part({ Size = V(0.25, 0.25, 1.1), CFrame = CFrame.lookAt(from, to), Color = RED })
				FX.Tween(shard, 0.25, { CFrame = CFrame.lookAt(to, to + (to - from)), Transparency = 0.6 })
				FX.Cleanup(shard, 0.27)
			end
		end
		FX.Cracks(g, radius * 0.8, RED, 6, 0.9)
		FX.Sound("HeavyHit", 1, 0.9, pos)
	end)

	-- рассекающий удар топора
	reg("Cleave", function(unitPos, center, radius, color)
		local col = color or RED
		FX.Reap(unitPos, center, radius, 4, col)
		FX.Ring(V(center.X, center.Y + 0.2, center.Z), radius, col, 0.4, 0.3)
		FX.Sound("HeavyHit", 1, 1, center)
	end)

	-- молот Starbreaker
	reg("Hammer", function(pos, radius, lv)
		FX.Shockwave(pos, radius, lv or 1, GOLD, rgb(200, 140, 255))
	end)

	-- кровавая луна падает с неба
	reg("BloodMoonFall", function(pos, radius, delay)
		delay = delay or 1
		local moon = FX.Part({ Shape = BALL, Size = V(5, 5, 5), CFrame = CF(pos + V(0, 45, 0)), Color = RED })
		FX.Light(moon, RED, 40, 4)
		local mark = FX.Part({ Shape = CYL, Size = V(0.1, radius * 2, radius * 2), CFrame = CF(pos + V(0, 0.25, 0)) * FLAT, Color = RED, Transparency = 0.75 })
		FX.Tween(moon, delay, { CFrame = CF(pos + V(0, 2, 0)), Size = V(7, 7, 7) }, Quad, In)
		FX.Tween(mark, delay, { Transparency = 0.4 })
		FX.Cleanup(moon, delay)
		FX.Cleanup(mark, delay)
		FX.Sound("Boss", 0.6, 1.4, pos)
	end)

	reg("BloodMoonBoom", function(pos, radius)
		FX.Shockwave(pos, radius, 5, RED, rgb(255, 140, 140))
		FX.Sphere(pos + V(0, 2, 0), radius * 0.6, rgb(120, 0, 15), 0.6, Enum.Material.Neon, 0.3)
		FX.Shake(0.6, 0.6)
	end)

	-- пробивающий лунный луч
	reg("PierceBeam", function(from, to)
		FX.Beam(from + V(0, 3, 0), to + V(0, 1.5, 0), 2.2, rgb(255, 190, 215), 0.45, true)
		FX.Sound("Laser", 1, 1.2, from)
	end)

	------------------------------------------------------------------------
	-- УДАРЫ (Impact)
	------------------------------------------------------------------------
	local Config = FX.Env.Config

	local function unitOf(p)
		local v = p.U and FX.UnitView(p.U)
		local def = v and Config.Units[v.UnitId]
		return v, def
	end

	local I = FX.RegisterImpact
	I("Shockwave", function(p) FX.Shockwave(p.P, p.R or 6, p.L or 1) end)
	I("Reap", function(p)
		local v, def = unitOf(p)
		FX.Reap((v and v.Pos) or p.P, p.P, p.R or 6, p.L or 1, def and def.ImpactColor)
		FX.Sound("Slash", 1, 0.8, p.P)
	end)
	I("Crystal", function(p) FX.CrystalBurst(p.P, p.R or 4) end)
	I("Hammer", function(p) FX.Hammer(p.P, p.R or 6, p.L or 1) end)
	I("Shard", function(p) FX.FallingShard(p.P, p.R or 4) end)
	I("Rift", function(p) FX.RiftPortal(p.P, p.L or 1) end)
	I("BigRift", function(p) FX.BigRift(p.P, p.R or 8) end)
	I("Splash", function(p)
		local v = unitOf(p)
		FX.RedSplash(p.P, p.R or 6, v and FX.MuzzlePos(v) or nil)
	end)
	I("Cleave", function(p)
		local v = unitOf(p)
		FX.Cleave((v and v.Pos) or p.P, p.P, p.R or 6)
	end)
	I("BloodMoonFall", function(p) FX.BloodMoonFall(p.P, p.R or 10, p.DL) end)
	I("BloodMoon", function(p) FX.BloodMoonBoom(p.P, p.R or 10) end)
	I("Pierce", function(p) FX.PierceBeam(p.P, p.E or p.P) end)
	I("Judgement", function(p) FX.Judgement(p.P, p.L or 1, p.H) end)
	I("BlackHole", function(p) FX.BlackHole(p.P, p.R or 8, p.DUR or 2, p.L or 1, p.DL) end)
end
