# VOID TD

Tower Defense для Roblox в стиле классических блочных TD: Пустота, тёмная магия, фиолетовый неон.
Всё — модели, карта, эффекты, UI — создаётся кодом, без внешних ассетов.

## Установка (Command Bar)

1. Открой новое место в Roblox Studio (шаблон Baseplate подойдёт — стандартный Baseplate удалится сам).
2. **View → Command Bar**.
3. Скопируй **весь** файл [`build/VoidTD_Installer.lua`](build/VoidTD_Installer.lua), вставь в Command Bar, нажми Enter.
4. В Output появится `[VOID TD] Установка завершена!`, а в Workspace — карта.
5. **Ctrl+S**, затем **Play**.

Если Command Bar не принимает большой файл — вставь по очереди три части из `build/parts/` (1 → 2 → 3).

Чтобы гемы и юниты сохранялись между запусками: *Game Settings → Security → Enable Studio Access to API Services*.
Без этого игра работает, но профиль каждый раз стартовый.

Альтернатива для Rojo: `rojo serve` (файл `default.project.json`).

## Управление

| Действие | Клавиша |
|---|---|
| Выбрать юнита из хотбара | `1`–`6` или клик по слоту |
| Поставить | ЛКМ (с `Shift` — поставить несколько) |
| Повернуть | `R` |
| Отмена | `Q` / ПКМ / `Esc` |
| Выбрать поставленного юнита | клик по нему |
| Улучшить / продать / сменить цель | `E` / `X` / `T` (или кнопки на панели) |

На телефоне: тап по земле двигает призрак, внизу кнопки PLACE / ROTATE / CANCEL.

## Что внутри

- **11 юнитов, 5 редкостей** (Common 3, Rare 2, Epic 2, Legendary 2, Mythic 2), у каждого 5 уровней — модель меняется на каждом уровне.
- **Типы атак:** Melee, Projectile, Laser, AOE, Multi-Hit, Damage over Time (чёрная дыра).
- **Способности:** Eclipse Shockwave (настоящий AOE, каждый враг получает урон один раз за удар), Fallen Beam, Void Judgement, Black Hole (замедление + периодический урон, своя перезарядка).
- **Цели:** First / Last / Strongest / Weakest / Closest.
- **9 врагов** с броней, уклонением, разными размерами и наградами; боссы на 10, 20 и 30 волне (The Entity призывает миньонов).
- **30 волн**, таймер между волнами, кнопка Start Wave, победа/поражение и авторестарт.
- **Summon** (x1 / x10 с гарантией Rare+), **инвентарь**, **экипировка** 6 слотов, сохранение в DataStore.
- **Карта The Forgotten Realm:** парящий остров, извилистая дорога, портал, ядро, кристаллы, руины, колонны, деревья, парящие островки, туман и освещение.
- Вся логика урона — на сервере. Клиент только рисует: модели, анимации (Motor6D), эффекты, полоски HP.

## Баланс

Все цифры — в [`src/ReplicatedStorage/VoidTD/Config.lua`](src/ReplicatedStorage/VoidTD/Config.lua):
урон/дальность/перезарядка/цены по уровням, враги, состав волн, деньги, шансы Summon.
Быстрая ручка сложности — `Settings.EnemyHealthMult` (0.8 — легче, 1.3 — сложнее).

Симуляция ботом (средняя игра, без микроконтроля): состав с Legendary + Mythic проходит 30 волн,
только Common-юниты доходят примерно до 24-й.

После правок в `src/` пересобери установщик: `python3 tools/build_installer.py`.

## Структура

```
src/ReplicatedStorage/VoidTD/      Config, PathUtil, UnitModels, EnemyModels  (общие модули)
src/ServerScriptService/VoidTDServer/  init.server.lua, GameService, DataService, MapBuilder
src/StarterPlayerScripts/VoidTDClient/ init.client.lua, Renderer, FX, UI, Placement
tools/build_installer.py           сборка установщика для Command Bar
build/                             готовые установщики
tests/                             мок Roblox API + прогон сервера (30 волн) и клиента в Luau CLI
```
