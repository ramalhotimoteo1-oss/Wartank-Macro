#!/bin/bash
# ============================================================
# cw.sh — Guerra (Clan War)
# HTML real confirmado — batalha activa e lobby
# ============================================================
# Lobby (/cw):
#   Título: "Guerra"
#   País: class="green1">10. Alemanha
#   Início: "Start in HH:MM:SS"
#   Tokens: "My tokens: X de 500"
#   Refresh tokens: cw?11-1.ILinkListener-jettonsView-refresh
#
# Batalha activa (/cw com batalha):
#   Título: "Guerra" (mantém-se)
#   HP: value-block lh1 → 2846 (jogador), 1886 (inimigo)
#   Links: cw?12-9.ILinkListener-currentControl-buttons-X
#     attackRegularShellLink  → SIMPLES
#     attackSpecialShellLink  → DE CARGA OCA (1533)
#     repairLink              → kit de reparação
#     maneuverLink            → Manobra
#     changeTargetLink        → Mudar de objetivo
#     escape                  → Abandonar o combate
#   Info: "dos Tanques no combate: 94 / 20"
#         "das Divisões no combate: 10"
#         "03:47" (tempo restante)
#
# TIMING (horário de verão PT):
#   NÃO usa horários fixos — verifica dinamicamente
#   A guerra muda de território — horário varia
#   Alemanha: ~18:20 ou ~19:20 (inverno/verão)
#   Bot detecta botão de entrada disponível na página
# ============================================================

# ── Verifica e entra em guerra se disponível ────────────────
cw_check_and_apply() {
  if [ "$FUNC_cw" = "n" ]; then return; fi

  fetch_page "/cw"
  if ! _session_active; then return; fi

  # Detecta se está numa batalha activa (tem attackRegularShellLink)
  if grep -q 'currentControl-buttons-attackRegularShellLink' "$SRC" 2>/dev/null; then
    echo_t "CW: Batalha activa detectada!" "$GOLD_BLACK" "$COLOR_RESET"
    _cw_fight_active
    return
  fi

  # Detecta link de entrada (enterLink ou joinLink)
  local enter_link
  enter_link=$(grep -o -E 'cw\?[0-9]+-[0-9]+\.ILinkListener-[^"]*\(enterLink\|joinLink\|apply\)[^"]*' \
    "$SRC" | head -n1)

  # Também tenta o botão "apply" da visão geral
  [ -z "$enter_link" ] && \
    enter_link=$(grep -o -E 'cw\?[0-9]+-[0-9]+\.ILinkListener-currentOverview-apply' \
      "$SRC" | head -n1)

  if [ -n "$enter_link" ]; then
    local war_country war_start
    war_country=$(grep -o -E 'class="green1">[^<]+' "$SRC" | sed 's/.*">//' | head -n1)
    war_start=$(grep -o -E 'Start in [0-9]{2}:[0-9]{2}:[0-9]{2}' "$SRC" | head -n1)
    echo_t "CW: A entrar — ${war_country:-?} ${war_start:-}" \
      "$GOLD_BLACK" "$COLOR_RESET"
    fetch_page "/${enter_link}"
    sleep_rand 500 1000

    # Aguarda o ecrã "Preparando Combate" e a batalha iniciar
    _cw_wait_battle_start
  else
    # Apenas verifica estado e tokens
    local war_country war_start tokens
    war_country=$(grep -o -E 'class="green1">[^<]+' "$SRC" | sed 's/.*">//' | head -n1)
    war_start=$(grep -o -E 'Start in [0-9]{2}:[0-9]{2}:[0-9]{2}' "$SRC" | head -n1)
    tokens=$(grep -o -E 'My tokens:[^0-9]*[0-9]+' "$SRC" \
      | grep -o -E '[0-9]+' | head -n1)
    echo_t "CW: ${war_country:-sem guerra} | ${war_start:-?} | Tokens: ${tokens:-0}" \
      "$GRAY_BLACK" "$COLOR_RESET"
  fi
}

cw_mode() {
  if [ "$FUNC_cw" = "n" ]; then return; fi
  cw_check_and_apply
}

# ── Aguarda ecrã "Preparando Combate" → batalha inicia ──────
_cw_wait_battle_start() {
  local timeout=$(( $(date +%s) + 60 ))
  echo_t "   Preparando combate CW..." "$GRAY_BLACK" "$COLOR_RESET"

  while [ "$(date +%s)" -lt "$timeout" ]; do
    # Batalha iniciada?
    if grep -q 'currentControl-buttons-attackRegularShellLink' "$SRC" 2>/dev/null; then
      echo_t "  [combate] Batalha CW iniciada!" "$GREEN_BLACK" "$COLOR_RESET"
      _cw_fight_active
      return
    fi

    # Refresh enquanto aguarda
    local refresh_link
    refresh_link=$(grep -o -E 'cw\?[0-9]+-[0-9]+\.ILinkListener-[^"]*refresh[^"]*' \
      "$SRC" | head -n1)
    [ -n "$refresh_link" ] && fetch_page "/${refresh_link}" || fetch_page "/cw"
    sleep_rand 2000 4000
  done

  echo_t "  Timeout a aguardar batalha CW." "$BLACK_YELLOW" "$COLOR_RESET"
}

# ── Extrai links de combate da batalha CW activa ────────────
_cw_extract() {
  # Padrão real: cw?12-9.ILinkListener-currentControl-buttons-X
  CW_ATK=$(grep -o -E 'cw\?[0-9]+-[0-9]+\.ILinkListener-currentControl-buttons-attackRegularShellLink' \
    "$SRC" | head -n1)
  CW_ATK_SPECIAL=$(grep -o -E 'cw\?[0-9]+-[0-9]+\.ILinkListener-currentControl-buttons-attackSpecialShellLink' \
    "$SRC" | head -n1)
  CW_REPAIR=$(grep -o -E 'cw\?[0-9]+-[0-9]+\.ILinkListener-currentControl-buttons-repairLink' \
    "$SRC" | head -n1)
  CW_MANEUVER=$(grep -o -E 'cw\?[0-9]+-[0-9]+\.ILinkListener-currentControl-buttons-maneuverLink' \
    "$SRC" | head -n1)
  CW_CHANGE=$(grep -o -E 'cw\?[0-9]+-[0-9]+\.ILinkListener-currentControl-buttons-changeTargetLink' \
    "$SRC" | head -n1)
  CW_ESCAPE=$(grep -o -E 'cw\?[0-9]+-[0-9]+\.ILinkListener-currentControl-escape' \
    "$SRC" | head -n1)

  # HP jogador e inimigo
  # HTML: value-block lh1 → 1º=jogador, 2º=inimigo
  CW_HP_PLAYER=$(grep -o -E 'value-block lh1[^>]*>[^<]*<[^>]*>[^<]*>[0-9]+' "$SRC" \
    | grep -o -E '[0-9]+$' | sed -n '1p')
  CW_HP_ENEMY=$(grep -o -E 'value-block lh1[^>]*>[^<]*<[^>]*>[^<]*>[0-9]+' "$SRC" \
    | grep -o -E '[0-9]+$' | sed -n '2p')

  # Info da batalha
  CW_TANKS=$(grep -o -E 'dos Tanques no combate: [0-9]+' "$SRC" | grep -o -E '[0-9]+' | head -n1)
  CW_TIME=$(grep -o -E '[0-9]{2}:[0-9]{2}' "$SRC" | tail -n1)
}

# ── Loop de combate CW ───────────────────────────────────────
_cw_fight_active() {
  _cw_extract

  # Guarda HP máximo no início
  local hp_max="${CW_HP_PLAYER:-0}"
  local last_repair=0
  local last_maneuver=0
  local last_atk=0
  local shots=0
  local timeout=$(( $(date +%s) + 600 )) # 10 min max

  echo_t "  [combate] CW — HP: ${CW_HP_PLAYER:-?} vs ${CW_HP_ENEMY:-?} | Tanques: ${CW_TANKS:-?}" \
    "$GOLD_BLACK" "$COLOR_RESET"

  while [ "$(date +%s)" -lt "$timeout" ]; do
    _cw_extract

    # Batalha terminou?
    if [ -z "$CW_ATK" ] && [ -z "$CW_ESCAPE" ]; then
      echo_t "  🏁 Batalha CW terminou." "$GREEN_BLACK" "$COLOR_RESET"
      break
    fi

    local now since_atk since_repair since_maneuver
    now=$(date +%s)
    since_atk=$(( now - last_atk ))
    since_repair=$(( now - last_repair ))
    since_maneuver=$(( now - last_maneuver ))

    # ── Repair ────────────────────────────────────────────────
    if [ -n "$CW_REPAIR" ] && [ -n "$CW_HP_PLAYER" ] && [ "$hp_max" -gt 0 ]; then
      local hp_pct
      hp_pct=$(awk -v n="$CW_HP_PLAYER" -v m="$hp_max" \
        'BEGIN{printf"%.0f",n/m*100}')
      if [ "$hp_pct" -le "${BATTLE_REPAIR_PCT:-30}" ] && \
         [ "$since_repair" -ge "${BATTLE_REPAIR_CD:-90}" ]; then
        echo_t "   CW Repair! HP: ${CW_HP_PLAYER} (${hp_pct}%)" "$BLACK_YELLOW" "$COLOR_RESET"
        fetch_page "/${CW_REPAIR}"
        last_repair=$now
        _cw_extract
        continue
      fi
    fi

    # ── Manobra ───────────────────────────────────────────────
    if [ -n "$CW_MANEUVER" ] && [ "$since_maneuver" -ge "${BATTLE_MANEUVER_CD:-20}" ]; then
      if grep -q 'disparou a\|danos' "$SRC" 2>/dev/null; then
        echo_t "  [divisao] CW Manobra!" "$BLUE_BLACK" "$COLOR_RESET"
        fetch_page "/${CW_MANEUVER}"
        last_maneuver=$now
        _cw_extract
        continue
      fi
    fi

    # ── Disparo ───────────────────────────────────────────────
    if [ -n "$CW_ATK" ] && [ "$since_atk" -ge "${BATTLE_LA:-3}" ]; then
      fetch_page "/${CW_ATK}"
      last_atk=$now
      shots=$(( shots + 1 ))
      _cw_extract
      echo_t "  [dm] CW #${shots} | HP: ${CW_HP_PLAYER:-?} vs ${CW_HP_ENEMY:-?} | ⏱️ ${CW_TIME:-?}" \
        "$GRAY_BLACK" "$COLOR_RESET"
    else
      sleep_rand 800 1500
    fi
  done

  echo_t "CW: ${shots} disparos." "$GREEN_BLACK" "$COLOR_RESET"
  go_hangar
}
