#!/bin/bash
# ============================================================
# login.sh — Login v1.2.0
# Usa _encrypt_creds/_decrypt_creds do core.sh (AES-256 ou base64)
# ============================================================

COOKIE_FILE="$TMP/cookies.txt"
ACC_FILE="$TMP/acc_file"

login_func() {
  if [ -f "$CRIPT_FILE" ]; then
    echo_t "A restaurar sessão anterior..." "$GRAY_BLACK" "$COLOR_RESET"
    _do_login
    if _check_session; then return 0; fi
    echo_t "Sessão expirada. Novo login necessário." "$BLACK_YELLOW" "$COLOR_RESET"
  fi

  _login_prompt

  if ! _check_session; then
    log_error "Login falhou. Verifica as credenciais."
    rm -f "$CRIPT_FILE"
    return 1
  fi

  log_ok "Login bem-sucedido! Conta: ${ACC}"
  return 0
}

_login_prompt() {
  clear
  echo_t "🔐 Login — wartank-pt.net" "$BLACK_CYAN" "$COLOR_RESET"
  echo ""
  echo_t "Username: " "$GOLD_BLACK" "$COLOR_RESET"
  read -r username

  local password="" charcount=0 prompt
  prompt="${GOLD_BLACK}Password: ${COLOR_RESET}"
  while IFS= read -p "$prompt" -r -s -n 1 char; do
    if [ "$char" = $'\0' ] || [ "$char" = $'\400' ]; then break; fi
    if [ "$char" = $'\177' ] || [ "$char" = $'\577' ]; then
      if [ "$charcount" -gt 0 ]; then
        charcount=$(( charcount - 1 ))
        prompt=$'\b \b'
        password="${password%?}"
      else
        prompt=""
      fi
    else
      charcount=$(( charcount + 1 ))
      prompt="*"
      password="${password}${char}"
    fi
  done
  echo ""

  # Encripta com AES-256 ou base64 (via core.sh)
  _encrypt_creds "login=${username}&password=${password}" "$CRIPT_FILE"
  unset username password
  _do_login
}

_do_login() {
  # Passo 1: GET página inicial — link "Já joguei"
  curl -s -L \
    -c "$COOKIE_FILE" \
    -b "$COOKIE_FILE" \
    -A "$USER_AGENT" \
    --max-time 20 \
    -o "$SRC" \
    "${URL}/" 2>>"$LOG_FILE"
  sleep_rand 400 800

  local signin_link
  signin_link=$(grep -o -E '\?[0-9]+-[0-9]+\.ILinkListener-showSigninLink' "$SRC" | head -n1)
  [ -z "$signin_link" ] && signin_link="?0-1.ILinkListener-showSigninLink"

  # Passo 2: GET página de login — form action
  curl -s -L \
    -c "$COOKIE_FILE" \
    -b "$COOKIE_FILE" \
    -A "$USER_AGENT" \
    --max-time 20 \
    -o "$SRC" \
    "${URL}/${signin_link}" 2>>"$LOG_FILE"
  sleep_rand 400 800

  local form_action
  form_action=$(grep -o -E '\?[0-9]+-[0-9]+\.IFormSubmitListener-loginForm' "$SRC" | head -n1)
  [ -z "$form_action" ] && form_action="?1-2.IFormSubmitListener-loginForm"
  echo_t "  Form: ${form_action}" "$GRAY_BLACK" "$COLOR_RESET"

  # Passo 3: Desencripta credenciais (AES ou base64)
  local creds user pass
  creds=$(_decrypt_creds "$CRIPT_FILE")
  user=$(echo "$creds" | sed 's/login=\([^&]*\).*/\1/')
  pass=$(echo "$creds" | sed 's/.*password=\(.*\)/\1/')
  unset creds

  # Passo 4: POST login
  # Campos confirmados no HTML real: login, password, id1_hf_0
  curl -s -L \
    -c "$COOKIE_FILE" \
    -b "$COOKIE_FILE" \
    -A "$USER_AGENT" \
    --max-time 20 \
    -X POST \
    --data-urlencode "login=${user}" \
    --data-urlencode "password=${pass}" \
    --data-urlencode "id1_hf_0=" \
    -o "$SRC" \
    "${URL}/${form_action}" 2>>"$LOG_FILE"

  unset user pass
  sleep_rand 800 1500
  _update_jsessionid
}

_check_session() {
  # Vai ao hangar verificar se está autenticado
  curl -s -L \
    -c "$COOKIE_FILE" \
    -b "$COOKIE_FILE" \
    -A "$USER_AGENT" \
    --max-time 20 \
    -o "$ACC_FILE" \
    "${URL}/angar;jsessionid=${JSESSIONID}" 2>>"$LOG_FILE"

  # Página de login → falhou
  if grep -q 'showSigninLink\|IFormSubmitListener-loginForm' "$ACC_FILE" 2>/dev/null; then
    return 1
  fi

  # Confirma pelo título real do hangar
  if grep -q '<title>Hangar</title>' "$ACC_FILE" 2>/dev/null; then
    PLAYER_ID=$(grep -o -E 'user=[0-9]+' "$ACC_FILE" | grep -o -E '[0-9]+' | head -n1)
    PLAYER_LEVEL=$(grep -o -E 'level=[0-9]+' "$ACC_FILE" | grep -o -E '[0-9]+' | head -n1)
    FUEL_CURRENT=$(grep -A1 'title="Combustível"' "$ACC_FILE" \
      | grep -o -E '[0-9]+' | head -n1)
    [ -z "$ACC" ] && ACC="Jogador#${PLAYER_ID:-?}"
    echo_t "✅ Hangar | ID:${PLAYER_ID:-?} Nível:${PLAYER_LEVEL:-?} ⛽${FUEL_CURRENT:-?}" \
      "$GOLD_BLACK" "$COLOR_RESET"
    cp "$ACC_FILE" "$SRC"
    _update_jsessionid
    return 0
  fi

  return 1
}

check_session_alive() {
  fetch_page "/angar"
  if ! _session_active; then
    log_warn "Sessão expirou. A reconectar..."
    _do_login
    _check_session
  fi
}
