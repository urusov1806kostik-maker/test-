#!/bin/bash
# Нижняя полоска: сколько осталось лимита сессии (5 ч) и контекста
in=$(cat)
bar() { p=${1%.*}; f=$((p/10)); s=""; for i in $(seq 1 10); do [ $i -le $f ] && s+="█" || s+="░"; done; echo "$s"; }
used5=$(echo "$in" | jq -r '.rate_limits.five_hour.used_percentage // empty')
ctx=$(echo "$in" | jq -r '.context_window.used_percentage // empty')
out=""
if [ -n "$used5" ]; then l=$((100-${used5%.*})); out+="Сессия: $(bar $l) ${l}% осталось"; fi
if [ -n "$ctx" ]; then c=$((100-${ctx%.*})); out+="${out:+  |  }Контекст: ${c}% осталось"; fi
echo "${out:-Сессия: нет данных}"
