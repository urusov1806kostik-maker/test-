--!nocheck
-- Мок Roblox API для прогона VOID TD в Luau CLI. Правило: только настоящие API Roblox и их поведение;
-- нарушения (нет такого свойства/класса/enum, не тот тип, не тот realm) копятся в M.problems.
local M = {}
local rawtypeof = typeof
local TYPENAME = {} -- метатаблица -> typeof
M.problems, M.errors = {}, {}
M.strictErrors = true -- true: ошибка в обработчике/потоке пробрасывается вызывающему; false: копится в M.errors
M.envRealm = setmetatable({}, { __mode = "k" }) -- env скрипта -> "server" | "client" (ставит env.luau)
M.isStudio, M.epoch, M.now = true, 1700000000, 0
M.mainThread = coroutine.running()
M.log = function() end -- хук: сервер -> клиент (имя ремоута, аргументы)

local function realmOf(fenv) return M.envRealm[fenv] end
local seenFor = setmetatable({}, { __mode = "k" }) -- дедупликация на каждый список M.problems (M.setup создаёт новый)
local function gameWhere() -- первый кадр кода игры (чанк "Service.Path"), иначе первый кадр теста
	local fallback = "?"
	for lv = 3, 40 do
		local s, l = debug.info(lv, "sl")
		if not s then break end
		if s ~= "[C]" and not s:find("/", 1, true) then return s .. ":" .. tostring(l) end
		if fallback == "?" and s ~= "[C]" and not s:find("mock%.luau") and not s:find("env%.luau") then fallback = s:match("[^/]*$") .. ":" .. tostring(l) end
	end
	return fallback
end
M.where = gameWhere
function M.problem(msg)
	local where = gameWhere()
	local key = msg .. " @ " .. where
	local seen = seenFor[M.problems] or {}
	seenFor[M.problems] = seen
	local p = seen[key]
	if p then p.count += 1; return end
	p = { msg = msg, where = where, count = 1 }
	seen[key] = p
	table.insert(M.problems, p)
	print("API: " .. key)
end
function M.reportError(msg)
	if M.strictErrors then error(msg, 0) end
	table.insert(M.errors, msg)
	print("ERROR: " .. msg)
end
local function fail(msg) error(gameWhere() .. ": " .. msg, 0) end -- ошибка с местом в коде игры

------------------------------------------------------------------ datatypes
local function datatype(name, methods, getters)
	local mt = { __newindex = function(_, k) error(tostring(k) .. " cannot be assigned to (" .. name .. ")", 2) end }
	mt.__index = function(t, k)
		local g = getters and getters[k]
		if g then return g(t) end
		local m = methods and methods[k]
		if m ~= nil then return m end
		error(tostring(k) .. " is not a valid member of " .. name, 2)
	end
	TYPENAME[mt] = name
	return mt
end
local function is(v, mt) return type(v) == "table" and getmetatable(v) == mt end
local function num(v, what) if v ~= nil and type(v) ~= "number" then fail(what .. ": number expected, got " .. M.typeof(v)) end return v or 0 end

-- Vector3
local V3, V3mt = {}, nil
local function v3(x, y, z) return setmetatable({ X = x, Y = y, Z = z }, V3mt) end
V3mt = datatype("Vector3", V3, {
	Magnitude = function(v) return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z) end,
	Unit = function(v) local m = math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z); return v3(v.X / m, v.Y / m, v.Z / m) end, -- 0/0 = NaN, как в Roblox
	x = function(v) return v.X end, y = function(v) return v.Y end, z = function(v) return v.Z end,
})
V3mt.__index = (function(old) return function(t, k) if k == "magnitude" then k = "Magnitude" elseif k == "unit" then k = "Unit" end return old(t, k) end end)(V3mt.__index)
local function chk3(a, b, op) if not (is(a, V3mt) and is(b, V3mt)) then fail("invalid Vector3 " .. op .. " (" .. M.typeof(a) .. ", " .. M.typeof(b) .. ")") end end
V3mt.__add = function(a, b) chk3(a, b, "+"); return v3(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
V3mt.__sub = function(a, b) chk3(a, b, "-"); return v3(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
V3mt.__unm = function(a) return v3(-a.X, -a.Y, -a.Z) end
V3mt.__mul = function(a, b)
	if type(a) == "number" and is(b, V3mt) then return v3(b.X * a, b.Y * a, b.Z * a) elseif type(b) == "number" and is(a, V3mt) then return v3(a.X * b, a.Y * b, a.Z * b) end
	chk3(a, b, "*"); return v3(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
V3mt.__div = function(a, b)
	if type(b) == "number" and is(a, V3mt) then return v3(a.X / b, a.Y / b, a.Z / b) elseif type(a) == "number" and is(b, V3mt) then return v3(a / b.X, a / b.Y, a / b.Z) end
	chk3(a, b, "/"); return v3(a.X / b.X, a.Y / b.Y, a.Z / b.Z)
end
V3mt.__idiv = function(a, b) local q = V3mt.__div(a, b); return v3(math.floor(q.X), math.floor(q.Y), math.floor(q.Z)) end
V3mt.__eq = function(a, b) return a.X == b.X and a.Y == b.Y and a.Z == b.Z end
V3mt.__tostring = function(v) return tostring(v.X) .. ", " .. tostring(v.Y) .. ", " .. tostring(v.Z) end
function V3.new(x, y, z) return v3(num(x, "Vector3.new"), num(y, "Vector3.new"), num(z, "Vector3.new")) end
function V3.Dot(a, b) chk3(a, b, "Dot"); return a.X * b.X + a.Y * b.Y + a.Z * b.Z end
function V3.Cross(a, b) chk3(a, b, "Cross"); return v3(a.Y * b.Z - a.Z * b.Y, a.Z * b.X - a.X * b.Z, a.X * b.Y - a.Y * b.X) end
function V3.Lerp(a, b, t) chk3(a, b, "Lerp"); return v3(a.X + (b.X - a.X) * t, a.Y + (b.Y - a.Y) * t, a.Z + (b.Z - a.Z) * t) end
V3.lerp = V3.Lerp
local function map3(f) return function(v) return v3(f(v.X), f(v.Y), f(v.Z)) end end
V3.Abs, V3.Floor, V3.Ceil, V3.Sign = map3(math.abs), map3(math.floor), map3(math.ceil), map3(math.sign)
function V3.Min(a, ...) for _, b in ipairs({ ... }) do a = v3(math.min(a.X, b.X), math.min(a.Y, b.Y), math.min(a.Z, b.Z)) end return a end
function V3.Max(a, ...) for _, b in ipairs({ ... }) do a = v3(math.max(a.X, b.X), math.max(a.Y, b.Y), math.max(a.Z, b.Z)) end return a end
function V3.FuzzyEq(a, b, eps) eps = eps or 1e-5; return math.abs(a.X - b.X) <= eps and math.abs(a.Y - b.Y) <= eps and math.abs(a.Z - b.Z) <= eps end
function V3.Angle(a, b, axis) local c = V3.Cross(a, b); local ang = math.atan2(c.Magnitude, V3.Dot(a, b)); return (axis and V3.Dot(c, axis) < 0) and -ang or ang end
V3.zero, V3.one, V3.xAxis, V3.yAxis, V3.zAxis = v3(0, 0, 0), v3(1, 1, 1), v3(1, 0, 0), v3(0, 1, 0), v3(0, 0, 1)
local NORMALS = { Right = v3(1, 0, 0), Left = v3(-1, 0, 0), Top = v3(0, 1, 0), Bottom = v3(0, -1, 0), Back = v3(0, 0, 1), Front = v3(0, 0, -1) }
function V3.FromNormalId(n) return NORMALS[n.Name] end
function V3.FromAxis(a) return ({ X = V3.xAxis, Y = V3.yAxis, Z = V3.zAxis })[a.Name] end
M.Vector3 = setmetatable({}, { __index = V3, __newindex = function() error("Vector3 is read-only", 2) end })
M.V3mt = V3mt

-- Vector2
local V2, V2mt = {}, nil
local function v2(x, y) return setmetatable({ X = x, Y = y }, V2mt) end
V2mt = datatype("Vector2", V2, {
	Magnitude = function(v) return math.sqrt(v.X * v.X + v.Y * v.Y) end,
	Unit = function(v) local m = math.sqrt(v.X * v.X + v.Y * v.Y); return v2(v.X / m, v.Y / m) end,
	x = function(v) return v.X end, y = function(v) return v.Y end,
})
local function chk2(a, b, op) if not (is(a, V2mt) and is(b, V2mt)) then fail("invalid Vector2 " .. op) end end
V2mt.__add = function(a, b) chk2(a, b, "+"); return v2(a.X + b.X, a.Y + b.Y) end
V2mt.__sub = function(a, b) chk2(a, b, "-"); return v2(a.X - b.X, a.Y - b.Y) end
V2mt.__unm = function(a) return v2(-a.X, -a.Y) end
V2mt.__mul = function(a, b) if type(a) == "number" then return v2(b.X * a, b.Y * a) elseif type(b) == "number" then return v2(a.X * b, a.Y * b) end chk2(a, b, "*"); return v2(a.X * b.X, a.Y * b.Y) end
V2mt.__div = function(a, b) if type(b) == "number" then return v2(a.X / b, a.Y / b) end chk2(a, b, "/"); return v2(a.X / b.X, a.Y / b.Y) end
V2mt.__eq = function(a, b) return a.X == b.X and a.Y == b.Y end
V2mt.__tostring = function(v) return tostring(v.X) .. ", " .. tostring(v.Y) end
function V2.new(x, y) return v2(num(x, "Vector2.new"), num(y, "Vector2.new")) end
function V2.Dot(a, b) return a.X * b.X + a.Y * b.Y end
function V2.Cross(a, b) return a.X * b.Y - a.Y * b.X end
function V2.Lerp(a, b, t) return v2(a.X + (b.X - a.X) * t, a.Y + (b.Y - a.Y) * t) end
function V2.Abs(v) return v2(math.abs(v.X), math.abs(v.Y)) end
function V2.Floor(v) return v2(math.floor(v.X), math.floor(v.Y)) end
function V2.Min(a, b) return v2(math.min(a.X, b.X), math.min(a.Y, b.Y)) end
function V2.Max(a, b) return v2(math.max(a.X, b.X), math.max(a.Y, b.Y)) end
function V2.FuzzyEq(a, b, eps) eps = eps or 1e-5; return math.abs(a.X - b.X) <= eps and math.abs(a.Y - b.Y) <= eps end
V2.zero, V2.one, V2.xAxis, V2.yAxis = v2(0, 0), v2(1, 1), v2(1, 0), v2(0, 1)
M.Vector2 = setmetatable({}, { __index = V2 })

-- CFrame: позиция p + матрица r (9 чисел, по строкам)
local CF, CFmt = {}, nil
local function cf(x, y, z, r) return setmetatable({ p = v3(x, y, z), _r = r }, CFmt) end
local IR = { 1, 0, 0, 0, 1, 0, 0, 0, 1 }
local function mm(a, b)
	return { a[1] * b[1] + a[2] * b[4] + a[3] * b[7], a[1] * b[2] + a[2] * b[5] + a[3] * b[8], a[1] * b[3] + a[2] * b[6] + a[3] * b[9],
		a[4] * b[1] + a[5] * b[4] + a[6] * b[7], a[4] * b[2] + a[5] * b[5] + a[6] * b[8], a[4] * b[3] + a[5] * b[6] + a[6] * b[9],
		a[7] * b[1] + a[8] * b[4] + a[9] * b[7], a[7] * b[2] + a[8] * b[5] + a[9] * b[8], a[7] * b[3] + a[8] * b[6] + a[9] * b[9] }
end
local function mv(a, x, y, z) return a[1] * x + a[2] * y + a[3] * z, a[4] * x + a[5] * y + a[6] * z, a[7] * x + a[8] * y + a[9] * z end
local function tr(a) return { a[1], a[4], a[7], a[2], a[5], a[8], a[3], a[6], a[9] } end
local function quat2r(x, y, z, w)
	local n = math.sqrt(x * x + y * y + z * z + w * w); x, y, z, w = x / n, y / n, z / n, w / n
	return { 1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w), 2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w), 2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y) }
end
local function r2quat(r)
	local t = r[1] + r[5] + r[9]
	if t > 0 then local s = math.sqrt(t + 1) * 2; return (r[8] - r[6]) / s, (r[3] - r[7]) / s, (r[4] - r[2]) / s, 0.25 * s end
	if r[1] > r[5] and r[1] > r[9] then local s = math.sqrt(1 + r[1] - r[5] - r[9]) * 2; return 0.25 * s, (r[2] + r[4]) / s, (r[3] + r[7]) / s, (r[8] - r[6]) / s end
	if r[5] > r[9] then local s = math.sqrt(1 + r[5] - r[1] - r[9]) * 2; return (r[2] + r[4]) / s, 0.25 * s, (r[6] + r[8]) / s, (r[3] - r[7]) / s end
	local s = math.sqrt(1 + r[9] - r[1] - r[5]) * 2; return (r[3] + r[7]) / s, (r[6] + r[8]) / s, 0.25 * s, (r[4] - r[2]) / s
end
local function vecArg(v, what) if not is(v, V3mt) then fail(what .. ": Vector3 expected, got " .. M.typeof(v)) end return v end
local function cfArg(c, what) if not is(c, CFmt) then fail(what .. ": CFrame expected, got " .. M.typeof(c)) end return c end
CFmt = datatype("CFrame", CF, {
	Position = function(c) return c.p end, X = function(c) return c.p.X end, Y = function(c) return c.p.Y end, Z = function(c) return c.p.Z end,
	Rotation = function(c) return cf(0, 0, 0, c._r) end,
	RightVector = function(c) local r = c._r; return v3(r[1], r[4], r[7]) end, XVector = function(c) local r = c._r; return v3(r[1], r[4], r[7]) end,
	UpVector = function(c) local r = c._r; return v3(r[2], r[5], r[8]) end, YVector = function(c) local r = c._r; return v3(r[2], r[5], r[8]) end,
	LookVector = function(c) local r = c._r; return v3(-r[3], -r[6], -r[9]) end, ZVector = function(c) local r = c._r; return v3(r[3], r[6], r[9]) end,
	lookVector = function(c) local r = c._r; return v3(-r[3], -r[6], -r[9]) end, rightVector = function(c) local r = c._r; return v3(r[1], r[4], r[7]) end,
	upVector = function(c) local r = c._r; return v3(r[2], r[5], r[8]) end,
})
CFmt.__mul = function(a, b)
	cfArg(a, "CFrame *")
	if is(b, V3mt) then local x, y, z = mv(a._r, b.X, b.Y, b.Z); return v3(x + a.p.X, y + a.p.Y, z + a.p.Z) end
	cfArg(b, "CFrame *")
	local x, y, z = mv(a._r, b.p.X, b.p.Y, b.p.Z)
	return cf(x + a.p.X, y + a.p.Y, z + a.p.Z, mm(a._r, b._r))
end
CFmt.__add = function(a, v) vecArg(v, "CFrame +"); return cf(a.p.X + v.X, a.p.Y + v.Y, a.p.Z + v.Z, a._r) end
CFmt.__sub = function(a, v) vecArg(v, "CFrame -"); return cf(a.p.X - v.X, a.p.Y - v.Y, a.p.Z - v.Z, a._r) end
CFmt.__eq = function(a, b) if a.p ~= b.p then return false end for i = 1, 9 do if a._r[i] ~= b._r[i] then return false end end return true end
CFmt.__tostring = function(c) return table.concat({ CF.GetComponents(c) }, ", ") end
function CF.new(...)
	local n, a, b, c = select("#", ...), ...
	if n == 0 then return cf(0, 0, 0, IR) end
	if is(a, V3mt) then if n >= 2 and b ~= nil then return CF.lookAt(a, vecArg(b, "CFrame.new#2")) end return cf(a.X, a.Y, a.Z, IR) end -- (pos, lookAt) — устаревшая форма
	if n == 3 then return cf(num(a, "CFrame.new"), num(b, "CFrame.new"), num(c, "CFrame.new"), IR) end
	local t = { ... }
	for i = 1, n do num(t[i], "CFrame.new") end
	if n == 7 then return cf(t[1], t[2], t[3], quat2r(t[4], t[5], t[6], t[7])) end
	if n == 12 then return cf(t[1], t[2], t[3], { t[4], t[5], t[6], t[7], t[8], t[9], t[10], t[11], t[12] }) end
	fail("CFrame.new: invalid number of arguments (" .. n .. ")")
end
local function rx(a) local c, s = math.cos(a), math.sin(a); return { 1, 0, 0, 0, c, -s, 0, s, c } end
local function ry(a) local c, s = math.cos(a), math.sin(a); return { c, 0, s, 0, 1, 0, -s, 0, c } end
local function rz(a) local c, s = math.cos(a), math.sin(a); return { c, -s, 0, s, c, 0, 0, 0, 1 } end
function CF.Angles(x, y, z) return cf(0, 0, 0, mm(mm(rx(num(x, "Angles")), ry(num(y, "Angles"))), rz(num(z, "Angles")))) end
CF.fromEulerAnglesXYZ = CF.Angles
function CF.fromEulerAnglesYXZ(x, y, z) return cf(0, 0, 0, mm(mm(ry(num(y, "YXZ")), rx(num(x, "YXZ"))), rz(num(z, "YXZ")))) end
CF.fromOrientation = CF.fromEulerAnglesYXZ
function CF.fromAxisAngle(axis, a)
	local u = vecArg(axis, "fromAxisAngle").Unit
	local x, y, z, c, s = u.X, u.Y, u.Z, math.cos(a), math.sin(a); local t = 1 - c
	return cf(0, 0, 0, { t * x * x + c, t * x * y - s * z, t * x * z + s * y, t * x * y + s * z, t * y * y + c, t * y * z - s * x, t * x * z - s * y, t * y * z + s * x, t * z * z + c })
end
function CF.fromMatrix(p, vx, vy, vz) vz = vz or V3.Cross(vx, vy).Unit; return cf(p.X, p.Y, p.Z, { vx.X, vy.X, vz.X, vx.Y, vy.Y, vz.Y, vx.Z, vy.Z, vz.Z }) end
function CF.lookAt(at, target, up)
	vecArg(at, "lookAt"); vecArg(target, "lookAt")
	local d = target - at
	if d.Magnitude < 1e-9 then return cf(at.X, at.Y, at.Z, IR) end
	local f = d.Unit
	local r = V3.Cross(f, up or V3.yAxis)
	if r.Magnitude < 1e-6 then r = V3.Cross(f, math.abs(f.Z) < 0.9 and V3.zAxis or V3.xAxis) end -- смотрим вдоль up
	r = r.Unit
	local u = V3.Cross(r, f)
	return cf(at.X, at.Y, at.Z, { r.X, u.X, -f.X, r.Y, u.Y, -f.Y, r.Z, u.Z, -f.Z })
end
function CF.lookAlong(at, dir, up) return CF.lookAt(at, at + dir, up) end
function CF.Inverse(c) local t = tr(c._r); local x, y, z = mv(t, c.p.X, c.p.Y, c.p.Z); return cf(-x, -y, -z, t) end
function CF.Lerp(a, b, t)
	cfArg(b, "CFrame:Lerp")
	local p = V3.Lerp(a.p, b.p, t)
	local ax, ay, az, aw = r2quat(a._r)
	local bx, by, bz, bw = r2quat(b._r)
	local d = ax * bx + ay * by + az * bz + aw * bw -- slerp, как в Roblox
	if d < 0 then bx, by, bz, bw, d = -bx, -by, -bz, -bw, -d end
	local k0, k1 = 1 - t, t
	if d < 0.9995 then local th = math.acos(d); local s = math.sin(th); k0, k1 = math.sin((1 - t) * th) / s, math.sin(t * th) / s end
	return cf(p.X, p.Y, p.Z, quat2r(ax * k0 + bx * k1, ay * k0 + by * k1, az * k0 + bz * k1, aw * k0 + bw * k1))
end
function CF.Orthonormalize(c) local r = c._r; return CF.fromMatrix(c.p, v3(r[1], r[4], r[7]).Unit, v3(r[2], r[5], r[8]).Unit) end
function CF.ToWorldSpace(c, ...) local o = {}; for i, x in ipairs({ ... }) do o[i] = c * x end return table.unpack(o) end
function CF.ToObjectSpace(c, ...) local inv = CF.Inverse(c); local o = {}; for i, x in ipairs({ ... }) do o[i] = inv * x end return table.unpack(o) end
function CF.PointToWorldSpace(c, ...) local o = {}; for i, v in ipairs({ ... }) do o[i] = c * vecArg(v, "PointToWorldSpace") end return table.unpack(o) end
function CF.PointToObjectSpace(c, ...) local inv = CF.Inverse(c); local o = {}; for i, v in ipairs({ ... }) do o[i] = inv * vecArg(v, "PointToObjectSpace") end return table.unpack(o) end
function CF.VectorToWorldSpace(c, ...) local o = {}; for i, v in ipairs({ ... }) do o[i] = v3(mv(c._r, v.X, v.Y, v.Z)) end return table.unpack(o) end
function CF.VectorToObjectSpace(c, ...) local t = tr(c._r); local o = {}; for i, v in ipairs({ ... }) do o[i] = v3(mv(t, v.X, v.Y, v.Z)) end return table.unpack(o) end
function CF.GetComponents(c) local r = c._r; return c.p.X, c.p.Y, c.p.Z, r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8], r[9] end
local function clamp1(x) return math.max(-1, math.min(1, x)) end
function CF.ToEulerAnglesXYZ(c) local r = c._r; return math.atan2(-r[6], r[9]), math.asin(clamp1(r[3])), math.atan2(-r[2], r[1]) end
function CF.ToEulerAnglesYXZ(c) local r = c._r; return math.asin(clamp1(-r[6])), math.atan2(r[3], r[9]), math.atan2(r[4], r[5]) end
CF.ToOrientation = CF.ToEulerAnglesYXZ
function CF.ToAxisAngle(c)
	local x, y, z, w = r2quat(c._r)
	local s = math.sqrt(math.max(0, 1 - w * w))
	if s < 1e-9 then return V3.xAxis, 0 end return v3(x / s, y / s, z / s), 2 * math.acos(clamp1(w))
end
function CF.FuzzyEq(a, b, eps)
	eps = eps or 1e-5
	for i = 1, 9 do if math.abs(a._r[i] - b._r[i]) > eps then return false end end return V3.FuzzyEq(a.p, b.p, eps)
end
CF.inverse, CF.lerp, CF.toWorldSpace, CF.toObjectSpace, CF.components = CF.Inverse, CF.Lerp, CF.ToWorldSpace, CF.ToObjectSpace, CF.GetComponents
CF.pointToWorldSpace, CF.pointToObjectSpace, CF.vectorToWorldSpace, CF.vectorToObjectSpace = CF.PointToWorldSpace, CF.PointToObjectSpace, CF.VectorToWorldSpace, CF.VectorToObjectSpace
CF.toEulerAnglesXYZ = CF.ToEulerAnglesXYZ
CF.identity = cf(0, 0, 0, IR)
M.CFrame = setmetatable({}, { __index = CF })
M.CFmt = CFmt
local IDENT = CF.identity

-- Color3
local C3, C3mt = {}, nil
local function c3(r, g, b) return setmetatable({ R = r, G = g, B = b }, C3mt) end
C3mt = datatype("Color3", C3, { r = function(c) return c.R end, g = function(c) return c.G end, b = function(c) return c.B end })
C3mt.__eq = function(a, b) return a.R == b.R and a.G == b.G and a.B == b.B end
C3mt.__tostring = function(c) return tostring(c.R) .. ", " .. tostring(c.G) .. ", " .. tostring(c.B) end
function C3.new(r, g, b) return c3(num(r, "Color3.new"), num(g, "Color3.new"), num(b, "Color3.new")) end
function C3.fromRGB(r, g, b) return c3(num(r, "Color3.fromRGB") / 255, num(g, "Color3.fromRGB") / 255, num(b, "Color3.fromRGB") / 255) end
function C3.fromHSV(h, s, v)
	local i, f = math.floor(h * 6) % 6, h * 6 - math.floor(h * 6)
	local p, q, t = v * (1 - s), v * (1 - f * s), v * (1 - (1 - f) * s)
	local rgb = ({ { v, t, p }, { q, v, p }, { p, v, t }, { p, q, v }, { t, p, v }, { v, p, q } })[i + 1]; return c3(rgb[1], rgb[2], rgb[3])
end
function C3.fromHex(hex)
	hex = tostring(hex):gsub("^#", "")
	if #hex == 3 then hex = hex:gsub(".", "%0%0") end
	local r, g, b = tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16)
	if not (r and g and b) or #hex ~= 6 then fail("Unable to convert characters to hex value") end
	return c3(r / 255, g / 255, b / 255)
end
function C3.Lerp(a, b, t) return c3(a.R + (b.R - a.R) * t, a.G + (b.G - a.G) * t, a.B + (b.B - a.B) * t) end
function C3.ToHSV(c)
	local mx, mn = math.max(c.R, c.G, c.B), math.min(c.R, c.G, c.B)
	local d, h = mx - mn, 0
	if d > 0 then if mx == c.R then h = ((c.G - c.B) / d) % 6 elseif mx == c.G then h = (c.B - c.R) / d + 2 else h = (c.R - c.G) / d + 4 end end
	return h / 6, mx > 0 and d / mx or 0, mx
end
function C3.ToHex(c) return string.format("%02x%02x%02x", math.floor(c.R * 255), math.floor(c.G * 255), math.floor(c.B * 255)) end
M.Color3 = setmetatable({}, { __index = C3 })

-- UDim / UDim2
local UDmt, U2mt
local function ud(s, o) return setmetatable({ Scale = s, Offset = o }, UDmt) end
UDmt = datatype("UDim")
UDmt.__add = function(a, b) return ud(a.Scale + b.Scale, a.Offset + b.Offset) end
UDmt.__sub = function(a, b) return ud(a.Scale - b.Scale, a.Offset - b.Offset) end
UDmt.__eq = function(a, b) return a.Scale == b.Scale and a.Offset == b.Offset end
UDmt.__tostring = function(u) return tostring(u.Scale) .. ", " .. tostring(u.Offset) end
local function u2(a, b) return setmetatable({ X = a, Y = b }, U2mt) end
local U2 = {}
U2mt = datatype("UDim2", U2, { Width = function(u) return u.X end, Height = function(u) return u.Y end })
U2mt.__add = function(a, b) return u2(a.X + b.X, a.Y + b.Y) end
U2mt.__sub = function(a, b) return u2(a.X - b.X, a.Y - b.Y) end
U2mt.__eq = function(a, b) return a.X == b.X and a.Y == b.Y end
U2mt.__tostring = function(u) return "{" .. tostring(u.X) .. "}, {" .. tostring(u.Y) .. "}" end
function U2.Lerp(a, b, t) return u2(ud(a.X.Scale + (b.X.Scale - a.X.Scale) * t, a.X.Offset + (b.X.Offset - a.X.Offset) * t), ud(a.Y.Scale + (b.Y.Scale - a.Y.Scale) * t, a.Y.Offset + (b.Y.Offset - a.Y.Offset) * t)) end
M.UDim = { new = function(s, o) return ud(num(s, "UDim.new"), num(o, "UDim.new")) end }
M.UDim2 = {
	new = function(a, b, c, d) if is(a, UDmt) then return u2(a, b) end return u2(ud(num(a, "UDim2.new"), num(b, "UDim2.new")), ud(num(c, "UDim2.new"), num(d, "UDim2.new"))) end,
	fromScale = function(a, b) return u2(ud(num(a, "fromScale"), 0), ud(num(b, "fromScale"), 0)) end,
	fromOffset = function(a, b) return u2(ud(0, num(a, "fromOffset")), ud(0, num(b, "fromOffset"))) end,
}

-- прочие значения
local function record(name, methods, getters) local mt = datatype(name, methods, getters); return function(t) return setmetatable(t, mt) end, mt end
local NR, NRmt = record("NumberRange")
M.NumberRange = { new = function(a, b) num(a, "NumberRange.new"); b = b or a; num(b, "NumberRange.new"); if b < a then fail("NumberRange: invalid range") end return NR({ Min = a, Max = b }) end }
local NK, NKmt = record("NumberSequenceKeypoint")
M.NumberSequenceKeypoint = { new = function(t, v, e) return NK({ Time = num(t, "Keypoint"), Value = num(v, "Keypoint"), Envelope = num(e, "Keypoint") }) end }
local CK, CKmt = record("ColorSequenceKeypoint")
M.ColorSequenceKeypoint = { new = function(t, c) if not is(c, C3mt) then fail("ColorSequenceKeypoint.new: Color3 expected") end return CK({ Time = num(t, "Keypoint"), Value = c }) end }
local function sequence(kind, kmt, mk, isVal)
	return function(a, b)
		local kps
		if type(a) == "table" and not getmetatable(a) then
			kps = a
			if #kps < 2 or #kps > 20 then fail(kind .. ": requires 2..20 keypoints") end
			for i, k in ipairs(kps) do if not is(k, kmt) then fail(kind .. ": keypoint expected") end if i > 1 and k.Time < kps[i - 1].Time then fail(kind .. ": keypoints must be ordered by time") end end
			if kps[1].Time ~= 0 or kps[#kps].Time ~= 1 then fail(kind .. ": first keypoint must be at 0 and last at 1") end
		elseif isVal(a) then
			kps = { mk(0, a), mk(1, b ~= nil and b or a) }
		else
			fail(kind .. ".new: invalid argument " .. M.typeof(a))
		end
		return kps
	end
end
local NS, NSmt = record("NumberSequence")
local nsKeys = sequence("NumberSequence", NKmt, function(t, v) return M.NumberSequenceKeypoint.new(t, v) end, function(v) return type(v) == "number" end)
M.NumberSequence = { new = function(a, b) return NS({ Keypoints = nsKeys(a, b) }) end }
local CS, CSmt = record("ColorSequence")
local csKeys = sequence("ColorSequence", CKmt, function(t, v) return M.ColorSequenceKeypoint.new(t, v) end, function(v) return is(v, C3mt) end)
M.ColorSequence = { new = function(a, b) return CS({ Keypoints = csKeys(a, b) }) end }
local ENUMS = {} -- списки допустимых значений задаёт env.luau (M.defineEnums); категории без списка не проверяются
local ItemMT = { __newindex = function(_, k) error(tostring(k) .. " cannot be assigned to (EnumItem)", 2) end }
ItemMT.__tostring = function(e) return "Enum." .. rawget(e.EnumType, "_name") .. "." .. e.Name end
ItemMT.__index = function(e, k) if k == "IsA" then return function(self, n) return rawget(self.EnumType, "_name") == n end end error(tostring(k) .. " is not a valid member of EnumItem", 2) end
TYPENAME[ItemMT] = "EnumItem"
local CatMT = {}
TYPENAME[CatMT] = "Enum"
CatMT.__tostring = function(c) return rawget(c, "_name") end
CatMT.__index = function(c, name)
	if name == "GetEnumItems" then return function(self) local o = {}; for _, n in ipairs(rawget(self, "_order") or {}) do o[#o + 1] = self[n] end return o end end
	if name == "FromName" then return function(self, n) return rawget(self, "_valid")[n] and self[n] or nil end end
	if name == "FromValue" then return function(self, v) for n, val in pairs(rawget(self, "_valid") or {}) do if val == v then return self[n] end end return nil end end
	local valid = rawget(c, "_valid")
	local value = 0
	if valid then
		if valid[name] == nil then M.problem(tostring(name) .. " is not a valid member of \"Enum." .. rawget(c, "_name") .. "\"") else value = valid[name] end
	end
	local it = setmetatable({ Name = name, Value = value, EnumType = c }, ItemMT)
	rawset(c, name, it)
	return it
end
M.Enum = setmetatable({}, {
	__index = function(root, cat)
		if cat == "GetEnums" then return function() local o = {}; for k in pairs(ENUMS) do o[#o + 1] = root[k] end return o end end
		local c = setmetatable({ _name = cat }, CatMT)
		local list = ENUMS[cat]
		if list then
			local valid, order, nextv = {}, {}, 0
			for tok in list:gmatch("%S+") do
				local n, v = tok:match("^(%w+)=(%-?%d+)$")
				if n then nextv = tonumber(v) else n = tok end
				valid[n] = nextv; order[#order + 1] = n; nextv += 1
			end
			rawset(c, "_valid", valid); rawset(c, "_order", order)
		end
		rawset(root, cat, c)
		return c
	end,
})
TYPENAME[getmetatable(M.Enum)] = "Enums"
function M.defineEnums(lists) for k, v in pairs(lists) do ENUMS[k] = v; rawset(M.Enum, k, nil) end end

M.typeof = function(v)
	if type(v) == "table" then
		if rawget(v, "__isInstance") then return "Instance" end
		local n = TYPENAME[getmetatable(v)]
		if n then return n end
	end
	return rawtypeof(v)
end
local typeof = M.typeof

------------------------------------------------------------------ сигналы (обработчик — в новом потоке, как в Roblox)
local Signal, Conn = {}, {}
Signal.__index = Signal
Conn.__index = Conn
TYPENAME[Signal], TYPENAME[Conn] = "RBXScriptSignal", "RBXScriptConnection"
local function resumeThread(co, ...)
	if coroutine.status(co) ~= "suspended" then return end
	local ok, err = coroutine.resume(co, ...)
	if not ok then M.reportError(debug.traceback(co, tostring(err))) end
end
M.resumeThread = resumeThread
local function runHandler(fn, ...) resumeThread(coroutine.create(fn), ...) end
function M.newSignal(name, realm) return setmetatable({ handlers = {}, name = name, realm = realm }, Signal) end
function Signal:Connect(fn)
	if type(fn) ~= "function" then error("Attempt to connect failed: Passed value is not a function", 2) end
	local r = realmOf(getfenv(2))
	if self.realm and r and r ~= self.realm then M.problem(self.name .. " can only be used on the " .. self.realm) end
	local c = setmetatable({ Connected = true, _fn = fn, _sig = self }, Conn)
	table.insert(self.handlers, c)
	local q = self.pending -- события ремоута, пришедшие до подключения
	if q then self.pending = nil; for _, f in ipairs(q) do M.task.defer(f) end end
	return c
end
Signal.ConnectParallel = Signal.Connect
function Signal:Once(fn)
	local c
	c = self:Connect(function(...) c:Disconnect(); fn(...) end)
	return c
end
function Signal:Wait()
	local co = coroutine.running()
	if co == M.mainThread then error("Signal:Wait() in main thread would hang", 2) end
	self.waiters = self.waiters or {}
	table.insert(self.waiters, co)
	return coroutine.yield()
end
function Conn:Disconnect()
	if not self.Connected then return end
	self.Connected = false
	local hs = self._sig.handlers
	for i = #hs, 1, -1 do if hs[i] == self then table.remove(hs, i) break end end
end
local function fireSignal(s, ...)
	local hs = s.handlers
	if #hs > 0 then
		for _, c in ipairs(table.clone(hs)) do if c.Connected then runHandler(c._fn, ...) end end
	end
	local w = s.waiters
	if w then s.waiters = nil; for _, co in ipairs(w) do resumeThread(co, ...) end end
end
M.fireSignal = fireSignal
function Signal:Fire(...) -- только для тестов: у RBXScriptSignal нет :Fire
	if realmOf(getfenv(2)) then M.problem("Fire is not a valid member of RBXScriptSignal (use BindableEvent)") end
	fireSignal(self, ...)
end
local function disconnectAll(s) for _, c in ipairs(s.handlers) do c.Connected = false end s.handlers = {} end
M.Signal = Signal

------------------------------------------------------------------ планировщик
local queue, seq = {}, 0
local function schedule(at, co, ...)
	seq += 1
	local it = { at = at, seq = seq, co = co, args = table.pack(...) }
	queue[#queue + 1] = it
	return it
end
local function asThread(f) return type(f) == "thread" and f or coroutine.create(f) end
M.task = {
	spawn = function(f, ...) local co = asThread(f); resumeThread(co, ...); return co end,
	defer = function(f, ...) local co = asThread(f); schedule(M.now, co, ...); return co end,
	delay = function(t, f, ...) local co = asThread(f); schedule(M.now + math.max(t or 0, 0), co, ...); return co end,
	wait = function(t)
		local co = coroutine.running()
		if co == M.mainThread then error("task.wait in main thread (run the script with E.run / task.spawn)", 2) end
		local start = M.now
		schedule(M.now + math.max(t or 0.03, 0.001), co)
		coroutine.yield()
		return M.now - start
	end,
	cancel = function(co)
		if co == coroutine.running() then error("cannot cancel the running thread", 2) end
		for _, it in ipairs(queue) do if it.co == co then it.cancelled = true end end
		if coroutine.status(co) == "suspended" then coroutine.close(co) end
	end,
	synchronize = function() end, desynchronize = function() end,
}
function M.runDue()
	for _ = 1, 100000 do
		local due, keep = {}, {}
		for _, it in ipairs(queue) do if it.at <= M.now + 1e-9 then due[#due + 1] = it else keep[#keep + 1] = it end end
		if #due == 0 then return end
		queue = keep
		table.sort(due, function(a, b) if a.at ~= b.at then return a.at < b.at end return a.seq < b.seq end)
		for _, it in ipairs(due) do if not it.cancelled then resumeThread(it.co, table.unpack(it.args, 1, it.args.n)) end end
	end
	error("runDue: endless rescheduling at the same time")
end
function M.pending() return #queue end
function M.clearQueue() queue = {} end

------------------------------------------------------------------ классы: схема задаётся env.luau (M.defineClasses)
-- строка: [*абстрактный|!сервис]Имя[<Предок]| члены; член: Prop:тип[=умолч], ~Prop (только чтение для игры), @Событие, Метод()
local CLASS = {}
M.CLASS = CLASS
local U2zero = u2(ud(0, 0), ud(0, 0))
local function parseDefault(t, d)
	if d == nil then return ({ n = 0, i = 0, b = false, s = "", v3 = V3.zero, v2 = V2.zero, cf = IDENT, c3 = c3(0, 0, 0), u = ud(0, 0), u2 = U2zero })[t] end
	local n = {}
	for x in d:gmatch("[^,]+") do n[#n + 1] = x == "inf" and math.huge or tonumber(x) end
	if t == "n" or t == "i" then return n[1] elseif t == "b" then return d == "true" elseif t == "s" then return d
	elseif t == "v3" then return v3(n[1], n[2], n[3]) elseif t == "v2" then return v2(n[1], n[2])
	elseif t == "c3" then return C3.fromRGB(n[1], n[2], n[3]) elseif t == "u" then return ud(n[1], n[2])
	elseif t == "u2" then return u2(ud(n[1], n[2]), ud(n[3], n[4])) elseif t == "ns" then return M.NumberSequence.new(n[1])
	elseif t == "nr" then return M.NumberRange.new(n[1], n[2]) elseif t == "cs" then return M.ColorSequence.new(C3.fromRGB(n[1], n[2], n[3]))
	elseif t:sub(1, 2) == "E." then return M.Enum[t:sub(3)][d] end
end
local ACCESS = {} -- "Класс.Свойство" -> { get, set } (производные свойства)
function M.defineClasses(text)
	for spec in (text:gsub("\n", " & ") .. " & "):gmatch("%s*(.-) & ") do
		local flag, name, base, body = spec:match("^([%*!]?)(%w+)<?(%w*)|(.*)$")
		assert(name or spec == "", "bad schema entry: " .. spec)
		if not name then continue end
		local c = { name = name, abstract = flag == "*", service = flag == "!", members = {}, isa = { [name] = true } }
		if base ~= "" then
			local b = assert(CLASS[base], "unknown base " .. base)
			for k, v in pairs(b.members) do c.members[k] = v end
			for k in pairs(b.isa) do c.isa[k] = true end
		end
		for tok in body:gmatch("%S+") do
			if tok:sub(1, 1) == "@" then c.members[tok:sub(2)] = { kind = "event" }
			elseif tok:sub(-2) == "()" then c.members[tok:sub(1, -3)] = { kind = "method" }
			else
				local ro, pn, t, d = tok:match("^(~?)([%w_]+):([%w%.]+)=?(.*)$")
				assert(pn, "bad member " .. tok .. " in " .. name)
				local acc = ACCESS[name .. "." .. pn]
				c.members[pn] = { kind = "prop", t = t, ro = ro == "~", default = parseDefault(t, d ~= "" and d or nil), enum = t:sub(1, 2) == "E." and t:sub(3) or nil,
					get = acc and acc.get, set = acc and acc.set }
			end
		end
		CLASS[name] = c
	end
end

------------------------------------------------------------------ экземпляры
local Inst = {}
M.Inst = Inst
local instMT = {}
M.instanceCount, M.partCount = 0, 0
M._listenDesc, M._listenAnc = 0, 0
local function P(o) return rawget(o, "_props") end
local function isInst(v) return type(v) == "table" and rawget(v, "__isInstance") == true end
M.isInstance = isInst
local function isa(o, name)
	local c = rawget(o, "_cls")
	if c then return c.isa[name] == true end
	return name == "Instance" or P(o).ClassName == name
end
M.isa = isa
local function create(class)
	M.instanceCount += 1
	local cls = CLASS[class]
	local o = setmetatable({ __isInstance = true, _props = { ClassName = class, Name = class, Archivable = true }, _children = {}, _attrs = {}, _cls = cls or false }, instMT)
	if cls and cls.isa.BasePart then
		rawset(o, "_isPart", true)
		M.partCount += 1
		P(o).CFrame, P(o).Size = IDENT, cls.members.Size.default
	end
	return o
end
M.newInstance = create -- для тестов: без проверок
function M.InstanceNew(class, parent) -- Instance.new для кода игры
	if type(class) ~= "string" then error("Instance.new: class name expected", 2) end
	local cls = CLASS[class]
	if not cls or cls.abstract or cls.service then M.problem('Unable to create an Instance of type "' .. class .. '"') end
	local o = create(class)
	if parent ~= nil then o.Parent = parent end
	return o
end
local function findChild(o, name)
	for _, c in ipairs(rawget(o, "_children")) do if P(c).Name == name then return c end end
	return nil
end
local SIGNAL_REALM = { RenderStepped = "client", PreRender = "client", OnServerEvent = "server", OnClientEvent = "client", OnClientInvoke = "client" }
local function lazySignal(o, k)
	local s = M.newSignal(k, SIGNAL_REALM[k])
	s.owner = o
	P(o)[k] = s
	if k == "DescendantAdded" or k == "DescendantRemoving" then M._listenDesc += 1 elseif k == "AncestryChanged" then M._listenAnc += 1 end
	return s
end
local LEGACY_EVENTS = { MouseEnter = 1, MouseLeave = 1, MouseButton1Down = 1, MouseButton1Up = 1, MouseButton1Click = 1, Activated = 1, AttributeChanged = 1, ChildAdded = 1, ChildRemoved = 1,
	OnClientEvent = 1, OnServerEvent = 1, Changed = 1, Heartbeat = 1, RenderStepped = 1, Stepped = 1, PlayerAdded = 1, PlayerRemoving = 1, CharacterAdded = 1, InputBegan = 1, InputEnded = 1,
	InputChanged = 1, TouchPinch = 1, Touched = 1, DescendantAdded = 1 }
local function gap(cls, k) return function() error("mock: " .. cls .. ":" .. k .. "() is not implemented", 2) end end
instMT.__index = function(self, k)
	local props = rawget(self, "_props")
	local v = props[k]
	if v ~= nil then
		if k == "LocalPlayer" and realmOf(getfenv(2)) == "server" then return nil end -- на сервере LocalPlayer = nil
		return v
	end
	local cls = rawget(self, "_cls")
	if cls then
		local m = cls.members[k]
		if m then
			if m.kind == "prop" then
				if m.get then return m.get(self, props) end
				return m.default
			elseif m.kind == "method" then
				return Inst[k] or gap(cls.name, k)
			end
			return lazySignal(self, k)
		end
		local ch = findChild(self, k)
		if ch then return ch end
		M.problem(tostring(k) .. " is not a valid member of " .. cls.name .. ' "' .. tostring(props.Name) .. '"')
		return nil
	end
	if Inst[k] then return Inst[k] end -- неизвестный класс: поведение старого мока
	local ch = findChild(self, k)
	if ch then return ch end
	if LEGACY_EVENTS[k] then return lazySignal(self, k) end
	return nil
end
local function changed(self, props, k, v)
	local ch = props.Changed
	if ch and getmetatable(ch) == Signal then
		local cls = rawget(self, "_cls")
		if cls and cls.isa.ValueBase then if k == "Value" then fireSignal(ch, v) end else fireSignal(ch, k) end
	end
	local ps = rawget(self, "_propSignals")
	if ps and ps[k] then fireSignal(ps[k]) end
end
local CHECK = {
	n = function(v) return type(v) == "number" end, i = function(v) return type(v) == "number" end, b = function(v) return type(v) == "boolean" end,
	v3 = function(v) return is(v, V3mt) end, v2 = function(v) return is(v, V2mt) end, cf = function(v) return is(v, CFmt) end, c3 = function(v) return is(v, C3mt) end,
	u = function(v) return is(v, UDmt) end, u2 = function(v) return is(v, U2mt) end, cs = function(v) return is(v, CSmt) end, ns = function(v) return is(v, NSmt) end,
	nr = function(v) return is(v, NRmt) end, rect = function(v) return typeof(v) == "Rect" end, font = function(v) return typeof(v) == "Font" end,
	bc = function(v) return typeof(v) == "BrickColor" end, pp = function(v) return v == nil or typeof(v) == "PhysicalProperties" end,
	I = function(v) return v == nil or isInst(v) end, fn = function(v) return v == nil or type(v) == "function" end, any = function() return true end,
}
local function coerce(m, v)
	local t = m.t
	if t == "s" then
		if type(v) == "number" then return true, tostring(v) end
		return type(v) == "string", v
	end
	if m.enum then
		if type(v) == "string" then return true, M.Enum[m.enum][v] end
		if type(v) == "number" then return true, M.Enum[m.enum]:FromValue(v) or v end
		return typeof(v) == "EnumItem" and rawget(v.EnumType, "_name") == m.enum, v
	end
	local f = CHECK[t]
	return f == nil or f(v), v
end
instMT.__newindex = function(self, k, v)
	local props = rawget(self, "_props")
	local cls = rawget(self, "_cls")
	if not cls then -- неизвестный класс
		if k == "Parent" then M.setParent(self, v) else props[k] = v end
		return
	end
	local m = cls.members[k]
	if not m or m.kind ~= "prop" then
		M.problem((m and ("cannot assign " .. m.kind .. " ") or "") .. tostring(k) .. " is not a valid member of " .. cls.name .. ' "' .. tostring(props.Name) .. '"')
		if not m then props[k] = v end
		return
	end
	if m.ro and realmOf(getfenv(2)) then M.problem("Unable to assign property " .. k .. " of " .. cls.name .. ". Property is read only") end
	local ok, cv = coerce(m, v)
	if not ok then
		M.problem(string.format("invalid value for %s.%s (%s expected, got %s)", cls.name, k, m.t, typeof(v)))
		return
	end
	if m.set then m.set(self, props, cv, k) return end
	local old = props[k]
	props[k] = cv
	if old ~= cv then changed(self, props, k, cv) end
end
instMT.__tostring = function(self) return tostring(P(self).Name) end

-- дерево
local function wake(parent, name, child)
	local w = rawget(parent, "_waiters")
	local list = w[name]
	w[name] = nil
	for _, it in ipairs(list) do if not it.done then it.done = true; schedule(M.now, it.co, child) end end
end
local function descFire(start, event, inst)
	local list
	local a = start
	while a do
		local s = P(a)[event]
		if s then
			if not list then list = Inst.GetDescendants(inst); table.insert(list, 1, inst) end
			for _, d in ipairs(list) do fireSignal(s, d) end
		end
		a = P(a).Parent
	end
end
function M.setParent(self, v)
	local props = P(self)
	if rawget(self, "_locked") then fail("The Parent property of " .. tostring(props.Name) .. " is locked, current parent: NULL, new parent " .. tostring(v and P(v).Name)) end
	local old = props.Parent
	if old == v then return end
	if v ~= nil then
		if not isInst(v) then fail("Parent must be an Instance") end
		local a = v
		while a do
			if a == self then fail("Attempt to set parent of " .. tostring(props.Name) .. " to " .. tostring(P(v).Name) .. " would result in circular reference") end
			a = P(a).Parent
		end
	end
	if old then
		local ch = rawget(old, "_children")
		for i = #ch, 1, -1 do if ch[i] == self then table.remove(ch, i) break end end
		local s = P(old).ChildRemoved
		if s then fireSignal(s, self) end
		if M._listenDesc > 0 then descFire(old, "DescendantRemoving", self) end
	end
	props.Parent = v
	if v then
		table.insert(rawget(v, "_children"), self)
		local s = P(v).ChildAdded
		if s then fireSignal(s, self) end
		if M._listenDesc > 0 then descFire(v, "DescendantAdded", self) end
		local w = rawget(v, "_waiters")
		if w and w[props.Name] then wake(v, props.Name, self) end
	end
	local ac = props.AncestryChanged
	if ac then fireSignal(ac, self, v) end
	if M._listenAnc > 0 then for _, d in ipairs(Inst.GetDescendants(self)) do local s = P(d).AncestryChanged; if s then fireSignal(s, self, v) end end end
	changed(self, props, "Parent", v)
end
local function teardown(o)
	local props = P(o)
	rawset(o, "_locked", true)
	rawset(o, "_destroyed", true)
	for _, c in ipairs(rawget(o, "_children")) do
		local d = P(c).Destroying
		if d then fireSignal(d) end
		P(c).Parent = nil
		teardown(c)
	end
	rawset(o, "_children", {})
	for _, s in pairs(props) do if getmetatable(s) == Signal then disconnectAll(s) end end
	for _, key in ipairs({ "_propSignals", "_attrSignals" }) do local t = rawget(o, key); if t then for _, s in pairs(t) do disconnectAll(s) end end end
	if M.onDestroy then M.onDestroy(o) end
end
function Inst.Destroy(self)
	if rawget(self, "_destroyed") then return end
	local d = P(self).Destroying
	if d then fireSignal(d) end
	M.setParent(self, nil)
	teardown(self)
end
function Inst.ClearAllChildren(self) for _, c in ipairs(Inst.GetChildren(self)) do Inst.Destroy(c) end end
local function cloneRec(o, map)
	local props = P(o)
	if props.Archivable == false then return nil end
	local c = create(props.ClassName)
	local cp = P(c)
	for k, v in pairs(props) do if k ~= "Parent" and getmetatable(v) ~= Signal then cp[k] = v end end
	for k, v in pairs(rawget(o, "_attrs")) do rawget(c, "_attrs")[k] = v end
	local tags = rawget(o, "_tags")
	if tags then rawset(c, "_tags", table.clone(tags)) end
	rawset(c, "_scale", rawget(o, "_scale"))
	map[o] = c
	local kids = rawget(c, "_children")
	for _, ch in ipairs(rawget(o, "_children")) do
		local cc = cloneRec(ch, map)
		if cc then P(cc).Parent = c; kids[#kids + 1] = cc end
	end
	return c
end
function Inst.Clone(self)
	local map = {}
	local root = cloneRec(self, map)
	for _, c in pairs(map) do -- ссылки внутри копии (Part0/Part1/PrimaryPart/Adornee…) -> на копии
		local cp = P(c)
		for k, v in pairs(cp) do if k ~= "Parent" and type(v) == "table" and map[v] then cp[k] = map[v] end end
	end
	return root
end
function Inst.IsA(self, c) return isa(self, c) end
function Inst.GetChildren(self) return table.clone(rawget(self, "_children")) end
function Inst.GetDescendants(self)
	local out = {}
	local function rec(o) for _, c in ipairs(rawget(o, "_children")) do out[#out + 1] = c; rec(c) end end
	rec(self)
	return out
end
local function nameArg(n, what) if type(n) ~= "string" then fail(what .. ": string expected, got " .. typeof(n)) end return n end
function Inst.FindFirstChild(self, name, recursive)
	nameArg(name, "FindFirstChild")
	local c = findChild(self, name)
	if c or not recursive then return c end
	for _, ch in ipairs(rawget(self, "_children")) do local r = Inst.FindFirstChild(ch, name, true); if r then return r end end
	return nil
end
function Inst.FindFirstChildOfClass(self, class) for _, c in ipairs(rawget(self, "_children")) do if P(c).ClassName == class then return c end end return nil end
function Inst.FindFirstChildWhichIsA(self, class, recursive)
	for _, c in ipairs(rawget(self, "_children")) do if isa(c, class) then return c end end
	if recursive then for _, c in ipairs(rawget(self, "_children")) do local r = Inst.FindFirstChildWhichIsA(c, class, true); if r then return r end end end
	return nil
end
function Inst.FindFirstDescendant(self, name) for _, d in ipairs(Inst.GetDescendants(self)) do if P(d).Name == name then return d end end return nil end
local function findAncestor(self, test) local p = P(self).Parent; while p do if test(p) then return p end p = P(p).Parent end return nil end
function Inst.FindFirstAncestor(self, name) return findAncestor(self, function(p) return P(p).Name == name end) end
function Inst.FindFirstAncestorOfClass(self, class) return findAncestor(self, function(p) return P(p).ClassName == class end) end
function Inst.FindFirstAncestorWhichIsA(self, class) return findAncestor(self, function(p) return isa(p, class) end) end
function Inst.IsDescendantOf(self, anc) return findAncestor(self, function(p) return p == anc end) ~= nil end
function Inst.IsAncestorOf(self, d) return isInst(d) and Inst.IsDescendantOf(d, self) end
function Inst.GetFullName(self)
	local parts, o = {}, self
	while o and P(o).ClassName ~= "DataModel" do table.insert(parts, 1, tostring(P(o).Name)); o = P(o).Parent end
	return table.concat(parts, ".")
end
function Inst.WaitForChild(self, name, timeout)
	nameArg(name, "WaitForChild")
	local c = findChild(self, name)
	if c then return c end
	local co = coroutine.running()
	if co == M.mainThread then error("WaitForChild would hang (main thread): " .. name .. " in " .. Inst.GetFullName(self), 2) end
	local w = rawget(self, "_waiters") or {}
	rawset(self, "_waiters", w)
	w[name] = w[name] or {}
	local it = { co = co }
	table.insert(w[name], it)
	M.task.delay(timeout or 5, function()
		if it.done then return end
		if timeout then it.done = true; M.resumeThread(co, nil)
		else M.problem("Infinite yield possible on '" .. Inst.GetFullName(self) .. ':WaitForChild("' .. name .. '")\'') end
	end)
	return coroutine.yield()
end
function Inst.GetDebugId(self) return tostring(rawget(self, "_props")):sub(8) end
function Inst.GetActor() return nil end
-- атрибуты и теги
local ATTR = { boolean = 1, number = 1, string = 1, UDim = 1, UDim2 = 1, BrickColor = 1, Color3 = 1, Vector2 = 1, Vector3 = 1, CFrame = 1, NumberSequence = 1,
	ColorSequence = 1, NumberRange = 1, Rect = 1, Font = 1, EnumItem = 1 }
function Inst.SetAttribute(self, k, v)
	if type(k) ~= "string" or #k == 0 or #k > 100 or not k:match("^[%w_]+$") or k:sub(1, 3) == "RBX" then error("Attribute name '" .. tostring(k) .. "' is invalid", 2) end
	if v ~= nil and not ATTR[typeof(v)] then error("Attribute '" .. k .. "': type " .. typeof(v) .. " is not supported", 2) end
	local attrs = rawget(self, "_attrs")
	local old = attrs[k]
	attrs[k] = v
	if old == v then return end
	local ac = P(self).AttributeChanged
	if ac and getmetatable(ac) == Signal then fireSignal(ac, k) end
	local as = rawget(self, "_attrSignals")
	if as and as[k] then fireSignal(as[k]) end
end
function Inst.GetAttribute(self, k) nameArg(k, "GetAttribute"); return rawget(self, "_attrs")[k] end
function Inst.GetAttributes(self) return table.clone(rawget(self, "_attrs")) end
local function cachedSignal(self, key, k)
	local t = rawget(self, key) or {}
	rawset(self, key, t)
	t[k] = t[k] or M.newSignal(k)
	return t[k]
end
function Inst.GetAttributeChangedSignal(self, k) return cachedSignal(self, "_attrSignals", k) end
function Inst.GetPropertyChangedSignal(self, prop)
	local cls = rawget(self, "_cls")
	if cls and not (cls.members[prop] and cls.members[prop].kind == "prop") then M.problem(tostring(prop) .. " is not a valid property name of " .. cls.name) end
	return cachedSignal(self, "_propSignals", prop)
end
function Inst.AddTag(self, tag) local t = rawget(self, "_tags") or {}; rawset(self, "_tags", t); if not t[tag] then t[tag] = true; if M.onTag then M.onTag(self, tag, true) end end end
function Inst.RemoveTag(self, tag) local t = rawget(self, "_tags"); if t and t[tag] then t[tag] = nil; if M.onTag then M.onTag(self, tag, false) end end end
function Inst.HasTag(self, tag) local t = rawget(self, "_tags"); return t ~= nil and t[tag] == true end
function Inst.GetTags(self) local o = {}; for k in pairs(rawget(self, "_tags") or {}) do o[#o + 1] = k end table.sort(o); return o end

-- производные свойства (геттеры/сеттеры), подключаются в M.defineClasses
local function nanv(v) return v.X ~= v.X or v.Y ~= v.Y or v.Z ~= v.Z end
local function nancf(c) if nanv(c.p) then return true end for i = 1, 9 do if c._r[i] ~= c._r[i] then return true end end return false end
local function store(self, props, v, k) local old = props[k]; props[k] = v; if old ~= v then changed(self, props, k, v) end end
local function acc(key, get, set) for k in key:gmatch("[^,]+") do ACCESS[k] = { get = get, set = set } end end
M.accessor = acc -- env.luau добавляет свои производные свойства до M.defineClasses
local deg, rad = math.deg, math.rad
acc("Instance.Parent", nil, function(self, _, v) M.setParent(self, v) end)
acc("BasePart.CFrame,JointInstance.C0,JointInstance.C1,Motor6D.Transform", nil, function(self, props, v, k)
	if nancf(v) then M.problem("NaN in " .. k .. " of " .. tostring(props.Name)) return end
	store(self, props, v, k)
end)
acc("BasePart.Position", function(_, p) return p.CFrame.p end, function(self, p, v)
	if nanv(v) then M.problem("NaN in Position of " .. tostring(p.Name)) return end
	store(self, p, cf(v.X, v.Y, v.Z, p.CFrame._r), "CFrame")
end)
acc("BasePart.Orientation", function(_, p) local x, y, z = CF.ToOrientation(p.CFrame); return v3(deg(x), deg(y), deg(z)) end,
	function(self, p, v) store(self, p, CF.new(p.CFrame.p) * CF.fromOrientation(rad(v.X), rad(v.Y), rad(v.Z)), "CFrame") end)
acc("BasePart.Rotation", function(_, p) local x, y, z = CF.ToEulerAnglesXYZ(p.CFrame); return v3(deg(x), deg(y), deg(z)) end,
	function(self, p, v) store(self, p, CF.new(p.CFrame.p) * CF.Angles(rad(v.X), rad(v.Y), rad(v.Z)), "CFrame") end)
local function clampSize(p, v)
	local function c(x) return math.clamp(x, 0.001, 2048) end
	v = v3(c(v.X), c(v.Y), c(v.Z))
	if p.Shape and p.Shape.Name == "Ball" then local m = math.min(v.X, v.Y, v.Z); v = v3(m, m, m) end
	return v
end
acc("BasePart.Size", nil, function(self, p, v)
	if nanv(v) then M.problem("NaN in Size of " .. tostring(p.Name)) return end
	store(self, p, clampSize(p, v), "Size")
end)
acc("Part.Shape", nil, function(self, p, v) p.Shape = v; p.Size = clampSize(p, p.Size); changed(self, p, "Shape", v) end)
acc("BasePart.Mass,BasePart.AssemblyMass", function(_, p) return p.Size.X * p.Size.Y * p.Size.Z * 0.7 end)
acc("BasePart.ExtentsSize", function(_, p) return p.Size end)
acc("BasePart.ExtentsCFrame", function(_, p) return p.CFrame end)
acc("BasePart.AssemblyRootPart", function(self) return self end)
acc("Model.WorldPivot", function(self) return Inst.GetPivot(self) end)
acc("JointInstance.Active,WeldConstraint.Active", function(_, p) return p.Part0 ~= nil and p.Part1 ~= nil and p.Enabled ~= false end)
acc("Workspace.DistributedGameTime", function() return M.now end)
acc("Sound.IsPlaying", function(_, p) return p.Playing == true end)
local function attParent(self) local par = P(self).Parent; while par and not rawget(par, "_isPart") do par = isa(par, "Attachment") and P(par).Parent or nil end return par and P(par).CFrame or IDENT end
local function attCF(p) return p.CFrame or IDENT end
acc("Attachment.Position", function(_, p) return attCF(p).p end, function(self, p, v) store(self, p, cf(v.X, v.Y, v.Z, attCF(p)._r), "CFrame") end)
acc("Attachment.Orientation", function(_, p) local x, y, z = CF.ToOrientation(attCF(p)); return v3(deg(x), deg(y), deg(z)) end,
	function(self, p, v) store(self, p, CF.new(attCF(p).p) * CF.fromOrientation(rad(v.X), rad(v.Y), rad(v.Z)), "CFrame") end)
acc("Attachment.Axis", function(_, p) return attCF(p).RightVector end)
acc("Attachment.SecondaryAxis", function(_, p) return attCF(p).UpVector end)
acc("Attachment.WorldCFrame", function(self, p) return attParent(self) * attCF(p) end, function(self, p, v) store(self, p, CF.Inverse(attParent(self)) * v, "CFrame") end)
acc("Attachment.WorldPosition", function(self, p) return (attParent(self) * attCF(p)).p end,
	function(self, p, v) local l = CF.Inverse(attParent(self)) * v; store(self, p, cf(l.X, l.Y, l.Z, attCF(p)._r), "CFrame") end)
acc("Attachment.WorldOrientation", function(self, p) local x, y, z = CF.ToOrientation(attParent(self) * attCF(p)); return v3(deg(x), deg(y), deg(z)) end)
acc("Attachment.WorldAxis", function(self, p) return (attParent(self) * attCF(p)).RightVector end)
acc("Attachment.WorldSecondaryAxis", function(self, p) return (attParent(self) * attCF(p)).UpVector end)
-- внутренности для env.luau (движок: сервисы, геометрия, рантайм скриптов)
M._ = { P = P, isa = isa, is = is, cf = cf, IR = IR, IDENT = IDENT, CF = CF, V3 = V3, V2 = V2, v3 = v3, v2 = v2, ud = ud, u2 = u2, c3 = c3, C3 = C3,
	V3mt = V3mt, V2mt = V2mt, CFmt = CFmt, C3mt = C3mt, UDmt = UDmt, U2mt = U2mt, NSmt = NSmt, CSmt = CSmt, NRmt = NRmt, datatype = datatype, record = record,
	num = num, fail = fail, changed = changed, schedule = schedule, Signal = Signal, fireSignal = fireSignal, runHandler = runHandler, realmOf = realmOf,
	findChild = findChild, create = create, TYPENAME = TYPENAME, U2zero = U2zero, vecArg = vecArg, cfArg = cfArg }

return M
