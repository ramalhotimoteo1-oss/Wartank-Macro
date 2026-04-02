#!/bin/bash
# ============================================================
# assault.sh — Missão Especial (Assault)
# Baseado no HTML real de /company/assault
# ============================================================
# Estrutura real confirmada:
#   Título: "Missão especial"
#   Rota: /company/assault
#   Recompensa: 250 ouro por destruição do objetivo
#
#   Alvos disponíveis (assaults-N-joinLink):
#     0: Fortress (Fortaleza)
#     1: Búnquer
#     2: Casamata fortificada
#     3: Blockhouse
#     4: Abrigo subterrâneo
#
#   Entrar num alvo:
#     assault?31-1.ILinkListener-allAssaults-assaults-N-joinLink
#
#   Dentro da missão (overview):
#     Atualizar:         assault?36-3.ILinkListener-overview-refreshLink
#     Começar combate:   assault?36-3.ILinkListener-overview-startBattleLink
#     Rejeitar:          assault?36-3.ILinkListener-overview-unapplyLink
#     Tanquistas: 1 de 10
#
#   NOTA: É missão de clã — precisa de outros membros
#         Bot entra, actualiza e inicia se houver suficientes
# ============================================================

assault_mode() {
  if [ "$FUNC_assault" = "n" ]; then return; fi

  echo_t "Missão Especial (Assault)" "$GOLD_BLACK" "$COLOR_RESET"

  fetch_page "/company/assault"

  if ! _session_active; then
    echo_t "Sessão inválida na Missão Especial." "$BLACK_RED" "$COLOR_RESET"
    go_hangar
    return
  fi

  if ! grep -q '<title>Missão especial</title>' "$TMP/SRC" 2>/dev/null; then
    echo_t "Página de Missão Especial não encontrada." "$BLACK_YELLOW" "$COLOR_RESET"
    go_hangar
    return
  fi

  # Verifica se já está dentro de uma missão (overview)
  if grep -q 'overview-startBattleLink\|overview-refreshLink' "$TMP/SRC" 2>/dev/null; then
    echo_t "  Já está numa missão activa." "$GOLD_BLACK" "$COLOR_RESET"
    _assault_handle_active
    return
  fi

  # Lista alvos disponíveis e entra no primeiro
  _assault_join_first
}

_assault_join_first() {
  # Padrão real: assault?31-1.ILinkListener-allAssaults-assaults-N-joinLink
  local join_links
  join_links=$(grep -o -E 'assault\?[0-9]+-[0-9]+\.ILinkListener-allAssaults-assaults-[0-9]+-joinLink' \
    "$TMP/SRC" 2>/dev/null)

  if [ -z "$join_links" ]; then
    echo_t "  Sem missões especiais disponíveis." "$GRAY_BLACK" "$COLOR_RESET"
    go_hangar
    return
  fi

  # Lista alvos
  local targets
  targets=$(grep -o -E 'class="small white cntr sh_b bold mb2">[^<]+' "$TMP/SRC" \
    | sed 's/.*">//' | grep -v 'Objetivo\|Commandante\|Tanquistas' | head -5)
  echo_t "  Alvos disponíveis:" "$GRAY_BLACK" "$COLOR_RESET"
  echo "$targets" | while IFS= read -r t; do
    [ -n "$t" ] && echo_t "    🎯 ${t}" "$GRAY_BLACK" "$COLOR_RESET"
  done

  # Entra no primeiro alvo disponível
  local first_link
  first_link=$(echo "$join_links" | head -n1)
  local target_idx
  target_idx=$(echo "$first_link" | grep -o -E 'assaults-[0-9]+' | grep -o -E '[0-9]+')

  local target_names=("Fortress" "Búnquer" "Casamata" "Blockhouse" "Abrigo subterrâneo")
  local target_name="${target_names[$target_idx]:-Alvo ${target_idx}}"

  echo_t "   A entrar em: ${target_name}..." "$GREEN_BLACK" "$COLOR_RESET"
  fetch_page "/${first_link}"
  sleep 1s

  if _session_active && grep -q 'overview-refreshLink' "$TMP/SRC" 2>/dev/null; then
    echo_t "   Entrou na missão!" "$GREEN_BLACK" "$COLOR_RESET"
    _assault_handle_active
  else
    echo_t "  Não foi possível entrar na missão." "$BLACK_YELLOW" "$COLOR_RESET"
    go_hangar
  fi
}

_assault_handle_active() {
  # Extrai info da missão activa
  local objective members start_link refresh_link unapply_link
  objective=$(grep -o -E 'Objetivo: [^<]+' "$TMP/SRC" | sed 's/Objetivo: //' | head -n1)
  members=$(grep -o -E 'Tanquistas: [0-9]+ de [0-9]+' "$TMP/SRC" | head -n1)

  echo_t "  🎯 ${objective:-?}" "$GRAY_BLACK" "$COLOR_RESET"
  echo_t "  👥 ${members:-?}" "$GRAY_BLACK" "$COLOR_RESET"

  refresh_link=$(grep -o -E 'assault\?[0-9]+-[0-9]+\.ILinkListener-overview-refreshLink' \
    "$TMP/SRC" | head -n1)
  start_link=$(grep -o -E 'assault\?[0-9]+-[0-9]+\.ILinkListener-overview-startBattleLink' \
    "$TMP/SRC" | head -n1)
  unapply_link=$(grep -o -E 'assault\?[0-9]+-[0-9]+\.ILinkListener-overview-unapplyLink' \
    "$TMP/SRC" | head -n1)

  # Aguarda membros suficientes (máx 2 min)
  local timeout=$(( $(date +%s) + 120 ))
  local min_members="${ASSAULT_MIN_MEMBERS:-2}"

  while [ "$(date +%s)" -lt "$timeout" ]; do
    local current_members
    current_members=$(grep -o -E 'Tanquistas: [0-9]+' "$TMP/SRC" | grep -o -E '[0-9]+' | head -n1)

    echo_t "   Membros: ${current_members:-?}/${min_members} (mín)" "$GRAY_BLACK" "$COLOR_RESET"

    if [ -n "$current_members" ] && [ "$current_members" -ge "$min_members" ]; then
      # Membros suficientes — inicia combate
      if [ -n "$start_link" ]; then
        echo_t "  [combate] A iniciar o combate!" "$RED_BLACK" "$COLOR_RESET"
        fetch_page "/${start_link}"
        sleep 2s
        echo_t "  [assalto] Missão especial iniciada!" "$GREEN_BLACK" "$COLOR_RESET"
      fi
      break
    fi

    # Refresh para actualizar membros
    if [ -n "$refresh_link" ]; then
      fetch_page "/${refresh_link}"
      refresh_link=$(grep -o -E 'assault\?[0-9]+-[0-9]+\.ILinkListener-overview-refreshLink' \
        "$TMP/SRC" | head -n1)
      start_link=$(grep -o -E 'assault\?[0-9]+-[0-9]+\.ILinkListener-overview-startBattleLink' \
        "$TMP/SRC" | head -n1)
    fi

    sleep 15s
  done

  # Timeout — rejeita se não houver membros suficientes
  if [ "$(date +%s)" -ge "$timeout" ]; then
    echo_t "  Tempo esgotado. A rejeitar missão..." "$BLACK_YELLOW" "$COLOR_RESET"
    if [ -n "$unapply_link" ]; then
      fetch_page "/${unapply_link}"
    fi
  fi

  echo_t "Missão Especial concluída." "$GREEN_BLACK" "$COLOR_RESET"
  go_hangar
}
