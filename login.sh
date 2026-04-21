#!/bin/bash
# login.sh — Login v1.4.0
# Fix: apagar cript_file E cookies para mudar de conta

login_func() {
  # Se ja tem credenciais, tenta login directo
  if [ -f "$CRIPT_FILE" ] && [ -s "$CRIPT_FILE" ]; then
    echo "[login] a usar credenciais guardadas..."
    _do_login
    if _check_session; then
      return 0
    fi
    echo "[login] sessao invalida — a pedir credenciais novamente..."
    # FIX: apaga TAMBEM os cookies — senao o servidor mantém a sessão antiga
    rm -f "$CRIPT_FILE" "$COOKIE_FILE"
  fi

  _login_prompt

  if [ $? -ne 0 ]; then
    return 1
  fi

  _do_login

  if ! _check_session; then
    echo "[login] ERRO: login falhou — verifica username e password"
    rm -f "$CRIPT_FILE" "$COOKIE_FILE"
    return 1
  fi

  log_ok "Login: $ACC"
  return 0
}

_login_prompt() {
  clear
  echo ""
  echo "  Login — wartank-pt.net"
  echo ""
  printf "  Username: "
  read -r username

  if [ -z "$username" ]; then
    echo "  ERRO: username vazio"
    return 1
  fi

  local password="" char
  printf "  Password: "
  while IFS= read -r -s -n1 char; do
    [ -z "$char" ] && break
    if [ "$char" = $'\177' ] || [ "$char" = $'\010' ]; then
      [ -n "$password" ] && password="${password%?}" && printf '\b \b'
      continue
    fi
    password="${password}${char}"
    printf '*'
  done
  echo ""

  if [ -z "$password" ]; then
    echo "  ERRO: password vazia"
    return 1
  fi

  # Guarda credenciais + limpa cookies antigos para garantir sessão nova
  rm -f "$COOKIE_FILE"
  _encrypt_creds "login=${username}&password=${password}" "$CRIPT_FILE"
  ACC="$username"
  unset username password
  return 0
}

_do_login() {
  local creds user pass

  creds=$(_decrypt_creds "$CRIPT_FILE")
  if [ -z "$creds" ]; then
    echo "[login] ERRO: nao conseguiu ler credenciais"
    return 1
  fi

  user=$(echo "$creds" | sed 's/login=\([^&]*\).*/\1/')
  pass=$(echo "$creds" | sed 's/.*password=\(.*\)/\1/')
  ACC="${ACC:-$user}"

  # Passo 1: pagina inicial
  curl -s -L \
    -c "$COOKIE_FILE" -b "$COOKIE_FILE" \
    -A "$USER_AGENT" --max-time 20 \
    -o "$SRC" "${URL}/" 2>>"$LOG_FILE"
  sleep_rand 400 800

  # Passo 2: link de signin
  local signin_link
  signin_link=$(grep -o -E '\?[0-9]+-[0-9]+\.ILinkListener-showSigninLink' \
    "$SRC" | head -n1)

  curl -s -L \
    -c "$COOKIE_FILE" -b "$COOKIE_FILE" \
    -A "$USER_AGENT" --max-time 20 \
    -o "$SRC" "${URL}/${signin_link}" 2>>"$LOG_FILE"
  sleep_rand 400 800

  # Passo 3: form action
  local form_action
  form_action=$(grep -o -E '\?[0-9]+-[0-9]+\.IFormSubmitListener-loginForm' \
    "$SRC" | head -n1)

  if [ -z "$form_action" ]; then
    _update_jsessionid
    echo "[login] form nao encontrado"
    return 0
  fi

  echo "[login] form: $form_action"

  # Passo 4: POST
  curl -s -L \
    -c "$COOKIE_FILE" -b "$COOKIE_FILE" \
    -A "$USER_AGENT" --max-time 20 \
    -X POST \
    --data-urlencode "login=${user}" \
    --data-urlencode "password=${pass}" \
    --data-urlencode "id1_hf_0=" \
    -o "$SRC" \
    "${URL}/${form_action}" 2>>"$LOG_FILE"

  unset user pass creds
  sleep_rand 800 1500
  _update_jsessionid
}

_check_session() {
  local tmp_file="$TMP/session_check"
  local cacert=""
  for ca in \
    /data/data/com.termux/files/usr/etc/tls/cert.pem \
    /etc/ssl/certs/ca-certificates.crt; do
    [ -f "$ca" ] && { cacert="--cacert $ca"; break; }
  done

  # shellcheck disable=SC2086
  curl -s -L \
    -c "$COOKIE_FILE" -b "$COOKIE_FILE" \
    -A "$USER_AGENT" --max-time 20 \
    $cacert \
    -o "$tmp_file" \
    "${URL}/angar;jsessionid=${JSESSIONID}" 2>>"$LOG_FILE"

  if grep -q '<title>Hangar</title>' "$tmp_file" 2>/dev/null; then
    PLAYER_ID=$(grep -o -E 'user=[0-9]+' "$tmp_file" \
      | grep -o -E '[0-9]+' | head -n1)
    PLAYER_LEVEL=$(grep -o -E 'level=[0-9]+' "$tmp_file" \
      | grep -o -E '[0-9]+' | head -n1)
    FUEL_CURRENT=$(grep -A1 'title="Combustível"' "$tmp_file" \
      | grep -o -E '[0-9]+' | head -n1)
    [ -z "$ACC" ] && ACC="ID:${PLAYER_ID:-?}"
    echo "[login] OK | $ACC | nivel:${PLAYER_LEVEL:-?} | combustivel:${FUEL_CURRENT:-?}"
    cp "$tmp_file" "$SRC"
    _update_jsessionid
    return 0
  fi

  echo "[login] FALHOU"
  return 1
}

check_session_alive() {
  fetch_page "/angar"
  if ! _session_active; then
    echo "[sessao] expirou — a reconectar"
    _do_login
    fetch_page "/angar"
  fi
}
