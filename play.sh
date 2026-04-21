#!/bin/bash
# play.sh — Single conta, arranque simples
# Para multi-contas: usar play_multi.sh (quando o bot estiver estavel)

BOT_DIR="$(cd "$(dirname "$0")" && pwd)"
MAIN="$BOT_DIR/wartank.sh"

chmod +x "$BOT_DIR"/*.sh 2>/dev/null
termux-wake-lock 2>/dev/null

# Verifica se wartank.sh existe
if [ ! -f "$MAIN" ]; then
  echo "ERRO: wartank.sh nao encontrado em $BOT_DIR"
  exit 1
fi

echo ""
echo "  Wartank Bot v1.3.0"
echo "  Pasta: $BOT_DIR"
echo ""

# Loop com restart automatico
while true; do
  bash "$MAIN"
  code=$?

  # Saida intencional
  if [ "$code" -eq 0 ]; then
    echo ""
    echo "  Bot parado."
    break
  fi

  echo ""
  echo "  Bot encerrou (cod $code). A reiniciar em 10s..."
  echo "  Ctrl+C para cancelar."
  sleep 10
done
