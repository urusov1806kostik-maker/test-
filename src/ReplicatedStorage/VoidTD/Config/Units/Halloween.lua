--!nocheck
-- VOID TD :: Config.Units.Halloween
-- Юниты HALLOWEEN CASE (Event = "Halloween").
--
-- Power — способность вместо каждой N-й обычной атаки:
--   Mode = "AOE" (по области вокруг цели), "Self" (волна вокруг юнита), "Single" (одна цель, Mult и метка),
--   "Zone" (облако урона по времени). Radius — из Power или из уровня (PowerRadius).
--   Delay — задержка удара (по умолчанию 0.45). Anim — анимация способности, Kind — эффект.
-- PreviewAbilities — кнопки просмотра способностей в окне юнита: { ключ, подпись }.
-- Summon — призыв союзников по уровням (интервал, количество, HP), не больше Max живых от юнита.

return {
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

	-- Pulse: волна вокруг самого юнита (радиус AOERadius)
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

	-- Flask: колба — взрыв радиуса Explode, затем ядовитая лужа PoisonDps на PoisonTime
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
			{ Damage = 230, Range = 15, Cooldown = 2.2, Cost = 3500, PowerRadius = 8 },
			{ Damage = 330, Range = 16, Cooldown = 2.1, Cost = 2400, PowerRadius = 8.5 },
			{ Damage = 470, Range = 16, Cooldown = 2.0, Cost = 3800, PowerRadius = 9 },
			{ Damage = 670, Range = 17, Cooldown = 1.9, Cost = 5600, PowerRadius = 10 },
			{ Damage = 980, Range = 18, Cooldown = 1.8, Cost = 8400, PowerRadius = 11 },
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

	-- КАЗНЬ: радиус = AOERadius + RadiusAdd, поджог Burn × урон юнита в секунду на BurnTime
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

	-- Chrono: зубчатый диск летит по прямой (ширина DiscWidth) и режет до DiscTargets врагов
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
			{ Damage = 240, Range = 17, Cooldown = 1.6,  Cost = 9500,  Haste = 0.06, HasteTime = 2 },
			{ Damage = 340, Range = 17, Cooldown = 1.5,  Cost = 6500,  Haste = 0.07, HasteTime = 2.5 },
			{ Damage = 480, Range = 18, Cooldown = 1.45, Cost = 9500,  Haste = 0.08, HasteTime = 3 },
			{ Damage = 680, Range = 19, Cooldown = 1.35, Cost = 13500, Haste = 0.09, HasteTime = 3.5 },
			{ Damage = 980, Range = 20, Cooldown = 1.25, Cost = 20000, Haste = 0.10, HasteTime = 4 },
		},
	},
}
