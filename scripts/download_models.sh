#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
MODELS_DIR="${ROOT_DIR}/models"

mkdir -p "${MODELS_DIR}"

echo "=========================================================="
echo "          Downloading Local AI Coding Models"
echo "=========================================================="

TARGET_URL="https://huggingface.co/unsloth/Qwen3.5-4B-GGUF/resolve/main/Qwen3.5-4B-Q4_K_M.gguf"
DRAFT_URL="https://huggingface.co/unsloth/Qwen3.5-0.8B-GGUF/resolve/main/Qwen3.5-0.8B-Q4_K_M.gguf"

TARGET_FILE="${MODELS_DIR}/target.gguf"
DRAFT_FILE="${MODELS_DIR}/draft.gguf"

# Expected minimum file sizes in bytes (Qwen3.5 4B Q4_K_M ~2.74GB, Qwen3.5 0.8B Q4_K_M ~530MB)
TARGET_MIN_SIZE=2500000000
DRAFT_MIN_SIZE=500000000

download_file() {
    local url="$1"
    local dest="$2"
    local name="$3"
    local min_size="$4"

    local current_size=0
    if [[ -f "${dest}" ]]; then
        current_size=$(stat -c%s "${dest}" 2>/dev/null || stat -f%z "${dest}" 2>/dev/null || echo 0)
    fi

    if [[ ${current_size} -ge ${min_size} ]]; then
        echo "[✓] ${name} already exists ($(du -h "${dest}" | cut -f1)). Skipping download."
    else
        if [[ -f "${dest}" ]]; then
            echo "[*] Existing ${dest} is outdated or incomplete (${current_size} bytes). Re-downloading..."
            rm -f "${dest}"
        fi
        echo "[↓] Downloading ${name} to ${dest}..."
        curl -L -C - --progress-bar "${url}" -o "${dest}"
        echo "[✓] ${name} downloaded successfully ($(du -h "${dest}" | cut -f1))."
    fi
}

download_file "${TARGET_URL}" "${TARGET_FILE}" "Target Model (Qwen3.5-4B Q4_K_M)" "${TARGET_MIN_SIZE}"
download_file "${DRAFT_URL}" "${DRAFT_FILE}" "Draft Model (Qwen3.5-0.8B Q4_K_M)" "${DRAFT_MIN_SIZE}"

echo ""
echo "=========================================================="
echo " Model files are ready in: ${MODELS_DIR}"
echo "=========================================================="
ls -lh "${MODELS_DIR}"
