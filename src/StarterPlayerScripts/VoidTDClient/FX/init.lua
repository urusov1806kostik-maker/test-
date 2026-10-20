--!nocheck
-- VOID TD :: FX (клиент) — ядро эффектов
-- Только картинка и звук: урон/броски считает сервер. Эффекты способностей пишутся в детях
-- FX/Void.lua, FX/Chrono.lua, FX/Halloween.lua (каждый `return function(FX) ... end`), которые
-- подключаются в FX.Init и регистрируют свои функции (FX.Xxx / FX.Fn.Xxx / FX.RegisterImpact).
--
-- ПОЛЯ
--   FX.Lite                     -- облегчённый режим (меньше частиц/обломков), ставит ctx.SetLite
--   FX.Colors                   -- Neon Soft Pink White Red Gold Blue Orange (+ CGold Bronze Dial Dust)
--   FX.Folder                   -- workspace.VoidTD_FX (создаётся лениво / в Init)
--   FX.Env                      -- { Renderer, Config, Path, Ctx }; недостающее берётся из ctx
--   FX.Fn                       -- именованные эффекты детей (FX.Fn.GearDisc, FX.Fn.EchoGhost, ...)
--   FX.ProjectileMakers[kind]   -- function(lv) -> part, trailColor?, tipOffset? (CFrame детали "Tip"
--                                  относительно снаряда; по умолчанию CFrame.new(0, 0, -Size.Z/2))
--   FX.Rng                      -- общий Random
--
-- ИНФРАСТРУКТУРА
--   FX.Init(ctx?)                         -- папка, тряска камеры, FX.Env, дети Void/Chrono/Halloween (один раз)
--   FX.SetLite(on)
--   FX.Sound(name, volume?, pitch?, pos?) -- Config.Sounds[name] {Id, Volume, Pitch, Custom}; volume/pitch —
--        множители; pos -> затухание по расстоянию до камеры (>140 studs — тишина); троттлинг 0.07 с на имя
--   FX.Shake(mag, dur)                    -- тряски складываются по максимуму (сильная короткая не теряется)
--   FX.Tween(obj, time, goal, style=Quad, dir=Out) -> Tween
--   FX.Part(props) -> BasePart            -- Class="Part", Anchored, без коллизий/запросов/тени, Neon,
--        Color=Neon, Size=1, Shape?, Transparency=0, CFrame, Parent=FX.Folder; прочие ключи props — как свойства
--   FX.Light(parent, color, range, brightness, life?) -> PointLight (life: яркость гаснет до 0)
--   FX.Cleanup(obj, t)                    -- уничтожить через t с
--   FX.Fade(part, life, goal?)            -- твин goal + Transparency=1, уничтожить через life+0.05
--   FX.Run(fn) -> job                     -- fn(elapsed, dt, now) каждый кадр (общий RenderStepped);
--        вернуть true = закончить; job:Stop(). Ошибка в fn пишет warn и снимает задачу.
--   FX.Ground(pos) -> Vector3             -- (x, Map.GroundY + 0.15, z) активной карты
--   FX.CamFacing(pos) -> CFrame           -- в pos, лицевая сторона (-Z) смотрит на камеру (по горизонтали)
--   FX.EnemyCenter(id), FX.EnemyPosition(id), FX.UnitView(uid), FX.MuzzlePos(view) -- через FX.Env.Renderer
--
-- БАЗОВЫЕ ЭФФЕКТЫ
--   FX.Burst(pos, color=Neon, count=8, size=0.4, speed=6, life=0.45)
--   FX.Ring(pos, radius, color=Neon, life=0.5, height=0.3, startRadius=0.5, transparency=0.15) -> part
--   FX.Sphere(pos, radius, color=Neon, life, material=Neon, startT=0.1) -> part
--   FX.Arc(cf, radius, a0, a1, color=Neon, thickness=0.35, life=0.35, horizontal?)
--   FX.SlashMark(pos, angle, length, width, color=Neon, life=0.35)
--   FX.Cracks(pos, radius, color=Neon, count=8, life=1.4)        -- в Lite не рисуется
--   FX.Projectile(kind, from, getTarget, travel, onHit?, lv=1) -> part
--        getTarget() -> Vector3|nil (или сразу Vector3); встроенные kind: Arrow Orb Crystal Bullet Moon,
--        остальные (Bolt, ...) — стандартный болт; FX.ProjectileMakers[kind] имеют приоритет
--   FX.Beam(from, to, width, color=Neon, life=0.45, big?)
--   FX.Thread(from, to, color=Soft)
--   FX.Poof(pos, color=Neon, size=1)
--   FX.Place(pos) ; FX.LevelUp(pos, color=Neon) ; FX.Summon(pos, radius=6)
--   FX.DamageNumber(pos, amount, flag)    -- flag 1 крит ("N!"), 2 фаза ("PHASE"), иначе обычный
--   FX.Debris(pos, color, count, size, speed, life, material=Slate) -- куски с гравитацией до земли
--   FX.Smoke(pos, color, n, size, life, rise=2)
--   FX.Flash(pos, color, radius, life)    -- шар + вспышка света
--   FX.RuneRing(pos, r, color, life) -> { parts }
--   FX.PortalDisc(pos, r, color, life, edge=(255,235,170))
--
-- УДАРЫ (Impact)
--   FX.RegisterImpact(kind, fn(p))        -- p = payload Impact {K, P, R, L, U, ...}
--   FX.Impact(p) -> handled               -- вызывает зарегистрированный обработчик (pcall)
--   Ядро само регистрирует Smash и Summon (дети могут переопределить).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("VoidTD")
local Config = require(Shared:WaitForChild("Config"))

local FX = {}
FX.Lite = false
FX.Fn = {}
FX.ProjectileMakers = {}
FX.Rng = Random.new()

local V = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles
local rad = math.rad
local rng = FX.Rng

local NEON = Color3.fromRGB(180, 80, 255)
local SOFT = Color3.fromRGB(215, 160, 255)
local PINK = Color3.fromRGB(255, 60, 170)
local WHITE = Color3.fromRGB(250, 245, 255)
local RED = Color3.fromRGB(255, 35, 55)
local GOLD = Color3.fromRGB(255, 205, 80)
local BLUE = Color3.fromRGB(90, 180, 255)
local ORANGE = Color3.fromRGB(255, 140, 40)
local PORTAL_EDGE = Color3.fromRGB(255, 235, 170)
FX.Colors = {
	Neon = NEON, Soft = SOFT, Pink = PINK, White = WHITE, Red = RED, Gold = GOLD, Blue = BLUE, Orange = ORANGE,
	CGold = Color3.fromRGB(230, 178, 74), Bronze = Color3.fromRGB(170, 112, 52), Dial = Color3.fromRGB(16, 12, 20),
	Dust = Color3.fromRGB(70, 60, 82),
}

------------------------------------------------------------------------
-- ОКРУЖЕНИЕ (Renderer/Config/Path для эффектов, которым нужны позиции врагов)
------------------------------------------------------------------------
FX.Env = setmetatable({ Config = Config }, {
	__index = function(env, k)
		local c = rawget(env, "Ctx")
		if c and c[k] ~= nil then
			return c[k]
		end
		if k == "Path" then
			local p = require(Shared:WaitForChild("Path"))
			rawset(env, "Path", p)
			return p
		end
		return nil
	end,
})

local function groundY()
	local path = FX.Env.Path
	local map = path and path.Map
	return (map and map.GroundY) or (Config.Map and Config.Map.GroundY) or 0
end

function FX.Ground(pos)
	return V(pos.X, groundY() + 0.15, pos.Z)
end

function FX.EnemyCenter(id)
	local r = FX.Env.Renderer
	return r and r.EnemyCenter and r.EnemyCenter(id) or nil
end

function FX.EnemyPosition(id)
	local r = FX.Env.Renderer
	return r and r.EnemyPosition and r.EnemyPosition(id) or nil
end

function FX.UnitView(uid)
	local r = FX.Env.Renderer
	return r and r.UnitViews and r.UnitViews[uid] or nil
end

function FX.MuzzlePos(view)
	local r = FX.Env.Renderer
	if r and r.MuzzlePos and view and view.Rig then
		return r.MuzzlePos(view)
	end
	return nil
end

function FX.CamFacing(pos)
	local cam = workspace.CurrentCamera
	local c = cam and cam.CFrame.Position or (pos + V(0, 10, 20))
	local flat = V(c.X, pos.Y, c.Z)
	if (flat - pos).Magnitude < 0.1 then
		return CF(pos)
	end
	return CFrame.lookAt(pos, flat)
end

------------------------------------------------------------------------
-- ИНФРАСТРУКТУРА
------------------------------------------------------------------------
local function getFolder()
	local f = FX.Folder
	if f and f.Parent then
		return f
	end
	f = workspace:FindFirstChild("VoidTD_FX")
	if not f then
		f = Instance.new("Folder")
		f.Name = "VoidTD_FX"
		f.Parent = workspace
	end
	FX.Folder = f
	return f
end

function FX.SetLite(on)
	FX.Lite = on and true or false
end

local function tween(obj, time, goal, style, dir)
	local tw = TweenService:Create(obj, TweenInfo.new(time, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), goal)
	tw:Play()
	return tw
end
FX.Tween = tween

local PART_KEYS = { Class = true, Parent = true, Shape = true, Size = true, Material = true, Color = true, Transparency = true, CFrame = true }

function FX.Part(props)
	props = props or {}
	local p = Instance.new(props.Class or "Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	if props.Shape and p:IsA("Part") then
		p.Shape = props.Shape
	end
	p.Material = props.Material or Enum.Material.Neon
	p.Color = props.Color or NEON
	p.Size = props.Size or V(1, 1, 1)
	p.Transparency = props.Transparency or 0
	p.CFrame = props.CFrame or CF()
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do
		if not PART_KEYS[k] then
			p[k] = v
		end
	end
	p.Parent = props.Parent or getFolder()
	return p
end

local function cleanup(obj, t)
	task.delay(t, function()
		if obj then
			obj:Destroy()
		end
	end)
end
FX.Cleanup = cleanup

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
FX.Light = light

function FX.Fade(p, life, goal)
	goal = goal or {}
	goal.Transparency = 1
	tween(p, life, goal)
	cleanup(p, life + 0.05)
end

-- Общий покадровый цикл: одна подписка RenderStepped на все движущиеся эффекты
local jobs = {}
local stepConn

local function stopJob(job)
	job.Dead = true
end

local function stepJobs(dt)
	local now = os.clock()
	local i = 1
	while i <= #jobs do
		local job = jobs[i]
		local done = job.Dead
		if not done then
			local ok, res = pcall(job.Fn, now - job.T0, dt, now)
			if not ok then
				warn("[FX] " .. tostring(res))
				done = true
			else
				done = res == true
			end
		end
		if done then
			job.Dead = true
			jobs[i] = jobs[#jobs]
			jobs[#jobs] = nil
		else
			i += 1
		end
	end
end

function FX.Run(fn)
	local job = { Fn = fn, T0 = os.clock(), Dead = false, Stop = stopJob }
	jobs[#jobs + 1] = job
	if not stepConn then
		stepConn = RunService.RenderStepped:Connect(stepJobs)
	end
	return job
end

------------------------------------------------------------------------
-- ЗВУКИ (встроенные звуки Roblox; Custom = свой ассет)
------------------------------------------------------------------------
local lastSound = {}

function FX.Sound(name, volume, pitch, pos)
	local def = Config.Sounds and Config.Sounds[name]
	if not def then
		return
	end
	local t = os.clock()
	local last = lastSound[name]
	if last and t - last < 0.07 then
		return
	end
	volume = (volume or 1) * (def.Volume or 0.4)
	-- далёкие звуки тише
	if pos then
		local cam = workspace.CurrentCamera
		local d = cam and (cam.CFrame.Position - pos).Magnitude or 0
		if d > 140 then
			return
		end
		volume *= math.clamp(1 - d / 140, 0.15, 1)
	end
	lastSound[name] = t
	local custom = type(def.Custom) == "string" and def.Custom ~= ""
	local s = Instance.new("Sound")
	s.Name = "VoidTD_" .. tostring(name)
	s.SoundId = custom and def.Custom or (def.Id or "")
	s.Volume = volume
	s.PlaybackSpeed = (pitch or 1) * (custom and 1 or (def.Pitch or 1))
	s.Parent = SoundService
	s:Play()
	cleanup(s, 4)
end

------------------------------------------------------------------------
-- ТРЯСКА КАМЕРЫ
------------------------------------------------------------------------
-- активные тряски; сила в момент t = (Until - t) / Dur * Mag, итог — максимум
local shakes = {}
local MAX_SHAKES = 8
local shakeOffset, shakeApplied -- что добавили к камере в этом кадре (снимаем в начале следующего)

function FX.Shake(mag, dur)
	if type(mag) ~= "number" or type(dur) ~= "number" or mag <= 0 or dur <= 0 then
		return
	end
	local t = os.clock()
	for i = #shakes, 1, -1 do
		if t >= shakes[i].Until then
			table.remove(shakes, i)
		end
	end
	local entry = { Until = t + dur, Dur = dur, Mag = mag }
	if #shakes < MAX_SHAKES then
		shakes[#shakes + 1] = entry
	else
		-- заменяем самую слабую
		local weakest, wv = 1, math.huge
		for i, s in ipairs(shakes) do
			local v = (s.Until - t) / s.Dur * s.Mag
			if v < wv then
				weakest, wv = i, v
			end
		end
		shakes[weakest] = entry
	end
end

local function shakeAmount(t)
	local k = 0
	for i = #shakes, 1, -1 do
		local s = shakes[i]
		if t >= s.Until then
			table.remove(shakes, i)
		else
			local v = (s.Until - t) / s.Dur * s.Mag
			if v > k then
				k = v
			end
		end
	end
	return k
end

local function sameCFrame(a, b)
	return (a.Position - b.Position).Magnitude < 1e-3 and a.LookVector:Dot(b.LookVector) > 0.99999 and a.UpVector:Dot(b.UpVector) > 0.99999
end

-- до камерных скриптов: снять прошлое смещение (иначе Scriptable-камера «уплывает»)
local function shakeUndo()
	local cam = workspace.CurrentCamera
	if shakeApplied and cam and sameCFrame(cam.CFrame, shakeApplied) then
		cam.CFrame = shakeApplied * shakeOffset:Inverse()
	end
	shakeApplied, shakeOffset = nil, nil
end

-- после камерных скриптов: добавить смещение
local function shakeApply()
	local k = shakeAmount(os.clock())
	if k <= 0 then
		return
	end
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	local off = CF(rng:NextNumber(-k, k), rng:NextNumber(-k, k), 0) * ANG(0, 0, rng:NextNumber(-k, k) * 0.03)
	local cf = cam.CFrame * off
	cam.CFrame = cf
	shakeOffset, shakeApplied = off, cf
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
		local p = FX.Part({ Size = V(size, size, size), CFrame = CF(pos) * ANG(rng:NextNumber(0, 6), rng:NextNumber(0, 6), 0), Color = color or NEON })
		tween(p, life, {
			CFrame = CF(pos + dir * speed * life) * ANG(rng:NextNumber(0, 6), rng:NextNumber(0, 6), 0),
			Transparency = 1,
			Size = V(0.05, 0.05, 0.05),
		})
		cleanup(p, life + 0.05)
	end
end

-- плоское кольцо, расширяющееся по земле
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
	life = life or 0.35
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

-- дуга из 9 сегментов (след оружия); horizontal — в плоскости XZ кадра cf
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
			local p = FX.Part({ Size = V(w, w * 0.5, len + w), CFrame = CFrame.lookAt((pt + prev) / 2, pt), Color = color or NEON, Transparency = 0.05 })
			local delay = i / segs * 0.06
			task.delay(delay, function()
				tween(p, life, { Transparency = 1, Size = V(w * 0.2, w * 0.1, len) })
			end)
			cleanup(p, life + delay + 0.05)
		end
		prev = pt
	end
end

-- полоса-разрез с белой сердцевиной
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

-- трещины в земле с ответвлениями и тёмное пятно
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
local function tipPart(parent, size, color)
	local tip = FX.Part({ Size = size, Color = color, Parent = parent })
	tip.Name = "Tip"
	return tip
end

-- встроенные снаряды легаси
local function builtinProjectile(kind, lv)
	if kind == "Arrow" then
		local p = FX.Part({ Size = V(0.18, 0.18, 2.2), Color = lv >= 4 and NEON or SOFT })
		tipPart(p, V(0.35, 0.35, 0.35), NEON)
		return p
	elseif kind == "Orb" then
		local s = 0.7 + lv * 0.1
		local p = FX.Part({ Shape = Enum.PartType.Ball, Size = V(s, s, s), Color = NEON })
		light(p, NEON, 8, 2)
		return p
	elseif kind == "Crystal" then
		local p = FX.Part({ Size = V(0.4, 0.4, 1.3), Color = Color3.fromRGB(110, 190, 255) })
		light(p, Color3.fromRGB(80, 170, 255), 7, 2)
		return p
	elseif kind == "Bullet" then
		return FX.Part({ Size = V(0.15, 0.15, 0.9), Color = Color3.fromRGB(255, 90, 80) })
	elseif kind == "Moon" then
		local p = FX.Part({ Shape = Enum.PartType.Cylinder, Size = V(0.2, 1.2, 1.2), Color = Color3.fromRGB(255, 200, 215) })
		light(p, Color3.fromRGB(255, 120, 150), 8, 2)
		return p
	end
	-- Bolt и прочие
	return FX.Part({ Size = V(0.25, 0.25, 1.4 + lv * 0.15), Color = lv >= 5 and PINK or SOFT })
end

-- getTarget() -> Vector3|nil (текущая позиция цели) или Vector3
function FX.Projectile(kind, from, getTarget, travel, onHit, lv)
	lv = lv or 1
	local p, trailColor, tipOffset
	local maker = FX.ProjectileMakers[kind]
	if maker then
		p, trailColor, tipOffset = maker(lv)
	end
	if not p then
		p = builtinProjectile(kind, lv)
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
	trail.Color = ColorSequence.new(trailColor or (kind == "Orb" and NEON or SOFT))
	trail.LightEmission = 1
	trail.Lifetime = 0.18
	trail.Transparency = NumberSequence.new(0.2, 1)
	trail.WidthScale = NumberSequence.new(kind == "Orb" and 3 or 1, 0)
	trail.Parent = p

	-- деталь "Tip" (наконечник/лицо/пробка) якорная — двигаем вручную вместе со снарядом
	local tip = p:FindFirstChild("Tip")
	if tip then
		tipOffset = tipOffset or CF(0, 0, -p.Size.Z / 2)
	end
	local fixed = typeof(getTarget) == "Vector3" and getTarget or nil
	local function target()
		if fixed then
			return fixed
		end
		return getTarget and getTarget() or nil
	end
	local function place(pos, aim)
		local cf = ((aim - pos).Magnitude > 0.01) and CFrame.lookAt(pos, aim) or CF(pos)
		p.CFrame = cf
		if tip then
			tip.CFrame = cf * tipOffset
		end
	end

	local last = target() or from
	place(from, last)
	local arc = kind == "Arrow"
	local dur = math.max(travel or 0.2, 0.01)
	FX.Run(function(el)
		if not p.Parent then
			return true
		end
		local alpha = math.clamp(el / dur, 0, 1)
		local tg = target() or last
		last = tg
		local pos = from:Lerp(tg, alpha)
		if arc then
			pos += V(0, math.sin(alpha * math.pi) * 1.2, 0)
		end
		place(pos, tg)
		if alpha >= 1 then
			p:Destroy()
			if onHit then
				onHit(tg)
			end
			return true
		end
		return false
	end)
	return p
end

function FX.Beam(from, to, width, color, life, big)
	life = life or 0.45
	color = color or NEON
	local len = (to - from).Magnitude
	local cf = CFrame.lookAt((from + to) / 2, to) * ANG(0, rad(90), 0)
	local outer = FX.Part({ Shape = Enum.PartType.Cylinder, Size = V(len, width * 0.2, width * 0.2), CFrame = cf, Color = color, Transparency = 0.15 })
	local inner = FX.Part({ Shape = Enum.PartType.Cylinder, Size = V(len, width * 0.1, width * 0.1), CFrame = cf, Color = WHITE })
	tween(outer, 0.1, { Size = V(len, width, width) }, Enum.EasingStyle.Back)
	tween(inner, 0.1, { Size = V(len, width * 0.45, width * 0.45) }, Enum.EasingStyle.Back)
	light(inner, color, 16, 4, life)
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
		local ring = FX.Part({
			Shape = Enum.PartType.Cylinder,
			Size = V(0.15, width * 1.6, width * 1.6),
			CFrame = (((to - pt).Magnitude > 0.01) and CFrame.lookAt(pt, to) or CF(pt)) * ANG(0, rad(90), 0),
			Color = color,
			Transparency = 0.3,
		})
		tween(ring, life, { Size = V(0.05, width * 3.5, width * 3.5), Transparency = 1 })
		cleanup(ring, life + 0.05)
	end
	FX.Sphere(to, width * 1.8, color, 0.35)
	FX.Burst(to, color, big and 16 or 8, 0.5, 10)
	FX.Sphere(from, width, WHITE, 0.25)
end

-- нить от руки к цели
function FX.Thread(from, to, color)
	local len = (to - from).Magnitude
	if len < 0.1 then
		return
	end
	local p = FX.Part({ Size = V(0.08, 0.08, len), CFrame = CFrame.lookAt((from + to) / 2, to), Color = color or SOFT })
	tween(p, 0.5, { Transparency = 1, Size = V(0.02, 0.02, len) })
	cleanup(p, 0.55)
	FX.Ring(to - V(0, 1, 0), 2, color or NEON, 0.35, 0.2)
end

------------------------------------------------------------------------
-- ОБЩИЕ СОБЫТИЯ
------------------------------------------------------------------------
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
	FX.Burst(pos + V(0, 3, 0), color or SOFT, 14, 0.35, 7, 0.7)
end

function FX.Place(pos)
	FX.Sound("Place", 1, 1, pos)
	FX.Ring(pos + V(0, 0.2, 0), 3.5, SOFT, 0.45, 0.25)
	FX.Burst(pos + V(0, 0.5, 0), Color3.fromRGB(70, 60, 80), 8, 0.4, 5)
end

------------------------------------------------------------------------
-- ЦИФРЫ УРОНА
------------------------------------------------------------------------
local numberCount = 0

function FX.DamageNumber(pos, amount, flag)
	if numberCount > (FX.Lite and 20 or 70) then
		return
	end
	numberCount += 1
	local anchor = FX.Part({ Size = V(0.1, 0.1, 0.1), CFrame = CF(pos), Transparency = 1 })
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(120, 40)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 220
	gui.StudsOffsetWorldSpace = V(rng:NextNumber(-0.8, 0.8), 0, rng:NextNumber(-0.8, 0.8))
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
	gui.Parent = anchor
	tween(gui, 0.8, { StudsOffsetWorldSpace = gui.StudsOffsetWorldSpace + V(0, 2.5, 0) })
	task.delay(0.35, function()
		tween(label, 0.45, { TextTransparency = 1, TextStrokeTransparency = 1 })
	end)
	task.delay(0.85, function()
		numberCount -= 1
		anchor:Destroy()
	end)
end

------------------------------------------------------------------------
-- ОБЛОМКИ, ДЫМ, ВСПЫШКИ, РУНЫ, ПОРТАЛЫ
------------------------------------------------------------------------
-- куски с гравитацией (камни, кость, солома, щепки); не проваливаются ниже земли
function FX.Debris(pos, color, count, size, speed, life, material)
	count = count or 6
	if FX.Lite then
		count = math.min(3, count)
	end
	size = size or 0.5
	speed = speed or 8
	life = life or 0.9
	local floor = groundY()
	local pieces = {}
	for i = 1, count do
		local s = size * rng:NextNumber(0.6, 1.3)
		pieces[i] = {
			P = FX.Part({ Size = V(s, s * 0.8, s * 1.1), CFrame = CF(pos) * ANG(rng:NextNumber(0, 6), rng:NextNumber(0, 6), 0), Color = color, Material = material or Enum.Material.Slate }),
			S = s,
			Vel = V(rng:NextNumber(-1, 1), rng:NextNumber(0.6, 1.4), rng:NextNumber(-1, 1)) * speed,
			SpinX = rng:NextNumber(-8, 8),
			SpinY = rng:NextNumber(-8, 8),
		}
	end
	local fadeFrom = life * 0.6
	FX.Run(function(t)
		local over = t >= life
		for _, d in ipairs(pieces) do
			local p = d.P
			if over then
				p:Destroy()
			elseif p.Parent then
				local q = pos + d.Vel * t + V(0, -30 * t * t, 0)
				q = V(q.X, math.max(q.Y, floor + d.S * 0.4), q.Z)
				p.CFrame = CF(q) * ANG(d.SpinX * t, d.SpinY * t, 0)
				if t > fadeFrom then
					p.Transparency = (t - fadeFrom) / (life * 0.4)
				end
			end
		end
		return over
	end)
end

-- дымное облако из полупрозрачных шаров
function FX.Smoke(pos, color, n, size, life, rise)
	n = n or 3
	if FX.Lite then
		n = math.min(n, 2)
	end
	size = size or 2
	life = life or 1
	for _ = 1, n do
		local s = size * rng:NextNumber(0.7, 1.2)
		local p = FX.Part({
			Shape = Enum.PartType.Ball,
			Size = V(s, s, s),
			CFrame = CF(pos + V(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1)) * size * 0.4),
			Color = color,
			Material = Enum.Material.SmoothPlastic,
			Transparency = 0.45,
		})
		FX.Fade(p, life * rng:NextNumber(0.8, 1.2), { Size = V(s, s, s) * 1.9, CFrame = p.CFrame + V(rng:NextNumber(-1, 1), rise or 2, rng:NextNumber(-1, 1)) })
	end
end

-- вспышка: шар + точечный свет
function FX.Flash(pos, color, radius, life)
	FX.Sphere(pos, radius, color, life or 0.3)
	local a = FX.Part({ Size = V(0.2, 0.2, 0.2), CFrame = CF(pos), Transparency = 1 })
	light(a, color, radius * 4, 4, life or 0.35)
	cleanup(a, (life or 0.35) + 0.05)
end

-- кольцо рун на земле: 8 знаков, крест и диск; гаснет в последние 40% жизни
function FX.RuneRing(pos, r, color, life)
	local g = FX.Ground(pos)
	local list = {}
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		list[#list + 1] = FX.Part({ Size = V(0.4, 0.06, 1.2), CFrame = CF(g + V(math.cos(a) * r, 0.05, math.sin(a) * r)) * ANG(0, -a, 0), Color = color })
	end
	for i = 0, 1 do
		list[#list + 1] = FX.Part({ Size = V(r * 1.5, 0.05, 0.22), CFrame = CF(g + V(0, 0.04, 0)) * ANG(0, i * math.pi / 2 + rad(45), 0), Color = color, Transparency = 0.3 })
	end
	list[#list + 1] = FX.Part({ Shape = Enum.PartType.Cylinder, Size = V(0.06, r * 2.2, r * 2.2), CFrame = CF(g) * ANG(0, 0, rad(90)), Color = color, Transparency = 0.55 })
	task.delay(life * 0.6, function()
		for _, p in ipairs(list) do
			FX.Fade(p, life * 0.4)
		end
	end)
	return list
end

-- вертикальный диск портала, повёрнутый к камере
function FX.PortalDisc(pos, r, color, life, edge)
	local cam = workspace.CurrentCamera
	local look = cam and (cam.CFrame.Position - pos) or V(0, 0, 1)
	local flat = V(look.X, 0, look.Z)
	if flat.Magnitude < 0.01 then
		flat = V(0, 0, 1)
	end
	local cf = CFrame.lookAt(pos, pos + flat) * ANG(0, rad(90), 0)
	local disc = FX.Part({ Shape = Enum.PartType.Cylinder, Size = V(0.2, 0.2, 0.2), CFrame = cf, Color = color, Transparency = 0.2 })
	tween(disc, 0.25, { Size = V(0.2, r * 2, r * 2) }, Enum.EasingStyle.Back)
	local rim = FX.Part({ Shape = Enum.PartType.Cylinder, Size = V(0.15, 0.3, 0.3), CFrame = cf * CF(-0.05, 0, 0), Color = edge or PORTAL_EDGE, Transparency = 0.1 })
	tween(rim, 0.25, { Size = V(0.15, r * 2.25, r * 2.25) }, Enum.EasingStyle.Back)
	light(disc, color, r * 5, 3, life)
	task.delay(life * 0.7, function()
		FX.Fade(disc, life * 0.3, { Size = V(0.2, 0.2, 0.2) })
		FX.Fade(rim, life * 0.3, { Size = V(0.15, 0.3, 0.3) })
	end)
	return disc, rim
end

------------------------------------------------------------------------
-- РЕЕСТР УДАРОВ (Impact)
------------------------------------------------------------------------
local impacts = {}
FX.Impacts = impacts

function FX.RegisterImpact(kind, fn)
	impacts[kind] = fn
end

function FX.Impact(p)
	if type(p) ~= "table" or p.K == nil then
		return false
	end
	local fn = impacts[p.K]
	if not fn then
		return false
	end
	local ok, err = pcall(fn, p)
	if not ok then
		warn("[FX] Impact " .. tostring(p.K) .. ": " .. tostring(err))
	end
	return true
end

-- удары, которым хватает ядра (дети могут переопределить)
FX.RegisterImpact("Smash", function(p)
	local lv = p.L or 1
	local R = p.R or 6
	local g = V(p.P.X, p.P.Y + 0.2, p.P.Z)
	FX.Ring(g, R, NEON, 0.4, 0.4, 1, 0.1)
	FX.Cracks(g, R, NEON, 5 + lv, 1.0)
	FX.Burst(g + V(0, 1, 0), Color3.fromRGB(60, 50, 70), 8 + lv, 0.5, 9)
end)

FX.RegisterImpact("Summon", function(p)
	FX.Summon(p.P, p.R)
end)

------------------------------------------------------------------------
-- ИНИЦИАЛИЗАЦИЯ
------------------------------------------------------------------------
local CHILDREN = { "Void", "Chrono", "Halloween" }
local inited = false

function FX.Init(ctx)
	local env = FX.Env
	if ctx then
		rawset(env, "Ctx", ctx)
		if ctx.Config then
			rawset(env, "Config", ctx.Config)
		end
		if ctx.Path then
			rawset(env, "Path", ctx.Path)
		end
		if ctx.Renderer then
			rawset(env, "Renderer", ctx.Renderer)
		end
		if ctx.Lite ~= nil then
			FX.SetLite(ctx.Lite)
		end
	end
	getFolder()
	if inited then
		return FX
	end
	inited = true
	if RunService:IsClient() then
		RunService:BindToRenderStep("VoidTD_ShakeUndo", Enum.RenderPriority.First.Value, shakeUndo)
		RunService:BindToRenderStep("VoidTD_Shake", Enum.RenderPriority.Camera.Value + 1, shakeApply)
	end
	-- эффекты способностей
	for _, name in ipairs(CHILDREN) do
		local mod = script:FindFirstChild(name)
		if mod and mod:IsA("ModuleScript") then
			local ok, install = pcall(require, mod)
			if not ok then
				warn("[FX] " .. name .. ": " .. tostring(install))
			elseif type(install) == "function" then
				local ok2, err = pcall(install, FX)
				if not ok2 then
					warn("[FX] " .. name .. ": " .. tostring(err))
				end
			end
		end
	end
	return FX
end

-- локальный игрок (нужен эффектам, которые реагируют только на свои юниты)
FX.LocalPlayer = Players.LocalPlayer

return FX
