--!nocheck
-- VOID TD :: UI.Halloween — окно рун («РУНЫ»), панель очереди 4 квадратов (HALLOWEEN TD), бестиарий острова.
--
-- API
--   Halloween.Build(UI, ctx)
--   Halloween.OpenRunePicker(unitId) ; Halloween.OnProfile(p) ; Halloween.UpdateQueue() ; Halloween.FillBestiary()
--   Halloween.RuneCard(grid, r, i)   -- карточка руны в результатах (из Openings)

local Players = game:GetService("Players")

local Halloween = {}

local player = Players.LocalPlayer
local rgb = Color3.fromRGB
local V2 = Vector2.new
local BLACK = Color3.new(0, 0, 0)
local ORANGE = rgb(255, 130, 30)
local GOLD = rgb(255, 205, 80)
local BOSS_OF = { GraveWarden = "Easy", FogReaper = "Medium", CursedMonarch = "Hard" }

local UI, ctx, K, T, Config, refs
local runeModal, pickerUnit
local queue, diffButtons = nil, {}
local bestiary, bestiaryBuilt = nil, false

function Halloween.RuneCard(grid, r, i)
	return UI.Openings.RuneCard(grid, r, i)
end

------------------------------------------------------------------------
-- РУНЫ
------------------------------------------------------------------------
local function refreshPicker()
	if not runeModal or not pickerUnit then
		return
	end
	local p = ctx.Profile or {}
	local runes, slots = p.Runes or {}, p.RuneSlots or {}
	local def = Config.Units[pickerUnit]
	refs.RuneFor.Text = "Юнит: " .. (def and def.Name or tostring(pickerUnit)) .. "  •  1 руна на юнита. Руна работает, только когда надета."
	refs.RuneRemove.Visible = slots[pickerUnit] ~= nil
	local row = refs.RuneRow
	for _, ch in ipairs(row:GetChildren()) do
		if ch:IsA("GuiObject") then
			ch:Destroy()
		end
	end
	for i, id in ipairs(Config.RuneOrder) do
		local rd = Config.Runes[id]
		local have = runes[id] or 0
		local used = 0
		for _, rid in pairs(slots) do
			if rid == id then
				used += 1
			end
		end
		local on = slots[pickerUnit] == id
		local card = K.panel({ Parent = row, LayoutOrder = i, Size = UDim2.fromOffset(210, 266), BackgroundColor3 = T.BG2, StrokeColor = on and GOLD or (have > 0 and rd.Color or rgb(60, 50, 60)), ZIndex = 7 })
		K.runeViewport(card, id, { Size = UDim2.new(1, 0, 0, 96), ZIndex = 8 })
		K.label({ Parent = card, Position = UDim2.fromOffset(6, 96), Size = UDim2.new(1, -12, 0, 22), Text = rd.Name, TextColor3 = rd.Color, ZIndex = 8 })
		K.label({ Parent = card, Position = UDim2.fromOffset(6, 118), Size = UDim2.new(1, -12, 0, 16), Text = string.format("есть: %d  •  надето: %d", have, used), TextColor3 = T.Dim, Font = Enum.Font.GothamBold, ZIndex = 8 })
		K.label({
			Parent = card, Position = UDim2.fromOffset(6, 136), Size = UDim2.new(1, -12, 0, 76), Text = rd.Description or "", ZIndex = 8,
			TextScaled = false, TextSize = 12, TextWrapped = true, Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
		})
		local free = have - used + (on and 1 or 0)
		local text, bg = "ЗАНЯТА", rgb(60, 50, 60)
		if on then
			text, bg = "НАДЕТА", rgb(90, 70, 20)
		elseif have == 0 then
			text, bg = "НЕТ РУНЫ", T.BG3
		elseif free > 0 then
			text, bg = "НАДЕТЬ", rgb(60, 110, 60)
		end
		K.button({ Parent = card, AnchorPoint = V2(0.5, 1), Position = UDim2.new(0.5, 0, 1, -8), Size = UDim2.new(1, -16, 0, 38), Text = text, BackgroundColor3 = bg, ZIndex = 8 }, function()
			if on or have == 0 or free <= 0 then
				return -- свободных рун нет (сервер всё равно проверяет)
			end
			ctx.Request("EquipRune", { Unit = pickerUnit, Rune = id })
		end)
	end
end

function Halloween.OpenRunePicker(unitId)
	pickerUnit = unitId
	UI.Show("Runes", true)
	refreshPicker()
end

function Halloween.OnProfile()
	if runeModal and runeModal.Visible then
		refreshPicker()
	end
end

local function buildRunes()
	runeModal = K.modal("Runes", "РУНЫ", UDim2.fromOffset(720, 420), "Rune")
	refs.RuneFor = K.label({ Parent = runeModal, Position = UDim2.fromOffset(18, 58), Size = UDim2.new(1, -36, 0, 24), Text = "", TextColor3 = T.Dim, Font = Enum.Font.GothamBold, ZIndex = 6 })
	local row = K.new("Frame", { Parent = runeModal, Position = UDim2.fromOffset(18, 88), Size = UDim2.new(1, -36, 0, 270), BackgroundTransparency = 1 })
	K.new("UIListLayout", { Parent = row, FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 12), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder })
	refs.RuneRow = row
	refs.RuneRemove = K.button({
		Parent = runeModal, AnchorPoint = V2(0.5, 1), Position = UDim2.new(0.5, 0, 1, -12), Size = UDim2.fromOffset(260, 44), ZIndex = 6, Visible = false,
		Text = "СНЯТЬ РУНУ", BackgroundColor3 = rgb(110, 40, 50),
	}, function()
		if pickerUnit then
			ctx.Request("EquipRune", { Unit = pickerUnit })
		end
	end)
end

------------------------------------------------------------------------
-- ОЧЕРЕДЬ (4 квадрата)
------------------------------------------------------------------------
local function buildQueue()
	queue = K.panel({ Parent = UI.Root, Name = "HalloweenQueue", AnchorPoint = V2(1, 0.5), Position = UDim2.new(1, -110, 0.5, 0), Size = UDim2.fromOffset(330, 330), StrokeColor = ORANGE, ZIndex = 4, Visible = false })
	K.label({ Parent = queue, Position = UDim2.fromOffset(10, 8), Size = UDim2.new(1, -20, 0, 32), Text = "🎃 HALLOWEEN TD", TextColor3 = ORANGE, ZIndex = 5 })
	refs.QMembers = K.label({
		Parent = queue, Position = UDim2.fromOffset(10, 44), Size = UDim2.new(1, -20, 0, 92), Text = "", ZIndex = 5,
		TextScaled = false, TextSize = 17, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
	})
	refs.QHost = K.label({ Parent = queue, Position = UDim2.fromOffset(10, 140), Size = UDim2.new(1, -20, 0, 18), Text = "", TextColor3 = T.Dim, ZIndex = 5 })
	local row = K.new("Frame", { Parent = queue, Position = UDim2.fromOffset(10, 164), Size = UDim2.new(1, -20, 0, 44), BackgroundTransparency = 1 })
	K.new("UIListLayout", { Parent = row, FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder })
	for i, key in ipairs(Config.Halloween.Difficulties) do
		local d = Config.Difficulties[key]
		diffButtons[key] = K.button({
			Parent = row, LayoutOrder = i, Size = UDim2.fromOffset(98, 44), ZIndex = 5, BackgroundColor3 = T.BG2, StrokeColor = d.Color, TextColor3 = d.Color,
			Text = d.Name .. "\n" .. tostring(Config.Halloween.Coins[key] or 0) .. "🎃",
		}, function()
			if queue:GetAttribute("IsHost") then
				ctx.Request("QueueDifficulty", { Difficulty = key })
			end
		end)
	end
	refs.QTimer = K.label({ Parent = queue, Position = UDim2.fromOffset(10, 214), Size = UDim2.new(1, -20, 0, 30), Text = "", TextColor3 = GOLD, ZIndex = 5 })
	refs.QStart = K.button({ Parent = queue, Position = UDim2.new(0, 10, 1, -54), Size = UDim2.new(0.5, -14, 0, 44), ZIndex = 5, Text = "СТАРТ", BackgroundColor3 = rgb(140, 70, 20), StrokeColor = ORANGE }, function()
		ctx.Request("QueueStart")
	end)
	K.button({ Parent = queue, Position = UDim2.new(0.5, 4, 1, -54), Size = UDim2.new(0.5, -14, 0, 44), ZIndex = 5, Text = "ВЫЙТИ", BackgroundColor3 = rgb(110, 30, 40), StrokeColor = T.Bad }, function()
		ctx.Request("QueueLeave")
	end)
	refs.Queue = queue
end

function Halloween.UpdateQueue()
	if not queue then
		return
	end
	local S = ctx.State
	local raw = S:GetAttribute("HQ_Members") or ""
	local members = {}
	for name in string.gmatch(raw, "[^\n]+") do
		members[#members + 1] = name
	end
	local me = table.find(members, player.DisplayName) ~= nil
	queue.Visible = me and not player:GetAttribute("InMatch")
	if not queue.Visible then
		return
	end
	local lines = {}
	for i = 1, Config.HalloweenIsland.Queue.MaxPlayers do
		lines[i] = (i == 1 and "👑 " or "• ") .. (members[i] or "свободно")
	end
	refs.QMembers.Text = table.concat(lines, "\n")
	local isHost = S:GetAttribute("HQ_Host") == player.UserId
	queue:SetAttribute("IsHost", isHost)
	refs.QHost.Text = isHost and "Ты хост: выбери сложность" or "Сложность выбирает хост"
	refs.QStart.Visible = isHost
	local sel = S:GetAttribute("HQ_Diff") or "Easy"
	for key, b in pairs(diffButtons) do
		local d = Config.Difficulties[key]
		b.BackgroundColor3 = key == sel and d.Color:Lerp(BLACK, 0.4) or T.BG2
		b.Active = isHost
		b.AutoButtonColor = false
	end
	local at = S:GetAttribute("HQ_At") or 0
	if S:GetAttribute("HQ_Busy") then
		refs.QTimer.Text = "Арена занята — ждём конца матча"
	elseif at > 0 then
		refs.QTimer.Text = "Телепорт через " .. math.max(0, math.ceil(at - workspace:GetServerTimeNow())) .. " c"
	else
		refs.QTimer.Text = ""
	end
end

------------------------------------------------------------------------
-- БЕСТИАРИЙ
------------------------------------------------------------------------
function Halloween.FillBestiary()
	if bestiaryBuilt or not bestiary then
		return
	end
	bestiaryBuilt = true
	local grid = refs.BestiaryGrid
	local n = 0
	for _, id in ipairs(Config.EnemyOrder) do
		local e = Config.Enemies[id]
		if e and e.Event == "Halloween" then
			n += 1
			local diff = BOSS_OF[id] and Config.Difficulties[BOSS_OF[id]]
			local col = diff and diff.Color or (e.MiniBoss and rgb(200, 90, 255) or ORANGE)
			local tag = diff and ("ФИНАЛЬНЫЙ БОСС • " .. diff.Name) or (e.MiniBoss and "МИНИ-БОСС" or "ВРАГ")
			local card = K.panel({ Parent = grid, LayoutOrder = n, BackgroundColor3 = T.BG2, StrokeColor = col, ZIndex = 7 })
			K.enemyViewport(card, id, { Size = UDim2.new(1, 0, 0, 110), ZIndex = 8 })
			K.label({ Parent = card, Position = UDim2.fromOffset(5, 110), Size = UDim2.new(1, -10, 0, 22), Text = e.Name or id, TextColor3 = col, ZIndex = 8 })
			K.label({
				Parent = card, Position = UDim2.fromOffset(5, 134), Size = UDim2.new(1, -10, 0, 16), ZIndex = 8, Font = Enum.Font.GothamBold, TextColor3 = T.Dim,
				Text = string.format("%s  •  HP %d  •  скор. %g", tag, math.floor((e.Health or 0) + 0.5), e.Speed or 0),
			})
			K.label({
				Parent = card, Position = UDim2.fromOffset(5, 152), Size = UDim2.new(1, -10, 0, 78), Text = e.Description or "", ZIndex = 8,
				TextScaled = false, TextSize = 12, TextWrapped = true, Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
			})
		end
	end
end

local function buildBestiary()
	bestiary = K.modal("Bestiary", "БЕСТИАРИЙ • HAUNTED HOLLOW", UDim2.fromOffset(940, 580), "Pumpkin")
	local grid = K.new("ScrollingFrame", {
		Parent = bestiary, Position = UDim2.fromOffset(18, 66), Size = UDim2.new(1, -36, 1, -80), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), ScrollBarThickness = 6,
	})
	K.new("UIGridLayout", { Parent = grid, CellSize = UDim2.fromOffset(212, 236), CellPadding = UDim2.fromOffset(10, 10), SortOrder = Enum.SortOrder.LayoutOrder })
	refs.BestiaryGrid = grid
end

function Halloween.Build(ui, c)
	UI, ctx = ui, c
	K, T, Config, refs = ui.Kit, ui.Theme, c.Config, ui.Refs
	buildRunes()
	buildQueue()
	buildBestiary()
end

return Halloween
