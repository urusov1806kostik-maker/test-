#!/usr/bin/env python3
"""Собирает src/ в один Luau-скрипт для Command Bar Roblox Studio.

Запуск:  python3 tools/build_installer.py
Результат: build/VoidTD_Installer.lua (читаемый) и build/VoidTD_Installer_Compact.lua (меньше размером)
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "src"
OUT = ROOT / "build" / "VoidTD_Installer.lua"

# (путь к файлу, сервис, путь внутри сервиса, класс)
ENTRIES = [
    ("ReplicatedStorage/VoidTD/Config.lua", "ReplicatedStorage", ["VoidTD", "Config"], "ModuleScript"),
    ("ReplicatedStorage/VoidTD/PathUtil.lua", "ReplicatedStorage", ["VoidTD", "PathUtil"], "ModuleScript"),
    ("ReplicatedStorage/VoidTD/UnitModels.lua", "ReplicatedStorage", ["VoidTD", "UnitModels"], "ModuleScript"),
    ("ReplicatedStorage/VoidTD/EnemyModels.lua", "ReplicatedStorage", ["VoidTD", "EnemyModels"], "ModuleScript"),
    ("ReplicatedStorage/VoidTD/CaseModels.lua", "ReplicatedStorage", ["VoidTD", "CaseModels"], "ModuleScript"),
    ("ServerScriptService/VoidTDServer/init.server.lua", "ServerScriptService", ["VoidTDServer"], "Script"),
    ("ServerScriptService/VoidTDServer/MapBuilder.lua", "ServerScriptService", ["VoidTDServer", "MapBuilder"], "ModuleScript"),
    ("ServerScriptService/VoidTDServer/DataService.lua", "ServerScriptService", ["VoidTDServer", "DataService"], "ModuleScript"),
    ("ServerScriptService/VoidTDServer/GameService.lua", "ServerScriptService", ["VoidTDServer", "GameService"], "ModuleScript"),
    ("StarterPlayerScripts/VoidTDClient/init.client.lua", "StarterPlayerScripts", ["VoidTDClient"], "LocalScript"),
    ("StarterPlayerScripts/VoidTDClient/FX.lua", "StarterPlayerScripts", ["VoidTDClient", "FX"], "ModuleScript"),
    ("StarterPlayerScripts/VoidTDClient/Renderer.lua", "StarterPlayerScripts", ["VoidTDClient", "Renderer"], "ModuleScript"),
    ("StarterPlayerScripts/VoidTDClient/UI.lua", "StarterPlayerScripts", ["VoidTDClient", "UI"], "ModuleScript"),
    ("StarterPlayerScripts/VoidTDClient/Placement.lua", "StarterPlayerScripts", ["VoidTDClient", "Placement"], "ModuleScript"),
]

LEVEL = "=" * 6
OPEN, CLOSE = f"[{LEVEL}[", f"]{LEVEL}]"

HEADER = """-- =====================================================================
--  VOID TD — установщик для Command Bar (Roblox Studio)
--  1) View -> Command Bar   2) вставь ВЕСЬ этот файл   3) Enter
--  Затем File -> Save и нажми Play.
--  Файл собран автоматически из src/ (tools/build_installer.py). Не редактируй вручную.
-- =====================================================================
local REMOVE_DEFAULT_BASEPLATE = true -- убрать стандартный Baseplate/SpawnLocation шаблона

local RS = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")
local SPS = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")
local SERVICES = { ReplicatedStorage = RS, ServerScriptService = SSS, StarterPlayerScripts = SPS }

-- удалить предыдущую установку
for _, pair in ipairs({ { RS, "VoidTD" }, { SSS, "VoidTDServer" }, { SPS, "VoidTDClient" }, { workspace, "VoidTDMap" }, { workspace, "VoidTDLobby" } }) do
	local obj = pair[1]:FindFirstChild(pair[2])
	if obj then obj:Destroy() end
end
if REMOVE_DEFAULT_BASEPLATE then
	local bp = workspace:FindFirstChild("Baseplate")
	if bp and bp:IsA("BasePart") then bp:Destroy() end
	local sp = workspace:FindFirstChild("SpawnLocation")
	if sp and sp:IsA("SpawnLocation") then sp:Destroy() end
end
pcall(function() workspace.StreamingEnabled = false end)

local function ensure(parent, name, className)
	local obj = parent:FindFirstChild(name)
	if not obj then
		obj = Instance.new(className)
		obj.Name = name
		obj.Parent = parent
	end
	return obj
end

local function install(service, path, className, source)
	local parent = SERVICES[service]
	for i = 1, #path - 1 do
		parent = ensure(parent, path[i], "Folder")
	end
	local name = path[#path]
	local obj = parent:FindFirstChild(name)
	if obj and obj.ClassName ~= className then
		-- папка-заглушка, созданная для детей: заменяем на скрипт и переносим детей
		local real = Instance.new(className)
		real.Name = name
		for _, child in ipairs(obj:GetChildren()) do child.Parent = real end
		obj:Destroy()
		real.Parent = parent
		obj = real
	elseif not obj then
		obj = Instance.new(className)
		obj.Name = name
		obj.Parent = parent
	end
	obj.Source = source
	return obj
end

local FILES = {}
"""

FOOTER = """
for _, f in ipairs(FILES) do
	install(f[1], f[2], f[3], f[4])
end

-- построить карту прямо в редакторе (чтобы её было видно до запуска)
local ok, err = pcall(function()
	local MapBuilder = require(SSS.VoidTDServer.MapBuilder)
	MapBuilder.Build()
end)
if not ok then
	warn("[VOID TD] Карта будет построена при запуске игры: " .. tostring(err))
end

print("[VOID TD] Установка завершена! Сохрани место (Ctrl+S) и нажми Play.")
print("[VOID TD] Для сохранения гемов: Game Settings -> Security -> Enable Studio Access to API Services.")
"""


def lua_list(items):
    return "{ " + ", ".join(f'"{x}"' for x in items) + " }"


def build(out_path, entries, header, footer):
    parts = [header]
    for rel, service, path, cls in entries:
        src = (SRC / rel).read_text(encoding="utf-8")
        if CLOSE in src:
            raise SystemExit(f"{rel} содержит {CLOSE} — увеличь LEVEL")
        parts.append(f"FILES[#FILES + 1] = {{ \"{service}\", {lua_list(path)}, \"{cls}\", {OPEN}\n{src}{CLOSE} }}\n")
    parts.append(footer)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text("".join(parts), encoding="utf-8")
    print(f"OK: {out_path.relative_to(ROOT)} ({out_path.stat().st_size // 1024} KB)")


def main():
    build(OUT, ENTRIES, HEADER, FOOTER)
    # запасной вариант: 3 части поменьше, вставлять по очереди 1 -> 2 -> 3
    groups = [
        ("1_Shared", "ReplicatedStorage", "VoidTD"),
        ("2_Server", "ServerScriptService", "VoidTDServer"),
        ("3_Client", "StarterPlayerScripts", "VoidTDClient"),
    ]
    common = HEADER[HEADER.index("local function ensure"):]
    for i, (name, service, root) in enumerate(groups):
        head = (
            f"-- VOID TD — установщик, часть {i + 1}/3 ({name}). Вставляй части по порядку 1 -> 2 -> 3.\n"
            "local RS = game:GetService(\"ReplicatedStorage\")\n"
            "local SSS = game:GetService(\"ServerScriptService\")\n"
            "local SPS = game:GetService(\"StarterPlayer\"):WaitForChild(\"StarterPlayerScripts\")\n"
            "local SERVICES = { ReplicatedStorage = RS, ServerScriptService = SSS, StarterPlayerScripts = SPS }\n"
            f"local old = SERVICES[\"{service}\"]:FindFirstChild(\"{root}\")\n"
            "if old then old:Destroy() end\n"
        )
        if i == 0:
            head += (
                "local bp = workspace:FindFirstChild(\"Baseplate\")\n"
                "if bp and bp:IsA(\"BasePart\") then bp:Destroy() end\n"
                "local sp = workspace:FindFirstChild(\"SpawnLocation\")\n"
                "if sp and sp:IsA(\"SpawnLocation\") then sp:Destroy() end\n"
                "pcall(function() workspace.StreamingEnabled = false end)\n"
            )
        foot = "\nfor _, f in ipairs(FILES) do\n\tinstall(f[1], f[2], f[3], f[4])\nend\n"
        if i == 1:
            foot += (
                "for _, n in ipairs({ \"VoidTDMap\", \"VoidTDLobby\" }) do\n"
                "\tlocal oldMap = workspace:FindFirstChild(n)\n"
                "\tif oldMap then oldMap:Destroy() end\n"
                "end\n"
                "local ok, err = pcall(function() require(SSS.VoidTDServer.MapBuilder).Build() end)\n"
                "if not ok then warn(\"[VOID TD] Карта построится при запуске: \" .. tostring(err)) end\n"
            )
        foot += f"print(\"[VOID TD] Часть {i + 1}/3 установлена\" .. ({i} == 2 and \". Готово! Сохрани место и нажми Play.\" or \". Вставь следующую часть.\"))\n"
        entries = [e for e in ENTRIES if e[1] == service]
        build(OUT.parent / "parts" / f"VoidTD_Part{name}.lua", entries, head + common, foot)


if __name__ == "__main__":
    main()
