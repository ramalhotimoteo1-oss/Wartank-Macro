# Adicione ao _maintenance() no run.sh:

_maintenance() {
  # 1. Battle (PVE)
  if [ "$FUNC_pve" = "y" ]; then
    pve_check_and_apply
  fi

  # 2. PVP (apenas em horário específico)
  if _check_pvp_time; then
    pvp_mode
  fi

  # 3. Disputa (DM)
  if [ "$FUNC_dm" = "y" ]; then
    dm_check_and_apply
  fi

  # 4. Guerra (CW)
  if [ "$FUNC_cw" = "y" ]; then
    cw_check_and_apply
  fi

  # 5. Comboio
  if [ "$FUNC_convoy" = "y" ]; then
    convoy_mode
  fi

  # 6. Edifícios
  if [ "$FUNC_buildings" = "y" ]; then
    buildings_func
  fi

  # 7. Companhia
  if [ "$FUNC_company" = "y" ]; then
    company_func
  fi

  # 8. Assalto
  if [ "$FUNC_assault" = "y" ]; then
    assault_mode
  fi

  # 9. Recompensas (sempre)
  collect_all_rewards
  
  go_hangar
  func_sleep
}
