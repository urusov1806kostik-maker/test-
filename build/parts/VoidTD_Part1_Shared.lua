-- VOID TD — установщик, часть 1/3 (1_Shared). Вставляй части по порядку 1 -> 2 -> 3.
local RS = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")
local SPS = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")
local SERVICES = { ReplicatedStorage = RS, ServerScriptService = SSS, StarterPlayerScripts = SPS }
local old = SERVICES["ReplicatedStorage"]:FindFirstChild("VoidTD")
if old then old:Destroy() end
local bp = workspace:FindFirstChild("Baseplate")
if bp and bp:IsA("BasePart") then bp:Destroy() end
local sp = workspace:FindFirstChild("SpawnLocation")
if sp and sp:IsA("SpawnLocation") then sp:Destroy() end
pcall(function() workspace.StreamingEnabled = false end)
local function ensure(parent, name, className)
	local obj = parent:FindFirstChild(name)
	if not obj then
		obj = Instance.new(className)
		obj.Name = name
		obj.Parent = parent
	end
	return obj
end

local function install(service, path, className, source)
	local parent = SERVICES[service]
	for i = 1, #path - 1 do
		parent = ensure(parent, path[i], "Folder")
	end
	local name = path[#path]
	local obj = parent:FindFirstChild(name)
	if obj and obj.ClassName ~= className then
		-- папка-заглушка, созданная для детей: заменяем на скрипт и переносим детей
		local real = Instance.new(className)
		real.Name = name
		for _, child in ipairs(obj:GetChildren()) do child.Parent = real end
		obj:Destroy()
		real.Parent = parent
		obj = real
	elseif not obj then
		obj = Instance.new(className)
		obj.Name = name
		obj.Parent = parent
	end
	obj.Source = source
	return obj
end

local FILES = {}
FILES[#FILES + 1] = { "ReplicatedStorage", { "VoidTD", "Config" }, "ModuleScript", [======[
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
]======] }
FILES[#FILES + 1] = { "ReplicatedStorage", { "VoidTD", "PathUtil" }, "ModuleScript", [======[
--!nocheck
-- VOID TD :: PathUtil
-- Общая математика дороги. Сервер и клиент считают позиции врагов одинаково.

local Config = require(script.Parent.Config)

local PathUtil = {}

local points = {}
local cumulative = { 0 }
local mapCfg = Config.Map

-- Перестроить дорогу для карты (Void / Halloween). Сервер и клиент вызывают при смене карты.
function PathUtil.SetMap(key)
	mapCfg = (Config.Maps and Config.Maps[key]) or Config.Map
	local c = mapCfg.Center or Vector3.new()
	local rel = mapCfg ~= Config.Map
	points = {}
	for i, p in ipairs(mapCfg.Path) do
		points[i] = rel and Vector3.new(c.X + p[1], mapCfg.GroundY, c.Z + p[2]) or Vector3.new(p[1], mapCfg.GroundY, p[2])
	end
	cumulative = { 0 }
	for i = 2, #points do
		cumulative[i] = cumulative[i - 1] + (points[i] - points[i - 1]).Magnitude
	end
	PathUtil.Points = points
	PathUtil.Length = cumulative[#cumulative]
	PathUtil.MapKey = mapCfg.Key or "Void"
	PathUtil.Map = mapCfg
end
PathUtil.SetMap("Void")

-- Доля пройденного пути (0..1)
function PathUtil.Fraction(d)
	return d / PathUtil.Length
end

-- Позиция и направление на расстоянии d от начала дороги
function PathUtil.PositionAt(d)
	local n = #points
	if d <= 0 then
		return points[1], (points[2] - points[1]).Unit
	end
	if d >= PathUtil.Length then
		return points[n], (points[n] - points[n - 1]).Unit
	end
	for i = 2, n do
		if d <= cumulative[i] then
			local seg = points[i] - points[i - 1]
			local alpha = (d - cumulative[i - 1]) / (cumulative[i] - cumulative[i - 1])
			return points[i - 1] + seg * alpha, seg.Unit
		end
	end
	return points[n], (points[n] - points[n - 1]).Unit
end

-- Позиция с боковым смещением (чтобы враги не шли одной ниткой)
function PathUtil.OffsetPositionAt(d, lateral)
	local pos, dir = PathUtil.PositionAt(d)
	if lateral and lateral ~= 0 then
		local right = Vector3.new(-dir.Z, 0, dir.X)
		pos = pos + right * lateral
	end
	return pos, dir
end

-- Горизонтальное расстояние от точки до ближайшего участка дороги
function PathUtil.DistanceToPath(pos)
	local best = math.huge
	local px, pz = pos.X, pos.Z
	for i = 2, #points do
		local ax, az = points[i - 1].X, points[i - 1].Z
		local bx, bz = points[i].X, points[i].Z
		local abx, abz = bx - ax, bz - az
		local lenSq = abx * abx + abz * abz
		local t = 0
		if lenSq > 0 then
			t = math.clamp(((px - ax) * abx + (pz - az) * abz) / lenSq, 0, 1)
		end
		local cx, cz = ax + abx * t, az + abz * t
		local dx, dz = px - cx, pz - cz
		local d = math.sqrt(dx * dx + dz * dz)
		if d < best then
			best = d
		end
	end
	return best
end

function PathUtil.FlatDistance(a, b)
	local dx, dz = a.X - b.X, a.Z - b.Z
	return math.sqrt(dx * dx + dz * dz)
end

-- Проверка позиции для установки (используется и клиентом для превью, и сервером)
function PathUtil.IsPlacementClear(pos)
	local s = Config.Settings
	local half = mapCfg.PathWidth / 2
	if PathUtil.DistanceToPath(pos) < half + s.PathClearance then
		return false, "Нельзя ставить на дорогу"
	end
	local size = mapCfg.IslandSize
	local c = mapCfg.Center or Vector3.new()
	if math.abs(pos.X - c.X) > size.X / 2 - 3 or math.abs(pos.Z - c.Z) > size.Y / 2 - 3 then
		return false, "Слишком близко к краю"
	end
	if PathUtil.FlatDistance(pos, points[1]) < 14 then
		return false, "Слишком близко к порталу"
	end
	if PathUtil.FlatDistance(pos, points[#points]) < 14 then
		return false, "Слишком близко к ядру"
	end
	return true
end

return PathUtil
]======] }
FILES[#FILES + 1] = { "ReplicatedStorage", { "VoidTD", "ModelKit" }, "ModuleScript", [======[
--!nocheck
-- VOID TD :: ModelKit
-- Общий набор деталей для процедурных моделей в угловатом стиле концепта:
-- блоки с фаской и светлым кантом, клинья-шипы, кристаллы-ромбы, наплечники-ступени, рваная ткань, цепи.
-- Используется UnitModels и EnemyModels. Все функции принимают rig (r) первым аргументом.

local Kit = {}

local V = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles
local rad = math.rad
local PI = math.pi

local M = {
	Plastic = Enum.Material.SmoothPlastic,
	Metal = Enum.Material.Metal,
	Neon = Enum.Material.Neon,
	Fabric = Enum.Material.Fabric,
}

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local C = {
	Neon = rgb(180, 80, 255),
	Steel = rgb(110, 110, 128),
}

-- Палитра брони
local A_ = {
	Armor = rgb(34, 32, 42),
	ArmorMid = rgb(52, 50, 64),
	Edge = rgb(122, 118, 138),
	Cloth = rgb(62, 30, 104),
	ClothDark = rgb(36, 17, 62),
}
Kit.Colors = A_

-- Облегчённый режим (подменяется UnitModels) и «дешёвая» фаска для толп врагов
Kit.IsLite = function()
	return false
end
Kit.Cheap = false

local function lite()
	return Kit.IsLite()
end

-- Острый шип из клиньев: flat = 2 клина (плоский коготь/зуб), иначе 4 (крестовой шип)
local function spike(r, limb, base, tip, w, color, mat, flat, thick)
	local dir = tip - base
	local h = dir.Magnitude
	local up = math.abs(dir.Unit.Y) > 0.98 and V(0, 0, 1) or V(0, 1, 0)
	local F = CFrame.lookAt(base, tip, up) * ANG(-PI / 2, 0, 0)
	local t = thick or w * 0.34
	local parts = {}
	local function fin(rot)
		parts[#parts + 1] = r:Wedge(limb, V(t, h, w / 2), F * rot * CF(0, h / 2, -w / 4), color, mat or M.Plastic)
		parts[#parts + 1] = r:Wedge(limb, V(t, h, w / 2), F * rot * CF(0, h / 2, w / 4) * ANG(0, PI, 0), color, mat or M.Plastic)
	end
	fin(CF())
	if not flat and not Kit.Cheap then
		fin(ANG(0, PI / 2, 0))
	end
	return parts
end
Kit.spike = spike

-- Светящаяся трещина из тонких сегментов
local function crack(r, limb, pts, thick, color)
	local parts = {}
	for i = 1, #pts - 1 do
		parts[#parts + 1] = r:Seg(limb, pts[i], pts[i + 1], thick or 0.08, color or C.Neon, M.Neon)
	end
	return parts
end
Kit.crack = crack

-- Кольцо из сегментов в плоскости XY узла cf. skip(i) -> true пропускает сегмент (разлом)
local function ring(r, limb, cf, radius, count, thick, depth, color, mat, skip)
	local parts = {}
	local segLen = 2 * PI * radius / count * 1.06
	for i = 0, count - 1 do
		if not (skip and skip(i)) then
			local a = i / count * PI * 2
			parts[#parts + 1] = r:Box(limb, V(segLen, thick, depth), cf * CF(math.cos(a) * radius, math.sin(a) * radius, 0) * ANG(0, 0, a + PI / 2), color, mat or M.Metal)
		end
	end
	return parts
end
Kit.ring = ring

local function hide(parts, target)
	for _, p in ipairs(parts) do
		p:SetAttribute("PT", target or p.Transparency)
		p.Transparency = 1
	end
	return parts
end
Kit.hide = hide

local function join(...)
	local out = {}
	for _, list in ipairs({ ... }) do
		for _, p in ipairs(list) do
			out[#out + 1] = p
		end
	end
	return out
end
Kit.join = join

-- Блок с фаской: три тёмных бруска, «выкусывающие» рёбра, и светлый брусок внутри —
-- по всем 12 рёбрам видна тонкая светлая линия, как на концепте. В облегчённом режиме — один брусок.
local function bevel(r, limb, size, cf, color, edge, mat, e)
	mat = mat or M.Metal
	if lite() or edge == false then
		return { r:Box(limb, size, cf, color, mat) }
	end
	local x, y, z = size.X, size.Y, size.Z
	e = e or math.min(0.09, math.min(x, y, z) * 0.2)
	if Kit.Cheap then
		-- тёмный блок + светлый кант по верхним рёбрам
		return {
			r:Box(limb, size, cf, color, mat),
			r:Box(limb, V(x + 0.03, e, z + 0.03), cf * CF(0, y / 2 - e * 0.62, 0), edge or A_.Edge, mat),
		}
	end
	return {
		r:Box(limb, V(x, y - 2 * e, z - 2 * e), cf, color, mat),
		r:Box(limb, V(x - 2 * e, y, z - 2 * e), cf, color, mat),
		r:Box(limb, V(x - 2 * e, y - 2 * e, z), cf, color, mat),
		r:Box(limb, V(x - e, y - e, z - e), cf, edge or A_.Edge, mat),
	}
end
Kit.bevel = bevel

-- Брусок между двумя точками с запасом на стыках (угловатые кости, рога, лапы)
local function bar(r, limb, a, b, t, color, mat)
	local d = (b - a).Unit
	local tt = typeof(t) == "Vector2" and math.min(t.X, t.Y) or t
	return r:Seg(limb, a - d * tt * 0.4, b + d * tt * 0.4, t, color, mat or M.Plastic)
end
Kit.bar = bar

-- Угловатый рог: сужающиеся бруски + острый кончик
local function hornA(r, limb, pts, t0, color, mat)
	local parts = {}
	local t = t0
	for i = 1, #pts - 2 do
		parts[#parts + 1] = bar(r, limb, pts[i], pts[i + 1], t, color, mat)
		t = t * 0.78
	end
	for _, p in ipairs(spike(r, limb, pts[#pts - 1], pts[#pts], t * 1.15, color, mat)) do
		parts[#parts + 1] = p
	end
	return parts
end
Kit.hornA = hornA

-- Кристалл-ромб в оправе (самоцвет на груди, пряжке, наплечнике)
local function gem(r, limb, s, cf, color, frame)
	local parts = {}
	if frame then
		parts[#parts + 1] = r:Box(limb, V(s * 1.3, s * 1.3, 0.12), cf * CF(0, 0, 0.04) * ANG(0, 0, rad(45)), frame, M.Metal)
	end
	parts[#parts + 1] = r:Neon(limb, V(s, s, 0.14), cf * ANG(0, 0, rad(45)), color or C.Neon)
	return parts
end
Kit.gem = gem

-- Рваный край: треугольные лоскуты вниз вдоль ширины w
local function tatter(r, limb, y, z, w, n, color, mat, seed)
	if lite() then
		return
	end
	for i = 0, n - 1 do
		local x = -w / 2 + (i + 0.5) * w / n
		local h = 0.3 + (((i + (seed or 0)) * 37) % 5) * 0.12
		spike(r, limb, V(x, y, z), V(x + 0.05, y - h, z), w / n * 1.05, color, mat or M.Fabric, true, 0.08)
	end
end
Kit.tatter = tatter

-- Угловатый наплечник: три пластины-ступени с фаской, шипы, самоцвет (side: 1 — правый, -1 — левый)
local function pauldron(r, A, side, s, color, edge, glow, spikes)
	local parts = {}
	local function add(list)
		for _, p in ipairs(list) do
			parts[#parts + 1] = p
		end
	end
	-- верхняя пластина над плечом
	add(bevel(r, A, V(1.55, 0.5, 1.5) * s, CF(0.18 * side, 1.08, 0) * ANG(0, 0, rad(-14 * side)), color, edge))
	-- две пластины-ступени под ней
	add(bevel(r, A, V(1.3, 0.32, 1.38) * s, CF(0.42 * side, 0.74, 0) * ANG(0, 0, rad(-26 * side)), A_.ArmorMid, edge))
	add(bevel(r, A, V(1.15, 0.3, 1.28) * s, CF(0.55 * side, 0.46, 0) * ANG(0, 0, rad(-34 * side)), color, edge))
	-- боковой щиток, закрывающий плечо снаружи
	add(bevel(r, A, V(0.3, 1.05, 1.42) * s, CF(0.82 * side * s, 0.62, 0) * ANG(0, 0, rad(-10 * side)), color, edge))
	-- передний клин-козырёк
	parts[#parts + 1] = r:Wedge(A, V(1.2 * s, 0.4 * s, 0.45 * s), CF(0.22 * side, 1.12, -0.92 * s) * ANG(0, PI, 0) * ANG(0, 0, rad(14 * side)), color, M.Metal)
	if glow then
		add(gem(r, A, 0.34 * s, CF(0.99 * side * s, 0.62, 0) * ANG(0, -side * PI / 2, 0) * ANG(0, 0, rad(10 * side)), glow, edge))
	end
	local n = spikes or 2
	for k = 1, n do
		local z = n == 1 and 0 or (-0.45 + (k - 1) * 0.9 / (n - 1))
		add(spike(r, A, V(0.4 * side, 1.3, z * s), V((0.85 + 0.1 * k) * side, 2.05 - 0.12 * k, z * 1.3 * s), 0.4 * s, color, M.Metal))
	end
	return parts
end
Kit.pauldron = pauldron

-- Латный сапог: блок + клиновидный носок
local function bootA(r, L, color, edge, w)
	w = w or 1.15
	bevel(r, L, V(w, 0.5, 1.25), CF(0, -0.75, -0.08), color, edge)
	r:Wedge(L, V(w * 0.9, 0.4, 0.55), CF(0, -0.8, -0.95), color, M.Metal)
end
Kit.bootA = bootA

-- Квадратное кольцо из 4 брусков (цепь на руке, обод)
local function squareRing(r, limb, cf, w, t, color)
	for i = 0, 3 do
		r:Box(limb, V(w, t, t), cf * ANG(0, i * PI / 2, 0) * CF(0, 0, -w / 2 + t / 2), color, M.Metal)
	end
end
Kit.squareRing = squareRing

-- Цепь из звеньев на моторе
local function chain(r, limb, n, size, color, at)
	at = at or CF()
	for i = 0, n - 1 do
		local cf = at * CF(0, -i * size * 1.1, 0) * ANG(0, i % 2 == 0 and 0 or PI / 2, 0)
		r:Box(limb, V(size * 0.18, size * 1.2, size * 0.7), cf, color or C.Steel, M.Metal)
		r:Box(limb, V(size * 0.18, size * 0.18, size * 0.7), cf * CF(0, size * 0.5, 0), color or C.Steel, M.Metal)
	end
end
Kit.chain = chain

-- Приглушает неон: светящиеся детали темнее, подсветка и частицы слабее (меньше «кислотности»)
local CALM_DARK = Color3.fromRGB(14, 10, 22)
function Kit.Calm(root, amount)
	amount = amount or 0.3
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("BasePart") and d.Material == Enum.Material.Neon then
			d.Color = d.Color:Lerp(CALM_DARK, amount)
		elseif d:IsA("PointLight") then
			d.Brightness = d.Brightness * 0.65
		elseif d:IsA("ParticleEmitter") then
			d.LightEmission = d.LightEmission * 0.6
		end
	end
end

return Kit
]======] }
FILES[#FILES + 1] = { "ReplicatedStorage", { "VoidTD", "HalloweenModels" }, "ModuleScript", [======[
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
]======] }
FILES[#FILES + 1] = { "ReplicatedStorage", { "VoidTD", "UnitModels" }, "ModuleScript", [======[
--!nocheck
-- VOID TD :: UnitModels
-- Процедурные модели юнитов в стиле Roblox R6. Без внешних ассетов.
-- UnitModels.Build(unitId, level) -> rig { Model, Motors, Base, Idle, Muzzle, ... }

local UnitModels = {}
-- Облегчённый режим: без мелких деталей, частиц, подсветки и шлейфов (меняется на клиенте)
UnitModels.Lite = false

-- общий набор угловатых деталей (фаска, шипы, ромбы, наплечники) — см. ModelKit
local Kit = require(script.Parent.ModelKit)
Kit.IsLite = function()
	return UnitModels.Lite
end
UnitModels.Kit = Kit

local V = Vector3.new
local V2 = Vector2.new
local CF = CFrame.new
local ANG = CFrame.Angles
local rad = math.rad

local M = {
	Plastic = Enum.Material.SmoothPlastic,
	Metal = Enum.Material.Metal,
	Neon = Enum.Material.Neon,
	Fabric = Enum.Material.Fabric,
	Slate = Enum.Material.Slate,
	Glass = Enum.Material.Glass,
	Wood = Enum.Material.Wood,
}

local P = {
	Black = Color3.fromRGB(20, 18, 26),
	Coal = Color3.fromRGB(33, 30, 41),
	Dark = Color3.fromRGB(48, 44, 58),
	Steel = Color3.fromRGB(74, 72, 86),
	Gray = Color3.fromRGB(108, 106, 120),
	Pale = Color3.fromRGB(168, 163, 180),
	Violet = Color3.fromRGB(70, 30, 110),
	DeepViolet = Color3.fromRGB(42, 18, 66),
	Purple = Color3.fromRGB(112, 52, 172),
	Neon = Color3.fromRGB(180, 80, 255),
	NeonSoft = Color3.fromRGB(210, 150, 255),
	NeonPink = Color3.fromRGB(255, 60, 170),
	Maroon = Color3.fromRGB(88, 20, 36),
	Crimson = Color3.fromRGB(140, 28, 48),
	White = Color3.fromRGB(245, 240, 255),
	Gold = Color3.fromRGB(200, 156, 60),
	DarkGold = Color3.fromRGB(140, 104, 40),
	Skin = Color3.fromRGB(140, 132, 146),
}
UnitModels.Palette = P

------------------------------------------------------------------------
-- RIG
------------------------------------------------------------------------
local Rig = {}
Rig.__index = Rig

local function basePart(className, size, color, material)
	local p = Instance.new(className)
	p.Size = size
	p.Color = color
	p.Material = material or M.Plastic
	p.Anchored = false
	p.CanCollide = false
	p.CanTouch = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	return p
end

function Rig.new(o)
	local self = setmetatable({}, Rig)
	local model = Instance.new("Model")
	model.Name = o.Name or "Unit"
	self.Model = model
	self.Motors = {}
	self.Base = {}

	local root = basePart("Part", V(2, 2, 1), Color3.new(), nil)
	root.Name = "HumanoidRootPart"
	root.Transparency = 1
	root.Anchored = true
	root.CFrame = CF()
	root.Parent = model
	self.Root = root

	local hs = o.HeadSize or V(1.3, 1.3, 1.3)
	self.HeadSize = hs

	local function limb(name, size, cf, color, mat)
		local p = basePart("Part", size, color, mat)
		p.Name = name
		p.CFrame = cf
		p.Parent = model
		return p
	end

	self.Torso = limb("Torso", V(2, 2, 1), CF(), o.Torso or P.Dark, o.TorsoMat)
	self.Head = limb("Head", hs, CF(0, 1 + hs.Y / 2, 0), o.Head or P.Skin)
	self.RArm = limb("Right Arm", V(1, 2, 1), CF(1.5, 0, 0), o.Arm or o.Torso or P.Dark)
	self.LArm = limb("Left Arm", V(1, 2, 1), CF(-1.5, 0, 0), o.Arm or o.Torso or P.Dark)
	self.RLeg = limb("Right Leg", V(1, 2, 1), CF(0.5, -2, 0), o.Leg or P.Black)
	self.LLeg = limb("Left Leg", V(1, 2, 1), CF(-0.5, -2, 0), o.Leg or P.Black)
	self.Pending = {}
	self.PendingTrails = {}

	local function motor(name, p0, p1, c0, c1)
		local m = Instance.new("Motor6D")
		m.Name = name
		m.Part0 = p0
		m.Part1 = p1
		m.C0 = c0
		m.C1 = c1
		m.Parent = p0
		self.Motors[name] = m
	end
	motor("Root", root, self.Torso, CF(), CF())
	motor("Neck", self.Torso, self.Head, CF(0, 1, 0), CF(0, -hs.Y / 2, 0))
	motor("RS", self.Torso, self.RArm, CF(1.5, 0.5, 0), CF(0, 0.5, 0))
	motor("LS", self.Torso, self.LArm, CF(-1.5, 0.5, 0), CF(0, 0.5, 0))
	motor("RH", self.Torso, self.RLeg, CF(0.5, -1, 0), CF(0, 1, 0))
	motor("LH", self.Torso, self.LLeg, CF(-0.5, -1, 0), CF(0, 1, 0))
	if o.RoundHead then
		-- круглая голова-цилиндр в стиле классического Roblox; детали крепятся к невидимому кубу Head
		self.Head.Transparency = 1
		self:Cyl(self.Head, hs.Y, math.max(hs.X, hs.Z), CF(), o.Head or P.Skin, M.Plastic, "Y").Name = "HeadShape"
	end
	return self
end

-- Деталь, приваренная к части тела. offset задаётся в локальных координатах limb.
function Rig:Add(limb, className, size, offset, color, material, props)
	local p = basePart(className, size, color, material)
	p.Name = "Detail"
	if props then
		for k, v in pairs(props) do
			p[k] = v
		end
	end
	p.CFrame = limb.CFrame * offset
	local w = Instance.new("Weld")
	w.Part0 = limb
	w.Part1 = p
	w.C0 = offset
	w.Parent = p
	p.Parent = self.Model
	return p
end

function Rig:Box(limb, size, offset, color, material, props)
	return self:Add(limb, "Part", size, offset, color, material, props)
end

local AXIS = {
	X = CF(),
	Y = ANG(0, 0, rad(90)),
	Z = ANG(0, rad(90), 0),
}

-- Цилиндр: длина len вдоль оси axis ("X" | "Y" | "Z"), диаметр d
function Rig:Cyl(limb, len, d, offset, color, material, axis, props)
	props = props or {}
	props.Shape = Enum.PartType.Cylinder
	return self:Add(limb, "Part", V(len, d, d), offset * AXIS[axis or "X"], color, material, props)
end

-- Эллипсоид (купол наплечника, круглое тело). Меш создаётся в Finish после масштабирования.
function Rig:Sphere(limb, size, offset, color, material, props)
	local p = self:Add(limb, "Part", size, offset, color, material, props)
	table.insert(self.Pending, p)
	return p
end

-- Круглый наплечник: купол-эллипсоид + обод
function Rig:Pauldron(limb, side, size, color, rim, lift, rimMat)
	size = size or 1
	local off = CF(0.12 * side, 0.82 + (lift or 0), 0) * ANG(0, 0, rad(-14 * side))
	self:Sphere(limb, V(1.55, 1.0, 1.5) * size, off, color or P.Black, M.Metal)
	if rim then
		self:Cyl(limb, 0.16, 1.6 * size, off * CF(0, -0.18 * size, 0), rim, rimMat or M.Metal, "Y")
	end
end

function Rig:Wedge(limb, size, offset, color, material, props)
	return self:Add(limb, "WedgePart", size, offset, color, material, props)
end

function Rig:Ball(limb, d, offset, color, material, props)
	props = props or {}
	props.Shape = Enum.PartType.Ball
	return self:Add(limb, "Part", V(d, d, d), offset, color, material, props)
end

function Rig:Neon(limb, size, offset, color, props)
	return self:Add(limb, "Part", size, offset, color or P.Neon, M.Neon, props)
end

-- Брусок между двумя точками (в координатах limb)
function Rig:Seg(limb, a, b, thick, color, material, props)
	local dir = b - a
	local len = dir.Magnitude
	local up = V(0, 1, 0)
	if math.abs(dir.Unit.Y) > 0.98 then
		up = V(0, 0, 1)
	end
	local cf = CFrame.lookAt((a + b) / 2, b, up)
	local tx, ty = thick, thick
	if typeof(thick) == "Vector2" then
		tx, ty = thick.X, thick.Y
	end
	if props and props.Round then
		props.Round = nil
		props.Shape = Enum.PartType.Cylinder
		return self:Add(limb, "Part", V(len, tx, tx), cf * AXIS.Z, color, material, props)
	end
	return self:Add(limb, "Part", V(tx, ty, len), cf, color, material, props)
end

-- Круглый стержень между точками (древки, рога, щупальца)
function Rig:Rod(limb, a, b, d, color, material, props)
	props = props or {}
	props.Round = true
	return self:Seg(limb, a, b, d, color, material, props)
end

-- Цепочка брусков (рога, щупальца, изогнутые лезвия)
function Rig:Chain(limb, points, thick, color, material, taper, round)
	local parts = {}
	local t = thick
	for i = 1, #points - 1 do
		parts[#parts + 1] = self:Seg(limb, points[i], points[i + 1], t, color, material, round and { Round = true } or nil)
		if round and i > 1 then
			self:Ball(limb, t * 1.02, CF(points[i]), color, material)
		end
		if taper then
			t = math.max(t * taper, 0.08)
		end
	end
	return parts
end

-- Подвижная часть на собственном Motor6D (крылья, челюсти)
function Rig:Joint(name, limb, size, pivot, fromPivot, color, material)
	local p = basePart("Part", size, color, material)
	p.Name = name
	p.CFrame = limb.CFrame * pivot * fromPivot
	p.Parent = self.Model
	local m = Instance.new("Motor6D")
	m.Name = name
	m.Part0 = limb
	m.Part1 = p
	m.C0 = pivot
	m.C1 = fromPivot:Inverse()
	m.Parent = limb
	self.Motors[name] = m
	return p
end

function Rig:Eyes(color, o)
	o = o or {}
	local hs = self.HeadSize
	local y = o.Y or 0.08
	local sp = o.Spacing or 0.3
	local size = o.Size or V(0.28, 0.14, 0.06)
	local z = -hs.Z / 2 - 0.02 + (o.Inset or 0)
	local l = self:Neon(self.Head, size, CF(-sp, y + (o.LeftLift or 0), z) * ANG(0, 0, rad(o.Tilt or 0)), color)
	local r = self:Neon(self.Head, o.RightSize or size, CF(sp, y, z) * ANG(0, 0, rad(-(o.Tilt or 0))), color)
	return l, r
end

function Rig:Glow(part, color, range, brightness)
	if UnitModels.Lite then
		return nil
	end
	local l = Instance.new("PointLight")
	l.Color = color or P.Neon
	l.Range = range or 8
	l.Brightness = brightness or 1.5
	l.Shadows = false
	l.Parent = part
	return l
end

function Rig:Sparkles(part, color, o)
	if UnitModels.Lite then
		return nil
	end
	o = o or {}
	local e = Instance.new("ParticleEmitter")
	e.Name = "Sparkles"
	e.Color = ColorSequence.new(color or P.Neon)
	e.LightEmission = 1
	e.LightInfluence = 0
	e.Rate = o.Rate or 8
	e.Lifetime = NumberRange.new(o.LifeMin or 0.5, o.LifeMax or 1)
	e.Speed = NumberRange.new(o.SpeedMin or 0.5, o.SpeedMax or 1.5)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, o.Size or 0.25),
		NumberSequenceKeypoint.new(1, 0),
	})
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	if o.Up then
		e.EmissionDirection = Enum.NormalId.Top
		e.SpreadAngle = Vector2.new(25, 25)
		e.Acceleration = V(0, o.Up, 0)
	end
	e.Parent = part
	return e
end

-- Меч в руке. Клинок направлен вперёд (-Z локально руки), ширина по Y.
function Rig:Sword(limb, o)
	o = o or {}
	local len = o.Length or 3
	local w = o.Width or 0.42
	local y = o.Y or -1.05
	self:Cyl(limb, 0.9, 0.26, CF(0, y, 0.05), o.Handle or P.Black, M.Fabric, "Z")
	self:Ball(limb, 0.4, CF(0, y, 0.55), o.Pommel or o.Guard or P.Steel, M.Metal)
	local gw = o.GuardWidth or w + 0.6
	self:Box(limb, V(0.3, gw, 0.26), CF(0, y, -0.45), o.Guard or P.Steel, M.Metal)
	self:Ball(limb, 0.34, CF(0, y + gw / 2, -0.45), o.Guard or P.Steel, M.Metal)
	self:Ball(limb, 0.34, CF(0, y - gw / 2, -0.45), o.Guard or P.Steel, M.Metal)
	self:Ball(limb, 0.34, CF(0, y, -0.45), o.Gem or o.Edge or P.Neon, M.Neon) -- камень в гарде
	local blade = self:Box(limb, V(0.14, w, len), CF(0, y, -0.58 - len / 2), o.Blade or P.Gray, o.BladeMat or M.Metal)
	blade.Name = "Blade"
	if not o.Core then
		self:Box(limb, V(0.16, math.max(w * 0.22, 0.07), len * 0.72), CF(0, y, -0.58 - len * 0.42), P.Black, M.Metal) -- желобок
	end
	for i = 1, (o.Runes or 0) do
		self:Neon(limb, V(0.17, 0.1, 0.18), CF(0, y - w * 0.22, -0.58 - len * (0.15 + i * 0.16)), o.Edge or P.Neon)
	end
	self:WeaponTrail(limb, V(0, y, -0.75), V(0, y, -0.58 - len), o.Edge or o.Core or P.NeonSoft)
	self:Wedge(limb, V(0.14, w, w * 1.3), CF(0, y, -0.58 - len - w * 0.65) * ANG(0, math.pi, 0), o.Blade or P.Gray, o.BladeMat or M.Metal)
	if o.Edge then
		self:Neon(limb, V(0.16, 0.09, len), CF(0, y + w / 2 - 0.02, -0.58 - len / 2), o.Edge)
	end
	if o.Core then
		self:Neon(limb, V(0.17, math.max(w * 0.25, 0.08), len * 0.8), CF(0, y, -0.58 - len * 0.45), o.Core)
	end
	local tip = self:Box(limb, V(0.2, 0.2, 0.2), CF(0, y, -0.58 - len), P.Black, M.Plastic, { Transparency = 1, Name = "Muzzle" })
	self.Muzzle = tip
	return blade
end

-- Светящийся шлейф оружия (включается Renderer'ом во время анимаций)
function Rig:WeaponTrail(limb, a, b, color)
	if UnitModels.Lite then
		return
	end
	table.insert(self.PendingTrails, { limb, a, b, color or P.NeonSoft })
end

-- Лицо: брови и рот. mood: "angry" | "calm" | "old"
function Rig:Face(o)
	if UnitModels.Lite then
		return
	end
	local hs = self.HeadSize
	local z = -hs.Z / 2 - 0.03
	local y = (o.EyeY or 0.08) + 0.2
	local sp = o.Spacing or 0.3
	local tilt = o.Mood == "angry" and 18 or (o.Mood == "old" and -10 or 4)
	local size = o.Mood == "old" and V(0.36, 0.13, 0.08) or V(0.3, 0.08, 0.06)
	self:Box(self.Head, size, CF(-sp, y, z) * ANG(0, 0, rad(-tilt)), o.BrowColor or P.Black)
	self:Box(self.Head, size, CF(sp, y, z) * ANG(0, 0, rad(tilt)), o.BrowColor or P.Black)
	if o.Mouth ~= false then
		self:Box(self.Head, V(o.Mood == "angry" and 0.4 or 0.3, 0.07, 0.06), CF(0, -0.32, z), o.MouthColor or P.Coal)
	end
end

-- Округлые кисти рук
function Rig:Hands(color, material)
	if UnitModels.Lite then
		return
	end
	for _, A in ipairs({ self.RArm, self.LArm }) do
		self:Sphere(A, V(1.08, 0.52, 1.08), CF(0, -0.93, 0), color or P.Coal, material or M.Plastic)
	end
end

function Rig:Horn(limb, side, base, size, color)
	local s = size or 1
	local pts = {
		base,
		base + V(0.35 * side, 0.45, 0.05) * s,
		base + V(0.55 * side, 0.95, 0.2) * s,
		base + V(0.45 * side, 1.4, 0.45) * s,
	}
	self:Ball(limb, 0.4 * s, CF(base), color or P.Black)
	self:Chain(limb, pts, 0.34 * s, color or P.Black, M.Plastic, 0.72, true)
	local d = pts[4] - pts[3]
	self:Seg(limb, pts[4], pts[4] + d.Unit * 0.35 * s, 0.12 * s, color or P.Black, M.Plastic, { Round = true })
end

-- Плащ на собственном моторе: развевается в анимации
function Rig:Cape(width, length, color, tatter)
	local T = self.Torso
	color = color or P.DeepViolet
	local l1 = length * 0.58
	local l2 = length - l1
	local cape = self:Joint("Cape", T, V(width, l1, 0.12), CF(0, 0.95, 0.58), ANG(rad(7), 0, 0) * CF(0, -l1 / 2, 0.02), color, M.Fabric)
	-- нижняя часть плаща на своём моторе: колышется с запаздыванием
	local cape2 = self:Joint("Cape2", cape, V(width * 0.98, l2, 0.12), CF(0, -l1 / 2, 0), CF(0, -l2 / 2, 0), color, M.Fabric)
	-- застёжки плаща
	self:Box(T, V(0.3, 0.3, 0.2), CF(-0.75, 0.85, 0.55), P.Gold, M.Metal)
	self:Box(T, V(0.3, 0.3, 0.2), CF(0.75, 0.85, 0.55), P.Gold, M.Metal)
	if tatter and not UnitModels.Lite then
		local seed = 0
		for i = -2, 2 do
			seed = seed + 1
			local h = 0.4 + ((seed * 37) % 5) * 0.12
			self:Wedge(cape2, V(width / 5.2, h, 0.12), CF(i * width / 5, -l2 / 2 - h / 2 + 0.02, 0) * ANG(0, 0, math.pi), color, M.Fabric)
		end
		-- кайма
		self:Box(cape, V(width + 0.04, 0.12, 0.14), CF(0, l1 / 2 - 0.25, 0), color:Lerp(P.Black, 0.4), M.Fabric)
		self:Box(cape2, V(width * 0.98 + 0.04, 0.1, 0.14), CF(0, -l2 / 2 + 0.15, 0), color:Lerp(P.White, 0.25), M.Fabric)
	end
	return cape
end

-- Кольцо вращающихся деталей (души, осколки, камни). Крутится в Renderer (моторы "Orbit*").
function Rig:Orbit(name, limb, offset, radius, count, size, color, material, transparency)
	local hub = self:Joint(name, limb, V(0.2, 0.2, 0.2), offset, CF(), P.Black)
	hub.Transparency = 1
	for i = 0, count - 1 do
		local a = i / count * math.pi * 2
		self:Add(hub, "Part", V(size, size * 1.3, size), CF(math.cos(a) * radius, math.sin(a * 2) * 0.15, math.sin(a) * radius) * ANG(rad(45), a, rad(30)),
			color or P.Neon, material or M.Neon, { Transparency = transparency or 0 })
	end
	return hub
end

function Rig:Pouch(limb, offset, color)
	color = color or P.Maroon
	self:Box(limb, V(0.42, 0.42, 0.28), offset, color, M.Fabric)
	self:Box(limb, V(0.44, 0.14, 0.3), offset * CF(0, 0.2, -0.01), color:Lerp(P.Black, 0.35), M.Fabric)
end

-- Поворачивает конечности в позу idle прямо в CFrame деталей: статичные превью (ViewportFrame)
-- и призрак размещения выглядят так же, как анимированная модель в игре.
function Rig:BakePose(pose)
	local attached = {}
	local limbMotors = { Root = true, Neck = true, RS = true, LS = true, RH = true, LH = true }
	for _, d in ipairs(self.Model:GetDescendants()) do
		if (d:IsA("Weld") or (d:IsA("Motor6D") and not limbMotors[d.Name])) and d.Part0 and d.Part1 then
			attached[d.Part0] = attached[d.Part0] or {}
			table.insert(attached[d.Part0], d.Part1)
		end
	end
	for name, ang in pairs(pose) do
		local m = self.Motors[name]
		if m and name ~= "Root" then
			local rot = ANG(rad(ang[1]), rad(ang[2]), rad(ang[3]))
			local limb = m.Part1
			local delta = (m.Part0.CFrame * m.C0 * rot * m.C1:Inverse()) * limb.CFrame:Inverse()
			local function move(p)
				p.CFrame = delta * p.CFrame
				for _, c in ipairs(attached[p] or {}) do
					move(c)
				end
			end
			move(limb)
			m.C0 = m.C0 * rot
		end
	end
end

function Rig:Finish(scale, idle)
	local model = self.Model
	model.PrimaryPart = self.Root
	scale = scale or 1
	if scale ~= 1 then
		model:ScaleTo(scale)
	end
	-- эллипсоиды: меш добавляем после ScaleTo, чтобы масштаб не применился дважды
	for _, p in ipairs(self.Pending or {}) do
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
	end
	self.Pending = {}
	for _, t in ipairs(self.PendingTrails or {}) do
		local limb = t[1]
		local a0 = Instance.new("Attachment")
		a0.Name = "TrailA"
		a0.Position = t[2] * scale
		a0.Parent = limb
		local a1 = Instance.new("Attachment")
		a1.Name = "TrailB"
		a1.Position = t[3] * scale
		a1.Parent = limb
		local trail = Instance.new("Trail")
		trail.Name = "WeaponTrail"
		trail.Attachment0 = a0
		trail.Attachment1 = a1
		trail.Color = ColorSequence.new(t[4])
		trail.LightEmission = 1
		trail.LightInfluence = 0
		trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
		trail.Lifetime = 0.22
		trail.MinLength = 0.05
		trail.Enabled = false
		trail.Parent = limb
	end
	self.PendingTrails = {}
	self.Scale = scale
	for name, m in pairs(self.Motors) do
		self.Base[name] = m.C0
	end
	if idle then
		self:BakePose(idle)
	end
	model:SetAttribute("HipHeight", 3 * scale)
	self.HipHeight = 3 * scale
	self.Idle = idle or {}
	if not self.Muzzle then
		self.Muzzle = self.RArm
	end
	return self
end

UnitModels.Rig = Rig

------------------------------------------------------------------------
-- ОБЩИЕ ЭФФЕКТЫ ПРОКАЧКИ
------------------------------------------------------------------------
local function levelAura(r, lv, color)
	color = color or P.Neon
	if lv >= 4 and r.Muzzle and r.Muzzle:IsA("BasePart") then
		r:Sparkles(r.Muzzle, color, { Rate = 6, Size = 0.25 })
	end
	if lv >= 5 then
		r:Add(r.Torso, "Part", V(0.08, 3.8, 3.8), CF(0, -2.96, 0) * ANG(0, 0, rad(90)), color, M.Neon,
			{ Shape = Enum.PartType.Cylinder, Transparency = 0.78, Name = "AuraRing" })
		r:Sparkles(r.Torso, color, { Rate = 10, Up = 3, Size = 0.3, LifeMin = 0.8, LifeMax = 1.4 })
		r:Glow(r.Torso, color, 10, 1.2)
	end
end


------------------------------------------------------------------------
-- R6-ФИГУРЫ В УГЛОВАТОМ СТИЛЕ (по референсу): тело — блоки R6 с фаской и светлым кантом,
-- поверх — броня, капюшоны, шлемы, плащи и оружие из блоков, клиньев и кристаллов-ромбов.
------------------------------------------------------------------------
local AC = Kit.Colors
local PI = math.pi
local GRIP = -1.05 -- точка хвата в кисти (локально в руке)

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

-- Базовая R6-фигура. pal: Torso, Arm, Leg, Skin, Edge
local function figure(name, pal)
	local r = Rig.new({ Name = name, HeadSize = V(1.2, 1.2, 1.2), Torso = pal.Torso, Arm = pal.Arm or pal.Torso, Leg = pal.Leg or pal.Torso, Head = pal.Skin or pal.Torso })
	for _, L in ipairs({ r.Torso, r.Head, r.RArm, r.LArm, r.RLeg, r.LLeg }) do
		L.Transparency = 1
	end
	local e = pal.Edge or AC.Edge
	Kit.bevel(r, r.Torso, V(2, 2, 1), CF(), pal.Torso, e)
	Kit.bevel(r, r.RArm, V(1, 2, 1), CF(), pal.Arm or pal.Torso, e)
	Kit.bevel(r, r.LArm, V(1, 2, 1), CF(), pal.Arm or pal.Torso, e)
	Kit.bevel(r, r.RLeg, V(1, 2, 1), CF(), pal.Leg or pal.Torso, e)
	Kit.bevel(r, r.LLeg, V(1, 2, 1), CF(), pal.Leg or pal.Torso, e)
	r:Box(r.Head, V(1.2, 1.2, 1.2), CF(), pal.Skin or rgb(70, 62, 80), M.Plastic)
	r.Pal = pal
	return r
end

-- Глаза: светящиеся или тёмные щели
local function eyes(r, color, glow, y)
	for _, s in ipairs({ -1, 1 }) do
		local f = glow and r.Neon or r.Box
		f(r, r.Head, V(0.22, 0.12, 0.05), CF(0.24 * s, y or 0.08, -0.61), color)
	end
end

-- Нагрудник, пояс с пряжкой, набедренники
local function chest(r, color, edge, gemColor)
	Kit.bevel(r, r.Torso, V(2.14, 1.05, 1.16), CF(0, 0.5, 0), color, edge)
	if gemColor then
		Kit.gem(r, r.Torso, 0.36, CF(0, 0.5, -0.62), gemColor, edge)
	end
end

local function belt(r, color, buckle, gemColor)
	Kit.bevel(r, r.Torso, V(2.1, 0.3, 1.12), CF(0, -0.82, 0), color, false, M.Fabric)
	Kit.bevel(r, r.Torso, V(0.42, 0.4, 0.12), CF(0, -0.82, -0.6), buckle, false)
	if gemColor then
		Kit.gem(r, r.Torso, 0.16, CF(0, -0.82, -0.68), gemColor)
	end
end

local function tassets(r, color, edge)
	for _, s in ipairs({ -1, 1 }) do
		Kit.bevel(r, r.Torso, V(0.85, 0.75, 0.2), CF(0.5 * s, -1.32, -0.56) * ANG(rad(-6), 0, 0), color, edge)
	end
end

-- Длинная юбка-мантия с рваным краем (поверх ног)
local function robe(r, color, trim, len)
	len = len or 1.8
	Kit.bevel(r, r.Torso, V(2.12, len, 1.14), CF(0, -1 - len / 2 + 0.1, 0), color, trim, M.Fabric)
	Kit.tatter(r, r.Torso, -1 - len + 0.1, -0.57, 2.1, 5, color, M.Fabric, 3)
	if trim then
		r:Box(r.Torso, V(0.3, len, 0.05), CF(0, -1 - len / 2 + 0.1, -0.58), trim, M.Fabric)
	end
end

-- Накидка на плечи
local function mantle(r, color, edge)
	Kit.bevel(r, r.Torso, V(2.35, 0.4, 1.3), CF(0, 0.88, 0), color, edge, M.Fabric)
	for _, s in ipairs({ -1, 1 }) do
		Kit.bevel(r, s == 1 and r.RArm or r.LArm, V(1.18, 0.7, 1.18), CF(0.05 * s, 0.68, 0), color, edge, M.Fabric)
	end
end

-- Капюшон: тёмное лицо, глаза светятся
local function hood(r, color, edge, eyeColor, peak)
	local H = r.Head
	Kit.bevel(r, H, V(1.44, 0.28, 1.44), CF(0, 0.72, 0.03), color, edge, M.Fabric)
	for _, s in ipairs({ -1, 1 }) do
		Kit.bevel(r, H, V(0.22, 1.32, 1.44), CF(0.72 * s, 0.06, 0.03), color, edge, M.Fabric)
	end
	Kit.bevel(r, H, V(1.44, 1.32, 0.22), CF(0, 0.06, 0.72), color, edge, M.Fabric)
	r:Wedge(H, V(1.44, 0.32, 0.4), CF(0, 0.58, -0.62), color, M.Fabric)
	if peak ~= false then
		Kit.spike(r, H, V(0, 0.8, 0.45), V(0, 1.15, 1.0), 0.7, color, M.Fabric, true, 0.2)
	end
	r:Box(H, V(1.04, 1.02, 0.05), CF(0, -0.02, -0.61), rgb(12, 9, 18), M.Plastic)
	eyes(r, eyeColor, true, 0.06)
end

-- Шлем рыцаря: блок с фаской и Т-визором
local function helm(r, color, edge, visor, crest, tall)
	local H = r.Head
	Kit.bevel(r, H, V(1.32, tall and 1.45 or 1.32, 1.34), CF(0, tall and 0.1 or 0.03, 0), color, edge)
	r:Neon(H, V(0.6, 0.09, 0.05), CF(0, 0.14, -0.68), visor)
	r:Neon(H, V(0.09, 0.42, 0.05), CF(0, -0.08, -0.68), visor)
	if crest then
		Kit.spike(r, H, V(0, 0.6 + (tall and 0.1 or 0), -0.25), V(0, 1.25 + (tall and 0.15 or 0), 0.25), 0.75, crest, M.Metal, true, 0.12)
	end
end

-- Остроконечная шляпа мага/ведьмы из уступов
local function wizardHat(r, color, band, edge)
	local H = r.Head
	Kit.bevel(r, H, V(2.3, 0.14, 2.3), CF(0, 0.64, 0), color, edge, M.Fabric)
	Kit.bevel(r, H, V(1.4, 0.24, 1.4), CF(0, 0.82, 0), band, false, M.Fabric)
	Kit.bevel(r, H, V(1.3, 0.55, 1.3), CF(0, 1.18, 0), color, edge, M.Fabric)
	Kit.bevel(r, H, V(0.95, 0.5, 0.95), CF(0.06, 1.6, 0.08) * ANG(rad(-8), 0, rad(-6)), color, edge, M.Fabric)
	Kit.bevel(r, H, V(0.6, 0.45, 0.6), CF(0.18, 1.98, 0.22) * ANG(rad(-18), 0, rad(-14)), color, edge, M.Fabric)
	Kit.spike(r, H, V(0.26, 2.15, 0.3), V(0.55, 2.55, 0.65), 0.5, color, M.Fabric)
end

-- Корона: четыре планки и зубцы с камнями
local function crown(r, color, gemColor, h)
	local H = r.Head
	h = h or 0.75
	for i = 0, 3 do
		r:Box(H, V(1.42, 0.26, 0.12), CF(0, 0.72, 0) * ANG(0, i * PI / 2, 0) * CF(0, 0, -0.66), color, M.Metal)
	end
	for i = 0, 7 do
		local a = i / 8 * PI * 2
		local p = V(math.sin(a) * 0.66, 0.8, -math.cos(a) * 0.66)
		local hh = (i % 2 == 0) and h or h * 0.6
		Kit.spike(r, H, p, p + V(0, hh, 0), 0.32, color, M.Metal, true, 0.1)
	end
	Kit.gem(r, H, 0.24, CF(0, 0.74, -0.73), gemColor)
end

-- Самурайский кабуто: купол, наплечная юбка-сикоро, маска, рога-кувагата
local function kabuto(r, color, edge, horn, mask)
	local H = r.Head
	Kit.bevel(r, H, V(1.38, 0.62, 1.42), CF(0, 0.5, 0.02), color, edge)
	for i = 0, 1 do
		Kit.bevel(r, H, V(1.62 + i * 0.2, 0.26, 0.26), CF(0, 0.05 - i * 0.26, 0.74 + i * 0.08) * ANG(rad(25), 0, 0), color, edge)
		for _, s in ipairs({ -1, 1 }) do
			Kit.bevel(r, H, V(0.26, 0.26, 1.2 + i * 0.15), CF(s * (0.78 + i * 0.08), 0.05 - i * 0.26, 0.12) * ANG(0, 0, rad(-25 * s)), color, edge)
		end
	end
	r:Box(H, V(0.96, 0.46, 0.08), CF(0, -0.3, -0.63), mask, M.Metal)
	r:Neon(H, V(0.46, 0.05, 0.05), CF(0, -0.36, -0.68), horn)
	for _, s in ipairs({ -1, 1 }) do
		Kit.hornA(r, H, { V(0.2 * s, 0.6, -0.7), V(0.45 * s, 0.95, -0.85), V(0.7 * s, 1.45, -0.8), V(0.75 * s, 1.85, -0.65) }, 0.14, horn, M.Metal)
	end
	eyes(r, horn, true, 0.12)
end

-- Простой наплечник-плита
local function plateShoulders(r, color, edge, s)
	s = s or 1
	for _, side in ipairs({ 1, -1 }) do
		local A = side == 1 and r.RArm or r.LArm
		Kit.bevel(r, A, V(1.3, 0.5, 1.25) * s, CF(0.12 * side, 0.9, 0) * ANG(0, 0, rad(-12 * side)), color, edge)
	end
end

-- Наплечники-ступени (из ModelKit)
local function bigShoulders(r, color, edge, glow, size, spikes)
	Kit.pauldron(r, r.RArm, 1, size or 1, color, edge, glow, spikes or 1)
	Kit.pauldron(r, r.LArm, -1, size or 1, color, edge, glow, spikes or 1)
end

-- Латные наручи и поножи
local function bracers(r, color, edge)
	for _, A in ipairs({ r.RArm, r.LArm }) do
		Kit.bevel(r, A, V(1.14, 0.75, 1.14), CF(0, -0.55, 0), color, edge)
	end
end

local function greaves(r, color, edge, boots)
	for _, L in ipairs({ r.RLeg, r.LLeg }) do
		Kit.bevel(r, L, V(1.12, 0.7, 1.14), CF(0, -0.35, 0), color, edge)
		if boots then
			Kit.bootA(r, L, color, edge, 1.12)
		end
	end
end

-- Крылья из перьев-пластин на моторах WingR/WingL
local function wings(r, color, edge, glow, span)
	span = span or 1
	for _, side in ipairs({ 1, -1 }) do
		local w = r:Joint(side == 1 and "WingR" or "WingL", r.Torso, V(0.3, 0.3, 0.3), CF(0.45 * side, 0.6, 0.6), CF(), color)
		w.Transparency = 1
		local lens = { 2.8, 2.5, 2.1, 1.7, 1.3 }
		for i, L in ipairs(lens) do
			local th = rad(28 + (i - 1) * 24)
			L = L * span
			local c = V(side * math.sin(th) * L / 2, math.cos(th) * L / 2, 0.15 + i * 0.03)
			Kit.bevel(r, w, V(0.5, L, 0.16), CF(c) * ANG(0, 0, -side * th), color, edge, M.Plastic)
			if glow and i <= 2 then
				r:Neon(w, V(0.08, L * 0.8, 0.18), CF(c) * ANG(0, 0, -side * th) * CF(0.2 * side, 0, 0), glow)
			end
		end
	end
end

------------------------------------------------------------------------
-- ОРУЖИЕ (правая рука: клинок вперёд по -Z; древковое — вертикально перед кулаком)
------------------------------------------------------------------------
local function muzzle(r, limb, cf)
	local m = r:Box(limb, V(0.2, 0.2, 0.2), cf, P.Black, M.Plastic, { Transparency = 1, Name = "Muzzle" })
	r.Muzzle = m
	return m
end

local function blade(r, A, o)
	local y = o.Y or GRIP
	local len, w = o.Len or 3, o.W or 0.5
	local z0 = -0.56
	r:Box(A, V(0.22, 0.22, 0.85), CF(0, y, 0.1), o.Grip or AC.ClothDark, M.Fabric)
	r:Box(A, V(0.3, 0.3, 0.25), CF(0, y, 0.6) * ANG(0, 0, rad(45)), o.Guard or AC.Armor, M.Metal)
	Kit.bevel(r, A, V(0.28, o.GuardW or (w + 0.7), 0.28), CF(0, y, -0.42), o.Guard or AC.Armor, o.Edge)
	r:Box(A, V(0.12, w, len), CF(0, y, z0 - len / 2), o.Blade or AC.ArmorMid, M.Metal)
	if o.Glow then
		r:Neon(A, V(0.14, 0.07, len * 0.96), CF(0, y + w / 2 - 0.03, z0 - len / 2), o.Glow)
		r:Neon(A, V(0.14, 0.07, len * 0.96), CF(0, y - w / 2 + 0.03, z0 - len / 2), o.Glow)
	end
	if o.Core then
		r:Neon(A, V(0.14, 0.08, len * 0.7), CF(0, y, z0 - len * 0.42), o.Core)
	end
	Kit.spike(r, A, V(0, y, z0 - len + 0.02), V(0, y, z0 - len - w * 1.2), w, o.Blade or AC.ArmorMid, M.Metal, true, 0.12)
	r:WeaponTrail(A, V(0, y, z0 - 0.15), V(0, y, z0 - len - w), o.Trail or o.Glow or P.NeonSoft)
	return muzzle(r, A, CF(0, y, z0 - len - w))
end

-- Вертикальное древко перед кулаком
local function shaft(r, A, bottom, top, color, d)
	d = d or 0.2
	r:Box(A, V(d, top - bottom, d), CF(0, (top + bottom) / 2, -0.5), color or rgb(44, 32, 30), M.Wood)
	return V(0, top, -0.5)
end

local function staff(r, A, o)
	local top = shaft(r, A, -2.5, o.Top or 2.4, o.Wood, 0.2)
	local c = top + V(0, 0.45, 0)
	for k = 0, 3 do
		local a = k / 4 * PI * 2 + PI / 4
		Kit.spike(r, A, top + V(math.cos(a) * 0.15, -0.1, math.sin(a) * 0.15), c + V(math.cos(a) * 0.35, 0.35, math.sin(a) * 0.35), 0.16, o.Prong or AC.Armor, M.Metal, true, 0.08)
	end
	local g = r:Neon(A, V(0.45, 0.45, 0.45), CF(c) * ANG(rad(45), 0, rad(45)), o.Glow)
	if o.Big then
		r:Box(A, V(0.7, 0.7, 0.7), CF(c) * ANG(rad(45), 0, rad(45)), o.Glow, M.Glass, { Transparency = 0.6 })
	end
	muzzle(r, A, CF(c))
	return g
end

local function scythe(r, A, o)
	local top = shaft(r, A, -2.6, 2.6, o.Wood, 0.2)
	local pts = { top + V(0, -0.05, 0.1), top + V(0, 0.25, -0.8), top + V(0, 0.05, -1.7), top + V(0, -0.4, -2.4) }
	for i = 1, #pts - 1 do
		Kit.bar(r, A, pts[i], pts[i + 1], V2(0.12, 0.42 - i * 0.07), o.Blade or AC.ArmorMid)
		if o.Glow then
			Kit.bar(r, A, pts[i] + V(0, -0.2 + i * 0.03, 0), pts[i + 1] + V(0, -0.17 + i * 0.03, 0), V2(0.14, 0.06), o.Glow, M.Neon)
		end
	end
	Kit.spike(r, A, pts[4], pts[4] + V(0, -0.55, -0.4), 0.26, o.Blade or AC.ArmorMid, M.Metal, true, 0.12)
	r:WeaponTrail(A, top + V(0, 0, -0.8), pts[4], o.Glow or P.NeonSoft)
	return muzzle(r, A, CF(pts[4]))
end

local function spear(r, A, o)
	local top = shaft(r, A, -2.4, o.Top or 2.6, o.Wood, 0.2)
	Kit.bevel(r, A, V(0.34, 0.3, 0.34), CF(top), o.Metal or AC.Armor, o.Edge)
	Kit.spike(r, A, top + V(0, 0.1, 0), top + V(0, 1.1, 0), 0.5, o.Head or AC.ArmorMid, M.Metal)
	if o.Glow then
		r:Neon(A, V(0.08, 0.6, 0.08), CF(top + V(0, 0.45, -0.13)), o.Glow)
	end
	if o.Axe then
		Kit.bevel(r, A, V(0.12, 0.8, 0.7), CF(top + V(0, -0.2, -0.45)), o.Head or AC.ArmorMid, o.Edge)
		Kit.spike(r, A, top + V(0, -0.2, -0.75), top + V(0, -0.2, -1.2), 0.8, o.Head or AC.ArmorMid, M.Metal, true, 0.12)
	end
	if o.Wing then
		for _, s in ipairs({ -1, 1 }) do
			Kit.spike(r, A, top + V(0.1 * s, 0, 0), top + V(0.55 * s, 0.35, 0), 0.22, o.Metal or AC.Armor, M.Metal, true, 0.08)
		end
	end
	r:WeaponTrail(A, top, top + V(0, 1.1, 0), o.Glow or P.NeonSoft)
	return muzzle(r, A, CF(top + V(0, 1.1, 0)))
end

local function hammer(r, A, o)
	local top = shaft(r, A, -2.2, 2.0, o.Wood or AC.Armor, 0.24)
	local c = top + V(0, 0.35, 0)
	Kit.bevel(r, A, V(0.95, 0.95, 1.8), CF(c), o.Head, o.Edge)
	for _, z in ipairs({ -0.65, 0.65 }) do
		Kit.bevel(r, A, V(1.05, 1.05, 0.18), CF(c + V(0, 0, z)), o.Trim or o.Edge, false)
	end
	Kit.gem(r, A, 0.45, CF(c + V(-0.49, 0, 0)) * ANG(0, PI / 2, 0), o.Glow)
	Kit.gem(r, A, 0.45, CF(c + V(0.49, 0, 0)) * ANG(0, -PI / 2, 0), o.Glow)
	Kit.spike(r, A, c + V(0, 0.45, 0), c + V(0, 1.0, 0), 0.4, o.Trim or o.Head, M.Metal)
	r:WeaponTrail(A, top, c + V(0, 0, -0.9), o.Glow)
	return muzzle(r, A, CF(c))
end

local function axe(r, A, o)
	local top = shaft(r, A, -2.2, 2.2, o.Wood, 0.22)
	Kit.bevel(r, A, V(0.14, 1.3, 1.0), CF(top + V(0, -0.35, -0.55)), o.Head, o.Edge)
	Kit.spike(r, A, top + V(0, -0.35, -1.0), top + V(0, -0.35, -1.6), 1.5, o.Head, M.Metal, true, 0.14)
	if o.Glow then
		r:Neon(A, V(0.16, 1.4, 0.08), CF(top + V(0, -0.35, -1.08)), o.Glow)
	end
	Kit.spike(r, A, top, top + V(0, 0.6, 0), 0.3, o.Head, M.Metal)
	r:WeaponTrail(A, top + V(0, -0.35, -0.8), top + V(0, -0.35, -1.6), o.Glow or P.NeonSoft)
	return muzzle(r, A, CF(top + V(0, -0.35, -1.5)))
end

-- Лук в левой руке (вертикально, тетива к стрелку)
local function bow(r, A, o)
	local y = GRIP
	local g = V(0, y, -0.45)
	r:Box(A, V(0.2, 0.5, 0.2), CF(g), o.Grip or AC.ClothDark, M.Fabric)
	local tips = {}
	for _, s in ipairs({ 1, -1 }) do
		local m = g + V(0, 0.9 * s, -0.2)
		local t = g + V(0, 1.75 * s, 0.25)
		Kit.bar(r, A, g, m, V2(0.14, 0.2), o.Wood)
		Kit.bar(r, A, m, t, V2(0.12, 0.16), o.Wood)
		if o.Glow then
			Kit.bar(r, A, g + V(0, 0.1 * s, -0.08), m + V(0, 0, -0.08), V2(0.15, 0.05), o.Glow, M.Neon)
		end
		Kit.spike(r, A, t, t + V(0, 0.3 * s, 0.15), 0.16, o.Tip or o.Wood, M.Metal, true, 0.08)
		tips[#tips + 1] = t
	end
	r:Box(A, V(0.04, (tips[1] - tips[2]).Magnitude, 0.04), CF((tips[1] + tips[2]) / 2), o.String or rgb(220, 210, 230), M.Plastic)
	return muzzle(r, A, CF(g + V(0, 0, -0.2)))
end

local function quiver(r, color, tips)
	Kit.bevel(r, r.Torso, V(0.5, 1.6, 0.5), CF(0.45, 0.2, 0.75) * ANG(0, 0, rad(-25)), color, false, M.Fabric)
	for k = -1, 1 do
		Kit.spike(r, r.Torso, V(0.75 + k * 0.1, 1.05, 0.75 + k * 0.08), V(0.95 + k * 0.1, 1.45, 0.75 + k * 0.08), 0.18, tips, M.Plastic, true, 0.05)
	end
end

-- Оружие для вытянутых вперёд рук: строится вдоль руки (локальная -Y), ствол смотрит вперёд,
-- когда рука поднята (idle RS ~75°). F переводит «вперёд» оружия в «вниз» руки.
local AIM = CF(0, GRIP, 0) * ANG(rad(-90), 0, 0)

local function crossbow(r, A, o)
	local F = AIM
	Kit.bevel(r, A, V(0.32, 0.32, 1.9), F * CF(0, 0, -0.75), o.Stock, o.Edge)
	local f = -1.55
	for _, s in ipairs({ -1, 1 }) do
		Kit.bar(r, A, F * V(0, 0.05, f), F * V(0.6 * s, 0.05, f + 0.15), V2(0.18, 0.14), o.Prong)
		Kit.bar(r, A, F * V(0.6 * s, 0.05, f + 0.15), F * V(1.1 * s, 0.05, f + 0.4), V2(0.14, 0.12), o.Prong)
		Kit.spike(r, A, F * V(1.1 * s, 0.05, f + 0.4), F * V(1.35 * s, 0.05, f + 0.25), 0.2, o.Glow, M.Neon, true, 0.08)
	end
	r:Box(A, V(2.2, 0.03, 0.03), F * CF(0, 0.05, f + 0.4), rgb(200, 220, 255), M.Plastic)
	r:Neon(A, V(0.1, 0.1, 1.2), F * CF(0, 0.22, -1.1), o.Glow)
	Kit.spike(r, A, F * V(0, 0.22, -1.7), F * V(0, 0.22, -2.1), 0.22, o.Glow, M.Neon)
	return muzzle(r, A, F * CF(0, 0.22, -2.1))
end

local function rifle(r, A, o)
	local F = AIM
	Kit.bevel(r, A, V(0.42, 0.55, 1.9), F * CF(0, 0.05, -0.75), o.Body, o.Edge)
	Kit.bevel(r, A, V(0.32, 0.5, 0.75), F * CF(0, -0.05, 0.45), o.Body, o.Edge)
	r:Box(A, V(0.24, 0.24, 1.5), F * CF(0, 0.15, -2.4), o.Barrel or AC.ArmorMid, M.Metal)
	Kit.bevel(r, A, V(0.2, 0.2, 0.8), F * CF(0, 0.45, -0.7), o.Body, o.Edge)
	r:Neon(A, V(0.08, 0.08, 0.08), F * CF(0, 0.45, -1.12), o.Glow)
	for k = 0, 2 do
		r:Neon(A, V(0.32, 0.32, 0.08), F * CF(0, 0.15, -1.9 - k * 0.38), o.Glow)
	end
	r:Box(A, V(0.3, 0.6, 0.2), F * CF(0, -0.45, -0.6), o.Body, M.Metal)
	return muzzle(r, A, F * CF(0, 0.15, -3.2))
end

local function dagger(r, A, glow, len, color)
	return blade(r, A, { Len = len or 1.2, W = 0.32, GuardW = 0.7, Blade = color or AC.ArmorMid, Glow = glow, Guard = AC.Armor })
end

local function shield(r, A, o)
	local x = -0.68
	Kit.bevel(r, A, V(0.24, o.H or 2.0, o.W or 1.4), CF(x, -0.5, -0.1), o.Color, o.Edge)
	Kit.spike(r, A, V(x, -0.5 - (o.H or 2.0) / 2 + 0.02, -0.1), V(x, -0.5 - (o.H or 2.0) / 2 - 0.6, -0.1), o.W or 1.4, o.Color, M.Metal, true, 0.24)
	if o.Rim then
		r:Box(A, V(0.26, (o.H or 2.0) * 0.8, 0.12), CF(x - 0.01, -0.5, -0.1), o.Rim, M.Metal)
		r:Box(A, V(0.26, 0.12, (o.W or 1.4) * 0.8), CF(x - 0.01, -0.3, -0.1), o.Rim, M.Metal)
	end
	if o.Gem then
		Kit.gem(r, A, 0.45, CF(x - 0.14, -0.3, -0.1) * ANG(0, PI / 2, 0), o.Gem, o.Edge)
	end
end

-- Плащ с эмблемой
local function capeWith(r, w, len, color, emblem)
	local cape = r:Cape(w, len, color, true)
	if emblem then
		Kit.gem(r, cape, 0.5, CF(0, 0.1, 0.08) * ANG(0, PI, 0), emblem)
	end
	return cape
end

------------------------------------------------------------------------
-- VOID CASE
------------------------------------------------------------------------
local VOID = P.Neon

local function VoidSoldier(lv)
	local r = figure("VoidSoldier", { Torso = AC.Armor, Arm = AC.Armor, Leg = rgb(28, 26, 34), Edge = AC.Edge })
	chest(r, AC.ArmorMid, AC.Edge, lv >= 3 and VOID or nil)
	belt(r, rgb(40, 30, 38), AC.Edge, lv >= 2 and VOID or nil)
	tassets(r, AC.ArmorMid, AC.Edge)
	helm(r, AC.Armor, AC.Edge, VOID, lv >= 3 and AC.Armor or nil)
	if lv >= 2 then
		plateShoulders(r, AC.ArmorMid, AC.Edge, lv >= 4 and 1.15 or 1)
	end
	bracers(r, AC.ArmorMid, AC.Edge)
	greaves(r, AC.ArmorMid, AC.Edge, true)
	blade(r, r.RArm, { Len = 2.6 + (lv >= 4 and 0.4 or 0), W = 0.45, Blade = lv >= 5 and AC.Cloth or AC.ArmorMid, Glow = lv >= 3 and VOID or nil, Edge = AC.Edge })
	shield(r, r.LArm, { Color = lv >= 3 and AC.Cloth or AC.ArmorMid, Edge = AC.Edge, H = lv >= 3 and 2.2 or 1.7, W = lv >= 3 and 1.5 or 1.25, Rim = lv >= 2 and AC.Edge or nil, Gem = lv >= 3 and VOID or nil })
	if lv >= 4 then
		r:Box(r.Torso, V(0.9, 1.1, 0.06), CF(0, -1.5, -0.6), AC.Cloth, M.Fabric)
		Kit.tatter(r, r.Torso, -2.05, -0.6, 0.9, 3, AC.Cloth, M.Fabric, 2)
	end
	if lv >= 5 then
		for _, s in ipairs({ -1, 1 }) do
			Kit.hornA(r, r.Head, { V(0.6 * s, 0.35, 0), V(0.9 * s, 0.6, 0.05), V(0.95 * s, 1.1, -0.05) }, 0.2, AC.Armor, M.Metal)
		end
		capeWith(r, 1.9, 2.8, AC.ClothDark, VOID)
	end
	levelAura(r, lv)
	return r:Finish(1, { RS = { 15, 0, 0 } })
end

local function ShadowArcher(lv)
	local r = figure("ShadowArcher", { Torso = rgb(30, 26, 36), Arm = rgb(30, 26, 36), Leg = rgb(24, 22, 30), Edge = rgb(90, 84, 104) })
	hood(r, AC.ClothDark, AC.Edge, VOID)
	Kit.bevel(r, r.Torso, V(2.12, 1.2, 1.12), CF(0, 0.35, 0), rgb(40, 32, 44), AC.Edge, M.Fabric)
	Kit.bar(r, r.Torso, V(-0.9, 0.95, -0.58), V(0.9, -0.6, -0.58), V2(0.2, 0.06), rgb(70, 50, 40))
	belt(r, rgb(50, 36, 30), AC.Edge)
	quiver(r, rgb(50, 36, 30), lv >= 3 and VOID or AC.Edge)
	if lv >= 2 then
		Kit.bevel(r, r.LArm, V(1.2, 0.5, 1.2), CF(-0.1, 0.9, 0) * ANG(0, 0, rad(12)), AC.ArmorMid, AC.Edge)
	end
	bracers(r, rgb(50, 36, 30), AC.Edge)
	greaves(r, rgb(34, 30, 40), AC.Edge, true)
	bow(r, r.LArm, { Wood = lv >= 4 and AC.Armor or rgb(56, 40, 34), Glow = lv >= 3 and VOID or nil, Tip = AC.Edge })
	if lv >= 4 then
		capeWith(r, 1.9, 3.0, AC.ClothDark, nil)
	end
	if lv >= 5 then
		r:Box(r.Head, V(1.06, 0.4, 0.08), CF(0, -0.3, -0.64), AC.Armor, M.Metal)
		mantle(r, AC.Cloth, AC.Edge)
	end
	levelAura(r, lv)
	return r:Finish(1, { LS = { 20, 0, 0 } })
end

local function LostMage(lv)
	local r = figure("LostMage", { Torso = AC.ClothDark, Arm = AC.ClothDark, Leg = AC.ClothDark, Skin = rgb(64, 56, 72), Edge = AC.Edge })
	r:Box(r.Head, V(1.04, 1.0, 0.05), CF(0, -0.05, -0.61), rgb(14, 10, 20), M.Plastic)
	eyes(r, VOID, true, 0.05)
	wizardHat(r, lv >= 4 and AC.Cloth or AC.ClothDark, lv >= 3 and rgb(150, 110, 60) or rgb(60, 44, 70), AC.Edge)
	robe(r, AC.ClothDark, lv >= 2 and AC.Cloth or nil, 1.8)
	belt(r, rgb(50, 36, 30), AC.Edge, lv >= 3 and VOID or nil)
	if lv >= 2 then
		mantle(r, AC.Cloth, AC.Edge)
	end
	-- книга на поясе
	Kit.bevel(r, r.Torso, V(0.2, 0.6, 0.5), CF(-1.08, -0.9, -0.1), rgb(70, 40, 30), AC.Edge)
	staff(r, r.RArm, { Glow = VOID, Top = 2.2 + (lv >= 4 and 0.4 or 0), Big = lv >= 4 })
	if lv >= 5 then
		r:Orbit("OrbitStaff", r.Torso, CF(0, 0.4, 0), 2.0, 4, 0.3, P.NeonSoft)
		capeWith(r, 1.9, 2.8, AC.Cloth, VOID)
	end
	levelAura(r, lv)
	return r:Finish(1, { RS = { 10, 0, 0 }, LS = { 8, 0, 0 } })
end

local function DarkGunner(lv)
	local r = figure("DarkGunner", { Torso = rgb(30, 28, 36), Arm = rgb(30, 28, 36), Leg = rgb(26, 24, 30), Edge = rgb(96, 92, 112) })
	-- шлем-кепи с очками
	Kit.bevel(r, r.Head, V(1.3, 0.55, 1.32), CF(0, 0.42, 0.02), AC.ArmorMid, AC.Edge)
	Kit.bevel(r, r.Head, V(1.32, 0.12, 0.5), CF(0, 0.2, -0.82), AC.ArmorMid, AC.Edge)
	r:Box(r.Head, V(1.2, 0.28, 0.08), CF(0, 0.06, -0.62), rgb(14, 10, 20), M.Plastic)
	for _, s in ipairs({ -1, 1 }) do
		r:Neon(r.Head, V(0.34, 0.18, 0.06), CF(0.27 * s, 0.06, -0.66), VOID)
	end
	r:Box(r.Head, V(1.1, 0.4, 0.08), CF(0, -0.32, -0.62), AC.Armor, M.Metal)
	-- бронежилет, подсумки, полы плаща
	chest(r, AC.ArmorMid, AC.Edge, lv >= 3 and VOID or nil)
	for k = -1, 1, 2 do
		Kit.bevel(r, r.Torso, V(0.42, 0.4, 0.2), CF(0.6 * k, -0.35, -0.6), rgb(50, 40, 36), false, M.Fabric)
	end
	belt(r, rgb(46, 36, 32), AC.Edge)
	for _, s in ipairs({ -1, 1 }) do
		Kit.bevel(r, r.Torso, V(0.95, 1.4, 0.18), CF(0.55 * s, -1.55, 0.45), AC.ClothDark, false, M.Fabric)
	end
	if lv >= 2 then
		plateShoulders(r, AC.ArmorMid, AC.Edge)
	end
	bracers(r, AC.ArmorMid, AC.Edge)
	greaves(r, rgb(40, 36, 46), AC.Edge, true)
	rifle(r, r.RArm, { Body = lv >= 4 and AC.Cloth or AC.ArmorMid, Edge = AC.Edge, Glow = VOID, Barrel = AC.Armor })
	if lv >= 4 then
		Kit.bevel(r, r.Torso, V(1.4, 1.3, 0.5), CF(0, 0.2, 0.78), AC.ArmorMid, AC.Edge)
		r:Neon(r.Torso, V(0.9, 0.12, 0.06), CF(0, 0.5, 1.04), VOID)
	end
	if lv >= 5 then
		capeWith(r, 1.8, 2.6, AC.ClothDark, VOID)
	end
	levelAura(r, lv)
	return r:Finish(1.05, { RS = { 75, 0, 0 }, LS = { 70, 0, -25 }, Neck = { 0, 0, 0 } })
end

local function AbyssReaper(lv)
	local cloth = rgb(26, 20, 32)
	local r = figure("AbyssReaper", { Torso = cloth, Arm = cloth, Leg = cloth, Skin = rgb(200, 190, 175), Edge = rgb(80, 70, 96) })
	hood(r, cloth, rgb(80, 70, 96), VOID, true)
	-- костяная маска-череп
	r:Box(r.Head, V(0.9, 0.85, 0.06), CF(0, -0.05, -0.63), rgb(200, 190, 175), M.Plastic)
	for _, s in ipairs({ -1, 1 }) do
		r:Box(r.Head, V(0.24, 0.22, 0.04), CF(0.2 * s, 0.07, -0.66), rgb(10, 8, 14))
		r:Neon(r.Head, V(0.1, 0.1, 0.04), CF(0.2 * s, 0.07, -0.68), VOID)
	end
	for k = -1, 1 do
		r:Box(r.Head, V(0.08, 0.16, 0.04), CF(k * 0.14, -0.35, -0.66), rgb(10, 8, 14))
	end
	robe(r, cloth, rgb(80, 70, 96), 2.0)
	mantle(r, rgb(36, 28, 44), rgb(80, 70, 96))
	belt(r, rgb(40, 30, 38), AC.Edge, VOID)
	if lv >= 2 then
		for _, side in ipairs({ 1, -1 }) do
			local A = side == 1 and r.RArm or r.LArm
			Kit.bevel(r, A, V(1.25, 0.45, 1.2), CF(0.15 * side, 1.12, 0) * ANG(0, 0, rad(-14 * side)), rgb(200, 190, 175), rgb(120, 110, 100), M.Plastic)
			Kit.spike(r, A, V(0.4 * side, 1.3, 0), V(0.8 * side, 1.85, 0), 0.3, rgb(200, 190, 175), M.Plastic, true, 0.1)
		end
	end
	if lv >= 3 then
		Kit.chain(r, r.Torso, 4, 0.26, nil, CF(0.7, -1.0, -0.6))
	end
	scythe(r, r.RArm, { Blade = lv >= 5 and AC.Cloth or AC.ArmorMid, Glow = lv >= 3 and VOID or nil, Wood = rgb(36, 28, 32) })
	if lv >= 4 then
		capeWith(r, 2.0, 3.4, cloth, nil)
	end
	if lv >= 5 then
		r:Orbit("OrbitSouls", r.Torso, CF(0, 0.6, 0), 2.3, 4, 0.32, P.NeonSoft, M.Neon, 0.25)
	end
	levelAura(r, lv)
	return r:Finish(1.15, { RS = { 8, 0, 0 } })
end

local function CorruptedSamurai(lv)
	local red, black, gold = rgb(130, 22, 30), rgb(26, 20, 24), rgb(190, 150, 70)
	local edge = rgb(150, 110, 110)
	local r = figure("CorruptedSamurai", { Torso = black, Arm = black, Leg = black, Edge = edge })
	kabuto(r, black, edge, lv >= 3 and gold or rgb(150, 120, 80), red)
	-- до: пластины-ламели
	for i = 0, 2 do
		Kit.bevel(r, r.Torso, V(2.14, 0.34, 1.16), CF(0, 0.75 - i * 0.36, 0), i % 2 == 0 and red or black, edge)
	end
	belt(r, rgb(60, 30, 30), gold)
	-- кусадзури: юбка из пластин
	for i, x in ipairs({ -0.62, 0, 0.62 }) do
		for k = 0, 1 do
			Kit.bevel(r, r.Torso, V(0.62, 0.36, 0.18), CF(x, -1.2 - k * 0.36, -0.58 - k * 0.04) * ANG(rad(-6), 0, 0), (i + k) % 2 == 0 and red or black, edge)
		end
	end
	-- содэ: наплечники из пластин
	for _, side in ipairs({ 1, -1 }) do
		local A = side == 1 and r.RArm or r.LArm
		for k = 0, lv >= 2 and 2 or 1 do
			Kit.bevel(r, A, V(0.25, 0.38, 1.3), CF(0.62 * side, 0.82 - k * 0.38, 0) * ANG(0, 0, rad(-12 * side)), k % 2 == 0 and red or black, edge)
		end
	end
	bracers(r, red, edge)
	greaves(r, black, edge, true)
	-- катана и ножны
	blade(r, r.RArm, { Len = 3.4 + (lv >= 4 and 0.4 or 0), W = 0.24, GuardW = 0.55, Blade = rgb(180, 180, 195), Glow = lv >= 3 and rgb(255, 50, 60) or nil, Guard = gold, Grip = red })
	Kit.bevel(r, r.Torso, V(0.2, 0.22, 2.6), CF(-0.9, -0.85, -0.2) * ANG(rad(-20), rad(10), 0), black, edge)
	if lv >= 4 then
		capeWith(r, 1.9, 3.0, red, nil)
	end
	if lv >= 5 then
		Kit.crack(r, r.Torso, { V(-0.8, 0.95, -0.59), V(-0.4, 0.5, -0.59), V(-0.6, 0.1, -0.59) }, 0.06, rgb(255, 50, 60))
	end
	levelAura(r, lv, rgb(255, 50, 60))
	return r:Finish(1.1, { RS = { 25, 0, 0 }, LS = { 10, 0, 0 } })
end

local function EclipseGuardian(lv)
	local gold, goldD, white, black = rgb(200, 158, 70), rgb(140, 104, 44), rgb(220, 214, 226), rgb(30, 26, 34)
	local edge = rgb(250, 225, 160)
	local r = figure("EclipseGuardian", { Torso = black, Arm = gold, Leg = black, Edge = edge })
	helm(r, gold, edge, rgb(255, 220, 140), nil, true)
	for _, s in ipairs({ -1, 1 }) do
		-- крылья на шлеме
		for k = 0, 2 do
			Kit.bevel(r, r.Head, V(0.12, 0.7 - k * 0.15, 0.22), CF(0.72 * s, 0.4 + k * 0.25, 0.1 + k * 0.15) * ANG(rad(-30 - k * 10), 0, rad(-20 * s)), gold, edge)
		end
	end
	chest(r, gold, edge, nil)
	-- эмблема затмения: тёмный ромб в золотой оправе
	Kit.gem(r, r.Torso, 0.55, CF(0, 0.5, -0.62), black, gold)
	r:Neon(r.Torso, V(0.15, 0.15, 0.06), CF(0, 0.5, -0.72) * ANG(0, 0, rad(45)), rgb(255, 220, 140))
	belt(r, goldD, gold)
	-- белый табард
	r:Box(r.Torso, V(1.0, 1.5, 0.06), CF(0, -1.6, -0.6), white, M.Fabric)
	Kit.tatter(r, r.Torso, -2.35, -0.6, 1.0, 3, white, M.Fabric, 4)
	bigShoulders(r, gold, edge, lv >= 3 and rgb(255, 220, 140) or nil, lv >= 4 and 1.15 or 1, lv >= 5 and 2 or 1)
	bracers(r, goldD, edge)
	greaves(r, gold, edge, true)
	spear(r, r.RArm, { Top = 2.8, Head = gold, Metal = goldD, Edge = edge, Glow = lv >= 3 and rgb(255, 220, 140) or nil, Axe = lv >= 2, Wing = lv >= 4, Wood = black })
	if lv >= 4 then
		capeWith(r, 2.1, 3.4, white, gold)
	end
	levelAura(r, lv, rgb(255, 210, 110))
	return r:Finish(1.3, { RS = { 30, 0, 0 } })
end

local function FallenAngel(lv)
	local silver, white, edge = rgb(170, 168, 186), rgb(232, 228, 238), rgb(255, 255, 255)
	local r = figure("FallenAngel", { Torso = silver, Arm = silver, Leg = rgb(60, 56, 72), Skin = rgb(226, 214, 208), Edge = edge })
	-- лицо и белые волосы
	eyes(r, VOID, true, 0.06)
	Kit.bevel(r, r.Head, V(1.32, 0.35, 1.34), CF(0, 0.62, 0.02), white, false, M.Plastic)
	Kit.bevel(r, r.Head, V(1.32, 1.1, 0.3), CF(0, 0.1, 0.55), white, false, M.Plastic)
	for _, s in ipairs({ -1, 1 }) do
		Kit.bevel(r, r.Head, V(0.18, 1.0, 0.9), CF(0.62 * s, 0.1, 0.2), white, false, M.Plastic)
		Kit.spike(r, r.Head, V(0.5 * s, -0.4, 0.5), V(0.6 * s, -1.2, 0.65), 0.35, white, M.Plastic, true, 0.12)
	end
	chest(r, white, edge, VOID)
	belt(r, rgb(70, 60, 90), edge, VOID)
	robe(r, rgb(60, 50, 84), white, 1.6)
	bigShoulders(r, white, edge, lv >= 3 and VOID or nil, lv >= 4 and 1.1 or 1, 1)
	bracers(r, white, edge)
	wings(r, lv >= 5 and rgb(200, 190, 230) or white, edge, lv >= 3 and VOID or nil, 0.9 + lv * 0.06)
	staff(r, r.RArm, { Glow = VOID, Prong = white, Wood = silver, Top = 2.6, Big = lv >= 4 })
	if lv >= 5 then
		-- сломанный нимб
		r:Orbit("OrbitHalo", r.Head, CF(0, 1.1, 0.1), 0.85, 6, 0.2, rgb(240, 230, 255))
	end
	levelAura(r, lv)
	return r:Finish(1.25, { RS = { 10, 0, 0 } })
end

local function VoidEmperor(lv)
	local royal, gold, black = rgb(66, 30, 110), rgb(196, 150, 64), rgb(26, 22, 34)
	local edge = rgb(150, 120, 200)
	local r = figure("VoidEmperor", { Torso = black, Arm = royal, Leg = black, Skin = rgb(54, 48, 64), Edge = edge })
	r:Box(r.Head, V(1.04, 0.9, 0.05), CF(0, -0.05, -0.61), rgb(12, 9, 18), M.Plastic)
	eyes(r, VOID, true, 0.04)
	crown(r, gold, VOID, 0.8 + lv * 0.08)
	chest(r, royal, gold, VOID)
	belt(r, rgb(50, 36, 30), gold, VOID)
	robe(r, royal, gold, 1.9)
	bigShoulders(r, black, gold, VOID, 1.1 + (lv >= 4 and 0.1 or 0), lv >= 3 and 2 or 1)
	bracers(r, black, gold)
	capeWith(r, 2.4, 4.0, royal, gold)
	-- скипетр
	staff(r, r.RArm, { Glow = VOID, Prong = gold, Wood = gold, Top = 2.6, Big = true })
	if lv >= 4 then
		r:Orbit("OrbitCrown", r.Head, CF(0, 1.5, 0), 1.4, 5, 0.26, P.NeonSoft)
	end
	levelAura(r, lv)
	return r:Finish(1.4, { RS = { 15, 0, 0 } })
end

local function AbyssOverlord(lv)
	local black, mid, edge = rgb(26, 22, 32), rgb(44, 38, 56), rgb(130, 110, 160)
	local r = figure("AbyssOverlord", { Torso = black, Arm = black, Leg = black, Edge = edge })
	helm(r, black, edge, VOID, nil, true)
	for _, s in ipairs({ -1, 1 }) do
		Kit.hornA(r, r.Head, { V(0.62 * s, 0.35, 0), V(1.1 * s, 0.6, 0.05), V(1.3 * s, 1.2, 0), V(1.1 * s, 1.9 + lv * 0.1, -0.15) }, 0.3, mid, M.Metal)
	end
	chest(r, mid, edge, VOID)
	Kit.crack(r, r.Torso, { V(-0.85, 0.95, -0.59), V(-0.45, 0.45, -0.6), V(-0.7, -0.05, -0.59) }, 0.06)
	Kit.crack(r, r.Torso, { V(0.7, 0.9, -0.59), V(0.85, 0.35, -0.59) }, 0.05)
	belt(r, black, edge, VOID)
	tassets(r, mid, edge)
	bigShoulders(r, black, edge, VOID, 1.2 + (lv >= 4 and 0.1 or 0), lv >= 3 and 3 or 2)
	bracers(r, mid, edge)
	greaves(r, mid, edge, true)
	blade(r, r.RArm, { Len = 4.2 + lv * 0.15, W = 0.85, GuardW = 1.8, Blade = black, Glow = VOID, Core = lv >= 3 and P.NeonSoft or nil, Guard = mid, Edge = edge })
	capeWith(r, 2.3, 3.6, rgb(40, 18, 64), VOID)
	if lv >= 4 then
		r:Orbit("OrbitRocks", r.Torso, CF(0, 0.3, 0), 3.0, lv >= 5 and 6 or 4, 0.5, mid, M.Slate)
	end
	levelAura(r, lv)
	return r:Finish(1.55, { RS = { 12, 0, 8 }, LS = { 12, 0, -8 } })
end

------------------------------------------------------------------------
-- SHATTERED REALITY CASE
------------------------------------------------------------------------
local BLUE, BLUE_SOFT = rgb(90, 150, 255), rgb(170, 210, 255)
local NAVY, NAVY_D = rgb(30, 40, 84), rgb(18, 22, 46)
local SH_EDGE = rgb(110, 130, 176)

local function RiftScout(lv)
	local r = figure("RiftScout", { Torso = NAVY_D, Arm = NAVY_D, Leg = rgb(22, 24, 36), Edge = SH_EDGE })
	hood(r, NAVY, SH_EDGE, BLUE)
	-- шарф
	Kit.bevel(r, r.Torso, V(1.6, 0.35, 1.2), CF(0, 0.92, 0), BLUE:Lerp(NAVY, 0.6), false, M.Fabric)
	Kit.bevel(r, r.Torso, V(1.9, 0.9, 1.1), CF(0, 0.4, 0), rgb(36, 40, 60), SH_EDGE, M.Fabric)
	belt(r, rgb(40, 34, 40), SH_EDGE, lv >= 3 and BLUE or nil)
	if lv >= 2 then
		Kit.bevel(r, r.RArm, V(1.2, 0.45, 1.2), CF(0.1, 0.9, 0) * ANG(0, 0, rad(-12)), NAVY, SH_EDGE)
	end
	bracers(r, NAVY, SH_EDGE)
	greaves(r, NAVY, SH_EDGE, true)
	dagger(r, r.RArm, lv >= 2 and BLUE or nil, 1.2 + (lv >= 4 and 0.3 or 0), BLUE_SOFT:Lerp(AC.ArmorMid, 0.6))
	-- кинжал в левой руке (без Muzzle)
	local A = r.LArm
	r:Box(A, V(0.2, 0.2, 0.7), CF(0, GRIP, 0.05), AC.ClothDark, M.Fabric)
	r:Box(A, V(0.12, 0.3, 1.1), CF(0, GRIP, -0.9), BLUE_SOFT:Lerp(AC.ArmorMid, 0.6), M.Metal)
	if lv >= 2 then
		r:Neon(A, V(0.14, 0.06, 1.05), CF(0, GRIP + 0.12, -0.9), BLUE)
	end
	Kit.spike(r, A, V(0, GRIP, -1.44), V(0, GRIP, -1.85), 0.3, BLUE_SOFT:Lerp(AC.ArmorMid, 0.6), M.Metal, true, 0.12)
	if lv >= 4 then
		capeWith(r, 1.7, 2.6, NAVY, nil)
	end
	if lv >= 5 then
		r:Orbit("OrbitShards", r.Torso, CF(0, 0.3, 0), 1.9, 3, 0.25, BLUE)
	end
	levelAura(r, lv, BLUE)
	return r:Finish(1, { RS = { 25, 0, 10 }, LS = { 25, 0, -10 } })
end

local function CrystalHunter(lv)
	local r = figure("CrystalHunter", { Torso = rgb(26, 26, 36), Arm = rgb(26, 26, 36), Leg = rgb(22, 22, 30), Edge = SH_EDGE })
	helm(r, rgb(30, 32, 46), SH_EDGE, BLUE, nil)
	chest(r, rgb(40, 44, 62), SH_EDGE, BLUE)
	belt(r, rgb(40, 34, 40), SH_EDGE)
	plateShoulders(r, rgb(40, 44, 62), SH_EDGE)
	-- кристаллы на плечах и спине
	for _, side in ipairs({ 1, -1 }) do
		local A = side == 1 and r.RArm or r.LArm
		for k = 0, (lv >= 3 and 2 or 1) do
			Kit.spike(r, A, V(0.3 * side, 1.1, -0.3 + k * 0.4), V((0.65 + k * 0.1) * side, 1.75 + k * 0.1, -0.35 + k * 0.5), 0.3, BLUE, M.Neon)
		end
	end
	if lv >= 2 then
		for k = -1, 1 do
			Kit.spike(r, r.Torso, V(k * 0.5, 0.6, 0.5), V(k * 0.7, 1.4 - math.abs(k) * 0.3, 1.0), 0.35, BLUE, M.Neon)
		end
	end
	bracers(r, rgb(40, 44, 62), SH_EDGE)
	greaves(r, rgb(40, 44, 62), SH_EDGE, true)
	crossbow(r, r.RArm, { Stock = rgb(40, 44, 62), Edge = SH_EDGE, Prong = rgb(30, 32, 46), Glow = BLUE })
	if lv >= 4 then
		capeWith(r, 1.8, 2.8, NAVY, BLUE)
	end
	if lv >= 5 then
		r:Orbit("OrbitCrystals", r.Torso, CF(0, 0.5, 0), 2.0, 4, 0.3, BLUE)
	end
	levelAura(r, lv, BLUE)
	return r:Finish(1, { RS = { 75, 0, 0 }, LS = { 65, 0, -25 } })
end

local function VoidPuppeteer(lv)
	local cloth = rgb(34, 22, 52)
	local r = figure("VoidPuppeteer", { Torso = cloth, Arm = cloth, Leg = cloth, Skin = rgb(220, 214, 226), Edge = AC.Edge })
	hood(r, rgb(46, 28, 72), AC.Edge, VOID, true)
	-- белая маска-улыбка
	r:Box(r.Head, V(0.86, 0.86, 0.06), CF(0, -0.04, -0.64), rgb(226, 220, 232), M.Plastic)
	for _, s in ipairs({ -1, 1 }) do
		r:Neon(r.Head, V(0.18, 0.08, 0.04), CF(0.2 * s, 0.1, -0.68) * ANG(0, 0, rad(-14 * s)), VOID)
	end
	r:Box(r.Head, V(0.4, 0.06, 0.04), CF(0, -0.25, -0.68), rgb(20, 14, 26))
	robe(r, cloth, AC.Edge, 1.8)
	mantle(r, rgb(46, 28, 72), AC.Edge)
	belt(r, rgb(50, 36, 30), AC.Edge, VOID)
	-- сферы-ромбы в руках и нити
	for _, side in ipairs({ 1, -1 }) do
		local A = side == 1 and r.RArm or r.LArm
		r:Neon(A, V(0.45, 0.45, 0.45), CF(0, -1.45, -0.2) * ANG(rad(45), 0, rad(45)), VOID)
		if side == 1 then
			muzzle(r, A, CF(0, -1.45, -0.2))
		end
		for k = -1, 1 do
			r:Neon(A, V(0.03, 1.3, 0.03), CF(k * 0.18, -2.1, -0.2), P.NeonSoft)
		end
	end
	-- куклы на орбите
	local n = lv >= 4 and 3 or 2
	local hub = r:Orbit("OrbitPuppets", r.Torso, CF(0, -0.2, 0), 2.4, 0, 0.2, VOID)
	for i = 0, n - 1 do
		local a = i / n * PI * 2
		local p = V(math.cos(a) * 2.4, 0, math.sin(a) * 2.4)
		r:Box(hub, V(0.5, 0.55, 0.3), CF(p), rgb(120, 90, 70), M.Wood)
		r:Box(hub, V(0.36, 0.36, 0.36), CF(p + V(0, 0.48, 0)), rgb(226, 220, 232), M.Plastic)
		r:Box(hub, V(0.16, 0.45, 0.16), CF(p + V(-0.18, -0.48, 0)), rgb(120, 90, 70), M.Wood)
		r:Box(hub, V(0.16, 0.45, 0.16), CF(p + V(0.18, -0.48, 0)), rgb(120, 90, 70), M.Wood)
		r:Neon(hub, V(0.03, 1.2, 0.03), CF(p + V(0, 1.2, 0)), P.NeonSoft)
	end
	if lv >= 3 then
		capeWith(r, 2.0, 3.2, rgb(46, 28, 72), VOID)
	end
	levelAura(r, lv)
	return r:Finish(1.05, { RS = { 40, 0, 20 }, LS = { 40, 0, -20 } })
end

local function Starbreaker(lv)
	local gold, white, edge = rgb(200, 160, 74), rgb(226, 222, 234), rgb(255, 235, 180)
	local r = figure("Starbreaker", { Torso = white, Arm = gold, Leg = white, Edge = edge })
	helm(r, gold, edge, BLUE, gold, true)
	chest(r, gold, edge, BLUE)
	-- звёздная эмблема
	for k = 0, 3 do
		Kit.spike(r, r.Torso, V(0, 0.5, -0.66), V(0, 0.5, -0.66) + V(math.cos(k * PI / 2), math.sin(k * PI / 2), 0) * 0.45, 0.2, rgb(255, 240, 200), M.Metal, true, 0.06)
	end
	belt(r, rgb(60, 50, 40), gold, BLUE)
	tassets(r, gold, edge)
	bigShoulders(r, white, edge, BLUE, lv >= 4 and 1.2 or 1.05, lv >= 3 and 2 or 1)
	bracers(r, gold, edge)
	greaves(r, gold, edge, true)
	hammer(r, r.RArm, { Head = white, Edge = edge, Trim = gold, Glow = BLUE, Wood = rgb(60, 50, 40) })
	capeWith(r, 2.1, 3.3, NAVY, lv >= 3 and BLUE or nil)
	if lv >= 5 then
		r:Orbit("OrbitStars", r.Head, CF(0, 1.3, 0), 1.6, 5, 0.3, rgb(255, 225, 140))
	end
	levelAura(r, lv, rgb(255, 210, 110))
	return r:Finish(1.3, { RS = { 30, 0, 0 }, LS = { 20, 0, 0 } })
end

local function RiftMonarch(lv)
	local royal, black, edge = rgb(46, 40, 110), rgb(22, 22, 40), rgb(140, 150, 220)
	local r = figure("RiftMonarch", { Torso = black, Arm = royal, Leg = black, Edge = edge })
	helm(r, royal, edge, BLUE, nil, true)
	crown(r, rgb(200, 210, 255), BLUE, 0.6 + lv * 0.06)
	chest(r, royal, edge, BLUE)
	belt(r, black, edge, VOID)
	robe(r, royal, edge, 1.7)
	bigShoulders(r, black, edge, BLUE, 1.2, lv >= 3 and 2 or 1)
	bracers(r, royal, edge)
	capeWith(r, 2.3, 3.8, rgb(36, 30, 90), VOID)
	staff(r, r.RArm, { Glow = BLUE, Prong = edge, Wood = black, Top = 2.6, Big = true })
	-- кольца-порталы за спиной
	for i, color in ipairs({ BLUE, VOID }) do
		if i == 1 or lv >= 3 then
			local radius = 1.0 + i * 0.35
			local hub = r:Orbit("OrbitRift" .. i, r.Torso, CF(0, 0.6, 1.6) * ANG(rad(90), 0, 0), radius, 0, 0.2, color)
			Kit.ring(r, hub, ANG(rad(90), 0, 0), radius, 14, 0.1, 0.1, color, M.Neon, function(k)
				return k % 5 == 4
			end)
		end
	end
	levelAura(r, lv, BLUE)
	return r:Finish(1.4, { RS = { 12, 0, 0 } })
end

local function RealityDestroyer(lv)
	local RED, black, mid, edge = rgb(255, 40, 50), rgb(24, 18, 22), rgb(44, 30, 36), rgb(160, 100, 110)
	local r = figure("RealityDestroyer", { Torso = black, Arm = black, Leg = black, Edge = edge })
	helm(r, black, edge, RED, nil, true)
	for _, s in ipairs({ -1, 1 }) do
		Kit.hornA(r, r.Head, { V(0.6 * s, 0.4, 0), V(1.0 * s, 0.7, 0), V(1.1 * s, 1.3, -0.05), V(0.9 * s, 1.8 + lv * 0.08, -0.2) }, 0.26, mid, M.Metal)
	end
	chest(r, mid, edge, RED)
	Kit.crack(r, r.Torso, { V(-0.85, 0.95, -0.59), V(-0.45, 0.45, -0.6), V(-0.7, -0.05, -0.59) }, 0.06, RED)
	Kit.crack(r, r.Torso, { V(0.7, 0.9, -0.59), V(0.85, 0.35, -0.59) }, 0.05, RED)
	belt(r, black, edge, RED)
	tassets(r, mid, edge)
	bigShoulders(r, black, edge, RED, 1.2 + (lv >= 4 and 0.1 or 0), lv >= 3 and 3 or 2)
	bracers(r, mid, edge)
	greaves(r, mid, edge, true)
	blade(r, r.RArm, { Len = 4.0 + lv * 0.15, W = 0.75, GuardW = 1.7, Blade = black, Glow = RED, Core = lv >= 3 and rgb(255, 150, 150) or nil, Guard = mid, Edge = edge, Trail = RED })
	capeWith(r, 2.3, 3.6, rgb(90, 10, 20), RED)
	if lv >= 4 then
		r:Orbit("OrbitShards", r.Torso, CF(0, 0.6, 0), 2.6, lv >= 5 and 6 or 4, 0.3, RED)
	end
	levelAura(r, lv, RED)
	return r:Finish(1.5, { RS = { 25, 0, 0 } })
end

------------------------------------------------------------------------
-- BLOOD MOON CASE
------------------------------------------------------------------------
local BLOOD, BLOOD_SOFT = rgb(235, 40, 56), rgb(255, 130, 140)
local CRIMSON, CRIMSON_D = rgb(96, 14, 24), rgb(52, 9, 16)
local BL_EDGE = rgb(160, 110, 116)
local BL_DARK = rgb(28, 20, 24)

local function BloodAcolyte(lv)
	local r = figure("BloodAcolyte", { Torso = CRIMSON_D, Arm = CRIMSON_D, Leg = BL_DARK, Edge = BL_EDGE })
	hood(r, CRIMSON, BL_EDGE, BLOOD)
	robe(r, CRIMSON_D, lv >= 3 and CRIMSON or nil, 1.6)
	belt(r, rgb(40, 26, 26), BL_EDGE, lv >= 2 and BLOOD or nil)
	if lv >= 2 then
		mantle(r, CRIMSON, BL_EDGE)
	end
	bracers(r, BL_DARK, BL_EDGE)
	-- глефа с серповидным лезвием
	local top = shaft(r, r.RArm, -2.4, 2.2, rgb(40, 26, 26), 0.2)
	local pts = { top, top + V(0, 0.45, -0.5), top + V(0, 0.3, -1.1), top + V(0, -0.15, -1.4) }
	for i = 1, 3 do
		Kit.bar(r, r.RArm, pts[i], pts[i + 1], V2(0.12, 0.34 - i * 0.06), lv >= 5 and CRIMSON or AC.ArmorMid)
	end
	if lv >= 3 then
		Kit.bar(r, r.RArm, pts[2] + V(0, -0.15, 0), pts[3] + V(0, -0.12, 0), V2(0.14, 0.05), BLOOD, M.Neon)
	end
	Kit.spike(r, r.RArm, top + V(0, 0.1, 0), top + V(0, 0.8, 0), 0.3, AC.ArmorMid, M.Metal)
	r:WeaponTrail(r.RArm, top + V(0, 0.3, -0.5), pts[4], BLOOD)
	muzzle(r, r.RArm, CF(pts[4]))
	if lv >= 4 then
		capeWith(r, 1.9, 3.0, CRIMSON, nil)
	end
	if lv >= 5 then
		r:Orbit("OrbitBlood", r.Torso, CF(0, 0.5, 0), 1.8, 3, 0.3, BLOOD)
	end
	levelAura(r, lv, BLOOD)
	return r:Finish(1, { RS = { 20, 0, 0 } })
end

-- Scarlet Hunter (CrimsonGunslinger): красный охотник с луком
local function CrimsonGunslinger(lv)
	local r = figure("CrimsonGunslinger", { Torso = BL_DARK, Arm = BL_DARK, Leg = BL_DARK, Edge = BL_EDGE })
	hood(r, CRIMSON, BL_EDGE, BLOOD)
	Kit.bevel(r, r.Torso, V(2.12, 1.2, 1.12), CF(0, 0.35, 0), rgb(50, 26, 30), BL_EDGE, M.Fabric)
	Kit.bar(r, r.Torso, V(-0.9, 0.95, -0.58), V(0.9, -0.6, -0.58), V2(0.2, 0.06), rgb(70, 40, 34))
	belt(r, rgb(50, 30, 28), BL_EDGE, lv >= 3 and BLOOD or nil)
	quiver(r, rgb(60, 30, 28), BLOOD)
	mantle(r, CRIMSON, BL_EDGE)
	bracers(r, rgb(60, 30, 28), BL_EDGE)
	greaves(r, BL_DARK, BL_EDGE, true)
	bow(r, r.LArm, { Wood = lv >= 4 and CRIMSON_D or rgb(60, 34, 30), Glow = lv >= 2 and BLOOD or nil, Tip = BL_EDGE })
	if lv >= 4 then
		capeWith(r, 1.9, 3.0, CRIMSON, nil)
	end
	if lv >= 5 then
		r:Box(r.Head, V(1.06, 0.4, 0.08), CF(0, -0.3, -0.64), BL_DARK, M.Metal)
	end
	levelAura(r, lv, BLOOD)
	return r:Finish(1, { LS = { 20, 0, 0 } })
end

-- Crimson Witch (MoonWitch): ведьма в остроконечной шляпе с посохом-полумесяцем
local function MoonWitch(lv)
	local r = figure("MoonWitch", { Torso = CRIMSON_D, Arm = CRIMSON_D, Leg = BL_DARK, Skin = rgb(220, 196, 190), Edge = BL_EDGE })
	eyes(r, BLOOD, true, 0.06)
	-- волосы
	Kit.bevel(r, r.Head, V(1.3, 1.1, 0.3), CF(0, -0.1, 0.52), rgb(30, 18, 22), false, M.Plastic)
	wizardHat(r, BL_DARK, CRIMSON, BL_EDGE)
	robe(r, CRIMSON_D, CRIMSON, 1.8)
	belt(r, rgb(40, 24, 26), BL_EDGE, BLOOD)
	if lv >= 2 then
		mantle(r, CRIMSON, BL_EDGE)
	end
	-- посох с полумесяцем
	local top = shaft(r, r.RArm, -2.4, 2.3, rgb(40, 24, 26), 0.2)
	local c = top + V(0, 0.6, 0)
	for k = 0, 4 do
		local a1, a2 = rad(200 + k * 28), rad(200 + (k + 1) * 28)
		Kit.bar(r, r.RArm, c + V(0, math.sin(a1) * 0.55, math.cos(a1) * 0.55), c + V(0, math.sin(a2) * 0.55, math.cos(a2) * 0.55), V2(0.12, 0.14), BLOOD, M.Neon)
	end
	r:Neon(r.RArm, V(0.3, 0.3, 0.3), CF(c) * ANG(rad(45), 0, rad(45)), BLOOD_SOFT)
	muzzle(r, r.RArm, CF(c))
	if lv >= 4 then
		capeWith(r, 1.9, 3.0, CRIMSON, BLOOD)
	end
	if lv >= 5 then
		r:Orbit("OrbitMoon", r.Torso, CF(0, 1.4, 0), 1.9, 3, 0.3, BLOOD_SOFT)
	end
	levelAura(r, lv, BLOOD)
	return r:Finish(1.05, { RS = { 10, 0, 0 }, LS = { 10, 0, -10 } })
end

-- Blood Paladin (BloodfangWarlord): красная броня, башенный щит, топор
local function BloodfangWarlord(lv)
	local r = figure("BloodfangWarlord", { Torso = BL_DARK, Arm = CRIMSON, Leg = BL_DARK, Edge = BL_EDGE })
	helm(r, CRIMSON, BL_EDGE, BLOOD, BL_DARK, true)
	if lv >= 3 then
		for _, s in ipairs({ -1, 1 }) do
			Kit.hornA(r, r.Head, { V(0.6 * s, 0.45, 0), V(0.9 * s, 0.7, 0), V(0.95 * s, 1.2, -0.1) }, 0.22, BL_DARK, M.Metal)
		end
	end
	chest(r, CRIMSON, BL_EDGE, BLOOD)
	belt(r, rgb(40, 24, 26), BL_EDGE, BLOOD)
	tassets(r, CRIMSON, BL_EDGE)
	bigShoulders(r, CRIMSON, BL_EDGE, lv >= 3 and BLOOD or nil, lv >= 4 and 1.2 or 1.05, lv >= 4 and 2 or 1)
	bracers(r, BL_DARK, BL_EDGE)
	greaves(r, CRIMSON, BL_EDGE, true)
	axe(r, r.RArm, { Head = AC.ArmorMid, Edge = BL_EDGE, Glow = BLOOD, Wood = rgb(40, 24, 26) })
	shield(r, r.LArm, { Color = CRIMSON, Edge = BL_EDGE, H = 2.8, W = 1.7, Rim = BL_DARK, Gem = BLOOD })
	capeWith(r, 2.1, 3.3, CRIMSON_D, lv >= 3 and BLOOD or nil)
	levelAura(r, lv, BLOOD)
	return r:Finish(1.3, { RS = { 30, 0, 0 } })
end

-- Moon Devourer (LunarSeraph): рогатая тёмная броня, парные клинки-полумесяцы, кровавая луна за спиной
local function LunarSeraph(lv)
	local r = figure("LunarSeraph", { Torso = BL_DARK, Arm = BL_DARK, Leg = BL_DARK, Edge = BL_EDGE })
	helm(r, BL_DARK, BL_EDGE, BLOOD, nil, true)
	for _, s in ipairs({ -1, 1 }) do
		Kit.hornA(r, r.Head, { V(0.62 * s, 0.4, 0), V(1.1 * s, 0.75, 0.1), V(1.25 * s, 1.4, 0.05), V(1.0 * s, 2.0 + lv * 0.08, -0.15) }, 0.28, CRIMSON_D, M.Metal)
	end
	chest(r, CRIMSON_D, BL_EDGE, BLOOD)
	Kit.crack(r, r.Torso, { V(-0.8, 0.95, -0.59), V(-0.4, 0.5, -0.6), V(-0.65, 0.05, -0.59) }, 0.05, BLOOD)
	belt(r, BL_DARK, BL_EDGE, BLOOD)
	tassets(r, CRIMSON_D, BL_EDGE)
	bigShoulders(r, BL_DARK, BL_EDGE, BLOOD, 1.2, lv >= 3 and 3 or 2)
	bracers(r, CRIMSON_D, BL_EDGE)
	greaves(r, CRIMSON_D, BL_EDGE, true)
	-- клинки-полумесяцы в обеих руках
	for _, A in ipairs({ r.RArm, r.LArm }) do
		r:Box(A, V(0.22, 0.22, 0.7), CF(0, GRIP, 0.05), BL_DARK, M.Fabric)
		local c = V(0, GRIP, -0.9)
		for k = 0, 4 do
			local a1, a2 = rad(-80 + k * 32), rad(-80 + (k + 1) * 32)
			Kit.bar(r, A, c + V(0, math.sin(a1) * 0.9, -math.cos(a1) * 0.5), c + V(0, math.sin(a2) * 0.9, -math.cos(a2) * 0.5), V2(0.12, 0.2), AC.ArmorMid)
			Kit.bar(r, A, c + V(0, math.sin(a1) * 1.0, -math.cos(a1) * 0.6), c + V(0, math.sin(a2) * 1.0, -math.cos(a2) * 0.6), V2(0.13, 0.05), BLOOD, M.Neon)
		end
	end
	muzzle(r, r.RArm, CF(0, GRIP, -1.5))
	-- кровавая луна за спиной
	local moon = r:Joint("MoonBack", r.Torso, V(0.2, 0.2, 0.2), CF(0, 1.2, 1.2), CF(), BLOOD)
	moon.Transparency = 1
	Kit.ring(r, moon, CF(), 1.5 + lv * 0.08, 16, 0.18, 0.14, BLOOD, M.Neon, function(k)
		return k >= 11
	end)
	capeWith(r, 2.2, 3.5, CRIMSON_D, BLOOD)
	levelAura(r, lv, BLOOD)
	return r:Finish(1.35, { RS = { 10, 0, 0 } })
end

-- Scarlet Eclipse (CrimsonEclipse): капюшон, кольцо затмения за головой, двойная коса-глефа
local function CrimsonEclipse(lv)
	local r = figure("CrimsonEclipse", { Torso = BL_DARK, Arm = BL_DARK, Leg = BL_DARK, Edge = BL_EDGE })
	hood(r, CRIMSON_D, BL_EDGE, BLOOD, true)
	r:Box(r.Head, V(0.9, 0.4, 0.06), CF(0, -0.28, -0.64), BL_DARK, M.Metal)
	chest(r, CRIMSON_D, BL_EDGE, BLOOD)
	belt(r, BL_DARK, BL_EDGE, BLOOD)
	robe(r, BL_DARK, CRIMSON, 2.0)
	bigShoulders(r, CRIMSON_D, BL_EDGE, BLOOD, 1.15, lv >= 3 and 3 or 2)
	bracers(r, CRIMSON_D, BL_EDGE)
	-- кольцо затмения: тёмный круг в кровавом ободе
	local ecl = r:Joint("SpinEclipse", r.Head, V(0.2, 0.2, 0.2), CF(0, 0.3, 0.95), CF(), BLOOD)
	ecl.Transparency = 1
	Kit.ring(r, ecl, CF(), 1.25, 16, 0.2, 0.12, BLOOD, M.Neon)
	r:Box(ecl, V(1.7, 1.7, 0.08), CF(0, 0, 0.06) * ANG(0, 0, rad(45)), rgb(10, 6, 8), M.Plastic)
	-- двойная глефа
	local A = r.RArm
	local top = shaft(r, A, -2.2, 2.2, BL_DARK, 0.2)
	local bottom = V(0, -2.2, -0.5)
	for _, base in ipairs({ top, bottom }) do
		local dir = base.Y > 0 and 1 or -1
		local pts = { base, base + V(0, 0.4 * dir, -0.6), base + V(0, 0.2 * dir, -1.4), base + V(0, -0.3 * dir, -1.9) }
		for i = 1, 3 do
			Kit.bar(r, A, pts[i], pts[i + 1], V2(0.12, 0.4 - i * 0.07), CRIMSON_D)
			Kit.bar(r, A, pts[i] + V(0, -0.15 * dir, 0), pts[i + 1] + V(0, -0.12 * dir, 0), V2(0.14, 0.05), BLOOD, M.Neon)
		end
	end
	r:WeaponTrail(A, top + V(0, 0.3, -0.6), top + V(0, -0.3, -1.9), BLOOD)
	muzzle(r, A, CF(top + V(0, -0.3, -1.9)))
	capeWith(r, 2.2, 3.6, CRIMSON_D, BLOOD)
	if lv >= 4 then
		r:Orbit("OrbitBlood", r.Torso, CF(0, 0.5, 0), 2.4, lv >= 5 and 6 or 4, 0.3, BLOOD)
	end
	levelAura(r, lv, BLOOD)
	return r:Finish(1.5, { RS = { 8, 0, 0 } })
end

------------------------------------------------------------------------
-- VOID KNIGHT (по концепту)
------------------------------------------------------------------------
-- Угловатый клинок Пустоты: тёмный клинок с неоновыми кромками, гарда с рогами и самоцветом
local function voidBlade(r, A, lv)
	local K, AC = Kit, Kit.Colors
	local y = -1.05
	local len = 3.5 + (lv >= 4 and 0.5 or 0) + (lv >= 5 and 0.4 or 0)
	local w = 0.62 + (lv >= 3 and 0.08 or 0)
	local glow = lv >= 5 and P.NeonSoft or P.Neon
	-- рукоять, навершие
	r:Box(A, V(0.24, 0.24, 0.95), CF(0, y, 0.1), AC.ClothDark, M.Fabric)
	r:Box(A, V(0.34, 0.34, 0.3), CF(0, y, 0.65) * ANG(0, 0, rad(45)), AC.Armor, M.Metal)
	-- гарда с загнутыми рогами и самоцветом
	K.bevel(r, A, V(0.32, 1.4, 0.32), CF(0, y, -0.45), AC.Armor, AC.Edge)
	for _, s in ipairs({ -1, 1 }) do
		K.spike(r, A, V(0, y + 0.62 * s, -0.45), V(0, y + 0.95 * s, -0.85), 0.32, AC.Armor, M.Metal, true, 0.14)
	end
	K.gem(r, A, 0.3, CF(-0.17, y, -0.45) * ANG(0, math.pi / 2, 0), P.Neon)
	K.gem(r, A, 0.3, CF(0.17, y, -0.45) * ANG(0, -math.pi / 2, 0), P.Neon)
	-- клинок: тёмное тело, светящиеся кромки и дол
	local z0 = -0.6
	r:Box(A, V(0.14, w, len), CF(0, y, z0 - len / 2), lv >= 5 and AC.Cloth or AC.ArmorMid, M.Metal)
	r:Neon(A, V(0.16, 0.08, len * 0.97), CF(0, y + w / 2 - 0.03, z0 - len / 2), glow)
	r:Neon(A, V(0.16, 0.08, len * 0.97), CF(0, y - w / 2 + 0.03, z0 - len / 2), glow)
	if lv >= 3 then
		r:Neon(A, V(0.17, 0.08, len * 0.7), CF(0, y, z0 - len * 0.42), P.NeonSoft)
	end
	K.spike(r, A, V(0, y, z0 - len + 0.02), V(0, y, z0 - len - w * 1.3), w, lv >= 5 and AC.Cloth or AC.ArmorMid, M.Metal, true, 0.14)
	K.spike(r, A, V(0, y, z0 - len + 0.02), V(0, y, z0 - len - w * 1.15), w * 0.75, glow, M.Neon, true, 0.16)
	local tip = r:Box(A, V(0.2, 0.2, 0.2), CF(0, y, z0 - len - w), P.Black, M.Plastic, { Transparency = 1, Name = "Muzzle" })
	r.Muzzle = tip
	r:WeaponTrail(A, V(0, y, z0 - 0.15), V(0, y, z0 - len - w), P.NeonSoft)
	return tip
end

local function VoidKnight(lv)
	local K, AC = Kit, Kit.Colors
	local r = Rig.new({ Name = "VoidKnight", Torso = AC.Armor, Arm = AC.Armor, Leg = AC.Armor, Head = AC.Armor, TorsoMat = M.Metal })
	local T, H, RA, LA, RL, LL = r.Torso, r.Head, r.RArm, r.LArm, r.RLeg, r.LLeg
	for _, L in ipairs({ T, H, RA, LA, RL, LL }) do
		L.Transparency = 1
	end
	local leather = Color3.fromRGB(40, 30, 38)
	-- КИРАСА
	K.bevel(r, T, V(2.05, 2.0, 1.05), CF(), AC.Armor, AC.Edge)
	K.bevel(r, T, V(2.25, 1.0, 1.25), CF(0, 0.5, -0.02), AC.ArmorMid, AC.Edge)
	K.bevel(r, T, V(1.85, 0.32, 1.15), CF(0, -0.15, 0), AC.ArmorMid, AC.Edge)
	K.bevel(r, T, V(1.8, 0.32, 1.12), CF(0, -0.45, 0), AC.Armor, AC.Edge)
	if lv >= 2 then
		K.bevel(r, T, V(0.34, 0.95, 0.18), CF(0, 0.5, -0.7), AC.Armor, AC.Edge)
		K.gem(r, T, 0.42, CF(0, 0.55, -0.8), P.Neon, AC.Edge)
	end
	if lv >= 3 then
		K.crack(r, T, { V(-0.85, 0.85, -0.66), V(-0.5, 0.45, -0.66), V(-0.7, 0.1, -0.66) }, 0.06)
		K.crack(r, T, { V(0.55, 0.9, -0.66), V(0.8, 0.4, -0.66) }, 0.05)
	end
	-- пояс с пряжкой, табард, набедренники
	K.bevel(r, T, V(2.15, 0.32, 1.2), CF(0, -0.8, 0), leather, AC.Edge, M.Fabric)
	K.bevel(r, T, V(0.48, 0.44, 0.14), CF(0, -0.8, -0.66), AC.Edge, AC.ArmorMid)
	K.gem(r, T, 0.2, CF(0, -0.8, -0.75), P.Neon)
	r:Box(T, V(0.95, 1.0, 0.08), CF(0, -1.45, -0.6), AC.Cloth, M.Fabric)
	if lv >= 2 then
		K.tatter(r, T, -1.95, -0.6, 0.95, 3, AC.Cloth, M.Fabric, 1)
	end
	for _, s in ipairs({ -1, 1 }) do
		K.bevel(r, T, V(0.75, 0.7, 0.95), CF(0.78 * s, -1.25, -0.02) * ANG(0, 0, rad(10 * s)), AC.ArmorMid, AC.Edge)
	end
	if lv >= 3 then
		K.chain(r, T, 4, 0.26, nil, CF(0.75, -1.0, -0.62))
		K.chain(r, T, 3, 0.26, nil, CF(-0.7, -1.0, 0.62))
	end
	-- ШЛЕМ: гранёный, лицевая пластина, Т-визор, гребень, нащёчники
	K.bevel(r, H, V(1.35, 1.4, 1.4), CF(0, 0.05, 0), AC.Armor, AC.Edge)
	K.bevel(r, H, V(1.12, 1.05, 0.22), CF(0, -0.05, -0.72), AC.ArmorMid, AC.Edge)
	r:Neon(H, V(0.5, 0.09, 0.06), CF(0, 0.2, -0.84), P.Neon)
	r:Neon(H, V(0.1, 0.62, 0.06), CF(0, -0.08, -0.84), P.Neon)
	-- двускатный верх шлема
	r:Wedge(H, V(1.36, 0.42, 0.7), CF(0, 0.96, -0.35), AC.Armor, M.Metal)
	r:Wedge(H, V(1.36, 0.42, 0.7), CF(0, 0.96, 0.35) * ANG(0, math.pi, 0), AC.Armor, M.Metal)
	r:Box(H, V(1.38, 0.06, 0.06), CF(0, 1.16, 0), AC.Edge, M.Metal)
	for _, s in ipairs({ -1, 1 }) do
		r:Wedge(H, V(0.28, 0.55, 0.55), CF(0.58 * s, -0.5, -0.5) * ANG(math.pi, 0, 0), AC.Armor, M.Metal)
	end
	if lv >= 2 then
		K.spike(r, H, V(0, 1.0, -0.3), V(0, 1.45 + lv * 0.12, 0.2), 0.8, AC.Armor, M.Metal, true, 0.14)
	end
	if lv >= 2 then
		local big = lv >= 5 and 1.6 or (lv >= 4 and 1.2 or 0.85)
		for _, s in ipairs({ -1, 1 }) do
			K.hornA(r, H, { V(0.6 * s, 0.3, 0), V(0.95 * s, 0.45 + 0.1 * big, 0.05), V(1.05 * s, 0.8 * big, 0.05), V(0.85 * s, 1.35 * big, -0.1) }, 0.24 + 0.04 * big, AC.Armor, M.Metal)
			if lv >= 5 then
				K.spike(r, H, V(0.95 * s, 1.0 * big, -0.05), V(0.85 * s, 1.35 * big, -0.1), 0.2, P.Neon, M.Neon, false, 0.1)
			end
		end
	end
	-- НАПЛЕЧНИКИ
	for _, a in ipairs({ { RA, 1 }, { LA, -1 } }) do
		local A, s = a[1], a[2]
		if lv == 1 then
			K.bevel(r, A, V(1.35, 0.55, 1.3), CF(0.12 * s, 0.85, 0) * ANG(0, 0, rad(-12 * s)), AC.ArmorMid, AC.Edge)
		else
			local size = lv >= 5 and 1.22 or (lv >= 4 and 1.1 or 1.0)
			K.pauldron(r, A, s, size, AC.Armor, AC.Edge, lv >= 3 and P.Neon or nil, lv >= 5 and 3 or (lv >= 4 and 2 or 1))
		end
		-- рука: плечо, наруч с манжетой, латная перчатка
		K.bevel(r, A, V(1.0, 0.9, 1.0), CF(0, 0.15, 0), AC.Armor, AC.Edge)
		K.bevel(r, A, V(1.15, 0.85, 1.15), CF(0, -0.55, 0), AC.ArmorMid, AC.Edge)
		K.bevel(r, A, V(1.28, 0.24, 1.28), CF(0, -0.15, 0), AC.Armor, AC.Edge)
		K.bevel(r, A, V(1.02, 0.42, 1.02), CF(0, -1.12, 0), AC.Armor, AC.Edge)
		if lv >= 3 then
			K.spike(r, A, V(0.55 * s, -0.5, 0), V(0.95 * s, -0.4, 0.15), 0.32, AC.Armor, M.Metal, true, 0.1)
		end
	end
	-- НОГИ
	for _, Lg in ipairs({ RL, LL }) do
		K.bevel(r, Lg, V(1.0, 0.95, 1.02), CF(0, 0.45, 0), AC.Armor, AC.Edge)
		if lv >= 2 then
			K.bevel(r, Lg, V(0.75, 0.45, 0.25), CF(0, 0.0, -0.58), AC.ArmorMid, AC.Edge)
		end
		K.bevel(r, Lg, V(1.08, 0.7, 1.1), CF(0, -0.38, 0), AC.ArmorMid, AC.Edge)
		K.bootA(r, Lg, AC.Armor, AC.Edge, 1.1)
	end
	-- МЕЧ
	local blade = voidBlade(r, RA, lv)
	if lv >= 3 then
		r:Sparkles(blade, P.Neon, { Rate = 10, Size = 0.3 })
	end
	-- рваный плащ с эмблемой
	if lv >= 4 then
		local cape = r:Cape(2.1, 3.5, AC.Cloth, true)
		K.gem(r, cape, 0.55, CF(0, 0.1, 0.08) * ANG(0, math.pi, 0), P.NeonSoft)
	end
	levelAura(r, lv)
	return r:Finish(1.1, { RS = { 20, 0, 0 } })
end

------------------------------------------------------------------------
-- HALLOWEEN: ПРОКЛЯТЫЙ ЧАСОВЩИК (SECRET)
-- Голова — старинные механические часы, стрелки и шестерёнки на моторах Clock*/Gear*
-- (крутятся в Renderer, быстрее во время способностей). Оружие — Хроносекира.
------------------------------------------------------------------------
local CLK = {
	Black = rgb(20, 18, 24),
	Suit = rgb(34, 30, 40),
	Gold = rgb(214, 168, 72),
	GoldDark = rgb(150, 112, 50),
	Bronze = rgb(160, 106, 52),
	Silver = rgb(172, 174, 188),
	Steel = rgb(58, 54, 64),
	Dial = rgb(14, 12, 18),
	Orange = rgb(255, 140, 40),
	OrangeDim = rgb(140, 70, 24),
}

-- Восьмиугольник из 4 брусков в плоскости XY узла cf (a — расстояние от центра до грани)
local function octa(r, limb, a, depth, cf, color, mat)
	local parts = {}
	for k = 0, 3 do
		parts[#parts + 1] = r:Box(limb, V(2 * a, 0.8284 * a, depth), cf * ANG(0, 0, k * PI / 4), color, mat or M.Metal)
	end
	return parts
end

-- Шестерёнка в плоскости XY. С именем — на своём моторе (крутится вокруг оси Z узла).
local function gear(r, limb, name, pivot, a, depth, color, hubColor, rate, mat)
	local host, base = limb, pivot
	if name then
		host = r:Joint(name, limb, V(0.1, 0.1, 0.1), pivot, CF(), color)
		host.Transparency = 1
		base = CF()
		r.SpinRates[name] = rate or 1
	end
	octa(r, host, a, depth, base, color, mat)
	for k = 0, 7 do
		local ang = k * PI / 4
		r:Box(host, V(a * 0.36, a * 0.34, depth), base * CF(math.cos(ang) * a * 1.08, math.sin(ang) * a * 1.08, 0) * ANG(0, 0, ang), color, mat or M.Metal)
	end
	local hub = r:Box(host, V(a * 0.42, a * 0.42, depth + 0.04), base * ANG(0, 0, PI / 4), hubColor or CLK.Black, (hubColor == CLK.Orange) and M.Neon or M.Metal)
	return host, hub
end

-- Циферблат: рама, чёрный диск, деления, стрелки на моторах <prefix>Hour / <prefix>Minute
local function clockFace(r, limb, cf, a, frame, prefix, handColor, glowHands)
	octa(r, limb, a, 0.5, cf, frame)
	octa(r, limb, a * 0.84, 0.54, cf, CLK.Dial, M.Plastic)
	for k = 0, 11 do
		local ang = k * PI / 6
		local big = k % 3 == 0
		r:Box(limb, V(a * 0.07, a * (big and 0.2 or 0.12), 0.04), cf * CF(math.cos(ang) * a * 0.68, math.sin(ang) * a * 0.68, -0.28) * ANG(0, 0, ang + PI / 2), handColor, M.Metal)
	end
	local hands = {}
	for i, h in ipairs({ { "Hour", 0.45, 0.11, 0.22 }, { "Minute", 0.68, 0.07, 1.6 } }) do
		local name = prefix .. h[1]
		local hub = r:Joint(name, limb, V(0.1, 0.1, 0.1), cf * CF(0, 0, -0.3 - i * 0.02), CF(), handColor)
		hub.Transparency = 1
		r.SpinRates[name] = h[4]
		local f = glowHands and r.Neon or r.Box
		hands[i] = f(r, hub, V(a * h[3], a * h[2], 0.04), CF(0, a * h[2] * 0.42, 0), glowHands and CLK.Orange or handColor)
	end
	r:Box(limb, V(a * 0.16, a * 0.16, 0.08), cf * CF(0, 0, -0.36) * ANG(0, 0, PI / 4), CLK.Gold, M.Metal)
	return hands
end

-- Хроносекира: длинная тёмная рукоять, два полукруглых зубчатых лезвия, центральная шестерня
local function chronoaxe(r, A, lv)
	local z = -0.5
	local bottom, top = -2.5, 2.3
	r:Box(A, V(0.22, top - bottom, 0.22), CF(0, (top + bottom) / 2, z), CLK.Steel, M.Metal)
	for _, y in ipairs({ -1.6, -0.2, 1.2 }) do
		Kit.bevel(r, A, V(0.34, 0.16, 0.34), CF(0, y, z), CLK.Bronze, false)
	end
	Kit.spike(r, A, V(0, bottom + 0.05, z), V(0, bottom - 0.5, z), 0.3, CLK.Bronze, M.Metal)
	local c = V(0, top + 0.2, z)
	local R = ({ 0.95, 1.15, 1.15, 1.3, 1.45 })[lv]
	local blade = lv >= 5 and CLK.Black or CLK.Steel
	local rimColor = lv >= 4 and CLK.Orange or CLK.OrangeDim
	for _, side in ipairs({ -1, 1 }) do
		local prev
		for k = 0, 6 do
			local phi = rad(-78 + k * 26)
			local dir = V(0, math.sin(phi), side * math.cos(phi))
			Kit.bar(r, A, c + dir * 0.3, c + dir * R, V2(0.1, 2 * R * math.sin(rad(13)) + 0.1), blade, M.Metal)
			Kit.spike(r, A, c + dir * (R - 0.02), c + dir * (R + 0.22), 0.2, CLK.Gold, M.Metal, true, 0.1)
			local rim = c + dir * (R * 0.9)
			if prev then
				local g = Kit.bar(r, A, prev, rim, V2(0.12, 0.07), rimColor, M.Neon)
				g:SetAttribute("AxeGlow", true)
			end
			prev = rim
		end
		-- бронзовая накладка у основания лезвия
		Kit.bevel(r, A, V(0.14, 0.5, 0.35), CF(c + V(0, 0, side * 0.42)), CLK.Bronze, false)
	end
	-- центральная шестерня (вращается) и малые механизмы
	local _, hub = gear(r, A, "GearAxe", CF(c) * ANG(0, PI / 2, 0), 0.38, 0.16, lv >= 3 and CLK.Gold or CLK.Bronze, CLK.Orange, 2.2)
	hub:SetAttribute("AxeGlow", true)
	gear(r, A, "GearAxeS1", CF(c + V(0, 0.5, -0.3)) * ANG(0, PI / 2, 0), 0.15, 0.12, CLK.Bronze, CLK.Black, -3.5)
	gear(r, A, "GearAxeS2", CF(c + V(0, -0.5, 0.3)) * ANG(0, PI / 2, 0), 0.15, 0.12, CLK.Bronze, CLK.Black, 3.5)
	r:Sparkles(hub, CLK.Orange, { Rate = lv >= 4 and 8 or 4, Size = 0.18 })
	r:WeaponTrail(A, c + V(0, 0, -0.4), c + V(0, 0, -R), CLK.Orange)
	return muzzle(r, A, CF(c))
end

-- Маленькие часы (для орбиты вокруг персонажа)
local function miniClock(r, limb, cf, a)
	octa(r, limb, a, 0.12, cf, CLK.Gold)
	octa(r, limb, a * 0.8, 0.14, cf, CLK.Dial, M.Plastic)
	r:Box(limb, V(a * 0.12, a * 0.6, 0.04), cf * CF(0, a * 0.25, -0.09), CLK.Gold, M.Metal)
	r:Box(limb, V(a * 0.5, a * 0.1, 0.04), cf * CF(a * 0.2, 0, -0.1), CLK.Gold, M.Metal)
end

local function CursedClockmaker(lv)
	local edge = CLK.GoldDark
	local r = Rig.new({ Name = "CursedClockmaker", HeadSize = V(1.2, 1.2, 1.2), Torso = CLK.Black, Arm = CLK.Black, Leg = CLK.Black, Head = CLK.Black })
	r.SpinRates = {}
	for _, L in ipairs({ r.Torso, r.Head, r.RArm, r.LArm, r.RLeg, r.LLeg }) do
		L.Transparency = 1
	end
	local T, H, RA, LA, RL, LL = r.Torso, r.Head, r.RArm, r.LArm, r.RLeg, r.LLeg
	local gearColor = lv >= 3 and CLK.Gold or (lv >= 2 and CLK.Silver or CLK.Bronze)
	local frame = lv >= 3 and CLK.Gold or CLK.Bronze

	-- R6-ТЕЛО: чёрный костюм с золотым кантом
	Kit.bevel(r, T, V(2, 2, 1), CF(), CLK.Black, edge)
	Kit.bevel(r, RA, V(1, 2, 1), CF(), CLK.Black, edge)
	Kit.bevel(r, LA, V(1, 2, 1), CF(), CLK.Black, edge)
	Kit.bevel(r, RL, V(1, 2, 1), CF(), CLK.Black, edge)
	Kit.bevel(r, LL, V(1, 2, 1), CF(), CLK.Black, edge)
	-- жилет, лацканы, пуговицы, брошь
	Kit.bevel(r, T, V(1.5, 1.7, 1.08), CF(0, 0.1, 0), CLK.Suit, edge, M.Fabric)
	for _, s in ipairs({ -1, 1 }) do
		Kit.bar(r, T, V(0.25 * s, 0.98, -0.56), V(0.62 * s, -0.4, -0.56), V2(0.12, 0.05), CLK.Gold, M.Metal)
	end
	for k = 0, 2 do
		r:Box(T, V(0.12, 0.12, 0.06), CF(0, 0.45 - k * 0.38, -0.57) * ANG(0, 0, PI / 4), CLK.Gold, M.Metal)
	end
	Kit.gem(r, T, 0.26, CF(0, 0.82, -0.6), CLK.Orange, CLK.Gold)
	-- золотые цепочки и карманные часы
	Kit.bar(r, T, V(0, 0.07, -0.58), V(-0.45, -0.3, -0.58), V2(0.06, 0.06), CLK.Gold, M.Metal)
	Kit.bar(r, T, V(-0.45, -0.3, -0.58), V(-0.75, -0.05, -0.58), V2(0.06, 0.06), CLK.Gold, M.Metal)
	miniClock(r, T, CF(-0.78, -0.25, -0.58), 0.18)
	-- пояс с пряжкой-шестерёнкой
	Kit.bevel(r, T, V(2.1, 0.3, 1.12), CF(0, -0.82, 0), CLK.Black, edge)
	gear(r, T, nil, CF(0, -0.82, -0.6), 0.16, 0.08, CLK.Gold, CLK.Orange)
	-- полы длинного сюртука
	for _, s in ipairs({ -1, 1 }) do
		Kit.bevel(r, T, V(0.95, 1.6, 0.16), CF(0.52 * s, -1.75, 0.46), CLK.Suit, edge, M.Fabric)
	end
	Kit.tatter(r, T, -2.55, 0.46, 2.0, 4, CLK.Suit, M.Fabric, 5)

	-- ГОЛОВА-ЧАСЫ
	local a = lv >= 5 and 1.0 or 0.92
	local headCF = CF(0, 0.35, 0)
	clockFace(r, H, headCF, a, frame, "Clock", CLK.Gold, lv >= 4)
	-- светящиеся механизмы на циферблате и по бокам
	gear(r, H, "GearHeadA", headCF * CF(0, -a * 0.38, -0.29), a * 0.16, 0.04, CLK.Orange, CLK.Dial, 3, M.Neon)
	for _, s in ipairs({ -1, 1 }) do
		gear(r, H, s == 1 and "GearHeadR" or "GearHeadL", headCF * CF(a * 0.98 * s, a * 0.45, 0), a * 0.24, 0.2, gearColor, CLK.Orange, 1.4 * s)
	end
	-- заводная головка сверху
	Kit.bevel(r, H, V(0.3, 0.3, 0.3), headCF * CF(0, a + 0.1, 0), frame, false)
	Kit.bevel(r, H, V(0.44, 0.12, 0.44), headCF * CF(0, a + 0.3, 0), frame, false)

	-- НАПЛЕЧНИКИ
	if lv >= 3 then
		Kit.pauldron(r, RA, 1, lv >= 5 and 1.2 or 1.05, CLK.Black, CLK.Gold, CLK.Orange, lv >= 5 and 2 or 1)
		Kit.pauldron(r, LA, -1, lv >= 5 and 1.2 or 1.05, CLK.Black, CLK.Gold, CLK.Orange, lv >= 5 and 2 or 1)
	else
		for _, side in ipairs({ 1, -1 }) do
			local A = side == 1 and RA or LA
			Kit.bevel(r, A, V(1.3, 0.45, 1.25) * (lv >= 2 and 1.1 or 1), CF(0.12 * side, 0.9, 0) * ANG(0, 0, rad(-12 * side)), CLK.Steel, lv >= 2 and CLK.Silver or CLK.Bronze)
			gear(r, A, nil, CF(0.62 * side, 0.85, 0) * ANG(0, PI / 2, 0), 0.2, 0.08, gearColor, CLK.Black)
		end
	end
	-- рукава с золотыми манжетами, перчатки
	for _, A in ipairs({ RA, LA }) do
		Kit.bevel(r, A, V(1.16, 0.3, 1.16), CF(0, -0.55, 0), CLK.Gold, false)
		Kit.bevel(r, A, V(1.04, 0.42, 1.04), CF(0, -0.82, 0), lv >= 2 and CLK.Steel or CLK.Bronze, edge)
		if lv >= 2 then
			Kit.bevel(r, A, V(1.12, 0.5, 1.12), CF(0, -0.2, 0), CLK.Steel, CLK.Silver)
		end
	end
	-- ноги: брюки, наколенники (с 2 ур.), сапоги с золотом
	for _, Lg in ipairs({ RL, LL }) do
		if lv >= 2 then
			Kit.bevel(r, Lg, V(0.8, 0.45, 0.26), CF(0, 0.0, -0.58), CLK.Steel, CLK.Silver)
		end
		Kit.bootA(r, Lg, CLK.Black, CLK.Gold, 1.12)
	end

	-- МЕХАНИЗМ НА СПИНЕ
	gear(r, T, "GearBack", CF(0, 0.3, 0.7), 0.7, 0.2, gearColor, CLK.Orange, 0.8)
	if lv >= 3 then
		gear(r, T, "GearBack2", CF(0.75, -0.35, 0.82), 0.42, 0.18, CLK.Bronze, CLK.Black, -1.4)
		gear(r, T, "GearBack3", CF(-0.7, -0.45, 0.82), 0.32, 0.18, CLK.Bronze, CLK.Black, 1.9)
		for _, s in ipairs({ -1, 1 }) do
			r:Box(T, V(0.14, 1.4, 0.14), CF(0.55 * s, 0.4, 0.66), CLK.Bronze, M.Metal)
		end
	end
	-- ПЛАЩ (роскошный с 4 ур.)
	local cape = r:Cape(lv >= 4 and 2.3 or 2.0, lv >= 4 and 4.2 or 3.6, lv >= 4 and rgb(26, 16, 30) or CLK.Black, true)
	if lv >= 4 then
		Kit.gem(r, cape, 0.5, CF(0, 0.1, 0.08) * ANG(0, PI, 0), CLK.Orange, CLK.Gold)
		r:Box(cape, V(2.34, 0.1, 0.14), CF(0, 0.9, 0), CLK.Gold, M.Metal)
	end
	-- ОГРОМНЫЕ ЧАСЫ ЗА СПИНОЙ (MAX)
	if lv >= 5 then
		clockFace(r, T, CF(0, 1.5, 1.15), 1.9, CLK.Gold, "ClockBig", CLK.Gold, true)
	end
	-- парящие золотые часы
	local orb = r:Orbit("OrbitClocks", T, CF(0, 0.5, 0), 2.6, 0, 0.2, CLK.Gold)
	local n = lv >= 5 and 5 or (lv >= 3 and 4 or 3)
	for i = 0, n - 1 do
		local ang = i / n * PI * 2
		miniClock(r, orb, CF(math.cos(ang) * 2.6, math.sin(ang * 2) * 0.4, math.sin(ang) * 2.6) * ANG(0, -ang + PI / 2, 0), 0.3)
	end
	-- вращающиеся золотые кольца (с 4 ур.)
	if lv >= 4 then
		local ringHub = r:Orbit("OrbitGoldRing", T, CF(0, -0.2, 0), 2.1, 0, 0.2, CLK.Gold)
		Kit.ring(r, ringHub, ANG(rad(90), 0, 0), 2.1, 16, 0.08, 0.14, CLK.Gold, M.Metal, function(k)
			return k % 4 == 3
		end)
	end
	-- шестерни бури (видны только во время «Временной бури»)
	local storm = r:Orbit("OrbitStormGears", T, CF(0, 0.2, 0), 3.2, 0, 0.2, CLK.Gold)
	local before = #r.Model:GetChildren()
	for i = 0, 5 do
		local ang = i / 6 * PI * 2
		gear(r, storm, nil, CF(math.cos(ang) * 3.2, math.sin(ang * 3) * 0.5, math.sin(ang) * 3.2) * ANG(0, -ang, 0), 0.3, 0.1, CLK.Gold, CLK.Orange)
	end
	local all = r.Model:GetChildren()
	for i = before + 1, #all do
		local d = all[i]
		if d:IsA("BasePart") then
			d:SetAttribute("StormFX", d.Transparency)
			d.Transparency = 1
		end
	end

	-- ХРОНОСЕКИРА в правой руке
	chronoaxe(r, RA, lv)
	levelAura(r, lv, CLK.Orange)
	return r:Finish(1.45, { RS = { 20, 0, 0 }, LS = { 10, 0, -5 } })
end

local Builders = {
	VoidSoldier = VoidSoldier,
	ShadowArcher = ShadowArcher,
	LostMage = LostMage,
	VoidKnight = VoidKnight,
	DarkGunner = DarkGunner,
	AbyssReaper = AbyssReaper,
	CorruptedSamurai = CorruptedSamurai,
	EclipseGuardian = EclipseGuardian,
	FallenAngel = FallenAngel,
	VoidEmperor = VoidEmperor,
	AbyssOverlord = AbyssOverlord,
	RiftScout = RiftScout,
	CrystalHunter = CrystalHunter,
	VoidPuppeteer = VoidPuppeteer,
	Starbreaker = Starbreaker,
	RiftMonarch = RiftMonarch,
	RealityDestroyer = RealityDestroyer,
	BloodAcolyte = BloodAcolyte,
	CrimsonGunslinger = CrimsonGunslinger,
	MoonWitch = MoonWitch,
	BloodfangWarlord = BloodfangWarlord,
	LunarSeraph = LunarSeraph,
	CrimsonEclipse = CrimsonEclipse,
	CursedClockmaker = CursedClockmaker,
}

-- Построить модель юнита. Модель стоит в начале координат, ноги на высоте -HipHeight.
-- Аура редкости у ног: Epic — фиолетовые искры, Legendary — золото, Mythic — красно-фиолетовый вихрь
local applyLevelSkin
local UNIT_RARITY = {
	AbyssReaper = "Epic", CorruptedSamurai = "Epic", VoidPuppeteer = "Epic", MoonWitch = "Epic",
	EclipseGuardian = "Legendary", FallenAngel = "Legendary", Starbreaker = "Legendary", BloodfangWarlord = "Legendary",
	VoidEmperor = "Mythic", AbyssOverlord = "Mythic", RiftMonarch = "Mythic", LunarSeraph = "Mythic",
	RealityDestroyer = "Secret", CrimsonEclipse = "Secret", CursedClockmaker = "Secret",
}
local RARITY_AURA = {
	Epic = { Color = ColorSequence.new(Color3.fromRGB(170, 80, 255)), Rate = 3, Size = 0.22 },
	Legendary = { Color = ColorSequence.new(Color3.fromRGB(255, 205, 70), Color3.fromRGB(190, 110, 255)), Rate = 5, Size = 0.28 },
	Mythic = { Color = ColorSequence.new(Color3.fromRGB(255, 50, 150), Color3.fromRGB(150, 60, 255)), Rate = 8, Size = 0.34 },
	Secret = { Color = ColorSequence.new(Color3.fromRGB(255, 20, 40), Color3.fromRGB(20, 0, 0)), Rate = 14, Size = 0.45 },
}

-- Материалы меняются с уровнем: 1 — потёртый ржавый металл, 2–3 — металл, 4–5 — блестящая фольга,
-- на 5-м уровне броня ещё и подсвечивается цветом редкости.
local RARITY_TINT = {
	Epic = Color3.fromRGB(150, 80, 230), Legendary = Color3.fromRGB(230, 180, 60),
	Mythic = Color3.fromRGB(150, 70, 230), Secret = Color3.fromRGB(230, 30, 40),
}
applyLevelSkin = function(model, lv, rarity)
	local tint = RARITY_TINT[rarity or ""]
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and d.Transparency < 1 then
			local mat = d.Material
			if mat == M.Metal then
				if lv == 1 then
					d.Material = Enum.Material.CorrodedMetal
				elseif lv >= 4 then
					d.Material = Enum.Material.Foil
					if lv >= 5 and tint then
						d.Color = d.Color:Lerp(tint, 0.1)
					end
				end
			elseif mat == M.Plastic and lv == 1 then
				d.Material = Enum.Material.Plastic
			elseif mat == M.Fabric and lv >= 5 and tint then
				d.Color = d.Color:Lerp(tint, 0.06)
			end
		end
	end
end

-- Хелперы для модулей-расширений (HalloweenModels): тот же R6-стиль и те же детали
UnitModels.H = {
	figure = figure, eyes = eyes, chest = chest, belt = belt, tassets = tassets, robe = robe, mantle = mantle,
	hood = hood, helm = helm, wizardHat = wizardHat, crown = crown, kabuto = kabuto,
	plateShoulders = plateShoulders, bigShoulders = bigShoulders, bracers = bracers, greaves = greaves, wings = wings,
	muzzle = muzzle, blade = blade, shaft = shaft, staff = staff, scythe = scythe, spear = spear, hammer = hammer,
	axe = axe, bow = bow, quiver = quiver, crossbow = crossbow, rifle = rifle, dagger = dagger, shield = shield,
	capeWith = capeWith, levelAura = levelAura, octa = octa, gear = gear, clockFace = clockFace, miniClock = miniClock,
	rgb = rgb, GRIP = GRIP, AIM = AIM, M = M, P = P, AC = AC,
}

-- Регистрация юнита из модуля-расширения
function UnitModels.Register(unitId, builder, rarity)
	Builders[unitId] = builder
	UNIT_RARITY[unitId] = rarity
end

function UnitModels.Has(unitId)
	return Builders[unitId] ~= nil
end

function UnitModels.Build(unitId, level)
	local builder = Builders[unitId]
	if not builder then
		error("Unknown unit " .. tostring(unitId))
	end
	local lv = math.clamp(level or 1, 1, 5)
	local rig = builder(lv)
	rig.Model.Name = unitId
	applyLevelSkin(rig.Model, lv, UNIT_RARITY[unitId])
	Kit.Calm(rig.Model)
	local aura = not UnitModels.Lite and RARITY_AURA[UNIT_RARITY[unitId] or ""]
	if aura then
		local at = Instance.new("Attachment")
		at.Name = "AuraPoint"
		at.Position = V(0, -rig.HipHeight + 0.2, 0)
		at.Parent = rig.Root
		local e = Instance.new("ParticleEmitter")
		e.Name = "RarityAura"
		e.Color = aura.Color
		e.LightEmission = 1
		e.LightInfluence = 0
		e.Rate = aura.Rate
		e.Lifetime = NumberRange.new(1.2, 2)
		e.Speed = NumberRange.new(0.6, 1.6)
		e.EmissionDirection = Enum.NormalId.Top
		e.SpreadAngle = Vector2.new(70, 70)
		e.Acceleration = V(0, 1.2, 0)
		e.RotSpeed = NumberRange.new(-90, 90)
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, aura.Size), NumberSequenceKeypoint.new(1, 0) })
		e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
		e.Parent = at
	end
	rig.Model:SetAttribute("UnitId", unitId)
	rig.Model:SetAttribute("Level", level or 1)
	return rig
end

-- Хэллоуинские юниты, союзники-призывы и руны
require(script.Parent:WaitForChild("HalloweenModels"))(UnitModels)

return UnitModels
]======] }
FILES[#FILES + 1] = { "ReplicatedStorage", { "VoidTD", "HalloweenEnemies" }, "ModuleScript", [======[
--!nocheck
-- VOID TD :: HalloweenEnemies
-- Хэллоуинские враги и финальные боссы (карта Haunted Hollow) в том же угловатом стиле:
-- блоки с фаской, клинья, шипы, ромбы, рваная ткань. Палитра: чёрный, тёмно-фиолетовый, оранжевый,
-- бордовый, золото, болотно-зелёный, кость.
--
-- Дополнительные поля rig (визуал реализует Renderer/FX):
--   DeathFX  "GreenSmoke" | "PumpkinBurst" | "Ghost" | "BoneShards" | "Straw" | "Fog" | "Reaper" | "MonarchDeath"
--   SpawnFX  "GraveBreak" | "FogVortex" | "MonarchPortal"
-- Атрибуты деталей:
--   Outline = true  — контур Призрачного воина, остаётся видимым в фазе невидимости
--   Crown = true    — корона Проклятого монарха (трескается при смерти)
-- Детали "ShieldFX" (скрыты, PT — целевая прозрачность) — щит Ночного жнеца.
-- Эмиттеры "FogFX" (выключены) — импульс тумана Туманного колдуна и Туманного жнеца.

local Kit = require(script.Parent.ModelKit)

return function(EnemyModels)
	local H = EnemyModels.H
	local newCreature, newBiped, setup, hub = H.newCreature, H.newBiped, H.setup, H.hub
	local emitter, emitPoint, finishCreature, finishBiped = H.emitter, H.emitPoint, H.finishCreature, H.finishBiped
	local C, M, rgb, lite = H.C, H.M, H.rgb, H.lite
	local A_ = Kit.Colors
	local bevel, bar, spike, gem, tatter = Kit.bevel, Kit.bar, Kit.spike, Kit.gem, Kit.tatter
	local crack, hide, join, hornA, pauldron, bootA, chain = Kit.crack, Kit.hide, Kit.join, Kit.hornA, Kit.pauldron, Kit.bootA, Kit.chain

	local WOOD, GRASS = Enum.Material.Wood, Enum.Material.Grass
	local V = Vector3.new
	local V2 = Vector2.new
	local CF = CFrame.new
	local ANG = CFrame.Angles
	local rad = math.rad
	local PI = math.pi

	-- палитра Хэллоуина
	local HC = {
		Pumpkin = rgb(214, 102, 26),
		PumpkinHi = rgb(250, 150, 60),
		PumpkinDark = rgb(150, 62, 18),
		Burnt = rgb(70, 34, 20),
		Stem = rgb(58, 70, 32),
		Fire = rgb(255, 140, 30),
		FireSoft = rgb(255, 196, 90),
		Green = rgb(130, 255, 90),
		GreenSoft = rgb(190, 255, 150),
		Rot = rgb(84, 104, 72),
		RotDark = rgb(50, 62, 44),
		RotHi = rgb(130, 146, 104),
		Rag = rgb(54, 48, 44),
		RagHi = rgb(96, 86, 74),
		Purple = rgb(44, 24, 62),
		PurpleHi = rgb(96, 62, 128),
		PurpleGlow = rgb(170, 90, 255),
		Burgundy = rgb(92, 20, 34),
		BurgundyHi = rgb(150, 50, 66),
		Gold = rgb(214, 166, 64),
		GoldDark = rgb(140, 100, 36),
		Straw = rgb(214, 178, 92),
		StrawDark = rgb(160, 122, 54),
		Sack = rgb(176, 148, 104),
		SackDark = rgb(120, 96, 64),
		Ghost = rgb(150, 226, 218),
		GhostMid = rgb(96, 170, 172),
		GhostDeep = rgb(34, 60, 70),
		Iron = rgb(58, 58, 66),
		IronHi = rgb(116, 116, 128),
		Rust = rgb(110, 62, 38),
		Stone = rgb(80, 80, 86),
		StoneHi = rgb(130, 130, 136),
		StoneDark = rgb(52, 52, 58),
		Moss = rgb(66, 92, 50),
		Fog = rgb(150, 160, 150),
		FogDark = rgb(70, 78, 74),
		Red = rgb(255, 40, 40),
		Crow = rgb(22, 20, 26),
	}

	local function mark(parts, attr)
		for _, p in ipairs(parts) do
			p:SetAttribute(attr, true)
		end
		return parts
	end

	-- Угловатая тыква: восьмигранник из блоков, рёбра-дольки, хвостик, вырезанное светящееся лицо.
	-- Возвращает (все детали, детали глаз, детали рта)
	local function pumpkin(r, limb, cf, s, o)
		o = o or {}
		local col, dark, glow = o.Color or HC.Pumpkin, o.Dark or HC.PumpkinDark, o.Glow or HC.Fire
		local parts, eyesP, mouth = {}, {}, {}
		local function add(list)
			for _, p in ipairs(list) do
				parts[#parts + 1] = p
			end
		end
		-- корпус: крест из двух брусков (широкий и глубокий) — гранёный силуэт тыквы сверху
		add(bevel(r, limb, V(1.75, 1.2, 1.2) * s, cf, col, o.Edge or HC.PumpkinHi, M.Plastic))
		add(bevel(r, limb, V(1.2, 1.28, 1.6) * s, cf, col, o.Edge or HC.PumpkinHi, M.Plastic))
		-- тёмные борозды между дольками
		if not Kit.Cheap then
			for _, x in ipairs({ -0.66, 0.66 }) do
				parts[#parts + 1] = r:Box(limb, V(0.1, 1.15, 0.05) * s, cf * CF(x * s, 0, -0.6 * s), dark, M.Plastic)
				parts[#parts + 1] = r:Box(limb, V(0.05, 1.15, 0.1) * s, cf * CF(x * 1.33 * s, 0, 0), dark, M.Plastic)
			end
		end
		-- верх и хвостик
		parts[#parts + 1] = r:Box(limb, V(1.1, 0.2, 1.05) * s, cf * CF(0, 0.66 * s, 0), dark, M.Plastic)
		parts[#parts + 1] = bar(r, limb, (cf * CF(0, 0.7 * s, 0)).Position, (cf * CF(0.12 * s, 1.1 * s, 0.1 * s)).Position, 0.18 * s, o.Stem or HC.Stem)
		-- глаза: светящиеся ромбы с тёмной рамкой, нос, зубастый рот
		local z = -0.81 * s
		for _, side in ipairs({ -1, 1 }) do
			local e = r:Neon(limb, V(0.36, 0.3, 0.06) * s, cf * CF(0.36 * side * s, 0.18 * s, z) * ANG(0, 0, rad(30 * side)), glow)
			eyesP[#eyesP + 1] = e
			parts[#parts + 1] = e
		end
		local nose = r:Neon(limb, V(0.16, 0.16, 0.06) * s, cf * CF(0, -0.02 * s, z) * ANG(0, 0, rad(45)), glow)
		parts[#parts + 1] = nose
		local m1 = r:Neon(limb, V(1.0, 0.22, 0.06) * s, cf * CF(0, -0.32 * s, z), glow)
		mouth[#mouth + 1] = m1
		parts[#parts + 1] = m1
		for _, x in ipairs({ -0.25, 0.22 }) do
			parts[#parts + 1] = r:Box(limb, V(0.13, 0.14, 0.07) * s, cf * CF(x * s, -0.25 * s, z - 0.01 * s), dark, M.Plastic)
		end
		return parts, eyesP, mouth
	end

	-- Глубокий капюшон: верх, бока, спинка, козырёк; лицо утоплено внутрь (возвращает z лица)
	local function deepHood(r, limb, w, h, color, edge, y)
		y = y or 0
		bevel(r, limb, V(w, 0.3, w), CF(0, y + h / 2 - 0.15, 0.05), color, edge, M.Fabric)
		for _, s in ipairs({ -1, 1 }) do
			bevel(r, limb, V(0.26, h, w), CF((w / 2 - 0.13) * s, y, 0.05), color, edge, M.Fabric)
		end
		bevel(r, limb, V(w, h, 0.26), CF(0, y, w / 2 - 0.08), color, edge, M.Fabric)
		r:Wedge(limb, V(w, 0.35, 0.45), CF(0, y + h / 2 - 0.45, -w / 2 + 0.15), color, M.Fabric)
		r:Box(limb, V(w - 0.4, h - 0.3, 0.1), CF(0, y - 0.05, 0.1), rgb(8, 6, 12), M.Plastic)
		return -w / 2 + 0.3
	end

	-- Простой коготь-кисть из шипов
	local function claws(r, A, color, n, len)
		for k = 1, n or 3 do
			local x = (k - (n or 3) / 2 - 0.5) * 0.28
			spike(r, A, V(x, -1.0, -0.2), V(x * 1.2, -1.15, -0.2 - (len or 0.5)), 0.16, color, M.Plastic, true, 0.06)
		end
	end

	------------------------------------------------------------------------
	-- 1. CURSED DEAD — медленный проклятый мертвец: руки вперёд, гнилая кожа, зелёные глаза
	------------------------------------------------------------------------
	local function CursedDead(scale)
		local r = newBiped("CursedDead", V(1.15, 1.15, 1.15))
		setup(r, { Style = "Biped", Gait = { Speed = 0.7, Stride = 0.35, Bob = 0.08, Sway = 0.14, Lean = 10 }, Death = "Collapse" })
		r.DeathFX = "GreenSmoke"
		local T, Hd, RA, LA, RL, LL = r.Torso, r.Head, r.RArm, r.LArm, r.RLeg, r.LLeg
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
		for _, s in ipairs({ -1, 1 }) do
			r:Box(Hd, V(0.34, 0.3, 0.06), CF(0.27 * s, 0.12, -0.58), HC.RotDark, M.Plastic)
			r:Neon(Hd, V(0.16, 0.14, 0.06), CF(0.27 * s, 0.1, -0.61), HC.Green)
		end
		r:Box(Hd, V(0.6, 0.3, 0.08), CF(0, -0.38, -0.58), rgb(20, 16, 18), M.Plastic)
		for _, x in ipairs({ -0.18, 0.05, 0.2 }) do
			r:Box(Hd, V(0.08, 0.1, 0.06), CF(x, -0.27, -0.62), C.Bone, M.Plastic)
		end
		-- руки: гнилые, одна в лохмотьях, когти
		for _, A in ipairs({ RA, LA }) do
			bevel(r, A, V(0.9, 2, 0.9), CF(), HC.Rot, HC.RotHi, M.Plastic)
			claws(r, A, HC.RotDark, 3, 0.4)
		end
		bevel(r, RA, V(1.02, 0.9, 1.02), CF(0, 0.5, 0), HC.Rag, HC.RagHi, M.Fabric)
		for _, Lg in ipairs({ RL, LL }) do
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
		setup(r, { Style = "Biped", Gait = { Speed = 1.25, Stride = 0.85, Bob = 0.22, Sway = 0.05, Lean = 16 }, Death = "Scatter" })
		r.DeathFX = "PumpkinBurst"
		local T, Hd, RA, LA, RL, LL = r.Torso, r.Head, r.RArm, r.LArm, r.RLeg, r.LLeg
		-- тонкое тёмное тело в лохмотьях
		bevel(r, T, V(1.7, 1.9, 0.85), CF(), HC.Purple, HC.PurpleHi, M.Fabric)
		r:Box(T, V(1.75, 0.25, 0.9), CF(0, -0.8, 0), HC.Burnt, M.Fabric)
		-- шарф-лоскут
		r:Box(T, V(1.4, 0.3, 1.0), CF(0, 0.85, 0), HC.Burgundy, M.Fabric)
		local scarf = hub(r, "SwayScarf", T, CF(0.4, 0.8, 0.5), { Amp = 0.35, Speed = 6 })
		spike(r, scarf, V(0, 0, 0), V(0.15, -0.3, 1.2), 0.35, HC.Burgundy, M.Fabric, true, 0.06)
		-- тыква-голова
		pumpkin(r, Hd, CF(0, 0.05, 0), 0.82)
		r:Glow(Hd, HC.Fire, 6, 0.9)
		for _, A in ipairs({ RA, LA }) do
			bevel(r, A, V(0.7, 2, 0.7), CF(), HC.Purple, HC.PurpleHi, M.Fabric)
			r:Box(A, V(0.72, 0.5, 0.72), CF(0, -0.8, 0), HC.Stem, M.Plastic)
		end
		for _, Lg in ipairs({ RL, LL }) do
			bevel(r, Lg, V(0.75, 2, 0.75), CF(), HC.Burnt, HC.RagHi, M.Fabric)
			r:Wedge(Lg, V(0.8, 0.35, 0.45), CF(0, -0.85, -0.55), HC.Stem, M.Plastic)
		end
		-- оранжевые искры
		emitter(Hd, HC.Fire, { Rate = 10, Size = 0.18, LifeMin = 0.3, LifeMax = 0.7, SpeedMin = 1, SpeedMax = 2.5, Accel = V(0, 2, 0) })
		return finishBiped(r, scale, { RS = { -10, 0, 6 }, LS = { -10, 0, -6 }, Root = { 10, 0, 0 } })
	end

	------------------------------------------------------------------------
	-- 3. PHANTOM WARRIOR — призрачный воин с мечом и щитом, контур остаётся при невидимости
	------------------------------------------------------------------------
	local function PhantomWarrior(scale)
		local r = newCreature("PhantomWarrior", V(1.8, 1.8, 1.0))
		setup(r, { Style = "Float", Gait = { Bob = 0.25 }, Death = "Dissipate", Spawn = "Fade" })
		r.DeathFX = "Ghost"
		local B = r.Torso
		local gT = { Transparency = 0.3 }
		local outline = {}
		local function ol(list)
			for _, p in ipairs(list) do
				outline[#outline + 1] = p
			end
		end
		-- призрачный торс в латах, нижняя часть — хвост-дым
		r:Box(B, V(1.8, 1.4, 1.0), CF(0, 0.35, 0), HC.Ghost, M.Plastic, gT)
		local plate = bevel(r, B, V(2.0, 1.0, 1.15), CF(0, 0.55, -0.02), HC.GhostDeep, HC.Ghost)
		ol({ plate[#plate] })
		r:Box(B, V(1.4, 0.7, 0.9), CF(0, -0.6, 0.05), HC.GhostMid, M.Plastic, { Transparency = 0.4 })
		spike(r, B, V(0, -0.9, 0.1), V(0.15, -2.1, 0.35), 1.0, HC.GhostMid, M.Plastic, false)
		-- голова-шлем: Т-визор, гребень
		local head = hub(r, "BobHead", B, CF(0, 1.55, 0), { Amp = 0.06, Speed = 2 })
		local helm = bevel(r, head, V(1.1, 1.15, 1.15), CF(), HC.GhostDeep, HC.Ghost)
		ol({ helm[#helm] })
		ol({ r:Neon(head, V(0.62, 0.1, 0.06), CF(0, 0.12, -0.6), HC.Ghost) })
		ol({ r:Neon(head, V(0.1, 0.42, 0.06), CF(0, -0.1, -0.6), HC.Ghost) })
		ol(spike(r, head, V(0, 0.55, -0.2), V(0, 1.15, 0.35), 0.7, HC.Ghost, M.Neon, true, 0.1))
		-- наплечники
		for _, s in ipairs({ 1, -1 }) do
			local sh = bevel(r, B, V(0.9, 0.4, 1.05), CF(1.15 * s, 1.0, 0) * ANG(0, 0, rad(-18 * s)), HC.GhostDeep, HC.Ghost)
			ol({ sh[#sh] })
		end
		-- рука с мечом (ArmR) и щитом (ArmL)
		local armR = hub(r, "ArmR", B, CF(1.25, 0.6, 0))
		r:Seg(armR, V(0, 0, 0), V(0.1, -1.0, -0.3), 0.4, HC.Ghost, M.Plastic, gT)
		r:Box(armR, V(0.18, 0.18, 0.7), CF(0.1, -1.05, -0.35), HC.GhostDeep, M.Metal)
		r:Box(armR, V(0.7, 0.14, 0.14), CF(0.1, -1.05, -0.7), HC.Ghost, M.Metal)
		local bladeA, bladeB = V(0.1, -1.05, -0.75), V(0.1, -1.05, -3.2)
		r:Seg(armR, bladeA, bladeB, V2(0.1, 0.32), HC.GhostMid, M.Metal)
		ol({ r:Seg(armR, bladeA + V(0, 0.17, 0), bladeB + V(0, 0.05, 0), V2(0.06, 0.06), HC.Ghost, M.Neon) })
		ol(spike(r, armR, bladeB, bladeB + V(0, 0, -0.45), 0.32, HC.Ghost, M.Neon, true, 0.1))
		local armL = hub(r, "ArmL", B, CF(-1.25, 0.6, 0))
		r:Seg(armL, V(0, 0, 0), V(-0.1, -1.0, -0.3), 0.4, HC.Ghost, M.Plastic, gT)
		local sh = bevel(r, armL, V(0.25, 1.9, 1.3), CF(-0.35, -0.9, -0.45), HC.GhostDeep, HC.Ghost)
		ol({ sh[#sh] })
		gem(r, armL, 0.4, CF(-0.5, -0.8, -0.45) * ANG(0, -PI / 2, 0), HC.Ghost)
		mark(outline, "Outline")
		local e = emitPoint(r, B, CF(0, -1.6, 0.2), V(0.9, 0.4, 0.9))
		emitter(e, HC.GhostMid, { Smoke = true, Rate = 6, Size = 0.8, SizeEnd = 1.4, LifeMin = 0.6, LifeMax = 1.1, Accel = V(0, 0.8, 0), T0 = 0.55 })
		r:Glow(B, HC.Ghost, 7, 0.8)
		return finishCreature(r, scale, 2.6, 4.2)
	end

	------------------------------------------------------------------------
	-- 4. BONE GUARD — скелет в тяжёлой железно-костяной броне с башенным щитом; броня ломается на 50%
	------------------------------------------------------------------------
	local function BoneGuard(scale)
		local r = newBiped("BoneGuard", V(1.15, 1.15, 1.15))
		setup(r, { Style = "Heavy", Gait = { Speed = 0.8, Stride = 0.4, Bob = 0.12, Sway = 0.06, Shake = 0.08 }, Death = "Collapse" })
		r.DeathFX = "BoneShards"
		local T, Hd, RA, LA, RL, LL = r.Torso, r.Head, r.RArm, r.LArm, r.RLeg, r.LLeg
		local glow = HC.Green
		local armor = {}
		local function arm(list)
			for _, p in ipairs(list) do
				armor[#armor + 1] = p
			end
			return list
		end
		-- скелет: позвоночник, рёбра, таз
		r:Box(T, V(0.3, 2, 0.3), CF(0, 0, 0.25), C.BoneDark, M.Plastic)
		for i = 0, 3 do
			r:Box(T, V(1.7 - i * 0.15, 0.14, 0.9), CF(0, 0.75 - i * 0.35, 0), C.Bone, M.Plastic)
		end
		r:Box(T, V(1.6, 0.4, 0.8), CF(0, -0.8, 0), C.BoneDark, M.Plastic)
		-- череп
		bevel(r, Hd, V(1.05, 1.0, 1.1), CF(0, 0.05, 0), C.Bone, C.BoneDark, M.Plastic)
		for _, s in ipairs({ -1, 1 }) do
			r:Box(Hd, V(0.3, 0.28, 0.06), CF(0.24 * s, 0.1, -0.56), rgb(16, 14, 18), M.Plastic)
			r:Neon(Hd, V(0.13, 0.12, 0.06), CF(0.24 * s, 0.1, -0.59), glow)
		end
		r:Box(Hd, V(0.7, 0.18, 0.06), CF(0, -0.32, -0.56), rgb(16, 14, 18), M.Plastic)
		-- кости рук и ног
		for _, A in ipairs({ RA, LA }) do
			bar(r, A, V(0, 0.6, 0), V(0, -0.9, 0), 0.32, C.Bone)
			r:Box(A, V(0.5, 0.35, 0.5), CF(0, -1.0, 0), C.BoneDark, M.Plastic)
		end
		for _, Lg in ipairs({ RL, LL }) do
			bar(r, Lg, V(0, 0.9, 0), V(0, -0.7, 0), 0.34, C.Bone)
			bootA(r, Lg, HC.Iron, HC.IronHi, 1.05)
		end
		-- БРОНЯ (ломается): нагрудник, шлем, наплечники, наручи, поножи
		arm(bevel(r, T, V(2.15, 1.25, 1.15), CF(0, 0.45, 0), HC.Iron, HC.IronHi))
		arm({ r:Wedge(T, V(2.0, 0.45, 0.45), CF(0, 0.55, -0.75) * ANG(PI, PI, 0), HC.Iron, M.Metal) })
		arm(gem(r, T, 0.32, CF(0, 0.5, -0.62), glow, HC.Rust))
		arm(bevel(r, T, V(2.1, 0.45, 1.1), CF(0, -0.45, 0), HC.Rust, HC.IronHi))
		arm(bevel(r, Hd, V(1.25, 0.55, 1.25), CF(0, 0.45, 0.02), HC.Iron, HC.IronHi))
		arm(spike(r, Hd, V(0, 0.7, 0.1), V(0, 1.3, 0.4), 0.55, HC.Iron, M.Metal, true, 0.1))
		for _, s in ipairs({ -1, 1 }) do
			arm(hornA(r, Hd, { V(0.55 * s, 0.4, 0), V(0.85 * s, 0.6, 0), V(0.9 * s, 1.05, 0.1) }, 0.2, C.Bone))
		end
		for _, a in ipairs({ { RA, 1 }, { LA, -1 } }) do
			local A, s = a[1], a[2]
			arm(bevel(r, A, V(1.35, 0.55, 1.3), CF(0.15 * s, 0.85, 0) * ANG(0, 0, rad(-14 * s)), HC.Iron, HC.IronHi))
			arm(spike(r, A, V(0.35 * s, 1.1, 0), V(0.8 * s, 1.75, 0), 0.4, C.Bone, M.Plastic, true, 0.12))
			arm(bevel(r, A, V(0.85, 0.7, 0.85), CF(0, -0.45, 0), HC.Rust, HC.IronHi))
		end
		for _, Lg in ipairs({ RL, LL }) do
			arm(bevel(r, Lg, V(1.05, 0.8, 1.05), CF(0, 0.4, 0), HC.Iron, HC.IronHi))
		end
		-- ржавый тесак в правой руке
		r:Box(RA, V(0.18, 0.18, 0.6), CF(0, -1.05, -0.3), HC.Burnt, WOOD)
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
		setup(r, { Style = "Biped", Gait = { Speed = 0.9, Stride = 0.5, Bob = 0.14, Sway = 0.16, Lean = 4 }, Death = "Topple" })
		r.DeathFX = "Straw"
		local T, Hd, RA, LA, RL, LL = r.Torso, r.Head, r.RArm, r.LArm, r.RLeg, r.LLeg
		-- клетчатая рубаха: бордовый с тёмными полосами, верёвочный пояс
		bevel(r, T, V(2, 2, 1), CF(), HC.Burgundy, HC.BurgundyHi, M.Fabric)
		r:Box(T, V(0.18, 2.02, 1.02), CF(-0.45, 0, 0), HC.Burnt, M.Fabric)
		r:Box(T, V(0.18, 2.02, 1.02), CF(0.45, 0, 0), HC.Burnt, M.Fabric)
		r:Box(T, V(2.04, 0.2, 1.04), CF(0, -0.8, 0), HC.StrawDark, M.Fabric)
		-- шест за спиной
		r:Box(T, V(0.3, 4.5, 0.3), CF(0, 0.4, 0.75), HC.Burnt, WOOD)
		-- мешок-голова: сшитые глаза-кресты, светящийся рот-шов
		bevel(r, Hd, V(1.2, 1.25, 1.2), CF(), HC.Sack, HC.SackDark, M.Fabric)
		for _, s in ipairs({ -1, 1 }) do
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
		for _, a in ipairs({ { RA, 1 }, { LA, -1 } }) do
			local A, s = a[1], a[2]
			bevel(r, A, V(1.0, 2, 1.0), CF(0, 0.1, 0), HC.Burgundy, HC.BurgundyHi, M.Fabric)
			for k = -1, 1 do
				spike(r, A, V(k * 0.25, -0.85, 0), V(k * 0.4, -1.55, k * 0.1), 0.25, HC.Straw, M.Fabric, true, 0.05)
			end
		end
		-- штаны с заплатой
		for _, Lg in ipairs({ RL, LL }) do
			bevel(r, Lg, V(1, 2, 1), CF(), HC.Rag, HC.RagHi, M.Fabric)
			spike(r, Lg, V(0, -0.9, 0), V(0.05, -1.3, -0.2), 0.5, HC.Straw, M.Fabric, true, 0.05)
		end
		r:Box(LL, V(0.5, 0.5, 0.06), CF(0.1, 0.2, -0.52), HC.SackDark, M.Fabric)
		-- ворона на левом плече
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
	-- 6. STRAW CREATURE — маленький соломенный бегун из пугала
	------------------------------------------------------------------------
	local function StrawMinion(scale)
		local r = newBiped("StrawMinion", V(1.0, 1.0, 1.0))
		setup(r, { Style = "Biped", Gait = { Speed = 1.5, Stride = 0.9, Bob = 0.25, Sway = 0.1, Lean = 12 }, Death = "Scatter" })
		r.DeathFX = "Straw"
		local T, Hd, RA, LA, RL, LL = r.Torso, r.Head, r.RArm, r.LArm, r.RLeg, r.LLeg
		r:Box(T, V(1.7, 2, 0.95), CF(), HC.Straw, M.Fabric)
		r:Box(T, V(1.74, 0.22, 1.0), CF(0, 0.4, 0), HC.SackDark, M.Fabric)
		r:Box(T, V(1.74, 0.22, 1.0), CF(0, -0.5, 0), HC.SackDark, M.Fabric)
		r:Box(Hd, V(1.0, 1.0, 1.0), CF(), HC.Sack, M.Fabric)
		r:Neon(Hd, V(0.18, 0.18, 0.05), CF(-0.22, 0.1, -0.51), HC.Fire)
		r:Neon(Hd, V(0.18, 0.18, 0.05), CF(0.22, 0.1, -0.51), HC.Fire)
		spike(r, Hd, V(0, 0.45, 0), V(0.1, 1.05, 0.1), 0.45, HC.Straw, M.Fabric, true, 0.06)
		for _, A in ipairs({ RA, LA }) do
			r:Box(A, V(0.6, 2, 0.6), CF(), HC.StrawDark, M.Fabric)
		end
		for _, Lg in ipairs({ RL, LL }) do
			r:Box(Lg, V(0.7, 2, 0.7), CF(), HC.StrawDark, M.Fabric)
		end
		return finishBiped(r, scale, { RS = { -20, 0, 10 }, LS = { -20, 0, -10 } })
	end

	------------------------------------------------------------------------
	-- 7. FOG WARLOCK — колдун в капюшоне с фонарём на посохе, серо-зелёный туман
	------------------------------------------------------------------------
	local function FogWarlock(scale)
		local r = newBiped("FogWarlock", V(1.2, 1.2, 1.2))
		setup(r, { Style = "Biped", Gait = { Speed = 0.8, Stride = 0.35, Bob = 0.06, Sway = 0.06, Lean = 6 }, Death = "Dissipate" })
		r.DeathFX = "Fog"
		local T, Hd, RA, LA, RL, LL = r.Torso, r.Head, r.RArm, r.LArm, r.RLeg, r.LLeg
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
		for _, s in ipairs({ -1, 1 }) do
			r:Neon(Hd, V(0.2, 0.08, 0.05), CF(0.22 * s, 0.0, fz + 0.2) * ANG(0, 0, rad(-12 * s)), HC.Green)
		end
		-- рукава
		for _, A in ipairs({ RA, LA }) do
			bevel(r, A, V(1.0, 2, 1.0), CF(), robeC, robeHi, M.Fabric)
			r:Box(A, V(1.15, 0.4, 1.15), CF(0, -0.85, 0), robeHi, M.Fabric)
		end
		for _, Lg in ipairs({ RL, LL }) do
			r:Box(Lg, V(0.9, 2, 0.9), CF(), HC.Rag, M.Fabric)
		end
		-- посох с фонарём
		r:Box(RA, V(0.2, 5.0, 0.2), CF(0, -0.6, -0.5), HC.Burnt, WOOD)
		local lantern = hub(r, "SwayLantern", RA, CF(0, 1.9, -0.5), { Amp = 0.2, Speed = 2 })
		r:Box(lantern, V(0.08, 0.5, 0.08), CF(0, -0.25, 0), HC.Iron, M.Metal)
		bevel(r, lantern, V(0.6, 0.12, 0.6), CF(0, -0.55, 0), HC.Iron, HC.IronHi)
		r:Neon(lantern, V(0.4, 0.55, 0.4), CF(0, -0.9, 0), HC.Green)
		bevel(r, lantern, V(0.6, 0.12, 0.6), CF(0, -1.25, 0), HC.Iron, HC.IronHi)
		r:Glow(lantern, HC.Green, 8, 1.1)
		-- постоянный лёгкий туман у ног и импульс тумана (FogFX включает Renderer)
		local e = emitPoint(r, T, CF(0, -2.6, 0), V(2.2, 0.3, 2.2))
		emitter(e, HC.Fog, { Smoke = true, Rate = 4, Size = 1.2, SizeEnd = 2.4, LifeMin = 1, LifeMax = 1.8, SpeedMin = 0.3, SpeedMax = 0.8, T0 = 0.65 })
		local fog = emitter(e, rgb(150, 190, 150), { Smoke = true, Rate = 30, Size = 2.5, SizeEnd = 5.5, LifeMin = 1.2, LifeMax = 2.0, SpeedMin = 3, SpeedMax = 6, T0 = 0.55, Off = true })
		if fog then
			fog.Name = "FogFX"
		end
		return finishBiped(r, scale, { RS = { 25, 0, 4 }, LS = { 30, 0, -12 }, Neck = { 8, 0, 0 } })
	end

	------------------------------------------------------------------------
	-- 8. PUMPKIN BRUTE — огромный громила с гигантской тыквой вместо головы
	------------------------------------------------------------------------
	local function PumpkinBrute(scale)
		local r = newBiped("PumpkinBrute", V(1.6, 1.4, 1.6))
		setup(r, { Style = "Heavy", Gait = { Speed = 0.75, Stride = 0.35, Bob = 0.22, Sway = 0.1, Shake = 0.14, Lean = 6 }, Death = "Topple" })
		r.DeathFX = "PumpkinBurst"
		local T, Hd, RA, LA, RL, LL = r.Torso, r.Head, r.RArm, r.LArm, r.RLeg, r.LLeg
		local skin, skinHi = rgb(60, 72, 44), rgb(104, 120, 76)
		-- массивное тело в мешковине, лямки, лозы
		bevel(r, T, V(2.8, 2.2, 1.7), CF(0, 0.15, 0.1), HC.Rag, HC.RagHi, M.Fabric)
		bevel(r, T, V(2.4, 0.9, 1.5), CF(0, -0.75, -0.05), HC.SackDark, HC.Sack, M.Fabric)
		for _, s in ipairs({ -1, 1 }) do
			r:Box(T, V(0.3, 2.2, 0.08), CF(0.7 * s, 0.2, -0.82), HC.Burnt, M.Fabric)
			r:Box(T, V(0.32, 0.32, 0.1), CF(0.7 * s, 0.85, -0.86), HC.GoldDark, M.Metal)
		end
		bar(r, T, V(-1.3, 0.9, -0.85), V(1.2, -0.4, -0.88), 0.16, HC.Stem)
		spike(r, T, V(0.3, 0.3, -0.9), V(0.6, 0.55, -1.15), 0.3, HC.Stem, M.Plastic, true, 0.06)
		-- гигантская тыква
		pumpkin(r, Hd, CF(0, 0.3, -0.05), 1.15)
		r:Glow(Hd, HC.Fire, 9, 1.2)
		-- огромные руки
		for _, a in ipairs({ { RA, 1 }, { LA, -1 } }) do
			local A, s = a[1], a[2]
			bevel(r, A, V(1.4, 1.2, 1.4), CF(0.15 * s, 0.5, 0), skin, skinHi, M.Plastic)
			bevel(r, A, V(1.6, 1.4, 1.6), CF(0.2 * s, -0.75, 0), skin, skinHi, M.Plastic)
			bar(r, A, V(0.2 * s, 0.3, -0.75), V(0.25 * s, -0.9, -0.82), 0.12, HC.Stem)
			bevel(r, A, V(1.5, 0.8, 1.5), CF(0.2 * s, -1.7, -0.05), skin, skinHi, M.Plastic)
		end
		-- дубина-коряга в правой руке
		bar(r, RA, V(0.2, -1.8, -0.4), V(0.25, -1.9, -3.2), 0.45, HC.Burnt, WOOD)
		spike(r, RA, V(0.25, -1.9, -2.6), V(0.85, -1.6, -2.9), 0.3, C.BoneDark)
		spike(r, RA, V(0.25, -1.9, -3.0), V(-0.35, -2.3, -3.2), 0.3, C.BoneDark)
		for _, Lg in ipairs({ RL, LL }) do
			bevel(r, Lg, V(1.25, 2, 1.25), CF(0, 0.05, 0), HC.SackDark, HC.Sack, M.Fabric)
			bevel(r, Lg, V(1.3, 0.55, 1.5), CF(0, -0.8, -0.12), HC.Burnt, HC.RagHi, M.Plastic)
		end
		emitter(Hd, HC.Fire, { Rate = 6, Size = 0.25, LifeMin = 0.4, LifeMax = 0.8, SpeedMin = 1, SpeedMax = 2, Accel = V(0, 2.5, 0) })
		return finishBiped(r, scale, { Root = { 10, 0, 0 }, Neck = { -8, 0, 0 }, RS = { 10, 0, 8 }, LS = { 8, 0, -8 } })
	end

	------------------------------------------------------------------------
	-- 9. NIGHT REAPER (мини-босс) — парящий жнец с косой, рваный плащ, щит-оболочка (ShieldFX)
	------------------------------------------------------------------------
	local function NightReaper(scale)
		local r = newCreature("NightReaper", V(2.0, 2.0, 1.2))
		setup(r, { Style = "Float", Gait = { Bob = 0.3 }, Death = "Dissipate", Spawn = "Fade" })
		r.DeathFX = "Reaper"
		local B = r.Torso
		local cloth, clothHi = rgb(24, 18, 32), rgb(78, 56, 104)
		local glow = HC.PurpleGlow
		-- плащ-балахон, сужающийся книзу
		bevel(r, B, V(2.2, 1.6, 1.3), CF(0, 0.5, 0), cloth, clothHi, M.Fabric)
		bevel(r, B, V(1.9, 1.3, 1.15), CF(0, -0.85, 0.05), cloth, clothHi, M.Fabric)
		bevel(r, B, V(1.4, 1.0, 0.95), CF(0, -1.95, 0.1), cloth, clothHi, M.Fabric)
		tatter(r, B, -2.4, -0.45, 1.5, 4, cloth, M.Fabric, 3)
		spike(r, B, V(0, -2.3, 0.2), V(0.2, -3.3, 0.5), 0.9, cloth, M.Fabric, true, 0.12)
		-- цепь-пояс и черепа
		chain(r, B, 3, 0.35, HC.IronHi, CF(0.6, -0.3, -0.6) * ANG(0, 0, rad(70)))
		r:Box(B, V(0.42, 0.42, 0.4), CF(-0.55, -0.25, -0.62), C.Bone, M.Plastic)
		-- капюшон с черепом
		local head = hub(r, "BobHead", B, CF(0, 1.75, 0), { Amp = 0.06, Speed = 1.6 })
		local fz = deepHood(r, head, 1.6, 1.55, cloth, clothHi)
		spike(r, head, V(0, 0.7, 0.35), V(0, 1.4, 1.1), 0.85, cloth, M.Fabric, true, 0.2)
		r:Box(head, V(0.95, 1.0, 0.3), CF(0, -0.1, fz + 0.15), C.Bone, M.Plastic)
		for _, s in ipairs({ -1, 1 }) do
			r:Box(head, V(0.3, 0.26, 0.06), CF(0.24 * s, 0.02, fz - 0.01), rgb(10, 8, 14), M.Plastic)
			r:Neon(head, V(0.14, 0.12, 0.06), CF(0.24 * s, 0.01, fz - 0.04), glow)
		end
		r:Box(head, V(0.6, 0.12, 0.06), CF(0, -0.38, fz - 0.01), rgb(10, 8, 14), M.Plastic)
		-- наплечная накидка с рваными концами
		for _, s in ipairs({ -1, 1 }) do
			bevel(r, B, V(1.0, 0.45, 1.4), CF(1.0 * s, 1.15, 0) * ANG(0, 0, rad(-20 * s)), cloth, clothHi, M.Fabric)
			spike(r, B, V(1.35 * s, 0.9, 0), V(1.6 * s, 0.1, 0.1), 0.6, cloth, M.Fabric, true, 0.1)
		end
		-- руки-кости с косой
		local armR = hub(r, "ArmR", B, CF(1.3, 0.75, 0))
		bar(r, armR, V(0, 0, 0), V(0.1, -1.0, -0.4), V2(0.6, 0.6), cloth)
		r:Box(armR, V(0.35, 0.35, 0.35), CF(0.1, -1.15, -0.45), C.Bone, M.Plastic)
		r:Box(armR, V(0.2, 5.4, 0.2), CF(0.1, -0.9, -0.55), HC.Burnt, WOOD)
		local top = V(0.1, 1.75, -0.55)
		local pts = { top, top + V(0, 0.2, -0.8), top + V(0, -0.15, -1.9), top + V(0, -0.8, -2.5) }
		for i = 1, 3 do
			bar(r, armR, pts[i], pts[i + 1], V2(0.1, 0.45 - i * 0.08), HC.IronHi, M.Metal)
		end
		bar(r, armR, pts[2] + V(0, -0.2, 0), pts[3] + V(0, -0.15, 0), V2(0.12, 0.06), glow, M.Neon)
		local armL = hub(r, "ArmL", B, CF(-1.3, 0.75, 0))
		bar(r, armL, V(0, 0, 0), V(-0.1, -1.0, -0.4), V2(0.6, 0.6), cloth)
		for k = -1, 1 do
			spike(r, armL, V(-0.1 + k * 0.1, -1.2, -0.45), V(-0.15 + k * 0.15, -1.75, -0.65), 0.12, C.Bone, M.Plastic, true, 0.05)
		end
		-- оболочка щита: фиолетовые плиты вокруг (скрыты, включает Renderer)
		local shell = hub(r, "OrbitShield", B, CF(0, 0, 0), { Speed = 0.6 })
		local plates = {}
		for i = 0, 5 do
			local a = i / 6 * PI * 2
			local p = r:Box(shell, V(1.5, 2.6, 0.12), CF(math.cos(a) * 2.2, 0, math.sin(a) * 2.2) * ANG(0, -a + PI / 2, 0), glow, M.Neon, { Transparency = 0.6 })
			p.Name = "ShieldFX"
			plates[#plates + 1] = p
		end
		hide(plates, 0.6)
		local e = emitPoint(r, B, CF(0, -2.6, 0.2), V(1.2, 0.4, 1.2))
		emitter(e, rgb(60, 30, 90), { Smoke = true, Rate = 6, Size = 1.0, SizeEnd = 1.8, LifeMin = 0.7, LifeMax = 1.2, Accel = V(0, 0.8, 0), T0 = 0.55 })
		r:Glow(head, glow, 8, 1)
		return finishCreature(r, scale, 3.4, 5.2)
	end

	------------------------------------------------------------------------
	-- 10. GRAVE WARDEN (босс, Лёгкая) — каменно-железный страж кладбища: надгробие-щит, молот,
	-- фонарь на поясе. 66% — трещины по броне, 33% — плиты брони отваливаются.
	------------------------------------------------------------------------
	local function GraveWarden(scale)
		local r = newBiped("GraveWarden", V(1.35, 1.3, 1.35))
		setup(r, { Style = "Heavy", Gait = { Speed = 0.7, Stride = 0.36, Bob = 0.2, Sway = 0.08, Shake = 0.3, Lean = 3 }, Death = "Collapse", Spawn = "Titan" })
		r.SpawnFX = "GraveBreak"
		r.DeathFX = "GraveBreak"
		local T, Hd, RA, LA, RL, LL = r.Torso, r.Head, r.RArm, r.LArm, r.RLeg, r.LLeg
		local glow = HC.Green
		local function stone(limb, size, cf, light)
			return bevel(r, limb, size, cf, light and HC.Stone or HC.StoneDark, light and HC.StoneHi or HC.Stone, M.Slate)
		end
		local plates = {}
		local function pl(list)
			for _, p in ipairs(list) do
				plates[#plates + 1] = p
			end
			return list
		end
		-- каменное тело
		r:Box(T, V(2.1, 2.0, 1.2), CF(0, 0.1, 0.05), HC.Green, M.Neon)
		stone(T, V(1.2, 1.15, 1.45), CF(-0.6, 0.6, 0.05) * ANG(rad(3), rad(5), rad(4)), false)
		stone(T, V(1.2, 1.1, 1.45), CF(0.62, 0.62, 0.05) * ANG(rad(-3), rad(-4), rad(-5)), true)
		stone(T, V(2.2, 0.95, 1.4), CF(0, -0.45, 0), false)
		-- железные латы (отваливаются на 33%)
		pl(bevel(r, T, V(2.6, 1.2, 0.5), CF(0, 0.6, -0.8), HC.Iron, HC.IronHi))
		pl({ r:Wedge(T, V(2.4, 0.5, 0.5), CF(0, -0.2, -0.8) * ANG(PI, PI, 0), HC.Iron, M.Metal) })
		pl(gem(r, T, 0.45, CF(0, 0.6, -1.08), glow, HC.GoldDark))
		bevel(r, T, V(2.3, 0.45, 1.6), CF(0, -1.0, 0), HC.Rust, HC.IronHi)
		-- фонарь на поясе
		r:Box(T, V(0.08, 0.4, 0.08), CF(-0.8, -1.3, -0.82), HC.Iron, M.Metal)
		bevel(r, T, V(0.55, 0.12, 0.55), CF(-0.8, -1.5, -0.82), HC.Iron, HC.IronHi)
		r:Neon(T, V(0.38, 0.5, 0.38), CF(-0.8, -1.8, -0.82), HC.Fire)
		bevel(r, T, V(0.55, 0.12, 0.55), CF(-0.8, -2.1, -0.82), HC.Iron, HC.IronHi)
		r:Glow(T, HC.Fire, 8, 0.8)
		-- шлем-череп с короной-зубцами надгробий
		stone(Hd, V(1.3, 1.25, 1.3), CF(0, -0.05, 0.05), true)
		pl(bevel(r, Hd, V(1.5, 0.7, 1.45), CF(0, 0.35, -0.05), HC.Iron, HC.IronHi))
		r:Box(Hd, V(1.0, 0.16, 0.06), CF(0, 0.0, -0.68), rgb(10, 12, 10), M.Plastic)
		for _, s in ipairs({ -1, 1 }) do
			r:Neon(Hd, V(0.26, 0.1, 0.06), CF(0.25 * s, 0.0, -0.71), glow)
		end
		for i = -1, 1 do
			stone(Hd, V(0.4, 0.55 + (i == 0 and 0.25 or 0), 0.25), CF(i * 0.45, 0.95, 0.1), i == 0)
		end
		-- наплечники-плиты
		for _, a in ipairs({ { RA, 1 }, { LA, -1 } }) do
			local A, s = a[1], a[2]
			pl(pauldron(r, A, s, 1.2, HC.Iron, HC.IronHi, glow, 1))
			stone(A, V(1.05, 1.0, 1.05), CF(0, 0.1, 0) * ANG(0, rad(10), rad(4 * s)), false)
			stone(A, V(1.2, 0.9, 1.2), CF(0, -0.75, 0), true)
			bevel(r, A, V(1.4, 0.7, 1.4), CF(0, -1.45, -0.05), HC.Iron, HC.IronHi)
		end
		-- большой молот-надгробие в правой руке
		r:Box(RA, V(0.3, 0.3, 4.2), CF(0, -1.45, -1.7), HC.Burnt, WOOD)
		stone(RA, V(1.5, 1.2, 1.0), CF(0, -1.45, -4.0), true)
		r:Box(RA, V(0.15, 0.7, 0.1), CF(0, -1.4, -4.52), HC.StoneDark, M.Slate)
		r:Box(RA, V(0.5, 0.15, 0.1), CF(0, -1.25, -4.52), HC.StoneDark, M.Slate)
		-- надгробие-щит в левой руке: плита с закруглённым верхом и крестом
		stone(LA, V(0.45, 2.8, 2.0), CF(-0.7, -0.7, -0.35), false)
		stone(LA, V(0.45, 0.6, 1.5), CF(-0.7, 0.95, -0.35), false)
		stone(LA, V(0.45, 0.35, 0.9), CF(-0.7, 1.35, -0.35), false)
		r:Neon(LA, V(0.08, 1.4, 0.2), CF(-0.95, -0.1, -0.35), glow)
		r:Neon(LA, V(0.08, 0.2, 0.9), CF(-0.95, 0.25, -0.35), glow)
		for _, s in ipairs({ -1, 1 }) do
			r:Box(LA, V(0.5, 0.5, 0.25), CF(-0.7, -1.9, -0.35 + s * 0.85), HC.Moss, GRASS)
		end
		for _, Lg in ipairs({ RL, LL }) do
			stone(Lg, V(1.15, 1.05, 1.15), CF(0, 0.45, 0), true)
			pl(bevel(r, Lg, V(1.2, 0.7, 1.2), CF(0, -0.42, 0), HC.Iron, HC.IronHi))
			bootA(r, Lg, HC.Rust, HC.IronHi, 1.25)
		end
		-- мох на плечах и цепь
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
	-- 50% — красное свечение (глаза и ядро), ярость.
	------------------------------------------------------------------------
	local function FogReaper(scale)
		local r = newCreature("FogReaper", V(2.4, 2.2, 1.4))
		setup(r, { Style = "Float", Gait = { Bob = 0.35 }, Death = "Implode", Spawn = "Fade" })
		r.SpawnFX = "FogVortex"
		r.DeathFX = "Fog"
		local B = r.Torso
		local cloth, clothHi = rgb(40, 44, 48), rgb(120, 130, 134)
		local fogT = { Transparency = 0.35 }
		-- слоистый балахон из тумана
		bevel(r, B, V(2.6, 1.8, 1.5), CF(0, 0.6, 0), cloth, clothHi, M.Fabric)
		bevel(r, B, V(2.3, 1.4, 1.35), CF(0, -0.9, 0.05), cloth, clothHi, M.Fabric)
		r:Box(B, V(2.0, 1.2, 1.2), CF(0, -2.1, 0.1), HC.FogDark, M.Fabric, fogT)
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
		-- капюшон с черепом
		local head = hub(r, "BobHead", B, CF(0, 2.05, 0), { Amp = 0.07, Speed = 1.4 })
		local fz = deepHood(r, head, 1.8, 1.7, cloth, clothHi)
		spike(r, head, V(0, 0.75, 0.4), V(0, 1.6, 1.3), 1.0, cloth, M.Fabric, true, 0.2)
		r:Box(head, V(1.05, 1.1, 0.3), CF(0, -0.12, fz + 0.15), C.Bone, M.Plastic)
		local whiteEyes, redEyes = {}, {}
		for _, s in ipairs({ -1, 1 }) do
			r:Box(head, V(0.34, 0.28, 0.06), CF(0.26 * s, 0.02, fz - 0.01), rgb(10, 10, 14), M.Plastic)
			whiteEyes[#whiteEyes + 1] = r:Neon(head, V(0.16, 0.13, 0.06), CF(0.26 * s, 0.01, fz - 0.04), HC.Ghost)
			redEyes[#redEyes + 1] = r:Neon(head, V(0.2, 0.16, 0.06), CF(0.26 * s, 0.01, fz - 0.06), HC.Red)
		end
		r:Box(head, V(0.7, 0.12, 0.06), CF(0, -0.45, fz - 0.01), rgb(10, 10, 14), M.Plastic)
		-- высокий воротник и наплечная накидка
		bevel(r, B, V(2.9, 0.6, 1.8), CF(0, 1.45, 0.1), cloth, clothHi, M.Fabric)
		for _, s in ipairs({ -1, 1 }) do
			spike(r, B, V(1.2 * s, 1.6, 0.1), V(1.9 * s, 2.4, 0.4), 0.8, cloth, M.Fabric, true, 0.12)
			spike(r, B, V(1.45 * s, 1.1, 0), V(1.8 * s, 0.0, 0.1), 0.7, cloth, M.Fabric, true, 0.1)
		end
		-- руки с двойной косой
		local armR = hub(r, "ArmR", B, CF(1.55, 0.95, 0))
		bar(r, armR, V(0, 0, 0), V(0.15, -1.1, -0.45), V2(0.7, 0.7), cloth)
		r:Box(armR, V(0.4, 0.4, 0.4), CF(0.15, -1.25, -0.5), C.Bone, M.Plastic)
		r:Box(armR, V(0.22, 6.4, 0.22), CF(0.15, -1.25, -0.6), HC.Iron, M.Metal)
		for _, e in ipairs({ { 1.95, 1 }, { -4.45, -1 } }) do
			local top = V(0.15, e[1], -0.6)
			local d = e[2]
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
		local e = emitPoint(r, B, CF(0, -3.2, 0.2), V(2.2, 0.5, 2.2))
		emitter(e, HC.Fog, { Smoke = true, Rate = 8, Size = 1.6, SizeEnd = 3.2, LifeMin = 1, LifeMax = 1.8, SpeedMin = 0.3, SpeedMax = 1, Accel = V(0, 0.6, 0), T0 = 0.6 })
		local fog = emitter(e, rgb(170, 180, 175), { Smoke = true, Rate = 40, Size = 3, SizeEnd = 7, LifeMin = 1.2, LifeMax = 2.2, SpeedMin = 4, SpeedMax = 8, T0 = 0.55, Off = true })
		if fog then
			fog.Name = "FogFX"
		end
		-- 50%: красные глаза и ядро, красный дым
		local core = hide(join(redEyes, { r:Box(B, V(0.7, 0.7, 0.2), CF(0, 0.55, -0.82) * ANG(0, 0, rad(45)), HC.Red, M.Neon) }))
		local red = emitter(B, HC.Red, { Rate = 14, Size = 0.45, SpeedMin = 1, SpeedMax = 3, Accel = V(0, 2, 0), Off = true })
		local redSmoke = emitter(e, rgb(150, 30, 30), { Smoke = true, Rate = 6, Size = 1.4, SizeEnd = 2.8, LifeMin = 0.8, LifeMax = 1.4, T0 = 0.6, Off = true })
		r.Phases = {
			{ At = 0.5, Reveal = core, Break = whiteEyes, Emit = { red, redSmoke }, Lights = { { light, 3 } }, Aggro = 1.3 },
		}
		if light then
			r.RedLight = light
		end
		return finishCreature(r, scale, 3.6, 6.0)
	end

	------------------------------------------------------------------------
	-- 12. CURSED MONARCH (босс, Сложная) — тёмный король с тыквой-головой в золотой короне,
	-- королевский плащ, посох-фонарь, огненная аура. 50% — красные глаза, огненные трещины на латах.
	------------------------------------------------------------------------
	local function CursedMonarch(scale)
		local r = newBiped("CursedMonarch", V(1.5, 1.4, 1.5))
		setup(r, { Style = "Heavy", Gait = { Speed = 0.7, Stride = 0.34, Bob = 0.18, Sway = 0.08, Shake = 0.35, Lean = 2 }, Death = "Implode", Spawn = "Titan" })
		r.SpawnFX = "MonarchPortal"
		r.DeathFX = "MonarchDeath"
		local T, Hd, RA, LA, RL, LL = r.Torso, r.Head, r.RArm, r.LArm, r.RLeg, r.LLeg
		local armorC, armorHi = rgb(30, 22, 34), HC.Gold
		-- торс: чёрные латы с золотым кантом, бордовый табард
		bevel(r, T, V(2.3, 2.1, 1.25), CF(0, 0.05, 0.05), armorC, armorHi)
		bevel(r, T, V(2.8, 1.1, 1.55), CF(0, 0.6, -0.05), rgb(44, 32, 50), armorHi)
		r:Wedge(T, V(2.5, 0.55, 0.5), CF(0, 0.6, -1.0) * ANG(PI, PI, 0), armorC, M.Metal)
		gem(r, T, 0.5, CF(0, 0.6, -0.88), HC.Fire, HC.Gold)
		bevel(r, T, V(1.1, 2.4, 0.15), CF(0, -1.1, -0.66), HC.Burgundy, HC.Gold, M.Fabric)
		tatter(r, T, -2.3, -0.66, 1.1, 3, HC.Burgundy, M.Fabric, 1)
		bevel(r, T, V(2.3, 0.45, 1.5), CF(0, -0.95, 0), armorC, armorHi)
		for _, s in ipairs({ -1, 1 }) do
			bevel(r, T, V(0.8, 0.9, 1.2), CF(0.85 * s, -1.4, -0.05) * ANG(0, 0, rad(12 * s)), armorC, armorHi)
		end
		-- королевский плащ с меховым воротником
		bevel(r, T, V(2.9, 0.5, 1.7), CF(0, 1.05, 0.1), rgb(220, 210, 190), rgb(160, 150, 130), M.Fabric)
		local cape = hub(r, "Cape", T, CF(0, 0.95, 0.8), nil)
		r:Box(cape, V(2.8, 2.6, 0.15), CF(0, -1.3, 0), HC.Burgundy, M.Fabric)
		local cape2 = hub(r, "Cape2", cape, CF(0, -2.6, 0), nil)
		r:Box(cape2, V(2.9, 2.2, 0.15), CF(0, -1.1, 0), HC.Burgundy, M.Fabric)
		r:Box(cape2, V(2.94, 0.16, 0.18), CF(0, -2.1, 0), HC.Gold, M.Metal)
		tatter(r, cape2, -2.2, 0, 2.9, 5, HC.Burgundy, M.Fabric, 4)
		-- тыква-голова (тёмная, выжженная)
		local ps = 1.2
		local _, eyesP, mouth = pumpkin(r, Hd, CF(0, 0.2, 0), ps, { Color = rgb(150, 66, 20), Dark = rgb(90, 36, 14), Edge = rgb(220, 120, 50) })
		local redEyes = {}
		for i in ipairs(eyesP) do
			local side = i == 1 and -1 or 1
			redEyes[i] = r:Neon(Hd, V(0.4, 0.34, 0.06) * ps, CF(0.36 * side * ps, 0.2 + 0.18 * ps, -0.84 * ps) * ANG(0, 0, rad(30 * side)), HC.Red)
		end
		local cy = 0.2 + 0.64 * ps + 0.1
		-- золотая корона (атрибут Crown)
		local crownParts = {}
		local function cp(list)
			for _, p in ipairs(list) do
				crownParts[#crownParts + 1] = p
			end
		end
		for i = 0, 3 do
			cp({ r:Box(Hd, V(1.6, 0.32, 0.14), CF(0, cy, 0) * ANG(0, i * PI / 2, 0) * CF(0, 0, -0.75), HC.Gold, M.Metal) })
		end
		for i = 0, 7 do
			local a = i / 8 * PI * 2
			local p = V(math.sin(a) * 0.75, cy + 0.1, -math.cos(a) * 0.75)
			cp(spike(r, Hd, p, p + V(0, (i % 2 == 0) and 0.8 or 0.5, 0), 0.34, HC.Gold, M.Metal, true, 0.1))
		end
		cp(gem(r, Hd, 0.26, CF(0, cy, -0.84), HC.Red))
		mark(crownParts, "Crown")
		local headLight = r:Glow(Hd, HC.Fire, 12, 1.4)
		-- наплечники и латные руки
		for _, a in ipairs({ { RA, 1 }, { LA, -1 } }) do
			local A, s = a[1], a[2]
			pauldron(r, A, s, 1.25, armorC, armorHi, HC.Fire, 2)
			bevel(r, A, V(1.1, 1.0, 1.1), CF(0, 0.1, 0), armorC, armorHi)
			bevel(r, A, V(1.25, 1.0, 1.25), CF(0, -0.75, 0), rgb(44, 32, 50), armorHi)
			bevel(r, A, V(1.15, 0.6, 1.15), CF(0, -1.45, -0.05), armorC, armorHi)
		end
		-- посох-фонарь: древко, золотая клетка, огненная тыква
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
		for _, Lg in ipairs({ RL, LL }) do
			bevel(r, Lg, V(1.2, 1.0, 1.2), CF(0, 0.45, 0), armorC, armorHi)
			bevel(r, Lg, V(1.2, 0.7, 1.2), CF(0, -0.4, 0), rgb(44, 32, 50), armorHi)
			bootA(r, Lg, armorC, armorHi, 1.3)
		end
		-- огненная аура всегда (вокруг ног)
		local feet = emitPoint(r, T, CF(0, -2.7, 0), V(3, 0.4, 3))
		emitter(feet, HC.Fire, { Rate = 14, Size = 0.5, SizeEnd = 0.1, LifeMin = 0.5, LifeMax = 1.0, SpeedMin = 1, SpeedMax = 2.5, Accel = V(0, 4, 0) })
		emitter(feet, rgb(80, 30, 10), { Smoke = true, Rate = 4, Size = 1.2, SizeEnd = 2.4, LifeMin = 0.8, LifeMax = 1.4, Accel = V(0, 1.5, 0), T0 = 0.6 })
		-- 50%: красные глаза вместо оранжевых, огненные трещины, больше огня
		local cracks = hide(join(
			redEyes,
			crack(r, T, { V(-1.05, 1.1, -0.84), V(-0.6, 0.7, -0.84), V(-0.85, 0.2, -0.84) }, 0.09, HC.Fire),
			crack(r, T, { V(1.0, 1.05, -0.84), V(0.55, 0.5, -0.84), V(0.8, 0.05, -0.84) }, 0.09, HC.Fire),
			crack(r, RA, { V(0.3, 0.3, -0.62), V(0.0, -0.3, -0.64), V(0.25, -0.9, -0.64) }, 0.07, HC.Fire),
			crack(r, LA, { V(-0.3, 0.3, -0.62), V(0.0, -0.3, -0.64), V(-0.25, -0.9, -0.64) }, 0.07, HC.Fire),
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
]======] }
FILES[#FILES + 1] = { "ReplicatedStorage", { "VoidTD", "EnemyModels" }, "ModuleScript", [======[
--!nocheck
-- VOID TD :: EnemyModels
-- Процедурные модели врагов (без внешних ассетов) в угловатом стиле: блоки с фаской и светлым кантом,
-- клинья, шипы, кристаллы-ромбы, рваная ткань, цепи. Модели — только визуал: урон и попадания считаются
-- на сервере по дистанции пути, поэтому размер брони не влияет на хитбокс.
--
-- EnemyModels.Build(enemyId) -> rig:
--   Model, Root, Motors, Base, Scale, Idle
--   Style      "Biped" | "Heavy" | "Crawl" | "Gallop" | "Float"
--   HipHeight, Height
--   Gait       { Speed, Stride, Bob, Sway, Lean, Shake }  параметры походки
--   Sec        { [motorName] = { Amp, Speed } }           вторичное движение (по префиксу имени мотора)
--              префиксы: Sway* (маятник), Cape* (плащ), Orbit* (вращение Y), Spin* (вращение Z),
--                        Bob* (парение вверх-вниз), Twitch* (резкие повороты головы)
--   Phases     { { At = 0.65, Reveal = {parts}, Break = {parts}, Emit = {emitters}, Lights = {{light, brightness}}, Aggro = 1.3 }, ... }
--              скрытые детали Reveal имеют Transparency = 1 и атрибут "PT" (целевая прозрачность)
--   DeathStyle "Dissipate" | "Scatter" | "Collapse" | "Topple" | "Implode"
--   SpawnStyle "Rise" | "Fade" | "Titan"

local UnitModels = require(script.Parent.UnitModels)
local Config = require(script.Parent.Config)

local Rig = UnitModels.Rig
local Kit = require(script.Parent.ModelKit)
local A_ = Kit.Colors
local spike = Kit.spike
local crack = Kit.crack
local ring = Kit.ring
local hide = Kit.hide
local join = Kit.join
local bevel = Kit.bevel
local bar = Kit.bar
local hornA = Kit.hornA
local gem = Kit.gem
local tatter = Kit.tatter
local pauldron = Kit.pauldron
local bootA = Kit.bootA
local squareRing = Kit.squareRing
local chain = Kit.chain

local V = Vector3.new
local V2 = Vector2.new
local CF = CFrame.new
local ANG = CFrame.Angles
local rad = math.rad
local PI = math.pi

local M = {
	Plastic = Enum.Material.SmoothPlastic,
	Metal = Enum.Material.Metal,
	Neon = Enum.Material.Neon,
	Fabric = Enum.Material.Fabric,
	Slate = Enum.Material.Slate,
}

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

-- Палитра Пустоты: тёмная база, средний тон, светлый край, кость, металл, золото, неон
local C = {
	Obsidian = rgb(22, 16, 30),
	Night = rgb(32, 23, 46),
	Deep = rgb(46, 31, 70),
	Mid = rgb(74, 50, 112),
	Lilac = rgb(122, 92, 170),
	Ghost = rgb(206, 192, 245),
	GhostMid = rgb(160, 132, 222),
	Bone = rgb(214, 204, 186),
	BoneDark = rgb(150, 138, 122),
	Gun = rgb(52, 50, 66),
	GunLight = rgb(92, 90, 112),
	Gold = rgb(196, 150, 64),
	GoldDark = rgb(130, 94, 40),
	Flesh = rgb(86, 26, 48),
	FleshLight = rgb(128, 44, 70),
	FleshDark = rgb(52, 16, 32),
	Stone = rgb(64, 60, 78),
	StoneLight = rgb(98, 92, 116),
	Neon = rgb(180, 80, 255),
	NeonSoft = rgb(222, 170, 255),
	Magenta = rgb(255, 60, 170),
	White = rgb(250, 244, 255),
	Steel = rgb(110, 110, 128),
}

-- встроенная текстура дыма клиента Roblox (content/textures/particles), не ассет из каталога
local SMOKE_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"

local EnemyModels = {}

local function lite()
	return UnitModels.Lite
end



------------------------------------------------------------------------
-- БАЗОВЫЕ ХЕЛПЕРЫ
------------------------------------------------------------------------

-- Существо без человеческого скелета: Root -> Torso (мотор "Root")
local function newCreature(name, bodySize)
	local self = setmetatable({}, Rig)
	local model = Instance.new("Model")
	model.Name = name
	self.Model = model
	self.Motors = {}
	self.Base = {}
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = V(1, 1, 1)
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanTouch = false
	root.CanQuery = false
	root.CFrame = CF()
	root.Parent = model
	self.Root = root

	local body = Instance.new("Part")
	body.Name = "Torso"
	body.Size = bodySize
	body.Color = C.Night
	body.Transparency = 1 -- форма тела строится эллипсоидами
	body.CanCollide = false
	body.CanTouch = false
	body.Massless = true
	body.CFrame = CF()
	body.Parent = model
	self.Torso = body
	self.Pending = {}
	self.PendingTrails = {}
	local m = Instance.new("Motor6D")
	m.Name = "Root"
	m.Part0 = root
	m.Part1 = body
	m.C0 = CF()
	m.C1 = CF()
	m.Parent = root
	self.Motors.Root = m
	return self
end

-- Скелет R6 с невидимыми базовыми конечностями: форма строится поверх
local function newBiped(name, headSize)
	local r = Rig.new({ Name = name, HeadSize = headSize or V(1.3, 1.3, 1.3), Torso = C.Night, Arm = C.Night, Leg = C.Night, Head = C.Night })
	for _, L in ipairs({ r.Torso, r.Head, r.RArm, r.LArm, r.RLeg, r.LLeg }) do
		L.Transparency = 1
	end
	return r
end

local function setup(r, o)
	r.Style = o.Style
	r.Gait = o.Gait or {}
	r.Sec = r.Sec or {}
	r.Phases = r.Phases or {}
	r.DeathStyle = o.Death or "Topple"
	r.SpawnStyle = o.Spawn or "Rise"
end




-- Невидимый узел на моторе
local function hub(r, name, limb, pivot, sec)
	local h = r:Joint(name, limb, V(0.2, 0.2, 0.2), pivot, CF(), C.Obsidian)
	h.Transparency = 1
	if sec then
		r.Sec[name] = sec
	end
	return h
end



-- Эмиттер частиц (nil в облегчённом режиме)
local function emitter(part, color, o)
	if lite() then
		return nil
	end
	o = o or {}
	local e = Instance.new("ParticleEmitter")
	e.Name = "EnemyFX"
	if o.Smoke then
		e.Texture = SMOKE_TEXTURE
	end
	e.Color = ColorSequence.new(color)
	e.LightEmission = o.Smoke and 0.3 or 1
	e.LightInfluence = o.Smoke and 0.4 or 0
	e.Rate = o.Rate or 8
	e.Lifetime = NumberRange.new(o.LifeMin or 0.6, o.LifeMax or 1.2)
	e.Speed = NumberRange.new(o.SpeedMin or 0.3, o.SpeedMax or 1.2)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-40, 40)
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, o.Size or 0.4),
		NumberSequenceKeypoint.new(1, o.SizeEnd or 0),
	})
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, o.T0 or 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	if o.Accel then
		e.Acceleration = o.Accel
	end
	if o.Off then
		e.Enabled = false
	end
	e.Parent = part
	return e
end

local function emitPoint(r, limb, offset, size)
	return r:Box(limb, size or V(0.6, 0.6, 0.6), offset, C.Obsidian, M.Plastic, { Transparency = 1, Name = "Emit" })
end

local function darkTrail(r, limb, a, b, color)
	if lite() then
		return
	end
	table.insert(r.PendingTrails, { limb, a, b, color })
end

local function afterFinish(r)
	for _, d in ipairs(r.Model:GetDescendants()) do
		if d:IsA("Trail") then
			d.Name = "EnemyTrail"
			d.Enabled = true
			d.Lifetime = 0.4
			d.LightEmission = 0.2
			d.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
		end
	end
end

local function finishCreature(r, scale, hip, height)
	r:Finish(scale)
	r.HipHeight = hip * scale
	r.Height = height * scale
	r.Model:SetAttribute("HipHeight", r.HipHeight)
	afterFinish(r)
	return r
end

local function finishBiped(r, scale, idle, height)
	r:Finish(scale, idle)
	r.Height = (height or (3 + 1 + r.HeadSize.Y + 0.6)) * scale
	afterFinish(r)
	return r
end











------------------------------------------------------------------------
-- 1. LOST SOUL — угловатый полупрозрачный дух в рваном капюшоне, фиолетовый дым
------------------------------------------------------------------------
local function LostSoul(scale)
	local r = newCreature("LostSoul", V(1.7, 1.8, 1.5))
	setup(r, { Style = "Float", Gait = { Bob = 0.35 }, Death = "Dissipate", Spawn = "Fade" })
	local B = r.Torso
	local ghost = { Transparency = 0.3 }
	-- голова-череп и тело, сужающееся книзу
	r:Box(B, V(1.3, 1.25, 1.2), CF(0, 0.45, 0), C.Ghost, M.Plastic, { Transparency = 0.2 })
	r:Box(B, V(1.15, 0.7, 1.0), CF(0, -0.45, 0.05), C.Ghost, M.Plastic, ghost)
	r:Box(B, V(0.85, 0.6, 0.8), CF(0, -0.95, 0.12), C.GhostMid, M.Plastic, { Transparency = 0.4 })
	spike(r, B, V(0, -1.2, 0.18), V(0.1, -1.9, 0.35), 0.75, C.GhostMid, M.Plastic, false)
	-- капюшон из клиньев
	r:Box(B, V(1.55, 0.3, 1.45), CF(0, 1.15, 0.12), A_.Cloth, M.Fabric, { Transparency = 0.15 })
	r:Box(B, V(0.25, 1.4, 1.45), CF(0.75, 0.5, 0.12), A_.Cloth, M.Fabric, { Transparency = 0.15 })
	r:Box(B, V(0.25, 1.4, 1.45), CF(-0.75, 0.5, 0.12), A_.Cloth, M.Fabric, { Transparency = 0.15 })
	r:Box(B, V(1.55, 1.45, 0.25), CF(0, 0.5, 0.75), A_.Cloth, M.Fabric, { Transparency = 0.15 })
	spike(r, B, V(0, 1.25, 0.45), V(0, 1.95, 1.1), 0.9, A_.Cloth, M.Fabric, true, 0.25)
	-- плащ на плечах с рваным краем
	r:Box(B, V(1.6, 1.0, 1.35), CF(0, -0.15, 0.1), A_.ClothDark, M.Fabric, { Transparency = 0.25 })
	tatter(r, B, -0.65, -0.58, 1.6, 5, A_.ClothDark, M.Fabric, 1)
	-- лицо: пустые глазницы с неоновыми зрачками, рот-щель
	for _, s in ipairs({ -1, 1 }) do
		r:Box(B, V(0.38, 0.42, 0.06), CF(0.3 * s, 0.5, -0.61) * ANG(0, 0, rad(-12 * s)), C.Obsidian)
		r:Neon(B, V(0.18, 0.2, 0.08), CF(0.3 * s, 0.48, -0.63), C.Neon)
	end
	r:Box(B, V(0.22, 0.42, 0.06), CF(0, 0.02, -0.61), C.Obsidian)
	-- ядро-ромб внутри
	gem(r, B, 0.45, CF(0, -0.35, -0.48), C.Neon)
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
	bevel(r, B, V(1.5, 0.8, 1.3), CF(0, 0.15, -0.6), A_.Armor, A_.Edge, M.Slate)
	bevel(r, B, V(1.9, 0.9, 1.0), CF(0, 0.35, 0.35) * ANG(rad(8), 0, rad(4)), C.Deep, A_.Edge, M.Slate)
	bevel(r, B, V(1.75, 0.85, 0.9), CF(0.08, 0.55, 1.0) * ANG(rad(-6), rad(5), rad(-5)), A_.Armor, A_.Edge, M.Slate)
	bevel(r, B, V(1.3, 0.7, 0.8), CF(-0.05, 0.4, 1.65) * ANG(rad(-18), 0, rad(3)), C.Deep, A_.Edge, M.Slate)
	r:Wedge(B, V(1.6, 0.5, 0.9), CF(0, 0.85, 0.35), A_.ArmorMid, M.Slate)
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
	bevel(r, tail, V(0.8, 0.5, 0.7), CF(0, 0.1, 0.3) * ANG(rad(-15), 0, 0), A_.Armor, A_.Edge, M.Slate)
	spike(r, tail, V(0, 0.3, 0.6), V(0, 0.95, 1.2), 0.3, C.Bone)
	-- голова на моторе "Twitch"
	local head = hub(r, "TwitchHead", B, CF(0, 0.15, -1.25), { Amp = 0.45, Speed = 1 })
	bevel(r, head, V(1.05, 0.7, 0.9), CF(0, 0.05, -0.4), A_.Armor, A_.Edge, M.Slate)
	r:Wedge(head, V(1.0, 0.35, 0.7), CF(0, 0.55, -0.45) * ANG(0, PI, 0), A_.ArmorMid, M.Slate)
	for _, e in ipairs({ { -0.25, 0.15, 0.2 }, { 0.25, 0.15, 0.2 }, { 0, 0.28, 0.15 }, { -0.4, -0.05, 0.13 }, { 0.4, -0.05, 0.13 } }) do
		r:Neon(head, V(e[3], e[3], 0.08), CF(e[1], e[2], -0.87) * ANG(0, 0, rad(45)), C.Neon)
	end
	-- жвалы-серпы
	for _, s in ipairs({ -1, 1 }) do
		bar(r, head, V(0.3 * s, -0.2, -0.8), V(0.45 * s, -0.25, -1.2), 0.16, C.BoneDark)
		spike(r, head, V(0.45 * s, -0.25, -1.2), V(0.12 * s, -0.25, -1.55), 0.18, C.Bone, M.Plastic, true, 0.08)
	end
	-- 4 лапы: бедро вверх, голень вниз, коготь
	local legs = { { "FR", 1, -0.7, 1.25 }, { "FL", -1, -0.7, 1.25 }, { "BR", 1, 0.75, 1 }, { "BL", -1, 0.75, 1 } }
	for _, l in ipairs(legs) do
		local s, z, big = l[2], l[3], l[4]
		local h = hub(r, l[1], B, CF(0.75 * s, 0.1, z))
		local knee = V(0.95 * s, 0.75, z < 0 and -0.2 or 0.2)
		local foot = V(1.45 * s, -1.2, z < 0 and -0.5 or 0.35)
		local toe = foot + (knee - foot).Unit * 0.45
		bar(r, h, V(0, 0, 0), knee, 0.34 * big, A_.Armor)
		r:Box(h, V(0.42, 0.42, 0.42) * big, CF(knee) * ANG(0, rad(45), rad(45)), A_.ArmorMid, M.Slate)
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
	-- грива-шипы
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
	r:Wedge(head, V(0.7, 0.3, 0.75), CF(0, 0.37, -1.25) * ANG(0, 0, 0), fur, M.Plastic)
	r:Box(head, V(0.3, 0.2, 0.12), CF(0, 0.08, -1.65), C.Obsidian)
	r:Box(head, V(0.6, 0.2, 0.7), CF(0, -0.38, -1.15), C.Obsidian)
	r:Neon(head, V(0.45, 0.06, 0.6), CF(0, -0.25, -1.15), C.Magenta)
	for _, s in ipairs({ -1, 1 }) do
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
		local s = l[2]
		local leg = hub(r, l[1], B, CF(0.6 * s, -0.1, 1.15))
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
-- 4. ARMORED HORROR — латный кошмар: огромный нагрудник, наплечники-ступени, шипы, светящиеся швы
------------------------------------------------------------------------
local function ArmoredHorror(scale)
	local r = newBiped("ArmoredHorror", V(1.2, 1.2, 1.2))
	setup(r, { Style = "Heavy", Gait = { Speed = 0.9, Stride = 0.45, Bob = 0.16, Sway = 0.07 }, Death = "Topple" })
	local T, H, RA, LA, RL, LL = r.Torso, r.Head, r.RArm, r.LArm, r.RLeg, r.LLeg
	local glow = C.Magenta
	-- корпус и огромный нагрудник
	bevel(r, T, V(2.2, 2.0, 1.2), CF(0, 0.05, 0.05), A_.Armor, A_.Edge)
	bevel(r, T, V(2.7, 1.25, 1.55), CF(0, 0.6, -0.1), A_.ArmorMid, A_.Edge)
	r:Wedge(T, V(2.4, 0.6, 0.55), CF(0, 0.65, -1.1) * ANG(PI, PI, 0), A_.ArmorMid, M.Metal)
	r:Wedge(T, V(2.4, 0.5, 0.55), CF(0, 1.1, -1.1), A_.Armor, M.Metal)
	-- светящиеся швы и трещины между пластинами
	r:Neon(T, V(2.75, 0.07, 1.6), CF(0, -0.05, -0.1), glow)
	crack(r, T, { V(-0.9, 1.15, -0.9), V(-0.55, 0.7, -0.92), V(-0.75, 0.25, -0.88) }, 0.06, glow)
	crack(r, T, { V(0.6, 1.1, -0.9), V(0.85, 0.5, -0.88) }, 0.05, glow)
	gem(r, T, 0.4, CF(0, 0.55, -0.9), glow, A_.Edge)
	-- пластины живота и пояс
	bevel(r, T, V(2.0, 0.4, 1.35), CF(0, -0.35, -0.02), A_.ArmorMid, A_.Edge)
	bevel(r, T, V(1.9, 0.4, 1.3), CF(0, -0.72, 0), A_.Armor, A_.Edge)
	bevel(r, T, V(0.45, 0.4, 0.15), CF(0, -0.72, -0.72), A_.Edge, A_.ArmorMid)
	for _, s in ipairs({ -1, 1 }) do
		bevel(r, T, V(0.75, 0.85, 1.1), CF(0.85 * s, -1.25, -0.05) * ANG(0, 0, rad(12 * s)), A_.ArmorMid, A_.Edge)
	end
	for i = -1, 1 do
		spike(r, T, V(i * 0.6, 0.8, 0.6), V(i * 0.8, 1.5 - math.abs(i) * 0.25, 1.4), 0.45, A_.Armor, M.Metal)
	end
	-- шлем: гранёный, с гребнем, рогами и узким визором
	bevel(r, H, V(1.3, 1.35, 1.35), CF(0, 0.05, 0), A_.Armor, A_.Edge)
	bevel(r, H, V(1.1, 0.75, 0.25), CF(0, -0.1, -0.7), A_.ArmorMid, A_.Edge)
	r:Neon(H, V(0.85, 0.09, 0.06), CF(0, 0.2, -0.84), glow)
	r:Neon(H, V(0.09, 0.4, 0.06), CF(0, -0.05, -0.84), glow)
	spike(r, H, V(0, 0.6, 0.1), V(0, 1.4, 0.55), 0.8, A_.Armor, M.Metal, true, 0.12)
	for _, s in ipairs({ -1, 1 }) do
		hornA(r, H, { V(0.6 * s, 0.3, 0), V(0.95 * s, 0.55, 0.05), V(1.1 * s, 1.0, 0.05), V(1.0 * s, 1.5, -0.1) }, 0.26, C.Bone)
	end
	-- наплечники-ступени, толстые руки, латные кулаки
	for _, a in ipairs({ { RA, 1 }, { LA, -1 } }) do
		local A, s = a[1], a[2]
		pauldron(r, A, s, 1.15, A_.Armor, A_.Edge, glow, 2)
		bevel(r, A, V(1.05, 0.9, 1.05), CF(0, 0.15, 0), A_.Armor, A_.Edge)
		bevel(r, A, V(1.25, 1.05, 1.25), CF(0, -0.75, 0), A_.ArmorMid, A_.Edge)
		r:Neon(A, V(1.27, 0.06, 1.27), CF(0, -0.55, 0), glow)
		bevel(r, A, V(1.15, 0.6, 1.15), CF(0, -1.45, -0.05), A_.Armor, A_.Edge)
		for k = -1, 1 do
			spike(r, A, V(k * 0.33, -1.4, -0.55), V(k * 0.38, -1.45, -0.95), 0.18, A_.Edge, M.Metal)
		end
	end
	-- ноги
	for _, Lg in ipairs({ RL, LL }) do
		bevel(r, Lg, V(1.05, 1.0, 1.05), CF(0, 0.45, 0), A_.Armor, A_.Edge)
		bevel(r, Lg, V(0.8, 0.5, 0.3), CF(0, -0.05, -0.6), A_.ArmorMid, A_.Edge)
		bevel(r, Lg, V(1.1, 0.7, 1.12), CF(0, -0.38, 0), A_.ArmorMid, A_.Edge)
		bootA(r, Lg, A_.Armor, A_.Edge, 1.15)
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
	spike(r, B, V(0, 0.0, -0.4), V(0, 0.6, -0.4), 0.5, C.NeonSoft, M.Neon)
	spike(r, B, V(0, 0.0, -0.4), V(0, -0.65, -0.4), 0.5, C.Neon, M.Neon)
	r:Glow(B, C.Neon, 9, 1.2)
	-- парящие плечи-пластины
	for _, s in ipairs({ 1, -1 }) do
		local sh = hub(r, s == 1 and "BobShoulderR" or "BobShoulderL", B, CF(1.05 * s, 0.75, 0), { Amp = 0.12, Speed = 2.6 })
		bevel(r, sh, V(0.95, 0.35, 0.9), CF() * ANG(0, 0, rad(-18 * s)), C.Deep, C.Lilac, M.Plastic)
		spike(r, sh, V(0.2 * s, 0.15, 0), V(0.6 * s, 0.75, 0), 0.35, C.Mid)
		r:Neon(sh, V(0.9, 0.05, 0.85), CF(0, -0.2, 0) * ANG(0, 0, rad(-18 * s)), C.NeonSoft)
	end
	-- парящая голова: светящееся лицо в остроконечном капюшоне
	local head = hub(r, "BobHead", B, CF(0, 1.6, 0), { Amp = 0.15, Speed = 2 })
	r:Box(head, V(0.75, 0.9, 0.7), CF(0, 0, -0.05), C.NeonSoft, M.Neon)
	r:Box(head, V(0.55, 0.1, 0.1), CF(0, 0.1, -0.42), C.Obsidian)
	r:Box(head, V(0.2, 0.3, 0.1), CF(0, -0.2, -0.42), C.Obsidian)
	r:Box(head, V(1.2, 0.25, 1.15), CF(0, 0.58, 0.12), C.Deep, M.Fabric)
	r:Box(head, V(0.22, 1.2, 1.15), CF(0.5, 0.05, 0.12), C.Deep, M.Fabric)
	r:Box(head, V(0.22, 1.2, 1.15), CF(-0.5, 0.05, 0.12), C.Deep, M.Fabric)
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
		r:Box(sd, V(w, w, w), CF() * ANG(rad(45), rad(i * 20), rad(45)), i % 2 == 0 and C.Mid or C.Deep, M.Plastic)
		r:Neon(sd, V(w * 0.45, w * 0.45, w * 1.05), CF() * ANG(rad(45), rad(i * 20), rad(45)), C.Neon)
		if i == 3 then
			emitter(sd, C.Neon, { Rate = 14, Size = 0.35, LifeMin = 0.6, LifeMax = 1.1, SpeedMin = 0.1, SpeedMax = 0.5 })
		end
	end
	-- энергетические кольца
	local ring1 = hub(r, "OrbitRing1", B, CF(0, 0, 0), { Speed = 1.6 })
	ring(r, ring1, ANG(rad(90), 0, 0), 1.6, 12, 0.08, 0.08, C.Neon, M.Neon, function(i) return i % 4 == 3 end)
	local ring2 = hub(r, "OrbitRing2", B, CF(0, 0.2, 0) * ANG(rad(65), 0, rad(20)), { Speed = -2.2 })
	ring(r, ring2, ANG(rad(90), 0, 0), 1.95, 14, 0.06, 0.06, C.NeonSoft, M.Neon, function(i) return i % 5 == 4 end)
	return finishCreature(r, scale, 3.3, 4.6)
end

------------------------------------------------------------------------
-- 6. ABYSS BRUTE — сгорбленный громила: гигантские руки-блоки, странная голова, кристаллы на спине
------------------------------------------------------------------------
local function AbyssBrute(scale)
	local r = newBiped("AbyssBrute", V(1.2, 1.0, 1.2))
	setup(r, { Style = "Heavy", Gait = { Speed = 0.75, Stride = 0.35, Bob = 0.24, Sway = 0.12, Shake = 0.12 }, Death = "Topple" })
	local T, H, RA, LA, RL, LL = r.Torso, r.Head, r.RArm, r.LArm, r.RLeg, r.LLeg
	local skin, skinHi, skinLo = rgb(56, 22, 42), rgb(104, 48, 76), rgb(36, 13, 28)
	-- горб, грудь, брюхо
	bevel(r, T, V(2.8, 1.6, 1.9), CF(0, 0.6, 0.25), skin, skinHi, M.Plastic)
	bevel(r, T, V(2.1, 1.2, 1.4), CF(0, -0.35, -0.15), skinLo, skinHi, M.Plastic)
	bevel(r, T, V(2.3, 0.5, 1.7), CF(0, -0.95, 0), A_.Armor, A_.Edge)
	bevel(r, T, V(0.5, 0.45, 0.15), CF(0, -0.95, -0.88), A_.Edge, A_.ArmorMid)
	-- светящееся сердце-ромб и трещины
	gem(r, T, 0.5, CF(0, 0.5, -0.72), C.Magenta, skinLo)
	crack(r, T, { V(-0.85, 1.05, -0.72), V(-0.35, 0.75, -0.73), V(-0.6, 0.15, -0.73) }, 0.06, C.Magenta)
	crack(r, T, { V(0.75, 1.0, -0.72), V(0.35, 0.8, -0.73) }, 0.05, C.Magenta)
	-- кристаллы на горбу
	local cr = { { -0.6, 1.3, 0.95, -0.35, 1.3, 0.48 }, { 0.05, 1.4, 0.75, 0.05, 1.8, 0.58 }, { 0.65, 1.3, 0.95, 0.4, 1.25, 0.44 }, { -0.3, 0.9, 1.2, -0.25, 0.85, 0.32 }, { 0.35, 0.95, 1.2, 0.3, 0.75, 0.3 } }
	for _, c in ipairs(cr) do
		local base = V(c[1], c[2], c[3])
		r:Box(T, V(c[6] * 1.5, c[6] * 0.6, c[6] * 1.5), CF(base) * ANG(0, rad(30), 0), C.Night, M.Slate)
		spike(r, T, base, base + V(c[4] * 0.5, c[5], 0.55), c[6], C.Neon, M.Neon)
	end
	r:Glow(T, C.Neon, 9, 1.1)
	-- странная голова: низкая и широкая, три глаза, выпирающая челюсть с бивнями
	bevel(r, H, V(1.4, 0.95, 1.25), CF(0, 0.08, 0), skin, skinHi, M.Plastic)
	bevel(r, H, V(1.5, 0.5, 1.15), CF(0, -0.4, -0.15), skinLo, skinHi, M.Plastic)
	r:Wedge(H, V(1.3, 0.35, 0.5), CF(0, 0.45, -0.45) * ANG(0, PI, 0), skinLo, M.Plastic)
	for _, s in ipairs({ -1, 1 }) do
		spike(r, H, V(0.45 * s, -0.35, -0.7), V(0.6 * s, 0.4, -0.85), 0.26, C.Bone)
		r:Neon(H, V(0.22, 0.12, 0.06), CF(0.38 * s, 0.22, -0.64) * ANG(0, 0, rad(14 * s)), C.Magenta)
		hornA(r, H, { V(0.5 * s, 0.35, 0.1), V(0.85 * s, 0.55, 0.35), V(0.95 * s, 0.75, 0.8), V(0.8 * s, 0.9, 1.3) }, 0.3, C.Bone)
	end
	gem(r, H, 0.24, CF(0, 0.3, -0.64), C.Magenta)
	-- костяные наплечники, гигантские руки до земли
	for _, a in ipairs({ { RA, 1 }, { LA, -1 } }) do
		local A, s = a[1], a[2]
		bevel(r, A, V(1.7, 0.55, 1.7), CF(0.25 * s, 1.15, 0) * ANG(0, 0, rad(-15 * s)), C.BoneDark, C.Bone, M.Plastic)
		for k = -1, 1 do
			spike(r, A, V(0.45 * s, 1.35, k * 0.5), V(0.95 * s, 2.05 - math.abs(k) * 0.3, k * 0.65), 0.4, C.Bone, M.Plastic, true, 0.14)
		end
		bevel(r, A, V(1.55, 1.55, 1.55), CF(0.1 * s, 0.15, 0), skin, skinHi, M.Plastic)
		bevel(r, A, V(1.8, 1.4, 1.8), CF(0.15 * s, -1.0, 0), skinLo, skinHi, M.Plastic)
		bevel(r, A, V(1.9, 0.4, 1.9), CF(0.15 * s, -1.5, 0), A_.Armor, A_.Edge)
		bevel(r, A, V(1.65, 0.9, 1.65), CF(0.15 * s, -2.05, -0.05), skin, skinHi, M.Plastic)
		for k = -1, 1 do
			spike(r, A, V(0.15 * s + k * 0.5, -2.2, -0.75), V(0.15 * s + k * 0.55, -2.4, -1.15), 0.26, C.Bone)
		end
	end
	for _, Lg in ipairs({ RL, LL }) do
		bevel(r, Lg, V(1.3, 1.3, 1.3), CF(0, 0.3, 0), skinLo, skinHi, M.Plastic)
		bevel(r, Lg, V(1.35, 0.55, 1.6), CF(0, -0.75, -0.15), skin, skinHi, M.Plastic)
		for k = -1, 1 do
			spike(r, Lg, V(k * 0.4, -0.85, -0.9), V(k * 0.45, -0.95, -1.2), 0.2, C.Bone, M.Plastic, true, 0.08)
		end
	end
	return finishBiped(r, scale, { Root = { 14, 0, 0 }, Neck = { -14, 0, 0 }, RS = { 8, 0, 6 }, LS = { 8, 0, -6 } })
end

------------------------------------------------------------------------
-- 7. CORRUPTED TITAN (мини-босс) — каменный великан в обсидиановых латах: рога, кулаки, кристалл
------------------------------------------------------------------------
local function CorruptedTitan(scale)
	local r = newBiped("CorruptedTitan", V(1.4, 1.3, 1.4))
	setup(r, { Style = "Heavy", Gait = { Speed = 0.8, Stride = 0.4, Bob = 0.2, Sway = 0.08, Shake = 0.2 }, Death = "Topple", Spawn = "Titan" })
	local T, H, RA, LA, RL, LL = r.Torso, r.Head, r.RArm, r.LArm, r.RLeg, r.LLeg
	local function rock(limb, size, cf, light)
		return bevel(r, limb, size, cf, light and C.StoneLight or C.Stone, light and rgb(140, 132, 160) or C.StoneLight, M.Slate)
	end
	-- каменная плоть из глыб, между ними светятся разломы
	r:Box(T, V(2.3, 2.1, 1.3), CF(0, 0.15, 0.05), C.Neon, M.Neon)
	rock(T, V(1.25, 1.2, 1.5), CF(-0.62, 0.65, 0.05) * ANG(rad(4), rad(6), rad(5)), false)
	rock(T, V(1.25, 1.15, 1.5), CF(0.64, 0.68, 0.05) * ANG(rad(-3), rad(-5), rad(-6)), true)
	rock(T, V(1.15, 0.95, 1.4), CF(-0.5, -0.4, 0.0) * ANG(rad(-5), rad(3), rad(-4)), true)
	rock(T, V(1.15, 0.95, 1.4), CF(0.52, -0.38, 0.0) * ANG(rad(6), rad(-4), rad(5)), false)
	-- обсидиановый нагрудник с золотым кантом и кристаллом
	bevel(r, T, V(2.5, 1.2, 0.5), CF(0, 0.65, -0.8), A_.Armor, C.Gold)
	r:Wedge(T, V(2.3, 0.5, 0.5), CF(0, -0.15, -0.8) * ANG(PI, PI, 0), A_.Armor, M.Metal)
	spike(r, T, V(0, 0.55, -1.1), V(0, 1.15, -1.1), 0.6, C.Neon, M.Neon)
	spike(r, T, V(0, 0.55, -1.1), V(0, -0.05, -1.1), 0.6, C.NeonSoft, M.Neon)
	local coreLight = r:Glow(T, C.Neon, 14, 1.6)
	bevel(r, T, V(2.2, 0.4, 1.6), CF(0, -1.0, 0), A_.Armor, C.Gold)
	-- голова: каменный череп в обсидиановом шлеме, щель глаз, огромные рога
	rock(H, V(1.3, 1.25, 1.3), CF(0, -0.05, 0.05) * ANG(rad(3), rad(5), 0), false)
	bevel(r, H, V(1.5, 0.75, 1.45), CF(0, 0.35, -0.05), A_.Armor, C.Gold)
	r:Neon(H, V(1.0, 0.09, 0.06), CF(0, 0.0, -0.69), C.Neon)
	r:Wedge(H, V(1.0, 0.5, 0.5), CF(0, -0.45, -0.5) * ANG(PI, PI, 0), C.StoneLight, M.Slate)
	for _, s in ipairs({ -1, 1 }) do
		hornA(r, H, { V(0.65 * s, 0.45, 0), V(1.2 * s, 0.8, 0.1), V(1.5 * s, 1.4, 0.0), V(1.4 * s, 2.05, -0.3), V(1.15 * s, 2.6, -0.55) }, 0.42, A_.Armor, M.Metal)
	end
	-- наплечники, каменные руки, гигантские кулаки
	for _, a in ipairs({ { RA, 1 }, { LA, -1 } }) do
		local A, s = a[1], a[2]
		pauldron(r, A, s, 1.2, A_.Armor, C.Gold, C.Neon, 1)
		rock(A, V(1.05, 1.0, 1.05), CF(0, 0.1, 0) * ANG(0, rad(10), rad(4 * s)), false)
		rock(A, V(1.2, 0.9, 1.2), CF(0, -0.75, 0) * ANG(0, rad(-8), rad(-5 * s)), true)
		r:Box(A, V(1.0, 0.25, 1.0), CF(0, -0.35, 0), C.Neon, M.Neon)
		bevel(r, A, V(1.7, 0.35, 1.7), CF(0, -1.2, -0.05), A_.Armor, C.Gold)
		rock(A, V(1.6, 1.2, 1.6), CF(0, -1.75, -0.1) * ANG(rad(5), rad(12), 0), false)
		for k = -1, 1 do
			spike(r, A, V(k * 0.5, -1.7, -0.85), V(k * 0.55, -1.75, -1.25), 0.28, A_.Armor, M.Metal)
		end
	end
	for _, Lg in ipairs({ RL, LL }) do
		rock(Lg, V(1.15, 1.05, 1.15), CF(0, 0.45, 0) * ANG(0, rad(8), 0), true)
		r:Box(Lg, V(0.95, 0.25, 0.95), CF(0, -0.1, 0), C.Neon, M.Neon)
		rock(Lg, V(1.15, 0.7, 1.2), CF(0, -0.42, 0) * ANG(0, rad(-6), 0), false)
		bootA(r, Lg, A_.Armor, C.Gold, 1.25)
	end
	-- парящие осколки разлома
	local orb = hub(r, "OrbitRift", T, CF(0, 0.3, 0), { Speed = 1.1 })
	for i = 0, 4 do
		local a = i / 5 * PI * 2
		local p = V(math.cos(a) * 2.7, math.sin(a * 2) * 0.4, math.sin(a) * 2.7)
		spike(r, orb, p - V(0, 0.35, 0), p + V(0, 0.45, 0), 0.4, C.Neon, M.Neon)
	end
	local aura = emitter(T, C.Neon, { Rate = 10, Size = 0.5, Accel = V(0, 2, 0) })
	-- фаза повреждений (50% HP): камень трескается, свечение сильнее
	local dmg = hide(join(
		crack(r, T, { V(-0.95, 1.15, -0.85), V(-0.55, 0.65, -0.85), V(-0.85, 0.2, -0.82) }, 0.08),
		crack(r, T, { V(0.9, 0.1, -0.75), V(0.5, -0.4, -0.75), V(0.8, -0.8, -0.75) }, 0.08),
		crack(r, H, { V(-0.4, -0.1, -0.62), V(-0.15, -0.35, -0.64), V(-0.35, -0.6, -0.62) }, 0.06),
		crack(r, RL, { V(0.3, 0.7, -0.59), V(-0.1, 0.2, -0.59) }, 0.07),
		crack(r, LL, { V(-0.3, 0.6, -0.59), V(0.15, 0.1, -0.59) }, 0.07)
	))
	local dmgFx = emitter(T, C.NeonSoft, { Rate = 16, Size = 0.35, Off = true, SpeedMin = 2, SpeedMax = 4 })
	r.Phases = { { At = 0.5, Reveal = dmg, Emit = { dmgFx, aura }, Lights = { { coreLight, 3 } }, Aggro = 1.15 } }
	return finishBiped(r, scale, { RS = { 0, 0, 8 }, LS = { 0, 0, -8 } }, 6.4)
end

------------------------------------------------------------------------
-- 8. VOID DEVOURER (босс) — сгорбленный пожиратель: рога, слоистая броня, кристаллы, светящаяся пасть
------------------------------------------------------------------------
local function VoidDevourer(scale)
	local r = newBiped("VoidDevourer", V(1.6, 1.35, 1.6))
	setup(r, { Style = "Heavy", Gait = { Speed = 0.7, Stride = 0.38, Bob = 0.22, Sway = 0.1, Lean = 4, Shake = 0.3 }, Death = "Topple" })
	local T, H, RA, LA, RL, LL = r.Torso, r.Head, r.RArm, r.LArm, r.RLeg, r.LLeg
	local maw = C.Magenta
	-- корпус и слоистая броня на груди
	bevel(r, T, V(2.5, 2.2, 1.6), CF(0, 0.2, 0.15), A_.Armor, A_.Edge)
	local plateA = bevel(r, T, V(2.7, 0.75, 1.35), CF(0, 0.95, -0.35) * ANG(rad(-10), 0, 0), A_.ArmorMid, A_.Edge)
	local plateB = bevel(r, T, V(2.4, 0.65, 1.25), CF(0, 0.3, -0.45) * ANG(rad(-6), 0, 0), A_.Armor, A_.Edge)
	bevel(r, T, V(2.0, 0.55, 1.2), CF(0, -0.3, -0.42), A_.ArmorMid, A_.Edge)
	r:Neon(T, V(2.5, 0.06, 1.3), CF(0, 0.62, -0.38) * ANG(rad(-8), 0, 0), C.Neon)
	bevel(r, T, V(2.2, 0.4, 1.6), CF(0, -0.95, 0), A_.Armor, A_.Edge)
	-- спинной гребень из пластин и кристаллов
	for i = 0, 3 do
		bevel(r, T, V(1.8 - i * 0.2, 0.32, 0.8), CF(0, 1.25 - i * 0.55, 1.0 + i * 0.05) * ANG(rad(28), 0, 0), i % 2 == 0 and A_.Armor or A_.ArmorMid, A_.Edge)
	end
	for _, c in ipairs({ { -0.55, 1.3, 1.1, -0.35, 1.4, 0.5 }, { 0.1, 1.45, 1.1, 0.05, 1.9, 0.6 }, { 0.6, 1.25, 1.05, 0.35, 1.25, 0.46 }, { -0.25, 0.65, 1.3, -0.2, 0.9, 0.36 }, { 0.35, 0.55, 1.3, 0.25, 0.8, 0.32 } }) do
		local base = V(c[1], c[2], c[3])
		spike(r, T, base, base + V(c[4], c[5], 0.75), c[6], C.Neon, M.Neon)
	end
	r:Glow(T, C.Neon, 12, 1.2)
	-- голова: гранёный череп, огромная пасть
	bevel(r, H, V(1.7, 1.15, 1.8), CF(0, 0.3, -0.05), A_.Armor, A_.Edge)
	r:Wedge(H, V(1.6, 0.45, 1.0), CF(0, 0.95, -0.4) * ANG(0, PI, 0), A_.ArmorMid, M.Metal)
	r:Box(H, V(1.3, 0.6, 0.9), CF(0, -0.15, -0.5), maw, M.Neon)
	for i = -3, 3 do
		spike(r, H, V(i * 0.2, 0.0, -0.98 + math.abs(i) * 0.05), V(i * 0.2, -0.4, -1.0 + math.abs(i) * 0.05), 0.17, C.White, M.Plastic, true, 0.07)
	end
	for _, s in ipairs({ -1, 1 }) do
		r:Neon(H, V(0.36, 0.1, 0.06), CF(0.45 * s, 0.55, -0.96) * ANG(0, 0, rad(-24 * s)), maw)
		r:Neon(H, V(0.18, 0.07, 0.06), CF(0.62 * s, 0.32, -0.96) * ANG(0, 0, rad(-24 * s)), maw)
	end
	local mawLight = r:Glow(H, maw, 10, 1.4)
	local jaw = hub(r, "Jaw", H, CF(0, -0.4, 0.35))
	bevel(r, jaw, V(1.45, 0.4, 1.6), CF(0, -0.15, -0.75), A_.Armor, A_.Edge)
	r:Neon(jaw, V(1.1, 0.06, 1.2), CF(0, 0.07, -0.75), maw)
	for i = -3, 3 do
		spike(r, jaw, V(i * 0.19, 0.05, -1.4 + math.abs(i) * 0.09), V(i * 0.19, 0.45, -1.4 + math.abs(i) * 0.09), 0.15, C.White, M.Plastic, true, 0.07)
	end
	-- массивные угловатые рога
	for _, s in ipairs({ -1, 1 }) do
		hornA(r, H, { V(0.7 * s, 0.6, 0.15), V(1.3 * s, 0.95, 0.2), V(1.7 * s, 1.7, 0.0), V(1.6 * s, 2.6, -0.4), V(1.2 * s, 3.3, -0.8) }, 0.5, A_.Armor, M.Metal)
		hornA(r, H, { V(0.45 * s, 0.8, 0.5), V(0.65 * s, 1.15, 1.0), V(0.7 * s, 1.35, 1.6), V(0.65 * s, 1.3, 2.2) }, 0.26, A_.ArmorMid, M.Metal)
	end
	-- наплечники с кристаллами, длинные руки с когтями-лезвиями
	local pauldrons = {}
	for _, a in ipairs({ { RA, 1 }, { LA, -1 } }) do
		local A, s = a[1], a[2]
		for _, p in ipairs(pauldron(r, A, s, 1.25, A_.Armor, A_.Edge, C.Neon, 1)) do
			pauldrons[#pauldrons + 1] = p
		end
		spike(r, A, V(0.55 * s, 1.3, -0.4), V(1.0 * s, 2.0, -0.55), 0.32, C.Neon, M.Neon)
		bevel(r, A, V(1.0, 0.95, 1.0), CF(0, 0.15, 0), A_.Armor, A_.Edge)
		bevel(r, A, V(1.2, 1.05, 1.2), CF(0, -0.75, -0.03), A_.ArmorMid, A_.Edge)
		r:Neon(A, V(1.22, 0.06, 1.22), CF(0, -0.45, -0.03), C.Neon)
		bevel(r, A, V(1.1, 0.55, 1.1), CF(0, -1.5, -0.1), A_.Armor, A_.Edge)
		for k = -1, 1 do
			spike(r, A, V(k * 0.36, -1.7, -0.45), V(k * 0.45, -2.75, -1.0), 0.24, C.Bone)
		end
	end
	for _, Lg in ipairs({ RL, LL }) do
		bevel(r, Lg, V(1.15, 1.0, 1.15), CF(0, 0.45, 0), A_.Armor, A_.Edge)
		bevel(r, Lg, V(0.85, 0.5, 0.3), CF(0, -0.05, -0.62), A_.ArmorMid, A_.Edge)
		bevel(r, Lg, V(1.15, 0.7, 1.15), CF(0, -0.38, 0), A_.ArmorMid, A_.Edge)
		bootA(r, Lg, A_.Armor, A_.Edge, 1.25)
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
	-- Фаза 2 (66%): светящиеся трещины по броне
	local cracks2 = hide(join(
		crack(r, T, { V(-1.0, 1.15, -1.05), V(-0.5, 0.7, -1.1), V(-0.75, 0.15, -1.08) }, 0.08, maw),
		crack(r, T, { V(0.95, 1.0, -1.05), V(0.45, 0.45, -1.1), V(0.75, -0.2, -1.05) }, 0.08, maw),
		crack(r, H, { V(-0.6, 0.75, -0.96), V(-0.25, 0.45, -0.96) }, 0.06, maw)
	))
	-- Фаза 3 (33%): броня отваливается, под ней светится ядро
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
-- 9. THE ENTITY (финальный босс)
-- Повелитель Пустоты в угловатых латах: сломанная корона, асимметричная броня, огромные руки,
-- разбитое кольцо, парящие камни, ядро-кристалл, цепи, руны, рваный плащ. 3 визуальные фазы.
------------------------------------------------------------------------
local function TheEntity(scale)
	local r = newBiped("TheEntity", V(1.3, 1.5, 1.3))
	setup(r, { Style = "Heavy", Gait = { Speed = 0.75, Stride = 0.36, Bob = 0.2, Sway = 0.09, Lean = 3, Shake = 0.4 }, Death = "Implode" })
	local T, H, RA, LA, RL, LL = r.Torso, r.Head, r.RArm, r.LArm, r.RLeg, r.LLeg
	local GOLD = C.Gold

	-- ТОРС: корпус, широкая грудная пластина, ядро-кристалл
	bevel(r, T, V(2.2, 2.0, 1.2), CF(0, 0.05, 0.05), A_.Armor, A_.Edge)
	bevel(r, T, V(2.75, 1.05, 1.5), CF(0, 0.6, -0.05), A_.ArmorMid, A_.Edge)
	-- правая сторона — тяжёлая пластина с золотым кантом, левая — открытые рёбра
	bevel(r, T, V(1.15, 0.95, 0.3), CF(0.62, 0.55, -0.85) * ANG(0, 0, rad(-6)), A_.Armor, GOLD)
	for k = 0, 2 do
		bar(r, T, V(-0.15, 1.0 - k * 0.32, -0.85), V(-1.1, 0.85 - k * 0.32, -0.75), V2(0.12, 0.1), C.Bone)
	end
	gem(r, T, 0.7, CF(-0.4, 0.45, -0.82), C.Neon, A_.Edge)
	gem(r, T, 0.35, CF(-0.4, 0.45, -0.92), C.White)
	local coreLight = r:Glow(T, C.Neon, 18, 2)
	-- воротник-гребень за головой
	for _, s in ipairs({ -1, 1 }) do
		spike(r, T, V(0.7 * s, 1.0, 0.3), V(1.1 * s, 2.6, 0.75), 0.85, A_.Armor, M.Metal, true, 0.22)
		spike(r, T, V(0.35 * s, 1.0, 0.45), V(0.5 * s, 2.1, 0.85), 0.6, A_.ArmorMid, M.Metal, true, 0.18)
	end
	-- пластины живота, пояс с пряжкой
	bevel(r, T, V(1.95, 0.38, 1.3), CF(0, -0.35, -0.02), A_.Armor, A_.Edge)
	bevel(r, T, V(2.2, 0.4, 1.45), CF(0, -0.85, 0), A_.ClothDark, A_.Edge, M.Fabric)
	bevel(r, T, V(0.55, 0.5, 0.16), CF(0, -0.85, -0.78), A_.Edge, A_.ArmorMid)
	gem(r, T, 0.22, CF(0, -0.85, -0.88), C.Neon)
	-- набедренные пластины
	for _, s in ipairs({ -1, 1 }) do
		bevel(r, T, V(0.75, 0.9, 1.1), CF(0.92 * s, -1.3, -0.05) * ANG(0, 0, rad(12 * s)), A_.ArmorMid, A_.Edge)
	end
	-- рваный плащ
	r:Cape(2.4, 4.6, A_.Cloth, true)
	r.Sec.Cape = { Amp = 0.12, Speed = 1.4 }
	r.Sec.Cape2 = { Amp = 0.18, Speed = 1.4 }

	-- ГОЛОВА: гранёный шлем, Т-образный визор, нащёчники, рога
	bevel(r, H, V(1.35, 1.45, 1.4), CF(0, 0.05, 0), A_.Armor, A_.Edge)
	bevel(r, H, V(1.15, 1.0, 0.25), CF(0, -0.1, -0.72), A_.ArmorMid, A_.Edge)
	r:Neon(H, V(0.9, 0.12, 0.06), CF(0, 0.2, -0.86), C.Neon)
	r:Neon(H, V(0.12, 0.55, 0.06), CF(0, -0.08, -0.86), C.Neon)
	for _, s in ipairs({ -1, 1 }) do
		r:Wedge(H, V(0.3, 0.6, 0.6), CF(0.6 * s, -0.55, -0.5) * ANG(PI, 0, 0), A_.Armor, M.Metal)
		hornA(r, H, { V(0.6 * s, 0.35, 0.05), V(0.95 * s, 0.6, 0.1), V(1.1 * s, 1.1, 0.05), V(0.95 * s, 1.6, -0.15) }, 0.28, A_.Armor, M.Metal)
	end
	r:Glow(H, C.Neon, 8, 1.2)
	-- высокая сломанная корона
	local crownTall, stubs = {}, {}
	for i = 0, 3 do
		r:Box(H, V(1.5, 0.28, 0.14), CF(0, 0.82, 0) * ANG(0, i * PI / 2, 0) * CF(0, 0, -0.7), GOLD, M.Metal)
	end
	local crown = { { 0, 2.6, true }, { 0.4, 1.7, true }, { -0.4, 2.0, true }, { 0.7, 0.5, false }, { -0.7, 1.3, true }, { 0.2, 0.35, false } }
	for _, c in ipairs(crown) do
		local x = c[1]
		local base = V(x, 0.9, -0.7)
		local tip = base + V(x * 0.3, c[2], 0.15)
		local p = spike(r, H, base, tip, 0.3 + c[2] * 0.05, GOLD, M.Metal, false, 0.1)
		r:Neon(H, V(0.18, 0.18, 0.08), CF(base + V(0, 0.0, -0.08)) * ANG(0, 0, rad(45)), C.Neon)
		if c[3] then
			for _, q in ipairs(p) do
				crownTall[#crownTall + 1] = q
			end
			stubs[#stubs + 1] = r:Seg(H, base, base + V(0, 0.3, 0), 0.16, C.NeonSoft, M.Neon)
		end
	end
	hide(stubs)

	-- ПРАВАЯ РУКА: огромный наплечник-ступени, латная перчатка
	pauldron(r, RA, 1, 1.3, A_.Armor, GOLD, C.Neon, 3)
	bevel(r, RA, V(1.0, 0.9, 1.0), CF(0, 0.15, 0), A_.Armor, A_.Edge)
	bevel(r, RA, V(1.3, 0.3, 1.3), CF(0, -0.35, 0), A_.Armor, GOLD)
	bevel(r, RA, V(1.2, 0.85, 1.2), CF(0, -0.85, -0.02), A_.ArmorMid, A_.Edge)
	spike(r, RA, V(0.5, -0.8, 0), V(1.0, -0.7, 0.15), 0.35, A_.Armor, M.Metal, true, 0.1)
	-- ЛЕВАЯ РУКА: проклятая, в цепях и рунах, костяные шипы
	bevel(r, LA, V(1.35, 0.6, 1.35), CF(-0.2, 1.05, 0) * ANG(0, 0, rad(14)), A_.ClothDark, A_.Edge, M.Fabric)
	for k = 0, 2 do
		spike(r, LA, V(-0.3 - k * 0.12, 1.25, -0.35 + k * 0.35), V(-0.65 - k * 0.15, 2.0 - k * 0.2, -0.4 + k * 0.45), 0.24, C.Bone)
	end
	bevel(r, LA, V(0.9, 0.9, 0.9), CF(0, 0.15, 0), C.Deep, C.Lilac, M.Plastic)
	bevel(r, LA, V(1.0, 1.0, 1.0), CF(0, -0.8, 0), C.Night, C.Mid, M.Plastic)
	for k = 0, 2 do
		squareRing(r, LA, CF(0, -0.45 - k * 0.3, 0) * ANG(rad(10 - k * 8), rad(10), 0), 1.1, 0.1, C.Steel)
	end
	r:Neon(LA, V(0.06, 0.85, 0.06), CF(0.1, -0.85, -0.52), C.NeonSoft)
	-- кисти с длинными когтями
	for _, A in ipairs({ RA, LA }) do
		bevel(r, A, V(1.05, 0.5, 1.05), CF(0, -1.5, -0.1), A_.Armor, A_.Edge)
		for k = -1, 1 do
			local base = V(k * 0.35, -1.7, -0.5)
			spike(r, A, base, base + V(k * 0.1, -0.85, -0.5), 0.26, C.Bone)
		end
	end
	-- свисающие цепи
	chain(r, hub(r, "SwayChainL", LA, CF(-0.15, -1.75, 0.3), { Amp = 0.25, Speed = 2.2 }), 6, 0.36)
	for _, x in ipairs({ -0.8, 0.8 }) do
		chain(r, hub(r, x < 0 and "SwayChainW1" or "SwayChainW2", T, CF(x, -1.05, -0.65), { Amp = 0.2, Speed = 2 + x }), 4, 0.3)
	end
	-- набедренник с руной и рваным краем
	local cloth = r:Joint("SwayCloth", T, V(1.2, 1.7, 0.1), CF(0, -1.05, -0.75), CF(0, -0.85, 0), A_.Cloth, M.Fabric)
	gem(r, cloth, 0.3, CF(0, 0.2, -0.07), C.NeonSoft)
	tatter(r, cloth, -0.85, 0, 1.2, 4, A_.Cloth, M.Fabric, 2)
	r.Sec.SwayCloth = { Amp = 0.15, Speed = 1.8 }
	-- ноги: бедро, наколенник-шип, поножи, сапоги
	for _, Lg in ipairs({ RL, LL }) do
		bevel(r, Lg, V(1.05, 1.0, 1.05), CF(0, 0.45, 0), A_.Armor, A_.Edge)
		bevel(r, Lg, V(0.8, 0.5, 0.3), CF(0, -0.05, -0.62), A_.ArmorMid, GOLD)
		spike(r, Lg, V(0, 0.1, -0.7), V(0, 0.55, -1.1), 0.36, A_.Armor, M.Metal)
		bevel(r, Lg, V(1.1, 0.7, 1.12), CF(0, -0.38, 0), A_.ArmorMid, A_.Edge)
		bootA(r, Lg, A_.Armor, A_.Edge, 1.2)
	end

	-- РАЗБИТОЕ КОЛЬЦО за спиной
	local halo = hub(r, "SpinHalo", T, CF(0, 1.7, 1.35), { Speed = 0.35 })
	local ringParts = ring(r, halo, CF(), 2.6, 16, 0.3, 0.25, GOLD, M.Metal, function(i) return i == 3 or i == 10 or i == 11 end)
	ring(r, halo, CF(0, 0, -0.06), 2.32, 16, 0.08, 0.08, C.Neon, M.Neon, function(i) return i == 3 or i == 10 or i == 11 or i == 12 end)
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
	local ringStub = hide(ring(r, halo, CF(0, 0, -0.1), 2.6, 16, 0.1, 0.28, C.Neon, M.Neon, function(i) return i % 3 ~= 2 end))

	-- ПАРЯЩИЕ КАМНИ с кристаллами
	local stones = hub(r, "OrbitStones", T, CF(0, -0.5, 0), { Speed = 0.6 })
	for i = 0, 5 do
		local a = i / 6 * PI * 2
		local s = 0.42 + (i % 3) * 0.12
		local p = V(math.cos(a) * 4.0, math.sin(a * 2) * 0.5, math.sin(a) * 4.0)
		local cf = CF(p) * ANG(i * 0.7, i * 1.3, i * 0.4)
		bevel(r, stones, V(s * 1.3, s, s * 1.1), cf, C.Night, C.Mid, M.Slate)
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

	-- ФАЗА 2 (65% HP): трещины по броне и шлему, ядро ярче
	local cracks2 = hide(join(
		crack(r, T, { V(0.3, 1.1, -0.82), V(0.6, 0.75, -1.02), V(0.45, 0.3, -1.02), V(0.8, 0.05, -1.0) }, 0.08),
		crack(r, T, { V(1.2, 1.0, -0.8), V(1.0, 0.45, -0.8) }, 0.07),
		crack(r, H, { V(0.45, 0.6, -0.71), V(0.25, 0.35, -0.71), V(0.4, 0.05, -0.71) }, 0.06),
		crack(r, RL, { V(0.3, -0.1, -0.57), V(-0.1, -0.6, -0.57) }, 0.07),
		crack(r, LL, { V(-0.3, -0.15, -0.57), V(0.15, -0.65, -0.57) }, 0.07)
	))
	local aura2 = emitter(T, C.NeonSoft, { Rate = 14, Size = 0.45, SpeedMin = 2, SpeedMax = 4, Off = true })
	-- ФАЗА 3 (30% HP): корона и кольцо ломаются, вокруг кружится больше осколков
	local extraHub = hub(r, "OrbitShards3", T, CF(0, 0.4, 0), { Speed = 1.8 })
	local extra = {}
	for i = 0, 7 do
		local a = i / 8 * PI * 2
		local p = V(math.cos(a) * 4.4, math.sin(a * 3) * 0.6, math.sin(a) * 4.4)
		for _, q in ipairs(spike(r, extraHub, p - V(0, 0.35, 0), p + V(0, 0.45, 0), 0.32, C.NeonSoft, M.Neon, true)) do
			extra[#extra + 1] = q
		end
	end
	hide(extra)
	local rage = emitter(T, C.Magenta, { Rate = 20, Size = 0.5, SpeedMin = 3, SpeedMax = 7, Off = true })
	r.Phases = {
		{ At = 0.65, Reveal = cracks2, Emit = { aura2 }, Lights = { { coreLight, 3.5 } }, Aggro = 1.1 },
		{ At = 0.30, Reveal = join(stubs, extra, ringStub), Break = join(crownTall, ringBreak), Emit = { rage, smoke }, Lights = { { coreLight, 5 } }, Aggro = 1.4 },
	}
	return finishBiped(r, scale, { Root = { 4, 0, 0 }, RS = { 6, 0, 12 }, LS = { 6, 0, -12 } }, 7.4)
end

local Builders = {
	LostSoul = LostSoul,
	VoidCrawler = VoidCrawler,
	ShadowBeast = ShadowBeast,
	ArmoredHorror = ArmoredHorror,
	RiftPhantom = RiftPhantom,
	AbyssBrute = AbyssBrute,
	CorruptedTitan = CorruptedTitan,
	VoidDevourer = VoidDevourer,
	TheEntity = TheEntity,
}

-- Хелперы для модулей-расширений (HalloweenEnemies)
EnemyModels.H = {
	newCreature = newCreature, newBiped = newBiped, setup = setup, hub = hub, emitter = emitter,
	emitPoint = emitPoint, darkTrail = darkTrail, finishCreature = finishCreature, finishBiped = finishBiped,
	C = C, M = M, rgb = rgb, lite = lite, SMOKE_TEXTURE = SMOKE_TEXTURE,
}

function EnemyModels.Register(enemyId, builder)
	Builders[enemyId] = builder
end

function EnemyModels.Has(enemyId)
	return Builders[enemyId] ~= nil
end

function EnemyModels.Build(enemyId)
	local def = Config.Enemies[enemyId]
	local builder = Builders[enemyId]
	if not def or not builder then
		error("Unknown enemy " .. tostring(enemyId))
	end
	-- обычные враги идут толпами: для них фаска дешевле (2 детали вместо 4), шипы плоские
	Kit.Cheap = not def.IsBoss
	local ok, rig = pcall(builder, def.Scale or 1)
	Kit.Cheap = false
	if not ok then
		error(rig)
	end
	rig.Model.Name = enemyId
	Kit.Calm(rig.Model)
	for _, d in ipairs(rig.Model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CanQuery = false
			d.CanTouch = false
			d.CastShadow = def.IsBoss == true
		end
	end
	return rig
end

require(script.Parent:WaitForChild("HalloweenEnemies"))(EnemyModels)

return EnemyModels
]======] }
FILES[#FILES + 1] = { "ReplicatedStorage", { "VoidTD", "CaseModels" }, "ModuleScript", [======[
--!nocheck
-- VOID TD :: CaseModels
-- 3D-модели кейсов (витрины в лобби и анимация открытия). Все детали заякорены.
-- CaseModels.Build(caseId) -> { Model, Body, Lid, Core, Shards = {...}, Cracks = {...} }
-- Halloween дополнительно: Chains, Eyes, Fire (ParticleEmitter), LidParts, Hinge (CFrame петли крышки)

local CaseModels = {}

local V = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles
local rad = math.rad

local function part(parent, size, cf, color, material, props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if props then
		for k, v in pairs(props) do
			p[k] = v
		end
	end
	p.Parent = parent
	return p
end

local function neon(parent, size, cf, color, props)
	local p = part(parent, size, cf, color, Enum.Material.Neon, props)
	p.CastShadow = false
	return p
end

------------------------------------------------------------------------
-- VOID CASE: тёмный сундук с фиолетовым светящимся замком и сферой Пустоты
------------------------------------------------------------------------
local function VoidCase(m)
	local r = { Shards = {}, Cracks = {} }
	local dark, violet, glow = Color3.fromRGB(28, 22, 38), Color3.fromRGB(70, 30, 110), Color3.fromRGB(180, 80, 255)
	r.Body = part(m, V(4, 2.4, 3), CF(0, 1.2, 0), dark, Enum.Material.Metal)
	part(m, V(4.15, 0.35, 3.15), CF(0, 0.2, 0), violet, Enum.Material.Metal)
	r.Lid = part(m, V(4.1, 1.0, 3.1), CF(0, 2.9, 0), violet, Enum.Material.Metal)
	part(m, V(4.2, 0.2, 3.2), CF(0, 2.45, 0), Color3.fromRGB(200, 160, 60), Enum.Material.Metal)
	for _, x in ipairs({ -1.6, 1.6 }) do
		part(m, V(0.35, 3.4, 3.2), CF(x, 1.7, 0), Color3.fromRGB(200, 160, 60), Enum.Material.Metal)
	end
	r.Core = neon(m, V(0.9, 0.9, 0.3), CF(0, 1.9, -1.6) * ANG(0, 0, rad(45)), glow)
	local orb = neon(m, V(1.4, 1.4, 1.4), CF(0, 4.6, 0), glow, { Shape = Enum.PartType.Ball, Transparency = 0.2 })
	table.insert(r.Shards, orb)
	for i = 0, 3 do
		local a = i / 4 * math.pi * 2
		local s = neon(m, V(0.4, 0.8, 0.4), CF(math.cos(a) * 2.6, 3.6, math.sin(a) * 2.6) * ANG(rad(30), a, 0), glow)
		table.insert(r.Shards, s)
	end
	return r
end

------------------------------------------------------------------------
-- SHATTERED REALITY: кубический сундук с трещинами, кристаллом и осколками
------------------------------------------------------------------------
local function ShatteredReality(m)
	local r = { Shards = {}, Cracks = {} }
	local dark, purple, glow = Color3.fromRGB(26, 14, 44), Color3.fromRGB(60, 20, 110), Color3.fromRGB(170, 70, 255)
	r.Body = part(m, V(3.6, 3.6, 3.6), CF(0, 1.8, 0), dark, Enum.Material.Slate)
	r.Lid = part(m, V(3.8, 0.5, 3.8), CF(0, 3.75, 0), purple, Enum.Material.Slate)
	part(m, V(3.8, 0.4, 3.8), CF(0, 0.2, 0), purple, Enum.Material.Slate)
	-- угловые рёбра
	for _, x in ipairs({ -1.75, 1.75 }) do
		for _, z in ipairs({ -1.75, 1.75 }) do
			part(m, V(0.35, 3.8, 0.35), CF(x, 1.9, z), purple, Enum.Material.Metal)
		end
	end
	-- фиолетовые трещины на гранях
	local cracks = {
		{ V(-1.0, 2.6, -1.82), V(0.1, 1.6, -1.82) }, { V(0.1, 1.6, -1.82), V(-0.3, 0.6, -1.82) },
		{ V(0.1, 1.6, -1.82), V(1.1, 1.1, -1.82) }, { V(1.82, 2.8, -0.8), V(1.82, 1.4, 0.4) },
		{ V(1.82, 1.4, 0.4), V(1.82, 0.5, 1.1) }, { V(-1.82, 2.2, 0.9), V(-1.82, 0.9, -0.4) },
	}
	for _, c in ipairs(cracks) do
		local a, b = c[1], c[2]
		local len = (b - a).Magnitude
		local up = math.abs((b - a).Unit.Y) > 0.98 and V(0, 0, 1) or V(0, 1, 0)
		local cr = neon(m, V(0.14, 0.14, len), CFrame.lookAt((a + b) / 2, b, up), glow)
		table.insert(r.Cracks, cr)
	end
	r.Core = neon(m, V(1.2, 1.9, 1.2), CF(0, 5.0, 0) * ANG(0, rad(45), 0), glow)
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2
		local s = neon(m, V(0.35, 0.7, 0.2), CF(math.cos(a) * 2.8, 4.2 + (i % 2) * 0.8, math.sin(a) * 2.8) * ANG(rad(25), a, rad(20)), i % 2 == 0 and glow or Color3.fromRGB(220, 170, 255))
		table.insert(r.Shards, s)
	end
	return r
end

------------------------------------------------------------------------
-- BLOOD MOON: чёрный алтарь-сундук с кровавой луной над ним
------------------------------------------------------------------------
local function BloodMoon(m)
	local r = { Shards = {}, Cracks = {} }
	local black, crimson, glow = Color3.fromRGB(20, 8, 12), Color3.fromRGB(110, 15, 28), Color3.fromRGB(255, 40, 60)
	r.Body = part(m, V(3.8, 2.6, 3.2), CF(0, 1.3, 0), black, Enum.Material.Slate)
	r.Lid = part(m, V(4.0, 0.8, 3.4), CF(0, 3.0, 0), crimson, Enum.Material.Metal)
	part(m, V(4.2, 0.3, 3.6), CF(0, 0.15, 0), crimson, Enum.Material.Metal)
	-- клыки по краям крышки
	for i = -1, 1 do
		local w = Instance.new("WedgePart")
		w.Anchored = true
		w.CanCollide = false
		w.CanQuery = false
		w.Size = V(0.3, 0.7, 0.4)
		w.CFrame = CF(i * 1.2, 2.35, -1.75) * ANG(0, 0, math.pi)
		w.Color = Color3.fromRGB(235, 225, 215)
		w.Parent = m
	end
	r.Core = neon(m, V(0.8, 0.8, 0.3), CF(0, 1.5, -1.65) * ANG(0, 0, rad(45)), glow)
	local moon = neon(m, V(2.4, 2.4, 2.4), CF(0, 5.6, 0), glow, { Shape = Enum.PartType.Ball })
	part(m, V(2.45, 2.45, 2.45), CF(0.55, 5.8, -0.2), black, Enum.Material.SmoothPlastic, { Shape = Enum.PartType.Ball, Transparency = 0.15 })
	table.insert(r.Shards, moon)
	for i = 0, 4 do
		local a = i / 5 * math.pi * 2
		table.insert(r.Shards, neon(m, V(0.3, 0.3, 0.3), CF(math.cos(a) * 2.4, 4.0, math.sin(a) * 2.4), glow, { Shape = Enum.PartType.Ball }))
	end
	return r
end

------------------------------------------------------------------------
-- HALLOWEEN: чёрно-золотой проклятый сундук — светящиеся глаза, цепи с замком, оранжевый огонь.
-- Крышка — отдельный набор деталей (LidParts) с петлёй Hinge на заднем верхнем ребре корпуса.
------------------------------------------------------------------------
local function wedge(parent, size, cf, color, material)
	local w = Instance.new("WedgePart")
	w.Anchored = true
	w.CanCollide = false
	w.CanTouch = false
	w.CanQuery = false
	w.Size = size
	w.CFrame = cf
	w.Color = color
	w.Material = material or Enum.Material.SmoothPlastic
	w.Parent = parent
	return w
end

-- цепь из звеньев между точками a и b
local function chainLinks(parent, list, a, b, color)
	local d = b - a
	local n = math.max(2, math.floor(d.Magnitude / 0.36))
	local up = math.abs(d.Unit.Y) > 0.98 and V(0, 0, 1) or V(0, 1, 0)
	for i = 0, n - 1 do
		local p = a + d * ((i + 0.5) / n)
		local cf = CFrame.lookAt(p, p + d, up) * ANG(0, 0, (i % 2 == 0) and 0 or math.pi / 2)
		list[#list + 1] = part(parent, V(0.3, 0.1, 0.44), cf, color, Enum.Material.Metal)
	end
end

local function fireEmitter(parent, list, cf, size, rate)
	local p = part(parent, V(size, 0.2, size), cf, Color3.new(), Enum.Material.SmoothPlastic, { Transparency = 1 })
	local e = Instance.new("ParticleEmitter")
	e.Name = "CursedFire"
	e.Color = ColorSequence.new(Color3.fromRGB(255, 200, 90), Color3.fromRGB(255, 70, 20))
	e.LightEmission = 1
	e.LightInfluence = 0
	e.Rate = rate or 14
	e.Lifetime = NumberRange.new(0.5, 0.9)
	e.Speed = NumberRange.new(1.5, 3)
	e.EmissionDirection = Enum.NormalId.Top
	e.SpreadAngle = Vector2.new(12, 12)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 1) })
	e.Parent = p
	list[#list + 1] = e
	return p
end

local function Halloween(m)
	local r = { Shards = {}, Cracks = {}, Chains = {}, Eyes = {}, Fire = {}, LidParts = {} }
	local black, coal = Color3.fromRGB(20, 14, 22), Color3.fromRGB(38, 26, 40)
	local gold, goldDark = Color3.fromRGB(214, 168, 70), Color3.fromRGB(140, 100, 40)
	local orange, ember = Color3.fromRGB(255, 130, 30), Color3.fromRGB(255, 190, 80)
	local iron = Color3.fromRGB(70, 64, 76)
	local W, Hh, D = 4.0, 2.4, 2.8
	-- корпус
	r.Body = part(m, V(W, Hh, D), CF(0, 0.3 + Hh / 2, 0), black, Enum.Material.Slate)
	part(m, V(W + 0.3, 0.35, D + 0.3), CF(0, 0.18, 0), gold, Enum.Material.Metal)
	part(m, V(W - 0.4, 0.12, D - 0.4), CF(0, 0.02, 0), goldDark, Enum.Material.Metal)
	-- ножки-когти
	for _, x in ipairs({ -1, 1 }) do
		for _, z in ipairs({ -1, 1 }) do
			wedge(m, V(0.5, 0.45, 0.5), CF(x * (W / 2 - 0.1), 0.0, z * (D / 2 - 0.1)) * ANG(0, (z < 0) and 0 or math.pi, 0) * ANG(math.pi, 0, 0), gold, Enum.Material.Metal)
		end
	end
	-- золотые рёбра и тёмные доски
	for _, x in ipairs({ -1, 1 }) do
		for _, z in ipairs({ -1, 1 }) do
			part(m, V(0.3, Hh + 0.05, 0.3), CF(x * (W / 2 - 0.08), 0.3 + Hh / 2, z * (D / 2 - 0.08)), gold, Enum.Material.Metal)
		end
	end
	for _, y in ipairs({ 0.95, 1.75 }) do
		part(m, V(W - 0.4, 0.06, 0.06), CF(0, y, -D / 2 - 0.01), coal, Enum.Material.Wood)
	end
	part(m, V(W + 0.06, 0.2, D + 0.06), CF(0, 0.3 + Hh - 0.1, 0), gold, Enum.Material.Metal)
	-- светящиеся глаза со злыми бровями
	for _, s in ipairs({ -1, 1 }) do
		local eye = neon(m, V(0.62, 0.3, 0.12), CF(0.85 * s, 1.95, -D / 2 - 0.04) * ANG(0, 0, math.rad(-14 * s)), orange)
		table.insert(r.Eyes, eye)
		table.insert(r.Eyes, neon(m, V(0.16, 0.16, 0.14), CF(0.85 * s, 1.93, -D / 2 - 0.06) * ANG(0, 0, math.rad(45)), ember))
		part(m, V(0.8, 0.14, 0.12), CF(0.8 * s, 2.22, -D / 2 - 0.05) * ANG(0, 0, math.rad(22 * s)), gold, Enum.Material.Metal)
	end
	-- клыкастая пасть под глазами
	part(m, V(2.2, 0.32, 0.08), CF(0, 1.52, -D / 2 - 0.02), Color3.fromRGB(60, 16, 10))
	for k = -3, 3 do
		wedge(m, V(0.08, 0.22, 0.2), CF(k * 0.3, 1.57, -D / 2 - 0.08) * ANG(0, math.pi / 2, 0) * ANG(math.pi, 0, 0), Color3.fromRGB(230, 220, 200))
	end
	-- цепи крест-накрест по фасаду и замок
	local fz = -D / 2 - 0.12
	chainLinks(m, r.Chains, V(-W / 2 + 0.2, 0.5, fz), V(-0.3, 1.0, fz), iron)
	chainLinks(m, r.Chains, V(W / 2 - 0.2, 0.5, fz), V(0.3, 1.0, fz), iron)
	chainLinks(m, r.Chains, V(0, 1.35, fz - 0.05), V(0, 2.65, fz - 0.05), iron)
	-- цепи по бокам
	for _, x in ipairs({ -1, 1 }) do
		chainLinks(m, r.Chains, V(x * (W / 2 + 0.1), 2.6, -D / 2 + 0.2), V(x * (W / 2 + 0.1), 0.45, D / 2 - 0.2), iron)
	end
	local lock = part(m, V(0.8, 0.75, 0.3), CF(0, 0.95, fz - 0.15), gold, Enum.Material.Metal)
	table.insert(r.Chains, lock)
	for _, s in ipairs({ -1, 1 }) do
		table.insert(r.Chains, part(m, V(0.12, 0.4, 0.12), CF(0.25 * s, 1.45, fz - 0.15), goldDark, Enum.Material.Metal))
	end
	table.insert(r.Chains, part(m, V(0.62, 0.12, 0.12), CF(0, 1.62, fz - 0.15), goldDark, Enum.Material.Metal))
	r.Core = neon(m, V(0.2, 0.32, 0.08), CF(0, 0.9, fz - 0.32), orange)
	table.insert(r.Chains, r.Core)
	-- крышка (на петле сзади)
	local lidY = 0.3 + Hh
	local function lid(p)
		table.insert(r.LidParts, p)
		return p
	end
	r.Lid = lid(part(m, V(W + 0.1, 0.55, D + 0.1), CF(0, lidY + 0.28, 0), black, Enum.Material.Slate))
	lid(part(m, V(W - 0.3, 0.42, D - 0.5), CF(0, lidY + 0.76, 0), coal, Enum.Material.Slate))
	lid(wedge(m, V(W - 0.3, 0.42, 0.25), CF(0, lidY + 0.76, -D / 2 + 0.12), coal, Enum.Material.Slate))
	lid(wedge(m, V(W - 0.3, 0.42, 0.25), CF(0, lidY + 0.76, D / 2 - 0.12) * ANG(0, math.pi, 0), coal, Enum.Material.Slate))
	lid(part(m, V(W + 0.2, 0.16, D + 0.2), CF(0, lidY + 0.06, 0), gold, Enum.Material.Metal))
	lid(part(m, V(W - 0.2, 0.12, 0.3), CF(0, lidY + 0.98, 0), gold, Enum.Material.Metal))
	for _, x in ipairs({ -1, 1 }) do
		lid(part(m, V(0.3, 0.62, D + 0.16), CF(x * (W / 2 - 0.1), lidY + 0.3, 0), gold, Enum.Material.Metal))
		-- рога по углам крышки
		local base = V(x * (W / 2 - 0.35), lidY + 1.0, -D / 2 + 0.4)
		lid(wedge(m, V(0.3, 0.7, 0.4), CFrame.new(base + V(x * 0.15, 0.3, 0)) * ANG(0, 0, math.rad(-25 * x)) * ANG(0, math.pi, 0), gold, Enum.Material.Metal))
	end
	-- оранжевый камень-око на крышке
	lid(neon(m, V(0.42, 0.42, 0.14), CF(0, lidY + 0.3, -D / 2 - 0.1) * ANG(0, 0, math.rad(45)), orange))
	-- петли
	for _, x in ipairs({ -1.2, 1.2 }) do
		part(m, V(0.5, 0.3, 0.2), CF(x, lidY, D / 2 + 0.08), gold, Enum.Material.Metal)
	end
	r.Hinge = CF(0, lidY, D / 2)
	-- огонь по углам и угли вокруг
	for _, x in ipairs({ -1, 1 }) do
		fireEmitter(m, r.Fire, CF(x * (W / 2 + 0.2), 0.45, -D / 2 - 0.2), 0.5, 12)
		fireEmitter(m, r.Fire, CF(x * (W / 2 - 0.35), lidY + 1.35, -D / 2 + 0.4), 0.3, 8)
	end
	for i = 0, 3 do
		local a = i / 4 * math.pi * 2 + 0.4
		table.insert(r.Shards, neon(m, V(0.25, 0.25, 0.25), CF(math.cos(a) * 2.8, 3.4 + (i % 2) * 0.6, math.sin(a) * 2.6) * ANG(math.rad(45), a, math.rad(45)), ember))
	end
	return r
end

local Builders = { VoidCase = VoidCase, ShatteredReality = ShatteredReality, BloodMoon = BloodMoon, Halloween = Halloween }

function CaseModels.Build(caseId)
	local m = Instance.new("Model")
	m.Name = "Case_" .. tostring(caseId)
	local builder = Builders[caseId] or VoidCase
	local r = builder(m)
	m.PrimaryPart = r.Body
	m.WorldPivot = CF(0, 0, 0)
	r.Model = m
	-- приглушённый неон
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") and d.Material == Enum.Material.Neon then
			d.Color = d.Color:Lerp(Color3.fromRGB(14, 10, 22), 0.3)
		end
	end
	-- запоминаем исходные позиции для анимации
	r.Base = {}
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			r.Base[d] = d.CFrame
		end
	end
	return r
end

return CaseModels
]======] }

for _, f in ipairs(FILES) do
	install(f[1], f[2], f[3], f[4])
end
print("[VOID TD] Часть 1/3 установлена" .. (0 == 2 and ". Готово! Сохрани место и нажми Play." or ". Вставь следующую часть."))
