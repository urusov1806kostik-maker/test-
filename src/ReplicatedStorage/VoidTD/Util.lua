--!nocheck
-- VOID TD :: Util
-- Мелкие общие помощники (без состояния). Сервер и клиент.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("VoidTD")
local Config = require(Shared:WaitForChild("Config"))

local Util = {}

-- Та же функция, что и Config.FormatNumber: 1234 -> "1,234", 15000 -> "15.0K", 1500000 -> "1.5M"
Util.FormatNumber = Config.FormatNumber

------------------------------------------------------------------------
-- Таблицы
------------------------------------------------------------------------

-- Глубокая копия простых таблиц. Таблицы с метатаблицей и значения Roblox
-- (Vector3, Color3, ...) копируются ссылкой. Циклы и общие подтаблицы сохраняются.
function Util.DeepCopy(t, seen)
	if type(t) ~= "table" or getmetatable(t) ~= nil then
		return t
	end
	seen = seen or {}
	if seen[t] then
		return seen[t]
	end
	local copy = {}
	seen[t] = copy
	for k, v in pairs(t) do
		copy[Util.DeepCopy(k, seen)] = Util.DeepCopy(v, seen)
	end
	return copy
end

function Util.ShallowCopy(t)
	local copy = {}
	for k, v in pairs(t) do
		copy[k] = v
	end
	return copy
end

-- Число ключей в словаре
function Util.Count(t)
	local n = 0
	for _ in pairs(t) do
		n = n + 1
	end
	return n
end

-- Индекс значения в массиве (или nil)
function Util.IndexOf(list, value)
	for i, v in ipairs(list) do
		if v == value then
			return i
		end
	end
	return nil
end

------------------------------------------------------------------------
-- Случайность
------------------------------------------------------------------------

local function rand01(rng)
	if rng == nil then
		return math.random()
	elseif type(rng) == "function" then
		return rng()
	end
	return rng:NextNumber()
end

local function weightOf(entry, weightKey)
	local w
	if type(weightKey) == "function" then
		w = weightKey(entry)
	elseif weightKey ~= nil then
		w = entry[weightKey]
	else
		w = entry
	end
	w = tonumber(w) or 0
	if w ~= w or w < 0 then w = 0 end
	return w
end

-- Взвешенный выбор: roll = roll01 * сумма весов, первый элемент с roll < накопленной суммы.
-- weightKey — имя поля ("Rate"), функция entry -> вес или nil (элементы — сами числа).
-- roll01 — число 0..1 (по умолчанию math.random()). Возвращает entry, index (nil для пустого списка).
function Util.WeightedPick(list, weightKey, roll01)
	local total = 0
	local lastIndex = nil
	for i, entry in ipairs(list) do
		local w = weightOf(entry, weightKey)
		total = total + w
		if w > 0 then lastIndex = i end
	end
	if not lastIndex then
		return nil, nil
	end
	local roll = (roll01 or math.random()) * total
	local acc = 0
	for i, entry in ipairs(list) do
		acc = acc + weightOf(entry, weightKey)
		if roll < acc then
			return entry, i
		end
	end
	-- roll01 >= 1 или погрешность суммы — последний элемент с весом
	return list[lastIndex], lastIndex
end

-- Перемешать массив на месте (Фишер — Йетс). rng — Random, функция 0..1 или nil.
function Util.Shuffle(list, rng)
	for i = #list, 2, -1 do
		local j = math.min(i, math.floor(rand01(rng) * i) + 1)
		list[i], list[j] = list[j], list[i]
	end
	return list
end

-- Случайный элемент массива (nil для пустого)
function Util.Pick(list, rng)
	local n = #list
	if n == 0 then return nil end
	return list[math.min(n, math.floor(rand01(rng) * n) + 1)]
end

------------------------------------------------------------------------
-- Числа и проверки (для валидации аргументов клиента)
------------------------------------------------------------------------

-- Конечное число (не NaN и не ±inf)
function Util.IsFinite(n)
	return type(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge
end

-- Vector3 с конечными координатами
function Util.IsFiniteVector3(v)
	return typeof(v) == "Vector3" and Util.IsFinite(v.X) and Util.IsFinite(v.Y) and Util.IsFinite(v.Z)
end

-- Целое число в диапазоне [lo, hi]
function Util.IsIntInRange(n, lo, hi)
	return Util.IsFinite(n) and n % 1 == 0 and n >= lo and n <= hi
end

function Util.Round(n, step)
	step = step or 1
	return math.floor(n / step + 0.5) * step
end

function Util.Lerp(a, b, t)
	return a + (b - a) * t
end

-- Горизонтальное расстояние (XZ)
function Util.FlatDistance(a, b)
	local dx, dz = a.X - b.X, a.Z - b.Z
	return math.sqrt(dx * dx + dz * dz)
end

-- Цвет -> "#rrggbb" (для RichText <font color>)
function Util.ColorHex(c)
	return string.format("#%02x%02x%02x",
		math.clamp(math.floor(c.R * 255 + 0.5), 0, 255),
		math.clamp(math.floor(c.G * 255 + 0.5), 0, 255),
		math.clamp(math.floor(c.B * 255 + 0.5), 0, 255))
end

return Util
