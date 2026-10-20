#!/usr/bin/env python3
"""Проверка build/VoidTD.rbxlx против src/ (независимо от tools/build.py).

- XML парсится (xml.etree), корень <roblox version="4">;
- все referent уникальны;
- каждый файл src есть по правильному пути, с правильным классом и побайтно тем же Source;
- лишних экземпляров нет (кроме каркаса сервисов);
- Source у скриптов записан только CDATA-секциями (]]> внутри исходника разрезан корректно);
- у Script/LocalScript не задан RunContext.
Запуск: python3 tests/check_rbxlx.py [--src DIR] [--rbxlx FILE]; код возврата != 0 при ошибках.
"""
import argparse
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SERVICE_PATH = {"ReplicatedStorage": "ReplicatedStorage", "ServerScriptService": "ServerScriptService",
                "StarterPlayerScripts": "StarterPlayer/StarterPlayerScripts"}
# каркас, который есть в месте, но не соответствует файлам
SKELETON = {"Workspace": "Workspace", "ReplicatedStorage": "ReplicatedStorage", "ServerScriptService": "ServerScriptService",
            "StarterPlayer": "StarterPlayer", "StarterPlayer/StarterPlayerScripts": "StarterPlayerScripts",
            "StarterPlayer/StarterCharacterScripts": "StarterCharacterScripts"}

errors = []
notes = []


def kind(name):
    for ext in (".lua", ".luau"):
        if name.endswith(ext):
            base = name[: -len(ext)]
            if base.endswith(".server"):
                return base[:-7], "Script"
            if base.endswith(".client"):
                return base[:-7], "LocalScript"
            return base, "ModuleScript"
    return None, None


def source_of(file):
    text = file.read_bytes().decode("utf-8")
    if text.startswith("﻿"):
        text = text[1:]
    if "\r" in text:
        notes.append(f"{file}: CRLF (в месте нормализован в LF)")
        text = text.replace("\r\n", "\n").replace("\r", "\n")
    return text


def expected_tree(src):
    """path -> (class, source|None, file)"""
    exp = {}

    def visit(d, path):
        items = [p for p in d.iterdir() if not p.name.startswith(".") and not p.name.endswith("~") and p.name != "__pycache__"]
        init = [p for p in items if p.is_file() and kind(p.name)[0] == "init"]
        if path not in SKELETON.keys() or init:
            if init:
                cls = kind(init[0].name)[1]
                exp[path] = (cls, source_of(init[0]), init[0])
            else:
                exp[path] = ("Folder", None, d)
        for p in items:
            if p in init:
                continue
            if p.is_dir():
                visit(p, f"{path}/{p.name}")
            else:
                name, cls = kind(p.name)
                if name:
                    exp[f"{path}/{name}"] = (cls, source_of(p), p)

    for top in sorted(src.iterdir()):
        if top.name.startswith("."):
            continue
        if top.name not in SERVICE_PATH:
            errors.append(f"src/{top.name}: неизвестный сервис")
            continue
        visit(top, SERVICE_PATH[top.name])
    return exp


def check_cdata(raw):
    """Каждый <ProtectedString name="Source"> содержит только последовательность CDATA-секций."""
    open_tag = '<ProtectedString name="Source">'
    pos, count = 0, 0
    while True:
        i = raw.find(open_tag, pos)
        if i < 0:
            return count
        j = i + len(open_tag)
        count += 1
        while raw.startswith("<![CDATA[", j):
            k = raw.find("]]>", j + 9)
            if k < 0:
                errors.append(f"незакрытая CDATA-секция (символ {j})")
                return count
            j = k + 3
        if not raw.startswith("</ProtectedString>", j):
            line = raw.count("\n", 0, j) + 1
            errors.append(f"строка {line}: Source не только из CDATA (CDATA небезопасна)")
        pos = j


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", default=str(ROOT / "src"))
    ap.add_argument("--rbxlx", default=str(ROOT / "build" / "VoidTD.rbxlx"))
    args = ap.parse_args()
    src, rbxlx = Path(args.src), Path(args.rbxlx)

    raw = rbxlx.read_text(encoding="utf-8")
    nsources = check_cdata(raw)
    try:
        root = ET.fromstring(raw)
    except ET.ParseError as e:
        print(f"FAIL: XML не парсится: {e}")
        sys.exit(1)
    if root.tag != "roblox" or root.get("version") != "4":
        errors.append(f"корень должен быть <roblox version=\"4\">, а не <{root.tag} version={root.get('version')}>")

    refs = {}
    actual = {}  # path -> (class, source|None, item)

    def visit(item, parent_path):
        cls = item.get("class")
        ref = item.get("referent")
        if not ref or not re.fullmatch(r"RBX[0-9A-Fa-f]+", ref):
            errors.append(f"плохой referent {ref!r} у {cls}")
        if ref in refs:
            errors.append(f"referent {ref} повторяется")
        refs[ref] = True
        props = item.find("Properties")
        name_el = props.find("string[@name='Name']") if props is not None else None
        if name_el is None:
            errors.append(f"{cls} без <string name=\"Name\"> (referent {ref})")
            name = "?"
        else:
            name = name_el.text or ""
        path = f"{parent_path}/{name}" if parent_path else name
        src_el = props.find("ProtectedString[@name='Source']") if props is not None else None
        source = None if src_el is None else (src_el.text or "")
        if cls in ("Script", "LocalScript") and props is not None:
            for el in props:
                if el.get("name") == "RunContext":
                    errors.append(f"{path}: задан RunContext (не нужен)")
        if path in actual:
            errors.append(f"{path}: два экземпляра с одинаковым путём")
        actual[path] = (cls, source)
        for child in item.findall("Item"):
            visit(child, path)

    for item in root.findall("Item"):
        visit(item, "")

    for path, cls in SKELETON.items():
        if path not in actual:
            errors.append(f"нет {path}")
        elif actual[path][0] != cls:
            errors.append(f"{path}: класс {actual[path][0]}, ожидался {cls}")
    ws = [p for p in actual if p.startswith("Workspace/")]
    if ws:
        errors.append(f"Workspace должен быть пустым, а в нём: {', '.join(ws[:5])}")

    exp = expected_tree(src)
    for path, (cls, source, file) in sorted(exp.items()):
        got = actual.get(path)
        if not got:
            errors.append(f"{path}: нет в месте ({file})")
            continue
        if got[0] != cls:
            errors.append(f"{path}: класс {got[0]}, ожидался {cls}")
        if source is not None:
            if got[1] is None:
                errors.append(f"{path}: нет Source")
            elif got[1].encode("utf-8") != source.encode("utf-8"):
                a, b = got[1], source
                i = next((k for k in range(min(len(a), len(b))) if a[k] != b[k]), min(len(a), len(b)))
                errors.append(f"{path}: Source отличается от {file} (с символа {i}, строка {b.count(chr(10), 0, i) + 1})")
        elif got[1] is not None:
            errors.append(f"{path}: у папки есть Source")
    for path in sorted(actual):
        if path not in exp and path not in SKELETON:
            errors.append(f"{path}: лишний экземпляр (нет в src)")

    scripts = sum(1 for v in exp.values() if v[1] is not None)
    if nsources != sum(1 for v in actual.values() if v[1] is not None):
        errors.append(f"ProtectedString в тексте {nsources}, в дереве {sum(1 for v in actual.values() if v[1] is not None)}")
    for n in notes:
        print("NOTE:", n)
    if errors:
        for e in errors:
            print("FAIL:", e)
        print(f"RBXLX FAILED ({len(errors)} problems)")
        sys.exit(1)
    print(f"RBXLX OK ({scripts} scripts, {len(actual)} instances, {len(refs)} unique referents)")


if __name__ == "__main__":
    main()
