--!nocheck
-- VOID TD :: Render/Allies — союзники-призывы на дороге (проклятые люди, марионетки, иллюзии).
-- Идут от базы к порталу навстречу врагам; HP = запас урона (считает сервер).
--
-- API (вызывается из Render/init)
--   Allies.Init(R, ctx)
--   Allies.Sync(list, removed)   list — плоский массив по 5: id, dist, hp, allyTypeIndex, maxHp; removed — {{id, reason}}
--   Allies.Update(t, dt) ; Allies.Clear()
--   Allies.Views  -- id -> { Id, AllyId, Family, Rig, Dist, ServerDist, HP, MaxHP, LastSync, Phase, Lateral, SpawnT, Fill, HitT }

local Allies = {}

local V = Vector3.new
local ANG = CFrame.Angles
local rad = math.rad
local rgb = Color3.fromRGB

local R, ctx, Config, Path, UnitModels, FX
local views = {}
Allies.Views = views
local rng = Random.new()

local RED = rgb(230, 30, 50)
local ORANGE = rgb(255, 140, 40)
local PURPLE = rgb(180, 90, 255)
local GOLD = rgb(255, 205, 80)

function Allies.Init(renderer, c)
	R, ctx = renderer, c
	Config, Path, UnitModels, FX = c.Config, c.Path, c.UnitModels, c.FX
end

local function familyColor(av, forDeath)
	if av.Family == "Cursed" then
		return RED
	elseif av.Family == "Puppet" then
		return (forDeath and av.AllyId == "GoldenMarionette") and GOLD or ORANGE
	end
	return PURPLE
end

-- полоска HP над головой
local function makeBar(av)
	local gui = Instance.new("BillboardGui")
	gui.Name = "HPBar"
	gui.Size = UDim2.fromOffset(60, 8)
	gui.StudsOffsetWorldSpace = V(0, av.Rig.Height or 5, 0)
	gui.MaxDistance = 90
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = rgb(20, 14, 24)
	bg.BorderSizePixel = 0
	bg.Parent = gui
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = familyColor(av, false)
	fill.BorderSizePixel = 0
	fill.Parent = bg
	gui.Parent = av.Rig.Root
	av.Fill = fill
end

local function place(av, dist, yOff)
	local rig = av.Rig
	local pos, dir = Path.OffsetPositionAt(math.max(dist, 0), av.Lateral)
	local up = V(0, rig.HipHeight + yOff, 0)
	-- смотрят назад по дороге (навстречу врагам)
	rig.Root.CFrame = CFrame.lookAt(pos + up, pos - dir + up)
end

local function add(id, dist, hp, typeIndex, maxHp)
	local allyId = Config.AllyOrder[typeIndex]
	if not allyId or not UnitModels.BuildAlly then
		return
	end
	local ok, rig = pcall(UnitModels.BuildAlly, allyId)
	if not ok or not rig then
		warn("[VOID TD] BuildAlly: " .. tostring(rig))
		return
	end
	local def = Config.Allies[allyId] or {}
	local now = os.clock()
	local av = {
		Id = id, AllyId = allyId, Family = def.Family, Rig = rig, Dist = dist, ServerDist = dist,
		HP = hp, MaxHP = maxHp or hp, LastSync = now, Phase = rng:NextNumber(0, 6),
		Lateral = rng:NextNumber(-1.4, 1.4), SpawnT = now,
	}
	rig.Height = rig.Height or (5 * (rig.Scale or 1))
	for _, d in ipairs(rig.Model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CanQuery = false
			d.CanTouch = false
			d.CanCollide = false
		end
	end
	place(av, dist, -2)
	makeBar(av)
	rig.Model.Parent = R.AllyFolder or workspace
	views[id] = av
end

local function remove(id, reason)
	local av = views[id]
	if not av then
		return
	end
	views[id] = nil
	local model = av.Rig.Model
	if model.Parent then
		local pos = av.Rig.Root.Position
		local color = familyColor(av, true)
		if reason == "dead" then
			FX.Burst(pos, color, 10, 0.35, 8)
			if av.Family == "Puppet" then
				FX.Debris(pos, rgb(150, 110, 70), 6, 0.4, 7, 0.8, Enum.Material.Wood)
			elseif av.Family == "Illusion" then
				FX.Debris(pos, rgb(220, 210, 255), 6, 0.35, 7, 0.8, Enum.Material.Glass)
			else
				FX.Smoke(pos, rgb(120, 20, 30), 3, 2, 0.8, 3)
			end
		else
			FX.Poof(pos, color, 1)
		end
	end
	model:Destroy()
end

function Allies.Sync(list, removed)
	if type(list) == "table" then
		local now = os.clock()
		local seen = {}
		for i = 1, #list, 5 do
			local id = list[i]
			seen[id] = true
			local av = views[id]
			if av then
				av.ServerDist = list[i + 1]
				av.HP = list[i + 2]
				av.MaxHP = list[i + 4] or av.MaxHP
				av.LastSync = now
			else
				add(id, list[i + 1], list[i + 2], list[i + 3], list[i + 4])
			end
		end
		-- пропавшие из списка без причины (переподключение, сброс)
		for id in pairs(views) do
			if not seen[id] then
				remove(id, "clear")
			end
		end
	end
	if type(removed) == "table" then
		for _, r in ipairs(removed) do
			remove(r[1], r[2])
		end
	end
end

function Allies.Clear()
	for id in pairs(views) do
		remove(id, "clear")
	end
end

function Allies.Update(t, dt)
	if next(views) == nil then
		return
	end
	local speed = Config.Settings.AllySpeed or 6
	local k = math.min(1, dt * 5)
	for _, av in pairs(views) do
		local rig = av.Rig
		-- предсказание: идут к порталу (dist уменьшается), догоняем сервер
		local predicted = av.ServerDist - speed * math.min(t - av.LastSync, 0.35)
		av.Dist = av.Dist - speed * dt
		av.Dist = av.Dist + (predicted - av.Dist) * k
		local rise = math.clamp((t - av.SpawnT) / 0.4, 0, 1)
		local bob = math.abs(math.sin(t * 7 + av.Phase)) * 0.15
		place(av, av.Dist, bob - (1 - rise) * 2)
		-- ходьба: руки и ноги навстречу
		local swing = math.sin(t * 7 + av.Phase) * 32
		local m, b = rig.Motors, rig.Base
		if m.RH and b.RH and m.LH and b.LH then
			m.RH.C0 = b.RH * ANG(rad(swing), 0, 0)
			m.LH.C0 = b.LH * ANG(rad(-swing), 0, 0)
		end
		if m.RS and b.RS and m.LS and b.LS then
			m.RS.C0 = b.RS * ANG(rad(-swing * 0.7), 0, 0)
			m.LS.C0 = b.LS * ANG(rad(swing * 0.7), 0, 0)
		end
		if av.Fill then
			av.Fill.Size = UDim2.fromScale(math.clamp(av.HP / math.max(av.MaxHP or 1, 1), 0, 1), 1)
		end
	end
end

return Allies
