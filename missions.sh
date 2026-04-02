#!/bin/bash
# missions.sh — Missoes wartank-pt.net
# HTML real confirmado:
#   titulo: "Мissões" (com M cirílico)
#   link recolha: ;jsessionid=X?40-1.ILinkListener-missions-cc-N-c-awardLink
#   tab complicados: href="Advanced;jsessionid=X"
#   bz2/xpduel: missao de combate especial

missions_func() {
  [ "$FUNC_missions" = "n" ] && return 0

  echo "[missions] inicio"

  fetch_page "/missions/"

  # BUG CORRIGIDO: titulo tem "М" cirílico (não ASCII M)
  # Verificacao mais robusta — usa o link awardLink ou "Мissões"
  if ! grep -q 'Мissões\|missions-cc' "$SRC" 2>/dev/null; then
    echo "[missions] pagina invalida"
    go_hangar
    return
  fi

  # Tab Simples (pagina actual)
  echo "[missions] tab simples"
  _missions_collect_awards

  # Tab Complicados
  # HTML: href="Advanced;jsessionid=X" (quando Simples esta activo)
  local adv_link
  adv_link=$(grep -o -E 'Advanced;jsessionid=[A-Z0-9]+' "$SRC" | head -n1)
  if [ -n "$adv_link" ]; then
    fetch_page "/missions/${adv_link}"
    echo "[missions] tab complicados"
    _missions_collect_awards
  fi

  echo "[missions] fim"
  go_hangar
}

_missions_collect_awards() {
  # BUG CORRIGIDO: o pattern nao apanhava os links correctamente
  # HTML real: href=";jsessionid=XXXX?40-1.ILinkListener-missions-cc-0-c-awardLink"
  # O grep estava a procurar em $TMP/SRC em vez de $SRC

  local link collected=0

  # Extrai cada awardLink individualmente com while+read
  while IFS= read -r link; do
    [ -z "$link" ] && continue
    echo "[missions] a recolher: $link"
    # O link ja tem o jsessionid — passamos so o path
    fetch_page "$link"
    collected=$(( collected + 1 ))
    sleep 0.5s
    # Reload para apanhar proximos links actualizados
    fetch_page "/missions/"
  done < <(grep -o -E \
    ';jsessionid=[A-Z0-9]+\?[0-9]+-[0-9]+\.ILinkListener-missions-cc-[0-9]+-c-awardLink' \
    "$SRC" 2>/dev/null)

  echo "[missions] recolhidas: $collected"
}

special_combat_mission() {
  [ "$FUNC_special_missions" = "n" ] && return 0

  # xpduel e o link real no footer (confirmado no HTML)
  # bz2 tambem aparece nalgumas paginas
  for path in /xpduel /bz2; do
    fetch_page "$path"
    if grep -q '<title>' "$SRC" 2>/dev/null && \
       ! grep -q 'user=0;level=0' "$SRC" 2>/dev/null; then

      local award_link
      award_link=$(grep -o -E \
        ';jsessionid=[A-Z0-9]+\?[0-9]+-[0-9]+\.ILinkListener-[^"]*awardLink[^"]*' \
        "$SRC" | head -n1)

      if [ -n "$award_link" ]; then
        echo "[missions] recolher especial: $path"
        fetch_page "$award_link"
        sleep 0.5s
        return
      fi
    fi
  done
}

collect_all_rewards() {
  missions_func
  special_combat_mission
}
