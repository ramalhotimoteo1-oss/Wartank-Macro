#!/bin/bash
# ============================================================
# missions.sh — Missões wartank-pt.net
# Baseado no HTML real com links de recolha confirmados
# ============================================================
# Link de recolha confirmado:
#   href=";jsessionid=XXXX?40-1.ILinkListener-missions-cc-0-c-awardLink"
#   href=";jsessionid=XXXX?40-1.ILinkListener-missions-cc-1-c-awardLink"
#   Padrão: ILinkListener-missions-cc-N-c-awardLink
#
# Botão de recolha: "Receber a recompensa"
# Botão de executar: "Passar a executar"
# Tab activo = <span> sem href (não é <a>)
# Tab inactivo = <a href="Advanced;jsessionid=...">
# ============================================================

missions_func() {
  if [ "$FUNC_missions" = "n" ]; then return; fi

  echo_t "Missões" "$GOLD_BLACK" "$COLOR_RESET" "after" "📜"

  # ── Tab Simples ─────────────────────────────────────────────
  fetch_page "/missions/"
  if ! grep -q '<title>Мissões</title>' "$TMP/SRC" 2>/dev/null; then
    echo_t "Página de missões não encontrada." "$BLACK_YELLOW" "$COLOR_RESET" "after" "⚠️"
    go_hangar
    return
  fi

  echo_t "  ── Simples ──" "$GOLD_BLACK" "$COLOR_RESET"
  _missions_collect_awards

  # ── Tab Complicados ─────────────────────────────────────────
  # Quando Simples é activo: tab Complicados tem <a href="Advanced;jsessionid=...">
  # Quando Complicados é activo: tab Simples tem <a href=".;jsessionid=...">
  local adv_link
  adv_link=$(grep -o -E 'href="Advanced;jsessionid=[A-Z0-9]+"' "$TMP/SRC" \
    | grep -o -E 'Advanced;jsessionid=[A-Z0-9]+' | head -n1)

  if [ -n "$adv_link" ]; then
    fetch_page "/missions/${adv_link}"
    echo_t "  ── Complicados ──" "$GOLD_BLACK" "$COLOR_RESET"
    _missions_collect_awards
  fi

  echo_t "Missões concluída." "$GREEN_BLACK" "$COLOR_RESET" "after" "✅"
  go_hangar
}

# ── Recolhe todas as recompensas disponíveis na página ───────
_missions_collect_awards() {
  local collected=0

  # Extrai todos os links awardLink da página
  # Padrão real: ;jsessionid=XXXX?XX-X.ILinkListener-missions-cc-N-c-awardLink
  local award_links
  award_links=$(grep -o -E ';jsessionid=[A-Z0-9]+\?[0-9]+-[0-9]+\.ILinkListener-missions-cc-[0-9]+-c-awardLink' \
    "$TMP/SRC" 2>/dev/null)

  if [ -z "$award_links" ]; then
    echo_t "    Sem recompensas para recolher." "$GRAY_BLACK" "$COLOR_RESET"
  else
    while IFS= read -r link; do
      [ -z "$link" ] && continue

      # Extrai nome da missão correspondente (linha antes do awardLink)
      # Aproximação: apanha o nome da missão mais próximo
      local mission_name
      mission_name=$(grep -B20 "$link" "$TMP/SRC" 2>/dev/null | \
        grep -o -E 'class="small orange pb2">[^<]+' | tail -n1 | \
        sed 's/.*">//' | xargs)

      echo_t "    🎁 A recolher: ${mission_name:-missão}..." "$GREEN_BLACK" "$COLOR_RESET"
      fetch_page "/${link}"
      collected=$(( collected + 1 ))
      sleep 0.5s
    done <<< "$award_links"

    echo_t "    ✅ ${collected} recompensa(s) recolhida(s)!" "$GREEN_BLACK" "$COLOR_RESET"

    # Refresh após recolha para ver estado actualizado
    fetch_page "/missions/"
  fi

  # Mostra missões em progresso
  local active
  active=$(grep -c 'Passar a executar' "$TMP/SRC" 2>/dev/null || echo 0)
  local locked
  locked=$(grep -c 'Atualização através de' "$TMP/SRC" 2>/dev/null || echo 0)

  if [ "$active" -gt 0 ] || [ "$locked" -gt 0 ]; then
    echo_t "    Em progresso: ${active} | Bloqueadas: ${locked}" "$GRAY_BLACK" "$COLOR_RESET"
  fi
}

# ── Missão de combate especial (bz2) ────────────────────────
special_combat_mission() {
  if [ "$FUNC_special_missions" = "n" ]; then return; fi

  echo_t "Missão de Combate" "$GOLD_BLACK" "$COLOR_RESET" "after" "⭐"
  fetch_page "/bz2"

  if ! grep -q '<title>' "$TMP/SRC" 2>/dev/null; then
    go_hangar
    return
  fi

  # Recolhe recompensa se disponível (awardLink no bz2)
  local award_link
  award_link=$(grep -o -E ';jsessionid=[A-Z0-9]+\?[0-9]+-[0-9]+\.ILinkListener-[^"]*awardLink[^"]*' \
    "$TMP/SRC" | head -n1)

  if [ -n "$award_link" ]; then
    echo_t "  🎁 A recolher recompensa bz2..." "$GREEN_BLACK" "$COLOR_RESET"
    fetch_page "/${award_link}"
    echo_t "  ✅ Recompensa recolhida!" "$GREEN_BLACK" "$COLOR_RESET"
    sleep 0.5s
  else
    echo_t "  Sem recompensa disponível agora." "$GRAY_BLACK" "$COLOR_RESET"
  fi

  go_hangar
}

# ── Recolhe tudo ─────────────────────────────────────────────
collect_all_rewards() {
  echo_t "A recolher recompensas..." "$GOLD_BLACK" "$COLOR_RESET" "after" "💰"
  missions_func
  special_combat_mission
  echo_t "Recolha concluída." "$GREEN_BLACK" "$COLOR_RESET" "after" "✅"
}
