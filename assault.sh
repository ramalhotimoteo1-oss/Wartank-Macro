#!/bin/bash
# assault.sh — Missao Especial v2.0.0
# HTML real confirmado — dois estados distintos:
#
# CONTAGEM REGRESSIVA:
#   titulo: "Missão especial"
#   texto:  "Para o começo da batalha ficam N segundos"
#   refresh: assault?X-X.ILinkListener-control-banner-refresh
#
# COMBATE ACTIVO:
#   titulo: "Missão especial"
#   atk:    assault?X-X.ILinkListener-control-buttons-attackRegularShellLink
#   repair: assault?X-X.ILinkListener-control-buttons-repairLink
#   HP:     value-block lh1 → 2876
#
# LOBBY (antes de iniciar):
#   titulo: "Missão especial"
#   start:  assault?X-X.ILinkListener-overview-startBattleLink
#   refresh: assault?X-X.ILinkListener-overview-refreshLink

assault_mode() {
  [ "$FUNC_assault" = "n" ] && return 0
  echo "[assault] verificar"

  fetch_page "/company/assault"
  if ! _session_active; then return; fi

  if ! grep -q '<title>Missão especial</title>' "$SRC" 2>/dev/null; then
    echo "[assault] pagina invalida"
    return
  fi

  # Estado 1: combate ja activo
  if grep -q 'control-buttons-attackRegularShellLink' "$SRC" 2>/dev/null; then
    echo "[assault] combate activo"
    _assault_fight
    return
  fi

  # Estado 2: contagem regressiva
  if grep -q 'control-banner-refresh' "$SRC" 2>/dev/null; then
    echo "[assault] contagem regressiva — a aguardar"
    _assault_wait_countdown
    return
  fi

  # Estado 3: lobby — ja aplicado, pronto para iniciar
  if grep -q 'overview-startBattleLink\|overview-refreshLink\|overview-unapplyLink' \
     "$SRC" 2>/dev/null; then
    echo "[assault] lobby activo"
    _assault_start
    return
  fi

  # Estado 4: lista de missoes — escolhe Abrigo Subterraneo
  local join_link
  for idx in 4 0 1 2 3; do
    join_link=$(grep -o -E \
      "assault\?[0-9]+-[0-9]+\.ILinkListener-allAssaults-assaults-${idx}-joinLink" \
      "$SRC" | head -n1)
    [ -n "$join_link" ] && break
  done

  if [ -z "$join_link" ]; then
    echo "[assault] sem missao disponivel (cooldown 20h)"
    return
  fi

  echo "[assault] a entrar no Abrigo Subterraneo"
  fetch_page "$join_link"
  sleep_rand 1000 1500

  # Re-detecta estado apos entrar
  if grep -q 'control-buttons-attackRegularShellLink' "$SRC" 2>/dev/null; then
    _assault_fight
  elif grep -q 'control-banner-refresh' "$SRC" 2>/dev/null; then
    _assault_wait_countdown
  elif grep -q 'overview-startBattleLink' "$SRC" 2>/dev/null; then
    _assault_start
  else
    echo "[assault] estado desconhecido apos entrar"
  fi
}

# ── Lobby: clica Comecar ──────────────────────────────────────
_assault_start() {
  local objective members
  objective=$(grep -o -E 'Objetivo: [^<]+' "$SRC" | sed 's/Objetivo: //' | head -n1)
  members=$(grep -o -E 'Tanquistas: [0-9]+ de [0-9]+' "$SRC" | head -n1)
  echo "[assault] $objective | $members"

  local start_link
  start_link=$(grep -o -E \
    'assault\?[0-9]+-[0-9]+\.ILinkListener-overview-startBattleLink' \
    "$SRC" | head -n1)

  if [ -z "$start_link" ]; then
    # Refresh e tenta de novo
    local ref
    ref=$(grep -o -E \
      'assault\?[0-9]+-[0-9]+\.ILinkListener-overview-refreshLink' \
      "$SRC" | head -n1)
    [ -n "$ref" ] && fetch_page "$ref" && sleep 2s
    start_link=$(grep -o -E \
      'assault\?[0-9]+-[0-9]+\.ILinkListener-overview-startBattleLink' \
      "$SRC" | head -n1)
  fi

  [ -z "$start_link" ] && { echo "[assault] sem botao start"; return; }

  echo "[assault] a clicar 'Comecar o combate!'"
  fetch_page "$start_link"
  sleep_rand 1000 2000

  # Apos clicar, pode ir para contagem regressiva ou combate directo
  if grep -q 'control-buttons-attackRegularShellLink' "$SRC" 2>/dev/null; then
    _assault_fight
  elif grep -q 'control-banner-refresh' "$SRC" 2>/dev/null; then
    _assault_wait_countdown
  else
    echo "[assault] a aguardar estado apos start..."
    sleep 3s
    fetch_page "/company/assault"
    grep -q 'control-buttons-attackRegularShellLink' "$SRC" 2>/dev/null && \
      _assault_fight
  fi
}

# ── Contagem regressiva: refresh ate combate iniciar ─────────
_assault_wait_countdown() {
  local timeout=$(( $(date +%s) + 60 ))
  echo "[assault] contagem regressiva..."

  while [ "$(date +%s)" -lt "$timeout" ]; do
    # Combate iniciado?
    if grep -q 'control-buttons-attackRegularShellLink' "$SRC" 2>/dev/null; then
      echo "[assault] combate iniciado!"
      _assault_fight
      return
    fi

    local countdown
    countdown=$(grep -o -E 'ficam [0-9]+ segundo' "$SRC" | grep -o -E '[0-9]+')
    echo "[assault] ${countdown:-?} segundos..."

    # Refresh com link correcto: control-banner-refresh
    local ref
    ref=$(grep -o -E \
      'assault\?[0-9]+-[0-9]+\.ILinkListener-control-banner-refresh' \
      "$SRC" | head -n1)

    if [ -n "$ref" ]; then
      fetch_page "$ref"
    else
      fetch_page "/company/assault"
    fi
    sleep 3s
  done

  echo "[assault] timeout na contagem regressiva"
}

# ── Combate activo ────────────────────────────────────────────
_assault_fight() {
  local shots=0
  local timeout=$(( $(date +%s) + 600 ))
  local la="${BATTLE_LA:-3}"
  local last_repair=0
  local hp_max=""

  echo "[assault] em combate"

  while [ "$(date +%s)" -lt "$timeout" ]; do
    _session_active || break

    # Links reais: control-buttons-attackRegularShellLink
    local atk repair
    atk=$(grep -o -E \
      'assault\?[0-9]+-[0-9]+\.ILinkListener-control-buttons-attackRegularShellLink' \
      "$SRC" | head -n1)
    repair=$(grep -o -E \
      'assault\?[0-9]+-[0-9]+\.ILinkListener-control-buttons-repairLink' \
      "$SRC" | head -n1)

    [ -z "$atk" ] && { echo "[assault] combate terminou ($shots disparos)"; break; }

    # HP do jogador: value-block lh1 → primeiro numero
    local hp_now
    hp_now=$(grep -o -E 'value-block lh1[^>]*>[^<]*<[^>]*>[^<]*>[0-9]+' "$SRC" \
      | grep -o -E '[0-9]+$' | sed -n '1p')
    [ -z "$hp_max" ] && hp_max="${hp_now:-0}"

    # Repair a 50% HP
    local since_repair=$(( $(date +%s) - last_repair ))
    if [ -n "$repair" ] && [ -n "$hp_now" ] && [ "$hp_max" -gt 0 ] \
       && [ "$since_repair" -ge 90 ] 2>/dev/null; then
      local hp_pct
      hp_pct=$(awk -v n="$hp_now" -v m="$hp_max" \
        'BEGIN{printf"%.0f",n/m*100}' 2>/dev/null)
      if [ -n "$hp_pct" ] && [ "$hp_pct" -le 50 ] 2>/dev/null; then
        echo "[assault] REPAIR HP: $hp_now (${hp_pct}%)"
        fetch_page "$repair"
        last_repair=$(date +%s)
        sleep_rand 300 500
        continue
      fi
    fi

    sleep "${la}s"
    fetch_page "$atk"
    sleep_rand 200 400
    shots=$(( shots + 1 ))
    echo "[assault] disparo $shots | HP: ${hp_now:-?}"
  done

  echo "[assault] fim: $shots disparos"
}
