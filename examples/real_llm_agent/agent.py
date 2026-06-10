#!/usr/bin/env python3
"""
Real LLM Agent — Python Entry Point

Usage:
    python3 agent.py <case> [--mode prompt|tool] [--mock] [--moon-prompt]

Modes:
    prompt   Self-correction loop (default): LLM generates text,
             moon_zod validates, loop fixes errors.
    tool     OpenAI tool calling / structured outputs: schema passed
             via tools parameter, guaranteed valid JSON.

Options:
    --mock, -m         Use mock data (no API key needed)
    --moon-prompt, -p  Use moon_zod schema_to_prompt() for the
                       initial prompt (TS-interface style) instead
                       of raw JSON Schema

Cases:
    product  Product listing schema demo

Examples:
    python3 agent.py product --mock
    python3 agent.py product --mock --moon-prompt
    OPENAI_API_KEY=sk-... python3 agent.py product --moon-prompt
    OPENAI_API_KEY=sk-... python3 agent.py product --mode tool
"""

import os
import sys

from core import (
    fetch_schema,
    fetch_moon_prompt,
    run_prompt_mode,
    run_tool_mode,
)


# ── case registry ─────────────────────────────────────────────────────

def _load_case(name: str):
    """Import a case module by name."""
    import importlib
    try:
        return importlib.import_module(f"cases.{name}")
    except ModuleNotFoundError:
        print(f"Error: unknown case {name!r}")
        print(f"Available cases: product")
        sys.exit(1)


# ── main ──────────────────────────────────────────────────────────────

def main():
    # parse positional
    if len(sys.argv) < 2 or sys.argv[1].startswith("--"):
        print(__doc__)
        sys.exit(1)

    case_name = sys.argv[1]

    # parse optional flags
    mode = "prompt"
    is_mock = False
    use_moon_prompt = False
    for arg in sys.argv[2:]:
        if arg == "--mock":
            is_mock = True
        elif arg in ("--moon-prompt", "-p"):
            use_moon_prompt = True
        elif arg == "--mode" or arg == "-m":
            pass  # handled below with next arg
        elif arg in ("prompt", "tool"):
            mode = arg

    # also accept --mode <value>
    for i, arg in enumerate(sys.argv[2:], start=2):
        if arg == "--mode" and i + 1 < len(sys.argv):
            mode = sys.argv[i + 1]
            break

    case = _load_case(case_name)

    api_key = os.getenv("OPENAI_API_KEY", "")
    api_url = os.getenv("OPENAI_API_URL", "")
    model = os.getenv("OPENAI_API_MODEL", "")

    if not is_mock and not api_key:
        print("Error: OPENAI_API_KEY not set.")
        print()
        print("  Set it and try again:")
        print("    OPENAI_API_KEY=sk-... python3 agent.py product")
        print()
        print("  Or use mock mode (no API key needed):")
        print("    python3 agent.py product --mock")
        sys.exit(1)

    print("╔══════════════════════════════════════════════════════════╗")
    print(f"║  Real LLM Agent — {case_name} ({mode} mode)")
    print("╚══════════════════════════════════════════════════════════╝")
    print()

    print(f"  Fetching schema for {case_name!r}...")
    schema_json = fetch_schema(case.SCHEMA_NAME)
    print(f"  Schema loaded ({len(schema_json.get('properties', {}))} fields)")

    if use_moon_prompt:
        moon_prompt = fetch_moon_prompt(case.SCHEMA_NAME)
        print(f"  Schema-to-Prompt (TS interface):")
        for line in moon_prompt.split("\n"):
            print(f"    {line}")
    print()

    if mode == "tool":
        run_tool_mode(
            case, schema_json,
            api_key=api_key, api_url=api_url, model=model,
            mock=is_mock,
        )
    else:
        run_prompt_mode(
            case, schema_json,
            api_key=api_key, api_url=api_url, model=model,
            mock=is_mock,
            use_moon_prompt=use_moon_prompt,
        )


if __name__ == "__main__":
    main()
