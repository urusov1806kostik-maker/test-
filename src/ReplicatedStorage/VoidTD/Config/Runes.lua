--!nocheck
-- VOID TD :: Config.Runes
-- HALLOWEEN-руны: своя редкость HALLOWEEN, 1 руна на юнита, без улучшений, работают только надетыми
-- (Profile.RuneSlots[unitId] = runeId; сервер читает руну в юнита при установке).
-- Руны срабатывают только от обычных атак (не от способностей Power и не от эха Призрачной короны).
-- Здесь же союзники — призывы, которые идут по дороге навстречу врагам.

return {
	RuneRarity = { Name = "HALLOWEEN", Color = Color3.fromRGB(255, 130, 30) },

	RuneOrder = { "LanternHeart", "CursedThreads", "PhantomCrown" },

	Runes = {
		LanternHeart = {
			Name = "Сердце фонаря", Color = Color3.fromRGB(255, 140, 40),
			Description = "Каждая 3-я обычная атака вызывает огненный взрыв: 20% урона юнита, радиус 4, до 4 дополнительных врагов.",
			EveryNth = 3, Mult = 0.2, Radius = 4, MaxTargets = 4,
		},
		CursedThreads = {
			Name = "Проклятые нити", Color = Color3.fromRGB(220, 30, 50),
			Description = "Каждая 5-я обычная атака замедляет до 3 врагов на 25% на 2 с (боссов — на 12.5%). Каждые 60 с призывает проклятых людей.",
			EveryNth = 5, Slow = 0.25, SlowTime = 2, MaxTargets = 3,
			-- призыв проклятых: раз в Interval, не больше Max живых; уровень = текущий уровень юнита
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
	},

	-- порядок союзников — часть протокола: Sync передаёт индекс в этом списке
	AllyOrder = {
		"ShadowDouble", "CardSoldier", "MirrorKnight", "PhantomMage", "RoyalIllusion",
		"WoodenDoll", "PorcelainDoll", "ArmoredDoll", "CursedPuppetKnight", "RoyalMarionette", "GoldenMarionette",
		"CursedPerson", "ShadowSoldier", "CursedGuard", "CrimsonWarrior", "CursedKnight",
	},

	-- Союзники: идут по дороге от базы навстречу врагам. HP = запас урона:
	-- при столкновении враг теряет min(HP союзника, HP врага), союзник — столько же.
	-- Family выбирает модель и цвет полосы HP.
	Allies = {
		-- Иллюзионист
		ShadowDouble       = { Name = "Теневой двойник",        Family = "Illusion", Tier = 1 },
		CardSoldier        = { Name = "Карточный солдат",       Family = "Illusion", Tier = 2 },
		MirrorKnight       = { Name = "Зеркальный рыцарь",      Family = "Illusion", Tier = 3 },
		PhantomMage        = { Name = "Фантомный маг",          Family = "Illusion", Tier = 4 },
		RoyalIllusion      = { Name = "Королевская иллюзия",    Family = "Illusion", Tier = 5 },
		-- Кукловод
		WoodenDoll         = { Name = "Деревянная кукла",       Family = "Puppet", Tier = 1 },
		PorcelainDoll      = { Name = "Фарфоровая кукла",       Family = "Puppet", Tier = 2 },
		ArmoredDoll        = { Name = "Бронированная кукла",    Family = "Puppet", Tier = 3 },
		CursedPuppetKnight = { Name = "Проклятый рыцарь",       Family = "Puppet", Tier = 4 },
		RoyalMarionette    = { Name = "Королевская марионетка", Family = "Puppet", Tier = 5 },
		GoldenMarionette   = { Name = "Золотая марионетка",     Family = "Puppet", Tier = 6 },
		-- руна «Проклятые нити»
		CursedPerson       = { Name = "Проклятый человек",      Family = "Cursed", Tier = 1 },
		ShadowSoldier      = { Name = "Теневой солдат",         Family = "Cursed", Tier = 2 },
		CursedGuard        = { Name = "Проклятый страж",        Family = "Cursed", Tier = 3 },
		CrimsonWarrior     = { Name = "Багровый воин",          Family = "Cursed", Tier = 4 },
		CursedKnight       = { Name = "Проклятый рыцарь",       Family = "Cursed", Tier = 5 },
	},
}
