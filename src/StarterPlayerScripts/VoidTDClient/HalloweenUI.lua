--!nocheck
-- VOID TD :: HalloweenUI (клиент)
-- Интерфейс события: открытие проклятого сундука, руны (3D-иконки, выбор, надеть/снять),
-- панель очереди на 4 квадратах, бестиарий врагов и боссов.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local HalloweenUI = {}

local ctx, UI, Config, UnitModels, EnemyModels, CaseModels, FX
local K -- конструкторы UI (UI.Kit)
local player = Players.LocalPlayer
local refs = {}

local ORANGE = Color3.fromRGB(255, 130, 30)
local GOLD = Color3.fromRGB(255, 205, 80)
local DARK = Color3.fromRGB(26, 12, 16)

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

------------------------------------------------------------------------
-- 3D-ИКОНКА РУНЫ
------------------------------------------------------------------------
function HalloweenUI.RuneViewport(parent, runeId, props)
	props = props or {}
	local vf = K.new("ViewportFrame", {
		Parent = parent,
		BackgroundTransparency = 1,
		Size = props.Size or UDim2.fromScale(1, 1),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.new(),
		Ambient = rgb(170, 140, 130),
		LightColor = rgb(255, 240, 220),
		LightDirection = Vector3.new(-0.5, -1, -0.7),
		ZIndex = props.ZIndex or 1,
	})
	if not UnitModels.BuildRune then
		return vf
	end
	local ok, r = pcall(UnitModels.BuildRune, runeId)
	if not ok or not r then
		return vf
	end
	r.Model.Parent = vf
	local cam = Instance.new("Camera")
	cam.FieldOfView = 30
	cam.CFrame = CFrame.lookAt(Vector3.new(2.2, 1.4, -6.5), Vector3.new(0, 0, 0))
	cam.Parent = vf
	vf.CurrentCamera = cam
	vf:SetAttribute("Spin", true)
	refs.RuneSpins = refs.RuneSpins or {}
	table.insert(refs.RuneSpins, { Model = r.Model, VF = vf })
	return vf, r
end

-- карточка руны в итогах открытия
function HalloweenUI.RuneCard(grid, r, i)
	local rd = Config.Runes[r.Rune]
	local col = Config.RuneRarity.Color
	local card = K.panel({ Parent = grid, BackgroundColor3 = UI.Theme.BG2, StrokeColor = col, LayoutOrder = i, ZIndex = 23 })
	K.new("UIGradient", { Parent = card, Rotation = 90, Color = ColorSequence.new(col:Lerp(UI.Theme.BG, 0.55), UI.Theme.BG) })
	HalloweenUI.RuneViewport(card, r.Rune, { Size = UDim2.new(1, 0, 0, 120), Position = UDim2.fromOffset(0, 8), ZIndex = 24 })
	K.label({ Parent = card, Size = UDim2.new(1, -8, 0, 22), Position = UDim2.fromOffset(4, 130), Text = rd.Name, ZIndex = 24 })
	K.label({ Parent = card, Size = UDim2.new(1, -8, 0, 18), Position = UDim2.fromOffset(4, 154), Text = "РУНА • " .. Config.RuneRarity.Name, TextColor3 = col, ZIndex = 24 })
	local sc = K.new("UIScale", { Parent = card, Scale = 0 })
	K.tween(sc, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
end

------------------------------------------------------------------------
-- ОТКРЫТИЕ ПРОКЛЯТОГО СУНДУКА
------------------------------------------------------------------------
-- Камера приближается, сундук трясётся, глаза и огонь разгораются, цепи рвутся, крышка открывается,
-- из сундука поднимается награда (3D-модель юнита или 3D-руна), затем имя и редкость. SECRET — отдельная сцена.
function HalloweenUI.PlayOpening(results, showCards)
	local r0 = results[1]
	local isRune = r0.Rune ~= nil
	local def = r0.Id and Config.Units[r0.Id]
	local rarity = def and def.Rarity or "Rune"
	local color = isRune and Config.RuneRarity.Color or Config.Rarities[rarity].Color
	local secret = rarity == "Secret"
	local gui = UI.Root
	local overlay = K.new("Frame", { Parent = gui, Size = UDim2.fromScale(1, 1), BackgroundColor3 = rgb(8, 2, 4), BackgroundTransparency = 0.1, ZIndex = 20 })
	local vf = K.new("ViewportFrame", { Parent = overlay, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(620, 620), Position = UDim2.fromScale(0.5, 0.52), Ambient = rgb(120, 80, 70), LightColor = rgb(255, 210, 160), LightDirection = Vector3.new(-0.4, -1, -0.8), ZIndex = 21 })
	local chest = CaseModels.Build("Halloween")
	chest.Model.Parent = vf
	local cam = Instance.new("Camera")
	cam.FieldOfView = 40
	cam.Parent = vf
	vf.CurrentCamera = cam
	local title = K.label({ Parent = overlay, AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.fromOffset(700, 56), Position = UDim2.new(0.5, 0, 0.05, 0), Text = "HALLOWEEN CASE", TextColor3 = ORANGE, ZIndex = 22, StrokeThickness = 3 })
	local glow = K.new("Frame", { Parent = overlay, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.55), Size = UDim2.fromOffset(10, 10), BackgroundColor3 = ORANGE, BackgroundTransparency = 1, ZIndex = 20 })
	K.corner(300).Parent = glow

	local base = chest.Base
	local lid = {}
	for _, p in ipairs(chest.LidParts or { chest.Lid }) do
		lid[p] = true
	end
	local chains = {}
	for _, p in ipairs(chest.Chains or {}) do
		chains[p] = Vector3.new(math.random() - 0.5, math.random() * 0.8 + 0.2, math.random() - 0.5).Unit
	end
	local hinge = chest.Hinge or CFrame.new(0, 2.7, 1.4)
	local eyes = chest.Eyes or {}
	local eyeColor = {}
	for _, e in ipairs(eyes) do
		eyeColor[e] = e.Color
	end

	local SHAKE, BREAK, OPEN, RISE = 1.6, 0.5, 0.7, 0.9
	local start = os.clock()
	local nextTick = 0
	local reward, rewardBase
	local done = false
	local conn
	FX.Sound("CaseShake", 1, 0.6)
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - start
		-- камера плавно приближается
		local k = math.clamp(t / (SHAKE + BREAK), 0, 1)
		local dist = 15 - k * 4.5
		cam.CFrame = CFrame.lookAt(Vector3.new(0, 4.5 - k * 0.6, -dist), Vector3.new(0, 2.4, 0))
		if t < SHAKE then
			local a = t / SHAKE
			local shake = CFrame.new((math.random() - 0.5) * a * 0.35, 0, (math.random() - 0.5) * a * 0.35) * CFrame.Angles(0, 0, (math.random() - 0.5) * a * 0.12)
			for p, b in pairs(base) do
				p.CFrame = shake * b
			end
			for _, e in ipairs(eyes) do
				e.Color = eyeColor[e]:Lerp(rgb(255, 240, 180), a)
			end
			glow.Size = UDim2.fromOffset(60 + a * 300, 60 + a * 300)
			glow.BackgroundTransparency = 1 - a * 0.25
			if t >= nextTick then
				nextTick = t + 0.42 - a * 0.28
				FX.Sound("CaseShake", 1, 0.6 + a * 0.6)
			end
		elseif t < SHAKE + BREAK then
			-- цепи рвутся и разлетаются
			local a = (t - SHAKE) / BREAK
			if not chest.Broke then
				chest.Broke = true
				FX.Sound("CaseOpen", 1, 0.7)
				local flash = K.new("Frame", { Parent = overlay, Size = UDim2.fromScale(1, 1), BackgroundColor3 = ORANGE, BackgroundTransparency = 0.3, ZIndex = 30 })
				K.tween(flash, 0.5, { BackgroundTransparency = 1 })
				task.delay(0.55, function()
					flash:Destroy()
				end)
			end
			for p, b in pairs(base) do
				if chains[p] then
					local d = chains[p]
					p.CFrame = CFrame.new(d * a * 9 + Vector3.new(0, -a * a * 3, 0)) * b * CFrame.Angles(a * 5 * d.X, a * 4, a * 5 * d.Z)
					p.Transparency = math.min(1, a * 1.2)
				elseif not lid[p] then
					p.CFrame = b
				end
			end
		elseif t < SHAKE + BREAK + OPEN then
			-- крышка открывается на петле
			local a = (t - SHAKE - BREAK) / OPEN
			local ang = math.rad(110) * (1 - (1 - a) ^ 3)
			for p in pairs(lid) do
				if base[p] then
					p.CFrame = hinge * CFrame.Angles(ang, 0, 0) * hinge:Inverse() * base[p]
				end
			end
			glow.BackgroundColor3 = color
			glow.Size = UDim2.fromOffset(360 + a * 200, 360 + a * 200)
		elseif t < SHAKE + BREAK + OPEN + RISE then
			-- награда поднимается из сундука
			local a = (t - SHAKE - BREAK - OPEN) / RISE
			if not reward then
				FX.Sound("Reveal", 1, isRune and 1.2 or 0.7 + (Config.Rarities[rarity] and Config.Rarities[rarity].Order or 3) * 0.12)
				if isRune and UnitModels.BuildRune then
					local ok, rr = pcall(UnitModels.BuildRune, r0.Rune)
					if ok and rr then
						reward = rr.Model
						reward:ScaleTo(1.2)
					end
				elseif def then
					local ok, rig = pcall(UnitModels.Build, r0.Id, 1)
					if ok and rig then
						reward = rig.Model
						for _, d in ipairs(reward:GetDescendants()) do
							if d:IsA("ParticleEmitter") or d:IsA("Trail") then
								d:Destroy()
							end
						end
						rewardBase = rig.HipHeight
					end
				end
				if reward then
					reward.Parent = vf
				end
			end
			if reward then
				local y = 1.5 + a * (isRune and 3.8 or 2.2) + (rewardBase or 0) * a
				reward:PivotTo(CFrame.new(0, y, -0.6) * CFrame.Angles(0, math.pi + a * math.pi * 2, 0))
			end
		elseif not done then
			done = true
			conn:Disconnect()
			local function finish()
				title.Text = isRune and ("РУНА «" .. Config.Runes[r0.Rune].Name .. "»") or def.Name
				title.TextColor3 = color
				K.label({ Parent = overlay, AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.fromOffset(600, 34), Position = UDim2.new(0.5, 0, 0.05, 60), Text = isRune and ("РУНА • " .. Config.RuneRarity.Name) or (rarity:upper() .. "  •  " .. Config.Events.Halloween.Tag), TextColor3 = isRune and color or ORANGE, ZIndex = 22 })
				if r0.New then
					local tag = K.label({ Parent = overlay, AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.fromOffset(160, 34), Position = UDim2.new(0.5, 220, 0.05, 0), Text = "NEW!", TextColor3 = GOLD, ZIndex = 23 })
					tag.Rotation = -12
				end
				K.button({ Parent = overlay, AnchorPoint = Vector2.new(0.5, 1), Size = UDim2.fromOffset(200, 54), Position = UDim2.new(0.5, 0, 0.95, 0), Text = "OK", BackgroundColor3 = rgb(110, 50, 20), StrokeColor = ORANGE, ZIndex = 25 }, function()
					overlay:Destroy()
				end)
				-- награда продолжает медленно вращаться
				local t0 = os.clock()
				local spin
				spin = RunService.RenderStepped:Connect(function()
					if not overlay.Parent then
						spin:Disconnect()
						return
					end
					if reward and reward.Parent then
						local y = 1.5 + (isRune and 3.8 or 2.2) + (rewardBase or 0) + math.sin((os.clock() - t0) * 2) * 0.15
						reward:PivotTo(CFrame.new(0, y, -0.6) * CFrame.Angles(0, math.pi + (os.clock() - t0) * 0.8, 0))
					end
				end)
			end
			if secret then
				-- SECRET: чёрный экран, оранжево-красные вспышки, тряска, затем награда
				FX.Sound("Secret", 1, 0.9)
				FX.Shake(0.8, 1.4)
				local black = K.new("Frame", { Parent = overlay, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), ZIndex = 40 })
				local big = K.label({ Parent = black, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(900, 160), Position = UDim2.fromScale(0.5, 0.45), Text = "SECRET!!", TextColor3 = ORANGE, ZIndex = 41, StrokeThickness = 4 })
				K.label({ Parent = black, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(700, 50), Position = UDim2.fromScale(0.5, 0.6), Text = def.Name, TextColor3 = Color3.fromRGB(255, 60, 60), ZIndex = 41 })
				for i = 1, 10 do
					task.delay(i * 0.12, function()
						black.BackgroundColor3 = (i % 2 == 0) and rgb(140, 40, 0) or Color3.new(0, 0, 0)
						big.Rotation = (math.random() - 0.5) * 10
					end)
				end
				task.delay(1.6, function()
					K.tween(black, 0.5, { BackgroundTransparency = 1 })
					for _, d in ipairs(black:GetDescendants()) do
						if d:IsA("TextLabel") then
							K.tween(d, 0.4, { TextTransparency = 1 })
						end
					end
					task.delay(0.55, function()
						black:Destroy()
					end)
					finish()
				end)
			else
				finish()
			end
		end
	end)
	local _ = showCards
end

------------------------------------------------------------------------
-- РУНЫ: выбор для юнита
------------------------------------------------------------------------
local pickerUnit

local function buildRunePicker()
	local m = K.modal("Runes", "РУНЫ", UDim2.fromOffset(720, 420), "Rune")
	refs.RuneFor = K.label({ Parent = m, Size = UDim2.new(1, -36, 0, 24), Position = UDim2.fromOffset(18, 58), Text = "", TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = UI.Theme.Dim, Font = Enum.Font.GothamBold, ZIndex = 6 })
	refs.RuneRow = K.new("Frame", { Parent = m, BackgroundTransparency = 1, Size = UDim2.new(1, -36, 0, 270), Position = UDim2.fromOffset(18, 88), ZIndex = 6 }, {
		K.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 12), HorizontalAlignment = Enum.HorizontalAlignment.Center }),
	})
	refs.RuneRemove = K.button({ Parent = m, AnchorPoint = Vector2.new(0.5, 1), Size = UDim2.fromOffset(260, 44), Position = UDim2.new(0.5, 0, 1, -12), Text = "СНЯТЬ РУНУ", BackgroundColor3 = rgb(110, 40, 50), ZIndex = 6 }, function()
		if pickerUnit then
			ctx.Request("EquipRune", { Unit = pickerUnit })
		end
	end)
end

local function refreshPicker()
	local prof = ctx.Profile
	if not pickerUnit or not prof or not refs.RuneRow then
		return
	end
	local def = Config.Units[pickerUnit]
	local current = prof.RuneSlots and prof.RuneSlots[pickerUnit]
	refs.RuneFor.Text = "Юнит: " .. def.Name .. "  •  1 руна на юнита. Руна работает, только когда надета."
	refs.RuneRemove.Visible = current ~= nil
	for _, c in ipairs(refs.RuneRow:GetChildren()) do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	for i, runeId in ipairs(Config.RuneOrder) do
		local rd = Config.Runes[runeId]
		local have = prof.Runes and prof.Runes[runeId] or 0
		local used = 0
		for _, r in pairs(prof.RuneSlots or {}) do
			if r == runeId then
				used = used + 1
			end
		end
		local on = current == runeId
		local card = K.panel({ Parent = refs.RuneRow, Size = UDim2.fromOffset(210, 266), BackgroundColor3 = UI.Theme.BG2, StrokeColor = on and GOLD or (have > 0 and rd.Color or rgb(60, 50, 60)), LayoutOrder = i, ZIndex = 7 })
		HalloweenUI.RuneViewport(card, runeId, { Size = UDim2.new(1, 0, 0, 96), ZIndex = 8 })
		K.label({ Parent = card, Size = UDim2.new(1, -12, 0, 22), Position = UDim2.fromOffset(6, 96), Text = rd.Name, TextColor3 = rd.Color, ZIndex = 8 })
		K.label({ Parent = card, Size = UDim2.new(1, -12, 0, 16), Position = UDim2.fromOffset(6, 118), Text = string.format("есть: %d  •  надето: %d", have, used), TextColor3 = UI.Theme.Dim, Font = Enum.Font.GothamBold, ZIndex = 8 })
		K.label({ Parent = card, Size = UDim2.new(1, -12, 0, 76), Position = UDim2.fromOffset(6, 136), Text = rd.Description, TextScaled = false, TextSize = 12, TextWrapped = true, Font = Enum.Font.Gotham, TextColor3 = UI.Theme.Text, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 8 })
		local free = have - used + (on and 1 or 0)
		K.button({ Parent = card, AnchorPoint = Vector2.new(0.5, 1), Size = UDim2.new(1, -16, 0, 38), Position = UDim2.new(0.5, 0, 1, -8), Text = on and "НАДЕТА" or (have == 0 and "НЕТ РУНЫ" or (free > 0 and "НАДЕТЬ" or "ЗАНЯТА")), BackgroundColor3 = on and rgb(90, 70, 20) or (free > 0 and rgb(60, 110, 60) or rgb(60, 50, 60)), ZIndex = 8 }, function()
			if on or have == 0 then
				return
			end
			ctx.Request("EquipRune", { Unit = pickerUnit, Rune = runeId })
		end)
	end
end

function HalloweenUI.OpenRunePicker(unitId)
	pickerUnit = unitId
	UI.Show("Runes", true)
	refreshPicker()
end

function HalloweenUI.OnProfile(prof)
	if UI.Modals.Runes and UI.Modals.Runes.Visible then
		refreshPicker()
	end
end

------------------------------------------------------------------------
-- ОЧЕРЕДЬ НА 4 КВАДРАТАХ
------------------------------------------------------------------------
local function buildQueue()
	local p = K.panel({ Parent = UI.Root, AnchorPoint = Vector2.new(1, 0.5), Size = UDim2.fromOffset(330, 330), Position = UDim2.new(1, -110, 0.5, 0), StrokeColor = ORANGE, Visible = false, ZIndex = 4 })
	refs.Queue = p
	K.label({ Parent = p, Size = UDim2.new(1, -20, 0, 32), Position = UDim2.fromOffset(10, 8), Text = "🎃 HALLOWEEN TD", TextColor3 = ORANGE, ZIndex = 5 })
	refs.QMembers = K.label({ Parent = p, Size = UDim2.new(1, -20, 0, 92), Position = UDim2.fromOffset(10, 44), Text = "", TextScaled = false, TextSize = 17, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 5 })
	refs.QHost = K.label({ Parent = p, Size = UDim2.new(1, -20, 0, 18), Position = UDim2.fromOffset(10, 140), Text = "", TextColor3 = UI.Theme.Dim, Font = Enum.Font.GothamBold, ZIndex = 5 })
	local row = K.new("Frame", { Parent = p, BackgroundTransparency = 1, Size = UDim2.new(1, -20, 0, 44), Position = UDim2.fromOffset(10, 164), ZIndex = 5 }, {
		K.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6) }),
	})
	refs.QDiff = {}
	for i, key in ipairs(Config.Halloween.Difficulties) do
		local d = Config.Difficulties[key]
		refs.QDiff[key] = K.button({ Parent = row, Size = UDim2.fromOffset(98, 44), Text = d.Name .. "\n" .. Config.Halloween.Coins[key] .. "🎃", TextColor3 = d.Color, BackgroundColor3 = UI.Theme.BG2, StrokeColor = d.Color, LayoutOrder = i, ZIndex = 6 }, function()
			ctx.Request("QueueDifficulty", { Difficulty = key })
		end)
	end
	refs.QTimer = K.label({ Parent = p, Size = UDim2.new(1, -20, 0, 30), Position = UDim2.fromOffset(10, 214), Text = "", TextColor3 = GOLD, ZIndex = 5 })
	refs.QStart = K.button({ Parent = p, Size = UDim2.new(0.5, -14, 0, 44), Position = UDim2.new(0, 10, 1, -54), Text = "СТАРТ", BackgroundColor3 = rgb(140, 70, 20), StrokeColor = ORANGE, ZIndex = 6 }, function()
		ctx.Request("QueueStart")
	end)
	K.button({ Parent = p, Size = UDim2.new(0.5, -14, 0, 44), Position = UDim2.new(0.5, 4, 1, -54), Text = "ВЫЙТИ", BackgroundColor3 = rgb(110, 30, 40), StrokeColor = UI.Theme.Bad, ZIndex = 6 }, function()
		ctx.Request("QueueLeave")
	end)
end

function HalloweenUI.UpdateQueue()
	local st = ctx.State
	local names = st:GetAttribute("HQ_Members") or ""
	local inQueue = false
	local list = {}
	for n in string.gmatch(names, "[^\n]+") do
		list[#list + 1] = n
		if n == player.DisplayName then
			inQueue = true
		end
	end
	local p = refs.Queue
	if not p then
		return
	end
	p.Visible = inQueue and not player:GetAttribute("InMatch")
	if not p.Visible then
		return
	end
	local isHost = (st:GetAttribute("HQ_Host") or 0) == player.UserId
	local lines = {}
	for i = 1, Config.HalloweenIsland.Queue.MaxPlayers do
		lines[i] = (i == 1 and "👑 " or "• ") .. (list[i] or "свободно")
	end
	refs.QMembers.Text = table.concat(lines, "\n")
	refs.QHost.Text = isHost and "Ты хост: выбери сложность" or "Сложность выбирает хост"
	local diff = st:GetAttribute("HQ_Diff") or "Easy"
	for key, b in pairs(refs.QDiff) do
		b.BackgroundColor3 = key == diff and Config.Difficulties[key].Color:Lerp(Color3.new(0, 0, 0), 0.4) or UI.Theme.BG2
		b.Active = isHost
		b.AutoButtonColor = false
	end
	refs.QStart.Visible = isHost
	local at = st:GetAttribute("HQ_At") or 0
	if st:GetAttribute("HQ_Busy") then
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
local function enemyViewport(parent, id, props)
	local vf = K.new("ViewportFrame", { Parent = parent, BackgroundTransparency = 1, Size = props.Size, Position = props.Position or UDim2.new(), Ambient = rgb(150, 130, 160), LightColor = rgb(255, 240, 230), LightDirection = Vector3.new(-0.5, -1, -0.8), ZIndex = props.ZIndex or 1 })
	local ok, rig = pcall(EnemyModels.Build, id)
	if not ok then
		return vf
	end
	for _, d in ipairs(rig.Model:GetDescendants()) do
		if d:IsA("ParticleEmitter") or d:IsA("Trail") or d:IsA("PointLight") then
			d:Destroy()
		end
	end
	rig.Model.Parent = vf
	local cam = Instance.new("Camera")
	cam.FieldOfView = 34
	local h = rig.Height or 5
	local c = Vector3.new(0, h * 0.5 - rig.HipHeight, 0)
	cam.CFrame = CFrame.lookAt(c + Vector3.new(h * 0.45, h * 0.25, -h * 1.7), c)
	cam.Parent = vf
	vf.CurrentCamera = cam
	return vf
end

local function buildBestiary()
	local m = K.modal("Bestiary", "БЕСТИАРИЙ • HAUNTED HOLLOW", UDim2.fromOffset(940, 580), "Pumpkin")
	local grid = K.new("ScrollingFrame", { Parent = m, BackgroundTransparency = 1, Size = UDim2.new(1, -36, 1, -80), Position = UDim2.fromOffset(18, 66), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 6, BorderSizePixel = 0, ZIndex = 6 }, {
		K.new("UIGridLayout", { CellSize = UDim2.fromOffset(212, 236), CellPadding = UDim2.fromOffset(10, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	refs.BestiaryGrid = grid
	refs.BestiaryBuilt = false
end

local BOSS_OF = { GraveWarden = "Easy", FogReaper = "Medium", CursedMonarch = "Hard" }
local function fillBestiary()
	if refs.BestiaryBuilt then
		return
	end
	refs.BestiaryBuilt = true
	for order, id in ipairs(Config.EnemyOrder) do
		local e = Config.Enemies[id]
		if e.Event == "Halloween" then
			local diff = BOSS_OF[id] and Config.Difficulties[BOSS_OF[id]]
			local col = diff and diff.Color or (e.MiniBoss and rgb(200, 90, 255) or ORANGE)
			local card = K.panel({ Parent = refs.BestiaryGrid, BackgroundColor3 = UI.Theme.BG2, StrokeColor = col, LayoutOrder = order, ZIndex = 7 })
			enemyViewport(card, id, { Size = UDim2.new(1, 0, 0, 110), ZIndex = 8 })
			K.label({ Parent = card, Size = UDim2.new(1, -10, 0, 22), Position = UDim2.fromOffset(5, 110), Text = e.Name, TextColor3 = col, ZIndex = 8 })
			local tag = diff and ("ФИНАЛЬНЫЙ БОСС • " .. diff.Name) or (e.MiniBoss and "МИНИ-БОСС" or "ВРАГ")
			K.label({ Parent = card, Size = UDim2.new(1, -10, 0, 14), Position = UDim2.fromOffset(5, 132), Text = string.format("%s  •  HP %d  •  скор. %g", tag, e.Health, e.Speed), TextColor3 = UI.Theme.Dim, Font = Enum.Font.GothamBold, ZIndex = 8 })
			K.label({ Parent = card, Size = UDim2.new(1, -12, 0, 80), Position = UDim2.fromOffset(6, 150), Text = e.Description or "", TextScaled = false, TextSize = 12, TextWrapped = true, Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 8 })
		end
	end
end

HalloweenUI.FillBestiary = fillBestiary

------------------------------------------------------------------------
function HalloweenUI.Init(c, ui)
	ctx, UI = c, ui
	Config, UnitModels, EnemyModels, CaseModels, FX = c.Config, c.UnitModels, c.EnemyModels, c.CaseModels, c.FX
	K = UI.Kit
	buildRunePicker()
	buildQueue()
	buildBestiary()
	-- 3D-руны медленно вращаются
	RunService.RenderStepped:Connect(function()
		local list = refs.RuneSpins
		if not list then
			return
		end
		local t = os.clock()
		for i = #list, 1, -1 do
			local it = list[i]
			if not it.VF.Parent then
				table.remove(list, i)
			elseif it.VF.Visible then
				it.Model:PivotTo(CFrame.new(0, math.sin(t * 1.6) * 0.08, 0) * CFrame.Angles(0, t * 0.9, 0))
			end
		end
	end)
end

return HalloweenUI
