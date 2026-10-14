--!nocheck
local M = require("./mock")
local E = {}

function E.make()
	local game = M.setup()
	local env = setmetatable({}, { __index = _G })
	env.game = game
	env.workspace = M.workspace
	env.Instance = { new = M.newInstance }
	for _, k in ipairs({ "Vector3", "Vector2", "CFrame", "Color3", "UDim", "UDim2", "Enum", "ColorSequence", "NumberSequence", "NumberSequenceKeypoint", "NumberRange", "TweenInfo", "RaycastParams", "Random", "typeof", "task" }) do
		env[k] = M[k]
	end
	local fake = 0
	env.os = setmetatable({ clock = function() fake = fake + 0.05; return fake end }, { __index = os })
	env.warn = function(...) print("WARN:", ...) end
	env.print = function(...) print("PRINT:", ...) end
	local cache = {}
	local function load(obj)
		local fn, err = loadstring(obj.Source, "=" .. obj.Name)
		assert(fn, err)
		local senv = setmetatable({ script = obj }, { __index = env })
		setfenv(fn, senv)
		return fn
	end
	env.require = function(obj)
		if cache[obj] ~= nil then return cache[obj] end
		local r = load(obj)()
		cache[obj] = r
		return r
	end
	E.env = env
	E.load = load
	return env
end

function E.runInstaller()
	local src = require("./installer_str")
	local fn = assert(loadstring(src, "=installer"))
	setfenv(fn, E.env)
	fn()
end

return E
