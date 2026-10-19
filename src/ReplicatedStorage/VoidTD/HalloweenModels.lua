--!nocheck
-- VOID TD :: HalloweenModels
-- Хэллоуинские юниты (R6 в угловатом стиле), союзники-призывы и 3D-иконки рун.
-- Подключается из UnitModels: require(HalloweenModels)(UnitModels).
--   UnitModels.Register(id, builder, rarity) — 11 юнитов события
--   UnitModels.BuildAlly(allyId) -> rig   (R6 с моторами RS/LS/RH/LH/Neck/Root для ходьбы)
--   UnitModels.BuildRune(runeId) -> { Model, Core }   (заякоренные детали, центр в начале координат)

local Config = require(script.Parent.Config)

return function(UnitModels)
	local H = UnitModels.H
	local Kit = UnitModels.Kit
	local M = H.M
	local rgb = H.rgb
	local GRIP, AIM = H.GRIP, H.AIM
	local figure, eyes, belt, robe, mantle = H.figure, H.eyes, H.belt, H.robe, H.mantle
	local muzzle, shaft, levelAura, capeWith = H.muzzle, H.shaft, H.levelAura, H.capeWith

	local V = Vector3.new
	local V2 = Vector2.new
	local CF = CFrame.new
	local ANG = CFrame.Angles
	local rad = math.rad
	local PI = math.pi

	local function lite()
		return UnitModels.Lite
	end

	-- Палитра Хэллоуина: чёрный, тёмно-фиолетовый, оранжевый, бордовый, золото
	local HW = {
		Black = rgb(18, 14, 22),
		Coal = rgb(32, 26, 38),
		Night = rgb(26, 22, 40),
		Purple = rgb(58, 30, 86),
		PurpleDeep = rgb(36, 18, 54),
		Violet = rgb(150, 70, 230),
		Orange = rgb(255, 130, 30),
		OrangeDim = rgb(170, 78, 22),
		Pumpkin = rgb(214, 104, 28),
		PumpkinDark = rgb(150, 66, 18),
		Burgundy = rgb(98, 22, 38),
		BurgDark = rgb(58, 14, 24),
		Gold = rgb(214, 168, 70),
		GoldDark = rgb(146, 108, 46),
		Edge = rgb(150, 124, 96),
		EdgeCool = rgb(120, 112, 140),
		Bone = rgb(222, 212, 192),
		Straw = rgb(206, 166, 82),
		StrawDark = rgb(150, 112, 52),
		Burlap = rgb(150, 118, 78),
		Wood = rgb(74, 48, 30),
		WoodLight = rgb(120, 82, 50),
		Leather = rgb(62, 40, 30),
		Iron = rgb(70, 68, 78),
		Green = rgb(120, 255, 110),
		GreenDim = rgb(60, 140, 60),
		Ghost = rgb(110, 190, 255),
		GhostDeep = rgb(40, 80, 150),
		Red = rgb(235, 30, 50),
		Pale = rgb(196, 190, 200),
		Flame = rgb(255, 190, 80),
	}

	------------------------------------------------------------------------
	-- ДЕТАЛИ
	------------------------------------------------------------------------
	-- Треугольник в плоскости XY узла cf (виден спереди), вершина вверх
	local function tri(r, limb, cf, w, h, color, mat, depth)
		local F = cf * ANG(0, PI / 2, 0)
		local d = depth or 0.05
		local a = r:Wedge(limb, V(d, h, w / 2), F * CF(0, 0, -w / 4), color, mat or M.Neon)
		local b = r:Wedge(limb, V(d, h, w / 2), F * CF(0, 0, w / 4) * ANG(0, PI, 0), color, mat or M.Neon)
		return { a, b }
	end

	-- Спрятать базовый куб головы, который добавляет figure()
	local function hideHeadBox(r)
		for _, d in ipairs(r.Model:GetChildren()) do
			if d.Name == "Detail" and d.Size == V(1.2, 1.2, 1.2) then
				local w = d:FindFirstChildOfClass("Weld")
				if w and w.Part0 == r.Head then
					d.Transparency = 1
				end
			end
		end
	end

	-- Взгляд «вниз по миру» в координатах руки при позе idle (для нитей и висящих предметов)
	local function downIn(pose)
		local rot = ANG(rad(pose[1]), rad(pose[2]), rad(pose[3]))
		local v = rot:Inverse() * V(0, -1, 0)
		return V(v.X, v.Y, v.Z).Unit
	end

	-- Тыква из 8 граней-рёбер вокруг оси Y; лицо смотрит в -Z. Возвращает список деталей лица.
	local function pumpkin(r, limb, cf, R, h, color, edge, faceColor, o)
		o = o or {}
		local w = 2 * R * math.tan(rad(22.5)) * 1.12
		local ribs = {}
		-- рёбра чередуются по цвету и высоте; между ними — тёмные бороздки
		local mid = color:Lerp(edge, 0.35)
		for k = 0, 7 do
			local a = k * PI / 4
			local hh = (k % 2 == 0) and h or h * 0.9
			local pos = V(math.sin(a) * R * 0.6, 0, -math.cos(a) * R * 0.6)
			ribs[#ribs + 1] = r:Box(limb, V(w, hh, R * 0.8), cf * CF(pos) * ANG(0, -a, 0), (k % 2 == 0) and color or mid, M.Plastic)
			if not o.Cheap and not lite() then
				local g = a + PI / 8
				r:Box(limb, V(0.06, h * 0.86, 0.06), cf * CF(math.sin(g) * R * 0.97, 0, -math.cos(g) * R * 0.97) * ANG(0, -g, 0), edge, M.Plastic)
			end
		end
		-- верх и низ
		r:Box(limb, V(R * 1.3, h * 0.1, R * 1.3), cf * CF(0, h / 2 - h * 0.02, 0) * ANG(0, PI / 4, 0), edge, M.Plastic)
		-- черенок
		Kit.bar(r, limb, cf * V(0, h / 2, 0), cf * V(0.08 * R, h / 2 + h * 0.26, 0.05 * R), V2(0.16 * R, 0.16 * R), o.Stem or rgb(66, 74, 34), M.Wood)
		-- вырезанное лицо (светится)
		local face = {}
		if faceColor then
			local z = -R - 0.03
			for _, s in ipairs({ -1, 1 }) do
				for _, p in ipairs(tri(r, limb, cf * CF(0.3 * R * s, h * 0.14, z) * ANG(0, 0, rad(8 * s)), 0.36 * R, 0.3 * R, faceColor, M.Neon, 0.06)) do
					face[#face + 1] = p
				end
			end
			if not o.Cheap then
				for _, p in ipairs(tri(r, limb, cf * CF(0, -h * 0.02, z), 0.14 * R, 0.13 * R, faceColor, M.Neon, 0.06)) do
					face[#face + 1] = p
				end
			end
			face[#face + 1] = r:Neon(limb, V(0.95 * R, 0.17 * R, 0.06), cf * CF(0, -h * 0.22, z), faceColor)
			-- зубы
			if not o.Cheap then
				for _, x in ipairs({ -0.24, 0.24 }) do
					r:Box(limb, V(0.14 * R, 0.1 * R, 0.07), cf * CF(x * R, -h * 0.19, z - 0.01), color, M.Plastic)
				end
				r:Box(limb, V(0.14 * R, 0.1 * R, 0.07), cf * CF(0, -h * 0.25, z - 0.01), color, M.Plastic)
			end
		end
		return face
	end

	-- Фонарь: крыша, кольцо, стекло, огонёк внутри. cf — центр стекла. Возвращает огонёк.
	local function lantern(r, limb, cf, s, frame, glow, glass)
		Kit.bevel(r, limb, V(0.72, 0.16, 0.72) * s, cf * CF(0, 0.42 * s, 0), frame, false)
		Kit.spike(r, limb, cf * V(0, 0.48 * s, 0), cf * V(0, 0.8 * s, 0), 0.52 * s, frame, M.Metal)
		r:Box(limb, V(0.06, 0.3, 0.3) * s, cf * CF(0, 0.92 * s, 0), frame, M.Metal)
		r:Box(limb, V(0.06, 0.06, 0.3) * s, cf * CF(0, 1.06 * s, 0), frame, M.Metal)
		for _, x in ipairs({ -1, 1 }) do
			for _, z in ipairs({ -1, 1 }) do
				r:Box(limb, V(0.07, 0.7, 0.07) * s, cf * CF(0.27 * s * x, 0, 0.27 * s * z), frame, M.Metal)
			end
		end
		r:Box(limb, V(0.5, 0.6, 0.5) * s, cf, glass or rgb(255, 170, 70), M.Glass, { Transparency = 0.45 })
		local flame = r:Neon(limb, V(0.22, 0.32, 0.22) * s, cf * CF(0, -0.03 * s, 0) * ANG(0, PI / 4, 0), glow)
		Kit.bevel(r, limb, V(0.66, 0.14, 0.66) * s, cf * CF(0, -0.38 * s, 0), frame, false)
		r:Glow(flame, glow, 9, 1.4)
		return flame
	end

	-- Корона: кольцо-восьмиугольник с зубцами (cf — центр низа короны)
	local function kingCrown(r, limb, cf, R, h, color, gemColor, n)
		local sides = (n or 8) <= 4 and 4 or 8
		local w = 2 * R * math.tan(PI / sides) * 1.1
		for k = 0, sides - 1 do
			local a = k * 2 * PI / sides
			r:Box(limb, V(w, h * 0.32, 0.12), cf * CF(math.sin(a) * R, h * 0.16, -math.cos(a) * R) * ANG(0, -a, 0), color, M.Metal)
		end
		for k = 0, (n or 8) - 1 do
			local a = k * 2 * PI / (n or 8)
			local p = V(math.sin(a) * R, h * 0.3, -math.cos(a) * R)
			local hh = (k % 2 == 0) and h or h * 0.62
			tri(r, limb, cf * CF(p + V(0, hh / 2, 0)) * ANG(0, -a, 0), 0.36, hh, color, M.Metal, 0.12)
		end
		if gemColor then
			Kit.gem(r, limb, 0.22, cf * CF(0, h * 0.16, -R - 0.07), gemColor)
		end
		if gemColor and sides == 8 then
			Kit.gem(r, limb, 0.15, cf * CF(R * 0.72, h * 0.16, -R * 0.72 - 0.07) * ANG(0, rad(-45), 0), gemColor)
			Kit.gem(r, limb, 0.15, cf * CF(-R * 0.72, h * 0.16, -R * 0.72 - 0.07) * ANG(0, rad(45), 0), gemColor)
		end
	end

	-- Широкополая шляпа (cf — центр полей на голове)
	local function brimHat(r, color, band, o)
		o = o or {}
		local Hd = r.Head
		local y = o.Y or 0.62
		Kit.bevel(r, Hd, V(o.Brim or 2.1, 0.12, o.Brim or 2.1), CF(0, y, 0) * ANG(rad(o.Tilt or 0), 0, 0), color, o.Edge or false, M.Fabric)
		Kit.bevel(r, Hd, V(o.W or 1.3, o.Hgt or 0.6, o.W or 1.3), CF(0, y + (o.Hgt or 0.6) / 2, 0) * ANG(rad(o.Tilt or 0), 0, 0), color, o.Edge or false, M.Fabric)
		if band then
			r:Box(Hd, V((o.W or 1.3) + 0.04, 0.14, (o.W or 1.3) + 0.04), CF(0, y + 0.12, 0) * ANG(rad(o.Tilt or 0), 0, 0), band, M.Fabric)
		end
	end

	-- Ворона: сидит на детали limb в точке cf (клюв в -Z cf)
	local function crow(r, limb, cf, s, eye)
		Kit.bevel(r, limb, V(0.36, 0.34, 0.6) * s, cf * CF(0, 0.17 * s, 0), HW.Black, rgb(60, 54, 70), M.Plastic)
		r:Box(limb, V(0.3, 0.28, 0.3) * s, cf * CF(0, 0.42 * s, -0.3 * s), HW.Black, M.Plastic)
		Kit.spike(r, limb, cf * V(0, 0.4 * s, -0.44 * s), cf * V(0, 0.36 * s, -0.72 * s), 0.14 * s, rgb(70, 60, 50), M.Plastic, true, 0.06)
		for _, x in ipairs({ -1, 1 }) do
			r:Neon(limb, V(0.04, 0.06, 0.06) * s, cf * CF(0.15 * s * x, 0.47 * s, -0.38 * s), eye or HW.Orange)
			r:Wedge(limb, V(0.06, 0.24, 0.5) * s, cf * CF(0.2 * s * x, 0.24 * s, 0.05 * s), rgb(30, 26, 38), M.Plastic)
		end
		Kit.spike(r, limb, cf * V(0, 0.2 * s, 0.28 * s), cf * V(0, 0.12 * s, 0.62 * s), 0.26 * s, HW.Black, M.Plastic, true, 0.05)
	end

	-- Пятиконечная звезда (значок шерифа) в плоскости XY
	local function star(r, limb, cf, s, color)
		for k = 0, 4 do
			tri(r, limb, cf * ANG(0, 0, k * 2 * PI / 5) * CF(0, 0.18 * s, 0), 0.22 * s, 0.32 * s, color, M.Metal, 0.05)
		end
		r:Box(limb, V(0.2, 0.2, 0.06) * s, cf * ANG(0, 0, rad(45)), color, M.Metal)
	end

	-- Склянка с жидкостью (cf — центр)
	local function flask(r, limb, cf, s, liquid)
		r:Box(limb, V(0.36, 0.42, 0.36) * s, cf, rgb(180, 220, 200), M.Glass, { Transparency = 0.5 })
		local l = r:Neon(limb, V(0.3, 0.26, 0.3) * s, cf * CF(0, -0.06 * s, 0), liquid)
		r:Box(limb, V(0.14, 0.2, 0.14) * s, cf * CF(0, 0.3 * s, 0), rgb(180, 220, 200), M.Glass, { Transparency = 0.5 })
		r:Box(limb, V(0.12, 0.08, 0.12) * s, cf * CF(0, 0.43 * s, 0), HW.Wood, M.Wood)
		return l
	end

	-- Колокол из уступов (cf — точка подвеса, колокол висит вниз)
	local function bell(r, limb, cf, s, color, rim, glow)
		Kit.bevel(r, limb, V(0.3, 0.2, 0.3) * s, cf * CF(0, -0.1 * s, 0), color, false)
		Kit.bevel(r, limb, V(0.55, 0.3, 0.55) * s, cf * CF(0, -0.32 * s, 0), color, rim)
		Kit.bevel(r, limb, V(0.72, 0.34, 0.72) * s, cf * CF(0, -0.62 * s, 0), color, rim)
		Kit.bevel(r, limb, V(0.95, 0.18, 0.95) * s, cf * CF(0, -0.86 * s, 0), rim, false)
		r:Box(limb, V(0.5, 0.1, 0.5) * s, cf * CF(0, -0.96 * s, 0), rgb(10, 8, 14), M.Plastic)
		local c = r:Neon(limb, V(0.2, 0.2, 0.2) * s, cf * CF(0, -1.04 * s, 0) * ANG(rad(45), 0, rad(45)), glow)
		return c
	end

	-- Игральная карта (cf — центр, лицом в -Z)
	local function card(r, limb, cf, s, suit, back)
		r:Box(limb, V(0.42, 0.6, 0.03) * s, cf, back and HW.Purple or rgb(236, 232, 240), M.Plastic)
		if back then
			r:Neon(limb, V(0.18, 0.18, 0.035) * s, cf * ANG(0, 0, rad(45)), HW.Violet)
		else
			r:Box(limb, V(0.14, 0.14, 0.035) * s, cf * ANG(0, 0, rad(45)), suit, M.Plastic)
		end
	end

	-- Нить (тонкий светящийся отрезок)
	local function thread(r, limb, a, b, color, d)
		return r:Seg(limb, a, b, d or 0.035, color, M.Neon)
	end

	-- Шлейф пламени / искр вверх
	local function embers(r, part, color, rate, size)
		return r:Sparkles(part, color, { Rate = rate or 8, Up = 3, Size = size or 0.25, LifeMin = 0.5, LifeMax = 1.1 })
	end

	------------------------------------------------------------------------
	-- 1. NIGHT WATCHMAN (Common) — ночной сторож с фонарём
	------------------------------------------------------------------------
	local function NightWatchman(lv)
		local coat, coatD = rgb(40, 44, 66), rgb(28, 30, 46)
		local r = figure("NightWatchman", { Torso = coat, Arm = coat, Leg = coatD, Skin = rgb(206, 178, 156), Edge = HW.EdgeCool })
		eyes(r, rgb(30, 22, 18), false, 0.06)
		r:Box(r.Head, V(0.5, 0.08, 0.05), CF(0, -0.3, -0.62), rgb(90, 60, 50))
		-- седые бакенбарды
		for _, s in ipairs({ -1, 1 }) do
			r:Box(r.Head, V(0.12, 0.5, 0.5), CF(0.62 * s, -0.2, -0.1), rgb(150, 146, 150), M.Fabric)
		end
		-- фуражка-котелок
		brimHat(r, HW.Coal, lv >= 2 and HW.Burgundy or nil, { Brim = 1.7, W = 1.24, Hgt = 0.5, Y = 0.6 })
		-- длинное пальто с пуговицами
		Kit.bevel(r, r.Torso, V(2.14, 1.2, 1.14), CF(0, 0.38, 0), coat, HW.EdgeCool, M.Fabric)
		for k = 0, 2 do
			r:Box(r.Torso, V(0.14, 0.14, 0.06), CF(0, 0.7 - k * 0.42, -0.6), lv >= 4 and HW.Gold or HW.Iron, M.Metal)
		end
		for _, s in ipairs({ -1, 1 }) do
			Kit.bevel(r, r.Torso, V(0.98, 1.3, 0.16), CF(0.52 * s, -1.6, -0.5), coatD, false, M.Fabric)
		end
		belt(r, HW.Leather, HW.Iron)
		if lv >= 2 then
			-- шарф
			Kit.bevel(r, r.Torso, V(1.4, 0.3, 1.2), CF(0, 0.98, 0), HW.Burgundy, false, M.Fabric)
			r:Box(r.Torso, V(0.3, 0.8, 0.08), CF(0.4, 0.5, -0.62), HW.Burgundy, M.Fabric)
		end
		if lv >= 3 then
			mantle(r, coatD, HW.EdgeCool)
			-- связка ключей на поясе
			r:Box(r.Torso, V(0.2, 0.2, 0.06), CF(-0.7, -0.95, -0.6), HW.Iron, M.Metal)
			r:Box(r.Torso, V(0.06, 0.4, 0.06), CF(-0.62, -1.2, -0.62), HW.Gold, M.Metal)
			r:Box(r.Torso, V(0.06, 0.34, 0.06), CF(-0.78, -1.17, -0.62), HW.Gold, M.Metal)
		end
		-- дубинка в левой руке
		local club = lv >= 4 and HW.Iron or HW.Wood
		r:Box(r.LArm, V(0.22, 1.7, 0.22), CF(0, -1.6, -0.3) * ANG(rad(-20), 0, 0), club, lv >= 4 and M.Metal or M.Wood)
		if lv >= 4 then
			star(r, r.Torso, CF(-0.55, 0.6, -0.62), 0.9, HW.Gold)
		end
		-- фонарь висит под кулаком правой руки
		local pose = { 35, 0, 0 }
		local dn = downIn(pose)
		local hand = V(0, GRIP, -0.2)
		r:Seg(r.RArm, hand, hand + dn * 0.55, 0.06, HW.Iron, M.Metal)
		local lc = hand + dn * 1.05
		local s = lv >= 4 and 1.25 or 1.05
		local look = CFrame.lookAt(lc, lc + dn, V(0, 0, -1)) * ANG(-PI / 2, 0, 0)
		local flame = lantern(r, r.RArm, look * ANG(PI, 0, 0), s, lv >= 4 and HW.Gold or HW.Iron, lv >= 5 and rgb(255, 230, 150) or HW.Flame)
		muzzle(r, r.RArm, CF(lc))
		if lv >= 3 then
			embers(r, flame, HW.Flame, 4, 0.15)
		end
		for _, L in ipairs({ r.RLeg, r.LLeg }) do
			Kit.bevel(r, L, V(1.1, 0.5, 1.2), CF(0, -0.75, -0.08), HW.Leather, false)
		end
		if lv >= 5 then
			capeWith(r, 1.9, 2.9, coatD, HW.Flame)
		end
		levelAura(r, lv, HW.Flame)
		return r:Finish(Config.Units.NightWatchman.Scale, { RS = pose, LS = { 8, 0, -6 } })
	end

	------------------------------------------------------------------------
	-- 2. GRAVEDIGGER (Rare) — могильщик с лопатой
	------------------------------------------------------------------------
	local function Gravedigger(lv)
		local shirt, pants = rgb(70, 58, 50), rgb(44, 38, 36)
		local r = figure("Gravedigger", { Torso = shirt, Arm = shirt, Leg = pants, Skin = rgb(150, 160, 140), Edge = HW.Edge })
		eyes(r, lv >= 3 and HW.Orange or rgb(30, 26, 22), lv >= 3, 0.08)
		-- щетина/борода и кривой рот
		Kit.bevel(r, r.Head, V(1.24, 0.42, 0.3), CF(0, -0.42, -0.5), rgb(70, 64, 58), false, M.Fabric)
		-- шляпа с обвисшими полями
		brimHat(r, rgb(46, 40, 36), rgb(90, 70, 46), { Brim = 1.9, W = 1.26, Hgt = 0.5, Y = 0.6, Tilt = -6 })
		-- фартук
		Kit.bevel(r, r.Torso, V(1.7, 1.9, 0.12), CF(0, -0.4, -0.56), HW.Leather, false, M.Fabric)
		r:Box(r.Torso, V(0.08, 0.9, 0.06), CF(-0.5, 0.6, -0.56), HW.Leather, M.Fabric)
		r:Box(r.Torso, V(0.08, 0.9, 0.06), CF(0.5, 0.6, -0.56), HW.Leather, M.Fabric)
		belt(r, HW.Leather, HW.Iron)
		-- закатанные рукава, перчатки
		for _, A in ipairs({ r.RArm, r.LArm }) do
			Kit.bevel(r, A, V(1.1, 0.3, 1.1), CF(0, -0.15, 0), rgb(96, 82, 70), false, M.Fabric)
			Kit.bevel(r, A, V(1.06, 0.55, 1.06), CF(0, -0.78, 0), rgb(46, 36, 30), false, M.Fabric)
		end
		for _, L in ipairs({ r.RLeg, r.LLeg }) do
			Kit.bootA(r, L, HW.Leather, false, 1.1)
		end
		if lv >= 2 then
			H.plateShoulders(r, HW.Iron, HW.Edge, 0.9)
			-- комья земли на ботинках
			r:Box(r.RLeg, V(0.4, 0.2, 0.3), CF(0.2, -0.95, -0.6), rgb(60, 46, 34), M.Plastic)
		end
		if lv >= 3 then
			-- фонарь на поясе
			lantern(r, r.Torso, CF(-0.95, -1.15, -0.25), 0.6, HW.Iron, HW.Flame)
		end
		if lv >= 4 then
			-- надгробие-ранец за спиной
			Kit.bevel(r, r.Torso, V(1.3, 1.6, 0.35), CF(0, 0.5, 0.75), rgb(96, 94, 104), rgb(140, 138, 150), M.Slate)
			Kit.bevel(r, r.Torso, V(0.95, 0.3, 0.37), CF(0, 1.4, 0.75), rgb(96, 94, 104), false, M.Slate)
			r:Box(r.Torso, V(0.15, 0.7, 0.05), CF(0, 0.6, 0.94), rgb(60, 58, 66), M.Slate)
			r:Box(r.Torso, V(0.45, 0.15, 0.05), CF(0, 0.75, 0.94), rgb(60, 58, 66), M.Slate)
		end
		-- лопата: древко, Т-рукоять, полотно наверху
		local wood = lv >= 4 and HW.Wood or HW.WoodLight
		local top = shaft(r, r.RArm, -2.4, 1.5, wood, 0.2)
		r:Box(r.RArm, V(0.55, 0.16, 0.16), CF(0, -2.45, -0.5), wood, M.Wood)
		local bladeC = top + V(0, 0.6, 0)
		local metal = lv >= 5 and HW.Gold or (lv >= 3 and HW.Iron or rgb(110, 90, 70))
		Kit.bevel(r, r.RArm, V(0.1, 0.36, 0.3), CF(top + V(0, 0.08, 0)), metal, false)
		Kit.bevel(r, r.RArm, V(0.08, 0.9, 0.85), CF(bladeC), metal, lv >= 3 and HW.Edge or false)
		Kit.spike(r, r.RArm, bladeC + V(0, 0.45, 0), bladeC + V(0, 0.8, 0), 0.85, metal, M.Metal, true, 0.08)
		if lv >= 5 then
			r:Neon(r.RArm, V(0.1, 0.06, 0.8), CF(bladeC + V(0, 0.42, 0)), HW.Orange)
		end
		if lv >= 4 then
			-- череп на полотне
			Kit.bevel(r, r.RArm, V(0.06, 0.3, 0.3), CF(bladeC + V(-0.06, 0, 0)), HW.Bone, false, M.Plastic)
		end
		r:WeaponTrail(r.RArm, top, bladeC + V(0, 0.8, 0), lv >= 5 and HW.Orange or rgb(180, 150, 110))
		muzzle(r, r.RArm, CF(bladeC + V(0, 0.6, 0)))
		if lv >= 5 then
			capeWith(r, 1.9, 2.8, rgb(46, 40, 36), HW.Orange)
		end
		levelAura(r, lv, HW.Orange)
		return r:Finish(Config.Units.Gravedigger.Scale, { RS = { 25, 0, 0 }, LS = { 10, 0, -6 }, Neck = { 6, 0, 0 } })
	end

	------------------------------------------------------------------------
	-- 3. CURSED SCARECROW (Rare) — проклятое пугало с вороньём
	------------------------------------------------------------------------
	local function CursedScarecrow(lv)
		local shirt = lv >= 4 and rgb(110, 40, 40) or rgb(120, 90, 60)
		local r = figure("CursedScarecrow", { Torso = shirt, Arm = shirt, Leg = rgb(70, 60, 80), Skin = HW.Burlap, Edge = HW.StrawDark })
		local Hd = r.Head
		-- мешок-голова: прошитые глаза-кресты и рот
		Kit.bevel(r, Hd, V(1.3, 1.25, 1.3), CF(0, 0, 0), HW.Burlap, HW.StrawDark, M.Fabric)
		local glow = lv >= 3 and HW.Orange or rgb(40, 26, 18)
		for _, s in ipairs({ -1, 1 }) do
			for _, a in ipairs({ 45, -45 }) do
				local f = lv >= 3 and r.Neon or r.Box
				f(r, Hd, V(0.3, 0.07, 0.05), CF(0.28 * s, 0.12, -0.67) * ANG(0, 0, rad(a)), glow)
			end
		end
		r:Box(Hd, V(0.7, 0.06, 0.05), CF(0, -0.28, -0.67), rgb(40, 26, 18))
		for k = -2, 2 do
			r:Box(Hd, V(0.04, 0.18, 0.05), CF(k * 0.15, -0.28, -0.68), rgb(40, 26, 18))
		end
		-- верёвка на шее и пучки соломы
		r:Box(Hd, V(1.34, 0.12, 1.34), CF(0, -0.55, 0), HW.StrawDark, M.Fabric)
		for k = 0, 5 do
			local a = k / 6 * PI * 2
			Kit.spike(r, Hd, V(math.cos(a) * 0.5, -0.6, math.sin(a) * 0.5), V(math.cos(a) * 0.85, -0.95, math.sin(a) * 0.85), 0.2, HW.Straw, M.Fabric, true, 0.05)
		end
		-- шляпа-колпак
		if lv >= 2 then
			H.wizardHat(r, rgb(60, 46, 34), lv >= 4 and HW.Burgundy or rgb(90, 70, 46), false)
		end
		-- рубаха с заплатками
		Kit.bevel(r, r.Torso, V(2.14, 2.0, 1.14), CF(0, 0, 0), shirt, HW.StrawDark, M.Fabric)
		r:Box(r.Torso, V(0.5, 0.45, 0.05), CF(0.45, -0.1, -0.6), rgb(150, 130, 90), M.Fabric)
		r:Box(r.Torso, V(0.4, 0.4, 0.05), CF(-0.5, 0.5, -0.6), rgb(90, 70, 100), M.Fabric)
		belt(r, rgb(120, 96, 50), HW.StrawDark)
		-- солома из рукавов и штанин
		for _, A in ipairs({ r.RArm, r.LArm, r.RLeg, r.LLeg }) do
			for k = -1, 1 do
				Kit.spike(r, A, V(k * 0.28, -0.85, 0), V(k * 0.4, -1.35, -0.1), 0.24, HW.Straw, M.Fabric, true, 0.05)
			end
		end
		-- крест-шест за спиной
		r:Box(r.Torso, V(0.24, 4.6, 0.24), CF(0, -0.1, 0.72), HW.Wood, M.Wood)
		r:Box(r.Torso, V(3.6, 0.22, 0.22), CF(0, 0.75, 0.72), HW.Wood, M.Wood)
		-- вилы в правой руке
		local top = shaft(r, r.RArm, -2.5, 2.0, HW.Wood, 0.18)
		local fork = lv >= 4 and HW.Iron or rgb(100, 90, 80)
		r:Box(r.RArm, V(0.12, 0.12, 0.85), CF(top + V(0, 0.05, 0)), fork, M.Metal)
		for k = -1, 1 do
			Kit.spike(r, r.RArm, top + V(0, 0.05, k * 0.38), top + V(0, 0.95, k * 0.38), 0.14, fork, M.Metal)
		end
		if lv >= 5 then
			for k = -1, 1 do
				r:Neon(r.RArm, V(0.05, 0.5, 0.05), CF(top + V(0, 0.45, k * 0.38 - 0.06)), HW.Orange)
			end
		end
		muzzle(r, r.RArm, CF(top + V(0, 0.9, 0)))
		r:WeaponTrail(r.RArm, top, top + V(0, 1, 0), HW.Orange)
		-- вороны на плечах
		if lv >= 3 then
			crow(r, r.LArm, CF(0, 1.02, 0) * ANG(0, rad(20), 0), 1, HW.Orange)
		end
		if lv >= 4 then
			crow(r, r.Torso, CF(1.35, 0.85, 0.72) * ANG(0, rad(-30), 0), 0.9, HW.Orange)
		end
		if lv >= 5 then
			local hub = r:Orbit("OrbitCrows", r.Torso, CF(0, 1.9, 0), 2.2, 0, 0.2, HW.Black)
			for i = 0, 2 do
				local a = i / 3 * PI * 2
				crow(r, hub, CF(math.cos(a) * 2.3, math.sin(a * 2) * 0.2, math.sin(a) * 2.3) * ANG(0, -a, 0), 0.9, HW.Orange)
			end
			capeWith(r, 1.9, 2.8, rgb(70, 54, 40), HW.Orange)
		end
		levelAura(r, lv, HW.Orange)
		return r:Finish(Config.Units.CursedScarecrow.Scale, { RS = { 20, 0, 0 }, LS = { 75, 0, -25 } })
	end

	------------------------------------------------------------------------
	-- 4. CURSED SHERIFF (Epic) — проклятый шериф с зелёным револьвером
	------------------------------------------------------------------------
	local function revolver(r, A, o)
		local F = AIM
		Kit.bevel(r, A, V(0.26, 0.5, 0.34), F * CF(0, -0.15, 0.15) * ANG(rad(-18), 0, 0), o.Grip or HW.Wood, false, M.Wood)
		Kit.bevel(r, A, V(0.3, 0.32, 0.5), F * CF(0, 0.14, -0.15), o.Metal, o.Edge)
		local cyl = Kit.bevel(r, A, V(0.4, 0.34, 0.38), F * CF(0, 0.16, -0.5), o.Metal, o.Edge)
		r:Box(A, V(0.18, 0.18, 1.1), F * CF(0, 0.24, -1.15), o.Metal, M.Metal)
		r:Box(A, V(0.06, 0.1, 0.1), F * CF(0, 0.36, -1.6), o.Metal, M.Metal)
		r:Neon(A, V(0.08, 0.08, 0.9), F * CF(0, 0.34, -1.1), o.Glow)
		for k = 0, 1 do
			r:Neon(A, V(0.42, 0.06, 0.06), F * CF(0, 0.16, -0.38 - k * 0.24), o.Glow)
		end
		return muzzle(r, A, F * CF(0, 0.24, -1.75)), cyl
	end

	local function CursedSheriff(lv)
		local coat, coatD = rgb(76, 54, 38), rgb(46, 34, 28)
		local r = figure("CursedSheriff", { Torso = rgb(56, 50, 46), Arm = coat, Leg = rgb(40, 36, 44), Skin = rgb(150, 170, 150), Edge = HW.Edge })
		local glow = HW.Green
		eyes(r, glow, true, 0.08)
		-- платок на лице
		Kit.bevel(r, r.Head, V(1.26, 0.5, 1.26), CF(0, -0.36, 0), lv >= 4 and HW.Burgundy or rgb(110, 40, 40), false, M.Fabric)
		Kit.spike(r, r.Head, V(0, -0.6, -0.63), V(0, -0.95, -0.66), 0.5, lv >= 4 and HW.Burgundy or rgb(110, 40, 40), M.Fabric, true, 0.06)
		-- ковбойская шляпа: широкие поля с загнутыми краями и тулья с вмятиной
		local hatC = lv >= 3 and HW.Black or rgb(70, 50, 36)
		Kit.bevel(r, r.Head, V(2.3, 0.12, 1.9), CF(0, 0.62, 0), hatC, false, M.Fabric)
		for _, s in ipairs({ -1, 1 }) do
			Kit.bevel(r, r.Head, V(0.3, 0.12, 1.8), CF(1.2 * s, 0.75, 0) * ANG(0, 0, rad(35 * s)), hatC, false, M.Fabric)
		end
		Kit.bevel(r, r.Head, V(1.25, 0.62, 1.3), CF(0, 0.98, 0), hatC, false, M.Fabric)
		r:Wedge(r.Head, V(1.25, 0.18, 0.6), CF(0, 1.38, -0.2) * ANG(0, PI, 0), hatC, M.Fabric)
		r:Box(r.Head, V(1.29, 0.14, 1.34), CF(0, 0.74, 0), lv >= 3 and glow or rgb(140, 110, 70), lv >= 3 and M.Neon or M.Fabric)
		if lv >= 4 then
			-- черепок на шляпе
			Kit.bevel(r, r.Head, V(0.34, 0.34, 0.08), CF(0, 0.92, -0.68), HW.Bone, false, M.Plastic)
			for _, s in ipairs({ -1, 1 }) do
				r:Neon(r.Head, V(0.08, 0.08, 0.04), CF(0.08 * s, 0.94, -0.73), glow)
			end
		end
		-- жилет, значок, пояс с патронами
		Kit.bevel(r, r.Torso, V(2.12, 1.3, 1.12), CF(0, 0.32, 0), rgb(46, 40, 38), HW.Edge, M.Fabric)
		star(r, r.Torso, CF(-0.5, 0.55, -0.6), 1.05, lv >= 2 and HW.Gold or HW.Iron)
		belt(r, HW.Leather, HW.Gold)
		if lv >= 2 then
			Kit.bar(r, r.Torso, V(-0.9, 0.95, -0.58), V(0.9, -0.7, -0.58), V2(0.2, 0.06), HW.Leather)
			for k = 0, 3 do
				local p = V(-0.6 + k * 0.38, 0.65 - k * 0.35, -0.62)
				r:Box(r.Torso, V(0.08, 0.16, 0.06), CF(p) * ANG(0, 0, rad(42)), HW.Gold, M.Metal)
			end
		end
		-- длинный плащ-пыльник: полы до колен
		for _, s in ipairs({ -1, 1 }) do
			Kit.bevel(r, r.Torso, V(0.98, 1.7, 0.16), CF(0.56 * s, -1.75, -0.44), coat, HW.Edge, M.Fabric)
			Kit.bevel(r, r.Torso, V(0.16, 1.7, 1.1), CF(1.05 * s, -1.75, 0.0), coat, false, M.Fabric)
		end
		Kit.bevel(r, r.Torso, V(2.1, 1.8, 0.16), CF(0, -1.8, 0.52), coat, false, M.Fabric)
		Kit.tatter(r, r.Torso, -2.6, 0.55, 2.0, 4, coat, M.Fabric, 2)
		for _, A in ipairs({ r.RArm, r.LArm }) do
			Kit.bevel(r, A, V(1.08, 0.4, 1.08), CF(0, -0.75, 0), HW.Leather, false, M.Fabric)
		end
		if lv >= 4 then
			mantle(r, coatD, HW.Edge)
		end
		for _, L in ipairs({ r.RLeg, r.LLeg }) do
			Kit.bootA(r, L, HW.Leather, HW.Edge, 1.1)
			r:Box(L, V(0.1, 0.1, 0.3), CF(0, -0.95, 0.65), HW.Gold, M.Metal) -- шпоры
		end
		local metal = lv >= 4 and rgb(40, 44, 40) or HW.Iron
		local edge = lv >= 3 and HW.GreenDim or HW.Edge
		revolver(r, r.RArm, { Metal = metal, Edge = edge, Glow = glow })
		if lv >= 3 then
			-- второй револьвер в левой руке
			local m2 = r.Muzzle
			revolver(r, r.LArm, { Metal = metal, Edge = edge, Glow = glow })
			r.Muzzle = m2
		else
			-- кобура
			Kit.bevel(r, r.Torso, V(0.3, 0.6, 0.42), CF(-1.0, -1.15, -0.1), HW.Leather, false, M.Fabric)
		end
		if lv >= 5 then
			capeWith(r, 1.9, 3.0, coatD, glow)
			-- проклятые цепи с черепами по поясу
			Kit.chain(r, r.Torso, 4, 0.22, rgb(60, 90, 60), CF(0.95, -0.95, -0.35))
		end
		levelAura(r, lv, glow)
		return r:Finish(Config.Units.CursedSheriff.Scale, { RS = { 72, 0, 0 }, LS = lv >= 3 and { 30, 0, -10 } or { 6, 0, -6 } })
	end

	------------------------------------------------------------------------
	-- 5. MIDNIGHT BELLRINGER (Epic) — горбатый звонарь с колоколом
	------------------------------------------------------------------------
	local function MidnightBellringer(lv)
		local robeC, robeD = rgb(44, 34, 62), rgb(28, 22, 40)
		local r = figure("MidnightBellringer", { Torso = robeC, Arm = robeC, Leg = robeD, Skin = rgb(170, 160, 176), Edge = HW.EdgeCool })
		local glow = rgb(190, 160, 255)
		H.hood(r, robeC, HW.EdgeCool, glow, true)
		for _, x in ipairs({ -1, 1 }) do
			r:Neon(r.Head, V(0.22, 0.13, 0.05), CF(0.24 * x, 0.06, -0.66), glow)
		end
		-- горб
		Kit.bevel(r, r.Torso, V(1.7, 1.1, 0.8), CF(0, 0.65, 0.65) * ANG(rad(-15), 0, 0), robeC, HW.EdgeCool, M.Fabric)
		robe(r, robeD, lv >= 3 and HW.Gold or nil, 1.8)
		belt(r, rgb(70, 50, 40), HW.Gold, lv >= 2 and glow or nil)
		-- верёвка от колокола на поясе
		r:Box(r.Torso, V(0.12, 1.4, 0.12), CF(0.75, -1.5, -0.6), rgb(170, 150, 110), M.Fabric)
		if lv >= 2 then
			mantle(r, robeC, HW.EdgeCool)
		end
		-- ручной колокол: рукоять в кулаке, колокол под ней
		local pose = { 62, 0, 10 }
		local dn = downIn(pose)
		local hand = V(0, GRIP, -0.15)
		r:Seg(r.RArm, hand, hand + dn * 0.6, V2(0.2, 0.2), HW.Wood, M.Wood)
		local s = ({ 0.8, 0.85, 0.9, 1.0, 1.1 })[lv]
		local hang = CFrame.lookAt(hand + dn * 0.6, hand + dn * 2, V(0, 0, -1)) * ANG(-PI / 2, 0, 0) * ANG(PI, 0, 0)
		local bc = lv >= 4 and HW.Gold or rgb(150, 110, 60)
		local clap = bell(r, r.RArm, hang, s, bc, lv >= 4 and HW.GoldDark or rgb(110, 80, 44), glow)
		muzzle(r, r.RArm, hang * CF(0, -0.9 * s, 0))
		r:Glow(clap, glow, 8, 1)
		-- призрачные часы над плечом
		if lv >= 2 then
			local c = r:Joint("OrbitGhostClock", r.Torso, V(0.1, 0.1, 0.1), CF(-1.4, 2.0, 0.6), CF(), glow)
			c.Transparency = 1
			r:Box(c, V(1.0, 1.0, 0.1), CF() * ANG(0, 0, rad(45)), glow, M.Glass, { Transparency = 0.55 })
			r:Box(c, V(0.82, 0.82, 0.12), CF() * ANG(0, 0, rad(45)), rgb(30, 24, 50), M.Glass, { Transparency = 0.35 })
			r:Neon(c, V(0.06, 0.34, 0.14), CF(0, 0.15, -0.02), glow)
			r:Neon(c, V(0.26, 0.05, 0.14), CF(0.12, 0, -0.02), glow)
		end
		if lv >= 3 then
			-- малый колокол на поясе
			bell(r, r.Torso, CF(-0.95, -0.8, -0.3), 0.45, bc, rgb(110, 80, 44), glow)
		end
		if lv >= 4 then
			local hub = r:Orbit("OrbitClocks", r.Torso, CF(0, 0.6, 0), 2.3, 0, 0.2, glow)
			for i = 0, 2 do
				local a = i / 3 * PI * 2
				local p = CF(math.cos(a) * 2.3, 0, math.sin(a) * 2.3) * ANG(0, -a + PI / 2, 0)
				r:Box(hub, V(0.6, 0.6, 0.08), p * ANG(0, 0, rad(45)), glow, M.Glass, { Transparency = 0.5 })
				r:Neon(hub, V(0.05, 0.24, 0.1), p * CF(0, 0.1, 0), glow)
			end
		end
		if lv >= 5 then
			capeWith(r, 2.0, 3.0, robeC, glow)
		end
		levelAura(r, lv, glow)
		return r:Finish(Config.Units.MidnightBellringer.Scale, { RS = pose, LS = { 15, 0, -8 }, Neck = { -4, 0, 0 } })
	end

	------------------------------------------------------------------------
	-- 6. PLAGUE DOCTOR (Legendary) — чумной доктор
	------------------------------------------------------------------------
	local function PlagueDoctor(lv)
		local coat, coatD = rgb(30, 26, 32), rgb(20, 18, 24)
		local r = figure("PlagueDoctor", { Torso = coat, Arm = coat, Leg = coatD, Skin = rgb(60, 46, 38), Edge = HW.EdgeCool })
		local glow = HW.Green
		local Hd = r.Head
		-- кожаная маска с клювом и круглыми стёклами
		local leather = lv >= 4 and rgb(70, 48, 36) or rgb(96, 72, 54)
		Kit.bevel(r, Hd, V(1.3, 1.3, 1.3), CF(), leather, rgb(130, 100, 76), M.Fabric)
		Kit.bevel(r, Hd, V(0.62, 0.5, 0.5), CF(0, -0.2, -0.82), leather, rgb(130, 100, 76), M.Fabric)
		Kit.spike(r, Hd, V(0, -0.22, -1.05), V(0, -0.55, -2.1), 0.5, leather, M.Fabric)
		for _, s in ipairs({ -1, 1 }) do
			r:Box(Hd, V(0.38, 0.38, 0.08), CF(0.3 * s, 0.14, -0.67) * ANG(0, 0, rad(45)), HW.Gold, M.Metal)
			r:Neon(Hd, V(0.3, 0.3, 0.1), CF(0.3 * s, 0.14, -0.68) * ANG(0, 0, rad(45)), lv >= 2 and glow or rgb(160, 200, 160))
		end
		-- широкополая шляпа
		brimHat(r, HW.Black, lv >= 3 and HW.Burgundy or rgb(40, 34, 38), { Brim = 2.4, W = 1.4, Hgt = 0.75, Y = 0.68, Edge = HW.EdgeCool })
		-- длинный плащ и кожаный фартук
		robe(r, coat, lv >= 3 and HW.Burgundy or nil, 2.0)
		Kit.bevel(r, r.Torso, V(1.4, 2.6, 0.12), CF(0, -0.9, -0.62), rgb(70, 52, 40), false, M.Fabric)
		belt(r, HW.Leather, HW.Gold)
		mantle(r, coatD, HW.EdgeCool)
		for _, A in ipairs({ r.RArm, r.LArm }) do
			Kit.bevel(r, A, V(1.1, 0.6, 1.1), CF(0, -0.78, 0), rgb(36, 30, 30), false, M.Fabric)
		end
		-- склянки на поясе
		for k = 0, (lv >= 2 and 3 or 2) - 1 do
			flask(r, r.Torso, CF(-0.75 + k * 0.42, -1.18, -0.68), 0.75, k % 2 == 0 and glow or rgb(200, 80, 255))
		end
		-- колба с ядом в правой руке
		local f = flask(r, r.RArm, CF(0, GRIP - 0.42, -0.25), lv >= 4 and 1.5 or 1.25, glow)
		muzzle(r, r.RArm, CF(0, GRIP - 0.42, -0.25))
		r:Glow(f, glow, 7, 1)
		if lv >= 3 then
			r:Sparkles(f, glow, { Rate = 5, Up = 2, Size = 0.2 })
		end
		-- трость с черепом в левой руке
		local top = shaft(r, r.LArm, -3.0, -0.4, HW.Black, 0.16)
		Kit.bevel(r, r.LArm, V(0.42, 0.42, 0.42), CF(top + V(0, 0.2, 0)), HW.Bone, false, M.Plastic)
		for _, s in ipairs({ -1, 1 }) do
			r:Neon(r.LArm, V(0.1, 0.08, 0.04), CF(top + V(0.1 * s, 0.24, -0.22)), glow)
		end
		-- ворон на плече
		if lv >= 3 then
			crow(r, r.LArm, CF(0.05, 1.02, 0) * ANG(0, rad(15), 0), 1.15, glow)
		end
		if lv >= 4 then
			local hub = r:Orbit("OrbitFlasks", r.Torso, CF(0, 0.2, 0), 2.2, 0, 0.2, glow)
			for i = 0, 2 do
				local a = i / 3 * PI * 2
				flask(r, hub, CF(math.cos(a) * 2.2, math.sin(a * 2) * 0.2, math.sin(a) * 2.2), 0.9, i == 1 and rgb(200, 80, 255) or glow)
			end
		end
		if lv >= 5 then
			capeWith(r, 2.1, 3.3, coatD, glow)
			if not lite() then
				local e = Instance.new("ParticleEmitter")
				e.Name = "PoisonMist"
				e.Color = ColorSequence.new(rgb(80, 160, 70))
				e.LightEmission = 0.3
				e.Rate = 4
				e.Lifetime = NumberRange.new(1, 1.8)
				e.Speed = NumberRange.new(0.2, 0.6)
				e.SpreadAngle = Vector2.new(180, 180)
				e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1.6) })
				e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 1) })
				e.Parent = r.Torso
			end
		end
		levelAura(r, lv, glow)
		return r:Finish(Config.Units.PlagueDoctor.Scale, { RS = { 40, 0, 0 }, LS = { 15, 0, -8 }, Neck = { 6, 0, 0 } })
	end

	------------------------------------------------------------------------
	-- 7. PHANTOM KNIGHT (Legendary) — призрачный рыцарь
	------------------------------------------------------------------------
	local function PhantomKnight(lv)
		local ghost, deep = rgb(70, 120, 190), rgb(34, 52, 96)
		local edge = rgb(150, 210, 255)
		local glow = HW.Ghost
		local r = figure("PhantomKnight", { Torso = deep, Arm = deep, Leg = deep, Skin = rgb(20, 30, 50), Edge = edge })
		-- полупрозрачная броня призрака
		local function glass(limb, size, cf)
			return r:Box(limb, size, cf, ghost, M.Glass, { Transparency = 0.35 })
		end
		H.helm(r, rgb(46, 70, 120), edge, glow, nil, true)
		glass(r.Head, V(1.42, 1.56, 1.42), CF(0, 0.1, 0))
		-- плюмаж из синего огня
		local nPl = lv >= 4 and 3 or (lv >= 2 and 2 or 1)
		for k = 1, nPl do
			Kit.spike(r, r.Head, V(0, 0.75, 0.1 + k * 0.18), V(0, 1.4 + k * 0.1, 0.6 + k * 0.25), 0.4, glow, M.Neon, true, 0.08)
		end
		H.chest(r, rgb(46, 70, 120), edge, glow)
		glass(r.Torso, V(2.25, 2.1, 1.25), CF())
		belt(r, deep, edge, glow)
		H.tassets(r, rgb(46, 70, 120), edge)
		H.bigShoulders(r, rgb(46, 70, 120), edge, lv >= 3 and glow or nil, lv >= 4 and 1.15 or 1.0, lv >= 4 and 2 or 1)
		H.bracers(r, rgb(46, 70, 120), edge)
		-- ноги растворяются в дымке
		for _, L in ipairs({ r.RLeg, r.LLeg }) do
			Kit.bevel(r, L, V(1.12, 0.8, 1.14), CF(0, 0.3, 0), rgb(46, 70, 120), edge)
			glass(L, V(1.16, 2.0, 1.16), CF())
		end
		if not lite() then
			local e = Instance.new("ParticleEmitter")
			e.Name = "GhostMist"
			e.Color = ColorSequence.new(glow)
			e.LightEmission = 0.6
			e.Rate = 6
			e.Lifetime = NumberRange.new(0.8, 1.4)
			e.Speed = NumberRange.new(0.2, 0.7)
			e.SpreadAngle = Vector2.new(180, 180)
			e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1.2) })
			e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1) })
			e.Parent = r.RLeg
		end
		-- светящийся синий меч (на MAX — большой двуручный)
		local len = ({ 3.0, 3.2, 3.4, 3.7, 4.2 })[lv]
		H.blade(r, r.RArm, { Len = len, W = lv >= 5 and 0.7 or 0.55, Blade = rgb(90, 150, 220), Guard = rgb(46, 70, 120), Edge = edge, Glow = glow, Core = lv >= 3 and rgb(220, 240, 255) or nil, Trail = glow })
		if lv >= 3 then
			capeWith(r, 2.0, 3.2, rgb(30, 50, 90), glow)
		end
		if lv >= 5 then
			local hub = r:Orbit("OrbitSwords", r.Torso, CF(0, 0.4, 0), 2.6, 0, 0.2, glow)
			for i = 0, 2 do
				local a = i / 3 * PI * 2
				local p = V(math.cos(a) * 2.6, 0, math.sin(a) * 2.6)
				r:Box(hub, V(0.1, 1.6, 0.32), CF(p) * ANG(0, -a, 0), glow, M.Glass, { Transparency = 0.3 })
				r:Box(hub, V(0.12, 0.12, 0.7), CF(p + V(0, -0.7, 0)) * ANG(0, -a, 0), edge, M.Metal)
				Kit.spike(r, hub, p + V(0, 0.8, 0), p + V(0, 1.2, 0), 0.3, glow, M.Neon, true, 0.08)
			end
		end
		levelAura(r, lv, glow)
		local rig = r:Finish(Config.Units.PhantomKnight.Scale, { RS = { 30, 0, 0 }, LS = { 10, 0, -8 } })
		return rig
	end

	------------------------------------------------------------------------
	-- 8. DARK ILLUSIONIST (Legendary) — тёмный иллюзионист с картами
	------------------------------------------------------------------------
	local function DarkIllusionist(lv)
		local suit, suitD = rgb(30, 22, 40), rgb(20, 14, 28)
		local r = figure("DarkIllusionist", { Torso = suit, Arm = suit, Leg = suitD, Skin = rgb(214, 200, 210), Edge = HW.EdgeCool })
		local glow = HW.Violet
		local Hd = r.Head
		-- маска-домино и улыбка
		r:Box(Hd, V(1.1, 0.34, 0.06), CF(0, 0.12, -0.62), HW.Black, M.Plastic)
		for _, s in ipairs({ -1, 1 }) do
			r:Neon(Hd, V(0.2, 0.1, 0.05), CF(0.27 * s, 0.12, -0.66), glow)
		end
		r:Box(Hd, V(0.46, 0.06, 0.04), CF(0, -0.3, -0.62) * ANG(0, 0, rad(-6)), rgb(80, 20, 40))
		-- цилиндр
		Kit.bevel(r, Hd, V(1.8, 0.1, 1.8), CF(0, 0.62, 0), HW.Black, false, M.Fabric)
		Kit.bevel(r, Hd, V(1.15, 1.2, 1.15), CF(0, 1.25, 0), HW.Black, HW.EdgeCool, M.Fabric)
		r:Box(Hd, V(1.19, 0.2, 1.19), CF(0, 0.8, 0), lv >= 3 and glow or HW.Burgundy, lv >= 3 and M.Neon or M.Fabric)
		if lv >= 2 then
			card(r, Hd, CF(0.4, 0.95, -0.62) * ANG(0, 0, rad(-15)), 0.8, HW.Red)
		end
		-- фрак: жилет, лацканы, фалды
		Kit.bevel(r, r.Torso, V(2.12, 2.0, 1.12), CF(), suit, HW.EdgeCool, M.Fabric)
		r:Box(r.Torso, V(0.6, 1.3, 0.06), CF(0, 0.3, -0.58), rgb(80, 20, 40), M.Fabric)
		r:Wedge(r.Torso, V(0.5, 0.25, 0.06), CF(0, 0.9, -0.62) * ANG(0, 0, PI), rgb(236, 232, 240), M.Plastic)
		for _, s in ipairs({ -1, 1 }) do
			r:Box(r.Torso, V(0.36, 1.3, 0.08), CF(0.48 * s, 0.35, -0.6) * ANG(0, 0, rad(12 * s)), HW.Black, M.Fabric)
			Kit.bevel(r, r.Torso, V(0.85, 1.6, 0.14), CF(0.45 * s, -1.6, 0.52) * ANG(rad(-8), 0, rad(-6 * s)), suitD, false, M.Fabric)
		end
		belt(r, HW.Black, HW.Gold, lv >= 2 and glow or nil)
		-- белые перчатки
		for _, A in ipairs({ r.RArm, r.LArm }) do
			Kit.bevel(r, A, V(1.06, 0.42, 1.06), CF(0, -0.8, 0), rgb(236, 232, 240), false, M.Plastic)
		end
		-- плащ с высоким воротником (красная подкладка)
		local cape = capeWith(r, 2.1, 3.1, lv >= 4 and HW.Black or suitD, lv >= 3 and glow or nil)
		r:Box(cape, V(1.95, 1.6, 0.04), CF(0, 0, -0.08), HW.Burgundy, M.Fabric)
		for _, s in ipairs({ -1, 1 }) do
			r:Wedge(r.Torso, V(0.15, 0.9, 0.7), CF(0.9 * s, 1.35, 0.25) * ANG(0, PI, 0), HW.Burgundy, M.Fabric)
		end
		-- веер карт в правой руке (лицом вперёд при поднятой руке)
		local F = AIM
		local n = lv >= 3 and 5 or 3
		for k = 1, n do
			local a = rad((k - (n + 1) / 2) * 22)
			card(r, r.RArm, F * CF(0, 0.05, -0.4) * ANG(0, 0, -a) * CF(0, 0.42, -0.01 * k), 1.45,
				(k % 2 == 0) and HW.Black or HW.Red)
		end
		muzzle(r, r.RArm, F * CF(0, 0.05, -0.5))
		-- трость с кристаллом в левой руке
		local top = shaft(r, r.LArm, -2.3, 1.3, HW.Black, 0.14)
		r:Box(r.LArm, V(0.18, 0.12, 0.18), CF(top), HW.Gold, M.Metal)
		r:Neon(r.LArm, V(0.32, 0.32, 0.32), CF(top + V(0, 0.25, 0)) * ANG(rad(45), 0, rad(45)), glow)
		-- осколки зеркал
		if lv >= 4 then
			local hub = r:Orbit("OrbitMirrors", r.Torso, CF(0, 0.6, 0), 2.3, 0, 0.2, glow)
			for i = 0, (lv >= 5 and 5 or 3) - 1 do
				local cnt = lv >= 5 and 5 or 3
				local a = i / cnt * PI * 2
				local p = V(math.cos(a) * 2.3, math.sin(a * 3) * 0.25, math.sin(a) * 2.3)
				tri(r, hub, CF(p) * ANG(0, -a + PI / 2, 0), 0.5, 0.8, rgb(200, 190, 230), M.Foil, 0.06)
				r:Neon(hub, V(0.05, 0.4, 0.07), CF(p) * ANG(0, -a + PI / 2, 0), glow)
			end
		end
		if lv >= 5 then
			local hub2 = r:Orbit("OrbitCards", r.Head, CF(0, 1.9, 0), 1.2, 0, 0.2, glow)
			for i = 0, 3 do
				local a = i / 4 * PI * 2
				card(r, hub2, CF(math.cos(a) * 1.2, 0, math.sin(a) * 1.2) * ANG(0, -a, rad(20)), 0.9, HW.Red, i % 2 == 1)
			end
		end
		levelAura(r, lv, glow)
		return r:Finish(Config.Units.DarkIllusionist.Scale, { RS = { 60, 0, 10 }, LS = { 10, 0, -8 } })
	end

	------------------------------------------------------------------------
	-- 9. PUPPETEER (Mythic) — кукловод с крестовиной и красными нитями
	------------------------------------------------------------------------
	local function marionette(r, limb, cf, s, wood, head)
		Kit.bevel(r, limb, V(0.5, 0.6, 0.3) * s, cf, wood, false, M.Wood)
		r:Box(limb, V(0.4, 0.4, 0.4) * s, cf * CF(0, 0.55 * s, 0), head, M.Plastic)
		for _, x in ipairs({ -1, 1 }) do
			r:Neon(limb, V(0.06, 0.06, 0.04) * s, cf * CF(0.09 * s * x, 0.6 * s, -0.21 * s), HW.Red)
			r:Box(limb, V(0.14, 0.5, 0.14) * s, cf * CF(0.34 * s * x, 0, 0), wood, M.Wood)
			r:Box(limb, V(0.16, 0.5, 0.16) * s, cf * CF(0.14 * s * x, -0.58 * s, 0), wood, M.Wood)
		end
	end

	local function HalloweenPuppeteer(lv)
		local coat, coatD = rgb(26, 18, 26), rgb(16, 12, 18)
		local red = HW.Red
		local r = figure("HalloweenPuppeteer", { Torso = coat, Arm = coat, Leg = coatD, Skin = rgb(228, 222, 230), Edge = rgb(130, 70, 80) })
		local Hd = r.Head
		-- фарфоровая маска с трещиной и красной улыбкой
		r:Box(Hd, V(1.0, 1.0, 0.06), CF(0, -0.02, -0.62), rgb(236, 230, 236), M.Plastic)
		for _, s in ipairs({ -1, 1 }) do
			tri(r, Hd, CF(0.26 * s, 0.14, -0.66) * ANG(0, 0, PI), 0.24, 0.16, red, M.Neon, 0.04)
		end
		r:Box(Hd, V(0.5, 0.06, 0.04), CF(0, -0.27, -0.66), red, M.Neon)
		for _, s in ipairs({ -1, 1 }) do
			r:Box(Hd, V(0.06, 0.14, 0.04), CF(0.27 * s, -0.22, -0.66), red, M.Neon)
		end
		if lv >= 2 then
			Kit.crack(r, Hd, { V(-0.1, 0.45, -0.66), V(-0.22, 0.25, -0.66), V(-0.12, 0.05, -0.66) }, 0.04, rgb(60, 40, 50))
		end
		-- высокий цилиндр с красной лентой
		Kit.bevel(r, Hd, V(1.7, 0.1, 1.7), CF(0, 0.62, 0), HW.Black, false, M.Fabric)
		Kit.bevel(r, Hd, V(1.1, 1.4, 1.1), CF(0, 1.35, 0) * ANG(0, 0, rad(-5)), HW.Black, rgb(90, 50, 60), M.Fabric)
		r:Box(Hd, V(1.14, 0.18, 1.14), CF(0, 0.82, 0), lv >= 3 and red or HW.Burgundy, lv >= 3 and M.Neon or M.Fabric)
		-- длинный фрак до пола, высокий воротник
		robe(r, coat, HW.Burgundy, 2.0)
		Kit.bevel(r, r.Torso, V(2.14, 1.2, 1.14), CF(0, 0.4, 0), HW.Burgundy, rgb(130, 70, 80), M.Fabric)
		r:Box(r.Torso, V(0.5, 1.2, 0.06), CF(0, 0.4, -0.6), HW.Black, M.Fabric)
		for _, s in ipairs({ -1, 1 }) do
			r:Wedge(r.Torso, V(0.15, 1.1, 0.8), CF(0.95 * s, 1.45, 0.2) * ANG(0, PI, 0), coat, M.Fabric)
		end
		belt(r, HW.Black, HW.Gold, red)
		mantle(r, coatD, rgb(130, 70, 80))
		for _, A in ipairs({ r.RArm, r.LArm }) do
			Kit.bevel(r, A, V(1.06, 0.42, 1.06), CF(0, -0.8, 0), rgb(236, 232, 240), false, M.Plastic)
		end
		-- крестовина-вага в правой руке, нити вниз к марионетке
		local pose = { 70, 0, 18 }
		local dn = downIn(pose)
		local c = V(0, GRIP - 0.25, -0.1)
		local up = CFrame.lookAt(c, c + dn, V(0, 0, -1)) * ANG(-PI / 2, 0, 0) * ANG(PI, 0, 0)
		local wood = lv >= 4 and HW.Black or HW.Wood
		r:Box(r.RArm, V(1.7, 0.16, 0.16), up, wood, M.Wood)
		r:Box(r.RArm, V(0.16, 0.16, 1.3), up, wood, M.Wood)
		if lv >= 4 then
			for _, x in ipairs({ -0.85, 0.85 }) do
				r:Box(r.RArm, V(0.2, 0.2, 0.2), up * CF(x, 0, 0), HW.Gold, M.Metal)
			end
		end
		local ends = { V(-0.8, 0, 0), V(0.8, 0, 0), V(0, 0, -0.6), V(0, 0, 0.6) }
		local L = ({ 1.6, 1.8, 2.0, 2.0, 2.2 })[lv]
		for _, e in ipairs(ends) do
			local a = up * e
			thread(r, r.RArm, a, a + dn * L, red)
		end
		muzzle(r, r.RArm, CF(c + dn * L))
		if lv >= 3 then
			-- кукла на нитях
			local mc = c + dn * (L + 0.55)
			marionette(r, r.RArm, CFrame.lookAt(mc, mc + dn, V(0, 0, -1)) * ANG(-PI / 2, 0, 0) * ANG(PI, 0, 0), 1.2, HW.WoodLight, rgb(236, 230, 236))
		end
		-- левая рука: нити от пальцев
		local pose2 = { 55, 0, -20 }
		local dn2 = downIn(pose2)
		for k = -1, 1 do
			local a = V(k * 0.3, GRIP - 0.3, -0.1)
			thread(r, r.LArm, a, a + dn2 * (1.4 + math.abs(k) * 0.3), red)
		end
		if lv >= 5 then
			-- огромная катушка за спиной и куклы на орбите
			for _, y in ipairs({ -0.6, 0.6 }) do
				Kit.bevel(r, r.Torso, V(1.5, 0.2, 1.5), CF(0, 0.3 + y, 1.25) * ANG(0, PI / 4, 0), HW.Black, rgb(130, 70, 80))
			end
			r:Neon(r.Torso, V(1.1, 1.0, 1.1), CF(0, 0.3, 1.25), red)
			local hub = r:Orbit("OrbitPuppets", r.Torso, CF(0, -0.4, 0), 2.6, 0, 0.2, red)
			for i = 0, 2 do
				local a = i / 3 * PI * 2
				local p = CF(math.cos(a) * 2.6, 0, math.sin(a) * 2.6) * ANG(0, -a, 0)
				marionette(r, hub, p, 1.0, HW.WoodLight, rgb(236, 230, 236))
				thread(r, hub, p * V(0, 0.8, 0), p * V(0, 2.2, 0), red)
			end
		end
		if lv >= 4 then
			capeWith(r, 2.1, 3.4, HW.Burgundy, red)
		end
		levelAura(r, lv, red)
		return r:Finish(Config.Units.HalloweenPuppeteer.Scale, { RS = pose, LS = pose2 })
	end

	------------------------------------------------------------------------
	-- 10. HEADLESS EXECUTIONER (Mythic) — безголовый палач с огромным топором
	------------------------------------------------------------------------
	local function HeadlessExecutioner(lv)
		local leather, iron = rgb(50, 32, 28), rgb(54, 52, 60)
		local fire = HW.Orange
		local r = figure("HeadlessExecutioner", { Torso = rgb(70, 50, 44), Arm = rgb(110, 80, 70), Leg = rgb(36, 28, 30), Skin = rgb(70, 50, 44), Edge = HW.Edge })
		hideHeadBox(r)
		-- обрубок шеи: железный ворот, тлеющие угли и пламя
		Kit.bevel(r, r.Torso, V(1.3, 0.35, 1.0), CF(0, 1.12, 0), iron, HW.Edge)
		local ember = r:Neon(r.Torso, V(0.8, 0.12, 0.6), CF(0, 1.32, 0), fire)
		r:Box(r.Torso, V(0.5, 0.14, 0.4), CF(0, 1.36, 0), rgb(120, 30, 20), M.Plastic)
		for k = 0, 3 do
			local a = k / 4 * PI * 2 + 0.4
			Kit.spike(r, r.Torso, V(math.cos(a) * 0.25, 1.35, math.sin(a) * 0.2), V(math.cos(a) * 0.32, 1.75 + (k % 2) * 0.2, math.sin(a) * 0.25), 0.22, fire, M.Neon, true, 0.05)
		end
		if not lite() then
			local e = Instance.new("ParticleEmitter")
			e.Name = "NeckFire"
			e.Color = ColorSequence.new(rgb(255, 190, 80), rgb(255, 70, 20))
			e.LightEmission = 1
			e.LightInfluence = 0
			e.Rate = 14
			e.Lifetime = NumberRange.new(0.4, 0.8)
			e.Speed = NumberRange.new(1.5, 3)
			e.EmissionDirection = Enum.NormalId.Top
			e.SpreadAngle = Vector2.new(15, 15)
			e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
			e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
			e.Parent = ember
		end
		r:Glow(ember, fire, 10, 1.6)
		-- кожаный нагрудник с ремнями, голые руки с наручами
		Kit.bevel(r, r.Torso, V(2.14, 2.0, 1.14), CF(), leather, HW.Edge, M.Fabric)
		Kit.bar(r, r.Torso, V(-0.9, 0.95, -0.6), V(0.9, -0.7, -0.6), V2(0.22, 0.07), rgb(30, 22, 20))
		Kit.bar(r, r.Torso, V(0.9, 0.95, -0.6), V(-0.9, -0.7, -0.6), V2(0.22, 0.07), rgb(30, 22, 20))
		r:Box(r.Torso, V(0.3, 0.3, 0.08), CF(0, 0.12, -0.64) * ANG(0, 0, rad(45)), HW.Iron, M.Metal)
		belt(r, rgb(30, 22, 20), HW.Gold, lv >= 3 and fire or nil)
		H.tassets(r, leather, HW.Edge)
		H.bracers(r, iron, HW.Edge)
		H.greaves(r, iron, HW.Edge, true)
		if lv >= 2 then
			H.bigShoulders(r, iron, HW.Edge, lv >= 4 and fire or nil, lv >= 4 and 1.15 or 1.0, lv >= 3 and 2 or 1)
		end
		-- капюшон палача висит на поясе
		Kit.bevel(r, r.Torso, V(0.75, 0.85, 0.5), CF(-1.0, -1.3, -0.25), HW.Black, false, M.Fabric)
		for _, s in ipairs({ -1, 1 }) do
			r:Box(r.Torso, V(0.14, 0.1, 0.05), CF(-1.0 + 0.17 * s, -1.2, -0.52), lv >= 3 and fire or rgb(60, 20, 20), lv >= 3 and M.Neon or M.Plastic)
		end
		-- цепи
		if lv >= 3 then
			Kit.chain(r, r.LArm, 4, 0.26, HW.Iron, CF(0.55, -0.2, 0))
			Kit.chain(r, r.Torso, 3, 0.24, HW.Iron, CF(0.9, -0.95, -0.4))
		end
		-- огромный топор палача: длинная рукоять, широкое лезвие-полумесяц
		local top = shaft(r, r.RArm, -2.8, 2.6, lv >= 4 and HW.Black or HW.Wood, 0.26)
		Kit.bevel(r, r.RArm, V(0.36, 0.25, 0.36), CF(V(0, -2.8, -0.5)), iron, false)
		local R = ({ 1.3, 1.4, 1.5, 1.7, 1.9 })[lv]
		local c = top + V(0, -0.4, -0.3)
		local bladeC = lv >= 5 and rgb(30, 26, 32) or iron
		local prev
		for k = 0, 6 do
			local phi = rad(-70 + k * 23.3)
			local dir = V(0, math.sin(phi), -math.cos(phi))
			Kit.bar(r, r.RArm, c + dir * 0.25, c + dir * R, V2(0.14, 2 * R * math.sin(rad(11.7)) + 0.1), bladeC, M.Metal)
			local rim = c + dir * (R * 0.94)
			if prev and lv >= 2 then
				Kit.bar(r, r.RArm, prev, rim, V2(0.16, 0.08), fire, M.Neon)
			end
			prev = rim
		end
		Kit.bevel(r, r.RArm, V(0.3, 0.6, 0.6), CF(top + V(0, -0.4, 0)), iron, HW.Edge)
		Kit.spike(r, r.RArm, top + V(0, -0.4, 0.2), top + V(0, -0.4, 0.8), 0.45, iron, M.Metal, true, 0.12)
		if lv >= 4 then
			Kit.crack(r, r.RArm, { c + V(0.08, 0.4, -0.5), c + V(0.08, 0.1, -0.8), c + V(0.08, -0.2, -0.6) }, 0.07, fire)
		end
		r:WeaponTrail(r.RArm, c + V(0, 0, -0.5), c + V(0, 0, -R), fire)
		muzzle(r, r.RArm, CF(c + V(0, 0, -R)))
		if lv >= 5 then
			capeWith(r, 2.2, 3.4, HW.BurgDark, fire)
			r:Orbit("OrbitEmbers", r.Torso, CF(0, 0.2, 0), 2.4, 5, 0.32, fire)
			embers(r, ember, fire, 10, 0.3)
		end
		levelAura(r, lv, fire)
		return r:Finish(Config.Units.HeadlessExecutioner.Scale, { RS = { 25, 0, 0 }, LS = { 20, 0, -8 } })
	end

	------------------------------------------------------------------------
	-- 11. LANTERN KING (Secret) — Король фонарей
	------------------------------------------------------------------------
	local function LanternKing(lv)
		local robeC, robeD = rgb(44, 20, 60), rgb(26, 12, 38)
		local fire = HW.Orange
		local r = figure("LanternKing", { Torso = robeC, Arm = robeC, Leg = robeD, Skin = HW.Pumpkin, Edge = HW.GoldDark })
		hideHeadBox(r)
		local Hd = r.Head
		-- тыквенная голова с вырезанным светящимся лицом
		pumpkin(r, Hd, CF(0, 0.12, 0), 0.92, 1.45, HW.Pumpkin, HW.PumpkinDark, lv >= 5 and rgb(255, 220, 120) or rgb(255, 170, 50))
		local inner = r:Neon(Hd, V(0.9, 0.9, 0.9), CF(0, 0.12, 0), rgb(255, 120, 20), { Transparency = 0.2 })
		r:Glow(inner, fire, 12, 1.8)
		-- корона
		kingCrown(r, Hd, CF(0, 0.82, 0), 0.62, lv >= 2 and 0.85 or 0.65, HW.Gold, lv >= 2 and fire or nil, 8)
		-- королевская мантия
		robe(r, robeD, HW.Gold, 2.0)
		Kit.bevel(r, r.Torso, V(2.14, 2.0, 1.14), CF(), robeC, HW.GoldDark, M.Fabric)
		r:Box(r.Torso, V(0.4, 2.0, 0.06), CF(0, 0, -0.58), HW.Gold, M.Fabric)
		Kit.gem(r, r.Torso, 0.4, CF(0, 0.45, -0.64), fire, HW.Gold)
		belt(r, HW.Black, HW.Gold, fire)
		-- меховой воротник (оранжево-чёрный)
		Kit.bevel(r, r.Torso, V(2.5, 0.45, 1.4), CF(0, 0.92, 0), HW.Black, HW.PumpkinDark, M.Fabric)
		for k = -2, 2 do
			r:Box(r.Torso, V(0.3, 0.2, 0.06), CF(k * 0.45, 0.92, -0.71), HW.PumpkinDark, M.Fabric)
		end
		if lv >= 4 then
			H.bigShoulders(r, HW.Gold, HW.GoldDark, fire, 1.0, 1)
		else
			mantle(r, robeC, HW.GoldDark)
		end
		for _, A in ipairs({ r.RArm, r.LArm }) do
			Kit.bevel(r, A, V(1.08, 0.45, 1.08), CF(0, -0.75, 0), HW.Gold, false)
		end
		-- плащ
		capeWith(r, 2.2, lv >= 3 and 3.6 or 3.2, lv >= 3 and HW.Burgundy or robeD, fire)
		-- посох-фонарь
		local top = shaft(r, r.RArm, -2.6, 2.4, HW.Black, 0.22)
		for _, y in ipairs({ -1.6, 0.4, 1.6 }) do
			Kit.bevel(r, r.RArm, V(0.34, 0.14, 0.34), CF(0, y, -0.5), HW.Gold, false)
		end
		-- крюк и фонарь
		local hook = { top, top + V(0, 0.5, -0.1), top + V(0, 0.7, -0.5), top + V(0, 0.5, -0.85) }
		for i = 1, 3 do
			Kit.bar(r, r.RArm, hook[i], hook[i + 1], V2(0.14, 0.14), HW.Gold, M.Metal)
		end
		local s = ({ 1.0, 1.1, 1.2, 1.3, 1.45 })[lv]
		local lc = hook[4] + V(0, -0.85 * s, 0)
		local flame = lantern(r, r.RArm, CF(lc), s, HW.Gold, rgb(255, 160, 40), rgb(255, 140, 50))
		-- в фонаре — маленькая тыква
		pumpkin(r, r.RArm, CF(lc + V(0, -0.02 * s, 0)), 0.16 * s, 0.24 * s, HW.Pumpkin, HW.PumpkinDark, nil, { Cheap = true })
		embers(r, flame, fire, lv >= 4 and 10 or 5, 0.22)
		muzzle(r, r.RArm, CF(lc))
		-- огненные тыквы на орбите
		if lv >= 3 then
			local hub = r:Orbit("OrbitPumpkins", r.Torso, CF(0, 1.2, 0), 2.6, 0, 0.2, fire)
			local n = lv >= 5 and 4 or 2
			for i = 0, n - 1 do
				local a = i / n * PI * 2
				local p = CF(math.cos(a) * 2.6, math.sin(a * 2) * 0.3, math.sin(a) * 2.6) * ANG(0, -a - PI / 2, 0)
				pumpkin(r, hub, p, 0.38, 0.55, HW.Pumpkin, HW.PumpkinDark, rgb(255, 190, 70), { Cheap = true })
			end
		end
		if lv >= 5 then
			embers(r, r.Torso, fire, 12, 0.3)
		end
		levelAura(r, lv, fire)
		return r:Finish(Config.Units.LanternKing.Scale, { RS = { 22, 0, 0 }, LS = { 12, 0, -10 } })
	end

	UnitModels.Register("NightWatchman", NightWatchman, "Common")
	UnitModels.Register("Gravedigger", Gravedigger, "Rare")
	UnitModels.Register("CursedScarecrow", CursedScarecrow, "Rare")
	UnitModels.Register("CursedSheriff", CursedSheriff, "Epic")
	UnitModels.Register("MidnightBellringer", MidnightBellringer, "Epic")
	UnitModels.Register("PlagueDoctor", PlagueDoctor, "Legendary")
	UnitModels.Register("PhantomKnight", PhantomKnight, "Legendary")
	UnitModels.Register("DarkIllusionist", DarkIllusionist, "Legendary")
	UnitModels.Register("HalloweenPuppeteer", HalloweenPuppeteer, "Mythic")
	UnitModels.Register("HeadlessExecutioner", HeadlessExecutioner, "Mythic")
	UnitModels.Register("LanternKing", LanternKing, "Secret")

	------------------------------------------------------------------------
	-- СОЮЗНИКИ (призывы). Лёгкие R6-фигуры: до ~60 деталей
	------------------------------------------------------------------------
	local function plain(r, limb, size, cf, color, mat)
		return r:Box(limb, size, cf, color, mat or M.Plastic)
	end

	-- Иллюзии: тёмно-фиолетовые, полупрозрачные, карты и зеркала
	local function Illusion(id, tier)
		local body = tier == 1 and rgb(16, 10, 24) or rgb(40, 22, 64)
		local edge = rgb(170, 120, 230)
		local glow = HW.Violet
		local r = figure(id, { Torso = body, Arm = body, Leg = body, Skin = tier == 1 and rgb(16, 10, 24) or rgb(70, 40, 100), Edge = edge })
		eyes(r, glow, true, 0.08)
		local glassC = rgb(150, 100, 220)
		if tier == 1 then
			-- теневой двойник: чёрный силуэт в дымке
			for _, L in ipairs({ r.Torso, r.RArm, r.LArm, r.RLeg, r.LLeg }) do
				plain(r, L, L.Size + V(0.06, 0.06, 0.06), CF(), glassC, M.Glass).Transparency = 0.7
			end
			H.hood(r, body, edge, glow, true)
		elseif tier == 2 then
			-- карточный солдат: тело — карта, копьё-пика
			plain(r, r.Torso, V(2.0, 2.6, 0.12), CF(0, -0.2, -0.58), rgb(236, 232, 240))
			plain(r, r.Torso, V(1.7, 2.3, 0.13), CF(0, -0.2, -0.58), HW.Red).Transparency = 0.85
			for _, y in ipairs({ 0.6, -1.0 }) do
				plain(r, r.Torso, V(0.4, 0.4, 0.14), CF(0, y, -0.6) * ANG(0, 0, rad(45)), HW.Red)
			end
			Kit.bevel(r, r.Head, V(1.3, 0.3, 1.3), CF(0, 0.65, 0), HW.Red, false)
			for k = -1, 1 do
				Kit.spike(r, r.Head, V(k * 0.4, 0.75, 0), V(k * 0.4, 1.15, 0), 0.3, HW.Gold, M.Metal, true, 0.08)
			end
			local top = shaft(r, r.RArm, -2.2, 2.0, HW.Black, 0.16)
			Kit.spike(r, r.RArm, top, top + V(0, 0.8, 0), 0.5, HW.Red, M.Plastic, true, 0.1)
		elseif tier == 3 then
			-- зеркальный рыцарь: блестящая броня, зеркальный щит
			H.helm(r, rgb(170, 160, 200), edge, glow, nil, false)
			Kit.bevel(r, r.Torso, V(2.14, 1.1, 1.16), CF(0, 0.45, 0), rgb(170, 160, 200), edge, M.Foil)
			H.plateShoulders(r, rgb(170, 160, 200), edge)
			Kit.bevel(r, r.LArm, V(0.2, 2.0, 1.4), CF(-0.65, -0.6, -0.1), rgb(200, 190, 230), glow, M.Foil)
			plain(r, r.LArm, V(0.22, 1.6, 1.0), CF(-0.66, -0.6, -0.1), glassC, M.Glass).Transparency = 0.4
			H.blade(r, r.RArm, { Len = 2.2, W = 0.4, Blade = rgb(200, 190, 230), Guard = body, Glow = glow })
		elseif tier == 4 then
			-- фантомный маг: капюшон, мантия, посох со сферой
			H.hood(r, rgb(60, 30, 96), edge, glow, true)
			robe(r, rgb(46, 24, 76), edge, 1.7)
			local top = shaft(r, r.RArm, -2.4, 1.9, HW.Black, 0.16)
			r:Neon(r.RArm, V(0.5, 0.5, 0.5), CF(top + V(0, 0.35, 0)) * ANG(rad(45), 0, rad(45)), glow)
			plain(r, r.RArm, V(0.75, 0.75, 0.75), CF(top + V(0, 0.35, 0)) * ANG(rad(45), 0, rad(45)), glassC, M.Glass).Transparency = 0.6
		else
			-- королевская иллюзия: корона, плащ, двойные клинки
			kingCrown(r, r.Head, CF(0, 0.6, 0), 0.66, 0.6, rgb(200, 170, 240), glow, 4)
			Kit.bevel(r, r.Torso, V(2.14, 1.1, 1.16), CF(0, 0.45, 0), rgb(90, 50, 140), HW.Gold, M.Foil)
			H.plateShoulders(r, rgb(90, 50, 140), HW.Gold)
			r:Cape(1.9, 2.6, rgb(60, 30, 96), false)
			H.blade(r, r.RArm, { Len = 2.4, W = 0.45, Blade = rgb(200, 190, 230), Guard = HW.Gold, Glow = glow })
			H.blade(r, r.LArm, { Len = 2.0, W = 0.4, Blade = rgb(200, 190, 230), Guard = HW.Gold, Glow = glow })
		end
		return r, glow
	end

	-- Куклы: деревянные шарниры, нити сверху
	local function Puppet(id, tier)
		local golden = id == "GoldenMarionette"
		local wood = golden and HW.Gold or ({ HW.WoodLight, rgb(236, 230, 236), HW.Iron, rgb(40, 30, 36), rgb(90, 40, 60) })[tier]
		local edge = golden and rgb(255, 230, 150) or ({ HW.Wood, rgb(190, 180, 196), HW.Edge, rgb(130, 70, 80), HW.Gold })[tier]
		local r = figure(id, { Torso = wood, Arm = wood, Leg = wood, Skin = (tier == 2 or tier == 1) and rgb(236, 230, 236) or wood, Edge = edge })
		-- лицо-маска с глазами-пуговицами
		for _, s in ipairs({ -1, 1 }) do
			r:Box(r.Head, V(0.24, 0.24, 0.05), CF(0.26 * s, 0.1, -0.62) * ANG(0, 0, rad(45)), HW.Black, M.Plastic)
			r:Neon(r.Head, V(0.08, 0.08, 0.04), CF(0.26 * s, 0.1, -0.65), golden and HW.Orange or HW.Red)
		end
		r:Box(r.Head, V(0.5, 0.05, 0.04), CF(0, -0.3, -0.62), golden and HW.GoldDark or HW.Red, golden and M.Metal or M.Neon)
		-- шарниры (суставы на плечах, бёдрах и шее)
		local joint = golden and HW.GoldDark or (tier == 1 and HW.Wood or rgb(60, 50, 56))
		for _, p in ipairs({ V(1.0, 0.7, 0), V(-1.0, 0.7, 0), V(0.5, -1.0, 0), V(-0.5, -1.0, 0), V(0, 1.0, 0) }) do
			plain(r, r.Torso, V(0.45, 0.45, 0.45), CF(p) * ANG(rad(45), 0, rad(45)), joint, M.Metal)
		end
		for _, A in ipairs({ r.RArm, r.LArm, r.RLeg, r.LLeg }) do
			plain(r, A, V(1.06, 0.12, 1.06), CF(0, 0, 0), joint, M.Metal)
		end
		if tier == 2 and not golden then
			-- фарфоровая кукла: платье и трещины
			Kit.bevel(r, r.Torso, V(2.3, 1.4, 1.3), CF(0, -1.1, 0), rgb(110, 30, 60), false, M.Fabric)
			Kit.crack(r, r.Head, { V(0.2, 0.5, -0.62), V(0.35, 0.2, -0.62), V(0.25, -0.05, -0.62) }, 0.04, rgb(60, 50, 60))
			Kit.bevel(r, r.Head, V(1.3, 0.35, 1.3), CF(0, 0.55, 0.05), rgb(60, 30, 20), false, M.Fabric)
		elseif tier >= 3 or golden then
			-- броня
			Kit.bevel(r, r.Torso, V(2.14, 1.1, 1.16), CF(0, 0.45, 0), golden and HW.Gold or (tier == 3 and HW.Iron or rgb(60, 40, 50)), edge, golden and M.Foil or M.Metal)
			H.plateShoulders(r, golden and HW.Gold or (tier == 3 and HW.Iron or rgb(60, 40, 50)), edge)
		end
		if tier >= 4 or golden then
			H.blade(r, r.RArm, { Len = tier >= 5 and 2.6 or 2.2, W = 0.45, Blade = golden and HW.Gold or HW.Iron, Guard = edge, Glow = golden and HW.Orange or HW.Red })
		elseif tier == 3 then
			H.shield(r, r.LArm, { Color = HW.Iron, Edge = edge, H = 1.6, W = 1.1 })
		end
		if tier >= 5 or golden then
			kingCrown(r, r.Head, CF(0, 0.6, 0), 0.66, 0.55, HW.Gold, golden and HW.Orange or HW.Red, 4)
			r:Cape(1.8, 2.4, golden and HW.Gold or HW.Burgundy, false)
		end
		-- нити кукловода над головой и руками
		local red = golden and rgb(255, 210, 120) or HW.Red
		thread(r, r.Head, V(0, 0.6, 0), V(0, 3.2, 0), red, 0.04)
		for _, A in ipairs({ r.RArm, r.LArm }) do
			thread(r, A, V(0, 1, 0), V(0, 3.4, 0), red, 0.035)
		end
		return r, red
	end

	-- Проклятые люди: красно-чёрные, светящиеся красные глаза
	local function Cursed(id, tier)
		local cloth = ({ rgb(70, 54, 50), rgb(30, 24, 30), rgb(40, 36, 44), rgb(110, 24, 36), rgb(24, 18, 22) })[tier]
		local edge = rgb(140, 70, 70)
		local glow = HW.Red
		local r = figure(id, { Torso = cloth, Arm = tier == 1 and rgb(150, 140, 142) or cloth, Leg = rgb(30, 24, 28), Skin = rgb(160, 150, 150), Edge = edge })
		eyes(r, glow, true, 0.08)
		if tier == 1 then
			-- рваная одежда, бледная кожа, красные трещины
			Kit.tatter(r, r.Torso, -1.0, -0.56, 2.0, 4, cloth, M.Fabric, 1)
			Kit.crack(r, r.Torso, { V(-0.4, 0.6, -0.52), V(-0.1, 0.2, -0.52), V(-0.3, -0.3, -0.52) }, 0.06, glow)
			Kit.crack(r, r.Head, { V(0.3, 0.5, -0.61), V(0.15, 0.25, -0.61) }, 0.05, glow)
		elseif tier == 2 then
			H.hood(r, cloth, edge, glow, false)
			Kit.bevel(r, r.Torso, V(2.14, 1.1, 1.16), CF(0, 0.45, 0), rgb(50, 40, 50), edge)
			local top = shaft(r, r.RArm, -2.4, 2.2, HW.Black, 0.16)
			Kit.spike(r, r.RArm, top, top + V(0, 0.9, 0), 0.4, HW.Iron, M.Metal)
		elseif tier == 3 then
			H.helm(r, rgb(60, 50, 60), edge, glow, nil, false)
			Kit.bevel(r, r.Torso, V(2.14, 1.1, 1.16), CF(0, 0.45, 0), rgb(60, 50, 60), edge)
			H.plateShoulders(r, rgb(60, 50, 60), edge)
			H.shield(r, r.LArm, { Color = rgb(60, 20, 30), Edge = edge, H = 1.8, W = 1.2, Gem = glow })
			H.blade(r, r.RArm, { Len = 1.8, W = 0.4, Blade = HW.Iron, Guard = rgb(60, 50, 60) })
		elseif tier == 4 then
			Kit.bevel(r, r.Head, V(1.32, 0.5, 1.34), CF(0, 0.45, 0), rgb(130, 30, 44), edge)
			Kit.bevel(r, r.Torso, V(2.14, 1.1, 1.16), CF(0, 0.45, 0), rgb(130, 30, 44), edge)
			H.plateShoulders(r, rgb(130, 30, 44), edge)
			H.axe(r, r.RArm, { Head = HW.Iron, Edge = edge, Glow = glow, Wood = HW.Black })
		else
			H.helm(r, rgb(30, 22, 26), edge, glow, rgb(130, 30, 44), true)
			Kit.bevel(r, r.Torso, V(2.14, 1.1, 1.16), CF(0, 0.45, 0), rgb(30, 22, 26), edge)
			H.bigShoulders(r, rgb(30, 22, 26), edge, glow, 0.9, 1)
			r:Cape(1.8, 2.6, rgb(90, 18, 30), false)
			H.blade(r, r.RArm, { Len = 2.6, W = 0.5, Blade = rgb(40, 34, 40), Guard = rgb(30, 22, 26), Glow = glow })
		end
		return r, glow
	end

	local ALLY_FAMILY = { Illusion = Illusion, Puppet = Puppet, Cursed = Cursed }

	function UnitModels.BuildAlly(allyId)
		local def = Config.Allies[allyId]
		if not def then
			error("Unknown ally " .. tostring(allyId))
		end
		local builder = ALLY_FAMILY[def.Family]
		-- союзники ходят группами: дешёвая фаска (2 детали), без частиц и шлейфов
		Kit.Cheap = true
		local ok, r, glow = pcall(builder, allyId, def.Tier)
		Kit.Cheap = false
		if not ok then
			error(r)
		end
		local scale = allyId == "GoldenMarionette" and 1.3 or (0.82 + 0.06 * math.min(def.Tier, 5))
		local rig = r:Finish(scale, {})
		for _, d in ipairs(rig.Model:GetDescendants()) do
			if d:IsA("Trail") or d:IsA("ParticleEmitter") or d:IsA("PointLight") then
				d:Destroy()
			end
		end
		if not UnitModels.Lite and glow then
			-- одна подсветка вместо частиц
			local l = Instance.new("PointLight")
			l.Color = glow
			l.Range = 6
			l.Brightness = 0.8
			l.Shadows = false
			l.Parent = rig.Torso
		end
		Kit.Calm(rig.Model)
		for _, d in ipairs(rig.Model:GetDescendants()) do
			if d:IsA("BasePart") then
				d.CanQuery = false
				d.CanTouch = false
				d.CastShadow = false
			end
		end
		rig.Model.Name = allyId
		rig.Model:SetAttribute("AllyId", allyId)
		rig.AllyId = allyId
		return rig
	end

	------------------------------------------------------------------------
	-- РУНЫ (3D-иконки)
	------------------------------------------------------------------------
	local function rpart(m, size, cf, color, mat, props)
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = false
		p.CastShadow = false
		p.Size = size
		p.CFrame = cf
		p.Color = color
		p.Material = mat or M.Plastic
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		if props then
			for k, v in pairs(props) do
				p[k] = v
			end
		end
		p.Parent = m
		return p
	end

	local function rwedge(m, size, cf, color, mat, props)
		local w = Instance.new("WedgePart")
		w.Anchored = true
		w.CanCollide = false
		w.CanTouch = false
		w.CanQuery = false
		w.CastShadow = false
		w.Size = size
		w.CFrame = cf
		w.Color = color
		w.Material = mat or M.Plastic
		if props then
			for k, v in pairs(props) do
				w[k] = v
			end
		end
		w.Parent = m
		return w
	end

	local function rlight(part, color, range)
		local l = Instance.new("PointLight")
		l.Color = color
		l.Range = range or 8
		l.Brightness = 1.4
		l.Shadows = false
		l.Parent = part
	end

	-- Сердце фонаря: оранжевое сердце в золотой клетке-фонаре
	local function LanternHeartRune(m)
		local gold, orange = HW.Gold, HW.Orange
		-- сердце: ромб + две «доли» сверху
		local core = rpart(m, V(1.0, 1.0, 0.5), CF(0, -0.15, 0) * ANG(0, 0, rad(45)), orange, M.Neon)
		for _, s in ipairs({ -1, 1 }) do
			rpart(m, V(0.5, 0.72, 0.72), CF(0.36 * s, 0.32, 0) * ANG(0, PI / 2, 0), orange, M.Neon, { Shape = Enum.PartType.Cylinder })
		end
		rpart(m, V(1.6, 1.8, 0.8), CF(0, 0.05, 0), rgb(255, 170, 70), M.Glass, { Transparency = 0.6 })
		-- клетка
		for _, x in ipairs({ -1, 1 }) do
			for _, z in ipairs({ -1, 1 }) do
				rpart(m, V(0.12, 2.0, 0.12), CF(0.85 * x, 0.05, 0.45 * z), gold, M.Metal)
			end
		end
		rpart(m, V(1.95, 0.22, 1.1), CF(0, 1.1, 0), gold, M.Metal)
		rpart(m, V(1.95, 0.22, 1.1), CF(0, -1.0, 0), gold, M.Metal)
		rpart(m, V(1.2, 0.2, 0.8), CF(0, 1.3, 0), HW.GoldDark, M.Metal)
		rpart(m, V(0.12, 0.5, 0.5), CF(0, 1.6, 0), gold, M.Metal)
		rpart(m, V(0.12, 0.12, 0.5), CF(0, 1.85, 0), gold, M.Metal)
		rwedge(m, V(1.2, 0.25, 0.5), CF(0, -1.25, 0) * ANG(PI, 0, 0), HW.GoldDark, M.Metal)
		rlight(core, orange, 9)
		return core
	end

	-- Проклятые нити: катушка с красной нитью и игла
	local function CursedThreadsRune(m)
		local red = HW.Red
		for _, y in ipairs({ -0.75, 0.75 }) do
			for k = 0, 3 do
				rpart(m, V(1.6, 0.22, 0.66), CF(0, y, 0) * ANG(0, k * PI / 4, 0), HW.BurgDark, M.Wood)
			end
			rpart(m, V(1.7, 0.08, 0.3), CF(0, y + (y > 0 and 0.12 or -0.12), 0), HW.Gold, M.Metal)
		end
		rpart(m, V(0.5, 1.4, 0.5), CF(), HW.Wood, M.Wood)
		local core
		for k = 0, 4 do
			local p = rpart(m, V(1.12, 0.22, 1.12), CF(0, -0.48 + k * 0.24, 0) * ANG(0, k * 0.3, 0), red, M.Neon)
			core = core or p
		end
		-- свисающая нить
		rpart(m, V(0.05, 1.0, 0.05), CF(0.58, -0.9, -0.3) * ANG(0, 0, rad(10)), red, M.Neon)
		rpart(m, V(0.05, 0.6, 0.05), CF(0.45, -1.5, -0.3) * ANG(0, 0, rad(-25)), red, M.Neon)
		-- игла насквозь
		rpart(m, V(0.09, 2.6, 0.09), CF(0.2, 0.25, -0.1) * ANG(rad(10), 0, rad(-35)), rgb(210, 214, 226), M.Metal)
		rpart(m, V(0.16, 0.26, 0.05), CF(0.2, 0.25, -0.1) * ANG(rad(10), 0, rad(-35)) * CF(0, 1.2, 0), rgb(210, 214, 226), M.Metal)
		rlight(core, red, 8)
		return core
	end

	-- Призрачная корона: прозрачная синяя корона
	local function PhantomCrownRune(m)
		local ghost, edge = HW.Ghost, rgb(200, 235, 255)
		local R = 0.9
		local w = 2 * R * math.tan(rad(22.5)) * 1.1
		for k = 0, 7 do
			local a = k * PI / 4
			rpart(m, V(w, 0.5, 0.16), CF(math.sin(a) * R, -0.4, -math.cos(a) * R) * ANG(0, -a, 0), ghost, M.Glass, { Transparency = 0.3 })
			rpart(m, V(w, 0.08, 0.18), CF(math.sin(a) * R, -0.68, -math.cos(a) * R) * ANG(0, -a, 0), edge, M.Neon)
			local hh = (k % 2 == 0) and 1.2 or 0.8
			local p = V(math.sin(a) * R, -0.15 + hh / 2, -math.cos(a) * R)
			local F = CF(p) * ANG(0, -a, 0)
			rwedge(m, V(0.12, hh, w / 2), F * ANG(0, PI / 2, 0) * CF(0, 0, -w / 4), ghost, M.Glass, { Transparency = 0.25 })
			rwedge(m, V(0.12, hh, w / 2), F * ANG(0, PI / 2, 0) * CF(0, 0, w / 4) * ANG(0, PI, 0), ghost, M.Glass, { Transparency = 0.25 })
		end
		local core = rpart(m, V(0.36, 0.36, 0.14), CF(0, -0.4, -R - 0.1) * ANG(0, 0, rad(45)), edge, M.Neon)
		for _, s in ipairs({ -1, 1 }) do
			rpart(m, V(0.24, 0.24, 0.14), CF(R * 0.71 * s, -0.4, -R * 0.71 - 0.08) * ANG(0, rad(-45 * s), rad(45)), ghost, M.Neon)
		end
		rpart(m, V(1.2, 0.6, 1.2), CF(0, 0.15, 0), ghost, M.Neon, { Transparency = 0.75 })
		rlight(core, ghost, 9)
		return core
	end

	local RUNES = { LanternHeart = LanternHeartRune, CursedThreads = CursedThreadsRune, PhantomCrown = PhantomCrownRune }

	function UnitModels.BuildRune(runeId)
		local builder = RUNES[runeId]
		if not builder then
			error("Unknown rune " .. tostring(runeId))
		end
		local m = Instance.new("Model")
		m.Name = "Rune_" .. runeId
		local core = builder(m)
		m.PrimaryPart = core
		m.WorldPivot = CF()
		Kit.Calm(m, 0.2)
		return { Model = m, Core = core }
	end
end
