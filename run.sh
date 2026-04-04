#!/bin/bash
# run.sh — scheduler v1.3.1
# Correcoes:
#   - load_config removido do _maintenance (causa recriar config em loop)
#   - battle chamado directamente sem _battle_ready separado
#   - combustivel lido do $SRC do hangar ja carregado

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
        config) config_menu; load_config ;;
        status) go_hangar ;;
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

_maintenance() {
  # IMPORTANTE: load_config NAO e chamado aqui
  # E carregado uma vez no arranque pelo wartank.sh
  # Chamar aqui recria o config em cada ciclo

  # 1. Battle — primeira prioridade
  if [ "$FUNC_battle" = "y" ]; then
    # Vai ao hangar para ler combustivel actualizado
    go_hangar
    # FUEL_CURRENT e populado por _parse_hangar_info dentro de go_hangar
    if [ -z "$FUEL_CURRENT" ] || [ "$FUEL_CURRENT" -gt "${FUEL_MIN:-0}" ] 2>/dev/null; then
      echo "[run] a iniciar battle (combustivel: ${FUEL_CURRENT:-?})"
      adiante_a_combate
    else
      echo "[run] sem combustivel para battle"
    fi
  fi

  # 2. Missoes
  if [ "$FUNC_missions" = "y" ]; then
    collect_all_rewards
  fi

  # 3. Modulos opcionais
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
