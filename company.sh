#!/bin/bash
# ============================================================
# company.sh — Divisão (Clan)
# Baseado no HTML real de /company/
# ============================================================
# Estrutura real confirmada:
#   Título: "Divisão"
#   Rota: /company/
#   Divisão: "✰ANGELS KILLERS✰" (ID 230)
#   Teu nome: Omega Prime (ID 198689), general
#   Membros online: 5 de 20
#
#   Sub-rotas:
#     /company/missions  → missões da divisão
#     /company/assault   → missão especial
#     /company/hq        → quartel-general
#     /company/barracks  → caserna
#     /company/fuelDepot → depósito de combustível
#     /company/polygon   → polígono da divisão
#     ../bitva           → batalha de divisões
#
#   Info da divisão:
#     Experiência: 141'289'166 de 170'000'000
#     Tripulação: 1132 de 1400
#     Medalhas: 261 de 480
#     Nível: 32 (42%)
#     Territórios em guerra: 10
# ============================================================

company_func() {
  if [ "$FUNC_company" = "n" ]; then return; fi

  echo_t "Divisão" "$GOLD_BLACK" "$COLOR_RESET"

  fetch_page "/company/"

  if ! _session_active; then
    go_hangar; return
  fi

  if ! grep -q '<title>Divisão</title>' "$TMP/SRC" 2>/dev/null; then
    go_hangar; return
  fi

  # Info da divisão
  local clan_name clan_level members_online
  clan_name=$(grep -o -E 'class="green2"[^>]*>[^<]+' "$TMP/SRC" | sed 's/.*">//' | head -n1)
  clan_level=$(grep -o -E 'level\.png[^>]*/>[^0-9]*[0-9]+' "$TMP/SRC" | grep -o -E '[0-9]+' | head -n1)
  members_online=$(grep -o -E 'Тanquistas: [0-9]+ de [0-9]+' "$TMP/SRC" | head -n1)

  echo_t "  [divisao] ${clan_name:-?} | Nível: ${clan_level:-?}" "$GRAY_BLACK" "$COLOR_RESET"
  echo_t "  👥 ${members_online:-?}" "$GRAY_BLACK" "$COLOR_RESET"

  # Missões da divisão
  _company_missions

  echo_t "Divisão verificada." "$GREEN_BLACK" "$COLOR_RESET"
  go_hangar
}

_company_missions() {
  fetch_page "/company/missions"
  if ! _session_active; then return; fi

  # Recolhe recompensas de missões da divisão
  # Padrão similar às missões normais mas com /company/missions
  local award_links collected=0
  award_links=$(grep -o -E '[^"]*ILinkListener-[^"]*awardLink[^"]*' "$TMP/SRC" 2>/dev/null)

  if [ -n "$award_links" ]; then
    while IFS= read -r link; do
      [ -z "$link" ] && continue
      echo_t "   A recolher missão da divisão..." "$GREEN_BLACK" "$COLOR_RESET"
      fetch_page "/${link}"
      collected=$(( collected + 1 ))
      sleep 0.5s
    done <<< "$award_links"
    [ "$collected" -gt 0 ] && \
      echo_t "   ${collected} missão(ões) da divisão recolhida(s)!" "$GREEN_BLACK" "$COLOR_RESET"
  fi
}

# ── Depósito de combustível da divisão ──────────────────────
company_fuel_depot() {
  fetch_page "/company/fuelDepot"
  if ! _session_active; then return; fi

  # Recolhe combustível disponível
  local fuel_link
  fuel_link=$(grep -o -E 'fuelDepot\?[0-9]+-[0-9]+\.ILinkListener-[^"]*takeLink[^"]*' \
    "$TMP/SRC" | head -n1)

  if [ -n "$fuel_link" ]; then
    echo_t "   A recolher combustível da divisão..." "$GREEN_BLACK" "$COLOR_RESET"
    fetch_page "/${fuel_link}"
    echo_t "   Combustível recolhido!" "$GREEN_BLACK" "$COLOR_RESET"
  fi
}
