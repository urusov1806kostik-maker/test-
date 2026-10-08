--!nocheck
-- ПОСЁЛОК: ЛИНИЯ ФРОНТА — клиент (HUD, стрельба, управление дронами, тепловизор, песочница)
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local Debris = game:GetService("Debris")

local plr = Players.LocalPlayer
local cam = workspace.CurrentCamera
local Net = RS:WaitForChild("Net")
local NetF = RS:WaitForChild("NetF")
local FX = workspace:WaitForChild("FX")
local BotsM = workspace:WaitForChild("Bots")
local VehM = workspace:WaitForChild("Vehicles")
local DroneF = workspace:WaitForChild("Drones")
local S = 3.5
local C3 = Color3.fromRGB
local rnd = Random.new()
local function rand(a, b) return a + rnd:NextNumber() * (b - a) end
local BASE0 = Vector3.new(-190 * S, 0, 0)

local controls = nil
task.spawn(function()
	local ok, pm = pcall(function() return require(plr:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule")) end)
	if ok and pm then controls = pm:GetControls() end
end)

plr.CameraMode = Enum.CameraMode.LockFirstPerson
plr.CameraMaxZoomDistance = 0.5

-- ================= GUI =================
local function new(cls, props, parent)
	local o = Instance.new(cls)
	for k, v in pairs(props or {}) do o[k] = v end
	if parent then o.Parent = parent end
	return o
end
local gui = new("ScreenGui", { Name = "HUD", ResetOnSpawn = false, IgnoreGuiInset = true, ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, plr:WaitForChild("PlayerGui"))
local function panel(props, parent)
	local f = new("Frame", props, parent or gui)
	f.BackgroundColor3 = C3(12, 16, 20); f.BackgroundTransparency = props.BackgroundTransparency or 0.25; f.BorderSizePixel = 0
	new("UICorner", { CornerRadius = UDim.new(0, 8) }, f)
	return f
end
local function label(props, parent)
	local l = new("TextLabel", props, parent)
	l.BackgroundTransparency = 1
	if not props.Font then l.Font = Enum.Font.GothamMedium end
	if not props.TextColor3 then l.TextColor3 = C3(235, 235, 235) end
	return l
end
local function button(text, props, parent, cb)
	local b = new("TextButton", props, parent)
	b.Text = text; b.Font = Enum.Font.GothamBold; b.TextColor3 = C3(255, 255, 255); b.BackgroundColor3 = props.BackgroundColor3 or C3(60, 90, 46); b.AutoButtonColor = true; b.BorderSizePixel = 0
	new("UICorner", { CornerRadius = UDim.new(0, 6) }, b)
	if cb then b.MouseButton1Click:Connect(cb) end
	return b
end

-- crosshair
local cross = new("Frame", { Size = UDim2.fromOffset(24, 24), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1 }, gui)
for _, d in ipairs({ { 11, 0, 2, 7 }, { 11, 17, 2, 7 }, { 0, 11, 7, 2 }, { 17, 11, 7, 2 } }) do
	new("Frame", { Position = UDim2.fromOffset(d[1], d[2]), Size = UDim2.fromOffset(d[3], d[4]), BackgroundColor3 = C3(255, 255, 255), BorderSizePixel = 0, BackgroundTransparency = 0.15 }, cross)
end
local hitm = label({ Text = "✕", TextSize = 34, Size = UDim2.fromOffset(40, 40), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), TextTransparency = 1, Font = Enum.Font.GothamBold }, gui)
local dmgF = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C3(200, 0, 0), BackgroundTransparency = 1, BorderSizePixel = 0 }, gui)

-- top bar
local top = panel({ Size = UDim2.fromOffset(300, 50), Position = UDim2.new(0.5, 0, 0, 12), AnchorPoint = Vector2.new(0.5, 0) })
local tk0 = label({ Text = "300", TextSize = 20, Font = Enum.Font.GothamBold, TextColor3 = C3(110, 170, 255), Size = UDim2.fromOffset(60, 50), Position = UDim2.fromOffset(6, 0) }, top)
local tk1 = label({ Text = "300", TextSize = 20, Font = Enum.Font.GothamBold, TextColor3 = C3(255, 110, 110), Size = UDim2.fromOffset(60, 50), Position = UDim2.new(1, -66, 0, 0) }, top)
local ptEls = {}
for i, n in ipairs({ "A", "B", "C" }) do
	local c = new("TextLabel", { Text = n, Font = Enum.Font.GothamBlack, TextSize = 18, TextColor3 = C3(255, 255, 255), Size = UDim2.fromOffset(36, 36), Position = UDim2.fromOffset(78 + (i - 1) * 50, 7), BackgroundColor3 = C3(100, 100, 100), BorderSizePixel = 0 }, top)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, c)
	local st = new("UIStroke", { Thickness = 2, Color = C3(255, 255, 255) }, c)
	ptEls[n] = { c, st }
end

-- bottom left / right
local bl = panel({ Size = UDim2.fromOffset(260, 86), Position = UDim2.new(0, 20, 1, -106) })
local hpL = label({ Text = "ЗДОРОВЬЕ 100", TextSize = 16, Font = Enum.Font.GothamBold, Size = UDim2.new(1, -20, 0, 24), Position = UDim2.fromOffset(10, 6), TextXAlignment = Enum.TextXAlignment.Left }, bl)
local hpBg = new("Frame", { Size = UDim2.new(1, -20, 0, 10), Position = UDim2.fromOffset(10, 34), BackgroundColor3 = C3(60, 60, 60), BorderSizePixel = 0 }, bl)
new("UICorner", { CornerRadius = UDim.new(1, 0) }, hpBg)
local hpBar = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C3(120, 210, 80), BorderSizePixel = 0 }, hpBg)
new("UICorner", { CornerRadius = UDim.new(1, 0) }, hpBar)
local itemsL = label({ Text = "", TextSize = 14, Size = UDim2.new(1, -20, 0, 24), Position = UDim2.fromOffset(10, 52), TextXAlignment = Enum.TextXAlignment.Left, RichText = true }, bl)
local br = panel({ Size = UDim2.fromOffset(220, 86), Position = UDim2.new(1, -240, 1, -106) })
local wL = label({ Text = "АК-74", TextSize = 15, Size = UDim2.new(1, -20, 0, 24), Position = UDim2.fromOffset(10, 6), TextXAlignment = Enum.TextXAlignment.Right }, br)
local ammoL = label({ Text = "30 / 210", TextSize = 34, Font = Enum.Font.GothamBold, Size = UDim2.new(1, -20, 0, 46), Position = UDim2.fromOffset(10, 32), TextXAlignment = Enum.TextXAlignment.Right, RichText = true }, br)

local feedF = new("Frame", { Size = UDim2.fromOffset(380, 200), Position = UDim2.new(1, -20, 0, 80), AnchorPoint = Vector2.new(1, 0), BackgroundTransparency = 1 }, gui)
new("UIListLayout", { HorizontalAlignment = Enum.HorizontalAlignment.Right, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 3) }, feedF)
local feedN = 0
local function feed(txt, col)
	feedN += 1
	local l = label({ Text = " " .. txt .. " ", RichText = true, TextSize = 14, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 22), BackgroundTransparency = 0.5, BackgroundColor3 = C3(0, 0, 0), LayoutOrder = -feedN, TextColor3 = col and Color3.fromHex(col) or C3(255, 255, 255) }, feedF)
	l.BackgroundTransparency = 0.5
	local kids = feedF:GetChildren()
	local labels = {}
	for _, k in ipairs(kids) do if k:IsA("TextLabel") then table.insert(labels, k) end end
	if #labels > 6 then
		table.sort(labels, function(a, b) return a.LayoutOrder > b.LayoutOrder end)
		labels[1]:Destroy()
	end
	Debris:AddItem(l, 7)
end
local msgL = label({ Text = "", TextSize = 24, Font = Enum.Font.GothamBold, Size = UDim2.new(1, 0, 0, 40), Position = UDim2.fromScale(0, 0.22), TextStrokeTransparency = 0.4 }, gui)
local msgT = 0
local function msg(t, d) msgL.Text = t; msgT = d or 2.5 end
local hintL = label({ Text = "", TextSize = 14, Size = UDim2.new(1, 0, 0, 20), Position = UDim2.new(0, 0, 1, -28), TextTransparency = 0.25, TextStrokeTransparency = 0.5 }, gui)
local marksF = new("Folder", { Name = "Marks" }, gui)

-- FPV overlay
local fpv = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false }, gui)
for y = 0, 59 do new("Frame", { Size = UDim2.new(1, 0, 0, 1), Position = UDim2.fromScale(0, y / 60), BackgroundColor3 = C3(0, 0, 0), BackgroundTransparency = 0.82, BorderSizePixel = 0 }, fpv) end
local noise = {}
for i = 1, 90 do noise[i] = new("Frame", { Size = UDim2.fromOffset(6, 3), BorderSizePixel = 0, BackgroundColor3 = C3(255, 255, 255) }, fpv) end
local glitch = new("Frame", { Size = UDim2.new(1, 0, 0, 6), BackgroundColor3 = C3(255, 255, 255), BackgroundTransparency = 0.6, BorderSizePixel = 0, Visible = false }, fpv)
local fpvTitle = label({ Text = "● FPV CAMERA", RichText = true, TextSize = 22, Font = Enum.Font.Code, Size = UDim2.fromOffset(400, 30), Position = UDim2.fromOffset(24, 20), TextXAlignment = Enum.TextXAlignment.Left, TextStrokeTransparency = 0.3 }, fpv)
local fpvStats = label({ Text = "", TextSize = 17, Font = Enum.Font.Code, Size = UDim2.fromOffset(400, 150), Position = UDim2.new(0, 24, 1, -170), TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Bottom, TextColor3 = C3(200, 255, 230), TextStrokeTransparency = 0.3 }, fpv)
local fpvRight = label({ Text = "", TextSize = 16, Font = Enum.Font.Code, Size = UDim2.fromOffset(420, 120), Position = UDim2.new(1, -444, 0, 20), TextXAlignment = Enum.TextXAlignment.Right, TextYAlignment = Enum.TextYAlignment.Top, TextColor3 = C3(200, 255, 230), TextStrokeTransparency = 0.3, RichText = true }, fpv)
local fpvWarn = label({ Text = "", TextSize = 30, Font = Enum.Font.Code, Size = UDim2.new(1, 0, 0, 40), Position = UDim2.fromScale(0, 0.3), TextColor3 = C3(255, 70, 70), TextStrokeTransparency = 0.2 }, fpv)
local fpvCross = new("Frame", { Size = UDim2.fromOffset(64, 64), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1 }, fpv)
local fcCorner = new("UICorner", { CornerRadius = UDim.new(1, 0) }, fpvCross)
new("UIStroke", { Thickness = 2, Color = C3(255, 255, 255), Transparency = 0.25 }, fpvCross)
local dot = new("Frame", { Size = UDim2.fromOffset(6, 6), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = C3(255, 50, 50), BorderSizePixel = 0 }, fpvCross)
new("UICorner", { CornerRadius = UDim.new(1, 0) }, dot)
local horizon = new("Frame", { Size = UDim2.fromOffset(260, 2), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = C3(150, 255, 150), BackgroundTransparency = 0.4, BorderSizePixel = 0 }, fpv)

-- drone menu
local dsel = "fpv"
local dmenu = panel({ Size = UDim2.fromOffset(720, 190), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Visible = false })
label({ Text = "ВЫБОР ДРОНА — клавиши 1/2/3, R — закрыть, E — запуск", TextSize = 18, Font = Enum.Font.GothamBold, Size = UDim2.new(1, 0, 0, 36), Position = UDim2.fromOffset(0, 6) }, dmenu)
local dcards = {}
local dinfo = {
	{ "fpv", "1. FPV-камикадзе", "Быстрый одноразовый дрон с игровым зарядом.\nЛКМ — подрыв, столкновение — взрыв." },
	{ "scout", "2. Разведчик-квадро", "Зависание, зум, тепловизор (V).\nЛКМ — отметить цели для союзников." },
	{ "uav", "3. Разведывательный БПЛА", "Самолёт: скорость, дальность,\nавтообнаружение, тепловизор." },
}
local function refreshD() for k, c in pairs(dcards) do c.BackgroundColor3 = (k == dsel) and C3(80, 130, 60) or C3(45, 50, 55) end end
for i, d in ipairs(dinfo) do
	local b = button(d[2] .. "\n\n" .. d[3], { Size = UDim2.fromOffset(220, 130), Position = UDim2.fromOffset(15 + (i - 1) * 235, 48), TextSize = 13, TextWrapped = true }, dmenu, function() dsel = d[1]; refreshD() end)
	dcards[d[1]] = b
end
refreshD()

-- end screen
local endF = panel({ Size = UDim2.fromOffset(420, 160), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Visible = false, BackgroundTransparency = 0.1 })
local endT = label({ Text = "", TextSize = 40, Font = Enum.Font.GothamBlack, Size = UDim2.new(1, 0, 0, 70), Position = UDim2.fromOffset(0, 20) }, endF)
local endS = label({ Text = "", TextSize = 16, Size = UDim2.new(1, 0, 0, 40), Position = UDim2.fromOffset(0, 95) }, endF)

-- ================= STATE =================
local WEAP = { { name = "АК-74", mag = 30, reserve = 210, rate = 0.1, spread = 0.012, recoil = 0.012, reload = 2.2 }, { name = "ПКМ", mag = 100, reserve = 300, rate = 0.085, spread = 0.022, recoil = 0.016, reload = 4.5 } }
local wi = 1
local ammo = { 30, 100 }
local reserve = { 210, 300 }
local reloadT = 0
local nextFire = 0
local mouseDown = false
local recoil = 0
local shake = 0
local fpvStock, fpvRegen = 8, 0
local dr = nil -- active drone
local viewing = false
local thermal = false
local sandboxEdit = false
local edCam = Vector3.new(0, 140 * S / 3.5 * 1, 40)

local function char() return plr.Character end
local function hum() local c = char(); return c and c:FindFirstChildOfClass("Humanoid") end
local function root() local c = char(); return c and c:FindFirstChild("HumanoidRootPart") end
local function alive() local h = hum(); return h and h.Health > 0 end

-- thermal
local cc = new("ColorCorrectionEffect", { Enabled = false, Saturation = -1, Contrast = 0.45, Brightness = -0.18, TintColor = C3(230, 230, 230) }, Lighting)
local thermBlur = new("BlurEffect", { Enabled = false, Size = 2 }, Lighting)
local function hl(adornee)
	return new("Highlight", { Enabled = false, Adornee = adornee, FillColor = C3(255, 255, 255), FillTransparency = 0, OutlineTransparency = 1, DepthMode = Enum.HighlightDepthMode.Occluded }, FX)
end
local hlBots, hlVeh, hlDr = hl(BotsM), hl(VehM), hl(DroneF)
local hlPlayers = {}
local function setThermal(on)
	thermal = on
	cc.Enabled = on; thermBlur.Enabled = on
	hlBots.Enabled = on; hlVeh.Enabled = on; hlDr.Enabled = on
	for _, h in pairs(hlPlayers) do h:Destroy() end
	hlPlayers = {}
	if on then
		for _, p in ipairs(Players:GetPlayers()) do if p.Character then local h = hl(p.Character); h.Enabled = true; table.insert(hlPlayers, h) end end
	end
end

-- ================= EFFECTS =================
local function emitAt(pos, color, size, n, speed, life, light, tex)
	local p = new("Part", { Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, Transparency = 1, Size = Vector3.new(0.2, 0.2, 0.2), CFrame = CFrame.new(pos) }, FX)
	local e = new("ParticleEmitter", {
		Color = ColorSequence.new(color), Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size), NumberSequenceKeypoint.new(1, size * 2.2) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) }),
		Lifetime = NumberRange.new(life * 0.6, life), Speed = NumberRange.new(speed * 0.3, speed), SpreadAngle = Vector2.new(180, 180), Rate = 0,
		LightEmission = light or 0, Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-40, 40), Acceleration = Vector3.new(0, light and light > 0.5 and 2 or 3, 0),
		Texture = tex or "rbxasset://textures/particles/smoke_main.dds", Drag = 2,
	}, p)
	e:Emit(n)
	Debris:AddItem(p, life + 0.2)
end
local function tracer(a, b, col)
	local d = (b - a).Magnitude
	if d < 1 then return end
	local p = new("Part", { Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, Material = Enum.Material.Neon, Color = col or C3(255, 210, 120), Size = Vector3.new(0.12, 0.12, d), CFrame = CFrame.lookAt(a, b) * CFrame.new(0, 0, -d / 2), CastShadow = false }, FX)
	Debris:AddItem(p, 0.05)
end
local function flash(pos, br, range, t)
	local p = new("Part", { Anchored = true, CanCollide = false, CanQuery = false, Transparency = 1, Size = Vector3.new(0.2, 0.2, 0.2), CFrame = CFrame.new(pos) }, FX)
	new("PointLight", { Brightness = br, Range = range, Color = C3(255, 180, 90) }, p)
	Debris:AddItem(p, t)
end
local function sound(id, pos, vol, pitch)
	local p = new("Part", { Anchored = true, CanCollide = false, CanQuery = false, Transparency = 1, Size = Vector3.new(0.2, 0.2, 0.2), CFrame = CFrame.new(pos) }, FX)
	local s = new("Sound", { SoundId = id, Volume = vol or 1, PlaybackSpeed = pitch or 1, RollOffMaxDistance = 600, RollOffMinDistance = 15 }, p)
	s:Play()
	Debris:AddItem(p, 4)
end
Net.OnClientEvent:Connect(function(cmd, a, b, c)
	if cmd == "tr" then
		if c ~= plr and rnd:NextNumber() < 0.6 then tracer(a, b) end
		if c ~= plr and (a - cam.CFrame.Position).Magnitude < 250 and rnd:NextNumber() < 0.5 then sound("rbxasset://sounds/paintball.wav", a, 0.5, rand(0.5, 0.7)) end
	elseif cmd == "fx" then
		if a == "blood" then emitAt(b, C3(110, 10, 10), 0.6, 5, 6, 0.5)
		elseif a == "spark" then emitAt(b, C3(255, 200, 120), 0.25, 8, 25, 0.3, 1, "rbxasset://textures/particles/sparkles_main.dds")
		elseif a == "impact" then emitAt(b, C3(150, 140, 120), 0.5, 3, 4, 0.6)
		elseif a == "glass" then emitAt(b, C3(200, 230, 255), 0.2, 14, 15, 0.8, 0.6, "rbxasset://textures/particles/sparkles_main.dds"); sound("rbxasset://sounds/snap.mp3", b, 0.8, 1.6)
		elseif a == "dust" then emitAt(b, C3(140, 125, 100), 4, 8, 10, 2.5)
		elseif a == "boom" or a == "smallboom" then
			local big = a == "boom"
			emitAt(b, C3(255, 170, 60), big and 5 or 2, big and 18 or 6, big and 30 or 12, 0.6, 1)
			emitAt(b, C3(60, 58, 55), big and 7 or 3, big and 16 or 5, big and 18 or 8, big and 4 or 2)
			emitAt(b, C3(130, 115, 90), big and 6 or 2, big and 10 or 3, big and 25 or 10, 2.5)
			flash(b, big and 8 or 3, big and 60 or 20, 0.15)
			if not big then sound("rbxasset://sounds/collide.wav", b, 0.6, 0.6) end
			local d = (cam.CFrame.Position - b).Magnitude
			if d < 140 then shake = math.max(shake, (1 - d / 140) * (big and 1 or 0.3)) end
		end
	elseif cmd == "hit" then
		hitm.TextTransparency = 0; hitm.TextColor3 = a and C3(255, 60, 60) or C3(255, 255, 255)
		task.delay(a and 0.3 or 0.12, function() hitm.TextTransparency = 1 end)
	elseif cmd == "feed" then
		feed(a, b)
	elseif cmd == "end" then
		endF.Visible = true
		local myT = plr.Team and plr.Team.Name == "Южные" and 1 or 0
		endT.Text = (a == myT) and "ПОБЕДА" or "ПОРАЖЕНИЕ"
		endS.Text = "Уничтожено вами: " .. tostring(plr:GetAttribute("Kills") or 0)
	elseif cmd == "scanres" then
		if a > 0 then msg("Обнаружено целей: " .. a .. " — отметки переданы союзникам", 2)
		elseif b then msg("Целей в прицеле нет", 1.2) end
	elseif cmd == "marks" then
		local keep = {}
		for _, m in ipairs(a or {}) do keep[m] = true end
		for _, bb in ipairs(marksF:GetChildren()) do
			local m = bb:GetAttribute("M") and bb.Adornee and bb.Adornee.Parent
			if not bb.Adornee or not bb.Adornee.Parent or not keep[bb.Adornee:FindFirstAncestorOfClass("Model")] then bb:Destroy() end
		end
		for m in pairs(keep) do
			if m.Parent then
				local part = m.PrimaryPart or m:FindFirstChild("HumanoidRootPart") or m:FindFirstChildWhichIsA("BasePart")
				local exists = false
				for _, bb in ipairs(marksF:GetChildren()) do if bb.Adornee == part then exists = true end end
				if part and not exists then
					local bb = new("BillboardGui", { Adornee = part, AlwaysOnTop = true, Size = UDim2.fromOffset(60, 40), StudsOffset = Vector3.new(0, 6, 0), MaxDistance = 3000 }, marksF)
					bb:SetAttribute("M", true)
					label({ Name = "T", Text = "◆", TextSize = 14, Font = Enum.Font.GothamBold, TextColor3 = C3(255, 60, 60), Size = UDim2.fromScale(1, 1), TextStrokeTransparency = 0.2 }, bb)
				end
			end
		end
	end
end)

-- ================= MODE MENU =================
local menu = panel({ Size = UDim2.fromOffset(760, 330), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 0.1, Visible = false })
label({ Text = "ПОСЁЛОК: ЛИНИЯ ФРОНТА", TextSize = 34, Font = Enum.Font.GothamBlack, Size = UDim2.new(1, 0, 0, 50), Position = UDim2.fromOffset(0, 12) }, menu)
label({ Text = "Северные (синие повязки) против Южных (красные). Выберите режим:", TextSize = 15, Size = UDim2.new(1, 0, 0, 24), Position = UDim2.fromOffset(0, 60), TextTransparency = 0.2 }, menu)
local modes = { { "free", "Свободный бой", "Две армии бьются\nза точки A, B, C" }, { "defense", "Оборона посёлка", "Удержите точки\nпротив штурма" }, { "sandbox", "Песочница", "Расставьте войска\nи запустите бой" } }
for i, m in ipairs(modes) do
	local b = button(m[2] .. "\n\n" .. m[3], { Size = UDim2.fromOffset(230, 120), Position = UDim2.fromOffset(17 + (i - 1) * 245, 96), TextSize = 16, TextWrapped = true, Modal = true }, menu, function()
		Net:FireServer("mode", m[1]); menu.Visible = false
	end)
end
label({ Text = "Солдат: WASD, Shift бег, C присед, ЛКМ огонь, T перезарядка, 1/2 оружие, H аптечка\nДроны: R меню, E запуск/выход, WASD полёт, мышь — курс, Space/C выше/ниже, Shift ускорение\nFPV: ЛКМ подрыв · Разведка: ЛКМ отметка, V тепловизор, колесо зум, B возврат",
	TextSize = 13, Size = UDim2.new(1, -20, 0, 70), Position = UDim2.fromOffset(10, 230), TextTransparency = 0.25, TextWrapped = true }, menu)
local function refreshMenu() menu.Visible = RS:GetAttribute("Mode") == "" end
RS:GetAttributeChangedSignal("Mode"):Connect(refreshMenu)
refreshMenu()

-- ================= SANDBOX =================
local sbPanel = panel({ Size = UDim2.fromOffset(250, 420), Position = UDim2.fromOffset(16, 70), Visible = false })
label({ Text = "ПЕСОЧНИЦА\nЛКМ — поставить, WASD — камера, колесо — высота", TextSize = 13, TextWrapped = true, Size = UDim2.new(1, -16, 0, 50), Position = UDim2.fromOffset(8, 4) }, sbPanel)
local sbSel = { "s", 0 }
local sbBtns = {}
local sbList = { { "Солдат (Северные)", "s", 0 }, { "Солдат (Южные)", "s", 1 }, { "Броневик (Северные)", "jeep", 0 }, { "Броневик (Южные)", "jeep", 1 }, { "БТР (Северные)", "btr", 0 }, { "БТР (Южные)", "btr", 1 }, { "Грузовик (Южные)", "truck", 1 }, { "Вражеский FPV", "drone", 1 } }
for i, u in ipairs(sbList) do
	local b
	b = button(u[1], { Size = UDim2.new(1, -16, 0, 34), Position = UDim2.fromOffset(8, 56 + (i - 1) * 38), TextSize = 14, Modal = true, BackgroundColor3 = C3(50, 55, 60) }, sbPanel, function()
		sbSel = { u[2], u[3] }
		for _, x in ipairs(sbBtns) do x.BackgroundColor3 = C3(50, 55, 60) end
		b.BackgroundColor3 = C3(80, 130, 60)
	end)
	table.insert(sbBtns, b)
end
sbBtns[1].BackgroundColor3 = C3(80, 130, 60)
button("▶ НАЧАТЬ БОЙ", { Size = UDim2.new(1, -16, 0, 40), Position = UDim2.new(0, 8, 1, -48), TextSize = 16, BackgroundColor3 = C3(170, 50, 50) }, sbPanel, function()
	Net:FireServer("sbstart")
end)
local function updSandbox()
	local want = RS:GetAttribute("Mode") == "sandbox" and not RS:GetAttribute("SB")
	if want ~= sandboxEdit then
		sandboxEdit = want
		sbPanel.Visible = want
		if want then
			if controls then controls:Disable() end
			cam.CameraType = Enum.CameraType.Scriptable
			edCam = Vector3.new(0, 120, 120)
		else
			if controls then controls:Enable() end
			cam.CameraType = Enum.CameraType.Custom
			local h = hum(); if h then cam.CameraSubject = h end
		end
	end
end
RS:GetAttributeChangedSignal("Mode"):Connect(updSandbox)
RS:GetAttributeChangedSignal("SB"):Connect(updSandbox)

-- ================= DRONES =================
local DDEF = {
	fpv = { name = "FPV CAMERA", max = 30 * S, boost = 46 * S, acc = 30 * S, vmax = 12 * S, battery = 150, range = 380 * S, fov = 95 },
	scout = { name = "SCOUT CAM", max = 12 * S, boost = 18 * S, acc = 14 * S, vmax = 6 * S, battery = 300, range = 480 * S, fov = 60 },
	uav = { name = "UAV GIMBAL CAM", fixed = true, battery = 480, range = 1000 * S, fov = 60 },
}
local function enterView()
	if not dr then return end
	viewing = true
	if controls then controls:Disable() end
	cam.CameraType = Enum.CameraType.Scriptable
	cam.FieldOfView = DDEF[dr.kind].fov / dr.zoom
	fpv.Visible = true; cross.Visible = false; bl.Visible = false; br.Visible = false
	fpvTitle.Text = '<font color="#ff3333">●</font> ' .. DDEF[dr.kind].name
	fcCorner.CornerRadius = dr.kind == "fpv" and UDim.new(1, 0) or UDim.new(0, 0)
end
local function exitView()
	viewing = false
	if thermal then setThermal(false) end
	if controls then controls:Enable() end
	cam.CameraType = Enum.CameraType.Custom
	local h = hum(); if h then cam.CameraSubject = h end
	cam.FieldOfView = 70
	fpv.Visible = false; cross.Visible = true; bl.Visible = true; br.Visible = true
	UIS.MouseBehavior = Enum.MouseBehavior.Default
end
local function droneGone(t)
	dr = nil
	if viewing then exitView() end
	if t then msg(t, 2.5) end
end
local function launch()
	if dsel == "fpv" and fpvStock <= 0 then msg("Нет FPV-дронов (пополнение каждые 35 с)", 2); return end
	local r = root(); if not r then return end
	local m = NetF:InvokeServer("launch", dsel)
	if not m then return end
	local body = m.PrimaryPart or m:WaitForChild("Body", 3)
	if not body then return end
	local _, ry = r.CFrame:ToOrientation()
	dr = { model = m, body = body, kind = dsel, vel = Vector3.zero, yaw = select(2, cam.CFrame:ToOrientation()), camPitch = dsel == "uav" and -0.6 or -0.1, camYaw = 0, pitch = 0, roll = 0,
		battery = 1, t = 0, signal = 1, lost = false, returning = false, zoom = 1, speed = 26 * S, bank = 0 }
	if dsel == "fpv" then fpvStock -= 1; dr.vel = Vector3.new(0, 4 * S, 0) end
	msg(dsel == "fpv" and "FPV запущен" or dsel == "scout" and "Разведчик запущен" or "БПЛА запущен", 1.5)
	enterView()
end
local function detonate()
	if not dr or dr.kind ~= "fpv" then return end
	Net:FireServer("detonate")
	droneGone("Подрыв — дрон уничтожен")
end
local function scan(manual)
	if not dr or dr.kind == "fpv" then return end
	local fovR = math.rad(cam.FieldOfView)
	local cosA = math.cos(fovR * (manual and 0.12 or 0.5))
	local maxD = dr.kind == "uav" and 330 or 220
	if not thermal and not manual then maxD = 120 end
	Net:FireServer("scan", cam.CFrame.Position, cam.CFrame.LookVector, { cosA, maxD, manual })
end

local rp = RaycastParams.new()
rp.FilterType = Enum.RaycastFilterType.Exclude
local function droneUpdate(dt)
	if not dr then return end
	if not dr.model.Parent or not dr.body.Parent then droneGone("Связь с дроном потеряна"); return end
	local d = DDEF[dr.kind]
	local r = root()
	dr.t += dt
	local boost = UIS:IsKeyDown(Enum.KeyCode.LeftShift)
	local ctl = viewing and not dr.lost and not dr.returning
	dr.battery -= dt / d.battery * ((boost and ctl) and 1.8 or 1)
	if dr.battery <= 0 then dr.lost = true end
	if r then
		local hd = Vector3.new(dr.body.Position.X - r.Position.X, 0, dr.body.Position.Z - r.Position.Z).Magnitude
		local sg = 1 - math.clamp((hd - d.range * 0.35) / (d.range * 0.65), 0, 1)
		if dr.body.Position.Y < 10 * S and hd > 40 * S then
			rp.FilterDescendantsInstances = { FX, dr.model, char() }
			if workspace:Raycast(r.Position + Vector3.new(0, 3, 0), dr.body.Position - r.Position, rp) then sg *= 0.55 end
		end
		dr.signal += (sg - dr.signal) * math.min(1, dt * 2)
		if dr.signal < 0.04 then dr.lost = true end
	end
	local pos = dr.body.Position
	if d.fixed then
		local turn, climb = 0, 0
		if ctl then
			if UIS:IsKeyDown(Enum.KeyCode.W) then dr.speed = math.min(42 * S, dr.speed + 12 * S * dt) end
			if UIS:IsKeyDown(Enum.KeyCode.S) then dr.speed = math.max(16 * S, dr.speed - 12 * S * dt) end
			turn = (UIS:IsKeyDown(Enum.KeyCode.A) and 1 or 0) - (UIS:IsKeyDown(Enum.KeyCode.D) and 1 or 0)
			climb = (UIS:IsKeyDown(Enum.KeyCode.Space) and 1 or 0) - ((UIS:IsKeyDown(Enum.KeyCode.LeftControl) or UIS:IsKeyDown(Enum.KeyCode.C)) and 1 or 0)
		elseif dr.returning and r then
			local a = math.atan2(-(r.Position.X - pos.X), -(r.Position.Z - pos.Z))
			local dy = (a - dr.yaw + math.pi) % (2 * math.pi) - math.pi
			turn = math.clamp(dy * 2, -1, 1); climb = math.clamp((40 * S - pos.Y) / 30, -1, 1)
			if Vector3.new(r.Position.X - pos.X, 0, r.Position.Z - pos.Z).Magnitude < 25 * S then Net:FireServer("recover"); droneGone("БПЛА вернулся на базу"); return end
		else
			turn = 0.35; climb = math.clamp((60 * S - pos.Y) / 30, -1, 1)
		end
		if dr.lost then climb = -1.5; turn = 0.2 end
		dr.yaw += turn * 0.55 * dt
		dr.bank += (turn * 0.5 - dr.bank) * math.min(1, dt * 3)
		dr.vel = Vector3.new(-math.sin(dr.yaw) * dr.speed, climb * 8 * S, -math.cos(dr.yaw) * dr.speed)
		if not dr.lost and pos.Y < 20 * S then dr.vel += Vector3.new(0, (20 * S - pos.Y), 0) end
		dr.pitch = -climb * 0.15; dr.roll = -dr.bank
	else
		local want = Vector3.zero
		if ctl then
			local mx = boost and d.boost or d.max
			local f = (UIS:IsKeyDown(Enum.KeyCode.W) and 1 or 0) - (UIS:IsKeyDown(Enum.KeyCode.S) and 1 or 0)
			local s = (UIS:IsKeyDown(Enum.KeyCode.D) and 1 or 0) - (UIS:IsKeyDown(Enum.KeyCode.A) and 1 or 0)
			local u = (UIS:IsKeyDown(Enum.KeyCode.Space) and 1 or 0) - ((UIS:IsKeyDown(Enum.KeyCode.LeftControl) or UIS:IsKeyDown(Enum.KeyCode.C)) and 1 or 0)
			local cp = dr.kind == "fpv" and dr.camPitch or 0
			local fw = Vector3.new(-math.sin(dr.yaw) * math.cos(cp), math.sin(cp), -math.cos(dr.yaw) * math.cos(cp))
			local rt = Vector3.new(math.cos(dr.yaw), 0, -math.sin(dr.yaw))
			want = fw * f * mx + rt * s * mx * 0.7 + Vector3.new(0, u * d.vmax, 0)
		elseif dr.lost then
			want = Vector3.new(dr.vel.X * 0.98, -30 * S, dr.vel.Z * 0.98)
		elseif dr.returning and r then
			local dx, dz = r.Position.X - pos.X, r.Position.Z - pos.Z
			local hd = math.sqrt(dx * dx + dz * dz)
			local ty = hd > 4 * S and r.Position.Y + 20 * S or r.Position.Y + 2
			local sp = math.min(d.max, hd)
			want = Vector3.new(dx / math.max(hd, 0.01) * sp, math.clamp(ty - pos.Y, -4 * S, 6 * S), dz / math.max(hd, 0.01) * sp)
			dr.yaw = math.atan2(-dx, -dz)
			if hd < 5 * S and pos.Y < r.Position.Y + 6 then Net:FireServer("recover"); droneGone("Дрон возвращён"); return end
		end
		local dv = want - dr.vel
		local acc = (dr.lost and 20 * S or d.acc) * dt
		if dv.Magnitude > acc then dv = dv.Unit * acc end
		dr.vel += dv
		local fwdv = -math.sin(dr.yaw) * dr.vel.X - math.cos(dr.yaw) * dr.vel.Z
		local sidev = math.cos(dr.yaw) * dr.vel.X - math.sin(dr.yaw) * dr.vel.Z
		dr.pitch += (-fwdv / d.boost * 0.7 - dr.pitch) * math.min(1, dt * 5)
		dr.roll += (-sidev / d.boost * 0.7 - dr.roll) * math.min(1, dt * 5)
	end
	-- collision
	rp.FilterDescendantsInstances = { FX, dr.model, char() }
	local spd = dr.vel.Magnitude
	if spd > 0.1 then
		local res = workspace:Raycast(pos, dr.vel * dt * 2 + dr.vel.Unit * (dr.kind == "uav" and 4 or 1.2), rp)
		if res then
			if dr.kind == "fpv" and (spd > 4 * S or dr.lost) then detonate(); return end
			if dr.kind == "uav" or spd > 9 * S or dr.lost then Net:FireServer("crash"); droneGone("Дрон разбит"); return end
			dr.vel = -dr.vel * 0.3
		end
	end
	if pos.Y < 0.8 and dr.vel.Y < 0 then
		if dr.kind == "fpv" and (spd > 4 * S or dr.lost) then detonate(); return end
		if dr.lost or dr.kind == "uav" then Net:FireServer("crash"); droneGone("Дрон разбит"); return end
		dr.vel = Vector3.new(dr.vel.X, 0, dr.vel.Z)
	end
	dr.body.AssemblyLinearVelocity = dr.vel
	dr.body.AssemblyAngularVelocity = Vector3.zero
	dr.body.CFrame = CFrame.new(pos) * CFrame.Angles(0, dr.yaw, 0) * CFrame.Angles(dr.pitch, 0, dr.roll)
	-- camera
	if viewing then
		UIS.MouseBehavior = Enum.MouseBehavior.LockCenter
		local md = UIS:GetMouseDelta() * 0.004 / dr.zoom
		if dr.kind == "uav" then
			dr.camYaw -= md.X; dr.camPitch = math.clamp(dr.camPitch - md.Y, -1.5, 0.2)
			cam.CFrame = CFrame.new(pos + Vector3.new(0, -1.5, 0)) * CFrame.Angles(0, dr.yaw + dr.camYaw, 0) * CFrame.Angles(dr.camPitch, 0, 0)
		else
			dr.yaw -= md.X
			dr.camPitch = math.clamp(dr.camPitch - md.Y, dr.kind == "fpv" and -1.3 or -1.5, dr.kind == "fpv" and 0.9 or 0.3)
			if dr.kind == "fpv" then
				cam.CFrame = CFrame.new(pos + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, dr.yaw, 0) * CFrame.Angles(dr.camPitch + dr.pitch * 0.5, 0, dr.roll * 0.8)
			else
				cam.CFrame = CFrame.new(pos - Vector3.new(0, 0.5, 0)) * CFrame.Angles(0, dr.yaw, 0) * CFrame.Angles(dr.camPitch, 0, dr.roll * 0.2)
			end
		end
		if dr.signal < 0.6 then cam.CFrame *= CFrame.Angles(0, 0, rand(-1, 1) * (1 - dr.signal) * 0.02) end
	end
end

-- ================= INPUT =================
local function fire()
	local W = WEAP[wi]
	nextFire = os.clock() + W.rate
	ammo[wi] -= 1
	local h = hum()
	local moving = h and h.MoveDirection.Magnitude > 0.1
	local crouch = UIS:IsKeyDown(Enum.KeyCode.C) or UIS:IsKeyDown(Enum.KeyCode.LeftControl)
	local spread = W.spread * (crouch and 0.6 or 1) * (moving and 1.8 or 1)
	local o = cam.CFrame.Position
	local dir = (cam.CFrame.LookVector + Vector3.new(rand(-spread, spread), rand(-spread, spread), rand(-spread, spread))).Unit
	rp.FilterDescendantsInstances = { FX, char() }
	local res = workspace:Raycast(o, dir * 1200, rp)
	local hitPos = res and res.Position or o + dir * 1200
	local gun = char() and char():FindFirstChild("Gun")
	local muzzle = o + cam.CFrame.RightVector * 0.6 - cam.CFrame.UpVector * 0.5 + cam.CFrame.LookVector * 1.5
	tracer(muzzle, hitPos)
	Net:FireServer("fire", o, dir, wi)
	recoil += W.recoil
	sound("rbxasset://sounds/paintball.wav", o, 0.9, wi == 1 and 0.55 or 0.45)
	flash(muzzle, 2, 10, 0.04)
end
local function doReload()
	if reloadT > 0 then return end
	local W = WEAP[wi]
	if ammo[wi] >= W.mag then return end
	if reserve[wi] <= 0 then msg("Нет патронов — пополните на базе", 1.5); return end
	reloadT = W.reload
end

UIS.InputBegan:Connect(function(inp, gp)
	if inp.UserInputType == Enum.UserInputType.MouseButton1 then
		if sandboxEdit then
			if gp then return end
			local m = plr:GetMouse()
			Net:FireServer("place", sbSel[1], m.Hit.Position, sbSel[2])
			return
		end
		if gp then return end
		mouseDown = true
		if viewing and dr then
			if dr.kind == "fpv" then detonate() else scan(true) end
		end
		return
	end
	if gp then return end
	local k = inp.KeyCode
	if sandboxEdit then return end
	if k == Enum.KeyCode.R then dmenu.Visible = not dmenu.Visible; return end
	if dmenu.Visible and (k == Enum.KeyCode.One or k == Enum.KeyCode.Two or k == Enum.KeyCode.Three) then
		dsel = k == Enum.KeyCode.One and "fpv" or k == Enum.KeyCode.Two and "scout" or "uav"; refreshD(); return
	end
	if k == Enum.KeyCode.E then
		dmenu.Visible = false
		if not alive() then return end
		if viewing then exitView(); if dr then msg("Дрон удерживается. E — вернуться" .. (dr.kind ~= "fpv" and ", B — вернуть" or ""), 2.5) end
		elseif dr and not dr.lost then dr.returning = false; enterView(); msg("Подключение к дрону", 1)
		else task.spawn(launch) end
		return
	end
	if viewing and dr then
		if k == Enum.KeyCode.V and dr.kind ~= "fpv" then setThermal(not thermal) end
		if k == Enum.KeyCode.B and dr.kind ~= "fpv" then dr.returning = true; exitView(); msg("Дрон возвращается", 2) end
		return
	end
	if k == Enum.KeyCode.B and dr and dr.kind ~= "fpv" then dr.returning = true; msg("Дрон возвращается", 2) end
	if k == Enum.KeyCode.T then doReload() end
	if k == Enum.KeyCode.One and reloadT <= 0 then wi = 1 end
	if k == Enum.KeyCode.Two and reloadT <= 0 then wi = 2 end
	if k == Enum.KeyCode.H then Net:FireServer("med") end
end)
UIS.InputEnded:Connect(function(inp)
	if inp.UserInputType == Enum.UserInputType.MouseButton1 then mouseDown = false end
end)
UIS.InputChanged:Connect(function(inp)
	if inp.UserInputType == Enum.UserInputType.MouseWheel then
		if sandboxEdit then edCam = Vector3.new(edCam.X, math.clamp(edCam.Y - inp.Position.Z * 15, 40, 600), edCam.Z); return end
		if viewing and dr and dr.kind ~= "fpv" then
			dr.zoom = math.clamp(dr.zoom * (inp.Position.Z > 0 and 1.25 or 0.8), 1, 8)
			cam.FieldOfView = DDEF[dr.kind].fov / dr.zoom
		elseif not viewing and reloadT <= 0 then
			wi = 3 - wi
		end
	end
end)

-- character events
local function onChar(c)
	ammo = { 30, 100 }; reserve = { 210, 300 }; reloadT = 0
	local h = c:WaitForChild("Humanoid")
	h.Died:Connect(function()
		if dr and dr.kind ~= "uav" then droneGone(nil) elseif viewing then exitView() end
		msg("Вы погибли. Возрождение через 6 с", 5)
	end)
	h.HealthChanged:Connect(function(v)
		local last = h:GetAttribute("LastHP") or 100
		if v < last then dmgF.BackgroundTransparency = 0.55; task.delay(0.25, function() dmgF.BackgroundTransparency = 1 end) end
		h:SetAttribute("LastHP", v)
	end)
end
plr.CharacterAdded:Connect(onChar)
if plr.Character then task.spawn(onChar, plr.Character) end

-- ================= MAIN LOOP =================
local scanT, refillT = 0, 0
RunService:BindToRenderStep("VillageWar", Enum.RenderPriority.Camera.Value + 1, function(dt)
	if msgT > 0 then msgT -= dt; if msgT <= 0 then msgL.Text = "" end end
	-- sandbox editor camera
	if sandboxEdit then
		local sp = edCam.Y * 0.9 * dt
		local mv = Vector3.zero
		if UIS:IsKeyDown(Enum.KeyCode.W) then mv += Vector3.new(0, 0, -sp) end
		if UIS:IsKeyDown(Enum.KeyCode.S) then mv += Vector3.new(0, 0, sp) end
		if UIS:IsKeyDown(Enum.KeyCode.A) then mv += Vector3.new(-sp, 0, 0) end
		if UIS:IsKeyDown(Enum.KeyCode.D) then mv += Vector3.new(sp, 0, 0) end
		edCam += mv
		cam.CameraType = Enum.CameraType.Scriptable
		cam.CFrame = CFrame.new(edCam) * CFrame.Angles(-1.15, 0, 0)
		UIS.MouseBehavior = Enum.MouseBehavior.Default
		return
	end
	local h = hum()
	-- fpv regen
	fpvRegen += dt
	if fpvRegen > 35 then fpvRegen = 0; if fpvStock < 8 then fpvStock += 1 end end
	droneUpdate(dt)
	if viewing and dr then
		scanT -= dt
		if scanT <= 0 and dr.kind ~= "fpv" then scanT = 0.7; scan(false) end
	end
	-- soldier
	if h and h.Health > 0 and not viewing then
		local crouch = UIS:IsKeyDown(Enum.KeyCode.C) or UIS:IsKeyDown(Enum.KeyCode.LeftControl)
		local sprint = UIS:IsKeyDown(Enum.KeyCode.LeftShift) and not crouch
		h.WalkSpeed = crouch and 7 or (sprint and 24 or 15)
		h.CameraOffset = h.CameraOffset:Lerp(crouch and Vector3.new(0, -1.6, 0) or Vector3.zero, math.min(1, dt * 10))
		if reloadT > 0 then
			reloadT -= dt
			if reloadT <= 0 then
				local W = WEAP[wi]
				local take = math.min(W.mag - ammo[wi], reserve[wi])
				ammo[wi] += take; reserve[wi] -= take
			end
		elseif mouseDown and not sprint and os.clock() >= nextFire and not menu.Visible then
			if ammo[wi] > 0 then fire() else doReload() end
		end
		local r = root()
		refillT -= dt
		if r and refillT <= 0 then
			refillT = 1
			if (r.Position - BASE0).Magnitude < 30 * S then reserve = { 210, 300 }; Net:FireServer("refill") end
		end
		-- recoil & shake
		recoil *= math.pow(0.002, dt)
		if recoil > 0.0005 or shake > 0 then
			cam.CFrame = cam.CFrame * CFrame.Angles(recoil + rand(-shake, shake) * 0.03, rand(-shake, shake) * 0.03, 0)
		end
	end
	shake = math.max(0, shake - dt * 1.5)
	-- HUD
	tk0.Text = RS:GetAttribute("Mode") == "defense" and "∞" or tostring(math.max(0, RS:GetAttribute("T0") or 0))
	tk1.Text = tostring(math.max(0, RS:GetAttribute("T1") or 0))
	for _, n in ipairs({ "A", "B", "C" }) do
		local pr = RS:GetAttribute("P" .. n) or 0
		local col = Color3.new(0.4, 0.4, 0.4):Lerp(pr >= 0 and C3(60, 120, 255) or C3(255, 60, 60), math.abs(pr))
		ptEls[n][1].BackgroundColor3 = col
		ptEls[n][2].Color = RS:GetAttribute("C" .. n) and C3(255, 230, 0) or C3(255, 255, 255)
	end
	if h then
		hpL.Text = "ЗДОРОВЬЕ " .. math.max(0, math.floor(h.Health))
		hpBar.Size = UDim2.fromScale(math.clamp(h.Health / 100, 0, 1), 1)
		hpBar.BackgroundColor3 = h.Health < 35 and C3(220, 50, 50) or C3(120, 210, 80)
	end
	itemsL.Text = "Аптечки: <b>" .. tostring(plr:GetAttribute("Med") or 0) .. "</b>   FPV: <b>" .. fpvStock .. "</b>   Дрон: <b>" .. (dsel == "fpv" and "FPV" or dsel == "scout" and "Разведчик" or "БПЛА") .. "</b>"
	wL.Text = WEAP[wi].name .. (reloadT > 0 and " — перезарядка…" or "")
	ammoL.Text = ammo[wi] .. '<font size="18" transparency="0.4"> / ' .. reserve[wi] .. "</font>"
	if not viewing then
		if dr then hintL.Text = "E — вернуться к дрону · B — вернуть дрон · R — меню дронов"
		else hintL.Text = "E — запуск " .. (dsel == "fpv" and "FPV" or dsel == "scout" and "разведчика" or "БПЛА") .. " · R — выбор дрона · T — перезарядка · H — аптечка" end
	else hintL.Text = "" end
	-- marks distance
	for _, bb in ipairs(marksF:GetChildren()) do
		if bb.Adornee and bb.Adornee.Parent then
			local t = bb:FindFirstChild("T")
			if t then t.Text = "◆\n" .. math.floor((bb.Adornee.Position - cam.CFrame.Position).Magnitude / S) .. "м" end
		else bb:Destroy() end
	end
	-- FPV HUD
	if viewing and dr then
		local spd = dr.vel.Magnitude / S * 3.6
		local bat = math.max(0, dr.battery * 100)
		local sig = math.floor(dr.signal * 100)
		local t = math.floor(dr.t)
		local nb = math.ceil(bat / 10)
		fpvStats.Text = string.format("SPD %3d km/h\nALT %.1f m\nBAT %s%s %d%%\nSIG %s %d%%\nT %02d:%02d", math.floor(spd), dr.body.Position.Y / S, string.rep("▮", nb), string.rep("▯", 10 - nb), math.floor(bat), string.rep("▮", math.ceil(sig / 25)), sig, t // 60, t % 60)
		local r = root()
		local dist = r and Vector3.new(dr.body.Position.X - r.Position.X, 0, dr.body.Position.Z - r.Position.Z).Magnitude / S or 0
		if dr.kind == "fpv" then
			fpvRight.Text = string.format("DIST %d m\nЛКМ — ПОДРЫВ\nE — ВЫХОД", math.floor(dist))
		else
			fpvRight.Text = string.format("%s  x%.1f\nDIST %d m\nЛКМ — отметить · V — тепло\nB — домой · E — выход", thermal and "THERMAL WHT" or "DAY", dr.zoom, math.floor(dist))
		end
		fpvWarn.Text = dr.lost and "SIGNAL LOST" or (dr.battery < 0.15 and "LOW BATTERY") or (dr.signal < 0.3 and "WEAK SIGNAL") or ""
		local pitchV = dr.kind == "fpv" and (dr.camPitch + dr.pitch * 0.5) or dr.camPitch
		horizon.Position = UDim2.new(0.5, 0, 0.5, pitchV * 300)
		horizon.Rotation = -math.deg(dr.roll)
		local inten = (dr.kind == "fpv" and 0.12 or 0.04) + (1 - dr.signal) * 0.85 + (dr.lost and 0.5 or 0)
		local vp = cam.ViewportSize
		for i, n in ipairs(noise) do
			if rnd:NextNumber() < inten then
				n.Visible = true
				n.Position = UDim2.fromOffset(rnd:NextInteger(0, vp.X), rnd:NextInteger(0, vp.Y))
				n.Size = UDim2.fromOffset(rnd:NextInteger(3, 14), rnd:NextInteger(2, 4))
				n.BackgroundColor3 = rnd:NextNumber() < 0.5 and C3(255, 255, 255) or C3(0, 0, 0)
				n.BackgroundTransparency = 0.6 - inten * 0.4
			else n.Visible = false end
		end
		glitch.Visible = rnd:NextNumber() < inten * 0.5
		if glitch.Visible then glitch.Position = UDim2.fromScale(0, rnd:NextNumber()); glitch.Size = UDim2.new(1, 0, 0, rnd:NextInteger(2, 30)) end
	end
end)
