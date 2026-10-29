--!nocheck
-- VOID TD :: UI.HUD — валюта, волна и ядро, полоса босса, кнопка волны, иконки справа, «В ЛОББИ»,
-- подсказка размещения и тач-кнопки, тосты и объявления.
--
-- API
--   HUD.Build(UI, ctx) ; HUD.Update(dt, inMatch)
--   HUD.Toast(text, kind) ; HUD.Announce(title, sub, color) ; HUD.SetLiteText(on)
--   HUD.ShowPlacementHint(on, touch) ; HUD.SetMapMode(key) ; HUD.CoreHit()

local Players = game:GetService("Players")

local HUD = {}

local player = Players.LocalPlayer
local rgb = Color3.fromRGB
local V2 = Vector2.new
local ORANGE = rgb(255, 130, 30)

local UI, ctx, K, T, Config, refs

local TOAST_COLOR = { error = "Bad", good = "Good", boss = "Pink", gold = "Gold" }

function HUD.Toast(text, kind)
	if not refs or not refs.Toasts then
		return
	end
	local color = T[TOAST_COLOR[kind] or "Accent"]
	-- не больше 6 тостов: старый уходит
	local list = refs.Toasts:GetChildren()
	local n = 0
	for _, c in ipairs(list) do
		if c:IsA("Frame") then
			n += 1
		end
	end
	if n >= 6 then
		for _, c in ipairs(list) do
			if c:IsA("Frame") then
				c:Destroy()
				break
			end
		end
	end
	local p = K.panel({ Parent = refs.Toasts, Size = UDim2.fromOffset(380, 38), StrokeColor = color, BackgroundTransparency = 0.05 })
	local l = K.label({ Parent = p, Position = UDim2.fromOffset(8, 5), Size = UDim2.new(1, -16, 1, -10), Text = tostring(text or ""), TextColor3 = color })
	local sc = K.new("UIScale", { Parent = p, Scale = 0.6 })
	K.tween(sc, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
	task.delay(2.6, function()
		if p.Parent then
			K.tween(p, 0.3, { BackgroundTransparency = 1 })
			K.tween(l, 0.3, { TextTransparency = 1 })
			task.delay(0.32, function()
				p:Destroy()
			end)
		end
	end)
end

function HUD.Announce(title, sub, color)
	local h = refs.Announce
	h:ClearAllChildren()
	local sc = K.new("UIScale", { Parent = h, Scale = 0.3 })
	K.tween(sc, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	local t1 = K.label({ Parent = h, Size = UDim2.new(1, 0, 0.62, 0), Text = title or "", TextColor3 = color or T.Text, StrokeThickness = 3 })
	local t2
	if sub then
		t2 = K.label({ Parent = h, Position = UDim2.fromScale(0, 0.66), Size = UDim2.new(1, 0, 0.32, 0), Text = sub, TextColor3 = T.Dim })
	end
	h.Visible = true
	task.delay(2.2, function()
		if t1.Parent then
			K.tween(t1, 0.4, { TextTransparency = 1 })
			if t2 then
				K.tween(t2, 0.4, { TextTransparency = 1 })
			end
		end
	end)
end

function HUD.SetLiteText(on)
	if refs.LiteCaption then
		refs.LiteCaption.Text = on and "ЛЁГКАЯ" or "ПОЛНАЯ"
		refs.LiteCaption.TextColor3 = on and T.Good or T.Text
	end
end

function HUD.ShowPlacementHint(on, touch)
	refs.PlaceHint.Visible = on and not touch or false
	refs.TouchBar.Visible = on and touch or false
end

local function coreColor()
	return UI.MapMode == "Halloween" and ORANGE or T.Accent
end

function HUD.SetMapMode(key)
	UI.MapMode = key
	refs.CoreFill.BackgroundColor3 = coreColor()
end

function HUD.CoreHit()
	refs.CoreFill.BackgroundColor3 = T.Bad
	K.tween(refs.CoreFill, 0.4, { BackgroundColor3 = coreColor() })
end

------------------------------------------------------------------------
-- ПОСТРОЕНИЕ
------------------------------------------------------------------------
local function buildCurrency(root)
	local cur = K.panel({ Parent = root, Name = "Currency", Size = UDim2.fromOffset(230, 92), Position = UDim2.fromOffset(16, 16) })
	refs.Currency = cur
	local function row(y, color, icon, iy, isz, ix)
		local l = K.label({ Parent = cur, Position = UDim2.fromOffset(52, y), Size = UDim2.new(1, -60, 0, 32), Text = "0", TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = color })
		local ic = K.icon(icon, cur, { Size = UDim2.fromOffset(isz, isz), Position = UDim2.fromOffset(ix, iy) })
		return l, ic
	end
	refs.Money, refs.MoneyIcon = row(6, rgb(255, 220, 120), "Coin", 7, 34, 10)
	refs.Money.Size = UDim2.new(1, -60, 0, 36)
	refs.Gems, refs.GemsIcon = row(50, rgb(150, 200, 255), "Gem", 49, 34, 10)
	refs.Coins, refs.CoinsIcon = row(92, rgb(255, 160, 60), "Pumpkin", 91, 32, 11)
	refs.Coins.Size = UDim2.new(1, -60, 0, 30)
end

local function buildTop(root)
	local top = K.panel({ Parent = root, Name = "Top", AnchorPoint = V2(0.5, 0), Size = UDim2.fromOffset(420, 104), Position = UDim2.new(0.5, 0, 0, 12), Visible = false })
	refs.Top = top
	refs.Wave = K.label({ Parent = top, Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -20, 0, 40), Text = "WAVE 0 / 30" })
	refs.Status = K.label({ Parent = top, Position = UDim2.fromOffset(10, 44), Size = UDim2.new(1, -20, 0, 22), Text = "", TextColor3 = T.Dim, Font = Enum.Font.GothamBold })
	local bar = K.new("Frame", { Parent = top, Position = UDim2.fromOffset(12, 72), Size = UDim2.new(1, -24, 0, 24), BackgroundColor3 = rgb(25, 12, 32), BorderSizePixel = 0 })
	K.corner(6).Parent = bar
	local fill = K.new("Frame", { Parent = bar, Size = UDim2.fromScale(1, 1), BackgroundColor3 = T.Accent, BorderSizePixel = 0 })
	K.corner(6).Parent = fill
	K.new("UIGradient", { Parent = fill, Color = ColorSequence.new(rgb(120, 50, 220), rgb(230, 120, 255)) })
	refs.CoreFill = fill
	refs.CoreText = K.label({ Parent = bar, Size = UDim2.fromScale(1, 1), Text = "VOID CORE 100 / 100", ZIndex = 2 })

	local boss = K.panel({ Parent = root, Name = "BossBar", AnchorPoint = V2(0.5, 0), Size = UDim2.fromOffset(560, 46), Position = UDim2.new(0.5, 0, 0, 124), StrokeColor = T.Pink, Visible = false })
	refs.Boss = boss
	local bb = K.new("Frame", { Parent = boss, Position = UDim2.fromOffset(8, 20), Size = UDim2.new(1, -16, 0, 20), BackgroundColor3 = rgb(30, 8, 20), BorderSizePixel = 0 })
	K.corner(5).Parent = bb
	refs.BossFill = K.new("Frame", { Parent = bb, Size = UDim2.fromScale(1, 1), BackgroundColor3 = T.Pink, BorderSizePixel = 0 })
	K.corner(5).Parent = refs.BossFill
	refs.BossName = K.label({ Parent = boss, Position = UDim2.fromOffset(8, 2), Size = UDim2.new(1, -16, 0, 18), Text = "BOSS", TextColor3 = T.Pink })
	refs.BossHP = K.label({ Parent = bb, Size = UDim2.fromScale(1, 1), Text = "", ZIndex = 2 })
end

local function buildButtons(root)
	refs.StartWave = K.button({
		Parent = root, Name = "StartWave", AnchorPoint = V2(1, 1), Size = UDim2.fromOffset(220, 60), Position = UDim2.new(1, -18, 1, -150),
		Text = "▶ START WAVE", BackgroundColor3 = rgb(70, 150, 90), StrokeColor = T.Good, Visible = false,
	}, function()
		ctx.Request("StartWave")
	end)

	local dock = K.new("Frame", { Parent = root, Name = "IconDock", AnchorPoint = V2(1, 0.5), Position = UDim2.new(1, -14, 0.5, -40), Size = UDim2.fromOffset(84, 290), BackgroundTransparency = 1 })
	K.new("UIListLayout", { Parent = dock, Padding = UDim.new(0, 12), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder })
	refs.ShopButton = K.iconButton(dock, 1, "Gem", "МАГАЗИН", rgb(44, 52, 92), rgb(18, 18, 36), rgb(110, 150, 230), function()
		UI.Toggle("Shop")
		ctx.FX.Sound("Click", 1, 1)
	end)
	refs.InvButton = K.iconButton(dock, 2, "Helmet", "ЮНИТЫ", rgb(66, 44, 100), rgb(22, 14, 36), rgb(150, 110, 210), function()
		UI.Toggle("Inventory")
	end)
	refs.LiteButton, refs.LiteCaption = K.iconButton(dock, 3, "Gear", "ГРАФИКА", rgb(56, 54, 72), rgb(22, 20, 30), rgb(120, 116, 140), function()
		ctx.SetLite(not ctx.Lite, true)
	end, 62)
	HUD.SetLiteText(ctx.Lite)

	local leave = K.button({
		Parent = root, Name = "LeaveButton", Size = UDim2.fromOffset(150, 44), Position = UDim2.fromOffset(16, 118),
		Text = "    В ЛОББИ", BackgroundColor3 = rgb(80, 30, 46), StrokeColor = rgb(170, 70, 90), Visible = false,
	}, function()
		ctx.Placement.Stop()
		UI.CloseUnit()
		task.spawn(UI.FadeTransition, "ВОЗВРАЩЕНИЕ В ЛОББИ", function()
			return ctx.Request("LeaveMatch")
		end)
	end)
	K.icon("Back", leave, { Size = UDim2.fromOffset(26, 26), Position = UDim2.fromOffset(12, 9), ZIndex = 2 })
	refs.Leave = leave

	local hint = K.panel({ Parent = root, Name = "PlaceHint", AnchorPoint = V2(0.5, 1), Size = UDim2.fromOffset(520, 34), Position = UDim2.new(0.5, 0, 1, -150), Visible = false })
	K.label({ Parent = hint, Position = UDim2.fromOffset(8, 4), Size = UDim2.new(1, -16, 1, -8), Font = Enum.Font.GothamBold,
		Text = "ЛКМ — поставить  •  R — повернуть  •  Q / ПКМ — отмена  •  Shift — несколько" })
	refs.PlaceHint = hint

	local bar = K.new("Frame", { Parent = root, Name = "TouchBar", AnchorPoint = V2(0.5, 1), Size = UDim2.fromOffset(380, 56), Position = UDim2.new(0.5, 0, 1, -190), BackgroundTransparency = 1, Visible = false })
	K.new("UIListLayout", { Parent = bar, FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder })
	local function tb(order, text, color, fn)
		K.button({ Parent = bar, LayoutOrder = order, Size = UDim2.fromOffset(115, 52), Text = text, BackgroundColor3 = color }, fn)
	end
	tb(1, "PLACE", rgb(60, 140, 80), function()
		ctx.Placement.Confirm()
	end)
	tb(2, "ROTATE", T.BG3, function()
		ctx.Placement.Rotate()
	end)
	tb(3, "CANCEL", rgb(140, 40, 60), function()
		ctx.Placement.Stop()
	end)
	refs.TouchBar = bar

	local toasts = K.new("Frame", { Parent = root, Name = "Toasts", AnchorPoint = V2(0.5, 0), Size = UDim2.fromOffset(400, 300), Position = UDim2.new(0.5, 0, 0, 180), BackgroundTransparency = 1 })
	K.new("UIListLayout", { Parent = toasts, Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder })
	refs.Toasts = toasts
	refs.Announce = K.new("Frame", { Parent = root, Name = "Announce", AnchorPoint = V2(0.5, 0.5), Size = UDim2.fromOffset(700, 130), Position = UDim2.fromScale(0.5, 0.36), BackgroundTransparency = 1, Visible = false })
end

function HUD.Build(ui, c)
	UI, ctx = ui, c
	K, T, Config, refs = ui.Kit, ui.Theme, c.Config, ui.Refs
	buildCurrency(ui.Root)
	buildTop(ui.Root)
	buildButtons(ui.Root)
end

------------------------------------------------------------------------
-- КАДР
------------------------------------------------------------------------
local PHASE_TEXT = { Prep = "Расставь юнитов и начни волну", Victory = "ПОБЕДА!", Defeat = "Ядро разрушено" }

function HUD.Update(dt, inMatch)
	local fmt = Config.FormatNumber
	local prof = ctx.Profile or {}
	-- валюта
	local gy = inMatch and 50 or 8
	refs.Currency.Size = UDim2.fromOffset(230, gy + 84)
	refs.Gems.Position = UDim2.fromOffset(52, gy)
	refs.GemsIcon.Position = UDim2.fromOffset(10, gy - 1)
	refs.Coins.Position = UDim2.fromOffset(52, gy + 44)
	refs.CoinsIcon.Position = UDim2.fromOffset(11, gy + 43)
	refs.Money.Visible = inMatch
	refs.MoneyIcon.Visible = inMatch
	refs.Money.Text = fmt(player:GetAttribute("Money") or 0)
	refs.Gems.Text = fmt(player:GetAttribute("Gems") or prof.Gems or 0)
	refs.Coins.Text = fmt(player:GetAttribute("HalloweenCoins") or prof.HalloweenCoins or 0)

	refs.Top.Visible = inMatch
	refs.Leave.Visible = inMatch
	local State = ctx.State
	local phase = State:GetAttribute("Phase")
	refs.StartWave.Visible = inMatch and (phase == "Prep" or phase == "Intermission") or false
	if not inMatch then
		refs.Boss.Visible = false
		return
	end
	-- волна и статус
	local diffKey = State:GetAttribute("Difficulty")
	local d = diffKey and Config.Difficulties[diffKey]
	refs.Wave.Text = "WAVE " .. tostring(State:GetAttribute("Wave") or 0) .. " / " .. tostring(State:GetAttribute("MaxWave") or 30) .. (d and ("  •  " .. d.Name) or "")
	refs.Wave.TextColor3 = d and d.Color or T.Text
	if phase == "Intermission" then
		local left = math.max(0, math.ceil((State:GetAttribute("NextWaveAt") or 0) - workspace:GetServerTimeNow()))
		refs.Status.Text = "Следующая волна через " .. left .. " c"
		refs.StartWave.Text = "▶ START WAVE (" .. left .. ")"
	elseif phase == "Wave" then
		local n = 0
		for _ in pairs(ctx.Renderer.EnemyViews) do
			n += 1
		end
		refs.Status.Text = "Врагов на поле: " .. n
	elseif PHASE_TEXT[phase] then
		refs.Status.Text = PHASE_TEXT[phase]
	end
	if phase == "Prep" then
		refs.StartWave.Text = "▶ START WAVE"
	end
	-- ядро
	local hp, maxHp = State:GetAttribute("CoreHP") or 100, State:GetAttribute("CoreMaxHP") or 100
	refs.CoreFill.Size = UDim2.fromScale(math.clamp(hp / math.max(maxHp, 1), 0, 1), 1)
	refs.CoreText.Text = (UI.MapMode == "Halloween" and "СВЯТИЛИЩЕ  " or "VOID CORE  ") .. tostring(math.floor(hp + 0.5)) .. " / " .. tostring(math.floor(maxHp + 0.5))
	-- босс
	local bossId = State:GetAttribute("BossId") or 0
	local bv = bossId ~= 0 and ctx.Renderer.EnemyViews[bossId]
	if bv then
		refs.Boss.Visible = true
		refs.BossName.Text = "☠ " .. string.upper(State:GetAttribute("BossName") or "BOSS")
		refs.BossFill.Size = UDim2.fromScale(math.clamp((bv.HP or 0) / math.max(bv.MaxHP or 1, 1), 0, 1), 1)
		refs.BossHP.Text = fmt(bv.HP or 0) .. " / " .. fmt(bv.MaxHP or 0)
	else
		refs.Boss.Visible = false
	end
end

return HUD
