#!/bin/bash
# wartank.sh — Engine principal v1.4.1

BOT_DIR="$(cd "$(dirname "$0")" && pwd)"
export BOT_DIR
# Sempre usa .tmp dentro da pasta do bot — ignora TMP do sistema
export TMP="$BOT_DIR/.tmp"
export URL="${URL:-https://wartank-pt.net}"
export LOG_FILE="${LOG_FILE:-$TMP/bot.log}"
export USER_AGENT="Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36"

mkdir -p "$TMP"
exec 2>>"$LOG_FILE"

# Log rotation — mantém apenas as ultimas 500 linhas
if [ -f "$LOG_FILE" ] && [ "$(wc -l < "$LOG_FILE" 2>/dev/null)" -gt 500 ]; then
  tail -500 "$LOG_FILE" > "$LOG_FILE.tmp" && mv "$LOG_FILE.tmp" "$LOG_FILE"
fi

# Dependencias
for cmd in curl grep sed awk base64; do
  command -v "$cmd" >/dev/null 2>&1 || {
    echo "ERRO: '$cmd' nao encontrado. Instala: pkg install $cmd"
    exit 1
  }
done

# Carrega modulos
_load() {
  local f="$BOT_DIR/$1"
  if [ ! -f "$f" ]; then
    echo "ERRO: '$1' nao encontrado em $BOT_DIR"
    exit 1
  fi
  . "$f"
}

_load core.sh
_load combat_common.sh
_load config.sh
_load login.sh
_load hangar.sh
_load combat_common.sh
_load missions.sh
_load battle.sh
_load pvp.sh
_load pve.sh
_load cw.sh
_load dm.sh
_load convoy.sh
_load buildings.sh
_load company.sh
_load assault.sh
_load run.sh

export SRC="$TMP/SRC"

clear
bot_slogan
load_config

if ! login_func; then
  echo "ERRO: login falhou"
  exit 1
fi

go_hangar

while true; do
  check_session_alive
  wartank_play
  sleep 1
done
