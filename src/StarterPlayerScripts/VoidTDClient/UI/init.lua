--!nocheck
-- VOID TD :: UI (клиент) — оркестратор интерфейса: ScreenGui, масштаб, окна, уведомления, затемнение.
-- Дети: Kit (тема и конструкторы), HUD, Hotbar, UnitPanel, Mode, EndScreen, Shop, Cases, Openings,
-- Inventory, Halloween, Viewer. Каждый: Build(UI, ctx) + своё API; здесь — общий фасад UI.*.
--
-- API (SPEC §4)
--   Init(ctx) SetProfile(p) OnNotify(p) Update(dt) Show(name, on) Toggle(name) SelectCase(id) SetInventoryFilter(ev)
--   UpdateQueue() Fade(text) FadeTransition(text, fn) SetMapMode(key) EquippedAt(i) OpenUnit(uid) CloseUnit()
--   RefreshUnitPanel() UpgradeSelected() SellSelected() CycleTarget() SetLiteText(on) ShowPlacementHint(on, touch)
--   Toast(text, kind) Announce(title, sub, color) ToggleEquip(unitId) RefreshInventory() RefreshMode() SpecialText(def, st)
--   поля: Root Gui Modals Refs Kit Theme SelectedUid MapMode InvFilter; модули: HUD Hotbar ... Viewer

local Players = game:GetService("Players")

local UI = {}
UI.Modals = {}
UI.Refs = {}
UI.MapMode = "Void"
UI.InvFilter = nil
UI.SelectedUid = nil

local function child(name)
	return require(script:WaitForChild(name))
end
local Kit = child("Kit")
local HUD = child("HUD")
local Hotbar = child("Hotbar")
local UnitPanel = child("UnitPanel")
local Mode = child("Mode")
local EndScreen = child("EndScreen")
local Shop = child("Shop")
local Cases = child("Cases")
local Openings = child("Openings")
local Inventory = child("Inventory")
local Halloween = child("Halloween")
local Viewer = child("Viewer")

UI.Kit, UI.Theme = Kit, Kit.Theme
UI.HUD, UI.Hotbar, UI.UnitPanel, UI.Mode, UI.EndScreen, UI.Shop = HUD, Hotbar, UnitPanel, Mode, EndScreen, Shop
UI.Cases, UI.Openings, UI.Inventory, UI.Halloween, UI.Viewer = Cases, Openings, Inventory, Halloween, Viewer

local player = Players.LocalPlayer
local ctx, FX
local fading = false

------------------------------------------------------------------------
-- ФАСАД
------------------------------------------------------------------------
function UI.Toast(text, kind)
	HUD.Toast(text, kind)
end
function UI.Announce(title, sub, color)
	HUD.Announce(title, sub, color)
end
function UI.SetLiteText(on)
	HUD.SetLiteText(on)
end
function UI.ShowPlacementHint(on, touch)
	HUD.ShowPlacementHint(on, touch)
end
function UI.SetMapMode(key)
	HUD.SetMapMode(key)
end
function UI.EquippedAt(i)
	return Hotbar.EquippedAt(i)
end
function UI.OpenUnit(uid)
	UnitPanel.Open(uid)
end
function UI.CloseUnit()
	UnitPanel.Close()
end
function UI.RefreshUnitPanel()
	UnitPanel.Refresh()
end
function UI.UpgradeSelected()
	UnitPanel.Upgrade()
end
function UI.SellSelected()
	UnitPanel.Sell()
end
function UI.CycleTarget()
	UnitPanel.CycleTarget()
end
function UI.SpecialText(def, st)
	return UnitPanel.SpecialText(def, st)
end
function UI.SelectCase(id)
	Cases.Select(id)
end
function UI.SetInventoryFilter(ev)
	Inventory.SetFilter(ev)
end
function UI.RefreshInventory()
	Inventory.Refresh()
end
function UI.ToggleEquip(id)
	Inventory.ToggleEquip(id)
end
function UI.RefreshMode()
	Mode.Refresh()
end
function UI.UpdateQueue()
	Halloween.UpdateQueue()
end
function UI.Icon(kind, parent, props)
	return Kit.icon(kind, parent, props)
end
function UI.Viewport(parent, unitId, level, props)
	return Kit.unitViewport(parent, unitId, level, props)
end

------------------------------------------------------------------------
-- ОКНА (взаимоисключающие)
------------------------------------------------------------------------
local OPEN_HOOK = {
	Inventory = function()
		Inventory.Refresh()
	end,
	Mode = function()
		Mode.Refresh()
	end,
	Bestiary = function()
		Halloween.FillBestiary()
	end,
}

function UI.Toggle(name)
	local m = UI.Modals[name]
	if not m then
		return
	end
	local open = not m.Visible
	for _, o in pairs(UI.Modals) do
		o.Visible = false
	end
	m.Visible = open
	if open then
		local sc = m:FindFirstChildOfClass("UIScale")
		if sc then
			sc.Scale = 0.85
			Kit.tween(sc, 0.2, { Scale = 1 }, Enum.EasingStyle.Back)
		end
		if OPEN_HOOK[name] then
			OPEN_HOOK[name]()
		end
	end
end

function UI.Show(name, on)
	local m = UI.Modals[name]
	if not m then
		return
	end
	if on then
		if not m.Visible then
			UI.Toggle(name)
		end
	else
		m.Visible = false
	end
end

------------------------------------------------------------------------
-- ЗАТЕМНЕНИЕ (телепорты, вход/выход из боя)
------------------------------------------------------------------------
function UI.FadeTransition(text, fn)
	if fading or not UI.Gui then
		if fn then
			return fn()
		end
		return nil
	end
	fading = true
	local f = Kit.new("Frame", { Parent = UI.Gui, Name = "Fade", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 200 })
	local l = Kit.new("TextLabel", {
		Parent = f, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(700, 60), BackgroundTransparency = 1,
		Font = Enum.Font.FredokaOne, TextScaled = true, Text = text or "", TextColor3 = UI.Theme.Accent, TextTransparency = 1, ZIndex = 201,
	})
	Kit.tween(f, 0.35, { BackgroundTransparency = 0 })
	Kit.tween(l, 0.35, { TextTransparency = 0 })
	FX.Sound("Portal", 0.8, 1)
	task.wait(0.4)
	local r = table.pack(pcall(function()
		if fn then
			return fn()
		end
	end))
	task.wait(0.45)
	Kit.tween(f, 0.55, { BackgroundTransparency = 1 })
	Kit.tween(l, 0.4, { TextTransparency = 1 })
	task.delay(0.6, function()
		f:Destroy()
		fading = false
	end)
	if not r[1] then
		warn("[VOID TD] FadeTransition: " .. tostring(r[2]))
		return nil
	end
	return table.unpack(r, 2, r.n)
end

function UI.Fade(text)
	task.spawn(UI.FadeTransition, text)
end

------------------------------------------------------------------------
-- ПРОФИЛЬ И УВЕДОМЛЕНИЯ
------------------------------------------------------------------------
function UI.SetProfile(p)
	ctx.Profile = p
	Hotbar.Refresh()
	Viewer.Refresh()
	if UI.Modals.Inventory and UI.Modals.Inventory.Visible then
		Inventory.Refresh()
	end
	Halloween.OnProfile(p)
end

function UI.OnNotify(p)
	local T, fmt = UI.Theme, ctx.Config.FormatNumber
	local kind = p.Type
	if kind == "Toast" then
		UI.Toast(p.Text, p.Kind)
	elseif kind == "WaveStart" then
		FX.Sound(p.Boss and "Boss" or "WaveStart", 1, 1)
		if p.Boss then
			FX.Shake(0.4, 0.8)
			UI.Announce("WAVE " .. tostring(p.Wave), "⚠ BOSS: " .. tostring(p.Boss), T.Pink)
		else
			UI.Announce("WAVE " .. tostring(p.Wave), nil, T.Text)
		end
	elseif kind == "WaveClear" then
		UI.Toast(string.format("Волна %d пройдена! +$%s  +💎%d", math.floor(p.Wave or 0), fmt(p.Reward or 0), math.floor(p.Gems or 0)), "good")
	elseif kind == "BossDown" then
		FX.Shake(0.6, 0.6)
	elseif kind == "CoreHit" then
		if player:GetAttribute("InMatch") then
			FX.Shake(0.35, 0.3)
			FX.Sound("CoreHit", 1, 1)
			HUD.CoreHit()
		end
	elseif kind == "Victory" or kind == "Defeat" then
		FX.Sound(kind, 1, 1)
		EndScreen.Show(kind == "Victory", p)
	elseif kind == "Fade" then
		UI.Fade(p.Text or "")
	elseif kind == "Purchase" then
		FX.Sound("Purchase", 1, 1)
		UI.Toast("Покупка: +" .. tostring(p.Gems) .. " 💎", "gold")
	elseif kind == "Reset" then
		EndScreen.Clear()
		UI.CloseUnit()
		if player:GetAttribute("Island") then
			UI.Toast("Бой окончен. Ты на Хэллоуин-острове", "good")
		else
			UI.Toast("Бой окончен. Ты в лобби — встань в круг ИГРАТЬ", "good")
		end
	end
end

------------------------------------------------------------------------
-- КАДР
------------------------------------------------------------------------
function UI.Update(dt)
	if not ctx then
		return
	end
	local inMatch = player:GetAttribute("InMatch") == true
	local t = os.clock()
	HUD.Update(dt, inMatch)
	Hotbar.Update(inMatch)
	UnitPanel.Update(dt, inMatch)
	Mode.Update()
	Cases.Update(t)
	Shop.Update()
	Kit.StepSparks(t)
end

------------------------------------------------------------------------
-- ЗАПУСК
------------------------------------------------------------------------
function UI.Init(c)
	ctx = c
	FX = c.FX
	local pg = player:WaitForChild("PlayerGui")
	local old = pg:FindFirstChild("VoidTD_UI")
	if old then
		old:Destroy()
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "VoidTD_UI"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	local root = Instance.new("Frame")
	root.Name = "Root"
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromScale(1, 1)
	root.Parent = gui
	local scale = Instance.new("UIScale")
	scale.Name = "Scale"
	scale.Parent = root
	UI.Gui, UI.Root = gui, root
	Kit.Build(UI, c)
	Kit.SetRoot(root)
	for _, m in ipairs({ HUD, Hotbar, UnitPanel, Cases, Shop, Inventory, Mode, EndScreen, Openings, Halloween, Viewer }) do
		m.Build(UI, c)
	end
	-- масштаб под экран (корень растягивается обратно, чтобы закрывать весь экран)
	local function fit()
		local cam = workspace.CurrentCamera
		local vs = cam and cam.ViewportSize or Vector2.new(1280, 760)
		local s = math.clamp(math.min(vs.X / 1280, vs.Y / 760), 0.55, 1.15)
		scale.Scale = s
		root.Size = UDim2.fromScale(1 / s, 1 / s)
	end
	fit()
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	end
	c.Renderer.OnUnitRemoved = function(uid)
		if UI.SelectedUid == uid then
			UI.CloseUnit()
		end
	end
	gui.Parent = pg
	return UI
end

return UI
