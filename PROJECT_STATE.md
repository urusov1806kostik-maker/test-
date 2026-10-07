# Shadow Visuals — состояние проекта

Ветка: `claude/modest-davinci-s2z7ta`. Fabric 1.21.11, Mojang mappings, Loom 1.18 (`net.fabricmc.fabric-loom-remap`), Fabric API 0.141.6+1.21.11, Loader 0.19.5.

## Окружение (важно)
- Сборка только на JDK 25: `export JAVA_HOME=/usr/lib/jvm/java-25-openjdk-amd64`.
- `~/.gradle/init.gradle` перенаправляет Maven Central на зеркало Google (иначе 429). Только локально, не в репо.
- Компиляция: `./gradlew --no-daemon -q compileJava`; тесты: `./gradlew --no-daemon -q test` (29 юнит-тестов).
- Живой тест игры: `xvfb-run -a -s "-screen 0 1920x1080x24" ./gradlew --no-daemon runClientGameTest`; скриншоты в `build/run/clientGameTest/screenshots/`. Тест: `src/gametest/java/.../ShadowVisualsClientGameTest.java`.
- Справочные исходники MC 1.21.11: `/home/user/ref/mc` (декомпиляция), Fabric API: `/home/user/ref/fabric`.
- Переводы генерирует скрипт `/tmp/claude-0/-home-user-test-/5800afb5-2051-5105-9735-544187b892fd/scratchpad/i18n/` (`base.py` = словарь key:(en,ru), `gen.py` пишет `assets/shadowvisuals/i18n/{en_us,ru_ru}.json`). Новые ключи добавлять туда (можно новым файлом `*.py` с dict `T`) и запускать `python3 gen.py`.

## Готово
- Ядро: EventBus (fail-safe), Module/ModuleManager (биндов toggle/hold, избранное, поиск, JSON), Setting system (все типы + group/visibility/internal), ConfigManager (debounce, атомарная запись, backup битых, миграции), ProfileManager, Localization (en/ru, uk через JSON), Friends, Waypoints, Notifications, AnimationClock/Animation/SmoothValue, ColorUtil, ThemeManager (5 пресетов), DesignTokens, ClientSettings.
- Рендер: `Renderer2D` (SDF-шейдер `ui_shape` для скруглений/обводок/теней/градиентов, fallback на vanilla fill), SDF-шрифт Inter через FreeType (`render/font`), полигоны, `WorldRenderer3D`, `WorldProjection` (матрицы из LevelRendererMixin), ShadowPipelines (ленивая валидация после загрузки ресурсов).
- UI: компоненты (Toggle, Button, Slider, RangeSlider, Dropdown/ListOverlay, ColorSwatch/ColorPickerOverlay, TextField, KeybindSelector, ScrollPanel, Tabs, ContextMenu, Dialog, Tooltip), SettingRow/SettingsList, ClickGUI (Sidebar, ModulesPage, ModuleCard, ModuleSettingsPanel, ConfigPage, SettingsPage, ProfileBadge/Popover), HudEditorScreen, ShadowScreen (масштаб, анимации, маршрутизация ввода), иконки `ui/Icon`.
- HUD: HudModule/PanelHudModule/InfoHudModule, HudManager, NotificationRenderer. Модули: Watermark, ActiveModules, Keybinds, FPS, Ping, Coordinates, Speed(BPS), PotionEffects, Armor, Inventory, ItemCounter (универсальный).
- Миксины: KeyboardHandler, MouseHandler, GameRenderer (кадр), LevelRenderer (матрицы). Access widener для ItemCooldowns.
- Живой запуск проверен: ClickGUI/настройки рендерятся корректно (скриншоты ок).

## Сейчас
- Дописываю HUD: TargetHud, SessionInfoHud, CompassHud, ServerInfoHud, CooldownHud (через AW `ItemCooldowns.cooldowns/tickCount`), система предупреждений (low health, durability, missing item, cooldown ready).
- Затем регистрация всех HUD-модулей в `modules/ModuleCatalog.java` (сейчас там только RecordingMode) и ключи перевода `hud.label.*`, `module.<id>.name/description`, настройки.

## Осталось
- Визуальные модули: Player ESP, Name Tags, Item ESP, Container Visuals, FullBright, Time Changer, Weather, Fog, Jump Circle, Trails, Hit Particles/Color/Sound, Crosshair, Hotbar, Tooltips, View Model, Swing, Zoom, FreeLook, Camera (3rd person distance, hurt cam, bobbing, FOV), Scoreboard, Tab, Boss Bar, Chat, Block Overlay/Selection, Glint color, World/Sky/Ambient color, Particles, Fire overlay, Overlay control, Waypoints render, Death Point.
- Замена vanilla HUD через `HudElementRegistry.replaceElement` (hotbar, crosshair, scoreboard, boss bar, tab, status effects).
- FunTime Helper: счётчики, кулдауны, предупреждения, подсветка.
- uk_ua перевод (опционально), полировка, ревизия утечек, финальный gametest, push.
- Известно: второй мир в gametest упирается в таймаут загрузки под llvmpipe (окружение медленное) — добавить ожидание.

## Решения
- Mojang mappings (как в официальном example 1.21.11; Yarn после 1.21.11 не развивается).
- Всё 2D только через `Renderer2D` (retained GuiElementRenderState), без прямого GL.
- Модули подписываются на события только когда включены; падение листенера отключает только этот модуль.
- HUD-позиции = anchor+offset внутри настроек модуля (internal), сохраняются в профиле.
- Клиентские настройки глобальные (`client.json`), модули/тема/HUD — в профиле (`profiles/<name>.json`).
- Без `cd` в bash (сбивает cwd) — использовать абсолютные пути.
