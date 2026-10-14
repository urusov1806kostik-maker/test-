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
	DataStoreName = "VoidTD_Data_v1",
	SyncRate = 0.1,               -- как часто сервер рассылает позиции врагов
}

------------------------------------------------------------------------
-- РЕДКОСТИ
------------------------------------------------------------------------
Config.RarityOrder = { "Common", "Rare", "Epic", "Legendary", "Mythic" }

Config.Rarities = {
	-- Rate — шанс выпадения в Summon (в процентах, сумма = 100)
	Common    = { Order = 1, Color = Color3.fromRGB(165, 165, 175), Rate = 72,  PlacementLimit = 6 },
	Rare      = { Order = 2, Color = Color3.fromRGB(60, 140, 255),  Rate = 21,  PlacementLimit = 5 },
	Epic      = { Order = 3, Color = Color3.fromRGB(170, 80, 255),  Rate = 5.5, PlacementLimit = 4 },
	Legendary = { Order = 4, Color = Color3.fromRGB(255, 195, 50),  Rate = 1.3, PlacementLimit = 3 },
	Mythic    = { Order = 5, Color = Color3.fromRGB(235, 40, 130),  Rate = 0.2, PlacementLimit = 2 },
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
	Center = Vector3.new(0, 60, 400),
	Radius = 58,
	Spawn = Vector3.new(0, 60, 432),
	Zones = {
		Summon = { Offset = Vector3.new(-32, 0, 6), Radius = 7, Title = "SUMMON", Color = Color3.fromRGB(255, 70, 180) },
		Units  = { Offset = Vector3.new(32, 0, 6),  Radius = 7, Title = "ЮНИТЫ",  Color = Color3.fromRGB(80, 170, 255) },
		Play   = { Offset = Vector3.new(0, 0, -30), Radius = 8, Title = "ИГРАТЬ", Color = Color3.fromRGB(180, 80, 255) },
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
	local l = Instance.new("PointLight")
	l.Color = color or P.Neon
	l.Range = range or 8
	l.Brightness = brightness or 1.5
	l.Shadows = false
	l.Parent = part
	return l
end

function Rig:Sparkles(part, color, o)
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
	local blade = self:Box(limb, V(0.14, w, len), CF(0, y, -0.58 - len / 2), o.Blade or P.Gray, o.BladeMat or M.Metal)
	blade.Name = "Blade"
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
	local cape = self:Joint("Cape", T, V(width, length, 0.12), CF(0, 0.95, 0.58), ANG(rad(7), 0, 0) * CF(0, -length / 2, 0.02), color, M.Fabric)
	-- застёжки плаща
	self:Box(T, V(0.3, 0.3, 0.2), CF(-0.75, 0.85, 0.55), P.Gold, M.Metal)
	self:Box(T, V(0.3, 0.3, 0.2), CF(0.75, 0.85, 0.55), P.Gold, M.Metal)
	if tatter then
		local seed = 0
		for i = -2, 2 do
			seed = seed + 1
			local h = 0.4 + ((seed * 37) % 5) * 0.12
			self:Wedge(cape, V(width / 5.2, h, 0.12), CF(i * width / 5, -length / 2 - h / 2 + 0.02, 0) * ANG(0, 0, math.pi), color, M.Fabric)
		end
		-- кайма
		self:Box(cape, V(width + 0.04, 0.12, 0.14), CF(0, length / 2 - 0.25, 0), color:Lerp(P.Black, 0.4), M.Fabric)
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
	Details.VoidSoldier(r, lv)
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
	Details.ShadowArcher(r, lv)
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
	Details.LostMage(r, lv)
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
	Details.VoidKnight(r, lv)
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
	Details.DarkGunner(r, lv)
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
	Details.AbyssReaper(r, lv)
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
	Details.CorruptedSamurai(r, lv)
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
	Details.EclipseGuardian(r, lv)
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
	Details.FallenAngel(r, lv)
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
	Details.VoidEmperor(r, lv)
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
	Details.AbyssOverlord(r, lv)
	levelAura(r, lv)
	return r:Finish(1.55, { RS = { 12, 0, 8 }, LS = { 12, 0, -8 } })
end

------------------------------------------------------------------------
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
}

-- Построить модель юнита. Модель стоит в начале координат, ноги на высоте -HipHeight.
function UnitModels.Build(unitId, level)
	local builder = Builders[unitId]
	if not builder then
		error("Unknown unit " .. tostring(unitId))
	end
	local rig = builder(math.clamp(level or 1, 1, 5))
	rig.Model.Name = unitId
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
FILES[#FILES + 1] = { "ServerScriptService", { "VoidTDServer" }, "Script", [======[
--!nocheck
-- VOID TD :: Server bootstrap

local Players = game:GetService("Players")
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

handlers.StartWave = function(player)
	return GameService.RequestStartWave(player)
end

handlers.Summon = function(player, data)
	local count = (type(data) == "table" and data.Count == 10) and 10 or 1
	local ok, result = DataService.Summon(player, count)
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
	bloom.Intensity = 0.9
	bloom.Size = 28
	bloom.Threshold = 1.1
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
	cylinderY(m, "FloorInlay", 22, 0.2, c + V(0, 0.02, 0), C.Ground2, Enum.Material.Slate, { CanCollide = false })
	cylinderY(m, "InnerRing", 22.6, 0.12, c + V(0, 0.01, 0), C.Neon, Enum.Material.Neon, { CanCollide = false, Transparency = 0.3 })
	cylinderY(m, "OuterRing", R - 4, 0.1, c + V(0, 0.005, 0), C.Neon, Enum.Material.Neon, { CanCollide = false, Transparency = 0.6 })
	cylinderY(m, "OuterFloor", R - 4.4, 0.12, c + V(0, 0.01, 0), C.Ground, Enum.Material.Slate, { CanCollide = false })
	-- низ острова
	for i, l in ipairs({ { 0.9, 10, -8 }, { 0.68, 14, -19 }, { 0.45, 16, -33 }, { 0.22, 16, -48 } }) do
		cylinderY(m, "Under" .. i, R * l[1], l[2], c + V(rng:NextNumber(-3, 3), l[3], rng:NextNumber(-3, 3)), (i % 2 == 0) and C.Rock or C.Rock2)
	end
	local root = part(m, { Name = "CrystalRoot", Size = V(7, 16, 7), CFrame = CF(c + V(0, -62, 0)) * ANG(rad(6), rad(45), 0), Color = C.Neon, Material = Enum.Material.Neon })
	light(root, C.Neon, 40, 3)
	-- край: камни и колонны с неоном
	for i = 0, 23 do
		local a = i / 24 * math.pi * 2
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

	-- SUMMON: алтарь с парящим кристаллом
	local sz = c + L.Zones.Summon.Offset + V(-13, 0, 0)
	part(m, { Name = "Altar", Size = V(7, 2, 7), CFrame = CF(sz + V(0, 1, 0)), Color = C.Stone2, Material = Enum.Material.Slate })
	part(m, { Name = "Altar2", Size = V(5, 1.5, 5), CFrame = CF(sz + V(0, 2.75, 0)) * ANG(0, rad(45), 0), Color = C.Stone, Material = Enum.Material.Slate })
	local crystal = part(m, { Name = "SummonCrystal", Size = V(3, 5, 3), CFrame = CF(sz + V(0, 8, 0)) * ANG(0, 0, rad(10)), Color = C.NeonPink, Material = Enum.Material.Neon, CanCollide = false })
	crystal:SetAttribute("Spin", 1)
	crystal:SetAttribute("SpinAxis", "Y")
	crystal:SetAttribute("BobAmp", 0.8)
	light(crystal, C.NeonPink, 30, 3)
	emitter(crystal, C.NeonPink, { Rate = 20, Size = 0.6 })
	for i = 0, 3 do
		local a = i / 4 * math.pi * 2 + math.pi / 4
		local op = sz + V(math.cos(a) * 6, 0, math.sin(a) * 6)
		part(m, { Name = "Obelisk", Size = V(1.4, 7 + (i % 2) * 2, 1.4), CFrame = CF(op + V(0, 3.5 + (i % 2), 0)), Color = C.Stone2, Material = Enum.Material.Slate })
		part(m, { Name = "ObeliskRune", Size = V(0.4, 3, 0.2), CFrame = CF(op + V(0, 4, 0)) * CFrame.lookAt(Vector3.zero, sz - op).Rotation * CF(0, 0, -0.75), Color = C.NeonPink, Material = Enum.Material.Neon, CanCollide = false })
	end

	-- ЮНИТЫ: статуи Common-героев
	local uz = c + L.Zones.Units.Offset
	statue(m, "VoidSoldier", uz + V(12, 0, -7), uz, 2.5)
	statue(m, "ShadowArcher", uz + V(14, 0, 1), uz, 2.5)
	statue(m, "LostMage", uz + V(12, 0, 9), uz, 2.5)

	-- ИГРАТЬ: портал в бой и мифические стражи
	local pz = c + L.Zones.Play.Offset
	lobbyPortal(m, pz + V(0, 10.5, -11), V(0, 0, 1))
	part(m, { Name = "PortalBase", Size = V(24, 1, 8), CFrame = CF(pz + V(0, 0.5, -11)), Color = C.Stone2, Material = Enum.Material.Slate })
	statue(m, "VoidEmperor", pz + V(-17, 0, -6), c, 4)
	statue(m, "AbyssOverlord", pz + V(17, 0, -6), c, 4)
	statue(m, "FallenAngel", c + V(-20, 0, 26), c, 3)
	statue(m, "EclipseGuardian", c + V(20, 0, 26), c, 3)

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
	end
	for i = 1, 10 do
		local a = rng:NextNumber(0, math.pi * 2)
		local d = rng:NextNumber(38, R - 7)
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
	}
end

------------------------------------------------------------------------
-- SUMMON
------------------------------------------------------------------------
local byRarity = {}
for _, id in ipairs(Config.UnitOrder) do
	local r = Config.Units[id].Rarity
	byRarity[r] = byRarity[r] or {}
	table.insert(byRarity[r], id)
end

local rng = Random.new()

local function rollRarity()
	local total = 0
	for _, name in ipairs(Config.RarityOrder) do
		total = total + Config.Rarities[name].Rate
	end
	local roll = rng:NextNumber() * total
	local acc = 0
	for _, name in ipairs(Config.RarityOrder) do
		acc = acc + Config.Rarities[name].Rate
		if roll <= acc then
			return name
		end
	end
	return "Common"
end

function DataService.Summon(player, count)
	local p = DataService.Profiles[player]
	if not p then
		return false, "Профиль не загружен"
	end
	local s = Config.Settings
	local cost = (count == 10) and s.SummonCost10 or s.SummonCost1
	count = (count == 10) and 10 or 1
	if p.Gems < cost then
		return false, "Недостаточно гемов"
	end
	p.Gems = p.Gems - cost
	player:SetAttribute("Gems", p.Gems)
	local results = {}
	local bestOrder = 0
	for i = 1, count do
		local rarity = rollRarity()
		-- гарантия: в x10 минимум один Rare+
		if count == 10 and i == 10 and bestOrder < 2 then
			rarity = "Rare"
		end
		bestOrder = math.max(bestOrder, Config.Rarities[rarity].Order)
		local pool = byRarity[rarity]
		local id = pool[rng:NextInteger(1, #pool)]
		local isNew = (p.Inventory[id] or 0) == 0
		p.Inventory[id] = (p.Inventory[id] or 0) + 1
		results[i] = { Id = id, New = isNew }
		-- автоэкипировка новых юнитов в свободный слот
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

local function aoeHit(u, center, radius, stats, kind)
	-- один удар = один набор целей: каждый враг получает урон ровно один раз
	local hitSet = {}
	for _, e in pairs(enemies) do
		if e.Alive and PathUtil.FlatDistance(e.Pos, center) <= radius + (e.IsBoss and 1.5 or 0.5) then
			hitSet[#hitSet + 1] = e
		end
	end
	Remotes.Impact:FireAllClients({ K = kind, P = center, R = radius, L = u.Level, U = u.Uid, N = #hitSet })
	for _, e in ipairs(hitSet) do
		local dmg, crit = rollDamage(stats)
		damageEnemy(e, dmg, crit, u)
	end
end

local function attack(u, stats, list)
	local def = u.Def
	local myMatch = matchId
	local hitDelay = def.HitDelay or 0.2
	local target = list[1]

	if def.AttackType == "Melee" or def.AttackType == "Laser" then
		fireAttack(u, { target.Id }, { D = hitDelay })
		task.delay(hitDelay, function()
			if valid(u, myMatch) and target.Alive then
				local dmg, crit = rollDamage(stats)
				damageEnemy(target, dmg, crit, u)
			end
		end)
	elseif def.AttackType == "Projectile" then
		local travel = PathUtil.FlatDistance(u.Pos, target.Pos) / (def.ProjectileSpeed or 80)
		fireAttack(u, { target.Id }, { D = hitDelay, TR = travel })
		task.delay(hitDelay + travel, function()
			if valid(u, myMatch) and target.Alive then
				local dmg, crit = rollDamage(stats)
				damageEnemy(target, dmg, crit, u)
			end
		end)
	elseif def.AttackType == "AOE" then
		local saved = target.Pos
		fireAttack(u, { target.Id }, { D = hitDelay })
		task.delay(hitDelay, function()
			if not valid(u, myMatch) then
				return
			end
			local center = target.Alive and target.Pos or saved
			local kind = def.ImpactKind or "Reap"
			aoeHit(u, center, stats.AOERadius or 6, stats, kind)
		end)
	elseif def.AttackType == "MultiHit" then
		local hits = stats.Hits or 1
		local interval = def.HitInterval or 0.15
		local spread = (u.Id == "VoidEmperor")
		local ids = {}
		local plan = {}
		for h = 1, hits do
			local e = spread and list[((h - 1) % #list) + 1] or target
			plan[h] = e
			ids[h] = e.Id
		end
		fireAttack(u, ids, { D = hitDelay, I = interval })
		for h = 1, hits do
			task.delay(hitDelay + (h - 1) * interval, function()
				if not valid(u, myMatch) then
					return
				end
				local e = plan[h]
				if not e.Alive then
					-- цель умерла — ищем следующую в радиусе
					local fresh = candidates(u, stats.Range)
					e = fresh[1]
				end
				if e then
					local dmg, crit = rollDamage(stats)
					if spread then
						Remotes.Impact:FireAllClients({ K = "Judgement", P = e.Pos, L = u.Level, U = u.Uid, H = h })
					end
					damageEnemy(e, dmg, crit, u)
				end
			end)
		end
	end
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
		if t >= u.NextAttack then
			local list = candidates(u, stats.Range)
			if #list > 0 then
				attack(u, stats, list)
				u.NextAttack = t + stats.Cooldown
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
		if e.SlowUntil > t then
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
		list[#list + 1] = (e.SlowUntil > t) and 1 or 0
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
			toLobby(pl)
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
local ZONE_MODAL = { Summon = "Summon", Units = "Inventory", Play = "Mode" }
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
			UI.Show(ZONE_MODAL[key], inside)
			if inside then
				FX.Sound("Ping", 0.3, 1.1)
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
local SOUNDS = {
	Slash = "rbxasset://sounds/swordslash.wav",
	Lunge = "rbxasset://sounds/swordlunge.wav",
	Place = "rbxasset://sounds/unsheath.wav",
	Ping = "rbxasset://sounds/electronicpingshort.wav",
}
local lastSound = {}

function FX.Sound(name, volume, pitch, pos)
	local id = SOUNDS[name]
	if not id then
		return
	end
	local t = os.clock()
	if lastSound[name] and t - lastSound[name] < 0.07 then
		return
	end
	-- приглушаем далёкие звуки
	if pos then
		local cam = workspace.CurrentCamera
		local d = cam and (cam.CFrame.Position - pos).Magnitude or 0
		if d > 120 then
			return
		end
		volume = (volume or 0.4) * math.clamp(1 - d / 120, 0.15, 1)
	end
	lastSound[name] = t
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume or 0.4
	s.PlaybackSpeed = pitch or 1
	s.Parent = SoundService
	s:Play()
	task.delay(3, function()
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
	p.CFrame = CFrame.lookAt(from, last)
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
	local rings = big and 6 or 3
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
function FX.Shockwave(pos, radius, lv)
	local g = V(pos.X, pos.Y + 0.2, pos.Z)
	FX.Sound("Lunge", 0.6, 0.55, pos)
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
	for _ = 1, 6 + lv do
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
function FX.Reap(unitPos, center, radius, lv)
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
	FX.Sound("Slash", 0.5, 0.8 + (hitIndex or 1) * 0.08, pos)
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
		FX.Sound("Lunge", 0.7, 0.4, pos)
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
		for i = 1, 4 + (lv >= 5 and 2 or 0) do
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
	FX.Sound("Ping", 0.4, 1.3, pos)
	FX.Ring(pos + V(0, 0.2, 0), 4, color or NEON, 0.6, 0.3)
	local col = FX.Part({ Shape = Enum.PartType.Cylinder, Size = V(0.2, 3, 3), CFrame = CF(pos + V(0, 0.3, 0)) * ANG(0, 0, rad(90)), Color = color or NEON, Transparency = 0.2 })
	tween(col, 0.7, { CFrame = CF(pos + V(0, 7, 0)) * ANG(0, 0, rad(90)), Transparency = 1, Size = V(0.1, 4.5, 4.5) })
	cleanup(col, 0.75)
	FX.Burst(pos + V(0, 3, 0), color or NEON_SOFT, 14, 0.35, 7, 0.7)
end

function FX.Place(pos)
	FX.Sound("Place", 0.5, 1, pos)
	FX.Ring(pos + V(0, 0.2, 0), 3.5, NEON_SOFT, 0.45, 0.25)
	FX.Burst(pos + V(0, 0.5, 0), Color3.fromRGB(70, 60, 80), 8, 0.4, 5)
end

------------------------------------------------------------------------
-- ЦИФРЫ УРОНА
------------------------------------------------------------------------
function FX.DamageNumber(pos, amount, flag)
	if numberCount > 70 then
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

local FIDGETS = {
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
			elseif name == "WingR" or name == "WingL" then
				local side = name == "WingR" and 1 or -1
				cf = cf * ANG(0, math.sin(t * 2.4 + phase) * 0.12 * side, math.sin(t * 2.4 + phase) * 0.1 * side)
			elseif name == "Neck" then
				cf = cf * ANG(0, math.sin(t * 0.7 + phase) * 0.08, 0)
			elseif name == "Cape" or name == "Scarf" then
				local gust = (rig.Gust or 0)
				cf = cf * ANG(rad(6 + math.sin(t * 1.7 + phase) * 4 + gust * 22), 0, rad(math.sin(t * 1.1 + phase) * 3))
			elseif name:sub(1, 5) == "Orbit" then
				cf = cf * ANG(0, t * 1.4 + phase, 0)
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
	}
	local pos, dir = PathUtil.OffsetPositionAt(dist, lateral)
	view.CF = CFrame.lookAt(pos + V(0, rig.HipHeight, 0), pos + dir + V(0, rig.HipHeight, 0))
	view.SpawnT = os.clock()
	view.Emerge = dist <= 1
	if Config.Enemies[typeId].IsBoss then
		view.RoarT = os.clock() + 0.6
		task.delay(0.6, function()
			FX.Sound("Lunge", 0.8, 0.3)
			FX.Shake(0.5, 0.9)
		end)
	end
	rig.Root.CFrame = view.CF
	makeHealthBar(view)
	rig.Model.Parent = enemyFolder
	enemyViews[id] = view
	if dist <= 1 then
		FX.Burst(pos + V(0, 2, 0), FX.Colors.Neon, 6, 0.3, 5)
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
	FX.Poof(root.Position + V(0, 0.5, 0), FX.Colors.Neon, size)
	if def.IsBoss then
		FX.Shockwave(root.Position - V(0, rig.HipHeight - 0.2, 0), 10 * size, 5)
	end
	local start = os.clock()
	local startCF = root.CFrame
	local life = def.IsBoss and 1.4 or 0.6
	local parts = {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and d.Transparency < 1 then
			parts[#parts + 1] = { d, d.Transparency }
		elseif d:IsA("ParticleEmitter") then
			d.Enabled = false
		end
	end
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local a = math.clamp((os.clock() - start) / life, 0, 1)
		root.CFrame = startCF * CF(0, -a * rig.HipHeight * 0.8, 0) * ANG(rad(-75 * ease(a)), 0, rad(15 * a))
		for _, p in ipairs(parts) do
			p[1].Transparency = p[2] + (1 - p[2]) * a
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

local function animateEnemy(view, t, dt)
	local rig = view.Rig
	local base = rig.Base
	local m = rig.Motors
	-- отшатывание от удара
	local hitA = t - (view.HitT or -10)
	local flinch = hitA < 0.2 and (1 - hitA / 0.2) * 0.22 or 0
	local def = Config.Enemies[view.Type]
	local freq = (view.Speed * (view.Slowed and 0.5 or 1)) / math.max(def.Scale or 1, 0.5) * 1.1
	local w = t * freq + view.Phase
	local s = math.sin(w)
	if rig.Style == "Biped" then
		if m.RH then
			m.RH.C0 = base.RH * ANG(s * 0.6, 0, 0)
			m.LH.C0 = base.LH * ANG(-s * 0.6, 0, 0)
			m.RS.C0 = base.RS * ANG(-s * 0.5, 0, 0)
			m.LS.C0 = base.LS * ANG(s * 0.5, 0, 0)
			local idle = rig.Idle.Root
			local tilt = idle and rad(idle[1]) or 0
			m.Root.C0 = base.Root * CF(0, math.abs(s) * 0.12 * (rig.Scale or 1), 0) * ANG(tilt, 0, s * 0.04)
		end
	elseif rig.Style == "Quad" then
		if m.FR then
			m.FR.C0 = base.FR * ANG(s * 0.6, 0, 0)
			m.BL.C0 = base.BL * ANG(s * 0.6, 0, 0)
			m.FL.C0 = base.FL * ANG(-s * 0.6, 0, 0)
			m.BR.C0 = base.BR * ANG(-s * 0.6, 0, 0)
		end
		m.Root.C0 = base.Root * CF(0, math.abs(s) * 0.1 * (rig.Scale or 1), 0) * ANG(s * 0.03, 0, 0)
		if m.Neck then
			m.Neck.C0 = base.Neck * ANG(math.sin(w * 2) * 0.06, 0, 0)
		end
	else -- Float
		m.Root.C0 = base.Root * CF(0, math.sin(t * 2 + view.Phase) * 0.3 * (rig.Scale or 1), 0) * ANG(0.12, 0, math.sin(t * 1.3 + view.Phase) * 0.06)
		for _, name in ipairs({ "ArmR", "ArmL", "ArmR2", "ArmL2", "RS", "LS" }) do
			if m[name] and base[name] then
				local side = (name:sub(-1) == "R" or name == "RS" or name == "ArmR2") and 1 or -1
				m[name].C0 = base[name] * ANG(math.sin(t * 2.2 + view.Phase + side) * 0.3 + 0.3, 0, math.sin(t * 1.7) * 0.15 * side)
			end
		end
	end
	if flinch > 0 then
		m.Root.C0 = m.Root.C0 * ANG(-flinch, 0, flinch * 0.3)
	end
	-- рёв босса при появлении
	local roarA = t - (view.RoarT or -10)
	local roar = (roarA > 0 and roarA < 1.4) and math.sin(roarA / 1.4 * math.pi) or 0
	if roar > 0 then
		if m.RS and base.RS then
			m.RS.C0 = base.RS * ANG(rad(150 * roar), 0, rad(30 * roar))
			m.LS.C0 = base.LS * ANG(rad(150 * roar), 0, rad(-30 * roar))
		end
		if m.Neck and base.Neck then
			m.Neck.C0 = base.Neck * ANG(rad(-30 * roar), 0, 0)
		end
		m.Root.C0 = m.Root.C0 * ANG(rad(-12 * roar), 0, 0)
	end
	if m.Jaw then
		m.Jaw.C0 = base.Jaw * ANG(math.max(0, math.sin(t * 3 + view.Phase)) * 0.45 + roar * 0.6, 0, 0)
	end
	if m.Halo then
		m.Halo.C0 = base.Halo * ANG(0, t * 1.5, 0)
	end
end

local function updateEnemies(t, dt)
	local nowc = os.clock()
	for _, v in pairs(enemyViews) do
		local speed = v.Speed * (v.Slowed and 0.5 or 1)
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
		v.Rig.Root.CFrame = v.CF - V(0, rise, 0)
		animateEnemy(v, t, dt)
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
	-- метка владельца
	local gui = Instance.new("BillboardGui")
	gui.Name = "Tag"
	gui.Size = UDim2.fromOffset(110, 34)
	gui.StudsOffsetWorldSpace = V(0, 2.7 * rig.Scale + 1.2, 0)
	gui.MaxDistance = 70
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
	view.NextFidget = os.clock() + 4 + math.random() * 8
	if isNew then
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
				FX.LevelUp(view.Pos, Config.Rarities[Config.Units[view.UnitId].Rarity].Color)
				view.Anim = { Start = os.clock(), Frames = Anims.PowerUp() }
				if Renderer.OnUnitChanged then
					Renderer.OnUnitChanged(uid)
				end
			end
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

	if def.AttackType == "Projectile" then
		at(h, function()
			if not view.Rig or not view.Rig.Model.Parent then
				return
			end
			local from = muzzlePos(view)
			FX.Sound("Lunge", def.Projectile == "Bolt" and 0.12 or 0.25, def.Projectile == "Bolt" and 1.8 or 1.3, from)
			FX.Projectile(def.Projectile, from, function()
				return Renderer.EnemyCenter(firstId)
			end, p.TR or 0.2, function(pos)
				FX.Burst(pos, def.Projectile == "Orb" and FX.Colors.Neon or FX.Colors.Soft, def.Projectile == "Orb" and 8 or 4, 0.3, 5)
				if def.Projectile == "Orb" then
					FX.Sphere(pos, 1.4 + lv * 0.15, FX.Colors.Neon, 0.25)
				end
			end, lv)
			if def.Projectile == "Bolt" then
				FX.Sphere(from, 0.6, FX.Colors.Soft, 0.12)
			end
		end)
	elseif def.AttackType == "Laser" then
		at(h, function()
			local target = Renderer.EnemyCenter(firstId) or tpos
			if target and view.Rig.Model.Parent then
				FX.Sound("Lunge", 0.5, 0.7, target)
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
			local big = view.UnitId == "AbyssOverlord"
			FX.Arc(cf, reach, rad(15), rad(150), big and FX.Colors.Neon or FX.Colors.Soft, big and 1 or (0.4 + lv * 0.05), 0.3)
			FX.Sound("Slash", 0.35, big and 0.7 or 1.1, target)
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
					FX.Sound("Slash", 0.35, 1.25, target)
					if lv >= 3 then
						FX.SlashMark(target, rad(i % 2 == 0 and 40 or -40), 5 + lv * 0.5, 0.35, FX.Colors.Neon, 0.3)
					end
				else
					-- Void Emperor: вспышка на мече, сам разрез — в Impact
					FX.Sphere(muzzlePos(view), 1.6, FX.Colors.Pink, 0.2)
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
		FX.Reap(view and view.Pos or p.P, p.P, p.R, lv)
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
			rig.Root.CFrame = CF(v.Pos + V(0, rig.HipHeight + drop, 0)) * ANG(0, v.Yaw, 0)
			applyPose(rig, evalPose(v, t), t, v.Phase)
		end
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
FILES[#FILES + 1] = { "StarterPlayerScripts", { "VoidTDClient", "UI" }, "ModuleScript", [======[
--!nocheck
-- VOID TD :: UI (клиент)
-- Весь интерфейс создаётся кодом: HUD, хотбар, панель юнита, Summon, инвентарь, уведомления.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local UI = {}

local ctx, Config, UnitModels, Renderer, FX
local player = Players.LocalPlayer

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
		if d:IsA("ParticleEmitter") or d:IsA("PointLight") then
			d:Destroy()
		end
	end
	rig.Model.Parent = vf
	local cam = Instance.new("Camera")
	cam.FieldOfView = 34
	local s = rig.Scale
	local center = Vector3.new(0, -0.1 * s, 0)
	cam.CFrame = CFrame.lookAt(center + Vector3.new(4.2, 2.0, -10.5) * s, center)
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
	refs.Money = label({ Parent = cur, Size = UDim2.new(1, -20, 0, 38), Position = UDim2.fromOffset(12, 6), Text = "💰 0", TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = THEME.Good })
	refs.Gems = label({ Parent = cur, Size = UDim2.new(1, -20, 0, 34), Position = UDim2.fromOffset(12, 50), Text = "💎 0", TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(120, 200, 255) })

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

	-- инвентарь всегда на экране
	refs.InvButton = button({ Parent = gui, Size = UDim2.fromOffset(150, 44), Position = UDim2.fromOffset(16, 118), Text = "☰ ЮНИТЫ (G)", BackgroundColor3 = THEME.BG3 }, function()
		UI.Toggle("Inventory")
	end)

	-- выход из матча в лобби
	refs.Leave = button({ Parent = gui, Size = UDim2.fromOffset(150, 44), Position = UDim2.fromOffset(16, 170), Text = "⟵ В ЛОББИ", BackgroundColor3 = Color3.fromRGB(110, 35, 55), StrokeColor = THEME.Bad }, function()
		ctx.Placement.Stop()
		local ok = ctx.Request("LeaveMatch")
		if ok then
			UI.CloseUnit()
		end
	end)

	-- подсказка в лобби
	local hint = panel({ Parent = gui, AnchorPoint = Vector2.new(0.5, 1), Size = UDim2.fromOffset(640, 86), Position = UDim2.new(0.5, 0, 1, -18), StrokeColor = THEME.Accent })
	refs.LobbyHint = hint
	label({ Parent = hint, Size = UDim2.new(1, -20, 0, 36), Position = UDim2.fromOffset(10, 6), Text = "ЛОББИ", TextColor3 = THEME.Accent })
	label({ Parent = hint, Size = UDim2.new(1, -20, 0, 32), Position = UDim2.fromOffset(10, 46), Font = Enum.Font.GothamBold, Text = "Встань в круг:  ✦ SUMMON — призыв   •   ▶ ИГРАТЬ — в бой   •   ☰ ЮНИТЫ — кнопка слева или G" })

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
	local p = panel({ Parent = gui, AnchorPoint = Vector2.new(1, 0.5), Size = UDim2.fromOffset(310, 470), Position = UDim2.new(1, -16, 0.45, 0), Visible = false })
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

local function modal(name, title, size)
	local m = panel({ Parent = gui, AnchorPoint = Vector2.new(0.5, 0.5), Size = size, Position = UDim2.fromScale(0.5, 0.5), Visible = false, BackgroundTransparency = 0.04, ZIndex = 5 })
	new("UIScale", { Parent = m })
	label({ Parent = m, Size = UDim2.new(1, -80, 0, 44), Position = UDim2.fromOffset(18, 10), Text = title, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = THEME.Accent })
	button({ Parent = m, Size = UDim2.fromOffset(40, 40), Position = UDim2.new(1, -52, 0, 12), Text = "✕", BackgroundColor3 = Color3.fromRGB(120, 30, 50) }, function()
		m.Visible = false
	end)
	modals[name] = m
	return m
end

------------------------------------------------------------------------
-- SUMMON
------------------------------------------------------------------------
local function showSummonResults(results)
	local overlay = new("Frame", { Parent = gui, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(5, 0, 10), BackgroundTransparency = 0.25, ZIndex = 20 })
	local best = 1
	for _, r in ipairs(results) do
		best = math.max(best, Config.Rarities[Config.Units[r.Id].Rarity].Order)
	end
	local bestName = Config.RarityOrder[best]
	local flash = new("Frame", { Parent = overlay, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Config.Rarities[bestName].Color, BackgroundTransparency = 0.3, ZIndex = 21 })
	tween(flash, 0.8, { BackgroundTransparency = 1 })
	label({ Parent = overlay, AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.fromOffset(600, 60), Position = UDim2.new(0.5, 0, 0.08, 0), Text = best >= 4 and (bestName:upper() .. "!") or "SUMMON", TextColor3 = Config.Rarities[bestName].Color, ZIndex = 22, StrokeThickness = 3 })
	local grid = new("Frame", { Parent = overlay, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(5 * 150, (#results > 5 and 2 or 1) * 200), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 22 }, {
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
			FX.Sound("Ping", 0.3, 0.8 + Config.Rarities[def.Rarity].Order * 0.15)
		end)
	end
	task.delay(0.15 * #results + 0.4, function()
		button({ Parent = overlay, AnchorPoint = Vector2.new(0.5, 1), Size = UDim2.fromOffset(200, 54), Position = UDim2.new(0.5, 0, 0.92, 0), Text = "OK", ZIndex = 25 }, function()
			overlay:Destroy()
		end)
	end)
end

local function buildSummon()
	local m = modal("Summon", "✦ VOID SUMMON", UDim2.fromOffset(760, 520))
	label({ Parent = m, Size = UDim2.new(1, -36, 0, 20), Position = UDim2.fromOffset(18, 54), Text = "Призови воинов Пустоты. В x10 гарантирован минимум один Rare+.", TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = THEME.Dim, Font = Enum.Font.GothamBold, ZIndex = 6 })
	local list = new("ScrollingFrame", { Parent = m, BackgroundTransparency = 1, Size = UDim2.new(1, -36, 0, 330), Position = UDim2.fromOffset(18, 82), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 6, BorderSizePixel = 0, ZIndex = 6 }, {
		new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	for order, rarity in ipairs(Config.RarityOrder) do
		local r = Config.Rarities[rarity]
		local row = panel({ Parent = list, Size = UDim2.new(1, -10, 0, 74), BackgroundColor3 = THEME.BG2, StrokeColor = r.Color, LayoutOrder = order, ZIndex = 6 })
		label({ Parent = row, Size = UDim2.fromOffset(130, 30), Position = UDim2.fromOffset(12, 8), Text = rarity:upper(), TextColor3 = r.Color, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 7 })
		label({ Parent = row, Size = UDim2.fromOffset(130, 24), Position = UDim2.fromOffset(12, 40), Text = string.format("%.1f%%", r.Rate), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = THEME.Text, ZIndex = 7 })
		local x = 150
		for _, id in ipairs(Config.UnitOrder) do
			if Config.Units[id].Rarity == rarity then
				local cell = new("Frame", { Parent = row, BackgroundColor3 = THEME.BG, BackgroundTransparency = 0.3, Size = UDim2.fromOffset(160, 64), Position = UDim2.fromOffset(x, 5), ZIndex = 7 }, { corner(6) })
				viewport(cell, id, 1, { Size = UDim2.fromOffset(60, 64), ZIndex = 8 })
				label({ Parent = cell, Size = UDim2.new(1, -64, 0, 22), Position = UDim2.fromOffset(62, 21), Text = Config.Units[id].Name, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 8 })
				x = x + 168
			end
		end
	end
	refs.SummonGems = label({ Parent = m, Size = UDim2.fromOffset(240, 36), Position = UDim2.new(0, 18, 1, -70), Text = "💎 0", TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(120, 200, 255), ZIndex = 6 })
	local busy = false
	local function summon(count)
		if busy then
			return
		end
		busy = true
		local ok, res = ctx.Request("Summon", { Count = count })
		busy = false
		if ok then
			showSummonResults(res)
		end
	end
	button({ Parent = m, AnchorPoint = Vector2.new(1, 1), Size = UDim2.fromOffset(200, 56), Position = UDim2.new(1, -238, 1, -16), Text = "x1  💎" .. Config.Settings.SummonCost1, BackgroundColor3 = THEME.AccentDark, ZIndex = 6 }, function()
		summon(1)
	end)
	button({ Parent = m, AnchorPoint = Vector2.new(1, 1), Size = UDim2.fromOffset(210, 56), Position = UDim2.new(1, -18, 1, -16), Text = "x10  💎" .. Config.Settings.SummonCost10, BackgroundColor3 = Color3.fromRGB(150, 60, 200), StrokeColor = THEME.Gold, ZIndex = 6 }, function()
		summon(10)
	end)
end

------------------------------------------------------------------------
-- ИНВЕНТАРЬ И ЭКИПИРОВКА
------------------------------------------------------------------------
local invSelected

local function buildInventory()
	local m = modal("Inventory", "☰ ЮНИТЫ", UDim2.fromOffset(860, 560))
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
		if not invSelected then
			return
		end
		local prof = ctx.Profile
		local equippedSlot
		for i = 1, Config.Settings.EquipSlots do
			if prof.Equipped[tostring(i)] == invSelected then
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
			ctx.Request("Equip", { Unit = invSelected, Slot = free })
		end
	end)
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
	local ok = ctx.Request("JoinMatch", { Difficulty = diffKey })
	if ok then
		UI.Show("Mode", false)
		FX.Sound("Ping", 0.5, 0.8)
	end
end

local function buildMode()
	local m = modal("Mode", "▶ ВЫБОР СЛОЖНОСТИ", UDim2.fromOffset(880, 430))
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
		FX.Sound("Ping", 0.35, p.Boss and 0.6 or 1)
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
		end
		local f = refs.CoreFill
		f.BackgroundColor3 = THEME.Bad
		tween(f, 0.4, { BackgroundColor3 = THEME.Accent })
	elseif t == "Victory" then
		showEnd(true, p)
	elseif t == "Defeat" then
		showEnd(false, p)
	elseif t == "Reset" then
		if refs.EndOverlay then
			refs.EndOverlay:Destroy()
			refs.EndOverlay = nil
		end
		UI.CloseUnit()
		UI.Toast("Бой окончен. Ты в лобби — встань в круг ИГРАТЬ", "good")
	end
end

function UI.SetProfile(prof)
	ctx.Profile = prof
	refreshHotbar()
	if modals.Inventory and modals.Inventory.Visible then
		UI.RefreshInventory()
	end
end

local lastRefresh = 0
function UI.Update(dt)
	local State = ctx.State
	local money = player:GetAttribute("Money") or 0
	refs.Money.Text = "💰 " .. Config.FormatNumber(money)
	local gems = player:GetAttribute("Gems") or (ctx.Profile and ctx.Profile.Gems) or 0
	refs.Gems.Text = "💎 " .. Config.FormatNumber(gems)
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
	refs.Gems.Position = UDim2.fromOffset(12, inMatch and 50 or 8)
	refs.InvButton.Position = UDim2.fromOffset(16, inMatch and 118 or 76)
	refs.LobbyHint.Visible = not inMatch and not (modals.Mode.Visible or modals.Summon.Visible or modals.Inventory.Visible)
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
	buildSummon()
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
		elseif d:IsA("ParticleEmitter") or d:IsA("PointLight") then
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
