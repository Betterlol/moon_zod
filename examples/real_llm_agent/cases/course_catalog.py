# Course Catalog test case — complex nested schema demo.
#
# Schema: course_catalog (6 levels deep, 8 enums, regex, array constraints)
#
# This schema is deliberately complex to trigger self-correction:
#   - Deep nesting (course → modules → topics) causes LLMs to skip constraints
#   - Time regex (HH:MM 24h) — LLMs default to "2:00 PM" or "14:00:00"
#   - Similar enum values (lecture/lab/seminar/workshop/exam) — easy to confuse
#   - Array length constraints (min 3 modules, min 1 topics) — LLMs underfill
#   - Email + URL validators — LLMs produce malformed strings
#   - Positive() on hours — LLMs use 0 or negative

NAME = "course_catalog"
SCHEMA_NAME = "course_catalog"
TOOL_NAME = "generate_syllabus"
TOOL_DESCRIPTION = "Generate a complete course syllabus for an academic course."


def system_prompt() -> str:
    return """\
You are a university curriculum designer. Generate a complete course \
syllabus in JSON format following the given schema exactly.

Rules:
- Return ONLY valid JSON. No markdown, no code fences, no explanations.
- All time values must use 24h HH:MM format (e.g. "09:00", "14:30").
- Every module must have at least one topic.
- Include all required fields. Add extra fields only for genuinely useful metadata.
- Double-check enum values match the allowed set exactly."""


def user_task() -> str:
    return """\
Generate a syllabus for "CS301: Advanced Machine Learning" — a 4-credit \
graduate-level course in the Computer Science department. 3-hour lecture \
sessions twice a week (Mon/Wed), one lab session (Fri). The instructor is \
Dr. Alan Turing (ata@cs.uni.edu), a professor. Assessment: 40% final project, \
30% midterm, 20% homework, 10% participation. Prerequisites: CS201, CS250. \
Tags: machine-learning, deep-learning, nlp, python, pytorch."""


def mock_data(round_num: int) -> dict:
    """Minimal mock — real self-correction loop is the demo."""
    return {}
