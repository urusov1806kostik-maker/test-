--!nocheck
-- VOID TD :: Models/Units/Blood
-- Юниты кейса Blood Moon (6, кровавые акценты): BloodAcolyte (Blood Initiate), CrimsonGunslinger
-- (Scarlet Hunter), MoonWitch (Crimson Witch), BloodfangWarlord (Blood Paladin), LunarSeraph
-- (Moon Devourer), CrimsonEclipse (Scarlet Eclipse). R6 в угловатом стиле, Muzzle на острие, 5 уровней.

return function(UnitModels, Kit, Parts)
	local V = Vector3.new
	local V2 = Vector2.new
	local CF = CFrame.new
	local ANG = CFrame.Angles
	local rad = math.rad

	local AC, M, rgb, GRIP = Parts.AC, Parts.M, Parts.rgb, Parts.GRIP
	local BL = Parts.BL
	local BLOOD, BLOOD_SOFT, CRIMSON, CRIMSON_D, BL_EDGE, BL_DARK = BL.Blood, BL.BloodSoft, BL.Crimson, BL.CrimsonD, BL.Edge, BL.Dark
	local bevel, spike, gem, bar = Kit.bevel, Kit.spike, Kit.gem, Kit.bar
	local SIDES = { -1, 1 }

	local function register(id, build)
		UnitModels.Register(id, function(lv)
			local r, idle = build(lv)
			Parts.levelAura(r, lv, BLOOD)
			return r:Finish(UnitModels.Scale(id), idle)
		end)
	end

	-- Серповидное лезвие из брусков по точкам pts (+ неоновая кромка, смещённая на edgeDy)
	local function crescent(r, A, pts, width, color, glow, edgeDy)
		for i = 1, #pts - 1 do
			bar(r, A, pts[i], pts[i + 1], V2(0.12, width - i * 0.07), color)
			if glow then
				bar(r, A, pts[i] + V(0, edgeDy[1], 0), pts[i + 1] + V(0, edgeDy[2], 0), V2(0.14, 0.05), glow, M.Neon)
			end
		end
	end

	------------------------------------------------------------------------
	-- BLOOD INITIATE: послушник в капюшоне с глефой
	------------------------------------------------------------------------
	register("BloodAcolyte", function(lv)
		local r = Parts.figure("BloodAcolyte", { Torso = CRIMSON_D, Arm = CRIMSON_D, Leg = BL_DARK, Edge = BL_EDGE })
		local A = r.RArm
		Parts.hood(r, CRIMSON, BL_EDGE, BLOOD)
		Parts.robe(r, CRIMSON_D, lv >= 3 and CRIMSON or nil, 1.6)
		Parts.belt(r, rgb(40, 26, 26), BL_EDGE, lv >= 2 and BLOOD or nil)
		if lv >= 2 then
			Parts.mantle(r, CRIMSON, BL_EDGE)
		end
		Parts.bracers(r, BL_DARK, BL_EDGE)
		-- глефа с серповидным лезвием
		local top = Parts.shaft(r, A, -2.4, 2.2, rgb(40, 26, 26), 0.2)
		local pts = { top, top + V(0, 0.45, -0.5), top + V(0, 0.3, -1.1), top + V(0, -0.15, -1.4) }
		for i = 1, 3 do
			bar(r, A, pts[i], pts[i + 1], V2(0.12, 0.34 - i * 0.06), lv >= 5 and CRIMSON or AC.ArmorMid)
		end
		if lv >= 3 then
			bar(r, A, pts[2] + V(0, -0.15, 0), pts[3] + V(0, -0.12, 0), V2(0.14, 0.05), BLOOD, M.Neon)
		end
		spike(r, A, top + V(0, 0.1, 0), top + V(0, 0.8, 0), 0.3, AC.ArmorMid, M.Metal)
		r:WeaponTrail(A, top + V(0, 0.3, -0.5), pts[4], BLOOD)
		Parts.muzzle(r, A, CF(pts[4]))
		if lv >= 4 then
			Parts.capeWith(r, 1.9, 3.0, CRIMSON, nil)
		end
		if lv >= 5 then
			r:Orbit("OrbitBlood", r.Torso, CF(0, 0.5, 0), 1.8, 3, 0.3, BLOOD)
		end
		return r, { RS = { 20, 0, 0 } }
	end)

	------------------------------------------------------------------------
	-- SCARLET HUNTER: красный охотник с луком
	------------------------------------------------------------------------
	register("CrimsonGunslinger", function(lv)
		local r = Parts.figure("CrimsonGunslinger", { Torso = BL_DARK, Arm = BL_DARK, Leg = BL_DARK, Edge = BL_EDGE })
		Parts.hood(r, CRIMSON, BL_EDGE, BLOOD)
		bevel(r, r.Torso, V(2.12, 1.2, 1.12), CF(0, 0.35, 0), rgb(50, 26, 30), BL_EDGE, M.Fabric) -- куртка
		bar(r, r.Torso, V(-0.9, 0.95, -0.58), V(0.9, -0.6, -0.58), V2(0.2, 0.06), rgb(70, 40, 34)) -- ремень
		if lv >= 3 then -- кровавый самоцвет на ремне
			gem(r, r.Torso, 0.22, CF(0, 0.18, -0.63), BLOOD, BL_EDGE)
		end
		Parts.belt(r, rgb(50, 30, 28), BL_EDGE, lv >= 3 and BLOOD or nil)
		Parts.quiver(r, rgb(60, 30, 28), BLOOD)
		Parts.mantle(r, CRIMSON, BL_EDGE)
		Parts.bracers(r, rgb(60, 30, 28), BL_EDGE)
		Parts.greaves(r, BL_DARK, BL_EDGE, true)
		Parts.bow(r, r.LArm, { Wood = lv >= 4 and CRIMSON_D or rgb(60, 34, 30), Glow = lv >= 2 and BLOOD or nil, Tip = BL_EDGE })
		if lv >= 4 then
			Parts.capeWith(r, 1.9, 3.0, CRIMSON, nil)
		end
		if lv >= 5 then
			r:Box(r.Head, V(1.06, 0.4, 0.08), CF(0, -0.3, -0.64), BL_DARK, M.Metal) -- маска
		end
		return r, { LS = { 20, 0, 0 } }
	end)

	------------------------------------------------------------------------
	-- CRIMSON WITCH: ведьма в остроконечной шляпе с посохом-полумесяцем
	------------------------------------------------------------------------
	register("MoonWitch", function(lv)
		local r = Parts.figure("MoonWitch", { Torso = CRIMSON_D, Arm = CRIMSON_D, Leg = BL_DARK, Skin = rgb(220, 196, 190), Edge = BL_EDGE })
		local A = r.RArm
		Parts.eyes(r, BLOOD, true, 0.06)
		bevel(r, r.Head, V(1.3, 1.1, 0.3), CF(0, -0.1, 0.52), rgb(30, 18, 22), false, M.Plastic) -- волосы
		Parts.wizardHat(r, BL_DARK, CRIMSON, BL_EDGE)
		if lv >= 3 then -- самоцвет на ленте шляпы
			gem(r, r.Head, 0.2, CF(0, 0.82, -0.72), BLOOD, BL_EDGE)
		end
		Parts.robe(r, CRIMSON_D, CRIMSON, 1.8)
		Parts.belt(r, rgb(40, 24, 26), BL_EDGE, BLOOD)
		if lv >= 2 then
			Parts.mantle(r, CRIMSON, BL_EDGE)
		end
		-- посох с полумесяцем (дуга 200°..340° в плоскости YZ руки)
		local top = Parts.shaft(r, A, -2.4, 2.3, rgb(40, 24, 26), 0.2)
		if lv >= 3 then -- светящееся кольцо под полумесяцем
			r:Neon(A, V(0.28, 0.12, 0.28), CF(top - V(0, 0.18, 0)), BLOOD)
		end
		local c = top + V(0, 0.6, 0)
		for k = 0, 4 do
			local a1, a2 = rad(200 + k * 28), rad(200 + (k + 1) * 28)
			bar(r, A, c + V(0, math.sin(a1) * 0.55, math.cos(a1) * 0.55), c + V(0, math.sin(a2) * 0.55, math.cos(a2) * 0.55), V2(0.12, 0.14), BLOOD, M.Neon)
		end
		r:Neon(A, V(0.3, 0.3, 0.3), CF(c) * ANG(rad(45), 0, rad(45)), BLOOD_SOFT)
		Parts.muzzle(r, A, CF(c))
		if lv >= 4 then
			Parts.capeWith(r, 1.9, 3.0, CRIMSON, BLOOD)
		end
		if lv >= 5 then
			r:Orbit("OrbitMoon", r.Torso, CF(0, 1.4, 0), 1.9, 3, 0.3, BLOOD_SOFT)
		end
		return r, { RS = { 10, 0, 0 }, LS = { 10, 0, -10 } }
	end)

	------------------------------------------------------------------------
	-- BLOOD PALADIN: красная броня, башенный щит, топор
	------------------------------------------------------------------------
	register("BloodfangWarlord", function(lv)
		local r = Parts.figure("BloodfangWarlord", { Torso = BL_DARK, Arm = CRIMSON, Leg = BL_DARK, Edge = BL_EDGE })
		Parts.helm(r, CRIMSON, BL_EDGE, BLOOD, BL_DARK, true)
		if lv >= 3 then
			for _, s in ipairs(SIDES) do
				Kit.hornA(r, r.Head, { V(0.6 * s, 0.45, 0), V(0.9 * s, 0.7, 0), V(0.95 * s, 1.2, -0.1) }, 0.22, BL_DARK, M.Metal)
			end
		end
		Parts.chest(r, CRIMSON, BL_EDGE, BLOOD)
		Parts.belt(r, rgb(40, 24, 26), BL_EDGE, BLOOD)
		Parts.tassets(r, CRIMSON, BL_EDGE)
		Parts.bigShoulders(r, CRIMSON, BL_EDGE, lv >= 3 and BLOOD or nil, lv >= 4 and 1.2 or 1.05, lv >= 4 and 2 or 1)
		Parts.bracers(r, BL_DARK, BL_EDGE)
		Parts.greaves(r, CRIMSON, BL_EDGE, true)
		if lv >= 2 then -- кровавые трещины на нагруднике
			Kit.crack(r, r.Torso, { V(0.8, 0.95, -0.59), V(0.45, 0.5, -0.6), V(0.65, 0.1, -0.59) }, 0.05, BLOOD)
		end
		Parts.axe(r, r.RArm, { Head = AC.ArmorMid, Edge = BL_EDGE, Glow = BLOOD, Wood = rgb(40, 24, 26) })
		Parts.shield(r, r.LArm, { Color = CRIMSON, Edge = BL_EDGE, H = 2.8, W = 1.7, Rim = BL_DARK, Gem = BLOOD })
		Parts.capeWith(r, 2.1, 3.3, CRIMSON_D, lv >= 3 and BLOOD or nil)
		return r, { RS = { 30, 0, 0 } }
	end)

	------------------------------------------------------------------------
	-- MOON DEVOURER: рогатая тёмная броня, парные клинки-полумесяцы, кровавая луна за спиной
	------------------------------------------------------------------------
	local function moonGap(k)
		return k >= 11 -- разрыв: полумесяц
	end
	register("LunarSeraph", function(lv)
		local r = Parts.figure("LunarSeraph", { Torso = BL_DARK, Arm = BL_DARK, Leg = BL_DARK, Edge = BL_EDGE })
		Parts.helm(r, BL_DARK, BL_EDGE, BLOOD, nil, true)
		for _, s in ipairs(SIDES) do
			local tip = V(1.0 * s, 2.0 + lv * 0.08, -0.15)
			Kit.hornA(r, r.Head, { V(0.62 * s, 0.4, 0), V(1.1 * s, 0.75, 0.1), V(1.25 * s, 1.4, 0.05), tip }, 0.28, CRIMSON_D, M.Metal)
			if lv >= 4 then -- раскалённые кончики рогов
				spike(r, r.Head, V(1.2 * s, 1.6, 0), tip, 0.16, BLOOD, M.Neon, false, 0.08)
			end
		end
		Parts.chest(r, CRIMSON_D, BL_EDGE, BLOOD)
		Kit.crack(r, r.Torso, { V(-0.8, 0.95, -0.59), V(-0.4, 0.5, -0.6), V(-0.65, 0.05, -0.59) }, 0.05, BLOOD)
		Parts.belt(r, BL_DARK, BL_EDGE, BLOOD)
		Parts.tassets(r, CRIMSON_D, BL_EDGE)
		Parts.bigShoulders(r, BL_DARK, BL_EDGE, BLOOD, 1.2, lv >= 3 and 3 or 2)
		Parts.bracers(r, CRIMSON_D, BL_EDGE)
		Parts.greaves(r, CRIMSON_D, BL_EDGE, true)
		-- клинки-полумесяцы в обеих руках: рукоять с гардой и шейкой до середины лезвия (не висит в воздухе)
		for _, A in ipairs({ r.RArm, r.LArm }) do
			r:Box(A, V(0.22, 0.22, 0.7), CF(0, GRIP, 0.05), BL_DARK, M.Fabric)
			bevel(r, A, V(0.26, 0.5, 0.26), CF(0, GRIP, -0.38), BL_DARK, BL_EDGE)
			bar(r, A, V(0, GRIP, -0.45), V(0, GRIP, -1.3), V2(0.14, 0.16), CRIMSON_D, M.Metal)
			local c = V(0, GRIP, -0.9)
			for k = 0, 4 do
				local a1, a2 = rad(-80 + k * 32), rad(-80 + (k + 1) * 32)
				bar(r, A, c + V(0, math.sin(a1) * 0.9, -math.cos(a1) * 0.5), c + V(0, math.sin(a2) * 0.9, -math.cos(a2) * 0.5), V2(0.12, 0.2), AC.ArmorMid)
				bar(r, A, c + V(0, math.sin(a1) * 1.0, -math.cos(a1) * 0.6), c + V(0, math.sin(a2) * 1.0, -math.cos(a2) * 0.6), V2(0.13, 0.05), BLOOD, M.Neon)
			end
		end
		Parts.muzzle(r, r.RArm, CF(0, GRIP, -1.5))
		Parts.muzzle(r, r.LArm, CF(0, GRIP, -1.5), true)
		-- кровавая луна за спиной: медленно вращается (SpinRates)
		local moon = r:Joint("MoonBack", r.Torso, V(0.2, 0.2, 0.2), CF(0, 1.2, 1.2), CF(), BLOOD)
		moon.Transparency = 1
		Kit.ring(r, moon, CF(), 1.5 + lv * 0.08, 16, 0.18, 0.14, BLOOD, M.Neon, moonGap)
		r.SpinRates = r.SpinRates or {}
		r.SpinRates.MoonBack = 0.35
		Parts.capeWith(r, 2.2, 3.5, CRIMSON_D, BLOOD)
		return r, { RS = { 10, 0, 0 } }
	end)

	------------------------------------------------------------------------
	-- SCARLET ECLIPSE: капюшон, кольцо затмения за головой, двойная глефа
	------------------------------------------------------------------------
	register("CrimsonEclipse", function(lv)
		local r = Parts.figure("CrimsonEclipse", { Torso = BL_DARK, Arm = BL_DARK, Leg = BL_DARK, Edge = BL_EDGE })
		local A = r.RArm
		Parts.hood(r, CRIMSON_D, BL_EDGE, BLOOD, true)
		r:Box(r.Head, V(0.9, 0.4, 0.06), CF(0, -0.28, -0.64), BL_DARK, M.Metal) -- маска нижней части лица
		Parts.chest(r, CRIMSON_D, BL_EDGE, BLOOD)
		Parts.belt(r, BL_DARK, BL_EDGE, BLOOD)
		Parts.robe(r, BL_DARK, CRIMSON, 2.0)
		Parts.bigShoulders(r, CRIMSON_D, BL_EDGE, BLOOD, 1.15, lv >= 3 and 3 or 2)
		Parts.bracers(r, CRIMSON_D, BL_EDGE)
		if lv >= 2 then -- кровавые трещины на маске
			Kit.crack(r, r.Head, { V(-0.3, -0.12, -0.68), V(-0.12, -0.3, -0.68), V(-0.22, -0.44, -0.68) }, 0.04, BLOOD)
		end
		-- кольцо затмения: тёмный диск в кровавом ободе, медленно вращается (SpinRates)
		local ecl = r:Joint("SpinEclipse", r.Head, V(0.2, 0.2, 0.2), CF(0, 0.3, 0.95), CF(), BLOOD)
		ecl.Transparency = 1
		Kit.ring(r, ecl, CF(), 1.25, 16, 0.2, 0.12, BLOOD, M.Neon)
		r:Box(ecl, V(1.7, 1.7, 0.08), CF(0, 0, 0.06) * ANG(0, 0, rad(45)), rgb(10, 6, 8), M.Plastic)
		r.SpinRates = r.SpinRates or {}
		r.SpinRates.SpinEclipse = 0.5
		-- двойная глефа: лезвия на обоих концах древка (зеркально)
		local top = Parts.shaft(r, A, -2.2, 2.2, BL_DARK, 0.2)
		for _, base in ipairs({ top, V(0, -2.2, -0.5) }) do
			local d = base.Y > 0 and 1 or -1
			local pts = { base, base + V(0, 0.4 * d, -0.6), base + V(0, 0.2 * d, -1.4), base + V(0, -0.3 * d, -1.9) }
			crescent(r, A, pts, 0.4, CRIMSON_D, BLOOD, { -0.15 * d, -0.12 * d })
		end
		r:WeaponTrail(A, top + V(0, 0.3, -0.6), top + V(0, -0.3, -1.9), BLOOD)
		Parts.muzzle(r, A, CF(top + V(0, -0.3, -1.9)))
		Parts.capeWith(r, 2.2, 3.6, CRIMSON_D, BLOOD)
		if lv >= 4 then
			r:Orbit("OrbitBlood", r.Torso, CF(0, 0.5, 0), 2.4, lv >= 5 and 6 or 4, 0.3, BLOOD)
		end
		return r, { RS = { 8, 0, 0 } }
	end)
end
