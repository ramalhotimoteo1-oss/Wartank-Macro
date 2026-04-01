#!/bin/bash
# ============================================================
# convoy.sh — Escolta (Comboio inimigo)
# Baseado no HTML real de /convoy
# ============================================================
# Estrutura real confirmada:
#   Título: "Escolta"
#   Mensagem: "No horizonte foi visto um comboio do inimigo!"
#   Reconhecimento: href="convoy?25-1.ILinkListener-root-findEnemy"
#     Botão: "Começar o reconhecimento"
#   Link da imagem: href="convoy?25-1.ILinkListener-root-banner-actLink"
#
#   Missões da escolta (recolha igual às missões normais):
#     href="convoy?25-1.ILinkListener-missions-cc-0-c-awardLink"
#     Botão: "Receber a recompensa"
#
#   Missões em progresso: "Mestre de reconhecimento" (4/6)
#   Missões bloqueadas: "Atualização através de: HH:MM:SS"
# ============================================================

convoy_mode() {
  if [ "$FUNC_convoy" = "n" ]; then return; fi

  echo_t "Escolta (Comboio)" "$GOLD_BLACK" "$COLOR_RESET" "after" "🚛"

  fetch_page "/convoy"

  if ! _session_active; then
    echo_t "Sessão inválida na Escolta." "$BLACK_RED" "$COLOR_RESET" "after" "❌"
    go_hangar
    return
  fi

  if ! grep -q '<title>Escolta</title>' "$TMP/SRC" 2>/dev/null; then
    echo_t "Página de Escolta não encontrada." "$BLACK_YELLOW" "$COLOR_RESET" "after" "⚠️"
    go_hangar
    return
  fi

  # ── Recolhe recompensas de missões da escolta ───────────────
  # Padrão real: convoy?25-1.ILinkListener-missions-cc-N-c-awardLink
  local award_links collected=0
  award_links=$(grep -o -E 'convoy\?[0-9]+-[0-9]+\.ILinkListener-missions-cc-[0-9]+-c-awardLink' \
    "$TMP/SRC" 2>/dev/null)

  if [ -n "$award_links" ]; then
    while IFS= read -r link; do
      [ -z "$link" ] && continue
      echo_t "  🎁 A recolher recompensa da escolta..." "$GREEN_BLACK" "$COLOR_RESET"
      fetch_page "/${link}"
      collected=$(( collected + 1 ))
      sleep 0.5s
    done <<< "$award_links"
    echo_t "  ✅ ${collected} recompensa(s) recolhida(s)!" "$GREEN_BLACK" "$COLOR_RESET"
    # Refresh após recolha
    fetch_page "/convoy"
  fi

  # ── Inicia reconhecimento se disponível ─────────────────────
  # HTML real: href="convoy?25-1.ILinkListener-root-findEnemy"
  local find_link
  find_link=$(grep -o -E 'convoy\?[0-9]+-[0-9]+\.ILinkListener-root-findEnemy' \
    "$TMP/SRC" | head -n1)

  if [ -n "$find_link" ]; then
    echo_t "  🔍 A iniciar reconhecimento..." "$GOLD_BLACK" "$COLOR_RESET"
    fetch_page "/${find_link}"
    sleep 1s

    # Verifica resultado do reconhecimento
    if _session_active; then
      # Tenta apanhar o link de ataque ao comboio
      local attack_link
      attack_link=$(grep -o -E 'convoy\?[0-9]+-[0-9]+\.ILinkListener-[^"]*actLink[^"]*' \
        "$TMP/SRC" | head -n1)

      if [ -n "$attack_link" ]; then
        echo_t "  ⚔️ Comboio encontrado! A atacar..." "$RED_BLACK" "$COLOR_RESET"
        fetch_page "/${attack_link}"
        sleep 1s
      fi
    fi
  else
    echo_t "  Reconhecimento não disponível agora." "$GRAY_BLACK" "$COLOR_RESET"

    # Mostra progresso das missões
    local active locked
    active=$(grep -c 'Receber a recompensa\|Começar o reconhecimento' "$TMP/SRC" 2>/dev/null || echo 0)
    locked=$(grep -c 'Atualização através de' "$TMP/SRC" 2>/dev/null || echo 0)
    echo_t "  Em progresso: ${active} | Bloqueadas: ${locked}" "$GRAY_BLACK" "$COLOR_RESET"
  fi

  echo_t "Escolta concluída." "$GREEN_BLACK" "$COLOR_RESET" "after" "✅"
  go_hangar
}
