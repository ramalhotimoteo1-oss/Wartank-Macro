#!/bin/bash
# ============================================================
# info.sh — Compatibilidade (delega para core.sh)
# ============================================================
# core.sh já define: fetch_page, echo_t, colors, _session_active
# etc. Este ficheiro existe apenas para compatibilidade caso
# algum módulo faça ". info.sh" directamente.
# Não redefine nada — core.sh é a fonte de verdade.
