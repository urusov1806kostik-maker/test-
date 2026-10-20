--!nocheck
-- VOID TD :: Models/Units/Clockmaker
-- CURSED CLOCKMAKER (Secret, Halloween): голова — старинные механические часы, стрелки и шестерни
-- на моторах Clock*/Gear* (r.SpinRates: мотор -> рад/с, крутятся по Z в Anims.Apply, быстрее в бурю),
-- оружие — Хроносекира (неоновые кромки с атрибутом AxeGlow), шестерни бури OrbitStormGears
-- (атрибут StormFX: скрыты до «Временной бури»).

return function(UnitModels, Kit, Parts)
	local V = Vector3.new
	local V2 = Vector2.new
	local CF = CFrame.new
	local ANG = CFrame.Angles
	local rad = math.rad
	local PI = math.pi

	local M, rgb = Parts.M, Parts.rgb
	local CLK = Parts.CLK
	local bevel, spike, gem, bar = Kit.bevel, Kit.spike, Kit.gem, Kit.bar
	local gear = Parts.gear
	local SIDES = { -1, 1 }
	local AXE_RADIUS = { 0.95, 1.15, 1.15, 1.3, 1.45 }

	-- Хроносекира: тёмная рукоять с бронзовыми кольцами, два полукруглых зубчатых лезвия,
	-- вращающаяся центральная шестерня и две малые
	local function chronoaxe(r, A, lv)
		local z = -0.5
		local bottom, top = -2.5, 2.3
		r:Box(A, V(0.22, top - bottom, 0.22), CF(0, (top + bottom) / 2, z), CLK.Steel, M.Metal)
		for _, y in ipairs({ -1.6, -0.2, 1.2 }) do
			bevel(r, A, V(0.34, 0.16, 0.34), CF(0, y, z), CLK.Bronze, false)
		end
		spike(r, A, V(0, bottom + 0.05, z), V(0, bottom - 0.5, z), 0.3, CLK.Bronze, M.Metal)
		local c = V(0, top + 0.2, z)
		local R = AXE_RADIUS[lv]
		local blade = lv >= 5 and CLK.Black or CLK.Steel
		local rimColor = lv >= 4 and CLK.Orange or CLK.OrangeDim
		for _, side in ipairs(SIDES) do
			local prev
			for k = 0, 6 do
				local phi = rad(-78 + k * 26)
				local dir = V(0, math.sin(phi), side * math.cos(phi))
				bar(r, A, c + dir * 0.3, c + dir * R, V2(0.1, 2 * R * math.sin(rad(13)) + 0.1), blade, M.Metal)
				spike(r, A, c + dir * (R - 0.02), c + dir * (R + 0.22), 0.2, CLK.Gold, M.Metal, true, 0.1)
				local rim = c + dir * (R * 0.9)
				if prev then -- неоновая кромка (в бурю Renderer перекрашивает по AxeGlow)
					bar(r, A, prev, rim, V2(0.12, 0.07), rimColor, M.Neon):SetAttribute("AxeGlow", true)
				end
				prev = rim
			end
			bevel(r, A, V(0.14, 0.5, 0.35), CF(c + V(0, 0, side * 0.42)), CLK.Bronze, false) -- накладка у основания
		end
		local _, hub = gear(r, A, "GearAxe", CF(c) * ANG(0, PI / 2, 0), 0.38, 0.16, lv >= 3 and CLK.Gold or CLK.Bronze, CLK.Orange, 2.2)
		hub:SetAttribute("AxeGlow", true)
		gear(r, A, "GearAxeS1", CF(c + V(0, 0.5, -0.3)) * ANG(0, PI / 2, 0), 0.15, 0.12, CLK.Bronze, CLK.Black, -3.5)
		gear(r, A, "GearAxeS2", CF(c + V(0, -0.5, 0.3)) * ANG(0, PI / 2, 0), 0.15, 0.12, CLK.Bronze, CLK.Black, 3.5)
		r:Sparkles(hub, CLK.Orange, { Rate = lv >= 4 and 8 or 4, Size = 0.18 })
		r:WeaponTrail(A, c + V(0, 0, -0.4), c + V(0, 0, -R), CLK.Orange)
		return Parts.muzzle(r, A, CF(c))
	end

	local function goldRingGap(k)
		return k % 4 == 3
	end

	UnitModels.Register("CursedClockmaker", function(lv)
		local edge = CLK.GoldDark
		local r = Kit.Rig.new({ Name = "CursedClockmaker", HeadSize = V(1.2, 1.2, 1.2), Torso = CLK.Black, Arm = CLK.Black, Leg = CLK.Black, Head = CLK.Black })
		r.SpinRates = {}
		local T, H, RA, LA, RL, LL = r.Torso, r.Head, r.RArm, r.LArm, r.RLeg, r.LLeg
		for _, L in ipairs({ T, H, RA, LA, RL, LL }) do
			L.Transparency = 1
		end
		local gearColor = lv >= 3 and CLK.Gold or (lv >= 2 and CLK.Silver or CLK.Bronze)
		local frame = lv >= 3 and CLK.Gold or CLK.Bronze

		-- R6-тело: чёрный костюм с золотым кантом
		bevel(r, T, V(2, 2, 1), CF(), CLK.Black, edge)
		for _, L in ipairs({ RA, LA, RL, LL }) do
			bevel(r, L, V(1, 2, 1), CF(), CLK.Black, edge)
		end
		-- жилет, лацканы, пуговицы, брошь
		bevel(r, T, V(1.5, 1.7, 1.08), CF(0, 0.1, 0), CLK.Suit, edge, M.Fabric)
		for _, s in ipairs(SIDES) do
			bar(r, T, V(0.25 * s, 0.98, -0.56), V(0.62 * s, -0.4, -0.56), V2(0.12, 0.05), CLK.Gold, M.Metal)
		end
		for k = 0, 2 do
			r:Box(T, V(0.12, 0.12, 0.06), CF(0, 0.45 - k * 0.38, -0.57) * ANG(0, 0, PI / 4), CLK.Gold, M.Metal)
		end
		gem(r, T, 0.26, CF(0, 0.82, -0.6), CLK.Orange, CLK.Gold)
		-- золотая цепочка и карманные часы
		bar(r, T, V(0, 0.07, -0.58), V(-0.45, -0.3, -0.58), V2(0.06, 0.06), CLK.Gold, M.Metal)
		bar(r, T, V(-0.45, -0.3, -0.58), V(-0.75, -0.05, -0.58), V2(0.06, 0.06), CLK.Gold, M.Metal)
		Parts.miniClock(r, T, CF(-0.78, -0.25, -0.58), 0.18)
		-- пояс с пряжкой-шестерёнкой (неподвижной)
		bevel(r, T, V(2.1, 0.3, 1.12), CF(0, -0.82, 0), CLK.Black, edge)
		gear(r, T, nil, CF(0, -0.82, -0.6), 0.16, 0.08, CLK.Gold, CLK.Orange)
		-- полы длинного сюртука
		for _, s in ipairs(SIDES) do
			bevel(r, T, V(0.95, 1.6, 0.16), CF(0.52 * s, -1.75, 0.46), CLK.Suit, edge, M.Fabric)
		end
		Kit.tatter(r, T, -2.55, 0.46, 2.0, 4, CLK.Suit, M.Fabric, 5)

		-- ГОЛОВА-ЧАСЫ: рама, циферблат, стрелки ClockHour/ClockMinute
		local a = lv >= 5 and 1.0 or 0.92
		local headCF = CF(0, 0.35, 0)
		Parts.clockFace(r, H, headCF, a, frame, "Clock", CLK.Gold, lv >= 4)
		gear(r, H, "GearHeadA", headCF * CF(0, -a * 0.38, -0.29), a * 0.16, 0.04, CLK.Orange, CLK.Dial, 3, M.Neon)
		for _, s in ipairs(SIDES) do
			gear(r, H, s == 1 and "GearHeadR" or "GearHeadL", headCF * CF(a * 0.98 * s, a * 0.45, 0), a * 0.24, 0.2, gearColor, CLK.Orange, 1.4 * s)
		end
		-- заводная головка сверху
		bevel(r, H, V(0.3, 0.3, 0.3), headCF * CF(0, a + 0.1, 0), frame, false)
		bevel(r, H, V(0.44, 0.12, 0.44), headCF * CF(0, a + 0.3, 0), frame, false)

		-- НАПЛЕЧНИКИ: с 3 ур. ступенчатые с оранжевым самоцветом, иначе стальные пластины с шестернями
		if lv >= 3 then
			local size, spikes = lv >= 5 and 1.2 or 1.05, lv >= 5 and 2 or 1
			Kit.pauldron(r, RA, 1, size, CLK.Black, CLK.Gold, CLK.Orange, spikes)
			Kit.pauldron(r, LA, -1, size, CLK.Black, CLK.Gold, CLK.Orange, spikes)
		else
			for _, side in ipairs({ 1, -1 }) do
				local A = side == 1 and RA or LA
				bevel(r, A, V(1.3, 0.45, 1.25) * (lv >= 2 and 1.1 or 1), CF(0.12 * side, 0.9, 0) * ANG(0, 0, rad(-12 * side)), CLK.Steel, lv >= 2 and CLK.Silver or CLK.Bronze)
				gear(r, A, nil, CF(0.62 * side, 0.85, 0) * ANG(0, PI / 2, 0), 0.2, 0.08, gearColor, CLK.Black)
			end
		end
		-- рукава: золотые манжеты, перчатки, с 2 ур. стальной наруч
		for _, A in ipairs({ RA, LA }) do
			bevel(r, A, V(1.16, 0.3, 1.16), CF(0, -0.55, 0), CLK.Gold, false)
			bevel(r, A, V(1.04, 0.42, 1.04), CF(0, -0.82, 0), lv >= 2 and CLK.Steel or CLK.Bronze, edge)
			if lv >= 2 then
				bevel(r, A, V(1.12, 0.5, 1.12), CF(0, -0.2, 0), CLK.Steel, CLK.Silver)
			end
		end
		-- ноги: наколенники (с 2 ур.), сапоги с золотым кантом
		for _, Lg in ipairs({ RL, LL }) do
			if lv >= 2 then
				bevel(r, Lg, V(0.8, 0.45, 0.26), CF(0, 0.0, -0.58), CLK.Steel, CLK.Silver)
			end
			Kit.bootA(r, Lg, CLK.Black, CLK.Gold, 1.12)
		end

		-- МЕХАНИЗМ НА СПИНЕ
		gear(r, T, "GearBack", CF(0, 0.3, 0.7), 0.7, 0.2, gearColor, CLK.Orange, 0.8)
		if lv >= 3 then
			gear(r, T, "GearBack2", CF(0.75, -0.35, 0.82), 0.42, 0.18, CLK.Bronze, CLK.Black, -1.4)
			gear(r, T, "GearBack3", CF(-0.7, -0.45, 0.82), 0.32, 0.18, CLK.Bronze, CLK.Black, 1.9)
			for _, s in ipairs(SIDES) do
				r:Box(T, V(0.14, 1.4, 0.14), CF(0.55 * s, 0.4, 0.66), CLK.Bronze, M.Metal)
			end
		end
		-- ПЛАЩ (роскошный с 4 ур.)
		local cape = r:Cape(lv >= 4 and 2.3 or 2.0, lv >= 4 and 4.2 or 3.6, lv >= 4 and rgb(26, 16, 30) or CLK.Black, true)
		if lv >= 4 then
			gem(r, cape, 0.5, CF(0, 0.1, 0.08) * ANG(0, PI, 0), CLK.Orange, CLK.Gold)
			r:Box(cape, V(2.34, 0.1, 0.14), CF(0, 0.9, 0), CLK.Gold, M.Metal)
		end
		-- ОГРОМНЫЕ ЧАСЫ ЗА СПИНОЙ (MAX): стрелки ClockBigHour/ClockBigMinute
		if lv >= 5 then
			Parts.clockFace(r, T, CF(0, 1.5, 1.15), 1.9, CLK.Gold, "ClockBig", CLK.Gold, true)
		end
		-- парящие золотые часы
		local orb = r:Orbit("OrbitClocks", T, CF(0, 0.5, 0), 2.6, 0, 0.2, CLK.Gold)
		local n = lv >= 5 and 5 or (lv >= 3 and 4 or 3)
		for i = 0, n - 1 do
			local ang = i / n * PI * 2
			Parts.miniClock(r, orb, CF(math.cos(ang) * 2.6, math.sin(ang * 2) * 0.4, math.sin(ang) * 2.6) * ANG(0, -ang + PI / 2, 0), 0.3)
		end
		-- вращающееся золотое кольцо (с 4 ур.)
		if lv >= 4 then
			local ringHub = r:Orbit("OrbitGoldRing", T, CF(0, -0.2, 0), 2.1, 0, 0.2, CLK.Gold)
			Kit.ring(r, ringHub, ANG(rad(90), 0, 0), 2.1, 16, 0.08, 0.14, CLK.Gold, M.Metal, goldRingGap)
		end
		-- шестерни бури: видны только во время «Временной бури» (явная пометка StormFX по метке)
		local storm = r:Orbit("OrbitStormGears", T, CF(0, 0.2, 0), 3.2, 0, 0.2, CLK.Gold)
		local mark = r:Mark()
		for i = 0, 5 do
			local ang = i / 6 * PI * 2
			gear(r, storm, nil, CF(math.cos(ang) * 3.2, math.sin(ang * 3) * 0.5, math.sin(ang) * 3.2) * ANG(0, -ang, 0), 0.3, 0.1, CLK.Gold, CLK.Orange)
		end
		Parts.stormFX(r:Since(mark))

		-- ХРОНОСЕКИРА в правой руке
		chronoaxe(r, RA, lv)
		Parts.levelAura(r, lv, CLK.Orange)
		return r:Finish(UnitModels.Scale("CursedClockmaker"), { RS = { 20, 0, 0 }, LS = { 10, 0, -5 } })
	end)
end
