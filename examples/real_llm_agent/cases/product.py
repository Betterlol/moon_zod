# Product test case — prompt-based and tool-calling demo.
#
# Schema: product (name, description, price, currency, category, tags, stock, metadata)

NAME = "product"
SCHEMA_NAME = "product"
TOOL_NAME = "create_product"
TOOL_DESCRIPTION = "Create a product listing with name, description, price, currency, category, tags, stock, and optional metadata."


def system_prompt() -> str:
    return """\
You are a product data generator. Given a product name, generate a
structured JSON product listing following the schema rules exactly.

Rules:
- Return ONLY valid JSON, no markdown wrappers, no explanations.
- You may add extra fields if they add useful information."""


def user_task() -> str:
    return 'Generate a product listing in JSON format for:\n"Quantum Computing Starter Kit"'


def mock_data(round_num: int) -> dict:
    """Return hardcoded JSON for demo/testing without an API key."""
    if round_num == 1:
        return {
            "name": "QC",
            "price": -2999.99,
            "currency": "BTC",
            "category": "quantum",
            "tags": ["quantum", "", "compute"],
            "stock": 100.5,
            "description": "A kit",
            "extra_field": "hallucinated",
        }
    return {
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
    }
