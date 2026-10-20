--!nocheck
-- VOID TD :: Models/Parts
-- Детали R6-фигур юнитов в угловатом стиле (тело — блоки R6 с фаской и светлым кантом; поверх — броня,
-- капюшоны, шлемы, плащи и оружие из блоков, клиньев и ромбов). Строится на Kit (Rig + bevel/spike/gem...).
-- Модули семейств (Units/Void, Shattered, Blood, Clockmaker, Halloween, Allies) используют ТОЛЬКО этот API.
--
-- Соглашения: r — rig из Parts.figure / Kit.Rig.new; A — рука (r.RArm / r.LArm), L — нога; перед фигуры — -Z.
--   Оружие в правой руке: клинок вперёд по -Z на высоте хвата GRIP; древковое — вертикально перед кулаком (z -0.5).
--   AIM = CF(0, GRIP, 0) * ANG(-90°, 0, 0) — рамка «вперёд оружия» для поднятой руки (idle RS ≈ 75°).
--   Каждый строитель оружия ставит r.Muzzle (невидимый "Muzzle" на острие/кристалле) и возвращает его;
--   o.Secondary = true — второе оружие: деталь-острие "Tip", r.Muzzle не меняется.
--
-- ПАЛИТРЫ / КОНСТАНТЫ
--   Parts.P (палитра юнитов = Kit.P), Parts.AC (= Kit.Colors), Parts.M (материалы), Parts.rgb, Parts.GRIP (-1.05), Parts.AIM
--   Parts.VOID (= P.Neon)
--   Parts.SH  Shattered: Blue BlueSoft Navy NavyD Edge
--   Parts.BL  Blood: Blood BloodSoft Crimson CrimsonD Edge Dark
--   Parts.CLK Clockmaker: Black Suit Gold GoldDark Bronze Silver Steel Dial Orange OrangeDim
--   Parts.HW  Halloween: Black Coal Night Purple PurpleDeep Violet Orange OrangeDim Pumpkin PumpkinDark Burgundy BurgDark
--             Gold GoldDark Edge EdgeCool Bone Straw StrawDark Burlap Wood WoodLight Leather Iron Green GreenDim Ghost
--             GhostDeep Red Pale Flame
--
-- ФИГУРА
--   figure(name, pal{Torso, Arm, Leg, Skin, Edge}) -> r   R6 (HeadSize 1.2), видимое тело — bevel-блоки; r.Pal, r.HeadBox (куб головы)
--   eyes(r, color, glow?, y=0.08)                       две щели-глаза (неон, если glow)
--   chest(r, color, edge, gemColor?)                    нагрудник (+ ромб)
--   belt(r, color, buckle, gemColor?)                   пояс с пряжкой (+ ромб)
--   tassets(r, color, edge)                             набедренники
--   robe(r, color, trim?, len=1.8)                      юбка-мантия с рваным краем (+ полоса trim)
--   mantle(r, color, edge)                              накидка на плечи + наплечья
--   hood(r, color, edge, eyeColor, peak=true)           капюшон с тёмным лицом и светящимися глазами (peak=false — без хвоста)
--   helm(r, color, edge, visor, crest?, tall?)          шлем с Т-визором (crest — цвет гребня)
--   wizardHat(r, color, band, edge)                     изогнутая остроконечная шляпа
--   crown(r, color, gemColor, h=0.75)                   корона с 8 зубцами
--   kabuto(r, color, edge, horn, mask)                  самурайский шлем с рогами и маской
--   plateShoulders(r, color, edge, s=1)                 простые наплечники-плиты
--   bigShoulders(r, color, edge, glow?, size=1, spikes=1)   ступенчатые наплечники Kit.pauldron на обе руки
--   bracers(r, color, edge)   greaves(r, color, edge, boots?)
--   wings(r, color, edge, glow?, span=1)                крылья из перьев на моторах WingR / WingL
--   capeWith(r, w, len, color, emblem?) -> cape         плащ с лохмотьями (+ ромб-эмблема)
--   levelAura(r, lv, color=P.Neon)                      эффекты уровня (вызывать перед Finish, после оружия):
--                                                       L4 искры на Muzzle, L5 кольцо "AuraRing" у ног + искры вверх + свет
-- ОРУЖИЕ (o — таблица опций; все цвета необязательны, по умолчанию палитра брони)
--   muzzle(r, limb, cf, secondary?) -> part
--   blade(r, A, {Y=GRIP, Len=3, W=0.5, Grip, Guard, GuardW=W+0.7, Blade, Edge, Glow, Core, Trail, Secondary})
--   dagger(r, A, glow?, len=1.2, color?, secondary?)
--   shaft(r, A, bottom, top, color=rgb(44,32,30), d=0.2) -> topPoint   древко (Wood)
--   staff(r, A, {Top=2.4, Wood, Prong, Glow, Big}) -> crystal
--   scythe(r, A, {Wood, Blade, Glow})   spear(r, A, {Top=2.6, Wood, Metal, Head, Edge, Glow, Axe, Wing})
--   hammer(r, A, {Head, Edge, Trim, Glow, Wood})   axe(r, A, {Wood, Head, Edge, Glow})
--   bow(r, A, {Wood, Glow, Tip, Grip, String})     (левая рука)   quiver(r, color, tipsColor)  (на спине)
--   crossbow(r, A, {Stock, Edge, Prong, Glow})   rifle(r, A, {Body, Edge, Glow, Barrel})   (рамка AIM)
--   shield(r, A, {Color, Edge, H=2.0, W=1.4, Rim, Gem})   (левая рука)
-- ЧАСОВЩИК (моторы с вращением по Z регистрируются в r.SpinRates[name] = rate)
--   octa(r, limb, a, depth, cf, color, mat=Metal) -> parts        восьмиугольник (a — до грани)
--   gear(r, limb, name?, pivot, a, depth, color, hubColor=CLK.Black, rate=1, mat) -> host, hub
--   clockFace(r, limb, cf, a, frame, prefix, handColor, glowHands?) -> hands   стрелки на моторах <prefix>Hour/<prefix>Minute
--   miniClock(r, limb, cf, a)
--   r.SpinRates[motor] = rate — любой мотор крутится вокруг своей оси Z (Anims.Apply), напр. MoonBack, SpinEclipse
--   stormFX(parts) -> parts   детали «бури»: атрибут StormFX = видимая прозрачность, Transparency = 1
--                             (пример: local m = r:Mark() ... строим ... Parts.stormFX(r:Since(m)))
-- ХЭЛЛОУИН
--   tri(r, limb, cf, w, h, color, mat=Neon, depth=0.05) -> {2 parts}   треугольник в плоскости XY cf, вершина вверх
--   hideHead(r)                     спрятать куб головы фигуры (r.HeadBox)
--   downIn(pose{x,y,z}) -> Vector3   «вниз по миру» в координатах руки в позе idle (висящие предметы, нити)
--   pumpkin(r, limb, cf, R, h, color, edge, faceColor?, {Cheap, Stem}) -> faceParts   тыква из 8 долек с лицом
--   lantern(r, limb, cf, s, frame, glow, glass=rgb(255,170,70)) -> flame
--   kingCrown(r, limb, cf, R, h, color, gemColor?, n=8)           корона-кольцо (4 или 8 граней) с зубцами
--   brimHat(r, color, band?, {Y=0.62, Brim=2.1, W=1.3, Hgt=0.6, Tilt, Edge})
--   crow(r, limb, cf, s, eye=HW.Orange)   star(r, limb, cf, s, color)   flask(r, limb, cf, s, liquid) -> liquid
--   bell(r, limb, cf, s, color, rim, glow) -> clapper   card(r, limb, cf, s, suit, back?)
--   thread(r, limb, a, b, color, d=0.035) -> part   embers(r, part, color, rate=8, size=0.25) -> emitter | nil
-- РУНЫ (3D-иконки без rig: заякоренные детали прямо в Model m, координаты — от центра иконки)
--   rpart(m, size, cf, color, mat=Plastic, props) -> Part      rwedge(m, size, cf, color, mat=Plastic, props) -> WedgePart
--   rlight(part, color, range=8) -> PointLight | nil (Lite)    (Brightness 1.4, без теней)

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("VoidTD")
local Kit = require(Shared.Models.Kit)

local Parts = {}

local V = Vector3.new
local V2 = Vector2.new
local CF = CFrame.new
local ANG = CFrame.Angles
local rad = math.rad
local PI = math.pi

local rgb = Kit.rgb
local M = Kit.M
local P = Kit.P
local AC = Kit.Colors
local bevel, spike, gem, bar = Kit.bevel, Kit.spike, Kit.gem, Kit.bar

local GRIP = -1.05 -- точка хвата в кисти (локально в руке)
local AIM = CF(0, GRIP, 0) * ANG(rad(-90), 0, 0)

Parts.P, Parts.AC, Parts.M, Parts.rgb, Parts.GRIP, Parts.AIM = P, AC, M, rgb, GRIP, AIM
Parts.VOID = P.Neon
Parts.SH = { Blue = rgb(90, 150, 255), BlueSoft = rgb(170, 210, 255), Navy = rgb(30, 40, 84), NavyD = rgb(18, 22, 46), Edge = rgb(110, 130, 176) }
Parts.BL = { Blood = rgb(235, 40, 56), BloodSoft = rgb(255, 130, 140), Crimson = rgb(96, 14, 24), CrimsonD = rgb(52, 9, 16), Edge = rgb(160, 110, 116), Dark = rgb(28, 20, 24) }
local CLK = {
	Black = rgb(20, 18, 24), Suit = rgb(34, 30, 40), Gold = rgb(214, 168, 72), GoldDark = rgb(150, 112, 50), Bronze = rgb(160, 106, 52),
	Silver = rgb(172, 174, 188), Steel = rgb(58, 54, 64), Dial = rgb(14, 12, 18), Orange = rgb(255, 140, 40), OrangeDim = rgb(140, 70, 24),
}
Parts.CLK = CLK
local HW = {
	Black = rgb(18, 14, 22), Coal = rgb(32, 26, 38), Night = rgb(26, 22, 40), Purple = rgb(58, 30, 86), PurpleDeep = rgb(36, 18, 54),
	Violet = rgb(150, 70, 230), Orange = rgb(255, 130, 30), OrangeDim = rgb(170, 78, 22), Pumpkin = rgb(214, 104, 28),
	PumpkinDark = rgb(150, 66, 18), Burgundy = rgb(98, 22, 38), BurgDark = rgb(58, 14, 24), Gold = rgb(214, 168, 70),
	GoldDark = rgb(146, 108, 46), Edge = rgb(150, 124, 96), EdgeCool = rgb(120, 112, 140), Bone = rgb(222, 212, 192),
	Straw = rgb(206, 166, 82), StrawDark = rgb(150, 112, 52), Burlap = rgb(150, 118, 78), Wood = rgb(74, 48, 30),
	WoodLight = rgb(120, 82, 50), Leather = rgb(62, 40, 30), Iron = rgb(70, 68, 78), Green = rgb(120, 255, 110),
	GreenDim = rgb(60, 140, 60), Ghost = rgb(110, 190, 255), GhostDeep = rgb(40, 80, 150), Red = rgb(235, 30, 50),
	Pale = rgb(196, 190, 200), Flame = rgb(255, 190, 80),
}
Parts.HW = HW

local SIDES = { -1, 1 }

------------------------------------------------------------------------
-- ФИГУРА
------------------------------------------------------------------------
function Parts.figure(name, pal)
	local arm, leg = pal.Arm or pal.Torso, pal.Leg or pal.Torso
	local r = Kit.Rig.new({ Name = name, HeadSize = V(1.2, 1.2, 1.2), Torso = pal.Torso, Arm = arm, Leg = leg, Head = pal.Skin or pal.Torso })
	for _, L in ipairs({ r.Torso, r.Head, r.RArm, r.LArm, r.RLeg, r.LLeg }) do
		L.Transparency = 1
	end
	local e = pal.Edge or AC.Edge
	bevel(r, r.Torso, V(2, 2, 1), CF(), pal.Torso, e)
	bevel(r, r.RArm, V(1, 2, 1), CF(), arm, e)
	bevel(r, r.LArm, V(1, 2, 1), CF(), arm, e)
	bevel(r, r.RLeg, V(1, 2, 1), CF(), leg, e)
	bevel(r, r.LLeg, V(1, 2, 1), CF(), leg, e)
	r.HeadBox = r:Box(r.Head, V(1.2, 1.2, 1.2), CF(), pal.Skin or rgb(70, 62, 80), M.Plastic)
	r.Pal = pal
	return r
end

function Parts.eyes(r, color, glow, y)
	for _, s in ipairs(SIDES) do
		if glow then
			r:Neon(r.Head, V(0.22, 0.12, 0.05), CF(0.24 * s, y or 0.08, -0.61), color)
		else
			r:Box(r.Head, V(0.22, 0.12, 0.05), CF(0.24 * s, y or 0.08, -0.61), color)
		end
	end
end

function Parts.chest(r, color, edge, gemColor)
	bevel(r, r.Torso, V(2.14, 1.05, 1.16), CF(0, 0.5, 0), color, edge)
	if gemColor then
		gem(r, r.Torso, 0.36, CF(0, 0.5, -0.62), gemColor, edge)
	end
end

function Parts.belt(r, color, buckle, gemColor)
	bevel(r, r.Torso, V(2.1, 0.3, 1.12), CF(0, -0.82, 0), color, false, M.Fabric)
	bevel(r, r.Torso, V(0.42, 0.4, 0.12), CF(0, -0.82, -0.6), buckle, false)
	if gemColor then
		gem(r, r.Torso, 0.16, CF(0, -0.82, -0.68), gemColor)
	end
end

function Parts.tassets(r, color, edge)
	for _, s in ipairs(SIDES) do
		bevel(r, r.Torso, V(0.85, 0.75, 0.2), CF(0.5 * s, -1.32, -0.56) * ANG(rad(-6), 0, 0), color, edge)
	end
end

function Parts.robe(r, color, trim, len)
	len = len or 1.8
	bevel(r, r.Torso, V(2.12, len, 1.14), CF(0, -1 - len / 2 + 0.1, 0), color, trim, M.Fabric)
	Kit.tatter(r, r.Torso, -1 - len + 0.1, -0.57, 2.1, 5, color, M.Fabric, 3)
	if trim then
		r:Box(r.Torso, V(0.3, len, 0.05), CF(0, -1 - len / 2 + 0.1, -0.58), trim, M.Fabric)
	end
end

function Parts.mantle(r, color, edge)
	bevel(r, r.Torso, V(2.35, 0.4, 1.3), CF(0, 0.88, 0), color, edge, M.Fabric)
	for _, s in ipairs(SIDES) do
		bevel(r, s == 1 and r.RArm or r.LArm, V(1.18, 0.7, 1.18), CF(0.05 * s, 0.68, 0), color, edge, M.Fabric)
	end
end

function Parts.hood(r, color, edge, eyeColor, peak)
	local H = r.Head
	bevel(r, H, V(1.44, 0.28, 1.44), CF(0, 0.72, 0.03), color, edge, M.Fabric)
	for _, s in ipairs(SIDES) do
		bevel(r, H, V(0.22, 1.32, 1.44), CF(0.72 * s, 0.06, 0.03), color, edge, M.Fabric)
	end
	bevel(r, H, V(1.44, 1.32, 0.22), CF(0, 0.06, 0.72), color, edge, M.Fabric)
	r:Wedge(H, V(1.44, 0.32, 0.4), CF(0, 0.58, -0.62), color, M.Fabric)
	if peak ~= false then
		spike(r, H, V(0, 0.8, 0.45), V(0, 1.15, 1.0), 0.7, color, M.Fabric, true, 0.2)
	end
	r:Box(H, V(1.04, 1.02, 0.05), CF(0, -0.02, -0.61), rgb(12, 9, 18), M.Plastic)
	Parts.eyes(r, eyeColor, true, 0.06)
end

function Parts.helm(r, color, edge, visor, crest, tall)
	local H = r.Head
	bevel(r, H, V(1.32, tall and 1.45 or 1.32, 1.34), CF(0, tall and 0.1 or 0.03, 0), color, edge)
	r:Neon(H, V(0.6, 0.09, 0.05), CF(0, 0.14, -0.68), visor)
	r:Neon(H, V(0.09, 0.42, 0.05), CF(0, -0.08, -0.68), visor)
	if crest then
		local lift = tall and 0.1 or 0
		spike(r, H, V(0, 0.6 + lift, -0.25), V(0, 1.25 + (tall and 0.15 or 0), 0.25), 0.75, crest, M.Metal, true, 0.12)
	end
end

function Parts.wizardHat(r, color, band, edge)
	local H = r.Head
	bevel(r, H, V(2.3, 0.14, 2.3), CF(0, 0.64, 0), color, edge, M.Fabric)
	bevel(r, H, V(1.4, 0.24, 1.4), CF(0, 0.82, 0), band, false, M.Fabric)
	bevel(r, H, V(1.3, 0.55, 1.3), CF(0, 1.18, 0), color, edge, M.Fabric)
	bevel(r, H, V(0.95, 0.5, 0.95), CF(0.06, 1.6, 0.08) * ANG(rad(-8), 0, rad(-6)), color, edge, M.Fabric)
	bevel(r, H, V(0.6, 0.45, 0.6), CF(0.18, 1.98, 0.22) * ANG(rad(-18), 0, rad(-14)), color, edge, M.Fabric)
	spike(r, H, V(0.26, 2.15, 0.3), V(0.55, 2.55, 0.65), 0.5, color, M.Fabric)
end

function Parts.crown(r, color, gemColor, h)
	local H = r.Head
	h = h or 0.75
	for i = 0, 3 do
		r:Box(H, V(1.42, 0.26, 0.12), CF(0, 0.72, 0) * ANG(0, i * PI / 2, 0) * CF(0, 0, -0.66), color, M.Metal)
	end
	for i = 0, 7 do
		local a = i / 8 * PI * 2
		local p = V(math.sin(a) * 0.66, 0.8, -math.cos(a) * 0.66)
		spike(r, H, p, p + V(0, i % 2 == 0 and h or h * 0.6, 0), 0.32, color, M.Metal, true, 0.1)
	end
	gem(r, H, 0.24, CF(0, 0.74, -0.73), gemColor)
end

function Parts.kabuto(r, color, edge, horn, mask)
	local H = r.Head
	bevel(r, H, V(1.38, 0.62, 1.42), CF(0, 0.5, 0.02), color, edge)
	for i = 0, 1 do -- сикоро: пластины на затылке и по бокам
		bevel(r, H, V(1.62 + i * 0.2, 0.26, 0.26), CF(0, 0.05 - i * 0.26, 0.74 + i * 0.08) * ANG(rad(25), 0, 0), color, edge)
		for _, s in ipairs(SIDES) do
			bevel(r, H, V(0.26, 0.26, 1.2 + i * 0.15), CF(s * (0.78 + i * 0.08), 0.05 - i * 0.26, 0.12) * ANG(0, 0, rad(-25 * s)), color, edge)
		end
	end
	r:Box(H, V(0.96, 0.46, 0.08), CF(0, -0.3, -0.63), mask, M.Metal)
	r:Neon(H, V(0.46, 0.05, 0.05), CF(0, -0.36, -0.68), horn)
	for _, s in ipairs(SIDES) do
		Kit.hornA(r, H, { V(0.2 * s, 0.6, -0.7), V(0.45 * s, 0.95, -0.85), V(0.7 * s, 1.45, -0.8), V(0.75 * s, 1.85, -0.65) }, 0.14, horn, M.Metal)
	end
	Parts.eyes(r, horn, true, 0.12)
end

function Parts.plateShoulders(r, color, edge, s)
	s = s or 1
	for _, side in ipairs({ 1, -1 }) do
		bevel(r, side == 1 and r.RArm or r.LArm, V(1.3, 0.5, 1.25) * s, CF(0.12 * side, 0.9, 0) * ANG(0, 0, rad(-12 * side)), color, edge)
	end
end

function Parts.bigShoulders(r, color, edge, glow, size, spikes)
	Kit.pauldron(r, r.RArm, 1, size or 1, color, edge, glow, spikes or 1)
	Kit.pauldron(r, r.LArm, -1, size or 1, color, edge, glow, spikes or 1)
end

function Parts.bracers(r, color, edge)
	for _, A in ipairs({ r.RArm, r.LArm }) do
		bevel(r, A, V(1.14, 0.75, 1.14), CF(0, -0.55, 0), color, edge)
	end
end

function Parts.greaves(r, color, edge, boots)
	for _, L in ipairs({ r.RLeg, r.LLeg }) do
		bevel(r, L, V(1.12, 0.7, 1.14), CF(0, -0.35, 0), color, edge)
		if boots then
			Kit.bootA(r, L, color, edge, 1.12)
		end
	end
end

local FEATHERS = { 2.8, 2.5, 2.1, 1.7, 1.3 }
function Parts.wings(r, color, edge, glow, span)
	span = span or 1
	for _, side in ipairs({ 1, -1 }) do
		local w = r:Joint(side == 1 and "WingR" or "WingL", r.Torso, V(0.3, 0.3, 0.3), CF(0.45 * side, 0.6, 0.6), CF(), color)
		w.Transparency = 1
		for i, L in ipairs(FEATHERS) do
			local th = rad(28 + (i - 1) * 24)
			L = L * span
			local at = CF(side * math.sin(th) * L / 2, math.cos(th) * L / 2, 0.15 + i * 0.03) * ANG(0, 0, -side * th)
			bevel(r, w, V(0.5, L, 0.16), at, color, edge, M.Plastic)
			if glow and i <= 2 then
				r:Neon(w, V(0.08, L * 0.8, 0.18), at * CF(0.2 * side, 0, 0), glow)
			end
		end
	end
end

function Parts.capeWith(r, w, len, color, emblem)
	local cape = r:Cape(w, len, color, true)
	if emblem then
		gem(r, cape, 0.5, CF(0, 0.1, 0.08) * ANG(0, PI, 0), emblem)
	end
	return cape
end

-- Эффекты прокачки: L4 искры на оружии, L5 светящееся кольцо у ног, искры вверх и подсветка
function Parts.levelAura(r, lv, color)
	color = color or P.Neon
	local mz = r.Muzzle
	if lv >= 4 and mz and mz:IsA("BasePart") then
		local own = mz:FindFirstChild("Sparkles")
		if own and own:IsA("ParticleEmitter") then
			own.Rate = own.Rate + 6 -- уже искрит (VoidKnight L3): гуще, без второго эмиттера
		else
			r:Sparkles(mz, color, { Rate = 6, Size = 0.25 })
		end
	end
	if lv >= 5 then
		r:Add(r.Torso, "Part", V(0.08, 3.8, 3.8), CF(0, -2.96, 0) * ANG(0, 0, rad(90)), color, M.Neon,
			{ Shape = Enum.PartType.Cylinder, Transparency = 0.78, Name = "AuraRing" })
		r:Sparkles(r.Torso, color, { Rate = 10, Up = 3, Size = 0.3, LifeMin = 0.8, LifeMax = 1.4 })
		r:Glow(r.Torso, color, 10, 1.2)
	end
end

------------------------------------------------------------------------
-- ОРУЖИЕ
------------------------------------------------------------------------
local function muzzle(r, limb, cf, secondary)
	local m = r:Box(limb, V(0.2, 0.2, 0.2), cf, P.Black, M.Plastic, { Transparency = 1, Name = secondary and "Tip" or "Muzzle" })
	if not secondary then
		r.Muzzle = m
	end
	return m
end
Parts.muzzle = muzzle

function Parts.blade(r, A, o)
	o = o or {}
	local y = o.Y or GRIP
	local len, w = o.Len or 3, o.W or 0.5
	local z0 = -0.56
	local bladeC = o.Blade or AC.ArmorMid
	r:Box(A, V(0.22, 0.22, 0.85), CF(0, y, 0.1), o.Grip or AC.ClothDark, M.Fabric)
	r:Box(A, V(0.3, 0.3, 0.25), CF(0, y, 0.6) * ANG(0, 0, rad(45)), o.Guard or AC.Armor, M.Metal)
	bevel(r, A, V(0.28, o.GuardW or (w + 0.7), 0.28), CF(0, y, -0.42), o.Guard or AC.Armor, o.Edge)
	r:Box(A, V(0.12, w, len), CF(0, y, z0 - len / 2), bladeC, M.Metal)
	if o.Glow then
		for _, s in ipairs({ 1, -1 }) do -- верхняя и нижняя кромки
			r:Neon(A, V(0.14, 0.07, len * 0.96), CF(0, y + s * (w / 2 - 0.03), z0 - len / 2), o.Glow)
		end
	end
	if o.Core then
		r:Neon(A, V(0.14, 0.08, len * 0.7), CF(0, y, z0 - len * 0.42), o.Core)
	end
	spike(r, A, V(0, y, z0 - len + 0.02), V(0, y, z0 - len - w * 1.2), w, bladeC, M.Metal, true, 0.12)
	r:WeaponTrail(A, V(0, y, z0 - 0.15), V(0, y, z0 - len - w), o.Trail or o.Glow or P.NeonSoft)
	return muzzle(r, A, CF(0, y, z0 - len - w), o.Secondary)
end

function Parts.dagger(r, A, glow, len, color, secondary)
	return Parts.blade(r, A, { Len = len or 1.2, W = 0.32, GuardW = 0.7, Blade = color or AC.ArmorMid, Glow = glow, Guard = AC.Armor, Secondary = secondary })
end

-- Вертикальное древко перед кулаком; возвращает верхнюю точку
local function shaft(r, A, bottom, top, color, d)
	d = d or 0.2
	r:Box(A, V(d, top - bottom, d), CF(0, (top + bottom) / 2, -0.5), color or rgb(44, 32, 30), M.Wood)
	return V(0, top, -0.5)
end
Parts.shaft = shaft

function Parts.staff(r, A, o)
	o = o or {}
	local top = shaft(r, A, -2.5, o.Top or 2.4, o.Wood, 0.2)
	local c = top + V(0, 0.45, 0)
	for k = 0, 3 do
		local a = k / 4 * PI * 2 + PI / 4
		local dx, dz = math.cos(a), math.sin(a)
		spike(r, A, top + V(dx * 0.15, -0.1, dz * 0.15), c + V(dx * 0.35, 0.35, dz * 0.35), 0.16, o.Prong or AC.Armor, M.Metal, true, 0.08)
	end
	local g = r:Neon(A, V(0.45, 0.45, 0.45), CF(c) * ANG(rad(45), 0, rad(45)), o.Glow)
	if o.Big then
		r:Box(A, V(0.7, 0.7, 0.7), CF(c) * ANG(rad(45), 0, rad(45)), o.Glow, M.Glass, { Transparency = 0.6 })
	end
	muzzle(r, A, CF(c), o.Secondary)
	return g
end

function Parts.scythe(r, A, o)
	o = o or {}
	local top = shaft(r, A, -2.6, 2.6, o.Wood, 0.2)
	local bladeC = o.Blade or AC.ArmorMid
	local pts = { top + V(0, -0.05, 0.1), top + V(0, 0.25, -0.8), top + V(0, 0.05, -1.7), top + V(0, -0.4, -2.4) }
	for i = 1, #pts - 1 do
		bar(r, A, pts[i], pts[i + 1], V2(0.12, 0.42 - i * 0.07), bladeC)
		if o.Glow then
			bar(r, A, pts[i] + V(0, -0.2 + i * 0.03, 0), pts[i + 1] + V(0, -0.17 + i * 0.03, 0), V2(0.14, 0.06), o.Glow, M.Neon)
		end
	end
	spike(r, A, pts[4], pts[4] + V(0, -0.55, -0.4), 0.26, bladeC, M.Metal, true, 0.12)
	r:WeaponTrail(A, top + V(0, 0, -0.8), pts[4], o.Glow or P.NeonSoft)
	return muzzle(r, A, CF(pts[4]), o.Secondary)
end

function Parts.spear(r, A, o)
	o = o or {}
	local top = shaft(r, A, -2.4, o.Top or 2.6, o.Wood, 0.2)
	local head = o.Head or AC.ArmorMid
	bevel(r, A, V(0.34, 0.3, 0.34), CF(top), o.Metal or AC.Armor, o.Edge)
	spike(r, A, top + V(0, 0.1, 0), top + V(0, 1.1, 0), 0.5, head, M.Metal)
	if o.Glow then
		r:Neon(A, V(0.08, 0.6, 0.08), CF(top + V(0, 0.45, -0.13)), o.Glow)
	end
	if o.Axe then
		bevel(r, A, V(0.12, 0.8, 0.7), CF(top + V(0, -0.2, -0.45)), head, o.Edge)
		spike(r, A, top + V(0, -0.2, -0.75), top + V(0, -0.2, -1.2), 0.8, head, M.Metal, true, 0.12)
	end
	if o.Wing then
		for _, s in ipairs(SIDES) do
			spike(r, A, top + V(0.1 * s, 0, 0), top + V(0.55 * s, 0.35, 0), 0.22, o.Metal or AC.Armor, M.Metal, true, 0.08)
		end
	end
	r:WeaponTrail(A, top, top + V(0, 1.1, 0), o.Glow or P.NeonSoft)
	return muzzle(r, A, CF(top + V(0, 1.1, 0)), o.Secondary)
end

function Parts.hammer(r, A, o)
	o = o or {}
	local top = shaft(r, A, -2.2, 2.0, o.Wood or AC.Armor, 0.24)
	local c = top + V(0, 0.35, 0)
	bevel(r, A, V(0.95, 0.95, 1.8), CF(c), o.Head, o.Edge)
	for _, z in ipairs({ -0.65, 0.65 }) do
		bevel(r, A, V(1.05, 1.05, 0.18), CF(c + V(0, 0, z)), o.Trim or o.Edge, false)
	end
	gem(r, A, 0.45, CF(c + V(-0.49, 0, 0)) * ANG(0, PI / 2, 0), o.Glow)
	gem(r, A, 0.45, CF(c + V(0.49, 0, 0)) * ANG(0, -PI / 2, 0), o.Glow)
	spike(r, A, c + V(0, 0.45, 0), c + V(0, 1.0, 0), 0.4, o.Trim or o.Head, M.Metal)
	r:WeaponTrail(A, top, c + V(0, 0, -0.9), o.Glow)
	return muzzle(r, A, CF(c), o.Secondary)
end

function Parts.axe(r, A, o)
	o = o or {}
	local top = shaft(r, A, -2.2, 2.2, o.Wood, 0.22)
	bevel(r, A, V(0.14, 1.3, 1.0), CF(top + V(0, -0.35, -0.55)), o.Head, o.Edge)
	spike(r, A, top + V(0, -0.35, -1.0), top + V(0, -0.35, -1.6), 1.5, o.Head, M.Metal, true, 0.14)
	if o.Glow then
		r:Neon(A, V(0.16, 1.4, 0.08), CF(top + V(0, -0.35, -1.08)), o.Glow)
	end
	spike(r, A, top, top + V(0, 0.6, 0), 0.3, o.Head, M.Metal)
	r:WeaponTrail(A, top + V(0, -0.35, -0.8), top + V(0, -0.35, -1.6), o.Glow or P.NeonSoft)
	return muzzle(r, A, CF(top + V(0, -0.35, -1.5)), o.Secondary)
end

-- Лук в левой руке: вертикально, тетива к стрелку
function Parts.bow(r, A, o)
	o = o or {}
	local g = V(0, GRIP, -0.45)
	r:Box(A, V(0.2, 0.5, 0.2), CF(g), o.Grip or AC.ClothDark, M.Fabric)
	local tips = {}
	for _, s in ipairs({ 1, -1 }) do
		local m = g + V(0, 0.9 * s, -0.2)
		local t = g + V(0, 1.75 * s, 0.25)
		bar(r, A, g, m, V2(0.14, 0.2), o.Wood)
		bar(r, A, m, t, V2(0.12, 0.16), o.Wood)
		if o.Glow then
			bar(r, A, g + V(0, 0.1 * s, -0.08), m + V(0, 0, -0.08), V2(0.15, 0.05), o.Glow, M.Neon)
		end
		spike(r, A, t, t + V(0, 0.3 * s, 0.15), 0.16, o.Tip or o.Wood, M.Metal, true, 0.08)
		tips[#tips + 1] = t
	end
	r:Box(A, V(0.04, (tips[1] - tips[2]).Magnitude, 0.04), CF((tips[1] + tips[2]) / 2), o.String or rgb(220, 210, 230), M.Plastic)
	return muzzle(r, A, CF(g + V(0, 0, -0.2)), o.Secondary)
end

function Parts.quiver(r, color, tips)
	bevel(r, r.Torso, V(0.5, 1.6, 0.5), CF(0.45, 0.2, 0.75) * ANG(0, 0, rad(-25)), color, false, M.Fabric)
	for k = -1, 1 do
		spike(r, r.Torso, V(0.75 + k * 0.1, 1.05, 0.75 + k * 0.08), V(0.95 + k * 0.1, 1.45, 0.75 + k * 0.08), 0.18, tips, M.Plastic, true, 0.05)
	end
end

-- Оружие для вытянутых вперёд рук строится в рамке AIM (ствол вперёд при поднятой руке)
function Parts.crossbow(r, A, o)
	o = o or {}
	local F = AIM
	bevel(r, A, V(0.32, 0.32, 1.9), F * CF(0, 0, -0.75), o.Stock, o.Edge)
	local f = -1.55
	for _, s in ipairs(SIDES) do
		bar(r, A, F * V(0, 0.05, f), F * V(0.6 * s, 0.05, f + 0.15), V2(0.18, 0.14), o.Prong)
		bar(r, A, F * V(0.6 * s, 0.05, f + 0.15), F * V(1.1 * s, 0.05, f + 0.4), V2(0.14, 0.12), o.Prong)
		spike(r, A, F * V(1.1 * s, 0.05, f + 0.4), F * V(1.35 * s, 0.05, f + 0.25), 0.2, o.Glow, M.Neon, true, 0.08)
	end
	r:Box(A, V(2.2, 0.03, 0.03), F * CF(0, 0.05, f + 0.4), rgb(200, 220, 255), M.Plastic)
	r:Neon(A, V(0.1, 0.1, 1.2), F * CF(0, 0.22, -1.1), o.Glow)
	spike(r, A, F * V(0, 0.22, -1.7), F * V(0, 0.22, -2.1), 0.22, o.Glow, M.Neon)
	return muzzle(r, A, F * CF(0, 0.22, -2.1), o.Secondary)
end

function Parts.rifle(r, A, o)
	o = o or {}
	local F = AIM
	bevel(r, A, V(0.42, 0.55, 1.9), F * CF(0, 0.05, -0.75), o.Body, o.Edge)
	bevel(r, A, V(0.32, 0.5, 0.75), F * CF(0, -0.05, 0.45), o.Body, o.Edge)
	r:Box(A, V(0.24, 0.24, 1.5), F * CF(0, 0.15, -2.4), o.Barrel or AC.ArmorMid, M.Metal)
	bevel(r, A, V(0.2, 0.2, 0.8), F * CF(0, 0.45, -0.7), o.Body, o.Edge)
	r:Neon(A, V(0.08, 0.08, 0.08), F * CF(0, 0.45, -1.12), o.Glow)
	for k = 0, 2 do
		r:Neon(A, V(0.32, 0.32, 0.08), F * CF(0, 0.15, -1.9 - k * 0.38), o.Glow)
	end
	r:Box(A, V(0.3, 0.6, 0.2), F * CF(0, -0.45, -0.6), o.Body, M.Metal)
	return muzzle(r, A, F * CF(0, 0.15, -3.2), o.Secondary)
end

function Parts.shield(r, A, o)
	o = o or {}
	local x, h, w = -0.68, o.H or 2.0, o.W or 1.4
	bevel(r, A, V(0.24, h, w), CF(x, -0.5, -0.1), o.Color, o.Edge)
	spike(r, A, V(x, -0.5 - h / 2 + 0.02, -0.1), V(x, -0.5 - h / 2 - 0.6, -0.1), w, o.Color, M.Metal, true, 0.24)
	if o.Rim then
		r:Box(A, V(0.26, h * 0.8, 0.12), CF(x - 0.01, -0.5, -0.1), o.Rim, M.Metal)
		r:Box(A, V(0.26, 0.12, w * 0.8), CF(x - 0.01, -0.3, -0.1), o.Rim, M.Metal)
	end
	if o.Gem then
		gem(r, A, 0.45, CF(x - 0.14, -0.3, -0.1) * ANG(0, PI / 2, 0), o.Gem, o.Edge)
	end
end

------------------------------------------------------------------------
-- ЧАСОВЩИК: восьмиугольники, шестерни, циферблаты (моторы вращения — в r.SpinRates)
------------------------------------------------------------------------
local function octa(r, limb, a, depth, cf, color, mat)
	local parts = {}
	for k = 0, 3 do
		parts[#parts + 1] = r:Box(limb, V(2 * a, 0.8284 * a, depth), cf * ANG(0, 0, k * PI / 4), color, mat or M.Metal)
	end
	return parts
end
Parts.octa = octa

-- Шестерня в плоскости XY; с именем — на своём моторе, крутится вокруг оси Z узла со скоростью rate
function Parts.gear(r, limb, name, pivot, a, depth, color, hubColor, rate, mat)
	local host, base = limb, pivot
	if name then
		host = r:Joint(name, limb, V(0.1, 0.1, 0.1), pivot, CF(), color)
		host.Transparency = 1
		base = CF()
		r.SpinRates = r.SpinRates or {}
		r.SpinRates[name] = rate or 1
	end
	octa(r, host, a, depth, base, color, mat)
	for k = 0, 7 do
		local ang = k * PI / 4
		r:Box(host, V(a * 0.36, a * 0.34, depth), base * CF(math.cos(ang) * a * 1.08, math.sin(ang) * a * 1.08, 0) * ANG(0, 0, ang), color, mat or M.Metal)
	end
	hubColor = hubColor or CLK.Black
	local hub = r:Box(host, V(a * 0.42, a * 0.42, depth + 0.04), base * ANG(0, 0, PI / 4), hubColor, hubColor == CLK.Orange and M.Neon or M.Metal)
	return host, hub
end

local HANDS = { { "Hour", 0.45, 0.11, 0.22 }, { "Minute", 0.68, 0.07, 1.6 } }
function Parts.clockFace(r, limb, cf, a, frame, prefix, handColor, glowHands)
	octa(r, limb, a, 0.5, cf, frame)
	octa(r, limb, a * 0.84, 0.54, cf, CLK.Dial, M.Plastic)
	for k = 0, 11 do
		local ang = k * PI / 6
		local big = k % 3 == 0
		r:Box(limb, V(a * 0.07, a * (big and 0.2 or 0.12), 0.04), cf * CF(math.cos(ang) * a * 0.68, math.sin(ang) * a * 0.68, -0.28) * ANG(0, 0, ang + PI / 2), handColor, M.Metal)
	end
	r.SpinRates = r.SpinRates or {}
	local hands = {}
	for i, h in ipairs(HANDS) do
		local name = prefix .. h[1]
		local hub = r:Joint(name, limb, V(0.1, 0.1, 0.1), cf * CF(0, 0, -0.3 - i * 0.02), CF(), handColor)
		hub.Transparency = 1
		r.SpinRates[name] = h[4]
		local size, at = V(a * h[3], a * h[2], 0.04), CF(0, a * h[2] * 0.42, 0)
		hands[i] = glowHands and r:Neon(hub, size, at, CLK.Orange) or r:Box(hub, size, at, handColor, M.Plastic)
	end
	r:Box(limb, V(a * 0.16, a * 0.16, 0.08), cf * CF(0, 0, -0.36) * ANG(0, 0, PI / 4), CLK.Gold, M.Metal)
	return hands
end

-- Детали, видимые только во время «бури» (Renderer / Viewer показывают их по атрибуту StormFX)
function Parts.stormFX(parts)
	for _, p in ipairs(parts or {}) do
		if p:IsA("BasePart") then
			p:SetAttribute("StormFX", p.Transparency)
			p.Transparency = 1
		end
	end
	return parts or {}
end

function Parts.miniClock(r, limb, cf, a)
	octa(r, limb, a, 0.12, cf, CLK.Gold)
	octa(r, limb, a * 0.8, 0.14, cf, CLK.Dial, M.Plastic)
	r:Box(limb, V(a * 0.12, a * 0.6, 0.04), cf * CF(0, a * 0.25, -0.09), CLK.Gold, M.Metal)
	r:Box(limb, V(a * 0.5, a * 0.1, 0.04), cf * CF(a * 0.2, 0, -0.1), CLK.Gold, M.Metal)
end

------------------------------------------------------------------------
-- ХЭЛЛОУИН
------------------------------------------------------------------------
local function tri(r, limb, cf, w, h, color, mat, depth)
	local F = cf * ANG(0, PI / 2, 0)
	local d = depth or 0.05
	return {
		r:Wedge(limb, V(d, h, w / 2), F * CF(0, 0, -w / 4), color, mat or M.Neon),
		r:Wedge(limb, V(d, h, w / 2), F * CF(0, 0, w / 4) * ANG(0, PI, 0), color, mat or M.Neon),
	}
end
Parts.tri = tri

function Parts.hideHead(r)
	if r.HeadBox then
		r.HeadBox.Transparency = 1
	end
end

function Parts.downIn(pose)
	local rot = ANG(rad(pose[1] or 0), rad(pose[2] or 0), rad(pose[3] or 0))
	return (rot:Inverse() * V(0, -1, 0)).Unit
end

-- Тыква из 8 долек вокруг оси Y; лицо смотрит в -Z. Возвращает детали лица
function Parts.pumpkin(r, limb, cf, R, h, color, edge, faceColor, o)
	o = o or {}
	local w = 2 * R * math.tan(rad(22.5)) * 1.12
	local mid = color:Lerp(edge, 0.35)
	for k = 0, 7 do
		local a = k * PI / 4
		local even = k % 2 == 0
		r:Box(limb, V(w, even and h or h * 0.9, R * 0.8), cf * CF(math.sin(a) * R * 0.6, 0, -math.cos(a) * R * 0.6) * ANG(0, -a, 0), even and color or mid, M.Plastic)
		if not o.Cheap and not Kit.IsLite() then -- тёмные бороздки
			local g = a + PI / 8
			r:Box(limb, V(0.06, h * 0.86, 0.06), cf * CF(math.sin(g) * R * 0.97, 0, -math.cos(g) * R * 0.97) * ANG(0, -g, 0), edge, M.Plastic)
		end
	end
	r:Box(limb, V(R * 1.3, h * 0.1, R * 1.3), cf * CF(0, h / 2 - h * 0.02, 0) * ANG(0, PI / 4, 0), edge, M.Plastic)
	bar(r, limb, cf * V(0, h / 2, 0), cf * V(0.08 * R, h / 2 + h * 0.26, 0.05 * R), V2(0.16 * R, 0.16 * R), o.Stem or rgb(66, 74, 34), M.Wood)
	local face = {}
	if faceColor then
		local z = -R - 0.03
		local function add(list)
			for _, p in ipairs(list) do
				face[#face + 1] = p
			end
		end
		for _, s in ipairs(SIDES) do
			add(tri(r, limb, cf * CF(0.3 * R * s, h * 0.14, z) * ANG(0, 0, rad(8 * s)), 0.36 * R, 0.3 * R, faceColor, M.Neon, 0.06))
		end
		if not o.Cheap then
			add(tri(r, limb, cf * CF(0, -h * 0.02, z), 0.14 * R, 0.13 * R, faceColor, M.Neon, 0.06))
		end
		face[#face + 1] = r:Neon(limb, V(0.95 * R, 0.17 * R, 0.06), cf * CF(0, -h * 0.22, z), faceColor)
		if not o.Cheap then -- зубы
			for _, x in ipairs({ -0.24, 0.24 }) do
				r:Box(limb, V(0.14 * R, 0.1 * R, 0.07), cf * CF(x * R, -h * 0.19, z - 0.01), color, M.Plastic)
			end
			r:Box(limb, V(0.14 * R, 0.1 * R, 0.07), cf * CF(0, -h * 0.25, z - 0.01), color, M.Plastic)
		end
	end
	return face
end

-- Фонарь: крыша, кольцо, стойки, стекло, огонёк. cf — центр стекла
function Parts.lantern(r, limb, cf, s, frame, glow, glass)
	bevel(r, limb, V(0.72, 0.16, 0.72) * s, cf * CF(0, 0.42 * s, 0), frame, false)
	spike(r, limb, cf * V(0, 0.48 * s, 0), cf * V(0, 0.8 * s, 0), 0.52 * s, frame, M.Metal)
	r:Box(limb, V(0.06, 0.3, 0.3) * s, cf * CF(0, 0.92 * s, 0), frame, M.Metal)
	r:Box(limb, V(0.06, 0.06, 0.3) * s, cf * CF(0, 1.06 * s, 0), frame, M.Metal)
	for _, x in ipairs(SIDES) do
		for _, z in ipairs(SIDES) do
			r:Box(limb, V(0.07, 0.7, 0.07) * s, cf * CF(0.27 * s * x, 0, 0.27 * s * z), frame, M.Metal)
		end
	end
	r:Box(limb, V(0.5, 0.6, 0.5) * s, cf, glass or rgb(255, 170, 70), M.Glass, { Transparency = 0.45 })
	local flame = r:Neon(limb, V(0.22, 0.32, 0.22) * s, cf * CF(0, -0.03 * s, 0) * ANG(0, PI / 4, 0), glow)
	bevel(r, limb, V(0.66, 0.14, 0.66) * s, cf * CF(0, -0.38 * s, 0), frame, false)
	r:Glow(flame, glow, 9, 1.4)
	return flame
end

-- Корона-кольцо (4 или 8 граней) с зубцами-треугольниками; cf — центр низа
function Parts.kingCrown(r, limb, cf, R, h, color, gemColor, n)
	n = n or 8
	local sides = n <= 4 and 4 or 8
	local w = 2 * R * math.tan(PI / sides) * 1.1
	for k = 0, sides - 1 do
		local a = k * 2 * PI / sides
		r:Box(limb, V(w, h * 0.32, 0.12), cf * CF(math.sin(a) * R, h * 0.16, -math.cos(a) * R) * ANG(0, -a, 0), color, M.Metal)
	end
	for k = 0, n - 1 do
		local a = k * 2 * PI / n
		local hh = k % 2 == 0 and h or h * 0.62
		tri(r, limb, cf * CF(math.sin(a) * R, h * 0.3 + hh / 2, -math.cos(a) * R) * ANG(0, -a, 0), 0.36, hh, color, M.Metal, 0.12)
	end
	if gemColor then
		gem(r, limb, 0.22, cf * CF(0, h * 0.16, -R - 0.07), gemColor)
		if sides == 8 then
			gem(r, limb, 0.15, cf * CF(R * 0.72, h * 0.16, -R * 0.72 - 0.07) * ANG(0, rad(-45), 0), gemColor)
			gem(r, limb, 0.15, cf * CF(-R * 0.72, h * 0.16, -R * 0.72 - 0.07) * ANG(0, rad(45), 0), gemColor)
		end
	end
end

function Parts.brimHat(r, color, band, o)
	o = o or {}
	local Hd = r.Head
	local y, w, hgt = o.Y or 0.62, o.W or 1.3, o.Hgt or 0.6
	local tilt = ANG(rad(o.Tilt or 0), 0, 0)
	bevel(r, Hd, V(o.Brim or 2.1, 0.12, o.Brim or 2.1), CF(0, y, 0) * tilt, color, o.Edge or false, M.Fabric)
	bevel(r, Hd, V(w, hgt, w), CF(0, y + hgt / 2, 0) * tilt, color, o.Edge or false, M.Fabric)
	if band then
		r:Box(Hd, V(w + 0.04, 0.14, w + 0.04), CF(0, y + 0.12, 0) * tilt, band, M.Fabric)
	end
end

-- Ворона сидит на limb в точке cf (клюв в -Z cf)
function Parts.crow(r, limb, cf, s, eye)
	bevel(r, limb, V(0.36, 0.34, 0.6) * s, cf * CF(0, 0.17 * s, 0), HW.Black, rgb(60, 54, 70), M.Plastic)
	r:Box(limb, V(0.3, 0.28, 0.3) * s, cf * CF(0, 0.42 * s, -0.3 * s), HW.Black, M.Plastic)
	spike(r, limb, cf * V(0, 0.4 * s, -0.44 * s), cf * V(0, 0.36 * s, -0.72 * s), 0.14 * s, rgb(70, 60, 50), M.Plastic, true, 0.06)
	for _, x in ipairs(SIDES) do
		r:Neon(limb, V(0.04, 0.06, 0.06) * s, cf * CF(0.15 * s * x, 0.47 * s, -0.38 * s), eye or HW.Orange)
		r:Wedge(limb, V(0.06, 0.24, 0.5) * s, cf * CF(0.2 * s * x, 0.24 * s, 0.05 * s), rgb(30, 26, 38), M.Plastic)
	end
	spike(r, limb, cf * V(0, 0.2 * s, 0.28 * s), cf * V(0, 0.12 * s, 0.62 * s), 0.26 * s, HW.Black, M.Plastic, true, 0.05)
end

-- Пятиконечная звезда (значок шерифа) в плоскости XY
function Parts.star(r, limb, cf, s, color)
	for k = 0, 4 do
		tri(r, limb, cf * ANG(0, 0, k * 2 * PI / 5) * CF(0, 0.18 * s, 0), 0.22 * s, 0.32 * s, color, M.Metal, 0.05)
	end
	r:Box(limb, V(0.2, 0.2, 0.06) * s, cf * ANG(0, 0, rad(45)), color, M.Metal)
end

function Parts.flask(r, limb, cf, s, liquid)
	local glass = rgb(180, 220, 200)
	r:Box(limb, V(0.36, 0.42, 0.36) * s, cf, glass, M.Glass, { Transparency = 0.5 })
	local l = r:Neon(limb, V(0.3, 0.26, 0.3) * s, cf * CF(0, -0.06 * s, 0), liquid)
	r:Box(limb, V(0.14, 0.2, 0.14) * s, cf * CF(0, 0.3 * s, 0), glass, M.Glass, { Transparency = 0.5 })
	r:Box(limb, V(0.12, 0.08, 0.12) * s, cf * CF(0, 0.43 * s, 0), HW.Wood, M.Wood)
	return l
end

-- Колокол из уступов: cf — точка подвеса, колокол висит вниз; возвращает светящийся язычок
function Parts.bell(r, limb, cf, s, color, rim, glow)
	bevel(r, limb, V(0.3, 0.2, 0.3) * s, cf * CF(0, -0.1 * s, 0), color, false)
	bevel(r, limb, V(0.55, 0.3, 0.55) * s, cf * CF(0, -0.32 * s, 0), color, rim)
	bevel(r, limb, V(0.72, 0.34, 0.72) * s, cf * CF(0, -0.62 * s, 0), color, rim)
	bevel(r, limb, V(0.95, 0.18, 0.95) * s, cf * CF(0, -0.86 * s, 0), rim, false)
	r:Box(limb, V(0.5, 0.1, 0.5) * s, cf * CF(0, -0.96 * s, 0), rgb(10, 8, 14), M.Plastic)
	return r:Neon(limb, V(0.2, 0.2, 0.2) * s, cf * CF(0, -1.04 * s, 0) * ANG(rad(45), 0, rad(45)), glow)
end

function Parts.card(r, limb, cf, s, suit, back)
	r:Box(limb, V(0.42, 0.6, 0.03) * s, cf, back and HW.Purple or rgb(236, 232, 240), M.Plastic)
	if back then
		r:Neon(limb, V(0.18, 0.18, 0.035) * s, cf * ANG(0, 0, rad(45)), HW.Violet)
	else
		r:Box(limb, V(0.14, 0.14, 0.035) * s, cf * ANG(0, 0, rad(45)), suit, M.Plastic)
	end
end

function Parts.thread(r, limb, a, b, color, d)
	return r:Seg(limb, a, b, d or 0.035, color, M.Neon)
end

function Parts.embers(r, part, color, rate, size)
	return r:Sparkles(part, color, { Rate = rate or 8, Up = 3, Size = size or 0.25, LifeMin = 0.5, LifeMax = 1.1 })
end

------------------------------------------------------------------------
-- РУНЫ: заякоренные детали без сварки (иконка вращается целиком через PivotTo)
------------------------------------------------------------------------
local function anchored(m, className, size, cf, color, mat, props)
	local p = Instance.new(className)
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

function Parts.rpart(m, size, cf, color, mat, props)
	return anchored(m, "Part", size, cf, color, mat, props)
end

function Parts.rwedge(m, size, cf, color, mat, props)
	return anchored(m, "WedgePart", size, cf, color, mat, props)
end

function Parts.rlight(part, color, range)
	if Kit.IsLite() then
		return nil
	end
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range or 8
	l.Brightness = 1.4
	l.Shadows = false
	l.Parent = part
	return l
end

return Parts
