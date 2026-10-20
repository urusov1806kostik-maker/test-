--!nocheck
-- VOID TD :: Config.Rarities
-- Редкости юнитов. Order — порядок (сортировка, питч раскрытия, pity x10),
-- PlacementLimit — сколько копий одного юнита игрок может поставить.
-- Rate не используется кодом (шансы задаются в Config.Cases), оставлен для справки: сумма = 100.

return {
	RarityOrder = { "Common", "Rare", "Epic", "Legendary", "Mythic", "Secret" },

	Rarities = {
		Common    = { Order = 1, Color = Color3.fromRGB(165, 165, 175), Rate = 72,  PlacementLimit = 6 },
		Rare      = { Order = 2, Color = Color3.fromRGB(60, 140, 255),  Rate = 21,  PlacementLimit = 5 },
		Epic      = { Order = 3, Color = Color3.fromRGB(170, 80, 255),  Rate = 5.5, PlacementLimit = 4 },
		Legendary = { Order = 4, Color = Color3.fromRGB(255, 195, 50),  Rate = 1.3, PlacementLimit = 3 },
		Mythic    = { Order = 5, Color = Color3.fromRGB(235, 40, 130),  Rate = 0.2, PlacementLimit = 2 },
		-- Secret есть только в новых кейсах (шанс задаётся в Config.Cases)
		Secret    = { Order = 6, Color = Color3.fromRGB(255, 25, 45),   Rate = 0,   PlacementLimit = 1 },
	},
}
