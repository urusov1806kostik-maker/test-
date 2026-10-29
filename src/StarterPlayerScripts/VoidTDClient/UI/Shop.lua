--!nocheck
-- VOID TD :: UI.Shop — «МАГАЗИН КРИСТАЛЛОВ»: наборы кристаллов за Robux и ежедневный подарок.
--
-- API
--   Shop.Build(UI, ctx) ; Shop.Update()   -- таймер подарка, пока окно открыто

local Shop = {}

local rgb = Color3.fromRGB
local V2 = Vector2.new

local UI, ctx, K, T, Config, refs
local modal, dailyButton

function Shop.Build(ui, c)
	UI, ctx = ui, c
	K, T, Config, refs = ui.Kit, ui.Theme, c.Config, ui.Refs
	modal = K.modal("Shop", "МАГАЗИН КРИСТАЛЛОВ", UDim2.fromOffset(920, 470), "Gem")
	local row = K.new("Frame", { Parent = modal, Position = UDim2.fromOffset(18, 70), Size = UDim2.new(1, -36, 0, 270), BackgroundTransparency = 1 })
	K.new("UIListLayout", { Parent = row, FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder })
	for i, item in ipairs(Config.Shop) do
		local card = K.panel({ Parent = row, LayoutOrder = i, Size = UDim2.fromOffset(165, 266), BackgroundColor3 = T.BG2, StrokeColor = rgb(90, 180, 255), ZIndex = 6 })
		K.new("UIGradient", { Parent = card, Rotation = 90, Color = ColorSequence.new(rgb(40, 70, 120), T.BG) })
		K.label({ Parent = card, Position = UDim2.fromOffset(5, 12), Size = UDim2.new(1, -10, 0, 70), Text = string.rep("💎", math.min(i, 3)), ZIndex = 7 })
		K.label({ Parent = card, Position = UDim2.fromOffset(5, 86), Size = UDim2.new(1, -10, 0, 40), Text = Config.FormatNumber(item.Gems), TextColor3 = rgb(130, 210, 255), ZIndex = 7 })
		K.label({ Parent = card, Position = UDim2.fromOffset(5, 128), Size = UDim2.new(1, -10, 0, 34), Text = item.Title or "", TextScaled = false, TextSize = 14, TextWrapped = true, Font = Enum.Font.GothamBold, ZIndex = 7 })
		if item.Bonus then
			K.label({ Parent = card, Position = UDim2.new(1, -74, 0, 6), Size = UDim2.fromOffset(70, 24), Text = item.Bonus, TextColor3 = T.Gold, Rotation = 10, ZIndex = 8 })
		end
		K.button({
			Parent = card, AnchorPoint = V2(0.5, 1), Position = UDim2.new(0.5, 0, 1, -12), Size = UDim2.new(1, -20, 0, 48), ZIndex = 7,
			Text = "R$ " .. tostring(item.Robux), BackgroundColor3 = rgb(50, 140, 80), StrokeColor = T.Good,
		}, function()
			local ok, res = ctx.Request("BuyGems", { Key = item.Key })
			if ok and res ~= "prompt" then
				ctx.FX.Sound("Purchase", 1, 1)
				UI.Toast("+" .. Config.FormatNumber(item.Gems) .. " 💎 (тестовая покупка в Studio)", "good")
			end
		end)
	end
	local daily = K.panel({ Parent = modal, Position = UDim2.new(0, 18, 1, -90), Size = UDim2.new(1, -36, 0, 74), BackgroundColor3 = T.BG2, StrokeColor = T.Gold, ZIndex = 6 })
	K.label({
		Parent = daily, Position = UDim2.fromOffset(16, 12), Size = UDim2.new(1, -300, 1, -24), ZIndex = 7, TextXAlignment = Enum.TextXAlignment.Left,
		Text = "🎁 Бесплатный подарок: " .. tostring(Config.Settings.DailyGems) .. " 💎", TextColor3 = T.Gold,
	})
	dailyButton = K.button({
		Parent = daily, Name = "DailyButton", AnchorPoint = V2(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(260, 52), ZIndex = 7,
		Text = "ЗАБРАТЬ", BackgroundColor3 = rgb(150, 110, 30), StrokeColor = T.Gold,
	}, function()
		local ok, res = ctx.Request("ClaimDaily")
		if ok then
			ctx.FX.Sound("Purchase", 1, 1.2)
			UI.Toast("+" .. tostring(res) .. " 💎 Подарок получен!", "gold")
		end
	end)
	refs.DailyButton = dailyButton
end

function Shop.Update()
	if not modal.Visible then
		return
	end
	local p = ctx.Profile
	local left = math.floor((p and p.DailyReadyAt or 0) - os.time())
	if left > 0 then
		dailyButton.Text = string.format("через %d:%02d:%02d", left // 3600, (left % 3600) // 60, left % 60)
	else
		dailyButton.Text = "ЗАБРАТЬ"
	end
end

return Shop
