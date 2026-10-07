# Shadow Visuals — состояние проекта

Ветка: `claude/modest-davinci-s2z7ta` (запушено). Fabric 1.21.11, Mojang mappings, Loom 1.18 (`net.fabricmc.fabric-loom-remap`), Fabric API 0.141.6+1.21.11, Loader 0.19.5.

## Окружение (важно)
- Сборка только на JDK 25: `export JAVA_HOME=/usr/lib/jvm/java-25-openjdk-amd64`.
- `~/.gradle/init.gradle` перенаправляет Maven Central на зеркало Google (иначе 429). Только локально, не в репо.
- Компиляция: `./gradlew --no-daemon -q compileJava`; тесты: `./gradlew --no-daemon -q test` (29 юнит-тестов, проходят).
- Живой тест: `xvfb-run -a -s "-screen 0 1920x1080x24" ./gradlew --no-daemon runClientGameTest`; скриншоты в `build/run/clientGameTest/screenshots/`.
- Исходники MC 1.21.11: `/home/user/ref/mc`, Fabric API: `/home/user/ref/fabric`.
- Переводы: scratchpad `.../scratchpad/i18n/` (`*.py` — dict `T` key:(en,ru); `uk_ua.txt` — key=uk); `python3 gen.py` пишет en_us/ru_ru/uk_ua.json и сообщает о недостающих uk-ключах.
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
- Всё из ТЗ реализовано. 31 юнит-тест + полный gametest зелёные: GUI, HUD, смерть/респавн/точка смерти, Незер, fullscreen, GUI scale, reload, второй мир, выделенный сервер (вход, Tab, переподключение), бинды предметов FunTime.
- Языки: en, ru, uk (тест сверяет ключи всех языков).
- Модуль FunTime «Item Binds» (`modules/funtime/ItemBinds.java`): 5 KeybindSetting (Дезориентация, Пласт, Трапка, Явная пыль, Огненный смерч), по умолчанию NONE; поиск по названию (настраивается), хотбар → левая рука → инвентарь (SWAP), слот возвращается.
- Категория Player: JumpCircle, Trails, HitParticles, HitSound, HitColor, ViewModel, SwingAnimation (пакет `modules/player`).

- Иконка мода (S), README, CI GitHub Actions (`.github/workflows/build.yml`: build + юнит-тесты, артефакт jar) — зелёный.
- `util/Numbers` вместо String.format в HUD (32 юнит-теста).

## Осталось
- Ничего обязательного. Дальше — по запросам пользователя.

## Решения
- Mojang mappings; всё 2D через `Renderer2D` (retained GuiElementRenderState), без прямого GL.
- Модули слушают события только когда включены; ошибка листенера отключает только модуль.
- HUD-позиции = anchor+offset (internal настройки), в профиле.
- Глобальные настройки — `client.json`; модули/тема/HUD — `profiles/<name>.json`.
- Кулдауны только из надёжных клиентских данных (ItemCooldowns через AW).
- RShift открывает GUI только без экрана или на TitleScreen; событие клавиши отменяется.
- Ключ мира в одиночной игре = имя папки сохранения (не отображаемое имя), чтобы метки не смешивались.
