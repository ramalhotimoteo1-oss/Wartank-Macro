#!/bin/bash
# ============================================================
# pve.sh — Módulo PvE (Batalhas Históricas)
# Baseado no HTML real de /pve
# ============================================================
# Estrutura real confirmada:
#   Título: "Batalhas"
#   Próxima batalha: href="pve?8-1.ILinkListener-currentOverview-apply"
#     Botão: "Pelotão, de pé! Ao ataque!"
#   Refresh: href="pve?8-1.ILinkListener-refresh"
#   Tipos: "Operação ofensiva" | "Operação defensiva"
#   Batalhas a cada 2h: 06:57, 08:57, 10:57, 12:57, 14:57, 16:57, 18:57, 21:57
#
# NOTA: O tanque luta sozinho mesmo sem participar.
#       Participar dá recompensa maior.
#       Aplicar = entrar na batalha para o próximo inicio.
# ============================================================

pve_mode() {
  if [ "$FUNC_pve" = "n" ]; then return; fi

  echo_t "PvE — Batalhas Históricas" "$GOLD_BLACK" "$COLOR_RESET" "after" "🎖️"

  fetch_page "/pve"

  if ! _session_active; then
    echo_t "Sessão inválida no PvE." "$BLACK_RED" "$COLOR_RESET" "after" "❌"
    go_hangar
    return
  fi

  if ! grep -q '<title>Batalhas</title>' "$TMP/SRC" 2>/dev/null; then
    echo_t "Página PvE não encontrada." "$BLACK_YELLOW" "$COLOR_RESET" "after" "⚠️"
    go_hangar
    return
  fi

  # Informação da próxima batalha
  local next_battle next_time battle_type
  next_battle=$(grep -o -E 'class="green2">[^<]+' "$TMP/SRC" | sed 's/.*">//' | head -n1)
  next_time=$(grep -o -E 'até o início [0-9]{2}:[0-9]{2}:[0-9]{2}' "$TMP/SRC" | head -n1)
  battle_type=$(grep -o -E 'Operação (ofensiva|defensiva)' "$TMP/SRC" | head -n1)

  echo_t "  📍 ${next_battle:-?}" "$GRAY_BLACK" "$COLOR_RESET"
  echo_t "  ⏰ ${next_time:-?}" "$GRAY_BLACK" "$COLOR_RESET"
  echo_t "  🎯 ${battle_type:-?}" "$GRAY_BLACK" "$COLOR_RESET"

  # Aplica na batalha disponível
  local apply_link
  # HTML real: href="pve?8-1.ILinkListener-currentOverview-apply"
  apply_link=$(grep -o -E 'pve\?[0-9]+-[0-9]+\.ILinkListener-currentOverview-apply' \
    "$TMP/SRC" | head -n1)

  if [ -n "$apply_link" ]; then
    echo_t "  ✅ A aplicar na batalha..." "$GREEN_BLACK" "$COLOR_RESET"
    fetch_page "/${apply_link}"
    sleep 1s

    # Verifica se entrou
    if _session_active && ! grep -q 'currentOverview-apply' "$TMP/SRC" 2>/dev/null; then
      echo_t "  🎖️ Aplicado com sucesso!" "$GREEN_BLACK" "$COLOR_RESET"
    fi
  else
    echo_t "  Sem batalha disponível para aplicar agora." "$GRAY_BLACK" "$COLOR_RESET"

    # Mostra próximas batalhas
    echo_t "  Próximas batalhas:" "$GRAY_BLACK" "$COLOR_RESET"
    grep -o -E 'class="green2">[^<]+' "$TMP/SRC" | sed 's/.*">/    📌 /' | head -5 | \
      while IFS= read -r line; do
        echo_t "$line" "$GRAY_BLACK" "$COLOR_RESET"
      done
  fi

  echo_t "PvE concluído." "$GREEN_BLACK" "$COLOR_RESET" "after" "✅"
  go_hangar
}

# ── Verifica e aplica em PvE se estiver na hora ──────────────
pve_check_and_apply() {
  fetch_page "/pve"
  if ! _session_active; then return; fi

  local apply_link
  apply_link=$(grep -o -E 'pve\?[0-9]+-[0-9]+\.ILinkListener-currentOverview-apply' \
    "$TMP/SRC" | head -n1)

  if [ -n "$apply_link" ]; then
    local battle next_time
    battle=$(grep -o -E 'class="green2">[^<]+' "$TMP/SRC" | sed 's/.*">//' | head -n1)
    next_time=$(grep -o -E 'até o início [0-9]{2}:[0-9]{2}:[0-9]{2}' "$TMP/SRC" | head -n1)
    echo_t "PvE: A aplicar em ${battle:-batalha}... ${next_time}" "$GOLD_BLACK" "$COLOR_RESET" "after" "🎖️"
    fetch_page "/${apply_link}"
    sleep 1s
  fi
}

# ── Dentro da batalha PvE activa ─────────────────────────────
# (Chamado quando já está dentro da batalha)
pve_fight_active() {
  echo_t "PvE — Em batalha" "$GOLD_BLACK" "$COLOR_RESET" "after" "⚔️"

  local shots=0
  local timeout=$(( $(date +%s) + 600 ))
  local last_atk=0
  local last_repair=0
  local last_maneuver=0

  while [ "$(date +%s)" -lt "$timeout" ]; do
    # Extrai links da página actual de batalha PvE
    local atk repair maneuver exit_link hp_player

    atk=$(grep -o -E 'pve\?[0-9]+-[0-9]+\.ILinkListener-[^"]*[Aa]ttack[^"]*' \
      "$TMP/SRC" | grep -v 'buff\|glory' | head -n1)
    repair=$(grep -o -E 'pve\?[0-9]+-[0-9]+\.ILinkListener-[^"]*[Rr]epair[^"]*' \
      "$TMP/SRC" | head -n1)
    maneuver=$(grep -o -E 'pve\?[0-9]+-[0-9]+\.ILinkListener-[^"]*[Mm]aneuver[^"]*' \
      "$TMP/SRC" | head -n1)
    exit_link=$(grep -o -E 'pve\?[0-9]+-[0-9]+\.ILinkListener-[^"]*\(escape\|exit\|leave\)[^"]*' \
      "$TMP/SRC" | head -n1)
    hp_player=$(grep -o -E 'value-block lh1[^>]*>[^<]*<[^>]*>[^<]*>[0-9]+' "$TMP/SRC" \
      | grep -o -E '[0-9]+$' | sed -n '1p')

    # Batalha terminou?
    if [ -z "$atk" ] && [ -z "$exit_link" ]; then
      echo_t "  🏁 Batalha PvE terminou." "$GREEN_BLACK" "$COLOR_RESET"
      break
    fi

    local now since_atk
    now=$(date +%s)
    since_atk=$(( now - last_atk ))

    # Repair
    if [ -n "$repair" ] && [ -n "$hp_player" ]; then
      local since_repair
      since_repair=$(( now - last_repair ))
      if [ "$since_repair" -ge "${BATTLE_REPAIR_CD:-90}" ]; then
        echo_t "  🔧 Repair PvE!" "$BLACK_YELLOW" "$COLOR_RESET"
        fetch_page "/${repair}"
        last_repair=$now
        continue
      fi
    fi

    # Manobra
    if [ -n "$maneuver" ]; then
      local since_maneuver
      since_maneuver=$(( now - last_maneuver ))
      if [ "$since_maneuver" -ge "${BATTLE_MANEUVER_CD:-20}" ] && \
         grep -q 'disparou a\|danos' "$TMP/SRC" 2>/dev/null; then
        echo_t "  🛡️ Manobra PvE!" "$BLUE_BLACK" "$COLOR_RESET"
        fetch_page "/${maneuver}"
        last_maneuver=$now
        continue
      fi
    fi

    # Disparo
    if [ -n "$atk" ] && [ "$since_atk" -ge "${BATTLE_LA:-3}" ]; then
      fetch_page "/${atk}"
      last_atk=$now
      shots=$(( shots + 1 ))
      echo_t "  💥 PvE #${shots} | HP: ${hp_player:-?}" "$GRAY_BLACK" "$COLOR_RESET"
    else
      sleep 1s
    fi
  done

  echo_t "  Disparos PvE: ${shots}" "$GRAY_BLACK" "$COLOR_RESET"
  go_hangar
}
