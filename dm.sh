#!/bin/bash
# dm.sh — Disputa (Deathmatch) v2.0.0
# HTML real confirmado:
#   titulo: "Combate"
#   atk:    dm?3-28.ILinkListener-currentControl-buttons-attackRegularShellLink
#   repair: dm?3-28.ILinkListener-currentControl-buttons-repairLink
#   maneuver: dm?3-28.ILinkListener-currentControl-buttons-maneuverLink
#   change: dm?3-28.ILinkListener-currentControl-buttons-changeTargetLink
#   escape: dm?3-28.ILinkListener-currentControl-escape
#   HP jogador (vermelho, class red1): value-block lh1 → 3136
#   HP inimigo: value-block lh1 → 2698
#   Reload: 6 segundos entre disparos

dm_check_and_apply() {
  [ "$FUNC_dm" = "n" ] && return 0

  fetch_page "/dm"
  if ! _session_active; then return; fi

  # Batalha activa?
  if grep -q 'currentControl-buttons-attackRegularShellLink' "$SRC" 2>/dev/null; then
    echo "[dm] batalha activa"
    _dm_fight
    return
  fi

  # Botao de aplicar?
  local apply_link
  apply_link=$(grep -o -E \
    'dm\?[0-9]+-[0-9]+\.ILinkListener-currentOverview-apply' \
    "$SRC" | head -n1)

  if [ -n "$apply_link" ]; then
    local next_time
    next_time=$(grep -o -E 'ate o inicio [0-9]{2}:[0-9]{2}:[0-9]{2}' "$SRC" | head -n1)
    echo "[dm] a aplicar... $next_time"
    fetch_page "$apply_link"
    sleep_rand 500 1000
    # Aguarda os 6s de preparacao
    _dm_wait_start
  fi
}

dm_mode() {
  [ "$FUNC_dm" = "n" ] && return 0
  dm_check_and_apply
}

_dm_wait_start() {
  local timeout=$(( $(date +%s) + 30 ))
  echo "[dm] a aguardar inicio (6s)..."
  while [ "$(date +%s)" -lt "$timeout" ]; do
    grep -q 'currentControl-buttons-attackRegularShellLink' "$SRC" 2>/dev/null && {
      echo "[dm] batalha iniciada"
      _dm_fight
      return
    }
    local ref
    ref=$(grep -o -E \
      'dm\?[0-9]+-[0-9]+\.ILinkListener-[^"]*refresh[^"]*' \
      "$SRC" | head -n1)
    [ -n "$ref" ] && fetch_page "$ref" || fetch_page "/dm"
    sleep_rand 2000 3000
  done
  echo "[dm] timeout a aguardar"
}

_dm_fight() {
  # HP do jogador = class "red1" (o proprio tanque e vermelho no DM)
  # Extrai HP do primeiro value-block (jogador) e segundo (inimigo)
  local hp_max=""
  local last_repair=0
  local last_maneuver=0
  local last_atk=0
  local shots=0
  local timeout=$(( $(date +%s) + 600 ))
  local dm_reload=6  # 6 segundos entre disparos (confirmado)

  # Le HP inicial para calcular percentagem
  hp_max=$(grep -o -E \
    'value-block lh1[^>]*>[^<]*<[^>]*>[^<]*>[0-9]+' "$SRC" \
    | grep -o -E '[0-9]+$' | sed -n '1p')
  echo "[dm] HP max: ${hp_max:-?}"

  while [ "$(date +%s)" -lt "$timeout" ]; do
    _session_active || { echo "[dm] sessao perdida"; break; }

    # Extrai links — padrao real confirmado
    local atk repair maneuver change escape
    atk=$(grep -o -E \
      'dm\?[0-9]+-[0-9]+\.ILinkListener-currentControl-buttons-attackRegularShellLink' \
      "$SRC" | head -n1)
    repair=$(grep -o -E \
      'dm\?[0-9]+-[0-9]+\.ILinkListener-currentControl-buttons-repairLink' \
      "$SRC" | head -n1)
    maneuver=$(grep -o -E \
      'dm\?[0-9]+-[0-9]+\.ILinkListener-currentControl-buttons-maneuverLink' \
      "$SRC" | head -n1)
    escape=$(grep -o -E \
      'dm\?[0-9]+-[0-9]+\.ILinkListener-currentControl-escape' \
      "$SRC" | head -n1)

    # Fim da batalha
    [ -z "$atk" ] && [ -z "$escape" ] && {
      echo "[dm] batalha terminou ($shots disparos)"
      break
    }

    # HP actual do jogador (1o value-block)
    local hp_now
    hp_now=$(grep -o -E \
      'value-block lh1[^>]*>[^<]*<[^>]*>[^<]*>[0-9]+' "$SRC" \
      | grep -o -E '[0-9]+$' | sed -n '1p')

    # HP inimigo (2o value-block)
    local hp_enemy
    hp_enemy=$(grep -o -E \
      'value-block lh1[^>]*>[^<]*<[^>]*>[^<]*>[0-9]+' "$SRC" \
      | grep -o -E '[0-9]+$' | sed -n '2p')

    local now=$(date +%s)
    local since_repair=$(( now - last_repair ))
    local since_maneuver=$(( now - last_maneuver ))
    local since_atk=$(( now - last_atk ))

    # ── REPAIR: prioridade maxima a 50% HP ────────────────────
    if [ -n "$repair" ] && [ -n "$hp_now" ] && [ "${hp_max:-0}" -gt 0 ] \
       && [ "$since_repair" -ge 90 ] 2>/dev/null; then
      local hp_pct
      hp_pct=$(awk -v n="$hp_now" -v m="$hp_max" \
        'BEGIN{printf"%.0f",n/m*100}' 2>/dev/null)
      if [ -n "$hp_pct" ] && [ "$hp_pct" -le 50 ] 2>/dev/null; then
        echo "[dm] REPAIR HP: $hp_now (${hp_pct}%)"
        fetch_page "$repair"
        last_repair=$now
        sleep_rand 300 500
        continue
      fi
    fi

    # ── MANOBRA: apos sofrer dano ──────────────────────────────
    if [ -n "$maneuver" ] && [ "$since_maneuver" -ge 20 ] 2>/dev/null; then
      if grep -q 'disparou a\|causou danos\|danos' "$SRC" 2>/dev/null; then
        echo "[dm] manobra"
        fetch_page "$maneuver"
        last_maneuver=$now
        sleep_rand 300 500
        continue
      fi
    fi

    # ── DISPARO: exactamente 6 segundos de intervalo ──────────
    if [ -n "$atk" ] 2>/dev/null; then
      local wait_rem=$(( dm_reload - since_atk ))
      if [ "$wait_rem" -gt 0 ]; then
        sleep "${wait_rem}s"
      fi
      fetch_page "$atk"
      last_atk=$(date +%s)
      shots=$(( shots + 1 ))
      echo "[dm] #${shots} | HP: ${hp_now:-?}/${hp_max:-?} vs ${hp_enemy:-?}"
    else
      sleep 1s
    fi

  done

  echo "[dm] fim: $shots disparos"
  go_hangar
}
