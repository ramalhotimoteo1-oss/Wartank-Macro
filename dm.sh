#!/bin/bash
# dm.sh — Disputa (Deathmatch) v3.1.0
# Usa combat_common.sh

dm_check_and_apply() {
  [ "$FUNC_dm" = "n" ] && return 0

  fetch_page "/dm"
  if ! _session_active; then return; fi

  # Estado 1: combate ja activo
  if grep -q 'currentControl-buttons-attackRegularShellLink' "$SRC" 2>/dev/null; then
    echo "[dm] combate activo"
    _dm_fight; return
  fi

  # Estado 2: tempo restante
  if wait_battle_timer "dm" "/dm" "ate o inicio" \
     "currentControl-buttons-attackRegularShellLink" "_dm_fight"; then
    return
  fi

  # Estado 3: apply disponivel
  local apply_link
  apply_link=$(grep -o -E \
    'dm\?[0-9]+-[0-9]+\.ILinkListener-currentOverview-apply' \
    "$SRC" | head -n1)

  if [ -n "$apply_link" ]; then
    echo "[dm] a aplicar"
    fetch_page "$apply_link"
    sleep_rand 500 800
    grep -q 'currentControl-buttons-attackRegularShellLink' "$SRC" 2>/dev/null && \
      _dm_fight
  fi
}

dm_mode() {
  [ "$FUNC_dm" = "n" ] && return 0
  dm_check_and_apply
}

_dm_fight() {
  # DM: com manobra, HP usa first
  combat_loop "dm" "y" "first"
}
