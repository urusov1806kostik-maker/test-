--!nocheck
-- VOID TD :: Models/Units/Void
-- Юниты кейса Пустоты (11): VoidSoldier ShadowArcher LostMage VoidKnight DarkGunner AbyssReaper
-- CorruptedSamurai EclipseGuardian FallenAngel VoidEmperor AbyssOverlord.
-- R6 в угловатом стиле, оружие в руке, Muzzle на острие; 5 уровней заметно отличаются деталями.
-- Модуль ставится из Units/init: `require(Void)(UnitModels, Kit, Parts)`.

return function(UnitModels, Kit, Parts)
	local V = Vector3.new
	local V2 = Vector2.new
	local CF = CFrame.new
	local ANG = CFrame.Angles
	local rad = math.rad
	local PI = math.pi

	local P, AC, M, rgb, GRIP = Parts.P, Parts.AC, Parts.M, Parts.rgb, Parts.GRIP
	local VOID = Parts.VOID
	local bevel, spike, gem, bar = Kit.bevel, Kit.spike, Kit.gem, Kit.bar
	local SIDES = { -1, 1 }

	-- Регистрация: строитель возвращает rig, позу покоя и цвет эффектов уровня;
	-- эффекты уровня и Finish (масштаб из Config.Units[id].Scale) — здесь
	local function register(id, build)
		UnitModels.Register(id, function(lv)
			local r, idle, aura = build(lv)
			Parts.levelAura(r, lv, aura)
			return r:Finish(UnitModels.Scale(id), idle)
		end)
	end

	------------------------------------------------------------------------
	-- VOID SOLDIER: латник с мечом и щитом
	------------------------------------------------------------------------
	register("VoidSoldier", function(lv)
		local r = Parts.figure("VoidSoldier", { Torso = AC.Armor, Arm = AC.Armor, Leg = rgb(28, 26, 34), Edge = AC.Edge })
		Parts.chest(r, AC.ArmorMid, AC.Edge, lv >= 3 and VOID or nil)
		Parts.belt(r, rgb(40, 30, 38), AC.Edge, lv >= 2 and VOID or nil)
		Parts.tassets(r, AC.ArmorMid, AC.Edge)
		Parts.helm(r, AC.Armor, AC.Edge, VOID, lv >= 3 and AC.Armor or nil)
		if lv >= 2 then
			Parts.plateShoulders(r, AC.ArmorMid, AC.Edge, lv >= 4 and 1.15 or 1)
		end
		Parts.bracers(r, AC.ArmorMid, AC.Edge)
		Parts.greaves(r, AC.ArmorMid, AC.Edge, true)
		Parts.blade(r, r.RArm, {
			Len = 2.6 + (lv >= 4 and 0.4 or 0), W = 0.45, Edge = AC.Edge,
			Blade = lv >= 5 and AC.Cloth or AC.ArmorMid, Glow = lv >= 3 and VOID or nil,
		})
		Parts.shield(r, r.LArm, {
			Color = lv >= 3 and AC.Cloth or AC.ArmorMid, Edge = AC.Edge,
			H = lv >= 3 and 2.2 or 1.7, W = lv >= 3 and 1.5 or 1.25,
			Rim = lv >= 2 and AC.Edge or nil, Gem = lv >= 3 and VOID or nil,
		})
		if lv >= 4 then -- табард
			r:Box(r.Torso, V(0.9, 1.1, 0.06), CF(0, -1.5, -0.6), AC.Cloth, M.Fabric)
			Kit.tatter(r, r.Torso, -2.05, -0.6, 0.9, 3, AC.Cloth, M.Fabric, 2)
		end
		if lv >= 5 then
			for _, s in ipairs(SIDES) do
				Kit.hornA(r, r.Head, { V(0.6 * s, 0.35, 0), V(0.9 * s, 0.6, 0.05), V(0.95 * s, 1.1, -0.05) }, 0.2, AC.Armor, M.Metal)
			end
			Parts.capeWith(r, 1.9, 2.8, AC.ClothDark, VOID)
		end
		return r, { RS = { 15, 0, 0 } }
	end)

	------------------------------------------------------------------------
	-- SHADOW ARCHER: лучник в капюшоне
	------------------------------------------------------------------------
	register("ShadowArcher", function(lv)
		local r = Parts.figure("ShadowArcher", { Torso = rgb(30, 26, 36), Arm = rgb(30, 26, 36), Leg = rgb(24, 22, 30), Edge = rgb(90, 84, 104) })
		Parts.hood(r, AC.ClothDark, AC.Edge, VOID)
		bevel(r, r.Torso, V(2.12, 1.2, 1.12), CF(0, 0.35, 0), rgb(40, 32, 44), AC.Edge, M.Fabric) -- куртка
		bar(r, r.Torso, V(-0.9, 0.95, -0.58), V(0.9, -0.6, -0.58), V2(0.2, 0.06), rgb(70, 50, 40)) -- ремень колчана
		Parts.belt(r, rgb(50, 36, 30), AC.Edge)
		Parts.quiver(r, rgb(50, 36, 30), lv >= 3 and VOID or AC.Edge)
		if lv >= 2 then
			bevel(r, r.LArm, V(1.2, 0.5, 1.2), CF(-0.1, 0.9, 0) * ANG(0, 0, rad(12)), AC.ArmorMid, AC.Edge)
		end
		Parts.bracers(r, rgb(50, 36, 30), AC.Edge)
		Parts.greaves(r, rgb(34, 30, 40), AC.Edge, true)
		Parts.bow(r, r.LArm, { Wood = lv >= 4 and AC.Armor or rgb(56, 40, 34), Glow = lv >= 3 and VOID or nil, Tip = AC.Edge })
		if lv >= 4 then
			Parts.capeWith(r, 1.9, 3.0, AC.ClothDark, nil)
		end
		if lv >= 5 then
			r:Box(r.Head, V(1.06, 0.4, 0.08), CF(0, -0.3, -0.64), AC.Armor, M.Metal) -- маска
			Parts.mantle(r, AC.Cloth, AC.Edge)
		end
		return r, { LS = { 20, 0, 0 } }
	end)

	------------------------------------------------------------------------
	-- LOST MAGE: маг в остроконечной шляпе с посохом
	------------------------------------------------------------------------
	register("LostMage", function(lv)
		local r = Parts.figure("LostMage", { Torso = AC.ClothDark, Arm = AC.ClothDark, Leg = AC.ClothDark, Skin = rgb(64, 56, 72), Edge = AC.Edge })
		r:Box(r.Head, V(1.04, 1.0, 0.05), CF(0, -0.05, -0.61), rgb(14, 10, 20), M.Plastic) -- тёмное лицо
		Parts.eyes(r, VOID, true, 0.05)
		Parts.wizardHat(r, lv >= 4 and AC.Cloth or AC.ClothDark, lv >= 3 and rgb(150, 110, 60) or rgb(60, 44, 70), AC.Edge)
		Parts.robe(r, AC.ClothDark, lv >= 2 and AC.Cloth or nil, 1.8)
		Parts.belt(r, rgb(50, 36, 30), AC.Edge, lv >= 3 and VOID or nil)
		if lv >= 2 then
			Parts.mantle(r, AC.Cloth, AC.Edge)
		end
		bevel(r, r.Torso, V(0.2, 0.6, 0.5), CF(-1.08, -0.9, -0.1), rgb(70, 40, 30), AC.Edge) -- книга на поясе
		Parts.staff(r, r.RArm, { Glow = VOID, Top = 2.2 + (lv >= 4 and 0.4 or 0), Big = lv >= 4 })
		if lv >= 5 then
			r:Orbit("OrbitStaff", r.Torso, CF(0, 0.4, 0), 2.0, 4, 0.3, P.NeonSoft)
			Parts.capeWith(r, 1.9, 2.8, AC.Cloth, VOID)
		end
		return r, { RS = { 10, 0, 0 }, LS = { 8, 0, 0 } }
	end)

	------------------------------------------------------------------------
	-- VOID KNIGHT (по концепту): гранёная кираса, рогатый шлем, клинок Пустоты
	------------------------------------------------------------------------
	-- Клинок Пустоты: тёмное тело с неоновыми кромками, рогатая гарда с самоцветами
	local function voidBlade(r, A, lv)
		local y = GRIP
		local len = 3.5 + (lv >= 4 and 0.5 or 0) + (lv >= 5 and 0.4 or 0)
		local w = 0.62 + (lv >= 3 and 0.08 or 0)
		local glow = lv >= 5 and P.NeonSoft or P.Neon
		local body = lv >= 5 and AC.Cloth or AC.ArmorMid
		r:Box(A, V(0.24, 0.24, 0.95), CF(0, y, 0.1), AC.ClothDark, M.Fabric) -- рукоять
		r:Box(A, V(0.34, 0.34, 0.3), CF(0, y, 0.65) * ANG(0, 0, rad(45)), AC.Armor, M.Metal) -- навершие
		bevel(r, A, V(0.32, 1.4, 0.32), CF(0, y, -0.45), AC.Armor, AC.Edge) -- гарда
		for _, s in ipairs(SIDES) do
			spike(r, A, V(0, y + 0.62 * s, -0.45), V(0, y + 0.95 * s, -0.85), 0.32, AC.Armor, M.Metal, true, 0.14)
		end
		gem(r, A, 0.3, CF(-0.17, y, -0.45) * ANG(0, PI / 2, 0), P.Neon)
		gem(r, A, 0.3, CF(0.17, y, -0.45) * ANG(0, -PI / 2, 0), P.Neon)
		local z0 = -0.6
		r:Box(A, V(0.14, w, len), CF(0, y, z0 - len / 2), body, M.Metal)
		for _, s in ipairs(SIDES) do -- кромки
			r:Neon(A, V(0.16, 0.08, len * 0.97), CF(0, y + s * (w / 2 - 0.03), z0 - len / 2), glow)
		end
		if lv >= 3 then -- светящийся дол
			r:Neon(A, V(0.17, 0.08, len * 0.7), CF(0, y, z0 - len * 0.42), P.NeonSoft)
		end
		spike(r, A, V(0, y, z0 - len + 0.02), V(0, y, z0 - len - w * 1.3), w, body, M.Metal, true, 0.14)
		spike(r, A, V(0, y, z0 - len + 0.02), V(0, y, z0 - len - w * 1.15), w * 0.75, glow, M.Neon, true, 0.16)
		r:WeaponTrail(A, V(0, y, z0 - 0.15), V(0, y, z0 - len - w), P.NeonSoft)
		return Parts.muzzle(r, A, CF(0, y, z0 - len - w))
	end

	register("VoidKnight", function(lv)
		local r = Kit.Rig.new({ Name = "VoidKnight", Torso = AC.Armor, Arm = AC.Armor, Leg = AC.Armor, Head = AC.Armor, TorsoMat = M.Metal })
		local T, H, RA, LA = r.Torso, r.Head, r.RArm, r.LArm
		for _, L in ipairs({ T, H, RA, LA, r.RLeg, r.LLeg }) do
			L.Transparency = 1
		end
		local leather = rgb(40, 30, 38)
		-- кираса
		bevel(r, T, V(2.05, 2.0, 1.05), CF(), AC.Armor, AC.Edge)
		bevel(r, T, V(2.25, 1.0, 1.25), CF(0, 0.5, -0.02), AC.ArmorMid, AC.Edge)
		bevel(r, T, V(1.85, 0.32, 1.15), CF(0, -0.15, 0), AC.ArmorMid, AC.Edge)
		bevel(r, T, V(1.8, 0.32, 1.12), CF(0, -0.45, 0), AC.Armor, AC.Edge)
		if lv >= 2 then -- центральное ребро и самоцвет
			bevel(r, T, V(0.34, 0.95, 0.18), CF(0, 0.5, -0.7), AC.Armor, AC.Edge)
			gem(r, T, 0.42, CF(0, 0.55, -0.8), P.Neon, AC.Edge)
		end
		if lv >= 3 then
			Kit.crack(r, T, { V(-0.85, 0.85, -0.66), V(-0.5, 0.45, -0.66), V(-0.7, 0.1, -0.66) }, 0.06)
			Kit.crack(r, T, { V(0.55, 0.9, -0.66), V(0.8, 0.4, -0.66) }, 0.05)
		end
		-- пояс с пряжкой, табард, набедренники
		bevel(r, T, V(2.15, 0.32, 1.2), CF(0, -0.8, 0), leather, AC.Edge, M.Fabric)
		bevel(r, T, V(0.48, 0.44, 0.14), CF(0, -0.8, -0.66), AC.Edge, AC.ArmorMid)
		gem(r, T, 0.2, CF(0, -0.8, -0.75), P.Neon)
		r:Box(T, V(0.95, 1.0, 0.08), CF(0, -1.45, -0.6), AC.Cloth, M.Fabric)
		if lv >= 2 then
			Kit.tatter(r, T, -1.95, -0.6, 0.95, 3, AC.Cloth, M.Fabric, 1)
		end
		for _, s in ipairs(SIDES) do
			bevel(r, T, V(0.75, 0.7, 0.95), CF(0.78 * s, -1.25, -0.02) * ANG(0, 0, rad(10 * s)), AC.ArmorMid, AC.Edge)
		end
		if lv >= 3 then
			Kit.chain(r, T, 4, 0.26, nil, CF(0.75, -1.0, -0.62))
			Kit.chain(r, T, 3, 0.26, nil, CF(-0.7, -1.0, 0.62))
		end
		-- шлем: гранёный, лицевая пластина, Т-визор, двускатный верх, нащёчники
		bevel(r, H, V(1.35, 1.4, 1.4), CF(0, 0.05, 0), AC.Armor, AC.Edge)
		bevel(r, H, V(1.12, 1.05, 0.22), CF(0, -0.05, -0.72), AC.ArmorMid, AC.Edge)
		r:Neon(H, V(0.5, 0.09, 0.06), CF(0, 0.2, -0.84), P.Neon)
		r:Neon(H, V(0.1, 0.62, 0.06), CF(0, -0.08, -0.84), P.Neon)
		r:Wedge(H, V(1.36, 0.42, 0.7), CF(0, 0.96, -0.35), AC.Armor, M.Metal)
		r:Wedge(H, V(1.36, 0.42, 0.7), CF(0, 0.96, 0.35) * ANG(0, PI, 0), AC.Armor, M.Metal)
		r:Box(H, V(1.38, 0.06, 0.06), CF(0, 1.16, 0), AC.Edge, M.Metal)
		for _, s in ipairs(SIDES) do
			r:Wedge(H, V(0.28, 0.55, 0.55), CF(0.58 * s, -0.5, -0.5) * ANG(PI, 0, 0), AC.Armor, M.Metal)
		end
		if lv >= 2 then
			spike(r, H, V(0, 1.0, -0.3), V(0, 1.45 + lv * 0.12, 0.2), 0.8, AC.Armor, M.Metal, true, 0.14) -- гребень
			local big = lv >= 5 and 1.6 or (lv >= 4 and 1.2 or 0.85)
			for _, s in ipairs(SIDES) do
				Kit.hornA(r, H, { V(0.6 * s, 0.3, 0), V(0.95 * s, 0.45 + 0.1 * big, 0.05), V(1.05 * s, 0.8 * big, 0.05), V(0.85 * s, 1.35 * big, -0.1) }, 0.24 + 0.04 * big, AC.Armor, M.Metal)
				if lv >= 5 then
					spike(r, H, V(0.95 * s, 1.0 * big, -0.05), V(0.85 * s, 1.35 * big, -0.1), 0.2, P.Neon, M.Neon, false, 0.1)
				end
			end
		end
		-- наплечники и руки: плечо, наруч с манжетой, латная перчатка
		for _, a in ipairs({ { RA, 1 }, { LA, -1 } }) do
			local A, s = a[1], a[2]
			if lv == 1 then
				bevel(r, A, V(1.35, 0.55, 1.3), CF(0.12 * s, 0.85, 0) * ANG(0, 0, rad(-12 * s)), AC.ArmorMid, AC.Edge)
			else
				local size = lv >= 5 and 1.22 or (lv >= 4 and 1.1 or 1.0)
				Kit.pauldron(r, A, s, size, AC.Armor, AC.Edge, lv >= 3 and P.Neon or nil, lv >= 5 and 3 or (lv >= 4 and 2 or 1))
			end
			bevel(r, A, V(1.0, 0.9, 1.0), CF(0, 0.15, 0), AC.Armor, AC.Edge)
			bevel(r, A, V(1.15, 0.85, 1.15), CF(0, -0.55, 0), AC.ArmorMid, AC.Edge)
			bevel(r, A, V(1.28, 0.24, 1.28), CF(0, -0.15, 0), AC.Armor, AC.Edge)
			bevel(r, A, V(1.02, 0.42, 1.02), CF(0, -1.12, 0), AC.Armor, AC.Edge)
			if lv >= 3 then -- шипы на локтях
				spike(r, A, V(0.55 * s, -0.5, 0), V(0.95 * s, -0.4, 0.15), 0.32, AC.Armor, M.Metal, true, 0.1)
			end
		end
		-- ноги: бедро, наколенник, голень, латный сапог
		for _, Lg in ipairs({ r.RLeg, r.LLeg }) do
			bevel(r, Lg, V(1.0, 0.95, 1.02), CF(0, 0.45, 0), AC.Armor, AC.Edge)
			if lv >= 2 then
				bevel(r, Lg, V(0.75, 0.45, 0.25), CF(0, 0.0, -0.58), AC.ArmorMid, AC.Edge)
			end
			bevel(r, Lg, V(1.08, 0.7, 1.1), CF(0, -0.38, 0), AC.ArmorMid, AC.Edge)
			Kit.bootA(r, Lg, AC.Armor, AC.Edge, 1.1)
		end
		local tip = voidBlade(r, RA, lv)
		if lv >= 3 then
			r:Sparkles(tip, P.Neon, { Rate = 10, Size = 0.3 })
		end
		if lv >= 4 then -- рваный плащ с эмблемой
			local cape = r:Cape(2.1, 3.5, AC.Cloth, true)
			gem(r, cape, 0.55, CF(0, 0.1, 0.08) * ANG(0, PI, 0), P.NeonSoft)
		end
		return r, { RS = { 20, 0, 0 } }
	end)

	------------------------------------------------------------------------
	-- DARK GUNNER: стрелок в кепи-шлеме с очками и винтовкой
	------------------------------------------------------------------------
	register("DarkGunner", function(lv)
		local r = Parts.figure("DarkGunner", { Torso = rgb(30, 28, 36), Arm = rgb(30, 28, 36), Leg = rgb(26, 24, 30), Edge = rgb(96, 92, 112) })
		local H = r.Head
		bevel(r, H, V(1.3, 0.55, 1.32), CF(0, 0.42, 0.02), AC.ArmorMid, AC.Edge) -- кепи
		bevel(r, H, V(1.32, 0.12, 0.5), CF(0, 0.2, -0.82), AC.ArmorMid, AC.Edge) -- козырёк
		r:Box(H, V(1.2, 0.28, 0.08), CF(0, 0.06, -0.62), rgb(14, 10, 20), M.Plastic) -- ремень очков
		for _, s in ipairs(SIDES) do
			r:Neon(H, V(0.34, 0.18, 0.06), CF(0.27 * s, 0.06, -0.66), VOID)
		end
		r:Box(H, V(1.1, 0.4, 0.08), CF(0, -0.32, -0.62), AC.Armor, M.Metal) -- защита челюсти
		Parts.chest(r, AC.ArmorMid, AC.Edge, lv >= 3 and VOID or nil)
		for _, s in ipairs(SIDES) do -- подсумки
			bevel(r, r.Torso, V(0.42, 0.4, 0.2), CF(0.6 * s, -0.35, -0.6), rgb(50, 40, 36), false, M.Fabric)
		end
		Parts.belt(r, rgb(46, 36, 32), AC.Edge)
		for _, s in ipairs(SIDES) do -- полы плаща
			bevel(r, r.Torso, V(0.95, 1.4, 0.18), CF(0.55 * s, -1.55, 0.45), AC.ClothDark, false, M.Fabric)
		end
		if lv >= 2 then
			Parts.plateShoulders(r, AC.ArmorMid, AC.Edge)
		end
		Parts.bracers(r, AC.ArmorMid, AC.Edge)
		Parts.greaves(r, rgb(40, 36, 46), AC.Edge, true)
		Parts.rifle(r, r.RArm, { Body = lv >= 4 and AC.Cloth or AC.ArmorMid, Edge = AC.Edge, Glow = VOID, Barrel = AC.Armor })
		if lv >= 4 then -- ранец с неоновой полосой
			bevel(r, r.Torso, V(1.4, 1.3, 0.5), CF(0, 0.2, 0.78), AC.ArmorMid, AC.Edge)
			r:Neon(r.Torso, V(0.9, 0.12, 0.06), CF(0, 0.5, 1.04), VOID)
		end
		if lv >= 5 then
			Parts.capeWith(r, 1.8, 2.6, AC.ClothDark, VOID)
		end
		return r, { RS = { 75, 0, 0 }, LS = { 70, 0, -25 }, Neck = { 0, 0, 0 } }
	end)

	------------------------------------------------------------------------
	-- ABYSS REAPER: жнец в маске-черепе с косой
	------------------------------------------------------------------------
	register("AbyssReaper", function(lv)
		local cloth, edge, bone, hole = rgb(26, 20, 32), rgb(80, 70, 96), rgb(200, 190, 175), rgb(10, 8, 14)
		local r = Parts.figure("AbyssReaper", { Torso = cloth, Arm = cloth, Leg = cloth, Skin = bone, Edge = edge })
		Parts.hood(r, cloth, edge, VOID, true)
		r:Box(r.Head, V(0.9, 0.85, 0.06), CF(0, -0.05, -0.63), bone, M.Plastic) -- маска-череп
		for _, s in ipairs(SIDES) do
			r:Box(r.Head, V(0.24, 0.22, 0.04), CF(0.2 * s, 0.07, -0.66), hole)
			r:Neon(r.Head, V(0.1, 0.1, 0.04), CF(0.2 * s, 0.07, -0.68), VOID)
		end
		for k = -1, 1 do -- зубы
			r:Box(r.Head, V(0.08, 0.16, 0.04), CF(k * 0.14, -0.35, -0.66), hole)
		end
		Parts.robe(r, cloth, edge, 2.0)
		Parts.mantle(r, rgb(36, 28, 44), edge)
		Parts.belt(r, rgb(40, 30, 38), AC.Edge, VOID)
		if lv >= 2 then -- костяные наплечники с шипами
			for _, side in ipairs({ 1, -1 }) do
				local A = side == 1 and r.RArm or r.LArm
				bevel(r, A, V(1.25, 0.45, 1.2), CF(0.15 * side, 1.12, 0) * ANG(0, 0, rad(-14 * side)), bone, rgb(120, 110, 100), M.Plastic)
				spike(r, A, V(0.4 * side, 1.3, 0), V(0.8 * side, 1.85, 0), 0.3, bone, M.Plastic, true, 0.1)
			end
		end
		if lv >= 3 then
			Kit.chain(r, r.Torso, 4, 0.26, nil, CF(0.7, -1.0, -0.6))
		end
		Parts.scythe(r, r.RArm, { Blade = lv >= 5 and AC.Cloth or AC.ArmorMid, Glow = lv >= 3 and VOID or nil, Wood = rgb(36, 28, 32) })
		if lv >= 4 then
			Parts.capeWith(r, 2.0, 3.4, cloth, nil)
		end
		if lv >= 5 then
			r:Orbit("OrbitSouls", r.Torso, CF(0, 0.6, 0), 2.3, 4, 0.32, P.NeonSoft, M.Neon, 0.25)
		end
		return r, { RS = { 8, 0, 0 } }
	end)

	------------------------------------------------------------------------
	-- CORRUPTED SAMURAI: кабуто, ламеллярный доспех, катана
	------------------------------------------------------------------------
	register("CorruptedSamurai", function(lv)
		local red, black, gold = rgb(130, 22, 30), rgb(26, 20, 24), rgb(190, 150, 70)
		local edge, glow = rgb(150, 110, 110), rgb(255, 50, 60)
		local r = Parts.figure("CorruptedSamurai", { Torso = black, Arm = black, Leg = black, Edge = edge })
		Parts.kabuto(r, black, edge, lv >= 3 and gold or rgb(150, 120, 80), red)
		for i = 0, 2 do -- до: пластины-ламели
			bevel(r, r.Torso, V(2.14, 0.34, 1.16), CF(0, 0.75 - i * 0.36, 0), i % 2 == 0 and red or black, edge)
		end
		Parts.belt(r, rgb(60, 30, 30), gold)
		for i, x in ipairs({ -0.62, 0, 0.62 }) do -- кусадзури
			for k = 0, 1 do
				bevel(r, r.Torso, V(0.62, 0.36, 0.18), CF(x, -1.2 - k * 0.36, -0.58 - k * 0.04) * ANG(rad(-6), 0, 0), (i + k) % 2 == 0 and red or black, edge)
			end
		end
		for _, side in ipairs({ 1, -1 }) do -- содэ
			local A = side == 1 and r.RArm or r.LArm
			for k = 0, lv >= 2 and 2 or 1 do
				bevel(r, A, V(0.25, 0.38, 1.3), CF(0.62 * side, 0.82 - k * 0.38, 0) * ANG(0, 0, rad(-12 * side)), k % 2 == 0 and red or black, edge)
			end
		end
		Parts.bracers(r, red, edge)
		Parts.greaves(r, black, edge, true)
		Parts.blade(r, r.RArm, {
			Len = 3.4 + (lv >= 4 and 0.4 or 0), W = 0.24, GuardW = 0.55, Blade = rgb(180, 180, 195),
			Glow = lv >= 3 and glow or nil, Guard = gold, Grip = red,
		})
		bevel(r, r.Torso, V(0.2, 0.22, 2.6), CF(-0.9, -0.85, -0.2) * ANG(rad(-20), rad(10), 0), black, edge) -- ножны
		if lv >= 4 then
			Parts.capeWith(r, 1.9, 3.0, red, nil)
		end
		if lv >= 5 then
			Kit.crack(r, r.Torso, { V(-0.8, 0.95, -0.59), V(-0.4, 0.5, -0.59), V(-0.6, 0.1, -0.59) }, 0.06, glow)
		end
		return r, { RS = { 25, 0, 0 }, LS = { 10, 0, 0 } }, glow
	end)

	------------------------------------------------------------------------
	-- ECLIPSE GUARDIAN: золотой страж с копьём-алебардой
	------------------------------------------------------------------------
	register("EclipseGuardian", function(lv)
		local gold, goldD, white, black = rgb(200, 158, 70), rgb(140, 104, 44), rgb(220, 214, 226), rgb(30, 26, 34)
		local edge, warm = rgb(250, 225, 160), rgb(255, 220, 140)
		local r = Parts.figure("EclipseGuardian", { Torso = black, Arm = gold, Leg = black, Edge = edge })
		Parts.helm(r, gold, edge, warm, nil, true)
		for _, s in ipairs(SIDES) do -- крылья на шлеме
			for k = 0, 2 do
				bevel(r, r.Head, V(0.12, 0.7 - k * 0.15, 0.22), CF(0.72 * s, 0.4 + k * 0.25, 0.1 + k * 0.15) * ANG(rad(-30 - k * 10), 0, rad(-20 * s)), gold, edge)
			end
		end
		Parts.chest(r, gold, edge, nil)
		gem(r, r.Torso, 0.55, CF(0, 0.5, -0.62), black, gold) -- эмблема затмения
		r:Neon(r.Torso, V(0.15, 0.15, 0.06), CF(0, 0.5, -0.72) * ANG(0, 0, rad(45)), warm)
		Parts.belt(r, goldD, gold)
		r:Box(r.Torso, V(1.0, 1.5, 0.06), CF(0, -1.6, -0.6), white, M.Fabric) -- табард
		Kit.tatter(r, r.Torso, -2.35, -0.6, 1.0, 3, white, M.Fabric, 4)
		Parts.bigShoulders(r, gold, edge, lv >= 3 and warm or nil, lv >= 4 and 1.15 or 1, lv >= 5 and 2 or 1)
		Parts.bracers(r, goldD, edge)
		Parts.greaves(r, gold, edge, true)
		Parts.spear(r, r.RArm, { Top = 2.8, Head = gold, Metal = goldD, Edge = edge, Glow = lv >= 3 and warm or nil, Axe = lv >= 2, Wing = lv >= 4, Wood = black })
		if lv >= 4 then
			Parts.capeWith(r, 2.1, 3.4, white, gold)
		end
		return r, { RS = { 30, 0, 0 } }, rgb(255, 210, 110)
	end)

	------------------------------------------------------------------------
	-- FALLEN ANGEL: серебряный ангел с крыльями и посохом
	------------------------------------------------------------------------
	register("FallenAngel", function(lv)
		local silver, white, edge = rgb(170, 168, 186), rgb(232, 228, 238), rgb(255, 255, 255)
		local r = Parts.figure("FallenAngel", { Torso = silver, Arm = silver, Leg = rgb(60, 56, 72), Skin = rgb(226, 214, 208), Edge = edge })
		local H = r.Head
		Parts.eyes(r, VOID, true, 0.06)
		-- белые волосы: макушка, затылок, бока и две пряди
		bevel(r, H, V(1.32, 0.35, 1.34), CF(0, 0.62, 0.02), white, false, M.Plastic)
		bevel(r, H, V(1.32, 1.1, 0.3), CF(0, 0.1, 0.55), white, false, M.Plastic)
		for _, s in ipairs(SIDES) do
			bevel(r, H, V(0.18, 1.0, 0.9), CF(0.62 * s, 0.1, 0.2), white, false, M.Plastic)
			spike(r, H, V(0.5 * s, -0.4, 0.5), V(0.6 * s, -1.2, 0.65), 0.35, white, M.Plastic, true, 0.12)
		end
		if lv >= 2 then -- серебряный обруч с самоцветом
			r:Box(H, V(1.36, 0.1, 1.38), CF(0, 0.38, 0.02), silver, M.Metal)
			gem(r, H, 0.18, CF(0, 0.38, -0.72), VOID)
		end
		Parts.chest(r, white, edge, VOID)
		Parts.belt(r, rgb(70, 60, 90), edge, VOID)
		Parts.robe(r, rgb(60, 50, 84), white, 1.6)
		Parts.bigShoulders(r, white, edge, lv >= 3 and VOID or nil, lv >= 4 and 1.1 or 1, 1)
		Parts.bracers(r, white, edge)
		Parts.wings(r, lv >= 5 and rgb(200, 190, 230) or white, edge, lv >= 3 and VOID or nil, 0.9 + lv * 0.06)
		Parts.staff(r, r.RArm, { Glow = VOID, Prong = white, Wood = silver, Top = 2.6, Big = lv >= 4 })
		if lv >= 5 then -- сломанный нимб
			r:Orbit("OrbitHalo", H, CF(0, 1.1, 0.1), 0.85, 6, 0.2, rgb(240, 230, 255))
		end
		return r, { RS = { 10, 0, 0 } }
	end)

	------------------------------------------------------------------------
	-- VOID EMPEROR: император в короне со скипетром
	------------------------------------------------------------------------
	register("VoidEmperor", function(lv)
		local royal, gold, black = rgb(66, 30, 110), rgb(196, 150, 64), rgb(26, 22, 34)
		local edge = rgb(150, 120, 200)
		local r = Parts.figure("VoidEmperor", { Torso = black, Arm = royal, Leg = black, Skin = rgb(54, 48, 64), Edge = edge })
		r:Box(r.Head, V(1.04, 0.9, 0.05), CF(0, -0.05, -0.61), rgb(12, 9, 18), M.Plastic) -- тёмное лицо
		Parts.eyes(r, VOID, true, 0.04)
		Parts.crown(r, gold, VOID, 0.8 + lv * 0.08)
		Parts.chest(r, royal, gold, VOID)
		Parts.belt(r, rgb(50, 36, 30), gold, VOID)
		Parts.robe(r, royal, gold, 1.9)
		Parts.bigShoulders(r, black, gold, VOID, 1.1 + (lv >= 4 and 0.1 or 0), lv >= 3 and 2 or 1)
		Parts.bracers(r, black, gold)
		if lv >= 2 then -- золотые манжеты
			for _, A in ipairs({ r.RArm, r.LArm }) do
				r:Box(A, V(1.2, 0.14, 1.2), CF(0, -0.88, 0), gold, M.Metal)
			end
		end
		Parts.capeWith(r, 2.4, 4.0, royal, gold)
		Parts.staff(r, r.RArm, { Glow = VOID, Prong = gold, Wood = gold, Top = 2.6, Big = true }) -- скипетр
		if lv >= 4 then
			r:Orbit("OrbitCrown", r.Head, CF(0, 1.5, 0), 1.4, 5, 0.26, P.NeonSoft)
		end
		return r, { RS = { 15, 0, 0 } }
	end)

	------------------------------------------------------------------------
	-- ABYSS OVERLORD: рогатый владыка с двуручным мечом
	------------------------------------------------------------------------
	register("AbyssOverlord", function(lv)
		local black, mid, edge = rgb(26, 22, 32), rgb(44, 38, 56), rgb(130, 110, 160)
		local r = Parts.figure("AbyssOverlord", { Torso = black, Arm = black, Leg = black, Edge = edge })
		Parts.helm(r, black, edge, VOID, nil, true)
		if lv >= 2 then -- самоцвет над визором
			gem(r, r.Head, 0.2, CF(0, 0.48, -0.7), VOID, edge)
		end
		for _, s in ipairs(SIDES) do
			Kit.hornA(r, r.Head, { V(0.62 * s, 0.35, 0), V(1.1 * s, 0.6, 0.05), V(1.3 * s, 1.2, 0), V(1.1 * s, 1.9 + lv * 0.1, -0.15) }, 0.3, mid, M.Metal)
		end
		Parts.chest(r, mid, edge, VOID)
		Kit.crack(r, r.Torso, { V(-0.85, 0.95, -0.59), V(-0.45, 0.45, -0.6), V(-0.7, -0.05, -0.59) }, 0.06)
		Kit.crack(r, r.Torso, { V(0.7, 0.9, -0.59), V(0.85, 0.35, -0.59) }, 0.05)
		Parts.belt(r, black, edge, VOID)
		Parts.tassets(r, mid, edge)
		Parts.bigShoulders(r, black, edge, VOID, 1.2 + (lv >= 4 and 0.1 or 0), lv >= 3 and 3 or 2)
		Parts.bracers(r, mid, edge)
		Parts.greaves(r, mid, edge, true)
		Parts.blade(r, r.RArm, {
			Len = 4.2 + lv * 0.15, W = 0.85, GuardW = 1.8, Blade = black, Glow = VOID,
			Core = lv >= 3 and P.NeonSoft or nil, Guard = mid, Edge = edge,
		})
		Parts.capeWith(r, 2.3, 3.6, rgb(40, 18, 64), VOID)
		if lv >= 4 then
			r:Orbit("OrbitRocks", r.Torso, CF(0, 0.3, 0), 3.0, lv >= 5 and 6 or 4, 0.5, mid, M.Slate)
		end
		return r, { RS = { 12, 0, 8 }, LS = { 12, 0, -8 } }
	end)
end
