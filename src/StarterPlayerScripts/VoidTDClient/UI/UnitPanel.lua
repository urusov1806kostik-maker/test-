--!nocheck
-- VOID TD :: UI.UnitPanel — панель выбранного юнита на карте: характеристики, цель, улучшение, продажа,
-- круг дальности.
--
-- API
--   UnitPanel.Build(UI, ctx) ; Open(uid) ; Close() ; Refresh() ; Update(dt, inMatch)
--   UnitPanel.Upgrade() ; Sell() ; CycleTarget() ; UnitPanel.SpecialText(def, st) -> string

local Players = game:GetService("Players")

local UnitPanel = {}

local player = Players.LocalPlayer
local rgb = Color3.fromRGB
local V2 = Vector2.new
local V3 = Vector3.new

local UI, ctx, K, T, Config, refs
local panel, rangePart
local acc = 0
local viewKey

-- целое для %d (Luau падает на дробных)
local function int(n)
	return math.floor((n or 0) + 0.5)
end

function UnitPanel.SpecialText(def, st)
	if st.BlackHole then
		return string.format("Black Hole r%d, %d/тик", int(st.BlackHole.Radius), int(st.BlackHole.TickDamage))
	elseif st.AOERadius then
		return string.format("AOE радиус %.1f", st.AOERadius)
	elseif st.Hits and st.Hits > 1 then
		local s = "x" .. st.Hits .. " удара"
		if st.CritChance then
			s = s .. string.format(", крит %d%%", int(st.CritChance * 100))
		end
		return s
	elseif st.CritChance then
		return string.format("Крит %d%% x%.1f", int(st.CritChance * 100), st.CritMult or 2)
	end
	return tostring(def.AttackType or "")
end

local function view()
	return UI.SelectedUid and ctx.Renderer.UnitViews[UI.SelectedUid]
end

local function arrow(a, b)
	if b ~= nil and b ~= a then
		return a .. "  →  " .. b
	end
	return a
end

function UnitPanel.Build(ui, c)
	UI, ctx = ui, c
	K, T, Config, refs = ui.Kit, ui.Theme, c.Config, ui.Refs
	panel = K.panel({ Parent = ui.Root, Name = "UnitPanel", AnchorPoint = V2(1, 0.5), Size = UDim2.fromOffset(310, 470), Position = UDim2.new(1, -112, 0.45, 0), Visible = false })
	refs.UnitPanel = panel
	refs.UPName = K.label({ Parent = panel, Position = UDim2.fromOffset(12, 10), Size = UDim2.new(1, -60, 0, 32), Text = "", TextXAlignment = Enum.TextXAlignment.Left })
	K.button({ Parent = panel, Size = UDim2.fromOffset(32, 32), Position = UDim2.new(1, -42, 0, 10), Text = "✕", BackgroundColor3 = rgb(120, 30, 50) }, function()
		UnitPanel.Close()
	end)
	refs.UPRarity = K.label({ Parent = panel, Position = UDim2.fromOffset(12, 42), Size = UDim2.new(1, -24, 0, 20), Text = "", TextXAlignment = Enum.TextXAlignment.Left })
	refs.UPStars = K.label({ Parent = panel, Position = UDim2.fromOffset(12, 62), Size = UDim2.new(1, -24, 0, 24), Text = "", TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = T.Gold })
	local vf = K.new("Frame", { Parent = panel, Position = UDim2.fromOffset(12, 90), Size = UDim2.new(1, -24, 0, 110), BackgroundColor3 = T.BG2, BackgroundTransparency = 0.3, BorderSizePixel = 0 })
	K.corner(8).Parent = vf
	refs.UPView = vf
	local stats = K.new("Frame", { Parent = panel, Position = UDim2.fromOffset(12, 206), Size = UDim2.new(1, -24, 0, 160), BackgroundTransparency = 1 })
	K.new("UIListLayout", { Parent = stats, Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder })
	refs.UPStats = {}
	for i, name in ipairs({ "Урон", "Дальность", "Перезарядка", "Особое", "Нанесено", "Владелец" }) do
		local row = K.new("Frame", { Parent = stats, LayoutOrder = i, Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1 })
		K.label({ Parent = row, Size = UDim2.fromScale(0.45, 1), Text = name, TextColor3 = T.Dim, TextXAlignment = Enum.TextXAlignment.Left })
		refs.UPStats[name] = K.label({ Parent = row, Position = UDim2.fromScale(0.45, 0), Size = UDim2.fromScale(0.55, 1), Text = "", Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Right })
	end
	refs.UPTarget = K.button({ Parent = panel, Position = UDim2.fromOffset(12, 362), Size = UDim2.new(1, -24, 0, 36), Text = "TARGET: First" }, function()
		UnitPanel.CycleTarget()
	end)
	refs.UPUpgrade = K.button({ Parent = panel, Position = UDim2.fromOffset(12, 406), Size = UDim2.new(0.6, -16, 0, 50), Text = "UPGRADE", BackgroundColor3 = rgb(60, 130, 80), StrokeColor = T.Good }, function()
		UnitPanel.Upgrade()
	end)
	refs.UPSell = K.button({ Parent = panel, Position = UDim2.new(0.6, 4, 0, 406), Size = UDim2.new(0.4, -12, 0, 50), Text = "SELL", BackgroundColor3 = rgb(130, 40, 60), StrokeColor = T.Bad }, function()
		UnitPanel.Sell()
	end)
end

local function hideRange()
	if rangePart then
		rangePart.Parent = nil
	end
end

function UnitPanel.Refresh()
	local v = view()
	if not v or not v.Folder then
		return
	end
	local def = Config.Units[v.UnitId]
	if not def then
		return
	end
	local f = v.Folder
	local lv = f:GetAttribute("Level") or 1
	local st = def.Levels[lv] or def.Levels[1]
	local nx = def.Levels[lv + 1]
	local col = K.rarityColor(v.UnitId)
	local fmt = Config.FormatNumber
	panel.Border.Color = col
	refs.UPName.Text = def.Name
	refs.UPRarity.Text = string.upper(def.Rarity) .. (def.Ability and ("  •  " .. def.Ability) or "")
	refs.UPRarity.TextColor3 = col
	refs.UPStars.Text = "Lv " .. lv .. "  " .. string.rep("★", lv) .. string.rep("☆", math.max(0, 5 - lv))
	-- 3D только при смене уровня/юнита
	local key = tostring(UI.SelectedUid) .. ":" .. lv
	if viewKey ~= key then
		viewKey = key
		refs.UPView:ClearAllChildren()
		K.corner(8).Parent = refs.UPView
		K.unitViewport(refs.UPView, v.UnitId, lv)
	end
	local S = refs.UPStats
	S["Урон"].Text = arrow(fmt(st.Damage), nx and fmt(nx.Damage))
	S["Дальность"].Text = arrow(tostring(st.Range), nx and tostring(nx.Range))
	S["Перезарядка"].Text = arrow(string.format("%.2fs", st.Cooldown), nx and string.format("%.2fs", nx.Cooldown))
	S["Особое"].Text = UnitPanel.SpecialText(def, st)
	S["Нанесено"].Text = fmt(f:GetAttribute("Damage") or 0)
	S["Владелец"].Text = tostring(f:GetAttribute("OwnerName") or "?")
	local mine = f:GetAttribute("OwnerId") == player.UserId
	refs.UPTarget.Visible = mine
	refs.UPUpgrade.Visible = mine
	refs.UPSell.Visible = mine
	refs.UPTarget.Text = "🎯 TARGET: " .. tostring(f:GetAttribute("TargetMode") or "First")
	if nx then
		refs.UPUpgrade.Text = "UPGRADE $" .. fmt(nx.Cost)
		refs.UPUpgrade.BackgroundColor3 = (player:GetAttribute("Money") or 0) >= nx.Cost and rgb(60, 130, 80) or rgb(60, 60, 70)
	else
		refs.UPUpgrade.Text = "MAX LEVEL"
		refs.UPUpgrade.BackgroundColor3 = rgb(120, 90, 30)
	end
	refs.UPSell.Text = "SELL $" .. fmt(math.floor((f:GetAttribute("Spent") or 0) * Config.Settings.SellRefund))
	-- круг дальности
	if not rangePart then
		rangePart = ctx.FX.Part({ Name = "VoidTD_Range", Shape = Enum.PartType.Cylinder, Color = T.Accent, Transparency = 0.75, Parent = nil })
	end
	local r = st.Range or 10
	rangePart.Size = V3(0.2, r * 2, r * 2)
	rangePart.CFrame = CFrame.new(v.Pos + V3(0, 0.25, 0)) * CFrame.Angles(0, 0, math.rad(90))
	rangePart.Parent = workspace
end

function UnitPanel.Open(uid)
	UI.SelectedUid = uid
	panel.Visible = true
	viewKey = nil
	acc = 0
	UnitPanel.Refresh()
end

function UnitPanel.Close()
	UI.SelectedUid = nil
	panel.Visible = false
	viewKey = nil
	hideRange()
end

function UnitPanel.Upgrade()
	local uid = UI.SelectedUid
	if not uid then
		return
	end
	local ok, res = ctx.Request("Upgrade", { Uid = uid })
	if ok then
		UI.Toast("Улучшено до уровня " .. tostring(res) .. "!", "good")
		UnitPanel.Refresh()
	end
end

function UnitPanel.Sell()
	local uid = UI.SelectedUid
	if not uid then
		return
	end
	local ok, res = ctx.Request("Sell", { Uid = uid })
	if ok then
		UI.Toast("Продано за $" .. Config.FormatNumber(res or 0), "gold")
		ctx.FX.Sound("Sell", 1, 1)
		UnitPanel.Close()
	end
end

function UnitPanel.CycleTarget()
	local v = view()
	if not v or not refs.UPTarget.Visible then
		return
	end
	local modes = Config.TargetModes
	local cur = v.Folder:GetAttribute("TargetMode") or "First"
	local i = table.find(modes, cur) or 0
	local nextMode = modes[i % #modes + 1]
	local ok = ctx.Request("SetTarget", { Uid = UI.SelectedUid, Mode = nextMode })
	if ok then
		refs.UPTarget.Text = "🎯 TARGET: " .. nextMode
	end
end

function UnitPanel.Update(dt, inMatch)
	if not UI.SelectedUid then
		return
	end
	if not inMatch or not view() then
		UnitPanel.Close()
		return
	end
	acc += dt
	if acc >= 0.25 then
		acc = 0
		UnitPanel.Refresh()
	end
end

return UnitPanel
