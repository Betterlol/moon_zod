# Product test case — prompt-based and tool-calling demo.
#
# Schema: movie (name, description, price, currency, category, tags, stock, metadata)

NAME = "movie"
SCHEMA_NAME = "movie"
TOOL_NAME = "create"
TOOL_DESCRIPTION = "Create a movie."


def system_prompt() -> str:
    return """\
You are a movie data generator. Given a movie name, generate a
structured JSON movie listing following the schema rules exactly.

Rules:
- Return ONLY valid JSON, no markdown wrappers, no explanations.
- You may add extra fields if they add useful information."""


def user_task() -> str:
    return 'Generate a movie listing in JSON format for:\n"Quantum Computing Starter Kit"'
