--!nocheck
-- VOID TD :: UI.Hotbar — слоты экипировки внизу экрана (клик или 1–6 — начать размещение).
--
-- API
--   Hotbar.Build(UI, ctx) ; Hotbar.Refresh() ; Hotbar.Update(inMatch) ; Hotbar.EquippedAt(i) -> unitId|nil

local Players = game:GetService("Players")

local Hotbar = {}

local player = Players.LocalPlayer
local V2 = Vector2.new

local UI, ctx, K, T, Config, refs
local slots = {}

function Hotbar.EquippedAt(i)
	local p = ctx and ctx.Profile
	return p and p.Equipped and p.Equipped[tostring(i)] or nil
end

function Hotbar.Build(ui, c)
	UI, ctx = ui, c
	K, T, Config, refs = ui.Kit, ui.Theme, c.Config, ui.Refs
	local n = Config.Settings.EquipSlots
	local bar = K.new("Frame", {
		Parent = ui.Root, Name = "Hotbar", AnchorPoint = V2(0.5, 1), Size = UDim2.fromOffset(n * 104, 128),
		Position = UDim2.new(0.5, 0, 1, -12), BackgroundTransparency = 1, Visible = false,
	})
	K.new("UIListLayout", { Parent = bar, FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder })
	refs.Hotbar = bar
	for i = 1, n do
		local b = K.button({ Parent = bar, Name = "Slot" .. i, LayoutOrder = i, Size = UDim2.fromOffset(96, 124), BackgroundColor3 = T.BG2, Text = "" }, function()
			local id = Hotbar.EquippedAt(i)
			if id then
				ctx.Placement.Start(id)
			else
				UI.Toast("Пустой слот: экипируй юнитов в круге ЮНИТЫ в лобби", "error")
			end
		end)
		slots[i] = { Button = b }
	end
end

function Hotbar.Refresh()
	for i, s in ipairs(slots) do
		local b = s.Button
		for _, ch in ipairs(b:GetChildren()) do
			if ch:IsA("ViewportFrame") or ch:IsA("TextLabel") or ch:IsA("Frame") then
				ch:Destroy()
			end
		end
		s.Cost, s.Price = nil, nil
		K.label({ Parent = b, Size = UDim2.fromOffset(20, 20), Position = UDim2.fromOffset(5, 3), Text = tostring(i), TextColor3 = T.Dim, ZIndex = 3 })
		local id = Hotbar.EquippedAt(i)
		local def = id and Config.Units[id]
		if def then
			local col = K.rarityColor(id)
			b.Border.Color = col
			local strip = K.new("Frame", { Parent = b, Position = UDim2.fromOffset(4, 4), Size = UDim2.new(1, -8, 0, 4), BackgroundColor3 = col, BorderSizePixel = 0, ZIndex = 2 })
			K.corner(2).Parent = strip
			K.unitViewport(b, id, 1, { Position = UDim2.fromOffset(0, 6), Size = UDim2.new(1, 0, 0, 82) })
			K.label({ Parent = b, Position = UDim2.fromOffset(3, 86), Size = UDim2.new(1, -6, 0, 16), Text = def.Name, Font = Enum.Font.GothamBold })
			s.Price = def.Levels[1].Cost
			s.Cost = K.label({ Parent = b, Position = UDim2.fromOffset(3, 102), Size = UDim2.new(1, -6, 0, 18), Text = "$" .. Config.FormatNumber(s.Price), TextColor3 = T.Good })
		else
			b.Border.Color = T.AccentDark
			K.label({ Parent = b, Position = UDim2.fromOffset(5, 40), Size = UDim2.new(1, -10, 0, 40), Text = "+", TextColor3 = T.Dim })
		end
	end
end

function Hotbar.Update(inMatch)
	refs.Hotbar.Visible = inMatch
	if not inMatch then
		return
	end
	local money = player:GetAttribute("Money") or 0
	for _, s in ipairs(slots) do
		if s.Cost then
			s.Cost.TextColor3 = money >= s.Price and T.Good or T.Bad
		end
	end
end

return Hotbar
