#!/bin/bash
# wartank.sh — Engine principal v1.3.1
# shellcheck disable=SC1091

BOT_DIR="$(cd "$(dirname "$0")" && pwd)"
export BOT_DIR
export TMP="${TMP:-$BOT_DIR/.tmp}"
export URL="${URL:-https://wartank-pt.net}"
export LOG_FILE="${LOG_FILE:-$TMP/bot.log}"
export USER_AGENT="Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36"

mkdir -p "$TMP"

# Stderr para log E para ecra durante debug
# Assim nao perde erros silenciosos
exec 2> >(tee -a "$LOG_FILE" >&2)

# Verificacao de dependencias
for cmd in bash curl grep sed awk base64; do
  command -v "$cmd" >/dev/null 2>&1 || {
    echo "ERRO FATAL: '$cmd' nao encontrado. Instala com: pkg install $cmd"
    exit 1
  }
done

# Carrega modulos com verificacao
_load() {
  local f="$BOT_DIR/$1"
  if [ ! -f "$f" ]; then
    echo "ERRO FATAL: modulo '$1' nao encontrado em $BOT_DIR"
    exit 1
  fi
  # shellcheck source=/dev/null
  . "$f" || {
    echo "ERRO FATAL: falha ao carregar '$1'"
    exit 1
  }
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

# Login — se falhar, sai com codigo 1 (play.sh vai reiniciar)
if ! login_func; then
  echo "ERRO: login falhou — a sair"
  exit 1
fi

go_hangar

# Loop principal
while true; do
  check_session_alive
  wartank_play
  sleep 1
done
