--!nocheck
-- VOID TD :: UI.EndScreen — экран победы/поражения с таймером до новой игры.
--
-- API
--   EndScreen.Build(UI, ctx) ; EndScreen.Show(victory, payload) ; EndScreen.Clear()

local EndScreen = {}

local rgb = Color3.fromRGB
local V2 = Vector2.new

local UI, ctx, K, T, refs
local overlays = {}

function EndScreen.Build(ui, c)
	UI, ctx = ui, c
	K, T, refs = ui.Kit, ui.Theme, ui.Refs
end

function EndScreen.Clear()
	for _, o in ipairs(overlays) do
		o:Destroy()
	end
	table.clear(overlays)
	refs.EndOverlay = nil
end

function EndScreen.Show(victory, p)
	EndScreen.Clear()
	p = p or {}
	local ov = K.new("Frame", {
		Parent = UI.Root, Name = "EndOverlay", Size = UDim2.fromScale(1, 1), BorderSizePixel = 0, ZIndex = 30,
		BackgroundColor3 = victory and rgb(30, 10, 50) or rgb(40, 0, 10), BackgroundTransparency = 1,
	})
	K.tween(ov, 0.6, { BackgroundTransparency = 0.3 })
	local title = K.label({
		Parent = ov, AnchorPoint = V2(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.38), Size = UDim2.fromOffset(800, 120), ZIndex = 31,
		Text = victory and "VICTORY" or "DEFEAT", TextColor3 = victory and T.Gold or T.Bad, StrokeThickness = 4,
	})
	local sc = K.new("UIScale", { Parent = title, Scale = 0.2 })
	K.tween(sc, 0.5, { Scale = 1 }, Enum.EasingStyle.Back)
	local sub
	if victory then
		sub = "Пустота отступила! Награда: 💎" .. tostring(p.Gems or 0)
		if p.Coins then
			sub = sub .. "  +🎃" .. tostring(p.Coins) .. " Halloween Coins"
		end
	else
		sub = "Ядро разрушено на волне " .. tostring(p.Wave or 0)
		if p.Mode == "Halloween" then
			sub = sub .. "  •  Halloween Coins не выдаются"
		end
	end
	K.label({ Parent = ov, AnchorPoint = V2(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(800, 40), ZIndex = 31, Text = sub })
	local timer = K.label({ Parent = ov, AnchorPoint = V2(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.57), Size = UDim2.fromOffset(600, 30), ZIndex = 31, Text = "", TextColor3 = T.Dim })
	overlays[#overlays + 1] = ov
	refs.EndOverlay = ov
	task.spawn(function()
		for n = math.floor(p.Reset or 15), 0, -1 do
			if not ov.Parent then
				return
			end
			timer.Text = "Новая игра через " .. n .. " c"
			task.wait(1)
		end
	end)
end

return EndScreen
