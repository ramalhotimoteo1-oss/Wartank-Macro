#!/bin/bash
# run.sh — scheduler v1.3.0

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
    if _session_active && grep -q 'currentOverview-apply' "$SRC" 2>/dev/null; then
      echo "[run] pve disponivel"
      pve_check_and_apply
    fi
  fi
}

_battle_ready() {
  # Fix 3: sempre vai ao hangar para ler combustivel actualizado
  # nao depende de FUEL_CURRENT cached de outra pagina
  fetch_page "/angar"
  FUEL_CURRENT=$(grep -o -E 'fuel\.png[^/]*/>[^0-9]*[0-9]+' "$SRC" 2>/dev/null \
    | grep -o -E '[0-9]+$' | head -n1)

  [ -z "$FUEL_CURRENT" ] && { echo "[battle] nao conseguiu ler combustivel"; return 0; }
  local min="${FUEL_MIN:-0}"
  if [ "$FUEL_CURRENT" -le "$min" ] 2>/dev/null; then
    echo "[battle] sem combustivel ($FUEL_CURRENT)"
    return 1
  fi
  echo "[battle] combustivel ok: $FUEL_CURRENT"
  return 0
}

_maintenance() {
  load_config

  # 1. BATTLE PRIMEIRO — prioridade maxima antes de qualquer outro modulo
  if [ "$FUNC_battle" = "y" ]; then
    if _battle_ready; then
      adiante_a_combate
    fi
  fi

  # 2. Recolha de recompensas
  collect_all_rewards

  # 3. Modulos de manutencao — nao bloqueiam
  [ "$FUNC_buildings" = "y" ] && buildings_func
  [ "$FUNC_convoy" = "y" ]    && convoy_mode
  [ "$FUNC_company" = "y" ]   && company_func
  [ "$FUNC_assault" = "y" ]   && assault_mode
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
  h=$((10#$h))
  [ "$h" -eq "${FUNC_pvp_hour:-21}" ] && return 0
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
