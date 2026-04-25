#!/bin/bash
# core.sh — funcoes base v1.2.1

BOT_DIR="${BOT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
TMP="${TMP:-$BOT_DIR/.tmp}"
SRC="$TMP/SRC"
URL="${URL:-https://wartank-pt.net}"
COOKIE_FILE="$TMP/cookies.txt"
CRIPT_FILE="$TMP/cript_file"
LOG_FILE="${LOG_FILE:-$TMP/bot.log}"
USER_AGENT="${USER_AGENT:-Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36}"
JSESSIONID=""
ACC=""
FUEL_CURRENT=""
PLAYER_LEVEL=""
PLAYER_ID=""
_LOGIN_FAILURES=0

mkdir -p "$TMP"

colors() {
  GOLD_BLACK='\033[0;33m'
  GREEN_BLACK='\033[32m'
  RED_BLACK='\033[0;31m'
  GRAY_BLACK='\033[02;37m'
  BLACK_YELLOW='\033[00;33m\033[01;07m'
  BLACK_RED='\033[01;31m\033[01;07m'
  BLACK_CYAN='\033[01;36m\033[01;07m'
  BLUE_BLACK='\033[0;34m'
  COLOR_RESET='\033[00m'
}
colors

log() {
  local ts
  printf -v ts '%(%Y-%m-%d %H:%M:%S)T' -1
  echo "[$ts] [${2:-INFO}] $1" >> "$LOG_FILE"
}
log_warn()  { log "$1" "WARN";  echo "[AVISO] $1"; }
log_error() { log "$1" "ERROR"; echo "[ERRO] $1"; }
log_ok()    { log "$1" "OK";    echo "[OK] $1"; }

echo_t() {
  local text="$1"
  local color_start="${2:-}"
  local color_end="${3:-$COLOR_RESET}"
  echo -e "${color_start}${text}${color_end}"
}

sleep_rand() {
  local min="${1:-300}" max="${2:-1200}" delay
  delay=$(awk -v min="$min" -v max="$max" \
    'BEGIN { srand(); printf "%.3f", (min + rand()*(max-min))/1000 }')
  sleep "${delay}s"
}

# Credenciais em base64 + chmod 600
# AES removido: pedia password interactiva no Termux
_encrypt_creds() {
  local data="$1" out="$2"
  printf '%s' "$data" | base64 -w 0 > "$out"
  chmod 600 "$out"
}

_decrypt_creds() {
  local file="$1"
  [ -f "$file" ] || return 1
  base64 -d "$file" 2>/dev/null
}

_update_jsessionid() {
  local s
  s=$(grep -o -E 'jsessionid=[A-Z0-9]+' "$SRC" 2>/dev/null | head -n1 | sed 's/jsessionid=//')
  [ -n "$s" ] && JSESSIONID="$s"
}

fetch_page() {
  local path="$1"
  local output="${2:-$SRC}"
  local full_url

  path=$(echo "$path" | sed 's/;jsessionid=[A-Z0-9]*//')

  if [ -n "$JSESSIONID" ]; then
    if echo "$path" | grep -q '?'; then
      full_url="${URL}/$(echo "$path" | sed "s|?|;jsessionid=${JSESSIONID}?|")"
    else
      full_url="${URL}/${path};jsessionid=${JSESSIONID}"
    fi
  else
    full_url="${URL}/${path}"
  fi

  full_url=$(echo "$full_url" | sed 's|https://||;s|//|/|g;s|^|https://|')

  local cacert=""
  for ca in \
    /data/data/com.termux/files/usr/etc/tls/cert.pem \
    /etc/ssl/certs/ca-certificates.crt \
    /etc/pki/tls/certs/ca-bundle.crt; do
    [ -f "$ca" ] && { cacert="--cacert $ca"; break; }
  done

  # shellcheck disable=SC2086
  curl -s -L \
    -c "$COOKIE_FILE" \
    -b "$COOKIE_FILE" \
    -A "$USER_AGENT" \
    --max-time 20 \
    --retry 2 \
    --retry-delay 3 \
    $cacert \
    -o "$output" \
    "$full_url" \
    2>>"$LOG_FILE"

  [ ! -s "$output" ] && log "fetch vazio: $path" "WARN"
  _update_jsessionid
  sleep_rand 300 700
}

# fetch_page_fast — sem delay extra, para usar em loops de combate
# O timing e controlado pelo proprio loop (BATTLE_LA, reload, etc.)
fetch_page_fast() {
  local path="$1"
  local output="${2:-$SRC}"
  local full_url

  path=$(echo "$path" | sed 's/;jsessionid=[A-Z0-9]*//')

  if [ -n "$JSESSIONID" ]; then
    if echo "$path" | grep -q '?'; then
      full_url="${URL}/$(echo "$path" | sed "s|?|;jsessionid=${JSESSIONID}?|")"
    else
      full_url="${URL}/${path};jsessionid=${JSESSIONID}"
    fi
  else
    full_url="${URL}/${path}"
  fi

  full_url=$(echo "$full_url" | sed 's|https://||;s|//|/|g;s|^|https://|')

  local cacert=""
  for ca in \
    /data/data/com.termux/files/usr/etc/tls/cert.pem \
    /etc/ssl/certs/ca-certificates.crt \
    /etc/pki/tls/certs/ca-bundle.crt; do
    [ -f "$ca" ] && { cacert="--cacert $ca"; break; }
  done

  # shellcheck disable=SC2086
  curl -s -L \
    -c "$COOKIE_FILE" \
    -b "$COOKIE_FILE" \
    -A "$USER_AGENT" \
    --max-time 20 \
    --retry 1 \
    $cacert \
    -o "$output" \
    "$full_url" \
    2>>"$LOG_FILE"

  [ ! -s "$output" ] && log "fetch_fast vazio: $path" "WARN"
  _update_jsessionid
  # SEM sleep_rand — timing controlado pelo loop de combate
}

_session_active() {
  local f="${1:-$SRC}"
  grep -q 'user=0;level=0' "$f" 2>/dev/null && return 1
  grep -q 'IFormSubmitListener-loginForm\|showSigninLink' "$f" 2>/dev/null && return 1
  return 0
}

require_login() {
  _session_active && { _LOGIN_FAILURES=0; return 0; }
  _LOGIN_FAILURES=$(( _LOGIN_FAILURES + 1 ))
  log "falha login tentativa ${_LOGIN_FAILURES}/3" "WARN"
  [ "$_LOGIN_FAILURES" -ge 3 ] && { log_error "3 falhas login. A parar."; exit 1; }
  [ -f "$CRIPT_FILE" ] && { JSESSIONID=""; _do_login; sleep_rand 1000 2000; }
  fetch_page "/angar"
  _session_active && { _LOGIN_FAILURES=0; return 0; }
  return 1
}

check_session_alive() {
  fetch_page "/angar"
  _session_active || require_login
}

ensure_hangar() {
  grep -q '<title>Hangar</title>' "$SRC" 2>/dev/null && return 0
  fetch_page "/angar"
  _session_active || { require_login; fetch_page "/angar"; }
  grep -q '<title>Hangar</title>' "$SRC" 2>/dev/null
}

check_fuel() {
  local min="${1:-${FUEL_MIN:-0}}"
  [ -z "$FUEL_CURRENT" ] && \
    FUEL_CURRENT=$(grep -o -E 'fuel\.png[^/]*/>[^0-9]*[0-9]+' "$SRC" 2>/dev/null \
      | grep -o -E '[0-9]+$' | head -n1)
  [ -z "$FUEL_CURRENT" ] && return 0
  [ "$FUEL_CURRENT" -le "$min" ] 2>/dev/null && return 1
  return 0
}

time_exit() {
  local t="$1" pid="$!" i
  for ((i=t; i>0; i--)); do
    sleep 1s
    kill -0 "$pid" 2>/dev/null || return 0
  done
  kill -PIPE "$pid" 2>/dev/null
  kill -15   "$pid" 2>/dev/null
}

bot_slogan() {
  echo ""
  echo "  wartank-pt.net Bot v1.2.1"
  echo "  [stop] parar | [config] configurar | [status] estado"
  echo ""
  log "Bot iniciado v1.2.1"
}
