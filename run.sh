#!/bin/bash
# run.sh — scheduler v1.2.0
# Deteccao dinamica — sem horarios fixos (resiste ao DST)
# PvP: horario fixo configuravel (FUNC_pvp_hour)

func_sleep() {
  local m
  printf -v m '%(%M)T' -1
  m=$((10#$m))
  # minutos 48-59 = ciclos curtos (batalhas aproximam-se)
  # minutos 13-22 = verifica DM
  if [ "$m" -ge 48 ]; then
    _idle_wait 20
  elif [ "$m" -ge 13 ] && [ "$m" -le 22 ]; then
    _idle_wait 20
  else
    _idle_wait 60
  fi
}

_idle_wait() {
  local wait="$1" h m count=0
  printf -v h '%(%H)T' -1
  printf -v m '%(%M)T' -1
  echo "[$h:$m] idle ${wait}s | combustivel: ${FUEL_CURRENT:-?}"

  while [ "$count" -lt "$wait" ]; do
    if read -r -t 1 cmd 2>/dev/null; then
      case "$cmd" in
        stop|exit|q|x) echo "a parar..."; exit 0 ;;
        config) config_menu ;;
        status) hangar_status ;;
      esac
    fi
    count=$(( count + 1 ))
  done
}

_check_battles() {
  local found=1

  if [ "$FUNC_cw" = "y" ]; then
    fetch_page "/cw"
    if _session_active && grep -q \
      'currentControl-buttons-attackRegularShellLink\|currentOverview-apply' \
      "$SRC" 2>/dev/null; then
      echo "[run] guerra disponivel"
      cw_check_and_apply
      found=0
    fi
  fi

  if [ "$FUNC_dm" = "y" ]; then
    fetch_page "/dm"
    if _session_active && grep -q \
      'currentControl-buttons-attackRegularShellLink\|currentOverview-apply' \
      "$SRC" 2>/dev/null; then
      echo "[run] disputa disponivel"
      dm_check_and_apply
      found=0
    fi
  fi

  if [ "$FUNC_pve" = "y" ]; then
    fetch_page "/pve"
    if _session_active && grep -q 'currentOverview-apply' "$SRC" 2>/dev/null; then
      echo "[run] pve disponivel"
      pve_check_and_apply
      found=0
    fi
  fi

  return $found
}

_maintenance() {
  load_config
  collect_all_rewards
  [ "$FUNC_buildings" = "y" ] && buildings_func
  [ "$FUNC_convoy" = "y" ]    && convoy_mode
  [ "$FUNC_company" = "y" ]   && company_func
  [ "$FUNC_assault" = "y" ]   && assault_mode
  if [ "$FUNC_battle" = "y" ]; then
    check_fuel && adiante_a_combate
  fi
}

start() {
  _maintenance
  go_hangar
  func_sleep
}

# PvP — horario fixo configuravel
# FUNC_pvp_hour=21 (joga PvP todo os dias as 21h)
_check_pvp_time() {
  [ "$FUNC_pvp" = "y" ] || return 1
  local h
  printf -v h '%(%H)T' -1
  h=$((10#$h))
  local pvp_h="${FUNC_pvp_hour:-21}"
  [ "$h" -eq "$pvp_h" ] && return 0
  return 1
}

wartank_play() {
  require_login || return

  # PvP no horario configurado
  if _check_pvp_time; then
    fetch_page "/pvp"
    if _session_active && grep -q 'ILinkListener-joinLink' "$SRC" 2>/dev/null; then
      echo "[run] pvp disponivel"
      pvp_mode
      return
    fi
  fi

  # Verifica batalhas dinamicamente
  _check_battles

  start
}
