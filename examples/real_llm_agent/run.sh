#!/bin/bash
set -e
cd "$(dirname "$0")/../.."

echo "=== Building MoonZod Validator ==="
moon build 2>&1
echo ""

echo "=== Starting Real LLM Agent Demo ==="
echo ""

# Examples:
#   bash run.sh product --mock
#   bash run.sh product --mode tool --mock
#   bash run.sh product

if ! python3 examples/real_llm_agent/agent.py "$@"; then
    echo ""
    echo "Hint: If you don't have your own LLM API,"
    echo "see README for a public key or use --mock"
    exit 1
fi
