#!/bin/bash
# battle.sh — Adiante a Combater v1.2.1
# HTML real confirmado:
#   /battle = titulo "Combate"
#   link disparo: battle;jsessionid=X?12-1.ILinkListener-opponents-opponents-N-opponent-root-bgDiv-attackLink2
#   sem combustivel: redireciona para hangar (title="Hangar")

adiante_a_combate() {
  [ "$FUNC_battle" = "n" ] && return 0

  echo "[battle] inicio"

  fetch_page "/battle"

  if ! grep -q '<title>Combate</title>' "$SRC" 2>/dev/null; then
    echo "[battle] pagina invalida ou sem combustivel"
    go_hangar
    return 0
  fi

  local shots=0
  local duration="${BATTLE_TIMEOUT:-600}"
  local timeout=$(( $(date +%s) + duration ))
  local last_atk=0
  local la="${BATTLE_LA:-3}"
  local ATK_LINK
  local atk_path

  while [ "$(date +%s)" -lt "$timeout" ]; do

    # Verifica sessao activa
    _session_active || break

    # Sem combustivel = redireccionou para hangar
    if grep -q '<title>Hangar</title>' "$SRC" 2>/dev/null; then
      echo "[battle] sem combustivel"
      return 0
    fi

    # Extrai link de disparo
    # attackLink (sem numero fixo) — mais resiliente a mudancas no HTML
    ATK_LINK=$(grep -o -E \
      'battle;jsessionid=[A-Z0-9]+\?[0-9]+-[0-9]+\.ILinkListener-opponents-opponents-[0-9]+-opponent-root-bgDiv-attackLink' \
      "$SRC" | head -n1)

    # Sem link = sem oponentes ou combustivel esgotado
    if [ -z "$ATK_LINK" ]; then
      echo "[battle] sem link de disparo, a terminar"
      break
    fi

    # Respeita intervalo entre disparos (BATTLE_LA)
    local now elapsed
    now=$(date +%s)
    elapsed=$(( now - last_atk ))
    if [ "$elapsed" -lt "$la" ]; then
      sleep $(( la - elapsed ))s
    fi

    # Converte URL completa em path relativo para fetch_page
    atk_path=$(echo "$ATK_LINK" | sed 's|battle;jsessionid=[A-Z0-9]*\?|battle?|')
    fetch_page "$atk_path"
    sleep_rand 200 500
    last_atk=$(date +%s)
    shots=$(( shots + 1 ))
    echo "[battle] disparo $shots"

  done

  echo "[battle] fim ($shots disparos)"
  go_hangar
}
