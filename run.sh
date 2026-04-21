#!/bin/bash
# run.sh — scheduler v1.4.0
# Deteccao dinamica — sem horarios fixos
# Combustivel: 9 disparos (3 inimigos) depois espera recarga

func_sleep() {
  local m
  printf -v m '%(%M)T' -1
  m=$((10#$m))
  # Ciclos curtos nos minutos 48-59 (batalhas aproximam-se)
  # e 13-22 (janela do DM)
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

# ── Verifica batalhas dinamicamente ─────────────────────────
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

# ── Battle com gestao de combustivel ─────────────────────────
# Logica:
#   - Le combustivel actual do hangar
#   - Se >= 270 (9 disparos): luta
#   - Se < 270: calcula tempo de espera e faz idle
#   - Combustivel=0: salta, nao tenta lutar
_battle_with_fuel_management() {
  [ "$FUNC_battle" = "n" ] && return

  # Le combustivel do hangar
  go_hangar
  local fuel
  fuel=$(grep -o -E 'fuel\.png[^/]*/>[^0-9]*[0-9]+' "$SRC" 2>/dev/null \
    | grep -o -E '[0-9]+$' | head -n1)
  FUEL_CURRENT="${fuel:-0}"

  if [ -z "$fuel" ] || [ "$fuel" -eq 0 ] 2>/dev/null; then
    echo "[battle] sem combustivel — a aguardar recarga"
    # 9 disparos = 270 combustivel
    # 30 combustivel a cada 464s → 270 = 9 * 464 = 4176s (~70 min)
    # Mas nao esperamos aqui — o idle normal vai eventualmente
    # verificar novamente quando o combustivel tiver recarregado
    return
  fi

  local min_fuel=270  # 9 disparos
  if [ "$fuel" -lt "$min_fuel" ] 2>/dev/null; then
    local reloads_needed=$(( (min_fuel - fuel + 29) / 30 ))
    local wait_sec=$(( reloads_needed * 464 ))
    echo "[battle] combustivel insuficiente ($fuel < $min_fuel) — aguarda ${wait_sec}s"
    # Nao bloqueia — apenas informa e deixa o scheduler decidir
    return
  fi

  echo "[battle] combustivel ok ($fuel) — a combater"
  adiante_a_combate
}

# ── Manutencao ───────────────────────────────────────────────
_maintenance() {
  # Battle: prioritario
  _battle_with_fuel_management

  # Missoes
  [ "$FUNC_missions" = "y" ] && collect_all_rewards

  # Modulos opcionais — nao bloqueiam
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
