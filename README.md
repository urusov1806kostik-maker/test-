# ✦ ShadowSMP — сервер Spigot 1.21.11

Всё в одном плагине **ShadowSMP.jar** + LuckPerms, EssentialsX, FlectonePulse.

![Текстуры](resourcepack/preview.png)

## Что внутри

| Папка | Что это |
|---|---|
| `server/` | Готовый сервер: загрузить на Falix как есть |
| `server/plugins/` | ShadowSMP, LuckPerms, EssentialsX, FlectonePulse |
| `plugin/` | Исходники плагина (Java 21, Maven) |
| `resourcepack/ShadowSMP-pack.zip` | Ресурспак (текстуры талисманов, оружия, иконок) |
| `tools/build_resourcepack.py` | Генератор текстур и ресурспака |

## Установка на Falix

1. Создай сервер → тип **Spigot**, версия **1.21.11**.
2. Во вкладке **Files** загрузи всё из папки `server/` (`plugins/`, `server.properties`, `server-icon.png`).
3. **Ресурспак.** Нужна прямая ссылка на `ShadowSMP-pack.zip`:
   - проще всего: залей zip на **mc-packs.net** и скопируй ссылку на скачивание;
   - или сделай репозиторий публичным: тогда сработает ссылка из конфига по умолчанию.
   Вставь ссылку в `plugins/ShadowSMP/config.yml` → `resource-pack.url`, затем выполни `/ss reload`.
   Если ссылка не открывается, игроков **не кикает** (иначе на сервер не зашёл бы никто), а в консоли будет предупреждение.
4. Запусти сервер. Через 5 секунд плагин сам создаст группы LuckPerms с префиксами.
5. Выдай себе права из консоли: `lp user <ник> parent add owner`.
6. Зайди на сервер, встань на ровное место и выполни `/buildspawn confirm`. Плагин построит спавн, поставит голограммы и 4 NPC.

`online-mode=false`, поэтому включены `/register` и `/login`. Если сервер только для лицензии, поставь `online-mode=true` и `auth.enabled: false`.

## Модули и команды

**Талисманы** (6 штук, держать в левой руке). Демона, Льда, Бури, Тени, Жизни, Океана.
`/talisman list`, `/talisman give <игрок> <id>`. Крафты смотри в `/crafts`.

**Кастом-оружие**: Клинок Тени, Ледяное Жало, Адский Топор, Кирка Пустоты.
Своё оружие добавляется в `items.yml`: материал, текстура (`model`), атрибуты, эффекты для того, кто бьёт (`on-hit`), и для того, кого бьют (`on-damaged`), а также молния, вампиризм, уклонение и шипы.
`/citem list`, `/citem give <игрок> <id> [кол-во]`.

**Кастом-зачарования** (15): Вампиризм, Иссушение, Яд, Заморозка, Громовержец, Обезглавливание, Бур 3x3, Автоплавка, Телепатия, Мудрость, Отражение, Уклонение, Ветер, Ночное зрение, Живучесть.
`/ce list`, `/ce apply <id> <ур>`, `/ce book <игрок> <id> <ур>`. Книгу накладывают через наковальню.

**Кастом-крафты** (`crafts.yml`): верстак (shaped/shapeless), печь, плавильня, коптильня, костёр, камнерез, кузнечный стол, наковальня. Просмотр: `/crafts`.

**Экономика**: Монеты (обычная валюта) и ShadowCoin (донатная).
`/money`, `/mpay <ник> <сумма> [coins|shadow]`, `/mtop [coins|shadow]`, `/seco give|take|set <ник> <coins|shadow> <сумма>`, `/shop`.

**Ивенты** (авто каждые 30 мин): chat, math, hunt, boss, treasure, drop.
`/event`, `/event start <тип>`, `/event stop`, `/event setboss`.

**NPC** (Mannequin со скином игрока или любой моб):
`/npc create <id> [тип]`, `/npc skin <id> <ник>`, `/npc name|desc <id> <текст>`, `/npc action <id> add [player] spawn`, `/npc remove <id>`.

**Кастом-команды** (`commands.yml` или прямо в игре): можно объединить несколько команд в одну.
`/ccmd create hf [console] heal {player}`, затем `/ccmd add hf [console] feed {player}`.
Уже готовы: `/rules`, `/discord`, `/hf`, `/daily`, `/starter`, `/boost`, `/info`.

**TAB и скорборд** с анимированным заголовком ShadowSMP, рангом, балансом, K/D и временем в игре. `/sb` скрывает скорборд. Настройки в `config.yml`.

**Спавн**: `/spawn`, `/setspawn`, `/buildspawn confirm`. Защита радиусом 40 блоков: нельзя ломать блоки и получать урон.

**Логин**: `/register <пароль> <пароль>`, `/login <пароль>`, `/changepassword`, `/logout`, `/unregister <ник>` (админ). Есть сессия по IP на 30 минут.

**Права LuckPerms**: группы default, vip, premium, shadow, helper, moder, admin, owner. Админ-права ShadowSMP: `shadowsmp.admin`.

`/ss reload` перезагружает все конфиги.

## Сборка

```bash
cd plugin && mvn package                 # -> plugin/target/ShadowSMP.jar
python3 tools/build_resourcepack.py      # -> resourcepack/ShadowSMP-pack.zip
```
