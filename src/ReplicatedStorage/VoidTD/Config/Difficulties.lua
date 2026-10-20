--!nocheck
-- VOID TD :: Config.Difficulties
-- Сложность выбирается в портале PLAY в лобби.
-- HP / Speed — множители врагов, Money — множитель денег, Gems — множитель кристаллов,
-- CoreHP — здоровье ядра, Intermission — секунд между волнами.
-- Здесь же режимы прицеливания юнитов.

return {
	TargetModes = { "First", "Last", "Strongest", "Weakest", "Closest" },

	DifficultyOrder = { "Easy", "Medium", "Hard", "Hardcore" },

	Difficulties = {
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
	},
}
