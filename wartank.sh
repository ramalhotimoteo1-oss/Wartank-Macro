#!/bin/bash
# ============================================================
# wartank.sh — Engine principal do bot
# Wartank-PT Bot v1.0.0
# ============================================================
# shellcheck disable=SC1091

# ── Configuração base ───────────────────────────────────────
BOT_DIR="$HOME/wartank-bot"
TMP="$BOT_DIR/.tmp"
URL="https://wartank-pt.net"
USER_AGENT="Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36"

mkdir -p "$TMP"

# ── Carrega módulos ─────────────────────────────────────────
cd "$BOT_DIR" || exit 1

. info.sh
. config.sh
. login.sh
. hangar.sh
. battle.sh
. pvp.sh
. missions.sh
. pve.sh
. cw.sh
. dm.sh
. convoy.sh
. assault.sh
. company.sh
. buildings.sh
. dm.sh
. run.sh

# ── Inicialização ───────────────────────────────────────────
colors
clear
bot_slogan
sleep 1s

load_config

# ── Login ───────────────────────────────────────────────────
if ! login_func; then
  echo_t "Falha no login. A terminar." "$BLACK_RED" "$COLOR_RESET" "after" "❌"
  exit 1
fi

# ── Hangar — ponto de partida ────────────────────────────────
go_hangar

# ── Loop principal infinito ─────────────────────────────────
echo_t "Bot iniciado. Loop principal a correr..." "$GREEN_BLACK" "$COLOR_RESET" "after" "🚀"
echo_t "  [stop/exit/q] para parar  |  [config] para configurar  |  [status] para estado" "$GRAY_BLACK" "$COLOR_RESET"

while true; do
  # Verifica sessão periodicamente
  check_session_alive

  # Executa acções com base no horário
  wartank_play

  sleep 1s
done
