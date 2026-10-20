--!nocheck
-- VOID TD :: Config.Units
-- Каталог юнитов: порядок (инвентарь, каталог) + определения из дочерних модулей по кейсам.
--
-- Поля юнита: Name, Rarity, AttackType, Description, Anim, HitDelay, Scale, DefaultTarget, Levels[1..5],
--   опционально Case, Event, Ability, ImpactKind (эффект AOE), ImpactColor, Projectile, ProjectileSpeed, ...
-- AttackType: Melee | Projectile | Laser | AOE | MultiHit | Thread | Splash | Chain | Pierce | Pulse | Flask | Chrono.
-- Levels[i]: Damage, Range, Cooldown, Cost (i = 1 — цена установки, дальше — цена улучшения до уровня i).
-- Id юнитов хранятся в DataStore — переименовывать нельзя.

local Units = {}
for _, name in ipairs({ "Void", "Shattered", "Blood", "Halloween" }) do
	for id, def in pairs(require(script:WaitForChild(name))) do
		assert(Units[id] == nil, "[Config.Units] повтор id: " .. id)
		Units[id] = def
	end
end

local UnitOrder = {
	-- Void Case
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

-- каждый юнит из каталога должен быть в порядке и наоборот
local listed = {}
for _, id in ipairs(UnitOrder) do
	assert(Units[id], "[Config.Units] нет определения: " .. id)
	listed[id] = true
end
for id in pairs(Units) do
	assert(listed[id], "[Config.Units] нет в UnitOrder: " .. id)
end

return {
	UnitOrder = UnitOrder,
	Units = Units,
}
