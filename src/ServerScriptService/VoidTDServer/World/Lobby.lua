--!nocheck
-- VOID TD :: World.Lobby
-- Главное лобби (workspace.VoidTDLobby): круглая платформа, круги зон (Zones), стойки кейсов,
-- статуи юнитов, декоративный портал ИГРАТЬ с вывеской, деревья/кристаллы, точка появления.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("VoidTD")
local Config = require(Shared:WaitForChild("Config"))

local Kit = require(script.Parent:WaitForChild("Kit"))

local V, CF, ANG, rad = Vector3.new, CFrame.new, CFrame.Angles, math.rad
local rgb = Color3.fromRGB
local C = Kit.C
local block, neon, light, emitter, cylY = Kit.Block, Kit.Neon, Kit.Light, Kit.Emitter, Kit.CylY

local L = Config.Lobby

local function flat(a, b)
	return Vector2.new(a.X - b.X, a.Z - b.Z).Magnitude
end

local function outDir(offset)
	local o = V(offset.X, 0, offset.Z)
	return o.Magnitude > 0 and o.Unit or V(0, 0, 1)
end

local function platform(m, c, R, rng)
	local floor = cylY(m, "Floor", R, 4, c - V(0, 2, 0), C.Ground)
	floor:SetAttribute("Placeable", false)
	-- инкрустация: каждый слой чуть выше предыдущего (без z-fighting), сверху — центральный круг
	local inlays = {
		{ "OuterRing", R - 4, C.Neon, Enum.Material.Neon, 0.6 },
		{ "OuterFloor", R - 4.4, C.Ground, Enum.Material.Slate, 0 },
		{ "MidRing", 55.6, C.Neon, Enum.Material.Neon, 0.7 },
		{ "MidFloor", 55, C.Ground, Enum.Material.Slate, 0 },
		{ "InnerRing", 30.6, C.Neon, Enum.Material.Neon, 0.3 },
		{ "FloorInlay", 30, C.Ground2, Enum.Material.Slate, 0 },
	}
	for i, d in ipairs(inlays) do
		local top = 0.02 * i
		cylY(m, d[1], d[2], 0.1, c + V(0, top - 0.05, 0), d[3], d[4], { CanCollide = false, Transparency = d[5] })
	end
	local under = { { 0.9, 10, -8 }, { 0.68, 14, -19 }, { 0.45, 16, -33 }, { 0.22, 16, -48 } }
	for i, u in ipairs(under) do
		cylY(m, "Under" .. i, R * u[1], u[2], c + V(rng:NextNumber(-3, 3), u[3], rng:NextNumber(-3, 3)), i % 2 == 0 and C.Rock or C.Rock2)
	end
	local root = neon(m, V(7, 16, 7), CF(c + V(0, -62, 0)) * ANG(rad(6), rad(45), 0), C.Neon, { Name = "CrystalRoot", CanCollide = true })
	light(root, C.Neon, 40, 3)
	for i = 0, 35 do
		local a = i / 36 * math.pi * 2
		local s = rng:NextNumber(4, 7)
		local h = rng:NextNumber(1, 2.5)
		local p = c + V(math.cos(a) * (R - 1), 0, math.sin(a) * (R - 1))
		block(m, V(s, h, s), CF(p) * ANG(0, rad(rng:NextNumber(0, 90)), 0), C.Rock2, nil, { Name = "EdgeRock" })
		if i % 3 == 0 then
			local ph = rng:NextNumber(6, 10)
			local pp = c + V(math.cos(a) * (R - 3), 0, math.sin(a) * (R - 3))
			block(m, V(2.2, ph, 2.2), CF(pp + V(0, ph / 2, 0)) * ANG(0, a, 0), C.Stone2, nil, { Name = "Pillar" })
			local gem = neon(m, V(1, 1.6, 1), CF(pp + V(0, ph + 1.4, 0)) * ANG(0, rad(45), rad(45)), C.Neon, { Name = "PillarGem" })
			Kit.Spin(gem, 1.5, "Y")
			light(gem, C.Neon, 14, 1.2)
		end
	end
end

local function caseStand(m, key, z, zc)
	local out = outDir(z.Offset)
	local sp = zc + out * 13
	local vert = ANG(0, 0, rad(90))
	Kit.Cyl(m, "CaseStand", V(2.5, 9, 9), CF(sp + V(0, 1.25, 0)) * vert, C.Stone2)
	Kit.Cyl(m, "CaseStandRing", V(0.3, 9.4, 9.4), CF(sp + V(0, 2.4, 0)) * vert, z.Color, Enum.Material.Neon, { CanCollide = false })
	local CaseModels = Kit.Model("Cases")
	if CaseModels then
		local ok, built = pcall(CaseModels.Build, z.Case)
		if ok and built and built.Model then
			local cm = built.Model
			cm:ScaleTo(1.6)
			cm:PivotTo(CF(sp + V(0, 2.6, 0)) * CFrame.lookAt(V(), -out).Rotation)
			Kit.Spin(cm, 0.5, "Y")
			cm.Parent = m
		end
	end
	local glow = Kit.Ghost(m, V(0.5, 0.5, 0.5), sp + V(0, 6, 0), "CaseGlow")
	light(glow, z.Color, 22, 2)
	emitter(glow, z.Color, { Rate = 8, Size = 0.4, SpeedMin = 1, SpeedMax = 2 })
	local case = Config.Cases[z.Case]
	if case then
		Kit.Billboard(m, sp + V(0, 13, 0), case.Name, "💎" .. case.Cost1 .. " / x10 💎" .. case.Cost10, z.Color, 14)
	end
	return sp
end

local function statues(m, c)
	local uz = c + L.Zones.Units.Offset
	for _, s in ipairs({ { "VoidSoldier", V(13, 0, -9) }, { "ShadowArcher", V(15, 0, 0) }, { "LostMage", V(13, 0, 9) } }) do
		Kit.Statue(m, s[1], uz + s[2], uz, 2.5)
	end
	local pz = c + L.Zones.Play.Offset
	for _, s in ipairs({ { "VoidEmperor", V(-17, 0, -6) }, { "AbyssOverlord", V(17, 0, -6) }, { "RiftMonarch", V(-32, 0, 2) }, { "LunarSeraph", V(32, 0, 2) } }) do
		Kit.Statue(m, s[1], pz + s[2], c, 4)
	end
	for _, s in ipairs({ { "FallenAngel", V(-24, 0, 50) }, { "EclipseGuardian", V(24, 0, 50) }, { "Starbreaker", V(-42, 0, 42) }, { "BloodfangWarlord", V(42, 0, 42) } }) do
		Kit.Statue(m, s[1], c + s[2], c, 3)
	end
	for _, s in ipairs({ { "RealityDestroyer", V(-8, 0, 0) }, { "CrimsonEclipse", V(8, 0, 0) } }) do
		Kit.Statue(m, s[1], c + s[2], c + V(0, 0, 60), 5)
	end
	Kit.Billboard(m, c + V(0, 17, 0), "SECRET", "шанс 0.1% в новых кейсах", rgb(255, 40, 60), 12)
end

local function playPortal(m, c)
	local pz = c + L.Zones.Play.Offset
	Kit.RingPortal(m, pz + V(0, 10.5, -11), V(0, 0, 1))
	block(m, V(24, 1, 8), CF(pz + V(0, 0.5, -11)), C.Stone2, nil, { Name = "PortalBase" })
	local sign = block(m, V(30, 8, 1), CF(pz + V(0, 27, -12)) * ANG(0, math.pi, 0), C.Black, nil, { Name = "Sign" })
	neon(m, V(31, 9, 0.6), CF(pz + V(0, 27, -12.4)), C.Neon, { Name = "SignFrame" })
	local g = Instance.new("SurfaceGui")
	g.Face = Enum.NormalId.Front
	g.LightInfluence = 0
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = 30
	g.Parent = sign
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.Text = "VOID TD"
	t.TextColor3 = rgb(200, 120, 255)
	t.TextStrokeTransparency = 0
	t.Size = UDim2.fromScale(1, 0.7)
	t.Parent = g
	local s = t:Clone()
	s.Text = "THE FORGOTTEN REALM"
	s.Font = Enum.Font.GothamBold
	s.TextColor3 = rgb(235, 225, 255)
	s.Position = UDim2.fromScale(0, 0.68)
	s.Size = UDim2.fromScale(1, 0.28)
	s.Parent = g
end

local function decor(m, c, R, rng, taken)
	for _, off in ipairs({ V(-24, 0, 50), V(24, 0, 50), V(-42, 0, 42), V(42, 0, 42), V(0, 0, 0), V(77, 0, 8), V(-32, 0, -60), V(32, 0, -60), V(0, 0, -73), V(-17, 0, -68), V(17, 0, -68) }) do
		taken[#taken + 1] = c + off
	end
	for i = 1, 24 do
		local a, d = rng:NextNumber(0, math.pi * 2), rng:NextNumber(36, R - 8)
		local p = c + V(math.cos(a) * d, 0, math.sin(a) * d)
		local ok = flat(p, L.Spawn) > 12
		for _, q in ipairs(taken) do
			if not ok then
				break
			end
			ok = flat(p, q) >= 16
		end
		if ok then
			taken[#taken + 1] = p
			if i % 2 == 0 then
				Kit.DarkTree(m, rng, p)
			else
				Kit.CrystalCluster(m, rng, p, rng:NextNumber(0.9, 1.4))
			end
		end
	end
end

return function()
	local rng = Random.new(4242)
	local c, R = L.Center, L.Radius
	local m = Instance.new("Model")
	m.Name = "VoidTDLobby"
	platform(m, c, R, rng)
	local zones = Instance.new("Folder")
	zones.Name = "Zones"
	zones.Parent = m
	local taken = {}
	for key, z in pairs(L.Zones) do
		local zc = c + z.Offset
		Kit.ZoneCircle(zones, key, z, zc)
		taken[#taken + 1] = zc
		if z.Case then
			taken[#taken + 1] = caseStand(m, key, z, zc)
		end
		if z.Teleport then
			-- место под ворота Хэллоуина (строятся отдельно)
			taken[#taken + 1] = zc + outDir(z.Offset) * 9
		end
	end
	statues(m, c)
	playPortal(m, c)
	decor(m, c, R, rng, taken)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "LobbySpawn"
	spawn.Anchored = true
	spawn.Size = V(10, 1, 10)
	spawn.CFrame = CF(L.Spawn + V(0, 0.5, 0))
	spawn.Color = rgb(70, 40, 110)
	spawn.Material = Enum.Material.Slate
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.BottomSurface = Enum.SurfaceType.Smooth
	spawn.Parent = m
	cylY(m, "SpawnGlow", 4.6, 0.08, L.Spawn + V(0, 1.03, 0), C.Neon, Enum.Material.Neon, { CanCollide = false, Transparency = 0.5 })
	m.WorldPivot = CF(c)
	Kit.Calm(m)
	m.Parent = workspace
	return m
end
