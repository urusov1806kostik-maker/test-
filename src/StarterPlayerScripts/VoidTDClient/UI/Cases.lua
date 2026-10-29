--!nocheck
-- VOID TD :: UI.Cases — окно «КЕЙСЫ»: вкладки кейсов, большое 3D-превью, шансы, юниты кейса, x1 / x10.
--
-- API
--   Cases.Build(UI, ctx) ; Cases.Select(caseId) ; Cases.Update(t) ; Cases.Selected -> caseId

local Players = game:GetService("Players")

local Cases = {}

local player = Players.LocalPlayer
local rgb = Color3.fromRGB
local V2 = Vector2.new

local UI, ctx, K, T, Config, refs
local modal, bigModel
local busy = false
Cases.Selected = "VoidCase"

local function hex(c)
	return "#" .. c:ToHex()
end

local function rateText(case)
	local lines = {}
	if case.Rewards then
		for _, r in ipairs(case.Rewards) do
			local name, col
			if r.Rune then
				local rd = Config.Runes[r.Rune]
				name, col = "Руна «" .. (rd and rd.Name or r.Rune) .. "»", Config.RuneRarity.Color
			else
				local def = Config.Units[r.Unit]
				name = (def and def.Name or r.Unit) .. " (" .. (def and def.Rarity or "?") .. ")"
				col = K.rarityColor(r.Unit)
			end
			lines[#lines + 1] = string.format('<font color="%s">%s</font>  %s%%', hex(col), name, tostring(r.Rate))
		end
	else
		for _, rar in ipairs(Config.RarityOrder) do
			local rate = case.Rates and case.Rates[rar]
			if rate and rate > 0 then
				lines[#lines + 1] = string.format('<font color="%s">%s</font>  %s%%', hex(Config.Rarities[rar].Color), string.upper(rar), tostring(rate))
			end
		end
	end
	return table.concat(lines, "\n")
end

local function fillUnits(case)
	local box = refs.CaseUnits
	for _, ch in ipairs(box:GetChildren()) do
		if ch:IsA("GuiObject") then
			ch:Destroy()
		end
	end
	for i, id in ipairs(case.Units or {}) do
		local def = Config.Units[id]
		if def then
			local col = K.rarityColor(id)
			local cell = K.panel({ Parent = box, LayoutOrder = Config.Rarities[def.Rarity].Order * 100 + i, Size = UDim2.fromOffset(100, 108), BackgroundColor3 = T.BG2, StrokeColor = col, ZIndex = 7 })
			K.unitViewport(cell, id, 1, { Size = UDim2.new(1, 0, 0, 74), ZIndex = 8 })
			K.label({ Parent = cell, Position = UDim2.fromOffset(3, 74), Size = UDim2.new(1, -6, 0, 16), Text = def.Name, Font = Enum.Font.GothamBold, ZIndex = 8 })
			K.label({ Parent = cell, Position = UDim2.fromOffset(3, 90), Size = UDim2.new(1, -6, 0, 14), Text = def.Rarity, TextColor3 = col, ZIndex = 8 })
			K.eventTag(cell, id, 8)
		end
	end
	for i, r in ipairs(case.Rewards or {}) do
		local rd = r.Rune and Config.Runes[r.Rune]
		if rd then
			local col = Config.RuneRarity.Color
			local cell = K.panel({ Parent = box, LayoutOrder = 1000 + i, Size = UDim2.fromOffset(100, 108), BackgroundColor3 = T.BG2, StrokeColor = col, ZIndex = 7 })
			K.runeViewport(cell, r.Rune, { Size = UDim2.new(1, 0, 0, 74), ZIndex = 8 })
			K.label({ Parent = cell, Position = UDim2.fromOffset(3, 74), Size = UDim2.new(1, -6, 0, 16), Text = rd.Name, Font = Enum.Font.GothamBold, ZIndex = 8 })
			K.label({ Parent = cell, Position = UDim2.fromOffset(3, 90), Size = UDim2.new(1, -6, 0, 14), Text = "РУНА • HALLOWEEN", TextColor3 = col, ZIndex = 8 })
		end
	end
end

function Cases.Select(caseId)
	local case = Config.Cases[caseId]
	if not case then
		return
	end
	Cases.Selected = caseId
	refs.CaseName.Text = case.Name
	refs.CaseName.TextColor3 = case.Color
	refs.CaseDesc.Text = case.Description or ""
	refs.CaseRates.TextSize = case.Rewards and 13 or 18
	refs.CaseRates.Text = rateText(case)
	refs.CasePity.Visible = not case.Single
	local glyph = case.Currency == "HalloweenCoins" and "🎃" or "💎"
	refs.Buy1.Text = (case.Single and "ОТКРЫТЬ  " or "x1  ") .. glyph .. tostring(case.Cost1)
	refs.Buy10.Visible = not case.Single and case.Cost10 ~= nil
	if case.Cost10 then
		refs.Buy10.Text = "x10  " .. glyph .. tostring(case.Cost10)
	end
	-- большое превью
	local big = refs.CaseBig
	for _, ch in ipairs(big:GetChildren()) do
		if ch:IsA("ViewportFrame") then
			ch:Destroy()
		end
	end
	local r = K.caseViewport(big, caseId)
	bigModel = r.Model
	for id, tab in pairs(refs.CaseTabs) do
		tab.Border.Color = id == caseId and Config.Cases[id].Color or T.AccentDark
	end
	fillUnits(case)
end

local function open(count)
	if busy or UI.Openings.Busy() then
		return
	end
	busy = true
	local caseId = Cases.Selected
	local ok, res = ctx.Request("Summon", { Case = caseId, Count = count })
	busy = false
	if ok and type(res) == "table" then
		if caseId == "Halloween" then
			UI.Openings.PlayHalloween(res)
		else
			UI.Openings.PlayCase(caseId, res)
		end
	end
end

function Cases.Build(ui, c)
	UI, ctx = ui, c
	K, T, Config, refs = ui.Kit, ui.Theme, c.Config, ui.Refs
	modal = K.modal("Summon", "КЕЙСЫ", UDim2.fromOffset(980, 590), "Gem")
	local tabs = K.new("Frame", { Parent = modal, Position = UDim2.fromOffset(18, 70), Size = UDim2.fromOffset(200, 480), BackgroundTransparency = 1 })
	K.new("UIListLayout", { Parent = tabs, Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder })
	refs.CaseTabs = {}
	for i, id in ipairs(Config.CaseOrder) do
		local case = Config.Cases[id]
		local b = K.button({ Parent = tabs, LayoutOrder = i, Size = UDim2.fromOffset(200, 140), Text = "", BackgroundColor3 = T.BG2, StrokeColor = case.Color, ZIndex = 7 }, function()
			Cases.Select(id)
			ctx.FX.Sound("Click", 1, 1)
		end)
		K.caseViewport(b, id, { Size = UDim2.new(1, 0, 0, 100), ZIndex = 8 })
		K.label({ Parent = b, Position = UDim2.fromOffset(5, 104), Size = UDim2.new(1, -10, 0, 26), Text = case.Name, TextColor3 = case.Color, ZIndex = 8 })
		refs.CaseTabs[id] = b
	end
	local big = K.new("Frame", { Parent = modal, Position = UDim2.fromOffset(236, 70), Size = UDim2.fromOffset(300, 300), BackgroundColor3 = T.BG2, BackgroundTransparency = 0.3, BorderSizePixel = 0, ZIndex = 6 })
	K.corner(10).Parent = big
	refs.CaseBig = big
	local left = Enum.TextXAlignment.Left
	local top = Enum.TextYAlignment.Top
	refs.CaseName = K.label({ Parent = modal, Position = UDim2.fromOffset(548, 70), Size = UDim2.fromOffset(420, 40), Text = "", TextXAlignment = left, ZIndex = 6 })
	refs.CaseDesc = K.label({ Parent = modal, Position = UDim2.fromOffset(548, 112), Size = UDim2.fromOffset(420, 40), Text = "", TextScaled = false, TextSize = 15, TextWrapped = true, Font = Enum.Font.Gotham, TextColor3 = T.Dim, TextXAlignment = left, TextYAlignment = top, ZIndex = 6 })
	refs.CaseRates = K.label({ Parent = modal, Position = UDim2.fromOffset(548, 156), Size = UDim2.fromOffset(420, 150), Text = "", RichText = true, TextScaled = false, TextSize = 18, TextXAlignment = left, TextYAlignment = top, ZIndex = 6 })
	refs.CasePity = K.label({ Parent = modal, Position = UDim2.fromOffset(548, 306), Size = UDim2.fromOffset(420, 20), Text = "В x10 гарантирован минимум один Rare+", TextScaled = false, TextSize = 14, Font = Enum.Font.GothamBold, TextColor3 = T.Dim, TextXAlignment = left, ZIndex = 6 })
	local units = K.new("ScrollingFrame", {
		Parent = modal, Position = UDim2.fromOffset(236, 380), Size = UDim2.fromOffset(732, 150), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 6,
		ScrollingDirection = Enum.ScrollingDirection.X, AutomaticCanvasSize = Enum.AutomaticSize.X, CanvasSize = UDim2.new(), ScrollBarThickness = 6,
	})
	K.new("UIListLayout", { Parent = units, FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder })
	refs.CaseUnits = units
	refs.SummonGems = K.label({ Parent = modal, Position = UDim2.new(0, 236, 1, -52), Size = UDim2.fromOffset(240, 36), Text = "", TextColor3 = rgb(120, 200, 255), TextXAlignment = left, ZIndex = 6 })
	refs.Buy1 = K.button({ Parent = modal, AnchorPoint = V2(1, 1), Position = UDim2.new(1, -238, 1, -12), Size = UDim2.fromOffset(200, 50), Text = "x1", BackgroundColor3 = T.AccentDark, ZIndex = 6 }, function()
		open(1)
	end)
	refs.Buy10 = K.button({ Parent = modal, AnchorPoint = V2(1, 1), Position = UDim2.new(1, -18, 1, -12), Size = UDim2.fromOffset(210, 50), Text = "x10", BackgroundColor3 = rgb(150, 60, 200), StrokeColor = T.Gold, ZIndex = 6 }, function()
		open(10)
	end)
	Cases.Select(Cases.Selected)
end

function Cases.Update(t)
	if not modal.Visible then
		return
	end
	local prof = ctx.Profile or {}
	if Cases.Selected == "Halloween" then
		refs.SummonGems.Text = "🎃 " .. Config.FormatNumber(player:GetAttribute("HalloweenCoins") or prof.HalloweenCoins or 0)
		refs.SummonGems.TextColor3 = rgb(255, 160, 60)
	else
		refs.SummonGems.Text = "💎 " .. Config.FormatNumber(player:GetAttribute("Gems") or prof.Gems or 0)
		refs.SummonGems.TextColor3 = rgb(120, 200, 255)
	end
	if bigModel and bigModel.Parent then
		bigModel:PivotTo(CFrame.Angles(0, t * 0.6, 0))
	end
end

return Cases
