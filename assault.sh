#!/bin/bash
# assault.sh — Missao Especial (Assault)
# Nao bloqueia o bot — entra, verifica, sai

assault_mode() {
  [ "$FUNC_assault" = "n" ] && return 0

  echo "[assault] verificar"
  fetch_page "/company/assault"
  if ! _session_active; then return; fi
  if ! grep -q '<title>Missão especial</title>' "$SRC" 2>/dev/null; then
    return
  fi

  # Ja esta numa missao activa — apenas regista, nao bloqueia
  if grep -q 'overview-startBattleLink\|overview-refreshLink' "$SRC" 2>/dev/null; then
    local objective members
    objective=$(grep -o -E 'Objetivo: [^<]+' "$SRC" | sed 's/Objetivo: //' | head -n1)
    members=$(grep -o -E 'Tanquistas: [0-9]+ de [0-9]+' "$SRC" | head -n1)
    echo "[assault] activo: ${objective:-?} | ${members:-?}"

    # Inicia se tiver membros suficientes — sem aguardar
    local start_link min="${ASSAULT_MIN_MEMBERS:-2}"
    start_link=$(grep -o -E 'assault\?[0-9]+-[0-9]+\.ILinkListener-overview-startBattleLink' \
      "$SRC" | head -n1)
    local current
    current=$(grep -o -E 'Tanquistas: [0-9]+' "$SRC" | grep -o -E '[0-9]+' | head -n1)
    if [ -n "$start_link" ] && [ -n "$current" ] && [ "$current" -ge "$min" ]; then
      echo "[assault] a iniciar combate ($current membros)"
      fetch_page "/$start_link"
    fi
    return
  fi

  # Entra no primeiro alvo disponivel — sem aguardar membros
  local join_link
  join_link=$(grep -o -E \
    'assault\?[0-9]+-[0-9]+\.ILinkListener-allAssaults-assaults-[0-9]+-joinLink' \
    "$SRC" | head -n1)

  if [ -n "$join_link" ]; then
    echo "[assault] a entrar"
    fetch_page "/$join_link"
    sleep_rand 500 1000
  fi
}
