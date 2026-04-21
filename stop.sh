#!/bin/sh
# stop.sh — Para todos os workers

STATUS_DIR="$HOME/.wartank/status"
GREEN='\033[32m'; GOLD='\033[0;33m'; RESET='\033[00m'

printf "${GOLD}A parar workers...${RESET}\n\n"
stopped=0

for pid_file in "$STATUS_DIR"/*.pid; do
  [ -f "$pid_file" ] || continue
  acc=$(basename "$pid_file" .pid)
  pid=$(cat "$pid_file")
  if kill -0 "$pid" 2>/dev/null; then
    kill -15 "$pid" 2>/dev/null; sleep 1
    kill -0 "$pid" 2>/dev/null && kill -9 "$pid" 2>/dev/null
    echo "stopped" > "$STATUS_DIR/${acc}.status"
    printf "  ${GREEN}[OK]${RESET} %s (PID %s)\n" "$acc" "$pid"
    stopped=$((stopped+1))
  fi
  rm -f "$pid_file"
done

pkill -f "wartank.sh" 2>/dev/null
printf "\n${GREEN}%s worker(s) parado(s).${RESET}\n" "$stopped"
