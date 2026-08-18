# Local AI Coding Lab 🚀

Ambiente local de AI Coding para Apple Silicon, otimizado para rodar com **Docker simultaneamente**, **contexto de 32K**, suporte a **Metal GPU**, **Speculative Decoding** e integração total com o **OpenCode** e IDEs compatíveis com OpenAI.

---

## ⚡ Setup Simplificado (1 Comando)

Para configurar tudo automaticamente (verificação de ferramentas, download dos modelos GGUF e configuração do OpenCode):

```bash
make setup
# ou: ./setup.sh
```

---

## 🛠️ Comandos do Dia a Dia (`Makefile`)

| Comando | Descrição |
| :--- | :--- |
| **`make start`** | Inicia o servidor local com **96K de contexto** (atende a >90K) |
| **`make start-128k`** | Inicia o servidor local com **128K de contexto** |
| **`make start-96k`** | Inicia o servidor local com **96K de contexto** |
| **`make start-32k`** | Inicia o servidor local com **32K de contexto** |
| **`make opencode`** | Abre o terminal interativo do **OpenCode** conectado ao modelo local |
| **`make status`** | Mostra se o servidor está ativo, PID e consumo de memória RAM |
| **`make stop`** | Finaliza o servidor `llama-server` |
| **`make bench`** | Executa bateria de benchmarks (Baseline vs Speculative) |
| **`make test`** | Envia um prompt de teste para validar a API OpenAI |

---

## 🧠 Ajustando o Tamanho do Contexto

O **Qwen3.5-4B** suporta janelas ultra-longas de contexto (nativamente até 256K). A quantização de KV Cache (`Q8_0`) vem ativada por padrão para janelas a partir de 64K:

```bash
# Iniciar com 96K (padrão do make start, >90K de contexto)
./scripts/start.sh --96k

# Iniciar com 128K
./scripts/start.sh --128k

# Iniciar com 32K
./scripts/start.sh --32k

# Iniciar com 16K
./scripts/start.sh --16k

# Iniciar com 8K
./scripts/start.sh --8k
```

### Memória e Coexistência com Docker (16 GB total no MacBook):
- **8K Contexto:** ~3.0 GB RAM total | **~13.0 GB livres**
- **16K Contexto:** ~3.3 GB RAM total | **~12.7 GB livres**
- **32K Contexto:** ~3.8 GB RAM total | **~12.2 GB livres**
- **96K Contexto (Recomendado):** ~4.8 GB RAM total | **~11.2 GB livres** (amplo espaço para Docker + macOS)
- **128K Contexto:** ~5.5 GB RAM total | **~10.5 GB livres**

---

## 💻 Como Codar com o OpenCode

Com o servidor rodando (`make start`), basta rodar no terminal do seu projeto:

```bash
opencode
```

Ou rodar um comando direto:
```bash
opencode run "Crie um endpoint em Node.js com Express para autenticação JWT"
```

O OpenCode já está configurado globalmente em `~/.config/opencode/opencode.jsonc` e localmente neste repositório apontando para `local/qwen3.5-4b`.

---

## 🔌 Integração com Outras Ferramentas (Continue, Cline, Cursor, Aider)

Endpoint compatível com OpenAI:
- **Base URL:** `http://127.0.0.1:8080/v1`
- **Model:** `default` (ou `qwen3.5-4b`)
- **API Key:** `not-needed`
