#!/bin/bash
# pve.sh — PvE v2.3.0
#
# LOGICA DE DISPARO (confirmada na imagem):
#
#   CASO 1 — Disparo normal:
#     dispara → "disparou a X para N danos" → espera 6s → dispara
#
#   CASO 2 — Manobra do inimigo (disparo anulado):
#     dispara → sem "disparou a" no log → dispara IMEDIATAMENTE
#     repete ate aparecer "disparou a" no log
#     quando confirma → espera 6s → dispara
#
#   CASO 3 — "O projétil ainda não está carregado":
#     bot disparou antes dos 6s → espera o tempo restante → dispara
#
# COMO DETECTAR SE DISPARO FOI CONFIRMADO:
#   Lê o log ANTES do disparo → guarda ultima linha
#   Dispara → lê log DEPOIS
#   Compara: se apareceu nova linha com "disparou a" → confirmado
#   Se nao apareceu linha nova com dano → manobra → dispara imediatamente
#
# REPAIR:
#   HP < 50% → tenta repair
#   Se repair nao disponivel → tenta de 5 em 5s (sem cooldown fixo de 90s)

pve_check_and_apply() {
  [ "$FUNC_pve" = "n" ] && return 0

  fetch_page "/pve"
  if ! _session_active; then return; fi

  if grep -q 'currentControl-attackRegularShellLink' "$SRC" 2>/dev/null; then
    echo "[pve] batalha activa"
    _pve_fight
    return
  fi

  local apply_link
  apply_link=$(grep -o -E \
    'pve\?[0-9]+-[0-9]+\.ILinkListener-currentOverview-apply' \
    "$SRC" | head -n1)

  if [ -n "$apply_link" ]; then
    local battle_name wait_time
    battle_name=$(grep -o -E 'class="green2">[^<]+' "$SRC" \
      | sed 's/.*">//' | head -n1)
    wait_time=$(grep -o -E 'ate o inicio [0-9:]+' "$SRC" | head -n1)
    echo "[pve] a aplicar: ${battle_name:-batalha} ${wait_time}"
    fetch_page "$apply_link"
    sleep_rand 500 1000
    grep -q 'currentControl-attackRegularShellLink' "$SRC" 2>/dev/null && \
      _pve_fight
  fi
}

pve_mode() {
  [ "$FUNC_pve" = "n" ] && return 0
  pve_check_and_apply
}

# ── Extrai o conteudo do log de combate ──────────────────────
_pve_log() {
  grep -o -E 'wrap-content small white.*' "$SRC" 2>/dev/null \
    | sed 's/<[^>]*>//g' | tr -s ' \n' '\n' | grep -v '^$'
}

# ── Conta linhas de "disparou a" no log — detecta novo disparo confirmado
_pve_count_shots() {
  grep -c 'disparou a.*danos\|disparou a.*crit' "$SRC" 2>/dev/null || echo 0
}

_pve_fight() {
  local timeout=$(( $(date +%s) + ${PVE_TIMEOUT:-600} ))
  local shots_confirmed=0
  local shots_total=0
  local last_confirmed_ts=0
  local hp_max=""
  local reload=6

  # Variaveis de repair sem cooldown fixo
  local last_repair_attempt=0
  local repair_retry=5  # tenta repair a cada 5s se HP < 50%

  echo "[pve] combate iniciado"

  while [ "$(date +%s)" -lt "$timeout" ]; do
    _session_active || { echo "[pve] sessao perdida"; break; }

    # Fim da batalha
    if ! grep -q 'currentControl-' "$SRC" 2>/dev/null; then
      echo "[pve] terminou ($shots_confirmed/$shots_total)"
      local next_apply
      next_apply=$(grep -o -E \
        'pve\?[0-9]+-[0-9]+\.ILinkListener-currentOverview-apply' \
        "$SRC" | head -n1)
      if [ -n "$next_apply" ]; then
        echo "[pve] nova batalha"
        fetch_page "$next_apply"
        sleep_rand 500 1000
        grep -q 'currentControl-attackRegularShellLink' "$SRC" 2>/dev/null || break
        shots_confirmed=0; shots_total=0; hp_max=""; last_confirmed_ts=0
        continue
      fi
      break
    fi

    # Extrai links
    local atk repair
    atk=$(grep -o -E \
      'pve\?[0-9]+-[0-9]+\.ILinkListener-currentControl-attackRegularShellLink' \
      "$SRC" | head -n1)
    repair=$(grep -o -E \
      'pve\?[0-9]+-[0-9]+\.ILinkListener-currentControl-repairLink' \
      "$SRC" | head -n1)

    # HP actual
    local hp_now
    hp_now=$(grep -o -E \
      'value-block lh1[^>]*>[^<]*<[^>]*>[^<]*>[0-9]+' "$SRC" \
      | grep -o -E '[0-9]+$' | sed -n '1p')
    [ -z "$hp_max" ] && [ -n "$hp_now" ] && hp_max="$hp_now"

    local now=$(date +%s)
    local since_confirmed=$(( now - last_confirmed_ts ))
    local since_repair_attempt=$(( now - last_repair_attempt ))

    # ── REPAIR: sem cooldown fixo ─────────────────────────────
    # Se HP < 50%, tenta; se nao disponivel, tenta de 5 em 5s
    if [ -n "$hp_now" ] && [ "${hp_max:-0}" -gt 0 ] 2>/dev/null; then
      local hp_pct
      hp_pct=$(awk -v n="$hp_now" -v m="$hp_max" \
        'BEGIN{printf"%.0f",n/m*100}' 2>/dev/null)

      if [ "${hp_pct:-100}" -le 50 ] && \
         [ "$since_repair_attempt" -ge "$repair_retry" ] 2>/dev/null; then
        last_repair_attempt=$now
        if [ -n "$repair" ]; then
          echo "[pve] REPAIR HP: $hp_now (${hp_pct}%)"
          fetch_page_fast "$repair"
          continue
        else
          echo "[pve] repair nao disponivel — tenta em ${repair_retry}s"
        fi
      fi
    fi

    # ── DISPARO ───────────────────────────────────────────────
    [ -z "$atk" ] && { sleep 1s; continue; }

    # Guarda contagem de disparos confirmados ANTES de disparar
    local shots_before
    shots_before=$(_pve_count_shots)

    # Verifica se precisa esperar recarga
    if [ "$last_confirmed_ts" -gt 0 ]; then
      local wait_rem=$(( reload - since_confirmed ))
      if [ "$wait_rem" -gt 0 ]; then
        # Durante a espera: verifica repair
        if [ -n "$repair" ] && [ "${hp_pct:-100}" -le 50 ] 2>/dev/null; then
          echo "[pve] REPAIR durante espera HP: $hp_now (${hp_pct}%)"
          fetch_page_fast "$repair"
          last_repair_attempt=$now
          continue
        fi
        sleep "${wait_rem}s"
      fi
    fi

    # Dispara (sem sleep extra — fetch_page_fast)
    fetch_page_fast "$atk"
    shots_total=$(( shots_total + 1 ))
    now=$(date +%s)

    # ── Analisa resultado ─────────────────────────────────────

    # CASO: "projétil não carregado" = disparo antes dos 6s
    if grep -q 'projétil ainda não está carregado\|projetil ainda nao' \
       "$SRC" 2>/dev/null; then
      local remaining=$(( reload - ( now - last_confirmed_ts ) ))
      [ "$remaining" -lt 0 ] && remaining=1
      echo "[pve] cedo demais — aguarda ${remaining}s"
      sleep "${remaining}s"
      continue
    fi

    # Conta disparos confirmados DEPOIS
    local shots_after
    shots_after=$(_pve_count_shots)

    if [ "$shots_after" -gt "$shots_before" ] 2>/dev/null; then
      # CONFIRMADO — novo "disparou a" apareceu no log
      shots_confirmed=$(( shots_confirmed + 1 ))
      last_confirmed_ts=$(date +%s)
      hp_pct=$(awk -v n="${hp_now:-0}" -v m="${hp_max:-1}" \
        'BEGIN{printf"%.0f",n/m*100}' 2>/dev/null)
      echo "[pve] #${shots_confirmed} confirmado | HP: ${hp_now:-?} (${hp_pct:-?}%)"
    else
      # NAO CONFIRMADO — inimigo usou manobra, disparo anulado
      # NAO actualiza last_confirmed_ts → dispara imediatamente
      echo "[pve] anulado (manobra) — disparo imediato"
    fi

  done

  echo "[pve] fim: $shots_confirmed confirmados / $shots_total tentativas"
  go_hangar
}
