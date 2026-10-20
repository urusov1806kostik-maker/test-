--!nocheck
-- VOID TD :: Render/Units — виды юнитов: модель по атрибутам папки VoidTD.Units/<uid>, табличка уровня,
-- слежение за врагом, разминки, плащи, буря часовщика, эффекты установки и атак (урон — на сервере).
--
-- API (вызывается из Render/init)
--   Units.Init(R, ctx)
--   Units.Add(folder, isNew) ; Units.Remove(folder) ; Units.Rebuild() ; Units.Cheer()
--   Units.Update(t, dt) ; Units.OnAttack(p)
--   Units.Views  -- uid -> view { Uid, Folder, UnitId, Level, Pos, Yaw, Rig, Anim, Phase, ... }

local Units = {}

local V = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles
local rad = math.rad
local min, clamp = math.min, math.clamp

local R, ctx, Config, Path, UnitModels, FX, Anims
local views = {}
Units.Views = views

local NEON = Color3.fromRGB(180, 80, 255)
local SOFT = Color3.fromRGB(215, 160, 255)
local PINK = Color3.fromRGB(255, 60, 170)
local RED = Color3.fromRGB(255, 35, 55)
local STORM_GLOW = Color3.fromRGB(255, 170, 60)

local function ease(a)
	return a * a * (3 - 2 * a)
end

local function yawTo(from, to)
	local d = to - from
	return math.atan2(-d.X, -d.Z)
end

function Units.Init(renderer, c)
	R, ctx = renderer, c
	Config, Path, UnitModels, FX, Anims = c.Config, c.Path, c.UnitModels, c.FX, c.Anims
end

local function levelStats(def, lv)
	local levels = def.Levels or {}
	return levels[clamp(lv or 1, 1, math.max(#levels, 1))] or {}
end

local function rarityColor(def)
	local r = def and Config.Rarities[def.Rarity]
	return r and r.Color or NEON
end

------------------------------------------------------------------------
-- МОДЕЛЬ
------------------------------------------------------------------------
local function makeTag(v, rig, def)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Tag"
	gui.Size = UDim2.fromOffset(110, 34)
	gui.StudsOffsetWorldSpace = V(0, 2.7 * (rig.Scale or 1) + 1.2, 0)
	gui.MaxDistance = ctx.Lite and 30 or 70
	gui.LightInfluence = 0
	gui.AlwaysOnTop = false
	gui.Adornee = rig.Root
	local lv = clamp(v.Level, 0, 5)
	local stars = Instance.new("TextLabel")
	stars.BackgroundTransparency = 1
	stars.Size = UDim2.fromScale(1, 0.55)
	stars.Font = Enum.Font.FredokaOne
	stars.TextScaled = true
	stars.Text = string.rep("★", lv) .. string.rep("☆", 5 - lv)
	stars.TextColor3 = rarityColor(def)
	stars.TextStrokeTransparency = 0.2
	stars.Parent = gui
	local owner = Instance.new("TextLabel")
	owner.BackgroundTransparency = 1
	owner.Position = UDim2.fromScale(0, 0.55)
	owner.Size = UDim2.fromScale(1, 0.45)
	owner.Font = Enum.Font.GothamBold
	owner.TextScaled = true
	owner.Text = tostring(v.Folder:GetAttribute("OwnerName") or "")
	owner.TextColor3 = Color3.fromRGB(220, 210, 235)
	owner.TextStrokeTransparency = 0.4
	owner.Parent = gui
	gui.Parent = rig.Root
end

local function setStorm(v, on)
	local rig = v.Rig
	if not rig then
		return
	end
	rig.Storm = on
	for _, d in ipairs(rig.Model:GetDescendants()) do
		if d:IsA("BasePart") then
			local st = d:GetAttribute("StormFX")
			if type(st) == "number" then
				if on then
					d.Transparency = st
				else
					FX.Tween(d, 0.8, { Transparency = 1 })
				end
			elseif d:GetAttribute("AxeGlow") then
				local base = d:GetAttribute("BaseColor")
				if base == nil then
					base = d.Color
					d:SetAttribute("BaseColor", base)
				end
				d.Color = on and STORM_GLOW or base
			end
		end
	end
end

local function build(v)
	if v.Rig and v.Rig.Model then
		v.Rig.Model:Destroy()
	end
	v.Rig = nil
	v.Anim = nil
	local ok, rig = pcall(UnitModels.Build, v.UnitId, v.Level)
	if not ok or not rig then
		warn("[VOID TD] юнит " .. tostring(v.UnitId) .. ": " .. tostring(rig))
		return
	end
	rig.Model:SetAttribute("Uid", v.Uid)
	v.Trails = {}
	for _, d in ipairs(rig.Model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CanQuery = true
			d.CanTouch = false
		elseif d:IsA("Trail") then
			d.Enabled = false
			v.Trails[#v.Trails + 1] = d
		end
	end
	v.TrailOn = false
	rig.Root.CFrame = CF(v.Pos + V(0, rig.HipHeight or 0, 0)) * ANG(0, v.Yaw, 0)
	v.Rig = rig
	makeTag(v, rig, v.Def)
	rig.Model.Parent = R.UnitFolder
end

local function onAttr(v, attr)
	local f = v.Folder
	if attr == "Level" then
		v.Level = f:GetAttribute("Level") or v.Level
		build(v)
		if f:GetAttribute("Storm") then
			setStorm(v, true)
		end
		FX.LevelUp(v.Pos, rarityColor(v.Def))
		Anims.Play(v, "PowerUp")
	elseif attr == "Storm" then
		setStorm(v, f:GetAttribute("Storm") == true)
		return
	end
	if R.OnUnitChanged then
		R.OnUnitChanged(v.Uid)
	end
end

function Units.Add(folder, isNew)
	local uid = tonumber(folder.Name)
	if not uid or views[uid] or not folder.Parent then
		return
	end
	local id = folder:GetAttribute("UnitId")
	local pos = folder:GetAttribute("Position")
	local def = id and Config.Units[id]
	if not def or typeof(pos) ~= "Vector3" then
		return
	end
	local now = os.clock()
	local yaw = rad(folder:GetAttribute("Rotation") or 0)
	local v = {
		Uid = uid, Folder = folder, UnitId = id, Def = def, Level = folder:GetAttribute("Level") or 1, Pos = pos,
		Yaw = yaw, TargetYaw = yaw, Phase = math.random() * 10, NextFidget = now + 4 + math.random() * 8,
		NextTrack = 0, GustT = -10, Trails = {},
	}
	views[uid] = v
	build(v)
	if folder:GetAttribute("Storm") then
		setStorm(v, true)
	end
	local fx = def.PlaceFX
	if isNew then
		if fx == "Throne" then
			v.DropT = now
			if FX.Fn.ThronePlace then
				FX.Fn.ThronePlace(pos)
			end
		elseif fx == "Clock" then
			v.RiseT = now
			if FX.ClockPortal then
				FX.ClockPortal(pos, 1.3)
			end
		else
			v.DropT = now
		end
	else
		FX.Place(pos)
	end
	v.Conn = folder.AttributeChanged:Connect(function(attr)
		if views[uid] == v then
			onAttr(v, attr)
		end
	end)
end

function Units.Remove(folder)
	local uid = tonumber(folder.Name)
	local v = uid and views[uid]
	if not v then
		return
	end
	views[uid] = nil
	if v.Conn then
		v.Conn:Disconnect()
	end
	FX.Poof(v.Pos + V(0, 2, 0), SOFT, 1)
	if v.Rig then
		v.Rig.Model:Destroy()
	end
	if R.OnUnitRemoved then
		R.OnUnitRemoved(uid)
	end
end

-- после смены графики: пересобрать модели (и вернуть бурю)
function Units.Rebuild()
	for _, v in pairs(views) do
		build(v)
		if v.Folder:GetAttribute("Storm") then
			setStorm(v, true)
		end
	end
end

function Units.Cheer()
	for _, v in pairs(views) do
		task.delay(math.random() * 0.3, function()
			if views[v.Uid] == v and v.Rig then
				Anims.Play(v, "Cheer")
			end
		end)
	end
end

------------------------------------------------------------------------
-- КАДР
------------------------------------------------------------------------
local function nearestEnemy(v, range)
	local best, bd
	for _, e in pairs(R.EnemyViews) do
		local d = Path.FlatDistance(v.Pos, e.Rig.Root.Position)
		if d <= range and (not bd or d < bd) then
			best, bd = e, d
		end
	end
	return best
end

function Units.Update(t, dt)
	local turnA = min(1, dt * 8)
	for _, v in pairs(views) do
		local rig = v.Rig
		if rig and rig.Root.Parent then
			if t >= v.NextTrack then
				v.NextTrack = t + 0.3
				local e = nearestEnemy(v, (levelStats(v.Def, v.Level).Range or 10) + 6)
				if e and not v.Anim then
					v.TargetYaw = yawTo(v.Pos, e.Rig.Root.Position)
				end
			end
			if not v.Anim and t >= v.NextFidget then
				Anims.PlayFidget(v, v.Def.Anim)
				v.NextFidget = t + 6 + math.random() * 8
			end
			rig.Gust = math.max(0, 1 - (t - v.GustT) / 0.8)
			local diff = (v.TargetYaw - v.Yaw + math.pi) % (2 * math.pi) - math.pi
			v.Yaw += diff * turnA
			local drop = 0
			if v.DropT then
				local a = clamp((t - v.DropT) / 0.3, 0, 1)
				drop = (1 - a * a) * 7
				if a >= 1 then
					v.DropT = nil
					Anims.Play(v, "Land")
					FX.Place(v.Pos)
				end
			elseif v.RiseT then
				local a = clamp((t - v.RiseT) / 1.3, 0, 1)
				drop = -(1 - ease(a)) * ((rig.HipHeight or 0) + 2.5)
				if a >= 1 then
					v.RiseT = nil
					Anims.Play(v, "TimeHaste")
				end
			end
			rig.Root.CFrame = CF(v.Pos + V(0, (rig.HipHeight or 0) + drop, 0)) * ANG(0, v.Yaw, 0)
			Anims.Step(v, t)
			local on = v.Anim ~= nil
			if on ~= v.TrailOn then
				v.TrailOn = on
				for _, tr in ipairs(v.Trails) do
					tr.Enabled = on
				end
			end
		end
	end
end

------------------------------------------------------------------------
-- АТАКИ (вылет снаряда / взмах; области — по Impact)
------------------------------------------------------------------------
local function alive(v)
	return views[v.Uid] == v and v.Rig ~= nil and v.Rig.Model.Parent ~= nil
end

local function flatLook(origin, target)
	return CFrame.lookAt(origin, V(target.X, origin.Y, target.Z))
end

function Units.OnAttack(p)
	local v = p.U and views[p.U]
	if not v or not v.Rig then
		return
	end
	local def = v.Def
	local lv = p.L or v.Level
	local h = p.D or def.HitDelay or 0.2
	local targets = p.T or {}
	local firstId = targets[1]
	local tpos = firstId and R.EnemyCenter(firstId)
	if tpos then
		v.TargetYaw = yawTo(v.Pos, tpos)
	end
	local now = os.clock()
	if type(p.AB) == "string" then
		Anims.Play(v, p.AB, h)
		v.Rig.SpinBoostUntil = now + (p.AB == "TimeStorm" and 2.4 or 1.6)
		return
	elseif p.AB then
		Anims.Play(v, "BlackHoleCast", h)
		local crystal = v.Rig.Model:FindFirstChild("Crystal", true)
		if crystal and crystal:IsA("BasePart") then
			FX.Sphere(crystal.Position, 3, NEON, 0.5)
		end
		return
	end
	local hits = math.max(#targets, 1)
	if p.EC then
		if FX.Fn.EchoGhost then
			FX.Fn.EchoGhost(v)
		end
	else
		Anims.Play(v, def.Anim, h, hits, p.I)
		v.GustT = now
		v.NextFidget = now + 6 + math.random() * 6
	end
	if FX.Fn.HalloweenAttack and FX.Fn.HalloweenAttack(v, def, p, h, lv) then
		return
	end
	local impactColor = def.ImpactColor or NEON
	local kind = def.AttackType
	local function at(d, fn)
		task.delay(d, function()
			if alive(v) then
				fn()
			end
		end)
	end
	local function muzzle()
		return R.MuzzlePos(v)
	end
	if kind == "Chrono" then
		at(h, function()
			if p.E and FX.GearDisc then
				local from = muzzle()
				local to = V(p.E.X, from.Y - 1.5, p.E.Z)
				FX.GearDisc(from, to, Path.FlatDistance(v.Pos, to) / (p.SP or 70), lv, p.ST)
			end
		end)
	elseif kind == "Projectile" then
		local list = #targets > 0 and targets or { firstId }
		for si, id in ipairs(list) do
			local travel = (p.TRS and p.TRS[si]) or p.TR or 0.2
			at(h + (si - 1) * (p.SG or 0.12), function()
				local from = muzzle()
				local pk = def.Projectile
				FX.Sound("Shoot", pk == "Bolt" and 0.6 or 1, pk == "Bullet" and 0.8 or 1, from)
				FX.Projectile(pk, from, function() return id and R.EnemyCenter(id) end, travel, function(pos)
					local orb = pk == "Orb"
					FX.Burst(pos, orb and NEON or impactColor, orb and 8 or 4, 0.3, 5)
					if orb then
						FX.Sphere(pos, 1.4 + lv * 0.15, NEON, 0.25)
					end
				end, lv)
				if pk == "Bolt" or pk == "Bullet" then
					FX.Sphere(from, 0.6, impactColor, 0.12)
				end
			end)
		end
	elseif kind == "Chain" then
		local times = p.TT or {}
		for i, id in ipairs(targets) do
			local prevT = i == 1 and h or (times[i - 1] or h)
			local prevId = targets[i - 1]
			at(prevT, function()
				local from = (i == 1) and muzzle() or (R.EnemyCenter(prevId) or muzzle())
				FX.Sound("Magic", 0.8, 1.3 + i * 0.1, from)
				FX.Projectile("Moon", from, function() return R.EnemyCenter(id) end, math.max((times[i] or prevT) - prevT, 0.05), function(pos)
					FX.Burst(pos, impactColor, 6, 0.3, 6)
					FX.Ring(pos - V(0, 1, 0), 2.5, impactColor, 0.3, 0.2)
				end, lv)
			end)
		end
	elseif kind == "Thread" then
		at(h, function()
			FX.Sound("Magic", 0.8, 0.7, v.Pos)
			for _, id in ipairs(targets) do
				local c = R.EnemyCenter(id)
				if c then
					FX.Thread(muzzle(), c, SOFT)
				end
			end
		end)
	elseif kind == "Splash" then
		at(h, function() FX.Sphere(muzzle(), 2.2, RED, 0.25) end)
	elseif kind == "Pierce" then
		at(h, function() FX.Sphere(muzzle(), 2, Color3.fromRGB(255, 190, 215), 0.3) end)
	elseif kind == "Laser" then
		at(h, function()
			local target = (firstId and R.EnemyCenter(firstId)) or tpos
			if target then
				FX.Sound("Laser", 1, 1, target)
				local big = lv >= 5
				FX.Beam(muzzle(), target, big and 2.6 or 1.2 + lv * 0.2, big and SOFT or NEON, 0.45, big)
			end
		end)
	elseif kind == "Melee" then
		at(h, function()
			local target = (firstId and R.EnemyCenter(firstId)) or tpos
			if not target then
				return
			end
			local origin = v.Rig.Root.Position + V(0, 1, 0)
			local cf = flatLook(origin, target)
			local reach = math.max(Path.FlatDistance(origin, target) * 0.6, 3)
			local big = v.UnitId == "AbyssOverlord" or p.PW
			local arcColor = def.ImpactColor or (big and NEON or SOFT)
			if p.PW then
				arcColor = PINK
				FX.Sphere(target, 2.2, PINK, 0.25)
			end
			FX.Arc(cf, reach, rad(15), rad(150), arcColor, big and 1 or 0.4 + lv * 0.05, 0.3)
			if def.Anim == "DualDagger" then
				FX.Arc(cf * ANG(0, 0, rad(60)), reach * 0.9, rad(20), rad(140), NEON, 0.35, 0.25)
			end
			FX.Sound(big and "HeavyHit" or "Slash", 1, 1, target)
			FX.Burst(target, NEON, big and 12 or 5, big and 0.6 or 0.3, big and 10 or 5)
			if big then
				FX.Ring(V(target.X, v.Pos.Y + 0.2, target.Z), 4, NEON, 0.35, 0.3)
			end
			if v.UnitId == "VoidKnight" and lv >= 3 then
				FX.Sphere(target, 1.5 + lv * 0.3, Color3.fromRGB(70, 20, 120), 0.35)
				FX.Burst(target, Color3.fromRGB(40, 10, 70), 8, 0.5, 6)
			end
		end)
	elseif kind == "AOE" then
		at(h, function()
			if v.UnitId == "EclipseGuardian" then
				FX.Sphere(muzzle(), 2, NEON, 0.25)
			elseif v.UnitId == "AbyssOverlord" then
				local target = (firstId and R.EnemyCenter(firstId)) or tpos
				if target then
					local origin = v.Rig.Root.Position + V(0, 1, 0)
					FX.Arc(flatLook(origin, target), math.max(Path.FlatDistance(origin, target) * 0.6, 3), rad(15), rad(150), NEON, 1, 0.3)
				end
			end
		end)
	elseif kind == "MultiHit" then
		local interval = p.I or def.HitInterval or 0.16
		for i, id in ipairs(targets) do
			at(h + (i - 1) * interval, function()
				local target = R.EnemyCenter(id) or tpos
				if v.UnitId == "CorruptedSamurai" then
					if not target then
						return
					end
					local origin = v.Rig.Root.Position + V(0, 1, 0)
					local even = i % 2 == 0
					local cf = flatLook(origin, target) * ANG(0, 0, rad(even and 50 or -50))
					local reach = math.max(Path.FlatDistance(origin, target) * 0.6, 3)
					FX.Arc(cf, reach, rad(10), rad(140), lv >= 5 and PINK or NEON, 0.35 + lv * 0.05, 0.25)
					FX.Sound("Slash", 1, 1.15, target)
					if lv >= 3 then
						FX.SlashMark(target, rad(even and 40 or -40), 5 + lv * 0.5, 0.35, NEON, 0.3)
					end
				else
					FX.Sphere(muzzle(), 1.6, def.ImpactKind == "Rift" and NEON or PINK, 0.2)
				end
			end)
		end
	end
end

return Units
