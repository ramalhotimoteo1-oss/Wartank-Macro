#!/bin/bash
# run.sh — scheduler v1.5.1
# Correcoes:
#   - painel mostra apos cada ciclo (go_hangar no final do start)
#   - assault nao tem prioridade sobre battle/missoes
#   - ordem correcta: battle > missoes > buildings > convoy > company > assault

LAST_BATTLE_TS=0
LAST_CONVOY_TS=0
BATTLE_INTERVAL=2400
CONVOY_INTERVAL=2400

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

_can_battle() {
  [ "$FUNC_battle" = "n" ] && return 1

  local now elapsed
  now=$(date +%s)
  elapsed=$(( now - LAST_BATTLE_TS ))

  if [ "$elapsed" -lt "$BATTLE_INTERVAL" ]; then
    local remaining=$(( (BATTLE_INTERVAL - elapsed) / 60 ))
    echo "[battle] aguarda ~${remaining} min"
    return 1
  fi

  # Usa FUEL_CURRENT ja lido pelo go_hangar do start()
  local fuel="${FUEL_CURRENT:-0}"
  if [ -z "$fuel" ] || [ "$fuel" -eq 0 ] 2>/dev/null; then
    echo "[battle] combustivel zero"
    return 1
  fi
  if [ "$fuel" -lt 90 ] 2>/dev/null; then
    echo "[battle] combustivel insuficiente ($fuel)"
    return 1
  fi

  echo "[battle] ok ($fuel)"
  return 0
}

_can_convoy() {
  [ "$FUNC_convoy" = "n" ] && return 1
  local elapsed=$(( $(date +%s) - LAST_CONVOY_TS ))
  if [ "$elapsed" -lt "$CONVOY_INTERVAL" ]; then
    echo "[convoy] aguarda ~$(( (CONVOY_INTERVAL - elapsed) / 60 )) min"
    return 1
  fi
  return 0
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
    if _session_active && grep -q \
      'currentControl-attackRegularShellLink\|currentOverview-apply' \
      "$SRC" 2>/dev/null; then
      echo "[run] pve disponivel"
      pve_check_and_apply
    fi
  fi
}

_maintenance() {
  # 1. Batalha normal — prioridade maxima
  if _can_battle; then
    adiante_a_combate
    LAST_BATTLE_TS=$(date +%s)
  fi

  # 2. Missoes
  [ "$FUNC_missions" = "y" ] && collect_all_rewards

  # 3. Base
  [ "$FUNC_buildings" = "y" ] && buildings_func

  # 4. Escolta
  if _can_convoy; then
    convoy_mode
    LAST_CONVOY_TS=$(date +%s)
  fi

  # 5. Divisao
  [ "$FUNC_company" = "y" ] && company_func

  # 6. Assault — ultimo, nao bloqueia
  [ "$FUNC_assault" = "y" ] && assault_mode
}

start() {
  # Vai ao hangar — mostra painel com todas as informacoes
  go_hangar

  _maintenance

  # Painel actualizado apos manutencao
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

  # Verifica batalhas activas (cw/dm/pve) — prioridade maxima
  _check_battles
  start

  # PvP — sem prioridade, corre no final
  # pvp.sh verifica o horario (05:23 / 11:23 / 21:23) internamente
  [ "$FUNC_pvp" = "y" ] && pvp_mode
}
