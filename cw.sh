#!/bin/bash
# ============================================================
# cw.sh — Guerra (Clan War)
# Baseado no HTML real de /cw
# ============================================================
# Estrutura real confirmada:
#   Título: "Guerra"
#   Guerra actual: "Guerra: <país> Start in HH:MM:SS"
#   Tokens: "My tokens: X de 500"
#   Refresh: href="cw?11-1.ILinkListener-jettonsView-refresh"
#   Mapa: href="europe/"
#   Guerras passadas: href="cwpast"
#
# NOTA: A guerra não tem botão de aplicar manual visível
#       O tanque participa automaticamente quando a guerra começa
#       Tokens ganhos → convertidos em ouro às 2as feiras
# ============================================================

cw_mode() {
  if [ "$FUNC_cw" = "n" ]; then return; fi

  echo_t "Guerra (CW)" "$GOLD_BLACK" "$COLOR_RESET" "after" "⚔️🗺️"

  fetch_page "/cw"

  if ! _session_active; then
    echo_t "Sessão inválida na Guerra." "$BLACK_RED" "$COLOR_RESET" "after" "❌"
    go_hangar
    return
  fi

  if ! grep -q '<title>Guerra</title>' "$TMP/SRC" 2>/dev/null; then
    echo_t "Página de Guerra não encontrada." "$BLACK_YELLOW" "$COLOR_RESET" "after" "⚠️"
    go_hangar
    return
  fi

  # Info da guerra actual
  local war_country war_start tokens
  war_country=$(grep -o -E 'class="green1">[^<]+' "$TMP/SRC" | sed 's/.*">//' | head -n1)
  war_start=$(grep -o -E 'Start in [0-9]{2}:[0-9]{2}:[0-9]{2}' "$TMP/SRC" | head -n1)
  tokens=$(grep -o -E 'My tokens:[^0-9]*[0-9]+' "$TMP/SRC" | grep -o -E '[0-9]+' | head -n1)

  echo_t "  🗺️ ${war_country:-?}" "$GRAY_BLACK" "$COLOR_RESET"
  echo_t "  ⏰ ${war_start:-?}" "$GRAY_BLACK" "$COLOR_RESET"
  echo_t "  🏅 Tokens: ${tokens:-0}/500" "$GRAY_BLACK" "$COLOR_RESET"

  # Refresh de tokens
  local refresh_link
  refresh_link=$(grep -o -E 'cw\?[0-9]+-[0-9]+\.ILinkListener-jettonsView-refresh' \
    "$TMP/SRC" | head -n1)

  if [ -n "$refresh_link" ]; then
    fetch_page "/${refresh_link}"
    local new_tokens
    new_tokens=$(grep -o -E 'My tokens:[^0-9]*[0-9]+' "$TMP/SRC" | grep -o -E '[0-9]+' | head -n1)
    echo_t "  🔄 Tokens actualizados: ${new_tokens:-?}/500" "$GRAY_BLACK" "$COLOR_RESET"
  fi

  echo_t "Guerra verificada." "$GREEN_BLACK" "$COLOR_RESET" "after" "✅"
  go_hangar
}
