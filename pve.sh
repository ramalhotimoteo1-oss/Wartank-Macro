#!/bin/bash
# pve.sh — PvE (Batalhas Historicas) v2.0.0
# HTML real confirmado:
#
# LOBBY (/pve):
#   titulo: "Batalhas"
#   apply:   pve?X-X.ILinkListener-currentOverview-apply
#   refresh: pve?X-X.ILinkListener-refresh
#
# COMBATE ACTIVO:
#   titulo: "Batalhas" (igual ao lobby — detectar por currentControl)
#   atk:    pve?6-32.ILinkListener-currentControl-attackRegularShellLink
#   repair: pve?6-32.ILinkListener-currentControl-repairLink
#   maneuver: pve?6-32.ILinkListener-currentControl-maneuverLink
#   change: pve?6-32.ILinkListener-currentControl-changeTargetLink
#   escape: pve?6-32.ILinkListener-currentControl-escape
#   HP jogador (class green1): value-block lh1 → 3029
#   HP inimigo (class red1):   value-block lh1 → 3136
#   Dano recebido: "A explosão do projetíl da artilharia causou-lhe danos 107"
#   Reload: 6 segundos entre disparos

pve_check_and_apply() {
  [ "$FUNC_pve" = "n" ] && return 0

  fetch_page "/pve"
  if ! _session_active; then return; fi

  # Batalha activa? (detect por currentControl)
  if grep -q 'currentControl-attackRegularShellLink' "$SRC" 2>/dev/null; then
    echo "[pve] batalha activa"
    _pve_fight
    return
  fi

  # Botao de aplicar disponivel?
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
    # Verifica se ja entrou em combate
    grep -q 'currentControl-attackRegularShellLink' "$SRC" 2>/dev/null && \
      _pve_fight
  fi
}

pve_mode() {
  [ "$FUNC_pve" = "n" ] && return 0
  pve_check_and_apply
}

_pve_fight() {
  local timeout=$(( $(date +%s) + ${PVE_TIMEOUT:-600} ))
  local shots=0
  local last_atk=0
  local last_repair=0
  local last_maneuver=0
  local hp_max=""
  local reload=6  # 6 segundos (confirmado)

  echo "[pve] combate iniciado"

  while [ "$(date +%s)" -lt "$timeout" ]; do
    _session_active || { echo "[pve] sessao perdida"; break; }

    # Fim da batalha — sem currentControl volta ao lobby
    if ! grep -q 'currentControl-' "$SRC" 2>/dev/null; then
      echo "[pve] batalha terminou ($shots disparos)"
      # Lobby pode ter nova batalha disponivel
      local next_apply
      next_apply=$(grep -o -E \
        'pve\?[0-9]+-[0-9]+\.ILinkListener-currentOverview-apply' \
        "$SRC" | head -n1)
      if [ -n "$next_apply" ]; then
        echo "[pve] nova batalha disponivel — a aplicar"
        fetch_page "$next_apply"
        sleep_rand 500 1000
        grep -q 'currentControl-attackRegularShellLink' "$SRC" 2>/dev/null || break
        shots=0
        hp_max=""
        continue
      fi
      break
    fi

    # Extrai links — padrao real confirmado
    local atk repair maneuver
    atk=$(grep -o -E \
      'pve\?[0-9]+-[0-9]+\.ILinkListener-currentControl-attackRegularShellLink' \
      "$SRC" | head -n1)
    repair=$(grep -o -E \
      'pve\?[0-9]+-[0-9]+\.ILinkListener-currentControl-repairLink' \
      "$SRC" | head -n1)
    maneuver=$(grep -o -E \
      'pve\?[0-9]+-[0-9]+\.ILinkListener-currentControl-maneuverLink' \
      "$SRC" | head -n1)

    # HP jogador (class green1 = jogador no PvE)
    # Extrai o value-block que vem apos "green1"
    local hp_now
    hp_now=$(grep -B1 'value-block lh1' "$SRC" 2>/dev/null \
      | grep -A1 'green1' \
      | grep -o -E '[0-9]+' | tail -n1)
    # Fallback: primeiro value-block
    [ -z "$hp_now" ] && \
      hp_now=$(grep -o -E 'value-block lh1[^>]*>[^<]*<[^>]*>[^<]*>[0-9]+' "$SRC" \
        | grep -o -E '[0-9]+$' | sed -n '1p')

    [ -z "$hp_max" ] && hp_max="${hp_now:-0}"

    local now=$(date +%s)
    local since_repair=$(( now - last_repair ))
    local since_maneuver=$(( now - last_maneuver ))
    local since_atk=$(( now - last_atk ))

    # ── REPAIR a 50% HP ───────────────────────────────────────
    if [ -n "$repair" ] && [ -n "$hp_now" ] && [ "${hp_max:-0}" -gt 0 ] \
       && [ "$since_repair" -ge 90 ] 2>/dev/null; then
      local hp_pct
      hp_pct=$(awk -v n="$hp_now" -v m="$hp_max" \
        'BEGIN{printf"%.0f",n/m*100}' 2>/dev/null)
      if [ -n "$hp_pct" ] && [ "$hp_pct" -le 50 ] 2>/dev/null; then
        echo "[pve] REPAIR HP: $hp_now (${hp_pct}%)"
        fetch_page "$repair"
        last_repair=$now
        sleep_rand 300 500
        continue
      fi
    fi

    # ── MANOBRA apos dano ──────────────────────────────────────
    if [ -n "$maneuver" ] && [ "$since_maneuver" -ge 20 ] 2>/dev/null; then
      if grep -q 'causou-lhe danos\|causou danos' "$SRC" 2>/dev/null; then
        echo "[pve] manobra"
        fetch_page "$maneuver"
        last_maneuver=$now
        sleep_rand 300 500
        continue
      fi
    fi

    # ── DISPARO: 6 segundos de intervalo ──────────────────────
    if [ -n "$atk" ] 2>/dev/null; then
      local wait_rem=$(( reload - since_atk ))
      [ "$wait_rem" -gt 0 ] && sleep "${wait_rem}s"
      fetch_page "$atk"
      last_atk=$(date +%s)
      shots=$(( shots + 1 ))
      echo "[pve] #${shots} | HP: ${hp_now:-?}/${hp_max:-?}"
    else
      sleep 1s
    fi

  done

  echo "[pve] fim: $shots disparos"
  go_hangar
}
