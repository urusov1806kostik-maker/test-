#!/bin/bash
# Прогон тестов в мок-окружении Roblox. Нужен Luau CLI (https://github.com/luau-lang/luau/releases) в PATH.
set -e
cd "$(dirname "$0")"
python3 ../tools/build_installer.py
python3 gen.py
for preset in strong mythic mid common; do
	echo "== server sim: $preset"
	luau run_server.luau -a "$preset" Medium 2>&1 | grep -E "RESULT|attempt|Error" || true
done
for diff in Easy Hard Hardcore; do
	echo "== server sim: strong / $diff"
	luau run_server.luau -a strong "$diff" 2>&1 | grep -E "RESULT|attempt|Error" || true
done
for set in old shattered blood; do
	echo "== client: $set"
	luau run_client.luau -a "$set" 2>&1 | grep -E "CLIENT TEST OK|attempt|Error"
done
echo "== enemies"
luau run_enemies.luau 2>&1 | grep -E "ENEMY TEST OK|attempt|Error"
for preset in shattered blood; do
	echo "== server sim: $preset"
	luau run_server.luau -a "$preset" Medium 2>&1 | grep -E "RESULT|attempt|Error" || true
done
