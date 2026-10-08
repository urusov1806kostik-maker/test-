--!nocheck
-- ПОСЁЛОК: ЛИНИЯ ФРОНТА — серверная часть (карта, боты, техника, дроны, точки)
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local Teams = game:GetService("Teams")
local Lighting = game:GetService("Lighting")

local S = 3.5 -- studs per meter
local rnd = Random.new()
local function rand(a, b) return a + rnd:NextNumber() * (b - a) end
local function pick(t) return t[rnd:NextInteger(1, #t)] end
local function MAT(name, fb)
	local ok, m = pcall(function() return Enum.Material[name] end)
	if ok and m then return m end
	return fb
end
local C3 = Color3.fromRGB

-- ===== NET =====
local Net = Instance.new("RemoteEvent"); Net.Name = "Net"; Net.Parent = RS
local NetF = Instance.new("RemoteFunction"); NetF.Name = "NetF"; NetF.Parent = RS
RS:SetAttribute("Mode", "")
RS:SetAttribute("T0", 300); RS:SetAttribute("T1", 300)
RS:SetAttribute("SB", false)

-- ===== TEAMS =====
local TEAM = {}
do
	local t0 = Instance.new("Team"); t0.Name = "Северные"; t0.TeamColor = BrickColor.new("Bright blue"); t0.AutoAssignable = true; t0.Parent = Teams
	local t1 = Instance.new("Team"); t1.Name = "Южные"; t1.TeamColor = BrickColor.new("Bright red"); t1.AutoAssignable = false; t1.Parent = Teams
	TEAM[0] = t0; TEAM[1] = t1
end
local TEAMCOL = { [0] = C3(60, 120, 255), [1] = C3(255, 60, 60) }

-- ===== LIGHTING =====
Lighting.ClockTime = 14.5
Lighting.Brightness = 2.5
Lighting.GlobalShadows = true
Lighting.OutdoorAmbient = C3(130, 130, 120)
pcall(function() Lighting.Technology = Enum.Technology.ShadowMap end)
local atm = Instance.new("Atmosphere"); atm.Density = 0.32; atm.Haze = 1.2; atm.Color = C3(200, 210, 220); atm.Parent = Lighting
local bloom = Instance.new("BloomEffect"); bloom.Intensity = 0.4; bloom.Threshold = 1.2; bloom.Parent = Lighting
local sunr = Instance.new("SunRaysEffect"); sunr.Intensity = 0.05; sunr.Parent = Lighting

-- ===== FOLDERS =====
for _, c in ipairs(workspace:GetChildren()) do
	if c:IsA("BasePart") and c.Name == "Baseplate" then c:Destroy() end
	if c:IsA("SpawnLocation") then c:Destroy() end
end
local World = Instance.new("Folder"); World.Name = "World"; World.Parent = workspace
local FX = Instance.new("Folder"); FX.Name = "FX"; FX.Parent = workspace
local BotsM = Instance.new("Model"); BotsM.Name = "Bots"; BotsM.Parent = workspace
local VehM = Instance.new("Model"); VehM.Name = "Vehicles"; VehM.Parent = workspace
local DroneF = Instance.new("Model"); DroneF.Name = "Drones"; DroneF.Parent = workspace

-- ===== PART HELPERS (meters) =====
local function P(size, cf, color, mat, parent)
	local p = Instance.new("Part")
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent or World
	return p
end
local function B(x0, y0, z0, x1, y1, z1, color, mat, parent)
	local sx, sy, sz = math.abs(x1 - x0), math.abs(y1 - y0), math.abs(z1 - z0)
	return P(Vector3.new(math.max(sx, 0.05) * S, math.max(sy, 0.05) * S, math.max(sz, 0.05) * S),
		CFrame.new((x0 + x1) / 2 * S, (y0 + y1) / 2 * S, (z0 + z1) / 2 * S), color, mat, parent)
end
local function V(x, y, z) return Vector3.new(x * S, y * S, z * S) end

local M_ASPH = MAT("Asphalt", Enum.Material.Concrete)
local M_GROUND = MAT("Ground", Enum.Material.Sand)
local M_PLASTER = MAT("Plaster", Enum.Material.SmoothPlastic)
local M_ROOF = MAT("RoofShingles", Enum.Material.Slate)
local M_CLAY = MAT("ClayRoofTiles", Enum.Material.Slate)
local M_LEAF = MAT("LeafyGrass", Enum.Material.Grass)
local M_MUD = MAT("Mud", Enum.Material.Sand)

-- ===== TERRAIN / GROUND =====
local ground = P(Vector3.new(2040, 4, 2040), CFrame.new(0, -2, 0), C3(86, 112, 50), Enum.Material.Grass)
ground.Name = "Ground"
local roads = {}
local function road(x0, z0, x1, z1, w, asph)
	local p
	if math.abs(x1 - x0) > math.abs(z1 - z0) then
		p = B(x0, 0, z0 - w / 2, x1, 0.06, z1 + w / 2, asph and C3(58, 60, 63) or C3(122, 100, 72), asph and M_ASPH or M_GROUND)
	else
		p = B(x0 - w / 2, 0, z0, x1 + w / 2, 0.06, z1, asph and C3(58, 60, 63) or C3(122, 100, 72), asph and M_ASPH or M_GROUND)
	end
	table.insert(roads, { x0, z0, x1, z1, w, asph })
	if asph and math.abs(x1 - x0) > 100 then B(x0, 0.06, -0.08, x1, 0.07, 0.08, C3(220, 220, 205), Enum.Material.SmoothPlastic) end
end
road(-255, 0, 255, 0, 9, true); road(0, -170, 0, 170, 7, true)
road(-135, -55, 135, -55, 5); road(-135, 55, 135, 55, 5); road(-135, -55, -135, 55, 5); road(135, -55, 135, 55, 5)
road(-60, 55, -60, 150, 4); road(60, -55, 60, -150, 4)
local fields = { { -140, 135, 130, 80, false }, { 20, 135, 110, 80, true }, { 150, 130, 110, 90, false }, { -150, -130, 110, 90, true }, { -30, -135, 120, 80, false }, { 140, -135, 120, 80, true } }
for _, f in ipairs(fields) do
	B(f[1] - f[3] / 2, 0, f[2] - f[4] / 2, f[1] + f[3] / 2, 0.04, f[2] + f[4] / 2, f[5] and C3(181, 154, 76) or C3(106, 82, 54), f[5] and Enum.Material.Grass or M_MUD)
	if f[5] then -- wheat rows
		for i = 0, 7 do
			local z = f[2] - f[4] / 2 + 5 + i * (f[4] - 10) / 7
			B(f[1] - f[3] / 2 + 2, 0, z - 0.6, f[1] + f[3] / 2 - 2, 0.9, z + 0.6, C3(196, 170, 90), Enum.Material.Grass).CanCollide = false
		end
	end
end

-- ===== HOUSES =====
local houses = {}
local styles = {
	brick = { C3(150, 72, 52), Enum.Material.Brick },
	wood = { C3(115, 82, 55), Enum.Material.WoodPlanks },
	plaster = { C3(214, 204, 180), M_PLASTER },
	white = { C3(225, 225, 215), M_PLASTER },
}
local roofCols = { { C3(150, 70, 50), M_CLAY }, { C3(125, 130, 135), Enum.Material.CorrodedMetal }, { C3(90, 120, 90), M_ROOF }, { C3(120, 125, 130), M_ROOF } }
local function markDestr(p, hp, kind)
	p:SetAttribute("HP", hp)
	p:SetAttribute("Kind", kind)
end
local function buildHouse(cx, cz, w, d, face, opt)
	opt = opt or {}
	local h = opt.h or 3
	local floors = opt.floors or 1
	local ruined = opt.ruined
	if ruined == nil then ruined = rnd:NextNumber() < 0.16 end
	local st = styles[opt.style or pick({ "brick", "wood", "plaster", "plaster", "white" })]
	local col, mat = st[1], st[2]
	if ruined and rnd:NextNumber() < 0.5 then col = C3(45, 40, 36) end
	local model = Instance.new("Model"); model.Name = opt.name or "Дом"; model.Parent = World
	local hw, hd = w / 2, d / 2
	local t = 0.25
	local sides = {
		{ ax = "x", fixed = -hd, u0 = -hw, u1 = hw },
		{ ax = "x", fixed = hd, u0 = -hw, u1 = hw },
		{ ax = "z", fixed = -hw, u0 = -hd, u1 = hd },
		{ ax = "z", fixed = hw, u0 = -hd, u1 = hd },
	}
	for i, s in ipairs(sides) do
		local len = s.u1 - s.u0
		local sh = h
		if ruined and rnd:NextNumber() < 0.5 then sh = rand(1.2, h * 0.7) end
		local cols = {}
		local doorU = nil
		if i - 1 == face then
			doorU = opt.doorU or rand(-len / 4, len / 4)
			local holes = { { 0, 2.2, false } }
			if floors > 1 then table.insert(holes, { 4.2, 5.2, true }) end
			table.insert(cols, { u0 = doorU - 0.65, u1 = doorU + 0.65, holes = holes })
		end
		local nW = math.max(1, math.floor(len / 3.4))
		for k = 0, nW - 1 do
			local um = s.u0 + len * (k + 0.5) / nW
			local ok = true
			if doorU and math.abs(um - doorU) < 1.6 then ok = false end
			if math.abs(um - s.u0) < 0.9 or math.abs(um - s.u1) < 0.9 then ok = false end
			if ok then
				local holes = { { 1.0, 2.0, true } }
				if floors > 1 then table.insert(holes, { 4.2, 5.2, true }) end
				table.insert(cols, { u0 = um - 0.6, u1 = um + 0.6, holes = holes })
			end
		end
		table.sort(cols, function(a, b) return a.u0 < b.u0 end)
		local function piece(ua, ub, ya, yb)
			if ub - ua < 0.05 or yb - ya < 0.05 then return end
			ya = math.min(ya, sh); yb = math.min(yb, sh)
			if yb - ya < 0.05 then return end
			local p
			if s.ax == "x" then
				p = B(cx + ua, ya, cz + s.fixed - t / 2, cx + ub, yb, cz + s.fixed + t / 2, col, mat, model)
			else
				p = B(cx + s.fixed - t / 2, ya, cz + ua, cx + s.fixed + t / 2, yb, cz + ub, col, mat, model)
			end
			markDestr(p, 140, "wall")
		end
		local u = s.u0
		for _, oc in ipairs(cols) do
			piece(u, oc.u0, 0, h)
			local y = 0
			for _, hole in ipairs(oc.holes) do
				piece(oc.u0, oc.u1, y, hole[1])
				y = hole[2]
				if hole[3] and hole[2] <= sh and not ruined then
					local g
					if s.ax == "x" then
						g = B(cx + oc.u0, hole[1], cz + s.fixed - 0.03, cx + oc.u1, hole[2], cz + s.fixed + 0.03, C3(150, 190, 215), Enum.Material.Glass, model)
					else
						g = B(cx + s.fixed - 0.03, hole[1], cz + oc.u0, cx + s.fixed + 0.03, hole[2], cz + oc.u1, C3(150, 190, 215), Enum.Material.Glass, model)
					end
					g.Transparency = 0.55
					g:SetAttribute("Kind", "glass")
				end
			end
			piece(oc.u0, oc.u1, y, h)
			u = oc.u1
		end
		piece(u, s.u1, 0, h)
	end
	B(cx - hw + 0.15, 0, cz - hd + 0.15, cx + hw - 0.15, 0.08, cz + hd - 0.15, C3(120, 95, 70), Enum.Material.WoodPlanks, model)
	if floors > 1 then
		local f2 = B(cx - hw, 3.1, cz - hd, cx + hw, 3.3, cz + hd, C3(140, 140, 135), Enum.Material.Concrete, model)
		markDestr(f2, 300, "wall")
	end
	if not ruined and not opt.noInterior then
		local tx, tz = cx + rand(-hw / 2, hw / 2), cz + rand(-hd / 2, hd / 2)
		B(tx - 0.6, 0, tz - 0.4, tx + 0.6, 0.8, tz + 0.4, C3(110, 75, 45), Enum.Material.Wood, model):SetAttribute("Cover", true)
		B(cx - hw + 0.3, 0, cz + hd - 2, cx - hw + 2.1, 0.55, cz + hd - 1, C3(230, 230, 225), Enum.Material.Fabric, model)
		B(cx + hw - 0.8, 0, cz - hd + 0.4, cx + hw - 0.2, 1.9, cz - hd + 1.6, C3(100, 70, 45), Enum.Material.Wood, model)
	end
	if ruined then
		for _ = 1, 4 do
			local r = B(0, 0, 0, rand(1, 2.5), rand(0.3, 0.8), rand(1, 2), C3(110, 105, 100), Enum.Material.Concrete, model)
			r.CFrame = CFrame.new(V(cx + rand(-hw + 1, hw - 1), 0.25, cz + rand(-hd + 1, hd - 1))) * CFrame.Angles(0, rand(0, 3), rand(-0.2, 0.2))
		end
	else
		local rc = opt.roof or pick(roofCols)
		local rh = 1.6
		local a = math.atan(rh / hd)
		local L = math.sqrt(hd * hd + rh * rh) + 0.5
		for sgn = -1, 1, 2 do
			local slab = P(Vector3.new((w + 0.8) * S, 0.2 * S, L * S), CFrame.new(V(cx, h + rh / 2, cz + sgn * hd / 2)) * CFrame.Angles(sgn * a, 0, 0), rc[1], rc[2], model)
			markDestr(slab, 160, "wall")
		end
		-- gable ends
		for sgn = -1, 1, 2 do
			for k = 0, 3 do
				local hh = rh * (1 - k / 4)
				local ww = d * (1 - k / 4)
				local g = B(cx + sgn * hw - 0.12, h + k * rh / 4, cz - ww / 2, cx + sgn * hw + 0.12, h + k * rh / 4 + rh / 4, cz + ww / 2, col, mat, model)
				markDestr(g, 100, "wall")
			end
		end
		B(cx + hw * 0.4 - 0.25, h, cz + hd * 0.2 - 0.25, cx + hw * 0.4 + 0.25, h + 2.1, cz + hd * 0.2 + 0.25, C3(140, 70, 55), Enum.Material.Brick, model)
	end
	if opt.sign then
		local z = (face == 0) and (cz - hd - 0.15) or (cz + hd + 0.15)
		local sp = B(cx - 2, h - 0.8, z - 0.05, cx + 2, h - 0.1, z + 0.05, opt.signCol or C3(40, 100, 180), Enum.Material.SmoothPlastic, model)
		local gui = Instance.new("SurfaceGui"); gui.Face = face == 0 and Enum.NormalId.Front or Enum.NormalId.Back; gui.Parent = sp
		local tl = Instance.new("TextLabel"); tl.Size = UDim2.fromScale(1, 1); tl.BackgroundTransparency = 1; tl.Text = opt.name; tl.TextScaled = true; tl.TextColor3 = C3(255, 255, 255); tl.Font = Enum.Font.GothamBold; tl.Parent = gui
	end
	local hs = { cx = cx, cz = cz, w = w, d = d, ruined = ruined, model = model }
	table.insert(houses, hs)
	return hs
end

local function fenceLine(x0, z0, x1, z1, gap)
	local len = math.sqrt((x1 - x0) ^ 2 + (z1 - z0) ^ 2)
	local n = math.ceil(len / 2.5)
	local alongX = math.abs(x1 - x0) > math.abs(z1 - z0)
	for i = 0, n - 1 do
		local a, b = i / n, (i + 1) / n
		local mx, mz = x0 + (x1 - x0) * (a + b) / 2, z0 + (z1 - z0) * (a + b) / 2
		local skip = rnd:NextNumber() < 0.06
		if gap and math.abs(mx - gap[1]) < 2 and math.abs(mz - gap[2]) < 2 then skip = true end
		if not skip then
			local sl = len / n
			local p
			if alongX then p = B(mx - sl / 2, 0, mz - 0.04, mx + sl / 2, 1.5, mz + 0.04, C3(150, 120, 85), Enum.Material.WoodPlanks)
			else p = B(mx - 0.04, 0, mz - sl / 2, mx + 0.04, 1.5, mz + sl / 2, C3(150, 120, 85), Enum.Material.WoodPlanks) end
			markDestr(p, 30, "fence")
		end
	end
end

-- plots
local plots = {}
local function plotsAlong(zr, side, xs)
	for _, x in ipairs(xs) do
		if math.abs(x) >= 16 and rnd:NextNumber() > 0.12 then
			table.insert(plots, { x = x + rand(-1.5, 1.5), z = zr + side * 15, face = side > 0 and 0 or 1 })
		end
	end
end
local xsMain, xsDirt = {}, {}
for x = -125, 125, 21 do table.insert(xsMain, x) end
for x = -112, 112, 24 do table.insert(xsDirt, x) end
plotsAlong(0, 1, xsMain); plotsAlong(0, -1, xsMain); plotsAlong(55, 1, xsDirt); plotsAlong(55, -1, xsDirt); plotsAlong(-55, 1, xsDirt); plotsAlong(-55, -1, xsDirt)
local specials = {
	{ x = -24, z = 18, w = 14, d = 10, name = "Администрация", face = 0, style = "white", h = 3.4, signCol = C3(200, 200, 200) },
	{ x = 24, z = 16, w = 11, d = 8, name = "Магазин", face = 0, style = "plaster", h = 3 },
	{ x = 28, z = -20, w = 20, d = 10, name = "Школа", face = 1, style = "brick", floors = 2, h = 6.4 },
}
for _, s in ipairs(specials) do
	buildHouse(s.x, s.z, s.w, s.d, s.face, { style = s.style, ruined = false, h = s.h, floors = s.floors, name = s.name, doorU = 0, sign = true, signCol = s.signCol })
end
P(Vector3.new(0.2 * S, 8 * S, 0.2 * S), CFrame.new(V(-24, 4, 11)), C3(150, 150, 150), Enum.Material.Metal)
local count = 0
for _, p in ipairs(plots) do
	local blocked = false
	for _, s in ipairs(specials) do
		if math.abs(p.x - s.x) < s.w / 2 + 10 and math.abs(p.z - s.z) < s.d / 2 + 8 then blocked = true end
	end
	if not blocked and count < 46 then
		count += 1
		local hz = p.z + (p.face == 0 and 2 or -2)
		buildHouse(p.x, hz, rand(7, 10), rand(6, 8), p.face, { h = rand(2.8, 3.2) })
		local fx0, fx1 = p.x - 9.5, p.x + 9.5
		local fz0 = p.z - (p.face == 0 and 6 or 9)
		local fz1 = p.z + (p.face == 0 and 9 or 6)
		local front = p.face == 0 and fz0 or fz1
		local back = p.face == 0 and fz1 or fz0
		if rnd:NextNumber() < 0.85 then
			fenceLine(fx0, front, fx1, front, { p.x + rand(-3, 3), front })
			fenceLine(fx0, back, fx1, back); fenceLine(fx0, fz0, fx0, fz1); fenceLine(fx1, fz0, fx1, fz1)
		end
		if rnd:NextNumber() < 0.75 then
			local sx = p.x + (rnd:NextNumber() < 0.5 and -6.5 or 6.5)
			local sz = back + (p.face == 0 and -2.2 or 2.2)
			local garage = rnd:NextNumber() < 0.4
			local sw, sd, sh = garage and 3.4 or 2.4, garage and 5 or 2.4, garage and 2.6 or 2.2
			B(sx - sw / 2, 0, sz - sd / 2, sx + sw / 2, sh, sz + sd / 2, garage and C3(150, 72, 52) or C3(105, 78, 52), garage and Enum.Material.Brick or Enum.Material.WoodPlanks):SetAttribute("Cover", true)
			B(sx - sw / 2 - 0.2, sh, sz - sd / 2 - 0.2, sx + sw / 2 + 0.2, sh + 0.15, sz + sd / 2 + 0.2, C3(120, 125, 130), Enum.Material.CorrodedMetal)
		end
	end
end

-- trees
local function tree(x, z, s)
	local tr = P(Vector3.new(4 * s * S, 0.45 * s * S, 0.45 * s * S), CFrame.new(V(x, 2 * s, z)) * CFrame.Angles(0, 0, math.pi / 2), C3(80, 62, 45), Enum.Material.Wood)
	tr.Shape = Enum.PartType.Cylinder
	local g = C3(55 + rnd:NextInteger(0, 20), 95 + rnd:NextInteger(0, 30), 40)
	local l1 = P(Vector3.new(5.2 * s * S, 5.2 * s * S, 5.2 * s * S), CFrame.new(V(x, 4.8 * s, z)), g, M_LEAF); l1.Shape = Enum.PartType.Ball
	local l2 = P(Vector3.new(3.6 * s * S, 3.6 * s * S, 3.6 * s * S), CFrame.new(V(x + rand(-1, 1) * s, 6.4 * s, z + rand(-1, 1) * s)), g, M_LEAF); l2.Shape = Enum.PartType.Ball
	l1.CastShadow = true
end
for _, zl in ipairs({ -85, 85, -175, 175 }) do
	local x = -230
	while x < 230 do tree(x, zl + rand(-3, 3), rand(0.8, 1.3)); x += rand(5, 9) end
end
for _, xl in ipairs({ -205, 205 }) do
	local z = -80
	while z < 80 do if math.abs(z) > 12 then tree(xl + rand(-2, 2), z, rand(0.8, 1.2)) end; z += rand(6, 9) end
end
for _, p in ipairs(plots) do if rnd:NextNumber() < 0.5 then tree(p.x + rand(-8, 8), p.z + (p.face == 0 and 7 or -7), rand(0.7, 1.1)) end end
for _ = 1, 160 do
	local x, z = rand(-220, 220), rand(-200, 200)
	if math.abs(z) > 7 and math.abs(x) > 6 then
		local s = rand(0.5, 1.1)
		local b = P(Vector3.new(2.4 * s * S, 1.8 * s * S, 2.4 * s * S), CFrame.new(V(x, 0.5 * s, z)), C3(70, 100, 45), M_LEAF)
		b.Shape = Enum.PartType.Ball; b.CanCollide = false
	end
end

-- sandbags / trenches
local function sandbags(x0, z0, x1, z1)
	local len = math.sqrt((x1 - x0) ^ 2 + (z1 - z0) ^ 2)
	local p = P(Vector3.new(len * S, 1.1 * S, 0.9 * S), CFrame.new(V((x0 + x1) / 2, 0.55, (z0 + z1) / 2)) * CFrame.Angles(0, -math.atan2(z1 - z0, x1 - x0), 0), C3(150, 135, 95), Enum.Material.Fabric)
	p:SetAttribute("Cover", true); markDestr(p, 250, "fence")
	local tr = P(Vector3.new(len * S, 0.1, 1.8 * S), p.CFrame * CFrame.new(0, -0.55 * S + 0.1, 0), C3(95, 78, 55), M_MUD); tr.CanCollide = false
end
local function trench(cx, cz, dir)
	for i = 0, 5 do
		local z = cz - 26 + i * 9
		if math.abs(z + 2.5) >= 9 then
			local x = cx + ((i % 2 == 1) and 2 or -2) * dir
			sandbags(x, z, x + ((i % 2 == 1) and -2 or 2) * dir, z + 5)
		end
	end
end
trench(-100, 0, 1); trench(100, 0, -1); trench(-165, 0, 1); trench(165, 0, -1)
sandbags(-8, 6, -3, 6); sandbags(3, -6, 8, -6); sandbags(-80, -5, -80, -10); sandbags(80, 5, 80, 10); sandbags(-70, 9, -66, 9); sandbags(70, -9, 66, -9)

-- abandoned cars
local carCols = { C3(122, 42, 42), C3(42, 74, 122), C3(176, 176, 168), C3(58, 90, 58), C3(160, 138, 80) }
local function makeCar(x, z, yaw, burnt)
	local m = Instance.new("Model"); m.Name = "Wreck"; m.Parent = World
	local c = burnt and C3(40, 36, 33) or pick(carCols)
	local cf = CFrame.new(V(x, 0, z)) * CFrame.Angles(0, yaw, 0)
	local body = P(V(1.8, 0.75, 4.2), cf * CFrame.new(0, 0.6 * S, 0), c, Enum.Material.Metal, m); body:SetAttribute("Cover", true)
	P(V(1.6, 0.6, 2.1), cf * CFrame.new(0, 1.25 * S, -0.2 * S), c, Enum.Material.Metal, m)
	local gl = P(V(1.62, 0.45, 2.0), cf * CFrame.new(0, 1.25 * S, -0.2 * S), burnt and C3(15, 15, 15) or C3(140, 170, 190), burnt and Enum.Material.SmoothPlastic or Enum.Material.Glass, m)
	for _, wz in ipairs({ { -0.85, 1.3 }, { 0.85, 1.3 }, { -0.85, -1.3 }, { 0.85, -1.3 } }) do
		local w = P(V(0.25, 0.66, 0.66), cf * CFrame.new(wz[1] * S, 0.33 * S, wz[2] * S), C3(25, 25, 25), Enum.Material.Rubber, m)
		w.Shape = Enum.PartType.Cylinder
	end
	return m
end
for _, w in ipairs({ { -118, 4, 0 }, { -52, -4, 0.1 }, { 38, 3.8, 3.1 }, { 95, -4, 0.3 }, { 0, -35, 1.6 }, { 3, 62, 1.5 }, { -90, -58, 0 }, { 110, 52, 3.1 }, { -40, 57, 0.2 }, { 150, -3, 0.05 }, { -150, 3, 3.1 } }) do
	makeCar(w[1], w[2], w[3] + math.pi / 2, rnd:NextNumber() < 0.5)
end

-- bases
local BASE = { [0] = Vector3.new(-190, 0, 0) * S, [1] = Vector3.new(190, 0, 0) * S }
for t = 0, 1 do
	local bx = t == 0 and -190 or 190
	local sg = t == 0 and 1 or -1
	local sp = Instance.new("SpawnLocation")
	sp.Size = V(6, 0.2, 6); sp.CFrame = CFrame.new(V(bx + 6 * sg, 0.1, 12)); sp.Anchored = true; sp.Neutral = false
	sp.TeamColor = TEAM[t].TeamColor; sp.AllowTeamChangeOnTouch = false; sp.Duration = 3; sp.Color = TEAMCOL[t]; sp.Material = Enum.Material.SmoothPlastic; sp.Parent = World
	local camo = t == 0 and C3(75, 90, 52) or C3(139, 122, 82)
	for _, o in ipairs({ { -8, 14 }, { -8, -14 }, { 6, 18 } }) do
		local tx = bx + o[1] * sg
		local tent = Instance.new("WedgePart"); tent.Anchored = true; tent.Size = V(6, 2.8, 3); tent.Color = camo; tent.Material = Enum.Material.Fabric
		tent.CFrame = CFrame.new(V(tx, 1.4, o[2] - 1.5)); tent.Parent = World
		local tent2 = tent:Clone(); tent2.CFrame = CFrame.new(V(tx, 1.4, o[2] + 1.5)) * CFrame.Angles(0, math.pi, 0); tent2.Parent = World
	end
	for _ = 1, 6 do
		local x, z = bx - sg * rand(-4, 12), rand(-22, 22)
		if math.abs(z) > 6 then B(x - 0.6, 0, z - 0.4, x + 0.6, 0.8, z + 0.4, camo, Enum.Material.Wood):SetAttribute("Cover", true) end
	end
	P(V(0.15, 9, 0.15), CFrame.new(V(bx, 4.5, -6)), C3(150, 150, 150), Enum.Material.Metal)
	local fl = P(V(2.4, 1.4, 0.05), CFrame.new(V(bx + 1.2, 8.2, -6)), TEAMCOL[t], Enum.Material.Fabric); fl.CanCollide = false
	local zone = P(V(44, 0.05, 50), CFrame.new(V(bx + 4 * sg, 0.07, 0)), TEAMCOL[t], Enum.Material.SmoothPlastic); zone.Transparency = 0.85; zone.CanCollide = false; zone.Name = "BaseZone" .. t
end

-- capture points
local points = {
	{ name = "A", pos = V(-75, 0, 0), r = 14 * S, prog = 0, owner = -1 },
	{ name = "B", pos = V(0, 0, 0), r = 14 * S, prog = 0, owner = -1 },
	{ name = "C", pos = V(75, 0, 0), r = 14 * S, prog = 0, owner = -1 },
}
for _, p in ipairs(points) do
	local ring = P(Vector3.new(0.1, p.r * 2, p.r * 2), CFrame.new(p.pos + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.pi / 2), C3(255, 255, 255), Enum.Material.SmoothPlastic)
	ring.Shape = Enum.PartType.Cylinder; ring.Transparency = 0.85; ring.CanCollide = false; ring.CanQuery = false
	p.ring = ring
	P(V(0.15, 7, 0.15), CFrame.new(p.pos + V(5, 3.5, 5)), C3(150, 150, 150), Enum.Material.Metal)
	local fl = P(V(2, 1.2, 0.05), CFrame.new(p.pos + V(6, 6, 5)), C3(255, 255, 255), Enum.Material.Fabric); fl.CanCollide = false
	p.flag = fl
	local bb = Instance.new("BillboardGui"); bb.Size = UDim2.fromOffset(40, 40); bb.AlwaysOnTop = true; bb.StudsOffset = Vector3.new(0, 6, 0); bb.MaxDistance = 600; bb.Parent = fl
	local tl = Instance.new("TextLabel"); tl.Size = UDim2.fromScale(1, 1); tl.BackgroundTransparency = 1; tl.Text = p.name; tl.TextScaled = true; tl.Font = Enum.Font.GothamBlack; tl.TextColor3 = C3(255, 255, 255); tl.TextStrokeTransparency = 0.3; tl.Parent = bb
	RS:SetAttribute("P" .. p.name, 0)
end

-- ===== EFFECTS / COMBAT CORE =====
local function fx(kind, ...) Net:FireAllClients("fx", kind, ...) end
local function feed(txt, col) Net:FireAllClients("feed", txt, col) end
local game_over = false

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function teamOfModel(m)
	if not m then return nil end
	local t = m:GetAttribute("Team")
	if t ~= nil then return t end
	local pl = Players:GetPlayerFromCharacter(m)
	if pl then return pl.Team == TEAM[1] and 1 or 0 end
	return nil
end
local function entityModel(inst)
	local m = inst
	while m and m ~= workspace do
		if m:IsA("Model") and (m:FindFirstChildOfClass("Humanoid") or m:GetAttribute("VHP") or m:GetAttribute("DHP")) then return m end
		m = m.Parent
	end
	return nil
end

local damageVehicle, damageDrone, explode -- forward
local killCredit = {}

local function breakPart(p, impulseFrom, power)
	if not p or not p.Parent or p:GetAttribute("Broken") then return end
	p:SetAttribute("Broken", true)
	p.Anchored = false
	p.CanQuery = false
	if impulseFrom then
		local dir = (p.Position - impulseFrom)
		if dir.Magnitude < 0.01 then dir = Vector3.new(0, 1, 0) end
		p.AssemblyLinearVelocity = dir.Unit * (power or 40) + Vector3.new(0, 25, 0)
		p.AssemblyAngularVelocity = Vector3.new(rand(-5, 5), rand(-5, 5), rand(-5, 5))
	end
	fx("dust", p.Position)
	Debris:AddItem(p, 20)
end
local function hitWorldPart(p, pos, dmg)
	local kind = p:GetAttribute("Kind")
	if kind == "glass" then
		fx("glass", p.Position)
		p:Destroy()
	elseif kind == "fence" then
		local hp = (p:GetAttribute("HP") or 30) - dmg * 0.2
		p:SetAttribute("HP", hp)
		if hp <= 0 then breakPart(p, pos, 15) end
	end
end

local function damageHumanoid(m, dmg, attTeam, attName, attPlayer, head)
	local hum = m:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then return false end
	local t = teamOfModel(m)
	if attTeam ~= nil and t == attTeam then return false end
	killCredit[m] = { team = attTeam, name = attName, player = attPlayer }
	hum:TakeDamage(dmg * (head and 2.5 or 1))
	return hum.Health <= 0
end

-- generic hit application
local function applyHit(res, origin, dmg, attTeam, attName, attPlayer)
	if not res then return end
	local inst = res.Instance
	local em = entityModel(inst)
	if em then
		if em:FindFirstChildOfClass("Humanoid") then
			local head = inst.Name == "Head"
			local killed = damageHumanoid(em, dmg, attTeam, attName, attPlayer, head)
			fx("blood", res.Position)
			if attPlayer then Net:FireClient(attPlayer, "hit", killed) end
		elseif em:GetAttribute("VHP") then
			damageVehicle(em, dmg, false, attTeam, attName, attPlayer)
			fx("spark", res.Position)
			if attPlayer then Net:FireClient(attPlayer, "hit", false) end
		elseif em:GetAttribute("DHP") then
			damageDrone(em, dmg, attTeam)
			fx("spark", res.Position)
			if attPlayer then Net:FireClient(attPlayer, "hit", false) end
		end
	else
		fx("impact", res.Position, res.Normal)
		hitWorldPart(inst, origin, dmg)
	end
end

local function shoot(origin, dir, range, dmg, attTeam, attName, attPlayer, exclude, blast)
	rayParams.FilterDescendantsInstances = { FX, exclude }
	local res = workspace:Raycast(origin, dir.Unit * range, rayParams)
	local hitPos = res and res.Position or (origin + dir.Unit * range)
	Net:FireAllClients("tr", origin, hitPos, attPlayer)
	applyHit(res, origin, dmg, attTeam, attName, attPlayer)
	if blast and res then explode(res.Position, 2.5 * S, 30, attTeam, attName, attPlayer, true) end
	return res
end

-- ===== ENTITIES =====
local bots = {}
local vehicles = {}
local aiDrones = {}
local marks = { [0] = {}, [1] = {} }

local function combatants()
	local list = {}
	for _, b in ipairs(bots) do
		if b.alive and b.root and b.root.Parent then table.insert(list, { model = b.model, root = b.root, team = b.team, kind = "sol" }) end
	end
	for _, pl in ipairs(Players:GetPlayers()) do
		local ch = pl.Character
		local hum = ch and ch:FindFirstChildOfClass("Humanoid")
		local root = ch and ch:FindFirstChild("HumanoidRootPart")
		if hum and root and hum.Health > 0 then table.insert(list, { model = ch, root = root, team = pl.Team == TEAM[1] and 1 or 0, kind = "sol", player = pl }) end
	end
	for _, v in ipairs(vehicles) do
		if v.alive then table.insert(list, { model = v.model, root = v.hull, team = v.team, kind = "veh" }) end
	end
	for _, d in ipairs(DroneF:GetChildren()) do
		local body = d:FindFirstChild("Body")
		if body and d:GetAttribute("DHP") and d:GetAttribute("DHP") > 0 then table.insert(list, { model = d, root = body, team = d:GetAttribute("Team"), kind = "drone" }) end
	end
	return list
end
local COMB = {}

local function los(fromPos, ent, exclude)
	rayParams.FilterDescendantsInstances = { FX, exclude }
	local target = ent.root.Position + (ent.kind == "sol" and Vector3.new(0, 1.2, 0) or Vector3.new(0, 1, 0))
	local res = workspace:Raycast(fromPos, target - fromPos, rayParams)
	if not res then return true end
	return ent.model:IsAncestorOf(res.Instance) or res.Instance:GetAttribute("Kind") == "glass"
end

-- ===== EXPLOSION =====
explode = function(pos, radius, dmg, attTeam, attName, attPlayer, small)
	local e = Instance.new("Explosion")
	e.Position = pos; e.BlastRadius = radius; e.BlastPressure = 0; e.DestroyJointRadiusPercent = 0
	e.ExplosionType = Enum.ExplosionType.NoCraters
	e.Visible = not small
	e.Parent = workspace
	fx(small and "smallboom" or "boom", pos)
	local hitModels = {}
	local op = OverlapParams.new(); op.FilterType = Enum.RaycastFilterType.Exclude; op.FilterDescendantsInstances = { FX, ground }
	for _, part in ipairs(workspace:GetPartBoundsInRadius(pos, radius * 1.4, op)) do
		local em = entityModel(part)
		if em then
			if not hitModels[em] then
				hitModels[em] = true
				local cp = em:GetPivot().Position
				local d = (cp - pos).Magnitude
				local k = math.clamp(1 - d / (radius * 1.2), 0, 1)
				if k > 0 then
					if em:FindFirstChildOfClass("Humanoid") then damageHumanoid(em, dmg * k * 1.1, attTeam, attName, attPlayer, false)
					elseif em:GetAttribute("VHP") then damageVehicle(em, dmg * math.max(k, 0.35) * 2.2, true, attTeam, attName, attPlayer)
					elseif em:GetAttribute("DHP") then damageDrone(em, dmg, attTeam) end
				end
			end
		elseif not small then
			local kind = part:GetAttribute("Kind")
			local d = (part.Position - pos).Magnitude
			if kind == "glass" then
				fx("glass", part.Position); part:Destroy()
			elseif kind == "fence" and d < radius then
				breakPart(part, pos, 50)
			elseif kind == "wall" and part.Anchored then
				local lp = part.CFrame:PointToObjectSpace(pos); local hs = part.Size / 2
				local cp = part.CFrame:PointToWorldSpace(Vector3.new(math.clamp(lp.X, -hs.X, hs.X), math.clamp(lp.Y, -hs.Y, hs.Y), math.clamp(lp.Z, -hs.Z, hs.Z)))
				local dd = (cp - pos).Magnitude
				if dd < radius * 0.8 then
					local hp = (part:GetAttribute("HP") or 100) - dmg * (1 - dd / radius)
					part:SetAttribute("HP", hp)
					if hp <= 0 then breakPart(part, pos, 45) else part.Color = part.Color:Lerp(Color3.new(0.15, 0.13, 0.12), 0.35) end
				end
			end
		end
	end
	if attPlayer and next(hitModels) then Net:FireClient(attPlayer, "hit", false) end
end

-- ===== BOTS =====
local ANIM = { walk = "rbxassetid://507777826", run = "rbxassetid://507767714", idle = "rbxassetid://507766388" }
local squads = {}
local function newSquad(team, idx) local sq = { team = team, members = {}, leader = nil, goal = nil, idx = idx or #squads }; table.insert(squads, sq); return sq end

local function chooseObjective(team, sq)
	local mode = RS:GetAttribute("Mode")
	if mode == "sandbox" then
		local best, bd = nil, 1e9
		local from = (sq and sq.leader and sq.leader.root) and sq.leader.root.Position or BASE[team]
		for _, e in ipairs(COMB) do
			if e.team ~= team and e.kind ~= "drone" then
				local d = (e.root.Position - from).Magnitude
				if d < bd then bd = d; best = e end
			end
		end
		if best then return best.root.Position + Vector3.new(rand(-30, 30), 0, rand(-30, 30)) end
		return points[2].pos
	end
	if mode == "defense" and team == 0 then
		local p = points[((sq and sq.idx or rnd:NextInteger(0, 2)) % 3) + 1]
		return p.pos + V(rand(-12, 12), 0, rand(-10, 10))
	end
	local order = team == 0 and { 1, 2, 3 } or { 3, 2, 1 }
	for _, i in ipairs(order) do
		local p = points[i]
		if p.owner ~= team or math.abs(p.prog) < 0.99 then return p.pos + V(rand(-10, 10), 0, rand(-9, 9)) end
	end
	local p = points[order[3]]
	return p.pos + V(rand(-25, 25) * (team == 1 and 1 or -1), 0, rand(-15, 15))
end

local function addWeld(a, b)
	local w = Instance.new("WeldConstraint"); w.Part0 = a; w.Part1 = b; w.Parent = a
end

local function makeBot(team, pos, opt)
	opt = opt or {}
	local desc = Instance.new("HumanoidDescription")
	local uni = team == 0 and C3(72, 88, 55) or C3(142, 122, 84)
	local skin = C3(200, 160, 130)
	desc.HeadColor = skin; desc.TorsoColor = uni; desc.LeftArmColor = uni; desc.RightArmColor = uni; desc.LeftLegColor = uni; desc.RightLegColor = uni
	local ok, model = pcall(function() return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15) end)
	if not ok or not model then return nil end
	model.Name = team == 0 and "Северный" or "Южный"
	model:SetAttribute("Team", team)
	local hum = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	local head = model:FindFirstChild("Head")
	local rh = model:FindFirstChild("RightHand")
	local ut = model:FindFirstChild("UpperTorso")
	local la = model:FindFirstChild("RightUpperArm")
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.WalkSpeed = 13
	hum.MaxHealth = 100; hum.Health = 100
	hum.BreakJointsOnDeath = false
	local an = model:FindFirstChild("Animate"); if an then an:Destroy() end
	-- gear
	local helm = Instance.new("Part"); helm.Shape = Enum.PartType.Ball; helm.Size = Vector3.new(1.45, 1.45, 1.45); helm.Color = team == 0 and C3(60, 74, 44) or C3(122, 106, 72); helm.Material = Enum.Material.SmoothPlastic; helm.CanCollide = false; helm.Massless = true
	helm.CFrame = head.CFrame * CFrame.new(0, 0.25, 0); helm.Parent = model; addWeld(helm, head)
	if ut then
		local vest = Instance.new("Part"); vest.Size = ut.Size * Vector3.new(1.1, 0.8, 1.25); vest.Color = team == 0 and C3(57, 67, 42) or C3(106, 92, 60); vest.Material = Enum.Material.Fabric; vest.CanCollide = false; vest.Massless = true
		vest.CFrame = ut.CFrame; vest.Parent = model; addWeld(vest, ut)
	end
	if la then
		local band = Instance.new("Part"); band.Size = la.Size * Vector3.new(1.15, 0.3, 1.15); band.Color = TEAMCOL[team]; band.Material = Enum.Material.Neon; band.CanCollide = false; band.Massless = true
		band.CFrame = la.CFrame; band.Parent = model; addWeld(band, la)
	end
	local mg = rnd:NextNumber() < 0.15
	local gun = Instance.new("Part"); gun.Name = "Gun"; gun.Size = Vector3.new(0.25, 0.4, mg and 3.4 or 2.8); gun.Color = C3(30, 30, 30); gun.Material = Enum.Material.Metal; gun.CanCollide = false; gun.Massless = true
	gun.CFrame = rh.CFrame * CFrame.new(0, -0.2, -0.8); gun.Parent = model; addWeld(gun, rh)
	model.Parent = BotsM
	model:PivotTo(CFrame.new(pos + Vector3.new(0, 3, 0)) * CFrame.Angles(0, team == 0 and -math.pi / 2 or math.pi / 2, 0))
	pcall(function() root:SetNetworkOwner(nil) end)
	local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)
	local tracks = {}
	for k, id in pairs(ANIM) do
		local a = Instance.new("Animation"); a.AnimationId = id
		local ok2, tr = pcall(function() return animator:LoadAnimation(a) end)
		if ok2 then tracks[k] = tr end
	end
	local b = { model = model, hum = hum, root = root, head = head, gun = gun, team = team, alive = true, mg = mg, mag = mg and 100 or 30, magSize = mg and 100 or 30,
		nextThink = 0, nextShot = 0, burst = 0, target = nil, aim = 0, reload = 0, squad = opt.squad, garrison = opt.garrison, retreat = false, tracks = tracks, anim = nil,
		lastPos = root.Position, stuckT = 0, cover = false, coverT = 0, frozen = opt.frozen }
	if b.squad then table.insert(b.squad.members, b) end
	hum.Died:Connect(function()
		if not b.alive then return end
		b.alive = false
		local c = killCredit[model]
		local tk = "T" .. team
		RS:SetAttribute(tk, math.max(0, (RS:GetAttribute(tk) or 0) - 1))
		if c then
			feed((c.player and ("<b>" .. c.player.Name .. "</b>") or (c.team == 0 and "Северные" or "Южные")) .. " ✖ " .. model.Name, c.team == 0 and "#88bbff" or "#ff8888")
			if c.player then c.player:SetAttribute("Kills", (c.player:GetAttribute("Kills") or 0) + 1) end
		end
		for _, tr in pairs(tracks) do pcall(function() tr:Stop() end) end
		-- ragdoll-ish fall
		root.Anchored = false
		local bv = root.CFrame.LookVector
		root.AssemblyAngularVelocity = Vector3.new(rand(-3, 3), 0, rand(-3, 3))
		root.CFrame = root.CFrame * CFrame.Angles(math.pi / 2 * (rnd:NextNumber() < 0.5 and 1 or -1), 0, 0)
		task.delay(12, function() if model then model:Destroy() end end)
	end)
	table.insert(bots, b)
	return b
end

local function playAnim(b, name)
	if b.anim == name then return end
	if b.anim and b.tracks[b.anim] then b.tracks[b.anim]:Stop(0.2) end
	b.anim = name
	if b.tracks[name] then b.tracks[name]:Play(0.2) end
end

local function findCover(pos, enemyPos)
	local op = OverlapParams.new(); op.FilterType = Enum.RaycastFilterType.Include; op.FilterDescendantsInstances = { World }
	local best, bs = nil, 1e9
	for _, p in ipairs(workspace:GetPartBoundsInRadius(pos, 14 * S, op)) do
		if p.Anchored and (p:GetAttribute("Cover") or (p:GetAttribute("Kind") == "wall" and p.Position.Y < 3 * S)) and p.Size.Y > 2.5 then
			local dir = (p.Position - enemyPos) * Vector3.new(1, 0, 1)
			if dir.Magnitude > 0.1 then
				dir = dir.Unit
				local half = math.max(p.Size.X, p.Size.Z) / 2
				local c = p.Position + dir * (math.min(half, 6) + 2.5)
				c = Vector3.new(c.X, 0, c.Z)
				local d = (c - pos).Magnitude
				if d < bs then bs = d; best = c end
			end
		end
	end
	return best
end

local function botShoot(b, ent)
	local origin = b.gun.Position + b.gun.CFrame.LookVector * 1.5
	local tp = ent.root.Position + (ent.kind == "sol" and Vector3.new(0, 0.8, 0) or Vector3.new(0, 1, 0))
	local spread = (b.mg and 0.05 or 0.035) + (ent.kind == "drone" and 0.03 or 0) + (b.hum.MoveDirection.Magnitude > 0.1 and 0.03 or 0)
	local dir = (tp - origin).Unit + Vector3.new(rand(-spread, spread), rand(-spread, spread) * 0.7, rand(-spread, spread))
	shoot(origin, dir, 420, b.mg and 20 or 17, b.team, nil, nil, b.model)
end

local function botThink(b, now)
	local root = b.root
	local pos = root.Position
	local eye = b.head.Position
	-- target
	local cands = {}
	for _, e in ipairs(COMB) do
		if e.team ~= b.team and e.model ~= b.model then
			local d = (e.root.Position - pos).Magnitude
			local range = e.kind == "drone" and 50 * S or (b.garrison and 110 * S or 95 * S)
			if d < range then
				local w = d
				if e.kind == "drone" then w = d * 0.4 elseif e.kind == "veh" then w = d * 1.3 end
				table.insert(cands, { e = e, w = w, d = d })
			end
		end
	end
	table.sort(cands, function(a, c) return a.w < c.w end)
	local best = nil
	for i = 1, math.min(4, #cands) do
		if los(eye, cands[i].e, b.model) then best = cands[i]; break end
	end
	local newT = best and best.e or nil
	if (newT and newT.model) ~= (b.target and b.target.model) then b.aim = 0; b.cover = false end
	b.target = newT
	-- drone dodge
	if best and best.e.kind == "drone" and best.d < 18 * S and rnd:NextNumber() < 0.5 then
		local a = rand(0, 6.28)
		b.hum:MoveTo(pos + Vector3.new(math.cos(a), 0, math.sin(a)) * 8 * S)
		return
	end
	if b.hum.Health < 35 and not b.retreat and not b.garrison and rnd:NextNumber() < 0.5 then b.retreat = true end
	if b.retreat then
		b.hum:MoveTo(BASE[b.team] + V(rand(-8, 8), 0, rand(-15, 15)))
		if (pos - BASE[b.team]).Magnitude < 25 * S then
			b.hum.Health = math.min(100, b.hum.Health + 8)
			if b.hum.Health > 95 then b.retreat = false end
		end
		return
	end
	if best then
		if b.garrison then b.hum:MoveTo(pos); return end
		if not b.cover then
			local c = findCover(pos, best.e.root.Position)
			if c then b.hum:MoveTo(c) else b.hum:MoveTo(pos) end
			b.cover = true
		end
		b.coverT += 0.4
		if b.coverT > rand(8, 16) and best.d > 30 * S then
			b.coverT = 0; b.cover = false
			b.hum:MoveTo(pos:Lerp(best.e.root.Position, 0.3))
		end
		return
	end
	b.cover = false; b.coverT = 0
	if b.garrison then b.hum:MoveTo(b.garrison); return end
	-- marked targets
	local mk, md = nil, 150 * S
	for m, exp in pairs(marks[b.team]) do
		if exp > now and m.Parent then
			local d = (m:GetPivot().Position - pos).Magnitude
			if d < md then md = d; mk = m end
		end
	end
	if mk and rnd:NextNumber() < 0.7 then b.hum:MoveTo(mk:GetPivot().Position + V(rand(-6, 6), 0, rand(-6, 6))); return end
	local sq = b.squad
	if sq then
		if not sq.leader or not sq.leader.alive then sq.leader = b end
		if sq.leader == b then
			if not sq.goal or (Vector3.new(pos.X, 0, pos.Z) - sq.goal).Magnitude < 6 * S or rnd:NextNumber() < 0.04 then sq.goal = chooseObjective(b.team, sq) end
			b.hum:MoveTo(sq.goal)
		else
			local l = sq.leader
			local idx = table.find(sq.members, b) or 1
			b.hum:MoveTo(l.root.Position + Vector3.new(math.cos(idx * 2.1) * 3 * S, 0, math.sin(idx * 2.1) * 3 * S))
		end
	else
		if not b.goal or (pos - b.goal).Magnitude < 3 * S then b.goal = chooseObjective(b.team, nil) end
		b.hum:MoveTo(b.goal)
	end
end

local function botUpdate(b, now, dt)
	if not b.alive or not b.root.Parent then return end
	if b.frozen and not RS:GetAttribute("SB") then return end
	b.frozen = false
	if now >= b.nextThink then b.nextThink = now + rand(0.3, 0.55); botThink(b, now) end
	local tg = b.target
	if tg and tg.root.Parent then
		local tp = tg.root.Position
		local flat = Vector3.new(tp.X, b.root.Position.Y, tp.Z)
		if (flat - b.root.Position).Magnitude > 0.5 then
			b.hum.AutoRotate = false
			b.root.CFrame = CFrame.lookAt(b.root.Position, flat)
		end
		b.aim += dt
		if b.reload > 0 then
			b.reload -= dt
			if b.reload <= 0 then b.mag = b.magSize end
		elseif b.mag <= 0 then
			b.reload = b.mg and 4 or 2.4
		elseif b.aim > 0.6 and now >= b.nextShot then
			botShoot(b, tg)
			b.mag -= 1; b.burst += 1
			if b.burst >= (b.mg and 8 or 3) then b.burst = 0; b.nextShot = now + rand(0.5, 1.2) else b.nextShot = now + (b.mg and 0.09 or 0.13) end
		end
	else
		b.hum.AutoRotate = true
	end
	local moving = b.hum.MoveDirection.Magnitude > 0.1
	playAnim(b, moving and (b.retreat and "run" or "walk") or "idle")
	b.hum.WalkSpeed = b.retreat and 18 or (tg and 9 or 13)
	-- stuck
	b.stuckT += dt
	if b.stuckT > 1.5 then
		b.stuckT = 0
		if moving and (b.root.Position - b.lastPos).Magnitude < 2 then
			b.hum.Jump = true
			local side = b.root.CFrame.RightVector * (rnd:NextNumber() < 0.5 and 1 or -1) * 10
			b.hum:MoveTo(b.root.Position + side)
			b.nextThink = now + 1.2
		end
		b.lastPos = b.root.Position
	end
end

-- ===== VEHICLES =====
local VDEF = {
	btr = { hp = 420, bullet = 0.04, blast = 0.45, speed = 7 * S, w = 2.9, l = 7.4, h = 2.6, gun = { dmg = 40, rate = 0.22, range = 170 * S, spread = 0.025, blast = true }, name = "БТР" },
	jeep = { hp = 140, bullet = 0.3, blast = 1, speed = 10 * S, w = 2.2, l = 4.6, h = 2.1, gun = { dmg = 20, rate = 0.11, range = 140 * S, spread = 0.04 }, name = "Броневик" },
	truck = { hp = 160, bullet = 0.35, blast = 1, speed = 8 * S, w = 2.5, l = 7, h = 3, gun = nil, name = "Грузовик" },
}
local function buildVehicle(kind, team)
	local m = Instance.new("Model"); m.Name = VDEF[kind].name
	local camo = team == 0 and C3(75, 90, 52) or C3(139, 122, 82)
	local function add(sz, cf, col, mat, parent)
		local p = Instance.new("Part"); p.Anchored = true; p.Size = sz * S; p.CFrame = cf; p.Color = col; p.Material = mat or Enum.Material.Metal; p.Parent = parent or m; return p
	end
	local hull, turret
	local function wheel(x, y, z, r)
		local w = add(Vector3.new(0.45, r * 2, r * 2), CFrame.new(x * S, y * S, z * S), C3(25, 25, 25), Enum.Material.Rubber); w.Shape = Enum.PartType.Cylinder
	end
	if kind == "btr" then
		hull = add(Vector3.new(2.8, 1.3, 6.6), CFrame.new(0, 1.35 * S, 0), camo)
		local nose = add(Vector3.new(2.8, 1, 1.6), CFrame.new(0, 1.3 * S, -3.5 * S) * CFrame.Angles(-0.6, 0, 0), camo)
		add(Vector3.new(2.4, 0.5, 5.2), CFrame.new(0, 2.2 * S, 0.3 * S), camo)
		for i = 0, 3 do for _, s in ipairs({ -1, 1 }) do wheel(s * 1.35, 0.55, -2.4 + i * 1.6, 0.55) end end
		turret = Instance.new("Model"); turret.Name = "Turret"; turret.Parent = m
		local tb = add(Vector3.new(1.5, 0.55, 1.6), CFrame.new(0, 2.72 * S, -0.6 * S), camo, nil, turret); tb.Name = "TBase"
		local br = add(Vector3.new(0.14, 0.14, 2.4), CFrame.new(0, 2.8 * S, -1.8 * S - 0.6 * S), C3(30, 30, 30), nil, turret); br.Name = "Barrel"
		turret.PrimaryPart = tb
	elseif kind == "jeep" then
		hull = add(Vector3.new(2.1, 1.0, 4.4), CFrame.new(0, 0.95 * S, 0), camo)
		add(Vector3.new(2.0, 0.9, 2.4), CFrame.new(0, 1.85 * S, 0.4 * S), camo)
		add(Vector3.new(1.8, 0.4, 0.05), CFrame.new(0, 1.95 * S, -0.82 * S), C3(140, 170, 190), Enum.Material.Glass)
		for _, q in ipairs({ { -1.05, 1.4 }, { 1.05, 1.4 }, { -1.05, -1.4 }, { 1.05, -1.4 } }) do wheel(q[1], 0.45, q[2], 0.45) end
		turret = Instance.new("Model"); turret.Name = "Turret"; turret.Parent = m
		local tb = add(Vector3.new(0.6, 0.35, 0.6), CFrame.new(0, 2.45 * S, 0.6 * S), C3(30, 30, 30), nil, turret); tb.Name = "TBase"
		local br = add(Vector3.new(0.08, 0.08, 1.3), CFrame.new(0, 2.55 * S, 0.6 * S - 0.7 * S), C3(30, 30, 30), nil, turret); br.Name = "Barrel"
		turret.PrimaryPart = tb
	else
		hull = add(Vector3.new(2.4, 1.6, 2.2), CFrame.new(0, 1.6 * S, -2.4 * S), camo)
		add(Vector3.new(2.4, 0.4, 4.6), CFrame.new(0, 1.0 * S, 1.0 * S), C3(40, 40, 40))
		add(Vector3.new(2.4, 1.7, 4.4), CFrame.new(0, 2.1 * S, 1.0 * S), team == 0 and C3(62, 74, 44) or C3(106, 92, 60), Enum.Material.Fabric)
		for _, q in ipairs({ { -1.1, -2.4 }, { 1.1, -2.4 }, { -1.1, 0.6 }, { 1.1, 0.6 }, { -1.1, 2.2 }, { 1.1, 2.2 } }) do wheel(q[1], 0.55, q[2], 0.55) end
	end
	hull.Name = "Hull"
	m.PrimaryPart = hull
	return m, hull, turret
end

local function spawnVehicle(kind, team, pos, frozen)
	local m, hull, turret = buildVehicle(kind, team)
	local d = VDEF[kind]
	local yaw = team == 0 and -math.pi / 2 or math.pi / 2
	local base = CFrame.new(pos) * CFrame.Angles(0, yaw, 0)
	-- re-centre model pivot
	local offset = hull.CFrame
	local tOff = turret and turret:GetPivot() or nil
	m:PivotTo(base * offset)
	m:SetAttribute("VHP", d.hp); m:SetAttribute("Team", team)
	m.Parent = VehM
	local v = { model = m, hull = hull, turret = turret, kind = kind, def = d, team = team, hp = d.hp, alive = true, pos = Vector3.new(pos.X, 0, pos.Z), yaw = yaw, tyaw = 0,
		offset = offset, nextThink = 0, nextShot = 0, burst = 0, target = nil, goal = nil, cargo = kind == "truck" and 6 or 0, rev = 0, stuckT = 0, lastPos = pos, frozen = frozen }
	v.tOffset = tOff
	table.insert(vehicles, v)
	return v
end
damageVehicle = function(m, dmg, blast, attTeam, attName, attPlayer)
	for _, v in ipairs(vehicles) do
		if v.model == m and v.alive then
			if attTeam == v.team then return end
			v.hp -= dmg * (blast and v.def.blast or v.def.bullet)
			m:SetAttribute("VHP", math.max(0, v.hp))
			if v.hp < v.def.hp * 0.5 and not v.smoke then v.smoke = Instance.new("Smoke"); v.smoke.Color = C3(40, 40, 40); v.smoke.Opacity = 0.4; v.smoke.RiseVelocity = 8; v.smoke.Parent = v.hull end
			if v.hp < v.def.hp * 0.25 and not v.fire then v.fire = Instance.new("Fire"); v.fire.Size = 8; v.fire.Parent = v.hull end
			if v.hp <= 0 then
				v.alive = false
				for _, p in ipairs(m:GetDescendants()) do if p:IsA("BasePart") then p.Color = C3(40, 36, 33); p.Material = Enum.Material.CorrodedMetal end end
				m:SetAttribute("VHP", nil)
				explode(v.hull.Position + Vector3.new(0, 3, 0), 4 * S, 60, nil, nil, nil, false)
				if not v.fire then v.fire = Instance.new("Fire"); v.fire.Size = 12; v.fire.Parent = v.hull end
				if not v.smoke then v.smoke = Instance.new("Smoke"); v.smoke.Color = C3(30, 30, 30); v.smoke.Parent = v.hull end
				v.smoke.Opacity = 0.6; v.smoke.Size = 6
				local tk = "T" .. v.team
				RS:SetAttribute(tk, math.max(0, (RS:GetAttribute(tk) or 0) - 5))
				feed((attPlayer and ("<b>" .. attPlayer.Name .. "</b> уничтожил ") or "Уничтожен ") .. v.def.name .. (v.team == 0 and " (Северные)" or " (Южные)"), "#ffcc66")
				if v.cargo > 0 then
					for _ = 1, 3 do local b = makeBot(v.team, v.hull.Position + V(rand(-3, 3), 0, rand(-3, 3))); if b then b.hum:TakeDamage(rand(20, 60)) end end
					v.cargo = 0
				end
				task.delay(30, function() if v.fire then v.fire.Enabled = false end end)
				if RS:GetAttribute("Mode") ~= "sandbox" then
					task.delay(45, function() if not game_over then spawnVehicle(pick({ "btr", "jeep", "jeep", "truck" }), v.team, BASE[v.team] + V(v.team == 0 and 10 or -10, 0, rand(-3, 3))) end end)
				end
			end
			return
		end
	end
end

local function vehThink(v)
	local pos = v.hull.Position
	local eye = pos + Vector3.new(0, 3 * S, 0)
	local best, bd = nil, 1e9
	if v.def.gun then
		for _, e in ipairs(COMB) do
			if e.team ~= v.team then
				local d = (e.root.Position - pos).Magnitude
				local w = d * (e.kind == "veh" and 0.7 or e.kind == "drone" and 0.5 or 1)
				if d < v.def.gun.range and w < bd and los(eye, e, v.model) then best = e; bd = w end
			end
		end
	end
	v.target = best
	if not v.goal or (v.pos - v.goal).Magnitude < 6 * S or rnd:NextNumber() < 0.03 then
		if v.kind == "truck" and v.cargo <= 0 then v.goal = BASE[v.team]; return end
		local o = chooseObjective(v.team, nil)
		if RS:GetAttribute("Mode") ~= "sandbox" then o = Vector3.new(o.X, 0, math.clamp(o.Z, -3 * S, 3 * S)) end
		local toward = v.team == 0 and -1 or 1
		if v.kind == "truck" then o += Vector3.new(toward * 35 * S, 0, 0) elseif v.kind == "btr" then o += Vector3.new(toward * 18 * S, 0, 0) end
		v.goal = Vector3.new(o.X, 0, o.Z)
	end
end

local function vehUpdate(v, now, dt)
	if not v.alive then return end
	if v.frozen and not RS:GetAttribute("SB") then return end
	v.frozen = false
	if now >= v.nextThink then v.nextThink = now + 0.5; vehThink(v) end
	local spd = 0
	if v.goal then
		local dx, dz = v.goal.X - v.pos.X, v.goal.Z - v.pos.Z
		local d = math.sqrt(dx * dx + dz * dz)
		local engaged = v.target and v.kind == "btr" and (v.target.root.Position - v.pos).Magnitude < 90 * S
		if d > 4 * S and not engaged then
			local ty = math.atan2(-dx, -dz)
			local dy = (ty - v.yaw + math.pi) % (2 * math.pi) - math.pi
			if v.rev > 0 then v.rev -= dt; spd = -3 * S; v.yaw += 0.8 * dt * (dy >= 0 and 1 or -1)
			else v.yaw += math.clamp(dy, -1, 1) * dt * 0.9; spd = v.def.speed * (math.abs(dy) > 1 and 0.4 or 1) * math.min(1, d / (15 * S) + 0.3) end
		elseif v.kind == "truck" and v.cargo > 0 and d <= 6 * S then
			local sq = newSquad(v.team)
			for _ = 1, v.cargo do makeBot(v.team, v.pos + V(rand(-3, 3), 0, rand(3, 5) * (rnd:NextNumber() < 0.5 and 1 or -1)), { squad = sq }) end
			v.cargo = 0; v.goal = BASE[v.team]
		end
	end
	local fwd = Vector3.new(-math.sin(v.yaw), 0, -math.cos(v.yaw))
	local newPos = v.pos + fwd * spd * dt
	-- obstacle check
	if spd ~= 0 then
		rayParams.FilterDescendantsInstances = { FX, v.model, BotsM, ground }
		local res = workspace:Raycast(v.pos + Vector3.new(0, 1.2 * S, 0), fwd * (spd > 0 and 1 or -1) * (v.def.l / 2 * S + 1.5), rayParams)
		if res then
			local k = res.Instance:GetAttribute("Kind")
			if k == "fence" or k == "glass" then breakPart(res.Instance, v.pos, 30)
			elseif res.Instance:IsDescendantOf(DroneF) then
			else newPos = v.pos end
		end
	end
	v.pos = newPos
	v.stuckT += dt
	if v.stuckT > 2 then
		v.stuckT = 0
		if spd > 1 and (v.pos - v.lastPos).Magnitude < 1.5 * S then v.rev = 1.5 end
		v.lastPos = v.pos
	end
	local cf = CFrame.new(v.pos) * CFrame.Angles(0, v.yaw, 0)
	v.model:PivotTo(cf * v.offset)
	-- turret
	if v.turret then
		local tg = v.target
		local tcf = cf * v.tOffset
		if tg and tg.root.Parent then
			local tp = tg.root.Position
			local lp = tcf:PointToObjectSpace(tp)
			local want = math.atan2(-lp.X, -lp.Z)
			local dy = (want - v.tyaw + math.pi) % (2 * math.pi) - math.pi
			v.tyaw += math.clamp(dy, -2 * dt, 2 * dt)
			v.turret:PivotTo(tcf * CFrame.Angles(0, v.tyaw, 0))
			if math.abs(dy) < 0.1 and now >= v.nextShot then
				local g = v.def.gun
				local barrel = v.turret:FindFirstChild("Barrel")
				local o = barrel.Position + barrel.CFrame.LookVector * barrel.Size.Z / 2
				local dir = (tp - o).Unit + Vector3.new(rand(-g.spread, g.spread), rand(-g.spread, g.spread) * 0.5, rand(-g.spread, g.spread))
				shoot(o, dir, g.range, g.dmg, v.team, nil, nil, v.model, g.blast)
				v.burst += 1
				if v.burst >= (g.blast and 4 or 10) then v.burst = 0; v.nextShot = now + rand(1, 2) else v.nextShot = now + g.rate end
			end
		else
			v.turret:PivotTo(tcf * CFrame.Angles(0, v.tyaw, 0))
		end
	end
	-- push soldiers away
	for _, b in ipairs(bots) do
		if b.alive then
			local d = b.root.Position - v.pos
			d = Vector3.new(d.X, 0, d.Z)
			if d.Magnitude < v.def.w * S * 0.8 and d.Magnitude > 0.01 then b.root.CFrame = b.root.CFrame + d.Unit * 2 end
		end
	end
end

-- ===== DRONES =====
local DDEF = {
	fpv = { hp = 4, size = 1 },
	scout = { hp = 8, size = 1.3 },
	uav = { hp = 25, size = 1 },
}
local function buildDrone(kind, team)
	local m = Instance.new("Model"); m.Name = kind == "fpv" and "FPV" or kind == "scout" and "Разведчик" or "БПЛА"
	local function part(sz, cf, col, mat, name)
		local p = Instance.new("Part"); p.Size = sz; p.CFrame = cf; p.Color = col; p.Material = mat or Enum.Material.SmoothPlastic; p.CanCollide = false; p.Anchored = false; p.Massless = true; p.CastShadow = true
		p.Name = name or "P"; p.Parent = m; return p
	end
	local body
	if kind == "uav" then
		body = part(Vector3.new(1.4, 1.4, 9), CFrame.new(), C3(205, 208, 200), Enum.Material.SmoothPlastic, "Body")
		part(Vector3.new(15, 0.2, 1.8), CFrame.new(0, 0.3, -0.3), C3(215, 218, 210))
		part(Vector3.new(4.5, 0.15, 1), CFrame.new(0, 0.35, 4.2), C3(215, 218, 210))
		part(Vector3.new(0.15, 1.6, 1), CFrame.new(0, 1, 4.2), C3(215, 218, 210))
		local cam = part(Vector3.new(0.9, 0.9, 0.9), CFrame.new(0, -0.8, -2.5), C3(25, 25, 25)); cam.Shape = Enum.PartType.Ball
		local pr = part(Vector3.new(3, 0.2, 0.2), CFrame.new(0, 0, 4.7), C3(25, 25, 25), nil, "Prop")
	else
		local s = kind == "scout" and 1.3 or 1
		local fm = kind == "scout" and C3(155, 160, 166) or C3(30, 32, 35)
		body = part(Vector3.new(0.5 * s, 0.25, 0.8 * s), CFrame.new(), fm, Enum.Material.Metal, "Body")
		part(Vector3.new(2.2 * s, 0.1, 0.18), CFrame.Angles(0, math.pi / 4, 0), fm, Enum.Material.Metal)
		part(Vector3.new(2.2 * s, 0.1, 0.18), CFrame.Angles(0, -math.pi / 4, 0), fm, Enum.Material.Metal)
		for _, q in ipairs({ { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } }) do
			local pp = part(Vector3.new(0.05, 1.7 * s, 1.7 * s), CFrame.new(q[1] * 0.78 * s, 0.18, q[2] * 0.78 * s) * CFrame.Angles(0, 0, math.pi / 2), kind == "fpv" and C3(140, 25, 25) or C3(50, 50, 50), Enum.Material.SmoothPlastic, "Prop")
			pp.Shape = Enum.PartType.Cylinder; pp.Transparency = 0.45
		end
		part(Vector3.new(0.18, 0.18, 0.15), CFrame.new(0, 0.25, -0.45 * s), C3(15, 15, 15))
		if kind == "fpv" then
			local w = part(Vector3.new(1.0, 0.32, 0.32), CFrame.new(0, -0.25, -0.35) * CFrame.Angles(0, math.pi / 2, 0), C3(60, 74, 42), Enum.Material.Metal, "Warhead"); w.Shape = Enum.PartType.Cylinder
			local c = part(Vector3.new(0.4, 0.4, 0.4), CFrame.new(0, -0.25, -0.95), C3(60, 74, 42), Enum.Material.Metal); c.Shape = Enum.PartType.Ball
		else
			local c = part(Vector3.new(0.35, 0.35, 0.35), CFrame.new(0, -0.25, -0.2), C3(20, 20, 20)); c.Shape = Enum.PartType.Ball
		end
	end
	body.Massless = false
	for _, p in ipairs(m:GetChildren()) do if p:IsA("BasePart") and p ~= body then addWeld(body, p) end end
	m.PrimaryPart = body
	m:SetAttribute("Team", team); m:SetAttribute("Kind", kind); m:SetAttribute("DHP", DDEF[kind].hp)
	return m, body
end
damageDrone = function(m, dmg, attTeam)
	if attTeam == m:GetAttribute("Team") then return end
	local hp = (m:GetAttribute("DHP") or 0) - dmg
	m:SetAttribute("DHP", hp)
	if hp <= 0 and not m:GetAttribute("Dead") then
		m:SetAttribute("Dead", true)
		local body = m.PrimaryPart
		if m:GetAttribute("Kind") == "fpv" and body then
			explode(body.Position, 6 * S, 100, m:GetAttribute("Team"), nil, nil, false)
		elseif body then fx("spark", body.Position) end
		task.defer(function() m:Destroy() end)
	end
end

NetF.OnServerInvoke = function(pl, cmd, kind)
	if cmd == "launch" then
		local ch = pl.Character
		local root = ch and ch:FindFirstChild("HumanoidRootPart")
		if not root then return nil end
		for _, d in ipairs(DroneF:GetChildren()) do if d:GetAttribute("Owner") == pl.UserId then d:Destroy() end end
		local k = (kind == "scout" or kind == "uav") and kind or "fpv"
		local m, body = buildDrone(k, pl.Team == TEAM[1] and 1 or 0)
		m:SetAttribute("Owner", pl.UserId)
		local start = root.CFrame * CFrame.new(0, k == "uav" and 40 * S or 2.5, -5)
		m:PivotTo(CFrame.new(start.Position) * (root.CFrame - root.Position))
		local att = Instance.new("Attachment"); att.Parent = body
		local vf = Instance.new("VectorForce"); vf.Attachment0 = att; vf.RelativeTo = Enum.ActuatorRelativeTo.World; vf.ApplyAtCenterOfMass = true; vf.Parent = body
		m.Parent = DroneF
		vf.Force = Vector3.new(0, body.AssemblyMass * workspace.Gravity, 0)
		pcall(function() body:SetNetworkOwner(pl) end)
		return m
	end
	return nil
end

-- AI kamikaze drones
local function spawnAIDrone(team, targetEnt)
	local m, body = buildDrone("fpv", team)
	for _, p in ipairs(m:GetDescendants()) do if p:IsA("BasePart") then p.Anchored = true end end
	local start = BASE[team] + V(team == 0 and 20 or -20, 8, rand(-10, 10))
	m:PivotTo(CFrame.new(start))
	m.Parent = DroneF
	table.insert(aiDrones, { model = m, body = body, team = team, target = targetEnt, t = 0, vel = Vector3.zero })
end
local function pickDroneTarget(team)
	local c = {}
	for _, e in ipairs(COMB) do
		if e.team ~= team and e.kind ~= "drone" and math.abs(e.root.Position.X) < 175 * S then
			table.insert(c, e)
			if e.kind == "veh" then table.insert(c, e); table.insert(c, e) end
		end
	end
	if #c == 0 then return nil end
	return pick(c)
end
local function aiDroneUpdate(d, dt)
	local m = d.model
	if not m.Parent or m:GetAttribute("Dead") then return false end
	d.t += dt
	local tg = d.target
	if not tg or not tg.root.Parent or (tg.model:FindFirstChildOfClass("Humanoid") and tg.model:FindFirstChildOfClass("Humanoid").Health <= 0) or (tg.kind == "veh" and not tg.model:GetAttribute("VHP")) then
		d.target = pickDroneTarget(d.team); tg = d.target
	end
	local pos = d.body.Position
	if not tg or d.t > 90 then
		m:SetAttribute("Dead", true); explode(pos, 6 * S, 100, d.team, nil, nil, false); m:Destroy(); return false
	end
	local tp = tg.root.Position + Vector3.new(0, 1, 0)
	local flat = Vector3.new(tp.X - pos.X, 0, tp.Z - pos.Z)
	local want
	if flat.Magnitude > 35 * S then want = flat.Unit * 24 * S + Vector3.new(0, math.clamp(28 * S - pos.Y, -5 * S, 5 * S), 0)
	else want = (tp - pos).Unit * 26 * S end
	local dv = want - d.vel
	local acc = 30 * S * dt
	if dv.Magnitude > acc then dv = dv.Unit * acc end
	d.vel += dv
	local np = pos + d.vel * dt
	rayParams.FilterDescendantsInstances = { FX, m }
	local res = workspace:Raycast(pos, np - pos + d.vel.Unit * 1.5, rayParams)
	if res or (tp - np).Magnitude < 2.5 * S or np.Y < 1 then
		m:SetAttribute("Dead", true)
		explode(res and res.Position or np, 7 * S, 120, d.team, nil, nil, false)
		m:Destroy()
		return false
	end
	m:PivotTo(CFrame.lookAt(np, np + Vector3.new(d.vel.X, 0, d.vel.Z) + Vector3.new(0, 0.001, 0)) * CFrame.Angles(-0.3, 0, 0))
	return true
end

-- ===== PLAYERS =====
local WEAP = { { dmg = 34, rate = 0.09, range = 350 * S }, { dmg = 38, rate = 0.075, range = 350 * S } }
local lastFire = {}
Players.RespawnTime = 6
Players.PlayerAdded:Connect(function(pl)
	pl.Team = TEAM[0]
	pl:SetAttribute("Med", 3)
	pl:SetAttribute("Kills", 0)
	pl.CharacterAdded:Connect(function(ch)
		pl:SetAttribute("Med", 3)
		local hum = ch:WaitForChild("Humanoid")
		local rh = ch:WaitForChild("RightHand", 5)
		if rh then
			local gun = Instance.new("Part"); gun.Name = "Gun"; gun.Size = Vector3.new(0.25, 0.4, 2.8); gun.Color = C3(30, 30, 30); gun.Material = Enum.Material.Metal; gun.CanCollide = false; gun.Massless = true
			gun.CFrame = rh.CFrame * CFrame.new(0, -0.2, -0.8); gun.Parent = ch; addWeld(gun, rh)
		end
		hum.Died:Connect(function()
			local tk = "T" .. (pl.Team == TEAM[1] and 1 or 0)
			RS:SetAttribute(tk, math.max(0, (RS:GetAttribute(tk) or 0) - 1))
			local c = killCredit[ch]
			feed((c and (c.team == 0 and "Северные" or "Южные") or "") .. " ✖ <b>" .. pl.Name .. "</b>", "#ff8888")
			for _, d in ipairs(DroneF:GetChildren()) do if d:GetAttribute("Owner") == pl.UserId and d:GetAttribute("Kind") ~= "uav" then d:Destroy() end end
		end)
	end)
end)

-- ===== MODES =====
local function spawnSquad(team, n, at, idx)
	local sq = newSquad(team, idx)
	for _ = 1, n do
		local p = (at or BASE[team]) + V(rand(-6, 6), 0, rand(-14, 14))
		task.spawn(makeBot, team, p, { squad = sq })
	end
	return sq
end
local BOTS = 16
local function startMode(mode)
	if RS:GetAttribute("Mode") ~= "" then return end
	RS:SetAttribute("Mode", mode)
	if mode == "free" then
		RS:SetAttribute("T0", 300); RS:SetAttribute("T1", 300)
		for _ = 1, BOTS / 4 do spawnSquad(0, 4); spawnSquad(1, 4) end
		spawnVehicle("btr", 0, V(-175, 0, 0)); spawnVehicle("jeep", 0, V(-180, 0, -4))
		spawnVehicle("btr", 1, V(175, 0, 0)); spawnVehicle("jeep", 1, V(180, 0, 4)); spawnVehicle("truck", 1, V(195, 0, -3))
	elseif mode == "defense" then
		RS:SetAttribute("T0", 9999); RS:SetAttribute("T1", 350)
		for i, p in ipairs(points) do
			p.prog = 1; p.owner = 0
			local n = 0
			for _, h in ipairs(houses) do
				if not h.ruined and n < 2 and math.sqrt((h.cx * S - p.pos.X) ^ 2 + (h.cz * S - p.pos.Z) ^ 2) < 35 * S then
					n += 1
					for _ = 1, 2 do
						local gp = V(h.cx + rand(-h.w / 2 + 1, h.w / 2 - 1), 0, h.cz + rand(-h.d / 2 + 1, h.d / 2 - 1))
						task.spawn(makeBot, 0, gp, { garrison = gp })
					end
				end
			end
			spawnSquad(0, 4, p.pos + V(-8, 0, 0), i - 1)
		end
		spawnVehicle("btr", 0, V(-40, 0, 2))
		for _ = 1, 5 do spawnSquad(1, 4) end
		spawnVehicle("btr", 1, V(175, 0, 0)); spawnVehicle("btr", 1, V(185, 0, 4)); spawnVehicle("jeep", 1, V(180, 0, -4)); spawnVehicle("truck", 1, V(195, 0, 3))
	elseif mode == "sandbox" then
		RS:SetAttribute("T0", 0); RS:SetAttribute("T1", 0)
	end
	feed("Режим: " .. (mode == "free" and "Свободный бой" or mode == "defense" and "Оборона посёлка" or "Песочница"), "#ffffff")
end

Net.OnServerEvent:Connect(function(pl, cmd, a, b, c)
	if cmd == "mode" then
		if a == "free" or a == "defense" or a == "sandbox" then startMode(a) end
	elseif cmd == "fire" then
		local ch = pl.Character
		local hum = ch and ch:FindFirstChildOfClass("Humanoid")
		local head = ch and ch:FindFirstChild("Head")
		if not hum or hum.Health <= 0 or not head or typeof(a) ~= "Vector3" or typeof(b) ~= "Vector3" then return end
		local w = WEAP[(c == 2) and 2 or 1]
		local now = os.clock()
		if lastFire[pl] and now - lastFire[pl] < w.rate * 0.7 then return end
		lastFire[pl] = now
		if (a - head.Position).Magnitude > 12 then a = head.Position end
		shoot(a, b, w.range, w.dmg, pl.Team == TEAM[1] and 1 or 0, pl.Name, pl, ch)
	elseif cmd == "med" then
		local ch = pl.Character
		local hum = ch and ch:FindFirstChildOfClass("Humanoid")
		local n = pl:GetAttribute("Med") or 0
		if hum and hum.Health > 0 and n > 0 and hum.Health < hum.MaxHealth then
			pl:SetAttribute("Med", n - 1); hum.Health = math.min(hum.MaxHealth, hum.Health + 50)
		end
	elseif cmd == "refill" then
		local ch = pl.Character
		local root = ch and ch:FindFirstChild("HumanoidRootPart")
		if root and (root.Position - BASE[0]).Magnitude < 30 * S then pl:SetAttribute("Med", 3) end
	elseif cmd == "detonate" then
		for _, d in ipairs(DroneF:GetChildren()) do
			if d:GetAttribute("Owner") == pl.UserId and d:GetAttribute("Kind") == "fpv" and not d:GetAttribute("Dead") then
				local body = d.PrimaryPart
				if body then
					d:SetAttribute("Dead", true)
					explode(body.Position, 7.5 * S, 135, pl.Team == TEAM[1] and 1 or 0, pl.Name, pl, false)
				end
				d:Destroy()
			end
		end
	elseif cmd == "recover" then
		for _, d in ipairs(DroneF:GetChildren()) do
			if d:GetAttribute("Owner") == pl.UserId and d:GetAttribute("Kind") ~= "fpv" then d:Destroy() end
		end
	elseif cmd == "crash" then
		for _, d in ipairs(DroneF:GetChildren()) do
			if d:GetAttribute("Owner") == pl.UserId then
				if d.PrimaryPart then fx("spark", d.PrimaryPart.Position) end
				d:Destroy()
			end
		end
	elseif cmd == "scan" then
		-- a = camera position, b = look vector, c = {cos, manual}
		if typeof(a) ~= "Vector3" or typeof(b) ~= "Vector3" or type(c) ~= "table" then return end
		local myTeam = pl.Team == TEAM[1] and 1 or 0
		local owns = false
		for _, d in ipairs(DroneF:GetChildren()) do
			if d:GetAttribute("Owner") == pl.UserId and d.PrimaryPart and (d.PrimaryPart.Position - a).Magnitude < 30 then owns = true end
		end
		if not owns then return end
		local cosA = tonumber(c[1]) or 0.9
		local maxD = (tonumber(c[2]) or 220) * S
		local n = 0
		local now = os.clock()
		for _, e in ipairs(COMB) do
			if e.team ~= myTeam then
				local dv = e.root.Position - a
				local dist = dv.Magnitude
				if dist < maxD and dv.Unit:Dot(b.Unit) > cosA then
					rayParams.FilterDescendantsInstances = { FX, DroneF }
					local res = workspace:Raycast(a, dv, rayParams)
					if not res or e.model:IsAncestorOf(res.Instance) then
						if not marks[myTeam][e.model] or marks[myTeam][e.model] < now then n += 1 end
						marks[myTeam][e.model] = now + 40
					end
				end
			end
		end
		if n > 0 then Net:FireClient(pl, "scanres", n, c[3]) elseif c[3] then Net:FireClient(pl, "scanres", 0, true) end
	elseif cmd == "place" then
		if RS:GetAttribute("Mode") ~= "sandbox" or RS:GetAttribute("SB") then return end
		if typeof(b) ~= "Vector3" then return end
		local pos = Vector3.new(b.X, 0, b.Z)
		local team = (c == 1) and 1 or 0
		if a == "s" then task.spawn(makeBot, team, pos, { frozen = true })
		elseif a == "btr" or a == "jeep" or a == "truck" then spawnVehicle(a, team, pos, true)
		elseif a == "drone" then task.delay(0.1, function() local t = pickDroneTarget(1); if t then spawnAIDrone(1, t) end end) end
	elseif cmd == "sbstart" then
		if RS:GetAttribute("Mode") == "sandbox" then RS:SetAttribute("SB", true) end
	end
end)

-- ===== MAIN LOOP =====
local capT, dirT, drainT, markT = 0, 3, 5, 0
local droneT = { [0] = 40, [1] = 25 }
local function aliveCount(team)
	local n = 0
	for _, b in ipairs(bots) do if b.alive and b.team == team then n += 1 end end
	return n
end
RunService.Heartbeat:Connect(function(dt)
	local now = os.clock()
	COMB = combatants()
	local mode = RS:GetAttribute("Mode")
	for _, b in ipairs(bots) do botUpdate(b, now, dt) end
	for _, v in ipairs(vehicles) do vehUpdate(v, now, dt) end
	for i = #aiDrones, 1, -1 do if not aiDroneUpdate(aiDrones[i], dt) then table.remove(aiDrones, i) end end
	-- cleanup
	for i = #bots, 1, -1 do if not bots[i].alive and not bots[i].model.Parent then table.remove(bots, i) end end
	-- capture
	capT -= dt
	if capT <= 0 and mode ~= "" then
		capT = 0.25
		for _, p in ipairs(points) do
			local cnt = { [0] = 0, [1] = 0 }
			for _, e in ipairs(COMB) do
				if e.kind ~= "drone" then
					local d = Vector3.new(e.root.Position.X - p.pos.X, 0, e.root.Position.Z - p.pos.Z).Magnitude
					if d < p.r then cnt[e.team] += (e.kind == "veh" and 2 or 1) end
				end
			end
			local diff = cnt[0] - cnt[1]
			if diff ~= 0 then
				local old = p.owner
				p.prog = math.clamp(p.prog + math.sign(diff) * math.min(3, math.abs(diff)) * 0.025, -1, 1)
				if p.prog >= 1 then p.owner = 0 elseif p.prog <= -1 then p.owner = 1 elseif math.abs(p.prog) < 0.02 then p.owner = -1 end
				if old ~= p.owner and p.owner >= 0 then feed("Точка " .. p.name .. " захвачена: " .. (p.owner == 0 and "Северные" or "Южные"), p.owner == 0 and "#88bbff" or "#ff8888") end
			end
			local col = Color3.new(1, 1, 1):Lerp(p.prog >= 0 and TEAMCOL[0] or TEAMCOL[1], math.abs(p.prog))
			p.flag.Color = col; p.ring.Color = col
			p.flag.CFrame = CFrame.new(p.pos + V(6, 1.5 + math.abs(p.prog) * 4.5, 5))
			RS:SetAttribute("P" .. p.name, p.prog)
			RS:SetAttribute("C" .. p.name, (cnt[0] > 0 and cnt[1] > 0))
		end
	end
	if mode == "" or game_over then return end
	-- marks broadcast
	markT -= dt
	if markT <= 0 then
		markT = 1
		for t = 0, 1 do
			local list = {}
			for m, exp in pairs(marks[t]) do
				if exp < now or not m.Parent then marks[t][m] = nil else table.insert(list, m) end
			end
			for _, pl in ipairs(Players:GetPlayers()) do
				if (pl.Team == TEAM[1] and 1 or 0) == t then Net:FireClient(pl, "marks", list) end
			end
		end
	end
	if mode == "sandbox" then return end
	-- director
	dirT -= dt
	if dirT <= 0 then
		dirT = 4
		local tgt = { [0] = BOTS, [1] = BOTS }
		if mode == "defense" then tgt[0] = math.floor(BOTS * 0.8); tgt[1] = math.floor(BOTS * 1.3) end
		for t = 0, 1 do
			if (RS:GetAttribute("T" .. t) or 0) > 0 and aliveCount(t) <= tgt[t] - 4 then
				spawnSquad(t, 4, (mode == "defense" and t == 0) and V(-60, 0, 0) or nil)
			end
		end
	end
	for t = 0, 1 do
		droneT[t] -= dt
		if droneT[t] <= 0 then
			droneT[t] = t == 1 and rand(22, 35) or rand(40, 60)
			local tg = pickDroneTarget(t)
			if tg then spawnAIDrone(t, tg) end
		end
	end
	-- drone marks by enemy recon (simulated): team1 spots players near front occasionally
	drainT -= dt
	if drainT <= 0 then
		drainT = 5
		local own = { [0] = 0, [1] = 0 }
		for _, p in ipairs(points) do if p.owner >= 0 and math.abs(p.prog) >= 0.99 then own[p.owner] += 1 end end
		if mode == "free" then
			if own[0] > own[1] then RS:SetAttribute("T1", (RS:GetAttribute("T1") or 0) - (own[0] - own[1])) end
			if own[1] > own[0] then RS:SetAttribute("T0", (RS:GetAttribute("T0") or 0) - (own[1] - own[0])) end
		end
		for _, e in ipairs(COMB) do if e.team == 0 and e.kind == "sol" and rnd:NextNumber() < 0.08 then marks[1][e.model] = now + 20 end end
	end
	local winner = nil
	if (RS:GetAttribute("T1") or 1) <= 0 then winner = 0
	elseif mode == "free" and (RS:GetAttribute("T0") or 1) <= 0 then winner = 1
	elseif mode == "defense" and points[1].owner == 1 and points[2].owner == 1 and points[3].owner == 1 then winner = 1 end
	if winner ~= nil then
		game_over = true
		Net:FireAllClients("end", winner)
	end
end)
