--!nocheck
-- VOID TD :: HalloweenFX (клиент)
-- Эффекты Хэллоуина: атаки и способности 11 юнитов, руны, союзники на дороге (модели, ходьба, HP),
-- состояния и смерти хэллоуинских врагов, появление боссов. Только визуал — урон считает сервер.

local RunService = game:GetService("RunService")

local HFX = {}

local V = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles
local rad = math.rad

local ctx, Config, PathUtil, UnitModels, FX, Renderer
local rng = Random.new()

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local COL = {
	Orange = rgb(255, 140, 40),
	Ember = rgb(255, 90, 20),
	Fire = rgb(255, 180, 70),
	Light = rgb(255, 235, 170),
	Green = rgb(120, 255, 110),
	Poison = rgb(140, 230, 80),
	PoisonDark = rgb(60, 110, 40),
	Blue = rgb(90, 170, 255),
	Ghost = rgb(170, 220, 255),
	Purple = rgb(180, 90, 255),
	Red = rgb(230, 30, 50),
	Gold = rgb(255, 205, 80),
	Straw = rgb(220, 190, 110),
	Dirt = rgb(110, 85, 60),
	Stone = rgb(120, 112, 104),
	Leaf = rgb(230, 140, 40),
	Bell = rgb(190, 160, 255),
	Bone = rgb(230, 222, 205),
	Black = rgb(16, 12, 18),
	Smoke = rgb(90, 90, 96),
	FogC = rgb(160, 170, 160),
}
HFX.Colors = COL

local function part(props)
	return FX.Part(props)
end

local function fade(p, life, goal)
	goal = goal or {}
	goal.Transparency = 1
	FX.Tween(p, life, goal)
	task.delay(life + 0.05, function()
		p:Destroy()
	end)
end

local function ground(pos)
	return V(pos.X, PathUtil.Map.GroundY + 0.15, pos.Z)
end

local function plight(p, color, range, brightness, life)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Shadows = false
	l.Parent = p
	if life then
		FX.Tween(l, life, { Brightness = 0 })
	end
	return l
end

-- обломки: куски с гравитацией (камни, кость, солома, щепки)
local function debris(pos, color, count, size, speed, life, material)
	if FX.Lite then
		count = math.min(3, count)
	end
	for _ = 1, count do
		local s = size * rng:NextNumber(0.6, 1.3)
		local p = part({ Size = V(s, s * 0.8, s * 1.1), CFrame = CF(pos) * ANG(rng:NextNumber(0, 6), rng:NextNumber(0, 6), 0), Color = color, Material = material or Enum.Material.Slate })
		local v = V(rng:NextNumber(-1, 1), rng:NextNumber(0.6, 1.4), rng:NextNumber(-1, 1)) * speed
		local t0 = os.clock()
		local spin = V(rng:NextNumber(-8, 8), rng:NextNumber(-8, 8), 0)
		local conn
		conn = RunService.RenderStepped:Connect(function()
			local t = os.clock() - t0
			if t >= life or not p.Parent then
				conn:Disconnect()
				if p.Parent then
					p:Destroy()
				end
				return
			end
			local q = pos + v * t + V(0, -30 * t * t, 0)
			q = V(q.X, math.max(q.Y, PathUtil.Map.GroundY + s * 0.4), q.Z)
			p.CFrame = CF(q) * ANG(spin.X * t, spin.Y * t, 0)
			if t > life * 0.6 then
				p.Transparency = (t - life * 0.6) / (life * 0.4)
			end
		end)
	end
end

-- дымное облако из полупрозрачных шаров
local function smoke(pos, color, n, size, life, rise)
	if FX.Lite then
		n = math.min(n, 2)
	end
	for _ = 1, n do
		local s = size * rng:NextNumber(0.7, 1.2)
		local p = part({ Shape = Enum.PartType.Ball, Size = V(s, s, s), CFrame = CF(pos + V(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1)) * size * 0.4), Color = color, Material = Enum.Material.SmoothPlastic, Transparency = 0.45 })
		fade(p, life * rng:NextNumber(0.8, 1.2), { Size = V(s, s, s) * 1.9, CFrame = p.CFrame + V(rng:NextNumber(-1, 1), rise or 2, rng:NextNumber(-1, 1)) })
	end
end

-- вспышка света
local function flash(pos, color, radius, life)
	FX.Sphere(pos, radius, color, life or 0.3)
	local a = part({ Size = V(0.2, 0.2, 0.2), CFrame = CF(pos), Transparency = 1 })
	plight(a, color, radius * 4, 4, life or 0.35)
	task.delay((life or 0.35) + 0.05, function()
		a:Destroy()
	end)
end

-- кольцо рун на земле
local function runeRing(pos, r, color, life)
	local list = {}
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		list[#list + 1] = part({ Size = V(0.4, 0.06, 1.2), CFrame = CF(ground(pos) + V(math.cos(a) * r, 0.05, math.sin(a) * r)) * ANG(0, -a, 0), Color = color })
	end
	for i = 0, 1 do
		list[#list + 1] = part({ Size = V(r * 1.5, 0.05, 0.22), CFrame = CF(ground(pos) + V(0, 0.04, 0)) * ANG(0, i * math.pi / 2 + rad(45), 0), Color = color, Transparency = 0.3 })
	end
	local ring = part({ Shape = Enum.PartType.Cylinder, Size = V(0.06, r * 2.2, r * 2.2), CFrame = CF(ground(pos)) * ANG(0, 0, rad(90)), Color = color, Transparency = 0.55 })
	list[#list + 1] = ring
	for _, p in ipairs(list) do
		task.delay(life * 0.6, function()
			fade(p, life * 0.4)
		end)
	end
	return list
end

-- вертикальный портал-диск
local function portalDisc(pos, r, color, life, edge)
	local cam = workspace.CurrentCamera
	local look = cam and (cam.CFrame.Position - pos) or V(0, 0, 1)
	local cf = CFrame.lookAt(pos, pos + V(look.X, 0, look.Z))
	local disc = part({ Shape = Enum.PartType.Cylinder, Size = V(0.2, 0.2, 0.2), CFrame = cf * ANG(0, rad(90), 0), Color = color, Transparency = 0.2 })
	FX.Tween(disc, 0.25, { Size = V(0.2, r * 2, r * 2) }, Enum.EasingStyle.Back)
	local rim = part({ Shape = Enum.PartType.Cylinder, Size = V(0.15, 0.3, 0.3), CFrame = cf * ANG(0, rad(90), 0) * CF(-0.05, 0, 0), Color = edge or COL.Light, Transparency = 0.1 })
	FX.Tween(rim, 0.25, { Size = V(0.15, r * 2.25, r * 2.25) }, Enum.EasingStyle.Back)
	plight(disc, color, r * 5, 3, life)
	task.delay(life * 0.7, function()
		fade(disc, life * 0.3, { Size = V(0.2, 0.2, 0.2) })
		fade(rim, life * 0.3, { Size = V(0.15, 0.3, 0.3) })
	end)
end

-- птица (ворон) — пара крыльев и тело
local function bird(color)
	local m = Instance.new("Model")
	local body = part({ Size = V(0.5, 0.45, 0.9), Color = color or COL.Black, Material = Enum.Material.SmoothPlastic, Parent = m })
	for _, s in ipairs({ -1, 1 }) do
		local w = part({ Class = "WedgePart", Size = V(0.1, 0.5, 1.2), Color = color or COL.Black, Material = Enum.Material.SmoothPlastic, Parent = m })
		w.Name = s == 1 and "WR" or "WL"
	end
	m.PrimaryPart = body
	m.Parent = workspace:FindFirstChild("VoidTD_FX") or workspace
	return m, body
end

local function placeBird(m, cf, flap)
	local body = m.PrimaryPart
	body.CFrame = cf
	m.WR.CFrame = cf * CF(0.55, 0.1, 0) * ANG(0, 0, rad(-60 + flap))
	m.WL.CFrame = cf * CF(-0.55, 0.1, 0) * ANG(0, 0, rad(60 - flap))
end

-- вороны кружат вокруг точки
local function crowCircle(pos, r, n, life, color)
	if FX.Lite then
		n = 1
	end
	local birds = {}
	for i = 1, n do
		birds[i] = { bird(color), i / n * math.pi * 2, rng:NextNumber(2, 4.5) }
	end
	local t0 = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		for _, b in ipairs(birds) do
			local a = b[2] + t * 2.4
			local p = pos + V(math.cos(a) * r, b[3] + math.sin(t * 3 + b[2]) * 0.4, math.sin(a) * r)
			local fwd = V(-math.sin(a), 0, math.cos(a))
			placeBird(b[1], CFrame.lookAt(p, p + fwd), math.sin(t * 18 + b[2]) * 40)
		end
		if t >= life then
			conn:Disconnect()
			for _, b in ipairs(birds) do
				b[1]:Destroy()
			end
		end
	end)
end

-- ворон летит от точки к точке (снаряд пугала)
local function crowFly(from, getTarget, travel, onHit)
	local m = bird()
	local t0 = os.clock()
	local last = getTarget() or from
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local a = math.clamp((os.clock() - t0) / math.max(travel, 0.05), 0, 1)
		local target = getTarget() or last
		last = target
		local p = from:Lerp(target, a) + V(0, math.sin(a * math.pi) * 2, 0)
		local dir = target - p
		placeBird(m, (dir.Magnitude > 0.05) and CFrame.lookAt(p, target) or CF(p), math.sin(os.clock() * 25) * 45)
		if a >= 1 then
			conn:Disconnect()
			m:Destroy()
			if onHit then
				onHit(target)
			end
		end
	end)
end

------------------------------------------------------------------------
-- СНАРЯДЫ (через FX.ProjectileMakers)
------------------------------------------------------------------------
local function installProjectiles()
	FX.ProjectileMakers = FX.ProjectileMakers or {}
	FX.ProjectileMakers.CurseBullet = function(lv)
		local p = part({ Size = V(0.22, 0.22, 1.1), Color = COL.Green })
		plight(p, COL.Green, 6, 2)
		return p, COL.Green
	end
	FX.ProjectileMakers.Flask = function(lv)
		local p = part({ Size = V(0.5, 0.7, 0.5), Color = COL.Poison, Material = Enum.Material.Glass, Transparency = 0.2 })
		local cork = part({ Size = V(0.25, 0.25, 0.25), Color = COL.Dirt, Material = Enum.Material.Wood, Parent = p })
		cork.Name = "Tip"
		plight(p, COL.Poison, 6, 1.5)
		return p, COL.Poison
	end
	FX.ProjectileMakers.Card = function(lv)
		local p = part({ Size = V(0.6, 0.06, 0.9), Color = rgb(245, 240, 250), Material = Enum.Material.SmoothPlastic })
		local mark = part({ Size = V(0.25, 0.08, 0.25), Color = COL.Purple, Parent = p })
		mark.Name = "Tip"
		return p, COL.Purple
	end
	FX.ProjectileMakers.Pumpkin = function(lv)
		local s = 1 + lv * 0.08
		local p = part({ Size = V(1.1 * s, 0.9 * s, 1.1 * s), Color = rgb(230, 110, 30), Material = Enum.Material.SmoothPlastic })
		local face = part({ Size = V(0.6 * s, 0.25 * s, 0.1), Color = COL.Fire, Parent = p })
		face.Name = "Tip"
		plight(p, COL.Orange, 10, 2.5)
		return p, COL.Ember
	end
end

------------------------------------------------------------------------
-- УДАРЫ И СПОСОБНОСТИ (Impact)
------------------------------------------------------------------------
local IMPACT = {}

IMPACT.LightFlash = function(p)
	local g = ground(p.P)
	flash(g + V(0, 1.5, 0), COL.Light, p.R * 0.6, 0.3)
	FX.Ring(g, p.R, COL.Light, 0.35, 0.2, 0.5, 0.3)
	FX.Sound("Magic", 0.6, 1.6, g)
end

IMPACT.LanternBeam = function(p)
	local g = ground(p.P)
	local beam = part({ Shape = Enum.PartType.Cylinder, Size = V(30, 0.5, 0.5), CFrame = CF(g + V(0, 15, 0)) * ANG(0, 0, rad(90)), Color = COL.Light, Transparency = 0.2 })
	FX.Tween(beam, 0.15, { Size = V(30, p.R * 1.2, p.R * 1.2) })
	task.delay(0.2, function()
		fade(beam, 0.4, { Size = V(30, 0.2, 0.2) })
	end)
	FX.Ring(g, p.R, COL.Fire, 0.5, 0.3, 1, 0.1)
	flash(g + V(0, 2, 0), COL.Light, p.R * 0.7, 0.45)
	FX.Burst(g + V(0, 1, 0), COL.Fire, 12, 0.35, 9)
	FX.Sound("Laser", 0.8, 1.4, g)
end

IMPACT.DirtBurst = function(p)
	local g = ground(p.P)
	FX.Ring(g, p.R, COL.Dirt, 0.45, 0.4, 1, 0.1)
	FX.Cracks(g, p.R, rgb(70, 50, 36), 6, 1.1)
	debris(g + V(0, 0.5, 0), COL.Stone, 8, 0.6, 9, 0.9)
	debris(g + V(0, 0.5, 0), COL.Dirt, 6, 0.45, 7, 0.8, Enum.Material.Ground)
	smoke(g + V(0, 1, 0), rgb(120, 100, 80), 4, 3, 0.9, 2.5)
	FX.Sound("HeavyHit", 0.8, 0.8, g)
end

IMPACT.LeafStorm = function(p)
	local g = ground(p.P)
	FX.Ring(g, p.R, COL.Leaf, 0.6, 0.25, 1, 0.3)
	local n = FX.Lite and 6 or 18
	local leaves = {}
	for i = 1, n do
		leaves[i] = { part({ Size = V(0.5, 0.06, 0.35), Color = (i % 3 == 0) and COL.Ember or COL.Leaf, Material = Enum.Material.SmoothPlastic }), rng:NextNumber(0, 6.28), rng:NextNumber(0.5, 1) }
	end
	local t0 = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		for _, l in ipairs(leaves) do
			local a = l[2] + t * 7
			local r = p.R * l[3] * (0.4 + t * 0.5)
			l[1].CFrame = CF(g + V(math.cos(a) * r, t * 4 * l[3] + 0.5, math.sin(a) * r)) * ANG(t * 9, a, 0)
			l[1].Transparency = math.clamp((t - 0.9) / 0.4, 0, 1)
		end
		if t >= 1.3 then
			conn:Disconnect()
			for _, l in ipairs(leaves) do
				l[1]:Destroy()
			end
		end
	end)
	crowCircle(g, p.R * 0.6, 2, 1.3)
	FX.Sound("Slash", 0.6, 0.6, g)
end

IMPACT.CurseMark = function(p)
	local id = p.I
	local c = Renderer.EnemyCenter(id) or p.P
	flash(c, COL.Green, 2.5, 0.3)
	FX.Burst(c, COL.Green, 10, 0.35, 8)
	-- знак проклятия над врагом: ромб и череп-рамка, держится DUR
	local mark = part({ Size = V(1, 1, 0.15), Color = COL.Green })
	local inner = part({ Size = V(0.45, 0.45, 0.2), Color = COL.Black, Material = Enum.Material.SmoothPlastic })
	local t0 = os.clock()
	local dur = p.DUR or 3
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		local view = Renderer.EnemyViews[id]
		if t >= dur or not view then
			conn:Disconnect()
			fade(mark, 0.2)
			fade(inner, 0.2)
			return
		end
		local top = view.Rig.Root.Position + V(0, view.Rig.Height - view.Rig.HipHeight + 1.2, 0)
		local cf = CF(top) * ANG(0, t * 3, rad(45))
		mark.CFrame = cf
		inner.CFrame = cf
	end)
	FX.Sound("Magic", 0.8, 0.6, c)
end

IMPACT.BellWave = function(p)
	local g = ground(p.P)
	FX.Ring(g + V(0, 0.2, 0), p.R, COL.Bell, 0.55, 0.5, 1, 0.25)
	task.delay(0.12, function()
		FX.Ring(g + V(0, 0.6, 0), p.R * 0.8, rgb(230, 220, 255), 0.45, 0.3, 1, 0.4)
	end)
	FX.Sound("Magic", 0.8, 0.45, g)
end

IMPACT.MidnightToll = function(p)
	local g = ground(p.P)
	for i = 0, 2 do
		task.delay(i * 0.15, function()
			FX.Ring(g + V(0, 0.3 + i * 0.4, 0), p.R * (1 - i * 0.12), i == 1 and COL.Purple or COL.Bell, 0.7, 0.6, 1, 0.15)
		end)
	end
	flash(g + V(0, 3, 0), COL.Bell, 4, 0.5)
	if FX.TinyClock then
		for i = 0, 2 do
			local a = i / 3 * math.pi * 2
			FX.TinyClock(g + V(math.cos(a) * p.R * 0.5, 3.5, math.sin(a) * p.R * 0.5), 1.4, 1.4, 4)
		end
	end
	FX.Shake(0.15, 0.3)
	FX.Sound("Boss", 0.5, 1.6, g)
end

IMPACT.FlaskSplash = function(p)
	local g = ground(p.P)
	FX.Burst(g + V(0, 1, 0), COL.Poison, 10, 0.35, 8)
	FX.Ring(g, p.R, COL.Poison, 0.4, 0.25, 0.5, 0.3)
	debris(g + V(0, 1, 0), rgb(200, 255, 200), 4, 0.25, 6, 0.5, Enum.Material.Glass)
	FX.Sound("Magic", 0.6, 1.2, g)
end

local function poisonCloud(p, big)
	local g = ground(p.P)
	local dur = p.DUR or 3
	local pool = part({ Shape = Enum.PartType.Cylinder, Size = V(0.1, 0.5, 0.5), CFrame = CF(g + V(0, 0.05, 0)) * ANG(0, 0, rad(90)), Color = COL.PoisonDark, Transparency = 0.35 })
	FX.Tween(pool, 0.3, { Size = V(0.1, p.R * 2, p.R * 2) })
	local balls = {}
	local n = FX.Lite and 2 or (big and 8 or 3)
	for i = 1, n do
		local a = i / n * math.pi * 2
		local s = p.R * (big and 0.9 or 0.7)
		local b = part({ Shape = Enum.PartType.Ball, Size = V(s, s * 0.6, s), CFrame = CF(g + V(math.cos(a) * p.R * 0.45, s * 0.25, math.sin(a) * p.R * 0.45)), Color = big and rgb(120, 200, 70) or COL.Poison, Material = Enum.Material.SmoothPlastic, Transparency = 0.6 })
		balls[i] = b
	end
	local em
	if not FX.Lite then
		em = Instance.new("ParticleEmitter")
		em.Color = ColorSequence.new(COL.Poison)
		em.LightEmission = 0.6
		em.Rate = big and 30 or 12
		em.Lifetime = NumberRange.new(0.6, 1.2)
		em.Speed = NumberRange.new(1, 3)
		em.SpreadAngle = Vector2.new(30, 30)
		em.EmissionDirection = Enum.NormalId.Right
		em.Size = NumberSequence.new(0.35, 0)
		em.Parent = pool
	end
	if big then
		crowCircle(g, p.R * 0.8, 3, dur)
	end
	task.delay(dur, function()
		if em then
			em.Enabled = false
		end
		fade(pool, 0.5)
		for _, b in ipairs(balls) do
			fade(b, 0.5, { Size = b.Size * 1.3 })
		end
	end)
end

IMPACT.Poison = function(p)
	poisonCloud(p, false)
end

IMPACT.PlagueCloud = function(p)
	poisonCloud(p, true)
	FX.Sound("Magic", 0.8, 0.5, p.P)
end

IMPACT.PlagueCloudBurst = function(p)
	FX.Sphere(ground(p.P) + V(0, 1, 0), p.R * 0.8, COL.Poison, 0.45, nil, 0.3)
	FX.Burst(ground(p.P) + V(0, 1, 0), COL.Poison, 14, 0.4, 10)
end

IMPACT.GhostSlash = function(p)
	local from, to = p.P + V(0, 1.5, 0), V(p.E.X, p.P.Y + 1.5, p.E.Z)
	FX.Beam(from, to, 1.1, COL.Blue, 0.35)
	local mid = (from + to) / 2
	local cf = CFrame.lookAt(mid, to)
	local crescent = part({ Size = V(3.5, 0.2, 1.2), CFrame = CFrame.lookAt(from, to), Color = COL.Ghost, Transparency = 0.2 })
	FX.Tween(crescent, 0.25, { CFrame = CFrame.lookAt(to, to + (to - from)) })
	task.delay(0.25, function()
		fade(crescent, 0.2)
	end)
	FX.Sound("Slash", 1, 0.9, mid)
	FX.Sphere(from, 1.6, COL.Blue, 0.25)
	local _ = cf
end

IMPACT.GhostSword = function(p)
	local g = ground(p.P)
	local h = 14
	local blade = part({ Size = V(1.4, h, 0.4), CFrame = CF(g + V(0, h / 2 + 18, 0)), Color = COL.Ghost, Transparency = 0.35 })
	local guard = part({ Size = V(5, 0.6, 0.8), CFrame = CF(g + V(0, h + 18, 0)), Color = COL.Blue, Transparency = 0.3 })
	local hilt = part({ Size = V(0.6, 3, 0.6), CFrame = CF(g + V(0, h + 19.8, 0)), Color = COL.Blue, Transparency = 0.3 })
	local list = { blade, guard, hilt }
	for _, q in ipairs(list) do
		FX.Tween(q, 0.3, { CFrame = q.CFrame - V(0, 18 + h * 0.3, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	end
	task.delay(0.3, function()
		FX.Ring(g, p.R, COL.Blue, 0.6, 0.5, 1, 0.1)
		FX.Cracks(g, p.R, COL.Blue, 8, 1.2)
		flash(g + V(0, 2, 0), COL.Ghost, p.R * 0.6, 0.45)
		FX.Burst(g + V(0, 1, 0), COL.Ghost, 16, 0.4, 12)
		FX.Shake(0.35, 0.35)
		FX.Sound("Explosion", 1, 0.8, g)
		for _, q in ipairs(list) do
			task.delay(0.35, function()
				fade(q, 0.4)
			end)
		end
	end)
end

IMPACT.MirrorShatter = function(p)
	local g = ground(p.P)
	portalDisc(g + V(0, 3.5, 0), 2.6, COL.Purple, 0.8, rgb(230, 200, 255))
	FX.Ring(g, p.R, COL.Purple, 0.5, 0.3, 1, 0.15)
	debris(g + V(0, 3, 0), rgb(220, 210, 255), 10, 0.5, 11, 0.9, Enum.Material.Glass)
	FX.Burst(g + V(0, 2, 0), COL.Purple, 10, 0.35, 10)
	FX.Sound("Explosion", 0.7, 1.3, g)
end

IMPACT.ThreadSnap = function(p)
	local g = ground(p.P) + V(0, 2.5, 0)
	for i = 1, (FX.Lite and 4 or 8) do
		local a = i / 8 * math.pi * 2
		local to = g + V(math.cos(a) * p.R, rng:NextNumber(-2, 1), math.sin(a) * p.R)
		FX.Thread(g + V(0, 6, 0), to, COL.Red)
	end
	FX.Ring(ground(p.P), p.R, COL.Red, 0.4, 0.2, 1, 0.2)
	FX.Burst(g, COL.Red, 14, 0.3, 10)
	FX.Sound("Slash", 1, 1.4, g)
end

IMPACT.FireCrack = function(p)
	local g = ground(p.P)
	FX.Cracks(g, p.R, COL.Ember, 6, 1.2)
	FX.Ring(g, p.R, COL.Orange, 0.4, 0.3, 1, 0.2)
	FX.Burst(g + V(0, 1, 0), COL.Fire, 10, 0.4, 8)
	smoke(g + V(0, 1, 0), rgb(60, 40, 36), 3, 2.5, 0.8, 3)
	FX.Sound("HeavyHit", 1, 0.6, g)
end

IMPACT.Execution = function(p)
	local g = ground(p.P)
	FX.Cracks(g, p.R, COL.Ember, 12, 1.6)
	FX.Ring(g, p.R, COL.Ember, 0.6, 0.6, 1, 0.05)
	flash(g + V(0, 2, 0), COL.Fire, p.R * 0.5, 0.4)
	for i = 1, (FX.Lite and 2 or 5) do
		local a = i / 5 * math.pi * 2
		local q = g + V(math.cos(a) * p.R * 0.6, 0, math.sin(a) * p.R * 0.6)
		local pillar = part({ Size = V(1.2, 0.5, 1.2), CFrame = CF(q), Color = COL.Orange, Transparency = 0.2 })
		FX.Tween(pillar, 0.25, { Size = V(1.2, 7, 1.2), CFrame = CF(q + V(0, 3.5, 0)) })
		task.delay(0.3, function()
			fade(pillar, 0.4, { Size = V(0.2, 9, 0.2) })
		end)
	end
	debris(g + V(0, 0.5, 0), COL.Stone, 8, 0.6, 10, 0.9)
	FX.Shake(0.45, 0.4)
	FX.Sound("Explosion", 1, 0.55, g)
end

IMPACT.PumpkinBlast = function(p)
	local g = ground(p.P) + V(0, 1, 0)
	FX.Sphere(g, p.R * 0.8, COL.Orange, 0.35)
	FX.Burst(g, COL.Ember, 10, 0.4, 9)
	debris(g, rgb(230, 110, 30), 5, 0.5, 8, 0.7, Enum.Material.SmoothPlastic)
	FX.Sound("Explosion", 0.6, 1.1, g)
end

IMPACT.GhostPumpkin = function(p)
	local g = ground(p.P)
	local s = 6
	local top = g + V(0, 22, 0)
	local pk = part({ Size = V(s, s * 0.85, s), CFrame = CF(top), Color = COL.Ghost, Transparency = 0.4 })
	local face = part({ Size = V(s * 0.6, s * 0.25, 0.2), CFrame = CF(top + V(0, -0.3, -s / 2)), Color = COL.Orange })
	local eyeL = part({ Size = V(0.9, 0.9, 0.2), CFrame = CF(top + V(-1.2, 1, -s / 2)) * ANG(0, 0, rad(45)), Color = COL.Orange })
	local eyeR = part({ Size = V(0.9, 0.9, 0.2), CFrame = CF(top + V(1.2, 1, -s / 2)) * ANG(0, 0, rad(45)), Color = COL.Orange })
	local list = { pk, face, eyeL, eyeR }
	plight(pk, COL.Orange, 30, 3)
	for _, q in ipairs(list) do
		FX.Tween(q, 0.45, { CFrame = q.CFrame - V(0, 19, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	end
	task.delay(0.45, function()
		for _, q in ipairs(list) do
			q:Destroy()
		end
		FX.Sphere(g + V(0, 2, 0), p.R, COL.Orange, 0.6, nil, 0.05)
		FX.Sphere(g + V(0, 2, 0), p.R * 0.7, COL.Ghost, 0.5, nil, 0.3)
		FX.Ring(g, p.R * 1.2, COL.Ember, 0.7, 0.6, 1, 0.05)
		FX.Cracks(g, p.R, COL.Ember, 10, 1.6)
		FX.Burst(g + V(0, 2, 0), COL.Fire, 24, 0.6, 16, 0.8)
		debris(g + V(0, 1, 0), rgb(230, 110, 30), 8, 0.8, 12, 1.0, Enum.Material.SmoothPlastic)
		flash(g + V(0, 3, 0), COL.Fire, p.R, 0.6)
		FX.Shake(0.6, 0.5)
		FX.Sound("Explosion", 1, 0.45, g)
	end)
end

-- РУНЫ
IMPACT.LanternHeart = function(p)
	local g = ground(p.P) + V(0, 1.2, 0)
	FX.Sphere(g, p.R, COL.Orange, 0.35, nil, 0.15)
	FX.Ring(ground(p.P), p.R, COL.Ember, 0.35, 0.25, 0.5, 0.2)
	FX.Burst(g, COL.Fire, 8, 0.3, 7)
	FX.Sound("Explosion", 0.4, 1.4, g)
end

IMPACT.CursedThreads = function(p)
	local c = p.P + V(0, 7, 0)
	for _, id in ipairs(p.A or {}) do
		local e = Renderer.EnemyCenter(id)
		if e then
			FX.Thread(c, e, COL.Red)
			FX.Ring(ground(e), 1.6, COL.Red, 0.5, 0.2, 0.3, 0.2)
		end
	end
	FX.Sound("Magic", 0.7, 0.5, p.P)
end

IMPACT.PhantomEcho = function(p)
	-- сама копия рисуется по событию атаки с флагом EC; здесь — синий отблеск у юнита
	FX.Burst(p.P + V(0, 2, 0), COL.Ghost, 5, 0.25, 4)
end

IMPACT.CursedCircle = function(p)
	local g = ground(p.P)
	runeRing(g, 4, COL.Red, 2.2)
	flash(g + V(0, 1.5, 0), COL.Red, 3, 0.5)
	FX.Burst(g + V(0, 1, 0), COL.Red, 12, 0.35, 6)
	FX.Sound("Magic", 0.8, 0.4, g)
end

IMPACT.SummonPortal = function(p)
	local g = ground(p.P)
	if p.S == "Illusion" then
		portalDisc(g + V(0, 4, 0), 3.4, COL.Purple, 1.4, rgb(230, 200, 255))
		runeRing(g, 3.5, COL.Purple, 1.6)
		debris(g + V(0, 3, 0), rgb(220, 210, 255), 6, 0.35, 6, 0.8, Enum.Material.Glass)
	else
		-- кукловод: красные нити опускают марионеток сверху
		for i = 1, 5 do
			local a = i / 5 * math.pi * 2
			FX.Thread(g + V(math.cos(a) * 1.5, 14, math.sin(a) * 1.5), g + V(math.cos(a) * 1.2, 2, math.sin(a) * 1.2), COL.Red)
		end
		runeRing(g, 3, COL.Red, 1.4)
		if p.G then
			flash(g + V(0, 3, 0), COL.Gold, 5, 0.7)
			FX.Burst(g + V(0, 2, 0), COL.Gold, 20, 0.4, 10, 0.8)
		end
	end
	FX.Sound("Portal", 0.8, 1.2, g)
end

IMPACT.AllyHit = function(p)
	local pos = p.P + V(0, 2, 0)
	FX.Burst(pos, p.F and COL.Orange or COL.Light, 6, 0.3, 7)
	FX.Sphere(pos, 1.4, p.F and COL.Ember or rgb(255, 255, 255), 0.18)
	FX.Sound("Slash", 0.5, 1.2, pos)
	local av = HFX.Allies[p.I]
	if av then
		av.HitT = os.clock()
	end
end

IMPACT.Fog = function(p)
	local g = ground(p.P)
	FX.Ring(g, p.R, COL.FogC, 0.9, 0.2, 1, 0.5)
	smoke(g + V(0, 1, 0), COL.FogC, 5, p.R * 0.6, 1.4, 1)
	local view = Renderer.EnemyViews[p.I]
	if view then
		for _, d in ipairs(view.Rig.Model:GetDescendants()) do
			if d.Name == "FogFX" and d:IsA("ParticleEmitter") then
				d:Emit(18)
			end
		end
	end
end

IMPACT.Straw = function(p)
	local g = ground(p.P)
	debris(g + V(0, 1.5, 0), COL.Straw, 10, 0.35, 8, 0.9, Enum.Material.Fabric)
	FX.Burst(g + V(0, 1.5, 0), COL.Straw, 8, 0.3, 6)
end

IMPACT.Fire = function(p)
	local g = ground(p.P)
	FX.Ring(g, 7, COL.Ember, 0.6, 0.4, 1, 0.1)
	FX.Burst(g + V(0, 2, 0), COL.Fire, 18, 0.5, 10)
	flash(g + V(0, 3, 0), COL.Orange, 6, 0.5)
end

------------------------------------------------------------------------
-- СОСТОЯНИЯ ВРАГОВ
------------------------------------------------------------------------
local function setPhased(view, on)
	local model = view.Rig.Model
	if on then
		view.PhaseSave = view.PhaseSave or {}
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("BasePart") and d.Transparency < 1 and not view.PhaseSave[d] then
				view.PhaseSave[d] = { d.Transparency, d.Color, d.Material }
				if d:GetAttribute("Outline") then
					d.Color = COL.Ghost
					d.Material = Enum.Material.Neon
				else
					d.Transparency = 0.9
				end
			end
		end
	elseif view.PhaseSave then
		for d, s in pairs(view.PhaseSave) do
			if d.Parent then
				d.Transparency, d.Color, d.Material = s[1], s[2], s[3]
			end
		end
		view.PhaseSave = nil
	end
end

local function setShield(view, on)
	for _, d in ipairs(view.Rig.Model:GetDescendants()) do
		if d.Name == "ShieldFX" and d:IsA("BasePart") then
			FX.Tween(d, 0.25, { Transparency = on and (d:GetAttribute("PT") or 0.6) or 1 })
		end
	end
end

IMPACT.EnemyState = function(p)
	local view = Renderer.EnemyViews[p.I]
	if not view then
		return
	end
	local c = Renderer.EnemyCenter(p.I) or p.P
	local s = p.S
	if s == "Phase" then
		setPhased(view, true)
		FX.Burst(c, COL.Ghost, 6, 0.25, 4)
		task.delay(p.DUR or 1.5, function()
			if view.Rig.Model.Parent then
				setPhased(view, false)
			end
		end)
	elseif s == "Shield" then
		setShield(view, true)
		FX.Sphere(c, 3 * (view.Rig.Scale or 1), COL.Purple, 0.35, nil, 0.4)
		task.delay(p.DUR or 3, function()
			if view.Rig.Model.Parent then
				setShield(view, false)
			end
		end)
	elseif s == "Haste" then
		view.HasteUntil = os.clock() + (p.DUR or 3)
		FX.Burst(c, COL.Red, 10, 0.3, 10)
		FX.Ring(ground(c), 4, COL.Red, 0.4, 0.2, 1, 0.2)
	elseif s == "Enrage" then
		flash(c, COL.Red, 6, 0.6)
		FX.Ring(ground(c), 10, COL.Red, 0.7, 0.5, 1, 0.1)
		FX.Shake(0.5, 0.6)
		FX.Sound("Boss", 1, 0.9, c)
	elseif s == "ArmorBreak" then
		debris(c, COL.Bone, 8, 0.45, 9, 0.9, Enum.Material.SmoothPlastic)
		debris(c, rgb(90, 88, 100), 5, 0.5, 8, 0.9, Enum.Material.Metal)
		FX.Sound("HeavyHit", 0.8, 1.3, c)
	end
end

-- Смерть врага: дополнительный эффект по rig.DeathFX
local DEATH = {
	GreenSmoke = function(pos, s)
		smoke(pos, rgb(90, 200, 100), 5, 2.4 * s, 1.1, 3)
		FX.Burst(pos, COL.Green, 6, 0.3, 4)
	end,
	PumpkinBurst = function(pos, s)
		debris(pos, rgb(230, 110, 30), 7, 0.5 * s, 9, 0.9, Enum.Material.SmoothPlastic)
		FX.Burst(pos, COL.Fire, 10, 0.35, 8)
		FX.Sphere(pos, 1.6 * s, COL.Orange, 0.3)
	end,
	Ghost = function(pos, s)
		smoke(pos, COL.Ghost, 4, 2 * s, 0.9, 4)
		FX.Burst(pos, COL.Ghost, 8, 0.3, 5)
	end,
	BoneShards = function(pos, s)
		debris(pos, COL.Bone, 9, 0.4 * s, 9, 1.0, Enum.Material.SmoothPlastic)
	end,
	Straw = function(pos, s)
		debris(pos, COL.Straw, 10, 0.35 * s, 8, 1.0, Enum.Material.Fabric)
	end,
	Fog = function(pos, s)
		smoke(pos, COL.FogC, 6, 2.6 * s, 1.3, 2)
	end,
	Reaper = function(pos, s)
		smoke(pos, rgb(70, 40, 110), 6, 2.6 * s, 1.2, 4)
		FX.Burst(pos, COL.Purple, 14, 0.4, 9)
		FX.Ring(ground(pos), 6, COL.Purple, 0.6, 0.3, 1, 0.2)
	end,
	GraveBreak = function(pos, s)
		debris(pos, COL.Stone, 14, 0.9, 11, 1.2)
		smoke(pos, rgb(110, 105, 100), 6, 3.5, 1.4, 3)
		FX.Ring(ground(pos), 12, rgb(150, 255, 140), 0.8, 0.5, 1, 0.1)
		FX.Shake(0.5, 0.6)
	end,
	MonarchDeath = function(pos, s)
		-- корона трескается, оранжевый свет, монарх рассыпается
		flash(pos + V(0, 4, 0), COL.Fire, 14, 1.2)
		FX.Ring(ground(pos), 20, COL.Ember, 1.2, 0.8, 1, 0.05)
		FX.Burst(pos + V(0, 4, 0), COL.Gold, 24, 0.5, 12, 1)
		debris(pos + V(0, 6, 0), COL.Gold, 10, 0.6, 9, 1.4, Enum.Material.Metal)
		smoke(pos, rgb(60, 30, 20), 8, 5, 2.2, 6)
		FX.Shake(0.9, 1.2)
		FX.Sound("Secret", 0.8, 0.8, pos)
	end,
}

function HFX.EnemyDeath(view, reason)
	local fxName = view.Rig.DeathFX
	local fn = fxName and DEATH[fxName]
	if fn and reason ~= "clear" then
		local s = (Config.Enemies[view.Type] or {}).Scale or 1
		local pos = view.Rig.Root.Position
		if fxName == "MonarchDeath" then
			-- детали короны отрываются и падают
			for _, d in ipairs(view.Rig.Model:GetDescendants()) do
				if d:IsA("BasePart") and d:GetAttribute("Crown") and d.Transparency < 1 then
					local c = d:Clone()
					c.Anchored = true
					c.Parent = workspace:FindFirstChild("VoidTD_FX") or workspace
					d.Transparency = 1
					fade(c, 1.4, { CFrame = c.CFrame * CF(rng:NextNumber(-3, 3), -4, rng:NextNumber(-3, 3)) * ANG(rng:NextNumber(-2, 2), 0, rng:NextNumber(-2, 2)) })
				end
			end
		end
		fn(pos, s)
	end
end

-- Появление: особые входы боссов
function HFX.EnemySpawn(view, atStart)
	local fxName = view.Rig.SpawnFX
	if not fxName or not atStart then
		return
	end
	local pos = view.Rig.Root.Position
	local g = ground(pos)
	if fxName == "GraveBreak" then
		-- плита могилы поднимается и раскалывается, страж выходит из могилы
		local slab = part({ Size = V(6, 0.8, 9), CFrame = CF(g + V(0, 0.4, 0)), Color = COL.Stone, Material = Enum.Material.Slate })
		FX.Tween(slab, 0.5, { CFrame = CF(g + V(0, 2.5, 0)) * ANG(rad(25), 0, rad(-10)) })
		task.delay(0.55, function()
			slab:Destroy()
			debris(g + V(0, 2.5, 0), COL.Stone, 12, 1.1, 12, 1.3)
			smoke(g + V(0, 1, 0), rgb(110, 105, 100), 6, 4, 1.4, 3)
			FX.Ring(g, 10, rgb(150, 255, 140), 0.7, 0.4, 1, 0.1)
			FX.Shake(0.6, 0.6)
		end)
	elseif fxName == "FogVortex" then
		-- вихрь тумана сгущается в жнеца
		local n = FX.Lite and 4 or 12
		local balls = {}
		for i = 1, n do
			balls[i] = { part({ Shape = Enum.PartType.Ball, Size = V(3, 3, 3), Color = COL.FogC, Material = Enum.Material.SmoothPlastic, Transparency = 0.6 }), i / n * math.pi * 2, rng:NextNumber(0, 6) }
		end
		local t0 = os.clock()
		local conn
		conn = RunService.RenderStepped:Connect(function()
			local t = os.clock() - t0
			for _, b in ipairs(balls) do
				local a = b[2] + t * 5
				local r = math.max(0.5, 10 - t * 7)
				b[1].CFrame = CF(g + V(math.cos(a) * r, 1 + b[3] * 0.6 + t * 2, math.sin(a) * r))
				b[1].Transparency = 0.6 + math.clamp((t - 1) / 0.4, 0, 0.4)
			end
			if t >= 1.4 then
				conn:Disconnect()
				for _, b in ipairs(balls) do
					b[1]:Destroy()
				end
				FX.Sphere(g + V(0, 4, 0), 7, COL.Red, 0.4, nil, 0.4)
			end
		end)
	elseif fxName == "MonarchPortal" then
		-- монарх выходит из огненного портала и втыкает посох в землю
		portalDisc(g + V(0, 9, 0), 8, rgb(150, 50, 15), 2.0, COL.Fire)
		task.delay(1.1, function()
			FX.Cracks(g, 12, COL.Ember, 12, 2)
			FX.Ring(g, 16, COL.Ember, 0.8, 0.6, 1, 0.05)
			FX.Burst(g + V(0, 1, 0), COL.Fire, 20, 0.5, 12)
			FX.Shake(0.7, 0.7)
			FX.Sound("Explosion", 1, 0.4, g)
		end)
	end
end

-- Ускорение (Fog Reaper) и туман: клиентское предсказание скорости
function HFX.SpeedMult(view)
	if view.HasteUntil and os.clock() < view.HasteUntil then
		return 1.6
	end
	return 1
end

------------------------------------------------------------------------
-- АТАКИ ЮНИТОВ (визуал вылета; урон и области — по Impact)
------------------------------------------------------------------------
function HFX.OnAttack(view, def, p, h, lv)
	if def.Event ~= "Halloween" or def.AttackType == "Chrono" then
		return false
	end
	local muzzle = Renderer.MuzzlePos(view)
	local firstId = p.T and p.T[1]
	local id = view.UnitId
	local function at(d, fn)
		task.delay(d, function()
			if view.Rig and view.Rig.Model.Parent then
				fn()
			end
		end)
	end
	if def.AttackType == "Melee" then
		at(h, function()
			local target = Renderer.EnemyCenter(firstId)
			if not target then
				return
			end
			local origin = view.Rig.Root.Position + V(0, 1, 0)
			local cf = CFrame.lookAt(origin, V(target.X, origin.Y, target.Z))
			FX.Arc(cf, math.max((V(target.X, origin.Y, target.Z) - origin).Magnitude * 0.6, 3), rad(20), rad(150), COL.Dirt, 0.6, 0.3)
			debris(ground(target) + V(0, 0.5, 0), COL.Dirt, 3, 0.35, 5, 0.6, Enum.Material.Ground)
			FX.Sound("HeavyHit", 0.8, 1, target)
		end)
		return true
	elseif def.AttackType == "Pulse" then
		at(h, function()
			flash(muzzle, COL.Bell, 1.6, 0.25)
		end)
		return true
	elseif def.AttackType == "Flask" then
		at(h, function()
			local from = Renderer.MuzzlePos(view)
			FX.Projectile("Flask", from, function()
				return Renderer.EnemyCenter(firstId)
			end, p.TR or 0.4, nil, lv)
		end)
		return true
	elseif def.AttackType == "Pierce" then
		at(h, function()
			FX.Sphere(Renderer.MuzzlePos(view), 1.8, COL.Blue, 0.25)
		end)
		return true
	elseif def.AttackType == "Thread" then
		at(h, function()
			for _, tid in ipairs(p.T or {}) do
				local target = Renderer.EnemyCenter(tid)
				if target then
					FX.Thread(Renderer.MuzzlePos(view), target, def.ThreadColor or COL.Red)
				end
			end
			FX.Sound("Magic", 0.8, 0.7, view.Pos)
		end)
		return true
	elseif def.AttackType == "AOE" then
		at(h, function()
			local m = Renderer.MuzzlePos(view)
			if id == "NightWatchman" then
				flash(m, COL.Light, 1.5, 0.2)
			elseif id == "HeadlessExecutioner" then
				local target = Renderer.EnemyCenter(firstId)
				if target then
					local origin = view.Rig.Root.Position + V(0, 2, 0)
					local cf = CFrame.lookAt(origin, V(target.X, origin.Y, target.Z))
					FX.Arc(cf, math.max((V(target.X, origin.Y, target.Z) - origin).Magnitude * 0.7, 4), rad(10), rad(160), COL.Ember, 1.1, 0.35)
				end
			end
		end)
		return true
	elseif def.AttackType == "Projectile" and def.Projectile == "Crow" then
		for si, tid in ipairs(p.T or { firstId }) do
			local travel = (p.TRS and p.TRS[si]) or p.TR or 0.3
			at(h + (si - 1) * (p.SG or 0.12), function()
				crowFly(Renderer.MuzzlePos(view), function()
					return Renderer.EnemyCenter(tid)
				end, travel, function(pos)
					FX.Burst(pos, COL.Black, 5, 0.3, 5)
				end)
			end)
		end
		return true
	end
	return false
end

-- «Призрачная корона»: синяя копия юнита за его спиной повторяет атаку
function HFX.EchoGhost(view)
	if not view.Rig or FX.Lite and math.random() < 0.5 then
		return
	end
	local ok, clone = pcall(function()
		return view.Rig.Model:Clone()
	end)
	if not ok or not clone then
		return
	end
	local root = view.Rig.Root
	local back = root.CFrame * CF(0, 0.3, 2.4)
	for _, d in ipairs(clone:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CastShadow = false
			if d.Transparency < 1 then
				d.Color = COL.Ghost
				d.Material = Enum.Material.Neon
				d.Transparency = 0.55
			end
		elseif d:IsA("ParticleEmitter") or d:IsA("BillboardGui") or d:IsA("PointLight") or d:IsA("Trail") or d:IsA("Motor6D") then
			d:Destroy()
		end
	end
	clone:PivotTo(back)
	clone.Parent = workspace:FindFirstChild("VoidTD_FX") or workspace
	local fwd = root.CFrame * CF(0, 0.3, -0.6)
	local t0 = os.clock()
	local parts = {}
	for _, d in ipairs(clone:GetDescendants()) do
		if d:IsA("BasePart") and d.Transparency < 1 then
			parts[#parts + 1] = d
		end
	end
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		local a = math.clamp(t / 0.25, 0, 1)
		clone:PivotTo(back:Lerp(fwd, a * 0.7))
		local tr = 0.55 + math.clamp((t - 0.35) / 0.35, 0, 1) * 0.45
		for _, d in ipairs(parts) do
			d.Transparency = tr
		end
		if t >= 0.7 then
			conn:Disconnect()
			clone:Destroy()
		end
	end)
end

function HFX.OnImpact(p)
	local fn = IMPACT[p.K]
	if fn then
		fn(p)
		return true
	end
	return false
end

-- Появление Короля фонарей: трон поднимается из огня
function HFX.ThronePlace(pos)
	local g = ground(pos)
	local seat = part({ Size = V(4, 0.6, 3.5), CFrame = CF(g - V(0, 3, 0)), Color = COL.Black, Material = Enum.Material.Slate })
	local back = part({ Size = V(4, 6, 0.6), CFrame = CF(g + V(0, 0, 1.6) - V(0, 3, 0)), Color = COL.Black, Material = Enum.Material.Slate })
	local trim = part({ Size = V(4.3, 0.3, 0.7), CFrame = CF(g + V(0, 3, 1.6) - V(0, 3, 0)), Color = COL.Gold })
	for _, q in ipairs({ seat, back, trim }) do
		FX.Tween(q, 0.6, { CFrame = q.CFrame + V(0, 3.3, 0) }, Enum.EasingStyle.Back)
		task.delay(1.6, function()
			fade(q, 0.6, { CFrame = q.CFrame - V(0, 2, 0) })
		end)
	end
	FX.Ring(g, 6, COL.Ember, 0.8, 0.5, 1, 0.1)
	FX.Burst(g + V(0, 1, 0), COL.Fire, 20, 0.45, 10, 0.8)
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2
		local q = g + V(math.cos(a) * 4, 0, math.sin(a) * 4)
		local pk = part({ Size = V(1, 0.8, 1), CFrame = CF(q - V(0, 1, 0)), Color = rgb(230, 110, 30), Material = Enum.Material.SmoothPlastic })
		FX.Tween(pk, 0.5, { CFrame = CF(q + V(0, 0.4, 0)) }, Enum.EasingStyle.Back)
		task.delay(1.8, function()
			fade(pk, 0.5)
		end)
	end
	flash(g + V(0, 3, 0), COL.Orange, 5, 0.8)
	FX.Sound("Secret", 0.6, 1.2, g)
end

------------------------------------------------------------------------
-- СОЮЗНИКИ: модели на дороге, идут от базы к порталу
------------------------------------------------------------------------
local allyViews = {}
HFX.Allies = allyViews
local allyFolder

local function allyBar(av)
	local gui = Instance.new("BillboardGui")
	gui.Name = "HPBar"
	gui.Size = UDim2.fromOffset(60, 8)
	gui.StudsOffsetWorldSpace = V(0, av.Rig.Height or 5, 0)
	gui.MaxDistance = 90
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = rgb(20, 14, 24)
	bg.BorderSizePixel = 0
	bg.Parent = gui
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = av.Family == "Cursed" and COL.Red or (av.Family == "Puppet" and COL.Orange or COL.Purple)
	fill.BorderSizePixel = 0
	fill.Parent = bg
	gui.Parent = av.Rig.Root
	av.Fill = fill
end

local function addAlly(id, dist, hp, typeIndex, maxHp)
	local allyId = Config.AllyOrder[typeIndex]
	if not allyId or not UnitModels.BuildAlly then
		return
	end
	local ok, rig = pcall(UnitModels.BuildAlly, allyId)
	if not ok or not rig then
		warn(rig)
		return
	end
	local def = Config.Allies[allyId]
	local av = {
		Id = id, AllyId = allyId, Family = def.Family, Rig = rig, Dist = dist, ServerDist = dist,
		HP = hp, MaxHP = maxHp or hp, LastSync = os.clock(), Phase = rng:NextNumber(0, 6),
		Lateral = rng:NextNumber(-1.4, 1.4), SpawnT = os.clock(),
	}
	rig.Height = rig.Height or (5 * (rig.Scale or 1))
	for _, d in ipairs(rig.Model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CanQuery = false
			d.CanTouch = false
			d.CanCollide = false
		end
	end
	local pos, dir = PathUtil.OffsetPositionAt(dist, av.Lateral)
	rig.Root.CFrame = CFrame.lookAt(pos + V(0, rig.HipHeight, 0), pos - dir + V(0, rig.HipHeight, 0))
	allyBar(av)
	rig.Model.Parent = allyFolder
	allyViews[id] = av
end

local function removeAlly(id, reason)
	local av = allyViews[id]
	if not av then
		return
	end
	allyViews[id] = nil
	local pos = av.Rig.Root.Position
	local color = av.Family == "Cursed" and COL.Red or (av.Family == "Puppet" and (av.AllyId == "GoldenMarionette" and COL.Gold or COL.Orange) or COL.Purple)
	if reason == "dead" then
		FX.Burst(pos, color, 10, 0.35, 8)
		if av.Family == "Puppet" then
			debris(pos, rgb(150, 110, 70), 6, 0.4, 7, 0.8, Enum.Material.Wood)
		elseif av.Family == "Illusion" then
			debris(pos, rgb(220, 210, 255), 6, 0.35, 7, 0.8, Enum.Material.Glass)
		else
			smoke(pos, rgb(120, 20, 30), 3, 2, 0.8, 3)
		end
	else
		FX.Poof(pos, color, 1)
	end
	av.Rig.Model:Destroy()
end

function HFX.SyncAllies(list, removed)
	local nowc = os.clock()
	local seen = {}
	if list then
		for i = 1, #list, 5 do
			local id = list[i]
			seen[id] = true
			local av = allyViews[id]
			if av then
				av.ServerDist = list[i + 1]
				av.HP = list[i + 2]
				av.MaxHP = list[i + 4] or av.MaxHP
				av.LastSync = nowc
			else
				addAlly(id, list[i + 1], list[i + 2], list[i + 3], list[i + 4])
			end
		end
		-- союзники, пропавшие из списка без причины (например, после переподключения)
		for id in pairs(allyViews) do
			if not seen[id] then
				removeAlly(id, "clear")
			end
		end
	end
	for _, r in ipairs(removed or {}) do
		removeAlly(r[1], r[2])
	end
end

function HFX.ClearAllies()
	for id in pairs(allyViews) do
		removeAlly(id, "clear")
	end
end

function HFX.Update(dt)
	local t = os.clock()
	local speed = Config.Settings.AllySpeed or 6
	for _, av in pairs(allyViews) do
		local rig = av.Rig
		local predicted = av.ServerDist - speed * math.min(t - av.LastSync, 0.35)
		av.Dist = av.Dist - speed * dt
		av.Dist = av.Dist + (predicted - av.Dist) * math.min(1, dt * 5)
		local pos, dir = PathUtil.OffsetPositionAt(math.max(av.Dist, 0), av.Lateral)
		local rise = math.clamp((t - av.SpawnT) / 0.4, 0, 1)
		local hip = rig.HipHeight
		local bob = math.abs(math.sin(t * 7 + av.Phase)) * 0.15
		rig.Root.CFrame = CFrame.lookAt(pos + V(0, hip + bob - (1 - rise) * 2, 0), pos - dir + V(0, hip + bob - (1 - rise) * 2, 0))
		-- ходьба: руки и ноги машут навстречу
		local swing = math.sin(t * 7 + av.Phase) * 32
		local base = rig.Base
		local m = rig.Motors
		if m.RH and base.RH then
			m.RH.C0 = base.RH * ANG(rad(swing), 0, 0)
			m.LH.C0 = base.LH * ANG(rad(-swing), 0, 0)
		end
		if m.RS and base.RS then
			m.RS.C0 = base.RS * ANG(rad(-swing * 0.7), 0, 0)
			m.LS.C0 = base.LS * ANG(rad(swing * 0.7), 0, 0)
		end
		if av.Fill then
			av.Fill.Size = UDim2.fromScale(math.clamp(av.HP / math.max(av.MaxHP, 1), 0, 1), 1)
		end
	end
end

function HFX.Init(c, renderer)
	ctx = c
	Config, PathUtil, UnitModels, FX = c.Config, c.PathUtil, c.UnitModels, c.FX
	Renderer = renderer
	allyFolder = Instance.new("Folder")
	allyFolder.Name = "VoidTD_Allies"
	allyFolder.Parent = workspace
	installProjectiles()
end

return HFX
