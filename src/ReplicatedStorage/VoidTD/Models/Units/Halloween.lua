--!nocheck
-- VOID TD :: Models/Units/Halloween
-- 11 юнитов события «Хэллоуин» в угловатом R6-стиле: у каждого предмет/оружие в руке, 5 заметно разных
-- уровней, Muzzle на острие/огне оружия, вращающиеся детали на моторах Orbit*.
-- Подключается из Models/Units: return function(UnitModels, Kit, Parts) — регистрирует строителей
-- UnitModels.Register(id, builder(lv, id) -> rig, rarity). Тыквы, фонари, короны, вороны, колокола, карты,
-- нити — общие детали Parts (раздел ХЭЛЛОУИН). Масштаб — Config.Units[id].Scale (UnitModels.Scale).
--
-- Моторы: Root Neck RS LS RH LH, Cape/Cape2 (плащи), OrbitCrows OrbitGhostClock OrbitClocks OrbitFlasks
-- OrbitSwords OrbitMirrors OrbitCards OrbitPuppets OrbitEmbers OrbitPumpkins. Частицы: PoisonMist (Чумной доктор),
-- GhostMist (Призрачный рыцарь), NeckFire (Безголовый палач) — не создаются в Lite.

return function(UnitModels, Kit, Parts)
	local V, V2, CF, ANG = Vector3.new, Vector2.new, CFrame.new, CFrame.Angles
	local rad, PI = math.rad, math.pi

	local M, HW, rgb = Parts.M, Parts.HW, Parts.rgb
	local GRIP, AIM = Parts.GRIP, Parts.AIM
	local bevel, spike, bar = Kit.bevel, Kit.spike, Kit.bar
	local figure, eyes, belt, robe, mantle = Parts.figure, Parts.eyes, Parts.belt, Parts.robe, Parts.mantle
	local muzzle, shaft, capeWith, levelAura = Parts.muzzle, Parts.shaft, Parts.capeWith, Parts.levelAura
	local tri, downIn, pumpkin, lantern = Parts.tri, Parts.downIn, Parts.pumpkin, Parts.lantern
	local brimHat, crow, star, flask = Parts.brimHat, Parts.crow, Parts.star, Parts.flask
	local bell, card, thread, embers = Parts.bell, Parts.card, Parts.thread, Parts.embers

	local SIDES = { -1, 1 }
	local WHITE = rgb(236, 232, 240) -- перчатки, манишки
	local PORCELAIN = rgb(236, 230, 236)
	local POTION = rgb(200, 80, 255) -- фиолетовое зелье (вторая склянка)

	------------------------------------------------------------------------
	-- ОБЩЕЕ
	------------------------------------------------------------------------
	local function finish(r, id, idle)
		return r:Finish(UnitModels.Scale(id), idle)
	end

	-- Рамка висящего предмета в точке at: +Y — вверх по миру (dn — «вниз» в координатах руки, Parts.downIn)
	local function hang(at, dn)
		return CFrame.lookAt(at, at + dn, V(0, 0, -1)) * ANG(-PI / 2, 0, 0) * ANG(PI, 0, 0)
	end

	-- Пустой узел-орбита (крутится по Y в Anims); содержимое добавляет строитель
	local function orbitHub(r, name, limb, offset)
		return r:Orbit(name, limb, offset, 0, 0, 0.2)
	end

	-- Угол и точка i-го из n предметов на окружности радиуса R
	local function around(i, n, R, y)
		local a = i / n * PI * 2
		return a, V(math.cos(a) * R, y or 0, math.sin(a) * R)
	end

	-- Манжеты/перчатки на обе руки
	local function cuffs(r, size, y, color, mat)
		for _, A in ipairs({ r.RArm, r.LArm }) do
			bevel(r, A, size, CF(0, y, 0), color, false, mat)
		end
	end

	local function seq(a, b)
		return NumberSequence.new({ NumberSequenceKeypoint.new(0, a), NumberSequenceKeypoint.new(1, b) })
	end

	-- Собственные частицы юнита (дымка, огонь); в Lite не создаются
	local function emitter(parent, name, props)
		if Kit.IsLite() then
			return nil
		end
		local e = Instance.new("ParticleEmitter")
		e.Name = name
		for k, v in pairs(props) do
			e[k] = v
		end
		e.Parent = parent
		return e
	end

	------------------------------------------------------------------------
	-- 1. NIGHT WATCHMAN (Common) — ночной сторож с фонарём
	------------------------------------------------------------------------
	local function NightWatchman(lv, id)
		local coat, coatD = rgb(40, 44, 66), rgb(28, 30, 46)
		local r = figure(id, { Torso = coat, Arm = coat, Leg = coatD, Skin = rgb(206, 178, 156), Edge = HW.EdgeCool })
		local T, Hd, A = r.Torso, r.Head, r.RArm
		-- лицо: тёмные глаза, рот, седые бакенбарды; котелок (лента с 2-го)
		eyes(r, rgb(30, 22, 18), false, 0.06)
		r:Box(Hd, V(0.5, 0.08, 0.05), CF(0, -0.3, -0.62), rgb(90, 60, 50))
		for _, s in ipairs(SIDES) do
			r:Box(Hd, V(0.12, 0.5, 0.5), CF(0.62 * s, -0.2, -0.1), rgb(150, 146, 150), M.Fabric)
		end
		brimHat(r, HW.Coal, lv >= 2 and HW.Burgundy or nil, { Brim = 1.7, W = 1.24, Hgt = 0.5, Y = 0.6 })
		-- длинное пальто: пуговицы (золото с 4-го), полы, ремень
		bevel(r, T, V(2.14, 1.2, 1.14), CF(0, 0.38, 0), coat, HW.EdgeCool, M.Fabric)
		for k = 0, 2 do
			r:Box(T, V(0.14, 0.14, 0.06), CF(0, 0.7 - k * 0.42, -0.6), lv >= 4 and HW.Gold or HW.Iron, M.Metal)
		end
		for _, s in ipairs(SIDES) do
			bevel(r, T, V(0.98, 1.3, 0.16), CF(0.52 * s, -1.6, -0.5), coatD, false, M.Fabric)
		end
		belt(r, HW.Leather, HW.Iron)
		if lv >= 2 then -- шарф
			bevel(r, T, V(1.4, 0.3, 1.2), CF(0, 0.98, 0), HW.Burgundy, false, M.Fabric)
			r:Box(T, V(0.3, 0.8, 0.08), CF(0.4, 0.5, -0.62), HW.Burgundy, M.Fabric)
		end
		if lv >= 3 then -- накидка и связка ключей
			mantle(r, coatD, HW.EdgeCool)
			r:Box(T, V(0.2, 0.2, 0.06), CF(-0.7, -0.95, -0.6), HW.Iron, M.Metal)
			r:Box(T, V(0.06, 0.4, 0.06), CF(-0.62, -1.2, -0.62), HW.Gold, M.Metal)
			r:Box(T, V(0.06, 0.34, 0.06), CF(-0.78, -1.17, -0.62), HW.Gold, M.Metal)
		end
		-- дубинка в левой руке (железная с 4-го) и значок-звезда
		local iron = lv >= 4
		r:Box(r.LArm, V(0.22, 1.7, 0.22), CF(0, -1.6, -0.3) * ANG(rad(-20), 0, 0), iron and HW.Iron or HW.Wood, iron and M.Metal or M.Wood)
		if lv >= 4 then
			star(r, T, CF(-0.55, 0.6, -0.62), 0.9, HW.Gold)
		end
		-- фонарь висит на железном пруте под кулаком правой руки
		local pose = { 35, 0, 0 }
		local dn = downIn(pose)
		local hand = V(0, GRIP, -0.2)
		r:Seg(A, hand, hand + dn * 0.55, 0.06, HW.Iron, M.Metal)
		local lc = hand + dn * 1.05
		local flame = lantern(r, A, hang(lc, dn), lv >= 4 and 1.25 or 1.05, lv >= 4 and HW.Gold or HW.Iron,
			lv >= 5 and rgb(255, 230, 150) or HW.Flame)
		muzzle(r, A, CF(lc))
		if lv >= 3 then
			embers(r, flame, HW.Flame, 4, 0.15)
		end
		for _, L in ipairs({ r.RLeg, r.LLeg }) do -- сапоги
			bevel(r, L, V(1.1, 0.5, 1.2), CF(0, -0.75, -0.08), HW.Leather, false)
		end
		if lv >= 5 then
			capeWith(r, 1.9, 2.9, coatD, HW.Flame)
		end
		levelAura(r, lv, HW.Flame)
		return finish(r, id, { RS = pose, LS = { 8, 0, -6 } })
	end

	------------------------------------------------------------------------
	-- 2. GRAVEDIGGER (Rare) — могильщик с лопатой
	------------------------------------------------------------------------
	local function Gravedigger(lv, id)
		local shirt, pants = rgb(70, 58, 50), rgb(44, 38, 36)
		local r = figure(id, { Torso = shirt, Arm = shirt, Leg = pants, Skin = rgb(150, 160, 140), Edge = HW.Edge })
		local T, A = r.Torso, r.RArm
		-- глаза (тлеют с 3-го), щетина, шляпа с обвисшими полями
		eyes(r, lv >= 3 and HW.Orange or rgb(30, 26, 22), lv >= 3, 0.08)
		bevel(r, r.Head, V(1.24, 0.42, 0.3), CF(0, -0.42, -0.5), rgb(70, 64, 58), false, M.Fabric)
		brimHat(r, rgb(46, 40, 36), rgb(90, 70, 46), { Brim = 1.9, W = 1.26, Hgt = 0.5, Y = 0.6, Tilt = -6 })
		-- кожаный фартук на лямках
		bevel(r, T, V(1.7, 1.9, 0.12), CF(0, -0.4, -0.56), HW.Leather, false, M.Fabric)
		for _, s in ipairs(SIDES) do
			r:Box(T, V(0.08, 0.9, 0.06), CF(0.5 * s, 0.6, -0.56), HW.Leather, M.Fabric)
		end
		belt(r, HW.Leather, HW.Iron)
		for _, arm in ipairs({ r.RArm, r.LArm }) do -- закатанные рукава и рабочие перчатки
			bevel(r, arm, V(1.1, 0.3, 1.1), CF(0, -0.15, 0), rgb(96, 82, 70), false, M.Fabric)
			bevel(r, arm, V(1.06, 0.55, 1.06), CF(0, -0.78, 0), rgb(46, 36, 30), false, M.Fabric)
		end
		for _, L in ipairs({ r.RLeg, r.LLeg }) do
			Kit.bootA(r, L, HW.Leather, false, 1.1)
		end
		if lv >= 2 then -- железные наплечники и ком земли на ботинке
			Parts.plateShoulders(r, HW.Iron, HW.Edge, 0.9)
			r:Box(r.RLeg, V(0.4, 0.2, 0.3), CF(0.2, -0.95, -0.6), rgb(60, 46, 34), M.Plastic)
		end
		if lv >= 3 then -- фонарь на поясе
			lantern(r, T, CF(-0.95, -1.15, -0.25), 0.6, HW.Iron, HW.Flame)
		end
		if lv >= 4 then -- надгробие-ранец с крестом
			local stone = rgb(96, 94, 104)
			bevel(r, T, V(1.3, 1.6, 0.35), CF(0, 0.5, 0.75), stone, rgb(140, 138, 150), M.Slate)
			bevel(r, T, V(0.95, 0.3, 0.37), CF(0, 1.4, 0.75), stone, false, M.Slate)
			r:Box(T, V(0.15, 0.7, 0.05), CF(0, 0.6, 0.94), rgb(60, 58, 66), M.Slate)
			r:Box(T, V(0.45, 0.15, 0.05), CF(0, 0.75, 0.94), rgb(60, 58, 66), M.Slate)
		end
		-- лопата: древко с Т-рукоятью внизу, полотно наверху (железо с 3-го, золото на 5-м)
		local wood = lv >= 4 and HW.Wood or HW.WoodLight
		local top = shaft(r, A, -2.4, 1.5, wood, 0.2)
		r:Box(A, V(0.55, 0.16, 0.16), CF(0, -2.45, -0.5), wood, M.Wood)
		local bc = top + V(0, 0.6, 0)
		local metal = lv >= 5 and HW.Gold or (lv >= 3 and HW.Iron or rgb(110, 90, 70))
		bevel(r, A, V(0.1, 0.36, 0.3), CF(top + V(0, 0.08, 0)), metal, false)
		bevel(r, A, V(0.08, 0.9, 0.85), CF(bc), metal, lv >= 3 and HW.Edge or false)
		spike(r, A, bc + V(0, 0.45, 0), bc + V(0, 0.8, 0), 0.85, metal, M.Metal, true, 0.08)
		if lv >= 5 then
			r:Neon(A, V(0.1, 0.06, 0.8), CF(bc + V(0, 0.42, 0)), HW.Orange)
		end
		if lv >= 4 then -- черепок на полотне
			bevel(r, A, V(0.06, 0.3, 0.3), CF(bc + V(-0.06, 0, 0)), HW.Bone, false, M.Plastic)
		end
		r:WeaponTrail(A, top, bc + V(0, 0.8, 0), lv >= 5 and HW.Orange or rgb(180, 150, 110))
		muzzle(r, A, CF(bc + V(0, 0.6, 0)))
		if lv >= 5 then
			capeWith(r, 1.9, 2.8, rgb(46, 40, 36), HW.Orange)
		end
		levelAura(r, lv, HW.Orange)
		return finish(r, id, { RS = { 25, 0, 0 }, LS = { 10, 0, -6 }, Neck = { 6, 0, 0 } })
	end

	------------------------------------------------------------------------
	-- 3. CURSED SCARECROW (Rare) — проклятое пугало с вороньём и вилами
	------------------------------------------------------------------------
	local function CursedScarecrow(lv, id)
		local shirt = lv >= 4 and rgb(110, 40, 40) or rgb(120, 90, 60)
		local r = figure(id, { Torso = shirt, Arm = shirt, Leg = rgb(70, 60, 80), Skin = HW.Burlap, Edge = HW.StrawDark })
		local T, Hd, A = r.Torso, r.Head, r.RArm
		-- голова-мешок: глаза-кресты (светятся с 3-го) и зашитый рот
		bevel(r, Hd, V(1.3, 1.25, 1.3), CF(), HW.Burlap, HW.StrawDark, M.Fabric)
		local stitch = rgb(40, 26, 18)
		for _, s in ipairs(SIDES) do
			for _, a in ipairs({ 45, -45 }) do
				local at = CF(0.28 * s, 0.12, -0.67) * ANG(0, 0, rad(a))
				if lv >= 3 then
					r:Neon(Hd, V(0.3, 0.07, 0.05), at, HW.Orange)
				else
					r:Box(Hd, V(0.3, 0.07, 0.05), at, stitch)
				end
			end
		end
		r:Box(Hd, V(0.7, 0.06, 0.05), CF(0, -0.28, -0.67), stitch)
		for k = -2, 2 do
			r:Box(Hd, V(0.04, 0.18, 0.05), CF(k * 0.15, -0.28, -0.68), stitch)
		end
		-- верёвка на шее и пучки соломы
		r:Box(Hd, V(1.34, 0.12, 1.34), CF(0, -0.55, 0), HW.StrawDark, M.Fabric)
		for k = 0, 5 do
			local a = k / 6 * PI * 2
			local c, s = math.cos(a), math.sin(a)
			spike(r, Hd, V(c * 0.5, -0.6, s * 0.5), V(c * 0.85, -0.95, s * 0.85), 0.2, HW.Straw, M.Fabric, true, 0.05)
		end
		if lv >= 2 then -- колпак (бордовая лента с 4-го)
			Parts.wizardHat(r, rgb(60, 46, 34), lv >= 4 and HW.Burgundy or rgb(90, 70, 46), false)
		end
		-- рубаха с заплатками
		bevel(r, T, V(2.14, 2.0, 1.14), CF(), shirt, HW.StrawDark, M.Fabric)
		r:Box(T, V(0.5, 0.45, 0.05), CF(0.45, -0.1, -0.6), rgb(150, 130, 90), M.Fabric)
		r:Box(T, V(0.4, 0.4, 0.05), CF(-0.5, 0.5, -0.6), rgb(90, 70, 100), M.Fabric)
		belt(r, rgb(120, 96, 50), HW.StrawDark)
		for _, limb in ipairs({ r.RArm, r.LArm, r.RLeg, r.LLeg }) do -- солома из рукавов и штанин
			for k = -1, 1 do
				spike(r, limb, V(k * 0.28, -0.85, 0), V(k * 0.4, -1.35, -0.1), 0.24, HW.Straw, M.Fabric, true, 0.05)
			end
		end
		-- крест-шест за спиной
		r:Box(T, V(0.24, 4.6, 0.24), CF(0, -0.1, 0.72), HW.Wood, M.Wood)
		r:Box(T, V(3.6, 0.22, 0.22), CF(0, 0.75, 0.72), HW.Wood, M.Wood)
		-- вилы (железные с 4-го, светящиеся зубья на 5-м)
		local top = shaft(r, A, -2.5, 2.0, HW.Wood, 0.18)
		local fork = lv >= 4 and HW.Iron or rgb(100, 90, 80)
		r:Box(A, V(0.12, 0.12, 0.85), CF(top + V(0, 0.05, 0)), fork, M.Metal)
		for k = -1, 1 do
			spike(r, A, top + V(0, 0.05, k * 0.38), top + V(0, 0.95, k * 0.38), 0.14, fork, M.Metal)
		end
		if lv >= 5 then
			for k = -1, 1 do
				r:Neon(A, V(0.05, 0.5, 0.05), CF(top + V(0, 0.45, k * 0.38 - 0.06)), HW.Orange)
			end
		end
		muzzle(r, A, CF(top + V(0, 0.9, 0)))
		r:WeaponTrail(A, top, top + V(0, 1, 0), HW.Orange)
		-- вороньё: на плече (3), на перекладине креста (4), кружит над головой (5)
		if lv >= 3 then
			crow(r, r.LArm, CF(0, 1.02, 0) * ANG(0, rad(20), 0), 1, HW.Orange)
		end
		if lv >= 4 then
			crow(r, T, CF(1.35, 0.85, 0.72) * ANG(0, rad(-30), 0), 0.9, HW.Orange)
		end
		if lv >= 5 then
			local hub = orbitHub(r, "OrbitCrows", T, CF(0, 1.9, 0))
			for i = 0, 2 do
				local a = i / 3 * PI * 2
				crow(r, hub, CF(math.cos(a) * 2.3, math.sin(a * 2) * 0.2, math.sin(a) * 2.3) * ANG(0, -a, 0), 0.9, HW.Orange)
			end
			capeWith(r, 1.9, 2.8, rgb(70, 54, 40), HW.Orange)
		end
		levelAura(r, lv, HW.Orange)
		return finish(r, id, { RS = { 20, 0, 0 }, LS = { 75, 0, -25 } })
	end

	------------------------------------------------------------------------
	-- 4. CURSED SHERIFF (Epic) — проклятый шериф с зелёными револьверами
	------------------------------------------------------------------------
	-- Револьвер в рамке AIM (ствол вперёд при поднятой руке); secondary — второй, Muzzle не трогает
	local function revolver(r, A, o, secondary)
		local F = AIM
		bevel(r, A, V(0.26, 0.5, 0.34), F * CF(0, -0.15, 0.15) * ANG(rad(-18), 0, 0), HW.Wood, false, M.Wood)
		bevel(r, A, V(0.3, 0.32, 0.5), F * CF(0, 0.14, -0.15), o.Metal, o.Edge)
		bevel(r, A, V(0.4, 0.34, 0.38), F * CF(0, 0.16, -0.5), o.Metal, o.Edge) -- барабан
		r:Box(A, V(0.18, 0.18, 1.1), F * CF(0, 0.24, -1.15), o.Metal, M.Metal)
		r:Box(A, V(0.06, 0.1, 0.1), F * CF(0, 0.36, -1.6), o.Metal, M.Metal) -- мушка
		r:Neon(A, V(0.08, 0.08, 0.9), F * CF(0, 0.34, -1.1), o.Glow)
		for k = 0, 1 do
			r:Neon(A, V(0.42, 0.06, 0.06), F * CF(0, 0.16, -0.38 - k * 0.24), o.Glow)
		end
		return muzzle(r, A, F * CF(0, 0.24, -1.75), secondary)
	end

	local function CursedSheriff(lv, id)
		local coat, coatD = rgb(76, 54, 38), rgb(46, 34, 28)
		local glow = HW.Green
		local r = figure(id, { Torso = rgb(56, 50, 46), Arm = coat, Leg = rgb(40, 36, 44), Skin = rgb(150, 170, 150), Edge = HW.Edge })
		local T, Hd = r.Torso, r.Head
		eyes(r, glow, true, 0.08)
		-- платок на лице с треугольным концом (бордовый с 4-го)
		local scarf = lv >= 4 and HW.Burgundy or rgb(110, 40, 40)
		bevel(r, Hd, V(1.26, 0.5, 1.26), CF(0, -0.36, 0), scarf, false, M.Fabric)
		spike(r, Hd, V(0, -0.6, -0.63), V(0, -0.95, -0.66), 0.5, scarf, M.Fabric, true, 0.06)
		-- ковбойская шляпа: поля с загнутыми краями, тулья с вмятиной, лента (неон с 3-го)
		local hat = lv >= 3 and HW.Black or rgb(70, 50, 36)
		bevel(r, Hd, V(2.3, 0.12, 1.9), CF(0, 0.62, 0), hat, false, M.Fabric)
		for _, s in ipairs(SIDES) do
			bevel(r, Hd, V(0.3, 0.12, 1.8), CF(1.2 * s, 0.75, 0) * ANG(0, 0, rad(35 * s)), hat, false, M.Fabric)
		end
		bevel(r, Hd, V(1.25, 0.62, 1.3), CF(0, 0.98, 0), hat, false, M.Fabric)
		r:Wedge(Hd, V(1.25, 0.18, 0.6), CF(0, 1.38, -0.2) * ANG(0, PI, 0), hat, M.Fabric)
		r:Box(Hd, V(1.29, 0.14, 1.34), CF(0, 0.74, 0), lv >= 3 and glow or rgb(140, 110, 70), lv >= 3 and M.Neon or M.Fabric)
		if lv >= 4 then -- черепок на тулье
			bevel(r, Hd, V(0.34, 0.34, 0.08), CF(0, 0.92, -0.68), HW.Bone, false, M.Plastic)
			for _, s in ipairs(SIDES) do
				r:Neon(Hd, V(0.08, 0.08, 0.04), CF(0.08 * s, 0.94, -0.73), glow)
			end
		end
		-- жилет, звезда (золотая с 2-го), пояс; с 2-го — патронташ через грудь
		bevel(r, T, V(2.12, 1.3, 1.12), CF(0, 0.32, 0), rgb(46, 40, 38), HW.Edge, M.Fabric)
		star(r, T, CF(-0.5, 0.55, -0.6), 1.05, lv >= 2 and HW.Gold or HW.Iron)
		belt(r, HW.Leather, HW.Gold)
		if lv >= 2 then
			bar(r, T, V(-0.9, 0.95, -0.58), V(0.9, -0.7, -0.58), V2(0.2, 0.06), HW.Leather)
			for k = 0, 3 do
				r:Box(T, V(0.08, 0.16, 0.06), CF(-0.6 + k * 0.38, 0.65 - k * 0.35, -0.62) * ANG(0, 0, rad(42)), HW.Gold, M.Metal)
			end
		end
		-- пыльник: полы до колен, спинка, рваный край
		for _, s in ipairs(SIDES) do
			bevel(r, T, V(0.98, 1.7, 0.16), CF(0.56 * s, -1.75, -0.44), coat, HW.Edge, M.Fabric)
			bevel(r, T, V(0.16, 1.7, 1.1), CF(1.05 * s, -1.75, 0), coat, false, M.Fabric)
		end
		bevel(r, T, V(2.1, 1.8, 0.16), CF(0, -1.8, 0.52), coat, false, M.Fabric)
		Kit.tatter(r, T, -2.6, 0.55, 2.0, 4, coat, M.Fabric, 2)
		cuffs(r, V(1.08, 0.4, 1.08), -0.75, HW.Leather, M.Fabric)
		if lv >= 4 then
			mantle(r, coatD, HW.Edge)
		end
		for _, L in ipairs({ r.RLeg, r.LLeg }) do -- сапоги с золотыми шпорами
			Kit.bootA(r, L, HW.Leather, HW.Edge, 1.1)
			r:Box(L, V(0.1, 0.1, 0.3), CF(0, -0.95, 0.65), HW.Gold, M.Metal)
		end
		local gun = { Metal = lv >= 4 and rgb(40, 44, 40) or HW.Iron, Edge = lv >= 3 and HW.GreenDim or HW.Edge, Glow = glow }
		revolver(r, r.RArm, gun)
		if lv >= 3 then
			revolver(r, r.LArm, gun, true) -- второй револьвер; Muzzle остаётся на правом
		else
			bevel(r, T, V(0.3, 0.6, 0.42), CF(-1.0, -1.15, -0.1), HW.Leather, false, M.Fabric) -- кобура
		end
		if lv >= 5 then -- плащ и проклятая цепь на поясе
			capeWith(r, 1.9, 3.0, coatD, glow)
			Kit.chain(r, T, 4, 0.22, rgb(60, 90, 60), CF(0.95, -0.95, -0.35))
		end
		levelAura(r, lv, glow)
		return finish(r, id, { RS = { 72, 0, 0 }, LS = lv >= 3 and { 30, 0, -10 } or { 6, 0, -6 } })
	end

	------------------------------------------------------------------------
	-- 5. MIDNIGHT BELLRINGER (Epic) — горбатый звонарь с колоколом
	------------------------------------------------------------------------
	local BELL_SCALE = { 0.8, 0.85, 0.9, 1.0, 1.1 }

	local function MidnightBellringer(lv, id)
		local robeC, robeD = rgb(44, 34, 62), rgb(28, 22, 40)
		local glow = rgb(190, 160, 255)
		local r = figure(id, { Torso = robeC, Arm = robeC, Leg = robeD, Skin = rgb(170, 160, 176), Edge = HW.EdgeCool })
		local T, A = r.Torso, r.RArm
		Parts.hood(r, robeC, HW.EdgeCool, glow, true)
		for _, s in ipairs(SIDES) do -- глаза светятся из тени капюшона
			r:Neon(r.Head, V(0.22, 0.13, 0.05), CF(0.24 * s, 0.06, -0.66), glow)
		end
		bevel(r, T, V(1.7, 1.1, 0.8), CF(0, 0.65, 0.65) * ANG(rad(-15), 0, 0), robeC, HW.EdgeCool, M.Fabric) -- горб
		robe(r, robeD, lv >= 3 and HW.Gold or nil, 1.8)
		belt(r, rgb(70, 50, 40), HW.Gold, lv >= 2 and glow or nil)
		r:Box(T, V(0.12, 1.4, 0.12), CF(0.75, -1.5, -0.6), rgb(170, 150, 110), M.Fabric) -- верёвка колокола
		if lv >= 2 then
			mantle(r, robeC, HW.EdgeCool)
		end
		-- ручной колокол: рукоять из кулака, колокол висит под ней (растёт с уровнем, золотой с 4-го)
		local pose = { 62, 0, 10 }
		local dn = downIn(pose)
		local hand = V(0, GRIP, -0.15)
		r:Seg(A, hand, hand + dn * 0.6, V2(0.2, 0.2), HW.Wood, M.Wood)
		local s = BELL_SCALE[lv]
		local at = hang(hand + dn * 0.6, dn)
		local metal = lv >= 4 and HW.Gold or rgb(150, 110, 60)
		local clapper = bell(r, A, at, s, metal, lv >= 4 and HW.GoldDark or rgb(110, 80, 44), glow)
		muzzle(r, A, at * CF(0, -0.9 * s, 0))
		r:Glow(clapper, glow, 8, 1)
		if lv >= 2 then -- призрачные часы над плечом (крутятся как Orbit)
			local c = r:Joint("OrbitGhostClock", T, V(0.1, 0.1, 0.1), CF(-1.4, 2.0, 0.6), CF(), glow)
			c.Transparency = 1
			r:Box(c, V(1.0, 1.0, 0.1), ANG(0, 0, rad(45)), glow, M.Glass, { Transparency = 0.55 })
			r:Box(c, V(0.82, 0.82, 0.12), ANG(0, 0, rad(45)), rgb(30, 24, 50), M.Glass, { Transparency = 0.35 })
			r:Neon(c, V(0.06, 0.34, 0.14), CF(0, 0.15, -0.02), glow)
			r:Neon(c, V(0.26, 0.05, 0.14), CF(0.12, 0, -0.02), glow)
		end
		if lv >= 3 then -- малый колокол на поясе
			bell(r, T, CF(-0.95, -0.8, -0.3), 0.45, metal, rgb(110, 80, 44), glow)
		end
		if lv >= 4 then -- кольцо призрачных циферблатов
			local hub = orbitHub(r, "OrbitClocks", T, CF(0, 0.6, 0))
			for i = 0, 2 do
				local a, p = around(i, 3, 2.3)
				local face = CF(p) * ANG(0, -a + PI / 2, 0)
				r:Box(hub, V(0.6, 0.6, 0.08), face * ANG(0, 0, rad(45)), glow, M.Glass, { Transparency = 0.5 })
				r:Neon(hub, V(0.05, 0.24, 0.1), face * CF(0, 0.1, 0), glow)
			end
		end
		if lv >= 5 then
			capeWith(r, 2.0, 3.0, robeC, glow)
		end
		levelAura(r, lv, glow)
		return finish(r, id, { RS = pose, LS = { 15, 0, -8 }, Neck = { -4, 0, 0 } })
	end

	------------------------------------------------------------------------
	-- 6. PLAGUE DOCTOR (Legendary) — чумной доктор с колбой яда
	------------------------------------------------------------------------
	local function PlagueDoctor(lv, id)
		local coat, coatD = rgb(30, 26, 32), rgb(20, 18, 24)
		local glow = HW.Green
		local r = figure(id, { Torso = coat, Arm = coat, Leg = coatD, Skin = rgb(60, 46, 38), Edge = HW.EdgeCool })
		local T, Hd, A = r.Torso, r.Head, r.RArm
		-- кожаная маска с длинным клювом и круглыми стёклами в золотой оправе (зелёные с 2-го)
		local leather, seam = lv >= 4 and rgb(70, 48, 36) or rgb(96, 72, 54), rgb(130, 100, 76)
		bevel(r, Hd, V(1.3, 1.3, 1.3), CF(), leather, seam, M.Fabric)
		bevel(r, Hd, V(0.62, 0.5, 0.5), CF(0, -0.2, -0.82), leather, seam, M.Fabric)
		spike(r, Hd, V(0, -0.22, -1.05), V(0, -0.55, -2.1), 0.5, leather, M.Fabric)
		for _, s in ipairs(SIDES) do
			r:Box(Hd, V(0.38, 0.38, 0.08), CF(0.3 * s, 0.14, -0.67) * ANG(0, 0, rad(45)), HW.Gold, M.Metal)
			r:Neon(Hd, V(0.3, 0.3, 0.1), CF(0.3 * s, 0.14, -0.68) * ANG(0, 0, rad(45)), lv >= 2 and glow or rgb(160, 200, 160))
		end
		brimHat(r, HW.Black, lv >= 3 and HW.Burgundy or rgb(40, 34, 38), { Brim = 2.4, W = 1.4, Hgt = 0.75, Y = 0.68, Edge = HW.EdgeCool })
		-- длинный плащ, кожаный фартук, накидка, перчатки
		robe(r, coat, lv >= 3 and HW.Burgundy or nil, 2.0)
		bevel(r, T, V(1.4, 2.6, 0.12), CF(0, -0.9, -0.62), rgb(70, 52, 40), false, M.Fabric)
		belt(r, HW.Leather, HW.Gold)
		mantle(r, coatD, HW.EdgeCool)
		cuffs(r, V(1.1, 0.6, 1.1), -0.78, rgb(36, 30, 30), M.Fabric)
		for k = 0, (lv >= 2 and 3 or 2) - 1 do -- склянки на поясе
			flask(r, T, CF(-0.75 + k * 0.42, -1.18, -0.68), 0.75, k % 2 == 0 and glow or POTION)
		end
		-- колба с ядом в правой руке (больше с 4-го, искрит с 3-го)
		local at = CF(0, GRIP - 0.42, -0.25)
		local liquid = flask(r, A, at, lv >= 4 and 1.5 or 1.25, glow)
		muzzle(r, A, at)
		r:Glow(liquid, glow, 7, 1)
		if lv >= 3 then
			r:Sparkles(liquid, glow, { Rate = 5, Up = 2, Size = 0.2 })
		end
		-- трость с черепом в левой руке
		local top = shaft(r, r.LArm, -3.0, -0.4, HW.Black, 0.16)
		bevel(r, r.LArm, V(0.42, 0.42, 0.42), CF(top + V(0, 0.2, 0)), HW.Bone, false, M.Plastic)
		for _, s in ipairs(SIDES) do
			r:Neon(r.LArm, V(0.1, 0.08, 0.04), CF(top + V(0.1 * s, 0.24, -0.22)), glow)
		end
		if lv >= 3 then -- ворон с зелёными глазами на плече
			crow(r, r.LArm, CF(0.05, 1.02, 0) * ANG(0, rad(15), 0), 1.15, glow)
		end
		if lv >= 4 then
			local hub = orbitHub(r, "OrbitFlasks", T, CF(0, 0.2, 0))
			for i = 0, 2 do
				local a = i / 3 * PI * 2
				flask(r, hub, CF(math.cos(a) * 2.2, math.sin(a * 2) * 0.2, math.sin(a) * 2.2), 0.9, i == 1 and POTION or glow)
			end
		end
		if lv >= 5 then -- плащ и ядовитая дымка
			capeWith(r, 2.1, 3.3, coatD, glow)
			emitter(T, "PoisonMist", {
				Color = ColorSequence.new(rgb(80, 160, 70)), LightEmission = 0.3, Rate = 4,
				Lifetime = NumberRange.new(1, 1.8), Speed = NumberRange.new(0.2, 0.6), SpreadAngle = V2(180, 180),
				Size = seq(0.6, 1.6), Transparency = seq(0.7, 1),
			})
		end
		levelAura(r, lv, glow)
		return finish(r, id, { RS = { 40, 0, 0 }, LS = { 15, 0, -8 }, Neck = { 6, 0, 0 } })
	end

	------------------------------------------------------------------------
	-- 7. PHANTOM KNIGHT (Legendary) — призрачный рыцарь с синим мечом
	------------------------------------------------------------------------
	local SWORD_LEN = { 3.0, 3.2, 3.4, 3.7, 4.2 }

	local function PhantomKnight(lv, id)
		local ghost, deep, plate = rgb(70, 120, 190), rgb(34, 52, 96), rgb(46, 70, 120)
		local edge, glow = rgb(150, 210, 255), HW.Ghost
		local r = figure(id, { Torso = deep, Arm = deep, Leg = deep, Skin = rgb(20, 30, 50), Edge = edge })
		local T, Hd = r.Torso, r.Head
		local function shell(limb, size, cf) -- полупрозрачная оболочка призрака
			return r:Box(limb, size, cf, ghost, M.Glass, { Transparency = 0.35 })
		end
		Parts.helm(r, plate, edge, glow, nil, true)
		shell(Hd, V(1.42, 1.56, 1.42), CF(0, 0.1, 0))
		for k = 1, lv >= 4 and 3 or (lv >= 2 and 2 or 1) do -- плюмаж из синего огня
			spike(r, Hd, V(0, 0.75, 0.1 + k * 0.18), V(0, 1.4 + k * 0.1, 0.6 + k * 0.25), 0.4, glow, M.Neon, true, 0.08)
		end
		Parts.chest(r, plate, edge, glow)
		shell(T, V(2.25, 2.1, 1.25), CF())
		belt(r, deep, edge, glow)
		Parts.tassets(r, plate, edge)
		Parts.bigShoulders(r, plate, edge, lv >= 3 and glow or nil, lv >= 4 and 1.15 or 1.0, lv >= 4 and 2 or 1)
		Parts.bracers(r, plate, edge)
		for _, L in ipairs({ r.RLeg, r.LLeg }) do -- ноги растворяются в дымке
			bevel(r, L, V(1.12, 0.8, 1.14), CF(0, 0.3, 0), plate, edge)
			shell(L, V(1.16, 2.0, 1.16), CF())
		end
		emitter(r.RLeg, "GhostMist", {
			Color = ColorSequence.new(glow), LightEmission = 0.6, Rate = 6,
			Lifetime = NumberRange.new(0.8, 1.4), Speed = NumberRange.new(0.2, 0.7), SpreadAngle = V2(180, 180),
			Size = seq(0.5, 1.2), Transparency = seq(0.6, 1),
		})
		-- светящийся меч растёт с уровнем (на 5-м — широкий двуручник)
		Parts.blade(r, r.RArm, {
			Len = SWORD_LEN[lv], W = lv >= 5 and 0.7 or 0.55, Blade = rgb(90, 150, 220), Guard = plate, Edge = edge,
			Glow = glow, Core = lv >= 3 and rgb(220, 240, 255) or nil, Trail = glow,
		})
		if lv >= 3 then
			capeWith(r, 2.0, 3.2, rgb(30, 50, 90), glow)
		end
		if lv >= 5 then -- призрачные мечи на орбите
			local hub = orbitHub(r, "OrbitSwords", T, CF(0, 0.4, 0))
			for i = 0, 2 do
				local a, p = around(i, 3, 2.6)
				r:Box(hub, V(0.1, 1.6, 0.32), CF(p) * ANG(0, -a, 0), glow, M.Glass, { Transparency = 0.3 })
				r:Box(hub, V(0.12, 0.12, 0.7), CF(p + V(0, -0.7, 0)) * ANG(0, -a, 0), edge, M.Metal)
				spike(r, hub, p + V(0, 0.8, 0), p + V(0, 1.2, 0), 0.3, glow, M.Neon, true, 0.08)
			end
		end
		levelAura(r, lv, glow)
		return finish(r, id, { RS = { 30, 0, 0 }, LS = { 10, 0, -8 } })
	end

	------------------------------------------------------------------------
	-- 8. DARK ILLUSIONIST (Legendary) — тёмный иллюзионист с веером карт
	------------------------------------------------------------------------
	local function DarkIllusionist(lv, id)
		local suit, suitD = rgb(30, 22, 40), rgb(20, 14, 28)
		local glow, wine = HW.Violet, rgb(80, 20, 40)
		local r = figure(id, { Torso = suit, Arm = suit, Leg = suitD, Skin = rgb(214, 200, 210), Edge = HW.EdgeCool })
		local T, Hd = r.Torso, r.Head
		-- маска-домино с фиолетовыми глазами и ухмылка
		r:Box(Hd, V(1.1, 0.34, 0.06), CF(0, 0.12, -0.62), HW.Black, M.Plastic)
		for _, s in ipairs(SIDES) do
			r:Neon(Hd, V(0.2, 0.1, 0.05), CF(0.27 * s, 0.12, -0.66), glow)
		end
		r:Box(Hd, V(0.46, 0.06, 0.04), CF(0, -0.3, -0.62) * ANG(0, 0, rad(-6)), wine)
		-- цилиндр: лента (неоновая с 3-го), с 2-го — карта за лентой
		bevel(r, Hd, V(1.8, 0.1, 1.8), CF(0, 0.62, 0), HW.Black, false, M.Fabric)
		bevel(r, Hd, V(1.15, 1.2, 1.15), CF(0, 1.25, 0), HW.Black, HW.EdgeCool, M.Fabric)
		r:Box(Hd, V(1.19, 0.2, 1.19), CF(0, 0.8, 0), lv >= 3 and glow or HW.Burgundy, lv >= 3 and M.Neon or M.Fabric)
		if lv >= 2 then
			card(r, Hd, CF(0.4, 0.95, -0.62) * ANG(0, 0, rad(-15)), 0.8, HW.Red)
		end
		-- фрак: красный жилет, белый галстук-клин, лацканы, фалды
		bevel(r, T, V(2.12, 2.0, 1.12), CF(), suit, HW.EdgeCool, M.Fabric)
		r:Box(T, V(0.6, 1.3, 0.06), CF(0, 0.3, -0.58), wine, M.Fabric)
		r:Wedge(T, V(0.5, 0.25, 0.06), CF(0, 0.9, -0.62) * ANG(0, 0, PI), WHITE, M.Plastic)
		for _, s in ipairs(SIDES) do
			r:Box(T, V(0.36, 1.3, 0.08), CF(0.48 * s, 0.35, -0.6) * ANG(0, 0, rad(12 * s)), HW.Black, M.Fabric)
			bevel(r, T, V(0.85, 1.6, 0.14), CF(0.45 * s, -1.6, 0.52) * ANG(rad(-8), 0, rad(-6 * s)), suitD, false, M.Fabric)
		end
		belt(r, HW.Black, HW.Gold, lv >= 2 and glow or nil)
		cuffs(r, V(1.06, 0.42, 1.06), -0.8, WHITE, M.Plastic) -- белые перчатки
		-- плащ с бордовой подкладкой и высоким воротником (чёрный с 4-го, эмблема с 3-го)
		local cape = capeWith(r, 2.1, 3.1, lv >= 4 and HW.Black or suitD, lv >= 3 and glow or nil)
		r:Box(cape, V(1.95, 1.6, 0.04), CF(0, 0, -0.08), HW.Burgundy, M.Fabric)
		for _, s in ipairs(SIDES) do
			r:Wedge(T, V(0.15, 0.9, 0.7), CF(0.9 * s, 1.35, 0.25) * ANG(0, PI, 0), HW.Burgundy, M.Fabric)
		end
		-- веер карт в правой руке (3, с 3-го — 5), лицом вперёд при поднятой руке
		local n = lv >= 3 and 5 or 3
		for k = 1, n do
			local a = rad((k - (n + 1) / 2) * 22)
			card(r, r.RArm, AIM * CF(0, 0.05, -0.4) * ANG(0, 0, -a) * CF(0, 0.42, -0.01 * k), 1.45, k % 2 == 0 and HW.Black or HW.Red)
		end
		muzzle(r, r.RArm, AIM * CF(0, 0.05, -0.5))
		-- трость с фиолетовым кристаллом в левой руке
		local top = shaft(r, r.LArm, -2.3, 1.3, HW.Black, 0.14)
		r:Box(r.LArm, V(0.18, 0.12, 0.18), CF(top), HW.Gold, M.Metal)
		r:Neon(r.LArm, V(0.32, 0.32, 0.32), CF(top + V(0, 0.25, 0)) * ANG(rad(45), 0, rad(45)), glow)
		if lv >= 4 then -- осколки зеркал на орбите (3, на 5-м — 5)
			local cnt = lv >= 5 and 5 or 3
			local hub = orbitHub(r, "OrbitMirrors", T, CF(0, 0.6, 0))
			for i = 0, cnt - 1 do
				local a = i / cnt * PI * 2
				local at = CF(math.cos(a) * 2.3, math.sin(a * 3) * 0.25, math.sin(a) * 2.3) * ANG(0, -a + PI / 2, 0)
				tri(r, hub, at, 0.5, 0.8, rgb(200, 190, 230), M.Foil, 0.06)
				r:Neon(hub, V(0.05, 0.4, 0.07), at, glow)
			end
		end
		if lv >= 5 then -- карты кружат над шляпой
			local hub = orbitHub(r, "OrbitCards", Hd, CF(0, 1.9, 0))
			for i = 0, 3 do
				local a, p = around(i, 4, 1.2)
				card(r, hub, CF(p) * ANG(0, -a, rad(20)), 0.9, HW.Red, i % 2 == 1)
			end
		end
		levelAura(r, lv, glow)
		return finish(r, id, { RS = { 60, 0, 10 }, LS = { 10, 0, -8 } })
	end

	------------------------------------------------------------------------
	-- 9. HALLOWEEN PUPPETEER (Mythic) — кукловод с вагой и красными нитями
	------------------------------------------------------------------------
	local THREAD_LEN = { 1.6, 1.8, 2.0, 2.0, 2.2 }
	local THREAD_ENDS = { V(-0.8, 0, 0), V(0.8, 0, 0), V(0, 0, -0.6), V(0, 0, 0.6) }

	-- Деревянная марионетка с фарфоровой головой (cf — центр тела)
	local function marionette(r, limb, cf, s)
		local wood = HW.WoodLight
		bevel(r, limb, V(0.5, 0.6, 0.3) * s, cf, wood, false, M.Wood)
		r:Box(limb, V(0.4, 0.4, 0.4) * s, cf * CF(0, 0.55 * s, 0), PORCELAIN, M.Plastic)
		for _, x in ipairs(SIDES) do
			r:Neon(limb, V(0.06, 0.06, 0.04) * s, cf * CF(0.09 * s * x, 0.6 * s, -0.21 * s), HW.Red)
			r:Box(limb, V(0.14, 0.5, 0.14) * s, cf * CF(0.34 * s * x, 0, 0), wood, M.Wood)
			r:Box(limb, V(0.16, 0.5, 0.16) * s, cf * CF(0.14 * s * x, -0.58 * s, 0), wood, M.Wood)
		end
	end

	local function HalloweenPuppeteer(lv, id)
		local coat, coatD = rgb(26, 18, 26), rgb(16, 12, 18)
		local red, trim = HW.Red, rgb(130, 70, 80)
		local r = figure(id, { Torso = coat, Arm = coat, Leg = coatD, Skin = rgb(228, 222, 230), Edge = trim })
		local T, Hd, A = r.Torso, r.Head, r.RArm
		-- фарфоровая маска: красные глаза-треугольники, улыбка с уголками (трещина с 2-го)
		r:Box(Hd, V(1.0, 1.0, 0.06), CF(0, -0.02, -0.62), PORCELAIN, M.Plastic)
		for _, s in ipairs(SIDES) do
			tri(r, Hd, CF(0.26 * s, 0.14, -0.66) * ANG(0, 0, PI), 0.24, 0.16, red, M.Neon, 0.04)
		end
		r:Box(Hd, V(0.5, 0.06, 0.04), CF(0, -0.27, -0.66), red, M.Neon)
		for _, s in ipairs(SIDES) do
			r:Box(Hd, V(0.06, 0.14, 0.04), CF(0.27 * s, -0.22, -0.66), red, M.Neon)
		end
		if lv >= 2 then
			Kit.crack(r, Hd, { V(-0.1, 0.45, -0.66), V(-0.22, 0.25, -0.66), V(-0.12, 0.05, -0.66) }, 0.04, rgb(60, 40, 50))
		end
		-- высокий цилиндр набекрень с красной лентой (неон с 3-го)
		bevel(r, Hd, V(1.7, 0.1, 1.7), CF(0, 0.62, 0), HW.Black, false, M.Fabric)
		bevel(r, Hd, V(1.1, 1.4, 1.1), CF(0, 1.35, 0) * ANG(0, 0, rad(-5)), HW.Black, rgb(90, 50, 60), M.Fabric)
		r:Box(Hd, V(1.14, 0.18, 1.14), CF(0, 0.82, 0), lv >= 3 and red or HW.Burgundy, lv >= 3 and M.Neon or M.Fabric)
		-- фрак до пола, бордовый жилет, высокий воротник
		robe(r, coat, HW.Burgundy, 2.0)
		bevel(r, T, V(2.14, 1.2, 1.14), CF(0, 0.4, 0), HW.Burgundy, trim, M.Fabric)
		r:Box(T, V(0.5, 1.2, 0.06), CF(0, 0.4, -0.6), HW.Black, M.Fabric)
		for _, s in ipairs(SIDES) do
			r:Wedge(T, V(0.15, 1.1, 0.8), CF(0.95 * s, 1.45, 0.2) * ANG(0, PI, 0), coat, M.Fabric)
		end
		belt(r, HW.Black, HW.Gold, red)
		mantle(r, coatD, trim)
		cuffs(r, V(1.06, 0.42, 1.06), -0.8, WHITE, M.Plastic)
		-- вага-крестовина в правой руке (чёрная с золотом с 4-го), 4 нити вниз
		local pose = { 70, 0, 18 }
		local dn = downIn(pose)
		local c = V(0, GRIP - 0.25, -0.1)
		local cross = hang(c, dn)
		local wood = lv >= 4 and HW.Black or HW.Wood
		r:Box(A, V(1.7, 0.16, 0.16), cross, wood, M.Wood)
		r:Box(A, V(0.16, 0.16, 1.3), cross, wood, M.Wood)
		if lv >= 4 then
			for _, x in ipairs({ -0.85, 0.85 }) do
				r:Box(A, V(0.2, 0.2, 0.2), cross * CF(x, 0, 0), HW.Gold, M.Metal)
			end
		end
		local len = THREAD_LEN[lv]
		for _, e in ipairs(THREAD_ENDS) do
			local p = cross * e
			thread(r, A, p, p + dn * len, red)
		end
		muzzle(r, A, CF(c + dn * len))
		if lv >= 3 then -- кукла на нитях
			marionette(r, A, hang(c + dn * (len + 0.55), dn), 1.2)
		end
		-- левая рука: нити от пальцев
		local pose2 = { 55, 0, -20 }
		local dn2 = downIn(pose2)
		for k = -1, 1 do
			local p = V(k * 0.3, GRIP - 0.3, -0.1)
			thread(r, r.LArm, p, p + dn2 * (1.4 + math.abs(k) * 0.3), red)
		end
		if lv >= 4 then
			capeWith(r, 2.1, 3.4, HW.Burgundy, red)
		end
		if lv >= 5 then -- огромная катушка за спиной и куклы на орбите
			for _, y in ipairs({ -0.6, 0.6 }) do
				bevel(r, T, V(1.5, 0.2, 1.5), CF(0, 0.3 + y, 1.25) * ANG(0, PI / 4, 0), HW.Black, trim)
			end
			r:Neon(T, V(1.1, 1.0, 1.1), CF(0, 0.3, 1.25), red)
			local hub = orbitHub(r, "OrbitPuppets", T, CF(0, -0.4, 0))
			for i = 0, 2 do
				local a, p = around(i, 3, 2.6)
				local at = CF(p) * ANG(0, -a, 0)
				marionette(r, hub, at, 1.0)
				thread(r, hub, at * V(0, 0.8, 0), at * V(0, 2.2, 0), red)
			end
		end
		levelAura(r, lv, red)
		return finish(r, id, { RS = pose, LS = pose2 })
	end

	------------------------------------------------------------------------
	-- 10. HEADLESS EXECUTIONER (Mythic) — безголовый палач с огромным топором
	------------------------------------------------------------------------
	local AXE_R = { 1.3, 1.4, 1.5, 1.7, 1.9 }

	local function HeadlessExecutioner(lv, id)
		local leather, iron, strap = rgb(50, 32, 28), rgb(54, 52, 60), rgb(30, 22, 20)
		local fire = HW.Orange
		local r = figure(id, { Torso = rgb(70, 50, 44), Arm = rgb(110, 80, 70), Leg = rgb(36, 28, 30), Skin = rgb(70, 50, 44), Edge = HW.Edge })
		local T, A = r.Torso, r.RArm
		Parts.hideHead(r)
		-- обрубок шеи: железный ворот, тлеющие угли и языки пламени
		bevel(r, T, V(1.3, 0.35, 1.0), CF(0, 1.12, 0), iron, HW.Edge)
		local ember = r:Neon(T, V(0.8, 0.12, 0.6), CF(0, 1.32, 0), fire)
		r:Box(T, V(0.5, 0.14, 0.4), CF(0, 1.36, 0), rgb(120, 30, 20), M.Plastic)
		for k = 0, 3 do
			local a = k / 4 * PI * 2 + 0.4
			local c, s = math.cos(a), math.sin(a)
			spike(r, T, V(c * 0.25, 1.35, s * 0.2), V(c * 0.32, 1.75 + (k % 2) * 0.2, s * 0.25), 0.22, fire, M.Neon, true, 0.05)
		end
		emitter(ember, "NeckFire", {
			Color = ColorSequence.new(rgb(255, 190, 80), rgb(255, 70, 20)), LightEmission = 1, LightInfluence = 0, Rate = 14,
			Lifetime = NumberRange.new(0.4, 0.8), Speed = NumberRange.new(1.5, 3), EmissionDirection = Enum.NormalId.Top,
			SpreadAngle = V2(15, 15), Size = seq(0.5, 0), Transparency = seq(0.2, 1),
		})
		r:Glow(ember, fire, 10, 1.6)
		-- кожаный нагрудник с ремнями крест-накрест и медальоном; железные наручи и поножи
		bevel(r, T, V(2.14, 2.0, 1.14), CF(), leather, HW.Edge, M.Fabric)
		bar(r, T, V(-0.9, 0.95, -0.6), V(0.9, -0.7, -0.6), V2(0.22, 0.07), strap)
		bar(r, T, V(0.9, 0.95, -0.6), V(-0.9, -0.7, -0.6), V2(0.22, 0.07), strap)
		r:Box(T, V(0.3, 0.3, 0.08), CF(0, 0.12, -0.64) * ANG(0, 0, rad(45)), HW.Iron, M.Metal)
		belt(r, strap, HW.Gold, lv >= 3 and fire or nil)
		Parts.tassets(r, leather, HW.Edge)
		Parts.bracers(r, iron, HW.Edge)
		Parts.greaves(r, iron, HW.Edge, true)
		if lv >= 2 then
			Parts.bigShoulders(r, iron, HW.Edge, lv >= 4 and fire or nil, lv >= 4 and 1.15 or 1.0, lv >= 3 and 2 or 1)
		end
		-- капюшон палача висит на поясе (прорези тлеют с 3-го)
		bevel(r, T, V(0.75, 0.85, 0.5), CF(-1.0, -1.3, -0.25), HW.Black, false, M.Fabric)
		for _, s in ipairs(SIDES) do
			r:Box(T, V(0.14, 0.1, 0.05), CF(-1.0 + 0.17 * s, -1.2, -0.52), lv >= 3 and fire or rgb(60, 20, 20), lv >= 3 and M.Neon or M.Plastic)
		end
		if lv >= 3 then -- цепи на руке и бедре
			Kit.chain(r, r.LArm, 4, 0.26, HW.Iron, CF(0.55, -0.2, 0))
			Kit.chain(r, T, 3, 0.24, HW.Iron, CF(0.9, -0.95, -0.4))
		end
		-- топор: длинная рукоять, лезвие-полумесяц из 7 секторов (растёт с уровнем), огненная кромка с 2-го
		local top = shaft(r, A, -2.8, 2.6, lv >= 4 and HW.Black or HW.Wood, 0.26)
		bevel(r, A, V(0.36, 0.25, 0.36), CF(0, -2.8, -0.5), iron, false)
		local R = AXE_R[lv]
		local c = top + V(0, -0.4, -0.3)
		local bladeC = lv >= 5 and rgb(30, 26, 32) or iron
		local sector = V2(0.14, 2 * R * math.sin(rad(11.7)) + 0.1)
		local prev
		for k = 0, 6 do
			local phi = rad(-70 + k * 23.3)
			local dir = V(0, math.sin(phi), -math.cos(phi))
			bar(r, A, c + dir * 0.25, c + dir * R, sector, bladeC, M.Metal)
			local rim = c + dir * (R * 0.94)
			if prev and lv >= 2 then
				bar(r, A, prev, rim, V2(0.16, 0.08), fire, M.Neon)
			end
			prev = rim
		end
		bevel(r, A, V(0.3, 0.6, 0.6), CF(top + V(0, -0.4, 0)), iron, HW.Edge)
		spike(r, A, top + V(0, -0.4, 0.2), top + V(0, -0.4, 0.8), 0.45, iron, M.Metal, true, 0.12) -- обух
		if lv >= 4 then
			Kit.crack(r, A, { c + V(0.08, 0.4, -0.5), c + V(0.08, 0.1, -0.8), c + V(0.08, -0.2, -0.6) }, 0.07, fire)
		end
		r:WeaponTrail(A, c + V(0, 0, -0.5), c + V(0, 0, -R), fire)
		muzzle(r, A, CF(c + V(0, 0, -R)))
		if lv >= 5 then -- плащ, угли на орбите, искры из шеи
			capeWith(r, 2.2, 3.4, HW.BurgDark, fire)
			r:Orbit("OrbitEmbers", T, CF(0, 0.2, 0), 2.4, 5, 0.32, fire)
			embers(r, ember, fire, 10, 0.3)
		end
		levelAura(r, lv, fire)
		return finish(r, id, { RS = { 25, 0, 0 }, LS = { 20, 0, -8 } })
	end

	------------------------------------------------------------------------
	-- 11. LANTERN KING (Secret) — Король фонарей с тыквенной головой
	------------------------------------------------------------------------
	local LANTERN_SCALE = { 1.0, 1.1, 1.2, 1.3, 1.45 }

	local function LanternKing(lv, id)
		local robeC, robeD = rgb(44, 20, 60), rgb(26, 12, 38)
		local fire = HW.Orange
		local r = figure(id, { Torso = robeC, Arm = robeC, Leg = robeD, Skin = HW.Pumpkin, Edge = HW.GoldDark })
		local T, Hd, A = r.Torso, r.Head, r.RArm
		Parts.hideHead(r)
		-- голова-тыква с вырезанным светящимся лицом и огнём внутри; золотая корона (выше и с камнями с 2-го)
		pumpkin(r, Hd, CF(0, 0.12, 0), 0.92, 1.45, HW.Pumpkin, HW.PumpkinDark, lv >= 5 and rgb(255, 220, 120) or rgb(255, 170, 50))
		local inner = r:Neon(Hd, V(0.9, 0.9, 0.9), CF(0, 0.12, 0), rgb(255, 120, 20), { Transparency = 0.2 })
		r:Glow(inner, fire, 12, 1.8)
		Parts.kingCrown(r, Hd, CF(0, 0.82, 0), 0.62, lv >= 2 and 0.85 or 0.65, HW.Gold, lv >= 2 and fire or nil, 8)
		-- королевская мантия: золотая полоса, огненный камень, меховой воротник с тыквенными кисточками
		robe(r, robeD, HW.Gold, 2.0)
		bevel(r, T, V(2.14, 2.0, 1.14), CF(), robeC, HW.GoldDark, M.Fabric)
		r:Box(T, V(0.4, 2.0, 0.06), CF(0, 0, -0.58), HW.Gold, M.Fabric)
		Kit.gem(r, T, 0.4, CF(0, 0.45, -0.64), fire, HW.Gold)
		belt(r, HW.Black, HW.Gold, fire)
		bevel(r, T, V(2.5, 0.45, 1.4), CF(0, 0.92, 0), HW.Black, HW.PumpkinDark, M.Fabric)
		for k = -2, 2 do
			r:Box(T, V(0.3, 0.2, 0.06), CF(k * 0.45, 0.92, -0.71), HW.PumpkinDark, M.Fabric)
		end
		if lv >= 4 then
			Parts.bigShoulders(r, HW.Gold, HW.GoldDark, fire, 1.0, 1)
		else
			mantle(r, robeC, HW.GoldDark)
		end
		cuffs(r, V(1.08, 0.45, 1.08), -0.75, HW.Gold)
		capeWith(r, 2.2, lv >= 3 and 3.6 or 3.2, lv >= 3 and HW.Burgundy or robeD, fire)
		-- посох: чёрное древко с золотыми кольцами, крюк, фонарь (растёт с уровнем) с тыковкой внутри
		local top = shaft(r, A, -2.6, 2.4, HW.Black, 0.22)
		for _, y in ipairs({ -1.6, 0.4, 1.6 }) do
			bevel(r, A, V(0.34, 0.14, 0.34), CF(0, y, -0.5), HW.Gold, false)
		end
		local hook = { top, top + V(0, 0.5, -0.1), top + V(0, 0.7, -0.5), top + V(0, 0.5, -0.85) }
		for i = 1, 3 do
			bar(r, A, hook[i], hook[i + 1], V2(0.14, 0.14), HW.Gold, M.Metal)
		end
		local s = LANTERN_SCALE[lv]
		local lc = hook[4] + V(0, -0.85 * s, 0)
		local flame = lantern(r, A, CF(lc), s, HW.Gold, rgb(255, 160, 40), rgb(255, 140, 50))
		pumpkin(r, A, CF(lc + V(0, -0.02 * s, 0)), 0.16 * s, 0.24 * s, HW.Pumpkin, HW.PumpkinDark, nil, { Cheap = true })
		embers(r, flame, fire, lv >= 4 and 10 or 5, 0.22)
		muzzle(r, A, CF(lc))
		if lv >= 3 then -- огненные тыквы на орбите (2, на 5-м — 4)
			local n = lv >= 5 and 4 or 2
			local hub = orbitHub(r, "OrbitPumpkins", T, CF(0, 1.2, 0))
			for i = 0, n - 1 do
				local a = i / n * PI * 2
				local at = CF(math.cos(a) * 2.6, math.sin(a * 2) * 0.3, math.sin(a) * 2.6) * ANG(0, -a - PI / 2, 0)
				pumpkin(r, hub, at, 0.38, 0.55, HW.Pumpkin, HW.PumpkinDark, rgb(255, 190, 70), { Cheap = true })
			end
		end
		if lv >= 5 then
			embers(r, T, fire, 12, 0.3)
		end
		levelAura(r, lv, fire)
		return finish(r, id, { RS = { 22, 0, 0 }, LS = { 12, 0, -10 } })
	end

	------------------------------------------------------------------------
	-- РЕГИСТРАЦИЯ (редкость — запасная; основная берётся из Config.Units[id].Rarity)
	------------------------------------------------------------------------
	local UNITS = {
		{ "NightWatchman", NightWatchman, "Common" },
		{ "Gravedigger", Gravedigger, "Rare" },
		{ "CursedScarecrow", CursedScarecrow, "Rare" },
		{ "CursedSheriff", CursedSheriff, "Epic" },
		{ "MidnightBellringer", MidnightBellringer, "Epic" },
		{ "PlagueDoctor", PlagueDoctor, "Legendary" },
		{ "PhantomKnight", PhantomKnight, "Legendary" },
		{ "DarkIllusionist", DarkIllusionist, "Legendary" },
		{ "HalloweenPuppeteer", HalloweenPuppeteer, "Mythic" },
		{ "HeadlessExecutioner", HeadlessExecutioner, "Mythic" },
		{ "LanternKing", LanternKing, "Secret" },
	}
	for _, u in ipairs(UNITS) do
		UnitModels.Register(u[1], u[2], u[3])
	end
end
