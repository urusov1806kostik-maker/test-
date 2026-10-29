--!nocheck
-- VOID TD :: UI.Openings — анимации открытия кейсов (тряска → взрыв → карточки) и проклятого сундука Хэллоуина
-- (цепи → крышка → награда поднимается), кинематограф SECRET.
--
-- API
--   Openings.Build(UI, ctx)
--   Openings.PlayCase(caseId, results)     results = { {Id, New} | {Rune, New}, ... }
--   Openings.PlayHalloween(results)         показывает results[1]
--   Openings.ShowCards(overlay, results) ; Openings.RuneCard(grid, r, i) ; Openings.Busy() -> bool

local RunService = game:GetService("RunService")

local Openings = {}

local rgb = Color3.fromRGB
local V2 = Vector2.new
local V3 = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles
local BLACK = Color3.new(0, 0, 0)
local WHITE = Color3.new(1, 1, 1)
local ORANGE = rgb(255, 130, 30)
local GOLD = rgb(255, 205, 80)

local UI, ctx, K, T, Config, FX
local active = 0 -- открытых оверлеев (защита от двойного открытия)

function Openings.Busy()
	return active > 0
end

local function overlay(color, transp)
	active += 1
	local ov = K.new("Frame", { Parent = UI.Root, Name = "CaseOverlay", Size = UDim2.fromScale(1, 1), BackgroundColor3 = color, BackgroundTransparency = transp, BorderSizePixel = 0, ZIndex = 20 })
	ov.Destroying:Connect(function()
		active = math.max(0, active - 1)
	end)
	return ov
end

local function flash(parent, color, transp, life)
	local f = K.new("Frame", { Parent = parent, Size = UDim2.fromScale(1, 1), BackgroundColor3 = color, BackgroundTransparency = transp, BorderSizePixel = 0, ZIndex = 30 })
	K.tween(f, life, { BackgroundTransparency = 1 })
	task.delay(life + 0.05, function()
		f:Destroy()
	end)
end

local function okButton(ov, props)
	local p = { Parent = ov, AnchorPoint = V2(0.5, 1), Position = UDim2.fromScale(0.5, 0.95), Size = UDim2.fromOffset(200, 54), Text = "OK", ZIndex = 25 }
	for k, v in pairs(props or {}) do
		p[k] = v
	end
	return K.button(p, function()
		ov:Destroy()
	end)
end

-- кинематограф SECRET поверх оверлея; done() — по окончании
local function secretFlash(ov, color, flickerColor, flickers, hold, sub)
	FX.Sound("Secret", 1, color == ORANGE and 0.9 or 1)
	FX.Shake(0.8, color == ORANGE and 1.4 or 1.2)
	local blk = K.new("Frame", { Parent = ov, Size = UDim2.fromScale(1, 1), BackgroundColor3 = BLACK, BorderSizePixel = 0, ZIndex = 40 })
	local lab = K.label({ Parent = blk, AnchorPoint = V2(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.fromOffset(900, 160), Text = "SECRET!!", TextColor3 = color, StrokeThickness = 4, ZIndex = 41 })
	if sub then
		K.label({ Parent = blk, AnchorPoint = V2(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.6), Size = UDim2.fromOffset(700, 50), Text = sub, TextColor3 = rgb(255, 60, 60), ZIndex = 41 })
	end
	for i = 1, flickers do
		task.wait(0.12)
		if not blk.Parent then
			return
		end
		blk.BackgroundColor3 = i % 2 == 0 and flickerColor or BLACK
		lab.Rotation = math.random(-5, 5)
	end
	task.wait(math.max(0, hold - flickers * 0.12))
	if not blk.Parent then
		return
	end
	K.tween(blk, hold > 1.5 and 0.5 or 0.4, { BackgroundTransparency = 1 })
	for _, d in ipairs(blk:GetChildren()) do
		if d:IsA("TextLabel") then
			K.tween(d, 0.4, { TextTransparency = 1 })
		end
	end
	task.wait(hold > 1.5 and 0.55 or 0.45)
	blk:Destroy()
end

------------------------------------------------------------------------
-- КАРТОЧКИ НАГРАД
------------------------------------------------------------------------
local function cardBase(grid, i, col)
	local card = K.panel({ Parent = grid, LayoutOrder = i, BackgroundColor3 = T.BG2, StrokeColor = col, ZIndex = 23 })
	K.new("UIGradient", { Parent = card, Rotation = 90, Color = ColorSequence.new(col:Lerp(T.BG, 0.55), T.BG) })
	local sc = K.new("UIScale", { Parent = card, Scale = 0 })
	K.tween(sc, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	return card
end

function Openings.RuneCard(grid, r, i)
	local rd = Config.Runes[r.Rune]
	local col = Config.RuneRarity.Color
	local card = cardBase(grid, i, col)
	K.runeViewport(card, r.Rune, { Position = UDim2.fromOffset(0, 8), Size = UDim2.new(1, 0, 0, 120), ZIndex = 24 })
	K.label({ Parent = card, Position = UDim2.fromOffset(4, 130), Size = UDim2.new(1, -8, 0, 22), Text = rd and rd.Name or tostring(r.Rune), ZIndex = 24 })
	K.label({ Parent = card, Position = UDim2.fromOffset(4, 154), Size = UDim2.new(1, -8, 0, 18), Text = "РУНА • " .. Config.RuneRarity.Name, TextColor3 = col, ZIndex = 24 })
	return card
end

function Openings.ShowCards(ov, results)
	local n = #results
	local rows = n > 5 and 2 or 1
	local grid = K.new("Frame", { Parent = ov, AnchorPoint = V2(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.55), Size = UDim2.fromOffset(5 * 150, rows * 200), BackgroundTransparency = 1, ZIndex = 22 })
	K.new("UIGridLayout", { Parent = grid, CellSize = UDim2.fromOffset(140, 190), CellPadding = UDim2.fromOffset(10, 10), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder })
	task.spawn(function()
		for i, r in ipairs(results) do
			task.wait(0.15)
			if not ov.Parent then
				return
			end
			if r.Rune then
				Openings.RuneCard(grid, r, i)
			else
				local def = Config.Units[r.Id]
				if def then
					local col = K.rarityColor(r.Id)
					local card = cardBase(grid, i, col)
					K.unitViewport(card, r.Id, 1, { Position = UDim2.fromOffset(0, 8), Size = UDim2.new(1, 0, 0, 120), ZIndex = 24 })
					K.label({ Parent = card, Position = UDim2.fromOffset(4, 130), Size = UDim2.new(1, -8, 0, 22), Text = def.Name, ZIndex = 24 })
					K.label({ Parent = card, Position = UDim2.fromOffset(4, 154), Size = UDim2.new(1, -8, 0, 18), Text = string.upper(def.Rarity), TextColor3 = col, ZIndex = 24 })
					K.eventTag(card, r.Id, 24, UDim2.fromOffset(4, 172), UDim2.new(1, -8, 0, 14))
					if r.New then
						K.label({ Parent = card, Position = UDim2.fromOffset(6, 6), Size = UDim2.fromOffset(56, 22), Text = "NEW!", TextColor3 = T.Gold, Rotation = -12, ZIndex = 25 })
					end
					FX.Sound("Reveal", 1, 0.8 + Config.Rarities[def.Rarity].Order * 0.12)
				end
			end
		end
		task.wait(0.4)
		if ov.Parent then
			okButton(ov)
		end
	end)
end

------------------------------------------------------------------------
-- ОБЫЧНЫЙ КЕЙС
------------------------------------------------------------------------
local SHAKE, BURST = 1.4, 0.9

function Openings.PlayCase(caseId, results)
	local case = Config.Cases[caseId]
	if not case then
		return
	end
	local best = 1
	for _, r in ipairs(results) do
		local def = r.Id and Config.Units[r.Id]
		if def then
			best = math.max(best, Config.Rarities[def.Rarity].Order)
		end
	end
	local bestName = Config.RarityOrder[best]
	local bestColor = Config.Rarities[bestName].Color
	local ov = overlay(rgb(5, 0, 10), 0.15)
	local stage = K.new("Frame", { Parent = ov, AnchorPoint = V2(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(520, 520), BackgroundTransparency = 1, ZIndex = 21 })
	local r = K.caseViewport(stage, caseId, { ZIndex = 21 })
	local title = K.label({ Parent = ov, AnchorPoint = V2(0.5, 0), Position = UDim2.fromScale(0.5, 0.06), Size = UDim2.fromOffset(700, 56), Text = case.Name, TextColor3 = case.Color, StrokeThickness = 3, ZIndex = 22 })
	-- направления разлёта
	local dirs = {}
	for p, base in pairs(r.Base) do
		local d = base.Position - V3(0, 2, 0)
		d = d.Magnitude > 0.01 and d.Unit or V3(0, 1, 0)
		dirs[p] = d + V3(math.random() - 0.5, math.random() * 0.6, math.random() - 0.5)
	end
	local blood = caseId == "BloodMoon"
	local t0 = os.clock()
	local nextShake, burst = 0, false
	local conn
	local function finish()
		if conn then
			conn:Disconnect()
			conn = nil
		end
		if not ov.Parent then
			return
		end
		stage:Destroy()
		title.Text = best >= 4 and (string.upper(bestName) .. "!") or case.Name
		title.TextColor3 = bestColor
		if bestName == "Secret" then
			task.spawn(function()
				secretFlash(ov, rgb(255, 30, 50), rgb(120, 0, 10), 8, 1.4)
				if ov.Parent then
					Openings.ShowCards(ov, results)
				end
			end)
		else
			Openings.ShowCards(ov, results)
		end
	end
	conn = RunService.RenderStepped:Connect(function()
		if not ov.Parent then
			conn:Disconnect()
			return
		end
		local t = os.clock() - t0
		if t < SHAKE then
			local k = t / SHAKE
			local shake = CF((math.random() - 0.5) * k * 0.5, 0, (math.random() - 0.5) * k * 0.5) * ANG(0, t * (1 + k * 6), (math.random() - 0.5) * k * 0.15)
			for p, base in pairs(r.Base) do
				p.CFrame = shake * base
			end
			if caseId == "VoidCase" and r.Lid and r.Base[r.Lid] then
				r.Lid.CFrame = shake * r.Base[r.Lid] * CF(0, k * 1.2, 0.6 * k) * ANG(-0.9 * k, 0, 0)
			elseif caseId == "ShatteredReality" then
				for _, c in ipairs(r.Cracks) do
					c.Size = V3(0.14 + 0.3 * k, 0.14 + 0.3 * k, c.Size.Z)
				end
				if r.Core and r.Base[r.Core] then
					r.Core.CFrame = shake * r.Base[r.Core] * CF(0, 1.5 * k, 0) * ANG(0, t * 8, 0)
				end
			elseif blood and r.Shards[1] and r.Base[r.Shards[1]] then
				r.Shards[1].CFrame = shake * r.Base[r.Shards[1]] * CF(0, -2.8 * k, 0)
				ov.BackgroundColor3 = rgb(5 + 60 * k, 0, 10)
			end
			for i, s in ipairs(r.Shards) do
				if not (blood and i == 1) then
					s.CFrame = ANG(0, t * (2 + 10 * k), 0) * s.CFrame
				end
			end
			if t >= nextShake then
				nextShake = t + (0.45 - 0.3 * k)
				FX.Sound("CaseShake", 1, 0.8 + 0.8 * k)
			end
		elseif t < SHAKE + BURST then
			if not burst then
				burst = true
				FX.Sound("CaseOpen", 1, 1)
				flash(ov, bestColor, 0.1, 0.8)
			end
			local k = (t - SHAKE) / BURST
			for p, base in pairs(r.Base) do
				local d = dirs[p]
				p.CFrame = CF(d * k * 14) * base * ANG(4 * k * d.X, 5 * k, 4 * k * d.Z)
				p.Transparency = math.min(1, 1.3 * k)
			end
		else
			finish()
		end
	end)
end

------------------------------------------------------------------------
-- ПРОКЛЯТЫЙ СУНДУК ХЭЛЛОУИНА
------------------------------------------------------------------------
local H_SHAKE, H_BREAK, H_OPEN, H_RISE = 1.6, 0.5, 0.7, 0.9

function Openings.PlayHalloween(results)
	local r0 = results and results[1]
	if not r0 then
		return
	end
	local isRune = r0.Rune ~= nil
	local def = r0.Id and Config.Units[r0.Id]
	if not isRune and not def then
		return
	end
	local rarity = isRune and "Rune" or def.Rarity
	local color = isRune and Config.RuneRarity.Color or K.rarityColor(r0.Id)
	local order = (not isRune and Config.Rarities[rarity] and Config.Rarities[rarity].Order) or 3
	local secret = rarity == "Secret"

	local ov = overlay(rgb(8, 2, 4), 0.1)
	local vf = K.new("ViewportFrame", {
		Parent = ov, AnchorPoint = V2(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52), Size = UDim2.fromOffset(620, 620), BackgroundTransparency = 1,
		Ambient = rgb(120, 80, 70), LightColor = rgb(255, 210, 160), LightDirection = V3(-0.4, -1, -0.8), ZIndex = 21,
	})
	local cam = Instance.new("Camera")
	cam.FieldOfView = 40
	cam.Parent = vf
	vf.CurrentCamera = cam
	local okC, r = pcall(ctx.CaseModels.Build, "Halloween")
	if not okC or type(r) ~= "table" or not r.Model then
		r = { Model = Instance.new("Model"), Base = {} }
	end
	K.StripModel(r.Model)
	r.Model.Parent = vf
	local base = r.Base or {}
	local lidParts = r.LidParts or { r.Lid }
	local isLid = {}
	for _, p in ipairs(lidParts) do
		isLid[p] = true
	end
	local chains = r.Chains or {}
	local isChain, chainDir = {}, {}
	for _, p in ipairs(chains) do
		isChain[p] = true
		chainDir[p] = V3(math.random() - 0.5, math.random() * 0.8 + 0.2, math.random() - 0.5).Unit
	end
	local hinge = r.Hinge or CF(0, 2.7, 1.4)
	local eyes, eyeBase = r.Eyes or {}, {}
	for i, e in ipairs(eyes) do
		eyeBase[i] = e.Color
	end
	local title = K.label({ Parent = ov, AnchorPoint = V2(0.5, 0), Position = UDim2.fromScale(0.5, 0.05), Size = UDim2.fromOffset(700, 56), Text = "HALLOWEEN CASE", TextColor3 = ORANGE, StrokeThickness = 3, ZIndex = 22 })
	local glow = K.new("Frame", { Parent = ov, AnchorPoint = V2(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.55), Size = UDim2.fromOffset(10, 10), BackgroundColor3 = ORANGE, BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 20 })
	K.corner(300).Parent = glow
	FX.Sound("CaseShake", 1, 0.6)

	local reward, rewardHip = nil, 0
	local riseH = isRune and 3.8 or 2.2
	local t0 = os.clock()
	local nextShake, broke, rose = 0, false, false
	local conn

	local function buildReward()
		if isRune then
			local ok, rr = pcall(ctx.UnitModels.BuildRune, r0.Rune)
			if ok and rr and rr.Model then
				rr.Model:ScaleTo(1.2)
				reward = rr.Model
			end
		else
			local ok, rig = pcall(ctx.UnitModels.Build, r0.Id, 1)
			if ok and rig and rig.Model then
				K.StripModel(rig.Model)
				reward = rig.Model
				rewardHip = rig.HipHeight or 0
			end
		end
		if reward then
			reward.Parent = vf
		end
	end

	local function finish()
		if not ov.Parent then
			return
		end
		local rd = isRune and Config.Runes[r0.Rune]
		title.Text = isRune and ("РУНА «" .. (rd and rd.Name or r0.Rune) .. "»") or def.Name
		title.TextColor3 = color
		local ev = Config.Events.Halloween
		K.label({
			Parent = ov, AnchorPoint = V2(0.5, 0), Position = UDim2.new(0.5, 0, 0.05, 60), Size = UDim2.fromOffset(600, 34), ZIndex = 22,
			Text = isRune and ("РУНА • " .. Config.RuneRarity.Name) or (string.upper(rarity) .. "  •  " .. (ev and ev.Tag or "")),
			TextColor3 = isRune and color or ORANGE,
		})
		if r0.New then
			K.label({ Parent = ov, AnchorPoint = V2(0.5, 0), Position = UDim2.new(0.5, 220, 0.05, 0), Size = UDim2.fromOffset(160, 34), Text = "NEW!", TextColor3 = GOLD, Rotation = -12, ZIndex = 23 })
		end
		okButton(ov, { BackgroundColor3 = rgb(110, 50, 20), StrokeColor = ORANGE })
		-- награда продолжает вращаться
		local s0 = os.clock()
		local spin
		spin = RunService.RenderStepped:Connect(function()
			if not ov.Parent or not reward then
				spin:Disconnect()
				return
			end
			local dt = os.clock() - s0
			reward:PivotTo(CF(0, 1.5 + riseH + rewardHip + math.sin(dt * 2) * 0.15, -0.6) * ANG(0, math.pi + dt * 0.8, 0))
		end)
	end

	conn = RunService.RenderStepped:Connect(function()
		if not ov.Parent then
			conn:Disconnect()
			return
		end
		local t = os.clock() - t0
		local kc = math.clamp(t / 2.1, 0, 1)
		local dist = 15 - 4.5 * kc
		cam.CFrame = CFrame.lookAt(V3(0, 4.5 - 0.6 * kc, -dist), V3(0, 2.4, 0))
		if t < H_SHAKE then
			local a = t / H_SHAKE
			local shake = CF((math.random() - 0.5) * a * 0.35, 0, (math.random() - 0.5) * a * 0.35) * ANG(0, 0, (math.random() - 0.5) * a * 0.12)
			for p, b in pairs(base) do
				p.CFrame = shake * b
			end
			for i, e in ipairs(eyes) do
				e.Color = eyeBase[i]:Lerp(rgb(255, 240, 180), a)
			end
			local sz = 60 + 300 * a
			glow.Size = UDim2.fromOffset(sz, sz)
			glow.BackgroundTransparency = 1 - 0.25 * a
			if t >= nextShake then
				nextShake = t + (0.42 - 0.28 * a)
				FX.Sound("CaseShake", 1, 0.6 + 0.6 * a)
			end
		elseif t < H_SHAKE + H_BREAK then
			local a = (t - H_SHAKE) / H_BREAK
			if not broke then
				broke = true
				FX.Sound("CaseOpen", 0.7, 1)
				flash(ov, ORANGE, 0.3, 0.5)
			end
			for p, b in pairs(base) do
				if isChain[p] then
					local d = chainDir[p]
					p.CFrame = CF(d * a * 9 + V3(0, -3 * a * a, 0)) * b * ANG(5 * a * d.X, 4 * a, 5 * a * d.Z)
					p.Transparency = math.min(1, 1.2 * a)
				else
					p.CFrame = b -- крышка тоже на место (без скачка при открытии)
				end
			end
		elseif t < H_SHAKE + H_BREAK + H_OPEN then
			local a = (t - H_SHAKE - H_BREAK) / H_OPEN
			local ang = math.rad(110) * (1 - (1 - a) ^ 3)
			local rot = hinge * ANG(ang, 0, 0) * hinge:Inverse()
			for _, p in ipairs(lidParts) do
				if base[p] then
					p.CFrame = rot * base[p]
				end
			end
			glow.BackgroundColor3 = color
			local sz = 360 + 200 * a
			glow.Size = UDim2.fromOffset(sz, sz)
		elseif t < H_SHAKE + H_BREAK + H_OPEN + H_RISE then
			local a = (t - H_SHAKE - H_BREAK - H_OPEN) / H_RISE
			if not rose then
				rose = true
				FX.Sound("Reveal", 1, isRune and 1.2 or (0.7 + order * 0.12))
				buildReward()
			end
			if reward then
				reward:PivotTo(CF(0, 1.5 + a * riseH + rewardHip * a, -0.6) * ANG(0, math.pi + a * 2 * math.pi, 0))
			end
		else
			conn:Disconnect()
			if secret then
				task.spawn(function()
					secretFlash(ov, ORANGE, rgb(140, 40, 0), 10, 1.6, def and def.Name)
					finish()
				end)
			else
				finish()
			end
		end
	end)
end

function Openings.Build(ui, c)
	UI, ctx = ui, c
	K, T, Config, FX = ui.Kit, ui.Theme, c.Config, c.FX
end

return Openings
