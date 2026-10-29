--!nocheck
-- VOID TD :: Net (клиент) — запросы к серверу и подписка на события.
-- Протокол — ReplicatedStorage.VoidTD.Net (не менять).
--
-- API
--   Net.Init(ctx) -> Request          -- Request(action, data) -> a, b; ошибку сервера показывает тостом
--   Net.Connect(ctx)                  -- Profile, EnemySpawn, Sync, Attack, Impact, Notify
--   Net.Connections                   -- подключения (для отладки/очистки)

local Net = {}
Net.Connections = {}

local ctx

function Net.Init(c)
	ctx = c
	local fn = c.Remotes:WaitForChild("Request")
	local function request(action, data)
		local ok, a, b = pcall(fn.InvokeServer, fn, action, data)
		local UI = ctx.UI
		if not ok then
			if UI and UI.Toast then
				UI.Toast("Нет связи с сервером", "error")
			end
			return false
		end
		if a == false and b ~= nil and UI and UI.Toast then
			UI.Toast(tostring(b), "error")
		end
		return a, b
	end
	Net.Request = request
	return request
end

local function on(name, fn)
	local ev = ctx.Remotes:WaitForChild(name)
	Net.Connections[#Net.Connections + 1] = ev.OnClientEvent:Connect(function(...)
		local ok, err = pcall(fn, ...)
		if not ok then
			warn("[VOID TD] " .. name .. ": " .. tostring(err))
		end
	end)
end

function Net.Connect(c)
	ctx = c or ctx
	local UI, Renderer, FX, Placement = ctx.UI, ctx.Renderer, ctx.FX, ctx.Placement

	on("Profile", function(p)
		if type(p) == "table" then
			UI.SetProfile(p)
		end
	end)
	on("EnemySpawn", Renderer.SpawnEnemy)
	on("Sync", Renderer.OnSync)
	on("Attack", Renderer.OnAttack)
	on("Impact", Renderer.OnImpact)
	on("Notify", function(p)
		if type(p) ~= "table" then
			return
		end
		UI.OnNotify(p)
		local kind = p.Type
		if kind == "CoreHit" then
			local map = Renderer.ActiveMap()
			local core = map and map:FindFirstChild("VoidCore")
			local c0 = core and core:GetAttribute("CoreCenter")
			if typeof(c0) == "Vector3" then
				FX.Sphere(c0, 6, FX.Colors.Pink, 0.4)
				FX.Burst(c0, FX.Colors.Pink, 10, 0.6, 10)
			end
		elseif kind == "Reset" then
			Placement.Stop()
		elseif kind == "WaveClear" or kind == "Victory" then
			Renderer.Cheer()
		end
	end)
end

return Net
