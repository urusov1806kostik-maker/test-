--!nocheck
-- VOID TD :: Render/Enemies — виды врагов: появление, интерполяция по дороге, походка, вторичное движение,
-- визуальные фазы боссов, полоски HP, смерть. Сервер авторитетен: клиент только догоняет ServerDist.
--
-- API (вызывается из Render/init)
--   Enemies.Init(R, ctx)
--   Enemies.Spawn(data)            data = { id, typeId, maxHp, speed, lateral, dist [, hp] }
--   Enemies.Remove(id, reason)     "clear" — без анимации; "core" — дошёл до ядра; иначе — убит
--   Enemies.Sync(E)                плоский массив по 4: id, dist, hp, flag (0 / 1 замедлен / 2 заморожен)
--   Enemies.Update(t, dt, camPos)
--   Enemies.Clear()
--   Enemies.Center(id), Enemies.Position(id)

local Enemies = {}

local V = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles
local rad = math.rad
local sin, cos, abs, min, max, clamp = math.sin, math.cos, math.abs, math.min, math.max, math.clamp

local R, ctx, Config, Path, EnemyModels, FX
local views = {}
Enemies.Views = views

local NEON = Color3.fromRGB(180, 80, 255)
local SOFT = Color3.fromRGB(215, 160, 255)
local PINK = Color3.fromRGB(255, 60, 170)
local WHITE = Color3.fromRGB(250, 245, 255)
local DUST = Color3.fromRGB(70, 60, 82)
local LOD_DISTANCE = 200
local SEC_KINDS = { "Sway", "Cape", "Orbit", "Spin", "Bob", "Twitch" }
local DEATH_LIFE = { Dissipate = 0.7, Scatter = 0.85, Collapse = 0.75, Topple = 1.0, Implode = 2.4 }
local FLOAT_ARMS = { "ArmR", "ArmL", "ArmR2", "ArmL2", "RS", "LS" }
local CRAWL_LEGS = { { "FR", 1, 0 }, { "BL", -1, 0 }, { "FL", -1, math.pi }, { "BR", 1, math.pi } }

local function ease(a)
	return a * a * (3 - 2 * a)
end

function Enemies.Init(renderer, c)
	R, ctx = renderer, c
	Config, Path, EnemyModels, FX = c.Config, c.Path, c.EnemyModels, c.FX
end

------------------------------------------------------------------------
-- ПОЗИЦИИ
------------------------------------------------------------------------
function Enemies.Position(id)
	local v = views[id]
	return v and v.Rig.Root.Position or nil
end

function Enemies.Center(id)
	local v = views[id]
	if not v then
		return nil
	end
	local rig = v.Rig
	return rig.Root.Position + V(0, ((rig.Height or 5) - (rig.HipHeight or 0)) * 0.35, 0)
end

local function groundOf(v)
	return v.Rig.Root.Position - V(0, (v.Rig.HipHeight or 0) - 0.3, 0)
end

------------------------------------------------------------------------
-- ПОЯВЛЕНИЕ
------------------------------------------------------------------------
-- вторичные моторы по префиксу имени
local function collectSecondary(rig)
	local list = {}
	local sec = rig.Sec or {}
	for name, motor in pairs(rig.Motors or {}) do
		local base = rig.Base and rig.Base[name]
		if base then
			for _, kind in ipairs(SEC_KINDS) do
				if name:sub(1, #kind) == kind then
					local prm = sec[name] or {}
					list[#list + 1] = { Motor = motor, Base = base, Kind = kind, Amp = prm.Amp or 0.2, Speed = prm.Speed or 1.5,
						Phase = math.random() * 6, Next = 0, Y = 0, P = 0, TY = 0, TP = 0 }
					break
				end
			end
		end
	end
	return list
end

local function makeHealthBar(v, boss)
	local rig = v.Rig
	local gui = Instance.new("BillboardGui")
	gui.Name = "HPBar"
	gui.Size = boss and UDim2.fromOffset(120, 12) or UDim2.fromOffset(60, 7)
	gui.StudsOffsetWorldSpace = V(0, (rig.Height or 5) - (rig.HipHeight or 0) + 1.2, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 180
	gui.LightInfluence = 0
	gui.Adornee = rig.Root
	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Color3.fromRGB(20, 10, 25)
	bg.BorderSizePixel = 0
	bg.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 3)
	corner.Parent = bg
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.new(0, 0, 0)
	stroke.Thickness = 1
	stroke.Parent = bg
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = boss and Color3.fromRGB(235, 50, 130) or Color3.fromRGB(190, 80, 255)
	fill.BorderSizePixel = 0
	fill.Parent = bg
	corner:Clone().Parent = fill
	gui.Parent = rig.Root
	v.Bar = gui
	v.Fill = fill
	v.FillRatio = 1
end

-- вспышка портала при выходе босса
local function portalSurge(final)
	local map = R.ActiveMap()
	local portal = map and map:FindFirstChild("VoidPortal")
	if not portal then
		return
	end
	local disc = portal:FindFirstChild("PortalDisc")
	local core = portal:FindFirstChild("PortalCore")
	local light = core and core:FindFirstChildWhichIsA("PointLight")
	if light then
		local orig = light:GetAttribute("OrigBrightness") or light.Brightness
		light:SetAttribute("OrigBrightness", orig)
		light.Brightness = orig * 3
		FX.Tween(light, 1.8, { Brightness = orig })
	end
	FX.Sound("Portal", 1.2, final and 0.7 or 0.85)
	if not disc then
		return
	end
	local orig = disc:GetAttribute("OrigColor") or disc.Color
	disc:SetAttribute("OrigColor", orig)
	disc.Color = Color3.fromRGB(235, 200, 255)
	FX.Tween(disc, 1.2, { Color = orig })
	local p = disc.Position
	local gy = (Path.Map and Path.Map.GroundY) or p.Y
	FX.Sphere(p, final and 16 or 11, NEON, 0.8, nil, 0.3)
	FX.Ring(V(p.X, gy + 0.3, p.Z), final and 45 or 30, NEON, 1.1, 0.6, 3, 0.05)
	task.delay(0.15, function()
		FX.Ring(V(p.X, gy + 0.4, p.Z), final and 32 or 22, WHITE, 0.9, 0.3, 2, 0.2)
	end)
	FX.Burst(p, SOFT, final and 30 or 18, 0.7, 18, 0.9)
end

local applyPhase, checkPhases

function Enemies.Spawn(data)
	local id, typeId, maxHp, speed, lateral, dist, hp = data[1], data[2], data[3], data[4], data[5], data[6], data[7]
	if id == nil or views[id] then
		return
	end
	local def = Config.Enemies[typeId]
	if not def then
		warn("[VOID TD] неизвестный враг " .. tostring(typeId))
		return
	end
	local ok, rig = pcall(EnemyModels.Build, typeId)
	if not ok or not rig then
		warn("[VOID TD] враг " .. tostring(typeId) .. ": " .. tostring(rig))
		return
	end
	dist = dist or 0
	lateral = lateral or 0
	local now = os.clock()
	local v = {
		Id = id, Type = typeId, Def = def, Rig = rig, MaxHP = maxHp or 1, HP = hp or maxHp or 1, Speed = speed or 0,
		Lateral = lateral, Dist = dist, ServerDist = dist, LastSync = now, Slowed = false, Frozen = false,
		Phase = math.random() * 10, Aggro = 1, NextPhase = 1, VisualPhase = 1, SpawnT = now, Emerge = dist <= 1,
		HitT = -10, RoarT = -10,
	}
	v.W = v.Phase
	v.Sec = collectSecondary(rig)
	local hip = rig.HipHeight or 0
	local pos, dir = Path.OffsetPositionAt(dist, lateral)
	v.CF = CFrame.lookAt(pos + V(0, hip, 0), pos + dir + V(0, hip, 0))
	-- переподключение: уже раненый босс сразу показывает поздние фазы (без эффектов)
	checkPhases(v, true)
	local boss = def.IsBoss == true
	if boss then
		local entity = typeId == "TheEntity"
		v.RoarT = now + (rig.SpawnStyle == "Titan" and 1.1 or 0.6)
		if dist <= 1 then
			portalSurge(entity)
		end
		task.delay(0.6, function()
			FX.Sound("Boss", 1, entity and 0.75 or 1)
			FX.Shake(entity and 0.8 or 0.5, 1.0)
		end)
	end
	if rig.SpawnStyle == "Fade" and not FX.Lite then
		v.FadeParts = {}
		for _, d in ipairs(rig.Model:GetDescendants()) do
			if d:IsA("BasePart") and d.Transparency < 1 then
				v.FadeParts[#v.FadeParts + 1] = { d, d.Transparency }
				d.Transparency = 1
			end
		end
	end
	local rise = v.Emerge and (hip + 1.5) or 0
	rig.Root.CFrame = v.CF - V(0, rise, 0)
	makeHealthBar(v, boss)
	rig.Model.Parent = R.EnemyFolder
	views[id] = v
	if rig.SpawnFX and FX.Fn.EnemySpawn then
		FX.Fn.EnemySpawn(v, dist <= 1)
	end
	if dist <= 1 then
		FX.Burst(pos + V(0, 2, 0), NEON, 6, 0.3, 5)
	end
	if rig.SpawnStyle == "Titan" then
		FX.Cracks(pos + V(0, 0.2, 0), 7, NEON, 10, 1.6)
		task.delay(1.1, function()
			local c = Enemies.Center(id)
			if c then
				FX.Sphere(c, 4, NEON, 0.5)
				FX.Burst(c, SOFT, 14, 0.5, 10, 0.6)
			end
		end)
	end
end

------------------------------------------------------------------------
-- ФАЗЫ БОССОВ (только внешний вид)
------------------------------------------------------------------------
-- оторвать деталь от модели и уронить
local function breakPart(v, part, silent)
	for _, d in ipairs(v.Rig.Model:GetDescendants()) do
		if (d:IsA("JointInstance") or d:IsA("WeldConstraint")) and (d.Part0 == part or d.Part1 == part) then
			d:Destroy()
		end
	end
	if silent or FX.Lite then
		part:Destroy()
		return
	end
	local root = v.Rig.Root.Position
	part.Anchored = true
	part.CanCollide = false
	part.Parent = FX.Folder
	local cf = part.CFrame
	local out = V(cf.Position.X - root.X, 0, cf.Position.Z - root.Z)
	out = out.Magnitude > 0.05 and out.Unit or V(0, 0, 1)
	local dest = V(cf.Position.X, root.Y - (v.Rig.HipHeight or 0) + part.Size.Y * 0.3, cf.Position.Z) + out * (2 + math.random() * 4)
	FX.Tween(part, 0.35, { CFrame = cf + out * 1.5 + V(0, 1.5, 0) })
	task.delay(0.35, function()
		if part.Parent then
			FX.Tween(part, 0.6, { CFrame = CF(dest) * ANG(math.random() * 3, math.random() * 3, math.random() * 3) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		end
	end)
	task.delay(1.6, function()
		if part.Parent then
			FX.Tween(part, 0.8, { Transparency = 1 })
		end
	end)
	FX.Cleanup(part, 2.5)
end

applyPhase = function(v, idx, silent)
	local ph = v.Rig.Phases[idx]
	v.VisualPhase = idx + 1
	v.Aggro = ph.Aggro or v.Aggro
	for _, part in ipairs(ph.Reveal or {}) do
		if part.Parent then
			local goal = part:GetAttribute("PT") or 0
			if silent or FX.Lite then
				part.Transparency = goal
			else
				FX.Tween(part, 0.6, { Transparency = goal })
			end
		end
	end
	for _, em in ipairs(ph.Emit or {}) do
		if em.Parent then
			if em.Enabled then
				em.Rate = em.Rate * 1.8
			else
				em.Enabled = true
			end
		end
	end
	for _, l in ipairs(ph.Lights or {}) do
		local light, b = l[1], l[2]
		if light and light.Parent then
			light.Brightness = b or light.Brightness
			light.Range = light.Range * 1.25
		end
	end
	for _, part in ipairs(ph.Break or {}) do
		if part.Parent then
			breakPart(v, part, silent)
		end
	end
	if silent then
		return
	end
	local rig = v.Rig
	local sc = rig.Scale or 1
	local c = Enemies.Center(v.Id) or rig.Root.Position
	v.RoarT = os.clock()
	FX.Sound("Boss", 1, 0.8 + idx * 0.12, c)
	FX.Shake(0.3 + idx * 0.15, 0.6)
	FX.Ring(groundOf(v), 8 * sc, NEON, 0.8, 0.5, 1, 0.05)
	FX.Sphere(c, 2.5 * sc, SOFT, 0.5)
	FX.Burst(c, NEON, 16, 0.4 * sc, 9 * sc, 0.7)
end

checkPhases = function(v, silent)
	local phases = v.Rig.Phases
	if not phases then
		return
	end
	local ratio = v.HP / max(v.MaxHP, 1)
	while phases[v.NextPhase] and ratio <= (phases[v.NextPhase].At or 0) do
		applyPhase(v, v.NextPhase, silent)
		v.NextPhase += 1
	end
end

------------------------------------------------------------------------
-- СИНХРОНИЗАЦИЯ
------------------------------------------------------------------------
function Enemies.Sync(E)
	local now = os.clock()
	for i = 1, #E - 3, 4 do
		local v = views[E[i]]
		if v then
			local hp, flag = E[i + 2], E[i + 3]
			v.ServerDist = E[i + 1] or v.ServerDist
			if hp and hp < v.HP then
				v.HitT = now
			end
			v.HP = hp or v.HP
			v.Slowed = flag == 1
			v.Frozen = flag == 2
			v.LastSync = now
		end
	end
end

------------------------------------------------------------------------
-- ПОХОДКА И ВТОРИЧНОЕ ДВИЖЕНИЕ
------------------------------------------------------------------------
local function heavyStep(v, power, camDist)
	if camDist < 90 then
		FX.Shake(power * (1 - camDist / 90), 0.18)
	end
	if not FX.Lite and camDist < 120 then
		local sc = v.Rig.Scale or 1
		FX.Ring(groundOf(v), 2.2 * sc, DUST, 0.45, 0.2, 0.4 * sc, 0.45)
	end
end

local function stepSecondary(v, t, dt, aggro, sc)
	for _, s in ipairs(v.Sec) do
		local k = s.Kind
		if k == "Sway" or k == "Cape" then
			local sp = s.Speed * (0.8 + 0.2 * aggro)
			s.Motor.C0 = s.Base * ANG(sin(t * sp + s.Phase) * s.Amp + (k == "Cape" and s.Amp * 0.8 or 0), 0, sin(t * sp * 0.7 + s.Phase) * s.Amp * 0.5)
		elseif k == "Orbit" then
			s.Motor.C0 = s.Base * ANG(0, t * s.Speed * aggro + s.Phase, 0)
		elseif k == "Spin" then
			s.Motor.C0 = s.Base * ANG(0, 0, t * s.Speed * aggro + s.Phase)
		elseif k == "Bob" then
			s.Motor.C0 = s.Base * CF(0, sin(t * s.Speed + s.Phase) * s.Amp * sc, 0) * ANG(0, sin(t * s.Speed * 0.5 + s.Phase) * 0.25, 0)
		else -- Twitch: резкие подёргивания
			if t >= s.Next then
				s.Next = t + 0.25 + math.random() * 0.7
				s.TY = (math.random() * 2 - 1) * s.Amp
				s.TP = (math.random() * 2 - 1) * s.Amp * 0.5
			end
			local a = min(1, dt * 22)
			s.Y += (s.TY - s.Y) * a
			s.P += (s.TP - s.P) * a
			s.Motor.C0 = s.Base * ANG(s.P, s.Y, 0)
		end
	end
end

local function animate(v, t, dt, camDist)
	local rig = v.Rig
	local m, b = rig.Motors, rig.Base
	if not m or not b or not m.Root or not b.Root then
		return
	end
	local g = rig.Gait or {}
	local sc = rig.Scale or 1
	local idle = rig.Idle or {}
	local aggro = v.Aggro
	local far = camDist > LOD_DISTANCE
	local style = rig.Style or "Biped"
	local spd = v.Speed * (v.Slowed and 0.5 or 1)
	local freq = spd / max(v.Def.Scale or 1, 0.5) * 1.1 * (g.Speed or 1) * (1 + (aggro - 1) * 0.3)
	v.W += dt * freq
	local W = v.W
	local s = sin(W)
	local stride = (g.Stride or 0.55) * (0.85 + 0.15 * aggro)
	local bob = (g.Bob or 0.12) * sc
	local boss = v.Def.IsBoss == true
	local flinch = 0
	local hitA = t - v.HitT
	if hitA < 0.22 then
		flinch = (1 - hitA / 0.22) * (boss and 0.35 or 1)
	end
	local neckCF
	local function pose(name, x, y, z)
		local motor, base = m[name], b[name]
		if not motor or not base then
			return
		end
		local i = idle[name]
		local cf
		if i then
			cf = base * ANG(rad(i[1] or 0) + x, rad(i[2] or 0) + y, rad(i[3] or 0) + z)
		else
			cf = base * ANG(x, y, z)
		end
		motor.C0 = cf
		if name == "Neck" then
			neckCF = cf
		end
	end
	local idleRoot = idle.Root and rad(idle.Root[1] or 0) or 0
	local rootCF
	if style == "Biped" or style == "Heavy" then
		local heavy = style == "Heavy"
		pose("RH", s * stride, 0, 0)
		pose("LH", -s * stride, 0, 0)
		local arm = stride * (heavy and 0.55 or 0.8) * aggro
		pose("RS", -s * arm, 0, heavy and abs(s) * 0.08 or 0)
		pose("LS", s * arm, 0, heavy and -abs(s) * 0.08 or 0)
		local sway = g.Sway or 0.04
		local lean = rad((g.Lean or 0) + (aggro - 1) * 20)
		local y = heavy and ((1 - abs(s)) * bob - bob * 0.5) or abs(s) * bob
		rootCF = b.Root * CF(0, y, 0) * ANG(idleRoot + lean, s * sway * 0.5, -s * sway)
		pose("Neck", heavy and -abs(s) * 0.05 or 0, 0, s * sway * 0.8)
		if g.Shake and not far then
			local c = cos(W) >= 0
			if v.StepSign ~= nil and v.StepSign ~= c then
				heavyStep(v, g.Shake * (0.8 + 0.2 * aggro), camDist)
			end
			v.StepSign = c
		end
	elseif style == "Gallop" then
		pose("FR", s * stride, 0, 0)
		pose("FL", sin(W + 0.35) * stride, 0, 0)
		pose("BR", sin(W - 1.6) * stride, 0, 0)
		pose("BL", sin(W - 1.25) * stride, 0, 0)
		rootCF = b.Root * CF(0, abs(s) * bob, 0) * ANG(cos(W) * 0.09, 0, 0)
		pose("Neck", -cos(W) * 0.12, 0, 0)
	elseif style == "Crawl" then
		for _, leg in ipairs(CRAWL_LEGS) do
			local p = W + leg[3]
			pose(leg[1], 0, sin(p) * stride * leg[2], max(0, cos(p)) * 0.35 * leg[2])
		end
		rootCF = b.Root * CF(0, abs(sin(2 * W)) * bob, 0) * ANG(0, s * 0.06, s * (g.Sway or 0.05))
	elseif style == "Quad" then
		pose("FR", s * 0.6, 0, 0)
		pose("BL", s * 0.6, 0, 0)
		pose("FL", -s * 0.6, 0, 0)
		pose("BR", -s * 0.6, 0, 0)
		rootCF = b.Root * CF(0, abs(s) * 0.1 * sc, 0) * ANG(s * 0.03, 0, 0)
		pose("Neck", sin(2 * W) * 0.06, 0, 0)
	else -- Float
		local amp = (g.Bob or 0.3) * sc
		rootCF = b.Root * CF(0, sin(t * 2 + v.Phase) * amp, 0) * ANG(0.12 + (aggro - 1) * 0.2, 0, sin(t * 1.3 + v.Phase) * 0.06)
		for _, name in ipairs(FLOAT_ARMS) do
			local side = (name:sub(-1) == "R" or name == "RS" or name == "ArmR2") and 1 or -1
			pose(name, sin(t * 2.2 + v.Phase + side) * 0.3 + 0.3, 0, sin(t * 1.7) * 0.15 * side)
		end
	end
	-- титан встаёт из приседа
	if rig.SpawnStyle == "Titan" then
		local sa = (t - v.SpawnT) / 1.6
		if sa < 1 then
			local k = 1 - ease(clamp(sa, 0, 1))
			rootCF = rootCF * CF(0, -k * 1.2 * sc, 0) * ANG(rad(40) * k, 0, 0)
			pose("RS", rad(-30) * k, 0, rad(20) * k)
			pose("LS", rad(-30) * k, 0, rad(-20) * k)
		end
	end
	-- вздрагивание от удара (шея — от базовой позы, без накопления)
	if m.Neck and b.Neck and (flinch > 0 or v.NeckFlinched) then
		local base = neckCF or b.Neck
		m.Neck.C0 = base * ANG(-flinch * 0.3, 0, 0)
		v.NeckFlinched = flinch > 0
	end
	if flinch > 0 then
		rootCF = rootCF * CF(0, 0, flinch * 0.25 * sc) * ANG(-flinch * 0.25, 0, flinch * 0.08)
	end
	-- рёв (появление босса / смена фазы)
	local roarA = t - v.RoarT
	local roar = (roarA > 0 and roarA < 1.4) and sin(roarA / 1.4 * math.pi) or 0
	if roar > 0 then
		if m.RS and b.RS then
			m.RS.C0 = b.RS * ANG(rad(150 * roar), 0, rad(30 * roar))
			if m.LS and b.LS then
				m.LS.C0 = b.LS * ANG(rad(150 * roar), 0, rad(-30 * roar))
			end
		end
		if m.Neck and b.Neck then
			m.Neck.C0 = b.Neck * ANG(rad(-30 * roar), 0, 0)
		end
		rootCF = rootCF * ANG(rad(-12 * roar), 0, 0)
	end
	m.Root.C0 = rootCF
	if m.Jaw and b.Jaw then
		m.Jaw.C0 = b.Jaw * ANG(max(0, sin(t * 3 + v.Phase)) * 0.4 + roar * 0.6 + flinch * 0.3, 0, 0)
	end
	if not far then
		stepSecondary(v, t, dt, aggro, sc)
	end
end

------------------------------------------------------------------------
-- КАДР
------------------------------------------------------------------------
function Enemies.Update(t, dt, camPos)
	local lerpA = min(1, dt * 9)
	local catchA = min(1, dt * 5)
	for _, v in pairs(views) do
		local rig = v.Rig
		local root = rig.Root
		if root.Parent then
			local f = v.Frozen and 0 or (v.Slowed and 0.5 or 1)
			local haste = (v.HasteUntil and t < v.HasteUntil) and 1.6 or 1
			local speed = v.Speed * f * haste
			local predicted = v.ServerDist + speed * min(t - v.LastSync, 0.35)
			v.Dist += speed * dt
			v.Dist += (predicted - v.Dist) * catchA
			local hip = rig.HipHeight or 0
			local pos, dir = Path.OffsetPositionAt(v.Dist, v.Lateral)
			local up = V(0, hip, 0)
			v.CF = v.CF:Lerp(CFrame.lookAt(pos + up, pos + dir + up), lerpA)
			local rise = 0
			if v.Emerge then
				local a = (t - v.SpawnT) / 0.6
				if a < 1 then
					rise = (1 - ease(clamp(a, 0, 1))) * (hip + 1.5)
				else
					v.Emerge = false
				end
			end
			if v.FadeParts then
				local a = clamp((t - v.SpawnT) / 0.7, 0, 1)
				for _, it in ipairs(v.FadeParts) do
					it[1].Transparency = 1 - (1 - it[2]) * a
				end
				if a >= 1 then
					v.FadeParts = nil
				end
			end
			root.CFrame = rise > 0 and (v.CF - V(0, rise, 0)) or v.CF
			checkPhases(v, false)
			if not v.Frozen then
				animate(v, t, dt, camPos and (root.Position - camPos).Magnitude or 0)
			end
			local ratio = clamp(v.HP / max(v.MaxHP, 1), 0, 1)
			if ratio ~= v.FillRatio then
				v.FillRatio = ratio
				v.Fill.Size = UDim2.fromScale(ratio, 1)
			end
		end
	end
end

------------------------------------------------------------------------
-- СМЕРТЬ
------------------------------------------------------------------------
local function deathAnim(v, reason)
	local rig = v.Rig
	local model = rig.Model
	if v.Bar then
		v.Bar:Destroy()
	end
	local size = v.Def.Scale or 1
	local root = rig.Root
	local pos = root.Position
	if reason == "core" then
		FX.Poof(pos, PINK, size)
		model:Destroy()
		return
	end
	local style = rig.DeathStyle or "Topple"
	local implode = style == "Implode"
	local boss = v.Def.IsBoss == true
	local hip = rig.HipHeight or 0
	local sc = rig.Scale or 1
	if not implode then
		FX.Poof(pos + V(0, 0.5, 0), NEON, size)
	end
	FX.Sound("EnemyDeath", 1, 1 / max(size, 0.6), pos)
	if boss and not implode then
		FX.Shockwave(pos - V(0, hip - 0.2, 0), 10 * size, 5)
	end
	local life = DEATH_LIFE[style] or 1
	if style == "Topple" and boss then
		life = 1.5
	end
	local parts = {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			if d.Transparency < 1 then
				parts[#parts + 1] = { d, d.Transparency }
			end
		elseif d:IsA("ParticleEmitter") or d:IsA("Trail") then
			d.Enabled = false
		end
	end
	local motors = {}
	for name, motor in pairs(rig.Motors or {}) do
		if name ~= "Root" then
			local dir = V(math.random() - 0.5, math.random() * 0.6, math.random() - 0.5)
			motors[#motors + 1] = { motor, motor.C0, name, dir.Magnitude > 0.01 and dir.Unit or V(0, 1, 0) }
		end
	end
	local rm = rig.Motors and rig.Motors.Root
	local start = rm and rm.C0 or CF()
	if style == "Dissipate" then
		FX.Burst(pos, SOFT, 10, 0.4 * size, 4, 0.9)
	elseif implode then
		FX.Sound("Boss", 1.2, 0.6, pos)
		FX.Shake(0.6, 2.4)
	end
	local blown = false
	FX.Run(function(el)
		if not model.Parent then
			return true
		end
		local a = clamp(el / life, 0, 1)
		local fade = a
		local rc
		if style == "Dissipate" then
			rc = start * CF(0, ease(a) * 2.5 * sc, 0) * ANG(0, a * 4, 0)
		elseif style == "Scatter" then
			rc = start * CF(0, a * 1.2 * sc, 0)
			for _, it in ipairs(motors) do
				local d = it[4]
				it[1].C0 = it[2] * CF(d * ease(a) * 3 * sc) * ANG(a * d.X * 4, a * 3, a * d.Z * 4)
			end
		elseif style == "Collapse" then
			rc = start * CF(0, -ease(a) * hip * 0.7, 0) * ANG(rad(-8 * a), 0, rad(20 * ease(a)))
			for _, it in ipairs(motors) do
				local n = it[3]
				if n == "FR" or n == "BR" or n == "FL" or n == "BL" then
					local side = (n == "FR" or n == "BR") and 1 or -1
					it[1].C0 = it[2] * ANG(0, 0, side * ease(a) * 1.1)
				end
			end
			fade = clamp((a - 0.4) / 0.6, 0, 1)
		elseif implode then
			if a < 0.55 then
				local k = a / 0.55
				rc = start * CF((math.random() - 0.5) * 0.4 * k * sc, k * 1.5 * sc, 0) * ANG(rad(-15 * k), 0, 0)
				for _, it in ipairs(motors) do
					if it[3] == "RS" or it[3] == "LS" then
						it[1].C0 = it[2] * ANG(rad(120 * k), 0, rad((it[3] == "RS" and 40 or -40) * k))
					end
				end
				if not FX.Lite and math.random() < 0.25 then
					local c = root.Position
					FX.Burst(c + V((math.random() - 0.5) * 6 * sc, (math.random() - 0.5) * 6 * sc, (math.random() - 0.5) * 6 * sc), NEON, 3, 0.4 * sc, 6, 0.4)
				end
				fade = 0
			else
				if not blown then
					blown = true
					local c = root.Position
					FX.Sphere(c, 9 * sc, WHITE, 0.6)
					FX.Sphere(c, 14 * sc, NEON, 0.9, nil, 0.2)
					FX.Shockwave(c - V(0, hip - 0.2, 0), 14 * size, 5)
					FX.Burst(c, SOFT, 30, 0.8, 22, 1)
					FX.Shake(1.2, 0.8)
				end
				local k = (a - 0.55) / 0.45
				rc = start * CF(0, 1.5 * sc - ease(k) * hip * 0.6, 0) * ANG(rad(-15 + 30 * k), k * 2, 0)
				fade = k
			end
		else -- Topple
			rc = start * CF(0, -a * hip * 0.8, 0) * ANG(rad(-75 * ease(a)), 0, rad(15 * a))
			for _, it in ipairs(motors) do
				local n = it[3]
				if n == "RS" or n == "LS" then
					it[1].C0 = it[2] * ANG(rad(70 * ease(a)), 0, 0)
				elseif n == "RH" or n == "LH" then
					it[1].C0 = it[2] * ANG(rad(40 * ease(a)), 0, 0)
				end
			end
			fade = clamp((a - 0.3) / 0.7, 0, 1)
		end
		if rm then
			rm.C0 = rc
		end
		for _, it in ipairs(parts) do
			it[1].Transparency = it[2] + (1 - it[2]) * fade
		end
		if a >= 1 then
			model:Destroy()
			return true
		end
		return false
	end)
end

function Enemies.Remove(id, reason)
	local v = views[id]
	if not v then
		return
	end
	views[id] = nil
	local model = v.Rig.Model
	if reason == "clear" then
		if model.Parent then
			FX.Poof(v.Rig.Root.Position, NEON, 0.8)
		end
		model:Destroy()
		return
	end
	if not model.Parent then
		return
	end
	if v.Rig.DeathFX and reason ~= "core" and FX.Fn.EnemyDeath then
		FX.Fn.EnemyDeath(v, reason)
	end
	deathAnim(v, reason)
end

function Enemies.Clear()
	for id in pairs(views) do
		Enemies.Remove(id, "clear")
	end
end

return Enemies
