#!/bin/bash
# assault.sh — Missao Especial v1.5.0
# Fix: guarda SRC em cada passo para debug
# Fix: repair aplicado no combate

assault_mode() {
  [ "$FUNC_assault" = "n" ] && return 0
  echo "[assault] verificar"

  fetch_page "/company/assault"
  if ! _session_active; then return; fi

  # Guarda sempre o SRC para debug
  cp "$SRC" "$TMP/assault_lobby.html" 2>/dev/null

  if ! grep -q '<title>Missão especial</title>' "$SRC" 2>/dev/null; then
    echo "[assault] pagina invalida: $(grep -o '<title>[^<]*</title>' "$SRC" | head -n1)"
    return
  fi

  echo "[assault] links encontrados:"
  grep -o -E 'assault\?[^"]+' "$SRC" | sed 's/^/  /' | head -8

  # Ja aplicado?
  if grep -q 'overview-startBattleLink\|overview-refreshLink\|overview-unapplyLink' \
     "$SRC" 2>/dev/null; then
    echo "[assault] ja aplicado"
    _assault_start_and_fight
    return
  fi

  # Entra no Abrigo Subterraneo (index 4)
  local join_link
  for idx in 4 0 1 2 3; do
    join_link=$(grep -o -E \
      "assault\?[0-9]+-[0-9]+\.ILinkListener-allAssaults-assaults-${idx}-joinLink" \
      "$SRC" | head -n1)
    [ -n "$join_link" ] && break
  done

  if [ -z "$join_link" ]; then
    echo "[assault] sem joinLink disponivel"
    return
  fi

  echo "[assault] a entrar: $join_link"
  fetch_page "$join_link"
  cp "$SRC" "$TMP/assault_after_join.html" 2>/dev/null
  sleep_rand 1000 1500

  echo "[assault] apos entrar — links:"
  grep -o -E 'assault\?[^"]+' "$SRC" | sed 's/^/  /' | head -8

  if ! grep -q 'overview-refreshLink\|overview-startBattleLink\|overview-unapplyLink' \
     "$SRC" 2>/dev/null; then
    echo "[assault] falhou ao entrar"
    return
  fi

  _assault_start_and_fight
}

_assault_start_and_fight() {
  local objective members
  objective=$(grep -o -E 'Objetivo: [^<]+' "$SRC" | sed 's/Objetivo: //' | head -n1)
  members=$(grep -o -E 'Tanquistas: [0-9]+ de [0-9]+' "$SRC" | head -n1)
  echo "[assault] $objective | $members"

  local start_link refresh_link
  start_link=$(grep -o -E \
    'assault\?[0-9]+-[0-9]+\.ILinkListener-overview-startBattleLink' \
    "$SRC" | head -n1)
  refresh_link=$(grep -o -E \
    'assault\?[0-9]+-[0-9]+\.ILinkListener-overview-refreshLink' \
    "$SRC" | head -n1)

  if [ -n "$start_link" ]; then
    echo "[assault] a clicar start: $start_link"
    fetch_page "$start_link"
    cp "$SRC" "$TMP/assault_after_start.html" 2>/dev/null
    echo "[assault] apos start — guarda em $TMP/assault_after_start.html"
    sleep_rand 1000 2000
  else
    echo "[assault] sem startBattleLink"
    [ -n "$refresh_link" ] && fetch_page "$refresh_link" && sleep 2s
    start_link=$(grep -o -E \
      'assault\?[0-9]+-[0-9]+\.ILinkListener-overview-startBattleLink' \
      "$SRC" | head -n1)
    [ -n "$start_link" ] && fetch_page "$start_link" && sleep_rand 1000 2000
  fi

  # Aguarda inicio — refresh em loop ate 3 min
  local wait_timeout=$(( $(date +%s) + 180 ))
  echo "[assault] a aguardar inicio do combate (max 3 min)..."

  while [ "$(date +%s)" -lt "$wait_timeout" ]; do
    cp "$SRC" "$TMP/assault_waiting.html" 2>/dev/null

    if grep -q 'attackRegularShellLink\|attackSpecialShellLink' "$SRC" 2>/dev/null; then
      echo "[assault] combate iniciado!"
      _assault_fight
      return
    fi

    local secs_left=$(( wait_timeout - $(date +%s) ))
    echo "[assault] aguarda ${secs_left}s | links: $(grep -o -E 'assault\?[^"]+' "$SRC" | head -3 | tr '\n' ' ')"

    refresh_link=$(grep -o -E \
      'assault\?[0-9]+-[0-9]+\.ILinkListener-overview-refreshLink' \
      "$SRC" | head -n1)
    if [ -n "$refresh_link" ]; then
      fetch_page "$refresh_link"
    else
      fetch_page "/company/assault"
    fi
    sleep 5s
  done

  echo "[assault] timeout — ficheiros de debug em $TMP/assault_*.html"
  echo "[assault] envia o conteudo de $TMP/assault_after_start.html"
}

_assault_fight() {
  local shots=0
  local timeout=$(( $(date +%s) + 600 ))
  local la="${BATTLE_LA:-3}"
  local last_repair=0
  local hp_max=""

  while [ "$(date +%s)" -lt "$timeout" ]; do
    _session_active || break

    local atk_link repair_link
    atk_link=$(grep -o -E \
      'assault\?[0-9]+-[0-9]+\.ILinkListener-[^"]+attackRegularShellLink' \
      "$SRC" | head -n1)
    repair_link=$(grep -o -E \
      'assault\?[0-9]+-[0-9]+\.ILinkListener-[^"]+repairLink' \
      "$SRC" | head -n1)

    [ -z "$atk_link" ] && { echo "[assault] fim ($shots disparos)"; break; }

    # Repair a 50% HP
    local hp_now since_repair
    hp_now=$(grep -o -E 'value-block lh1[^>]*>[^<]*<[^>]*>[^<]*>[0-9]+' "$SRC" \
      | grep -o -E '[0-9]+$' | sed -n '1p')
    [ -z "$hp_max" ] && hp_max="${hp_now:-0}"
    since_repair=$(( $(date +%s) - last_repair ))

    if [ -n "$repair_link" ] && [ -n "$hp_now" ] && [ "$hp_max" -gt 0 ] \
       && [ "$since_repair" -ge 90 ] 2>/dev/null; then
      local hp_pct
      hp_pct=$(awk -v n="$hp_now" -v m="$hp_max" 'BEGIN{printf"%.0f",n/m*100}' 2>/dev/null)
      if [ -n "$hp_pct" ] && [ "$hp_pct" -le 50 ] 2>/dev/null; then
        echo "[assault] REPAIR HP: $hp_now (${hp_pct}%)"
        fetch_page "$repair_link"
        last_repair=$(date +%s)
        sleep_rand 300 500
        continue
      fi
    fi

    sleep "${la}s"
    fetch_page "$atk_link"
    sleep_rand 200 400
    shots=$(( shots + 1 ))
    echo "[assault] disparo $shots | HP: ${hp_now:-?}"
  done

  echo "[assault] combate terminou: $shots disparos"
}
