--!nocheck
-- VOID TD :: Anims (клиент)
-- Анимации юнитов ключевыми кадрами (углы в градусах) и вторичное движение (дыхание, крылья,
-- шея, плащи, орбиты, шестерёнки). Те же позы и тайминги, что в легаси Renderer + HalloweenAnims.
--
-- ФОРМАТ КЛИПА
--   Anims.Clips[name](h, hits, interval) -> frames
--   frames = { { time, { Joint = { xDeg, yDeg, zDeg [, dy] } } }, ... }, время по возрастанию,
--   первый кадр {0, {}}, последний обычно {T, {}} (возврат в idle). Клип заканчивается, когда
--   прошло >= времени последнего кадра. Сустав, которого нет в кадре, берётся из rig.Idle
--   (а если и там нет — {0,0,0,0}). Суставы: RS LS Neck Root WingR WingL; у Root 4-е число —
--   смещение по вертикали (в studs, умножается на rig.Scale).
--   h = HitDelay (момент удара). Способности (TimeBreak, LanternBeam, ...) h игнорируют.
--
-- API
--   Anims.Clips[name]                         -- все клипы (атаки, способности, разминки, PowerUp/Land/Cheer)
--   Anims.Fidgets[attackAnim] = { names }     -- разминки в простое по def.Anim юнита
--   Anims.Has(name) -> bool
--   Anims.FidgetsFor(attackAnim) -> { names } -- список или { "LookAround" }
--   Anims.PickFidget(attackAnim) -> name      -- случайная разминка (math.random)
--   Anims.Play(state, name, h, hits, interval [, start]) -> bool
--        state.Anim = { Start = start or os.clock(), Frames = clip(h, hits, interval), Name = name }
--   Anims.PlayFidget(state, attackAnim [, start]) -> name
--   Anims.Stop(state)                         -- state.Anim = nil
--   Anims.IsPlaying(state) -> bool
--   Anims.Eval(state, t) -> pose              -- state = { Rig, Anim = {Start, Frames}, Phase };
--        по окончании клипа сбрасывает state.Anim = nil и возвращает rig.Idle.
--        Возвращаемая поза — переиспользуемый буфер state.PoseBuf (валиден до следующего Eval).
--   Anims.Apply(rig, pose, t, phase)          -- пишет motor.C0 всех моторов rig.Motors (от rig.Base):
--        Root: dy*Scale + дыхание; RS/LS: дыхание; Wing*: взмахи; Neck: покачивание;
--        Cape/Scarf/Cape2: колыхание + порыв rig.Gust; Orbit*: вращение по Y;
--        rig.SpinRates[motor] (рад/с, Clock*/Gear*): накопленный угол по Z, ×3 при rig.Storm,
--        ×6 пока os.clock() < rig.SpinBoostUntil. Пишет rig.SpinT, rig.SpinAngle.
--   Anims.Step(state, t)                      -- Apply(state.Rig, Eval(state, t), t, state.Phase or 0)
--   Anims.Register(name, builder [, fidgets]) -- добавить/заменить клип
--   Anims.Ease(a)                             -- smoothstep a*a*(3-2a)
--   t — os.clock() (тот же источник времени, что Start и SpinBoostUntil).
--   Для совместимости Anims[name] тоже отдаёт клип (Anims.Slash == Anims.Clips.Slash).

local Anims = {}
local Clips = {}
local Fidgets = {}
Anims.Clips = Clips
Anims.Fidgets = Fidgets

local CF = CFrame.new
local ANG = CFrame.Angles
local rad = math.rad
local sin = math.sin
local clamp = math.clamp

local EMPTY = {}
local ZERO = { 0, 0, 0, 0 }
local DEFAULT_FIDGETS = { "LookAround" }

------------------------------------------------------------------------
-- АТАКИ (h = HitDelay)
------------------------------------------------------------------------
function Clips.Slash(h)
	h = h or 0.2
	return {
		{ 0, {} },
		{ h * 0.75, { RS = { 150, 0, 12 }, Root = { 0, -15, 0 } } },
		{ h, { RS = { 25, 0, -12 }, LS = { -20, 0, 0 }, Root = { 4, 15, 0 } } },
		{ h + 0.2, { RS = { 15, 0, -5 } } },
		{ h + 0.5, {} },
	}
end

function Clips.HeavySlash(h)
	h = h or 0.2
	return {
		{ 0, {} },
		{ h * 0.8, { RS = { 168, 0, 15 }, LS = { 40, 0, -10 }, Root = { -8, -22, 0 } } },
		{ h, { RS = { 18, 0, -15 }, LS = { 30, 0, 0 }, Root = { 12, 20, 0, -0.15 } } },
		{ h + 0.3, { RS = { 15, 0, -5 }, Root = { 6, 10, 0 } } },
		{ h + 0.65, {} },
	}
end

function Clips.Bow(h)
	h = h or 0.2
	return {
		{ 0, {} },
		{ h * 0.6, { LS = { 90, 0, 0 }, RS = { 90, 0, -30 }, Root = { 0, -20, 0 } } },
		{ h, { LS = { 90, 0, 0 }, RS = { 75, 0, -65 }, Root = { 0, -20, 0 } } },
		{ h + 0.06, { LS = { 92, 0, 0 }, RS = { 95, 0, -15 }, Root = { 0, -20, 0 } } },
		{ h + 0.45, {} },
	}
end

function Clips.Cast(h)
	h = h or 0.2
	return {
		{ 0, {} },
		{ h * 0.7, { RS = { 145, 0, 0 }, LS = { 30, 0, -20 }, Neck = { 12, 0, 0 } } },
		{ h, { RS = { 90, 0, 0 }, LS = { 55, 0, -25 } } },
		{ h + 0.45, {} },
	}
end

function Clips.Gun(h)
	h = h or 0.2
	return {
		{ 0, {} },
		{ h, { RS = { 92, 0, 0 }, LS = { 88, 0, -30 } } },
		{ h + 0.05, { RS = { 104, 0, 0 }, LS = { 98, 0, -30 }, Root = { -5, 0, 0 } } },
		{ h + 0.18, { RS = { 92, 0, 0 }, LS = { 88, 0, -30 } } },
		{ h + 0.5, {} },
	}
end

function Clips.Reap(h)
	h = h or 0.2
	return {
		{ 0, {} },
		{ h * 0.7, { RS = { 60, 0, 25 }, LS = { 50, 0, -10 }, Root = { 0, -70, 0 } } },
		{ h, { RS = { 75, 0, -15 }, LS = { 65, 0, 10 }, Root = { 6, 80, 0 } } },
		{ h + 0.25, { RS = { 60, 0, -10 }, Root = { 3, 60, 0 } } },
		{ h + 0.65, {} },
	}
end

-- серия ударов: каждый следующий — в обратную сторону
function Clips.Katana(h, hits, interval)
	h = h or 0.2
	hits = math.max(1, math.floor(hits or 1))
	interval = interval or 0.16
	local k = { { 0, {} }, { h * 0.7, { RS = { 125, 0, 40 }, Root = { 0, -25, 0 } } } }
	for i = 1, hits do
		local t = h + (i - 1) * interval
		local dir = (i % 2 == 1) and 1 or -1
		k[#k + 1] = { t, { RS = { 45, 0, -50 * dir }, Root = { 4, 30 * dir, 0 } } }
		if i < hits then
			k[#k + 1] = { t + interval * 0.6, { RS = { 120, 0, 40 * -dir }, Root = { 0, -20 * dir, 0 } } }
		end
	end
	local last = h + (hits - 1) * interval
	k[#k + 1] = { last + 0.15, { RS = { 30, 0, -30 } } }
	k[#k + 1] = { last + 0.4, {} }
	return k
end

function Clips.Slam(h)
	h = h or 0.2
	return {
		{ 0, {} },
		{ h * 0.65, { RS = { 172, 0, 10 }, LS = { 165, 0, -10 }, Root = { -10, 0, 0, 0.15 }, Neck = { -10, 0, 0 } } },
		{ h, { RS = { 55, 0, 0 }, LS = { 50, 0, 0 }, Root = { 16, 0, 0, -0.45 } } },
		{ h + 0.35, { RS = { 48, 0, 0 }, LS = { 45, 0, 0 }, Root = { 12, 0, 0, -0.35 } } },
		{ h + 0.85, {} },
	}
end

function Clips.Beam(h)
	h = h or 0.2
	return {
		{ 0, {} },
		{ h * 0.6, { RS = { 55, 0, 0 }, Root = { -6, 0, 0 }, WingR = { 0, 25, 0 }, WingL = { 0, -25, 0 } } },
		{ h, { RS = { 96, 0, 0 }, LS = { 60, 0, -20 }, Root = { 4, 0, 0 }, WingR = { 0, -15, 10 }, WingL = { 0, 15, -10 } } },
		{ h + 0.45, { RS = { 94, 0, 0 }, LS = { 55, 0, -20 } } },
		{ h + 0.85, {} },
	}
end

-- рука держится поднятой, пока идут все удары серии
function Clips.Judgement(h, hits, interval)
	h = h or 0.2
	local hold = h + math.max(0, hits or 3) * (interval or 0.18)
	return {
		{ 0, {} },
		{ h * 0.8, { RS = { 178, 0, 5 }, LS = { 35, 0, -35 }, Neck = { 18, 0, 0 }, Root = { -6, 0, 0, 0.2 } } },
		{ hold, { RS = { 172, 0, 5 }, LS = { 40, 0, -40 }, Neck = { 15, 0, 0 }, Root = { -4, 0, 0, 0.2 } } },
		{ hold + 0.2, { RS = { 40, 0, -10 }, Root = { 10, 0, 0 } } },
		{ hold + 0.6, {} },
	}
end

function Clips.Smash(h)
	h = h or 0.2
	return {
		{ 0, {} },
		{ h * 0.7, { RS = { 160, 0, 10 }, Root = { -8, -18, 0 } } },
		{ h, { RS = { 40, 0, -10 }, LS = { 30, 0, 0 }, Root = { 14, 18, 0, -0.3 } } },
		{ h + 0.45, {} },
	}
end

function Clips.BlackHoleCast(h)
	h = h or 0.2
	return {
		{ 0, {} },
		{ h * 0.7, { RS = { 150, 0, 30 }, LS = { 150, 0, -30 }, Neck = { 25, 0, 0 }, Root = { -8, 0, 0, 0.2 } } },
		{ h, { RS = { 110, 0, 40 }, LS = { 110, 0, -40 }, Root = { 6, 0, 0 } } },
		{ h + 0.5, {} },
	}
end

function Clips.DualDagger(h)
	h = h or 0.2
	return {
		{ 0, {} },
		{ h * 0.6, { RS = { 110, 0, 20 }, LS = { 40, 0, -10 }, Root = { 0, -20, 0 } } },
		{ h, { RS = { 60, 0, -20 }, LS = { 100, 0, -20 }, Root = { 4, 20, 0 } } },
		{ h + 0.12, { RS = { 75, 0, 0 }, LS = { 70, 0, 0 } } },
		{ h + 0.3, {} },
	}
end

function Clips.Crossbow(h)
	h = h or 0.2
	return {
		{ 0, {} },
		{ h, { RS = { 88, 0, 0 }, LS = { 82, 0, -28 }, Neck = { 6, 0, 0 } } },
		{ h + 0.06, { RS = { 105, 0, 0 }, LS = { 96, 0, -28 }, Root = { -6, 0, 0 } } },
		{ h + 0.3, { RS = { 88, 0, 0 }, LS = { 82, 0, -28 } } },
		{ h + 0.6, {} },
	}
end

function Clips.Puppet(h)
	h = h or 0.2
	return {
		{ 0, {} },
		{ h * 0.7, { RS = { 85, 0, 35 }, LS = { 85, 0, -35 }, Neck = { 10, 0, 0 } } },
		{ h, { RS = { 105, 0, 12 }, LS = { 105, 0, -12 } } },
		{ h + 0.15, { RS = { 90, 0, 28 }, LS = { 90, 0, -28 } } },
		{ h + 0.5, {} },
	}
end

-- Проклятый Часовщик: замах Хроносекирой из-за плеча и горизонтальный взмах
function Clips.ChronoSlash(h)
	h = h or 0.2
	return {
		{ 0, {} },
		{ h * 0.75, { RS = { 160, 0, 35 }, LS = { 40, 0, -20 }, Root = { -4, -28, 0 } } },
		{ h, { RS = { 70, 0, -70 }, LS = { 20, 0, -10 }, Root = { 6, 32, 0, -0.1 } } },
		{ h + 0.25, { RS = { 45, 0, -40 }, Root = { 3, 18, 0 } } },
		{ h + 0.6, {} },
	}
end

-- два выстрела: правая, затем левая рука
function Clips.Revolver(h)
	h = h or 0.2
	return {
		{ 0, {} },
		{ h, { RS = { 95, 0, 0 }, LS = { 70, 0, 0 } } },
		{ h + 0.05, { RS = { 112, 0, 0 }, LS = { 70, 0, 0 }, Root = { -3, 0, 0 } } },
		{ h + 0.12, { RS = { 92, 0, 0 }, LS = { 95, 0, 0 } } },
		{ h + 0.17, { RS = { 92, 0, 0 }, LS = { 112, 0, 0 }, Root = { -3, 0, 0 } } },
		{ h + 0.45, {} },
	}
end

------------------------------------------------------------------------
-- СПОСОБНОСТИ ЧАСОВЩИКА (фиксированное время, h не нужен)
------------------------------------------------------------------------
-- Поломка времени: секира над головой, затем удар о землю
function Clips.TimeBreak()
	return {
		{ 0, {} },
		{ 0.35, { RS = { 175, 0, 5 }, LS = { 165, 0, -5 }, Neck = { -15, 0, 0 }, Root = { -8, 0, 0, 0.3 } } },
		{ 0.5, { RS = { 30, 0, 0 }, LS = { 30, 0, 0 }, Neck = { 15, 0, 0 }, Root = { 20, 0, 0, -0.45 } } },
		{ 0.95, { RS = { 30, 0, 0 }, LS = { 30, 0, 0 }, Root = { 16, 0, 0, -0.4 } } },
		{ 1.35, {} },
	}
end

-- Ускорение времени: секира вертикально вверх
function Clips.TimeHaste()
	return {
		{ 0, {} },
		{ 0.4, { RS = { 178, 0, 0 }, Neck = { -18, 0, 0 }, Root = { 0, 0, 0, 0.25 } } },
		{ 1.1, { RS = { 178, 0, 0 }, Neck = { -18, 0, 0 }, Root = { 0, 0, 0, 0.25 } } },
		{ 1.5, {} },
	}
end

-- Временная буря: медленный подъём, вспышка, удар о землю
function Clips.TimeStorm()
	return {
		{ 0, {} },
		{ 0.9, { RS = { 172, 0, 10 }, LS = { 150, 0, -15 }, Neck = { -22, 0, 0 }, Root = { -8, 0, 0, 0.4 } } },
		{ 1.15, { RS = { 176, 0, 10 }, LS = { 155, 0, -15 }, Neck = { -24, 0, 0 }, Root = { -9, 0, 0, 0.45 } } },
		{ 1.3, { RS = { 25, 0, 0 }, LS = { 25, 0, 0 }, Neck = { 18, 0, 0 }, Root = { 22, 0, 0, -0.55 } } },
		{ 1.8, { RS = { 25, 0, 0 }, LS = { 25, 0, 0 }, Root = { 15, 0, 0, -0.4 } } },
		{ 2.2, {} },
	}
end

------------------------------------------------------------------------
-- ПРОСТОЙ, ПОВЫШЕНИЕ, ПРАЗДНОВАНИЕ, ПРИЗЕМЛЕНИЕ
------------------------------------------------------------------------
function Clips.LookAround()
	return { { 0, {} }, { 0.5, { Neck = { 0, 40, 0 } } }, { 1.2, { Neck = { 5, -40, 0 } } }, { 1.8, {} } }
end

-- вращение оружия: последний кадр (15, 360, 0) — тот же угол, что idle; интерполяция идёт по
-- градусам Эйлера, поэтому 0 -> 360 даёт полный оборот
function Clips.Twirl()
	return {
		{ 0, {} },
		{ 0.25, { RS = { 85, 0, 0 } } },
		{ 0.45, { RS = { 85, 120, 0 } } },
		{ 0.65, { RS = { 85, 240, 0 } } },
		{ 0.85, { RS = { 85, 360, 0 } } },
		{ 1.2, { RS = { 15, 360, 0 } } },
	}
end

function Clips.Flex()
	return {
		{ 0, {} },
		{ 0.35, { RS = { 0, 0, 95 }, LS = { 0, 0, -95 }, Root = { -4, 0, 0 } } },
		{ 0.6, { RS = { 0, 0, 80 }, LS = { 0, 0, -80 }, Root = { -6, 0, 0, 0.1 } } },
		{ 1.1, {} },
	}
end

function Clips.Stretch()
	return {
		{ 0, {} },
		{ 0.5, { RS = { 170, 0, 15 }, LS = { 170, 0, -15 }, Root = { -8, 0, 0, 0.15 }, Neck = { -15, 0, 0 } } },
		{ 1.1, { RS = { 165, 0, 20 }, LS = { 165, 0, -20 }, Root = { -6, 0, 0, 0.1 }, Neck = { -10, 0, 0 } } },
		{ 1.6, {} },
	}
end

function Clips.StaffTap()
	return {
		{ 0, {} },
		{ 0.25, { RS = { 35, 0, 0 } } },
		{ 0.4, { RS = { -5, 0, 0 }, Root = { 0, 0, 0, -0.08 } } },
		{ 0.55, { RS = { 25, 0, 0 } } },
		{ 0.7, { RS = { -5, 0, 0 }, Root = { 0, 0, 0, -0.08 } } },
		{ 1.1, {} },
	}
end

function Clips.CheckBow()
	return {
		{ 0, {} },
		{ 0.4, { LS = { 75, 0, 35 }, Neck = { 20, -25, 0 }, RS = { 40, 0, -20 } } },
		{ 1.3, { LS = { 70, 0, 30 }, Neck = { 22, -20, 0 }, RS = { 45, 0, -25 } } },
		{ 1.7, {} },
	}
end

function Clips.Reload()
	return {
		{ 0, {} },
		{ 0.3, { RS = { 45, 0, -30 }, LS = { 60, 0, 25 }, Neck = { 25, 0, 0 } } },
		{ 0.5, { RS = { 45, 0, -30 }, LS = { 40, 0, 10 }, Neck = { 25, 0, 0 } } },
		{ 0.7, { RS = { 45, 0, -30 }, LS = { 65, 0, 25 }, Neck = { 25, 0, 0 } } },
		{ 1.2, {} },
	}
end

function Clips.WingSpread()
	return {
		{ 0, {} },
		{ 0.4, { WingR = { 0, -35, 20 }, WingL = { 0, 35, -20 }, Neck = { -15, 0, 0 }, Root = { 0, 0, 0, 0.3 } } },
		{ 1.0, { WingR = { 0, -30, 15 }, WingL = { 0, 30, -15 }, Neck = { -10, 0, 0 }, Root = { 0, 0, 0, 0.25 } } },
		{ 1.5, {} },
	}
end

-- после волны / победы: прыжки с поднятыми руками
function Clips.Cheer()
	local up = { RS = { 165, 0, 25 }, LS = { 165, 0, -25 }, Root = { 0, 0, 0, 0.6 } }
	local down = { RS = { 150, 0, 30 }, LS = { 150, 0, -30 }, Root = { 0, 0, 0, 0 } }
	return { { 0, {} }, { 0.2, up }, { 0.4, down }, { 0.6, up }, { 0.8, down }, { 1.2, {} } }
end

-- повышение уровня: присед и рывок вверх
function Clips.PowerUp()
	return {
		{ 0, {} },
		{ 0.25, { Root = { 12, 0, 0, -0.45 }, RS = { 30, 0, 35 }, LS = { 30, 0, -35 }, Neck = { 15, 0, 0 } } },
		{ 0.5, { Root = { -10, 0, 0, 0.6 }, RS = { 160, 0, 40 }, LS = { 160, 0, -40 }, Neck = { -20, 0, 0 } } },
		{ 0.9, { Root = { -6, 0, 0, 0.3 }, RS = { 150, 0, 35 }, LS = { 150, 0, -35 } } },
		{ 1.3, {} },
	}
end

-- приземление после установки: начинается сразу в приседе
function Clips.Land()
	return {
		{ 0, { Root = { 10, 0, 0, -0.45 }, RS = { 20, 0, 45 }, LS = { 20, 0, -45 } } },
		{ 0.45, {} },
	}
end

------------------------------------------------------------------------
-- ХЭЛЛОУИН: АТАКИ (h = HitDelay)
------------------------------------------------------------------------
-- Ночной сторож: фонарь вперёд и вверх — вспышка
function Clips.Lantern(h)
	h = h or 0.2
	return {
		{ 0, {} },
		{ h * 0.7, { RS = { 125, 0, 0 }, LS = { 20, 0, -10 }, Root = { -4, 0, 0 } } },
		{ h, { RS = { 100, 0, 0 }, Root = { 4, 0, 0 } } },
		{ h + 0.25, { RS = { 80, 0, 0 } } },
		{ h + 0.55, {} },
	}
end

-- Могильщик: удар лопатой сверху вниз
function Clips.Shovel(h)
	h = h or 0.2
	return {
		{ 0, {} },
		{ h * 0.75, { RS = { 172, 0, 10 }, LS = { 40, 0, -10 }, Root = { -8, -10, 0, 0.1 } } },
		{ h, { RS = { 40, 0, -5 }, LS = { 25, 0, 0 }, Root = { 14, 10, 0, -0.2 } } },
		{ h + 0.3, { RS = { 30, 0, 0 }, Root = { 6, 0, 0 } } },
		{ h + 0.65, {} },
	}
end

-- Пугало: взмах рукой — вороны срываются с плеч
function Clips.Crows(h)
	h = h or 0.2
	return {
		{ 0, {} },
		{ h * 0.7, { RS = { 135, 0, 35 }, LS = { 60, 0, -40 }, Neck = { -10, 0, 0 }, Root = { 0, -15, 0 } } },
		{ h, { RS = { 95, 0, -25 }, LS = { 50, 0, -20 }, Root = { 4, 15, 0 } } },
		{ h + 0.3, { RS = { 60, 0, -10 } } },
		{ h + 0.6, {} },
	}
end

-- Звонарь: колокол раскачивается — звон
function Clips.Bell(h)
	h = h or 0.2
	return {
		{ 0, {} },
		{ h * 0.5, { RS = { 95, 0, 35 }, Root = { 0, -8, 0 } } },
		{ h, { RS = { 112, 0, -25 }, Root = { 3, 8, 0 } } },
		{ h + 0.15, { RS = { 92, 0, 25 } } },
		{ h + 0.3, { RS = { 100, 0, -10 } } },
		{ h + 0.6, {} },
	}
end

-- Чумной доктор: бросок колбы из-за плеча
function Clips.Flask(h)
	h = h or 0.2
	return {
		{ 0, {} },
		{ h * 0.7, { RS = { 165, 0, 15 }, LS = { 30, 0, -15 }, Root = { -6, -18, 0 } } },
		{ h, { RS = { 60, 0, -15 }, Root = { 8, 15, 0 } } },
		{ h + 0.3, { RS = { 45, 0, 0 } } },
		{ h + 0.6, {} },
	}
end

-- Призрачный рыцарь: широкий горизонтальный разрез
function Clips.GhostSlash(h)
	h = h or 0.2
	return {
		{ 0, {} },
		{ h * 0.75, { RS = { 125, 0, 45 }, LS = { 30, 0, -15 }, Root = { -4, -30, 0 } } },
		{ h, { RS = { 80, 0, -65 }, LS = { 20, 0, -5 }, Root = { 6, 30, 0, -0.1 } } },
		{ h + 0.25, { RS = { 50, 0, -40 }, Root = { 3, 15, 0 } } },
		{ h + 0.6, {} },
	}
end

-- Иллюзионист: щелчок кистью — веер карт
function Clips.Cards(h)
	h = h or 0.2
	return {
		{ 0, {} },
		{ h * 0.6, { RS = { 65, 0, 45 }, Root = { 0, -12, 0 } } },
		{ h, { RS = { 98, 0, -35 }, Root = { 0, 12, 0 } } },
		{ h + 0.12, { RS = { 92, 0, -40 } } },
		{ h + 0.45, {} },
	}
end

-- Палач: двуручный удар топором сверху
function Clips.ExecAxe(h)
	h = h or 0.2
	return {
		{ 0, {} },
		{ h * 0.8, { RS = { 176, 0, 5 }, LS = { 166, 0, -5 }, Root = { -10, 0, 0, 0.2 } } },
		{ h, { RS = { 35, 0, 0 }, LS = { 35, 0, 0 }, Root = { 20, 0, 0, -0.4 } } },
		{ h + 0.35, { RS = { 30, 0, 0 }, LS = { 30, 0, 0 }, Root = { 14, 0, 0, -0.3 } } },
		{ h + 0.8, {} },
	}
end

-- Король фонарей: посох вверх и вперёд — огненная тыква
function Clips.LanternStaff(h)
	h = h or 0.2
	return {
		{ 0, {} },
		{ h * 0.7, { RS = { 145, 0, 5 }, LS = { 30, 0, -20 }, Neck = { -8, 0, 0 } } },
		{ h, { RS = { 95, 0, 0 }, LS = { 25, 0, -10 }, Root = { 5, 0, 0 } } },
		{ h + 0.3, { RS = { 80, 0, 0 } } },
		{ h + 0.6, {} },
	}
end

------------------------------------------------------------------------
-- ХЭЛЛОУИН: СПОСОБНОСТИ (в комментарии — момент удара)
------------------------------------------------------------------------
-- Луч фонаря: фонарь высоко над головой (~0.45 с)
function Clips.LanternBeam()
	return {
		{ 0, {} },
		{ 0.35, { RS = { 172, 0, 0 }, LS = { 30, 0, -20 }, Neck = { -15, 0, 0 }, Root = { -4, 0, 0, 0.15 } } },
		{ 0.8, { RS = { 168, 0, 0 }, LS = { 30, 0, -20 }, Neck = { -12, 0, 0 }, Root = { -3, 0, 0, 0.1 } } },
		{ 1.1, {} },
	}
end

-- Взрыв земли: прыжок и удар лопатой в землю (~0.45 с)
function Clips.DirtBurst()
	return {
		{ 0, {} },
		{ 0.3, { RS = { 176, 0, 8 }, LS = { 150, 0, -8 }, Root = { -10, 0, 0, 0.45 } } },
		{ 0.45, { RS = { 15, 0, 0 }, LS = { 25, 0, 0 }, Root = { 22, 0, 0, -0.45 } } },
		{ 0.85, { RS = { 15, 0, 0 }, LS = { 25, 0, 0 }, Root = { 18, 0, 0, -0.35 } } },
		{ 1.2, {} },
	}
end

-- Вихрь листьев: руки в стороны, разворот корпусом (~0.5 с)
function Clips.LeafStorm()
	return {
		{ 0, {} },
		{ 0.25, { RS = { 95, 0, 70 }, LS = { 95, 0, -70 }, Root = { 0, -45, 0 } } },
		{ 0.5, { RS = { 110, 0, 60 }, LS = { 110, 0, -60 }, Neck = { -15, 0, 0 }, Root = { 0, 45, 0, 0.15 } } },
		{ 0.8, { RS = { 100, 0, 65 }, LS = { 100, 0, -65 }, Root = { 0, 0, 0, 0.1 } } },
		{ 1.1, {} },
	}
end

-- Метка проклятия: долгий прицел и выстрел (~0.45 с)
function Clips.CurseMark()
	return {
		{ 0, {} },
		{ 0.3, { RS = { 92, 0, 0 }, LS = { 88, 0, 15 }, Neck = { 5, 0, 0 }, Root = { 0, -10, 0 } } },
		{ 0.45, { RS = { 125, 0, 0 }, LS = { 95, 0, 15 }, Root = { -6, -10, 0 } } },
		{ 0.7, { RS = { 95, 0, 0 }, LS = { 70, 0, 10 } } },
		{ 1.0, {} },
	}
end

-- Полночный звон: колокол над головой и мощный удар вниз (~0.5 с)
function Clips.MidnightToll()
	return {
		{ 0, {} },
		{ 0.35, { RS = { 176, 0, 0 }, LS = { 120, 0, -20 }, Neck = { -20, 0, 0 }, Root = { -6, 0, 0, 0.2 } } },
		{ 0.5, { RS = { 55, 0, -20 }, LS = { 40, 0, 0 }, Neck = { 12, 0, 0 }, Root = { 16, 0, 0, -0.3 } } },
		{ 0.9, { RS = { 70, 0, 20 }, Root = { 8, 0, 0, -0.15 } } },
		{ 1.25, {} },
	}
end

-- Чумное облако: обе руки вверх и бросок двух колб (~0.55 с)
function Clips.PlagueCloud()
	return {
		{ 0, {} },
		{ 0.4, { RS = { 170, 0, 15 }, LS = { 170, 0, -15 }, Neck = { -15, 0, 0 }, Root = { -6, 0, 0, 0.1 } } },
		{ 0.55, { RS = { 75, 0, -10 }, LS = { 75, 0, 10 }, Root = { 10, 0, 0, -0.1 } } },
		{ 0.9, { RS = { 55, 0, 0 }, LS = { 45, 0, 0 } } },
		{ 1.2, {} },
	}
end

-- Призрачный меч: клинок к небу, затем удар вниз (~0.55 с)
function Clips.GhostSword()
	return {
		{ 0, {} },
		{ 0.4, { RS = { 178, 0, 0 }, LS = { 40, 0, -20 }, Neck = { -20, 0, 0 }, Root = { -6, 0, 0, 0.25 } } },
		{ 0.55, { RS = { 45, 0, 0 }, LS = { 30, 0, -10 }, Neck = { 10, 0, 0 }, Root = { 14, 0, 0, -0.25 } } },
		{ 0.95, { RS = { 40, 0, 0 }, Root = { 10, 0, 0, -0.2 } } },
		{ 1.3, {} },
	}
end

-- Зеркальный разлом: толчок обеими руками вперёд (~0.45 с)
function Clips.MirrorShatter()
	return {
		{ 0, {} },
		{ 0.3, { RS = { 80, 0, 35 }, LS = { 80, 0, -35 }, Root = { -5, 0, 0 } } },
		{ 0.45, { RS = { 96, 0, -8 }, LS = { 96, 0, 8 }, Root = { 8, 0, 0, -0.05 } } },
		{ 0.75, { RS = { 90, 0, -5 }, LS = { 90, 0, 5 } } },
		{ 1.0, {} },
	}
end

-- Разрыв нитей: руки широко вверх и резкий рывок вниз (~0.5 с)
function Clips.ThreadSnap()
	return {
		{ 0, {} },
		{ 0.35, { RS = { 155, 0, 45 }, LS = { 155, 0, -45 }, Neck = { -12, 0, 0 }, Root = { -5, 0, 0, 0.15 } } },
		{ 0.5, { RS = { 40, 0, 15 }, LS = { 40, 0, -15 }, Neck = { 10, 0, 0 }, Root = { 10, 0, 0, -0.15 } } },
		{ 0.8, { RS = { 55, 0, 20 }, LS = { 55, 0, -20 } } },
		{ 1.1, {} },
	}
end

-- Казнь: долгий замах с отклонением назад и страшный удар (~0.65 с)
function Clips.Execution()
	return {
		{ 0, {} },
		{ 0.5, { RS = { 178, 0, 5 }, LS = { 170, 0, -5 }, Neck = { -15, 0, 0 }, Root = { -14, 0, 0, 0.25 } } },
		{ 0.65, { RS = { 25, 0, 0 }, LS = { 25, 0, 0 }, Neck = { 15, 0, 0 }, Root = { 26, 0, 0, -0.55 } } },
		{ 1.1, { RS = { 25, 0, 0 }, LS = { 25, 0, 0 }, Root = { 22, 0, 0, -0.5 } } },
		{ 1.5, {} },
	}
end

-- Призрачная тыква: посох медленно вверх, затем вперёд (~0.8 с)
function Clips.GhostPumpkin()
	return {
		{ 0, {} },
		{ 0.55, { RS = { 176, 0, 0 }, LS = { 120, 0, -25 }, Neck = { -22, 0, 0 }, Root = { -8, 0, 0, 0.35 } } },
		{ 0.7, { RS = { 178, 0, 0 }, LS = { 125, 0, -25 }, Neck = { -24, 0, 0 }, Root = { -9, 0, 0, 0.4 } } },
		{ 0.8, { RS = { 100, 0, 0 }, LS = { 40, 0, -15 }, Neck = { 8, 0, 0 }, Root = { 12, 0, 0, -0.1 } } },
		{ 1.15, { RS = { 90, 0, 0 }, Root = { 6, 0, 0 } } },
		{ 1.45, {} },
	}
end

-- Призыв союзников: руки вверх над порталом (~1.2 с)
function Clips.Summon()
	return {
		{ 0, {} },
		{ 0.4, { RS = { 160, 0, 30 }, LS = { 160, 0, -30 }, Neck = { -18, 0, 0 }, Root = { -4, 0, 0, 0.2 } } },
		{ 0.9, { RS = { 165, 0, 25 }, LS = { 165, 0, -25 }, Neck = { -20, 0, 0 }, Root = { -4, 0, 0, 0.25 } } },
		{ 1.05, { RS = { 70, 0, 25 }, LS = { 70, 0, -25 }, Neck = { 8, 0, 0 }, Root = { 6, 0, 0, -0.05 } } },
		{ 1.3, {} },
	}
end

------------------------------------------------------------------------
-- ПСЕВДОНИМЫ
------------------------------------------------------------------------
Clips.Hammer = Clips.Slam
Clips.RiftStorm = Clips.Judgement
Clips.RedSplash = Clips.HeavySlash
Clips.Sickle = Clips.Slash
Clips.Axe = Clips.HeavySlash

------------------------------------------------------------------------
-- РАЗМИНКИ В ПРОСТОЕ (по def.Anim юнита)
------------------------------------------------------------------------
Fidgets.ChronoSlash = { "LookAround", "Flex", "Twirl" }
Fidgets.DualDagger = { "Twirl", "LookAround", "Flex" }
Fidgets.Crossbow = { "Reload", "LookAround" }
Fidgets.Puppet = { "Stretch", "LookAround" }
Fidgets.Hammer = { "Flex", "Stretch", "LookAround" }
Fidgets.RiftStorm = { "LookAround", "Stretch" }
Fidgets.RedSplash = { "Twirl", "Flex" }
Fidgets.Sickle = { "Twirl", "LookAround" }
Fidgets.Revolver = { "Twirl", "Reload" }
Fidgets.Axe = { "Flex", "LookAround" }
Fidgets.Slash = { "Twirl", "LookAround", "Flex" }
Fidgets.HeavySlash = { "Twirl", "LookAround", "Stretch" }
Fidgets.Katana = { "Twirl", "LookAround" }
Fidgets.Judgement = { "Twirl", "LookAround", "Flex" }
Fidgets.Bow = { "CheckBow", "LookAround" }
Fidgets.Cast = { "StaffTap", "LookAround", "Stretch" }
Fidgets.Gun = { "Reload", "LookAround" }
Fidgets.Reap = { "Twirl", "LookAround" }
Fidgets.Slam = { "Flex", "LookAround", "Stretch" }
Fidgets.Smash = { "Flex", "LookAround" }
Fidgets.Beam = { "WingSpread", "LookAround", "Stretch" }
-- Хэллоуин
Fidgets.Lantern = { "LookAround", "StaffTap" }
Fidgets.Shovel = { "Flex", "LookAround", "Stretch" }
Fidgets.Crows = { "LookAround", "Twirl" }
Fidgets.Bell = { "LookAround", "Stretch" }
Fidgets.Flask = { "LookAround", "Reload" }
Fidgets.GhostSlash = { "Twirl", "LookAround", "Flex" }
Fidgets.Cards = { "Twirl", "LookAround" }
Fidgets.ExecAxe = { "Flex", "LookAround" }
Fidgets.LanternStaff = { "StaffTap", "LookAround", "Stretch" }

------------------------------------------------------------------------
-- ВОСПРОИЗВЕДЕНИЕ
------------------------------------------------------------------------
local function ease(a)
	return a * a * (3 - 2 * a)
end
Anims.Ease = ease

function Anims.Has(name)
	return name ~= nil and Clips[name] ~= nil
end

function Anims.FidgetsFor(attackAnim)
	local list = attackAnim and Fidgets[attackAnim]
	if list and #list > 0 then
		return list
	end
	return DEFAULT_FIDGETS
end

function Anims.PickFidget(attackAnim)
	local list = Anims.FidgetsFor(attackAnim)
	return list[math.random(1, #list)]
end

function Anims.Play(state, name, h, hits, interval, start)
	local clip = name and Clips[name]
	if not state or not clip then
		return false
	end
	state.Anim = { Start = start or os.clock(), Frames = clip(h, hits, interval), Name = name }
	return true
end

function Anims.PlayFidget(state, attackAnim, start)
	local name = Anims.PickFidget(attackAnim)
	Anims.Play(state, name, nil, nil, nil, start)
	return name
end

function Anims.Stop(state)
	if state then
		state.Anim = nil
	end
end

function Anims.IsPlaying(state)
	return state ~= nil and state.Anim ~= nil
end

function Anims.Register(name, builder, fidgets)
	Clips[name] = builder
	if fidgets then
		Fidgets[name] = fidgets
	end
end

-- запись интерполированного сустава в буфер; [5] — метка кадра (для чистки устаревших суставов)
local function mix(buf, joint, p0, p1, a, stamp)
	p0 = p0 or ZERO
	p1 = p1 or ZERO
	local d = buf[joint]
	if not d then
		d = { 0, 0, 0, 0, 0 }
		buf[joint] = d
	end
	local x0, y0, z0, w0 = p0[1] or 0, p0[2] or 0, p0[3] or 0, p0[4] or 0
	d[1] = x0 + ((p1[1] or 0) - x0) * a
	d[2] = y0 + ((p1[2] or 0) - y0) * a
	d[3] = z0 + ((p1[3] or 0) - z0) * a
	d[4] = w0 + ((p1[4] or 0) - w0) * a
	d[5] = stamp
end

-- Поза в момент t: сглаженная (smoothstep) интерполяция между соседними кадрами,
-- суставы = кадр0 ∪ кадр1 ∪ idle
function Anims.Eval(state, t)
	local rig = state.Rig
	local idle = (rig and rig.Idle) or EMPTY
	local anim = state.Anim
	if not anim then
		return idle
	end
	local frames = anim.Frames
	local n = frames and #frames or 0
	if n == 0 then
		state.Anim = nil
		return idle
	end
	local el = t - (anim.Start or t)
	if el >= frames[n][1] then
		state.Anim = nil
		return idle
	end
	local k = 1
	for i = 1, n - 1 do
		if el >= frames[i][1] then
			k = i
		end
	end
	local f0 = frames[k]
	local f1 = frames[k + 1] or f0
	local span = math.max(f1[1] - f0[1], 0.001)
	local a = ease(clamp((el - f0[1]) / span, 0, 1))
	local p0s, p1s = f0[2] or EMPTY, f1[2] or EMPTY

	local buf = state.PoseBuf
	if not buf then
		buf = {}
		state.PoseBuf = buf
	end
	local stamp = (state.PoseStamp or 0) + 1
	state.PoseStamp = stamp
	for j, v in pairs(p0s) do
		mix(buf, j, v, p1s[j] or idle[j], a, stamp)
	end
	for j, v in pairs(p1s) do
		if p0s[j] == nil then
			mix(buf, j, idle[j], v, a, stamp)
		end
	end
	for j, v in pairs(idle) do
		if p0s[j] == nil and p1s[j] == nil then
			mix(buf, j, v, v, a, stamp)
		end
	end
	for j, v in pairs(buf) do
		if v[5] ~= stamp then
			buf[j] = nil
		end
	end
	return buf
end

------------------------------------------------------------------------
-- ВТОРИЧНОЕ ДВИЖЕНИЕ
------------------------------------------------------------------------
-- вид мотора (порядок проверок как в легаси: RS/LS → Wing* → Neck → Cape/Scarf → Cape2 → Orbit* → SpinRates)
local K_OTHER, K_ARM, K_WING, K_NECK, K_CAPE, K_CAPE2, K_ORBIT = 0, 1, 2, 3, 4, 5, 6

local function classify(name)
	if name == "RS" then
		return K_ARM, 1
	elseif name == "LS" then
		return K_ARM, -1
	elseif string.sub(name, 1, 4) == "Wing" then
		return K_WING, (string.sub(name, 5, 5) == "R") and 1 or -1
	elseif name == "Neck" then
		return K_NECK, 0
	elseif name == "Cape" or name == "Scarf" then
		return K_CAPE, 0
	elseif name == "Cape2" then
		return K_CAPE2, 0
	elseif string.sub(name, 1, 5) == "Orbit" then
		return K_ORBIT, 0
	end
	return K_OTHER, 0
end

-- кэш видов моторов на риге (имена не меняются; новые моторы классифицируются при первой встрече)
local function kindsOf(rig)
	local kinds = rig.AnimKinds
	if not kinds then
		kinds = { Kind = {}, Side = {} }
		rig.AnimKinds = kinds
	end
	return kinds
end

function Anims.Apply(rig, pose, t, phase)
	local motors = rig and rig.Motors
	if not motors then
		return
	end
	local base = rig.Base or EMPTY
	pose = pose or EMPTY
	phase = phase or 0
	local s = rig.Scale or 1
	local breathe = sin(t * 2 + phase)

	-- стрелки и шестерёнки (Clock*/Gear*): быстрее в бурю и во время способностей
	local spinRates = rig.SpinRates
	local spinDt = 0
	local spinAngle
	if spinRates then
		spinDt = clamp(t - (rig.SpinT or t), 0, 0.1)
		rig.SpinT = t
		spinAngle = rig.SpinAngle
		if not spinAngle then
			spinAngle = {}
			rig.SpinAngle = spinAngle
		end
		local boost = rig.Storm and 3 or 1
		if os.clock() < (rig.SpinBoostUntil or 0) then
			boost = math.max(boost, 6)
		end
		spinDt *= boost
	end

	local kinds = kindsOf(rig)
	local kindOf, sideOf = kinds.Kind, kinds.Side
	local armX, armZ = rad(breathe * 2), rad(breathe * 1.5)
	local wing = sin(t * 2.4 + phase)
	local neckYaw = sin(t * 0.7 + phase) * 0.08
	local gust = rig.Gust or 0
	local capeX = rad(6 + sin(t * 1.7 + phase) * 4 + gust * 22)
	local capeZ = rad(sin(t * 1.1 + phase) * 3)
	local cape2X = rad(5 + sin(t * 1.7 + phase - 0.8) * 7 + gust * 28)
	local cape2Z = rad(sin(t * 1.1 + phase - 0.6) * 5)
	local orbitY = t * 1.4 + phase

	for name, motor in pairs(motors) do
		local b = base[name]
		if b then
			local kind = kindOf[name]
			if kind == nil then
				local side
				kind, side = classify(name)
				kindOf[name], sideOf[name] = kind, side
			end
			local p = pose[name]
			local cf = b
			if name == "Root" then
				-- дыхание корпуса всегда, даже без позы
				cf = b * CF(0, ((p and p[4]) or 0) * s + breathe * 0.04 * s, 0)
			end
			if p then
				cf = cf * ANG(rad(p[1] or 0), rad(p[2] or 0), rad(p[3] or 0))
			end
			if kind == K_ARM then
				cf = cf * ANG(armX, 0, armZ * sideOf[name])
			elseif kind == K_WING then
				local side = sideOf[name]
				cf = cf * ANG(0, wing * 0.12 * side, wing * 0.1 * side)
			elseif kind == K_NECK then
				cf = cf * ANG(0, neckYaw, 0)
			elseif kind == K_CAPE then
				cf = cf * ANG(capeX, 0, capeZ)
			elseif kind == K_CAPE2 then
				-- нижняя часть плаща догоняет верхнюю с запаздыванием
				cf = cf * ANG(cape2X, 0, cape2Z)
			elseif kind == K_ORBIT then
				cf = cf * ANG(0, orbitY, 0)
			elseif spinRates then
				local rate = spinRates[name]
				if rate then
					-- накопленный угол: минус = по часовой
					local ang = (spinAngle[name] or 0) - rate * spinDt
					spinAngle[name] = ang
					cf = cf * ANG(0, 0, ang)
				end
			end
			motor.C0 = cf
		end
	end
end

function Anims.Step(state, t)
	Anims.Apply(state.Rig, Anims.Eval(state, t), t, state.Phase or 0)
end

-- Anims.Slash и т.п. — как в легаси-таблице Anims
setmetatable(Anims, {
	__index = function(_, k)
		return Clips[k]
	end,
})

return Anims
