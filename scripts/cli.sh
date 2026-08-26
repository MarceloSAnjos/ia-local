#!/usr/bin/env bash
# Multi-Model CLI Wrapper for Local AI Coding Lab
# Usage: ./scripts/cli.sh [command] [args]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "${SCRIPT_DIR}")"

# Available commands
declare -A COMMANDS=(
    ["run"]="Run with selected model"
    ["list-local"]="List local GGUF models"
    ["list-hf"]="List Hugging Face models"
    ["quick"]="Quick run with default settings"
    ["help"]="Show this help"
)

show_usage() {
    cat <<EOF
Multi-Model CLI for Local AI Coding Lab
=======================================

USAGE:
  $0 [command] [args]

COMMANDS:
  $0 run [args]           Run with selected model (interactive)
  $0 list-local           List local GGUF models
  $0 list-hf              List Hugging Face models  
  $0 quick [prompt]       Quick run with default model
  $0 help                 Show this help

RUN ARGUMENTS:
  --system <local|hf>     Inference system (default: local)
  --model <name>          Model name
  --prompt "<text>"       Prompt to send to model
  --ctx <int>             Context size in tokens (local only, default: 32768)

EXAMPLES:
  $0 run                                    # Interactive mode
  $0 list-local
  $0 list-hf
  $0 quick "Implement LRU cache in Python"

See 'python3 ${ROOT_DIR}/scripts/cli.py --help' for more details.
EOF
}

show_help() {
    echo "Multi-Model CLI Wrapper"
    echo ""
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    for cmd in "${!COMMANDS[@]}"; do
        echo "  $0 $cmd    ${COMMANDS[$cmd]}"
    done
    echo ""
    echo "Run this script: $0 help"
}

# Main
if [[ $# -eq 0 ]]; then
    show_help
    exit 0
fi

COMMAND="$1"
shift

case "$COMMAND" in
    run)
        python3 "${SCRIPT_DIR}/cli.py" run "$@"
        ;;
    list-local)
        python3 "${SCRIPT_DIR}/cli.py" --model --list-local
        ;;
    list-hf)
        python3 "${SCRIPT_DIR}/cli.py" --model --list-hf
        ;;
    quick)
        if [[ -n "$1" ]]; then
            python3 "${SCRIPT_DIR}/cli.py" --quick "$1"
        else
            echo "Error: Quick mode requires a prompt"
            exit 1
        fi
        ;;
    help)
        show_help
        ;;
    *)
        echo "Unknown command: $COMMAND"
        echo "Run '$0 help' for available commands"
        exit 1
        ;;
esac
