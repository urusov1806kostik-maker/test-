--!nocheck
-- VOID TD :: World.Halloween
-- Хэллоуин-мир: ворота HALLOWEEN EVENT в лобби (VoidTDLobby.HalloweenGate), остров (VoidTDHalloween)
-- с кейсом, очередью на 4 квадратах, статуями и бестиарием, и карта «Haunted Hollow» (VoidTDHalloweenMap).

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("VoidTD")
local Config = require(Shared:WaitForChild("Config"))
local Path = require(Shared:WaitForChild("Path"))

local Kit = require(script.Parent:WaitForChild("Kit"))

local V, CF, ANG, rad = Vector3.new, CFrame.new, CFrame.Angles, math.rad
local rgb = Color3.fromRGB
local H = Kit.H
local block, neon, wedge, light, emitter, cylY = Kit.Block, Kit.Neon, Kit.Wedge, Kit.Light, Kit.Emitter, Kit.CylY

local HW = {}

local I = Config.HalloweenIsland
local HM = Config.Maps.Halloween
local GREEN_FOG = rgb(120, 200, 130)

local function flat(a, b)
	return Vector2.new(a.X - b.X, a.Z - b.Z).Magnitude
end

local function outDir(offset)
	local o = V(offset.X, 0, offset.Z)
	return o.Magnitude > 0 and o.Unit or V(0, 0, 1)
end

-- невидимый блок тумана (не мешает рейкастам постановки)
local function fogBlock(parent, size, pos, color, rate, sz)
	local p = Kit.Ghost(parent, size, pos, "FogArea")
	Kit.Fog(p, color, rate, sz)
	return p
end

local function bossLabel(key)
	return "босс " .. ({ Easy = "ЛЁГКОЙ", Medium = "СРЕДНЕЙ", Hard = "СЛОЖНОЙ" })[key]
end

local function coinsText()
	local lines = {}
	for _, key in ipairs(Config.Halloween.Difficulties) do
		lines[#lines + 1] = Config.Difficulties[key].Name .. " — " .. (Config.Halloween.Coins[key] or 0) .. " 🎃"
	end
	lines[#lines + 1] = "только за победу"
	return table.concat(lines, "\n")
end

------------------------------------------------------------------------
-- ВОРОТА В ЛОББИ
------------------------------------------------------------------------
function HW.BuildGate(lobby)
	local z = Config.Lobby.Zones.HalloweenPortal
	if not lobby or not z or lobby:FindFirstChild("HalloweenGate") then
		return lobby and lobby:FindFirstChild("HalloweenGate")
	end
	local gate = Instance.new("Model")
	gate.Name = "HalloweenGate"
	local zc = Config.Lobby.Center + z.Offset
	local out = outDir(z.Offset)
	local pc = zc + out * 9
	local face = CFrame.lookAt(pc, pc - out) -- лицом к центру лобби
	local R = 13
	for i = 0, 19 do
		local a = i / 20 * math.pi * 2
		local cf = face * CF(math.cos(a) * R, R + 1 + math.sin(a) * R, 0) * ANG(0, 0, a)
		block(gate, V(4, 3.4, 3), cf, i % 2 == 0 and H.Stone2 or H.Black)
		if i % 2 == 0 then
			wedge(gate, V(1.2, 2.4, 1.2), cf * CF(1.8, 0, 0) * ANG(0, 0, rad(-90)), H.Black)
		end
		if i % 5 == 0 then
			neon(gate, V(0.6, 1.4, 0.3), cf * CF(0, 0, -1.6), H.Orange)
		end
	end
	local disc = Kit.Cyl(gate, "PortalDisc", V(0.4, 23, 23), face * CF(0, R + 1, 0) * ANG(0, rad(90), 0), rgb(150, 60, 20), Enum.Material.Neon, { CanCollide = false, Transparency = 0.25 })
	light(disc, H.Orange, 50, 3)
	emitter(disc, H.Orange, { Rate = 26, Size = 0.7, SpeedMin = 2, SpeedMax = 5 })
	for i = 1, 3 do
		local s = neon(gate, V(0.7, R * 1.7, 0.6), face * CF(0, R + 1, -0.4) * ANG(0, 0, rad(i * 60)), i == 1 and H.Purple or H.Orange, { Transparency = 0.35 })
		Kit.Spin(s, -1.2 - 0.3 * i, "Z")
	end
	local slab = block(gate, V(20, 1, 6), face * CF(0, 0.5, 0), H.Stone2)
	Kit.Fog(slab, H.Fog, 3, 7)
	for sx = -1, 1, 2 do
		Kit.Pumpkin(gate, (face * CF(16 * sx, 0, 2)).Position, 2.2, true, math.atan2(-out.X, -out.Z) + math.pi)
		Kit.Pumpkin(gate, (face * CF(19 * sx, 0, -1)).Position, 1.4, true, math.atan2(-out.X, -out.Z) + math.pi + 0.5 * sx)
		Kit.LanternPost(gate, (face * CF(12 * sx, 0, 5)).Position, 9)
	end
	-- вывеска лицом к лобби (в legacy была развёрнута текстом от игроков)
	Kit.Sign(gate, face * CF(0, 2 * R + 7, 0), V(30, 7, 1), "HALLOWEEN EVENT", "🎃 остров, кейс, боссы и Halloween Coins", H.Orange, H.Orange)
	for i = 1, 3 do
		Kit.Bat(gate, zc + V(0, 22 + 3 * i, 0), 8 + 3 * i, 0.6 + 0.2 * i)
	end
	Kit.Calm(gate)
	gate.Parent = lobby
	return gate
end

------------------------------------------------------------------------
-- ОСТРОВ
------------------------------------------------------------------------
local function castle(m, c)
	local cz = c + V(0, 0, -90)
	block(m, V(46, 22, 16), CF(cz + V(0, 11, 0)), H.Stone2, nil, { Name = "Hall" })
	block(m, V(48, 1.5, 18), CF(cz + V(0, 22.7, 0)), H.Stone)
	for i = -5, 5 do
		block(m, V(2.4, 2.4, 2), CF(cz + V(4.2 * i, 24.6, -8.2)), H.Stone2)
	end
	Kit.Tower(m, cz + V(0, 0, 2), 12, 36, false)
	Kit.Tower(m, cz + V(-25, 0, 2), 9, 30, false)
	Kit.Tower(m, cz + V(25, 0, 2), 9, 30, false)
	for sx = -1, 1, 2 do
		for k = 0, 3 do
			local cf = CF(cz + V(sx * (6 + 4.5 * k), 9, -8.05))
			neon(m, V(1.6, 4, 0.1), cf, H.Window)
			wedge(m, V(1.6, 1.2, 0.12), cf * CF(0, 2.6, 0), H.Window, Enum.Material.Neon)
		end
	end
	block(m, V(8, 11, 0.6), CF(cz + V(0, 5.5, -8.3)), H.Bark, Enum.Material.Wood, { Name = "Gate" })
	neon(m, V(1, 1, 0.1), CF(cz + V(0, 7, -8.65)) * ANG(0, 0, rad(45)), H.Orange)
	Kit.Sign(m, CF(cz + V(0, 30, -9)) * ANG(0, math.pi, 0), V(26, 6, 1), "HAUNTED HOLLOW", "Хэллоуин-остров VOID TD", H.Orange, H.Burgundy)
end

local function caseStand(m, z, zc)
	local out = outDir(z.Offset)
	local sp = zc + out * 13
	local vert = ANG(0, 0, rad(90))
	Kit.Cyl(m, "CaseStand", V(2.5, 10, 10), CF(sp + V(0, 1.25, 0)) * vert, H.Black)
	Kit.Cyl(m, "CaseStandRing", V(0.3, 10.4, 10.4), CF(sp + V(0, 2.4, 0)) * vert, H.Gold, Enum.Material.Neon, { CanCollide = false })
	local CaseModels = Kit.Model("Cases")
	if CaseModels then
		local ok, built = pcall(CaseModels.Build, z.Case)
		if ok and built and built.Model then
			local cm = built.Model
			cm:ScaleTo(1.7)
			cm:PivotTo(CF(sp + V(0, 2.6, 0)) * CFrame.lookAt(V(), -out).Rotation)
			Kit.Spin(cm, 0.4, "Y")
			cm.Parent = m
		end
	end
	light(Kit.Ghost(m, V(0.5, 0.5, 0.5), sp + V(0, 6, 0), "CaseGlow"), H.Orange, 24, 2)
	local case = Config.Cases[z.Case]
	Kit.Billboard(m, sp + V(0, 13.5, 0), case and case.Name or z.Title, "🎃 " .. (case and case.Cost1 or 0) .. " Halloween Coins", H.Orange, 14)
	for i = 0, 5 do
		local a = rad(i * 60)
		Kit.Pumpkin(m, sp + V(math.cos(a) * 7.5, 0, math.sin(a) * 7.5), 1 + 0.4 * (i % 2), i % 2 == 0, a)
	end
end

local function queueArea(m, c)
	local Q = I.Queue
	local qc = c + Q.Offset
	block(m, V(30, 0.6, 22), CF(qc + V(0, 0.3, 0)), H.Black, nil, { Name = "QueueBase" })
	for i, off in ipairs(Q.Pads) do
		local p = qc + off
		neon(m, V(Q.Pad + 0.6, 0.65, Q.Pad + 0.6), CF(p + V(0, 0.33, 0)), H.Orange, { CanCollide = true })
		local pad = block(m, V(Q.Pad, 0.7, Q.Pad), CF(p + V(0, 0.36, 0)), rgb(40, 16, 10), Enum.Material.Glass, { Name = "QueuePad" .. i, Transparency = 0.15 })
		light(pad, H.Orange, 14, 1.5)
		emitter(pad, H.Orange, { Rate = 10, Size = 0.4, SpeedMin = 2, SpeedMax = 4, Spread = 15, Dir = Enum.NormalId.Top, LifeMin = 1, LifeMax = 2 })
		local beam = neon(m, V(Q.Pad - 1.4, 18, Q.Pad - 1.4), CF(p + V(0, 9, 0)), H.Orange, { Transparency = 0.9, Query = false })
		beam.CastShadow = false
	end
	for sx = -1, 1, 2 do
		block(m, V(2.4, 16, 2.4), CF(qc + V(16 * sx, 8, -12)), H.Stone2)
		Kit.Pumpkin(m, qc + V(16 * sx, 16, -12), 1.6, true, math.pi)
	end
	block(m, V(34, 2, 2.4), CF(qc + V(0, 15, -12)), H.Stone2)
	Kit.Sign(m, CF(qc + V(0, 20, -12)) * ANG(0, math.pi, 0), V(26, 6, 1), "HALLOWEEN TD",
		"встань на квадрат • до " .. Q.MaxPlayers .. " игроков • хост выбирает сложность", H.Orange, H.Orange)
	Kit.Billboard(m, qc + V(0, 7, 0), "ВХОД В БОЙ", "встань на светящийся квадрат", H.Orange, 13)
	Kit.Sign(m, CF(qc + V(24, 6, 6)) * ANG(0, rad(-90), 0) * ANG(0, math.pi, 0), V(12, 9, 0.8), "НАГРАДЫ", coinsText(), H.Gold, H.Gold)
	block(m, V(0.8, 2, 0.8), CF(qc + V(24, 1, 6)), H.Black)
end

local function eventStatues(m, c)
	local uz = c + I.Zones.HalloweenUnits.Offset
	for i, id in ipairs({ "LanternKing", "HalloweenPuppeteer", "HeadlessExecutioner", "PlagueDoctor", "PhantomKnight" }) do
		local a = rad(140 + 25 * (i - 1))
		Kit.Statue(m, id, uz + V(math.cos(a) * 15, 0, math.sin(a) * 15), uz, i == 1 and 4 or 3)
	end
end

local function bestiary(m, c)
	local EnemyModels = Kit.Model("Enemies")
	if not EnemyModels then
		return
	end
	local bz = c + I.Zones.Bestiary.Offset
	local rims = { rgb(90, 220, 120), rgb(255, 205, 70), rgb(255, 90, 80) }
	for i, key in ipairs(Config.Halloween.Difficulties) do
		local id = Config.Halloween.Bosses[key]
		local pos = bz + V(16, 0, 12 * (i - 2))
		block(m, V(7, 3, 7), CF(pos + V(0, 1.5, 0)), H.Stone2, nil, { Name = "Pedestal" })
		neon(m, V(7.4, 0.25, 7.4), CF(pos + V(0, 2.6, 0)), rims[i])
		local ok, rig = pcall(EnemyModels.Build, id)
		if ok and rig and rig.Model then
			local em = rig.Model
			em:ScaleTo(0.75)
			local base = pos + V(0, 3 + (rig.HipHeight or 3) * 0.75, 0)
			em:PivotTo(CFrame.lookAt(base, V(bz.X, base.Y, bz.Z)))
			Kit.AnchorAll(em)
			em.Name = "Bestiary_" .. id
			em.Parent = m
		end
		Kit.Billboard(m, pos + V(0, 13, 0), Config.Enemies[id] and Config.Enemies[id].Name or id, bossLabel(key), rims[i], 10)
	end
end

local function graveyard(m, c, rng)
	local g = c + V(52, 0, 44)
	for x = 0, 3 do
		for zz = 0, 2 do
			Kit.Tombstone(m, rng, g + V(6 * x - 9, 0, 7 * zz - 7), rng:NextNumber(-0.3, 0.3))
		end
	end
	Kit.Fence(m, g + V(-14, 0, -12), g + V(14, 0, -12))
	Kit.Fence(m, g + V(14, 0, -12), g + V(14, 0, 14))
	Kit.Fence(m, g + V(-14, 0, 14), g + V(14, 0, 14))
	Kit.Crow(m, g + V(14, 2.9, 2), rad(-90))
	Kit.Crow(m, g + V(-6, 2.9, -12), 0)
	Kit.GhostFigure(m, g + V(2, 2, 2), 1.1)
	fogBlock(m, V(26, 1, 24), g + V(0, 0.5, 0), GREEN_FOG, 2, 6)
end

local function pumpkinField(m, c, rng)
	local f = c + V(-50, 0, 58)
	block(m, V(30, 0.25, 20), CF(f + V(0, 0.12, 0)), rgb(40, 28, 20), Enum.Material.Ground, { CanCollide = false, Name = "Soil" })
	for x = 0, 4 do
		for zz = 0, 3 do
			local p = f + V(6 * x - 12 + rng:NextNumber(-1, 1), 0, 5 * zz - 7.5 + rng:NextNumber(-1, 1))
			Kit.Pumpkin(m, p, rng:NextNumber(0.8, 1.5), rng:NextInteger(1, 4) == 1, rng:NextNumber(0, 6))
		end
	end
	local sc = f + V(0, 0, -11)
	block(m, V(0.5, 8, 0.5), CF(sc + V(0, 4, 0)), H.Bark, Enum.Material.Wood)
	block(m, V(6, 0.5, 0.5), CF(sc + V(0, 6, 0)), H.Bark, Enum.Material.Wood)
	block(m, V(2.2, 3, 1.2), CF(sc + V(0, 5, 0)), rgb(90, 60, 40), Enum.Material.Fabric)
	Kit.Pumpkin(m, sc + V(0, 6.6, 0), 1.5, true, math.pi)
	Kit.Crow(m, sc + V(2.6, 6.3, 0), 0.4)
end

local function bridge(m, c, rng)
	local a = c + V(-96, 0, -20)
	local b = a + V(-28, 0, -6)
	local cf = CFrame.lookAt((a + b) / 2, b)
	for i = -6, 6 do
		block(m, V(5, 0.4, 1.8), cf * CF(0, -0.1 + 0.08 * math.abs(i), 2.1 * i), H.Bark, Enum.Material.WoodPlanks)
	end
	for sx = -1, 1, 2 do
		block(m, V(0.2, 0.2, 28), cf * CF(2.4 * sx, 1.6, 0), H.Bark, Enum.Material.Wood, { CanCollide = false })
	end
	local isl = b + V(-8, 0, -2)
	cylY(m, "Islet", 12, 4, isl - V(0, 2, 0), H.Ground)
	cylY(m, "IsletRock", 8, 12, isl - V(0, 10, 0), H.Rock)
	Kit.Tower(m, isl, 7, 14, true, rng)
	Kit.RuneCircle(m, isl + V(0, 0, 8), 4, H.Rune)
end

local function returnPortal(m, c)
	local z = I.Zones.ReturnPortal
	local zc = c + z.Offset
	local face = CFrame.lookAt(zc + V(0, 0, 8), zc)
	for i = 0, 11 do
		local a = i / 12 * math.pi * 2
		block(m, V(2.6, 2.2, 1.8), face * CF(7 * math.cos(a), 8 + 7 * math.sin(a), 0) * ANG(0, 0, a), i % 2 == 0 and H.Stone or H.Stone2)
	end
	local disc = Kit.Cyl(m, "ReturnDisc", V(0.4, 12, 12), face * CF(0, 8, 0) * ANG(0, rad(90), 0), rgb(120, 40, 210), Enum.Material.Neon, { CanCollide = false, Transparency = 0.25 })
	light(disc, rgb(170, 80, 255), 24, 2)
end

function HW.BuildIsland()
	local existing = workspace:FindFirstChild("VoidTDHalloween")
	if existing then
		return existing
	end
	local rng = Random.new(1031)
	local c = I.Center
	local m = Instance.new("Model")
	m.Name = "VoidTDHalloween"
	Kit.IslandDisc(m, c, I.Radius, rng, false)
	Kit.Patches(m, c, I.Radius, rng, 14, false)
	local moon = Kit.Ball(m, "Moon", 70, c + V(-40, 150, -330), H.Moon)
	light(moon, H.Moon, 60, 1)
	Kit.Ball(m, "MoonShade", 68, c + V(-22, 156, -318), rgb(20, 12, 28), Enum.Material.SmoothPlastic, { Transparency = 0.25 })
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2
		fogBlock(m, V(30, 1, 30), c + V(math.cos(a) * 55, 0.5, math.sin(a) * 55), H.Fog, 1.5, 9)
	end
	castle(m, c)
	Kit.Tower(m, c + V(-78, 0, -48), 8, 18, true, rng)
	Kit.Tower(m, c + V(80, 0, -44), 8, 22, true, rng)
	local zones = Instance.new("Folder")
	zones.Name = "Zones"
	zones.Parent = m
	local taken = { c + V(0, 0, 70), c + I.Queue.Offset }
	for key, z in pairs(I.Zones) do
		local zc = c + z.Offset
		local sub = z.Case and ((Config.Cases[z.Case] and Config.Cases[z.Case].Cost1 or 0) .. " 🎃 Halloween Coins") or nil
		Kit.ZoneCircle(zones, key, z, zc, sub, rgb(30, 14, 18))
		taken[#taken + 1] = zc
	end
	caseStand(m, I.Zones.Case_Halloween, c + I.Zones.Case_Halloween.Offset)
	queueArea(m, c)
	eventStatues(m, c)
	bestiary(m, c)
	graveyard(m, c, rng)
	pumpkinField(m, c, rng)
	Kit.House(m, c + V(-80, 0, 0), rad(80), 1)
	Kit.House(m, c + V(78, 0, 8), rad(-85), 0.9)
	bridge(m, c, rng)
	for _ = 1, 26 do
		local a, d = rng:NextNumber(0, math.pi * 2), rng:NextNumber(70, 94)
		local p = c + V(math.cos(a) * d, 0, math.sin(a) * d)
		local ok = p.Z > c.Z - 70
		for _, q in ipairs(taken) do
			if not ok then
				break
			end
			ok = flat(p, q) >= 15
		end
		if ok then
			taken[#taken + 1] = p
			Kit.DeadTree(m, rng, p, rng:NextNumber(0.9, 1.3))
		end
	end
	for i = 0, 9 do
		local a = i / 10 * math.pi * 2 + 0.2
		Kit.LanternPost(m, c + V(math.cos(a) * 34, 0, math.sin(a) * 34), 7)
	end
	Kit.GhostFigure(m, c + V(-30, 3, -40), 1.3)
	Kit.GhostFigure(m, c + V(36, 4, -60), 1)
	Kit.GhostFigure(m, c + V(-70, 2, 30), 0.9)
	for _ = 1, 6 do
		local p = c + V(rng:NextNumber(-60, 60), rng:NextNumber(26, 40), rng:NextNumber(-70, 40))
		Kit.Bat(m, p, rng:NextNumber(8, 18), rng:NextNumber(0.5, 1.2))
	end
	Kit.RuneCircle(m, c + V(0, 0, 18), 8, H.Rune)
	Kit.RuneCircle(m, c + V(-20, 0, -64), 5, H.Orange)
	block(m, V(10, 1, 10), CF(I.Spawn + V(0, 0.5, 0)), rgb(60, 26, 20), nil, { Name = "ArrivalPad" })
	cylY(m, "SpawnGlow", 4.6, 0.08, I.Spawn + V(0, 1.03, 0), H.Orange, Enum.Material.Neon, { CanCollide = false, Transparency = 0.5 })
	returnPortal(m, c)
	m.WorldPivot = CF(c)
	Kit.Calm(m)
	m.Parent = workspace
	return m
end

------------------------------------------------------------------------
-- КАРТА HAUNTED HOLLOW
------------------------------------------------------------------------
local function mapPortal(map, pts)
	local m = Instance.new("Model")
	m.Name = "VoidPortal"
	local start = pts[1]
	local dir = (pts[2] - start).Unit
	local R = 10
	local center = start - dir * 4 + V(0, R + 1, 0)
	local face = CFrame.lookAt(center, center + dir)
	for i = 0, 17 do
		local a = i / 18 * math.pi * 2
		local cf = face * CF(math.cos(a) * R, math.sin(a) * R, 0) * ANG(0, 0, a)
		block(m, V(3.4, 3, 2.6), cf, i % 2 == 0 and H.Stone2 or H.Black)
		if i % 3 == 0 then
			wedge(m, V(1, 2.2, 1), cf * CF(1.6, 0, 0) * ANG(0, 0, rad(-90)), H.Bone, Enum.Material.SmoothPlastic)
		end
	end
	local disc = Kit.Cyl(m, "PortalDisc", V(0.4, 17.6, 17.6), face * ANG(0, rad(90), 0), rgb(140, 50, 20), Enum.Material.Neon, { CanCollide = false, Transparency = 0.2 })
	local core = neon(m, V(2, 2, 2), face * CF(0, 0, -0.3) * ANG(rad(45), rad(45), 0), H.Orange, { Name = "PortalCore" })
	light(core, H.Orange, 40, 3)
	emitter(disc, H.Ember, { Rate = 26, Size = 0.7, SpeedMin = 2, SpeedMax = 5 })
	Kit.Fog(disc, H.Fog, 3, 6)
	for i = 1, 3 do
		local s = neon(m, V(0.6, 16, 0.7), face * ANG(0, 0, rad(i * 60)) * CF(0, 0, -0.4), i == 1 and H.Purple or H.Orange, { Transparency = 0.35 })
		Kit.Spin(s, -1.4 - 0.3 * i, "Z")
	end
	m.Parent = map
end

local function mapCore(map, pts)
	local m = Instance.new("Model")
	m.Name = "VoidCore"
	local pos = pts[#pts]
	cylY(m, "CoreBase", 9, 1.5, pos + V(0, 0.75, 0), H.Stone2)
	cylY(m, "CoreRing", 9.4, 0.4, pos + V(0, 1.6, 0), H.Gold, Enum.Material.Neon, { CanCollide = false })
	for k = 0, 3 do
		local a = rad(45 + 90 * k)
		local p = pos + V(math.cos(a) * 6.5, 0, math.sin(a) * 6.5)
		block(m, V(1.6, 14, 1.6), CF(p + V(0, 7, 0)), H.Black, Enum.Material.Metal)
		Kit.Pumpkin(m, p + V(0, 14, 0), 1.3, true, a)
	end
	block(m, V(10, 1, 10), CF(pos + V(0, 14.5, 0)) * ANG(0, rad(45), 0), H.Black, Enum.Material.Metal)
	Kit.Spire(m, CF(pos + V(0, 15, 0)), 9, 9, H.Burgundy)
	local flame = neon(m, V(4, 6, 4), CF(pos + V(0, 8, 0)) * ANG(0, rad(45), 0), H.Orange, { Name = "CoreCrystal", Transparency = 0.15 })
	Kit.Spin(flame, 0.6, "Y")
	light(flame, H.Orange, 40, 3)
	emitter(flame, H.Ember, { Rate = 20, Size = 0.6, SpeedMin = 1, SpeedMax = 3, Accel = V(0, 3, 0) })
	m:SetAttribute("CoreCenter", pos + V(0, 8, 0))
	m.Parent = map
end

local function mapDecor(map, c, road, rng)
	local f = Instance.new("Folder")
	f.Name = "Decor"
	f.Parent = map
	local pts = road.Points
	local taken = { pts[1], pts[#pts], HM.BattleSpawn }
	local hx, hz = HM.IslandSize.X / 2, HM.IslandSize.Y / 2
	local function spot(pathDist, sep, tries)
		for _ = 1, tries or 40 do
			local p = V(c.X + rng:NextNumber(-hx, hx), HM.GroundY, c.Z + rng:NextNumber(-hz, hz))
			local ok = road.DistanceToPath(p) >= pathDist and math.abs(p.X - c.X) <= hx - 6 and math.abs(p.Z - c.Z) <= hz - 6
			for _, q in ipairs(taken) do
				if not ok then
					break
				end
				ok = flat(p, q) >= sep
			end
			if ok then
				taken[#taken + 1] = p
				return p
			end
		end
		return nil
	end
	for _ = 1, 3 do
		local g = spot(16, 26)
		if g then
			for _ = 1, 6 do
				Kit.Tombstone(f, rng, g + V(rng:NextNumber(-7, 7), 0, rng:NextNumber(-7, 7)), rng:NextNumber(-0.4, 0.4))
			end
			if rng:NextInteger(1, 2) == 1 then
				Kit.Crow(f, g + V(0, 0, 0), rng:NextNumber(0, 6)) -- на земле, не в воздухе
			end
			fogBlock(f, V(16, 1, 16), g + V(0, 0.5, 0), GREEN_FOG, 1, 5)
		end
	end
	for _ = 1, 4 do
		local p = spot(12, 20)
		if p then
			for _ = 1, 7 do
				Kit.Pumpkin(f, p + V(rng:NextNumber(-6, 6), 0, rng:NextNumber(-6, 6)), rng:NextNumber(0.8, 1.6), rng:NextInteger(1, 3) == 1, rng:NextNumber(0, 6))
			end
		end
	end
	for k = 1, 3 do
		local p = spot(22, 34)
		if p then
			if k == 1 then
				Kit.Tower(f, p, 10, 26, false, rng)
			elseif k == 2 then
				Kit.House(f, p, rng:NextNumber(0, 6), 1.1)
			else
				Kit.Tower(f, p, 8, 16, true, rng)
			end
		end
	end
	for _ = 1, 30 do
		local p = spot(9, 9, 12)
		if p then
			Kit.DeadTree(f, rng, p, rng:NextNumber(0.8, 1.3))
		end
	end
	for _ = 1, 4 do
		local p = spot(10, 12, 12)
		if p then
			Kit.GhostFigure(f, p + V(0, 3, 0), rng:NextNumber(0.8, 1.2))
		end
	end
	for _ = 1, 6 do
		local p = V(c.X + rng:NextNumber(-110, 110), HM.GroundY + rng:NextNumber(24, 40), c.Z + rng:NextNumber(-90, 90))
		Kit.Bat(f, p, rng:NextNumber(8, 16), rng:NextNumber(0.5, 1.2))
	end
	for i = 0, 5 do
		fogBlock(f, V(40, 1, 40), V(c.X + 85 * (i % 3 - 1), HM.GroundY + 0.5, c.Z + (i < 3 and -50 or 50)), H.Fog, 1.2, 9)
	end
	local moon = Kit.Ball(f, "Moon", 60, c + V(60, 140, -300), H.Moon)
	light(moon, H.Moon, 60, 1)
end

function HW.BuildMap()
	local existing = workspace:FindFirstChild("VoidTDHalloweenMap")
	if existing then
		return existing
	end
	local rng = Random.new(666)
	local c = HM.Center
	local GY = HM.GroundY
	local road = Path.Get("Halloween") -- своя дорога, активная карта Path не меняется
	local pts = road.Points
	local map = Instance.new("Model")
	map.Name = "VoidTDHalloweenMap"

	local g = Instance.new("Folder")
	g.Name = "Ground"
	g.Parent = map
	local SX, SZ = HM.IslandSize.X, HM.IslandSize.Y
	local top = block(g, V(SX, 4, SZ), CF(c.X, GY - 2, c.Z), H.Ground, nil, { Name = "IslandTop" })
	top:SetAttribute("Placeable", true)
	for i = 1, 22 do
		local w, d = rng:NextNumber(14, 34), rng:NextNumber(14, 30)
		local x = rng:NextNumber(-SX / 2 + w / 2 + 2, SX / 2 - w / 2 - 2)
		local z = rng:NextNumber(-SZ / 2 + d / 2 + 2, SZ / 2 - d / 2 - 2)
		local p = Kit.Part(g, {
			Name = "Patch", Size = V(w, 0.2, d), CFrame = CF(c.X + x, GY + 0.02 + 0.004 * i, c.Z + z) * ANG(0, rad(rng:NextNumber(-20, 20)), 0),
			Color = i % 3 == 0 and H.GrassP or (i % 3 == 1 and H.Grass or H.Ground2), Material = Enum.Material.Grass, CastShadow = false,
		})
		p:SetAttribute("Placeable", true)
	end

	local u = Instance.new("Folder")
	u.Name = "Underside"
	u.Parent = map
	for i, L in ipairs({ { 0.92, 12, -9 }, { 0.72, 16, -22 }, { 0.5, 18, -38 }, { 0.28, 18, -55 } }) do
		block(u, V(SX * L[1], L[2], SZ * L[1]), CF(c.X + rng:NextNumber(-6, 6), GY + L[3], c.Z + rng:NextNumber(-6, 6)) * ANG(0, rad(rng:NextNumber(-8, 8)), 0), i % 2 == 0 and H.Rock or H.Rock2)
	end
	local function edgeRock(x, z, color)
		local s = rng:NextNumber(10, 18)
		block(u, V(s, rng:NextNumber(5, 8), s), CF(x, GY - 3.5, z) * ANG(0, rng:NextNumber(0, 2), 0), color, nil, { Name = "EdgeRock" })
	end
	for x = -SX / 2, SX / 2 - 1, 18 do
		edgeRock(c.X + x, c.Z - SZ / 2, H.Rock2)
		edgeRock(c.X + x, c.Z + SZ / 2, H.Rock2)
	end
	for z = -SZ / 2 + 18, SZ / 2 - 18, 18 do
		edgeRock(c.X - SX / 2, c.Z + z, H.Rock)
		edgeRock(c.X + SX / 2, c.Z + z, H.Rock)
	end

	local pf = Instance.new("Folder")
	pf.Name = "Path"
	pf.Parent = map
	local w = HM.PathWidth
	Kit.Road(pf, pts, GY, w, H.Road, H.RoadEdge, function(i, a, b, cf, len, dir)
		if i % 2 == 0 then
			neon(pf, V(0.35, 0.05, math.min(0.4 * len, 12)), cf * CF(rng:NextNumber(-2, 2), 0.16, 0) * ANG(0, rad(rng:NextNumber(-25, 25)), 0), H.Ember, { Name = "Crack" })
		end
		local right = V(-dir.Z, 0, dir.X)
		local steps = math.floor(len / 26)
		for s2 = 1, steps do
			local side = s2 % 2 == 0 and 1 or -1
			local p = a:Lerp(b, s2 / (steps + 1)) + right * side * (w / 2 + 2)
			Kit.LanternPost(pf, V(p.X, GY, p.Z), 6, -right * side) -- кронштейн к дороге
		end
	end)

	mapPortal(map, pts)
	mapCore(map, pts)
	mapDecor(map, c, road, rng)
	local bs = HM.BattleSpawn
	block(map, V(8, 1, 8), CF(bs.X, GY + 0.5, bs.Z), rgb(60, 26, 20), nil, { Name = "BattlePad" })
	neon(map, V(7, 0.05, 7), CF(bs.X, GY + 1.03, bs.Z), H.Orange, { Name = "BattlePadGlow", Transparency = 0.6 })
	map.WorldPivot = CF(c)
	Kit.Calm(map)
	map.Parent = workspace
	return map
end

return HW
