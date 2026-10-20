--!nocheck
-- VOID TD :: Config.Enemies
-- Health — базовое HP (умножается на множитель волны и HP сложности).
-- Armor — доля поглощаемого урона, Dodge — шанс уклониться. CoreDamage — урон ядру.
-- Reward — деньги за убийство, BossGems — кристаллы всем игрокам за босса.
-- Поведение (Хэллоуин): Phase, ArmorBreak, OnDeath, Fog, Shield, Haste, Enrage, ArmorZones, FireAura, ArmorScale.
-- SpawnStyle — анимация появления на клиенте.

return {
	EnemyOrder = {
		"LostSoul", "VoidCrawler", "ShadowBeast", "ArmoredHorror", "RiftPhantom",
		"AbyssBrute", "CorruptedTitan", "VoidDevourer", "TheEntity",
		-- Хэллоуин
		"CursedDead", "PumpkinRunner", "PhantomWarrior", "BoneGuard", "LivingScarecrow", "StrawMinion",
		"FogWarlock", "PumpkinBrute", "NightReaper", "GraveWarden", "FogReaper", "CursedMonarch",
	},

	Enemies = {
		----------------------------------------------------------------
		-- ПУСТОТА (карта Void)
		----------------------------------------------------------------
		LostSoul       = { Name = "Lost Soul",       Health = 12,   Speed = 10.5, Reward = 10,   CoreDamage = 1,   Scale = 0.85 },
		VoidCrawler    = { Name = "Void Crawler",    Health = 33,   Speed = 9,    Reward = 18,   CoreDamage = 2,   Scale = 1.0 },
		ShadowBeast    = { Name = "Shadow Beast",    Health = 30,   Speed = 16,   Reward = 21,   CoreDamage = 2,   Scale = 1.0 },
		ArmoredHorror  = { Name = "Armored Horror",  Health = 120,  Speed = 7,    Reward = 45,   CoreDamage = 4,   Scale = 1.15, Armor = 0.3 },
		RiftPhantom    = { Name = "Rift Phantom",    Health = 85,   Speed = 11.5, Reward = 40,   CoreDamage = 3,   Scale = 1.05, Dodge = 0.2 },
		AbyssBrute     = { Name = "Abyss Brute",     Health = 510,  Speed = 6,    Reward = 105,  CoreDamage = 8,   Scale = 1.5 },
		CorruptedTitan = {
			Name = "Corrupted Titan", Health = 1200, Speed = 5, Reward = 500, CoreDamage = 25, Scale = 2.2,
			Armor = 0.15, IsBoss = true, BossGems = 50,
		},
		VoidDevourer = {
			Name = "Void Devourer", Health = 3000, Speed = 4.5, Reward = 1500, CoreDamage = 50, Scale = 2.6,
			IsBoss = true, BossGems = 150,
		},
		TheEntity = {
			Name = "The Entity", Health = 8400, Speed = 4, Reward = 3000, CoreDamage = 100, Scale = 3.0,
			Armor = 0.1, IsBoss = true, BossGems = 500,
			-- каждые Interval с призывает Count врагов позади себя
			Summon = { Enemy = "LostSoul", Count = 3, Interval = 7 },
		},

		----------------------------------------------------------------
		-- ХЭЛЛОУИН (только на карте Haunted Hollow)
		----------------------------------------------------------------
		CursedDead = {
			Name = "Cursed Dead", Health = 32, Speed = 6.5, Reward = 10, CoreDamage = 1, Scale = 1.0, Event = "Halloween",
			Description = "Медленный проклятый мертвец. После смерти рассыпается в зелёный дым.",
		},
		PumpkinRunner = {
			Name = "Pumpkin Runner", Health = 20, Speed = 16, Reward = 9, CoreDamage = 1, Scale = 0.9, Event = "Halloween",
			Description = "Очень быстрый, но хрупкий. Оставляет оранжевые искры.",
		},
		PhantomWarrior = {
			Name = "Phantom Warrior", Health = 85, Speed = 10.5, Reward = 32, CoreDamage = 3, Scale = 1.05, Event = "Halloween",
			Description = "Периодически становится почти невидимым и получает вдвое меньше урона.",
			Phase = { Every = 6, Duration = 1.5, Taken = 0.5 },
		},
		BoneGuard = {
			Name = "Bone Guard", Health = 240, Speed = 5.5, Reward = 60, CoreDamage = 4, Scale = 1.15, Armor = 0.4, Event = "Halloween",
			Description = "Медленный и крепкий. На половине HP броня ломается (40% → 10%).",
			ArmorBreak = { At = 0.5, Armor = 0.1 },
		},
		LivingScarecrow = {
			Name = "Living Scarecrow", Health = 120, Speed = 8.5, Reward = 38, CoreDamage = 3, Scale = 1.1, Event = "Halloween",
			Description = "После смерти из него выбегают 2 соломенных существа.",
			OnDeath = { Enemy = "StrawMinion", Count = 2 },
		},
		StrawMinion = {
			Name = "Straw Creature", Health = 18, Speed = 12, Reward = 4, CoreDamage = 1, Scale = 0.6, Event = "Halloween",
			Minion = true,
			Description = "Соломенное существо из Живого пугала.",
		},
		FogWarlock = {
			Name = "Fog Warlock", Health = 150, Speed = 7.5, Reward = 55, CoreDamage = 4, Scale = 1.1, Event = "Halloween",
			Description = "Создаёт туман: враги рядом ускоряются на 30% на 2.5 с.",
			Fog = { Every = 6, Radius = 9, Speed = 0.3, Duration = 2.5 },
		},
		PumpkinBrute = {
			Name = "Pumpkin Brute", Health = 560, Speed = 5, Reward = 110, CoreDamage = 8, Scale = 1.55, Event = "Halloween",
			Description = "Огромный тыквенный громила. Много HP, медленный.",
		},
		NightReaper = {
			Name = "Night Reaper", Health = 1500, Speed = 6, Reward = 380, CoreDamage = 20, Scale = 1.8, Armor = 0.2,
			Event = "Halloween", MiniBoss = true, -- мини-босс: только подпись в бестиарии, не IsBoss
			Description = "Мини-босс. Каждые 10 с на 3 с ставит защиту: получает вдвое меньше урона.",
			Shield = { Every = 10, Duration = 3, Taken = 0.5 },
		},

		-- ФИНАЛЬНЫЕ БОССЫ (по одному на сложность)
		GraveWarden = {
			Name = "Grave Warden", Health = 3000, Speed = 4.2, Reward = 2500, CoreDamage = 100, Scale = 2.4, Armor = 0.5,
			IsBoss = true, BossGems = 150, Event = "Halloween",
			Description = "Босс ЛЁГКОЙ сложности. Мощная броня трескается по мере потери HP. Медленный.",
			ArmorScale = true, -- броня = базовая × доля HP
			SpawnStyle = "Grave",
		},
		FogReaper = {
			Name = "Fog Reaper", Health = 4500, Speed = 5, Reward = 3500, CoreDamage = 100, Scale = 2.5, Armor = 0.15,
			IsBoss = true, BossGems = 250, Event = "Halloween",
			Description = "Босс СРЕДНЕЙ сложности. Ускоряется, создаёт туман, ставит защиту. На 50% HP — красное свечение.",
			Haste = { Every = 12, Duration = 3, Speed = 0.6 },
			Fog = { Every = 8, Radius = 10, Speed = 0.3, Duration = 3 },
			Shield = { Every = 15, Duration = 3, Taken = 0.5 },
			Enrage = { At = 0.5, Speed = 0.15 },
			SpawnStyle = "FogVortex",
		},
		CursedMonarch = {
			Name = "Cursed Monarch", Health = 7000, Speed = 4.2, Reward = 5000, CoreDamage = 100, Scale = 2.7, Armor = 0.15,
			IsBoss = true, BossGems = 400, Event = "Halloween",
			Description = "Босс СЛОЖНОЙ сложности. Огненная аура, защита на участках дороги, на 50% HP — вторая фаза и 2 Тыквенных громилы.",
			-- участки дороги { от, до, +броня } (доля длины пути), где броня монарха +35%
			ArmorZones = { { 0.28, 0.40, 0.35 }, { 0.60, 0.72, 0.35 } },
			FireAura = 1.5, -- союзники при столкновении теряют в 1.5 раза больше HP
			Enrage = { At = 0.5, Spawn = { "PumpkinBrute", 2 } },
			SpawnStyle = "Portal",
		},
	},
}
