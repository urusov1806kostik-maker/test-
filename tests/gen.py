#!/usr/bin/env python3
"""Упаковывает build/VoidTD_Installer.lua в tests/installer_str.luau для прогона в Luau CLI."""
from pathlib import Path

here = Path(__file__).resolve().parent
src = (here.parent / "build" / "VoidTD_Installer.lua").read_text(encoding="utf-8")
level = "=" * 9
assert f"]{level}]" not in src
(here / "installer_str.luau").write_text(f"return [{level}[\n{src}]{level}]\n", encoding="utf-8")
print("ok")
