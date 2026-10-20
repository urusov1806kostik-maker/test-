--!nocheck
-- VOID TD :: Models/Units/Shattered
-- Юниты кейса Shattered Reality (6, синие акценты): RiftScout CrystalHunter VoidPuppeteer Starbreaker
-- RiftMonarch RealityDestroyer. R6 в угловатом стиле, оружие в руке, Muzzle на острие, 5 уровней.

return function(UnitModels, Kit, Parts)
	local V = Vector3.new
	local CF = CFrame.new
	local ANG = CFrame.Angles
	local rad = math.rad
	local PI = math.pi

	local P, AC, M, rgb, GRIP = Parts.P, Parts.AC, Parts.M, Parts.rgb, Parts.GRIP
	local VOID = Parts.VOID
	local SH = Parts.SH
	local BLUE, BLUE_SOFT, NAVY, NAVY_D, SH_EDGE = SH.Blue, SH.BlueSoft, SH.Navy, SH.NavyD, SH.Edge
	local bevel, spike, gem = Kit.bevel, Kit.spike, Kit.gem
	local SIDES = { -1, 1 }

	local function register(id, build)
		UnitModels.Register(id, function(lv)
			local r, idle, aura = build(lv)
			Parts.levelAura(r, lv, aura)
			return r:Finish(UnitModels.Scale(id), idle)
		end)
	end

	------------------------------------------------------------------------
	-- RIFT SCOUT: разведчик в капюшоне с двумя кинжалами
	------------------------------------------------------------------------
	register("RiftScout", function(lv)
		local r = Parts.figure("RiftScout", { Torso = NAVY_D, Arm = NAVY_D, Leg = rgb(22, 24, 36), Edge = SH_EDGE })
		local steel = BLUE_SOFT:Lerp(AC.ArmorMid, 0.6)
		Parts.hood(r, NAVY, SH_EDGE, BLUE)
		bevel(r, r.Torso, V(1.6, 0.35, 1.2), CF(0, 0.92, 0), BLUE:Lerp(NAVY, 0.6), false, M.Fabric) -- шарф
		if lv >= 3 then -- светящаяся кайма шарфа
			r:Neon(r.Torso, V(1.62, 0.06, 0.05), CF(0, 0.8, -0.61), BLUE)
		end
		bevel(r, r.Torso, V(1.9, 0.9, 1.1), CF(0, 0.4, 0), rgb(36, 40, 60), SH_EDGE, M.Fabric) -- куртка
		Parts.belt(r, rgb(40, 34, 40), SH_EDGE, lv >= 3 and BLUE or nil)
		if lv >= 2 then
			bevel(r, r.RArm, V(1.2, 0.45, 1.2), CF(0.1, 0.9, 0) * ANG(0, 0, rad(-12)), NAVY, SH_EDGE)
		end
		Parts.bracers(r, NAVY, SH_EDGE)
		Parts.greaves(r, NAVY, SH_EDGE, true)
		Parts.dagger(r, r.RArm, lv >= 2 and BLUE or nil, 1.2 + (lv >= 4 and 0.3 or 0), steel)
		-- кинжал в левой руке (второе оружие: острие "Tip", Muzzle не меняется)
		local A = r.LArm
		r:Box(A, V(0.2, 0.2, 0.7), CF(0, GRIP, 0.05), AC.ClothDark, M.Fabric)
		r:Box(A, V(0.12, 0.3, 1.1), CF(0, GRIP, -0.9), steel, M.Metal)
		if lv >= 2 then
			r:Neon(A, V(0.14, 0.06, 1.05), CF(0, GRIP + 0.12, -0.9), BLUE)
		end
		spike(r, A, V(0, GRIP, -1.44), V(0, GRIP, -1.85), 0.3, steel, M.Metal, true, 0.12)
		Parts.muzzle(r, A, CF(0, GRIP, -1.85), true)
		if lv >= 4 then
			Parts.capeWith(r, 1.7, 2.6, NAVY, nil)
		end
		if lv >= 5 then
			r:Orbit("OrbitShards", r.Torso, CF(0, 0.3, 0), 1.9, 3, 0.25, BLUE)
		end
		return r, { RS = { 25, 0, 10 }, LS = { 25, 0, -10 } }, BLUE
	end)

	------------------------------------------------------------------------
	-- CRYSTAL HUNTER: охотник с кристальным арбалетом
	------------------------------------------------------------------------
	register("CrystalHunter", function(lv)
		local plate = rgb(40, 44, 62)
		local r = Parts.figure("CrystalHunter", { Torso = rgb(26, 26, 36), Arm = rgb(26, 26, 36), Leg = rgb(22, 22, 30), Edge = SH_EDGE })
		Parts.helm(r, rgb(30, 32, 46), SH_EDGE, BLUE, nil)
		Parts.chest(r, plate, SH_EDGE, BLUE)
		Parts.belt(r, rgb(40, 34, 40), SH_EDGE)
		Parts.plateShoulders(r, plate, SH_EDGE)
		for _, side in ipairs({ 1, -1 }) do -- кристаллы на плечах
			local A = side == 1 and r.RArm or r.LArm
			for k = 0, (lv >= 3 and 2 or 1) do
				spike(r, A, V(0.3 * side, 1.1, -0.3 + k * 0.4), V((0.65 + k * 0.1) * side, 1.75 + k * 0.1, -0.35 + k * 0.5), 0.3, BLUE, M.Neon)
			end
		end
		if lv >= 2 then -- кристаллы на спине
			for k = -1, 1 do
				spike(r, r.Torso, V(k * 0.5, 0.6, 0.5), V(k * 0.7, 1.4 - math.abs(k) * 0.3, 1.0), 0.35, BLUE, M.Neon)
			end
		end
		Parts.bracers(r, plate, SH_EDGE)
		Parts.greaves(r, plate, SH_EDGE, true)
		Parts.crossbow(r, r.RArm, { Stock = plate, Edge = SH_EDGE, Prong = rgb(30, 32, 46), Glow = BLUE })
		if lv >= 4 then
			Parts.capeWith(r, 1.8, 2.8, NAVY, BLUE)
		end
		if lv >= 5 then
			r:Orbit("OrbitCrystals", r.Torso, CF(0, 0.5, 0), 2.0, 4, 0.3, BLUE)
		end
		return r, { RS = { 75, 0, 0 }, LS = { 65, 0, -25 } }, BLUE
	end)

	------------------------------------------------------------------------
	-- VOID PUPPETEER: кукловод в маске-улыбке, нити из ладоней, куклы на орбите
	------------------------------------------------------------------------
	local PUPPET_IDLE = { RS = { 40, 0, 20 }, LS = { 40, 0, -20 } }
	register("VoidPuppeteer", function(lv)
		local cloth, hoodC, mask, wood = rgb(34, 22, 52), rgb(46, 28, 72), rgb(226, 220, 232), rgb(120, 90, 70)
		local r = Parts.figure("VoidPuppeteer", { Torso = cloth, Arm = cloth, Leg = cloth, Skin = rgb(220, 214, 226), Edge = AC.Edge })
		Parts.hood(r, hoodC, AC.Edge, VOID, true)
		r:Box(r.Head, V(0.86, 0.86, 0.06), CF(0, -0.04, -0.64), mask, M.Plastic) -- белая маска
		for _, s in ipairs(SIDES) do
			r:Neon(r.Head, V(0.18, 0.08, 0.04), CF(0.2 * s, 0.1, -0.68) * ANG(0, 0, rad(-14 * s)), VOID)
		end
		r:Box(r.Head, V(0.4, 0.06, 0.04), CF(0, -0.25, -0.68), rgb(20, 14, 26))
		Parts.robe(r, cloth, AC.Edge, 1.8)
		Parts.mantle(r, hoodC, AC.Edge)
		Parts.belt(r, rgb(50, 36, 30), AC.Edge, VOID)
		if lv >= 2 then -- самоцветы-застёжки на накидке
			for _, s in ipairs(SIDES) do
				gem(r, r.Torso, 0.22, CF(0.62 * s, 0.82, -0.66), VOID, AC.Edge)
			end
		end
		-- сферы-ромбы в ладонях; нити свисают вертикально (по миру в позе покоя)
		for _, side in ipairs({ 1, -1 }) do
			local A = side == 1 and r.RArm or r.LArm
			local c = V(0, -1.45, -0.2)
			r:Neon(A, V(0.45, 0.45, 0.45), CF(c) * ANG(rad(45), 0, rad(45)), VOID)
			if side == 1 then
				Parts.muzzle(r, A, CF(c))
			end
			local down = Parts.downIn(side == 1 and PUPPET_IDLE.RS or PUPPET_IDLE.LS)
			for k = -1, 1 do
				local a = c + V(k * 0.18, 0, 0) + down * 0.2
				Parts.thread(r, A, a, a + down * 1.3, P.NeonSoft, 0.03)
			end
		end
		-- марионетки на орбите (пустой узел + свои детали)
		local n = lv >= 4 and 3 or 2
		local hub = r:Orbit("OrbitPuppets", r.Torso, CF(0, -0.2, 0), 2.4, 0, 0.2, VOID)
		for i = 0, n - 1 do
			local a = i / n * PI * 2
			local p = V(math.cos(a) * 2.4, 0, math.sin(a) * 2.4)
			r:Box(hub, V(0.5, 0.55, 0.3), CF(p), wood, M.Wood)
			r:Box(hub, V(0.36, 0.36, 0.36), CF(p + V(0, 0.48, 0)), mask, M.Plastic)
			r:Box(hub, V(0.16, 0.45, 0.16), CF(p + V(-0.18, -0.48, 0)), wood, M.Wood)
			r:Box(hub, V(0.16, 0.45, 0.16), CF(p + V(0.18, -0.48, 0)), wood, M.Wood)
			r:Neon(hub, V(0.03, 1.2, 0.03), CF(p + V(0, 1.2, 0)), P.NeonSoft)
		end
		if lv >= 3 then
			Parts.capeWith(r, 2.0, 3.2, hoodC, VOID)
		end
		return r, PUPPET_IDLE
	end)

	------------------------------------------------------------------------
	-- STARBREAKER: золото-белый паладин с боевым молотом
	------------------------------------------------------------------------
	register("Starbreaker", function(lv)
		local gold, white, edge, star = rgb(200, 160, 74), rgb(226, 222, 234), rgb(255, 235, 180), rgb(255, 240, 200)
		local r = Parts.figure("Starbreaker", { Torso = white, Arm = gold, Leg = white, Edge = edge })
		Parts.helm(r, gold, edge, BLUE, gold, true)
		Parts.chest(r, gold, edge, BLUE)
		for k = 0, 3 do -- звёздная эмблема
			local dir = V(math.cos(k * PI / 2), math.sin(k * PI / 2), 0)
			spike(r, r.Torso, V(0, 0.5, -0.66), V(0, 0.5, -0.66) + dir * 0.45, 0.2, star, M.Metal, true, 0.06)
		end
		Parts.belt(r, rgb(60, 50, 40), gold, BLUE)
		Parts.tassets(r, gold, edge)
		Parts.bigShoulders(r, white, edge, BLUE, lv >= 4 and 1.2 or 1.05, lv >= 3 and 2 or 1)
		Parts.bracers(r, gold, edge)
		if lv >= 2 then -- синие самоцветы на наручах
			for _, s in ipairs({ 1, -1 }) do
				gem(r, s == 1 and r.RArm or r.LArm, 0.2, CF(0.58 * s, -0.55, 0) * ANG(0, -s * PI / 2, 0), BLUE, edge)
			end
		end
		Parts.greaves(r, gold, edge, true)
		Parts.hammer(r, r.RArm, { Head = white, Edge = edge, Trim = gold, Glow = BLUE, Wood = rgb(60, 50, 40) })
		Parts.capeWith(r, 2.1, 3.3, NAVY, lv >= 3 and BLUE or nil)
		if lv >= 5 then
			r:Orbit("OrbitStars", r.Head, CF(0, 1.3, 0), 1.6, 5, 0.3, rgb(255, 225, 140))
		end
		return r, { RS = { 30, 0, 0 }, LS = { 20, 0, 0 } }, rgb(255, 210, 110)
	end)

	------------------------------------------------------------------------
	-- RIFT MONARCH: монарх в короне с посохом и кольцами-порталами за спиной
	------------------------------------------------------------------------
	local function skipEvery5th(k)
		return k % 5 == 4
	end
	register("RiftMonarch", function(lv)
		local royal, black, edge = rgb(46, 40, 110), rgb(22, 22, 40), rgb(140, 150, 220)
		local r = Parts.figure("RiftMonarch", { Torso = black, Arm = royal, Leg = black, Edge = edge })
		Parts.helm(r, royal, edge, BLUE, nil, true)
		Parts.crown(r, rgb(200, 210, 255), BLUE, 0.6 + lv * 0.06)
		Parts.chest(r, royal, edge, BLUE)
		Parts.belt(r, black, edge, VOID)
		Parts.robe(r, royal, edge, 1.7)
		if lv >= 4 then -- светящиеся швы мантии
			for _, s in ipairs(SIDES) do
				r:Neon(r.Torso, V(0.06, 1.4, 0.05), CF(0.32 * s, -1.75, -0.6), BLUE)
			end
		end
		Parts.bigShoulders(r, black, edge, BLUE, 1.2, lv >= 3 and 2 or 1)
		Parts.bracers(r, royal, edge)
		if lv >= 2 then -- разломы на нагруднике
			Kit.crack(r, r.Torso, { V(-0.8, 0.95, -0.59), V(-0.45, 0.55, -0.6), V(-0.6, 0.15, -0.59) }, 0.05, BLUE)
		end
		Parts.capeWith(r, 2.3, 3.8, rgb(36, 30, 90), VOID)
		Parts.staff(r, r.RArm, { Glow = BLUE, Prong = edge, Wood = black, Top = 2.6, Big = true })
		for i, color in ipairs({ BLUE, VOID }) do -- кольца-порталы (второе с 3 ур.)
			if i == 1 or lv >= 3 then
				local radius = 1.0 + i * 0.35
				local hub = r:Orbit("OrbitRift" .. i, r.Torso, CF(0, 0.6, 1.6) * ANG(rad(90), 0, 0), radius, 0, 0.2, color)
				Kit.ring(r, hub, ANG(rad(90), 0, 0), radius, 14, 0.1, 0.1, color, M.Neon, skipEvery5th)
			end
		end
		return r, { RS = { 12, 0, 0 } }, BLUE
	end)

	------------------------------------------------------------------------
	-- REALITY DESTROYER: красно-чёрный разрушитель с огромным мечом
	------------------------------------------------------------------------
	register("RealityDestroyer", function(lv)
		local RED, black, mid, edge = rgb(255, 40, 50), rgb(24, 18, 22), rgb(44, 30, 36), rgb(160, 100, 110)
		local r = Parts.figure("RealityDestroyer", { Torso = black, Arm = black, Leg = black, Edge = edge })
		Parts.helm(r, black, edge, RED, nil, true)
		if lv >= 2 then -- самоцвет над визором
			gem(r, r.Head, 0.2, CF(0, 0.48, -0.7), RED, edge)
		end
		for _, s in ipairs(SIDES) do
			Kit.hornA(r, r.Head, { V(0.6 * s, 0.4, 0), V(1.0 * s, 0.7, 0), V(1.1 * s, 1.3, -0.05), V(0.9 * s, 1.8 + lv * 0.08, -0.2) }, 0.26, mid, M.Metal)
		end
		Parts.chest(r, mid, edge, RED)
		Kit.crack(r, r.Torso, { V(-0.85, 0.95, -0.59), V(-0.45, 0.45, -0.6), V(-0.7, -0.05, -0.59) }, 0.06, RED)
		Kit.crack(r, r.Torso, { V(0.7, 0.9, -0.59), V(0.85, 0.35, -0.59) }, 0.05, RED)
		Parts.belt(r, black, edge, RED)
		Parts.tassets(r, mid, edge)
		Parts.bigShoulders(r, black, edge, RED, 1.2 + (lv >= 4 and 0.1 or 0), lv >= 3 and 3 or 2)
		Parts.bracers(r, mid, edge)
		Parts.greaves(r, mid, edge, true)
		Parts.blade(r, r.RArm, {
			Len = 4.0 + lv * 0.15, W = 0.75, GuardW = 1.7, Blade = black, Glow = RED,
			Core = lv >= 3 and rgb(255, 150, 150) or nil, Guard = mid, Edge = edge, Trail = RED,
		})
		Parts.capeWith(r, 2.3, 3.6, rgb(90, 10, 20), RED)
		if lv >= 4 then
			r:Orbit("OrbitShards", r.Torso, CF(0, 0.6, 0), 2.6, lv >= 5 and 6 or 4, 0.3, RED)
		end
		return r, { RS = { 25, 0, 0 } }, RED
	end)
end
