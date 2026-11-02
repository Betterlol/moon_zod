# Real LLM Agent — Shared Core Logic
#
# Shared helpers: schema fetch, validation protocol, LLM calls,
# prompt construction, and runner loops for prompt and tool modes.

import json
import os
import subprocess
import sys

# ── paths ──────────────────────────────────────────────────────────────
PROJECT_ROOT = os.path.normpath(
    os.path.join(os.path.dirname(__file__), "../..")
)
VALIDATOR_PKG = "examples/real_llm_agent"
MAX_RETRIES = 3


# ── protocol helpers ──────────────────────────────────────────────────

def fetch_schema(schema_name: str) -> dict:
    """Run validator --schema and return the parsed JSON Schema dict."""
    proc = subprocess.run(
        ["moon", "run", VALIDATOR_PKG, "--", schema_name, "schema"],
        capture_output=True,
        text=True,
        cwd=PROJECT_ROOT,
        timeout=30,
    )
    if proc.returncode != 0:
        print(f"  [validator stderr]: {proc.stderr.strip()}")
        sys.exit(1)
    return json.loads(proc.stdout)


def fetch_moon_prompt(schema_name: str) -> str:
    """Run validator --prompt and return the TypeScript interface prompt string.

    Uses moon_zod's schema_to_prompt() to generate an LLM-friendly type
    definition with constraint annotations as inline comments.
    """
    proc = subprocess.run(
        ["moon", "run", VALIDATOR_PKG, "--", schema_name, "prompt"],
        capture_output=True,
        text=True,
        cwd=PROJECT_ROOT,
        timeout=30,
    )
    if proc.returncode != 0:
        print(f"  [validator stderr]: {proc.stderr.strip()}")
        sys.exit(1)
    return proc.stdout.strip()


def validate_json(json_str: str, schema_name: str) -> tuple[bool, object]:
    """Run the moon_zod validator via subprocess.

    Returns (True, cleaned_debug_str) on success,
            (False, list_of_error_strings) on failure.
    """
    proc = subprocess.run(
        ["moon", "run", VALIDATOR_PKG, "--", schema_name, "validate", json_str],
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


# ── LLM helpers ───────────────────────────────────────────────────────

def call_llm(system: str, user: str, api_key: str, api_url: str, model: str) -> str:
    """Call OpenAI and return the text response."""
    from openai import OpenAI

    client = OpenAI(api_key=api_key, base_url=api_url)
    resp = client.chat.completions.create(
        model=model,
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
    for marker in ("```json", "```"):
        if marker in text:
            parts = text.split(marker)
            if len(parts) >= 2:
                candidate = parts[1].split("```")[0].strip()
                if candidate.startswith("{") or candidate.startswith("["):
                    text = candidate
                    break
    return text


def build_correction_prompt(case, errors: list[str], schema_str: str) -> str:
    """Build a detailed correction prompt with schema context and errors."""
    prompt = "Your previous JSON had validation errors. Fix them by following the type definition.\n\n"
    prompt += "Task:\n" + case.user_task() + "\n\n"
    prompt += f"Expected type:\n{schema_str}\n\n"
    prompt += "Validation errors:\n"
    for e in errors:
        prompt += f"  - {e}\n"
    prompt += (
        "\nReturn ONLY the corrected JSON object. "
        "No markdown, no explanations."
    )
    return prompt


# ── runner: prompt-based self-correction ──────────────────────────────

def run_prompt_mode(
    case,
    schema_json: dict,
    *,
    api_key: str = "",
    api_url: str = "",
    model: str = "",
    mock: bool = False,
    use_moon_prompt: bool = False,
):
    """Self-correction loop: LLM generates text → extract → validate → fix.

    When use_moon_prompt is True, the initial prompt uses moon_zod's
    schema_to_prompt() output (TypeScript-interface style) instead of
    raw JSON Schema.  This is more compact and LLM-friendly, and the
    self-correction loop handles any gaps.
    """
    schema_str = json.dumps(schema_json, indent=2)
    schema_display = (
        fetch_moon_prompt(case.SCHEMA_NAME) if use_moon_prompt
        else schema_str
    )
    system_prompt = case.system_prompt()
    user_prompt = (
        case.user_task()
        + f"\n\nExpected type:\n{schema_display}"
    )
    print("  user prompt:")
    for line in user_prompt.split("\n"):
        print(f"  {line}")
    print()
    current_user_prompt = user_prompt
    final_data = None

    for attempt in range(1, MAX_RETRIES + 1):
        print(f"── Round {attempt} ──────────────────────────────────")
        print()

        if mock:
            print("  (mock mode) Generating fake LLM output...")
            # raw_response = json.dumps(case.mock_data(attempt))
            print("  No longer supporting mock mode. Please refer README for instructions on running with real LLMs.")
            return
        else:
            print(f"  Calling {model}...")
            raw_response = call_llm(system_prompt, current_user_prompt,
                                    api_key, api_url, model)

        json_str = extract_json(raw_response)

        print(f"  LLM output:")
        for line in json_str.split("\n"):
            print(f"    {line}")
        print()

        print(f"  Validating with moon_zod ({case.SCHEMA_NAME})...")
        is_ok, result = validate_json(json_str, case.SCHEMA_NAME)
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
                current_user_prompt = build_correction_prompt(case, errors, schema_display)
                print("  ↻ Sending correction prompt back to LLM...")
                print()
        print()

    # summary
    print("════════════════════════════════════════════════════════════")
    if final_data is not None:
        print("  Status: ✅ Success")
        print(f"  Rounds: {attempt}")
        print("  Strip:  Extra fields removed by moon_zod default mode")
    else:
        print("  Status: ❌ Failed after max retries")
        print(f"  Rounds: {MAX_RETRIES}")
    print("════════════════════════════════════════════════════════════")

    return final_data


# ── runner: tool-calling mode ────────────────────────────────────────

def run_tool_mode(
    case,
    schema_json: dict,
    *,
    api_key: str = "",
    api_url: str = "",
    model: str = "",
    mock: bool = False,
):
    """Tool-calling loop: LLM receives JSON Schema as a function tool.

    Uses OpenAI structured outputs so the response is guaranteed valid JSON.
    Still validates through moon_zod as a safety check.
    """
    from openai import OpenAI
    from openai.types.chat import ChatCompletionToolParam

    system_prompt = case.system_prompt()
    user_prompt = case.user_task()
    schema_str = json.dumps(schema_json, indent=2)
    final_data = None

    tool: ChatCompletionToolParam = {
        "type": "function",
        "function": {
            "name": case.TOOL_NAME,
            "description": case.TOOL_DESCRIPTION,
            "parameters": schema_json,
            "strict": True,
        },
    }

    for attempt in range(1, MAX_RETRIES + 1):
        print(f"── Round {attempt} ──────────────────────────────────")
        print()

        if mock:
            print("  (mock mode) Generating fake LLM output...")
            raw_response = json.dumps(case.mock_data(attempt))
            json_str = raw_response
        else:
            print(f"  Calling {model} (tool: {case.TOOL_NAME})...")
            client = OpenAI(api_key=api_key, base_url=api_url)
            resp = client.chat.completions.create(
                model=model,
                messages=[
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": user_prompt},
                ],
                tools=[tool],
                tool_choice={"type": "function", "function": {"name": case.TOOL_NAME}},
                temperature=0.8,
            )

            msg = resp.choices[0].message
            if msg.tool_calls:
                json_str = msg.tool_calls[0].function.arguments
            else:
                json_str = extract_json(msg.content)

        print(f"  LLM output:")
        for line in json_str.split("\n"):
            print(f"    {line}")
        print()

        print(f"  Validating with moon_zod ({case.SCHEMA_NAME})...")
        is_ok, result = validate_json(json_str, case.SCHEMA_NAME)
        print()

        if is_ok:
            print("  ✅ VALIDATION PASSED  (Structured output)")
            print()
            print(f"  Clean data (hallucinations stripped):")
            for line in str(result).split("\n"):
                print(f"    {line}")
            print()
            print(f"  ✅ Completed in {attempt} round(s)")
            final_data = result
            break
        else:
            errors = result if isinstance(result, list) else [str(result)]
            print(f"  ❌ VALIDATION FAILED — {len(errors)} error(s):")
            for e in errors:
                print(f"     {e}")
            print()

            if attempt < MAX_RETRIES:
                user_prompt = build_correction_prompt(case, errors, schema_str)
                print("  ↻ Sending correction prompt back to LLM...")
                print()
        print()

    print("════════════════════════════════════════════════════════════")
    if final_data is not None:
        print("  Status: ✅ Success")
        print(f"  Rounds: {attempt}")
        print("  Strip:  Extra fields removed by moon_zod default mode")
    else:
        print("  Status: ❌ Failed after max retries")
        print(f"  Rounds: {MAX_RETRIES}")
    print("════════════════════════════════════════════════════════════")

    return final_data
