#!/usr/bin/env python3
"""Сборка VOID TD: src/ (Rojo-стиль) -> build/VoidTD.rbxlx + tests/_bundle.luau.

Соглашение (SPEC §1):
  src/<Service>/...       верхняя папка = сервис: ReplicatedStorage, ServerScriptService,
                          StarterPlayerScripts (-> StarterPlayer.StarterPlayerScripts)
  папка                   -> Folder, ЕСЛИ в ней нет init.lua / init.server.lua / init.client.lua;
                          иначе сама папка = ModuleScript / Script / LocalScript, остальное — её дети
  Name.lua                -> ModuleScript, Name.server.lua -> Script, Name.client.lua -> LocalScript
  (.luau тоже принимается)

Запуск:  python3 tools/build.py [--src DIR] [--rbxlx FILE] [--bundle FILE] [--fixtures DIR]
Вывод детерминированный (сортировка по имени, referent = md5 пути).
"""
import argparse
import hashlib
import re
import sys
from pathlib import Path
from xml.sax.saxutils import escape

ROOT = Path(__file__).resolve().parent.parent

# папка в src -> путь в месте (цепочка сервисов)
SERVICES = {
    "ReplicatedStorage": ["ReplicatedStorage"],
    "ServerScriptService": ["ServerScriptService"],
    "StarterPlayerScripts": ["StarterPlayer", "StarterPlayerScripts"],
}
SERVICE_ORDER = ["ReplicatedStorage", "ServerScriptService", "StarterPlayerScripts"]

SCRIPT_SUFFIXES = [  # (суффикс, класс) — длинные раньше коротких
    (".server.luau", "Script"), (".client.luau", "LocalScript"), (".luau", "ModuleScript"),
    (".server.lua", "Script"), (".client.lua", "LocalScript"), (".lua", "ModuleScript"),
]
# запрещённые в XML 1.0 символы (CDATA их тоже не пропускает)
BAD_XML = re.compile("[\x00-\x08\x0b\x0c\x0e-\x1f￾￿]")

problems = []
warnings = []


class Node:
    def __init__(self, name, cls, path, source=None, file=None):
        self.name, self.cls, self.path = name, cls, path  # path: "ReplicatedStorage/VoidTD/Config"
        self.source, self.file = source, file
        self.children = []


def script_kind(filename):
    for suffix, cls in SCRIPT_SUFFIXES:
        if filename.endswith(suffix) and len(filename) > len(suffix):
            return filename[: -len(suffix)], cls
    return None, None


def read_source(file, root):
    rel = file.relative_to(root).as_posix()
    raw = file.read_bytes()
    try:
        text = raw.decode("utf-8")
    except UnicodeDecodeError as e:
        problems.append(f"{rel}: не UTF-8 ({e})")
        return ""
    if text.startswith("﻿"):
        warnings.append(f"{rel}: убран BOM")
        text = text[1:]
    if "\r" in text:
        warnings.append(f"{rel}: CRLF/CR заменены на LF")
        text = text.replace("\r\n", "\n").replace("\r", "\n")
    m = BAD_XML.search(text)
    if m:
        line = text.count("\n", 0, m.start()) + 1
        problems.append(f"{rel}:{line}: недопустимый управляющий символ U+{ord(m.group()):04X}")
    return text


def skip(p):
    return p.name.startswith(".") or p.name.endswith("~") or p.name == "__pycache__"


def walk_dir(directory, path, root):
    """Возвращает Node для папки directory (Folder или скрипт с init.*)."""
    entries = sorted([p for p in directory.iterdir() if not skip(p)], key=lambda p: (p.name.lower(), p.name))
    inits = [p for p in entries if p.is_file() and script_kind(p.name)[0] == "init"]
    if len(inits) > 1:
        problems.append(f"{directory.relative_to(root).as_posix()}: несколько init-файлов: {', '.join(p.name for p in inits)}")
    if inits:
        _, cls = script_kind(inits[0].name)
        node = Node(directory.name, cls, path, read_source(inits[0], root), inits[0].relative_to(root).as_posix())
    else:
        node = Node(directory.name, "Folder", path)
    seen = {}
    for p in entries:
        if p in inits:
            continue
        if p.is_dir():
            child = walk_dir(p, f"{path}/{p.name}", root)
        else:
            name, cls = script_kind(p.name)
            if not name:
                warnings.append(f"{p.relative_to(root).as_posix()}: не скрипт — пропущен")
                continue
            child = Node(name, cls, f"{path}/{name}", read_source(p, root), p.relative_to(root).as_posix())
        if child.name in seen:
            problems.append(f"{directory.relative_to(root).as_posix()}: имя '{child.name}' занято дважды ({seen[child.name]} и {p.name})")
            continue
        seen[child.name] = p.name
        node.children.append(child)
    return node


def collect(src):
    """Сервисы -> списки корневых узлов."""
    roots = {}
    if not src.is_dir():
        problems.append(f"нет папки {src}")
        return roots
    for p in sorted(src.iterdir(), key=lambda p: p.name):
        if skip(p):
            continue
        if not p.is_dir() or p.name not in SERVICES:
            problems.append(f"src/{p.name}: неизвестный сервис (ожидаются {', '.join(SERVICE_ORDER)})")
            continue
        top = walk_dir(p, p.name, src)
        if top.cls != "Folder":
            problems.append(f"src/{p.name}: сервис не может быть скриптом (init-файл в корне сервиса)")
            continue
        roots[p.name] = top.children
    return roots


def iter_nodes(nodes):
    for n in nodes:
        yield n
        yield from iter_nodes(n.children)


# ---------------------------------------------------------------- rbxlx
def referent(path):
    return "RBX" + hashlib.md5(path.encode("utf-8")).hexdigest().upper()


def cdata(text):
    return "<![CDATA[" + text.replace("]]>", "]]]]><![CDATA[>") + "]]>"


def xml_item(out, cls, ref, name, depth, extra=(), children=()):
    t = "\t" * depth
    out.append(f'{t}<Item class="{cls}" referent="{ref}">')
    out.append(f"{t}\t<Properties>")
    out.append(f'{t}\t\t<string name="Name">{escape(name)}</string>')
    out.extend(f"{t}\t\t{line}" for line in extra)
    out.append(f"{t}\t</Properties>")
    for child in children:
        child(out, depth + 1)
    out.append(f"{t}</Item>")


def node_writer(node):
    def write(out, depth):
        extra = []
        if node.cls != "Folder":
            # RunContext не задаём (как в старой версии): Script/LocalScript по месту расположения
            extra.append(f'<ProtectedString name="Source">{cdata(node.source)}</ProtectedString>')
        xml_item(out, node.cls, referent(node.path), node.name, depth, extra, [node_writer(c) for c in node.children])
    return write


def service_writer(cls, path, children, extra=()):
    def write(out, depth):
        xml_item(out, cls, referent("@" + path), cls if "/" not in path else path.rsplit("/", 1)[1], depth, extra, children)
    return write


def build_rbxlx(roots):
    out = ['<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
           'xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">',
           '\t<Meta name="ExplicitAutoJoints">true</Meta>',
           "\t<External>null</External>",
           "\t<External>nil</External>"]
    kids = lambda key: [node_writer(n) for n in roots.get(key, [])]
    tops = [
        # пустой Workspace: мир строит сервер; стриминг выключен (клиент рассчитывает на всю карту)
        service_writer("Workspace", "Workspace", [], ['<bool name="StreamingEnabled">false</bool>']),
        service_writer("ReplicatedStorage", "ReplicatedStorage", kids("ReplicatedStorage")),
        service_writer("ServerScriptService", "ServerScriptService", kids("ServerScriptService")),
        service_writer("StarterPlayer", "StarterPlayer", [
            service_writer("StarterPlayerScripts", "StarterPlayer/StarterPlayerScripts", kids("StarterPlayerScripts")),
            service_writer("StarterCharacterScripts", "StarterPlayer/StarterCharacterScripts", []),
        ]),
    ]
    for w in tops:
        w(out, 1)
    out.append("</roblox>")
    return "\n".join(out) + "\n"


# ---------------------------------------------------------------- bundle для мока
def long_string(text):
    """Длинная строка Luau, которая точно закроется ровно в конце текста."""
    level = 0
    while True:
        close = "]" + "=" * level + "]"
        if (text + close).find(close) == len(text):
            return "[" + "=" * level + "[\n" + text + close
        level += 1


def build_bundle(roots, fixtures):
    lines = ["--!nocheck",
             "-- Сгенерировано tools/build.py из src/ — не редактировать вручную.",
             "-- Использование: require(\"./_bundle\")(M) — создаёт дерево src в моке (M.services.*).",
             "local FILES = {"]
    sources = []
    index = 0
    for service in SERVICE_ORDER:
        for node in iter_nodes(roots.get(service, [])):
            index += 1
            file = f'"{node.file}"' if node.file else "nil"
            lines.append(f'\t{{ Path = "{node.path}", Class = "{node.cls}", File = {file} }},')
            if node.source is not None:
                sources.append(f"SOURCES[{index}] = {long_string(node.source)}")
    lines.append("}")
    lines.append("local SOURCES = {}")
    lines.extend(sources)
    lines.append("local FIXTURES = {}")
    for name, text in fixtures:
        lines.append(f'FIXTURES["{name}"] = {long_string(text)}')
    lines.append("""
local function install(M)
	local S = M.services
	local sp = S.StarterPlayer
	local sps = sp:FindFirstChild("StarterPlayerScripts")
	if not sps then
		sps = M.newInstance("StarterPlayerScripts")
		sps.Name = "StarterPlayerScripts"
		sps.Parent = sp
	end
	local made = { ReplicatedStorage = S.ReplicatedStorage, ServerScriptService = S.ServerScriptService, StarterPlayerScripts = sps }
	local list = {}
	for i, f in ipairs(FILES) do
		local parentPath, name = string.match(f.Path, "^(.*)/([^/]+)$")
		local parent = assert(made[parentPath], "bundle: нет родителя " .. f.Path)
		if not string.find(parentPath, "/", 1, true) then
			local old = parent:FindFirstChild(name)
			if old then old:Destroy() end -- повторная установка
		end
		local obj = M.newInstance(f.Class)
		obj.Name = name
		if SOURCES[i] then obj.Source = SOURCES[i] end
		obj.Parent = parent
		made[f.Path] = obj
		list[i] = { Path = f.Path, Class = f.Class, File = f.File, Instance = obj }
	end
	return list
end

return setmetatable({ Files = FILES, Sources = SOURCES, Fixtures = FIXTURES }, {
	__call = function(_, M) return install(M) end,
})""")
    return "\n".join(lines) + "\n"


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--src", default=str(ROOT / "src"))
    ap.add_argument("--rbxlx", default=str(ROOT / "build" / "VoidTD.rbxlx"))
    ap.add_argument("--bundle", default=str(ROOT / "tests" / "_bundle.luau"))
    ap.add_argument("--fixtures", default=str(ROOT / "tests" / "fixtures"))
    args = ap.parse_args()

    src = Path(args.src).resolve()
    roots = collect(src)
    fixtures = []
    fdir = Path(args.fixtures)
    if fdir.is_dir():
        for p in sorted(fdir.iterdir()):
            name, cls = script_kind(p.name)
            if name and cls == "ModuleScript":
                fixtures.append((name, read_source(p, fdir)))
    for w in warnings:
        print("WARN:", w)
    if problems:
        for p in problems:
            print("ERROR:", p)
        sys.exit(1)

    nodes = [n for s in SERVICE_ORDER for n in iter_nodes(roots.get(s, []))]
    refs = [referent(n.path) for n in nodes]
    assert len(set(refs)) == len(refs), "referent collision"
    scripts = [n for n in nodes if n.cls != "Folder"]

    rbxlx = Path(args.rbxlx)
    rbxlx.parent.mkdir(parents=True, exist_ok=True)
    rbxlx.write_text(build_rbxlx(roots), encoding="utf-8", newline="\n")
    bundle = Path(args.bundle)
    bundle.parent.mkdir(parents=True, exist_ok=True)
    bundle.write_text(build_bundle(roots, fixtures), encoding="utf-8", newline="\n")

    src_bytes = sum(len(n.source.encode("utf-8")) for n in scripts)
    by_cls = {}
    for n in nodes:
        by_cls[n.cls] = by_cls.get(n.cls, 0) + 1
    summary = ", ".join(f"{k} {v}" for k, v in sorted(by_cls.items()))
    print(f"src: {len(scripts)} scripts, {src_bytes / 1024:.1f} KB of source ({summary})")
    for path in (rbxlx, bundle):
        try:
            shown = path.resolve().relative_to(ROOT)
        except ValueError:
            shown = path
        print(f"OK: {shown} ({path.stat().st_size / 1024:.1f} KB)")


if __name__ == "__main__":
    main()
