--!nocheck
-- VOID TD :: UI.Mode — окно «ВЫБОР СЛОЖНОСТИ» (круг ИГРАТЬ): карточки сложностей или «ПРИСОЕДИНИТЬСЯ» к идущему бою.
--
-- API
--   Mode.Build(UI, ctx) ; Mode.Refresh() ; Mode.Update() ; Mode.Join(diffKey|nil)

local Mode = {}

local rgb = Color3.fromRGB
local BLACK = Color3.new(0, 0, 0)

local UI, ctx, K, T, Config, refs
local modal, cards, running, runningText

function Mode.Join(key)
	modal.Visible = false
	task.spawn(function()
		local ok = UI.FadeTransition("ПОРТАЛ ОТКРЫВАЕТСЯ...", function()
			return ctx.Request("JoinMatch", { Difficulty = key })
		end)
		if not ok then
			UI.Show("Mode", true)
		end
	end)
end

function Mode.Build(ui, c)
	UI, ctx = ui, c
	K, T, Config, refs = ui.Kit, ui.Theme, c.Config, ui.Refs
	modal = K.modal("Mode", "ВЫБОР СЛОЖНОСТИ", UDim2.fromOffset(880, 430))
	cards = K.new("Frame", { Parent = modal, Position = UDim2.fromOffset(18, 70), Size = UDim2.new(1, -36, 0, 340), BackgroundTransparency = 1 })
	K.new("UIListLayout", { Parent = cards, FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 12), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder })
	for i, key in ipairs(Config.DifficultyOrder) do
		local d = Config.Difficulties[key]
		local card = K.panel({ Parent = cards, LayoutOrder = i, Size = UDim2.fromOffset(200, 336), BackgroundColor3 = T.BG2, StrokeColor = d.Color, ZIndex = 6 })
		K.new("UIGradient", { Parent = card, Rotation = 90, Color = ColorSequence.new(d.Color:Lerp(T.BG, 0.6), T.BG) })
		K.label({ Parent = card, Position = UDim2.fromOffset(8, 10), Size = UDim2.new(1, -16, 0, 40), Text = d.Name, TextColor3 = d.Color, ZIndex = 7 })
		K.label({
			Parent = card, Position = UDim2.fromOffset(10, 56), Size = UDim2.new(1, -20, 0, 116), ZIndex = 7,
			Font = Enum.Font.Code, TextScaled = false, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
			Text = string.format("HP врагов   x%.2g\nСкорость    x%.2g\nДеньги      x%.2g\nГемы        x%.2g\nЯдро        %d HP",
				d.HP, d.Speed, d.Money, d.Gems, math.floor(d.CoreHP + 0.5)),
		})
		K.label({
			Parent = card, Position = UDim2.fromOffset(10, 176), Size = UDim2.new(1, -20, 0, 70), ZIndex = 7, Text = d.Description or "",
			Font = Enum.Font.Gotham, TextScaled = false, TextSize = 14, TextWrapped = true, TextColor3 = T.Dim,
			TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
		})
		K.button({
			Parent = card, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -12), Size = UDim2.new(1, -24, 0, 50), ZIndex = 7,
			Text = "ИГРАТЬ", BackgroundColor3 = d.Color:Lerp(BLACK, 0.45), StrokeColor = d.Color,
		}, function()
			Mode.Join(key)
		end)
	end
	running = K.new("Frame", { Parent = modal, Position = UDim2.fromOffset(18, 80), Size = UDim2.new(1, -36, 0, 300), BackgroundTransparency = 1, Visible = false })
	runningText = K.label({ Parent = running, Size = UDim2.new(1, 0, 0, 120), Text = "", ZIndex = 7 })
	K.button({
		Parent = running, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 160), Size = UDim2.fromOffset(320, 64), ZIndex = 7,
		Text = "ПРИСОЕДИНИТЬСЯ", BackgroundColor3 = T.AccentDark,
	}, function()
		Mode.Join(nil)
	end)
	refs.ModeCards, refs.ModeRunning = cards, running
end

function Mode.Refresh()
	local State = ctx.State
	local phase = State:GetAttribute("Phase") or "Idle"
	local idle = phase == "Idle"
	cards.Visible = idle
	running.Visible = not idle
	if not idle then
		local d = Config.Difficulties[State:GetAttribute("Difficulty") or "Medium"] or Config.Difficulties.Medium
		runningText.Text = "Уже идёт бой: " .. d.Name .. ", волна " .. tostring(State:GetAttribute("Wave") or 0) .. "\nПрисоединяйся к команде!"
		runningText.TextColor3 = d.Color
	end
end

function Mode.Update()
	if modal.Visible then
		Mode.Refresh()
	end
end

return Mode
