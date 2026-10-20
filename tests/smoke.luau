--!nocheck
-- Смоук-тест v2: дерево по SPEC §1, require каждого ModuleScript (в нужном realm), запуск серверного
-- и клиентского бутстрапа на несколько секунд. Отсутствующие файлы — MISSING (не ошибка).
-- Запуск: luau smoke.luau [-a [--strict] [--verbose] [--seconds N]]   (--strict: MISSING тоже ошибка)
local E = require("./env")
local M = E.M

local args = { ... }
local STRICT, VERBOSE, SECONDS = table.find(args, "--strict") ~= nil, table.find(args, "--verbose") ~= nil, 5
for i, a in ipairs(args) do if a == "--seconds" then SECONDS = tonumber(args[i + 1]) or SECONDS end end

-- ожидаемое дерево (SPEC §1): путь = класс
local EXPECTED = {}
local function expect(base, class, children)
	EXPECTED[#EXPECTED + 1] = { Path = base, Class = class }
	for _, n in ipairs(children or {}) do EXPECTED[#EXPECTED + 1] = { Path = base .. "/" .. n, Class = "ModuleScript" } end
end
local RS, SSS, SPS = "ReplicatedStorage/VoidTD", "ServerScriptService/VoidTDServer", "StarterPlayerScripts/VoidTDClient"
expect(RS, "Folder", { "Net", "Path", "Util" })
expect(RS .. "/Config", "ModuleScript", { "Settings", "Rarities", "Cases", "Shop", "Sounds", "Difficulties", "World", "Runes", "Enemies", "Waves" })
expect(RS .. "/Config/Units", "ModuleScript", { "Void", "Shattered", "Blood", "Halloween" })
expect(RS .. "/Models", "Folder", { "Kit", "Parts", "Cases" })
expect(RS .. "/Models/Units", "ModuleScript", { "Void", "Shattered", "Blood", "Clockmaker", "Halloween", "Allies", "Runes" })
expect(RS .. "/Models/Enemies", "ModuleScript", { "Base", "Void", "Halloween" })
expect(SSS, "Script", { "Router", "Data", "Economy", "Match", "Queue" })
expect(SSS .. "/Sim", "ModuleScript", { "Enemies", "Units", "Attacks", "Abilities", "Allies", "Runes" })
expect(SSS .. "/World", "ModuleScript", { "Kit", "Lighting", "Lobby", "VoidMap", "Halloween" })
expect(SPS, "LocalScript", { "Net", "Anims", "Placement", "Zones", "Input" })
expect(SPS .. "/FX", "ModuleScript", { "Void", "Chrono", "Halloween" })
expect(SPS .. "/Render", "ModuleScript", { "Enemies", "Units", "Allies" })
expect(SPS .. "/UI", "ModuleScript", { "Kit", "HUD", "Hotbar", "UnitPanel", "Mode", "EndScreen", "Shop", "Cases", "Openings", "Inventory", "Halloween", "Viewer" })

local failures, apiCount, runtimeErrors = 0, 0, 0
local function out(...) print(...) end
local function firstLines(s, n)
	local lines = {}
	for l in (tostring(s) .. "\n"):gmatch("(.-)\n") do
		if not l:find("mock%.luau") and not l:find("env%.luau") and l ~= "" then lines[#lines + 1] = l end
		if #lines >= n then break end
	end
	return table.concat(lines, "\n     ")
end

------------------------------------------------------------------ 1. дерево
local env = E.make()
local files = E.install()
local present = {}
for _, f in ipairs(files) do present[f.Path] = f end
local missing, missingNames = {}, {}
local expectedSet = {}
for _, e in ipairs(EXPECTED) do
	expectedSet[e.Path] = true
	local f = present[e.Path]
	if not f then
		missing[#missing + 1] = e.Path
		missingNames[e.Path:match("[^/]+$")] = true
	elseif f.Class ~= e.Class then
		failures += 1
		out("FAIL    " .. e.Path .. ": class " .. f.Class .. ", SPEC expects " .. e.Class .. " (" .. tostring(f.File) .. ")")
	end
end
do -- MISSING одной строкой на папку
	local groups, order = {}, {}
	for _, p in ipairs(missing) do
		local parent, name = p:match("^(.*)/([^/]+)$")
		if not groups[parent] then groups[parent] = {}; order[#order + 1] = parent end
		table.insert(groups[parent], name)
	end
	for _, parent in ipairs(order) do out("MISSING " .. parent .. "/{" .. table.concat(groups[parent], ", ") .. "}") end
end
for _, f in ipairs(files) do if not expectedSet[f.Path] then out("EXTRA   " .. f.Path .. " (" .. f.Class .. ", not in SPEC §1)") end end
out(string.format("== tree: %d expected, %d present, %d missing, %d files in bundle", #EXPECTED, #EXPECTED - #missing, #missing, #files))
local function missingUnder(prefixes)
	local o = {}
	for _, p in ipairs(missing) do for _, pre in ipairs(prefixes) do if p:sub(1, #pre) == pre then o[#o + 1] = p; break end end end
	return o
end
-- ошибка из-за ещё не написанного файла (имя отсутствующего модуля в тексте) — BLOCKED, не FAIL
local function blockedBy(text)
	text = tostring(text)
	for name in pairs(missingNames) do
		if text:find('"' .. name .. '"', 1, true) or text:find(name .. " is not a valid member", 1, true) or text:find("." .. name .. ":", 1, true) then return name end
	end
	return nil
end
local function report(list, from, tag)
	for i = from, #list do
		local p = list[i]
		local b = blockedBy(p.msg)
		if b then out("BLOCKED " .. p.msg .. " @ " .. p.where .. "  (missing " .. b .. ")")
		else apiCount += 1; out("API     " .. p.msg .. " @ " .. p.where .. (p.count > 1 and ("  (x" .. p.count .. ")") or "") .. (tag and ("  [" .. tag .. "]") or "")) end
	end
end

------------------------------------------------------------------ 2. require каждого модуля
M.strictErrors = false
local player = M.newPlayer("Tester", 1)
M.services.Players.LocalPlayer = player -- клиентским модулям нужен LocalPlayer уже при require
local function tryRequire(obj, realm)
	local done, ok, err = false, nil, nil
	local co = coroutine.create(function() ok, err = pcall(realm.require, obj); done = true end)
	coroutine.resume(co)
	local t = 0
	while not done and t < 6 do M.step(0.1); t += 0.1 end
	if not done then return false, "module did not finish loading in 6 s (yields: WaitForChild of a missing child?)" end
	return ok, err
end
for _, pass in ipairs({ { "server", { "ReplicatedStorage/", "ServerScriptService/" } }, { "client", { "ReplicatedStorage/", "StarterPlayerScripts/" } } }) do
	local realm = E[pass[1]]
	local okN, n = 0, 0
	for _, f in ipairs(files) do
		local under = false
		for _, pre in ipairs(pass[2]) do if f.Path:sub(1, #pre) == pre then under = true end end
		if under and f.Class == "ModuleScript" then
			n += 1
			local before, errsBefore = #M.problems, #M.errors
			local ok, err = tryRequire(f.Instance, realm)
			if ok then
				okN += 1
				if VERBOSE then out("ok      [" .. pass[1] .. "] " .. f.Path) end
			else
				local b = blockedBy(err)
				if b then out("BLOCKED [" .. pass[1] .. "] " .. f.Path .. ": needs missing " .. b)
				else failures += 1; out("FAIL    [" .. pass[1] .. "] " .. f.Path .. ": " .. firstLines(err, 6)) end
			end
			report(M.problems, before + 1, pass[1] .. " require " .. f.Path)
			for i = errsBefore + 1, #M.errors do runtimeErrors += 1; out("ERROR   [" .. pass[1] .. "] while requiring " .. f.Path .. ": " .. firstLines(M.errors[i], 6)) end
		end
	end
	out(string.format("== require [%s]: %d/%d modules loaded", pass[1], okN, n))
end

------------------------------------------------------------------ 3. бутстрапы: сервер + один игрок, клиент (LocalPlayer)
env = E.make()
files = E.install()
M.strictErrors = false
local serverMissing, clientMissing = missingUnder({ RS, SSS }), missingUnder({ RS, SPS })
local serverRan, skipped = false, false
if #serverMissing > 0 then
	skipped = true
	out("== run: server bootstrap SKIPPED (" .. #serverMissing .. " server/shared files missing)")
else
	E.startServer()
	M.run(1, 1 / 30)
	player = M.newPlayer("Tester", 1)
	local spawn = M.workspace:FindFirstChild("LobbySpawn", true)
	M.spawnCharacter(player, spawn and spawn.CFrame + M.Vector3.new(0, 4, 0) or M.CFrame.new(0, 70, 0))
	M.run(1, 1 / 30)
	serverRan = true
	out(string.format("== run: server up; parts %d, VoidReady=%s, Money=%s", M.partCount, tostring(player:GetAttribute("VoidReady")), tostring(player:GetAttribute("Money"))))
end
if #clientMissing > 0 or not serverRan then
	skipped = true
	out("== run: client bootstrap SKIPPED (" .. (serverRan and (#clientMissing .. " client/shared files missing") or "server not running") .. ")")
else
	E.startClient(player)
	M.run(SECONDS, 1 / 30)
	out(string.format("== run: client %ds; PlayerGui descendants %d, workspace children %d", SECONDS, #player.PlayerGui:GetDescendants(), #M.workspace:GetChildren()))
end
if serverRan then
	report(M.problems, 1, "run")
	for _, e in ipairs(M.errors) do runtimeErrors += 1; out("ERROR   [run] " .. firstLines(e, 8)) end
end

------------------------------------------------------------------ итог
local bad = failures + apiCount + runtimeErrors + (STRICT and #missing or 0)
if bad == 0 then
	out(string.format("SMOKE OK (missing %d%s)", #missing, skipped and ", bootstraps skipped" or ""))
else
	out(string.format("SMOKE FAILED: %d failures, %d API problems, %d runtime errors, %d missing", failures, apiCount, runtimeErrors, #missing))
	error("smoke failed", 0)
end
