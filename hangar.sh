#!/bin/bash
# hangar.sh — v1.5.1
# go_hangar: vai ao hangar, le dados, mostra painel limpo
# Os modulos NAO chamam go_hangar — so o run.sh chama

go_hangar() {
  fetch_page "/angar"

  if grep -q '<title>Hangar</title>' "$SRC" 2>/dev/null; then
    _parse_hangar_info
    return 0
  fi

  # Sessao perdida
  if grep -q 'showSigninLink\|IFormSubmitListener-loginForm' "$SRC" 2>/dev/null; then
    echo "[hangar] sessao perdida — a reconectar"
    _do_login
    fetch_page "/angar"
    _parse_hangar_info
  fi

  return 0
}

_parse_hangar_info() {
  FUEL_CURRENT=$(grep -o -E 'fuel\.png[^/]*/>[^0-9]*[0-9]+' "$SRC" \
    | grep -o -E '[0-9]+$' | head -n1)
  GOLD=$(grep -o -E 'gold\.png[^/]*/>[^0-9]*[0-9]+' "$SRC" \
    | grep -o -E '[0-9]+$' | head -n1)
  SILVER=$(grep -o -E 'silver\.png[^/]*/>[^0-9]*[0-9]+' "$SRC" \
    | grep -o -E '[0-9]+$' | head -n1)
  PLAYER_LEVEL=$(grep -o -E 'level=[0-9]+' "$SRC" \
    | grep -o -E '[0-9]+' | head -n1)
  PLAYER_ID=$(grep -o -E 'user=[0-9]+' "$SRC" \
    | grep -o -E '[0-9]+' | head -n1)
  TANK_POWER=$(grep -o -E 'Potência de tanque: [0-9]+' "$SRC" \
    | grep -o -E '[0-9]+' | head -n1)
  XP_PCT=$(grep -o -E '"scale" style="width:[0-9]+' "$SRC" \
    | grep -o -E '[0-9]+$' | head -n1)
  PLAYER_RANK=$(grep -o -E \
    'class="(leader|general|officer|soldier|newbie|rank)[^>]*>[^<]+' \
    "$SRC" | sed 's/.*">//' | head -n1)

  _display_status
}

_display_status() {
  local h m
  printf -v h '%(%H)T' -1
  printf -v m '%(%M)T' -1

  # Limpa TUDO antes de mostrar o painel
  clear

  echo ""
  echo "  ┌─────────────────────────────────────────┐"
  printf "  │  %-38s│\n" "wartank-pt.net  |  ${h}:${m}"
  echo "  ├─────────────────────────────────────────┤"
  printf "  │  %-38s│\n" "${ACC:-Jogador}"
  printf "  │  Nivel: %-5s  ID: %-23s│\n" \
    "${PLAYER_LEVEL:-?}" "${PLAYER_ID:-?}"
  [ -n "$PLAYER_RANK" ] && \
    printf "  │  Patente: %-30s│\n" "${PLAYER_RANK}"
  [ -n "$XP_PCT" ] && \
    printf "  │  Exp: %-34s│\n" "${XP_PCT}%"
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
