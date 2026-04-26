#!/bin/bash
# pve.sh — PvE v2.4.0
#
# LOGICA CORRIGIDA:
#
#   Disparo → confirmado ("disparou a") → last_confirmed_ts = agora → espera 6s
#   Disparo → manobra inimigo (sem "disparou a") → last_confirmed_ts = agora → dispara imediato
#   Disparo imediato → confirmado → last_confirmed_ts = agora → espera 6s
#
# A CHAVE: last_confirmed_ts e actualizado SEMPRE apos um disparo (confirmado ou anulado)
# A diferenca e o wait:
#   - Confirmado  → espera 6s completos
#   - Anulado     → espera 0s (disparo imediato) MAS actualiza o timer
#
# Assim, apos o disparo imediato ser confirmado, os 6s contam a partir
# desse momento — nunca dispara 2x seguidas sem o inimigo usar manobra

pve_check_and_apply() {
  [ "$FUNC_pve" = "n" ] && return 0

  fetch_page "/pve"
  if ! _session_active; then return; fi

  if grep -q 'currentControl-attackRegularShellLink' "$SRC" 2>/dev/null; then
    echo "[pve] batalha activa"
    _pve_fight
    return
  fi

  local apply_link
  apply_link=$(grep -o -E \
    'pve\?[0-9]+-[0-9]+\.ILinkListener-currentOverview-apply' \
    "$SRC" | head -n1)

  if [ -n "$apply_link" ]; then
    local battle_name wait_time
    battle_name=$(grep -o -E 'class="green2">[^<]+' "$SRC" \
      | sed 's/.*">//' | head -n1)
    wait_time=$(grep -o -E 'ate o inicio [0-9:]+' "$SRC" | head -n1)
    echo "[pve] a aplicar: ${battle_name:-batalha} ${wait_time}"
    fetch_page "$apply_link"
    sleep_rand 500 1000
    grep -q 'currentControl-attackRegularShellLink' "$SRC" 2>/dev/null && \
      _pve_fight
  fi
}

pve_mode() {
  [ "$FUNC_pve" = "n" ] && return 0
  pve_check_and_apply
}

_pve_count_shots() {
  grep -c 'disparou a.*danos\|disparou a.*crit' "$SRC" 2>/dev/null || echo 0
}

_pve_fight() {
  local timeout=$(( $(date +%s) + ${PVE_TIMEOUT:-600} ))
  local shots_confirmed=0
  local shots_total=0
  local hp_max=""
  local reload=6

  # Timer do ultimo disparo (confirmado OU anulado por manobra)
  # Controla quando pode disparar de novo
  local last_shot_ts=0

  # Indica se proximo disparo e imediato (manobra detectada)
  local immediate_next=0

  local last_repair_attempt=0
  local repair_retry=5

  echo "[pve] combate iniciado"

  while [ "$(date +%s)" -lt "$timeout" ]; do
    _session_active || { echo "[pve] sessao perdida"; break; }

    # Fim da batalha
    if ! grep -q 'currentControl-' "$SRC" 2>/dev/null; then
      echo "[pve] terminou ($shots_confirmed/$shots_total)"
      local next_apply
      next_apply=$(grep -o -E \
        'pve\?[0-9]+-[0-9]+\.ILinkListener-currentOverview-apply' \
        "$SRC" | head -n1)
      if [ -n "$next_apply" ]; then
        echo "[pve] nova batalha"
        fetch_page "$next_apply"
        sleep_rand 500 1000
        grep -q 'currentControl-attackRegularShellLink' "$SRC" 2>/dev/null || break
        shots_confirmed=0; shots_total=0; hp_max=""
        last_shot_ts=0; immediate_next=0
        continue
      fi
      break
    fi

    local atk repair
    atk=$(grep -o -E \
      'pve\?[0-9]+-[0-9]+\.ILinkListener-currentControl-attackRegularShellLink' \
      "$SRC" | head -n1)
    repair=$(grep -o -E \
      'pve\?[0-9]+-[0-9]+\.ILinkListener-currentControl-repairLink' \
      "$SRC" | head -n1)

    local hp_now
    hp_now=$(grep -o -E \
      'value-block lh1[^>]*>[^<]*<[^>]*>[^<]*>[0-9]+' "$SRC" \
      | grep -o -E '[0-9]+$' | sed -n '1p')
    [ -z "$hp_max" ] && [ -n "$hp_now" ] && hp_max="$hp_now"

    local now=$(date +%s)
    local since_shot=$(( now - last_shot_ts ))
    local since_repair_attempt=$(( now - last_repair_attempt ))

    local hp_pct=""
    [ -n "$hp_now" ] && [ "${hp_max:-0}" -gt 0 ] && \
      hp_pct=$(awk -v n="$hp_now" -v m="$hp_max" \
        'BEGIN{printf"%.0f",n/m*100}' 2>/dev/null)

    # ── REPAIR: tenta de 5 em 5s se HP < 50% ─────────────────
    if [ "${hp_pct:-100}" -le 50 ] && \
       [ "$since_repair_attempt" -ge "$repair_retry" ] 2>/dev/null; then
      last_repair_attempt=$now
      if [ -n "$repair" ]; then
        echo "[pve] REPAIR HP: $hp_now (${hp_pct}%)"
        fetch_page_fast "$repair"
        continue
      else
        echo "[pve] repair indisponivel — tenta em ${repair_retry}s"
      fi
    fi

    # ── DISPARO ───────────────────────────────────────────────
    [ -z "$atk" ] && { sleep 1s; continue; }

    # Calcula espera necessaria
    local wait_rem=0
    if [ "$last_shot_ts" -gt 0 ] && [ "$immediate_next" -eq 0 ]; then
      # Disparo normal: espera 6s desde o ultimo disparo
      wait_rem=$(( reload - since_shot ))
    fi
    # immediate_next=1: manobra detectada → wait_rem=0 → disparo imediato

    if [ "$wait_rem" -gt 0 ]; then
      # Durante a espera, aproveita para repair
      if [ -n "$repair" ] && [ "${hp_pct:-100}" -le 50 ] 2>/dev/null; then
        echo "[pve] REPAIR durante espera HP: $hp_now (${hp_pct}%)"
        fetch_page_fast "$repair"
        last_repair_attempt=$now
        continue
      fi
      sleep "${wait_rem}s"
    fi

    # Guarda contagem de disparos confirmados antes
    local shots_before
    shots_before=$(_pve_count_shots)

    # Dispara
    fetch_page_fast "$atk"
    shots_total=$(( shots_total + 1 ))
    now=$(date +%s)

    # Projétil nao carregado = disparou antes do reload
    if grep -q 'projétil ainda não está carregado\|projetil ainda nao' \
       "$SRC" 2>/dev/null; then
      local remaining=$(( reload - ( now - last_shot_ts ) ))
      [ "$remaining" -lt 1 ] && remaining=1
      echo "[pve] cedo demais — aguarda ${remaining}s"
      sleep "${remaining}s"
      continue
    fi

    # Actualiza timer SEMPRE (confirmado ou anulado)
    last_shot_ts=$(date +%s)

    local shots_after
    shots_after=$(_pve_count_shots)

    if [ "$shots_after" -gt "$shots_before" ] 2>/dev/null; then
      # CONFIRMADO — proximo disparo espera 6s normais
      shots_confirmed=$(( shots_confirmed + 1 ))
      immediate_next=0
      echo "[pve] #${shots_confirmed} confirmado | HP: ${hp_now:-?} (${hp_pct:-?}%)"
    else
      # ANULADO por manobra — proximo disparo e imediato
      immediate_next=1
      echo "[pve] anulado (manobra) — proximo imediato"
    fi

  done

  echo "[pve] fim: $shots_confirmed confirmados / $shots_total tentativas"
  go_hangar
}
