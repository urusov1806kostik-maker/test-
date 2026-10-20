--!nocheck
-- Config v2 против замороженного legacy Config (tests/fixtures/LegacyConfig.lua): глубокое сравнение
-- (ключи, числа точно, строки, Color3/Vector3/Vector2/CFrame/UDim2/последовательности, порядок массивов,
-- общие таблицы — например Maps.Void == Map) + одинаковое поведение GetUnitStats/WaveHPMult/FormatNumber.
-- Запуск: luau run_config.luau [-a --allow-extra]   (--allow-extra: лишние ключи v2 не считаются ошибкой)
local E = require("./env")
local M = E.M
local ALLOW_EXTRA = table.find({ ... }, "--allow-extra") ~= nil

local env = E.make()
E.install()
M.strictErrors = false

-- legacy: тот же набор глобалов Roblox (Vector3, Color3, ...), отдельная VM
local legacyFn = assert(loadstring(assert(E.bundle.Fixtures.LegacyConfig, "нет fixtures/LegacyConfig.lua в бандле"), "=LegacyConfig"))
setfenv(legacyFn, setmetatable({}, { __index = E.client.env }))
local Legacy = legacyFn()

local cfgModule = M.services.ReplicatedStorage:FindFirstChild("VoidTD") and M.services.ReplicatedStorage.VoidTD:FindFirstChild("Config")
if not cfgModule then
	print("MISSING ReplicatedStorage/VoidTD/Config (src/ReplicatedStorage/VoidTD/Config/init.lua)")
	error("CONFIG FAILED: no Config module", 0)
end
local New, loadErr
do
	local done = false
	coroutine.resume(coroutine.create(function() local ok, r = pcall(E.server.require, cfgModule); if ok then New = r else loadErr = r end; done = true end))
	local t = 0
	while not done and t < 6 do M.step(0.1); t += 0.1 end
	if not done then loadErr = "Config did not finish loading (WaitForChild of a missing child?)" end
end
for _, p in ipairs(M.problems) do print("API     " .. p.msg .. " @ " .. p.where) end
if not New then print("FAIL    require Config: " .. tostring(loadErr)); error("CONFIG FAILED: Config does not load", 0) end

local diffs, extras, notes = {}, {}, {}
local function key(k) return type(k) == "string" and k:match("^[%a_][%w_]*$") and ("." .. k) or ("[" .. (type(k) == "string" and string.format("%q", k) or tostring(k)) .. "]") end
local function fmt(v)
	local t = M.typeof(v)
	if t == "string" then return string.format("%q", v) end
	if t == "number" then return string.format("%.17g", v) end
	if t == "Color3" then return string.format("Color3(%.17g, %.17g, %.17g)", v.R, v.G, v.B) end
	if t == "table" then return "table" elseif t == "nil" then return "nil" end
	return t .. "(" .. tostring(v) .. ")"
end
local function diff(path, msg) diffs[#diffs + 1] = path .. ": " .. msg end
local COMP = {
	Vector3 = { "X", "Y", "Z" }, Vector2 = { "X", "Y" }, Color3 = { "R", "G", "B" }, UDim = { "Scale", "Offset" }, NumberRange = { "Min", "Max" },
}
local function sameNum(a, b) return a == b or (a ~= a and b ~= b) end
local function sameValue(a, b) -- значения Roblox-типов
	local t = M.typeof(a)
	if COMP[t] then for _, c in ipairs(COMP[t]) do if not sameNum(a[c], b[c]) then return false end end return true end
	if t == "UDim2" then return sameValue(a.X, b.X) and sameValue(a.Y, b.Y) end
	if t == "CFrame" then local x, y = { a:GetComponents() }, { b:GetComponents() }; for i = 1, 12 do if not sameNum(x[i], y[i]) then return false end end return true end
	if t == "NumberSequence" or t == "ColorSequence" then
		if #a.Keypoints ~= #b.Keypoints then return false end
		for i, k in ipairs(a.Keypoints) do
			local o = b.Keypoints[i]
			if not sameNum(k.Time, o.Time) or (t == "NumberSequence" and (not sameNum(k.Value, o.Value) or not sameNum(k.Envelope, o.Envelope))) or (t == "ColorSequence" and not sameValue(k.Value, o.Value)) then return false end
		end
		return true
	end
	if t == "EnumItem" then return a == b end
	return tostring(a) == tostring(b)
end
local function compare(a, b, path, ctx)
	local ta, tb = M.typeof(a), M.typeof(b)
	if b == nil and a ~= nil then diff(path, "MISSING in v2 (legacy " .. fmt(a) .. ")") return end
	if ta ~= tb then diff(path, "type " .. ta .. " (legacy) vs " .. tb .. " (v2): " .. fmt(a) .. " / " .. fmt(b)) return end
	if ta == "number" then if not sameNum(a, b) then diff(path, fmt(a) .. " (legacy) vs " .. fmt(b) .. " (v2)") end return end
	if ta == "string" or ta == "boolean" then if a ~= b then diff(path, fmt(a) .. " (legacy) vs " .. fmt(b) .. " (v2)") end return end
	if ta == "function" then return end
	if ta ~= "table" then if not sameValue(a, b) then diff(path, fmt(a) .. " (legacy) vs " .. fmt(b) .. " (v2)") end return end
	-- общие таблицы: если в legacy одна таблица встречается в двух местах, в v2 тоже должна быть одна
	local first = ctx.legacyAt[a]
	if first then
		if ctx.newAt[first] ~= b then diff(path, "must be the SAME table as " .. first .. " (as in legacy)") end
		return
	end
	local other = ctx.newSeen[b]
	if other then diff(path, "v2 reuses the table from " .. other .. " (legacy has separate tables)") return end
	ctx.legacyAt[a], ctx.newAt[path], ctx.newSeen[b] = path, b, path
	local keys = {}
	for k in pairs(a) do keys[#keys + 1] = k end
	table.sort(keys, function(x, y) if type(x) == type(y) then return x < y end return type(x) < type(y) end)
	for _, k in ipairs(keys) do compare(a[k], b[k], path .. key(k), ctx) end
	local extra = {}
	for k, v in pairs(b) do if a[k] == nil then extra[#extra + 1] = { k, v } end end
	table.sort(extra, function(x, y) return tostring(x[1]) < tostring(y[1]) end)
	for _, e in ipairs(extra) do extras[#extras + 1] = path .. key(e[1]) .. " = " .. fmt(e[2]) end
end
local function newCtx() return { legacyAt = {}, newAt = {}, newSeen = {} } end
compare(Legacy, New, "Config", newCtx())
if New.Maps and New.Maps.Void ~= New.Map then diff("Config.Maps.Void", "must be the same table as Config.Map") end

-- функции: одинаковые ответы на выборке входов
local function call(f, ...) local r = table.pack(pcall(f, ...)); return r end
local function checkFn(name, inputs, accept)
	local lf, nf = Legacy[name], New[name]
	if type(nf) ~= "function" then diff("Config." .. name, "function missing in v2") return end
	for _, input in ipairs(inputs) do
		local label = "Config." .. name .. "(" .. table.concat((function() local o = {} for i = 1, input.n or #input do o[i] = fmt(input[i]) end return o end)(), ", ") .. ")"
		local lr, nr = call(lf, table.unpack(input, 1, input.n or #input)), call(nf, table.unpack(input, 1, input.n or #input))
		if not lr[1] then
			local what = "legacy throws (" .. tostring(lr[2]):gsub("^.-:%d+: ", "") .. "), v2 " .. (nr[1] and ("returns " .. M.typeof(nr[2])) or "throws too")
			local g = notes[name .. what]
			if g then g.count += 1 else notes[name .. what] = { text = label .. ": " .. what, count = 1 }; notes[#notes + 1] = notes[name .. what] end
		elseif not nr[1] then
			diff(label, "v2 throws: " .. tostring(nr[2]))
		elseif accept and accept(lr[2], nr[2], input) then
			if lr[2] ~= nr[2] then notes[#notes + 1] = { text = label .. ": legacy " .. fmt(lr[2]) .. " -> v2 " .. fmt(nr[2]) .. " (legacy bug fixed)", count = 1 } end
		elseif lr[2] == nil or nr[2] == nil then
			if lr[2] ~= nr[2] then diff(label, fmt(lr[2]) .. " (legacy) vs " .. fmt(nr[2]) .. " (v2)") end
		else
			compare(lr[2], nr[2], label, newCtx())
		end
	end
end
local waves = {}
for w = -2, 60 do waves[#waves + 1] = { w } end
for _, w in ipairs({ 0.5, 1.5, 7.25, 100, 1000 }) do waves[#waves + 1] = { w } end
checkFn("WaveHPMult", waves)
local nums = {}
for _, n in ipairs({ 0, 0.4, 0.5, 1, 1.5, 2.5, 7, 12, 99, 100, 999, 999.4, 999.5, 1000, 1234, 1500.7, 9999, 9999.4, 9999.5, 10000, 10049, 10050, 12345, 15000, 99999,
	100000, 123456, 999949, 999950, 999999, 1000000, 1234567, 1500000, 9999999, 123456789, 1e12, -0.4, -1, -12, -123, -999, -1000, -1234, -12345, -50000, -123456, -1e7 }) do
	nums[#nums + 1] = { n }
end
-- известные баги legacy (инвентарь): "-,123" для отрицательных и "1000.0K" для 999950..999999 — исправление допустимо
checkFn("FormatNumber", nums, function(l, n)
	if l == n then return true end
	if type(l) == "string" and l:find("^%-,") and n == "-" .. l:sub(3) then return true end
	if l == "1000.0K" and n == "1.0M" then return true end
	-- исправление: отрицательные ≤ -10000 тоже сокращаются (K/M), как положительные
	if type(l) == "string" and l:find("^%-[%d,]+$") and type(n) == "string" and n:find("^%-[%d%.]+[KM]$") then return true end
	return false
end)
local stats = { { "NoSuchUnit", 1 }, { nil, 1, n = 2 } }
for _, id in ipairs(Legacy.UnitOrder or {}) do
	for _, lv in ipairs({ -1, 0, 1, 2, 3, 4, 5, 6, 10 }) do stats[#stats + 1] = { id, lv } end
	stats[#stats + 1] = { id, nil, n = 2 }
end
checkFn("GetUnitStats", stats)

for _, n in ipairs(notes) do print("NOTE    " .. n.text .. (n.count > 1 and ("  (and " .. (n.count - 1) .. " similar inputs)") or "")) end
for _, d in ipairs(diffs) do print("DIFF    " .. d) end
for _, x in ipairs(extras) do print("EXTRA   " .. x .. (ALLOW_EXTRA and "" or "  (not in legacy)")) end
local bad = #diffs + (ALLOW_EXTRA and 0 or #extras) + #M.problems
if bad == 0 then
	print(string.format("CONFIG OK (%d units, %d enemies%s)", #New.UnitOrder, #New.EnemyOrder, #extras > 0 and (", " .. #extras .. " extra keys allowed") or ""))
else
	print(string.format("CONFIG FAILED: %d differences, %d extra keys, %d API problems", #diffs, #extras, #M.problems))
	error("config mismatch", 0)
end
