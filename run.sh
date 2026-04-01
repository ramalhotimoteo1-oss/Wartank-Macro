#!/bin/bash
# ============================================================
# run.sh — Scheduler principal
# Horários baseados no HTML real do wartank-pt.net
# ============================================================
# Batalhas PvE a cada 2h (horário PT):
#   06:57, 08:57, 10:57, 12:57, 14:57, 16:57, 18:57, 21:57
# Bot aplica 5 min antes: 06:52, 08:52, etc.
# ============================================================

func_sleep() {
  local h m
  printf -v h '%(%H)T' -1
  printf -v m '%(%M)T' -1
  HOUR=$((10#$h))
  MIN=$((10#$m))

  # Próximo evento em menos de 3 min — espera pouco
  if [ "$MIN" -ge 52 ] && [ "$MIN" -le 56 ]; then
    _idle_wait 15
  elif [ "$MIN" -ge 57 ] && [ "$MIN" -le 59 ]; then
    _idle_wait 10
  else
    _idle_wait 60
  fi
}

_idle_wait() {
  local wait_sec="$1"
  local h m
  printf -v h '%(%H)T' -1
  printf -v m '%(%M)T' -1

  echo_t "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "$GRAY_BLACK" "$COLOR_RESET"
  echo_t "🕐 ${h}:${m}  |  👤 ${ACC:-?}  |  ⛽ ${FUEL_CURRENT:-?}" "$GRAY_BLACK" "$COLOR_RESET"
  echo_t "⏳ Próxima acção em ~${wait_sec}s" "$GRAY_BLACK" "$COLOR_RESET"
  echo_t "[stop] parar  [config] configurar  [status] estado" "$GRAY_BLACK" "$COLOR_RESET"
  echo_t "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "$GRAY_BLACK" "$COLOR_RESET"

  local count=0
  while [ "$count" -lt "$wait_sec" ]; do
    if read -r -t 1 cmd 2>/dev/null; then
      case "$cmd" in
        stop|exit|q|x)
          echo_t "A parar o bot..." "$BLACK_RED" "$COLOR_RESET" "after" "🛑"
          exit 0 ;;
        config) config_menu ;;
        status) hangar_status ;;
      esac
    fi
    count=$(( count + 1 ))
  done
}

# ── Sequência de acções principal ───────────────────────────
start() {
  load_config
  collect_all_rewards
  buildings_func
  convoy_mode
  company_func
  assault_mode

  if [ "$FUNC_battle" = "y" ]; then
    adiante_a_combate
  fi

  go_hangar
  func_sleep
}

# ── Scheduler por horário ────────────────────────────────────
wartank_play() {
  local h m hm
  printf -v h '%(%H)T' -1
  printf -v m '%(%M)T' -1
  hm="${h}:${m}"

  case "$hm" in

    # ── PvE — aplica 5 min antes de cada batalha ────────────
    # Batalhas reais: 06:57, 08:57, 10:57, 12:57, 14:57, 16:57, 18:57, 21:57
    06:5[2-6]|08:5[2-6]|10:5[2-6]|12:5[2-6]|\
    14:5[2-6]|16:5[2-6]|18:5[2-6]|21:5[2-6])
      if [ "$FUNC_pve" = "y" ]; then
        pve_check_and_apply
      fi
      start
      ;;

    # ── DM — aplica antes das disputas
    # Horários reais: 11:20, 15:20, 21:20
    11:1[5-9]|15:1[5-9]|21:1[5-9])
      dm_check_and_apply
      start
      ;;

    # ── PvP — madrugada e períodos calmos ───────────────────
    00:[0-5][05]|01:[0-5][05]|02:[0-5][05]|03:[0-5][05]|\
    04:[0-5][05]|05:[0-5][05])
      if [ "$FUNC_pvp" = "y" ]; then
        pvp_mode
      fi
      start
      ;;

    # ── Rotina completa — durante o dia ─────────────────────
    07:00|07:30|08:00|08:30|09:00|09:30|\
    10:00|10:30|11:00|11:30|12:00|12:30|\
    13:00|13:30|14:00|14:30|15:00|15:30|\
    16:00|16:30|17:00|17:30|18:00|18:30|\
    19:00|19:30|20:00|20:30|21:00|21:30|\
    22:00|22:30|23:00|23:30)
      start
      ;;

    # ── Default — idle ───────────────────────────────────────
    *)
      go_hangar
      func_sleep
      ;;
  esac
}
