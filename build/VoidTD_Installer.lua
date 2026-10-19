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
for _, pair in ipairs({ { RS, "VoidTD" }, { SSS, "VoidTDServer" }, { SPS, "VoidTDClient" }, { workspace, "VoidTDMap" }, { workspace, "VoidTDLobby" } }) do
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
	-- HALLOWEEN CASE: пока выключен (Enabled = false) — в нём есть только Проклятый часовщик,
	-- остальные хэллоуинские юниты, Король фонарей, Ночной сторож и руны ещё не добавлены.
	-- Валюта — Halloween Coins. UnitRates — шанс конкретного юнита в процентах (поверх шансов редкостей).
	Halloween = {
		Name = "HALLOWEEN CASE", Color = Color3.fromRGB(255, 130, 30),
		Description = "Хэллоуин. Проклятый часовщик: 0.2%",
		Enabled = false,
		Currency = "HalloweenCoins",
		Cost1 = 500, Cost10 = 5000,
		Rates = {},
		UnitRates = { CursedClockmaker = 0.2 },
		Units = { "CursedClockmaker" },
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
	-- Halloween Case
	"CursedClockmaker",
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

return UnitModels
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
GameService.Init(remotes, state, unitsFolder, map)

local function pushProfile(player)
	local snap = DataService.Snapshot(player)
	if snap then
		remotes.Profile:FireClient(player, snap)
	end
end

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
			if prof and p:GetAttribute("LastGems") ~= prof.Gems then
				p:SetAttribute("LastGems", prof.Gems)
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
		local zc = c + z.Offset
		local zm = Instance.new("Model")
		zm.Name = key
		zm.Parent = zonesFolder
		cylinderY(zm, "PadBase", z.Radius + 1.2, 0.6, zc + V(0, 0.3, 0), C.Stone2)
		cylinderY(zm, "PadEdge", z.Radius + 0.5, 0.65, zc + V(0, 0.33, 0), z.Color, Enum.Material.Neon)
		local pad = cylinderY(zm, "Pad", z.Radius, 0.7, zc + V(0, 0.36, 0), Color3.fromRGB(25, 15, 40), Enum.Material.Glass, { Transparency = 0.15 })
		local beam = cylinderY(zm, "LightBeam", z.Radius * 0.9, 26, zc + V(0, 13, 0), z.Color, Enum.Material.Neon, { CanCollide = false, Transparency = 0.88 })
		beam.CastShadow = false
		emitter(pad, z.Color, { Rate = 14, Size = 0.5, SpeedMin = 2, SpeedMax = 4, Spread = 10, Dir = Enum.NormalId.Right, LifeMin = 1.5, LifeMax = 2.5 })
		light(pad, z.Color, 18, 2)
		billboard(zm, zc + V(0, 8.5, 0), z.Title, "встань в круг", z.Color, 12)
		zm:SetAttribute("Zone", key)
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
	p.HalloweenCoins = tonumber(p.HalloweenCoins) or 0
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
	}
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
	local cost = (count == 10) and case.Cost10 or case.Cost1
	local currency = case.Currency or "Gems"
	if (p[currency] or 0) < cost then
		return false, currency == "Gems" and "Недостаточно кристаллов" or "Недостаточно Halloween Coins"
	end
	p[currency] = p[currency] - cost
	if currency == "Gems" then
		player:SetAttribute("Gems", p.Gems)
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
	teleport(player, Config.BattleSpawn)
end

local function toLobby(player)
	teleport(player, Config.Lobby.Spawn)
end

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
	removeEnemy(e, "kill")
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
	local dmg = math.max(1, math.floor(amount * (1 - e.Armor) + 0.5))
	e.Health = e.Health - dmg
	pushDamage(e.Id, dmg, crit and 1 or 0)
	if unit then
		unit.DamageDealt = unit.DamageDealt + math.min(dmg, dmg + e.Health)
	end
	if e.Health <= 0 then
		killEnemy(e)
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
		notifyAll({ Type = "Victory", Wave = wave, Gems = g, Reset = S.ResetDelay, Difficulty = difficultyKey })
	else
		for _, pl in ipairs(matchPlayers()) do
			local prof = DataService.Get(pl)
			if prof then
				prof.Stats.BestWave = math.max(prof.Stats.BestWave or 0, wave - 1)
				DataService.Save(pl, true)
			end
		end
		notifyAll({ Type = "Defeat", Wave = wave, Reset = S.ResetDelay, Difficulty = difficultyKey })
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
	if wave >= S.MaxWave then
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
	local groups = Config.Waves[wave] or {}
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

local function removeUnit(u)
	u.Alive = false
	units[u.Uid] = nil
	if u.Folder then
		u.Folder:Destroy()
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
	raycastParams.FilterDescendantsInstances = { Map }
	local hit = workspace:Raycast(Vector3.new(pos.X, Config.Map.GroundY + 30, pos.Z), Vector3.new(0, -60, 0), raycastParams)
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
	local payload = { U = u.Uid, T = targetIds, L = u.Level }
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
			applyDot(e, opts.Bleed, opts.BleedTime or 3, u, "Bleed")
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

local function attack(u, stats, list)
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
		if def.EveryNth then
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
					aoeHit(u, center, stats.Explode, stats, "Crystal", { Exclude = e, Mult = def.ExplodeMult or 0.5 })
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
		u.ChronoCount = (u.ChronoCount or 0) + 1
		if u.ChronoCount >= tb.EveryNth and t0 - (u.LastBreak or -1e9) >= tb.MinInterval then
			u.ChronoCount = 0
			u.LastBreak = t0
			u.NextAttack = math.max(u.NextAttack or 0, t0 + 1.6)
			later(hitDelay + 0.45, function()
				castTimeBreak(u, stats)
			end)
		end
	elseif atype == "Pierce" then
		-- луч насквозь: все враги на линии от юнита через цель
		local dir = Vector3.new(target.Pos.X - u.Pos.X, 0, target.Pos.Z - u.Pos.Z)
		if dir.Magnitude < 0.1 then
			dir = Vector3.new(0, 0, -1)
		end
		local endPos = u.Pos + dir.Unit * (stats.Range + 4)
		fireAttack(u, { target.Id }, { D = hitDelay, E = endPos })
		later(hitDelay, function()
			Remotes.Impact:FireAllClients({ K = "Pierce", P = u.Pos, E = endPos, L = u.Level, U = u.Uid })
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
					local slow = z.Slow * (e.IsBoss and S.BossSlowResist or 1)
					e.SlowUntil = t + z.Tick + 0.15
					e.SlowAmount = math.max(slow, (e.SlowUntil > t and e.SlowAmount) or 0)
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
		if t >= u.NextAttack then
			local list = candidates(u, stats.Range)
			if #list > 0 then
				-- ускорение времени: союзник атакует чаще, урон за удар прежний
				local cd = stats.Cooldown
				if (u.HasteUntil or 0) > t then
					cd = cd / (1 + (u.Haste or 0))
				end
				u.NextAttack = t + cd
				attack(u, stats, list)
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
			Remotes.Impact:FireAllClients({ K = "Summon", P = s[4], R = 6 })
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
	Remotes.Sync:FireAllClients({ T = t, E = list, DMG = damageBuffer, RM = removedBuffer })
	damageBuffer = {}
	removedBuffer = {}
end

local function step(dt)
	local t = now()
	if phase == "Wave" or phase == "Intermission" or phase == "Prep" then
		updateEnemies(t, dt)
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
	wave = 0
	waveSpawning = false
	nextWaveAt = 0
	setState("Wave", 0)
	setState("NextWaveAt", 0)
	setState("MatchId", matchId)
end

-- Матч закончен (или все ушли): все возвращаются в лобби
resetMatch = function()
	clearMatch()
	phase = "Idle"
	setState("Phase", phase)
	setState("Difficulty", "")
	for _, pl in ipairs(Players:GetPlayers()) do
		if inMatch(pl) then
			pl:SetAttribute("InMatch", false)
			setMoney(pl, 0)
			-- чёрный экран-переход, затем телепорт в лобби
			Remotes.Notify:FireClient(pl, { Type = "Fade", Text = "ЛОББИ" })
			task.delay(0.45, function()
				toLobby(pl)
			end)
		end
	end
	notifyAll({ Type = "Reset" })
end

local function startNewMatch(diffKey)
	clearMatch()
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
	toLobby(player)
	if #matchPlayers() == 0 and phase ~= "Idle" then
		resetMatch()
	end
	return true
end

function GameService.GetMatchInfo()
	return { Phase = phase, Difficulty = difficultyKey, Wave = wave, Players = #matchPlayers() }
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
			toLobby(player)
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

function GameService.Init(remotes, state, unitsFolder, map)
	Remotes, State, UnitsFolder, Map = remotes, state, unitsFolder, map
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
	return { Units = units, Enemies = enemies, Spawn = spawnEnemy, Now = now }
end

return GameService
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
	for _, name in ipairs({ "VoidTDMap", "VoidTDLobby" }) do
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
		local core = workspace:FindFirstChild("VoidTDMap") and workspace.VoidTDMap:FindFirstChild("VoidCore")
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
end)

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
local ZONE_MODAL = { Units = "Inventory", Play = "Mode" }
for key, z in pairs(ctx.Config.Lobby.Zones) do
	if z.Case then
		ZONE_MODAL[key] = "Summon"
	end
end
local zoneState = {}

local function updateZones()
	if player:GetAttribute("InMatch") then
		if next(zoneState) then
			for key in pairs(zoneState) do
				UI.Show(ZONE_MODAL[key], false)
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
	local L = ctx.Config.Lobby
	local pos = root.Position
	for key, z in pairs(L.Zones) do
		local c = L.Center + z.Offset
		local flat = Vector3.new(pos.X - c.X, 0, pos.Z - c.Z).Magnitude
		local inside = flat <= z.Radius + 0.5 and math.abs(pos.Y - c.Y) < 8
		if inside ~= (zoneState[key] == true) then
			zoneState[key] = inside or nil
			if inside and z.Case then
				UI.SelectCase(z.Case)
			end
			UI.Show(ZONE_MODAL[key], inside)
			if inside then
				FX.Sound("Click", 1, 1)
			end
		end
	end
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
	local p
	if kind == "Arrow" then
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
	trail.Color = ColorSequence.new(kind == "Orb" and NEON or NEON_SOFT)
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
local function portalSurge(isFinal)
	local map = workspace:FindFirstChild("VoidTDMap")
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
		local gy = Config.Map.GroundY
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
		local speed = v.Speed * (v.Frozen and 0 or (v.Slowed and 0.5 or 1))
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
	if isNew and placeFx == "Clock" then
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
	playAnim(view, def.Anim, h, hits, p.I)
	view.GustT = os.clock()
	view.NextFidget = os.clock() + 6 + math.random() * 6

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
	refs.Rarity.Text = def.Rarity:upper()
	refs.Rarity.TextColor3 = rc
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
	if rarity == "Mythic" then
		spawnParticles(glow, 14)
	elseif rarity == "Secret" then
		spawnParticles(glow, 10)
	else
		spawnParticles(glow, 0)
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
	if not state or not state.Rig then
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
	Renderer.PreviewStep(state, t)
	if #refs.Particles > 0 then
		stepParticles(t)
	end
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

previewFx = function(kind)
	local s = state.Rig.Scale or 1
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
	buildModel(false)
	refreshInfo()
	applyRarityFx(true)
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
	buildModel(true)
	refreshInfo()
	if FX then
		FX.Sound("Upgrade", 0.6, 0.9 + lv * 0.05)
	end
end

function UnitViewer.PlayAnim(kind)
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
	clearScene()
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
	refs.CaseBuy1.Text = "x1  💎" .. case.Cost1
	refs.CaseBuy10.Text = "x10  💎" .. case.Cost10
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
	end
end

local function showCards(overlay, results)
	local grid = new("Frame", { Parent = overlay, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(5 * 150, (#results > 5 and 2 or 1) * 200), Position = UDim2.fromScale(0.5, 0.55), ZIndex = 22 }, {
		new("UIGridLayout", { CellSize = UDim2.fromOffset(140, 190), CellPadding = UDim2.fromOffset(10, 10), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	for i, r in ipairs(results) do
		task.delay(0.15 * i, function()
			local def = Config.Units[r.Id]
			local rc = rarityColor(r.Id)
			local card = panel({ Parent = grid, BackgroundColor3 = THEME.BG2, StrokeColor = rc, LayoutOrder = i, ZIndex = 23 })
			new("UIGradient", { Parent = card, Rotation = 90, Color = ColorSequence.new(rc:Lerp(THEME.BG, 0.55), THEME.BG) })
			local sc = new("UIScale", { Parent = card, Scale = 0 })
			viewport(card, r.Id, 1, { Size = UDim2.new(1, 0, 0, 120), Position = UDim2.fromOffset(0, 8), ZIndex = 24 })
			label({ Parent = card, Size = UDim2.new(1, -8, 0, 22), Position = UDim2.fromOffset(4, 130), Text = def.Name, ZIndex = 24 })
			label({ Parent = card, Size = UDim2.new(1, -8, 0, 18), Position = UDim2.fromOffset(4, 154), Text = def.Rarity:upper(), TextColor3 = rc, ZIndex = 24 })
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
		best = math.max(best, Config.Rarities[Config.Units[r.Id].Rarity].Order)
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
			playCaseOpening(selectedCase, res)
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
	refs.InvEquip.Text = equipped and "UNEQUIP" or "EQUIP"
	refs.InvEquip.BackgroundColor3 = equipped and Color3.fromRGB(130, 50, 60) or Color3.fromRGB(60, 130, 80)
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
		end
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
	local sub = victory and ("Пустота отступила! Награда: 💎" .. tostring(payload.Gems)) or ("Ядро Пустоты разрушено на волне " .. tostring(payload.Wave))
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
		tween(f, 0.4, { BackgroundColor3 = THEME.Accent })
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
		UI.Toast("Бой окончен. Ты в лобби — встань в круг ИГРАТЬ", "good")
	end
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
end

local lastRefresh = 0
function UI.Update(dt)
	local State = ctx.State
	local money = player:GetAttribute("Money") or 0
	refs.Money.Text = Config.FormatNumber(money)
	local gems = player:GetAttribute("Gems") or (ctx.Profile and ctx.Profile.Gems) or 0
	refs.Gems.Text = Config.FormatNumber(gems)
	if refs.SummonGems then
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
	refs.Currency.Size = UDim2.fromOffset(230, inMatch and 92 or 50)
	refs.Gems.Position = UDim2.fromOffset(52, inMatch and 50 or 8)
	refs.GemsIcon.Position = UDim2.fromOffset(10, inMatch and 49 or 7)
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
	refs.CoreText.Text = "VOID CORE  " .. hp .. " / " .. maxHp

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
	UI.Kit = { new = new, corner = corner, stroke = stroke, label = label, button = button, panel = panel, tween = tween }
	UI.SpecialText = specialText
	UnitViewer.Init(c, UI)
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
	local map = workspace:FindFirstChild("VoidTDMap")
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
