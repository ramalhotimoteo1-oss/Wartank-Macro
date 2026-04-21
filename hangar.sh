#!/bin/bash
# hangar.sh — v1.4.0
# Fix: clear antes do display, potencia do tanque, interface limpa

# Tempo da ultima batalha (para gerir combustivel)
LAST_BATTLE_TIME=0

go_hangar() {
  fetch_page "/angar"

  if grep -q '<title>Hangar</title>' "$SRC" 2>/dev/null; then
    _parse_hangar_info
    return 0
  fi

  if grep -q 'showSigninLink\|IFormSubmitListener-loginForm' "$SRC" 2>/dev/null; then
    echo "[hangar] sessao perdida — a reconectar"
    _do_login
    fetch_page "/angar"
    _parse_hangar_info
  fi

  return 0
}

_parse_hangar_info() {
  # Combustivel
  FUEL_CURRENT=$(grep -o -E 'fuel\.png[^/]*/>[^0-9]*[0-9]+' "$SRC" \
    | grep -o -E '[0-9]+$' | head -n1)

  # Ouro
  GOLD=$(grep -o -E 'gold\.png[^/]*/>[^0-9]*[0-9]+' "$SRC" \
    | grep -o -E '[0-9]+$' | head -n1)

  # Prata
  SILVER=$(grep -o -E 'silver\.png[^/]*/>[^0-9]*[0-9]+' "$SRC" \
    | grep -o -E '[0-9]+$' | head -n1)

  # Nivel e ID (do jsInterface)
  PLAYER_LEVEL=$(grep -o -E 'level=[0-9]+' "$SRC" | grep -o -E '[0-9]+' | head -n1)
  PLAYER_ID=$(grep -o -E 'user=[0-9]+' "$SRC" | grep -o -E '[0-9]+' | head -n1)

  # Potencia do tanque — extraida do HTML do hangar
  # HTML: <span class="green2">Potência de tanque: 4788</span>
  TANK_POWER=$(grep -o -E 'Potência de tanque: [0-9]+' "$SRC" \
    | grep -o -E '[0-9]+' | head -n1)

  # Experiencia da barra de nivel
  # HTML: <div class="scale" style="width:29%;">
  XP_PCT=$(grep -o -E 'width:[0-9]+%' "$SRC" \
    | grep -o -E '[0-9]+' | head -n1)

  _display_status
}

_display_status() {
  local h m
  printf -v h '%(%H)T' -1
  printf -v m '%(%M)T' -1

  # FIX: clear para nao acumular texto no terminal
  clear

  echo ""
  echo "  wartank-pt.net | ${h}:${m}"
  echo "  ─────────────────────────────────────────"
  printf "  %-20s Nv.%-4s ID: %s\n" \
    "${ACC:-Jogador}" "${PLAYER_LEVEL:-?}" "${PLAYER_ID:-?}"
  echo "  ─────────────────────────────────────────"
  printf "  Combustivel: %-8s Potencia: %s\n" \
    "${FUEL_CURRENT:-?}" "${TANK_POWER:-?}"
  printf "  Ouro:        %-8s Prata: %s\n" \
    "${GOLD:-?}" "${SILVER:-?}"
  [ -n "$XP_PCT" ] && printf "  Exp:         %s%%\n" "$XP_PCT"
  echo "  ─────────────────────────────────────────"
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
