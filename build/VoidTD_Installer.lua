-- =====================================================================
--  VOID TD — установщик для Command Bar (Roblox Studio)
--  1) View -> Command Bar   2) вставь ВЕСЬ этот файл   3) Enter
--  Затем File -> Save и нажми Play.
--  Файл собран автоматически из src/ (tools/build_installer.py). Не редактируй вручную.
-- =====================================================================
local REMOVE_DEFAULT_BASEPLATE = true -- убрать стандартный Baseplate/SpawnLocation шаблона

local RS = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")
local SPS = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")
local SERVICES = { ReplicatedStorage = RS, ServerScriptService = SSS, StarterPlayerScripts = SPS }

-- удалить предыдущую установку
for _, pair in ipairs({ { RS, "VoidTD" }, { SSS, "VoidTDServer" }, { SPS, "VoidTDClient" }, { workspace, "VoidTDMap" }, { workspace, "VoidTDLobby" }, { workspace, "VoidTDHalloween" }, { workspace, "VoidTDHalloweenMap" } }) do
	local obj = pair[1]:FindFirstChild(pair[2])
	if obj then obj:Destroy() end
end
if REMOVE_DEFAULT_BASEPLATE then
	local bp = workspace:FindFirstChild("Baseplate")
	if bp and bp:IsA("BasePart") then bp:Destroy() end
	local sp = workspace:FindFirstChild("SpawnLocation")
	if sp and sp:IsA("SpawnLocation") then sp:Destroy() end
end
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
FILES[#FILES + 1] = { "ServerScriptService", { "VoidTDServer" }, "Script", [======[
--!nocheck
-- VOID TD :: Server bootstrap

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("VoidTD")
local Config = require(Shared:WaitForChild("Config"))

local MapBuilder = require(script:WaitForChild("MapBuilder"))
local DataService = require(script:WaitForChild("DataService"))
local GameService = require(script:WaitForChild("GameService"))
local HalloweenService = require(script:WaitForChild("HalloweenService"))

-- Remotes / State
local function folder(parent, name)
	local f = parent:FindFirstChild(name)
	if f then
		f:Destroy()
	end
	f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

local remotesFolder = folder(Shared, "Remotes")
local remotes = {}
for _, name in ipairs({ "EnemySpawn", "Sync", "Attack", "Impact", "Notify", "Profile" }) do
	local r = Instance.new("RemoteEvent")
	r.Name = name
	r.Parent = remotesFolder
	remotes[name] = r
end
local request = Instance.new("RemoteFunction")
request.Name = "Request"
request.Parent = remotesFolder
remotes.Request = request

local state = folder(Shared, "State")
local unitsFolder = folder(Shared, "Units")

local map = MapBuilder.Build()
-- Хэллоуин: остров с порталом и карта Haunted Hollow
local okH, halloweenMap = pcall(MapBuilder.BuildHalloween)
if not okH then
	warn("[VOID TD] Хэллоуин-мир не построен: " .. tostring(halloweenMap))
	halloweenMap = nil
end
GameService.Init(remotes, state, unitsFolder, map, { Void = map, Halloween = halloweenMap })
HalloweenService.Init(GameService, state)

local function pushProfile(player)
	local snap = DataService.Snapshot(player)
	if snap then
		remotes.Profile:FireClient(player, snap)
	end
end
GameService.OnProfileChanged = pushProfile

local function onPlayerAdded(player)
	DataService.Load(player)
	GameService.PlayerAdded(player)
	player:SetAttribute("VoidReady", true)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, p in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, p)
end

Players.PlayerRemoving:Connect(function(player)
	GameService.PlayerRemoving(player)
	DataService.Release(player)
end)

game:BindToClose(function()
	for _, p in ipairs(Players:GetPlayers()) do
		DataService.Save(p, true)
	end
	task.wait(2)
end)

-- Простое ограничение частоты запросов
local budget = {}
local function allow(player)
	local t = os.clock()
	local b = budget[player]
	if not b or t - b.Start > 1 then
		budget[player] = { Start = t, Count = 1 }
		return true
	end
	b.Count = b.Count + 1
	return b.Count <= 25
end
Players.PlayerRemoving:Connect(function(p)
	budget[p] = nil
end)

local handlers = {}

handlers.GetProfile = function(player)
	return true, DataService.Snapshot(player)
end

handlers.GetEnemies = function()
	return true, GameService.GetEnemySnapshot()
end

handlers.Place = function(player, data)
	if type(data) ~= "table" then
		return false, "Неверный запрос"
	end
	return GameService.PlaceUnit(player, data.Unit, data.Position, data.Rotation)
end

handlers.Upgrade = function(player, data)
	return GameService.UpgradeUnit(player, type(data) == "table" and data.Uid or data)
end

handlers.Sell = function(player, data)
	return GameService.SellUnit(player, type(data) == "table" and data.Uid or data)
end

handlers.SetTarget = function(player, data)
	if type(data) ~= "table" then
		return false, "Неверный запрос"
	end
	return GameService.SetTargetMode(player, data.Uid, data.Mode)
end

handlers.JoinMatch = function(player, data)
	return GameService.JoinMatch(player, type(data) == "table" and data.Difficulty or nil)
end

handlers.LeaveMatch = function(player)
	return GameService.LeaveMatch(player)
end

handlers.GetMatchInfo = function()
	return true, GameService.GetMatchInfo()
end

handlers.SetLite = function(player, data)
	local prof = DataService.Get(player)
	prof.Settings = prof.Settings or {}
	prof.Settings.Lite = type(data) == "table" and data.On == true
	DataService.Save(player)
	return true
end

handlers.ClaimDaily = function(player)
	local ok, res = DataService.ClaimDaily(player)
	if ok then
		pushProfile(player)
	end
	return ok, res
end

handlers.BuyGems = function(player, data)
	local key = type(data) == "table" and data.Key
	local item
	for _, it in ipairs(Config.Shop) do
		if it.Key == key then
			item = it
		end
	end
	if not item then
		return false, "Неизвестный товар"
	end
	if (item.ProductId or 0) > 0 then
		MarketplaceService:PromptProductPurchase(player, item.ProductId)
		return true, "prompt"
	end
	if Config.Settings.ShopTestMode and RunService:IsStudio() then
		DataService.GrantPurchase(player, item.Gems, nil)
		pushProfile(player)
		return true, item.Gems
	end
	return false, "Товар не настроен: укажи ProductId в Config.Shop"
end

handlers.StartWave = function(player)
	return GameService.RequestStartWave(player)
end

handlers.Summon = function(player, data)
	local count = (type(data) == "table" and data.Count == 10) and 10 or 1
	local caseId = type(data) == "table" and data.Case or "VoidCase"
	local ok, result = DataService.Summon(player, caseId, count)
	if ok then
		pushProfile(player)
	end
	return ok, result
end

handlers.EquipRune = function(player, data)
	if type(data) ~= "table" or type(data.Unit) ~= "string" then
		return false, "Неверный запрос"
	end
	local runeId = type(data.Rune) == "string" and data.Rune or nil
	local ok, err = DataService.EquipRune(player, data.Unit, runeId)
	if ok then
		pushProfile(player)
	end
	return ok, err
end

handlers.Teleport = function(player, data)
	return HalloweenService.Teleport(player, type(data) == "table" and data.To or nil)
end

handlers.QueueDifficulty = function(player, data)
	return HalloweenService.SetDifficulty(player, type(data) == "table" and data.Difficulty or nil)
end

handlers.QueueStart = function(player)
	return HalloweenService.StartNow(player)
end

handlers.QueueLeave = function(player)
	return HalloweenService.Leave(player)
end

handlers.Equip = function(player, data)
	if type(data) ~= "table" then
		return false, "Неверный запрос"
	end
	local ok, err = DataService.Equip(player, data.Unit, data.Slot)
	if ok then
		pushProfile(player)
	end
	return ok, err
end

request.OnServerInvoke = function(player, action, data)
	if not allow(player) then
		return false, "Слишком много запросов"
	end
	if not DataService.Get(player) then
		return false, "Профиль ещё загружается"
	end
	local h = handlers[action]
	if not h then
		return false, "Неизвестное действие"
	end
	local ok, a, b = pcall(h, player, data)
	if not ok then
		warn("[VOID TD] Ошибка обработки " .. tostring(action) .. ": " .. tostring(a))
		return false, "Ошибка сервера"
	end
	return a, b
end

-- Покупки за Robux (Developer Products из Config.Shop)
MarketplaceService.ProcessReceipt = function(info)
	local player = Players:GetPlayerByUserId(info.PlayerId)
	if not player or not DataService.Get(player) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	for _, it in ipairs(Config.Shop) do
		if it.ProductId == info.ProductId then
			DataService.GrantPurchase(player, it.Gems, info.PurchaseId)
			pushProfile(player)
			remotes.Notify:FireClient(player, { Type = "Purchase", Gems = it.Gems })
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
	end
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

-- Гемы меняются от наград за волны — периодически отправляем профиль
task.spawn(function()
	while true do
		task.wait(5)
		for _, p in ipairs(Players:GetPlayers()) do
			local prof = DataService.Get(p)
			if prof and (p:GetAttribute("LastGems") ~= prof.Gems or p:GetAttribute("LastCoins") ~= prof.HalloweenCoins) then
				p:SetAttribute("LastGems", prof.Gems)
				p:SetAttribute("LastCoins", prof.HalloweenCoins)
				pushProfile(p)
				DataService.Save(p)
			end
		end
	end
end)

print("[VOID TD] Сервер запущен. Карта: " .. Config.Map.Name)
]======] }
FILES[#FILES + 1] = { "ServerScriptService", { "VoidTDServer", "MapBuilder" }, "ModuleScript", [======[
--!nocheck
-- VOID TD :: MapBuilder
-- Строит карту "The Forgotten Realm" программно. Повторный вызов ничего не дублирует.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("VoidTD")
local Config = require(Shared:WaitForChild("Config"))
local PathUtil = require(Shared:WaitForChild("PathUtil"))

local MapBuilder = {}

local V = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles
local rad = math.rad

local GY = Config.Map.GroundY

local C = {
	Ground = Color3.fromRGB(38, 34, 48),
	Ground2 = Color3.fromRGB(46, 38, 60),
	Moss = Color3.fromRGB(52, 34, 72),
	Rock = Color3.fromRGB(30, 27, 38),
	Rock2 = Color3.fromRGB(44, 40, 54),
	Path = Color3.fromRGB(72, 64, 84),
	PathEdge = Color3.fromRGB(56, 50, 66),
	Stone = Color3.fromRGB(88, 84, 98),
	Stone2 = Color3.fromRGB(64, 60, 74),
	Neon = Color3.fromRGB(170, 70, 255),
	NeonPink = Color3.fromRGB(255, 70, 180),
	NeonSoft = Color3.fromRGB(210, 150, 255),
	Bark = Color3.fromRGB(28, 22, 30),
	Leaf = Color3.fromRGB(46, 22, 64),
	Leaf2 = Color3.fromRGB(30, 16, 44),
	Black = Color3.fromRGB(12, 8, 18),
}

local function part(parent, props)
	local p = Instance.new(props.Class or "Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = props.Material or Enum.Material.SmoothPlastic
	p.Color = props.Color or C.Ground
	p.Size = props.Size or V(4, 4, 4)
	if props.Shape then
		p.Shape = props.Shape
	end
	p.CFrame = props.CFrame or CF()
	p.Transparency = props.Transparency or 0
	p.CanCollide = props.CanCollide ~= false
	p.CastShadow = props.CastShadow ~= false
	p.Name = props.Name or "Part"
	if props.Material == Enum.Material.Neon then
		p.CastShadow = false
	end
	p.Parent = parent
	return p
end

local function light(p, color, range, brightness)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Shadows = false
	l.Parent = p
	return l
end

local function emitter(p, color, o)
	o = o or {}
	local e = Instance.new("ParticleEmitter")
	e.Color = ColorSequence.new(color)
	e.LightEmission = 1
	e.LightInfluence = 0
	e.Rate = o.Rate or 10
	e.Lifetime = NumberRange.new(o.LifeMin or 1, o.LifeMax or 2)
	e.Speed = NumberRange.new(o.SpeedMin or 1, o.SpeedMax or 3)
	e.SpreadAngle = Vector2.new(o.Spread or 180, o.Spread or 180)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, o.Size or 0.5), NumberSequenceKeypoint.new(1, 0) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	if o.Accel then
		e.Acceleration = o.Accel
	end
	if o.Dir then
		e.EmissionDirection = o.Dir
	end
	e.Parent = p
	return e
end

------------------------------------------------------------------------
-- ОСВЕЩЕНИЕ
------------------------------------------------------------------------
local function setupLighting()
	Lighting.ClockTime = 0.2
	Lighting.Brightness = 2
	Lighting.Ambient = Color3.fromRGB(58, 40, 86)
	Lighting.OutdoorAmbient = Color3.fromRGB(86, 64, 120)
	Lighting.ColorShift_Top = Color3.fromRGB(120, 80, 200)
	Lighting.EnvironmentDiffuseScale = 0.4
	Lighting.EnvironmentSpecularScale = 0.6
	Lighting.GlobalShadows = true
	Lighting.FogColor = Color3.fromRGB(40, 20, 70)
	Lighting.FogStart = 150
	Lighting.FogEnd = 900
	pcall(function()
		Lighting.Technology = Enum.Technology.Future
	end)

	for _, name in ipairs({ "VoidAtmosphere", "VoidBloom", "VoidColor", "VoidSky", "VoidRays" }) do
		local old = Lighting:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end
	for _, child in ipairs(Lighting:GetChildren()) do
		if child:IsA("Atmosphere") or child:IsA("Sky") then
			child:Destroy()
		end
	end

	local atmo = Instance.new("Atmosphere")
	atmo.Name = "VoidAtmosphere"
	atmo.Density = 0.38
	atmo.Offset = 0.15
	atmo.Color = Color3.fromRGB(110, 60, 170)
	atmo.Decay = Color3.fromRGB(40, 10, 60)
	atmo.Glare = 0.3
	atmo.Haze = 2.2
	atmo.Parent = Lighting

	local sky = Instance.new("Sky")
	sky.Name = "VoidSky"
	sky.StarCount = 5000
	sky.CelestialBodiesShown = true
	sky.MoonAngularSize = 18
	sky.Parent = Lighting

	local bloom = Instance.new("BloomEffect")
	bloom.Name = "VoidBloom"
	bloom.Intensity = 0.35
	bloom.Size = 18
	bloom.Threshold = 1.4
	bloom.Parent = Lighting

	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "VoidColor"
	cc.Brightness = 0.02
	cc.Contrast = 0.12
	cc.Saturation = 0.12
	cc.TintColor = Color3.fromRGB(240, 225, 255)
	cc.Parent = Lighting
end

------------------------------------------------------------------------
-- ОСТРОВ
------------------------------------------------------------------------
local function buildIsland(map, rng)
	local ground = Instance.new("Folder")
	ground.Name = "Ground"
	ground.Parent = map

	local size = Config.Map.IslandSize
	local top = part(ground, {
		Name = "IslandTop",
		Size = V(size.X, 4, size.Y),
		CFrame = CF(0, GY - 2, 0),
		Color = C.Ground,
		Material = Enum.Material.Slate,
	})
	top:SetAttribute("Placeable", true)

	-- цветные пятна мха на поверхности
	for i = 1, 18 do
		local w, d = rng:NextNumber(14, 34), rng:NextNumber(14, 30)
		local x = rng:NextNumber(-size.X / 2 + w / 2 + 2, size.X / 2 - w / 2 - 2)
		local z = rng:NextNumber(-size.Y / 2 + d / 2 + 2, size.Y / 2 - d / 2 - 2)
		local patch = part(ground, {
			Name = "Moss",
			Size = V(w, 0.2, d),
			CFrame = CF(x, GY + 0.02 + i * 0.001, z) * ANG(0, rad(rng:NextNumber(-20, 20)), 0),
			Color = (i % 2 == 0) and C.Moss or C.Ground2,
			Material = Enum.Material.Grass,
			CastShadow = false,
		})
		patch:SetAttribute("Placeable", true)
	end

	-- неровный край острова
	local under = Instance.new("Folder")
	under.Name = "Underside"
	under.Parent = map
	local perim = {}
	for x = -size.X / 2, size.X / 2, 16 do
		perim[#perim + 1] = V(x, 0, -size.Y / 2)
		perim[#perim + 1] = V(x, 0, size.Y / 2)
	end
	for z = -size.Y / 2 + 16, size.Y / 2 - 16, 16 do
		perim[#perim + 1] = V(-size.X / 2, 0, z)
		perim[#perim + 1] = V(size.X / 2, 0, z)
	end
	for _, p in ipairs(perim) do
		local s = rng:NextNumber(10, 20)
		local h = rng:NextNumber(5, 9)
		part(under, {
			Name = "EdgeRock",
			Size = V(s, h, s * rng:NextNumber(0.7, 1.2)),
			CFrame = CF(p.X, GY - h / 2 + rng:NextNumber(-1.5, 0.2), p.Z) * ANG(rad(rng:NextNumber(-6, 6)), rad(rng:NextNumber(0, 90)), rad(rng:NextNumber(-6, 6))),
			Color = (rng:NextInteger(1, 2) == 1) and C.Rock or C.Rock2,
			Material = Enum.Material.Slate,
		})
	end

	-- каменное "дно" острова, сужается вниз
	local layers = {
		{ 0.92, 12, -9 },
		{ 0.75, 16, -22 },
		{ 0.55, 18, -38 },
		{ 0.32, 20, -55 },
		{ 0.14, 18, -72 },
	}
	for i, l in ipairs(layers) do
		part(under, {
			Name = "Bedrock" .. i,
			Size = V(size.X * l[1], l[2], size.Y * l[1]),
			CFrame = CF(rng:NextNumber(-6, 6), GY + l[3], rng:NextNumber(-6, 6)) * ANG(0, rad(rng:NextNumber(-8, 8)), 0),
			Color = (i % 2 == 0) and C.Rock or C.Rock2,
			Material = Enum.Material.Slate,
		})
		-- светящиеся жилы в камне
		if i <= 4 then
			local vein = part(under, {
				Name = "Vein",
				Size = V(size.X * l[1] * 0.6, 0.6, 0.6),
				CFrame = CF(0, GY + l[3] + rng:NextNumber(-3, 3), -size.Y * l[1] / 2 - 0.1) * ANG(0, 0, rad(rng:NextNumber(-12, 12))),
				Color = C.Neon,
				Material = Enum.Material.Neon,
			})
			vein.CanCollide = false
		end
	end
	local tip = part(under, {
		Name = "Crystal Root",
		Size = V(10, 22, 10),
		CFrame = CF(0, GY - 92, 0) * ANG(rad(8), rad(45), 0),
		Color = C.Neon,
		Material = Enum.Material.Neon,
	})
	light(tip, C.Neon, 40, 3)
	return ground
end

------------------------------------------------------------------------
-- ДОРОГА
------------------------------------------------------------------------
local function buildPath(map, rng)
	local folder = Instance.new("Folder")
	folder.Name = "Path"
	folder.Parent = map
	local pts = PathUtil.Points
	local w = Config.Map.PathWidth
	for i = 2, #pts do
		local a, b = pts[i - 1], pts[i]
		local len = (b - a).Magnitude
		local mid = (a + b) / 2
		local cf = CFrame.lookAt(V(mid.X, GY + 0.15, mid.Z), V(b.X, GY + 0.15, b.Z))
		part(folder, {
			Name = "Road",
			Size = V(w, 0.3, len + w),
			CFrame = cf,
			Color = C.Path,
			Material = Enum.Material.Cobblestone,
		})
		part(folder, {
			Name = "RoadEdge",
			Size = V(w + 1.6, 0.22, len + w + 1.6),
			CFrame = cf * CF(0, -0.06, 0),
			Color = C.PathEdge,
			Material = Enum.Material.Slate,
		})
		-- разбросанные камни по краям дороги
		local steps = math.floor(len / 14)
		for s = 1, steps do
			local t = s / (steps + 1)
			local side = (s % 2 == 0) and 1 or -1
			local pos = a:Lerp(b, t)
			local dir = (b - a).Unit
			local right = V(-dir.Z, 0, dir.X)
			local p = pos + right * side * (w / 2 + 1.2)
			local sz = rng:NextNumber(0.8, 1.6)
			part(folder, {
				Name = "Pebble",
				Size = V(sz, sz * 0.7, sz * 1.2),
				CFrame = CF(p.X, GY + sz * 0.3, p.Z) * ANG(rad(rng:NextNumber(-20, 20)), rad(rng:NextNumber(0, 180)), 0),
				Color = C.Stone2,
				Material = Enum.Material.Slate,
				CanCollide = false,
			})
		end
		-- фиолетовые трещины на дороге
		if i % 2 == 0 then
			local p = a:Lerp(b, 0.5)
			part(folder, {
				Name = "Crack",
				Size = V(0.35, 0.05, math.min(len * 0.4, 12)),
				CFrame = CF(p.X + rng:NextNumber(-2, 2), GY + 0.31, p.Z + rng:NextNumber(-2, 2)) * CFrame.lookAt(Vector3.zero, b - a).Rotation * ANG(0, rad(rng:NextNumber(-25, 25)), 0),
				Color = C.Neon,
				Material = Enum.Material.Neon,
				CanCollide = false,
			})
		end
	end
	return folder
end

------------------------------------------------------------------------
-- ПОРТАЛ
------------------------------------------------------------------------
local function buildPortal(map, rng)
	local m = Instance.new("Model")
	m.Name = "VoidPortal"
	m.Parent = map
	local start = PathUtil.Points[1]
	local dir = (PathUtil.Points[2] - start).Unit
	local R = 10
	local center = start - dir * 4 + V(0, R + 1, 0)
	local base = CFrame.lookAt(center, center + dir)

	-- ступени-платформа
	part(m, { Name = "Base", Size = V(26, 1.2, 12), CFrame = CF(start.X - dir.X * 4, GY + 0.4, start.Z - dir.Z * 4) * base.Rotation, Color = C.Stone2, Material = Enum.Material.Slate })
	part(m, { Name = "Base2", Size = V(22, 1.2, 9), CFrame = CF(start.X - dir.X * 4, GY + 1.2, start.Z - dir.Z * 4) * base.Rotation, Color = C.Stone, Material = Enum.Material.Slate })

	-- каменное кольцо из блоков
	local n = 18
	for i = 0, n - 1 do
		local a = i / n * math.pi * 2
		if i ~= 4 then -- один камень выпал
			local off = V(math.cos(a) * R, math.sin(a) * R, 0)
			local jitter = rng:NextNumber(-0.4, 0.4)
			part(m, {
				Name = "RingStone",
				Size = V(3.6, 3.2 + jitter, 3),
				CFrame = base * CF(off) * ANG(0, 0, a + rad(rng:NextNumber(-4, 4))),
				Color = (i % 3 == 0) and C.Stone or C.Stone2,
				Material = Enum.Material.Slate,
			})
			if i % 3 == 0 then
				part(m, {
					Name = "Rune",
					Size = V(0.6, 1.4, 0.3),
					CFrame = base * CF(off * 1.0) * ANG(0, 0, a) * CF(0, 0, -1.55),
					Color = C.Neon,
					Material = Enum.Material.Neon,
					CanCollide = false,
				})
			end
		end
	end
	-- обломок, упавший с кольца
	part(m, { Name = "Fallen", Size = V(3.4, 2.8, 3), CFrame = CF(center.X + 6, GY + 1.4, center.Z + 9) * ANG(rad(20), rad(30), rad(10)), Color = C.Stone2, Material = Enum.Material.Slate })

	-- воронка портала
	local disc = part(m, {
		Name = "PortalDisc",
		Shape = Enum.PartType.Cylinder,
		Size = V(0.4, R * 2 - 2.5, R * 2 - 2.5),
		CFrame = base * ANG(0, rad(90), 0),
		Color = Color3.fromRGB(110, 30, 190),
		Material = Enum.Material.Neon,
		Transparency = 0.15,
		CanCollide = false,
	})
	local inner = part(m, {
		Name = "PortalCore",
		Shape = Enum.PartType.Cylinder,
		Size = V(0.5, R * 1.1, R * 1.1),
		CFrame = base * ANG(0, rad(90), 0),
		Color = Color3.fromRGB(15, 0, 30),
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
	for i = 0, 2 do
		local swirl = part(m, {
			Name = "Swirl",
			Size = V(0.6, R * 1.6, 0.7),
			CFrame = base * ANG(0, 0, rad(i * 60)) * CF(0, 0, -0.4),
			Color = C.NeonSoft,
			Material = Enum.Material.Neon,
			Transparency = 0.35,
			CanCollide = false,
		})
		swirl:SetAttribute("Spin", 1.6 + i * 0.4)
		swirl:SetAttribute("SpinAxis", "Z")
	end
	light(inner, C.Neon, 45, 4)
	emitter(disc, C.Neon, { Rate = 40, Size = 0.8, SpeedMin = 2, SpeedMax = 6, LifeMin = 1, LifeMax = 2 })
	return m, center
end

------------------------------------------------------------------------
-- ЯДРО ПУСТОТЫ
------------------------------------------------------------------------
local function buildCore(map, rng)
	local m = Instance.new("Model")
	m.Name = "VoidCore"
	m.Parent = map
	local pos = PathUtil.Points[#PathUtil.Points]
	local c = V(pos.X, GY, pos.Z)

	part(m, { Name = "Plinth1", Shape = Enum.PartType.Cylinder, Size = V(1.4, 30, 30), CFrame = CF(c + V(0, 0.5, 0)) * ANG(0, 0, rad(90)), Color = C.Stone2, Material = Enum.Material.Slate })
	part(m, { Name = "Plinth2", Shape = Enum.PartType.Cylinder, Size = V(1.4, 22, 22), CFrame = CF(c + V(0, 1.7, 0)) * ANG(0, 0, rad(90)), Color = C.Stone, Material = Enum.Material.Slate })
	local glowRing = part(m, { Name = "GlowRing", Shape = Enum.PartType.Cylinder, Size = V(0.2, 23, 23), CFrame = CF(c + V(0, 1.15, 0)) * ANG(0, 0, rad(90)), Color = C.Neon, Material = Enum.Material.Neon, CanCollide = false })

	-- колонны вокруг (одна сломана)
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2
		local p = c + V(math.cos(a) * 12, 0, math.sin(a) * 12)
		local h = (i == 2) and 5 or 11 + rng:NextNumber(-1, 1)
		part(m, { Name = "Pillar", Size = V(2.4, h, 2.4), CFrame = CF(p + V(0, 2.4 + h / 2, 0)) * ANG(0, a, rad(i == 4 and 4 or 0)), Color = C.Stone2, Material = Enum.Material.Slate })
		if i ~= 2 then
			local cap = part(m, { Name = "PillarGem", Size = V(1.2, 1.8, 1.2), CFrame = CF(p + V(0, 2.4 + h + 1.2, 0)) * ANG(0, rad(45), rad(45)), Color = C.Neon, Material = Enum.Material.Neon, CanCollide = false })
			cap:SetAttribute("Spin", 1.2)
			cap:SetAttribute("SpinAxis", "Y")
		end
	end

	-- главный кристалл
	local crystal = part(m, {
		Name = "CoreCrystal",
		Size = V(6, 6, 6),
		CFrame = CF(c + V(0, 13, 0)) * ANG(rad(45), 0, rad(45)),
		Color = Color3.fromRGB(190, 90, 255),
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
	crystal:SetAttribute("Spin", 0.8)
	crystal:SetAttribute("SpinAxis", "Y")
	crystal:SetAttribute("BobAmp", 1.2)
	local shell = part(m, {
		Name = "CoreShell",
		Size = V(9, 9, 9),
		CFrame = crystal.CFrame,
		Color = Color3.fromRGB(120, 60, 200),
		Material = Enum.Material.Glass,
		Transparency = 0.7,
		CanCollide = false,
	})
	shell:SetAttribute("Spin", -0.5)
	shell:SetAttribute("SpinAxis", "Y")
	shell:SetAttribute("BobAmp", 1.2)
	light(crystal, Color3.fromRGB(190, 90, 255), 50, 5)
	emitter(crystal, C.NeonSoft, { Rate = 25, Size = 0.7, SpeedMin = 2, SpeedMax = 5 })

	-- орбитальные кольца
	for k = 1, 2 do
		local ring = Instance.new("Model")
		ring.Name = "OrbitRing"
		ring.Parent = m
		local rr = 7 + k * 1.8
		local tilt = ANG(rad(k == 1 and 20 or -25), 0, rad(k == 1 and 10 or -12))
		for i = 0, 15 do
			local a = i / 16 * math.pi * 2
			part(ring, {
				Name = "Seg",
				Size = V(0.4, 0.4, 2.6),
				CFrame = CF(c + V(0, 13, 0)) * tilt * CF(math.cos(a) * rr, 0, math.sin(a) * rr) * ANG(0, -a, 0),
				Color = (k == 1) and C.Neon or C.NeonPink,
				Material = Enum.Material.Neon,
				CanCollide = false,
			})
		end
		ring:SetAttribute("Spin", k == 1 and 0.9 or -0.7)
		ring:SetAttribute("SpinAxis", "Y")
		ring.WorldPivot = CF(c + V(0, 13, 0)) * tilt
	end
	m:SetAttribute("CoreCenter", c + V(0, 13, 0))
	return m
end

------------------------------------------------------------------------
-- ДЕКОР
------------------------------------------------------------------------
local function freeSpot(rng, minPathDist, taken, minSep)
	local size = Config.Map.IslandSize
	for _ = 1, 60 do
		local p = V(rng:NextNumber(-size.X / 2 + 6, size.X / 2 - 6), GY, rng:NextNumber(-size.Y / 2 + 6, size.Y / 2 - 6))
		local ok = PathUtil.DistanceToPath(p) > minPathDist
			and PathUtil.FlatDistance(p, PathUtil.Points[1]) > 22
			and PathUtil.FlatDistance(p, PathUtil.Points[#PathUtil.Points]) > 22
			and p.Magnitude > 14
		if ok then
			for _, t in ipairs(taken) do
				if PathUtil.FlatDistance(p, t) < minSep then
					ok = false
					break
				end
			end
		end
		if ok then
			taken[#taken + 1] = p
			return p
		end
	end
	return nil
end

local function crystalCluster(parent, rng, p, scale)
	local m = Instance.new("Model")
	m.Name = "CrystalCluster"
	m.Parent = parent
	local colors = { C.Neon, C.NeonSoft, C.NeonPink }
	local count = rng:NextInteger(3, 5)
	local main
	for i = 1, count do
		local h = rng:NextNumber(2.5, 6) * scale * (i == 1 and 1.4 or 1)
		local w = h * rng:NextNumber(0.25, 0.4)
		local off = V(rng:NextNumber(-1.6, 1.6), 0, rng:NextNumber(-1.6, 1.6)) * scale
		local cr = part(m, {
			Name = "Crystal",
			Size = V(w, h, w),
			CFrame = CF(p + off + V(0, h * 0.4, 0)) * ANG(rad(rng:NextNumber(-25, 25)), rad(rng:NextNumber(0, 90)), rad(rng:NextNumber(-25, 25))),
			Color = colors[rng:NextInteger(1, (i == 1) and 1 or 3)],
			Material = Enum.Material.Neon,
		})
		if i == 1 then
			main = cr
		end
	end
	part(m, { Name = "Rock", Size = V(3.5, 1.2, 3) * scale, CFrame = CF(p + V(0, 0.4, 0)) * ANG(0, rad(rng:NextNumber(0, 90)), 0), Color = C.Rock2, Material = Enum.Material.Slate })
	light(main, C.Neon, 16 * scale, 1.6)
	return m
end

local function darkTree(parent, rng, p)
	local m = Instance.new("Model")
	m.Name = "DarkTree"
	m.Parent = parent
	local h = rng:NextNumber(9, 14)
	local lean = rad(rng:NextNumber(-8, 8))
	local trunkCF = CF(p + V(0, h / 2, 0)) * ANG(lean, rad(rng:NextNumber(0, 180)), lean * 0.5)
	part(m, { Name = "Trunk", Size = V(1.6, h, 1.6), CFrame = trunkCF, Color = C.Bark, Material = Enum.Material.Wood })
	part(m, { Name = "Root", Size = V(3.2, 1, 3.2), CFrame = CF(p + V(0, 0.4, 0)) * ANG(0, rad(rng:NextNumber(0, 90)), 0), Color = C.Bark, Material = Enum.Material.Wood })
	-- кривые ветки
	local topCF = trunkCF * CF(0, h / 2, 0)
	for i = 1, 3 do
		local a = rad(i * 120 + rng:NextNumber(-20, 20))
		local len = rng:NextNumber(3, 5)
		local branch = topCF * ANG(0, a, 0) * CF(0, -1.2 * i * 0.5, 0) * ANG(rad(55), 0, 0) * CF(0, len / 2, 0)
		part(m, { Name = "Branch", Size = V(0.7, len, 0.7), CFrame = branch, Color = C.Bark, Material = Enum.Material.Wood })
		local leaves = part(m, {
			Name = "Leaves",
			Size = V(rng:NextNumber(3.5, 5.5), rng:NextNumber(2.5, 3.5), rng:NextNumber(3.5, 5.5)),
			CFrame = branch * CF(0, len / 2 + 0.6, 0) * ANG(rad(rng:NextNumber(-15, 15)), rad(rng:NextNumber(0, 90)), 0),
			Color = (i % 2 == 0) and C.Leaf or C.Leaf2,
			Material = Enum.Material.Grass,
		})
		Instance.new("SpecialMesh", leaves).MeshType = Enum.MeshType.Sphere -- округлая листва
	end
	local crown = part(m, {
		Name = "Crown",
		Size = V(5.5, 4, 5.5),
		CFrame = topCF * CF(0, 1.4, 0) * ANG(0, rad(rng:NextNumber(0, 90)), rad(rng:NextNumber(-8, 8))),
		Color = C.Leaf,
		Material = Enum.Material.Grass,
	})
	Instance.new("SpecialMesh", crown).MeshType = Enum.MeshType.Sphere
	if rng:NextNumber() < 0.5 then
		local fruit = part(m, { Name = "Glow", Shape = Enum.PartType.Ball, Size = V(0.8, 0.8, 0.8), CFrame = topCF * CF(1.5, 0, -1.8), Color = C.NeonPink, Material = Enum.Material.Neon, CanCollide = false })
		light(fruit, C.NeonPink, 8, 1)
	end
	return m
end

local function ruin(parent, rng, p)
	local m = Instance.new("Model")
	m.Name = "Ruins"
	m.Parent = parent
	local rot = ANG(0, rad(rng:NextNumber(0, 180)), 0)
	local base = CF(p) * rot
	-- обломок стены с проёмом
	local cols = rng:NextInteger(3, 5)
	for x = 1, cols do
		local h = rng:NextInteger(1, 4)
		for y = 1, h do
			if not (x == 2 and y <= 2) then
				part(m, {
					Name = "Brick",
					Size = V(2.8, 1.6, 1.6),
					CFrame = base * CF((x - cols / 2) * 2.9, 0.8 + (y - 1) * 1.65, 0) * ANG(0, rad(rng:NextNumber(-4, 4)), 0),
					Color = (x + y) % 2 == 0 and C.Stone or C.Stone2,
					Material = Enum.Material.Slate,
				})
			end
		end
	end
	-- арка над проёмом
	part(m, { Name = "Lintel", Size = V(6.2, 1.2, 1.8), CFrame = base * CF((2 - cols / 2) * 2.9, 4.0, 0) * ANG(0, 0, rad(rng:NextNumber(-6, 6))), Color = C.Stone, Material = Enum.Material.Slate })
	-- разбросанные камни
	for i = 1, 4 do
		local s = rng:NextNumber(0.8, 1.8)
		part(m, {
			Name = "Rubble",
			Size = V(s * 1.6, s, s * 1.2),
			CFrame = base * CF(rng:NextNumber(-6, 6), s / 2, rng:NextNumber(1.5, 4)) * ANG(rad(rng:NextNumber(-20, 20)), rad(rng:NextNumber(0, 90)), rad(rng:NextNumber(-20, 20))),
			Color = C.Stone2,
			Material = Enum.Material.Slate,
		})
	end
	local rune = part(m, { Name = "Rune", Size = V(1, 1, 0.2), CFrame = base * CF((cols - cols / 2) * 2.9, 2.2, -0.85), Color = C.Neon, Material = Enum.Material.Neon, CanCollide = false })
	light(rune, C.Neon, 8, 1)
	return m
end

local function brokenColumn(parent, rng, p)
	local m = Instance.new("Model")
	m.Name = "BrokenColumn"
	m.Parent = parent
	local h = rng:NextNumber(4, 12)
	part(m, { Name = "Base", Size = V(4, 1, 4), CFrame = CF(p + V(0, 0.5, 0)), Color = C.Stone2, Material = Enum.Material.Slate })
	part(m, {
		Name = "Shaft",
		Shape = Enum.PartType.Cylinder,
		Size = V(h, 2.6, 2.6),
		CFrame = CF(p + V(0, 1 + h / 2, 0)) * ANG(0, 0, rad(90)) * ANG(rad(rng:NextNumber(-3, 3)), 0, 0),
		Color = C.Stone,
		Material = Enum.Material.Slate,
	})
	part(m, { Name = "Break", Size = V(2.4, 0.9, 2.4), CFrame = CF(p + V(0.3, 1 + h + 0.2, 0)) * ANG(rad(14), rad(30), rad(-10)), Color = C.Stone2, Material = Enum.Material.Slate })
	-- упавший кусок колонны
	local len = rng:NextNumber(3, 6)
	local a = rad(rng:NextNumber(0, 360))
	part(m, {
		Name = "FallenPiece",
		Shape = Enum.PartType.Cylinder,
		Size = V(len, 2.4, 2.4),
		CFrame = CF(p + V(math.cos(a) * 4, 1.2, math.sin(a) * 4)) * ANG(0, a, 0),
		Color = C.Stone2,
		Material = Enum.Material.Slate,
	})
	return m
end

local function floatingIsland(parent, rng, p, s)
	local m = Instance.new("Model")
	m.Name = "FloatingIsland"
	m.Parent = parent
	part(m, { Name = "Top", Size = V(14, 3, 12) * s, CFrame = CF(p) * ANG(0, rad(rng:NextNumber(0, 90)), 0), Color = C.Ground2, Material = Enum.Material.Slate })
	part(m, { Name = "Mid", Size = V(10, 5, 8) * s, CFrame = CF(p + V(0, -3.5 * s, 0)) * ANG(0, rad(rng:NextNumber(0, 90)), 0), Color = C.Rock, Material = Enum.Material.Slate })
	part(m, { Name = "Bottom", Size = V(5, 6, 4) * s, CFrame = CF(p + V(0, -8 * s, 0)) * ANG(rad(10), rad(rng:NextNumber(0, 90)), 0), Color = C.Rock2, Material = Enum.Material.Slate })
	crystalCluster(m, rng, p + V(0, 1.5 * s, 0), s)
	m:SetAttribute("BobAmp", rng:NextNumber(1.2, 2.5))
	m:SetAttribute("BobSpeed", rng:NextNumber(0.3, 0.6))
	m.WorldPivot = CF(p)
	return m
end

local function buildDecor(map, rng)
	local decor = Instance.new("Folder")
	decor.Name = "Decor"
	decor.Parent = map
	local taken = { V(10, GY, 10) }

	for _ = 1, 10 do
		local p = freeSpot(rng, 11, taken, 14)
		if p then
			crystalCluster(decor, rng, p, rng:NextNumber(0.9, 1.6))
		end
	end
	for _ = 1, 14 do
		local p = freeSpot(rng, 12, taken, 12)
		if p then
			darkTree(decor, rng, p)
		end
	end
	for _ = 1, 4 do
		local p = freeSpot(rng, 14, taken, 18)
		if p then
			ruin(decor, rng, p)
		end
	end
	for _ = 1, 6 do
		local p = freeSpot(rng, 11, taken, 12)
		if p then
			brokenColumn(decor, rng, p)
		end
	end

	-- парящие островки вокруг
	local sky = Instance.new("Folder")
	sky.Name = "Sky"
	sky.Parent = map
	local spots = {
		V(-170, GY + 25, -60), V(-150, GY + 40, 90), V(10, GY + 35, -150),
		V(170, GY + 20, 40), V(140, GY + 45, -120), V(-40, GY + 50, 150), V(90, GY + 30, 150),
	}
	for i, p in ipairs(spots) do
		floatingIsland(sky, rng, p, (i % 3 == 0) and 1.5 or 1)
	end
	return decor
end

------------------------------------------------------------------------
-- ЛОББИ
------------------------------------------------------------------------
local function cylinderY(parent, name, radius, height, center, color, material, props)
	local p = part(parent, {
		Name = name,
		Shape = Enum.PartType.Cylinder,
		Size = V(height, radius * 2, radius * 2),
		CFrame = CF(center) * ANG(0, 0, rad(90)),
		Color = color,
		Material = material or Enum.Material.Slate,
		CanCollide = props and props.CanCollide,
		Transparency = props and props.Transparency,
	})
	return p
end

local function billboard(parent, pos, title, subtitle, color, size)
	local anchor = part(parent, { Name = "Label", Size = V(1, 1, 1), CFrame = CF(pos), Transparency = 1, CanCollide = false })
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.new(size or 14, 0, (size or 14) * 0.4, 0)
	gui.LightInfluence = 0
	gui.MaxDistance = 250
	gui.Parent = anchor
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, subtitle and 0.65 or 1)
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.Text = title
	t.TextColor3 = color
	t.TextStrokeTransparency = 0
	t.TextStrokeColor3 = Color3.fromRGB(15, 0, 25)
	t.Parent = gui
	if subtitle then
		local st = t:Clone()
		st.Position = UDim2.fromScale(0, 0.65)
		st.Size = UDim2.fromScale(1, 0.35)
		st.Font = Enum.Font.GothamBold
		st.Text = subtitle
		st.TextColor3 = Color3.fromRGB(235, 225, 255)
		st.Parent = gui
	end
	return anchor
end

local function statue(parent, unitId, pos, lookAt, pedestalH)
	local ok, UnitModels = pcall(require, Shared:WaitForChild("UnitModels"))
	if not ok then
		return
	end
	pedestalH = pedestalH or 3
	part(parent, { Name = "Pedestal", Size = V(5, pedestalH, 5), CFrame = CF(pos + V(0, pedestalH / 2, 0)), Color = C.Stone2, Material = Enum.Material.Slate })
	part(parent, { Name = "PedestalTop", Size = V(5.6, 0.5, 5.6), CFrame = CF(pos + V(0, pedestalH + 0.25, 0)), Color = C.Stone, Material = Enum.Material.Slate })
	part(parent, { Name = "PedestalRune", Size = V(5.7, 0.25, 5.7), CFrame = CF(pos + V(0, pedestalH - 0.6, 0)), Color = C.Neon, Material = Enum.Material.Neon, CanCollide = false })
	local rig = UnitModels.Build(unitId, 5)
	local model = rig.Model
	model.Name = "Statue_" .. unitId
	local base = pos + V(0, pedestalH + 0.5 + rig.HipHeight, 0)
	model:PivotTo(CFrame.lookAt(base, V(lookAt.X, base.Y, lookAt.Z)))
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
		end
	end
	model.Parent = parent
	return model
end

local function lobbyPortal(parent, center, facing)
	local R = 9
	local base = CFrame.lookAt(center, center + facing)
	local rng = Random.new(7)
	for i = 0, 15 do
		local a = i / 16 * math.pi * 2
		local off = V(math.cos(a) * R, math.sin(a) * R, 0)
		part(parent, {
			Name = "PortalStone",
			Size = V(3.4, 3, 2.6),
			CFrame = base * CF(off) * ANG(0, 0, a + rad(rng:NextNumber(-3, 3))),
			Color = (i % 2 == 0) and C.Stone or C.Stone2,
			Material = Enum.Material.Slate,
		})
		if i % 4 == 0 then
			part(parent, { Name = "Rune", Size = V(0.6, 1.3, 0.3), CFrame = base * CF(off) * ANG(0, 0, a) * CF(0, 0, -1.35), Color = C.Neon, Material = Enum.Material.Neon, CanCollide = false })
		end
	end
	local disc = part(parent, {
		Name = "PortalDisc",
		Shape = Enum.PartType.Cylinder,
		Size = V(0.4, R * 2 - 2.4, R * 2 - 2.4),
		CFrame = base * ANG(0, rad(90), 0),
		Color = Color3.fromRGB(120, 40, 210),
		Material = Enum.Material.Neon,
		Transparency = 0.2,
		CanCollide = false,
	})
	for i = 0, 2 do
		local sw = part(parent, { Name = "Swirl", Size = V(0.6, R * 1.6, 0.7), CFrame = base * ANG(0, 0, rad(i * 60)) * CF(0, 0, -0.4), Color = C.NeonSoft, Material = Enum.Material.Neon, Transparency = 0.35, CanCollide = false })
		sw:SetAttribute("Spin", -1.4 - i * 0.3)
		sw:SetAttribute("SpinAxis", "Z")
	end
	light(disc, C.Neon, 40, 4)
	emitter(disc, C.Neon, { Rate = 30, Size = 0.7, SpeedMin = 2, SpeedMax = 5 })
end

-- Приглушённый неон по всей карте: светящиеся детали темнее, подсветка слабее
local function calm(root)
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("BasePart") and d.Material == Enum.Material.Neon then
			d.Color = d.Color:Lerp(Color3.fromRGB(14, 10, 22), 0.3)
		elseif d:IsA("PointLight") then
			d.Brightness = d.Brightness * 0.65
		end
	end
end

-- Круг-зона: встал — открылось меню (или сработал портал)
local function zoneCircle(parent, key, z, zc, subtitle, padColor)
	local zm = Instance.new("Model")
	zm.Name = key
	zm.Parent = parent
	cylinderY(zm, "PadBase", z.Radius + 1.2, 0.6, zc + V(0, 0.3, 0), C.Stone2)
	cylinderY(zm, "PadEdge", z.Radius + 0.5, 0.65, zc + V(0, 0.33, 0), z.Color, Enum.Material.Neon)
	local pad = cylinderY(zm, "Pad", z.Radius, 0.7, zc + V(0, 0.36, 0), padColor or Color3.fromRGB(25, 15, 40), Enum.Material.Glass, { Transparency = 0.15 })
	local beam = cylinderY(zm, "LightBeam", z.Radius * 0.9, 26, zc + V(0, 13, 0), z.Color, Enum.Material.Neon, { CanCollide = false, Transparency = 0.88 })
	beam.CastShadow = false
	emitter(pad, z.Color, { Rate = 14, Size = 0.5, SpeedMin = 2, SpeedMax = 4, Spread = 10, Dir = Enum.NormalId.Right, LifeMin = 1.5, LifeMax = 2.5 })
	light(pad, z.Color, 18, 2)
	billboard(zm, zc + V(0, 8.5, 0), z.Title, subtitle or (z.Teleport and "войди в портал" or "встань в круг"), z.Color, 12)
	zm:SetAttribute("Zone", key)
	return zm
end

function MapBuilder.BuildLobby()
	local existing = workspace:FindFirstChild("VoidTDLobby")
	if existing then
		return existing
	end
	local L = Config.Lobby
	local c = L.Center
	local R = L.Radius
	local rng = Random.new(4242)
	local m = Instance.new("Model")
	m.Name = "VoidTDLobby"

	-- платформа
	local top = cylinderY(m, "Floor", R, 4, c - V(0, 2, 0), C.Ground, Enum.Material.Slate)
	top:SetAttribute("Placeable", false)
	cylinderY(m, "FloorInlay", 30, 0.2, c + V(0, 0.02, 0), C.Ground2, Enum.Material.Slate, { CanCollide = false })
	cylinderY(m, "InnerRing", 30.6, 0.12, c + V(0, 0.01, 0), C.Neon, Enum.Material.Neon, { CanCollide = false, Transparency = 0.3 })
	cylinderY(m, "MidRing", 55.6, 0.1, c + V(0, 0.008, 0), C.Neon, Enum.Material.Neon, { CanCollide = false, Transparency = 0.7 })
	cylinderY(m, "MidFloor", 55, 0.11, c + V(0, 0.009, 0), C.Ground, Enum.Material.Slate, { CanCollide = false })
	cylinderY(m, "OuterRing", R - 4, 0.1, c + V(0, 0.005, 0), C.Neon, Enum.Material.Neon, { CanCollide = false, Transparency = 0.6 })
	cylinderY(m, "OuterFloor", R - 4.4, 0.12, c + V(0, 0.01, 0), C.Ground, Enum.Material.Slate, { CanCollide = false })
	-- низ острова
	for i, l in ipairs({ { 0.9, 10, -8 }, { 0.68, 14, -19 }, { 0.45, 16, -33 }, { 0.22, 16, -48 } }) do
		cylinderY(m, "Under" .. i, R * l[1], l[2], c + V(rng:NextNumber(-3, 3), l[3], rng:NextNumber(-3, 3)), (i % 2 == 0) and C.Rock or C.Rock2)
	end
	local root = part(m, { Name = "CrystalRoot", Size = V(7, 16, 7), CFrame = CF(c + V(0, -62, 0)) * ANG(rad(6), rad(45), 0), Color = C.Neon, Material = Enum.Material.Neon })
	light(root, C.Neon, 40, 3)
	-- край: камни и колонны с неоном
	for i = 0, 35 do
		local a = i / 36 * math.pi * 2
		local p = c + V(math.cos(a) * (R - 1), 0, math.sin(a) * (R - 1))
		local s = rng:NextNumber(4, 7)
		part(m, { Name = "EdgeRock", Size = V(s, rng:NextNumber(1, 2.5), s), CFrame = CF(p) * ANG(0, rad(rng:NextNumber(0, 90)), 0), Color = C.Rock2, Material = Enum.Material.Slate })
		if i % 3 == 0 then
			local h = rng:NextNumber(6, 10)
			local pil = c + V(math.cos(a) * (R - 3), 0, math.sin(a) * (R - 3))
			part(m, { Name = "Pillar", Size = V(2.2, h, 2.2), CFrame = CF(pil + V(0, h / 2, 0)) * ANG(0, a, 0), Color = C.Stone2, Material = Enum.Material.Slate })
			local gem = part(m, { Name = "PillarGem", Size = V(1, 1.6, 1), CFrame = CF(pil + V(0, h + 1.4, 0)) * ANG(0, rad(45), rad(45)), Color = C.Neon, Material = Enum.Material.Neon, CanCollide = false })
			gem:SetAttribute("Spin", 1.5)
			gem:SetAttribute("SpinAxis", "Y")
			light(gem, C.Neon, 14, 1.2)
		end
	end

	-- зоны-круги
	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = m
	for key, z in pairs(L.Zones) do
		zoneCircle(zonesFolder, key, z, c + z.Offset)
	end

	-- КЕЙСЫ: витрины с вращающимися 3D-кейсами за каждым кругом
	local okCM, CaseModels = pcall(require, Shared:WaitForChild("CaseModels"))
	for _, z in pairs(L.Zones) do
		if z.Case then
			local zc = c + z.Offset
			local out = V(z.Offset.X, 0, z.Offset.Z).Unit
			local sp = zc + out * 13
			part(m, { Name = "CaseStand", Shape = Enum.PartType.Cylinder, Size = V(2.5, 9, 9), CFrame = CF(sp + V(0, 1.25, 0)) * ANG(0, 0, rad(90)), Color = C.Stone2, Material = Enum.Material.Slate })
			part(m, { Name = "CaseStandRing", Shape = Enum.PartType.Cylinder, Size = V(0.3, 9.4, 9.4), CFrame = CF(sp + V(0, 2.4, 0)) * ANG(0, 0, rad(90)), Color = z.Color, Material = Enum.Material.Neon, CanCollide = false })
			if okCM then
				local cm = CaseModels.Build(z.Case).Model
				cm:ScaleTo(1.6)
				cm:PivotTo(CF(sp + V(0, 2.6, 0)) * CFrame.lookAt(Vector3.zero, -out).Rotation)
				cm:SetAttribute("Spin", 0.5)
				cm:SetAttribute("SpinAxis", "Y")
				cm.Parent = m
			end
			local glow = part(m, { Name = "CaseGlow", Size = V(0.5, 0.5, 0.5), CFrame = CF(sp + V(0, 6, 0)), Transparency = 1, CanCollide = false })
			light(glow, z.Color, 22, 2)
			emitter(glow, z.Color, { Rate = 8, Size = 0.4, SpeedMin = 1, SpeedMax = 2 })
			local case = Config.Cases[z.Case]
			billboard(m, sp + V(0, 13, 0), case.Name, "💎" .. case.Cost1 .. " / x10 💎" .. case.Cost10, z.Color, 14)
		end
	end

	-- ЮНИТЫ: статуи Common-героев
	local uz = c + L.Zones.Units.Offset
	statue(m, "VoidSoldier", uz + V(13, 0, -9), uz, 2.5)
	statue(m, "ShadowArcher", uz + V(15, 0, 0), uz, 2.5)
	statue(m, "LostMage", uz + V(13, 0, 9), uz, 2.5)

	-- ИГРАТЬ: портал в бой и мифические стражи
	local pz = c + L.Zones.Play.Offset
	lobbyPortal(m, pz + V(0, 10.5, -11), V(0, 0, 1))
	part(m, { Name = "PortalBase", Size = V(24, 1, 8), CFrame = CF(pz + V(0, 0.5, -11)), Color = C.Stone2, Material = Enum.Material.Slate })
	statue(m, "VoidEmperor", pz + V(-17, 0, -6), c, 4)
	statue(m, "AbyssOverlord", pz + V(17, 0, -6), c, 4)
	statue(m, "RiftMonarch", pz + V(-32, 0, 2), c, 4)
	statue(m, "LunarSeraph", pz + V(32, 0, 2), c, 4)
	-- герои у точки появления
	statue(m, "FallenAngel", c + V(-24, 0, 50), c, 3)
	statue(m, "EclipseGuardian", c + V(24, 0, 50), c, 3)
	statue(m, "Starbreaker", c + V(-42, 0, 42), c, 3)
	statue(m, "BloodfangWarlord", c + V(42, 0, 42), c, 3)
	-- секретные юниты в центре
	statue(m, "RealityDestroyer", c + V(-8, 0, 0), c + V(0, 0, 60), 5)
	statue(m, "CrimsonEclipse", c + V(8, 0, 0), c + V(0, 0, 60), 5)
	billboard(m, c + V(0, 17, 0), "SECRET", "шанс 0.1% в новых кейсах", Color3.fromRGB(255, 40, 60), 12)

	-- вывеска
	local sign = part(m, { Name = "Sign", Size = V(30, 8, 1), CFrame = CF(pz + V(0, 27, -12)) * ANG(0, math.pi, 0), Color = C.Black, Material = Enum.Material.Slate })
	part(m, { Name = "SignFrame", Size = V(31, 9, 0.6), CFrame = CF(pz + V(0, 27, -12.4)), Color = C.Neon, Material = Enum.Material.Neon, CanCollide = false })
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Front
	sg.LightInfluence = 0
	sg.PixelsPerStud = 30
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.Parent = sign
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.fromScale(1, 0.7)
	title.Font = Enum.Font.FredokaOne
	title.TextScaled = true
	title.Text = "VOID TD"
	title.TextColor3 = Color3.fromRGB(200, 120, 255)
	title.TextStrokeTransparency = 0
	title.Parent = sg
	local sub = title:Clone()
	sub.Position = UDim2.fromScale(0, 0.68)
	sub.Size = UDim2.fromScale(1, 0.28)
	sub.Font = Enum.Font.GothamBold
	sub.Text = "THE FORGOTTEN REALM"
	sub.TextColor3 = Color3.fromRGB(235, 225, 255)
	sub.Parent = sg

	-- декор
	local taken = {}
	for key, z in pairs(L.Zones) do
		taken[#taken + 1] = c + z.Offset
		if z.Case then
			taken[#taken + 1] = c + z.Offset + V(z.Offset.X, 0, z.Offset.Z).Unit * 13
		end
	end
	for _, off in ipairs({ V(-24, 0, 50), V(24, 0, 50), V(-42, 0, 42), V(42, 0, 42), V(0, 0, 0), V(77, 0, 8), V(-32, 0, -60), V(32, 0, -60), V(0, 0, -73) }) do
		taken[#taken + 1] = c + off
	end
	for i = 1, 24 do
		local a = rng:NextNumber(0, math.pi * 2)
		local d = rng:NextNumber(36, R - 8)
		local p = c + V(math.cos(a) * d, 0, math.sin(a) * d)
		local free = true
		for _, t in ipairs(taken) do
			if (V(p.X, 0, p.Z) - V(t.X, 0, t.Z)).Magnitude < 16 then
				free = false
			end
		end
		if free and (p - L.Spawn).Magnitude > 12 then
			taken[#taken + 1] = p
			if i % 2 == 0 then
				darkTree(m, rng, p)
			else
				crystalCluster(m, rng, p, rng:NextNumber(0.9, 1.4))
			end
		end
	end

	-- точка появления
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "LobbySpawn"
	spawn.Anchored = true
	spawn.Size = V(10, 1, 10)
	spawn.CFrame = CF(L.Spawn + V(0, 0.5, 0))
	spawn.Color = Color3.fromRGB(70, 40, 110)
	spawn.Material = Enum.Material.Slate
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Parent = m
	cylinderY(m, "SpawnGlow", 4.6, 0.08, L.Spawn + V(0, 1.03, 0), C.Neon, Enum.Material.Neon, { CanCollide = false, Transparency = 0.5 })

	m.WorldPivot = CF(c)
	calm(m)
	m.Parent = workspace
	return m
end

-- Хелперы для HalloweenWorld
MapBuilder.H = {
	part = part, light = light, emitter = emitter, cylinderY = cylinderY, billboard = billboard,
	statue = statue, calm = calm, zoneCircle = zoneCircle, lobbyPortal = lobbyPortal, C = C,
}

-- Хэллоуин-остров, портал в лобби и карта Haunted Hollow
function MapBuilder.BuildHalloween()
	local HalloweenWorld = require(script.Parent:WaitForChild("HalloweenWorld"))
	return HalloweenWorld.Build(MapBuilder.H)
end

------------------------------------------------------------------------
function MapBuilder.Build()
	local existing = workspace:FindFirstChild("VoidTDMap")
	if existing then
		MapBuilder.BuildLobby()
		setupLighting()
		return existing
	end
	local rng = Random.new(1337)
	local map = Instance.new("Model")
	map.Name = "VoidTDMap"

	buildIsland(map, rng)
	buildPath(map, rng)
	buildPortal(map, rng)
	buildCore(map, rng)
	buildDecor(map, rng)

	-- площадка, куда телепортирует из лобби (не SpawnLocation: появляются все в лобби)
	local bs = Config.BattleSpawn
	part(map, { Name = "BattlePad", Size = V(8, 1, 8), CFrame = CF(bs.X, GY + 0.5, bs.Z), Color = Color3.fromRGB(70, 40, 110), Material = Enum.Material.Slate })
	part(map, { Name = "BattlePadGlow", Size = V(7, 0.05, 7), CFrame = CF(bs.X, GY + 1.03, bs.Z), Color = C.Neon, Material = Enum.Material.Neon, Transparency = 0.6, CanCollide = false })

	calm(map)
	map.Parent = workspace
	MapBuilder.BuildLobby()
	setupLighting()
	return map
end

return MapBuilder
]======] }
FILES[#FILES + 1] = { "ServerScriptService", { "VoidTDServer", "DataService" }, "ModuleScript", [======[
--!nocheck
-- VOID TD :: DataService
-- Профиль игрока: гемы, инвентарь юнитов, экипировка. DataStore с безопасным фолбэком для Studio.

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("VoidTD"):WaitForChild("Config"))

local DataService = {}
DataService.Profiles = {}

local store
local storeOk = pcall(function()
	store = DataStoreService:GetDataStore(Config.Settings.DataStoreName)
end)
if not storeOk then
	store = nil
end

local function deepCopy(t)
	local c = {}
	for k, v in pairs(t) do
		c[k] = type(v) == "table" and deepCopy(v) or v
	end
	return c
end

local function defaultProfile()
	local s = Config.Settings
	local p = {
		Gems = s.StartGems,
		Inventory = {},
		Equipped = {},
		Stats = { Wins = 0, BestWave = 0, Summons = 0 },
		Settings = {},
		LastDaily = 0,
		Receipts = {},
		HalloweenCoins = 0,
		Runes = {},       -- RuneId -> количество
		RuneSlots = {},   -- UnitId -> RuneId (1 руна на юнита)
	}
	for i, id in ipairs(s.StarterUnits) do
		p.Inventory[id] = 1
		p.Equipped[i] = id
	end
	return p
end

local function sanitize(p)
	local d = defaultProfile()
	if type(p) ~= "table" then
		return d
	end
	p.Gems = tonumber(p.Gems) or d.Gems
	p.Inventory = type(p.Inventory) == "table" and p.Inventory or d.Inventory
	p.Equipped = type(p.Equipped) == "table" and p.Equipped or d.Equipped
	p.Stats = type(p.Stats) == "table" and p.Stats or d.Stats
	p.Settings = type(p.Settings) == "table" and p.Settings or {}
	p.LastDaily = tonumber(p.LastDaily) or 0
	p.Receipts = type(p.Receipts) == "table" and p.Receipts or {}
	p.HalloweenCoins = math.max(0, math.floor(tonumber(p.HalloweenCoins) or 0))
	-- руны: только известные, слоты — только у своих юнитов и не больше, чем рун есть
	local runes = {}
	if type(p.Runes) == "table" then
		for id, n in pairs(p.Runes) do
			n = math.floor(tonumber(n) or 0)
			if Config.Runes[id] and n > 0 then
				runes[id] = n
			end
		end
	end
	p.Runes = runes
	local slots, used = {}, {}
	if type(p.RuneSlots) == "table" then
		for unitId, runeId in pairs(p.RuneSlots) do
			if Config.Units[unitId] and (p.Inventory[unitId] or 0) > 0 and runes[runeId] and (used[runeId] or 0) < runes[runeId] then
				slots[unitId] = runeId
				used[runeId] = (used[runeId] or 0) + 1
			end
		end
	end
	p.RuneSlots = slots
	-- убрать неизвестные юниты
	for id in pairs(p.Inventory) do
		if not Config.Units[id] then
			p.Inventory[id] = nil
		end
	end
	local eq = {}
	for i = 1, Config.Settings.EquipSlots do
		local id = p.Equipped[i] or p.Equipped[tostring(i)]
		if id and Config.Units[id] and (p.Inventory[id] or 0) > 0 then
			eq[i] = id
		end
	end
	p.Equipped = eq
	return p
end

function DataService.Load(player)
	local profile
	if store then
		local ok, result = pcall(function()
			return store:GetAsync("u_" .. player.UserId)
		end)
		if ok then
			profile = result
		else
			warn("[VOID TD] DataStore недоступен (в Studio включи API Services). Используются данные по умолчанию.")
		end
	end
	profile = sanitize(profile and deepCopy(profile) or nil)
	-- проверка в Studio: секретные юниты из настроек сразу в инвентаре
	if RunService:IsStudio() then
		for _, id in ipairs(Config.Settings.StudioGrantUnits or {}) do
			if Config.Units[id] and (profile.Inventory[id] or 0) == 0 then
				profile.Inventory[id] = 1
			end
		end
	end
	DataService.Profiles[player] = profile
	player:SetAttribute("Gems", profile.Gems)
	player:SetAttribute("HalloweenCoins", profile.HalloweenCoins)
	return profile
end

function DataService.Get(player)
	return DataService.Profiles[player]
end

local lastSave = {}
function DataService.Save(player, force)
	local profile = DataService.Profiles[player]
	if not profile or not store then
		return
	end
	local now = os.clock()
	if not force and lastSave[player] and now - lastSave[player] < 8 then
		return
	end
	lastSave[player] = now
	local data = deepCopy(profile)
	-- ключи экипировки -> строки для JSON
	local eq = {}
	for i, id in pairs(data.Equipped) do
		eq[tostring(i)] = id
	end
	data.Equipped = eq
	task.spawn(function()
		local ok, err = pcall(function()
			store:SetAsync("u_" .. player.UserId, data)
		end)
		if not ok and not RunService:IsStudio() then
			warn("[VOID TD] Ошибка сохранения: " .. tostring(err))
		end
	end)
end

function DataService.Release(player)
	DataService.Save(player, true)
	DataService.Profiles[player] = nil
	lastSave[player] = nil
end

function DataService.AddGems(player, amount)
	local p = DataService.Profiles[player]
	if not p then
		return
	end
	p.Gems = math.max(0, p.Gems + amount)
	player:SetAttribute("Gems", p.Gems)
end

-- Публичная версия профиля для клиента
function DataService.Snapshot(player)
	local p = DataService.Profiles[player]
	if not p then
		return nil
	end
	-- ключи экипировки строками: разреженные массивы плохо переживают RemoteEvent
	local eq = {}
	for i, id in pairs(p.Equipped) do
		eq[tostring(i)] = id
	end
	return {
		Gems = p.Gems,
		Inventory = deepCopy(p.Inventory),
		Equipped = eq,
		Stats = deepCopy(p.Stats),
		Settings = deepCopy(p.Settings or {}),
		DailyReadyAt = (tonumber(p.LastDaily) or 0) + Config.Settings.DailyCooldown,
		HalloweenCoins = p.HalloweenCoins or 0,
		Runes = deepCopy(p.Runes or {}),
		RuneSlots = deepCopy(p.RuneSlots or {}),
	}
end

function DataService.AddCurrency(player, currency, amount)
	local p = DataService.Profiles[player]
	if not p then
		return
	end
	if currency == "Gems" then
		DataService.AddGems(player, amount)
		return
	end
	p[currency] = math.max(0, (p[currency] or 0) + math.floor(amount))
	player:SetAttribute(currency, p[currency])
end

------------------------------------------------------------------------
-- РУНЫ: 1 руна на юнита, снимается и переносится на другого, работает только надетой
------------------------------------------------------------------------
function DataService.GetRune(player, unitId)
	local p = DataService.Profiles[player]
	return p and p.RuneSlots and p.RuneSlots[unitId] or nil
end

local function runesUsed(p, runeId, exceptUnit)
	local n = 0
	for unitId, r in pairs(p.RuneSlots) do
		if r == runeId and unitId ~= exceptUnit then
			n = n + 1
		end
	end
	return n
end

-- runeId = nil — снять руну с юнита
function DataService.EquipRune(player, unitId, runeId)
	local p = DataService.Profiles[player]
	if not p then
		return false, "Профиль не загружен"
	end
	if not Config.Units[unitId] or (p.Inventory[unitId] or 0) <= 0 then
		return false, "Юнита нет в инвентаре"
	end
	if runeId == nil then
		p.RuneSlots[unitId] = nil
		DataService.Save(player)
		return true
	end
	if not Config.Runes[runeId] then
		return false, "Неизвестная руна"
	end
	if runesUsed(p, runeId, unitId) >= (p.Runes[runeId] or 0) then
		return false, "Все такие руны уже надеты — сними руну с другого юнита"
	end
	p.RuneSlots[unitId] = runeId
	DataService.Save(player)
	return true
end

------------------------------------------------------------------------
-- КЕЙСЫ (SUMMON)
------------------------------------------------------------------------
local rng = Random.new()

local function unitsByRarity(case)
	local map = {}
	for _, id in ipairs(case.Units) do
		local r = Config.Units[id].Rarity
		map[r] = map[r] or {}
		table.insert(map[r], id)
	end
	return map
end

-- редкость есть в розыгрыше, если в ней есть юниты без отдельного шанса (UnitRates)
local function rollable(pool, name, unitRates)
	for _, id in ipairs(pool[name] or {}) do
		if not (unitRates and unitRates[id]) then
			return true
		end
	end
	return false
end

local function rollRarity(case, pool, unitRates)
	local total = 0
	for _, name in ipairs(Config.RarityOrder) do
		if rollable(pool, name, unitRates) then
			total = total + (case.Rates[name] or 0)
		end
	end
	local roll = rng:NextNumber() * total
	local acc = 0
	for _, name in ipairs(Config.RarityOrder) do
		if rollable(pool, name, unitRates) then
			acc = acc + (case.Rates[name] or 0)
			if roll <= acc then
				return name
			end
		end
	end
	return "Common"
end

function DataService.Summon(player, caseId, count)
	local p = DataService.Profiles[player]
	if not p then
		return false, "Профиль не загружен"
	end
	local case = Config.Cases[caseId]
	if not case then
		return false, "Неизвестный кейс"
	end
	if case.Enabled == false then
		return false, "Кейс пока недоступен"
	end
	local s = Config.Settings
	count = (count == 10) and 10 or 1
	if case.Single and count ~= 1 then
		return false, "Этот кейс открывается по одному"
	end
	local cost = (count == 10) and case.Cost10 or case.Cost1
	if not cost then
		return false, "Неверный запрос"
	end
	local currency = case.Currency or "Gems"
	if (p[currency] or 0) < cost then
		return false, currency == "Gems" and "Недостаточно кристаллов" or "Недостаточно Halloween Coins"
	end
	p[currency] = p[currency] - cost
	if currency == "Gems" then
		player:SetAttribute("Gems", p.Gems)
	end
	-- кейс с полным списком наград (юниты и руны): один бросок на открытие
	if case.Rewards then
		local total = 0
		for _, r in ipairs(case.Rewards) do
			total = total + r.Rate
		end
		local roll, acc, pick = rng:NextNumber() * total, 0, case.Rewards[#case.Rewards]
		for _, r in ipairs(case.Rewards) do
			acc = acc + r.Rate
			if roll < acc then
				pick = r
				break
			end
		end
		local result
		if pick.Rune then
			local isNew = (p.Runes[pick.Rune] or 0) == 0
			p.Runes[pick.Rune] = (p.Runes[pick.Rune] or 0) + 1
			result = { Rune = pick.Rune, New = isNew }
		else
			local id = pick.Unit
			local isNew = (p.Inventory[id] or 0) == 0
			p.Inventory[id] = (p.Inventory[id] or 0) + 1
			result = { Id = id, New = isNew }
			if isNew then
				for slot = 1, s.EquipSlots do
					if not p.Equipped[slot] then
						p.Equipped[slot] = id
						break
					end
				end
			end
		end
		if currency ~= "Gems" then
			player:SetAttribute(currency, p[currency])
		end
		p.Stats.Summons = (p.Stats.Summons or 0) + 1
		DataService.Save(player, true)
		return true, { result }
	end
	local pool = unitsByRarity(case)
	local results = {}
	local bestOrder = 0
	for i = 1, count do
		-- отдельный шанс конкретных юнитов (UnitRates, в процентах), иначе — по редкостям
		local fixed
		if case.UnitRates then
			local roll, acc = rng:NextNumber() * 100, 0
			for id, rate in pairs(case.UnitRates) do
				acc = acc + rate
				if roll < acc then
					fixed = id
					break
				end
			end
		end
		local rarity = fixed and Config.Units[fixed].Rarity or rollRarity(case, pool, case.UnitRates)
		-- гарантия: в x10 минимум один Rare+
		if count == 10 and i == 10 and bestOrder < 2 and not fixed and rollable(pool, "Rare", case.UnitRates) then
			rarity = "Rare"
		end
		bestOrder = math.max(bestOrder, Config.Rarities[rarity].Order)
		local id = fixed
		if not id then
			local list = {}
			for _, u in ipairs(pool[rarity]) do
				if not (case.UnitRates and case.UnitRates[u]) then
					list[#list + 1] = u
				end
			end
			id = list[rng:NextInteger(1, #list)]
		end
		local isNew = (p.Inventory[id] or 0) == 0
		p.Inventory[id] = (p.Inventory[id] or 0) + 1
		results[i] = { Id = id, New = isNew }
		if isNew then
			for slot = 1, s.EquipSlots do
				if not p.Equipped[slot] then
					p.Equipped[slot] = id
					break
				end
			end
		end
	end
	p.Stats.Summons = (p.Stats.Summons or 0) + count
	DataService.Save(player)
	return true, results
end

------------------------------------------------------------------------
-- МАГАЗИН
------------------------------------------------------------------------
function DataService.ClaimDaily(player)
	local p = DataService.Profiles[player]
	if not p then
		return false, "Профиль не загружен"
	end
	local now = os.time()
	local last = tonumber(p.LastDaily) or 0
	local left = (last + Config.Settings.DailyCooldown) - now
	if left > 0 then
		return false, string.format("Подарок будет через %d ч %d мин", left // 3600, (left % 3600) // 60)
	end
	p.LastDaily = now
	DataService.AddGems(player, Config.Settings.DailyGems)
	DataService.Save(player, true)
	return true, Config.Settings.DailyGems
end

-- Выдача кристаллов за покупку. receiptId защищает от повторной выдачи.
function DataService.GrantPurchase(player, gems, receiptId)
	local p = DataService.Profiles[player]
	if not p then
		return false
	end
	p.Receipts = p.Receipts or {}
	if receiptId and p.Receipts[receiptId] then
		return true
	end
	if receiptId then
		p.Receipts[receiptId] = true
	end
	DataService.AddGems(player, gems)
	DataService.Save(player, true)
	return true
end

function DataService.Equip(player, unitId, slot)
	local p = DataService.Profiles[player]
	if not p then
		return false, "Профиль не загружен"
	end
	slot = tonumber(slot)
	if not slot or slot < 1 or slot > Config.Settings.EquipSlots or slot ~= math.floor(slot) then
		return false, "Неверный слот"
	end
	if unitId == nil then
		p.Equipped[slot] = nil
		return true
	end
	if not Config.Units[unitId] or (p.Inventory[unitId] or 0) <= 0 then
		return false, "Юнита нет в инвентаре"
	end
	for i = 1, Config.Settings.EquipSlots do
		if p.Equipped[i] == unitId then
			p.Equipped[i] = nil
		end
	end
	p.Equipped[slot] = unitId
	DataService.Save(player)
	return true
end

function DataService.IsEquipped(player, unitId)
	local p = DataService.Profiles[player]
	if not p then
		return false
	end
	for i = 1, Config.Settings.EquipSlots do
		if p.Equipped[i] == unitId then
			return true
		end
	end
	return false
end

return DataService
]======] }
FILES[#FILES + 1] = { "ServerScriptService", { "VoidTDServer", "GameService" }, "ModuleScript", [======[
--!nocheck
-- VOID TD :: GameService
-- Вся игровая логика на сервере: враги, волны, ядро, юниты, урон.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("VoidTD")
local Config = require(Shared:WaitForChild("Config"))
local PathUtil = require(Shared:WaitForChild("PathUtil"))
local DataService = require(script.Parent:WaitForChild("DataService"))

local S = Config.Settings

local GameService = {}

local Remotes, State, UnitsFolder, Map
local MapModels = {}
local rng = Random.new()

local enemies = {}
local nextEnemyId = 0
local units = {}
local nextUnitId = 0
local zones = {}
local damageBuffer = {}
local removedBuffer = {}
local pendingSpawns = {}

-- Фазы: Idle (никто не играет) -> Prep (расстановка до 1-й волны) -> Wave <-> Intermission -> Victory/Defeat
local phase = "Idle"
local difficultyKey = "Medium"
local D = Config.Difficulties.Medium
local wave = 0
local coreHP = S.CoreMaxHP
local matchId = 0
local waveSpawning = false
local nextWaveAt = 0
local lastSync = 0
local lastAttrFlush = 0
-- режим матча: Void (обычный) или Halloween (карта Haunted Hollow, вход только из очереди на острове)
local matchMode = "Void"
local maxWave = S.MaxWave
local roster = {}       -- участники Хэллоуин-матча (UserId -> true)
local coinsPaid = {}    -- matchId -> true: награда за победу выдана (повторно не платится)
-- союзники (призывы): идут по дороге от базы к порталу
local allies = {}
local nextAllyId = 0
local allyRemoved = {}
local allyIndex = {}
for i, id in ipairs(Config.AllyOrder or {}) do
	allyIndex[id] = i
end
local echoAttack = false -- true, пока выполняется повтор атаки «Призрачной короны»

local function now()
	return workspace:GetServerTimeNow()
end

local function setState(key, value)
	State:SetAttribute(key, value)
end

local function notifyAll(payload)
	Remotes.Notify:FireAllClients(payload)
end

local function toast(player, text, kind)
	Remotes.Notify:FireClient(player, { Type = "Toast", Text = text, Kind = kind or "error" })
end
GameService.Toast = toast

------------------------------------------------------------------------
-- ДЕНЬГИ
------------------------------------------------------------------------
local function getMoney(player)
	return player:GetAttribute("Money") or 0
end

local function setMoney(player, amount)
	amount = math.max(0, math.floor(amount))
	player:SetAttribute("Money", amount)
	local ls = player:FindFirstChild("leaderstats")
	if ls and ls:FindFirstChild("Money") then
		ls.Money.Value = amount
	end
end

local function inMatch(player)
	return player:GetAttribute("InMatch") == true
end

local function matchPlayers()
	local list = {}
	for _, pl in ipairs(Players:GetPlayers()) do
		if inMatch(pl) then
			list[#list + 1] = pl
		end
	end
	return list
end

local function addMoneyAll(amount)
	for _, pl in ipairs(matchPlayers()) do
		setMoney(pl, getMoney(pl) + amount)
	end
end

local function addGemsAll(amount)
	amount = math.floor(amount * D.Gems + 0.5)
	for _, pl in ipairs(matchPlayers()) do
		DataService.AddGems(pl, amount)
	end
	return amount
end

------------------------------------------------------------------------
-- ТЕЛЕПОРТ ЛОББИ <-> КАРТА
------------------------------------------------------------------------
local function teleport(player, pos)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if root then
		local jitter = Vector3.new(rng:NextNumber(-3, 3), 3.5, rng:NextNumber(-3, 3))
		char:PivotTo(CFrame.new(pos + jitter))
	end
end

local function toBattle(player)
	local m = Config.Maps[matchMode] or Config.Map
	teleport(player, m.BattleSpawn or Config.BattleSpawn)
end

local function toLobby(player, island)
	player:SetAttribute("Island", island == true)
	teleport(player, island and Config.HalloweenIsland.Spawn or Config.Lobby.Spawn)
end
GameService.ToLobby = toLobby
GameService.Teleport = teleport

------------------------------------------------------------------------
-- ВРАГИ
------------------------------------------------------------------------
local function enemyPos(e)
	return (PathUtil.OffsetPositionAt(e.Dist, e.Lateral))
end

local function refreshBoss()
	local best
	for _, e in pairs(enemies) do
		if e.IsBoss and (not best or e.MaxHealth > best.MaxHealth) then
			best = e
		end
	end
	if best then
		setState("BossId", best.Id)
		setState("BossName", best.Def.Name)
		setState("BossMaxHP", best.MaxHealth)
	else
		setState("BossId", 0)
		setState("BossName", "")
	end
end

local function spawnEnemy(typeId, startDist, lateral)
	local def = Config.Enemies[typeId]
	if not def then
		return
	end
	nextEnemyId = nextEnemyId + 1
	local hp = math.floor(def.Health * Config.WaveHPMult(math.max(wave, 1)) * D.HP)
	local e = {
		Id = nextEnemyId,
		Type = typeId,
		Def = def,
		MaxHealth = hp,
		Health = hp,
		Speed = def.Speed * D.Speed,
		Dist = startDist or 0,
		Lateral = lateral or (def.IsBoss and 0 or rng:NextNumber(-2.2, 2.2)),
		Armor = def.Armor or 0,
		Dodge = def.Dodge or 0,
		IsBoss = def.IsBoss == true,
		SlowUntil = 0,
		SlowAmount = 0,
		Dots = {},
		NextDot = 0,
		Alive = true,
		Wave = wave,
	}
	if def.Summon then
		e.NextSummon = now() + def.Summon.Interval
	end
	-- особое поведение хэллоуинских врагов
	local t0 = now()
	e.BaseArmor = e.Armor
	if def.Phase then
		e.NextPhase = t0 + def.Phase.Every * rng:NextNumber(0.5, 1)
	end
	if def.Fog then
		e.NextFog = t0 + def.Fog.Every * rng:NextNumber(0.4, 0.8)
	end
	if def.Shield then
		e.NextShield = t0 + def.Shield.Every * 0.6
	end
	if def.Haste then
		e.NextHaste = t0 + def.Haste.Every * 0.7
	end
	e.Pos = enemyPos(e)
	enemies[e.Id] = e
	Remotes.EnemySpawn:FireAllClients({ e.Id, typeId, hp, e.Speed, e.Lateral, e.Dist })
	if e.IsBoss then
		refreshBoss()
	end
	return e
end

local function removeEnemy(e, reason)
	if not e.Alive then
		return
	end
	e.Alive = false
	enemies[e.Id] = nil
	removedBuffer[#removedBuffer + 1] = { e.Id, reason }
	if e.IsBoss then
		refreshBoss()
	end
end

local function killEnemy(e)
	local reward = math.floor(e.Def.Reward * (1 + S.KillRewardScalePerWave * (math.max(e.Wave, 1) - 1)) * D.Money + 0.5)
	addMoneyAll(reward)
	if e.Def.BossGems then
		local g = addGemsAll(e.Def.BossGems)
		notifyAll({ Type = "Toast", Text = e.Def.Name .. " повержен! +" .. g .. " гемов", Kind = "boss" })
		notifyAll({ Type = "BossDown" })
	end
	if e.Def.OnDeath then
		pendingSpawns[#pendingSpawns + 1] = { e.Def.OnDeath.Enemy, e.Def.OnDeath.Count, e.Dist + 1.5, e.Pos, "Straw" }
	end
	removeEnemy(e, "kill")
end

local function enemyState(e, state, dur)
	Remotes.Impact:FireAllClients({ K = "EnemyState", I = e.Id, S = state, DUR = dur, P = e.Pos })
end

-- множитель получаемого урона: фаза призрака, защита, метка проклятия
local function takenMult(e, t)
	local m = 1
	if (e.PhasedUntil or 0) > t then
		m = m * e.Def.Phase.Taken
	end
	if (e.ShieldUntil or 0) > t then
		m = m * e.Def.Shield.Taken
	end
	if (e.MarkUntil or 0) > t then
		m = m * (1 + (e.Mark or 0))
	end
	return m
end

-- броня с учётом участков дороги (Проклятый монарх)
local function armorOf(e)
	local a = e.Armor
	local zones = e.Def.ArmorZones
	if zones then
		local f = PathUtil.Fraction(e.Dist)
		for _, z in ipairs(zones) do
			if f >= z[1] and f <= z[2] then
				a = a + z[3]
			end
		end
	end
	return math.min(a, 0.9)
end

-- пороги HP: ломается броня, ярость, вторая фаза
local function checkThresholds(e)
	local def = e.Def
	local ratio = e.Health / e.MaxHealth
	if def.ArmorScale then
		e.Armor = e.BaseArmor * math.max(ratio, 0)
	end
	if def.ArmorBreak and not e.ArmorBroken and ratio <= def.ArmorBreak.At then
		e.ArmorBroken = true
		e.Armor = def.ArmorBreak.Armor
		enemyState(e, "ArmorBreak")
	end
	if def.Enrage and not e.Enraged and ratio <= def.Enrage.At then
		e.Enraged = true
		e.EnrageSpeed = def.Enrage.Speed or 0
		enemyState(e, "Enrage")
		if def.Enrage.Spawn then
			pendingSpawns[#pendingSpawns + 1] = { def.Enrage.Spawn[1], def.Enrage.Spawn[2], math.max(e.Dist - 4, 0), e.Pos, "Fire" }
		end
	end
end

local function pushDamage(id, amount, flag)
	damageBuffer[#damageBuffer + 1] = { id, amount, flag }
end

-- flag: 0 обычный, 1 крит, 2 уклонение
local function damageEnemy(e, amount, crit, unit, noDodge)
	if not e or not e.Alive then
		return 0
	end
	if not noDodge and e.Dodge > 0 and rng:NextNumber() < e.Dodge then
		pushDamage(e.Id, 0, 2)
		return 0
	end
	local dmg = math.max(1, math.floor(amount * (1 - armorOf(e)) * takenMult(e, now()) + 0.5))
	e.Health = e.Health - dmg
	pushDamage(e.Id, dmg, crit and 1 or 0)
	if unit then
		unit.DamageDealt = unit.DamageDealt + math.min(dmg, dmg + e.Health)
	end
	if e.Health <= 0 then
		killEnemy(e)
	else
		checkThresholds(e)
	end
	return dmg
end

-- чистый урон без брони и уклонения (столкновение с союзником)
local function rawDamage(e, amount, unit)
	if not e.Alive or amount <= 0 then
		return 0
	end
	local dmg = math.min(amount, e.Health)
	e.Health = e.Health - dmg
	pushDamage(e.Id, math.floor(dmg + 0.5), 0)
	if unit and unit.Alive then
		unit.DamageDealt = unit.DamageDealt + dmg
	end
	if e.Health <= 0.5 then
		e.Health = 0
		killEnemy(e)
	else
		checkThresholds(e)
	end
	return dmg
end

local function clearEnemies()
	for _, e in pairs(enemies) do
		e.Alive = false
		removedBuffer[#removedBuffer + 1] = { e.Id, "clear" }
	end
	enemies = {}
	zones = {}
	refreshBoss()
end

------------------------------------------------------------------------
-- ФАЗЫ МАТЧА
------------------------------------------------------------------------
local resetMatch

local function endMatch(victory)
	phase = victory and "Victory" or "Defeat"
	setState("Phase", phase)
	waveSpawning = false
	local myMatch = matchId
	if victory then
		local g = addGemsAll(S.VictoryGems)
		for _, pl in ipairs(matchPlayers()) do
			local prof = DataService.Get(pl)
			if prof then
				prof.Stats.Wins = (prof.Stats.Wins or 0) + 1
				prof.Stats.BestWave = math.max(prof.Stats.BestWave or 0, wave)
				DataService.Save(pl, true)
			end
		end
		-- Halloween Coins: каждому участнику за победу, один раз за матч
		local coins = 0
		if matchMode == "Halloween" and not coinsPaid[myMatch] then
			coinsPaid[myMatch] = true
			coins = Config.Halloween.Coins[difficultyKey] or 0
			for _, pl in ipairs(matchPlayers()) do
				if roster[pl.UserId] then
					DataService.AddCurrency(pl, "HalloweenCoins", coins)
					DataService.Save(pl, true)
					if GameService.OnProfileChanged then
						GameService.OnProfileChanged(pl)
					end
				end
			end
		end
		notifyAll({ Type = "Victory", Wave = wave, Gems = g, Coins = coins > 0 and coins or nil, Reset = S.ResetDelay, Difficulty = difficultyKey, Mode = matchMode })
	else
		for _, pl in ipairs(matchPlayers()) do
			local prof = DataService.Get(pl)
			if prof then
				prof.Stats.BestWave = math.max(prof.Stats.BestWave or 0, wave - 1)
				DataService.Save(pl, true)
			end
		end
		notifyAll({ Type = "Defeat", Wave = wave, Reset = S.ResetDelay, Difficulty = difficultyKey, Mode = matchMode })
		clearEnemies()
	end
	task.delay(S.ResetDelay, function()
		if matchId == myMatch then
			resetMatch()
		end
	end)
end

local function damageCore(amount)
	if phase == "Victory" or phase == "Defeat" then
		return
	end
	coreHP = math.max(0, coreHP - amount)
	setState("CoreHP", coreHP)
	notifyAll({ Type = "CoreHit", Amount = amount })
	if coreHP <= 0 then
		endMatch(false)
	end
end

local function waveCleared()
	local reward = math.floor((S.WaveRewardBase + S.WaveRewardPerWave * wave) * D.Money + 0.5)
	addMoneyAll(reward)
	local gems = addGemsAll(S.WaveGemsBase + S.WaveGemsPerWave * wave)
	if wave >= maxWave then
		endMatch(true)
		return
	end
	phase = "Intermission"
	nextWaveAt = now() + (D.Intermission or S.Intermission)
	setState("Phase", phase)
	setState("NextWaveAt", nextWaveAt)
	notifyAll({ Type = "WaveClear", Wave = wave, Reward = reward, Gems = gems })
end

local function startWave()
	if phase ~= "Prep" and phase ~= "Intermission" then
		return false
	end
	wave = wave + 1
	phase = "Wave"
	setState("Wave", wave)
	setState("Phase", phase)
	setState("NextWaveAt", 0)
	local source = matchMode == "Halloween" and Config.Maps.Halloween.Waves or Config.Waves
	local groups = {}
	for i, g in ipairs(source[wave] or {}) do
		-- BOSS — финальный босс выбранной сложности
		groups[i] = g[1] == "BOSS" and { Config.Halloween.Bosses[difficultyKey] or "GraveWarden", g[2], g[3] } or g
	end
	local bossName
	for _, g in ipairs(groups) do
		local def = Config.Enemies[g[1]]
		if def and def.IsBoss then
			bossName = def.Name
		end
	end
	notifyAll({ Type = "WaveStart", Wave = wave, Boss = bossName })
	waveSpawning = true
	local myMatch, myWave = matchId, wave
	task.spawn(function()
		for gi, g in ipairs(groups) do
			for i = 1, g[2] do
				if matchId ~= myMatch or phase ~= "Wave" then
					return
				end
				spawnEnemy(g[1])
				if i < g[2] then
					task.wait(g[3])
				end
			end
			if gi < #groups then
				task.wait(S.GroupDelay)
			end
		end
		if matchId == myMatch and wave == myWave then
			waveSpawning = false
		end
	end)
	return true
end

function GameService.RequestStartWave(player)
	if not inMatch(player) then
		return false, "Сначала зайди в матч через портал ИГРАТЬ"
	end
	if phase == "Prep" or phase == "Intermission" then
		startWave()
		return true
	end
	return false, "Волна уже идёт"
end

------------------------------------------------------------------------
-- ЮНИТЫ
------------------------------------------------------------------------
local function unitCountFor(player, unitId)
	local total, same = 0, 0
	for _, u in pairs(units) do
		if u.Owner == player then
			total = total + 1
			if u.Id == unitId then
				same = same + 1
			end
		end
	end
	return total, same
end

local function removeAlly(a, reason)
	if not a.Alive then
		return
	end
	a.Alive = false
	allies[a.Id] = nil
	allyRemoved[#allyRemoved + 1] = { a.Id, reason }
end

local function removeUnit(u)
	u.Alive = false
	units[u.Uid] = nil
	if u.Folder then
		u.Folder:Destroy()
	end
	-- проданный юнит забирает своих союзников
	for _, a in pairs(allies) do
		if a.Owner == u then
			removeAlly(a, "sold")
		end
	end
end

local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Include

function GameService.PlaceUnit(player, unitId, pos, rotation)
	if phase == "Victory" or phase == "Defeat" or phase == "Idle" then
		return false, "Матч не идёт"
	end
	if not inMatch(player) then
		return false, "Ты не в матче"
	end
	local def = Config.Units[unitId]
	if not def or typeof(pos) ~= "Vector3" then
		return false, "Неверный запрос"
	end
	if pos.X ~= pos.X or pos.Z ~= pos.Z then
		return false, "Неверная позиция"
	end
	if not DataService.IsEquipped(player, unitId) then
		return false, "Юнит не экипирован"
	end
	local cost = def.Levels[1].Cost
	if getMoney(player) < cost then
		return false, "Недостаточно денег"
	end
	local total, same = unitCountFor(player, unitId)
	if total >= S.MaxUnitsPerPlayer then
		return false, "Лимит юнитов: " .. S.MaxUnitsPerPlayer
	end
	local limit = Config.Rarities[def.Rarity].PlacementLimit
	if same >= limit then
		return false, "Лимит " .. def.Name .. ": " .. limit
	end
	local ok, why = PathUtil.IsPlacementClear(pos)
	if not ok then
		return false, why
	end
	-- проверяем, что под ногами остров
	raycastParams.FilterDescendantsInstances = { MapModels[matchMode] or Map }
	local hit = workspace:Raycast(Vector3.new(pos.X, PathUtil.Map.GroundY + 30, pos.Z), Vector3.new(0, -60, 0), raycastParams)
	if not hit or not hit.Instance:GetAttribute("Placeable") then
		return false, "Сюда ставить нельзя"
	end
	local ground = Vector3.new(pos.X, hit.Position.Y, pos.Z)
	for _, u in pairs(units) do
		if PathUtil.FlatDistance(u.Pos, ground) < S.PlacementSpacing then
			return false, "Слишком близко к другому юниту"
		end
	end

	setMoney(player, getMoney(player) - cost)
	nextUnitId = nextUnitId + 1
	local u = {
		Uid = nextUnitId,
		Id = unitId,
		Def = def,
		Owner = player,
		Level = 1,
		Pos = ground,
		Rotation = tonumber(rotation) or 0,
		TargetMode = def.DefaultTarget or "First",
		NextAttack = now() + 0.6,
		NextAbility = now() + 1.5,
		PlacedAt = now(),
		Spent = cost,
		DamageDealt = 0,
		Alive = true,
	}
	local f = Instance.new("Folder")
	f.Name = tostring(u.Uid)
	f:SetAttribute("UnitId", unitId)
	f:SetAttribute("Level", 1)
	f:SetAttribute("OwnerId", player.UserId)
	f:SetAttribute("OwnerName", player.DisplayName)
	f:SetAttribute("Position", ground)
	f:SetAttribute("Rotation", u.Rotation)
	f:SetAttribute("TargetMode", u.TargetMode)
	f:SetAttribute("Spent", u.Spent)
	f:SetAttribute("Damage", 0)
	f.Parent = UnitsFolder
	u.Folder = f
	-- таймеры способностей времени стартуют после установки
	if def.TimeHaste then
		u.NextHaste = u.PlacedAt + def.TimeHaste.FirstDelay
	end
	if def.TimeStorm then
		u.NextStorm = u.PlacedAt + def.TimeStorm.FirstDelay
	end
	-- призыв союзников: первый — через интервал текущего уровня
	if def.Summon then
		u.NextSummon = u.PlacedAt + def.Summon.Levels[1].Interval
		u.SummonCount = 0
	end
	-- руна: читается из профиля в момент установки
	u.Rune = DataService.GetRune(player, unitId)
	if u.Rune then
		f:SetAttribute("Rune", u.Rune)
		if u.Rune == "CursedThreads" then
			u.NextRuneSummon = u.PlacedAt + Config.Runes.CursedThreads.Summon.Interval
		end
	end
	units[u.Uid] = u
	return true, u.Uid
end

local function ownedUnit(player, uid)
	local u = units[tonumber(uid) or -1]
	if not u then
		return nil, "Юнит не найден"
	end
	if u.Owner ~= player then
		return nil, "Это не твой юнит"
	end
	return u
end

function GameService.UpgradeUnit(player, uid)
	local u, err = ownedUnit(player, uid)
	if not u then
		return false, err
	end
	if u.Level >= #u.Def.Levels then
		return false, "Максимальный уровень"
	end
	local cost = u.Def.Levels[u.Level + 1].Cost
	if getMoney(player) < cost then
		return false, "Недостаточно денег"
	end
	setMoney(player, getMoney(player) - cost)
	u.Level = u.Level + 1
	u.Spent = u.Spent + cost
	u.Folder:SetAttribute("Level", u.Level)
	u.Folder:SetAttribute("Spent", u.Spent)
	return true, u.Level
end

function GameService.SellUnit(player, uid)
	local u, err = ownedUnit(player, uid)
	if not u then
		return false, err
	end
	local refund = math.floor(u.Spent * S.SellRefund)
	setMoney(player, getMoney(player) + refund)
	removeUnit(u)
	return true, refund
end

function GameService.SetTargetMode(player, uid, mode)
	local u, err = ownedUnit(player, uid)
	if not u then
		return false, err
	end
	if not table.find(Config.TargetModes, mode) then
		return false, "Неверный режим"
	end
	u.TargetMode = mode
	u.Folder:SetAttribute("TargetMode", mode)
	return true
end

------------------------------------------------------------------------
-- ВЫБОР ЦЕЛИ
------------------------------------------------------------------------
local sorters = {
	First = function(a, b)
		return a.Dist > b.Dist
	end,
	Last = function(a, b)
		return a.Dist < b.Dist
	end,
	Strongest = function(a, b)
		if a.Health == b.Health then
			return a.Dist > b.Dist
		end
		return a.Health > b.Health
	end,
	Weakest = function(a, b)
		if a.Health == b.Health then
			return a.Dist > b.Dist
		end
		return a.Health < b.Health
	end,
}

local function candidates(u, range)
	local list = {}
	for _, e in pairs(enemies) do
		if e.Alive then
			local d = PathUtil.FlatDistance(e.Pos, u.Pos)
			if d <= range then
				e._d = d
				list[#list + 1] = e
			end
		end
	end
	if #list > 1 then
		local sorter = sorters[u.TargetMode]
		if u.TargetMode == "Closest" or not sorter then
			table.sort(list, function(a, b)
				return a._d < b._d
			end)
		else
			table.sort(list, sorter)
		end
	end
	return list
end

------------------------------------------------------------------------
-- АТАКИ
------------------------------------------------------------------------
local function rollDamage(stats)
	local dmg = stats.Damage
	local crit = false
	if stats.CritChance and rng:NextNumber() < stats.CritChance then
		dmg = dmg * (stats.CritMult or 2)
		crit = true
	end
	return dmg, crit
end

local function fireAttack(u, targetIds, extra)
	local payload = { U = u.Uid, T = targetIds, L = u.Level, EC = echoAttack or nil }
	if extra then
		for k, v in pairs(extra) do
			payload[k] = v
		end
	end
	Remotes.Attack:FireAllClients(payload)
end

local function valid(u, myMatch)
	return u.Alive and matchId == myMatch
end

------------------------------------------------------------------------
-- ЭФФЕКТЫ НА ВРАГАХ: периодический урон (кровотечение, нити) и замедление
------------------------------------------------------------------------
local function applyDot(e, dps, duration, u, kind)
	if not e.Alive or not dps or dps <= 0 then
		return
	end
	-- один источник обновляет свой эффект, а не стакает бесконечно
	local key = tostring(u and u.Uid or 0) .. ":" .. kind
	e.Dots[key] = { Dps = dps, Until = now() + duration, Unit = u }
end

local function applySlow(e, amount, duration)
	if not e then
		return
	end
	if not e.Alive or not amount then
		return
	end
	local t = now()
	amount = amount * (e.IsBoss and S.BossSlowResist or 1)
	if e.SlowUntil < t then
		e.SlowAmount = 0
	end
	e.SlowAmount = math.max(e.SlowAmount, amount)
	e.SlowUntil = math.max(e.SlowUntil, t + duration)
end

local function updateDots(t)
	for _, e in pairs(enemies) do
		if next(e.Dots) and t >= e.NextDot then
			e.NextDot = t + 0.5
			local total, unit = 0, nil
			for key, d in pairs(e.Dots) do
				if t >= d.Until then
					e.Dots[key] = nil
				else
					total = total + d.Dps * 0.5
					unit = unit or d.Unit
				end
			end
			if total > 0 then
				damageEnemy(e, total, false, unit, true)
			end
		end
	end
end

-- AOE: каждый враг получает урон ровно один раз за удар.
-- opts: Exclude (враг без урона), Mult, Bleed/BleedTime, Color, Extra (доп. поля события)
local function aoeHit(u, center, radius, stats, kind, opts)
	opts = opts or {}
	local hitSet = {}
	for _, e in pairs(enemies) do
		if e.Alive and e ~= opts.Exclude and PathUtil.FlatDistance(e.Pos, center) <= radius + (e.IsBoss and 1.5 or 0.5) then
			hitSet[#hitSet + 1] = e
		end
	end
	local payload = { K = kind, P = center, R = radius, L = u.Level, U = u.Uid, N = #hitSet }
	for k, v in pairs(opts.Extra or {}) do
		payload[k] = v
	end
	Remotes.Impact:FireAllClients(payload)
	for _, e in ipairs(hitSet) do
		local dmg, crit = rollDamage(stats)
		if opts.Bleed then
			applyDot(e, opts.Bleed, opts.BleedTime or 3, u, opts.DotKind or "Bleed")
		end
		if opts.Slow then
			applySlow(e, opts.Slow, opts.SlowTime or 1.5)
		end
		damageEnemy(e, dmg * (opts.Mult or 1), crit, u)
	end
	return hitSet
end

local function distToSegment(p, a, b)
	local abx, abz = b.X - a.X, b.Z - a.Z
	local lenSq = abx * abx + abz * abz
	local t = 0
	if lenSq > 0 then
		t = math.clamp(((p.X - a.X) * abx + (p.Z - a.Z) * abz) / lenSq, 0, 1)
	end
	local cx, cz = a.X + abx * t, a.Z + abz * t
	return math.sqrt((p.X - cx) ^ 2 + (p.Z - cz) ^ 2)
end

------------------------------------------------------------------------
-- СПОСОБНОСТИ ВРЕМЕНИ (Проклятый часовщик)
------------------------------------------------------------------------
-- Остановка не суммируется: замороженного не морозим повторно, после заморозки — иммунитет
local function freezeEnemy(e, duration, t)
	e.FrozenUntil = t + duration
	e.FreezeImmuneUntil = t + duration + (S.FreezeImmunity or 3)
end

local function castTimeBreak(u, stats)
	local tb = u.Def.TimeBreak
	local list = candidates(u, stats.Range + 2)
	if #list == 0 then
		return
	end
	local t = now()
	local center = list[1].Pos
	local normal, bosses = {}, {}
	for _, e in pairs(enemies) do
		if e.Alive and t >= (e.FreezeImmuneUntil or 0) and (e.FrozenUntil or 0) <= t then
			local d = PathUtil.FlatDistance(e.Pos, center)
			if d <= tb.Radius + (e.IsBoss and 1.5 or 0) then
				e._dc = d
				table.insert(e.IsBoss and bosses or normal, e)
			end
		end
	end
	table.sort(normal, function(a, b)
		return a._dc < b._dc
	end)
	local frozen = {}
	for i = 1, math.min(tb.MaxFreeze, #normal) do
		freezeEnemy(normal[i], tb.Freeze, t)
		frozen[i] = normal[i]
	end
	for _, b in ipairs(bosses) do
		freezeEnemy(b, tb.BossFreeze, t)
	end
	Remotes.Attack:FireAllClients({ U = u.Uid, T = { list[1].Id }, L = u.Level, D = 0.5, AB = "TimeBreak" })
	Remotes.Impact:FireAllClients({ K = "TimeBreak", P = center, R = tb.Radius, DUR = tb.Freeze, U = u.Uid, L = u.Level })
	-- после остановки до 3 обычных врагов отматываются назад по дороге (боссы — нет)
	local myMatch = matchId
	task.delay(tb.Freeze, function()
		if matchId ~= myMatch then
			return
		end
		for i = 1, math.min(tb.MaxRewind, #frozen) do
			local e = frozen[i]
			if e.Alive then
				e.Dist = math.max(0, e.Dist - tb.Rewind)
				e.Pos = enemyPos(e)
			end
		end
	end)
end

local function castTimeHaste(u, stats)
	local th = u.Def.TimeHaste
	local t = now()
	local allies = {}
	for _, o in pairs(units) do
		-- только свои юниты того же игрока, не сам часовщик
		if o ~= u and o.Alive and o.Owner == u.Owner and PathUtil.FlatDistance(o.Pos, u.Pos) <= th.Radius then
			-- одинаковые ускорения не суммируются: действует самое сильное
			if (o.HasteUntil or 0) > t then
				o.Haste = math.max(o.Haste or 0, stats.Haste)
			else
				o.Haste = stats.Haste
			end
			o.HasteUntil = math.max(o.HasteUntil or 0, t + stats.HasteTime)
			allies[#allies + 1] = o.Uid
		end
	end
	Remotes.Attack:FireAllClients({ U = u.Uid, T = {}, L = u.Level, D = 0.4, AB = "TimeHaste" })
	Remotes.Impact:FireAllClients({ K = "TimeHaste", P = u.Pos, R = th.Radius, A = allies, DUR = stats.HasteTime, U = u.Uid, L = u.Level })
end

local function startTimeStorm(u, t)
	local ts = u.Def.TimeStorm
	u.StormUntil = t + ts.Duration
	u.NextStorm = u.StormUntil + ts.Cooldown
	u.Folder:SetAttribute("Storm", true)
	Remotes.Attack:FireAllClients({ U = u.Uid, T = {}, L = u.Level, D = 1.2, AB = "TimeStorm" })
	Remotes.Impact:FireAllClients({ K = "TimeStorm", P = u.Pos, R = 6, DL = 1.3, U = u.Uid, L = u.Level })
end

local function updateChrono(u, stats, t)
	local def = u.Def
	if def.TimeStorm then
		if u.StormUntil and t >= u.StormUntil then
			u.StormUntil = nil
			u.Folder:SetAttribute("Storm", false)
		end
		if not u.StormUntil and t >= u.NextStorm then
			startTimeStorm(u, t)
			u.NextAttack = math.max(u.NextAttack, t + 1.4)
		end
	end
	if def.TimeHaste and t >= u.NextHaste then
		castTimeHaste(u, stats)
		u.NextHaste = t + def.TimeHaste.Interval
		u.NextAttack = math.max(u.NextAttack, t + 0.6)
	end
end

-- ядовитая/огненная зона: урон раз в 0.5 с всем внутри
local function poisonZone(u, pos, radius, duration, dps, kind, delay)
	if dps <= 0 then
		return
	end
	local t = now() + (delay or 0)
	zones[#zones + 1] = {
		Pos = pos, Radius = radius, Until = t + duration, NextTick = t, Tick = 0.5,
		TickDamage = dps * 0.5, Slow = 0, Unit = u,
	}
	Remotes.Impact:FireAllClients({ K = kind, P = pos, R = radius, DUR = duration, DL = delay, U = u.Uid, L = u.Level })
end

local function attack(u, stats, list)
	list = list or {}
	if not list[1] then
		return
	end
	local def = u.Def
	local myMatch = matchId
	local hitDelay = def.HitDelay or 0.2
	local target = list[1]
	local atype = def.AttackType

	local function later(delay, fn)
		task.delay(delay, function()
			if valid(u, myMatch) then
				fn()
			end
		end)
	end

	-- урон + эффекты при попадании (кровотечение)
	local function strike(e, mult, forceCrit)
		if not e or not e.Alive then
			return
		end
		local dmg, crit = rollDamage(stats)
		if stats.Bleed then
			applyDot(e, stats.Bleed, stats.BleedTime or 3, u, "Bleed")
		end
		damageEnemy(e, dmg * (mult or 1), crit or forceCrit, u)
	end

	if atype == "Melee" or atype == "Laser" then
		local mult, power = 1, false
		if def.EveryNth and not echoAttack then
			u.HitCount = (u.HitCount or 0) + 1
			if u.HitCount % def.EveryNth.N == 0 then
				mult, power = def.EveryNth.Mult, true
			end
		end
		fireAttack(u, { target.Id }, { D = hitDelay, PW = power })
		later(hitDelay, function()
			strike(target, mult, power)
		end)
	elseif atype == "Projectile" then
		local shots = stats.Shots or 1
		local ids, travels = {}, {}
		for s = 1, shots do
			local e = list[((s - 1) % #list) + 1]
			ids[s] = e.Id
			travels[s] = PathUtil.FlatDistance(u.Pos, e.Pos) / (def.ProjectileSpeed or 80)
		end
		fireAttack(u, ids, { D = hitDelay, TR = travels[1], TRS = travels, SG = 0.12 })
		for s = 1, shots do
			local e = list[((s - 1) % #list) + 1]
			later(hitDelay + (s - 1) * 0.12 + travels[s], function()
				if not e.Alive then
					return
				end
				local center = e.Pos
				strike(e)
				if stats.Explode then
					aoeHit(u, center, stats.Explode, stats, def.ExplodeKind or "Crystal", { Exclude = e, Mult = def.ExplodeMult or 0.5 })
				end
			end)
		end
	elseif atype == "Chain" then
		-- лунный серп отскакивает к ближайшим врагам
		local seq, times = { target }, {}
		local used = { [target] = true }
		local speed = def.ProjectileSpeed or 60
		times[1] = hitDelay + PathUtil.FlatDistance(u.Pos, target.Pos) / speed
		for i = 2, stats.Bounces or 3 do
			local prev = seq[i - 1]
			local best, bestD
			for _, e in pairs(enemies) do
				if e.Alive and not used[e] then
					local d = PathUtil.FlatDistance(e.Pos, prev.Pos)
					if d <= (def.BounceRange or 12) and (not bestD or d < bestD) then
						best, bestD = e, d
					end
				end
			end
			if not best then
				break
			end
			used[best] = true
			seq[i] = best
			times[i] = times[i - 1] + bestD / speed
		end
		local ids = {}
		for i, e in ipairs(seq) do
			ids[i] = e.Id
		end
		fireAttack(u, ids, { D = hitDelay, TT = times })
		for i, e in ipairs(seq) do
			later(times[i], function()
				strike(e, (def.BounceMult or 0.8) ^ (i - 1))
			end)
		end
	elseif atype == "Thread" then
		local ids, targets = {}, {}
		for i = 1, math.min(stats.Targets or 1, #list) do
			targets[i] = list[i]
			ids[i] = list[i].Id
		end
		fireAttack(u, ids, { D = hitDelay })
		later(hitDelay, function()
			for _, e in ipairs(targets) do
				if e.Alive then
					applySlow(e, stats.Slow, stats.SlowTime or 1.5)
					applyDot(e, stats.Dot, stats.DotTime or 3, u, "Thread")
					strike(e)
				end
			end
		end)
	elseif atype == "AOE" then
		local saved = target.Pos
		fireAttack(u, { target.Id }, { D = hitDelay })
		later(hitDelay, function()
			local center = target.Alive and target.Pos or saved
			aoeHit(u, center, stats.AOERadius or 6, stats, def.ImpactKind or "Reap", { Bleed = stats.Bleed, BleedTime = stats.BleedTime })
			-- падающие звёздные осколки
			for k = 1, stats.Shards or 0 do
				later(0.35 + k * 0.15, function()
					local pool = candidates(u, stats.Range + 4)
					if #pool > 0 then
						local e = pool[math.random(1, #pool)]
						aoeHit(u, e.Pos, stats.ShardRadius or 4, stats, "Shard", { Mult = stats.ShardMult or 0.6 })
					end
				end)
			end
		end)
	elseif atype == "MultiHit" then
		local hits = stats.Hits or 1
		local interval = def.HitInterval or 0.15
		local spread = def.Spread or (u.Id == "VoidEmperor")
		local kind = def.ImpactKind or "Judgement"
		local ids = {}
		local plan = {}
		for h = 1, hits do
			local e = spread and list[((h - 1) % #list) + 1] or target
			plan[h] = e
			ids[h] = e.Id
		end
		fireAttack(u, ids, { D = hitDelay, I = interval })
		for h = 1, hits do
			later(hitDelay + (h - 1) * interval, function()
				local e = plan[h]
				if not e.Alive then
					e = candidates(u, stats.Range)[1]
				end
				if e then
					if spread then
						Remotes.Impact:FireAllClients({ K = kind, P = e.Pos, L = u.Level, U = u.Uid, H = h })
					end
					strike(e)
				end
			end)
		end
		if stats.BigRift then
			later(hitDelay + hits * interval + 0.2, function()
				local pool = candidates(u, stats.Range)
				if #pool > 0 then
					aoeHit(u, pool[1].Pos, stats.BigRift, stats, "BigRift", { Mult = stats.BigRiftMult or 1.5 })
				end
			end)
		end
	elseif atype == "Splash" then
		-- RED SPLASH: цель 100%, остальные в радиусе 50% (цель второй раз не задевается)
		fireAttack(u, { target.Id }, { D = hitDelay })
		local saved = target.Pos
		later(hitDelay, function()
			local center = target.Alive and target.Pos or saved
			local primary = target.Alive and target or nil
			strike(primary)
			aoeHit(u, center, stats.AOERadius or 8, stats, "Splash", { Exclude = target, Mult = def.SplashMult or 0.5 })
		end)
	elseif atype == "Chrono" then
		-- РАЗРЕЗ СЕКУНД: зубчатый диск летит по прямой и режет до DiscTargets врагов
		local t0 = now()
		local storm = u.StormUntil ~= nil and t0 < u.StormUntil
		local dir = Vector3.new(target.Pos.X - u.Pos.X, 0, target.Pos.Z - u.Pos.Z)
		if dir.Magnitude < 0.1 then
			dir = Vector3.new(0, 0, -1)
		end
		dir = dir.Unit
		local endPos = u.Pos + dir * (stats.Range + 3)
		local speed = def.ProjectileSpeed or 70
		local half = (def.DiscWidth or 3) / 2
		local line = {}
		for _, e in pairs(enemies) do
			if e.Alive and e ~= target and distToSegment(e.Pos, u.Pos, endPos) <= half + (e.IsBoss and 1.2 or 0) then
				e._along = (e.Pos.X - u.Pos.X) * dir.X + (e.Pos.Z - u.Pos.Z) * dir.Z
				line[#line + 1] = e
			end
		end
		table.sort(line, function(a, b)
			return a._along < b._along
		end)
		local hits = { target }
		local hitSet = { [target] = true }
		for _, e in ipairs(line) do
			if #hits >= (def.DiscTargets or 5) then
				break
			end
			hits[#hits + 1] = e
			hitSet[e] = true
		end
		fireAttack(u, { target.Id }, { D = hitDelay, E = endPos, SP = speed, ST = storm or nil })
		for _, e in ipairs(hits) do
			local along = math.max(0, (e.Pos.X - u.Pos.X) * dir.X + (e.Pos.Z - u.Pos.Z) * dir.Z)
			later(hitDelay + along / speed, function()
				if e.Alive then
					Remotes.Impact:FireAllClients({ K = "ChronoHit", P = e.Pos, L = u.Level, U = u.Uid })
					strike(e)
				end
			end)
		end
		-- ВРЕМЕННАЯ БУРЯ: основная цель 100% (диском), до 4 других врагов рядом с ней — по 50%.
		-- Эти попадания не считаются обычными атаками.
		if storm then
			local ts = def.TimeStorm
			local saved = target.Pos
			later(hitDelay + PathUtil.FlatDistance(u.Pos, target.Pos) / speed + 0.02, function()
				local center = target.Alive and target.Pos or saved
				local extra = {}
				for _, e in pairs(enemies) do
					if e.Alive and not hitSet[e] then
						local d = PathUtil.FlatDistance(e.Pos, center)
						if d <= ts.Radius + (e.IsBoss and 1 or 0.3) then
							e._dc = d
							extra[#extra + 1] = e
						end
					end
				end
				table.sort(extra, function(a, b)
					return a._dc < b._dc
				end)
				Remotes.Impact:FireAllClients({ K = "ChronoBurst", P = center, R = ts.Radius, L = u.Level, U = u.Uid })
				for i = 1, math.min(ts.Extra, #extra) do
					strike(extra[i], ts.Mult)
				end
			end)
		end
		-- ПОЛОМКА ВРЕМЕНИ: каждая 8-я обычная атака, но не чаще раза в 18 с
		local tb = def.TimeBreak
		if not echoAttack then
			u.ChronoCount = (u.ChronoCount or 0) + 1
		end
		if not echoAttack and u.ChronoCount >= tb.EveryNth and t0 - (u.LastBreak or -1e9) >= tb.MinInterval then
			u.ChronoCount = 0
			u.LastBreak = t0
			u.NextAttack = math.max(u.NextAttack or 0, t0 + 1.6)
			later(hitDelay + 0.45, function()
				castTimeBreak(u, stats)
			end)
		end
	elseif atype == "Pulse" then
		-- звуковая волна вокруг самого юнита
		fireAttack(u, { target.Id }, { D = hitDelay })
		later(hitDelay, function()
			aoeHit(u, u.Pos, stats.AOERadius or stats.Range, stats, def.ImpactKind or "BellWave")
		end)
	elseif atype == "Flask" then
		-- колба: взрыв по области и ядовитая лужа (урон по времени)
		local travel = PathUtil.FlatDistance(u.Pos, target.Pos) / (def.ProjectileSpeed or 45)
		local saved = target.Pos
		fireAttack(u, { target.Id }, { D = hitDelay, TR = travel })
		later(hitDelay + travel, function()
			local center = target.Alive and target.Pos or saved
			aoeHit(u, center, stats.Explode or 5, stats, "FlaskSplash")
			poisonZone(u, center, (stats.Explode or 5) * 0.8, def.PoisonTime or 3, stats.PoisonDps or 0, "Poison")
		end)
	elseif atype == "Pierce" then
		-- луч насквозь: все враги на линии от юнита через цель
		local dir = Vector3.new(target.Pos.X - u.Pos.X, 0, target.Pos.Z - u.Pos.Z)
		if dir.Magnitude < 0.1 then
			dir = Vector3.new(0, 0, -1)
		end
		local endPos = u.Pos + dir.Unit * (stats.Range + 4)
		fireAttack(u, { target.Id }, { D = hitDelay, E = endPos })
		later(hitDelay, function()
			Remotes.Impact:FireAllClients({ K = def.ImpactKindPierce or "Pierce", P = u.Pos, E = endPos, L = u.Level, U = u.Uid })
			local half = (def.PierceWidth or 3) / 2
			local hitSet = {}
			for _, e in pairs(enemies) do
				if e.Alive and distToSegment(e.Pos, u.Pos, endPos) <= half + (e.IsBoss and 1.2 or 0) then
					hitSet[#hitSet + 1] = e
				end
			end
			for _, e in ipairs(hitSet) do
				strike(e)
			end
		end)
	end
end

------------------------------------------------------------------------
-- HALLOWEEN: обычная атака с рунами, способности Power, союзники
------------------------------------------------------------------------
-- через сколько секунд обычная атака попадает в цель
local function impactDelay(u, target)
	local def = u.Def
	local d = def.HitDelay or 0.2
	if def.ProjectileSpeed and def.AttackType ~= "Chrono" then
		d = d + PathUtil.FlatDistance(u.Pos, target.Pos) / def.ProjectileSpeed
	elseif def.AttackType == "Chrono" then
		d = d + PathUtil.FlatDistance(u.Pos, target.Pos) / (def.ProjectileSpeed or 70)
	end
	return d
end

local function nearestTo(center, radius, exclude, maxCount)
	local list = {}
	for _, e in pairs(enemies) do
		if e.Alive and not exclude[e] then
			local d = PathUtil.FlatDistance(e.Pos, center)
			if d <= radius + (e.IsBoss and 1 or 0.3) then
				e._dr = d
				list[#list + 1] = e
			end
		end
	end
	table.sort(list, function(a, b)
		return a._dr < b._dr
	end)
	while #list > maxCount do
		table.remove(list)
	end
	return list
end

-- Руны после обычной атаки (повтор «Призрачной короны» руны не запускает)
local function runeAfterAttack(u, stats, list)
	local runeId = u.Rune
	local rune = runeId and Config.Runes[runeId]
	if not rune or echoAttack then
		return
	end
	local target = list[1]
	local myMatch = matchId
	if runeId == "LanternHeart" then
		-- каждая 3-я обычная атака: огненный взрыв 20% урона, радиус 4, до 4 дополнительных врагов
		u.RuneCount = (u.RuneCount or 0) + 1
		if u.RuneCount % rune.EveryNth == 0 then
			local saved = target.Pos
			task.delay(impactDelay(u, target), function()
				if not valid(u, myMatch) then
					return
				end
				local center = target.Alive and target.Pos or saved
				local extra = nearestTo(center, rune.Radius, { [target] = true }, rune.MaxTargets)
				Remotes.Impact:FireAllClients({ K = "LanternHeart", P = center, R = rune.Radius, U = u.Uid, L = u.Level, N = #extra })
				for _, e in ipairs(extra) do
					damageEnemy(e, stats.Damage * rune.Mult, false, u, true)
				end
			end)
		end
	elseif runeId == "CursedThreads" then
		-- каждая 5-я обычная атака: замедление до 3 врагов на 25% (боссы — вдвое слабее), не суммируется
		u.RuneCount = (u.RuneCount or 0) + 1
		if u.RuneCount % rune.EveryNth == 0 then
			task.delay(impactDelay(u, target), function()
				if not valid(u, myMatch) then
					return
				end
				local first = target.Alive and target or nil
				local center = first and first.Pos or target.Pos
				local list2 = first and { first } or {}
				for _, e in ipairs(nearestTo(center, 8, { [target] = true }, rune.MaxTargets - #list2)) do
					list2[#list2 + 1] = e
				end
				local ids = {}
				for i, e in ipairs(list2) do
					applySlow(e, rune.Slow, rune.SlowTime)
					ids[i] = e.Id
				end
				Remotes.Impact:FireAllClients({ K = "CursedThreads", P = center, A = ids, U = u.Uid, L = u.Level, DUR = rune.SlowTime })
			end)
		end
	elseif runeId == "PhantomCrown" then
		-- 30%: призрачная копия повторяет атаку через 0.3 с со 100% урона, не задерживая следующую атаку
		if rng:NextNumber() < rune.Chance then
			task.delay(rune.Delay, function()
				if not valid(u, myMatch) or phase ~= "Wave" and phase ~= "Intermission" and phase ~= "Prep" then
					return
				end
				local pool = candidates(u, stats.Range)
				if target.Alive and PathUtil.FlatDistance(target.Pos, u.Pos) <= stats.Range then
					for i, e in ipairs(pool) do
						if e == target then
							table.remove(pool, i)
							break
						end
					end
					table.insert(pool, 1, target)
				end
				if #pool == 0 then
					return -- целей нет — повтор отменяется
				end
				Remotes.Impact:FireAllClients({ K = "PhantomEcho", P = u.Pos, U = u.Uid, L = u.Level })
				echoAttack = true
				local ok, err = pcall(attack, u, stats, pool)
				echoAttack = false
				if not ok then
					warn("[VOID TD] echo: " .. tostring(err))
				end
			end)
		end
	end
end

local function normalAttack(u, stats, list)
	attack(u, stats, list)
	if u.Rune then
		runeAfterAttack(u, stats, list)
	end
end

-- Способность вместо каждой N-й обычной атаки
local function castPower(u, stats, list)
	local def = u.Def
	local P = def.Power
	local target = list[1]
	local myMatch = matchId
	local delay = P.Delay or 0.45
	local saved = target.Pos
	-- длинная анимация способности не обрывается следующей атакой
	u.NextAttack = math.max(u.NextAttack, now() + delay + 0.25)
	Remotes.Attack:FireAllClients({ U = u.Uid, T = { target.Id }, L = u.Level, D = delay, AB = P.Anim })
	task.delay(delay, function()
		if not valid(u, myMatch) then
			return
		end
		local center = target.Alive and target.Pos or saved
		if P.Mode == "Single" then
			local e = target.Alive and target or candidates(u, stats.Range + 2)[1]
			if not e then
				return
			end
			Remotes.Impact:FireAllClients({ K = P.Kind, P = e.Pos, I = e.Id, U = u.Uid, L = u.Level, DUR = P.MarkTime })
			if P.Mark then
				e.Mark = P.Mark
				e.MarkUntil = now() + (P.MarkTime or 3)
			end
			local dmg, crit = rollDamage(stats)
			damageEnemy(e, dmg * (P.Mult or 1), crit or true, u)
		elseif P.Mode == "Zone" then
			local radius = (stats.Explode or 5) * (P.RadiusMult or 1.5)
			aoeHit(u, center, radius, stats, P.Kind .. "Burst", { Mult = 0.5 })
			poisonZone(u, center, radius, P.Duration or 5, (stats.PoisonDps or stats.Damage * 0.3) * (P.Mult or 1), P.Kind)
		else
			local radius = stats.PowerRadius or P.Radius or ((stats.AOERadius or 5) + (P.RadiusAdd or 0))
			if P.Mode == "Self" then
				center = u.Pos
				radius = stats.PowerRadius or P.Radius or ((stats.AOERadius or stats.Range) + (P.RadiusAdd or 1))
			end
			aoeHit(u, center, radius, stats, P.Kind, {
				Mult = P.Mult, Slow = P.Slow, SlowTime = P.SlowTime,
				Bleed = P.Burn and stats.Damage * P.Burn or nil, BleedTime = P.BurnTime, DotKind = "Burn",
			})
		end
	end)
end

-- СОЮЗНИКИ
local function spawnAlly(u, allyId, hp, source, index)
	nextAllyId = nextAllyId + 1
	local a = {
		Id = nextAllyId,
		AllyId = allyId,
		HP = hp,
		MaxHP = hp,
		Dist = math.max(1, PathUtil.Length - (S.AllyStartBack or 4) - (index or 0) * 2.2),
		Lateral = rng:NextNumber(-1.6, 1.6),
		Speed = S.AllySpeed or 6,
		Owner = u,
		Source = source,
		Born = now(),
		Alive = true,
	}
	a.Pos = PathUtil.OffsetPositionAt(a.Dist, a.Lateral)
	allies[a.Id] = a
	return a
end

local function alliesOf(u, source)
	local list = {}
	for _, a in pairs(allies) do
		if a.Owner == u and a.Source == source then
			list[#list + 1] = a
		end
	end
	table.sort(list, function(x, y)
		return x.Id < y.Id
	end)
	return list
end

-- Призыв Кукловода / Иллюзиониста: не больше Max живых, лишние не появляются
local function castSummon(u, t)
	local sm = u.Def.Summon
	local lv = sm.Levels[u.Level]
	u.NextSummon = t + lv.Interval
	local alive = #alliesOf(u, "Summon")
	local count = math.min(lv.Count, sm.Max - alive)
	if count <= 0 then
		return
	end
	u.SummonCount = (u.SummonCount or 0) + 1
	local golden = sm.Golden and u.Level >= #u.Def.Levels and u.SummonCount % sm.Golden.Every == 0
	local ids = {}
	for i = 1, count do
		local a
		if golden and i == 1 then
			a = spawnAlly(u, sm.Golden.Ally, sm.Golden.HP, "Summon", i - 1)
		else
			a = spawnAlly(u, lv.Ally, lv.HP, "Summon", i - 1)
		end
		ids[i] = a.Id
	end
	Remotes.Attack:FireAllClients({ U = u.Uid, T = {}, L = u.Level, D = 0.6, AB = "Summon" })
	Remotes.Impact:FireAllClients({ K = "SummonPortal", S = sm.Portal, P = PathUtil.PositionAt(PathUtil.Length - (S.AllyStartBack or 4)), U = u.Uid, L = u.Level, A = ids, G = golden or nil })
end

-- «Проклятые нити»: ровно каждые 60 с, не больше 3 живых, лишний — самый старый — исчезает
local function runeSummon(u, t)
	local sm = Config.Runes.CursedThreads.Summon
	u.NextRuneSummon = u.NextRuneSummon + sm.Interval
	local lv = sm.Levels[u.Level]
	local ids = {}
	for i = 1, lv.Count do
		local a = spawnAlly(u, lv.Ally, lv.HP, "Rune", i - 1)
		ids[i] = a.Id
	end
	local list = alliesOf(u, "Rune")
	for i = 1, #list - sm.Max do
		removeAlly(list[i], "replaced")
	end
	Remotes.Impact:FireAllClients({ K = "CursedCircle", P = PathUtil.PositionAt(PathUtil.Length - (S.AllyStartBack or 4)), U = u.Uid, L = u.Level, A = ids })
end

local function updateAllies(t, dt)
	for _, a in pairs(allies) do
		if a.Alive then
			a.Dist = a.Dist - a.Speed * dt
			if a.Dist <= 0 then
				removeAlly(a, "portal")
			else
				a.Pos = PathUtil.OffsetPositionAt(a.Dist, a.Lateral)
				-- столкновение: враг дошёл до союзника (окно с запасом для большого dt)
				for _, e in pairs(enemies) do
					if e.Alive and e.Dist >= a.Dist - 1.4 - (e.IsBoss and 1.2 or 0) and e.Dist <= a.Dist + 3 then
						local cost = e.Def.FireAura or 1
						local dealt = rawDamage(e, math.min(a.HP / cost, e.Health), a.Owner)
						a.HP = a.HP - dealt * cost
						Remotes.Impact:FireAllClients({ K = "AllyHit", P = a.Pos, I = a.Id, E = e.Id, F = cost > 1 or nil })
						if a.HP <= 0.5 then
							removeAlly(a, "dead")
							break
						end
					end
				end
			end
		end
	end
end

local function castBloodMoon(u, stats, list)
	local bm = stats.BloodMoon
	local myMatch = matchId
	local target = list[1]
	local pos = PathUtil.PositionAt(math.min(target.Dist + 3, PathUtil.Length - 1))
	Remotes.Attack:FireAllClients({ U = u.Uid, T = { target.Id }, L = u.Level, D = 0.6, AB = true })
	Remotes.Impact:FireAllClients({ K = "BloodMoonFall", P = pos, R = bm.Radius, L = u.Level, U = u.Uid, DL = 1.0 })
	task.delay(1.0, function()
		if valid(u, myMatch) then
			local big = { Damage = stats.Damage * (bm.Mult or 3) }
			aoeHit(u, pos, bm.Radius, big, "BloodMoon", { Bleed = bm.Bleed, BleedTime = bm.BleedTime })
		end
	end)
end

local function castBlackHole(u, stats, list)
	local bh = stats.BlackHole
	local target = list[1]
	local pos = PathUtil.PositionAt(math.min(target.Dist + 4, PathUtil.Length - 1))
	local zone = {
		Pos = pos,
		Radius = bh.Radius,
		Until = now() + 0.6 + bh.Duration,
		NextTick = now() + 0.6,
		Tick = bh.Tick,
		TickDamage = bh.TickDamage,
		Slow = bh.Slow,
		Unit = u,
	}
	Remotes.Attack:FireAllClients({ U = u.Uid, T = { target.Id }, L = u.Level, D = 0.6, AB = true })
	Remotes.Impact:FireAllClients({ K = "BlackHole", P = pos, R = bh.Radius, L = u.Level, U = u.Uid, DUR = bh.Duration, DL = 0.6 })
	zones[#zones + 1] = zone
end

local function updateZones(t)
	for i = #zones, 1, -1 do
		local z = zones[i]
		if t >= z.Until or not z.Unit.Alive then
			table.remove(zones, i)
		elseif t >= z.NextTick then
			z.NextTick = z.NextTick + z.Tick
			for _, e in pairs(enemies) do
				if e.Alive and PathUtil.FlatDistance(e.Pos, z.Pos) <= z.Radius then
					if z.Slow and z.Slow > 0 then
						local slow = z.Slow * (e.IsBoss and S.BossSlowResist or 1)
						e.SlowUntil = t + z.Tick + 0.15
						e.SlowAmount = math.max(slow, (e.SlowUntil > t and e.SlowAmount) or 0)
					end
					damageEnemy(e, z.TickDamage, false, z.Unit, true)
				end
			end
		end
	end
end

local function updateUnits(t)
	for _, u in pairs(units) do
		local stats = u.Def.Levels[u.Level]
		if stats.BlackHole and t >= u.NextAbility then
			local list = candidates(u, stats.Range + (u.Def.BlackHoleExtraRange or 6))
			if #list > 0 then
				castBlackHole(u, stats, list)
				u.NextAbility = t + stats.BlackHole.Cooldown
				u.NextAttack = math.max(u.NextAttack, t + 0.9)
			end
		end
		if stats.BloodMoon and t >= u.NextAbility then
			local list = candidates(u, stats.Range + (u.Def.AbilityExtraRange or 6))
			if #list > 0 then
				castBloodMoon(u, stats, list)
				u.NextAbility = t + stats.BloodMoon.Cooldown
				u.NextAttack = math.max(u.NextAttack, t + 1.0)
			end
		end
		if u.Def.TimeHaste or u.Def.TimeStorm then
			updateChrono(u, stats, t)
		end
		if u.Def.Summon and t >= u.NextSummon then
			castSummon(u, t)
		end
		if u.NextRuneSummon and t >= u.NextRuneSummon then
			runeSummon(u, t)
		end
		if t >= u.NextAttack then
			local list = candidates(u, stats.Range)
			if #list > 0 then
				-- ускорение времени: союзник атакует чаще, урон за удар прежний
				local cd = stats.Cooldown
				if (u.HasteUntil or 0) > t then
					cd = cd / (1 + (u.Haste or 0))
				end
				u.NextAttack = t + cd
				local P = u.Def.Power
				if P then
					u.PowerCount = (u.PowerCount or 0) + 1
				end
				if P and u.PowerCount % P.N == 0 then
					castPower(u, stats, list)
				else
					normalAttack(u, stats, list)
				end
			end
		end
	end
end

------------------------------------------------------------------------
-- ЦИКЛ
------------------------------------------------------------------------
local function updateEnemies(t, dt)
	local reached = {}
	for _, e in pairs(enemies) do
		local mult = 1
		if (e.FrozenUntil or 0) > t then
			mult = 0
		elseif e.SlowUntil > t then
			mult = 1 - e.SlowAmount
		else
			e.SlowAmount = 0
		end
		-- ускорения: туман, рывок босса, ярость (замедление и заморозка действуют поверх)
		local boost = (e.EnrageSpeed or 0)
		if (e.FogUntil or 0) > t then
			boost = boost + (e.FogAmount or 0)
		end
		if (e.HasteUntil or 0) > t then
			boost = boost + e.Def.Haste.Speed
		end
		mult = mult * (1 + boost)
		local def = e.Def
		if e.NextPhase and t >= e.NextPhase then
			e.NextPhase = t + def.Phase.Every
			e.PhasedUntil = t + def.Phase.Duration
			enemyState(e, "Phase", def.Phase.Duration)
		end
		if e.NextShield and t >= e.NextShield then
			e.NextShield = t + def.Shield.Every
			e.ShieldUntil = t + def.Shield.Duration
			enemyState(e, "Shield", def.Shield.Duration)
		end
		if e.NextHaste and t >= e.NextHaste then
			e.NextHaste = t + def.Haste.Every
			e.HasteUntil = t + def.Haste.Duration
			enemyState(e, "Haste", def.Haste.Duration)
		end
		if e.NextFog and t >= e.NextFog then
			-- туман: враги рядом (и сам колдун) ускоряются; одинаковый туман не суммируется
			local fog = def.Fog
			e.NextFog = t + fog.Every
			for _, o in pairs(enemies) do
				if PathUtil.FlatDistance(o.Pos, e.Pos) <= fog.Radius then
					o.FogAmount = math.max((o.FogUntil or 0) > t and o.FogAmount or 0, fog.Speed)
					o.FogUntil = math.max(o.FogUntil or 0, t + fog.Duration)
				end
			end
			Remotes.Impact:FireAllClients({ K = "Fog", P = e.Pos, R = fog.Radius, I = e.Id, DUR = fog.Duration })
		end
		e.Dist = e.Dist + e.Speed * mult * dt
		e.Pos = enemyPos(e)
		if e.NextSummon and t >= e.NextSummon then
			e.NextSummon = t + e.Def.Summon.Interval
			pendingSpawns[#pendingSpawns + 1] = { e.Def.Summon.Enemy, e.Def.Summon.Count, math.max(e.Dist - 3, 0), e.Pos }
		end
		if e.Dist >= PathUtil.Length then
			reached[#reached + 1] = e
		end
	end
	for _, e in ipairs(reached) do
		removeEnemy(e, "core")
		damageCore(e.Def.CoreDamage)
	end
	if #pendingSpawns > 0 then
		local list = pendingSpawns
		pendingSpawns = {}
		for _, s in ipairs(list) do
			Remotes.Impact:FireAllClients({ K = s[5] or "Summon", P = s[4], R = 6 })
			for k = 1, s[2] do
				spawnEnemy(s[1], s[3] - k * 1.5)
			end
		end
	end
end

local function sync(t)
	local list = {}
	for _, e in pairs(enemies) do
		list[#list + 1] = e.Id
		list[#list + 1] = math.floor(e.Dist * 100) / 100
		list[#list + 1] = math.max(0, e.Health)
		list[#list + 1] = ((e.FrozenUntil or 0) > t) and 2 or ((e.SlowUntil > t) and 1 or 0)
	end
	-- союзники: id, дистанция, HP, тип (индекс в Config.AllyOrder), максимум HP
	local al
	if next(allies) or #allyRemoved > 0 then
		al = {}
		for _, a in pairs(allies) do
			al[#al + 1] = a.Id
			al[#al + 1] = math.floor(a.Dist * 100) / 100
			al[#al + 1] = math.floor(a.HP + 0.5)
			al[#al + 1] = allyIndex[a.AllyId] or 1
			al[#al + 1] = a.MaxHP
		end
	end
	Remotes.Sync:FireAllClients({ T = t, E = list, DMG = damageBuffer, RM = removedBuffer, AL = al, RA = #allyRemoved > 0 and allyRemoved or nil })
	damageBuffer = {}
	removedBuffer = {}
	allyRemoved = {}
end

local function step(dt)
	local t = now()
	if phase == "Wave" or phase == "Intermission" or phase == "Prep" then
		updateEnemies(t, dt)
		updateAllies(t, dt)
		updateZones(t)
		updateDots(t)
		updateUnits(t)
	end
	if phase == "Wave" and not waveSpawning and next(enemies) == nil then
		waveCleared()
	elseif phase == "Intermission" and t >= nextWaveAt then
		startWave()
	end
	if t - lastSync >= S.SyncRate then
		lastSync = t
		sync(t)
	end
	if t - lastAttrFlush >= 1 then
		lastAttrFlush = t
		for _, u in pairs(units) do
			u.Folder:SetAttribute("Damage", math.floor(u.DamageDealt))
		end
	end
end

local function clearMatch()
	matchId = matchId + 1
	clearEnemies()
	for _, u in pairs(units) do
		removeUnit(u)
	end
	units = {}
	for _, a in pairs(allies) do
		removeAlly(a, "clear")
	end
	allies = {}
	wave = 0
	waveSpawning = false
	nextWaveAt = 0
	setState("Wave", 0)
	setState("NextWaveAt", 0)
	setState("MatchId", matchId)
end

-- Матч закончен (или все ушли): все возвращаются в лобби
local function setMapMode(mode)
	matchMode = mode
	PathUtil.SetMap(mode)
	maxWave = (Config.Maps[mode] and Config.Maps[mode].MaxWave) or S.MaxWave
	setState("Map", mode)
	setState("MaxWave", maxWave)
end

resetMatch = function()
	local wasHalloween = matchMode == "Halloween"
	clearMatch()
	phase = "Idle"
	setState("Phase", phase)
	setState("Difficulty", "")
	for _, pl in ipairs(Players:GetPlayers()) do
		if inMatch(pl) then
			pl:SetAttribute("InMatch", false)
			setMoney(pl, 0)
			-- чёрный экран-переход, затем телепорт в лобби (после Хэллоуин-матча — на остров)
			Remotes.Notify:FireClient(pl, { Type = "Fade", Text = wasHalloween and "HALLOWEEN" or "ЛОББИ" })
			task.delay(0.45, function()
				toLobby(pl, wasHalloween)
			end)
		end
	end
	roster = {}
	setMapMode("Void")
	notifyAll({ Type = "Reset" })
end

local function startNewMatch(diffKey, mode)
	clearMatch()
	setMapMode(mode or "Void")
	difficultyKey = diffKey
	D = Config.Difficulties[diffKey]
	coreHP = D.CoreHP
	phase = "Prep"
	setState("Difficulty", diffKey)
	setState("CoreMaxHP", coreHP)
	setState("CoreHP", coreHP)
	setState("Phase", phase)
end

function GameService.JoinMatch(player, diffKey)
	if inMatch(player) then
		return false, "Ты уже в матче"
	end
	if phase == "Victory" or phase == "Defeat" then
		return false, "Матч завершается, подожди пару секунд"
	end
	if phase ~= "Idle" and matchMode == "Halloween" then
		return false, "Сейчас идёт Хэллоуин-матч. Подожди, пока он закончится"
	end
	if phase == "Idle" then
		if not Config.Difficulties[diffKey] then
			return false, "Выбери сложность"
		end
		startNewMatch(diffKey)
	end
	player:SetAttribute("InMatch", true)
	-- поздно зашедшим даём компенсацию за пропущенные волны
	setMoney(player, (S.StartMoney + math.max(0, wave - 1) * 150) * D.Money)
	toBattle(player)
	notifyAll({ Type = "Toast", Text = player.DisplayName .. " вступил в бой (" .. D.Name .. ")", Kind = "good" })
	return true, difficultyKey
end

-- Хэллоуин-матч: все игроки из очереди попадают в один матч
function GameService.CanStartHalloween()
	return phase == "Idle"
end

function GameService.StartHalloween(players, diffKey)
	if phase ~= "Idle" then
		return false, "Арена занята — идёт другой матч"
	end
	if not table.find(Config.Halloween.Difficulties, diffKey) then
		return false, "Неверная сложность"
	end
	startNewMatch(diffKey, "Halloween")
	roster = {}
	for _, pl in ipairs(players) do
		if pl.Parent and not inMatch(pl) then
			roster[pl.UserId] = true
			pl:SetAttribute("InMatch", true)
			setMoney(pl, S.StartMoney * D.Money)
			Remotes.Notify:FireClient(pl, { Type = "Fade", Text = "HAUNTED HOLLOW" })
			task.delay(0.45, function()
				toBattle(pl)
			end)
		end
	end
	if #matchPlayers() == 0 then
		resetMatch()
		return false, "Никого нет в очереди"
	end
	notifyAll({ Type = "Toast", Text = "🎃 Хэллоуин-матч начался (" .. D.Name .. ")", Kind = "good" })
	return true
end

function GameService.GetMode()
	return matchMode, phase
end

function GameService.LeaveMatch(player)
	if not inMatch(player) then
		return false, "Ты не в матче"
	end
	for _, u in pairs(units) do
		if u.Owner == player then
			removeUnit(u)
		end
	end
	player:SetAttribute("InMatch", false)
	setMoney(player, 0)
	toLobby(player, matchMode == "Halloween")
	if #matchPlayers() == 0 and phase ~= "Idle" then
		resetMatch()
	end
	return true
end

function GameService.GetMatchInfo()
	return { Phase = phase, Difficulty = difficultyKey, Wave = wave, Players = #matchPlayers(), Mode = matchMode }
end

------------------------------------------------------------------------
-- ИГРОКИ
------------------------------------------------------------------------
function GameService.PlayerAdded(player)
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	local money = Instance.new("IntValue")
	money.Name = "Money"
	money.Parent = ls
	ls.Parent = player
	player:SetAttribute("InMatch", false)
	setMoney(player, 0)
	-- после смерти игрок в матче возвращается на карту, остальные — в лобби
	player.CharacterAdded:Connect(function(char)
		char:WaitForChild("HumanoidRootPart", 5)
		task.wait(0.2)
		if inMatch(player) then
			toBattle(player)
		else
			toLobby(player, player:GetAttribute("Island") == true)
		end
	end)
end

function GameService.PlayerRemoving(player)
	for _, u in pairs(units) do
		if u.Owner == player then
			removeUnit(u)
		end
	end
	player:SetAttribute("InMatch", false)
	task.defer(function()
		if #matchPlayers() == 0 and phase ~= "Idle" then
			resetMatch()
		end
	end)
end

function GameService.GetEnemySnapshot()
	local list = {}
	for _, e in pairs(enemies) do
		list[#list + 1] = { e.Id, e.Type, e.MaxHealth, e.Speed, e.Lateral, e.Dist, e.Health }
	end
	return list
end

function GameService.Init(remotes, state, unitsFolder, map, maps)
	Remotes, State, UnitsFolder, Map = remotes, state, unitsFolder, map
	MapModels = maps or { Void = map }
	MapModels.Void = MapModels.Void or map
	setState("MaxWave", S.MaxWave)
	setState("CoreMaxHP", S.CoreMaxHP)
	setState("CoreHP", S.CoreMaxHP)
	setState("BossId", 0)
	setState("BossName", "")
	resetMatch()
	RunService.Heartbeat:Connect(step)
end

-- Доступ к внутреннему состоянию для автотестов (в игре не используется)
function GameService.Debug()
	return {
		Units = units, Enemies = enemies, Spawn = spawnEnemy, Now = now,
		Allies = function()
			return allies
		end,
		Mode = function()
			return matchMode, roster
		end,
	}
end

return GameService
]======] }
FILES[#FILES + 1] = { "ServerScriptService", { "VoidTDServer", "HalloweenService" }, "ModuleScript", [======[
--!nocheck
-- VOID TD :: HalloweenService
-- Хэллоуин-остров: телепорты через порталы и очередь в Хэллоуин-матч на 4 светящихся квадратах.
-- Встал на квадрат — в очереди. Первый в очереди — хост: выбирает сложность и может ускорить старт.
-- После обратного отсчёта все из очереди попадают в один и тот же матч.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("VoidTD"):WaitForChild("Config"))

local HalloweenService = {}

local GameService, State
local Q = Config.HalloweenIsland.Queue
local queue = {}          -- игроки по порядку входа
local difficulty = "Easy"
local countdownAt = 0     -- серверное время телепорта (0 — отсчёт не идёт)
local leftUntil = {}      -- игрок нажал «Выйти»: не возвращаем в очередь, пока не сойдёт с квадрата

local function now()
	return workspace:GetServerTimeNow()
end

local function queueCenter()
	return Config.HalloweenIsland.Center + Q.Offset
end

-- стоит ли игрок на одном из квадратов
local function onPad(player)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end
	local c = queueCenter()
	local pos = root.Position
	if math.abs(pos.Y - c.Y) > 9 then
		return false
	end
	local half = Q.Pad / 2 + 0.4
	for _, off in ipairs(Q.Pads) do
		local p = c + off
		if math.abs(pos.X - p.X) <= half and math.abs(pos.Z - p.Z) <= half then
			return true
		end
	end
	return false
end

local function publish()
	local names = {}
	for _, pl in ipairs(queue) do
		names[#names + 1] = pl.DisplayName
	end
	State:SetAttribute("HQ_Members", table.concat(names, "\n"))
	State:SetAttribute("HQ_Count", #queue)
	State:SetAttribute("HQ_Host", queue[1] and queue[1].UserId or 0)
	State:SetAttribute("HQ_Diff", difficulty)
	State:SetAttribute("HQ_At", countdownAt)
	State:SetAttribute("HQ_Busy", not GameService.CanStartHalloween())
end

local function remove(player)
	local i = table.find(queue, player)
	if i then
		table.remove(queue, i)
		if i == 1 then
			difficulty = "Easy" -- новый хост выбирает заново
		end
	end
end

local function tick()
	local t = now()
	-- ушедшие с квадратов и вошедшие в матч выбывают
	for i = #queue, 1, -1 do
		local pl = queue[i]
		if not pl.Parent or pl:GetAttribute("InMatch") or not onPad(pl) then
			remove(pl)
		end
	end
	for _, pl in ipairs(Players:GetPlayers()) do
		if #queue >= Q.MaxPlayers then
			break
		end
		if not table.find(queue, pl) and not pl:GetAttribute("InMatch") then
			local standing = onPad(pl)
			if leftUntil[pl] and not standing then
				leftUntil[pl] = nil
			end
			if standing and not leftUntil[pl] then
				queue[#queue + 1] = pl
				GameService.Toast(pl, "Ты в очереди Хэллоуин-матча (" .. #queue .. "/" .. Q.MaxPlayers .. ")", "good")
			end
		end
	end
	if #queue == 0 or not GameService.CanStartHalloween() then
		countdownAt = 0
	elseif countdownAt == 0 then
		countdownAt = t + Q.Countdown
	elseif t >= countdownAt then
		local list = table.clone(queue)
		local diff = difficulty
		queue = {}
		countdownAt = 0
		difficulty = "Easy"
		local ok, err = GameService.StartHalloween(list, diff)
		if not ok then
			for _, pl in ipairs(list) do
				GameService.Toast(pl, err or "Не удалось начать матч")
			end
		end
	end
	publish()
end

------------------------------------------------------------------------
-- ЗАПРОСЫ КЛИЕНТА
------------------------------------------------------------------------
function HalloweenService.SetDifficulty(player, diff)
	if queue[1] ~= player then
		return false, "Сложность выбирает хост (первый в очереди)"
	end
	if not table.find(Config.Halloween.Difficulties, diff) then
		return false, "Неверная сложность"
	end
	difficulty = diff
	publish()
	return true
end

function HalloweenService.StartNow(player)
	if queue[1] ~= player then
		return false, "Начать может только хост"
	end
	if countdownAt == 0 then
		return false, "Арена занята — подожди окончания матча"
	end
	countdownAt = math.min(countdownAt, now() + Q.StartNow)
	publish()
	return true
end

function HalloweenService.Leave(player)
	if not table.find(queue, player) then
		return false, "Ты не в очереди"
	end
	remove(player)
	leftUntil[player] = true
	-- отводим игрока с квадратов
	GameService.Teleport(player, queueCenter() + Vector3.new(0, 0, 16))
	publish()
	return true
end

-- Портал лобби <-> остров. Проверяем, что игрок стоит у портала и не в матче.
function HalloweenService.Teleport(player, where)
	if player:GetAttribute("InMatch") then
		return false, "Сначала выйди из матча"
	end
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then
		return false, "Персонаж не загружен"
	end
	local zone, center
	if where == "Halloween" then
		zone, center = Config.Lobby.Zones.HalloweenPortal, Config.Lobby.Center
	elseif where == "Lobby" then
		zone, center = Config.HalloweenIsland.Zones.ReturnPortal, Config.HalloweenIsland.Center
	else
		return false, "Неверный портал"
	end
	local p = center + zone.Offset
	local d = Vector3.new(root.Position.X - p.X, 0, root.Position.Z - p.Z).Magnitude
	if d > zone.Radius + 8 then
		return false, "Подойди к порталу"
	end
	GameService.ToLobby(player, where == "Halloween")
	return true
end

function HalloweenService.Init(gameService, state)
	GameService, State = gameService, state
	Players.PlayerRemoving:Connect(function(pl)
		remove(pl)
		leftUntil[pl] = nil
	end)
	publish()
	task.spawn(function()
		while true do
			task.wait(0.25)
			local ok, err = pcall(tick)
			if not ok then
				warn("[VOID TD] HalloweenService: " .. tostring(err))
			end
		end
	end)
end

HalloweenService._tick = tick -- для автотестов
HalloweenService._queue = function()
	return queue, difficulty, countdownAt
end

return HalloweenService
]======] }
FILES[#FILES + 1] = { "ServerScriptService", { "VoidTDServer", "HalloweenWorld" }, "ModuleScript", [======[
--!nocheck
-- VOID TD :: HalloweenWorld
-- Хэллоуин-мир из примитивов (без внешних ассетов):
--   • огромный портал HALLOWEEN EVENT в главном лобби;
--   • Хэллоуин-остров: луна, готический замок, кладбище, тыквенные поля, мёртвые деревья, призраки,
--     летучие мыши, вороны, фонари, туман, руны, разрушенные башни, мост, домики; кейс, 4 квадрата
--     входа в бой, доска наград, превью хэллоуинских юнитов и бестиарий;
--   • карта Haunted Hollow: длинная извилистая дорога, кладбище, поля тыкв, готические здания, лес,
--     база игрока (VoidCore) и портал врагов (VoidPortal).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("VoidTD")
local Config = require(Shared:WaitForChild("Config"))
local PathUtil = require(Shared:WaitForChild("PathUtil"))

local HalloweenWorld = {}

local V = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles
local rad = math.rad

local H -- хелперы MapBuilder (part, light, emitter, cylinderY, billboard, statue, calm, zoneCircle)

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

-- палитра: чёрный, тёмно-фиолетовый, оранжевый, бордовый, золото
local C = {
	Black = rgb(14, 10, 16),
	Ground = rgb(34, 26, 36),
	Ground2 = rgb(44, 30, 40),
	Grass = rgb(46, 34, 30),
	GrassP = rgb(42, 24, 54),
	Rock = rgb(30, 24, 32),
	Rock2 = rgb(44, 36, 46),
	Stone = rgb(78, 70, 82),
	Stone2 = rgb(58, 52, 64),
	Road = rgb(64, 54, 58),
	RoadEdge = rgb(44, 36, 42),
	Purple = rgb(70, 30, 110),
	DeepPurple = rgb(36, 18, 56),
	Orange = rgb(255, 130, 30),
	Ember = rgb(255, 90, 20),
	Pumpkin = rgb(220, 110, 30),
	PumpkinD = rgb(170, 70, 20),
	Stem = rgb(60, 70, 30),
	Burgundy = rgb(100, 20, 34),
	Gold = rgb(200, 156, 60),
	Bark = rgb(32, 24, 26),
	Bone = rgb(200, 192, 176),
	Ghost = rgb(220, 225, 255),
	Fog = rgb(150, 140, 170),
	Moon = rgb(255, 214, 150),
	Window = rgb(255, 160, 60),
	Rune = rgb(170, 70, 255),
}

local SMOKE = "rbxasset://textures/particles/smoke_main.dds"

------------------------------------------------------------------------
-- ДЕТАЛИ
------------------------------------------------------------------------
local function block(parent, size, cf, color, mat, props)
	local o = { Size = size, CFrame = cf, Color = color, Material = mat or Enum.Material.Slate }
	if props then
		for k, v in pairs(props) do
			o[k] = v
		end
	end
	return H.part(parent, o)
end

local function neon(parent, size, cf, color, props)
	local o = { CanCollide = false }
	if props then
		for k, v in pairs(props) do
			o[k] = v
		end
	end
	return block(parent, size, cf, color, Enum.Material.Neon, o)
end

local function wedge(parent, size, cf, color, mat, collide)
	return H.part(parent, { Class = "WedgePart", Size = size, CFrame = cf, Color = color, Material = mat or Enum.Material.Slate, CanCollide = collide == true })
end

local function fogEmitter(p, color, rate, size)
	local e = Instance.new("ParticleEmitter")
	e.Name = "Fog"
	e.Texture = SMOKE
	e.Color = ColorSequence.new(color or C.Fog)
	e.LightEmission = 0.1
	e.LightInfluence = 0.6
	e.Rate = rate or 2
	e.Lifetime = NumberRange.new(5, 8)
	e.Speed = NumberRange.new(0.3, 1)
	e.SpreadAngle = Vector2.new(180, 10)
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-10, 10)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size or 6), NumberSequenceKeypoint.new(1, (size or 6) * 1.8) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.75), NumberSequenceKeypoint.new(1, 1) })
	e.Parent = p
	return e
end

-- угловатая тыква: 6 рёбер-долек вокруг оси, хвостик; carved — вырезанное светящееся лицо
local function pumpkin(parent, pos, s, carved, yaw)
	local m = Instance.new("Model")
	m.Name = "Pumpkin"
	m.Parent = parent
	local base = CF(pos + V(0, 0.55 * s, 0)) * ANG(0, yaw or 0, 0)
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2
		block(m, V(0.62 * s, 1.0 * s, 0.62 * s), base * ANG(0, a, 0) * CF(0, 0, -0.38 * s), (i % 2 == 0) and C.Pumpkin or C.PumpkinD, Enum.Material.SmoothPlastic, { CanCollide = false })
	end
	block(m, V(0.18 * s, 0.4 * s, 0.18 * s), base * CF(0, 0.62 * s, 0) * ANG(0, 0, rad(12)), C.Stem, Enum.Material.Wood, { CanCollide = false })
	if carved then
		local f = base * CF(0, 0, -0.72 * s)
		for _, sx in ipairs({ -1, 1 }) do
			neon(m, V(0.2 * s, 0.2 * s, 0.06), f * CF(0.2 * s * sx, 0.15 * s, 0) * ANG(0, 0, rad(45)), C.Orange)
		end
		neon(m, V(0.5 * s, 0.1 * s, 0.06), f * CF(0, -0.2 * s, 0), C.Orange)
		if s >= 1.2 then
			H.light(m:FindFirstChildWhichIsA("BasePart"), C.Orange, 8 * s, 0.8)
		end
	end
	return m
end

local function deadTree(parent, rng, pos, s)
	s = s or 1
	local m = Instance.new("Model")
	m.Name = "DeadTree"
	m.Parent = parent
	local h = rng:NextNumber(9, 14) * s
	local lean = rad(rng:NextNumber(-6, 6))
	local trunk = CF(pos) * ANG(lean, rng:NextNumber(0, 6), lean * 0.5)
	block(m, V(1.4 * s, h, 1.4 * s), trunk * CF(0, h / 2, 0), C.Bark, Enum.Material.Wood)
	block(m, V(2.4 * s, 1.2 * s, 2.4 * s), trunk * CF(0, 0.4 * s, 0) * ANG(0, rad(45), 0), C.Bark, Enum.Material.Wood)
	for i = 1, 4 do
		local a = i / 4 * math.pi * 2 + rng:NextNumber(-0.4, 0.4)
		local y = h * rng:NextNumber(0.5, 0.95)
		local L = rng:NextNumber(3, 5.5) * s
		local br = trunk * CF(0, y, 0) * ANG(0, a, 0) * ANG(0, 0, rad(rng:NextNumber(45, 65)))
		block(m, V(0.5 * s, L, 0.5 * s), br * CF(0, L / 2, 0), C.Bark, Enum.Material.Wood, { CanCollide = false })
		local tw = br * CF(0, L, 0) * ANG(0, 0, rad(-35))
		block(m, V(0.3 * s, L * 0.5, 0.3 * s), tw * CF(0, L * 0.25, 0), C.Bark, Enum.Material.Wood, { CanCollide = false })
	end
	return m
end

local function tombstone(parent, rng, pos, yaw)
	local kind = rng:NextInteger(1, 3)
	local cf = CF(pos) * ANG(rad(rng:NextNumber(-6, 6)), yaw or 0, rad(rng:NextNumber(-8, 8)))
	if kind == 1 then
		block(parent, V(2, 2.6, 0.5), cf * CF(0, 1.3, 0), C.Stone2)
		block(parent, V(1.6, 0.6, 0.5), cf * CF(0, 2.8, 0) * ANG(0, 0, rad(45)), C.Stone2)
	elseif kind == 2 then
		block(parent, V(0.45, 3.2, 0.45), cf * CF(0, 1.6, 0), C.Stone)
		block(parent, V(1.8, 0.45, 0.45), cf * CF(0, 2.3, 0), C.Stone)
	else
		block(parent, V(2.4, 1.6, 0.7), cf * CF(0, 0.8, 0), C.Stone2)
		block(parent, V(2.6, 0.3, 0.9), cf * CF(0, 1.7, 0), C.Stone)
	end
	-- холмик могилы
	block(parent, V(2.2, 0.4, 3.6), cf * CF(0, 0.15, 1.9), C.Grass, Enum.Material.Ground, { CanCollide = false })
end

local function fence(parent, a, b, color)
	local d = b - a
	local n = math.max(1, math.floor(d.Magnitude / 2.2))
	for i = 0, n do
		local p = a + d * (i / n)
		block(parent, V(0.3, 2.6, 0.3), CF(p + V(0, 1.3, 0)), color or C.Black, Enum.Material.Metal)
		wedge(parent, V(0.3, 0.5, 0.3), CF(p + V(0, 2.85, 0)), color or C.Black, Enum.Material.Metal)
	end
	local mid = (a + b) / 2
	local cf = CFrame.lookAt(mid, b)
	block(parent, V(0.18, 0.18, d.Magnitude), cf * CF(0, 2.1, 0), color or C.Black, Enum.Material.Metal)
	block(parent, V(0.18, 0.18, d.Magnitude), cf * CF(0, 0.8, 0), color or C.Black, Enum.Material.Metal)
end

local function lanternPost(parent, pos, h)
	h = h or 7
	block(parent, V(0.5, h, 0.5), CF(pos + V(0, h / 2, 0)), C.Black, Enum.Material.Metal)
	block(parent, V(1.8, 0.3, 0.3), CF(pos + V(0.6, h - 0.3, 0)), C.Black, Enum.Material.Metal)
	local cage = block(parent, V(0.9, 1.1, 0.9), CF(pos + V(1.3, h - 1.2, 0)), C.Black, Enum.Material.Metal, { CanCollide = false, Transparency = 0.2 })
	local flame = neon(parent, V(0.55, 0.7, 0.55), CF(pos + V(1.3, h - 1.2, 0)), C.Orange)
	H.light(flame, C.Orange, 16, 1.4)
	wedge(parent, V(1.1, 0.5, 1.1), CF(pos + V(1.3, h - 0.45, 0)), C.Black, Enum.Material.Metal)
	return cage
end

local function bat(parent, pos, r, speed)
	local m = Instance.new("Model")
	m.Name = "Bat"
	m.Parent = parent
	local body = block(m, V(0.6, 0.5, 0.9), CF(pos + V(r, 0, 0)), C.Black, Enum.Material.SmoothPlastic, { CanCollide = false })
	for _, s in ipairs({ -1, 1 }) do
		wedge(m, V(0.1, 0.6, 1.6), CF(pos + V(r + 0.9 * s, 0.1, 0)) * ANG(0, 0, rad(-70 * s)), C.Black, Enum.Material.SmoothPlastic)
	end
	neon(m, V(0.3, 0.1, 0.05), CF(pos + V(r, 0.08, -0.46)), C.Ember)
	-- летает по кругу вокруг pos (вращается вся модель)
	m.WorldPivot = CF(pos)
	m:SetAttribute("Spin", speed)
	m:SetAttribute("SpinAxis", "Y")
	m:SetAttribute("BobAmp", 0.8)
	m:SetAttribute("BobSpeed", 2.2)
	m.PrimaryPart = body
	return m
end

local function crow(parent, pos, yaw)
	local cf = CF(pos) * ANG(0, yaw or 0, 0)
	block(parent, V(0.5, 0.5, 0.9), cf * CF(0, 0.35, 0), C.Black, Enum.Material.SmoothPlastic, { CanCollide = false })
	block(parent, V(0.4, 0.4, 0.4), cf * CF(0, 0.75, -0.4), C.Black, Enum.Material.SmoothPlastic, { CanCollide = false })
	wedge(parent, V(0.15, 0.15, 0.4), cf * CF(0, 0.7, -0.75) * ANG(rad(90), 0, 0), C.Gold, Enum.Material.SmoothPlastic)
	wedge(parent, V(0.3, 0.12, 0.6), cf * CF(0, 0.3, 0.6) * ANG(rad(180), 0, 0), C.Black, Enum.Material.SmoothPlastic)
end

local function ghost(parent, pos, s)
	s = s or 1
	local m = Instance.new("Model")
	m.Name = "Ghost"
	m.Parent = parent
	local body = block(m, V(2.2 * s, 2.4 * s, 1.8 * s), CF(pos + V(0, 1.6 * s, 0)), C.Ghost, Enum.Material.SmoothPlastic, { CanCollide = false, Transparency = 0.55 })
	block(m, V(1.8 * s, 1.6 * s, 1.6 * s), CF(pos + V(0, 3.4 * s, 0)), C.Ghost, Enum.Material.SmoothPlastic, { CanCollide = false, Transparency = 0.55 })
	for i = -1, 1 do
		wedge(m, V(0.7 * s, 0.9 * s, 1.6 * s), CF(pos + V(i * 0.7 * s, 0.05, 0)) * ANG(0, 0, rad(180)), C.Ghost, Enum.Material.SmoothPlastic).Transparency = 0.55
	end
	for _, sx in ipairs({ -1, 1 }) do
		block(m, V(0.3 * s, 0.45 * s, 0.05), CF(pos + V(0.35 * s * sx, 3.5 * s, -0.81 * s)), C.Black, Enum.Material.SmoothPlastic, { CanCollide = false })
	end
	m.PrimaryPart = body
	m:SetAttribute("BobAmp", 1.2)
	m:SetAttribute("BobSpeed", 1.1)
	return m
end

-- готическая крыша-шпиль из уменьшающихся блоков
local function spire(parent, cf, w, h, color)
	local n = 5
	for i = 0, n - 1 do
		local k = 1 - i / n
		block(parent, V(w * k, h / n, w * k), cf * CF(0, h / n * (i + 0.5), 0) * ANG(0, rad(45 * (i % 2)), 0), color or C.DeepPurple)
	end
	block(parent, V(0.3, h * 0.35, 0.3), cf * CF(0, h + h * 0.17, 0), C.Gold, Enum.Material.Metal, { CanCollide = false })
end

local function tower(parent, base, w, h, ruined, rng)
	block(parent, V(w, h, w), CF(base + V(0, h / 2, 0)), C.Stone2)
	-- окна
	for i = 1, math.floor(h / 7) do
		for k = 0, 3 do
			local cf = CF(base + V(0, i * 7 - 2, 0)) * ANG(0, k * math.pi / 2, 0) * CF(0, 0, -w / 2 - 0.05)
			neon(parent, V(1.1, 2.2, 0.1), cf, C.Window)
			wedge(parent, V(1.1, 0.7, 0.12), cf * CF(0, 1.45, 0), C.Window, Enum.Material.Neon)
		end
	end
	if ruined then
		for i = 1, 5 do
			local a = i / 5 * math.pi * 2
			local hh = rng:NextNumber(1, 4)
			block(parent, V(w * 0.35, hh, w * 0.35), CF(base + V(math.cos(a) * w * 0.35, h + hh / 2, math.sin(a) * w * 0.35)) * ANG(0, a, rad(rng:NextNumber(-10, 10))), C.Stone2)
		end
	else
		block(parent, V(w + 1.2, 1, w + 1.2), CF(base + V(0, h + 0.5, 0)), C.Stone)
		spire(parent, CF(base + V(0, h + 1, 0)), w + 0.4, w * 2.2, C.DeepPurple)
	end
end

local function house(parent, pos, yaw, s)
	s = s or 1
	local cf = CF(pos) * ANG(0, yaw, 0)
	block(parent, V(10 * s, 7 * s, 8 * s), cf * CF(0, 3.5 * s, 0), C.Rock2, Enum.Material.WoodPlanks)
	for _, sx in ipairs({ -1, 1 }) do
		wedge(parent, V(10.6 * s, 4.5 * s, 4.6 * s), cf * CF(0, 9.25 * s, 2.3 * s * sx) * ANG(0, sx == 1 and math.pi or 0, 0), C.Burgundy, Enum.Material.Slate, true)
	end
	block(parent, V(1.2 * s, 4 * s, 1.2 * s), cf * CF(3 * s, 10 * s, 1.5 * s), C.Stone2)
	block(parent, V(2.2 * s, 3.8 * s, 0.2), cf * CF(0, 1.9 * s, -4.05 * s), C.Bark, Enum.Material.Wood)
	for _, sx in ipairs({ -1, 1 }) do
		neon(parent, V(1.6 * s, 1.6 * s, 0.1), cf * CF(3 * s * sx, 4 * s, -4.05 * s), C.Window)
	end
	H.light(block(parent, V(0.5, 0.5, 0.5), cf * CF(0, 4 * s, -5 * s), C.Black, Enum.Material.SmoothPlastic, { Transparency = 1, CanCollide = false }), C.Window, 14, 1)
end

local function runeCircle(parent, pos, r, color)
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		neon(parent, V(0.5, 0.06, 1.4), CF(pos + V(math.cos(a) * r, 0.06, math.sin(a) * r)) * ANG(0, -a, 0), color or C.Rune)
	end
	for i = 0, 2 do
		neon(parent, V(r * 1.6, 0.05, 0.25), CF(pos + V(0, 0.05, 0)) * ANG(0, i * math.pi / 3, 0), color or C.Rune, { Transparency = 0.3 })
	end
end

-- круглый остров со скальным низом
local function islandDisc(parent, center, R, rng, placeable)
	local top = H.cylinderY(parent, "IslandTop", R, 4, center + V(0, -2, 0), C.Ground)
	top:SetAttribute("Placeable", placeable or nil)
	local layers = { { 0.95, 10, -8 }, { 0.78, 14, -19 }, { 0.56, 16, -33 }, { 0.32, 16, -48 }, { 0.14, 14, -62 } }
	for i, l in ipairs(layers) do
		H.cylinderY(parent, "Bedrock" .. i, R * l[1], l[2], center + V(rng:NextNumber(-4, 4), l[3], rng:NextNumber(-4, 4)), (i % 2 == 0) and C.Rock or C.Rock2)
	end
	for i = 0, 23 do
		local a = i / 24 * math.pi * 2
		local s = rng:NextNumber(10, 18)
		block(parent, V(s, rng:NextNumber(5, 8), s), CF(center + V(math.cos(a) * (R - 4), -3.5, math.sin(a) * (R - 4))) * ANG(0, a + rng:NextNumber(-0.3, 0.3), 0), (i % 2 == 0) and C.Rock or C.Rock2)
	end
	local tip = neon(parent, V(8, 18, 8), CF(center + V(0, -76, 0)) * ANG(rad(8), rad(45), 0), C.Ember)
	H.light(tip, C.Orange, 40, 2)
	return top
end

local function patches(parent, center, R, rng, n, placeable)
	for i = 1, n do
		local a, d = rng:NextNumber(0, math.pi * 2), rng:NextNumber(0, R - 14)
		local w, l = rng:NextNumber(10, 26), rng:NextNumber(10, 22)
		local p = block(parent, V(w, 0.2, l), CF(center + V(math.cos(a) * d, 0.02 + i * 0.001, math.sin(a) * d)) * ANG(0, rng:NextNumber(0, 3), 0),
			(i % 3 == 0) and C.GrassP or ((i % 3 == 1) and C.Grass or C.Ground2), Enum.Material.Grass, { CastShadow = false })
		p:SetAttribute("Placeable", placeable or nil)
	end
end

local function surfaceSign(parent, cf, size, title, sub, titleColor, frameColor)
	local sign = block(parent, size, cf, C.Black)
	neon(parent, size + V(1, 1, -size.Z + 0.3), cf * CF(0, 0, size.Z / 2 + 0.1), frameColor or C.Orange)
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Front
	sg.LightInfluence = 0
	sg.PixelsPerStud = 30
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.Parent = sign
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, sub and 0.62 or 1)
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.RichText = true
	t.Text = title
	t.TextColor3 = titleColor or C.Orange
	t.TextStrokeTransparency = 0
	t.Parent = sg
	if sub then
		local st = t:Clone()
		st.Position = UDim2.fromScale(0.04, 0.62)
		st.Size = UDim2.fromScale(0.92, 0.34)
		st.Font = Enum.Font.GothamBold
		st.Text = sub
		st.TextColor3 = rgb(245, 230, 210)
		st.Parent = sg
	end
	return sign
end

------------------------------------------------------------------------
-- ПОРТАЛ HALLOWEEN EVENT В ГЛАВНОМ ЛОББИ
------------------------------------------------------------------------
local function buildLobbyPortal()
	local lobby = workspace:FindFirstChild("VoidTDLobby")
	if not lobby or lobby:FindFirstChild("HalloweenGate") then
		return
	end
	local L = Config.Lobby
	local z = L.Zones.HalloweenPortal
	if not z then
		return
	end
	local m = Instance.new("Model")
	m.Name = "HalloweenGate"
	local zc = L.Center + z.Offset
	local out = V(z.Offset.X, 0, z.Offset.Z).Unit
	local pc = zc + out * 9
	local face = CFrame.lookAt(pc, pc - out)
	local R = 13
	-- готическая арка: камни по окружности + шипы
	for i = 0, 19 do
		local a = i / 20 * math.pi * 2
		local cf = face * CF(math.cos(a) * R, R + 1 + math.sin(a) * R, 0) * ANG(0, 0, a)
		block(m, V(4, 3.4, 3), cf, (i % 2 == 0) and C.Stone2 or C.Black)
		if i % 2 == 0 then
			wedge(m, V(1.2, 2.4, 1.2), cf * CF(1.8, 0, 0) * ANG(0, 0, rad(-90)), C.Black, Enum.Material.Slate)
		end
		if i % 5 == 0 then
			neon(m, V(0.6, 1.4, 0.3), cf * CF(0, 0, -1.6), C.Orange)
		end
	end
	local disc = H.part(m, { Name = "PortalDisc", Shape = Enum.PartType.Cylinder, Size = V(0.4, R * 2 - 3, R * 2 - 3), CFrame = face * CF(0, R + 1, 0) * ANG(0, rad(90), 0), Color = rgb(150, 60, 20), Material = Enum.Material.Neon, Transparency = 0.25, CanCollide = false })
	for i = 0, 2 do
		local sw = neon(m, V(0.7, R * 1.7, 0.6), face * CF(0, R + 1, -0.4) * ANG(0, 0, rad(i * 60)), (i == 1) and C.Purple or C.Orange, { Transparency = 0.35 })
		sw:SetAttribute("Spin", -1.2 - i * 0.3)
		sw:SetAttribute("SpinAxis", "Z")
	end
	H.light(disc, C.Orange, 50, 3)
	H.emitter(disc, C.Orange, { Rate = 26, Size = 0.7, SpeedMin = 2, SpeedMax = 5 })
	fogEmitter(block(m, V(20, 1, 6), face * CF(0, 0.5, 0), C.Stone2), C.Fog, 3, 7)
	-- тыквы и фонари по сторонам
	for _, sx in ipairs({ -1, 1 }) do
		pumpkin(m, (face * CF(sx * 16, 0, 2)).Position, 2.2, true, 0)
		pumpkin(m, (face * CF(sx * 19, 0, -1)).Position, 1.4, true, 0.5)
		lanternPost(m, (face * CF(sx * 12, 0, 5)).Position, 9)
	end
	surfaceSign(m, face * CF(0, R * 2 + 7, 0) * ANG(0, math.pi, 0), V(30, 7, 1), "HALLOWEEN EVENT", "🎃 остров, кейс, боссы и Halloween Coins", C.Orange, C.Orange)
	for i = 1, 3 do
		bat(m, zc + V(0, 22 + i * 3, 0), 8 + i * 3, 0.6 + i * 0.2)
	end
	H.calm(m)
	m.Parent = lobby
end

------------------------------------------------------------------------
-- ХЭЛЛОУИН-ОСТРОВ
------------------------------------------------------------------------
local function buildIsland()
	local existing = workspace:FindFirstChild("VoidTDHalloween")
	if existing then
		return existing
	end
	local I = Config.HalloweenIsland
	local c = I.Center
	local rng = Random.new(1031)
	local m = Instance.new("Model")
	m.Name = "VoidTDHalloween"

	islandDisc(m, c, I.Radius, rng, false)
	patches(m, c, I.Radius, rng, 14, false)

	-- ЛУНА и туман
	local moon = neon(m, V(70, 70, 70), CF(c + V(-40, 150, -330)), C.Moon, { Shape = Enum.PartType.Ball })
	block(m, V(68, 68, 68), CF(c + V(-22, 156, -318)), rgb(20, 12, 28), Enum.Material.SmoothPlastic, { Shape = Enum.PartType.Ball, CanCollide = false, Transparency = 0.25 })
	H.light(moon, C.Moon, 60, 1)
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2
		fogEmitter(block(m, V(30, 1, 30), CF(c + V(math.cos(a) * 55, 0.5, math.sin(a) * 55)), C.Ground, Enum.Material.Slate, { Transparency = 1, CanCollide = false }), C.Fog, 1.5, 9)
	end

	-- ЗАМОК на дальнем краю
	local cz = c + V(0, 0, -90)
	block(m, V(46, 22, 16), CF(cz + V(0, 11, 0)), C.Stone2)
	block(m, V(48, 1.5, 18), CF(cz + V(0, 22.7, 0)), C.Stone)
	for i = -5, 5 do
		block(m, V(2.4, 2.4, 2), CF(cz + V(i * 4.2, 24.6, -8.2)), C.Stone2)
	end
	tower(m, cz + V(0, 0, 2), 12, 36, false, rng)
	tower(m, cz + V(-25, 0, 2), 9, 30, false, rng)
	tower(m, cz + V(25, 0, 2), 9, 30, false, rng)
	for _, sx in ipairs({ -1, 1 }) do
		for k = 0, 3 do
			local cf = CF(cz + V(sx * (6 + k * 4.5), 9, -8.05))
			neon(m, V(1.6, 4, 0.1), cf, C.Window)
			wedge(m, V(1.6, 1.2, 0.12), cf * CF(0, 2.6, 0), C.Window, Enum.Material.Neon)
		end
	end
	-- ворота замка
	block(m, V(8, 11, 0.6), CF(cz + V(0, 5.5, -8.3)), C.Bark, Enum.Material.Wood)
	neon(m, V(1, 1, 0.1), CF(cz + V(0, 7, -8.65)) * ANG(0, 0, rad(45)), C.Orange)
	surfaceSign(m, CF(cz + V(0, 30, -9)) * ANG(0, math.pi, 0), V(26, 6, 1), "HAUNTED HOLLOW", "Хэллоуин-остров VOID TD", C.Orange, C.Burgundy)
	-- разрушенные башни по краям
	tower(m, c + V(-78, 0, -48), 8, 18, true, rng)
	tower(m, c + V(80, 0, -44), 8, 22, true, rng)

	-- ЗОНЫ-КРУГИ
	local zf = Instance.new("Folder")
	zf.Name = "Zones"
	zf.Parent = m
	for key, z in pairs(I.Zones) do
		local sub = z.Case and "500 🎃 Halloween Coins" or nil
		H.zoneCircle(zf, key, z, c + z.Offset, sub, rgb(30, 14, 18))
	end

	-- КЕЙС: проклятый сундук на постаменте за кругом
	do
		local z = I.Zones.Case_Halloween
		local zc = c + z.Offset
		local out = V(z.Offset.X, 0, z.Offset.Z).Unit
		local sp = zc + out * 13
		H.part(m, { Name = "CaseStand", Shape = Enum.PartType.Cylinder, Size = V(2.5, 10, 10), CFrame = CF(sp + V(0, 1.25, 0)) * ANG(0, 0, rad(90)), Color = C.Black, Material = Enum.Material.Slate })
		H.part(m, { Name = "CaseStandRing", Shape = Enum.PartType.Cylinder, Size = V(0.3, 10.4, 10.4), CFrame = CF(sp + V(0, 2.4, 0)) * ANG(0, 0, rad(90)), Color = C.Gold, Material = Enum.Material.Neon, CanCollide = false })
		local okCM, CaseModels = pcall(require, Shared:WaitForChild("CaseModels"))
		if okCM then
			local cm = CaseModels.Build("Halloween").Model
			cm:ScaleTo(1.7)
			cm:PivotTo(CF(sp + V(0, 2.6, 0)) * CFrame.lookAt(Vector3.zero, -out).Rotation)
			cm:SetAttribute("Spin", 0.4)
			cm:SetAttribute("SpinAxis", "Y")
			cm.Parent = m
		end
		local glow = block(m, V(0.5, 0.5, 0.5), CF(sp + V(0, 6, 0)), C.Black, Enum.Material.SmoothPlastic, { Transparency = 1, CanCollide = false })
		H.light(glow, C.Orange, 24, 2)
		H.billboard(m, sp + V(0, 13.5, 0), "HALLOWEEN CASE", "🎃 500 Halloween Coins", C.Orange, 14)
		for i = 0, 5 do
			local a = i / 6 * math.pi * 2
			pumpkin(m, sp + V(math.cos(a) * 7.5, 0, math.sin(a) * 7.5), 1 + (i % 2) * 0.4, i % 2 == 0, a)
		end
	end

	-- ОЧЕРЕДЬ: 4 светящихся квадрата входа в бой
	do
		local Q = I.Queue
		local qc = c + Q.Offset
		block(m, V(30, 0.6, 22), CF(qc + V(0, 0.3, 0)), C.Black)
		for i, off in ipairs(Q.Pads) do
			local p = qc + off
			neon(m, V(Q.Pad + 0.6, 0.65, Q.Pad + 0.6), CF(p + V(0, 0.33, 0)), C.Orange)
			local pad = block(m, V(Q.Pad, 0.7, Q.Pad), CF(p + V(0, 0.36, 0)), rgb(40, 16, 10), Enum.Material.Glass, { Transparency = 0.15 })
			pad.Name = "QueuePad" .. i
			H.light(pad, C.Orange, 14, 1.5)
			H.emitter(pad, C.Orange, { Rate = 10, Size = 0.4, SpeedMin = 2, SpeedMax = 4, Spread = 15, Dir = Enum.NormalId.Top, LifeMin = 1, LifeMax = 2 })
			local beam = neon(m, V(Q.Pad * 0.8, 18, Q.Pad * 0.8), CF(p + V(0, 9, 0)), C.Orange, { Transparency = 0.9 })
			beam.CastShadow = false
		end
		-- арка над входом и вывеска
		for _, sx in ipairs({ -1, 1 }) do
			block(m, V(2.4, 16, 2.4), CF(qc + V(sx * 16, 8, -12)), C.Stone2)
			pumpkin(m, qc + V(sx * 16, 16, -12), 1.6, true, 0)
		end
		block(m, V(34, 2, 2.4), CF(qc + V(0, 15, -12)), C.Stone2)
		surfaceSign(m, CF(qc + V(0, 20, -12)) * ANG(0, math.pi, 0), V(26, 6, 1), "HALLOWEEN TD", "встань на квадрат • до 4 игроков • хост выбирает сложность", C.Orange, C.Orange)
		H.billboard(m, qc + V(0, 7, 0), "ВХОД В БОЙ", "встань на светящийся квадрат", C.Orange, 13)
		-- доска наград
		surfaceSign(m, CF(qc + V(24, 6, 6)) * ANG(0, rad(-90), 0) * ANG(0, math.pi, 0), V(12, 9, 0.8),
			"НАГРАДЫ", "ЛЁГКАЯ — 100 🎃\nСРЕДНЯЯ — 150 🎃\nСЛОЖНАЯ — 250 🎃\nтолько за победу", C.Gold, C.Gold)
		block(m, V(0.8, 2, 0.8), CF(qc + V(24, 1, 6)), C.Black)
	end

	-- ПРЕВЬЮ ХЭЛЛОУИНСКИХ ЮНИТОВ: статуи у круга
	do
		local uz = c + I.Zones.HalloweenUnits.Offset
		local list = { "LanternKing", "HalloweenPuppeteer", "HeadlessExecutioner", "PlagueDoctor", "PhantomKnight" }
		for i, id in ipairs(list) do
			local a = rad(140 + (i - 1) * 25)
			pcall(H.statue, m, id, uz + V(math.cos(a) * 15, 0, math.sin(a) * 15), uz, i == 1 and 4 or 3)
		end
	end

	-- БЕСТИАРИЙ: боссы на постаментах
	do
		local bz = c + I.Zones.Bestiary.Offset
		local okE, EnemyModels = pcall(require, Shared:WaitForChild("EnemyModels"))
		if okE then
			for i, id in ipairs({ "GraveWarden", "FogReaper", "CursedMonarch" }) do
				local pos = bz + V(16, 0, (i - 2) * 12)
				block(m, V(7, 3, 7), CF(pos + V(0, 1.5, 0)), C.Stone2)
				neon(m, V(7.4, 0.25, 7.4), CF(pos + V(0, 2.6, 0)), ({ rgb(90, 220, 120), rgb(255, 205, 70), rgb(255, 90, 80) })[i])
				local ok, rig = pcall(EnemyModels.Build, id)
				if ok and rig then
					local model = rig.Model
					model:ScaleTo(0.75)
					local hip = (rig.HipHeight or 3) * 0.75
					local base = pos + V(0, 3 + hip, 0)
					model:PivotTo(CFrame.lookAt(base, V(bz.X, base.Y, bz.Z)))
					for _, d in ipairs(model:GetDescendants()) do
						if d:IsA("BasePart") then
							d.Anchored = true
							d.CanCollide = false
						end
					end
					model.Name = "Bestiary_" .. id
					model.Parent = m
				end
				H.billboard(m, pos + V(0, 13, 0), Config.Enemies[id].Name, ({ "босс ЛЁГКОЙ", "босс СРЕДНЕЙ", "босс СЛОЖНОЙ" })[i], ({ rgb(90, 220, 120), rgb(255, 205, 70), rgb(255, 90, 80) })[i], 10)
			end
		end
	end

	-- КЛАДБИЩЕ (восток)
	do
		local g = c + V(52, 0, 44)
		for x = 0, 3 do
			for zz = 0, 2 do
				tombstone(m, rng, g + V(x * 6 - 9, 0, zz * 7 - 7), rng:NextNumber(-0.3, 0.3))
			end
		end
		fence(m, g + V(-14, 0, -12), g + V(14, 0, -12))
		fence(m, g + V(14, 0, -12), g + V(14, 0, 14))
		fence(m, g + V(-14, 0, 14), g + V(14, 0, 14))
		crow(m, g + V(14, 2.9, 2), rad(-90))
		crow(m, g + V(-6, 2.9, -12), 0)
		ghost(m, g + V(2, 2, 2), 1.1)
		fogEmitter(block(m, V(26, 1, 24), CF(g + V(0, 0.5, 0)), C.Ground, Enum.Material.Slate, { Transparency = 1, CanCollide = false }), rgb(120, 200, 130), 2, 6)
	end

	-- ТЫКВЕННОЕ ПОЛЕ (юго-запад)
	do
		local f = c + V(-50, 0, 58)
		block(m, V(30, 0.25, 20), CF(f + V(0, 0.12, 0)), rgb(40, 28, 20), Enum.Material.Ground, { CanCollide = false })
		for x = 0, 4 do
			for zz = 0, 3 do
				pumpkin(m, f + V(x * 6 - 12 + rng:NextNumber(-1, 1), 0, zz * 5 - 7.5 + rng:NextNumber(-1, 1)), rng:NextNumber(0.8, 1.5), rng:NextInteger(1, 4) == 1, rng:NextNumber(0, 6))
			end
		end
		-- пугало
		block(m, V(0.5, 8, 0.5), CF(f + V(0, 4, -11)), C.Bark, Enum.Material.Wood)
		block(m, V(6, 0.5, 0.5), CF(f + V(0, 6, -11)), C.Bark, Enum.Material.Wood)
		block(m, V(2.2, 3, 1.2), CF(f + V(0, 5, -11)), rgb(90, 60, 40), Enum.Material.Fabric)
		pumpkin(m, f + V(0, 6.6, -11), 1.5, true, 0)
		crow(m, f + V(2.6, 6.3, -11), 0.4)
	end

	-- ДОМИКИ, МОСТ, ДЕРЕВЬЯ, ФОНАРИ, ПРИЗРАКИ, МЫШИ, РУНЫ
	house(m, c + V(-80, 0, 0), rad(80), 1)
	house(m, c + V(78, 0, 8), rad(-85), 0.9)
	-- мост к маленькому парящему островку с руинами
	do
		local a = c + V(-96, 0, -20)
		local b = a + V(-28, 0, -6)
		local mid = (a + b) / 2
		local cf = CFrame.lookAt(mid, b)
		for i = -6, 6 do
			block(m, V(5, 0.4, 1.8), cf * CF(0, -0.1 + math.abs(i) * 0.08, i * 2.1) , C.Bark, Enum.Material.WoodPlanks)
		end
		for _, sx in ipairs({ -1, 1 }) do
			block(m, V(0.2, 0.2, 28), cf * CF(sx * 2.4, 1.6, 0), C.Bark, Enum.Material.Wood, { CanCollide = false })
		end
		local isl = b + V(-8, 0, -2)
		H.cylinderY(m, "Islet", 12, 4, isl + V(0, -2, 0), C.Ground)
		H.cylinderY(m, "IsletRock", 8, 12, isl + V(0, -10, 0), C.Rock)
		tower(m, isl, 7, 14, true, rng)
		runeCircle(m, isl + V(0, 0, 8), 4, C.Rune)
	end
	local taken = { c + V(0, 0, 70) }
	for _, z in pairs(I.Zones) do
		taken[#taken + 1] = c + z.Offset
	end
	taken[#taken + 1] = c + I.Queue.Offset
	for i = 1, 26 do
		local a = rng:NextNumber(0, math.pi * 2)
		local d = rng:NextNumber(70, I.Radius - 6)
		local p = c + V(math.cos(a) * d, 0, math.sin(a) * d)
		local free = p.Z > c.Z - 70
		for _, t in ipairs(taken) do
			if (V(p.X - t.X, 0, p.Z - t.Z)).Magnitude < 15 then
				free = false
			end
		end
		if free then
			taken[#taken + 1] = p
			deadTree(m, rng, p, rng:NextNumber(0.9, 1.3))
		end
	end
	for i = 0, 9 do
		local a = i / 10 * math.pi * 2 + 0.2
		lanternPost(m, c + V(math.cos(a) * 34, 0, math.sin(a) * 34), 7)
	end
	ghost(m, c + V(-30, 3, -40), 1.3)
	ghost(m, c + V(36, 4, -60), 1)
	ghost(m, c + V(-70, 2, 30), 0.9)
	for i = 1, 6 do
		bat(m, c + V(rng:NextNumber(-60, 60), rng:NextNumber(26, 40), rng:NextNumber(-70, 40)), rng:NextNumber(8, 18), rng:NextNumber(0.5, 1.2))
	end
	runeCircle(m, c + V(0, 0, 18), 8, C.Rune)
	runeCircle(m, c + V(-20, 0, -64), 5, C.Orange)

	-- точка прибытия (не SpawnLocation: игроки появляются в главном лобби)
	block(m, V(10, 1, 10), CF(I.Spawn + V(0, 0.5, 0)), rgb(60, 26, 20))
	H.cylinderY(m, "SpawnGlow", 4.6, 0.08, I.Spawn + V(0, 1.03, 0), C.Orange, Enum.Material.Neon, { CanCollide = false, Transparency = 0.5 })
	-- портал в лобби
	do
		local z = I.Zones.ReturnPortal
		local zc = c + z.Offset
		local face = CFrame.lookAt(zc + V(0, 0, 8), zc)
		for i = 0, 11 do
			local a = i / 12 * math.pi * 2
			block(m, V(2.6, 2.2, 1.8), face * CF(math.cos(a) * 7, 8 + math.sin(a) * 7, 0) * ANG(0, 0, a), (i % 2 == 0) and C.Stone or C.Stone2)
		end
		local disc = H.part(m, { Name = "ReturnDisc", Shape = Enum.PartType.Cylinder, Size = V(0.4, 12, 12), CFrame = face * CF(0, 8, 0) * ANG(0, rad(90), 0), Color = rgb(120, 40, 210), Material = Enum.Material.Neon, Transparency = 0.25, CanCollide = false })
		H.light(disc, rgb(170, 80, 255), 24, 2)
	end

	m.WorldPivot = CF(c)
	H.calm(m)
	m.Parent = workspace
	return m
end

------------------------------------------------------------------------
-- КАРТА HAUNTED HOLLOW
------------------------------------------------------------------------
local function buildMap()
	local existing = workspace:FindFirstChild("VoidTDHalloweenMap")
	if existing then
		return existing
	end
	local MC = Config.Maps.Halloween
	local c = MC.Center
	local GY = MC.GroundY
	local size = MC.IslandSize
	local rng = Random.new(666)
	PathUtil.SetMap("Halloween")
	local m = Instance.new("Model")
	m.Name = "VoidTDHalloweenMap"

	-- земля (на неё можно ставить юнитов)
	local ground = Instance.new("Folder")
	ground.Name = "Ground"
	ground.Parent = m
	local top = block(ground, V(size.X, 4, size.Y), CF(c.X, GY - 2, c.Z), C.Ground)
	top.Name = "IslandTop"
	top:SetAttribute("Placeable", true)
	for i = 1, 22 do
		local w, d = rng:NextNumber(14, 34), rng:NextNumber(14, 30)
		local x = rng:NextNumber(-size.X / 2 + w / 2 + 2, size.X / 2 - w / 2 - 2)
		local z = rng:NextNumber(-size.Y / 2 + d / 2 + 2, size.Y / 2 - d / 2 - 2)
		local p = block(ground, V(w, 0.2, d), CF(c.X + x, GY + 0.02 + i * 0.001, c.Z + z) * ANG(0, rad(rng:NextNumber(-20, 20)), 0),
			(i % 3 == 0) and C.GrassP or ((i % 3 == 1) and C.Grass or C.Ground2), Enum.Material.Grass, { CastShadow = false })
		p:SetAttribute("Placeable", true)
	end
	-- скальный низ
	local under = Instance.new("Folder")
	under.Name = "Underside"
	under.Parent = m
	for i, l in ipairs({ { 0.92, 12, -9 }, { 0.72, 16, -22 }, { 0.5, 18, -38 }, { 0.28, 18, -55 } }) do
		block(under, V(size.X * l[1], l[2], size.Y * l[1]), CF(c.X + rng:NextNumber(-6, 6), GY + l[3], c.Z + rng:NextNumber(-6, 6)) * ANG(0, rad(rng:NextNumber(-8, 8)), 0), (i % 2 == 0) and C.Rock or C.Rock2)
	end
	for x = -size.X / 2, size.X / 2, 18 do
		for _, zs in ipairs({ -1, 1 }) do
			local s = rng:NextNumber(10, 18)
			block(under, V(s, rng:NextNumber(5, 8), s), CF(c.X + x, GY - 3.5, c.Z + zs * size.Y / 2) * ANG(0, rng:NextNumber(0, 2), 0), C.Rock2)
		end
	end
	for z = -size.Y / 2 + 18, size.Y / 2 - 18, 18 do
		for _, xs in ipairs({ -1, 1 }) do
			local s = rng:NextNumber(10, 18)
			block(under, V(s, rng:NextNumber(5, 8), s), CF(c.X + xs * size.X / 2, GY - 3.5, c.Z + z) * ANG(0, rng:NextNumber(0, 2), 0), C.Rock)
		end
	end

	-- ДОРОГА: тёмная брусчатка, оранжевые трещины, фонари по краям
	local road = Instance.new("Folder")
	road.Name = "Path"
	road.Parent = m
	local pts = PathUtil.Points
	local w = MC.PathWidth
	for i = 2, #pts do
		local a, b = pts[i - 1], pts[i]
		local len = (b - a).Magnitude
		local mid = (a + b) / 2
		local cf = CFrame.lookAt(V(mid.X, GY + 0.15, mid.Z), V(b.X, GY + 0.15, b.Z))
		block(road, V(w, 0.3, len + w), cf, C.Road, Enum.Material.Cobblestone).Name = "Road"
		block(road, V(w + 1.6, 0.22, len + w + 1.6), cf * CF(0, -0.06, 0), C.RoadEdge).Name = "RoadEdge"
		if i % 2 == 0 then
			neon(road, V(0.35, 0.05, math.min(len * 0.4, 12)), cf * CF(rng:NextNumber(-2, 2), 0.16, 0) * ANG(0, rad(rng:NextNumber(-25, 25)), 0), C.Ember)
		end
		local steps = math.floor(len / 26)
		local dir = (b - a).Unit
		local right = V(-dir.Z, 0, dir.X)
		for s2 = 1, steps do
			local p = a:Lerp(b, s2 / (steps + 1)) + right * ((s2 % 2 == 0) and 1 or -1) * (w / 2 + 2)
			lanternPost(road, V(p.X, GY, p.Z), 6)
		end
	end

	-- ПОРТАЛ ВРАГОВ (VoidPortal: PortalDisc/PortalCore нужны для вспышки при боссе)
	do
		local pm = Instance.new("Model")
		pm.Name = "VoidPortal"
		pm.Parent = m
		local start = pts[1]
		local dir = (pts[2] - start).Unit
		local R = 10
		local center = start - dir * 4 + V(0, R + 1, 0)
		local face = CFrame.lookAt(center, center + dir)
		for i = 0, 17 do
			local a = i / 18 * math.pi * 2
			local cf = face * CF(math.cos(a) * R, math.sin(a) * R, 0) * ANG(0, 0, a)
			block(pm, V(3.4, 3, 2.6), cf, (i % 2 == 0) and C.Stone2 or C.Black)
			if i % 3 == 0 then
				wedge(pm, V(1, 2.2, 1), cf * CF(1.6, 0, 0) * ANG(0, 0, rad(-90)), C.Bone, Enum.Material.SmoothPlastic)
			end
		end
		local disc = H.part(pm, { Name = "PortalDisc", Shape = Enum.PartType.Cylinder, Size = V(0.4, R * 2 - 2.4, R * 2 - 2.4), CFrame = face * ANG(0, rad(90), 0), Color = rgb(140, 50, 20), Material = Enum.Material.Neon, Transparency = 0.2, CanCollide = false })
		local core = neon(pm, V(2, 2, 2), face * CF(0, 0, -0.3) * ANG(rad(45), rad(45), 0), C.Orange)
		core.Name = "PortalCore"
		H.light(core, C.Orange, 40, 3)
		H.emitter(disc, C.Ember, { Rate = 26, Size = 0.7, SpeedMin = 2, SpeedMax = 5 })
		for i = 0, 2 do
			local sw = neon(pm, V(0.6, R * 1.6, 0.7), face * ANG(0, 0, rad(i * 60)) * CF(0, 0, -0.4), (i == 1) and C.Purple or C.Orange, { Transparency = 0.35 })
			sw:SetAttribute("Spin", -1.4 - i * 0.3)
			sw:SetAttribute("SpinAxis", "Z")
		end
		fogEmitter(disc, C.Fog, 3, 6)
	end

	-- БАЗА ИГРОКА (VoidCore): святилище-фонарь
	do
		local cm = Instance.new("Model")
		cm.Name = "VoidCore"
		cm.Parent = m
		local pos = pts[#pts]
		H.cylinderY(cm, "CoreBase", 9, 1.5, pos + V(0, 0.75, 0), C.Stone2)
		H.cylinderY(cm, "CoreRing", 9.4, 0.4, pos + V(0, 1.6, 0), C.Gold, Enum.Material.Neon, { CanCollide = false })
		for k = 0, 3 do
			local a = k / 4 * math.pi * 2 + rad(45)
			local pp = pos + V(math.cos(a) * 6.5, 0, math.sin(a) * 6.5)
			block(cm, V(1.6, 14, 1.6), CF(pp + V(0, 7, 0)), C.Black, Enum.Material.Metal)
			pumpkin(cm, pp + V(0, 14, 0), 1.3, true, a)
		end
		block(cm, V(10, 1, 10), CF(pos + V(0, 14.5, 0)) * ANG(0, rad(45), 0), C.Black, Enum.Material.Metal)
		spire(cm, CF(pos + V(0, 15, 0)), 9, 9, C.Burgundy)
		local flame = neon(cm, V(4, 6, 4), CF(pos + V(0, 8, 0)) * ANG(0, rad(45), 0), C.Orange, { Transparency = 0.15 })
		flame.Name = "CoreCrystal"
		flame:SetAttribute("Spin", 0.6)
		flame:SetAttribute("SpinAxis", "Y")
		H.light(flame, C.Orange, 40, 3)
		H.emitter(flame, C.Ember, { Rate = 20, Size = 0.6, SpeedMin = 1, SpeedMax = 3, Accel = V(0, 3, 0) })
		cm:SetAttribute("CoreCenter", pos + V(0, 8, 0))
	end

	-- ДЕКОР: кладбище, тыквенные поля, готические здания, лес — только вдали от дороги
	local taken = { pts[1], pts[#pts], MC.BattleSpawn }
	local function free(p, pathDist, sep)
		if PathUtil.DistanceToPath(p) < pathDist then
			return false
		end
		if math.abs(p.X - c.X) > size.X / 2 - 6 or math.abs(p.Z - c.Z) > size.Y / 2 - 6 then
			return false
		end
		for _, t in ipairs(taken) do
			if V(p.X - t.X, 0, p.Z - t.Z).Magnitude < sep then
				return false
			end
		end
		return true
	end
	local function spot(pathDist, sep, tries)
		for _ = 1, tries or 40 do
			local p = V(c.X + rng:NextNumber(-size.X / 2, size.X / 2), GY, c.Z + rng:NextNumber(-size.Y / 2, size.Y / 2))
			if free(p, pathDist, sep) then
				taken[#taken + 1] = p
				return p
			end
		end
	end
	local decor = Instance.new("Folder")
	decor.Name = "Decor"
	decor.Parent = m
	-- кладбище
	for _ = 1, 3 do
		local g = spot(16, 26)
		if g then
			for k = 1, 6 do
				tombstone(decor, rng, g + V(rng:NextNumber(-7, 7), 0, rng:NextNumber(-7, 7)), rng:NextNumber(-0.4, 0.4))
			end
			if rng:NextInteger(1, 2) == 1 then
				crow(decor, g + V(0, 2.9, 0), rng:NextNumber(0, 6))
			end
			fogEmitter(block(decor, V(16, 1, 16), CF(g + V(0, 0.5, 0)), C.Ground, Enum.Material.Slate, { Transparency = 1, CanCollide = false }), rgb(120, 200, 130), 1, 5)
		end
	end
	-- поля тыкв
	for _ = 1, 4 do
		local f = spot(12, 20)
		if f then
			for k = 1, 7 do
				pumpkin(decor, f + V(rng:NextNumber(-6, 6), 0, rng:NextNumber(-6, 6)), rng:NextNumber(0.8, 1.6), rng:NextInteger(1, 3) == 1, rng:NextNumber(0, 6))
			end
		end
	end
	-- готические здания
	for k = 1, 3 do
		local p = spot(22, 34)
		if p then
			if k == 1 then
				tower(decor, p, 10, 26, false, rng)
			elseif k == 2 then
				house(decor, p, rng:NextNumber(0, 6), 1.1)
			else
				tower(decor, p, 8, 16, true, rng)
			end
		end
	end
	-- лес мёртвых деревьев
	for _ = 1, 30 do
		local p = spot(9, 9, 12)
		if p then
			deadTree(decor, rng, p, rng:NextNumber(0.8, 1.3))
		end
	end
	-- призраки, мыши, туман, руны
	for _ = 1, 4 do
		local p = spot(10, 12, 12)
		if p then
			ghost(decor, p + V(0, 3, 0), rng:NextNumber(0.8, 1.2))
		end
	end
	for _ = 1, 6 do
		bat(decor, V(c.X + rng:NextNumber(-110, 110), GY + rng:NextNumber(24, 40), c.Z + rng:NextNumber(-90, 90)), rng:NextNumber(8, 16), rng:NextNumber(0.5, 1.2))
	end
	for i = 0, 5 do
		fogEmitter(block(decor, V(40, 1, 40), CF(c.X + (i % 3 - 1) * 85, GY + 0.5, c.Z + (i < 3 and -50 or 50)), C.Ground, Enum.Material.Slate, { Transparency = 1, CanCollide = false }), C.Fog, 1.2, 9)
	end
	local moon = neon(decor, V(60, 60, 60), CF(c + V(60, 140, -300)), C.Moon, { Shape = Enum.PartType.Ball })
	H.light(moon, C.Moon, 60, 1)

	-- площадка прибытия
	local bs = MC.BattleSpawn
	block(m, V(8, 1, 8), CF(bs.X, GY + 0.5, bs.Z), rgb(60, 26, 20)).Name = "BattlePad"
	neon(m, V(7, 0.05, 7), CF(bs.X, GY + 1.03, bs.Z), C.Orange, { Transparency = 0.6 }).Name = "BattlePadGlow"

	PathUtil.SetMap("Void")
	H.calm(m)
	m.Parent = workspace
	return m
end

function HalloweenWorld.Build(helpers)
	H = helpers
	buildLobbyPortal()
	buildIsland()
	return buildMap()
end

return HalloweenWorld
]======] }
FILES[#FILES + 1] = { "StarterPlayerScripts", { "VoidTDClient" }, "LocalScript", [======[
--!nocheck
-- VOID TD :: Client bootstrap

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

local Shared = ReplicatedStorage:WaitForChild("VoidTD")
local Remotes = Shared:WaitForChild("Remotes")
local State = Shared:WaitForChild("State")
local UnitsFolder = Shared:WaitForChild("Units")

local ctx = {
	Config = require(Shared:WaitForChild("Config")),
	PathUtil = require(Shared:WaitForChild("PathUtil")),
	UnitModels = require(Shared:WaitForChild("UnitModels")),
	EnemyModels = require(Shared:WaitForChild("EnemyModels")),
	CaseModels = require(Shared:WaitForChild("CaseModels")),
	FX = require(script:WaitForChild("FX")),
	HFX = require(script:WaitForChild("HalloweenFX")),
	HalloweenAnims = require(script:WaitForChild("HalloweenAnims")),
	Renderer = require(script:WaitForChild("Renderer")),
	UI = require(script:WaitForChild("UI")),
	Placement = require(script:WaitForChild("Placement")),
	Remotes = Remotes,
	State = State,
	UnitsFolder = UnitsFolder,
	Profile = nil,
}

local UI, Renderer, Placement, FX = ctx.UI, ctx.Renderer, ctx.Placement, ctx.FX
local requestFn = Remotes:WaitForChild("Request")

function ctx.Request(action, data)
	local ok, a, b = pcall(function()
		return requestFn:InvokeServer(action, data)
	end)
	if not ok then
		UI.Toast("Нет связи с сервером", "error")
		return false
	end
	if a == false and b then
		UI.Toast(tostring(b), "error")
	end
	return a, b
end

------------------------------------------------------------------------
-- ОБЛЕГЧЁННАЯ ГРАФИКА
------------------------------------------------------------------------
local Lighting = game:GetService("Lighting")
ctx.Lite = false

local function applyWorldLite(on)
	for _, name in ipairs({ "VoidTDMap", "VoidTDLobby", "VoidTDHalloween", "VoidTDHalloweenMap" }) do
		local root = workspace:FindFirstChild(name)
		if root then
			for _, d in ipairs(root:GetDescendants()) do
				if d:IsA("ParticleEmitter") then
					d.Enabled = not on
				elseif d:IsA("PointLight") then
					-- оставляем только самые яркие источники
					d.Enabled = not on or d.Range >= 30
				end
			end
		end
	end
	-- на клиенте изменения Lighting локальные
	Lighting.GlobalShadows = not on
	local bloom = Lighting:FindFirstChild("VoidBloom")
	if bloom then
		bloom.Enabled = not on
	end
end

function ctx.SetLite(on, save)
	ctx.Lite = on
	ctx.UnitModels.Lite = on
	FX.Lite = on
	applyWorldLite(on)
	Renderer.RebuildUnits()
	UI.SetLiteText(on)
	if save then
		ctx.Request("SetLite", { On = on })
		UI.Toast(on and "Лёгкая графика включена" or "Полная графика включена", "good")
	end
end

FX.Init()
Renderer.Init(ctx)
UI.Init(ctx)
Placement.Init(ctx)

-- профиль
while not player:GetAttribute("VoidReady") do
	task.wait(0.1)
end
local ok, prof = ctx.Request("GetProfile")
if ok and prof then
	UI.SetProfile(prof)
end
-- режим графики: из профиля, иначе на телефонах сразу лёгкий
do
	local saved = prof and prof.Settings and prof.Settings.Lite
	local mobile = UserInputService.TouchEnabled and not UserInputService.MouseEnabled
	local on = (saved == nil and mobile) or saved == true
	task.spawn(function()
		workspace:WaitForChild("VoidTDMap", 20)
		workspace:WaitForChild("VoidTDLobby", 20)
		ctx.SetLite(on, false)
	end)
end
Remotes.Profile.OnClientEvent:Connect(function(p)
	UI.SetProfile(p)
end)

-- враги
Remotes.EnemySpawn.OnClientEvent:Connect(Renderer.SpawnEnemy)
Remotes.Sync.OnClientEvent:Connect(Renderer.OnSync)
Remotes.Attack.OnClientEvent:Connect(Renderer.OnAttack)
Remotes.Impact.OnClientEvent:Connect(Renderer.OnImpact)
Remotes.Notify.OnClientEvent:Connect(function(p)
	UI.OnNotify(p)
	if p.Type == "CoreHit" then
		local map = Renderer.ActiveMap()
		local core = map and map:FindFirstChild("VoidCore")
		local c = core and core:GetAttribute("CoreCenter")
		if c then
			FX.Sphere(c, 6, FX.Colors.Pink, 0.4)
			FX.Burst(c, FX.Colors.Pink, 10, 0.6, 10)
		end
	elseif p.Type == "Reset" then
		Placement.Stop()
	elseif p.Type == "WaveClear" or p.Type == "Victory" then
		Renderer.Cheer()
	end
end)
local okE, list = ctx.Request("GetEnemies")
if okE and list then
	for _, e in ipairs(list) do
		Renderer.SpawnEnemy(e)
	end
end

-- юниты
for _, f in ipairs(UnitsFolder:GetChildren()) do
	Renderer.AddUnit(f)
end
UnitsFolder.ChildAdded:Connect(function(f)
	-- атрибуты приходят вместе с объектом, но подстрахуемся
	task.defer(Renderer.AddUnit, f, true)
end)
UnitsFolder.ChildRemoved:Connect(Renderer.RemoveUnit)

------------------------------------------------------------------------
-- ВВОД
------------------------------------------------------------------------
local hoverHL = Instance.new("Highlight")
hoverHL.FillTransparency = 1
hoverHL.OutlineColor = Color3.fromRGB(220, 160, 255)
hoverHL.OutlineTransparency = 0.1
hoverHL.DepthMode = Enum.HighlightDepthMode.Occluded

local unitParams = RaycastParams.new()
unitParams.FilterType = Enum.RaycastFilterType.Include

local function unitUnder(screenPos, isTouch)
	local cam = workspace.CurrentCamera
	local ray = isTouch and cam:ScreenPointToRay(screenPos.X, screenPos.Y) or cam:ViewportPointToRay(screenPos.X, screenPos.Y)
	unitParams.FilterDescendantsInstances = { Renderer.UnitFolder }
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 600, unitParams)
	if hit then
		local m = hit.Instance:FindFirstAncestorOfClass("Model")
		while m and not m:GetAttribute("Uid") do
			m = m.Parent and m.Parent:FindFirstAncestorOfClass("Model")
		end
		if m then
			return m:GetAttribute("Uid"), m
		end
	end
	return nil
end

local keySlots = {
	[Enum.KeyCode.One] = 1, [Enum.KeyCode.Two] = 2, [Enum.KeyCode.Three] = 3,
	[Enum.KeyCode.Four] = 4, [Enum.KeyCode.Five] = 5, [Enum.KeyCode.Six] = 6,
}

UserInputService.InputBegan:Connect(function(input, gp)
	if gp then
		return
	end
	local t = input.UserInputType
	if t == Enum.UserInputType.Keyboard then
		local k = input.KeyCode
		if keySlots[k] then
			local id = UI.EquippedAt(keySlots[k])
			if id then
				Placement.Start(id)
			end
		elseif k == Enum.KeyCode.Q or k == Enum.KeyCode.Escape then
			if Placement.Active then
				Placement.Stop()
			else
				UI.CloseUnit()
			end
		elseif k == Enum.KeyCode.R and Placement.Active then
			Placement.Rotate()
		elseif k == Enum.KeyCode.E then
			UI.UpgradeSelected()
		elseif k == Enum.KeyCode.X then
			UI.SellSelected()
		elseif k == Enum.KeyCode.T then
			UI.CycleTarget()
		elseif k == Enum.KeyCode.G then
			UI.Toggle("Inventory")
		end
	elseif t == Enum.UserInputType.MouseButton1 then
		if Placement.Active then
			Placement.Confirm()
		else
			local uid = unitUnder(UserInputService:GetMouseLocation(), false)
			if uid then
				UI.OpenUnit(uid)
			else
				UI.CloseUnit()
			end
		end
	elseif t == Enum.UserInputType.MouseButton2 then
		if Placement.Active then
			Placement.Stop()
		end
	elseif t == Enum.UserInputType.Touch then
		local pos = Vector2.new(input.Position.X, input.Position.Y)
		if Placement.Active then
			Placement.SetTouch(pos)
		else
			local uid = unitUnder(pos, true)
			if uid then
				UI.OpenUnit(uid)
			end
		end
	end
end)

------------------------------------------------------------------------
-- ДЕКОР КАРТЫ: вращение и покачивание
------------------------------------------------------------------------
local spinners = {}
local function collectSpinners(map)
	if not map then
		return
	end
	for _, d in ipairs(map:GetDescendants()) do
		if (d:IsA("BasePart") or d:IsA("Model")) and (d:GetAttribute("Spin") or d:GetAttribute("BobAmp")) then
			local base = d:IsA("Model") and d:GetPivot() or d.CFrame
			spinners[#spinners + 1] = {
				Obj = d,
				Base = base,
				Spin = d:GetAttribute("Spin") or 0,
				Axis = d:GetAttribute("SpinAxis") or "Y",
				Bob = d:GetAttribute("BobAmp") or 0,
				BobSpeed = d:GetAttribute("BobSpeed") or 1,
				Phase = math.random() * 6,
			}
		end
	end
end
task.spawn(function()
	local map = workspace:WaitForChild("VoidTDMap", 30)
	local lobby = workspace:WaitForChild("VoidTDLobby", 30)
	task.wait(1)
	collectSpinners(map)
	collectSpinners(lobby)
	collectSpinners(workspace:WaitForChild("VoidTDHalloween", 30))
	collectSpinners(workspace:WaitForChild("VoidTDHalloweenMap", 30))
end)

------------------------------------------------------------------------
-- КАРТА МАТЧА: Void или Haunted Hollow (дорога пересчитывается у всех одинаково)
------------------------------------------------------------------------
local function applyMap()
	local key = State:GetAttribute("Map") or "Void"
	if ctx.PathUtil.MapKey ~= key then
		Renderer.ClearEnemies()
		ctx.HFX.ClearAllies()
		ctx.PathUtil.SetMap(key)
	end
	UI.SetMapMode(key)
end
State:GetAttributeChangedSignal("Map"):Connect(applyMap)
applyMap()

local function updateSpinners(t)
	for _, s in ipairs(spinners) do
		local a = t * s.Spin
		local rot
		if s.Axis == "X" then
			rot = CFrame.Angles(a, 0, 0)
		elseif s.Axis == "Z" then
			rot = CFrame.Angles(0, 0, a)
		else
			rot = CFrame.Angles(0, a, 0)
		end
		local bob = CFrame.new(0, math.sin(t * s.BobSpeed + s.Phase) * s.Bob, 0)
		local cf = bob * s.Base * rot
		if s.Obj:IsA("Model") then
			s.Obj:PivotTo(cf)
		else
			s.Obj.CFrame = cf
		end
	end
end

------------------------------------------------------------------------
-- КРУГИ В ЛОББИ: встал в круг — открылось меню, вышел — закрылось
------------------------------------------------------------------------
local ZONE_MODAL = { Units = "Inventory", Play = "Mode", Bestiary = "Bestiary", HalloweenUnits = "Inventory" }
-- зоны главного лобби и Хэллоуин-острова
local ZONE_SETS = {
	{ Prefix = "", Center = ctx.Config.Lobby.Center, Zones = ctx.Config.Lobby.Zones },
	{ Prefix = "H_", Center = ctx.Config.HalloweenIsland.Center, Zones = ctx.Config.HalloweenIsland.Zones },
}
for _, set in ipairs(ZONE_SETS) do
	for key, z in pairs(set.Zones) do
		if z.Case then
			ZONE_MODAL[set.Prefix .. key] = "Summon"
		elseif ZONE_MODAL[key] then
			ZONE_MODAL[set.Prefix .. key] = ZONE_MODAL[key]
		end
	end
end
local zoneState = {}
local teleportCooldown = 0

local function updateZones()
	if player:GetAttribute("InMatch") then
		if next(zoneState) then
			for key in pairs(zoneState) do
				if ZONE_MODAL[key] then
					UI.Show(ZONE_MODAL[key], false)
				end
			end
			zoneState = {}
		end
		return
	end
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local pos = root.Position
	for _, set in ipairs(ZONE_SETS) do
		for key, z in pairs(set.Zones) do
			local id = set.Prefix .. key
			local c = set.Center + z.Offset
			local flat = Vector3.new(pos.X - c.X, 0, pos.Z - c.Z).Magnitude
			local inside = flat <= z.Radius + 0.5 and math.abs(pos.Y - c.Y) < 8
			if inside ~= (zoneState[id] == true) then
				zoneState[id] = inside or nil
				if z.Teleport then
					-- портал: телепорт на остров / в лобби
					if inside and os.clock() > teleportCooldown then
						teleportCooldown = os.clock() + 2
						FX.Sound("Portal", 1, 1)
						UI.Fade(z.Teleport == "Halloween" and "HALLOWEEN" or "ЛОББИ")
						task.delay(0.35, function()
							ctx.Request("Teleport", { To = z.Teleport })
						end)
					end
				else
					if inside and z.Case then
						UI.SelectCase(z.Case)
					end
					if inside and z.EventUnits then
						UI.SetInventoryFilter(z.EventUnits)
					elseif inside and key == "Units" then
						UI.SetInventoryFilter(nil)
					end
					if ZONE_MODAL[id] then
						UI.Show(ZONE_MODAL[id], inside)
					end
					if inside then
						FX.Sound("Click", 1, 1)
					end
				end
			end
		end
	end
	UI.UpdateQueue()
end

------------------------------------------------------------------------
-- ГЛАВНЫЙ ЦИКЛ
------------------------------------------------------------------------
local hoverTimer = 0
RunService.RenderStepped:Connect(function(dt)
	local t = os.clock()
	Renderer.Update(dt)
	UI.Update(dt)
	updateSpinners(t)
	updateZones()
	hoverTimer = hoverTimer + dt
	if hoverTimer > 0.05 then
		hoverTimer = 0
		if Placement.Active or not UserInputService.MouseEnabled then
			hoverHL.Parent = nil
		else
			local _, model = unitUnder(UserInputService:GetMouseLocation(), false)
			if model then
				hoverHL.Adornee = model
				hoverHL.Parent = model
			else
				hoverHL.Parent = nil
			end
		end
	end
end)

UI.Toast("Добро пожаловать в VOID TD! Встань в круг ИГРАТЬ, чтобы начать бой", "good")
]======] }
FILES[#FILES + 1] = { "StarterPlayerScripts", { "VoidTDClient", "FX" }, "ModuleScript", [======[
--!nocheck
-- VOID TD :: FX (клиент)
-- Все визуальные эффекты способностей. Урон считается на сервере, тут только картинка.

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local FX = {}
FX.Lite = false -- облегчённый режим: меньше частиц и обломков

local V = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles
local rad = math.rad

local NEON = Color3.fromRGB(180, 80, 255)
local NEON_SOFT = Color3.fromRGB(215, 160, 255)
local NEON_PINK = Color3.fromRGB(255, 60, 170)
local WHITE = Color3.fromRGB(250, 245, 255)
FX.Colors = { Neon = NEON, Soft = NEON_SOFT, Pink = NEON_PINK, White = WHITE }

local folder
local rng = Random.new()
local numberCount = 0

------------------------------------------------------------------------
-- ЗВУКИ (встроенные звуки клиента Roblox, без загрузки ассетов)
------------------------------------------------------------------------
local SoundService = game:GetService("SoundService")
local SoundConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("VoidTD"):WaitForChild("Config")).Sounds
local lastSound = {}

-- Играет звук события из Config.Sounds. volume/pitch — множители (по умолчанию 1).
-- Если у события указан Custom ("rbxassetid://..."), играет свой звук, иначе встроенный.
function FX.Sound(name, volume, pitch, pos)
	local def = SoundConfig[name]
	if not def then
		return
	end
	local t = os.clock()
	if lastSound[name] and t - lastSound[name] < 0.07 then
		return
	end
	volume = (volume or 1) * (def.Volume or 0.4)
	-- приглушаем далёкие звуки
	if pos then
		local cam = workspace.CurrentCamera
		local d = cam and (cam.CFrame.Position - pos).Magnitude or 0
		if d > 140 then
			return
		end
		volume = volume * math.clamp(1 - d / 140, 0.15, 1)
	end
	lastSound[name] = t
	local custom = def.Custom and def.Custom ~= ""
	local s = Instance.new("Sound")
	s.SoundId = custom and def.Custom or def.Id
	s.Volume = volume
	s.PlaybackSpeed = (pitch or 1) * (custom and 1 or (def.Pitch or 1))
	s.Parent = SoundService
	s:Play()
	task.delay(4, function()
		s:Destroy()
	end)
end

------------------------------------------------------------------------
-- ТРЯСКА КАМЕРЫ
------------------------------------------------------------------------
local shakeUntil, shakeDur, shakeMag = 0, 1, 0

function FX.Shake(magnitude, duration)
	local t = os.clock()
	if t + duration > shakeUntil or magnitude > shakeMag then
		shakeUntil = t + duration
		shakeDur = duration
		shakeMag = magnitude
	end
end

function FX.Init()
	folder = workspace:FindFirstChild("VoidTD_FX") or Instance.new("Folder")
	folder.Name = "VoidTD_FX"
	folder.Parent = workspace
	RunService:BindToRenderStep("VoidTD_Shake", Enum.RenderPriority.Camera.Value + 1, function()
		local t = os.clock()
		if t < shakeUntil then
			local k = (shakeUntil - t) / shakeDur * shakeMag
			local cam = workspace.CurrentCamera
			cam.CFrame = cam.CFrame * CFrame.new(rng:NextNumber(-k, k), rng:NextNumber(-k, k), 0) * CFrame.Angles(0, 0, rng:NextNumber(-k, k) * 0.03)
		end
	end)
end

local function tween(obj, time, goal, style, dir)
	local t = TweenService:Create(obj, TweenInfo.new(time, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), goal)
	t:Play()
	return t
end
FX.Tween = tween

function FX.Part(props)
	local p = Instance.new(props.Class or "Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = props.Material or Enum.Material.Neon
	p.Color = props.Color or NEON
	p.Size = props.Size or V(1, 1, 1)
	if props.Shape then
		p.Shape = props.Shape
	end
	p.Transparency = props.Transparency or 0
	p.CFrame = props.CFrame or CF()
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = props.Parent or folder
	return p
end

local function cleanup(obj, t)
	task.delay(t, function()
		if obj then
			obj:Destroy()
		end
	end)
end

local function light(parent, color, range, brightness, life)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Shadows = false
	l.Parent = parent
	if life then
		tween(l, life, { Brightness = 0 })
	end
	return l
end

------------------------------------------------------------------------
-- БАЗОВЫЕ ЭФФЕКТЫ
------------------------------------------------------------------------
function FX.Burst(pos, color, count, size, speed, life)
	count = count or 8
	if FX.Lite then
		count = math.min(math.ceil(count / 3), 4)
	end
	size = size or 0.4
	speed = speed or 6
	life = life or 0.45
	for _ = 1, count do
		local dir = V(rng:NextNumber(-1, 1), rng:NextNumber(-0.2, 1), rng:NextNumber(-1, 1)).Unit
		local p = FX.Part({
			Size = V(size, size, size),
			CFrame = CF(pos) * ANG(rng:NextNumber(0, 6), rng:NextNumber(0, 6), 0),
			Color = color or NEON,
		})
		tween(p, life, {
			CFrame = CF(pos + dir * speed * life) * ANG(rng:NextNumber(0, 6), rng:NextNumber(0, 6), 0),
			Transparency = 1,
			Size = V(0.05, 0.05, 0.05),
		})
		cleanup(p, life + 0.05)
	end
end

-- Плоское кольцо, расширяющееся по земле
function FX.Ring(pos, radius, color, life, height, startRadius, transparency)
	life = life or 0.5
	height = height or 0.3
	local r0 = startRadius or 0.5
	local p = FX.Part({
		Shape = Enum.PartType.Cylinder,
		Size = V(height, r0 * 2, r0 * 2),
		CFrame = CF(pos) * ANG(0, 0, rad(90)),
		Color = color or NEON,
		Transparency = transparency or 0.15,
	})
	tween(p, life, { Size = V(height * 0.4, radius * 2, radius * 2), Transparency = 1 })
	cleanup(p, life + 0.05)
	return p
end

function FX.Sphere(pos, radius, color, life, material, startT)
	local p = FX.Part({
		Shape = Enum.PartType.Ball,
		Size = V(0.5, 0.5, 0.5),
		CFrame = CF(pos),
		Color = color or NEON,
		Material = material or Enum.Material.Neon,
		Transparency = startT or 0.1,
	})
	tween(p, life, { Size = V(radius * 2, radius * 2, radius * 2), Transparency = 1 })
	cleanup(p, life + 0.05)
	return p
end

-- Дуга из сегментов (след от оружия)
function FX.Arc(cf, radius, a0, a1, color, thickness, life, horizontal)
	local segs = 9
	thickness = thickness or 0.35
	life = life or 0.35
	local prev
	for i = 0, segs do
		local a = a0 + (a1 - a0) * (i / segs)
		local pt
		if horizontal then
			pt = (cf * CF(math.sin(a) * radius, 0, -math.cos(a) * radius)).Position
		else
			pt = (cf * CF(0, math.cos(a) * radius, -math.sin(a) * radius)).Position
		end
		if prev then
			local len = (pt - prev).Magnitude
			local w = thickness * (0.35 + 0.65 * math.sin(math.pi * i / segs))
			local p = FX.Part({
				Size = V(w, w * 0.5, len + w),
				CFrame = CFrame.lookAt((pt + prev) / 2, pt),
				Color = color or NEON,
				Transparency = 0.05,
			})
			local delay = i / segs * 0.06
			task.delay(delay, function()
				tween(p, life, { Transparency = 1, Size = V(w * 0.2, w * 0.1, len) })
			end)
			cleanup(p, life + delay + 0.05)
		end
		prev = pt
	end
end

-- Вертикальная полоса-разрез (для катаны / императора)
function FX.SlashMark(pos, angle, length, width, color, life)
	life = life or 0.35
	local cf = CF(pos) * ANG(0, rng:NextNumber(0, math.pi), 0) * ANG(0, 0, angle)
	local p = FX.Part({ Size = V(width, length * 0.3, 0.12), CFrame = cf, Color = color or NEON })
	local core = FX.Part({ Size = V(width * 0.35, length * 0.3, 0.14), CFrame = cf, Color = WHITE })
	tween(p, life * 0.35, { Size = V(width, length, 0.12) }, Enum.EasingStyle.Back)
	tween(core, life * 0.35, { Size = V(width * 0.35, length, 0.14) }, Enum.EasingStyle.Back)
	task.delay(life * 0.35, function()
		tween(p, life * 0.65, { Transparency = 1, Size = V(0.05, length * 1.1, 0.05) })
		tween(core, life * 0.65, { Transparency = 1, Size = V(0.02, length * 1.1, 0.02) })
	end)
	cleanup(p, life + 0.05)
	cleanup(core, life + 0.05)
end

function FX.Cracks(pos, radius, color, count, life)
	if FX.Lite then
		return
	end
	count = count or 8
	life = life or 1.4
	for i = 1, count do
		local a = (i / count) * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
		local len = radius * rng:NextNumber(0.5, 0.95)
		local dir = V(math.cos(a), 0, math.sin(a))
		local mid = pos + dir * (len / 2 + 0.6)
		local p = FX.Part({
			Size = V(rng:NextNumber(0.25, 0.5), 0.08, len),
			CFrame = CFrame.lookAt(mid, mid + dir) * ANG(0, rng:NextNumber(-0.15, 0.15), 0),
			Color = color or NEON,
		})
		-- маленькое ответвление
		local bdir = (dir + V(-dir.Z, 0, dir.X) * rng:NextNumber(-0.8, 0.8)).Unit
		local bmid = pos + dir * len * 0.6 + bdir * len * 0.2
		local b = FX.Part({ Size = V(0.2, 0.08, len * 0.4), CFrame = CFrame.lookAt(bmid, bmid + bdir), Color = color or NEON })
		task.delay(life * 0.5, function()
			tween(p, life * 0.5, { Transparency = 1 })
			tween(b, life * 0.5, { Transparency = 1 })
		end)
		cleanup(p, life + 0.05)
		cleanup(b, life + 0.05)
	end
	local scorch = FX.Part({
		Shape = Enum.PartType.Cylinder,
		Size = V(0.06, radius * 0.9, radius * 0.9),
		CFrame = CF(pos) * ANG(0, 0, rad(90)),
		Color = Color3.fromRGB(10, 5, 15),
		Material = Enum.Material.SmoothPlastic,
		Transparency = 0.3,
	})
	tween(scorch, life, { Transparency = 1 })
	cleanup(scorch, life + 0.05)
end

------------------------------------------------------------------------
-- СНАРЯДЫ И ЛУЧИ
------------------------------------------------------------------------
-- getTarget() -> Vector3 | nil (текущая позиция цели)
function FX.Projectile(kind, from, getTarget, travel, onHit, lv)
	lv = lv or 1
	local p, trailColor
	local maker = FX.ProjectileMakers and FX.ProjectileMakers[kind]
	if maker then
		p, trailColor = maker(lv)
	elseif kind == "Arrow" then
		p = FX.Part({ Size = V(0.18, 0.18, 2.2), Color = lv >= 4 and NEON or NEON_SOFT })
		local tipP = FX.Part({ Size = V(0.35, 0.35, 0.35), Color = NEON, Parent = p })
		tipP.Name = "Tip"
	elseif kind == "Orb" then
		local s = 0.7 + lv * 0.1
		p = FX.Part({ Shape = Enum.PartType.Ball, Size = V(s, s, s), Color = NEON })
		light(p, NEON, 8, 2)
	elseif kind == "Crystal" then
		p = FX.Part({ Size = V(0.4, 0.4, 1.3), Color = Color3.fromRGB(110, 190, 255) })
		light(p, Color3.fromRGB(80, 170, 255), 7, 2)
	elseif kind == "Bullet" then
		p = FX.Part({ Size = V(0.15, 0.15, 0.9), Color = Color3.fromRGB(255, 90, 80) })
	elseif kind == "Moon" then
		p = FX.Part({ Size = V(0.2, 1.2, 1.2), Shape = Enum.PartType.Cylinder, Color = Color3.fromRGB(255, 200, 215) })
		light(p, Color3.fromRGB(255, 120, 150), 8, 2)
	else
		p = FX.Part({ Size = V(0.25, 0.25, 1.4 + lv * 0.15), Color = lv >= 5 and NEON_PINK or NEON_SOFT })
	end
	local a0 = Instance.new("Attachment")
	a0.Position = V(0, 0.12, 0)
	a0.Parent = p
	local a1 = Instance.new("Attachment")
	a1.Position = V(0, -0.12, 0)
	a1.Parent = p
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Color = ColorSequence.new(trailColor or (kind == "Orb" and NEON or NEON_SOFT))
	trail.LightEmission = 1
	trail.Lifetime = 0.18
	trail.Transparency = NumberSequence.new(0.2, 1)
	trail.WidthScale = NumberSequence.new(kind == "Orb" and 3 or 1, 0)
	trail.Parent = p

	local start = os.clock()
	local last = getTarget() or from
	if (last - from).Magnitude > 0.01 then
		p.CFrame = CFrame.lookAt(from, last)
	else
		p.CFrame = CF(from)
	end
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local alpha = math.clamp((os.clock() - start) / math.max(travel, 0.01), 0, 1)
		local target = getTarget() or last
		last = target
		local pos = from:Lerp(target, alpha)
		if kind == "Arrow" then
			pos = pos + V(0, math.sin(alpha * math.pi) * 1.2, 0)
		end
		if (target - pos).Magnitude > 0.01 then
			p.CFrame = CFrame.lookAt(pos, target)
		else
			p.CFrame = CF(pos)
		end
		if p:FindFirstChild("Tip") then
			p.Tip.CFrame = p.CFrame * CF(0, 0, -1.1)
		end
		if alpha >= 1 then
			conn:Disconnect()
			if onHit then
				onHit(target)
			end
			p:Destroy()
		end
	end)
end

function FX.Beam(from, to, width, color, life, big)
	life = life or 0.45
	local len = (to - from).Magnitude
	local cf = CFrame.lookAt((from + to) / 2, to)
	local outer = FX.Part({ Shape = Enum.PartType.Cylinder, Size = V(len, width * 0.2, width * 0.2), CFrame = cf * ANG(0, rad(90), 0), Color = color or NEON, Transparency = 0.15 })
	local inner = FX.Part({ Shape = Enum.PartType.Cylinder, Size = V(len, width * 0.1, width * 0.1), CFrame = cf * ANG(0, rad(90), 0), Color = WHITE })
	tween(outer, 0.1, { Size = V(len, width, width) }, Enum.EasingStyle.Back)
	tween(inner, 0.1, { Size = V(len, width * 0.45, width * 0.45) }, Enum.EasingStyle.Back)
	light(inner, color or NEON, 16, 4, life)
	task.delay(0.12, function()
		tween(outer, life, { Size = V(len, 0.05, 0.05), Transparency = 1 })
		tween(inner, life, { Size = V(len, 0.02, 0.02), Transparency = 1 })
	end)
	cleanup(outer, life + 0.2)
	cleanup(inner, life + 0.2)
	-- кольца вдоль луча
	local rings = FX.Lite and 1 or (big and 6 or 3)
	for i = 1, rings do
		local pt = from:Lerp(to, i / (rings + 1))
		local ring = FX.Part({ Shape = Enum.PartType.Cylinder, Size = V(0.15, width * 1.6, width * 1.6), CFrame = CFrame.lookAt(pt, to) * ANG(0, rad(90), 0), Color = color or NEON, Transparency = 0.3 })
		tween(ring, life, { Size = V(0.05, width * 3.5, width * 3.5), Transparency = 1 })
		cleanup(ring, life + 0.05)
	end
	FX.Sphere(to, width * 1.8, color or NEON, 0.35)
	FX.Burst(to, color or NEON, big and 16 or 8, 0.5, 10)
	FX.Sphere(from, width, WHITE, 0.25)
end

------------------------------------------------------------------------
-- СПОСОБНОСТИ
------------------------------------------------------------------------
-- ECLIPSE SHOCKWAVE
function FX.Shockwave(pos, radius, lv, color, soft)
	local NEON = color or NEON
	local NEON_SOFT = soft or NEON_SOFT
	local g = V(pos.X, pos.Y + 0.2, pos.Z)
	FX.Sound("Explosion", 1, 1, pos)
	local cam = workspace.CurrentCamera
	if cam and (cam.CFrame.Position - pos).Magnitude < 70 then
		FX.Shake(lv >= 5 and 0.5 or 0.25, 0.35)
	end
	FX.Ring(g, radius, NEON, 0.55, 0.5, 1, 0.05)
	FX.Ring(g + V(0, 0.15, 0), radius * 0.75, WHITE, 0.4, 0.3, 0.5, 0.2)
	task.delay(0.08, function()
		FX.Ring(g + V(0, 0.1, 0), radius * 1.05, NEON_SOFT, 0.6, 0.25, radius * 0.4, 0.4)
	end)
	FX.Cracks(g, radius, NEON, 6 + lv * 2, 1.4)
	-- пыль/осколки
	for _ = 1, FX.Lite and 0 or (6 + lv) do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(1, radius * 0.8)
		local p = g + V(math.cos(a) * r, 0, math.sin(a) * r)
		local rock = FX.Part({ Size = V(0.6, 0.6, 0.6), CFrame = CF(p), Color = Color3.fromRGB(50, 44, 60), Material = Enum.Material.Slate })
		tween(rock, 0.25, { CFrame = CF(p + V(0, rng:NextNumber(1.5, 3), 0)) * ANG(1, 2, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		task.delay(0.25, function()
			tween(rock, 0.3, { CFrame = CF(p) * ANG(2, 1, 1), Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		end)
		cleanup(rock, 0.6)
	end
	local flash = FX.Part({ Size = V(0.2, 0.2, 0.2), CFrame = CF(g + V(0, 2, 0)), Transparency = 1 })
	light(flash, NEON, radius * 2.5, 5, 0.6)
	cleanup(flash, 0.7)
	if lv >= 5 then
		-- большой фиолетовый взрыв
		FX.Sphere(g, radius * 0.7, NEON, 0.6)
		FX.Sphere(g, radius * 0.45, WHITE, 0.4)
		local pillar = FX.Part({ Shape = Enum.PartType.Cylinder, Size = V(18, 3, 3), CFrame = CF(g + V(0, 9, 0)) * ANG(0, 0, rad(90)), Color = NEON, Transparency = 0.2 })
		tween(pillar, 0.6, { Size = V(26, 0.2, 0.2), Transparency = 1 })
		cleanup(pillar, 0.7)
		FX.Burst(g + V(0, 1, 0), NEON_SOFT, 20, 0.6, 16, 0.6)
	end
end

-- Удар косы: горизонтальная дуга + область
function FX.Reap(unitPos, center, radius, lv, color)
	local NEON = color or NEON
	local dir = (center - unitPos)
	dir = V(dir.X, 0, dir.Z)
	if dir.Magnitude < 0.1 then
		dir = V(0, 0, -1)
	end
	local cf = CFrame.lookAt(V(center.X, center.Y + 1.5, center.Z) - dir.Unit * 1.5, V(center.X, center.Y + 1.5, center.Z) + dir.Unit)
	FX.Arc(cf, radius * 0.9, rad(-80), rad(80), NEON, 0.6 + lv * 0.08, 0.4, true)
	FX.Arc(cf * CF(0, -0.4, 0), radius * 0.75, rad(-70), rad(70), Color3.fromRGB(30, 10, 50), 0.5, 0.45, true)
	FX.Ring(V(center.X, center.Y + 0.15, center.Z), radius, Color3.fromRGB(90, 30, 150), 0.4, 0.2, radius * 0.3, 0.45)
	if lv >= 4 then
		FX.Burst(center + V(0, 1, 0), NEON, 10, 0.4, 8)
	end
end

-- VOID JUDGEMENT: энергетический разрез по врагу
function FX.Judgement(pos, lv, hitIndex)
	FX.Sound("Magic", 1, 0.9 + (hitIndex or 1) * 0.08, pos)
	local color = (hitIndex or 1) % 2 == 0 and NEON or NEON_PINK
	local p = pos + V(0, 2, 0)
	FX.SlashMark(p, rad(35 + rng:NextNumber(-10, 10)), 9 + lv, 0.7 + lv * 0.08, color, 0.45)
	if lv >= 3 then
		FX.SlashMark(p, rad(-35 + rng:NextNumber(-10, 10)), 8 + lv, 0.6, NEON, 0.4)
	end
	-- луч с неба
	local beam = FX.Part({ Shape = Enum.PartType.Cylinder, Size = V(30, 1.4, 1.4), CFrame = CF(pos + V(0, 15, 0)) * ANG(0, 0, rad(90)), Color = color, Transparency = 0.3 })
	tween(beam, 0.35, { Size = V(30, 0.1, 0.1), Transparency = 1 })
	cleanup(beam, 0.4)
	FX.Burst(p, color, 8, 0.45, 9)
	FX.Ring(V(pos.X, pos.Y + 0.15, pos.Z), 3 + lv * 0.4, color, 0.4, 0.25)
end

-- BLACK HOLE
function FX.BlackHole(pos, radius, duration, lv, delay)
	task.delay(delay or 0, function()
		FX.Sound("Portal", 1, 1, pos)
		local center = pos + V(0, 2.2, 0)
		local m = Instance.new("Model")
		m.Name = "BlackHole"
		m.Parent = folder
		local core = FX.Part({ Shape = Enum.PartType.Ball, Size = V(0.5, 0.5, 0.5), CFrame = CF(center), Color = Color3.fromRGB(0, 0, 0), Material = Enum.Material.SmoothPlastic, Parent = m })
		local glow = FX.Part({ Shape = Enum.PartType.Ball, Size = V(0.6, 0.6, 0.6), CFrame = CF(center), Color = NEON, Transparency = 0.55, Parent = m })
		local disk = FX.Part({ Shape = Enum.PartType.Cylinder, Size = V(0.15, 1, 1), CFrame = CF(pos + V(0, 0.2, 0)) * ANG(0, 0, rad(90)), Color = Color3.fromRGB(60, 20, 100), Transparency = 0.35, Parent = m })
		local edge = FX.Part({ Shape = Enum.PartType.Cylinder, Size = V(0.1, 1, 1), CFrame = CF(pos + V(0, 0.25, 0)) * ANG(0, 0, rad(90)), Color = NEON, Transparency = 0.5, Parent = m })
		light(glow, NEON, radius * 2.5, 3)
		local coreSize = 2.2 + lv * 0.35
		tween(core, 0.4, { Size = V(coreSize, coreSize, coreSize) }, Enum.EasingStyle.Back)
		tween(glow, 0.4, { Size = V(coreSize * 1.5, coreSize * 1.5, coreSize * 1.5) }, Enum.EasingStyle.Back)
		tween(disk, 0.4, { Size = V(0.15, radius * 2, radius * 2) })
		tween(edge, 0.4, { Size = V(0.1, radius * 2 + 0.6, radius * 2 + 0.6) })
		-- закручивающиеся рукава
		local arms = {}
		for i = 1, FX.Lite and 2 or (4 + (lv >= 5 and 2 or 0)) do
			arms[i] = FX.Part({ Size = V(0.35, 0.2, radius * 0.9), Color = (i % 2 == 0) and NEON or NEON_SOFT, Transparency = 0.2, Parent = m })
		end
		local emitter = Instance.new("ParticleEmitter")
		emitter.Color = ColorSequence.new(NEON)
		emitter.LightEmission = 1
		emitter.Rate = 30 + lv * 8
		emitter.Lifetime = NumberRange.new(0.5, 0.8)
		emitter.Speed = NumberRange.new(-radius * 1.6, -radius * 1.2)
		emitter.SpreadAngle = Vector2.new(180, 180)
		emitter.Size = NumberSequence.new(0.5, 0)
		emitter.Parent = glow
		local start = os.clock()
		local conn
		conn = RunService.RenderStepped:Connect(function()
			local t = os.clock() - start
			if t > duration then
				conn:Disconnect()
				return
			end
			for i, a in ipairs(arms) do
				local ang = t * 4 + i / #arms * math.pi * 2
				local r = radius * 0.55
				local p = center + V(math.cos(ang) * r, -1.6 + math.sin(t * 3 + i) * 0.3, math.sin(ang) * r)
				a.CFrame = CFrame.lookAt(p, center + V(0, -1.6, 0)) * ANG(0, rad(70), 0)
			end
			local pulse = 1 + math.sin(t * 8) * 0.06
			glow.Size = V(coreSize * 1.5, coreSize * 1.5, coreSize * 1.5) * pulse
		end)
		task.delay(duration, function()
			emitter.Enabled = false
			for _, d in ipairs(m:GetChildren()) do
				if d:IsA("BasePart") then
					tween(d, 0.35, { Size = V(0.05, 0.05, 0.05), Transparency = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
				end
			end
			task.delay(0.3, function()
				FX.Sphere(center, radius * 0.6, NEON, 0.35)
			end)
			cleanup(m, 0.8)
		end)
	end)
end

function FX.Summon(pos, radius)
	FX.Ring(V(pos.X, pos.Y + 0.2, pos.Z), radius or 6, NEON, 0.6, 0.4)
	FX.Burst(pos + V(0, 1, 0), NEON, 12, 0.5, 8)
end

function FX.Poof(pos, color, size)
	size = size or 1
	FX.Sphere(pos, 1.5 * size, color or NEON, 0.35)
	FX.Burst(pos, color or NEON, math.floor(6 + size * 4), 0.35 * size, 6 * size, 0.5)
end

function FX.LevelUp(pos, color)
	FX.Sound("Upgrade", 1, 1, pos)
	FX.Ring(pos + V(0, 0.2, 0), 4, color or NEON, 0.6, 0.3)
	local col = FX.Part({ Shape = Enum.PartType.Cylinder, Size = V(0.2, 3, 3), CFrame = CF(pos + V(0, 0.3, 0)) * ANG(0, 0, rad(90)), Color = color or NEON, Transparency = 0.2 })
	tween(col, 0.7, { CFrame = CF(pos + V(0, 7, 0)) * ANG(0, 0, rad(90)), Transparency = 1, Size = V(0.1, 4.5, 4.5) })
	cleanup(col, 0.75)
	FX.Burst(pos + V(0, 3, 0), color or NEON_SOFT, 14, 0.35, 7, 0.7)
end

function FX.Place(pos)
	FX.Sound("Place", 1, 1, pos)
	FX.Ring(pos + V(0, 0.2, 0), 3.5, NEON_SOFT, 0.45, 0.25)
	FX.Burst(pos + V(0, 0.5, 0), Color3.fromRGB(70, 60, 80), 8, 0.4, 5)
end

------------------------------------------------------------------------
-- ЦИФРЫ УРОНА
------------------------------------------------------------------------
function FX.DamageNumber(pos, amount, flag)
	if numberCount > (FX.Lite and 20 or 70) then
		return
	end
	numberCount = numberCount + 1
	local anchor = FX.Part({ Size = V(0.1, 0.1, 0.1), CFrame = CF(pos), Transparency = 1 })
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(120, 40)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 220
	gui.StudsOffsetWorldSpace = V(rng:NextNumber(-0.8, 0.8), 0, rng:NextNumber(-0.8, 0.8))
	gui.Parent = anchor
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = Color3.fromRGB(20, 0, 30)
	if flag == 2 then
		label.Text = "PHASE"
		label.TextColor3 = Color3.fromRGB(170, 170, 200)
		gui.Size = UDim2.fromOffset(80, 26)
	elseif flag == 1 then
		label.Text = tostring(amount) .. "!"
		label.TextColor3 = Color3.fromRGB(255, 210, 70)
		gui.Size = UDim2.fromOffset(150, 50)
	else
		label.Text = tostring(amount)
		label.TextColor3 = Color3.fromRGB(240, 220, 255)
		gui.Size = UDim2.fromOffset(90, 30)
	end
	label.Parent = gui
	tween(gui, 0.8, { StudsOffsetWorldSpace = gui.StudsOffsetWorldSpace + V(0, 2.5, 0) })
	task.delay(0.35, function()
		tween(label, 0.45, { TextTransparency = 1, TextStrokeTransparency = 1 })
	end)
	task.delay(0.85, function()
		numberCount = numberCount - 1
		anchor:Destroy()
	end)
end

------------------------------------------------------------------------
-- ЭФФЕКТЫ НОВЫХ ЮНИТОВ
------------------------------------------------------------------------
local RED = Color3.fromRGB(255, 35, 55)
local GOLD = Color3.fromRGB(255, 205, 80)
local BLUE = Color3.fromRGB(90, 180, 255)
FX.Colors.Red, FX.Colors.Gold, FX.Colors.Blue = RED, GOLD, BLUE

-- нить кукловода от руки к цели
function FX.Thread(from, to, color)
	local len = (to - from).Magnitude
	if len < 0.1 then
		return
	end
	local p = FX.Part({ Size = V(0.08, 0.08, len), CFrame = CFrame.lookAt((from + to) / 2, to), Color = color or NEON_SOFT })
	tween(p, 0.5, { Transparency = 1, Size = V(0.02, 0.02, len) })
	cleanup(p, 0.55)
	FX.Ring(to - V(0, 1, 0), 2, color or NEON, 0.35, 0.2)
end

-- взрыв кристалла
function FX.CrystalBurst(pos, radius)
	FX.Sphere(pos, radius * 0.6, BLUE, 0.3)
	FX.Ring(V(pos.X, pos.Y + 0.2, pos.Z), radius, Color3.fromRGB(170, 225, 255), 0.35, 0.25)
	FX.Burst(pos + V(0, 1, 0), BLUE, 8, 0.35, 8)
	FX.Sound("Explosion", 0.5, 1.6, pos)
end

-- падающий звёздный осколок
function FX.FallingShard(pos, radius, color)
	color = color or GOLD
	local top = pos + V(rng:NextNumber(-3, 3), 22, rng:NextNumber(-3, 3))
	local shard = FX.Part({ Size = V(0.7, 2.2, 0.7), CFrame = CF(top) * ANG(0, rng:NextNumber(0, 6), rad(15)), Color = color })
	tween(shard, 0.28, { CFrame = CF(pos + V(0, 1, 0)) * ANG(0, 2, rad(15)) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	task.delay(0.28, function()
		shard:Destroy()
		FX.Ring(V(pos.X, pos.Y + 0.2, pos.Z), radius, color, 0.35, 0.3)
		FX.Sphere(pos + V(0, 0.5, 0), radius * 0.4, Color3.fromRGB(255, 240, 200), 0.25)
		FX.Burst(pos + V(0, 1, 0), color, 6, 0.4, 8)
	end)
end

-- маленький портал с разрезом (RIFT STORM)
function FX.RiftPortal(pos, lv)
	local c = pos + V(0, 3.5, 0)
	local ring = FX.Part({ Shape = Enum.PartType.Cylinder, Size = V(0.2, 0.5, 0.5), CFrame = CF(c) * ANG(0, rng:NextNumber(0, 6), 0), Color = NEON })
	tween(ring, 0.15, { Size = V(0.2, 3.2, 3.2) }, Enum.EasingStyle.Back)
	local core = FX.Part({ Shape = Enum.PartType.Cylinder, Size = V(0.25, 0.3, 0.3), CFrame = ring.CFrame, Color = Color3.fromRGB(15, 0, 30) })
	tween(core, 0.15, { Size = V(0.25, 2.4, 2.4) }, Enum.EasingStyle.Back)
	task.delay(0.15, function()
		FX.SlashMark(pos + V(0, 1.5, 0), rad(rng:NextNumber(-50, 50)), 6 + lv * 0.5, 0.5, NEON_PINK, 0.3)
		FX.Burst(pos + V(0, 1, 0), NEON, 6, 0.35, 7)
		tween(ring, 0.25, { Size = V(0.1, 0.2, 0.2), Transparency = 1 })
		tween(core, 0.25, { Size = V(0.1, 0.1, 0.1), Transparency = 1 })
	end)
	cleanup(ring, 0.45)
	cleanup(core, 0.45)
	FX.Sound("Portal", 0.5, 1.4, pos)
end

-- большой центральный разлом
function FX.BigRift(pos, radius)
	local g = V(pos.X, pos.Y + 0.2, pos.Z)
	local disk = FX.Part({ Shape = Enum.PartType.Cylinder, Size = V(0.2, 1, 1), CFrame = CF(g) * ANG(0, 0, rad(90)), Color = Color3.fromRGB(15, 0, 30) })
	tween(disk, 0.25, { Size = V(0.2, radius * 2, radius * 2) }, Enum.EasingStyle.Back)
	FX.Ring(g, radius * 1.1, NEON, 0.6, 0.5, 1, 0.05)
	FX.Ring(g + V(0, 0.1, 0), radius * 0.8, NEON_PINK, 0.5, 0.3, 0.5)
	for i = 1, 4 do
		task.delay(i * 0.05, function()
			FX.SlashMark(g + V(rng:NextNumber(-radius / 2, radius / 2), 2, rng:NextNumber(-radius / 2, radius / 2)), rad(rng:NextNumber(-60, 60)), 9, 0.7, NEON, 0.4)
		end)
	end
	task.delay(0.35, function()
		tween(disk, 0.35, { Size = V(0.1, 0.5, 0.5), Transparency = 1 })
	end)
	cleanup(disk, 0.8)
	FX.Shake(0.4, 0.4)
	FX.Sound("Explosion", 1, 0.7, pos)
end

-- RED SPLASH: расширяющаяся красная волна, вспышка и осколки из меча
function FX.RedSplash(pos, radius, from)
	local g = V(pos.X, pos.Y + 0.2, pos.Z)
	FX.Ring(g, radius, RED, 0.5, 0.5, 1, 0.05)
	FX.Ring(g + V(0, 0.12, 0), radius * 0.7, Color3.fromRGB(255, 150, 150), 0.35, 0.25, 0.5, 0.2)
	local flash = FX.Part({ Shape = Enum.PartType.Cylinder, Size = V(0.08, radius * 1.6, radius * 1.6), CFrame = CF(g + V(0, 0.05, 0)) * ANG(0, 0, rad(90)), Color = RED, Transparency = 0.3 })
	tween(flash, 0.3, { Transparency = 1 })
	cleanup(flash, 0.35)
	FX.Sphere(pos + V(0, 1, 0), 2.5, RED, 0.25)
	if from then
		for _ = 1, FX.Lite and 2 or 6 do
			local to = g + V(rng:NextNumber(-radius, radius) * 0.7, 0.5, rng:NextNumber(-radius, radius) * 0.7)
			local shard = FX.Part({ Size = V(0.25, 0.25, 1.1), CFrame = CFrame.lookAt(from, to), Color = RED })
			tween(shard, 0.25, { CFrame = CFrame.lookAt(to, to + (to - from)), Transparency = 0.6 })
			cleanup(shard, 0.27)
		end
	end
	FX.Cracks(g, radius * 0.8, RED, 6, 0.9)
	FX.Sound("HeavyHit", 1, 0.9, pos)
end

-- рассекающий удар топора
function FX.Cleave(unitPos, center, radius, color)
	FX.Reap(unitPos, center, radius, 4, color or RED)
	FX.Ring(V(center.X, center.Y + 0.2, center.Z), radius, color or RED, 0.4, 0.3)
	FX.Sound("HeavyHit", 1, 1, center)
end

-- молот Starbreaker
function FX.Hammer(pos, radius, lv)
	FX.Shockwave(pos, radius, lv, GOLD, Color3.fromRGB(200, 140, 255))
end

-- кровавая луна падает с неба и взрывается
function FX.BloodMoonFall(pos, radius, delay)
	delay = delay or 1
	local moon = FX.Part({ Shape = Enum.PartType.Ball, Size = V(5, 5, 5), CFrame = CF(pos + V(0, 45, 0)), Color = RED })
	light(moon, RED, 40, 4)
	local mark = FX.Part({ Shape = Enum.PartType.Cylinder, Size = V(0.1, radius * 2, radius * 2), CFrame = CF(pos + V(0, 0.25, 0)) * ANG(0, 0, rad(90)), Color = RED, Transparency = 0.75 })
	tween(moon, delay, { CFrame = CF(pos + V(0, 2, 0)), Size = V(7, 7, 7) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	tween(mark, delay, { Transparency = 0.4 })
	task.delay(delay, function()
		moon:Destroy()
		mark:Destroy()
	end)
	FX.Sound("Boss", 0.6, 1.4, pos)
end

function FX.BloodMoonBoom(pos, radius)
	FX.Shockwave(pos, radius, 5, RED, Color3.fromRGB(255, 140, 140))
	FX.Sphere(pos + V(0, 2, 0), radius * 0.6, Color3.fromRGB(120, 0, 15), 0.6, Enum.Material.Neon, 0.3)
	FX.Shake(0.6, 0.6)
end

-- пробивающий лунный луч
function FX.PierceBeam(from, to)
	FX.Beam(from + V(0, 3, 0), to + V(0, 1.5, 0), 2.2, Color3.fromRGB(255, 190, 215), 0.45, true)
	FX.Sound("Laser", 1, 1.2, from)
end


------------------------------------------------------------------------
-- ПРОКЛЯТЫЙ ЧАСОВЩИК: эффекты времени (золото, бронза, оранжевые искры)
------------------------------------------------------------------------
local CGOLD = Color3.fromRGB(230, 178, 74)
local BRONZE = Color3.fromRGB(170, 112, 52)
local ORANGE = Color3.fromRGB(255, 140, 40)
local DIAL = Color3.fromRGB(16, 12, 20)
FX.Colors.Orange = ORANGE

-- Набор деталей, двигающихся как одно целое: { part, offset }
local function rigidSet()
	return { list = {} }
end

local function addRigid(set, props, offset)
	local p = FX.Part(props)
	set.list[#set.list + 1] = { p, offset or CF() }
	return p
end

local function placeRigid(set, cf)
	for _, it in ipairs(set.list) do
		it[1].CFrame = cf * it[2]
	end
end

local function fadeRigid(set, time)
	for _, it in ipairs(set.list) do
		tween(it[1], time, { Transparency = 1 })
		cleanup(it[1], time + 0.05)
	end
end

-- Шестерня в плоскости XY: восьмиугольник из 4 брусков + 8 зубьев + ступица
local function addGear(set, a, depth, color, hubColor, base)
	base = base or CF()
	for k = 0, 3 do
		addRigid(set, { Size = V(2 * a, 0.83 * a, depth), Color = color, Material = Enum.Material.Metal }, base * ANG(0, 0, k * math.pi / 4))
	end
	if not FX.Lite then
		for k = 0, 7 do
			local ang = k * math.pi / 4
			addRigid(set, { Size = V(a * 0.36, a * 0.34, depth), Color = color, Material = Enum.Material.Metal }, base * CF(math.cos(ang) * a * 1.08, math.sin(ang) * a * 1.08, 0) * ANG(0, 0, ang))
		end
	end
	addRigid(set, { Size = V(a * 0.45, a * 0.45, depth + 0.05), Color = hubColor or ORANGE }, base * ANG(0, 0, math.pi / 4))
end

-- Циферблат в плоскости XY (рама, тёмный диск, деления). Возвращает детали стрелок (двигаются отдельно).
local function addDial(set, a, depth, transparency)
	for k = 0, 3 do
		addRigid(set, { Size = V(2 * a, 0.83 * a, depth), Color = CGOLD, Material = Enum.Material.Metal, Transparency = transparency or 0 }, ANG(0, 0, k * math.pi / 4))
		addRigid(set, { Size = V(1.68 * a, 0.7 * a, depth + 0.04), Color = DIAL, Material = Enum.Material.SmoothPlastic, Transparency = transparency or 0 }, ANG(0, 0, k * math.pi / 4))
	end
	for k = 0, 11 do
		local ang = k * math.pi / 6
		addRigid(set, { Size = V(a * 0.06, a * (k % 3 == 0 and 0.2 or 0.11), depth + 0.08), Color = CGOLD }, CF(math.cos(ang) * a * 0.68, math.sin(ang) * a * 0.68, 0) * ANG(0, 0, ang + math.pi / 2))
	end
end

-- Стрелки часов: две детали, поворачиваются вокруг центра циферблата (cf) на угол
local function makeHands(a, color)
	local h = FX.Part({ Size = V(a * 0.1, a * 0.45, 0.08), Color = color or CGOLD })
	local m = FX.Part({ Size = V(a * 0.06, a * 0.7, 0.08), Color = color or CGOLD })
	return h, m
end

local function placeHands(h, m, cf, ha, ma, a, depth)
	h.CFrame = cf * ANG(0, 0, ha) * CF(0, a * 0.2, -depth / 2 - 0.08)
	m.CFrame = cf * ANG(0, 0, ma) * CF(0, a * 0.32, -depth / 2 - 0.1)
end

local function camFacing(pos)
	local cam = workspace.CurrentCamera
	local c = cam and cam.CFrame.Position or (pos + V(0, 10, 20))
	local flat = V(c.X, pos.Y, c.Z)
	if (flat - pos).Magnitude < 0.1 then
		return CF(pos)
	end
	-- лицевая сторона (-Z) смотрит на камеру
	return CFrame.lookAt(pos, flat)
end

-- Разрез секунд: вращающийся зубчатый диск летит по прямой
function FX.GearDisc(from, to, duration, lv, storm)
	local set = rigidSet()
	local a = 0.75 + (lv or 1) * 0.08
	addGear(set, a, 0.18, storm and ORANGE or CGOLD, storm and Color3.fromRGB(255, 230, 160) or ORANGE)
	local core = set.list[#set.list][1]
	light(core, ORANGE, 8, storm and 3 or 1.5)
	local dir = to - from
	local flat = V(dir.X, 0, dir.Z)
	local base = flat.Magnitude > 0.01 and CFrame.lookAt(V(), flat).Rotation or CF()
	local start = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local el = os.clock() - start
		local alpha = math.clamp(el / math.max(duration, 0.05), 0, 1)
		local pos = from:Lerp(to, alpha)
		placeRigid(set, CF(pos) * base * ANG(rad(90), 0, 0) * ANG(0, 0, el * 16))
		if alpha >= 1 then
			conn:Disconnect()
			fadeRigid(set, 0.2)
		end
	end)
	FX.Sound("Slash", 0.8, 1.4, from)
end

-- Попадание диском: золотые искры, шестерёнки, призрачные стрелки, оранжевая вспышка
function FX.ChronoHit(pos)
	FX.Burst(pos, CGOLD, 5, 0.22, 6, 0.35)
	FX.Burst(pos, BRONZE, 3, 0.3, 4, 0.45)
	FX.Sphere(pos, 1.0, ORANGE, 0.18, nil, 0.3)
	if not FX.Lite then
		local cf = camFacing(pos + V(0, 1.2, 0))
		local h, m = makeHands(1.2, Color3.fromRGB(255, 220, 150))
		h.Transparency, m.Transparency = 0.3, 0.3
		placeHands(h, m, cf, 0, 0, 1.2, 0)
		tween(h, 0.4, { CFrame = cf * ANG(0, 0, -2.5) * CF(0, 0.24, -0.1), Transparency = 1 })
		tween(m, 0.4, { CFrame = cf * ANG(0, 0, 2.8) * CF(0, 0.38, -0.12), Transparency = 1 })
		cleanup(h, 0.45)
		cleanup(m, 0.45)
	end
end

-- Маленькие часы над точкой (на время dur): стрелки крутятся со скоростью speed
local function tinyClock(pos, a, dur, speed)
	local set = rigidSet()
	addDial(set, a, 0.12)
	local h, m = makeHands(a)
	local cf = camFacing(pos)
	placeRigid(set, cf)
	local start = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local el = os.clock() - start
		placeHands(h, m, cf, -el * speed * 0.2, -el * speed, a, 0.12)
		if el >= dur then
			conn:Disconnect()
			fadeRigid(set, 0.25)
			for _, p in ipairs({ h, m }) do
				tween(p, 0.25, { Transparency = 1 })
				cleanup(p, 0.3)
			end
		end
	end)
end
FX.TinyClock = tinyClock

-- ПОЛОМКА ВРЕМЕНИ: огромный циферблат под врагами, стрелки резко останавливаются, всё замирает
function FX.TimeBreak(pos, radius, dur)
	local g = V(pos.X, pos.Y + 0.25, pos.Z)
	FX.Sound("Magic", 1, 0.55, pos)
	-- циферблат на дороге
	local floor = rigidSet()
	addDial(floor, radius, 0.12, 0.25)
	placeRigid(floor, CF(g) * ANG(rad(-90), 0, 0))
	local fh, fm = makeHands(radius)
	-- огромные часы над дорогой
	local sky = rigidSet()
	local skyA = radius * 0.45
	addDial(sky, skyA, 0.3)
	local skyCF = camFacing(g + V(0, radius * 0.9 + 3, 0))
	placeRigid(sky, skyCF)
	local sh, sm = makeHands(skyA)
	-- механические кольца и зависшие в воздухе частицы
	local rings = {}
	if not FX.Lite then
		for i = 1, 2 do
			local set = rigidSet()
			local rr = radius * (0.7 + i * 0.12)
			for k = 0, 15 do
				if k % 4 ~= 3 then
					local ang = k / 16 * math.pi * 2
					addRigid(set, { Size = V(2 * math.pi * rr / 16 * 1.05, 0.12, 0.2), Color = CGOLD, Material = Enum.Material.Metal }, CF(math.cos(ang) * rr, 0, math.sin(ang) * rr) * ANG(0, -ang - math.pi / 2, 0))
				end
			end
			rings[i] = { set, i * 0.9 }
		end
		for _ = 1, 10 do
			local ang = rng:NextNumber(0, math.pi * 2)
			local d = rng:NextNumber(0, radius * 0.9)
			local p = FX.Part({ Size = V(0.25, 0.25, 0.25), CFrame = CF(g + V(math.cos(ang) * d, rng:NextNumber(0.6, 3), math.sin(ang) * d)) * ANG(1, 2, 0), Color = rng:NextNumber() < 0.5 and CGOLD or ORANGE, Transparency = 0.15 })
			task.delay(dur, function()
				tween(p, 0.35, { CFrame = p.CFrame + V(0, -1.5, 0), Transparency = 1 })
			end)
			cleanup(p, dur + 0.4)
		end
	end
	local start = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local el = os.clock() - start
		-- первые 0.45 с стрелки бешено крутятся, затем резко останавливаются
		local spin = math.min(el, 0.45)
		local ha, ma = -spin * 14, -spin * 40
		placeHands(fh, fm, CF(g) * ANG(rad(-90), 0, 0), ha, ma, radius, 0.12)
		placeHands(sh, sm, skyCF, ha * 0.8, ma * 0.8, skyA, 0.3)
		for _, rg in ipairs(rings) do
			placeRigid(rg[1], CF(g + V(0, rg[2], 0)) * ANG(0, spin * 3 * (rg[2] > 1 and -1 or 1), 0))
		end
		if el >= dur then
			conn:Disconnect()
			-- время пошло: оранжевая вспышка и осколки шестерёнок
			FX.Sound("Explosion", 0.6, 1.4, pos)
			FX.Sphere(g + V(0, 1, 0), radius * 0.55, ORANGE, 0.35, nil, 0.3)
			FX.Ring(g, radius * 1.1, ORANGE, 0.45, 0.3, radius * 0.5, 0.2)
			FX.Burst(g + V(0, 1, 0), CGOLD, 12, 0.35, 10, 0.6)
			FX.Burst(g + V(0, 1, 0), BRONZE, 8, 0.4, 7, 0.6)
			fadeRigid(floor, 0.35)
			fadeRigid(sky, 0.35)
			for _, rg in ipairs(rings) do
				fadeRigid(rg[1], 0.3)
			end
			for _, p in ipairs({ fh, fm, sh, sm }) do
				tween(p, 0.3, { Transparency = 1 })
				cleanup(p, 0.35)
			end
		end
	end)
end

-- УСКОРЕНИЕ ВРЕМЕНИ: золотое кольцо от часовщика и маленькие часы над союзниками
function FX.TimeHaste(pos, radius, allyPositions, dur)
	local g = V(pos.X, pos.Y + 0.25, pos.Z)
	FX.Sound("Upgrade", 0.9, 1.35, pos)
	FX.Ring(g, radius, CGOLD, 0.8, 0.4, 1, 0.1)
	task.delay(0.12, function()
		FX.Ring(g + V(0, 0.1, 0), radius * 0.8, ORANGE, 0.7, 0.25, 1, 0.3)
	end)
	FX.Burst(g + V(0, 2, 0), CGOLD, 10, 0.3, 8, 0.6)
	for _, ap in ipairs(allyPositions) do
		tinyClock(ap + V(0, 7, 0), 0.7, dur, 18)
		FX.Ring(ap + V(0, 0.3, 0), 2.5, CGOLD, 0.4, 0.2, 0.5, 0.2)
	end
end

-- ВРЕМЕННАЯ БУРЯ: огромное механическое кольцо и удар по земле
function FX.TimeStorm(pos, delay)
	local g = V(pos.X, pos.Y + 0.25, pos.Z)
	FX.Sound("Magic", 1, 0.45, pos)
	local set = rigidSet()
	local rr = 6.5
	for k = 0, (FX.Lite and 7 or 15) do
		local n = FX.Lite and 8 or 16
		local ang = k / n * math.pi * 2
		addRigid(set, { Size = V(2 * math.pi * rr / n * 1.02, 0.5, 0.3), Color = CGOLD, Material = Enum.Material.Metal }, CF(math.cos(ang) * rr, 0, math.sin(ang) * rr) * ANG(0, -ang - math.pi / 2, 0))
		if k % 2 == 0 and not FX.Lite then
			addRigid(set, { Size = V(0.4, 0.8, 0.4), Color = ORANGE }, CF(math.cos(ang) * rr, 0.5, math.sin(ang) * rr) * ANG(0, -ang, math.pi / 4))
		end
	end
	local start = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local el = os.clock() - start
		local rise = math.min(el / (delay or 1.2), 1)
		placeRigid(set, CF(g + V(0, 0.5 + rise * 2, 0)) * ANG(0, el * 2.5 * (0.3 + rise), 0))
		if el >= (delay or 1.2) then
			conn:Disconnect()
			fadeRigid(set, 0.4)
			FX.Shockwave(g, 9, 3, CGOLD, ORANGE)
			FX.Sphere(g + V(0, 2, 0), 4, ORANGE, 0.45, nil, 0.25)
		end
	end)
end

-- Удар во время бури: механический взрыв, золотой круг на дороге, часы над целью
function FX.ChronoBurst(pos, radius)
	local g = V(pos.X, pos.Y + 0.2, pos.Z)
	FX.Ring(g, radius, CGOLD, 0.45, 0.3, 0.5, 0.1)
	FX.Ring(g + V(0, 0.05, 0), radius * 0.6, ORANGE, 0.35, 0.2, 0.3, 0.3)
	FX.Burst(g + V(0, 1, 0), ORANGE, 8, 0.3, 9, 0.45)
	FX.Burst(g + V(0, 1, 0), BRONZE, 5, 0.35, 6, 0.5)
	if not FX.Lite then
		tinyClock(g + V(0, 4, 0), 0.6, 0.6, 30)
	end
	FX.Sound("Explosion", 0.4, 1.6, pos)
end

-- Установка часовщика: циферблат под ним, стрелки идут назад, золотой механический портал
function FX.ClockPortal(pos, dur)
	dur = dur or 1.3
	local g = V(pos.X, pos.Y + 0.25, pos.Z)
	local set = rigidSet()
	local a = 4.5
	addDial(set, a, 0.12, 0.2)
	placeRigid(set, CF(g) * ANG(rad(-90), 0, 0))
	local h, m = makeHands(a)
	local portal = FX.Part({ Shape = Enum.PartType.Cylinder, Size = V(0.3, 0.5, 0.5), CFrame = CF(g + V(0, 0.2, 0)) * ANG(0, 0, rad(90)), Color = CGOLD, Transparency = 0.2 })
	tween(portal, dur * 0.6, { Size = V(0.3, a * 1.6, a * 1.6) })
	light(portal, ORANGE, 14, 2, dur + 0.5)
	FX.Sound("Portal", 0.9, 1.2, pos)
	local start = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local el = os.clock() - start
		-- стрелки идут назад
		placeHands(h, m, CF(g) * ANG(rad(-90), 0, 0), el * 4, el * 22, a, 0.12)
		if el >= dur then
			conn:Disconnect()
			fadeRigid(set, 0.5)
			for _, p in ipairs({ h, m, portal }) do
				tween(p, 0.5, { Transparency = 1 })
				cleanup(p, 0.55)
			end
			FX.Burst(g + V(0, 2, 0), CGOLD, 14, 0.35, 8, 0.6)
			FX.Ring(g, 6, ORANGE, 0.5, 0.3, 2, 0.2)
		end
	end)
end

return FX
]======] }
FILES[#FILES + 1] = { "StarterPlayerScripts", { "VoidTDClient", "HalloweenFX" }, "ModuleScript", [======[
--!nocheck
-- VOID TD :: HalloweenFX (клиент)
-- Эффекты Хэллоуина: атаки и способности 11 юнитов, руны, союзники на дороге (модели, ходьба, HP),
-- состояния и смерти хэллоуинских врагов, появление боссов. Только визуал — урон считает сервер.

local RunService = game:GetService("RunService")

local HFX = {}

local V = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles
local rad = math.rad

local ctx, Config, PathUtil, UnitModels, FX, Renderer
local rng = Random.new()

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local COL = {
	Orange = rgb(255, 140, 40),
	Ember = rgb(255, 90, 20),
	Fire = rgb(255, 180, 70),
	Light = rgb(255, 235, 170),
	Green = rgb(120, 255, 110),
	Poison = rgb(140, 230, 80),
	PoisonDark = rgb(60, 110, 40),
	Blue = rgb(90, 170, 255),
	Ghost = rgb(170, 220, 255),
	Purple = rgb(180, 90, 255),
	Red = rgb(230, 30, 50),
	Gold = rgb(255, 205, 80),
	Straw = rgb(220, 190, 110),
	Dirt = rgb(110, 85, 60),
	Stone = rgb(120, 112, 104),
	Leaf = rgb(230, 140, 40),
	Bell = rgb(190, 160, 255),
	Bone = rgb(230, 222, 205),
	Black = rgb(16, 12, 18),
	Smoke = rgb(90, 90, 96),
	FogC = rgb(160, 170, 160),
}
HFX.Colors = COL

local function part(props)
	return FX.Part(props)
end

local function fade(p, life, goal)
	goal = goal or {}
	goal.Transparency = 1
	FX.Tween(p, life, goal)
	task.delay(life + 0.05, function()
		p:Destroy()
	end)
end

local function ground(pos)
	return V(pos.X, PathUtil.Map.GroundY + 0.15, pos.Z)
end

local function plight(p, color, range, brightness, life)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Shadows = false
	l.Parent = p
	if life then
		FX.Tween(l, life, { Brightness = 0 })
	end
	return l
end

-- обломки: куски с гравитацией (камни, кость, солома, щепки)
local function debris(pos, color, count, size, speed, life, material)
	if FX.Lite then
		count = math.min(3, count)
	end
	for _ = 1, count do
		local s = size * rng:NextNumber(0.6, 1.3)
		local p = part({ Size = V(s, s * 0.8, s * 1.1), CFrame = CF(pos) * ANG(rng:NextNumber(0, 6), rng:NextNumber(0, 6), 0), Color = color, Material = material or Enum.Material.Slate })
		local v = V(rng:NextNumber(-1, 1), rng:NextNumber(0.6, 1.4), rng:NextNumber(-1, 1)) * speed
		local t0 = os.clock()
		local spin = V(rng:NextNumber(-8, 8), rng:NextNumber(-8, 8), 0)
		local conn
		conn = RunService.RenderStepped:Connect(function()
			local t = os.clock() - t0
			if t >= life or not p.Parent then
				conn:Disconnect()
				if p.Parent then
					p:Destroy()
				end
				return
			end
			local q = pos + v * t + V(0, -30 * t * t, 0)
			q = V(q.X, math.max(q.Y, PathUtil.Map.GroundY + s * 0.4), q.Z)
			p.CFrame = CF(q) * ANG(spin.X * t, spin.Y * t, 0)
			if t > life * 0.6 then
				p.Transparency = (t - life * 0.6) / (life * 0.4)
			end
		end)
	end
end

-- дымное облако из полупрозрачных шаров
local function smoke(pos, color, n, size, life, rise)
	if FX.Lite then
		n = math.min(n, 2)
	end
	for _ = 1, n do
		local s = size * rng:NextNumber(0.7, 1.2)
		local p = part({ Shape = Enum.PartType.Ball, Size = V(s, s, s), CFrame = CF(pos + V(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1)) * size * 0.4), Color = color, Material = Enum.Material.SmoothPlastic, Transparency = 0.45 })
		fade(p, life * rng:NextNumber(0.8, 1.2), { Size = V(s, s, s) * 1.9, CFrame = p.CFrame + V(rng:NextNumber(-1, 1), rise or 2, rng:NextNumber(-1, 1)) })
	end
end

-- вспышка света
local function flash(pos, color, radius, life)
	FX.Sphere(pos, radius, color, life or 0.3)
	local a = part({ Size = V(0.2, 0.2, 0.2), CFrame = CF(pos), Transparency = 1 })
	plight(a, color, radius * 4, 4, life or 0.35)
	task.delay((life or 0.35) + 0.05, function()
		a:Destroy()
	end)
end

-- кольцо рун на земле
local function runeRing(pos, r, color, life)
	local list = {}
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		list[#list + 1] = part({ Size = V(0.4, 0.06, 1.2), CFrame = CF(ground(pos) + V(math.cos(a) * r, 0.05, math.sin(a) * r)) * ANG(0, -a, 0), Color = color })
	end
	for i = 0, 1 do
		list[#list + 1] = part({ Size = V(r * 1.5, 0.05, 0.22), CFrame = CF(ground(pos) + V(0, 0.04, 0)) * ANG(0, i * math.pi / 2 + rad(45), 0), Color = color, Transparency = 0.3 })
	end
	local ring = part({ Shape = Enum.PartType.Cylinder, Size = V(0.06, r * 2.2, r * 2.2), CFrame = CF(ground(pos)) * ANG(0, 0, rad(90)), Color = color, Transparency = 0.55 })
	list[#list + 1] = ring
	for _, p in ipairs(list) do
		task.delay(life * 0.6, function()
			fade(p, life * 0.4)
		end)
	end
	return list
end

-- вертикальный портал-диск
local function portalDisc(pos, r, color, life, edge)
	local cam = workspace.CurrentCamera
	local look = cam and (cam.CFrame.Position - pos) or V(0, 0, 1)
	local cf = CFrame.lookAt(pos, pos + V(look.X, 0, look.Z))
	local disc = part({ Shape = Enum.PartType.Cylinder, Size = V(0.2, 0.2, 0.2), CFrame = cf * ANG(0, rad(90), 0), Color = color, Transparency = 0.2 })
	FX.Tween(disc, 0.25, { Size = V(0.2, r * 2, r * 2) }, Enum.EasingStyle.Back)
	local rim = part({ Shape = Enum.PartType.Cylinder, Size = V(0.15, 0.3, 0.3), CFrame = cf * ANG(0, rad(90), 0) * CF(-0.05, 0, 0), Color = edge or COL.Light, Transparency = 0.1 })
	FX.Tween(rim, 0.25, { Size = V(0.15, r * 2.25, r * 2.25) }, Enum.EasingStyle.Back)
	plight(disc, color, r * 5, 3, life)
	task.delay(life * 0.7, function()
		fade(disc, life * 0.3, { Size = V(0.2, 0.2, 0.2) })
		fade(rim, life * 0.3, { Size = V(0.15, 0.3, 0.3) })
	end)
end

-- птица (ворон) — пара крыльев и тело
local function bird(color)
	local m = Instance.new("Model")
	local body = part({ Size = V(0.5, 0.45, 0.9), Color = color or COL.Black, Material = Enum.Material.SmoothPlastic, Parent = m })
	for _, s in ipairs({ -1, 1 }) do
		local w = part({ Class = "WedgePart", Size = V(0.1, 0.5, 1.2), Color = color or COL.Black, Material = Enum.Material.SmoothPlastic, Parent = m })
		w.Name = s == 1 and "WR" or "WL"
	end
	m.PrimaryPart = body
	m.Parent = workspace:FindFirstChild("VoidTD_FX") or workspace
	return m, body
end

local function placeBird(m, cf, flap)
	local body = m.PrimaryPart
	body.CFrame = cf
	m.WR.CFrame = cf * CF(0.55, 0.1, 0) * ANG(0, 0, rad(-60 + flap))
	m.WL.CFrame = cf * CF(-0.55, 0.1, 0) * ANG(0, 0, rad(60 - flap))
end

-- вороны кружат вокруг точки
local function crowCircle(pos, r, n, life, color)
	if FX.Lite then
		n = 1
	end
	local birds = {}
	for i = 1, n do
		birds[i] = { bird(color), i / n * math.pi * 2, rng:NextNumber(2, 4.5) }
	end
	local t0 = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		for _, b in ipairs(birds) do
			local a = b[2] + t * 2.4
			local p = pos + V(math.cos(a) * r, b[3] + math.sin(t * 3 + b[2]) * 0.4, math.sin(a) * r)
			local fwd = V(-math.sin(a), 0, math.cos(a))
			placeBird(b[1], CFrame.lookAt(p, p + fwd), math.sin(t * 18 + b[2]) * 40)
		end
		if t >= life then
			conn:Disconnect()
			for _, b in ipairs(birds) do
				b[1]:Destroy()
			end
		end
	end)
end

-- ворон летит от точки к точке (снаряд пугала)
local function crowFly(from, getTarget, travel, onHit)
	local m = bird()
	local t0 = os.clock()
	local last = getTarget() or from
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local a = math.clamp((os.clock() - t0) / math.max(travel, 0.05), 0, 1)
		local target = getTarget() or last
		last = target
		local p = from:Lerp(target, a) + V(0, math.sin(a * math.pi) * 2, 0)
		local dir = target - p
		placeBird(m, (dir.Magnitude > 0.05) and CFrame.lookAt(p, target) or CF(p), math.sin(os.clock() * 25) * 45)
		if a >= 1 then
			conn:Disconnect()
			m:Destroy()
			if onHit then
				onHit(target)
			end
		end
	end)
end

------------------------------------------------------------------------
-- СНАРЯДЫ (через FX.ProjectileMakers)
------------------------------------------------------------------------
local function installProjectiles()
	FX.ProjectileMakers = FX.ProjectileMakers or {}
	FX.ProjectileMakers.CurseBullet = function(lv)
		local p = part({ Size = V(0.22, 0.22, 1.1), Color = COL.Green })
		plight(p, COL.Green, 6, 2)
		return p, COL.Green
	end
	FX.ProjectileMakers.Flask = function(lv)
		local p = part({ Size = V(0.5, 0.7, 0.5), Color = COL.Poison, Material = Enum.Material.Glass, Transparency = 0.2 })
		local cork = part({ Size = V(0.25, 0.25, 0.25), Color = COL.Dirt, Material = Enum.Material.Wood, Parent = p })
		cork.Name = "Tip"
		plight(p, COL.Poison, 6, 1.5)
		return p, COL.Poison
	end
	FX.ProjectileMakers.Card = function(lv)
		local p = part({ Size = V(0.6, 0.06, 0.9), Color = rgb(245, 240, 250), Material = Enum.Material.SmoothPlastic })
		local mark = part({ Size = V(0.25, 0.08, 0.25), Color = COL.Purple, Parent = p })
		mark.Name = "Tip"
		return p, COL.Purple
	end
	FX.ProjectileMakers.Pumpkin = function(lv)
		local s = 1 + lv * 0.08
		local p = part({ Size = V(1.1 * s, 0.9 * s, 1.1 * s), Color = rgb(230, 110, 30), Material = Enum.Material.SmoothPlastic })
		local face = part({ Size = V(0.6 * s, 0.25 * s, 0.1), Color = COL.Fire, Parent = p })
		face.Name = "Tip"
		plight(p, COL.Orange, 10, 2.5)
		return p, COL.Ember
	end
end

------------------------------------------------------------------------
-- УДАРЫ И СПОСОБНОСТИ (Impact)
------------------------------------------------------------------------
local IMPACT = {}

IMPACT.LightFlash = function(p)
	local g = ground(p.P)
	flash(g + V(0, 1.5, 0), COL.Light, p.R * 0.6, 0.3)
	FX.Ring(g, p.R, COL.Light, 0.35, 0.2, 0.5, 0.3)
	FX.Sound("Magic", 0.6, 1.6, g)
end

IMPACT.LanternBeam = function(p)
	local g = ground(p.P)
	local beam = part({ Shape = Enum.PartType.Cylinder, Size = V(30, 0.5, 0.5), CFrame = CF(g + V(0, 15, 0)) * ANG(0, 0, rad(90)), Color = COL.Light, Transparency = 0.2 })
	FX.Tween(beam, 0.15, { Size = V(30, p.R * 1.2, p.R * 1.2) })
	task.delay(0.2, function()
		fade(beam, 0.4, { Size = V(30, 0.2, 0.2) })
	end)
	FX.Ring(g, p.R, COL.Fire, 0.5, 0.3, 1, 0.1)
	flash(g + V(0, 2, 0), COL.Light, p.R * 0.7, 0.45)
	FX.Burst(g + V(0, 1, 0), COL.Fire, 12, 0.35, 9)
	FX.Sound("Laser", 0.8, 1.4, g)
end

IMPACT.DirtBurst = function(p)
	local g = ground(p.P)
	FX.Ring(g, p.R, COL.Dirt, 0.45, 0.4, 1, 0.1)
	FX.Cracks(g, p.R, rgb(70, 50, 36), 6, 1.1)
	debris(g + V(0, 0.5, 0), COL.Stone, 8, 0.6, 9, 0.9)
	debris(g + V(0, 0.5, 0), COL.Dirt, 6, 0.45, 7, 0.8, Enum.Material.Ground)
	smoke(g + V(0, 1, 0), rgb(120, 100, 80), 4, 3, 0.9, 2.5)
	FX.Sound("HeavyHit", 0.8, 0.8, g)
end

IMPACT.LeafStorm = function(p)
	local g = ground(p.P)
	FX.Ring(g, p.R, COL.Leaf, 0.6, 0.25, 1, 0.3)
	local n = FX.Lite and 6 or 18
	local leaves = {}
	for i = 1, n do
		leaves[i] = { part({ Size = V(0.5, 0.06, 0.35), Color = (i % 3 == 0) and COL.Ember or COL.Leaf, Material = Enum.Material.SmoothPlastic }), rng:NextNumber(0, 6.28), rng:NextNumber(0.5, 1) }
	end
	local t0 = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		for _, l in ipairs(leaves) do
			local a = l[2] + t * 7
			local r = p.R * l[3] * (0.4 + t * 0.5)
			l[1].CFrame = CF(g + V(math.cos(a) * r, t * 4 * l[3] + 0.5, math.sin(a) * r)) * ANG(t * 9, a, 0)
			l[1].Transparency = math.clamp((t - 0.9) / 0.4, 0, 1)
		end
		if t >= 1.3 then
			conn:Disconnect()
			for _, l in ipairs(leaves) do
				l[1]:Destroy()
			end
		end
	end)
	crowCircle(g, p.R * 0.6, 2, 1.3)
	FX.Sound("Slash", 0.6, 0.6, g)
end

IMPACT.CurseMark = function(p)
	local id = p.I
	local c = Renderer.EnemyCenter(id) or p.P
	flash(c, COL.Green, 2.5, 0.3)
	FX.Burst(c, COL.Green, 10, 0.35, 8)
	-- знак проклятия над врагом: ромб и череп-рамка, держится DUR
	local mark = part({ Size = V(1, 1, 0.15), Color = COL.Green })
	local inner = part({ Size = V(0.45, 0.45, 0.2), Color = COL.Black, Material = Enum.Material.SmoothPlastic })
	local t0 = os.clock()
	local dur = p.DUR or 3
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		local view = Renderer.EnemyViews[id]
		if t >= dur or not view then
			conn:Disconnect()
			fade(mark, 0.2)
			fade(inner, 0.2)
			return
		end
		local top = view.Rig.Root.Position + V(0, view.Rig.Height - view.Rig.HipHeight + 1.2, 0)
		local cf = CF(top) * ANG(0, t * 3, rad(45))
		mark.CFrame = cf
		inner.CFrame = cf
	end)
	FX.Sound("Magic", 0.8, 0.6, c)
end

IMPACT.BellWave = function(p)
	local g = ground(p.P)
	FX.Ring(g + V(0, 0.2, 0), p.R, COL.Bell, 0.55, 0.5, 1, 0.25)
	task.delay(0.12, function()
		FX.Ring(g + V(0, 0.6, 0), p.R * 0.8, rgb(230, 220, 255), 0.45, 0.3, 1, 0.4)
	end)
	FX.Sound("Magic", 0.8, 0.45, g)
end

IMPACT.MidnightToll = function(p)
	local g = ground(p.P)
	for i = 0, 2 do
		task.delay(i * 0.15, function()
			FX.Ring(g + V(0, 0.3 + i * 0.4, 0), p.R * (1 - i * 0.12), i == 1 and COL.Purple or COL.Bell, 0.7, 0.6, 1, 0.15)
		end)
	end
	flash(g + V(0, 3, 0), COL.Bell, 4, 0.5)
	if FX.TinyClock then
		for i = 0, 2 do
			local a = i / 3 * math.pi * 2
			FX.TinyClock(g + V(math.cos(a) * p.R * 0.5, 3.5, math.sin(a) * p.R * 0.5), 1.4, 1.4, 4)
		end
	end
	FX.Shake(0.15, 0.3)
	FX.Sound("Boss", 0.5, 1.6, g)
end

IMPACT.FlaskSplash = function(p)
	local g = ground(p.P)
	FX.Burst(g + V(0, 1, 0), COL.Poison, 10, 0.35, 8)
	FX.Ring(g, p.R, COL.Poison, 0.4, 0.25, 0.5, 0.3)
	debris(g + V(0, 1, 0), rgb(200, 255, 200), 4, 0.25, 6, 0.5, Enum.Material.Glass)
	FX.Sound("Magic", 0.6, 1.2, g)
end

local function poisonCloud(p, big)
	local g = ground(p.P)
	local dur = p.DUR or 3
	local pool = part({ Shape = Enum.PartType.Cylinder, Size = V(0.1, 0.5, 0.5), CFrame = CF(g + V(0, 0.05, 0)) * ANG(0, 0, rad(90)), Color = COL.PoisonDark, Transparency = 0.35 })
	FX.Tween(pool, 0.3, { Size = V(0.1, p.R * 2, p.R * 2) })
	local balls = {}
	local n = FX.Lite and 2 or (big and 8 or 3)
	for i = 1, n do
		local a = i / n * math.pi * 2
		local s = p.R * (big and 0.9 or 0.7)
		local b = part({ Shape = Enum.PartType.Ball, Size = V(s, s * 0.6, s), CFrame = CF(g + V(math.cos(a) * p.R * 0.45, s * 0.25, math.sin(a) * p.R * 0.45)), Color = big and rgb(120, 200, 70) or COL.Poison, Material = Enum.Material.SmoothPlastic, Transparency = 0.6 })
		balls[i] = b
	end
	local em
	if not FX.Lite then
		em = Instance.new("ParticleEmitter")
		em.Color = ColorSequence.new(COL.Poison)
		em.LightEmission = 0.6
		em.Rate = big and 30 or 12
		em.Lifetime = NumberRange.new(0.6, 1.2)
		em.Speed = NumberRange.new(1, 3)
		em.SpreadAngle = Vector2.new(30, 30)
		em.EmissionDirection = Enum.NormalId.Right
		em.Size = NumberSequence.new(0.35, 0)
		em.Parent = pool
	end
	if big then
		crowCircle(g, p.R * 0.8, 3, dur)
	end
	task.delay(dur, function()
		if em then
			em.Enabled = false
		end
		fade(pool, 0.5)
		for _, b in ipairs(balls) do
			fade(b, 0.5, { Size = b.Size * 1.3 })
		end
	end)
end

IMPACT.Poison = function(p)
	poisonCloud(p, false)
end

IMPACT.PlagueCloud = function(p)
	poisonCloud(p, true)
	FX.Sound("Magic", 0.8, 0.5, p.P)
end

IMPACT.PlagueCloudBurst = function(p)
	FX.Sphere(ground(p.P) + V(0, 1, 0), p.R * 0.8, COL.Poison, 0.45, nil, 0.3)
	FX.Burst(ground(p.P) + V(0, 1, 0), COL.Poison, 14, 0.4, 10)
end

IMPACT.GhostSlash = function(p)
	local from, to = p.P + V(0, 1.5, 0), V(p.E.X, p.P.Y + 1.5, p.E.Z)
	FX.Beam(from, to, 1.1, COL.Blue, 0.35)
	local mid = (from + to) / 2
	local cf = CFrame.lookAt(mid, to)
	local crescent = part({ Size = V(3.5, 0.2, 1.2), CFrame = CFrame.lookAt(from, to), Color = COL.Ghost, Transparency = 0.2 })
	FX.Tween(crescent, 0.25, { CFrame = CFrame.lookAt(to, to + (to - from)) })
	task.delay(0.25, function()
		fade(crescent, 0.2)
	end)
	FX.Sound("Slash", 1, 0.9, mid)
	FX.Sphere(from, 1.6, COL.Blue, 0.25)
	local _ = cf
end

IMPACT.GhostSword = function(p)
	local g = ground(p.P)
	local h = 14
	local blade = part({ Size = V(1.4, h, 0.4), CFrame = CF(g + V(0, h / 2 + 18, 0)), Color = COL.Ghost, Transparency = 0.35 })
	local guard = part({ Size = V(5, 0.6, 0.8), CFrame = CF(g + V(0, h + 18, 0)), Color = COL.Blue, Transparency = 0.3 })
	local hilt = part({ Size = V(0.6, 3, 0.6), CFrame = CF(g + V(0, h + 19.8, 0)), Color = COL.Blue, Transparency = 0.3 })
	local list = { blade, guard, hilt }
	for _, q in ipairs(list) do
		FX.Tween(q, 0.3, { CFrame = q.CFrame - V(0, 18 + h * 0.3, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	end
	task.delay(0.3, function()
		FX.Ring(g, p.R, COL.Blue, 0.6, 0.5, 1, 0.1)
		FX.Cracks(g, p.R, COL.Blue, 8, 1.2)
		flash(g + V(0, 2, 0), COL.Ghost, p.R * 0.6, 0.45)
		FX.Burst(g + V(0, 1, 0), COL.Ghost, 16, 0.4, 12)
		FX.Shake(0.35, 0.35)
		FX.Sound("Explosion", 1, 0.8, g)
		for _, q in ipairs(list) do
			task.delay(0.35, function()
				fade(q, 0.4)
			end)
		end
	end)
end

IMPACT.MirrorShatter = function(p)
	local g = ground(p.P)
	portalDisc(g + V(0, 3.5, 0), 2.6, COL.Purple, 0.8, rgb(230, 200, 255))
	FX.Ring(g, p.R, COL.Purple, 0.5, 0.3, 1, 0.15)
	debris(g + V(0, 3, 0), rgb(220, 210, 255), 10, 0.5, 11, 0.9, Enum.Material.Glass)
	FX.Burst(g + V(0, 2, 0), COL.Purple, 10, 0.35, 10)
	FX.Sound("Explosion", 0.7, 1.3, g)
end

IMPACT.ThreadSnap = function(p)
	local g = ground(p.P) + V(0, 2.5, 0)
	for i = 1, (FX.Lite and 4 or 8) do
		local a = i / 8 * math.pi * 2
		local to = g + V(math.cos(a) * p.R, rng:NextNumber(-2, 1), math.sin(a) * p.R)
		FX.Thread(g + V(0, 6, 0), to, COL.Red)
	end
	FX.Ring(ground(p.P), p.R, COL.Red, 0.4, 0.2, 1, 0.2)
	FX.Burst(g, COL.Red, 14, 0.3, 10)
	FX.Sound("Slash", 1, 1.4, g)
end

IMPACT.FireCrack = function(p)
	local g = ground(p.P)
	FX.Cracks(g, p.R, COL.Ember, 6, 1.2)
	FX.Ring(g, p.R, COL.Orange, 0.4, 0.3, 1, 0.2)
	FX.Burst(g + V(0, 1, 0), COL.Fire, 10, 0.4, 8)
	smoke(g + V(0, 1, 0), rgb(60, 40, 36), 3, 2.5, 0.8, 3)
	FX.Sound("HeavyHit", 1, 0.6, g)
end

IMPACT.Execution = function(p)
	local g = ground(p.P)
	FX.Cracks(g, p.R, COL.Ember, 12, 1.6)
	FX.Ring(g, p.R, COL.Ember, 0.6, 0.6, 1, 0.05)
	flash(g + V(0, 2, 0), COL.Fire, p.R * 0.5, 0.4)
	for i = 1, (FX.Lite and 2 or 5) do
		local a = i / 5 * math.pi * 2
		local q = g + V(math.cos(a) * p.R * 0.6, 0, math.sin(a) * p.R * 0.6)
		local pillar = part({ Size = V(1.2, 0.5, 1.2), CFrame = CF(q), Color = COL.Orange, Transparency = 0.2 })
		FX.Tween(pillar, 0.25, { Size = V(1.2, 7, 1.2), CFrame = CF(q + V(0, 3.5, 0)) })
		task.delay(0.3, function()
			fade(pillar, 0.4, { Size = V(0.2, 9, 0.2) })
		end)
	end
	debris(g + V(0, 0.5, 0), COL.Stone, 8, 0.6, 10, 0.9)
	FX.Shake(0.45, 0.4)
	FX.Sound("Explosion", 1, 0.55, g)
end

IMPACT.PumpkinBlast = function(p)
	local g = ground(p.P) + V(0, 1, 0)
	FX.Sphere(g, p.R * 0.8, COL.Orange, 0.35)
	FX.Burst(g, COL.Ember, 10, 0.4, 9)
	debris(g, rgb(230, 110, 30), 5, 0.5, 8, 0.7, Enum.Material.SmoothPlastic)
	FX.Sound("Explosion", 0.6, 1.1, g)
end

IMPACT.GhostPumpkin = function(p)
	local g = ground(p.P)
	local s = 6
	local top = g + V(0, 22, 0)
	local pk = part({ Size = V(s, s * 0.85, s), CFrame = CF(top), Color = COL.Ghost, Transparency = 0.4 })
	local face = part({ Size = V(s * 0.6, s * 0.25, 0.2), CFrame = CF(top + V(0, -0.3, -s / 2)), Color = COL.Orange })
	local eyeL = part({ Size = V(0.9, 0.9, 0.2), CFrame = CF(top + V(-1.2, 1, -s / 2)) * ANG(0, 0, rad(45)), Color = COL.Orange })
	local eyeR = part({ Size = V(0.9, 0.9, 0.2), CFrame = CF(top + V(1.2, 1, -s / 2)) * ANG(0, 0, rad(45)), Color = COL.Orange })
	local list = { pk, face, eyeL, eyeR }
	plight(pk, COL.Orange, 30, 3)
	for _, q in ipairs(list) do
		FX.Tween(q, 0.45, { CFrame = q.CFrame - V(0, 19, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	end
	task.delay(0.45, function()
		for _, q in ipairs(list) do
			q:Destroy()
		end
		FX.Sphere(g + V(0, 2, 0), p.R, COL.Orange, 0.6, nil, 0.05)
		FX.Sphere(g + V(0, 2, 0), p.R * 0.7, COL.Ghost, 0.5, nil, 0.3)
		FX.Ring(g, p.R * 1.2, COL.Ember, 0.7, 0.6, 1, 0.05)
		FX.Cracks(g, p.R, COL.Ember, 10, 1.6)
		FX.Burst(g + V(0, 2, 0), COL.Fire, 24, 0.6, 16, 0.8)
		debris(g + V(0, 1, 0), rgb(230, 110, 30), 8, 0.8, 12, 1.0, Enum.Material.SmoothPlastic)
		flash(g + V(0, 3, 0), COL.Fire, p.R, 0.6)
		FX.Shake(0.6, 0.5)
		FX.Sound("Explosion", 1, 0.45, g)
	end)
end

-- РУНЫ
IMPACT.LanternHeart = function(p)
	local g = ground(p.P) + V(0, 1.2, 0)
	FX.Sphere(g, p.R, COL.Orange, 0.35, nil, 0.15)
	FX.Ring(ground(p.P), p.R, COL.Ember, 0.35, 0.25, 0.5, 0.2)
	FX.Burst(g, COL.Fire, 8, 0.3, 7)
	FX.Sound("Explosion", 0.4, 1.4, g)
end

IMPACT.CursedThreads = function(p)
	local c = p.P + V(0, 7, 0)
	for _, id in ipairs(p.A or {}) do
		local e = Renderer.EnemyCenter(id)
		if e then
			FX.Thread(c, e, COL.Red)
			FX.Ring(ground(e), 1.6, COL.Red, 0.5, 0.2, 0.3, 0.2)
		end
	end
	FX.Sound("Magic", 0.7, 0.5, p.P)
end

IMPACT.PhantomEcho = function(p)
	-- сама копия рисуется по событию атаки с флагом EC; здесь — синий отблеск у юнита
	FX.Burst(p.P + V(0, 2, 0), COL.Ghost, 5, 0.25, 4)
end

IMPACT.CursedCircle = function(p)
	local g = ground(p.P)
	runeRing(g, 4, COL.Red, 2.2)
	flash(g + V(0, 1.5, 0), COL.Red, 3, 0.5)
	FX.Burst(g + V(0, 1, 0), COL.Red, 12, 0.35, 6)
	FX.Sound("Magic", 0.8, 0.4, g)
end

IMPACT.SummonPortal = function(p)
	local g = ground(p.P)
	if p.S == "Illusion" then
		portalDisc(g + V(0, 4, 0), 3.4, COL.Purple, 1.4, rgb(230, 200, 255))
		runeRing(g, 3.5, COL.Purple, 1.6)
		debris(g + V(0, 3, 0), rgb(220, 210, 255), 6, 0.35, 6, 0.8, Enum.Material.Glass)
	else
		-- кукловод: красные нити опускают марионеток сверху
		for i = 1, 5 do
			local a = i / 5 * math.pi * 2
			FX.Thread(g + V(math.cos(a) * 1.5, 14, math.sin(a) * 1.5), g + V(math.cos(a) * 1.2, 2, math.sin(a) * 1.2), COL.Red)
		end
		runeRing(g, 3, COL.Red, 1.4)
		if p.G then
			flash(g + V(0, 3, 0), COL.Gold, 5, 0.7)
			FX.Burst(g + V(0, 2, 0), COL.Gold, 20, 0.4, 10, 0.8)
		end
	end
	FX.Sound("Portal", 0.8, 1.2, g)
end

IMPACT.AllyHit = function(p)
	local pos = p.P + V(0, 2, 0)
	FX.Burst(pos, p.F and COL.Orange or COL.Light, 6, 0.3, 7)
	FX.Sphere(pos, 1.4, p.F and COL.Ember or rgb(255, 255, 255), 0.18)
	FX.Sound("Slash", 0.5, 1.2, pos)
	local av = HFX.Allies[p.I]
	if av then
		av.HitT = os.clock()
	end
end

IMPACT.Fog = function(p)
	local g = ground(p.P)
	FX.Ring(g, p.R, COL.FogC, 0.9, 0.2, 1, 0.5)
	smoke(g + V(0, 1, 0), COL.FogC, 5, p.R * 0.6, 1.4, 1)
	local view = Renderer.EnemyViews[p.I]
	if view then
		for _, d in ipairs(view.Rig.Model:GetDescendants()) do
			if d.Name == "FogFX" and d:IsA("ParticleEmitter") then
				d:Emit(18)
			end
		end
	end
end

IMPACT.Straw = function(p)
	local g = ground(p.P)
	debris(g + V(0, 1.5, 0), COL.Straw, 10, 0.35, 8, 0.9, Enum.Material.Fabric)
	FX.Burst(g + V(0, 1.5, 0), COL.Straw, 8, 0.3, 6)
end

IMPACT.Fire = function(p)
	local g = ground(p.P)
	FX.Ring(g, 7, COL.Ember, 0.6, 0.4, 1, 0.1)
	FX.Burst(g + V(0, 2, 0), COL.Fire, 18, 0.5, 10)
	flash(g + V(0, 3, 0), COL.Orange, 6, 0.5)
end

------------------------------------------------------------------------
-- СОСТОЯНИЯ ВРАГОВ
------------------------------------------------------------------------
local function setPhased(view, on)
	local model = view.Rig.Model
	if on then
		view.PhaseSave = view.PhaseSave or {}
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("BasePart") and d.Transparency < 1 and not view.PhaseSave[d] then
				view.PhaseSave[d] = { d.Transparency, d.Color, d.Material }
				if d:GetAttribute("Outline") then
					d.Color = COL.Ghost
					d.Material = Enum.Material.Neon
				else
					d.Transparency = 0.9
				end
			end
		end
	elseif view.PhaseSave then
		for d, s in pairs(view.PhaseSave) do
			if d.Parent then
				d.Transparency, d.Color, d.Material = s[1], s[2], s[3]
			end
		end
		view.PhaseSave = nil
	end
end

local function setShield(view, on)
	for _, d in ipairs(view.Rig.Model:GetDescendants()) do
		if d.Name == "ShieldFX" and d:IsA("BasePart") then
			FX.Tween(d, 0.25, { Transparency = on and (d:GetAttribute("PT") or 0.6) or 1 })
		end
	end
end

IMPACT.EnemyState = function(p)
	local view = Renderer.EnemyViews[p.I]
	if not view then
		return
	end
	local c = Renderer.EnemyCenter(p.I) or p.P
	local s = p.S
	if s == "Phase" then
		setPhased(view, true)
		FX.Burst(c, COL.Ghost, 6, 0.25, 4)
		task.delay(p.DUR or 1.5, function()
			if view.Rig.Model.Parent then
				setPhased(view, false)
			end
		end)
	elseif s == "Shield" then
		setShield(view, true)
		FX.Sphere(c, 3 * (view.Rig.Scale or 1), COL.Purple, 0.35, nil, 0.4)
		task.delay(p.DUR or 3, function()
			if view.Rig.Model.Parent then
				setShield(view, false)
			end
		end)
	elseif s == "Haste" then
		view.HasteUntil = os.clock() + (p.DUR or 3)
		FX.Burst(c, COL.Red, 10, 0.3, 10)
		FX.Ring(ground(c), 4, COL.Red, 0.4, 0.2, 1, 0.2)
	elseif s == "Enrage" then
		flash(c, COL.Red, 6, 0.6)
		FX.Ring(ground(c), 10, COL.Red, 0.7, 0.5, 1, 0.1)
		FX.Shake(0.5, 0.6)
		FX.Sound("Boss", 1, 0.9, c)
	elseif s == "ArmorBreak" then
		debris(c, COL.Bone, 8, 0.45, 9, 0.9, Enum.Material.SmoothPlastic)
		debris(c, rgb(90, 88, 100), 5, 0.5, 8, 0.9, Enum.Material.Metal)
		FX.Sound("HeavyHit", 0.8, 1.3, c)
	end
end

-- Смерть врага: дополнительный эффект по rig.DeathFX
local DEATH = {
	GreenSmoke = function(pos, s)
		smoke(pos, rgb(90, 200, 100), 5, 2.4 * s, 1.1, 3)
		FX.Burst(pos, COL.Green, 6, 0.3, 4)
	end,
	PumpkinBurst = function(pos, s)
		debris(pos, rgb(230, 110, 30), 7, 0.5 * s, 9, 0.9, Enum.Material.SmoothPlastic)
		FX.Burst(pos, COL.Fire, 10, 0.35, 8)
		FX.Sphere(pos, 1.6 * s, COL.Orange, 0.3)
	end,
	Ghost = function(pos, s)
		smoke(pos, COL.Ghost, 4, 2 * s, 0.9, 4)
		FX.Burst(pos, COL.Ghost, 8, 0.3, 5)
	end,
	BoneShards = function(pos, s)
		debris(pos, COL.Bone, 9, 0.4 * s, 9, 1.0, Enum.Material.SmoothPlastic)
	end,
	Straw = function(pos, s)
		debris(pos, COL.Straw, 10, 0.35 * s, 8, 1.0, Enum.Material.Fabric)
	end,
	Fog = function(pos, s)
		smoke(pos, COL.FogC, 6, 2.6 * s, 1.3, 2)
	end,
	Reaper = function(pos, s)
		smoke(pos, rgb(70, 40, 110), 6, 2.6 * s, 1.2, 4)
		FX.Burst(pos, COL.Purple, 14, 0.4, 9)
		FX.Ring(ground(pos), 6, COL.Purple, 0.6, 0.3, 1, 0.2)
	end,
	GraveBreak = function(pos, s)
		debris(pos, COL.Stone, 14, 0.9, 11, 1.2)
		smoke(pos, rgb(110, 105, 100), 6, 3.5, 1.4, 3)
		FX.Ring(ground(pos), 12, rgb(150, 255, 140), 0.8, 0.5, 1, 0.1)
		FX.Shake(0.5, 0.6)
	end,
	MonarchDeath = function(pos, s)
		-- корона трескается, оранжевый свет, монарх рассыпается
		flash(pos + V(0, 4, 0), COL.Fire, 14, 1.2)
		FX.Ring(ground(pos), 20, COL.Ember, 1.2, 0.8, 1, 0.05)
		FX.Burst(pos + V(0, 4, 0), COL.Gold, 24, 0.5, 12, 1)
		debris(pos + V(0, 6, 0), COL.Gold, 10, 0.6, 9, 1.4, Enum.Material.Metal)
		smoke(pos, rgb(60, 30, 20), 8, 5, 2.2, 6)
		FX.Shake(0.9, 1.2)
		FX.Sound("Secret", 0.8, 0.8, pos)
	end,
}

function HFX.EnemyDeath(view, reason)
	local fxName = view.Rig.DeathFX
	local fn = fxName and DEATH[fxName]
	if fn and reason ~= "clear" then
		local s = (Config.Enemies[view.Type] or {}).Scale or 1
		local pos = view.Rig.Root.Position
		if fxName == "MonarchDeath" then
			-- детали короны отрываются и падают
			for _, d in ipairs(view.Rig.Model:GetDescendants()) do
				if d:IsA("BasePart") and d:GetAttribute("Crown") and d.Transparency < 1 then
					local c = d:Clone()
					c.Anchored = true
					c.Parent = workspace:FindFirstChild("VoidTD_FX") or workspace
					d.Transparency = 1
					fade(c, 1.4, { CFrame = c.CFrame * CF(rng:NextNumber(-3, 3), -4, rng:NextNumber(-3, 3)) * ANG(rng:NextNumber(-2, 2), 0, rng:NextNumber(-2, 2)) })
				end
			end
		end
		fn(pos, s)
	end
end

-- Появление: особые входы боссов
function HFX.EnemySpawn(view, atStart)
	local fxName = view.Rig.SpawnFX
	if not fxName or not atStart then
		return
	end
	local pos = view.Rig.Root.Position
	local g = ground(pos)
	if fxName == "GraveBreak" then
		-- плита могилы поднимается и раскалывается, страж выходит из могилы
		local slab = part({ Size = V(6, 0.8, 9), CFrame = CF(g + V(0, 0.4, 0)), Color = COL.Stone, Material = Enum.Material.Slate })
		FX.Tween(slab, 0.5, { CFrame = CF(g + V(0, 2.5, 0)) * ANG(rad(25), 0, rad(-10)) })
		task.delay(0.55, function()
			slab:Destroy()
			debris(g + V(0, 2.5, 0), COL.Stone, 12, 1.1, 12, 1.3)
			smoke(g + V(0, 1, 0), rgb(110, 105, 100), 6, 4, 1.4, 3)
			FX.Ring(g, 10, rgb(150, 255, 140), 0.7, 0.4, 1, 0.1)
			FX.Shake(0.6, 0.6)
		end)
	elseif fxName == "FogVortex" then
		-- вихрь тумана сгущается в жнеца
		local n = FX.Lite and 4 or 12
		local balls = {}
		for i = 1, n do
			balls[i] = { part({ Shape = Enum.PartType.Ball, Size = V(3, 3, 3), Color = COL.FogC, Material = Enum.Material.SmoothPlastic, Transparency = 0.6 }), i / n * math.pi * 2, rng:NextNumber(0, 6) }
		end
		local t0 = os.clock()
		local conn
		conn = RunService.RenderStepped:Connect(function()
			local t = os.clock() - t0
			for _, b in ipairs(balls) do
				local a = b[2] + t * 5
				local r = math.max(0.5, 10 - t * 7)
				b[1].CFrame = CF(g + V(math.cos(a) * r, 1 + b[3] * 0.6 + t * 2, math.sin(a) * r))
				b[1].Transparency = 0.6 + math.clamp((t - 1) / 0.4, 0, 0.4)
			end
			if t >= 1.4 then
				conn:Disconnect()
				for _, b in ipairs(balls) do
					b[1]:Destroy()
				end
				FX.Sphere(g + V(0, 4, 0), 7, COL.Red, 0.4, nil, 0.4)
			end
		end)
	elseif fxName == "MonarchPortal" then
		-- монарх выходит из огненного портала и втыкает посох в землю
		portalDisc(g + V(0, 9, 0), 8, rgb(150, 50, 15), 2.0, COL.Fire)
		task.delay(1.1, function()
			FX.Cracks(g, 12, COL.Ember, 12, 2)
			FX.Ring(g, 16, COL.Ember, 0.8, 0.6, 1, 0.05)
			FX.Burst(g + V(0, 1, 0), COL.Fire, 20, 0.5, 12)
			FX.Shake(0.7, 0.7)
			FX.Sound("Explosion", 1, 0.4, g)
		end)
	end
end

-- Ускорение (Fog Reaper) и туман: клиентское предсказание скорости
function HFX.SpeedMult(view)
	if view.HasteUntil and os.clock() < view.HasteUntil then
		return 1.6
	end
	return 1
end

------------------------------------------------------------------------
-- АТАКИ ЮНИТОВ (визуал вылета; урон и области — по Impact)
------------------------------------------------------------------------
function HFX.OnAttack(view, def, p, h, lv)
	if def.Event ~= "Halloween" or def.AttackType == "Chrono" then
		return false
	end
	local muzzle = Renderer.MuzzlePos(view)
	local firstId = p.T and p.T[1]
	local id = view.UnitId
	local function at(d, fn)
		task.delay(d, function()
			if view.Rig and view.Rig.Model.Parent then
				fn()
			end
		end)
	end
	if def.AttackType == "Melee" then
		at(h, function()
			local target = Renderer.EnemyCenter(firstId)
			if not target then
				return
			end
			local origin = view.Rig.Root.Position + V(0, 1, 0)
			local cf = CFrame.lookAt(origin, V(target.X, origin.Y, target.Z))
			FX.Arc(cf, math.max((V(target.X, origin.Y, target.Z) - origin).Magnitude * 0.6, 3), rad(20), rad(150), COL.Dirt, 0.6, 0.3)
			debris(ground(target) + V(0, 0.5, 0), COL.Dirt, 3, 0.35, 5, 0.6, Enum.Material.Ground)
			FX.Sound("HeavyHit", 0.8, 1, target)
		end)
		return true
	elseif def.AttackType == "Pulse" then
		at(h, function()
			flash(muzzle, COL.Bell, 1.6, 0.25)
		end)
		return true
	elseif def.AttackType == "Flask" then
		at(h, function()
			local from = Renderer.MuzzlePos(view)
			FX.Projectile("Flask", from, function()
				return Renderer.EnemyCenter(firstId)
			end, p.TR or 0.4, nil, lv)
		end)
		return true
	elseif def.AttackType == "Pierce" then
		at(h, function()
			FX.Sphere(Renderer.MuzzlePos(view), 1.8, COL.Blue, 0.25)
		end)
		return true
	elseif def.AttackType == "Thread" then
		at(h, function()
			for _, tid in ipairs(p.T or {}) do
				local target = Renderer.EnemyCenter(tid)
				if target then
					FX.Thread(Renderer.MuzzlePos(view), target, def.ThreadColor or COL.Red)
				end
			end
			FX.Sound("Magic", 0.8, 0.7, view.Pos)
		end)
		return true
	elseif def.AttackType == "AOE" then
		at(h, function()
			local m = Renderer.MuzzlePos(view)
			if id == "NightWatchman" then
				flash(m, COL.Light, 1.5, 0.2)
			elseif id == "HeadlessExecutioner" then
				local target = Renderer.EnemyCenter(firstId)
				if target then
					local origin = view.Rig.Root.Position + V(0, 2, 0)
					local cf = CFrame.lookAt(origin, V(target.X, origin.Y, target.Z))
					FX.Arc(cf, math.max((V(target.X, origin.Y, target.Z) - origin).Magnitude * 0.7, 4), rad(10), rad(160), COL.Ember, 1.1, 0.35)
				end
			end
		end)
		return true
	elseif def.AttackType == "Projectile" and def.Projectile == "Crow" then
		for si, tid in ipairs(p.T or { firstId }) do
			local travel = (p.TRS and p.TRS[si]) or p.TR or 0.3
			at(h + (si - 1) * (p.SG or 0.12), function()
				crowFly(Renderer.MuzzlePos(view), function()
					return Renderer.EnemyCenter(tid)
				end, travel, function(pos)
					FX.Burst(pos, COL.Black, 5, 0.3, 5)
				end)
			end)
		end
		return true
	end
	return false
end

-- «Призрачная корона»: синяя копия юнита за его спиной повторяет атаку
function HFX.EchoGhost(view)
	if not view.Rig or FX.Lite and math.random() < 0.5 then
		return
	end
	local ok, clone = pcall(function()
		return view.Rig.Model:Clone()
	end)
	if not ok or not clone then
		return
	end
	local root = view.Rig.Root
	local back = root.CFrame * CF(0, 0.3, 2.4)
	for _, d in ipairs(clone:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CastShadow = false
			if d.Transparency < 1 then
				d.Color = COL.Ghost
				d.Material = Enum.Material.Neon
				d.Transparency = 0.55
			end
		elseif d:IsA("ParticleEmitter") or d:IsA("BillboardGui") or d:IsA("PointLight") or d:IsA("Trail") or d:IsA("Motor6D") then
			d:Destroy()
		end
	end
	clone:PivotTo(back)
	clone.Parent = workspace:FindFirstChild("VoidTD_FX") or workspace
	local fwd = root.CFrame * CF(0, 0.3, -0.6)
	local t0 = os.clock()
	local parts = {}
	for _, d in ipairs(clone:GetDescendants()) do
		if d:IsA("BasePart") and d.Transparency < 1 then
			parts[#parts + 1] = d
		end
	end
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		local a = math.clamp(t / 0.25, 0, 1)
		clone:PivotTo(back:Lerp(fwd, a * 0.7))
		local tr = 0.55 + math.clamp((t - 0.35) / 0.35, 0, 1) * 0.45
		for _, d in ipairs(parts) do
			d.Transparency = tr
		end
		if t >= 0.7 then
			conn:Disconnect()
			clone:Destroy()
		end
	end)
end

function HFX.OnImpact(p)
	local fn = IMPACT[p.K]
	if fn then
		fn(p)
		return true
	end
	return false
end

-- Появление Короля фонарей: трон поднимается из огня
function HFX.ThronePlace(pos)
	local g = ground(pos)
	local seat = part({ Size = V(4, 0.6, 3.5), CFrame = CF(g - V(0, 3, 0)), Color = COL.Black, Material = Enum.Material.Slate })
	local back = part({ Size = V(4, 6, 0.6), CFrame = CF(g + V(0, 0, 1.6) - V(0, 3, 0)), Color = COL.Black, Material = Enum.Material.Slate })
	local trim = part({ Size = V(4.3, 0.3, 0.7), CFrame = CF(g + V(0, 3, 1.6) - V(0, 3, 0)), Color = COL.Gold })
	for _, q in ipairs({ seat, back, trim }) do
		FX.Tween(q, 0.6, { CFrame = q.CFrame + V(0, 3.3, 0) }, Enum.EasingStyle.Back)
		task.delay(1.6, function()
			fade(q, 0.6, { CFrame = q.CFrame - V(0, 2, 0) })
		end)
	end
	FX.Ring(g, 6, COL.Ember, 0.8, 0.5, 1, 0.1)
	FX.Burst(g + V(0, 1, 0), COL.Fire, 20, 0.45, 10, 0.8)
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2
		local q = g + V(math.cos(a) * 4, 0, math.sin(a) * 4)
		local pk = part({ Size = V(1, 0.8, 1), CFrame = CF(q - V(0, 1, 0)), Color = rgb(230, 110, 30), Material = Enum.Material.SmoothPlastic })
		FX.Tween(pk, 0.5, { CFrame = CF(q + V(0, 0.4, 0)) }, Enum.EasingStyle.Back)
		task.delay(1.8, function()
			fade(pk, 0.5)
		end)
	end
	flash(g + V(0, 3, 0), COL.Orange, 5, 0.8)
	FX.Sound("Secret", 0.6, 1.2, g)
end

------------------------------------------------------------------------
-- СОЮЗНИКИ: модели на дороге, идут от базы к порталу
------------------------------------------------------------------------
local allyViews = {}
HFX.Allies = allyViews
local allyFolder

local function allyBar(av)
	local gui = Instance.new("BillboardGui")
	gui.Name = "HPBar"
	gui.Size = UDim2.fromOffset(60, 8)
	gui.StudsOffsetWorldSpace = V(0, av.Rig.Height or 5, 0)
	gui.MaxDistance = 90
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = rgb(20, 14, 24)
	bg.BorderSizePixel = 0
	bg.Parent = gui
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = av.Family == "Cursed" and COL.Red or (av.Family == "Puppet" and COL.Orange or COL.Purple)
	fill.BorderSizePixel = 0
	fill.Parent = bg
	gui.Parent = av.Rig.Root
	av.Fill = fill
end

local function addAlly(id, dist, hp, typeIndex, maxHp)
	local allyId = Config.AllyOrder[typeIndex]
	if not allyId or not UnitModels.BuildAlly then
		return
	end
	local ok, rig = pcall(UnitModels.BuildAlly, allyId)
	if not ok or not rig then
		warn(rig)
		return
	end
	local def = Config.Allies[allyId]
	local av = {
		Id = id, AllyId = allyId, Family = def.Family, Rig = rig, Dist = dist, ServerDist = dist,
		HP = hp, MaxHP = maxHp or hp, LastSync = os.clock(), Phase = rng:NextNumber(0, 6),
		Lateral = rng:NextNumber(-1.4, 1.4), SpawnT = os.clock(),
	}
	rig.Height = rig.Height or (5 * (rig.Scale or 1))
	for _, d in ipairs(rig.Model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CanQuery = false
			d.CanTouch = false
			d.CanCollide = false
		end
	end
	local pos, dir = PathUtil.OffsetPositionAt(dist, av.Lateral)
	rig.Root.CFrame = CFrame.lookAt(pos + V(0, rig.HipHeight, 0), pos - dir + V(0, rig.HipHeight, 0))
	allyBar(av)
	rig.Model.Parent = allyFolder
	allyViews[id] = av
end

local function removeAlly(id, reason)
	local av = allyViews[id]
	if not av then
		return
	end
	allyViews[id] = nil
	local pos = av.Rig.Root.Position
	local color = av.Family == "Cursed" and COL.Red or (av.Family == "Puppet" and (av.AllyId == "GoldenMarionette" and COL.Gold or COL.Orange) or COL.Purple)
	if reason == "dead" then
		FX.Burst(pos, color, 10, 0.35, 8)
		if av.Family == "Puppet" then
			debris(pos, rgb(150, 110, 70), 6, 0.4, 7, 0.8, Enum.Material.Wood)
		elseif av.Family == "Illusion" then
			debris(pos, rgb(220, 210, 255), 6, 0.35, 7, 0.8, Enum.Material.Glass)
		else
			smoke(pos, rgb(120, 20, 30), 3, 2, 0.8, 3)
		end
	else
		FX.Poof(pos, color, 1)
	end
	av.Rig.Model:Destroy()
end

function HFX.SyncAllies(list, removed)
	local nowc = os.clock()
	local seen = {}
	if list then
		for i = 1, #list, 5 do
			local id = list[i]
			seen[id] = true
			local av = allyViews[id]
			if av then
				av.ServerDist = list[i + 1]
				av.HP = list[i + 2]
				av.MaxHP = list[i + 4] or av.MaxHP
				av.LastSync = nowc
			else
				addAlly(id, list[i + 1], list[i + 2], list[i + 3], list[i + 4])
			end
		end
		-- союзники, пропавшие из списка без причины (например, после переподключения)
		for id in pairs(allyViews) do
			if not seen[id] then
				removeAlly(id, "clear")
			end
		end
	end
	for _, r in ipairs(removed or {}) do
		removeAlly(r[1], r[2])
	end
end

function HFX.ClearAllies()
	for id in pairs(allyViews) do
		removeAlly(id, "clear")
	end
end

function HFX.Update(dt)
	local t = os.clock()
	local speed = Config.Settings.AllySpeed or 6
	for _, av in pairs(allyViews) do
		local rig = av.Rig
		local predicted = av.ServerDist - speed * math.min(t - av.LastSync, 0.35)
		av.Dist = av.Dist - speed * dt
		av.Dist = av.Dist + (predicted - av.Dist) * math.min(1, dt * 5)
		local pos, dir = PathUtil.OffsetPositionAt(math.max(av.Dist, 0), av.Lateral)
		local rise = math.clamp((t - av.SpawnT) / 0.4, 0, 1)
		local hip = rig.HipHeight
		local bob = math.abs(math.sin(t * 7 + av.Phase)) * 0.15
		rig.Root.CFrame = CFrame.lookAt(pos + V(0, hip + bob - (1 - rise) * 2, 0), pos - dir + V(0, hip + bob - (1 - rise) * 2, 0))
		-- ходьба: руки и ноги машут навстречу
		local swing = math.sin(t * 7 + av.Phase) * 32
		local base = rig.Base
		local m = rig.Motors
		if m.RH and base.RH then
			m.RH.C0 = base.RH * ANG(rad(swing), 0, 0)
			m.LH.C0 = base.LH * ANG(rad(-swing), 0, 0)
		end
		if m.RS and base.RS then
			m.RS.C0 = base.RS * ANG(rad(-swing * 0.7), 0, 0)
			m.LS.C0 = base.LS * ANG(rad(swing * 0.7), 0, 0)
		end
		if av.Fill then
			av.Fill.Size = UDim2.fromScale(math.clamp(av.HP / math.max(av.MaxHP, 1), 0, 1), 1)
		end
	end
end

function HFX.Init(c, renderer)
	ctx = c
	Config, PathUtil, UnitModels, FX = c.Config, c.PathUtil, c.UnitModels, c.FX
	Renderer = renderer
	allyFolder = Instance.new("Folder")
	allyFolder.Name = "VoidTD_Allies"
	allyFolder.Parent = workspace
	installProjectiles()
end

return HFX
]======] }
FILES[#FILES + 1] = { "StarterPlayerScripts", { "VoidTDClient", "HalloweenAnims" }, "ModuleScript", [======[
--!nocheck
-- VOID TD :: HalloweenAnims (клиент)
-- Анимации хэллоуинских юнитов в формате Renderer: function(h) -> { { время, { Сустав = { x, y, z, dy } } }, ... }
-- Подключение: require(HalloweenAnims)(Anims, FIDGETS)

return function(Anims, FIDGETS)
	------------------------------------------------------------------------
	-- ОБЫЧНЫЕ АТАКИ (h = HitDelay)
	------------------------------------------------------------------------
	-- Ночной сторож: фонарь вперёд и вверх — вспышка
	Anims.Lantern = function(h)
		return {
			{ 0, {} },
			{ h * 0.7, { RS = { 125, 0, 0 }, LS = { 20, 0, -10 }, Root = { -4, 0, 0 } } },
			{ h, { RS = { 100, 0, 0 }, Root = { 4, 0, 0 } } },
			{ h + 0.25, { RS = { 80, 0, 0 } } },
			{ h + 0.55, {} },
		}
	end

	-- Могильщик: удар лопатой сверху вниз
	Anims.Shovel = function(h)
		return {
			{ 0, {} },
			{ h * 0.75, { RS = { 172, 0, 10 }, LS = { 40, 0, -10 }, Root = { -8, -10, 0, 0.1 } } },
			{ h, { RS = { 40, 0, -5 }, LS = { 25, 0, 0 }, Root = { 14, 10, 0, -0.2 } } },
			{ h + 0.3, { RS = { 30, 0, 0 }, Root = { 6, 0, 0 } } },
			{ h + 0.65, {} },
		}
	end

	-- Пугало: взмах рукой — вороны срываются с плеч
	Anims.Crows = function(h)
		return {
			{ 0, {} },
			{ h * 0.7, { RS = { 135, 0, 35 }, LS = { 60, 0, -40 }, Neck = { -10, 0, 0 }, Root = { 0, -15, 0 } } },
			{ h, { RS = { 95, 0, -25 }, LS = { 50, 0, -20 }, Root = { 4, 15, 0 } } },
			{ h + 0.3, { RS = { 60, 0, -10 } } },
			{ h + 0.6, {} },
		}
	end

	-- Звонарь: колокол раскачивается — звон
	Anims.Bell = function(h)
		return {
			{ 0, {} },
			{ h * 0.5, { RS = { 95, 0, 35 }, Root = { 0, -8, 0 } } },
			{ h, { RS = { 112, 0, -25 }, Root = { 3, 8, 0 } } },
			{ h + 0.15, { RS = { 92, 0, 25 } } },
			{ h + 0.3, { RS = { 100, 0, -10 } } },
			{ h + 0.6, {} },
		}
	end

	-- Чумной доктор: бросок колбы из-за плеча
	Anims.Flask = function(h)
		return {
			{ 0, {} },
			{ h * 0.7, { RS = { 165, 0, 15 }, LS = { 30, 0, -15 }, Root = { -6, -18, 0 } } },
			{ h, { RS = { 60, 0, -15 }, Root = { 8, 15, 0 } } },
			{ h + 0.3, { RS = { 45, 0, 0 } } },
			{ h + 0.6, {} },
		}
	end

	-- Призрачный рыцарь: широкий горизонтальный разрез
	Anims.GhostSlash = function(h)
		return {
			{ 0, {} },
			{ h * 0.75, { RS = { 125, 0, 45 }, LS = { 30, 0, -15 }, Root = { -4, -30, 0 } } },
			{ h, { RS = { 80, 0, -65 }, LS = { 20, 0, -5 }, Root = { 6, 30, 0, -0.1 } } },
			{ h + 0.25, { RS = { 50, 0, -40 }, Root = { 3, 15, 0 } } },
			{ h + 0.6, {} },
		}
	end

	-- Иллюзионист: щелчок кистью — веер карт
	Anims.Cards = function(h)
		return {
			{ 0, {} },
			{ h * 0.6, { RS = { 65, 0, 45 }, Root = { 0, -12, 0 } } },
			{ h, { RS = { 98, 0, -35 }, Root = { 0, 12, 0 } } },
			{ h + 0.12, { RS = { 92, 0, -40 } } },
			{ h + 0.45, {} },
		}
	end

	-- Палач: двуручный удар топором сверху
	Anims.ExecAxe = function(h)
		return {
			{ 0, {} },
			{ h * 0.8, { RS = { 176, 0, 5 }, LS = { 166, 0, -5 }, Root = { -10, 0, 0, 0.2 } } },
			{ h, { RS = { 35, 0, 0 }, LS = { 35, 0, 0 }, Root = { 20, 0, 0, -0.4 } } },
			{ h + 0.35, { RS = { 30, 0, 0 }, LS = { 30, 0, 0 }, Root = { 14, 0, 0, -0.3 } } },
			{ h + 0.8, {} },
		}
	end

	-- Король фонарей: посох вверх и вперёд — огненная тыква
	Anims.LanternStaff = function(h)
		return {
			{ 0, {} },
			{ h * 0.7, { RS = { 145, 0, 5 }, LS = { 30, 0, -20 }, Neck = { -8, 0, 0 } } },
			{ h, { RS = { 95, 0, 0 }, LS = { 25, 0, -10 }, Root = { 5, 0, 0 } } },
			{ h + 0.3, { RS = { 80, 0, 0 } } },
			{ h + 0.6, {} },
		}
	end

	------------------------------------------------------------------------
	-- СПОСОБНОСТИ (удар — в указанное время)
	------------------------------------------------------------------------
	-- Луч фонаря: фонарь высоко над головой (вспышка ~0.45 с)
	Anims.LanternBeam = function()
		return {
			{ 0, {} },
			{ 0.35, { RS = { 172, 0, 0 }, LS = { 30, 0, -20 }, Neck = { -15, 0, 0 }, Root = { -4, 0, 0, 0.15 } } },
			{ 0.8, { RS = { 168, 0, 0 }, LS = { 30, 0, -20 }, Neck = { -12, 0, 0 }, Root = { -3, 0, 0, 0.1 } } },
			{ 1.1, {} },
		}
	end

	-- Взрыв земли: прыжок и удар лопатой в землю (~0.45 с)
	Anims.DirtBurst = function()
		return {
			{ 0, {} },
			{ 0.3, { RS = { 176, 0, 8 }, LS = { 150, 0, -8 }, Root = { -10, 0, 0, 0.45 } } },
			{ 0.45, { RS = { 15, 0, 0 }, LS = { 25, 0, 0 }, Root = { 22, 0, 0, -0.45 } } },
			{ 0.85, { RS = { 15, 0, 0 }, LS = { 25, 0, 0 }, Root = { 18, 0, 0, -0.35 } } },
			{ 1.2, {} },
		}
	end

	-- Вихрь листьев: руки в стороны, разворот корпусом (~0.5 с)
	Anims.LeafStorm = function()
		return {
			{ 0, {} },
			{ 0.25, { RS = { 95, 0, 70 }, LS = { 95, 0, -70 }, Root = { 0, -45, 0 } } },
			{ 0.5, { RS = { 110, 0, 60 }, LS = { 110, 0, -60 }, Neck = { -15, 0, 0 }, Root = { 0, 45, 0, 0.15 } } },
			{ 0.8, { RS = { 100, 0, 65 }, LS = { 100, 0, -65 }, Root = { 0, 0, 0, 0.1 } } },
			{ 1.1, {} },
		}
	end

	-- Метка проклятия: долгий прицел и выстрел (~0.45 с)
	Anims.CurseMark = function()
		return {
			{ 0, {} },
			{ 0.3, { RS = { 92, 0, 0 }, LS = { 88, 0, 15 }, Neck = { 5, 0, 0 }, Root = { 0, -10, 0 } } },
			{ 0.45, { RS = { 125, 0, 0 }, LS = { 95, 0, 15 }, Root = { -6, -10, 0 } } },
			{ 0.7, { RS = { 95, 0, 0 }, LS = { 70, 0, 10 } } },
			{ 1.0, {} },
		}
	end

	-- Полночный звон: колокол над головой и мощный удар вниз (~0.5 с)
	Anims.MidnightToll = function()
		return {
			{ 0, {} },
			{ 0.35, { RS = { 176, 0, 0 }, LS = { 120, 0, -20 }, Neck = { -20, 0, 0 }, Root = { -6, 0, 0, 0.2 } } },
			{ 0.5, { RS = { 55, 0, -20 }, LS = { 40, 0, 0 }, Neck = { 12, 0, 0 }, Root = { 16, 0, 0, -0.3 } } },
			{ 0.9, { RS = { 70, 0, 20 }, Root = { 8, 0, 0, -0.15 } } },
			{ 1.25, {} },
		}
	end

	-- Чумное облако: обе руки вверх и бросок двух колб (~0.55 с)
	Anims.PlagueCloud = function()
		return {
			{ 0, {} },
			{ 0.4, { RS = { 170, 0, 15 }, LS = { 170, 0, -15 }, Neck = { -15, 0, 0 }, Root = { -6, 0, 0, 0.1 } } },
			{ 0.55, { RS = { 75, 0, -10 }, LS = { 75, 0, 10 }, Root = { 10, 0, 0, -0.1 } } },
			{ 0.9, { RS = { 55, 0, 0 }, LS = { 45, 0, 0 } } },
			{ 1.2, {} },
		}
	end

	-- Призрачный меч: клинок к небу (призыв), затем удар вниз (~0.55 с)
	Anims.GhostSword = function()
		return {
			{ 0, {} },
			{ 0.4, { RS = { 178, 0, 0 }, LS = { 40, 0, -20 }, Neck = { -20, 0, 0 }, Root = { -6, 0, 0, 0.25 } } },
			{ 0.55, { RS = { 45, 0, 0 }, LS = { 30, 0, -10 }, Neck = { 10, 0, 0 }, Root = { 14, 0, 0, -0.25 } } },
			{ 0.95, { RS = { 40, 0, 0 }, Root = { 10, 0, 0, -0.2 } } },
			{ 1.3, {} },
		}
	end

	-- Зеркальный разлом: толчок обеими руками вперёд (~0.45 с)
	Anims.MirrorShatter = function()
		return {
			{ 0, {} },
			{ 0.3, { RS = { 80, 0, 35 }, LS = { 80, 0, -35 }, Root = { -5, 0, 0 } } },
			{ 0.45, { RS = { 96, 0, -8 }, LS = { 96, 0, 8 }, Root = { 8, 0, 0, -0.05 } } },
			{ 0.75, { RS = { 90, 0, -5 }, LS = { 90, 0, 5 } } },
			{ 1.0, {} },
		}
	end

	-- Разрыв нитей: руки широко вверх и резкий рывок вниз (~0.5 с)
	Anims.ThreadSnap = function()
		return {
			{ 0, {} },
			{ 0.35, { RS = { 155, 0, 45 }, LS = { 155, 0, -45 }, Neck = { -12, 0, 0 }, Root = { -5, 0, 0, 0.15 } } },
			{ 0.5, { RS = { 40, 0, 15 }, LS = { 40, 0, -15 }, Neck = { 10, 0, 0 }, Root = { 10, 0, 0, -0.15 } } },
			{ 0.8, { RS = { 55, 0, 20 }, LS = { 55, 0, -20 } } },
			{ 1.1, {} },
		}
	end

	-- Казнь: долгий замах с отклонением назад и страшный удар (~0.65 с)
	Anims.Execution = function()
		return {
			{ 0, {} },
			{ 0.5, { RS = { 178, 0, 5 }, LS = { 170, 0, -5 }, Neck = { -15, 0, 0 }, Root = { -14, 0, 0, 0.25 } } },
			{ 0.65, { RS = { 25, 0, 0 }, LS = { 25, 0, 0 }, Neck = { 15, 0, 0 }, Root = { 26, 0, 0, -0.55 } } },
			{ 1.1, { RS = { 25, 0, 0 }, LS = { 25, 0, 0 }, Root = { 22, 0, 0, -0.5 } } },
			{ 1.5, {} },
		}
	end

	-- Призрачная тыква: посох медленно вверх, затем вперёд (~0.8 с)
	Anims.GhostPumpkin = function()
		return {
			{ 0, {} },
			{ 0.55, { RS = { 176, 0, 0 }, LS = { 120, 0, -25 }, Neck = { -22, 0, 0 }, Root = { -8, 0, 0, 0.35 } } },
			{ 0.7, { RS = { 178, 0, 0 }, LS = { 125, 0, -25 }, Neck = { -24, 0, 0 }, Root = { -9, 0, 0, 0.4 } } },
			{ 0.8, { RS = { 100, 0, 0 }, LS = { 40, 0, -15 }, Neck = { 8, 0, 0 }, Root = { 12, 0, 0, -0.1 } } },
			{ 1.15, { RS = { 90, 0, 0 }, Root = { 6, 0, 0 } } },
			{ 1.45, {} },
		}
	end

	-- Призыв союзников: руки вверх над порталом (~1.2 с)
	Anims.Summon = function()
		return {
			{ 0, {} },
			{ 0.4, { RS = { 160, 0, 30 }, LS = { 160, 0, -30 }, Neck = { -18, 0, 0 }, Root = { -4, 0, 0, 0.2 } } },
			{ 0.9, { RS = { 165, 0, 25 }, LS = { 165, 0, -25 }, Neck = { -20, 0, 0 }, Root = { -4, 0, 0, 0.25 } } },
			{ 1.05, { RS = { 70, 0, 25 }, LS = { 70, 0, -25 }, Neck = { 8, 0, 0 }, Root = { 6, 0, 0, -0.05 } } },
			{ 1.3, {} },
		}
	end

	------------------------------------------------------------------------
	-- ДВИЖЕНИЯ В ПРОСТОЕ
	------------------------------------------------------------------------
	FIDGETS.Lantern = { "LookAround", "StaffTap" }
	FIDGETS.Shovel = { "Flex", "LookAround", "Stretch" }
	FIDGETS.Crows = { "LookAround", "Twirl" }
	FIDGETS.Bell = { "LookAround", "Stretch" }
	FIDGETS.Flask = { "LookAround", "Reload" }
	FIDGETS.GhostSlash = { "Twirl", "LookAround", "Flex" }
	FIDGETS.Cards = { "Twirl", "LookAround" }
	FIDGETS.ExecAxe = { "Flex", "LookAround" }
	FIDGETS.LanternStaff = { "StaffTap", "LookAround", "Stretch" }
end
]======] }
FILES[#FILES + 1] = { "StarterPlayerScripts", { "VoidTDClient", "Renderer" }, "ModuleScript", [======[
--!nocheck
-- VOID TD :: Renderer (клиент)
-- Визуализация врагов и юнитов: модели, плавное движение, анимации, полоски HP.

local RunService = game:GetService("RunService")

local Renderer = {}

local V = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles
local rad = math.rad

local ctx, Config, PathUtil, UnitModels, EnemyModels, FX
local HFX -- эффекты Хэллоуина (HalloweenFX)
local enemyFolder, unitFolder
local enemyViews = {}
local unitViews = {}
Renderer.EnemyViews = enemyViews
Renderer.UnitViews = unitViews

------------------------------------------------------------------------
-- АНИМАЦИИ ЮНИТОВ (ключевые кадры, углы в градусах)
------------------------------------------------------------------------
local Anims = {}

Anims.Slash = function(h)
	return {
		{ 0, {} },
		{ h * 0.75, { RS = { 150, 0, 12 }, Root = { 0, -15, 0 } } },
		{ h, { RS = { 25, 0, -12 }, LS = { -20, 0, 0 }, Root = { 4, 15, 0 } } },
		{ h + 0.2, { RS = { 15, 0, -5 } } },
		{ h + 0.5, {} },
	}
end

Anims.HeavySlash = function(h)
	return {
		{ 0, {} },
		{ h * 0.8, { RS = { 168, 0, 15 }, LS = { 40, 0, -10 }, Root = { -8, -22, 0 } } },
		{ h, { RS = { 18, 0, -15 }, LS = { 30, 0, 0 }, Root = { 12, 20, 0, -0.15 } } },
		{ h + 0.3, { RS = { 15, 0, -5 }, Root = { 6, 10, 0 } } },
		{ h + 0.65, {} },
	}
end

Anims.Bow = function(h)
	return {
		{ 0, {} },
		{ h * 0.6, { LS = { 90, 0, 0 }, RS = { 90, 0, -30 }, Root = { 0, -20, 0 } } },
		{ h, { LS = { 90, 0, 0 }, RS = { 75, 0, -65 }, Root = { 0, -20, 0 } } },
		{ h + 0.06, { LS = { 92, 0, 0 }, RS = { 95, 0, -15 }, Root = { 0, -20, 0 } } },
		{ h + 0.45, {} },
	}
end

Anims.Cast = function(h)
	return {
		{ 0, {} },
		{ h * 0.7, { RS = { 145, 0, 0 }, LS = { 30, 0, -20 }, Neck = { 12, 0, 0 } } },
		{ h, { RS = { 90, 0, 0 }, LS = { 55, 0, -25 } } },
		{ h + 0.45, {} },
	}
end

Anims.Gun = function(h)
	return {
		{ 0, {} },
		{ h, { RS = { 92, 0, 0 }, LS = { 88, 0, -30 } } },
		{ h + 0.05, { RS = { 104, 0, 0 }, LS = { 98, 0, -30 }, Root = { -5, 0, 0 } } },
		{ h + 0.18, { RS = { 92, 0, 0 }, LS = { 88, 0, -30 } } },
		{ h + 0.5, {} },
	}
end

Anims.Reap = function(h)
	return {
		{ 0, {} },
		{ h * 0.7, { RS = { 60, 0, 25 }, LS = { 50, 0, -10 }, Root = { 0, -70, 0 } } },
		{ h, { RS = { 75, 0, -15 }, LS = { 65, 0, 10 }, Root = { 6, 80, 0 } } },
		{ h + 0.25, { RS = { 60, 0, -10 }, Root = { 3, 60, 0 } } },
		{ h + 0.65, {} },
	}
end

Anims.Katana = function(h, hits, interval)
	local k = { { 0, {} }, { h * 0.7, { RS = { 125, 0, 40 }, Root = { 0, -25, 0 } } } }
	hits = hits or 1
	for i = 1, hits do
		local t = h + (i - 1) * (interval or 0.16)
		local dir = (i % 2 == 1) and 1 or -1
		k[#k + 1] = { t, { RS = { 45, 0, -50 * dir }, Root = { 4, 30 * dir, 0 } } }
		if i < hits then
			k[#k + 1] = { t + (interval or 0.16) * 0.6, { RS = { 120, 0, 40 * -dir }, Root = { 0, -20 * dir, 0 } } }
		end
	end
	local last = h + (hits - 1) * (interval or 0.16)
	k[#k + 1] = { last + 0.15, { RS = { 30, 0, -30 } } }
	k[#k + 1] = { last + 0.4, {} }
	return k
end

Anims.Slam = function(h)
	return {
		{ 0, {} },
		{ h * 0.65, { RS = { 172, 0, 10 }, LS = { 165, 0, -10 }, Root = { -10, 0, 0, 0.15 }, Neck = { -10, 0, 0 } } },
		{ h, { RS = { 55, 0, 0 }, LS = { 50, 0, 0 }, Root = { 16, 0, 0, -0.45 } } },
		{ h + 0.35, { RS = { 48, 0, 0 }, LS = { 45, 0, 0 }, Root = { 12, 0, 0, -0.35 } } },
		{ h + 0.85, {} },
	}
end

Anims.Beam = function(h)
	return {
		{ 0, {} },
		{ h * 0.6, { RS = { 55, 0, 0 }, Root = { -6, 0, 0 }, WingR = { 0, 25, 0 }, WingL = { 0, -25, 0 } } },
		{ h, { RS = { 96, 0, 0 }, LS = { 60, 0, -20 }, Root = { 4, 0, 0 }, WingR = { 0, -15, 10 }, WingL = { 0, 15, -10 } } },
		{ h + 0.45, { RS = { 94, 0, 0 }, LS = { 55, 0, -20 } } },
		{ h + 0.85, {} },
	}
end

Anims.Judgement = function(h, hits, interval)
	local hold = h + (hits or 3) * (interval or 0.18)
	return {
		{ 0, {} },
		{ h * 0.8, { RS = { 178, 0, 5 }, LS = { 35, 0, -35 }, Neck = { 18, 0, 0 }, Root = { -6, 0, 0, 0.2 } } },
		{ hold, { RS = { 172, 0, 5 }, LS = { 40, 0, -40 }, Neck = { 15, 0, 0 }, Root = { -4, 0, 0, 0.2 } } },
		{ hold + 0.2, { RS = { 40, 0, -10 }, Root = { 10, 0, 0 } } },
		{ hold + 0.6, {} },
	}
end

Anims.Smash = function(h)
	return {
		{ 0, {} },
		{ h * 0.7, { RS = { 160, 0, 10 }, Root = { -8, -18, 0 } } },
		{ h, { RS = { 40, 0, -10 }, LS = { 30, 0, 0 }, Root = { 14, 18, 0, -0.3 } } },
		{ h + 0.45, {} },
	}
end

Anims.BlackHoleCast = function(h)
	return {
		{ 0, {} },
		{ h * 0.7, { RS = { 150, 0, 30 }, LS = { 150, 0, -30 }, Neck = { 25, 0, 0 }, Root = { -8, 0, 0, 0.2 } } },
		{ h, { RS = { 110, 0, 40 }, LS = { 110, 0, -40 }, Root = { 6, 0, 0 } } },
		{ h + 0.5, {} },
	}
end

-- Анимации в простое (fidget), повышения уровня, празднования и приземления
Anims.LookAround = function()
	return { { 0, {} }, { 0.5, { Neck = { 0, 40, 0 } } }, { 1.2, { Neck = { 5, -40, 0 } } }, { 1.8, {} } }
end

Anims.Twirl = function()
	return {
		{ 0, {} },
		{ 0.25, { RS = { 85, 0, 0 } } },
		{ 0.45, { RS = { 85, 120, 0 } } },
		{ 0.65, { RS = { 85, 240, 0 } } },
		{ 0.85, { RS = { 85, 360, 0 } } },
		{ 1.2, { RS = { 15, 360, 0 } } },
	}
end

Anims.Flex = function()
	return {
		{ 0, {} },
		{ 0.35, { RS = { 0, 0, 95 }, LS = { 0, 0, -95 }, Root = { -4, 0, 0 } } },
		{ 0.6, { RS = { 0, 0, 80 }, LS = { 0, 0, -80 }, Root = { -6, 0, 0, 0.1 } } },
		{ 1.1, {} },
	}
end

Anims.Stretch = function()
	return {
		{ 0, {} },
		{ 0.5, { RS = { 170, 0, 15 }, LS = { 170, 0, -15 }, Root = { -8, 0, 0, 0.15 }, Neck = { -15, 0, 0 } } },
		{ 1.1, { RS = { 165, 0, 20 }, LS = { 165, 0, -20 }, Root = { -6, 0, 0, 0.1 }, Neck = { -10, 0, 0 } } },
		{ 1.6, {} },
	}
end

Anims.StaffTap = function()
	return {
		{ 0, {} },
		{ 0.25, { RS = { 35, 0, 0 } } },
		{ 0.4, { RS = { -5, 0, 0 }, Root = { 0, 0, 0, -0.08 } } },
		{ 0.55, { RS = { 25, 0, 0 } } },
		{ 0.7, { RS = { -5, 0, 0 }, Root = { 0, 0, 0, -0.08 } } },
		{ 1.1, {} },
	}
end

Anims.CheckBow = function()
	return {
		{ 0, {} },
		{ 0.4, { LS = { 75, 0, 35 }, Neck = { 20, -25, 0 }, RS = { 40, 0, -20 } } },
		{ 1.3, { LS = { 70, 0, 30 }, Neck = { 22, -20, 0 }, RS = { 45, 0, -25 } } },
		{ 1.7, {} },
	}
end

Anims.Reload = function()
	return {
		{ 0, {} },
		{ 0.3, { RS = { 45, 0, -30 }, LS = { 60, 0, 25 }, Neck = { 25, 0, 0 } } },
		{ 0.5, { RS = { 45, 0, -30 }, LS = { 40, 0, 10 }, Neck = { 25, 0, 0 } } },
		{ 0.7, { RS = { 45, 0, -30 }, LS = { 65, 0, 25 }, Neck = { 25, 0, 0 } } },
		{ 1.2, {} },
	}
end

Anims.WingSpread = function()
	return {
		{ 0, {} },
		{ 0.4, { WingR = { 0, -35, 20 }, WingL = { 0, 35, -20 }, Neck = { -15, 0, 0 }, Root = { 0, 0, 0, 0.3 } } },
		{ 1.0, { WingR = { 0, -30, 15 }, WingL = { 0, 30, -15 }, Neck = { -10, 0, 0 }, Root = { 0, 0, 0, 0.25 } } },
		{ 1.5, {} },
	}
end

Anims.Cheer = function()
	return {
		{ 0, {} },
		{ 0.2, { RS = { 165, 0, 25 }, LS = { 165, 0, -25 }, Root = { 0, 0, 0, 0.6 } } },
		{ 0.4, { RS = { 150, 0, 30 }, LS = { 150, 0, -30 }, Root = { 0, 0, 0, 0 } } },
		{ 0.6, { RS = { 165, 0, 25 }, LS = { 165, 0, -25 }, Root = { 0, 0, 0, 0.6 } } },
		{ 0.8, { RS = { 150, 0, 30 }, LS = { 150, 0, -30 }, Root = { 0, 0, 0, 0 } } },
		{ 1.2, {} },
	}
end

Anims.PowerUp = function()
	return {
		{ 0, {} },
		{ 0.25, { Root = { 12, 0, 0, -0.45 }, RS = { 30, 0, 35 }, LS = { 30, 0, -35 }, Neck = { 15, 0, 0 } } },
		{ 0.5, { Root = { -10, 0, 0, 0.6 }, RS = { 160, 0, 40 }, LS = { 160, 0, -40 }, Neck = { -20, 0, 0 } } },
		{ 0.9, { Root = { -6, 0, 0, 0.3 }, RS = { 150, 0, 35 }, LS = { 150, 0, -35 } } },
		{ 1.3, {} },
	}
end

Anims.Land = function()
	return {
		{ 0, { Root = { 10, 0, 0, -0.45 }, RS = { 20, 0, 45 }, LS = { 20, 0, -45 } } },
		{ 0.45, {} },
	}
end

-- анимации новых юнитов
Anims.DualDagger = function(h)
	return {
		{ 0, {} },
		{ h * 0.6, { RS = { 110, 0, 20 }, LS = { 40, 0, -10 }, Root = { 0, -20, 0 } } },
		{ h, { RS = { 60, 0, -20 }, LS = { 100, 0, -20 }, Root = { 4, 20, 0 } } },
		{ h + 0.12, { RS = { 75, 0, 0 }, LS = { 70, 0, 0 } } },
		{ h + 0.3, {} },
	}
end
Anims.Crossbow = function(h)
	return {
		{ 0, {} },
		{ h, { RS = { 88, 0, 0 }, LS = { 82, 0, -28 }, Neck = { 6, 0, 0 } } },
		{ h + 0.06, { RS = { 105, 0, 0 }, LS = { 96, 0, -28 }, Root = { -6, 0, 0 } } },
		{ h + 0.3, { RS = { 88, 0, 0 }, LS = { 82, 0, -28 } } },
		{ h + 0.6, {} },
	}
end
Anims.Puppet = function(h)
	return {
		{ 0, {} },
		{ h * 0.7, { RS = { 85, 0, 35 }, LS = { 85, 0, -35 }, Neck = { 10, 0, 0 } } },
		{ h, { RS = { 105, 0, 12 }, LS = { 105, 0, -12 } } },
		{ h + 0.15, { RS = { 90, 0, 28 }, LS = { 90, 0, -28 } } },
		{ h + 0.5, {} },
	}
end
Anims.Hammer = Anims.Slam
Anims.RiftStorm = Anims.Judgement
Anims.RedSplash = Anims.HeavySlash
Anims.Sickle = Anims.Slash

-- ПРОКЛЯТЫЙ ЧАСОВЩИК
-- Разрез секунд: замах Хроносекирой из-за плеча и мощный горизонтальный взмах
Anims.ChronoSlash = function(h)
	return {
		{ 0, {} },
		{ h * 0.75, { RS = { 160, 0, 35 }, LS = { 40, 0, -20 }, Root = { -4, -28, 0 } } },
		{ h, { RS = { 70, 0, -70 }, LS = { 20, 0, -10 }, Root = { 6, 32, 0, -0.1 } } },
		{ h + 0.25, { RS = { 45, 0, -40 }, Root = { 3, 18, 0 } } },
		{ h + 0.6, {} },
	}
end
-- Поломка времени: Хроносекира над головой, затем удар о землю
Anims.TimeBreak = function()
	return {
		{ 0, {} },
		{ 0.35, { RS = { 175, 0, 5 }, LS = { 165, 0, -5 }, Neck = { -15, 0, 0 }, Root = { -8, 0, 0, 0.3 } } },
		{ 0.5, { RS = { 30, 0, 0 }, LS = { 30, 0, 0 }, Neck = { 15, 0, 0 }, Root = { 20, 0, 0, -0.45 } } },
		{ 0.95, { RS = { 30, 0, 0 }, LS = { 30, 0, 0 }, Root = { 16, 0, 0, -0.4 } } },
		{ 1.35, {} },
	}
end
-- Ускорение времени: Хроносекира вертикально вверх
Anims.TimeHaste = function()
	return {
		{ 0, {} },
		{ 0.4, { RS = { 178, 0, 0 }, Neck = { -18, 0, 0 }, Root = { 0, 0, 0, 0.25 } } },
		{ 1.1, { RS = { 178, 0, 0 }, Neck = { -18, 0, 0 }, Root = { 0, 0, 0, 0.25 } } },
		{ 1.5, {} },
	}
end
-- Временная буря: медленный подъём оружия, вспышка, удар о землю
Anims.TimeStorm = function()
	return {
		{ 0, {} },
		{ 0.9, { RS = { 172, 0, 10 }, LS = { 150, 0, -15 }, Neck = { -22, 0, 0 }, Root = { -8, 0, 0, 0.4 } } },
		{ 1.15, { RS = { 176, 0, 10 }, LS = { 155, 0, -15 }, Neck = { -24, 0, 0 }, Root = { -9, 0, 0, 0.45 } } },
		{ 1.3, { RS = { 25, 0, 0 }, LS = { 25, 0, 0 }, Neck = { 18, 0, 0 }, Root = { 22, 0, 0, -0.55 } } },
		{ 1.8, { RS = { 25, 0, 0 }, LS = { 25, 0, 0 }, Root = { 15, 0, 0, -0.4 } } },
		{ 2.2, {} },
	}
end
Anims.Axe = Anims.HeavySlash
Anims.Revolver = function(h)
	return {
		{ 0, {} },
		{ h, { RS = { 95, 0, 0 }, LS = { 70, 0, 0 } } },
		{ h + 0.05, { RS = { 112, 0, 0 }, LS = { 70, 0, 0 }, Root = { -3, 0, 0 } } },
		{ h + 0.12, { RS = { 92, 0, 0 }, LS = { 95, 0, 0 } } },
		{ h + 0.17, { RS = { 92, 0, 0 }, LS = { 112, 0, 0 }, Root = { -3, 0, 0 } } },
		{ h + 0.45, {} },
	}
end

local FIDGETS = {
	ChronoSlash = { "LookAround", "Flex", "Twirl" },
	DualDagger = { "Twirl", "LookAround", "Flex" },
	Crossbow = { "Reload", "LookAround" },
	Puppet = { "Stretch", "LookAround" },
	Hammer = { "Flex", "Stretch", "LookAround" },
	RiftStorm = { "LookAround", "Stretch" },
	RedSplash = { "Twirl", "Flex" },
	Sickle = { "Twirl", "LookAround" },
	Revolver = { "Twirl", "Reload" },
	Axe = { "Flex", "LookAround" },
	Slash = { "Twirl", "LookAround", "Flex" },
	HeavySlash = { "Twirl", "LookAround", "Stretch" },
	Katana = { "Twirl", "LookAround" },
	Judgement = { "Twirl", "LookAround", "Flex" },
	Bow = { "CheckBow", "LookAround" },
	Cast = { "StaffTap", "LookAround", "Stretch" },
	Gun = { "Reload", "LookAround" },
	Reap = { "Twirl", "LookAround" },
	Slam = { "Flex", "LookAround", "Stretch" },
	Smash = { "Flex", "LookAround" },
	Beam = { "WingSpread", "LookAround", "Stretch" },
}

local function ease(a)
	return a * a * (3 - 2 * a)
end

local function getAngle(pose, idle, joint)
	return pose[joint] or idle[joint]
end

local function evalPose(view, t)
	local idle = view.Rig.Idle
	local anim = view.Anim
	if not anim then
		return idle
	end
	local el = t - anim.Start
	local frames = anim.Frames
	if el >= frames[#frames][1] then
		view.Anim = nil
		return idle
	end
	local k = 1
	for i = 1, #frames - 1 do
		if el >= frames[i][1] then
			k = i
		end
	end
	local f0, f1 = frames[k], frames[k + 1]
	local span = math.max(f1[1] - f0[1], 0.001)
	local a = ease(math.clamp((el - f0[1]) / span, 0, 1))
	local out = {}
	local joints = {}
	for j in pairs(f0[2]) do
		joints[j] = true
	end
	for j in pairs(f1[2]) do
		joints[j] = true
	end
	for j in pairs(idle) do
		joints[j] = true
	end
	for j in pairs(joints) do
		local p0 = getAngle(f0[2], idle, j) or { 0, 0, 0, 0 }
		local p1 = getAngle(f1[2], idle, j) or { 0, 0, 0, 0 }
		out[j] = {
			p0[1] + (p1[1] - p0[1]) * a,
			p0[2] + (p1[2] - p0[2]) * a,
			p0[3] + (p1[3] - p0[3]) * a,
			(p0[4] or 0) + ((p1[4] or 0) - (p0[4] or 0)) * a,
		}
	end
	return out
end

local function applyPose(rig, pose, t, phase)
	local base = rig.Base
	local s = rig.Scale or 1
	local breathe = math.sin(t * 2 + phase)
	-- стрелки и шестерёнки (Clock*/Gear*) крутятся; во время способностей и бури — быстрее
	local spinDt = 0
	if rig.SpinRates then
		spinDt = math.clamp(t - (rig.SpinT or t), 0, 0.1)
		rig.SpinT = t
		rig.SpinAngle = rig.SpinAngle or {}
		local boost = rig.Storm and 3 or 1
		if os.clock() < (rig.SpinBoostUntil or 0) then
			boost = math.max(boost, 6)
		end
		spinDt = spinDt * boost
	end
	for name, motor in pairs(rig.Motors) do
		local b = base[name]
		if b then
			local p = pose[name]
			local cf = b
			if name == "Root" then
				local dy = (p and p[4] or 0) * s + breathe * 0.04 * s
				cf = b * CF(0, dy, 0)
			end
			if p then
				cf = cf * ANG(rad(p[1]), rad(p[2]), rad(p[3]))
			end
			if name == "RS" or name == "LS" then
				local side = name == "RS" and 1 or -1
				cf = cf * ANG(rad(breathe * 2), 0, rad(breathe * 1.5 * side))
			elseif name:sub(1, 4) == "Wing" then
				local side = name:sub(5, 5) == "R" and 1 or -1
				cf = cf * ANG(0, math.sin(t * 2.4 + phase) * 0.12 * side, math.sin(t * 2.4 + phase) * 0.1 * side)
			elseif name == "Neck" then
				cf = cf * ANG(0, math.sin(t * 0.7 + phase) * 0.08, 0)
			elseif name == "Cape" or name == "Scarf" then
				local gust = (rig.Gust or 0)
				cf = cf * ANG(rad(6 + math.sin(t * 1.7 + phase) * 4 + gust * 22), 0, rad(math.sin(t * 1.1 + phase) * 3))
			elseif name == "Cape2" then
				-- нижняя часть плаща догоняет верхнюю с запаздыванием
				local gust = (rig.Gust or 0)
				cf = cf * ANG(rad(5 + math.sin(t * 1.7 + phase - 0.8) * 7 + gust * 28), 0, rad(math.sin(t * 1.1 + phase - 0.6) * 5))
			elseif name:sub(1, 5) == "Orbit" then
				cf = cf * ANG(0, t * 1.4 + phase, 0)
			elseif rig.SpinRates and rig.SpinRates[name] then
				local ang = (rig.SpinAngle[name] or 0) - rig.SpinRates[name] * spinDt
				rig.SpinAngle[name] = ang
				cf = cf * ANG(0, 0, ang)
			end
			motor.C0 = cf
		end
	end
end

------------------------------------------------------------------------
-- ВРАГИ
------------------------------------------------------------------------
local function makeHealthBar(view)
	local def = Config.Enemies[view.Type]
	local gui = Instance.new("BillboardGui")
	gui.Name = "HPBar"
	gui.Size = UDim2.fromOffset(def.IsBoss and 120 or 60, def.IsBoss and 12 or 7)
	gui.StudsOffsetWorldSpace = V(0, view.Rig.Height - view.Rig.HipHeight + 1.2, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 180
	gui.LightInfluence = 0
	gui.Adornee = view.Rig.Root
	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Color3.fromRGB(20, 10, 25)
	bg.BorderSizePixel = 0
	bg.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 3)
	corner.Parent = bg
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = def.IsBoss and Color3.fromRGB(235, 50, 130) or Color3.fromRGB(190, 80, 255)
	fill.BorderSizePixel = 0
	fill.Parent = bg
	local c2 = corner:Clone()
	c2.Parent = fill
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(0, 0, 0)
	stroke.Thickness = 1
	stroke.Parent = bg
	gui.Parent = view.Rig.Root
	view.Fill = fill
end

------------------------------------------------------------------------
-- ВТОРИЧНОЕ ДВИЖЕНИЕ (по префиксу имени мотора, см. EnemyModels)
------------------------------------------------------------------------
local SEC_KINDS = { "Sway", "Cape", "Orbit", "Spin", "Bob", "Twitch" }
local LOD_DISTANCE = 200 -- дальше этого от камеры вторичная анимация не считается

local function collectSecondary(rig)
	local list = {}
	for name, motor in pairs(rig.Motors) do
		for _, kind in ipairs(SEC_KINDS) do
			if name:sub(1, #kind) == kind and rig.Base[name] then
				local p = (rig.Sec and rig.Sec[name]) or {}
				list[#list + 1] = { Motor = motor, Base = rig.Base[name], Kind = kind, Amp = p.Amp or 0.2, Speed = p.Speed or 1.5, Phase = math.random() * 6 }
				break
			end
		end
	end
	return list
end

local function applySecondary(view, t, dt)
	local sc = view.Rig.Scale or 1
	local aggro = view.Aggro or 1
	for _, s in ipairs(view.Sec) do
		local k, ph = s.Kind, s.Phase
		local cf
		if k == "Sway" or k == "Cape" then
			local sp = s.Speed * (0.8 + 0.2 * aggro)
			cf = s.Base * ANG(math.sin(t * sp + ph) * s.Amp + (k == "Cape" and s.Amp * 0.8 or 0), 0, math.sin(t * sp * 0.7 + ph) * s.Amp * 0.5)
		elseif k == "Orbit" then
			cf = s.Base * ANG(0, t * s.Speed * aggro + ph, 0)
		elseif k == "Spin" then
			cf = s.Base * ANG(0, 0, t * s.Speed * aggro + ph)
		elseif k == "Bob" then
			cf = s.Base * CF(0, math.sin(t * s.Speed + ph) * s.Amp * sc, 0) * ANG(0, math.sin(t * s.Speed * 0.5 + ph) * 0.25, 0)
		else -- Twitch: резкий поворот к случайной цели, пауза, снова рывок
			if t >= (s.Next or 0) then
				s.Next = t + 0.25 + math.random() * 0.7
				s.TY = (math.random() * 2 - 1) * s.Amp
				s.TP = (math.random() * 2 - 1) * s.Amp * 0.5
			end
			local a = math.min(1, dt * 22)
			s.Y = (s.Y or 0) + ((s.TY or 0) - (s.Y or 0)) * a
			s.P = (s.P or 0) + ((s.TP or 0) - (s.P or 0)) * a
			cf = s.Base * ANG(s.P, s.Y, 0)
		end
		s.Motor.C0 = cf
	end
end

------------------------------------------------------------------------
-- ВИЗУАЛЬНЫЕ ФАЗЫ БОССОВ (только внешний вид, без новых способностей)
------------------------------------------------------------------------
local function groundOf(view)
	return view.Rig.Root.Position - V(0, view.Rig.HipHeight - 0.3, 0)
end

-- Деталь отрывается от модели и падает на землю
local function breakPart(view, p, silent)
	if not p or not p.Parent then
		return
	end
	local cf = p.CFrame
	for _, w in ipairs(p:GetChildren()) do
		if w:IsA("Weld") then
			w:Destroy()
		end
	end
	if silent or FX.Lite then
		p:Destroy()
		return
	end
	p.Anchored = true
	p.CFrame = cf
	p.Parent = workspace:FindFirstChild("VoidTD_FX") or workspace
	local root = view.Rig.Root.Position
	local out = V(cf.Position.X - root.X, 0, cf.Position.Z - root.Z)
	out = out.Magnitude > 0.01 and out.Unit or V(0, 0, 1)
	local groundY = root.Y - view.Rig.HipHeight + p.Size.Y * 0.3
	local dest = V(cf.Position.X, groundY, cf.Position.Z) + out * (2 + math.random() * 4)
	FX.Tween(p, 0.35, { CFrame = cf + out * 1.5 + V(0, 1.5, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	task.delay(0.35, function()
		if p.Parent then
			FX.Tween(p, 0.6, { CFrame = CF(dest) * ANG(math.random() * 3, math.random() * 3, math.random() * 3) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		end
	end)
	task.delay(1.6, function()
		if p.Parent then
			FX.Tween(p, 0.8, { Transparency = 1 })
		end
	end)
	task.delay(2.5, function()
		p:Destroy()
	end)
end

local function applyPhase(view, idx, silent)
	local ph = view.Rig.Phases[idx]
	view.VisualPhase = idx + 1
	view.Aggro = ph.Aggro or view.Aggro
	for _, p in ipairs(ph.Reveal or {}) do
		local target = p:GetAttribute("PT") or 0
		if silent or FX.Lite then
			p.Transparency = target
		else
			FX.Tween(p, 0.6, { Transparency = target })
		end
	end
	for _, e in ipairs(ph.Emit or {}) do
		if e then
			if e.Enabled then
				e.Rate = e.Rate * 1.8
			else
				e.Enabled = true
			end
		end
	end
	for _, l in ipairs(ph.Lights or {}) do
		if l[1] then
			l[1].Brightness = l[2]
			l[1].Range = l[1].Range * 1.25
		end
	end
	for _, p in ipairs(ph.Break or {}) do
		breakPart(view, p, silent)
	end
	if silent then
		return
	end
	-- переход: рёв, волна энергии, вспышка
	local sc = view.Rig.Scale or 1
	local center = Renderer.EnemyCenter(view.Id) or view.Rig.Root.Position
	view.RoarT = os.clock()
	FX.Sound("Boss", 1, 0.8 + idx * 0.12, center)
	FX.Shake(0.3 + idx * 0.15, 0.6)
	FX.Ring(groundOf(view), 8 * sc, FX.Colors.Neon, 0.8, 0.5, 1, 0.05)
	FX.Sphere(center, 2.5 * sc, FX.Colors.Soft, 0.5)
	FX.Burst(center, FX.Colors.Neon, 16, 0.4 * sc, 9 * sc, 0.7)
end

local function checkPhases(view, silent)
	local phases = view.Rig.Phases
	if not phases then
		return
	end
	local ratio = view.HP / math.max(view.MaxHP, 1)
	while phases[view.NextPhase] and ratio <= phases[view.NextPhase].At do
		applyPhase(view, view.NextPhase, silent)
		view.NextPhase = view.NextPhase + 1
	end
end

------------------------------------------------------------------------
-- ПОЯВЛЕНИЕ
------------------------------------------------------------------------
-- Вступление босса: портал вспыхивает, по земле идёт волна энергии
local function activeMap()
	return workspace:FindFirstChild(PathUtil.MapKey == "Halloween" and "VoidTDHalloweenMap" or "VoidTDMap")
end
Renderer.ActiveMap = activeMap

local function portalSurge(isFinal)
	local map = activeMap()
	local portal = map and map:FindFirstChild("VoidPortal")
	if not portal then
		return
	end
	local disc = portal:FindFirstChild("PortalDisc")
	local core = portal:FindFirstChild("PortalCore")
	local light = core and core:FindFirstChildOfClass("PointLight")
	if light then
		local b = light.Brightness
		light.Brightness = b * 3
		FX.Tween(light, 1.8, { Brightness = b })
	end
	if disc then
		local col = disc.Color
		disc.Color = Color3.fromRGB(235, 200, 255)
		FX.Tween(disc, 1.2, { Color = col })
		local pos = disc.Position
		local gy = PathUtil.Map.GroundY
		FX.Sphere(pos, isFinal and 16 or 11, FX.Colors.Neon, 0.8, nil, 0.3)
		FX.Ring(V(pos.X, gy + 0.3, pos.Z), isFinal and 45 or 30, FX.Colors.Neon, 1.1, 0.6, 3, 0.05)
		task.delay(0.15, function()
			FX.Ring(V(pos.X, gy + 0.4, pos.Z), isFinal and 32 or 22, FX.Colors.White, 0.9, 0.3, 2, 0.2)
		end)
		FX.Burst(pos, FX.Colors.Soft, isFinal and 30 or 18, 0.7, 18, 0.9)
	end
	FX.Sound("Portal", 1.2, isFinal and 0.7 or 0.85)
end

function Renderer.SpawnEnemy(data)
	local id, typeId, maxHp, speed, lateral, dist, hp = data[1], data[2], data[3], data[4], data[5], data[6], data[7]
	if enemyViews[id] then
		return
	end
	local ok, rig = pcall(EnemyModels.Build, typeId)
	if not ok then
		warn(rig)
		return
	end
	local def = Config.Enemies[typeId]
	local view = {
		Id = id,
		Type = typeId,
		Rig = rig,
		MaxHP = maxHp,
		HP = hp or maxHp,
		Speed = speed,
		Lateral = lateral,
		Dist = dist,
		ServerDist = dist,
		LastSync = os.clock(),
		Slowed = false,
		Phase = math.random() * 10,
		Aggro = 1,
		NextPhase = 1,
		VisualPhase = 1,
	}
	view.Sec = collectSecondary(rig)
	local pos, dir = PathUtil.OffsetPositionAt(dist, lateral)
	view.CF = CFrame.lookAt(pos + V(0, rig.HipHeight, 0), pos + dir + V(0, rig.HipHeight, 0))
	view.SpawnT = os.clock()
	view.Emerge = dist <= 1
	-- если враг пришёл уже раненым (переподключение) — фазы применяются без эффектов
	checkPhases(view, true)
	if def.IsBoss then
		view.RoarT = os.clock() + (rig.SpawnStyle == "Titan" and 1.1 or 0.6)
		if dist <= 1 then
			portalSurge(typeId == "TheEntity")
		end
		task.delay(0.6, function()
			FX.Sound("Boss", 1, typeId == "TheEntity" and 0.75 or 1)
			FX.Shake(typeId == "TheEntity" and 0.8 or 0.5, 1.0)
		end)
	end
	-- появление из дыма: прозрачность плавно возвращается
	if rig.SpawnStyle == "Fade" and not FX.Lite then
		view.FadeParts = {}
		for _, d in ipairs(rig.Model:GetDescendants()) do
			if d:IsA("BasePart") and d.Transparency < 1 then
				view.FadeParts[#view.FadeParts + 1] = { d, d.Transparency }
				d.Transparency = 1
			end
		end
	end
	rig.Root.CFrame = view.CF
	makeHealthBar(view)
	rig.Model.Parent = enemyFolder
	enemyViews[id] = view
	if rig.SpawnFX then
		HFX.EnemySpawn(view, dist <= 1)
	end
	if dist <= 1 then
		FX.Burst(pos + V(0, 2, 0), FX.Colors.Neon, 6, 0.3, 5)
		if rig.SpawnStyle == "Titan" then
			-- мини-босс выбирается из земли и выпрямляется, кристалл в груди вспыхивает
			FX.Cracks(pos + V(0, 0.2, 0), 7, FX.Colors.Neon, 10, 1.6)
			task.delay(1.1, function()
				local c = Renderer.EnemyCenter(id)
				if c then
					FX.Sphere(c, 4, FX.Colors.Neon, 0.5)
					FX.Burst(c, FX.Colors.Soft, 14, 0.5, 10, 0.6)
				end
			end)
		end
	end
end

function Renderer.EnemyPosition(id)
	local v = enemyViews[id]
	if v then
		return v.Rig.Root.Position
	end
	return nil
end

function Renderer.EnemyCenter(id)
	local v = enemyViews[id]
	if v then
		return v.Rig.Root.Position + V(0, (v.Rig.Height - v.Rig.HipHeight) * 0.35, 0)
	end
	return nil
end

------------------------------------------------------------------------
-- СМЕРТЬ (своя анимация для каждого типа)
------------------------------------------------------------------------
local DEATH_LIFE = { Dissipate = 0.7, Scatter = 0.85, Collapse = 0.75, Topple = 1.0, Implode = 2.4 }
local LEGS = { FR = 1, BR = 1, FL = -1, BL = -1 }

local function deathAnim(view, reason)
	local rig = view.Rig
	local model = rig.Model
	local root = rig.Root
	local gui = root:FindFirstChild("HPBar")
	if gui then
		gui:Destroy()
	end
	local def = Config.Enemies[view.Type]
	local size = def.Scale or 1
	if reason == "core" then
		FX.Poof(root.Position, FX.Colors.Pink, size)
		model:Destroy()
		return
	end
	local style = rig.DeathStyle or "Topple"
	local sc = rig.Scale or 1
	local hip = rig.HipHeight
	if style ~= "Implode" then
		FX.Poof(root.Position + V(0, 0.5, 0), FX.Colors.Neon, size)
	end
	FX.Sound("EnemyDeath", 1, 1 / math.max(size, 0.6), root.Position)
	if def.IsBoss and style ~= "Implode" then
		FX.Shockwave(root.Position - V(0, hip - 0.2, 0), 10 * size, 5)
	end
	local start = os.clock()
	local startCF = root.CFrame
	local life = DEATH_LIFE[style] or 1
	if def.IsBoss and style == "Topple" then
		life = 1.5
	end
	local parts = {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and d.Transparency < 1 then
			parts[#parts + 1] = { d, d.Transparency }
		elseif d:IsA("ParticleEmitter") or d:IsA("Trail") then
			d.Enabled = false
		end
	end
	-- исходные C0 моторов (для разлёта частей и подкашивания лап)
	local motors = {}
	for name, m in pairs(rig.Motors) do
		if name ~= "Root" then
			local dir = V(math.random() - 0.5, math.random() * 0.6, math.random() - 0.5)
			motors[#motors + 1] = { m, m.C0, name, dir.Magnitude > 0.01 and dir.Unit or V(0, 1, 0) }
		end
	end
	if style == "Dissipate" then
		FX.Burst(root.Position, FX.Colors.Soft, 10, 0.4 * size, 4, 0.9)
	elseif style == "Implode" then
		FX.Sound("Boss", 1.2, 0.6, root.Position)
		FX.Shake(0.6, life)
	end
	local exploded = false
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local a = math.clamp((os.clock() - start) / life, 0, 1)
		local fade = a
		if style == "Dissipate" then
			-- дух растворяется вверх, закручиваясь
			root.CFrame = startCF * CF(0, ease(a) * 2.5 * sc, 0) * ANG(0, a * 4, 0)
		elseif style == "Scatter" then
			-- разделённые части разлетаются в стороны
			root.CFrame = startCF * CF(0, a * 1.2 * sc, 0)
			for _, mm in ipairs(motors) do
				mm[1].C0 = mm[2] * CF(mm[4] * ease(a) * 3 * sc) * ANG(a * mm[4].X * 4, a * 3, a * mm[4].Z * 4)
			end
		elseif style == "Collapse" then
			-- лапы разъезжаются, тело падает на землю
			root.CFrame = startCF * CF(0, -ease(a) * hip * 0.7, 0) * ANG(rad(-8 * a), 0, rad(20 * ease(a)))
			for _, mm in ipairs(motors) do
				local side = LEGS[mm[3]]
				if side then
					mm[1].C0 = mm[2] * ANG(0, 0, side * ease(a) * 1.1)
				end
			end
			fade = math.clamp((a - 0.4) / 0.6, 0, 1)
		elseif style == "Implode" then
			-- финальный босс: дрожит, поднимается, раскидывает руки, затем коллапсирует во вспышке
			if a < 0.55 then
				local k = a / 0.55
				root.CFrame = startCF * CF((math.random() - 0.5) * 0.4 * k * sc, k * 1.5 * sc, 0) * ANG(rad(-15 * k), 0, 0)
				for _, mm in ipairs(motors) do
					if mm[3] == "RS" or mm[3] == "LS" then
						mm[1].C0 = mm[2] * ANG(rad(120 * k), 0, rad((mm[3] == "RS" and 40 or -40) * k))
					end
				end
				if math.random() < 0.25 and not FX.Lite then
					FX.Burst(root.Position + V((math.random() - 0.5) * 6 * sc, (math.random() - 0.3) * 6 * sc, (math.random() - 0.5) * 6 * sc), FX.Colors.Neon, 3, 0.4 * sc, 6, 0.4)
				end
				fade = 0
			else
				if not exploded then
					exploded = true
					local g = root.Position - V(0, hip - 0.2, 0)
					FX.Sphere(root.Position, 9 * sc, FX.Colors.White, 0.6)
					FX.Sphere(root.Position, 14 * sc, FX.Colors.Neon, 0.9, nil, 0.2)
					FX.Shockwave(g, 14 * size, 5)
					FX.Burst(root.Position, FX.Colors.Soft, 30, 0.8, 22, 1)
					FX.Shake(1.2, 0.8)
				end
				local k = (a - 0.55) / 0.45
				root.CFrame = startCF * CF(0, 1.5 * sc - ease(k) * hip * 0.6, 0) * ANG(rad(-15 + 30 * k), k * 2, 0)
				fade = k
			end
		else -- Topple: колени подгибаются, тело валится вперёд
			root.CFrame = startCF * CF(0, -a * hip * 0.8, 0) * ANG(rad(-75 * ease(a)), 0, rad(15 * a))
			for _, mm in ipairs(motors) do
				if mm[3] == "RS" or mm[3] == "LS" then
					mm[1].C0 = mm[2] * ANG(rad(70 * ease(a)), 0, 0)
				elseif mm[3] == "RH" or mm[3] == "LH" then
					mm[1].C0 = mm[2] * ANG(rad(40 * ease(a)), 0, 0)
				end
			end
			fade = math.clamp((a - 0.3) / 0.7, 0, 1)
		end
		for _, p in ipairs(parts) do
			p[1].Transparency = p[2] + (1 - p[2]) * fade
		end
		if a >= 1 then
			conn:Disconnect()
			model:Destroy()
		end
	end)
end

function Renderer.RemoveEnemy(id, reason)
	local view = enemyViews[id]
	if not view then
		return
	end
	enemyViews[id] = nil
	if reason == "clear" then
		FX.Poof(view.Rig.Root.Position, FX.Colors.Neon, 0.8)
		view.Rig.Model:Destroy()
	else
		if view.Rig.DeathFX and reason ~= "core" then
			HFX.EnemyDeath(view, reason)
		end
		deathAnim(view, reason)
	end
end

function Renderer.OnSync(payload)
	local list = payload.E
	local nowc = os.clock()
	for i = 1, #list, 4 do
		local v = enemyViews[list[i]]
		if v then
			v.ServerDist = list[i + 1]
			if list[i + 2] < v.HP then
				v.HitT = nowc
			end
			v.HP = list[i + 2]
			v.Slowed = list[i + 3] == 1
			v.Frozen = list[i + 3] == 2
			v.LastSync = nowc
		end
	end
	for _, d in ipairs(payload.DMG or {}) do
		local pos = Renderer.EnemyCenter(d[1])
		if pos then
			FX.DamageNumber(pos + V(0, 1.5, 0), d[2], d[3])
		end
	end
	for _, r in ipairs(payload.RM or {}) do
		Renderer.RemoveEnemy(r[1], r[2])
	end
	if payload.AL or payload.RA then
		HFX.SyncAllies(payload.AL, payload.RA)
	end
end

------------------------------------------------------------------------
-- ХОДЬБА / ПАРЕНИЕ
------------------------------------------------------------------------
local DUST = Color3.fromRGB(70, 60, 82)

local function heavyStep(view, power, camDist)
	if camDist < 90 then
		FX.Shake(power * (1 - camDist / 90), 0.18)
	end
	if not FX.Lite and camDist < 120 then
		local sc = view.Rig.Scale or 1
		FX.Ring(groundOf(view), 2.2 * sc, DUST, 0.45, 0.2, 0.4 * sc, 0.45)
	end
end

local CRAWL_LEGS = { { "FR", 1, 0 }, { "BL", -1, 0 }, { "FL", -1, math.pi }, { "BR", 1, math.pi } }
local FLOAT_ARMS = { "ArmR", "ArmL", "ArmR2", "ArmL2", "RS", "LS" }

local function animateEnemy(view, t, dt, camDist)
	local rig = view.Rig
	local base = rig.Base
	local m = rig.Motors
	local g = rig.Gait or {}
	local sc = rig.Scale or 1
	local idle = rig.Idle or {}
	local def = Config.Enemies[view.Type]
	local aggro = view.Aggro or 1
	local far = camDist > LOD_DISTANCE
	local spd = view.Speed * (view.Frozen and 0 or (view.Slowed and 0.5 or 1))
	-- частота шага привязана к скорости врага
	local freq = spd / math.max(def.Scale or 1, 0.5) * 1.1 * (g.Speed or 1) * (1 + (aggro - 1) * 0.3)
	view.W = (view.W or view.Phase) + dt * freq
	local w = view.W
	local s = math.sin(w)
	local stride = (g.Stride or 0.55) * (0.85 + 0.15 * aggro)
	local bob = (g.Bob or 0.12) * sc
	local hitA = t - (view.HitT or -10)
	local flinch = hitA < 0.22 and (1 - hitA / 0.22) * (def.IsBoss and 0.35 or 1) or 0

	local function pose(name, x, y, z)
		local b = base[name]
		if not b or not m[name] then
			return
		end
		local id = idle[name]
		if id then
			m[name].C0 = b * ANG(rad(id[1]) + x, rad(id[2]) + y, rad(id[3]) + z)
		else
			m[name].C0 = b * ANG(x, y, z)
		end
	end
	local idleRoot = idle.Root and rad(idle.Root[1]) or 0

	local rootCF
	local style = rig.Style
	if style == "Biped" or style == "Heavy" then
		local heavy = style == "Heavy"
		pose("RH", s * stride, 0, 0)
		pose("LH", -s * stride, 0, 0)
		local arm = stride * (heavy and 0.55 or 0.8) * aggro
		pose("RS", -s * arm, 0, heavy and math.abs(s) * 0.08 or 0)
		pose("LS", s * arm, 0, heavy and -math.abs(s) * 0.08 or 0)
		local sway = g.Sway or 0.04
		local lean = rad((g.Lean or 0) + (aggro - 1) * 20)
		-- тяжёлые проседают на каждом шаге, лёгкие подпрыгивают
		local y = heavy and ((1 - math.abs(s)) * bob - bob * 0.5) or math.abs(s) * bob
		rootCF = base.Root * CF(0, y, 0) * ANG(idleRoot + lean, s * sway * 0.5, -s * sway)
		pose("Neck", heavy and -math.abs(s) * 0.05 or 0, 0, s * sway * 0.8)
		local c = math.cos(w)
		if g.Shake and not far and view.LastC and (view.LastC > 0) ~= (c > 0) then
			heavyStep(view, g.Shake * (0.8 + 0.2 * aggro), camDist)
		end
		view.LastC = c
	elseif style == "Gallop" then
		-- галоп: передние лапы парой, задние парой со сдвигом
		pose("FR", s * stride, 0, 0)
		pose("FL", math.sin(w + 0.35) * stride, 0, 0)
		pose("BR", math.sin(w - 1.6) * stride, 0, 0)
		pose("BL", math.sin(w - 1.25) * stride, 0, 0)
		rootCF = base.Root * CF(0, math.abs(s) * bob, 0) * ANG(math.cos(w) * 0.09, 0, 0)
		pose("Neck", -math.cos(w) * 0.12, 0, 0)
	elseif style == "Crawl" then
		-- диагональные пары лап: мах вперёд-назад + подъём
		for _, l in ipairs(CRAWL_LEGS) do
			local p = w + l[3]
			pose(l[1], 0, math.sin(p) * stride * l[2], math.max(0, math.cos(p)) * 0.35 * l[2])
		end
		rootCF = base.Root * CF(0, math.abs(math.sin(w * 2)) * bob, 0) * ANG(0, s * 0.06, s * (g.Sway or 0.05))
	elseif style == "Quad" then
		pose("FR", s * 0.6, 0, 0)
		pose("BL", s * 0.6, 0, 0)
		pose("FL", -s * 0.6, 0, 0)
		pose("BR", -s * 0.6, 0, 0)
		rootCF = base.Root * CF(0, math.abs(s) * 0.1 * sc, 0) * ANG(s * 0.03, 0, 0)
		pose("Neck", math.sin(w * 2) * 0.06, 0, 0)
	else -- Float
		local amp = (g.Bob or 0.3) * sc
		rootCF = base.Root * CF(0, math.sin(t * 2 + view.Phase) * amp, 0) * ANG(0.12 + (aggro - 1) * 0.2, 0, math.sin(t * 1.3 + view.Phase) * 0.06)
		for _, name in ipairs(FLOAT_ARMS) do
			if m[name] and base[name] then
				local side = (name:sub(-1) == "R" or name == "RS" or name == "ArmR2") and 1 or -1
				pose(name, math.sin(t * 2.2 + view.Phase + side) * 0.3 + 0.3, 0, math.sin(t * 1.7) * 0.15 * side)
			end
		end
	end

	-- особое появление мини-босса: выбирается из земли согнувшись и выпрямляется
	if rig.SpawnStyle == "Titan" then
		local sa = (t - view.SpawnT) / 1.6
		if sa < 1 then
			local k = 1 - ease(math.clamp(sa, 0, 1))
			rootCF = rootCF * CF(0, -k * 1.2 * sc, 0) * ANG(rad(40) * k, 0, 0)
			pose("RS", rad(-30) * k, 0, rad(20) * k)
			pose("LS", rad(-30) * k, 0, rad(-20) * k)
		end
	end
	-- отшатывание от удара
	if flinch > 0 then
		rootCF = rootCF * CF(0, 0, flinch * 0.25 * sc) * ANG(-flinch * 0.25, 0, flinch * 0.08)
		if m.Neck and base.Neck then
			m.Neck.C0 = m.Neck.C0 * ANG(-flinch * 0.3, 0, 0)
		end
	end
	-- рёв босса (появление, смена фазы)
	local roarA = t - (view.RoarT or -10)
	local roar = (roarA > 0 and roarA < 1.4) and math.sin(roarA / 1.4 * math.pi) or 0
	if roar > 0 then
		if m.RS and base.RS then
			pose("RS", rad(150 * roar), 0, rad(30 * roar))
			pose("LS", rad(150 * roar), 0, rad(-30 * roar))
		end
		if m.Neck and base.Neck then
			m.Neck.C0 = base.Neck * ANG(rad(-30 * roar), 0, 0)
		end
		rootCF = rootCF * ANG(rad(-12 * roar), 0, 0)
	end
	m.Root.C0 = rootCF
	if m.Jaw then
		m.Jaw.C0 = base.Jaw * ANG(math.max(0, math.sin(t * 3 + view.Phase)) * 0.4 + roar * 0.6 + flinch * 0.3, 0, 0)
	end
	if not far then
		applySecondary(view, t, dt)
	end
end

local function updateEnemies(t, dt)
	local nowc = os.clock()
	local cam = workspace.CurrentCamera
	local camPos = cam and cam.CFrame.Position or V()
	for _, v in pairs(enemyViews) do
		local speed = v.Speed * (v.Frozen and 0 or (v.Slowed and 0.5 or 1)) * (v.HasteUntil and HFX.SpeedMult(v) or 1)
		local predicted = v.ServerDist + speed * math.min(nowc - v.LastSync, 0.35)
		v.Dist = v.Dist + speed * dt
		v.Dist = v.Dist + (predicted - v.Dist) * math.min(1, dt * 5)
		local pos, dir = PathUtil.OffsetPositionAt(v.Dist, v.Lateral)
		local hip = v.Rig.HipHeight
		local target = CFrame.lookAt(pos + V(0, hip, 0), pos + dir + V(0, hip, 0))
		v.CF = v.CF:Lerp(target, math.min(1, dt * 9))
		local rise = 0
		if v.Emerge then
			local a = math.clamp((t - v.SpawnT) / 0.6, 0, 1)
			rise = (1 - ease(a)) * (hip + 1.5)
			if a >= 1 then
				v.Emerge = false
			end
		end
		if v.FadeParts then
			local a = math.clamp((t - v.SpawnT) / 0.7, 0, 1)
			for _, p in ipairs(v.FadeParts) do
				p[1].Transparency = 1 - (1 - p[2]) * a
			end
			if a >= 1 then
				v.FadeParts = nil
			end
		end
		v.Rig.Root.CFrame = v.CF - V(0, rise, 0)
		checkPhases(v, false)
		-- остановленные временем враги замирают в текущей позе
		if not v.Frozen then
			animateEnemy(v, t, dt, (camPos - pos).Magnitude)
		end
		if v.Fill then
			v.Fill.Size = UDim2.fromScale(math.clamp(v.HP / v.MaxHP, 0, 1), 1)
		end
	end
end

------------------------------------------------------------------------
-- ЮНИТЫ
------------------------------------------------------------------------
local function yawTo(from, to)
	local d = to - from
	return math.atan2(-d.X, -d.Z)
end

local function prepareUnitModel(model, uid)
	model:SetAttribute("Uid", uid)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CanQuery = true
			d.CanTouch = false
		end
	end
end

local function buildUnitView(view)
	if view.Rig then
		view.Rig.Model:Destroy()
	end
	local rig = UnitModels.Build(view.UnitId, view.Level)
	view.Rig = rig
	prepareUnitModel(rig.Model, view.Uid)
	rig.Root.CFrame = CF(view.Pos + V(0, rig.HipHeight, 0)) * ANG(0, view.Yaw, 0)
	rig.Model.Parent = unitFolder
	view.Trails = {}
	view.TrailOn = false
	for _, d in ipairs(rig.Model:GetDescendants()) do
		if d:IsA("Trail") then
			table.insert(view.Trails, d)
		end
	end
	-- метка владельца
	local gui = Instance.new("BillboardGui")
	gui.Name = "Tag"
	gui.Size = UDim2.fromOffset(110, 34)
	gui.StudsOffsetWorldSpace = V(0, 2.7 * rig.Scale + 1.2, 0)
	gui.MaxDistance = (ctx and ctx.Lite) and 30 or 70
	gui.LightInfluence = 0
	gui.Adornee = rig.Root
	local def = Config.Units[view.UnitId]
	local rcolor = Config.Rarities[def.Rarity].Color
	local lv = Instance.new("TextLabel")
	lv.BackgroundTransparency = 1
	lv.Size = UDim2.fromScale(1, 0.55)
	lv.Font = Enum.Font.FredokaOne
	lv.TextScaled = true
	lv.Text = string.rep("★", view.Level) .. string.rep("☆", 5 - view.Level)
	lv.TextColor3 = rcolor
	lv.TextStrokeTransparency = 0.2
	lv.Parent = gui
	local own = Instance.new("TextLabel")
	own.BackgroundTransparency = 1
	own.Position = UDim2.fromScale(0, 0.55)
	own.Size = UDim2.fromScale(1, 0.45)
	own.Font = Enum.Font.GothamBold
	own.TextScaled = true
	own.Text = view.Folder:GetAttribute("OwnerName") or ""
	own.TextColor3 = Color3.fromRGB(220, 210, 235)
	own.TextStrokeTransparency = 0.4
	own.Parent = gui
	gui.Parent = rig.Root
end

-- «Временная буря»: шестерни вокруг видны, Хроносекира светится ярче, механизмы крутятся быстрее
local STORM_GLOW = Color3.fromRGB(255, 170, 60)
local function setStorm(view, on)
	local rig = view.Rig
	if not rig then
		return
	end
	rig.Storm = on
	for _, d in ipairs(rig.Model:GetDescendants()) do
		if d:IsA("BasePart") then
			local st = d:GetAttribute("StormFX")
			if st then
				if on then
					d.Transparency = st
				else
					FX.Tween(d, 0.8, { Transparency = 1 })
				end
			elseif d:GetAttribute("AxeGlow") then
				if not d:GetAttribute("BaseColor") then
					d:SetAttribute("BaseColor", d.Color)
				end
				d.Color = on and STORM_GLOW or d:GetAttribute("BaseColor")
			end
		end
	end
end

function Renderer.AddUnit(folder, isNew)
	local uid = tonumber(folder.Name)
	if not uid or unitViews[uid] then
		return
	end
	local view = {
		Uid = uid,
		Folder = folder,
		UnitId = folder:GetAttribute("UnitId"),
		Level = folder:GetAttribute("Level") or 1,
		Pos = folder:GetAttribute("Position"),
		Yaw = rad(folder:GetAttribute("Rotation") or 0),
		Phase = math.random() * 10,
	}
	view.TargetYaw = view.Yaw
	if not view.UnitId or not view.Pos then
		return
	end
	unitViews[uid] = view
	buildUnitView(view)
	if folder:GetAttribute("Storm") then
		setStorm(view, true)
	end
	view.NextFidget = os.clock() + 4 + math.random() * 8
	local placeFx = Config.Units[view.UnitId].PlaceFX
	if isNew and placeFx == "Throne" then
		-- Король фонарей: трон поднимается из огня, вокруг вырастают тыквы
		view.DropT = os.clock()
		HFX.ThronePlace(view.Pos)
	elseif isNew and placeFx == "Clock" then
		-- часовщик поднимается из золотого механического портала, стрелки идут назад
		view.RiseT = os.clock()
		FX.ClockPortal(view.Pos, 1.3)
	elseif isNew then
		view.DropT = os.clock()
	else
		FX.Place(view.Pos)
	end
	view.Conn = folder.AttributeChanged:Connect(function(attr)
		if attr == "Level" then
			local newLevel = folder:GetAttribute("Level")
			if newLevel ~= view.Level then
				view.Level = newLevel
				buildUnitView(view)
				if folder:GetAttribute("Storm") then
					setStorm(view, true)
				end
				FX.LevelUp(view.Pos, Config.Rarities[Config.Units[view.UnitId].Rarity].Color)
				view.Anim = { Start = os.clock(), Frames = Anims.PowerUp() }
				if Renderer.OnUnitChanged then
					Renderer.OnUnitChanged(uid)
				end
			end
		elseif attr == "Storm" then
			setStorm(view, folder:GetAttribute("Storm") == true)
		elseif Renderer.OnUnitChanged then
			Renderer.OnUnitChanged(uid)
		end
	end)
end

function Renderer.RemoveUnit(folder)
	local uid = tonumber(folder.Name)
	local view = uid and unitViews[uid]
	if not view then
		return
	end
	unitViews[uid] = nil
	if view.Conn then
		view.Conn:Disconnect()
	end
	FX.Poof(view.Pos + V(0, 2, 0), FX.Colors.Soft, 1)
	view.Rig.Model:Destroy()
	if Renderer.OnUnitRemoved then
		Renderer.OnUnitRemoved(uid)
	end
end

local function muzzlePos(view)
	local m = view.Rig.Muzzle
	if m and m.Parent then
		return m.Position
	end
	return view.Rig.Root.Position + V(0, 1, 0)
end
Renderer.MuzzlePos = muzzlePos

local function playAnim(view, name, h, hits, interval)
	local builder = Anims[name]
	if not builder then
		return
	end
	view.Anim = { Start = os.clock(), Frames = builder(h, hits, interval) }
end

------------------------------------------------------------------------
-- ПРЕДПРОСМОТР (окно юнита в инвентаре): те же позы и анимации, что в бою
------------------------------------------------------------------------
function Renderer.PreviewStep(state, t)
	applyPose(state.Rig, evalPose(state, t), t, state.Phase or 0)
end

function Renderer.PreviewAttack(state, unitId, level)
	local def = Config.Units[unitId]
	local st = def.Levels[math.clamp(level or 1, 1, #def.Levels)]
	playAnim(state, def.Anim, def.HitDelay or 0.2, st.Hits or 1, def.HitInterval)
end

-- Предпросмотр способности: только анимация и ускоренные механизмы, без игровых эффектов
function Renderer.PreviewAbility(state, name)
	if Anims[name] then
		state.Anim = { Start = os.clock(), Frames = Anims[name]() }
		state.Rig.SpinBoostUntil = os.clock() + 2.2
	end
end

function Renderer.PreviewFidget(state, unitId)
	local list = FIDGETS[Config.Units[unitId].Anim] or { "LookAround" }
	local pick = list[math.random(1, #list)]
	state.Anim = { Start = os.clock(), Frames = Anims[pick]() }
end

function Renderer.OnAttack(p)
	local view = unitViews[p.U]
	if not view then
		return
	end
	local def = Config.Units[view.UnitId]
	local lv = p.L or view.Level
	local h = p.D or def.HitDelay or 0.2
	local firstId = p.T and p.T[1]
	local tpos = firstId and Renderer.EnemyPosition(firstId)
	if tpos then
		view.TargetYaw = yawTo(view.Pos, tpos)
	end

	if type(p.AB) == "string" then
		-- способность с собственной анимацией (например, способности часовщика)
		playAnim(view, p.AB, h)
		view.Rig.SpinBoostUntil = os.clock() + (p.AB == "TimeStorm" and 2.4 or 1.6)
		return
	end
	if p.AB then
		playAnim(view, "BlackHoleCast", h)
		local crystal = view.Rig.Model:FindFirstChild("Crystal")
		if crystal then
			FX.Sphere(crystal.Position, 3, FX.Colors.Neon, 0.5)
		end
		return
	end

	local hits = p.T and #p.T or 1
	if p.EC then
		-- повтор «Призрачной короны»: атакует синяя копия за спиной, сам юнит не дёргается
		HFX.EchoGhost(view)
	else
		playAnim(view, def.Anim, h, hits, p.I)
		view.GustT = os.clock()
		view.NextFidget = os.clock() + 6 + math.random() * 6
	end
	if HFX.OnAttack(view, def, p, h, lv) then
		return
	end

	local function at(delay, fn)
		task.delay(delay, fn)
	end

	local impactColor = def.ImpactColor or FX.Colors.Neon
	if def.AttackType == "Chrono" then
		-- зубчатый диск летит по прямой до конца дальности
		at(h, function()
			if not view.Rig or not view.Rig.Model.Parent or not p.E then
				return
			end
			local from = muzzlePos(view)
			local to = Vector3.new(p.E.X, from.Y - 1.5, p.E.Z)
			local dist = (Vector3.new(to.X, 0, to.Z) - Vector3.new(view.Pos.X, 0, view.Pos.Z)).Magnitude
			FX.GearDisc(from, to, dist / (p.SP or 70), lv, p.ST)
		end)
	elseif def.AttackType == "Projectile" then
		for si, id in ipairs(p.T or { firstId }) do
			local travel = (p.TRS and p.TRS[si]) or p.TR or 0.2
			at(h + (si - 1) * (p.SG or 0.12), function()
				if not view.Rig or not view.Rig.Model.Parent then
					return
				end
				local from = muzzlePos(view)
				FX.Sound("Shoot", def.Projectile == "Bolt" and 0.6 or 1, def.Projectile == "Bullet" and 0.8 or 1, from)
				FX.Projectile(def.Projectile, from, function()
					return Renderer.EnemyCenter(id)
				end, travel, function(pos)
					local orb = def.Projectile == "Orb"
					FX.Burst(pos, orb and FX.Colors.Neon or impactColor, orb and 8 or 4, 0.3, 5)
					if orb then
						FX.Sphere(pos, 1.4 + lv * 0.15, FX.Colors.Neon, 0.25)
					end
				end, lv)
				if def.Projectile == "Bolt" or def.Projectile == "Bullet" then
					FX.Sphere(from, 0.6, impactColor, 0.12)
				end
			end)
		end
	elseif def.AttackType == "Chain" then
		-- лунный серп летит от цели к цели
		local times = p.TT or {}
		for i, id in ipairs(p.T or {}) do
			local prevT = i == 1 and h or times[i - 1]
			at(prevT, function()
				if not view.Rig.Model.Parent then
					return
				end
				local from = i == 1 and muzzlePos(view) or Renderer.EnemyCenter(p.T[i - 1])
				if not from then
					return
				end
				FX.Sound("Magic", 0.8, 1.3 + i * 0.1, from)
				FX.Projectile("Moon", from, function()
					return Renderer.EnemyCenter(id)
				end, math.max((times[i] or prevT) - prevT, 0.05), function(pos)
					FX.Burst(pos, impactColor, 6, 0.3, 6)
					FX.Ring(pos - V(0, 1, 0), 2.5, impactColor, 0.3, 0.2)
				end, lv)
			end)
		end
	elseif def.AttackType == "Thread" then
		at(h, function()
			if not view.Rig.Model.Parent then
				return
			end
			FX.Sound("Magic", 0.8, 0.7, view.Pos)
			for _, id in ipairs(p.T or {}) do
				local target = Renderer.EnemyCenter(id)
				if target then
					FX.Thread(muzzlePos(view), target, FX.Colors.Soft)
				end
			end
		end)
	elseif def.AttackType == "Splash" then
		at(h, function()
			if view.Rig.Model.Parent then
				FX.Sphere(muzzlePos(view), 2.2, FX.Colors.Red, 0.25)
			end
		end)
	elseif def.AttackType == "Pierce" then
		at(h, function()
			if view.Rig.Model.Parent then
				FX.Sphere(muzzlePos(view), 2, Color3.fromRGB(255, 190, 215), 0.3)
			end
		end)
	elseif def.AttackType == "Laser" then
		at(h, function()
			local target = Renderer.EnemyCenter(firstId) or tpos
			if target and view.Rig.Model.Parent then
				FX.Sound("Laser", 1, 1, target)
				FX.Beam(muzzlePos(view), target, (lv >= 5) and 2.6 or (1.2 + lv * 0.2), (lv >= 5) and FX.Colors.Soft or FX.Colors.Neon, 0.45, lv >= 5)
			end
		end)
	elseif def.AttackType == "Melee" then
		at(h, function()
			local target = Renderer.EnemyCenter(firstId) or tpos
			if not target then
				return
			end
			local origin = view.Rig.Root.Position + V(0, 1, 0)
			local cf = CFrame.lookAt(origin, V(target.X, origin.Y, target.Z))
			local reach = math.max((V(target.X, origin.Y, target.Z) - origin).Magnitude * 0.6, 3)
			local big = view.UnitId == "AbyssOverlord" or p.PW
			local arcColor = def.ImpactColor or (big and FX.Colors.Neon or FX.Colors.Soft)
			if p.PW then
				arcColor = FX.Colors.Pink
				FX.Sphere(target, 2.2, FX.Colors.Pink, 0.25)
			end
			FX.Arc(cf, reach, rad(15), rad(150), arcColor, big and 1 or (0.4 + lv * 0.05), 0.3)
			if def.Anim == "DualDagger" then
				FX.Arc(cf * ANG(0, 0, rad(60)), reach * 0.9, rad(20), rad(140), FX.Colors.Neon, 0.35, 0.25)
			end
			FX.Sound(big and "HeavyHit" or "Slash", 1, 1, target)
			FX.Burst(target, FX.Colors.Neon, big and 12 or 5, big and 0.6 or 0.3, big and 10 or 5)
			if big then
				FX.Ring(V(target.X, view.Pos.Y + 0.2, target.Z), 4, FX.Colors.Neon, 0.35, 0.3)
			end
			if view.UnitId == "VoidKnight" and lv >= 3 then
				FX.Sphere(target, 1.5 + lv * 0.3, Color3.fromRGB(70, 20, 120), 0.35)
				FX.Burst(target, Color3.fromRGB(40, 10, 70), 8, 0.5, 6)
			end
		end)
	elseif def.AttackType == "AOE" then
		-- сама область рисуется по событию Impact (точный центр с сервера)
		at(h, function()
			if not view.Rig.Model.Parent then
				return
			end
			if view.UnitId == "EclipseGuardian" then
				FX.Sphere(muzzlePos(view), 2, FX.Colors.Neon, 0.25)
			elseif view.UnitId == "AbyssOverlord" then
				local target = Renderer.EnemyCenter(firstId) or tpos
				if target then
					local origin = view.Rig.Root.Position + Vector3.new(0, 1, 0)
					local cf = CFrame.lookAt(origin, Vector3.new(target.X, origin.Y, target.Z))
					FX.Arc(cf, math.max((Vector3.new(target.X, origin.Y, target.Z) - origin).Magnitude * 0.6, 3), rad(15), rad(150), FX.Colors.Neon, 1, 0.3)
				end
			end
		end)
	elseif def.AttackType == "MultiHit" then
		local interval = p.I or def.HitInterval or 0.16
		for i, id in ipairs(p.T or {}) do
			at(h + (i - 1) * interval, function()
				local target = Renderer.EnemyCenter(id)
				if not target or not view.Rig.Model.Parent then
					return
				end
				if view.UnitId == "CorruptedSamurai" then
					local origin = view.Rig.Root.Position + V(0, 1, 0)
					local cf = CFrame.lookAt(origin, V(target.X, origin.Y, target.Z)) * ANG(0, 0, rad(i % 2 == 0 and 50 or -50))
					local reach = math.max((V(target.X, origin.Y, target.Z) - origin).Magnitude * 0.6, 3)
					FX.Arc(cf, reach, rad(10), rad(140), lv >= 5 and FX.Colors.Pink or FX.Colors.Neon, 0.35 + lv * 0.05, 0.25)
					FX.Sound("Slash", 1, 1.15, target)
					if lv >= 3 then
						FX.SlashMark(target, rad(i % 2 == 0 and 40 or -40), 5 + lv * 0.5, 0.35, FX.Colors.Neon, 0.3)
					end
				else
					-- Void Emperor / Rift Monarch: вспышка на оружии, сам удар — в Impact
					FX.Sphere(muzzlePos(view), 1.6, def.ImpactKind == "Rift" and FX.Colors.Neon or FX.Colors.Pink, 0.2)
				end
			end)
		end
	end
end

function Renderer.OnImpact(p)
	local k = p.K
	local lv = p.L or 1
	if k == "Shockwave" then
		FX.Shockwave(p.P, p.R, lv)
	elseif k == "Reap" then
		local view = unitViews[p.U]
		local def = view and Config.Units[view.UnitId]
		FX.Reap(view and view.Pos or p.P, p.P, p.R, lv, def and def.ImpactColor)
		FX.Sound("Slash", 1, 0.8, p.P)
	elseif k == "Crystal" then
		FX.CrystalBurst(p.P, p.R)
	elseif k == "Hammer" then
		FX.Hammer(p.P, p.R, lv)
	elseif k == "Shard" then
		FX.FallingShard(p.P, p.R)
	elseif k == "Rift" then
		FX.RiftPortal(p.P, lv)
	elseif k == "BigRift" then
		FX.BigRift(p.P, p.R)
	elseif k == "Splash" then
		local view = unitViews[p.U]
		FX.RedSplash(p.P, p.R, view and muzzlePos(view))
	elseif k == "Cleave" then
		local view = unitViews[p.U]
		FX.Cleave(view and view.Pos or p.P, p.P, p.R)
	elseif k == "BloodMoonFall" then
		FX.BloodMoonFall(p.P, p.R, p.DL)
	elseif k == "BloodMoon" then
		FX.BloodMoonBoom(p.P, p.R)
	elseif k == "Pierce" then
		FX.PierceBeam(p.P, p.E)
	elseif k == "Smash" then
		local g = Vector3.new(p.P.X, p.P.Y + 0.2, p.P.Z)
		FX.Ring(g, p.R, FX.Colors.Neon, 0.4, 0.4, 1, 0.1)
		FX.Cracks(g, p.R, FX.Colors.Neon, 5 + lv, 1.0)
		FX.Burst(g + Vector3.new(0, 1, 0), Color3.fromRGB(60, 50, 70), 8 + lv, 0.5, 9)
	elseif k == "Judgement" then
		FX.Judgement(p.P, lv, p.H)
	elseif k == "BlackHole" then
		FX.BlackHole(p.P, p.R, p.DUR, lv, p.DL)
	elseif k == "Summon" then
		FX.Summon(p.P, p.R)
	elseif k == "ChronoHit" then
		FX.ChronoHit(p.P + V(0, 1.5, 0))
	elseif k == "ChronoBurst" then
		FX.ChronoBurst(p.P, p.R)
	elseif k == "TimeBreak" then
		FX.TimeBreak(p.P, p.R, p.DUR or 1.5)
	elseif k == "TimeHaste" then
		local list = {}
		for _, uid in ipairs(p.A or {}) do
			local v = unitViews[uid]
			if v then
				list[#list + 1] = v.Pos
				-- у союзника тоже быстрее крутятся стрелки/механизмы, если они есть
				if v.Rig then
					v.Rig.SpinBoostUntil = os.clock() + (p.DUR or 2)
				end
			end
		end
		FX.TimeHaste(p.P, p.R, list, p.DUR or 2)
	elseif k == "TimeStorm" then
		FX.TimeStorm(p.P, p.DL or 1.3)
	else
		HFX.OnImpact(p)
	end
end

local function nearestEnemyYaw(v, range)
	local best, bestD
	for _, e in pairs(enemyViews) do
		local p = e.Rig.Root.Position
		local d = PathUtil.FlatDistance(p, v.Pos)
		if d <= range and (not bestD or d < bestD) then
			best, bestD = p, d
		end
	end
	return best and yawTo(v.Pos, best)
end

local function updateUnits(t, dt)
	for _, v in pairs(unitViews) do
		local rig = v.Rig
		if rig then
			-- следим за ближайшим врагом даже до атаки
			v.TrackT = (v.TrackT or 0) - dt
			if v.TrackT <= 0 then
				v.TrackT = 0.3
				local def = Config.Units[v.UnitId]
				local yaw = nearestEnemyYaw(v, def.Levels[v.Level].Range + 6)
				if yaw and not v.Anim then
					v.TargetYaw = yaw
				end
			end
			-- случайные действия в простое
			if not v.Anim and t >= (v.NextFidget or 0) then
				local list = FIDGETS[Config.Units[v.UnitId].Anim] or { "LookAround" }
				local pick = list[math.random(1, #list)]
				v.Anim = { Start = t, Frames = Anims[pick]() }
				v.NextFidget = t + 6 + math.random() * 8
			end
			-- плащ развевается сильнее во время атаки
			rig.Gust = math.max(0, 1 - (t - (v.GustT or -10)) / 0.8)
			local diff = (v.TargetYaw - v.Yaw + math.pi) % (2 * math.pi) - math.pi
			v.Yaw = v.Yaw + diff * math.min(1, dt * 8)
			-- приземление после установки
			local drop = 0
			if v.DropT then
				local a = math.clamp((t - v.DropT) / 0.3, 0, 1)
				drop = (1 - a * a) * 7
				if a >= 1 then
					v.DropT = nil
					v.Anim = { Start = t, Frames = Anims.Land() }
					FX.Place(v.Pos)
				end
			end
			if v.RiseT then
				local a = math.clamp((t - v.RiseT) / 1.3, 0, 1)
				drop = -(1 - ease(a)) * (rig.HipHeight + 2.5)
				if a >= 1 then
					v.RiseT = nil
					v.Anim = { Start = t, Frames = Anims.TimeHaste() }
				end
			end
			rig.Root.CFrame = CF(v.Pos + V(0, rig.HipHeight + drop, 0)) * ANG(0, v.Yaw, 0)
			applyPose(rig, evalPose(v, t), t, v.Phase)
			-- шлейф оружия виден только во время анимаций
			local on = v.Anim ~= nil
			if on ~= v.TrailOn then
				v.TrailOn = on
				for _, tr in ipairs(v.Trails or {}) do
					tr.Enabled = on
				end
			end
		end
	end
end

-- Перестроить все модели юнитов (после смены режима графики)
function Renderer.RebuildUnits()
	for _, v in pairs(unitViews) do
		buildUnitView(v)
	end
end

function Renderer.Cheer()
	for _, v in pairs(unitViews) do
		task.delay(math.random() * 0.3, function()
			if v.Rig then
				v.Anim = { Start = os.clock(), Frames = Anims.Cheer() }
			end
		end)
	end
end

------------------------------------------------------------------------
function Renderer.Update(dt)
	local t = os.clock()
	updateEnemies(t, dt)
	updateUnits(t, dt)
	HFX.Update(dt)
end

function Renderer.ClearEnemies()
	for id in pairs(enemyViews) do
		Renderer.RemoveEnemy(id, "clear")
	end
end

function Renderer.Init(c)
	ctx = c
	Config, PathUtil, UnitModels, EnemyModels, FX = c.Config, c.PathUtil, c.UnitModels, c.EnemyModels, c.FX
	enemyFolder = Instance.new("Folder")
	enemyFolder.Name = "VoidTD_Enemies"
	enemyFolder.Parent = workspace
	unitFolder = Instance.new("Folder")
	unitFolder.Name = "VoidTD_Units"
	unitFolder.Parent = workspace
	Renderer.UnitFolder = unitFolder
	Renderer.EnemyFolder = enemyFolder
	HFX = c.HFX
	HFX.Init(c, Renderer)
	-- анимации хэллоуинских юнитов (атаки, способности, разминки)
	if c.HalloweenAnims then
		c.HalloweenAnims(Anims, FIDGETS)
	end
end

return Renderer
]======] }
FILES[#FILES + 1] = { "StarterPlayerScripts", { "VoidTDClient", "UnitViewer" }, "ModuleScript", [======[
--!nocheck
-- VOID TD :: UnitViewer (клиент)
-- Большое окно просмотра юнита: 3D-модель в ViewportFrame + WorldModel (работают моторы и анимации),
-- вращение мышью/пальцем, зум колёсиком/щипком, переключатель уровней, анимации, характеристики,
-- кнопка экипировки, эффекты редкости. Показывается копия модели, а не юнит с карты.
-- Переключение уровней в предпросмотре ничего не покупает и не улучшает.

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local UnitViewer = {}

local V = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles
local rad = math.rad

local ctx, UI, K, Config, UnitModels, Renderer, FX
local THEME

-- подсветка по редкости (по ТЗ: эпические — синие, легендарные — золотые, мифические — фиолетовые)
local GLOW = {
	Common = Color3.fromRGB(150, 140, 170),
	Rare = Color3.fromRGB(90, 150, 255),
	Epic = Color3.fromRGB(70, 140, 255),
	Legendary = Color3.fromRGB(255, 200, 70),
	Mythic = Color3.fromRGB(190, 80, 255),
	Secret = Color3.fromRGB(255, 40, 60),
}

local LEVEL_TABS = { "LVL 1", "LVL 2", "LVL 3", "LVL 4", "MAX" }

local window -- корневая рамка (создаётся один раз)
local refs = {}
local state -- текущее открытие: { Id, Level, Rig, Yaw, Pitch, Dist, ... }
local conns = {} -- соединения, живущие только пока окно открыто
local previewFx -- эффекты способностей в предпросмотре (определены ниже)
local showGallery -- галерея призыва (определена ниже)

------------------------------------------------------------------------
-- 3D-сцена
------------------------------------------------------------------------
local function clearScene()
	if state and state.Rig then
		state.Rig.Model:Destroy()
		state.Rig = nil
	end
	if refs.World then
		for _, c in ipairs(refs.World:GetChildren()) do
			c:Destroy()
		end
	end
end

-- Габариты модели (по видимым деталям) — камера настраивается под размер юнита
local function bounds(model)
	local lo, hi
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and d.Transparency < 1 then
			local p, s = d.Position, d.Size
			local r = math.max(s.X, s.Y, s.Z) * 0.5
			local a, b = p - V(r, r, r), p + V(r, r, r)
			lo = lo and V(math.min(lo.X, a.X), math.min(lo.Y, a.Y), math.min(lo.Z, a.Z)) or a
			hi = hi and V(math.max(hi.X, b.X), math.max(hi.Y, b.Y), math.max(hi.Z, b.Z)) or b
		end
	end
	return lo or V(-2, -3, -2), hi or V(2, 3, 2)
end

local function part(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do
		p[k] = v
	end
	p.Parent = refs.World
	return p
end

-- Круглая платформа под юнитом с кольцом цвета редкости
local function buildPlatform(groundY, radius, glow)
	local disc = ANG(0, 0, rad(90))
	part({ Name = "Platform", Shape = Enum.PartType.Cylinder, Size = V(0.6, radius * 2, radius * 2), CFrame = CF(0, groundY - 0.3, 0) * disc, Color = Color3.fromRGB(24, 20, 32), Material = Enum.Material.Slate })
	part({ Name = "PlatformTop", Shape = Enum.PartType.Cylinder, Size = V(0.62, radius * 1.7, radius * 1.7), CFrame = CF(0, groundY - 0.29, 0) * disc, Color = Color3.fromRGB(40, 34, 54), Material = Enum.Material.Slate })
	part({ Name = "PlatformRing", Shape = Enum.PartType.Cylinder, Size = V(0.64, radius * 2.06, radius * 2.06), CFrame = CF(0, groundY - 0.36, 0) * disc, Color = glow:Lerp(Color3.new(0, 0, 0), 0.35), Material = Enum.Material.SmoothPlastic })
	-- руны по кругу
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		part({ Name = "Rune", Size = V(0.12, 0.62, radius * 0.18), CFrame = CF(math.cos(a) * radius * 0.93, groundY - 0.3, math.sin(a) * radius * 0.93) * ANG(0, -a, 0), Color = glow:Lerp(Color3.new(0, 0, 0), 0.45), Material = Enum.Material.Neon })
	end
end

local function updateCamera()
	if not state or not refs.Cam then
		return
	end
	local c = state.Center
	local dir = V(math.sin(state.Yaw) * math.cos(state.Pitch), math.sin(state.Pitch), -math.cos(state.Yaw) * math.cos(state.Pitch))
	refs.Cam.CFrame = CFrame.lookAt(c + dir * state.Dist, c)
end

local function buildModel(keepCamera)
	clearScene()
	local id, lv = state.Id, state.Level
	local ok, rig = pcall(UnitModels.Build, id, lv)
	if not ok then
		warn("[VOID TD] Предпросмотр: " .. tostring(rig))
		return
	end
	-- частицы, свет и шлейфы во ViewportFrame не рисуются — убираем их из копии
	for _, d in ipairs(rig.Model:GetDescendants()) do
		if d:IsA("ParticleEmitter") or d:IsA("PointLight") or d:IsA("Trail") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.CanQuery = false
		end
	end
	rig.Root.CFrame = CF(0, rig.HipHeight, 0)
	rig.Model.Parent = refs.World
	state.Rig = rig
	state.Anim = nil
	state.Phase = 0
	local glow = GLOW[Config.Units[id].Rarity] or THEME.Accent
	local lo, hi = bounds(rig.Model)
	local size = hi - lo
	buildPlatform(0, math.max(size.X, size.Z, 4) * 0.62, glow)
	state.Center = V(0, (lo.Y + hi.Y) * 0.5, 0)
	-- дистанция, при которой модель целиком входит в кадр при FOV 32
	state.BaseDist = math.max(size.Y, size.X * 0.9) * 1.95 + 2
	if not keepCamera then
		state.Yaw = math.rad(200)
		state.Pitch = math.rad(12)
		state.Zoom = 1
	end
	state.Dist = state.BaseDist * state.Zoom
	refs.VF.LightColor = Color3.new(1, 0.97, 1):Lerp(glow, 0.2)
	updateCamera()
end

------------------------------------------------------------------------
-- ИНФОРМАЦИЯ
------------------------------------------------------------------------
local function fmt(n)
	return Config.FormatNumber(n)
end

local function totalCost(def, lv)
	local sum = 0
	for i = 1, lv do
		sum = sum + def.Levels[i].Cost
	end
	return sum
end

local function refreshInfo()
	local id, lv = state.Id, state.Level
	local def = Config.Units[id]
	local st = def.Levels[lv]
	local rc = Config.Rarities[def.Rarity].Color
	refs.Name.Text = def.Name
	-- основная редкость + тег события (оба тега видны)
	local ev = def.Event and Config.Events[def.Event]
	refs.Rarity.RichText = true
	refs.Rarity.Text = def.Rarity:upper() .. (ev and string.format('  <font color="#%s">%s</font>', ev.Color:ToHex(), ev.Tag) or "")
	refs.Rarity.TextColor3 = rc
	local runeId = ctx.Profile and ctx.Profile.RuneSlots and ctx.Profile.RuneSlots[id]
	if runeId then
		refs.Rarity.Text = refs.Rarity.Text .. string.format('  <font color="#%s">• РУНА %s</font>', Config.RuneRarity.Color:ToHex(), Config.Runes[runeId].Name)
	end
	refs.RarityBar.BackgroundColor3 = rc
	refs.Desc.Text = def.Description or ""
	refs.StatDamage.Text = fmt(st.Damage) .. ((st.Hits and st.Hits > 1) and ("  x" .. st.Hits) or "")
	refs.StatRange.Text = tostring(st.Range)
	refs.StatSpeed.Text = string.format("%.2f/с  (%.2f с)", 1 / st.Cooldown, st.Cooldown)
	refs.StatCost.Text = "$" .. fmt(def.Levels[1].Cost)
	if lv > 1 then
		refs.StatUpgrade.Text = string.format("$%s  (всего $%s)", fmt(st.Cost), fmt(totalCost(def, lv)))
	else
		refs.StatUpgrade.Text = "—"
	end
	local ability = UI.SpecialText and UI.SpecialText(def, st) or def.AttackType
	refs.Ability.Text = (def.Ability and (def.Ability .. "\n") or "") .. ability
	for i, b in ipairs(refs.Tabs) do
		local on = i == lv
		b.BackgroundColor3 = on and THEME.Accent or THEME.BG3
		b.TextColor3 = on and Color3.new(1, 1, 1) or THEME.Dim
	end
	-- экипировка
	local prof = ctx.Profile
	local owned = prof and (prof.Inventory[id] or 0) > 0
	local equipped = false
	if prof then
		for i = 1, Config.Settings.EquipSlots do
			if prof.Equipped[tostring(i)] == id then
				equipped = true
			end
		end
	end
	refs.Equip.Text = not owned and "НЕТ В КОЛЛЕКЦИИ" or (equipped and "СНЯТЬ" or "ЭКИПИРОВАТЬ")
	refs.Equip.BackgroundColor3 = not owned and Color3.fromRGB(50, 44, 60) or (equipped and Color3.fromRGB(130, 50, 60) or Color3.fromRGB(70, 40, 140))
	refs.Equip.AutoButtonColor = false
	refs.Equip.Active = owned
end

------------------------------------------------------------------------
-- ЭФФЕКТЫ РЕДКОСТИ (лёгкие, в 2D поверх сцены)
------------------------------------------------------------------------
local function setGlow(color)
	for i, g in ipairs(refs.Glows) do
		g.BackgroundColor3 = color
		g.BackgroundTransparency = 0.84 + i * 0.04
	end
	refs.SceneStroke.Color = color
end

local function spawnParticles(color, count)
	for _, p in ipairs(refs.Particles) do
		p:Destroy()
	end
	refs.Particles = {}
	for i = 1, count do
		local p = K.new("Frame", {
			Parent = refs.Scene,
			Size = UDim2.fromOffset(6 + (i % 3) * 2, 6 + (i % 3) * 2),
			BackgroundColor3 = color,
			BackgroundTransparency = 0.2,
			BorderSizePixel = 0,
			Rotation = 45,
			ZIndex = 24,
		})
		p:SetAttribute("Seed", i * 0.6180339 % 1)
		refs.Particles[#refs.Particles + 1] = p
	end
end

local function stepParticles(t)
	for i, p in ipairs(refs.Particles) do
		local seed = p:GetAttribute("Seed") or 0
		local a = (t * (0.08 + seed * 0.06) + seed) % 1
		p.Position = UDim2.new(0.12 + seed * 0.76 + math.sin(t * 1.3 + i) * 0.02, 0, 0.95 - a * 0.9, 0)
		p.BackgroundTransparency = 0.15 + a * 0.85
	end
end

-- Короткое появление секретного юнита: затемнение, красная вспышка, надпись
local function secretIntro()
	local ov = refs.Intro
	ov.Visible = true
	ov.BackgroundTransparency = 0
	refs.IntroText.TextTransparency = 1
	refs.IntroText.Text = "✦ SECRET ✦"
	refs.IntroRing.Size = UDim2.fromScale(0.05, 0.05)
	refs.IntroRing.BackgroundTransparency = 0.1
	state.Zoom = 2.2
	K.tween(refs.IntroText, 0.35, { TextTransparency = 0 })
	K.tween(refs.IntroRing, 0.7, { Size = UDim2.fromScale(1.6, 1.6), BackgroundTransparency = 1 }, Enum.EasingStyle.Quad)
	if FX then
		FX.Sound("Secret", 0.8, 1)
	end
	task.delay(0.55, function()
		if ov.Parent then
			K.tween(ov, 0.6, { BackgroundTransparency = 1 })
			K.tween(refs.IntroText, 0.6, { TextTransparency = 1 })
		end
	end)
	task.delay(1.25, function()
		if ov.Parent then
			ov.Visible = false
		end
	end)
end

local function applyRarityFx(first)
	local rarity = Config.Units[state.Id].Rarity
	local glow = GLOW[rarity] or THEME.Accent
	setGlow(glow)
	-- Mythic — фиолетовые частицы, Legendary — золотые, Epic — синие, Secret — кинематографичное появление
	local counts = { Mythic = 14, Secret = 10, Legendary = 9, Epic = 6 }
	spawnParticles(glow, counts[rarity] or 0)
	-- Хэллоуин: тыква и оранжевые искры поверх основного свечения (не заменяют его)
	local ev = Config.Units[state.Id].Event
	refs.EventPumpkin.Visible = ev == "Halloween"
	for _, p in ipairs(refs.EventSparks) do
		p:Destroy()
	end
	refs.EventSparks = {}
	if ev == "Halloween" then
		for i = 1, 8 do
			local p = K.new("Frame", { Parent = refs.Scene, Size = UDim2.fromOffset(4, 4), BackgroundColor3 = Color3.fromRGB(255, 150, 50), BackgroundTransparency = 0.3, BorderSizePixel = 0, Rotation = 45, ZIndex = 24 })
			p:SetAttribute("Seed", (i * 0.37 + 0.11) % 1)
			refs.EventSparks[#refs.EventSparks + 1] = p
		end
	end
	if first and rarity == "Secret" then
		secretIntro()
	end
end

------------------------------------------------------------------------
-- ОКНО
------------------------------------------------------------------------
local function statRow(parent, order, name)
	local row = K.new("Frame", { Parent = parent, BackgroundColor3 = THEME.BG2, BackgroundTransparency = 0.2, Size = UDim2.new(1, 0, 0, 30), LayoutOrder = order, ZIndex = 23 })
	K.corner(6).Parent = row
	K.label({ Parent = row, Size = UDim2.new(0.5, -8, 1, -8), Position = UDim2.fromOffset(10, 4), Text = name, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = THEME.Dim, Font = Enum.Font.GothamBold, ZIndex = 24 })
	return K.label({ Parent = row, Size = UDim2.new(0.5, -10, 1, -8), Position = UDim2.new(0.5, 0, 0, 4), Text = "", TextXAlignment = Enum.TextXAlignment.Right, Font = Enum.Font.GothamBold, ZIndex = 24 })
end

local function build()
	window = K.new("Frame", { Name = "UnitViewer", Parent = UI.Root, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(1020, 620), BackgroundColor3 = Color3.fromRGB(10, 6, 18), BackgroundTransparency = 0.02, Visible = false, ZIndex = 20 })
	K.corner(14).Parent = window
	K.stroke(THEME.Accent, 2).Parent = window
	K.new("UIGradient", { Parent = window, Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(40, 22, 64), Color3.fromRGB(8, 4, 14)) })
	refs.Scale = K.new("UIScale", { Parent = window })
	-- затемнение фона за окном (клик по нему закрывает)
	refs.Dim = K.new("TextButton", { Name = "ViewerDim", Parent = UI.Root, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, Text = "", AutoButtonColor = false, Visible = false, ZIndex = 19 })
	refs.Dim.Activated:Connect(function()
		UnitViewer.Close()
	end)

	-- ЛЕВАЯ ЧАСТЬ: сцена
	local scene = K.new("Frame", { Parent = window, Position = UDim2.fromOffset(16, 16), Size = UDim2.new(0, 560, 1, -32), BackgroundColor3 = Color3.fromRGB(14, 9, 24), ClipsDescendants = true, ZIndex = 21 })
	refs.Scene = scene
	K.corner(12).Parent = scene
	refs.SceneStroke = K.stroke(THEME.AccentDark, 2)
	refs.SceneStroke.Parent = scene
	K.new("UIGradient", { Parent = scene, Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(34, 20, 56), Color3.fromRGB(6, 4, 12)) })
	-- мягкое свечение за моделью: концентрические круги
	refs.Glows = {}
	for i = 1, 3 do
		local sz = 0.95 - i * 0.2
		local g = K.new("Frame", { Parent = scene, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(sz, sz * 0.9), BackgroundColor3 = THEME.Accent, BackgroundTransparency = 0.8, BorderSizePixel = 0, ZIndex = 21 })
		K.new("UICorner", { Parent = g, CornerRadius = UDim.new(0.5, 0) })
		refs.Glows[i] = g
	end
	refs.Particles = {}
	local vf = K.new("ViewportFrame", { Parent = scene, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Ambient = Color3.fromRGB(120, 105, 150), LightColor = Color3.fromRGB(255, 245, 255), LightDirection = V(-0.5, -1, -0.7), ZIndex = 22, Active = true })
	refs.VF = vf
	refs.World = K.new("WorldModel", { Parent = vf })
	refs.Cam = Instance.new("Camera")
	refs.Cam.FieldOfView = 32
	refs.Cam.Parent = vf
	vf.CurrentCamera = refs.Cam
	K.label({ Parent = scene, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -8), Size = UDim2.new(1, -20, 0, 18), Text = "Тяни мышью или пальцем — вращать  •  колесо / щипок — приблизить", TextColor3 = THEME.Dim, Font = Enum.Font.Gotham, ZIndex = 24 })
	-- анимации
	local animRow = K.new("Frame", { Parent = scene, Position = UDim2.fromOffset(10, 10), Size = UDim2.fromOffset(330, 34), BackgroundTransparency = 1, ZIndex = 24 }, {
		K.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6) }),
	})
	for i, a in ipairs({ { "IDLE", "Idle" }, { "АТАКА", "Attack" }, { "ПОЗА", "Fidget" } }) do
		K.button({ Parent = animRow, Size = UDim2.fromOffset(104, 32), Text = a[1], LayoutOrder = i, BackgroundColor3 = THEME.BG3, ZIndex = 25 }, function()
			UnitViewer.PlayAnim(a[2])
		end)
	end
	-- кнопки способностей (только у юнитов с PreviewAbilities)
	refs.AbilityRow = K.new("Frame", { Parent = scene, Position = UDim2.fromOffset(10, 48), Size = UDim2.fromOffset(420, 32), BackgroundTransparency = 1, ZIndex = 24 }, {
		K.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6) }),
	})
	K.button({ Parent = scene, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 10), Size = UDim2.fromOffset(40, 32), Text = "⟲", BackgroundColor3 = THEME.BG3, ZIndex = 25 }, function()
		if state then
			state.Yaw, state.Pitch, state.Zoom = math.rad(200), math.rad(12), 1
			state.Dist = state.BaseDist
			state.Idle = 0
		end
	end)
	-- галерея призыва / проклятых людей
	refs.GalleryButton = K.button({ Parent = scene, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -56, 0, 10), Size = UDim2.fromOffset(190, 32), Text = "", BackgroundColor3 = Color3.fromRGB(110, 40, 30), StrokeColor = Color3.fromRGB(255, 130, 40), Visible = false, ZIndex = 25 }, function()
		if state then
			showGallery(state.GalleryKind)
		end
	end)
	refs.GalleryInfo = K.label({ Parent = scene, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 10, 1, -30), Size = UDim2.new(1, -20, 0, 120), Text = "", TextScaled = false, TextSize = 13, TextWrapped = true, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Bottom, Visible = false, ZIndex = 25 })
	-- хэллоуинская тыква в углу сцены
	refs.EventPumpkin = K.new("Frame", { Parent = scene, Size = UDim2.fromOffset(40, 40), Position = UDim2.new(1, -54, 1, -64), BackgroundTransparency = 1, Visible = false, ZIndex = 25 })
	UI.Icon("Pumpkin", refs.EventPumpkin, { Size = UDim2.fromScale(1, 1), ZIndex = 25 })
	refs.EventSparks = {}
	-- вступление секретного юнита
	refs.Intro = K.new("Frame", { Parent = scene, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), Visible = false, ZIndex = 30 })
	refs.IntroRing = K.new("Frame", { Parent = refs.Intro, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.05, 0.05), BackgroundColor3 = GLOW.Secret, BorderSizePixel = 0, ZIndex = 31 })
	K.new("UICorner", { Parent = refs.IntroRing, CornerRadius = UDim.new(0.5, 0) })
	K.new("UIAspectRatioConstraint", { Parent = refs.IntroRing })
	refs.IntroText = K.label({ Parent = refs.Intro, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, 0, 0, 60), Text = "", TextColor3 = GLOW.Secret, ZIndex = 32 })

	-- ПРАВАЯ ЧАСТЬ: информация
	local info = K.new("Frame", { Parent = window, Position = UDim2.fromOffset(592, 16), Size = UDim2.new(1, -608, 1, -32), BackgroundTransparency = 1, ZIndex = 21 })
	K.button({ Parent = window, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 14), Size = UDim2.fromOffset(40, 40), Text = "✕", BackgroundColor3 = Color3.fromRGB(120, 30, 50), ZIndex = 26 }, function()
		UnitViewer.Close()
	end)
	refs.RarityBar = K.new("Frame", { Parent = info, Size = UDim2.fromOffset(6, 64), BorderSizePixel = 0, ZIndex = 22 })
	refs.Name = K.label({ Parent = info, Position = UDim2.fromOffset(16, 0), Size = UDim2.new(1, -70, 0, 40), Text = "", TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 22 })
	refs.Rarity = K.label({ Parent = info, Position = UDim2.fromOffset(16, 40), Size = UDim2.new(1, -70, 0, 24), Text = "", TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 22 })
	refs.Desc = K.label({ Parent = info, Position = UDim2.fromOffset(0, 72), Size = UDim2.new(1, 0, 0, 40), Text = "", TextScaled = false, TextSize = 14, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Font = Enum.Font.Gotham, TextColor3 = THEME.Dim, ZIndex = 22 })
	-- переключатель уровней
	local tabs = K.new("Frame", { Parent = info, Position = UDim2.fromOffset(0, 118), Size = UDim2.new(1, 0, 0, 36), BackgroundTransparency = 1, ZIndex = 22 }, {
		K.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6) }),
	})
	refs.Tabs = {}
	for i, name in ipairs(LEVEL_TABS) do
		refs.Tabs[i] = K.button({ Parent = tabs, Size = UDim2.new(0.2, -5, 1, 0), Text = name, LayoutOrder = i, BackgroundColor3 = THEME.BG3, ZIndex = 23 }, function()
			UnitViewer.SetLevel(i)
		end)
	end
	K.label({ Parent = info, Position = UDim2.fromOffset(0, 156), Size = UDim2.new(1, 0, 0, 16), Text = "Предпросмотр: уровень ничего не покупает и не улучшает", TextColor3 = THEME.Dim, Font = Enum.Font.Gotham, ZIndex = 22 })
	-- характеристики
	local stats = K.new("Frame", { Parent = info, Position = UDim2.fromOffset(0, 178), Size = UDim2.new(1, 0, 0, 180), BackgroundTransparency = 1, ZIndex = 22 }, {
		K.new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	refs.StatDamage = statRow(stats, 1, "Урон")
	refs.StatRange = statRow(stats, 2, "Радиус")
	refs.StatSpeed = statRow(stats, 3, "Скорость атаки")
	refs.StatCost = statRow(stats, 4, "Установка")
	refs.StatUpgrade = statRow(stats, 5, "Улучшение")
	-- способности
	local ab = K.new("Frame", { Parent = info, Position = UDim2.fromOffset(0, 364), Size = UDim2.new(1, 0, 0, 108), BackgroundColor3 = THEME.BG2, BackgroundTransparency = 0.2, ZIndex = 22 })
	K.corner(8).Parent = ab
	K.label({ Parent = ab, Position = UDim2.fromOffset(10, 6), Size = UDim2.new(1, -20, 0, 20), Text = "СПОСОБНОСТИ", TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = THEME.Accent, ZIndex = 23 })
	refs.Ability = K.label({ Parent = ab, Position = UDim2.fromOffset(10, 30), Size = UDim2.new(1, -20, 1, -36), Text = "", TextScaled = false, TextSize = 15, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Font = Enum.Font.GothamBold, ZIndex = 23 })
	-- экипировка
	refs.Equip = K.button({ Parent = info, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, 54), Text = "ЭКИПИРОВАТЬ", BackgroundColor3 = Color3.fromRGB(70, 40, 140), ZIndex = 23 }, function()
		if state and UI.ToggleEquip then
			UI.ToggleEquip(state.Id)
		end
	end)
end

------------------------------------------------------------------------
-- ВВОД: вращение и зум
------------------------------------------------------------------------
local function bindInput()
	local dragging, last = false, nil
	conns[#conns + 1] = refs.VF.InputBegan:Connect(function(input)
		local t = input.UserInputType
		if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
			dragging, last = true, input.Position
			state.Idle = 0
		end
	end)
	conns[#conns + 1] = refs.VF.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseWheel then
			state.Zoom = math.clamp(state.Zoom * (input.Position.Z > 0 and 0.88 or 1.14), 0.45, 1.8)
			state.Idle = 0
		end
	end)
	conns[#conns + 1] = UserInputService.InputChanged:Connect(function(input)
		if not dragging or not last then
			return
		end
		local t = input.UserInputType
		if t == Enum.UserInputType.MouseMovement or t == Enum.UserInputType.Touch then
			local d = input.Position - last
			last = input.Position
			state.Yaw = state.Yaw - d.X * 0.012
			state.Pitch = math.clamp(state.Pitch + d.Y * 0.008, math.rad(-15), math.rad(60))
			state.Idle = 0
		end
	end)
	conns[#conns + 1] = UserInputService.InputEnded:Connect(function(input)
		local t = input.UserInputType
		if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
	conns[#conns + 1] = UserInputService.TouchPinch:Connect(function(_, scale, _, inputState)
		if inputState == Enum.UserInputState.Change and scale and scale > 0 then
			state.Zoom = math.clamp(state.Zoom / (1 + (scale - 1) * 0.08), 0.45, 1.8)
			state.Idle = 0
		end
	end)
end

local function step(dt)
	if not state or (not state.Rig and not state.Gallery) then
		return
	end
	local t = os.clock()
	state.Idle = (state.Idle or 0) + dt
	-- плавное автовращение, пока игрок не трогает модель
	if state.Idle > 2.5 then
		state.Yaw = state.Yaw + dt * 0.45
	end
	state.Dist = state.Dist + (state.BaseDist * state.Zoom - state.Dist) * math.min(1, dt * 8)
	updateCamera()
	-- анимация модели (те же позы, что в бою)
	if state.Rig then
		Renderer.PreviewStep(state, t)
	end
	if #refs.Particles > 0 then
		stepParticles(t)
	end
	-- хэллоуинские искры и подпрыгивающая тыква
	for i, p in ipairs(refs.EventSparks) do
		local seed = p:GetAttribute("Seed") or 0
		local a = (t * (0.12 + seed * 0.1) + seed) % 1
		p.Position = UDim2.new(0.08 + seed * 0.84 + math.sin(t * 2 + i) * 0.03, 0, 1 - a, 0)
		p.BackgroundTransparency = 0.25 + a * 0.75
	end
	if refs.EventPumpkin.Visible then
		refs.EventPumpkin.Position = UDim2.new(1, -54, 1, -64 - math.abs(math.sin(t * 3)) * 10)
		refs.EventPumpkin.Rotation = math.sin(t * 3) * 8
	end
	-- союзники в галерее призыва идут на месте
	if state.Gallery then
		for i, g in ipairs(state.Gallery) do
			local rig = g.Rig
			local sw = math.sin(t * 6 + i) * 28
			local m, b = rig.Motors, rig.Base
			if m.RH and b.RH then
				m.RH.C0 = b.RH * ANG(rad(sw), 0, 0)
				m.LH.C0 = b.LH * ANG(rad(-sw), 0, 0)
				m.RS.C0 = b.RS * ANG(rad(-sw * 0.7), 0, 0)
				m.LS.C0 = b.LS * ANG(rad(sw * 0.7), 0, 0)
			end
		end
	end
end

------------------------------------------------------------------------
-- ГАЛЕРЕЯ ПРИЗЫВА: все союзники юнита (или «проклятые люди» руны) в ряд с HP
------------------------------------------------------------------------
local function galleryList(kind)
	local def = Config.Units[state.Id]
	local list = {}
	if kind == "Rune" then
		for i, lv in ipairs(Config.Runes.CursedThreads.Summon.Levels) do
			list[#list + 1] = { Ally = lv.Ally, HP = lv.HP, Text = string.format("LVL %d • x%d • %d HP • каждые 60 с", i, lv.Count, lv.HP) }
		end
	elseif def.Summon then
		for i, lv in ipairs(def.Summon.Levels) do
			list[#list + 1] = { Ally = lv.Ally, HP = lv.HP, Text = string.format("%s • x%d • %d HP • %d с", i == 5 and "MAX" or ("LVL " .. i), lv.Count, lv.HP, lv.Interval) }
		end
		if def.Summon.Golden then
			local g = def.Summon.Golden
			list[#list + 1] = { Ally = g.Ally, HP = g.HP, Text = string.format("MAX • каждый %d-й призыв • %d HP", g.Every, g.HP) }
		end
	end
	return list
end

local function clearGallery()
	if state and state.Gallery then
		for _, g in ipairs(state.Gallery) do
			g.Rig.Model:Destroy()
		end
		state.Gallery = nil
	end
	if refs.GalleryInfo then
		refs.GalleryInfo.Visible = false
	end
end

showGallery = function(kind)
	if not UnitModels.BuildAlly then
		return
	end
	if state.Gallery then
		clearGallery()
		buildModel(true)
		refs.GalleryButton.Text = state.GalleryLabel
		return
	end
	clearScene()
	local list = galleryList(kind)
	state.Gallery = {}
	local n = #list
	local lines = {}
	for i, it in ipairs(list) do
		local ok, rig = pcall(UnitModels.BuildAlly, it.Ally)
		if ok and rig then
			for _, d in ipairs(rig.Model:GetDescendants()) do
				if d:IsA("ParticleEmitter") or d:IsA("PointLight") or d:IsA("Trail") then
					d:Destroy()
				end
			end
			local x = (i - (n + 1) / 2) * 3.4
			rig.Root.CFrame = CF(x, rig.HipHeight, math.abs(x) * 0.25) * ANG(0, math.pi, 0)
			rig.Model.Parent = refs.World
			state.Gallery[#state.Gallery + 1] = { Rig = rig }
		end
		lines[#lines + 1] = string.format("%d. %s — %s", i, Config.Allies[it.Ally].Name, it.Text)
	end
	local glow = GLOW[Config.Units[state.Id].Rarity] or THEME.Accent
	buildPlatform(0, n * 1.9 + 2, glow)
	state.Center = V(0, 2.4, 0)
	state.BaseDist = n * 3.6 + 8
	state.Zoom = 1
	state.Dist = state.BaseDist
	state.Yaw, state.Pitch = math.rad(180), math.rad(10)
	updateCamera()
	refs.GalleryInfo.Text = (kind == "Rune" and "ПРОКЛЯТЫЕ НИТИ — проклятые люди:\n" or "ПРИЗЫВ — союзники идут по дороге навстречу врагам, HP = запас урона:\n") .. table.concat(lines, "\n")
	refs.GalleryInfo.Visible = true
	refs.GalleryButton.Text = "← К ЮНИТУ"
end

------------------------------------------------------------------------
-- ЭФФЕКТЫ СПОСОБНОСТЕЙ В ПРЕДПРОСМОТРЕ (детали внутри WorldModel, удаляются сами)
------------------------------------------------------------------------
local GOLD, ORANGE = Color3.fromRGB(230, 178, 74), Color3.fromRGB(255, 140, 40)

local function fxPart(props, life)
	local p = part(props)
	task.delay(life, function()
		if p.Parent then
			p:Destroy()
		end
	end)
	return p
end

local function previewRing(y, r0, r1, color, time, delay)
	task.delay(delay or 0, function()
		if not state or not refs.World then
			return
		end
		local p = fxPart({ Shape = Enum.PartType.Cylinder, Size = V(0.15, r0 * 2, r0 * 2), CFrame = CF(0, y, 0) * ANG(0, 0, rad(90)), Color = color, Material = Enum.Material.Neon, Transparency = 0.2 }, time + 0.1)
		K.tween(p, time, { Size = V(0.1, r1 * 2, r1 * 2), Transparency = 1 })
	end)
end

-- показать/скрыть шестерни бури на копии модели
local function previewStorm(on)
	if not state or not state.Rig then
		return
	end
	state.Rig.Storm = on
	for _, d in ipairs(state.Rig.Model:GetDescendants()) do
		if d:IsA("BasePart") and d:GetAttribute("StormFX") then
			d.Transparency = on and d:GetAttribute("StormFX") or 1
		end
	end
end

local POWER_FX = {
	LanternBeam = Color3.fromRGB(255, 230, 150), DirtBurst = Color3.fromRGB(140, 110, 80), LeafStorm = Color3.fromRGB(230, 140, 40),
	CurseMark = Color3.fromRGB(120, 255, 110), MidnightToll = Color3.fromRGB(190, 160, 255), PlagueCloud = Color3.fromRGB(140, 230, 80),
	GhostSword = Color3.fromRGB(110, 190, 255), MirrorShatter = Color3.fromRGB(180, 90, 255), ThreadSnap = Color3.fromRGB(230, 30, 50),
	Execution = Color3.fromRGB(255, 110, 30), GhostPumpkin = Color3.fromRGB(255, 140, 40), Summon = Color3.fromRGB(200, 90, 255),
}

previewFx = function(kind)
	local s = state.Rig.Scale or 1
	if POWER_FX[kind] then
		local col = POWER_FX[kind]
		previewRing(0.08, 1, 7 * s, col, 0.8, 0.5)
		previewRing(0.12, 0.5, 4.5 * s, col:Lerp(Color3.new(1, 1, 1), 0.3), 0.6, 0.6)
		return
	end
	if kind == "TimeBreak" then
		previewRing(0.05, 1, 6 * s, GOLD, 0.9, 0.5)
		previewRing(0.1, 0.5, 4 * s, ORANGE, 0.6, 0.55)
	elseif kind == "TimeHaste" then
		previewRing(0.1, 1, 9 * s, GOLD, 1.0, 0.4)
		previewRing(0.15, 1, 7 * s, ORANGE, 0.8, 0.5)
	elseif kind == "TimeStorm" then
		previewStorm(true)
		previewRing(0.1, 1, 8 * s, GOLD, 0.9, 1.3)
		previewRing(0.15, 0.5, 5 * s, ORANGE, 0.6, 1.35)
		local rig = state.Rig
		task.delay(4, function()
			if state and state.Rig == rig then
				previewStorm(false)
			end
		end)
	end
end

------------------------------------------------------------------------
-- API
------------------------------------------------------------------------
function UnitViewer.Open(unitId, level)
	if not Config.Units[unitId] then
		return
	end
	-- 3D-просмотр открывается только для юнитов, которые уже есть в коллекции
	local prof = ctx.Profile
	if not prof or (prof.Inventory[unitId] or 0) <= 0 then
		return
	end
	if not window then
		build()
	end
	state = state or {}
	state.Id = unitId
	state.Level = math.clamp(level or 1, 1, 5)
	state.Idle = 0
	window.Visible = true
	refs.Dim.Visible = true
	refs.Scale.Scale = 0.88
	K.tween(refs.Scale, 0.22, { Scale = 1 }, Enum.EasingStyle.Back)
	clearGallery()
	buildModel(false)
	refreshInfo()
	applyRarityFx(true)
	-- «Посмотреть призыв» у Кукловода и Иллюзиониста, «Проклятые люди» у юнитов с руной «Проклятые нити»
	local def = Config.Units[unitId]
	local hasThreads = prof.RuneSlots and prof.RuneSlots[unitId] == "CursedThreads"
	state.GalleryKind = def.Summon and "Summon" or (hasThreads and "Rune" or nil)
	state.GalleryLabel = def.Summon and "ПОСМОТРЕТЬ ПРИЗЫВ" or "ПРОКЛЯТЫЕ ЛЮДИ"
	refs.GalleryButton.Visible = state.GalleryKind ~= nil
	refs.GalleryButton.Text = state.GalleryLabel
	for _, c in ipairs(refs.AbilityRow:GetChildren()) do
		if c:IsA("GuiButton") then
			c:Destroy()
		end
	end
	for i, ab in ipairs(Config.Units[unitId].PreviewAbilities or {}) do
		K.button({ Parent = refs.AbilityRow, Size = UDim2.fromOffset(132, 30), Text = ab[2], LayoutOrder = i, BackgroundColor3 = Color3.fromRGB(90, 56, 20), StrokeColor = Color3.fromRGB(230, 170, 70), ZIndex = 25 }, function()
			UnitViewer.PlayAnim(ab[1])
		end)
	end
	-- соединения живут только пока окно открыто
	for _, c in ipairs(conns) do
		c:Disconnect()
	end
	conns = {}
	bindInput()
	conns[#conns + 1] = RunService.RenderStepped:Connect(step)
	if FX then
		FX.Sound("Click", 1, 1.1)
	end
end

function UnitViewer.SetLevel(lv)
	if not state then
		return
	end
	state.Level = math.clamp(lv, 1, 5)
	if state.Gallery then
		clearGallery()
		refs.GalleryButton.Text = state.GalleryLabel
	end
	buildModel(true)
	refreshInfo()
	if FX then
		FX.Sound("Upgrade", 0.6, 0.9 + lv * 0.05)
	end
end

function UnitViewer.PlayAnim(kind)
	if state and state.Gallery then
		clearGallery()
		buildModel(true)
		refs.GalleryButton.Text = state.GalleryLabel
	end
	if not state or not state.Rig then
		return
	end
	if kind == "Idle" then
		state.Anim = nil
	elseif kind == "Attack" then
		Renderer.PreviewAttack(state, state.Id, state.Level)
	elseif kind == "Fidget" then
		Renderer.PreviewFidget(state, state.Id)
	else
		-- способность: только анимация и эффекты в окне, на матч не влияет
		Renderer.PreviewAbility(state, kind)
		previewFx(kind)
	end
end

function UnitViewer.Refresh()
	if window and window.Visible and state then
		refreshInfo()
	end
end

function UnitViewer.IsOpen()
	return window ~= nil and window.Visible
end

-- Закрытие: копия модели удаляется, все соединения отключаются — утечек нет
function UnitViewer.Close()
	if not window then
		return
	end
	window.Visible = false
	refs.Dim.Visible = false
	for _, c in ipairs(conns) do
		c:Disconnect()
	end
	conns = {}
	clearGallery()
	clearScene()
	for _, p in ipairs(refs.EventSparks) do
		p:Destroy()
	end
	refs.EventSparks = {}
	spawnParticles(THEME.Accent, 0)
	refs.Intro.Visible = false
	state = nil
end

function UnitViewer.Init(c, ui)
	ctx, UI = c, ui
	K = ui.Kit
	THEME = ui.Theme
	Config, UnitModels, Renderer, FX = c.Config, c.UnitModels, c.Renderer, c.FX
	UserInputService.InputBegan:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.Escape and UnitViewer.IsOpen() then
			UnitViewer.Close()
		end
	end)
end

return UnitViewer
]======] }
FILES[#FILES + 1] = { "StarterPlayerScripts", { "VoidTDClient", "HalloweenUI" }, "ModuleScript", [======[
--!nocheck
-- VOID TD :: HalloweenUI (клиент)
-- Интерфейс события: открытие проклятого сундука, руны (3D-иконки, выбор, надеть/снять),
-- панель очереди на 4 квадратах, бестиарий врагов и боссов.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local HalloweenUI = {}

local ctx, UI, Config, UnitModels, EnemyModels, CaseModels, FX
local K -- конструкторы UI (UI.Kit)
local player = Players.LocalPlayer
local refs = {}

local ORANGE = Color3.fromRGB(255, 130, 30)
local GOLD = Color3.fromRGB(255, 205, 80)
local DARK = Color3.fromRGB(26, 12, 16)

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

------------------------------------------------------------------------
-- 3D-ИКОНКА РУНЫ
------------------------------------------------------------------------
function HalloweenUI.RuneViewport(parent, runeId, props)
	props = props or {}
	local vf = K.new("ViewportFrame", {
		Parent = parent,
		BackgroundTransparency = 1,
		Size = props.Size or UDim2.fromScale(1, 1),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.new(),
		Ambient = rgb(170, 140, 130),
		LightColor = rgb(255, 240, 220),
		LightDirection = Vector3.new(-0.5, -1, -0.7),
		ZIndex = props.ZIndex or 1,
	})
	if not UnitModels.BuildRune then
		return vf
	end
	local ok, r = pcall(UnitModels.BuildRune, runeId)
	if not ok or not r then
		return vf
	end
	r.Model.Parent = vf
	local cam = Instance.new("Camera")
	cam.FieldOfView = 30
	cam.CFrame = CFrame.lookAt(Vector3.new(2.2, 1.4, -6.5), Vector3.new(0, 0, 0))
	cam.Parent = vf
	vf.CurrentCamera = cam
	vf:SetAttribute("Spin", true)
	refs.RuneSpins = refs.RuneSpins or {}
	table.insert(refs.RuneSpins, { Model = r.Model, VF = vf })
	return vf, r
end

-- карточка руны в итогах открытия
function HalloweenUI.RuneCard(grid, r, i)
	local rd = Config.Runes[r.Rune]
	local col = Config.RuneRarity.Color
	local card = K.panel({ Parent = grid, BackgroundColor3 = UI.Theme.BG2, StrokeColor = col, LayoutOrder = i, ZIndex = 23 })
	K.new("UIGradient", { Parent = card, Rotation = 90, Color = ColorSequence.new(col:Lerp(UI.Theme.BG, 0.55), UI.Theme.BG) })
	HalloweenUI.RuneViewport(card, r.Rune, { Size = UDim2.new(1, 0, 0, 120), Position = UDim2.fromOffset(0, 8), ZIndex = 24 })
	K.label({ Parent = card, Size = UDim2.new(1, -8, 0, 22), Position = UDim2.fromOffset(4, 130), Text = rd.Name, ZIndex = 24 })
	K.label({ Parent = card, Size = UDim2.new(1, -8, 0, 18), Position = UDim2.fromOffset(4, 154), Text = "РУНА • " .. Config.RuneRarity.Name, TextColor3 = col, ZIndex = 24 })
	local sc = K.new("UIScale", { Parent = card, Scale = 0 })
	K.tween(sc, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
end

------------------------------------------------------------------------
-- ОТКРЫТИЕ ПРОКЛЯТОГО СУНДУКА
------------------------------------------------------------------------
-- Камера приближается, сундук трясётся, глаза и огонь разгораются, цепи рвутся, крышка открывается,
-- из сундука поднимается награда (3D-модель юнита или 3D-руна), затем имя и редкость. SECRET — отдельная сцена.
function HalloweenUI.PlayOpening(results, showCards)
	local r0 = results[1]
	local isRune = r0.Rune ~= nil
	local def = r0.Id and Config.Units[r0.Id]
	local rarity = def and def.Rarity or "Rune"
	local color = isRune and Config.RuneRarity.Color or Config.Rarities[rarity].Color
	local secret = rarity == "Secret"
	local gui = UI.Root
	local overlay = K.new("Frame", { Parent = gui, Size = UDim2.fromScale(1, 1), BackgroundColor3 = rgb(8, 2, 4), BackgroundTransparency = 0.1, ZIndex = 20 })
	local vf = K.new("ViewportFrame", { Parent = overlay, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(620, 620), Position = UDim2.fromScale(0.5, 0.52), Ambient = rgb(120, 80, 70), LightColor = rgb(255, 210, 160), LightDirection = Vector3.new(-0.4, -1, -0.8), ZIndex = 21 })
	local chest = CaseModels.Build("Halloween")
	chest.Model.Parent = vf
	local cam = Instance.new("Camera")
	cam.FieldOfView = 40
	cam.Parent = vf
	vf.CurrentCamera = cam
	local title = K.label({ Parent = overlay, AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.fromOffset(700, 56), Position = UDim2.new(0.5, 0, 0.05, 0), Text = "HALLOWEEN CASE", TextColor3 = ORANGE, ZIndex = 22, StrokeThickness = 3 })
	local glow = K.new("Frame", { Parent = overlay, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.55), Size = UDim2.fromOffset(10, 10), BackgroundColor3 = ORANGE, BackgroundTransparency = 1, ZIndex = 20 })
	K.corner(300).Parent = glow

	local base = chest.Base
	local lid = {}
	for _, p in ipairs(chest.LidParts or { chest.Lid }) do
		lid[p] = true
	end
	local chains = {}
	for _, p in ipairs(chest.Chains or {}) do
		chains[p] = Vector3.new(math.random() - 0.5, math.random() * 0.8 + 0.2, math.random() - 0.5).Unit
	end
	local hinge = chest.Hinge or CFrame.new(0, 2.7, 1.4)
	local eyes = chest.Eyes or {}
	local eyeColor = {}
	for _, e in ipairs(eyes) do
		eyeColor[e] = e.Color
	end

	local SHAKE, BREAK, OPEN, RISE = 1.6, 0.5, 0.7, 0.9
	local start = os.clock()
	local nextTick = 0
	local reward, rewardBase
	local done = false
	local conn
	FX.Sound("CaseShake", 1, 0.6)
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - start
		-- камера плавно приближается
		local k = math.clamp(t / (SHAKE + BREAK), 0, 1)
		local dist = 15 - k * 4.5
		cam.CFrame = CFrame.lookAt(Vector3.new(0, 4.5 - k * 0.6, -dist), Vector3.new(0, 2.4, 0))
		if t < SHAKE then
			local a = t / SHAKE
			local shake = CFrame.new((math.random() - 0.5) * a * 0.35, 0, (math.random() - 0.5) * a * 0.35) * CFrame.Angles(0, 0, (math.random() - 0.5) * a * 0.12)
			for p, b in pairs(base) do
				p.CFrame = shake * b
			end
			for _, e in ipairs(eyes) do
				e.Color = eyeColor[e]:Lerp(rgb(255, 240, 180), a)
			end
			glow.Size = UDim2.fromOffset(60 + a * 300, 60 + a * 300)
			glow.BackgroundTransparency = 1 - a * 0.25
			if t >= nextTick then
				nextTick = t + 0.42 - a * 0.28
				FX.Sound("CaseShake", 1, 0.6 + a * 0.6)
			end
		elseif t < SHAKE + BREAK then
			-- цепи рвутся и разлетаются
			local a = (t - SHAKE) / BREAK
			if not chest.Broke then
				chest.Broke = true
				FX.Sound("CaseOpen", 1, 0.7)
				local flash = K.new("Frame", { Parent = overlay, Size = UDim2.fromScale(1, 1), BackgroundColor3 = ORANGE, BackgroundTransparency = 0.3, ZIndex = 30 })
				K.tween(flash, 0.5, { BackgroundTransparency = 1 })
				task.delay(0.55, function()
					flash:Destroy()
				end)
			end
			for p, b in pairs(base) do
				if chains[p] then
					local d = chains[p]
					p.CFrame = CFrame.new(d * a * 9 + Vector3.new(0, -a * a * 3, 0)) * b * CFrame.Angles(a * 5 * d.X, a * 4, a * 5 * d.Z)
					p.Transparency = math.min(1, a * 1.2)
				elseif not lid[p] then
					p.CFrame = b
				end
			end
		elseif t < SHAKE + BREAK + OPEN then
			-- крышка открывается на петле
			local a = (t - SHAKE - BREAK) / OPEN
			local ang = math.rad(110) * (1 - (1 - a) ^ 3)
			for p in pairs(lid) do
				if base[p] then
					p.CFrame = hinge * CFrame.Angles(ang, 0, 0) * hinge:Inverse() * base[p]
				end
			end
			glow.BackgroundColor3 = color
			glow.Size = UDim2.fromOffset(360 + a * 200, 360 + a * 200)
		elseif t < SHAKE + BREAK + OPEN + RISE then
			-- награда поднимается из сундука
			local a = (t - SHAKE - BREAK - OPEN) / RISE
			if not reward then
				FX.Sound("Reveal", 1, isRune and 1.2 or 0.7 + (Config.Rarities[rarity] and Config.Rarities[rarity].Order or 3) * 0.12)
				if isRune and UnitModels.BuildRune then
					local ok, rr = pcall(UnitModels.BuildRune, r0.Rune)
					if ok and rr then
						reward = rr.Model
						reward:ScaleTo(1.2)
					end
				elseif def then
					local ok, rig = pcall(UnitModels.Build, r0.Id, 1)
					if ok and rig then
						reward = rig.Model
						for _, d in ipairs(reward:GetDescendants()) do
							if d:IsA("ParticleEmitter") or d:IsA("Trail") then
								d:Destroy()
							end
						end
						rewardBase = rig.HipHeight
					end
				end
				if reward then
					reward.Parent = vf
				end
			end
			if reward then
				local y = 1.5 + a * (isRune and 3.8 or 2.2) + (rewardBase or 0) * a
				reward:PivotTo(CFrame.new(0, y, -0.6) * CFrame.Angles(0, math.pi + a * math.pi * 2, 0))
			end
		elseif not done then
			done = true
			conn:Disconnect()
			local function finish()
				title.Text = isRune and ("РУНА «" .. Config.Runes[r0.Rune].Name .. "»") or def.Name
				title.TextColor3 = color
				K.label({ Parent = overlay, AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.fromOffset(600, 34), Position = UDim2.new(0.5, 0, 0.05, 60), Text = isRune and ("РУНА • " .. Config.RuneRarity.Name) or (rarity:upper() .. "  •  " .. Config.Events.Halloween.Tag), TextColor3 = isRune and color or ORANGE, ZIndex = 22 })
				if r0.New then
					local tag = K.label({ Parent = overlay, AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.fromOffset(160, 34), Position = UDim2.new(0.5, 220, 0.05, 0), Text = "NEW!", TextColor3 = GOLD, ZIndex = 23 })
					tag.Rotation = -12
				end
				K.button({ Parent = overlay, AnchorPoint = Vector2.new(0.5, 1), Size = UDim2.fromOffset(200, 54), Position = UDim2.new(0.5, 0, 0.95, 0), Text = "OK", BackgroundColor3 = rgb(110, 50, 20), StrokeColor = ORANGE, ZIndex = 25 }, function()
					overlay:Destroy()
				end)
				-- награда продолжает медленно вращаться
				local t0 = os.clock()
				local spin
				spin = RunService.RenderStepped:Connect(function()
					if not overlay.Parent then
						spin:Disconnect()
						return
					end
					if reward and reward.Parent then
						local y = 1.5 + (isRune and 3.8 or 2.2) + (rewardBase or 0) + math.sin((os.clock() - t0) * 2) * 0.15
						reward:PivotTo(CFrame.new(0, y, -0.6) * CFrame.Angles(0, math.pi + (os.clock() - t0) * 0.8, 0))
					end
				end)
			end
			if secret then
				-- SECRET: чёрный экран, оранжево-красные вспышки, тряска, затем награда
				FX.Sound("Secret", 1, 0.9)
				FX.Shake(0.8, 1.4)
				local black = K.new("Frame", { Parent = overlay, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), ZIndex = 40 })
				local big = K.label({ Parent = black, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(900, 160), Position = UDim2.fromScale(0.5, 0.45), Text = "SECRET!!", TextColor3 = ORANGE, ZIndex = 41, StrokeThickness = 4 })
				K.label({ Parent = black, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(700, 50), Position = UDim2.fromScale(0.5, 0.6), Text = def.Name, TextColor3 = Color3.fromRGB(255, 60, 60), ZIndex = 41 })
				for i = 1, 10 do
					task.delay(i * 0.12, function()
						black.BackgroundColor3 = (i % 2 == 0) and rgb(140, 40, 0) or Color3.new(0, 0, 0)
						big.Rotation = (math.random() - 0.5) * 10
					end)
				end
				task.delay(1.6, function()
					K.tween(black, 0.5, { BackgroundTransparency = 1 })
					for _, d in ipairs(black:GetDescendants()) do
						if d:IsA("TextLabel") then
							K.tween(d, 0.4, { TextTransparency = 1 })
						end
					end
					task.delay(0.55, function()
						black:Destroy()
					end)
					finish()
				end)
			else
				finish()
			end
		end
	end)
	local _ = showCards
end

------------------------------------------------------------------------
-- РУНЫ: выбор для юнита
------------------------------------------------------------------------
local pickerUnit

local function buildRunePicker()
	local m = K.modal("Runes", "РУНЫ", UDim2.fromOffset(720, 420), "Rune")
	refs.RuneFor = K.label({ Parent = m, Size = UDim2.new(1, -36, 0, 24), Position = UDim2.fromOffset(18, 58), Text = "", TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = UI.Theme.Dim, Font = Enum.Font.GothamBold, ZIndex = 6 })
	refs.RuneRow = K.new("Frame", { Parent = m, BackgroundTransparency = 1, Size = UDim2.new(1, -36, 0, 270), Position = UDim2.fromOffset(18, 88), ZIndex = 6 }, {
		K.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 12), HorizontalAlignment = Enum.HorizontalAlignment.Center }),
	})
	refs.RuneRemove = K.button({ Parent = m, AnchorPoint = Vector2.new(0.5, 1), Size = UDim2.fromOffset(260, 44), Position = UDim2.new(0.5, 0, 1, -12), Text = "СНЯТЬ РУНУ", BackgroundColor3 = rgb(110, 40, 50), ZIndex = 6 }, function()
		if pickerUnit then
			ctx.Request("EquipRune", { Unit = pickerUnit })
		end
	end)
end

local function refreshPicker()
	local prof = ctx.Profile
	if not pickerUnit or not prof or not refs.RuneRow then
		return
	end
	local def = Config.Units[pickerUnit]
	local current = prof.RuneSlots and prof.RuneSlots[pickerUnit]
	refs.RuneFor.Text = "Юнит: " .. def.Name .. "  •  1 руна на юнита. Руна работает, только когда надета."
	refs.RuneRemove.Visible = current ~= nil
	for _, c in ipairs(refs.RuneRow:GetChildren()) do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	for i, runeId in ipairs(Config.RuneOrder) do
		local rd = Config.Runes[runeId]
		local have = prof.Runes and prof.Runes[runeId] or 0
		local used = 0
		for _, r in pairs(prof.RuneSlots or {}) do
			if r == runeId then
				used = used + 1
			end
		end
		local on = current == runeId
		local card = K.panel({ Parent = refs.RuneRow, Size = UDim2.fromOffset(210, 266), BackgroundColor3 = UI.Theme.BG2, StrokeColor = on and GOLD or (have > 0 and rd.Color or rgb(60, 50, 60)), LayoutOrder = i, ZIndex = 7 })
		HalloweenUI.RuneViewport(card, runeId, { Size = UDim2.new(1, 0, 0, 96), ZIndex = 8 })
		K.label({ Parent = card, Size = UDim2.new(1, -12, 0, 22), Position = UDim2.fromOffset(6, 96), Text = rd.Name, TextColor3 = rd.Color, ZIndex = 8 })
		K.label({ Parent = card, Size = UDim2.new(1, -12, 0, 16), Position = UDim2.fromOffset(6, 118), Text = string.format("есть: %d  •  надето: %d", have, used), TextColor3 = UI.Theme.Dim, Font = Enum.Font.GothamBold, ZIndex = 8 })
		K.label({ Parent = card, Size = UDim2.new(1, -12, 0, 76), Position = UDim2.fromOffset(6, 136), Text = rd.Description, TextScaled = false, TextSize = 12, TextWrapped = true, Font = Enum.Font.Gotham, TextColor3 = UI.Theme.Text, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 8 })
		local free = have - used + (on and 1 or 0)
		K.button({ Parent = card, AnchorPoint = Vector2.new(0.5, 1), Size = UDim2.new(1, -16, 0, 38), Position = UDim2.new(0.5, 0, 1, -8), Text = on and "НАДЕТА" or (have == 0 and "НЕТ РУНЫ" or (free > 0 and "НАДЕТЬ" or "ЗАНЯТА")), BackgroundColor3 = on and rgb(90, 70, 20) or (free > 0 and rgb(60, 110, 60) or rgb(60, 50, 60)), ZIndex = 8 }, function()
			if on or have == 0 then
				return
			end
			ctx.Request("EquipRune", { Unit = pickerUnit, Rune = runeId })
		end)
	end
end

function HalloweenUI.OpenRunePicker(unitId)
	pickerUnit = unitId
	UI.Show("Runes", true)
	refreshPicker()
end

function HalloweenUI.OnProfile(prof)
	if UI.Modals.Runes and UI.Modals.Runes.Visible then
		refreshPicker()
	end
end

------------------------------------------------------------------------
-- ОЧЕРЕДЬ НА 4 КВАДРАТАХ
------------------------------------------------------------------------
local function buildQueue()
	local p = K.panel({ Parent = UI.Root, AnchorPoint = Vector2.new(1, 0.5), Size = UDim2.fromOffset(330, 330), Position = UDim2.new(1, -110, 0.5, 0), StrokeColor = ORANGE, Visible = false, ZIndex = 4 })
	refs.Queue = p
	K.label({ Parent = p, Size = UDim2.new(1, -20, 0, 32), Position = UDim2.fromOffset(10, 8), Text = "🎃 HALLOWEEN TD", TextColor3 = ORANGE, ZIndex = 5 })
	refs.QMembers = K.label({ Parent = p, Size = UDim2.new(1, -20, 0, 92), Position = UDim2.fromOffset(10, 44), Text = "", TextScaled = false, TextSize = 17, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 5 })
	refs.QHost = K.label({ Parent = p, Size = UDim2.new(1, -20, 0, 18), Position = UDim2.fromOffset(10, 140), Text = "", TextColor3 = UI.Theme.Dim, Font = Enum.Font.GothamBold, ZIndex = 5 })
	local row = K.new("Frame", { Parent = p, BackgroundTransparency = 1, Size = UDim2.new(1, -20, 0, 44), Position = UDim2.fromOffset(10, 164), ZIndex = 5 }, {
		K.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6) }),
	})
	refs.QDiff = {}
	for i, key in ipairs(Config.Halloween.Difficulties) do
		local d = Config.Difficulties[key]
		refs.QDiff[key] = K.button({ Parent = row, Size = UDim2.fromOffset(98, 44), Text = d.Name .. "\n" .. Config.Halloween.Coins[key] .. "🎃", TextColor3 = d.Color, BackgroundColor3 = UI.Theme.BG2, StrokeColor = d.Color, LayoutOrder = i, ZIndex = 6 }, function()
			ctx.Request("QueueDifficulty", { Difficulty = key })
		end)
	end
	refs.QTimer = K.label({ Parent = p, Size = UDim2.new(1, -20, 0, 30), Position = UDim2.fromOffset(10, 214), Text = "", TextColor3 = GOLD, ZIndex = 5 })
	refs.QStart = K.button({ Parent = p, Size = UDim2.new(0.5, -14, 0, 44), Position = UDim2.new(0, 10, 1, -54), Text = "СТАРТ", BackgroundColor3 = rgb(140, 70, 20), StrokeColor = ORANGE, ZIndex = 6 }, function()
		ctx.Request("QueueStart")
	end)
	K.button({ Parent = p, Size = UDim2.new(0.5, -14, 0, 44), Position = UDim2.new(0.5, 4, 1, -54), Text = "ВЫЙТИ", BackgroundColor3 = rgb(110, 30, 40), StrokeColor = UI.Theme.Bad, ZIndex = 6 }, function()
		ctx.Request("QueueLeave")
	end)
end

function HalloweenUI.UpdateQueue()
	local st = ctx.State
	local names = st:GetAttribute("HQ_Members") or ""
	local inQueue = false
	local list = {}
	for n in string.gmatch(names, "[^\n]+") do
		list[#list + 1] = n
		if n == player.DisplayName then
			inQueue = true
		end
	end
	local p = refs.Queue
	if not p then
		return
	end
	p.Visible = inQueue and not player:GetAttribute("InMatch")
	if not p.Visible then
		return
	end
	local isHost = (st:GetAttribute("HQ_Host") or 0) == player.UserId
	local lines = {}
	for i = 1, Config.HalloweenIsland.Queue.MaxPlayers do
		lines[i] = (i == 1 and "👑 " or "• ") .. (list[i] or "свободно")
	end
	refs.QMembers.Text = table.concat(lines, "\n")
	refs.QHost.Text = isHost and "Ты хост: выбери сложность" or "Сложность выбирает хост"
	local diff = st:GetAttribute("HQ_Diff") or "Easy"
	for key, b in pairs(refs.QDiff) do
		b.BackgroundColor3 = key == diff and Config.Difficulties[key].Color:Lerp(Color3.new(0, 0, 0), 0.4) or UI.Theme.BG2
		b.Active = isHost
		b.AutoButtonColor = false
	end
	refs.QStart.Visible = isHost
	local at = st:GetAttribute("HQ_At") or 0
	if st:GetAttribute("HQ_Busy") then
		refs.QTimer.Text = "Арена занята — ждём конца матча"
	elseif at > 0 then
		refs.QTimer.Text = "Телепорт через " .. math.max(0, math.ceil(at - workspace:GetServerTimeNow())) .. " c"
	else
		refs.QTimer.Text = ""
	end
end

------------------------------------------------------------------------
-- БЕСТИАРИЙ
------------------------------------------------------------------------
local function enemyViewport(parent, id, props)
	local vf = K.new("ViewportFrame", { Parent = parent, BackgroundTransparency = 1, Size = props.Size, Position = props.Position or UDim2.new(), Ambient = rgb(150, 130, 160), LightColor = rgb(255, 240, 230), LightDirection = Vector3.new(-0.5, -1, -0.8), ZIndex = props.ZIndex or 1 })
	local ok, rig = pcall(EnemyModels.Build, id)
	if not ok then
		return vf
	end
	for _, d in ipairs(rig.Model:GetDescendants()) do
		if d:IsA("ParticleEmitter") or d:IsA("Trail") or d:IsA("PointLight") then
			d:Destroy()
		end
	end
	rig.Model.Parent = vf
	local cam = Instance.new("Camera")
	cam.FieldOfView = 34
	local h = rig.Height or 5
	local c = Vector3.new(0, h * 0.5 - rig.HipHeight, 0)
	cam.CFrame = CFrame.lookAt(c + Vector3.new(h * 0.45, h * 0.25, -h * 1.7), c)
	cam.Parent = vf
	vf.CurrentCamera = cam
	return vf
end

local function buildBestiary()
	local m = K.modal("Bestiary", "БЕСТИАРИЙ • HAUNTED HOLLOW", UDim2.fromOffset(940, 580), "Pumpkin")
	local grid = K.new("ScrollingFrame", { Parent = m, BackgroundTransparency = 1, Size = UDim2.new(1, -36, 1, -80), Position = UDim2.fromOffset(18, 66), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 6, BorderSizePixel = 0, ZIndex = 6 }, {
		K.new("UIGridLayout", { CellSize = UDim2.fromOffset(212, 236), CellPadding = UDim2.fromOffset(10, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	refs.BestiaryGrid = grid
	refs.BestiaryBuilt = false
end

local BOSS_OF = { GraveWarden = "Easy", FogReaper = "Medium", CursedMonarch = "Hard" }
local function fillBestiary()
	if refs.BestiaryBuilt then
		return
	end
	refs.BestiaryBuilt = true
	for order, id in ipairs(Config.EnemyOrder) do
		local e = Config.Enemies[id]
		if e.Event == "Halloween" then
			local diff = BOSS_OF[id] and Config.Difficulties[BOSS_OF[id]]
			local col = diff and diff.Color or (e.MiniBoss and rgb(200, 90, 255) or ORANGE)
			local card = K.panel({ Parent = refs.BestiaryGrid, BackgroundColor3 = UI.Theme.BG2, StrokeColor = col, LayoutOrder = order, ZIndex = 7 })
			enemyViewport(card, id, { Size = UDim2.new(1, 0, 0, 110), ZIndex = 8 })
			K.label({ Parent = card, Size = UDim2.new(1, -10, 0, 22), Position = UDim2.fromOffset(5, 110), Text = e.Name, TextColor3 = col, ZIndex = 8 })
			local tag = diff and ("ФИНАЛЬНЫЙ БОСС • " .. diff.Name) or (e.MiniBoss and "МИНИ-БОСС" or "ВРАГ")
			K.label({ Parent = card, Size = UDim2.new(1, -10, 0, 14), Position = UDim2.fromOffset(5, 132), Text = string.format("%s  •  HP %d  •  скор. %g", tag, e.Health, e.Speed), TextColor3 = UI.Theme.Dim, Font = Enum.Font.GothamBold, ZIndex = 8 })
			K.label({ Parent = card, Size = UDim2.new(1, -12, 0, 80), Position = UDim2.fromOffset(6, 150), Text = e.Description or "", TextScaled = false, TextSize = 12, TextWrapped = true, Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 8 })
		end
	end
end

HalloweenUI.FillBestiary = fillBestiary

------------------------------------------------------------------------
function HalloweenUI.Init(c, ui)
	ctx, UI = c, ui
	Config, UnitModels, EnemyModels, CaseModels, FX = c.Config, c.UnitModels, c.EnemyModels, c.CaseModels, c.FX
	K = UI.Kit
	buildRunePicker()
	buildQueue()
	buildBestiary()
	-- 3D-руны медленно вращаются
	RunService.RenderStepped:Connect(function()
		local list = refs.RuneSpins
		if not list then
			return
		end
		local t = os.clock()
		for i = #list, 1, -1 do
			local it = list[i]
			if not it.VF.Parent then
				table.remove(list, i)
			elseif it.VF.Visible then
				it.Model:PivotTo(CFrame.new(0, math.sin(t * 1.6) * 0.08, 0) * CFrame.Angles(0, t * 0.9, 0))
			end
		end
	end)
end

return HalloweenUI
]======] }
FILES[#FILES + 1] = { "StarterPlayerScripts", { "VoidTDClient", "UI" }, "ModuleScript", [======[
--!nocheck
-- VOID TD :: UI (клиент)
-- Весь интерфейс создаётся кодом: HUD, хотбар, панель юнита, Summon, инвентарь, уведомления.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local UI = {}

local ctx, Config, UnitModels, Renderer, FX
local player = Players.LocalPlayer
local UnitViewer = require(script.Parent:WaitForChild("UnitViewer"))
local HalloweenUI = require(script.Parent:WaitForChild("HalloweenUI"))

local THEME = {
	BG = Color3.fromRGB(16, 10, 26),
	BG2 = Color3.fromRGB(32, 20, 50),
	BG3 = Color3.fromRGB(48, 30, 72),
	Accent = Color3.fromRGB(170, 80, 255),
	AccentDark = Color3.fromRGB(90, 40, 150),
	Text = Color3.fromRGB(242, 234, 255),
	Dim = Color3.fromRGB(170, 155, 195),
	Good = Color3.fromRGB(90, 220, 140),
	Bad = Color3.fromRGB(255, 80, 110),
	Gold = Color3.fromRGB(255, 205, 70),
	Pink = Color3.fromRGB(255, 70, 170),
}
UI.Theme = THEME

local gui
local refs = {}

------------------------------------------------------------------------
-- КОНСТРУКТОРЫ
------------------------------------------------------------------------
local CUSTOM = { Parent = true, Radius = true, StrokeColor = true, StrokeThickness = true }

local function new(class, props, children)
	local o = Instance.new(class)
	for k, v in pairs(props or {}) do
		if not CUSTOM[k] then
			o[k] = v
		end
	end
	for _, c in ipairs(children or {}) do
		c.Parent = o
	end
	if props and props.Parent then
		o.Parent = props.Parent
	end
	return o
end

local function corner(r)
	return new("UICorner", { CornerRadius = UDim.new(0, r or 8) })
end

local function stroke(color, th, transparency)
	return new("UIStroke", { Name = "Border", Color = color or THEME.Accent, Thickness = th or 2, Transparency = transparency or 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end

local function textStroke(th)
	return new("UIStroke", { Color = Color3.fromRGB(10, 0, 20), Thickness = th or 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual })
end

local function pad(px)
	return new("UIPadding", { PaddingLeft = UDim.new(0, px), PaddingRight = UDim.new(0, px), PaddingTop = UDim.new(0, px), PaddingBottom = UDim.new(0, px) })
end

local function tween(o, t, goal, style, dir)
	local tw = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), goal)
	tw:Play()
	return tw
end

local function panel(props)
	props.BackgroundColor3 = props.BackgroundColor3 or THEME.BG
	props.BackgroundTransparency = props.BackgroundTransparency or 0.12
	props.BorderSizePixel = 0
	local f = new("Frame", props)
	corner(props.Radius or 10).Parent = f
	stroke(props.StrokeColor or THEME.AccentDark, 2).Parent = f
	return f
end

local function label(props)
	props.BackgroundTransparency = 1
	props.Font = props.Font or Enum.Font.FredokaOne
	props.TextColor3 = props.TextColor3 or THEME.Text
	if props.TextScaled == nil then
		props.TextScaled = true
	end
	local l = new("TextLabel", props)
	textStroke(props.StrokeThickness).Parent = l
	return l
end

local function button(props, onClick)
	props.BackgroundColor3 = props.BackgroundColor3 or THEME.BG3
	props.BorderSizePixel = 0
	props.AutoButtonColor = false
	props.Font = props.Font or Enum.Font.FredokaOne
	props.TextColor3 = props.TextColor3 or THEME.Text
	if props.TextScaled == nil then
		props.TextScaled = true
	end
	local b = new("TextButton", props)
	corner(props.Radius or 8).Parent = b
	stroke(props.StrokeColor or THEME.Accent, 2).Parent = b
	textStroke().Parent = b
	local scale = new("UIScale", { Parent = b })
	b.MouseEnter:Connect(function()
		tween(scale, 0.12, { Scale = 1.06 })
	end)
	b.MouseLeave:Connect(function()
		tween(scale, 0.12, { Scale = 1 })
	end)
	b.MouseButton1Down:Connect(function()
		tween(scale, 0.06, { Scale = 0.94 })
	end)
	b.MouseButton1Up:Connect(function()
		tween(scale, 0.1, { Scale = 1.04 })
	end)
	if onClick then
		b.Activated:Connect(onClick)
	end
	return b
end

------------------------------------------------------------------------
-- ИКОНКИ: рисуются из фигур (без эмодзи и загруженных картинок)
------------------------------------------------------------------------
-- фигура в долях контейнера: центр (x, y), размер (w, h), поворот, скругление
local function shape(parent, x, y, w, h, color, rot, round, z, props)
	local f = new("Frame", {
		Parent = parent,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(x, y),
		Size = UDim2.fromScale(w, h),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Rotation = rot or 0,
		ZIndex = z or 1,
	})
	if round then
		new("UICorner", { Parent = f, CornerRadius = UDim.new(round, 0) })
	end
	for k, v in pairs(props or {}) do
		f[k] = v
	end
	return f
end

local function shade(f, top, bottom, rot)
	new("UIGradient", { Parent = f, Rotation = rot or 90, Color = ColorSequence.new(top, bottom) })
end

local ICONS = {}

-- кристалл: огранённый ромб с бликом
function ICONS.Gem(c, z)
	local o = shape(c, 0.5, 0.52, 0.6, 0.6, Color3.new(1, 1, 1), 45, 0.12, z)
	shade(o, Color3.fromRGB(150, 210, 255), Color3.fromRGB(80, 70, 220), 45)
	new("UIStroke", { Parent = o, Color = Color3.fromRGB(20, 14, 50), Thickness = 2 })
	shape(c, 0.5, 0.4, 0.28, 0.28, Color3.fromRGB(215, 240, 255), 45, 0.1, z + 1, { BackgroundTransparency = 0.15 })
	shape(c, 0.38, 0.38, 0.08, 0.16, Color3.new(1, 1, 1), 45, 0.5, z + 2, { BackgroundTransparency = 0.1 })
end

-- монета
function ICONS.Coin(c, z)
	local o = shape(c, 0.5, 0.5, 0.74, 0.74, Color3.new(1, 1, 1), 0, 0.5, z)
	shade(o, Color3.fromRGB(255, 225, 110), Color3.fromRGB(190, 120, 30))
	new("UIStroke", { Parent = o, Color = Color3.fromRGB(70, 40, 10), Thickness = 2 })
	local i = shape(c, 0.5, 0.5, 0.5, 0.5, Color3.fromRGB(215, 150, 45), 0, 0.5, z + 1)
	new("TextLabel", { Parent = i, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "$", TextScaled = true, Font = Enum.Font.FredokaOne, TextColor3 = Color3.fromRGB(90, 50, 10), ZIndex = z + 2 })
end

-- шлем рыцаря Пустоты с Т-визором
function ICONS.Helmet(c, z)
	local acc = Color3.fromRGB(196, 130, 255)
	for _, sx in ipairs({ -1, 1 }) do
		shape(c, 0.5 + 0.26 * sx, 0.26, 0.09, 0.3, Color3.fromRGB(215, 205, 190), 28 * sx, 0.3, z)
	end
	local h = shape(c, 0.5, 0.55, 0.54, 0.62, Color3.new(1, 1, 1), 0, 0.22, z + 1)
	shade(h, Color3.fromRGB(110, 106, 130), Color3.fromRGB(40, 36, 54))
	new("UIStroke", { Parent = h, Color = Color3.fromRGB(16, 12, 24), Thickness = 2 })
	shape(c, 0.5, 0.2, 0.1, 0.18, Color3.fromRGB(90, 86, 110), 0, 0.3, z)
	shape(c, 0.5, 0.48, 0.38, 0.07, acc, 0, 0.5, z + 2)
	shape(c, 0.5, 0.6, 0.07, 0.24, acc, 0, 0.5, z + 2)
end

-- шестерёнка настроек
function ICONS.Gear(c, z)
	local col = Color3.fromRGB(190, 186, 210)
	for k = 0, 7 do
		local a = k / 8 * math.pi * 2
		shape(c, 0.5 + math.cos(a) * 0.3, 0.5 + math.sin(a) * 0.3, 0.16, 0.16, col, math.deg(a), 0.15, z)
	end
	shape(c, 0.5, 0.5, 0.6, 0.6, col, 0, 0.5, z + 1)
	shape(c, 0.5, 0.5, 0.26, 0.26, Color3.fromRGB(34, 30, 48), 0, 0.5, z + 2)
end

-- стрелка «назад»
function ICONS.Back(c, z)
	local col = Color3.fromRGB(255, 235, 240)
	shape(c, 0.56, 0.5, 0.5, 0.12, col, 0, 0.5, z)
	shape(c, 0.34, 0.37, 0.32, 0.12, col, -42, 0.5, z)
	shape(c, 0.34, 0.63, 0.32, 0.12, col, 42, 0.5, z)
end

-- тыква: дольки, хвостик, вырезанное лицо
function ICONS.Pumpkin(c, z)
	for i, x in ipairs({ 0.3, 0.7, 0.5 }) do
		local o = shape(c, x, 0.58, i == 3 and 0.42 or 0.38, 0.6, Color3.new(1, 1, 1), 0, 0.45, z + (i == 3 and 1 or 0))
		shade(o, Color3.fromRGB(255, 165, 60), Color3.fromRGB(190, 80, 20))
		new("UIStroke", { Parent = o, Color = Color3.fromRGB(70, 25, 5), Thickness = 1.5 })
	end
	shape(c, 0.52, 0.22, 0.1, 0.18, Color3.fromRGB(80, 110, 40), 14, 0.3, z + 2)
	for _, x in ipairs({ 0.38, 0.62 }) do
		shape(c, x, 0.52, 0.12, 0.12, Color3.fromRGB(255, 230, 120), 45, 0.1, z + 3)
	end
	shape(c, 0.5, 0.7, 0.34, 0.08, Color3.fromRGB(255, 230, 120), 0, 0.4, z + 3)
end

-- руна: камень-ромб с символом
function ICONS.Rune(c, z)
	local o = shape(c, 0.5, 0.5, 0.62, 0.62, Color3.new(1, 1, 1), 45, 0.15, z)
	shade(o, Color3.fromRGB(255, 160, 60), Color3.fromRGB(120, 30, 40), 45)
	new("UIStroke", { Parent = o, Color = Color3.fromRGB(40, 10, 10), Thickness = 2 })
	shape(c, 0.5, 0.5, 0.08, 0.42, Color3.fromRGB(255, 240, 200), 0, 0.5, z + 1)
	shape(c, 0.5, 0.4, 0.3, 0.07, Color3.fromRGB(255, 240, 200), 30, 0.5, z + 1)
	shape(c, 0.5, 0.6, 0.3, 0.07, Color3.fromRGB(255, 240, 200), -30, 0.5, z + 1)
end

-- контейнер с иконкой (квадратный)
local function icon(kind, parent, props)
	local c = new("Frame", { Parent = parent, Name = "Icon" .. kind, BackgroundTransparency = 1, Size = props.Size, Position = props.Position or UDim2.new(), AnchorPoint = props.AnchorPoint or Vector2.new(), ZIndex = props.ZIndex or 1 })
	new("UIAspectRatioConstraint", { Parent = c })
	ICONS[kind](c, (props.ZIndex or 1) + 1)
	return c
end
UI.Icon = icon

-- Квадратная кнопка-иконка с подписью (панель справа)
local function iconButton(parent, order, kind, caption, top, bottom, edge, onClick, size)
	size = size or 76
	local b = new("TextButton", {
		Parent = parent,
		Name = kind .. "Button",
		LayoutOrder = order,
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
	})
	corner(16).Parent = b
	stroke(edge, 2).Parent = b
	new("UIGradient", { Parent = b, Rotation = 90, Color = ColorSequence.new(top, bottom) })
	-- мягкий блик сверху
	local shine = new("Frame", { Parent = b, BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.9, BorderSizePixel = 0, Position = UDim2.fromOffset(4, 4), Size = UDim2.new(1, -8, 0.4, 0) })
	corner(12).Parent = shine
	icon(kind, b, { Size = UDim2.fromScale(0.72, 0.72), Position = UDim2.fromScale(0.5, 0.48), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 2 })
	local cap = label({ Parent = b, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, 3), Size = UDim2.new(1, 16, 0, math.max(14, size * 0.2)), Text = caption, Font = Enum.Font.GothamBold })
	local scale = new("UIScale", { Parent = b })
	b.MouseEnter:Connect(function()
		tween(scale, 0.12, { Scale = 1.08 })
	end)
	b.MouseLeave:Connect(function()
		tween(scale, 0.12, { Scale = 1 })
	end)
	b.MouseButton1Down:Connect(function()
		tween(scale, 0.06, { Scale = 0.93 })
	end)
	b.MouseButton1Up:Connect(function()
		tween(scale, 0.1, { Scale = 1.04 })
	end)
	if onClick then
		b.Activated:Connect(onClick)
	end
	return b, cap
end

local function rarityColor(id)
	return Config.Rarities[Config.Units[id].Rarity].Color
end

-- лёгкие оранжевые искры на карточках хэллоуинских юнитов (двигаются в UI.Update)
local sparks = {}
local function eventSparks(parent, z, n)
	for i = 1, n or 4 do
		local f = new("Frame", { Parent = parent, BackgroundColor3 = Color3.fromRGB(255, 160, 60), BorderSizePixel = 0, Size = UDim2.fromOffset(3, 3), Rotation = 45, ZIndex = z, BackgroundTransparency = 0.2 })
		sparks[#sparks + 1] = { F = f, X = math.random(), P = math.random() * 3, S = 0.25 + math.random() * 0.25 }
	end
end

-- Тег события: значок-тыква в углу, «🎃 HALLOWEEN» и искры. Рамка остаётся цветом редкости.
local function eventTag(parent, unitId, z, textPos, textSize)
	local def = Config.Units[unitId]
	local ev = def and def.Event and Config.Events[def.Event]
	if not ev then
		return
	end
	icon("Pumpkin", parent, { Size = UDim2.fromOffset(22, 22), Position = UDim2.fromOffset(4, 4), ZIndex = z + 2 })
	if textPos then
		label({ Parent = parent, Size = textSize or UDim2.new(1, -8, 0, 13), Position = textPos, Text = ev.Tag, TextColor3 = ev.Color, Font = Enum.Font.GothamBold, ZIndex = z + 1 })
	end
	eventSparks(parent, z + 1, 4)
end
UI.EventTag = eventTag

-- 3D превью юнита
local function viewport(parent, unitId, level, props)
	props = props or {}
	local vf = new("ViewportFrame", {
		Parent = parent,
		BackgroundTransparency = 1,
		Size = props.Size or UDim2.fromScale(1, 1),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.new(),
		Ambient = Color3.fromRGB(150, 130, 185),
		LightColor = Color3.fromRGB(255, 245, 255),
		LightDirection = Vector3.new(-0.6, -1, -0.8),
		ZIndex = props.ZIndex or 1,
	})
	local ok, rig = pcall(UnitModels.Build, unitId, level or 1)
	if not ok then
		return vf
	end
	for _, d in ipairs(rig.Model:GetDescendants()) do
		if d:IsA("ParticleEmitter") or d:IsA("PointLight") or d:IsA("Trail") then
			d:Destroy()
		end
	end
	rig.Model.Parent = vf
	local cam = Instance.new("Camera")
	cam.FieldOfView = 34
	local s = rig.Scale
	local center = Vector3.new(0, -0.1 * s, 0)
	-- камера дальше, чтобы юнит с оружием целиком помещался в превью
	cam.CFrame = CFrame.lookAt(center + Vector3.new(5.6, 2.6, -14.5) * s, center)
	cam.Parent = vf
	vf.CurrentCamera = cam
	if props.Silhouette then
		vf.ImageColor3 = Color3.fromRGB(0, 0, 0)
		vf.ImageTransparency = 0.2
	end
	return vf
end
UI.Viewport = viewport

------------------------------------------------------------------------
-- УВЕДОМЛЕНИЯ
------------------------------------------------------------------------
function UI.Toast(text, kind)
	local color = THEME.Accent
	if kind == "error" then
		color = THEME.Bad
	elseif kind == "good" then
		color = THEME.Good
	elseif kind == "boss" then
		color = THEME.Pink
	elseif kind == "gold" then
		color = THEME.Gold
	end
	local t = panel({ Parent = refs.Toasts, Size = UDim2.fromOffset(380, 38), StrokeColor = color, BackgroundTransparency = 0.05 })
	local l = label({ Parent = t, Size = UDim2.new(1, -16, 1, -10), Position = UDim2.fromOffset(8, 5), Text = text, TextColor3 = color })
	local sc = new("UIScale", { Parent = t, Scale = 0.6 })
	tween(sc, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
	task.delay(2.6, function()
		tween(t, 0.3, { BackgroundTransparency = 1 })
		tween(l, 0.3, { TextTransparency = 1 })
		task.wait(0.32)
		t:Destroy()
	end)
end

function UI.Announce(title, subtitle, color)
	local holder = refs.Announce
	holder:ClearAllChildren()
	local sc = new("UIScale", { Parent = holder, Scale = 0.3 })
	local t = label({ Parent = holder, Size = UDim2.new(1, 0, 0.62, 0), Text = title, TextColor3 = color or THEME.Text, StrokeThickness = 3 })
	local s
	if subtitle then
		s = label({ Parent = holder, Size = UDim2.new(1, 0, 0.32, 0), Position = UDim2.fromScale(0, 0.66), Text = subtitle, TextColor3 = THEME.Dim })
	end
	holder.Visible = true
	tween(sc, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	task.delay(2.2, function()
		if t.Parent then
			tween(t, 0.4, { TextTransparency = 1 })
			if s then
				tween(s, 0.4, { TextTransparency = 1 })
			end
		end
	end)
end

------------------------------------------------------------------------
-- HUD
------------------------------------------------------------------------
local function buildHUD()
	-- деньги и гемы
	local cur = panel({ Parent = gui, Size = UDim2.fromOffset(230, 92), Position = UDim2.fromOffset(16, 16) })
	refs.Currency = cur
	refs.Money = label({ Parent = cur, Size = UDim2.new(1, -60, 0, 36), Position = UDim2.fromOffset(52, 6), Text = "0", TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(255, 220, 120) })
	refs.MoneyIcon = icon("Coin", cur, { Size = UDim2.fromOffset(34, 34), Position = UDim2.fromOffset(10, 7) })
	refs.Gems = label({ Parent = cur, Size = UDim2.new(1, -60, 0, 32), Position = UDim2.fromOffset(52, 50), Text = "0", TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(150, 200, 255) })
	refs.GemsIcon = icon("Gem", cur, { Size = UDim2.fromOffset(34, 34), Position = UDim2.fromOffset(10, 49) })
	refs.Coins = label({ Parent = cur, Size = UDim2.new(1, -60, 0, 30), Position = UDim2.fromOffset(52, 92), Text = "0", TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(255, 160, 60) })
	refs.CoinsIcon = icon("Pumpkin", cur, { Size = UDim2.fromOffset(32, 32), Position = UDim2.fromOffset(11, 91) })

	-- волна и ядро
	local top = panel({ Parent = gui, AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.fromOffset(420, 104), Position = UDim2.new(0.5, 0, 0, 12) })
	refs.Top = top
	refs.Wave = label({ Parent = top, Size = UDim2.new(1, -20, 0, 40), Position = UDim2.fromOffset(10, 4), Text = "WAVE 0 / 30" })
	refs.Status = label({ Parent = top, Size = UDim2.new(1, -20, 0, 22), Position = UDim2.fromOffset(10, 44), Text = "", TextColor3 = THEME.Dim, Font = Enum.Font.GothamBold })
	local coreBg = new("Frame", { Parent = top, Size = UDim2.new(1, -24, 0, 24), Position = UDim2.fromOffset(12, 72), BackgroundColor3 = Color3.fromRGB(25, 12, 32), BorderSizePixel = 0 }, { corner(6) })
	refs.CoreFill = new("Frame", { Parent = coreBg, Size = UDim2.fromScale(1, 1), BackgroundColor3 = THEME.Accent, BorderSizePixel = 0 }, { corner(6) })
	new("UIGradient", { Parent = refs.CoreFill, Color = ColorSequence.new(Color3.fromRGB(120, 50, 220), Color3.fromRGB(230, 120, 255)) })
	refs.CoreText = label({ Parent = coreBg, Size = UDim2.new(1, 0, 1, -4), Position = UDim2.fromOffset(0, 2), Text = "VOID CORE 100 / 100", ZIndex = 2 })

	-- босс
	local boss = panel({ Parent = gui, AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.fromOffset(560, 46), Position = UDim2.new(0.5, 0, 0, 124), StrokeColor = THEME.Pink, Visible = false })
	refs.Boss = boss
	local bossBg = new("Frame", { Parent = boss, Size = UDim2.new(1, -16, 0, 20), Position = UDim2.fromOffset(8, 20), BackgroundColor3 = Color3.fromRGB(30, 8, 20), BorderSizePixel = 0 }, { corner(5) })
	refs.BossFill = new("Frame", { Parent = bossBg, Size = UDim2.fromScale(1, 1), BackgroundColor3 = THEME.Pink, BorderSizePixel = 0 }, { corner(5) })
	refs.BossName = label({ Parent = boss, Size = UDim2.new(1, -16, 0, 18), Position = UDim2.fromOffset(8, 2), Text = "BOSS", TextColor3 = THEME.Pink })
	refs.BossHP = label({ Parent = bossBg, Size = UDim2.new(1, 0, 1, -4), Position = UDim2.fromOffset(0, 2), Text = "", ZIndex = 2 })

	-- уведомления и анонсы
	refs.Toasts = new("Frame", { Parent = gui, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.fromOffset(400, 300), Position = UDim2.new(0.5, 0, 0, 180) }, {
		new("UIListLayout", { Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	refs.Announce = new("Frame", { Parent = gui, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(700, 130), Position = UDim2.fromScale(0.5, 0.36), Visible = false })

	-- кнопка старта волны
	refs.Start = button({
		Parent = gui,
		AnchorPoint = Vector2.new(1, 1),
		Size = UDim2.fromOffset(220, 60),
		Position = UDim2.new(1, -18, 1, -150),
		Text = "▶ START WAVE",
		BackgroundColor3 = Color3.fromRGB(70, 150, 90),
		StrokeColor = THEME.Good,
	}, function()
		ctx.Request("StartWave")
	end)

	-- панель иконок справа: магазин, юниты, графика
	local dock = new("Frame", { Parent = gui, Name = "IconDock", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, -40), Size = UDim2.fromOffset(84, 290), BackgroundTransparency = 1 })
	new("UIListLayout", { Parent = dock, Padding = UDim.new(0, 12), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder })
	refs.ShopButton = iconButton(dock, 1, "Gem", "МАГАЗИН", Color3.fromRGB(44, 52, 92), Color3.fromRGB(18, 18, 36), Color3.fromRGB(110, 150, 230), function()
		UI.Toggle("Shop")
		FX.Sound("Click", 1, 1)
	end)
	refs.InvButton = iconButton(dock, 2, "Helmet", "ЮНИТЫ", Color3.fromRGB(66, 44, 100), Color3.fromRGB(22, 14, 36), Color3.fromRGB(150, 110, 210), function()
		UI.Toggle("Inventory")
	end)
	refs.LiteButton, refs.LiteCaption = iconButton(dock, 3, "Gear", "ГРАФИКА", Color3.fromRGB(56, 54, 72), Color3.fromRGB(22, 20, 30), Color3.fromRGB(120, 116, 140), function()
		ctx.SetLite(not ctx.Lite, true)
	end, 62)

	-- выход из матча в лобби
	refs.Leave = button({ Parent = gui, Name = "LeaveButton", Size = UDim2.fromOffset(150, 44), Position = UDim2.fromOffset(16, 118), Text = "    В ЛОББИ", BackgroundColor3 = Color3.fromRGB(80, 30, 46), StrokeColor = Color3.fromRGB(170, 70, 90) }, function()
		ctx.Placement.Stop()
		UI.CloseUnit()
		task.spawn(UI.FadeTransition, "ВОЗВРАЩЕНИЕ В ЛОББИ", function()
			return ctx.Request("LeaveMatch")
		end)
	end)
	icon("Back", refs.Leave, { Size = UDim2.fromOffset(26, 26), Position = UDim2.fromOffset(12, 9), ZIndex = 2 })

	-- подсказка размещения
	refs.PlaceHint = panel({ Parent = gui, AnchorPoint = Vector2.new(0.5, 1), Size = UDim2.fromOffset(520, 34), Position = UDim2.new(0.5, 0, 1, -150), Visible = false })
	label({ Parent = refs.PlaceHint, Size = UDim2.new(1, -16, 1, -8), Position = UDim2.fromOffset(8, 4), Font = Enum.Font.GothamBold, Text = "ЛКМ — поставить  •  R — повернуть  •  Q / ПКМ — отмена  •  Shift — несколько" })

	-- тач-кнопки размещения
	refs.TouchBar = new("Frame", { Parent = gui, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 1), Size = UDim2.fromOffset(380, 56), Position = UDim2.new(0.5, 0, 1, -190), Visible = false }, {
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10), HorizontalAlignment = Enum.HorizontalAlignment.Center }),
	})
	button({ Parent = refs.TouchBar, Size = UDim2.fromOffset(115, 52), Text = "PLACE", BackgroundColor3 = Color3.fromRGB(60, 140, 80) }, function()
		ctx.Placement.Confirm()
	end)
	button({ Parent = refs.TouchBar, Size = UDim2.fromOffset(115, 52), Text = "ROTATE" }, function()
		ctx.Placement.Rotate()
	end)
	button({ Parent = refs.TouchBar, Size = UDim2.fromOffset(115, 52), Text = "CANCEL", BackgroundColor3 = Color3.fromRGB(140, 40, 60) }, function()
		ctx.Placement.Stop()
	end)
end

function UI.ShowPlacementHint(on, touch)
	refs.PlaceHint.Visible = on and not touch
	refs.TouchBar.Visible = on and touch
end

------------------------------------------------------------------------
-- ХОТБАР
------------------------------------------------------------------------
local slotRefs = {}

local function buildHotbar()
	local bar = new("Frame", { Parent = gui, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 1), Size = UDim2.fromOffset(6 * 104, 128), Position = UDim2.new(0.5, 0, 1, -12) }, {
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), HorizontalAlignment = Enum.HorizontalAlignment.Center }),
	})
	refs.Hotbar = bar
	for i = 1, Config.Settings.EquipSlots do
		local slot = button({ Parent = bar, Size = UDim2.fromOffset(96, 124), Text = "", BackgroundColor3 = THEME.BG2, LayoutOrder = i }, function()
			local id = UI.EquippedAt(i)
			if id then
				ctx.Placement.Start(id)
			else
				UI.Toast("Пустой слот: экипируй юнитов в круге ЮНИТЫ в лобби", "error")
			end
		end)
		slotRefs[i] = { Button = slot }
	end
end

function UI.EquippedAt(i)
	local prof = ctx.Profile
	return prof and prof.Equipped and prof.Equipped[tostring(i)]
end

local function refreshHotbar()
	for i, s in ipairs(slotRefs) do
		local b = s.Button
		for _, c in ipairs(b:GetChildren()) do
			if c:IsA("ViewportFrame") or c:IsA("TextLabel") or c:IsA("Frame") then
				c:Destroy()
			end
		end
		local id = UI.EquippedAt(i)
		local st = b:FindFirstChild("Border")
		label({ Parent = b, Size = UDim2.fromOffset(20, 20), Position = UDim2.fromOffset(5, 3), Text = tostring(i), TextColor3 = THEME.Dim, ZIndex = 3 })
		if id then
			local def = Config.Units[id]
			local rc = rarityColor(id)
			st.Color = rc
			new("Frame", { Parent = b, Size = UDim2.new(1, -8, 0, 4), Position = UDim2.fromOffset(4, 4), BackgroundColor3 = rc, BorderSizePixel = 0, ZIndex = 2 }, { corner(2) })
			viewport(b, id, 1, { Size = UDim2.new(1, 0, 0, 82), Position = UDim2.fromOffset(0, 6) })
			label({ Parent = b, Size = UDim2.new(1, -6, 0, 16), Position = UDim2.fromOffset(3, 86), Text = def.Name, Font = Enum.Font.GothamBold, ZIndex = 2 })
			s.Cost = label({ Parent = b, Size = UDim2.new(1, -6, 0, 18), Position = UDim2.fromOffset(3, 102), Text = "$" .. Config.FormatNumber(def.Levels[1].Cost), TextColor3 = THEME.Good, ZIndex = 2 })
			s.Id = id
		else
			st.Color = THEME.AccentDark
			label({ Parent = b, Size = UDim2.new(1, -10, 0, 40), Position = UDim2.fromOffset(5, 40), Text = "+", TextColor3 = THEME.Dim })
			s.Id = nil
			s.Cost = nil
		end
	end
end

------------------------------------------------------------------------
-- ПАНЕЛЬ ЮНИТА
------------------------------------------------------------------------
local rangePart

local function showRange(pos, range)
	if not rangePart then
		rangePart = FX.Part({
			Shape = Enum.PartType.Cylinder,
			Color = THEME.Accent,
			Transparency = 0.75,
			Parent = workspace,
		})
		rangePart.Name = "VoidTD_Range"
	end
	rangePart.Size = Vector3.new(0.2, range * 2, range * 2)
	rangePart.CFrame = CFrame.new(pos + Vector3.new(0, 0.25, 0)) * CFrame.Angles(0, 0, math.rad(90))
	rangePart.Parent = workspace
end

local function hideRange()
	if rangePart then
		rangePart.Parent = nil
	end
end

local function statLine(parent, order, name)
	local row = new("Frame", { Parent = parent, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 24), LayoutOrder = order })
	label({ Parent = row, Size = UDim2.new(0.45, 0, 1, 0), Text = name, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = THEME.Dim, Font = Enum.Font.GothamBold })
	return label({ Parent = row, Size = UDim2.new(0.55, 0, 1, 0), Position = UDim2.fromScale(0.45, 0), Text = "", TextXAlignment = Enum.TextXAlignment.Right, Font = Enum.Font.GothamBold })
end

local function buildUnitPanel()
	local p = panel({ Parent = gui, AnchorPoint = Vector2.new(1, 0.5), Size = UDim2.fromOffset(310, 470), Position = UDim2.new(1, -112, 0.45, 0), Visible = false })
	refs.UnitPanel = p
	refs.UPName = label({ Parent = p, Size = UDim2.new(1, -60, 0, 32), Position = UDim2.fromOffset(12, 10), Text = "Unit", TextXAlignment = Enum.TextXAlignment.Left })
	button({ Parent = p, Size = UDim2.fromOffset(32, 32), Position = UDim2.new(1, -42, 0, 10), Text = "✕", BackgroundColor3 = Color3.fromRGB(120, 30, 50) }, function()
		UI.CloseUnit()
	end)
	refs.UPRarity = label({ Parent = p, Size = UDim2.new(1, -24, 0, 20), Position = UDim2.fromOffset(12, 42), Text = "", TextXAlignment = Enum.TextXAlignment.Left })
	refs.UPStars = label({ Parent = p, Size = UDim2.new(1, -24, 0, 24), Position = UDim2.fromOffset(12, 62), Text = "", TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = THEME.Gold })
	refs.UPView = new("Frame", { Parent = p, BackgroundColor3 = THEME.BG2, BackgroundTransparency = 0.3, Size = UDim2.new(1, -24, 0, 110), Position = UDim2.fromOffset(12, 90) }, { corner(8) })
	local stats = new("Frame", { Parent = p, BackgroundTransparency = 1, Size = UDim2.new(1, -24, 0, 160), Position = UDim2.fromOffset(12, 206) }, {
		new("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	refs.UPDamage = statLine(stats, 1, "Урон")
	refs.UPRange = statLine(stats, 2, "Дальность")
	refs.UPCooldown = statLine(stats, 3, "Перезарядка")
	refs.UPSpecial = statLine(stats, 4, "Особое")
	refs.UPDealt = statLine(stats, 5, "Нанесено")
	refs.UPOwner = statLine(stats, 6, "Владелец")
	local function cycleTarget()
		local uid = UI.SelectedUid
		local v = uid and Renderer.UnitViews[uid]
		if not v then
			return
		end
		local cur = v.Folder:GetAttribute("TargetMode") or "First"
		local idx = table.find(Config.TargetModes, cur) or 1
		local nextMode = Config.TargetModes[idx % #Config.TargetModes + 1]
		ctx.Request("SetTarget", { Uid = uid, Mode = nextMode })
	end
	UI.CycleTargetFn = cycleTarget
	refs.UPTarget = button({ Parent = p, Size = UDim2.new(1, -24, 0, 36), Position = UDim2.fromOffset(12, 362), Text = "TARGET: First", BackgroundColor3 = THEME.BG3 }, cycleTarget)
	refs.UPUpgrade = button({ Parent = p, Size = UDim2.new(0.6, -16, 0, 50), Position = UDim2.fromOffset(12, 406), Text = "UPGRADE", BackgroundColor3 = Color3.fromRGB(60, 130, 80), StrokeColor = THEME.Good }, function()
		UI.UpgradeSelected()
	end)
	refs.UPSell = button({ Parent = p, Size = UDim2.new(0.4, -12, 0, 50), Position = UDim2.new(0.6, 4, 0, 406), Text = "SELL", BackgroundColor3 = Color3.fromRGB(130, 40, 60), StrokeColor = THEME.Bad }, function()
		UI.SellSelected()
	end)
end

local function specialText(def, st)
	if st.BlackHole then
		return string.format("Black Hole r%d, %d/тик", st.BlackHole.Radius, st.BlackHole.TickDamage)
	elseif st.AOERadius then
		return string.format("AOE радиус %.1f", st.AOERadius)
	elseif st.Hits and st.Hits > 1 then
		local s = "x" .. st.Hits .. " удара"
		if st.CritChance then
			s = s .. string.format(", крит %d%%", st.CritChance * 100)
		end
		return s
	elseif st.CritChance then
		return string.format("Крит %d%% x%.1f", st.CritChance * 100, st.CritMult or 2)
	end
	return def.AttackType
end

function UI.RefreshUnitPanel()
	local uid = UI.SelectedUid
	local v = uid and Renderer.UnitViews[uid]
	if not v then
		UI.CloseUnit()
		return
	end
	local def = Config.Units[v.UnitId]
	local lv = v.Folder:GetAttribute("Level") or 1
	local st = def.Levels[lv]
	local nx = def.Levels[lv + 1]
	local rc = rarityColor(v.UnitId)
	refs.UPName.Text = def.Name
	refs.UPRarity.Text = def.Rarity:upper() .. (def.Ability and ("  •  " .. def.Ability) or "")
	refs.UPRarity.TextColor3 = rc
	refs.UPStars.Text = "Lv " .. lv .. "  " .. string.rep("★", lv) .. string.rep("☆", 5 - lv)
	refs.UnitPanel.Border.Color = rc
	local function arrow(a, b, fmt)
		fmt = fmt or "%s"
		if b and b ~= a then
			return string.format(fmt, a) .. "  →  " .. string.format(fmt, b)
		end
		return string.format(fmt, a)
	end
	refs.UPDamage.Text = arrow(Config.FormatNumber(st.Damage), nx and Config.FormatNumber(nx.Damage))
	refs.UPRange.Text = arrow(st.Range, nx and nx.Range)
	refs.UPCooldown.Text = arrow(st.Cooldown, nx and nx.Cooldown, "%.2fs")
	refs.UPSpecial.Text = specialText(def, st)
	refs.UPDealt.Text = Config.FormatNumber(v.Folder:GetAttribute("Damage") or 0)
	refs.UPOwner.Text = v.Folder:GetAttribute("OwnerName") or "?"
	refs.UPTarget.Text = "🎯 TARGET: " .. (v.Folder:GetAttribute("TargetMode") or "First")
	local mine = v.Folder:GetAttribute("OwnerId") == player.UserId
	refs.UPUpgrade.Visible = mine
	refs.UPSell.Visible = mine
	refs.UPTarget.Visible = mine
	if nx then
		refs.UPUpgrade.Text = "UPGRADE $" .. Config.FormatNumber(nx.Cost)
		local afford = (player:GetAttribute("Money") or 0) >= nx.Cost
		refs.UPUpgrade.BackgroundColor3 = afford and Color3.fromRGB(60, 130, 80) or Color3.fromRGB(60, 60, 70)
	else
		refs.UPUpgrade.Text = "MAX LEVEL"
		refs.UPUpgrade.BackgroundColor3 = Color3.fromRGB(120, 90, 30)
	end
	local spent = v.Folder:GetAttribute("Spent") or 0
	refs.UPSell.Text = "SELL $" .. Config.FormatNumber(math.floor(spent * Config.Settings.SellRefund))
	if refs.UPViewLevel ~= lv or refs.UPViewUid ~= uid then
		refs.UPViewLevel, refs.UPViewUid = lv, uid
		refs.UPView:ClearAllChildren()
		corner(8).Parent = refs.UPView
		viewport(refs.UPView, v.UnitId, lv)
	end
	showRange(v.Pos, st.Range)
end

function UI.OpenUnit(uid)
	UI.SelectedUid = uid
	refs.UnitPanel.Visible = true
	refs.UPViewUid = nil
	UI.RefreshUnitPanel()
end

function UI.CloseUnit()
	UI.SelectedUid = nil
	if refs.UnitPanel then
		refs.UnitPanel.Visible = false
	end
	hideRange()
end

function UI.UpgradeSelected()
	if UI.SelectedUid then
		local ok, res = ctx.Request("Upgrade", { Uid = UI.SelectedUid })
		if ok then
			UI.Toast("Улучшено до уровня " .. tostring(res) .. "!", "good")
		end
	end
end

function UI.SellSelected()
	if UI.SelectedUid then
		local ok, res = ctx.Request("Sell", { Uid = UI.SelectedUid })
		if ok then
			UI.Toast("Продано за $" .. Config.FormatNumber(res), "gold")
			FX.Sound("Sell", 1, 1)
			UI.CloseUnit()
		end
	end
end

function UI.CycleTarget()
	if UI.SelectedUid and refs.UPTarget.Visible then
		UI.CycleTargetFn()
	end
end

------------------------------------------------------------------------
-- МОДАЛЬНЫЕ ОКНА
------------------------------------------------------------------------
local modals = {}

function UI.Toggle(name)
	for n, m in pairs(modals) do
		if n == name then
			m.Visible = not m.Visible
			if m.Visible then
				local sc = m:FindFirstChildOfClass("UIScale")
				sc.Scale = 0.85
				tween(sc, 0.2, { Scale = 1 }, Enum.EasingStyle.Back)
				if name == "Inventory" then
					UI.RefreshInventory()
				elseif name == "Mode" then
					UI.RefreshMode()
				elseif name == "Bestiary" then
					HalloweenUI.FillBestiary()
				end
			end
		else
			m.Visible = false
		end
	end
end

function UI.Show(name, on)
	local m = modals[name]
	if not m then
		return
	end
	if on and not m.Visible then
		UI.Toggle(name)
	elseif not on then
		m.Visible = false
	end
end

local function modal(name, title, size, iconKind)
	local m = panel({ Parent = gui, AnchorPoint = Vector2.new(0.5, 0.5), Size = size, Position = UDim2.fromScale(0.5, 0.5), Visible = false, BackgroundTransparency = 0.04, ZIndex = 5 })
	new("UIScale", { Parent = m })
	local x = 18
	if iconKind then
		icon(iconKind, m, { Size = UDim2.fromOffset(38, 38), Position = UDim2.fromOffset(16, 13), ZIndex = 6 })
		x = 62
	end
	label({ Parent = m, Size = UDim2.new(1, -80 - x, 0, 44), Position = UDim2.fromOffset(x, 10), Text = title, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = THEME.Accent })
	button({ Parent = m, Size = UDim2.fromOffset(40, 40), Position = UDim2.new(1, -52, 0, 12), Text = "✕", BackgroundColor3 = Color3.fromRGB(120, 30, 50) }, function()
		m.Visible = false
	end)
	modals[name] = m
	return m
end

------------------------------------------------------------------------
-- ПЕРЕХОД: чёрный экран
------------------------------------------------------------------------
local fading = false

-- Затемнение -> действие (fn) -> плавное появление. fn может вернуть результат.
function UI.FadeTransition(text, fn)
	if fading then
		return fn and fn() or nil
	end
	fading = true
	local black = new("Frame", { Parent = UI.Gui, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, ZIndex = 200 })
	local t = new("TextLabel", { Parent = black, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(700, 60), Font = Enum.Font.FredokaOne, TextScaled = true, Text = text or "", TextColor3 = THEME.Accent, TextTransparency = 1, ZIndex = 201 })
	tween(black, 0.35, { BackgroundTransparency = 0 })
	tween(t, 0.35, { TextTransparency = 0 })
	FX.Sound("Portal", 0.8, 1)
	task.wait(0.4)
	local a, b
	if fn then
		a, b = fn()
	end
	task.wait(0.45)
	tween(black, 0.55, { BackgroundTransparency = 1 })
	tween(t, 0.4, { TextTransparency = 1 })
	task.delay(0.6, function()
		black:Destroy()
		fading = false
	end)
	return a, b
end

------------------------------------------------------------------------
-- КЕЙСЫ: витрина, шансы, анимации открытия
------------------------------------------------------------------------
local CaseModels
local selectedCase = "VoidCase"
local caseViews = {}

-- 3D-кейс во ViewportFrame
local function caseViewport(parent, caseId, props)
	props = props or {}
	local vf = new("ViewportFrame", {
		Parent = parent,
		BackgroundTransparency = 1,
		Size = props.Size or UDim2.fromScale(1, 1),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.new(),
		Ambient = Color3.fromRGB(160, 140, 190),
		LightColor = Color3.fromRGB(255, 245, 255),
		LightDirection = Vector3.new(-0.5, -1, -0.7),
		ZIndex = props.ZIndex or 1,
	})
	local r = CaseModels.Build(caseId)
	r.Model.Parent = vf
	local cam = Instance.new("Camera")
	cam.FieldOfView = 40
	cam.CFrame = CFrame.lookAt(Vector3.new(0, 4.5, -13), Vector3.new(0, 2.6, 0))
	cam.Parent = vf
	vf.CurrentCamera = cam
	r.Viewport = vf
	return r
end

local function rateText(case)
	local lines = {}
	if case.Rewards then
		-- полный список наград с шансами (юниты и руны)
		for _, r in ipairs(case.Rewards) do
			local name, color
			if r.Rune then
				local rd = Config.Runes[r.Rune]
				name, color = "Руна «" .. rd.Name .. "»", Config.RuneRarity.Color
			else
				local def = Config.Units[r.Unit]
				name, color = def.Name .. " (" .. def.Rarity .. ")", Config.Rarities[def.Rarity].Color
			end
			lines[#lines + 1] = string.format('<font color="#%s">%s</font>  %s%%', color:ToHex(), name, tostring(r.Rate))
		end
		return table.concat(lines, "\n")
	end
	for _, rarity in ipairs(Config.RarityOrder) do
		local rate = case.Rates[rarity]
		if rate and rate > 0 then
			lines[#lines + 1] = string.format('<font color="#%s">%s</font>  %s%%', Config.Rarities[rarity].Color:ToHex(), rarity:upper(), tostring(rate))
		end
	end
	return table.concat(lines, "\n")
end

function UI.SelectCase(caseId)
	if not Config.Cases[caseId] then
		return
	end
	selectedCase = caseId
	local case = Config.Cases[caseId]
	refs.CaseName.Text = case.Name
	refs.CaseName.TextColor3 = case.Color
	refs.CaseDesc.Text = case.Description
	refs.CaseRates.Text = rateText(case)
	refs.CaseRates.TextSize = case.Rewards and 13 or 18
	local cur = case.Currency == "HalloweenCoins" and "🎃" or "💎"
	refs.CaseBuy1.Text = (case.Single and "ОТКРЫТЬ  " or "x1  ") .. cur .. case.Cost1
	refs.CaseBuy10.Visible = not case.Single and case.Cost10 ~= nil
	refs.CaseBuy10.Text = "x10  " .. cur .. tostring(case.Cost10 or "")
	refs.CaseBig:ClearAllChildren()
	caseViews.Big = caseViewport(refs.CaseBig, caseId)
	for id, b in pairs(refs.CaseTabs) do
		b.Border.Color = id == caseId and Config.Cases[id].Color or THEME.AccentDark
	end
	for _, c in ipairs(refs.CaseUnits:GetChildren()) do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	for i, id in ipairs(case.Units) do
		local def = Config.Units[id]
		local rc = rarityColor(id)
		local cell = panel({ Parent = refs.CaseUnits, Size = UDim2.fromOffset(100, 108), BackgroundColor3 = THEME.BG2, StrokeColor = rc, LayoutOrder = Config.Rarities[def.Rarity].Order * 100 + i, ZIndex = 7 })
		viewport(cell, id, 1, { Size = UDim2.new(1, 0, 0, 74), ZIndex = 8 })
		label({ Parent = cell, Size = UDim2.new(1, -6, 0, 16), Position = UDim2.fromOffset(3, 74), Text = def.Name, Font = Enum.Font.GothamBold, ZIndex = 8 })
		label({ Parent = cell, Size = UDim2.new(1, -6, 0, 14), Position = UDim2.fromOffset(3, 90), Text = def.Rarity, TextColor3 = rc, ZIndex = 8 })
		eventTag(cell, id, 8)
	end
	-- руны в кейсе
	for i, r in ipairs(case.Rewards or {}) do
		if r.Rune then
			local rd = Config.Runes[r.Rune]
			local cell = panel({ Parent = refs.CaseUnits, Size = UDim2.fromOffset(100, 108), BackgroundColor3 = THEME.BG2, StrokeColor = Config.RuneRarity.Color, LayoutOrder = 1000 + i, ZIndex = 7 })
			HalloweenUI.RuneViewport(cell, r.Rune, { Size = UDim2.new(1, 0, 0, 74), ZIndex = 8 })
			label({ Parent = cell, Size = UDim2.new(1, -6, 0, 16), Position = UDim2.fromOffset(3, 74), Text = rd.Name, Font = Enum.Font.GothamBold, ZIndex = 8 })
			label({ Parent = cell, Size = UDim2.new(1, -6, 0, 14), Position = UDim2.fromOffset(3, 90), Text = "РУНА • HALLOWEEN", TextColor3 = Config.RuneRarity.Color, ZIndex = 8 })
		end
	end
end

local function showCards(overlay, results)
	local grid = new("Frame", { Parent = overlay, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(5 * 150, (#results > 5 and 2 or 1) * 200), Position = UDim2.fromScale(0.5, 0.55), ZIndex = 22 }, {
		new("UIGridLayout", { CellSize = UDim2.fromOffset(140, 190), CellPadding = UDim2.fromOffset(10, 10), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	for i, r in ipairs(results) do
		task.delay(0.15 * i, function()
			if r.Rune then
				HalloweenUI.RuneCard(grid, r, i)
				return
			end
			local def = Config.Units[r.Id]
			local rc = rarityColor(r.Id)
			local card = panel({ Parent = grid, BackgroundColor3 = THEME.BG2, StrokeColor = rc, LayoutOrder = i, ZIndex = 23 })
			new("UIGradient", { Parent = card, Rotation = 90, Color = ColorSequence.new(rc:Lerp(THEME.BG, 0.55), THEME.BG) })
			local sc = new("UIScale", { Parent = card, Scale = 0 })
			viewport(card, r.Id, 1, { Size = UDim2.new(1, 0, 0, 120), Position = UDim2.fromOffset(0, 8), ZIndex = 24 })
			label({ Parent = card, Size = UDim2.new(1, -8, 0, 22), Position = UDim2.fromOffset(4, 130), Text = def.Name, ZIndex = 24 })
			label({ Parent = card, Size = UDim2.new(1, -8, 0, 18), Position = UDim2.fromOffset(4, 154), Text = def.Rarity:upper(), TextColor3 = rc, ZIndex = 24 })
			eventTag(card, r.Id, 24, UDim2.fromOffset(4, 172), UDim2.new(1, -8, 0, 14))
			if r.New then
				local tag = label({ Parent = card, Size = UDim2.fromOffset(56, 22), Position = UDim2.fromOffset(6, 6), Text = "NEW!", TextColor3 = THEME.Gold, ZIndex = 25 })
				tag.Rotation = -12
			end
			tween(sc, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
			FX.Sound("Reveal", 1, 0.8 + Config.Rarities[def.Rarity].Order * 0.12)
		end)
	end
	task.delay(0.15 * #results + 0.4, function()
		button({ Parent = overlay, AnchorPoint = Vector2.new(0.5, 1), Size = UDim2.fromOffset(200, 54), Position = UDim2.new(0.5, 0, 0.95, 0), Text = "OK", ZIndex = 25 }, function()
			overlay:Destroy()
		end)
	end)
end

-- Анимация открытия: у каждого кейса своя
local function playCaseOpening(caseId, results)
	local case = Config.Cases[caseId]
	local best = 1
	for _, r in ipairs(results) do
		if r.Id then
			best = math.max(best, Config.Rarities[Config.Units[r.Id].Rarity].Order)
		end
	end
	local bestName = Config.RarityOrder[best]
	local bestColor = Config.Rarities[bestName].Color
	local overlay = new("Frame", { Parent = gui, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(5, 0, 10), BackgroundTransparency = 0.15, ZIndex = 20 })
	local stage = new("Frame", { Parent = overlay, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(520, 520), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 21 })
	local r = caseViewport(stage, caseId, { ZIndex = 21 })
	local title = label({ Parent = overlay, AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.fromOffset(700, 56), Position = UDim2.new(0.5, 0, 0.06, 0), Text = case.Name, TextColor3 = case.Color, ZIndex = 22, StrokeThickness = 3 })
	local start = os.clock()
	local SHAKE, BURST = 1.4, 0.9
	local nextTick = 0
	local dirs = {}
	for p, base in pairs(r.Base) do
		local d = base.Position - Vector3.new(0, 2, 0)
		dirs[p] = (d.Magnitude > 0.1 and d.Unit or Vector3.new(0, 1, 0)) + Vector3.new(math.random() - 0.5, math.random() * 0.6, math.random() - 0.5)
	end
	local done = false
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - start
		if t < SHAKE then
			-- фаза 1: тряска, свечение, у каждого кейса своё
			local k = t / SHAKE
			local shake = CFrame.new((math.random() - 0.5) * k * 0.5, 0, (math.random() - 0.5) * k * 0.5) * CFrame.Angles(0, t * (1 + k * 6), (math.random() - 0.5) * k * 0.15)
			for p, base in pairs(r.Base) do
				p.CFrame = shake * base
			end
			if caseId == "VoidCase" and r.Lid then
				r.Lid.CFrame = shake * r.Base[r.Lid] * CFrame.new(0, k * 1.2, 0.6 * k) * CFrame.Angles(-k * 0.9, 0, 0)
			elseif caseId == "ShatteredReality" then
				for _, c in ipairs(r.Cracks) do
					c.Size = Vector3.new(0.14 + k * 0.3, 0.14 + k * 0.3, c.Size.Z)
				end
				if r.Core then
					r.Core.CFrame = shake * r.Base[r.Core] * CFrame.new(0, k * 1.5, 0) * CFrame.Angles(0, t * 8, 0)
				end
			elseif caseId == "BloodMoon" and r.Shards[1] then
				r.Shards[1].CFrame = shake * r.Base[r.Shards[1]] * CFrame.new(0, -k * 2.8, 0)
				overlay.BackgroundColor3 = Color3.fromRGB(5 + k * 60, 0, 10)
			end
			for i, s in ipairs(r.Shards) do
				if not (caseId == "BloodMoon" and i == 1) then
					s.CFrame = CFrame.Angles(0, t * (2 + k * 10), 0) * s.CFrame
				end
			end
			if t >= nextTick then
				nextTick = t + 0.45 - k * 0.3
				FX.Sound("CaseShake", 1, 0.8 + k * 0.8)
			end
		elseif t < SHAKE + BURST then
			-- фаза 2: разрушение — части разлетаются
			if not r.Burst then
				r.Burst = true
				FX.Sound("CaseOpen", 1, 1)
				local flash = new("Frame", { Parent = overlay, Size = UDim2.fromScale(1, 1), BackgroundColor3 = bestColor, BackgroundTransparency = 0.1, ZIndex = 30 })
				tween(flash, 0.8, { BackgroundTransparency = 1 })
				task.delay(0.85, function()
					flash:Destroy()
				end)
			end
			local k = (t - SHAKE) / BURST
			for p, base in pairs(r.Base) do
				local d = dirs[p]
				p.CFrame = CFrame.new(d * k * 14) * base * CFrame.Angles(k * 4 * d.X, k * 5, k * 4 * d.Z)
				p.Transparency = math.min(1, k * 1.3)
			end
		elseif not done then
			done = true
			conn:Disconnect()
			stage:Destroy()
			title.Text = best >= 4 and (bestName:upper() .. "!") or case.Name
			title.TextColor3 = bestColor
			if bestName == "Secret" then
				-- SECRET: чёрный экран, красные молнии, тряска
				FX.Sound("Secret", 1, 1)
				FX.Shake(0.8, 1.2)
				local black = new("Frame", { Parent = overlay, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), ZIndex = 40 })
				local big = label({ Parent = black, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(900, 160), Position = UDim2.fromScale(0.5, 0.5), Text = "SECRET!!", TextColor3 = Color3.fromRGB(255, 30, 50), ZIndex = 41, StrokeThickness = 4 })
				for i = 1, 8 do
					task.delay(i * 0.12, function()
						black.BackgroundColor3 = (i % 2 == 0) and Color3.fromRGB(120, 0, 10) or Color3.new(0, 0, 0)
						big.Rotation = (math.random() - 0.5) * 10
					end)
				end
				task.delay(1.4, function()
					tween(black, 0.4, { BackgroundTransparency = 1 })
					tween(big, 0.4, { TextTransparency = 1 })
					task.delay(0.45, function()
						black:Destroy()
					end)
					showCards(overlay, results)
				end)
			else
				showCards(overlay, results)
			end
		end
	end)
end

local function buildCases()
	local m = modal("Summon", "КЕЙСЫ", UDim2.fromOffset(980, 590), "Gem")
	refs.CaseTabs = {}
	local tabs = new("Frame", { Parent = m, BackgroundTransparency = 1, Size = UDim2.fromOffset(200, 480), Position = UDim2.fromOffset(18, 70), ZIndex = 6 }, {
		new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	for i, id in ipairs(Config.CaseOrder) do
		local case = Config.Cases[id]
		local b = button({ Parent = tabs, Size = UDim2.fromOffset(200, 140), Text = "", BackgroundColor3 = THEME.BG2, StrokeColor = case.Color, LayoutOrder = i, ZIndex = 7 }, function()
			UI.SelectCase(id)
			FX.Sound("Click", 1, 1)
		end)
		caseViewport(b, id, { Size = UDim2.new(1, 0, 0, 100), ZIndex = 8 })
		label({ Parent = b, Size = UDim2.new(1, -10, 0, 26), Position = UDim2.fromOffset(5, 104), Text = case.Name, TextColor3 = case.Color, ZIndex = 8 })
		refs.CaseTabs[id] = b
	end
	refs.CaseBig = new("Frame", { Parent = m, BackgroundColor3 = THEME.BG2, BackgroundTransparency = 0.3, Size = UDim2.fromOffset(300, 300), Position = UDim2.fromOffset(236, 70), ZIndex = 6 }, { corner(10) })
	refs.CaseName = label({ Parent = m, Size = UDim2.fromOffset(420, 40), Position = UDim2.fromOffset(548, 70), Text = "", TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 6 })
	refs.CaseDesc = label({ Parent = m, Size = UDim2.fromOffset(420, 40), Position = UDim2.fromOffset(548, 112), Text = "", TextScaled = false, TextSize = 15, TextWrapped = true, Font = Enum.Font.Gotham, TextColor3 = THEME.Dim, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 6 })
	refs.CaseRates = label({ Parent = m, Size = UDim2.fromOffset(420, 150), Position = UDim2.fromOffset(548, 156), Text = "", RichText = true, TextScaled = false, TextSize = 18, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 6 })
	label({ Parent = m, Size = UDim2.fromOffset(420, 20), Position = UDim2.fromOffset(548, 306), Text = "В x10 гарантирован минимум один Rare+", TextScaled = false, TextSize = 14, Font = Enum.Font.GothamBold, TextColor3 = THEME.Dim, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 6 })
	refs.CaseUnits = new("ScrollingFrame", { Parent = m, BackgroundTransparency = 1, Size = UDim2.fromOffset(732, 150), Position = UDim2.fromOffset(236, 380), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.X, ScrollingDirection = Enum.ScrollingDirection.X, ScrollBarThickness = 6, BorderSizePixel = 0, ZIndex = 6 }, {
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	refs.CaseUnitsLayoutCell = UDim2.fromOffset(100, 106)
	refs.SummonGems = label({ Parent = m, Size = UDim2.fromOffset(240, 36), Position = UDim2.new(0, 236, 1, -52), Text = "💎 0", TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(120, 200, 255), ZIndex = 6 })
	local busy = false
	local function open(count)
		if busy then
			return
		end
		busy = true
		local ok, res = ctx.Request("Summon", { Case = selectedCase, Count = count })
		busy = false
		if ok then
			if selectedCase == "Halloween" then
				-- проклятый сундук: своя кинематографичная анимация
				HalloweenUI.PlayOpening(res, showCards)
			else
				playCaseOpening(selectedCase, res)
			end
		end
	end
	refs.CaseBuy1 = button({ Parent = m, AnchorPoint = Vector2.new(1, 1), Size = UDim2.fromOffset(200, 50), Position = UDim2.new(1, -238, 1, -12), Text = "x1", BackgroundColor3 = THEME.AccentDark, ZIndex = 6 }, function()
		open(1)
	end)
	refs.CaseBuy10 = button({ Parent = m, AnchorPoint = Vector2.new(1, 1), Size = UDim2.fromOffset(210, 50), Position = UDim2.new(1, -18, 1, -12), Text = "x10", BackgroundColor3 = Color3.fromRGB(150, 60, 200), StrokeColor = THEME.Gold, ZIndex = 6 }, function()
		open(10)
	end)
	UI.SelectCase(selectedCase)
end

------------------------------------------------------------------------
-- МАГАЗИН КРИСТАЛЛОВ
------------------------------------------------------------------------
local function buildShop()
	local m = modal("Shop", "МАГАЗИН КРИСТАЛЛОВ", UDim2.fromOffset(920, 470), "Gem")
	local row = new("Frame", { Parent = m, BackgroundTransparency = 1, Size = UDim2.new(1, -36, 0, 270), Position = UDim2.fromOffset(18, 70), ZIndex = 6 }, {
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10), HorizontalAlignment = Enum.HorizontalAlignment.Center }),
	})
	for i, item in ipairs(Config.Shop) do
		local card = panel({ Parent = row, Size = UDim2.fromOffset(165, 266), BackgroundColor3 = THEME.BG2, StrokeColor = Color3.fromRGB(90, 180, 255), LayoutOrder = i, ZIndex = 6 })
		new("UIGradient", { Parent = card, Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(40, 70, 120), THEME.BG) })
		label({ Parent = card, Size = UDim2.new(1, 0, 0, 70), Position = UDim2.fromOffset(0, 12), Text = string.rep("💎", math.min(i, 3)), ZIndex = 7 })
		label({ Parent = card, Size = UDim2.new(1, -10, 0, 40), Position = UDim2.fromOffset(5, 86), Text = Config.FormatNumber(item.Gems), TextColor3 = Color3.fromRGB(130, 210, 255), ZIndex = 7 })
		label({ Parent = card, Size = UDim2.new(1, -10, 0, 34), Position = UDim2.fromOffset(5, 128), Text = item.Title, TextScaled = false, TextSize = 14, TextWrapped = true, Font = Enum.Font.GothamBold, ZIndex = 7 })
		if item.Bonus then
			local tag = label({ Parent = card, Size = UDim2.fromOffset(70, 24), Position = UDim2.new(1, -74, 0, 6), Text = item.Bonus, TextColor3 = THEME.Gold, ZIndex = 8 })
			tag.Rotation = 10
		end
		button({ Parent = card, AnchorPoint = Vector2.new(0.5, 1), Size = UDim2.new(1, -20, 0, 48), Position = UDim2.new(0.5, 0, 1, -12), Text = "R$ " .. item.Robux, BackgroundColor3 = Color3.fromRGB(50, 140, 80), StrokeColor = THEME.Good, ZIndex = 7 }, function()
			local ok, res = ctx.Request("BuyGems", { Key = item.Key })
			if ok and res ~= "prompt" then
				FX.Sound("Purchase", 1, 1)
				UI.Toast("+" .. Config.FormatNumber(res) .. " 💎 (тестовая покупка в Studio)", "good")
			end
		end)
	end
	-- ежедневный подарок
	local daily = panel({ Parent = m, Size = UDim2.new(1, -36, 0, 74), Position = UDim2.new(0, 18, 1, -90), BackgroundColor3 = THEME.BG2, StrokeColor = THEME.Gold, ZIndex = 6 })
	label({ Parent = daily, Size = UDim2.new(0.6, 0, 1, -16), Position = UDim2.fromOffset(14, 8), Text = "🎁 Бесплатный подарок: " .. Config.Settings.DailyGems .. " 💎", TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = THEME.Gold, ZIndex = 7 })
	refs.DailyButton = button({ Parent = daily, AnchorPoint = Vector2.new(1, 0.5), Size = UDim2.fromOffset(260, 52), Position = UDim2.new(1, -12, 0.5, 0), Text = "ЗАБРАТЬ", BackgroundColor3 = Color3.fromRGB(150, 110, 30), StrokeColor = THEME.Gold, ZIndex = 7 }, function()
		local ok, res = ctx.Request("ClaimDaily")
		if ok then
			FX.Sound("Purchase", 1, 1.2)
			UI.Toast("+" .. tostring(res) .. " 💎 Подарок получен!", "gold")
		end
	end)
end

function UI.UpdateShop()
	local prof = ctx.Profile
	if not refs.DailyButton or not prof then
		return
	end
	local left = (prof.DailyReadyAt or 0) - os.time()
	if left > 0 then
		refs.DailyButton.Text = string.format("через %d:%02d:%02d", left // 3600, (left % 3600) // 60, left % 60)
	else
		refs.DailyButton.Text = "ЗАБРАТЬ"
	end
end

function UI.SpinCases(t)
	local r = caseViews.Big
	if r and r.Model.Parent then
		r.Model:PivotTo(CFrame.Angles(0, t * 0.6, 0))
	end
end

------------------------------------------------------------------------
-- ИНВЕНТАРЬ И ЭКИПИРОВКА
------------------------------------------------------------------------
local invSelected

local function buildInventory()
	local m = modal("Inventory", "ЮНИТЫ", UDim2.fromOffset(860, 560), "Helmet")
	-- экипировка
	label({ Parent = m, Size = UDim2.fromOffset(300, 22), Position = UDim2.fromOffset(18, 56), Text = "ЭКИПИРОВКА (клик — снять)", TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = THEME.Dim, Font = Enum.Font.GothamBold, ZIndex = 6 })
	refs.EquipRow = new("Frame", { Parent = m, BackgroundTransparency = 1, Size = UDim2.new(1, -36, 0, 92), Position = UDim2.fromOffset(18, 80), ZIndex = 6 }, {
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8) }),
	})
	-- коллекция
	refs.InvGrid = new("ScrollingFrame", { Parent = m, BackgroundTransparency = 1, Size = UDim2.new(0, 500, 1, -196), Position = UDim2.fromOffset(18, 182), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 6, BorderSizePixel = 0, ZIndex = 6 }, {
		new("UIGridLayout", { CellSize = UDim2.fromOffset(112, 140), CellPadding = UDim2.fromOffset(10, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
		pad(4),
	})
	-- детали
	local d = panel({ Parent = m, BackgroundColor3 = THEME.BG2, Size = UDim2.new(1, -556, 1, -196), Position = UDim2.fromOffset(536, 182), ZIndex = 6 })
	refs.InvDetail = d
	refs.InvName = label({ Parent = d, Size = UDim2.new(1, -20, 0, 30), Position = UDim2.fromOffset(10, 8), Text = "Выбери юнита", TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 7 })
	refs.InvRarity = label({ Parent = d, Size = UDim2.new(1, -20, 0, 18), Position = UDim2.fromOffset(10, 38), Text = "", TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 7 })
	refs.InvDesc = label({ Parent = d, Size = UDim2.new(1, -20, 0, 48), Position = UDim2.fromOffset(10, 60), Text = "", TextScaled = false, TextSize = 14, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Font = Enum.Font.Gotham, TextColor3 = THEME.Dim, ZIndex = 7 })
	refs.InvStats = label({ Parent = d, Size = UDim2.new(1, -20, 0, 120), Position = UDim2.fromOffset(10, 110), Text = "", TextScaled = false, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Font = Enum.Font.Code, ZIndex = 7 })
	-- руна юнита: показать, надеть, снять
	refs.InvRune = button({ Parent = d, AnchorPoint = Vector2.new(0, 1), Size = UDim2.new(1, -20, 0, 34), Position = UDim2.new(0, 10, 1, -60), Text = "РУНА: нет", TextColor3 = Color3.fromRGB(255, 170, 70), BackgroundColor3 = Color3.fromRGB(50, 26, 20), StrokeColor = Color3.fromRGB(255, 130, 30), ZIndex = 7 }, function()
		if invSelected then
			HalloweenUI.OpenRunePicker(invSelected)
		end
	end)
	refs.InvEquip = button({ Parent = d, AnchorPoint = Vector2.new(0, 1), Size = UDim2.new(1, -20, 0, 44), Position = UDim2.new(0, 10, 1, -10), Text = "EQUIP", BackgroundColor3 = Color3.fromRGB(60, 130, 80), ZIndex = 7 }, function()
		if invSelected then
			UI.ToggleEquip(invSelected)
		end
	end)
end

-- Экипировать / снять юнита (из инвентаря и из окна просмотра)
function UI.ToggleEquip(unitId)
	local prof = ctx.Profile
	if not prof or (prof.Inventory[unitId] or 0) <= 0 then
		return
	end
	local equippedSlot
	for i = 1, Config.Settings.EquipSlots do
		if prof.Equipped[tostring(i)] == unitId then
			equippedSlot = i
		end
	end
	if equippedSlot then
		ctx.Request("Equip", { Unit = nil, Slot = equippedSlot })
	else
		local free
		for i = 1, Config.Settings.EquipSlots do
			if not prof.Equipped[tostring(i)] then
				free = i
				break
			end
		end
		if not free then
			UI.Toast("Все слоты заняты — сними юнита сверху", "error")
			return
		end
		ctx.Request("Equip", { Unit = unitId, Slot = free })
	end
end

local function selectInventory(id)
	invSelected = id
	local def = Config.Units[id]
	local prof = ctx.Profile
	local owned = (prof.Inventory[id] or 0) > 0
	refs.InvName.Text = def.Name
	refs.InvRarity.Text = def.Rarity:upper() .. (def.Ability and ("  •  " .. def.Ability) or "")
	refs.InvRarity.TextColor3 = rarityColor(id)
	refs.InvDesc.Text = def.Description
	local lines = { "LV   DMG     RNG   CD     COST" }
	for i, st in ipairs(def.Levels) do
		lines[#lines + 1] = string.format("%-4d %-7s %-5s %-6s $%s", i, Config.FormatNumber(st.Damage), tostring(st.Range), string.format("%.2f", st.Cooldown), Config.FormatNumber(st.Cost))
	end
	refs.InvStats.Text = table.concat(lines, "\n")
	local equipped = false
	for i = 1, Config.Settings.EquipSlots do
		if prof.Equipped[tostring(i)] == id then
			equipped = true
		end
	end
	refs.InvEquip.Visible = owned
	refs.InvRune.Visible = owned
	local runeId = prof.RuneSlots and prof.RuneSlots[id]
	refs.InvRune.Text = runeId and ("РУНА: " .. Config.Runes[runeId].Name .. "  (сменить)") or "РУНА: нет  (надеть)"
	if def.Event and Config.Events[def.Event] then
		refs.InvRarity.Text = def.Rarity:upper() .. "  •  " .. Config.Events[def.Event].Tag .. (def.Ability and ("  •  " .. def.Ability) or "")
	end
	refs.InvEquip.Text = equipped and "UNEQUIP" or "EQUIP"
	refs.InvEquip.BackgroundColor3 = equipped and Color3.fromRGB(130, 50, 60) or Color3.fromRGB(60, 130, 80)
end

-- фильтр коллекции: nil — все юниты, "Halloween" — только юниты события (круг на острове)
function UI.SetInventoryFilter(eventKey)
	UI.InvFilter = eventKey
	if modals.Inventory and modals.Inventory.Visible then
		UI.RefreshInventory()
	end
end

function UI.RefreshInventory()
	local prof = ctx.Profile
	if not prof or not refs.InvGrid then
		return
	end
	for _, c in ipairs(refs.EquipRow:GetChildren()) do
		if not c:IsA("UIListLayout") then
			c:Destroy()
		end
	end
	for i = 1, Config.Settings.EquipSlots do
		local id = prof.Equipped[tostring(i)]
		local b = button({ Parent = refs.EquipRow, Size = UDim2.fromOffset(92, 90), Text = "", BackgroundColor3 = THEME.BG2, StrokeColor = id and rarityColor(id) or THEME.AccentDark, LayoutOrder = i, ZIndex = 7 }, function()
			if id then
				ctx.Request("Equip", { Unit = nil, Slot = i })
			end
		end)
		if id then
			viewport(b, id, 1, { ZIndex = 8 })
		else
			label({ Parent = b, Size = UDim2.fromScale(1, 1), Text = tostring(i), TextColor3 = THEME.Dim, ZIndex = 8 })
		end
	end
	for _, c in ipairs(refs.InvGrid:GetChildren()) do
		if c:IsA("GuiButton") then
			c:Destroy()
		end
	end
	for order, id in ipairs(Config.UnitOrder) do
		local def = Config.Units[id]
		local count = prof.Inventory[id] or 0
		local rc = rarityColor(id)
		if UI.InvFilter and def.Event ~= UI.InvFilter then
			continue
		end
		local b = button({ Parent = refs.InvGrid, Text = "", BackgroundColor3 = THEME.BG2, StrokeColor = count > 0 and rc or Color3.fromRGB(60, 50, 70), LayoutOrder = order, ZIndex = 7 }, function()
			selectInventory(id)
			if (ctx.Profile.Inventory[id] or 0) > 0 then
				UnitViewer.Open(id, 1)
			else
				UI.Toast("Сначала открой этого юнита в кейсе — тогда откроется 3D-просмотр", "error")
			end
		end)
		new("UIGradient", { Parent = b, Rotation = 90, Color = ColorSequence.new(rc:Lerp(THEME.BG, count > 0 and 0.6 or 0.9), THEME.BG) })
		viewport(b, id, 1, { Size = UDim2.new(1, 0, 0, 96), ZIndex = 8, Silhouette = count == 0 })
		label({ Parent = b, Size = UDim2.new(1, -8, 0, 18), Position = UDim2.fromOffset(4, 98), Text = count > 0 and def.Name or "???", Font = Enum.Font.GothamBold, ZIndex = 8 })
		label({ Parent = b, Size = UDim2.new(1, -8, 0, 16), Position = UDim2.fromOffset(4, 118), Text = def.Rarity, TextColor3 = rc, ZIndex = 8 })
		if count > 0 then
			label({ Parent = b, Size = UDim2.fromOffset(40, 20), Position = UDim2.new(1, -44, 0, 4), Text = "x" .. count, TextColor3 = THEME.Gold, ZIndex = 9 })
			if prof.RuneSlots and prof.RuneSlots[id] then
				icon("Rune", b, { Size = UDim2.fromOffset(20, 20), Position = UDim2.new(1, -24, 0, 26), ZIndex = 10 })
			end
		end
		eventTag(b, id, 8, UDim2.fromOffset(4, 82), UDim2.new(1, -8, 0, 13))
	end
	if invSelected then
		selectInventory(invSelected)
	end
end

------------------------------------------------------------------------
-- ВЫБОР СЛОЖНОСТИ (круг ИГРАТЬ)
------------------------------------------------------------------------
local function joinMatch(diffKey)
	UI.Show("Mode", false)
	task.spawn(function()
		local ok = UI.FadeTransition("ПОРТАЛ ОТКРЫВАЕТСЯ...", function()
			return ctx.Request("JoinMatch", { Difficulty = diffKey })
		end)
		if not ok then
			UI.Show("Mode", true)
		end
	end)
end

local function buildMode()
	local m = modal("Mode", "ВЫБОР СЛОЖНОСТИ", UDim2.fromOffset(880, 430))
	local cards = new("Frame", { Parent = m, BackgroundTransparency = 1, Size = UDim2.new(1, -36, 0, 340), Position = UDim2.fromOffset(18, 70), ZIndex = 6 }, {
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 12), HorizontalAlignment = Enum.HorizontalAlignment.Center }),
	})
	refs.ModeCards = cards
	for i, key in ipairs(Config.DifficultyOrder) do
		local d = Config.Difficulties[key]
		local card = panel({ Parent = cards, Size = UDim2.fromOffset(200, 336), BackgroundColor3 = THEME.BG2, StrokeColor = d.Color, LayoutOrder = i, ZIndex = 6 })
		new("UIGradient", { Parent = card, Rotation = 90, Color = ColorSequence.new(d.Color:Lerp(THEME.BG, 0.6), THEME.BG) })
		label({ Parent = card, Size = UDim2.new(1, -16, 0, 40), Position = UDim2.fromOffset(8, 10), Text = d.Name, TextColor3 = d.Color, ZIndex = 7 })
		local lines = {
			string.format("HP врагов   x%.2g", d.HP),
			string.format("Скорость    x%.2g", d.Speed),
			string.format("Деньги      x%.2g", d.Money),
			string.format("Гемы        x%.2g", d.Gems),
			string.format("Ядро        %d HP", d.CoreHP),
		}
		label({ Parent = card, Size = UDim2.new(1, -20, 0, 110), Position = UDim2.fromOffset(10, 58), Text = table.concat(lines, "\n"), TextScaled = false, TextSize = 16, Font = Enum.Font.Code, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 7 })
		label({ Parent = card, Size = UDim2.new(1, -20, 0, 70), Position = UDim2.fromOffset(10, 176), Text = d.Description, TextScaled = false, TextSize = 14, TextWrapped = true, Font = Enum.Font.Gotham, TextColor3 = THEME.Dim, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 7 })
		button({ Parent = card, AnchorPoint = Vector2.new(0.5, 1), Size = UDim2.new(1, -24, 0, 50), Position = UDim2.new(0.5, 0, 1, -12), Text = "ИГРАТЬ", BackgroundColor3 = d.Color:Lerp(Color3.new(0, 0, 0), 0.45), StrokeColor = d.Color, ZIndex = 7 }, function()
			joinMatch(key)
		end)
	end
	-- если матч уже идёт — присоединиться
	local running = new("Frame", { Parent = m, BackgroundTransparency = 1, Size = UDim2.new(1, -36, 0, 300), Position = UDim2.fromOffset(18, 80), Visible = false, ZIndex = 6 })
	refs.ModeRunning = running
	refs.ModeRunningText = label({ Parent = running, Size = UDim2.new(1, 0, 0, 90), Position = UDim2.fromOffset(0, 40), Text = "", ZIndex = 7 })
	button({ Parent = running, AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.fromOffset(320, 64), Position = UDim2.new(0.5, 0, 0, 170), Text = "ПРИСОЕДИНИТЬСЯ", BackgroundColor3 = THEME.AccentDark, ZIndex = 7 }, function()
		joinMatch(nil)
	end)
end

function UI.RefreshMode()
	local phase = ctx.State:GetAttribute("Phase") or "Idle"
	local idle = phase == "Idle"
	refs.ModeCards.Visible = idle
	refs.ModeRunning.Visible = not idle
	if not idle then
		local d = Config.Difficulties[ctx.State:GetAttribute("Difficulty") or "Medium"] or Config.Difficulties.Medium
		local w = ctx.State:GetAttribute("Wave") or 0
		refs.ModeRunningText.Text = "Уже идёт бой: " .. d.Name .. ", волна " .. w .. "\nПрисоединяйся к команде!"
		refs.ModeRunningText.TextColor3 = d.Color
	end
end

------------------------------------------------------------------------
-- ПОБЕДА / ПОРАЖЕНИЕ
------------------------------------------------------------------------
local function showEnd(victory, payload)
	local overlay = new("Frame", { Parent = gui, Size = UDim2.fromScale(1, 1), BackgroundColor3 = victory and Color3.fromRGB(30, 10, 50) or Color3.fromRGB(40, 0, 10), BackgroundTransparency = 1, ZIndex = 30 })
	tween(overlay, 0.6, { BackgroundTransparency = 0.3 })
	local title = label({ Parent = overlay, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(800, 120), Position = UDim2.fromScale(0.5, 0.38), Text = victory and "VICTORY" or "DEFEAT", TextColor3 = victory and THEME.Gold or THEME.Bad, ZIndex = 31, StrokeThickness = 4 })
	local sc = new("UIScale", { Parent = title, Scale = 0.2 })
	tween(sc, 0.5, { Scale = 1 }, Enum.EasingStyle.Back)
	local sub = victory and ("Пустота отступила! Награда: 💎" .. tostring(payload.Gems) .. (payload.Coins and ("  +🎃" .. payload.Coins .. " Halloween Coins") or "")) or ("Ядро разрушено на волне " .. tostring(payload.Wave) .. (payload.Mode == "Halloween" and "  •  Halloween Coins не выдаются" or ""))
	label({ Parent = overlay, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(800, 40), Position = UDim2.fromScale(0.5, 0.5), Text = sub, ZIndex = 31 })
	local timer = label({ Parent = overlay, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(600, 30), Position = UDim2.fromScale(0.5, 0.57), Text = "", TextColor3 = THEME.Dim, ZIndex = 31 })
	local reset = payload.Reset or 15
	task.spawn(function()
		for i = reset, 1, -1 do
			if not overlay.Parent then
				return
			end
			timer.Text = "Новая игра через " .. i .. " c"
			task.wait(1)
		end
	end)
	refs.EndOverlay = overlay
end

------------------------------------------------------------------------
-- СОБЫТИЯ
------------------------------------------------------------------------
function UI.OnNotify(p)
	local t = p.Type
	if t == "Toast" then
		UI.Toast(p.Text, p.Kind)
	elseif t == "WaveStart" then
		FX.Sound(p.Boss and "Boss" or "WaveStart", 1, 1)
		if p.Boss then
			FX.Shake(0.4, 0.8)
			UI.Announce("WAVE " .. p.Wave, "⚠ BOSS: " .. p.Boss, THEME.Pink)
		else
			UI.Announce("WAVE " .. p.Wave, nil, THEME.Text)
		end
	elseif t == "WaveClear" then
		UI.Toast(string.format("Волна %d пройдена! +$%s  +💎%d", p.Wave, Config.FormatNumber(p.Reward), p.Gems), "good")
	elseif t == "BossDown" then
		FX.Shake(0.6, 0.6)
	elseif t == "CoreHit" then
		if player:GetAttribute("InMatch") then
			FX.Shake(0.35, 0.3)
			FX.Sound("CoreHit", 1, 1)
		end
		local f = refs.CoreFill
		f.BackgroundColor3 = THEME.Bad
		tween(f, 0.4, { BackgroundColor3 = UI.MapMode == "Halloween" and Color3.fromRGB(255, 130, 30) or THEME.Accent })
	elseif t == "Victory" then
		FX.Sound("Victory", 1, 1)
		showEnd(true, p)
	elseif t == "Defeat" then
		FX.Sound("Defeat", 1, 1)
		showEnd(false, p)
	elseif t == "Fade" then
		task.spawn(UI.FadeTransition, p.Text or "")
	elseif t == "Purchase" then
		FX.Sound("Purchase", 1, 1)
		UI.Toast("Покупка: +" .. Config.FormatNumber(p.Gems or 0) .. " 💎", "gold")
	elseif t == "Reset" then
		if refs.EndOverlay then
			refs.EndOverlay:Destroy()
			refs.EndOverlay = nil
		end
		UI.CloseUnit()
		if player:GetAttribute("Island") then
			UI.Toast("Бой окончен. Ты на Хэллоуин-острове", "good")
		else
			UI.Toast("Бой окончен. Ты в лобби — встань в круг ИГРАТЬ", "good")
		end
	end
end

-- карта матча: Void или Haunted Hollow
function UI.SetMapMode(key)
	UI.MapMode = key
	if refs.CoreFill then
		refs.CoreFill.BackgroundColor3 = key == "Halloween" and Color3.fromRGB(255, 130, 30) or THEME.Accent
	end
end

function UI.Fade(text)
	task.spawn(UI.FadeTransition, text)
end

function UI.UpdateQueue()
	HalloweenUI.UpdateQueue()
end

function UI.SetLiteText(on)
	refs.LiteCaption.Text = on and "ЛЁГКАЯ" or "ПОЛНАЯ"
	refs.LiteCaption.TextColor3 = on and THEME.Good or THEME.Text
end

function UI.SetProfile(prof)
	ctx.Profile = prof
	refreshHotbar()
	UnitViewer.Refresh()
	if modals.Inventory and modals.Inventory.Visible then
		UI.RefreshInventory()
	end
	HalloweenUI.OnProfile(prof)
end

local lastRefresh = 0
function UI.Update(dt)
	local State = ctx.State
	local money = player:GetAttribute("Money") or 0
	refs.Money.Text = Config.FormatNumber(money)
	local gems = player:GetAttribute("Gems") or (ctx.Profile and ctx.Profile.Gems) or 0
	refs.Gems.Text = Config.FormatNumber(gems)
	if refs.SummonGems and selectedCase ~= "Halloween" then
		refs.SummonGems.Text = "💎 " .. Config.FormatNumber(gems)
	end

	local wave = State:GetAttribute("Wave") or 0
	local maxWave = State:GetAttribute("MaxWave") or 30
	local phase = State:GetAttribute("Phase") or "Idle"
	local inMatch = player:GetAttribute("InMatch") == true
	refs.Top.Visible = inMatch
	refs.Hotbar.Visible = inMatch
	refs.Leave.Visible = inMatch
	refs.Money.Visible = inMatch
	local coins = player:GetAttribute("HalloweenCoins") or (ctx.Profile and ctx.Profile.HalloweenCoins) or 0
	refs.Coins.Text = Config.FormatNumber(coins)
	local gy = inMatch and 50 or 8
	refs.Currency.Size = UDim2.fromOffset(230, gy + 84)
	refs.Gems.Position = UDim2.fromOffset(52, gy)
	refs.GemsIcon.Position = UDim2.fromOffset(10, gy - 1)
	refs.Coins.Position = UDim2.fromOffset(52, gy + 44)
	refs.CoinsIcon.Position = UDim2.fromOffset(11, gy + 43)
	if refs.SummonGems and selectedCase == "Halloween" then
		refs.SummonGems.Text = "🎃 " .. Config.FormatNumber(coins)
		refs.SummonGems.TextColor3 = Color3.fromRGB(255, 160, 60)
	elseif refs.SummonGems then
		refs.SummonGems.TextColor3 = Color3.fromRGB(120, 200, 255)
	end
	-- искры на карточках хэллоуинских юнитов
	local tt = os.clock()
	for i = #sparks, 1, -1 do
		local sp = sparks[i]
		if not sp.F.Parent then
			table.remove(sparks, i)
		else
			local a = ((tt * sp.S + sp.P) % 1)
			sp.F.Position = UDim2.fromScale(sp.X + math.sin(tt * 2 + sp.P) * 0.04, 1 - a)
			sp.F.BackgroundTransparency = 0.2 + a * 0.8
		end
	end
	refs.MoneyIcon.Visible = inMatch
	if not inMatch and UI.SelectedUid then
		UI.CloseUnit()
	end
	if modals.Mode.Visible then
		UI.RefreshMode()
	end
	local diff = Config.Difficulties[State:GetAttribute("Difficulty") or ""]
	refs.Wave.Text = "WAVE " .. wave .. " / " .. maxWave .. (diff and ("  •  " .. diff.Name) or "")
	refs.Wave.TextColor3 = diff and diff.Color or THEME.Text
	local count = 0
	for _ in pairs(Renderer.EnemyViews) do
		count = count + 1
	end
	if phase == "Prep" then
		refs.Status.Text = "Расставь юнитов и начни волну"
	elseif phase == "Intermission" then
		local left = math.max(0, math.ceil((State:GetAttribute("NextWaveAt") or 0) - workspace:GetServerTimeNow()))
		refs.Status.Text = "Следующая волна через " .. left .. " c"
		refs.Start.Text = "▶ START WAVE (" .. left .. ")"
	elseif phase == "Wave" then
		refs.Status.Text = "Врагов на поле: " .. count
	elseif phase == "Victory" then
		refs.Status.Text = "ПОБЕДА!"
	elseif phase == "Defeat" then
		refs.Status.Text = "Ядро разрушено"
	end
	if phase == "Prep" then
		refs.Start.Text = "▶ START WAVE"
	end
	refs.Start.Visible = inMatch and (phase == "Prep" or phase == "Intermission")

	local hp = State:GetAttribute("CoreHP") or 100
	local maxHp = State:GetAttribute("CoreMaxHP") or 100
	refs.CoreFill.Size = UDim2.fromScale(math.clamp(hp / maxHp, 0, 1), 1)
	refs.CoreText.Text = (UI.MapMode == "Halloween" and "СВЯТИЛИЩЕ  " or "VOID CORE  ") .. hp .. " / " .. maxHp

	-- босс
	local bossId = State:GetAttribute("BossId") or 0
	local bv = bossId ~= 0 and Renderer.EnemyViews[bossId]
	if bv and inMatch then
		refs.Boss.Visible = true
		refs.BossName.Text = "☠ " .. (State:GetAttribute("BossName") or "BOSS"):upper()
		refs.BossFill.Size = UDim2.fromScale(math.clamp(bv.HP / bv.MaxHP, 0, 1), 1)
		refs.BossHP.Text = Config.FormatNumber(bv.HP) .. " / " .. Config.FormatNumber(bv.MaxHP)
	else
		refs.Boss.Visible = false
	end

	-- доступность слотов
	for _, s in ipairs(slotRefs) do
		if s.Id and s.Cost then
			local cost = Config.Units[s.Id].Levels[1].Cost
			s.Cost.TextColor3 = money >= cost and THEME.Good or THEME.Bad
		end
	end

	UI.SpinCases(os.clock())
	if modals.Shop and modals.Shop.Visible then
		UI.UpdateShop()
	end
	lastRefresh = lastRefresh + dt
	if lastRefresh > 0.25 then
		lastRefresh = 0
		if UI.SelectedUid then
			UI.RefreshUnitPanel()
		end
	end
end

function UI.Init(c)
	ctx = c
	Config, UnitModels, Renderer, FX = c.Config, c.UnitModels, c.Renderer, c.FX
	CaseModels = c.CaseModels
	local pg = player:WaitForChild("PlayerGui")
	local old = pg:FindFirstChild("VoidTD_UI")
	if old then
		old:Destroy()
	end
	local screen = new("ScreenGui", { Name = "VoidTD_UI", ResetOnSpawn = false, IgnoreGuiInset = true, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = pg })
	-- корневой контейнер: UIScale + размер 1/s дают ровно весь экран при любом масштабе
	gui = new("Frame", { Name = "Root", Parent = screen, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) })
	local uiScale = new("UIScale", { Parent = gui, Name = "Scale" })
	buildHUD()
	buildHotbar()
	buildUnitPanel()
	buildCases()
	buildShop()
	buildInventory()
	buildMode()
	-- адаптация под маленькие экраны
	local cam = workspace.CurrentCamera
	local function fit()
		local vs = cam.ViewportSize
		local s = math.clamp(math.min(vs.X / 1280, vs.Y / 760), 0.55, 1.15)
		uiScale.Scale = s
		gui.Size = UDim2.fromScale(1 / s, 1 / s)
	end
	fit()
	cam:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	Renderer.OnUnitRemoved = function(uid)
		if UI.SelectedUid == uid then
			UI.CloseUnit()
		end
	end
	UI.Gui = screen
	-- окно 3D-просмотра юнита
	UI.Root = gui
	UI.Kit = { new = new, corner = corner, stroke = stroke, label = label, button = button, panel = panel, tween = tween,
		modal = modal, viewport = viewport, icon = icon, rarityColor = rarityColor, eventTag = eventTag, eventSparks = eventSparks, pad = pad }
	UI.SpecialText = specialText
	UI.Modals = modals
	UI.Refs = refs
	UnitViewer.Init(c, UI)
	HalloweenUI.Init(c, UI)
end

return UI
]======] }
FILES[#FILES + 1] = { "StarterPlayerScripts", { "VoidTDClient", "Placement" }, "ModuleScript", [======[
--!nocheck
-- VOID TD :: Placement (клиент)
-- Полупрозрачный призрак юнита следует за курсором, круг радиуса показывает зелёный/красный статус.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Placement = {}
Placement.Active = false

local ctx, Config, PathUtil, UnitModels, FX, UI, Renderer
local player = Players.LocalPlayer

local V = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles
local rad = math.rad

local ghost, circle, inner, conn
local unitId
local rotation = 0
local valid = false
local lastPos
local touchPos
local reason = ""

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include

local GOOD = Color3.fromRGB(80, 230, 140)
local BAD = Color3.fromRGB(255, 70, 90)

local function isTouch()
	return UserInputService.TouchEnabled and not UserInputService.MouseEnabled
end

local function countMine(id)
	local total, same = 0, 0
	for _, v in pairs(Renderer.UnitViews) do
		if v.Folder:GetAttribute("OwnerId") == player.UserId then
			total = total + 1
			if v.UnitId == id then
				same = same + 1
			end
		end
	end
	return total, same
end

local function check(hit, pos)
	if not hit or not hit.Instance:GetAttribute("Placeable") then
		return false, "Сюда ставить нельзя"
	end
	local ok, why = PathUtil.IsPlacementClear(pos)
	if not ok then
		return false, why
	end
	for _, v in pairs(Renderer.UnitViews) do
		if PathUtil.FlatDistance(v.Pos, pos) < Config.Settings.PlacementSpacing then
			return false, "Слишком близко к другому юниту"
		end
	end
	local def = Config.Units[unitId]
	if (player:GetAttribute("Money") or 0) < def.Levels[1].Cost then
		return false, "Недостаточно денег"
	end
	local total, same = countMine(unitId)
	if total >= Config.Settings.MaxUnitsPerPlayer then
		return false, "Лимит юнитов"
	end
	if same >= Config.Rarities[def.Rarity].PlacementLimit then
		return false, "Лимит этого юнита"
	end
	return true
end

local function update()
	local cam = workspace.CurrentCamera
	local ray
	if touchPos then
		ray = cam:ScreenPointToRay(touchPos.X, touchPos.Y)
	else
		local screen = UserInputService:GetMouseLocation()
		ray = cam:ViewportPointToRay(screen.X, screen.Y)
	end
	local map = ctx.Renderer.ActiveMap()
	if not map then
		return
	end
	params.FilterDescendantsInstances = { map }
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 800, params)
	if not hit then
		valid = false
		return
	end
	local pos = hit.Position
	lastPos = pos
	valid, reason = check(hit, pos)
	local hip = ghost.HipHeight
	ghost.Root.CFrame = CF(pos + V(0, hip, 0)) * ANG(0, rad(rotation), 0)
	local color = valid and GOOD or BAD
	local range = Config.Units[unitId].Levels[1].Range
	circle.Size = V(0.15, range * 2, range * 2)
	circle.CFrame = CF(pos + V(0, 0.22, 0)) * ANG(0, 0, rad(90))
	circle.Color = color
	inner.CFrame = CF(pos + V(0, 0.25, 0)) * ANG(0, 0, rad(90))
	inner.Color = color
	for _, d in ipairs(ghost.Model:GetDescendants()) do
		if d:IsA("Highlight") then
			d.FillColor = color
			d.OutlineColor = color
		end
	end
end

function Placement.Start(id)
	if not id or not Config.Units[id] then
		return
	end
	Placement.Stop()
	local def = Config.Units[id]
	if (player:GetAttribute("Money") or 0) < def.Levels[1].Cost then
		UI.Toast("Недостаточно денег: нужно $" .. Config.FormatNumber(def.Levels[1].Cost), "error")
		return
	end
	local phase = ctx.State:GetAttribute("Phase")
	if phase == "Victory" or phase == "Defeat" or not player:GetAttribute("InMatch") then
		return
	end
	unitId = id
	ghost = UnitModels.Build(id, 1)
	for _, d in ipairs(ghost.Model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CanQuery = false
			d.CanTouch = false
			d.CastShadow = false
			if d.Transparency < 1 then
				d.Transparency = 0.35 + d.Transparency * 0.5
			end
		elseif d:IsA("ParticleEmitter") or d:IsA("PointLight") or d:IsA("Trail") then
			d:Destroy()
		end
	end
	local hl = Instance.new("Highlight")
	hl.FillTransparency = 0.75
	hl.OutlineTransparency = 0.2
	hl.DepthMode = Enum.HighlightDepthMode.Occluded
	hl.Parent = ghost.Model
	ghost.Model.Parent = workspace
	circle = FX.Part({ Shape = Enum.PartType.Cylinder, Transparency = 0.72, Parent = workspace })
	circle.Name = "VoidTD_GhostRange"
	inner = FX.Part({ Shape = Enum.PartType.Cylinder, Size = V(0.2, 2.6, 2.6), Transparency = 0.3, Parent = workspace })
	Placement.Active = true
	rotation = rotation or 0
	touchPos = nil
	UI.CloseUnit()
	UI.ShowPlacementHint(true, isTouch())
	conn = RunService.RenderStepped:Connect(update)
	update()
end

function Placement.Stop()
	Placement.Active = false
	if conn then
		conn:Disconnect()
		conn = nil
	end
	if ghost then
		ghost.Model:Destroy()
		ghost = nil
	end
	if circle then
		circle:Destroy()
		circle = nil
	end
	if inner then
		inner:Destroy()
		inner = nil
	end
	UI.ShowPlacementHint(false)
end

function Placement.Rotate()
	rotation = (rotation + 45) % 360
end

function Placement.Confirm()
	if not Placement.Active then
		return
	end
	update()
	if not valid then
		UI.Toast(reason ~= "" and reason or "Сюда ставить нельзя", "error")
		return
	end
	local id = unitId
	local ok = ctx.Request("Place", { Unit = id, Position = lastPos, Rotation = rotation })
	if ok then
		local keep = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
		local enough = (player:GetAttribute("Money") or 0) >= Config.Units[id].Levels[1].Cost
		if not (keep and enough) then
			Placement.Stop()
		end
	end
end

function Placement.SetTouch(pos)
	touchPos = pos
end

function Placement.Init(c)
	ctx = c
	Config, PathUtil, UnitModels, FX, UI, Renderer = c.Config, c.PathUtil, c.UnitModels, c.FX, c.UI, c.Renderer
end

return Placement
]======] }

for _, f in ipairs(FILES) do
	install(f[1], f[2], f[3], f[4])
end

-- построить карту прямо в редакторе (чтобы её было видно до запуска)
local ok, err = pcall(function()
	local MapBuilder = require(SSS.VoidTDServer.MapBuilder)
	MapBuilder.Build()
end)
if not ok then
	warn("[VOID TD] Карта будет построена при запуске игры: " .. tostring(err))
end

print("[VOID TD] Установка завершена! Сохрани место (Ctrl+S) и нажми Play.")
print("[VOID TD] Для сохранения гемов: Game Settings -> Security -> Enable Studio Access to API Services.")
