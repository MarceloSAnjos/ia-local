#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

HOST="127.0.0.1"
PORT="8080"
RUNS="2"
MODE="compare"

print_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --baseline       Run baseline benchmark only (server must be running or will be tested)"
    echo "  --speculative    Run speculative decoding benchmark only"
    echo "  --compare        Full comparison: runs both modes sequentially and creates comparison report"
    echo "  --runs NUM       Number of runs per prompt (default: 2)"
    echo "  --port PORT      Port number (default: 8080)"
    echo "  -h, --help       Show this help message"
    echo ""
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --baseline)
            MODE="baseline"
            shift
            ;;
        --speculative)
            MODE="speculative"
            shift
            ;;
        --compare)
            MODE="compare"
            shift
            ;;
        --runs)
            RUNS="$2"
            shift 2
            ;;
        --port)
            PORT="$2"
            shift 2
            ;;
        -h|--help)
            print_usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            print_usage
            exit 1
            ;;
    esac
done

run_automated_mode() {
    local target_mode="$1"
    echo ""
    echo "=========================================================="
    local upper_mode
    upper_mode=$(echo "${target_mode}" | tr '[:lower:]' '[:upper:]')
    echo " Starting Server for [${upper_mode}] benchmark..."
    echo "=========================================================="

    # Kill any existing llama-server (cross-platform: use kill -15 on Linux, -9 on macOS)
    kill -15 -f llama-server 2>/dev/null || kill -9 -f llama-server 2>/dev/null || true
    sleep 2

    # Launch server in background
    if [[ "${target_mode}" == "baseline" ]]; then
        "${SCRIPT_DIR}/start.sh" --baseline --port "${PORT}" > /tmp/llama_server_baseline.log 2>&1 &
    else
        "${SCRIPT_DIR}/start.sh" --speculative --port "${PORT}" > /tmp/llama_server_spec.log 2>&1 &
    fi
    SERVER_PID=$!

    # Wait for server readiness
    echo "[*] Waiting for llama-server to initialize (PID: ${SERVER_PID})..."
    local retries=30
    local ready=0
    for ((i=1; i<=retries; i++)); do
        if curl -s "http://${HOST}:${PORT}/health" >/dev/null 2>&1; then
            ready=1
            echo "[✓] Server is ready!"
            break
        fi
        sleep 2
    done

    if [[ ${ready} -eq 0 ]]; then
        echo "[!] Server failed to start within timeout. Check logs:"
        tail -n 20 "/tmp/llama_server_${target_mode}.log" 2>/dev/null || true
        kill -9 "${SERVER_PID}" 2>/dev/null || true
        exit 1
    fi

    # Run python benchmark runner
    python3 "${SCRIPT_DIR}/runner.py" --mode "${target_mode}" --host "${HOST}" --port "${PORT}" --runs "${RUNS}"

    # Terminate server
    echo "[*] Stopping server (PID: ${SERVER_PID})..."
    kill -TERM "${SERVER_PID}" 2>/dev/null || true
    sleep 2
}

if [[ "${MODE}" == "compare" ]]; then
    echo "=========================================================="
    echo " Running Full Comparative Benchmark: Baseline vs Speculative"
    echo "=========================================================="
    run_automated_mode "baseline"
    run_automated_mode "speculative"

    # Generate comparison report
    python3 -c "
import json, os

base_file = '${ROOT_DIR}/benchmarks/baseline/latest.json'
spec_file = '${ROOT_DIR}/benchmarks/speculative/latest.json'

if os.path.exists(base_file) and os.path.exists(spec_file):
    with open(base_file) as f: b = json.load(f)
    with open(spec_file) as f: s = json.load(f)

    b_speed = b['overall_avg_tok_s']
    s_speed = s['overall_avg_tok_s']
    speedup = round(((s_speed - b_speed) / b_speed) * 100, 1) if b_speed > 0 else 0

    print('\n' + '='*60)
    print(' FINAL COMPARATIVE SUMMARY')
    print('='*60)
    print(f'Baseline (Target only):        {b_speed} tok/s | RAM: {b[\"peak_ram_mb\"]} MB | TTFT: {b[\"overall_avg_ttft_ms\"]} ms')
    print(f'Speculative (Target + Draft):  {s_speed} tok/s | RAM: {s[\"peak_ram_mb\"]} MB | TTFT: {s[\"overall_avg_ttft_ms\"]} ms')
    print(f'Net Improvement:              +{speedup}% speedup')
    print('='*60 + '\n')
"
else
    # If server is already running, test directly, otherwise run automated lifecycle
    if curl -s "http://${HOST}:${PORT}/health" >/dev/null 2>&1; then
        echo "[*] Using existing server running on port ${PORT}..."
        python3 "${SCRIPT_DIR}/runner.py" --mode "${MODE}" --host "${HOST}" --port "${PORT}" --runs "${RUNS}"
    else
        run_automated_mode "${MODE}"
    fi
fi
