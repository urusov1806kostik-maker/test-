--!nocheck
-- Окружение тестов VOID TD: база API Roblox (enum, классы), движок (сервисы, ремоуты, твины, запросы к миру),
-- рантайм скриптов (realm сервер/клиент, require ModuleScript, установка _bundle.luau в мок).
local M = require("./mock")
local X = M._ -- внутренности мока
local P, isa, is, cf, CF, V3, v3, v2, IDENT = X.P, X.isa, X.is, X.cf, X.CF, X.V3, X.v3, X.v2, X.IDENT
local Inst, num = M.Inst, X.num
local E = {}
M.dataStores = M.dataStores or {} -- переживает M.setup (сохранение профиля между «сессиями» одного процесса)

------------------------------------------------------------------ прочие datatypes
local RC = X.record("Rect", nil, { Width = function(r) return r.Max.X - r.Min.X end, Height = function(r) return r.Max.Y - r.Min.Y end })
M.Rect = { new = function(a, b, c, d) if is(a, X.V2mt) then return RC({ Min = a, Max = b }) end return RC({ Min = v2(num(a, "Rect"), num(b, "Rect")), Max = v2(num(c, "Rect"), num(d, "Rect")) }) end }
local PP = X.record("PhysicalProperties")
M.PhysicalProperties = { new = function(d, f, e, fw, ew) if type(d) ~= "number" then d = 0.7 end return PP({ Density = d, Friction = f or 0.3, Elasticity = e or 0.5, FrictionWeight = fw or 1, ElasticityWeight = ew or 1 }) end }
local RYm, RY = {}, nil
RY = X.record("Ray", RYm, { Unit = function(r) return RY({ Origin = r.Origin, Direction = r.Direction.Unit }) end })
function RYm.ClosestPoint(r, p) local d = r.Direction.Unit; return r.Origin + d * math.max(0, V3.Dot(p - r.Origin, d)) end
function RYm.Distance(r, p) return (RYm.ClosestPoint(r, p) - p).Magnitude end
M.Ray = { new = function(o, d) return RY({ Origin = X.vecArg(o, "Ray.new"), Direction = X.vecArg(d, "Ray.new") }) end }
local RR = X.record("RaycastResult")
local FT = X.record("Font")
M.Font = {
	new = function(fam, w, s) if type(fam) ~= "string" then error("Font.new: string expected", 2) end return FT({ Family = fam, Weight = w or M.Enum.FontWeight.Regular, Style = s or M.Enum.FontStyle.Normal, Bold = w == M.Enum.FontWeight.Bold }) end,
	fromEnum = function(e) return M.Font.new("rbxasset://fonts/families/" .. e.Name .. ".json") end,
	fromName = function(n, w, s) return M.Font.new("rbxasset://fonts/families/" .. n .. ".json", w, s) end,
	fromId = function(id, w, s) return M.Font.new("rbxassetid://" .. tostring(id), w, s) end,
}
local TI = X.record("TweenInfo")
M.TweenInfo = { new = function(t, st, dir, rep, rev, del)
	return TI({ Time = num(t or 1, "TweenInfo"), EasingStyle = st or M.Enum.EasingStyle.Quad, EasingDirection = dir or M.Enum.EasingDirection.Out, RepeatCount = rep or 0, Reverses = rev or false, DelayTime = del or 0 })
end }
local BRICK = { White = { 1, 242, 243, 243 }, Black = { 26, 27, 42, 53 }, ["Really black"] = { 1003, 17, 17, 17 }, ["Medium stone grey"] = { 194, 163, 162, 165 },
	["Dark stone grey"] = { 199, 99, 95, 98 }, ["Institutional white"] = { 1001, 248, 248, 248 }, ["Bright red"] = { 21, 196, 40, 28 }, ["Really red"] = { 1004, 255, 0, 0 },
	["Bright blue"] = { 23, 13, 105, 172 }, ["Bright green"] = { 37, 75, 151, 75 }, ["Bright yellow"] = { 24, 245, 205, 48 }, ["Bright orange"] = { 106, 218, 133, 65 } }
local BC = X.record("BrickColor")
local function brick(name) if not BRICK[name] then name = "Medium stone grey" end local e = BRICK[name]; return BC({ Name = name, Number = e[1], Color = X.C3.fromRGB(e[2], e[3], e[4]) }) end
M.BrickColor = { new = function(a, g, b)
	if type(a) == "string" then return brick(a) end
	if type(a) == "number" and not g then for n, e in pairs(BRICK) do if e[1] == a then return brick(n) end end return brick("") end
	local c = is(a, X.C3mt) and a or X.c3(a, g, b)
	local best, bd = "", math.huge
	for n, e in pairs(BRICK) do local d = (e[2] / 255 - c.R) ^ 2 + (e[3] / 255 - c.G) ^ 2 + (e[4] / 255 - c.B) ^ 2; if d < bd then best, bd = n, d end end
	return brick(best)
end, White = function() return brick("White") end, Black = function() return brick("Black") end, Gray = function() return brick("") end, Red = function() return brick("Bright red") end }
local DTmt = X.datatype("DateTime", { ToIsoDate = function(d) return os.date("!%Y-%m-%dT%H:%M:%SZ", d.UnixTimestamp) end,
	FormatUniversalTime = function(d) return os.date("!%Y-%m-%d %H:%M:%S", d.UnixTimestamp) end, FormatLocalTime = function(d) return os.date("!%Y-%m-%d %H:%M:%S", d.UnixTimestamp) end })
local function dtime(ms) return setmetatable({ UnixTimestampMillis = math.floor(ms), UnixTimestamp = math.floor(ms / 1000) }, DTmt) end
M.DateTime = { now = function() return dtime((M.epoch + M.now) * 1000) end, fromUnixTimestamp = function(s) return dtime(s * 1000) end, fromUnixTimestampMillis = dtime }
local function params(name, fields) -- изменяемые параметры запросов: неизвестное поле — ошибка, как в Roblox
	local mt = {}
	mt.__index = function(t, k)
		if k == "AddToFilter" then return function(self, x) local f = rawget(self, "_v").FilterDescendantsInstances; for _, i in ipairs(M.isInstance(x) and { x } or x) do table.insert(f, i) end end end
		if fields[k] == nil then error(tostring(k) .. " is not a valid member of " .. name, 2) end
		return rawget(t, "_v")[k]
	end
	mt.__newindex = function(t, k, v) if fields[k] == nil then error(tostring(k) .. " is not a valid member of " .. name, 2) end rawget(t, "_v")[k] = v end
	X.TYPENAME[mt] = name
	return { new = function() local v = {}; for k, d in pairs(fields) do v[k] = d end v.FilterDescendantsInstances, v.FilterType = {}, M.Enum.RaycastFilterType.Exclude; return setmetatable({ _v = v }, mt) end }
end
M.RaycastParams = params("RaycastParams", { FilterDescendantsInstances = 0, FilterType = 0, IgnoreWater = false, CollisionGroup = "Default", RespectCanCollide = false, BruteForceAllSlow = false })
M.OverlapParams = params("OverlapParams", { FilterDescendantsInstances = 0, FilterType = 0, MaxParts = 0, CollisionGroup = "Default", RespectCanCollide = false, BruteForceAllSlow = false })
local RNmt = X.datatype("Random", {
	NextNumber = function(r, a, b) local x = r._n(); if a == nil then return x end return a + (b - a) * x end,
	NextInteger = function(r, a, b) num(a, "NextInteger"); num(b, "NextInteger"); if b < a then error("NextInteger: max must be >= min", 2) end return a + math.floor(r._n() * (b - a + 1)) end,
	NextUnitVector = function(r) local z = r._n() * 2 - 1; local t = r._n() * math.pi * 2; local s = math.sqrt(1 - z * z); return v3(s * math.cos(t), s * math.sin(t), z) end,
	Shuffle = function(r, t) for i = #t, 2, -1 do local j = 1 + math.floor(r._n() * i); t[i], t[j] = t[j], t[i] end end,
	Clone = function(r) return M.Random.new(r._s()) end,
})
M.Random = { new = function(seed) -- MINSTD (Park–Miller): детерминированно
	local state = math.floor(seed or 12345) % 2147483646 + 1
	return setmetatable({ _n = function() state = (state * 48271) % 2147483647; return (state - 1) / 2147483646 end, _s = function() return state end }, RNmt)
end }

------------------------------------------------------------------ база API: допустимые значения Enum
local ENUMS = {
	Material = "Plastic=256 SmoothPlastic=272 Neon=288 Wood=512 WoodPlanks=528 Marble=784 Basalt=788 Slate=800 CrackedLava=804 Concrete=816 Limestone=820 Granite=832 Pavement=836 Brick=848 Pebble=864 Cobblestone=880 Rock=896 Sandstone=912 CorrodedMetal=1040 DiamondPlate=1056 Foil=1072 Metal=1088 Grass=1280 LeafyGrass=1284 Sand=1296 Fabric=1312 Snow=1328 Mud=1344 Ground=1360 Asphalt=1376 Salt=1392 Ice=1536 Glacier=1552 Glass=1568 ForceField=1584 Air=1792 Water=2048 Cardboard=2304 Carpet=2305 CeramicTiles=2306 ClayRoofTiles=2307 RoofShingles=2308 Leather=2309 Plaster=2310 Rubber=2311",
	PartType = "Ball Block Cylinder Wedge CornerWedge", MeshType = "Head Torso Wedge Prism Pyramid ParallelRamp RightAngleRamp CornerWedge Brick Sphere Cylinder FileMesh",
	EasingStyle = "Linear Sine Back Quad Quart Quint Bounce Elastic Exponential Circular Cubic", EasingDirection = "In Out InOut",
	Font = "Legacy Arial ArialBold SourceSans SourceSansBold SourceSansLight SourceSansItalic Bodoni Garamond Cartoon Code Highway SciFi Arcade Fantasy Antique SourceSansSemibold Gotham GothamMedium GothamBold GothamBlack GothamSemibold AmaticSC Bangers Creepster DenkOne Fondamento FredokaOne GrenzeGotisch IndieFlower JosefinSans Jura Kalam LuckiestGuy Merriweather Michroma Nunito Oswald PatrickHand PermanentMarker Roboto RobotoCondensed RobotoMono Sarpanch SpecialElite TitilliumWeb Ubuntu BuilderSans BuilderSansMedium BuilderSansBold BuilderSansExtraBold Arimo ArimoBold Unknown=100",
	FontWeight = "Thin=100 ExtraLight=200 Light=300 Regular=400 Medium=500 SemiBold=600 Bold=700 ExtraBold=800 Heavy=900", FontStyle = "Normal Italic",
	TextXAlignment = "Left Right Center", TextYAlignment = "Top Center Bottom", TextTruncate = "None AtEnd SplitWord", NormalId = "Right Top Back Left Bottom Front",
	SurfaceType = "Smooth Glue Weld Studs Inlet Universal Hinge Motor SteppingMotor SmoothNoOutlines=10", SortOrder = "Name Custom LayoutOrder", FillDirection = "Horizontal Vertical",
	HorizontalAlignment = "Center Left Right", VerticalAlignment = "Center Top Bottom", AutomaticSize = "None X Y XY", ApplyStrokeMode = "Contextual Border", LineJoinMode = "Round Bevel Miter",
	ScaleType = "Stretch Slice Tile Fit Crop", SizeConstraint = "RelativeXY RelativeXX RelativeYY", BorderMode = "Outline Middle Inset", ZIndexBehavior = "Global Sibling",
	AspectType = "FitWithinMaxSize ScaleWithParentSize", DominantAxis = "Width Height", ScrollingDirection = "X=1 Y XY=4", ElasticBehavior = "WhenScrollable Always Never",
	ScrollBarInset = "None ScrollBar Always", CameraType = "Fixed Attach Watch Track Follow Custom Scriptable Orbital", HighlightDepthMode = "AlwaysOnTop Occluded",
	ParticleOrientation = "FacingCamera FacingCameraWorldUp VelocityParallel VelocityPerpendicular", ParticleEmitterShape = "Box Sphere Cylinder Disc",
	ParticleEmitterShapeStyle = "Volume Surface", ParticleEmitterShapeInOut = "Outward Inward InAndOut", ParticleFlipbookLayout = "None Grid2x2 Grid4x4 Grid8x8 Custom",
	ParticleFlipbookMode = "Loop OneShot PingPong Random", TextureMode = "Stretch Wrap Static", RollOffMode = "Inverse Linear LinearSquare InverseTapered",
	UserInputType = "MouseButton1 MouseButton2 MouseButton3 MouseWheel MouseMovement Touch=7 Keyboard Focus Accelerometer Gyro Gamepad1 Gamepad2 Gamepad3 Gamepad4 Gamepad5 Gamepad6 Gamepad7 Gamepad8 TextInput InputMethod None",
	UserInputState = "Begin Change End Cancel None", RenderPriority = "First=0 Input=100 Camera=200 Character=300 Last=2000",
	Technology = "Legacy Voxel Compatibility ShadowMap Future Unified", HumanoidRigType = "R6 R15", ExplosionType = "NoCraters Craters", ResamplerMode = "Default Pixelated",
	RenderFidelity = "Automatic Precise Performance", CollisionFidelity = "Default Hull Box PreciseConvexDecomposition", FieldOfViewMode = "Vertical Diagonal MaxAxis",
	StartCorner = "TopLeft TopRight BottomLeft BottomRight", ProductPurchaseDecision = "NotProcessedYet PurchaseGranted", MouseBehavior = "Default LockCenter LockCurrentPosition",
	RaycastFilterType = "Blacklist Whitelist Exclude=0 Include=1", PlaybackState = "Begin Delayed Playing Paused Completed Cancelled",
	CoreGuiType = "PlayerList Health Backpack Chat All EmotesMenu SelfView Captures", SurfaceGuiSizingMode = "FixedSize PixelsPerStud", AnimationPriority = "Idle Movement Action Core=1000 Action2=2 Action3 Action4",
	HumanoidDisplayDistanceType = "Viewer Subject None", ModelLevelOfDetail = "Automatic StreamingMesh Disabled SLIM", ModelStreamingMode = "Default Atomic Persistent PersistentPerPlayer Nonatomic",
	RunContext = "Legacy Server Client Plugin", ScreenInsets = "None DeviceSafeInsets CoreUISafeInsets TopbarSafeInsets", InfoType = "Asset Product GamePass Subscription Bundle",
	Axis = "X Y Z",
}
do
	local keys = { "Unknown=0 Backspace=8 Tab=9 Clear=12 Return=13 Pause=19 Escape=27 Space=32 QuotedDouble=34 Hash Dollar Percent Ampersand Quote LeftParenthesis RightParenthesis Asterisk Plus Comma Minus Period Slash Zero One Two Three Four Five Six Seven Eight Nine Colon Semicolon LessThan Equals GreaterThan Question At LeftBracket=91 BackSlash RightBracket Caret Underscore Backquote" }
	for i = 0, 25 do keys[#keys + 1] = string.char(65 + i) .. "=" .. (97 + i) end
	keys[#keys + 1] = "LeftCurly=123 Pipe RightCurly Tilde Delete KeypadZero=256 KeypadOne KeypadTwo KeypadThree KeypadFour KeypadFive KeypadSix KeypadSeven KeypadEight KeypadNine KeypadPeriod KeypadDivide KeypadMultiply KeypadMinus KeypadPlus KeypadEnter KeypadEquals Up Down Right Left Insert Home End PageUp PageDown"
	for i = 1, 15 do keys[#keys + 1] = "F" .. i .. "=" .. (281 + i) end
	keys[#keys + 1] = "NumLock=300 CapsLock ScrollLock RightShift LeftShift RightControl LeftControl RightAlt LeftAlt RightMeta LeftMeta LeftSuper RightSuper ButtonX=1000 ButtonY ButtonA ButtonB ButtonR1 ButtonL1 ButtonR2 ButtonL2 ButtonR3 ButtonL3 ButtonStart ButtonSelect DPadLeft DPadRight DPadUp DPadDown Thumbstick1 Thumbstick2"
	ENUMS.KeyCode = table.concat(keys, " ")
end
M.defineEnums(ENUMS)

------------------------------------------------------------------ база API: классы (члены, типы, значения по умолчанию)
-- строка (несколько через " & "): [*абстрактный|!сервис]Имя[<Предок]| члены; член: Prop:тип[=умолч] (~ — только чтение для игры), @Событие, Метод()
-- типы: n i b s v3 v2 cf c3 u u2 cs ns nr rect font bc pp I(Instance) fn any E.<Enum>
local TEXT = "Font:E.Font=Legacy FontFace:font LineHeight:n=1 MaxVisibleGraphemes:i=-1 RichText:b ~TextBounds:v2 TextColor3:c3=27,42,53 TextDirection:E.TextDirection TextFits:b TextScaled:b TextSize:n=14 TextStrokeColor3:c3 TextStrokeTransparency:n=1 TextTransparency:n TextTruncate:E.TextTruncate=None TextWrapped:b TextWrap:b TextXAlignment:E.TextXAlignment=Center TextYAlignment:E.TextYAlignment=Center ~ContentText:s ~LocalizedText:s OpenTypeFeatures:s"
local IMAGE = "Image:s ImageColor3:c3=255,255,255 ImageRectOffset:v2 ImageRectSize:v2 ImageTransparency:n ~IsLoaded:b=true ResampleMode:E.ResamplerMode=Default ScaleType:E.ScaleType=Stretch SliceCenter:rect SliceScale:n=1 TileSize:u2=1,0,1,0"
local SCHEMA = [[
*Instance| Name:s ~ClassName:s Parent:I Archivable:b=true @AncestryChanged @AttributeChanged @ChildAdded @ChildRemoved @DescendantAdded @DescendantRemoving @Changed @Destroying ClearAllChildren() Clone() Destroy() FindFirstAncestor() FindFirstAncestorOfClass() FindFirstAncestorWhichIsA() FindFirstChild() FindFirstChildOfClass() FindFirstChildWhichIsA() FindFirstDescendant() GetAttribute() GetAttributeChangedSignal() GetAttributes() GetChildren() GetDescendants() GetFullName() GetPropertyChangedSignal() IsA() IsAncestorOf() IsDescendantOf() SetAttribute() WaitForChild() AddTag() RemoveTag() HasTag() GetTags() GetActor() GetDebugId()
*PVInstance<Instance| GetPivot() PivotTo()
*BasePart<PVInstance| Anchored:b CanCollide:b=true CanQuery:b=true CanTouch:b=true CastShadow:b=true CFrame:cf Position:v3 Orientation:v3 Rotation:v3 Size:v3=4,1,2 Color:c3=163,162,165 BrickColor:bc Material:E.Material=Plastic MaterialVariant:s Reflectance:n Transparency:n LocalTransparencyModifier:n Massless:b CollisionGroup:s=Default CustomPhysicalProperties:pp RootPriority:i TopSurface:E.SurfaceType=Smooth BottomSurface:E.SurfaceType=Smooth LeftSurface:E.SurfaceType=Smooth RightSurface:E.SurfaceType=Smooth FrontSurface:E.SurfaceType=Smooth BackSurface:E.SurfaceType=Smooth AssemblyLinearVelocity:v3 AssemblyAngularVelocity:v3 Velocity:v3 RotVelocity:v3 ~AssemblyMass:n ~AssemblyRootPart:I ~Mass:n PivotOffset:cf Locked:b ~ExtentsCFrame:cf ~ExtentsSize:v3 EnableFluidForces:b=true AudioCanCollide:b=true @Touched @TouchEnded GetMass() GetTouchingParts() GetConnectedParts() GetJoints() GetRootPart() GetNetworkOwner() SetNetworkOwner() SetNetworkOwnershipAuto() CanSetNetworkOwnership() ApplyImpulse() ApplyAngularImpulse() BreakJoints() GetVelocityAtPosition()
*FormFactorPart<BasePart| & Part<FormFactorPart| Shape:E.PartType=Block & WedgePart<FormFactorPart| & CornerWedgePart<BasePart| & TrussPart<BasePart| Style:E.Style
SpawnLocation<Part| AllowTeamChangeOnTouch:b Duration:n=10 Enabled:b=true Neutral:b=true TeamColor:bc & *TriangleMeshPart<BasePart| CollisionFidelity:E.CollisionFidelity=Default
MeshPart<TriangleMeshPart| MeshId:s TextureID:s DoubleSided:b RenderFidelity:E.RenderFidelity=Automatic ~MeshSize:v3 & *PartOperation<TriangleMeshPart| UsePartColor:b SmoothingAngle:n RenderFidelity:E.RenderFidelity=Automatic
UnionOperation<PartOperation|
Terrain<BasePart| WaterColor:c3 WaterReflectance:n=1 WaterTransparency:n=0.3 WaterWaveSize:n=0.15 WaterWaveSpeed:n=10 Decoration:b FillBlock() FillBall() Clear()
Model<PVInstance| PrimaryPart:I WorldPivot:cf LevelOfDetail:E.ModelLevelOfDetail ModelStreamingMode:E.ModelStreamingMode GetBoundingBox() GetExtentsSize() GetScale() ScaleTo() MoveTo() TranslateBy() GetPrimaryPartCFrame() SetPrimaryPartCFrame()
*WorldRoot<Model| Raycast() Blockcast() Spherecast() Shapecast() GetPartBoundsInBox() GetPartBoundsInRadius() GetPartsInPart() BulkMoveTo() & WorldModel<WorldRoot|
!Workspace<WorldRoot| CurrentCamera:I Gravity:n=196.2 StreamingEnabled:b FallenPartsDestroyHeight:n=-500 ~DistributedGameTime:n AirDensity:n=0.0012 GlobalWind:v3 ~Terrain:I SignalBehavior:E.SignalBehavior StreamingMinRadius:n=64 StreamingTargetRadius:n=1024 StreamingIntegrityMode:E.StreamingIntegrityMode TouchesUseCollisionGroups:b GetServerTimeNow() GetRealPhysicsFPS()
Camera<PVInstance| CFrame:cf Focus:cf FieldOfView:n=70 CameraType:E.CameraType=Custom CameraSubject:I ~ViewportSize:v2 NearPlaneZ:n=-0.1 HeadLocked:b=true HeadScale:n=1 DiagonalFieldOfView:n FieldOfViewMode:E.FieldOfViewMode=Vertical MaxAxisFieldOfView:n VRTiltAndRollEnabled:b ViewportPointToRay() ScreenPointToRay() WorldToViewportPoint() WorldToScreenPoint() GetPartsObscuringTarget() ZoomToExtents() GetRenderCFrame()
Folder<Instance| & Configuration<Instance| & *JointInstance<Instance| Part0:I Part1:I C0:cf C1:cf Enabled:b=true ~Active:b & Motor<JointInstance| CurrentAngle:n DesiredAngle:n MaxVelocity:n
Motor6D<Motor| Transform:cf ChildName:s ParentName:s & Weld<JointInstance| & ManualWeld<JointInstance| & Snap<JointInstance| & WeldConstraint<Instance| Part0:I Part1:I Enabled:b=true ~Active:b
NoCollisionConstraint<Instance| Part0:I Part1:I Enabled:b=true & *Constraint<Instance| Attachment0:I Attachment1:I Color:bc Enabled:b=true Visible:b ~Active:b
AlignPosition<Constraint| Position:v3 Responsiveness:n=10 MaxForce:n MaxVelocity:n Mode:E.PositionAlignmentMode RigidityEnabled:b ApplyAtCenterOfMass:b ReactionForceEnabled:b
AlignOrientation<Constraint| CFrame:cf Responsiveness:n=10 MaxTorque:n MaxAngularVelocity:n Mode:E.OrientationAlignmentMode RigidityEnabled:b PrimaryAxisOnly:b ReactionTorqueEnabled:b
RopeConstraint<Constraint| Length:n=5 Thickness:n=0.1 Restitution:n WinchEnabled:b & RodConstraint<Constraint| Length:n=5 Thickness:n=0.1 & BallSocketConstraint<Constraint| LimitsEnabled:b UpperAngle:n=45 TwistLimitsEnabled:b
HingeConstraint<Constraint| ActuatorType:E.ActuatorType AngularVelocity:n MotorMaxTorque:n LimitsEnabled:b
LinearVelocity<Constraint| VectorVelocity:v3 MaxForce:n VelocityConstraintMode:E.VelocityConstraintMode RelativeTo:E.ActuatorRelativeTo & AngularVelocity<Constraint| AngularVelocity:v3 MaxTorque:n RelativeTo:E.ActuatorRelativeTo
VectorForce<Constraint| Force:v3 RelativeTo:E.ActuatorRelativeTo ApplyAtCenterOfMass:b
Attachment<Instance| CFrame:cf Position:v3 Orientation:v3 Axis:v3 SecondaryAxis:v3 WorldCFrame:cf WorldPosition:v3 ~WorldOrientation:v3 ~WorldAxis:v3 ~WorldSecondaryAxis:v3 Visible:b
Bone<Attachment| Transform:cf ~TransformedCFrame:cf ~TransformedWorldCFrame:cf & *DataModelMesh<Instance| Offset:v3 Scale:v3=1,1,1 VertexColor:v3=1,1,1 & *FileMesh<DataModelMesh| MeshId:s TextureId:s
SpecialMesh<FileMesh| MeshType:E.MeshType=Head & *BevelMesh<DataModelMesh| & BlockMesh<BevelMesh| & CylinderMesh<BevelMesh| & *Light<Instance| Brightness:n=1 Color:c3=255,255,255 Enabled:b=true Shadows:b
PointLight<Light| Range:n=8 & SpotLight<Light| Range:n=16 Angle:n=90 Face:E.NormalId=Front & SurfaceLight<Light| Range:n=16 Angle:n=90 Face:E.NormalId=Front
ParticleEmitter<Instance| Acceleration:v3 Brightness:n=1 Color:cs=255,255,255 Drag:n EmissionDirection:E.NormalId=Top Enabled:b=true FlipbookFramerate:nr=1 FlipbookIncompatible:s FlipbookLayout:E.ParticleFlipbookLayout=None FlipbookMode:E.ParticleFlipbookMode=Loop FlipbookStartRandom:b Lifetime:nr=5,10 LightEmission:n LightInfluence:n=1 LockedToPart:b Orientation:E.ParticleOrientation=FacingCamera Rate:n=20 RotSpeed:nr=0 Rotation:nr=0 Shape:E.ParticleEmitterShape=Box ShapeInOut:E.ParticleEmitterShapeInOut=Outward ShapePartial:n=1 ShapeStyle:E.ParticleEmitterShapeStyle=Volume Size:ns=1 Speed:nr=5 SpreadAngle:v2 Squash:ns=0 Texture:s=rbxasset://textures/particles/sparkles_main.dds TimeScale:n=1 Transparency:ns=0 VelocityInheritance:n VelocitySpread:n WindAffectsDrag:b ZOffset:n Emit() Clear()
Beam<Instance| Attachment0:I Attachment1:I Brightness:n=1 Color:cs=255,255,255 CurveSize0:n CurveSize1:n Enabled:b=true FaceCamera:b LightEmission:n LightInfluence:n Segments:i=10 Texture:s TextureLength:n=1 TextureMode:E.TextureMode=Stretch TextureSpeed:n=1 Transparency:ns=0.5 Width0:n=1 Width1:n=1 ZOffset:n SetTextureOffset()
Trail<Instance| Attachment0:I Attachment1:I Brightness:n=1 Color:cs=255,255,255 Enabled:b=true FaceCamera:b Lifetime:n=2 LightEmission:n LightInfluence:n MaxLength:n MinLength:n=0.1 Texture:s TextureLength:n=1 TextureMode:E.TextureMode=Stretch Transparency:ns=0.5 WidthScale:ns=1 Clear()
Fire<Instance| Color:c3=236,139,70 SecondaryColor:c3=139,80,55 Enabled:b=true Heat:n=9 Size:n=5 TimeScale:n=1 & Smoke<Instance| Color:c3=255,255,255 Enabled:b=true Opacity:n=0.5 RiseVelocity:n=1 Size:n=1 TimeScale:n=1
Sparkles<Instance| SparkleColor:c3=144,25,255 Enabled:b=true TimeScale:n=1
Explosion<Instance| BlastPressure:n=500000 BlastRadius:n=4 DestroyJointRadiusPercent:n=1 ExplosionType:E.ExplosionType=Craters Position:v3 TimeScale:n=1 Visible:b=true @Hit
Highlight<Instance| Adornee:I DepthMode:E.HighlightDepthMode=AlwaysOnTop Enabled:b=true FillColor:c3=255,0,0 FillTransparency:n=0.5 OutlineColor:c3=255,255,255 OutlineTransparency:n
*GuiBase3d<Instance| Color3:c3=13,105,172 Transparency:n Visible:b=true & *PVAdornment<GuiBase3d| Adornee:I & SelectionBox<PVAdornment| LineThickness:n=0.15 SurfaceColor3:c3=13,105,172 SurfaceTransparency:n=1
*FaceInstance<Instance| Face:E.NormalId=Front & Decal<FaceInstance| Color3:c3=255,255,255 Texture:s Transparency:n ZIndex:i=1 & Texture<Decal| OffsetStudsU:n OffsetStudsV:n StudsPerTileU:n=2 StudsPerTileV:n=2
Sound<Instance| Looped:b PlaybackSpeed:n=1 Playing:b RollOffMaxDistance:n=10000 RollOffMinDistance:n=10 RollOffMode:E.RollOffMode=Inverse SoundGroup:I SoundId:s TimePosition:n ~TimeLength:n Volume:n=0.5 PlayOnRemove:b ~IsLoaded:b=true ~IsPlaying:b ~IsPaused:b @Ended @Played @Loaded @Paused @Resumed @Stopped Play() Stop() Pause() Resume()
SoundGroup<Instance| Volume:n=0.5 & *SoundEffect<Instance| Enabled:b=true Priority:i & EqualizerSoundEffect<SoundEffect| HighGain:n LowGain:n MidGain:n
ReverbSoundEffect<SoundEffect| DecayTime:n=1.5 Density:n=1 Diffusion:n=1 DryLevel:n WetLevel:n & PitchShiftSoundEffect<SoundEffect| Octave:n=1
Humanoid<Instance| WalkSpeed:n=16 JumpPower:n=50 JumpHeight:n=7.2 Health:n=100 MaxHealth:n=100 HipHeight:n=2 DisplayName:s DisplayDistanceType:E.HumanoidDisplayDistanceType=Viewer HealthDisplayType:E.HumanoidHealthDisplayType NameDisplayDistance:n=100 HealthDisplayDistance:n=100 AutoRotate:b=true PlatformStand:b Sit:b RigType:E.HumanoidRigType=R15 ~RootPart:I UseJumpPower:b=true ~MoveDirection:v3 ~FloorMaterial:E.Material RequiresNeck:b=true BreakJointsOnDeath:b=true AutomaticScalingEnabled:b=true EvaluateStateMachine:b=true WalkToPoint:v3 @Died @Running @Jumping @StateChanged @MoveToFinished @HealthChanged @Seated MoveTo() Move() ChangeState() GetState() SetStateEnabled() LoadAnimation() TakeDamage() GetPlayingAnimationTracks() UnequipTools()
Animator<Instance| LoadAnimation() GetPlayingAnimationTracks() & AnimationController<Instance| & Animation<Instance| AnimationId:s & RemoteEvent<Instance| @OnServerEvent @OnClientEvent FireServer() FireClient() FireAllClients()
UnreliableRemoteEvent<Instance| @OnServerEvent @OnClientEvent FireServer() FireClient() FireAllClients() & RemoteFunction<Instance| OnServerInvoke:fn OnClientInvoke:fn InvokeServer() InvokeClient()
BindableEvent<Instance| @Event Fire() & BindableFunction<Instance| OnInvoke:fn Invoke() & *ValueBase<Instance| & IntValue<ValueBase| Value:i & NumberValue<ValueBase| Value:n & StringValue<ValueBase| Value:s
BoolValue<ValueBase| Value:b & ObjectValue<ValueBase| Value:I & Vector3Value<ValueBase| Value:v3 & CFrameValue<ValueBase| Value:cf & Color3Value<ValueBase| Value:c3 & BrickColorValue<ValueBase| Value:bc
*LuaSourceContainer<Instance| & *BaseScript<LuaSourceContainer| Enabled:b=true Disabled:b RunContext:E.RunContext=Legacy LinkedSource:s & Script<BaseScript| ~Source:s & LocalScript<Script|
ModuleScript<LuaSourceContainer| ~Source:s LinkedSource:s
*Player<Instance| UserId:i DisplayName:s Character:I Team:I TeamColor:bc Neutral:b=true ~AccountAge:i ~MembershipType:E.MembershipType CameraMode:E.CameraMode CameraMaxZoomDistance:n=128 CameraMinZoomDistance:n=0.5 DevComputerMovementMode:E.DevComputerMovementMode DevTouchMovementMode:E.DevTouchMovementMode AutoJumpEnabled:b=true HealthDisplayDistance:n=100 NameDisplayDistance:n=100 RespawnLocation:I CanLoadCharacterAppearance:b=true GameplayPaused:b ReplicationFocus:I ~LocaleId:s=en-us @CharacterAdded @CharacterRemoving @CharacterAppearanceLoaded @Idled @Chatted Kick() LoadCharacter() GetMouse() GetNetworkPing() IsInGroup() GetRankInGroup() GetRoleInGroup() GetJoinData() HasAppearanceLoaded() ClearCharacterAppearance() RequestStreamAroundAsync() IsFriendsWith() DistanceFromCharacter()
*BasePlayerGui<Instance|
*PlayerGui<BasePlayerGui| ScreenOrientation:E.ScreenOrientation SelectionImageObject:I GetTopbarTransparency() & *PlayerScripts<Instance| & *Backpack<Instance|
*Mouse<Instance| ~Hit:cf ~Target:I TargetFilter:I ~X:n ~Y:n ~UnitRay:any ~ViewSizeX:n ~ViewSizeY:n Icon:s ~Origin:cf ~TargetSurface:E.NormalId @Button1Down @Button1Up @Button2Down @Button2Up @Move @WheelForward @WheelBackward @Idle
Team<Instance| TeamColor:bc AutoAssignable:b=true GetPlayers() & *GuiBase<Instance|
*GuiBase2d<GuiBase| ~AbsolutePosition:v2 ~AbsoluteSize:v2 ~AbsoluteRotation:n AutoLocalize:b=true RootLocalizationTable:I SelectionGroup:b SelectionBehaviorUp:E.SelectionBehavior SelectionBehaviorDown:E.SelectionBehavior SelectionBehaviorLeft:E.SelectionBehavior SelectionBehaviorRight:E.SelectionBehavior
*LayerCollector<GuiBase2d| Enabled:b=true ResetOnSpawn:b=true ZIndexBehavior:E.ZIndexBehavior=Sibling
ScreenGui<LayerCollector| DisplayOrder:i IgnoreGuiInset:b ScreenInsets:E.ScreenInsets=CoreUISafeInsets ClipToDeviceSafeArea:b=true SafeAreaCompatibility:E.SafeAreaCompatibility
BillboardGui<LayerCollector| Active:b Adornee:I AlwaysOnTop:b Brightness:n=1 ClipsDescendants:b ~CurrentDistance:n DistanceLowerLimit:n DistanceStep:n DistanceUpperLimit:n=-1 ExtentsOffset:v3 ExtentsOffsetWorldSpace:v3 LightInfluence:n MaxDistance:n=inf PlayerToHideFrom:I Size:u2 SizeOffset:v2 StudsOffset:v3 StudsOffsetWorldSpace:v3
*SurfaceGuiBase<LayerCollector| Active:b=true Adornee:I Face:E.NormalId=Front
SurfaceGui<SurfaceGuiBase| AlwaysOnTop:b Brightness:n=1 CanvasSize:v2=800,600 ClipsDescendants:b LightInfluence:n=1 PixelsPerStud:n=50 SizingMode:E.SurfaceGuiSizingMode=FixedSize ZOffset:n MaxDistance:n ToolPunchThroughDistance:n
*GuiObject<GuiBase2d| Active:b AnchorPoint:v2 AutomaticSize:E.AutomaticSize=None BackgroundColor3:c3=255,255,255 BackgroundTransparency:n BorderColor3:c3=27,42,53 BorderMode:E.BorderMode=Outline BorderSizePixel:i=1 ClipsDescendants:b Draggable:b Interactable:b=true LayoutOrder:i NextSelectionDown:I NextSelectionLeft:I NextSelectionRight:I NextSelectionUp:I Position:u2 Rotation:n Selectable:b SelectionImageObject:I SelectionOrder:i Size:u2 SizeConstraint:E.SizeConstraint=RelativeXY Transparency:n Visible:b=true ZIndex:i=1 ~GuiState:E.GuiState @InputBegan @InputChanged @InputEnded @MouseEnter @MouseLeave @MouseMoved @MouseWheelBackward @MouseWheelForward @SelectionGained @SelectionLost @TouchLongPress @TouchPan @TouchPinch @TouchRotate @TouchSwipe @TouchTap TweenPosition() TweenSize() TweenSizeAndPosition()
Frame<GuiObject| Style:E.FrameStyle & CanvasGroup<GuiObject| GroupColor3:c3=255,255,255 GroupTransparency:n
ScrollingFrame<GuiObject| ~AbsoluteCanvasSize:v2 ~AbsoluteWindowSize:v2 AutomaticCanvasSize:E.AutomaticSize=None BottomImage:s CanvasPosition:v2 CanvasSize:u2=0,0,2,0 ElasticBehavior:E.ElasticBehavior=WhenScrollable HorizontalScrollBarInset:E.ScrollBarInset=None MidImage:s ScrollBarImageColor3:c3=255,255,255 ScrollBarImageTransparency:n ScrollBarThickness:i=12 ScrollingDirection:E.ScrollingDirection=XY ScrollingEnabled:b=true TopImage:s VerticalScrollBarInset:E.ScrollBarInset=None VerticalScrollBarPosition:E.VerticalScrollBarPosition
ViewportFrame<GuiObject| Ambient:c3=200,200,200 CurrentCamera:I ImageColor3:c3=255,255,255 ImageTransparency:n LightColor:c3=140,140,140 LightDirection:v3=-1,-1,-1 & *GuiLabel<GuiObject|
TextLabel<GuiLabel| Text:s=Label $TEXT
ImageLabel<GuiLabel| $IMAGE
*GuiButton<GuiObject| AutoButtonColor:b=true Modal:b Selected:b Style:E.ButtonStyle @Activated @MouseButton1Click @MouseButton1Down @MouseButton1Up @MouseButton2Click @MouseButton2Down @MouseButton2Up
TextButton<GuiButton| Text:s=Button $TEXT
ImageButton<GuiButton| $IMAGE HoverImage:s PressedImage:s
TextBox<GuiObject| Text:s $TEXT ClearTextOnFocus:b=true MultiLine:b PlaceholderColor3:c3=178,178,178 PlaceholderText:s CursorPosition:i=1 SelectionStart:i=-1 ShowNativeInput:b=true TextEditable:b=true @FocusLost @Focused CaptureFocus() ReleaseFocus() IsFocused()
*UIBase<Instance| & *UIComponent<UIBase| & UICorner<UIComponent| CornerRadius:u=0,8
UIStroke<UIComponent| ApplyStrokeMode:E.ApplyStrokeMode=Contextual Color:c3 Enabled:b=true LineJoinMode:E.LineJoinMode=Round Thickness:n=1 Transparency:n
UIGradient<UIComponent| Color:cs=255,255,255 Enabled:b=true Offset:v2 Rotation:n Transparency:ns=0 & UIPadding<UIComponent| PaddingBottom:u PaddingLeft:u PaddingRight:u PaddingTop:u & UIScale<UIComponent| Scale:n=1
*UIConstraint<UIComponent|
UIAspectRatioConstraint<UIConstraint| AspectRatio:n=1 AspectType:E.AspectType=FitWithinMaxSize DominantAxis:E.DominantAxis=Width & UISizeConstraint<UIConstraint| MaxSize:v2=inf,inf MinSize:v2
UITextSizeConstraint<UIConstraint| MaxTextSize:i=100 MinTextSize:i=1 & *UILayout<UIComponent|
*UIGridStyleLayout<UILayout| ~AbsoluteContentSize:v2 FillDirection:E.FillDirection=Horizontal HorizontalAlignment:E.HorizontalAlignment=Left SortOrder:E.SortOrder=LayoutOrder VerticalAlignment:E.VerticalAlignment=Top ApplyLayout()
UIListLayout<UIGridStyleLayout| FillDirection:E.FillDirection=Vertical Padding:u Wraps:b HorizontalFlex:E.UIFlexAlignment VerticalFlex:E.UIFlexAlignment ItemLineAlignment:E.ItemLineAlignment
UIGridLayout<UIGridStyleLayout| CellPadding:u2=0,5,0,5 CellSize:u2=0,100,0,100 FillDirectionMaxCells:i StartCorner:E.StartCorner=TopLeft
UIFlexItem<UIComponent| FlexMode:E.UIFlexMode GrowRatio:n ShrinkRatio:n ItemLineAlignment:E.ItemLineAlignment & *PostEffect<Instance| Enabled:b=true & BloomEffect<PostEffect| Intensity:n=1 Size:n=24 Threshold:n=2
BlurEffect<PostEffect| Size:n=24 & ColorCorrectionEffect<PostEffect| Brightness:n Contrast:n Saturation:n TintColor:c3=255,255,255 & SunRaysEffect<PostEffect| Intensity:n=0.25 Spread:n=1
DepthOfFieldEffect<PostEffect| FarIntensity:n=0.75 FocusDistance:n=0.05 InFocusRadius:n=10 NearIntensity:n=0.75 & Atmosphere<Instance| Color:c3=199,170,107 Decay:c3=92,60,13 Density:n=0.395 Glare:n Haze:n Offset:n
Sky<Instance| CelestialBodiesShown:b=true MoonAngularSize:n=11 MoonTextureId:s SkyboxBk:s SkyboxDn:s SkyboxFt:s SkyboxLf:s SkyboxRt:s SkyboxUp:s StarCount:i=3000 SunAngularSize:n=21 SunTextureId:s SkyboxOrientation:v3
Clouds<Instance| Color:c3=255,255,255 Cover:n=0.5 Density:n=0.7 Enabled:b=true
ProximityPrompt<Instance| ActionText:s=Interact ObjectText:s Enabled:b=true HoldDuration:n KeyboardKeyCode:E.KeyCode=E MaxActivationDistance:n=10 RequiresLineOfSight:b=true Style:E.ProximityPromptStyle UIOffset:v2 @Triggered @TriggerEnded @PromptShown @PromptHidden
ClickDetector<Instance| MaxActivationDistance:n=32 CursorIcon:s @MouseClick @MouseHoverEnter @MouseHoverLeave @RightMouseClick & *TweenBase<Instance| ~PlaybackState:E.PlaybackState=Begin @Completed Play() Pause() Cancel()
*Tween<TweenBase| ~Instance:I ~TweenInfo:any & *DataStore<Instance| GetAsync() SetAsync() UpdateAsync() RemoveAsync() IncrementAsync()
*DataModel<Instance| ~PlaceId:i ~GameId:i ~JobId:s ~CreatorId:i ~PlaceVersion:i ~PrivateServerId:s ~PrivateServerOwnerId:i ~Workspace:I @Loaded @Close GetService() FindService() BindToClose() IsLoaded()
!Lighting<Instance| Ambient:c3=70,70,70 Brightness:n=2 ClockTime:n=14 ColorShift_Bottom:c3 ColorShift_Top:c3 EnvironmentDiffuseScale:n EnvironmentSpecularScale:n ExposureCompensation:n FogColor:c3=192,192,192 FogEnd:n=100000 FogStart:n GeographicLatitude:n=41.73 GlobalShadows:b=true OutdoorAmbient:c3=127,127,127 ShadowSoftness:n=0.2 Technology:E.Technology=ShadowMap TimeOfDay:s=14:00:00 GetMinutesAfterMidnight() SetMinutesAfterMidnight() GetSunDirection() GetMoonDirection()
!Players<Instance| LocalPlayer:I MaxPlayers:i=8 RespawnTime:n=5 CharacterAutoLoads:b=true PreferredPlayers:i BubbleChat:b ClassicChat:b @PlayerAdded @PlayerRemoving GetPlayers() GetPlayerByUserId() GetPlayerFromCharacter() GetUserIdFromNameAsync() GetNameFromUserIdAsync() GetUserThumbnailAsync()
!RunService<Instance| @Heartbeat @RenderStepped @Stepped @PreSimulation @PostSimulation @PreRender @PreAnimation IsStudio() IsServer() IsClient() IsRunning() IsRunMode() IsEdit() BindToRenderStep() UnbindFromRenderStep()
!TweenService<Instance| Create() GetValue()
!UserInputService<Instance| ~TouchEnabled:b ~MouseEnabled:b ~KeyboardEnabled:b ~GamepadEnabled:b ~AccelerometerEnabled:b ~GyroscopeEnabled:b ~VREnabled:b MouseBehavior:E.MouseBehavior=Default MouseDeltaSensitivity:n=1 MouseIconEnabled:b=true MouseIcon:s ModalEnabled:b ~OnScreenKeyboardVisible:b ~PreferredInput:E.PreferredInput @InputBegan @InputChanged @InputEnded @TouchStarted @TouchMoved @TouchEnded @TouchPinch @TouchTap @TouchTapInWorld @TouchSwipe @TouchPan @TouchRotate @TouchLongPress @JumpRequest @LastInputTypeChanged @WindowFocused @WindowFocusReleased @TextBoxFocused @TextBoxFocusReleased IsKeyDown() IsMouseButtonPressed() GetMouseLocation() GetMouseDelta() GetFocusedTextBox() GetLastInputType() GetKeysPressed() GetMouseButtonsPressed() GetStringForKeyCode()
!ContextActionService<Instance| BindAction() BindActionAtPriority() UnbindAction() UnbindAllActions() GetButton() SetTitle() SetImage() SetPosition()
!DataStoreService<Instance| GetDataStore() GetOrderedDataStore() GetGlobalDataStore() GetRequestBudgetForRequestType()
!GuiService<Instance| ~MenuIsOpen:b SelectedObject:I AutoSelectGuiEnabled:b=true GuiNavigationEnabled:b=true TouchControlsEnabled:b=true ~TopbarInset:rect ~PreferredTransparency:n=1 ~ReducedMotionEnabled:b @MenuOpened @MenuClosed GetGuiInset() IsTenFootInterface()
!MarketplaceService<Instance| ProcessReceipt:fn @PromptProductPurchaseFinished @PromptGamePassPurchaseFinished @PromptPurchaseFinished PromptProductPurchase() PromptGamePassPurchase() PromptPurchase() UserOwnsGamePassAsync() GetProductInfo() PlayerOwnsAsset()
!SoundService<Instance| AmbientReverb:E.ReverbType DistanceFactor:n=3.33 DopplerScale:n=1 RolloffScale:n=1 RespectFilteringEnabled:b=true PlayLocalSound()
!StarterPlayer<Instance| CameraMaxZoomDistance:n=128 CameraMinZoomDistance:n=0.5 CameraMode:E.CameraMode CharacterWalkSpeed:n=16 CharacterJumpPower:n=50 CharacterJumpHeight:n=7.2 CharacterUseJumpPower:b DevComputerMovementMode:E.DevComputerMovementMode DevTouchMovementMode:E.DevTouchMovementMode AutoJumpEnabled:b=true EnableMouseLockOption:b=true HealthDisplayDistance:n=100 NameDisplayDistance:n=100 LoadCharacterAppearance:b=true UserEmotesEnabled:b=true
*StarterPlayerScripts<Instance| & *StarterCharacterScripts<StarterPlayerScripts| & !ReplicatedStorage<Instance| & !ReplicatedFirst<Instance| RemoveDefaultLoadingScreen() IsFinishedReplicating()
!ServerScriptService<Instance| LoadStringEnabled:b & !ServerStorage<Instance|
!StarterGui<BasePlayerGui| ShowDevelopmentGui:b=true ResetPlayerGuiOnSpawn:b=true ScreenOrientation:E.ScreenOrientation SetCoreGuiEnabled() GetCoreGuiEnabled() SetCore() GetCore() & !StarterPack<Instance|
!Teams<Instance| GetTeams() & !Debris<Instance| MaxItems:i=1000 AddItem()
!CollectionService<Instance| AddTag() RemoveTag() HasTag() GetTagged() GetTags() GetAllTags() GetInstanceAddedSignal() GetInstanceRemovedSignal()
!HttpService<Instance| HttpEnabled:b JSONEncode() JSONDecode() GenerateGUID() UrlEncode() & !ContentProvider<Instance| ~RequestQueueSize:i PreloadAsync() & !TextService<Instance| GetTextSize() GetTextBoundsAsync()
!TeleportService<Instance| Teleport() TeleportAsync() GetLocalPlayerTeleportData() & !BadgeService<Instance| AwardBadge() UserHasBadgeAsync()
!PhysicsService<Instance| RegisterCollisionGroup() CollisionGroupSetCollidable() CollisionGroupsAreCollidable() IsCollisionGroupRegistered() & !LocalizationService<Instance| ~RobloxLocaleId:s=en-us ~SystemLocaleId:s=en-us
!PolicyService<Instance| GetPolicyInfoForPlayerAsync() & !SocialService<Instance| & !HapticService<Instance| IsVibrationSupported() SetMotor()
!ProximityPromptService<Instance| Enabled:b=true MaxPromptsVisible:i=16 @PromptTriggered & !Chat<Instance| & !TextChatService<Instance| & !LogService<Instance| @MessageOut & !Stats<Instance|
!AnalyticsService<Instance| LogEconomyEvent() LogCustomEvent()
]]
-- раскладка GUI (грубо: Scale/Offset/AnchorPoint без UIListLayout) — производные свойства
local function viewport() local cam = M.workspace and P(M.workspace).CurrentCamera; return cam and P(cam).ViewportSize or v2(1280, 720) end
M.viewport = viewport
local function absSize(o)
	local p = P(o)
	if isa(o, "ScreenGui") then local vs = viewport(); return p.IgnoreGuiInset and vs or v2(vs.X, vs.Y - 36) end
	if isa(o, "BillboardGui") then local s = p.Size or X.U2zero; return v2(s.X.Offset, s.Y.Offset) end
	if isa(o, "SurfaceGui") then return p.CanvasSize or v2(800, 600) end
	if not isa(o, "GuiObject") then return X.V2.zero end
	local par = p.Parent
	local ps = par and isa(par, "GuiBase2d") and absSize(par) or viewport()
	local s = p.Size or X.U2zero
	return v2(ps.X * s.X.Scale + s.X.Offset, ps.Y * s.Y.Scale + s.Y.Offset)
end
local function absPos(o)
	local p = P(o)
	if not isa(o, "GuiObject") then return X.V2.zero end
	local par = p.Parent
	local pp = par and isa(par, "GuiObject") and absPos(par) or X.V2.zero
	local ps = par and isa(par, "GuiBase2d") and absSize(par) or viewport()
	local pos, me, ap = p.Position or X.U2zero, absSize(o), p.AnchorPoint or X.V2.zero
	return v2(pp.X + ps.X * pos.X.Scale + pos.X.Offset - ap.X * me.X, pp.Y + ps.Y * pos.Y.Scale + pos.Y.Offset - ap.Y * me.Y)
end
M.accessor("GuiBase2d.AbsoluteSize", absSize)
M.accessor("GuiBase2d.AbsolutePosition", absPos)
M.accessor("ScrollingFrame.AbsoluteWindowSize", absSize)
for _, cn in ipairs({ "TextLabel", "TextButton", "TextBox" }) do
	M.accessor(cn .. ".TextBounds", function(_, p) local t = tostring(p.Text or ""); local s = p.TextSize or 14; return v2((utf8.len(t) or #t) * s * 0.5, s) end)
	M.accessor(cn .. ".ContentText", function(_, p) local t = tostring(p.Text or ""); return p.RichText and (t:gsub("<[^>]->", "")) or t end)
end
M.defineClasses((SCHEMA:gsub("%$TEXT", TEXT):gsub("%$IMAGE", IMAGE)))

------------------------------------------------------------------ геометрия: пивоты, масштаб, габариты
local function partPivot(p) local props = P(p); local off = props.PivotOffset; return off and props.CFrame * off or props.CFrame end
local function extents(c, s) -- полуразмеры повернутого бокса по осям системы
	local r, hx, hy, hz = c._r, s.X / 2, s.Y / 2, s.Z / 2
	return math.abs(r[1]) * hx + math.abs(r[2]) * hy + math.abs(r[3]) * hz, math.abs(r[4]) * hx + math.abs(r[5]) * hy + math.abs(r[6]) * hz, math.abs(r[7]) * hx + math.abs(r[8]) * hy + math.abs(r[9]) * hz
end
local function eachPart(root, fn) -- все BasePart-потомки (без списка)
	local function rec(o) for _, c in ipairs(rawget(o, "_children")) do if rawget(c, "_isPart") then fn(c) end rec(c) end end
	rec(root)
end
local function box(model, frame) -- габариты частей в системе frame: центр (в frame), размер
	local inv = CF.Inverse(frame)
	local x0, y0, z0, x1, y1, z1 = math.huge, math.huge, math.huge, -math.huge, -math.huge, -math.huge
	eachPart(model, function(d)
		local c = inv * P(d).CFrame
		local ex, ey, ez = extents(c, P(d).Size)
		x0, y0, z0 = math.min(x0, c.p.X - ex), math.min(y0, c.p.Y - ey), math.min(z0, c.p.Z - ez)
		x1, y1, z1 = math.max(x1, c.p.X + ex), math.max(y1, c.p.Y + ey), math.max(z1, c.p.Z + ez)
	end)
	if x0 > x1 then return V3.zero, V3.zero end
	return v3((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), v3(x1 - x0, y1 - y0, z1 - z0)
end
M.box, M.eachPart = box, eachPart
function Inst.GetPivot(self)
	local props = P(self)
	if rawget(self, "_isPart") then return partPivot(self) end
	if props.PrimaryPart then return partPivot(props.PrimaryPart) end
	if props.WorldPivot then return props.WorldPivot end
	if isa(self, "Model") then local c = box(self, IDENT); return CF.new(c) end -- новая модель: центр габаритов (пока WorldPivot не задан)
	return props.CFrame or IDENT
end
function Inst.PivotTo(self, target)
	X.cfArg(target, "PivotTo")
	if rawget(self, "_isPart") then local off = P(self).PivotOffset; self.CFrame = off and target * CF.Inverse(off) or target return end
	local delta = target * CF.Inverse(Inst.GetPivot(self))
	eachPart(self, function(d) P(d).CFrame = delta * P(d).CFrame end)
	if isa(self, "Model") and not P(self).PrimaryPart then P(self).WorldPivot = target end
	if isa(self, "Camera") then P(self).CFrame = target end
end
function Inst.GetBoundingBox(self) local frame = Inst.GetPivot(self).Rotation; local c, s = box(self, frame); return frame * CF.new(c), s end
function Inst.GetExtentsSize(self) local _, s = Inst.GetBoundingBox(self); return s end
function Inst.GetScale(self) return rawget(self, "_scale") or 1 end
function Inst.ScaleTo(self, s)
	if type(s) ~= "number" or s <= 0 then error("ScaleTo: positive number expected", 2) end
	local f = s / (rawget(self, "_scale") or 1) -- масштаб абсолютный (от исходного), как в Roblox
	rawset(self, "_scale", s)
	if f == 1 then return end
	local pivot = Inst.GetPivot(self)
	local inv = CF.Inverse(pivot)
	local function sc(c) return cf(c.p.X * f, c.p.Y * f, c.p.Z * f, c._r) end
	for _, d in ipairs(Inst.GetDescendants(self)) do
		local p = P(d)
		if rawget(d, "_isPart") then p.Size = p.Size * f; p.CFrame = pivot * sc(inv * p.CFrame)
		elseif isa(d, "JointInstance") then p.C0 = p.C0 and sc(p.C0); p.C1 = p.C1 and sc(p.C1)
		elseif isa(d, "Attachment") then p.CFrame = p.CFrame and sc(p.CFrame)
		elseif isa(d, "DataModelMesh") then
			p.Offset = p.Offset and p.Offset * f
			if p.MeshType and p.MeshType.Name == "FileMesh" then p.Scale = (p.Scale or V3.one) * f end
		end
	end
	if P(self).WorldPivot then P(self).WorldPivot = pivot end
end
function Inst.TranslateBy(self, v) Inst.PivotTo(self, Inst.GetPivot(self) + v) end
function Inst.GetPrimaryPartCFrame(self) local pp = P(self).PrimaryPart; return pp and P(pp).CFrame end
function Inst.SetPrimaryPartCFrame(self, c) if not P(self).PrimaryPart then error("Model has no PrimaryPart", 2) end Inst.PivotTo(self, c) end
------------------------------------------------------------------ сервисы и движок
local function realmAt(level) return X.realmOf(getfenv(level + 1)) end
local function onlyOn(realm, what) local r = realmAt(3); if r and r ~= realm then M.problem(what .. " can only be called on the " .. realm) end end
local SERVICES = { "Workspace", "ReplicatedStorage", "ServerScriptService", "ServerStorage", "ReplicatedFirst", "Lighting", "Players", "RunService", "TweenService", "UserInputService",
	"DataStoreService", "GuiService", "MarketplaceService", "SoundService", "StarterPlayer", "StarterGui", "StarterPack", "Debris", "CollectionService", "HttpService", "ContextActionService", "TextService", "Teams" }
local function svc(name) local s = X.create(name); P(s).Name = name; s.Parent = M.game; M.services[name] = s; return s end
local function mk(class, name, parent) local o = X.create(class); P(o).Name = name; o.Parent = parent; return o end
function M.setup()
	M.clearQueue()
	M.now, M.tweens, M.renderSteps, M.players, M.keysDown, M.mouse = 0, {}, {}, {}, {}, v2(500, 300)
	M.problems, M.errors, M.closeHandlers, M.purchases, M.actions = {}, {}, {}, {}, {}
	M.game = X.create("DataModel")
	P(M.game).Name = "Game"
	M.services = {}
	for _, n in ipairs(SERVICES) do svc(n) end
	local ws = M.services.Workspace
	M.workspace = ws
	local cam = mk("Camera", "Camera", ws)
	P(cam).ViewportSize = v2(1280, 720)
	local terrain = X.create("Terrain")
	rawset(terrain, "_isPart", nil) -- пустой воксельный ландшафт: в запросах к миру не участвует
	M.partCount -= 1
	P(terrain).Name = "Terrain"
	terrain.Parent = ws
	P(ws).CurrentCamera, P(ws).Terrain, P(M.game).Workspace = cam, terrain, ws
	for _, n in ipairs({ "StarterPlayerScripts", "StarterCharacterScripts" }) do mk(n, n, M.services.StarterPlayer) end
	local uis = P(M.services.UserInputService)
	uis.TouchEnabled, uis.MouseEnabled, uis.KeyboardEnabled = false, true, true
	return M.game
end
function Inst.GetService(_, name)
	local s = M.services[name]
	if s then return s end
	local c = M.CLASS[name]
	if c and c.service then return svc(name) end
	error("'" .. tostring(name) .. "' is not a valid Service name", 2)
end
function Inst.FindService(_, name) return M.services[name] end
function Inst.BindToClose(_, fn) table.insert(M.closeHandlers, fn) end
-- игроки
local function localPlayer() return P(M.services.Players).LocalPlayer or M.players[1] end
function M.newPlayer(name, id)
	local p = X.create("Player")
	local pp = P(p)
	pp.Name, pp.DisplayName, pp.UserId = name, name, id
	mk("PlayerGui", "PlayerGui", p)
	mk("Backpack", "Backpack", p)
	p.Parent = M.services.Players
	table.insert(M.players, p)
	local s = P(M.services.Players).PlayerAdded
	if s then X.fireSignal(s, p) end
	return p
end
function M.removePlayer(p)
	local s = P(M.services.Players).PlayerRemoving
	if s then X.fireSignal(s, p) end
	for i, q in ipairs(M.players) do if q == p then table.remove(M.players, i) break end end
	if P(p).Character then Inst.Destroy(P(p).Character) end
	Inst.Destroy(p)
end
function M.spawnCharacter(p, at)
	local old = P(p).Character
	if old then local s = P(p).CharacterRemoving; if s then X.fireSignal(s, old) end Inst.Destroy(old) end
	local m = X.create("Model")
	P(m).Name = P(p).Name
	local hrp = mk("Part", "HumanoidRootPart", m)
	P(hrp).Size, P(hrp).Transparency = v3(2, 2, 1), 1
	local head = mk("Part", "Head", m)
	P(head).Size, P(head).CFrame = v3(2, 1, 1), CF.new(0, 1.5, 0)
	mk("Humanoid", "Humanoid", m)
	P(m).PrimaryPart = hrp
	m.Parent = M.workspace
	Inst.PivotTo(m, at or CF.new(0, 5, 0))
	p.Character = m
	local s = P(p).CharacterAdded
	if s then X.fireSignal(s, m) end
	return m
end
function Inst.GetPlayers(self)
	if isa(self, "Team") then local o = {}; for _, p in ipairs(M.players) do if P(p).Team == self then o[#o + 1] = p end end return o end
	return table.clone(M.players)
end
function Inst.GetPlayerByUserId(_, id) for _, p in ipairs(M.players) do if P(p).UserId == id then return p end end return nil end
function Inst.GetPlayerFromCharacter(_, ch) for _, p in ipairs(M.players) do if ch ~= nil and P(p).Character == ch then return p end end return nil end
function Inst.Kick(p) M.removePlayer(p) end
function Inst.LoadCharacter(p) onlyOn("server", "LoadCharacter"); M.spawnCharacter(p) end
function Inst.GetMouse(p) local m = rawget(p, "_mouse") or X.create("Mouse"); rawset(p, "_mouse", m); P(m).X, P(m).Y = M.mouse.X, M.mouse.Y; return m end
for n, v in pairs({ GetNetworkPing = 0.05, IsInGroup = false, GetRankInGroup = 0, HasAppearanceLoaded = true, IsRunning = true, IsRunMode = true, IsEdit = false, IsLoaded = true }) do Inst[n] = function() return v end end
function Inst.GetJoinData() return {} end
function Inst.DistanceFromCharacter(p, pos) local ch = P(p).Character; local r = ch and Inst.FindFirstChild(ch, "HumanoidRootPart"); return r and (P(r).CFrame.p - pos).Magnitude or 0 end
-- RunService и шаг кадра
function Inst.IsStudio() return M.isStudio end
function Inst.IsServer() return realmAt(2) ~= "client" end
function Inst.IsClient() return realmAt(2) == "client" end
function Inst.BindToRenderStep(_, name, prio, fn) onlyOn("client", "BindToRenderStep"); M.renderSteps[name] = { prio = num(prio, "BindToRenderStep"), fn = fn, name = name } end
function Inst.UnbindFromRenderStep(_, name) M.renderSteps[name] = nil end
local stepTweens
function M.step(dt)
	dt = dt or 1 / 60
	M.now += dt
	M.runDue()
	stepTweens(dt)
	local rs = P(M.services.RunService)
	local list = {}
	for _, b in pairs(M.renderSteps) do list[#list + 1] = b end
	table.sort(list, function(a, b) if a.prio ~= b.prio then return a.prio < b.prio end return a.name < b.name end)
	for _, b in ipairs(list) do X.runHandler(b.fn, dt) end
	for _, ev in ipairs({ "RenderStepped", "PreRender", "PreAnimation", "Stepped", "PreSimulation", "PostSimulation", "Heartbeat" }) do
		local s = rs[ev]
		if s then if ev == "Stepped" then X.fireSignal(s, M.now, dt) else X.fireSignal(s, dt) end end
	end
end
function M.run(sec, dt) dt = dt or 1 / 30; for _ = 1, math.max(1, math.floor(sec / dt + 0.5)) do M.step(dt) end end
-- ремоуты: копирование аргументов по правилам Roblox (функции нельзя, метатаблицы теряются, смешанные таблицы режутся)
local function wireCopy(v, seen)
	local t = type(v)
	if t == "function" or t == "thread" then M.problem("remote/bindable: cannot pass a " .. t); return nil end
	if t ~= "table" or M.isInstance(v) or X.TYPENAME[getmetatable(v)] then return v end
	if getmetatable(v) ~= nil then M.problem("remote/bindable: table with a metatable (metatable is lost)") end
	if seen[v] then M.problem("remote/bindable: cyclic table"); return nil end
	seen[v] = true
	local n, cnt, other = #v, 0, false
	for k in pairs(v) do cnt += 1; if not (type(k) == "number" and k % 1 == 0 and k >= 1 and k <= n) then other = true end end
	local out = {}
	if n > 0 and other then
		M.problem("remote/bindable: mixed or sparse table (non-array keys are lost)")
		for i = 1, n do out[i] = wireCopy(v[i], seen) end
	elseif n > 0 then
		for i = 1, n do out[i] = wireCopy(v[i], seen) end
	else
		for k, x in pairs(v) do
			if type(k) ~= "string" then M.problem("remote/bindable: dictionary key " .. tostring(k) .. " (" .. type(k) .. ") becomes a string"); k = tostring(k) end
			out[k] = wireCopy(x, seen)
		end
	end
	seen[v] = nil
	return out
end
local function wire(...) local n, t, seen = select("#", ...), { ... }, {}; for i = 1, n do t[i] = wireCopy(t[i], seen) end return t, n end
-- аргументы копируются при отправке; обработчики — в следующем кадре (сеть асинхронна); пока никто не подключён — очередь
local function deliver(remote, ev, pre, ...)
	local a, n = wire(...)
	local s = remote[ev]
	local function fire() if pre then X.fireSignal(s, pre, table.unpack(a, 1, n)) else X.fireSignal(s, table.unpack(a, 1, n)) end end
	if #s.handlers == 0 then s.pending = s.pending or {}; table.insert(s.pending, fire) return end
	X.schedule(M.now, coroutine.create(fire))
end
function Inst.FireServer(self, ...) onlyOn("client", "FireServer"); deliver(self, "OnServerEvent", localPlayer(), ...) end
-- клиент в тесте один: LocalPlayer, а до E.startClient — первый игрок
local function isClient(pl) local lp = P(M.services.Players).LocalPlayer; if lp then return pl == lp end return pl == M.players[1] end
function Inst.FireClient(self, player, ...)
	onlyOn("server", "FireClient")
	if not (M.isInstance(player) and isa(player, "Player")) then error("FireClient: player argument must be a Player object", 2) end
	M.log(P(self).Name, ...)
	if isClient(player) then deliver(self, "OnClientEvent", nil, ...) end
end
function Inst.FireAllClients(self, ...) onlyOn("server", "FireAllClients"); M.log(P(self).Name, ...); if #M.players > 0 then deliver(self, "OnClientEvent", nil, ...) end end
local function invoke(cb, ...) -- обработчик в своём потоке; вызывающий ждёт (может уступать), ошибка — вызывающему, как в Roblox
	local caller, res, err, waiting = coroutine.running(), nil, nil, false
	local co = coroutine.create(function(...)
		local r = table.pack(pcall(cb, ...))
		if r[1] then res = table.pack(table.unpack(r, 2, r.n)) else err = r[2] end
		if waiting then M.resumeThread(caller) end
	end)
	M.resumeThread(co, ...)
	if not res and not err then
		if caller == M.mainThread then error("remote invoke: the handler yielded in the main thread", 3) end
		waiting = true
		coroutine.yield()
	end
	if err then error(err, 0) end
	local out, n = wire(table.unpack(res, 1, res.n))
	return table.unpack(out, 1, n)
end
function Inst.InvokeServer(self, ...)
	onlyOn("client", "InvokeServer")
	local cb = P(self).OnServerInvoke
	if not cb then error("InvokeServer: OnServerInvoke is not set (" .. Inst.GetFullName(self) .. ")", 2) end
	local a, n = wire(...)
	return invoke(cb, localPlayer(), table.unpack(a, 1, n))
end
function Inst.InvokeClient(self, player, ...)
	onlyOn("server", "InvokeClient")
	local cb = P(self).OnClientInvoke
	if not cb then error("InvokeClient: OnClientInvoke is not set", 2) end
	local a, n = wire(...)
	return invoke(cb, table.unpack(a, 1, n))
end
function Inst.Fire(self, ...) local s = P(self).Event; if s then local a, n = wire(...); X.fireSignal(s, table.unpack(a, 1, n)) end end
function Inst.Invoke(self, ...) local cb = P(self).OnInvoke; if not cb then error("Invoke: OnInvoke is not set", 2) end local a, n = wire(...); return invoke(cb, table.unpack(a, 1, n)) end
-- TweenService: настоящая интерполяция по M.step, Completed срабатывает
local EASE = { Linear = function(t) return t end, Sine = function(t) return 1 - math.cos(t * math.pi / 2) end, Quad = function(t) return t * t end,
	Cubic = function(t) return t ^ 3 end, Quart = function(t) return t ^ 4 end, Quint = function(t) return t ^ 5 end, Exponential = function(t) return t == 0 and 0 or 2 ^ (10 * t - 10) end,
	Circular = function(t) return 1 - math.sqrt(1 - t * t) end, Back = function(t) return 2.70158 * t ^ 3 - 1.70158 * t * t end }
local function ease(style, dir, t)
	local f = EASE[style and style.Name] or EASE.Quad
	local d = dir and dir.Name or "Out"
	if d == "In" then return f(t) elseif d == "Out" then return 1 - f(1 - t) end
	return t < 0.5 and f(2 * t) / 2 or 1 - f(2 - 2 * t) / 2
end
local TWEENABLE = { number = 1, boolean = 1, Vector3 = 1, Vector2 = 1, CFrame = 1, Color3 = 1, UDim2 = 1, UDim = 1 }
local function lerp(a, b, t)
	local ty = M.typeof(a)
	if ty == "number" then return a + (b - a) * t end
	if ty == "UDim" then return X.ud(a.Scale + (b.Scale - a.Scale) * t, a.Offset + (b.Offset - a.Offset) * t) end
	if TWEENABLE[ty] and ty ~= "boolean" and M.typeof(b) == ty then return a:Lerp(b, t) end
	return t >= 1 and b or a
end
function Inst.Create(_, obj, info, goal)
	if not M.isInstance(obj) then error("TweenService:Create: Instance expected", 2) end
	if M.typeof(info) ~= "TweenInfo" then error("TweenService:Create: TweenInfo expected, got " .. M.typeof(info), 2) end
	local cls = rawget(obj, "_cls")
	for k, v in pairs(goal) do
		local m = cls and cls.members[k]
		if cls and not (m and m.kind == "prop") then M.problem("TweenService:Create: " .. tostring(k) .. " is not a property of " .. cls.name)
		elseif not TWEENABLE[M.typeof(v)] then M.problem("TweenService:Create: property " .. k .. " cannot be tweened (" .. M.typeof(v) .. ")") end
	end
	local tw = X.create("Tween")
	P(tw).Instance, P(tw).TweenInfo, P(tw).PlaybackState = obj, info, M.Enum.PlaybackState.Begin
	rawset(tw, "_goal", goal)
	return tw
end
function Inst.GetValue(_, a, style, dir) return ease(style, dir, a) end
local function stopTween(tw, state)
	rawset(tw, "_active", false)
	P(tw).PlaybackState = M.Enum.PlaybackState[state]
	local c = P(tw).Completed
	if c then X.fireSignal(c, P(tw).PlaybackState) end
end
function Inst.Play(self)
	if isa(self, "Sound") then P(self).Playing = true; local s = P(self).Played; if s then X.fireSignal(s, P(self).SoundId) end return end
	if not isa(self, "Tween") then return end
	local obj, goal = P(self).Instance, rawget(self, "_goal")
	for _, o in ipairs(M.tweens) do -- новый твин тех же свойств отменяет старый
		if o ~= self and rawget(o, "_active") and P(o).Instance == obj then for k in pairs(goal) do if rawget(o, "_goal")[k] ~= nil then stopTween(o, "Cancelled") break end end end
	end
	local start = {}
	for k in pairs(goal) do start[k] = obj[k] end
	rawset(self, "_start", start)
	if not rawget(self, "_paused") then rawset(self, "_t", -P(self).TweenInfo.DelayTime); rawset(self, "_reps", 0); rawset(self, "_back", false) end
	rawset(self, "_paused", false)
	rawset(self, "_active", true)
	P(self).PlaybackState = M.Enum.PlaybackState.Playing
	if not table.find(M.tweens, self) then table.insert(M.tweens, self) end
end
function Inst.Cancel(self) if rawget(self, "_active") then stopTween(self, "Cancelled") end end
function Inst.Pause(self)
	if isa(self, "Sound") then P(self).Playing = false return end
	if rawget(self, "_active") then rawset(self, "_active", false); rawset(self, "_paused", true); P(self).PlaybackState = M.Enum.PlaybackState.Paused end
end
function Inst.Stop(self) if isa(self, "Sound") then P(self).Playing = false; P(self).TimePosition = 0 end end
function Inst.Resume(self) if isa(self, "Sound") then P(self).Playing = true end end
stepTweens = function(dt)
	for i = #M.tweens, 1, -1 do
		local tw = M.tweens[i]
		local p = P(tw)
		local info, obj = p.TweenInfo, p.Instance
		if not rawget(tw, "_active") then
			if not rawget(tw, "_paused") then table.remove(M.tweens, i) end
		elseif rawget(obj, "_destroyed") then
			stopTween(tw, "Cancelled")
		else
			local t = rawget(tw, "_t") + dt
			rawset(tw, "_t", t)
			if t >= 0 then
				local a = math.min(t / math.max(info.Time, 1e-6), 1)
				local back = rawget(tw, "_back")
				local alpha = ease(info.EasingStyle, info.EasingDirection, back and 1 - a or a)
				local start = rawget(tw, "_start")
				for k, g in pairs(rawget(tw, "_goal")) do obj[k] = lerp(start[k], g, alpha) end
				if a >= 1 then
					if info.Reverses and not back then rawset(tw, "_back", true); rawset(tw, "_t", 0)
					elseif info.RepeatCount < 0 or rawget(tw, "_reps") < info.RepeatCount then rawset(tw, "_reps", rawget(tw, "_reps") + 1); rawset(tw, "_back", false); rawset(tw, "_t", -info.DelayTime)
					else stopTween(tw, "Completed") end
				end
			end
		end
	end
end
local function guiTween(self, goal, dir, style, time, override, cb)
	local tw = Inst.Create(nil, self, M.TweenInfo.new(time or 1, style or M.Enum.EasingStyle.Quad, dir or M.Enum.EasingDirection.Out), goal)
	if cb then P(tw).Completed:Connect(function(st) cb(st) end) end
	Inst.Play(tw)
	return true
end
function Inst.TweenPosition(self, pos, ...) return guiTween(self, { Position = pos }, ...) end
function Inst.TweenSize(self, size, ...) return guiTween(self, { Size = size }, ...) end
function Inst.TweenSizeAndPosition(self, size, pos, ...) return guiTween(self, { Size = size, Position = pos }, ...) end
-- Debris, теги, Http
function Inst.AddItem(_, item, t) M.task.delay(t or 10, function() if not rawget(item, "_destroyed") then Inst.Destroy(item) end end) end
local tagSignals = {}
M.onTag = function(o, tag, added) local s = tagSignals[(added and "+" or "-") .. tag]; if s then X.fireSignal(s, o) end end
for _, n in ipairs({ "AddTag", "RemoveTag", "HasTag", "GetTags" }) do -- одноимённые методы Instance и CollectionService
	local f = Inst[n]
	Inst[n] = function(self, a, b) if P(self).ClassName == "CollectionService" then return f(a, b) end return f(self, a) end
end
function Inst.GetTagged(_, tag) local o = {}; for _, d in ipairs(Inst.GetDescendants(M.game)) do if Inst.HasTag(d, tag) then o[#o + 1] = d end end return o end
function Inst.GetAllTags() local s, o = {}, {}; for _, d in ipairs(Inst.GetDescendants(M.game)) do for t in pairs(rawget(d, "_tags") or {}) do if not s[t] then s[t] = true; o[#o + 1] = t end end end return o end
local function tagSignal(key) tagSignals[key] = tagSignals[key] or M.newSignal(key); return tagSignals[key] end
function Inst.GetInstanceAddedSignal(_, tag) return tagSignal("+" .. tag) end
function Inst.GetInstanceRemovedSignal(_, tag) return tagSignal("-" .. tag) end
local guid = 0
function Inst.GenerateGUID(_, wrap) guid += 1; local s = string.format("%08X-0000-4000-8000-%012X", 0x5EED0000 + guid, guid); return wrap == false and s or "{" .. s .. "}" end
function Inst.UrlEncode(_, s) return (tostring(s):gsub("[^%w%-_%.~]", function(c) return string.format("%%%02X", string.byte(c)) end)) end
-- DataStore в памяти (M.dataStores), значения проверяются на сериализуемость
local function dsCopy(v, path, seen)
	local t = type(v)
	if t == "number" then if v ~= v or math.abs(v) == math.huge then M.problem("DataStore: NaN/inf at " .. path) end return v end
	if t == "string" then if not utf8.len(v) then M.problem("DataStore: invalid UTF-8 at " .. path) end return v end
	if t == "boolean" or t == "nil" then return v end
	if t ~= "table" or getmetatable(v) ~= nil or M.isInstance(v) then M.problem("DataStore: cannot store " .. M.typeof(v) .. " at " .. path); return nil end
	if seen[v] then M.problem("DataStore: cyclic table at " .. path); return nil end
	seen[v] = true
	local n, cnt = #v, 0
	for k in pairs(v) do cnt += 1; if type(k) ~= "string" and type(k) ~= "number" then M.problem("DataStore: key of type " .. type(k) .. " at " .. path) end end
	if n > 0 and cnt ~= n then M.problem("DataStore: mixed/sparse table at " .. path) end
	local out = {}
	for k, x in pairs(v) do out[k] = dsCopy(x, path .. "." .. tostring(k), seen) end
	seen[v] = nil
	return out
end
local function store(ds, key)
	if M.dataStoreError then error(M.dataStoreError, 3) end
	if type(key) ~= "string" or #key == 0 or #key > 50 then M.problem("DataStore: key must be a string of 1..50 chars, got " .. tostring(key)) end
	return M.dataStores[rawget(ds, "_key")]
end
function Inst.GetDataStore(_, name, scope)
	onlyOn("server", "GetDataStore")
	local key = tostring(name) .. "/" .. tostring(scope or "global")
	local ds = X.create("DataStore")
	P(ds).Name = tostring(name)
	rawset(ds, "_key", key)
	M.dataStores[key] = M.dataStores[key] or {}
	return ds
end
Inst.GetOrderedDataStore = Inst.GetDataStore
function Inst.GetGlobalDataStore(s) return Inst.GetDataStore(s, "global") end
Inst.GetRequestBudgetForRequestType = function() return 100 end
function Inst.GetAsync(ds, key) local d = store(ds, key); if d[key] == nil then return nil end return dsCopy(d[key], key, {}), {} end
function Inst.SetAsync(ds, key, value) local d = store(ds, key); d[key] = dsCopy(value, key, {}) end
function Inst.UpdateAsync(ds, key, fn) local d = store(ds, key); local new = fn(d[key] ~= nil and dsCopy(d[key], key, {}) or nil, {}); if new ~= nil then d[key] = dsCopy(new, key, {}) end return new end
function Inst.RemoveAsync(ds, key) local d = store(ds, key); local v = d[key]; d[key] = nil; return v end
function Inst.IncrementAsync(ds, key, delta) local d = store(ds, key); d[key] = (d[key] or 0) + (delta or 1); return d[key] end
-- покупки, ввод, GUI-сервисы, прочие заглушки без побочных эффектов
function Inst.PromptProductPurchase(_, player, id) table.insert(M.purchases, { player, id }) end
function Inst.PromptGamePassPurchase(_, player, id) table.insert(M.purchases, { player, id, pass = true }) end
function Inst.GetProductInfo(_, id) return { Name = "Product " .. tostring(id), PriceInRobux = 0, ProductId = id } end
function Inst.IsKeyDown(_, k) return M.keysDown[k] == true end
function Inst.GetMouseLocation() return M.mouse end
function Inst.GetMouseDelta() return X.V2.zero end
function Inst.GetLastInputType() return M.Enum.UserInputType.MouseMovement end
function Inst.GetStringForKeyCode(_, k) return k.Name end
function Inst.GetGuiInset() return v2(0, 36), v2(0, 0) end
function Inst.SetCoreGuiEnabled() onlyOn("client", "SetCoreGuiEnabled") end
function Inst.SetCore() onlyOn("client", "SetCore") end
function Inst.BindAction(_, name, fn) M.actions[name] = fn end
Inst.BindActionAtPriority = Inst.BindAction
function Inst.UnbindAction(_, name) M.actions[name] = nil end
function Inst.UnbindAllActions() M.actions = {} end
function Inst.GetTextSize(_, text, size) text = tostring(text); return v2((utf8.len(text) or #text) * size * 0.5, size) end
function Inst.MoveTo(self, pos) if isa(self, "Humanoid") then self.WalkToPoint = pos return end Inst.PivotTo(self, CF.new(pos) * Inst.GetPivot(self).Rotation) end
function Inst.GetState() return M.Enum.HumanoidStateType.Running end
function Inst.TakeDamage(h, n) h.Health = math.max(0, (P(h).Health or 100) - n) end
function Inst.GetPolicyInfoForPlayerAsync() return { AreAdsAllowed = false, ArePaidRandomItemsRestricted = false, AllowedExternalLinkReferences = {}, IsPaidItemTradingAllowed = true, IsSubjectToChinaPolicies = false } end
function Inst.GetMinutesAfterMidnight(l) return (P(l).ClockTime or 14) * 60 end
function Inst.SetMinutesAfterMidnight(l, m) l.ClockTime = (m / 60) % 24 end
function Inst.GetSunDirection() return v3(0.3, 0.9, 0.3).Unit end
function Inst.GetMoonDirection() return v3(-0.3, 0.9, -0.3).Unit end
function Inst.GetServerTimeNow() return M.epoch + M.now end -- как в Roblox: unix-время
function Inst.GetMass(p) return P(p).Size.X * P(p).Size.Y * P(p).Size.Z * 0.7 end
function Inst.GetConnectedParts(p) return { p } end
function Inst.GetRootPart(p) return p end
function Inst.SetNetworkOwner() onlyOn("server", "SetNetworkOwner") end
function Inst.CanSetNetworkOwnership(p) return not P(p).Anchored, nil end
function Inst.BulkMoveTo(_, parts, cfs) for i, p in ipairs(parts) do p.CFrame = cfs[i] end end
for _, n in ipairs({ "PromptPurchase", "SetTitle", "SetImage", "SetPosition", "PreloadAsync", "Emit", "Clear", "Move", "ChangeState", "SetStateEnabled", "UnequipTools",
	"RegisterCollisionGroup", "CollisionGroupSetCollidable", "SetMotor", "LogEconomyEvent", "LogCustomEvent", "RemoveDefaultLoadingScreen", "ApplyLayout",
	"SetNetworkOwnershipAuto", "ApplyImpulse", "ApplyAngularImpulse", "BreakJoints", "ZoomToExtents" }) do Inst[n] = function() end end
for n, v in pairs({ UserOwnsGamePassAsync = false, PlayerOwnsAsset = false, IsMouseButtonPressed = false, IsTenFootInterface = false, GetCoreGuiEnabled = true,
	CollisionGroupsAreCollidable = true, IsCollisionGroupRegistered = true, GetRealPhysicsFPS = 60, GetTopbarTransparency = 0, IsVibrationSupported = false,
	IsFinishedReplicating = true, GetVelocityAtPosition = V3.zero }) do Inst[n] = function() return v end end
for _, n in ipairs({ "GetFocusedTextBox", "GetCore", "GetButton", "GetNetworkOwner" }) do Inst[n] = function() return nil end end
for _, n in ipairs({ "GetKeysPressed", "GetMouseButtonsPressed", "GetTouchingParts", "GetJoints", "GetPlayingAnimationTracks", "GetPartsObscuringTarget" }) do Inst[n] = function() return {} end end
-- камера и запросы к миру
local function camRay(cam, x, y)
	local c, vs, fov = cam.CFrame, P(cam).ViewportSize or v2(1280, 720), math.rad(cam.FieldOfView)
	local t = math.tan(fov / 2)
	local d = v3((2 * x / vs.X - 1) * t * vs.X / vs.Y, (1 - 2 * y / vs.Y) * t, -1).Unit
	return M.Ray.new(c.p, CF.VectorToWorldSpace(c, d))
end
function Inst.ViewportPointToRay(cam, x, y) return camRay(cam, x, y) end
function Inst.ScreenPointToRay(cam, x, y) return camRay(cam, x, y + 36) end
function Inst.WorldToViewportPoint(cam, pos)
	local c, vs, fov = cam.CFrame, P(cam).ViewportSize or v2(1280, 720), math.rad(cam.FieldOfView)
	local l = CF.PointToObjectSpace(c, pos)
	local t, depth = math.tan(fov / 2), -l.Z
	if depth <= 1e-6 then return v3(0, 0, depth), false end
	local sx, sy = (l.X / depth / (t * vs.X / vs.Y) + 1) * vs.X / 2, (1 - l.Y / depth / t) * vs.Y / 2
	return v3(sx, sy, depth), sx >= 0 and sx <= vs.X and sy >= 0 and sy <= vs.Y
end
function Inst.WorldToScreenPoint(cam, pos) local p, on = Inst.WorldToViewportPoint(cam, pos); return v3(p.X, p.Y - 36, p.Z), on end
function Inst.GetPartsObscuringTarget() return {} end
function Inst.ZoomToExtents() end
local function filterOf(params)
	if not params then return function() return true end end
	local list = params.FilterDescendantsInstances or {}
	local ft = params.FilterType
	local include = ft == M.Enum.RaycastFilterType.Include or ft == M.Enum.RaycastFilterType.Whitelist
	return function(part)
		local hit = false
		for _, f in ipairs(list) do if part == f or Inst.IsDescendantOf(part, f) then hit = true break end end
		return hit == include
	end
end
function M.raycastWorld(root, origin, dir, params) -- луч против OBB всех частей (шары/цилиндры — как боксы)
	local ok, best, bt, bn = filterOf(params), nil, 1, nil
	eachPart(root, function(part)
		local pp = P(part)
		if pp.CanQuery == false or (params and params.RespectCanCollide and pp.CanCollide == false) then return end
		local c, s = pp.CFrame, pp.Size
		local o, d = CF.PointToObjectSpace(c, origin), CF.VectorToObjectSpace(c, dir)
		local t0, t1, axis, sign = 0, bt, nil, 0
		for _, k in ipairs({ "X", "Y", "Z" }) do
			local h, oo, dd = s[k] / 2, o[k], d[k]
			if math.abs(dd) < 1e-12 then
				if oo < -h or oo > h then return end
			else
				local ta, tb, sg = (-h - oo) / dd, (h - oo) / dd, -1
				if ta > tb then ta, tb, sg = tb, ta, 1 end
				if ta > t0 then t0, axis, sign = ta, k, sg end
				if tb < t1 then t1 = tb end
				if t0 > t1 then return end
			end
		end
		if axis == nil or not ok(part) then return end -- начало луча внутри части — Roblox её не видит
		best, bt = part, t0
		bn = CF.VectorToWorldSpace(c, v3(axis == "X" and sign or 0, axis == "Y" and sign or 0, axis == "Z" and sign or 0))
	end)
	if not best then return nil end
	return RR({ Instance = best, Position = origin + dir * bt, Normal = bn, Distance = dir.Magnitude * bt, Material = best.Material })
end
function Inst.Raycast(root, origin, dir, params)
	X.vecArg(origin, "Raycast"); X.vecArg(dir, "Raycast")
	if params ~= nil and M.typeof(params) ~= "RaycastParams" then M.problem("Raycast: RaycastParams expected, got " .. M.typeof(params)) end
	if M.raycast then return M.raycast(origin, dir, params) end -- хук теста (как в старых тестах)
	return M.raycastWorld(root, origin, dir, params)
end
local function cast(root, c, dir, params) return Inst.Raycast(root, c.p or c, dir, params) end
function Inst.Blockcast(root, c, _, dir, params) return cast(root, c, dir, params) end
function Inst.Spherecast(root, pos, _, dir, params) return cast(root, pos, dir, params) end
function Inst.Shapecast(root, part, dir, params) return cast(root, P(part).CFrame, dir, params) end
local function overlap(root, params, test)
	local ok, out = filterOf(params), {}
	local max = params and params.MaxParts or 0
	eachPart(root, function(p)
		if P(p).CanQuery == false or (max > 0 and #out >= max) then return end
		local c = P(p).CFrame
		local ex, ey, ez = extents(c, P(p).Size)
		if test(c.p, ex, ey, ez) and ok(p) then out[#out + 1] = p end
	end)
	return out
end
function Inst.GetPartBoundsInRadius(root, pos, r, params)
	return overlap(root, params, function(c, ex, ey, ez)
		local dx, dy, dz = math.max(math.abs(pos.X - c.X) - ex, 0), math.max(math.abs(pos.Y - c.Y) - ey, 0), math.max(math.abs(pos.Z - c.Z) - ez, 0)
		return dx * dx + dy * dy + dz * dz <= r * r
	end)
end
function Inst.GetPartBoundsInBox(root, bc, size, params)
	local bx, by, bz = extents(bc, size)
	return overlap(root, params, function(c, ex, ey, ez) return math.abs(c.X - bc.p.X) <= ex + bx and math.abs(c.Y - bc.p.Y) <= ey + by and math.abs(c.Z - bc.p.Z) <= ez + bz end)
end
function Inst.GetPartsInPart(root, part, params)
	local o = {}
	for _, p in ipairs(Inst.GetPartBoundsInBox(root, P(part).CFrame, P(part).Size, params)) do if p ~= part then o[#o + 1] = p end end
	return o
end

------------------------------------------------------------------ рантайм скриптов: realm сервер/клиент, require, установка бандла
-- В Roblox у сервера и клиента разные VM: модули грузятся отдельно в каждом realm (свой кэш require, свой _G).
local base = setmetatable({}, { __index = _G })
for _, k in ipairs({ "Vector3", "Vector2", "CFrame", "Color3", "BrickColor", "UDim", "UDim2", "Rect", "Ray", "NumberRange", "NumberSequence", "NumberSequenceKeypoint",
	"ColorSequence", "ColorSequenceKeypoint", "PhysicalProperties", "TweenInfo", "RaycastParams", "OverlapParams", "Font", "DateTime", "Random", "Enum", "typeof", "task" }) do
	base[k] = assert(M[k], k)
end
base.Instance = { new = M.InstanceNew }
base.os = setmetatable({ clock = function() return M.now end, time = function(t) if t then return os.time(t) end return math.floor(M.epoch + M.now) end }, { __index = os })
base.tick = function() return M.epoch + M.now end
base.time = function() return M.now end
base.elapsedTime = base.time
base.wait = function(t) return M.task.wait(t), M.now end
base.delay = function(t, f) M.task.delay(t, f) end
base.spawn = function(f) M.task.defer(f) end
base.warn = function(...) print("WARN:", ...) end
base.print = function(...) print("PRINT:", ...) end
base.version = function() return "0.650.0.0" end
base.settings = function() return { Rendering = { QualityLevel = M.Enum.QualityLevel.Automatic } } end
base.UserSettings = function() return { GameSettings = { SavedQualityLevel = M.Enum.SavedQualitySetting.Automatic }, GetService = function(self, n) return self[n] end } end
E.base = base

local function newRealm(name)
	local R = { name = name, cache = {}, loading = {} }
	local renv = setmetatable({ _G = {}, shared = {} }, { __index = base })
	R.env = renv
	function R.load(obj) -- функция скрипта (не запущена), env = { script = obj } поверх realm
		if not (M.isInstance(obj) and isa(obj, "LuaSourceContainer")) then error("load: script instance expected, got " .. M.typeof(obj), 2) end
		local fn, err = loadstring(P(obj).Source or "", "=" .. Inst.GetFullName(obj))
		if not fn then error(err, 0) end
		local senv = setmetatable({ script = obj }, { __index = renv })
		M.envRealm[senv] = name
		setfenv(fn, senv)
		return fn
	end
	function R.require(obj)
		if type(obj) == "number" then error("require(assetId): внешние модули запрещены", 2) end
		if not (M.isInstance(obj) and P(obj).ClassName == "ModuleScript") then error("Attempted to call require with invalid argument(s).", 2) end
		local c = R.cache[obj]
		if c then
			if c.err then error("Requested module experienced an error while loading: " .. Inst.GetFullName(obj), 2) end
			return c.value
		end
		if R.loading[obj] then error("Requested module was required recursively: " .. Inst.GetFullName(obj), 2) end
		R.loading[obj] = true
		local okL, fn = pcall(R.load, obj)
		if not okL then R.loading[obj] = nil; R.cache[obj] = { err = true }; error(fn, 0) end
		local r = table.pack(xpcall(fn, debug.traceback))
		R.loading[obj] = nil
		if not r[1] then R.cache[obj] = { err = true }; error(r[2], 0) end
		if r.n ~= 2 then R.cache[obj] = { err = true }; error("Module code did not return exactly one value: " .. Inst.GetFullName(obj), 2) end
		R.cache[obj] = { value = r[2] }
		return r[2]
	end
	renv.require = R.require
	return R
end
local CLIENT_ROOTS = { StarterPlayer = 1, StarterGui = 1, StarterPack = 1, ReplicatedFirst = 1, Players = 1 }
local SERVER_ROOTS = { ServerScriptService = 1, ServerStorage = 1 }
local function realmFor(obj, explicit)
	if explicit then return explicit end
	local o = obj
	while o do
		local n = P(o).Name
		local par = P(o).Parent
		if par == M.game then
			if CLIENT_ROOTS[n] then return E.client end
			if SERVER_ROOTS[n] then return E.server end
		end
		o = par
	end
	if P(obj).ClassName == "LocalScript" then return E.client end
	return E.defaultRealm == "client" and E.client or E.server
end

-- E.make(): свежий DataModel + realm'ы; возвращает env теста (env.require выбирает realm по месту модуля)
function E.make()
	M.setup()
	math.randomseed(1)
	base.game, base.Game, base.workspace, base.Workspace = M.game, M.game, M.workspace, M.workspace
	E.server, E.client = newRealm("server"), newRealm("client")
	E.defaultRealm = "server"
	local env = setmetatable({}, { __index = base })
	env.require = function(obj, realm) return realmFor(obj, realm).require(obj) end
	E.env = env
	return env
end
function E.load(obj, realm) return realmFor(obj, realm).load(obj) end
-- запуск скрипта как в Roblox: в своём потоке (может уступать); ошибки — через M.reportError
function E.run(obj, realm) local co = coroutine.create(E.load(obj, realm)); M.resumeThread(co); return co end
-- установка дерева src (tests/_bundle.luau, собирается tools/build.py)
function E.install()
	local bundle = require("./_bundle")
	E.bundle = bundle
	E.files = bundle(M)
	P(M.workspace).StreamingEnabled = false -- как в VoidTD.rbxlx
	return E.files
end
local function scripts(root, class)
	local o = {}
	for _, d in ipairs(Inst.GetDescendants(root)) do if P(d).ClassName == class and P(d).Enabled ~= false and not P(d).Disabled then o[#o + 1] = d end end
	return o
end
function E.startServer() -- все Script в ServerScriptService (как при старте сервера)
	local t = {}
	for _, s in ipairs(scripts(M.services.ServerScriptService, "Script")) do t[#t + 1] = E.run(s, E.server) end
	return t
end
-- клиент: StarterPlayerScripts копируется в Player.PlayerScripts, LocalScript'ы стартуют в client realm
function E.startClient(player)
	P(M.services.Players).LocalPlayer = player
	local ps = Inst.FindFirstChild(player, "PlayerScripts")
	if not ps then ps = X.create("PlayerScripts"); P(ps).Name = "PlayerScripts"; ps.Parent = player end
	local roots = {}
	for _, ch in ipairs(Inst.GetChildren(Inst.FindFirstChild(M.services.StarterPlayer, "StarterPlayerScripts"))) do
		local c = Inst.Clone(ch)
		c.Parent = ps
		roots[P(c).Name] = c
	end
	for _, s in ipairs(scripts(ps, "LocalScript")) do E.run(s, E.client) end
	return roots, ps
end
function E.close() for _, fn in ipairs(M.closeHandlers) do X.runHandler(fn) end end -- game:BindToClose
E.M = M
return E
