#!/bin/bash
# config.sh — Configuracao v1.3.0
# CONFIG_FILE usa BOT_DIR para funcionar com qualquer nome de pasta

# BOT_DIR definido no core.sh (detectado automaticamente)
CONFIG_FILE="${BOT_DIR}/config.cfg"

default_config() {
  cat > "$CONFIG_FILE" << 'EOF'
FUNC_pvp=y
FUNC_pvp_hour=21
FUNC_battle=y
FUNC_missions=y
FUNC_special_missions=y
FUNC_pve=y
FUNC_cw=y
FUNC_dm=y
FUNC_convoy=y
FUNC_buildings=y
FUNC_assault=y
FUNC_company=y
BATTLE_LA=3
BATTLE_SHOTS=6
BATTLE_TIMEOUT=600
FUEL_MIN=0
ASSAULT_MIN_MEMBERS=2
EOF
  echo "[config] criado em: $CONFIG_FILE"
}

load_config() {
  # Garante que CONFIG_FILE aponta para o sitio correcto
  CONFIG_FILE="${BOT_DIR}/config.cfg"

  if [ ! -f "$CONFIG_FILE" ]; then
    echo "[config] nao encontrado, a criar..."
    default_config
  fi
  # shellcheck disable=SC1090
  . "$CONFIG_FILE"
}

set_config() {
  local key="$1" value="$2"
  CONFIG_FILE="${BOT_DIR}/config.cfg"
  if grep -q "^${key}=" "$CONFIG_FILE" 2>/dev/null; then
    sed -i "s|^${key}=.*|${key}=${value}|" "$CONFIG_FILE"
  else
    echo "${key}=${value}" >> "$CONFIG_FILE"
  fi
}

get_config() {
  local key="$1"
  load_config
  echo "${!key}"
}

config_menu() {
  load_config
  while true; do
    clear
    echo "=== Configuracoes ==="
    echo "1) Batalha:      $FUNC_battle"
    echo "2) Missoes:      $FUNC_missions"
    echo "3) PvP:          $FUNC_pvp (hora: $FUNC_pvp_hour)"
    echo "4) PvE:          $FUNC_pve"
    echo "5) Guerra:       $FUNC_cw"
    echo "6) Disputa:      $FUNC_dm"
    echo "7) Escolta:      $FUNC_convoy"
    echo "8) Base:         $FUNC_buildings"
    echo "9) BATTLE_LA:    $BATTLE_LA s"
    echo "0) BATTLE_SHOTS: $BATTLE_SHOTS"
    echo "ENTER) Sair"
    read -r -n 1 opt
    case "$opt" in
      1) echo "batalla (y/n):"; read -r v; set_config "FUNC_battle" "$v" ;;
      2) echo "missoes (y/n):"; read -r v; set_config "FUNC_missions" "$v" ;;
      3) echo "pvp (y/n):"; read -r v; set_config "FUNC_pvp" "$v" ;;
      4) echo "pve (y/n):"; read -r v; set_config "FUNC_pve" "$v" ;;
      5) echo "guerra (y/n):"; read -r v; set_config "FUNC_cw" "$v" ;;
      6) echo "disputa (y/n):"; read -r v; set_config "FUNC_dm" "$v" ;;
      7) echo "escolta (y/n):"; read -r v; set_config "FUNC_convoy" "$v" ;;
      8) echo "base (y/n):"; read -r v; set_config "FUNC_buildings" "$v" ;;
      9) echo "LA segundos:"; read -r v; set_config "BATTLE_LA" "$v" ;;
      0) echo "disparos:"; read -r v; set_config "BATTLE_SHOTS" "$v" ;;
      "") break ;;
    esac
    load_config
    sleep 0.3s
  done
}
