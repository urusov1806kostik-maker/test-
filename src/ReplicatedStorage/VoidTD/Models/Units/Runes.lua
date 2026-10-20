--!nocheck
-- VOID TD :: Models/Units/Runes
-- 3D-иконки рун (Config.RuneOrder): LanternHeart, CursedThreads, PhantomCrown. Без rig: заякоренные детали
-- Parts.rpart / Parts.rwedge прямо в Model, координаты — от центра иконки (~2.5 студа в высоту).
-- Регистрирует UnitModels.RegisterRune(runeId, builder(m) -> corePart); PrimaryPart = core, pivot в начале
-- координат и Kit.Calm(m, 0.2) ставит UnitModels.BuildRune. Свет — Parts.rlight (не в Lite).

return function(UnitModels, Kit, Parts)
	local V, CF, ANG, rad, PI = Vector3.new, CFrame.new, CFrame.Angles, math.rad, math.pi
	local M, HW, rgb = Parts.M, Parts.HW, Parts.rgb
	local rpart, rwedge, rlight = Parts.rpart, Parts.rwedge, Parts.rlight
	local SIDES = { -1, 1 }

	-- Сердце фонаря: оранжевое сердце за стеклом в золотой клетке-фонаре
	local function LanternHeart(m)
		local gold, orange = HW.Gold, HW.Orange
		-- сердце: ромб и две доли-цилиндра сверху
		local core = rpart(m, V(1.0, 1.0, 0.5), CF(0, -0.15, 0) * ANG(0, 0, rad(45)), orange, M.Neon)
		for _, s in ipairs(SIDES) do
			rpart(m, V(0.5, 0.72, 0.72), CF(0.36 * s, 0.32, 0) * ANG(0, PI / 2, 0), orange, M.Neon, { Shape = Enum.PartType.Cylinder })
		end
		rpart(m, V(1.6, 1.8, 0.8), CF(0, 0.05, 0), rgb(255, 170, 70), M.Glass, { Transparency = 0.6 })
		-- клетка: 4 стойки, крышка и дно, колпак, кольцо для подвеса, клин снизу
		for _, x in ipairs(SIDES) do
			for _, z in ipairs(SIDES) do
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

	-- Проклятые нити: катушка с витками красной нити, свисающая нить и игла насквозь
	local function CursedThreads(m)
		local red, needle = HW.Red, rgb(210, 214, 226)
		for _, y in ipairs({ -0.75, 0.75 }) do -- щёчки катушки (восьмигранные) с золотым ободом
			for k = 0, 3 do
				rpart(m, V(1.6, 0.22, 0.66), CF(0, y, 0) * ANG(0, k * PI / 4, 0), HW.BurgDark, M.Wood)
			end
			rpart(m, V(1.7, 0.08, 0.3), CF(0, y + (y > 0 and 0.12 or -0.12), 0), HW.Gold, M.Metal)
		end
		rpart(m, V(0.5, 1.4, 0.5), CF(), HW.Wood, M.Wood)
		local core
		for k = 0, 4 do -- витки нити, повёрнутые друг относительно друга
			local layer = rpart(m, V(1.12, 0.22, 1.12), CF(0, -0.48 + k * 0.24, 0) * ANG(0, k * 0.3, 0), red, M.Neon)
			core = core or layer
		end
		rpart(m, V(0.05, 1.0, 0.05), CF(0.58, -0.9, -0.3) * ANG(0, 0, rad(10)), red, M.Neon)
		rpart(m, V(0.05, 0.6, 0.05), CF(0.45, -1.5, -0.3) * ANG(0, 0, rad(-25)), red, M.Neon)
		local tilt = CF(0.2, 0.25, -0.1) * ANG(rad(10), 0, rad(-35))
		rpart(m, V(0.09, 2.6, 0.09), tilt, needle, M.Metal)
		rpart(m, V(0.16, 0.26, 0.05), tilt * CF(0, 1.2, 0), needle, M.Metal) -- ушко
		rlight(core, red, 8)
		return core
	end

	-- Призрачная корона: восьмигранное прозрачное кольцо с зубцами, неоновый обод и камни
	local function PhantomCrown(m)
		local ghost, edge = HW.Ghost, rgb(200, 235, 255)
		local R = 0.9
		local w = 2 * R * math.tan(rad(22.5)) * 1.1
		for k = 0, 7 do
			local a = k * PI / 4
			local face = CF(math.sin(a) * R, 0, -math.cos(a) * R) * ANG(0, -a, 0)
			rpart(m, V(w, 0.5, 0.16), CF(0, -0.4, 0) * face, ghost, M.Glass, { Transparency = 0.3 })
			rpart(m, V(w, 0.08, 0.18), CF(0, -0.68, 0) * face, edge, M.Neon)
			-- зубец из двух клиньев: высокие и низкие чередуются
			local hh = k % 2 == 0 and 1.2 or 0.8
			local F = CF(0, -0.15 + hh / 2, 0) * face * ANG(0, PI / 2, 0)
			rwedge(m, V(0.12, hh, w / 2), F * CF(0, 0, -w / 4), ghost, M.Glass, { Transparency = 0.25 })
			rwedge(m, V(0.12, hh, w / 2), F * CF(0, 0, w / 4) * ANG(0, PI, 0), ghost, M.Glass, { Transparency = 0.25 })
		end
		local core = rpart(m, V(0.36, 0.36, 0.14), CF(0, -0.4, -R - 0.1) * ANG(0, 0, rad(45)), edge, M.Neon)
		for _, s in ipairs(SIDES) do
			rpart(m, V(0.24, 0.24, 0.14), CF(R * 0.71 * s, -0.4, -R * 0.71 - 0.08) * ANG(0, rad(-45 * s), rad(45)), ghost, M.Neon)
		end
		rpart(m, V(1.2, 0.6, 1.2), CF(0, 0.15, 0), ghost, M.Neon, { Transparency = 0.75 }) -- внутреннее свечение
		rlight(core, ghost, 9)
		return core
	end

	UnitModels.RegisterRune("LanternHeart", LanternHeart)
	UnitModels.RegisterRune("CursedThreads", CursedThreads)
	UnitModels.RegisterRune("PhantomCrown", PhantomCrown)
end
