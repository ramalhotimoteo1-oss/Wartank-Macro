#!/bin/bash
# ============================================================
# dm.sh — Disputa (Deathmatch)
# HTML real confirmado — lobby e batalha activa
# ============================================================
# Lobby (/dm):
#   Título: "Combate" (partilhado com /battle)
#   Próxima: href="dm?14-1.ILinkListener-currentOverview-apply"
#   Botão: "Cada um por si!"
#   Refresh: href="dm?14-1.ILinkListener-refresh"
#   Horários: ~11:20, ~15:20, ~21:20 (podem variar com DST)
#
# Batalha activa:
#   Links: dm?16-53.ILinkListener-currentControl-buttons-X
#     attackRegularShellLink  → SIMPLES
#     attackSpecialShellLink  → PERFURANTES (4088)
#     repairLink              → kit de reparação
#     maneuverLink            → Manobra
#     changeTargetLink        → Mudar de objetivo
#     escape                  → Abandonar o combate
#   Info: "de Tanques no combate: 21"
#
# FLUXO:
#   apply → "Preparando Combate" (6s countdown) → batalha inicia
#   Bot não usa horários fixos — verifica apply dinamicamente
# ============================================================

# ── Verifica e aplica em DM se disponível ───────────────────
dm_check_and_apply() {
  if [ "$FUNC_dm" = "n" ]; then return; fi

  fetch_page "/dm"
  if ! _session_active; then return; fi

  # Batalha já activa?
  if grep -q 'currentControl-buttons-attackRegularShellLink' "$SRC" 2>/dev/null; then
    echo_t "DM: Batalha activa detectada!" "$GOLD_BLACK" "$COLOR_RESET" "after" "💥"
    _dm_fight_active
    return
  fi

  # Link de aplicar disponível?
  local apply_link
  apply_link=$(grep -o -E 'dm\?[0-9]+-[0-9]+\.ILinkListener-currentOverview-apply' \
    "$SRC" | head -n1)

  if [ -n "$apply_link" ]; then
    local next_time
    next_time=$(grep -o -E 'até o início [0-9]{2}:[0-9]{2}:[0-9]{2}' "$SRC" | head -n1)
    echo_t "DM: A aplicar... ${next_time:-}" "$GOLD_BLACK" "$COLOR_RESET" "after" "💥"
    fetch_page "/${apply_link}"
    sleep_rand 500 1000
    _dm_wait_battle_start
  fi
}

dm_mode() {
  if [ "$FUNC_dm" = "n" ]; then return; fi
  dm_check_and_apply
}

# ── Aguarda ecrã "Preparando Combate" (6s) → inicia ─────────
_dm_wait_battle_start() {
  local timeout=$(( $(date +%s) + 30 ))
  echo_t "  ⏳ Preparando combate DM (6s)..." "$GRAY_BLACK" "$COLOR_RESET"

  while [ "$(date +%s)" -lt "$timeout" ]; do
    if grep -q 'currentControl-buttons-attackRegularShellLink' "$SRC" 2>/dev/null; then
      echo_t "  💥 Batalha DM iniciada!" "$GREEN_BLACK" "$COLOR_RESET"
      _dm_fight_active
      return
    fi

    local refresh_link
    refresh_link=$(grep -o -E 'dm\?[0-9]+-[0-9]+\.ILinkListener-[^"]*refresh[^"]*' \
      "$SRC" | head -n1)
    [ -n "$refresh_link" ] && fetch_page "/${refresh_link}" || fetch_page "/dm"
    sleep_rand 2000 3000
  done

  echo_t "  Timeout a aguardar DM." "$BLACK_YELLOW" "$COLOR_RESET"
}

# ── Extrai links de combate DM ───────────────────────────────
_dm_extract() {
  # Padrão real: dm?16-53.ILinkListener-currentControl-buttons-X
  DM_ATK=$(grep -o -E 'dm\?[0-9]+-[0-9]+\.ILinkListener-currentControl-buttons-attackRegularShellLink' \
    "$SRC" | head -n1)
  DM_ATK_SPECIAL=$(grep -o -E 'dm\?[0-9]+-[0-9]+\.ILinkListener-currentControl-buttons-attackSpecialShellLink' \
    "$SRC" | head -n1)
  DM_REPAIR=$(grep -o -E 'dm\?[0-9]+-[0-9]+\.ILinkListener-currentControl-buttons-repairLink' \
    "$SRC" | head -n1)
  DM_MANEUVER=$(grep -o -E 'dm\?[0-9]+-[0-9]+\.ILinkListener-currentControl-buttons-maneuverLink' \
    "$SRC" | head -n1)
  DM_CHANGE=$(grep -o -E 'dm\?[0-9]+-[0-9]+\.ILinkListener-currentControl-buttons-changeTargetLink' \
    "$SRC" | head -n1)
  DM_ESCAPE=$(grep -o -E 'dm\?[0-9]+-[0-9]+\.ILinkListener-currentControl-escape' \
    "$SRC" | head -n1)

  # HP
  DM_HP_PLAYER=$(grep -o -E 'value-block lh1[^>]*>[^<]*<[^>]*>[^<]*>[0-9]+' "$SRC" \
    | grep -o -E '[0-9]+$' | sed -n '1p')
  DM_HP_ENEMY=$(grep -o -E 'value-block lh1[^>]*>[^<]*<[^>]*>[^<]*>[0-9]+' "$SRC" \
    | grep -o -E '[0-9]+$' | sed -n '2p')

  DM_TANKS=$(grep -o -E 'de Tanques no combate: [0-9]+' "$SRC" | grep -o -E '[0-9]+' | head -n1)
}

# ── Loop de combate DM ───────────────────────────────────────
_dm_fight_active() {
  _dm_extract

  local hp_max="${DM_HP_PLAYER:-0}"
  local last_repair=0
  local last_maneuver=0
  local last_atk=0
  local shots=0
  local timeout=$(( $(date +%s) + 600 ))

  echo_t "  💥 DM — HP: ${DM_HP_PLAYER:-?} vs ${DM_HP_ENEMY:-?} | Tanques: ${DM_TANKS:-?}" \
    "$GOLD_BLACK" "$COLOR_RESET"

  while [ "$(date +%s)" -lt "$timeout" ]; do
    _dm_extract

    # Batalha terminou?
    if [ -z "$DM_ATK" ] && [ -z "$DM_ESCAPE" ]; then
      echo_t "  🏁 DM terminou." "$GREEN_BLACK" "$COLOR_RESET"
      break
    fi

    local now since_atk since_repair since_maneuver
    now=$(date +%s)
    since_atk=$(( now - last_atk ))
    since_repair=$(( now - last_repair ))
    since_maneuver=$(( now - last_maneuver ))

    # ── Repair ────────────────────────────────────────────────
    if [ -n "$DM_REPAIR" ] && [ -n "$DM_HP_PLAYER" ] && [ "$hp_max" -gt 0 ]; then
      local hp_pct
      hp_pct=$(awk -v n="$DM_HP_PLAYER" -v m="$hp_max" \
        'BEGIN{printf"%.0f",n/m*100}')
      if [ "$hp_pct" -le "${BATTLE_REPAIR_PCT:-30}" ] && \
         [ "$since_repair" -ge "${BATTLE_REPAIR_CD:-90}" ]; then
        echo_t "  🔧 DM Repair! HP: ${DM_HP_PLAYER} (${hp_pct}%)" "$BLACK_YELLOW" "$COLOR_RESET"
        fetch_page "/${DM_REPAIR}"
        last_repair=$now
        _dm_extract
        continue
      fi
    fi

    # ── Manobra ───────────────────────────────────────────────
    if [ -n "$DM_MANEUVER" ] && [ "$since_maneuver" -ge "${BATTLE_MANEUVER_CD:-20}" ]; then
      if grep -q 'disparou a\|danos' "$SRC" 2>/dev/null; then
        echo_t "  🛡️ DM Manobra!" "$BLUE_BLACK" "$COLOR_RESET"
        fetch_page "/${DM_MANEUVER}"
        last_maneuver=$now
        _dm_extract
        continue
      fi
    fi

    # ── Disparo ───────────────────────────────────────────────
    if [ -n "$DM_ATK" ] && [ "$since_atk" -ge "${BATTLE_LA:-3}" ]; then
      fetch_page "/${DM_ATK}"
      last_atk=$now
      shots=$(( shots + 1 ))
      _dm_extract
      echo_t "  💥 DM #${shots} | HP: ${DM_HP_PLAYER:-?} vs ${DM_HP_ENEMY:-?}" \
        "$GRAY_BLACK" "$COLOR_RESET"
    else
      sleep_rand 800 1500
    fi
  done

  echo_t "DM: ${shots} disparos." "$GREEN_BLACK" "$COLOR_RESET" "after" "✅"
  go_hangar
}
