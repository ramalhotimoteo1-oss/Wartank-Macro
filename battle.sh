#!/bin/bash
# battle.sh — Adiante a Combater v1.4.0
#
# Fluxo real confirmado nos HTMLs:
#
#   Estado 1 — Pagina inicial (/battle), 2 oponentes:
#     opponents-opponents-0-...-attackLink2  → "Disparar"
#     opponents-opponents-1-...-attackLink2  → "Disparar"
#
#   Estado 2 — Apos 1 disparo, inimigo com vida:
#     lastOpponentPanel-...-attackLink2      → "Acabar de matar"
#
#   Estado 3 — Apos 2 disparos, inimigo quase morto:
#     lastOpponentPanel-...-attackLink2      → "Destruir"
#
#   Estado 4 — Inimigo destruido, novos oponentes:
#     opponents-opponents-0-...-attackLink2  → "Disparar"  (volta ao estado 1)
#
#   REGEX UNIVERSAL: battle?X-X.ILinkListener-[qualquer coisa]-attackLink2
#   Cobre todos os estados sem necessidade de alternar logica.
#
# Logica simplificada:
#   - Procura sempre o primeiro attackLink2 disponivel na pagina
#   - Dispara
#   - A pagina seguinte ja mostra o proximo botao correcto
#   - Repete ate BATTLE_SHOTS disparos

adiante_a_combate() {
  [ "$FUNC_battle" = "n" ] && return 0

  echo "[battle] inicio"

  fetch_page "/battle"

  if ! grep -q '<title>Combate</title>' "$SRC" 2>/dev/null; then
    echo "[battle] pagina invalida: $(grep -o '<title>[^<]*</title>' "$SRC" 2>/dev/null | head -n1)"
    return 0
  fi

  local la="${BATTLE_LA:-3}"
  local target_shots="${BATTLE_SHOTS:-6}"
  local timeout=$(( $(date +%s) + ${BATTLE_TIMEOUT:-600} ))
  local total_shots=0
  local ATK_LINK
  local miss=0

  echo "[battle] meta: $target_shots disparos | LA: ${la}s"

  while [ "$total_shots" -lt "$target_shots" ] && [ "$(date +%s)" -lt "$timeout" ]; do

    _session_active || { echo "[battle] sessao perdida"; break; }

    # Sem combustivel — site redireccionou para fora do Combate
    if ! grep -q '<title>Combate</title>' "$SRC" 2>/dev/null; then
      echo "[battle] saiu do combate: $(grep -o '<title>[^<]*</title>' "$SRC" 2>/dev/null | head -n1)"
      break
    fi

    # REGEX UNIVERSAL — apanha qualquer attackLink2 independente do estado
    # Cobre: Disparar, Acabar de matar, Destruir
    ATK_LINK=$(grep -o -E \
      'battle\?[0-9]+-[0-9]+\.ILinkListener-[^"]+attackLink2' \
      "$SRC" | head -n1)

    if [ -z "$ATK_LINK" ]; then
      miss=$(( miss + 1 ))
      echo "[battle] sem link ($miss/3) — recarregando"
      # Apos 3 tentativas sem link, desiste
      if [ "$miss" -ge 3 ]; then
        echo "[battle] sem link apos 3 tentativas, a terminar"
        break
      fi
      fetch_page "/battle"
      sleep "${la}s"
      continue
    fi

    # Encontrou link — reset do contador de miss
    miss=0

    # Intervalo entre disparos
    sleep "${la}s"

    # Dispara
    fetch_page "$ATK_LINK"
    sleep_rand 200 500
    total_shots=$(( total_shots + 1 ))
    echo "[battle] disparo $total_shots/$target_shots"

  done

  echo "[battle] fim: $total_shots disparos"
  go_hangar
}
