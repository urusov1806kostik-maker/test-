--!nocheck
-- VOID TD :: Config
-- Все цифры баланса собраны здесь. Меняй смело — остальной код читает только эту таблицу.

local Config = {}

Config.GameName = "VOID TD"

------------------------------------------------------------------------
-- ОБЩИЕ НАСТРОЙКИ
------------------------------------------------------------------------
Config.Settings = {
	StartMoney = 800,             -- деньги в начале матча
	CoreMaxHP = 100,              -- здоровье ядра
	MaxWave = 30,
	Intermission = 15,            -- секунд между волнами (кнопка Start Wave пропускает)
	GroupDelay = 2,               -- пауза между группами внутри волны
	WaveRewardBase = 200,         -- награда за волну = Base + PerWave * номер
	WaveRewardPerWave = 60,
	KillRewardScalePerWave = 0.08,-- +8% к награде за убийство за каждую волну
	EnemyHPScaleLinear = 0.08,    -- множитель HP = 1 + L*(w-1) + Q*(w-1)^2
	EnemyHPScaleQuad = 0.004,
	EnemyHealthMult = 1.0,        -- общий множитель HP врагов (сложность): 0.8 — легче, 1.3 — сложнее
	SellRefund = 0.6,             -- возврат при продаже (60% от потраченного)
	MaxUnitsPerPlayer = 15,
	PlacementSpacing = 3.2,       -- минимальное расстояние между юнитами
	PathClearance = 1.0,          -- отступ юнита от края дороги
	ResetDelay = 15,              -- через сколько секунд после победы/поражения матч перезапускается
	EquipSlots = 6,
	SummonCost1 = 50,
	SummonCost10 = 450,
	StartGems = 1500,
	WaveGemsBase = 10,
	WaveGemsPerWave = 2,
	VictoryGems = 1000,
	BossSlowResist = 0.5,         -- боссы получают только 50% силы замедления
	StarterUnits = { "VoidSoldier", "ShadowArcher", "LostMage" },
	DailyGems = 150,              -- бесплатные кристаллы в магазине раз в 20 часов
	DailyCooldown = 20 * 3600,
	FreezeImmunity = 3,           -- после остановки времени враг 3 с не может быть остановлен снова
	-- В Studio эти юниты выдаются в инвентарь для проверки (в опубликованной игре — нет)
	StudioGrantUnits = { "CursedClockmaker" },
	-- союзники (призывы Кукловода, Иллюзиониста и руны «Проклятые нити»)
	AllySpeed = 6,                -- скорость союзников по дороге (идут от базы к порталу)
	AllyStartBack = 4,            -- появляются на этом расстоянии от базы
	ShopTestMode = true,          -- в Studio покупка с ProductId = 0 выдаёт кристаллы бесплатно (для теста)
	DataStoreName = "VoidTD_Data_v1",
	SyncRate = 0.1,               -- как часто сервер рассылает позиции врагов
}

------------------------------------------------------------------------
-- РЕДКОСТИ
------------------------------------------------------------------------
Config.RarityOrder = { "Common", "Rare", "Epic", "Legendary", "Mythic", "Secret" }

Config.Rarities = {
	-- Rate — шанс выпадения в Summon (в процентах, сумма = 100)
	Common    = { Order = 1, Color = Color3.fromRGB(165, 165, 175), Rate = 72,  PlacementLimit = 6 },
	Rare      = { Order = 2, Color = Color3.fromRGB(60, 140, 255),  Rate = 21,  PlacementLimit = 5 },
	Epic      = { Order = 3, Color = Color3.fromRGB(170, 80, 255),  Rate = 5.5, PlacementLimit = 4 },
	Legendary = { Order = 4, Color = Color3.fromRGB(255, 195, 50),  Rate = 1.3, PlacementLimit = 3 },
	Mythic    = { Order = 5, Color = Color3.fromRGB(235, 40, 130),  Rate = 0.2, PlacementLimit = 2 },
	-- Secret есть только в новых кейсах (шанс задаётся в Config.Cases)
	Secret    = { Order = 6, Color = Color3.fromRGB(255, 25, 45),   Rate = 0,   PlacementLimit = 1 },
}

------------------------------------------------------------------------
-- КЕЙСЫ (Summon). Rates — шансы редкостей в процентах, сумма = 100.
------------------------------------------------------------------------
-- Blood Moon убран из лобби и меню кейсов. Его юниты остаются у игроков и в игре.
Config.CaseOrder = { "VoidCase", "ShatteredReality" }

Config.Cases = {
	VoidCase = {
		Name = "VOID CASE", Color = Color3.fromRGB(170, 80, 255),
		Description = "Оригинальные воины Пустоты.",
		Cost1 = 50, Cost10 = 450,
		Rates = { Common = 72, Rare = 21, Epic = 5.5, Legendary = 1.3, Mythic = 0.2 },
		Units = { "VoidSoldier", "ShadowArcher", "LostMage", "VoidKnight", "DarkGunner", "AbyssReaper",
			"CorruptedSamurai", "EclipseGuardian", "FallenAngel", "VoidEmperor", "AbyssOverlord" },
	},
	ShatteredReality = {
		Name = "SHATTERED REALITY", Color = Color3.fromRGB(120, 40, 210),
		Description = "Расколотая реальность. Шанс SECRET: 0.1%",
		Cost1 = 80, Cost10 = 720,
		Rates = { Common = 70, Rare = 21, Epic = 6.4, Legendary = 2, Mythic = 0.5, Secret = 0.1 },
		Units = { "RiftScout", "CrystalHunter", "VoidPuppeteer", "Starbreaker", "RiftMonarch", "RealityDestroyer" },
	},
	-- HALLOWEEN CASE: только на Хэллоуин-острове, за Halloween Coins, одна награда за открытие.
	-- Rewards — полный список наград с шансами в процентах (сумма = 100). Результат считается на сервере.
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
		Units = { "LanternKing", "CursedClockmaker", "HalloweenPuppeteer", "HeadlessExecutioner", "PlagueDoctor", "PhantomKnight",
			"DarkIllusionist", "CursedSheriff", "MidnightBellringer", "Gravedigger", "CursedScarecrow", "NightWatchman" },
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
}

------------------------------------------------------------------------
-- МАГАЗИН КРИСТАЛЛОВ
-- ProductId — Developer Product из Creator Hub (Monetization → Developer Products).
-- Пока ProductId = 0 и включён ShopTestMode, в Studio покупка бесплатная (для проверки).
------------------------------------------------------------------------
Config.Shop = {
	{ Key = "Gems100",  Gems = 100,  Robux = 25,  ProductId = 0, Title = "Горсть кристаллов" },
	{ Key = "Gems550",  Gems = 550,  Robux = 99,  ProductId = 0, Title = "Мешок кристаллов", Bonus = "+10%" },
	{ Key = "Gems1200", Gems = 1200, Robux = 199, ProductId = 0, Title = "Сундук кристаллов", Bonus = "+20%" },
	{ Key = "Gems2600", Gems = 2600, Robux = 399, ProductId = 0, Title = "Груда кристаллов", Bonus = "+30%" },
	{ Key = "Gems7000", Gems = 7000, Robux = 999, ProductId = 0, Title = "Сокровищница Пустоты", Bonus = "+40%" },
}

------------------------------------------------------------------------
-- ЗВУКИ. Custom — свой звук "rbxassetid://ID" (файлы для загрузки лежат в assets/sounds).
-- Пока Custom пустой, играет встроенный звук Roblox с обработкой (Pitch).
------------------------------------------------------------------------
Config.Sounds = {
	Slash      = { Custom = "", Id = "rbxasset://sounds/swordslash.wav",           Volume = 0.35, Pitch = 1.1 },
	HeavyHit   = { Custom = "", Id = "rbxasset://sounds/swordslash.wav",           Volume = 0.5,  Pitch = 0.65 },
	Shoot      = { Custom = "", Id = "rbxasset://sounds/swordlunge.wav",           Volume = 0.2,  Pitch = 1.6 },
	Laser      = { Custom = "", Id = "rbxasset://sounds/swordlunge.wav",           Volume = 0.45, Pitch = 0.7 },
	Magic      = { Custom = "", Id = "rbxasset://sounds/electronicpingshort.wav",  Volume = 0.3,  Pitch = 0.8 },
	Explosion  = { Custom = "", Id = "rbxasset://sounds/swordlunge.wav",           Volume = 0.6,  Pitch = 0.45 },
	Place      = { Custom = "", Id = "rbxasset://sounds/unsheath.wav",             Volume = 0.5,  Pitch = 1 },
	Upgrade    = { Custom = "", Id = "rbxasset://sounds/electronicpingshort.wav",  Volume = 0.45, Pitch = 1.3 },
	Sell       = { Custom = "", Id = "rbxasset://sounds/electronicpingshort.wav",  Volume = 0.4,  Pitch = 0.6 },
	Click      = { Custom = "", Id = "rbxasset://sounds/electronicpingshort.wav",  Volume = 0.2,  Pitch = 1.8 },
	WaveStart  = { Custom = "", Id = "rbxasset://sounds/electronicpingshort.wav",  Volume = 0.4,  Pitch = 1 },
	Boss       = { Custom = "", Id = "rbxasset://sounds/swordlunge.wav",           Volume = 0.8,  Pitch = 0.3 },
	CoreHit    = { Custom = "", Id = "rbxasset://sounds/swordslash.wav",           Volume = 0.5,  Pitch = 0.4 },
	Victory    = { Custom = "", Id = "rbxasset://sounds/electronicpingshort.wav",  Volume = 0.6,  Pitch = 1.2 },
	Defeat     = { Custom = "", Id = "rbxasset://sounds/electronicpingshort.wav",  Volume = 0.6,  Pitch = 0.45 },
	CaseShake  = { Custom = "", Id = "rbxasset://sounds/unsheath.wav",             Volume = 0.4,  Pitch = 0.7 },
	CaseOpen   = { Custom = "", Id = "rbxasset://sounds/swordlunge.wav",           Volume = 0.7,  Pitch = 0.5 },
	Reveal     = { Custom = "", Id = "rbxasset://sounds/electronicpingshort.wav",  Volume = 0.35, Pitch = 1 },
	Secret     = { Custom = "", Id = "rbxasset://sounds/swordlunge.wav",           Volume = 0.9,  Pitch = 0.25 },
	Purchase   = { Custom = "", Id = "rbxasset://sounds/electronicpingshort.wav",  Volume = 0.5,  Pitch = 1.5 },
	Portal     = { Custom = "", Id = "rbxasset://sounds/swordlunge.wav",           Volume = 0.5,  Pitch = 0.35 },
	EnemyDeath = { Custom = "", Id = "rbxasset://sounds/swordlunge.wav",           Volume = 0.15, Pitch = 2.2 },
}

Config.TargetModes = { "First", "Last", "Strongest", "Weakest", "Closest" }

------------------------------------------------------------------------
-- СЛОЖНОСТЬ (выбирается в портале PLAY в лобби)
-- HP / Speed — множители врагов, Money — множитель денег, Gems — множитель гемов.
------------------------------------------------------------------------
Config.DifficultyOrder = { "Easy", "Medium", "Hard", "Hardcore" }

Config.Difficulties = {
	Easy = {
		Name = "ЛЁГКАЯ", Color = Color3.fromRGB(90, 220, 120),
		HP = 0.55, Speed = 0.9, Money = 1.3, Gems = 0.6, CoreHP = 150, Intermission = 18,
		Description = "Для новичков. Враги слабее, денег больше.",
	},
	Medium = {
		Name = "СРЕДНЯЯ", Color = Color3.fromRGB(255, 205, 70),
		HP = 1.0, Speed = 1.0, Money = 1.0, Gems = 1.0, CoreHP = 100, Intermission = 15,
		Description = "Стандартный баланс.",
	},
	Hard = {
		Name = "СЛОЖНАЯ", Color = Color3.fromRGB(255, 90, 80),
		HP = 1.2, Speed = 1.05, Money = 1.0, Gems = 1.6, CoreHP = 100, Intermission = 12,
		Description = "Враги крепче и быстрее. Награда x1.6.",
	},
	Hardcore = {
		Name = "ХАРДКОР", Color = Color3.fromRGB(200, 40, 255),
		HP = 1.4, Speed = 1.1, Money = 1.0, Gems = 2.5, CoreHP = 50, Intermission = 10,
		Description = "Только для лучших. Слабое ядро, быстрые враги. Награда x2.5.",
	},
}

------------------------------------------------------------------------
-- ЛОББИ: остров рядом с картой. Встань в круг, чтобы открыть меню.
------------------------------------------------------------------------
Config.Lobby = {
	Center = Vector3.new(0, 60, 440),
	Radius = 95,
	Spawn = Vector3.new(0, 60, 510),
	Zones = {
		Play  = { Offset = Vector3.new(0, 0, -62), Radius = 9, Title = "ИГРАТЬ", Color = Color3.fromRGB(180, 80, 255) },
		Units = { Offset = Vector3.new(64, 0, 8),  Radius = 8, Title = "ЮНИТЫ",  Color = Color3.fromRGB(80, 170, 255) },
		-- кейсы: Case = ключ из Config.Cases
		Case_VoidCase         = { Offset = Vector3.new(-58, 0, -22), Radius = 7, Title = "VOID CASE",         Color = Color3.fromRGB(170, 80, 255), Case = "VoidCase" },
		Case_ShatteredReality = { Offset = Vector3.new(-70, 0, 6),   Radius = 7, Title = "SHATTERED REALITY", Color = Color3.fromRGB(130, 50, 230), Case = "ShatteredReality" },
		-- огромный портал на Хэллоуин-остров
		HalloweenPortal = { Offset = Vector3.new(-56, 0, 40), Radius = 8, Title = "HALLOWEEN EVENT", Color = Color3.fromRGB(255, 130, 30), Teleport = "Halloween" },
	},
}
Config.BattleSpawn = Vector3.new(10, 60, 10)

------------------------------------------------------------------------
-- HALLOWEEN EVENT
------------------------------------------------------------------------
-- Тег события (не редкость): рамка карточки остаётся цветом основной редкости
Config.Events = {
	Halloween = { Tag = "🎃 HALLOWEEN", Color = Color3.fromRGB(255, 135, 35), Glow = Color3.fromRGB(255, 170, 60) },
}

-- Хэллоуин-остров: кейс, вход в бой на 4 квадратах, доска наград, превью юнитов, бестиарий
Config.HalloweenIsland = {
	Center = Vector3.new(560, 60, 460),
	Radius = 100,
	Spawn = Vector3.new(560, 60, 530),
	Zones = {
		Case_Halloween = { Offset = Vector3.new(-50, 0, -20), Radius = 8, Title = "HALLOWEEN CASE", Color = Color3.fromRGB(255, 130, 30), Case = "Halloween" },
		Units          = { Offset = Vector3.new(60, 0, 20),   Radius = 7, Title = "ЮНИТЫ",          Color = Color3.fromRGB(255, 170, 60) },
		Bestiary       = { Offset = Vector3.new(60, 0, -22),  Radius = 7, Title = "БЕСТИАРИЙ",      Color = Color3.fromRGB(170, 60, 255), Bestiary = true },
		HalloweenUnits = { Offset = Vector3.new(-62, 0, 26),  Radius = 7, Title = "HALLOWEEN ЮНИТЫ", Color = Color3.fromRGB(255, 120, 40), EventUnits = "Halloween" },
		ReturnPortal   = { Offset = Vector3.new(34, 0, 60),   Radius = 7, Title = "В ЛОББИ",        Color = Color3.fromRGB(170, 80, 255), Teleport = "Lobby" },
	},
	-- 4 светящихся квадрата входа в Хэллоуин-матч (центр — Offset, Pad — сторона квадрата)
	Queue = {
		Offset = Vector3.new(0, 0, -46),
		Pads = { Vector3.new(-9, 0, -4.5), Vector3.new(9, 0, -4.5), Vector3.new(-9, 0, 4.5), Vector3.new(9, 0, 4.5) },
		Pad = 7,
		MaxPlayers = 4,
		Countdown = 15,       -- секунд до телепорта (хост может нажать СТАРТ — останется 3 с)
		StartNow = 3,
	},
}

Config.Halloween = {
	Difficulties = { "Easy", "Medium", "Hard" },
	-- Halloween Coins каждому участнику за победу (за поражение — ничего)
	Coins = { Easy = 100, Medium = 150, Hard = 250 },
	Bosses = { Easy = "GraveWarden", Medium = "FogReaper", Hard = "CursedMonarch" },
	MaxWave = 20,
}

-- HALLOWEEN-руны: своя редкость HALLOWEEN, 1 руна на юнита, без улучшений, работают только надетыми
Config.RuneRarity = { Name = "HALLOWEEN", Color = Color3.fromRGB(255, 130, 30) }
Config.RuneOrder = { "LanternHeart", "CursedThreads", "PhantomCrown" }
Config.Runes = {
	LanternHeart = {
		Name = "Сердце фонаря", Color = Color3.fromRGB(255, 140, 40),
		Description = "Каждая 3-я обычная атака вызывает огненный взрыв: 20% урона юнита, радиус 4, до 4 дополнительных врагов.",
		EveryNth = 3, Mult = 0.2, Radius = 4, MaxTargets = 4,
	},
	CursedThreads = {
		Name = "Проклятые нити", Color = Color3.fromRGB(220, 30, 50),
		Description = "Каждая 5-я обычная атака замедляет до 3 врагов на 25% на 2 с (боссов — на 12.5%). Каждые 60 с призывает проклятых людей.",
		EveryNth = 5, Slow = 0.25, SlowTime = 2, MaxTargets = 3,
		Summon = {
			Interval = 60, Max = 3,
			Levels = {
				{ Ally = "CursedPerson", Count = 1, HP = 300 },
				{ Ally = "ShadowSoldier", Count = 1, HP = 650 },
				{ Ally = "CursedGuard", Count = 2, HP = 900 },
				{ Ally = "CrimsonWarrior", Count = 2, HP = 1400 },
				{ Ally = "CursedKnight", Count = 3, HP = 1900 },
			},
		},
	},
	PhantomCrown = {
		Name = "Призрачная корона", Color = Color3.fromRGB(110, 190, 255),
		Description = "Каждая обычная атака с шансом 30% повторяется через 0.3 с призрачной копией юнита со 100% урона.",
		Chance = 0.3, Delay = 0.3, Mult = 1,
	},
}

Config.AllyOrder = {
	"ShadowDouble", "CardSoldier", "MirrorKnight", "PhantomMage", "RoyalIllusion",
	"WoodenDoll", "PorcelainDoll", "ArmoredDoll", "CursedPuppetKnight", "RoyalMarionette", "GoldenMarionette",
	"CursedPerson", "ShadowSoldier", "CursedGuard", "CrimsonWarrior", "CursedKnight",
}
-- Союзники: идут по дороге от базы навстречу врагам. HP = запас урона:
-- при столкновении враг теряет min(HP союзника, HP врага), союзник — столько же.
Config.Allies = {
	-- Иллюзионист
	ShadowDouble   = { Name = "Теневой двойник",        Family = "Illusion", Tier = 1 },
	CardSoldier    = { Name = "Карточный солдат",       Family = "Illusion", Tier = 2 },
	MirrorKnight   = { Name = "Зеркальный рыцарь",      Family = "Illusion", Tier = 3 },
	PhantomMage    = { Name = "Фантомный маг",          Family = "Illusion", Tier = 4 },
	RoyalIllusion  = { Name = "Королевская иллюзия",    Family = "Illusion", Tier = 5 },
	-- Кукловод
	WoodenDoll     = { Name = "Деревянная кукла",       Family = "Puppet", Tier = 1 },
	PorcelainDoll  = { Name = "Фарфоровая кукла",       Family = "Puppet", Tier = 2 },
	ArmoredDoll    = { Name = "Бронированная кукла",    Family = "Puppet", Tier = 3 },
	CursedPuppetKnight = { Name = "Проклятый рыцарь",   Family = "Puppet", Tier = 4 },
	RoyalMarionette = { Name = "Королевская марионетка", Family = "Puppet", Tier = 5 },
	GoldenMarionette = { Name = "Золотая марионетка",   Family = "Puppet", Tier = 6 },
	-- руна «Проклятые нити»
	CursedPerson   = { Name = "Проклятый человек",      Family = "Cursed", Tier = 1 },
	ShadowSoldier  = { Name = "Теневой солдат",         Family = "Cursed", Tier = 2 },
	CursedGuard    = { Name = "Проклятый страж",        Family = "Cursed", Tier = 3 },
	CrimsonWarrior = { Name = "Багровый воин",          Family = "Cursed", Tier = 4 },
	CursedKnight   = { Name = "Проклятый рыцарь",       Family = "Cursed", Tier = 5 },
}

------------------------------------------------------------------------
-- ЮНИТЫ
-- Levels[i].Cost: для i = 1 — цена установки, дальше — цена улучшения до уровня i.
-- AttackType: Melee | Projectile | Laser | AOE | MultiHit (ImpactKind — какой эффект рисовать для AOE)
-- Abyss Overlord дополнительно использует BlackHole (Damage Over Time + Slow).
------------------------------------------------------------------------
Config.UnitOrder = {
	"VoidSoldier", "ShadowArcher", "LostMage",
	"VoidKnight", "DarkGunner",
	"AbyssReaper", "CorruptedSamurai",
	"EclipseGuardian", "FallenAngel",
	"VoidEmperor", "AbyssOverlord",
	-- Shattered Reality Case
	"RiftScout", "CrystalHunter", "VoidPuppeteer", "Starbreaker", "RiftMonarch", "RealityDestroyer",
	-- Blood Moon Case
	"BloodAcolyte", "CrimsonGunslinger", "MoonWitch", "BloodfangWarlord", "LunarSeraph", "CrimsonEclipse",
	-- Halloween Case
	"NightWatchman", "Gravedigger", "CursedScarecrow", "CursedSheriff", "MidnightBellringer",
	"PlagueDoctor", "PhantomKnight", "DarkIllusionist", "HalloweenPuppeteer", "HeadlessExecutioner",
	"LanternKing", "CursedClockmaker",
}

Config.Units = {
	VoidSoldier = {
		Name = "Void Soldier", Rarity = "Common", AttackType = "Melee",
		Description = "Обычный солдат Пустоты. Удары мечом по одной цели.",
		Anim = "Slash", HitDelay = 0.22, Scale = 1.0, DefaultTarget = "First",
		Levels = {
			{ Damage = 11, Range = 12,  Cooldown = 1.00, Cost = 150 },
			{ Damage = 16, Range = 12,  Cooldown = 0.95, Cost = 120 },
			{ Damage = 23, Range = 13, Cooldown = 0.90, Cost = 220 },
			{ Damage = 33, Range = 13, Cooldown = 0.85, Cost = 380 },
			{ Damage = 48, Range = 14, Cooldown = 0.75, Cost = 600 },
		},
	},
	ShadowArcher = {
		Name = "Shadow Archer", Rarity = "Common", AttackType = "Projectile",
		Description = "Тёмный лучник. Дальние выстрелы по одной цели.",
		Anim = "Bow", HitDelay = 0.25, ProjectileSpeed = 95, Projectile = "Arrow", Scale = 1.0, DefaultTarget = "First",
		Levels = {
			{ Damage = 16, Range = 20, Cooldown = 1.40, Cost = 250 },
			{ Damage = 23, Range = 22, Cooldown = 1.35, Cost = 200 },
			{ Damage = 33, Range = 24, Cooldown = 1.30, Cost = 350 },
			{ Damage = 47, Range = 26, Cooldown = 1.20, Cost = 550 },
			{ Damage = 68, Range = 28, Cooldown = 1.05, Cost = 850 },
		},
	},
	LostMage = {
		Name = "Lost Mage", Rarity = "Common", AttackType = "Projectile",
		Description = "Начинающий маг Пустоты. Магические снаряды.",
		Anim = "Cast", HitDelay = 0.3, ProjectileSpeed = 55, Projectile = "Orb", Scale = 1.0, DefaultTarget = "First",
		Levels = {
			{ Damage = 22, Range = 13, Cooldown = 1.40, Cost = 300 },
			{ Damage = 32, Range = 14, Cooldown = 1.35, Cost = 240 },
			{ Damage = 48, Range = 15, Cooldown = 1.25, Cost = 400 },
			{ Damage = 69, Range = 16, Cooldown = 1.15, Cost = 650 },
			{ Damage = 100, Range = 17, Cooldown = 1.00, Cost = 1000 },
		},
	},
	VoidKnight = {
		Name = "Void Knight", Rarity = "Rare", AttackType = "Melee",
		Description = "Бронированный рыцарь. Сильные удары по одной цели.",
		Anim = "HeavySlash", HitDelay = 0.3, Scale = 1.1, DefaultTarget = "First",
		Levels = {
			{ Damage = 58,  Range = 13, Cooldown = 1.50, Cost = 600 },
			{ Damage = 84,  Range = 13, Cooldown = 1.45, Cost = 450 },
			{ Damage = 125,  Range = 14, Cooldown = 1.40, Cost = 750 },
			{ Damage = 180, Range = 14, Cooldown = 1.30, Cost = 1200 },
			{ Damage = 275, Range = 15, Cooldown = 1.20, Cost = 1800 },
		},
	},
	DarkGunner = {
		Name = "Dark Gunner", Rarity = "Rare", AttackType = "Projectile",
		Description = "Стрелок Пустоты. Очень быстрые энергетические выстрелы.",
		Anim = "Gun", HitDelay = 0.05, ProjectileSpeed = 170, Projectile = "Bolt", Scale = 1.05, DefaultTarget = "First",
		Levels = {
			{ Damage = 9,  Range = 18, Cooldown = 0.35, Cost = 700 },
			{ Damage = 13, Range = 19, Cooldown = 0.32, Cost = 500 },
			{ Damage = 18, Range = 20, Cooldown = 0.30, Cost = 850 },
			{ Damage = 26, Range = 21, Cooldown = 0.27, Cost = 1300 },
			{ Damage = 38, Range = 23, Cooldown = 0.24, Cost = 2000 },
		},
	},
	AbyssReaper = {
		Name = "Abyss Reaper", Rarity = "Epic", AttackType = "AOE", ImpactKind = "Reap",
		Description = "Жнец Бездны. Удары косой по области.",
		Anim = "Reap", HitDelay = 0.35, Scale = 1.15, DefaultTarget = "First",
		Levels = {
			{ Damage = 65,  Range = 14, Cooldown = 1.80, Cost = 1400, AOERadius = 6 },
			{ Damage = 94,  Range = 14, Cooldown = 1.70, Cost = 1000, AOERadius = 6.5 },
			{ Damage = 135, Range = 15, Cooldown = 1.60, Cost = 1600, AOERadius = 7 },
			{ Damage = 195, Range = 15, Cooldown = 1.50, Cost = 2500, AOERadius = 8 },
			{ Damage = 285, Range = 16, Cooldown = 1.35, Cost = 3800, AOERadius = 9 },
		},
	},
	CorruptedSamurai = {
		Name = "Corrupted Samurai", Rarity = "Epic", AttackType = "MultiHit",
		Description = "Проклятый самурай. Быстрые удары катаной и криты.",
		Anim = "Katana", HitDelay = 0.15, HitInterval = 0.16, Scale = 1.1, DefaultTarget = "First",
		Levels = {
			{ Damage = 49,  Range = 13, Cooldown = 0.75, Cost = 1500, CritChance = 0.15, CritMult = 2.0, Hits = 1 },
			{ Damage = 72,  Range = 13, Cooldown = 0.70, Cost = 1100, CritChance = 0.18, CritMult = 2.0, Hits = 1 },
			{ Damage = 105,  Range = 14, Cooldown = 0.65, Cost = 1800, CritChance = 0.20, CritMult = 2.2, Hits = 1 },
			{ Damage = 110,  Range = 14, Cooldown = 0.60, Cost = 2700, CritChance = 0.25, CritMult = 2.4, Hits = 2 },
			{ Damage = 160, Range = 15, Cooldown = 0.55, Cost = 4000, CritChance = 0.30, CritMult = 2.6, Hits = 2 },
		},
	},
	EclipseGuardian = {
		Name = "Eclipse Guardian", Rarity = "Legendary", AttackType = "AOE", ImpactKind = "Shockwave",
		Description = "Огромный рыцарь. ECLIPSE SHOCKWAVE — ударная волна по всем врагам в области.",
		Ability = "ECLIPSE SHOCKWAVE",
		Anim = "Slam", HitDelay = 0.55, Scale = 1.3, DefaultTarget = "First",
		Levels = {
			{ Damage = 160, Range = 15, Cooldown = 2.40, Cost = 3200, AOERadius = 8 },
			{ Damage = 230, Range = 15, Cooldown = 2.30, Cost = 2200, AOERadius = 9 },
			{ Damage = 325, Range = 16, Cooldown = 2.20, Cost = 3500, AOERadius = 10 },
			{ Damage = 460, Range = 17, Cooldown = 2.10, Cost = 5200, AOERadius = 11.5 },
			{ Damage = 675, Range = 18, Cooldown = 1.90, Cost = 7800, AOERadius = 14 },
		},
	},
	FallenAngel = {
		Name = "Fallen Angel", Rarity = "Legendary", AttackType = "Laser",
		Description = "Падший ангел. FALLEN BEAM — огромный урон по одной цели. Убийца боссов.",
		Ability = "FALLEN BEAM",
		Anim = "Beam", HitDelay = 0.4, Scale = 1.25, DefaultTarget = "Strongest",
		Levels = {
			{ Damage = 420,  Range = 28, Cooldown = 2.60, Cost = 3500, CritChance = 0.20, CritMult = 2.0 },
			{ Damage = 600,  Range = 30, Cooldown = 2.50, Cost = 2400, CritChance = 0.22, CritMult = 2.1 },
			{ Damage = 860,  Range = 32, Cooldown = 2.40, Cost = 3800, CritChance = 0.25, CritMult = 2.2 },
			{ Damage = 1250, Range = 34, Cooldown = 2.30, Cost = 5600, CritChance = 0.28, CritMult = 2.35 },
			{ Damage = 1850, Range = 36, Cooldown = 2.10, Cost = 8500, CritChance = 0.32, CritMult = 2.5 },
		},
	},
	VoidEmperor = {
		Name = "Void Emperor", Rarity = "Mythic", AttackType = "MultiHit",
		Description = "Император Пустоты. VOID JUDGEMENT — серия энергетических разрезов по врагам.",
		Ability = "VOID JUDGEMENT",
		Anim = "Judgement", HitDelay = 0.5, HitInterval = 0.18, Scale = 1.4, DefaultTarget = "First",
		Levels = {
			{ Damage = 195, Range = 20, Cooldown = 3.0, Cost = 6500,  Hits = 3 },
			{ Damage = 275, Range = 21, Cooldown = 2.9, Cost = 4200,  Hits = 3 },
			{ Damage = 390, Range = 22, Cooldown = 2.8, Cost = 6500,  Hits = 4 },
			{ Damage = 560, Range = 23, Cooldown = 2.7, Cost = 9500,  Hits = 4 },
			{ Damage = 805, Range = 25, Cooldown = 2.5, Cost = 14000, Hits = 6 },
		},
	},
	AbyssOverlord = {
		Name = "Abyss Overlord", Rarity = "Mythic", AttackType = "AOE", ImpactKind = "Smash",
		Description = "Повелитель Бездны. Сокрушающие удары + BLACK HOLE: замедление и урон по области.",
		Ability = "BLACK HOLE",
		Anim = "Smash", HitDelay = 0.45, Scale = 1.55, DefaultTarget = "First",
		Levels = {
			{ Damage = 240, Range = 15, Cooldown = 2.0, Cost = 7000, AOERadius = 5,
				BlackHole = { Cooldown = 12, Duration = 4.5, Radius = 8,  Tick = 0.5, TickDamage = 68,  Slow = 0.40 } },
			{ Damage = 335, Range = 15, Cooldown = 1.9, Cost = 4500, AOERadius = 5,
				BlackHole = { Cooldown = 11, Duration = 5.0, Radius = 9,  Tick = 0.5, TickDamage = 98,  Slow = 0.45 } },
			{ Damage = 480, Range = 16, Cooldown = 1.8, Cost = 7000, AOERadius = 5.5,
				BlackHole = { Cooldown = 10, Duration = 5.5, Radius = 10, Tick = 0.5, TickDamage = 135,  Slow = 0.50 } },
			{ Damage = 685, Range = 16, Cooldown = 1.7, Cost = 10000, AOERadius = 6,
				BlackHole = { Cooldown = 9,  Duration = 6.0, Radius = 11, Tick = 0.5, TickDamage = 195, Slow = 0.55 } },
			{ Damage = 985, Range = 17, Cooldown = 1.6, Cost = 15000, AOERadius = 7,
				BlackHole = { Cooldown = 8,  Duration = 7.0, Radius = 14, Tick = 0.5, TickDamage = 285, Slow = 0.60 } },
		},
		BlackHoleExtraRange = 11, -- чёрная дыра достаёт дальше обычной атаки
	},

	--------------------------------------------------------------------
	-- SHATTERED REALITY CASE
	--------------------------------------------------------------------
	RiftScout = {
		Name = "Rift Scout", Rarity = "Common", AttackType = "Melee", Case = "ShatteredReality",
		Description = "Разведчик с двумя кинжалами. Каждый 5-й удар наносит 150% урона.",
		Anim = "DualDagger", HitDelay = 0.12, Scale = 1.0, DefaultTarget = "First",
		EveryNth = { N = 5, Mult = 1.5 },
		Levels = {
			{ Damage = 9,  Range = 11, Cooldown = 0.55, Cost = 200 },
			{ Damage = 13, Range = 11, Cooldown = 0.52, Cost = 150 },
			{ Damage = 18, Range = 12, Cooldown = 0.48, Cost = 280 },
			{ Damage = 26, Range = 12, Cooldown = 0.44, Cost = 450 },
			{ Damage = 38, Range = 13, Cooldown = 0.40, Cost = 700 },
		},
	},
	CrystalHunter = {
		Name = "Crystal Hunter", Rarity = "Rare", AttackType = "Projectile", Case = "ShatteredReality",
		Description = "Кристальный арбалет. Кристаллы взрываются по области. На 5-м уровне — двойной выстрел.",
		Anim = "Crossbow", HitDelay = 0.2, ProjectileSpeed = 110, Projectile = "Crystal", Scale = 1.0, DefaultTarget = "First",
		ExplodeMult = 0.5, ImpactColor = Color3.fromRGB(80, 170, 255),
		Levels = {
			{ Damage = 30,  Range = 22, Cooldown = 1.10, Cost = 800,  Explode = 4,   Shots = 1 },
			{ Damage = 44,  Range = 23, Cooldown = 1.05, Cost = 550,  Explode = 4.5, Shots = 1 },
			{ Damage = 64,  Range = 24, Cooldown = 1.00, Cost = 900,  Explode = 5,   Shots = 1 },
			{ Damage = 92,  Range = 26, Cooldown = 0.95, Cost = 1400, Explode = 5.5, Shots = 1 },
			{ Damage = 130, Range = 28, Cooldown = 0.90, Cost = 2200, Explode = 6,   Shots = 2 },
		},
	},
	VoidPuppeteer = {
		Name = "Void Puppeteer", Rarity = "Epic", AttackType = "Thread", Case = "ShatteredReality",
		Description = "Кукловод. Нити замедляют и наносят периодический урон. На 5-м уровне — 3 цели.",
		Anim = "Puppet", HitDelay = 0.25, Scale = 1.05, DefaultTarget = "First",
		Levels = {
			{ Damage = 35,  Range = 16, Cooldown = 1.3,  Cost = 1600, Targets = 1, Slow = 0.30, SlowTime = 1.5, Dot = 15, DotTime = 3 },
			{ Damage = 50,  Range = 16, Cooldown = 1.25, Cost = 1100, Targets = 1, Slow = 0.35, SlowTime = 1.5, Dot = 22, DotTime = 3 },
			{ Damage = 72,  Range = 17, Cooldown = 1.2,  Cost = 1800, Targets = 2, Slow = 0.40, SlowTime = 1.6, Dot = 32, DotTime = 3 },
			{ Damage = 105, Range = 18, Cooldown = 1.1,  Cost = 2800, Targets = 2, Slow = 0.45, SlowTime = 1.7, Dot = 46, DotTime = 3 },
			{ Damage = 150, Range = 19, Cooldown = 1.0,  Cost = 4200, Targets = 3, Slow = 0.50, SlowTime = 1.8, Dot = 68, DotTime = 3 },
		},
	},
	Starbreaker = {
		Name = "Starbreaker", Rarity = "Legendary", AttackType = "AOE", ImpactKind = "Hammer", Case = "ShatteredReality",
		Description = "Разрушитель звёзд. Удар молотом — круговой взрыв. С 3-го уровня падают звёздные осколки.",
		Ability = "STAR SMASH",
		Anim = "Hammer", HitDelay = 0.55, Scale = 1.3, DefaultTarget = "First",
		Levels = {
			{ Damage = 150, Range = 14, Cooldown = 2.4, Cost = 3600, AOERadius = 8 },
			{ Damage = 210, Range = 14, Cooldown = 2.3, Cost = 2400, AOERadius = 9 },
			{ Damage = 300, Range = 15, Cooldown = 2.2, Cost = 3800, AOERadius = 10,   Shards = 2, ShardRadius = 4, ShardMult = 0.6 },
			{ Damage = 430, Range = 16, Cooldown = 2.1, Cost = 5800, AOERadius = 11.5, Shards = 3, ShardRadius = 4.5, ShardMult = 0.6 },
			{ Damage = 620, Range = 17, Cooldown = 1.9, Cost = 8600, AOERadius = 13,   Shards = 5, ShardRadius = 5, ShardMult = 0.7 },
		},
	},
	RiftMonarch = {
		Name = "Rift Monarch", Rarity = "Mythic", AttackType = "MultiHit", ImpactKind = "Rift", Case = "ShatteredReality",
		Description = "Монарх Разломов. RIFT STORM — порталы бьют по разным врагам. На 5-м уровне — большой разлом.",
		Ability = "RIFT STORM",
		Anim = "RiftStorm", HitDelay = 0.5, HitInterval = 0.14, Spread = true, Scale = 1.4, DefaultTarget = "First",
		Levels = {
			{ Damage = 170, Range = 22, Cooldown = 3.0, Cost = 7200,  Hits = 3 },
			{ Damage = 240, Range = 23, Cooldown = 2.9, Cost = 4600,  Hits = 4 },
			{ Damage = 340, Range = 24, Cooldown = 2.8, Cost = 7200,  Hits = 4 },
			{ Damage = 480, Range = 25, Cooldown = 2.7, Cost = 10500, Hits = 5 },
			{ Damage = 690, Range = 27, Cooldown = 2.5, Cost = 15500, Hits = 6, BigRift = 12, BigRiftMult = 1.5 },
		},
	},
	RealityDestroyer = {
		Name = "REALITY DESTROYER", Rarity = "Secret", AttackType = "Splash", Case = "ShatteredReality",
		Description = "SECRET. RED SPLASH: каждый удар — 100% по цели и 50% по всем врагам вокруг.",
		Ability = "RED SPLASH",
		Anim = "RedSplash", HitDelay = 0.35, Scale = 1.5, DefaultTarget = "First",
		SplashMult = 0.5, ImpactColor = Color3.fromRGB(255, 30, 50),
		Levels = {
			{ Damage = 320,  Range = 15, Cooldown = 1.6,  Cost = 9000,  AOERadius = 8 },
			{ Damage = 450,  Range = 15, Cooldown = 1.5,  Cost = 6000,  AOERadius = 9 },
			{ Damage = 640,  Range = 16, Cooldown = 1.45, Cost = 9000,  AOERadius = 11 },
			{ Damage = 900,  Range = 17, Cooldown = 1.35, Cost = 13000, AOERadius = 13 },
			{ Damage = 1300, Range = 18, Cooldown = 1.25, Cost = 19000, AOERadius = 16 },
		},
	},

	--------------------------------------------------------------------
	-- BLOOD MOON CASE
	--------------------------------------------------------------------
	BloodAcolyte = {
		Name = "Blood Initiate", Rarity = "Common", AttackType = "Melee", Case = "BloodMoon",
		Description = "Послушник с кровавой глефой. Удары вызывают кровотечение.",
		Anim = "Sickle", HitDelay = 0.2, Scale = 1.0, DefaultTarget = "First",
		ImpactColor = Color3.fromRGB(220, 30, 50),
		Levels = {
			{ Damage = 10, Range = 12, Cooldown = 0.85, Cost = 180, Bleed = 4,  BleedTime = 3 },
			{ Damage = 14, Range = 12, Cooldown = 0.80, Cost = 140, Bleed = 6,  BleedTime = 3 },
			{ Damage = 20, Range = 13, Cooldown = 0.75, Cost = 260, Bleed = 8,  BleedTime = 3 },
			{ Damage = 29, Range = 13, Cooldown = 0.70, Cost = 420, Bleed = 11, BleedTime = 3 },
			{ Damage = 42, Range = 14, Cooldown = 0.65, Cost = 650, Bleed = 16, BleedTime = 3 },
		},
	},
	CrimsonGunslinger = {
		Name = "Scarlet Hunter", Rarity = "Rare", AttackType = "Projectile", Case = "BloodMoon",
		Description = "Охотник с кровавым луком. Всегда стреляет двумя стрелами.",
		Anim = "Bow", HitDelay = 0.05, ProjectileSpeed = 200, Projectile = "Arrow", Scale = 1.0, DefaultTarget = "First",
		ImpactColor = Color3.fromRGB(255, 70, 70),
		Levels = {
			{ Damage = 14, Range = 19, Cooldown = 0.80, Cost = 750,  Shots = 2 },
			{ Damage = 20, Range = 20, Cooldown = 0.76, Cost = 520,  Shots = 2 },
			{ Damage = 29, Range = 21, Cooldown = 0.72, Cost = 880,  Shots = 2 },
			{ Damage = 42, Range = 22, Cooldown = 0.66, Cost = 1350, Shots = 2 },
			{ Damage = 60, Range = 24, Cooldown = 0.60, Cost = 2100, Shots = 2 },
		},
	},
	MoonWitch = {
		Name = "Crimson Witch", Rarity = "Epic", AttackType = "Chain", Case = "BloodMoon",
		Description = "Кровавая ведьма. Лунный серп отскакивает между врагами.",
		Anim = "Cast", HitDelay = 0.3, ProjectileSpeed = 60, Projectile = "Moon", Scale = 1.05, DefaultTarget = "First",
		BounceMult = 0.8, BounceRange = 12, ImpactColor = Color3.fromRGB(255, 120, 140),
		Levels = {
			{ Damage = 40,  Range = 17, Cooldown = 1.5,  Cost = 1500, Bounces = 3 },
			{ Damage = 58,  Range = 18, Cooldown = 1.45, Cost = 1050, Bounces = 3 },
			{ Damage = 84,  Range = 19, Cooldown = 1.4,  Cost = 1750, Bounces = 4 },
			{ Damage = 120, Range = 20, Cooldown = 1.3,  Cost = 2700, Bounces = 4 },
			{ Damage = 175, Range = 21, Cooldown = 1.2,  Cost = 4000, Bounces = 5 },
		},
	},
	BloodfangWarlord = {
		Name = "Blood Paladin", Rarity = "Legendary", AttackType = "AOE", ImpactKind = "Cleave", Case = "BloodMoon",
		Description = "Кровавый паладин с топором и башенным щитом. Рассекающий удар по области + кровотечение.",
		Ability = "BLOOD CLEAVE",
		Anim = "Axe", HitDelay = 0.4, Scale = 1.3, DefaultTarget = "First",
		ImpactColor = Color3.fromRGB(230, 30, 40),
		Levels = {
			{ Damage = 140, Range = 13, Cooldown = 2.0,  Cost = 3400, AOERadius = 7,   Bleed = 25,  BleedTime = 3 },
			{ Damage = 200, Range = 13, Cooldown = 1.9,  Cost = 2300, AOERadius = 7.5, Bleed = 35,  BleedTime = 3 },
			{ Damage = 285, Range = 14, Cooldown = 1.8,  Cost = 3600, AOERadius = 8,   Bleed = 50,  BleedTime = 3 },
			{ Damage = 410, Range = 14, Cooldown = 1.7,  Cost = 5500, AOERadius = 9,   Bleed = 70,  BleedTime = 3 },
			{ Damage = 590, Range = 15, Cooldown = 1.55, Cost = 8200, AOERadius = 10,  Bleed = 100, BleedTime = 3 },
		},
	},
	LunarSeraph = {
		Name = "Moon Devourer", Rarity = "Mythic", AttackType = "Pierce", Case = "BloodMoon",
		Description = "Пожиратель луны. Луч пронзает всех врагов на линии.",
		Ability = "LUNAR LANCE",
		Anim = "Beam", HitDelay = 0.4, Scale = 1.35, DefaultTarget = "First",
		PierceWidth = 3.2, ImpactColor = Color3.fromRGB(255, 200, 220),
		Levels = {
			{ Damage = 380,  Range = 26, Cooldown = 2.6, Cost = 7000,  CritChance = 0.15, CritMult = 2 },
			{ Damage = 540,  Range = 27, Cooldown = 2.5, Cost = 4500,  CritChance = 0.17, CritMult = 2 },
			{ Damage = 770,  Range = 28, Cooldown = 2.4, Cost = 7000,  CritChance = 0.2,  CritMult = 2.2 },
			{ Damage = 1100, Range = 30, Cooldown = 2.3, Cost = 10000, CritChance = 0.22, CritMult = 2.3 },
			{ Damage = 1600, Range = 32, Cooldown = 2.1, Cost = 15000, CritChance = 0.25, CritMult = 2.5 },
		},
	},
	CrimsonEclipse = {
		Name = "SCARLET ECLIPSE", Rarity = "Secret", AttackType = "AOE", ImpactKind = "Reap", Case = "BloodMoon",
		Description = "SECRET. Удары косой по области + BLOOD MOON: падающая кровавая луна.",
		Ability = "BLOOD MOON",
		Anim = "Reap", HitDelay = 0.35, Scale = 1.5, DefaultTarget = "First",
		ImpactColor = Color3.fromRGB(255, 30, 50),
		Levels = {
			{ Damage = 300,  Range = 15, Cooldown = 1.7, Cost = 9000,  AOERadius = 6,
				BloodMoon = { Cooldown = 14, Radius = 12, Mult = 3, Bleed = 60,  BleedTime = 4 } },
			{ Damage = 420,  Range = 15, Cooldown = 1.6, Cost = 6000,  AOERadius = 6.5,
				BloodMoon = { Cooldown = 13, Radius = 13, Mult = 3, Bleed = 85,  BleedTime = 4 } },
			{ Damage = 600,  Range = 16, Cooldown = 1.5, Cost = 9000,  AOERadius = 7,
				BloodMoon = { Cooldown = 12, Radius = 14, Mult = 3, Bleed = 120, BleedTime = 4 } },
			{ Damage = 850,  Range = 17, Cooldown = 1.4, Cost = 13000, AOERadius = 8,
				BloodMoon = { Cooldown = 11, Radius = 16, Mult = 3, Bleed = 170, BleedTime = 4 } },
			{ Damage = 1200, Range = 18, Cooldown = 1.3, Cost = 19000, AOERadius = 9,
				BloodMoon = { Cooldown = 9,  Radius = 20, Mult = 3, Bleed = 240, BleedTime = 4 } },
		},
		AbilityExtraRange = 8,
	},
	--------------------------------------------------------------------
	-- HALLOWEEN CASE
	--------------------------------------------------------------------
	-- Power — способность вместо каждой N-й обычной атаки:
	--   Mode = "AOE" (по области вокруг цели), "Self" (волна вокруг юнита), "Single" (одна цель, Mult и метка),
	--   "Zone" (облако урона по времени). Radius — из Power или из уровня (PowerRadius).
	NightWatchman = {
		Name = "Night Watchman", Rarity = "Common", Event = "Halloween", AttackType = "AOE", ImpactKind = "LightFlash", Case = "Halloween",
		Description = "🎃 Ночной сторож с фонарём. Вспышки света бьют по небольшой области.",
		Ability = "ЛУЧ ФОНАРЯ",
		Anim = "Lantern", HitDelay = 0.28, Scale = 1.0, DefaultTarget = "First",
		ImpactColor = Color3.fromRGB(255, 220, 140),
		Power = { N = 5, Anim = "LanternBeam", Kind = "LanternBeam", Mode = "AOE", Mult = 1.6, Radius = 6 },
		PreviewAbilities = { { "LanternBeam", "ЛУЧ" } },
		Levels = {
			{ Damage = 8,  Range = 12, Cooldown = 1.20, Cost = 220, AOERadius = 4 },
			{ Damage = 11, Range = 12, Cooldown = 1.15, Cost = 170, AOERadius = 4 },
			{ Damage = 16, Range = 13, Cooldown = 1.10, Cost = 300, AOERadius = 4.5 },
			{ Damage = 23, Range = 13, Cooldown = 1.00, Cost = 480, AOERadius = 4.5 },
			{ Damage = 33, Range = 14, Cooldown = 0.95, Cost = 750, AOERadius = 5 },
		},
	},
	Gravedigger = {
		Name = "Gravedigger", Rarity = "Rare", Event = "Halloween", AttackType = "Melee", Case = "Halloween",
		Description = "🎃 Могильщик. Тяжёлые удары лопатой. Каждый 4-й удар — взрыв земли и камней по области.",
		Ability = "ВЗРЫВ ЗЕМЛИ",
		Anim = "Shovel", HitDelay = 0.3, Scale = 1.05, DefaultTarget = "First",
		ImpactColor = Color3.fromRGB(150, 120, 90),
		Power = { N = 4, Anim = "DirtBurst", Kind = "DirtBurst", Mode = "AOE", Mult = 1.2, Radius = 5 },
		PreviewAbilities = { { "DirtBurst", "ЗЕМЛЯ" } },
		Levels = {
			{ Damage = 45,  Range = 12, Cooldown = 1.30, Cost = 650 },
			{ Damage = 65,  Range = 12, Cooldown = 1.25, Cost = 480 },
			{ Damage = 95,  Range = 13, Cooldown = 1.20, Cost = 800 },
			{ Damage = 140, Range = 13, Cooldown = 1.10, Cost = 1250 },
			{ Damage = 210, Range = 14, Cooldown = 1.05, Cost = 1900 },
		},
	},
	CursedScarecrow = {
		Name = "Cursed Scarecrow", Rarity = "Rare", Event = "Halloween", AttackType = "Projectile", Case = "Halloween",
		Description = "🎃 Проклятое пугало. Насылает ворон. Каждая 5-я атака — вихрь листьев: урон и замедление по области.",
		Ability = "ВИХРЬ ЛИСТЬЕВ",
		Anim = "Crows", HitDelay = 0.25, ProjectileSpeed = 60, Projectile = "Crow", Scale = 1.05, DefaultTarget = "First",
		ImpactColor = Color3.fromRGB(230, 150, 50),
		Power = { N = 5, Anim = "LeafStorm", Kind = "LeafStorm", Mode = "AOE", Mult = 0.9, Radius = 6, Slow = 0.2, SlowTime = 1.5 },
		PreviewAbilities = { { "LeafStorm", "ВИХРЬ" } },
		Levels = {
			{ Damage = 24,  Range = 18, Cooldown = 1.10, Cost = 700 },
			{ Damage = 35,  Range = 19, Cooldown = 1.05, Cost = 500 },
			{ Damage = 50,  Range = 20, Cooldown = 1.00, Cost = 850 },
			{ Damage = 72,  Range = 22, Cooldown = 0.92, Cost = 1300 },
			{ Damage = 105, Range = 24, Cooldown = 0.85, Cost = 2000 },
		},
	},
	CursedSheriff = {
		Name = "Cursed Sheriff", Rarity = "Epic", Event = "Halloween", AttackType = "Projectile", Case = "Halloween",
		Description = "🎃 Проклятый шериф. Зелёные проклятые пули. Каждый 4-й выстрел — метка проклятия: x2.5 урона, цель 3 с получает +15% урона.",
		Ability = "МЕТКА ПРОКЛЯТИЯ",
		Anim = "Revolver", HitDelay = 0.08, ProjectileSpeed = 150, Projectile = "CurseBullet", Scale = 1.05, DefaultTarget = "First",
		ImpactColor = Color3.fromRGB(120, 255, 110),
		Power = { N = 4, Anim = "CurseMark", Kind = "CurseMark", Mode = "Single", Mult = 2.5, Mark = 0.15, MarkTime = 3 },
		PreviewAbilities = { { "CurseMark", "МЕТКА" } },
		Levels = {
			{ Damage = 32,  Range = 20, Cooldown = 0.65, Cost = 1500 },
			{ Damage = 46,  Range = 21, Cooldown = 0.60, Cost = 1050 },
			{ Damage = 66,  Range = 22, Cooldown = 0.55, Cost = 1750 },
			{ Damage = 95,  Range = 23, Cooldown = 0.50, Cost = 2700 },
			{ Damage = 138, Range = 25, Cooldown = 0.45, Cost = 4000 },
		},
	},
	MidnightBellringer = {
		Name = "Midnight Bellringer", Rarity = "Epic", Event = "Halloween", AttackType = "Pulse", Case = "Halloween",
		Description = "🎃 Полуночный звонарь. Удар в колокол — круговая звуковая волна. Каждый 4-й удар — ПОЛНОЧЬ: сильная волна, призрачные часы и замедление.",
		Ability = "ПОЛНОЧНЫЙ ЗВОН",
		Anim = "Bell", HitDelay = 0.35, Scale = 1.1, DefaultTarget = "First",
		ImpactColor = Color3.fromRGB(190, 160, 255),
		Power = { N = 4, Anim = "MidnightToll", Kind = "MidnightToll", Mode = "Self", Mult = 1.8, Slow = 0.3, SlowTime = 1.5 },
		PreviewAbilities = { { "MidnightToll", "ПОЛНОЧЬ" } },
		Levels = {
			{ Damage = 40,  Range = 10, Cooldown = 1.90, Cost = 1600, AOERadius = 10 },
			{ Damage = 58,  Range = 10, Cooldown = 1.80, Cost = 1100, AOERadius = 10 },
			{ Damage = 84,  Range = 11, Cooldown = 1.70, Cost = 1800, AOERadius = 11 },
			{ Damage = 120, Range = 12, Cooldown = 1.60, Cost = 2800, AOERadius = 12 },
			{ Damage = 175, Range = 13, Cooldown = 1.50, Cost = 4200, AOERadius = 13 },
		},
	},
	PlagueDoctor = {
		Name = "Plague Doctor", Rarity = "Legendary", Event = "Halloween", AttackType = "Flask", Case = "Halloween",
		Description = "🎃 Чумной доктор. Бросает колбы с ядом: взрыв и ядовитая лужа. Каждая 4-я колба — ЧУМНОЕ ОБЛАКО с воронами.",
		Ability = "ЧУМНОЕ ОБЛАКО",
		Anim = "Flask", HitDelay = 0.3, ProjectileSpeed = 45, Projectile = "Flask", Scale = 1.15, DefaultTarget = "First",
		ImpactColor = Color3.fromRGB(140, 230, 80),
		PoisonTime = 3, PoisonTick = 0.5,
		Power = { N = 4, Anim = "PlagueCloud", Kind = "PlagueCloud", Mode = "Zone", Mult = 1.0, RadiusMult = 1.6, Duration = 5 },
		PreviewAbilities = { { "PlagueCloud", "ОБЛАКО" } },
		Levels = {
			{ Damage = 120, Range = 18, Cooldown = 2.0, Cost = 3400, Explode = 5,   PoisonDps = 40 },
			{ Damage = 170, Range = 19, Cooldown = 1.9, Cost = 2300, Explode = 5.5, PoisonDps = 56 },
			{ Damage = 245, Range = 20, Cooldown = 1.8, Cost = 3600, Explode = 6,   PoisonDps = 80 },
			{ Damage = 350, Range = 21, Cooldown = 1.7, Cost = 5500, Explode = 6.5, PoisonDps = 115 },
			{ Damage = 510, Range = 23, Cooldown = 1.6, Cost = 8200, Explode = 7,   PoisonDps = 170 },
		},
	},
	PhantomKnight = {
		Name = "Phantom Knight", Rarity = "Legendary", Event = "Halloween", AttackType = "Pierce", Case = "Halloween",
		Description = "🎃 Призрачный рыцарь. Синие разрезы пронзают всех на линии. Каждый 4-й удар — ГИГАНТСКИЙ ПРИЗРАЧНЫЙ МЕЧ падает на врагов.",
		Ability = "ПРИЗРАЧНЫЙ МЕЧ",
		Anim = "GhostSlash", HitDelay = 0.3, Scale = 1.25, DefaultTarget = "First",
		PierceWidth = 3.4, ImpactColor = Color3.fromRGB(90, 170, 255), ImpactKindPierce = "GhostSlash",
		Power = { N = 4, Anim = "GhostSword", Kind = "GhostSword", Mode = "AOE", Mult = 2, Delay = 0.55 },
		PreviewAbilities = { { "GhostSword", "МЕЧ" } },
		Levels = {
			{ Damage = 230, Range = 15, Cooldown = 2.2,  Cost = 3500, PowerRadius = 8 },
			{ Damage = 330, Range = 16, Cooldown = 2.1,  Cost = 2400, PowerRadius = 8.5 },
			{ Damage = 470, Range = 16, Cooldown = 2.0,  Cost = 3800, PowerRadius = 9 },
			{ Damage = 670, Range = 17, Cooldown = 1.9,  Cost = 5600, PowerRadius = 10 },
			{ Damage = 980, Range = 18, Cooldown = 1.8,  Cost = 8400, PowerRadius = 11 },
		},
	},
	DarkIllusionist = {
		Name = "Dark Illusionist", Rarity = "Legendary", Event = "Halloween", AttackType = "Projectile", Case = "Halloween",
		Description = "🎃 Тёмный иллюзионист. Бросает веер карт. Каждая 5-я атака — ЗЕРКАЛЬНЫЙ РАЗЛОМ. Из фиолетового портала призывает иллюзии.",
		Ability = "ЗЕРКАЛЬНЫЙ РАЗЛОМ • ИЛЛЮЗИИ",
		Anim = "Cards", HitDelay = 0.2, ProjectileSpeed = 100, Projectile = "Card", Scale = 1.1, DefaultTarget = "First",
		ImpactColor = Color3.fromRGB(190, 90, 255),
		Power = { N = 5, Anim = "MirrorShatter", Kind = "MirrorShatter", Mode = "AOE", Mult = 1.5, Radius = 6 },
		PreviewAbilities = { { "MirrorShatter", "РАЗЛОМ" }, { "Summon", "ПРИЗЫВ" } },
		-- призыв иллюзий: интервал по уровню, не больше Max живых от одного Иллюзиониста
		Summon = {
			Max = 6, Portal = "Illusion",
			Levels = {
				{ Ally = "ShadowDouble",  Count = 1, HP = 400,  Interval = 30 },
				{ Ally = "CardSoldier",   Count = 1, HP = 800,  Interval = 28 },
				{ Ally = "MirrorKnight",  Count = 2, HP = 1400, Interval = 26 },
				{ Ally = "PhantomMage",   Count = 2, HP = 2400, Interval = 24 },
				{ Ally = "RoyalIllusion", Count = 3, HP = 3500, Interval = 22 },
			},
		},
		Levels = {
			{ Damage = 70,  Range = 18, Cooldown = 1.6,  Cost = 3600, Shots = 3 },
			{ Damage = 100, Range = 19, Cooldown = 1.5,  Cost = 2400, Shots = 3 },
			{ Damage = 140, Range = 20, Cooldown = 1.45, Cost = 3800, Shots = 3 },
			{ Damage = 200, Range = 21, Cooldown = 1.35, Cost = 5800, Shots = 3 },
			{ Damage = 290, Range = 23, Cooldown = 1.25, Cost = 8600, Shots = 3 },
		},
	},
	HalloweenPuppeteer = {
		Name = "Puppeteer", Rarity = "Mythic", Event = "Halloween", AttackType = "Thread", Case = "Halloween",
		Description = "🎃 Кукловод. Красные нити режут и замедляют врагов. Каждая 5-я атака — РАЗРЫВ НИТЕЙ. Призывает марионеток.",
		Ability = "РАЗРЫВ НИТЕЙ • МАРИОНЕТКИ",
		Anim = "Puppet", HitDelay = 0.25, Scale = 1.3, DefaultTarget = "First",
		ImpactColor = Color3.fromRGB(230, 30, 50), ThreadColor = Color3.fromRGB(230, 30, 50),
		Power = { N = 5, Anim = "ThreadSnap", Kind = "ThreadSnap", Mode = "AOE", Mult = 1.5, Radius = 7 },
		PreviewAbilities = { { "ThreadSnap", "РАЗРЫВ" }, { "Summon", "ПРИЗЫВ" } },
		Summon = {
			Max = 5, Portal = "Puppet",
			-- на MAX уровне каждый 3-й призыв заменяет одну обычную марионетку на Золотую
			Golden = { Every = 3, Ally = "GoldenMarionette", HP = 10000 },
			Levels = {
				{ Ally = "WoodenDoll",         Count = 1, HP = 600,  Interval = 30 },
				{ Ally = "PorcelainDoll",      Count = 1, HP = 1200, Interval = 28 },
				{ Ally = "ArmoredDoll",        Count = 2, HP = 2200, Interval = 26 },
				{ Ally = "CursedPuppetKnight", Count = 2, HP = 4000, Interval = 24 },
				{ Ally = "RoyalMarionette",    Count = 3, HP = 6500, Interval = 22 },
			},
		},
		Levels = {
			{ Damage = 190, Range = 18, Cooldown = 1.6,  Cost = 7000,  Targets = 2, Slow = 0.30, SlowTime = 1.5, Dot = 60,  DotTime = 3 },
			{ Damage = 270, Range = 19, Cooldown = 1.5,  Cost = 4500,  Targets = 2, Slow = 0.33, SlowTime = 1.5, Dot = 85,  DotTime = 3 },
			{ Damage = 385, Range = 20, Cooldown = 1.45, Cost = 7000,  Targets = 3, Slow = 0.36, SlowTime = 1.6, Dot = 120, DotTime = 3 },
			{ Damage = 550, Range = 21, Cooldown = 1.35, Cost = 10000, Targets = 3, Slow = 0.40, SlowTime = 1.7, Dot = 170, DotTime = 3 },
			{ Damage = 800, Range = 22, Cooldown = 1.25, Cost = 15000, Targets = 4, Slow = 0.45, SlowTime = 1.8, Dot = 250, DotTime = 3 },
		},
	},
	HeadlessExecutioner = {
		Name = "Headless Executioner", Rarity = "Mythic", Event = "Halloween", AttackType = "AOE", ImpactKind = "FireCrack", Case = "Halloween",
		Description = "🎃 Безголовый палач. Удар огромным топором раскалывает землю огнём. Каждый 3-й удар — КАЗНЬ: x2.5 урона и поджог.",
		Ability = "КАЗНЬ",
		Anim = "ExecAxe", HitDelay = 0.5, Scale = 1.45, DefaultTarget = "First",
		ImpactColor = Color3.fromRGB(255, 110, 30),
		Power = { N = 3, Anim = "Execution", Kind = "Execution", Mode = "AOE", Mult = 2.5, RadiusAdd = 3, Burn = 0.25, BurnTime = 3, Delay = 0.65 },
		PreviewAbilities = { { "Execution", "КАЗНЬ" } },
		Levels = {
			{ Damage = 300,  Range = 14, Cooldown = 2.4, Cost = 7200,  AOERadius = 7 },
			{ Damage = 420,  Range = 14, Cooldown = 2.3, Cost = 4600,  AOERadius = 7.5 },
			{ Damage = 600,  Range = 15, Cooldown = 2.2, Cost = 7200,  AOERadius = 8 },
			{ Damage = 850,  Range = 16, Cooldown = 2.1, Cost = 10500, AOERadius = 9 },
			{ Damage = 1230, Range = 17, Cooldown = 2.0, Cost = 15500, AOERadius = 10 },
		},
	},
	LanternKing = {
		Name = "LANTERN KING", Rarity = "Secret", Event = "Halloween", AttackType = "Projectile", Case = "Halloween",
		Description = "SECRET 🎃 Король фонарей. Огненные тыквы взрываются по области. Каждая 4-я атака — ПРИЗРАЧНАЯ ТЫКВА: огромный взрыв.",
		Ability = "ПРИЗРАЧНАЯ ТЫКВА",
		Anim = "LanternStaff", HitDelay = 0.3, ProjectileSpeed = 55, Projectile = "Pumpkin", Scale = 1.45, DefaultTarget = "First",
		ExplodeMult = 0.6, ImpactColor = Color3.fromRGB(255, 130, 30), ExplodeKind = "PumpkinBlast", PlaceFX = "Throne",
		Power = { N = 4, Anim = "GhostPumpkin", Kind = "GhostPumpkin", Mode = "AOE", Mult = 2.5, Delay = 0.8 },
		PreviewAbilities = { { "GhostPumpkin", "ТЫКВА" } },
		Levels = {
			{ Damage = 330,  Range = 18, Cooldown = 1.6,  Cost = 9500,  Explode = 5,   PowerRadius = 10 },
			{ Damage = 460,  Range = 19, Cooldown = 1.5,  Cost = 6500,  Explode = 5.5, PowerRadius = 11 },
			{ Damage = 650,  Range = 20, Cooldown = 1.45, Cost = 9500,  Explode = 6,   PowerRadius = 12 },
			{ Damage = 920,  Range = 21, Cooldown = 1.35, Cost = 13500, Explode = 6.5, PowerRadius = 13 },
			{ Damage = 1330, Range = 22, Cooldown = 1.3,  Cost = 20000, Explode = 7,   PowerRadius = 14 },
		},
	},
	CursedClockmaker = {
		Name = "CURSED CLOCKMAKER", Rarity = "Secret", Event = "Halloween", AttackType = "Chrono", Case = "Halloween",
		Description = "SECRET 🎃 Проклятый часовщик. Хроносекира выпускает зубчатый диск: он летит по прямой и режет до 5 врагов. Три способности времени.",
		Ability = "ПОЛОМКА ВРЕМЕНИ • УСКОРЕНИЕ ВРЕМЕНИ • ВРЕМЕННАЯ БУРЯ",
		Anim = "ChronoSlash", HitDelay = 0.35, ProjectileSpeed = 70, Scale = 1.45, DefaultTarget = "First",
		DiscWidth = 3, DiscTargets = 5, ImpactColor = Color3.fromRGB(255, 160, 50), PlaceFX = "Clock",
		PreviewAbilities = { { "TimeBreak", "ПОЛОМКА" }, { "TimeHaste", "УСКОРЕНИЕ" }, { "TimeStorm", "БУРЯ" } },
		-- 1. Поломка времени: каждая 8-я обычная атака, не чаще раза в 18 с
		TimeBreak = { EveryNth = 8, MinInterval = 18, Radius = 9, MaxFreeze = 4, Freeze = 1.5, BossFreeze = 0.5, MaxRewind = 3, Rewind = 2 },
		-- 2. Ускорение времени: через 30 с после установки и далее каждые 30 с (сила и длительность — по уровням)
		TimeHaste = { FirstDelay = 30, Interval = 30, Radius = 14 },
		-- 3. Временная буря: через 90 с после установки, 15 с AOE, перезарядка 90 с после окончания
		TimeStorm = { FirstDelay = 90, Duration = 15, Cooldown = 90, Radius = 5, Extra = 4, Mult = 0.5 },
		Levels = {
			{ Damage = 240,  Range = 17, Cooldown = 1.6,  Cost = 9500,  Haste = 0.06, HasteTime = 2 },
			{ Damage = 340,  Range = 17, Cooldown = 1.5,  Cost = 6500,  Haste = 0.07, HasteTime = 2.5 },
			{ Damage = 480,  Range = 18, Cooldown = 1.45, Cost = 9500,  Haste = 0.08, HasteTime = 3 },
			{ Damage = 680,  Range = 19, Cooldown = 1.35, Cost = 13500, Haste = 0.09, HasteTime = 3.5 },
			{ Damage = 980,  Range = 20, Cooldown = 1.25, Cost = 20000, Haste = 0.10, HasteTime = 4 },
		},
	},
}

------------------------------------------------------------------------
-- ВРАГИ
-- Health — базовое HP (умножается на множитель волны).
-- Armor — доля поглощаемого урона, Dodge — шанс уклониться.
------------------------------------------------------------------------
Config.EnemyOrder = {
	"LostSoul", "VoidCrawler", "ShadowBeast", "ArmoredHorror", "RiftPhantom",
	"AbyssBrute", "CorruptedTitan", "VoidDevourer", "TheEntity",
	-- Хэллоуин
	"CursedDead", "PumpkinRunner", "PhantomWarrior", "BoneGuard", "LivingScarecrow", "StrawMinion",
	"FogWarlock", "PumpkinBrute", "NightReaper", "GraveWarden", "FogReaper", "CursedMonarch",
}

Config.Enemies = {
	LostSoul       = { Name = "Lost Soul",       Health = 12,    Speed = 10.5,Reward = 10,   CoreDamage = 1,   Scale = 0.85 },
	VoidCrawler    = { Name = "Void Crawler",    Health = 33,    Speed = 9,   Reward = 18,   CoreDamage = 2,   Scale = 1.0 },
	ShadowBeast    = { Name = "Shadow Beast",    Health = 30,    Speed = 16,  Reward = 21,   CoreDamage = 2,   Scale = 1.0 },
	ArmoredHorror  = { Name = "Armored Horror",  Health = 120,   Speed = 7,   Reward = 45,   CoreDamage = 4,   Scale = 1.15, Armor = 0.3 },
	RiftPhantom    = { Name = "Rift Phantom",    Health = 85,    Speed = 11.5,Reward = 40,   CoreDamage = 3,   Scale = 1.05, Dodge = 0.2 },
	AbyssBrute     = { Name = "Abyss Brute",     Health = 510,   Speed = 6,   Reward = 105,  CoreDamage = 8,   Scale = 1.5 },
	CorruptedTitan = { Name = "Corrupted Titan", Health = 1200,  Speed = 5,   Reward = 500,  CoreDamage = 25,  Scale = 2.2, Armor = 0.15, IsBoss = true, BossGems = 50 },
	VoidDevourer   = { Name = "Void Devourer",   Health = 3000,  Speed = 4.5, Reward = 1500, CoreDamage = 50,  Scale = 2.6, IsBoss = true, BossGems = 150 },
	TheEntity      = { Name = "The Entity",      Health = 8400,  Speed = 4,   Reward = 3000, CoreDamage = 100, Scale = 3.0, Armor = 0.1, IsBoss = true, BossGems = 500,
		Summon = { Enemy = "LostSoul", Count = 3, Interval = 7 } },

	--------------------------------------------------------------------
	-- ХЭЛЛОУИН (только на карте Haunted Hollow)
	--------------------------------------------------------------------
	CursedDead      = { Name = "Cursed Dead",      Health = 32,   Speed = 6.5, Reward = 10,  CoreDamage = 1, Scale = 1.0, Event = "Halloween",
		Description = "Медленный проклятый мертвец. После смерти рассыпается в зелёный дым." },
	PumpkinRunner   = { Name = "Pumpkin Runner",   Health = 20,   Speed = 16,  Reward = 9,   CoreDamage = 1, Scale = 0.9, Event = "Halloween",
		Description = "Очень быстрый, но хрупкий. Оставляет оранжевые искры." },
	PhantomWarrior  = { Name = "Phantom Warrior",  Health = 85,   Speed = 10.5,Reward = 32,  CoreDamage = 3, Scale = 1.05, Event = "Halloween",
		Description = "Периодически становится почти невидимым и получает вдвое меньше урона.",
		Phase = { Every = 6, Duration = 1.5, Taken = 0.5 } },
	BoneGuard       = { Name = "Bone Guard",       Health = 240,  Speed = 5.5, Reward = 60,  CoreDamage = 4, Scale = 1.15, Armor = 0.4, Event = "Halloween",
		Description = "Медленный и крепкий. На половине HP броня ломается (40% → 10%).",
		ArmorBreak = { At = 0.5, Armor = 0.1 } },
	LivingScarecrow = { Name = "Living Scarecrow", Health = 120,  Speed = 8.5, Reward = 38,  CoreDamage = 3, Scale = 1.1, Event = "Halloween",
		Description = "После смерти из него выбегают 2 соломенных существа.",
		OnDeath = { Enemy = "StrawMinion", Count = 2 } },
	StrawMinion     = { Name = "Straw Creature",   Health = 18,   Speed = 12,  Reward = 4,   CoreDamage = 1, Scale = 0.6, Event = "Halloween", Minion = true,
		Description = "Соломенное существо из Живого пугала." },
	FogWarlock      = { Name = "Fog Warlock",      Health = 150,  Speed = 7.5, Reward = 55,  CoreDamage = 4, Scale = 1.1, Event = "Halloween",
		Description = "Создаёт туман: враги рядом ускоряются на 30% на 2.5 с.",
		Fog = { Every = 6, Radius = 9, Speed = 0.3, Duration = 2.5 } },
	PumpkinBrute    = { Name = "Pumpkin Brute",    Health = 560,  Speed = 5,   Reward = 110, CoreDamage = 8, Scale = 1.55, Event = "Halloween",
		Description = "Огромный тыквенный громила. Много HP, медленный." },
	NightReaper     = { Name = "Night Reaper",     Health = 1500, Speed = 6,   Reward = 380, CoreDamage = 20, Scale = 1.8, Armor = 0.2, Event = "Halloween", MiniBoss = true,
		Description = "Мини-босс. Каждые 10 с на 3 с ставит защиту: получает вдвое меньше урона.",
		Shield = { Every = 10, Duration = 3, Taken = 0.5 } },
	-- ФИНАЛЬНЫЕ БОССЫ (по одному на сложность)
	GraveWarden     = { Name = "Grave Warden",     Health = 3000, Speed = 4.2, Reward = 2500, CoreDamage = 100, Scale = 2.4, Armor = 0.5, IsBoss = true, BossGems = 150, Event = "Halloween",
		Description = "Босс ЛЁГКОЙ сложности. Мощная броня трескается по мере потери HP. Медленный.",
		ArmorScale = true, SpawnStyle = "Grave" },
	FogReaper       = { Name = "Fog Reaper",       Health = 4500, Speed = 5,   Reward = 3500, CoreDamage = 100, Scale = 2.5, Armor = 0.15, IsBoss = true, BossGems = 250, Event = "Halloween",
		Description = "Босс СРЕДНЕЙ сложности. Ускоряется, создаёт туман, ставит защиту. На 50% HP — красное свечение.",
		Haste = { Every = 12, Duration = 3, Speed = 0.6 },
		Fog = { Every = 8, Radius = 10, Speed = 0.3, Duration = 3 },
		Shield = { Every = 15, Duration = 3, Taken = 0.5 },
		Enrage = { At = 0.5, Speed = 0.15 }, SpawnStyle = "FogVortex" },
	CursedMonarch   = { Name = "Cursed Monarch",   Health = 7000, Speed = 4.2, Reward = 5000, CoreDamage = 100, Scale = 2.7, Armor = 0.15, IsBoss = true, BossGems = 400, Event = "Halloween",
		Description = "Босс СЛОЖНОЙ сложности. Огненная аура, защита на участках дороги, на 50% HP — вторая фаза и 2 Тыквенных громилы.",
		-- участки дороги (доля длины пути), где броня монарха +35%
		ArmorZones = { { 0.28, 0.40, 0.35 }, { 0.60, 0.72, 0.35 } },
		FireAura = 1.5, -- союзники при столкновении теряют в 1.5 раза больше HP
		Enrage = { At = 0.5, Spawn = { "PumpkinBrute", 2 } }, SpawnStyle = "Portal" },
}

------------------------------------------------------------------------
-- ВОЛНЫ: { Враг, Количество, Интервал спавна }
-- Группы идут по очереди (пауза Settings.GroupDelay между ними).
------------------------------------------------------------------------
Config.Waves = {
	[1]  = { { "LostSoul", 6, 1.3 } },
	[2]  = { { "LostSoul", 10, 1.0 } },
	[3]  = { { "LostSoul", 8, 0.9 }, { "VoidCrawler", 4, 1.5 } },
	[4]  = { { "VoidCrawler", 8, 1.2 }, { "LostSoul", 8, 0.6 } },
	[5]  = { { "VoidCrawler", 12, 1.0 }, { "LostSoul", 10, 0.5 } },
	[6]  = { { "ShadowBeast", 6, 1.2 }, { "VoidCrawler", 8, 1.0 } },
	[7]  = { { "ArmoredHorror", 4, 2.5 }, { "ShadowBeast", 8, 0.9 } },
	[8]  = { { "ShadowBeast", 12, 0.7 }, { "ArmoredHorror", 5, 2.0 } },
	[9]  = { { "ArmoredHorror", 8, 1.6 }, { "ShadowBeast", 10, 0.6 }, { "VoidCrawler", 10, 0.6 } },
	[10] = { { "VoidCrawler", 10, 0.8 }, { "CorruptedTitan", 1, 0 }, { "LostSoul", 12, 0.5 } },
	[11] = { { "RiftPhantom", 6, 1.5 }, { "ShadowBeast", 10, 0.6 } },
	[12] = { { "RiftPhantom", 10, 1.2 }, { "ArmoredHorror", 6, 1.6 } },
	[13] = { { "AbyssBrute", 2, 4 }, { "RiftPhantom", 10, 1.0 } },
	[14] = { { "ArmoredHorror", 12, 1.0 }, { "ShadowBeast", 16, 0.5 } },
	[15] = { { "AbyssBrute", 4, 3 }, { "RiftPhantom", 12, 0.9 }, { "VoidCrawler", 15, 0.4 } },
	[16] = { { "ShadowBeast", 25, 0.35 }, { "AbyssBrute", 3, 3 } },
	[17] = { { "RiftPhantom", 16, 0.7 }, { "ArmoredHorror", 10, 1.0 } },
	[18] = { { "AbyssBrute", 6, 2.5 }, { "ArmoredHorror", 12, 0.8 } },
	[19] = { { "CorruptedTitan", 2, 8 }, { "RiftPhantom", 15, 0.6 }, { "ShadowBeast", 20, 0.4 } },
	[20] = { { "AbyssBrute", 4, 2 }, { "VoidDevourer", 1, 0 }, { "RiftPhantom", 12, 0.8 } },
	[21] = { { "ArmoredHorror", 18, 0.7 }, { "AbyssBrute", 6, 2 } },
	[22] = { { "ShadowBeast", 35, 0.3 }, { "RiftPhantom", 15, 0.6 } },
	[23] = { { "AbyssBrute", 10, 1.6 }, { "CorruptedTitan", 2, 6 } },
	[24] = { { "RiftPhantom", 25, 0.5 }, { "ArmoredHorror", 20, 0.6 } },
	[25] = { { "CorruptedTitan", 4, 5 }, { "AbyssBrute", 10, 1.5 }, { "ShadowBeast", 30, 0.3 } },
	[26] = { { "AbyssBrute", 16, 1.2 }, { "RiftPhantom", 25, 0.4 } },
	[27] = { { "VoidDevourer", 1, 0 }, { "CorruptedTitan", 3, 5 }, { "ArmoredHorror", 25, 0.5 } },
	[28] = { { "AbyssBrute", 20, 1.0 }, { "ShadowBeast", 40, 0.25 }, { "RiftPhantom", 20, 0.5 } },
	[29] = { { "CorruptedTitan", 6, 3.5 }, { "VoidDevourer", 2, 10 }, { "AbyssBrute", 15, 1 } },
	[30] = { { "AbyssBrute", 10, 1.2 }, { "TheEntity", 1, 0 }, { "CorruptedTitan", 4, 6 } },
}

------------------------------------------------------------------------
-- КАРТА: The Forgotten Realm
------------------------------------------------------------------------
Config.Map = {
	Name = "The Forgotten Realm",
	GroundY = 60,          -- высота поверхности острова (карта висит в небе)
	PathWidth = 10,
	IslandSize = Vector2.new(250, 196),
	-- Точки дороги (X, Z). Первая — портал, последняя — ядро.
	Path = {
		{ -108, -66 },
		{ -55, -66 },
		{ -55, -10 },
		{ -95, -10 },
		{ -95, 52 },
		{ -20, 52 },
		{ -20, -45 },
		{ 40, -45 },
		{ 40, 56 },
		{ 95, 56 },
		{ 95, -60 },
	},
}

------------------------------------------------------------------------
-- КАРТЫ. Void — обычная карта, Halloween — Haunted Hollow (только из очереди на Хэллоуин-острове).
-- Path у Хэллоуин-карты задан относительно Center.
------------------------------------------------------------------------
Config.Map.Key = "Void"
Config.Map.Center = Vector3.new(0, 60, 0)
Config.Map.BattleSpawn = Config.BattleSpawn

Config.Maps = {
	Void = Config.Map,
	Halloween = {
		Key = "Halloween",
		Name = "Haunted Hollow",
		Center = Vector3.new(560, 60, 0),
		GroundY = 60,
		PathWidth = 10,
		IslandSize = Vector2.new(270, 210),
		BattleSpawn = Vector3.new(590, 60, 45),
		MaxWave = 20,
		Path = {
			{ -112, -72 }, { -50, -72 }, { -50, -22 }, { -100, -22 }, { -100, 40 }, { -62, 76 },
			{ 0, 76 }, { 0, 12 }, { 40, -28 }, { 40, -76 }, { 96, -76 }, { 96, 10 }, { 62, 40 },
			{ 62, 82 }, { 112, 82 },
		},
		-- BOSS — подставляется финальный босс выбранной сложности (Config.Halloween.Bosses)
		Waves = {
			[1]  = { { "CursedDead", 8, 1.2 } },
			[2]  = { { "CursedDead", 10, 0.9 }, { "PumpkinRunner", 4, 1.0 } },
			[3]  = { { "PumpkinRunner", 8, 0.7 }, { "CursedDead", 8, 0.8 } },
			[4]  = { { "PhantomWarrior", 4, 1.8 }, { "CursedDead", 10, 0.7 } },
			[5]  = { { "LivingScarecrow", 4, 2.0 }, { "PumpkinRunner", 10, 0.5 } },
			[6]  = { { "BoneGuard", 3, 3.0 }, { "PhantomWarrior", 6, 1.2 } },
			[7]  = { { "FogWarlock", 2, 4.0 }, { "CursedDead", 16, 0.5 }, { "PumpkinRunner", 8, 0.5 } },
			[8]  = { { "LivingScarecrow", 6, 1.5 }, { "BoneGuard", 4, 2.5 } },
			[9]  = { { "PhantomWarrior", 10, 0.9 }, { "FogWarlock", 3, 3.0 } },
			[10] = { { "PumpkinBrute", 2, 5.0 }, { "NightReaper", 1, 0 }, { "PumpkinRunner", 12, 0.4 } },
			[11] = { { "BoneGuard", 8, 1.6 }, { "LivingScarecrow", 6, 1.2 } },
			[12] = { { "FogWarlock", 4, 2.5 }, { "PhantomWarrior", 12, 0.7 }, { "CursedDead", 20, 0.3 } },
			[13] = { { "PumpkinBrute", 4, 3.5 }, { "PumpkinRunner", 20, 0.35 } },
			[14] = { { "BoneGuard", 10, 1.2 }, { "FogWarlock", 5, 2.0 } },
			[15] = { { "NightReaper", 2, 6.0 }, { "LivingScarecrow", 10, 0.9 }, { "PhantomWarrior", 10, 0.7 } },
			[16] = { { "PumpkinBrute", 6, 2.5 }, { "BoneGuard", 8, 1.0 } },
			[17] = { { "FogWarlock", 6, 1.5 }, { "PhantomWarrior", 16, 0.5 }, { "PumpkinRunner", 25, 0.3 } },
			[18] = { { "NightReaper", 3, 5.0 }, { "PumpkinBrute", 6, 2.0 } },
			[19] = { { "PumpkinBrute", 8, 1.8 }, { "BoneGuard", 12, 0.8 }, { "LivingScarecrow", 10, 0.8 } },
			[20] = { { "FogWarlock", 4, 2.0 }, { "BOSS", 1, 0 }, { "PumpkinBrute", 4, 4.0 }, { "NightReaper", 2, 6.0 } },
		},
	},
}

------------------------------------------------------------------------
-- Утилиты
------------------------------------------------------------------------
function Config.GetUnitStats(unitId, level)
	local def = Config.Units[unitId]
	if not def then return nil end
	return def.Levels[math.clamp(level, 1, #def.Levels)]
end

function Config.WaveHPMult(wave)
	local s = Config.Settings
	local w = math.max(wave - 1, 0)
	return (1 + s.EnemyHPScaleLinear * w + s.EnemyHPScaleQuad * w * w) * (s.EnemyHealthMult or 1)
end

function Config.FormatNumber(n)
	n = math.floor(n + 0.5)
	if n >= 1e6 then
		return string.format("%.1fM", n / 1e6)
	elseif n >= 1e4 then
		return string.format("%.1fK", n / 1e3)
	end
	local s = tostring(n)
	local formatted = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if formatted:sub(1, 1) == "," then formatted = formatted:sub(2) end
	return formatted
end

return Config
