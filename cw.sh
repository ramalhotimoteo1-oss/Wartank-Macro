#!/bin/bash
# cw.sh — Guerra (Clan War) v3.1.0
# Usa combat_common.sh

cw_check_and_apply() {
  [ "$FUNC_cw" = "n" ] && return 0

  fetch_page "/cw"
  if ! _session_active; then return; fi

  # Estado 1: combate ja activo
  if grep -q 'currentControl-buttons-attackRegularShellLink' "$SRC" 2>/dev/null; then
    echo "[cw] combate activo"
    _cw_fight; return
  fi

  # Estado 2: tempo restante
  if wait_battle_timer "cw" "/cw" "Start in" \
     "currentControl-buttons-attackRegularShellLink" "_cw_fight"; then
    return
  fi

  # Estado 3: apply disponivel
  local enter_link
  enter_link=$(grep -o -E \
    'cw\?[0-9]+-[0-9]+\.ILinkListener-currentOverview-apply' \
    "$SRC" | head -n1)

  if [ -n "$enter_link" ]; then
    local war_country
    war_country=$(grep -o -E 'class="green1">[^<]+' "$SRC" \
      | sed 's/.*">//' | head -n1)
    echo "[cw] a entrar: ${war_country:-?}"
    fetch_page "$enter_link"
    sleep_rand 500 800
    grep -q 'currentControl-buttons-attackRegularShellLink' "$SRC" 2>/dev/null && \
      _cw_fight
  else
    local tokens war_country
    tokens=$(grep -o -E 'My tokens:[^0-9]*[0-9]+' "$SRC" \
      | grep -o -E '[0-9]+' | head -n1)
    war_country=$(grep -o -E 'class="green1">[^<]+' "$SRC" \
      | sed 's/.*">//' | head -n1)
    echo "[cw] ${war_country:-sem guerra} | tokens: ${tokens:-0}"
  fi
}

cw_mode() {
  [ "$FUNC_cw" = "n" ] && return 0
  cw_check_and_apply
}

_cw_fight() {
  # CW: com manobra, HP usa first
  combat_loop "cw" "y" "first"
}
