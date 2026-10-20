--!nocheck
-- VOID TD :: Models/Enemies/Void
-- Враги карты Пустоты (9): LostSoul VoidCrawler ShadowBeast ArmoredHorror RiftPhantom AbyssBrute
-- и боссы CorruptedTitan (1 фаза), VoidDevourer (2 фазы), TheEntity (2 фазы, финальный).
-- Угловатый стиль: блоки с фаской и светлым кантом, клинья-шипы, ромбы, трещины, рваная ткань, цепи.
-- Перед -Z. Все смещения — в локальных координатах детали-основы, до масштаба (Config.Enemies[id].Scale).
-- Скрытые детали фаз: Kit.hide (Transparency 1 + атрибут PT); nil из Lite уплотняет EnemyModels.Build.

return function(EnemyModels, Kit, Base)
	local V = Vector3.new
	local V2 = Vector2.new
	local CF = CFrame.new
	local ANG = CFrame.Angles
	local rad = math.rad
	local PI = math.pi

	local C, AC, M, rgb = Base.C, Base.AC, Base.M, Base.rgb
	local newCreature, newBiped, setup, hub = Base.newCreature, Base.newBiped, Base.setup, Base.hub
	local emitter, emitPoint, darkTrail = Base.emitter, Base.emitPoint, Base.darkTrail
	local finishCreature, finishBiped = Base.finishCreature, Base.finishBiped
	local bevel, bar, spike, gem, tatter = Kit.bevel, Kit.bar, Kit.spike, Kit.gem, Kit.tatter
	local crack, ring, hide, join, hornA = Kit.crack, Kit.ring, Kit.hide, Kit.join, Kit.hornA
	local pauldron, bootA, squareRing, chain = Kit.pauldron, Kit.bootA, Kit.squareRing, Kit.chain

	local SIDES = { -1, 1 }
	local function arms(r)
		return { { r.RArm, 1 }, { r.LArm, -1 } }
	end

	local function add(list, parts)
		for _, p in ipairs(parts) do
			list[#list + 1] = p
		end
		return parts
	end

	------------------------------------------------------------------------
	-- 1. LOST SOUL — угловатый полупрозрачный дух в рваном капюшоне, фиолетовый дым
	------------------------------------------------------------------------
	local function LostSoul(scale)
		local r = newCreature("LostSoul", V(1.7, 1.8, 1.5))
		setup(r, { Style = "Float", Gait = { Bob = 0.35 }, Death = "Dissipate", Spawn = "Fade" })
		local B = r.Torso
		-- голова-череп и тело, сужающееся книзу
		r:Box(B, V(1.3, 1.25, 1.2), CF(0, 0.45, 0), C.Ghost, M.Plastic, { Transparency = 0.2 })
		r:Box(B, V(1.15, 0.7, 1.0), CF(0, -0.45, 0.05), C.Ghost, M.Plastic, { Transparency = 0.3 })
		r:Box(B, V(0.85, 0.6, 0.8), CF(0, -0.95, 0.12), C.GhostMid, M.Plastic, { Transparency = 0.4 })
		spike(r, B, V(0, -1.2, 0.18), V(0.1, -1.9, 0.35), 0.75, C.GhostMid, M.Plastic, false)
		-- капюшон из брусков
		local hood = { Transparency = 0.15 }
		r:Box(B, V(1.55, 0.3, 1.45), CF(0, 1.15, 0.12), AC.Cloth, M.Fabric, hood)
		for _, s in ipairs(SIDES) do
			r:Box(B, V(0.25, 1.4, 1.45), CF(0.75 * s, 0.5, 0.12), AC.Cloth, M.Fabric, hood)
		end
		r:Box(B, V(1.55, 1.45, 0.25), CF(0, 0.5, 0.75), AC.Cloth, M.Fabric, hood)
		spike(r, B, V(0, 1.25, 0.45), V(0, 1.95, 1.1), 0.9, AC.Cloth, M.Fabric, true, 0.25)
		-- плащ на плечах с рваным краем
		r:Box(B, V(1.6, 1.0, 1.35), CF(0, -0.15, 0.1), AC.ClothDark, M.Fabric, { Transparency = 0.25 })
		tatter(r, B, -0.65, -0.58, 1.6, 5, AC.ClothDark, M.Fabric, 1)
		-- лицо: пустые глазницы с неоновыми зрачками, рот-щель
		for _, s in ipairs(SIDES) do
			r:Box(B, V(0.38, 0.42, 0.06), CF(0.3 * s, 0.5, -0.61) * ANG(0, 0, rad(-12 * s)), C.Obsidian)
			r:Neon(B, V(0.18, 0.2, 0.08), CF(0.3 * s, 0.48, -0.63), C.Neon)
		end
		r:Box(B, V(0.22, 0.42, 0.06), CF(0, 0.02, -0.61), C.Obsidian)
		gem(r, B, 0.45, CF(0, -0.35, -0.48), C.Neon) -- ядро-ромб внутри
		-- хвосты-лоскуты
		for i, x in ipairs({ -0.35, 0.35 }) do
			local t = hub(r, "SwayTail" .. i, B, CF(x, -1.0, 0.3), { Amp = 0.35, Speed = 3 + i * 0.5 })
			spike(r, t, V(0, 0, 0), V(0.1 * i, -1.0, 0.2), 0.5, C.GhostMid, M.Plastic, true, 0.08)
		end
		-- тонкие руки с когтями
		for _, s in ipairs({ 1, -1 }) do
			local arm = hub(r, s == 1 and "ArmR" or "ArmL", B, CF(0.85 * s, -0.1, 0))
			r:Seg(arm, V(0, 0, 0), V(0.3 * s, -0.75, -0.15), 0.28, C.Ghost, M.Plastic, { Transparency = 0.3 })
			for k = -1, 1 do
				spike(r, arm, V(0.3 * s + k * 0.08, -0.85, -0.15), V(0.35 * s + k * 0.14, -1.3, -0.3), 0.14, C.GhostMid, M.Plastic, true, 0.05)
			end
		end
		local e = emitPoint(r, B, CF(0, -1.4, 0.2), V(0.9, 0.3, 0.9))
		emitter(e, rgb(120, 60, 200), { Smoke = true, Rate = 7, Size = 0.9, SizeEnd = 1.6, LifeMin = 0.8, LifeMax = 1.4, SpeedMin = 0.2, SpeedMax = 0.6, Accel = V(0, 0.6, 0), T0 = 0.55 })
		r:Glow(B, C.Neon, 7, 0.9)
		return finishCreature(r, scale, 2.4, 3.2)
	end

	------------------------------------------------------------------------
	-- 2. VOID CRAWLER — угловатый жук: гранёный панцирь, клешни, трещины, дёрганая голова
	------------------------------------------------------------------------
	local function VoidCrawler(scale)
		local r = newCreature("VoidCrawler", V(2.0, 0.9, 2.6))
		setup(r, { Style = "Crawl", Gait = { Speed = 1.7, Stride = 0.4, Bob = 0.08, Sway = 0.06 }, Death = "Collapse" })
		local B = r.Torso
		-- грудь и брюшко из гранёных пластин внахлёст (неровная спина)
		bevel(r, B, V(1.5, 0.8, 1.3), CF(0, 0.15, -0.6), AC.Armor, AC.Edge, M.Slate)
		bevel(r, B, V(1.9, 0.9, 1.0), CF(0, 0.35, 0.35) * ANG(rad(8), 0, rad(4)), C.Deep, AC.Edge, M.Slate)
		bevel(r, B, V(1.75, 0.85, 0.9), CF(0.08, 0.55, 1.0) * ANG(rad(-6), rad(5), rad(-5)), AC.Armor, AC.Edge, M.Slate)
		bevel(r, B, V(1.3, 0.7, 0.8), CF(-0.05, 0.4, 1.65) * ANG(rad(-18), 0, rad(3)), C.Deep, AC.Edge, M.Slate)
		r:Wedge(B, V(1.6, 0.5, 0.9), CF(0, 0.85, 0.35), AC.ArmorMid, M.Slate)
		-- кривые костяные шипы
		spike(r, B, V(-0.45, 0.85, 0.3), V(-0.65, 1.6, 0.6), 0.32, C.Bone)
		spike(r, B, V(0.35, 0.9, 0.55), V(0.5, 1.4, 0.85), 0.26, C.Bone)
		spike(r, B, V(0.05, 0.95, 1.05), V(0.05, 1.85, 1.35), 0.36, C.Bone)
		spike(r, B, V(-0.35, 0.75, 1.55), V(-0.5, 1.25, 1.9), 0.24, C.BoneDark)
		-- трещины между пластинами
		crack(r, B, { V(-0.95, 0.65, -0.12), V(-0.3, 0.82, -0.15), V(0.35, 0.8, -0.1), V(0.95, 0.6, -0.08) }, 0.09)
		crack(r, B, { V(-0.9, 0.85, 0.66), V(-0.2, 1.0, 0.7), V(0.45, 0.98, 0.68), V(0.95, 0.8, 0.7) }, 0.08)
		-- брюшко-хвост с жалом
		local tail = hub(r, "SwayTail", B, CF(0, 0.35, 1.95), { Amp = 0.18, Speed = 5 })
		bevel(r, tail, V(0.8, 0.5, 0.7), CF(0, 0.1, 0.3) * ANG(rad(-15), 0, 0), AC.Armor, AC.Edge, M.Slate)
		spike(r, tail, V(0, 0.3, 0.6), V(0, 0.95, 1.2), 0.3, C.Bone)
		-- дёрганая голова: гранёный череп, россыпь неоновых глаз
		local head = hub(r, "TwitchHead", B, CF(0, 0.15, -1.25), { Amp = 0.45, Speed = 1 })
		bevel(r, head, V(1.05, 0.7, 0.9), CF(0, 0.05, -0.4), AC.Armor, AC.Edge, M.Slate)
		r:Wedge(head, V(1.0, 0.35, 0.7), CF(0, 0.55, -0.45) * ANG(0, PI, 0), AC.ArmorMid, M.Slate)
		for _, e in ipairs({ { -0.25, 0.15, 0.2 }, { 0.25, 0.15, 0.2 }, { 0, 0.28, 0.15 }, { -0.4, -0.05, 0.13 }, { 0.4, -0.05, 0.13 } }) do
			r:Neon(head, V(e[3], e[3], 0.08), CF(e[1], e[2], -0.87) * ANG(0, 0, rad(45)), C.Neon)
		end
		-- жвалы-серпы
		for _, s in ipairs(SIDES) do
			bar(r, head, V(0.3 * s, -0.2, -0.8), V(0.45 * s, -0.25, -1.2), 0.16, C.BoneDark)
			spike(r, head, V(0.45 * s, -0.25, -1.2), V(0.12 * s, -0.25, -1.55), 0.18, C.Bone, M.Plastic, true, 0.08)
		end
		-- 4 лапы: бедро вверх, голень вниз, коготь
		for _, l in ipairs({ { "FR", 1, -0.7, 1.25 }, { "FL", -1, -0.7, 1.25 }, { "BR", 1, 0.75, 1 }, { "BL", -1, 0.75, 1 } }) do
			local s, z, big = l[2], l[3], l[4]
			local h = hub(r, l[1], B, CF(0.75 * s, 0.1, z))
			local knee = V(0.95 * s, 0.75, z < 0 and -0.2 or 0.2)
			local foot = V(1.45 * s, -1.2, z < 0 and -0.5 or 0.35)
			local toe = foot + (knee - foot).Unit * 0.45
			bar(r, h, V(0, 0, 0), knee, 0.34 * big, AC.Armor)
			r:Box(h, V(0.42, 0.42, 0.42) * big, CF(knee) * ANG(0, rad(45), rad(45)), AC.ArmorMid, M.Slate)
			bar(r, h, knee, toe, 0.25 * big, C.Deep)
			r:Neon(h, V(0.05, 0.05, 0.55), CFrame.lookAt((knee + toe) / 2, toe) * CF(0, 0.13 * big, 0), C.Neon)
			spike(r, h, toe, foot, 0.24 * big, C.Bone)
		end
		return finishCreature(r, scale, 1.3, 2.4)
	end

	------------------------------------------------------------------------
	-- 3. SHADOW BEAST — угловатый теневой волк: массивные передние лапы, шипы, тёмный шлейф
	------------------------------------------------------------------------
	local function ShadowBeast(scale)
		local r = newCreature("ShadowBeast", V(1.6, 1.4, 2.8))
		setup(r, { Style = "Gallop", Gait = { Speed = 1, Stride = 0.6, Bob = 0.18 }, Death = "Collapse" })
		local B = r.Torso
		local fur, furHi = rgb(26, 20, 36), rgb(60, 44, 86)
		-- грудь, талия, круп
		bevel(r, B, V(1.8, 1.6, 1.4), CF(0, 0.25, -0.75), fur, furHi, M.Plastic)
		bevel(r, B, V(1.25, 1.1, 1.2), CF(0, 0.2, 0.4), fur, furHi, M.Plastic)
		bevel(r, B, V(1.5, 1.3, 1.1), CF(0, 0.25, 1.15), fur, furHi, M.Plastic)
		r:Wedge(B, V(1.75, 0.5, 0.9), CF(0, -0.55, -0.85) * ANG(PI, 0, 0), fur, M.Plastic)
		-- грива-шипы (передние плоские и выше)
		for i = 0, 6 do
			local z = -1.25 + i * 0.42
			local h = 0.4 + ((i * 3) % 4) * 0.13 + (i < 3 and 0.3 or 0)
			local y = 1.0 - i * 0.03
			spike(r, B, V(0, y - 0.1, z), V(0, y + h, z + 0.45), 0.38, i % 2 == 0 and C.Mid or C.Deep, M.Plastic, i < 3, 0.16)
		end
		crack(r, B, { V(0.91, 0.6, -1.1), V(0.91, 0.3, -0.6), V(0.91, 0.45, -0.25) }, 0.06)
		crack(r, B, { V(-0.91, 0.55, -1.0), V(-0.91, 0.25, -0.55) }, 0.06)
		-- голова: гранёный череп, клиновидная морда, челюсть, клыки, уши-клинья
		local head = hub(r, "Neck", B, CF(0, 0.65, -1.5))
		bevel(r, head, V(1.1, 0.9, 1.0), CF(0, 0.15, -0.45), fur, furHi, M.Plastic)
		bevel(r, head, V(0.7, 0.5, 0.75), CF(0, -0.02, -1.25), fur, furHi, M.Plastic)
		r:Wedge(head, V(0.7, 0.3, 0.75), CF(0, 0.37, -1.25), fur, M.Plastic)
		r:Box(head, V(0.3, 0.2, 0.12), CF(0, 0.08, -1.65), C.Obsidian)
		r:Box(head, V(0.6, 0.2, 0.7), CF(0, -0.38, -1.15), C.Obsidian)
		r:Neon(head, V(0.45, 0.06, 0.6), CF(0, -0.25, -1.15), C.Magenta)
		for _, s in ipairs(SIDES) do
			spike(r, head, V(0.25 * s, -0.2, -1.5), V(0.24 * s, -0.5, -1.5), 0.12, C.White, M.Plastic, true, 0.06)
			spike(r, head, V(0.38 * s, 0.55, -0.25), V(0.5 * s, 1.2, 0.0), 0.4, fur, M.Plastic, true, 0.14)
			r:Neon(head, V(0.3, 0.1, 0.06), CF(0.3 * s, 0.25, -0.96) * ANG(0, 0, rad(-18 * s)), C.Neon)
		end
		r:Glow(head, C.Neon, 6, 1)
		-- массивные передние лапы
		for _, l in ipairs({ { "FR", 1 }, { "FL", -1 } }) do
			local s = l[2]
			bevel(r, B, V(0.6, 1.3, 1.2), CF(0.85 * s, 0.15, -0.9), fur, furHi, M.Plastic)
			local leg = hub(r, l[1], B, CF(0.8 * s, -0.25, -1.0))
			bevel(r, leg, V(0.8, 1.0, 0.85), CF(0, -0.25, 0), fur, furHi, M.Plastic)
			bevel(r, leg, V(0.6, 0.7, 0.65), CF(0, -1.0, 0.05), fur, furHi, M.Plastic)
			bevel(r, leg, V(0.85, 0.35, 1.0), CF(0, -1.55, -0.15), fur, furHi, M.Plastic)
			for k = -1, 1 do
				spike(r, leg, V(k * 0.26, -1.6, -0.6), V(k * 0.3, -1.72, -0.9), 0.14, C.Bone, M.Plastic, true, 0.06)
			end
		end
		-- задние лапы
		for _, l in ipairs({ { "BR", 1 }, { "BL", -1 } }) do
			local leg = hub(r, l[1], B, CF(0.6 * l[2], -0.1, 1.15))
			bar(r, leg, V(0, 0.1, 0), V(0, -0.6, 0.35), V2(0.6, 0.8), fur)
			bar(r, leg, V(0, -0.6, 0.35), V(0, -1.55, 0.15), 0.42, fur)
			bevel(r, leg, V(0.55, 0.32, 0.8), CF(0, -1.75, -0.05), fur, furHi, M.Plastic)
		end
		-- хвост с шипом
		local tail = hub(r, "SwayTail", B, CF(0, 0.6, 1.7), { Amp = 0.3, Speed = 6 })
		bar(r, tail, V(0, 0, 0), V(0, 0.4, 0.6), 0.34, fur)
		bar(r, tail, V(0, 0.4, 0.6), V(0.1, 0.85, 1.05), 0.26, fur)
		spike(r, tail, V(0.1, 0.85, 1.05), V(0.1, 1.5, 1.4), 0.3, C.Mid)
		darkTrail(r, B, V(0, 0.75, 1.4), V(0, -0.45, 1.4), C.Deep)
		local e = emitPoint(r, B, CF(0, 0, 0.6), V(1.2, 1, 1.6))
		emitter(e, rgb(40, 16, 66), { Smoke = true, Rate = 6, Size = 0.7, SizeEnd = 1.3, LifeMin = 0.4, LifeMax = 0.8, T0 = 0.5 })
		return finishCreature(r, scale, 2.0, 3.2)
	end

	------------------------------------------------------------------------
	-- 4. ARMORED HORROR — латный кошмар: огромный нагрудник, наплечники-ступени, светящиеся швы
	------------------------------------------------------------------------
	local function ArmoredHorror(scale)
		local r = newBiped("ArmoredHorror", V(1.2, 1.2, 1.2))
		setup(r, { Style = "Heavy", Gait = { Speed = 0.9, Stride = 0.45, Bob = 0.16, Sway = 0.07 }, Death = "Topple" })
		local T, H = r.Torso, r.Head
		local glow = C.Magenta
		-- корпус и огромный нагрудник
		bevel(r, T, V(2.2, 2.0, 1.2), CF(0, 0.05, 0.05), AC.Armor, AC.Edge)
		bevel(r, T, V(2.7, 1.25, 1.55), CF(0, 0.6, -0.1), AC.ArmorMid, AC.Edge)
		r:Wedge(T, V(2.4, 0.6, 0.55), CF(0, 0.65, -1.1) * ANG(PI, PI, 0), AC.ArmorMid, M.Metal)
		r:Wedge(T, V(2.4, 0.5, 0.55), CF(0, 1.1, -1.1), AC.Armor, M.Metal)
		-- светящиеся швы и трещины между пластинами
		r:Neon(T, V(2.75, 0.07, 1.6), CF(0, -0.05, -0.1), glow)
		crack(r, T, { V(-0.9, 1.15, -0.9), V(-0.55, 0.7, -0.92), V(-0.75, 0.25, -0.88) }, 0.06, glow)
		crack(r, T, { V(0.6, 1.1, -0.9), V(0.85, 0.5, -0.88) }, 0.05, glow)
		gem(r, T, 0.4, CF(0, 0.55, -0.9), glow, AC.Edge)
		-- пластины живота, пояс, набедренники, шипы на спине
		bevel(r, T, V(2.0, 0.4, 1.35), CF(0, -0.35, -0.02), AC.ArmorMid, AC.Edge)
		bevel(r, T, V(1.9, 0.4, 1.3), CF(0, -0.72, 0), AC.Armor, AC.Edge)
		bevel(r, T, V(0.45, 0.4, 0.15), CF(0, -0.72, -0.72), AC.Edge, AC.ArmorMid)
		for _, s in ipairs(SIDES) do
			bevel(r, T, V(0.75, 0.85, 1.1), CF(0.85 * s, -1.25, -0.05) * ANG(0, 0, rad(12 * s)), AC.ArmorMid, AC.Edge)
		end
		for i = -1, 1 do
			spike(r, T, V(i * 0.6, 0.8, 0.6), V(i * 0.8, 1.5 - math.abs(i) * 0.25, 1.4), 0.45, AC.Armor, M.Metal)
		end
		-- шлем: гранёный, с гребнем, рогами и узким визором
		bevel(r, H, V(1.3, 1.35, 1.35), CF(0, 0.05, 0), AC.Armor, AC.Edge)
		bevel(r, H, V(1.1, 0.75, 0.25), CF(0, -0.1, -0.7), AC.ArmorMid, AC.Edge)
		r:Neon(H, V(0.85, 0.09, 0.06), CF(0, 0.2, -0.84), glow)
		r:Neon(H, V(0.09, 0.4, 0.06), CF(0, -0.05, -0.84), glow)
		spike(r, H, V(0, 0.6, 0.1), V(0, 1.4, 0.55), 0.8, AC.Armor, M.Metal, true, 0.12)
		for _, s in ipairs(SIDES) do
			hornA(r, H, { V(0.6 * s, 0.3, 0), V(0.95 * s, 0.55, 0.05), V(1.1 * s, 1.0, 0.05), V(1.0 * s, 1.5, -0.1) }, 0.26, C.Bone)
		end
		-- наплечники-ступени, толстые руки, латные кулаки
		for _, a in ipairs(arms(r)) do
			local A, s = a[1], a[2]
			pauldron(r, A, s, 1.15, AC.Armor, AC.Edge, glow, 2)
			bevel(r, A, V(1.05, 0.9, 1.05), CF(0, 0.15, 0), AC.Armor, AC.Edge)
			bevel(r, A, V(1.25, 1.05, 1.25), CF(0, -0.75, 0), AC.ArmorMid, AC.Edge)
			r:Neon(A, V(1.27, 0.06, 1.27), CF(0, -0.55, 0), glow)
			bevel(r, A, V(1.15, 0.6, 1.15), CF(0, -1.45, -0.05), AC.Armor, AC.Edge)
			for k = -1, 1 do
				spike(r, A, V(k * 0.33, -1.4, -0.55), V(k * 0.38, -1.45, -0.95), 0.18, AC.Edge, M.Metal)
			end
		end
		for _, Lg in ipairs({ r.RLeg, r.LLeg }) do
			bevel(r, Lg, V(1.05, 1.0, 1.05), CF(0, 0.45, 0), AC.Armor, AC.Edge)
			bevel(r, Lg, V(0.8, 0.5, 0.3), CF(0, -0.05, -0.6), AC.ArmorMid, AC.Edge)
			bevel(r, Lg, V(1.1, 0.7, 1.12), CF(0, -0.38, 0), AC.ArmorMid, AC.Edge)
			bootA(r, Lg, AC.Armor, AC.Edge, 1.15)
		end
		r:Glow(T, glow, 7, 0.9)
		return finishBiped(r, scale, { Root = { 6, 0, 0 }, RS = { 0, 0, 6 }, LS = { 0, 0, -6 } })
	end

	------------------------------------------------------------------------
	-- 5. RIFT PHANTOM — разделённые парящие части тела, кольца энергии, шлейф частиц
	------------------------------------------------------------------------
	local function RiftPhantom(scale)
		local r = newCreature("RiftPhantom", V(1.4, 1.2, 0.9))
		setup(r, { Style = "Float", Gait = { Bob = 0.3 }, Death = "Scatter", Spawn = "Fade" })
		local B = r.Torso
		-- грудь: гранёный корпус с кристаллом
		bevel(r, B, V(1.4, 1.1, 0.8), CF(0, 0.1, 0.1), C.Deep, C.Lilac, M.Plastic)
		r:Wedge(B, V(1.4, 0.6, 0.8), CF(0, -0.75, 0.1) * ANG(PI, 0, 0), C.Deep, M.Plastic)
		spike(r, B, V(0, 0, -0.4), V(0, 0.6, -0.4), 0.5, C.NeonSoft, M.Neon)
		spike(r, B, V(0, 0, -0.4), V(0, -0.65, -0.4), 0.5, C.Neon, M.Neon)
		r:Glow(B, C.Neon, 9, 1.2)
		-- парящие плечи-пластины
		for _, s in ipairs({ 1, -1 }) do
			local sh = hub(r, s == 1 and "BobShoulderR" or "BobShoulderL", B, CF(1.05 * s, 0.75, 0), { Amp = 0.12, Speed = 2.6 })
			bevel(r, sh, V(0.95, 0.35, 0.9), ANG(0, 0, rad(-18 * s)), C.Deep, C.Lilac, M.Plastic)
			spike(r, sh, V(0.2 * s, 0.15, 0), V(0.6 * s, 0.75, 0), 0.35, C.Mid)
			r:Neon(sh, V(0.9, 0.05, 0.85), CF(0, -0.2, 0) * ANG(0, 0, rad(-18 * s)), C.NeonSoft)
		end
		-- парящая голова: светящееся лицо в остроконечном капюшоне
		local head = hub(r, "BobHead", B, CF(0, 1.6, 0), { Amp = 0.15, Speed = 2 })
		r:Box(head, V(0.75, 0.9, 0.7), CF(0, 0, -0.05), C.NeonSoft, M.Neon)
		r:Box(head, V(0.55, 0.1, 0.1), CF(0, 0.1, -0.42), C.Obsidian)
		r:Box(head, V(0.2, 0.3, 0.1), CF(0, -0.2, -0.42), C.Obsidian)
		r:Box(head, V(1.2, 0.25, 1.15), CF(0, 0.58, 0.12), C.Deep, M.Fabric)
		for _, s in ipairs(SIDES) do
			r:Box(head, V(0.22, 1.2, 1.15), CF(0.5 * s, 0.05, 0.12), C.Deep, M.Fabric)
		end
		r:Box(head, V(1.2, 1.2, 0.22), CF(0, 0.05, 0.6), C.Deep, M.Fabric)
		spike(r, head, V(0, 0.65, 0.3), V(0, 1.35, 0.95), 0.75, C.Deep, M.Fabric, true, 0.2)
		r:Glow(head, C.NeonSoft, 7, 1)
		-- отделённые руки-когти
		for _, s in ipairs({ 1, -1 }) do
			local arm = hub(r, s == 1 and "ArmR" or "ArmL", B, CF(1.25 * s, 0.2, 0))
			bevel(r, arm, V(0.45, 0.9, 0.45), CF(0.03 * s, -0.55, -0.05), C.Deep, C.Lilac, M.Plastic)
			r:Neon(arm, V(0.06, 0.8, 0.06), CF(0.03 * s, -0.55, -0.3), C.Neon)
			for k = -1, 1 do
				spike(r, arm, V(0.05 * s + k * 0.13, -1.0, -0.1), V(0.08 * s + k * 0.2, -1.75, -0.35), 0.15, C.NeonSoft, M.Neon, true, 0.06)
			end
		end
		-- нижняя часть: парящие осколки-ромбы
		for i = 1, 3 do
			local sd = hub(r, "BobShard" .. i, B, CF(0.08 * ((i % 2) * 2 - 1), -0.9 - i * 0.6, 0.08 * i), { Amp = 0.1 + i * 0.04, Speed = 2.4 + i * 0.3 })
			local w = 0.85 - i * 0.18
			local rot = ANG(rad(45), rad(i * 20), rad(45))
			r:Box(sd, V(w, w, w), rot, i % 2 == 0 and C.Mid or C.Deep, M.Plastic)
			r:Neon(sd, V(w * 0.45, w * 0.45, w * 1.05), rot, C.Neon)
			if i == 3 then
				emitter(sd, C.Neon, { Rate = 14, Size = 0.35, LifeMin = 0.6, LifeMax = 1.1, SpeedMin = 0.1, SpeedMax = 0.5 })
			end
		end
		-- энергетические кольца
		local ring1 = hub(r, "OrbitRing1", B, CF(), { Speed = 1.6 })
		ring(r, ring1, ANG(rad(90), 0, 0), 1.6, 12, 0.08, 0.08, C.Neon, M.Neon, function(i)
			return i % 4 == 3
		end)
		local ring2 = hub(r, "OrbitRing2", B, CF(0, 0.2, 0) * ANG(rad(65), 0, rad(20)), { Speed = -2.2 })
		ring(r, ring2, ANG(rad(90), 0, 0), 1.95, 14, 0.06, 0.06, C.NeonSoft, M.Neon, function(i)
			return i % 5 == 4
		end)
		return finishCreature(r, scale, 3.3, 4.6)
	end

	------------------------------------------------------------------------
	-- 6. ABYSS BRUTE — сгорбленный громила: гигантские руки-блоки, странная голова, кристаллы на спине
	------------------------------------------------------------------------
	local function AbyssBrute(scale)
		local r = newBiped("AbyssBrute", V(1.2, 1.0, 1.2))
		setup(r, { Style = "Heavy", Gait = { Speed = 0.75, Stride = 0.35, Bob = 0.24, Sway = 0.12, Shake = 0.12 }, Death = "Topple" })
		local T, H = r.Torso, r.Head
		local skin, skinHi, skinLo = rgb(56, 22, 42), rgb(104, 48, 76), rgb(36, 13, 28)
		-- горб, грудь, пояс
		bevel(r, T, V(2.8, 1.6, 1.9), CF(0, 0.6, 0.25), skin, skinHi, M.Plastic)
		bevel(r, T, V(2.1, 1.2, 1.4), CF(0, -0.35, -0.15), skinLo, skinHi, M.Plastic)
		bevel(r, T, V(2.3, 0.5, 1.7), CF(0, -0.95, 0), AC.Armor, AC.Edge)
		bevel(r, T, V(0.5, 0.45, 0.15), CF(0, -0.95, -0.88), AC.Edge, AC.ArmorMid)
		-- светящееся сердце-ромб и трещины
		gem(r, T, 0.5, CF(0, 0.5, -0.72), C.Magenta, skinLo)
		crack(r, T, { V(-0.85, 1.05, -0.72), V(-0.35, 0.75, -0.73), V(-0.6, 0.15, -0.73) }, 0.06, C.Magenta)
		crack(r, T, { V(0.75, 1.0, -0.72), V(0.35, 0.8, -0.73) }, 0.05, C.Magenta)
		-- кристаллы на горбу {x, y, z, dx, dy, w}
		for _, c in ipairs({ { -0.6, 1.3, 0.95, -0.35, 1.3, 0.48 }, { 0.05, 1.4, 0.75, 0.05, 1.8, 0.58 }, { 0.65, 1.3, 0.95, 0.4, 1.25, 0.44 }, { -0.3, 0.9, 1.2, -0.25, 0.85, 0.32 }, { 0.35, 0.95, 1.2, 0.3, 0.75, 0.3 } }) do
			local base = V(c[1], c[2], c[3])
			r:Box(T, V(c[6] * 1.5, c[6] * 0.6, c[6] * 1.5), CF(base) * ANG(0, rad(30), 0), C.Night, M.Slate)
			spike(r, T, base, base + V(c[4] * 0.5, c[5], 0.55), c[6], C.Neon, M.Neon)
		end
		r:Glow(T, C.Neon, 9, 1.1)
		-- странная голова: низкая и широкая, три глаза, выпирающая челюсть с бивнями
		bevel(r, H, V(1.4, 0.95, 1.25), CF(0, 0.08, 0), skin, skinHi, M.Plastic)
		bevel(r, H, V(1.5, 0.5, 1.15), CF(0, -0.4, -0.15), skinLo, skinHi, M.Plastic)
		r:Wedge(H, V(1.3, 0.35, 0.5), CF(0, 0.45, -0.45) * ANG(0, PI, 0), skinLo, M.Plastic)
		for _, s in ipairs(SIDES) do
			spike(r, H, V(0.45 * s, -0.35, -0.7), V(0.6 * s, 0.4, -0.85), 0.26, C.Bone)
			r:Neon(H, V(0.22, 0.12, 0.06), CF(0.38 * s, 0.22, -0.64) * ANG(0, 0, rad(14 * s)), C.Magenta)
			hornA(r, H, { V(0.5 * s, 0.35, 0.1), V(0.85 * s, 0.55, 0.35), V(0.95 * s, 0.75, 0.8), V(0.8 * s, 0.9, 1.3) }, 0.3, C.Bone)
		end
		gem(r, H, 0.24, CF(0, 0.3, -0.64), C.Magenta)
		-- костяные наплечники, гигантские руки до земли
		for _, a in ipairs(arms(r)) do
			local A, s = a[1], a[2]
			bevel(r, A, V(1.7, 0.55, 1.7), CF(0.25 * s, 1.15, 0) * ANG(0, 0, rad(-15 * s)), C.BoneDark, C.Bone, M.Plastic)
			for k = -1, 1 do
				spike(r, A, V(0.45 * s, 1.35, k * 0.5), V(0.95 * s, 2.05 - math.abs(k) * 0.3, k * 0.65), 0.4, C.Bone, M.Plastic, true, 0.14)
			end
			bevel(r, A, V(1.55, 1.55, 1.55), CF(0.1 * s, 0.15, 0), skin, skinHi, M.Plastic)
			bevel(r, A, V(1.8, 1.4, 1.8), CF(0.15 * s, -1.0, 0), skinLo, skinHi, M.Plastic)
			bevel(r, A, V(1.9, 0.4, 1.9), CF(0.15 * s, -1.5, 0), AC.Armor, AC.Edge)
			bevel(r, A, V(1.65, 0.9, 1.65), CF(0.15 * s, -2.05, -0.05), skin, skinHi, M.Plastic)
			for k = -1, 1 do
				spike(r, A, V(0.15 * s + k * 0.5, -2.2, -0.75), V(0.15 * s + k * 0.55, -2.4, -1.15), 0.26, C.Bone)
			end
		end
		for _, Lg in ipairs({ r.RLeg, r.LLeg }) do
			bevel(r, Lg, V(1.3, 1.3, 1.3), CF(0, 0.3, 0), skinLo, skinHi, M.Plastic)
			bevel(r, Lg, V(1.35, 0.55, 1.6), CF(0, -0.75, -0.15), skin, skinHi, M.Plastic)
			for k = -1, 1 do
				spike(r, Lg, V(k * 0.4, -0.85, -0.9), V(k * 0.45, -0.95, -1.2), 0.2, C.Bone, M.Plastic, true, 0.08)
			end
		end
		return finishBiped(r, scale, { Root = { 14, 0, 0 }, Neck = { -14, 0, 0 }, RS = { 8, 0, 6 }, LS = { 8, 0, -6 } })
	end

	------------------------------------------------------------------------
	-- 7. CORRUPTED TITAN (босс-страж) — каменный великан в обсидиановых латах: рога, кулаки, кристалл.
	-- 50%: камень трескается, свечение ядра сильнее
	------------------------------------------------------------------------
	local function CorruptedTitan(scale)
		local r = newBiped("CorruptedTitan", V(1.4, 1.3, 1.4))
		setup(r, { Style = "Heavy", Gait = { Speed = 0.8, Stride = 0.4, Bob = 0.2, Sway = 0.08, Shake = 0.2 }, Death = "Topple", Spawn = "Titan" })
		local T, H, RL, LL = r.Torso, r.Head, r.RLeg, r.LLeg
		local function rock(limb, size, cf, light)
			return bevel(r, limb, size, cf, light and C.StoneLight or C.Stone, light and rgb(140, 132, 160) or C.StoneLight, M.Slate)
		end
		-- каменная плоть из глыб, между ними светятся разломы
		r:Box(T, V(2.3, 2.1, 1.3), CF(0, 0.15, 0.05), C.Neon, M.Neon)
		rock(T, V(1.25, 1.2, 1.5), CF(-0.62, 0.65, 0.05) * ANG(rad(4), rad(6), rad(5)), false)
		rock(T, V(1.25, 1.15, 1.5), CF(0.64, 0.68, 0.05) * ANG(rad(-3), rad(-5), rad(-6)), true)
		rock(T, V(1.15, 0.95, 1.4), CF(-0.5, -0.4, 0) * ANG(rad(-5), rad(3), rad(-4)), true)
		rock(T, V(1.15, 0.95, 1.4), CF(0.52, -0.38, 0) * ANG(rad(6), rad(-4), rad(5)), false)
		-- обсидиановый нагрудник с золотым кантом и кристаллом
		bevel(r, T, V(2.5, 1.2, 0.5), CF(0, 0.65, -0.8), AC.Armor, C.Gold)
		r:Wedge(T, V(2.3, 0.5, 0.5), CF(0, -0.15, -0.8) * ANG(PI, PI, 0), AC.Armor, M.Metal)
		spike(r, T, V(0, 0.55, -1.1), V(0, 1.15, -1.1), 0.6, C.Neon, M.Neon)
		spike(r, T, V(0, 0.55, -1.1), V(0, -0.05, -1.1), 0.6, C.NeonSoft, M.Neon)
		local coreLight = r:Glow(T, C.Neon, 14, 1.6)
		bevel(r, T, V(2.2, 0.4, 1.6), CF(0, -1.0, 0), AC.Armor, C.Gold)
		-- голова: каменный череп в обсидиановом шлеме, щель глаз, огромные рога
		rock(H, V(1.3, 1.25, 1.3), CF(0, -0.05, 0.05) * ANG(rad(3), rad(5), 0), false)
		bevel(r, H, V(1.5, 0.75, 1.45), CF(0, 0.35, -0.05), AC.Armor, C.Gold)
		r:Neon(H, V(1.0, 0.09, 0.06), CF(0, 0, -0.69), C.Neon)
		r:Wedge(H, V(1.0, 0.5, 0.5), CF(0, -0.45, -0.5) * ANG(PI, PI, 0), C.StoneLight, M.Slate)
		for _, s in ipairs(SIDES) do
			hornA(r, H, { V(0.65 * s, 0.45, 0), V(1.2 * s, 0.8, 0.1), V(1.5 * s, 1.4, 0), V(1.4 * s, 2.05, -0.3), V(1.15 * s, 2.6, -0.55) }, 0.42, AC.Armor, M.Metal)
		end
		-- наплечники, каменные руки, гигантские кулаки
		for _, a in ipairs(arms(r)) do
			local A, s = a[1], a[2]
			pauldron(r, A, s, 1.2, AC.Armor, C.Gold, C.Neon, 1)
			rock(A, V(1.05, 1.0, 1.05), CF(0, 0.1, 0) * ANG(0, rad(10), rad(4 * s)), false)
			rock(A, V(1.2, 0.9, 1.2), CF(0, -0.75, 0) * ANG(0, rad(-8), rad(-5 * s)), true)
			r:Box(A, V(1.0, 0.25, 1.0), CF(0, -0.35, 0), C.Neon, M.Neon)
			bevel(r, A, V(1.7, 0.35, 1.7), CF(0, -1.2, -0.05), AC.Armor, C.Gold)
			rock(A, V(1.6, 1.2, 1.6), CF(0, -1.75, -0.1) * ANG(rad(5), rad(12), 0), false)
			for k = -1, 1 do
				spike(r, A, V(k * 0.5, -1.7, -0.85), V(k * 0.55, -1.75, -1.25), 0.28, AC.Armor, M.Metal)
			end
		end
		for _, Lg in ipairs({ RL, LL }) do
			rock(Lg, V(1.15, 1.05, 1.15), CF(0, 0.45, 0) * ANG(0, rad(8), 0), true)
			r:Box(Lg, V(0.95, 0.25, 0.95), CF(0, -0.1, 0), C.Neon, M.Neon)
			rock(Lg, V(1.15, 0.7, 1.2), CF(0, -0.42, 0) * ANG(0, rad(-6), 0), false)
			bootA(r, Lg, AC.Armor, C.Gold, 1.25)
		end
		-- парящие осколки разлома
		local orb = hub(r, "OrbitRift", T, CF(0, 0.3, 0), { Speed = 1.1 })
		for i = 0, 4 do
			local a = i / 5 * PI * 2
			local p = V(math.cos(a) * 2.7, math.sin(a * 2) * 0.4, math.sin(a) * 2.7)
			spike(r, orb, p - V(0, 0.35, 0), p + V(0, 0.45, 0), 0.4, C.Neon, M.Neon)
		end
		local aura = emitter(T, C.Neon, { Rate = 10, Size = 0.5, Accel = V(0, 2, 0) })
		-- фаза повреждений (50% HP)
		local dmg = hide(join(
			crack(r, T, { V(-0.95, 1.15, -0.85), V(-0.55, 0.65, -0.85), V(-0.85, 0.2, -0.82) }, 0.08),
			crack(r, T, { V(0.9, 0.1, -0.75), V(0.5, -0.4, -0.75), V(0.8, -0.8, -0.75) }, 0.08),
			crack(r, H, { V(-0.4, -0.1, -0.62), V(-0.15, -0.35, -0.64), V(-0.35, -0.6, -0.62) }, 0.06),
			crack(r, RL, { V(0.3, 0.7, -0.59), V(-0.1, 0.2, -0.59) }, 0.07),
			crack(r, LL, { V(-0.3, 0.6, -0.59), V(0.15, 0.1, -0.59) }, 0.07)
		))
		local dmgFx = emitter(T, C.NeonSoft, { Rate = 16, Size = 0.35, SpeedMin = 2, SpeedMax = 4, Off = true })
		r.Phases = {
			{ At = 0.5, Reveal = dmg, Emit = { dmgFx, aura }, Lights = { { coreLight, 3 } }, Aggro = 1.15 },
		}
		return finishBiped(r, scale, { RS = { 0, 0, 8 }, LS = { 0, 0, -8 } }, 6.4)
	end

	------------------------------------------------------------------------
	-- 8. VOID DEVOURER (босс) — сгорбленный пожиратель: рога, слоистая броня, кристаллы, светящаяся пасть.
	-- 66%: трещины по броне; 33%: броня отваливается, под ней светится ядро
	------------------------------------------------------------------------
	local function VoidDevourer(scale)
		local r = newBiped("VoidDevourer", V(1.6, 1.35, 1.6))
		setup(r, { Style = "Heavy", Gait = { Speed = 0.7, Stride = 0.38, Bob = 0.22, Sway = 0.1, Lean = 4, Shake = 0.3 }, Death = "Topple" })
		local T, H = r.Torso, r.Head
		local maw = C.Magenta
		-- корпус и слоистая броня на груди
		bevel(r, T, V(2.5, 2.2, 1.6), CF(0, 0.2, 0.15), AC.Armor, AC.Edge)
		local plateA = bevel(r, T, V(2.7, 0.75, 1.35), CF(0, 0.95, -0.35) * ANG(rad(-10), 0, 0), AC.ArmorMid, AC.Edge)
		local plateB = bevel(r, T, V(2.4, 0.65, 1.25), CF(0, 0.3, -0.45) * ANG(rad(-6), 0, 0), AC.Armor, AC.Edge)
		bevel(r, T, V(2.0, 0.55, 1.2), CF(0, -0.3, -0.42), AC.ArmorMid, AC.Edge)
		r:Neon(T, V(2.5, 0.06, 1.3), CF(0, 0.62, -0.38) * ANG(rad(-8), 0, 0), C.Neon)
		bevel(r, T, V(2.2, 0.4, 1.6), CF(0, -0.95, 0), AC.Armor, AC.Edge)
		-- спинной гребень из пластин и кристаллов
		for i = 0, 3 do
			bevel(r, T, V(1.8 - i * 0.2, 0.32, 0.8), CF(0, 1.25 - i * 0.55, 1.0 + i * 0.05) * ANG(rad(28), 0, 0), i % 2 == 0 and AC.Armor or AC.ArmorMid, AC.Edge)
		end
		for _, c in ipairs({ { -0.55, 1.3, 1.1, -0.35, 1.4, 0.5 }, { 0.1, 1.45, 1.1, 0.05, 1.9, 0.6 }, { 0.6, 1.25, 1.05, 0.35, 1.25, 0.46 }, { -0.25, 0.65, 1.3, -0.2, 0.9, 0.36 }, { 0.35, 0.55, 1.3, 0.25, 0.8, 0.32 } }) do
			local base = V(c[1], c[2], c[3])
			spike(r, T, base, base + V(c[4], c[5], 0.75), c[6], C.Neon, M.Neon)
		end
		r:Glow(T, C.Neon, 12, 1.2)
		-- голова: гранёный череп, огромная пасть
		bevel(r, H, V(1.7, 1.15, 1.8), CF(0, 0.3, -0.05), AC.Armor, AC.Edge)
		r:Wedge(H, V(1.6, 0.45, 1.0), CF(0, 0.95, -0.4) * ANG(0, PI, 0), AC.ArmorMid, M.Metal)
		r:Box(H, V(1.3, 0.6, 0.9), CF(0, -0.15, -0.5), maw, M.Neon)
		for i = -3, 3 do
			local z = math.abs(i) * 0.05
			spike(r, H, V(i * 0.2, 0, -0.98 + z), V(i * 0.2, -0.4, -1.0 + z), 0.17, C.White, M.Plastic, true, 0.07)
		end
		for _, s in ipairs(SIDES) do
			r:Neon(H, V(0.36, 0.1, 0.06), CF(0.45 * s, 0.55, -0.96) * ANG(0, 0, rad(-24 * s)), maw)
			r:Neon(H, V(0.18, 0.07, 0.06), CF(0.62 * s, 0.32, -0.96) * ANG(0, 0, rad(-24 * s)), maw)
		end
		local mawLight = r:Glow(H, maw, 10, 1.4)
		-- нижняя челюсть на своём моторе (без вторичного движения)
		local jaw = hub(r, "Jaw", H, CF(0, -0.4, 0.35))
		bevel(r, jaw, V(1.45, 0.4, 1.6), CF(0, -0.15, -0.75), AC.Armor, AC.Edge)
		r:Neon(jaw, V(1.1, 0.06, 1.2), CF(0, 0.07, -0.75), maw)
		for i = -3, 3 do
			local z = -1.4 + math.abs(i) * 0.09
			spike(r, jaw, V(i * 0.19, 0.05, z), V(i * 0.19, 0.45, z), 0.15, C.White, M.Plastic, true, 0.07)
		end
		-- массивные угловатые рога
		for _, s in ipairs(SIDES) do
			hornA(r, H, { V(0.7 * s, 0.6, 0.15), V(1.3 * s, 0.95, 0.2), V(1.7 * s, 1.7, 0), V(1.6 * s, 2.6, -0.4), V(1.2 * s, 3.3, -0.8) }, 0.5, AC.Armor, M.Metal)
			hornA(r, H, { V(0.45 * s, 0.8, 0.5), V(0.65 * s, 1.15, 1.0), V(0.7 * s, 1.35, 1.6), V(0.65 * s, 1.3, 2.2) }, 0.26, AC.ArmorMid, M.Metal)
		end
		-- наплечники с кристаллами, длинные руки с когтями-лезвиями
		local pauldrons = {}
		for _, a in ipairs(arms(r)) do
			local A, s = a[1], a[2]
			add(pauldrons, pauldron(r, A, s, 1.25, AC.Armor, AC.Edge, C.Neon, 1))
			spike(r, A, V(0.55 * s, 1.3, -0.4), V(1.0 * s, 2.0, -0.55), 0.32, C.Neon, M.Neon)
			bevel(r, A, V(1.0, 0.95, 1.0), CF(0, 0.15, 0), AC.Armor, AC.Edge)
			bevel(r, A, V(1.2, 1.05, 1.2), CF(0, -0.75, -0.03), AC.ArmorMid, AC.Edge)
			r:Neon(A, V(1.22, 0.06, 1.22), CF(0, -0.45, -0.03), C.Neon)
			bevel(r, A, V(1.1, 0.55, 1.1), CF(0, -1.5, -0.1), AC.Armor, AC.Edge)
			for k = -1, 1 do
				spike(r, A, V(k * 0.36, -1.7, -0.45), V(k * 0.45, -2.75, -1.0), 0.24, C.Bone)
			end
		end
		for _, Lg in ipairs({ r.RLeg, r.LLeg }) do
			bevel(r, Lg, V(1.15, 1.0, 1.15), CF(0, 0.45, 0), AC.Armor, AC.Edge)
			bevel(r, Lg, V(0.85, 0.5, 0.3), CF(0, -0.05, -0.62), AC.ArmorMid, AC.Edge)
			bevel(r, Lg, V(1.15, 0.7, 1.15), CF(0, -0.38, 0), AC.ArmorMid, AC.Edge)
			bootA(r, Lg, AC.Armor, AC.Edge, 1.25)
			for k = -1, 1 do
				spike(r, Lg, V(k * 0.35, -0.85, -1.15), V(k * 0.4, -0.95, -1.5), 0.2, C.Bone, M.Plastic, true, 0.08)
			end
		end
		-- парящие осколки за спиной
		local orb = hub(r, "OrbitShards", T, CF(0, 1.2, 1.7), { Speed = 0.9 })
		for i = 0, 5 do
			local a = i / 6 * PI * 2
			local p = V(math.cos(a) * 1.7, math.sin(a * 3) * 0.3, math.sin(a) * 1.7)
			spike(r, orb, p - V(0, 0.3, 0), p + V(0, 0.45, 0), 0.38, C.Neon, M.Neon)
		end
		local aura = emitter(T, maw, { Rate = 12, Size = 0.55, Accel = V(0, 1.5, 0) })
		-- 66%: светящиеся трещины по броне
		local cracks2 = hide(join(
			crack(r, T, { V(-1.0, 1.15, -1.05), V(-0.5, 0.7, -1.1), V(-0.75, 0.15, -1.08) }, 0.08, maw),
			crack(r, T, { V(0.95, 1.0, -1.05), V(0.45, 0.45, -1.1), V(0.75, -0.2, -1.05) }, 0.08, maw),
			crack(r, H, { V(-0.6, 0.75, -0.96), V(-0.25, 0.45, -0.96) }, 0.06, maw)
		))
		-- 33%: под отвалившейся бронёй светится ядро
		local inner = hide({
			r:Box(T, V(1.6, 0.6, 0.3), CF(0, 0.95, -0.85), C.Neon, M.Neon),
			r:Box(T, V(1.2, 0.5, 0.3), CF(0, 0.3, -0.9), C.NeonSoft, M.Neon),
		})
		local burst = emitter(T, C.Neon, { Rate = 22, Size = 0.4, SpeedMin = 3, SpeedMax = 6, Off = true })
		r.Phases = {
			{ At = 0.66, Reveal = cracks2, Emit = { aura }, Lights = { { mawLight, 2.4 } }, Aggro = 1.1 },
			{ At = 0.33, Reveal = inner, Break = join(plateA, plateB, pauldrons), Emit = { burst }, Aggro = 1.25 },
		}
		return finishBiped(r, scale, { Root = { 16, 0, 0 }, Neck = { -14, 0, 0 }, RS = { 10, 0, 8 }, LS = { 10, 0, -8 } }, 7.0)
	end

	------------------------------------------------------------------------
	-- 9. THE ENTITY (финальный босс) — Повелитель Пустоты в угловатых латах: сломанная корона,
	-- асимметричная броня, разбитое кольцо, парящие камни, ядро-кристалл, цепи, руны, рваный плащ.
	-- 65%: трещины, ядро ярче; 30%: корона и кольцо ломаются, вокруг кружится больше осколков
	------------------------------------------------------------------------
	-- корона {x, высота, высокий зубец (ломается на 30%)}
	local ENTITY_CROWN = { { 0, 2.6, true }, { 0.4, 1.7, true }, { -0.4, 2.0, true }, { 0.7, 0.5, false }, { -0.7, 1.3, true }, { 0.2, 0.35, false } }

	-- руки: правая латная, левая проклятая (цепи, руны, кость); кисти с когтями
	local function entityArms(r, GOLD)
		local RA, LA = r.RArm, r.LArm
		pauldron(r, RA, 1, 1.3, AC.Armor, GOLD, C.Neon, 3)
		bevel(r, RA, V(1.0, 0.9, 1.0), CF(0, 0.15, 0), AC.Armor, AC.Edge)
		bevel(r, RA, V(1.3, 0.3, 1.3), CF(0, -0.35, 0), AC.Armor, GOLD)
		bevel(r, RA, V(1.2, 0.85, 1.2), CF(0, -0.85, -0.02), AC.ArmorMid, AC.Edge)
		spike(r, RA, V(0.5, -0.8, 0), V(1.0, -0.7, 0.15), 0.35, AC.Armor, M.Metal, true, 0.1)
		bevel(r, LA, V(1.35, 0.6, 1.35), CF(-0.2, 1.05, 0) * ANG(0, 0, rad(14)), AC.ClothDark, AC.Edge, M.Fabric)
		for k = 0, 2 do
			spike(r, LA, V(-0.3 - k * 0.12, 1.25, -0.35 + k * 0.35), V(-0.65 - k * 0.15, 2.0 - k * 0.2, -0.4 + k * 0.45), 0.24, C.Bone)
		end
		bevel(r, LA, V(0.9, 0.9, 0.9), CF(0, 0.15, 0), C.Deep, C.Lilac, M.Plastic)
		bevel(r, LA, V(1.0, 1.0, 1.0), CF(0, -0.8, 0), C.Night, C.Mid, M.Plastic)
		for k = 0, 2 do
			squareRing(r, LA, CF(0, -0.45 - k * 0.3, 0) * ANG(rad(10 - k * 8), rad(10), 0), 1.1, 0.1, C.Steel)
		end
		r:Neon(LA, V(0.06, 0.85, 0.06), CF(0.1, -0.85, -0.52), C.NeonSoft)
		for _, A in ipairs({ RA, LA }) do
			bevel(r, A, V(1.05, 0.5, 1.05), CF(0, -1.5, -0.1), AC.Armor, AC.Edge)
			for k = -1, 1 do
				local base = V(k * 0.35, -1.7, -0.5)
				spike(r, A, base, base + V(k * 0.1, -0.85, -0.5), 0.26, C.Bone)
			end
		end
	end

	local function TheEntity(scale)
		local r = newBiped("TheEntity", V(1.3, 1.5, 1.3))
		setup(r, { Style = "Heavy", Gait = { Speed = 0.75, Stride = 0.36, Bob = 0.2, Sway = 0.09, Lean = 3, Shake = 0.4 }, Death = "Implode" })
		local T, H, LA, RL, LL = r.Torso, r.Head, r.LArm, r.RLeg, r.LLeg
		local GOLD = C.Gold

		-- ТОРС: корпус, широкая грудная пластина; справа тяжёлая пластина, слева открытые рёбра; ядро-кристалл
		bevel(r, T, V(2.2, 2.0, 1.2), CF(0, 0.05, 0.05), AC.Armor, AC.Edge)
		bevel(r, T, V(2.75, 1.05, 1.5), CF(0, 0.6, -0.05), AC.ArmorMid, AC.Edge)
		bevel(r, T, V(1.15, 0.95, 0.3), CF(0.62, 0.55, -0.85) * ANG(0, 0, rad(-6)), AC.Armor, GOLD)
		for k = 0, 2 do
			bar(r, T, V(-0.15, 1.0 - k * 0.32, -0.85), V(-1.1, 0.85 - k * 0.32, -0.75), V2(0.12, 0.1), C.Bone)
		end
		gem(r, T, 0.7, CF(-0.4, 0.45, -0.82), C.Neon, AC.Edge)
		gem(r, T, 0.35, CF(-0.4, 0.45, -0.92), C.White)
		local coreLight = r:Glow(T, C.Neon, 18, 2)
		-- воротник-гребень за головой
		for _, s in ipairs(SIDES) do
			spike(r, T, V(0.7 * s, 1.0, 0.3), V(1.1 * s, 2.6, 0.75), 0.85, AC.Armor, M.Metal, true, 0.22)
			spike(r, T, V(0.35 * s, 1.0, 0.45), V(0.5 * s, 2.1, 0.85), 0.6, AC.ArmorMid, M.Metal, true, 0.18)
		end
		-- пластины живота, тканевый пояс с пряжкой, набедренники
		bevel(r, T, V(1.95, 0.38, 1.3), CF(0, -0.35, -0.02), AC.Armor, AC.Edge)
		bevel(r, T, V(2.2, 0.4, 1.45), CF(0, -0.85, 0), AC.ClothDark, AC.Edge, M.Fabric)
		bevel(r, T, V(0.55, 0.5, 0.16), CF(0, -0.85, -0.78), AC.Edge, AC.ArmorMid)
		gem(r, T, 0.22, CF(0, -0.85, -0.88), C.Neon)
		for _, s in ipairs(SIDES) do
			bevel(r, T, V(0.75, 0.9, 1.1), CF(0.92 * s, -1.3, -0.05) * ANG(0, 0, rad(12 * s)), AC.ArmorMid, AC.Edge)
		end
		-- рваный плащ
		r:Cape(2.4, 4.6, AC.Cloth, true)
		r.Sec.Cape = { Amp = 0.12, Speed = 1.4 }
		r.Sec.Cape2 = { Amp = 0.18, Speed = 1.4 }

		-- ГОЛОВА: гранёный шлем, Т-образный визор, нащёчники, рога
		bevel(r, H, V(1.35, 1.45, 1.4), CF(0, 0.05, 0), AC.Armor, AC.Edge)
		bevel(r, H, V(1.15, 1.0, 0.25), CF(0, -0.1, -0.72), AC.ArmorMid, AC.Edge)
		r:Neon(H, V(0.9, 0.12, 0.06), CF(0, 0.2, -0.86), C.Neon)
		r:Neon(H, V(0.12, 0.55, 0.06), CF(0, -0.08, -0.86), C.Neon)
		for _, s in ipairs(SIDES) do
			r:Wedge(H, V(0.3, 0.6, 0.6), CF(0.6 * s, -0.55, -0.5) * ANG(PI, 0, 0), AC.Armor, M.Metal)
			hornA(r, H, { V(0.6 * s, 0.35, 0.05), V(0.95 * s, 0.6, 0.1), V(1.1 * s, 1.1, 0.05), V(0.95 * s, 1.6, -0.15) }, 0.28, AC.Armor, M.Metal)
		end
		r:Glow(H, C.Neon, 8, 1.2)
		-- высокая сломанная корона: высокие зубцы ломаются, на их месте светятся обломки
		local crownTall, stubs = {}, {}
		for i = 0, 3 do
			r:Box(H, V(1.5, 0.28, 0.14), CF(0, 0.82, 0) * ANG(0, i * PI / 2, 0) * CF(0, 0, -0.7), GOLD, M.Metal)
		end
		for _, c in ipairs(ENTITY_CROWN) do
			local base = V(c[1], 0.9, -0.7)
			local tip = base + V(c[1] * 0.3, c[2], 0.15)
			local p = spike(r, H, base, tip, 0.3 + c[2] * 0.05, GOLD, M.Metal, false, 0.1)
			r:Neon(H, V(0.18, 0.18, 0.08), CF(base + V(0, 0, -0.08)) * ANG(0, 0, rad(45)), C.Neon)
			if c[3] then
				add(crownTall, p)
				stubs[#stubs + 1] = r:Seg(H, base, base + V(0, 0.3, 0), 0.16, C.NeonSoft, M.Neon)
			end
		end
		hide(stubs)

		entityArms(r, GOLD)
		-- свисающие цепи
		chain(r, hub(r, "SwayChainL", LA, CF(-0.15, -1.75, 0.3), { Amp = 0.25, Speed = 2.2 }), 6, 0.36)
		for _, x in ipairs({ -0.8, 0.8 }) do
			chain(r, hub(r, x < 0 and "SwayChainW1" or "SwayChainW2", T, CF(x, -1.05, -0.65), { Amp = 0.2, Speed = 2 + x }), 4, 0.3)
		end
		-- набедренник с руной и рваным краем
		local cloth = r:Joint("SwayCloth", T, V(1.2, 1.7, 0.1), CF(0, -1.05, -0.75), CF(0, -0.85, 0), AC.Cloth, M.Fabric)
		gem(r, cloth, 0.3, CF(0, 0.2, -0.07), C.NeonSoft)
		tatter(r, cloth, -0.85, 0, 1.2, 4, AC.Cloth, M.Fabric, 2)
		r.Sec.SwayCloth = { Amp = 0.15, Speed = 1.8 }
		-- ноги: бедро, наколенник-шип, поножи, сапоги
		for _, Lg in ipairs({ RL, LL }) do
			bevel(r, Lg, V(1.05, 1.0, 1.05), CF(0, 0.45, 0), AC.Armor, AC.Edge)
			bevel(r, Lg, V(0.8, 0.5, 0.3), CF(0, -0.05, -0.62), AC.ArmorMid, GOLD)
			spike(r, Lg, V(0, 0.1, -0.7), V(0, 0.55, -1.1), 0.36, AC.Armor, M.Metal)
			bevel(r, Lg, V(1.1, 0.7, 1.12), CF(0, -0.38, 0), AC.ArmorMid, AC.Edge)
			bootA(r, Lg, AC.Armor, AC.Edge, 1.2)
		end

		-- РАЗБИТОЕ КОЛЬЦО за спиной (каждая третья золотая дуга отлетает на 30%, обнажая неоновый каркас)
		local halo = hub(r, "SpinHalo", T, CF(0, 1.7, 1.35), { Speed = 0.35 })
		local ringParts = ring(r, halo, CF(), 2.6, 16, 0.3, 0.25, GOLD, M.Metal, function(i)
			return i == 3 or i == 10 or i == 11
		end)
		ring(r, halo, CF(0, 0, -0.06), 2.32, 16, 0.08, 0.08, C.Neon, M.Neon, function(i)
			return i == 3 or i == 10 or i == 11 or i == 12
		end)
		for i = 0, 5 do
			local a = i / 6 * PI * 2 + 0.3
			gem(r, halo, 0.3, CF(math.cos(a) * 2.6, math.sin(a) * 2.6, -0.16), C.NeonSoft)
		end
		local ringBreak = {}
		for i, p in ipairs(ringParts) do
			if i % 3 == 0 then
				ringBreak[#ringBreak + 1] = p
			end
		end
		local ringStub = hide(ring(r, halo, CF(0, 0, -0.1), 2.6, 16, 0.1, 0.28, C.Neon, M.Neon, function(i)
			return i % 3 ~= 2
		end))

		-- ПАРЯЩИЕ КАМНИ с кристаллами и кольцо осколков над плечами
		local stones = hub(r, "OrbitStones", T, CF(0, -0.5, 0), { Speed = 0.6 })
		for i = 0, 5 do
			local a = i / 6 * PI * 2
			local s = 0.42 + (i % 3) * 0.12
			local p = V(math.cos(a) * 4.0, math.sin(a * 2) * 0.5, math.sin(a) * 4.0)
			bevel(r, stones, V(s * 1.3, s, s * 1.1), CF(p) * ANG(i * 0.7, i * 1.3, i * 0.4), C.Night, C.Mid, M.Slate)
			spike(r, stones, p + V(0, s * 0.3, 0), p + V(s * 0.2, s * 1.2, 0), s * 0.5, C.Neon, M.Neon, true)
		end
		local shards = hub(r, "OrbitShards", T, CF(0, 1.7, 0), { Speed = -1.2 })
		for i = 0, 4 do
			local a = i / 5 * PI * 2
			local p = V(math.cos(a) * 2.9, 0, math.sin(a) * 2.9)
			spike(r, shards, p - V(0, 0.3, 0), p + V(0, 0.4, 0), 0.3, C.Neon, M.Neon)
		end

		emitter(T, C.Neon, { Rate = 10, Size = 0.6, Accel = V(0, 2, 0) })
		local smoke = emitter(emitPoint(r, T, CF(0, -3.2, 0), V(2.5, 0.4, 2.5)), rgb(50, 20, 80), { Smoke = true, Rate = 5, Size = 2, SizeEnd = 3.5, LifeMin = 1, LifeMax = 1.8, T0 = 0.6 })

		-- 65%: трещины по броне, шлему и ногам
		local cracks2 = hide(join(
			crack(r, T, { V(0.3, 1.1, -0.82), V(0.6, 0.75, -1.02), V(0.45, 0.3, -1.02), V(0.8, 0.05, -1.0) }, 0.08),
			crack(r, T, { V(1.2, 1.0, -0.8), V(1.0, 0.45, -0.8) }, 0.07),
			crack(r, H, { V(0.45, 0.6, -0.71), V(0.25, 0.35, -0.71), V(0.4, 0.05, -0.71) }, 0.06),
			crack(r, RL, { V(0.3, -0.1, -0.57), V(-0.1, -0.6, -0.57) }, 0.07),
			crack(r, LL, { V(-0.3, -0.15, -0.57), V(0.15, -0.65, -0.57) }, 0.07)
		))
		local aura2 = emitter(T, C.NeonSoft, { Rate = 14, Size = 0.45, SpeedMin = 2, SpeedMax = 4, Off = true })
		-- 30%: внешнее кольцо осколков (скрыто до фазы)
		local extraHub = hub(r, "OrbitShards3", T, CF(0, 0.4, 0), { Speed = 1.8 })
		local extra = {}
		for i = 0, 7 do
			local a = i / 8 * PI * 2
			local p = V(math.cos(a) * 4.4, math.sin(a * 3) * 0.6, math.sin(a) * 4.4)
			add(extra, spike(r, extraHub, p - V(0, 0.35, 0), p + V(0, 0.45, 0), 0.32, C.NeonSoft, M.Neon, true))
		end
		hide(extra)
		local rage = emitter(T, C.Magenta, { Rate = 20, Size = 0.5, SpeedMin = 3, SpeedMax = 7, Off = true })
		r.Phases = {
			{ At = 0.65, Reveal = cracks2, Emit = { aura2 }, Lights = { { coreLight, 3.5 } }, Aggro = 1.1 },
			{ At = 0.30, Reveal = join(stubs, extra, ringStub), Break = join(crownTall, ringBreak), Emit = { rage, smoke }, Lights = { { coreLight, 5 } }, Aggro = 1.4 },
		}
		return finishBiped(r, scale, { Root = { 4, 0, 0 }, RS = { 6, 0, 12 }, LS = { 6, 0, -12 } }, 7.4)
	end

	EnemyModels.Register("LostSoul", LostSoul)
	EnemyModels.Register("VoidCrawler", VoidCrawler)
	EnemyModels.Register("ShadowBeast", ShadowBeast)
	EnemyModels.Register("ArmoredHorror", ArmoredHorror)
	EnemyModels.Register("RiftPhantom", RiftPhantom)
	EnemyModels.Register("AbyssBrute", AbyssBrute)
	EnemyModels.Register("CorruptedTitan", CorruptedTitan)
	EnemyModels.Register("VoidDevourer", VoidDevourer)
	EnemyModels.Register("TheEntity", TheEntity)
end
