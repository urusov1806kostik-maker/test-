--!nocheck
-- VOID TD :: World
-- World.Build() строит (или переиспользует уже стоящие в workspace) все корни мира и освещение:
--   VoidTDMap (карта Void), VoidTDLobby (+ HalloweenGate), VoidTDHalloween (остров), VoidTDHalloweenMap.
-- Каждый корень собирается без родителя и кладётся в workspace последним. Ошибка Хэллоуина не ломает Void.

local Lighting = require(script:WaitForChild("Lighting"))
local VoidMap = require(script:WaitForChild("VoidMap"))
local Lobby = require(script:WaitForChild("Lobby"))
local Halloween = require(script:WaitForChild("Halloween"))

local World = {}

local function existing(name)
	local m = workspace:FindFirstChild(name)
	return m and m:IsA("Model") and m or nil
end

local function try(label, fn)
	local ok, res = pcall(fn)
	if not ok then
		warn("[VOID TD] " .. label .. " не построен: " .. tostring(res))
		return nil
	end
	return res
end

function World.Build()
	local out = {}
	out.Void = existing("VoidTDMap") or VoidMap()
	out.Lobby = existing("VoidTDLobby") or Lobby()
	try("Свет", Lighting)
	try("Хэллоуин-ворота", function()
		return Halloween.BuildGate(out.Lobby)
	end)
	out.Island = try("Хэллоуин-остров", Halloween.BuildIsland)
	out.Halloween = try("Хэллоуин-мир", Halloween.BuildMap)
	return out
end

return World
