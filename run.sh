#!/bin/bash
# ============================================================
# run.sh — Scheduler principal (detecção dinâmica)
# ============================================================
# IMPORTANTE: Não usa horários fixos para CW/DM/PvE/PvP.
# O fuso de Portugal tem horário de verão (DST) que muda
# os horários em 1h. Em vez de fixar horas, o bot verifica
# dinamicamente se há batalha disponível a cada ciclo.
#
# Lógica:
#   - A cada iteração do loop principal (wartank_play)
#     verificamos se há batalha disponível nas páginas
#   - Se sim → entra imediatamente
#   - Se não → executa rotina de manutenção + idle
#
# Janelas de verificação conhecidas (aproximadas, PT):
#   PvE:  ~06:57, 08:57, 10:57, 12:57, 14:57, 16:57, 18:57, 21:57
#   DM:   ~11:20, 15:20, 21:20
#   CW:   ~18:20 ou 19:20 (Alemanha; outros territórios variam)
#   PvP:  qualquer hora (fila disponível 24h)
# ============================================================

# ── Idle inteligente ─────────────────────────────────────────
func_sleep() {
  local h m min
  printf -v h '%(%H)T' -1
  printf -v m '%(%M)T' -1
  min=$((10#$m))

  # Nos minutos 50-59 → ciclos curtos (batalhas aproximam-se)
  if [ "$min" -ge 50 ]; then
    _idle_wait 20
  # Nos minutos 15-25 → verificação para DM
  elif [ "$min" -ge 15 ] && [ "$min" -le 25 ]; then
    _idle_wait 20
  else
    _idle_wait 60
  fi
}

_idle_wait() {
  local wait_sec="$1"
  local h m
  printf -v h '%(%H)T' -1
  printf -v m '%(%M)T' -1

  echo_t "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "$GRAY_BLACK" "$COLOR_RESET"
  echo_t "🕐 ${h}:${m}  |  👤 ${ACC:-?}  |  ⛽ ${FUEL_CURRENT:-?}" "$GRAY_BLACK" "$COLOR_RESET"
  echo_t "⏳ Próxima verificação em ~${wait_sec}s" "$GRAY_BLACK" "$COLOR_RESET"
  echo_t "[stop] parar  [config] configurar  [status] estado" "$GRAY_BLACK" "$COLOR_RESET"
  echo_t "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "$GRAY_BLACK" "$COLOR_RESET"

  local count=0
  while [ "$count" -lt "$wait_sec" ]; do
    if read -r -t 1 cmd 2>/dev/null; then
      case "$cmd" in
        stop|exit|q|x)
          echo_t "A parar o bot..." "$BLACK_RED" "$COLOR_RESET" "after" "🛑"
          exit 0 ;;
        config) config_menu ;;
        status) hangar_status ;;
      esac
    fi
    count=$(( count + 1 ))
  done
}

# ── Detecção dinâmica de batalhas ────────────────────────────
# Verifica se há batalha disponível AGORA em cada modo.
# Retorna 0 se entrou numa batalha, 1 se não havia nada.
_check_battles_available() {
  local found=1

  # ── CW — verifica se há link de entrada ───────────────────
  if [ "$FUNC_cw" = "y" ]; then
    fetch_page "/cw"
    if _session_active && \
       grep -q 'currentControl-buttons-attackRegularShellLink\|currentOverview-apply' \
       "$SRC" 2>/dev/null; then
      echo_t "🗺️ Guerra disponível!" "$GOLD_BLACK" "$COLOR_RESET"
      cw_check_and_apply
      found=0
    fi
  fi

  # ── DM — verifica se há link de aplicar ───────────────────
  if [ "$FUNC_dm" = "y" ]; then
    fetch_page "/dm"
    if _session_active && \
       grep -q 'currentControl-buttons-attackRegularShellLink\|currentOverview-apply' \
       "$SRC" 2>/dev/null; then
      echo_t "💥 Disputa disponível!" "$GOLD_BLACK" "$COLOR_RESET"
      dm_check_and_apply
      found=0
    fi
  fi

  # ── PvE — verifica se há link de aplicar ──────────────────
  if [ "$FUNC_pve" = "y" ]; then
    fetch_page "/pve"
    if _session_active && \
       grep -q 'currentOverview-apply' "$SRC" 2>/dev/null; then
      echo_t "🎖️ PvE disponível!" "$GOLD_BLACK" "$COLOR_RESET"
      pve_check_and_apply
      found=0
    fi
  fi

  return $found
}

# ── Rotina de manutenção (entre batalhas) ────────────────────
_maintenance() {
  load_config

  # Recolhe missões
  collect_all_rewards

  # Base — recolhe produção
  if [ "$FUNC_buildings" = "y" ]; then
    buildings_func
  fi

  # Escolta
  if [ "$FUNC_convoy" = "y" ]; then
    convoy_mode
  fi

  # Divisão + missão especial
  if [ "$FUNC_company" = "y" ]; then
    company_func
  fi
  if [ "$FUNC_assault" = "y" ]; then
    assault_mode
  fi

  # Batalha normal (combustível)
  if [ "$FUNC_battle" = "y" ]; then
    if check_fuel; then
      adiante_a_combate
    fi
  fi
}

# ── Loop principal ───────────────────────────────────────────
start() {
  _maintenance
  go_hangar
  func_sleep
}

wartank_play() {
  # 1. Verifica sessão
  require_login || return

  # 2. Verifica dinamicamente se há batalhas disponíveis
  _check_battles_available

  # 3. PvP — verifica separadamente (tem fila própria)
  if [ "$FUNC_pvp" = "y" ]; then
    fetch_page "/pvp"
    if _session_active && grep -q 'ILinkListener-joinLink' "$SRC" 2>/dev/null; then
      echo_t "🏆 PvP disponível!" "$GOLD_BLACK" "$COLOR_RESET"
      pvp_mode
      return
    fi
  fi

  # 4. Rotina de manutenção + idle
  start
}
