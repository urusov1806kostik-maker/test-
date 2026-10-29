--!nocheck
-- VOID TD :: World.VoidMap
-- Карта «The Forgotten Realm» (workspace.VoidTDMap): парящий остров, дорога, портал врагов,
-- ядро игрока, декор, летающие островки, площадка прибытия.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("VoidTD")
local Config = require(Shared:WaitForChild("Config"))
local Path = require(Shared:WaitForChild("Path"))

local Kit = require(script.Parent:WaitForChild("Kit"))

local V, CF, ANG, rad = Vector3.new, CFrame.new, CFrame.Angles, math.rad
local rgb = Color3.fromRGB
local C = Kit.C
local block, neon, light, emitter, spin = Kit.Block, Kit.Neon, Kit.Light, Kit.Emitter, Kit.Spin

local MAP = Config.Map
local GY = MAP.GroundY
local SX, SZ = MAP.IslandSize.X, MAP.IslandSize.Y

local function folder(parent, name)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

local function buildIsland(map, rng)
	local g = folder(map, "Ground")
	local top = block(g, V(SX, 4, SZ), CF(0, GY - 2, 0), C.Ground, nil, { Name = "IslandTop" })
	top:SetAttribute("Placeable", true)
	for i = 1, 18 do
		local w, d = rng:NextNumber(14, 34), rng:NextNumber(14, 30)
		local x = rng:NextNumber(-SX / 2 + w / 2 + 2, SX / 2 - w / 2 - 2)
		local z = rng:NextNumber(-SZ / 2 + d / 2 + 2, SZ / 2 - d / 2 - 2)
		local p = Kit.Part(g, {
			Name = "Moss", Size = V(w, 0.2, d), CFrame = CF(x, GY + 0.02 + i * 0.004, z) * ANG(0, rad(rng:NextNumber(-20, 20)), 0),
			Color = i % 2 == 0 and C.Moss or C.Ground2, Material = Enum.Material.Grass, CastShadow = false,
		})
		p:SetAttribute("Placeable", true)
	end

	local u = folder(map, "Underside")
	local edge = {}
	for x = -SX / 2, SX / 2 - 1, 16 do
		edge[#edge + 1] = V(x, 0, -SZ / 2)
		edge[#edge + 1] = V(x, 0, SZ / 2)
	end
	for z = -SZ / 2 + 16, SZ / 2 - 16, 16 do
		edge[#edge + 1] = V(-SX / 2, 0, z)
		edge[#edge + 1] = V(SX / 2, 0, z)
	end
	for _, p in ipairs(edge) do
		local s, h = rng:NextNumber(10, 20), rng:NextNumber(5, 9)
		local size = V(s, h, s * rng:NextNumber(0.7, 1.2))
		local y = GY - h / 2 + rng:NextNumber(-1.5, 0.2)
		local rot = ANG(rad(rng:NextNumber(-6, 6)), rad(rng:NextNumber(0, 90)), rad(rng:NextNumber(-6, 6)))
		block(u, size, CF(p.X, y, p.Z) * rot, rng:NextInteger(1, 2) == 1 and C.Rock or C.Rock2, nil, { Name = "EdgeRock" })
	end
	local layers = { { 0.92, 12, -9 }, { 0.75, 16, -22 }, { 0.55, 18, -38 }, { 0.32, 20, -55 }, { 0.14, 18, -72 } }
	for i, L in ipairs(layers) do
		local s, h, yOff = L[1], L[2], L[3]
		local cx, cz = rng:NextNumber(-6, 6), rng:NextNumber(-6, 6)
		local yaw = rad(rng:NextNumber(-8, 8))
		local layerCF = CF(cx, GY + yOff, cz) * ANG(0, yaw, 0)
		block(u, V(SX * s, h, SZ * s), layerCF, i % 2 == 0 and C.Rock or C.Rock2, nil, { Name = "Bedrock" .. i })
		if i <= 4 then
			-- светящаяся жила на боку яруса (вместе с его смещением и поворотом)
			neon(u, V(SX * s * 0.6, 0.6, 0.6), layerCF * CF(0, rng:NextNumber(-3, 3), -SZ * s / 2 - 0.1) * ANG(0, 0, rad(rng:NextNumber(-12, 12))), C.Neon, { Name = "Vein" })
		end
	end
	local root = neon(u, V(10, 22, 10), CF(0, GY - 92, 0) * ANG(rad(8), rad(45), 0), C.Neon, { Name = "Crystal Root", CanCollide = true })
	light(root, C.Neon, 40, 3)
end

local function buildPath(map, rng)
	local f = folder(map, "Path")
	local w = MAP.PathWidth
	Kit.Road(f, Path.Get("Void").Points, GY, w, C.Path, C.PathEdge, function(i, a, b, cf, len, dir)
		local right = V(-dir.Z, 0, dir.X)
		local steps = math.floor(len / 14)
		for s = 1, steps do
			local t = s / (steps + 1)
			local side = s % 2 == 0 and 1 or -1
			local p = a:Lerp(b, t) + right * side * (w / 2 + 1.2)
			local sz = rng:NextNumber(0.8, 1.6)
			block(f, V(sz, 0.7 * sz, 1.2 * sz), CF(p.X, GY + 0.3 * sz, p.Z) * ANG(rad(rng:NextNumber(-20, 20)), rad(rng:NextNumber(0, 180)), 0), C.Stone2, nil, { Name = "Pebble", CanCollide = false })
		end
		if i % 2 == 0 then
			local mid = (a + b) / 2
			local rot = CFrame.lookAt(V(), b - a).Rotation
			neon(f, V(0.35, 0.05, math.min(len * 0.4, 12)), CF(mid.X + rng:NextNumber(-2, 2), GY + 0.31, mid.Z + rng:NextNumber(-2, 2)) * rot * ANG(0, rad(rng:NextNumber(-25, 25)), 0), C.Neon, { Name = "Crack" })
		end
	end)
end

local function buildPortal(map, rng)
	local m = Instance.new("Model")
	m.Name = "VoidPortal"
	local pts = Path.Get("Void").Points
	local start = pts[1]
	local dir = (pts[2] - start).Unit
	local R = 10
	local foot = start - dir * 4
	local center = foot + V(0, R + 1, 0)
	local base = CFrame.lookAt(center, center + dir)
	block(m, V(26, 1.2, 12), CF(foot.X, GY + 0.4, foot.Z) * base.Rotation, C.Stone2, nil, { Name = "Base" })
	block(m, V(22, 1.2, 9), CF(foot.X, GY + 1.2, foot.Z) * base.Rotation, C.Stone, nil, { Name = "Base2" })
	for i = 0, 17 do
		if i ~= 4 then -- выпавший камень
			local a = i / 18 * math.pi * 2
			local off = CF(math.cos(a) * R, math.sin(a) * R, 0)
			block(m, V(3.6, 3.2 + rng:NextNumber(-0.4, 0.4), 3), base * off * ANG(0, 0, a + rad(rng:NextNumber(-4, 4))), i % 3 == 0 and C.Stone or C.Stone2, nil, { Name = "RingStone" })
			if i % 3 == 0 then
				neon(m, V(0.6, 1.4, 0.3), base * off * ANG(0, 0, a) * CF(0, 0, -1.55), C.Neon, { Name = "Rune" })
			end
		end
	end
	block(m, V(3.4, 2.8, 3), CF(center.X + 6, GY + 1.4, center.Z + 9) * ANG(rad(20), rad(30), rad(10)), C.Stone2, nil, { Name = "Fallen" })
	local discCF = base * ANG(0, rad(90), 0)
	local disc = Kit.Cyl(m, "PortalDisc", V(0.4, 2 * R - 2.5, 2 * R - 2.5), discCF, rgb(110, 30, 190), Enum.Material.Neon, { CanCollide = false, Transparency = 0.15 })
	local core = Kit.Cyl(m, "PortalCore", V(0.5, 11, 11), discCF, rgb(15, 0, 30), Enum.Material.Neon, { CanCollide = false })
	for i = 1, 3 do
		local s = neon(m, V(0.6, 16, 0.7), base * ANG(0, 0, rad(i * 60)) * CF(0, 0, -0.4), C.NeonSoft, { Name = "Swirl", Transparency = 0.35 })
		spin(s, 1.6 + 0.4 * (i - 1), "Z")
	end
	light(core, C.Neon, 45, 4)
	emitter(disc, C.Neon, { Rate = 40, Size = 0.8, SpeedMin = 2, SpeedMax = 6, LifeMin = 1, LifeMax = 2 })
	m.Parent = map
	return m
end

local function buildCore(map, rng)
	local m = Instance.new("Model")
	m.Name = "VoidCore"
	local last = Path.Get("Void").Points
	last = last[#last]
	local c = V(last.X, GY, last.Z)
	local vert = ANG(0, 0, rad(90))
	Kit.Cyl(m, "Plinth1", V(1.4, 30, 30), CF(c + V(0, 0.5, 0)) * vert, C.Stone2)
	Kit.Cyl(m, "Plinth2", V(1.4, 22, 22), CF(c + V(0, 1.7, 0)) * vert, C.Stone)
	Kit.Cyl(m, "GlowRing", V(0.2, 23, 23), CF(c + V(0, 1.15, 0)) * vert, C.Neon, Enum.Material.Neon, { CanCollide = false })
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2
		local h = i == 2 and 5 or 11 + rng:NextNumber(-1, 1) -- сломанная колонна
		local pc = c + V(math.cos(a) * 12, 0, math.sin(a) * 12)
		block(m, V(2.4, h, 2.4), CF(pc + V(0, 2.4 + h / 2, 0)) * ANG(0, a, i == 4 and rad(4) or 0), C.Stone2, nil, { Name = "Pillar" })
		if i ~= 2 then
			local gem = neon(m, V(1.2, 1.8, 1.2), CF(pc + V(0, 2.4 + h + 1.2, 0)) * ANG(0, rad(45), rad(45)), C.Neon, { Name = "PillarGem" })
			spin(gem, 1.2, "Y")
		end
	end
	local cc = CF(c + V(0, 13, 0)) * ANG(rad(45), 0, rad(45))
	local crystal = neon(m, V(6, 6, 6), cc, rgb(190, 90, 255), { Name = "CoreCrystal" })
	spin(crystal, 0.8, "Y", 1.2)
	light(crystal, rgb(190, 90, 255), 50, 5)
	emitter(crystal, C.NeonSoft, { Rate = 25, Size = 0.7, SpeedMin = 2, SpeedMax = 5 })
	local shell = block(m, V(9, 9, 9), cc, rgb(120, 60, 200), Enum.Material.Glass, { Name = "CoreShell", Transparency = 0.7, CanCollide = false })
	spin(shell, -0.5, "Y", 1.2)
	for k = 1, 2 do
		local ring = Instance.new("Model")
		ring.Name = "OrbitRing"
		local rr = 7 + 1.8 * k
		local tilt = k == 1 and ANG(rad(20), 0, rad(10)) or ANG(rad(-25), 0, rad(-12))
		local pivot = CF(c + V(0, 13, 0)) * tilt
		for i = 0, 15 do
			local a = i / 16 * math.pi * 2
			neon(ring, V(0.4, 0.4, 2.6), pivot * CF(math.cos(a) * rr, 0, math.sin(a) * rr) * ANG(0, -a, 0), k == 1 and C.Neon or C.NeonPink, { Name = "Seg" })
		end
		ring.WorldPivot = pivot
		spin(ring, k == 1 and 0.9 or -0.7, "Y")
		ring.Parent = m
	end
	m:SetAttribute("CoreCenter", c + V(0, 13, 0))
	m.Parent = map
	return m
end

local function buildDecor(map, rng)
	local f = folder(map, "Decor")
	local road = Path.Get("Void")
	local pts = road.Points
	local taken = { MAP.BattleSpawn }
	local function freeSpot(minPath, minSep)
		for _ = 1, 60 do
			local p = V(rng:NextNumber(-119, 119), GY, rng:NextNumber(-92, 92))
			local ok = road.DistanceToPath(p) > minPath and Path.FlatDistance(p, pts[1]) > 22 and Path.FlatDistance(p, pts[#pts]) > 22
				and Path.FlatDistance(p, MAP.Center) > 14
			if ok then
				for _, q in ipairs(taken) do
					if Path.FlatDistance(p, q) < minSep then
						ok = false
						break
					end
				end
			end
			if ok then
				taken[#taken + 1] = p
				return p
			end
		end
		return nil
	end
	for _ = 1, 10 do
		local p = freeSpot(11, 14)
		if p then
			Kit.CrystalCluster(f, rng, p, rng:NextNumber(0.9, 1.6))
		end
	end
	for _ = 1, 14 do
		local p = freeSpot(12, 12)
		if p then
			Kit.DarkTree(f, rng, p)
		end
	end
	for _ = 1, 4 do
		local p = freeSpot(14, 18)
		if p then
			Kit.Ruin(f, rng, p)
		end
	end
	for _ = 1, 6 do
		local p = freeSpot(11, 12)
		if p then
			Kit.BrokenColumn(f, rng, p)
		end
	end
	local sky = folder(map, "Sky")
	local spots = { V(-170, 25, -60), V(-150, 40, 90), V(10, 35, -150), V(170, 20, 40), V(140, 45, -120), V(-40, 50, 150), V(90, 30, 150) }
	for i, p in ipairs(spots) do
		Kit.FloatingIsland(sky, rng, p + V(0, GY, 0), i % 3 == 0 and 1.5 or 1)
	end
end

return function()
	local rng = Random.new(1337)
	local map = Instance.new("Model")
	map.Name = "VoidTDMap"
	buildIsland(map, rng)
	buildPath(map, rng)
	buildPortal(map, rng)
	buildCore(map, rng)
	buildDecor(map, rng)
	local bs = MAP.BattleSpawn
	block(map, V(8, 1, 8), CF(bs.X, GY + 0.5, bs.Z), rgb(70, 40, 110), nil, { Name = "BattlePad" })
	neon(map, V(7, 0.05, 7), CF(bs.X, GY + 1.03, bs.Z), C.Neon, { Name = "BattlePadGlow", Transparency = 0.6 })
	Kit.Calm(map)
	map.WorldPivot = CF(MAP.Center)
	map.Parent = workspace
	return map
end
