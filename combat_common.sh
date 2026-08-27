#!/bin/bash
# combat_common.sh — Funcoes partilhadas de combate v2.1.0
#
# ALTERACOES v2.1.0:
#   + wait_battle_timer NAO bloqueia o bot em contagens longas
#     So espera se faltarem <= COMBAT_WAIT_MAX segundos (default 120)
#     Contagens maiores: log e sai — o run.sh volta a verificar no ciclo
#   + Disparo continua com 6s fixos (tempo de recarga do jogo)
#
# v2.0.0:
#   + get_player_hp unificado (green1 | first | value-block)
#   + combat_loop com repair/manobra

# Segundos maximos a esperar num timer antes de desistir e voltar ao ciclo
COMBAT_WAIT_MAX="${COMBAT_WAIT_MAX:-120}"

# ── get_player_hp — leitura unificada de HP do jogador ────────
# Uso: get_player_hp MODE
#   green1:      PvE — HP do painel com class green1
#   first:       CW/DM — primeiro span numerico
#   value-block: Assault/PvP — value-block lh1
get_player_hp() {
  local mode="$1"
  local hp=""

  case "$mode" in
    green1)
      hp=$(grep -A15 'green1' "$SRC" 2>/dev/null \
        | sed '/red1/,$d' \
        | grep -o -E '<span><span>[0-9]+' \
        | grep -o -E '[0-9]+' | head -n1)
      ;;
    first)
      hp=$(grep -o -E '<span><span>[0-9]+</span>' "$SRC" \
        | grep -o -E '[0-9]+' | sed -n '1p')
      ;;
    value-block)
      hp=$(grep -o -E \
        'value-block lh1[^>]*>[^<]*<[^>]*>[^<]*>[0-9]+' "$SRC" \
        | grep -o -E '[0-9]+$' | head -n1)
      ;;
  esac

  if [ -z "$hp" ]; then
    log "get_player_hp: HP nao detectado (modo: $mode)" "WARN"
  fi

  echo "$hp"
}

# ── wait_battle_timer — aguarda contagem CURTA e entra em combate ──
# Uso: wait_battle_timer tag page time_pattern atk_grep fight_func
#
# Retorno:
#   0 = combate iniciado (ou timeout de preparacao tratado)
#   1 = sem timer / timer longo (bot continua o ciclo normal)
wait_battle_timer() {
  local tag="$1" page="$2" time_pattern="$3" atk_grep="$4" fight_func="$5"

  local time_str
  time_str=$(grep -o -E "${time_pattern} [0-9]{2}:[0-9]{2}:[0-9]{2}" \
    "$SRC" | head -n1)
  [ -z "$time_str" ] && return 1

  local hh mm ss seconds_left
  hh=$(echo "$time_str" | grep -o -E '[0-9]{2}:[0-9]{2}:[0-9]{2}' | cut -d: -f1)
  mm=$(echo "$time_str" | grep -o -E '[0-9]{2}:[0-9]{2}:[0-9]{2}' | cut -d: -f2)
  ss=$(echo "$time_str" | grep -o -E '[0-9]{2}:[0-9]{2}:[0-9]{2}' | cut -d: -f3)
  seconds_left=$(( 10#$hh * 3600 + 10#$mm * 60 + 10#$ss ))

  # Timer longo: NAO bloquear o bot — volta no proximo ciclo
  if [ "$seconds_left" -gt "$COMBAT_WAIT_MAX" ] 2>/dev/null; then
    local mins=$(( seconds_left / 60 ))
    echo "[${tag}] ${time_str} (~${mins} min) — espera no ciclo (max ${COMBAT_WAIT_MAX}s)"
    return 1
  fi

  echo "[${tag}] ${time_str} (${seconds_left}s) — a aguardar inicio"

  while [ "$seconds_left" -gt 0 ] 2>/dev/null; do
    local wait_this=25
    [ "$seconds_left" -le 30 ] && wait_this=$seconds_left
    [ "$wait_this" -lt 1 ] && wait_this=1

    sleep "${wait_this}s"
    fetch_page "$page"

    if grep -q "$atk_grep" "$SRC" 2>/dev/null; then
      echo "[${tag}] combate iniciado durante espera"
      $fight_func
      return 0
    fi

    time_str=$(grep -o -E "${time_pattern} [0-9]{2}:[0-9]{2}:[0-9]{2}" \
      "$SRC" | head -n1)
    if [ -z "$time_str" ]; then
      break
    fi
    hh=$(echo "$time_str" | grep -o -E '[0-9]{2}:[0-9]{2}:[0-9]{2}' | cut -d: -f1)
    mm=$(echo "$time_str" | grep -o -E '[0-9]{2}:[0-9]{2}:[0-9]{2}' | cut -d: -f2)
    ss=$(echo "$time_str" | grep -o -E '[0-9]{2}:[0-9]{2}:[0-9]{2}' | cut -d: -f3)
    seconds_left=$(( 10#$hh * 3600 + 10#$mm * 60 + 10#$ss ))

    # Se o timer voltou a ser longo (pagina mudou), sai
    if [ "$seconds_left" -gt "$COMBAT_WAIT_MAX" ] 2>/dev/null; then
      echo "[${tag}] timer voltou a ser longo — a sair"
      return 1
    fi
    echo "[${tag}] ${seconds_left}s..."
  done

  # Contagem zerou — hangar → 10s → preparacao (max 15s)
  echo "[${tag}] contagem zerou — hangar → 10s → preparacao"
  go_hangar
  sleep 10s

  local prep=$(( $(date +%s) + 15 ))
  echo "[${tag}] a aguardar preparacao (max 15s)..."
  while [ "$(date +%s)" -lt "$prep" ]; do
    fetch_page "$page"
    if grep -q "$atk_grep" "$SRC" 2>/dev/null; then
      echo "[${tag}] controles disponiveis — a combater"
      $fight_func
      return 0
    fi
    echo "[${tag}] preparacao... $(( prep - $(date +%s) ))s"
    sleep 3s
  done

  echo "[${tag}] timeout na preparacao"
  return 0
}

# ── combat_loop — loop de combate partilhado ─────────────────
# Uso: combat_loop tag has_maneuver hp_mode [repair_threshold]
#   tag:              pve | cw | dm
#   has_maneuver:     y | n
#   hp_mode:          green1 | first | value-block
#   repair_threshold: percentagem HP para repair (default: 30)
#
# DISPARO: 6s fixos = tempo de recarga do jogo (nao alterar sem motivo)
combat_loop() {
  local tag="$1" has_maneuver="$2" hp_mode="$3"
  local repair_threshold="${4:-30}"
  local atk_pat rep_pat man_pat esc_pat

  case "$tag" in
    pve)
      atk_pat='pve\?[0-9]+-[0-9]+\.ILinkListener-currentControl-attackRegularShellLink'
      rep_pat='pve\?[0-9]+-[0-9]+\.ILinkListener-currentControl-repairLink'
      man_pat='pve\?[0-9]+-[0-9]+\.ILinkListener-currentControl-maneuverLink'
      esc_pat=''
      ;;
    cw)
      atk_pat='cw\?[0-9]+-[0-9]+\.ILinkListener-currentControl-buttons-attackRegularShellLink'
      rep_pat='cw\?[0-9]+-[0-9]+\.ILinkListener-currentControl-buttons-repairLink'
      man_pat='cw\?[0-9]+-[0-9]+\.ILinkListener-currentControl-buttons-maneuverLink'
      esc_pat='cw\?[0-9]+-[0-9]+\.ILinkListener-currentControl-escape'
      ;;
    dm)
      atk_pat='dm\?[0-9]+-[0-9]+\.ILinkListener-currentControl-buttons-attackRegularShellLink'
      rep_pat='dm\?[0-9]+-[0-9]+\.ILinkListener-currentControl-buttons-repairLink'
      man_pat='dm\?[0-9]+-[0-9]+\.ILinkListener-currentControl-buttons-maneuverLink'
      esc_pat='dm\?[0-9]+-[0-9]+\.ILinkListener-currentControl-escape'
      ;;
  esac

  local shots=0
  local timeout=$(( $(date +%s) + 600 ))
  local hp_max=""
  local last_repair=0 last_maneuver=0
  local repair_retry=5

  echo "[${tag}] combate iniciado"

  while [ "$(date +%s)" -lt "$timeout" ]; do
    _session_active || { echo "[${tag}] sessao perdida"; break; }

    local atk repair maneuver escape
    atk=$(grep -o -E "$atk_pat" "$SRC" | head -n1)
    repair=$(grep -o -E "$rep_pat" "$SRC" | head -n1)
    [ "$has_maneuver" = "y" ] && \
      maneuver=$(grep -o -E "$man_pat" "$SRC" | head -n1)
    [ -n "$esc_pat" ] && \
      escape=$(grep -o -E "$esc_pat" "$SRC" | head -n1)

    # Fim da batalha
    if [ -z "$atk" ]; then
      if [ -n "$esc_pat" ] && [ -z "$escape" ]; then
        echo "[${tag}] fim ($shots disparos)"; break
      elif [ -z "$esc_pat" ] && \
           ! grep -q 'currentControl-' "$SRC" 2>/dev/null; then
        echo "[${tag}] fim ($shots disparos)"; break
      fi
    fi

    local hp_now
    hp_now=$(get_player_hp "$hp_mode")
    [ -z "$hp_max" ] && [ -n "$hp_now" ] && hp_max="$hp_now"

    local now=$(date +%s)
    local since_repair=$(( now - last_repair ))
    local since_maneuver=$(( now - last_maneuver ))

    local hp_pct=""
    if [ -n "$hp_now" ] && [ "${hp_max:-0}" -gt 0 ] 2>/dev/null; then
      hp_pct=$(awk -v n="$hp_now" -v m="$hp_max" \
        'BEGIN{printf"%.0f",n/m*100}' 2>/dev/null)
    elif [ -z "$hp_now" ]; then
      echo "[${tag}] AVISO: HP nao detectado — repair/manobra suspensos"
    fi

    # REPAIR: HP <= threshold, tenta de 5 em 5s
    if [ -n "$hp_pct" ] && \
       [ "$hp_pct" -le "$repair_threshold" ] && \
       [ "$since_repair" -ge "$repair_retry" ] 2>/dev/null; then
      last_repair=$now
      if [ -n "$repair" ]; then
        echo "[${tag}] REPAIR HP: $hp_now (${hp_pct}%)"
        fetch_page_fast "$repair"; continue
      else
        echo "[${tag}] repair indisponivel"
      fi
    fi

    # MANOBRA: apos receber dano
    if [ "$has_maneuver" = "y" ] && [ -n "$maneuver" ] && \
       [ "$since_maneuver" -ge 20 ] 2>/dev/null; then
      if grep -q 'causou-lhe danos' "$SRC" 2>/dev/null; then
        echo "[${tag}] manobra"
        fetch_page_fast "$maneuver"
        last_maneuver=$now; continue
      fi
    fi

    # DISPARO: 6s = recarga do jogo
    [ -z "$atk" ] && { sleep 1s; continue; }
    sleep 6s
    fetch_page_fast "$atk"
    shots=$(( shots + 1 ))
    echo "[${tag}] #${shots} | HP: ${hp_now:-?} (${hp_pct:-?}%)"
  done

  echo "[${tag}] fim: $shots disparos"
  go_hangar
}
