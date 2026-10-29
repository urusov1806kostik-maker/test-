--!nocheck
-- VOID TD :: UI.Viewer — большое окно 3D-просмотра юнита (копия модели в ViewportFrame + WorldModel):
-- вкладки уровней (ничего не покупают), анимации и способности, вращение/зум, эффекты редкости,
-- галерея призыва / «проклятых людей», кинематограф SECRET.
--
-- API
--   Viewer.Build(UI, ctx) ; Viewer.Open(unitId, level) ; Viewer.SetLevel(lv) ; Viewer.PlayAnim(kind)
--   Viewer.Refresh() ; Viewer.IsOpen() ; Viewer.Close()

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Viewer = {}

local rgb = Color3.fromRGB
local V2 = Vector2.new
local V3 = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles
local rad = math.rad
local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)

local GLOW = {
	Common = rgb(150, 140, 170), Rare = rgb(90, 150, 255), Epic = rgb(70, 140, 255),
	Legendary = rgb(255, 200, 70), Mythic = rgb(190, 80, 255), Secret = rgb(255, 40, 60),
}
local PARTICLES = { Mythic = 14, Secret = 10, Legendary = 9, Epic = 6 }
local LEVEL_TABS = { "LVL 1", "LVL 2", "LVL 3", "LVL 4", "MAX" }
local GOLD = rgb(230, 178, 74)
local ORANGE = rgb(255, 140, 40)
local POWER_FX = {
	LanternBeam = rgb(255, 230, 150), DirtBurst = rgb(140, 110, 80), LeafStorm = rgb(230, 140, 40), CurseMark = rgb(120, 255, 110),
	MidnightToll = rgb(190, 160, 255), PlagueCloud = rgb(140, 230, 80), GhostSword = rgb(110, 190, 255), MirrorShatter = rgb(180, 90, 255),
	ThreadSnap = rgb(230, 30, 50), Execution = rgb(255, 110, 30), GhostPumpkin = rgb(255, 140, 40), Summon = rgb(200, 90, 255),
}
local ZOOM_MIN, ZOOM_MAX = 0.45, 1.8

local UI, ctx, K, T, Config, UnitModels, Renderer, FX
local win, dim, refs
local state
local conns = {}
local particles, sparks = {}, {}

local function glowOf(def)
	return GLOW[def.Rarity] or T.Accent
end

------------------------------------------------------------------------
-- СЦЕНА
------------------------------------------------------------------------
local function part(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do
		p[k] = v
	end
	p.Parent = refs.World
	return p
end

local function strip(model)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("ParticleEmitter") or d:IsA("Light") or d:IsA("Trail") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.CanQuery = false
		end
	end
end

local function clearScene()
	if state and state.Rig then
		state.Rig.Model:Destroy()
		state.Rig = nil
	end
	refs.World:ClearAllChildren()
end

local function bounds(model)
	local lo, hi
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and d.Transparency < 1 then
			local r = math.max(d.Size.X, d.Size.Y, d.Size.Z) / 2
			local p = d.Position
			local a, b = p - V3(r, r, r), p + V3(r, r, r)
			lo = lo and V3(math.min(lo.X, a.X), math.min(lo.Y, a.Y), math.min(lo.Z, a.Z)) or a
			hi = hi and V3(math.max(hi.X, b.X), math.max(hi.Y, b.Y), math.max(hi.Z, b.Z)) or b
		end
	end
	return lo or V3(-2, -3, -2), hi or V3(2, 3, 2)
end

local function platform(groundY, r, glow)
	local flat = ANG(0, 0, rad(90))
	part({ Name = "Platform", Shape = Enum.PartType.Cylinder, Size = V3(0.6, 2 * r, 2 * r), CFrame = CF(0, groundY - 0.3, 0) * flat, Color = rgb(24, 20, 32), Material = Enum.Material.Slate })
	part({ Name = "PlatformTop", Shape = Enum.PartType.Cylinder, Size = V3(0.62, 1.7 * r, 1.7 * r), CFrame = CF(0, groundY - 0.29, 0) * flat, Color = rgb(40, 34, 54), Material = Enum.Material.Slate })
	part({ Name = "PlatformRing", Shape = Enum.PartType.Cylinder, Size = V3(0.64, 2.06 * r, 2.06 * r), CFrame = CF(0, groundY - 0.36, 0) * flat, Color = glow:Lerp(BLACK, 0.35), Material = Enum.Material.SmoothPlastic })
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		part({
			Name = "Rune", Size = V3(0.12, 0.62, 0.18 * r), Color = glow:Lerp(BLACK, 0.45), Material = Enum.Material.Neon,
			CFrame = CF(math.cos(a) * 0.93 * r, groundY - 0.3, math.sin(a) * 0.93 * r) * ANG(0, -a, 0),
		})
	end
end

local function updateCamera()
	local dir = V3(math.sin(state.Yaw) * math.cos(state.Pitch), math.sin(state.Pitch), -math.cos(state.Yaw) * math.cos(state.Pitch))
	refs.Cam.CFrame = CFrame.lookAt(state.Center + dir * state.Dist, state.Center)
end

local function buildModel(keepCamera)
	clearScene()
	local ok, rig = pcall(UnitModels.Build, state.Id, state.Level)
	if not ok or not rig then
		warn("[VOID TD] Предпросмотр: " .. tostring(rig))
		return
	end
	strip(rig.Model)
	rig.Root.CFrame = CF(0, rig.HipHeight or 0, 0)
	rig.Model.Parent = refs.World
	state.Rig = rig
	state.Anim = nil
	state.Phase = 0
	local def = Config.Units[state.Id]
	local glow = glowOf(def)
	local lo, hi = bounds(rig.Model)
	local size = hi - lo
	platform(0, math.max(size.X, size.Z, 4) * 0.62, glow)
	state.Center = V3(0, (lo.Y + hi.Y) / 2, 0)
	state.BaseDist = math.max(size.Y, size.X * 0.9) * 1.95 + 2
	if not keepCamera then
		state.Yaw, state.Pitch, state.Zoom = rad(200), rad(12), 1
	end
	state.Dist = state.BaseDist * state.Zoom
	refs.VF.LightColor = Color3.new(1, 0.97, 1):Lerp(glow, 0.2)
	updateCamera()
end

------------------------------------------------------------------------
-- ЭФФЕКТЫ РЕДКОСТИ
------------------------------------------------------------------------
local function clearList(list)
	for _, f in ipairs(list) do
		f:Destroy()
	end
	table.clear(list)
end

local function setGlow(glow)
	for i, g in ipairs(refs.Glows) do
		g.BackgroundColor3 = glow
		g.BackgroundTransparency = 0.84 + i * 0.04
	end
	refs.SceneStroke.Color = glow
end

local function spawnParticles(glow, n)
	clearList(particles)
	for i = 1, n do
		local s = (i * 0.6180339) % 1
		local sz = 6 + (i % 3) * 2
		local f = K.new("Frame", { Parent = refs.Scene, Size = UDim2.fromOffset(sz, sz), BackgroundColor3 = glow, BackgroundTransparency = 0.2, BorderSizePixel = 0, Rotation = 45, ZIndex = 24 })
		f:SetAttribute("Seed", s)
		particles[i] = f
	end
end

local function secretIntro()
	local ov = refs.Intro
	ov.Visible = true
	ov.BackgroundTransparency = 0
	refs.IntroText.Text = "✦ SECRET ✦"
	refs.IntroText.TextTransparency = 1
	refs.IntroRing.Size = UDim2.fromScale(0.05, 0.05)
	refs.IntroRing.BackgroundTransparency = 0.1
	state.Zoom = 2.2 -- камера стартует дальше, затем мягко подъезжает (колесо вернёт в диапазон)
	K.tween(refs.IntroText, 0.35, { TextTransparency = 0 })
	K.tween(refs.IntroRing, 0.7, { Size = UDim2.fromScale(1.6, 1.6), BackgroundTransparency = 1 })
	FX.Sound("Secret", 0.8, 1)
	local my = state
	task.delay(0.55, function()
		if ov.Parent and state == my then
			K.tween(ov, 0.6, { BackgroundTransparency = 1 })
			K.tween(refs.IntroText, 0.6, { TextTransparency = 1 })
		end
	end)
	task.delay(1.25, function()
		if ov.Parent and state == my then
			ov.Visible = false
		end
	end)
end

local function applyRarityFx(first)
	local def = Config.Units[state.Id]
	local glow = glowOf(def)
	setGlow(glow)
	spawnParticles(glow, PARTICLES[def.Rarity] or 0)
	clearList(sparks)
	local hw = def.Event == "Halloween"
	refs.Pumpkin.Visible = hw
	if hw then
		for i = 1, 8 do
			local f = K.new("Frame", { Parent = refs.Scene, Size = UDim2.fromOffset(4, 4), BackgroundColor3 = rgb(255, 150, 50), BackgroundTransparency = 0.3, BorderSizePixel = 0, Rotation = 45, ZIndex = 24 })
			f:SetAttribute("Seed", (i * 0.37 + 0.11) % 1)
			sparks[i] = f
		end
	end
	if first and def.Rarity == "Secret" then
		secretIntro()
	end
end

------------------------------------------------------------------------
-- ИНФО
------------------------------------------------------------------------
local function refreshInfo()
	local def = Config.Units[state.Id]
	local lv = state.Level
	local st = def.Levels[lv] or def.Levels[#def.Levels]
	local prof = ctx.Profile or {}
	local fmt = Config.FormatNumber
	local rcol = Config.Rarities[def.Rarity].Color
	refs.RarityBar.BackgroundColor3 = rcol
	refs.Name.Text = def.Name
	local rt = string.upper(def.Rarity)
	local ev = def.Event and Config.Events[def.Event]
	if ev then
		rt = rt .. '  <font color="#' .. ev.Color:ToHex() .. '">' .. ev.Tag .. "</font>"
	end
	local runeId = prof.RuneSlots and prof.RuneSlots[state.Id]
	local rd = runeId and Config.Runes[runeId]
	if rd then
		rt = rt .. '  <font color="#' .. Config.RuneRarity.Color:ToHex() .. '">• РУНА ' .. rd.Name .. "</font>"
	end
	refs.Rarity.Text = rt
	refs.Rarity.TextColor3 = rcol
	refs.Desc.Text = def.Description or ""
	for i, tab in ipairs(refs.Tabs) do
		local on = i == lv
		tab.BackgroundColor3 = on and T.Accent or T.BG3
		tab.TextColor3 = on and WHITE or T.Dim
	end
	local S = refs.Stats
	S[1].Text = fmt(st.Damage) .. ((st.Hits or 1) > 1 and ("  x" .. st.Hits) or "")
	S[2].Text = tostring(st.Range)
	S[3].Text = string.format("%.2f/с  (%.2f с)", 1 / st.Cooldown, st.Cooldown)
	S[4].Text = "$" .. fmt(def.Levels[1].Cost)
	if lv > 1 then
		local total = 0
		for i = 1, lv do
			total += def.Levels[i].Cost
		end
		S[5].Text = string.format("$%s  (всего $%s)", fmt(st.Cost), fmt(total))
	else
		S[5].Text = "—"
	end
	refs.Abilities.Text = (def.Ability and (def.Ability .. "\n") or "") .. (UI.SpecialText and UI.SpecialText(def, st) or tostring(def.AttackType))
	local inv = prof.Inventory or {}
	local eq = prof.Equipped or {}
	local equipped = false
	for i = 1, Config.Settings.EquipSlots do
		if eq[tostring(i)] == state.Id then
			equipped = true
		end
	end
	local b = refs.Equip
	if (inv[state.Id] or 0) <= 0 then
		b.Text, b.BackgroundColor3, b.Active = "НЕТ В КОЛЛЕКЦИИ", rgb(50, 44, 60), false
	elseif equipped then
		b.Text, b.BackgroundColor3, b.Active = "СНЯТЬ", rgb(130, 50, 60), true
	else
		b.Text, b.BackgroundColor3, b.Active = "ЭКИПИРОВАТЬ", rgb(70, 40, 140), true
	end
end

------------------------------------------------------------------------
-- ГАЛЕРЕЯ ПРИЗЫВА
------------------------------------------------------------------------
local function galleryList(kind)
	local out = {}
	if kind == "Rune" then
		local rs = Config.Runes.CursedThreads and Config.Runes.CursedThreads.Summon
		for i, lv in ipairs(rs and rs.Levels or {}) do
			out[#out + 1] = { Ally = lv.Ally, HP = lv.HP, Text = string.format("LVL %d • x%d • %d HP • каждые 60 с", i, lv.Count, lv.HP) }
		end
	else
		local s = Config.Units[state.Id].Summon
		for i, lv in ipairs(s and s.Levels or {}) do
			out[#out + 1] = { Ally = lv.Ally, HP = lv.HP, Text = string.format("%s • x%d • %d HP • %d с", i == 5 and "MAX" or ("LVL " .. i), lv.Count, lv.HP, lv.Interval) }
		end
		local g = s and s.Golden
		if g then
			out[#out + 1] = { Ally = g.Ally, HP = g.HP, Text = string.format("MAX • каждый %d-й призыв • %d HP", g.Every, g.HP) }
		end
	end
	return out
end

local function galleryLabel()
	return Config.Units[state.Id].Summon and "ПОСМОТРЕТЬ ПРИЗЫВ" or "ПРОКЛЯТЫЕ ЛЮДИ"
end

local function clearGallery()
	if state and state.Gallery then
		for _, r in ipairs(state.Gallery) do
			r.Model:Destroy()
		end
		state.Gallery = nil
	end
	refs.GalleryInfo.Visible = false
end

local function showGallery(kind)
	if not UnitModels.BuildAlly or not kind then
		return
	end
	if state.Gallery then
		clearGallery()
		buildModel(true)
		refs.GalleryButton.Text = galleryLabel()
		return
	end
	clearScene()
	state.Anim = nil
	local list = galleryList(kind)
	local n = #list
	local rigs, lines = {}, {}
	for i, it in ipairs(list) do
		local ok, rig = pcall(UnitModels.BuildAlly, it.Ally)
		if ok and rig then
			strip(rig.Model)
			local x = (i - (n + 1) / 2) * 3.4
			rig.Root.CFrame = CF(x, rig.HipHeight or 0, math.abs(x) * 0.25) * ANG(0, math.pi, 0)
			rig.Model.Parent = refs.World
			rigs[#rigs + 1] = rig
		end
		local ad = Config.Allies[it.Ally]
		lines[#lines + 1] = string.format("%d. %s — %s", i, ad and ad.Name or tostring(it.Ally), it.Text)
	end
	state.Gallery = rigs
	platform(0, n * 1.9 + 2, glowOf(Config.Units[state.Id]))
	state.Center = V3(0, 2.4, 0)
	state.BaseDist = n * 3.6 + 8
	state.Zoom, state.Dist, state.Yaw, state.Pitch = 1, state.BaseDist, rad(180), rad(10)
	updateCamera()
	local head = kind == "Rune" and "ПРОКЛЯТЫЕ НИТИ — проклятые люди:\n" or "ПРИЗЫВ — союзники идут по дороге навстречу врагам, HP = запас урона:\n"
	refs.GalleryInfo.Text = head .. table.concat(lines, "\n")
	refs.GalleryInfo.Visible = true
	refs.GalleryButton.Text = "← К ЮНИТУ"
end

local function exitGallery()
	if state.Gallery then
		clearGallery()
		buildModel(true)
		refs.GalleryButton.Text = galleryLabel()
	end
end

------------------------------------------------------------------------
-- ЭФФЕКТЫ СПОСОБНОСТЕЙ (только картинка)
------------------------------------------------------------------------
local function previewRing(y, r0, r1, color, time, delay)
	local rig = state and state.Rig
	task.delay(delay or 0, function()
		if not state or state.Rig ~= rig or not refs.World.Parent then
			return
		end
		local p = part({ Shape = Enum.PartType.Cylinder, Size = V3(0.15, 2 * r0, 2 * r0), CFrame = CF(0, y, 0) * ANG(0, 0, rad(90)), Color = color, Material = Enum.Material.Neon, Transparency = 0.2 })
		K.tween(p, time, { Size = V3(0.1, 2 * r1, 2 * r1), Transparency = 1 })
		task.delay(time + 0.1, function()
			p:Destroy()
		end)
	end)
end

local function previewStorm(on)
	local rig = state and state.Rig
	if not rig then
		return
	end
	rig.Storm = on
	for _, d in ipairs(rig.Model:GetDescendants()) do
		if d:IsA("BasePart") then
			local v = d:GetAttribute("StormFX")
			if type(v) == "number" then
				d.Transparency = on and v or 1
			end
		end
	end
end

local function previewFx(kind)
	local s = state.Rig and state.Rig.Scale or 1
	local col = POWER_FX[kind]
	if col then
		previewRing(0.08, 1, 7 * s, col, 0.8, 0.5)
		previewRing(0.12, 0.5, 4.5 * s, col:Lerp(WHITE, 0.3), 0.6, 0.6)
	elseif kind == "TimeBreak" then
		previewRing(0.05, 1, 6 * s, GOLD, 0.9, 0.5)
		previewRing(0.1, 0.5, 4 * s, ORANGE, 0.6, 0.55)
	elseif kind == "TimeHaste" then
		previewRing(0.1, 1, 9 * s, GOLD, 1.0, 0.4)
		previewRing(0.15, 1, 7 * s, ORANGE, 0.8, 0.5)
	elseif kind == "TimeStorm" then
		previewStorm(true)
		previewRing(0.1, 1, 8 * s, GOLD, 0.9, 1.3)
		previewRing(0.15, 0.5, 5 * s, ORANGE, 0.6, 1.35)
		local rig = state.Rig
		task.delay(4, function()
			if state and state.Rig == rig then
				previewStorm(false)
			end
		end)
	end
end

------------------------------------------------------------------------
-- ВВОД И КАДР
------------------------------------------------------------------------
local function disconnect()
	for _, c in ipairs(conns) do
		c:Disconnect()
	end
	table.clear(conns)
end

local function bindInput()
	local vf = refs.VF
	local dragging, last = false, nil
	local function zoom(f)
		state.Zoom = math.clamp(state.Zoom * f, ZOOM_MIN, ZOOM_MAX)
		state.Idle = 0
	end
	conns[#conns + 1] = vf.InputBegan:Connect(function(input)
		local t = input.UserInputType
		if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
			-- второй палец (щипок) не перехватывает вращение
			if dragging and t == Enum.UserInputType.Touch then
				return
			end
			dragging, last = input, input.Position
			state.Idle = 0
		end
	end)
	conns[#conns + 1] = vf.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseWheel then
			zoom(input.Position.Z > 0 and 0.88 or 1.14)
		end
	end)
	conns[#conns + 1] = UserInputService.InputChanged:Connect(function(input)
		if not dragging then
			return
		end
		local t = input.UserInputType
		local ok = t == Enum.UserInputType.MouseMovement or (t == Enum.UserInputType.Touch and (input == dragging or dragging.UserInputType ~= Enum.UserInputType.Touch))
		if ok then
			local d = input.Position - last
			last = input.Position
			state.Yaw -= d.X * 0.012
			state.Pitch = math.clamp(state.Pitch + d.Y * 0.008, rad(-15), rad(60))
			state.Idle = 0
		end
	end)
	conns[#conns + 1] = UserInputService.InputEnded:Connect(function(input)
		local t = input.UserInputType
		if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
	local lastScale = 1
	conns[#conns + 1] = UserInputService.TouchPinch:Connect(function(_, scale, _, st)
		if st == Enum.UserInputState.Begin then
			lastScale = 1
		elseif st == Enum.UserInputState.Change and scale > 0 then
			-- scale накопительный с начала жеста — берём приращение
			local f = scale / lastScale
			lastScale = scale
			zoom(1 / f)
		end
	end)
end

local function step(dt)
	if not state or not (state.Rig or state.Gallery) then
		return
	end
	local t = os.clock()
	state.Idle += dt
	if state.Idle > 2.5 then
		state.Yaw += dt * 0.45
	end
	state.Dist += (state.BaseDist * state.Zoom - state.Dist) * math.min(1, dt * 8)
	updateCamera()
	if state.Rig then
		Renderer.PreviewStep(state, t)
	end
	for i, f in ipairs(particles) do
		local s = f:GetAttribute("Seed")
		local a = (t * (0.08 + s * 0.06) + s) % 1
		f.Position = UDim2.new(0.12 + s * 0.76 + math.sin(t * 1.3 + i) * 0.02, 0, 0.95 - a * 0.9, 0)
		f.BackgroundTransparency = 0.15 + a * 0.85
	end
	for i, f in ipairs(sparks) do
		local s = f:GetAttribute("Seed")
		local a = (t * (0.12 + s * 0.1) + s) % 1
		f.Position = UDim2.new(0.08 + s * 0.84 + math.sin(t * 2 + i) * 0.03, 0, 1 - a, 0)
		f.BackgroundTransparency = 0.25 + a * 0.75
	end
	if refs.Pumpkin.Visible then
		local b = math.sin(t * 3)
		refs.Pumpkin.Position = UDim2.new(1, -54, 1, -64 - math.abs(b) * 10)
		refs.Pumpkin.Rotation = b * 8
	end
	if state.Gallery then
		for i, rig in ipairs(state.Gallery) do
			local sw = math.sin(t * 6 + i) * 28
			local m, b = rig.Motors, rig.Base
			if m and b then
				for _, j in ipairs({ { "RH", 1 }, { "LH", -1 }, { "RS", -0.7 }, { "LS", 0.7 } }) do
					local mo, bc = m[j[1]], b[j[1]]
					if mo and bc then
						mo.C0 = bc * ANG(rad(sw * j[2]), 0, 0)
					end
				end
			end
		end
	end
end

------------------------------------------------------------------------
-- ОКНО
------------------------------------------------------------------------
local function buildWindow()
	refs = {}
	local root = UI.Root
	dim = K.new("TextButton", { Parent = root, Name = "ViewerDim", Size = UDim2.fromScale(1, 1), BackgroundColor3 = BLACK, BackgroundTransparency = 0.45, Text = "", AutoButtonColor = false, Visible = false, ZIndex = 19, BorderSizePixel = 0 })
	dim.Activated:Connect(function()
		Viewer.Close()
	end)
	win = K.new("Frame", { Parent = root, Name = "UnitViewer", AnchorPoint = V2(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(1020, 620), BackgroundColor3 = rgb(10, 6, 18), BackgroundTransparency = 0.02, Visible = false, ZIndex = 20, BorderSizePixel = 0 })
	K.corner(14).Parent = win
	K.new("UIStroke", { Parent = win, Color = T.Accent, Thickness = 2 })
	K.new("UIGradient", { Parent = win, Rotation = 90, Color = ColorSequence.new(rgb(40, 22, 64), rgb(8, 4, 14)) })
	refs.Scale = K.new("UIScale", { Parent = win })
	-- сцена
	local scene = K.new("Frame", { Parent = win, Position = UDim2.fromOffset(16, 16), Size = UDim2.new(0, 560, 1, -32), BackgroundColor3 = rgb(14, 9, 24), ClipsDescendants = true, ZIndex = 21, BorderSizePixel = 0 })
	K.corner(12).Parent = scene
	refs.SceneStroke = K.new("UIStroke", { Parent = scene, Color = T.AccentDark, Thickness = 2 })
	K.new("UIGradient", { Parent = scene, Rotation = 90, Color = ColorSequence.new(rgb(34, 20, 56), rgb(6, 4, 12)) })
	refs.Scene = scene
	refs.Glows = {}
	for i = 1, 3 do
		local sz = 0.95 - i * 0.2
		local g = K.new("Frame", { Parent = scene, AnchorPoint = V2(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(sz, sz * 0.9), BackgroundColor3 = T.Accent, BackgroundTransparency = 0.8, BorderSizePixel = 0, ZIndex = 21 })
		K.new("UICorner", { Parent = g, CornerRadius = UDim.new(0.5, 0) })
		refs.Glows[i] = g
	end
	local vf = K.new("ViewportFrame", { Parent = scene, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Ambient = rgb(120, 105, 150), LightColor = rgb(255, 245, 255), LightDirection = V3(-0.5, -1, -0.7), ZIndex = 22, Active = true })
	refs.VF = vf
	refs.World = K.new("WorldModel", { Parent = vf })
	local cam = Instance.new("Camera")
	cam.FieldOfView = 32
	cam.Parent = vf
	vf.CurrentCamera = cam
	refs.Cam = cam
	K.label({ Parent = scene, AnchorPoint = V2(0.5, 1), Position = UDim2.new(0.5, 0, 1, -8), Size = UDim2.new(1, -20, 0, 18), Text = "Тяни мышью или пальцем — вращать  •  колесо / щипок — приблизить", TextColor3 = T.Dim, Font = Enum.Font.Gotham, ZIndex = 24 })
	local anim = K.new("Frame", { Parent = scene, Position = UDim2.fromOffset(10, 10), Size = UDim2.fromOffset(330, 34), BackgroundTransparency = 1, ZIndex = 24 })
	K.new("UIListLayout", { Parent = anim, FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder })
	for i, it in ipairs({ { "IDLE", "Idle" }, { "АТАКА", "Attack" }, { "ПОЗА", "Fidget" } }) do
		K.button({ Parent = anim, LayoutOrder = i, Size = UDim2.fromOffset(104, 32), Text = it[1], BackgroundColor3 = T.BG3, ZIndex = 25 }, function()
			Viewer.PlayAnim(it[2])
		end)
	end
	local ab = K.new("Frame", { Parent = scene, Position = UDim2.fromOffset(10, 48), Size = UDim2.fromOffset(420, 32), BackgroundTransparency = 1, ZIndex = 24 })
	K.new("UIListLayout", { Parent = ab, FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder })
	refs.AbilityRow = ab
	K.button({ Parent = scene, AnchorPoint = V2(1, 0), Position = UDim2.new(1, -10, 0, 10), Size = UDim2.fromOffset(40, 32), Text = "⟲", BackgroundColor3 = T.BG3, ZIndex = 25 }, function()
		if state then
			state.Yaw, state.Pitch, state.Zoom, state.Dist, state.Idle = rad(200), rad(12), 1, state.BaseDist, 0
		end
	end)
	refs.GalleryButton = K.button({ Parent = scene, AnchorPoint = V2(1, 0), Position = UDim2.new(1, -56, 0, 10), Size = UDim2.fromOffset(190, 32), Text = "", BackgroundColor3 = rgb(110, 40, 30), StrokeColor = rgb(255, 130, 40), Visible = false, ZIndex = 25 }, function()
		if state then
			showGallery(state.GalleryKind)
		end
	end)
	refs.GalleryInfo = K.label({
		Parent = scene, AnchorPoint = V2(0, 1), Position = UDim2.new(0, 10, 1, -30), Size = UDim2.new(1, -20, 0, 120), Text = "", Visible = false, ZIndex = 25,
		TextScaled = false, TextSize = 13, TextWrapped = true, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Bottom,
	})
	local pk = K.new("Frame", { Parent = scene, Position = UDim2.new(1, -54, 1, -64), Size = UDim2.fromOffset(40, 40), BackgroundTransparency = 1, Visible = false, ZIndex = 25 })
	K.icon("Pumpkin", pk, { Size = UDim2.fromScale(1, 1), ZIndex = 25 })
	refs.Pumpkin = pk
	local intro = K.new("Frame", { Parent = scene, Size = UDim2.fromScale(1, 1), BackgroundColor3 = BLACK, Visible = false, ZIndex = 30, BorderSizePixel = 0 })
	refs.IntroRing = K.new("Frame", { Parent = intro, AnchorPoint = V2(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.05, 0.05), BackgroundColor3 = GLOW.Secret, ZIndex = 31, BorderSizePixel = 0 })
	K.new("UICorner", { Parent = refs.IntroRing, CornerRadius = UDim.new(0.5, 0) })
	K.new("UIAspectRatioConstraint", { Parent = refs.IntroRing })
	refs.IntroText = K.label({ Parent = intro, AnchorPoint = V2(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, 0, 0, 60), Text = "", TextColor3 = GLOW.Secret, ZIndex = 32 })
	refs.Intro = intro
	-- информация
	K.button({ Parent = win, AnchorPoint = V2(1, 0), Position = UDim2.new(1, -14, 0, 14), Size = UDim2.fromOffset(40, 40), Text = "✕", BackgroundColor3 = rgb(120, 30, 50), ZIndex = 26 }, function()
		Viewer.Close()
	end)
	local info = K.new("Frame", { Parent = win, Position = UDim2.fromOffset(592, 16), Size = UDim2.new(1, -608, 1, -32), BackgroundTransparency = 1, ZIndex = 21 })
	local left, top = Enum.TextXAlignment.Left, Enum.TextYAlignment.Top
	refs.RarityBar = K.new("Frame", { Parent = info, Size = UDim2.fromOffset(6, 64), BorderSizePixel = 0, ZIndex = 22 })
	refs.Name = K.label({ Parent = info, Position = UDim2.fromOffset(16, 0), Size = UDim2.new(1, -70, 0, 40), Text = "", TextXAlignment = left, ZIndex = 22 })
	refs.Rarity = K.label({ Parent = info, Position = UDim2.fromOffset(16, 40), Size = UDim2.new(1, -70, 0, 24), Text = "", RichText = true, TextXAlignment = left, ZIndex = 22 })
	refs.Desc = K.label({ Parent = info, Position = UDim2.fromOffset(0, 72), Size = UDim2.new(1, 0, 0, 40), Text = "", TextScaled = false, TextSize = 14, TextWrapped = true, Font = Enum.Font.Gotham, TextColor3 = T.Dim, TextXAlignment = left, TextYAlignment = top, ZIndex = 22 })
	local tabs = K.new("Frame", { Parent = info, Position = UDim2.fromOffset(0, 118), Size = UDim2.new(1, 0, 0, 36), BackgroundTransparency = 1 })
	K.new("UIListLayout", { Parent = tabs, FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder })
	refs.Tabs = {}
	for i, name in ipairs(LEVEL_TABS) do
		refs.Tabs[i] = K.button({ Parent = tabs, LayoutOrder = i, Size = UDim2.new(0.2, -5, 1, 0), Text = name, BackgroundColor3 = T.BG3, ZIndex = 23 }, function()
			Viewer.SetLevel(i)
		end)
	end
	K.label({ Parent = info, Position = UDim2.fromOffset(0, 156), Size = UDim2.new(1, 0, 0, 16), Text = "Предпросмотр: уровень ничего не покупает и не улучшает", TextColor3 = T.Dim, Font = Enum.Font.Gotham, TextXAlignment = left, ZIndex = 22 })
	local stats = K.new("Frame", { Parent = info, Position = UDim2.fromOffset(0, 178), Size = UDim2.new(1, 0, 0, 180), BackgroundTransparency = 1 })
	K.new("UIListLayout", { Parent = stats, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder })
	refs.Stats = {}
	for i, name in ipairs({ "Урон", "Радиус", "Скорость атаки", "Установка", "Улучшение" }) do
		local row = K.new("Frame", { Parent = stats, LayoutOrder = i, Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = T.BG2, BackgroundTransparency = 0.2, BorderSizePixel = 0, ZIndex = 23 })
		K.corner(6).Parent = row
		K.label({ Parent = row, Position = UDim2.fromOffset(10, 4), Size = UDim2.new(0.5, -8, 1, -8), Text = name, TextColor3 = T.Dim, Font = Enum.Font.GothamBold, TextXAlignment = left, ZIndex = 24 })
		refs.Stats[i] = K.label({ Parent = row, Position = UDim2.new(0.5, 0, 0, 4), Size = UDim2.new(0.5, -10, 1, -8), Text = "", Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 24 })
	end
	local abox = K.new("Frame", { Parent = info, Position = UDim2.fromOffset(0, 364), Size = UDim2.new(1, 0, 0, 108), BackgroundColor3 = T.BG2, BackgroundTransparency = 0.2, BorderSizePixel = 0, ZIndex = 22 })
	K.corner(8).Parent = abox
	K.label({ Parent = abox, Position = UDim2.fromOffset(10, 6), Size = UDim2.new(1, -20, 0, 20), Text = "СПОСОБНОСТИ", TextColor3 = T.Accent, TextXAlignment = left, ZIndex = 23 })
	refs.Abilities = K.label({ Parent = abox, Position = UDim2.fromOffset(10, 30), Size = UDim2.new(1, -20, 1, -36), Text = "", TextScaled = false, TextSize = 15, TextWrapped = true, Font = Enum.Font.GothamBold, TextXAlignment = left, TextYAlignment = top, ZIndex = 23 })
	refs.Equip = K.button({ Parent = info, AnchorPoint = V2(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 54), Text = "", ZIndex = 23 }, function()
		if state and refs.Equip.Active and UI.ToggleEquip then
			UI.ToggleEquip(state.Id)
		end
	end)
end

-- окно помещается на экран (телефоны)
local function fitScale()
	local vs = UI.Root.AbsoluteSize
	if vs.X <= 0 or vs.Y <= 0 then
		return 1
	end
	return math.min(1, (vs.X - 16) / 1020, (vs.Y - 16) / 620)
end

function Viewer.Open(unitId, level)
	local def = Config.Units[unitId]
	local inv = ctx.Profile and ctx.Profile.Inventory
	if not def or not inv or (inv[unitId] or 0) <= 0 then
		return
	end
	if not win then
		buildWindow()
	end
	clearGallery()
	state = state or {}
	state.Id = unitId
	state.Level = math.clamp(level or 1, 1, 5)
	state.Idle = 0
	state.Rig = nil
	win.Visible = true
	dim.Visible = true
	local fit = fitScale()
	refs.Scale.Scale = 0.88 * fit
	K.tween(refs.Scale, 0.22, { Scale = fit }, Enum.EasingStyle.Back)
	buildModel(false)
	refreshInfo()
	applyRarityFx(true)
	local prof = ctx.Profile
	state.GalleryKind = def.Summon and "Summon" or ((prof.RuneSlots and prof.RuneSlots[unitId] == "CursedThreads") and "Rune" or nil)
	refs.GalleryButton.Visible = state.GalleryKind ~= nil
	refs.GalleryButton.Text = galleryLabel()
	for _, ch in ipairs(refs.AbilityRow:GetChildren()) do
		if ch:IsA("GuiButton") then
			ch:Destroy()
		end
	end
	for i, it in ipairs(def.PreviewAbilities or {}) do
		local kind = it[1]
		K.button({ Parent = refs.AbilityRow, LayoutOrder = i, Size = UDim2.fromOffset(132, 30), Text = it[2], BackgroundColor3 = rgb(90, 56, 20), StrokeColor = rgb(230, 170, 70), ZIndex = 25 }, function()
			Viewer.PlayAnim(kind)
		end)
	end
	disconnect()
	bindInput()
	conns[#conns + 1] = RunService.RenderStepped:Connect(step)
	FX.Sound("Click", 1, 1.1)
end

function Viewer.SetLevel(lv)
	if not state or not win then
		return
	end
	lv = math.clamp(lv or 1, 1, 5)
	state.Level = lv
	clearGallery()
	refs.GalleryButton.Text = galleryLabel()
	buildModel(true)
	refreshInfo()
	FX.Sound("Upgrade", 0.6, 0.9 + lv * 0.05)
end

function Viewer.PlayAnim(kind)
	if not state then
		return
	end
	exitGallery()
	if not state.Rig then
		return
	end
	state.Idle = 0
	if kind == "Idle" then
		state.Anim = nil
	elseif kind == "Attack" then
		Renderer.PreviewAttack(state, state.Id, state.Level)
	elseif kind == "Fidget" then
		Renderer.PreviewFidget(state, state.Id)
	else
		Renderer.PreviewAbility(state, kind)
		previewFx(kind)
	end
end

function Viewer.Refresh()
	if win and win.Visible and state then
		refreshInfo()
	end
end

function Viewer.IsOpen()
	return win ~= nil and win.Visible
end

function Viewer.Close()
	if not win then
		return
	end
	win.Visible = false
	dim.Visible = false
	disconnect()
	clearGallery()
	clearScene()
	clearList(sparks)
	clearList(particles)
	refs.Intro.Visible = false
	state = nil
end

function Viewer.Build(ui, c)
	UI, ctx = ui, c
	K, T, Config = ui.Kit, ui.Theme, c.Config
	UnitModels, Renderer, FX = c.UnitModels, c.Renderer, c.FX
	UserInputService.InputBegan:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.Escape and Viewer.IsOpen() then
			Viewer.Close()
		end
	end)
end

return Viewer
