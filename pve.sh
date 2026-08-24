#!/bin/bash
# pve.sh — PvE (Batalhas Historicas) v3.1.0
# Usa combat_common.sh

pve_check_and_apply() {
  [ "$FUNC_pve" = "n" ] && return 0

  fetch_page "/pve"
  if ! _session_active; then return; fi

  # Estado 1: combate ja activo
  if grep -q 'currentControl-attackRegularShellLink' "$SRC" 2>/dev/null; then
    echo "[pve] combate activo"
    _pve_fight; return
  fi

  # Estado 2: tempo restante
  if wait_battle_timer "pve" "/pve" "ate o inicio" \
     "currentControl-attackRegularShellLink" "_pve_fight"; then
    return
  fi

  # Estado 3: apply disponivel
  local apply_link
  apply_link=$(grep -o -E \
    'pve\?[0-9]+-[0-9]+\.ILinkListener-currentOverview-apply' \
    "$SRC" | head -n1)

  if [ -n "$apply_link" ]; then
    local battle_name
    battle_name=$(grep -o -E 'class="green2">[^<]+' "$SRC" \
      | sed 's/.*">//' | head -n1)
    echo "[pve] a aplicar: ${battle_name:-batalha}"
    fetch_page "$apply_link"
    sleep_rand 500 800
    grep -q 'currentControl-attackRegularShellLink' "$SRC" 2>/dev/null && \
      _pve_fight
  fi
}

pve_mode() {
  [ "$FUNC_pve" = "n" ] && return 0
  pve_check_and_apply
}

_pve_fight() {
  # PvE: sem manobra, HP usa green1
  combat_loop "pve" "n" "green1"

  # Apos batalha: verifica nova batalha disponivel
  local next_apply
  next_apply=$(grep -o -E \
    'pve\?[0-9]+-[0-9]+\.ILinkListener-currentOverview-apply' \
    "$SRC" | head -n1)
  if [ -n "$next_apply" ]; then
    echo "[pve] nova batalha — a aplicar"
    fetch_page "$next_apply"
    sleep_rand 500 800
    grep -q 'currentControl-attackRegularShellLink' "$SRC" 2>/dev/null && \
      _pve_fight
  fi
}
