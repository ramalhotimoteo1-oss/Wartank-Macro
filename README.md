# Wartank-Macro

Bot automático para **wartank-pt.net** — corre no Android via **Termux**.

Automatiza batalhas, missões, PvP, PvE, guerra de clã, disputa, escolta, base, divisão e missão especial (Assault).

---

## Índice

1. [Instalar o Termux](#1--instalar-o-termux)
2. [Instalar o Bot](#2--instalar-o-bot)
3. [Configurar a Conta](#3--configurar-a-conta)
4. [Iniciar e Parar](#4--iniciar-e-parar)
5. [Comandos em execução](#5--comandos-em-execução)
6. [Configurações](#6--configurações)
7. [Logs](#7--logs)
8. [Manter o bot activo](#8--manter-o-bot-activo)
9. [Actualizar o Bot](#9--actualizar-o-bot)
10. [Mudar de conta](#10--mudar-de-conta)
11. [Multi-contas](#11--multi-contas-em-desenvolvimento)
12. [Resolver problemas](#12--resolver-problemas)
13. [Resumo rápido](#13--resumo-rápido)
14. [Doações](#14--doações)

---

## 1 — Instalar o Termux

O Termux é um terminal Linux para Android. O bot corre dentro dele.

**Importante:** instala pela **F-Droid**, não pela Play Store.

```
https://f-droid.org/packages/com.termux/
```

Depois de instalar, abre o Termux e actualiza:

```bash
pkg update && pkg upgrade -y
```

Instala as dependências:

```bash
pkg install git curl bash
```

Confirma:

```bash
curl --version && bash --version && git --version
```

Se aparecerem versões sem erros, está pronto.

---

## 2 — Instalar o Bot

```bash
cd ~
```

```bash
git clone https://github.com/ramalhotimoteo1-oss/Wartank-Macro.git
```

```bash
cd ~/Wartank-Macro
```

```bash
chmod +x *.sh
```

Confirma os ficheiros:

```bash
ls
```

Deves ver, entre outros: `play.sh`, `wartank.sh`, `core.sh`, `login.sh`, `run.sh`, `assault.sh`, etc.

---

## 3 — Configurar a Conta

Na **primeira execução**, o bot pede username e password no terminal.

```bash
./play.sh
```

A password não aparece enquanto escreves — é normal e seguro.  
As credenciais ficam guardadas em `.tmp/cript_file` (permissões restritas).

> **Nota:** o ficheiro `setup.sh` existe no projecto para a gestão de contas no futuro sistema multi-contas (ver secção 11). Na versão actual (single-conta), o login é feito directamente ao iniciar o bot.

---

## 4 — Iniciar e Parar

**Iniciar:**

```bash
cd ~/Wartank-Macro
./play.sh
```

**Parar** (escreve no terminal enquanto o bot corre):

```
stop
```

**Parar à força:**

```bash
./stop.sh
```

---

## 5 — Comandos em execução

Enquanto o bot está a correr, podes escrever no terminal:

| Comando   | Acção                    |
|-----------|--------------------------|
| `stop`    | Para o bot               |
| `config`  | Abre o menu de opções    |
| `status`  | Mostra o painel do hangar|

---

## 6 — Configurações

O ficheiro `config.cfg` é criado automaticamente na primeira execução.

**Editar:**

```bash
nano config.cfg
```

**Opções principais:**

```
FUNC_battle=y          → Batalha normal
FUNC_missions=y        → Recolha de missões
FUNC_pvp=y             → PvP
FUNC_pvp_hour=21       → Referência de hora PvP (horários reais: 05:23, 11:23, 21:23)
FUNC_pve=y             → Batalhas históricas
FUNC_cw=y              → Guerra de clã
FUNC_dm=y              → Disputa (Deathmatch)
FUNC_convoy=y          → Escolta
FUNC_buildings=y       → Recolha da Base
FUNC_assault=y         → Missão especial (Abrigo)
FUNC_company=y         → Missões da Divisão

BATTLE_LA=3            → Segundos entre disparos (batalha normal)
BATTLE_SHOTS=9         → Disparos por sessão (9 = 3 inimigos)
FUEL_MIN=0             → Combustível mínimo
ASSAULT_MIN_MEMBERS=1  → Membros mínimos para iniciar o Assault
```

**Guardar no nano:** `Ctrl+O` → Enter → `Ctrl+X`

Também podes usar o comando `config` enquanto o bot corre.

---

## 7 — Logs

**Em tempo real:**

```bash
tail -f ~/Wartank-Macro/.tmp/bot.log
```

**Últimas 50 linhas:**

```bash
tail -50 ~/Wartank-Macro/.tmp/bot.log
```

**Procurar erros:**

```bash
grep "ERRO" ~/Wartank-Macro/.tmp/bot.log
```

---

## 8 — Manter o bot activo

Para o Android não suspender o Termux com o ecrã desligado:

```bash
termux-wake-lock
```

Corre este comando **antes** de `./play.sh`.

---

## 9 — Actualizar o Bot

```bash
cd ~/Wartank-Macro
```

```bash
git pull
```

```bash
chmod +x *.sh
```

Reinicia o bot depois de actualizar:

```bash
./play.sh
```

---

## 10 — Mudar de conta

Apaga as credenciais e cookies da conta actual:

```bash
rm -f ~/Wartank-Macro/.tmp/cript_file
rm -f ~/Wartank-Macro/.tmp/cookies.txt
```

Inicia de novo — o bot pede a nova conta:

```bash
./play.sh
```

---

## 11 — Multi-contas (em desenvolvimento)

O suporte a **várias contas em paralelo** é um projecto **viável e planeado**, mas ainda **em desenvolvimento**.

Por isso existe (ou existirá) o `setup.sh` no repositório: serve para gerir várias contas (adicionar, listar, remover) quando o modo multi-contas estiver estável.

**Estado actual:**
- Single-conta: **funcional** (`./play.sh`)
- Multi-contas: **em desenvolvimento** — não uses como funcionalidade pronta

Quando estiver pronto, a documentação desta secção será actualizada com os comandos exactos.

---

## 12 — Resolver problemas

### Bot fica na mesma conta mesmo apagando credenciais

Apaga **os dois** ficheiros:

```bash
rm -f ~/Wartank-Macro/.tmp/cript_file
rm -f ~/Wartank-Macro/.tmp/cookies.txt
```

### "Config não encontrado" em loop

Garante que entras na pasta correcta antes de iniciar:

```bash
cd ~/Wartank-Macro
./play.sh
```

### Bot não combate

```bash
tail -50 ~/Wartank-Macro/.tmp/bot.log
```

Causas comuns:
- Combustível abaixo de ~90 (mínimo para batalha normal)
- `FUNC_battle=n` no `config.cfg`

### Sessão expira com frequência

Normal em redes móveis — o bot tenta reconectar sozinho.  
Se falhar 3 vezes seguidas, para e reinicia com `./play.sh`.

### Pasta errada / clone duplicado

```bash
cd ~
rm -rf Wartank-Macro
git clone https://github.com/ramalhotimoteo1-oss/Wartank-Macro.git
cd ~/Wartank-Macro
chmod +x *.sh
```

---

## 13 — Resumo rápido

| O que fazer              | Comando                                      |
|--------------------------|----------------------------------------------|
| Actualizar Termux        | `pkg update && pkg upgrade -y`               |
| Instalar dependências    | `pkg install git curl bash`                  |
| Clonar o bot             | `git clone https://github.com/ramalhotimoteo1-oss/Wartank-Macro.git` |
| Entrar na pasta          | `cd ~/Wartank-Macro`                         |
| Permissões               | `chmod +x *.sh`                              |
| Iniciar                  | `./play.sh`                                  |
| Parar                    | escreve `stop`                               |
| Parar à força            | `./stop.sh`                                  |
| Ver log                  | `tail -f .tmp/bot.log`                       |
| Wake lock                | `termux-wake-lock`                           |
| Actualizar bot           | `git pull && chmod +x *.sh`                  |

---

## 14 — Doações

Se o bot te for útil e quiseres apoiar o desenvolvimento:

**PayPal / contacto:** `ramirosh015@gmail.com`

Obrigado a quem contribui — ajuda a manter o projecto activo e a evoluir funcionalidades como o multi-contas.

---

**Repositório:** [github.com/ramalhotimoteo1-oss/Wartank-Macro](https://github.com/ramalhotimoteo1-oss/Wartank-Macro)
