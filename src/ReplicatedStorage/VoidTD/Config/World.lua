--!nocheck
-- VOID TD :: Config.World
-- Лобби, Хэллоуин-остров, события и карты (дороги). Всё висит в небе на высоте 60.
-- Зоны: Offset — от центра острова, Radius — круг, в который надо встать, чтобы открыть меню.
-- IslandSize — Vector2: X — размер по X, Y — размер по мировой оси Z.

local BATTLE_SPAWN = Vector3.new(10, 60, 10) -- точка прибытия на карту Void

------------------------------------------------------------------------
-- ЛОББИ: остров рядом с картой. Встань в круг, чтобы открыть меню.
------------------------------------------------------------------------
local Lobby = {
	Center = Vector3.new(0, 60, 440),
	Radius = 95,
	Spawn = Vector3.new(0, 60, 510),
	Zones = {
		Play  = { Offset = Vector3.new(0, 0, -62), Radius = 9, Title = "ИГРАТЬ", Color = Color3.fromRGB(180, 80, 255) },
		Units = { Offset = Vector3.new(64, 0, 8),  Radius = 8, Title = "ЮНИТЫ",  Color = Color3.fromRGB(80, 170, 255) },
		-- кейсы: Case = ключ из Config.Cases
		Case_VoidCase = {
			Offset = Vector3.new(-58, 0, -22), Radius = 7, Title = "VOID CASE",
			Color = Color3.fromRGB(170, 80, 255), Case = "VoidCase",
		},
		Case_ShatteredReality = {
			Offset = Vector3.new(-70, 0, 6), Radius = 7, Title = "SHATTERED REALITY",
			Color = Color3.fromRGB(130, 50, 230), Case = "ShatteredReality",
		},
		-- огромный портал на Хэллоуин-остров
		HalloweenPortal = {
			Offset = Vector3.new(-56, 0, 40), Radius = 8, Title = "HALLOWEEN EVENT",
			Color = Color3.fromRGB(255, 130, 30), Teleport = "Halloween",
		},
	},
}

------------------------------------------------------------------------
-- HALLOWEEN EVENT
------------------------------------------------------------------------
-- Тег события (не редкость): рамка карточки остаётся цветом основной редкости
local Events = {
	Halloween = { Tag = "🎃 HALLOWEEN", Color = Color3.fromRGB(255, 135, 35), Glow = Color3.fromRGB(255, 170, 60) },
}

-- Хэллоуин-остров: кейс, вход в бой на 4 квадратах, доска наград, превью юнитов, бестиарий
local HalloweenIsland = {
	Center = Vector3.new(560, 60, 460),
	Radius = 100,
	Spawn = Vector3.new(560, 60, 530),
	Zones = {
		Case_Halloween = {
			Offset = Vector3.new(-50, 0, -20), Radius = 8, Title = "HALLOWEEN CASE",
			Color = Color3.fromRGB(255, 130, 30), Case = "Halloween",
		},
		Units = {
			Offset = Vector3.new(60, 0, 20), Radius = 7, Title = "ЮНИТЫ",
			Color = Color3.fromRGB(255, 170, 60),
		},
		Bestiary = {
			Offset = Vector3.new(60, 0, -22), Radius = 7, Title = "БЕСТИАРИЙ",
			Color = Color3.fromRGB(170, 60, 255), Bestiary = true,
		},
		HalloweenUnits = {
			Offset = Vector3.new(-62, 0, 26), Radius = 7, Title = "HALLOWEEN ЮНИТЫ",
			Color = Color3.fromRGB(255, 120, 40), EventUnits = "Halloween",
		},
		ReturnPortal = {
			Offset = Vector3.new(34, 0, 60), Radius = 7, Title = "В ЛОББИ",
			Color = Color3.fromRGB(170, 80, 255), Teleport = "Lobby",
		},
	},
	-- 4 светящихся квадрата входа в Хэллоуин-матч (центр — Offset, Pads — от центра, Pad — сторона квадрата)
	Queue = {
		Offset = Vector3.new(0, 0, -46),
		Pads = { Vector3.new(-9, 0, -4.5), Vector3.new(9, 0, -4.5), Vector3.new(-9, 0, 4.5), Vector3.new(9, 0, 4.5) },
		Pad = 7,
		MaxPlayers = 4,
		Countdown = 15, -- секунд до телепорта (хост может нажать СТАРТ — останется 3 с)
		StartNow = 3,
	},
}

local Halloween = {
	Difficulties = { "Easy", "Medium", "Hard" }, -- Хардкор в Хэллоуине недоступен
	-- Halloween Coins каждому участнику за победу (за поражение — ничего)
	Coins = { Easy = 100, Medium = 150, Hard = 250 },
	-- финальный босс по сложности (подставляется вместо "BOSS" в волнах)
	Bosses = { Easy = "GraveWarden", Medium = "FogReaper", Hard = "CursedMonarch" },
	MaxWave = 20, -- дубль Maps.Halloween.MaxWave (сервер читает тот)
}

------------------------------------------------------------------------
-- КАРТА VOID: The Forgotten Realm. Точки дороги (X, Z) — от Center; у Void центр (0, 60, 0),
-- поэтому они совпадают с мировыми. Первая точка — портал, последняя — ядро.
------------------------------------------------------------------------
local Map = {
	Key = "Void",
	Name = "The Forgotten Realm",
	Center = Vector3.new(0, 60, 0),
	BattleSpawn = BATTLE_SPAWN,
	GroundY = 60, -- высота поверхности острова (карта висит в небе)
	PathWidth = 10,
	IslandSize = Vector2.new(250, 196),
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
-- КАРТА HALLOWEEN: Haunted Hollow (только из очереди на Хэллоуин-острове).
-- Path задан относительно Center. Волны: { Враг, Количество, Интервал спавна },
-- "BOSS" — финальный босс выбранной сложности (Config.Halloween.Bosses).
------------------------------------------------------------------------
local HalloweenMap = {
	Key = "Halloween",
	Name = "Haunted Hollow",
	Center = Vector3.new(560, 60, 0),
	GroundY = 60,
	PathWidth = 10,
	IslandSize = Vector2.new(270, 210),
	BattleSpawn = Vector3.new(590, 60, 45),
	MaxWave = 20,
	Path = {
		{ -112, -72 }, { -50, -72 }, { -50, -22 }, { -100, -22 }, { -100, 40 },
		{ -62, 76 }, { 0, 76 }, { 0, 12 }, { 40, -28 }, { 40, -76 },
		{ 96, -76 }, { 96, 10 }, { 62, 40 }, { 62, 82 }, { 112, 82 },
	},
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
}

return {
	Lobby = Lobby,
	BattleSpawn = BATTLE_SPAWN,
	Events = Events,
	HalloweenIsland = HalloweenIsland,
	Halloween = Halloween,
	Map = Map,
	-- Void — та же самая таблица, что и Config.Map
	Maps = { Void = Map, Halloween = HalloweenMap },
}
