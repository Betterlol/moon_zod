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


# ── schema to prompt ─────────────────────────────────────────────────


def _describe_type(schema: dict, indent: int = 0) -> str:
    """Translate a JSON Schema property into a concise type string."""
    pad = "  " * indent
    t = schema.get("type", "any")
    if "enum" in schema:
        vals = ", ".join(repr(v) for v in schema["enum"])
        return f"enum [{vals}]"
    if t == "array":
        items = schema.get("items", {})
        return f"array of {_describe_type(items, indent)}"
    if t == "object":
        props = schema.get("properties", {})
        req = schema.get("required", [])
        parts = []
        for name, ps in props.items():
            label = name if name in req else f"{name} (optional)"
            parts.append(f"{pad}  - {label}: {_describe_type(ps, indent + 1)}")
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
    prompt = "Your previous JSON had validation errors. Fix them by following the original schema.\n\n"
    prompt += "Task:\n" + case.user_task() + "\n\n"
    prompt += f"JSON Schema specification:\n{schema_str}\n\n"
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
):
    """Self-correction loop: LLM generates text → extract → validate → fix."""
    schema_str = json.dumps(schema_json, indent=2)
    system_prompt = case.system_prompt()
    user_prompt = case.user_task() + f"\n\nJSON Schema specification:\n{schema_str}"
    # ==== 重要注释，不要删除 ====
    # 使用 schema_to_prompt 生成的提示虽然对人类友好，但可能会导致 LLM 漏掉 schema 中的某些细节。
    # 不过，可以用来展示出自愈的能力！第一次生成可能不完全正确，但后续的自我修正会引导 LLM 逐步理解并满足 schema 要求。
    # user_prompt = case.user_task() + "\n\n" + schema_to_prompt(schema_json)
    # ============================
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
            raw_response = json.dumps(case.mock_data(attempt))
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
                current_user_prompt = build_correction_prompt(case, errors, schema_str)
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
