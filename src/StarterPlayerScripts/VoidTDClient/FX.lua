--!nocheck
-- VOID TD :: FX (клиент)
-- Все визуальные эффекты способностей. Урон считается на сервере, тут только картинка.

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local FX = {}
FX.Lite = false -- облегчённый режим: меньше частиц и обломков

local V = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles
local rad = math.rad

local NEON = Color3.fromRGB(180, 80, 255)
local NEON_SOFT = Color3.fromRGB(215, 160, 255)
local NEON_PINK = Color3.fromRGB(255, 60, 170)
local WHITE = Color3.fromRGB(250, 245, 255)
FX.Colors = { Neon = NEON, Soft = NEON_SOFT, Pink = NEON_PINK, White = WHITE }

local folder
local rng = Random.new()
local numberCount = 0

------------------------------------------------------------------------
-- ЗВУКИ (встроенные звуки клиента Roblox, без загрузки ассетов)
------------------------------------------------------------------------
local SoundService = game:GetService("SoundService")
local SoundConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("VoidTD"):WaitForChild("Config")).Sounds
local lastSound = {}

-- Играет звук события из Config.Sounds. volume/pitch — множители (по умолчанию 1).
-- Если у события указан Custom ("rbxassetid://..."), играет свой звук, иначе встроенный.
function FX.Sound(name, volume, pitch, pos)
	local def = SoundConfig[name]
	if not def then
		return
	end
	local t = os.clock()
	if lastSound[name] and t - lastSound[name] < 0.07 then
		return
	end
	volume = (volume or 1) * (def.Volume or 0.4)
	-- приглушаем далёкие звуки
	if pos then
		local cam = workspace.CurrentCamera
		local d = cam and (cam.CFrame.Position - pos).Magnitude or 0
		if d > 140 then
			return
		end
		volume = volume * math.clamp(1 - d / 140, 0.15, 1)
	end
	lastSound[name] = t
	local custom = def.Custom and def.Custom ~= ""
	local s = Instance.new("Sound")
	s.SoundId = custom and def.Custom or def.Id
	s.Volume = volume
	s.PlaybackSpeed = (pitch or 1) * (custom and 1 or (def.Pitch or 1))
	s.Parent = SoundService
	s:Play()
	task.delay(4, function()
		s:Destroy()
	end)
end

------------------------------------------------------------------------
-- ТРЯСКА КАМЕРЫ
------------------------------------------------------------------------
local shakeUntil, shakeDur, shakeMag = 0, 1, 0

function FX.Shake(magnitude, duration)
	local t = os.clock()
	if t + duration > shakeUntil or magnitude > shakeMag then
		shakeUntil = t + duration
		shakeDur = duration
		shakeMag = magnitude
	end
end

function FX.Init()
	folder = workspace:FindFirstChild("VoidTD_FX") or Instance.new("Folder")
	folder.Name = "VoidTD_FX"
	folder.Parent = workspace
	RunService:BindToRenderStep("VoidTD_Shake", Enum.RenderPriority.Camera.Value + 1, function()
		local t = os.clock()
		if t < shakeUntil then
			local k = (shakeUntil - t) / shakeDur * shakeMag
			local cam = workspace.CurrentCamera
			cam.CFrame = cam.CFrame * CFrame.new(rng:NextNumber(-k, k), rng:NextNumber(-k, k), 0) * CFrame.Angles(0, 0, rng:NextNumber(-k, k) * 0.03)
		end
	end)
end

local function tween(obj, time, goal, style, dir)
	local t = TweenService:Create(obj, TweenInfo.new(time, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), goal)
	t:Play()
	return t
end
FX.Tween = tween

function FX.Part(props)
	local p = Instance.new(props.Class or "Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = props.Material or Enum.Material.Neon
	p.Color = props.Color or NEON
	p.Size = props.Size or V(1, 1, 1)
	if props.Shape then
		p.Shape = props.Shape
	end
	p.Transparency = props.Transparency or 0
	p.CFrame = props.CFrame or CF()
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = props.Parent or folder
	return p
end

local function cleanup(obj, t)
	task.delay(t, function()
		if obj then
			obj:Destroy()
		end
	end)
end

local function light(parent, color, range, brightness, life)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Shadows = false
	l.Parent = parent
	if life then
		tween(l, life, { Brightness = 0 })
	end
	return l
end

------------------------------------------------------------------------
-- БАЗОВЫЕ ЭФФЕКТЫ
------------------------------------------------------------------------
function FX.Burst(pos, color, count, size, speed, life)
	count = count or 8
	if FX.Lite then
		count = math.min(math.ceil(count / 3), 4)
	end
	size = size or 0.4
	speed = speed or 6
	life = life or 0.45
	for _ = 1, count do
		local dir = V(rng:NextNumber(-1, 1), rng:NextNumber(-0.2, 1), rng:NextNumber(-1, 1)).Unit
		local p = FX.Part({
			Size = V(size, size, size),
			CFrame = CF(pos) * ANG(rng:NextNumber(0, 6), rng:NextNumber(0, 6), 0),
			Color = color or NEON,
		})
		tween(p, life, {
			CFrame = CF(pos + dir * speed * life) * ANG(rng:NextNumber(0, 6), rng:NextNumber(0, 6), 0),
			Transparency = 1,
			Size = V(0.05, 0.05, 0.05),
		})
		cleanup(p, life + 0.05)
	end
end

-- Плоское кольцо, расширяющееся по земле
function FX.Ring(pos, radius, color, life, height, startRadius, transparency)
	life = life or 0.5
	height = height or 0.3
	local r0 = startRadius or 0.5
	local p = FX.Part({
		Shape = Enum.PartType.Cylinder,
		Size = V(height, r0 * 2, r0 * 2),
		CFrame = CF(pos) * ANG(0, 0, rad(90)),
		Color = color or NEON,
		Transparency = transparency or 0.15,
	})
	tween(p, life, { Size = V(height * 0.4, radius * 2, radius * 2), Transparency = 1 })
	cleanup(p, life + 0.05)
	return p
end

function FX.Sphere(pos, radius, color, life, material, startT)
	local p = FX.Part({
		Shape = Enum.PartType.Ball,
		Size = V(0.5, 0.5, 0.5),
		CFrame = CF(pos),
		Color = color or NEON,
		Material = material or Enum.Material.Neon,
		Transparency = startT or 0.1,
	})
	tween(p, life, { Size = V(radius * 2, radius * 2, radius * 2), Transparency = 1 })
	cleanup(p, life + 0.05)
	return p
end

-- Дуга из сегментов (след от оружия)
function FX.Arc(cf, radius, a0, a1, color, thickness, life, horizontal)
	local segs = 9
	thickness = thickness or 0.35
	life = life or 0.35
	local prev
	for i = 0, segs do
		local a = a0 + (a1 - a0) * (i / segs)
		local pt
		if horizontal then
			pt = (cf * CF(math.sin(a) * radius, 0, -math.cos(a) * radius)).Position
		else
			pt = (cf * CF(0, math.cos(a) * radius, -math.sin(a) * radius)).Position
		end
		if prev then
			local len = (pt - prev).Magnitude
			local w = thickness * (0.35 + 0.65 * math.sin(math.pi * i / segs))
			local p = FX.Part({
				Size = V(w, w * 0.5, len + w),
				CFrame = CFrame.lookAt((pt + prev) / 2, pt),
				Color = color or NEON,
				Transparency = 0.05,
			})
			local delay = i / segs * 0.06
			task.delay(delay, function()
				tween(p, life, { Transparency = 1, Size = V(w * 0.2, w * 0.1, len) })
			end)
			cleanup(p, life + delay + 0.05)
		end
		prev = pt
	end
end

-- Вертикальная полоса-разрез (для катаны / императора)
function FX.SlashMark(pos, angle, length, width, color, life)
	life = life or 0.35
	local cf = CF(pos) * ANG(0, rng:NextNumber(0, math.pi), 0) * ANG(0, 0, angle)
	local p = FX.Part({ Size = V(width, length * 0.3, 0.12), CFrame = cf, Color = color or NEON })
	local core = FX.Part({ Size = V(width * 0.35, length * 0.3, 0.14), CFrame = cf, Color = WHITE })
	tween(p, life * 0.35, { Size = V(width, length, 0.12) }, Enum.EasingStyle.Back)
	tween(core, life * 0.35, { Size = V(width * 0.35, length, 0.14) }, Enum.EasingStyle.Back)
	task.delay(life * 0.35, function()
		tween(p, life * 0.65, { Transparency = 1, Size = V(0.05, length * 1.1, 0.05) })
		tween(core, life * 0.65, { Transparency = 1, Size = V(0.02, length * 1.1, 0.02) })
	end)
	cleanup(p, life + 0.05)
	cleanup(core, life + 0.05)
end

function FX.Cracks(pos, radius, color, count, life)
	if FX.Lite then
		return
	end
	count = count or 8
	life = life or 1.4
	for i = 1, count do
		local a = (i / count) * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
		local len = radius * rng:NextNumber(0.5, 0.95)
		local dir = V(math.cos(a), 0, math.sin(a))
		local mid = pos + dir * (len / 2 + 0.6)
		local p = FX.Part({
			Size = V(rng:NextNumber(0.25, 0.5), 0.08, len),
			CFrame = CFrame.lookAt(mid, mid + dir) * ANG(0, rng:NextNumber(-0.15, 0.15), 0),
			Color = color or NEON,
		})
		-- маленькое ответвление
		local bdir = (dir + V(-dir.Z, 0, dir.X) * rng:NextNumber(-0.8, 0.8)).Unit
		local bmid = pos + dir * len * 0.6 + bdir * len * 0.2
		local b = FX.Part({ Size = V(0.2, 0.08, len * 0.4), CFrame = CFrame.lookAt(bmid, bmid + bdir), Color = color or NEON })
		task.delay(life * 0.5, function()
			tween(p, life * 0.5, { Transparency = 1 })
			tween(b, life * 0.5, { Transparency = 1 })
		end)
		cleanup(p, life + 0.05)
		cleanup(b, life + 0.05)
	end
	local scorch = FX.Part({
		Shape = Enum.PartType.Cylinder,
		Size = V(0.06, radius * 0.9, radius * 0.9),
		CFrame = CF(pos) * ANG(0, 0, rad(90)),
		Color = Color3.fromRGB(10, 5, 15),
		Material = Enum.Material.SmoothPlastic,
		Transparency = 0.3,
	})
	tween(scorch, life, { Transparency = 1 })
	cleanup(scorch, life + 0.05)
end

------------------------------------------------------------------------
-- СНАРЯДЫ И ЛУЧИ
------------------------------------------------------------------------
-- getTarget() -> Vector3 | nil (текущая позиция цели)
function FX.Projectile(kind, from, getTarget, travel, onHit, lv)
	lv = lv or 1
	local p
	if kind == "Arrow" then
		p = FX.Part({ Size = V(0.18, 0.18, 2.2), Color = lv >= 4 and NEON or NEON_SOFT })
		local tipP = FX.Part({ Size = V(0.35, 0.35, 0.35), Color = NEON, Parent = p })
		tipP.Name = "Tip"
	elseif kind == "Orb" then
		local s = 0.7 + lv * 0.1
		p = FX.Part({ Shape = Enum.PartType.Ball, Size = V(s, s, s), Color = NEON })
		light(p, NEON, 8, 2)
	elseif kind == "Crystal" then
		p = FX.Part({ Size = V(0.4, 0.4, 1.3), Color = Color3.fromRGB(110, 190, 255) })
		light(p, Color3.fromRGB(80, 170, 255), 7, 2)
	elseif kind == "Bullet" then
		p = FX.Part({ Size = V(0.15, 0.15, 0.9), Color = Color3.fromRGB(255, 90, 80) })
	elseif kind == "Moon" then
		p = FX.Part({ Size = V(0.2, 1.2, 1.2), Shape = Enum.PartType.Cylinder, Color = Color3.fromRGB(255, 200, 215) })
		light(p, Color3.fromRGB(255, 120, 150), 8, 2)
	else
		p = FX.Part({ Size = V(0.25, 0.25, 1.4 + lv * 0.15), Color = lv >= 5 and NEON_PINK or NEON_SOFT })
	end
	local a0 = Instance.new("Attachment")
	a0.Position = V(0, 0.12, 0)
	a0.Parent = p
	local a1 = Instance.new("Attachment")
	a1.Position = V(0, -0.12, 0)
	a1.Parent = p
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Color = ColorSequence.new(kind == "Orb" and NEON or NEON_SOFT)
	trail.LightEmission = 1
	trail.Lifetime = 0.18
	trail.Transparency = NumberSequence.new(0.2, 1)
	trail.WidthScale = NumberSequence.new(kind == "Orb" and 3 or 1, 0)
	trail.Parent = p

	local start = os.clock()
	local last = getTarget() or from
	if (last - from).Magnitude > 0.01 then
		p.CFrame = CFrame.lookAt(from, last)
	else
		p.CFrame = CF(from)
	end
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local alpha = math.clamp((os.clock() - start) / math.max(travel, 0.01), 0, 1)
		local target = getTarget() or last
		last = target
		local pos = from:Lerp(target, alpha)
		if kind == "Arrow" then
			pos = pos + V(0, math.sin(alpha * math.pi) * 1.2, 0)
		end
		if (target - pos).Magnitude > 0.01 then
			p.CFrame = CFrame.lookAt(pos, target)
		else
			p.CFrame = CF(pos)
		end
		if p:FindFirstChild("Tip") then
			p.Tip.CFrame = p.CFrame * CF(0, 0, -1.1)
		end
		if alpha >= 1 then
			conn:Disconnect()
			if onHit then
				onHit(target)
			end
			p:Destroy()
		end
	end)
end

function FX.Beam(from, to, width, color, life, big)
	life = life or 0.45
	local len = (to - from).Magnitude
	local cf = CFrame.lookAt((from + to) / 2, to)
	local outer = FX.Part({ Shape = Enum.PartType.Cylinder, Size = V(len, width * 0.2, width * 0.2), CFrame = cf * ANG(0, rad(90), 0), Color = color or NEON, Transparency = 0.15 })
	local inner = FX.Part({ Shape = Enum.PartType.Cylinder, Size = V(len, width * 0.1, width * 0.1), CFrame = cf * ANG(0, rad(90), 0), Color = WHITE })
	tween(outer, 0.1, { Size = V(len, width, width) }, Enum.EasingStyle.Back)
	tween(inner, 0.1, { Size = V(len, width * 0.45, width * 0.45) }, Enum.EasingStyle.Back)
	light(inner, color or NEON, 16, 4, life)
	task.delay(0.12, function()
		tween(outer, life, { Size = V(len, 0.05, 0.05), Transparency = 1 })
		tween(inner, life, { Size = V(len, 0.02, 0.02), Transparency = 1 })
	end)
	cleanup(outer, life + 0.2)
	cleanup(inner, life + 0.2)
	-- кольца вдоль луча
	local rings = FX.Lite and 1 or (big and 6 or 3)
	for i = 1, rings do
		local pt = from:Lerp(to, i / (rings + 1))
		local ring = FX.Part({ Shape = Enum.PartType.Cylinder, Size = V(0.15, width * 1.6, width * 1.6), CFrame = CFrame.lookAt(pt, to) * ANG(0, rad(90), 0), Color = color or NEON, Transparency = 0.3 })
		tween(ring, life, { Size = V(0.05, width * 3.5, width * 3.5), Transparency = 1 })
		cleanup(ring, life + 0.05)
	end
	FX.Sphere(to, width * 1.8, color or NEON, 0.35)
	FX.Burst(to, color or NEON, big and 16 or 8, 0.5, 10)
	FX.Sphere(from, width, WHITE, 0.25)
end

------------------------------------------------------------------------
-- СПОСОБНОСТИ
------------------------------------------------------------------------
-- ECLIPSE SHOCKWAVE
function FX.Shockwave(pos, radius, lv, color, soft)
	local NEON = color or NEON
	local NEON_SOFT = soft or NEON_SOFT
	local g = V(pos.X, pos.Y + 0.2, pos.Z)
	FX.Sound("Explosion", 1, 1, pos)
	local cam = workspace.CurrentCamera
	if cam and (cam.CFrame.Position - pos).Magnitude < 70 then
		FX.Shake(lv >= 5 and 0.5 or 0.25, 0.35)
	end
	FX.Ring(g, radius, NEON, 0.55, 0.5, 1, 0.05)
	FX.Ring(g + V(0, 0.15, 0), radius * 0.75, WHITE, 0.4, 0.3, 0.5, 0.2)
	task.delay(0.08, function()
		FX.Ring(g + V(0, 0.1, 0), radius * 1.05, NEON_SOFT, 0.6, 0.25, radius * 0.4, 0.4)
	end)
	FX.Cracks(g, radius, NEON, 6 + lv * 2, 1.4)
	-- пыль/осколки
	for _ = 1, FX.Lite and 0 or (6 + lv) do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(1, radius * 0.8)
		local p = g + V(math.cos(a) * r, 0, math.sin(a) * r)
		local rock = FX.Part({ Size = V(0.6, 0.6, 0.6), CFrame = CF(p), Color = Color3.fromRGB(50, 44, 60), Material = Enum.Material.Slate })
		tween(rock, 0.25, { CFrame = CF(p + V(0, rng:NextNumber(1.5, 3), 0)) * ANG(1, 2, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		task.delay(0.25, function()
			tween(rock, 0.3, { CFrame = CF(p) * ANG(2, 1, 1), Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		end)
		cleanup(rock, 0.6)
	end
	local flash = FX.Part({ Size = V(0.2, 0.2, 0.2), CFrame = CF(g + V(0, 2, 0)), Transparency = 1 })
	light(flash, NEON, radius * 2.5, 5, 0.6)
	cleanup(flash, 0.7)
	if lv >= 5 then
		-- большой фиолетовый взрыв
		FX.Sphere(g, radius * 0.7, NEON, 0.6)
		FX.Sphere(g, radius * 0.45, WHITE, 0.4)
		local pillar = FX.Part({ Shape = Enum.PartType.Cylinder, Size = V(18, 3, 3), CFrame = CF(g + V(0, 9, 0)) * ANG(0, 0, rad(90)), Color = NEON, Transparency = 0.2 })
		tween(pillar, 0.6, { Size = V(26, 0.2, 0.2), Transparency = 1 })
		cleanup(pillar, 0.7)
		FX.Burst(g + V(0, 1, 0), NEON_SOFT, 20, 0.6, 16, 0.6)
	end
end

-- Удар косы: горизонтальная дуга + область
function FX.Reap(unitPos, center, radius, lv, color)
	local NEON = color or NEON
	local dir = (center - unitPos)
	dir = V(dir.X, 0, dir.Z)
	if dir.Magnitude < 0.1 then
		dir = V(0, 0, -1)
	end
	local cf = CFrame.lookAt(V(center.X, center.Y + 1.5, center.Z) - dir.Unit * 1.5, V(center.X, center.Y + 1.5, center.Z) + dir.Unit)
	FX.Arc(cf, radius * 0.9, rad(-80), rad(80), NEON, 0.6 + lv * 0.08, 0.4, true)
	FX.Arc(cf * CF(0, -0.4, 0), radius * 0.75, rad(-70), rad(70), Color3.fromRGB(30, 10, 50), 0.5, 0.45, true)
	FX.Ring(V(center.X, center.Y + 0.15, center.Z), radius, Color3.fromRGB(90, 30, 150), 0.4, 0.2, radius * 0.3, 0.45)
	if lv >= 4 then
		FX.Burst(center + V(0, 1, 0), NEON, 10, 0.4, 8)
	end
end

-- VOID JUDGEMENT: энергетический разрез по врагу
function FX.Judgement(pos, lv, hitIndex)
	FX.Sound("Magic", 1, 0.9 + (hitIndex or 1) * 0.08, pos)
	local color = (hitIndex or 1) % 2 == 0 and NEON or NEON_PINK
	local p = pos + V(0, 2, 0)
	FX.SlashMark(p, rad(35 + rng:NextNumber(-10, 10)), 9 + lv, 0.7 + lv * 0.08, color, 0.45)
	if lv >= 3 then
		FX.SlashMark(p, rad(-35 + rng:NextNumber(-10, 10)), 8 + lv, 0.6, NEON, 0.4)
	end
	-- луч с неба
	local beam = FX.Part({ Shape = Enum.PartType.Cylinder, Size = V(30, 1.4, 1.4), CFrame = CF(pos + V(0, 15, 0)) * ANG(0, 0, rad(90)), Color = color, Transparency = 0.3 })
	tween(beam, 0.35, { Size = V(30, 0.1, 0.1), Transparency = 1 })
	cleanup(beam, 0.4)
	FX.Burst(p, color, 8, 0.45, 9)
	FX.Ring(V(pos.X, pos.Y + 0.15, pos.Z), 3 + lv * 0.4, color, 0.4, 0.25)
end

-- BLACK HOLE
function FX.BlackHole(pos, radius, duration, lv, delay)
	task.delay(delay or 0, function()
		FX.Sound("Portal", 1, 1, pos)
		local center = pos + V(0, 2.2, 0)
		local m = Instance.new("Model")
		m.Name = "BlackHole"
		m.Parent = folder
		local core = FX.Part({ Shape = Enum.PartType.Ball, Size = V(0.5, 0.5, 0.5), CFrame = CF(center), Color = Color3.fromRGB(0, 0, 0), Material = Enum.Material.SmoothPlastic, Parent = m })
		local glow = FX.Part({ Shape = Enum.PartType.Ball, Size = V(0.6, 0.6, 0.6), CFrame = CF(center), Color = NEON, Transparency = 0.55, Parent = m })
		local disk = FX.Part({ Shape = Enum.PartType.Cylinder, Size = V(0.15, 1, 1), CFrame = CF(pos + V(0, 0.2, 0)) * ANG(0, 0, rad(90)), Color = Color3.fromRGB(60, 20, 100), Transparency = 0.35, Parent = m })
		local edge = FX.Part({ Shape = Enum.PartType.Cylinder, Size = V(0.1, 1, 1), CFrame = CF(pos + V(0, 0.25, 0)) * ANG(0, 0, rad(90)), Color = NEON, Transparency = 0.5, Parent = m })
		light(glow, NEON, radius * 2.5, 3)
		local coreSize = 2.2 + lv * 0.35
		tween(core, 0.4, { Size = V(coreSize, coreSize, coreSize) }, Enum.EasingStyle.Back)
		tween(glow, 0.4, { Size = V(coreSize * 1.5, coreSize * 1.5, coreSize * 1.5) }, Enum.EasingStyle.Back)
		tween(disk, 0.4, { Size = V(0.15, radius * 2, radius * 2) })
		tween(edge, 0.4, { Size = V(0.1, radius * 2 + 0.6, radius * 2 + 0.6) })
		-- закручивающиеся рукава
		local arms = {}
		for i = 1, FX.Lite and 2 or (4 + (lv >= 5 and 2 or 0)) do
			arms[i] = FX.Part({ Size = V(0.35, 0.2, radius * 0.9), Color = (i % 2 == 0) and NEON or NEON_SOFT, Transparency = 0.2, Parent = m })
		end
		local emitter = Instance.new("ParticleEmitter")
		emitter.Color = ColorSequence.new(NEON)
		emitter.LightEmission = 1
		emitter.Rate = 30 + lv * 8
		emitter.Lifetime = NumberRange.new(0.5, 0.8)
		emitter.Speed = NumberRange.new(-radius * 1.6, -radius * 1.2)
		emitter.SpreadAngle = Vector2.new(180, 180)
		emitter.Size = NumberSequence.new(0.5, 0)
		emitter.Parent = glow
		local start = os.clock()
		local conn
		conn = RunService.RenderStepped:Connect(function()
			local t = os.clock() - start
			if t > duration then
				conn:Disconnect()
				return
			end
			for i, a in ipairs(arms) do
				local ang = t * 4 + i / #arms * math.pi * 2
				local r = radius * 0.55
				local p = center + V(math.cos(ang) * r, -1.6 + math.sin(t * 3 + i) * 0.3, math.sin(ang) * r)
				a.CFrame = CFrame.lookAt(p, center + V(0, -1.6, 0)) * ANG(0, rad(70), 0)
			end
			local pulse = 1 + math.sin(t * 8) * 0.06
			glow.Size = V(coreSize * 1.5, coreSize * 1.5, coreSize * 1.5) * pulse
		end)
		task.delay(duration, function()
			emitter.Enabled = false
			for _, d in ipairs(m:GetChildren()) do
				if d:IsA("BasePart") then
					tween(d, 0.35, { Size = V(0.05, 0.05, 0.05), Transparency = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
				end
			end
			task.delay(0.3, function()
				FX.Sphere(center, radius * 0.6, NEON, 0.35)
			end)
			cleanup(m, 0.8)
		end)
	end)
end

function FX.Summon(pos, radius)
	FX.Ring(V(pos.X, pos.Y + 0.2, pos.Z), radius or 6, NEON, 0.6, 0.4)
	FX.Burst(pos + V(0, 1, 0), NEON, 12, 0.5, 8)
end

function FX.Poof(pos, color, size)
	size = size or 1
	FX.Sphere(pos, 1.5 * size, color or NEON, 0.35)
	FX.Burst(pos, color or NEON, math.floor(6 + size * 4), 0.35 * size, 6 * size, 0.5)
end

function FX.LevelUp(pos, color)
	FX.Sound("Upgrade", 1, 1, pos)
	FX.Ring(pos + V(0, 0.2, 0), 4, color or NEON, 0.6, 0.3)
	local col = FX.Part({ Shape = Enum.PartType.Cylinder, Size = V(0.2, 3, 3), CFrame = CF(pos + V(0, 0.3, 0)) * ANG(0, 0, rad(90)), Color = color or NEON, Transparency = 0.2 })
	tween(col, 0.7, { CFrame = CF(pos + V(0, 7, 0)) * ANG(0, 0, rad(90)), Transparency = 1, Size = V(0.1, 4.5, 4.5) })
	cleanup(col, 0.75)
	FX.Burst(pos + V(0, 3, 0), color or NEON_SOFT, 14, 0.35, 7, 0.7)
end

function FX.Place(pos)
	FX.Sound("Place", 1, 1, pos)
	FX.Ring(pos + V(0, 0.2, 0), 3.5, NEON_SOFT, 0.45, 0.25)
	FX.Burst(pos + V(0, 0.5, 0), Color3.fromRGB(70, 60, 80), 8, 0.4, 5)
end

------------------------------------------------------------------------
-- ЦИФРЫ УРОНА
------------------------------------------------------------------------
function FX.DamageNumber(pos, amount, flag)
	if numberCount > (FX.Lite and 20 or 70) then
		return
	end
	numberCount = numberCount + 1
	local anchor = FX.Part({ Size = V(0.1, 0.1, 0.1), CFrame = CF(pos), Transparency = 1 })
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(120, 40)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 220
	gui.StudsOffsetWorldSpace = V(rng:NextNumber(-0.8, 0.8), 0, rng:NextNumber(-0.8, 0.8))
	gui.Parent = anchor
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = Color3.fromRGB(20, 0, 30)
	if flag == 2 then
		label.Text = "PHASE"
		label.TextColor3 = Color3.fromRGB(170, 170, 200)
		gui.Size = UDim2.fromOffset(80, 26)
	elseif flag == 1 then
		label.Text = tostring(amount) .. "!"
		label.TextColor3 = Color3.fromRGB(255, 210, 70)
		gui.Size = UDim2.fromOffset(150, 50)
	else
		label.Text = tostring(amount)
		label.TextColor3 = Color3.fromRGB(240, 220, 255)
		gui.Size = UDim2.fromOffset(90, 30)
	end
	label.Parent = gui
	tween(gui, 0.8, { StudsOffsetWorldSpace = gui.StudsOffsetWorldSpace + V(0, 2.5, 0) })
	task.delay(0.35, function()
		tween(label, 0.45, { TextTransparency = 1, TextStrokeTransparency = 1 })
	end)
	task.delay(0.85, function()
		numberCount = numberCount - 1
		anchor:Destroy()
	end)
end

------------------------------------------------------------------------
-- ЭФФЕКТЫ НОВЫХ ЮНИТОВ
------------------------------------------------------------------------
local RED = Color3.fromRGB(255, 35, 55)
local GOLD = Color3.fromRGB(255, 205, 80)
local BLUE = Color3.fromRGB(90, 180, 255)
FX.Colors.Red, FX.Colors.Gold, FX.Colors.Blue = RED, GOLD, BLUE

-- нить кукловода от руки к цели
function FX.Thread(from, to, color)
	local len = (to - from).Magnitude
	if len < 0.1 then
		return
	end
	local p = FX.Part({ Size = V(0.08, 0.08, len), CFrame = CFrame.lookAt((from + to) / 2, to), Color = color or NEON_SOFT })
	tween(p, 0.5, { Transparency = 1, Size = V(0.02, 0.02, len) })
	cleanup(p, 0.55)
	FX.Ring(to - V(0, 1, 0), 2, color or NEON, 0.35, 0.2)
end

-- взрыв кристалла
function FX.CrystalBurst(pos, radius)
	FX.Sphere(pos, radius * 0.6, BLUE, 0.3)
	FX.Ring(V(pos.X, pos.Y + 0.2, pos.Z), radius, Color3.fromRGB(170, 225, 255), 0.35, 0.25)
	FX.Burst(pos + V(0, 1, 0), BLUE, 8, 0.35, 8)
	FX.Sound("Explosion", 0.5, 1.6, pos)
end

-- падающий звёздный осколок
function FX.FallingShard(pos, radius, color)
	color = color or GOLD
	local top = pos + V(rng:NextNumber(-3, 3), 22, rng:NextNumber(-3, 3))
	local shard = FX.Part({ Size = V(0.7, 2.2, 0.7), CFrame = CF(top) * ANG(0, rng:NextNumber(0, 6), rad(15)), Color = color })
	tween(shard, 0.28, { CFrame = CF(pos + V(0, 1, 0)) * ANG(0, 2, rad(15)) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	task.delay(0.28, function()
		shard:Destroy()
		FX.Ring(V(pos.X, pos.Y + 0.2, pos.Z), radius, color, 0.35, 0.3)
		FX.Sphere(pos + V(0, 0.5, 0), radius * 0.4, Color3.fromRGB(255, 240, 200), 0.25)
		FX.Burst(pos + V(0, 1, 0), color, 6, 0.4, 8)
	end)
end

-- маленький портал с разрезом (RIFT STORM)
function FX.RiftPortal(pos, lv)
	local c = pos + V(0, 3.5, 0)
	local ring = FX.Part({ Shape = Enum.PartType.Cylinder, Size = V(0.2, 0.5, 0.5), CFrame = CF(c) * ANG(0, rng:NextNumber(0, 6), 0), Color = NEON })
	tween(ring, 0.15, { Size = V(0.2, 3.2, 3.2) }, Enum.EasingStyle.Back)
	local core = FX.Part({ Shape = Enum.PartType.Cylinder, Size = V(0.25, 0.3, 0.3), CFrame = ring.CFrame, Color = Color3.fromRGB(15, 0, 30) })
	tween(core, 0.15, { Size = V(0.25, 2.4, 2.4) }, Enum.EasingStyle.Back)
	task.delay(0.15, function()
		FX.SlashMark(pos + V(0, 1.5, 0), rad(rng:NextNumber(-50, 50)), 6 + lv * 0.5, 0.5, NEON_PINK, 0.3)
		FX.Burst(pos + V(0, 1, 0), NEON, 6, 0.35, 7)
		tween(ring, 0.25, { Size = V(0.1, 0.2, 0.2), Transparency = 1 })
		tween(core, 0.25, { Size = V(0.1, 0.1, 0.1), Transparency = 1 })
	end)
	cleanup(ring, 0.45)
	cleanup(core, 0.45)
	FX.Sound("Portal", 0.5, 1.4, pos)
end

-- большой центральный разлом
function FX.BigRift(pos, radius)
	local g = V(pos.X, pos.Y + 0.2, pos.Z)
	local disk = FX.Part({ Shape = Enum.PartType.Cylinder, Size = V(0.2, 1, 1), CFrame = CF(g) * ANG(0, 0, rad(90)), Color = Color3.fromRGB(15, 0, 30) })
	tween(disk, 0.25, { Size = V(0.2, radius * 2, radius * 2) }, Enum.EasingStyle.Back)
	FX.Ring(g, radius * 1.1, NEON, 0.6, 0.5, 1, 0.05)
	FX.Ring(g + V(0, 0.1, 0), radius * 0.8, NEON_PINK, 0.5, 0.3, 0.5)
	for i = 1, 4 do
		task.delay(i * 0.05, function()
			FX.SlashMark(g + V(rng:NextNumber(-radius / 2, radius / 2), 2, rng:NextNumber(-radius / 2, radius / 2)), rad(rng:NextNumber(-60, 60)), 9, 0.7, NEON, 0.4)
		end)
	end
	task.delay(0.35, function()
		tween(disk, 0.35, { Size = V(0.1, 0.5, 0.5), Transparency = 1 })
	end)
	cleanup(disk, 0.8)
	FX.Shake(0.4, 0.4)
	FX.Sound("Explosion", 1, 0.7, pos)
end

-- RED SPLASH: расширяющаяся красная волна, вспышка и осколки из меча
function FX.RedSplash(pos, radius, from)
	local g = V(pos.X, pos.Y + 0.2, pos.Z)
	FX.Ring(g, radius, RED, 0.5, 0.5, 1, 0.05)
	FX.Ring(g + V(0, 0.12, 0), radius * 0.7, Color3.fromRGB(255, 150, 150), 0.35, 0.25, 0.5, 0.2)
	local flash = FX.Part({ Shape = Enum.PartType.Cylinder, Size = V(0.08, radius * 1.6, radius * 1.6), CFrame = CF(g + V(0, 0.05, 0)) * ANG(0, 0, rad(90)), Color = RED, Transparency = 0.3 })
	tween(flash, 0.3, { Transparency = 1 })
	cleanup(flash, 0.35)
	FX.Sphere(pos + V(0, 1, 0), 2.5, RED, 0.25)
	if from then
		for _ = 1, FX.Lite and 2 or 6 do
			local to = g + V(rng:NextNumber(-radius, radius) * 0.7, 0.5, rng:NextNumber(-radius, radius) * 0.7)
			local shard = FX.Part({ Size = V(0.25, 0.25, 1.1), CFrame = CFrame.lookAt(from, to), Color = RED })
			tween(shard, 0.25, { CFrame = CFrame.lookAt(to, to + (to - from)), Transparency = 0.6 })
			cleanup(shard, 0.27)
		end
	end
	FX.Cracks(g, radius * 0.8, RED, 6, 0.9)
	FX.Sound("HeavyHit", 1, 0.9, pos)
end

-- рассекающий удар топора
function FX.Cleave(unitPos, center, radius, color)
	FX.Reap(unitPos, center, radius, 4, color or RED)
	FX.Ring(V(center.X, center.Y + 0.2, center.Z), radius, color or RED, 0.4, 0.3)
	FX.Sound("HeavyHit", 1, 1, center)
end

-- молот Starbreaker
function FX.Hammer(pos, radius, lv)
	FX.Shockwave(pos, radius, lv, GOLD, Color3.fromRGB(200, 140, 255))
end

-- кровавая луна падает с неба и взрывается
function FX.BloodMoonFall(pos, radius, delay)
	delay = delay or 1
	local moon = FX.Part({ Shape = Enum.PartType.Ball, Size = V(5, 5, 5), CFrame = CF(pos + V(0, 45, 0)), Color = RED })
	light(moon, RED, 40, 4)
	local mark = FX.Part({ Shape = Enum.PartType.Cylinder, Size = V(0.1, radius * 2, radius * 2), CFrame = CF(pos + V(0, 0.25, 0)) * ANG(0, 0, rad(90)), Color = RED, Transparency = 0.75 })
	tween(moon, delay, { CFrame = CF(pos + V(0, 2, 0)), Size = V(7, 7, 7) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	tween(mark, delay, { Transparency = 0.4 })
	task.delay(delay, function()
		moon:Destroy()
		mark:Destroy()
	end)
	FX.Sound("Boss", 0.6, 1.4, pos)
end

function FX.BloodMoonBoom(pos, radius)
	FX.Shockwave(pos, radius, 5, RED, Color3.fromRGB(255, 140, 140))
	FX.Sphere(pos + V(0, 2, 0), radius * 0.6, Color3.fromRGB(120, 0, 15), 0.6, Enum.Material.Neon, 0.3)
	FX.Shake(0.6, 0.6)
end

-- пробивающий лунный луч
function FX.PierceBeam(from, to)
	FX.Beam(from + V(0, 3, 0), to + V(0, 1.5, 0), 2.2, Color3.fromRGB(255, 190, 215), 0.45, true)
	FX.Sound("Laser", 1, 1.2, from)
end


------------------------------------------------------------------------
-- ПРОКЛЯТЫЙ ЧАСОВЩИК: эффекты времени (золото, бронза, оранжевые искры)
------------------------------------------------------------------------
local CGOLD = Color3.fromRGB(230, 178, 74)
local BRONZE = Color3.fromRGB(170, 112, 52)
local ORANGE = Color3.fromRGB(255, 140, 40)
local DIAL = Color3.fromRGB(16, 12, 20)
FX.Colors.Orange = ORANGE

-- Набор деталей, двигающихся как одно целое: { part, offset }
local function rigidSet()
	return { list = {} }
end

local function addRigid(set, props, offset)
	local p = FX.Part(props)
	set.list[#set.list + 1] = { p, offset or CF() }
	return p
end

local function placeRigid(set, cf)
	for _, it in ipairs(set.list) do
		it[1].CFrame = cf * it[2]
	end
end

local function fadeRigid(set, time)
	for _, it in ipairs(set.list) do
		tween(it[1], time, { Transparency = 1 })
		cleanup(it[1], time + 0.05)
	end
end

-- Шестерня в плоскости XY: восьмиугольник из 4 брусков + 8 зубьев + ступица
local function addGear(set, a, depth, color, hubColor, base)
	base = base or CF()
	for k = 0, 3 do
		addRigid(set, { Size = V(2 * a, 0.83 * a, depth), Color = color, Material = Enum.Material.Metal }, base * ANG(0, 0, k * math.pi / 4))
	end
	if not FX.Lite then
		for k = 0, 7 do
			local ang = k * math.pi / 4
			addRigid(set, { Size = V(a * 0.36, a * 0.34, depth), Color = color, Material = Enum.Material.Metal }, base * CF(math.cos(ang) * a * 1.08, math.sin(ang) * a * 1.08, 0) * ANG(0, 0, ang))
		end
	end
	addRigid(set, { Size = V(a * 0.45, a * 0.45, depth + 0.05), Color = hubColor or ORANGE }, base * ANG(0, 0, math.pi / 4))
end

-- Циферблат в плоскости XY (рама, тёмный диск, деления). Возвращает детали стрелок (двигаются отдельно).
local function addDial(set, a, depth, transparency)
	for k = 0, 3 do
		addRigid(set, { Size = V(2 * a, 0.83 * a, depth), Color = CGOLD, Material = Enum.Material.Metal, Transparency = transparency or 0 }, ANG(0, 0, k * math.pi / 4))
		addRigid(set, { Size = V(1.68 * a, 0.7 * a, depth + 0.04), Color = DIAL, Material = Enum.Material.SmoothPlastic, Transparency = transparency or 0 }, ANG(0, 0, k * math.pi / 4))
	end
	for k = 0, 11 do
		local ang = k * math.pi / 6
		addRigid(set, { Size = V(a * 0.06, a * (k % 3 == 0 and 0.2 or 0.11), depth + 0.08), Color = CGOLD }, CF(math.cos(ang) * a * 0.68, math.sin(ang) * a * 0.68, 0) * ANG(0, 0, ang + math.pi / 2))
	end
end

-- Стрелки часов: две детали, поворачиваются вокруг центра циферблата (cf) на угол
local function makeHands(a, color)
	local h = FX.Part({ Size = V(a * 0.1, a * 0.45, 0.08), Color = color or CGOLD })
	local m = FX.Part({ Size = V(a * 0.06, a * 0.7, 0.08), Color = color or CGOLD })
	return h, m
end

local function placeHands(h, m, cf, ha, ma, a, depth)
	h.CFrame = cf * ANG(0, 0, ha) * CF(0, a * 0.2, -depth / 2 - 0.08)
	m.CFrame = cf * ANG(0, 0, ma) * CF(0, a * 0.32, -depth / 2 - 0.1)
end

local function camFacing(pos)
	local cam = workspace.CurrentCamera
	local c = cam and cam.CFrame.Position or (pos + V(0, 10, 20))
	local flat = V(c.X, pos.Y, c.Z)
	if (flat - pos).Magnitude < 0.1 then
		return CF(pos)
	end
	-- лицевая сторона (-Z) смотрит на камеру
	return CFrame.lookAt(pos, flat)
end

-- Разрез секунд: вращающийся зубчатый диск летит по прямой
function FX.GearDisc(from, to, duration, lv, storm)
	local set = rigidSet()
	local a = 0.75 + (lv or 1) * 0.08
	addGear(set, a, 0.18, storm and ORANGE or CGOLD, storm and Color3.fromRGB(255, 230, 160) or ORANGE)
	local core = set.list[#set.list][1]
	light(core, ORANGE, 8, storm and 3 or 1.5)
	local dir = to - from
	local flat = V(dir.X, 0, dir.Z)
	local base = flat.Magnitude > 0.01 and CFrame.lookAt(V(), flat).Rotation or CF()
	local start = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local el = os.clock() - start
		local alpha = math.clamp(el / math.max(duration, 0.05), 0, 1)
		local pos = from:Lerp(to, alpha)
		placeRigid(set, CF(pos) * base * ANG(rad(90), 0, 0) * ANG(0, 0, el * 16))
		if alpha >= 1 then
			conn:Disconnect()
			fadeRigid(set, 0.2)
		end
	end)
	FX.Sound("Slash", 0.8, 1.4, from)
end

-- Попадание диском: золотые искры, шестерёнки, призрачные стрелки, оранжевая вспышка
function FX.ChronoHit(pos)
	FX.Burst(pos, CGOLD, 5, 0.22, 6, 0.35)
	FX.Burst(pos, BRONZE, 3, 0.3, 4, 0.45)
	FX.Sphere(pos, 1.0, ORANGE, 0.18, nil, 0.3)
	if not FX.Lite then
		local cf = camFacing(pos + V(0, 1.2, 0))
		local h, m = makeHands(1.2, Color3.fromRGB(255, 220, 150))
		h.Transparency, m.Transparency = 0.3, 0.3
		placeHands(h, m, cf, 0, 0, 1.2, 0)
		tween(h, 0.4, { CFrame = cf * ANG(0, 0, -2.5) * CF(0, 0.24, -0.1), Transparency = 1 })
		tween(m, 0.4, { CFrame = cf * ANG(0, 0, 2.8) * CF(0, 0.38, -0.12), Transparency = 1 })
		cleanup(h, 0.45)
		cleanup(m, 0.45)
	end
end

-- Маленькие часы над точкой (на время dur): стрелки крутятся со скоростью speed
local function tinyClock(pos, a, dur, speed)
	local set = rigidSet()
	addDial(set, a, 0.12)
	local h, m = makeHands(a)
	local cf = camFacing(pos)
	placeRigid(set, cf)
	local start = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local el = os.clock() - start
		placeHands(h, m, cf, -el * speed * 0.2, -el * speed, a, 0.12)
		if el >= dur then
			conn:Disconnect()
			fadeRigid(set, 0.25)
			for _, p in ipairs({ h, m }) do
				tween(p, 0.25, { Transparency = 1 })
				cleanup(p, 0.3)
			end
		end
	end)
end
FX.TinyClock = tinyClock

-- ПОЛОМКА ВРЕМЕНИ: огромный циферблат под врагами, стрелки резко останавливаются, всё замирает
function FX.TimeBreak(pos, radius, dur)
	local g = V(pos.X, pos.Y + 0.25, pos.Z)
	FX.Sound("Magic", 1, 0.55, pos)
	-- циферблат на дороге
	local floor = rigidSet()
	addDial(floor, radius, 0.12, 0.25)
	placeRigid(floor, CF(g) * ANG(rad(-90), 0, 0))
	local fh, fm = makeHands(radius)
	-- огромные часы над дорогой
	local sky = rigidSet()
	local skyA = radius * 0.45
	addDial(sky, skyA, 0.3)
	local skyCF = camFacing(g + V(0, radius * 0.9 + 3, 0))
	placeRigid(sky, skyCF)
	local sh, sm = makeHands(skyA)
	-- механические кольца и зависшие в воздухе частицы
	local rings = {}
	if not FX.Lite then
		for i = 1, 2 do
			local set = rigidSet()
			local rr = radius * (0.7 + i * 0.12)
			for k = 0, 15 do
				if k % 4 ~= 3 then
					local ang = k / 16 * math.pi * 2
					addRigid(set, { Size = V(2 * math.pi * rr / 16 * 1.05, 0.12, 0.2), Color = CGOLD, Material = Enum.Material.Metal }, CF(math.cos(ang) * rr, 0, math.sin(ang) * rr) * ANG(0, -ang - math.pi / 2, 0))
				end
			end
			rings[i] = { set, i * 0.9 }
		end
		for _ = 1, 10 do
			local ang = rng:NextNumber(0, math.pi * 2)
			local d = rng:NextNumber(0, radius * 0.9)
			local p = FX.Part({ Size = V(0.25, 0.25, 0.25), CFrame = CF(g + V(math.cos(ang) * d, rng:NextNumber(0.6, 3), math.sin(ang) * d)) * ANG(1, 2, 0), Color = rng:NextNumber() < 0.5 and CGOLD or ORANGE, Transparency = 0.15 })
			task.delay(dur, function()
				tween(p, 0.35, { CFrame = p.CFrame + V(0, -1.5, 0), Transparency = 1 })
			end)
			cleanup(p, dur + 0.4)
		end
	end
	local start = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local el = os.clock() - start
		-- первые 0.45 с стрелки бешено крутятся, затем резко останавливаются
		local spin = math.min(el, 0.45)
		local ha, ma = -spin * 14, -spin * 40
		placeHands(fh, fm, CF(g) * ANG(rad(-90), 0, 0), ha, ma, radius, 0.12)
		placeHands(sh, sm, skyCF, ha * 0.8, ma * 0.8, skyA, 0.3)
		for _, rg in ipairs(rings) do
			placeRigid(rg[1], CF(g + V(0, rg[2], 0)) * ANG(0, spin * 3 * (rg[2] > 1 and -1 or 1), 0))
		end
		if el >= dur then
			conn:Disconnect()
			-- время пошло: оранжевая вспышка и осколки шестерёнок
			FX.Sound("Explosion", 0.6, 1.4, pos)
			FX.Sphere(g + V(0, 1, 0), radius * 0.55, ORANGE, 0.35, nil, 0.3)
			FX.Ring(g, radius * 1.1, ORANGE, 0.45, 0.3, radius * 0.5, 0.2)
			FX.Burst(g + V(0, 1, 0), CGOLD, 12, 0.35, 10, 0.6)
			FX.Burst(g + V(0, 1, 0), BRONZE, 8, 0.4, 7, 0.6)
			fadeRigid(floor, 0.35)
			fadeRigid(sky, 0.35)
			for _, rg in ipairs(rings) do
				fadeRigid(rg[1], 0.3)
			end
			for _, p in ipairs({ fh, fm, sh, sm }) do
				tween(p, 0.3, { Transparency = 1 })
				cleanup(p, 0.35)
			end
		end
	end)
end

-- УСКОРЕНИЕ ВРЕМЕНИ: золотое кольцо от часовщика и маленькие часы над союзниками
function FX.TimeHaste(pos, radius, allyPositions, dur)
	local g = V(pos.X, pos.Y + 0.25, pos.Z)
	FX.Sound("Upgrade", 0.9, 1.35, pos)
	FX.Ring(g, radius, CGOLD, 0.8, 0.4, 1, 0.1)
	task.delay(0.12, function()
		FX.Ring(g + V(0, 0.1, 0), radius * 0.8, ORANGE, 0.7, 0.25, 1, 0.3)
	end)
	FX.Burst(g + V(0, 2, 0), CGOLD, 10, 0.3, 8, 0.6)
	for _, ap in ipairs(allyPositions) do
		tinyClock(ap + V(0, 7, 0), 0.7, dur, 18)
		FX.Ring(ap + V(0, 0.3, 0), 2.5, CGOLD, 0.4, 0.2, 0.5, 0.2)
	end
end

-- ВРЕМЕННАЯ БУРЯ: огромное механическое кольцо и удар по земле
function FX.TimeStorm(pos, delay)
	local g = V(pos.X, pos.Y + 0.25, pos.Z)
	FX.Sound("Magic", 1, 0.45, pos)
	local set = rigidSet()
	local rr = 6.5
	for k = 0, (FX.Lite and 7 or 15) do
		local n = FX.Lite and 8 or 16
		local ang = k / n * math.pi * 2
		addRigid(set, { Size = V(2 * math.pi * rr / n * 1.02, 0.5, 0.3), Color = CGOLD, Material = Enum.Material.Metal }, CF(math.cos(ang) * rr, 0, math.sin(ang) * rr) * ANG(0, -ang - math.pi / 2, 0))
		if k % 2 == 0 and not FX.Lite then
			addRigid(set, { Size = V(0.4, 0.8, 0.4), Color = ORANGE }, CF(math.cos(ang) * rr, 0.5, math.sin(ang) * rr) * ANG(0, -ang, math.pi / 4))
		end
	end
	local start = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local el = os.clock() - start
		local rise = math.min(el / (delay or 1.2), 1)
		placeRigid(set, CF(g + V(0, 0.5 + rise * 2, 0)) * ANG(0, el * 2.5 * (0.3 + rise), 0))
		if el >= (delay or 1.2) then
			conn:Disconnect()
			fadeRigid(set, 0.4)
			FX.Shockwave(g, 9, 3, CGOLD, ORANGE)
			FX.Sphere(g + V(0, 2, 0), 4, ORANGE, 0.45, nil, 0.25)
		end
	end)
end

-- Удар во время бури: механический взрыв, золотой круг на дороге, часы над целью
function FX.ChronoBurst(pos, radius)
	local g = V(pos.X, pos.Y + 0.2, pos.Z)
	FX.Ring(g, radius, CGOLD, 0.45, 0.3, 0.5, 0.1)
	FX.Ring(g + V(0, 0.05, 0), radius * 0.6, ORANGE, 0.35, 0.2, 0.3, 0.3)
	FX.Burst(g + V(0, 1, 0), ORANGE, 8, 0.3, 9, 0.45)
	FX.Burst(g + V(0, 1, 0), BRONZE, 5, 0.35, 6, 0.5)
	if not FX.Lite then
		tinyClock(g + V(0, 4, 0), 0.6, 0.6, 30)
	end
	FX.Sound("Explosion", 0.4, 1.6, pos)
end

-- Установка часовщика: циферблат под ним, стрелки идут назад, золотой механический портал
function FX.ClockPortal(pos, dur)
	dur = dur or 1.3
	local g = V(pos.X, pos.Y + 0.25, pos.Z)
	local set = rigidSet()
	local a = 4.5
	addDial(set, a, 0.12, 0.2)
	placeRigid(set, CF(g) * ANG(rad(-90), 0, 0))
	local h, m = makeHands(a)
	local portal = FX.Part({ Shape = Enum.PartType.Cylinder, Size = V(0.3, 0.5, 0.5), CFrame = CF(g + V(0, 0.2, 0)) * ANG(0, 0, rad(90)), Color = CGOLD, Transparency = 0.2 })
	tween(portal, dur * 0.6, { Size = V(0.3, a * 1.6, a * 1.6) })
	light(portal, ORANGE, 14, 2, dur + 0.5)
	FX.Sound("Portal", 0.9, 1.2, pos)
	local start = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local el = os.clock() - start
		-- стрелки идут назад
		placeHands(h, m, CF(g) * ANG(rad(-90), 0, 0), el * 4, el * 22, a, 0.12)
		if el >= dur then
			conn:Disconnect()
			fadeRigid(set, 0.5)
			for _, p in ipairs({ h, m, portal }) do
				tween(p, 0.5, { Transparency = 1 })
				cleanup(p, 0.55)
			end
			FX.Burst(g + V(0, 2, 0), CGOLD, 14, 0.35, 8, 0.6)
			FX.Ring(g, 6, ORANGE, 0.5, 0.3, 2, 0.2)
		end
	end)
end

return FX
