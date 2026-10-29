--!nocheck
-- VOID TD :: Placement (клиент) — «призрак» юнита под курсором, круг дальности, проверка места.
-- Сервер всё перепроверяет (Placeable, дорога, деньги, лимиты).
--
-- API
--   Placement.Init(ctx) ; Placement.Start(unitId) ; Placement.Stop() ; Placement.Confirm()
--   Placement.Rotate() ; Placement.SetTouch(screenPos) ; Placement.Active

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Placement = {}
Placement.Active = false

local player = Players.LocalPlayer
local V = Vector3.new
local GOOD = Color3.fromRGB(80, 230, 140)
local BAD = Color3.fromRGB(255, 70, 90)
local NO_PLACE = "Сюда ставить нельзя"

local ctx, Config, Path, UnitModels, FX, UI, Renderer
local unitId, def, ghost, circle, disc, conn
local rotation = 0
local lastPos, valid, reason
local touchPos
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include

function Placement.Init(c)
	ctx = c
	Config, Path, UnitModels, FX, UI, Renderer = c.Config, c.Path, c.UnitModels, c.FX, c.UI, c.Renderer
end

local function isTouch()
	return UserInputService.TouchEnabled and not UserInputService.MouseEnabled
end

local function money()
	return player:GetAttribute("Money") or 0
end

local function cost()
	return def and def.Levels[1].Cost or math.huge
end

-- луч из камеры: точка касания, иначе курсор (на тач-экране до первого касания — центр экрана)
local function castRay(map)
	local cam = workspace.CurrentCamera
	if not cam then
		return nil
	end
	local ray
	if touchPos then
		ray = cam:ScreenPointToRay(touchPos.X, touchPos.Y)
	elseif isTouch() then
		local vs = cam.ViewportSize
		ray = cam:ViewportPointToRay(vs.X / 2, vs.Y / 2)
	else
		local m = UserInputService:GetMouseLocation()
		ray = cam:ViewportPointToRay(m.X, m.Y)
	end
	params.FilterDescendantsInstances = { map }
	return workspace:Raycast(ray.Origin, ray.Direction * 800, params)
end

local function check(hit)
	if not hit or not hit.Instance:GetAttribute("Placeable") then
		return false, NO_PLACE
	end
	local pos = hit.Position
	local ok, why = Path.IsPlacementClear(pos)
	if not ok then
		return false, why or NO_PLACE
	end
	local mine, same = 0, 0
	for _, v in pairs(Renderer.UnitViews) do
		if v.Pos and Path.FlatDistance(v.Pos, pos) < Config.Settings.PlacementSpacing then
			return false, "Слишком близко к другому юниту"
		end
		if v.Folder and v.Folder:GetAttribute("OwnerId") == player.UserId then
			mine += 1
			if v.UnitId == unitId then
				same += 1
			end
		end
	end
	if money() < cost() then
		return false, "Недостаточно денег"
	end
	if mine >= Config.Settings.MaxUnitsPerPlayer then
		return false, "Лимит юнитов"
	end
	local rar = Config.Rarities[def.Rarity]
	if rar and rar.PlacementLimit and same >= rar.PlacementLimit then
		return false, "Лимит этого юнита"
	end
	return true, nil
end

local function update()
	if not ghost then
		return
	end
	local map = Renderer.ActiveMap()
	if not map then
		valid, reason = false, NO_PLACE
		return
	end
	local hit = castRay(map)
	if not hit then
		valid, reason = false, NO_PLACE
		return
	end
	lastPos = hit.Position
	valid, reason = check(hit)
	local color = valid and GOOD or BAD
	ghost.Root.CFrame = CFrame.new(lastPos + V(0, ghost.HipHeight or 0, 0)) * CFrame.Angles(0, math.rad(rotation), 0)
	local r = def.Levels[1].Range or 10
	local flat = CFrame.Angles(0, 0, math.rad(90))
	circle.Size = V(0.15, r * 2, r * 2)
	circle.CFrame = CFrame.new(lastPos + V(0, 0.22, 0)) * flat
	circle.Color = color
	disc.CFrame = CFrame.new(lastPos + V(0, 0.25, 0)) * flat
	disc.Color = color
	for _, d in ipairs(ghost.Model:GetChildren()) do
		if d:IsA("Highlight") then
			d.FillColor = color
			d.OutlineColor = color
		end
	end
end

function Placement.Stop()
	Placement.Active = false
	if conn then
		conn:Disconnect()
		conn = nil
	end
	if ghost then
		ghost.Model:Destroy()
		ghost = nil
	end
	if circle then
		circle:Destroy()
		circle = nil
	end
	if disc then
		disc:Destroy()
		disc = nil
	end
	touchPos = nil
	if UI and UI.ShowPlacementHint then
		UI.ShowPlacementHint(false)
	end
end

function Placement.Start(id)
	local d = Config.Units[id]
	if not d then
		return
	end
	Placement.Stop()
	if money() < d.Levels[1].Cost then
		UI.Toast("Недостаточно денег: нужно $" .. Config.FormatNumber(d.Levels[1].Cost), "error")
		return
	end
	local phase = ctx.State:GetAttribute("Phase")
	if phase == "Victory" or phase == "Defeat" or not player:GetAttribute("InMatch") then
		return
	end
	local ok, rig = pcall(UnitModels.Build, id, 1)
	if not ok or not rig then
		warn("[VOID TD] призрак " .. tostring(id) .. ": " .. tostring(rig))
		return
	end
	unitId, def, ghost = id, d, rig
	for _, p in ipairs(rig.Model:GetDescendants()) do
		if p:IsA("BasePart") then
			p.CanQuery = false
			p.CanTouch = false
			p.CanCollide = false
			p.CastShadow = false
			if p.Transparency < 1 then
				p.Transparency = 0.35 + p.Transparency * 0.5
			end
		elseif p:IsA("ParticleEmitter") or p:IsA("Light") or p:IsA("Trail") then
			p:Destroy()
		end
	end
	local hl = Instance.new("Highlight")
	hl.FillTransparency = 0.75
	hl.OutlineTransparency = 0.2
	hl.DepthMode = Enum.HighlightDepthMode.Occluded
	hl.Parent = rig.Model
	rig.Model.Name = "VoidTD_Ghost"
	rig.Model.Parent = workspace
	circle = FX.Part({ Name = "VoidTD_GhostRange", Shape = Enum.PartType.Cylinder, Transparency = 0.72, Parent = workspace })
	disc = FX.Part({ Name = "VoidTD_GhostDisc", Shape = Enum.PartType.Cylinder, Size = V(0.2, 2.6, 2.6), Transparency = 0.3, Parent = workspace })
	Placement.Active = true
	touchPos = nil
	UI.CloseUnit()
	UI.ShowPlacementHint(true, isTouch())
	conn = RunService.RenderStepped:Connect(update)
	update()
end

function Placement.Rotate()
	rotation = (rotation + 45) % 360
end

function Placement.SetTouch(pos)
	touchPos = pos
	update()
end

function Placement.Confirm()
	if not Placement.Active then
		return
	end
	update()
	if not valid or not lastPos then
		UI.Toast(reason or NO_PLACE, "error")
		return
	end
	local id, price, before = unitId, cost(), money()
	local ok = ctx.Request("Place", { Unit = id, Position = lastPos, Rotation = rotation })
	if not ok then
		return -- причину уже показал Request
	end
	-- Shift — ставить ещё; деньги на атрибуте могут обновиться не сразу
	local shift = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
	local left = math.min(money(), before - price)
	if not (shift and left >= price and unitId == id) then
		Placement.Stop()
	end
end

return Placement
