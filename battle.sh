#!/bin/bash
# battle.sh — Adiante a Combater v1.3.1
# 6 disparos por sessao: 3 no inimigo 0, 3 no inimigo 1
# Link real: battle?3-1.ILinkListener-opponents-opponents-N-opponent-root-bgDiv-attackLink2

adiante_a_combate() {
  [ "$FUNC_battle" = "n" ] && return 0

  echo "[battle] inicio"

  fetch_page "/battle"

  if ! grep -q '<title>Combate</title>' "$SRC" 2>/dev/null; then
    echo "[battle] pagina invalida (titulo: $(grep -o '<title>[^<]*</title>' "$SRC" | head -n1))"
    return 0
  fi

  local la="${BATTLE_LA:-3}"
  local target_shots="${BATTLE_SHOTS:-6}"
  local timeout=$(( $(date +%s) + ${BATTLE_TIMEOUT:-600} ))
  local total_shots=0
  local ATK_LINK target

  echo "[battle] meta: $target_shots disparos | LA: ${la}s"

  while [ "$total_shots" -lt "$target_shots" ] && [ "$(date +%s)" -lt "$timeout" ]; do

    _session_active || { echo "[battle] sessao perdida"; break; }

    # Alterna alvo: primeiros 3 no inimigo 0, seguintes 3 no inimigo 1
    if [ "$total_shots" -lt 3 ]; then
      target=0
    else
      target=1
    fi

    # Extrai link do alvo preferido
    ATK_LINK=$(grep -o -E \
      "battle\?[0-9]+-[0-9]+\.ILinkListener-opponents-opponents-${target}-opponent-root-bgDiv-attackLink2" \
      "$SRC" | head -n1)

    # Fallback: qualquer attackLink na pagina
    if [ -z "$ATK_LINK" ]; then
      ATK_LINK=$(grep -o -E \
        'battle\?[0-9]+-[0-9]+\.ILinkListener-opponents-opponents-[0-9]+-opponent-root-bgDiv-attackLink2' \
        "$SRC" | head -n1)
    fi

    if [ -z "$ATK_LINK" ]; then
      echo "[battle] sem link — recarregando"
      fetch_page "/battle"
      if ! grep -q '<title>Combate</title>' "$SRC" 2>/dev/null; then
        echo "[battle] saiu da pagina de combate"
        break
      fi
      sleep "${la}s"
      continue
    fi

    sleep "${la}s"
    fetch_page "$ATK_LINK"
    sleep_rand 200 500
    total_shots=$(( total_shots + 1 ))
    echo "[battle] disparo $total_shots/$target_shots (inimigo $target)"

  done

  echo "[battle] fim: $total_shots disparos"
  go_hangar
}
