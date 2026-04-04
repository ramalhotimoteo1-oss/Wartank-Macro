#!/bin/bash
# battle.sh — Adiante a Combater v1.5.0
#
# Logica baseada no TitansWarPro/arena_duel:
#   - fetch_page inicial em /battle
#   - extrai link do SRC actual
#   - dispara (fetch_page do link)
#   - a resposta JA contem o proximo link (lastOpponentPanel ou novo opponents)
#   - NAO volta a /battle — continua a partir do SRC actual
#   - so volta a /battle se nao houver link (novo ciclo)
#
# Fluxo real confirmado nos HTMLs:
#   /battle                           → opponents-opponents-N-attackLink2 "Disparar"
#   → disparo →                       → lastOpponentPanel-attackLink2     "Acabar de matar"
#   → disparo →                       → lastOpponentPanel-attackLink2     "Destruir"
#   → disparo →                       → opponents-opponents-N-attackLink2 "Disparar" (novo)
#
# Regex universal: battle?X-X.ILinkListener-*-attackLink2

adiante_a_combate() {
  [ "$FUNC_battle" = "n" ] && return 0

  echo "[battle] inicio"

  # Unico fetch inicial — como o TitansWarPro faz fetch_page "/arena/"
  fetch_page "/battle"

  if ! grep -q '<title>Combate</title>' "$SRC" 2>/dev/null; then
    echo "[battle] pagina invalida: $(grep -o '<title>[^<]*</title>' "$SRC" 2>/dev/null)"
    return 0
  fi

  local la="${BATTLE_LA:-3}"
  local target_shots="${BATTLE_SHOTS:-6}"
  local timeout=$(( $(date +%s) + ${BATTLE_TIMEOUT:-600} ))
  local total_shots=0
  local ATK_LINK

  echo "[battle] meta: $target_shots disparos | LA: ${la}s"

  while [ "$total_shots" -lt "$target_shots" ] && [ "$(date +%s)" -lt "$timeout" ]; do

    _session_active || { echo "[battle] sessao perdida"; break; }

    # Verifica se ainda esta em pagina de combate
    if ! grep -q '<title>Combate</title>' "$SRC" 2>/dev/null; then
      echo "[battle] saiu do combate"
      break
    fi

    # Extrai link do SRC ACTUAL (nao recarrega a pagina)
    # Cobre todos os estados: Disparar, Acabar de matar, Destruir
    ATK_LINK=$(grep -o -E \
      'battle\?[0-9]+-[0-9]+\.ILinkListener-[^"]+attackLink2' \
      "$SRC" | head -n1)

    if [ -z "$ATK_LINK" ]; then
      # Sem link no SRC actual — tenta recarregar /battle uma vez
      echo "[battle] sem link, a recarregar /battle"
      fetch_page "/battle"
      ATK_LINK=$(grep -o -E \
        'battle\?[0-9]+-[0-9]+\.ILinkListener-[^"]+attackLink2' \
        "$SRC" | head -n1)
      if [ -z "$ATK_LINK" ]; then
        echo "[battle] sem link apos reload, a terminar"
        break
      fi
    fi

    # Intervalo entre disparos (BATTLE_LA segundos)
    sleep "${la}s"

    # Dispara — a resposta do fetch ja contem o proximo estado
    fetch_page "$ATK_LINK"
    sleep_rand 200 400
    total_shots=$(( total_shots + 1 ))
    echo "[battle] disparo $total_shots/$target_shots"

    # NAO fazer fetch_page "/battle" aqui — o SRC ja tem o proximo link

  done

  echo "[battle] fim: $total_shots disparos"
  go_hangar
}
