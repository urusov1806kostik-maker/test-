--!nocheck
-- VOID TD :: World.Lighting
-- Ночное небо Пустоты: атмосфера, звёзды, мягкий bloom (клиент выключает VoidBloom в Lite), цветокоррекция.

local LightingService = game:GetService("Lighting")

local rgb = Color3.fromRGB

local function new(class, name, props)
	local o = Instance.new(class)
	o.Name = name
	for k, v in pairs(props) do
		o[k] = v
	end
	o.Parent = LightingService
	return o
end

return function()
	local L = LightingService
	L.ClockTime = 0.2
	L.Brightness = 2
	L.Ambient = rgb(58, 40, 86)
	L.OutdoorAmbient = rgb(86, 64, 120)
	L.ColorShift_Top = rgb(120, 80, 200)
	L.EnvironmentDiffuseScale = 0.4
	L.EnvironmentSpecularScale = 0.6
	L.GlobalShadows = true
	-- туман Lighting игнорируется при Atmosphere, но пусть совпадает по цвету
	L.FogColor = rgb(40, 20, 70)
	L.FogStart = 150
	L.FogEnd = 900
	pcall(function()
		L.Technology = Enum.Technology.Future -- из скрипта может быть недоступно — тогда как сохранено в месте
	end)
	for _, name in ipairs({ "VoidAtmosphere", "VoidBloom", "VoidColor", "VoidSky", "VoidRays" }) do
		local o = L:FindFirstChild(name)
		if o then
			o:Destroy()
		end
	end
	for _, ch in ipairs(L:GetChildren()) do
		if ch:IsA("Atmosphere") or ch:IsA("Sky") then
			ch:Destroy()
		end
	end
	new("Atmosphere", "VoidAtmosphere", {
		Density = 0.38, Offset = 0.15, Color = rgb(110, 60, 170), Decay = rgb(40, 10, 60), Glare = 0.3, Haze = 2.2,
	})
	new("Sky", "VoidSky", { StarCount = 5000, CelestialBodiesShown = true, MoonAngularSize = 18 })
	new("BloomEffect", "VoidBloom", { Intensity = 0.35, Size = 18, Threshold = 1.4 })
	new("ColorCorrectionEffect", "VoidColor", { Brightness = 0.02, Contrast = 0.12, Saturation = 0.12, TintColor = rgb(240, 225, 255) })
end
