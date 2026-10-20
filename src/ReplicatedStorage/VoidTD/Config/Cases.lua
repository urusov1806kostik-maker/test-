--!nocheck
-- VOID TD :: Config.Cases
-- Кейсы (Summon). Rates — шансы редкостей в процентах (сумма = 100), юнит внутри редкости — равновероятно.
-- Rewards — полный список наград с шансами (одна награда за открытие). Результат считается на сервере.
-- Поля: Name, Color, Description, Cost1, Cost10?, Rates?, Units, Currency? (= "Gems"), Single?, Rewards?, Enabled?

return {
	-- порядок в меню кейсов и в лобби. Blood Moon убран из лобби и меню кейсов,
	-- его юниты остаются у игроков и в игре.
	CaseOrder = { "VoidCase", "ShatteredReality" },

	Cases = {
		VoidCase = {
			Name = "VOID CASE", Color = Color3.fromRGB(170, 80, 255),
			Description = "Оригинальные воины Пустоты.",
			Cost1 = 50, Cost10 = 450,
			Rates = { Common = 72, Rare = 21, Epic = 5.5, Legendary = 1.3, Mythic = 0.2 },
			Units = {
				"VoidSoldier", "ShadowArcher", "LostMage", "VoidKnight", "DarkGunner", "AbyssReaper",
				"CorruptedSamurai", "EclipseGuardian", "FallenAngel", "VoidEmperor", "AbyssOverlord",
			},
		},

		ShatteredReality = {
			Name = "SHATTERED REALITY", Color = Color3.fromRGB(120, 40, 210),
			Description = "Расколотая реальность. Шанс SECRET: 0.1%",
			Cost1 = 80, Cost10 = 720,
			Rates = { Common = 70, Rare = 21, Epic = 6.4, Legendary = 2, Mythic = 0.5, Secret = 0.1 },
			Units = { "RiftScout", "CrystalHunter", "VoidPuppeteer", "Starbreaker", "RiftMonarch", "RealityDestroyer" },
		},

		-- HALLOWEEN CASE: только на Хэллоуин-острове, за Halloween Coins, одна награда за открытие
		Halloween = {
			Name = "HALLOWEEN CASE", Color = Color3.fromRGB(255, 130, 30),
			Description = "Проклятый сундук. 11 хэллоуинских юнитов, Проклятый часовщик и 3 руны.",
			Currency = "HalloweenCoins",
			Cost1 = 500,
			Single = true,
			Rewards = {
				{ Unit = "LanternKing", Rate = 0.1 },
				{ Unit = "CursedClockmaker", Rate = 0.2 },
				{ Unit = "HalloweenPuppeteer", Rate = 2 },
				{ Unit = "HeadlessExecutioner", Rate = 2 },
				{ Unit = "PlagueDoctor", Rate = 5 },
				{ Unit = "PhantomKnight", Rate = 5 },
				{ Unit = "DarkIllusionist", Rate = 5 },
				{ Unit = "CursedSheriff", Rate = 10 },
				{ Unit = "MidnightBellringer", Rate = 10 },
				{ Unit = "Gravedigger", Rate = 14 },
				{ Unit = "CursedScarecrow", Rate = 14 },
				{ Unit = "NightWatchman", Rate = 24.7 },
				{ Rune = "LanternHeart", Rate = 2.5 },
				{ Rune = "CursedThreads", Rate = 3 },
				{ Rune = "PhantomCrown", Rate = 2.5 },
			},
			-- список для показа (от редких к частым); должен совпадать с юнитами в Rewards
			Units = {
				"LanternKing", "CursedClockmaker", "HalloweenPuppeteer", "HeadlessExecutioner", "PlagueDoctor",
				"PhantomKnight", "DarkIllusionist", "CursedSheriff", "MidnightBellringer", "Gravedigger",
				"CursedScarecrow", "NightWatchman",
			},
		},

		-- Blood Moon: кейс отключён и убран из лобби (юниты остаются в инвентаре)
		BloodMoon = {
			Name = "BLOOD MOON", Color = Color3.fromRGB(210, 30, 50),
			Enabled = false,
			Description = "Кровавая луна. Шанс SECRET: 0.1%",
			Cost1 = 100, Cost10 = 900,
			Rates = { Common = 70, Rare = 21, Epic = 6.4, Legendary = 2, Mythic = 0.5, Secret = 0.1 },
			Units = { "BloodAcolyte", "CrimsonGunslinger", "MoonWitch", "BloodfangWarlord", "LunarSeraph", "CrimsonEclipse" },
		},
	},
}
