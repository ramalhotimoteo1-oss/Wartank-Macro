#!/bin/bash
# run.sh — scheduler v1.6.0
#
# ALTERACOES v1.6.0:
#   + Battle com horarios fixos a cada 40 min (nao usa intervalo desde o ultimo combate)
#   + Slots: 00:00, 00:40, 01:20, 02:00, 02:40, ... ate 23:20
#   + Janela BATTLE_WINDOW (default 3 min) apos o slot
#   + LAST_BATTLE_SLOT evita repetir no mesmo horario
#   + Restart do bot NAO gasta combustivel logo de seguida
#
# Ordem: cw/dm/pve (prioridade) > battle > missoes > buildings > convoy > company > assault > pvp

LAST_BATTLE_SLOT=""
BATTLE_WINDOW="${BATTLE_WINDOW:-3}"

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

# ── Slot actual de battle (HH:MM) ou vazio se fora da janela ──
# Multiplos de 40 min desde 00:00: 00:00, 00:40, 01:20, 02:00, ...
_battle_current_slot() {
  local h m total slot_min slot_h slot_m diff
  printf -v h '%(%H)T' -1
  printf -v m '%(%M)T' -1
  h=$((10#$h)); m=$((10#$m))
  total=$(( h * 60 + m ))

  slot_min=$(( (total / 40) * 40 ))
  diff=$(( total - slot_min ))

  # Fora da janela (ex.: mais de 3 min depois do slot)
  [ "$diff" -ge "$BATTLE_WINDOW" ] && { echo ""; return; }

  slot_h=$(( slot_min / 60 ))
  slot_m=$(( slot_min % 60 ))
  printf '%02d:%02d' "$slot_h" "$slot_m"
}

_can_battle() {
  [ "$FUNC_battle" = "n" ] && return 1

  local slot
  slot=$(_battle_current_slot)

  if [ -z "$slot" ]; then
    local h m total next nh nm
    printf -v h '%(%H)T' -1
    printf -v m '%(%M)T' -1
    h=$((10#$h)); m=$((10#$m))
    total=$(( h * 60 + m ))
    next=$(( (total / 40 + 1) * 40 ))
    [ "$next" -ge 1440 ] && next=0
    nh=$(( next / 60 ))
    nm=$(( next % 60 ))
    echo "[battle] fora de horario — proximo $(printf '%02d:%02d' "$nh" "$nm")"
    return 1
  fi

  # Ja combateu neste slot
  if [ "$LAST_BATTLE_SLOT" = "$slot" ]; then
    echo "[battle] ja feito neste slot ($slot)"
    return 1
  fi

  # Combustivel (lido pelo go_hangar do start)
  local fuel="${FUEL_CURRENT:-0}"
  if [ -z "$fuel" ] || [ "$fuel" -eq 0 ] 2>/dev/null; then
    echo "[battle] combustivel zero"
    return 1
  fi
  if [ "$fuel" -lt 90 ] 2>/dev/null; then
    echo "[battle] combustivel insuficiente ($fuel/90) — slot $slot"
    return 1
  fi

  echo "[battle] ok — slot $slot | combustivel $fuel"
  return 0
}

# Escolta: SEM cooldown no bot.
# A disponibilidade e decidida pelo HTML do jogo (findEnemy / startFight).
_can_convoy() {
  [ "$FUNC_convoy" = "n" ] && return 1
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
  # 1. Batalha normal — so nos horarios fixos
  if _can_battle; then
    adiante_a_combate
    LAST_BATTLE_SLOT=$(_battle_current_slot)
  fi

  # 2. Missoes
  [ "$FUNC_missions" = "y" ] && collect_all_rewards

  # 3. Base
  [ "$FUNC_buildings" = "y" ] && buildings_func

  # 4. Escolta — tenta sempre; o jogo define se ha botao
  if _can_convoy; then
    convoy_mode
  fi

  # 5. Divisao
  [ "$FUNC_company" = "y" ] && company_func

  # 6. Assault — ultimo, nao bloqueia
  [ "$FUNC_assault" = "y" ] && assault_mode
}

start() {
  go_hangar
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

  # CW / DM / PvE — prioridade maxima se ja activos
  _check_battles
  start

  # PvP — horarios internos (05:23 / 11:23 / 21:23)
  [ "$FUNC_pvp" = "y" ] && pvp_mode
}
