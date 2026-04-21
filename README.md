# Wartank Bot v1.3.0

Bot automatizado para **wartank-pt.net** — escrito em Bash puro.
Funciona no **Termux (Android)** e em qualquer Linux.
Suporte a **múltiplas contas** com workers isolados.

---

## Instalação

```bash
# 1. Copia os ficheiros para a pasta do bot
cp -r wartank-bot ~/Wartank-Bot
cd ~/Wartank-Bot

# 2. Da permissao de execucao
chmod +x *.sh

# 3. Adiciona a tua conta
./setup.sh

# 4. Inicia o bot
./play.sh
```

---

## Ficheiros — o que faz cada um

```
Wartank-Bot/
├── play.sh        → Inicia o bot (single ou multi-contas)
├── setup.sh       → Gere contas (adicionar / remover)
├── stop.sh        → Para o bot e todos os workers
├── worker.sh      → Loop de uma conta (chamado pelo play.sh)
├── wartank.sh     → Engine principal — carrega todos os modulos
├── core.sh        → Funcoes base: fetch_page, login, sessao, logs
├── config.sh      → Configuracoes e menu interactivo
├── login.sh       → Login no wartank-pt.net
├── hangar.sh      → Hangar — ponto central entre todas as accoes
├── run.sh         → Scheduler — decide o que fazer a cada ciclo
├── battle.sh      → Adiante a Combater (batalha normal)
├── pvp.sh         → PvP (horario configuravel)
├── pve.sh         → PvE — Batalhas historicas
├── cw.sh          → Guerra (Clan War)
├── dm.sh          → Disputa (Deathmatch)
├── missions.sh    → Missoes normais e especiais
├── buildings.sh   → Base — recolha de producao
├── convoy.sh      → Escolta (comboio inimigo)
├── company.sh     → Divisao e missoes de divisao
├── assault.sh     → Missao especial (Assault)
└── accounts.conf  → Lista de contas (criado pelo setup.sh)
```

---

## Como usar — Single conta

```bash
./play.sh
```

O bot faz login, vai ao hangar e entra no loop automatico.
Para parar, escreve `stop` no terminal.

---

## Como usar — Multi-contas

```bash
# Passo 1: adiciona cada conta
./setup.sh
# Escolhe "2) Adicionar" e insere username + password para cada conta

# Passo 2: inicia todas as contas
./play.sh
# O bot lanca um worker por conta, cada um em background

# Para ver o log de uma conta
tail -f ~/.wartank/USERNAME/bot.log

# Para parar tudo
./stop.sh
```

Cada conta corre de forma **completamente independente**.
Os dados de cada conta ficam em `~/.wartank/USERNAME/`.

---

## Comandos durante execucao

Escreve no terminal enquanto o bot corre:

| Comando  | O que faz                        |
|----------|----------------------------------|
| `stop`   | Para o bot                       |
| `config` | Abre o menu de configuracoes     |
| `status` | Actualiza e mostra estado actual |

---

## Configuracoes (config.cfg)

O ficheiro `config.cfg` e criado automaticamente na primeira execucao.
Podes editar manualmente ou usar o menu `config` durante a execucao.

```
# Modulos activos (y=sim, n=nao)
FUNC_battle=y          # Batalha normal (Adiante a Combater)
FUNC_missions=y        # Recolha de missoes
FUNC_special_missions=y
FUNC_pvp=y             # PvP
FUNC_pvp_hour=21       # Hora do PvP (0-23)
FUNC_pve=y             # PvE (batalhas historicas)
FUNC_cw=y              # Guerra (Clan War)
FUNC_dm=y              # Disputa (Deathmatch)
FUNC_convoy=y          # Escolta
FUNC_buildings=y       # Base (recolha de producao)
FUNC_assault=y         # Missao especial
FUNC_company=y         # Divisao

# Batalha normal
BATTLE_LA=3            # Segundos entre disparos
BATTLE_SHOTS=9         # Total de disparos (9 = 3 inimigos destruidos)
BATTLE_TIMEOUT=600     # Timeout maximo em segundos

# PvE
PVE_RELOAD=6           # Segundos entre disparos no PvE
PVE_TIMEOUT=600        # Timeout maximo em segundos

# Geral
FUEL_MIN=0             # Combustivel minimo para batalhar
ASSAULT_MIN_MEMBERS=2  # Membros minimos para iniciar missao especial
```

---

## Logica de cada modulo

### Batalha normal (battle.sh)

O bot vai a `/battle`, faz **9 disparos** (3 inimigos × 3 disparos).
Cada disparo consome ~30 combustivel — 9 disparos = ~270 no total.

Antes de combater, verifica se tem combustivel suficiente (≥270).
Se nao tiver, salta a batalha e continua com os outros modulos.

O combustivel regenera: **30 unidades a cada ~7m44s**.

### PvE (pve.sh)

Batalhas historicas que ocorrem a horas fixas.
O bot verifica `/pve` a cada ciclo — se o botao "Pelotao, ao ataque!"
estiver disponivel, aplica imediatamente.

Nao usa horarios fixos — detecta dinamicamente.
Resistente ao horario de verao de Portugal (DST).

Apos o fim de cada batalha, o lobby mostra imediatamente a proxima
com "0 requerimentos" — o bot aplica logo sem esperar.

### Guerra / Disputa / PvP (cw.sh / dm.sh / pvp.sh)

Estas batalhas **nao consomem combustivel**.

- **Guerra**: detectada dinamicamente quando o botao de entrada aparece
- **Disputa**: igual — detectada quando disponivel (~11:20, 15:20, 21:20 PT)
- **PvP**: corre uma vez por dia a `FUNC_pvp_hour` (padrao: 21h)

### Missoes (missions.sh)

Recolhe todas as recompensas disponiveis em `/missions/`.
Verifica a tab "Simples" e a tab "Complicados".
Tambem verifica a missao de combate especial (`/xpduel`).

### Base (buildings.sh)

Recolhe a producao dos edificios: Mina, Sala de armas, Banco.
O Poligono, Mercado e Laboratorio nao tem recolha automatica.

### Escolta (convoy.sh)

Inicia o reconhecimento e recolhe recompensas das missoes da escolta.

### Missao especial (assault.sh)

Entra no primeiro alvo disponivel.
Se tiver `ASSAULT_MIN_MEMBERS` membros, inicia o combate.
Nao bloqueia — se nao houver membros suficientes, sai e continua.

---

## Fluxo completo

```
play.sh
  └── worker.sh (uma por conta, em background)
        └── wartank.sh (loop infinito)
              ├── Login
              ├── Hangar
              └── Loop principal (wartank_play)
                    ├── PvP (se for a hora configurada)
                    ├── _check_battles
                    │     ├── /cw  → guerra se disponivel
                    │     ├── /dm  → disputa se disponivel
                    │     └── /pve → pve se disponivel
                    └── _maintenance
                          ├── battle (se combustivel >= 270)
                          ├── missions (recolha)
                          ├── buildings (producao)
                          ├── convoy (escolta)
                          ├── company (divisao)
                          └── assault (missao especial)
```

---

## Logs

Os logs ficam em:

```
# Single conta
~/Wartank-Bot/.tmp/bot.log

# Multi-contas
~/.wartank/USERNAME/bot.log
```

Para ver em tempo real:

```bash
tail -f ~/.wartank/USERNAME/bot.log
```

---

## Problemas comuns

**"Config nao encontrado. A criar..."** em cada ciclo

O `BOT_DIR` nao esta a ser detectado correctamente.
Garante que corres o bot sempre a partir da pasta do bot:

```bash
cd ~/Wartank-Bot
./play.sh
```

---

**"Login falhou"**

1. Apaga as credenciais antigas: `rm ~/.wartank/USERNAME/cript_file`
2. Corre `./setup.sh` e adiciona a conta novamente
3. Ou apaga `.tmp/cript_file` na pasta do bot (single conta)

---

**Bot nao combate (sem "[battle] inicio")**

Verifica o log: `tail -f .tmp/bot.log`

Causas possiveis:
- `FUNC_battle=n` no config.cfg
- Combustivel insuficiente (< 270)
- `load_config` a recriar o config — confirma que `BOT_DIR` esta correcto

---

**Sessao expira frequentemente**

Normal em conexoes moveis. O bot reconecta automaticamente.
Se falhar 3 vezes seguidas, para e mostra erro no log.

---

## Notas tecnicas

- **Sessao**: jsessionid deve estar na URL E nos cookies (Apache Wicket)
- **fetch_page**: adiciona jsessionid automaticamente a cada request
- **Credenciais**: guardadas em base64 com `chmod 600`
- **Anti-ban**: delay aleatorio de 300-800ms entre cada request
- **Sem dependencias externas**: apenas `bash`, `curl`, `grep`, `sed`, `awk`, `base64`
