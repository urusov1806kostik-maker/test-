--!nocheck
-- VOID TD :: UI.Inventory — окно «ЮНИТЫ»: экипировка (6 слотов), коллекция, описание и таблица уровней,
-- руна юнита, EQUIP / UNEQUIP. Клик по открытому юниту — 3D-просмотр.
--
-- API
--   Inventory.Build(UI, ctx) ; Inventory.Refresh() ; Inventory.ToggleEquip(unitId) ; Inventory.SetFilter(eventKey|nil)

local Inventory = {}

local rgb = Color3.fromRGB
local V2 = Vector2.new

local UI, ctx, K, T, Config, refs
local modal, selected

local function prof()
	return ctx.Profile or {}
end

local function owned(id)
	local inv = prof().Inventory
	return inv and (inv[id] or 0) > 0
end

local function slotOf(id)
	local eq = prof().Equipped or {}
	for i = 1, Config.Settings.EquipSlots do
		if eq[tostring(i)] == id then
			return i
		end
	end
	return nil
end

function Inventory.ToggleEquip(id)
	if not owned(id) then
		return
	end
	local slot = slotOf(id)
	if slot then
		ctx.Request("Equip", { Unit = nil, Slot = slot })
		return
	end
	local eq = prof().Equipped or {}
	for i = 1, Config.Settings.EquipSlots do
		if not eq[tostring(i)] then
			ctx.Request("Equip", { Unit = id, Slot = i })
			return
		end
	end
	UI.Toast("Все слоты заняты — сними юнита сверху", "error")
end

function Inventory.SetFilter(ev)
	UI.InvFilter = ev
	if modal and modal.Visible then
		Inventory.Refresh()
	end
end

local function clear(frame)
	for _, ch in ipairs(frame:GetChildren()) do
		if ch:IsA("GuiObject") then
			ch:Destroy()
		end
	end
end

local function fmtStats(def)
	local lines = { "LV   DMG     RNG   CD     COST" }
	local fmt = Config.FormatNumber
	for i, st in ipairs(def.Levels) do
		lines[#lines + 1] = string.format("%-4d %-7s %-5s %-6s $%s", i, fmt(st.Damage), tostring(st.Range), string.format("%.2f", st.Cooldown), fmt(st.Cost))
	end
	return table.concat(lines, "\n")
end

local function select(id)
	selected = id
	local def = Config.Units[id]
	if not def then
		return
	end
	local have = owned(id)
	refs.InvName.Text = have and def.Name or "???"
	refs.InvName.TextColor3 = K.rarityColor(id)
	local ev = def.Event and Config.Events[def.Event]
	refs.InvRarity.Text = string.upper(def.Rarity) .. (ev and ("  •  " .. ev.Tag) or "") .. (def.Ability and ("  •  " .. def.Ability) or "")
	refs.InvRarity.TextColor3 = K.rarityColor(id)
	refs.InvDesc.Text = def.Description or ""
	refs.InvStats.Text = fmtStats(def)
	refs.InvEquip.Visible = have
	refs.InvRune.Visible = have
	if have then
		local eq = slotOf(id) ~= nil
		refs.InvEquip.Text = eq and "UNEQUIP" or "EQUIP"
		refs.InvEquip.BackgroundColor3 = eq and rgb(130, 50, 60) or rgb(60, 130, 80)
		local runeId = (prof().RuneSlots or {})[id]
		local rd = runeId and Config.Runes[runeId]
		refs.InvRune.Text = rd and ("РУНА: " .. rd.Name .. "  (сменить)") or "РУНА: нет  (надеть)"
	end
end

function Inventory.Refresh()
	if not modal then
		return
	end
	local p = prof()
	local eq = p.Equipped or {}
	-- экипировка
	clear(refs.EquipRow)
	for i = 1, Config.Settings.EquipSlots do
		local id = eq[tostring(i)]
		local b = K.button({ Parent = refs.EquipRow, LayoutOrder = i, Size = UDim2.fromOffset(92, 90), Text = "", BackgroundColor3 = T.BG2, StrokeColor = id and K.rarityColor(id) or T.AccentDark, ZIndex = 7 }, function()
			if id then
				ctx.Request("Equip", { Unit = nil, Slot = i })
			end
		end)
		if id then
			K.unitViewport(b, id, 1, { ZIndex = 8 })
		else
			K.label({ Parent = b, Size = UDim2.fromScale(1, 1), Text = tostring(i), TextColor3 = T.Dim, ZIndex = 8 })
		end
	end
	-- коллекция
	clear(refs.InvGrid)
	local inv = p.Inventory or {}
	local slots = p.RuneSlots or {}
	for i, id in ipairs(Config.UnitOrder) do
		local def = Config.Units[id]
		if def and (not UI.InvFilter or def.Event == UI.InvFilter) then
			local count = inv[id] or 0
			local have = count > 0
			local col = K.rarityColor(id)
			local card = K.button({ Parent = refs.InvGrid, LayoutOrder = i, Text = "", BackgroundColor3 = T.BG2, StrokeColor = have and col or rgb(60, 50, 70), ZIndex = 7 }, function()
				select(id)
				if owned(id) then
					UI.Viewer.Open(id, 1)
				else
					UI.Toast("Сначала открой этого юнита в кейсе — тогда откроется 3D-просмотр", "error")
				end
			end)
			K.new("UIGradient", { Parent = card, Rotation = 90, Color = ColorSequence.new(col:Lerp(T.BG, have and 0.6 or 0.9), T.BG) })
			K.unitViewport(card, id, 1, { Size = UDim2.new(1, 0, 0, 96), ZIndex = 8, Silhouette = not have })
			K.label({ Parent = card, Position = UDim2.fromOffset(4, 98), Size = UDim2.new(1, -8, 0, 18), Text = have and def.Name or "???", Font = Enum.Font.GothamBold, ZIndex = 8 })
			K.label({ Parent = card, Position = UDim2.fromOffset(4, 118), Size = UDim2.new(1, -8, 0, 16), Text = def.Rarity, TextColor3 = col, ZIndex = 8 })
			if have then
				K.label({ Parent = card, Position = UDim2.new(1, -44, 0, 4), Size = UDim2.fromOffset(40, 20), Text = "x" .. count, TextColor3 = T.Gold, ZIndex = 9 })
			end
			if slots[id] then
				K.icon("Rune", card, { Size = UDim2.fromOffset(20, 20), Position = UDim2.new(1, -24, 0, 26), ZIndex = 10 })
			end
			K.eventTag(card, id, 8, UDim2.fromOffset(4, 82))
		end
	end
	if selected then
		select(selected)
	end
end

function Inventory.Build(ui, c)
	UI, ctx = ui, c
	K, T, Config, refs = ui.Kit, ui.Theme, c.Config, ui.Refs
	modal = K.modal("Inventory", "ЮНИТЫ", UDim2.fromOffset(860, 560), "Helmet")
	K.label({ Parent = modal, Position = UDim2.fromOffset(18, 56), Size = UDim2.fromOffset(300, 22), Text = "ЭКИПИРОВКА (клик — снять)", TextColor3 = T.Dim, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 6 })
	local row = K.new("Frame", { Parent = modal, Position = UDim2.fromOffset(18, 80), Size = UDim2.new(1, -36, 0, 92), BackgroundTransparency = 1 })
	K.new("UIListLayout", { Parent = row, FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder })
	refs.EquipRow = row
	local grid = K.new("ScrollingFrame", {
		Parent = modal, Position = UDim2.fromOffset(18, 182), Size = UDim2.new(0, 500, 1, -196), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), ScrollBarThickness = 6,
	})
	K.new("UIGridLayout", { Parent = grid, CellSize = UDim2.fromOffset(112, 140), CellPadding = UDim2.fromOffset(10, 10), SortOrder = Enum.SortOrder.LayoutOrder })
	K.pad(4).Parent = grid
	refs.InvGrid = grid
	local det = K.new("Frame", { Parent = modal, Position = UDim2.fromOffset(536, 182), Size = UDim2.new(1, -556, 1, -196), BackgroundColor3 = T.BG2, BorderSizePixel = 0, ZIndex = 6 })
	K.corner(10).Parent = det
	local left, top = Enum.TextXAlignment.Left, Enum.TextYAlignment.Top
	refs.InvName = K.label({ Parent = det, Position = UDim2.fromOffset(10, 8), Size = UDim2.new(1, -20, 0, 30), Text = "Выбери юнита", TextXAlignment = left, ZIndex = 7 })
	refs.InvRarity = K.label({ Parent = det, Position = UDim2.fromOffset(10, 38), Size = UDim2.new(1, -20, 0, 18), Text = "", TextXAlignment = left, ZIndex = 7 })
	refs.InvDesc = K.label({ Parent = det, Position = UDim2.fromOffset(10, 60), Size = UDim2.new(1, -20, 0, 48), Text = "", TextScaled = false, TextSize = 14, TextWrapped = true, Font = Enum.Font.Gotham, TextColor3 = T.Dim, TextXAlignment = left, TextYAlignment = top, ZIndex = 7 })
	refs.InvStats = K.label({ Parent = det, Position = UDim2.fromOffset(10, 110), Size = UDim2.new(1, -20, 0, 120), Text = "", TextScaled = false, TextSize = 14, Font = Enum.Font.Code, TextXAlignment = left, TextYAlignment = top, ZIndex = 7 })
	refs.InvRune = K.button({
		Parent = det, AnchorPoint = V2(0, 1), Position = UDim2.new(0, 10, 1, -60), Size = UDim2.new(1, -20, 0, 34), ZIndex = 7, Visible = false,
		Text = "РУНА: нет", TextColor3 = rgb(255, 170, 70), BackgroundColor3 = rgb(50, 26, 20), StrokeColor = rgb(255, 130, 30),
	}, function()
		if selected then
			UI.Halloween.OpenRunePicker(selected)
		end
	end)
	refs.InvEquip = K.button({ Parent = det, AnchorPoint = V2(0, 1), Position = UDim2.new(0, 10, 1, -10), Size = UDim2.new(1, -20, 0, 44), Text = "EQUIP", BackgroundColor3 = rgb(60, 130, 80), Visible = false, ZIndex = 7 }, function()
		if selected then
			Inventory.ToggleEquip(selected)
		end
	end)
end

return Inventory
