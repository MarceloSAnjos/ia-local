.PHONY: all setup start start-8k start-16k start-32k start-96k start-128k start-spec restart stop status bench test opencode clean help multi-model cli list-local list-hf quick

all: help

help:
	@echo "Local AI Coding Lab - Available Commands:"
	@echo "  make setup          - Complete one-step setup (models, tools, opencode config)"
	@echo "  make setup-all      - Complete setup: models, tools, opencode, start server"
	@echo ""
	@echo "  ======================= MULTI-MODEL ========================="
	@echo "  make multi-model     - Run multi-model CLI (interactive)"
	@echo "  make cli             - Run multi-model CLI (interactive)"
	@echo "  make list-local      - List local GGUF models"
	@echo "  make list-hf         - List Hugging Face models"
	@echo "  make quick <prompt>  - Quick run with default model"
	@echo "  make help            - Show all available commands"
	@echo ""
	@echo "  ==================== LOCAL SERVER =========================="
	@echo "  make start          - Start local LLM server (96K context)"
	@echo "  make stop           - Stop running llama-server"
	@echo "  make status         - Check server status"
	@echo "  make opencode       - Start OpenCode interactive coding agent"
	@echo "  make bench          - Run performance benchmark"
	@echo "  make test           - Test OpenAI API compatibility"

setup:
	@./setup.sh

multi-model:
	@./scripts/cli.py run

cli:
	@./scripts/cli.py run

list-local:
	@./scripts/cli.py --list-local

list-hf:
	@./scripts/cli.py --list-hf

quick:
	@./scripts/cli.py "$@"

start:
	@./scripts/start.sh --baseline --ctx 98304

restart: stop start

start-128k:
	@./scripts/start.sh --baseline --ctx 131072

start-96k:
	@./scripts/start.sh --baseline --ctx 98304

start-32k:
	@./scripts/start.sh --baseline --ctx 32768

start-16k:
	@./scripts/start.sh --baseline --ctx 16384

start-8k:
	@./scripts/start.sh --baseline --ctx 8192

start-spec:
	@./scripts/start.sh --speculative --ctx 32768

stop:
	@pkill -15 -f llama-server 2>/dev/null || pkill -9 -f llama-server 2>/dev/null || true && echo "[✓] llama-server stopped." || echo "[*] llama-server was not running."

status:
	@./scripts/status.sh

opencode:
	@opencode

bench:
	@./scripts/benchmark.sh --compare

test:
	@curl -s http://127.0.0.1:8080/v1/chat/completions \
		-H "Content-Type: application/json" \
		-d '{"messages":[{"role":"user","content":"Implement binary search in Python."}],"temperature":0.2,"max_tokens":100}' \
		| python3 -m json.tool || echo "[!] Could not reach server. Run 'make start' first."
