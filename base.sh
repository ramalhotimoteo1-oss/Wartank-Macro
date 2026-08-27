#!/bin/bash
# base.sh — Base unificada v1.1.0
#
# ALTERACOES v1.1.0:
#   + Recolha "Pegar": regex mais largos + normalizacao de path
#   + Debug quando nao encontra takeProductionLink
#   + Log claro em cada passo (mina / poligono / armory)
#   + fetch de links relativos sempre com path correcto
#
# Ordem: recolha → mina → poligono → armory → mercado (horarios)

MARKET_GOLD_HOURS="${MARKET_GOLD_HOURS:-06 12 18 22}"
MARKET_GOLD_MINUTE="${MARKET_GOLD_MINUTE:-27}"
MARKET_GOLD_WINDOW="${MARKET_GOLD_WINDOW:-3}"
LAST_MARKET_GOLD_SLOT=""

base_mode() {
  [ "${FUNC_buildings:-y}" = "n" ] && return 0

  echo "[base] inicio"

  _base_collect_production
  _base_mine
  _base_polygon
  _base_armory
  _base_market_gold

  echo "[base] fim"
}

# Normaliza href relativo para path usavel no fetch_page
_base_norm() {
  local link="$1"
  link=$(echo "$link" | sed 's/^["'\'']//;s/["'\'']$//;s/;jsessionid=[A-Z0-9]*//')

  case "$link" in
    /*) echo "$link" ;;
    buildings\?*|buildings/*) echo "/$link" ;;
    polygon\?*|polygon/*) echo "/$link" ;;
    market\?*|market/*) echo "/$link" ;;
    Mine\?*) echo "/production/$link" ;;
    Armory\?*) echo "/production/$link" ;;
    Bank\?*) echo "/production/$link" ;;
    \?*) echo "/buildings$link" ;;
    *) echo "/$link" ;;
  esac
}

# ── Recolher "Pegar" em /buildings ────────────────────────────
_base_collect_production() {
  echo "[base] a verificar recolha (Pegar)"
  fetch_page "/buildings"
  if ! _session_active; then
    echo "[base] sessao invalida em /buildings"
    return
  fi

  if ! grep -qiE '<title>Base</title>|buildings-' "$SRC" 2>/dev/null; then
    echo "[base] pagina Base invalida: $(grep -oE '<title>[^<]+</title>' "$SRC" 2>/dev/null | head -1)"
    return
  fi

  local link n=0
  local links

  # Padrao completo
  links=$(grep -oE \
    'buildings\?[0-9]+-[0-9]+\.ILinkListener-buildings-[0-9]+-building-rootBlock-actionPanel-takeProductionLink' \
    "$SRC" 2>/dev/null)

  # Fallback: qualquer takeProductionLink
  if [ -z "$links" ]; then
    links=$(grep -oE \
      '[^"<> ]*takeProductionLink[^"<> ]*' \
      "$SRC" 2>/dev/null)
  fi

  # Fallback: botao com texto Pegar no href proximo (ILinkListener com take)
  if [ -z "$links" ]; then
    links=$(grep -oE \
      'ILinkListener[^"<> ]*take[^"<> ]*' \
      "$SRC" 2>/dev/null | grep -i production)
  fi

  if [ -z "$links" ]; then
    echo "[base] nenhuma producao a recolher"
    # Debug util
    local sample
    sample=$(grep -oE 'ILinkListener[^"<> ]{10,80}' "$SRC" 2>/dev/null | head -6 | tr '\n' ' ')
    [ -n "$sample" ] && echo "[base] debug links: $sample"
    return
  fi

  while IFS= read -r link; do
    [ -z "$link" ] && continue
    # Evitar duplicados do grep solto
    echo "$link" | grep -qi takeProduction || continue

    link=$(_base_norm "$link")
    # Garantir prefixo buildings se for so o ILinkListener
    case "$link" in
      /ILinkListener*|/\?[0-9]*) link="/buildings${link#/}" ;;
    esac

    echo "[base] a recolher: $link"
    fetch_page "$link"
    n=$(( n + 1 ))
    sleep_rand 300 500
    fetch_page "/buildings"
  done <<< "$links"

  echo "[base] $n producao(oes) recolhida(s)"
}

# ── Mina: so MINERIO ──────────────────────────────────────────
_base_mine() {
  echo "[base/mina] verificar"
  fetch_page "/production/Mine"
  if ! _session_active; then return; fi

  local ore_link
  ore_link=$(grep -oE \
    'Mine\?[0-9]+-[0-9]+\.ILinkListener-productions-0-production-startProduceLink' \
    "$SRC" 2>/dev/null | head -n1)

  # Fallback mais largo
  [ -z "$ore_link" ] && \
    ore_link=$(grep -oE \
      '[^"<> ]*productions-0-production-startProduceLink[^"<> ]*' \
      "$SRC" 2>/dev/null | head -n1)

  if [ -z "$ore_link" ]; then
    if grep -qE 'startProduceLink' "$SRC" 2>/dev/null; then
      echo "[base/mina] minério indisponivel (outras opcoes ignoradas)"
    else
      echo "[base/mina] sem start — ja a produzir ou sem opcoes"
    fi
    return
  fi

  ore_link=$(_base_norm "$ore_link")
  echo "[base/mina] a iniciar minério: $ore_link"
  fetch_page "$ore_link"
  sleep_rand 500 800
  echo "[base/mina] producao de minério iniciada"
}

# ── Poligono: so ataque gratis (buffs-0) ──────────────────────
_base_polygon() {
  echo "[base/polygon] verificar"
  fetch_page "/polygon"
  if ! _session_active; then return; fi

  local free_atk
  free_atk=$(grep -oE \
    'polygon\?[0-9]+-[0-9]+\.ILinkListener-buffs-0-buff-getFreeLink' \
    "$SRC" 2>/dev/null | head -n1)

  [ -z "$free_atk" ] && \
    free_atk=$(grep -oE \
      '[^"<> ]*buffs-0-buff-getFreeLink[^"<> ]*' \
      "$SRC" 2>/dev/null | head -n1)

  if [ -z "$free_atk" ]; then
    if grep -qE 'buffs-[123]-buff-getFreeLink' "$SRC" 2>/dev/null; then
      echo "[base/polygon] ataque gratis indisponivel (outros ignorados)"
    elif grep -qiE 'ATIVO|Resta:|Intensifica' "$SRC" 2>/dev/null; then
      echo "[base/polygon] buff de ataque activo / em cooldown"
    else
      echo "[base/polygon] sem getFreeLink de ataque"
      local sample
      sample=$(grep -oE 'buffs-[0-9][^"<> ]{5,50}' "$SRC" 2>/dev/null | head -4 | tr '\n' ' ')
      [ -n "$sample" ] && echo "[base/polygon] debug: $sample"
    fi
    return
  fi

  free_atk=$(_base_norm "$free_atk")
  echo "[base/polygon] a activar ataque gratis: $free_atk"
  fetch_page "$free_atk"
  sleep_rand 500 800
  echo "[base/polygon] intensificacao do ataque activada"
}

# ── Sala de armas ─────────────────────────────────────────────
_base_armory() {
  echo "[base/armory] verificar"
  fetch_page "/production/Armory"
  if ! _session_active; then return; fi

  if ! grep -q 'startProduceLink' "$SRC" 2>/dev/null; then
    echo "[base/armory] sem start — ja a produzir"
    return
  fi

  local he ap hc kit
  he=$(_base_armory_stock 'Granada explosiva')
  ap=$(_base_armory_stock 'Projétil perfurante')
  hc=$(_base_armory_stock 'Granada de carga oca')
  kit=$(_base_armory_stock_kit)

  echo "[base/armory] stock kit=${kit:-?} HE=${he:-?} AP=${ap:-?} HC=${hc:-?}"

  local idx="" label=""
  local kit_min="${ARMORY_KIT_MIN:-500}"

  if [ -n "$kit" ] && [ "$kit" -le "$kit_min" ] 2>/dev/null; then
    idx=3
    label="kit de reparacao"
  else
    he=${he:-0}; ap=${ap:-0}; hc=${hc:-0}
    local min=$he
    idx=0
    label="granada explosiva"
    if [ "$ap" -lt "$min" ] 2>/dev/null; then
      min=$ap; idx=1; label="projetil perfurante"
    fi
    if [ "$hc" -lt "$min" ] 2>/dev/null; then
      min=$hc; idx=2; label="carga oca"
    fi
  fi

  local link
  link=$(grep -oE \
    "Armory\\?[0-9]+-[0-9]+\\.ILinkListener-productions-${idx}-production-startProduceLink" \
    "$SRC" 2>/dev/null | head -n1)

  [ -z "$link" ] && \
    link=$(grep -oE \
      "[^\"<> ]*productions-${idx}-production-startProduceLink[^\"<> ]*" \
      "$SRC" 2>/dev/null | head -n1)

  if [ -z "$link" ]; then
    echo "[base/armory] link idx=$idx nao encontrado"
    return
  fi

  link=$(_base_norm "$link")
  echo "[base/armory] a produzir: $label ($link)"
  fetch_page "$link"
  sleep_rand 500 800
  echo "[base/armory] producao iniciada"
}

_base_armory_stock() {
  local name="$1"
  grep -oE "alt=\"${name}\"[^0-9]*[0-9]+" "$SRC" 2>/dev/null \
    | grep -oE '[0-9]+$' | head -n1
}

_base_armory_stock_kit() {
  local n
  n=$(grep -oE 'repairkit[^0-9]*[0-9]+' "$SRC" 2>/dev/null \
    | grep -oE '[0-9]+$' | head -n1)
  [ -n "$n" ] && { echo "$n"; return; }
  grep -oE 'Kit de repara[^0-9]*[0-9]+' "$SRC" 2>/dev/null \
    | grep -oE '[0-9]+$' | head -n1
}

# ── Mercado: prata → ouro, max 4x/dia ─────────────────────────
_base_market_gold() {
  [ "${FUNC_market_gold:-n}" = "n" ] && return 0

  local slot
  slot=$(_market_gold_slot)
  [ -z "$slot" ] && return 0
  if [ "$LAST_MARKET_GOLD_SLOT" = "$slot" ]; then
    echo "[base/market] ja trocou neste slot ($slot)"
    return 0
  fi

  echo "[base/market] horario de troca prata→ouro ($slot)"
  fetch_page "/market"
  if ! _session_active; then return; fi

  local buy
  buy=$(grep -oE \
    'market\?[0-9]+-[0-9]+\.ILinkListener-xcSilverToGold-buyGold' \
    "$SRC" 2>/dev/null | head -n1)

  if [ -z "$buy" ]; then
    echo "[base/market] buyGold indisponivel"
    return
  fi

  buy=$(_base_norm "$buy")
  echo "[base/market] a trocar: $buy"
  fetch_page "$buy"
  sleep_rand 500 800
  LAST_MARKET_GOLD_SLOT="$slot"
  echo "[base/market] troca feita (slot $slot)"
}

_market_gold_slot() {
  local h m pm win gh
  printf -v h '%(%H)T' -1
  printf -v m '%(%M)T' -1
  h=$((10#$h)); m=$((10#$m))
  pm=$((10#${MARKET_GOLD_MINUTE:-27}))
  win=$((10#${MARKET_GOLD_WINDOW:-3}))

  for gh in $MARKET_GOLD_HOURS; do
    gh=$((10#$gh))
    if [ "$h" -eq "$gh" ] && [ "$m" -ge "$pm" ] && [ "$m" -lt $(( pm + win )) ]; then
      printf '%02d:%02d' "$gh" "$pm"
      return
    fi
  done
  echo ""
}
