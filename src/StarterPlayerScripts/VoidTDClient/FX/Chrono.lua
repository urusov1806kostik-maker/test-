--!nocheck
-- VOID TD :: FX/Chrono — эффекты Проклятого Часовщика (золото, бронза, оранжевые искры)
-- Регистрирует FX.GearDisc, FX.ChronoHit, FX.TinyClock, FX.TimeBreak, FX.TimeHaste, FX.TimeStorm,
-- FX.ChronoBurst, FX.ClockPortal (+ те же в FX.Fn) и удары ChronoHit ChronoBurst TimeBreak TimeHaste TimeStorm.

return function(FX)
	local V = Vector3.new
	local CF = CFrame.new
	local ANG = CFrame.Angles
	local rad = math.rad
	local rng = FX.Rng
	local C = FX.Colors
	local CGOLD, BRONZE, ORANGE, DIAL = C.CGold, C.Bronze, C.Orange, C.Dial
	local METAL = Enum.Material.Metal
	local FLOOR = ANG(rad(-90), 0, 0)

	local function reg(name, fn)
		FX[name] = fn
		FX.Fn[name] = fn
	end

	-- набор деталей, движущихся как одно целое: { {part, offset}, ... }
	local function addRigid(set, props, offset)
		local p = FX.Part(props)
		set[#set + 1] = { p, offset or CF() }
		return p
	end

	local function placeRigid(set, cf)
		for _, it in ipairs(set) do
			it[1].CFrame = cf * it[2]
		end
	end

	local function fadeParts(list, time)
		for _, p in ipairs(list) do
			if p.Parent then
				FX.Tween(p, time, { Transparency = 1 })
			end
			FX.Cleanup(p, time + 0.05)
		end
	end

	local function fadeRigid(set, time)
		for _, it in ipairs(set) do
			if it[1].Parent then
				FX.Tween(it[1], time, { Transparency = 1 })
			end
			FX.Cleanup(it[1], time + 0.05)
		end
	end

	-- шестерня в плоскости XY: восьмиугольник из 4 брусков + 8 зубьев + ступица (последняя деталь)
	local function addGear(set, a, depth, color, hubColor, base)
		base = base or CF()
		for k = 0, 3 do
			addRigid(set, { Size = V(2 * a, 0.83 * a, depth), Color = color, Material = METAL }, base * ANG(0, 0, k * math.pi / 4))
		end
		if not FX.Lite then
			for k = 0, 7 do
				local ang = k * math.pi / 4
				addRigid(set, { Size = V(a * 0.36, a * 0.34, depth), Color = color, Material = METAL },
					base * CF(math.cos(ang) * a * 1.08, math.sin(ang) * a * 1.08, 0) * ANG(0, 0, ang))
			end
		end
		return addRigid(set, { Size = V(a * 0.45, a * 0.45, depth + 0.05), Color = hubColor or ORANGE }, base * ANG(0, 0, math.pi / 4))
	end

	-- циферблат в плоскости XY: рама, тёмный диск, 12 делений
	local function addDial(set, a, depth, transparency)
		local tr = transparency or 0
		for k = 0, 3 do
			local r = ANG(0, 0, k * math.pi / 4)
			addRigid(set, { Size = V(2 * a, 0.83 * a, depth), Color = CGOLD, Material = METAL, Transparency = tr }, r)
			addRigid(set, { Size = V(1.68 * a, 0.7 * a, depth + 0.04), Color = DIAL, Material = Enum.Material.SmoothPlastic, Transparency = tr }, r)
		end
		for k = 0, 11 do
			local ang = k * math.pi / 6
			addRigid(set, { Size = V(a * 0.06, a * (k % 3 == 0 and 0.2 or 0.11), depth + 0.08), Color = CGOLD },
				CF(math.cos(ang) * a * 0.68, math.sin(ang) * a * 0.68, 0) * ANG(0, 0, ang + math.pi / 2))
		end
	end

	-- стрелки: часовая и минутная
	local function makeHands(a, color)
		local h = FX.Part({ Size = V(a * 0.1, a * 0.45, 0.08), Color = color or CGOLD })
		local m = FX.Part({ Size = V(a * 0.06, a * 0.7, 0.08), Color = color or CGOLD })
		return h, m
	end

	local function placeHands(h, m, cf, ha, ma, a, depth)
		h.CFrame = cf * ANG(0, 0, ha) * CF(0, a * 0.2, -depth / 2 - 0.08)
		m.CFrame = cf * ANG(0, 0, ma) * CF(0, a * 0.32, -depth / 2 - 0.1)
	end

	-- кольцо из сегментов радиуса rr (n штук, пропуск по skip(k))
	local function ringSegments(set, rr, n, height, depth, skip)
		for k = 0, n - 1 do
			if not (skip and skip(k)) then
				local ang = k / n * math.pi * 2
				addRigid(set, { Size = V(2 * math.pi * rr / n * 1.05, height, depth), Color = CGOLD, Material = METAL },
					CF(math.cos(ang) * rr, 0, math.sin(ang) * rr) * ANG(0, -ang - math.pi / 2, 0))
			end
		end
	end

	-- разрез секунд: вращающийся зубчатый диск летит по прямой
	reg("GearDisc", function(from, to, duration, lv, storm)
		local set = {}
		local a = 0.75 + (lv or 1) * 0.08
		local hub = addGear(set, a, 0.18, storm and ORANGE or CGOLD, storm and Color3.fromRGB(255, 230, 160) or ORANGE)
		FX.Light(hub, ORANGE, 8, storm and 3 or 1.5)
		local dir = to - from
		local flat = V(dir.X, 0, dir.Z)
		local base = flat.Magnitude > 0.01 and CFrame.lookAt(Vector3.zero, flat).Rotation or CF()
		local dur = math.max(duration or 0.3, 0.05)
		placeRigid(set, CF(from) * base * ANG(rad(90), 0, 0))
		FX.Run(function(el)
			local alpha = math.clamp(el / dur, 0, 1)
			placeRigid(set, CF(from:Lerp(to, alpha)) * base * ANG(rad(90), 0, 0) * ANG(0, 0, el * 16))
			if alpha >= 1 then
				fadeRigid(set, 0.2)
				return true
			end
			return false
		end)
		FX.Sound("Slash", 0.8, 1.4, from)
	end)

	-- попадание диском: искры, оранжевая вспышка, призрачные стрелки
	reg("ChronoHit", function(pos)
		FX.Burst(pos, CGOLD, 5, 0.22, 6, 0.35)
		FX.Burst(pos, BRONZE, 3, 0.3, 4, 0.45)
		FX.Sphere(pos, 1.0, ORANGE, 0.18, nil, 0.3)
		if not FX.Lite then
			local cf = FX.CamFacing(pos + V(0, 1.2, 0))
			local h, m = makeHands(1.2, Color3.fromRGB(255, 220, 150))
			h.Transparency, m.Transparency = 0.3, 0.3
			placeHands(h, m, cf, 0, 0, 1.2, 0)
			FX.Tween(h, 0.4, { CFrame = cf * ANG(0, 0, -2.5) * CF(0, 0.24, -0.1), Transparency = 1 })
			FX.Tween(m, 0.4, { CFrame = cf * ANG(0, 0, 2.8) * CF(0, 0.38, -0.12), Transparency = 1 })
			FX.Cleanup(h, 0.45)
			FX.Cleanup(m, 0.45)
		end
	end)

	-- маленькие часы над точкой: стрелки крутятся со скоростью speed
	reg("TinyClock", function(pos, a, dur, speed)
		local set = {}
		addDial(set, a, 0.12)
		local h, m = makeHands(a)
		local cf = FX.CamFacing(pos)
		placeRigid(set, cf)
		placeHands(h, m, cf, 0, 0, a, 0.12)
		FX.Run(function(el)
			placeHands(h, m, cf, -el * speed * 0.2, -el * speed, a, 0.12)
			if el >= dur then
				fadeRigid(set, 0.25)
				fadeParts({ h, m }, 0.25)
				return true
			end
			return false
		end)
	end)

	-- ПОЛОМКА ВРЕМЕНИ: циферблат на дороге и в небе, стрелки резко останавливаются
	reg("TimeBreak", function(pos, radius, dur)
		dur = dur or 1.5
		local g = V(pos.X, pos.Y + 0.25, pos.Z)
		FX.Sound("Magic", 1, 0.55, pos)
		local floor = {}
		addDial(floor, radius, 0.12, 0.25)
		local floorCF = CF(g) * FLOOR
		placeRigid(floor, floorCF)
		local fh, fm = makeHands(radius)
		local sky = {}
		local skyA = radius * 0.45
		addDial(sky, skyA, 0.3)
		local skyCF = FX.CamFacing(g + V(0, radius * 0.9 + 3, 0))
		placeRigid(sky, skyCF)
		local sh, sm = makeHands(skyA)
		local rings = {}
		if not FX.Lite then
			for i = 1, 2 do
				local set = {}
				ringSegments(set, radius * (0.7 + i * 0.12), 16, 0.12, 0.2, function(k) return k % 4 == 3 end)
				rings[i] = { set, i * 0.9 }
			end
			for _ = 1, 10 do
				local ang = rng:NextNumber(0, math.pi * 2)
				local d = rng:NextNumber(0, radius * 0.9)
				local p = FX.Part({ Size = V(0.25, 0.25, 0.25), CFrame = CF(g + V(math.cos(ang) * d, rng:NextNumber(0.6, 3), math.sin(ang) * d)) * ANG(1, 2, 0),
					Color = rng:NextNumber() < 0.5 and CGOLD or ORANGE, Transparency = 0.15 })
				task.delay(dur, function()
					if p.Parent then
						FX.Tween(p, 0.35, { CFrame = p.CFrame + V(0, -1.5, 0), Transparency = 1 })
					end
				end)
				FX.Cleanup(p, dur + 0.4)
			end
		end
		FX.Run(function(el)
			-- первые 0.45 с стрелки бешено крутятся, затем замирают
			local spin = math.min(el, 0.45)
			local ha, ma = -spin * 14, -spin * 40
			placeHands(fh, fm, floorCF, ha, ma, radius, 0.12)
			placeHands(sh, sm, skyCF, ha * 0.8, ma * 0.8, skyA, 0.3)
			for _, rg in ipairs(rings) do
				placeRigid(rg[1], CF(g + V(0, rg[2], 0)) * ANG(0, spin * 3 * (rg[2] > 1 and -1 or 1), 0))
			end
			if el < dur then
				return false
			end
			FX.Sound("Explosion", 0.6, 1.4, pos)
			FX.Sphere(g + V(0, 1, 0), radius * 0.55, ORANGE, 0.35, nil, 0.3)
			FX.Ring(g, radius * 1.1, ORANGE, 0.45, 0.3, radius * 0.5, 0.2)
			FX.Burst(g + V(0, 1, 0), CGOLD, 12, 0.35, 10, 0.6)
			FX.Burst(g + V(0, 1, 0), BRONZE, 8, 0.4, 7, 0.6)
			fadeRigid(floor, 0.35)
			fadeRigid(sky, 0.35)
			for _, rg in ipairs(rings) do
				fadeRigid(rg[1], 0.3)
			end
			fadeParts({ fh, fm, sh, sm }, 0.3)
			return true
		end)
	end)

	-- УСКОРЕНИЕ ВРЕМЕНИ: золотое кольцо и маленькие часы над союзниками
	reg("TimeHaste", function(pos, radius, allyPositions, dur)
		dur = dur or 2
		local g = V(pos.X, pos.Y + 0.25, pos.Z)
		FX.Sound("Upgrade", 0.9, 1.35, pos)
		FX.Ring(g, radius, CGOLD, 0.8, 0.4, 1, 0.1)
		task.delay(0.12, function()
			FX.Ring(g + V(0, 0.1, 0), radius * 0.8, ORANGE, 0.7, 0.25, 1, 0.3)
		end)
		FX.Burst(g + V(0, 2, 0), CGOLD, 10, 0.3, 8, 0.6)
		for _, ap in ipairs(allyPositions or {}) do
			FX.TinyClock(ap + V(0, 7, 0), 0.7, dur, 18)
			FX.Ring(ap + V(0, 0.3, 0), 2.5, CGOLD, 0.4, 0.2, 0.5, 0.2)
		end
	end)

	-- ВРЕМЕННАЯ БУРЯ: механическое кольцо поднимается и бьёт по земле
	reg("TimeStorm", function(pos, delay)
		delay = delay or 1.2
		local g = V(pos.X, pos.Y + 0.25, pos.Z)
		FX.Sound("Magic", 1, 0.45, pos)
		local set = {}
		local rr = 6.5
		local n = FX.Lite and 8 or 16
		for k = 0, n - 1 do
			local ang = k / n * math.pi * 2
			addRigid(set, { Size = V(2 * math.pi * rr / n * 1.02, 0.5, 0.3), Color = CGOLD, Material = METAL },
				CF(math.cos(ang) * rr, 0, math.sin(ang) * rr) * ANG(0, -ang - math.pi / 2, 0))
			if k % 2 == 0 and not FX.Lite then
				addRigid(set, { Size = V(0.4, 0.8, 0.4), Color = ORANGE }, CF(math.cos(ang) * rr, 0.5, math.sin(ang) * rr) * ANG(0, -ang, math.pi / 4))
			end
		end
		placeRigid(set, CF(g + V(0, 0.5, 0)))
		FX.Run(function(el)
			local rise = math.min(el / delay, 1)
			placeRigid(set, CF(g + V(0, 0.5 + rise * 2, 0)) * ANG(0, el * 2.5 * (0.3 + rise), 0))
			if el < delay then
				return false
			end
			fadeRigid(set, 0.4)
			FX.Shockwave(g, 9, 3, CGOLD, ORANGE)
			FX.Sphere(g + V(0, 2, 0), 4, ORANGE, 0.45, nil, 0.25)
			return true
		end)
	end)

	-- удар во время бури: механический взрыв и часы над целью
	reg("ChronoBurst", function(pos, radius)
		local g = V(pos.X, pos.Y + 0.2, pos.Z)
		FX.Ring(g, radius, CGOLD, 0.45, 0.3, 0.5, 0.1)
		FX.Ring(g + V(0, 0.05, 0), radius * 0.6, ORANGE, 0.35, 0.2, 0.3, 0.3)
		FX.Burst(g + V(0, 1, 0), ORANGE, 8, 0.3, 9, 0.45)
		FX.Burst(g + V(0, 1, 0), BRONZE, 5, 0.35, 6, 0.5)
		if not FX.Lite then
			FX.TinyClock(g + V(0, 4, 0), 0.6, 0.6, 30)
		end
		FX.Sound("Explosion", 0.4, 1.6, pos)
	end)

	-- установка часовщика: циферблат, стрелки назад, золотой портал
	reg("ClockPortal", function(pos, dur)
		dur = dur or 1.3
		local g = V(pos.X, pos.Y + 0.25, pos.Z)
		local set = {}
		local a = 4.5
		addDial(set, a, 0.12, 0.2)
		local cf = CF(g) * FLOOR
		placeRigid(set, cf)
		local h, m = makeHands(a)
		placeHands(h, m, cf, 0, 0, a, 0.12)
		local portal = FX.Part({ Shape = Enum.PartType.Cylinder, Size = V(0.3, 0.5, 0.5), CFrame = CF(g + V(0, 0.2, 0)) * ANG(0, 0, rad(90)), Color = CGOLD, Transparency = 0.2 })
		FX.Tween(portal, dur * 0.6, { Size = V(0.3, a * 1.6, a * 1.6) })
		FX.Light(portal, ORANGE, 14, 2, dur + 0.5)
		FX.Sound("Portal", 0.9, 1.2, pos)
		FX.Run(function(el)
			placeHands(h, m, cf, el * 4, el * 22, a, 0.12)
			if el < dur then
				return false
			end
			fadeRigid(set, 0.5)
			fadeParts({ h, m, portal }, 0.5)
			FX.Burst(g + V(0, 2, 0), CGOLD, 14, 0.35, 8, 0.6)
			FX.Ring(g, 6, ORANGE, 0.5, 0.3, 2, 0.2)
			return true
		end)
	end)

	------------------------------------------------------------------------
	-- УДАРЫ (Impact)
	------------------------------------------------------------------------
	local I = FX.RegisterImpact
	I("ChronoHit", function(p) FX.ChronoHit(p.P + V(0, 1.5, 0)) end)
	I("ChronoBurst", function(p) FX.ChronoBurst(p.P, p.R or 5) end)
	I("TimeBreak", function(p) FX.TimeBreak(p.P, p.R or 9, p.DUR or 1.5) end)
	I("TimeHaste", function(p)
		local dur = p.DUR or 2
		local positions = {}
		for _, uid in ipairs(p.A or {}) do
			local v = FX.UnitView(uid)
			if v and v.Pos then
				positions[#positions + 1] = v.Pos
				if v.Rig then
					v.Rig.SpinBoostUntil = os.clock() + dur
				end
			end
		end
		FX.TimeHaste(p.P, p.R or 14, positions, dur)
	end)
	I("TimeStorm", function(p) FX.TimeStorm(p.P, p.DL or 1.3) end)
end
