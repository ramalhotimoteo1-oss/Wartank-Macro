#!/bin/bash
# ============================================================
# info.sh — Cores, utilitários, fetch com jsessionid
# ============================================================

colors() {
  BLACK_CYAN='\033[01;36m\033[01;07m'
  BLACK_GREEN='\033[00;32m\033[01;07m'
  BLACK_RED='\033[01;31m\033[01;07m'
  BLACK_YELLOW='\033[00;33m\033[01;07m'
  GOLD_BLACK='\033[0;33m'
  GREEN_BLACK='\033[32m'
  GREENb_BLACK='\033[1;32m'
  RED_BLACK='\033[0;31m'
  GRAY_BLACK='\033[02;37m'
  BLUE_BLACK='\033[0;34m'
  WHITE_BLACK='\033[37m'
  COLOR_RESET='\033[00m'
}

echo_t() {
  local text="$1"
  local color_start="${2:-}"
  local color_end="${3:-$COLOR_RESET}"
  local position="${4:-after}"
  local emoji="${5:-}"
  if [ "$position" = "before" ]; then
    echo -e "${color_start}${emoji} ${text}${color_end}"
  else
    echo -e "${color_start}${text} ${emoji}${color_end}"
  fi
}

time_exit() {
  local timeout="$1"
  local pid="$!"
  for ((i=timeout; i>0; i--)); do
    sleep 1s
    kill -0 "$pid" 2>/dev/null || return 0
  done
  kill -PIPE "$pid" 2>/dev/null
  kill -15 "$pid" 2>/dev/null
}

# ── Extrai jsessionid da última página ──────────────────────
_update_jsessionid() {
  local new_sid
  # Apanha jsessionid de qualquer href na página
  new_sid=$(grep -o -E 'jsessionid=[A-Z0-9]+' "$TMP/SRC" | head -n1 | sed 's/jsessionid=//')
  if [ -n "$new_sid" ]; then
    JSESSIONID="$new_sid"
  fi
}

# ── Fetch com jsessionid sempre na URL ──────────────────────
# O wartank-pt.net usa jsessionid na URL, não só em cookies
# Sem o jsessionid na URL → sessão perdida → redireciona para login
fetch_page() {
  local path="$1"
  local output="${2:-$TMP/SRC}"

  # Constrói URL com jsessionid se disponível
  local full_url
  if [ -n "$JSESSIONID" ]; then
    # Remove jsessionid anterior se já estiver no path
    path=$(echo "$path" | sed 's/;jsessionid=[A-Z0-9]*//')
    # Adiciona antes do ? se existir, ou no fim
    if echo "$path" | grep -q '\?'; then
      # Ex: /pvp?12-1.ILink... → /pvp;jsessionid=XXX?12-1.ILink...
      full_url="${URL}/$(echo "$path" | sed "s|\?|;jsessionid=${JSESSIONID}?|")"
    else
      full_url="${URL}/${path};jsessionid=${JSESSIONID}"
    fi
  else
    full_url="${URL}/${path}"
  fi

  # Remove duplo //
  full_url=$(echo "$full_url" | sed 's|//\([^/]\)|/\1|g; s|https:/|https://|')

  curl -s -L \
    -c "$TMP/cookies.txt" \
    -b "$TMP/cookies.txt" \
    -A "$USER_AGENT" \
    -o "$output" \
    "$full_url" \
    2>/dev/null

  # Actualiza jsessionid com o da nova página
  _update_jsessionid

  sleep 0.3s
}

# ── Verifica se sessão está activa ───────────────────────────
_session_active() {
  # user=0;level=0 → não autenticado
  if grep -q 'user=0;level=0' "$TMP/SRC" 2>/dev/null; then
    return 1
  fi
  # Página de login → não autenticado
  if grep -q 'IFormSubmitListener-loginForm\|showSigninLink' "$TMP/SRC" 2>/dev/null; then
    return 1
  fi
  return 0
}

bot_slogan() {
  colors
  echo -e "${GOLD_BLACK}"
  echo "  ██╗    ██╗ █████╗ ██████╗ ████████╗ █████╗ ███╗   ██╗██╗  ██╗"
  echo "  ██║    ██║██╔══██╗██╔══██╗╚══██╔══╝██╔══██╗████╗  ██║██║ ██╔╝"
  echo "  ██║ █╗ ██║███████║██████╔╝   ██║   ███████║██╔██╗ ██║█████╔╝ "
  echo "  ██║███╗██║██╔══██║██╔══██╗   ██║   ██╔══██║██║╚██╗██║██╔═██╗ "
  echo "  ╚███╔███╔╝██║  ██║██║  ██║   ██║   ██║  ██║██║ ╚████║██║  ██╗"
  echo "   ╚══╝╚══╝ ╚═╝  ╚═╝╚═╝  ╚═╝   ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═══╝╚═╝  ╚═╝"
  echo -  e "${COLOR_RESET}"
echo -e "${GREEN_BLACK}  wartank-pt.net Bot — v1.0.0${COLOR_RESET}"
echo -e "${GREEN_BLACK}  criador: Omega Prime${COLOR_RESET}"
  echo -e "${GRAY_BLACK}  Modular | Automático | Inteligente${COLOR_RESET}\n"
  sleep 1s
}
