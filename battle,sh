#!/bin/bash
# ============================================================
# battle.sh — Módulo "Adiante a Combater"
# Regex baseados no HTML real do wartank-pt.net
# ============================================================
# Estrutura da página /battle:
#   Título: "Combate"
#   Links de disparo:
#     href="battle;jsessionid=...?12-1.ILinkListener-opponents-opponents-0-opponent-root-bgDiv-attackLink2"
#   Texto do botão: "Disparar"
#   Inimigos: opponents-0, opponents-1 (fraco e forte)
# ============================================================

adiante_a_combate() {
  echo_t "Adiante a Combater!" "$GOLD_BLACK" "$COLOR_RESET" "after" "⚔️"

  go_hangar
  if ! has_fuel; then
    echo_t "Sem combustível. A voltar ao hangar." "$BLACK_RED" "$COLOR_RESET" "after" "⛽"
    return 0
  fi

  fetch_page "/battle"

  # Verifica se está na página de combate
  if ! grep -q '<title>Combate</title>' "$TMP/SRC" 2>/dev/null; then
    echo_t "Página de combate não encontrada." "$BLACK_YELLOW" "$COLOR_RESET" "after" "⚠️"
    go_hangar
    return 0
  fi

  local shots=0
  local enemies=0
  local BREAK=$(( $(date +%s) + 600 )) # timeout 10 min
  local LAST_ATK=0

  while [ "$(date +%s)" -lt "$BREAK" ]; do

    _battle_extract_links

    # Sem combustível?
    if _battle_no_fuel; then
      echo_t "Combustível esgotado." "$BLACK_YELLOW" "$COLOR_RESET" "after" "⛽"
      break
    fi

    # Sem inimigos disponíveis?
    if [ -z "$ATK_LINK" ]; then
      # Volta ao hangar — sem oponentes
      echo_t "Sem oponentes disponíveis." "$GRAY_BLACK" "$COLOR_RESET"
      break
    fi

    # Respeita intervalo entre disparos
    local now elapsed
    now=$(date +%s)
    elapsed=$(( now - LAST_ATK ))
    if [ "$elapsed" -lt "${BATTLE_LA:-3}" ]; then
      sleep $(( BATTLE_LA - elapsed ))s
    fi

    # Dispara
    fetch_page "/${ATK_LINK}"
    LAST_ATK=$(date +%s)
    shots=$(( shots + 1 ))
    echo_t "  💥 Disparo #${shots} → ${ATK_TARGET:-inimigo}" "$GRAY_BLACK" "$COLOR_RESET"

    # Verifica resultado
    _battle_extract_links

  done

  echo_t "Combate concluído. Disparos: ${shots}" "$GREEN_BLACK" "$COLOR_RESET" "after" "✅"
  go_hangar
}

_battle_extract_links() {
  # ── Links de disparo ─────────────────────────────────────────
  # HTML real:
  #   href="battle;jsessionid=...?12-1.ILinkListener-opponents-opponents-0-opponent-root-bgDiv-attackLink2"
  # O número antes de ILinkListener muda a cada request (ex: 12-1)
  # opponents-0 = inimigo fraco, opponents-1 = inimigo forte

  # Apanha todos os links de disparo disponíveis
  ATK_LINK=$(grep -o -E 'battle;jsessionid=[A-Z0-9]+\?[0-9]+-[0-9]+\.ILinkListener-opponents-opponents-[0-9]+-opponent-root-bgDiv-attackLink2' \
    "$TMP/SRC" | head -n1)

  # Nome do alvo
  ATK_TARGET=$(grep -B5 'attackLink2' "$TMP/SRC" 2>/dev/null \
    | grep -o -E 'class="small bold cD[0-9]+ cntr sh_b pb2">[^<]*</div>' \
    | sed 's/.*">//;s/<.*//' | head -n1 | xargs)

  # Potência do inimigo
  ATK_POWER=$(grep -o -E 'Potência de tanque: [0-9]+' "$TMP/SRC" | grep -o -E '[0-9]+' | head -n1)
}

_battle_no_fuel() {
  # Detecta mensagem de sem combustível
  # O site pode redirecionar para hangar ou mostrar mensagem
  if grep -q '<title>Hangar</title>' "$TMP/SRC" 2>/dev/null; then
    return 0
  fi
  # Sem link de disparo e sem título de combate = sem combustível ou sessão expirada
  if ! grep -q '<title>Combate</title>' "$TMP/SRC" 2>/dev/null && \
     ! grep -q 'attackLink2' "$TMP/SRC" 2>/dev/null; then
    return 0
  fi
  return 1
}
