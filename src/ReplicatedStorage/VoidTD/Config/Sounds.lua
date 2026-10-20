--!nocheck
-- VOID TD :: Config.Sounds
-- Custom — свой звук "rbxassetid://ID" (файлы для загрузки лежат в assets/sounds).
-- Пока Custom пустой, играет встроенный звук Roblox с обработкой (Pitch).

local SLASH = "rbxasset://sounds/swordslash.wav"
local LUNGE = "rbxasset://sounds/swordlunge.wav"
local PING = "rbxasset://sounds/electronicpingshort.wav"
local UNSHEATH = "rbxasset://sounds/unsheath.wav"

local function snd(id, volume, pitch)
	return { Custom = "", Id = id, Volume = volume, Pitch = pitch }
end

return {
	Sounds = {
		Slash      = snd(SLASH, 0.35, 1.1),
		HeavyHit   = snd(SLASH, 0.5, 0.65),
		Shoot      = snd(LUNGE, 0.2, 1.6),
		Laser      = snd(LUNGE, 0.45, 0.7),
		Magic      = snd(PING, 0.3, 0.8),
		Explosion  = snd(LUNGE, 0.6, 0.45),
		Place      = snd(UNSHEATH, 0.5, 1),
		Upgrade    = snd(PING, 0.45, 1.3),
		Sell       = snd(PING, 0.4, 0.6),
		Click      = snd(PING, 0.2, 1.8),
		WaveStart  = snd(PING, 0.4, 1),
		Boss       = snd(LUNGE, 0.8, 0.3),
		CoreHit    = snd(SLASH, 0.5, 0.4),
		Victory    = snd(PING, 0.6, 1.2),
		Defeat     = snd(PING, 0.6, 0.45),
		CaseShake  = snd(UNSHEATH, 0.4, 0.7),
		CaseOpen   = snd(LUNGE, 0.7, 0.5),
		Reveal     = snd(PING, 0.35, 1),
		Secret     = snd(LUNGE, 0.9, 0.25),
		Purchase   = snd(PING, 0.5, 1.5),
		Portal     = snd(LUNGE, 0.5, 0.35),
		EnemyDeath = snd(LUNGE, 0.15, 2.2),
	},
}
