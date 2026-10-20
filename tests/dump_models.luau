--!nocheck
-- Выгрузка геометрии моделей для рейтрейсера (scratchpad/test/rt.py): строки "MODEL <имя> [json частей]".
-- Модели: юниты lv1/lv5 (<Id>_L1, <Id>_L5), союзники (Ally_<Id>), руны (Rune_<Id>), враги (Enemy_<Id>,
-- с фазами боссов ещё Enemy_<Id>_P<n>), кейсы (Case_<Id>). Нет строителя — строка SKIP, без ошибки.
-- Запуск: luau dump_models.luau [-a unit|ally|rune|enemy|case|<Id>|<Id>:<lv> ... [--nosolve]] > models.txt
--   python3 rt.py models.txt out.png [фильтр] --cols 4 --size 360
local E = require("./env")
local M = E.M
local P, CF = M._.P, M._.CF

local args = { ... }
local SOLVE = not table.find(args, "--nosolve")
local KINDS = { unit = true, ally = true, rune = true, enemy = true, case = true }
local want, ids = {}, {}
for _, a in ipairs(args) do
	if KINDS[a] then want[a] = true elseif a:sub(1, 2) ~= "--" then ids[#ids + 1] = a end
end
local all = next(want) == nil and #ids == 0

-- суставы как в движке: Part1 = Part0 * C0 * Transform * C1^-1; закреплённые части не двигаются
local function solveJoints(root)
	local adj, placed, queue, parts = {}, {}, {}, {}
	for _, j in ipairs(root:GetDescendants()) do
		if j:IsA("JointInstance") and P(j).Part0 and P(j).Part1 and P(j).Enabled ~= false then
			for _, part in ipairs({ P(j).Part0, P(j).Part1 }) do
				if not adj[part] then adj[part] = {}; parts[#parts + 1] = part end
				table.insert(adj[part], j)
			end
		end
	end
	local function bfs(seed)
		if not seed or placed[seed] then return end
		placed[seed] = true
		queue[#queue + 1] = seed
		local i = #queue
		while i <= #queue do
			local a = queue[i]
			i += 1
			for _, j in ipairs(adj[a] or {}) do
				local jp = P(j)
				local c0, c1 = jp.C0 or CF.identity, jp.C1 or CF.identity
				local link = c0 * (jp.Transform or CF.identity)
				local b, c
				if jp.Part0 == a then b, c = jp.Part1, P(a).CFrame * link * CF.Inverse(c1) else b, c = jp.Part0, P(a).CFrame * c1 * CF.Inverse(link) end
				if not placed[b] then
					placed[b] = true
					if not P(b).Anchored then P(b).CFrame = c end
					queue[#queue + 1] = b
				end
			end
		end
	end
	for _, p in ipairs(parts) do if P(p).Anchored then bfs(p) end end
	bfs(P(root).PrimaryPart)
	bfs(root:FindFirstChild("HumanoidRootPart", true))
	table.sort(parts, function(a, b) local s, t = P(a).Size, P(b).Size; return s.X * s.Y * s.Z > t.X * t.Y * t.Z end)
	for _, p in ipairs(parts) do bfs(p) end -- незакреплённая сборка: корень — самая крупная часть
end

local function f3(x, y, z) return string.format("%.3f,%.3f,%.3f", x, y, z) end
local function dump(name, model)
	if SOLVE then solveJoints(model) end
	local out = {}
	for _, d in ipairs(model:GetDescendants()) do
		if rawget(d, "_isPart") and (d.Transparency or 0) < 0.99 then
			local c, size = d.CFrame, d.Size
			local mesh = d:FindFirstChildOfClass("SpecialMesh")
			local shape = d.ClassName == "WedgePart" and "Wedge" or d.ClassName == "CornerWedgePart" and "CornerWedge" or (d:IsA("Part") and d.Shape.Name or "Block")
			if mesh then
				local mt = mesh.MeshType.Name
				local sc = mesh.Scale
				size = size * sc
				c = c * CF.new(mesh.Offset)
				if mt == "Sphere" or mt == "Head" or mt == "Wedge" then shape = mt
				elseif mt == "Cylinder" then shape, size, c = "Cylinder", M.Vector3.new(size.Y, size.X, size.Z), c * CF.Angles(0, 0, math.pi / 2) -- у меша ось Y
				elseif mt == "Brick" then shape = "Block" end
			end
			local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = c:GetComponents()
			local col = d.Color
			out[#out + 1] = string.format('{"shape":"%s","mat":"%s","t":%.2f,"p":[%s],"r":[%.5f,%.5f,%.5f,%.5f,%.5f,%.5f,%.5f,%.5f,%.5f],"s":[%s],"c":[%.3f,%.3f,%.3f]}',
				shape, d.Material.Name, d.Transparency, f3(x, y, z), r00, r01, r02, r10, r11, r12, r20, r21, r22, f3(size.X, size.Y, size.Z), col.R, col.G, col.B)
		end
	end
	print("MODEL " .. name .. " [" .. table.concat(out, ",") .. "]")
end

local env = E.make()
E.install()
M.strictErrors = false
M.services.Players.LocalPlayer = M.newPlayer("Viewer", 1) -- модели строятся на клиенте
local VoidTD = M.services.ReplicatedStorage:FindFirstChild("VoidTD")
local function find(...) -- новый путь, затем старое имя (для сравнения с legacy)
	for _, path in ipairs({ ... }) do
		local o = VoidTD
		for part in path:gmatch("[^/]+") do o = o and o:FindFirstChild(part) end
		if o and o:IsA("ModuleScript") then return o end
	end
	return nil
end
local function load(what, ...)
	local mod = find(...)
	if not mod then print("SKIP " .. what .. ": module " .. (...) .. " missing") return nil end
	local ok, r = pcall(E.client.require, mod)
	if not ok then print("SKIP " .. what .. ": " .. tostring(r):match("[^\n]*")) return nil end
	return r
end
local Config = load("config", "Config")
local Units = load("units/allies/runes", "Models/Units", "UnitModels")
local Enemies = load("enemies", "Models/Enemies", "EnemyModels")
local Cases = load("cases", "Models/Cases", "CaseModels")
if not Config then error("dump_models: Config is required", 0) end

local function try(name, fn)
	local ok, r = pcall(fn)
	if not ok then print("SKIP " .. name .. ": " .. tostring(r):match("[^\n]*")) return end
	if r == false then return end -- уже выгружено
	local model = type(r) == "table" and not M.isInstance(r) and r.Model or r
	if not (M.isInstance(model) and model:IsA("Model")) then print("SKIP " .. name .. ": builder returned no Model") return end
	dump(name, model)
	model:Destroy()
end
local function selected(kind, id) return all or want[kind] or table.find(ids, id) ~= nil end

for _, id in ipairs(Config.UnitOrder or {}) do
	local levels = {}
	for _, a in ipairs(ids) do local i, lv = a:match("^(.-):(%d)$"); if i == id then levels[#levels + 1] = tonumber(lv) end end
	if #levels == 0 and selected("unit", id) then levels = { 1, 5 } end
	for _, lv in ipairs(levels) do
		if not Units then break end
		if Units.Has and not Units.Has(id) then print("SKIP " .. id .. ": no builder") break end
		try(id .. "_L" .. lv, function() return Units.Build(id, lv) end)
	end
end
for _, id in ipairs(Config.AllyOrder or {}) do
	if Units and selected("ally", id) then try("Ally_" .. id, function() return assert(Units.BuildAlly, "no BuildAlly")(id) end) end
end
for _, id in ipairs(Config.RuneOrder or {}) do
	if Units and selected("rune", id) then try("Rune_" .. id, function() return assert(Units.BuildRune, "no BuildRune")(id) end) end
end
for _, id in ipairs(Config.EnemyOrder or {}) do
	if Enemies and selected("enemy", id) then
		if Enemies.Has and not Enemies.Has(id) then print("SKIP Enemy_" .. id .. ": no builder") continue end
		try("Enemy_" .. id, function()
			local rig = Enemies.Build(id)
			if rig.Phases and #rig.Phases > 0 then -- все фазы босса: показать Reveal, спрятать Break
				local copy = rig.Model:Clone()
				dump("Enemy_" .. id, copy)
				copy:Destroy()
				for _, ph in ipairs(rig.Phases) do
					for _, p in ipairs(ph.Reveal or {}) do p.Transparency = p:GetAttribute("PT") or 0 end
					for _, p in ipairs(ph.Break or {}) do p.Transparency = 1 end
				end
				dump("Enemy_" .. id .. "_P" .. #rig.Phases, rig.Model)
				rig.Model:Destroy()
				return false
			end
			return rig
		end)
	end
end
local caseIds = table.clone(Config.CaseOrder or {})
for id in pairs(Config.Cases or {}) do if not table.find(caseIds, id) then caseIds[#caseIds + 1] = id end end
for _, id in ipairs(caseIds) do
	if Cases and selected("case", id) then try("Case_" .. id, function() return Cases.Build(id) end) end
end
if #M.problems > 0 then print(string.format("# %d API problems while building (see API: lines above)", #M.problems)) end
