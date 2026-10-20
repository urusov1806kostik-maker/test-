--!nocheck
-- VOID TD :: Models/Enemies/Halloween
-- Хэллоуинские враги карты Haunted Hollow (12) в том же угловатом стиле: CursedDead PumpkinRunner
-- PhantomWarrior BoneGuard LivingScarecrow StrawMinion FogWarlock PumpkinBrute NightReaper (мини-босс)
-- и боссы GraveWarden (Лёгкая), FogReaper (Средняя), CursedMonarch (Сложная).
-- Палитра: чёрный, тёмно-фиолетовый, оранжевый, бордовый, золото, болотно-зелёный, кость.
--
-- Поля rig для эффектов (HalloweenFX):
--   DeathFX  GreenSmoke | PumpkinBurst | Ghost | BoneShards | Straw | Fog | Reaper | GraveBreak | MonarchDeath
--   SpawnFX  GraveBreak | FogVortex | MonarchPortal (только боссы, при появлении в начале пути)
-- Атрибуты деталей: Outline = true — контур Призрачного воина (виден в фазе невидимости);
--   Crown = true — корона Проклятого монарха (падает при смерти).
-- Детали "ShieldFX" (скрыты, PT 0.6) — щит Ночного жнеца; эмиттеры "FogFX" (выключены) — импульс тумана.

return function(EnemyModels, Kit, Base)
	local V = Vector3.new
	local V2 = Vector2.new
	local CF = CFrame.new
	local ANG = CFrame.Angles
	local rad = math.rad
	local PI = math.pi

	local C, HC, M, rgb = Base.C, Base.HC, Base.M, Base.rgb
	local newCreature, newBiped, setup, hub = Base.newCreature, Base.newBiped, Base.setup, Base.hub
	local emitter, emitPoint = Base.emitter, Base.emitPoint
	local finishCreature, finishBiped = Base.finishCreature, Base.finishBiped
	local pumpkin, deepHood, claws, mark, outline = Base.pumpkin, Base.deepHood, Base.claws, Base.mark, Base.outline
	local bevel, bar, spike, gem, tatter = Kit.bevel, Kit.bar, Kit.spike, Kit.gem, Kit.tatter
	local crack, hide, join, hornA, pauldron, bootA, chain = Kit.crack, Kit.hide, Kit.join, Kit.hornA, Kit.pauldron, Kit.bootA, Kit.chain

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
	-- 1. CURSED DEAD — медленный проклятый мертвец: руки вперёд, гнилая кожа, зелёные глаза
	------------------------------------------------------------------------
	local function CursedDead(scale)
		local r = newBiped("CursedDead", V(1.15, 1.15, 1.15))
		setup(r, { Style = "Biped", Gait = { Speed = 0.7, Stride = 0.35, Bob = 0.08, Sway = 0.14, Lean = 10 }, Death = "Collapse", DeathFX = "GreenSmoke" })
		local T, Hd = r.Torso, r.Head
		-- рваная рубаха и торчащие рёбра
		bevel(r, T, V(2, 2, 1), CF(), HC.Rag, HC.RagHi, M.Fabric)
		r:Box(T, V(0.9, 0.8, 0.08), CF(0.35, 0.35, -0.51), HC.Rot, M.Plastic)
		for i = 0, 2 do
			r:Box(T, V(0.7, 0.08, 0.06), CF(0.38, 0.62 - i * 0.22, -0.56), C.Bone, M.Plastic)
		end
		tatter(r, T, -0.95, -0.52, 2, 4, HC.Rag, M.Fabric, 2)
		r:Box(T, V(2.04, 0.3, 1.04), CF(0, -0.85, 0), HC.Burnt, M.Fabric)
		-- голова: гнилая кожа, ввалившиеся глаза, отвисшая челюсть
		bevel(r, Hd, V(1.15, 1.1, 1.15), CF(0, 0.03, 0), HC.Rot, HC.RotHi, M.Plastic)
		r:Box(Hd, V(1.18, 0.35, 1.18), CF(0, 0.45, 0.04), HC.RotDark, M.Plastic)
		for _, s in ipairs(SIDES) do
			r:Box(Hd, V(0.34, 0.3, 0.06), CF(0.27 * s, 0.12, -0.58), HC.RotDark, M.Plastic)
			r:Neon(Hd, V(0.16, 0.14, 0.06), CF(0.27 * s, 0.1, -0.61), HC.Green)
		end
		r:Box(Hd, V(0.6, 0.3, 0.08), CF(0, -0.38, -0.58), rgb(20, 16, 18), M.Plastic)
		for _, x in ipairs({ -0.18, 0.05, 0.2 }) do
			r:Box(Hd, V(0.08, 0.1, 0.06), CF(x, -0.27, -0.62), C.Bone, M.Plastic)
		end
		-- гнилые руки с когтями, правая в лохмотьях рукава
		for _, A in ipairs({ r.RArm, r.LArm }) do
			bevel(r, A, V(0.9, 2, 0.9), CF(), HC.Rot, HC.RotHi, M.Plastic)
			claws(r, A, HC.RotDark, 3, 0.4)
		end
		bevel(r, r.RArm, V(1.02, 0.9, 1.02), CF(0, 0.5, 0), HC.Rag, HC.RagHi, M.Fabric)
		for _, Lg in ipairs({ r.RLeg, r.LLeg }) do
			bevel(r, Lg, V(1, 2, 1), CF(), HC.Burnt, HC.RagHi, M.Fabric)
			r:Box(Lg, V(1.02, 0.4, 1.15), CF(0, -0.8, -0.08), HC.RotDark, M.Plastic)
		end
		-- зелёный дымок с плеч
		local e = emitPoint(r, T, CF(0, 0.9, 0), V(1.6, 0.3, 0.8))
		emitter(e, rgb(90, 170, 70), { Smoke = true, Rate = 3, Size = 0.6, SizeEnd = 1.2, LifeMin = 0.8, LifeMax = 1.4, SpeedMin = 0.2, SpeedMax = 0.6, Accel = V(0, 0.8, 0), T0 = 0.6 })
		r:Glow(Hd, HC.Green, 5, 0.6)
		return finishBiped(r, scale, { RS = { 82, 0, 4 }, LS = { 70, 0, -6 }, Neck = { 12, 0, 8 } })
	end

	------------------------------------------------------------------------
	-- 2. PUMPKIN RUNNER — быстрый тыквоголовый бегун, оранжевые искры
	------------------------------------------------------------------------
	local function PumpkinRunner(scale)
		local r = newBiped("PumpkinRunner", V(1.3, 1.3, 1.3))
		setup(r, { Style = "Biped", Gait = { Speed = 1.25, Stride = 0.85, Bob = 0.22, Sway = 0.05, Lean = 16 }, Death = "Scatter", DeathFX = "PumpkinBurst" })
		local T, Hd = r.Torso, r.Head
		-- тонкое тёмное тело в лохмотьях
		bevel(r, T, V(1.7, 1.9, 0.85), CF(), HC.Purple, HC.PurpleHi, M.Fabric)
		r:Box(T, V(1.75, 0.25, 0.9), CF(0, -0.8, 0), HC.Burnt, M.Fabric)
		-- шарф: воротник и развевающийся лоскут
		r:Box(T, V(1.4, 0.3, 1.0), CF(0, 0.85, 0), HC.Burgundy, M.Fabric)
		local scarf = hub(r, "SwayScarf", T, CF(0.4, 0.8, 0.5), { Amp = 0.35, Speed = 6 })
		spike(r, scarf, V(0, 0, 0), V(0.15, -0.3, 1.2), 0.35, HC.Burgundy, M.Fabric, true, 0.06)
		pumpkin(r, Hd, CF(0, 0.05, 0), 0.82)
		r:Glow(Hd, HC.Fire, 6, 0.9)
		for _, A in ipairs({ r.RArm, r.LArm }) do
			bevel(r, A, V(0.7, 2, 0.7), CF(), HC.Purple, HC.PurpleHi, M.Fabric)
			r:Box(A, V(0.72, 0.5, 0.72), CF(0, -0.8, 0), HC.Stem, M.Plastic)
		end
		for _, Lg in ipairs({ r.RLeg, r.LLeg }) do
			bevel(r, Lg, V(0.75, 2, 0.75), CF(), HC.Burnt, HC.RagHi, M.Fabric)
			r:Wedge(Lg, V(0.8, 0.35, 0.45), CF(0, -0.85, -0.55), HC.Stem, M.Plastic)
		end
		-- оранжевые искры
		emitter(Hd, HC.Fire, { Rate = 10, Size = 0.18, LifeMin = 0.3, LifeMax = 0.7, SpeedMin = 1, SpeedMax = 2.5, Accel = V(0, 2, 0) })
		return finishBiped(r, scale, { RS = { -10, 0, 6 }, LS = { -10, 0, -6 }, Root = { 10, 0, 0 } })
	end

	------------------------------------------------------------------------
	-- 3. PHANTOM WARRIOR — призрачный воин с мечом и щитом; контур (Outline) виден при невидимости
	------------------------------------------------------------------------
	local function PhantomWarrior(scale)
		local r = newCreature("PhantomWarrior", V(1.8, 1.8, 1.0))
		setup(r, { Style = "Float", Gait = { Bob = 0.25 }, Death = "Dissipate", Spawn = "Fade", DeathFX = "Ghost" })
		local B = r.Torso
		local gT = { Transparency = 0.3 }
		-- кант фасок + неоновые детали: в Lite канта нет — помечается сам блок (силуэт остаётся виден)
		local function edgeOf(parts, edge)
			outline(parts, edge)
			return parts
		end
		-- призрачный торс в латах, нижняя часть — хвост-дым
		r:Box(B, V(1.8, 1.4, 1.0), CF(0, 0.35, 0), HC.Ghost, M.Plastic, gT)
		edgeOf(bevel(r, B, V(2.0, 1.0, 1.15), CF(0, 0.55, -0.02), HC.GhostDeep, HC.Ghost))
		r:Box(B, V(1.4, 0.7, 0.9), CF(0, -0.6, 0.05), HC.GhostMid, M.Plastic, { Transparency = 0.4 })
		spike(r, B, V(0, -0.9, 0.1), V(0.15, -2.1, 0.35), 1.0, HC.GhostMid, M.Plastic, false)
		-- голова-шлем: Т-визор, гребень
		local head = hub(r, "BobHead", B, CF(0, 1.55, 0), { Amp = 0.06, Speed = 2 })
		edgeOf(bevel(r, head, V(1.1, 1.15, 1.15), CF(), HC.GhostDeep, HC.Ghost))
		mark({
			r:Neon(head, V(0.62, 0.1, 0.06), CF(0, 0.12, -0.6), HC.Ghost),
			r:Neon(head, V(0.1, 0.42, 0.06), CF(0, -0.1, -0.6), HC.Ghost),
		}, "Outline")
		mark(spike(r, head, V(0, 0.55, -0.2), V(0, 1.15, 0.35), 0.7, HC.Ghost, M.Neon, true, 0.1), "Outline")
		-- наплечники
		for _, s in ipairs({ 1, -1 }) do
			edgeOf(bevel(r, B, V(0.9, 0.4, 1.05), CF(1.15 * s, 1.0, 0) * ANG(0, 0, rad(-18 * s)), HC.GhostDeep, HC.Ghost))
		end
		-- рука с мечом (ArmR)
		local armR = hub(r, "ArmR", B, CF(1.25, 0.6, 0))
		r:Seg(armR, V(0, 0, 0), V(0.1, -1.0, -0.3), 0.4, HC.Ghost, M.Plastic, gT)
		r:Box(armR, V(0.18, 0.18, 0.7), CF(0.1, -1.05, -0.35), HC.GhostDeep, M.Metal)
		r:Box(armR, V(0.7, 0.14, 0.14), CF(0.1, -1.05, -0.7), HC.Ghost, M.Metal)
		local bladeA, bladeB = V(0.1, -1.05, -0.75), V(0.1, -1.05, -3.2)
		r:Seg(armR, bladeA, bladeB, V2(0.1, 0.32), HC.GhostMid, M.Metal)
		mark({ r:Seg(armR, bladeA + V(0, 0.17, 0), bladeB + V(0, 0.05, 0), V2(0.06, 0.06), HC.Ghost, M.Neon) }, "Outline")
		mark(spike(r, armR, bladeB, bladeB + V(0, 0, -0.45), 0.32, HC.Ghost, M.Neon, true, 0.1), "Outline")
		-- рука со щитом (ArmL)
		local armL = hub(r, "ArmL", B, CF(-1.25, 0.6, 0))
		r:Seg(armL, V(0, 0, 0), V(-0.1, -1.0, -0.3), 0.4, HC.Ghost, M.Plastic, gT)
		edgeOf(bevel(r, armL, V(0.25, 1.9, 1.3), CF(-0.35, -0.9, -0.45), HC.GhostDeep, HC.Ghost))
		gem(r, armL, 0.4, CF(-0.5, -0.8, -0.45) * ANG(0, -PI / 2, 0), HC.Ghost)
		local e = emitPoint(r, B, CF(0, -1.6, 0.2), V(0.9, 0.4, 0.9))
		emitter(e, HC.GhostMid, { Smoke = true, Rate = 6, Size = 0.8, SizeEnd = 1.4, LifeMin = 0.6, LifeMax = 1.1, Accel = V(0, 0.8, 0), T0 = 0.55 })
		r:Glow(B, HC.Ghost, 7, 0.8)
		return finishCreature(r, scale, 2.6, 4.2)
	end

	------------------------------------------------------------------------
	-- 4. BONE GUARD — скелет в железно-костяной броне с башенным щитом; броня ломается на 50%
	------------------------------------------------------------------------
	local function BoneGuard(scale)
		local r = newBiped("BoneGuard", V(1.15, 1.15, 1.15))
		setup(r, { Style = "Heavy", Gait = { Speed = 0.8, Stride = 0.4, Bob = 0.12, Sway = 0.06, Shake = 0.08 }, Death = "Collapse", DeathFX = "BoneShards" })
		local T, Hd, RA, LA = r.Torso, r.Head, r.RArm, r.LArm
		local glow = HC.Green
		local armor = {}
		-- скелет: позвоночник, рёбра, таз, череп
		r:Box(T, V(0.3, 2, 0.3), CF(0, 0, 0.25), C.BoneDark, M.Plastic)
		for i = 0, 3 do
			r:Box(T, V(1.7 - i * 0.15, 0.14, 0.9), CF(0, 0.75 - i * 0.35, 0), C.Bone, M.Plastic)
		end
		r:Box(T, V(1.6, 0.4, 0.8), CF(0, -0.8, 0), C.BoneDark, M.Plastic)
		bevel(r, Hd, V(1.05, 1.0, 1.1), CF(0, 0.05, 0), C.Bone, C.BoneDark, M.Plastic)
		for _, s in ipairs(SIDES) do
			r:Box(Hd, V(0.3, 0.28, 0.06), CF(0.24 * s, 0.1, -0.56), rgb(16, 14, 18), M.Plastic)
			r:Neon(Hd, V(0.13, 0.12, 0.06), CF(0.24 * s, 0.1, -0.59), glow)
		end
		r:Box(Hd, V(0.7, 0.18, 0.06), CF(0, -0.32, -0.56), rgb(16, 14, 18), M.Plastic)
		-- кости рук и ног
		for _, A in ipairs({ RA, LA }) do
			bar(r, A, V(0, 0.6, 0), V(0, -0.9, 0), 0.32, C.Bone)
			r:Box(A, V(0.5, 0.35, 0.5), CF(0, -1.0, 0), C.BoneDark, M.Plastic)
		end
		for _, Lg in ipairs({ r.RLeg, r.LLeg }) do
			bar(r, Lg, V(0, 0.9, 0), V(0, -0.7, 0), 0.34, C.Bone)
			bootA(r, Lg, HC.Iron, HC.IronHi, 1.05)
		end
		-- БРОНЯ (отваливается на 50%): нагрудник, шлем, наплечники, наручи, поножи
		add(armor, bevel(r, T, V(2.15, 1.25, 1.15), CF(0, 0.45, 0), HC.Iron, HC.IronHi))
		armor[#armor + 1] = r:Wedge(T, V(2.0, 0.45, 0.45), CF(0, 0.55, -0.75) * ANG(PI, PI, 0), HC.Iron, M.Metal)
		add(armor, gem(r, T, 0.32, CF(0, 0.5, -0.62), glow, HC.Rust))
		add(armor, bevel(r, T, V(2.1, 0.45, 1.1), CF(0, -0.45, 0), HC.Rust, HC.IronHi))
		add(armor, bevel(r, Hd, V(1.25, 0.55, 1.25), CF(0, 0.45, 0.02), HC.Iron, HC.IronHi))
		add(armor, spike(r, Hd, V(0, 0.7, 0.1), V(0, 1.3, 0.4), 0.55, HC.Iron, M.Metal, true, 0.1))
		for _, s in ipairs(SIDES) do
			add(armor, hornA(r, Hd, { V(0.55 * s, 0.4, 0), V(0.85 * s, 0.6, 0), V(0.9 * s, 1.05, 0.1) }, 0.2, C.Bone))
		end
		for _, a in ipairs(arms(r)) do
			local A, s = a[1], a[2]
			add(armor, bevel(r, A, V(1.35, 0.55, 1.3), CF(0.15 * s, 0.85, 0) * ANG(0, 0, rad(-14 * s)), HC.Iron, HC.IronHi))
			add(armor, spike(r, A, V(0.35 * s, 1.1, 0), V(0.8 * s, 1.75, 0), 0.4, C.Bone, M.Plastic, true, 0.12))
			add(armor, bevel(r, A, V(0.85, 0.7, 0.85), CF(0, -0.45, 0), HC.Rust, HC.IronHi))
		end
		for _, Lg in ipairs({ r.RLeg, r.LLeg }) do
			add(armor, bevel(r, Lg, V(1.05, 0.8, 1.05), CF(0, 0.4, 0), HC.Iron, HC.IronHi))
		end
		-- ржавый тесак в правой руке
		r:Box(RA, V(0.18, 0.18, 0.6), CF(0, -1.05, -0.3), HC.Burnt, M.Wood)
		r:Seg(RA, V(0, -1.0, -0.6), V(0, -0.95, -2.6), V2(0.12, 0.5), HC.Rust, M.Metal)
		r:Box(RA, V(0.14, 0.08, 1.9), CF(0, -0.72, -1.6), HC.IronHi, M.Metal)
		-- башенный щит в левой руке (остаётся)
		bevel(r, LA, V(0.3, 2.6, 1.6), CF(-0.6, -0.6, -0.4), HC.Iron, HC.IronHi)
		r:Box(LA, V(0.34, 2.4, 0.25), CF(-0.6, -0.6, -0.4), C.Bone, M.Plastic)
		r:Box(LA, V(0.34, 0.25, 1.3), CF(-0.6, -0.1, -0.4), C.Bone, M.Plastic)
		gem(r, LA, 0.3, CF(-0.78, -0.1, -0.4) * ANG(0, -PI / 2, 0), glow)
		r:Glow(T, glow, 6, 0.7)
		local shards = emitter(T, C.Bone, { Rate = 22, Size = 0.25, SpeedMin = 3, SpeedMax = 6, LifeMin = 0.3, LifeMax = 0.6, Accel = V(0, -12, 0), Off = true })
		r.Phases = { { At = 0.5, Break = armor, Emit = { shards }, Aggro = 1.15 } }
		return finishBiped(r, scale, { RS = { 10, 0, 6 }, LS = { 25, 0, -8 } })
	end

	------------------------------------------------------------------------
	-- 5. LIVING SCARECROW — живое пугало: мешок-голова, шляпа, солома, ворона на плече
	------------------------------------------------------------------------
	local function LivingScarecrow(scale)
		local r = newBiped("LivingScarecrow", V(1.2, 1.25, 1.2))
		setup(r, { Style = "Biped", Gait = { Speed = 0.9, Stride = 0.5, Bob = 0.14, Sway = 0.16, Lean = 4 }, Death = "Topple", DeathFX = "Straw" })
		local T, Hd, LA, LL = r.Torso, r.Head, r.LArm, r.LLeg
		-- клетчатая рубаха: бордовый с тёмными полосами, верёвочный пояс, шест за спиной
		bevel(r, T, V(2, 2, 1), CF(), HC.Burgundy, HC.BurgundyHi, M.Fabric)
		for _, s in ipairs(SIDES) do
			r:Box(T, V(0.18, 2.02, 1.02), CF(0.45 * s, 0, 0), HC.Burnt, M.Fabric)
		end
		r:Box(T, V(2.04, 0.2, 1.04), CF(0, -0.8, 0), HC.StrawDark, M.Fabric)
		r:Box(T, V(0.3, 4.5, 0.3), CF(0, 0.4, 0.75), HC.Burnt, M.Wood)
		-- мешок-голова: сшитые глаза-кресты, светящийся рот-шов
		bevel(r, Hd, V(1.2, 1.25, 1.2), CF(), HC.Sack, HC.SackDark, M.Fabric)
		for _, s in ipairs(SIDES) do
			r:Neon(Hd, V(0.34, 0.08, 0.05), CF(0.27 * s, 0.15, -0.61) * ANG(0, 0, rad(45)), HC.Fire)
			r:Neon(Hd, V(0.34, 0.08, 0.05), CF(0.27 * s, 0.15, -0.61) * ANG(0, 0, rad(-45)), HC.Fire)
		end
		r:Neon(Hd, V(0.7, 0.07, 0.05), CF(0, -0.28, -0.61) * ANG(0, 0, rad(-6)), HC.Fire)
		for i = -2, 2 do
			r:Box(Hd, V(0.04, 0.2, 0.06), CF(i * 0.15, -0.28, -0.63), HC.SackDark, M.Fabric)
		end
		-- перевязь на шее и солома из-под мешка
		r:Box(Hd, V(1.0, 0.16, 1.0), CF(0, -0.55, 0), HC.StrawDark, M.Fabric)
		for i = 0, 4 do
			local a = i / 5 * PI * 2
			spike(r, T, V(math.cos(a) * 0.45, 0.95, math.sin(a) * 0.4), V(math.cos(a) * 0.75, 1.25, math.sin(a) * 0.6), 0.22, HC.Straw, M.Fabric, true, 0.05)
		end
		-- соломенная шляпа с широкими полями
		bevel(r, Hd, V(2.3, 0.12, 2.2), CF(0, 0.66, 0) * ANG(rad(-6), 0, rad(5)), HC.StrawDark, HC.Straw, M.Fabric)
		bevel(r, Hd, V(1.2, 0.55, 1.2), CF(0.02, 0.98, 0.02) * ANG(rad(-6), 0, rad(8)), HC.Straw, HC.StrawDark, M.Fabric)
		r:Box(Hd, V(1.24, 0.14, 1.24), CF(0, 0.8, 0) * ANG(rad(-6), 0, rad(6)), HC.Burgundy, M.Fabric)
		-- руки-рукава с соломой на концах
		for _, A in ipairs({ r.RArm, LA }) do
			bevel(r, A, V(1.0, 2, 1.0), CF(0, 0.1, 0), HC.Burgundy, HC.BurgundyHi, M.Fabric)
			for k = -1, 1 do
				spike(r, A, V(k * 0.25, -0.85, 0), V(k * 0.4, -1.55, k * 0.1), 0.25, HC.Straw, M.Fabric, true, 0.05)
			end
		end
		-- штаны с соломой и заплатой
		for _, Lg in ipairs({ r.RLeg, LL }) do
			bevel(r, Lg, V(1, 2, 1), CF(), HC.Rag, HC.RagHi, M.Fabric)
			spike(r, Lg, V(0, -0.9, 0), V(0.05, -1.3, -0.2), 0.5, HC.Straw, M.Fabric, true, 0.05)
		end
		r:Box(LL, V(0.5, 0.5, 0.06), CF(0.1, 0.2, -0.52), HC.SackDark, M.Fabric)
		-- ворона на левом плече (резко вертит головой)
		local crow = hub(r, "TwitchCrow", LA, CF(-0.1, 1.15, 0), { Amp = 0.5, Speed = 1 })
		r:Box(crow, V(0.4, 0.42, 0.65), CF(0, 0.2, 0.05), HC.Crow, M.Plastic)
		r:Box(crow, V(0.32, 0.32, 0.32), CF(0, 0.5, -0.25), HC.Crow, M.Plastic)
		spike(r, crow, V(0, 0.48, -0.4), V(0, 0.45, -0.75), 0.16, HC.GoldDark, M.Plastic, true, 0.1)
		r:Neon(crow, V(0.36, 0.06, 0.06), CF(0, 0.55, -0.3), HC.Red)
		spike(r, crow, V(0, 0.2, 0.35), V(0, 0.05, 0.85), 0.35, HC.Crow, M.Plastic, true, 0.06)
		r:Glow(Hd, HC.Fire, 5, 0.6)
		return finishBiped(r, scale, { RS = { 12, 0, 50 }, LS = { 12, 0, -50 }, Neck = { 0, 0, -10 } })
	end

	------------------------------------------------------------------------
	-- 6. STRAW CREATURE (StrawMinion) — маленький соломенный бегун из пугала
	------------------------------------------------------------------------
	local function StrawMinion(scale)
		local r = newBiped("StrawMinion", V(1.0, 1.0, 1.0))
		setup(r, { Style = "Biped", Gait = { Speed = 1.5, Stride = 0.9, Bob = 0.25, Sway = 0.1, Lean = 12 }, Death = "Scatter", DeathFX = "Straw" })
		local T, Hd = r.Torso, r.Head
		r:Box(T, V(1.7, 2, 0.95), CF(), HC.Straw, M.Fabric)
		for _, y in ipairs({ 0.4, -0.5 }) do
			r:Box(T, V(1.74, 0.22, 1.0), CF(0, y, 0), HC.SackDark, M.Fabric)
		end
		r:Box(Hd, V(1.0, 1.0, 1.0), CF(), HC.Sack, M.Fabric)
		for _, s in ipairs(SIDES) do
			r:Neon(Hd, V(0.18, 0.18, 0.05), CF(0.22 * s, 0.1, -0.51), HC.Fire)
		end
		spike(r, Hd, V(0, 0.45, 0), V(0.1, 1.05, 0.1), 0.45, HC.Straw, M.Fabric, true, 0.06)
		for _, A in ipairs({ r.RArm, r.LArm }) do
			r:Box(A, V(0.6, 2, 0.6), CF(), HC.StrawDark, M.Fabric)
		end
		for _, Lg in ipairs({ r.RLeg, r.LLeg }) do
			r:Box(Lg, V(0.7, 2, 0.7), CF(), HC.StrawDark, M.Fabric)
		end
		return finishBiped(r, scale, { RS = { -20, 0, 10 }, LS = { -20, 0, -10 } })
	end

	------------------------------------------------------------------------
	-- 7. FOG WARLOCK — колдун в капюшоне с фонарём на посохе, серо-зелёный туман (импульс FogFX)
	------------------------------------------------------------------------
	local function FogWarlock(scale)
		local r = newBiped("FogWarlock", V(1.2, 1.2, 1.2))
		setup(r, { Style = "Biped", Gait = { Speed = 0.8, Stride = 0.35, Bob = 0.06, Sway = 0.06, Lean = 6 }, Death = "Dissipate", DeathFX = "Fog" })
		local T, Hd, RA = r.Torso, r.Head, r.RArm
		local robeC, robeHi = rgb(46, 52, 50), rgb(104, 116, 106)
		-- мантия до земли с рваным краем
		bevel(r, T, V(2, 2, 1), CF(), robeC, robeHi, M.Fabric)
		bevel(r, T, V(2.2, 1.8, 1.2), CF(0, -1.75, 0.02), robeC, robeHi, M.Fabric)
		tatter(r, T, -2.65, -0.62, 2.2, 5, robeC, M.Fabric, 1)
		r:Box(T, V(0.3, 3.4, 0.06), CF(0, -0.9, -0.52), HC.Burgundy, M.Fabric)
		r:Box(T, V(2.04, 0.22, 1.04), CF(0, -0.75, 0), HC.Burnt, M.Fabric)
		gem(r, T, 0.3, CF(0, -0.75, -0.56), HC.Green, HC.GoldDark)
		-- капюшон с пустотой и зелёными глазами
		local fz = deepHood(r, Hd, 1.45, 1.4, robeC, robeHi)
		spike(r, Hd, V(0, 0.65, 0.4), V(0, 1.3, 1.0), 0.75, robeC, M.Fabric, true, 0.2)
		for _, s in ipairs(SIDES) do
			r:Neon(Hd, V(0.2, 0.08, 0.05), CF(0.22 * s, 0, fz + 0.2) * ANG(0, 0, rad(-12 * s)), HC.Green)
		end
		for _, A in ipairs({ RA, r.LArm }) do
			bevel(r, A, V(1.0, 2, 1.0), CF(), robeC, robeHi, M.Fabric)
			r:Box(A, V(1.15, 0.4, 1.15), CF(0, -0.85, 0), robeHi, M.Fabric)
		end
		for _, Lg in ipairs({ r.RLeg, r.LLeg }) do
			r:Box(Lg, V(0.9, 2, 0.9), CF(), HC.Rag, M.Fabric)
		end
		-- посох с качающимся фонарём
		r:Box(RA, V(0.2, 5.0, 0.2), CF(0, -0.6, -0.5), HC.Burnt, M.Wood)
		local lantern = hub(r, "SwayLantern", RA, CF(0, 1.9, -0.5), { Amp = 0.2, Speed = 2 })
		r:Box(lantern, V(0.08, 0.5, 0.08), CF(0, -0.25, 0), HC.Iron, M.Metal)
		bevel(r, lantern, V(0.6, 0.12, 0.6), CF(0, -0.55, 0), HC.Iron, HC.IronHi)
		r:Neon(lantern, V(0.4, 0.55, 0.4), CF(0, -0.9, 0), HC.Green)
		bevel(r, lantern, V(0.6, 0.12, 0.6), CF(0, -1.25, 0), HC.Iron, HC.IronHi)
		r:Glow(lantern, HC.Green, 8, 1.1)
		-- постоянный лёгкий туман у ног и импульс тумана (FogFX выпускает HalloweenFX)
		local e = emitPoint(r, T, CF(0, -2.6, 0), V(2.2, 0.3, 2.2))
		emitter(e, HC.Fog, { Smoke = true, Rate = 4, Size = 1.2, SizeEnd = 2.4, LifeMin = 1, LifeMax = 1.8, SpeedMin = 0.3, SpeedMax = 0.8, T0 = 0.65 })
		emitter(e, rgb(150, 190, 150), { Name = "FogFX", Smoke = true, Rate = 30, Size = 2.5, SizeEnd = 5.5, LifeMin = 1.2, LifeMax = 2.0, SpeedMin = 3, SpeedMax = 6, T0 = 0.55, Off = true })
		return finishBiped(r, scale, { RS = { 25, 0, 4 }, LS = { 30, 0, -12 }, Neck = { 8, 0, 0 } })
	end

	------------------------------------------------------------------------
	-- 8. PUMPKIN BRUTE — огромный громила с гигантской тыквой вместо головы и дубиной
	------------------------------------------------------------------------
	local function PumpkinBrute(scale)
		local r = newBiped("PumpkinBrute", V(1.6, 1.4, 1.6))
		setup(r, { Style = "Heavy", Gait = { Speed = 0.75, Stride = 0.35, Bob = 0.22, Sway = 0.1, Shake = 0.14, Lean = 6 }, Death = "Topple", DeathFX = "PumpkinBurst" })
		local T, Hd, RA = r.Torso, r.Head, r.RArm
		local skin, skinHi = rgb(60, 72, 44), rgb(104, 120, 76)
		-- массивное тело в мешковине, лямки, лозы
		bevel(r, T, V(2.8, 2.2, 1.7), CF(0, 0.15, 0.1), HC.Rag, HC.RagHi, M.Fabric)
		bevel(r, T, V(2.4, 0.9, 1.5), CF(0, -0.75, -0.05), HC.SackDark, HC.Sack, M.Fabric)
		for _, s in ipairs(SIDES) do
			r:Box(T, V(0.3, 2.2, 0.08), CF(0.7 * s, 0.2, -0.82), HC.Burnt, M.Fabric)
			r:Box(T, V(0.32, 0.32, 0.1), CF(0.7 * s, 0.85, -0.86), HC.GoldDark, M.Metal)
		end
		bar(r, T, V(-1.3, 0.9, -0.85), V(1.2, -0.4, -0.88), 0.16, HC.Stem)
		spike(r, T, V(0.3, 0.3, -0.9), V(0.6, 0.55, -1.15), 0.3, HC.Stem, M.Plastic, true, 0.06)
		pumpkin(r, Hd, CF(0, 0.3, -0.05), 1.15)
		r:Glow(Hd, HC.Fire, 9, 1.2)
		-- огромные руки
		for _, a in ipairs(arms(r)) do
			local A, s = a[1], a[2]
			bevel(r, A, V(1.4, 1.2, 1.4), CF(0.15 * s, 0.5, 0), skin, skinHi, M.Plastic)
			bevel(r, A, V(1.6, 1.4, 1.6), CF(0.2 * s, -0.75, 0), skin, skinHi, M.Plastic)
			bar(r, A, V(0.2 * s, 0.3, -0.75), V(0.25 * s, -0.9, -0.82), 0.12, HC.Stem)
			bevel(r, A, V(1.5, 0.8, 1.5), CF(0.2 * s, -1.7, -0.05), skin, skinHi, M.Plastic)
		end
		-- дубина-коряга с костяными шипами в правой руке
		bar(r, RA, V(0.2, -1.8, -0.4), V(0.25, -1.9, -3.2), 0.45, HC.Burnt, M.Wood)
		spike(r, RA, V(0.25, -1.9, -2.6), V(0.85, -1.6, -2.9), 0.3, C.BoneDark)
		spike(r, RA, V(0.25, -1.9, -3.0), V(-0.35, -2.3, -3.2), 0.3, C.BoneDark)
		for _, Lg in ipairs({ r.RLeg, r.LLeg }) do
			bevel(r, Lg, V(1.25, 2, 1.25), CF(0, 0.05, 0), HC.SackDark, HC.Sack, M.Fabric)
			bevel(r, Lg, V(1.3, 0.55, 1.5), CF(0, -0.8, -0.12), HC.Burnt, HC.RagHi, M.Plastic)
		end
		emitter(Hd, HC.Fire, { Rate = 6, Size = 0.25, LifeMin = 0.4, LifeMax = 0.8, SpeedMin = 1, SpeedMax = 2, Accel = V(0, 2.5, 0) })
		return finishBiped(r, scale, { Root = { 10, 0, 0 }, Neck = { -8, 0, 0 }, RS = { 10, 0, 8 }, LS = { 8, 0, -8 } })
	end

	------------------------------------------------------------------------
	-- 9. NIGHT REAPER (мини-босс) — парящий жнец с косой, рваный плащ, оболочка щита (ShieldFX)
	------------------------------------------------------------------------
	local function NightReaper(scale)
		local r = newCreature("NightReaper", V(2.0, 2.0, 1.2))
		setup(r, { Style = "Float", Gait = { Bob = 0.3 }, Death = "Dissipate", Spawn = "Fade", DeathFX = "Reaper" })
		local B = r.Torso
		local cloth, clothHi = rgb(24, 18, 32), rgb(78, 56, 104)
		local glow = HC.PurpleGlow
		-- плащ-балахон, сужающийся книзу
		bevel(r, B, V(2.2, 1.6, 1.3), CF(0, 0.5, 0), cloth, clothHi, M.Fabric)
		bevel(r, B, V(1.9, 1.3, 1.15), CF(0, -0.85, 0.05), cloth, clothHi, M.Fabric)
		bevel(r, B, V(1.4, 1.0, 0.95), CF(0, -1.95, 0.1), cloth, clothHi, M.Fabric)
		tatter(r, B, -2.4, -0.45, 1.5, 4, cloth, M.Fabric, 3)
		spike(r, B, V(0, -2.3, 0.2), V(0.2, -3.3, 0.5), 0.9, cloth, M.Fabric, true, 0.12)
		-- цепь-пояс и череп-трофей
		chain(r, B, 3, 0.35, HC.IronHi, CF(0.6, -0.3, -0.6) * ANG(0, 0, rad(70)))
		r:Box(B, V(0.42, 0.42, 0.4), CF(-0.55, -0.25, -0.62), C.Bone, M.Plastic)
		-- капюшон с черепом
		local head = hub(r, "BobHead", B, CF(0, 1.75, 0), { Amp = 0.06, Speed = 1.6 })
		local fz = deepHood(r, head, 1.6, 1.55, cloth, clothHi)
		spike(r, head, V(0, 0.7, 0.35), V(0, 1.4, 1.1), 0.85, cloth, M.Fabric, true, 0.2)
		r:Box(head, V(0.95, 1.0, 0.3), CF(0, -0.1, fz + 0.15), C.Bone, M.Plastic)
		for _, s in ipairs(SIDES) do
			r:Box(head, V(0.3, 0.26, 0.06), CF(0.24 * s, 0.02, fz - 0.01), rgb(10, 8, 14), M.Plastic)
			r:Neon(head, V(0.14, 0.12, 0.06), CF(0.24 * s, 0.01, fz - 0.04), glow)
		end
		r:Box(head, V(0.6, 0.12, 0.06), CF(0, -0.38, fz - 0.01), rgb(10, 8, 14), M.Plastic)
		-- наплечная накидка с рваными концами
		for _, s in ipairs(SIDES) do
			bevel(r, B, V(1.0, 0.45, 1.4), CF(1.0 * s, 1.15, 0) * ANG(0, 0, rad(-20 * s)), cloth, clothHi, M.Fabric)
			spike(r, B, V(1.35 * s, 0.9, 0), V(1.6 * s, 0.1, 0.1), 0.6, cloth, M.Fabric, true, 0.1)
		end
		-- правая рука-кость с косой
		local armR = hub(r, "ArmR", B, CF(1.3, 0.75, 0))
		bar(r, armR, V(0, 0, 0), V(0.1, -1.0, -0.4), V2(0.6, 0.6), cloth)
		r:Box(armR, V(0.35, 0.35, 0.35), CF(0.1, -1.15, -0.45), C.Bone, M.Plastic)
		r:Box(armR, V(0.2, 5.4, 0.2), CF(0.1, -0.9, -0.55), HC.Burnt, M.Wood)
		local top = V(0.1, 1.75, -0.55)
		local pts = { top, top + V(0, 0.2, -0.8), top + V(0, -0.15, -1.9), top + V(0, -0.8, -2.5) }
		for i = 1, 3 do
			bar(r, armR, pts[i], pts[i + 1], V2(0.1, 0.45 - i * 0.08), HC.IronHi, M.Metal)
		end
		bar(r, armR, pts[2] + V(0, -0.2, 0), pts[3] + V(0, -0.15, 0), V2(0.12, 0.06), glow, M.Neon)
		-- левая рука: костяные пальцы
		local armL = hub(r, "ArmL", B, CF(-1.3, 0.75, 0))
		bar(r, armL, V(0, 0, 0), V(-0.1, -1.0, -0.4), V2(0.6, 0.6), cloth)
		for k = -1, 1 do
			spike(r, armL, V(-0.1 + k * 0.1, -1.2, -0.45), V(-0.15 + k * 0.15, -1.75, -0.65), 0.12, C.Bone, M.Plastic, true, 0.05)
		end
		-- оболочка щита: фиолетовые плиты вокруг (скрыты, PT 0.6; показывает HalloweenFX)
		local shell = hub(r, "OrbitShield", B, CF(), { Speed = 0.6 })
		local plates = {}
		for i = 0, 5 do
			local a = i / 6 * PI * 2
			plates[#plates + 1] = r:Box(shell, V(1.5, 2.6, 0.12), CF(math.cos(a) * 2.2, 0, math.sin(a) * 2.2) * ANG(0, -a + PI / 2, 0), glow, M.Neon, { Name = "ShieldFX", Transparency = 0.6 })
		end
		hide(plates, 0.6)
		local e = emitPoint(r, B, CF(0, -2.6, 0.2), V(1.2, 0.4, 1.2))
		emitter(e, rgb(60, 30, 90), { Smoke = true, Rate = 6, Size = 1.0, SizeEnd = 1.8, LifeMin = 0.7, LifeMax = 1.2, Accel = V(0, 0.8, 0), T0 = 0.55 })
		r:Glow(head, glow, 8, 1)
		return finishCreature(r, scale, 3.4, 5.2)
	end

	------------------------------------------------------------------------
	-- 10. GRAVE WARDEN (босс, Лёгкая) — каменно-железный страж кладбища: надгробие-щит, молот,
	-- фонарь на поясе. 66% — трещины по камню и латам; 33% — латы отваливаются, светится ядро
	------------------------------------------------------------------------
	local function GraveWarden(scale)
		local r = newBiped("GraveWarden", V(1.35, 1.3, 1.35))
		setup(r, { Style = "Heavy", Gait = { Speed = 0.7, Stride = 0.36, Bob = 0.2, Sway = 0.08, Shake = 0.3, Lean = 3 }, Death = "Collapse", Spawn = "Titan", SpawnFX = "GraveBreak", DeathFX = "GraveBreak" })
		local T, Hd, RA, LA, RL, LL = r.Torso, r.Head, r.RArm, r.LArm, r.RLeg, r.LLeg
		local glow = HC.Green
		local function stone(limb, size, cf, light)
			return bevel(r, limb, size, cf, light and HC.Stone or HC.StoneDark, light and HC.StoneHi or HC.Stone, M.Slate)
		end
		local plates = {}
		-- каменное тело, между глыбами светится зелёное ядро
		r:Box(T, V(2.1, 2.0, 1.2), CF(0, 0.1, 0.05), glow, M.Neon)
		stone(T, V(1.2, 1.15, 1.45), CF(-0.6, 0.6, 0.05) * ANG(rad(3), rad(5), rad(4)), false)
		stone(T, V(1.2, 1.1, 1.45), CF(0.62, 0.62, 0.05) * ANG(rad(-3), rad(-4), rad(-5)), true)
		stone(T, V(2.2, 0.95, 1.4), CF(0, -0.45, 0), false)
		-- железные латы (отваливаются на 33%)
		add(plates, bevel(r, T, V(2.6, 1.2, 0.5), CF(0, 0.6, -0.8), HC.Iron, HC.IronHi))
		plates[#plates + 1] = r:Wedge(T, V(2.4, 0.5, 0.5), CF(0, -0.2, -0.8) * ANG(PI, PI, 0), HC.Iron, M.Metal)
		add(plates, gem(r, T, 0.45, CF(0, 0.6, -1.08), glow, HC.GoldDark))
		bevel(r, T, V(2.3, 0.45, 1.6), CF(0, -1.0, 0), HC.Rust, HC.IronHi)
		-- фонарь на поясе
		r:Box(T, V(0.08, 0.4, 0.08), CF(-0.8, -1.3, -0.82), HC.Iron, M.Metal)
		bevel(r, T, V(0.55, 0.12, 0.55), CF(-0.8, -1.5, -0.82), HC.Iron, HC.IronHi)
		r:Neon(T, V(0.38, 0.5, 0.38), CF(-0.8, -1.8, -0.82), HC.Fire)
		bevel(r, T, V(0.55, 0.12, 0.55), CF(-0.8, -2.1, -0.82), HC.Iron, HC.IronHi)
		r:Glow(T, HC.Fire, 8, 0.8)
		-- каменная голова в шлеме, щель глаз, корона из надгробий
		stone(Hd, V(1.3, 1.25, 1.3), CF(0, -0.05, 0.05), true)
		add(plates, bevel(r, Hd, V(1.5, 0.7, 1.45), CF(0, 0.35, -0.05), HC.Iron, HC.IronHi))
		r:Box(Hd, V(1.0, 0.16, 0.06), CF(0, 0, -0.68), rgb(10, 12, 10), M.Plastic)
		for _, s in ipairs(SIDES) do
			r:Neon(Hd, V(0.26, 0.1, 0.06), CF(0.25 * s, 0, -0.71), glow)
		end
		for i = -1, 1 do
			stone(Hd, V(0.4, 0.55 + (i == 0 and 0.25 or 0), 0.25), CF(i * 0.45, 0.95, 0.1), i == 0)
		end
		-- наплечники-плиты, каменные руки, латные перчатки
		for _, a in ipairs(arms(r)) do
			local A, s = a[1], a[2]
			add(plates, pauldron(r, A, s, 1.2, HC.Iron, HC.IronHi, glow, 1))
			stone(A, V(1.05, 1.0, 1.05), CF(0, 0.1, 0) * ANG(0, rad(10), rad(4 * s)), false)
			stone(A, V(1.2, 0.9, 1.2), CF(0, -0.75, 0), true)
			bevel(r, A, V(1.4, 0.7, 1.4), CF(0, -1.45, -0.05), HC.Iron, HC.IronHi)
		end
		-- молот-надгробие в правой руке
		r:Box(RA, V(0.3, 0.3, 4.2), CF(0, -1.45, -1.7), HC.Burnt, M.Wood)
		stone(RA, V(1.5, 1.2, 1.0), CF(0, -1.45, -4.0), true)
		r:Box(RA, V(0.15, 0.7, 0.1), CF(0, -1.4, -4.52), HC.StoneDark, M.Slate)
		r:Box(RA, V(0.5, 0.15, 0.1), CF(0, -1.25, -4.52), HC.StoneDark, M.Slate)
		-- надгробие-щит в левой руке: плита со ступенчатым верхом, светящийся крест, мох
		stone(LA, V(0.45, 2.8, 2.0), CF(-0.7, -0.7, -0.35), false)
		stone(LA, V(0.45, 0.6, 1.5), CF(-0.7, 0.95, -0.35), false)
		stone(LA, V(0.45, 0.35, 0.9), CF(-0.7, 1.35, -0.35), false)
		r:Neon(LA, V(0.08, 1.4, 0.2), CF(-0.95, -0.1, -0.35), glow)
		r:Neon(LA, V(0.08, 0.2, 0.9), CF(-0.95, 0.25, -0.35), glow)
		for _, s in ipairs(SIDES) do
			r:Box(LA, V(0.5, 0.5, 0.25), CF(-0.7, -1.9, -0.35 + s * 0.85), HC.Moss, M.Grass)
		end
		for _, Lg in ipairs({ RL, LL }) do
			stone(Lg, V(1.15, 1.05, 1.15), CF(0, 0.45, 0), true)
			add(plates, bevel(r, Lg, V(1.2, 0.7, 1.2), CF(0, -0.42, 0), HC.Iron, HC.IronHi))
			bootA(r, Lg, HC.Rust, HC.IronHi, 1.25)
		end
		-- мох на плече и цепь
		r:Box(T, V(1.0, 0.25, 0.9), CF(0.55, 1.1, 0.2), HC.Moss, M.Fabric)
		chain(r, T, 4, 0.4, HC.IronHi, CF(0.9, 0.9, -1.1) * ANG(0, 0, rad(30)))
		local aura = emitter(T, glow, { Rate = 6, Size = 0.4, Accel = V(0, 2, 0) })
		-- 66%: светящиеся трещины по камню и латам
		local cracks = hide(join(
			crack(r, T, { V(-1.0, 1.15, -1.06), V(-0.55, 0.7, -1.07), V(-0.8, 0.2, -1.06) }, 0.09, glow),
			crack(r, T, { V(0.95, 0.95, -1.06), V(0.5, 0.4, -1.07) }, 0.08, glow),
			crack(r, Hd, { V(-0.4, 0.6, -0.78), V(-0.15, 0.35, -0.78), V(-0.3, 0.1, -0.78) }, 0.06, glow),
			crack(r, RL, { V(0.3, 0.7, -0.6), V(-0.1, 0.2, -0.6) }, 0.07, glow),
			crack(r, LL, { V(-0.3, 0.6, -0.6), V(0.15, 0.1, -0.6) }, 0.07, glow)
		))
		local dust = emitter(T, HC.StoneHi, { Rate = 12, Size = 0.35, SpeedMin = 2, SpeedMax = 4, Accel = V(0, -8, 0), Off = true })
		-- 33%: под латами светится ядро
		local core = hide({ r:Box(T, V(1.6, 0.8, 0.3), CF(0, 0.6, -0.8), glow, M.Neon) })
		local rage = emitter(T, HC.GreenSoft, { Rate = 18, Size = 0.4, SpeedMin = 3, SpeedMax = 6, Off = true })
		r.Phases = {
			{ At = 0.66, Reveal = cracks, Emit = { dust, aura }, Aggro = 1.1 },
			{ At = 0.33, Reveal = core, Break = plates, Emit = { rage }, Aggro = 1.3 },
		}
		return finishBiped(r, scale, { Root = { 6, 0, 0 }, RS = { 15, 0, 8 }, LS = { 25, 0, -10 } }, 6.6)
	end

	------------------------------------------------------------------------
	-- 11. FOG REAPER (босс, Средняя) — огромный жнец из тумана с двойной косой.
	-- 50% — белые глаза гаснут, красное свечение (глаза и ядро), красный дым, ярость
	------------------------------------------------------------------------
	local function FogReaper(scale)
		local r = newCreature("FogReaper", V(2.4, 2.2, 1.4))
		setup(r, { Style = "Float", Gait = { Bob = 0.35 }, Death = "Implode", Spawn = "Fade", SpawnFX = "FogVortex", DeathFX = "Fog" })
		local B = r.Torso
		local cloth, clothHi = rgb(40, 44, 48), rgb(120, 130, 134)
		-- слоистый балахон, переходящий в туман
		bevel(r, B, V(2.6, 1.8, 1.5), CF(0, 0.6, 0), cloth, clothHi, M.Fabric)
		bevel(r, B, V(2.3, 1.4, 1.35), CF(0, -0.9, 0.05), cloth, clothHi, M.Fabric)
		r:Box(B, V(2.0, 1.2, 1.2), CF(0, -2.1, 0.1), HC.FogDark, M.Fabric, { Transparency = 0.35 })
		r:Box(B, V(1.5, 1.0, 0.9), CF(0, -3.0, 0.2), HC.Fog, M.Fabric, { Transparency = 0.55 })
		tatter(r, B, -1.6, -0.7, 2.3, 6, cloth, M.Fabric, 2)
		for i = 0, 3 do
			local a = i / 4 * PI * 2 + 0.4
			spike(r, B, V(math.cos(a) * 0.9, -1.4, math.sin(a) * 0.6), V(math.cos(a) * 1.4, -3.4, math.sin(a) * 0.9), 0.7, HC.FogDark, M.Fabric, true, 0.1)
		end
		-- ключицы-кости и рёбра под плащом
		r:Box(B, V(2.0, 0.2, 0.2), CF(0, 1.2, -0.75), C.Bone, M.Plastic)
		for i = 0, 2 do
			r:Box(B, V(1.3 - i * 0.2, 0.12, 0.1), CF(0, 0.75 - i * 0.28, -0.78), C.BoneDark, M.Plastic)
		end
		-- капюшон с черепом: белые глаза (гаснут на 50%) и скрытые красные
		local head = hub(r, "BobHead", B, CF(0, 2.05, 0), { Amp = 0.07, Speed = 1.4 })
		local fz = deepHood(r, head, 1.8, 1.7, cloth, clothHi)
		spike(r, head, V(0, 0.75, 0.4), V(0, 1.6, 1.3), 1.0, cloth, M.Fabric, true, 0.2)
		r:Box(head, V(1.05, 1.1, 0.3), CF(0, -0.12, fz + 0.15), C.Bone, M.Plastic)
		local whiteEyes, redEyes = {}, {}
		for _, s in ipairs(SIDES) do
			r:Box(head, V(0.34, 0.28, 0.06), CF(0.26 * s, 0.02, fz - 0.01), rgb(10, 10, 14), M.Plastic)
			whiteEyes[#whiteEyes + 1] = r:Neon(head, V(0.16, 0.13, 0.06), CF(0.26 * s, 0.01, fz - 0.04), HC.Ghost)
			redEyes[#redEyes + 1] = r:Neon(head, V(0.2, 0.16, 0.06), CF(0.26 * s, 0.01, fz - 0.06), HC.Red)
		end
		r:Box(head, V(0.7, 0.12, 0.06), CF(0, -0.45, fz - 0.01), rgb(10, 10, 14), M.Plastic)
		-- высокий воротник и наплечная накидка
		bevel(r, B, V(2.9, 0.6, 1.8), CF(0, 1.45, 0.1), cloth, clothHi, M.Fabric)
		for _, s in ipairs(SIDES) do
			spike(r, B, V(1.2 * s, 1.6, 0.1), V(1.9 * s, 2.4, 0.4), 0.8, cloth, M.Fabric, true, 0.12)
			spike(r, B, V(1.45 * s, 1.1, 0), V(1.8 * s, 0, 0.1), 0.7, cloth, M.Fabric, true, 0.1)
		end
		-- правая рука с двойной косой (клинки на обоих концах древка)
		local armR = hub(r, "ArmR", B, CF(1.55, 0.95, 0))
		bar(r, armR, V(0, 0, 0), V(0.15, -1.1, -0.45), V2(0.7, 0.7), cloth)
		r:Box(armR, V(0.4, 0.4, 0.4), CF(0.15, -1.25, -0.5), C.Bone, M.Plastic)
		r:Box(armR, V(0.22, 6.4, 0.22), CF(0.15, -1.25, -0.6), HC.Iron, M.Metal)
		for _, e in ipairs({ { 1.95, 1 }, { -4.45, -1 } }) do
			local top, d = V(0.15, e[1], -0.6), e[2]
			local pts = { top, top + V(0, 0.25 * d, -0.9), top + V(0, -0.1 * d, -2.0), top + V(0, -0.75 * d, -2.6) }
			for i = 1, 3 do
				bar(r, armR, pts[i], pts[i + 1], V2(0.1, 0.5 - i * 0.09), HC.IronHi, M.Metal)
			end
			bar(r, armR, pts[2] + V(0, -0.22 * d, 0), pts[3] + V(0, -0.17 * d, 0), V2(0.12, 0.07), HC.Ghost, M.Neon)
		end
		local armL = hub(r, "ArmL", B, CF(-1.55, 0.95, 0))
		bar(r, armL, V(0, 0, 0), V(-0.15, -1.1, -0.45), V2(0.7, 0.7), cloth)
		for k = -1, 1 do
			spike(r, armL, V(-0.15 + k * 0.12, -1.35, -0.5), V(-0.2 + k * 0.18, -2.0, -0.75), 0.14, C.Bone, M.Plastic, true, 0.05)
		end
		-- вращающиеся клочья тумана
		local orb = hub(r, "OrbitFog", B, CF(0, -0.4, 0), { Speed = 0.8 })
		for i = 0, 4 do
			local a = i / 5 * PI * 2
			r:Box(orb, V(1.0, 0.5, 0.5), CF(math.cos(a) * 2.6, math.sin(a * 2) * 0.5, math.sin(a) * 2.6) * ANG(0, -a, rad(20)), HC.Fog, M.Fabric, { Transparency = 0.5 })
		end
		local light = r:Glow(head, HC.Ghost, 10, 1.1)
		r.RedLight = light -- свет головы (разгорается в фазе 50%); nil в Lite
		local e = emitPoint(r, B, CF(0, -3.2, 0.2), V(2.2, 0.5, 2.2))
		emitter(e, HC.Fog, { Smoke = true, Rate = 8, Size = 1.6, SizeEnd = 3.2, LifeMin = 1, LifeMax = 1.8, SpeedMin = 0.3, SpeedMax = 1, Accel = V(0, 0.6, 0), T0 = 0.6 })
		emitter(e, rgb(170, 180, 175), { Name = "FogFX", Smoke = true, Rate = 40, Size = 3, SizeEnd = 7, LifeMin = 1.2, LifeMax = 2.2, SpeedMin = 4, SpeedMax = 8, T0 = 0.55, Off = true })
		-- 50%: красные глаза и ядро, красный дым
		local core = hide(join(redEyes, { r:Box(B, V(0.7, 0.7, 0.2), CF(0, 0.55, -0.82) * ANG(0, 0, rad(45)), HC.Red, M.Neon) }))
		local red = emitter(B, HC.Red, { Rate = 14, Size = 0.45, SpeedMin = 1, SpeedMax = 3, Accel = V(0, 2, 0), Off = true })
		local redSmoke = emitter(e, rgb(150, 30, 30), { Smoke = true, Rate = 6, Size = 1.4, SizeEnd = 2.8, LifeMin = 0.8, LifeMax = 1.4, T0 = 0.6, Off = true })
		r.Phases = {
			{ At = 0.5, Reveal = core, Break = whiteEyes, Emit = { red, redSmoke }, Lights = { { light, 3 } }, Aggro = 1.3 },
		}
		return finishCreature(r, scale, 3.6, 6.0)
	end

	------------------------------------------------------------------------
	-- 12. CURSED MONARCH (босс, Сложная) — тёмный король с тыквой-головой в золотой короне,
	-- королевский плащ, посох-фонарь, огненная аура. 50% — красные глаза, огненные трещины на латах
	------------------------------------------------------------------------
	-- золотая корона (атрибут Crown: при смерти MonarchDeath роняет её)
	local function monarchCrown(r, Hd, cy)
		local parts = {}
		for i = 0, 3 do
			parts[#parts + 1] = r:Box(Hd, V(1.6, 0.32, 0.14), CF(0, cy, 0) * ANG(0, i * PI / 2, 0) * CF(0, 0, -0.75), HC.Gold, M.Metal)
		end
		for i = 0, 7 do
			local a = i / 8 * PI * 2
			local p = V(math.sin(a) * 0.75, cy + 0.1, -math.cos(a) * 0.75)
			add(parts, spike(r, Hd, p, p + V(0, (i % 2 == 0) and 0.8 or 0.5, 0), 0.34, HC.Gold, M.Metal, true, 0.1))
		end
		add(parts, gem(r, Hd, 0.26, CF(0, cy, -0.84), HC.Red))
		return mark(parts, "Crown")
	end

	-- посох-фонарь: древко, золотая клетка, огненный куб
	local function monarchStaff(r, RA)
		r:Box(RA, V(0.26, 6.2, 0.26), CF(0, -0.4, -0.6), rgb(26, 18, 22), M.Metal)
		local topY = 2.7
		r:Box(RA, V(0.9, 0.16, 0.9), CF(0, topY, -0.6), HC.Gold, M.Metal)
		for i = 0, 3 do
			r:Box(RA, V(0.1, 1.1, 0.1), CF(0, topY + 0.6, -0.6) * ANG(0, i * PI / 2 + PI / 4, 0) * CF(0.45, 0, 0), HC.Gold, M.Metal)
		end
		r:Box(RA, V(0.9, 0.16, 0.9), CF(0, topY + 1.2, -0.6), HC.Gold, M.Metal)
		spike(r, RA, V(0, topY + 1.25, -0.6), V(0, topY + 1.9, -0.6), 0.35, HC.Gold, M.Metal)
		r:Neon(RA, V(0.55, 0.55, 0.55), CF(0, topY + 0.6, -0.6) * ANG(0, rad(45), 0), HC.Fire)
		r:Glow(RA, HC.Fire, 8, 1)
	end

	local function CursedMonarch(scale)
		local r = newBiped("CursedMonarch", V(1.5, 1.4, 1.5))
		setup(r, { Style = "Heavy", Gait = { Speed = 0.7, Stride = 0.34, Bob = 0.18, Sway = 0.08, Shake = 0.35, Lean = 2 }, Death = "Implode", Spawn = "Titan", SpawnFX = "MonarchPortal", DeathFX = "MonarchDeath" })
		local T, Hd, RA, LA, RL, LL = r.Torso, r.Head, r.RArm, r.LArm, r.RLeg, r.LLeg
		local armorC, armorHi, armorMid = rgb(30, 22, 34), HC.Gold, rgb(44, 32, 50)
		-- торс: чёрные латы с золотым кантом, бордовый табард
		bevel(r, T, V(2.3, 2.1, 1.25), CF(0, 0.05, 0.05), armorC, armorHi)
		bevel(r, T, V(2.8, 1.1, 1.55), CF(0, 0.6, -0.05), armorMid, armorHi)
		r:Wedge(T, V(2.5, 0.55, 0.5), CF(0, 0.6, -1.0) * ANG(PI, PI, 0), armorC, M.Metal)
		gem(r, T, 0.5, CF(0, 0.6, -0.88), HC.Fire, HC.Gold)
		bevel(r, T, V(1.1, 2.4, 0.15), CF(0, -1.1, -0.66), HC.Burgundy, HC.Gold, M.Fabric)
		tatter(r, T, -2.3, -0.66, 1.1, 3, HC.Burgundy, M.Fabric, 1)
		bevel(r, T, V(2.3, 0.45, 1.5), CF(0, -0.95, 0), armorC, armorHi)
		for _, s in ipairs(SIDES) do
			bevel(r, T, V(0.8, 0.9, 1.2), CF(0.85 * s, -1.4, -0.05) * ANG(0, 0, rad(12 * s)), armorC, armorHi)
		end
		-- королевский плащ с меховым воротником (моторы Cape/Cape2: колыхание по умолчанию Renderer)
		bevel(r, T, V(2.9, 0.5, 1.7), CF(0, 1.05, 0.1), rgb(220, 210, 190), rgb(160, 150, 130), M.Fabric)
		local cape = hub(r, "Cape", T, CF(0, 0.95, 0.8))
		r:Box(cape, V(2.8, 2.6, 0.15), CF(0, -1.3, 0), HC.Burgundy, M.Fabric)
		local cape2 = hub(r, "Cape2", cape, CF(0, -2.6, 0))
		r:Box(cape2, V(2.9, 2.2, 0.15), CF(0, -1.1, 0), HC.Burgundy, M.Fabric)
		r:Box(cape2, V(2.94, 0.16, 0.18), CF(0, -2.1, 0), HC.Gold, M.Metal)
		tatter(r, cape2, -2.2, 0, 2.9, 5, HC.Burgundy, M.Fabric, 4)
		-- тыква-голова (тёмная, выжженная); красные глаза скрыты до 50%
		local ps = 1.2
		local _, eyesP, mouth = pumpkin(r, Hd, CF(0, 0.2, 0), ps, { Color = rgb(150, 66, 20), Dark = rgb(90, 36, 14), Edge = rgb(220, 120, 50) })
		local redEyes = {}
		for i = 1, #eyesP do
			local side = i == 1 and -1 or 1
			redEyes[i] = r:Neon(Hd, V(0.4, 0.34, 0.06) * ps, CF(0.36 * side * ps, 0.2 + 0.18 * ps, -0.84 * ps) * ANG(0, 0, rad(30 * side)), HC.Red)
		end
		monarchCrown(r, Hd, 0.2 + 0.64 * ps + 0.1)
		local headLight = r:Glow(Hd, HC.Fire, 12, 1.4)
		-- наплечники и латные руки
		for _, a in ipairs(arms(r)) do
			local A, s = a[1], a[2]
			pauldron(r, A, s, 1.25, armorC, armorHi, HC.Fire, 2)
			bevel(r, A, V(1.1, 1.0, 1.1), CF(0, 0.1, 0), armorC, armorHi)
			bevel(r, A, V(1.25, 1.0, 1.25), CF(0, -0.75, 0), armorMid, armorHi)
			bevel(r, A, V(1.15, 0.6, 1.15), CF(0, -1.45, -0.05), armorC, armorHi)
		end
		monarchStaff(r, RA)
		for _, Lg in ipairs({ RL, LL }) do
			bevel(r, Lg, V(1.2, 1.0, 1.2), CF(0, 0.45, 0), armorC, armorHi)
			bevel(r, Lg, V(1.2, 0.7, 1.2), CF(0, -0.4, 0), armorMid, armorHi)
			bootA(r, Lg, armorC, armorHi, 1.3)
		end
		-- огненная аура у ног (всегда)
		local feet = emitPoint(r, T, CF(0, -2.7, 0), V(3, 0.4, 3))
		emitter(feet, HC.Fire, { Rate = 14, Size = 0.5, SizeEnd = 0.1, LifeMin = 0.5, LifeMax = 1.0, SpeedMin = 1, SpeedMax = 2.5, Accel = V(0, 4, 0) })
		emitter(feet, rgb(80, 30, 10), { Smoke = true, Rate = 4, Size = 1.2, SizeEnd = 2.4, LifeMin = 0.8, LifeMax = 1.4, Accel = V(0, 1.5, 0), T0 = 0.6 })
		-- 50%: красные глаза вместо оранжевых, огненные трещины, больше огня
		local cracks = hide(join(
			redEyes,
			crack(r, T, { V(-1.05, 1.1, -0.84), V(-0.6, 0.7, -0.84), V(-0.85, 0.2, -0.84) }, 0.09, HC.Fire),
			crack(r, T, { V(1.0, 1.05, -0.84), V(0.55, 0.5, -0.84), V(0.8, 0.05, -0.84) }, 0.09, HC.Fire),
			crack(r, RA, { V(0.3, 0.3, -0.62), V(0, -0.3, -0.64), V(0.25, -0.9, -0.64) }, 0.07, HC.Fire),
			crack(r, LA, { V(-0.3, 0.3, -0.62), V(0, -0.3, -0.64), V(-0.25, -0.9, -0.64) }, 0.07, HC.Fire),
			crack(r, RL, { V(0.3, 0.7, -0.62), V(-0.1, 0.2, -0.62) }, 0.07, HC.Fire),
			crack(r, LL, { V(-0.3, 0.6, -0.62), V(0.15, 0.1, -0.62) }, 0.07, HC.Fire)
		))
		local rage = emitter(feet, HC.Red, { Rate = 22, Size = 0.6, SpeedMin = 2, SpeedMax = 4, Accel = V(0, 5, 0), Off = true })
		local embers = emitter(T, HC.FireSoft, { Rate = 12, Size = 0.25, SpeedMin = 2, SpeedMax = 5, Off = true })
		r.Phases = {
			{ At = 0.5, Reveal = cracks, Break = join(eyesP, mouth), Emit = { rage, embers }, Lights = { { headLight, 3 } }, Aggro = 1.3 },
		}
		return finishBiped(r, scale, { Root = { 4, 0, 0 }, RS = { 18, 0, 8 }, LS = { 6, 0, -10 } }, 7.0)
	end

	EnemyModels.Register("CursedDead", CursedDead)
	EnemyModels.Register("PumpkinRunner", PumpkinRunner)
	EnemyModels.Register("PhantomWarrior", PhantomWarrior)
	EnemyModels.Register("BoneGuard", BoneGuard)
	EnemyModels.Register("LivingScarecrow", LivingScarecrow)
	EnemyModels.Register("StrawMinion", StrawMinion)
	EnemyModels.Register("FogWarlock", FogWarlock)
	EnemyModels.Register("PumpkinBrute", PumpkinBrute)
	EnemyModels.Register("NightReaper", NightReaper)
	EnemyModels.Register("GraveWarden", GraveWarden)
	EnemyModels.Register("FogReaper", FogReaper)
	EnemyModels.Register("CursedMonarch", CursedMonarch)
end
