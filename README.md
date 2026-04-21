# Wartank Bot v1.3.0

Bot automático para wartank-pt.net — funciona no Android via Termux.

---

## PARTE 1 — Instalar o Termux

**O que é o Termux?**
É um terminal Linux que corre no Android. O bot precisa dele para funcionar.

**Passo 1** — Instala o Termux pela F-Droid (recomendado, versão mais actualizada):

```
https://f-droid.org/packages/com.termux/
```

> Não uses a versão da Play Store — está desactualizada.

---

**Passo 2** — Abre o Termux e actualiza os pacotes:

```bash
pkg update
```

```bash
pkg upgrade
```

> Quando perguntar "Do you want to continue? [y/N]" escreve `y` e prime Enter.

---

**Passo 3** — Instala as ferramentas necessárias:

```bash
pkg install curl
```

```bash
pkg install bash
```

```bash
pkg install grep
```

> O `sed`, `awk` e `base64` já vêm instalados por defeito no Termux.

---

**Passo 4** — Verifica que tudo está instalado:

```bash
curl --version && bash --version && grep --version
```

> Se aparecerem versões sem erros, está pronto.

---

## PARTE 2 — Instalar o Bot

**Passo 1** — Cria a pasta do bot:

```bash
mkdir -p ~/Wartank-Bot
```

**Passo 2** — Entra na pasta:

```bash
cd ~/Wartank-Bot
```

**Passo 3** — Copia os ficheiros do bot para esta pasta.

> Podes fazer via USB, Bluetooth, ou qualquer gestor de ficheiros.
> Os ficheiros que precisas estão todos na pasta `wartank-bot` que recebeste.

**Passo 4** — Dá permissão de execução a todos os scripts:

```bash
chmod +x *.sh
```

---

## PARTE 3 — Configurar a Conta

**Passo 1** — Abre o menu de gestão de contas:

```bash
./setup.sh
```

**Passo 2** — Escolhe a opção `2) Adicionar`

**Passo 3** — Insere o teu username do wartank-pt.net

**Passo 4** — Insere a tua password

> A password não aparece no ecrã enquanto escreves — é normal.
> As credenciais ficam guardadas de forma segura em base64.

---

## PARTE 4 — Iniciar o Bot

**Para iniciar:**

```bash
./play.sh
```

> O bot faz login, vai ao hangar e entra em modo automático.
> Vais ver as acções a aparecer no ecrã em tempo real.

---

**Para parar o bot:**

Escreve no terminal e prime Enter:

```
stop
```

---

**Para parar o bot à força (se o terminal estiver bloqueado):**

```bash
./stop.sh
```

---

## PARTE 5 — Comandos Durante a Execução

Enquanto o bot está a correr, podes escrever no terminal:

**Ver configurações e mudar:**

```
config
```

**Ver estado actual (hangar, combustível):**

```
status
```

**Parar o bot:**

```
stop
```

---

## PARTE 6 — Multi-Contas

Se tens mais do que uma conta, podes correr o bot para todas ao mesmo tempo.

**Passo 1** — Abre o setup e adiciona cada conta:

```bash
./setup.sh
```

> Repete "2) Adicionar" para cada conta que quiseres.

---

**Passo 2** — Inicia todas as contas de uma vez:

```bash
./play.sh
```

> O bot lança um worker independente por conta.
> Cada conta corre em background, completamente separada.

---

**Passo 3** — Ver o log de uma conta específica:

```bash
tail -f ~/.wartank/USERNAME/bot.log
```

> Substitui `USERNAME` pelo nome da conta que queres ver.

---

**Parar todas as contas:**

```bash
./stop.sh
```

---

## PARTE 7 — Configurações

O ficheiro `config.cfg` é criado automaticamente na primeira execução.
Podes editá-lo directamente ou usar o comando `config` durante a execução.

**Para abrir o ficheiro de configuração:**

```bash
nano config.cfg
```

**O que cada opção faz:**

```
FUNC_battle=y          → Batalha normal (y=activo, n=desactivo)
FUNC_missions=y        → Recolha de missões automática
FUNC_pvp=y             → PvP automático
FUNC_pvp_hour=21       → Hora do PvP (21 = 21h00)
FUNC_pve=y             → PvE — batalhas históricas
FUNC_cw=y              → Guerra de clã
FUNC_dm=y              → Disputa (Deathmatch)
FUNC_convoy=y          → Escolta (comboio inimigo)
FUNC_buildings=y       → Recolha de produção da Base
FUNC_assault=y         → Missão especial
FUNC_company=y         → Missões da Divisão

BATTLE_LA=3            → Segundos entre disparos na batalha
BATTLE_SHOTS=9         → Disparos por sessão (9 = 3 inimigos)
FUEL_MIN=0             → Combustível mínimo para batalhar
```

**Depois de editar, guarda com:**

```
Ctrl + O  →  Enter  →  Ctrl + X
```

---

## PARTE 8 — Ver Logs

**Ver o log em tempo real (single conta):**

```bash
tail -f ~/.wartank/USERNAME/bot.log
```

**Ver as últimas 50 linhas:**

```bash
tail -50 ~/.wartank/USERNAME/bot.log
```

**Pesquisar erros no log:**

```bash
grep "ERRO" ~/.wartank/USERNAME/bot.log
```

---

## PARTE 9 — Resolver Problemas

---

### O bot pede password ao iniciar (AES)

Apaga o ficheiro de credenciais antigo e volta a adicionar a conta:

```bash
rm ~/.wartank/USERNAME/cript_file
```

```bash
./setup.sh
```

---

### "Config não encontrado. A criar..." aparece sempre

O bot não está a encontrar a pasta correcta. Garante que entras sempre na pasta antes de iniciar:

```bash
cd ~/Wartank-Bot
```

```bash
./play.sh
```

---

### O bot não combate

Verifica o log para perceber o que está a acontecer:

```bash
tail -50 ~/.wartank/USERNAME/bot.log
```

Causas mais comuns:
- Combustível insuficiente (precisa de 270 para 9 disparos)
- `FUNC_battle=n` no config.cfg

---

### A sessão expira com frequência

É normal em ligações móveis. O bot reconecta automaticamente.
Se falhar 3 vezes seguidas, para sozinho — volta a iniciar com:

```bash
./play.sh
```

---

### Manter o bot a correr com o ecrã desligado

Usa o comando do Termux para manter o processo activo:

```bash
termux-wake-lock
```

> Corre este comando antes de `./play.sh`.
> Assim o Android não suspende o Termux quando o ecrã apagar.

---

## Resumo Rápido

```
Instalar Termux     → F-Droid
Actualizar          → pkg update && pkg upgrade
Instalar curl/bash  → pkg install curl bash grep
Ir para a pasta     → cd ~/Wartank-Bot
Permissões          → chmod +x *.sh
Adicionar conta     → ./setup.sh
Iniciar             → ./play.sh
Parar               → stop  ou  ./stop.sh
Ver log             → tail -f ~/.wartank/USERNAME/bot.log
```
