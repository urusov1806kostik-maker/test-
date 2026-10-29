--!nocheck
-- VOID TD :: Input (клиент) — клавиши, мышь, касания и подсветка юнита под курсором.
--   1–6 — юнит из слота; Q/Esc — отмена/закрыть; R — повернуть; E — улучшить; X — продать;
--   T — цель; G — окно ЮНИТЫ; ЛКМ — поставить/выбрать; ПКМ — отмена; касание — двигать призрак/выбрать.
--
-- API
--   Input.Init(ctx) ; Input.Update(dt) (подсветка раз в 0.05 с) ; Input.UnitUnder(screenPos, isTouch) -> uid, model

local UserInputService = game:GetService("UserInputService")

local Input = {}

local KC = Enum.KeyCode
local UIT = Enum.UserInputType
local SLOT_KEYS = { [KC.One] = 1, [KC.Two] = 2, [KC.Three] = 3, [KC.Four] = 4, [KC.Five] = 5, [KC.Six] = 6 }

local ctx, UI, Placement, Renderer
local hover
local hoverAcc = 0
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include

-- юнит под точкой экрана: модель с атрибутом Uid (поднимаемся по предкам-моделям)
function Input.UnitUnder(screenPos, isTouch)
	local cam = workspace.CurrentCamera
	local folder = Renderer.UnitFolder
	if not cam or not folder then
		return nil
	end
	local ray = isTouch and cam:ScreenPointToRay(screenPos.X, screenPos.Y) or cam:ViewportPointToRay(screenPos.X, screenPos.Y)
	params.FilterDescendantsInstances = { folder }
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 600, params)
	if not hit then
		return nil
	end
	local m = hit.Instance:FindFirstAncestorOfClass("Model")
	while m and m:GetAttribute("Uid") == nil do
		m = m:FindFirstAncestorOfClass("Model")
	end
	if m then
		return m:GetAttribute("Uid"), m
	end
	return nil
end

local function onBegan(input, gp)
	local t = input.UserInputType
	if t == UIT.Keyboard then
		local k = input.KeyCode
		if gp and k ~= KC.Escape then
			return -- печать в чате / текстовом поле
		end
		local slot = SLOT_KEYS[k]
		if slot then
			local id = UI.EquippedAt(slot)
			if id then
				Placement.Start(id)
			end
		elseif k == KC.Q or k == KC.Escape then
			if Placement.Active then
				Placement.Stop()
			else
				UI.CloseUnit()
			end
		elseif k == KC.R then
			if Placement.Active then
				Placement.Rotate()
			end
		elseif k == KC.E then
			UI.UpgradeSelected()
		elseif k == KC.X then
			UI.SellSelected()
		elseif k == KC.T then
			UI.CycleTarget()
		elseif k == KC.G then
			UI.Toggle("Inventory")
		end
	elseif t == UIT.MouseButton1 then
		if gp then
			return -- клик по интерфейсу
		end
		if Placement.Active then
			Placement.Confirm()
		else
			local uid = Input.UnitUnder(UserInputService:GetMouseLocation(), false)
			if uid then
				UI.OpenUnit(uid)
			else
				UI.CloseUnit()
			end
		end
	elseif t == UIT.MouseButton2 then
		if Placement.Active then
			Placement.Stop()
		end
	elseif t == UIT.Touch then
		if gp then
			return
		end
		local pos = Vector2.new(input.Position.X, input.Position.Y)
		if Placement.Active then
			Placement.SetTouch(pos) -- ставит кнопка PLACE
		else
			local uid = Input.UnitUnder(pos, true)
			if uid then
				UI.OpenUnit(uid)
			end
		end
	end
end

function Input.Init(c)
	ctx = c
	UI, Placement, Renderer = c.UI, c.Placement, c.Renderer
	hover = Instance.new("Highlight")
	hover.Name = "VoidTD_Hover"
	hover.FillTransparency = 1
	hover.OutlineColor = Color3.fromRGB(220, 160, 255)
	hover.OutlineTransparency = 0.1
	hover.DepthMode = Enum.HighlightDepthMode.Occluded
	if Input.Conn then
		Input.Conn:Disconnect()
	end
	Input.Conn = UserInputService.InputBegan:Connect(onBegan)
end

function Input.Update(dt)
	hoverAcc += dt
	if hoverAcc < 0.05 then
		return
	end
	hoverAcc = 0
	if Placement.Active or not UserInputService.MouseEnabled then
		hover.Parent = nil
		return
	end
	local _, model = Input.UnitUnder(UserInputService:GetMouseLocation(), false)
	if model then
		hover.Adornee = model
		hover.Parent = model
	else
		hover.Parent = nil
	end
end

return Input
