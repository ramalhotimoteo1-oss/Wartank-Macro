#!/bin/bash
# battle.sh — Adiante a Combater v1.3.0
#
# Logica: a cada 45 min, destruir 2 inimigos (6 ataques total)
#   - 3 ataques no inimigo 0 (fraco)
#   - 3 ataques no inimigo 1 (forte)
#
# HTML real confirmado:
#   titulo: "Combate"
#   link: battle?3-1.ILinkListener-opponents-opponents-0-opponent-root-bgDiv-attackLink2
#   link: battle?3-1.ILinkListener-opponents-opponents-1-opponent-root-bgDiv-attackLink2
#   O numero "3-1" muda a cada sessao — capturado dinamicamente
#   O jsessionid NAO aparece no href — adicionado automaticamente por fetch_page

adiante_a_combate() {
  [ "$FUNC_battle" = "n" ] && return 0

  echo "[battle] inicio"

  fetch_page "/battle"

  # Verifica pagina correcta
  if ! grep -q '<title>Combate</title>' "$SRC" 2>/dev/null; then
    echo "[battle] pagina invalida ou sem combustivel"
    go_hangar
    return 0
  fi

  # Sem combustivel = redirecionou para hangar
  if grep -q '<title>Hangar</title>' "$SRC" 2>/dev/null; then
    echo "[battle] sem combustivel"
    return 0
  fi

  local la="${BATTLE_LA:-3}"
  local duration="${BATTLE_TIMEOUT:-600}"
  local timeout=$(( $(date +%s) + duration ))
  local total_shots=0
  local target_shots="${BATTLE_SHOTS:-6}"   # 6 disparos = 2 inimigos destruidos
  local ATK_LINK
  local atk_path

  echo "[battle] meta: $target_shots disparos ($la s intervalo)"

  while [ "$total_shots" -lt "$target_shots" ] && [ "$(date +%s)" -lt "$timeout" ]; do

    # Verifica sessao
    _session_active || { echo "[battle] sessao perdida"; break; }

    # Sem combustivel durante combate
    if grep -q '<title>Hangar</title>' "$SRC" 2>/dev/null; then
      echo "[battle] sem combustivel"
      return 0
    fi

    # Extrai link de disparo dinamicamente
    # Padrao real: battle?X-X.ILinkListener-opponents-opponents-N-opponent-root-bgDiv-attackLink2
    # Alterna entre inimigo 0 e 1 para destruir os 2
    local target=0
    [ $(( total_shots % 3 )) -ge 0 ] && [ "$total_shots" -ge 3 ] && target=1

    ATK_LINK=$(grep -o -E \
      "battle\?[0-9]+-[0-9]+\.ILinkListener-opponents-opponents-${target}-opponent-root-bgDiv-attackLink2" \
      "$SRC" | head -n1)

    # Fallback: qualquer attackLink disponivel
    if [ -z "$ATK_LINK" ]; then
      ATK_LINK=$(grep -o -E \
        'battle\?[0-9]+-[0-9]+\.ILinkListener-opponents-opponents-[0-9]+-opponent-root-bgDiv-attackLink[0-9]*' \
        "$SRC" | head -n1)
    fi

    if [ -z "$ATK_LINK" ]; then
      echo "[battle] sem link de disparo"
      # Recarrega a pagina e tenta novamente
      fetch_page "/battle"
      sleep_rand 1000 2000
      continue
    fi

    # Intervalo entre disparos
    sleep "${la}s"

    # Dispara — fetch_page adiciona jsessionid automaticamente
    fetch_page "$ATK_LINK"
    sleep_rand 200 500
    total_shots=$(( total_shots + 1 ))
    echo "[battle] disparo $total_shots/$target_shots (inimigo $target)"

  done

  echo "[battle] fim ($total_shots disparos)"
  go_hangar
}
