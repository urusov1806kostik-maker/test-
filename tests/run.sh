#!/bin/bash
# Прогон тестов в мок-окружении Roblox. Нужен Luau CLI (https://github.com/luau-lang/luau/releases) в PATH.
set -e
cd "$(dirname "$0")"
python3 ../tools/build_installer.py
python3 gen.py
for preset in strong mythic mid common; do
	echo "== server sim: $preset"
	luau run_server.luau -a "$preset" 2>&1 | grep -E "RESULT|attempt|Error" || true
done
echo "== client"
luau run_client.luau 2>&1 | grep -E "CLIENT TEST OK|attempt|Error"
