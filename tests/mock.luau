--!nocheck
-- Minimal Roblox API mock for crash-testing VOID TD sources in the Luau CLI.
local M = {}

local rawtypeof = typeof
local function tag(t, name) return setmetatable(t, t.__mt or getmetatable(t)) end

------------------------------------------------------------------ Vector3
local V3 = {}
V3.__index = function(v, k)
	if k == "Magnitude" then return math.sqrt(v.X*v.X + v.Y*v.Y + v.Z*v.Z) end
	if k == "Unit" then local m = math.sqrt(v.X*v.X + v.Y*v.Y + v.Z*v.Z); if m == 0 then return v end return V3.new(v.X/m, v.Y/m, v.Z/m) end
	return V3[k]
end
local function num(v, what) assert(v == nil or type(v) == "number", what .. ": number expected, got " .. type(v)); return v end
function V3.new(x, y, z) num(x, "Vector3.new#1"); num(y, "Vector3.new#2"); num(z, "Vector3.new#3"); return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0, __type = "Vector3" }, V3) end
V3.__add = function(a, b) assert(type(a) == "table" and type(b) == "table" and rawget(b, "__type") == "Vector3" and rawget(a, "__type") == "Vector3", "bad Vector3 add"); return V3.new(a.X+b.X, a.Y+b.Y, a.Z+b.Z) end
V3.__sub = function(a, b) return V3.new(a.X-b.X, a.Y-b.Y, a.Z-b.Z) end
V3.__unm = function(a) return V3.new(-a.X, -a.Y, -a.Z) end
V3.__mul = function(a, b)
	assert((type(a) == "number" or rawget(a, "__type") == "Vector3") and (type(b) == "number" or rawget(b, "__type") == "Vector3"), "bad Vector3 multiply")
	if type(a) == "number" then return V3.new(b.X*a, b.Y*a, b.Z*a) end
	if type(b) == "number" then return V3.new(a.X*b, a.Y*b, a.Z*b) end
	return V3.new(a.X*b.X, a.Y*b.Y, a.Z*b.Z)
end
V3.__div = function(a, b)
	if type(b) == "number" then return V3.new(a.X/b, a.Y/b, a.Z/b) end
	return V3.new(a.X/b.X, a.Y/b.Y, a.Z/b.Z)
end
V3.__eq = function(a, b) return a.X == b.X and a.Y == b.Y and a.Z == b.Z end
V3.__tostring = function(v) return string.format("(%.2f, %.2f, %.2f)", v.X, v.Y, v.Z) end
function V3.Dot(a, b) return a.X*b.X + a.Y*b.Y + a.Z*b.Z end
function V3.Cross(a, b) return V3.new(a.Y*b.Z - a.Z*b.Y, a.Z*b.X - a.X*b.Z, a.X*b.Y - a.Y*b.X) end
function V3.Lerp(a, b, t) return a + (b - a) * t end
V3.zero = V3.new(0, 0, 0)
V3.one = V3.new(1, 1, 1)
M.Vector3 = V3

local V2 = {}
V2.__index = function(v, k) if k == "Magnitude" then return math.sqrt(v.X*v.X+v.Y*v.Y) end return V2[k] end
function V2.new(x, y) num(x, "Vector2.new#1"); num(y, "Vector2.new#2"); return setmetatable({ X = x or 0, Y = y or 0, __type = "Vector2" }, V2) end
V2.__add = function(a, b) return V2.new(a.X+b.X, a.Y+b.Y) end
V2.__sub = function(a, b) return V2.new(a.X-b.X, a.Y-b.Y) end
M.Vector2 = V2

------------------------------------------------------------------ CFrame (3x3 rot + pos)
local CFm = {}
local function mk(px, py, pz, r)
	return setmetatable({ p = V3.new(px, py, pz), r = r, __type = "CFrame" }, CFm)
end
local I = { 1,0,0, 0,1,0, 0,0,1 }
local function matmul(a, b)
	local c = {}
	for i = 0, 2 do for j = 0, 2 do
		local s = 0
		for k = 0, 2 do s = s + a[i*3+k+1] * b[k*3+j+1] end
		c[i*3+j+1] = s
	end end
	return c
end
local function matvec(a, v)
	return V3.new(a[1]*v.X + a[2]*v.Y + a[3]*v.Z, a[4]*v.X + a[5]*v.Y + a[6]*v.Z, a[7]*v.X + a[8]*v.Y + a[9]*v.Z)
end
local function transpose(a) return { a[1],a[4],a[7], a[2],a[5],a[8], a[3],a[6],a[9] } end
CFm.__index = function(cf, k)
	if k == "Position" then return cf.p end
	if k == "X" then return cf.p.X end
	if k == "Y" then return cf.p.Y end
	if k == "Z" then return cf.p.Z end
	if k == "Rotation" then return mk(0, 0, 0, cf.r) end
	if k == "LookVector" then return V3.new(-cf.r[3], -cf.r[6], -cf.r[9]) end
	if k == "RightVector" then return V3.new(cf.r[1], cf.r[4], cf.r[7]) end
	if k == "UpVector" then return V3.new(cf.r[2], cf.r[5], cf.r[8]) end
	return CFm[k]
end
function CFm.new(a, b, c)
	if a == nil then return mk(0, 0, 0, I) end
	if type(a) == "table" then assert(rawget(a, "__type") == "Vector3", "CFrame.new expects Vector3"); return mk(a.X, a.Y, a.Z, I) end
	num(a, "CFrame.new#1"); num(b, "CFrame.new#2"); num(c, "CFrame.new#3")
	return mk(a, b, c, I)
end
function CFm.Angles(rx, ry, rz)
	num(rx, "Angles#1"); num(ry, "Angles#2"); num(rz, "Angles#3")
	local cx, sx, cy, sy, cz, sz = math.cos(rx), math.sin(rx), math.cos(ry), math.sin(ry), math.cos(rz), math.sin(rz)
	local X = { 1,0,0, 0,cx,-sx, 0,sx,cx }
	local Y = { cy,0,sy, 0,1,0, -sy,0,cy }
	local Z = { cz,-sz,0, sz,cz,0, 0,0,1 }
	return mk(0, 0, 0, matmul(matmul(X, Y), Z))
end
function CFm.lookAt(at, target, up)
	up = up or V3.new(0, 1, 0)
	local f = (target - at)
	assert(f.Magnitude > 1e-9, "lookAt with zero direction")
	f = f.Unit
	local r = f:Cross(up)
	if r.Magnitude < 1e-6 then r = V3.new(1, 0, 0) end
	r = r.Unit
	local u = r:Cross(f)
	local back = -f
	return mk(at.X, at.Y, at.Z, { r.X,u.X,back.X, r.Y,u.Y,back.Y, r.Z,u.Z,back.Z })
end
CFm.__mul = function(a, b)
	if rawget(b, "__type") == "Vector3" then return matvec(a.r, b) + a.p end
	local p = matvec(a.r, b.p) + a.p
	return mk(p.X, p.Y, p.Z, matmul(a.r, b.r))
end
CFm.__add = function(a, v) return mk(a.p.X+v.X, a.p.Y+v.Y, a.p.Z+v.Z, a.r) end
function CFm.Inverse(cf)
	local rt = transpose(cf.r)
	local p = -(matvec(rt, cf.p))
	return mk(p.X, p.Y, p.Z, rt)
end
function CFm.Lerp(a, b, t)
	local p = a.p:Lerp(b.p, t)
	local r = {}
	for i = 1, 9 do r[i] = a.r[i] + (b.r[i] - a.r[i]) * t end
	return mk(p.X, p.Y, p.Z, r)
end
function CFm.ToWorldSpace(a, b) return a * b end
CFm.identity = CFm.new()
M.CFrame = CFm

------------------------------------------------------------------ misc datatypes
local function datatype(name, ctor)
	return { new = function(...) local t = { __type = name, args = { ... } }; return t end }
end
M.Color3 = {
	new = function(r, g, b) num(r, "Color3"); num(g, "Color3"); num(b, "Color3"); return setmetatable({ R = r, G = g, B = b, __type = "Color3" }, { __index = { Lerp = function(a, b2, t) return M.Color3.new(a.R + (b2.R - a.R) * t, a.G, a.B) end } }) end,
}
M.Color3.fromRGB = function(r, g, b) return M.Color3.new(r / 255, g / 255, b / 255) end
M.UDim = { new = function(s, o) return { Scale = s, Offset = o, __type = "UDim" } end }
M.UDim2 = {
	new = function(a, b, c, d) return { __type = "UDim2", X = { Scale = a or 0, Offset = b or 0 }, Y = { Scale = c or 0, Offset = d or 0 } } end,
}
M.UDim2.fromScale = function(a, b) return M.UDim2.new(a, 0, b, 0) end
M.UDim2.fromOffset = function(a, b) return M.UDim2.new(0, a, 0, b) end
M.ColorSequence = datatype("ColorSequence")
M.NumberSequence = datatype("NumberSequence")
M.NumberSequenceKeypoint = datatype("NumberSequenceKeypoint")
M.NumberRange = datatype("NumberRange")
M.TweenInfo = datatype("TweenInfo")
M.RaycastParams = { new = function() return { __type = "RaycastParams" } end }
M.Random = {
	new = function(seed)
		local state = seed or 12345
		local function nxt()
			state = (state * 1103515245 + 12345) % 2147483648
			return state / 2147483648
		end
		return {
			NextNumber = function(_, a, b) if a == nil then return nxt() end return a + (b - a) * nxt() end,
			NextInteger = function(_, a, b) return a + math.floor(nxt() * (b - a + 1)) end,
		}
	end,
}

-- Enum: Enum.Material.Neon -> token
local enumMT = {}
local function enumItem(cat, name) return { __type = "EnumItem", Name = name, EnumType = cat } end
M.Enum = setmetatable({}, { __index = function(root, cat)
	local c = setmetatable({}, { __index = function(t, name) local it = enumItem(cat, name); rawset(t, name, it); return it end })
	rawset(root, cat, c)
	return c
end })

M.typeof = function(v)
	if type(v) == "table" and rawget(v, "__type") then return rawget(v, "__type") end
	if type(v) == "table" and rawget(v, "__isInstance") then return "Instance" end
	return rawtypeof(v)
end

------------------------------------------------------------------ signals
local Signal = {}
Signal.__index = Signal
function Signal.new() return setmetatable({ handlers = {} }, Signal) end
function Signal:Connect(fn)
	local h = { fn = fn, connected = true }
	table.insert(self.handlers, h)
	return { Disconnect = function() h.connected = false end, Connected = true }
end
function Signal:Fire(...)
	for _, h in ipairs(self.handlers) do if h.connected then h.fn(...) end end
end
function Signal:Wait() return coroutine.yield() end
M.Signal = Signal

------------------------------------------------------------------ Instances
local EVENTS = {
	MouseEnter = true, MouseLeave = true, MouseButton1Down = true, MouseButton1Up = true, MouseButton1Click = true,
	Activated = true, AttributeChanged = true, ChildAdded = true, ChildRemoved = true, OnClientEvent = true,
	OnServerEvent = true, Changed = true, Heartbeat = true, RenderStepped = true, Stepped = true, PlayerAdded = true,
	PlayerRemoving = true, InputBegan = true, InputEnded = true, Touched = true, DescendantAdded = true,
}
M.instanceCount = 0
M.partCount = 0
local Inst = {}
local function isA(self, class)
	local c = self.ClassName
	if class == "Instance" then return true end
	if c == class then return true end
	local base = {
		Part = { "BasePart", "PVInstance" }, WedgePart = { "BasePart", "PVInstance" }, SpawnLocation = { "Part", "BasePart" },
		Model = { "PVInstance" }, Workspace = { "Model" }, ScreenGui = { "LayerCollector" }, BillboardGui = { "LayerCollector" },
		TextButton = { "GuiButton", "GuiObject" }, ImageButton = { "GuiButton", "GuiObject" }, TextLabel = { "GuiObject" },
		Frame = { "GuiObject" }, ScrollingFrame = { "GuiObject" }, ViewportFrame = { "GuiObject" },
		Script = { "LuaSourceContainer" }, LocalScript = { "Script", "LuaSourceContainer" }, ModuleScript = { "LuaSourceContainer" },
		Motor6D = { "JointInstance" }, Weld = { "JointInstance" }, Atmosphere = {}, Sky = {},
		BloomEffect = { "PostEffect" }, ColorCorrectionEffect = { "PostEffect" },
	}
	for _, b in ipairs(base[c] or {}) do if b == class then return true end end
	return false
end

local instMT
instMT = {
	__index = function(self, k)
		local props = rawget(self, "_props")
		if props[k] ~= nil then return props[k] end
		if Inst[k] then return Inst[k] end
		local child = Inst.FindFirstChild(self, k)
		if child then return child end
		if EVENTS[k] then local s = Signal.new(); props[k] = s; return s end
		if k == "CFrame" then return CFm.new() end
		if k == "Position" then local cf = props.CFrame; return cf and cf.p or V3.new() end
		if k == "Size" then return V3.new(1, 1, 1) end
		if k == "Transparency" then return 0 end
		return nil
	end,
	__newindex = function(self, k, v)
		local props = rawget(self, "_props")
		if k == "Parent" then
			local old = props.Parent
			if old == v then return end
			if old then
				local ch = rawget(old, "_children")
				for i, c in ipairs(ch) do if c == self then table.remove(ch, i); break end end
				if rawget(old, "_props").ChildRemoved then old.ChildRemoved:Fire(self) end
			end
			props.Parent = v
			if v then
				assert(rawget(v, "__isInstance"), "Parent must be an Instance")
				table.insert(rawget(v, "_children"), self)
				if rawget(v, "_props").ChildAdded then v.ChildAdded:Fire(self) end
			end
			return
		end
		if k == "Position" and props.ClassName ~= "TextLabel" and rawget(self, "_isPart") then
			local cf = props.CFrame or CFm.new()
			props.CFrame = CFm.new(v.X, v.Y, v.Z) * cf.Rotation
			return
		end
		if k == "Size" and rawget(self, "_isPart") then
			assert(type(v) == "table" and rawget(v, "__type") == "Vector3" and type(v.X) == "number", "Part.Size must be Vector3")
		end
		if (k == "CFrame" or k == "C0" or k == "C1") and v ~= nil then
			assert(type(v) == "table" and rawget(v, "__type") == "CFrame", k .. " must be CFrame")
		end
		if ((k == "Color" and rawget(self, "_isPart")) or k == "BackgroundColor3" or k == "TextColor3") and v ~= nil then
			assert(type(v) == "table" and rawget(v, "__type") == "Color3", k .. " must be Color3")
		end
		if k == "Shape" and v and v.Name == "Ball" and props.Size then
			local s = props.Size; local m = math.min(s.X, s.Y, s.Z); props.Size = V3.new(m, m, m)
		end
		props[k] = v
	end,
	__tostring = function(self) return rawget(self, "_props").Name end,
}

function M.newInstance(class)
	M.instanceCount = M.instanceCount + 1
	local self = setmetatable({ __isInstance = true, _props = { ClassName = class, Name = class, Archivable = true }, _children = {}, _attrs = {} }, instMT)
	if class == "Part" or class == "WedgePart" or class == "SpawnLocation" then
		rawset(self, "_isPart", true)
		M.partCount = M.partCount + 1
		rawget(self, "_props").CFrame = CFm.new()
		rawget(self, "_props").Size = V3.new(4, 1, 2)
	end
	return self
end

function Inst.IsA(self, c) return isA(self, c) end
function Inst.GetChildren(self) local t = {}; for i, c in ipairs(rawget(self, "_children")) do t[i] = c end; return t end
function Inst.GetDescendants(self)
	local out = {}
	local function rec(o) for _, c in ipairs(rawget(o, "_children")) do out[#out + 1] = c; rec(c) end end
	rec(self)
	return out
end
function Inst.FindFirstChild(self, name, recursive)
	for _, c in ipairs(rawget(self, "_children")) do if rawget(c, "_props").Name == name then return c end end
	if recursive then for _, c in ipairs(rawget(self, "_children")) do local r = Inst.FindFirstChild(c, name, true); if r then return r end end end
	return nil
end
function Inst.FindFirstChildOfClass(self, class)
	for _, c in ipairs(rawget(self, "_children")) do if rawget(c, "_props").ClassName == class then return c end end
	return nil
end
function Inst.FindFirstChildWhichIsA(self, class)
	for _, c in ipairs(rawget(self, "_children")) do if isA(c, class) then return c end end
	return nil
end
function Inst.FindFirstAncestorOfClass(self, class)
	local p = self.Parent
	while p do if p.ClassName == class then return p end p = p.Parent end
	return nil
end
function Inst.WaitForChild(self, name)
	local c = Inst.FindFirstChild(self, name)
	if not c then error("WaitForChild would hang: " .. tostring(name) .. " in " .. tostring(self.Name)) end
	return c
end
function Inst.Destroy(self)
	for _, c in ipairs(Inst.GetChildren(self)) do Inst.Destroy(c) end
	self.Parent = nil
	rawset(self, "_destroyed", true)
end
function Inst.ClearAllChildren(self) for _, c in ipairs(Inst.GetChildren(self)) do Inst.Destroy(c) end end
function Inst.SetAttribute(self, k, v)
	local t = M.typeof(v)
	assert(v == nil or t == "number" or t == "string" or t == "boolean" or t == "Vector3" or t == "Color3" or t == "CFrame" or t == "UDim2", "bad attribute type " .. t .. " for " .. k)
	rawget(self, "_attrs")[k] = v
	if rawget(self, "_props").AttributeChanged then self.AttributeChanged:Fire(k) end
end
function Inst.GetAttribute(self, k) return rawget(self, "_attrs")[k] end
function Inst.GetPropertyChangedSignal(self, prop) return Signal.new() end
function Inst.GetPivot(self)
	local props = rawget(self, "_props")
	if props.WorldPivot then return props.WorldPivot end
	if props.PrimaryPart then return props.PrimaryPart.CFrame end
	if rawget(self, "_isPart") then return props.CFrame end
	return CFm.new()
end
function Inst.PivotTo(self, cf)
	local cur = Inst.GetPivot(self)
	local delta = cf * cur:Inverse()
	for _, d in ipairs(Inst.GetDescendants(self)) do
		if rawget(d, "_isPart") then rawget(d, "_props").CFrame = delta * rawget(d, "_props").CFrame end
	end
	if rawget(self, "_isPart") then rawget(self, "_props").CFrame = cf end
	if rawget(self, "_props").WorldPivot then rawget(self, "_props").WorldPivot = cf end
end
function Inst.ScaleTo(self, s)
	assert(type(s) == "number" and s > 0, "ScaleTo needs positive number")
	local pivot = Inst.GetPivot(self)
	for _, d in ipairs(Inst.GetDescendants(self)) do
		local props = rawget(d, "_props")
		if rawget(d, "_isPart") then
			props.Size = props.Size * s
			local rel = pivot:Inverse() * props.CFrame
			local r = rel.Rotation
			local p = rel.Position * s
			props.CFrame = pivot * (CFm.new(p.X, p.Y, p.Z) * r)
		elseif props.ClassName == "Motor6D" or props.ClassName == "Weld" then
			for _, key in ipairs({ "C0", "C1" }) do
				local c = props[key]
				if c then local p = c.Position * s; props[key] = CFm.new(p.X, p.Y, p.Z) * c.Rotation end
			end
		end
	end
end
function Inst.GetPlayers(self) return M.players end
function Inst.Clone(self)
	local c = M.newInstance(self.ClassName)
	for k, v in pairs(rawget(self, "_props")) do if k ~= "Parent" then rawget(c, "_props")[k] = v end end
	for k, v in pairs(rawget(self, "_attrs")) do rawget(c, "_attrs")[k] = v end
	for _, ch in ipairs(rawget(self, "_children")) do Inst.Clone(ch).Parent = c end
	return c
end
function Inst.Raycast(self, origin, dir, params) return M.raycast and M.raycast(origin, dir, params) or nil end
function Inst.GetServerTimeNow() return M.now end
function Inst.GetService(self, name) return M.services[name] end
function Inst.BindToClose() end
function Inst.Create(_, obj, info, goal) return { Play = function() for k, v in pairs(goal) do obj[k] = v end end, Cancel = function() end, Completed = Signal.new() } end
function Inst.FireAllClients(self, ...) M.log(self.Name, ...) end
function Inst.FireClient(self, pl, ...) M.log(self.Name, ...) end
function Inst.InvokeServer(self, ...) return rawget(self, "_props").OnServerInvoke(M.players[1], ...) end
function Inst.IsStudio() return true end
function Inst.IsKeyDown() return false end
function Inst.GetMouseLocation() return V2.new(500, 300) end
function Inst.ViewportPointToRay(_, x, y) return { Origin = V3.new(0, 200, 0), Direction = V3.new(0, -1, 0) } end
function Inst.ScreenPointToRay(_, x, y) return { Origin = V3.new(0, 200, 0), Direction = V3.new(0, -1, 0) } end
function Inst.GetDataStore() return { GetAsync = function() return nil end, SetAsync = function() end } end
function Inst.GetGuiInset() return V2.new(0, 36) end
function Inst.Play() end

M.log = function() end

------------------------------------------------------------------ scheduler
M.now = 0
local queue = {}
local function schedule(at, co, ...)
	table.insert(queue, { at = at, co = co, args = table.pack(...) })
end
local function resume(co, ...)
	local ok, err = coroutine.resume(co, ...)
	if not ok then error(debug.traceback(co, tostring(err)), 0) end
end
M.task = {
	spawn = function(f, ...)
		local co = type(f) == "thread" and f or coroutine.create(f)
		resume(co, ...)
		return co
	end,
	defer = function(f, ...) schedule(M.now, coroutine.create(f), ...) end,
	delay = function(t, f, ...) schedule(M.now + (t or 0), coroutine.create(f), ...) end,
	wait = function(t)
		local co = coroutine.running()
		schedule(M.now + (t or 0.03), co)
		coroutine.yield()
		return t
	end,
}
function M.runDue()
	local again = true
	while again do
		again = false
		for i, item in ipairs(queue) do
			if item.at <= M.now + 1e-9 then
				table.remove(queue, i)
				resume(item.co, table.unpack(item.args, 1, item.args.n))
				again = true
				break
			end
		end
	end
end

------------------------------------------------------------------ services
function M.setup()
	local game = M.newInstance("DataModel")
	M.game = game
	M.services = {}
	local function svc(name, class)
		local s = M.newInstance(class or name)
		s.Name = name
		s.Parent = game
		M.services[name] = s
		return s
	end
	svc("ReplicatedStorage")
	svc("ServerScriptService")
	svc("Lighting")
	svc("Players")
	svc("RunService")
	svc("TweenService")
	svc("UserInputService")
	svc("DataStoreService")
	svc("GuiService")
	local sp = svc("StarterPlayer")
	local sps = M.newInstance("Folder"); sps.Name = "StarterPlayerScripts"; sps.Parent = sp
	local ws = svc("Workspace", "Workspace")
	M.workspace = ws
	local cam = M.newInstance("Camera"); cam.Name = "Camera"; cam.Parent = ws
	ws.CurrentCamera = cam
	cam.ViewportSize = V2.new(1280, 720)
	M.services.UserInputService.TouchEnabled = false
	M.services.UserInputService.MouseEnabled = true
	M.players = {}
	return game
end

function M.newPlayer(name, id)
	local p = M.newInstance("Player")
	p.Name = name
	p.DisplayName = name
	p.UserId = id
	p.Parent = M.services.Players
	local pg = M.newInstance("PlayerGui"); pg.Name = "PlayerGui"; pg.Parent = p
	table.insert(M.players, p)
	return p
end

M.Inst = Inst
return M
