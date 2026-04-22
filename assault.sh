#!/bin/bash
# assault.sh — Missao Especial v1.3.0
# Fix: fluxo completo — entrar > comecar > esperar inicio > combater
#
# Fluxo confirmado:
#   /company/ → "Missao especial" → /company/assault
#   Lista de alvos → Entrar (assaults-4 = Abrigo Subterraneo)
#   Lobby da missao → "Comecar o combate!"
#   Espera o combate iniciar (contagem regressiva)
#   Combate activo → disparar ate destruir
#
# Cooldown: 20h apos destruicao
# Derrota: missao continua disponivel (tenta novamente)
# Solo: Abrigo Subterraneo (20.000 HP) — unico viavel solo

assault_mode() {
  [ "$FUNC_assault" = "n" ] && return 0

  echo "[assault] verificar"

  fetch_page "/company/assault"
  if ! _session_active; then return; fi

  if ! grep -q '<title>Missão especial</title>' "$SRC" 2>/dev/null; then
    echo "[assault] pagina invalida"
    return
  fi

  # Ja esta numa missao activa (lobby com startBattleLink)?
  if grep -q 'overview-startBattleLink\|overview-refreshLink' "$SRC" 2>/dev/null; then
    echo "[assault] ja aplicado — a processar"
    _assault_start_and_fight
    return
  fi

  # Procura Abrigo Subterraneo (index 4)
  local join_link
  join_link=$(grep -o -E \
    'assault\?[0-9]+-[0-9]+\.ILinkListener-allAssaults-assaults-4-joinLink' \
    "$SRC" | head -n1)

  # Fallback: mais facil disponivel
  if [ -z "$join_link" ]; then
    for idx in 4 0 1 2 3; do
      join_link=$(grep -o -E \
        "assault\?[0-9]+-[0-9]+\.ILinkListener-allAssaults-assaults-${idx}-joinLink" \
        "$SRC" | head -n1)
      [ -n "$join_link" ] && break
    done
  fi

  if [ -z "$join_link" ]; then
    echo "[assault] sem missao disponivel (cooldown 20h)"
    return
  fi

  echo "[assault] a entrar no Abrigo Subterraneo"
  fetch_page "$join_link"
  sleep_rand 1000 1500

  if ! grep -q 'overview-refreshLink\|overview-startBattleLink' "$SRC" 2>/dev/null; then
    echo "[assault] falhou ao entrar"
    return
  fi

  echo "[assault] entrou — a iniciar combate"
  _assault_start_and_fight
}

# ── Inicia o combate e espera comecar ─────────────────────────
_assault_start_and_fight() {
  local objective members start_link refresh_link

  objective=$(grep -o -E 'Objetivo: [^<]+' "$SRC" | sed 's/Objetivo: //' | head -n1)
  members=$(grep -o -E 'Tanquistas: [0-9]+ de [0-9]+' "$SRC" | head -n1)
  echo "[assault] $objective | $members"

  start_link=$(grep -o -E \
    'assault\?[0-9]+-[0-9]+\.ILinkListener-overview-startBattleLink' \
    "$SRC" | head -n1)
  refresh_link=$(grep -o -E \
    'assault\?[0-9]+-[0-9]+\.ILinkListener-overview-refreshLink' \
    "$SRC" | head -n1)

  # Clica "Comecar o combate!"
  if [ -n "$start_link" ]; then
    echo "[assault] a clicar 'Comecar o combate!'"
    fetch_page "$start_link"
    sleep_rand 1000 2000
  else
    echo "[assault] botao 'Comecar' nao encontrado — a fazer refresh"
    [ -n "$refresh_link" ] && fetch_page "$refresh_link"
    start_link=$(grep -o -E \
      'assault\?[0-9]+-[0-9]+\.ILinkListener-overview-startBattleLink' \
      "$SRC" | head -n1)
    if [ -n "$start_link" ]; then
      fetch_page "$start_link"
      sleep_rand 1000 2000
    else
      echo "[assault] sem botao de inicio"
      return
    fi
  fi

  # Espera o combate iniciar — faz refresh ate aparecer link de ataque
  echo "[assault] a aguardar inicio do combate..."
  local wait_timeout=$(( $(date +%s) + 60 ))

  while [ "$(date +%s)" -lt "$wait_timeout" ]; do
    # Combate activo?
    if grep -q 'attackRegularShellLink\|attackLink' "$SRC" 2>/dev/null; then
      echo "[assault] combate iniciado!"
      _assault_fight
      return
    fi

    # Refresh enquanto espera
    refresh_link=$(grep -o -E \
      'assault\?[0-9]+-[0-9]+\.ILinkListener-overview-refreshLink' \
      "$SRC" | head -n1)
    if [ -n "$refresh_link" ]; then
      fetch_page "$refresh_link"
    else
      sleep 3s
    fi

    sleep_rand 2000 3000
  done

  echo "[assault] timeout a aguardar inicio"
}

# ── Loop de combate da missao especial ────────────────────────
_assault_fight() {
  local shots=0
  local timeout=$(( $(date +%s) + 600 ))
  local la="${BATTLE_LA:-3}"

  echo "[assault] em combate"

  while [ "$(date +%s)" -lt "$timeout" ]; do
    _session_active || break

    # Extrai link de ataque
    local atk_link
    atk_link=$(grep -o -E \
      'assault\?[0-9]+-[0-9]+\.ILinkListener-[^"]+attackRegularShellLink' \
      "$SRC" | head -n1)

    # Sem link — combate terminou
    if [ -z "$atk_link" ]; then
      echo "[assault] combate terminou ($shots disparos)"
      break
    fi

    sleep "${la}s"
    fetch_page "$atk_link"
    sleep_rand 200 400
    shots=$(( shots + 1 ))
    echo "[assault] disparo $shots"
  done

  echo "[assault] fim"
}
