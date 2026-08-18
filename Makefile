.PHONY: all setup start start-8k start-16k start-32k start-96k start-128k start-spec restart stop status bench test opencode clean help

all: help

help:
	@echo "Local AI Coding Lab - Available Commands:"
	@echo "  make setup          - Complete one-step setup (models, tools, opencode config)"
	@echo "  make start          - Start local LLM server (96K context, GPU Metal acceleration)"
	@echo "  make restart        - Cleanly restart the local server"
	@echo "  make start-128k     - Start server with 128K context"
	@echo "  make start-96k      - Start server with 96K context"
	@echo "  make start-32k      - Start server with 32K context"
	@echo "  make start-16k      - Start server with 16K context"
	@echo "  make start-8k       - Start server with 8K context"
	@echo "  make start-spec     - Start server with Speculative Decoding (Target 4B + Draft 0.8B)"
	@echo "  make stop           - Stop running llama-server"
	@echo "  make status         - Check server status, PID and memory usage"
	@echo "  make opencode       - Start OpenCode interactive coding agent"
	@echo "  make bench          - Run full comparative benchmark (tok/s, TTFT, RAM)"
	@echo "  make test           - Send a test completion to verify OpenAI API compatibility"

setup:
	@./setup.sh

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
	@kill -15 -f llama-server 2>/dev/null || kill -9 -f llama-server 2>/dev/null || true && echo "[✓] llama-server stopped." || echo "[*] llama-server was not running."

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
