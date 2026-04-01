#!/bin/bash
# ============================================================
# hangar.sh — Ponto central de controlo
# Regex baseados no HTML real do wartank-pt.net
# ============================================================

go_hangar() {
  echo_t "Hangar" "$GOLD_BLACK" "$COLOR_RESET" "after" "🏠"
  fetch_page "/angar"

  # Verifica se chegou ao hangar (título real é "Hangar")
  if grep -q '<title>Hangar</title>' "$TMP/SRC" 2>/dev/null; then
    _parse_hangar_info
    return 0
  fi

  # Redirecionado para login → reconecta
  if grep -q 'showSigninLink\|IFormSubmitListener-loginForm' "$TMP/SRC" 2>/dev/null; then
    echo_t "Sessão perdida. A reconectar..." "$BLACK_YELLOW" "$COLOR_RESET" "after" "⚠️"
    _do_login
    fetch_page "/angar"
    _parse_hangar_info
  fi

  return 0
}

_parse_hangar_info() {
  # ── Combustível ─────────────────────────────────────────────
  # HTML real: <img title="Combustível" .../> 20246
  FUEL_CURRENT=$(grep -o -E 'fuel\.png[^/]*/>[^0-9]*[0-9]+' "$TMP/SRC" \
    | grep -o -E '[0-9]+$' | head -n1)

  # ── Ouro ────────────────────────────────────────────────────
  GOLD=$(grep -o -E 'gold\.png[^/]*/>[^0-9]*[0-9]+' "$TMP/SRC" \
    | grep -o -E '[0-9]+$' | head -n1)

  # ── Prata ────────────────────────────────────────────────────
  SILVER=$(grep -o -E 'silver\.png[^/]*/>[^0-9]*[0-9]+' "$TMP/SRC" \
    | grep -o -E '[0-9]+$' | head -n1)

  # ── Nível ────────────────────────────────────────────────────
  PLAYER_LEVEL=$(grep -o -E 'level=[0-9]+' "$TMP/SRC" | grep -o -E '[0-9]+' | head -n1)

  # ── User ID ──────────────────────────────────────────────────
  PLAYER_ID=$(grep -o -E 'user=[0-9]+' "$TMP/SRC" | grep -o -E '[0-9]+' | head -n1)

  # ── Exibe estado ─────────────────────────────────────────────
  echo_t "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "$GRAY_BLACK" "$COLOR_RESET"
  echo_t "👤 ${ACC:-Jogador}  |  Nível: ${PLAYER_LEVEL:-?}  |  ID: ${PLAYER_ID:-?}" "$GRAY_BLACK" "$COLOR_RESET"
  echo_t "⛽ Combustível: ${FUEL_CURRENT:-?}" "$GRAY_BLACK" "$COLOR_RESET"
  echo_t "🪙 Ouro: ${GOLD:-?}  |  🥈 Prata: ${SILVER:-?}" "$GRAY_BLACK" "$COLOR_RESET"
  echo_t "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "$GRAY_BLACK" "$COLOR_RESET"
}

# Verifica se há combustível suficiente
has_fuel() {
  local min_fuel="${1:-${FUEL_MIN:-0}}"
  _parse_hangar_info

  if [ -z "$FUEL_CURRENT" ]; then
    return 0  # Não conseguiu ler — assume que tem
  fi

  if [ "$FUEL_CURRENT" -le "$min_fuel" ] 2>/dev/null; then
    echo_t "Sem combustível (${FUEL_CURRENT})." "$BLACK_RED" "$COLOR_RESET" "after" "⛽"
    return 1
  fi
  return 0
}

# Aguarda regeneração de combustível
wait_fuel() {
  local wait_min="${1:-5}"
  echo_t "A aguardar combustível..." "$GRAY_BLACK" "$COLOR_RESET" "after" "⏳"
  sleep "${wait_min}m"
  go_hangar
}

# Estado completo do hangar
hangar_status() {
  go_hangar
  local h m
  printf -v h '%(%H)T' -1
  printf -v m '%(%M)T' -1
  echo_t "🕐 ${h}:${m}  |  wartank-pt.net" "$GOLD_BLACK" "$COLOR_RESET"
}

# Extrai o jsessionid actual da página (para uso em rotas)
get_jsessionid() {
  JSESSIONID=$(grep -o -E 'jsessionid=[A-Z0-9]+' "$TMP/SRC" | head -n1 | sed 's/jsessionid=//')
}

# Rotas reais confirmadas no HTML do hangar:
#   battle          → Adiante a combater
#   pvp             → Batalhas PvP
#   pve             → Batalhas PvE
#   missions/       → Missões
#   convoy          → Escolta
#   buildings       → Base
#   bz2             → Missão de combate
#   company/        → Divisão
#   cw              → Guerra de clãs
#   dm              → Disputa
#   rating          → Ranking
#   profile/        → Perfil
#   angar           → Hangar
