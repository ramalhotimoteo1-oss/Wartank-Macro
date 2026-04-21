#!/bin/bash
# pve.sh — PvE (Batalhas Historicas) v1.3.0
# HTML real confirmado via docx
#
# LOBBY (/pve):
#   titulo: "Batalhas"
#   apply:   pve?X-X.ILinkListener-currentOverview-apply  → "Pelotao, ao ataque!"
#   refresh: pve?X-X.ILinkListener-refresh
#   "ate o inicio HH:MM:SS (N requerimentos)"
#   apos fim: lobby aparece imediatamente com "0 requerimentos" e novo apply
#
# DENTRO DA BATALHA (/pve com currentControl):
#   titulo: "Batalhas" (igual ao lobby — detectar por currentControl)
#   disparo: pve?X-X.ILinkListener-currentControl-attackRegularShellLink
#   especial: pve?X-X.ILinkListener-currentControl-attackSpecialShellLink
#   repair:   pve?X-X.ILinkListener-currentControl-repairLink
#   manobra:  pve?X-X.ILinkListener-currentControl-maneuverLink
#   alvo:     pve?X-X.ILinkListener-currentControl-changeTargetLink
#   sair:     pve?X-X.ILinkListener-currentControl-escape
#   HP jogador (verde, class green1): value-block lh1 → 1472
#   HP inimigo (vermelho, class red1): value-block lh1 → 2458
#   Info: "dos Tanques no combate: 15"
#   Reload: 6s entre disparos para 100% da capacidade
#
# TIMING:
#   Deteccao dinamica — verifica apply a cada ciclo
#   Nao usa horarios fixos (resistente ao DST Portugal)
#   Apos fim: lobby tem novo apply imediatamente → aplica logo

# ── Verifica e aplica em PvE ─────────────────────────────────
pve_check_and_apply() {
  [ "$FUNC_pve" = "n" ] && return 0

  fetch_page "/pve"
  if ! _session_active; then return; fi

  # Batalha ja activa?
  if grep -q 'currentControl-attackRegularShellLink' "$SRC" 2>/dev/null; then
    echo "[pve] batalha activa — a combater"
    _pve_fight
    return
  fi

  # Botao de aplicar disponivel?
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
    # Verifica se entrou na batalha
    if grep -q 'currentControl-attackRegularShellLink' "$SRC" 2>/dev/null; then
      echo "[pve] batalha iniciada"
      _pve_fight
    fi
  fi
}

pve_mode() {
  [ "$FUNC_pve" = "n" ] && return 0
  pve_check_and_apply
}

# ── Loop de combate PvE ──────────────────────────────────────
_pve_fight() {
  local timeout=$(( $(date +%s) + ${PVE_TIMEOUT:-600} ))
  local shots=0
  local last_atk=0
  local reload="${PVE_RELOAD:-6}"  # 6s = 100% capacidade

  echo "[pve] combate iniciado"

  while [ "$(date +%s)" -lt "$timeout" ]; do

    _session_active || { echo "[pve] sessao perdida"; break; }

    # Fim da batalha — lobby aparece sem currentControl
    if ! grep -q 'currentControl-' "$SRC" 2>/dev/null; then
      echo "[pve] batalha terminou"
      # Lobby ja tem novo apply — aplica imediatamente
      local next_apply
      next_apply=$(grep -o -E \
        'pve\?[0-9]+-[0-9]+\.ILinkListener-currentOverview-apply' \
        "$SRC" | head -n1)
      if [ -n "$next_apply" ]; then
        echo "[pve] nova batalha disponivel — a aplicar"
        fetch_page "$next_apply"
        sleep_rand 500 1000
        # Se entrou numa nova batalha continua o loop
        grep -q 'currentControl-attackRegularShellLink' "$SRC" 2>/dev/null || break
        shots=0
        continue
      fi
      break
    fi

    # Extrai links de combate
    local atk atk_special repair maneuver change_target
    atk=$(grep -o -E \
      'pve\?[0-9]+-[0-9]+\.ILinkListener-currentControl-attackRegularShellLink' \
      "$SRC" | head -n1)
    atk_special=$(grep -o -E \
      'pve\?[0-9]+-[0-9]+\.ILinkListener-currentControl-attackSpecialShellLink' \
      "$SRC" | head -n1)
    repair=$(grep -o -E \
      'pve\?[0-9]+-[0-9]+\.ILinkListener-currentControl-repairLink' \
      "$SRC" | head -n1)

    # HP do jogador (class green1, primeiro value-block)
    local hp_player
    hp_player=$(grep -A3 'green1' "$SRC" 2>/dev/null \
      | grep -o -E 'value-block lh1[^>]*>[^<]*<[^>]*>[^<]*>[0-9]+' \
      | grep -o -E '[0-9]+$' | head -n1)

    # Repair se HP baixo
    if [ -n "$repair" ] && [ -n "$hp_player" ] && [ "$hp_player" -lt 500 ] 2>/dev/null; then
      echo "[pve] repair! HP: $hp_player"
      fetch_page "$repair"
      sleep_rand 500 800
      continue
    fi

    # Aguarda reload de 6s
    local now elapsed
    now=$(date +%s)
    elapsed=$(( now - last_atk ))
    if [ "$elapsed" -lt "$reload" ]; then
      sleep $(( reload - elapsed ))s
    fi

    # Disparo
    if [ -n "$atk" ]; then
      fetch_page "$atk"
      last_atk=$(date +%s)
      shots=$(( shots + 1 ))
      echo "[pve] disparo $shots | HP: ${hp_player:-?}"
    else
      sleep 1s
    fi

  done

  echo "[pve] fim: $shots disparos"
  go_hangar
}
