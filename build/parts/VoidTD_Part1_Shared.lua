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
Config.CaseOrder = { "VoidCase", "ShatteredReality", "BloodMoon" }

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
	BloodMoon = {
		Name = "BLOOD MOON", Color = Color3.fromRGB(210, 30, 50),
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
		Case_BloodMoon        = { Offset = Vector3.new(-58, 0, 34),  Radius = 7, Title = "BLOOD MOON",        Color = Color3.fromRGB(230, 40, 60),  Case = "BloodMoon" },
	},
}
Config.BattleSpawn = Vector3.new(10, 60, 10)

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
		Name = "Blood Acolyte", Rarity = "Common", AttackType = "Melee", Case = "BloodMoon",
		Description = "Послушник с серпом. Удары вызывают кровотечение.",
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
		Name = "Crimson Gunslinger", Rarity = "Rare", AttackType = "Projectile", Case = "BloodMoon",
		Description = "Стрелок с двумя револьверами. Всегда стреляет дуплетом.",
		Anim = "Revolver", HitDelay = 0.05, ProjectileSpeed = 200, Projectile = "Bullet", Scale = 1.0, DefaultTarget = "First",
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
		Name = "Moon Witch", Rarity = "Epic", AttackType = "Chain", Case = "BloodMoon",
		Description = "Лунная ведьма. Лунный серп отскакивает между врагами.",
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
		Name = "Bloodfang Warlord", Rarity = "Legendary", AttackType = "AOE", ImpactKind = "Cleave", Case = "BloodMoon",
		Description = "Военачальник с двуручным топором. Рассекающий удар по области + кровотечение.",
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
		Name = "Lunar Seraph", Rarity = "Mythic", AttackType = "Pierce", Case = "BloodMoon",
		Description = "Лунный серафим. Луч пронзает всех врагов на линии.",
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
		Name = "CRIMSON ECLIPSE", Rarity = "Secret", AttackType = "AOE", ImpactKind = "Reap", Case = "BloodMoon",
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
}

------------------------------------------------------------------------
-- ВРАГИ
-- Health — базовое HP (умножается на множитель волны).
-- Armor — доля поглощаемого урона, Dodge — шанс уклониться.
------------------------------------------------------------------------
Config.EnemyOrder = {
	"LostSoul", "VoidCrawler", "ShadowBeast", "ArmoredHorror", "RiftPhantom",
	"AbyssBrute", "CorruptedTitan", "VoidDevourer", "TheEntity",
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
for i, p in ipairs(Config.Map.Path) do
	points[i] = Vector3.new(p[1], Config.Map.GroundY, p[2])
end

local cumulative = { 0 }
for i = 2, #points do
	cumulative[i] = cumulative[i - 1] + (points[i] - points[i - 1]).Magnitude
end

PathUtil.Points = points
PathUtil.Length = cumulative[#cumulative]

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
	local half = Config.Map.PathWidth / 2
	if PathUtil.DistanceToPath(pos) < half + s.PathClearance then
		return false, "Нельзя ставить на дорогу"
	end
	local size = Config.Map.IslandSize
	if math.abs(pos.X) > size.X / 2 - 3 or math.abs(pos.Z) > size.Y / 2 - 3 then
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
FILES[#FILES + 1] = { "ReplicatedStorage", { "VoidTD", "UnitModels" }, "ModuleScript", [======[
--!nocheck
-- VOID TD :: UnitModels
-- Процедурные модели юнитов в стиле Roblox R6. Без внешних ассетов.
-- UnitModels.Build(unitId, level) -> rig { Model, Motors, Base, Idle, Muzzle, ... }

local UnitModels = {}
-- Облегчённый режим: без мелких деталей, частиц, подсветки и шлейфов (меняется на клиенте)
UnitModels.Lite = false

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
			{ Shape = Enum.PartType.Cylinder, Transparency = 0.55, Name = "AuraRing" })
		r:Sparkles(r.Torso, color, { Rate = 10, Up = 3, Size = 0.3, LifeMin = 0.8, LifeMax = 1.4 })
		r:Glow(r.Torso, color, 10, 1.2)
	end
end


------------------------------------------------------------------------
-- ДОПОЛНИТЕЛЬНЫЕ ДЕТАЛИ МОДЕЛЕЙ (ремни, сумки, эмблемы, кольца)
------------------------------------------------------------------------
local Details = {}

function Details.VoidSoldier(r, lv)
	local T, H, RL, LL = r.Torso, r.Head, r.RLeg, r.LLeg
	r:Box(T, V(0.9, 1.05, 0.08), CF(0, -1.4, -0.54), P.Violet, M.Fabric) -- табард
	r:Neon(T, V(0.3, 0.3, 0.06), CF(0, -1.3, -0.6) * ANG(0, 0, rad(45)), lv >= 2 and P.Neon or P.Purple, lv < 2 and { Material = M.Plastic } or nil)
	r:Box(T, V(2.04, 0.4, 1.04), CF(0, -1.15, 0), P.Steel, M.Metal) -- кольчужная юбка
	r:Seg(T, V(-0.85, 0.95, -0.72), V(0.75, -0.6, -0.72), 0.16, P.Maroon) -- ремень через плечо
	r:Pouch(T, CF(0.72, -0.8, -0.62), P.Maroon)
	r:Ball(H, 0.2, CF(-0.79, 0.25, -0.4), P.Steel, M.Metal)
	r:Ball(H, 0.2, CF(0.79, 0.3, -0.4), P.Steel, M.Metal)
	for _, Lg in ipairs({ RL, LL }) do
		r:Box(Lg, V(0.9, 0.28, 0.25), CF(0, -0.88, -0.68), P.Black, M.Metal) -- носки сапог
	end
	if lv >= 3 then
		r:Cyl(T, 0.16, 1.6, CF(0, 0.1, 0.62), P.Coal, M.Metal, "Z") -- круглый щит на спине
		r:Cyl(T, 0.12, 1.75, CF(0, 0.1, 0.6), P.Steel, M.Metal, "Z")
		r:Sphere(T, V(0.5, 0.5, 0.3), CF(0, 0.1, 0.72), P.Neon, M.Neon)
	end
end

function Details.ShadowArcher(r, lv)
	local T, H, RA, LA, RL, LL = r.Torso, r.Head, r.RArm, r.LArm, r.RLeg, r.LLeg
	r:Box(T, V(2.06, 0.25, 1.06), CF(0, -0.85, 0), P.Maroon)
	r:Cyl(T, 0.5, 0.18, CF(1.05, -0.85, -0.2), P.Black, M.Plastic, "Y") -- кинжал
	r:Box(T, V(0.1, 0.7, 0.24), CF(1.05, -1.45, -0.2), P.Pale, M.Metal)
	r:Pouch(T, CF(-0.65, -0.9, -0.6), P.Coal)
	for _, Lg in ipairs({ RL, LL }) do
		r:Box(Lg, V(1.04, 0.12, 1.04), CF(0, -0.15, 0), P.DeepViolet, M.Fabric)
		r:Box(Lg, V(1.04, 0.12, 1.04), CF(0, -0.45, 0), P.DeepViolet, M.Fabric)
	end
	r:Box(RA, V(1.04, 0.12, 1.04), CF(0, -0.95, 0), P.Maroon)
	if lv >= 2 then
		r:Neon(H, V(1.56, 0.08, 0.08), CF(0, 0.6, -0.75), P.Neon)
		r:Neon(H, V(0.08, 1.2, 0.08), CF(-0.73, 0, -0.75), P.Neon)
		r:Neon(H, V(0.08, 1.2, 0.08), CF(0.73, 0, -0.75), P.Neon)
	end
	-- развевающийся шарф
	local scarf = r:Joint("Scarf", T, V(0.5, 1.5, 0.1), CF(-0.35, 0.95, 0.6), ANG(rad(18), 0, rad(8)) * CF(0, -0.75, 0.05), P.Maroon, M.Fabric)
	r:Wedge(scarf, V(0.5, 0.4, 0.1), CF(0, -0.95, 0) * ANG(0, 0, math.pi), P.Maroon, M.Fabric)
end

function Details.LostMage(r, lv)
	local T, RA = r.Torso, r.RArm
	r:Pouch(T, CF(-0.7, -0.75, -0.66), P.Maroon)
	r:Ball(T, 0.32, CF(0.55, -1.0, -0.7), P.NeonPink, M.Neon) -- зелья
	r:Cyl(T, 0.18, 0.12, CF(0.55, -0.8, -0.7), P.Pale, M.Glass, "Y")
	r:Ball(T, 0.28, CF(0.82, -1.0, -0.68), Color3.fromRGB(90, 200, 255), M.Neon)
	r:Cyl(T, 0.16, 0.1, CF(0.82, -0.82, -0.68), P.Pale, M.Glass, "Y")
	r:Box(T, V(0.28, 0.75, 0.6), CF(1.15, -0.9, 0), P.Maroon) -- книга
	r:Box(T, V(0.3, 0.65, 0.5), CF(1.16, -0.9, 0), P.Pale)
	r:Box(T, V(2.24, 0.15, 1.34), CF(0, -2.95, 0), lv >= 3 and P.Neon or P.Violet, lv >= 3 and M.Neon or M.Fabric) -- кайма мантии
	if lv >= 2 then
		local hub = r:Orbit("OrbitStaff", RA, CF(0, 2.75, -0.55), 0.95, 0, 0.22, P.NeonSoft)
		for i = 0, (lv >= 4 and 3 or 2) - 1 do
			local a = i / (lv >= 4 and 3 or 2) * math.pi * 2
			r:Ball(hub, 0.3, CF(math.cos(a) * 0.95, 0, math.sin(a) * 0.95), P.NeonSoft, M.Neon)
		end
	end
	if lv >= 3 then
		for i = 0, 2 do
			r:Neon(T, V(0.22, 0.22, 0.06), CF(-0.6 + i * 0.6, -1.9 - (i % 2) * 0.35, -0.67) * ANG(0, 0, rad(45)), P.Neon)
		end
	end
end

function Details.VoidKnight(r, lv)
	local T, H, RA, LA, RL, LL = r.Torso, r.Head, r.RArm, r.LArm, r.RLeg, r.LLeg
	r:Box(T, V(2.25, 0.24, 1.29), CF(0, -0.55, 0), P.Coal)
	r:Neon(T, V(0.4, 0.28, 0.08), CF(0, -0.55, -0.66), P.Neon)
	for _, x in ipairs({ -0.55, 0.55 }) do
		r:Box(T, V(0.8, 0.7, 0.15), CF(x, -1.32, -0.62) * ANG(rad(-8), 0, 0), P.Black, M.Metal) -- набедренники
	end
	for _, A in ipairs({ RA, LA }) do
		r:Box(A, V(1.14, 0.32, 1.14), CF(0, -1.05, 0), P.Steel, M.Metal) -- латные перчатки
	end
	for _, Lg in ipairs({ RL, LL }) do
		r:Box(Lg, V(0.7, 0.5, 0.3), CF(0, 0.05, -0.62), P.Steel, M.Metal) -- наколенники
	end
	for i = -1, 1 do
		r:Ball(RA, 0.16, CF(0.45 + i * 0.1, 1.05, -0.62 + i * 0.55), P.Gray, M.Metal) -- заклёпки
	end
	if lv >= 5 then
		r:Seg(H, V(-0.5, 0.6, -0.77), V(-0.2, 0.25, -0.77), 0.07, P.Neon, M.Neon)
		r:Seg(H, V(0.45, -0.5, -0.77), V(0.2, -0.2, -0.77), 0.07, P.Neon, M.Neon)
	end
end

function Details.DarkGunner(r, lv)
	local T, RL, LL = r.Torso, r.RLeg, r.LLeg
	r:Seg(T, V(-0.9, 0.95, -0.66), V(0.85, -0.7, -0.66), V2(0.3, 0.1), P.Maroon) -- патронташ
	for i = 1, 4 do
		local a = V(-0.9, 0.95, -0.72):Lerp(V(0.85, -0.7, -0.72), i / 5)
		r:Neon(T, V(0.16, 0.22, 0.08), CF(a), P.Neon)
	end
	r:Box(T, V(2.18, 0.25, 1.24), CF(0, -0.5, 0), P.Black)
	r:Pouch(T, CF(-0.7, -0.7, -0.66), P.Coal)
	r:Box(RL, V(0.3, 0.8, 0.5), CF(0.64, -0.05, 0), P.Coal) -- кобура
	r:Cyl(RL, 0.3, 0.2, CF(0.64, -0.6, -0.1), P.Steel, M.Metal, "Y")
	r:Box(RL, V(0.22, 0.35, 0.3), CF(0.64, 0.45, -0.05), P.Black)
	for _, Lg in ipairs({ RL, LL }) do
		r:Box(Lg, V(0.8, 0.45, 0.25), CF(0, 0.1, -0.6), P.Steel, M.Metal)
	end
	r:Cyl(T, 1.4, 0.08, CF(0.6, 1.4, 1.0), P.Steel, M.Metal, "Y") -- антенна
	local tip = r:Ball(T, 0.24, CF(0.6, 2.1, 1.0), lv >= 3 and P.NeonPink or P.Neon, M.Neon)
	if lv >= 4 then
		r:Glow(tip, P.NeonPink, 5, 1)
	end
end

function Details.AbyssReaper(r, lv)
	local T = r.Torso
	-- черепок на груди
	r:Sphere(T, V(0.55, 0.5, 0.35), CF(0, 0.45, -0.7), P.Pale)
	r:Ball(T, 0.14, CF(-0.12, 0.5, -0.86), P.Black)
	r:Ball(T, 0.14, CF(0.12, 0.5, -0.86), P.Black)
	-- фонарь душ
	r:Seg(T, V(-1.0, -0.6, -0.3), V(-1.05, -0.9, -0.3), 0.08, P.Steel, M.Metal)
	r:Cyl(T, 0.12, 0.5, CF(-1.1, -0.92, -0.3), P.Coal, M.Metal, "Y")
	r:Cyl(T, 0.12, 0.5, CF(-1.1, -1.48, -0.3), P.Coal, M.Metal, "Y")
	r:Cyl(T, 0.5, 0.42, CF(-1.1, -1.2, -0.3), P.Coal, M.Glass, "Y", { Transparency = 0.5 })
	local soul = r:Ball(T, 0.32, CF(-1.1, -1.2, -0.3), P.NeonSoft, M.Neon)
	r:Glow(soul, P.NeonSoft, 6, 1)
	-- цепи
	for i = 0, 3 do
		r:Box(T, V(0.18, 0.28, 0.08), CF(0.6, -1.0 - i * 0.3, -0.68) * ANG(0, 0, rad(i % 2 == 0 and 0 or 90)), P.Steel, M.Metal)
	end
	if lv >= 3 then
		local hub = r:Orbit("OrbitSouls", T, CF(0, 0.6, 0), 2.3, 0, 0.35, P.NeonSoft)
		local n = lv >= 5 and 5 or 3
		for i = 0, n - 1 do
			local a = i / n * math.pi * 2
			local c = CF(math.cos(a) * 2.3, math.sin(a * 2) * 0.2, math.sin(a) * 2.3)
			r:Ball(hub, 0.42, c, P.NeonSoft, M.Neon, { Transparency = 0.2 })
			r:Sphere(hub, V(0.25, 0.25, 0.7), c * CF(0, 0, 0.45), P.Neon, M.Neon, { Transparency = 0.5 }) -- хвост души
		end
	end
end

function Details.CorruptedSamurai(r, lv)
	local T, H, RA, LA, RL, LL = r.Torso, r.Head, r.RArm, r.LArm, r.RLeg, r.LLeg
	r:Box(T, V(2.2, 0.32, 1.22), CF(0, -0.95, 0), P.Crimson, M.Fabric) -- оби
	r:Box(T, V(0.6, 0.4, 0.3), CF(0.2, -0.95, 0.72), P.Crimson, M.Fabric)
	r:Sphere(H, V(0.45, 0.55, 0.45), CF(0, 0.95, 0.6) * ANG(rad(-25), 0, 0), P.Black) -- пучок волос
	for _, A in ipairs({ RA, LA }) do
		r:Box(A, V(1.08, 0.55, 1.08), CF(0, -0.55, 0), P.Maroon, M.Fabric)
		r:Box(A, V(1.1, 0.08, 1.1), CF(0, -0.3, 0), P.Gold, M.Metal)
	end
	for _, Lg in ipairs({ RL, LL }) do
		r:Box(Lg, V(1.04, 0.9, 0.2), CF(0, -0.4, -0.55), P.Black, M.Metal) -- сунэатэ
		r:Box(Lg, V(1.06, 0.08, 0.22), CF(0, -0.05, -0.56), P.Gold, M.Metal)
		r:Box(Lg, V(1.05, 0.12, 1.2), CF(0, -1.0, -0.05), P.Pale) -- сандалии
	end
	if lv >= 3 then
		-- сасимоно (флаг на спине)
		r:Cyl(T, 3.2, 0.12, CF(0.55, 1.6, 0.65), P.Black, M.Plastic, "Y")
		r:Ball(T, 0.22, CF(0.55, 3.25, 0.65), P.Gold, M.Metal)
		local flag = r:Box(T, V(0.06, 1.6, 0.9), CF(0.55, 2.4, 0.2), P.Crimson, M.Fabric)
		r:Neon(flag, V(0.08, 0.6, 0.2), CF(0, 0.1, 0), P.Neon)
	end
end

function Details.EclipseGuardian(r, lv)
	local T, RA, LA = r.Torso, r.RArm, r.LArm
	r:Box(T, V(2.64, 0.3, 1.54), CF(0, -0.8, 0), P.Coal, M.Metal)
	for _, x in ipairs({ -0.7, 0, 0.7 }) do
		r:Box(T, V(0.6, 0.8, 0.15), CF(x, -1.3, -0.78) * ANG(rad(-6), 0, 0), P.Black, M.Metal)
	end
	-- эмблема затмения
	r:Add(T, "Part", V(0.1, 1.0, 1.0), CF(0, 0.75, -0.83) * ANG(0, rad(90), 0), P.Neon, M.Neon, { Shape = Enum.PartType.Cylinder })
	r:Add(T, "Part", V(0.12, 0.75, 0.75), CF(0.08, 0.78, -0.85) * ANG(0, rad(90), 0), P.Black, M.Plastic, { Shape = Enum.PartType.Cylinder })
	if lv >= 3 then
		for _, A in ipairs({ RA, LA }) do
			r:Neon(A, V(1.24, 0.12, 1.24), CF(0, -0.95, 0), P.Neon)
		end
	end
	if lv >= 2 then
		r:Orbit("OrbitEclipse", r.Head, CF(0, 0.2, 1.0) * ANG(rad(90), 0, 0), 1.3, 8, 0.25, P.Neon)
	end
end

function Details.FallenAngel(r, lv)
	local T, H, RA, LA, RL, LL = r.Torso, r.Head, r.RArm, r.LArm, r.RLeg, r.LLeg
	r:Seg(T, V(-0.9, 0.9, -0.6), V(0.8, -0.5, -0.6), 0.14, P.DarkGold, M.Metal)
	r:Seg(T, V(0.9, 0.9, -0.6), V(-0.8, -0.5, -0.6), 0.14, P.DarkGold, M.Metal)
	r:Box(T, V(2.24, 0.22, 1.28), CF(0, -0.85, 0), P.DarkGold, M.Metal)
	r:Box(T, V(0.8, 1.2, 0.08), CF(0, -1.55, -0.66), P.White, M.Fabric)
	for _, A in ipairs({ RA, LA }) do
		r:Box(A, V(1.08, 0.4, 1.08), CF(0, -0.75, 0), P.Black, M.Metal)
		r:Box(A, V(1.1, 0.08, 1.1), CF(0, -0.55, 0), P.DarkGold, M.Metal)
	end
	-- второй ряд перьев
	for _, name in ipairs({ "WingR", "WingL" }) do
		local wing = r.Model:FindFirstChild(name)
		local side = name == "WingR" and 1 or -1
		if wing then
			for i = 1, 3 do
				local x = (-0.9 + i * 0.6) * side * (wing.Size.X / 3)
				r:Box(wing, V(0.45, 1.0 + i * 0.2, 0.15), CF(x, -0.5, -0.12) * ANG(0, 0, rad(-8 * side)), P.Coal)
			end
		end
	end
	if lv >= 4 then
		local hub = r:Orbit("OrbitHalo", H, CF(0, 1.25, 0.15), 1.25, 0, 0.18, P.White)
		for i = 0, 3 do
			local a = i / 4 * math.pi * 2
			r:Ball(hub, 0.24, CF(math.cos(a) * 1.25, 0, math.sin(a) * 1.25), P.White, M.Neon)
		end
	end
	if lv >= 5 then
		for _, Lg in ipairs({ RL, LL }) do
			r:Neon(Lg, V(1.1, 0.1, 1.14), CF(0, -1.0, 0), P.NeonSoft)
		end
	end
end

function Details.VoidEmperor(r, lv)
	local T, H, RA, LA = r.Torso, r.Head, r.RArm, r.LArm
	r:Seg(T, V(-0.95, 0.95, -0.7), V(0.85, -0.75, -0.7), V2(0.35, 0.08), P.Crimson, M.Fabric) -- лента
	r:Box(T, V(2.32, 0.25, 1.34), CF(0, -0.75, 0), P.Black)
	r:Box(T, V(0.5, 0.4, 0.1), CF(0, -0.75, -0.7), P.Gold, M.Metal)
	r:Neon(T, V(0.25, 0.25, 0.06), CF(0, 0.95, -0.72) * ANG(0, 0, rad(45)), P.NeonPink) -- кулон
	for _, A in ipairs({ RA, LA }) do
		r:Box(A, V(1.14, 0.25, 1.14), CF(0, -0.95, 0), P.Gold, M.Metal)
	end
	if lv >= 3 then
		local hub = r:Orbit("OrbitCrown", H, CF(0, 1.6, 0), 1.5, 0, 0.28, P.NeonPink)
		for i = 0, 4 do
			local a = i / 5 * math.pi * 2
			r:Wedge(hub, V(0.2, 0.5, 0.3), CF(math.cos(a) * 1.5, 0, math.sin(a) * 1.5) * ANG(0, -a, 0), P.NeonPink, M.Neon)
		end
	end
end

function Details.AbyssOverlord(r, lv)
	local T, RL, LL = r.Torso, r.RLeg, r.LLeg
	for i = 0, 2 do
		r:Wedge(T, V(0.35, 0.9 - i * 0.15, 0.7), CF(0, 1.0 - i * 0.7, 1.05) * ANG(rad(-25), 0, 0), P.Steel, M.Metal) -- шипы на спине
	end
	for _, x in ipairs({ -0.35, -0.12, 0.12, 0.35 }) do
		r:Cyl(T, 1.0, 0.09, CF(x, 0.35, -1.12), P.Steel, M.Metal, "Y") -- клетка кристалла
	end
	for i = -3, 3 do
		r:Box(T, V(0.3, 0.2, 0.15), CF(i * 0.36, -0.9, -0.8) * ANG(0, 0, rad(i % 2 == 0 and 0 or 90)), P.Steel, M.Metal) -- цепь
	end
	for _, Lg in ipairs({ RL, LL }) do
		r:Seg(Lg, V(-0.3, 0.3, -0.64), V(0.2, -0.5, -0.64), 0.08, P.Neon, M.Neon)
	end
	if lv >= 2 then
		r:Orbit("OrbitRocks", T, CF(0, 0.3, 0), 3.0, lv >= 4 and 6 or 4, 0.55, P.Rock or P.Coal, M.Slate)
	end
end

------------------------------------------------------------------------
-- 1. VOID SOLDIER (Common)
------------------------------------------------------------------------
local function VoidSoldier(lv)
	local r = Rig.new({ Name = "VoidSoldier", Torso = P.Steel, Arm = P.Dark, Leg = P.Coal, Head = P.Coal })
	local T, H, RA, LA, RL, LL = r.Torso, r.Head, r.RArm, r.LArm, r.RLeg, r.LLeg
	-- нагрудник и пояс
	r:Box(T, V(2.1, 1.25, 0.25), CF(0, 0.3, -0.56), P.Dark, M.Metal)
	r:Box(T, V(2.06, 0.32, 1.1), CF(0, -0.78, 0), P.Violet)
	r:Neon(T, V(0.36, 0.3, 0.08), CF(0, -0.78, -0.58), P.Neon)
	-- шлем (чуть кривой)
	r:Box(H, V(1.46, 0.72, 1.46), CF(0, 0.36, 0) * ANG(0, 0, rad(-3)), P.Black, M.Metal)
	r:Box(H, V(1.44, 0.75, 0.26), CF(0, -0.25, 0.62), P.Black, M.Metal)
	r:Box(H, V(0.24, 1.12, 1.4), CF(-0.66, -0.1, 0.02), P.Black, M.Metal)
	r:Box(H, V(0.24, 0.96, 1.36), CF(0.66, -0.02, 0.02), P.Black, M.Metal)
	r:Box(H, V(0.22, 0.5, 0.18), CF(0, -0.15, -0.66), P.Black, M.Metal) -- наносник
	r:Wedge(H, V(0.18, 0.42, 0.95), CF(0.18, 0.92, 0.12), lv >= 3 and P.Purple or P.Steel)
	r:Eyes(P.Neon, { Y = 0.05, Spacing = 0.33, Size = V(0.26, 0.12, 0.06) })
	-- сапоги / перчатки
	r:Box(RL, V(1.06, 0.55, 1.15), CF(0, -0.75, -0.06), P.Black)
	r:Box(LL, V(1.06, 0.55, 1.15), CF(0, -0.75, -0.06), P.Black)
	r:Box(RA, V(1.08, 0.5, 1.08), CF(0, -0.78, 0), P.Black)
	r:Box(LA, V(1.08, 0.5, 1.08), CF(0, -0.78, 0), P.Black)
	-- меч
	r:Sword(RA, {
		Length = 2.8 + (lv >= 4 and 0.6 or 0),
		Width = 0.4,
		Blade = P.Purple,
		Edge = lv >= 2 and P.Neon or nil,
		Core = lv >= 4 and P.NeonSoft or nil,
		Guard = P.Black,
	})
	if lv >= 2 then
		r:Pauldron(RA, 1, 0.85, P.Black, P.Steel)
	end
	if lv >= 3 then
		r:Pauldron(LA, -1, 0.8, P.Steel, P.Black)
		r:Box(RL, V(1.04, 0.45, 0.2), CF(0, 0.15, -0.55), P.Dark, M.Metal)
		r:Box(LL, V(1.04, 0.45, 0.2), CF(0, 0.15, -0.55), P.Dark, M.Metal)
	end
	if lv >= 4 then
		r:Cape(1.8, 2.2, P.DeepViolet, true)
	end
	if lv >= 5 then
		r:Neon(T, V(0.55, 0.55, 0.08), CF(0, 0.35, -0.7) * ANG(0, 0, rad(45)), P.Neon)
		r:Neon(H, V(1.48, 0.08, 0.06), CF(0, 0.55, -0.74), P.Neon)
	end
	if not UnitModels.Lite then
		Details.VoidSoldier(r, lv)
	end
	levelAura(r, lv)
	return r:Finish(1, { RS = { 15, 0, 0 } })
end

------------------------------------------------------------------------
-- 2. SHADOW ARCHER (Common)
------------------------------------------------------------------------
local function ShadowArcher(lv)
	local r = Rig.new({ Name = "ShadowArcher", Torso = P.Coal, Arm = P.Coal, Leg = P.Black, Head = P.Black, HeadSize = V(1.25, 1.25, 1.25) })
	local T, H, RA, LA, RL, LL = r.Torso, r.Head, r.RArm, r.LArm, r.RLeg, r.LLeg
	local hood = lv >= 3 and P.Violet or P.DeepViolet
	-- капюшон: верх, бока, спина и висящий хвост
	r:Box(H, V(1.55, 0.26, 1.5), CF(0, 0.74, 0.02), hood, M.Fabric)
	r:Box(H, V(0.22, 1.42, 1.5), CF(-0.74, 0.02, 0.02), hood, M.Fabric)
	r:Box(H, V(0.22, 1.36, 1.46), CF(0.74, 0.05, 0.02), hood, M.Fabric)
	r:Box(H, V(1.55, 1.42, 0.22), CF(0, 0.02, 0.72), hood, M.Fabric)
	r:Wedge(H, V(0.9, 0.9, 1.2), CF(0.1, 0.62, 0.95) * ANG(rad(-25), 0, rad(4)), hood, M.Fabric)
	r:Box(H, V(1.3, 0.45, 0.1), CF(0, -0.38, -0.64), P.Black, M.Fabric) -- маска-повязка
	r:Eyes(P.Neon, { Y = 0.12, Spacing = 0.28, Size = V(0.24, 0.1, 0.06), Tilt = 8 })
	-- плащ на плечах, ремень, колчан
	r:Box(T, V(2.2, 0.5, 1.2), CF(0, 0.8, 0), hood, M.Fabric)
	r:Seg(T, V(-0.9, 0.9, -0.56), V(0.9, -0.9, -0.56), V2(0.25, 0.08), P.Maroon)
	local quiver = r:Cyl(T, 1.9, 0.65, CF(0.4, 0.2, 0.85) * ANG(0, 0, rad(-20)), P.Maroon, M.Fabric, "Y")
	r:Cyl(T, 0.12, 0.7, CF(0.4, 0.2, 0.85) * ANG(0, 0, rad(-20)) * CF(0, 0.85, 0), P.DarkGold, M.Metal, "Y")
	for i = 0, 2 do
		local base = CF(0.62 + i * 0.12, 1.3 - i * 0.05, 0.85 + (i - 1) * 0.1) * ANG(0, 0, rad(-20))
		r:Cyl(T, 0.5, 0.08, base, P.Coal, M.Plastic, "Y")
		r:Wedge(T, V(0.06, 0.25, 0.2), base * CF(0, 0.3, 0), P.Neon, M.Neon) -- оперение
	end
	-- лук в левой руке (вертикален в позе прицеливания)
	local s = lv >= 3 and 1.25 or 1
	local bowColor = lv >= 2 and P.Coal or P.Dark
	r:Cyl(LA, 0.6, 0.3, CF(0, -1.15, 0), P.Maroon, M.Fabric, "Z")
	r:Rod(LA, V(0, -1.3, -0.25), V(0, -1.0, -1.7 * s), 0.24, bowColor)
	r:Rod(LA, V(0, -1.3, 0.25), V(0, -1.0, 1.7 * s), 0.24, bowColor)
	r:Rod(LA, V(0, -1.0, -1.7 * s), V(0, -0.65, -2.0 * s), 0.18, bowColor)
	r:Rod(LA, V(0, -1.0, 1.7 * s), V(0, -0.65, 2.0 * s), 0.18, bowColor)
	r:Ball(LA, 0.26, CF(0, -1.0, -1.7 * s), bowColor)
	r:Ball(LA, 0.26, CF(0, -1.0, 1.7 * s), bowColor)
	r:Neon(LA, V(0.05, 0.05, 4.0 * s), CF(0, -0.62, 0), lv >= 4 and P.Neon or P.White)
	if lv >= 3 then
		r:Ball(LA, 0.32, CF(0, -0.62, -2.05 * s), P.Neon, M.Neon)
		r:Ball(LA, 0.32, CF(0, -0.62, 2.05 * s), P.Neon, M.Neon)
	end
	local muzzle = r:Box(LA, V(0.2, 0.2, 0.2), CF(0, -1.5, 0), P.Black, M.Plastic, { Transparency = 1, Name = "Muzzle" })
	r.Muzzle = muzzle
	-- ноги
	r:Box(RL, V(1.05, 0.5, 1.1), CF(0, -0.78, -0.05), P.Maroon)
	r:Box(LL, V(1.05, 0.5, 1.1), CF(0, -0.78, -0.05), P.Maroon)
	if lv >= 2 then
		r:Box(RA, V(1.06, 0.7, 1.06), CF(0, -0.55, 0), P.DeepViolet, M.Fabric)
		r:Box(LA, V(1.06, 0.7, 1.06), CF(0, -0.55, 0), P.DeepViolet, M.Fabric)
	end
	if lv >= 4 then
		r:Cape(2.0, 2.6, hood, true)
	end
	if lv >= 5 then
		r:Horn(H, 1, V(0.45, 0.8, 0.1), 0.6, P.Black)
		r:Horn(H, -1, V(-0.45, 0.8, 0.1), 0.6, P.Black)
		r:Glow(quiver, P.Neon, 6, 1)
	end
	r:Hands(P.Coal, M.Fabric)
	if not UnitModels.Lite then
		Details.ShadowArcher(r, lv)
	end
	levelAura(r, lv)
	return r:Finish(1, { LS = { 20, 0, 0 } })
end

------------------------------------------------------------------------
-- 3. LOST MAGE (Common)
------------------------------------------------------------------------
local function LostMage(lv)
	local r = Rig.new({ Name = "LostMage", Torso = P.DeepViolet, Arm = P.DeepViolet, Leg = P.Black, Head = P.Pale, RoundHead = true })
	local T, H, RA, LA = r.Torso, r.Head, r.RArm, r.LArm
	-- мантия до земли
	r:Box(T, V(2.2, 2.1, 1.3), CF(0, -2.0, 0), P.DeepViolet, M.Fabric)
	r:Wedge(T, V(2.2, 0.5, 0.4), CF(0, -2.8, -0.8) * ANG(0, math.pi, 0), P.DeepViolet, M.Fabric)
	r:Box(T, V(0.4, 3.1, 0.1), CF(0, -1.4, -0.66), lv >= 2 and P.Purple or P.Violet, M.Fabric)
	r:Box(T, V(2.1, 0.25, 1.1), CF(0, -0.7, 0), P.Maroon)
	-- рукава
	r:Box(RA, V(1.2, 0.8, 1.2), CF(0, -0.6, 0), P.Violet, M.Fabric)
	r:Box(LA, V(1.2, 0.8, 1.2), CF(0, -0.6, 0), P.Violet, M.Fabric)
	-- шляпа (кривая, классическая)
	r:Cyl(H, 0.16, 2.3, CF(0, 0.7, 0) * ANG(rad(-4), 0, rad(3)), P.Coal, M.Fabric, "Y") -- круглые поля
	r:Cyl(H, 0.6, 1.35, CF(0, 1.05, 0.05) * ANG(rad(-6), 0, rad(4)), P.Coal, M.Fabric, "Y")
	r:Cyl(H, 0.6, 1.0, CF(0.08, 1.58, 0.22) * ANG(rad(-14), 0, rad(9)), P.Coal, M.Fabric, "Y")
	r:Cyl(H, 0.55, 0.66, CF(0.22, 2.04, 0.48) * ANG(rad(-24), 0, rad(16)), P.Coal, M.Fabric, "Y")
	r:Cyl(H, 0.45, 0.36, CF(0.4, 2.38, 0.78) * ANG(rad(-38), 0, rad(24)), P.Coal, M.Fabric, "Y")
	r:Ball(H, 0.3, CF(0.52, 2.62, 1.0), lv >= 3 and P.Neon or P.Coal, lv >= 3 and M.Neon or M.Fabric)
	r:Cyl(H, 0.16, 1.4, CF(0, 0.85, 0.02) * ANG(rad(-5), 0, rad(3)), lv >= 5 and P.Neon or P.Violet, lv >= 5 and M.Neon or M.Fabric, "Y")
	r:Box(H, V(1.36, 0.42, 0.2), CF(0, -0.42, -0.6), P.Pale) -- борода-шарф
	r:Eyes(P.Neon, { Y = 0.12, Spacing = 0.3, Size = V(0.22, 0.22, 0.06) })
	-- посох (вертикальный в правой руке)
	local staffColor = lv >= 3 and P.Maroon or P.Coal
	r:Cyl(RA, 5, 0.26, CF(0, -0.5, -0.55), staffColor, M.Plastic, "Y")
	r:Cyl(RA, 0.3, 0.44, CF(0, 1.9, -0.55), P.Steel, M.Metal, "Y")
	r:Ball(RA, 0.34, CF(0, -3.0, -0.55), P.Steel, M.Metal)
	local cs = lv >= 3 and 0.75 or 0.5
	local crystal = r:Neon(RA, V(cs, cs * 1.4, cs), CF(0, 2.35 + cs * 0.3, -0.55) * ANG(0, rad(45), rad(12)), P.Neon)
	crystal.Name = "Crystal"
	r:Glow(crystal, P.Neon, 7, 1.4)
	local muzzle = r:Box(RA, V(0.2, 0.2, 0.2), CF(0, 2.6 + cs * 0.3, -0.55), P.Black, M.Plastic, { Transparency = 1, Name = "Muzzle" })
	r.Muzzle = muzzle
	if lv >= 2 then
		r:Rod(RA, V(-0.2, 1.8, -0.55), V(-0.5, 2.4, -0.55), 0.14, staffColor)
		r:Rod(RA, V(0.2, 1.8, -0.55), V(0.45, 2.5, -0.55), 0.14, staffColor)
	end
	if lv >= 3 then
		r:Box(T, V(2.25, 0.6, 1.3), CF(0, 0.75, 0), P.Violet, M.Fabric)
	end
	if lv >= 4 then
		r:Ball(LA, 0.55, CF(0, -1.6, -0.3), P.NeonSoft, M.Neon)
		r:Cape(1.9, 3.2, P.Coal, true)
	end
	r:Face({ Mood = "old", EyeY = 0.12, BrowColor = P.White, Mouth = false })
	r:Hands(P.Pale)
	r:WeaponTrail(RA, V(0, 2.0, -0.55), V(0, 3.0, -0.55), P.Neon)
	if not UnitModels.Lite then
		Details.LostMage(r, lv)
	end
	levelAura(r, lv)
	return r:Finish(1, { RS = { 10, 0, 0 }, LS = { 8, 0, 0 } })
end

------------------------------------------------------------------------
-- 4. VOID KNIGHT (Rare)
------------------------------------------------------------------------
local function VoidKnight(lv)
	local r = Rig.new({ Name = "VoidKnight", Torso = P.Coal, Arm = P.Coal, Leg = P.Coal, Head = P.Black, TorsoMat = M.Metal })
	local T, H, RA, LA, RL, LL = r.Torso, r.Head, r.RArm, r.LArm, r.RLeg, r.LLeg
	-- кираса
	r:Box(T, V(2.2, 1.6, 1.25), CF(0, 0.25, 0), P.Black, M.Metal)
	r:Box(T, V(2.1, 0.5, 1.15), CF(0, -0.8, 0), P.Dark, M.Metal)
	-- фиолетовые трещины
	r:Seg(T, V(-0.6, 0.8, -0.64), V(-0.2, 0.2, -0.64), 0.09, P.Neon, M.Neon)
	r:Seg(T, V(-0.2, 0.2, -0.64), V(-0.45, -0.3, -0.64), 0.09, P.Neon, M.Neon)
	r:Seg(T, V(0.5, 0.6, -0.64), V(0.25, -0.1, -0.64), 0.09, P.Neon, M.Neon)
	-- шлем (большой, с Т-визором)
	r:Cyl(H, 1.45, 1.6, CF(0, 0.0, 0), P.Black, M.Metal, "Y") -- шлем-ведро
	r:Sphere(H, V(1.6, 0.6, 1.6), CF(0, 0.72, 0), P.Black, M.Metal)
	r:Cyl(H, 0.14, 1.66, CF(0, 0.45, 0), P.Steel, M.Metal, "Y")
	r:Box(H, V(1.0, 0.12, 0.08), CF(0, 0.15, -0.81), P.Neon, M.Neon)
	r:Box(H, V(0.14, 0.5, 0.08), CF(0, -0.1, -0.81), P.Neon, M.Neon)
	r:Box(H, V(0.3, 0.35, 1.3), CF(0, 0.88, 0.05), P.Steel, M.Metal)
	r:Wedge(H, V(0.22, 0.7, 0.9), CF(0, 1.3, 0.4) * ANG(rad(-10), 0, 0), lv >= 3 and P.Crimson or P.Steel)
	-- наплечники (асимметрия: правый крупнее)
	local ps = lv >= 5 and 1.25 or 1
	r:Pauldron(RA, 1, 1.05 * ps, P.Black, P.Neon, 0, M.Neon)
	r:Sphere(RA, V(1.1, 0.7, 1.05) * ps, CF(0.2, 1.25 * ps, 0) * ANG(0, 0, rad(-14)), P.Steel, M.Metal)
	r:Pauldron(LA, -1, 0.95 * ps, P.Black, P.Steel)
	-- наручи и поножи
	r:Box(RA, V(1.1, 0.8, 1.1), CF(0, -0.55, 0), P.Black, M.Metal)
	r:Box(LA, V(1.1, 0.8, 1.1), CF(0, -0.55, 0), P.Black, M.Metal)
	r:Box(RL, V(1.1, 1.1, 1.12), CF(0, -0.45, 0), P.Black, M.Metal)
	r:Box(LL, V(1.1, 1.1, 1.12), CF(0, -0.45, 0), P.Black, M.Metal)
	-- длинный меч
	local blade = r:Sword(RA, {
		Length = 3.8 + (lv >= 4 and 0.7 or 0),
		Width = 0.55,
		Blade = lv >= 5 and P.Purple or P.Steel,
		Edge = P.Neon,
		Core = lv >= 3 and P.NeonSoft or nil,
		Guard = P.Black,
		GuardWidth = 1.4,
		Runes = lv >= 3 and 3 or 0,
	})
	if lv >= 2 then
		r:Cyl(LA, 0.22, 1.7, CF(-0.62, -0.6, 0), P.Dark, M.Metal, "X") -- круглый щит-наруч
		r:Cyl(LA, 0.16, 1.85, CF(-0.6, -0.6, 0), P.Steel, M.Metal, "X")
		r:Ball(LA, 0.4, CF(-0.76, -0.6, 0), P.Neon, M.Neon)
	end
	if lv >= 3 then
		r:Sparkles(blade, P.Neon, { Rate = 10, Size = 0.3 })
	end
	if lv >= 4 then
		r:Cape(2.1, 3.3, P.Maroon, true)
	end
	if lv >= 5 then
		r:Horn(H, 1, V(0.6, 0.55, 0.1), 0.8, P.Black)
		r:Horn(H, -1, V(-0.6, 0.55, 0.1), 0.8, P.Black)
	end
	if not UnitModels.Lite then
		Details.VoidKnight(r, lv)
	end
	levelAura(r, lv)
	return r:Finish(1.1, { RS = { 20, 0, 0 } })
end

------------------------------------------------------------------------
-- 5. DARK GUNNER (Rare)
------------------------------------------------------------------------
local function DarkGunner(lv)
	local r = Rig.new({ Name = "DarkGunner", Torso = P.Black, Arm = P.Coal, Leg = P.Black, Head = P.Skin, RoundHead = true })
	local T, H, RA, LA, RL, LL = r.Torso, r.Head, r.RArm, r.LArm, r.RLeg, r.LLeg
	-- броня
	r:Box(T, V(2.15, 1.4, 1.2), CF(0, 0.3, 0), P.Coal, M.Metal)
	r:Neon(T, V(0.1, 1.2, 0.08), CF(-0.5, 0.3, -0.62), P.Neon)
	r:Neon(T, V(0.1, 0.8, 0.08), CF(0.6, 0.5, -0.62), P.Neon)
	-- рюкзак-батарея
	r:Box(T, V(1.6, 1.8, 0.7), CF(0, 0.1, 0.85), P.Dark, M.Metal)
	local cell = r:Cyl(T, 1.2, 0.45, CF(0.4, 0.1, 1.2), P.Neon, M.Neon, "Y")
	r:Cyl(T, 1.2, 0.45, CF(-0.4, 0.1, 1.2), lv >= 3 and P.Neon or P.Purple, lv >= 3 and M.Neon or M.Plastic, "Y")
	for _, x in ipairs({ -0.4, 0.4 }) do
		r:Cyl(T, 0.12, 0.52, CF(x, 0.72, 1.2), P.Steel, M.Metal, "Y")
		r:Cyl(T, 0.12, 0.52, CF(x, -0.52, 1.2), P.Steel, M.Metal, "Y")
	end
	-- шапка-берет и визор
	r:Cyl(H, 0.4, 1.5, CF(0.05, 0.68, 0.05) * ANG(0, 0, rad(-8)), P.Coal, M.Fabric, "Y") -- берет
	r:Sphere(H, V(1.1, 0.4, 1.0), CF(-0.25, 0.9, 0) * ANG(0, 0, rad(-14)), P.Coal, M.Fabric)
	r:Box(H, V(0.3, 0.3, 0.12), CF(-0.35, 0.72, -0.72), P.Neon, M.Neon) -- кокарда
	r:Box(H, V(1.4, 0.32, 0.25), CF(0, 0.12, -0.68), P.Black, M.Metal)
	r:Neon(H, V(1.2, 0.16, 0.06), CF(0, 0.12, -0.82), P.Neon)
	r:Box(H, V(1.36, 0.45, 0.12), CF(0, -0.38, -0.62), P.Black, M.Fabric) -- маска
	-- сапоги
	r:Box(RL, V(1.08, 0.7, 1.15), CF(0, -0.7, -0.05), P.Coal, M.Metal)
	r:Box(LL, V(1.08, 0.7, 1.15), CF(0, -0.7, -0.05), P.Coal, M.Metal)
	-- большое энергетическое оружие (ствол по -Y руки)
	local gs = lv >= 4 and 1.2 or 1
	r:Box(RA, V(0.6, 1.9, 0.75) * gs, CF(0, -1.85, -0.15), P.Black, M.Metal)
	r:Box(RA, V(0.5, 0.6, 1.3), CF(0, -1.2, 0.35), P.Coal, M.Metal) -- приклад
	r:Neon(RA, V(0.64, 1.0, 0.12), CF(0, -1.9, -0.55), P.Neon)
	r:Cyl(RA, 1.0, 0.38, CF(0, -3.2 * gs + 0.2, -0.15), P.Dark, M.Metal, "Y")
	for i = 0, 2 do
		r:Cyl(RA, 0.08, 0.46, CF(0, -2.85 * gs - i * 0.22 + 0.2, -0.15), P.Steel, M.Metal, "Y") -- рёбра охлаждения
	end
	if lv >= 3 then
		r:Cyl(RA, 0.9, 0.3, CF(0, -3.1 * gs + 0.2, -0.55), P.Dark, M.Metal, "Y") -- второй ствол
		r:Cyl(RA, 0.7, 0.26, CF(0, -1.75, -0.82), P.Steel, M.Metal, "Y") -- прицел
		r:Cyl(RA, 0.06, 0.2, CF(0, -2.1, -0.82), P.NeonSoft, M.Neon, "Y")
	end
	local tip = r:Cyl(RA, 0.18, 0.44, CF(0, -3.75 * gs + 0.2, -0.15), P.NeonSoft, M.Neon, "Y")
	tip.Name = "Muzzle"
	r.Muzzle = tip
	if lv >= 2 then
		r:Pauldron(RA, 1, 0.8, P.Coal, P.Neon, 0, M.Neon)
		r:Pauldron(LA, -1, 0.75, P.Coal)
	end
	if lv >= 4 then
		r:Glow(cell, P.Neon, 8, 1.5)
	end
	if lv >= 5 then
		r:Neon(RA, V(0.7, 0.12, 0.85), CF(0, -2.4, -0.15), P.NeonPink)
		r:Box(T, V(0.6, 2.2, 0.15), CF(0.5, -0.3, 0.55) * ANG(0, 0, rad(10)), P.DeepViolet, M.Fabric)
	end
	r:Hands(P.Black)
	if not UnitModels.Lite then
		Details.DarkGunner(r, lv)
	end
	levelAura(r, lv)
	return r:Finish(1.05, { RS = { 75, 0, 0 }, LS = { 70, 0, -25 }, Neck = { 0, 0, 0 } })
end

------------------------------------------------------------------------
-- 6. ABYSS REAPER (Epic)
------------------------------------------------------------------------
local function AbyssReaper(lv)
	local r = Rig.new({ Name = "AbyssReaper", Torso = P.Black, Arm = P.Black, Leg = P.Black, Head = P.Black })
	local T, H, RA, LA = r.Torso, r.Head, r.RArm, r.LArm
	-- глубокий капюшон
	r:Box(H, V(1.6, 0.3, 1.65), CF(0, 0.78, 0.05), P.Coal, M.Fabric)
	r:Box(H, V(0.26, 1.55, 1.65), CF(-0.78, 0.0, 0.05), P.Coal, M.Fabric)
	r:Box(H, V(0.26, 1.5, 1.6), CF(0.79, 0.02, 0.05), P.Coal, M.Fabric)
	r:Box(H, V(1.6, 1.55, 0.26), CF(0, 0, 0.78), P.Coal, M.Fabric)
	r:Wedge(H, V(1.2, 0.9, 0.9), CF(0, 0.85, -0.6) * ANG(0, math.pi, 0), P.Coal, M.Fabric)
	r:Wedge(H, V(0.6, 1.2, 1.4), CF(-0.15, 0.6, 1.2) * ANG(rad(-35), 0, rad(-6)), P.Coal, M.Fabric)
	r:Eyes(lv >= 4 and P.NeonPink or P.Neon, { Y = 0.0, Spacing = 0.28, Size = V(0.2, 0.2, 0.06), Inset = 0.25 })
	-- рваная мантия
	r:Box(T, V(2.25, 0.7, 1.3), CF(0, 0.75, 0), P.Coal, M.Fabric)
	r:Box(T, V(2.2, 1.6, 1.25), CF(0, -1.55, 0), P.Black, M.Fabric)
	local lens = { 1.4, 0.9, 1.7, 1.1, 1.5 }
	for i = 1, 5 do
		local x = -1.0 + (i - 1) * 0.5
		r:Wedge(T, V(0.45, lens[i], 0.3), CF(x, -2.35 - lens[i] / 2 + 0.2, -0.5) * ANG(0, math.pi, math.pi), P.Black, M.Fabric)
		r:Wedge(T, V(0.45, lens[6 - i], 0.3), CF(x, -2.35 - lens[6 - i] / 2 + 0.2, 0.5) * ANG(0, 0, math.pi), P.Black, M.Fabric)
	end
	r:Box(RA, V(1.25, 1.0, 1.25), CF(0, -0.6, 0), P.Coal, M.Fabric)
	r:Box(LA, V(1.25, 1.0, 1.25), CF(0, -0.6, 0), P.Coal, M.Fabric)
	-- цепь на груди
	r:Seg(T, V(-0.9, 0.8, -0.66), V(0.8, -0.6, -0.66), 0.14, P.Steel, M.Metal)
	-- коса: древко вертикально в правой руке, лезвие наверху
	local pole = lv >= 3 and P.Maroon or P.Coal
	r:Cyl(RA, 6, 0.26, CF(0, 0.2, -0.55), pole, M.Plastic, "Y")
	for i = 0, 2 do
		r:Cyl(RA, 0.14, 0.32, CF(0, -1.5 + i * 1.6, -0.55), P.Steel, M.Metal, "Y") -- кольца на древке
	end
	local bl = lv >= 5 and 1.3 or 1
	local top = V(0, 3.15, -0.55)
	local bladePts = {
		top,
		top + V(0, 0.15, -1.0) * bl,
		top + V(0, -0.1, -2.0) * bl,
		top + V(0, -0.6, -2.8) * bl,
		top + V(0, -1.3, -3.2) * bl,
	}
	r:Chain(RA, bladePts, 0.45, P.Steel, M.Metal, 0.85)
	if lv >= 2 then
		local edge = {}
		for i, p in ipairs(bladePts) do
			edge[i] = p + V(0, -0.22, 0)
		end
		r:Chain(RA, edge, 0.12, P.Neon, M.Neon, 1)
	end
	r:Ball(RA, 0.55, CF(top), P.Black, M.Metal)
	local muzzle = r:Box(RA, V(0.2, 0.2, 0.2), CF(top + V(0, -0.6, -2.4) * bl), P.Black, M.Plastic, { Transparency = 1, Name = "Muzzle" })
	r.Muzzle = muzzle
	if lv >= 4 then
		r:Sparkles(muzzle, P.Neon, { Rate = 14, Size = 0.35 })
		r:Cape(2.2, 3.6, P.Black, true)
	end
	if lv >= 5 then
		local back = {}
		for i, p in ipairs(bladePts) do
			back[i] = V(p.X, p.Y - 0.2, -0.55 + (-0.55 - p.Z) * 0.5)
		end
		r:Chain(RA, back, 0.3, P.Steel, M.Metal, 0.8)
	end
	r:Hands(P.Pale)
	r:WeaponTrail(RA, top + V(0, -0.2, -0.6) * bl, top + V(0, -1.3, -3.2) * bl, P.Neon)
	if not UnitModels.Lite then
		Details.AbyssReaper(r, lv)
	end
	levelAura(r, lv)
	return r:Finish(1.15, { RS = { 8, 0, 0 } })
end

------------------------------------------------------------------------
-- 7. CORRUPTED SAMURAI (Epic)
------------------------------------------------------------------------
local function CorruptedSamurai(lv)
	local r = Rig.new({ Name = "CorruptedSamurai", Torso = P.Maroon, Arm = P.Black, Leg = P.Black, Head = P.Black })
	local T, H, RA, LA, RL, LL = r.Torso, r.Head, r.RArm, r.LArm, r.RLeg, r.LLeg
	-- до (нагрудник) пластинами
	for i = 0, 3 do
		r:Box(T, V(2.15, 0.36, 1.18), CF(0, 0.75 - i * 0.42, 0), i % 2 == 0 and P.Black or P.Maroon, M.Metal)
	end
	-- кусадзури (юбка из пластин)
	for i = -1, 1 do
		r:Box(T, V(0.68, 1.0, 0.18), CF(i * 0.7, -1.3, -0.6) * ANG(rad(-12), 0, rad(i * 4)), P.Maroon, M.Metal)
	end
	r:Box(T, V(0.9, 1.0, 0.18), CF(-0.55, -1.3, 0.6) * ANG(rad(12), 0, 0), P.Maroon, M.Metal)
	r:Box(T, V(0.9, 1.1, 0.18), CF(0.55, -1.35, 0.6) * ANG(rad(12), 0, 0), P.Black, M.Metal)
	-- соде (наплечники) разного размера
	r:Box(RA, V(1.4, 1.2, 1.3), CF(0.35, 0.55, 0) * ANG(0, 0, rad(-22)), P.Maroon, M.Metal)
	r:Box(RA, V(1.42, 0.18, 1.32), CF(0.4, 0.25, 0) * ANG(0, 0, rad(-22)), P.Black, M.Metal)
	r:Box(LA, V(1.25, 1.0, 1.2), CF(-0.3, 0.6, 0) * ANG(0, 0, rad(18)), P.Maroon, M.Metal)
	-- кабуто
	r:Sphere(H, V(1.6, 1.0, 1.6), CF(0, 0.6, 0), P.Black, M.Metal) -- купол кабуто
	r:Cyl(H, 0.14, 2.2, CF(0, 0.3, 0.1) * ANG(rad(-8), 0, rad(2)), P.Maroon, M.Metal, "Y") -- широкие круглые поля
	r:Ball(H, 0.3, CF(0, 1.12, 0), P.Gold, M.Metal)
	r:Wedge(H, V(0.4, 0.8, 0.7), CF(-0.95, 0.0, 0.3) * ANG(0, rad(-90), rad(10)), P.Maroon, M.Metal)
	r:Wedge(H, V(0.4, 0.7, 0.6), CF(0.95, 0.05, 0.3) * ANG(0, rad(90), rad(-8)), P.Maroon, M.Metal)
	-- маэдатэ (полумесяц на шлеме)
	r:Chain(H, { V(0, 0.75, -0.75), V(-0.45, 1.15, -0.8), V(-0.75, 1.75, -0.8) }, 0.16, P.Gold, M.Metal, 0.8, true)
	r:Chain(H, { V(0, 0.75, -0.75), V(0.4, 1.1, -0.8), V(0.6, 1.55, -0.8) }, 0.16, P.Gold, M.Metal, 0.8, true)
	r:Ball(H, 0.26, CF(0, 0.75, -0.77), P.Neon, M.Neon)
	-- демоническая маска
	r:Box(H, V(1.3, 0.85, 0.15), CF(0, -0.15, -0.7), P.Crimson)
	r:Wedge(H, V(0.15, 0.4, 0.2), CF(-0.35, -0.6, -0.78) * ANG(0, 0, math.pi), P.White)
	r:Wedge(H, V(0.15, 0.4, 0.2), CF(0.38, -0.62, -0.78) * ANG(0, 0, math.pi), P.White)
	r:Eyes(P.Neon, { Y = 0.05, Spacing = 0.3, Size = V(0.3, 0.12, 0.06), Tilt = -14, Inset = -0.08 })
	-- катана (тонкая и длинная, чуть изогнутая)
	local len = 3.6 + (lv >= 4 and 0.5 or 0)
	r:Cyl(RA, 1.1, 0.24, CF(0, -1.05, 0.05), P.Maroon, M.Fabric, "Z")
	r:Cyl(RA, 0.12, 0.6, CF(0, -1.05, -0.55), P.Gold, M.Metal, "Z") -- круглая цуба
	r:Seg(RA, V(0, -1.05, -0.6), V(0, -1.0, -0.6 - len * 0.55), V2(0.1, 0.3), P.Pale, M.Metal)
	r:Seg(RA, V(0, -1.0, -0.6 - len * 0.55), V(0, -0.8, -0.6 - len), V2(0.1, 0.27), P.Pale, M.Metal)
	r:Seg(RA, V(0, -0.88, -0.6), V(0, -0.65, -0.6 - len), V2(0.12, 0.07), lv >= 2 and P.Neon or P.White, M.Neon)
	local muzzle = r:Box(RA, V(0.2, 0.2, 0.2), CF(0, -0.85, -0.6 - len), P.Black, M.Plastic, { Transparency = 1, Name = "Muzzle" })
	r.Muzzle = muzzle
	-- ножны на поясе
	r:Rod(T, V(-1.05, -0.8, 0.4), V(-1.2, -1.2, -1.6), 0.28, P.Black) -- ножны
	if lv >= 3 then
		r:Horn(H, 1, V(0.55, 0.75, 0.1), 0.7, P.Crimson)
		r:Horn(H, -1, V(-0.55, 0.75, 0.1), 0.6, P.Crimson)
	end
	if lv >= 4 then
		r:Neon(T, V(0.1, 1.4, 0.06), CF(0.3, 0.2, -0.62) * ANG(0, 0, rad(20)), P.Neon)
		r:Sparkles(muzzle, P.Neon, { Rate = 8 })
	end
	if lv >= 5 then
		r:Cape(1.6, 3.0, P.Crimson, true)
		r:Rod(T, V(1.05, -0.8, 0.4), V(1.2, -1.2, -1.6), 0.24, P.Maroon) -- вторая катана
	end
	r:Hands(P.Black)
	r:WeaponTrail(RA, V(0, -0.95, -0.9), V(0, -0.8, -0.6 - len), lv >= 5 and P.NeonPink or P.Neon)
	if not UnitModels.Lite then
		Details.CorruptedSamurai(r, lv)
	end
	levelAura(r, lv, lv >= 5 and P.NeonPink or P.Neon)
	return r:Finish(1.1, { RS = { 25, 0, 0 }, LS = { 10, 0, 0 } })
end

------------------------------------------------------------------------
-- 8. ECLIPSE GUARDIAN (Legendary) — AOE
------------------------------------------------------------------------
local function EclipseGuardian(lv)
	local r = Rig.new({ Name = "EclipseGuardian", Torso = P.Black, Arm = P.Black, Leg = P.Black, Head = P.Black, HeadSize = V(1.4, 1.4, 1.4), TorsoMat = M.Metal })
	local T, H, RA, LA, RL, LL = r.Torso, r.Head, r.RArm, r.LArm, r.RLeg, r.LLeg
	-- массивная броня
	r:Box(T, V(2.6, 2.0, 1.5), CF(0, 0.15, 0), P.Black, M.Metal)
	r:Box(T, V(2.2, 0.6, 0.25), CF(0, 0.7, -0.8), P.Coal, M.Metal)
	r:Wedge(T, V(2.6, 0.6, 0.5), CF(0, -0.95, -0.6) * ANG(0, math.pi, math.pi), P.Coal, M.Metal)
	-- энергетические линии
	r:Neon(T, V(0.12, 1.8, 0.06), CF(0, 0.1, -0.78), P.Neon)
	r:Neon(T, V(1.8, 0.1, 0.06), CF(0, 0.35, -0.78), P.Neon)
	r:Seg(T, V(-1.2, 0.9, -0.78), V(-0.3, -0.7, -0.78), 0.08, P.Neon, M.Neon)
	r:Seg(T, V(1.2, 0.9, -0.78), V(0.35, -0.6, -0.78), 0.08, P.Neon, M.Neon)
	-- шлем с рогами
	r:Box(H, V(1.6, 1.6, 1.6), CF(0, 0.05, 0), P.Black, M.Metal)
	r:Box(H, V(1.2, 0.14, 0.08), CF(0, 0.05, -0.81), P.Neon, M.Neon)
	r:Box(H, V(0.3, 0.3, 1.7), CF(0, 0.85, 0), P.Coal, M.Metal)
	r:Horn(H, 1, V(0.75, 0.45, 0), 1.3, P.Coal)
	r:Horn(H, -1, V(-0.75, 0.45, 0), 1.15, P.Coal)
	-- огромные наплечники
	r:Pauldron(RA, 1, 1.25, P.Black, P.Neon, 0.1, M.Neon)
	r:Sphere(RA, V(1.3, 0.8, 1.25), CF(0.25, 1.45, 0) * ANG(0, 0, rad(-16)), P.Coal, M.Metal)
	r:Wedge(RA, V(0.35, 0.8, 0.6), CF(0.45, 1.95, 0) * ANG(0, rad(90), rad(-20)), P.Steel, M.Metal)
	r:Pauldron(LA, -1, 1.18, P.Black, P.Steel, 0.1)
	r:Sphere(LA, V(1.2, 0.75, 1.15), CF(-0.25, 1.4, 0) * ANG(0, 0, rad(16)), P.Coal, M.Metal)
	r:Box(RA, V(1.2, 1.0, 1.2), CF(0, -0.5, 0), P.Coal, M.Metal)
	r:Box(LA, V(1.2, 1.0, 1.2), CF(0, -0.5, 0), P.Coal, M.Metal)
	r:Box(RL, V(1.15, 1.3, 1.2), CF(0, -0.35, 0), P.Coal, M.Metal)
	r:Box(LL, V(1.15, 1.3, 1.2), CF(0, -0.35, 0), P.Coal, M.Metal)
	-- тёмный плащ
	r:Cape(2.5, 4.0, P.DeepViolet, true)
	-- огромный меч
	local blade = r:Sword(RA, {
		Length = 5.2 + (lv >= 4 and 0.8 or 0),
		Width = 1.0 + (lv >= 5 and 0.2 or 0),
		Blade = P.Coal,
		Edge = P.Neon,
		Core = P.Neon,
		Guard = P.Black,
		GuardWidth = 2.2,
		Runes = 2 + lv,
		Gem = P.NeonSoft,
	})
	if lv >= 2 then
		r:Neon(LL, V(0.08, 1.0, 0.06), CF(0.2, -0.3, -0.62), P.Neon)
		r:Neon(RL, V(0.08, 1.0, 0.06), CF(-0.2, -0.3, -0.62), P.Neon)
	end
	if lv >= 3 then
		r:Neon(H, V(0.3, 0.3, 0.06), CF(0, 0.55, -0.82) * ANG(0, 0, rad(45)), P.NeonSoft)
		r:Glow(blade, P.Neon, 10, 1.5)
	end
	if lv >= 4 then
		r:Sparkles(blade, P.Neon, { Rate = 16, Size = 0.4 })
	end
	if lv >= 5 then
		r:Horn(H, 1, V(0.5, 0.75, 0.3), 0.8, P.Neon)
		r:Horn(H, -1, V(-0.5, 0.75, 0.3), 0.8, P.Neon)
	end
	if not UnitModels.Lite then
		Details.EclipseGuardian(r, lv)
	end
	levelAura(r, lv)
	return r:Finish(1.3, { RS = { 30, 0, 0 } })
end

------------------------------------------------------------------------
-- 9. FALLEN ANGEL (Legendary) — single target
------------------------------------------------------------------------
local function FallenAngel(lv)
	local r = Rig.new({ Name = "FallenAngel", Torso = P.Coal, Arm = P.Coal, Leg = P.Black, Head = P.Pale, RoundHead = true })
	local T, H, RA, LA, RL, LL = r.Torso, r.Head, r.RArm, r.LArm, r.RLeg, r.LLeg
	r:Box(T, V(2.15, 1.4, 1.15), CF(0, 0.35, 0), P.Black, M.Metal)
	r:Neon(T, V(0.5, 0.5, 0.06), CF(0, 0.4, -0.6) * ANG(0, 0, rad(45)), P.Neon)
	r:Box(T, V(2.2, 1.2, 1.25), CF(0, -1.5, 0), P.Black, M.Fabric)
	r:Pauldron(RA, 1, 0.85, P.Black, P.DarkGold)
	r:Pauldron(LA, -1, 0.85, P.Black, P.DarkGold)
	r:Box(RL, V(1.08, 0.6, 1.12), CF(0, -0.72, 0), P.Coal, M.Metal)
	r:Box(LL, V(1.08, 0.6, 1.12), CF(0, -0.72, 0), P.Coal, M.Metal)
	-- волосы / шлем
	r:Box(H, V(1.4, 0.4, 1.4), CF(0, 0.55, 0.05), P.White)
	r:Box(H, V(1.4, 1.1, 0.35), CF(0, 0.05, 0.55), P.White)
	r:Wedge(H, V(0.4, 0.8, 0.6), CF(-0.6, 0.35, -0.35) * ANG(0, 0, rad(10)), P.White)
	r:Eyes(P.Neon, { Y = 0.05, Spacing = 0.3, Size = V(0.26, 0.12, 0.06) })
	-- нимб
	local halo = {}
	local segs = 10
	local hr = 0.85
	for i = 0, segs - 1 do
		local a1 = (i / segs) * math.pi * 2
		local a2 = ((i + 1) / segs) * math.pi * 2
		halo[#halo + 1] = r:Rod(H, V(math.cos(a1) * hr, 1.25, math.sin(a1) * hr + 0.15), V(math.cos(a2) * hr, 1.25, math.sin(a2) * hr + 0.15), 0.15, lv >= 3 and P.NeonSoft or P.White, M.Neon)
	end
	r:Glow(halo[1], P.NeonSoft, 7, 1)
	-- чёрные блочные крылья на моторах
	local ws = lv >= 4 and 1.25 or 1
	for _, side in ipairs({ 1, -1 }) do
		local name = side == 1 and "WingR" or "WingL"
		local wing = r:Joint(name, T, V(3.0 * ws, 0.5, 0.3), CF(0.35 * side, 0.6, 0.55), CF(1.5 * ws * side, 0.55, 0.15) * ANG(0, 0, rad(20 * side)), P.Black)
		for i = 1, 4 do
			local len = (2.6 - i * 0.35) * ws
			local x = (-1.3 + i * 0.6) * ws * side
			r:Box(wing, V(0.55 * ws, len, 0.2), CF(x, -len / 2 + 0.1, 0.05) * ANG(0, 0, rad(-12 * side)), i % 2 == 0 and P.Coal or P.Black)
		end
		if lv >= 2 then
			r:Neon(wing, V(2.8 * ws, 0.08, 0.32), CF(0, 0.26, 0), P.Neon)
		end
	end
	-- копьё (вертикально в правой руке)
	local sl = lv >= 5 and 1.2 or 1
	r:Cyl(RA, 6.2 * sl, 0.24, CF(0, 0.3, -0.55), P.Black, M.Metal, "Y")
	r:Cyl(RA, 0.25, 0.5, CF(0, 3.1 * sl + 0.2, -0.55), P.DarkGold, M.Metal, "Y")
	r:Ball(RA, 0.4, CF(0, -2.8 * sl, -0.55), P.DarkGold, M.Metal)
	local tip = r:Neon(RA, V(0.35, 1.6 * sl, 0.12), CF(0, 4.1 * sl + 0.2, -0.55), P.Neon)
	r:Wedge(RA, V(0.12, 0.6, 0.35), CF(0, 5.2 * sl, -0.55) * ANG(0, rad(90), 0), P.Neon, M.Neon)
	tip.Name = "Muzzle"
	r.Muzzle = tip
	if lv >= 3 then
		r:Rod(RA, V(-0.5, 3.1 * sl, -0.55), V(-0.2, 3.6 * sl, -0.55), 0.14, P.Neon, M.Neon)
		r:Rod(RA, V(0.5, 3.1 * sl, -0.55), V(0.2, 3.6 * sl, -0.55), 0.14, P.Neon, M.Neon)
	end
	if lv >= 4 then
		r:Glow(tip, P.Neon, 10, 2)
	end
	if lv >= 5 then
		r:Cape(1.8, 3.4, P.Black, true)
	end
	r:Face({ Mood = "calm", EyeY = 0.05, BrowColor = P.Coal })
	r:Hands(P.Coal)
	r:WeaponTrail(RA, V(0, 3.0 * sl, -0.55), V(0, 5.2 * sl, -0.55), P.NeonSoft)
	if not UnitModels.Lite then
		Details.FallenAngel(r, lv)
	end
	levelAura(r, lv, P.NeonSoft)
	return r:Finish(1.25, { RS = { 10, 0, 0 } })
end

------------------------------------------------------------------------
-- 10. VOID EMPEROR (Mythic)
------------------------------------------------------------------------
local function VoidEmperor(lv)
	local r = Rig.new({ Name = "VoidEmperor", Torso = P.DeepViolet, Arm = P.DeepViolet, Leg = P.Coal, Head = P.Pale, TorsoMat = M.Metal, RoundHead = true })
	local T, H, RA, LA, RL, LL = r.Torso, r.Head, r.RArm, r.LArm, r.RLeg, r.LLeg
	-- королевская броня
	r:Box(T, V(2.3, 1.7, 1.3), CF(0, 0.2, 0), P.Violet, M.Metal)
	r:Box(T, V(0.5, 1.7, 0.1), CF(0, 0.2, -0.68), P.DarkGold, M.Metal)
	r:Neon(T, V(0.4, 0.4, 0.06), CF(0, 0.5, -0.75) * ANG(0, 0, rad(45)), P.NeonPink)
	r:Box(T, V(2.25, 1.6, 1.3), CF(0, -1.7, 0), P.DeepViolet, M.Fabric)
	r:Box(T, V(2.27, 0.2, 1.32), CF(0, -2.4, 0), P.DarkGold, M.Metal)
	-- наплечники с шипами
	r:Pauldron(RA, 1, 1.0, P.Violet, P.Gold)
	r:Pauldron(LA, -1, 1.0, P.Violet, P.Gold)
	r:Wedge(RA, V(0.25, 0.8, 0.5), CF(0.45, 1.45, 0) * ANG(0, rad(90), 0), P.DarkGold, M.Metal)
	r:Wedge(LA, V(0.25, 0.7, 0.5), CF(-0.45, 1.4, 0) * ANG(0, rad(-90), 0), P.DarkGold, M.Metal)
	r:Box(RA, V(1.1, 0.7, 1.1), CF(0, -0.65, 0), P.Black, M.Metal)
	r:Box(LA, V(1.1, 0.7, 1.1), CF(0, -0.65, 0), P.Black, M.Metal)
	-- лицо / борода / глаза
	r:Box(H, V(1.36, 0.5, 0.2), CF(0, -0.45, -0.6), P.White)
	r:Eyes(P.NeonPink, { Y = 0.1, Spacing = 0.3, Size = V(0.28, 0.12, 0.06), Tilt = -6 })
	-- огромная корона
	local cs = lv >= 3 and 1.15 or 1
	r:Cyl(H, 0.55, 1.85, CF(0, 0.85, 0), P.Gold, M.Metal, "Y") -- круглая корона
	r:Cyl(H, 0.12, 1.95, CF(0, 0.62, 0), P.DarkGold, M.Metal, "Y")
	local spikes = { { -0.7, 1.2, -0.7 }, { 0, 1.7, -0.75 }, { 0.7, 1.3, -0.7 }, { -0.75, 1.1, 0.7 }, { 0.72, 1.4, 0.7 }, { 0, 1.0, 0.75 } }
	for i, s in ipairs(spikes) do
		local h = s[2] * cs
		r:Wedge(H, V(0.34, h, 0.34), CF(s[1], 1.1 + h / 2, s[3]) * ANG(0, s[3] > 0 and 0 or math.pi, rad(s[1] * -10)), P.Gold, M.Metal)
		if i <= 3 or lv >= 4 then
			r:Ball(H, 0.34, CF(s[1], 1.15 + h, s[3]), i == 2 and P.NeonPink or P.Neon, M.Neon)
		end
	end
	r:Neon(H, V(0.35, 0.35, 0.08), CF(0, 0.85, -0.9) * ANG(0, 0, rad(45)), P.NeonPink)
	-- плащ с частицами
	local cape = r:Cape(2.4, 4.2, P.Maroon, true)
	r:Sphere(T, V(2.7, 0.7, 1.5), CF(0, 0.95, 0.1), P.Crimson, M.Fabric) -- меховой воротник
	r:Sparkles(cape, P.NeonPink, { Rate = 8, Size = 0.3 })
	-- большой меч с красно-фиолетовым свечением
	local blade = r:Sword(RA, {
		Length = 4.8 + (lv >= 4 and 0.8 or 0),
		Width = 0.75,
		Blade = P.Coal,
		Edge = P.NeonPink,
		Core = P.Neon,
		Guard = P.Gold,
		GuardWidth = 1.8,
		Runes = lv >= 2 and 4 or 2,
		Gem = P.NeonPink,
	})
	r:Glow(blade, P.NeonPink, 9, 1.4)
	if lv >= 2 then
		r:Box(RL, V(1.1, 0.8, 1.15), CF(0, -0.6, 0), P.Black, M.Metal)
		r:Box(LL, V(1.1, 0.8, 1.15), CF(0, -0.6, 0), P.Black, M.Metal)
	end
	if lv >= 3 then
		r:Sparkles(blade, P.NeonPink, { Rate = 14, Size = 0.35 })
	end
	if lv >= 5 then
		for i = 0, 2 do
			local a = rad(-40 + i * 40)
			r:Neon(T, V(0.15, 1.6, 0.15), CF(math.sin(a) * 1.4, 2.6 + math.cos(a) * 0.4, 0.9) * ANG(0, 0, -a), P.NeonPink)
		end
	end
	r:Face({ Mood = "angry", EyeY = 0.1, BrowColor = P.Black, Mouth = false })
	r:Hands(P.Black, M.Metal)
	if not UnitModels.Lite then
		Details.VoidEmperor(r, lv)
	end
	levelAura(r, lv, P.NeonPink)
	return r:Finish(1.4, { RS = { 15, 0, 0 } })
end

------------------------------------------------------------------------
-- 11. ABYSS OVERLORD (Mythic)
------------------------------------------------------------------------
local function AbyssOverlord(lv)
	local r = Rig.new({ Name = "AbyssOverlord", Torso = P.Black, Arm = P.Black, Leg = P.Black, Head = P.Black, HeadSize = V(1.35, 1.35, 1.35), TorsoMat = M.Metal })
	local T, H, RA, LA, RL, LL = r.Torso, r.Head, r.RArm, r.LArm, r.RLeg, r.LLeg
	-- массивный торс
	r:Box(T, V(3.0, 2.3, 1.7), CF(0, 0.25, 0), P.Black, M.Metal)
	r:Box(T, V(2.4, 0.5, 1.5), CF(0, -0.9, 0), P.Coal, M.Metal)
	r:Box(T, V(1.1, 1.1, 0.3), CF(0, 0.35, -0.9), P.Coal, M.Metal)
	local crystal = r:Neon(T, V(0.8, 0.8, 0.5), CF(0, 0.35, -1.0) * ANG(0, 0, rad(45)), P.Neon)
	crystal.Name = "Crystal"
	r:Glow(crystal, P.Neon, 12, 2)
	for i = -1, 1, 2 do
		r:Seg(T, V(i * 0.5, 0.35, -0.92), V(i * 1.3, 1.0, -0.88), 0.1, P.Neon, M.Neon)
		r:Seg(T, V(i * 0.5, 0.2, -0.92), V(i * 1.1, -0.6, -0.88), 0.1, P.Neon, M.Neon)
	end
	-- голова с рогами
	r:Box(H, V(1.45, 1.2, 1.45), CF(0, 0, 0), P.Black, M.Metal)
	r:Box(H, V(1.5, 0.4, 0.3), CF(0, 0.15, -0.7), P.Coal, M.Metal)
	r:Eyes(P.Neon, { Y = -0.1, Spacing = 0.32, Size = V(0.3, 0.14, 0.06), Tilt = -12, Inset = -0.12 })
	r:Horn(H, 1, V(0.65, 0.4, 0), 1.7, P.Coal)
	r:Horn(H, -1, V(-0.65, 0.4, 0), 1.5, P.Coal)
	if lv >= 3 then
		r:Horn(H, 1, V(0.4, 0.6, 0.4), 1.0, P.Black)
		r:Horn(H, -1, V(-0.4, 0.6, 0.4), 1.0, P.Black)
	end
	-- огромные руки
	for _, A in ipairs({ RA, LA }) do
		local s = A == RA and 1 or -1
		r:Sphere(A, V(2.0, 1.4, 1.9), CF(0.2 * s, 0.85, 0) * ANG(0, 0, rad(-12 * s)), P.Coal, M.Metal) -- огромные наплечники
		r:Box(A, V(1.8, 1.6, 1.8), CF(0, -0.6, 0), P.Black, M.Metal)
		r:Cyl(A, 0.7, 2.0, CF(0, -1.3, 0), P.Coal, M.Metal, "Y") -- кулаки-латы
		for k = -1, 1 do
			r:Wedge(A, V(0.3, 0.5, 0.45), CF(k * 0.55, -1.75, -0.7) * ANG(0, math.pi, math.pi), P.Steel, M.Metal) -- когти
		end
		r:Neon(A, V(0.08, 1.2, 0.08), CF(0.6 * s, -0.6, -0.92), P.Neon)
		r:Wedge(A, V(0.3, 0.8, 0.6), CF(0.65 * s, 1.35, 0) * ANG(0, rad(90 * s), 0), P.Steel, M.Metal) -- шипы
	end
	r.Muzzle = r:Box(RA, V(0.2, 0.2, 0.2), CF(0, -1.9, -0.4), P.Black, M.Plastic, { Transparency = 1, Name = "Muzzle" })
	r:Box(RL, V(1.2, 1.4, 1.25), CF(0, -0.3, 0), P.Coal, M.Metal)
	r:Box(LL, V(1.2, 1.4, 1.25), CF(0, -0.3, 0), P.Coal, M.Metal)
	if lv >= 2 then
		r:Cape(2.7, 3.6, P.DeepViolet, true)
	end
	if lv >= 4 then
		r:Sparkles(crystal, P.Neon, { Rate = 16, Size = 0.4 })
		for i = -1, 1, 2 do
			r:Wedge(T, V(0.4, 1.1, 0.8), CF(i * 0.8, 1.8, 0.6) * ANG(rad(-20), 0, rad(-15 * i)), P.Steel, M.Metal)
		end
	end
	if lv >= 5 then
		local orbit = r:Ball(T, 0.7, CF(1.9, 2.4, 0.3), P.Neon, M.Neon)
		r:Ball(T, 0.55, CF(-1.9, 2.1, 0.5), P.Neon, M.Neon)
		r:Glow(orbit, P.Neon, 8, 1)
	end
	r:WeaponTrail(RA, V(0, -0.9, 0), V(0, -1.9, -0.2), P.Neon)
	r:WeaponTrail(LA, V(0, -0.9, 0), V(0, -1.9, -0.2), P.Neon)
	if not UnitModels.Lite then
		Details.AbyssOverlord(r, lv)
	end
	levelAura(r, lv)
	return r:Finish(1.55, { RS = { 12, 0, 8 }, LS = { 12, 0, -8 } })
end

------------------------------------------------------------------------
------------------------------------------------------------------------
-- НОВЫЕ ЮНИТЫ: SHATTERED REALITY CASE
------------------------------------------------------------------------
local BLUE = Color3.fromRGB(80, 170, 255)
local ICE = Color3.fromRGB(170, 225, 255)
local RED = Color3.fromRGB(255, 35, 55)
local BLOOD = Color3.fromRGB(140, 14, 28)
local MOON = Color3.fromRGB(245, 225, 235)
local SILVER = Color3.fromRGB(200, 200, 215)

-- кинжал в руке, клинок вперёд
local function dagger(r, limb, glow, len)
	len = len or 1.3
	r:Cyl(limb, 0.6, 0.2, CF(0, -1.05, 0.05), P.Maroon, M.Fabric, "Z")
	r:Box(limb, V(0.22, 0.55, 0.16), CF(0, -1.05, -0.3), P.Steel, M.Metal)
	r:Box(limb, V(0.1, 0.32, len), CF(0, -1.05, -0.38 - len / 2), P.Purple, M.Metal)
	r:Wedge(limb, V(0.1, 0.32, 0.45), CF(0, -1.05, -0.38 - len - 0.22) * ANG(0, math.pi, 0), P.Purple, M.Metal)
	if glow then
		r:Neon(limb, V(0.12, 0.07, len), CF(0, -0.9, -0.38 - len / 2), P.Neon)
	end
	return V(0, -1.05, -0.38 - len)
end

local function RiftScout(lv)
	local r = Rig.new({ Name = "RiftScout", Torso = P.DeepViolet, Arm = P.Coal, Leg = P.Black, Head = P.Skin, RoundHead = true })
	local T, H, RA, LA, RL, LL = r.Torso, r.Head, r.RArm, r.LArm, r.RLeg, r.LLeg
	r:Box(T, V(2.06, 1.0, 1.08), CF(0, 0.45, 0), P.Coal, M.Fabric) -- лёгкая куртка
	r:Box(T, V(2.04, 0.22, 1.06), CF(0, -0.7, 0), P.Maroon)
	r:Seg(T, V(0.9, 0.95, -0.56), V(-0.85, -0.65, -0.56), 0.16, P.Black)
	-- бандана, очки и шарф
	r:Cyl(H, 0.3, 1.36, CF(0, 0.45, 0), P.Purple, M.Fabric, "Y")
	r:Wedge(H, V(0.3, 0.5, 0.7), CF(0.2, 0.35, 0.85) * ANG(rad(-30), 0, rad(15)), P.Purple, M.Fabric)
	r:Box(H, V(1.38, 0.3, 0.2), CF(0, 0.12, -0.6), P.Black, M.Metal)
	r:Cyl(H, 0.1, 0.36, CF(-0.3, 0.12, -0.7), P.Neon, M.Neon, "Z")
	r:Cyl(H, 0.1, 0.36, CF(0.3, 0.12, -0.7), P.Neon, M.Neon, "Z")
	r:Box(H, V(1.38, 0.4, 0.15), CF(0, -0.38, -0.6), P.Maroon, M.Fabric)
	r:Face({ Mood = "angry", EyeY = 0.0, Mouth = false })
	local tipR = dagger(r, RA, lv >= 2, 1.2 + (lv >= 4 and 0.3 or 0))
	local tipL = dagger(r, LA, lv >= 3, 1.1 + (lv >= 4 and 0.3 or 0))
	r.Muzzle = r:Box(RA, V(0.2, 0.2, 0.2), CF(tipR), P.Black, M.Plastic, { Transparency = 1, Name = "Muzzle" })
	r:WeaponTrail(RA, V(0, -1.05, -0.5), tipR, P.NeonSoft)
	if lv >= 5 then
		-- дополнительный энергетический след
		r:WeaponTrail(LA, V(0, -1.05, -0.5), tipL, P.NeonPink)
		r:Neon(T, V(0.12, 1.4, 0.06), CF(-0.5, 0.2, -0.58) * ANG(0, 0, rad(-20)), P.NeonPink)
	end
	r:Hands(P.Black, M.Fabric)
	for _, Lg in ipairs({ RL, LL }) do
		r:Box(Lg, V(1.06, 0.45, 1.12), CF(0, -0.78, -0.04), P.Coal)
		r:Box(Lg, V(1.04, 0.12, 1.04), CF(0, -0.25, 0), P.Purple, M.Fabric)
	end
	if lv >= 2 then
		r:Pauldron(LA, -1, 0.7, P.Coal, P.Purple)
	end
	if lv >= 3 then
		for i = 0, 2 do
			r:Box(T, V(0.1, 0.5, 0.2), CF(-0.7 + i * 0.25, -0.95, -0.6) * ANG(0, 0, rad(-10)), P.Steel, M.Metal) -- метательные ножи
		end
	end
	if lv >= 4 then
		r:Cape(1.6, 2.0, P.DeepViolet, true)
	end
	levelAura(r, lv)
	return r:Finish(1, { RS = { 25, 0, 10 }, LS = { 25, 0, -10 } })
end

local function CrystalHunter(lv)
	local r = Rig.new({ Name = "CrystalHunter", Torso = Color3.fromRGB(30, 40, 70), Arm = Color3.fromRGB(30, 40, 70), Leg = P.Black, Head = P.Skin, RoundHead = true })
	local T, H, RA, LA, RL, LL = r.Torso, r.Head, r.RArm, r.LArm, r.RLeg, r.LLeg
	-- плащ охотника с меховым воротником
	r:Box(T, V(2.1, 1.9, 1.1), CF(0, 0.05, 0), Color3.fromRGB(25, 30, 55), M.Fabric)
	r:Sphere(T, V(2.4, 0.7, 1.4), CF(0, 0.95, 0.05), P.Pale, M.Fabric)
	r:Box(T, V(2.12, 0.25, 1.12), CF(0, -0.75, 0), P.Maroon)
	r:Box(T, V(1.0, 1.1, 0.1), CF(0, -1.4, -0.57), Color3.fromRGB(25, 30, 55), M.Fabric)
	-- широкополая шляпа с пером
	r:Cyl(H, 0.14, 2.2, CF(0, 0.68, 0) * ANG(rad(-6), 0, rad(4)), P.Coal, M.Fabric, "Y")
	r:Cyl(H, 0.6, 1.2, CF(0, 1.0, 0.05), P.Coal, M.Fabric, "Y")
	r:Cyl(H, 0.14, 1.24, CF(0, 0.78, 0.05), BLUE, M.Fabric, "Y")
	r:Sphere(H, V(0.18, 1.3, 0.3), CF(0.55, 1.35, 0.3) * ANG(rad(-25), 0, rad(-30)), ICE, M.Neon)
	r:Eyes(BLUE, { Y = 0.05, Spacing = 0.3, Size = V(0.24, 0.12, 0.06) })
	r:Face({ Mood = "calm", EyeY = 0.05 })
	-- кристальный колчан на спине
	r:Cyl(T, 1.8, 0.6, CF(-0.45, 0.2, 0.8) * ANG(0, 0, rad(18)), P.Coal, M.Fabric, "Y")
	for i = 0, 2 do
		r:Neon(T, V(0.22, 0.6, 0.22), CF(-0.6 + i * 0.12, 1.2, 0.8 + (i - 1) * 0.12) * ANG(0, rad(45), rad(18)), BLUE)
	end
	-- кристальный арбалет (ствол вдоль -Y руки)
	local function crossbow(yOff, xOff)
		r:Box(RA, V(0.4, 2.0, 0.5), CF(xOff, -1.9 + yOff, -0.1), P.Coal, M.Metal)
		r:Box(RA, V(0.4, 0.6, 1.1), CF(xOff, -1.15 + yOff, 0.3), P.Maroon) -- приклад
		r:Rod(RA, V(xOff, -2.6 + yOff, -0.1), V(xOff - 1.3, -2.3 + yOff, -0.1), 0.18, P.Steel, M.Metal) -- плечи лука
		r:Rod(RA, V(xOff, -2.6 + yOff, -0.1), V(xOff + 1.3, -2.3 + yOff, -0.1), 0.18, P.Steel, M.Metal)
		r:Neon(RA, V(2.6, 0.05, 0.05), CF(xOff, -2.15 + yOff, -0.1), ICE) -- тетива
		r:Neon(RA, V(0.18, 1.2, 0.18), CF(xOff, -2.5 + yOff, -0.35) * ANG(0, rad(45), 0), BLUE) -- кристальный болт
	end
	crossbow(0, 0)
	if lv >= 5 then
		crossbow(0.05, 0.55) -- двойной выстрел
	end
	r.Muzzle = r:Neon(RA, V(0.3, 0.3, 0.3), CF(0, -3.1, -0.35) * ANG(rad(45), rad(45), 0), BLUE)
	r.Muzzle.Name = "Muzzle"
	r:Hands(Color3.fromRGB(60, 45, 35), M.Fabric)
	for _, Lg in ipairs({ RL, LL }) do
		r:Box(Lg, V(1.08, 0.75, 1.14), CF(0, -0.65, -0.04), Color3.fromRGB(60, 45, 35), M.Fabric)
		r:Sphere(Lg, V(1.15, 0.35, 1.15), CF(0, -0.25, 0), P.Pale, M.Fabric)
	end
	if lv >= 2 then
		r:Pauldron(RA, 1, 0.75, Color3.fromRGB(40, 60, 100), ICE)
	end
	if lv >= 3 then
		r:Pauldron(LA, -1, 0.75, Color3.fromRGB(40, 60, 100), ICE)
		r:Neon(T, V(0.3, 0.3, 0.08), CF(0, 0.4, -0.58) * ANG(0, 0, rad(45)), BLUE)
	end
	if lv >= 4 then
		r:Orbit("OrbitCrystals", T, CF(0, 0.5, 0), 2.0, 3, 0.3, BLUE)
	end
	levelAura(r, lv, BLUE)
	return r:Finish(1, { RS = { 75, 0, 0 }, LS = { 65, 0, -25 } })
end

local function VoidPuppeteer(lv)
	local r = Rig.new({ Name = "VoidPuppeteer", Torso = P.Black, Arm = P.Black, Leg = P.Black, Head = P.Black })
	local T, H, RA, LA = r.Torso, r.Head, r.RArm, r.LArm
	-- высокий остроконечный капюшон
	r:Box(H, V(1.6, 0.3, 1.6), CF(0, 0.78, 0.05), P.DeepViolet, M.Fabric)
	r:Box(H, V(0.26, 1.5, 1.6), CF(-0.78, 0, 0.05), P.DeepViolet, M.Fabric)
	r:Box(H, V(0.26, 1.5, 1.6), CF(0.78, 0, 0.05), P.DeepViolet, M.Fabric)
	r:Box(H, V(1.6, 1.5, 0.26), CF(0, 0, 0.78), P.DeepViolet, M.Fabric)
	r:Wedge(H, V(1.0, 1.6, 1.0), CF(0.1, 1.6, 0.25) * ANG(rad(-10), 0, rad(8)), P.DeepViolet, M.Fabric)
	r:Eyes(P.NeonSoft, { Y = 0, Spacing = 0.28, Size = V(0.22, 0.22, 0.06), Inset = 0.2 })
	-- маска-улыбка
	r:Box(H, V(0.6, 0.1, 0.06), CF(0, -0.35, -0.56), P.NeonSoft, M.Neon)
	-- длинный камзол
	r:Box(T, V(2.15, 1.9, 1.15), CF(0, 0.05, 0), P.Violet, M.Fabric)
	r:Box(T, V(2.2, 1.6, 1.2), CF(0, -1.7, 0), P.DeepViolet, M.Fabric)
	for i = -1, 1 do
		r:Ball(T, 0.16, CF(0, 0.6 - i * 0.4, -0.6), P.Gold, M.Metal) -- пуговицы
	end
	r:Box(T, V(2.2, 0.2, 1.2), CF(0, -0.85, 0), P.Black)
	r:Hands(P.Pale)
	-- нити на пальцах
	for _, A in ipairs({ RA, LA }) do
		for k = -1, 1 do
			r:Rod(A, V(k * 0.25, -1.1, -0.2), V(k * 0.4, -2.6, -0.9), 0.04, P.NeonSoft, M.Neon)
		end
	end
	-- парящая теневая кукла
	local doll = r:Joint("OrbitPuppet", T, V(0.2, 0.2, 0.2), CF(0, 0.2, 0), CF(), P.Black)
	doll.Transparency = 1
	local function makeDoll(cx, cz, color)
		r:Box(doll, V(0.5, 0.6, 0.3), CF(cx, -0.4, cz), color, M.Fabric)
		r:Box(doll, V(0.45, 0.45, 0.45), CF(cx, 0.15, cz), color, M.Fabric)
		r:Neon(doll, V(0.1, 0.1, 0.05), CF(cx - 0.1, 0.18, cz - 0.23), P.NeonPink)
		r:Neon(doll, V(0.1, 0.1, 0.05), CF(cx + 0.1, 0.18, cz - 0.23), P.NeonPink)
		r:Box(doll, V(0.18, 0.5, 0.18), CF(cx - 0.35, -0.4, cz), color, M.Fabric)
		r:Box(doll, V(0.18, 0.5, 0.18), CF(cx + 0.35, -0.4, cz), color, M.Fabric)
		r:Box(doll, V(0.18, 0.5, 0.18), CF(cx - 0.12, -0.95, cz), color, M.Fabric)
		r:Box(doll, V(0.18, 0.5, 0.18), CF(cx + 0.12, -0.95, cz), color, M.Fabric)
		r:Rod(doll, V(cx, 0.4, cz), V(cx, 2.0, cz), 0.03, P.NeonSoft, M.Neon)
	end
	makeDoll(2.2, -0.6, P.Coal)
	if lv >= 5 then
		makeDoll(-2.2, -0.6, P.DeepViolet)
	end
	r.Muzzle = r:Box(RA, V(0.2, 0.2, 0.2), CF(0, -1.3, -0.3), P.Black, M.Plastic, { Transparency = 1, Name = "Muzzle" })
	if lv >= 2 then
		r:Cyl(H, 0.1, 1.7, CF(0, 0.55, 0), P.NeonSoft, M.Neon, "Y") -- светящийся обод капюшона
	end
	if lv >= 3 then
		r:Pauldron(RA, 1, 0.8, P.DeepViolet, P.Gold)
		r:Pauldron(LA, -1, 0.8, P.DeepViolet, P.Gold)
	end
	if lv >= 4 then
		r:Cape(2.1, 3.4, P.Black, true)
		r:Glow(doll:FindFirstChildWhichIsA("BasePart") or doll, P.NeonSoft, 6, 1)
	end
	levelAura(r, lv)
	return r:Finish(1.05, { RS = { 40, 0, 20 }, LS = { 40, 0, -20 } })
end

local function Starbreaker(lv)
	local GOLD = P.Gold
	local r = Rig.new({ Name = "Starbreaker", Torso = P.Black, Arm = P.Black, Leg = P.Black, Head = P.Black, HeadSize = V(1.45, 1.45, 1.45), TorsoMat = M.Metal })
	local T, H, RA, LA, RL, LL = r.Torso, r.Head, r.RArm, r.LArm, r.RLeg, r.LLeg
	r:Box(T, V(2.7, 2.1, 1.6), CF(0, 0.15, 0), P.Coal, M.Metal)
	r:Wedge(T, V(2.7, 0.6, 0.6), CF(0, -1.0, -0.65) * ANG(0, math.pi, math.pi), P.Black, M.Metal)
	-- золото-фиолетовые руны
	for i = 0, 2 do
		r:Neon(T, V(0.3, 0.3, 0.06), CF(-0.7 + i * 0.7, 0.55 - (i % 2) * 0.3, -0.82) * ANG(0, 0, rad(45)), i % 2 == 0 and GOLD or P.Neon)
	end
	r:Neon(T, V(2.2, 0.08, 0.06), CF(0, -0.2, -0.82), GOLD)
	-- светящийся шлем
	r:Cyl(H, 1.5, 1.6, CF(0, 0, 0), P.Black, M.Metal, "Y")
	r:Sphere(H, V(1.6, 0.7, 1.6), CF(0, 0.75, 0), P.Coal, M.Metal)
	r:Box(H, V(1.3, 0.35, 0.1), CF(0, 0.05, -0.8), P.NeonSoft, M.Neon)
	r:Box(H, V(0.25, 0.9, 0.2), CF(0, 1.2, 0), GOLD, M.Metal)
	r:Pauldron(RA, 1, 1.25, P.Black, GOLD, 0.1)
	r:Pauldron(LA, -1, 1.2, P.Black, GOLD, 0.1)
	r:Box(RA, V(1.2, 1.0, 1.2), CF(0, -0.5, 0), P.Coal, M.Metal)
	r:Box(LA, V(1.2, 1.0, 1.2), CF(0, -0.5, 0), P.Coal, M.Metal)
	r:Box(RL, V(1.15, 1.3, 1.2), CF(0, -0.35, 0), P.Coal, M.Metal)
	r:Box(LL, V(1.15, 1.3, 1.2), CF(0, -0.35, 0), P.Coal, M.Metal)
	r:Cape(2.5, 3.8, P.DeepViolet, true)
	-- огромный молот: рукоять вперёд, боёк поперёк
	local hl = 4.0 + (lv >= 4 and 0.6 or 0)
	r:Cyl(RA, hl, 0.32, CF(0, -1.05, -hl / 2 + 0.4), P.Maroon, M.Fabric, "Z")
	r:Ball(RA, 0.5, CF(0, -1.05, 0.55), GOLD, M.Metal)
	local hz = -hl + 0.2
	local hs = lv >= 5 and 1.25 or 1
	r:Box(RA, V(1.6, 2.6, 1.6) * hs, CF(0, -1.05, hz), P.Black, M.Metal)
	r:Cyl(RA, 0.3, 1.9 * hs, CF(0, -1.05 + 1.3 * hs, hz), GOLD, M.Metal, "Y")
	r:Cyl(RA, 0.3, 1.9 * hs, CF(0, -1.05 - 1.3 * hs, hz), GOLD, M.Metal, "Y")
	r:Neon(RA, V(1.65, 0.2, 1.65) * hs, CF(0, -1.05, hz), lv >= 3 and P.Neon or GOLD)
	if lv >= 5 then
		r:Neon(RA, V(0.8, 2.7, 0.8), CF(0, -1.05, hz), P.NeonSoft)
	end
	r.Muzzle = r:Box(RA, V(0.2, 0.2, 0.2), CF(0, -1.05, hz), P.Black, M.Plastic, { Transparency = 1, Name = "Muzzle" })
	r:WeaponTrail(RA, V(0, -1.05, hz + 0.8), V(0, -1.05, hz - 0.8), GOLD)
	if lv >= 3 then
		r:Orbit("OrbitStars", H, CF(0, 1.3, 0), 1.6, lv >= 5 and 5 or 3, 0.3, GOLD)
	end
	if lv >= 4 then
		r:Horn(H, 1, V(0.7, 0.4, 0), 0.9, GOLD)
		r:Horn(H, -1, V(-0.7, 0.4, 0), 0.9, GOLD)
	end
	levelAura(r, lv, GOLD)
	return r:Finish(1.3, { RS = { 30, 0, 0 }, LS = { 20, 0, 0 } })
end

local function RiftMonarch(lv)
	local r = Rig.new({ Name = "RiftMonarch", Torso = P.Black, Arm = P.DeepViolet, Leg = P.Black, Head = P.Pale, RoundHead = true, TorsoMat = M.Metal })
	local T, H, RA, LA, RL, LL = r.Torso, r.Head, r.RArm, r.LArm, r.RLeg, r.LLeg
	r:Box(T, V(2.25, 1.8, 1.25), CF(0, 0.2, 0), P.Coal, M.Metal)
	r:Box(T, V(2.25, 1.7, 1.3), CF(0, -1.75, 0), P.DeepViolet, M.Fabric)
	r:Seg(T, V(-0.9, 0.9, -0.66), V(0.8, -0.7, -0.66), V2(0.3, 0.08), P.Neon, M.Neon)
	r:Pauldron(RA, 1, 1.0, P.Black, P.Neon, 0, M.Neon)
	r:Pauldron(LA, -1, 1.0, P.Black, P.Neon, 0, M.Neon)
	r:Eyes(P.Neon, { Y = 0.08, Spacing = 0.3, Size = V(0.26, 0.12, 0.06), Tilt = -8 })
	r:Face({ Mood = "angry", EyeY = 0.08, Mouth = false })
	-- чёрно-фиолетовая зубчатая корона
	r:Cyl(H, 0.5, 1.75, CF(0, 0.85, 0), P.Black, M.Metal, "Y")
	for i = 0, 6 do
		local a = i / 7 * math.pi * 2
		local h = (i % 2 == 0) and 1.1 or 0.7
		r:Wedge(H, V(0.3, h, 0.3), CF(math.cos(a) * 0.75, 1.1 + h / 2, math.sin(a) * 0.75) * ANG(0, -a, 0), i % 2 == 0 and P.Neon or P.Black, i % 2 == 0 and M.Neon or M.Metal)
	end
	-- энергетический посох с порталом наверху
	r:Cyl(RA, 6, 0.26, CF(0, 0.3, -0.55), P.Black, M.Metal, "Y")
	local top = V(0, 3.6, -0.55)
	for i = 0, 9 do
		local a1, a2 = i / 10 * math.pi * 2, (i + 1) / 10 * math.pi * 2
		r:Rod(RA, top + V(math.cos(a1) * 0.7, math.sin(a1) * 0.7, 0), top + V(math.cos(a2) * 0.7, math.sin(a2) * 0.7, 0), 0.14, P.Neon, M.Neon)
	end
	r:Cyl(RA, 0.1, 1.2, CF(top) * ANG(0, rad(90), 0), Color3.fromRGB(10, 0, 20), M.Neon, "X")
	r.Muzzle = r:Box(RA, V(0.2, 0.2, 0.2), CF(top), P.Black, M.Plastic, { Transparency = 1, Name = "Muzzle" })
	r:WeaponTrail(RA, top - V(0, 0.8, 0), top + V(0, 0.8, 0), P.Neon)
	r:Hands(P.Black, M.Metal)
	-- плавающие кольца за спиной
	local function ring(name, radius, count, color)
		local hub = r:Orbit(name, T, CF(0, 0.6, 1.6) * ANG(rad(90), 0, 0), radius, 0, 0.2, color)
		for i = 0, count - 1 do
			local a = i / count * math.pi * 2
			r:Neon(hub, V(0.25, 0.25, 0.7), CF(math.cos(a) * radius, 0, math.sin(a) * radius) * ANG(0, -a, 0), color)
		end
	end
	ring("OrbitRing1", 1.8, 12, P.Neon)
	if lv >= 3 then
		ring("OrbitRing2", 2.6, 16, P.NeonPink)
	end
	if lv >= 2 then
		r:Cape(2.3, 3.8, P.Black, true)
	end
	if lv >= 4 then
		r:Sparkles(T, P.Neon, { Rate = 10, Size = 0.3 })
	end
	levelAura(r, lv)
	return r:Finish(1.4, { RS = { 12, 0, 0 } })
end

local function RealityDestroyer(lv)
	local r = Rig.new({ Name = "RealityDestroyer", Torso = P.Black, Arm = P.Black, Leg = P.Black, Head = P.Black, HeadSize = V(1.45, 1.45, 1.45), TorsoMat = M.Metal })
	local T, H, RA, LA, RL, LL = r.Torso, r.Head, r.RArm, r.LArm, r.RLeg, r.LLeg
	r:Box(T, V(2.8, 2.2, 1.6), CF(0, 0.15, 0), P.Black, M.Metal)
	r:Box(T, V(2.4, 0.5, 1.5), CF(0, -0.95, 0), P.Coal, M.Metal)
	-- красные светящиеся трещины
	local cracks = { { V(-1.1, 0.9, -0.82), V(-0.2, 0.1, -0.82) }, { V(-0.2, 0.1, -0.82), V(0.4, -0.7, -0.82) }, { V(-0.2, 0.1, -0.82), V(1.0, 0.5, -0.82) }, { V(0.8, 1.0, -0.82), V(1.2, 0.2, -0.82) } }
	for _, c in ipairs(cracks) do
		r:Seg(T, c[1], c[2], 0.12, RED, M.Neon)
	end
	r:Box(H, V(1.55, 1.55, 1.55), CF(0, 0, 0), P.Black, M.Metal)
	r:Eyes(RED, { Y = 0.05, Spacing = 0.32, Size = V(0.32, 0.14, 0.06), Tilt = -15, Inset = -0.06 })
	r:Seg(H, V(-0.5, 0.6, -0.79), V(0.1, -0.2, -0.79), 0.08, RED, M.Neon)
	-- сломанная корона (не хватает зубцов, наклонена)
	r:Cyl(H, 0.4, 1.7, CF(0, 0.95, 0) * ANG(0, 0, rad(-9)), P.DarkGold, M.Metal, "Y")
	for i, a in ipairs({ 0, 1.2, 2.1, 4.4 }) do
		local h = ({ 0.9, 0.5, 0.75, 0.35 })[i]
		r:Wedge(H, V(0.3, h, 0.3), CF(math.cos(a) * 0.75, 1.2 + h / 2, math.sin(a) * 0.75) * ANG(0, -a, rad(-9 + i * 4)), P.DarkGold, M.Metal)
	end
	r:Pauldron(RA, 1, 1.3, P.Black, RED, 0.1, M.Neon)
	r:Pauldron(LA, -1, 1.2, P.Black, BLOOD, 0.1)
	r:Box(RA, V(1.2, 1.0, 1.2), CF(0, -0.5, 0), P.Coal, M.Metal)
	r:Box(LA, V(1.2, 1.0, 1.2), CF(0, -0.5, 0), P.Coal, M.Metal)
	r:Box(RL, V(1.15, 1.3, 1.2), CF(0, -0.35, 0), P.Coal, M.Metal)
	r:Box(LL, V(1.15, 1.3, 1.2), CF(0, -0.35, 0), P.Coal, M.Metal)
	r:Seg(RL, V(-0.3, 0.2, -0.62), V(0.2, -0.6, -0.62), 0.08, RED, M.Neon)
	r:Cape(2.6, 4.0, BLOOD, true)
	-- красно-фиолетовый меч
	local blade = r:Sword(RA, {
		Length = 5.0 + (lv >= 4 and 0.8 or 0),
		Width = 0.9,
		Blade = P.Black,
		Edge = RED,
		Core = P.NeonPink,
		Guard = P.DarkGold,
		GuardWidth = 2.0,
		Runes = 2 + lv,
		Gem = RED,
	})
	r:Glow(blade, RED, 10, 1.5)
	-- парящие осколки реальности
	local hub = r:Orbit("OrbitShards", T, CF(0, 0.6, 0), 2.6, 0, 0.3, RED)
	for i = 0, (lv >= 3 and 7 or 5) - 1 do
		local a = i / (lv >= 3 and 7 or 5) * math.pi * 2
		r:Wedge(hub, V(0.25, 0.7, 0.4), CF(math.cos(a) * 2.6, math.sin(a * 3) * 0.4, math.sin(a) * 2.6) * ANG(rad(30), -a, rad(20)), i % 2 == 0 and RED or P.Neon, M.Neon)
	end
	if lv >= 2 then
		r:Horn(H, 1, V(0.7, 0.4, 0), 1.0, P.Black)
	end
	if lv >= 4 then
		r:Sparkles(blade, RED, { Rate = 16, Size = 0.4 })
		r:Horn(H, -1, V(-0.7, 0.4, 0), 0.6, P.Black) -- обломанный рог
	end
	levelAura(r, lv, RED)
	return r:Finish(1.5, { RS = { 25, 0, 0 } })
end

------------------------------------------------------------------------
-- НОВЫЕ ЮНИТЫ: BLOOD MOON CASE
------------------------------------------------------------------------
local function BloodAcolyte(lv)
	local r = Rig.new({ Name = "BloodAcolyte", Torso = BLOOD, Arm = BLOOD, Leg = P.Black, Head = P.Pale, RoundHead = true })
	local T, H, RA, LA = r.Torso, r.Head, r.RArm, r.LArm
	r:Box(H, V(1.55, 0.28, 1.5), CF(0, 0.74, 0.04), P.Maroon, M.Fabric)
	r:Box(H, V(0.24, 1.4, 1.5), CF(-0.74, 0.02, 0.04), P.Maroon, M.Fabric)
	r:Box(H, V(0.24, 1.4, 1.5), CF(0.74, 0.02, 0.04), P.Maroon, M.Fabric)
	r:Box(H, V(1.55, 1.4, 0.24), CF(0, 0.02, 0.72), P.Maroon, M.Fabric)
	r:Eyes(RED, { Y = 0.05, Spacing = 0.28, Size = V(0.22, 0.12, 0.06) })
	r:Face({ Mood = "angry", EyeY = 0.05, Mouth = true })
	r:Box(T, V(2.2, 1.7, 1.25), CF(0, -1.65, 0), BLOOD, M.Fabric) -- ряса
	r:Rod(T, V(-1.05, -0.8, -0.6), V(1.05, -0.8, -0.6), 0.14, Color3.fromRGB(150, 120, 80), M.Fabric) -- верёвочный пояс
	r:Rod(T, V(0.5, -0.8, -0.62), V(0.6, -1.6, -0.65), 0.1, Color3.fromRGB(150, 120, 80), M.Fabric)
	r:Ball(T, 0.3, CF(0, 0.45, -0.62), RED, M.Neon) -- кровавый камень
	r:Hands(P.Pale)
	-- серп: древко и изогнутое лезвие наверху
	r:Cyl(RA, 2.6, 0.2, CF(0, -0.9, -0.55), Color3.fromRGB(70, 45, 30), M.Wood or M.Plastic, "Y")
	local top = V(0, 0.35, -0.55)
	local pts = { top, top + V(0, 0.35, -0.6), top + V(0, 0.2, -1.2), top + V(0, -0.3, -1.5) }
	r:Chain(RA, pts, 0.3, P.Steel, M.Metal, 0.8)
	if lv >= 2 then
		local edge = {}
		for i, p in ipairs(pts) do
			edge[i] = p + V(0, -0.14, 0)
		end
		r:Chain(RA, edge, 0.08, RED, M.Neon, 1)
	end
	r.Muzzle = r:Box(RA, V(0.2, 0.2, 0.2), CF(top + V(0, -0.3, -1.5)), P.Black, M.Plastic, { Transparency = 1, Name = "Muzzle" })
	r:WeaponTrail(RA, top, top + V(0, -0.3, -1.5), RED)
	if lv >= 3 then
		r:Box(T, V(2.25, 0.6, 1.3), CF(0, 0.75, 0), P.Maroon, M.Fabric)
	end
	if lv >= 4 then
		r:Cape(1.8, 2.8, P.Maroon, true)
	end
	if lv >= 5 then
		r:Orbit("OrbitBlood", T, CF(0, 0.5, 0), 1.8, 3, 0.3, RED)
	end
	levelAura(r, lv, RED)
	return r:Finish(1, { RS = { 20, 0, 0 } })
end

local function revolver(r, limb, glow)
	r:Box(limb, V(0.3, 0.55, 0.45), CF(0, -1.25, 0.1), Color3.fromRGB(70, 45, 30)) -- рукоять
	r:Cyl(limb, 0.4, 0.45, CF(0, -1.6, -0.05), P.Steel, M.Metal, "Y") -- барабан
	r:Cyl(limb, 1.0, 0.2, CF(0, -2.2, -0.05), P.Black, M.Metal, "Y") -- ствол
	if glow then
		r:Cyl(limb, 0.6, 0.22, CF(0, -2.0, -0.05), RED, M.Neon, "Y")
	end
	return V(0, -2.75, -0.05)
end

local function CrimsonGunslinger(lv)
	local r = Rig.new({ Name = "CrimsonGunslinger", Torso = P.Coal, Arm = P.Coal, Leg = Color3.fromRGB(50, 35, 30), Head = P.Skin, RoundHead = true })
	local T, H, RA, LA, RL, LL = r.Torso, r.Head, r.RArm, r.LArm, r.RLeg, r.LLeg
	-- ковбойская шляпа
	r:Cyl(H, 0.14, 2.3, CF(0, 0.66, 0) * ANG(rad(-5), 0, rad(-4)), P.Black, M.Fabric, "Y")
	r:Cyl(H, 0.7, 1.3, CF(0, 1.02, 0), P.Black, M.Fabric, "Y")
	r:Cyl(H, 0.14, 1.34, CF(0, 0.8, 0), RED, M.Fabric, "Y")
	r:Eyes(RED, { Y = 0.02, Spacing = 0.28, Size = V(0.24, 0.1, 0.06), Tilt = -10 })
	r:Face({ Mood = "angry", EyeY = 0.02, Mouth = false })
	r:Box(H, V(1.38, 0.45, 0.15), CF(0, -0.38, -0.6), BLOOD, M.Fabric) -- платок
	-- пончо
	r:Wedge(T, V(2.4, 0.9, 0.7), CF(0, 0.6, -0.5) * ANG(0, math.pi, 0), BLOOD, M.Fabric)
	r:Wedge(T, V(2.4, 0.9, 0.7), CF(0, 0.6, 0.5), BLOOD, M.Fabric)
	r:Box(T, V(2.3, 0.12, 1.3), CF(0, 0.16, 0), P.Gold, M.Fabric)
	r:Box(T, V(2.1, 0.25, 1.1), CF(0, -0.8, 0), Color3.fromRGB(70, 45, 30)) -- пояс
	r:Ball(T, 0.3, CF(0, -0.8, -0.58), P.Gold, M.Metal)
	for i = 0, 4 do
		r:Cyl(T, 0.25, 0.1, CF(-0.8 + i * 0.4, -0.8, -0.6), P.Gold, M.Metal, "Y") -- патроны
	end
	r:Hands(P.Black, M.Fabric)
	for _, Lg in ipairs({ RL, LL }) do
		r:Box(Lg, V(1.08, 0.8, 1.15), CF(0, -0.62, -0.04), Color3.fromRGB(70, 45, 30)) -- сапоги
		r:Cyl(Lg, 0.1, 0.35, CF(0, -0.95, 0.62), P.Steel, M.Metal, "Z") -- шпоры
	end
	local tip = revolver(r, RA, lv >= 3)
	revolver(r, LA, lv >= 3)
	r.Muzzle = r:Box(RA, V(0.2, 0.2, 0.2), CF(tip), P.Black, M.Plastic, { Transparency = 1, Name = "Muzzle" })
	if lv >= 2 then
		r:Pauldron(RA, 1, 0.7, BLOOD, P.Gold)
	end
	if lv >= 4 then
		r:Cape(1.8, 2.6, P.Black, true)
	end
	if lv >= 5 then
		r:Neon(H, V(1.36, 0.08, 1.36), CF(0, 0.8, 0), RED)
	end
	levelAura(r, lv, RED)
	return r:Finish(1, { RS = { 70, 0, 0 }, LS = { 70, 0, 0 } })
end

local function MoonWitch(lv)
	local r = Rig.new({ Name = "MoonWitch", Torso = Color3.fromRGB(40, 12, 30), Arm = Color3.fromRGB(40, 12, 30), Leg = P.Black, Head = MOON, RoundHead = true })
	local T, H, RA, LA = r.Torso, r.Head, r.RArm, r.LArm
	-- остроконечная шляпа ведьмы
	r:Cyl(H, 0.14, 2.4, CF(0, 0.7, 0) * ANG(rad(-4), 0, rad(5)), P.Black, M.Fabric, "Y")
	r:Cyl(H, 0.6, 1.3, CF(0, 1.05, 0.05), P.Black, M.Fabric, "Y")
	r:Cyl(H, 0.6, 0.9, CF(0.1, 1.6, 0.25) * ANG(rad(-15), 0, rad(-10)), P.Black, M.Fabric, "Y")
	r:Cyl(H, 0.5, 0.5, CF(0.2, 2.05, 0.55) * ANG(rad(-30), 0, rad(-18)), P.Black, M.Fabric, "Y")
	r:Cyl(H, 0.14, 1.34, CF(0, 0.85, 0.05), RED, M.Fabric, "Y")
	r:Neon(H, V(0.3, 0.3, 0.08), CF(0.45, 1.0, -0.6) * ANG(0, 0, rad(45)), MOON)
	-- длинные волосы
	r:Box(H, V(1.4, 1.4, 0.3), CF(0, -0.3, 0.6), Color3.fromRGB(90, 10, 30))
	r:Eyes(RED, { Y = 0.05, Spacing = 0.28, Size = V(0.22, 0.14, 0.06) })
	r:Face({ Mood = "calm", EyeY = 0.05, MouthColor = BLOOD })
	-- платье
	r:Box(T, V(2.2, 2.1, 1.3), CF(0, -2.0, 0), Color3.fromRGB(40, 12, 30), M.Fabric)
	r:Box(T, V(2.25, 0.15, 1.35), CF(0, -2.95, 0), RED, M.Fabric)
	r:Rod(T, V(-1.0, -0.8, -0.6), V(1.0, -0.8, -0.6), 0.14, P.Gold, M.Metal)
	r:Hands(MOON)
	-- посох с полумесяцем
	r:Cyl(RA, 5, 0.22, CF(0, -0.5, -0.55), P.Black, M.Plastic, "Y")
	local c = V(0, 2.5, -0.55)
	local pts = {}
	for i = 0, 6 do
		local a = math.rad(-60 + i * 40)
		pts[#pts + 1] = c + V(0, math.cos(a) * 0.9, math.sin(a) * 0.9)
	end
	r:Chain(RA, pts, 0.3, MOON, M.Neon, 0.9, true)
	r.Muzzle = r:Box(RA, V(0.2, 0.2, 0.2), CF(c), P.Black, M.Plastic, { Transparency = 1, Name = "Muzzle" })
	r:WeaponTrail(RA, c - V(0, 0.9, 0), c + V(0, 0.9, 0), MOON)
	r:Glow(RA, MOON, 6, 1)
	-- парящая луна
	if lv >= 2 then
		local hub = r:Orbit("OrbitMoon", T, CF(0, 1.4, 0), 1.9, 0, 0.3, MOON)
		r:Ball(hub, 0.7, CF(1.9, 0, 0), MOON, M.Neon)
		if lv >= 4 then
			r:Ball(hub, 0.5, CF(-1.9, 0, 0), RED, M.Neon)
		end
	end
	if lv >= 3 then
		r:Cape(1.9, 3.2, P.Black, true)
	end
	if lv >= 5 then
		r:Sparkles(T, RED, { Rate = 8, Size = 0.3 })
	end
	levelAura(r, lv, MOON)
	return r:Finish(1.05, { RS = { 10, 0, 0 }, LS = { 10, 0, -10 } })
end

local function BloodfangWarlord(lv)
	local r = Rig.new({ Name = "BloodfangWarlord", Torso = Color3.fromRGB(80, 50, 40), Arm = Color3.fromRGB(80, 50, 40), Leg = P.Black, Head = Color3.fromRGB(80, 50, 40), HeadSize = V(1.4, 1.4, 1.4) })
	local T, H, RA, LA, RL, LL = r.Torso, r.Head, r.RArm, r.LArm, r.RLeg, r.LLeg
	local FUR = Color3.fromRGB(70, 60, 60)
	-- волчья шкура-капюшон с пастью
	r:Sphere(H, V(1.7, 1.1, 1.8), CF(0, 0.65, 0.1), FUR, M.Fabric)
	r:Box(H, V(0.9, 0.5, 0.9), CF(0, 0.75, -0.95), FUR, M.Fabric)
	for i = -1, 1, 2 do
		r:Wedge(H, V(0.15, 0.35, 0.2), CF(i * 0.3, 0.42, -1.3) * ANG(0, 0, math.pi), P.White)
		r:Wedge(H, V(0.3, 0.5, 0.4), CF(i * 0.55, 1.25, 0.2), FUR, M.Fabric) -- уши
	end
	r:Neon(H, V(0.12, 0.08, 0.06), CF(-0.3, 0.88, -1.4), RED)
	r:Neon(H, V(0.12, 0.08, 0.06), CF(0.3, 0.88, -1.4), RED)
	r:Eyes(RED, { Y = 0.0, Spacing = 0.32, Size = V(0.28, 0.12, 0.06), Tilt = -15 })
	r:Box(H, V(0.12, 0.6, 0.06), CF(-0.32, -0.25, -0.72), RED, M.Neon) -- боевая раскраска
	r:Box(H, V(0.12, 0.6, 0.06), CF(0.32, -0.25, -0.72), RED, M.Neon)
	-- броня и мех
	r:Box(T, V(2.5, 1.6, 1.4), CF(0, 0.3, 0), P.Coal, M.Metal)
	r:Sphere(T, V(3.2, 0.9, 1.8), CF(0, 1.0, 0.05), FUR, M.Fabric)
	r:Box(T, V(2.3, 0.35, 1.3), CF(0, -0.8, 0), Color3.fromRGB(70, 45, 30))
	r:Ball(T, 0.45, CF(0, -0.8, -0.68), P.Pale) -- череп-пряжка
	for _, x in ipairs({ -0.6, 0.6 }) do
		r:Box(T, V(0.8, 0.9, 0.15), CF(x, -1.35, -0.62) * ANG(rad(-8), 0, 0), FUR, M.Fabric)
	end
	r:Pauldron(RA, 1, 1.15, P.Coal, RED, 0, M.Neon)
	r:Pauldron(LA, -1, 1.1, P.Coal, P.Steel)
	r:Hands(Color3.fromRGB(60, 40, 30), M.Fabric)
	for _, Lg in ipairs({ RL, LL }) do
		r:Box(Lg, V(1.15, 0.9, 1.2), CF(0, -0.55, 0), FUR, M.Fabric)
	end
	-- двуручный топор: рукоять вперёд, два лезвия
	local hl = 4.2
	r:Cyl(RA, hl, 0.3, CF(0, -1.05, -hl / 2 + 0.4), Color3.fromRGB(60, 40, 30), M.Fabric, "Z")
	local hz = -hl + 0.4
	local bs = lv >= 4 and 1.2 or 1
	for _, side in ipairs({ 1, -1 }) do
		r:Box(RA, V(0.18, 1.3 * bs, 1.2 * bs), CF(0, -1.05 + side * 0.85 * bs, hz), P.Steel, M.Metal)
		r:Wedge(RA, V(0.18, 0.6 * bs, 1.2 * bs), CF(0, -1.05 + side * 1.75 * bs, hz) * ANG(side == 1 and 0 or math.pi, 0, 0), P.Steel, M.Metal)
		if lv >= 2 then
			r:Neon(RA, V(0.2, 0.12, 1.2 * bs), CF(0, -1.05 + side * 2.05 * bs, hz), RED)
		end
	end
	r.Muzzle = r:Box(RA, V(0.2, 0.2, 0.2), CF(0, -1.05, hz), P.Black, M.Plastic, { Transparency = 1, Name = "Muzzle" })
	r:WeaponTrail(RA, V(0, -1.05 + 1.8 * bs, hz), V(0, -1.05 - 1.8 * bs, hz), RED)
	if lv >= 3 then
		r:Cape(2.4, 3.4, BLOOD, true)
	end
	if lv >= 5 then
		r:Horn(H, 1, V(0.7, 0.6, 0.1), 0.8, P.Pale)
		r:Horn(H, -1, V(-0.7, 0.6, 0.1), 0.8, P.Pale)
	end
	levelAura(r, lv, RED)
	return r:Finish(1.3, { RS = { 30, 0, 0 } })
end

local function LunarSeraph(lv)
	local r = Rig.new({ Name = "LunarSeraph", Torso = SILVER, Arm = SILVER, Leg = Color3.fromRGB(150, 150, 170), Head = MOON, RoundHead = true, TorsoMat = M.Metal })
	local T, H, RA, LA, RL, LL = r.Torso, r.Head, r.RArm, r.LArm, r.RLeg, r.LLeg
	r:Box(T, V(2.2, 1.5, 1.2), CF(0, 0.3, 0), P.White, M.Metal)
	r:Neon(T, V(0.45, 0.45, 0.06), CF(0, 0.4, -0.62) * ANG(0, 0, rad(45)), Color3.fromRGB(255, 160, 200))
	r:Box(T, V(2.2, 1.3, 1.25), CF(0, -1.55, 0), P.White, M.Fabric)
	r:Box(T, V(2.24, 0.2, 1.28), CF(0, -0.85, 0), P.Gold, M.Metal)
	r:Pauldron(RA, 1, 0.9, P.White, P.Gold)
	r:Pauldron(LA, -1, 0.9, P.White, P.Gold)
	r:Box(H, V(1.4, 1.2, 0.35), CF(0, 0.05, 0.55), Color3.fromRGB(250, 240, 220)) -- волосы
	r:Eyes(Color3.fromRGB(255, 120, 170), { Y = 0.05, Spacing = 0.3, Size = V(0.24, 0.12, 0.06) })
	r:Face({ Mood = "calm", EyeY = 0.05, BrowColor = P.Gray })
	r:Hands(P.White, M.Metal)
	-- полумесяц-нимб
	local pts = {}
	for i = 0, 7 do
		local a = math.rad(-110 + i * 31)
		pts[#pts + 1] = V(math.sin(a) * 0.95, 1.35 + math.cos(a) * 0.3, 0.3 + math.cos(a) * 0.2)
	end
	r:Chain(H, pts, 0.16, MOON, M.Neon, 1, true)
	-- две пары крыльев
	local ws = lv >= 4 and 1.2 or 1
	for pair = 1, 2 do
		for _, side in ipairs({ 1, -1 }) do
			local name = (side == 1 and "WingR" or "WingL") .. (pair == 2 and "2" or "")
			local y = pair == 1 and 0.6 or -0.2
			local wing = r:Joint(name, T, V(2.8 * ws, 0.45, 0.25), CF(0.3 * side, y, 0.55), CF(1.4 * ws * side, 0.45, 0.15) * ANG(0, 0, rad((pair == 1 and 25 or -10) * side)), P.White)
			for i = 1, 4 do
				local len = (2.2 - i * 0.3) * ws * (pair == 2 and 0.75 or 1)
				r:Box(wing, V(0.5 * ws, len, 0.18), CF((-1.2 + i * 0.55) * ws * side, -len / 2 + 0.1, 0.05) * ANG(0, 0, rad(-10 * side)), i % 2 == 0 and MOON or P.White)
			end
		end
	end
	-- копьё-луч
	local sl = lv >= 5 and 1.2 or 1
	r:Cyl(RA, 6.2 * sl, 0.24, CF(0, 0.3, -0.55), P.White, M.Metal, "Y")
	r:Cyl(RA, 0.25, 0.5, CF(0, 3.1 * sl + 0.2, -0.55), P.Gold, M.Metal, "Y")
	local tip = r:Neon(RA, V(0.35, 1.6 * sl, 0.12), CF(0, 4.1 * sl + 0.2, -0.55), Color3.fromRGB(255, 180, 210))
	tip.Name = "Muzzle"
	r.Muzzle = tip
	r:WeaponTrail(RA, V(0, 3.0 * sl, -0.55), V(0, 5.0 * sl, -0.55), MOON)
	r:Glow(tip, Color3.fromRGB(255, 180, 210), 8, 1.5)
	if lv >= 3 then
		r:Orbit("OrbitStars", H, CF(0, 1.4, 0.2), 1.4, 4, 0.2, MOON)
	end
	if lv >= 5 then
		r:Cape(1.8, 3.4, Color3.fromRGB(240, 200, 220), true)
	end
	levelAura(r, lv, MOON)
	return r:Finish(1.35, { RS = { 10, 0, 0 } })
end

local function CrimsonEclipse(lv)
	local r = Rig.new({ Name = "CrimsonEclipse", Torso = P.Black, Arm = P.Black, Leg = P.Black, Head = P.Black, HeadSize = V(1.4, 1.4, 1.4), TorsoMat = M.Metal })
	local T, H, RA, LA, RL, LL = r.Torso, r.Head, r.RArm, r.LArm, r.RLeg, r.LLeg
	r:Box(T, V(2.6, 2.0, 1.5), CF(0, 0.2, 0), P.Black, M.Metal)
	r:Box(T, V(2.3, 1.7, 1.35), CF(0, -1.7, 0), BLOOD, M.Fabric)
	for _, c in ipairs({ { V(-0.9, 0.9, -0.77), V(-0.1, 0.0, -0.77) }, { V(-0.1, 0.0, -0.77), V(0.7, -0.6, -0.77) }, { V(0.6, 0.9, -0.77), V(0.2, 0.3, -0.77) } }) do
		r:Seg(T, c[1], c[2], 0.12, RED, M.Neon)
	end
	-- капюшон-шлем
	r:Sphere(H, V(1.7, 1.6, 1.7), CF(0, 0.15, 0.05), P.Black, M.Metal)
	r:Box(H, V(1.2, 0.5, 0.2), CF(0, -0.05, -0.75), Color3.fromRGB(10, 0, 5))
	r:Eyes(RED, { Y = 0.0, Spacing = 0.3, Size = V(0.3, 0.12, 0.06), Tilt = -15, Inset = -0.1 })
	-- диск затмения за головой
	r:Cyl(H, 0.15, 3.0, CF(0, 0.4, 1.0), RED, M.Neon, "Z")
	r:Cyl(H, 0.2, 2.5, CF(0.15, 0.45, 1.05), P.Black, M.Plastic, "Z")
	r:Pauldron(RA, 1, 1.2, P.Black, RED, 0.1, M.Neon)
	r:Pauldron(LA, -1, 1.15, P.Black, BLOOD, 0.1)
	r:Hands(P.Black, M.Metal)
	r:Cape(2.5, 4.0, BLOOD, true)
	-- огромная красная коса
	r:Cyl(RA, 6.4, 0.28, CF(0, 0.2, -0.55), P.Black, M.Metal, "Y")
	local top = V(0, 3.35, -0.55)
	local bl = lv >= 5 and 1.35 or 1.1
	local pts = { top, top + V(0, 0.2, -1.0) * bl, top + V(0, -0.05, -2.0) * bl, top + V(0, -0.6, -2.9) * bl, top + V(0, -1.4, -3.4) * bl }
	r:Chain(RA, pts, 0.5, P.Black, M.Metal, 0.85)
	local edge = {}
	for i, p in ipairs(pts) do
		edge[i] = p + V(0, -0.25, 0)
	end
	r:Chain(RA, edge, 0.14, RED, M.Neon, 1)
	r:Ball(RA, 0.6, CF(top), RED, M.Neon)
	r.Muzzle = r:Box(RA, V(0.2, 0.2, 0.2), CF(top + V(0, -0.6, -2.5) * bl), P.Black, M.Plastic, { Transparency = 1, Name = "Muzzle" })
	r:WeaponTrail(RA, top + V(0, -0.2, -0.8) * bl, top + V(0, -1.4, -3.4) * bl, RED)
	-- капли крови на орбите
	local hub = r:Orbit("OrbitBlood", T, CF(0, 0.5, 0), 2.4, 0, 0.3, RED)
	for i = 0, (lv >= 3 and 6 or 4) - 1 do
		local a = i / (lv >= 3 and 6 or 4) * math.pi * 2
		r:Sphere(hub, V(0.35, 0.5, 0.35), CF(math.cos(a) * 2.4, math.sin(a * 2) * 0.3, math.sin(a) * 2.4), RED, M.Neon)
	end
	if lv >= 2 then
		r:Horn(H, 1, V(0.6, 0.5, 0.1), 1.1, P.Black)
		r:Horn(H, -1, V(-0.6, 0.5, 0.1), 1.1, P.Black)
	end
	if lv >= 4 then
		r:Sparkles(T, RED, { Rate = 14, Size = 0.4, Up = 2 })
	end
	levelAura(r, lv, RED)
	return r:Finish(1.5, { RS = { 8, 0, 0 } })
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
}

-- Построить модель юнита. Модель стоит в начале координат, ноги на высоте -HipHeight.
-- Аура редкости у ног: Epic — фиолетовые искры, Legendary — золото, Mythic — красно-фиолетовый вихрь
local applyLevelSkin
local UNIT_RARITY = {
	AbyssReaper = "Epic", CorruptedSamurai = "Epic", VoidPuppeteer = "Epic", MoonWitch = "Epic",
	EclipseGuardian = "Legendary", FallenAngel = "Legendary", Starbreaker = "Legendary", BloodfangWarlord = "Legendary",
	VoidEmperor = "Mythic", AbyssOverlord = "Mythic", RiftMonarch = "Mythic", LunarSeraph = "Mythic",
	RealityDestroyer = "Secret", CrimsonEclipse = "Secret",
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
	Mythic = Color3.fromRGB(230, 50, 140), Secret = Color3.fromRGB(230, 30, 40),
}
applyLevelSkin = function(model, lv, rarity)
	local tint = RARITY_TINT[rarity or ""] or Color3.fromRGB(150, 110, 230)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and d.Transparency < 1 then
			local mat = d.Material
			if mat == M.Metal then
				if lv == 1 then
					d.Material = Enum.Material.CorrodedMetal
				elseif lv >= 4 then
					d.Material = Enum.Material.Foil
					if lv >= 5 then
						d.Color = d.Color:Lerp(tint, 0.18)
					end
				end
			elseif mat == M.Plastic and lv == 1 then
				d.Material = Enum.Material.Plastic
			elseif mat == M.Fabric and lv >= 5 then
				d.Color = d.Color:Lerp(tint, 0.1)
			end
		end
	end
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

return UnitModels
]======] }
FILES[#FILES + 1] = { "ReplicatedStorage", { "VoidTD", "EnemyModels" }, "ModuleScript", [======[
--!nocheck
-- VOID TD :: EnemyModels
-- Блочные модели врагов. EnemyModels.Build(enemyId) -> rig { Model, Motors, Base, Style, HipHeight, Height }

local UnitModels = require(script.Parent.UnitModels)
local Config = require(script.Parent.Config)

local Rig = UnitModels.Rig
local P = UnitModels.Palette

local V = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles
local rad = math.rad

local M = {
	Plastic = Enum.Material.SmoothPlastic,
	Metal = Enum.Material.Metal,
	Neon = Enum.Material.Neon,
	Fabric = Enum.Material.Fabric,
	Slate = Enum.Material.Slate,
}

local EnemyModels = {}

------------------------------------------------------------------------
-- Существо без человеческого скелета: Root -> Body (мотор "Root")
------------------------------------------------------------------------
local function newCreature(name, bodySize, bodyColor, bodyMat)
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
	body.Color = bodyColor
	body.Material = bodyMat or M.Plastic
	body.CanCollide = false
	body.CanTouch = false
	body.Massless = true
	body.TopSurface = Enum.SurfaceType.Smooth
	body.BottomSurface = Enum.SurfaceType.Smooth
	body.CFrame = CF()
	body.Parent = model
	self.Torso = body
	self.Pending = {}
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

local function finishCreature(self, scale, hip, height, style)
	self:Finish(scale)
	self.HipHeight = hip * scale
	self.Height = height * scale
	self.Style = style
	self.Model:SetAttribute("HipHeight", self.HipHeight)
	return self
end

local function finishBiped(self, scale, style)
	-- self:Finish(...) уже вызван
	self.Height = (3 + 1 + self.HeadSize.Y + 0.6) * scale
	self.Style = style or "Biped"
	return self
end

------------------------------------------------------------------------
-- 1. LOST SOUL — маленький призрачный огонёк
------------------------------------------------------------------------
local function LostSoul(scale)
	local r = newCreature("LostSoul", V(1.6, 1.6, 1.4), P.Pale)
	local B = r.Torso
	B.Transparency = 0.25
	table.insert(r.Pending, B) -- тело-эллипсоид
	r.Head = B
	r.HeadSize = B.Size
	r:Eyes(P.Neon, { Y = 0.15, Spacing = 0.32, Size = V(0.3, 0.3, 0.06) })
	r:Sphere(B, V(0.45, 0.3, 0.1), CF(0, -0.3, -0.68), P.Black) -- рот
	r:Wedge(B, V(1.2, 0.9, 1.0), CF(0, -1.2, 0.1) * ANG(0, 0, math.pi), P.Pale, M.Plastic, { Transparency = 0.35 })
	r:Wedge(B, V(0.6, 0.7, 0.6), CF(0.1, -1.8, 0.4) * ANG(0, 0, math.pi), P.Pale, M.Plastic, { Transparency = 0.5 })
	r:Joint("ArmR", B, V(0.35, 0.9, 0.35), CF(0.8, 0, 0), CF(0.25, -0.35, 0) * ANG(0, 0, rad(25)), P.Pale)
	r:Joint("ArmL", B, V(0.35, 0.8, 0.35), CF(-0.8, 0, 0), CF(-0.25, -0.35, 0) * ANG(0, 0, rad(-25)), P.Pale)
	r:Glow(B, P.Neon, 6, 0.8)
	return finishCreature(r, scale, 2.4, 3.2, "Float")
end

------------------------------------------------------------------------
-- 2. VOID CRAWLER — четырёхлапый жук
------------------------------------------------------------------------
local function VoidCrawler(scale)
	local r = newCreature("VoidCrawler", V(2.2, 1.0, 2.8), P.DeepViolet)
	local B = r.Torso
	r:Sphere(B, V(2.3, 1.1, 2.8), CF(0, 0.5, 0.15) * ANG(rad(-4), 0, 0), P.Coal, M.Metal) -- панцирь
	r:Sphere(B, V(1.3, 0.6, 1.2), CF(0.1, 0.95, 0.5), P.Black, M.Metal)
	r:Neon(B, V(0.1, 0.12, 2.2), CF(0, 0.88, 0.1), P.Neon)
	r:Sphere(B, V(1.35, 0.95, 1.1), CF(0, 0.05, -1.75), P.Coal)
	r:Wedge(B, V(0.25, 0.3, 0.8), CF(-0.4, -0.25, -2.5) * ANG(0, 0, 0), P.Pale)
	r:Wedge(B, V(0.25, 0.3, 0.7), CF(0.42, -0.22, -2.45), P.Pale)
	r:Ball(B, 0.26, CF(-0.33, 0.2, -2.22), P.Neon, M.Neon)
	r:Ball(B, 0.26, CF(0.35, 0.22, -2.22), P.Neon, M.Neon)
	r:Ball(B, 0.2, CF(0.05, 0.4, -2.2), P.NeonPink, M.Neon)
	local legs = { { "FR", 1, -0.8 }, { "FL", -1, -0.8 }, { "BR", 1, 0.8 }, { "BL", -1, 0.8 } }
	for _, l in ipairs(legs) do
		local leg = r:Joint(l[1], B, V(0.32, 1.5, 0.32), CF(1.05 * l[2], -0.1, l[3]), CF(0.45 * l[2], -0.6, 0) * ANG(0, 0, rad(32 * l[2])), P.Black)
		r:Box(leg, V(0.3, 0.6, 0.3), CF(0, -0.85, 0) * ANG(0, 0, rad(-40 * l[2])), P.Coal)
	end
	return finishCreature(r, scale, 1.3, 2.4, "Quad")
end

------------------------------------------------------------------------
-- 3. SHADOW BEAST — быстрый теневой волк
------------------------------------------------------------------------
local function ShadowBeast(scale)
	local r = newCreature("ShadowBeast", V(1.6, 1.4, 3.0), P.Black)
	local B = r.Torso
	r.Head = r:Joint("Neck", B, V(1.3, 1.2, 1.4), CF(0, 0.4, -1.4), CF(0, 0.2, -0.6), P.Black)
	r.HeadSize = r.Head.Size
	r:Box(r.Head, V(0.8, 0.6, 0.9), CF(0, -0.25, -1.0), P.Coal)
	r:Box(r.Head, V(0.75, 0.15, 0.85), CF(0, -0.6, -0.95), P.Maroon)
	r:Wedge(r.Head, V(0.3, 0.6, 0.4), CF(-0.42, 0.85, 0.2), P.Black)
	r:Wedge(r.Head, V(0.3, 0.55, 0.4), CF(0.42, 0.8, 0.25) * ANG(0, 0, rad(-12)), P.Black)
	r:Eyes(P.Neon, { Y = 0.2, Spacing = 0.33, Size = V(0.28, 0.12, 0.06), Tilt = -15 })
	for i = 0, 3 do
		r:Wedge(B, V(0.25, 0.4 + (i % 2) * 0.2, 0.5), CF(0, 0.85, -0.9 + i * 0.6), P.DeepViolet)
	end
	r:Chain(B, { V(0, 0.4, 1.5), V(0, 0.8, 2.2), V(0.2, 1.3, 2.6) }, 0.32, P.Black, M.Plastic, 0.75, true)
	r:Sphere(r.Head, V(0.5, 0.4, 0.4), CF(0, -0.2, -1.5), P.Black) -- нос
	local legs = { { "FR", 0.55, -1.1 }, { "FL", -0.55, -1.1 }, { "BR", 0.55, 1.1 }, { "BL", -0.55, 1.1 } }
	for _, l in ipairs(legs) do
		local leg = r:Joint(l[1], B, V(0.5, 1.5, 0.5), CF(l[2], -0.5, l[3]), CF(0, -0.75, 0), P.Black)
		r:Box(leg, V(0.55, 0.25, 0.7), CF(0, -0.68, -0.1), P.Coal)
	end
	r:Sparkles(B, P.DeepViolet, { Rate = 6, Size = 0.4 })
	return finishCreature(r, scale, 2.0, 3.2, "Quad")
end

------------------------------------------------------------------------
-- 4. ARMORED HORROR — бронированный
------------------------------------------------------------------------
local function ArmoredHorror(scale)
	local r = Rig.new({ Name = "ArmoredHorror", Torso = P.Steel, Arm = P.Dark, Leg = P.Dark, Head = P.Coal, TorsoMat = M.Metal })
	local T, H, RA, LA, RL, LL = r.Torso, r.Head, r.RArm, r.LArm, r.RLeg, r.LLeg
	r:Box(T, V(2.5, 2.1, 1.5), CF(0, 0.1, 0), P.Steel, M.Metal)
	r:Box(T, V(2.2, 0.3, 0.2), CF(0, 0.2, -0.8), P.Neon, M.Neon)
	r:Box(H, V(1.55, 1.5, 1.55), CF(0, 0.05, 0), P.Gray, M.Metal)
	r:Box(H, V(1.1, 0.12, 0.08), CF(0, 0.05, -0.8), P.NeonPink, M.Neon)
	for i = -1, 1 do
		r:Wedge(H, V(0.25, 0.6, 0.4), CF(i * 0.5, 1.05, 0), P.Steel, M.Metal)
	end
	r:Pauldron(RA, 1, 1.0, P.Gray, P.Steel)
	r:Pauldron(LA, -1, 0.95, P.Gray, P.Steel)
	r:Cyl(LA, 0.3, 2.6, CF(-0.7, -0.6, -0.2), P.Steel, M.Metal, "X") -- круглый щит
	r:Cyl(LA, 0.2, 2.8, CF(-0.66, -0.6, -0.2), P.Dark, M.Metal, "X")
	r:Sphere(LA, V(0.3, 0.8, 0.8), CF(-0.88, -0.6, -0.2), P.Neon, M.Neon)
	r:Box(RL, V(1.15, 1.2, 1.2), CF(0, -0.4, 0), P.Gray, M.Metal)
	r:Box(LL, V(1.15, 1.2, 1.2), CF(0, -0.4, 0), P.Gray, M.Metal)
	r:Box(RA, V(1.15, 1.2, 1.15), CF(0, -0.4, 0), P.Steel, M.Metal)
	return finishBiped(r:Finish(scale), scale)
end

------------------------------------------------------------------------
-- 5. RIFT PHANTOM — призрачный
------------------------------------------------------------------------
local function RiftPhantom(scale)
	local r = newCreature("RiftPhantom", V(1.8, 2.0, 1.1), P.DeepViolet)
	local B = r.Torso
	B.Transparency = 0.35
	r.Head = r:Joint("Neck", B, V(1.3, 1.3, 1.3), CF(0, 1.0, 0), CF(0, 0.65, 0), P.Black)
	r.HeadSize = r.Head.Size
	r:Box(r.Head, V(1.55, 0.3, 1.55), CF(0, 0.75, 0.05), P.DeepViolet, M.Fabric, { Transparency = 0.3 })
	r:Box(r.Head, V(0.25, 1.4, 1.55), CF(-0.72, 0.0, 0.05), P.DeepViolet, M.Fabric, { Transparency = 0.3 })
	r:Box(r.Head, V(0.25, 1.4, 1.55), CF(0.72, 0.0, 0.05), P.DeepViolet, M.Fabric, { Transparency = 0.3 })
	r:Wedge(r.Head, V(0.7, 1.2, 1.0), CF(0, 0.8, 0.7) * ANG(rad(-30), 0, 0), P.DeepViolet, M.Fabric, { Transparency = 0.3 })
	r:Eyes(P.NeonSoft, { Y = 0.0, Spacing = 0.28, Size = V(0.3, 0.1, 0.06), Tilt = 10 })
	-- плащ сужается книзу
	for i = 1, 4 do
		local w = 1.8 - i * 0.32
		r:Cyl(B, 0.6, w, CF(0.05 * (i % 2), -1.0 - i * 0.5, 0.05 * i), P.DeepViolet, M.Fabric, "Y", { Transparency = 0.3 + i * 0.1 })
	end
	r:Neon(B, V(0.12, 1.8, 0.06), CF(0.4, 0, -0.58), P.Neon, { Transparency = 0.2 })
	for _, s in ipairs({ 1, -1 }) do
		local arm = r:Joint(s == 1 and "ArmR" or "ArmL", B, V(0.5, 2.2, 0.5), CF(1.1 * s, 0.7, 0), CF(0.1 * s, -1.0, 0), P.DeepViolet)
		arm.Transparency = 0.3
		for k = -1, 1 do
			r:Wedge(arm, V(0.12, 0.5, 0.2), CF(k * 0.15, -1.3, -0.1) * ANG(0, 0, math.pi), P.NeonSoft, M.Neon)
		end
	end
	r:Sparkles(B, P.Neon, { Rate = 10, Size = 0.35 })
	r:Glow(B, P.Neon, 8, 1)
	return finishCreature(r, scale, 3.3, 4.6, "Float")
end

------------------------------------------------------------------------
-- 6. ABYSS BRUTE — много здоровья
------------------------------------------------------------------------
local function AbyssBrute(scale)
	local r = Rig.new({ Name = "AbyssBrute", Torso = P.Maroon, Arm = P.Maroon, Leg = P.Coal, Head = P.Maroon, HeadSize = V(1.2, 1.1, 1.2) })
	local T, H, RA, LA, RL, LL = r.Torso, r.Head, r.RArm, r.LArm, r.RLeg, r.LLeg
	r:Box(T, V(2.6, 1.6, 1.5), CF(0, 0.45, 0.1), P.Maroon)
	r:Box(T, V(2.2, 0.5, 1.3), CF(0, -0.8, 0), P.Black, M.Metal)
	r:Neon(T, V(0.6, 0.6, 0.08), CF(0, 0.4, -0.67) * ANG(0, 0, rad(45)), P.NeonPink)
	for i = -1, 1 do
		r:Wedge(T, V(0.3, 0.7, 0.6), CF(i * 0.7, 1.4, 0.6) * ANG(rad(-20), 0, 0), P.Pale)
	end
	r:Box(H, V(1.3, 0.5, 0.2), CF(0, -0.3, -0.6), P.Black)
	r:Wedge(H, V(0.12, 0.3, 0.15), CF(-0.3, -0.62, -0.68) * ANG(0, 0, math.pi), P.White)
	r:Wedge(H, V(0.12, 0.3, 0.15), CF(0.32, -0.62, -0.68) * ANG(0, 0, math.pi), P.White)
	r:Eyes(P.NeonPink, { Y = 0.15, Spacing = 0.28, Size = V(0.22, 0.12, 0.06), Tilt = -12 })
	r:Horn(H, 1, V(0.55, 0.3, 0), 0.7, P.Pale)
	r:Horn(H, -1, V(-0.55, 0.3, 0), 0.6, P.Pale)
	-- огромные руки
	r:Box(RA, V(1.7, 2.2, 1.7), CF(0.15, -0.6, 0), P.Maroon)
	r:Box(LA, V(1.6, 2.1, 1.6), CF(-0.15, -0.6, 0), P.Maroon)
	r:Box(RA, V(1.8, 0.6, 1.8), CF(0.15, -1.6, 0), P.Black, M.Metal)
	r:Box(LA, V(1.7, 0.6, 1.7), CF(-0.15, -1.6, 0), P.Black, M.Metal)
	r:Box(RL, V(1.2, 1.0, 1.2), CF(0, -0.55, 0), P.Black, M.Metal)
	r:Box(LL, V(1.2, 1.0, 1.2), CF(0, -0.55, 0), P.Black, M.Metal)
	r:Finish(scale, { Root = { 10, 0, 0 }, Neck = { -10, 0, 0 } })
	return finishBiped(r, scale)
end

------------------------------------------------------------------------
-- 7. CORRUPTED TITAN — мини-босс
------------------------------------------------------------------------
local function CorruptedTitan(scale)
	local r = Rig.new({ Name = "CorruptedTitan", Torso = P.Coal, Arm = P.Coal, Leg = P.Black, Head = P.Coal, HeadSize = V(1.4, 1.4, 1.4), TorsoMat = M.Slate })
	local T, H, RA, LA, RL, LL = r.Torso, r.Head, r.RArm, r.LArm, r.RLeg, r.LLeg
	r:Box(T, V(2.7, 2.2, 1.6), CF(0, 0.15, 0), P.Coal, M.Slate)
	r:Seg(T, V(-1.0, 1.0, -0.82), V(0.1, 0.0, -0.82), 0.12, P.Neon, M.Neon)
	r:Seg(T, V(0.1, 0.0, -0.82), V(-0.3, -0.9, -0.82), 0.12, P.Neon, M.Neon)
	r:Seg(T, V(0.9, 0.8, -0.82), V(0.4, -0.3, -0.82), 0.12, P.Neon, M.Neon)
	r:Box(H, V(1.6, 1.0, 1.6), CF(0, 0.3, 0), P.Black, M.Slate)
	r:Box(H, V(1.2, 0.14, 0.08), CF(0, -0.05, -0.72), P.Neon, M.Neon)
	local spikes = { -0.6, -0.2, 0.25, 0.6 }
	for i, x in ipairs(spikes) do
		r:Box(H, V(0.25, 0.5 + (i % 2) * 0.35, 0.25), CF(x, 1.0 + (i % 2) * 0.15, -0.5), P.Steel, M.Metal)
	end
	r:Pauldron(RA, 1, 1.15, P.Black, P.Neon, 0, M.Neon)
	r:Pauldron(LA, -1, 1.05, P.Black)
	r:Box(RL, V(1.2, 1.3, 1.2), CF(0, -0.35, 0), P.Coal, M.Slate)
	r:Box(LL, V(1.2, 1.3, 1.2), CF(0, -0.35, 0), P.Coal, M.Slate)
	-- дубина
	r:Cyl(RA, 1.2, 0.38, CF(0, -1.05, -0.2), P.Maroon, M.Fabric, "Z")
	r:Cyl(RA, 2.6, 1.1, CF(0, -1.05, -2.0), P.Black, M.Slate, "Z") -- дубина
	r:Ball(RA, 1.3, CF(0, -1.05, -3.3), P.Black, M.Slate)
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2
		r:Wedge(RA, V(0.3, 0.5, 0.3), CF(math.cos(a) * 0.6, -1.05 + math.sin(a) * 0.6, -2.4 - (i % 2) * 0.6) * ANG(0, 0, a - math.pi / 2), P.Steel, M.Metal)
	end
	r:Cyl(RA, 0.15, 1.15, CF(0, -1.05, -1.4), P.Neon, M.Neon, "Z")
	r:Sparkles(T, P.Neon, { Rate = 12, Size = 0.5 })
	r:Glow(T, P.Neon, 14, 1.5)
	return finishBiped(r:Finish(scale), scale)
end

------------------------------------------------------------------------
-- 8. VOID DEVOURER — огромная пасть
------------------------------------------------------------------------
local function VoidDevourer(scale)
	local r = newCreature("VoidDevourer", V(4.0, 2.6, 4.2), P.DeepViolet)
	local B = r.Torso
	r:Box(B, V(4.2, 1.0, 4.0), CF(0, 1.6, 0.1) * ANG(rad(-5), 0, rad(2)), P.Black, M.Slate)
	r:Box(B, V(2.4, 0.9, 2.2), CF(0.3, 2.3, 0.6), P.Coal, M.Slate)
	-- глаза (асимметричные)
	local eyes = { { -1.2, 0.8, 0.5 }, { 1.1, 0.9, 0.42 }, { -0.4, 1.2, 0.3 }, { 0.5, 0.6, 0.3 }, { 1.6, 0.4, 0.25 } }
	for _, e in ipairs(eyes) do
		r:Ball(B, e[3] * 1.2, CF(e[1], e[2], -2.08), P.NeonPink, M.Neon)
	end
	-- верхние зубы
	for i = -3, 3 do
		r:Wedge(B, V(0.35, 0.6, 0.4), CF(i * 0.55, -1.55, -1.9) * ANG(0, 0, math.pi), P.White)
	end
	-- нижняя челюсть на моторе
	local jaw = r:Joint("Jaw", B, V(3.8, 0.8, 3.8), CF(0, -1.2, 1.6), CF(0, -0.4, -1.7), P.Coal)
	for i = -3, 3 do
		r:Wedge(jaw, V(0.32, 0.55, 0.35), CF(i * 0.52, 0.65, -1.65), P.White)
	end
	r:Neon(jaw, V(3.0, 0.1, 2.6), CF(0, 0.41, -0.2), P.Maroon, { Material = M.Plastic })
	-- лапы
	local legs = { { "FR", 1.6, -1.2 }, { "FL", -1.6, -1.2 }, { "BR", 1.6, 1.4 }, { "BL", -1.6, 1.4 } }
	for _, l in ipairs(legs) do
		local leg = r:Joint(l[1], B, V(1.0, 1.8, 1.0), CF(l[2], -1.0, l[3]), CF(0, -0.9, 0), P.Black)
		r:Wedge(leg, V(0.9, 0.4, 0.4), CF(0, -0.9, -0.6) * ANG(0, math.pi, 0), P.Pale)
	end
	-- щупальца на спине
	for i, x in ipairs({ -1.2, 0, 1.2 }) do
		local lift = 1.6 + (i % 2) * 0.6
		r:Chain(B, { V(x, 1.8, 1.6), V(x * 1.3, 1.8 + lift * 0.6, 2.4), V(x * 1.6, 1.8 + lift, 3.4) }, 0.48, P.Black, M.Plastic, 0.7, true)
		r:Ball(B, 0.4, CF(x * 1.6, 1.8 + lift, 3.4), P.NeonPink, M.Neon)
	end
	r:Sparkles(B, P.NeonPink, { Rate = 14, Size = 0.6 })
	r:Glow(B, P.NeonPink, 16, 1.5)
	return finishCreature(r, scale, 2.6, 5.0, "Quad")
end

------------------------------------------------------------------------
-- 9. THE ENTITY — финальный босс
------------------------------------------------------------------------
local function TheEntity(scale)
	local r = Rig.new({ Name = "TheEntity", Torso = P.Black, Arm = P.Black, Leg = P.Black, Head = P.Black, HeadSize = V(1.3, 1.6, 1.3) })
	local T, H, RA, LA, RL, LL = r.Torso, r.Head, r.RArm, r.LArm, r.RLeg, r.LLeg
	-- вместо ног — рваный шлейф
	RL.Transparency = 1
	LL.Transparency = 1
	for i = 1, 5 do
		local w = 2.2 - i * 0.35
		r:Cyl(T, 0.7, w, CF(math.sin(i) * 0.15, -1.2 - i * 0.6, 0.1 * i), P.Black, M.Plastic, "Y", { Transparency = (i - 1) * 0.12 })
	end
	r:Neon(T, V(0.15, 1.6, 0.06), CF(0, 0.1, -0.52), P.White)
	r:Seg(T, V(-0.8, 0.8, -0.52), V(0, 0.1, -0.52), 0.1, P.Neon, M.Neon)
	r:Seg(T, V(0.8, 0.8, -0.52), V(0, 0.1, -0.52), 0.1, P.Neon, M.Neon)
	-- лицо: белые светящиеся глаза и трещина-рот
	r:Eyes(P.White, { Y = 0.25, Spacing = 0.3, Size = V(0.2, 0.32, 0.06) })
	r:Neon(H, V(0.7, 0.08, 0.06), CF(0, -0.35, -0.68) * ANG(0, 0, rad(-6)), P.Neon)
	-- лишние руки
	for _, s in ipairs({ 1, -1 }) do
		local arm = r:Joint(s == 1 and "ArmR2" or "ArmL2", T, V(0.7, 2.6, 0.7), CF(1.1 * s, -0.2, 0.3), CF(0.5 * s, -1.0, 0) * ANG(0, 0, rad(30 * s)), P.Black)
		r:Neon(arm, V(0.12, 1.8, 0.12), CF(0, 0, -0.36), P.Neon)
	end
	for _, A in ipairs({ RA, LA }) do
		r:Box(A, V(0.6, 1.2, 0.6), CF(0, -1.5, 0), P.Black)
		r:Neon(A, V(0.12, 1.6, 0.06), CF(0, -0.4, -0.52), P.Neon)
	end
	-- кольцо осколков вокруг головы (крутится)
	local halo = r:Joint("Halo", H, V(0.3, 0.3, 0.3), CF(0, 0.6, 0.3), CF(), P.Black)
	halo.Transparency = 1
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		r:Neon(halo, V(0.3, 0.8, 0.12), CF(math.cos(a) * 1.5, 0, math.sin(a) * 1.5) * ANG(0, -a, rad(20)), i % 2 == 0 and P.White or P.Neon)
	end
	r:Sparkles(T, P.Neon, { Rate = 20, Size = 0.6, Up = 2 })
	r:Glow(T, P.White, 18, 1.2)
	r:Finish(scale)
	r.HipHeight = 4.2 * scale
	r.Height = 7 * scale
	r.Style = "Float"
	r.Model:SetAttribute("HipHeight", r.HipHeight)
	return r
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

function EnemyModels.Build(enemyId)
	local def = Config.Enemies[enemyId]
	local builder = Builders[enemyId]
	if not def or not builder then
		error("Unknown enemy " .. tostring(enemyId))
	end
	local rig = builder(def.Scale or 1)
	rig.Model.Name = enemyId
	for _, d in ipairs(rig.Model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CanQuery = false
			d.CastShadow = def.IsBoss == true or d.Name == "Torso"
		end
	end
	return rig
end

return EnemyModels
]======] }
FILES[#FILES + 1] = { "ReplicatedStorage", { "VoidTD", "CaseModels" }, "ModuleScript", [======[
--!nocheck
-- VOID TD :: CaseModels
-- 3D-модели кейсов (витрины в лобби и анимация открытия). Все детали заякорены.
-- CaseModels.Build(caseId) -> { Model, Body, Lid, Core, Shards = {...}, Cracks = {...} }

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

local Builders = { VoidCase = VoidCase, ShatteredReality = ShatteredReality, BloodMoon = BloodMoon }

function CaseModels.Build(caseId)
	local m = Instance.new("Model")
	m.Name = "Case_" .. tostring(caseId)
	local builder = Builders[caseId] or VoidCase
	local r = builder(m)
	m.PrimaryPart = r.Body
	m.WorldPivot = CF(0, 0, 0)
	r.Model = m
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
