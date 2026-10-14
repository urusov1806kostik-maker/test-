--!nocheck
-- VOID TD :: Placement (клиент)
-- Полупрозрачный призрак юнита следует за курсором, круг радиуса показывает зелёный/красный статус.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Placement = {}
Placement.Active = false

local ctx, Config, PathUtil, UnitModels, FX, UI, Renderer
local player = Players.LocalPlayer

local V = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles
local rad = math.rad

local ghost, circle, inner, conn
local unitId
local rotation = 0
local valid = false
local lastPos
local touchPos
local reason = ""

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include

local GOOD = Color3.fromRGB(80, 230, 140)
local BAD = Color3.fromRGB(255, 70, 90)

local function isTouch()
	return UserInputService.TouchEnabled and not UserInputService.MouseEnabled
end

local function countMine(id)
	local total, same = 0, 0
	for _, v in pairs(Renderer.UnitViews) do
		if v.Folder:GetAttribute("OwnerId") == player.UserId then
			total = total + 1
			if v.UnitId == id then
				same = same + 1
			end
		end
	end
	return total, same
end

local function check(hit, pos)
	if not hit or not hit.Instance:GetAttribute("Placeable") then
		return false, "Сюда ставить нельзя"
	end
	local ok, why = PathUtil.IsPlacementClear(pos)
	if not ok then
		return false, why
	end
	for _, v in pairs(Renderer.UnitViews) do
		if PathUtil.FlatDistance(v.Pos, pos) < Config.Settings.PlacementSpacing then
			return false, "Слишком близко к другому юниту"
		end
	end
	local def = Config.Units[unitId]
	if (player:GetAttribute("Money") or 0) < def.Levels[1].Cost then
		return false, "Недостаточно денег"
	end
	local total, same = countMine(unitId)
	if total >= Config.Settings.MaxUnitsPerPlayer then
		return false, "Лимит юнитов"
	end
	if same >= Config.Rarities[def.Rarity].PlacementLimit then
		return false, "Лимит этого юнита"
	end
	return true
end

local function update()
	local cam = workspace.CurrentCamera
	local ray
	if touchPos then
		ray = cam:ScreenPointToRay(touchPos.X, touchPos.Y)
	else
		local screen = UserInputService:GetMouseLocation()
		ray = cam:ViewportPointToRay(screen.X, screen.Y)
	end
	local map = workspace:FindFirstChild("VoidTDMap")
	if not map then
		return
	end
	params.FilterDescendantsInstances = { map }
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 800, params)
	if not hit then
		valid = false
		return
	end
	local pos = hit.Position
	lastPos = pos
	valid, reason = check(hit, pos)
	local hip = ghost.HipHeight
	ghost.Root.CFrame = CF(pos + V(0, hip, 0)) * ANG(0, rad(rotation), 0)
	local color = valid and GOOD or BAD
	local range = Config.Units[unitId].Levels[1].Range
	circle.Size = V(0.15, range * 2, range * 2)
	circle.CFrame = CF(pos + V(0, 0.22, 0)) * ANG(0, 0, rad(90))
	circle.Color = color
	inner.CFrame = CF(pos + V(0, 0.25, 0)) * ANG(0, 0, rad(90))
	inner.Color = color
	for _, d in ipairs(ghost.Model:GetDescendants()) do
		if d:IsA("Highlight") then
			d.FillColor = color
			d.OutlineColor = color
		end
	end
end

function Placement.Start(id)
	if not id or not Config.Units[id] then
		return
	end
	Placement.Stop()
	local def = Config.Units[id]
	if (player:GetAttribute("Money") or 0) < def.Levels[1].Cost then
		UI.Toast("Недостаточно денег: нужно $" .. Config.FormatNumber(def.Levels[1].Cost), "error")
		return
	end
	local phase = ctx.State:GetAttribute("Phase")
	if phase == "Victory" or phase == "Defeat" or not player:GetAttribute("InMatch") then
		return
	end
	unitId = id
	ghost = UnitModels.Build(id, 1)
	for _, d in ipairs(ghost.Model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CanQuery = false
			d.CanTouch = false
			d.CastShadow = false
			if d.Transparency < 1 then
				d.Transparency = 0.35 + d.Transparency * 0.5
			end
		elseif d:IsA("ParticleEmitter") or d:IsA("PointLight") then
			d:Destroy()
		end
	end
	local hl = Instance.new("Highlight")
	hl.FillTransparency = 0.75
	hl.OutlineTransparency = 0.2
	hl.DepthMode = Enum.HighlightDepthMode.Occluded
	hl.Parent = ghost.Model
	ghost.Model.Parent = workspace
	circle = FX.Part({ Shape = Enum.PartType.Cylinder, Transparency = 0.72, Parent = workspace })
	circle.Name = "VoidTD_GhostRange"
	inner = FX.Part({ Shape = Enum.PartType.Cylinder, Size = V(0.2, 2.6, 2.6), Transparency = 0.3, Parent = workspace })
	Placement.Active = true
	rotation = rotation or 0
	touchPos = nil
	UI.CloseUnit()
	UI.ShowPlacementHint(true, isTouch())
	conn = RunService.RenderStepped:Connect(update)
	update()
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
	if inner then
		inner:Destroy()
		inner = nil
	end
	UI.ShowPlacementHint(false)
end

function Placement.Rotate()
	rotation = (rotation + 45) % 360
end

function Placement.Confirm()
	if not Placement.Active then
		return
	end
	update()
	if not valid then
		UI.Toast(reason ~= "" and reason or "Сюда ставить нельзя", "error")
		return
	end
	local id = unitId
	local ok = ctx.Request("Place", { Unit = id, Position = lastPos, Rotation = rotation })
	if ok then
		local keep = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
		local enough = (player:GetAttribute("Money") or 0) >= Config.Units[id].Levels[1].Cost
		if not (keep and enough) then
			Placement.Stop()
		end
	end
end

function Placement.SetTouch(pos)
	touchPos = pos
end

function Placement.Init(c)
	ctx = c
	Config, PathUtil, UnitModels, FX, UI, Renderer = c.Config, c.PathUtil, c.UnitModels, c.FX, c.UI, c.Renderer
end

return Placement
