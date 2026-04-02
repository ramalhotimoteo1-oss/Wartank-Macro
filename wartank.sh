#!/bin/bash
# wartank.sh — engine principal v1.2.0
# shellcheck disable=SC1091

BOT_DIR="$(cd "$(dirname "$0")" && pwd)"
export BOT_DIR TMP="$BOT_DIR/.tmp" URL="https://wartank-pt.net"
export LOG_FILE="$TMP/bot.log"
export USER_AGENT="Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36"

mkdir -p "$TMP"
exec 2>>"$TMP/bot.log"

# verifica dependencias
for cmd in bash curl grep sed awk base64; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "ERRO: falta $cmd"; exit 1; }
done

# carrega modulos — core DEVE ser primeiro
_load() {
  [ -f "$BOT_DIR/$1" ] && . "$BOT_DIR/$1" || { echo "ERRO: $1 nao encontrado"; exit 1; }
}

_load core.sh
_load config.sh
_load login.sh
_load hangar.sh
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
  sleep 1s
done
