# ============================================================
# convoy.sh — Comboio / Comércio (similar ao func_trade do Titans)
# ============================================================

convoy_mode() {
  if [ "$FUNC_convoy" = "n" ]; then return; fi
  
  echo_t "🚚 Comboio — Troca de recursos" "$GOLD_BLACK" "$COLOR_RESET"
  fetch_page "/convoy"
  
  if ! _session_active; then return; fi
  
  # Extrai recursos disponíveis para troca
  local silver_link gold_link
  silver_link=$(grep -o -E 'convoy\?[0-9]+-[0-9]+\.ILinkListener-exchangeSilver' "$SRC" | head -n1)
  gold_link=$(grep -o -E 'convoy\?[0-9]+-[0-9]+\.ILinkListener-exchangeGold' "$SRC" | head -n1)
  
  # Recursos atuais
  local current_silver current_gold
  current_silver=$(grep -o -E 'class="silver">[0-9]+' "$SRC" | grep -o -E '[0-9]+' | head -n1)
  current_gold=$(grep -o -E 'class="gold">[0-9]+' "$SRC" | grep -o -E '[0-9]+' | head -n1)
  
  echo_t "  🪙 Prata: ${current_silver:-0} | Ouro: ${current_gold:-0}" "$GRAY_BLACK" "$COLOR_RESET"
  
  # Troca prata se disponível (limite diário)
  if [ -n "$silver_link" ]; then
    local exchange_count=0
    local max_exchange="${CONVOY_SILVER_MAX:-5}"
    
    while [ "$exchange_count" -lt "$max_exchange" ] && [ -n "$silver_link" ]; do
      echo_t "   Trocando prata... (${exchange_count}/$max_exchange)" "$GRAY_BLACK" "$COLOR_RESET"
      fetch_page "/${silver_link}"
      sleep_rand 1000 2000
      exchange_count=$(( exchange_count + 1 ))
      
      # Reextrai link (pode mudar após cada troca)
      silver_link=$(grep -o -E 'convoy\?[0-9]+-[0-9]+\.ILinkListener-exchangeSilver' "$SRC" | head -n1)
    done
  fi
  
  # Troca ouro se disponível
  if [ -n "$gold_link" ]; then
    echo_t "   Trocando ouro..." "$GRAY_BLACK" "$COLOR_RESET"
    fetch_page "/${gold_link}"
    sleep_rand 1000 2000
  fi
  
  echo_t "Comboio concluído." "$GREEN_BLACK" "$COLOR_RESET"
}

# ============================================================
# buildings.sh — Edifícios (similar ao clan_statue)
# ============================================================

buildings_func() {
  if [ "$FUNC_buildings" = "n" ]; then return; fi
  
  echo_t "🏛️ Edifícios — Coleta automática" "$GOLD_BLACK" "$COLOR_RESET"
  fetch_page "/buildings"
  
  if ! _session_active; then return; fi
  
  # Coleta de todos os edifícios produtivos
  local collect_links
  collect_links=$(grep -o -E 'buildings\?[0-9]+-[0-9]+\.ILinkListener-[^"]*collect[^"]*' "$SRC")
  
  local count=0
  while IFS= read -r link; do
    [ -z "$link" ] && continue
    echo_t "   Coletando recurso..." "$GRAY_BLACK" "$COLOR_RESET"
    fetch_page "/${link}"
    sleep_rand 500 1000
    count=$(( count + 1 ))
  done <<< "$collect_links"
  
  [ "$count" -gt 0 ] && echo_t "  ✅ Coletados $count edifícios." "$GREEN_BLACK" "$COLOR_RESET"
  
  # Upgrade automático (se configurado)
  if [ "${BUILDINGS_AUTO_UPGRADE:-n}" = "y" ]; then
    local upgrade_links
    upgrade_links=$(grep -o -E 'buildings\?[0-9]+-[0-9]+\.ILinkListener-[^"]*upgrade[^"]*' "$SRC")
    
    while IFS= read -r link; do
      [ -z "$link" ] && continue
      echo_t "   🔧 Upgrading building..." "$YELLOW_BLACK" "$COLOR_RESET"
      fetch_page "/${link}"
      sleep_rand 2000 3000
    done <<< "$upgrade_links"
  fi
}

# ============================================================
# company.sh — Companhia / Clã (similar ao clanDungeon)
# ============================================================

company_func() {
  if [ "$FUNC_company" = "n" ]; then return; fi
  
  echo_t "🏢 Companhia — Operações diárias" "$GOLD_BLACK" "$COLOR_RESET"
  fetch_page "/company"
  
  if ! _session_active; then return; fi
  
  # Contribuição diária para a companhia
  local contribute_link
  contribute_link=$(grep -o -E 'company\?[0-9]+-[0-9]+\.ILinkListener-contribute' "$SRC" | head -n1)
  
  if [ -n "$contribute_link" ]; then
    echo_t "   Contribuindo para a companhia..." "$GRAY_BLACK" "$COLOR_RESET"
    fetch_page "/${contribute_link}"
    sleep_rand 1000 2000
  fi
  
  # Coleta de recompensas da companhia
  local reward_link
  reward_link=$(grep -o -E 'company\?[0-9]+-[0-9]+\.ILinkListener-collectReward' "$SRC" | head -n1)
  
  if [ -n "$reward_link" ]; then
    echo_t "   Coletando recompensas da companhia..." "$GREEN_BLACK" "$COLOR_RESET"
    fetch_page "/${reward_link}"
    sleep_rand 1000 2000
  fi
  
  # Missões da companhia
  local mission_links
  mission_links=$(grep -o -E 'company\?[0-9]+-[0-9]+\.ILinkListener-startMission[^"]*' "$SRC")
  
  while IFS= read -r link; do
    [ -z "$link" ] && continue
    echo_t "   Iniciando missão da companhia..." "$GRAY_BLACK" "$COLOR_RESET"
    fetch_page "/${link}"
    sleep_rand 1500 2500
  done <<< "$mission_links"
}

# ============================================================
# assault.sh — Assalto (similar ao campaign_func)
# ============================================================

assault_mode() {
  if [ "$FUNC_assault" = "n" ]; then return; fi
  
  echo_t "⚡ Assalto — Modo campanha" "$GOLD_BLACK" "$COLOR_RESET"
  fetch_page "/assault"
  
  if ! _session_active; then return; fi
  
  # Lista de batalhas de assalto disponíveis
  local battle_links
  battle_links=$(grep -o -E 'assault\?[0-9]+-[0-9]+\.ILinkListener-battle[0-9]+' "$SRC")
  
  local battles_fought=0
  local max_battles="${ASSAULT_MAX_BATTLES:-3}"
  
  while IFS= read -r link && [ "$battles_fought" -lt "$max_battles" ]; do
    [ -z "$link" ] && continue
    
    echo_t "   Iniciando assalto #$((battles_fought + 1))..." "$GRAY_BLACK" "$COLOR_RESET"
    fetch_page "/${link}"
    sleep_rand 2000 3000
    
    # Participa da batalha
    local fight_link
    fight_link=$(grep -o -E 'assault\?[0-9]+-[0-9]+\.ILinkListener-fight' "$SRC" | head -n1)
    
    if [ -n "$fight_link" ]; then
      fetch_page "/${fight_link}"
      sleep_rand 3000 5000
      battles_fought=$(( battles_fought + 1 ))
      echo_t "   ✅ Assalto #${battles_fought} concluído!" "$GREEN_BLACK" "$COLOR_RESET"
    fi
    
  done <<< "$battle_links"
  
  echo_t "Assaltos realizados: ${battles_fought}" "$GREEN_BLACK" "$COLOR_RESET"
}

# ============================================================
# missions.sh — Missões e Recompensas
# ============================================================

collect_all_rewards() {
  echo_t "🎁 Coletando todas as recompensas" "$GOLD_BLACK" "$COLOR_RESET"
  fetch_page "/rewards"
  
  if ! _session_active; then return; fi
  
  # Recompensas diárias
  local daily_reward
  daily_reward=$(grep -o -E 'rewards\?[0-9]+-[0-9]+\.ILinkListener-collectDaily' "$SRC" | head -n1)
  if [ -n "$daily_reward" ]; then
    echo_t "   Coletando recompensa diária..." "$GREEN_BLACK" "$COLOR_RESET"
    fetch_page "/${daily_reward}"
    sleep_rand 1000 1500
  fi
  
  # Recompensas de missões
  local mission_rewards
  mission_rewards=$(grep -o -E 'rewards\?[0-9]+-[0-9]+\.ILinkListener-collectMission[0-9]+' "$SRC")
  
  local count=0
  while IFS= read -r link; do
    [ -z "$link" ] && continue
    fetch_page "/${link}"
    sleep_rand 500 1000
    count=$(( count + 1 ))
  done <<< "$mission_rewards"
  
  [ "$count" -gt 0 ] && echo_t "   ✅ ${count} recompensas de missões coletadas." "$GREEN_BLACK" "$COLOR_RESET"
  
  # Recompensas de conquistas
  local achievement_rewards
  achievement_rewards=$(grep -o -E 'rewards\?[0-9]+-[0-9]+\.ILinkListener-collectAchievement[^"]*' "$SRC")
  
  count=0
  while IFS= read -r link; do
    [ -z "$link" ] && continue
    fetch_page "/${link}"
    sleep_rand 500 1000
    count=$(( count + 1 ))
  done <<< "$achievement_rewards"
  
  [ "$count" -gt 0 ] && echo_t "   🏆 ${count} conquistas coletadas!" "$YELLOW_BLACK" "$COLOR_RESET"
}

# ============================================================
# config.sh — Menu de configuração
# ============================================================

config_menu() {
  local config_file="$TMP/config.cfg"
  
  echo_t "⚙️ Configuração do Bot" "$CYAN_BLACK" "$COLOR_RESET"
  echo ""
  echo "1) Batalhas PVP (${FUNC_pvp:-y})"
  echo "2) Batalhas PVE (${FUNC_pve:-y})"
  echo "3) Disputa/DM (${FUNC_dm:-y})"
  echo "4) Guerra/CW (${FUNC_cw:-y})"
  echo "5) Comboio (${FUNC_convoy:-y})"
  echo "6) Edifícios (${FUNC_buildings:-y})"
  echo "7) Companhia (${FUNC_company:-y})"
  echo "8) Assalto (${FUNC_assault:-y})"
  echo "9) Combustível mínimo (${FUEL_MIN:-10})"
  echo "10) Batalhas PVP por ciclo (${PVP_BATTLES:-4})"
  echo "0) Salvar e sair"
  echo ""
  
  read -r opt
  case "$opt" in
    1) toggle_config "FUNC_pvp" ;;
    2) toggle_config "FUNC_pve" ;;
    3) toggle_config "FUNC_dm" ;;
    4) toggle_config "FUNC_cw" ;;
    5) toggle_config "FUNC_convoy" ;;
    6) toggle_config "FUNC_buildings" ;;
    7) toggle_config "FUNC_company" ;;
    8) toggle_config "FUNC_assault" ;;
    9) 
      echo "Combustível mínimo atual: ${FUEL_MIN:-10}"
      echo -n "Novo valor: "
      read -r new_val
      [ -n "$new_val" ] && sed -i "s/^FUEL_MIN=.*/FUEL_MIN=$new_val/" "$config_file"
      ;;
    10)
      echo "Batalhas PVP por ciclo atual: ${PVP_BATTLES:-4}"
      echo -n "Novo valor: "
      read -r new_val
      [ -n "$new_val" ] && sed -i "s/^PVP_BATTLES=.*/PVP_BATTLES=$new_val/" "$config_file"
      ;;
    0) 
      load_config
      return 0
      ;;
  esac
  
  config_menu
}

toggle_config() {
  local var="$1"
  local config_file="$TMP/config.cfg"
  local current=$(grep "^${var}=" "$config_file" | cut -d'=' -f2)
  
  if [ "$current" = "y" ]; then
    sed -i "s/^${var}=.*/${var}=n/" "$config_file"
  else
    sed -i "s/^${var}=.*/${var}=y/" "$config_file"
  fi
  
  config_menu
}
