```bash
export OPENAI_API_URL=https://api.siliconflow.cn
export OPENAI_API_KEY=sk-...
export OPENAI_API_MODEL=deepseek-ai/DeepSeek-V3.2

# if you don't have an API key, you can use the Api_key below:
# export OPENAI_API_KEY=sk-tveudemnngjhzzjfnxfagjcmndtemgzpgtzdsnqkxzdqefcb

# Prompt-based self-correction loop (default)
python3 agent.py product

# Tool calling / structured outputs mode
python3 agent.py product --mode tool
```

**Mock mode** (no API key needed):
```bash
python3 agent.py product --mock
python3 agent.py product --mode tool --mock
```

**MoonBit CLI** (direct schema inspection):
```bash
moon run examples/real_llm_agent -- product schema
moon run examples/real_llm_agent -- product validate '<json>'
moon run examples/real_llm_agent -- movie schema
```