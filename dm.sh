#!/bin/bash
# dm.sh — Disputa (Deathmatch) v1.4.0
# Fix:
#   - Tempo entre disparos: 6 segundos (tempo real do jogo)
#   - Kit de Reparacao: usa quando HP < 50% (nao so manobra)
#   - Prioridade: repair > disparo (para sobreviver)

dm_check_and_apply() {
  [ "$FUNC_dm" = "n" ] && return 0

  fetch_page "/dm"
  if ! _session_active; then return; fi

  # Batalha ja activa?
  if grep -q 'currentControl-buttons-attackRegularShellLink' "$SRC" 2>/dev/null; then
    echo "[dm] batalha activa"
    _dm_fight_active
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
      _dm_fight_active
      return
    }
    local ref
    ref=$(grep -o -E 'dm\?[0-9]+-[0-9]+\.ILinkListener-[^"]*refresh[^"]*' \
      "$SRC" | head -n1)
    [ -n "$ref" ] && fetch_page "$ref" || fetch_page "/dm"
    sleep_rand 2000 3000
  done
  echo "[dm] timeout a aguardar"
}

_dm_extract() {
  DM_ATK=$(grep -o -E \
    'dm\?[0-9]+-[0-9]+\.ILinkListener-currentControl-buttons-attackRegularShellLink' \
    "$SRC" | head -n1)
  DM_ATK_SP=$(grep -o -E \
    'dm\?[0-9]+-[0-9]+\.ILinkListener-currentControl-buttons-attackSpecialShellLink' \
    "$SRC" | head -n1)
  DM_REPAIR=$(grep -o -E \
    'dm\?[0-9]+-[0-9]+\.ILinkListener-currentControl-buttons-repairLink' \
    "$SRC" | head -n1)
  DM_MANEUVER=$(grep -o -E \
    'dm\?[0-9]+-[0-9]+\.ILinkListener-currentControl-buttons-maneuverLink' \
    "$SRC" | head -n1)
  DM_ESCAPE=$(grep -o -E \
    'dm\?[0-9]+-[0-9]+\.ILinkListener-currentControl-escape' \
    "$SRC" | head -n1)

  # HP do jogador (1o value-block) e inimigo (2o value-block)
  DM_HP_PLAYER=$(grep -o -E \
    'value-block lh1[^>]*>[^<]*<[^>]*>[^<]*>[0-9]+' "$SRC" \
    | grep -o -E '[0-9]+$' | sed -n '1p')
  DM_HP_ENEMY=$(grep -o -E \
    'value-block lh1[^>]*>[^<]*<[^>]*>[^<]*>[0-9]+' "$SRC" \
    | grep -o -E '[0-9]+$' | sed -n '2p')
  DM_HP_MAX="${DM_HP_MAX:-$DM_HP_PLAYER}"
}

_dm_fight_active() {
  _dm_extract
  DM_HP_MAX="${DM_HP_PLAYER:-2846}"

  local timeout=$(( $(date +%s) + 600 ))
  local shots=0
  local last_atk=0
  local last_repair=0
  local last_maneuver=0

  # FIX: 6 segundos entre disparos (tempo real do jogo)
  local dm_reload=6

  echo "[dm] HP: ${DM_HP_PLAYER:-?}/${DM_HP_MAX} vs ${DM_HP_ENEMY:-?}"

  while [ "$(date +%s)" -lt "$timeout" ]; do
    _session_active || { echo "[dm] sessao perdida"; break; }
    _dm_extract

    # Fim da batalha
    [ -z "$DM_ATK" ] && [ -z "$DM_ESCAPE" ] && {
      echo "[dm] batalha terminou ($shots disparos)"
      break
    }

    local now=$(date +%s)
    local since_repair=$(( now - last_repair ))
    local since_maneuver=$(( now - last_maneuver ))
    local since_atk=$(( now - last_atk ))

    # ── REPAIR: prioridade maxima ─────────────────────────────
    # FIX: usa repair quando HP < 50% (antes era so manobra)
    if [ -n "$DM_REPAIR" ] && [ -n "$DM_HP_PLAYER" ] && [ "$DM_HP_MAX" -gt 0 ] \
       2>/dev/null; then
      local hp_pct
      hp_pct=$(awk -v n="$DM_HP_PLAYER" -v m="$DM_HP_MAX" \
        'BEGIN{printf"%.0f",n/m*100}' 2>/dev/null)
      if [ -n "$hp_pct" ] && [ "$hp_pct" -le 50 ] && \
         [ "$since_repair" -ge 90 ] 2>/dev/null; then
        echo "[dm] REPAIR HP: ${DM_HP_PLAYER} (${hp_pct}%)"
        fetch_page "$DM_REPAIR"
        last_repair=$now
        DM_HP_MAX="$DM_HP_PLAYER"  # actualiza max apos repair
        sleep_rand 500 800
        continue
      fi
    fi

    # ── MANOBRA: usa apos sofrer dano ──────────────────────────
    if [ -n "$DM_MANEUVER" ] && [ "$since_maneuver" -ge 20 ] 2>/dev/null; then
      if grep -q 'disparou a\|causou danos\|danos' "$SRC" 2>/dev/null; then
        echo "[dm] manobra"
        fetch_page "$DM_MANEUVER"
        last_maneuver=$now
        sleep_rand 300 500
        continue
      fi
    fi

    # ── DISPARO: a cada 6 segundos ────────────────────────────
    if [ -n "$DM_ATK" ] && [ "$since_atk" -ge "$dm_reload" ] 2>/dev/null; then
      fetch_page "$DM_ATK"
      last_atk=$(date +%s)
      shots=$(( shots + 1 ))
      _dm_extract
      echo "[dm] #${shots} | HP: ${DM_HP_PLAYER:-?}/${DM_HP_MAX} vs ${DM_HP_ENEMY:-?}"
    else
      # Espera o tempo restante ate proximo disparo
      local wait_rem=$(( dm_reload - since_atk ))
      [ "$wait_rem" -gt 0 ] && sleep "${wait_rem}s" || sleep 1s
    fi

  done

  echo "[dm] fim: $shots disparos"
  go_hangar
}
