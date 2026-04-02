#!/bin/sh
# play.sh — arranque com auto-restart v1.2.0

BOT_DIR="$(cd "$(dirname "$0")" && pwd)"
MAIN="$BOT_DIR/wartank.sh"
[ -f "$MAIN" ] || { echo "ERRO: wartank.sh nao encontrado em $BOT_DIR"; exit 1; }
chmod +x "$MAIN"

graceful_kill() {
  local pid="$1" w=0
  kill -TERM "$pid" 2>/dev/null
  while [ "$w" -lt 15 ]; do
    kill -0 "$pid" 2>/dev/null || return 0
    sleep 1; w=$(( w + 1 ))
  done
  kill -KILL "$pid" 2>/dev/null
}

while true; do
  old=$(ps ax -o pid=,args= 2>/dev/null \
    | grep "wartank.sh" | grep -v grep \
    | head -n1 | grep -o -E '^[[:space:]]*[0-9]+' | tr -d ' ')
  [ -n "$old" ] && { echo "a encerrar pid $old..."; graceful_kill "$old"; sleep 2s; }

  "$MAIN"
  code=$?
  [ "$code" -eq 0 ] && { echo "bot parado pelo utilizador"; break; }
  echo "bot terminou (cod $code), a reiniciar em 5s..."
  sleep 5s
done
