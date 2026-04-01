#!/bin/sh
# ============================================================
# play.sh — Arranque com auto-restart
# ============================================================
BOT_DIR="$HOME/wartank-bot"

while true; do
  # Mata instâncias anteriores
  pidf=$(ps ax -o pid=,args= 2>/dev/null \
    | grep "wartank-bot/wartank.sh" \
    | grep -v grep \
    | head -n1 \
    | grep -o -E '[0-9]{3,6}' | head -n1)
  while [ -n "$pidf" ]; do
    kill -9 "$pidf" 2>/dev/null
    sleep 1s
    pidf=$(ps ax -o pid=,args= 2>/dev/null \
      | grep "wartank-bot/wartank.sh" \
      | grep -v grep \
      | head -n1 \
      | grep -o -E '[0-9]{3,6}' | head -n1)
  done

  chmod +x "$BOT_DIR/wartank.sh"
  "$BOT_DIR/wartank.sh"

  exit_code=$?
  if [ "$exit_code" -eq 0 ]; then
    echo "Bot parado pelo utilizador."
    break
  fi

  echo "Bot terminou (código $exit_code). A reiniciar em 5s..."
  sleep 5s
done
