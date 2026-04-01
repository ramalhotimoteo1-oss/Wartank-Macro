#!/bin/bash
# ============================================================
# core.sh — Funções essenciais centralizadas
# Wartank-PT Bot
# ============================================================
# Carregado pelo wartank.sh ANTES de todos os outros módulos.
# Fornece:
#   - Variáveis globais (TMP, SRC, URL, COOKIE_FILE, etc.)
#   - fetch_page com jsessionid automático
#   - _session_active / _update_jsessionid
#   - echo_t (log com cor e emoji)
#   - sleep_rand (delay humano anti-ban)
#   - require_login (garante sessão activa)
#   - ensure_hangar (garante que está no hangar)
#   - check_fuel (verifica combustível global)
#   - Reconexão automática quando sessão expira
# ============================================================

# ── Variáveis globais ────────────────────────────────────────
BOT_DIR="${BOT_DIR:-$HOME/wartank-bot}"
TMP="${TMP:-$BOT_DIR/.tmp}"
SRC="$TMP/SRC"           # Ficheiro de saída padrão do fetch_page
URL="${URL:-https://wartank-pt.net}"
COOKIE_FILE="$TMP/cookies.txt"
CRIPT_FILE="$TMP/cript_file"

# User-Agent — simula Chrome Android (igual ao browser real)
USER_AGENT="${USER_AGENT:-Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36}"

# Variáveis de estado da sessão
JSESSIONID=""
ACC=""
FUEL_CURRENT=""
GOLD=""
SILVER=""
PLAYER_LEVEL=""
PLAYER_ID=""

# Garante que o directório tmp existe
mkdir -p "$TMP"

# ── Cores ANSI ───────────────────────────────────────────────
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
colors  # Carrega imediatamente ao fazer source

# ── echo_t — log com cor e emoji ────────────────────────────
# Uso: echo_t "texto" "$COR" "$RESET" "before|after" "emoji"
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

# ── sleep_rand — delay humano (anti-ban) ────────────────────
# Uso: sleep_rand [min_ms] [max_ms]
# Default: entre 300ms e 1200ms
sleep_rand() {
  local min="${1:-300}"
  local max="${2:-1200}"
  # Gera número aleatório entre min e max
  local delay
  delay=$(awk -v min="$min" -v max="$max" \
    'BEGIN { srand(); printf "%.3f", (min + rand()*(max-min))/1000 }')
  sleep "${delay}s"
}

# ── _update_jsessionid — extrai jsessionid da página ────────
_update_jsessionid() {
  local new_sid
  new_sid=$(grep -o -E 'jsessionid=[A-Z0-9]+' "$SRC" 2>/dev/null \
    | head -n1 | sed 's/jsessionid=//')
  if [ -n "$new_sid" ]; then
    JSESSIONID="$new_sid"
  fi
}

# ── fetch_page — curl com cookies + jsessionid na URL ───────
# O wartank-pt.net requer jsessionid TANTO nos cookies
# COMO na URL — sem isso a sessão é perdida.
#
# Uso: fetch_page "/rota" [ficheiro_saida]
# Uso: fetch_page "/rota?X-X.ILink..." [ficheiro_saida]
fetch_page() {
  local path="$1"
  local output="${2:-$SRC}"
  local full_url

  # Remove jsessionid anterior no path (evita duplicação)
  path=$(echo "$path" | sed 's/;jsessionid=[A-Z0-9]*//')

  # Constrói URL com jsessionid
  if [ -n "$JSESSIONID" ]; then
    if echo "$path" | grep -q '?'; then
      # /rota?X.ILink... → /rota;jsessionid=XXX?X.ILink...
      full_url="${URL}/$(echo "$path" | sed "s|?|;jsessionid=${JSESSIONID}?|")"
    else
      # /rota → /rota;jsessionid=XXX
      full_url="${URL}/${path};jsessionid=${JSESSIONID}"
    fi
  else
    full_url="${URL}/${path}"
  fi

  # Normaliza URL (remove // acidentais)
  full_url=$(echo "$full_url" \
    | sed 's|https://||' \
    | sed 's|//|/|g' \
    | sed 's|^|https://|')

  curl -s -L \
    -c "$COOKIE_FILE" \
    -b "$COOKIE_FILE" \
    -A "$USER_AGENT" \
    --max-time 20 \
    --retry 2 \
    --retry-delay 3 \
    -o "$output" \
    "$full_url" \
    2>/dev/null

  # Actualiza jsessionid com o novo valor da resposta
  _update_jsessionid

  # Delay humano entre requests
  sleep_rand 300 800
}

# ── _session_active — verifica se está autenticado ──────────
_session_active() {
  local file="${1:-$SRC}"
  # user=0;level=0 → não autenticado
  if grep -q 'user=0;level=0' "$file" 2>/dev/null; then
    return 1
  fi
  # Página de login
  if grep -q 'IFormSubmitListener-loginForm\|showSigninLink' "$file" 2>/dev/null; then
    return 1
  fi
  return 0
}

# ── require_login — garante sessão activa ───────────────────
# Chama _do_login se necessário. Para o bot se falhar 3x.
_LOGIN_FAILURES=0
require_login() {
  if _session_active; then
    _LOGIN_FAILURES=0
    return 0
  fi

  echo_t "Sessão inválida. A reconectar..." "$BLACK_YELLOW" "$COLOR_RESET" "after" "🔄"
  _LOGIN_FAILURES=$(( _LOGIN_FAILURES + 1 ))

  if [ "$_LOGIN_FAILURES" -ge 3 ]; then
    echo_t "3 falhas de login consecutivas. A parar." "$BLACK_RED" "$COLOR_RESET" "after" "🛑"
    exit 1
  fi

  # Tenta re-login com credenciais guardadas
  if [ -f "$CRIPT_FILE" ]; then
    JSESSIONID=""  # Força nova sessão
    _do_login 2>/dev/null
    sleep_rand 1000 2000

    fetch_page "/angar"
    if _session_active; then
      echo_t "Sessão restaurada!" "$GREEN_BLACK" "$COLOR_RESET" "after" "✅"
      _LOGIN_FAILURES=0
      return 0
    fi
  fi

  echo_t "Não foi possível restaurar sessão (tentativa ${_LOGIN_FAILURES}/3)." \
    "$BLACK_RED" "$COLOR_RESET"
  return 1
}

# ── check_session_alive — verificação periódica ─────────────
# Chamado no loop principal do wartank.sh
check_session_alive() {
  fetch_page "/angar"
  if ! _session_active; then
    require_login
  fi
}

# ── ensure_hangar — garante que está no hangar ──────────────
# Uso: ensure_hangar || return  (em qualquer módulo)
ensure_hangar() {
  # Se já está no hangar, não faz nada
  if grep -q '<title>Hangar</title>' "$SRC" 2>/dev/null; then
    return 0
  fi

  echo_t "A regressar ao hangar..." "$GRAY_BLACK" "$COLOR_RESET" "after" "🏠"
  fetch_page "/angar"

  if ! _session_active; then
    require_login
    fetch_page "/angar"
  fi

  if grep -q '<title>Hangar</title>' "$SRC" 2>/dev/null; then
    return 0
  fi

  echo_t "Não foi possível aceder ao hangar." "$BLACK_RED" "$COLOR_RESET" "after" "❌"
  return 1
}

# ── check_fuel — verifica combustível global ────────────────
# Uso: check_fuel [minimo]
# Retorna 0 se tem combustível, 1 se não tem
check_fuel() {
  local min="${1:-${FUEL_MIN:-0}}"

  # Lê combustível da página actual se não estiver em cache
  if [ -z "$FUEL_CURRENT" ]; then
    FUEL_CURRENT=$(grep -o -E 'fuel\.png[^/]*/>[^0-9]*[0-9]+' "$SRC" 2>/dev/null \
      | grep -o -E '[0-9]+$' | head -n1)
  fi

  # Se não conseguiu ler, vai ao hangar buscar
  if [ -z "$FUEL_CURRENT" ]; then
    fetch_page "/angar"
    FUEL_CURRENT=$(grep -o -E 'fuel\.png[^/]*/>[^0-9]*[0-9]+' "$SRC" 2>/dev/null \
      | grep -o -E '[0-9]+$' | head -n1)
  fi

  # Se ainda vazio, assume que tem (falha silenciosa)
  [ -z "$FUEL_CURRENT" ] && return 0

  if [ "$FUEL_CURRENT" -le "$min" ] 2>/dev/null; then
    echo_t "⛽ Combustível insuficiente: ${FUEL_CURRENT} (mín: ${min})" \
      "$BLACK_YELLOW" "$COLOR_RESET"
    return 1
  fi
  return 0
}

# ── time_exit — mata processo em background após timeout ────
time_exit() {
  local timeout="$1"
  local pid="$!"
  local i
  for ((i=timeout; i>0; i--)); do
    sleep 1s
    kill -0 "$pid" 2>/dev/null || return 0
  done
  kill -PIPE "$pid" 2>/dev/null
  kill -15 "$pid" 2>/dev/null
}

# ── log — log com timestamp para ficheiro ───────────────────
LOG_FILE="${LOG_FILE:-$TMP/bot.log}"
log() {
  local msg="$1"
  local ts
  printf -v ts '%(%Y-%m-%d %H:%M:%S)T' -1
  echo "[$ts] $msg" >> "$LOG_FILE"
}

# ── bot_slogan — apresentação ────────────────────────────────
bot_slogan() {
  echo -e "${GOLD_BLACK}"
  echo "  ██╗    ██╗ █████╗ ██████╗ ████████╗ █████╗ ███╗   ██╗██╗  ██╗"
  echo "  ██║    ██║██╔══██╗██╔══██╗╚══██╔══╝██╔══██╗████╗  ██║██║ ██╔╝"
  echo "  ██║ █╗ ██║███████║██████╔╝   ██║   ███████║██╔██╗ ██║█████╔╝ "
  echo "  ██║███╗██║██╔══██║██╔══██╗   ██║   ██╔══██║██║╚██╗██║██╔═██╗ "
  echo "  ╚███╔███╔╝██║  ██║██║  ██║   ██║   ██║  ██║██║ ╚████║██║  ██╗"
  echo "   ╚══╝╚══╝ ╚═╝  ╚═╝╚═╝  ╚═╝   ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═══╝╚═╝  ╚═╝"
  echo -e "${COLOR_RESET}"
  echo -e "${GREEN_BLACK}  wartank-pt.net Bot — v1.1.0${COLOR_RESET}"
  echo -e "${GRAY_BLACK}  Modular | Automático | Inteligente${COLOR_RESET}\n"
}
