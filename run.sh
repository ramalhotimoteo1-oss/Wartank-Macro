#!/bin/bash
# run.sh — scheduler v1.5.0
# Fix: battle com intervalo fixo de 40 min
#      convoy com intervalo fixo de 40 min

# ── Timestamps de controlo ───────────────────────────────────
LAST_BATTLE_TS=0    # ultima batalha normal
LAST_CONVOY_TS=0    # ultima escolta

BATTLE_INTERVAL=2400   # 40 min em segundos
CONVOY_INTERVAL=2400   # 40 min em segundos

# ── Idle ─────────────────────────────────────────────────────
func_sleep() {
  local m
  printf -v m '%(%M)T' -1
  m=$((10#$m))
  if [ "$m" -ge 48 ]; then
    _idle_wait 20
  elif [ "$m" -ge 13 ] && [ "$m" -le 22 ]; then
    _idle_wait 20
  else
    _idle_wait 60
  fi
}

_idle_wait() {
  local wait="$1" count=0
  while [ "$count" -lt "$wait" ]; do
    if read -r -t 1 cmd 2>/dev/null; then
      case "$cmd" in
        stop|exit|q|x) echo "a parar..."; exit 0 ;;
        config) config_menu; load_config ;;
        status) go_hangar ;;
      esac
    fi
    count=$(( count + 1 ))
  done
}

# ── Battle: intervalo de 40 min ──────────────────────────────
_can_battle() {
  [ "$FUNC_battle" = "n" ] && return 1

  local now elapsed
  now=$(date +%s)
  elapsed=$(( now - LAST_BATTLE_TS ))

  # Ainda dentro do intervalo de 40 min?
  if [ "$elapsed" -lt "$BATTLE_INTERVAL" ]; then
    local remaining=$(( (BATTLE_INTERVAL - elapsed) / 60 ))
    echo "[battle] aguarda ~${remaining} min para proximo ciclo"
    return 1
  fi

  # Verifica combustivel actual
  go_hangar
  local fuel="${FUEL_CURRENT:-0}"

  if [ -z "$fuel" ] || [ "$fuel" -eq 0 ] 2>/dev/null; then
    echo "[battle] combustivel zero"
    return 1
  fi

  # Minimo: 90 (3 disparos = 1 inimigo)
  if [ "$fuel" -lt 90 ] 2>/dev/null; then
    local needed=$(( 90 - fuel ))
    local wait_min=$(( (needed * 464 / 30) / 60 ))
    echo "[battle] combustivel insuficiente ($fuel) — aguarda ~${wait_min} min"
    return 1
  fi

  echo "[battle] ok | combustivel: $fuel | intervalo: ${elapsed}s >= ${BATTLE_INTERVAL}s"
  return 0
}

# ── Convoy: intervalo de 40 min ──────────────────────────────
_can_convoy() {
  [ "$FUNC_convoy" = "n" ] && return 1

  local now elapsed
  now=$(date +%s)
  elapsed=$(( now - LAST_CONVOY_TS ))

  if [ "$elapsed" -lt "$CONVOY_INTERVAL" ]; then
    local remaining=$(( (CONVOY_INTERVAL - elapsed) / 60 ))
    echo "[convoy] aguarda ~${remaining} min"
    return 1
  fi

  return 0
}

# ── Verifica batalhas (CW/DM/PvE) ───────────────────────────
_check_battles() {
  if [ "$FUNC_cw" = "y" ]; then
    fetch_page "/cw"
    if _session_active && grep -q \
      'currentControl-buttons-attackRegularShellLink\|currentOverview-apply' \
      "$SRC" 2>/dev/null; then
      echo "[run] guerra disponivel"
      cw_check_and_apply
    fi
  fi

  if [ "$FUNC_dm" = "y" ]; then
    fetch_page "/dm"
    if _session_active && grep -q \
      'currentControl-buttons-attackRegularShellLink\|currentOverview-apply' \
      "$SRC" 2>/dev/null; then
      echo "[run] disputa disponivel"
      dm_check_and_apply
    fi
  fi

  if [ "$FUNC_pve" = "y" ]; then
    fetch_page "/pve"
    if _session_active && grep -q \
      'currentControl-attackRegularShellLink\|currentOverview-apply' \
      "$SRC" 2>/dev/null; then
      echo "[run] pve disponivel"
      pve_check_and_apply
    fi
  fi
}

# ── Manutencao ───────────────────────────────────────────────
_maintenance() {
  # Battle: so a cada 40 min
  if _can_battle; then
    adiante_a_combate
    LAST_BATTLE_TS=$(date +%s)
  fi

  # Missoes
  [ "$FUNC_missions" = "y" ] && collect_all_rewards

  # Base
  [ "$FUNC_buildings" = "y" ] && buildings_func

  # Escolta: so a cada 40 min
  if _can_convoy; then
    convoy_mode
    LAST_CONVOY_TS=$(date +%s)
  fi

  # Divisao + missao especial
  [ "$FUNC_company" = "y" ] && company_func
  [ "$FUNC_assault" = "y" ] && assault_mode
}

start() {
  _maintenance
  go_hangar
  func_sleep
}

_check_pvp_time() {
  [ "$FUNC_pvp" = "y" ] || return 1
  local h
  printf -v h '%(%H)T' -1
  [ "$((10#$h))" -eq "${FUNC_pvp_hour:-21}" ] && return 0
  return 1
}

wartank_play() {
  require_login || return

  if _check_pvp_time; then
    fetch_page "/pvp"
    if _session_active && grep -q 'ILinkListener-joinLink' "$SRC" 2>/dev/null; then
      echo "[run] pvp disponivel"
      pvp_mode
      return
    fi
  fi

  _check_battles
  start
}
