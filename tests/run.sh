#!/bin/bash
# Прогон тестов VOID TD v2 в мок-окружении Roblox. Нужны python3 и Luau CLI (luau) в PATH
# (https://github.com/luau-lang/luau/releases). Сборка/проверка места прерывают прогон, тесты идут все.
set -uo pipefail
cd "$(dirname "$0")"
command -v luau >/dev/null || { echo "luau not found in PATH"; exit 2; }
python3 ../tools/build.py || exit 1
python3 check_rbxlx.py || exit 1
failed=()
step() { echo "== $*"; "$@" || failed+=("$*"); }
step luau run_config.luau
step luau smoke.luau
step luau run_server.luau
step luau run_halloween.luau
if [ ${#failed[@]} -gt 0 ]; then
	echo "FAILED: ${failed[*]}"
	exit 1
fi
echo "ALL OK"
