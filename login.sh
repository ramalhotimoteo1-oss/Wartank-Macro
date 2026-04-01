#!/bin/bash
# ============================================================
# login.sh — Login real para wartank-pt.net
# Campos confirmados: login, password, id1_hf_0 (hidden)
# ============================================================

CRIPT_FILE="$TMP/cript_file"
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
    echo_t "Login falhou. Verifica as credenciais." "$BLACK_RED" "$COLOR_RESET" "after" "❌"
    rm -f "$CRIPT_FILE"
    return 1
  fi

  echo_t "Login bem-sucedido!" "$GREEN_BLACK" "$COLOR_RESET" "after" "✅"
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

  printf '%s' "login=${username}&password=${password}" | base64 -w 0 > "$CRIPT_FILE"
  chmod 600 "$CRIPT_FILE"
  unset username password
  _do_login
}

_do_login() {
  # Passo 1: GET página inicial — obtém link "Já joguei" com número Wicket
  curl -s -L \
    -c "$COOKIE_FILE" \
    -b "$COOKIE_FILE" \
    -A "$USER_AGENT" \
    "${URL}/" \
    -o "$TMP/SRC" 2>/dev/null
  sleep 0.5s

  # Ex: href="?1-1.ILinkListener-showSigninLink"
  local signin_link
  signin_link=$(grep -o -E '\?[0-9]+-[0-9]+\.ILinkListener-showSigninLink' "$TMP/SRC" | head -n1)
  [ -z "$signin_link" ] && signin_link="?0-1.ILinkListener-showSigninLink"

  # Passo 2: GET página de login — obtém form action dinâmico
  curl -s -L \
    -c "$COOKIE_FILE" \
    -b "$COOKIE_FILE" \
    -A "$USER_AGENT" \
    "${URL}/${signin_link}" \
    -o "$TMP/SRC" 2>/dev/null
  sleep 0.5s

  # Ex: action="?1-2.IFormSubmitListener-loginForm"
  local form_action
  form_action=$(grep -o -E '\?[0-9]+-[0-9]+\.IFormSubmitListener-loginForm' "$TMP/SRC" | head -n1)
  [ -z "$form_action" ] && form_action="?1-2.IFormSubmitListener-loginForm"
  echo_t "Form: ${form_action}" "$GRAY_BLACK" "$COLOR_RESET"

  # Passo 3: Desencripta credenciais
  local creds user pass
  creds=$(base64 -d "$CRIPT_FILE" 2>/dev/null)
  user=$(echo "$creds" | sed 's/login=\([^&]*\).*/\1/')
  pass=$(echo "$creds" | sed 's/.*password=\(.*\)/\1/')
  unset creds

  # Passo 4: POST com campos reais confirmados no HTML
  # login=X  password=Y  id1_hf_0="" (hidden Wicket obrigatório)
  curl -s -L \
    -c "$COOKIE_FILE" \
    -b "$COOKIE_FILE" \
    -A "$USER_AGENT" \
    -X POST \
    --data-urlencode "login=${user}" \
    --data-urlencode "password=${pass}" \
    --data-urlencode "id1_hf_0=" \
    "${URL}/${form_action}" \
    -o "$TMP/SRC" 2>/dev/null

  unset user pass
  sleep 1s
}

_check_session() {
  curl -s -L \
    -c "$COOKIE_FILE" \
    -b "$COOKIE_FILE" \
    -A "$USER_AGENT" \
    "${URL}/angar" \
    -o "$ACC_FILE" 2>/dev/null

  # Não está logado se aparecer formulário de login
  if grep -q 'showSigninLink\|IFormSubmitListener-loginForm' "$ACC_FILE" 2>/dev/null; then
    return 1
  fi

  # Confirmado no HTML real: title="Hangar" ou user=198689
  if grep -q '<title>Hangar</title>' "$ACC_FILE" 2>/dev/null; then
    # Extrai ID e nível do jsInterface
    # HTML real: jsInterface.event("user=198689;level=47")
    PLAYER_ID=$(grep -o -E 'user=[0-9]+' "$ACC_FILE" | grep -o -E '[0-9]+' | head -n1)
    PLAYER_LEVEL=$(grep -o -E 'level=[0-9]+' "$ACC_FILE" | grep -o -E '[0-9]+' | head -n1)

    # Extrai combustível
    # HTML real: <img title="Combustível" .../> 20246
    FUEL_CURRENT=$(grep -A1 'title="Combustível"' "$ACC_FILE" \
      | grep -o -E '[0-9]+' | head -n1)
    # Fallback regex alternativo
    [ -z "$FUEL_CURRENT" ] && FUEL_CURRENT=$(grep -o -E 'fuel\.png[^>]*/>[^0-9]*[0-9]+' "$ACC_FILE" \
      | grep -o -E '[0-9]+$' | head -n1)

    [ -z "$ACC" ] && ACC="Jogador#${PLAYER_ID:-?}"

    echo_t "✅ Hangar | ID:${PLAYER_ID:-?} Nível:${PLAYER_LEVEL:-?} ⛽${FUEL_CURRENT:-?}" "$GOLD_BLACK" "$COLOR_RESET"
    return 0
  fi

  return 1
}

check_session_alive() {
  fetch_page "/angar"
  if grep -q 'showSigninLink\|IFormSubmitListener-loginForm' "$TMP/SRC" 2>/dev/null; then
    echo_t "Sessão expirou. A reconectar..." "$BLACK_YELLOW" "$COLOR_RESET" "after" "⚠️"
    _do_login
    _check_session
  fi
}

# Override check_session_alive com detecção user=0
check_session_alive() {
  fetch_page "/angar"
  if ! _session_active; then
    echo_t "Sessão perdida (user=0). A reconectar..." "$BLACK_YELLOW" "$COLOR_RESET" "after" "⚠️"
    JSESSIONID=""
    _do_login
    _check_session
  fi
}
