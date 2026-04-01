#!/bin/bash
# ============================================================
# dm.sh — Disputa (Deathmatch)
# Baseado no HTML real de /dm
# ============================================================
# Estrutura real confirmada:
#   Título: "Combate" (igual ao /battle mas é DM)
#   Próxima disputa: href="dm?14-1.ILinkListener-currentOverview-apply"
#     Botão: "Cada um por si!"
#   Refresh: href="dm?14-1.ILinkListener-refresh"
#   Horários: 11:20, 15:20, 21:20 (a confirmar)
#   Passadas: href="dmpast"
#
# NOTA: Estrutura igual ao PvE — aplica antes do início
# ============================================================

dm_mode() {
  if [ "$FUNC_dm" = "n" ]; then return; fi

  echo_t "Disputa (DM)" "$GOLD_BLACK" "$COLOR_RESET" "after" "💥"

  fetch_page "/dm"

  if ! _session_active; then
    echo_t "Sessão inválida na Disputa." "$BLACK_RED" "$COLOR_RESET" "after" "❌"
    go_hangar
    return
  fi

  # Título é "Combate" mas tem link DM
  if ! grep -q 'dm?[0-9]' "$TMP/SRC" 2>/dev/null; then
    echo_t "Página de Disputa não encontrada." "$BLACK_YELLOW" "$COLOR_RESET" "after" "⚠️"
    go_hangar
    return
  fi

  # Info da próxima disputa
  local next_time
  next_time=$(grep -o -E 'até o início [0-9]{2}:[0-9]{2}:[0-9]{2}' "$TMP/SRC" | head -n1)
  echo_t "  ⏰ ${next_time:-?}" "$GRAY_BLACK" "$COLOR_RESET"

  # Aplica na disputa disponível
  local apply_link
  # HTML real: href="dm?14-1.ILinkListener-currentOverview-apply"
  apply_link=$(grep -o -E 'dm\?[0-9]+-[0-9]+\.ILinkListener-currentOverview-apply' \
    "$TMP/SRC" | head -n1)

  if [ -n "$apply_link" ]; then
    echo_t "  ✅ A aplicar na Disputa..." "$GREEN_BLACK" "$COLOR_RESET"
    fetch_page "/${apply_link}"
    sleep 1s
    echo_t "  💥 Aplicado! Cada um por si!" "$GREEN_BLACK" "$COLOR_RESET"
  else
    echo_t "  Sem disputa disponível para aplicar agora." "$GRAY_BLACK" "$COLOR_RESET"
  fi

  echo_t "Disputa concluída." "$GREEN_BLACK" "$COLOR_RESET" "after" "✅"
  go_hangar
}

# ── Verifica e aplica em DM se estiver na hora ───────────────
dm_check_and_apply() {
  fetch_page "/dm"
  if ! _session_active; then return; fi

  local apply_link
  apply_link=$(grep -o -E 'dm\?[0-9]+-[0-9]+\.ILinkListener-currentOverview-apply' \
    "$TMP/SRC" | head -n1)

  if [ -n "$apply_link" ]; then
    local next_time
    next_time=$(grep -o -E 'até o início [0-9]{2}:[0-9]{2}:[0-9]{2}' "$TMP/SRC" | head -n1)
    echo_t "DM: A aplicar... ${next_time}" "$GOLD_BLACK" "$COLOR_RESET" "after" "💥"
    fetch_page "/${apply_link}"
    sleep 1s
  fi
}
