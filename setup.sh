#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${SCRIPT_DIR}"

echo "=========================================================="
echo "    Local AI Coding Lab - Automated One-Step Setup"
echo "=========================================================="
echo ""

# 1. Check & Validate System Tools
echo "[1/4] Checking system prerequisites..."
if ! command -v brew >/dev/null 2>&1; then
    echo "[!] Homebrew is not installed. Please install Homebrew first: https://brew.sh"
    exit 1
fi

if ! command -v llama-server >/dev/null 2>&1; then
    echo "[*] llama.cpp not found. Installing via Homebrew..."
    brew install llama.cpp
else
    echo "[✓] llama.cpp is installed ($(llama-server --version 2>/dev/null | head -n 1 || echo 'ready'))"
fi

if ! command -v opencode >/dev/null 2>&1; then
    echo "[*] OpenCode CLI not found. Installing via Homebrew/npm..."
    if command -v npm >/dev/null 2>&1; then
        npm install -g opencode-ai 2>/dev/null || brew install sst/tap/opencode || echo "[!] Could not auto-install OpenCode. Please install manually if needed."
    fi
else
    echo "[✓] OpenCode CLI is installed ($(opencode --version 2>/dev/null || echo 'ready'))"
fi

if ! command -v python3 >/dev/null 2>&1; then
    echo "[!] Python 3 is required."
    exit 1
fi
echo "[✓] Python 3 is ready"

# 2. Download Models
echo ""
echo "[2/4] Verifying and downloading local models (GGUF Q4_K_M)..."
"${ROOT_DIR}/scripts/download_models.sh"

# 3. Configure OpenCode
echo ""
echo "[3/4] Configuring OpenCode to use local llama-server..."
OPENCODE_DIR="${HOME}/.config/opencode"
mkdir -p "${OPENCODE_DIR}"

python3 -c '
import json, os

config_path = os.path.expanduser("~/.config/opencode/opencode.jsonc")
config = {
  "$schema": "https://opencode.ai/config.json",
  "model": "local/qwen3.5-4b",
  "provider": {
    "local": {
      "name": "Local LLM (llama-server Metal GPU)",
      "npm": "@ai-sdk/openai-compatible",
      "options": {
        "baseURL": "http://127.0.0.1:8080/v1",
        "apiKey": "not-needed"
      },
      "models": {
        "qwen3.5-4b": {
          "name": "Qwen 3.5 4B",
          "tool_call": True,
          "limit": {
            "context": 98304,
            "output": 8192
          }
        },
        "qwen3.5-0.8b": {
          "name": "Qwen 3.5 0.8B",
          "tool_call": True,
          "limit": {
            "context": 8192,
            "output": 4096
          }
        }
      }
    }
  }
}

with open(config_path, "w") as f:
    json.dump(config, f, indent=2)

print("[✓] OpenCode configuration saved to " + config_path)
'

# Also create project-level opencode.jsonc
cp "${HOME}/.config/opencode/opencode.jsonc" "${ROOT_DIR}/opencode.jsonc"
echo "[✓] Project-level opencode.jsonc updated."

# 4. Make all scripts executable
echo ""
echo "[4/4] Setting execution permissions..."
chmod +x "${ROOT_DIR}/scripts/"*
chmod +x "${ROOT_DIR}/setup.sh" 2>/dev/null || true

echo ""
echo "=========================================================="
echo "               Setup Completed Successfully! 🎉"
echo "=========================================================="
echo ""
echo "Quick Commands:"
echo "  1. Iniciar servidor com contexto de 32K (Recomendado):"
echo "     make start"
echo "     (ou: ./scripts/start.sh --ctx 32768)"
echo ""
echo "  2. Abrir o OpenCode para programar:"
echo "     make opencode"
echo "     (ou: opencode)"
echo ""
echo "  3. Rodar benchmark de performance:"
echo "     make bench"
echo ""
echo "  4. Parar o servidor:"
echo "     make stop"
echo "=========================================================="
