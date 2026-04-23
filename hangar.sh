#!/bin/bash
# hangar.sh — v1.5.0
# Fix: patente adicionada, painel mais organizado

go_hangar() {
  fetch_page "/angar"

  if grep -q '<title>Hangar</title>' "$SRC" 2>/dev/null; then
    _parse_hangar_info
    return 0
  fi

  if grep -q 'showSigninLink\|IFormSubmitListener-loginForm' "$SRC" 2>/dev/null; then
    echo "[hangar] sessao perdida"
    _do_login
    fetch_page "/angar"
    _parse_hangar_info
  fi

  return 0
}

_parse_hangar_info() {
  FUEL_CURRENT=$(grep -A1 'title="Combustível"' "$SRC" \
    | grep -o -E '[0-9]+' | head -n1)
  GOLD=$(grep -A1 'title="Ouro"' "$SRC" \
    | grep -o -E '[0-9]+' | head -n1)
  SILVER=$(grep -A1 'title="Prata"' "$SRC" \
    | grep -o -E '[0-9]+' | head -n1)
  PLAYER_LEVEL=$(grep -o -E 'level=[0-9]+' "$SRC" \
    | grep -o -E '[0-9]+' | head -n1)
  PLAYER_ID=$(grep -o -E 'user=[0-9]+' "$SRC" \
    | grep -o -E '[0-9]+' | head -n1)
  TANK_POWER=$(grep -o -E 'Potência de tanque: [0-9]+' "$SRC" \
    | grep -o -E '[0-9]+' | head -n1)
  XP_PCT=$(grep -o -E '"scale" style="width:[0-9]+' "$SRC" \
    | grep -o -E '[0-9]+$' | head -n1)

  # Patente — extraida do perfil/hangar
  # HTML: class="rank">general</span> ou similar
  PLAYER_RANK=$(grep -o -E 'class="(leader|general|officer|soldier|newbie|rank)[^>]*>[^<]+' \
    "$SRC" | sed 's/.*">//;s/<.*//' | head -n1)
  # Fallback: busca por texto de patente comum
  [ -z "$PLAYER_RANK" ] && \
    PLAYER_RANK=$(grep -o -E '(general|comandante|oficial|soldado|novato)' \
      "$SRC" | head -n1)

  _display_status
}

_display_status() {
  local h m
  printf -v h '%(%H)T' -1
  printf -v m '%(%M)T' -1

  clear

  echo ""
  echo "  ┌─────────────────────────────────────────┐"
  printf "  │  %-38s│\n" "wartank-pt.net  |  ${h}:${m}"
  echo "  ├─────────────────────────────────────────┤"
  printf "  │  %-38s│\n" "${ACC:-Jogador}"
  printf "  │  Nivel: %-5s  ID: %-20s│\n" \
    "${PLAYER_LEVEL:-?}" "${PLAYER_ID:-?}"
  [ -n "$PLAYER_RANK" ] && \
    printf "  │  Patente: %-31s│\n" "${PLAYER_RANK}"
  [ -n "$XP_PCT" ] && \
    printf "  │  Exp: %s%%%-34s│\n" "${XP_PCT}" ""
  echo "  ├─────────────────────────────────────────┤"
  printf "  │  Combustivel: %-26s│\n" "${FUEL_CURRENT:-?}"
  printf "  │  Potencia:    %-26s│\n" "${TANK_POWER:-?}"
  printf "  │  Ouro:        %-26s│\n" "${GOLD:-?}"
  printf "  │  Prata:       %-26s│\n" "${SILVER:-?}"
  echo "  └─────────────────────────────────────────┘"
  echo ""
}

has_fuel() {
  local min_fuel="${1:-${FUEL_MIN:-0}}"
  [ -z "$FUEL_CURRENT" ] && return 0
  [ "$FUEL_CURRENT" -le "$min_fuel" ] 2>/dev/null && return 1
  return 0
}

hangar_status() {
  go_hangar
}
