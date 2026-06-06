#!/bin/bash
set -e
cd "$(dirname "$0")/../.."

echo "=== Building MoonZod Validator ==="
moon build 2>&1
echo ""

echo "=== Starting Real LLM Agent Demo ==="
echo ""

# Pass through any args (e.g. --mock) to the Python script
if ! python3 examples/real_llm_agent/agent.py "$@"; then
    echo ""
    echo "Hint: If you don't have your own LLM API,"
    echo "see README for a public key or use --mock"
    exit 1
fi
