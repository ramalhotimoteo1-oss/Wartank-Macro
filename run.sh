#!/bin/bash
# run.sh — scheduler v1.4.0
# Fix: gestao de combustivel com timestamp — evita combater sem fuel

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

# ── Gestao de combustivel ─────────────────────────────────────
# Cada disparo consome ~30 combustivel
# 9 disparos = ~270 combustivel
# Recarga: 30 por cada 464s (~7m44s)
# Tempo minimo entre batalhas: 9 * 464 = 4176s (~70 min)

LAST_BATTLE_TS=0          # timestamp da ultima batalha
BATTLE_FUEL_COST=270      # combustivel consumido por sessao (9 disparos)
FUEL_REGEN_RATE=30        # combustivel por ciclo de recarga
FUEL_REGEN_SECS=464       # segundos por ciclo de recarga

_can_battle() {
  [ "$FUNC_battle" = "n" ] && return 1

  local now
  now=$(date +%s)

  # Verifica combustivel actual
  go_hangar
  local fuel="${FUEL_CURRENT:-0}"

  if [ "$fuel" -eq 0 ] 2>/dev/null; then
    echo "[fuel] combustivel zero — a aguardar"
    return 1
  fi

  # Tem combustivel suficiente para pelo menos 3 disparos (1 inimigo)?
  local min_to_fight=90   # 3 disparos x 30
  if [ "$fuel" -lt "$min_to_fight" ] 2>/dev/null; then
    # Calcula tempo de espera
    local needed=$(( min_to_fight - fuel ))
    local cycles=$(( (needed + FUEL_REGEN_RATE - 1) / FUEL_REGEN_RATE ))
    local wait_secs=$(( cycles * FUEL_REGEN_SECS ))
    local wait_min=$(( wait_secs / 60 ))
    echo "[fuel] insuficiente ($fuel < $min_to_fight) — aguarda ~${wait_min} min"
    return 1
  fi

  echo "[fuel] ok ($fuel) — a combater"
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
  # Battle com verificacao de combustivel
  if _can_battle; then
    adiante_a_combate
    LAST_BATTLE_TS=$(date +%s)
  fi

  # Missoes
  [ "$FUNC_missions" = "y" ] && collect_all_rewards

  # Modulos opcionais
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
