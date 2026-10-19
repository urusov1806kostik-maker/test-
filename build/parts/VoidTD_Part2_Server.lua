-- VOID TD — установщик, часть 2/3 (2_Server). Вставляй части по порядку 1 -> 2 -> 3.
local RS = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")
local SPS = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")
local SERVICES = { ReplicatedStorage = RS, ServerScriptService = SSS, StarterPlayerScripts = SPS }
local old = SERVICES["ServerScriptService"]:FindFirstChild("VoidTDServer")
if old then old:Destroy() end
local function ensure(parent, name, className)
	local obj = parent:FindFirstChild(name)
	if not obj then
		obj = Instance.new(className)
		obj.Name = name
		obj.Parent = parent
	end
	return obj
end

local function install(service, path, className, source)
	local parent = SERVICES[service]
	for i = 1, #path - 1 do
		parent = ensure(parent, path[i], "Folder")
	end
	local name = path[#path]
	local obj = parent:FindFirstChild(name)
	if obj and obj.ClassName ~= className then
		-- папка-заглушка, созданная для детей: заменяем на скрипт и переносим детей
		local real = Instance.new(className)
		real.Name = name
		for _, child in ipairs(obj:GetChildren()) do child.Parent = real end
		obj:Destroy()
		real.Parent = parent
		obj = real
	elseif not obj then
		obj = Instance.new(className)
		obj.Name = name
		obj.Parent = parent
	end
	obj.Source = source
	return obj
end

local FILES = {}
FILES[#FILES + 1] = { "ServerScriptService", { "VoidTDServer" }, "Script", [======[
--!nocheck
-- VOID TD :: Server bootstrap

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("VoidTD")
local Config = require(Shared:WaitForChild("Config"))

local MapBuilder = require(script:WaitForChild("MapBuilder"))
local DataService = require(script:WaitForChild("DataService"))
local GameService = require(script:WaitForChild("GameService"))
local HalloweenService = require(script:WaitForChild("HalloweenService"))

-- Remotes / State
local function folder(parent, name)
	local f = parent:FindFirstChild(name)
	if f then
		f:Destroy()
	end
	f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

local remotesFolder = folder(Shared, "Remotes")
local remotes = {}
for _, name in ipairs({ "EnemySpawn", "Sync", "Attack", "Impact", "Notify", "Profile" }) do
	local r = Instance.new("RemoteEvent")
	r.Name = name
	r.Parent = remotesFolder
	remotes[name] = r
end
local request = Instance.new("RemoteFunction")
request.Name = "Request"
request.Parent = remotesFolder
remotes.Request = request

local state = folder(Shared, "State")
local unitsFolder = folder(Shared, "Units")

local map = MapBuilder.Build()
-- Хэллоуин: остров с порталом и карта Haunted Hollow
local okH, halloweenMap = pcall(MapBuilder.BuildHalloween)
if not okH then
	warn("[VOID TD] Хэллоуин-мир не построен: " .. tostring(halloweenMap))
	halloweenMap = nil
end
GameService.Init(remotes, state, unitsFolder, map, { Void = map, Halloween = halloweenMap })
HalloweenService.Init(GameService, state)

local function pushProfile(player)
	local snap = DataService.Snapshot(player)
	if snap then
		remotes.Profile:FireClient(player, snap)
	end
end
GameService.OnProfileChanged = pushProfile

local function onPlayerAdded(player)
	DataService.Load(player)
	GameService.PlayerAdded(player)
	player:SetAttribute("VoidReady", true)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, p in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, p)
end

Players.PlayerRemoving:Connect(function(player)
	GameService.PlayerRemoving(player)
	DataService.Release(player)
end)

game:BindToClose(function()
	for _, p in ipairs(Players:GetPlayers()) do
		DataService.Save(p, true)
	end
	task.wait(2)
end)

-- Простое ограничение частоты запросов
local budget = {}
local function allow(player)
	local t = os.clock()
	local b = budget[player]
	if not b or t - b.Start > 1 then
		budget[player] = { Start = t, Count = 1 }
		return true
	end
	b.Count = b.Count + 1
	return b.Count <= 25
end
Players.PlayerRemoving:Connect(function(p)
	budget[p] = nil
end)

local handlers = {}

handlers.GetProfile = function(player)
	return true, DataService.Snapshot(player)
end

handlers.GetEnemies = function()
	return true, GameService.GetEnemySnapshot()
end

handlers.Place = function(player, data)
	if type(data) ~= "table" then
		return false, "Неверный запрос"
	end
	return GameService.PlaceUnit(player, data.Unit, data.Position, data.Rotation)
end

handlers.Upgrade = function(player, data)
	return GameService.UpgradeUnit(player, type(data) == "table" and data.Uid or data)
end

handlers.Sell = function(player, data)
	return GameService.SellUnit(player, type(data) == "table" and data.Uid or data)
end

handlers.SetTarget = function(player, data)
	if type(data) ~= "table" then
		return false, "Неверный запрос"
	end
	return GameService.SetTargetMode(player, data.Uid, data.Mode)
end

handlers.JoinMatch = function(player, data)
	return GameService.JoinMatch(player, type(data) == "table" and data.Difficulty or nil)
end

handlers.LeaveMatch = function(player)
	return GameService.LeaveMatch(player)
end

handlers.GetMatchInfo = function()
	return true, GameService.GetMatchInfo()
end

handlers.SetLite = function(player, data)
	local prof = DataService.Get(player)
	prof.Settings = prof.Settings or {}
	prof.Settings.Lite = type(data) == "table" and data.On == true
	DataService.Save(player)
	return true
end

handlers.ClaimDaily = function(player)
	local ok, res = DataService.ClaimDaily(player)
	if ok then
		pushProfile(player)
	end
	return ok, res
end

handlers.BuyGems = function(player, data)
	local key = type(data) == "table" and data.Key
	local item
	for _, it in ipairs(Config.Shop) do
		if it.Key == key then
			item = it
		end
	end
	if not item then
		return false, "Неизвестный товар"
	end
	if (item.ProductId or 0) > 0 then
		MarketplaceService:PromptProductPurchase(player, item.ProductId)
		return true, "prompt"
	end
	if Config.Settings.ShopTestMode and RunService:IsStudio() then
		DataService.GrantPurchase(player, item.Gems, nil)
		pushProfile(player)
		return true, item.Gems
	end
	return false, "Товар не настроен: укажи ProductId в Config.Shop"
end

handlers.StartWave = function(player)
	return GameService.RequestStartWave(player)
end

handlers.Summon = function(player, data)
	local count = (type(data) == "table" and data.Count == 10) and 10 or 1
	local caseId = type(data) == "table" and data.Case or "VoidCase"
	local ok, result = DataService.Summon(player, caseId, count)
	if ok then
		pushProfile(player)
	end
	return ok, result
end

handlers.EquipRune = function(player, data)
	if type(data) ~= "table" or type(data.Unit) ~= "string" then
		return false, "Неверный запрос"
	end
	local runeId = type(data.Rune) == "string" and data.Rune or nil
	local ok, err = DataService.EquipRune(player, data.Unit, runeId)
	if ok then
		pushProfile(player)
	end
	return ok, err
end

handlers.Teleport = function(player, data)
	return HalloweenService.Teleport(player, type(data) == "table" and data.To or nil)
end

handlers.QueueDifficulty = function(player, data)
	return HalloweenService.SetDifficulty(player, type(data) == "table" and data.Difficulty or nil)
end

handlers.QueueStart = function(player)
	return HalloweenService.StartNow(player)
end

handlers.QueueLeave = function(player)
	return HalloweenService.Leave(player)
end

handlers.Equip = function(player, data)
	if type(data) ~= "table" then
		return false, "Неверный запрос"
	end
	local ok, err = DataService.Equip(player, data.Unit, data.Slot)
	if ok then
		pushProfile(player)
	end
	return ok, err
end

request.OnServerInvoke = function(player, action, data)
	if not allow(player) then
		return false, "Слишком много запросов"
	end
	if not DataService.Get(player) then
		return false, "Профиль ещё загружается"
	end
	local h = handlers[action]
	if not h then
		return false, "Неизвестное действие"
	end
	local ok, a, b = pcall(h, player, data)
	if not ok then
		warn("[VOID TD] Ошибка обработки " .. tostring(action) .. ": " .. tostring(a))
		return false, "Ошибка сервера"
	end
	return a, b
end

-- Покупки за Robux (Developer Products из Config.Shop)
MarketplaceService.ProcessReceipt = function(info)
	local player = Players:GetPlayerByUserId(info.PlayerId)
	if not player or not DataService.Get(player) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	for _, it in ipairs(Config.Shop) do
		if it.ProductId == info.ProductId then
			DataService.GrantPurchase(player, it.Gems, info.PurchaseId)
			pushProfile(player)
			remotes.Notify:FireClient(player, { Type = "Purchase", Gems = it.Gems })
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
	end
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

-- Гемы меняются от наград за волны — периодически отправляем профиль
task.spawn(function()
	while true do
		task.wait(5)
		for _, p in ipairs(Players:GetPlayers()) do
			local prof = DataService.Get(p)
			if prof and (p:GetAttribute("LastGems") ~= prof.Gems or p:GetAttribute("LastCoins") ~= prof.HalloweenCoins) then
				p:SetAttribute("LastGems", prof.Gems)
				p:SetAttribute("LastCoins", prof.HalloweenCoins)
				pushProfile(p)
				DataService.Save(p)
			end
		end
	end
end)

print("[VOID TD] Сервер запущен. Карта: " .. Config.Map.Name)
]======] }
FILES[#FILES + 1] = { "ServerScriptService", { "VoidTDServer", "MapBuilder" }, "ModuleScript", [======[
--!nocheck
-- VOID TD :: MapBuilder
-- Строит карту "The Forgotten Realm" программно. Повторный вызов ничего не дублирует.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("VoidTD")
local Config = require(Shared:WaitForChild("Config"))
local PathUtil = require(Shared:WaitForChild("PathUtil"))

local MapBuilder = {}

local V = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles
local rad = math.rad

local GY = Config.Map.GroundY

local C = {
	Ground = Color3.fromRGB(38, 34, 48),
	Ground2 = Color3.fromRGB(46, 38, 60),
	Moss = Color3.fromRGB(52, 34, 72),
	Rock = Color3.fromRGB(30, 27, 38),
	Rock2 = Color3.fromRGB(44, 40, 54),
	Path = Color3.fromRGB(72, 64, 84),
	PathEdge = Color3.fromRGB(56, 50, 66),
	Stone = Color3.fromRGB(88, 84, 98),
	Stone2 = Color3.fromRGB(64, 60, 74),
	Neon = Color3.fromRGB(170, 70, 255),
	NeonPink = Color3.fromRGB(255, 70, 180),
	NeonSoft = Color3.fromRGB(210, 150, 255),
	Bark = Color3.fromRGB(28, 22, 30),
	Leaf = Color3.fromRGB(46, 22, 64),
	Leaf2 = Color3.fromRGB(30, 16, 44),
	Black = Color3.fromRGB(12, 8, 18),
}

local function part(parent, props)
	local p = Instance.new(props.Class or "Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = props.Material or Enum.Material.SmoothPlastic
	p.Color = props.Color or C.Ground
	p.Size = props.Size or V(4, 4, 4)
	if props.Shape then
		p.Shape = props.Shape
	end
	p.CFrame = props.CFrame or CF()
	p.Transparency = props.Transparency or 0
	p.CanCollide = props.CanCollide ~= false
	p.CastShadow = props.CastShadow ~= false
	p.Name = props.Name or "Part"
	if props.Material == Enum.Material.Neon then
		p.CastShadow = false
	end
	p.Parent = parent
	return p
end

local function light(p, color, range, brightness)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Shadows = false
	l.Parent = p
	return l
end

local function emitter(p, color, o)
	o = o or {}
	local e = Instance.new("ParticleEmitter")
	e.Color = ColorSequence.new(color)
	e.LightEmission = 1
	e.LightInfluence = 0
	e.Rate = o.Rate or 10
	e.Lifetime = NumberRange.new(o.LifeMin or 1, o.LifeMax or 2)
	e.Speed = NumberRange.new(o.SpeedMin or 1, o.SpeedMax or 3)
	e.SpreadAngle = Vector2.new(o.Spread or 180, o.Spread or 180)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, o.Size or 0.5), NumberSequenceKeypoint.new(1, 0) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	if o.Accel then
		e.Acceleration = o.Accel
	end
	if o.Dir then
		e.EmissionDirection = o.Dir
	end
	e.Parent = p
	return e
end

------------------------------------------------------------------------
-- ОСВЕЩЕНИЕ
------------------------------------------------------------------------
local function setupLighting()
	Lighting.ClockTime = 0.2
	Lighting.Brightness = 2
	Lighting.Ambient = Color3.fromRGB(58, 40, 86)
	Lighting.OutdoorAmbient = Color3.fromRGB(86, 64, 120)
	Lighting.ColorShift_Top = Color3.fromRGB(120, 80, 200)
	Lighting.EnvironmentDiffuseScale = 0.4
	Lighting.EnvironmentSpecularScale = 0.6
	Lighting.GlobalShadows = true
	Lighting.FogColor = Color3.fromRGB(40, 20, 70)
	Lighting.FogStart = 150
	Lighting.FogEnd = 900
	pcall(function()
		Lighting.Technology = Enum.Technology.Future
	end)

	for _, name in ipairs({ "VoidAtmosphere", "VoidBloom", "VoidColor", "VoidSky", "VoidRays" }) do
		local old = Lighting:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end
	for _, child in ipairs(Lighting:GetChildren()) do
		if child:IsA("Atmosphere") or child:IsA("Sky") then
			child:Destroy()
		end
	end

	local atmo = Instance.new("Atmosphere")
	atmo.Name = "VoidAtmosphere"
	atmo.Density = 0.38
	atmo.Offset = 0.15
	atmo.Color = Color3.fromRGB(110, 60, 170)
	atmo.Decay = Color3.fromRGB(40, 10, 60)
	atmo.Glare = 0.3
	atmo.Haze = 2.2
	atmo.Parent = Lighting

	local sky = Instance.new("Sky")
	sky.Name = "VoidSky"
	sky.StarCount = 5000
	sky.CelestialBodiesShown = true
	sky.MoonAngularSize = 18
	sky.Parent = Lighting

	local bloom = Instance.new("BloomEffect")
	bloom.Name = "VoidBloom"
	bloom.Intensity = 0.35
	bloom.Size = 18
	bloom.Threshold = 1.4
	bloom.Parent = Lighting

	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "VoidColor"
	cc.Brightness = 0.02
	cc.Contrast = 0.12
	cc.Saturation = 0.12
	cc.TintColor = Color3.fromRGB(240, 225, 255)
	cc.Parent = Lighting
end

------------------------------------------------------------------------
-- ОСТРОВ
------------------------------------------------------------------------
local function buildIsland(map, rng)
	local ground = Instance.new("Folder")
	ground.Name = "Ground"
	ground.Parent = map

	local size = Config.Map.IslandSize
	local top = part(ground, {
		Name = "IslandTop",
		Size = V(size.X, 4, size.Y),
		CFrame = CF(0, GY - 2, 0),
		Color = C.Ground,
		Material = Enum.Material.Slate,
	})
	top:SetAttribute("Placeable", true)

	-- цветные пятна мха на поверхности
	for i = 1, 18 do
		local w, d = rng:NextNumber(14, 34), rng:NextNumber(14, 30)
		local x = rng:NextNumber(-size.X / 2 + w / 2 + 2, size.X / 2 - w / 2 - 2)
		local z = rng:NextNumber(-size.Y / 2 + d / 2 + 2, size.Y / 2 - d / 2 - 2)
		local patch = part(ground, {
			Name = "Moss",
			Size = V(w, 0.2, d),
			CFrame = CF(x, GY + 0.02 + i * 0.001, z) * ANG(0, rad(rng:NextNumber(-20, 20)), 0),
			Color = (i % 2 == 0) and C.Moss or C.Ground2,
			Material = Enum.Material.Grass,
			CastShadow = false,
		})
		patch:SetAttribute("Placeable", true)
	end

	-- неровный край острова
	local under = Instance.new("Folder")
	under.Name = "Underside"
	under.Parent = map
	local perim = {}
	for x = -size.X / 2, size.X / 2, 16 do
		perim[#perim + 1] = V(x, 0, -size.Y / 2)
		perim[#perim + 1] = V(x, 0, size.Y / 2)
	end
	for z = -size.Y / 2 + 16, size.Y / 2 - 16, 16 do
		perim[#perim + 1] = V(-size.X / 2, 0, z)
		perim[#perim + 1] = V(size.X / 2, 0, z)
	end
	for _, p in ipairs(perim) do
		local s = rng:NextNumber(10, 20)
		local h = rng:NextNumber(5, 9)
		part(under, {
			Name = "EdgeRock",
			Size = V(s, h, s * rng:NextNumber(0.7, 1.2)),
			CFrame = CF(p.X, GY - h / 2 + rng:NextNumber(-1.5, 0.2), p.Z) * ANG(rad(rng:NextNumber(-6, 6)), rad(rng:NextNumber(0, 90)), rad(rng:NextNumber(-6, 6))),
			Color = (rng:NextInteger(1, 2) == 1) and C.Rock or C.Rock2,
			Material = Enum.Material.Slate,
		})
	end

	-- каменное "дно" острова, сужается вниз
	local layers = {
		{ 0.92, 12, -9 },
		{ 0.75, 16, -22 },
		{ 0.55, 18, -38 },
		{ 0.32, 20, -55 },
		{ 0.14, 18, -72 },
	}
	for i, l in ipairs(layers) do
		part(under, {
			Name = "Bedrock" .. i,
			Size = V(size.X * l[1], l[2], size.Y * l[1]),
			CFrame = CF(rng:NextNumber(-6, 6), GY + l[3], rng:NextNumber(-6, 6)) * ANG(0, rad(rng:NextNumber(-8, 8)), 0),
			Color = (i % 2 == 0) and C.Rock or C.Rock2,
			Material = Enum.Material.Slate,
		})
		-- светящиеся жилы в камне
		if i <= 4 then
			local vein = part(under, {
				Name = "Vein",
				Size = V(size.X * l[1] * 0.6, 0.6, 0.6),
				CFrame = CF(0, GY + l[3] + rng:NextNumber(-3, 3), -size.Y * l[1] / 2 - 0.1) * ANG(0, 0, rad(rng:NextNumber(-12, 12))),
				Color = C.Neon,
				Material = Enum.Material.Neon,
			})
			vein.CanCollide = false
		end
	end
	local tip = part(under, {
		Name = "Crystal Root",
		Size = V(10, 22, 10),
		CFrame = CF(0, GY - 92, 0) * ANG(rad(8), rad(45), 0),
		Color = C.Neon,
		Material = Enum.Material.Neon,
	})
	light(tip, C.Neon, 40, 3)
	return ground
end

------------------------------------------------------------------------
-- ДОРОГА
------------------------------------------------------------------------
local function buildPath(map, rng)
	local folder = Instance.new("Folder")
	folder.Name = "Path"
	folder.Parent = map
	local pts = PathUtil.Points
	local w = Config.Map.PathWidth
	for i = 2, #pts do
		local a, b = pts[i - 1], pts[i]
		local len = (b - a).Magnitude
		local mid = (a + b) / 2
		local cf = CFrame.lookAt(V(mid.X, GY + 0.15, mid.Z), V(b.X, GY + 0.15, b.Z))
		part(folder, {
			Name = "Road",
			Size = V(w, 0.3, len + w),
			CFrame = cf,
			Color = C.Path,
			Material = Enum.Material.Cobblestone,
		})
		part(folder, {
			Name = "RoadEdge",
			Size = V(w + 1.6, 0.22, len + w + 1.6),
			CFrame = cf * CF(0, -0.06, 0),
			Color = C.PathEdge,
			Material = Enum.Material.Slate,
		})
		-- разбросанные камни по краям дороги
		local steps = math.floor(len / 14)
		for s = 1, steps do
			local t = s / (steps + 1)
			local side = (s % 2 == 0) and 1 or -1
			local pos = a:Lerp(b, t)
			local dir = (b - a).Unit
			local right = V(-dir.Z, 0, dir.X)
			local p = pos + right * side * (w / 2 + 1.2)
			local sz = rng:NextNumber(0.8, 1.6)
			part(folder, {
				Name = "Pebble",
				Size = V(sz, sz * 0.7, sz * 1.2),
				CFrame = CF(p.X, GY + sz * 0.3, p.Z) * ANG(rad(rng:NextNumber(-20, 20)), rad(rng:NextNumber(0, 180)), 0),
				Color = C.Stone2,
				Material = Enum.Material.Slate,
				CanCollide = false,
			})
		end
		-- фиолетовые трещины на дороге
		if i % 2 == 0 then
			local p = a:Lerp(b, 0.5)
			part(folder, {
				Name = "Crack",
				Size = V(0.35, 0.05, math.min(len * 0.4, 12)),
				CFrame = CF(p.X + rng:NextNumber(-2, 2), GY + 0.31, p.Z + rng:NextNumber(-2, 2)) * CFrame.lookAt(Vector3.zero, b - a).Rotation * ANG(0, rad(rng:NextNumber(-25, 25)), 0),
				Color = C.Neon,
				Material = Enum.Material.Neon,
				CanCollide = false,
			})
		end
	end
	return folder
end

------------------------------------------------------------------------
-- ПОРТАЛ
------------------------------------------------------------------------
local function buildPortal(map, rng)
	local m = Instance.new("Model")
	m.Name = "VoidPortal"
	m.Parent = map
	local start = PathUtil.Points[1]
	local dir = (PathUtil.Points[2] - start).Unit
	local R = 10
	local center = start - dir * 4 + V(0, R + 1, 0)
	local base = CFrame.lookAt(center, center + dir)

	-- ступени-платформа
	part(m, { Name = "Base", Size = V(26, 1.2, 12), CFrame = CF(start.X - dir.X * 4, GY + 0.4, start.Z - dir.Z * 4) * base.Rotation, Color = C.Stone2, Material = Enum.Material.Slate })
	part(m, { Name = "Base2", Size = V(22, 1.2, 9), CFrame = CF(start.X - dir.X * 4, GY + 1.2, start.Z - dir.Z * 4) * base.Rotation, Color = C.Stone, Material = Enum.Material.Slate })

	-- каменное кольцо из блоков
	local n = 18
	for i = 0, n - 1 do
		local a = i / n * math.pi * 2
		if i ~= 4 then -- один камень выпал
			local off = V(math.cos(a) * R, math.sin(a) * R, 0)
			local jitter = rng:NextNumber(-0.4, 0.4)
			part(m, {
				Name = "RingStone",
				Size = V(3.6, 3.2 + jitter, 3),
				CFrame = base * CF(off) * ANG(0, 0, a + rad(rng:NextNumber(-4, 4))),
				Color = (i % 3 == 0) and C.Stone or C.Stone2,
				Material = Enum.Material.Slate,
			})
			if i % 3 == 0 then
				part(m, {
					Name = "Rune",
					Size = V(0.6, 1.4, 0.3),
					CFrame = base * CF(off * 1.0) * ANG(0, 0, a) * CF(0, 0, -1.55),
					Color = C.Neon,
					Material = Enum.Material.Neon,
					CanCollide = false,
				})
			end
		end
	end
	-- обломок, упавший с кольца
	part(m, { Name = "Fallen", Size = V(3.4, 2.8, 3), CFrame = CF(center.X + 6, GY + 1.4, center.Z + 9) * ANG(rad(20), rad(30), rad(10)), Color = C.Stone2, Material = Enum.Material.Slate })

	-- воронка портала
	local disc = part(m, {
		Name = "PortalDisc",
		Shape = Enum.PartType.Cylinder,
		Size = V(0.4, R * 2 - 2.5, R * 2 - 2.5),
		CFrame = base * ANG(0, rad(90), 0),
		Color = Color3.fromRGB(110, 30, 190),
		Material = Enum.Material.Neon,
		Transparency = 0.15,
		CanCollide = false,
	})
	local inner = part(m, {
		Name = "PortalCore",
		Shape = Enum.PartType.Cylinder,
		Size = V(0.5, R * 1.1, R * 1.1),
		CFrame = base * ANG(0, rad(90), 0),
		Color = Color3.fromRGB(15, 0, 30),
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
	for i = 0, 2 do
		local swirl = part(m, {
			Name = "Swirl",
			Size = V(0.6, R * 1.6, 0.7),
			CFrame = base * ANG(0, 0, rad(i * 60)) * CF(0, 0, -0.4),
			Color = C.NeonSoft,
			Material = Enum.Material.Neon,
			Transparency = 0.35,
			CanCollide = false,
		})
		swirl:SetAttribute("Spin", 1.6 + i * 0.4)
		swirl:SetAttribute("SpinAxis", "Z")
	end
	light(inner, C.Neon, 45, 4)
	emitter(disc, C.Neon, { Rate = 40, Size = 0.8, SpeedMin = 2, SpeedMax = 6, LifeMin = 1, LifeMax = 2 })
	return m, center
end

------------------------------------------------------------------------
-- ЯДРО ПУСТОТЫ
------------------------------------------------------------------------
local function buildCore(map, rng)
	local m = Instance.new("Model")
	m.Name = "VoidCore"
	m.Parent = map
	local pos = PathUtil.Points[#PathUtil.Points]
	local c = V(pos.X, GY, pos.Z)

	part(m, { Name = "Plinth1", Shape = Enum.PartType.Cylinder, Size = V(1.4, 30, 30), CFrame = CF(c + V(0, 0.5, 0)) * ANG(0, 0, rad(90)), Color = C.Stone2, Material = Enum.Material.Slate })
	part(m, { Name = "Plinth2", Shape = Enum.PartType.Cylinder, Size = V(1.4, 22, 22), CFrame = CF(c + V(0, 1.7, 0)) * ANG(0, 0, rad(90)), Color = C.Stone, Material = Enum.Material.Slate })
	local glowRing = part(m, { Name = "GlowRing", Shape = Enum.PartType.Cylinder, Size = V(0.2, 23, 23), CFrame = CF(c + V(0, 1.15, 0)) * ANG(0, 0, rad(90)), Color = C.Neon, Material = Enum.Material.Neon, CanCollide = false })

	-- колонны вокруг (одна сломана)
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2
		local p = c + V(math.cos(a) * 12, 0, math.sin(a) * 12)
		local h = (i == 2) and 5 or 11 + rng:NextNumber(-1, 1)
		part(m, { Name = "Pillar", Size = V(2.4, h, 2.4), CFrame = CF(p + V(0, 2.4 + h / 2, 0)) * ANG(0, a, rad(i == 4 and 4 or 0)), Color = C.Stone2, Material = Enum.Material.Slate })
		if i ~= 2 then
			local cap = part(m, { Name = "PillarGem", Size = V(1.2, 1.8, 1.2), CFrame = CF(p + V(0, 2.4 + h + 1.2, 0)) * ANG(0, rad(45), rad(45)), Color = C.Neon, Material = Enum.Material.Neon, CanCollide = false })
			cap:SetAttribute("Spin", 1.2)
			cap:SetAttribute("SpinAxis", "Y")
		end
	end

	-- главный кристалл
	local crystal = part(m, {
		Name = "CoreCrystal",
		Size = V(6, 6, 6),
		CFrame = CF(c + V(0, 13, 0)) * ANG(rad(45), 0, rad(45)),
		Color = Color3.fromRGB(190, 90, 255),
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
	crystal:SetAttribute("Spin", 0.8)
	crystal:SetAttribute("SpinAxis", "Y")
	crystal:SetAttribute("BobAmp", 1.2)
	local shell = part(m, {
		Name = "CoreShell",
		Size = V(9, 9, 9),
		CFrame = crystal.CFrame,
		Color = Color3.fromRGB(120, 60, 200),
		Material = Enum.Material.Glass,
		Transparency = 0.7,
		CanCollide = false,
	})
	shell:SetAttribute("Spin", -0.5)
	shell:SetAttribute("SpinAxis", "Y")
	shell:SetAttribute("BobAmp", 1.2)
	light(crystal, Color3.fromRGB(190, 90, 255), 50, 5)
	emitter(crystal, C.NeonSoft, { Rate = 25, Size = 0.7, SpeedMin = 2, SpeedMax = 5 })

	-- орбитальные кольца
	for k = 1, 2 do
		local ring = Instance.new("Model")
		ring.Name = "OrbitRing"
		ring.Parent = m
		local rr = 7 + k * 1.8
		local tilt = ANG(rad(k == 1 and 20 or -25), 0, rad(k == 1 and 10 or -12))
		for i = 0, 15 do
			local a = i / 16 * math.pi * 2
			part(ring, {
				Name = "Seg",
				Size = V(0.4, 0.4, 2.6),
				CFrame = CF(c + V(0, 13, 0)) * tilt * CF(math.cos(a) * rr, 0, math.sin(a) * rr) * ANG(0, -a, 0),
				Color = (k == 1) and C.Neon or C.NeonPink,
				Material = Enum.Material.Neon,
				CanCollide = false,
			})
		end
		ring:SetAttribute("Spin", k == 1 and 0.9 or -0.7)
		ring:SetAttribute("SpinAxis", "Y")
		ring.WorldPivot = CF(c + V(0, 13, 0)) * tilt
	end
	m:SetAttribute("CoreCenter", c + V(0, 13, 0))
	return m
end

------------------------------------------------------------------------
-- ДЕКОР
------------------------------------------------------------------------
local function freeSpot(rng, minPathDist, taken, minSep)
	local size = Config.Map.IslandSize
	for _ = 1, 60 do
		local p = V(rng:NextNumber(-size.X / 2 + 6, size.X / 2 - 6), GY, rng:NextNumber(-size.Y / 2 + 6, size.Y / 2 - 6))
		local ok = PathUtil.DistanceToPath(p) > minPathDist
			and PathUtil.FlatDistance(p, PathUtil.Points[1]) > 22
			and PathUtil.FlatDistance(p, PathUtil.Points[#PathUtil.Points]) > 22
			and p.Magnitude > 14
		if ok then
			for _, t in ipairs(taken) do
				if PathUtil.FlatDistance(p, t) < minSep then
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

local function crystalCluster(parent, rng, p, scale)
	local m = Instance.new("Model")
	m.Name = "CrystalCluster"
	m.Parent = parent
	local colors = { C.Neon, C.NeonSoft, C.NeonPink }
	local count = rng:NextInteger(3, 5)
	local main
	for i = 1, count do
		local h = rng:NextNumber(2.5, 6) * scale * (i == 1 and 1.4 or 1)
		local w = h * rng:NextNumber(0.25, 0.4)
		local off = V(rng:NextNumber(-1.6, 1.6), 0, rng:NextNumber(-1.6, 1.6)) * scale
		local cr = part(m, {
			Name = "Crystal",
			Size = V(w, h, w),
			CFrame = CF(p + off + V(0, h * 0.4, 0)) * ANG(rad(rng:NextNumber(-25, 25)), rad(rng:NextNumber(0, 90)), rad(rng:NextNumber(-25, 25))),
			Color = colors[rng:NextInteger(1, (i == 1) and 1 or 3)],
			Material = Enum.Material.Neon,
		})
		if i == 1 then
			main = cr
		end
	end
	part(m, { Name = "Rock", Size = V(3.5, 1.2, 3) * scale, CFrame = CF(p + V(0, 0.4, 0)) * ANG(0, rad(rng:NextNumber(0, 90)), 0), Color = C.Rock2, Material = Enum.Material.Slate })
	light(main, C.Neon, 16 * scale, 1.6)
	return m
end

local function darkTree(parent, rng, p)
	local m = Instance.new("Model")
	m.Name = "DarkTree"
	m.Parent = parent
	local h = rng:NextNumber(9, 14)
	local lean = rad(rng:NextNumber(-8, 8))
	local trunkCF = CF(p + V(0, h / 2, 0)) * ANG(lean, rad(rng:NextNumber(0, 180)), lean * 0.5)
	part(m, { Name = "Trunk", Size = V(1.6, h, 1.6), CFrame = trunkCF, Color = C.Bark, Material = Enum.Material.Wood })
	part(m, { Name = "Root", Size = V(3.2, 1, 3.2), CFrame = CF(p + V(0, 0.4, 0)) * ANG(0, rad(rng:NextNumber(0, 90)), 0), Color = C.Bark, Material = Enum.Material.Wood })
	-- кривые ветки
	local topCF = trunkCF * CF(0, h / 2, 0)
	for i = 1, 3 do
		local a = rad(i * 120 + rng:NextNumber(-20, 20))
		local len = rng:NextNumber(3, 5)
		local branch = topCF * ANG(0, a, 0) * CF(0, -1.2 * i * 0.5, 0) * ANG(rad(55), 0, 0) * CF(0, len / 2, 0)
		part(m, { Name = "Branch", Size = V(0.7, len, 0.7), CFrame = branch, Color = C.Bark, Material = Enum.Material.Wood })
		local leaves = part(m, {
			Name = "Leaves",
			Size = V(rng:NextNumber(3.5, 5.5), rng:NextNumber(2.5, 3.5), rng:NextNumber(3.5, 5.5)),
			CFrame = branch * CF(0, len / 2 + 0.6, 0) * ANG(rad(rng:NextNumber(-15, 15)), rad(rng:NextNumber(0, 90)), 0),
			Color = (i % 2 == 0) and C.Leaf or C.Leaf2,
			Material = Enum.Material.Grass,
		})
		Instance.new("SpecialMesh", leaves).MeshType = Enum.MeshType.Sphere -- округлая листва
	end
	local crown = part(m, {
		Name = "Crown",
		Size = V(5.5, 4, 5.5),
		CFrame = topCF * CF(0, 1.4, 0) * ANG(0, rad(rng:NextNumber(0, 90)), rad(rng:NextNumber(-8, 8))),
		Color = C.Leaf,
		Material = Enum.Material.Grass,
	})
	Instance.new("SpecialMesh", crown).MeshType = Enum.MeshType.Sphere
	if rng:NextNumber() < 0.5 then
		local fruit = part(m, { Name = "Glow", Shape = Enum.PartType.Ball, Size = V(0.8, 0.8, 0.8), CFrame = topCF * CF(1.5, 0, -1.8), Color = C.NeonPink, Material = Enum.Material.Neon, CanCollide = false })
		light(fruit, C.NeonPink, 8, 1)
	end
	return m
end

local function ruin(parent, rng, p)
	local m = Instance.new("Model")
	m.Name = "Ruins"
	m.Parent = parent
	local rot = ANG(0, rad(rng:NextNumber(0, 180)), 0)
	local base = CF(p) * rot
	-- обломок стены с проёмом
	local cols = rng:NextInteger(3, 5)
	for x = 1, cols do
		local h = rng:NextInteger(1, 4)
		for y = 1, h do
			if not (x == 2 and y <= 2) then
				part(m, {
					Name = "Brick",
					Size = V(2.8, 1.6, 1.6),
					CFrame = base * CF((x - cols / 2) * 2.9, 0.8 + (y - 1) * 1.65, 0) * ANG(0, rad(rng:NextNumber(-4, 4)), 0),
					Color = (x + y) % 2 == 0 and C.Stone or C.Stone2,
					Material = Enum.Material.Slate,
				})
			end
		end
	end
	-- арка над проёмом
	part(m, { Name = "Lintel", Size = V(6.2, 1.2, 1.8), CFrame = base * CF((2 - cols / 2) * 2.9, 4.0, 0) * ANG(0, 0, rad(rng:NextNumber(-6, 6))), Color = C.Stone, Material = Enum.Material.Slate })
	-- разбросанные камни
	for i = 1, 4 do
		local s = rng:NextNumber(0.8, 1.8)
		part(m, {
			Name = "Rubble",
			Size = V(s * 1.6, s, s * 1.2),
			CFrame = base * CF(rng:NextNumber(-6, 6), s / 2, rng:NextNumber(1.5, 4)) * ANG(rad(rng:NextNumber(-20, 20)), rad(rng:NextNumber(0, 90)), rad(rng:NextNumber(-20, 20))),
			Color = C.Stone2,
			Material = Enum.Material.Slate,
		})
	end
	local rune = part(m, { Name = "Rune", Size = V(1, 1, 0.2), CFrame = base * CF((cols - cols / 2) * 2.9, 2.2, -0.85), Color = C.Neon, Material = Enum.Material.Neon, CanCollide = false })
	light(rune, C.Neon, 8, 1)
	return m
end

local function brokenColumn(parent, rng, p)
	local m = Instance.new("Model")
	m.Name = "BrokenColumn"
	m.Parent = parent
	local h = rng:NextNumber(4, 12)
	part(m, { Name = "Base", Size = V(4, 1, 4), CFrame = CF(p + V(0, 0.5, 0)), Color = C.Stone2, Material = Enum.Material.Slate })
	part(m, {
		Name = "Shaft",
		Shape = Enum.PartType.Cylinder,
		Size = V(h, 2.6, 2.6),
		CFrame = CF(p + V(0, 1 + h / 2, 0)) * ANG(0, 0, rad(90)) * ANG(rad(rng:NextNumber(-3, 3)), 0, 0),
		Color = C.Stone,
		Material = Enum.Material.Slate,
	})
	part(m, { Name = "Break", Size = V(2.4, 0.9, 2.4), CFrame = CF(p + V(0.3, 1 + h + 0.2, 0)) * ANG(rad(14), rad(30), rad(-10)), Color = C.Stone2, Material = Enum.Material.Slate })
	-- упавший кусок колонны
	local len = rng:NextNumber(3, 6)
	local a = rad(rng:NextNumber(0, 360))
	part(m, {
		Name = "FallenPiece",
		Shape = Enum.PartType.Cylinder,
		Size = V(len, 2.4, 2.4),
		CFrame = CF(p + V(math.cos(a) * 4, 1.2, math.sin(a) * 4)) * ANG(0, a, 0),
		Color = C.Stone2,
		Material = Enum.Material.Slate,
	})
	return m
end

local function floatingIsland(parent, rng, p, s)
	local m = Instance.new("Model")
	m.Name = "FloatingIsland"
	m.Parent = parent
	part(m, { Name = "Top", Size = V(14, 3, 12) * s, CFrame = CF(p) * ANG(0, rad(rng:NextNumber(0, 90)), 0), Color = C.Ground2, Material = Enum.Material.Slate })
	part(m, { Name = "Mid", Size = V(10, 5, 8) * s, CFrame = CF(p + V(0, -3.5 * s, 0)) * ANG(0, rad(rng:NextNumber(0, 90)), 0), Color = C.Rock, Material = Enum.Material.Slate })
	part(m, { Name = "Bottom", Size = V(5, 6, 4) * s, CFrame = CF(p + V(0, -8 * s, 0)) * ANG(rad(10), rad(rng:NextNumber(0, 90)), 0), Color = C.Rock2, Material = Enum.Material.Slate })
	crystalCluster(m, rng, p + V(0, 1.5 * s, 0), s)
	m:SetAttribute("BobAmp", rng:NextNumber(1.2, 2.5))
	m:SetAttribute("BobSpeed", rng:NextNumber(0.3, 0.6))
	m.WorldPivot = CF(p)
	return m
end

local function buildDecor(map, rng)
	local decor = Instance.new("Folder")
	decor.Name = "Decor"
	decor.Parent = map
	local taken = { V(10, GY, 10) }

	for _ = 1, 10 do
		local p = freeSpot(rng, 11, taken, 14)
		if p then
			crystalCluster(decor, rng, p, rng:NextNumber(0.9, 1.6))
		end
	end
	for _ = 1, 14 do
		local p = freeSpot(rng, 12, taken, 12)
		if p then
			darkTree(decor, rng, p)
		end
	end
	for _ = 1, 4 do
		local p = freeSpot(rng, 14, taken, 18)
		if p then
			ruin(decor, rng, p)
		end
	end
	for _ = 1, 6 do
		local p = freeSpot(rng, 11, taken, 12)
		if p then
			brokenColumn(decor, rng, p)
		end
	end

	-- парящие островки вокруг
	local sky = Instance.new("Folder")
	sky.Name = "Sky"
	sky.Parent = map
	local spots = {
		V(-170, GY + 25, -60), V(-150, GY + 40, 90), V(10, GY + 35, -150),
		V(170, GY + 20, 40), V(140, GY + 45, -120), V(-40, GY + 50, 150), V(90, GY + 30, 150),
	}
	for i, p in ipairs(spots) do
		floatingIsland(sky, rng, p, (i % 3 == 0) and 1.5 or 1)
	end
	return decor
end

------------------------------------------------------------------------
-- ЛОББИ
------------------------------------------------------------------------
local function cylinderY(parent, name, radius, height, center, color, material, props)
	local p = part(parent, {
		Name = name,
		Shape = Enum.PartType.Cylinder,
		Size = V(height, radius * 2, radius * 2),
		CFrame = CF(center) * ANG(0, 0, rad(90)),
		Color = color,
		Material = material or Enum.Material.Slate,
		CanCollide = props and props.CanCollide,
		Transparency = props and props.Transparency,
	})
	return p
end

local function billboard(parent, pos, title, subtitle, color, size)
	local anchor = part(parent, { Name = "Label", Size = V(1, 1, 1), CFrame = CF(pos), Transparency = 1, CanCollide = false })
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.new(size or 14, 0, (size or 14) * 0.4, 0)
	gui.LightInfluence = 0
	gui.MaxDistance = 250
	gui.Parent = anchor
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, subtitle and 0.65 or 1)
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.Text = title
	t.TextColor3 = color
	t.TextStrokeTransparency = 0
	t.TextStrokeColor3 = Color3.fromRGB(15, 0, 25)
	t.Parent = gui
	if subtitle then
		local st = t:Clone()
		st.Position = UDim2.fromScale(0, 0.65)
		st.Size = UDim2.fromScale(1, 0.35)
		st.Font = Enum.Font.GothamBold
		st.Text = subtitle
		st.TextColor3 = Color3.fromRGB(235, 225, 255)
		st.Parent = gui
	end
	return anchor
end

local function statue(parent, unitId, pos, lookAt, pedestalH)
	local ok, UnitModels = pcall(require, Shared:WaitForChild("UnitModels"))
	if not ok then
		return
	end
	pedestalH = pedestalH or 3
	part(parent, { Name = "Pedestal", Size = V(5, pedestalH, 5), CFrame = CF(pos + V(0, pedestalH / 2, 0)), Color = C.Stone2, Material = Enum.Material.Slate })
	part(parent, { Name = "PedestalTop", Size = V(5.6, 0.5, 5.6), CFrame = CF(pos + V(0, pedestalH + 0.25, 0)), Color = C.Stone, Material = Enum.Material.Slate })
	part(parent, { Name = "PedestalRune", Size = V(5.7, 0.25, 5.7), CFrame = CF(pos + V(0, pedestalH - 0.6, 0)), Color = C.Neon, Material = Enum.Material.Neon, CanCollide = false })
	local rig = UnitModels.Build(unitId, 5)
	local model = rig.Model
	model.Name = "Statue_" .. unitId
	local base = pos + V(0, pedestalH + 0.5 + rig.HipHeight, 0)
	model:PivotTo(CFrame.lookAt(base, V(lookAt.X, base.Y, lookAt.Z)))
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
		end
	end
	model.Parent = parent
	return model
end

local function lobbyPortal(parent, center, facing)
	local R = 9
	local base = CFrame.lookAt(center, center + facing)
	local rng = Random.new(7)
	for i = 0, 15 do
		local a = i / 16 * math.pi * 2
		local off = V(math.cos(a) * R, math.sin(a) * R, 0)
		part(parent, {
			Name = "PortalStone",
			Size = V(3.4, 3, 2.6),
			CFrame = base * CF(off) * ANG(0, 0, a + rad(rng:NextNumber(-3, 3))),
			Color = (i % 2 == 0) and C.Stone or C.Stone2,
			Material = Enum.Material.Slate,
		})
		if i % 4 == 0 then
			part(parent, { Name = "Rune", Size = V(0.6, 1.3, 0.3), CFrame = base * CF(off) * ANG(0, 0, a) * CF(0, 0, -1.35), Color = C.Neon, Material = Enum.Material.Neon, CanCollide = false })
		end
	end
	local disc = part(parent, {
		Name = "PortalDisc",
		Shape = Enum.PartType.Cylinder,
		Size = V(0.4, R * 2 - 2.4, R * 2 - 2.4),
		CFrame = base * ANG(0, rad(90), 0),
		Color = Color3.fromRGB(120, 40, 210),
		Material = Enum.Material.Neon,
		Transparency = 0.2,
		CanCollide = false,
	})
	for i = 0, 2 do
		local sw = part(parent, { Name = "Swirl", Size = V(0.6, R * 1.6, 0.7), CFrame = base * ANG(0, 0, rad(i * 60)) * CF(0, 0, -0.4), Color = C.NeonSoft, Material = Enum.Material.Neon, Transparency = 0.35, CanCollide = false })
		sw:SetAttribute("Spin", -1.4 - i * 0.3)
		sw:SetAttribute("SpinAxis", "Z")
	end
	light(disc, C.Neon, 40, 4)
	emitter(disc, C.Neon, { Rate = 30, Size = 0.7, SpeedMin = 2, SpeedMax = 5 })
end

-- Приглушённый неон по всей карте: светящиеся детали темнее, подсветка слабее
local function calm(root)
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("BasePart") and d.Material == Enum.Material.Neon then
			d.Color = d.Color:Lerp(Color3.fromRGB(14, 10, 22), 0.3)
		elseif d:IsA("PointLight") then
			d.Brightness = d.Brightness * 0.65
		end
	end
end

-- Круг-зона: встал — открылось меню (или сработал портал)
local function zoneCircle(parent, key, z, zc, subtitle, padColor)
	local zm = Instance.new("Model")
	zm.Name = key
	zm.Parent = parent
	cylinderY(zm, "PadBase", z.Radius + 1.2, 0.6, zc + V(0, 0.3, 0), C.Stone2)
	cylinderY(zm, "PadEdge", z.Radius + 0.5, 0.65, zc + V(0, 0.33, 0), z.Color, Enum.Material.Neon)
	local pad = cylinderY(zm, "Pad", z.Radius, 0.7, zc + V(0, 0.36, 0), padColor or Color3.fromRGB(25, 15, 40), Enum.Material.Glass, { Transparency = 0.15 })
	local beam = cylinderY(zm, "LightBeam", z.Radius * 0.9, 26, zc + V(0, 13, 0), z.Color, Enum.Material.Neon, { CanCollide = false, Transparency = 0.88 })
	beam.CastShadow = false
	emitter(pad, z.Color, { Rate = 14, Size = 0.5, SpeedMin = 2, SpeedMax = 4, Spread = 10, Dir = Enum.NormalId.Right, LifeMin = 1.5, LifeMax = 2.5 })
	light(pad, z.Color, 18, 2)
	billboard(zm, zc + V(0, 8.5, 0), z.Title, subtitle or (z.Teleport and "войди в портал" or "встань в круг"), z.Color, 12)
	zm:SetAttribute("Zone", key)
	return zm
end

function MapBuilder.BuildLobby()
	local existing = workspace:FindFirstChild("VoidTDLobby")
	if existing then
		return existing
	end
	local L = Config.Lobby
	local c = L.Center
	local R = L.Radius
	local rng = Random.new(4242)
	local m = Instance.new("Model")
	m.Name = "VoidTDLobby"

	-- платформа
	local top = cylinderY(m, "Floor", R, 4, c - V(0, 2, 0), C.Ground, Enum.Material.Slate)
	top:SetAttribute("Placeable", false)
	cylinderY(m, "FloorInlay", 30, 0.2, c + V(0, 0.02, 0), C.Ground2, Enum.Material.Slate, { CanCollide = false })
	cylinderY(m, "InnerRing", 30.6, 0.12, c + V(0, 0.01, 0), C.Neon, Enum.Material.Neon, { CanCollide = false, Transparency = 0.3 })
	cylinderY(m, "MidRing", 55.6, 0.1, c + V(0, 0.008, 0), C.Neon, Enum.Material.Neon, { CanCollide = false, Transparency = 0.7 })
	cylinderY(m, "MidFloor", 55, 0.11, c + V(0, 0.009, 0), C.Ground, Enum.Material.Slate, { CanCollide = false })
	cylinderY(m, "OuterRing", R - 4, 0.1, c + V(0, 0.005, 0), C.Neon, Enum.Material.Neon, { CanCollide = false, Transparency = 0.6 })
	cylinderY(m, "OuterFloor", R - 4.4, 0.12, c + V(0, 0.01, 0), C.Ground, Enum.Material.Slate, { CanCollide = false })
	-- низ острова
	for i, l in ipairs({ { 0.9, 10, -8 }, { 0.68, 14, -19 }, { 0.45, 16, -33 }, { 0.22, 16, -48 } }) do
		cylinderY(m, "Under" .. i, R * l[1], l[2], c + V(rng:NextNumber(-3, 3), l[3], rng:NextNumber(-3, 3)), (i % 2 == 0) and C.Rock or C.Rock2)
	end
	local root = part(m, { Name = "CrystalRoot", Size = V(7, 16, 7), CFrame = CF(c + V(0, -62, 0)) * ANG(rad(6), rad(45), 0), Color = C.Neon, Material = Enum.Material.Neon })
	light(root, C.Neon, 40, 3)
	-- край: камни и колонны с неоном
	for i = 0, 35 do
		local a = i / 36 * math.pi * 2
		local p = c + V(math.cos(a) * (R - 1), 0, math.sin(a) * (R - 1))
		local s = rng:NextNumber(4, 7)
		part(m, { Name = "EdgeRock", Size = V(s, rng:NextNumber(1, 2.5), s), CFrame = CF(p) * ANG(0, rad(rng:NextNumber(0, 90)), 0), Color = C.Rock2, Material = Enum.Material.Slate })
		if i % 3 == 0 then
			local h = rng:NextNumber(6, 10)
			local pil = c + V(math.cos(a) * (R - 3), 0, math.sin(a) * (R - 3))
			part(m, { Name = "Pillar", Size = V(2.2, h, 2.2), CFrame = CF(pil + V(0, h / 2, 0)) * ANG(0, a, 0), Color = C.Stone2, Material = Enum.Material.Slate })
			local gem = part(m, { Name = "PillarGem", Size = V(1, 1.6, 1), CFrame = CF(pil + V(0, h + 1.4, 0)) * ANG(0, rad(45), rad(45)), Color = C.Neon, Material = Enum.Material.Neon, CanCollide = false })
			gem:SetAttribute("Spin", 1.5)
			gem:SetAttribute("SpinAxis", "Y")
			light(gem, C.Neon, 14, 1.2)
		end
	end

	-- зоны-круги
	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = m
	for key, z in pairs(L.Zones) do
		zoneCircle(zonesFolder, key, z, c + z.Offset)
	end

	-- КЕЙСЫ: витрины с вращающимися 3D-кейсами за каждым кругом
	local okCM, CaseModels = pcall(require, Shared:WaitForChild("CaseModels"))
	for _, z in pairs(L.Zones) do
		if z.Case then
			local zc = c + z.Offset
			local out = V(z.Offset.X, 0, z.Offset.Z).Unit
			local sp = zc + out * 13
			part(m, { Name = "CaseStand", Shape = Enum.PartType.Cylinder, Size = V(2.5, 9, 9), CFrame = CF(sp + V(0, 1.25, 0)) * ANG(0, 0, rad(90)), Color = C.Stone2, Material = Enum.Material.Slate })
			part(m, { Name = "CaseStandRing", Shape = Enum.PartType.Cylinder, Size = V(0.3, 9.4, 9.4), CFrame = CF(sp + V(0, 2.4, 0)) * ANG(0, 0, rad(90)), Color = z.Color, Material = Enum.Material.Neon, CanCollide = false })
			if okCM then
				local cm = CaseModels.Build(z.Case).Model
				cm:ScaleTo(1.6)
				cm:PivotTo(CF(sp + V(0, 2.6, 0)) * CFrame.lookAt(Vector3.zero, -out).Rotation)
				cm:SetAttribute("Spin", 0.5)
				cm:SetAttribute("SpinAxis", "Y")
				cm.Parent = m
			end
			local glow = part(m, { Name = "CaseGlow", Size = V(0.5, 0.5, 0.5), CFrame = CF(sp + V(0, 6, 0)), Transparency = 1, CanCollide = false })
			light(glow, z.Color, 22, 2)
			emitter(glow, z.Color, { Rate = 8, Size = 0.4, SpeedMin = 1, SpeedMax = 2 })
			local case = Config.Cases[z.Case]
			billboard(m, sp + V(0, 13, 0), case.Name, "💎" .. case.Cost1 .. " / x10 💎" .. case.Cost10, z.Color, 14)
		end
	end

	-- ЮНИТЫ: статуи Common-героев
	local uz = c + L.Zones.Units.Offset
	statue(m, "VoidSoldier", uz + V(13, 0, -9), uz, 2.5)
	statue(m, "ShadowArcher", uz + V(15, 0, 0), uz, 2.5)
	statue(m, "LostMage", uz + V(13, 0, 9), uz, 2.5)

	-- ИГРАТЬ: портал в бой и мифические стражи
	local pz = c + L.Zones.Play.Offset
	lobbyPortal(m, pz + V(0, 10.5, -11), V(0, 0, 1))
	part(m, { Name = "PortalBase", Size = V(24, 1, 8), CFrame = CF(pz + V(0, 0.5, -11)), Color = C.Stone2, Material = Enum.Material.Slate })
	statue(m, "VoidEmperor", pz + V(-17, 0, -6), c, 4)
	statue(m, "AbyssOverlord", pz + V(17, 0, -6), c, 4)
	statue(m, "RiftMonarch", pz + V(-32, 0, 2), c, 4)
	statue(m, "LunarSeraph", pz + V(32, 0, 2), c, 4)
	-- герои у точки появления
	statue(m, "FallenAngel", c + V(-24, 0, 50), c, 3)
	statue(m, "EclipseGuardian", c + V(24, 0, 50), c, 3)
	statue(m, "Starbreaker", c + V(-42, 0, 42), c, 3)
	statue(m, "BloodfangWarlord", c + V(42, 0, 42), c, 3)
	-- секретные юниты в центре
	statue(m, "RealityDestroyer", c + V(-8, 0, 0), c + V(0, 0, 60), 5)
	statue(m, "CrimsonEclipse", c + V(8, 0, 0), c + V(0, 0, 60), 5)
	billboard(m, c + V(0, 17, 0), "SECRET", "шанс 0.1% в новых кейсах", Color3.fromRGB(255, 40, 60), 12)

	-- вывеска
	local sign = part(m, { Name = "Sign", Size = V(30, 8, 1), CFrame = CF(pz + V(0, 27, -12)) * ANG(0, math.pi, 0), Color = C.Black, Material = Enum.Material.Slate })
	part(m, { Name = "SignFrame", Size = V(31, 9, 0.6), CFrame = CF(pz + V(0, 27, -12.4)), Color = C.Neon, Material = Enum.Material.Neon, CanCollide = false })
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Front
	sg.LightInfluence = 0
	sg.PixelsPerStud = 30
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.Parent = sign
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.fromScale(1, 0.7)
	title.Font = Enum.Font.FredokaOne
	title.TextScaled = true
	title.Text = "VOID TD"
	title.TextColor3 = Color3.fromRGB(200, 120, 255)
	title.TextStrokeTransparency = 0
	title.Parent = sg
	local sub = title:Clone()
	sub.Position = UDim2.fromScale(0, 0.68)
	sub.Size = UDim2.fromScale(1, 0.28)
	sub.Font = Enum.Font.GothamBold
	sub.Text = "THE FORGOTTEN REALM"
	sub.TextColor3 = Color3.fromRGB(235, 225, 255)
	sub.Parent = sg

	-- декор
	local taken = {}
	for key, z in pairs(L.Zones) do
		taken[#taken + 1] = c + z.Offset
		if z.Case then
			taken[#taken + 1] = c + z.Offset + V(z.Offset.X, 0, z.Offset.Z).Unit * 13
		end
	end
	for _, off in ipairs({ V(-24, 0, 50), V(24, 0, 50), V(-42, 0, 42), V(42, 0, 42), V(0, 0, 0), V(77, 0, 8), V(-32, 0, -60), V(32, 0, -60), V(0, 0, -73) }) do
		taken[#taken + 1] = c + off
	end
	for i = 1, 24 do
		local a = rng:NextNumber(0, math.pi * 2)
		local d = rng:NextNumber(36, R - 8)
		local p = c + V(math.cos(a) * d, 0, math.sin(a) * d)
		local free = true
		for _, t in ipairs(taken) do
			if (V(p.X, 0, p.Z) - V(t.X, 0, t.Z)).Magnitude < 16 then
				free = false
			end
		end
		if free and (p - L.Spawn).Magnitude > 12 then
			taken[#taken + 1] = p
			if i % 2 == 0 then
				darkTree(m, rng, p)
			else
				crystalCluster(m, rng, p, rng:NextNumber(0.9, 1.4))
			end
		end
	end

	-- точка появления
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "LobbySpawn"
	spawn.Anchored = true
	spawn.Size = V(10, 1, 10)
	spawn.CFrame = CF(L.Spawn + V(0, 0.5, 0))
	spawn.Color = Color3.fromRGB(70, 40, 110)
	spawn.Material = Enum.Material.Slate
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Parent = m
	cylinderY(m, "SpawnGlow", 4.6, 0.08, L.Spawn + V(0, 1.03, 0), C.Neon, Enum.Material.Neon, { CanCollide = false, Transparency = 0.5 })

	m.WorldPivot = CF(c)
	calm(m)
	m.Parent = workspace
	return m
end

-- Хелперы для HalloweenWorld
MapBuilder.H = {
	part = part, light = light, emitter = emitter, cylinderY = cylinderY, billboard = billboard,
	statue = statue, calm = calm, zoneCircle = zoneCircle, lobbyPortal = lobbyPortal, C = C,
}

-- Хэллоуин-остров, портал в лобби и карта Haunted Hollow
function MapBuilder.BuildHalloween()
	local HalloweenWorld = require(script.Parent:WaitForChild("HalloweenWorld"))
	return HalloweenWorld.Build(MapBuilder.H)
end

------------------------------------------------------------------------
function MapBuilder.Build()
	local existing = workspace:FindFirstChild("VoidTDMap")
	if existing then
		MapBuilder.BuildLobby()
		setupLighting()
		return existing
	end
	local rng = Random.new(1337)
	local map = Instance.new("Model")
	map.Name = "VoidTDMap"

	buildIsland(map, rng)
	buildPath(map, rng)
	buildPortal(map, rng)
	buildCore(map, rng)
	buildDecor(map, rng)

	-- площадка, куда телепортирует из лобби (не SpawnLocation: появляются все в лобби)
	local bs = Config.BattleSpawn
	part(map, { Name = "BattlePad", Size = V(8, 1, 8), CFrame = CF(bs.X, GY + 0.5, bs.Z), Color = Color3.fromRGB(70, 40, 110), Material = Enum.Material.Slate })
	part(map, { Name = "BattlePadGlow", Size = V(7, 0.05, 7), CFrame = CF(bs.X, GY + 1.03, bs.Z), Color = C.Neon, Material = Enum.Material.Neon, Transparency = 0.6, CanCollide = false })

	calm(map)
	map.Parent = workspace
	MapBuilder.BuildLobby()
	setupLighting()
	return map
end

return MapBuilder
]======] }
FILES[#FILES + 1] = { "ServerScriptService", { "VoidTDServer", "DataService" }, "ModuleScript", [======[
--!nocheck
-- VOID TD :: DataService
-- Профиль игрока: гемы, инвентарь юнитов, экипировка. DataStore с безопасным фолбэком для Studio.

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("VoidTD"):WaitForChild("Config"))

local DataService = {}
DataService.Profiles = {}

local store
local storeOk = pcall(function()
	store = DataStoreService:GetDataStore(Config.Settings.DataStoreName)
end)
if not storeOk then
	store = nil
end

local function deepCopy(t)
	local c = {}
	for k, v in pairs(t) do
		c[k] = type(v) == "table" and deepCopy(v) or v
	end
	return c
end

local function defaultProfile()
	local s = Config.Settings
	local p = {
		Gems = s.StartGems,
		Inventory = {},
		Equipped = {},
		Stats = { Wins = 0, BestWave = 0, Summons = 0 },
		Settings = {},
		LastDaily = 0,
		Receipts = {},
		HalloweenCoins = 0,
		Runes = {},       -- RuneId -> количество
		RuneSlots = {},   -- UnitId -> RuneId (1 руна на юнита)
	}
	for i, id in ipairs(s.StarterUnits) do
		p.Inventory[id] = 1
		p.Equipped[i] = id
	end
	return p
end

local function sanitize(p)
	local d = defaultProfile()
	if type(p) ~= "table" then
		return d
	end
	p.Gems = tonumber(p.Gems) or d.Gems
	p.Inventory = type(p.Inventory) == "table" and p.Inventory or d.Inventory
	p.Equipped = type(p.Equipped) == "table" and p.Equipped or d.Equipped
	p.Stats = type(p.Stats) == "table" and p.Stats or d.Stats
	p.Settings = type(p.Settings) == "table" and p.Settings or {}
	p.LastDaily = tonumber(p.LastDaily) or 0
	p.Receipts = type(p.Receipts) == "table" and p.Receipts or {}
	p.HalloweenCoins = math.max(0, math.floor(tonumber(p.HalloweenCoins) or 0))
	-- руны: только известные, слоты — только у своих юнитов и не больше, чем рун есть
	local runes = {}
	if type(p.Runes) == "table" then
		for id, n in pairs(p.Runes) do
			n = math.floor(tonumber(n) or 0)
			if Config.Runes[id] and n > 0 then
				runes[id] = n
			end
		end
	end
	p.Runes = runes
	local slots, used = {}, {}
	if type(p.RuneSlots) == "table" then
		for unitId, runeId in pairs(p.RuneSlots) do
			if Config.Units[unitId] and (p.Inventory[unitId] or 0) > 0 and runes[runeId] and (used[runeId] or 0) < runes[runeId] then
				slots[unitId] = runeId
				used[runeId] = (used[runeId] or 0) + 1
			end
		end
	end
	p.RuneSlots = slots
	-- убрать неизвестные юниты
	for id in pairs(p.Inventory) do
		if not Config.Units[id] then
			p.Inventory[id] = nil
		end
	end
	local eq = {}
	for i = 1, Config.Settings.EquipSlots do
		local id = p.Equipped[i] or p.Equipped[tostring(i)]
		if id and Config.Units[id] and (p.Inventory[id] or 0) > 0 then
			eq[i] = id
		end
	end
	p.Equipped = eq
	return p
end

function DataService.Load(player)
	local profile
	if store then
		local ok, result = pcall(function()
			return store:GetAsync("u_" .. player.UserId)
		end)
		if ok then
			profile = result
		else
			warn("[VOID TD] DataStore недоступен (в Studio включи API Services). Используются данные по умолчанию.")
		end
	end
	profile = sanitize(profile and deepCopy(profile) or nil)
	-- проверка в Studio: секретные юниты из настроек сразу в инвентаре
	if RunService:IsStudio() then
		for _, id in ipairs(Config.Settings.StudioGrantUnits or {}) do
			if Config.Units[id] and (profile.Inventory[id] or 0) == 0 then
				profile.Inventory[id] = 1
			end
		end
	end
	DataService.Profiles[player] = profile
	player:SetAttribute("Gems", profile.Gems)
	player:SetAttribute("HalloweenCoins", profile.HalloweenCoins)
	return profile
end

function DataService.Get(player)
	return DataService.Profiles[player]
end

local lastSave = {}
function DataService.Save(player, force)
	local profile = DataService.Profiles[player]
	if not profile or not store then
		return
	end
	local now = os.clock()
	if not force and lastSave[player] and now - lastSave[player] < 8 then
		return
	end
	lastSave[player] = now
	local data = deepCopy(profile)
	-- ключи экипировки -> строки для JSON
	local eq = {}
	for i, id in pairs(data.Equipped) do
		eq[tostring(i)] = id
	end
	data.Equipped = eq
	task.spawn(function()
		local ok, err = pcall(function()
			store:SetAsync("u_" .. player.UserId, data)
		end)
		if not ok and not RunService:IsStudio() then
			warn("[VOID TD] Ошибка сохранения: " .. tostring(err))
		end
	end)
end

function DataService.Release(player)
	DataService.Save(player, true)
	DataService.Profiles[player] = nil
	lastSave[player] = nil
end

function DataService.AddGems(player, amount)
	local p = DataService.Profiles[player]
	if not p then
		return
	end
	p.Gems = math.max(0, p.Gems + amount)
	player:SetAttribute("Gems", p.Gems)
end

-- Публичная версия профиля для клиента
function DataService.Snapshot(player)
	local p = DataService.Profiles[player]
	if not p then
		return nil
	end
	-- ключи экипировки строками: разреженные массивы плохо переживают RemoteEvent
	local eq = {}
	for i, id in pairs(p.Equipped) do
		eq[tostring(i)] = id
	end
	return {
		Gems = p.Gems,
		Inventory = deepCopy(p.Inventory),
		Equipped = eq,
		Stats = deepCopy(p.Stats),
		Settings = deepCopy(p.Settings or {}),
		DailyReadyAt = (tonumber(p.LastDaily) or 0) + Config.Settings.DailyCooldown,
		HalloweenCoins = p.HalloweenCoins or 0,
		Runes = deepCopy(p.Runes or {}),
		RuneSlots = deepCopy(p.RuneSlots or {}),
	}
end

function DataService.AddCurrency(player, currency, amount)
	local p = DataService.Profiles[player]
	if not p then
		return
	end
	if currency == "Gems" then
		DataService.AddGems(player, amount)
		return
	end
	p[currency] = math.max(0, (p[currency] or 0) + math.floor(amount))
	player:SetAttribute(currency, p[currency])
end

------------------------------------------------------------------------
-- РУНЫ: 1 руна на юнита, снимается и переносится на другого, работает только надетой
------------------------------------------------------------------------
function DataService.GetRune(player, unitId)
	local p = DataService.Profiles[player]
	return p and p.RuneSlots and p.RuneSlots[unitId] or nil
end

local function runesUsed(p, runeId, exceptUnit)
	local n = 0
	for unitId, r in pairs(p.RuneSlots) do
		if r == runeId and unitId ~= exceptUnit then
			n = n + 1
		end
	end
	return n
end

-- runeId = nil — снять руну с юнита
function DataService.EquipRune(player, unitId, runeId)
	local p = DataService.Profiles[player]
	if not p then
		return false, "Профиль не загружен"
	end
	if not Config.Units[unitId] or (p.Inventory[unitId] or 0) <= 0 then
		return false, "Юнита нет в инвентаре"
	end
	if runeId == nil then
		p.RuneSlots[unitId] = nil
		DataService.Save(player)
		return true
	end
	if not Config.Runes[runeId] then
		return false, "Неизвестная руна"
	end
	if runesUsed(p, runeId, unitId) >= (p.Runes[runeId] or 0) then
		return false, "Все такие руны уже надеты — сними руну с другого юнита"
	end
	p.RuneSlots[unitId] = runeId
	DataService.Save(player)
	return true
end

------------------------------------------------------------------------
-- КЕЙСЫ (SUMMON)
------------------------------------------------------------------------
local rng = Random.new()

local function unitsByRarity(case)
	local map = {}
	for _, id in ipairs(case.Units) do
		local r = Config.Units[id].Rarity
		map[r] = map[r] or {}
		table.insert(map[r], id)
	end
	return map
end

-- редкость есть в розыгрыше, если в ней есть юниты без отдельного шанса (UnitRates)
local function rollable(pool, name, unitRates)
	for _, id in ipairs(pool[name] or {}) do
		if not (unitRates and unitRates[id]) then
			return true
		end
	end
	return false
end

local function rollRarity(case, pool, unitRates)
	local total = 0
	for _, name in ipairs(Config.RarityOrder) do
		if rollable(pool, name, unitRates) then
			total = total + (case.Rates[name] or 0)
		end
	end
	local roll = rng:NextNumber() * total
	local acc = 0
	for _, name in ipairs(Config.RarityOrder) do
		if rollable(pool, name, unitRates) then
			acc = acc + (case.Rates[name] or 0)
			if roll <= acc then
				return name
			end
		end
	end
	return "Common"
end

function DataService.Summon(player, caseId, count)
	local p = DataService.Profiles[player]
	if not p then
		return false, "Профиль не загружен"
	end
	local case = Config.Cases[caseId]
	if not case then
		return false, "Неизвестный кейс"
	end
	if case.Enabled == false then
		return false, "Кейс пока недоступен"
	end
	local s = Config.Settings
	count = (count == 10) and 10 or 1
	if case.Single and count ~= 1 then
		return false, "Этот кейс открывается по одному"
	end
	local cost = (count == 10) and case.Cost10 or case.Cost1
	if not cost then
		return false, "Неверный запрос"
	end
	local currency = case.Currency or "Gems"
	if (p[currency] or 0) < cost then
		return false, currency == "Gems" and "Недостаточно кристаллов" or "Недостаточно Halloween Coins"
	end
	p[currency] = p[currency] - cost
	if currency == "Gems" then
		player:SetAttribute("Gems", p.Gems)
	end
	-- кейс с полным списком наград (юниты и руны): один бросок на открытие
	if case.Rewards then
		local total = 0
		for _, r in ipairs(case.Rewards) do
			total = total + r.Rate
		end
		local roll, acc, pick = rng:NextNumber() * total, 0, case.Rewards[#case.Rewards]
		for _, r in ipairs(case.Rewards) do
			acc = acc + r.Rate
			if roll < acc then
				pick = r
				break
			end
		end
		local result
		if pick.Rune then
			local isNew = (p.Runes[pick.Rune] or 0) == 0
			p.Runes[pick.Rune] = (p.Runes[pick.Rune] or 0) + 1
			result = { Rune = pick.Rune, New = isNew }
		else
			local id = pick.Unit
			local isNew = (p.Inventory[id] or 0) == 0
			p.Inventory[id] = (p.Inventory[id] or 0) + 1
			result = { Id = id, New = isNew }
			if isNew then
				for slot = 1, s.EquipSlots do
					if not p.Equipped[slot] then
						p.Equipped[slot] = id
						break
					end
				end
			end
		end
		if currency ~= "Gems" then
			player:SetAttribute(currency, p[currency])
		end
		p.Stats.Summons = (p.Stats.Summons or 0) + 1
		DataService.Save(player, true)
		return true, { result }
	end
	local pool = unitsByRarity(case)
	local results = {}
	local bestOrder = 0
	for i = 1, count do
		-- отдельный шанс конкретных юнитов (UnitRates, в процентах), иначе — по редкостям
		local fixed
		if case.UnitRates then
			local roll, acc = rng:NextNumber() * 100, 0
			for id, rate in pairs(case.UnitRates) do
				acc = acc + rate
				if roll < acc then
					fixed = id
					break
				end
			end
		end
		local rarity = fixed and Config.Units[fixed].Rarity or rollRarity(case, pool, case.UnitRates)
		-- гарантия: в x10 минимум один Rare+
		if count == 10 and i == 10 and bestOrder < 2 and not fixed and rollable(pool, "Rare", case.UnitRates) then
			rarity = "Rare"
		end
		bestOrder = math.max(bestOrder, Config.Rarities[rarity].Order)
		local id = fixed
		if not id then
			local list = {}
			for _, u in ipairs(pool[rarity]) do
				if not (case.UnitRates and case.UnitRates[u]) then
					list[#list + 1] = u
				end
			end
			id = list[rng:NextInteger(1, #list)]
		end
		local isNew = (p.Inventory[id] or 0) == 0
		p.Inventory[id] = (p.Inventory[id] or 0) + 1
		results[i] = { Id = id, New = isNew }
		if isNew then
			for slot = 1, s.EquipSlots do
				if not p.Equipped[slot] then
					p.Equipped[slot] = id
					break
				end
			end
		end
	end
	p.Stats.Summons = (p.Stats.Summons or 0) + count
	DataService.Save(player)
	return true, results
end

------------------------------------------------------------------------
-- МАГАЗИН
------------------------------------------------------------------------
function DataService.ClaimDaily(player)
	local p = DataService.Profiles[player]
	if not p then
		return false, "Профиль не загружен"
	end
	local now = os.time()
	local last = tonumber(p.LastDaily) or 0
	local left = (last + Config.Settings.DailyCooldown) - now
	if left > 0 then
		return false, string.format("Подарок будет через %d ч %d мин", left // 3600, (left % 3600) // 60)
	end
	p.LastDaily = now
	DataService.AddGems(player, Config.Settings.DailyGems)
	DataService.Save(player, true)
	return true, Config.Settings.DailyGems
end

-- Выдача кристаллов за покупку. receiptId защищает от повторной выдачи.
function DataService.GrantPurchase(player, gems, receiptId)
	local p = DataService.Profiles[player]
	if not p then
		return false
	end
	p.Receipts = p.Receipts or {}
	if receiptId and p.Receipts[receiptId] then
		return true
	end
	if receiptId then
		p.Receipts[receiptId] = true
	end
	DataService.AddGems(player, gems)
	DataService.Save(player, true)
	return true
end

function DataService.Equip(player, unitId, slot)
	local p = DataService.Profiles[player]
	if not p then
		return false, "Профиль не загружен"
	end
	slot = tonumber(slot)
	if not slot or slot < 1 or slot > Config.Settings.EquipSlots or slot ~= math.floor(slot) then
		return false, "Неверный слот"
	end
	if unitId == nil then
		p.Equipped[slot] = nil
		return true
	end
	if not Config.Units[unitId] or (p.Inventory[unitId] or 0) <= 0 then
		return false, "Юнита нет в инвентаре"
	end
	for i = 1, Config.Settings.EquipSlots do
		if p.Equipped[i] == unitId then
			p.Equipped[i] = nil
		end
	end
	p.Equipped[slot] = unitId
	DataService.Save(player)
	return true
end

function DataService.IsEquipped(player, unitId)
	local p = DataService.Profiles[player]
	if not p then
		return false
	end
	for i = 1, Config.Settings.EquipSlots do
		if p.Equipped[i] == unitId then
			return true
		end
	end
	return false
end

return DataService
]======] }
FILES[#FILES + 1] = { "ServerScriptService", { "VoidTDServer", "GameService" }, "ModuleScript", [======[
--!nocheck
-- VOID TD :: GameService
-- Вся игровая логика на сервере: враги, волны, ядро, юниты, урон.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("VoidTD")
local Config = require(Shared:WaitForChild("Config"))
local PathUtil = require(Shared:WaitForChild("PathUtil"))
local DataService = require(script.Parent:WaitForChild("DataService"))

local S = Config.Settings

local GameService = {}

local Remotes, State, UnitsFolder, Map
local MapModels = {}
local rng = Random.new()

local enemies = {}
local nextEnemyId = 0
local units = {}
local nextUnitId = 0
local zones = {}
local damageBuffer = {}
local removedBuffer = {}
local pendingSpawns = {}

-- Фазы: Idle (никто не играет) -> Prep (расстановка до 1-й волны) -> Wave <-> Intermission -> Victory/Defeat
local phase = "Idle"
local difficultyKey = "Medium"
local D = Config.Difficulties.Medium
local wave = 0
local coreHP = S.CoreMaxHP
local matchId = 0
local waveSpawning = false
local nextWaveAt = 0
local lastSync = 0
local lastAttrFlush = 0
-- режим матча: Void (обычный) или Halloween (карта Haunted Hollow, вход только из очереди на острове)
local matchMode = "Void"
local maxWave = S.MaxWave
local roster = {}       -- участники Хэллоуин-матча (UserId -> true)
local coinsPaid = {}    -- matchId -> true: награда за победу выдана (повторно не платится)
-- союзники (призывы): идут по дороге от базы к порталу
local allies = {}
local nextAllyId = 0
local allyRemoved = {}
local allyIndex = {}
for i, id in ipairs(Config.AllyOrder or {}) do
	allyIndex[id] = i
end
local echoAttack = false -- true, пока выполняется повтор атаки «Призрачной короны»

local function now()
	return workspace:GetServerTimeNow()
end

local function setState(key, value)
	State:SetAttribute(key, value)
end

local function notifyAll(payload)
	Remotes.Notify:FireAllClients(payload)
end

local function toast(player, text, kind)
	Remotes.Notify:FireClient(player, { Type = "Toast", Text = text, Kind = kind or "error" })
end
GameService.Toast = toast

------------------------------------------------------------------------
-- ДЕНЬГИ
------------------------------------------------------------------------
local function getMoney(player)
	return player:GetAttribute("Money") or 0
end

local function setMoney(player, amount)
	amount = math.max(0, math.floor(amount))
	player:SetAttribute("Money", amount)
	local ls = player:FindFirstChild("leaderstats")
	if ls and ls:FindFirstChild("Money") then
		ls.Money.Value = amount
	end
end

local function inMatch(player)
	return player:GetAttribute("InMatch") == true
end

local function matchPlayers()
	local list = {}
	for _, pl in ipairs(Players:GetPlayers()) do
		if inMatch(pl) then
			list[#list + 1] = pl
		end
	end
	return list
end

local function addMoneyAll(amount)
	for _, pl in ipairs(matchPlayers()) do
		setMoney(pl, getMoney(pl) + amount)
	end
end

local function addGemsAll(amount)
	amount = math.floor(amount * D.Gems + 0.5)
	for _, pl in ipairs(matchPlayers()) do
		DataService.AddGems(pl, amount)
	end
	return amount
end

------------------------------------------------------------------------
-- ТЕЛЕПОРТ ЛОББИ <-> КАРТА
------------------------------------------------------------------------
local function teleport(player, pos)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if root then
		local jitter = Vector3.new(rng:NextNumber(-3, 3), 3.5, rng:NextNumber(-3, 3))
		char:PivotTo(CFrame.new(pos + jitter))
	end
end

local function toBattle(player)
	local m = Config.Maps[matchMode] or Config.Map
	teleport(player, m.BattleSpawn or Config.BattleSpawn)
end

local function toLobby(player, island)
	player:SetAttribute("Island", island == true)
	teleport(player, island and Config.HalloweenIsland.Spawn or Config.Lobby.Spawn)
end
GameService.ToLobby = toLobby
GameService.Teleport = teleport

------------------------------------------------------------------------
-- ВРАГИ
------------------------------------------------------------------------
local function enemyPos(e)
	return (PathUtil.OffsetPositionAt(e.Dist, e.Lateral))
end

local function refreshBoss()
	local best
	for _, e in pairs(enemies) do
		if e.IsBoss and (not best or e.MaxHealth > best.MaxHealth) then
			best = e
		end
	end
	if best then
		setState("BossId", best.Id)
		setState("BossName", best.Def.Name)
		setState("BossMaxHP", best.MaxHealth)
	else
		setState("BossId", 0)
		setState("BossName", "")
	end
end

local function spawnEnemy(typeId, startDist, lateral)
	local def = Config.Enemies[typeId]
	if not def then
		return
	end
	nextEnemyId = nextEnemyId + 1
	local hp = math.floor(def.Health * Config.WaveHPMult(math.max(wave, 1)) * D.HP)
	local e = {
		Id = nextEnemyId,
		Type = typeId,
		Def = def,
		MaxHealth = hp,
		Health = hp,
		Speed = def.Speed * D.Speed,
		Dist = startDist or 0,
		Lateral = lateral or (def.IsBoss and 0 or rng:NextNumber(-2.2, 2.2)),
		Armor = def.Armor or 0,
		Dodge = def.Dodge or 0,
		IsBoss = def.IsBoss == true,
		SlowUntil = 0,
		SlowAmount = 0,
		Dots = {},
		NextDot = 0,
		Alive = true,
		Wave = wave,
	}
	if def.Summon then
		e.NextSummon = now() + def.Summon.Interval
	end
	-- особое поведение хэллоуинских врагов
	local t0 = now()
	e.BaseArmor = e.Armor
	if def.Phase then
		e.NextPhase = t0 + def.Phase.Every * rng:NextNumber(0.5, 1)
	end
	if def.Fog then
		e.NextFog = t0 + def.Fog.Every * rng:NextNumber(0.4, 0.8)
	end
	if def.Shield then
		e.NextShield = t0 + def.Shield.Every * 0.6
	end
	if def.Haste then
		e.NextHaste = t0 + def.Haste.Every * 0.7
	end
	e.Pos = enemyPos(e)
	enemies[e.Id] = e
	Remotes.EnemySpawn:FireAllClients({ e.Id, typeId, hp, e.Speed, e.Lateral, e.Dist })
	if e.IsBoss then
		refreshBoss()
	end
	return e
end

local function removeEnemy(e, reason)
	if not e.Alive then
		return
	end
	e.Alive = false
	enemies[e.Id] = nil
	removedBuffer[#removedBuffer + 1] = { e.Id, reason }
	if e.IsBoss then
		refreshBoss()
	end
end

local function killEnemy(e)
	local reward = math.floor(e.Def.Reward * (1 + S.KillRewardScalePerWave * (math.max(e.Wave, 1) - 1)) * D.Money + 0.5)
	addMoneyAll(reward)
	if e.Def.BossGems then
		local g = addGemsAll(e.Def.BossGems)
		notifyAll({ Type = "Toast", Text = e.Def.Name .. " повержен! +" .. g .. " гемов", Kind = "boss" })
		notifyAll({ Type = "BossDown" })
	end
	if e.Def.OnDeath then
		pendingSpawns[#pendingSpawns + 1] = { e.Def.OnDeath.Enemy, e.Def.OnDeath.Count, e.Dist + 1.5, e.Pos, "Straw" }
	end
	removeEnemy(e, "kill")
end

local function enemyState(e, state, dur)
	Remotes.Impact:FireAllClients({ K = "EnemyState", I = e.Id, S = state, DUR = dur, P = e.Pos })
end

-- множитель получаемого урона: фаза призрака, защита, метка проклятия
local function takenMult(e, t)
	local m = 1
	if (e.PhasedUntil or 0) > t then
		m = m * e.Def.Phase.Taken
	end
	if (e.ShieldUntil or 0) > t then
		m = m * e.Def.Shield.Taken
	end
	if (e.MarkUntil or 0) > t then
		m = m * (1 + (e.Mark or 0))
	end
	return m
end

-- броня с учётом участков дороги (Проклятый монарх)
local function armorOf(e)
	local a = e.Armor
	local zones = e.Def.ArmorZones
	if zones then
		local f = PathUtil.Fraction(e.Dist)
		for _, z in ipairs(zones) do
			if f >= z[1] and f <= z[2] then
				a = a + z[3]
			end
		end
	end
	return math.min(a, 0.9)
end

-- пороги HP: ломается броня, ярость, вторая фаза
local function checkThresholds(e)
	local def = e.Def
	local ratio = e.Health / e.MaxHealth
	if def.ArmorScale then
		e.Armor = e.BaseArmor * math.max(ratio, 0)
	end
	if def.ArmorBreak and not e.ArmorBroken and ratio <= def.ArmorBreak.At then
		e.ArmorBroken = true
		e.Armor = def.ArmorBreak.Armor
		enemyState(e, "ArmorBreak")
	end
	if def.Enrage and not e.Enraged and ratio <= def.Enrage.At then
		e.Enraged = true
		e.EnrageSpeed = def.Enrage.Speed or 0
		enemyState(e, "Enrage")
		if def.Enrage.Spawn then
			pendingSpawns[#pendingSpawns + 1] = { def.Enrage.Spawn[1], def.Enrage.Spawn[2], math.max(e.Dist - 4, 0), e.Pos, "Fire" }
		end
	end
end

local function pushDamage(id, amount, flag)
	damageBuffer[#damageBuffer + 1] = { id, amount, flag }
end

-- flag: 0 обычный, 1 крит, 2 уклонение
local function damageEnemy(e, amount, crit, unit, noDodge)
	if not e or not e.Alive then
		return 0
	end
	if not noDodge and e.Dodge > 0 and rng:NextNumber() < e.Dodge then
		pushDamage(e.Id, 0, 2)
		return 0
	end
	local dmg = math.max(1, math.floor(amount * (1 - armorOf(e)) * takenMult(e, now()) + 0.5))
	e.Health = e.Health - dmg
	pushDamage(e.Id, dmg, crit and 1 or 0)
	if unit then
		unit.DamageDealt = unit.DamageDealt + math.min(dmg, dmg + e.Health)
	end
	if e.Health <= 0 then
		killEnemy(e)
	else
		checkThresholds(e)
	end
	return dmg
end

-- чистый урон без брони и уклонения (столкновение с союзником)
local function rawDamage(e, amount, unit)
	if not e.Alive or amount <= 0 then
		return 0
	end
	local dmg = math.min(amount, e.Health)
	e.Health = e.Health - dmg
	pushDamage(e.Id, math.floor(dmg + 0.5), 0)
	if unit and unit.Alive then
		unit.DamageDealt = unit.DamageDealt + dmg
	end
	if e.Health <= 0.5 then
		e.Health = 0
		killEnemy(e)
	else
		checkThresholds(e)
	end
	return dmg
end

local function clearEnemies()
	for _, e in pairs(enemies) do
		e.Alive = false
		removedBuffer[#removedBuffer + 1] = { e.Id, "clear" }
	end
	enemies = {}
	zones = {}
	refreshBoss()
end

------------------------------------------------------------------------
-- ФАЗЫ МАТЧА
------------------------------------------------------------------------
local resetMatch

local function endMatch(victory)
	phase = victory and "Victory" or "Defeat"
	setState("Phase", phase)
	waveSpawning = false
	local myMatch = matchId
	if victory then
		local g = addGemsAll(S.VictoryGems)
		for _, pl in ipairs(matchPlayers()) do
			local prof = DataService.Get(pl)
			if prof then
				prof.Stats.Wins = (prof.Stats.Wins or 0) + 1
				prof.Stats.BestWave = math.max(prof.Stats.BestWave or 0, wave)
				DataService.Save(pl, true)
			end
		end
		-- Halloween Coins: каждому участнику за победу, один раз за матч
		local coins = 0
		if matchMode == "Halloween" and not coinsPaid[myMatch] then
			coinsPaid[myMatch] = true
			coins = Config.Halloween.Coins[difficultyKey] or 0
			for _, pl in ipairs(matchPlayers()) do
				if roster[pl.UserId] then
					DataService.AddCurrency(pl, "HalloweenCoins", coins)
					DataService.Save(pl, true)
					if GameService.OnProfileChanged then
						GameService.OnProfileChanged(pl)
					end
				end
			end
		end
		notifyAll({ Type = "Victory", Wave = wave, Gems = g, Coins = coins > 0 and coins or nil, Reset = S.ResetDelay, Difficulty = difficultyKey, Mode = matchMode })
	else
		for _, pl in ipairs(matchPlayers()) do
			local prof = DataService.Get(pl)
			if prof then
				prof.Stats.BestWave = math.max(prof.Stats.BestWave or 0, wave - 1)
				DataService.Save(pl, true)
			end
		end
		notifyAll({ Type = "Defeat", Wave = wave, Reset = S.ResetDelay, Difficulty = difficultyKey, Mode = matchMode })
		clearEnemies()
	end
	task.delay(S.ResetDelay, function()
		if matchId == myMatch then
			resetMatch()
		end
	end)
end

local function damageCore(amount)
	if phase == "Victory" or phase == "Defeat" then
		return
	end
	coreHP = math.max(0, coreHP - amount)
	setState("CoreHP", coreHP)
	notifyAll({ Type = "CoreHit", Amount = amount })
	if coreHP <= 0 then
		endMatch(false)
	end
end

local function waveCleared()
	local reward = math.floor((S.WaveRewardBase + S.WaveRewardPerWave * wave) * D.Money + 0.5)
	addMoneyAll(reward)
	local gems = addGemsAll(S.WaveGemsBase + S.WaveGemsPerWave * wave)
	if wave >= maxWave then
		endMatch(true)
		return
	end
	phase = "Intermission"
	nextWaveAt = now() + (D.Intermission or S.Intermission)
	setState("Phase", phase)
	setState("NextWaveAt", nextWaveAt)
	notifyAll({ Type = "WaveClear", Wave = wave, Reward = reward, Gems = gems })
end

local function startWave()
	if phase ~= "Prep" and phase ~= "Intermission" then
		return false
	end
	wave = wave + 1
	phase = "Wave"
	setState("Wave", wave)
	setState("Phase", phase)
	setState("NextWaveAt", 0)
	local source = matchMode == "Halloween" and Config.Maps.Halloween.Waves or Config.Waves
	local groups = {}
	for i, g in ipairs(source[wave] or {}) do
		-- BOSS — финальный босс выбранной сложности
		groups[i] = g[1] == "BOSS" and { Config.Halloween.Bosses[difficultyKey] or "GraveWarden", g[2], g[3] } or g
	end
	local bossName
	for _, g in ipairs(groups) do
		local def = Config.Enemies[g[1]]
		if def and def.IsBoss then
			bossName = def.Name
		end
	end
	notifyAll({ Type = "WaveStart", Wave = wave, Boss = bossName })
	waveSpawning = true
	local myMatch, myWave = matchId, wave
	task.spawn(function()
		for gi, g in ipairs(groups) do
			for i = 1, g[2] do
				if matchId ~= myMatch or phase ~= "Wave" then
					return
				end
				spawnEnemy(g[1])
				if i < g[2] then
					task.wait(g[3])
				end
			end
			if gi < #groups then
				task.wait(S.GroupDelay)
			end
		end
		if matchId == myMatch and wave == myWave then
			waveSpawning = false
		end
	end)
	return true
end

function GameService.RequestStartWave(player)
	if not inMatch(player) then
		return false, "Сначала зайди в матч через портал ИГРАТЬ"
	end
	if phase == "Prep" or phase == "Intermission" then
		startWave()
		return true
	end
	return false, "Волна уже идёт"
end

------------------------------------------------------------------------
-- ЮНИТЫ
------------------------------------------------------------------------
local function unitCountFor(player, unitId)
	local total, same = 0, 0
	for _, u in pairs(units) do
		if u.Owner == player then
			total = total + 1
			if u.Id == unitId then
				same = same + 1
			end
		end
	end
	return total, same
end

local function removeAlly(a, reason)
	if not a.Alive then
		return
	end
	a.Alive = false
	allies[a.Id] = nil
	allyRemoved[#allyRemoved + 1] = { a.Id, reason }
end

local function removeUnit(u)
	u.Alive = false
	units[u.Uid] = nil
	if u.Folder then
		u.Folder:Destroy()
	end
	-- проданный юнит забирает своих союзников
	for _, a in pairs(allies) do
		if a.Owner == u then
			removeAlly(a, "sold")
		end
	end
end

local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Include

function GameService.PlaceUnit(player, unitId, pos, rotation)
	if phase == "Victory" or phase == "Defeat" or phase == "Idle" then
		return false, "Матч не идёт"
	end
	if not inMatch(player) then
		return false, "Ты не в матче"
	end
	local def = Config.Units[unitId]
	if not def or typeof(pos) ~= "Vector3" then
		return false, "Неверный запрос"
	end
	if pos.X ~= pos.X or pos.Z ~= pos.Z then
		return false, "Неверная позиция"
	end
	if not DataService.IsEquipped(player, unitId) then
		return false, "Юнит не экипирован"
	end
	local cost = def.Levels[1].Cost
	if getMoney(player) < cost then
		return false, "Недостаточно денег"
	end
	local total, same = unitCountFor(player, unitId)
	if total >= S.MaxUnitsPerPlayer then
		return false, "Лимит юнитов: " .. S.MaxUnitsPerPlayer
	end
	local limit = Config.Rarities[def.Rarity].PlacementLimit
	if same >= limit then
		return false, "Лимит " .. def.Name .. ": " .. limit
	end
	local ok, why = PathUtil.IsPlacementClear(pos)
	if not ok then
		return false, why
	end
	-- проверяем, что под ногами остров
	raycastParams.FilterDescendantsInstances = { MapModels[matchMode] or Map }
	local hit = workspace:Raycast(Vector3.new(pos.X, PathUtil.Map.GroundY + 30, pos.Z), Vector3.new(0, -60, 0), raycastParams)
	if not hit or not hit.Instance:GetAttribute("Placeable") then
		return false, "Сюда ставить нельзя"
	end
	local ground = Vector3.new(pos.X, hit.Position.Y, pos.Z)
	for _, u in pairs(units) do
		if PathUtil.FlatDistance(u.Pos, ground) < S.PlacementSpacing then
			return false, "Слишком близко к другому юниту"
		end
	end

	setMoney(player, getMoney(player) - cost)
	nextUnitId = nextUnitId + 1
	local u = {
		Uid = nextUnitId,
		Id = unitId,
		Def = def,
		Owner = player,
		Level = 1,
		Pos = ground,
		Rotation = tonumber(rotation) or 0,
		TargetMode = def.DefaultTarget or "First",
		NextAttack = now() + 0.6,
		NextAbility = now() + 1.5,
		PlacedAt = now(),
		Spent = cost,
		DamageDealt = 0,
		Alive = true,
	}
	local f = Instance.new("Folder")
	f.Name = tostring(u.Uid)
	f:SetAttribute("UnitId", unitId)
	f:SetAttribute("Level", 1)
	f:SetAttribute("OwnerId", player.UserId)
	f:SetAttribute("OwnerName", player.DisplayName)
	f:SetAttribute("Position", ground)
	f:SetAttribute("Rotation", u.Rotation)
	f:SetAttribute("TargetMode", u.TargetMode)
	f:SetAttribute("Spent", u.Spent)
	f:SetAttribute("Damage", 0)
	f.Parent = UnitsFolder
	u.Folder = f
	-- таймеры способностей времени стартуют после установки
	if def.TimeHaste then
		u.NextHaste = u.PlacedAt + def.TimeHaste.FirstDelay
	end
	if def.TimeStorm then
		u.NextStorm = u.PlacedAt + def.TimeStorm.FirstDelay
	end
	-- призыв союзников: первый — через интервал текущего уровня
	if def.Summon then
		u.NextSummon = u.PlacedAt + def.Summon.Levels[1].Interval
		u.SummonCount = 0
	end
	-- руна: читается из профиля в момент установки
	u.Rune = DataService.GetRune(player, unitId)
	if u.Rune then
		f:SetAttribute("Rune", u.Rune)
		if u.Rune == "CursedThreads" then
			u.NextRuneSummon = u.PlacedAt + Config.Runes.CursedThreads.Summon.Interval
		end
	end
	units[u.Uid] = u
	return true, u.Uid
end

local function ownedUnit(player, uid)
	local u = units[tonumber(uid) or -1]
	if not u then
		return nil, "Юнит не найден"
	end
	if u.Owner ~= player then
		return nil, "Это не твой юнит"
	end
	return u
end

function GameService.UpgradeUnit(player, uid)
	local u, err = ownedUnit(player, uid)
	if not u then
		return false, err
	end
	if u.Level >= #u.Def.Levels then
		return false, "Максимальный уровень"
	end
	local cost = u.Def.Levels[u.Level + 1].Cost
	if getMoney(player) < cost then
		return false, "Недостаточно денег"
	end
	setMoney(player, getMoney(player) - cost)
	u.Level = u.Level + 1
	u.Spent = u.Spent + cost
	u.Folder:SetAttribute("Level", u.Level)
	u.Folder:SetAttribute("Spent", u.Spent)
	return true, u.Level
end

function GameService.SellUnit(player, uid)
	local u, err = ownedUnit(player, uid)
	if not u then
		return false, err
	end
	local refund = math.floor(u.Spent * S.SellRefund)
	setMoney(player, getMoney(player) + refund)
	removeUnit(u)
	return true, refund
end

function GameService.SetTargetMode(player, uid, mode)
	local u, err = ownedUnit(player, uid)
	if not u then
		return false, err
	end
	if not table.find(Config.TargetModes, mode) then
		return false, "Неверный режим"
	end
	u.TargetMode = mode
	u.Folder:SetAttribute("TargetMode", mode)
	return true
end

------------------------------------------------------------------------
-- ВЫБОР ЦЕЛИ
------------------------------------------------------------------------
local sorters = {
	First = function(a, b)
		return a.Dist > b.Dist
	end,
	Last = function(a, b)
		return a.Dist < b.Dist
	end,
	Strongest = function(a, b)
		if a.Health == b.Health then
			return a.Dist > b.Dist
		end
		return a.Health > b.Health
	end,
	Weakest = function(a, b)
		if a.Health == b.Health then
			return a.Dist > b.Dist
		end
		return a.Health < b.Health
	end,
}

local function candidates(u, range)
	local list = {}
	for _, e in pairs(enemies) do
		if e.Alive then
			local d = PathUtil.FlatDistance(e.Pos, u.Pos)
			if d <= range then
				e._d = d
				list[#list + 1] = e
			end
		end
	end
	if #list > 1 then
		local sorter = sorters[u.TargetMode]
		if u.TargetMode == "Closest" or not sorter then
			table.sort(list, function(a, b)
				return a._d < b._d
			end)
		else
			table.sort(list, sorter)
		end
	end
	return list
end

------------------------------------------------------------------------
-- АТАКИ
------------------------------------------------------------------------
local function rollDamage(stats)
	local dmg = stats.Damage
	local crit = false
	if stats.CritChance and rng:NextNumber() < stats.CritChance then
		dmg = dmg * (stats.CritMult or 2)
		crit = true
	end
	return dmg, crit
end

local function fireAttack(u, targetIds, extra)
	local payload = { U = u.Uid, T = targetIds, L = u.Level, EC = echoAttack or nil }
	if extra then
		for k, v in pairs(extra) do
			payload[k] = v
		end
	end
	Remotes.Attack:FireAllClients(payload)
end

local function valid(u, myMatch)
	return u.Alive and matchId == myMatch
end

------------------------------------------------------------------------
-- ЭФФЕКТЫ НА ВРАГАХ: периодический урон (кровотечение, нити) и замедление
------------------------------------------------------------------------
local function applyDot(e, dps, duration, u, kind)
	if not e.Alive or not dps or dps <= 0 then
		return
	end
	-- один источник обновляет свой эффект, а не стакает бесконечно
	local key = tostring(u and u.Uid or 0) .. ":" .. kind
	e.Dots[key] = { Dps = dps, Until = now() + duration, Unit = u }
end

local function applySlow(e, amount, duration)
	if not e then
		return
	end
	if not e.Alive or not amount then
		return
	end
	local t = now()
	amount = amount * (e.IsBoss and S.BossSlowResist or 1)
	if e.SlowUntil < t then
		e.SlowAmount = 0
	end
	e.SlowAmount = math.max(e.SlowAmount, amount)
	e.SlowUntil = math.max(e.SlowUntil, t + duration)
end

local function updateDots(t)
	for _, e in pairs(enemies) do
		if next(e.Dots) and t >= e.NextDot then
			e.NextDot = t + 0.5
			local total, unit = 0, nil
			for key, d in pairs(e.Dots) do
				if t >= d.Until then
					e.Dots[key] = nil
				else
					total = total + d.Dps * 0.5
					unit = unit or d.Unit
				end
			end
			if total > 0 then
				damageEnemy(e, total, false, unit, true)
			end
		end
	end
end

-- AOE: каждый враг получает урон ровно один раз за удар.
-- opts: Exclude (враг без урона), Mult, Bleed/BleedTime, Color, Extra (доп. поля события)
local function aoeHit(u, center, radius, stats, kind, opts)
	opts = opts or {}
	local hitSet = {}
	for _, e in pairs(enemies) do
		if e.Alive and e ~= opts.Exclude and PathUtil.FlatDistance(e.Pos, center) <= radius + (e.IsBoss and 1.5 or 0.5) then
			hitSet[#hitSet + 1] = e
		end
	end
	local payload = { K = kind, P = center, R = radius, L = u.Level, U = u.Uid, N = #hitSet }
	for k, v in pairs(opts.Extra or {}) do
		payload[k] = v
	end
	Remotes.Impact:FireAllClients(payload)
	for _, e in ipairs(hitSet) do
		local dmg, crit = rollDamage(stats)
		if opts.Bleed then
			applyDot(e, opts.Bleed, opts.BleedTime or 3, u, opts.DotKind or "Bleed")
		end
		if opts.Slow then
			applySlow(e, opts.Slow, opts.SlowTime or 1.5)
		end
		damageEnemy(e, dmg * (opts.Mult or 1), crit, u)
	end
	return hitSet
end

local function distToSegment(p, a, b)
	local abx, abz = b.X - a.X, b.Z - a.Z
	local lenSq = abx * abx + abz * abz
	local t = 0
	if lenSq > 0 then
		t = math.clamp(((p.X - a.X) * abx + (p.Z - a.Z) * abz) / lenSq, 0, 1)
	end
	local cx, cz = a.X + abx * t, a.Z + abz * t
	return math.sqrt((p.X - cx) ^ 2 + (p.Z - cz) ^ 2)
end

------------------------------------------------------------------------
-- СПОСОБНОСТИ ВРЕМЕНИ (Проклятый часовщик)
------------------------------------------------------------------------
-- Остановка не суммируется: замороженного не морозим повторно, после заморозки — иммунитет
local function freezeEnemy(e, duration, t)
	e.FrozenUntil = t + duration
	e.FreezeImmuneUntil = t + duration + (S.FreezeImmunity or 3)
end

local function castTimeBreak(u, stats)
	local tb = u.Def.TimeBreak
	local list = candidates(u, stats.Range + 2)
	if #list == 0 then
		return
	end
	local t = now()
	local center = list[1].Pos
	local normal, bosses = {}, {}
	for _, e in pairs(enemies) do
		if e.Alive and t >= (e.FreezeImmuneUntil or 0) and (e.FrozenUntil or 0) <= t then
			local d = PathUtil.FlatDistance(e.Pos, center)
			if d <= tb.Radius + (e.IsBoss and 1.5 or 0) then
				e._dc = d
				table.insert(e.IsBoss and bosses or normal, e)
			end
		end
	end
	table.sort(normal, function(a, b)
		return a._dc < b._dc
	end)
	local frozen = {}
	for i = 1, math.min(tb.MaxFreeze, #normal) do
		freezeEnemy(normal[i], tb.Freeze, t)
		frozen[i] = normal[i]
	end
	for _, b in ipairs(bosses) do
		freezeEnemy(b, tb.BossFreeze, t)
	end
	Remotes.Attack:FireAllClients({ U = u.Uid, T = { list[1].Id }, L = u.Level, D = 0.5, AB = "TimeBreak" })
	Remotes.Impact:FireAllClients({ K = "TimeBreak", P = center, R = tb.Radius, DUR = tb.Freeze, U = u.Uid, L = u.Level })
	-- после остановки до 3 обычных врагов отматываются назад по дороге (боссы — нет)
	local myMatch = matchId
	task.delay(tb.Freeze, function()
		if matchId ~= myMatch then
			return
		end
		for i = 1, math.min(tb.MaxRewind, #frozen) do
			local e = frozen[i]
			if e.Alive then
				e.Dist = math.max(0, e.Dist - tb.Rewind)
				e.Pos = enemyPos(e)
			end
		end
	end)
end

local function castTimeHaste(u, stats)
	local th = u.Def.TimeHaste
	local t = now()
	local allies = {}
	for _, o in pairs(units) do
		-- только свои юниты того же игрока, не сам часовщик
		if o ~= u and o.Alive and o.Owner == u.Owner and PathUtil.FlatDistance(o.Pos, u.Pos) <= th.Radius then
			-- одинаковые ускорения не суммируются: действует самое сильное
			if (o.HasteUntil or 0) > t then
				o.Haste = math.max(o.Haste or 0, stats.Haste)
			else
				o.Haste = stats.Haste
			end
			o.HasteUntil = math.max(o.HasteUntil or 0, t + stats.HasteTime)
			allies[#allies + 1] = o.Uid
		end
	end
	Remotes.Attack:FireAllClients({ U = u.Uid, T = {}, L = u.Level, D = 0.4, AB = "TimeHaste" })
	Remotes.Impact:FireAllClients({ K = "TimeHaste", P = u.Pos, R = th.Radius, A = allies, DUR = stats.HasteTime, U = u.Uid, L = u.Level })
end

local function startTimeStorm(u, t)
	local ts = u.Def.TimeStorm
	u.StormUntil = t + ts.Duration
	u.NextStorm = u.StormUntil + ts.Cooldown
	u.Folder:SetAttribute("Storm", true)
	Remotes.Attack:FireAllClients({ U = u.Uid, T = {}, L = u.Level, D = 1.2, AB = "TimeStorm" })
	Remotes.Impact:FireAllClients({ K = "TimeStorm", P = u.Pos, R = 6, DL = 1.3, U = u.Uid, L = u.Level })
end

local function updateChrono(u, stats, t)
	local def = u.Def
	if def.TimeStorm then
		if u.StormUntil and t >= u.StormUntil then
			u.StormUntil = nil
			u.Folder:SetAttribute("Storm", false)
		end
		if not u.StormUntil and t >= u.NextStorm then
			startTimeStorm(u, t)
			u.NextAttack = math.max(u.NextAttack, t + 1.4)
		end
	end
	if def.TimeHaste and t >= u.NextHaste then
		castTimeHaste(u, stats)
		u.NextHaste = t + def.TimeHaste.Interval
		u.NextAttack = math.max(u.NextAttack, t + 0.6)
	end
end

-- ядовитая/огненная зона: урон раз в 0.5 с всем внутри
local function poisonZone(u, pos, radius, duration, dps, kind, delay)
	if dps <= 0 then
		return
	end
	local t = now() + (delay or 0)
	zones[#zones + 1] = {
		Pos = pos, Radius = radius, Until = t + duration, NextTick = t, Tick = 0.5,
		TickDamage = dps * 0.5, Slow = 0, Unit = u,
	}
	Remotes.Impact:FireAllClients({ K = kind, P = pos, R = radius, DUR = duration, DL = delay, U = u.Uid, L = u.Level })
end

local function attack(u, stats, list)
	list = list or {}
	if not list[1] then
		return
	end
	local def = u.Def
	local myMatch = matchId
	local hitDelay = def.HitDelay or 0.2
	local target = list[1]
	local atype = def.AttackType

	local function later(delay, fn)
		task.delay(delay, function()
			if valid(u, myMatch) then
				fn()
			end
		end)
	end

	-- урон + эффекты при попадании (кровотечение)
	local function strike(e, mult, forceCrit)
		if not e or not e.Alive then
			return
		end
		local dmg, crit = rollDamage(stats)
		if stats.Bleed then
			applyDot(e, stats.Bleed, stats.BleedTime or 3, u, "Bleed")
		end
		damageEnemy(e, dmg * (mult or 1), crit or forceCrit, u)
	end

	if atype == "Melee" or atype == "Laser" then
		local mult, power = 1, false
		if def.EveryNth and not echoAttack then
			u.HitCount = (u.HitCount or 0) + 1
			if u.HitCount % def.EveryNth.N == 0 then
				mult, power = def.EveryNth.Mult, true
			end
		end
		fireAttack(u, { target.Id }, { D = hitDelay, PW = power })
		later(hitDelay, function()
			strike(target, mult, power)
		end)
	elseif atype == "Projectile" then
		local shots = stats.Shots or 1
		local ids, travels = {}, {}
		for s = 1, shots do
			local e = list[((s - 1) % #list) + 1]
			ids[s] = e.Id
			travels[s] = PathUtil.FlatDistance(u.Pos, e.Pos) / (def.ProjectileSpeed or 80)
		end
		fireAttack(u, ids, { D = hitDelay, TR = travels[1], TRS = travels, SG = 0.12 })
		for s = 1, shots do
			local e = list[((s - 1) % #list) + 1]
			later(hitDelay + (s - 1) * 0.12 + travels[s], function()
				if not e.Alive then
					return
				end
				local center = e.Pos
				strike(e)
				if stats.Explode then
					aoeHit(u, center, stats.Explode, stats, def.ExplodeKind or "Crystal", { Exclude = e, Mult = def.ExplodeMult or 0.5 })
				end
			end)
		end
	elseif atype == "Chain" then
		-- лунный серп отскакивает к ближайшим врагам
		local seq, times = { target }, {}
		local used = { [target] = true }
		local speed = def.ProjectileSpeed or 60
		times[1] = hitDelay + PathUtil.FlatDistance(u.Pos, target.Pos) / speed
		for i = 2, stats.Bounces or 3 do
			local prev = seq[i - 1]
			local best, bestD
			for _, e in pairs(enemies) do
				if e.Alive and not used[e] then
					local d = PathUtil.FlatDistance(e.Pos, prev.Pos)
					if d <= (def.BounceRange or 12) and (not bestD or d < bestD) then
						best, bestD = e, d
					end
				end
			end
			if not best then
				break
			end
			used[best] = true
			seq[i] = best
			times[i] = times[i - 1] + bestD / speed
		end
		local ids = {}
		for i, e in ipairs(seq) do
			ids[i] = e.Id
		end
		fireAttack(u, ids, { D = hitDelay, TT = times })
		for i, e in ipairs(seq) do
			later(times[i], function()
				strike(e, (def.BounceMult or 0.8) ^ (i - 1))
			end)
		end
	elseif atype == "Thread" then
		local ids, targets = {}, {}
		for i = 1, math.min(stats.Targets or 1, #list) do
			targets[i] = list[i]
			ids[i] = list[i].Id
		end
		fireAttack(u, ids, { D = hitDelay })
		later(hitDelay, function()
			for _, e in ipairs(targets) do
				if e.Alive then
					applySlow(e, stats.Slow, stats.SlowTime or 1.5)
					applyDot(e, stats.Dot, stats.DotTime or 3, u, "Thread")
					strike(e)
				end
			end
		end)
	elseif atype == "AOE" then
		local saved = target.Pos
		fireAttack(u, { target.Id }, { D = hitDelay })
		later(hitDelay, function()
			local center = target.Alive and target.Pos or saved
			aoeHit(u, center, stats.AOERadius or 6, stats, def.ImpactKind or "Reap", { Bleed = stats.Bleed, BleedTime = stats.BleedTime })
			-- падающие звёздные осколки
			for k = 1, stats.Shards or 0 do
				later(0.35 + k * 0.15, function()
					local pool = candidates(u, stats.Range + 4)
					if #pool > 0 then
						local e = pool[math.random(1, #pool)]
						aoeHit(u, e.Pos, stats.ShardRadius or 4, stats, "Shard", { Mult = stats.ShardMult or 0.6 })
					end
				end)
			end
		end)
	elseif atype == "MultiHit" then
		local hits = stats.Hits or 1
		local interval = def.HitInterval or 0.15
		local spread = def.Spread or (u.Id == "VoidEmperor")
		local kind = def.ImpactKind or "Judgement"
		local ids = {}
		local plan = {}
		for h = 1, hits do
			local e = spread and list[((h - 1) % #list) + 1] or target
			plan[h] = e
			ids[h] = e.Id
		end
		fireAttack(u, ids, { D = hitDelay, I = interval })
		for h = 1, hits do
			later(hitDelay + (h - 1) * interval, function()
				local e = plan[h]
				if not e.Alive then
					e = candidates(u, stats.Range)[1]
				end
				if e then
					if spread then
						Remotes.Impact:FireAllClients({ K = kind, P = e.Pos, L = u.Level, U = u.Uid, H = h })
					end
					strike(e)
				end
			end)
		end
		if stats.BigRift then
			later(hitDelay + hits * interval + 0.2, function()
				local pool = candidates(u, stats.Range)
				if #pool > 0 then
					aoeHit(u, pool[1].Pos, stats.BigRift, stats, "BigRift", { Mult = stats.BigRiftMult or 1.5 })
				end
			end)
		end
	elseif atype == "Splash" then
		-- RED SPLASH: цель 100%, остальные в радиусе 50% (цель второй раз не задевается)
		fireAttack(u, { target.Id }, { D = hitDelay })
		local saved = target.Pos
		later(hitDelay, function()
			local center = target.Alive and target.Pos or saved
			local primary = target.Alive and target or nil
			strike(primary)
			aoeHit(u, center, stats.AOERadius or 8, stats, "Splash", { Exclude = target, Mult = def.SplashMult or 0.5 })
		end)
	elseif atype == "Chrono" then
		-- РАЗРЕЗ СЕКУНД: зубчатый диск летит по прямой и режет до DiscTargets врагов
		local t0 = now()
		local storm = u.StormUntil ~= nil and t0 < u.StormUntil
		local dir = Vector3.new(target.Pos.X - u.Pos.X, 0, target.Pos.Z - u.Pos.Z)
		if dir.Magnitude < 0.1 then
			dir = Vector3.new(0, 0, -1)
		end
		dir = dir.Unit
		local endPos = u.Pos + dir * (stats.Range + 3)
		local speed = def.ProjectileSpeed or 70
		local half = (def.DiscWidth or 3) / 2
		local line = {}
		for _, e in pairs(enemies) do
			if e.Alive and e ~= target and distToSegment(e.Pos, u.Pos, endPos) <= half + (e.IsBoss and 1.2 or 0) then
				e._along = (e.Pos.X - u.Pos.X) * dir.X + (e.Pos.Z - u.Pos.Z) * dir.Z
				line[#line + 1] = e
			end
		end
		table.sort(line, function(a, b)
			return a._along < b._along
		end)
		local hits = { target }
		local hitSet = { [target] = true }
		for _, e in ipairs(line) do
			if #hits >= (def.DiscTargets or 5) then
				break
			end
			hits[#hits + 1] = e
			hitSet[e] = true
		end
		fireAttack(u, { target.Id }, { D = hitDelay, E = endPos, SP = speed, ST = storm or nil })
		for _, e in ipairs(hits) do
			local along = math.max(0, (e.Pos.X - u.Pos.X) * dir.X + (e.Pos.Z - u.Pos.Z) * dir.Z)
			later(hitDelay + along / speed, function()
				if e.Alive then
					Remotes.Impact:FireAllClients({ K = "ChronoHit", P = e.Pos, L = u.Level, U = u.Uid })
					strike(e)
				end
			end)
		end
		-- ВРЕМЕННАЯ БУРЯ: основная цель 100% (диском), до 4 других врагов рядом с ней — по 50%.
		-- Эти попадания не считаются обычными атаками.
		if storm then
			local ts = def.TimeStorm
			local saved = target.Pos
			later(hitDelay + PathUtil.FlatDistance(u.Pos, target.Pos) / speed + 0.02, function()
				local center = target.Alive and target.Pos or saved
				local extra = {}
				for _, e in pairs(enemies) do
					if e.Alive and not hitSet[e] then
						local d = PathUtil.FlatDistance(e.Pos, center)
						if d <= ts.Radius + (e.IsBoss and 1 or 0.3) then
							e._dc = d
							extra[#extra + 1] = e
						end
					end
				end
				table.sort(extra, function(a, b)
					return a._dc < b._dc
				end)
				Remotes.Impact:FireAllClients({ K = "ChronoBurst", P = center, R = ts.Radius, L = u.Level, U = u.Uid })
				for i = 1, math.min(ts.Extra, #extra) do
					strike(extra[i], ts.Mult)
				end
			end)
		end
		-- ПОЛОМКА ВРЕМЕНИ: каждая 8-я обычная атака, но не чаще раза в 18 с
		local tb = def.TimeBreak
		if not echoAttack then
			u.ChronoCount = (u.ChronoCount or 0) + 1
		end
		if not echoAttack and u.ChronoCount >= tb.EveryNth and t0 - (u.LastBreak or -1e9) >= tb.MinInterval then
			u.ChronoCount = 0
			u.LastBreak = t0
			u.NextAttack = math.max(u.NextAttack or 0, t0 + 1.6)
			later(hitDelay + 0.45, function()
				castTimeBreak(u, stats)
			end)
		end
	elseif atype == "Pulse" then
		-- звуковая волна вокруг самого юнита
		fireAttack(u, { target.Id }, { D = hitDelay })
		later(hitDelay, function()
			aoeHit(u, u.Pos, stats.AOERadius or stats.Range, stats, def.ImpactKind or "BellWave")
		end)
	elseif atype == "Flask" then
		-- колба: взрыв по области и ядовитая лужа (урон по времени)
		local travel = PathUtil.FlatDistance(u.Pos, target.Pos) / (def.ProjectileSpeed or 45)
		local saved = target.Pos
		fireAttack(u, { target.Id }, { D = hitDelay, TR = travel })
		later(hitDelay + travel, function()
			local center = target.Alive and target.Pos or saved
			aoeHit(u, center, stats.Explode or 5, stats, "FlaskSplash")
			poisonZone(u, center, (stats.Explode or 5) * 0.8, def.PoisonTime or 3, stats.PoisonDps or 0, "Poison")
		end)
	elseif atype == "Pierce" then
		-- луч насквозь: все враги на линии от юнита через цель
		local dir = Vector3.new(target.Pos.X - u.Pos.X, 0, target.Pos.Z - u.Pos.Z)
		if dir.Magnitude < 0.1 then
			dir = Vector3.new(0, 0, -1)
		end
		local endPos = u.Pos + dir.Unit * (stats.Range + 4)
		fireAttack(u, { target.Id }, { D = hitDelay, E = endPos })
		later(hitDelay, function()
			Remotes.Impact:FireAllClients({ K = def.ImpactKindPierce or "Pierce", P = u.Pos, E = endPos, L = u.Level, U = u.Uid })
			local half = (def.PierceWidth or 3) / 2
			local hitSet = {}
			for _, e in pairs(enemies) do
				if e.Alive and distToSegment(e.Pos, u.Pos, endPos) <= half + (e.IsBoss and 1.2 or 0) then
					hitSet[#hitSet + 1] = e
				end
			end
			for _, e in ipairs(hitSet) do
				strike(e)
			end
		end)
	end
end

------------------------------------------------------------------------
-- HALLOWEEN: обычная атака с рунами, способности Power, союзники
------------------------------------------------------------------------
-- через сколько секунд обычная атака попадает в цель
local function impactDelay(u, target)
	local def = u.Def
	local d = def.HitDelay or 0.2
	if def.ProjectileSpeed and def.AttackType ~= "Chrono" then
		d = d + PathUtil.FlatDistance(u.Pos, target.Pos) / def.ProjectileSpeed
	elseif def.AttackType == "Chrono" then
		d = d + PathUtil.FlatDistance(u.Pos, target.Pos) / (def.ProjectileSpeed or 70)
	end
	return d
end

local function nearestTo(center, radius, exclude, maxCount)
	local list = {}
	for _, e in pairs(enemies) do
		if e.Alive and not exclude[e] then
			local d = PathUtil.FlatDistance(e.Pos, center)
			if d <= radius + (e.IsBoss and 1 or 0.3) then
				e._dr = d
				list[#list + 1] = e
			end
		end
	end
	table.sort(list, function(a, b)
		return a._dr < b._dr
	end)
	while #list > maxCount do
		table.remove(list)
	end
	return list
end

-- Руны после обычной атаки (повтор «Призрачной короны» руны не запускает)
local function runeAfterAttack(u, stats, list)
	local runeId = u.Rune
	local rune = runeId and Config.Runes[runeId]
	if not rune or echoAttack then
		return
	end
	local target = list[1]
	local myMatch = matchId
	if runeId == "LanternHeart" then
		-- каждая 3-я обычная атака: огненный взрыв 20% урона, радиус 4, до 4 дополнительных врагов
		u.RuneCount = (u.RuneCount or 0) + 1
		if u.RuneCount % rune.EveryNth == 0 then
			local saved = target.Pos
			task.delay(impactDelay(u, target), function()
				if not valid(u, myMatch) then
					return
				end
				local center = target.Alive and target.Pos or saved
				local extra = nearestTo(center, rune.Radius, { [target] = true }, rune.MaxTargets)
				Remotes.Impact:FireAllClients({ K = "LanternHeart", P = center, R = rune.Radius, U = u.Uid, L = u.Level, N = #extra })
				for _, e in ipairs(extra) do
					damageEnemy(e, stats.Damage * rune.Mult, false, u, true)
				end
			end)
		end
	elseif runeId == "CursedThreads" then
		-- каждая 5-я обычная атака: замедление до 3 врагов на 25% (боссы — вдвое слабее), не суммируется
		u.RuneCount = (u.RuneCount or 0) + 1
		if u.RuneCount % rune.EveryNth == 0 then
			task.delay(impactDelay(u, target), function()
				if not valid(u, myMatch) then
					return
				end
				local first = target.Alive and target or nil
				local center = first and first.Pos or target.Pos
				local list2 = first and { first } or {}
				for _, e in ipairs(nearestTo(center, 8, { [target] = true }, rune.MaxTargets - #list2)) do
					list2[#list2 + 1] = e
				end
				local ids = {}
				for i, e in ipairs(list2) do
					applySlow(e, rune.Slow, rune.SlowTime)
					ids[i] = e.Id
				end
				Remotes.Impact:FireAllClients({ K = "CursedThreads", P = center, A = ids, U = u.Uid, L = u.Level, DUR = rune.SlowTime })
			end)
		end
	elseif runeId == "PhantomCrown" then
		-- 30%: призрачная копия повторяет атаку через 0.3 с со 100% урона, не задерживая следующую атаку
		if rng:NextNumber() < rune.Chance then
			task.delay(rune.Delay, function()
				if not valid(u, myMatch) or phase ~= "Wave" and phase ~= "Intermission" and phase ~= "Prep" then
					return
				end
				local pool = candidates(u, stats.Range)
				if target.Alive and PathUtil.FlatDistance(target.Pos, u.Pos) <= stats.Range then
					for i, e in ipairs(pool) do
						if e == target then
							table.remove(pool, i)
							break
						end
					end
					table.insert(pool, 1, target)
				end
				if #pool == 0 then
					return -- целей нет — повтор отменяется
				end
				Remotes.Impact:FireAllClients({ K = "PhantomEcho", P = u.Pos, U = u.Uid, L = u.Level })
				echoAttack = true
				local ok, err = pcall(attack, u, stats, pool)
				echoAttack = false
				if not ok then
					warn("[VOID TD] echo: " .. tostring(err))
				end
			end)
		end
	end
end

local function normalAttack(u, stats, list)
	attack(u, stats, list)
	if u.Rune then
		runeAfterAttack(u, stats, list)
	end
end

-- Способность вместо каждой N-й обычной атаки
local function castPower(u, stats, list)
	local def = u.Def
	local P = def.Power
	local target = list[1]
	local myMatch = matchId
	local delay = P.Delay or 0.45
	local saved = target.Pos
	-- длинная анимация способности не обрывается следующей атакой
	u.NextAttack = math.max(u.NextAttack, now() + delay + 0.25)
	Remotes.Attack:FireAllClients({ U = u.Uid, T = { target.Id }, L = u.Level, D = delay, AB = P.Anim })
	task.delay(delay, function()
		if not valid(u, myMatch) then
			return
		end
		local center = target.Alive and target.Pos or saved
		if P.Mode == "Single" then
			local e = target.Alive and target or candidates(u, stats.Range + 2)[1]
			if not e then
				return
			end
			Remotes.Impact:FireAllClients({ K = P.Kind, P = e.Pos, I = e.Id, U = u.Uid, L = u.Level, DUR = P.MarkTime })
			if P.Mark then
				e.Mark = P.Mark
				e.MarkUntil = now() + (P.MarkTime or 3)
			end
			local dmg, crit = rollDamage(stats)
			damageEnemy(e, dmg * (P.Mult or 1), crit or true, u)
		elseif P.Mode == "Zone" then
			local radius = (stats.Explode or 5) * (P.RadiusMult or 1.5)
			aoeHit(u, center, radius, stats, P.Kind .. "Burst", { Mult = 0.5 })
			poisonZone(u, center, radius, P.Duration or 5, (stats.PoisonDps or stats.Damage * 0.3) * (P.Mult or 1), P.Kind)
		else
			local radius = stats.PowerRadius or P.Radius or ((stats.AOERadius or 5) + (P.RadiusAdd or 0))
			if P.Mode == "Self" then
				center = u.Pos
				radius = stats.PowerRadius or P.Radius or ((stats.AOERadius or stats.Range) + (P.RadiusAdd or 1))
			end
			aoeHit(u, center, radius, stats, P.Kind, {
				Mult = P.Mult, Slow = P.Slow, SlowTime = P.SlowTime,
				Bleed = P.Burn and stats.Damage * P.Burn or nil, BleedTime = P.BurnTime, DotKind = "Burn",
			})
		end
	end)
end

-- СОЮЗНИКИ
local function spawnAlly(u, allyId, hp, source, index)
	nextAllyId = nextAllyId + 1
	local a = {
		Id = nextAllyId,
		AllyId = allyId,
		HP = hp,
		MaxHP = hp,
		Dist = math.max(1, PathUtil.Length - (S.AllyStartBack or 4) - (index or 0) * 2.2),
		Lateral = rng:NextNumber(-1.6, 1.6),
		Speed = S.AllySpeed or 6,
		Owner = u,
		Source = source,
		Born = now(),
		Alive = true,
	}
	a.Pos = PathUtil.OffsetPositionAt(a.Dist, a.Lateral)
	allies[a.Id] = a
	return a
end

local function alliesOf(u, source)
	local list = {}
	for _, a in pairs(allies) do
		if a.Owner == u and a.Source == source then
			list[#list + 1] = a
		end
	end
	table.sort(list, function(x, y)
		return x.Id < y.Id
	end)
	return list
end

-- Призыв Кукловода / Иллюзиониста: не больше Max живых, лишние не появляются
local function castSummon(u, t)
	local sm = u.Def.Summon
	local lv = sm.Levels[u.Level]
	u.NextSummon = t + lv.Interval
	local alive = #alliesOf(u, "Summon")
	local count = math.min(lv.Count, sm.Max - alive)
	if count <= 0 then
		return
	end
	u.SummonCount = (u.SummonCount or 0) + 1
	local golden = sm.Golden and u.Level >= #u.Def.Levels and u.SummonCount % sm.Golden.Every == 0
	local ids = {}
	for i = 1, count do
		local a
		if golden and i == 1 then
			a = spawnAlly(u, sm.Golden.Ally, sm.Golden.HP, "Summon", i - 1)
		else
			a = spawnAlly(u, lv.Ally, lv.HP, "Summon", i - 1)
		end
		ids[i] = a.Id
	end
	Remotes.Attack:FireAllClients({ U = u.Uid, T = {}, L = u.Level, D = 0.6, AB = "Summon" })
	Remotes.Impact:FireAllClients({ K = "SummonPortal", S = sm.Portal, P = PathUtil.PositionAt(PathUtil.Length - (S.AllyStartBack or 4)), U = u.Uid, L = u.Level, A = ids, G = golden or nil })
end

-- «Проклятые нити»: ровно каждые 60 с, не больше 3 живых, лишний — самый старый — исчезает
local function runeSummon(u, t)
	local sm = Config.Runes.CursedThreads.Summon
	u.NextRuneSummon = u.NextRuneSummon + sm.Interval
	local lv = sm.Levels[u.Level]
	local ids = {}
	for i = 1, lv.Count do
		local a = spawnAlly(u, lv.Ally, lv.HP, "Rune", i - 1)
		ids[i] = a.Id
	end
	local list = alliesOf(u, "Rune")
	for i = 1, #list - sm.Max do
		removeAlly(list[i], "replaced")
	end
	Remotes.Impact:FireAllClients({ K = "CursedCircle", P = PathUtil.PositionAt(PathUtil.Length - (S.AllyStartBack or 4)), U = u.Uid, L = u.Level, A = ids })
end

local function updateAllies(t, dt)
	for _, a in pairs(allies) do
		if a.Alive then
			a.Dist = a.Dist - a.Speed * dt
			if a.Dist <= 0 then
				removeAlly(a, "portal")
			else
				a.Pos = PathUtil.OffsetPositionAt(a.Dist, a.Lateral)
				-- столкновение: враг дошёл до союзника (окно с запасом для большого dt)
				for _, e in pairs(enemies) do
					if e.Alive and e.Dist >= a.Dist - 1.4 - (e.IsBoss and 1.2 or 0) and e.Dist <= a.Dist + 3 then
						local cost = e.Def.FireAura or 1
						local dealt = rawDamage(e, math.min(a.HP / cost, e.Health), a.Owner)
						a.HP = a.HP - dealt * cost
						Remotes.Impact:FireAllClients({ K = "AllyHit", P = a.Pos, I = a.Id, E = e.Id, F = cost > 1 or nil })
						if a.HP <= 0.5 then
							removeAlly(a, "dead")
							break
						end
					end
				end
			end
		end
	end
end

local function castBloodMoon(u, stats, list)
	local bm = stats.BloodMoon
	local myMatch = matchId
	local target = list[1]
	local pos = PathUtil.PositionAt(math.min(target.Dist + 3, PathUtil.Length - 1))
	Remotes.Attack:FireAllClients({ U = u.Uid, T = { target.Id }, L = u.Level, D = 0.6, AB = true })
	Remotes.Impact:FireAllClients({ K = "BloodMoonFall", P = pos, R = bm.Radius, L = u.Level, U = u.Uid, DL = 1.0 })
	task.delay(1.0, function()
		if valid(u, myMatch) then
			local big = { Damage = stats.Damage * (bm.Mult or 3) }
			aoeHit(u, pos, bm.Radius, big, "BloodMoon", { Bleed = bm.Bleed, BleedTime = bm.BleedTime })
		end
	end)
end

local function castBlackHole(u, stats, list)
	local bh = stats.BlackHole
	local target = list[1]
	local pos = PathUtil.PositionAt(math.min(target.Dist + 4, PathUtil.Length - 1))
	local zone = {
		Pos = pos,
		Radius = bh.Radius,
		Until = now() + 0.6 + bh.Duration,
		NextTick = now() + 0.6,
		Tick = bh.Tick,
		TickDamage = bh.TickDamage,
		Slow = bh.Slow,
		Unit = u,
	}
	Remotes.Attack:FireAllClients({ U = u.Uid, T = { target.Id }, L = u.Level, D = 0.6, AB = true })
	Remotes.Impact:FireAllClients({ K = "BlackHole", P = pos, R = bh.Radius, L = u.Level, U = u.Uid, DUR = bh.Duration, DL = 0.6 })
	zones[#zones + 1] = zone
end

local function updateZones(t)
	for i = #zones, 1, -1 do
		local z = zones[i]
		if t >= z.Until or not z.Unit.Alive then
			table.remove(zones, i)
		elseif t >= z.NextTick then
			z.NextTick = z.NextTick + z.Tick
			for _, e in pairs(enemies) do
				if e.Alive and PathUtil.FlatDistance(e.Pos, z.Pos) <= z.Radius then
					if z.Slow and z.Slow > 0 then
						local slow = z.Slow * (e.IsBoss and S.BossSlowResist or 1)
						e.SlowUntil = t + z.Tick + 0.15
						e.SlowAmount = math.max(slow, (e.SlowUntil > t and e.SlowAmount) or 0)
					end
					damageEnemy(e, z.TickDamage, false, z.Unit, true)
				end
			end
		end
	end
end

local function updateUnits(t)
	for _, u in pairs(units) do
		local stats = u.Def.Levels[u.Level]
		if stats.BlackHole and t >= u.NextAbility then
			local list = candidates(u, stats.Range + (u.Def.BlackHoleExtraRange or 6))
			if #list > 0 then
				castBlackHole(u, stats, list)
				u.NextAbility = t + stats.BlackHole.Cooldown
				u.NextAttack = math.max(u.NextAttack, t + 0.9)
			end
		end
		if stats.BloodMoon and t >= u.NextAbility then
			local list = candidates(u, stats.Range + (u.Def.AbilityExtraRange or 6))
			if #list > 0 then
				castBloodMoon(u, stats, list)
				u.NextAbility = t + stats.BloodMoon.Cooldown
				u.NextAttack = math.max(u.NextAttack, t + 1.0)
			end
		end
		if u.Def.TimeHaste or u.Def.TimeStorm then
			updateChrono(u, stats, t)
		end
		if u.Def.Summon and t >= u.NextSummon then
			castSummon(u, t)
		end
		if u.NextRuneSummon and t >= u.NextRuneSummon then
			runeSummon(u, t)
		end
		if t >= u.NextAttack then
			local list = candidates(u, stats.Range)
			if #list > 0 then
				-- ускорение времени: союзник атакует чаще, урон за удар прежний
				local cd = stats.Cooldown
				if (u.HasteUntil or 0) > t then
					cd = cd / (1 + (u.Haste or 0))
				end
				u.NextAttack = t + cd
				local P = u.Def.Power
				if P then
					u.PowerCount = (u.PowerCount or 0) + 1
				end
				if P and u.PowerCount % P.N == 0 then
					castPower(u, stats, list)
				else
					normalAttack(u, stats, list)
				end
			end
		end
	end
end

------------------------------------------------------------------------
-- ЦИКЛ
------------------------------------------------------------------------
local function updateEnemies(t, dt)
	local reached = {}
	for _, e in pairs(enemies) do
		local mult = 1
		if (e.FrozenUntil or 0) > t then
			mult = 0
		elseif e.SlowUntil > t then
			mult = 1 - e.SlowAmount
		else
			e.SlowAmount = 0
		end
		-- ускорения: туман, рывок босса, ярость (замедление и заморозка действуют поверх)
		local boost = (e.EnrageSpeed or 0)
		if (e.FogUntil or 0) > t then
			boost = boost + (e.FogAmount or 0)
		end
		if (e.HasteUntil or 0) > t then
			boost = boost + e.Def.Haste.Speed
		end
		mult = mult * (1 + boost)
		local def = e.Def
		if e.NextPhase and t >= e.NextPhase then
			e.NextPhase = t + def.Phase.Every
			e.PhasedUntil = t + def.Phase.Duration
			enemyState(e, "Phase", def.Phase.Duration)
		end
		if e.NextShield and t >= e.NextShield then
			e.NextShield = t + def.Shield.Every
			e.ShieldUntil = t + def.Shield.Duration
			enemyState(e, "Shield", def.Shield.Duration)
		end
		if e.NextHaste and t >= e.NextHaste then
			e.NextHaste = t + def.Haste.Every
			e.HasteUntil = t + def.Haste.Duration
			enemyState(e, "Haste", def.Haste.Duration)
		end
		if e.NextFog and t >= e.NextFog then
			-- туман: враги рядом (и сам колдун) ускоряются; одинаковый туман не суммируется
			local fog = def.Fog
			e.NextFog = t + fog.Every
			for _, o in pairs(enemies) do
				if PathUtil.FlatDistance(o.Pos, e.Pos) <= fog.Radius then
					o.FogAmount = math.max((o.FogUntil or 0) > t and o.FogAmount or 0, fog.Speed)
					o.FogUntil = math.max(o.FogUntil or 0, t + fog.Duration)
				end
			end
			Remotes.Impact:FireAllClients({ K = "Fog", P = e.Pos, R = fog.Radius, I = e.Id, DUR = fog.Duration })
		end
		e.Dist = e.Dist + e.Speed * mult * dt
		e.Pos = enemyPos(e)
		if e.NextSummon and t >= e.NextSummon then
			e.NextSummon = t + e.Def.Summon.Interval
			pendingSpawns[#pendingSpawns + 1] = { e.Def.Summon.Enemy, e.Def.Summon.Count, math.max(e.Dist - 3, 0), e.Pos }
		end
		if e.Dist >= PathUtil.Length then
			reached[#reached + 1] = e
		end
	end
	for _, e in ipairs(reached) do
		removeEnemy(e, "core")
		damageCore(e.Def.CoreDamage)
	end
	if #pendingSpawns > 0 then
		local list = pendingSpawns
		pendingSpawns = {}
		for _, s in ipairs(list) do
			Remotes.Impact:FireAllClients({ K = s[5] or "Summon", P = s[4], R = 6 })
			for k = 1, s[2] do
				spawnEnemy(s[1], s[3] - k * 1.5)
			end
		end
	end
end

local function sync(t)
	local list = {}
	for _, e in pairs(enemies) do
		list[#list + 1] = e.Id
		list[#list + 1] = math.floor(e.Dist * 100) / 100
		list[#list + 1] = math.max(0, e.Health)
		list[#list + 1] = ((e.FrozenUntil or 0) > t) and 2 or ((e.SlowUntil > t) and 1 or 0)
	end
	-- союзники: id, дистанция, HP, тип (индекс в Config.AllyOrder), максимум HP
	local al
	if next(allies) or #allyRemoved > 0 then
		al = {}
		for _, a in pairs(allies) do
			al[#al + 1] = a.Id
			al[#al + 1] = math.floor(a.Dist * 100) / 100
			al[#al + 1] = math.floor(a.HP + 0.5)
			al[#al + 1] = allyIndex[a.AllyId] or 1
			al[#al + 1] = a.MaxHP
		end
	end
	Remotes.Sync:FireAllClients({ T = t, E = list, DMG = damageBuffer, RM = removedBuffer, AL = al, RA = #allyRemoved > 0 and allyRemoved or nil })
	damageBuffer = {}
	removedBuffer = {}
	allyRemoved = {}
end

local function step(dt)
	local t = now()
	if phase == "Wave" or phase == "Intermission" or phase == "Prep" then
		updateEnemies(t, dt)
		updateAllies(t, dt)
		updateZones(t)
		updateDots(t)
		updateUnits(t)
	end
	if phase == "Wave" and not waveSpawning and next(enemies) == nil then
		waveCleared()
	elseif phase == "Intermission" and t >= nextWaveAt then
		startWave()
	end
	if t - lastSync >= S.SyncRate then
		lastSync = t
		sync(t)
	end
	if t - lastAttrFlush >= 1 then
		lastAttrFlush = t
		for _, u in pairs(units) do
			u.Folder:SetAttribute("Damage", math.floor(u.DamageDealt))
		end
	end
end

local function clearMatch()
	matchId = matchId + 1
	clearEnemies()
	for _, u in pairs(units) do
		removeUnit(u)
	end
	units = {}
	for _, a in pairs(allies) do
		removeAlly(a, "clear")
	end
	allies = {}
	wave = 0
	waveSpawning = false
	nextWaveAt = 0
	setState("Wave", 0)
	setState("NextWaveAt", 0)
	setState("MatchId", matchId)
end

-- Матч закончен (или все ушли): все возвращаются в лобби
local function setMapMode(mode)
	matchMode = mode
	PathUtil.SetMap(mode)
	maxWave = (Config.Maps[mode] and Config.Maps[mode].MaxWave) or S.MaxWave
	setState("Map", mode)
	setState("MaxWave", maxWave)
end

resetMatch = function()
	local wasHalloween = matchMode == "Halloween"
	clearMatch()
	phase = "Idle"
	setState("Phase", phase)
	setState("Difficulty", "")
	for _, pl in ipairs(Players:GetPlayers()) do
		if inMatch(pl) then
			pl:SetAttribute("InMatch", false)
			setMoney(pl, 0)
			-- чёрный экран-переход, затем телепорт в лобби (после Хэллоуин-матча — на остров)
			Remotes.Notify:FireClient(pl, { Type = "Fade", Text = wasHalloween and "HALLOWEEN" or "ЛОББИ" })
			task.delay(0.45, function()
				toLobby(pl, wasHalloween)
			end)
		end
	end
	roster = {}
	setMapMode("Void")
	notifyAll({ Type = "Reset" })
end

local function startNewMatch(diffKey, mode)
	clearMatch()
	setMapMode(mode or "Void")
	difficultyKey = diffKey
	D = Config.Difficulties[diffKey]
	coreHP = D.CoreHP
	phase = "Prep"
	setState("Difficulty", diffKey)
	setState("CoreMaxHP", coreHP)
	setState("CoreHP", coreHP)
	setState("Phase", phase)
end

function GameService.JoinMatch(player, diffKey)
	if inMatch(player) then
		return false, "Ты уже в матче"
	end
	if phase == "Victory" or phase == "Defeat" then
		return false, "Матч завершается, подожди пару секунд"
	end
	if phase ~= "Idle" and matchMode == "Halloween" then
		return false, "Сейчас идёт Хэллоуин-матч. Подожди, пока он закончится"
	end
	if phase == "Idle" then
		if not Config.Difficulties[diffKey] then
			return false, "Выбери сложность"
		end
		startNewMatch(diffKey)
	end
	player:SetAttribute("InMatch", true)
	-- поздно зашедшим даём компенсацию за пропущенные волны
	setMoney(player, (S.StartMoney + math.max(0, wave - 1) * 150) * D.Money)
	toBattle(player)
	notifyAll({ Type = "Toast", Text = player.DisplayName .. " вступил в бой (" .. D.Name .. ")", Kind = "good" })
	return true, difficultyKey
end

-- Хэллоуин-матч: все игроки из очереди попадают в один матч
function GameService.CanStartHalloween()
	return phase == "Idle"
end

function GameService.StartHalloween(players, diffKey)
	if phase ~= "Idle" then
		return false, "Арена занята — идёт другой матч"
	end
	if not table.find(Config.Halloween.Difficulties, diffKey) then
		return false, "Неверная сложность"
	end
	startNewMatch(diffKey, "Halloween")
	roster = {}
	for _, pl in ipairs(players) do
		if pl.Parent and not inMatch(pl) then
			roster[pl.UserId] = true
			pl:SetAttribute("InMatch", true)
			setMoney(pl, S.StartMoney * D.Money)
			Remotes.Notify:FireClient(pl, { Type = "Fade", Text = "HAUNTED HOLLOW" })
			task.delay(0.45, function()
				toBattle(pl)
			end)
		end
	end
	if #matchPlayers() == 0 then
		resetMatch()
		return false, "Никого нет в очереди"
	end
	notifyAll({ Type = "Toast", Text = "🎃 Хэллоуин-матч начался (" .. D.Name .. ")", Kind = "good" })
	return true
end

function GameService.GetMode()
	return matchMode, phase
end

function GameService.LeaveMatch(player)
	if not inMatch(player) then
		return false, "Ты не в матче"
	end
	for _, u in pairs(units) do
		if u.Owner == player then
			removeUnit(u)
		end
	end
	player:SetAttribute("InMatch", false)
	setMoney(player, 0)
	toLobby(player, matchMode == "Halloween")
	if #matchPlayers() == 0 and phase ~= "Idle" then
		resetMatch()
	end
	return true
end

function GameService.GetMatchInfo()
	return { Phase = phase, Difficulty = difficultyKey, Wave = wave, Players = #matchPlayers(), Mode = matchMode }
end

------------------------------------------------------------------------
-- ИГРОКИ
------------------------------------------------------------------------
function GameService.PlayerAdded(player)
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	local money = Instance.new("IntValue")
	money.Name = "Money"
	money.Parent = ls
	ls.Parent = player
	player:SetAttribute("InMatch", false)
	setMoney(player, 0)
	-- после смерти игрок в матче возвращается на карту, остальные — в лобби
	player.CharacterAdded:Connect(function(char)
		char:WaitForChild("HumanoidRootPart", 5)
		task.wait(0.2)
		if inMatch(player) then
			toBattle(player)
		else
			toLobby(player, player:GetAttribute("Island") == true)
		end
	end)
end

function GameService.PlayerRemoving(player)
	for _, u in pairs(units) do
		if u.Owner == player then
			removeUnit(u)
		end
	end
	player:SetAttribute("InMatch", false)
	task.defer(function()
		if #matchPlayers() == 0 and phase ~= "Idle" then
			resetMatch()
		end
	end)
end

function GameService.GetEnemySnapshot()
	local list = {}
	for _, e in pairs(enemies) do
		list[#list + 1] = { e.Id, e.Type, e.MaxHealth, e.Speed, e.Lateral, e.Dist, e.Health }
	end
	return list
end

function GameService.Init(remotes, state, unitsFolder, map, maps)
	Remotes, State, UnitsFolder, Map = remotes, state, unitsFolder, map
	MapModels = maps or { Void = map }
	MapModels.Void = MapModels.Void or map
	setState("MaxWave", S.MaxWave)
	setState("CoreMaxHP", S.CoreMaxHP)
	setState("CoreHP", S.CoreMaxHP)
	setState("BossId", 0)
	setState("BossName", "")
	resetMatch()
	RunService.Heartbeat:Connect(step)
end

-- Доступ к внутреннему состоянию для автотестов (в игре не используется)
function GameService.Debug()
	return {
		Units = units, Enemies = enemies, Spawn = spawnEnemy, Now = now,
		Allies = function()
			return allies
		end,
		Mode = function()
			return matchMode, roster
		end,
	}
end

return GameService
]======] }
FILES[#FILES + 1] = { "ServerScriptService", { "VoidTDServer", "HalloweenService" }, "ModuleScript", [======[
--!nocheck
-- VOID TD :: HalloweenService
-- Хэллоуин-остров: телепорты через порталы и очередь в Хэллоуин-матч на 4 светящихся квадратах.
-- Встал на квадрат — в очереди. Первый в очереди — хост: выбирает сложность и может ускорить старт.
-- После обратного отсчёта все из очереди попадают в один и тот же матч.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("VoidTD"):WaitForChild("Config"))

local HalloweenService = {}

local GameService, State
local Q = Config.HalloweenIsland.Queue
local queue = {}          -- игроки по порядку входа
local difficulty = "Easy"
local countdownAt = 0     -- серверное время телепорта (0 — отсчёт не идёт)
local leftUntil = {}      -- игрок нажал «Выйти»: не возвращаем в очередь, пока не сойдёт с квадрата

local function now()
	return workspace:GetServerTimeNow()
end

local function queueCenter()
	return Config.HalloweenIsland.Center + Q.Offset
end

-- стоит ли игрок на одном из квадратов
local function onPad(player)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end
	local c = queueCenter()
	local pos = root.Position
	if math.abs(pos.Y - c.Y) > 9 then
		return false
	end
	local half = Q.Pad / 2 + 0.4
	for _, off in ipairs(Q.Pads) do
		local p = c + off
		if math.abs(pos.X - p.X) <= half and math.abs(pos.Z - p.Z) <= half then
			return true
		end
	end
	return false
end

local function publish()
	local names = {}
	for _, pl in ipairs(queue) do
		names[#names + 1] = pl.DisplayName
	end
	State:SetAttribute("HQ_Members", table.concat(names, "\n"))
	State:SetAttribute("HQ_Count", #queue)
	State:SetAttribute("HQ_Host", queue[1] and queue[1].UserId or 0)
	State:SetAttribute("HQ_Diff", difficulty)
	State:SetAttribute("HQ_At", countdownAt)
	State:SetAttribute("HQ_Busy", not GameService.CanStartHalloween())
end

local function remove(player)
	local i = table.find(queue, player)
	if i then
		table.remove(queue, i)
		if i == 1 then
			difficulty = "Easy" -- новый хост выбирает заново
		end
	end
end

local function tick()
	local t = now()
	-- ушедшие с квадратов и вошедшие в матч выбывают
	for i = #queue, 1, -1 do
		local pl = queue[i]
		if not pl.Parent or pl:GetAttribute("InMatch") or not onPad(pl) then
			remove(pl)
		end
	end
	for _, pl in ipairs(Players:GetPlayers()) do
		if #queue >= Q.MaxPlayers then
			break
		end
		if not table.find(queue, pl) and not pl:GetAttribute("InMatch") then
			local standing = onPad(pl)
			if leftUntil[pl] and not standing then
				leftUntil[pl] = nil
			end
			if standing and not leftUntil[pl] then
				queue[#queue + 1] = pl
				GameService.Toast(pl, "Ты в очереди Хэллоуин-матча (" .. #queue .. "/" .. Q.MaxPlayers .. ")", "good")
			end
		end
	end
	if #queue == 0 or not GameService.CanStartHalloween() then
		countdownAt = 0
	elseif countdownAt == 0 then
		countdownAt = t + Q.Countdown
	elseif t >= countdownAt then
		local list = table.clone(queue)
		local diff = difficulty
		queue = {}
		countdownAt = 0
		difficulty = "Easy"
		local ok, err = GameService.StartHalloween(list, diff)
		if not ok then
			for _, pl in ipairs(list) do
				GameService.Toast(pl, err or "Не удалось начать матч")
			end
		end
	end
	publish()
end

------------------------------------------------------------------------
-- ЗАПРОСЫ КЛИЕНТА
------------------------------------------------------------------------
function HalloweenService.SetDifficulty(player, diff)
	if queue[1] ~= player then
		return false, "Сложность выбирает хост (первый в очереди)"
	end
	if not table.find(Config.Halloween.Difficulties, diff) then
		return false, "Неверная сложность"
	end
	difficulty = diff
	publish()
	return true
end

function HalloweenService.StartNow(player)
	if queue[1] ~= player then
		return false, "Начать может только хост"
	end
	if countdownAt == 0 then
		return false, "Арена занята — подожди окончания матча"
	end
	countdownAt = math.min(countdownAt, now() + Q.StartNow)
	publish()
	return true
end

function HalloweenService.Leave(player)
	if not table.find(queue, player) then
		return false, "Ты не в очереди"
	end
	remove(player)
	leftUntil[player] = true
	-- отводим игрока с квадратов
	GameService.Teleport(player, queueCenter() + Vector3.new(0, 0, 16))
	publish()
	return true
end

-- Портал лобби <-> остров. Проверяем, что игрок стоит у портала и не в матче.
function HalloweenService.Teleport(player, where)
	if player:GetAttribute("InMatch") then
		return false, "Сначала выйди из матча"
	end
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then
		return false, "Персонаж не загружен"
	end
	local zone, center
	if where == "Halloween" then
		zone, center = Config.Lobby.Zones.HalloweenPortal, Config.Lobby.Center
	elseif where == "Lobby" then
		zone, center = Config.HalloweenIsland.Zones.ReturnPortal, Config.HalloweenIsland.Center
	else
		return false, "Неверный портал"
	end
	local p = center + zone.Offset
	local d = Vector3.new(root.Position.X - p.X, 0, root.Position.Z - p.Z).Magnitude
	if d > zone.Radius + 8 then
		return false, "Подойди к порталу"
	end
	GameService.ToLobby(player, where == "Halloween")
	return true
end

function HalloweenService.Init(gameService, state)
	GameService, State = gameService, state
	Players.PlayerRemoving:Connect(function(pl)
		remove(pl)
		leftUntil[pl] = nil
	end)
	publish()
	task.spawn(function()
		while true do
			task.wait(0.25)
			local ok, err = pcall(tick)
			if not ok then
				warn("[VOID TD] HalloweenService: " .. tostring(err))
			end
		end
	end)
end

HalloweenService._tick = tick -- для автотестов
HalloweenService._queue = function()
	return queue, difficulty, countdownAt
end

return HalloweenService
]======] }
FILES[#FILES + 1] = { "ServerScriptService", { "VoidTDServer", "HalloweenWorld" }, "ModuleScript", [======[
--!nocheck
-- VOID TD :: HalloweenWorld
-- Хэллоуин-мир из примитивов (без внешних ассетов):
--   • огромный портал HALLOWEEN EVENT в главном лобби;
--   • Хэллоуин-остров: луна, готический замок, кладбище, тыквенные поля, мёртвые деревья, призраки,
--     летучие мыши, вороны, фонари, туман, руны, разрушенные башни, мост, домики; кейс, 4 квадрата
--     входа в бой, доска наград, превью хэллоуинских юнитов и бестиарий;
--   • карта Haunted Hollow: длинная извилистая дорога, кладбище, поля тыкв, готические здания, лес,
--     база игрока (VoidCore) и портал врагов (VoidPortal).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("VoidTD")
local Config = require(Shared:WaitForChild("Config"))
local PathUtil = require(Shared:WaitForChild("PathUtil"))

local HalloweenWorld = {}

local V = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles
local rad = math.rad

local H -- хелперы MapBuilder (part, light, emitter, cylinderY, billboard, statue, calm, zoneCircle)

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

-- палитра: чёрный, тёмно-фиолетовый, оранжевый, бордовый, золото
local C = {
	Black = rgb(14, 10, 16),
	Ground = rgb(34, 26, 36),
	Ground2 = rgb(44, 30, 40),
	Grass = rgb(46, 34, 30),
	GrassP = rgb(42, 24, 54),
	Rock = rgb(30, 24, 32),
	Rock2 = rgb(44, 36, 46),
	Stone = rgb(78, 70, 82),
	Stone2 = rgb(58, 52, 64),
	Road = rgb(64, 54, 58),
	RoadEdge = rgb(44, 36, 42),
	Purple = rgb(70, 30, 110),
	DeepPurple = rgb(36, 18, 56),
	Orange = rgb(255, 130, 30),
	Ember = rgb(255, 90, 20),
	Pumpkin = rgb(220, 110, 30),
	PumpkinD = rgb(170, 70, 20),
	Stem = rgb(60, 70, 30),
	Burgundy = rgb(100, 20, 34),
	Gold = rgb(200, 156, 60),
	Bark = rgb(32, 24, 26),
	Bone = rgb(200, 192, 176),
	Ghost = rgb(220, 225, 255),
	Fog = rgb(150, 140, 170),
	Moon = rgb(255, 214, 150),
	Window = rgb(255, 160, 60),
	Rune = rgb(170, 70, 255),
}

local SMOKE = "rbxasset://textures/particles/smoke_main.dds"

------------------------------------------------------------------------
-- ДЕТАЛИ
------------------------------------------------------------------------
local function block(parent, size, cf, color, mat, props)
	local o = { Size = size, CFrame = cf, Color = color, Material = mat or Enum.Material.Slate }
	if props then
		for k, v in pairs(props) do
			o[k] = v
		end
	end
	return H.part(parent, o)
end

local function neon(parent, size, cf, color, props)
	local o = { CanCollide = false }
	if props then
		for k, v in pairs(props) do
			o[k] = v
		end
	end
	return block(parent, size, cf, color, Enum.Material.Neon, o)
end

local function wedge(parent, size, cf, color, mat, collide)
	return H.part(parent, { Class = "WedgePart", Size = size, CFrame = cf, Color = color, Material = mat or Enum.Material.Slate, CanCollide = collide == true })
end

local function fogEmitter(p, color, rate, size)
	local e = Instance.new("ParticleEmitter")
	e.Name = "Fog"
	e.Texture = SMOKE
	e.Color = ColorSequence.new(color or C.Fog)
	e.LightEmission = 0.1
	e.LightInfluence = 0.6
	e.Rate = rate or 2
	e.Lifetime = NumberRange.new(5, 8)
	e.Speed = NumberRange.new(0.3, 1)
	e.SpreadAngle = Vector2.new(180, 10)
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-10, 10)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size or 6), NumberSequenceKeypoint.new(1, (size or 6) * 1.8) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.75), NumberSequenceKeypoint.new(1, 1) })
	e.Parent = p
	return e
end

-- угловатая тыква: 6 рёбер-долек вокруг оси, хвостик; carved — вырезанное светящееся лицо
local function pumpkin(parent, pos, s, carved, yaw)
	local m = Instance.new("Model")
	m.Name = "Pumpkin"
	m.Parent = parent
	local base = CF(pos + V(0, 0.55 * s, 0)) * ANG(0, yaw or 0, 0)
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2
		block(m, V(0.62 * s, 1.0 * s, 0.62 * s), base * ANG(0, a, 0) * CF(0, 0, -0.38 * s), (i % 2 == 0) and C.Pumpkin or C.PumpkinD, Enum.Material.SmoothPlastic, { CanCollide = false })
	end
	block(m, V(0.18 * s, 0.4 * s, 0.18 * s), base * CF(0, 0.62 * s, 0) * ANG(0, 0, rad(12)), C.Stem, Enum.Material.Wood, { CanCollide = false })
	if carved then
		local f = base * CF(0, 0, -0.72 * s)
		for _, sx in ipairs({ -1, 1 }) do
			neon(m, V(0.2 * s, 0.2 * s, 0.06), f * CF(0.2 * s * sx, 0.15 * s, 0) * ANG(0, 0, rad(45)), C.Orange)
		end
		neon(m, V(0.5 * s, 0.1 * s, 0.06), f * CF(0, -0.2 * s, 0), C.Orange)
		if s >= 1.2 then
			H.light(m:FindFirstChildWhichIsA("BasePart"), C.Orange, 8 * s, 0.8)
		end
	end
	return m
end

local function deadTree(parent, rng, pos, s)
	s = s or 1
	local m = Instance.new("Model")
	m.Name = "DeadTree"
	m.Parent = parent
	local h = rng:NextNumber(9, 14) * s
	local lean = rad(rng:NextNumber(-6, 6))
	local trunk = CF(pos) * ANG(lean, rng:NextNumber(0, 6), lean * 0.5)
	block(m, V(1.4 * s, h, 1.4 * s), trunk * CF(0, h / 2, 0), C.Bark, Enum.Material.Wood)
	block(m, V(2.4 * s, 1.2 * s, 2.4 * s), trunk * CF(0, 0.4 * s, 0) * ANG(0, rad(45), 0), C.Bark, Enum.Material.Wood)
	for i = 1, 4 do
		local a = i / 4 * math.pi * 2 + rng:NextNumber(-0.4, 0.4)
		local y = h * rng:NextNumber(0.5, 0.95)
		local L = rng:NextNumber(3, 5.5) * s
		local br = trunk * CF(0, y, 0) * ANG(0, a, 0) * ANG(0, 0, rad(rng:NextNumber(45, 65)))
		block(m, V(0.5 * s, L, 0.5 * s), br * CF(0, L / 2, 0), C.Bark, Enum.Material.Wood, { CanCollide = false })
		local tw = br * CF(0, L, 0) * ANG(0, 0, rad(-35))
		block(m, V(0.3 * s, L * 0.5, 0.3 * s), tw * CF(0, L * 0.25, 0), C.Bark, Enum.Material.Wood, { CanCollide = false })
	end
	return m
end

local function tombstone(parent, rng, pos, yaw)
	local kind = rng:NextInteger(1, 3)
	local cf = CF(pos) * ANG(rad(rng:NextNumber(-6, 6)), yaw or 0, rad(rng:NextNumber(-8, 8)))
	if kind == 1 then
		block(parent, V(2, 2.6, 0.5), cf * CF(0, 1.3, 0), C.Stone2)
		block(parent, V(1.6, 0.6, 0.5), cf * CF(0, 2.8, 0) * ANG(0, 0, rad(45)), C.Stone2)
	elseif kind == 2 then
		block(parent, V(0.45, 3.2, 0.45), cf * CF(0, 1.6, 0), C.Stone)
		block(parent, V(1.8, 0.45, 0.45), cf * CF(0, 2.3, 0), C.Stone)
	else
		block(parent, V(2.4, 1.6, 0.7), cf * CF(0, 0.8, 0), C.Stone2)
		block(parent, V(2.6, 0.3, 0.9), cf * CF(0, 1.7, 0), C.Stone)
	end
	-- холмик могилы
	block(parent, V(2.2, 0.4, 3.6), cf * CF(0, 0.15, 1.9), C.Grass, Enum.Material.Ground, { CanCollide = false })
end

local function fence(parent, a, b, color)
	local d = b - a
	local n = math.max(1, math.floor(d.Magnitude / 2.2))
	for i = 0, n do
		local p = a + d * (i / n)
		block(parent, V(0.3, 2.6, 0.3), CF(p + V(0, 1.3, 0)), color or C.Black, Enum.Material.Metal)
		wedge(parent, V(0.3, 0.5, 0.3), CF(p + V(0, 2.85, 0)), color or C.Black, Enum.Material.Metal)
	end
	local mid = (a + b) / 2
	local cf = CFrame.lookAt(mid, b)
	block(parent, V(0.18, 0.18, d.Magnitude), cf * CF(0, 2.1, 0), color or C.Black, Enum.Material.Metal)
	block(parent, V(0.18, 0.18, d.Magnitude), cf * CF(0, 0.8, 0), color or C.Black, Enum.Material.Metal)
end

local function lanternPost(parent, pos, h)
	h = h or 7
	block(parent, V(0.5, h, 0.5), CF(pos + V(0, h / 2, 0)), C.Black, Enum.Material.Metal)
	block(parent, V(1.8, 0.3, 0.3), CF(pos + V(0.6, h - 0.3, 0)), C.Black, Enum.Material.Metal)
	local cage = block(parent, V(0.9, 1.1, 0.9), CF(pos + V(1.3, h - 1.2, 0)), C.Black, Enum.Material.Metal, { CanCollide = false, Transparency = 0.2 })
	local flame = neon(parent, V(0.55, 0.7, 0.55), CF(pos + V(1.3, h - 1.2, 0)), C.Orange)
	H.light(flame, C.Orange, 16, 1.4)
	wedge(parent, V(1.1, 0.5, 1.1), CF(pos + V(1.3, h - 0.45, 0)), C.Black, Enum.Material.Metal)
	return cage
end

local function bat(parent, pos, r, speed)
	local m = Instance.new("Model")
	m.Name = "Bat"
	m.Parent = parent
	local body = block(m, V(0.6, 0.5, 0.9), CF(pos + V(r, 0, 0)), C.Black, Enum.Material.SmoothPlastic, { CanCollide = false })
	for _, s in ipairs({ -1, 1 }) do
		wedge(m, V(0.1, 0.6, 1.6), CF(pos + V(r + 0.9 * s, 0.1, 0)) * ANG(0, 0, rad(-70 * s)), C.Black, Enum.Material.SmoothPlastic)
	end
	neon(m, V(0.3, 0.1, 0.05), CF(pos + V(r, 0.08, -0.46)), C.Ember)
	-- летает по кругу вокруг pos (вращается вся модель)
	m.WorldPivot = CF(pos)
	m:SetAttribute("Spin", speed)
	m:SetAttribute("SpinAxis", "Y")
	m:SetAttribute("BobAmp", 0.8)
	m:SetAttribute("BobSpeed", 2.2)
	m.PrimaryPart = body
	return m
end

local function crow(parent, pos, yaw)
	local cf = CF(pos) * ANG(0, yaw or 0, 0)
	block(parent, V(0.5, 0.5, 0.9), cf * CF(0, 0.35, 0), C.Black, Enum.Material.SmoothPlastic, { CanCollide = false })
	block(parent, V(0.4, 0.4, 0.4), cf * CF(0, 0.75, -0.4), C.Black, Enum.Material.SmoothPlastic, { CanCollide = false })
	wedge(parent, V(0.15, 0.15, 0.4), cf * CF(0, 0.7, -0.75) * ANG(rad(90), 0, 0), C.Gold, Enum.Material.SmoothPlastic)
	wedge(parent, V(0.3, 0.12, 0.6), cf * CF(0, 0.3, 0.6) * ANG(rad(180), 0, 0), C.Black, Enum.Material.SmoothPlastic)
end

local function ghost(parent, pos, s)
	s = s or 1
	local m = Instance.new("Model")
	m.Name = "Ghost"
	m.Parent = parent
	local body = block(m, V(2.2 * s, 2.4 * s, 1.8 * s), CF(pos + V(0, 1.6 * s, 0)), C.Ghost, Enum.Material.SmoothPlastic, { CanCollide = false, Transparency = 0.55 })
	block(m, V(1.8 * s, 1.6 * s, 1.6 * s), CF(pos + V(0, 3.4 * s, 0)), C.Ghost, Enum.Material.SmoothPlastic, { CanCollide = false, Transparency = 0.55 })
	for i = -1, 1 do
		wedge(m, V(0.7 * s, 0.9 * s, 1.6 * s), CF(pos + V(i * 0.7 * s, 0.05, 0)) * ANG(0, 0, rad(180)), C.Ghost, Enum.Material.SmoothPlastic).Transparency = 0.55
	end
	for _, sx in ipairs({ -1, 1 }) do
		block(m, V(0.3 * s, 0.45 * s, 0.05), CF(pos + V(0.35 * s * sx, 3.5 * s, -0.81 * s)), C.Black, Enum.Material.SmoothPlastic, { CanCollide = false })
	end
	m.PrimaryPart = body
	m:SetAttribute("BobAmp", 1.2)
	m:SetAttribute("BobSpeed", 1.1)
	return m
end

-- готическая крыша-шпиль из уменьшающихся блоков
local function spire(parent, cf, w, h, color)
	local n = 5
	for i = 0, n - 1 do
		local k = 1 - i / n
		block(parent, V(w * k, h / n, w * k), cf * CF(0, h / n * (i + 0.5), 0) * ANG(0, rad(45 * (i % 2)), 0), color or C.DeepPurple)
	end
	block(parent, V(0.3, h * 0.35, 0.3), cf * CF(0, h + h * 0.17, 0), C.Gold, Enum.Material.Metal, { CanCollide = false })
end

local function tower(parent, base, w, h, ruined, rng)
	block(parent, V(w, h, w), CF(base + V(0, h / 2, 0)), C.Stone2)
	-- окна
	for i = 1, math.floor(h / 7) do
		for k = 0, 3 do
			local cf = CF(base + V(0, i * 7 - 2, 0)) * ANG(0, k * math.pi / 2, 0) * CF(0, 0, -w / 2 - 0.05)
			neon(parent, V(1.1, 2.2, 0.1), cf, C.Window)
			wedge(parent, V(1.1, 0.7, 0.12), cf * CF(0, 1.45, 0), C.Window, Enum.Material.Neon)
		end
	end
	if ruined then
		for i = 1, 5 do
			local a = i / 5 * math.pi * 2
			local hh = rng:NextNumber(1, 4)
			block(parent, V(w * 0.35, hh, w * 0.35), CF(base + V(math.cos(a) * w * 0.35, h + hh / 2, math.sin(a) * w * 0.35)) * ANG(0, a, rad(rng:NextNumber(-10, 10))), C.Stone2)
		end
	else
		block(parent, V(w + 1.2, 1, w + 1.2), CF(base + V(0, h + 0.5, 0)), C.Stone)
		spire(parent, CF(base + V(0, h + 1, 0)), w + 0.4, w * 2.2, C.DeepPurple)
	end
end

local function house(parent, pos, yaw, s)
	s = s or 1
	local cf = CF(pos) * ANG(0, yaw, 0)
	block(parent, V(10 * s, 7 * s, 8 * s), cf * CF(0, 3.5 * s, 0), C.Rock2, Enum.Material.WoodPlanks)
	for _, sx in ipairs({ -1, 1 }) do
		wedge(parent, V(10.6 * s, 4.5 * s, 4.6 * s), cf * CF(0, 9.25 * s, 2.3 * s * sx) * ANG(0, sx == 1 and math.pi or 0, 0), C.Burgundy, Enum.Material.Slate, true)
	end
	block(parent, V(1.2 * s, 4 * s, 1.2 * s), cf * CF(3 * s, 10 * s, 1.5 * s), C.Stone2)
	block(parent, V(2.2 * s, 3.8 * s, 0.2), cf * CF(0, 1.9 * s, -4.05 * s), C.Bark, Enum.Material.Wood)
	for _, sx in ipairs({ -1, 1 }) do
		neon(parent, V(1.6 * s, 1.6 * s, 0.1), cf * CF(3 * s * sx, 4 * s, -4.05 * s), C.Window)
	end
	H.light(block(parent, V(0.5, 0.5, 0.5), cf * CF(0, 4 * s, -5 * s), C.Black, Enum.Material.SmoothPlastic, { Transparency = 1, CanCollide = false }), C.Window, 14, 1)
end

local function runeCircle(parent, pos, r, color)
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		neon(parent, V(0.5, 0.06, 1.4), CF(pos + V(math.cos(a) * r, 0.06, math.sin(a) * r)) * ANG(0, -a, 0), color or C.Rune)
	end
	for i = 0, 2 do
		neon(parent, V(r * 1.6, 0.05, 0.25), CF(pos + V(0, 0.05, 0)) * ANG(0, i * math.pi / 3, 0), color or C.Rune, { Transparency = 0.3 })
	end
end

-- круглый остров со скальным низом
local function islandDisc(parent, center, R, rng, placeable)
	local top = H.cylinderY(parent, "IslandTop", R, 4, center + V(0, -2, 0), C.Ground)
	top:SetAttribute("Placeable", placeable or nil)
	local layers = { { 0.95, 10, -8 }, { 0.78, 14, -19 }, { 0.56, 16, -33 }, { 0.32, 16, -48 }, { 0.14, 14, -62 } }
	for i, l in ipairs(layers) do
		H.cylinderY(parent, "Bedrock" .. i, R * l[1], l[2], center + V(rng:NextNumber(-4, 4), l[3], rng:NextNumber(-4, 4)), (i % 2 == 0) and C.Rock or C.Rock2)
	end
	for i = 0, 23 do
		local a = i / 24 * math.pi * 2
		local s = rng:NextNumber(10, 18)
		block(parent, V(s, rng:NextNumber(5, 8), s), CF(center + V(math.cos(a) * (R - 4), -3.5, math.sin(a) * (R - 4))) * ANG(0, a + rng:NextNumber(-0.3, 0.3), 0), (i % 2 == 0) and C.Rock or C.Rock2)
	end
	local tip = neon(parent, V(8, 18, 8), CF(center + V(0, -76, 0)) * ANG(rad(8), rad(45), 0), C.Ember)
	H.light(tip, C.Orange, 40, 2)
	return top
end

local function patches(parent, center, R, rng, n, placeable)
	for i = 1, n do
		local a, d = rng:NextNumber(0, math.pi * 2), rng:NextNumber(0, R - 14)
		local w, l = rng:NextNumber(10, 26), rng:NextNumber(10, 22)
		local p = block(parent, V(w, 0.2, l), CF(center + V(math.cos(a) * d, 0.02 + i * 0.001, math.sin(a) * d)) * ANG(0, rng:NextNumber(0, 3), 0),
			(i % 3 == 0) and C.GrassP or ((i % 3 == 1) and C.Grass or C.Ground2), Enum.Material.Grass, { CastShadow = false })
		p:SetAttribute("Placeable", placeable or nil)
	end
end

local function surfaceSign(parent, cf, size, title, sub, titleColor, frameColor)
	local sign = block(parent, size, cf, C.Black)
	neon(parent, size + V(1, 1, -size.Z + 0.3), cf * CF(0, 0, size.Z / 2 + 0.1), frameColor or C.Orange)
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Front
	sg.LightInfluence = 0
	sg.PixelsPerStud = 30
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.Parent = sign
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, sub and 0.62 or 1)
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.RichText = true
	t.Text = title
	t.TextColor3 = titleColor or C.Orange
	t.TextStrokeTransparency = 0
	t.Parent = sg
	if sub then
		local st = t:Clone()
		st.Position = UDim2.fromScale(0.04, 0.62)
		st.Size = UDim2.fromScale(0.92, 0.34)
		st.Font = Enum.Font.GothamBold
		st.Text = sub
		st.TextColor3 = rgb(245, 230, 210)
		st.Parent = sg
	end
	return sign
end

------------------------------------------------------------------------
-- ПОРТАЛ HALLOWEEN EVENT В ГЛАВНОМ ЛОББИ
------------------------------------------------------------------------
local function buildLobbyPortal()
	local lobby = workspace:FindFirstChild("VoidTDLobby")
	if not lobby or lobby:FindFirstChild("HalloweenGate") then
		return
	end
	local L = Config.Lobby
	local z = L.Zones.HalloweenPortal
	if not z then
		return
	end
	local m = Instance.new("Model")
	m.Name = "HalloweenGate"
	local zc = L.Center + z.Offset
	local out = V(z.Offset.X, 0, z.Offset.Z).Unit
	local pc = zc + out * 9
	local face = CFrame.lookAt(pc, pc - out)
	local R = 13
	-- готическая арка: камни по окружности + шипы
	for i = 0, 19 do
		local a = i / 20 * math.pi * 2
		local cf = face * CF(math.cos(a) * R, R + 1 + math.sin(a) * R, 0) * ANG(0, 0, a)
		block(m, V(4, 3.4, 3), cf, (i % 2 == 0) and C.Stone2 or C.Black)
		if i % 2 == 0 then
			wedge(m, V(1.2, 2.4, 1.2), cf * CF(1.8, 0, 0) * ANG(0, 0, rad(-90)), C.Black, Enum.Material.Slate)
		end
		if i % 5 == 0 then
			neon(m, V(0.6, 1.4, 0.3), cf * CF(0, 0, -1.6), C.Orange)
		end
	end
	local disc = H.part(m, { Name = "PortalDisc", Shape = Enum.PartType.Cylinder, Size = V(0.4, R * 2 - 3, R * 2 - 3), CFrame = face * CF(0, R + 1, 0) * ANG(0, rad(90), 0), Color = rgb(150, 60, 20), Material = Enum.Material.Neon, Transparency = 0.25, CanCollide = false })
	for i = 0, 2 do
		local sw = neon(m, V(0.7, R * 1.7, 0.6), face * CF(0, R + 1, -0.4) * ANG(0, 0, rad(i * 60)), (i == 1) and C.Purple or C.Orange, { Transparency = 0.35 })
		sw:SetAttribute("Spin", -1.2 - i * 0.3)
		sw:SetAttribute("SpinAxis", "Z")
	end
	H.light(disc, C.Orange, 50, 3)
	H.emitter(disc, C.Orange, { Rate = 26, Size = 0.7, SpeedMin = 2, SpeedMax = 5 })
	fogEmitter(block(m, V(20, 1, 6), face * CF(0, 0.5, 0), C.Stone2), C.Fog, 3, 7)
	-- тыквы и фонари по сторонам
	for _, sx in ipairs({ -1, 1 }) do
		pumpkin(m, (face * CF(sx * 16, 0, 2)).Position, 2.2, true, 0)
		pumpkin(m, (face * CF(sx * 19, 0, -1)).Position, 1.4, true, 0.5)
		lanternPost(m, (face * CF(sx * 12, 0, 5)).Position, 9)
	end
	surfaceSign(m, face * CF(0, R * 2 + 7, 0) * ANG(0, math.pi, 0), V(30, 7, 1), "HALLOWEEN EVENT", "🎃 остров, кейс, боссы и Halloween Coins", C.Orange, C.Orange)
	for i = 1, 3 do
		bat(m, zc + V(0, 22 + i * 3, 0), 8 + i * 3, 0.6 + i * 0.2)
	end
	H.calm(m)
	m.Parent = lobby
end

------------------------------------------------------------------------
-- ХЭЛЛОУИН-ОСТРОВ
------------------------------------------------------------------------
local function buildIsland()
	local existing = workspace:FindFirstChild("VoidTDHalloween")
	if existing then
		return existing
	end
	local I = Config.HalloweenIsland
	local c = I.Center
	local rng = Random.new(1031)
	local m = Instance.new("Model")
	m.Name = "VoidTDHalloween"

	islandDisc(m, c, I.Radius, rng, false)
	patches(m, c, I.Radius, rng, 14, false)

	-- ЛУНА и туман
	local moon = neon(m, V(70, 70, 70), CF(c + V(-40, 150, -330)), C.Moon, { Shape = Enum.PartType.Ball })
	block(m, V(68, 68, 68), CF(c + V(-22, 156, -318)), rgb(20, 12, 28), Enum.Material.SmoothPlastic, { Shape = Enum.PartType.Ball, CanCollide = false, Transparency = 0.25 })
	H.light(moon, C.Moon, 60, 1)
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2
		fogEmitter(block(m, V(30, 1, 30), CF(c + V(math.cos(a) * 55, 0.5, math.sin(a) * 55)), C.Ground, Enum.Material.Slate, { Transparency = 1, CanCollide = false }), C.Fog, 1.5, 9)
	end

	-- ЗАМОК на дальнем краю
	local cz = c + V(0, 0, -90)
	block(m, V(46, 22, 16), CF(cz + V(0, 11, 0)), C.Stone2)
	block(m, V(48, 1.5, 18), CF(cz + V(0, 22.7, 0)), C.Stone)
	for i = -5, 5 do
		block(m, V(2.4, 2.4, 2), CF(cz + V(i * 4.2, 24.6, -8.2)), C.Stone2)
	end
	tower(m, cz + V(0, 0, 2), 12, 36, false, rng)
	tower(m, cz + V(-25, 0, 2), 9, 30, false, rng)
	tower(m, cz + V(25, 0, 2), 9, 30, false, rng)
	for _, sx in ipairs({ -1, 1 }) do
		for k = 0, 3 do
			local cf = CF(cz + V(sx * (6 + k * 4.5), 9, -8.05))
			neon(m, V(1.6, 4, 0.1), cf, C.Window)
			wedge(m, V(1.6, 1.2, 0.12), cf * CF(0, 2.6, 0), C.Window, Enum.Material.Neon)
		end
	end
	-- ворота замка
	block(m, V(8, 11, 0.6), CF(cz + V(0, 5.5, -8.3)), C.Bark, Enum.Material.Wood)
	neon(m, V(1, 1, 0.1), CF(cz + V(0, 7, -8.65)) * ANG(0, 0, rad(45)), C.Orange)
	surfaceSign(m, CF(cz + V(0, 30, -9)) * ANG(0, math.pi, 0), V(26, 6, 1), "HAUNTED HOLLOW", "Хэллоуин-остров VOID TD", C.Orange, C.Burgundy)
	-- разрушенные башни по краям
	tower(m, c + V(-78, 0, -48), 8, 18, true, rng)
	tower(m, c + V(80, 0, -44), 8, 22, true, rng)

	-- ЗОНЫ-КРУГИ
	local zf = Instance.new("Folder")
	zf.Name = "Zones"
	zf.Parent = m
	for key, z in pairs(I.Zones) do
		local sub = z.Case and "500 🎃 Halloween Coins" or nil
		H.zoneCircle(zf, key, z, c + z.Offset, sub, rgb(30, 14, 18))
	end

	-- КЕЙС: проклятый сундук на постаменте за кругом
	do
		local z = I.Zones.Case_Halloween
		local zc = c + z.Offset
		local out = V(z.Offset.X, 0, z.Offset.Z).Unit
		local sp = zc + out * 13
		H.part(m, { Name = "CaseStand", Shape = Enum.PartType.Cylinder, Size = V(2.5, 10, 10), CFrame = CF(sp + V(0, 1.25, 0)) * ANG(0, 0, rad(90)), Color = C.Black, Material = Enum.Material.Slate })
		H.part(m, { Name = "CaseStandRing", Shape = Enum.PartType.Cylinder, Size = V(0.3, 10.4, 10.4), CFrame = CF(sp + V(0, 2.4, 0)) * ANG(0, 0, rad(90)), Color = C.Gold, Material = Enum.Material.Neon, CanCollide = false })
		local okCM, CaseModels = pcall(require, Shared:WaitForChild("CaseModels"))
		if okCM then
			local cm = CaseModels.Build("Halloween").Model
			cm:ScaleTo(1.7)
			cm:PivotTo(CF(sp + V(0, 2.6, 0)) * CFrame.lookAt(Vector3.zero, -out).Rotation)
			cm:SetAttribute("Spin", 0.4)
			cm:SetAttribute("SpinAxis", "Y")
			cm.Parent = m
		end
		local glow = block(m, V(0.5, 0.5, 0.5), CF(sp + V(0, 6, 0)), C.Black, Enum.Material.SmoothPlastic, { Transparency = 1, CanCollide = false })
		H.light(glow, C.Orange, 24, 2)
		H.billboard(m, sp + V(0, 13.5, 0), "HALLOWEEN CASE", "🎃 500 Halloween Coins", C.Orange, 14)
		for i = 0, 5 do
			local a = i / 6 * math.pi * 2
			pumpkin(m, sp + V(math.cos(a) * 7.5, 0, math.sin(a) * 7.5), 1 + (i % 2) * 0.4, i % 2 == 0, a)
		end
	end

	-- ОЧЕРЕДЬ: 4 светящихся квадрата входа в бой
	do
		local Q = I.Queue
		local qc = c + Q.Offset
		block(m, V(30, 0.6, 22), CF(qc + V(0, 0.3, 0)), C.Black)
		for i, off in ipairs(Q.Pads) do
			local p = qc + off
			neon(m, V(Q.Pad + 0.6, 0.65, Q.Pad + 0.6), CF(p + V(0, 0.33, 0)), C.Orange)
			local pad = block(m, V(Q.Pad, 0.7, Q.Pad), CF(p + V(0, 0.36, 0)), rgb(40, 16, 10), Enum.Material.Glass, { Transparency = 0.15 })
			pad.Name = "QueuePad" .. i
			H.light(pad, C.Orange, 14, 1.5)
			H.emitter(pad, C.Orange, { Rate = 10, Size = 0.4, SpeedMin = 2, SpeedMax = 4, Spread = 15, Dir = Enum.NormalId.Top, LifeMin = 1, LifeMax = 2 })
			local beam = neon(m, V(Q.Pad * 0.8, 18, Q.Pad * 0.8), CF(p + V(0, 9, 0)), C.Orange, { Transparency = 0.9 })
			beam.CastShadow = false
		end
		-- арка над входом и вывеска
		for _, sx in ipairs({ -1, 1 }) do
			block(m, V(2.4, 16, 2.4), CF(qc + V(sx * 16, 8, -12)), C.Stone2)
			pumpkin(m, qc + V(sx * 16, 16, -12), 1.6, true, 0)
		end
		block(m, V(34, 2, 2.4), CF(qc + V(0, 15, -12)), C.Stone2)
		surfaceSign(m, CF(qc + V(0, 20, -12)) * ANG(0, math.pi, 0), V(26, 6, 1), "HALLOWEEN TD", "встань на квадрат • до 4 игроков • хост выбирает сложность", C.Orange, C.Orange)
		H.billboard(m, qc + V(0, 7, 0), "ВХОД В БОЙ", "встань на светящийся квадрат", C.Orange, 13)
		-- доска наград
		surfaceSign(m, CF(qc + V(24, 6, 6)) * ANG(0, rad(-90), 0) * ANG(0, math.pi, 0), V(12, 9, 0.8),
			"НАГРАДЫ", "ЛЁГКАЯ — 100 🎃\nСРЕДНЯЯ — 150 🎃\nСЛОЖНАЯ — 250 🎃\nтолько за победу", C.Gold, C.Gold)
		block(m, V(0.8, 2, 0.8), CF(qc + V(24, 1, 6)), C.Black)
	end

	-- ПРЕВЬЮ ХЭЛЛОУИНСКИХ ЮНИТОВ: статуи у круга
	do
		local uz = c + I.Zones.HalloweenUnits.Offset
		local list = { "LanternKing", "HalloweenPuppeteer", "HeadlessExecutioner", "PlagueDoctor", "PhantomKnight" }
		for i, id in ipairs(list) do
			local a = rad(140 + (i - 1) * 25)
			pcall(H.statue, m, id, uz + V(math.cos(a) * 15, 0, math.sin(a) * 15), uz, i == 1 and 4 or 3)
		end
	end

	-- БЕСТИАРИЙ: боссы на постаментах
	do
		local bz = c + I.Zones.Bestiary.Offset
		local okE, EnemyModels = pcall(require, Shared:WaitForChild("EnemyModels"))
		if okE then
			for i, id in ipairs({ "GraveWarden", "FogReaper", "CursedMonarch" }) do
				local pos = bz + V(16, 0, (i - 2) * 12)
				block(m, V(7, 3, 7), CF(pos + V(0, 1.5, 0)), C.Stone2)
				neon(m, V(7.4, 0.25, 7.4), CF(pos + V(0, 2.6, 0)), ({ rgb(90, 220, 120), rgb(255, 205, 70), rgb(255, 90, 80) })[i])
				local ok, rig = pcall(EnemyModels.Build, id)
				if ok and rig then
					local model = rig.Model
					model:ScaleTo(0.75)
					local hip = (rig.HipHeight or 3) * 0.75
					local base = pos + V(0, 3 + hip, 0)
					model:PivotTo(CFrame.lookAt(base, V(bz.X, base.Y, bz.Z)))
					for _, d in ipairs(model:GetDescendants()) do
						if d:IsA("BasePart") then
							d.Anchored = true
							d.CanCollide = false
						end
					end
					model.Name = "Bestiary_" .. id
					model.Parent = m
				end
				H.billboard(m, pos + V(0, 13, 0), Config.Enemies[id].Name, ({ "босс ЛЁГКОЙ", "босс СРЕДНЕЙ", "босс СЛОЖНОЙ" })[i], ({ rgb(90, 220, 120), rgb(255, 205, 70), rgb(255, 90, 80) })[i], 10)
			end
		end
	end

	-- КЛАДБИЩЕ (восток)
	do
		local g = c + V(52, 0, 44)
		for x = 0, 3 do
			for zz = 0, 2 do
				tombstone(m, rng, g + V(x * 6 - 9, 0, zz * 7 - 7), rng:NextNumber(-0.3, 0.3))
			end
		end
		fence(m, g + V(-14, 0, -12), g + V(14, 0, -12))
		fence(m, g + V(14, 0, -12), g + V(14, 0, 14))
		fence(m, g + V(-14, 0, 14), g + V(14, 0, 14))
		crow(m, g + V(14, 2.9, 2), rad(-90))
		crow(m, g + V(-6, 2.9, -12), 0)
		ghost(m, g + V(2, 2, 2), 1.1)
		fogEmitter(block(m, V(26, 1, 24), CF(g + V(0, 0.5, 0)), C.Ground, Enum.Material.Slate, { Transparency = 1, CanCollide = false }), rgb(120, 200, 130), 2, 6)
	end

	-- ТЫКВЕННОЕ ПОЛЕ (юго-запад)
	do
		local f = c + V(-50, 0, 58)
		block(m, V(30, 0.25, 20), CF(f + V(0, 0.12, 0)), rgb(40, 28, 20), Enum.Material.Ground, { CanCollide = false })
		for x = 0, 4 do
			for zz = 0, 3 do
				pumpkin(m, f + V(x * 6 - 12 + rng:NextNumber(-1, 1), 0, zz * 5 - 7.5 + rng:NextNumber(-1, 1)), rng:NextNumber(0.8, 1.5), rng:NextInteger(1, 4) == 1, rng:NextNumber(0, 6))
			end
		end
		-- пугало
		block(m, V(0.5, 8, 0.5), CF(f + V(0, 4, -11)), C.Bark, Enum.Material.Wood)
		block(m, V(6, 0.5, 0.5), CF(f + V(0, 6, -11)), C.Bark, Enum.Material.Wood)
		block(m, V(2.2, 3, 1.2), CF(f + V(0, 5, -11)), rgb(90, 60, 40), Enum.Material.Fabric)
		pumpkin(m, f + V(0, 6.6, -11), 1.5, true, 0)
		crow(m, f + V(2.6, 6.3, -11), 0.4)
	end

	-- ДОМИКИ, МОСТ, ДЕРЕВЬЯ, ФОНАРИ, ПРИЗРАКИ, МЫШИ, РУНЫ
	house(m, c + V(-80, 0, 0), rad(80), 1)
	house(m, c + V(78, 0, 8), rad(-85), 0.9)
	-- мост к маленькому парящему островку с руинами
	do
		local a = c + V(-96, 0, -20)
		local b = a + V(-28, 0, -6)
		local mid = (a + b) / 2
		local cf = CFrame.lookAt(mid, b)
		for i = -6, 6 do
			block(m, V(5, 0.4, 1.8), cf * CF(0, -0.1 + math.abs(i) * 0.08, i * 2.1) , C.Bark, Enum.Material.WoodPlanks)
		end
		for _, sx in ipairs({ -1, 1 }) do
			block(m, V(0.2, 0.2, 28), cf * CF(sx * 2.4, 1.6, 0), C.Bark, Enum.Material.Wood, { CanCollide = false })
		end
		local isl = b + V(-8, 0, -2)
		H.cylinderY(m, "Islet", 12, 4, isl + V(0, -2, 0), C.Ground)
		H.cylinderY(m, "IsletRock", 8, 12, isl + V(0, -10, 0), C.Rock)
		tower(m, isl, 7, 14, true, rng)
		runeCircle(m, isl + V(0, 0, 8), 4, C.Rune)
	end
	local taken = { c + V(0, 0, 70) }
	for _, z in pairs(I.Zones) do
		taken[#taken + 1] = c + z.Offset
	end
	taken[#taken + 1] = c + I.Queue.Offset
	for i = 1, 26 do
		local a = rng:NextNumber(0, math.pi * 2)
		local d = rng:NextNumber(70, I.Radius - 6)
		local p = c + V(math.cos(a) * d, 0, math.sin(a) * d)
		local free = p.Z > c.Z - 70
		for _, t in ipairs(taken) do
			if (V(p.X - t.X, 0, p.Z - t.Z)).Magnitude < 15 then
				free = false
			end
		end
		if free then
			taken[#taken + 1] = p
			deadTree(m, rng, p, rng:NextNumber(0.9, 1.3))
		end
	end
	for i = 0, 9 do
		local a = i / 10 * math.pi * 2 + 0.2
		lanternPost(m, c + V(math.cos(a) * 34, 0, math.sin(a) * 34), 7)
	end
	ghost(m, c + V(-30, 3, -40), 1.3)
	ghost(m, c + V(36, 4, -60), 1)
	ghost(m, c + V(-70, 2, 30), 0.9)
	for i = 1, 6 do
		bat(m, c + V(rng:NextNumber(-60, 60), rng:NextNumber(26, 40), rng:NextNumber(-70, 40)), rng:NextNumber(8, 18), rng:NextNumber(0.5, 1.2))
	end
	runeCircle(m, c + V(0, 0, 18), 8, C.Rune)
	runeCircle(m, c + V(-20, 0, -64), 5, C.Orange)

	-- точка прибытия (не SpawnLocation: игроки появляются в главном лобби)
	block(m, V(10, 1, 10), CF(I.Spawn + V(0, 0.5, 0)), rgb(60, 26, 20))
	H.cylinderY(m, "SpawnGlow", 4.6, 0.08, I.Spawn + V(0, 1.03, 0), C.Orange, Enum.Material.Neon, { CanCollide = false, Transparency = 0.5 })
	-- портал в лобби
	do
		local z = I.Zones.ReturnPortal
		local zc = c + z.Offset
		local face = CFrame.lookAt(zc + V(0, 0, 8), zc)
		for i = 0, 11 do
			local a = i / 12 * math.pi * 2
			block(m, V(2.6, 2.2, 1.8), face * CF(math.cos(a) * 7, 8 + math.sin(a) * 7, 0) * ANG(0, 0, a), (i % 2 == 0) and C.Stone or C.Stone2)
		end
		local disc = H.part(m, { Name = "ReturnDisc", Shape = Enum.PartType.Cylinder, Size = V(0.4, 12, 12), CFrame = face * CF(0, 8, 0) * ANG(0, rad(90), 0), Color = rgb(120, 40, 210), Material = Enum.Material.Neon, Transparency = 0.25, CanCollide = false })
		H.light(disc, rgb(170, 80, 255), 24, 2)
	end

	m.WorldPivot = CF(c)
	H.calm(m)
	m.Parent = workspace
	return m
end

------------------------------------------------------------------------
-- КАРТА HAUNTED HOLLOW
------------------------------------------------------------------------
local function buildMap()
	local existing = workspace:FindFirstChild("VoidTDHalloweenMap")
	if existing then
		return existing
	end
	local MC = Config.Maps.Halloween
	local c = MC.Center
	local GY = MC.GroundY
	local size = MC.IslandSize
	local rng = Random.new(666)
	PathUtil.SetMap("Halloween")
	local m = Instance.new("Model")
	m.Name = "VoidTDHalloweenMap"

	-- земля (на неё можно ставить юнитов)
	local ground = Instance.new("Folder")
	ground.Name = "Ground"
	ground.Parent = m
	local top = block(ground, V(size.X, 4, size.Y), CF(c.X, GY - 2, c.Z), C.Ground)
	top.Name = "IslandTop"
	top:SetAttribute("Placeable", true)
	for i = 1, 22 do
		local w, d = rng:NextNumber(14, 34), rng:NextNumber(14, 30)
		local x = rng:NextNumber(-size.X / 2 + w / 2 + 2, size.X / 2 - w / 2 - 2)
		local z = rng:NextNumber(-size.Y / 2 + d / 2 + 2, size.Y / 2 - d / 2 - 2)
		local p = block(ground, V(w, 0.2, d), CF(c.X + x, GY + 0.02 + i * 0.001, c.Z + z) * ANG(0, rad(rng:NextNumber(-20, 20)), 0),
			(i % 3 == 0) and C.GrassP or ((i % 3 == 1) and C.Grass or C.Ground2), Enum.Material.Grass, { CastShadow = false })
		p:SetAttribute("Placeable", true)
	end
	-- скальный низ
	local under = Instance.new("Folder")
	under.Name = "Underside"
	under.Parent = m
	for i, l in ipairs({ { 0.92, 12, -9 }, { 0.72, 16, -22 }, { 0.5, 18, -38 }, { 0.28, 18, -55 } }) do
		block(under, V(size.X * l[1], l[2], size.Y * l[1]), CF(c.X + rng:NextNumber(-6, 6), GY + l[3], c.Z + rng:NextNumber(-6, 6)) * ANG(0, rad(rng:NextNumber(-8, 8)), 0), (i % 2 == 0) and C.Rock or C.Rock2)
	end
	for x = -size.X / 2, size.X / 2, 18 do
		for _, zs in ipairs({ -1, 1 }) do
			local s = rng:NextNumber(10, 18)
			block(under, V(s, rng:NextNumber(5, 8), s), CF(c.X + x, GY - 3.5, c.Z + zs * size.Y / 2) * ANG(0, rng:NextNumber(0, 2), 0), C.Rock2)
		end
	end
	for z = -size.Y / 2 + 18, size.Y / 2 - 18, 18 do
		for _, xs in ipairs({ -1, 1 }) do
			local s = rng:NextNumber(10, 18)
			block(under, V(s, rng:NextNumber(5, 8), s), CF(c.X + xs * size.X / 2, GY - 3.5, c.Z + z) * ANG(0, rng:NextNumber(0, 2), 0), C.Rock)
		end
	end

	-- ДОРОГА: тёмная брусчатка, оранжевые трещины, фонари по краям
	local road = Instance.new("Folder")
	road.Name = "Path"
	road.Parent = m
	local pts = PathUtil.Points
	local w = MC.PathWidth
	for i = 2, #pts do
		local a, b = pts[i - 1], pts[i]
		local len = (b - a).Magnitude
		local mid = (a + b) / 2
		local cf = CFrame.lookAt(V(mid.X, GY + 0.15, mid.Z), V(b.X, GY + 0.15, b.Z))
		block(road, V(w, 0.3, len + w), cf, C.Road, Enum.Material.Cobblestone).Name = "Road"
		block(road, V(w + 1.6, 0.22, len + w + 1.6), cf * CF(0, -0.06, 0), C.RoadEdge).Name = "RoadEdge"
		if i % 2 == 0 then
			neon(road, V(0.35, 0.05, math.min(len * 0.4, 12)), cf * CF(rng:NextNumber(-2, 2), 0.16, 0) * ANG(0, rad(rng:NextNumber(-25, 25)), 0), C.Ember)
		end
		local steps = math.floor(len / 26)
		local dir = (b - a).Unit
		local right = V(-dir.Z, 0, dir.X)
		for s2 = 1, steps do
			local p = a:Lerp(b, s2 / (steps + 1)) + right * ((s2 % 2 == 0) and 1 or -1) * (w / 2 + 2)
			lanternPost(road, V(p.X, GY, p.Z), 6)
		end
	end

	-- ПОРТАЛ ВРАГОВ (VoidPortal: PortalDisc/PortalCore нужны для вспышки при боссе)
	do
		local pm = Instance.new("Model")
		pm.Name = "VoidPortal"
		pm.Parent = m
		local start = pts[1]
		local dir = (pts[2] - start).Unit
		local R = 10
		local center = start - dir * 4 + V(0, R + 1, 0)
		local face = CFrame.lookAt(center, center + dir)
		for i = 0, 17 do
			local a = i / 18 * math.pi * 2
			local cf = face * CF(math.cos(a) * R, math.sin(a) * R, 0) * ANG(0, 0, a)
			block(pm, V(3.4, 3, 2.6), cf, (i % 2 == 0) and C.Stone2 or C.Black)
			if i % 3 == 0 then
				wedge(pm, V(1, 2.2, 1), cf * CF(1.6, 0, 0) * ANG(0, 0, rad(-90)), C.Bone, Enum.Material.SmoothPlastic)
			end
		end
		local disc = H.part(pm, { Name = "PortalDisc", Shape = Enum.PartType.Cylinder, Size = V(0.4, R * 2 - 2.4, R * 2 - 2.4), CFrame = face * ANG(0, rad(90), 0), Color = rgb(140, 50, 20), Material = Enum.Material.Neon, Transparency = 0.2, CanCollide = false })
		local core = neon(pm, V(2, 2, 2), face * CF(0, 0, -0.3) * ANG(rad(45), rad(45), 0), C.Orange)
		core.Name = "PortalCore"
		H.light(core, C.Orange, 40, 3)
		H.emitter(disc, C.Ember, { Rate = 26, Size = 0.7, SpeedMin = 2, SpeedMax = 5 })
		for i = 0, 2 do
			local sw = neon(pm, V(0.6, R * 1.6, 0.7), face * ANG(0, 0, rad(i * 60)) * CF(0, 0, -0.4), (i == 1) and C.Purple or C.Orange, { Transparency = 0.35 })
			sw:SetAttribute("Spin", -1.4 - i * 0.3)
			sw:SetAttribute("SpinAxis", "Z")
		end
		fogEmitter(disc, C.Fog, 3, 6)
	end

	-- БАЗА ИГРОКА (VoidCore): святилище-фонарь
	do
		local cm = Instance.new("Model")
		cm.Name = "VoidCore"
		cm.Parent = m
		local pos = pts[#pts]
		H.cylinderY(cm, "CoreBase", 9, 1.5, pos + V(0, 0.75, 0), C.Stone2)
		H.cylinderY(cm, "CoreRing", 9.4, 0.4, pos + V(0, 1.6, 0), C.Gold, Enum.Material.Neon, { CanCollide = false })
		for k = 0, 3 do
			local a = k / 4 * math.pi * 2 + rad(45)
			local pp = pos + V(math.cos(a) * 6.5, 0, math.sin(a) * 6.5)
			block(cm, V(1.6, 14, 1.6), CF(pp + V(0, 7, 0)), C.Black, Enum.Material.Metal)
			pumpkin(cm, pp + V(0, 14, 0), 1.3, true, a)
		end
		block(cm, V(10, 1, 10), CF(pos + V(0, 14.5, 0)) * ANG(0, rad(45), 0), C.Black, Enum.Material.Metal)
		spire(cm, CF(pos + V(0, 15, 0)), 9, 9, C.Burgundy)
		local flame = neon(cm, V(4, 6, 4), CF(pos + V(0, 8, 0)) * ANG(0, rad(45), 0), C.Orange, { Transparency = 0.15 })
		flame.Name = "CoreCrystal"
		flame:SetAttribute("Spin", 0.6)
		flame:SetAttribute("SpinAxis", "Y")
		H.light(flame, C.Orange, 40, 3)
		H.emitter(flame, C.Ember, { Rate = 20, Size = 0.6, SpeedMin = 1, SpeedMax = 3, Accel = V(0, 3, 0) })
		cm:SetAttribute("CoreCenter", pos + V(0, 8, 0))
	end

	-- ДЕКОР: кладбище, тыквенные поля, готические здания, лес — только вдали от дороги
	local taken = { pts[1], pts[#pts], MC.BattleSpawn }
	local function free(p, pathDist, sep)
		if PathUtil.DistanceToPath(p) < pathDist then
			return false
		end
		if math.abs(p.X - c.X) > size.X / 2 - 6 or math.abs(p.Z - c.Z) > size.Y / 2 - 6 then
			return false
		end
		for _, t in ipairs(taken) do
			if V(p.X - t.X, 0, p.Z - t.Z).Magnitude < sep then
				return false
			end
		end
		return true
	end
	local function spot(pathDist, sep, tries)
		for _ = 1, tries or 40 do
			local p = V(c.X + rng:NextNumber(-size.X / 2, size.X / 2), GY, c.Z + rng:NextNumber(-size.Y / 2, size.Y / 2))
			if free(p, pathDist, sep) then
				taken[#taken + 1] = p
				return p
			end
		end
	end
	local decor = Instance.new("Folder")
	decor.Name = "Decor"
	decor.Parent = m
	-- кладбище
	for _ = 1, 3 do
		local g = spot(16, 26)
		if g then
			for k = 1, 6 do
				tombstone(decor, rng, g + V(rng:NextNumber(-7, 7), 0, rng:NextNumber(-7, 7)), rng:NextNumber(-0.4, 0.4))
			end
			if rng:NextInteger(1, 2) == 1 then
				crow(decor, g + V(0, 2.9, 0), rng:NextNumber(0, 6))
			end
			fogEmitter(block(decor, V(16, 1, 16), CF(g + V(0, 0.5, 0)), C.Ground, Enum.Material.Slate, { Transparency = 1, CanCollide = false }), rgb(120, 200, 130), 1, 5)
		end
	end
	-- поля тыкв
	for _ = 1, 4 do
		local f = spot(12, 20)
		if f then
			for k = 1, 7 do
				pumpkin(decor, f + V(rng:NextNumber(-6, 6), 0, rng:NextNumber(-6, 6)), rng:NextNumber(0.8, 1.6), rng:NextInteger(1, 3) == 1, rng:NextNumber(0, 6))
			end
		end
	end
	-- готические здания
	for k = 1, 3 do
		local p = spot(22, 34)
		if p then
			if k == 1 then
				tower(decor, p, 10, 26, false, rng)
			elseif k == 2 then
				house(decor, p, rng:NextNumber(0, 6), 1.1)
			else
				tower(decor, p, 8, 16, true, rng)
			end
		end
	end
	-- лес мёртвых деревьев
	for _ = 1, 30 do
		local p = spot(9, 9, 12)
		if p then
			deadTree(decor, rng, p, rng:NextNumber(0.8, 1.3))
		end
	end
	-- призраки, мыши, туман, руны
	for _ = 1, 4 do
		local p = spot(10, 12, 12)
		if p then
			ghost(decor, p + V(0, 3, 0), rng:NextNumber(0.8, 1.2))
		end
	end
	for _ = 1, 6 do
		bat(decor, V(c.X + rng:NextNumber(-110, 110), GY + rng:NextNumber(24, 40), c.Z + rng:NextNumber(-90, 90)), rng:NextNumber(8, 16), rng:NextNumber(0.5, 1.2))
	end
	for i = 0, 5 do
		fogEmitter(block(decor, V(40, 1, 40), CF(c.X + (i % 3 - 1) * 85, GY + 0.5, c.Z + (i < 3 and -50 or 50)), C.Ground, Enum.Material.Slate, { Transparency = 1, CanCollide = false }), C.Fog, 1.2, 9)
	end
	local moon = neon(decor, V(60, 60, 60), CF(c + V(60, 140, -300)), C.Moon, { Shape = Enum.PartType.Ball })
	H.light(moon, C.Moon, 60, 1)

	-- площадка прибытия
	local bs = MC.BattleSpawn
	block(m, V(8, 1, 8), CF(bs.X, GY + 0.5, bs.Z), rgb(60, 26, 20)).Name = "BattlePad"
	neon(m, V(7, 0.05, 7), CF(bs.X, GY + 1.03, bs.Z), C.Orange, { Transparency = 0.6 }).Name = "BattlePadGlow"

	PathUtil.SetMap("Void")
	H.calm(m)
	m.Parent = workspace
	return m
end

function HalloweenWorld.Build(helpers)
	H = helpers
	buildLobbyPortal()
	buildIsland()
	return buildMap()
end

return HalloweenWorld
]======] }

for _, f in ipairs(FILES) do
	install(f[1], f[2], f[3], f[4])
end
for _, n in ipairs({ "VoidTDMap", "VoidTDLobby" }) do
	local oldMap = workspace:FindFirstChild(n)
	if oldMap then oldMap:Destroy() end
end
local ok, err = pcall(function() require(SSS.VoidTDServer.MapBuilder).Build() end)
if not ok then warn("[VOID TD] Карта построится при запуске: " .. tostring(err)) end
print("[VOID TD] Часть 2/3 установлена" .. (1 == 2 and ". Готово! Сохрани место и нажми Play." or ". Вставь следующую часть."))
