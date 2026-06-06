#!/usr/bin/env python3
"""
Real LLM Agent — Python Orchestrator

Calls OpenAI GPT-4o-mini to generate product JSON, validates it with
the moon_zod validator (via subprocess), and runs a self-correction loop.

Usage:
    OPENAI_API_URL=... OPENAI_API_KEY=sk-... OPENAI_API_MODEL=...
    python3 agent.py [--mock]

    --mock: use hardcoded test data, no API key needed
"""

import json
import os
import subprocess
import sys
import textwrap

# ── paths ──────────────────────────────────────────────────────────────
PROJECT_ROOT = os.path.normpath(
    os.path.join(os.path.dirname(__file__), "../..")
)
VALIDATOR_PKG = "examples/real_llm_agent"
MAX_RETRIES = 3


# ── protocol helpers ──────────────────────────────────────────────────

def validate_json(json_str: str) -> tuple[bool, object]:
    """Run the moon_zod validator via subprocess.

    Returns (True, cleaned_debug_str) on success,
            (False, list_of_error_strings) on failure.
    """
    proc = subprocess.run(
        ["moon", "run", VALIDATOR_PKG, "--", json_str],
        capture_output=True,
        text=True,
        cwd=PROJECT_ROOT,
        timeout=30,
    )
    if proc.returncode != 0:
        print(f"  [validator stderr]: {proc.stderr.strip()}")

    lines = proc.stdout.strip().split("\n")
    if not lines:
        return False, ["(validator returned empty output)"]

    if lines[0] == "OK":
        cleaned = "\n".join(lines[1:]) if len(lines) > 1 else ""
        return True, cleaned

    if lines[0] == "ERR":
        if len(lines) < 2:
            return False, ["(missing error count)"]
        errors = lines[2:] if len(lines) > 2 else []
        return False, errors

    return False, [f"(unexpected output: {lines[0]!r})"]


# ── schema fetch ─────────────────────────────────────────────────────


def fetch_schema() -> dict:
    """Run validator --schema and return the parsed JSON Schema dict."""
    proc = subprocess.run(
        ["moon", "run", VALIDATOR_PKG, "--", "--schema"],
        capture_output=True,
        text=True,
        cwd=PROJECT_ROOT,
        timeout=30,
    )
    if proc.returncode != 0:
        print(f"  [validator stderr]: {proc.stderr.strip()}")
        sys.exit(1)
    return json.loads(proc.stdout)


# ── schema to prompt ─────────────────────────────────────────────────


def _describe_type(schema: dict) -> str:
    """Translate a JSON Schema property into a concise type string."""
    t = schema.get("type", "any")
    if "enum" in schema:
        vals = ", ".join(repr(v) for v in schema["enum"])
        return f"enum [{vals}]"
    if t == "array":
        items = schema.get("items", {})
        return f"array of {_describe_type(items)}"
    if t == "object":
        props = schema.get("properties", {})
        req = schema.get("required", [])
        parts = []
        for name, ps in props.items():
            label = name if name in req else f"{name} (optional)"
            parts.append(f"    - {label}: {_describe_type(ps)}")
        return "object\n" + "\n".join(parts)
    return t  # string, number, integer, boolean, null


def schema_to_prompt(schema: dict) -> str:
    """Convert a JSON Schema dict to a concise, LLM-friendly text description."""
    props = schema.get("properties", {})
    required = set(schema.get("required", []))

    req_lines = []
    opt_lines = []

    for name, ps in props.items():
        desc = _describe_type(ps)
        if name in required:
            req_lines.append(f"  - {name}: {desc}")
        else:
            opt_lines.append(f"  - {name}: {desc}")

    lines = ["Required fields:"]
    lines.extend(req_lines)

    if opt_lines:
        lines.append("")
        lines.append("Optional fields:")
        lines.extend(opt_lines)

    extra = schema.get("additionalProperties", True)
    lines.append("")
    lines.append(f"Extra fields: {'allowed' if extra else 'not allowed'}")

    return "\n".join(lines)


# ── LLM helpers ───────────────────────────────────────────────────────

def call_llm(system: str, user: str) -> str:
    """Call OpenAI and return the text response."""
    from openai import OpenAI

    client = OpenAI(api_key=os.getenv("OPENAI_API_KEY"), base_url=os.getenv("OPENAI_API_URL"))
    resp = client.chat.completions.create(
        model=os.getenv("OPENAI_API_MODEL"),
        messages=[
            {"role": "system", "content": system},
            {"role": "user", "content": user},
        ],
        temperature=0.8,
    )
    return resp.choices[0].message.content


def extract_json(text: str) -> str:
    """Extract a JSON string from an LLM response, handling code fences."""
    text = text.strip()
    # Remove markdown code fences
    for marker in ("```json", "```"):
        if marker in text:
            parts = text.split(marker)
            if len(parts) >= 2:
                candidate = parts[1].split("```")[0].strip()
                # Only use if it looks like JSON
                if candidate.startswith("{") or candidate.startswith("["):
                    text = candidate
                    break
    return text


# ── mock mode (no API key needed) ─────────────────────────────────────

def mock_generate_json(round_num: int) -> str:
    """Return hardcoded JSON for demo/testing without an API key."""
    if round_num == 1:
        # Round 1: several validation errors
        return json.dumps({
            "name": "QC",
            "price": -2999.99,
            "currency": "BTC",
            "category": "quantum",
            "tags": ["quantum", "", "compute"],
            "stock": 100.5,
            "description": "A kit",
            "extra_field": "hallucinated",
        })
    # Round 2: fixed errors
    return json.dumps({
        "name": "Quantum Computing Starter Kit",
        "description": "A complete hands-on kit for learning quantum computing with real hardware simulations.",
        "price": 2999.99,
        "currency": "USD",
        "category": "electronics",
        "tags": ["quantum", "education", "hardware"],
        "stock": 42,
        "metadata": {
            "brand": "QuantumLeap",
            "weight_kg": 2.5,
        },
        "llm_model": "gpt-5",
        "confidence": 0.99,
    })


def build_correction_prompt(errors: list[str]) -> str:
    """Build a detailed correction prompt from validation errors."""
    prompt = "Your previous JSON had validation errors. Fix ALL of them:\n\n"
    for e in errors:
        prompt += f"  - {e}\n"
    prompt += (
        "\nReturn ONLY the corrected JSON object. "
        "No markdown, no explanations."
    )
    return prompt


# ── main ──────────────────────────────────────────────────────────────

def main():
    is_mock = "--mock" in sys.argv

    if not is_mock and "OPENAI_API_KEY" not in os.environ:
        print("❌ Error: OPENAI_API_KEY not set.")
        print()
        print("  Set it and try again:")
        print("    OPENAI_API_KEY=sk-... python3 agent.py")
        print()
        print("  Or use mock mode (no API key needed):")
        print("    python3 agent.py --mock")
        sys.exit(1)

    print("╔══════════════════════════════════════════════════════════╗")
    print("║      Real LLM Agent — MoonZod Self-Correction Demo     ║")
    print("╚══════════════════════════════════════════════════════════╝")
    print()

    # ── fetch schema from validator ─────────────────────────────────
    schema_json = fetch_schema()
    schema_prompt = schema_to_prompt(schema_json)

    # ── system prompt ──────────────────────────────────────────────
    system_prompt = textwrap.dedent("""\
    You are a product data generator. Given a product name, generate a
    structured JSON product listing following the provided JSON Schema exactly.

    Rules:
    - Return ONLY valid JSON, no markdown wrappers, no explanations.
    - You may add extra fields if they add useful information.
    """)

    user_prompt = textwrap.dedent(f"""\
    Generate a product listing in JSON format for:
    "Quantum Computing Starter Kit"

    {schema_prompt}

    Be creative and realistic. Add extra fields if they add value.
    Return ONLY valid JSON.
    """)
    
    print("  user prompt:")
    for line in user_prompt.split("\n"):
        print(f"    {line}")
    print()

    # ── correction loop ────────────────────────────────────────────
    current_user_prompt = user_prompt
    final_data = None

    for attempt in range(1, MAX_RETRIES + 1):
        print(f"── Round {attempt} ──────────────────────────────────")
        print()

        if is_mock:
            print("  (mock mode) Generating fake LLM output...")
            raw_response = mock_generate_json(attempt)
        else:
            print(f"  Calling Model {os.getenv('OPENAI_API_MODEL')}...")
            raw_response = call_llm(system_prompt, current_user_prompt)

        json_str = extract_json(raw_response)

        print(f"  LLM output:")
        for line in json_str.split("\n"):
            print(f"    {line}")
        print()

        print("  Validating with moon_zod...")
        is_ok, result = validate_json(json_str)
        print()

        if is_ok:
            print("  ✅ VALIDATION PASSED  (Strip mode active)")
            print()
            print(f"  Clean data (hallucinations stripped):")
            for line in str(result).split("\n"):
                print(f"    {line}")
            print()
            print(f"  ✅ Self-correction loop completed in {attempt} round(s)")
            final_data = result
            break
        else:
            errors = result if isinstance(result, list) else [str(result)]
            print(f"  ❌ VALIDATION FAILED — {len(errors)} error(s):")
            for e in errors:
                print(f"     {e}")
            print()

            if attempt < MAX_RETRIES:
                current_user_prompt = build_correction_prompt(errors)
                print("  ↻ Sending correction prompt back to LLM...")
                print()
        print()

    # ── summary ────────────────────────────────────────────────────
    print("════════════════════════════════════════════════════════════")
    if final_data is not None:
        print("  Status: ✅ Success")
        print(f"  Rounds: {attempt}")
        print("  Strip:  Extra fields removed by moon_zod default mode")
    else:
        print("  Status: ❌ Failed after max retries")
        print(f"  Rounds: {MAX_RETRIES}")
    print("════════════════════════════════════════════════════════════")


if __name__ == "__main__":
    main()
