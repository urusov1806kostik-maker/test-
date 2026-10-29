--!nocheck
-- VOID TD :: Zones (клиент) — круги лобби и Хэллоуин-острова: открывают окна, телепортируют, фильтруют юнитов.
--
-- API
--   Zones.Init(ctx) ; Zones.Update()   -- каждый кадр
--   Zones.List                          -- { {Key, Raw, Center, Radius, Modal, Case, Teleport, EventUnits}, ... }

local Players = game:GetService("Players")

local Zones = {}

local player = Players.LocalPlayer
local ZONE_MODAL = { Units = "Inventory", Play = "Mode", Bestiary = "Bestiary", HalloweenUnits = "Inventory" }

local ctx, Config, UI, FX
local list = {}
Zones.List = list
local inside = {} -- key -> true
local teleportCooldown = 0

local function addSet(prefix, area)
	if not area or not area.Zones then
		return
	end
	for key, z in pairs(area.Zones) do
		list[#list + 1] = {
			Key = prefix .. key,
			Raw = key,
			Center = area.Center + z.Offset,
			Radius = z.Radius,
			Modal = z.Case and "Summon" or ZONE_MODAL[key],
			Case = z.Case,
			Teleport = z.Teleport,
			EventUnits = z.EventUnits,
		}
	end
end

function Zones.Init(c)
	ctx = c
	Config, UI, FX = c.Config, c.UI, c.FX
	table.clear(list)
	addSet("", Config.Lobby)
	addSet("H_", Config.HalloweenIsland)
end

local function within(z, pos)
	local d = pos - z.Center
	return Vector3.new(d.X, 0, d.Z).Magnitude <= z.Radius + 0.5 and math.abs(d.Y) < 8
end

local function enter(z)
	if z.Teleport then
		-- кулдаун: вход не засчитываем, пока он не прошёл (иначе пришлось бы выйти и зайти снова)
		if os.clock() <= teleportCooldown then
			return false
		end
		teleportCooldown = os.clock() + 2
		FX.Sound("Portal", 1, 1)
		UI.Fade(z.Teleport == "Halloween" and "HALLOWEEN" or "ЛОББИ")
		task.delay(0.35, function()
			ctx.Request("Teleport", { To = z.Teleport })
		end)
		return true
	end
	if z.Case then
		UI.SelectCase(z.Case)
	end
	if z.EventUnits then
		UI.SetInventoryFilter(z.EventUnits)
	elseif z.Raw == "Units" then
		UI.SetInventoryFilter(nil)
	end
	if z.Modal then
		UI.Show(z.Modal, true)
	end
	FX.Sound("Click", 1, 1)
	return true
end

local function leave(z)
	if z.Modal then
		UI.Show(z.Modal, false)
	end
	-- фильтр события снимаем при выходе из его круга
	if z.EventUnits and UI.InvFilter == z.EventUnits then
		UI.SetInventoryFilter(nil)
	end
end

function Zones.Update()
	if player:GetAttribute("InMatch") then
		for _, z in ipairs(list) do
			if inside[z.Key] and z.Modal then
				UI.Show(z.Modal, false)
			end
		end
		table.clear(inside)
		UI.UpdateQueue()
		return
	end
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if hrp then
		local pos = hrp.Position
		for _, z in ipairs(list) do
			local now = within(z, pos)
			if now ~= (inside[z.Key] == true) then
				if now then
					if enter(z) then
						inside[z.Key] = true
					end
				else
					inside[z.Key] = nil
					leave(z)
				end
			end
		end
	end
	UI.UpdateQueue()
end

return Zones
