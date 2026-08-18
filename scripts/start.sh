#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
MODELS_DIR="${ROOT_DIR}/models"

MODE="baseline"
TARGET_MODEL="${MODELS_DIR}/target.gguf"
DRAFT_MODEL="${MODELS_DIR}/draft.gguf"
HOST="127.0.0.1"
PORT="8080"
CONTEXT_SIZE="98304"
GPU_LAYERS="99"
GPU_LAYERS_DRAFT="99"
PARALLEL="1"
DRAFT_MAX="8"
DRAFT_MIN="0"
FLASH_ATTN="on"
QUANT_KV=1
FORCE_RESTART=1

print_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --baseline            Run target model directly (default, fastest on Metal GPU)"
    echo "  --speculative         Run target model with speculative decoding draft model"
    echo "  --target FILE         Path to target GGUF model (default: ./models/target.gguf)"
    echo "  --draft FILE          Path to draft GGUF model (default: ./models/draft.gguf)"
    echo "  --ctx NUM             Context size in tokens (default: 98304 [96K])"
    echo "  --128k                Shortcut for --ctx 131072 (128K context)"
    echo "  --96k                 Shortcut for --ctx 98304  (96K context)"
    echo "  --64k                 Shortcut for --ctx 65536  (64K context)"
    echo "  --32k                 Shortcut for --ctx 32768  (32K context)"
    echo "  --16k                 Shortcut for --ctx 16384  (16K context)"
    echo "  --8k                  Shortcut for --ctx 8192   (8K context)"
    echo "  --quant-kv            Quantize KV cache to Q8_0 (default for 64K+, saves 50% KV RAM)"
    echo "  --no-quant-kv         Disable KV cache quantization (use FP16)"
    echo "  --host HOST           Host IP (default: 127.0.0.1)"
    echo "  --port PORT           Port number (default: 8080)"
    echo "  --no-force            Do not auto-terminate existing process on the same port"
    echo "  -h, --help            Show this help message"
    echo ""
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --baseline|baseline)
            MODE="baseline"
            shift
            ;;
        --speculative|speculative)
            MODE="speculative"
            shift
            ;;
        --target)
            TARGET_MODEL="$2"
            shift 2
            ;;
        --draft)
            DRAFT_MODEL="$2"
            shift 2
            ;;
        --host)
            HOST="$2"
            shift 2
            ;;
        --port)
            PORT="$2"
            shift 2
            ;;
        --ctx)
            CONTEXT_SIZE="$2"
            shift 2
            ;;
        --128k)
            CONTEXT_SIZE="131072"
            shift
            ;;
        --96k)
            CONTEXT_SIZE="98304"
            shift
            ;;
        --64k)
            CONTEXT_SIZE="65536"
            shift
            ;;
        --32k)
            CONTEXT_SIZE="32768"
            shift
            ;;
        --16k)
            CONTEXT_SIZE="16384"
            shift
            ;;
        --8k)
            CONTEXT_SIZE="8192"
            shift
            ;;
        --quant-kv)
            QUANT_KV=1
            shift
            ;;
        --no-quant-kv)
            QUANT_KV=0
            shift
            ;;
        --no-force)
            FORCE_RESTART=0
            shift
            ;;
        --draft-max)
            DRAFT_MAX="$2"
            shift 2
            ;;
        --draft-min)
            DRAFT_MIN="$2"
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

if [[ ! -f "${TARGET_MODEL}" ]]; then
    echo "[!] Target model not found at '${TARGET_MODEL}'."
    echo "    Run ./setup.sh or ./scripts/download_models.sh first."
    exit 1
fi

if [[ "${MODE}" == "speculative" && ! -f "${DRAFT_MODEL}" ]]; then
    echo "[!] Draft model not found at '${DRAFT_MODEL}'."
    echo "    Run ./setup.sh or ./scripts/download_models.sh first."
    exit 1
fi

# Check if port is already in use (cross-platform: lsof on macOS, fuser or process pattern on Linux)
EXISTING_PID=""
if command -v lsof >/dev/null 2>&1; then
    # macOS
    EXISTING_PID=$(lsof -ti ":${PORT}" 2>/dev/null || true)
elif command -v fuser >/dev/null 2>&1; then
    # Linux with fuser
    EXISTING_PID=$(fuser -n tcp "${PORT}" 2>/dev/null | head -n 1 || true)
else
    # Linux: find process by pattern
    EXISTING_PID=$(pgrep -f "llama-server.*:${PORT}" 2>/dev/null || true)
fi

if [[ -n "${EXISTING_PID}" ]]; then
    if [[ ${FORCE_RESTART} -eq 1 ]]; then
        echo "[*] Port ${PORT} is currently in use (PID: ${EXISTING_PID}). Restarting server..."
        kill -9 "${EXISTING_PID}" 2>/dev/null || true
        sleep 1
    else
        echo "[!] Port ${PORT} is already in use by PID ${EXISTING_PID}."
        echo "    Run 'make stop' or remove the process first."
        exit 1
    fi
fi

echo "=========================================================="
echo "          Starting llama-server on Apple Silicon"
echo "=========================================================="
echo "Mode:             ${MODE}"
echo "Target Model:     ${TARGET_MODEL}"
[[ "${MODE}" == "speculative" ]] && echo "Draft Model:      ${DRAFT_MODEL}"
echo "Context Size:     ${CONTEXT_SIZE} tokens"
echo "KV Cache Quant:   $([[ ${QUANT_KV} -eq 1 ]] && echo 'Enabled (Q8_0)' || echo 'Standard (FP16)')"
echo "Host & Port:      http://${HOST}:${PORT}"
echo "Flash Attention:  ${FLASH_ATTN}"
echo "=========================================================="

CMD=(
    llama-server
    -m "${TARGET_MODEL}"
    -c "${CONTEXT_SIZE}"
    -ngl "${GPU_LAYERS}"
    -np "${PARALLEL}"
    -fa "${FLASH_ATTN}"
    --jinja
    --host "${HOST}"
    --port "${PORT}"
)

if [[ ${QUANT_KV} -eq 1 ]]; then
    CMD+=(
        -ctk q8_0
        -ctv q8_0
    )
fi

if [[ "${MODE}" == "speculative" ]]; then
    CMD+=(
        -md "${DRAFT_MODEL}"
        -ngld "${GPU_LAYERS_DRAFT}"
        --spec-draft-n-max "${DRAFT_MAX}"
        --spec-draft-n-min "${DRAFT_MIN}"
    )
fi

exec "${CMD[@]}"
