# Shadow Visuals — состояние проекта

Ветка: `claude/modest-davinci-s2z7ta` (запушено). Fabric 1.21.11, Mojang mappings, Loom 1.18 (`net.fabricmc.fabric-loom-remap`), Fabric API 0.141.6+1.21.11, Loader 0.19.5.

## Окружение (важно)
- Сборка только на JDK 25: `export JAVA_HOME=/usr/lib/jvm/java-25-openjdk-amd64`.
- `~/.gradle/init.gradle` перенаправляет Maven Central на зеркало Google (иначе 429). Только локально, не в репо.
- Компиляция: `./gradlew --no-daemon -q compileJava`; тесты: `./gradlew --no-daemon -q test` (29 юнит-тестов, проходят).
- Живой тест: `xvfb-run -a -s "-screen 0 1920x1080x24" ./gradlew --no-daemon runClientGameTest`; скриншоты в `build/run/clientGameTest/screenshots/`.
- Исходники MC 1.21.11: `/home/user/ref/mc`, Fabric API: `/home/user/ref/fabric`.
- Переводы: scratchpad `.../scratchpad/i18n/` (`base.py`, `hud.py`, `modules1.py` — dict `T` key:(en,ru)); `python3 gen.py` пишет `assets/shadowvisuals/i18n/{en_us,ru_ru}.json`. Новые ключи — новым `*.py`.
- `shadowvisuals.mixins.json` (client) перегенерировать из файлов `dev/shadowvisuals/mixin/*.java`.
- Без `cd` в bash — абсолютные пути.

## Готово
- Ядро: EventBus, Module/ModuleManager, Settings (все типы), ConfigManager (debounce, бэкапы, миграции), ProfileManager, ClientPreferences, Localization (en/ru, uk готов архитектурно), Friends, Waypoints, Notifications, анимации, ThemeManager (5 пресетов), CombatTracker, UiSounds.
- Рендер: Renderer2D (SDF шейдеры), SDF-шрифт Inter (FreeType), полигоны, WorldRenderer3D, WorldProjection, ShadowPipelines.
- UI: все компоненты, оверлеи, ClickGUI (все страницы), HudEditor, ScreenManager.
- HUD: Watermark, ActiveModules, Keybinds, FPS, Ping, Coordinates, BPS, Compass, PotionEffects, Armor, Inventory, ItemCounter, TargetHud, SessionInfo, ServerInfo; FunTime: CooldownHud, WarningsHud; NotificationRenderer; VanillaHudOverrides.
- Модули: RecordingMode; visual: FullBright, HitColor, ViewModel, SwingAnimation, FireOverlay, OverlayControl, ParticleModifier; world: TimeChanger, WeatherControl, FogControl, WorldColor, SkyColor, AmbientColor; camera: Zoom, FreeLook, CameraSettings, HurtCamera, ViewBobbing, FovControl; iface: CustomCrosshair/Hotbar/Scoreboard/Tab/BossBar, ChatVisuals, CustomTooltips.
- Все миксины для этого написаны и применяются без ошибок. Gametest со скриншотами работает.

## Сейчас
- Всё из ТЗ реализовано, компилируется, 29 юнит-тестов и полный gametest проходят (оба мира грузятся; в тесте FPS-лимит 30 и дальность 4 — иначе llvmpipe душит сервер).
- Запушено в `claude/modest-davinci-s2z7ta`.

## Осталось (опционально)
- uk_ua перевод (архитектура готова: новый JSON + константа уже есть).
- Дальнейшая полировка по отзывам.

## Решения
- Mojang mappings; всё 2D через `Renderer2D` (retained GuiElementRenderState), без прямого GL.
- Модули слушают события только когда включены; ошибка листенера отключает только модуль.
- HUD-позиции = anchor+offset (internal настройки), в профиле.
- Глобальные настройки — `client.json`; модули/тема/HUD — `profiles/<name>.json`.
- Кулдауны только из надёжных клиентских данных (ItemCooldowns через AW).
- RShift открывает GUI только без экрана или на TitleScreen; событие клавиши отменяется.
- Ключ мира в одиночной игре = имя папки сохранения (не отображаемое имя), чтобы метки не смешивались.
