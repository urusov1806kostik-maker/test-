--!nocheck
-- VOID TD :: Config.Settings
-- Общие настройки матча, экономики и профиля.

return {
	Settings = {
		-- матч
		StartMoney = 800,              -- деньги в начале матча (× Money сложности)
		CoreMaxHP = 100,               -- здоровье ядра (в матче берётся из сложности)
		MaxWave = 30,                  -- волн на карте Void (если у карты нет своего MaxWave)
		Intermission = 15,             -- секунд между волнами (кнопка Start Wave пропускает)
		GroupDelay = 2,                -- пауза между группами внутри волны
		ResetDelay = 15,               -- через сколько секунд после победы/поражения матч перезапускается

		-- награды деньгами
		WaveRewardBase = 200,          -- награда за волну = Base + PerWave * номер
		WaveRewardPerWave = 60,
		KillRewardScalePerWave = 0.08, -- +8% к награде за убийство за каждую волну

		-- HP врагов: множитель = 1 + L*(w-1) + Q*(w-1)^2
		EnemyHPScaleLinear = 0.08,
		EnemyHPScaleQuad = 0.004,
		EnemyHealthMult = 1.0,         -- общий множитель HP врагов: 0.8 — легче, 1.3 — сложнее

		-- юниты на карте
		SellRefund = 0.6,              -- возврат при продаже (60% от потраченного)
		MaxUnitsPerPlayer = 15,
		PlacementSpacing = 3.2,        -- минимальное расстояние между юнитами
		PathClearance = 1.0,           -- отступ юнита от края дороги
		EquipSlots = 6,

		-- кристаллы и профиль
		SummonCost1 = 50,              -- не используется: цены берутся из Config.Cases
		SummonCost10 = 450,
		StartGems = 1500,
		WaveGemsBase = 10,             -- кристаллы за волну = Base + PerWave * номер (× Gems сложности)
		WaveGemsPerWave = 2,
		VictoryGems = 1000,
		StarterUnits = { "VoidSoldier", "ShadowArcher", "LostMage" },
		DailyGems = 150,               -- бесплатные кристаллы в магазине раз в 20 часов
		DailyCooldown = 20 * 3600,

		-- бой
		BossSlowResist = 0.5,          -- боссы получают только 50% силы замедления
		FreezeImmunity = 3,            -- после остановки времени враг 3 с не может быть остановлен снова

		-- в Studio эти юниты выдаются в инвентарь для проверки (в опубликованной игре — нет)
		StudioGrantUnits = { "CursedClockmaker" },

		-- союзники (призывы Кукловода, Иллюзиониста и руны «Проклятые нити»)
		AllySpeed = 6,                 -- скорость союзников по дороге (идут от базы к порталу)
		AllyStartBack = 4,             -- появляются на этом расстоянии от базы

		-- сервис
		ShopTestMode = true,           -- в Studio покупка с ProductId = 0 выдаёт кристаллы бесплатно (для теста)
		DataStoreName = "VoidTD_Data_v1",
		SyncRate = 0.1,                -- как часто сервер рассылает позиции врагов
	},
}
