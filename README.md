# Local AI Coding Lab 🚀

Ambiente local de IA Coding para Apple Silicon, otimizado para rodar com **Docker simultaneamente**, **contexto de 32K+**, suporte a **Metal GPU**, **Speculative Decoding** e integração total com o **OpenCode** e IDEs compatíveis com OpenAI.

**Multi-Model Support**: Agora suporta modelos locais GGUF (via OpenCode/Metal GPU) ou modelos do Hugging Face (API direta).

---

## ⚡ Setup Simplificado (1 Comando)

Para configurar tudo automaticamente (verificação de ferramentas, download dos modelos GGUF e configuração do OpenCode):

```bash
make setup
# ou: ./setup.sh
```

---

## 🤖 Multi-Model CLI - Escolha seu Modelo

O novo CLI permite escolher entre sistemas de inferência e modelos diferentes:

### Sistema de Inferência

1. **Local (GGUF) + OpenCode**
   - ✅ Metal GPU acceleration
   - ✅ Otimizado para Apple Silicon
   - ✅ Alta performance com Speculative Decoding
   - ❌ Requer servidor local rodando

2. **Hugging Face (API)**
   - ✅ Acesso a milhares de modelos
   - ✅ Sem necessidade de configurar servidor
   - ❌ Mais lento (API overhead)
   - ❌ Sem GPU acceleration

### Comandos Disponíveis

| Comando | Descrição |
| :--- | :--- |
| `make multi-model` | Abre CLI interativo para escolher sistema e modelo |
| `make list-local` | Lista modelos GGUF locais disponíveis |
| `make list-hf` | Lista modelos do Hugging Face |
| `make quick "<prompt>"` | Executa prompt rápido com modelo padrão |

### Exemplos de Uso

```bash
# Modo interativo - escolha sistema e modelo
make multi-model

# Listar modelos locais
make list-local

# Listar modelos Hugging Face
make list-hf

# Executar prompt rápido com modelo local
make quick "Implementa uma função de busca binária em Python"

# Executar prompt rápido com Hugging Face
make quick --system hf "microsoft/phi-3-mini-instruct" "Write a Go struct"

# Com contexto personalizado
make quick --ctx 131072 "Tarefa de contexto longo"
```

### CLI Options

```bash
# Python CLI directly
python3 scripts/cli.py run --system local --model Qwen/Qwen2.5-3B-Instruct "Prompt aqui"
python3 scripts/cli.py run --system hf --model microsoft/phi-3-mini-instruct "Prompt aqui"
python3 scripts/cli.py quick "Implement LRU cache in Python"
```

### Modelos Disponíveis

#### Modelos Locais (GGUF)

O setup automatico baixa:
- `Qwen3.5-4B-Q4_K_M.gguf` (~2.7 GB) - Modelo principal
- `Qwen3.5-0.8B-Q4_K_M.gguf` (~532 MB) - Modelo rápido (draft)

Baixe mais modelos:
```bash
./scripts/download_models.sh
# ou manualmente via Hugging Face CLI
huggingface-cli download unsloth/Qwen3.5-4B-GGUF --local-dir ./models
```

#### Modelos Hugging Face (Exemplos)

- **Pequenos/Rápidos**: Qwen2.5-0.5B, 1.5B, 3B
- **Equilibrados**: Qwen2.5-7B, 14B, 32B
- **Long Context**: phi-3-mini-instruct (128K context), phi-3-medium-instruct

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
| **`make multi-model`** | **Novo:** CLI interativo para escolher modelo |
| **`make list-local`** | **Novo:** Lista modelos GGUF locais |
| **`make list-hf`** | **Novo:** Lista modelos Hugging Face |
| **`make quick "<prompt>"`** | **Novo:** Executa prompt rápido com modelo padrão |

---

## 🧠 Ajustando o Tamanho do Contexto

O **Qwen3.5-4B** suporta janelas ultra-longas de contexto (nativamente até 256K). A quantização de KV Cache (`Q8_0`) vem ativada por padrão para janelas a partir de 64K:

```bash
# Iniciar com 96K (padrão do make start, >90K de contexto)
./scripts/start.sh --96k

# Iniciar com 128K
./scripts/start.sh --128k

# Com CLI
make quick --ctx 131072 "Tarefa de contexto longo"
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

Exemplo para Continue:
```json
{
  "provider": "local",
  "model": "local/qwen3.5-4b",
  "baseURL": "http://127.0.0.1:8080/v1",
  "apiKey": "not-needed"
}
```

---

## 📊 Performance

Benchmarks típicos com Qwen3.5-4B (96K context, Metal GPU):

| Métrica | Baseline | Speculative (0.8B draft) |
|---------|----------|--------------------------|
| TTFT (Time to First Token) | 150-300 ms | 80-150 ms |
| Generation Speed | 35-45 tok/s | 80-120 tok/s |
| Memory (RAM) | ~4.8 GB total | ~3.5 GB total |
| Context | 96K | 96K |

Rodar benchmarks:
```bash
make bench
```

---

## 📁 Estrutura do Projeto

```
.
├── scripts/
│   ├── cli.py              # CLI multi-modelo (Python)
│   ├── cli.sh              # Wrapper bash para CLI
│   ├── start.sh            # Inicia llama-server
│   ├── benchmark.sh        # Roda benchmarks
│   ├── status.sh           # Verifica status do servidor
│   └── download_models.sh  # Download de modelos GGUF
├── models/
│   ├── target.gguf         # Modelo principal (Qwen3.5-4B)
│   └── draft.gguf          # Modelo de draft (Qwen3.5-0.8B)
├── config.yaml             # Configurações YAML
├── opencode.jsonc          # Configuração do OpenCode
├── README.md               # Este arquivo
└── Makefile                # Scripts make
```

---

## 🔧 Configuração Avançada

### Editar Configuração

Edite `config.yaml` para customizar:
- Modelos locais
- Tamanho de contexto
- Parâmetros de sampling
- Configuração do OpenCode

### Download Manual de Modelos

```bash
# Download automático
./scripts/download_models.sh

# Download específico do Hugging Face
huggingface-cli download unsloth/Qwen3.5-4B-GGUF --local-dir ./models

# Ver lista de modelos
huggingface-cli list --library Qwen
```

---

## 🆘 Troubleshooting

### Servidor não inicia
```bash
# Verificar logs
./scripts/start.sh --debug

# Verificar espaço em disco
df -h

# Verificar RAM disponível
free -h
```

### Modelo não encontrado
```bash
# Verificar modelos instalados
make list-local

# Re-instalar
./scripts/download_models.sh
```

### Lento com Hugging Face
- Use modelos menores (3B ou menos)
- Configure cache de Hugging Face: `HF_HOME=$HOME/.cache/huggingface`
- Use modelo local se possível

---

## 📚 Recursos

- [llama.cpp Documentation](https://github.com/ggerganov/llama.cpp)
- [Hugging Face Inference API](https://huggingface.co/docs/api-inference/index)
- [Qwen Model Hub](https://huggingface.co/Qwen)
- [OpenCode Documentation](https://opencode.ai)

---

## 📝 Licença

MIT License - veja arquivo LICENSE para detalhes.
