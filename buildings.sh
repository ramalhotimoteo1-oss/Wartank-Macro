#!/bin/bash
# ============================================================
# buildings.sh — Base (Edifícios)
# Baseado no HTML real de /buildings
# ============================================================
# Estrutura real confirmada:
#   Título: "Base"
#   Recursos: Minério 45768 | Ferro 3729 | Aço 1794 | Chumbo 650
#
#   Edifícios com produção para recolher (botão "Pegar"):
#     Mina:           buildings?28-1.ILinkListener-buildings-0-building-rootBlock-actionPanel-takeProductionLink
#     Sala de armas:  buildings?28-1.ILinkListener-buildings-2-building-rootBlock-actionPanel-takeProductionLink
#     Banco:          buildings?28-1.ILinkListener-buildings-3-building-rootBlock-actionPanel-takeProductionLink
#
#   Edifícios sem recolha (só detalhes/produção):
#     Polígono:              href="polygon"
#     Armazém combustível:   href="fuelStore"
#     Mercado:               href="market"
#     Laboratório:           href="laboratory"
#
#   Padrão geral de recolha:
#     buildings?X-X.ILinkListener-buildings-N-building-rootBlock-actionPanel-takeProductionLink
# ============================================================

buildings_func() {
  if [ "$FUNC_buildings" = "n" ]; then return; fi

  echo_t "Base (Edifícios)" "$GOLD_BLACK" "$COLOR_RESET"

  fetch_page "/buildings"

  if ! _session_active; then
    echo_t "Sessão inválida na Base." "$BLACK_RED" "$COLOR_RESET"
    go_hangar
    return
  fi

  if ! grep -q '<title>Base</title>' "$TMP/SRC" 2>/dev/null; then
    echo_t "Página de Base não encontrada." "$BLACK_YELLOW" "$COLOR_RESET"
    go_hangar
    return
  fi

  # Mostra recursos actuais
  _buildings_show_resources

  # Recolhe produção de todos os edifícios disponíveis
  _buildings_collect_all

  echo_t "Base concluída." "$GREEN_BLACK" "$COLOR_RESET"
  go_hangar
}

_buildings_show_resources() {
  # HTML real: <img ... alt="Minério"/> 45768
  local ore iron steel lead
  ore=$(grep -o -E 'alt="Minério"[^0-9]*[0-9]+' "$TMP/SRC" | grep -o -E '[0-9]+' | head -n1)
  iron=$(grep -o -E 'alt="Ferro"[^0-9]*[0-9]+' "$TMP/SRC" | grep -o -E '[0-9]+' | head -n1)
  steel=$(grep -o -E 'alt="Aço"[^0-9]*[0-9]+' "$TMP/SRC" | grep -o -E '[0-9]+' | head -n1)
  lead=$(grep -o -E 'alt="Chumbo"[^0-9]*[0-9]+' "$TMP/SRC" | grep -o -E '[0-9]+' | head -n1)

  echo_t "  ⛏️ Minério: ${ore:-?}  🔩 Ferro: ${iron:-?}   Aço: ${steel:-?}  🔫 Chumbo: ${lead:-?}" \
    "$GRAY_BLACK" "$COLOR_RESET"
}

_buildings_collect_all() {
  local collected=0

  # Padrão real de recolha:
  # buildings?28-1.ILinkListener-buildings-N-building-rootBlock-actionPanel-takeProductionLink
  local take_links
  take_links=$(grep -o -E 'buildings\?[0-9]+-[0-9]+\.ILinkListener-buildings-[0-9]+-building-rootBlock-actionPanel-takeProductionLink' \
    "$TMP/SRC" 2>/dev/null)

  if [ -z "$take_links" ]; then
    echo_t "  Sem produção para recolher agora." "$GRAY_BLACK" "$COLOR_RESET"
    return
  fi

  while IFS= read -r link; do
    [ -z "$link" ] && continue

    # Identifica qual edifício pelo índice (buildings-N-)
    local idx building_name
    idx=$(echo "$link" | grep -o -E 'buildings-[0-9]+' | grep -o -E '[0-9]+' | head -n1)
    case "$idx" in
      0) building_name="Mina" ;;
      1) building_name="Polígono" ;;
      2) building_name="Sala de armas" ;;
      3) building_name="Banco" ;;
      4) building_name="Armazém" ;;
      *) building_name="Edifício ${idx}" ;;
    esac

    echo_t "   A recolher: ${building_name}..." "$GREEN_BLACK" "$COLOR_RESET"
    fetch_page "/${link}"
    collected=$(( collected + 1 ))
    sleep 0.5s
  done <<< "$take_links"

  if [ "$collected" -gt 0 ]; then
    echo_t "   ${collected} edifício(s) recolhido(s)!" "$GREEN_BLACK" "$COLOR_RESET"
    # Actualiza recursos após recolha
    fetch_page "/buildings"
    _buildings_show_resources
  fi
}
