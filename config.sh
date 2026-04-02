#!/bin/bash
# ============================================================
# config.sh — Configuração, load/save, defaults
# ============================================================

CONFIG_FILE="$HOME/wartank-bot/config.cfg"

default_config() {
  cat > "$CONFIG_FILE" <<EOF
# ── Wartank Bot — Configuração ──────────────────────────────
URL=https://wartank-pt.net
TIMEZONE=Europe/Lisbon

# ── Funcões activas (y/n) ────────────────────────────────────
FUNC_pvp=y
FUNC_pvp_hour=21
FUNC_battle=y
FUNC_campaign=y
FUNC_missions=y
FUNC_special_missions=y
FUNC_event_missions=y
FUNC_pve=y
FUNC_cw=y
FUNC_dm=y
FUNC_convoy=y
FUNC_buildings=y
FUNC_assault=y
FUNC_company=y
ASSAULT_MIN_MEMBERS=2
FUNC_auto_update=n

# ── Combate ──────────────────────────────────────────────────
BATTLE_LA=3          # intervalo entre disparos (segundos)
BATTLE_REPAIR_PCT=30 # % vida para usar kit de reparação
BATTLE_MANEUVER_CD=20 # cooldown manobra (segundos)
BATTLE_REPAIR_CD=90  # cooldown repair (segundos)

# ── PvP ──────────────────────────────────────────────────────
PVP_BATTLES=4        # batalhas por sessão
PVP_WAIT_PLAYERS=5   # aguardar N jogadores
PVP_REFRESH_INTERVAL=10 # segundos entre refreshes na fila

# ── Combustível ───────────────────────────────────────────────
FUEL_PER_SHOT=30     # combustível por disparo
FUEL_MIN=0           # mínimo antes de voltar hangar
EOF
  echo_t "Config criado com valores padrão." "$GREEN_BLACK" "$COLOR_RESET"
}

load_config() {
  if [ ! -f "$CONFIG_FILE" ]; then
    echo_t "Config não encontrado. A criar..." "$BLACK_YELLOW" "$COLOR_RESET"
    default_config
  fi
  # shellcheck disable=SC1090
  . "$CONFIG_FILE"
}

get_config() {
  local key="$1"
  load_config
  echo "${!key}"
}

set_config() {
  local key="$1"
  local value="$2"
  load_config
  if grep -q "^${key}=" "$CONFIG_FILE"; then
    sed -i "s|^${key}=.*|${key}=${value}|" "$CONFIG_FILE"
  else
    echo "${key}=${value}" >> "$CONFIG_FILE"
  fi
}

# Menu de configuração interativo
config_menu() {
  load_config
  while true; do
    clear
    echo_t "⚙️  Configurações do Bot" "$BLACK_CYAN" "$COLOR_RESET"
    echo ""
    echo_t "1) PvP activo:              $FUNC_pvp"
    echo_t "2) Batalha activa:          $FUNC_battle"
    echo_t "3) Campanha activa:         $FUNC_campaign"
    echo_t "4) Missões activas:         $FUNC_missions"
    echo_t "5) Missões especiais:       $FUNC_special_missions"
    echo_t "6) Intervalo disparo (LA):  ${BATTLE_LA}s"
    echo_t "7) Repair em % vida:        ${BATTLE_REPAIR_PCT}%"
    echo_t "8) Combustível mínimo:      $FUEL_MIN"
    echo ""
    echo_t "ENTER) Sair" "$GRAY_BLACK" "$COLOR_RESET"
    echo ""
    read -r -n 1 opt
    case "$opt" in
      1) echo_t "PvP (y/n):"; read -r v; set_config "FUNC_pvp" "$v" ;;
      2) echo_t "Batalha (y/n):"; read -r v; set_config "FUNC_battle" "$v" ;;
      3) echo_t "Campanha (y/n):"; read -r v; set_config "FUNC_campaign" "$v" ;;
      4) echo_t "Missões (y/n):"; read -r v; set_config "FUNC_missions" "$v" ;;
      5) echo_t "Missões especiais (y/n):"; read -r v; set_config "FUNC_special_missions" "$v" ;;
      6) echo_t "Intervalo disparo (segundos):"; read -r v; set_config "BATTLE_LA" "$v" ;;
      7) echo_t "Repair em % de vida (ex: 30):"; read -r v; set_config "BATTLE_REPAIR_PCT" "$v" ;;
      8) echo_t "Combustível mínimo:"; read -r v; set_config "FUEL_MIN" "$v" ;;
      "") break ;;
    esac
    load_config
    sleep 0.5s
  done
}
