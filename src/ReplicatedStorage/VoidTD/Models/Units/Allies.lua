--!nocheck
-- VOID TD :: Models/Units/Allies
-- Союзники-призывы (Config.Allies, 16 шт.): лёгкие R6-фигуры трёх семейств, ходят толпой по дорожке.
--   Illusion — тёмно-фиолетовые иллюзии (тень, карточный солдат, зеркальный рыцарь, маг, королевская иллюзия);
--   Puppet   — шарнирные куклы на нитях кукловода (дерево, фарфор, железо ... золотая марионетка);
--   Cursed   — проклятые люди с красными глазами (оборванец, теневой солдат, страж, багровый воин, рыцарь).
-- Регистрирует UnitModels.RegisterAlly(family, builder(allyId, tier, def) -> r, glowColor). Rig отдаётся БЕЗ Finish:
-- масштаб по ярусу, чистку частиц/шлейфов/света, одну подсветку glow, Calm и флаги деталей делает
-- UnitModels.BuildAlly (строит с Kit.Cheap = true: фаска из 2 деталей, плоские шипы). Позы нет — прямая стойка R6.

return function(UnitModels, Kit, Parts)
	local V, CF, ANG, rad = Vector3.new, CFrame.new, CFrame.Angles, math.rad
	local M, HW, rgb = Parts.M, Parts.HW, Parts.rgb
	local bevel, spike = Kit.bevel, Kit.spike
	local figure, eyes, shaft, blade = Parts.figure, Parts.eyes, Parts.shaft, Parts.blade

	local CHEST = V(2.14, 1.1, 1.16) -- нагрудник поверх торса
	local CHEST_AT = CF(0, 0.45, 0)
	local PORCELAIN = rgb(236, 230, 236)

	-- Ярус 1..5 (ярусы выше 5 — особые, их строитель обрабатывает отдельно)
	local function tierOf(tier)
		return math.clamp(math.floor(tonumber(tier) or 1), 1, 5)
	end

	-- Простой брусок без фаски (прозрачность — необязательно)
	local function plain(r, limb, size, cf, color, mat, transparency)
		return r:Box(limb, size, cf, color, mat or M.Plastic, transparency and { Transparency = transparency } or nil)
	end

	------------------------------------------------------------------------
	-- ИЛЛЮЗИИ: тёмно-фиолетовые, стекло, карты и зеркала
	------------------------------------------------------------------------
	local ILL_EDGE = rgb(170, 120, 230)
	local ILL_GLASS = rgb(150, 100, 220)
	local MIRROR = rgb(200, 190, 230)

	local function Illusion(id, tier)
		tier = tierOf(tier)
		local shade = tier == 1
		local body = shade and rgb(16, 10, 24) or rgb(40, 22, 64)
		local edge, glow = ILL_EDGE, HW.Violet
		local r = figure(id, { Torso = body, Arm = body, Leg = body, Skin = shade and body or rgb(70, 40, 100), Edge = edge })
		eyes(r, glow, true, 0.08)
		if tier == 1 then
			-- ShadowDouble: чёрный силуэт в стеклянной дымке, капюшон
			for _, L in ipairs({ r.Torso, r.RArm, r.LArm, r.RLeg, r.LLeg }) do
				plain(r, L, L.Size + V(0.06, 0.06, 0.06), CF(), ILL_GLASS, M.Glass, 0.7)
			end
			Parts.hood(r, body, edge, glow, true)
		elseif tier == 2 then
			-- CardSoldier: тело-карта с бубнами, красная шапка с золотыми шипами, копьё-пика
			plain(r, r.Torso, V(2.0, 2.6, 0.12), CF(0, -0.2, -0.58), rgb(236, 232, 240))
			plain(r, r.Torso, V(1.7, 2.3, 0.13), CF(0, -0.2, -0.58), HW.Red, nil, 0.85)
			for _, y in ipairs({ 0.6, -1.0 }) do
				plain(r, r.Torso, V(0.4, 0.4, 0.14), CF(0, y, -0.6) * ANG(0, 0, rad(45)), HW.Red)
			end
			bevel(r, r.Head, V(1.3, 0.3, 1.3), CF(0, 0.65, 0), HW.Red, false)
			for k = -1, 1 do
				spike(r, r.Head, V(k * 0.4, 0.75, 0), V(k * 0.4, 1.15, 0), 0.3, HW.Gold, M.Metal, true, 0.08)
			end
			local top = shaft(r, r.RArm, -2.2, 2.0, HW.Black, 0.16)
			spike(r, r.RArm, top, top + V(0, 0.8, 0), 0.5, HW.Red, M.Plastic, true, 0.1)
		elseif tier == 3 then
			-- MirrorKnight: блестящий шлем и кираса, зеркальный щит со стеклом, клинок
			local steel = rgb(170, 160, 200)
			Parts.helm(r, steel, edge, glow, nil, false)
			bevel(r, r.Torso, CHEST, CHEST_AT, steel, edge, M.Foil)
			Parts.plateShoulders(r, steel, edge)
			bevel(r, r.LArm, V(0.2, 2.0, 1.4), CF(-0.65, -0.6, -0.1), MIRROR, glow, M.Foil)
			plain(r, r.LArm, V(0.22, 1.6, 1.0), CF(-0.66, -0.6, -0.1), ILL_GLASS, M.Glass, 0.4)
			blade(r, r.RArm, { Len = 2.2, W = 0.4, Blade = MIRROR, Guard = body, Glow = glow })
		elseif tier == 4 then
			-- PhantomMage: капюшон, мантия, посох со светящимся ромбом в стеклянной оболочке
			Parts.hood(r, rgb(60, 30, 96), edge, glow, true)
			Parts.robe(r, rgb(46, 24, 76), edge, 1.7)
			local top = shaft(r, r.RArm, -2.4, 1.9, HW.Black, 0.16)
			local orb = CF(top + V(0, 0.35, 0)) * ANG(rad(45), 0, rad(45))
			r:Neon(r.RArm, V(0.5, 0.5, 0.5), orb, glow)
			plain(r, r.RArm, V(0.75, 0.75, 0.75), orb, ILL_GLASS, M.Glass, 0.6)
		else
			-- RoyalIllusion: четырёхгранная корона, кираса с золотым кантом, плащ, два клинка
			local royal = rgb(90, 50, 140)
			Parts.kingCrown(r, r.Head, CF(0, 0.6, 0), 0.66, 0.6, rgb(200, 170, 240), glow, 4)
			bevel(r, r.Torso, CHEST, CHEST_AT, royal, HW.Gold, M.Foil)
			Parts.plateShoulders(r, royal, HW.Gold)
			r:Cape(1.9, 2.6, rgb(60, 30, 96), false)
			blade(r, r.RArm, { Len = 2.4, W = 0.45, Blade = MIRROR, Guard = HW.Gold, Glow = glow })
			blade(r, r.LArm, { Len = 2.0, W = 0.4, Blade = MIRROR, Guard = HW.Gold, Glow = glow, Secondary = true })
		end
		return r, glow
	end

	------------------------------------------------------------------------
	-- КУКЛЫ: шарнирные, нити кукловода над головой и руками
	------------------------------------------------------------------------
	local JOINT_DARK = rgb(60, 50, 56)
	local DOLL_ARMOR = rgb(60, 40, 50)
	-- по ярусам 1..5: дерево, кант, голова, шарниры, броня
	local PUPPET = {
		{ Wood = HW.WoodLight, Edge = HW.Wood, Skin = PORCELAIN, Joint = HW.Wood },
		{ Wood = PORCELAIN, Edge = rgb(190, 180, 196), Skin = PORCELAIN, Joint = JOINT_DARK },
		{ Wood = HW.Iron, Edge = HW.Edge, Joint = JOINT_DARK, Armor = HW.Iron },
		{ Wood = rgb(40, 30, 36), Edge = rgb(130, 70, 80), Joint = JOINT_DARK, Armor = DOLL_ARMOR },
		{ Wood = rgb(90, 40, 60), Edge = HW.Gold, Joint = JOINT_DARK, Armor = DOLL_ARMOR },
	}
	-- особая золотая марионетка (ярус > 5)
	local GOLDEN = { Wood = HW.Gold, Edge = rgb(255, 230, 150), Joint = HW.GoldDark, Armor = HW.Gold, ArmorMat = M.Foil }
	local DOLL_JOINTS = { V(1.0, 0.7, 0), V(-1.0, 0.7, 0), V(0.5, -1.0, 0), V(-0.5, -1.0, 0), V(0, 1.0, 0) }

	local function Puppet(id, tier)
		local golden = id == "GoldenMarionette" or (tonumber(tier) or 1) > 5
		local t = golden and 6 or tierOf(tier)
		local st = golden and GOLDEN or PUPPET[t]
		local wood, edge = st.Wood, st.Edge
		local hot = golden and HW.Orange or HW.Red -- зрачки, свечение клинка, камни короны
		local r = figure(id, { Torso = wood, Arm = wood, Leg = wood, Skin = st.Skin or wood, Edge = edge })
		local T, Hd = r.Torso, r.Head
		-- лицо-маска: глаза-пуговицы со светящимися зрачками, рот-шов
		for _, s in ipairs({ -1, 1 }) do
			plain(r, Hd, V(0.24, 0.24, 0.05), CF(0.26 * s, 0.1, -0.62) * ANG(0, 0, rad(45)), HW.Black)
			r:Neon(Hd, V(0.08, 0.08, 0.04), CF(0.26 * s, 0.1, -0.65), hot)
		end
		if golden then
			plain(r, Hd, V(0.5, 0.05, 0.04), CF(0, -0.3, -0.62), HW.GoldDark, M.Metal)
		else
			r:Neon(Hd, V(0.5, 0.05, 0.04), CF(0, -0.3, -0.62), HW.Red)
		end
		-- шарниры: плечи, бёдра, шея + кольца-стыки на конечностях
		for _, p in ipairs(DOLL_JOINTS) do
			plain(r, T, V(0.45, 0.45, 0.45), CF(p) * ANG(rad(45), 0, rad(45)), st.Joint, M.Metal)
		end
		for _, L in ipairs({ r.RArm, r.LArm, r.RLeg, r.LLeg }) do
			plain(r, L, V(1.06, 0.12, 1.06), CF(), st.Joint, M.Metal)
		end
		if t == 2 then
			-- PorcelainDoll: платье, трещина на лице, тёмные волосы
			bevel(r, T, V(2.3, 1.4, 1.3), CF(0, -1.1, 0), rgb(110, 30, 60), false, M.Fabric)
			Kit.crack(r, Hd, { V(0.2, 0.5, -0.62), V(0.35, 0.2, -0.62), V(0.25, -0.05, -0.62) }, 0.04, rgb(60, 50, 60))
			bevel(r, Hd, V(1.3, 0.35, 1.3), CF(0, 0.55, 0.05), rgb(60, 30, 20), false, M.Fabric)
		elseif t >= 3 then
			-- броня: железо (3), тёмная (4–5), золотая фольга (золотая марионетка)
			bevel(r, T, CHEST, CHEST_AT, st.Armor, edge, st.ArmorMat or M.Metal)
			Parts.plateShoulders(r, st.Armor, edge)
		end
		if t >= 4 then
			blade(r, r.RArm, { Len = t >= 5 and 2.6 or 2.2, W = 0.45, Blade = golden and HW.Gold or HW.Iron, Guard = edge, Glow = hot })
		elseif t == 3 then
			Parts.shield(r, r.LArm, { Color = HW.Iron, Edge = edge, H = 1.6, W = 1.1 })
		end
		if t >= 5 then -- корона и плащ
			Parts.kingCrown(r, Hd, CF(0, 0.6, 0), 0.66, 0.55, HW.Gold, hot, 4)
			r:Cape(1.8, 2.4, golden and HW.Gold or HW.Burgundy, false)
		end
		-- нити кукловода
		local threadC = golden and rgb(255, 210, 120) or HW.Red
		Parts.thread(r, Hd, V(0, 0.6, 0), V(0, 3.2, 0), threadC, 0.04)
		for _, A in ipairs({ r.RArm, r.LArm }) do
			Parts.thread(r, A, V(0, 1, 0), V(0, 3.4, 0), threadC, 0.035)
		end
		return r, threadC
	end

	------------------------------------------------------------------------
	-- ПРОКЛЯТЫЕ ЛЮДИ: красно-чёрные, светящиеся красные глаза
	------------------------------------------------------------------------
	local CURSED_CLOTH = { rgb(70, 54, 50), rgb(30, 24, 30), rgb(40, 36, 44), rgb(110, 24, 36), rgb(24, 18, 22) }
	local CURSED_EDGE = rgb(140, 70, 70)

	local function Cursed(id, tier)
		tier = tierOf(tier)
		local cloth = CURSED_CLOTH[tier]
		local edge, glow = CURSED_EDGE, HW.Red
		local r = figure(id, { Torso = cloth, Arm = tier == 1 and rgb(150, 140, 142) or cloth, Leg = rgb(30, 24, 28), Skin = rgb(160, 150, 150), Edge = edge })
		local T = r.Torso
		eyes(r, glow, true, 0.08)
		if tier == 1 then
			-- CursedPerson: рваная рубаха, бледные руки, красные трещины на груди и лице
			Kit.tatter(r, T, -1.0, -0.56, 2.0, 4, cloth, M.Fabric, 1)
			Kit.crack(r, T, { V(-0.4, 0.6, -0.52), V(-0.1, 0.2, -0.52), V(-0.3, -0.3, -0.52) }, 0.06, glow)
			Kit.crack(r, r.Head, { V(0.3, 0.5, -0.61), V(0.15, 0.25, -0.61) }, 0.05, glow)
		elseif tier == 2 then
			-- ShadowSoldier: капюшон без хвоста, нагрудник, чёрное копьё с железным наконечником
			Parts.hood(r, cloth, edge, glow, false)
			bevel(r, T, CHEST, CHEST_AT, rgb(50, 40, 50), edge)
			local top = shaft(r, r.RArm, -2.4, 2.2, HW.Black, 0.16)
			spike(r, r.RArm, top, top + V(0, 0.9, 0), 0.4, HW.Iron, M.Metal)
		elseif tier == 3 then
			-- CursedGuard: шлем, нагрудник, наплечники, щит с красным камнем, короткий клинок
			local plate = rgb(60, 50, 60)
			Parts.helm(r, plate, edge, glow, nil, false)
			bevel(r, T, CHEST, CHEST_AT, plate, edge)
			Parts.plateShoulders(r, plate, edge)
			Parts.shield(r, r.LArm, { Color = rgb(60, 20, 30), Edge = edge, H = 1.8, W = 1.2, Gem = glow })
			blade(r, r.RArm, { Len = 1.8, W = 0.4, Blade = HW.Iron, Guard = plate })
		elseif tier == 4 then
			-- CrimsonWarrior: багровая шапка-шлем, нагрудник, наплечники, топор с красной кромкой
			local crimson = rgb(130, 30, 44)
			bevel(r, r.Head, V(1.32, 0.5, 1.34), CF(0, 0.45, 0), crimson, edge)
			bevel(r, T, CHEST, CHEST_AT, crimson, edge)
			Parts.plateShoulders(r, crimson, edge)
			Parts.axe(r, r.RArm, { Head = HW.Iron, Edge = edge, Glow = glow, Wood = HW.Black })
		else
			-- CursedKnight: высокий шлем с красным визором и гребнем, ступенчатые наплечники, плащ, клинок
			local plate = rgb(30, 22, 26)
			Parts.helm(r, plate, edge, glow, rgb(130, 30, 44), true)
			bevel(r, T, CHEST, CHEST_AT, plate, edge)
			Parts.bigShoulders(r, plate, edge, glow, 0.9, 1)
			r:Cape(1.8, 2.6, rgb(90, 18, 30), false)
			blade(r, r.RArm, { Len = 2.6, W = 0.5, Blade = rgb(40, 34, 40), Guard = plate, Glow = glow })
		end
		return r, glow
	end

	UnitModels.RegisterAlly("Illusion", Illusion)
	UnitModels.RegisterAlly("Puppet", Puppet)
	UnitModels.RegisterAlly("Cursed", Cursed)
end
