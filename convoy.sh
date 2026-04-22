#!/bin/bash
# convoy.sh — Escolta v1.3.0
# Fix: logica de combate correcta
#
# Regras confirmadas:
#   - Cooldown: 40 min (gerido pelo run.sh)
#   - Combate: maximo 3 disparos por inimigo
#   - Se inimigo morrer com 3 ou menos disparos: procura novo inimigo
#   - Se inimigo nao morrer com 3 disparos: batalha encerra (novo ciclo)
#   - Maximo 2 inimigos por sessao
#
# Inimigos (por ordem de dificuldade):
#   Obus auto-propulsado: 1000 HP
#   Tanque:               1200 HP
#   Trem blindado:        1600 HP

convoy_mode() {
  [ "$FUNC_convoy" = "n" ] && return 0

  echo "[convoy] inicio"

  fetch_page "/convoy"
  if ! _session_active; then return; fi

  if ! grep -q '<title>Escolta</title>' "$SRC" 2>/dev/null; then
    echo "[convoy] pagina invalida"
    return
  fi

  # Recolhe recompensas de missoes se disponiveis
  local award_link collected=0
  while IFS= read -r award_link; do
    [ -z "$award_link" ] && continue
    echo "[convoy] a recolher recompensa"
    fetch_page "$award_link"
    collected=$(( collected + 1 ))
    sleep_rand 300 500
    fetch_page "/convoy"
  done < <(grep -o -E \
    'convoy\?[0-9]+-[0-9]+\.ILinkListener-missions-cc-[0-9]+-c-awardLink' \
    "$SRC" 2>/dev/null)

  [ "$collected" -gt 0 ] && echo "[convoy] $collected recompensa(s) recolhida(s)"

  # Inicia reconhecimento
  local find_link
  find_link=$(grep -o -E \
    'convoy\?[0-9]+-[0-9]+\.ILinkListener-root-findEnemy' \
    "$SRC" | head -n1)

  if [ -z "$find_link" ]; then
    echo "[convoy] reconhecimento nao disponivel"
    return
  fi

  # Loop: maximo 2 inimigos por sessao
  local enemies_killed=0
  local max_enemies=2

  while [ "$enemies_killed" -lt "$max_enemies" ]; do
    echo "[convoy] a procurar inimigo ($((enemies_killed+1))/$max_enemies)"

    fetch_page "$find_link"
    sleep_rand 800 1200

    # Verifica se encontrou inimigo para atacar
    local act_link
    act_link=$(grep -o -E \
      'convoy\?[0-9]+-[0-9]+\.ILinkListener-root-banner-actLink' \
      "$SRC" | head -n1)

    if [ -z "$act_link" ]; then
      echo "[convoy] sem inimigo encontrado"
      break
    fi

    echo "[convoy] inimigo encontrado — a entrar em combate"
    fetch_page "$act_link"
    sleep_rand 500 800

    # Combate: maximo 3 disparos
    local result
    result=$(_convoy_fight)

    if [ "$result" = "killed" ]; then
      enemies_killed=$(( enemies_killed + 1 ))
      echo "[convoy] inimigo destruido ($enemies_killed/$max_enemies)"
      # Atualiza link de reconhecimento para proximo inimigo
      find_link=$(grep -o -E \
        'convoy\?[0-9]+-[0-9]+\.ILinkListener-root-findEnemy' \
        "$SRC" | head -n1)
      [ -z "$find_link" ] && break
    else
      # 3 disparos sem destruir — sessao encerra
      echo "[convoy] inimigo nao destruido — sessao encerrada"
      break
    fi
  done

  echo "[convoy] fim ($enemies_killed inimigo(s) destruido(s))"
}

# ── Combate contra um inimigo (max 3 disparos) ────────────────
# Retorna: "killed" se destruiu, "timeout" se nao destruiu em 3 tiros
_convoy_fight() {
  local shots=0
  local max_shots=3
  local la="${BATTLE_LA:-3}"

  while [ "$shots" -lt "$max_shots" ]; do
    _session_active || { echo "timeout"; return; }

    # Link de ataque ao inimigo do comboio
    local atk_link
    atk_link=$(grep -o -E \
      'convoy\?[0-9]+-[0-9]+\.ILinkListener-[^"]*attack[^"]*' \
      "$SRC" | head -n1)

    if [ -z "$atk_link" ]; then
      # Sem link de ataque = inimigo destruido ou saiu do combate
      echo "killed"
      return
    fi

    sleep "${la}s"
    fetch_page "$atk_link"
    sleep_rand 200 400
    shots=$(( shots + 1 ))
    echo "[convoy] disparo $shots/$max_shots"

    # Verifica se inimigo foi destruido (sem mais link de ataque)
    local next_atk
    next_atk=$(grep -o -E \
      'convoy\?[0-9]+-[0-9]+\.ILinkListener-[^"]*attack[^"]*' \
      "$SRC" | head -n1)
    if [ -z "$next_atk" ]; then
      echo "killed"
      return
    fi
  done

  # 3 disparos feitos, inimigo ainda vivo
  echo "timeout"
}
