--!nocheck
-- VOID TD :: Path
-- Общая математика дороги. Сервер и клиент считают позиции врагов одинаково.
--
-- Активная дорога (одна на процесс) переключается через Path.SetMap(key); функции модуля
-- (PositionAt, DistanceToPath, IsPlacementClear, ...) всегда работают с активной картой.
-- Path.Get(key) отдаёт дорогу любой карты с теми же функциями — без переключения активной
-- (удобно строителям мира и проверкам).
--
-- Точки дороги в Config — (X, Z) от Center карты (у Void Center = 0,60,0, так что это мировые
-- координаты). Высота точек — GroundY.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("VoidTD")
local Config = require(Shared:WaitForChild("Config"))

local Path = {}

local EDGE_MARGIN = 3       -- отступ от края острова при установке
local END_CLEARANCE = 14    -- нельзя ставить ближе к порталу / ядру
local FALLBACK_DIR = Vector3.new(0, 0, -1)

local roads = {}            -- таблица карты -> дорога (кэш)
local active                -- активная дорога

local sqrt = math.sqrt

local function flatDistance(a, b)
	local dx, dz = a.X - b.X, a.Z - b.Z
	return sqrt(dx * dx + dz * dz)
end

------------------------------------------------------------------------
-- Математика одной дороги
------------------------------------------------------------------------

-- Позиция и направление на расстоянии d от начала дороги
local function positionAt(road, d)
	local points, cum, dirs = road.Points, road.Cumulative, road.Dirs
	local n = #points
	if d <= 0 then
		return points[1], dirs[2]
	end
	if d >= road.Length then
		return points[n], dirs[n]
	end
	for i = 2, n do
		if d <= cum[i] then
			-- отрезок нулевой длины сюда не попадает: d <= cum[i-1] сработало бы раньше
			local alpha = (d - cum[i - 1]) / (cum[i] - cum[i - 1])
			return points[i - 1] + road.Segs[i] * alpha, dirs[i]
		end
	end
	-- d = NaN: как в legacy — конец дороги
	return points[n], dirs[n]
end

-- Позиция с боковым смещением (чтобы враги не шли одной ниткой). right = (-dir.Z, 0, dir.X)
local function offsetPositionAt(road, d, lateral)
	local pos, dir = positionAt(road, d)
	if lateral and lateral ~= 0 then
		pos = pos + Vector3.new(-dir.Z, 0, dir.X) * lateral
	end
	return pos, dir
end

-- Горизонтальное расстояние от точки до ближайшего участка дороги
local function distanceToPath(road, pos)
	local best = math.huge
	local px, pz = pos.X, pos.Z
	local ax, az, abx, abz, lenSq = road.AX, road.AZ, road.ABX, road.ABZ, road.LenSq
	for i = 2, #road.Points do
		local t = 0
		local l = lenSq[i]
		if l > 0 then
			t = math.clamp(((px - ax[i]) * abx[i] + (pz - az[i]) * abz[i]) / l, 0, 1)
		end
		local dx = px - (ax[i] + abx[i] * t)
		local dz = pz - (az[i] + abz[i] * t)
		local d = sqrt(dx * dx + dz * dz)
		if d < best then
			best = d
		end
	end
	return best
end

-- Доля пройденного пути (без зажима: 0..1 внутри дороги)
local function fraction(road, d)
	if road.Length <= 0 then return 0 end
	return d / road.Length
end

-- Проверка позиции для установки (клиент — для превью, сервер — для проверки).
-- Не проверяет высоту, расстояние до других юнитов, деньги и лимиты.
local function isPlacementClear(road, pos)
	local map = road.Map
	local s = Config.Settings
	if distanceToPath(road, pos) < map.PathWidth / 2 + s.PathClearance then
		return false, "Нельзя ставить на дорогу"
	end
	local size = map.IslandSize -- Vector2: Y — размер по мировой оси Z
	local c = road.Center
	if math.abs(pos.X - c.X) > size.X / 2 - EDGE_MARGIN or math.abs(pos.Z - c.Z) > size.Y / 2 - EDGE_MARGIN then
		return false, "Слишком близко к краю"
	end
	local points = road.Points
	if flatDistance(pos, points[1]) < END_CLEARANCE then
		return false, "Слишком близко к порталу"
	end
	if flatDistance(pos, points[#points]) < END_CLEARANCE then
		return false, "Слишком близко к ядру"
	end
	return true
end

------------------------------------------------------------------------
-- Сборка дороги из конфига карты
------------------------------------------------------------------------
local function build(key, map)
	assert(type(map) == "table" and type(map.Path) == "table", "[Path] у карты нет Path: " .. tostring(key))
	assert(#map.Path >= 2, "[Path] в дороге меньше 2 точек: " .. tostring(key))
	local c = map.Center or Vector3.new()
	local y = map.GroundY or c.Y

	local road = {
		MapKey = key,
		Map = map,
		Center = c,
		Points = {},
		Cumulative = { 0 },
		Segs = {},
		Dirs = {},
		AX = {}, AZ = {}, ABX = {}, ABZ = {}, LenSq = {},
	}
	local points = road.Points
	for i, p in ipairs(map.Path) do
		points[i] = Vector3.new(c.X + p[1], y, c.Z + p[2])
	end

	local n = #points
	for i = 2, n do
		local a, b = points[i - 1], points[i]
		local seg = b - a
		local len = seg.Magnitude
		road.Segs[i] = seg
		road.Cumulative[i] = road.Cumulative[i - 1] + len
		road.Dirs[i] = len > 0 and seg.Unit or nil
		road.AX[i], road.AZ[i] = a.X, a.Z
		road.ABX[i], road.ABZ[i] = b.X - a.X, b.Z - a.Z
		road.LenSq[i] = road.ABX[i] * road.ABX[i] + road.ABZ[i] * road.ABZ[i]
	end
	-- у отрезков нулевой длины направление берём от соседей (без NaN)
	local last = nil
	for i = 2, n do
		if road.Dirs[i] then last = road.Dirs[i] elseif last then road.Dirs[i] = last end
	end
	local nextDir = nil
	for i = n, 2, -1 do
		if road.Dirs[i] then nextDir = road.Dirs[i] else road.Dirs[i] = nextDir or FALLBACK_DIR end
	end
	road.Length = road.Cumulative[n]

	-- функции дороги (вызов через точку, как у модуля)
	road.PositionAt = function(d) return positionAt(road, d) end
	road.OffsetPositionAt = function(d, lateral) return offsetPositionAt(road, d, lateral) end
	road.DistanceToPath = function(pos) return distanceToPath(road, pos) end
	road.Fraction = function(d) return fraction(road, d) end
	road.IsPlacementClear = function(pos) return isPlacementClear(road, pos) end
	road.FlatDistance = flatDistance
	return road
end

local function resolve(key)
	local maps = Config.Maps
	local map = (maps and key ~= nil and maps[key]) or Config.Map
	return map.Key or "Void", map
end

------------------------------------------------------------------------
-- API модуля
------------------------------------------------------------------------

-- Дорога карты key (неизвестный ключ — Void). Активную карту не меняет.
function Path.Get(key)
	local k, map = resolve(key)
	local road = roads[map]
	if not road then
		road = build(k, map)
		roads[map] = road
	end
	return road
end

-- Сделать карту активной (Void / Halloween). Сервер и клиент вызывают при смене карты.
function Path.SetMap(key)
	active = Path.Get(key)
	Path.Road = active
	Path.Points = active.Points
	Path.Length = active.Length
	Path.MapKey = active.MapKey
	Path.Map = active.Map
	return active
end

function Path.Fraction(d)
	return fraction(active, d)
end

function Path.PositionAt(d)
	return positionAt(active, d)
end

function Path.OffsetPositionAt(d, lateral)
	return offsetPositionAt(active, d, lateral)
end

function Path.DistanceToPath(pos)
	return distanceToPath(active, pos)
end

function Path.FlatDistance(a, b)
	return flatDistance(a, b)
end

function Path.IsPlacementClear(pos)
	return isPlacementClear(active, pos)
end

Path.SetMap("Void")

return Path
