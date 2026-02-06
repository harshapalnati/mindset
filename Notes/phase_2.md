# Phase 2: The Native Unit – Local Inference Engine

## Project Goal Achieved
Successfully transitioned Mindset AI from a cloud-dependent "API Wrapper" into a **Native AI Engine** that runs models locally on the user's hardware with full chat UI integration.

---

## Implementation Summary

### EXLA Integration via WSL
**The Challenge**: EXLA (Accelerated Linear Algebra) lacks precompiled binaries for Windows (`x86_64-windows-cpu`).

**The Solution**: Run the application in **WSL2 (Windows Subsystem for Linux)**:
- EXLA provides precompiled binaries for `x86_64-linux-gnu-cpu` ✓
- Performance: ~3-4 seconds per inference (GPT-2) vs 2-5 minutes on Windows CPU
- Compiler: `Elixir.EXLA` with XLA backend for optimized tensor operations

### Current Working Setup

**Platform**: WSL2 Ubuntu with EXLA
**Model**: GPT-2 (openai-community/gpt2) - 124M parameters
**Response Time**: 3-4 seconds per message
**Compiler**: EXLA (XLA backend)

**Alternative Models Available**:
- `TinyLlama/TinyLlama-1.1B-Chat-v1.0` - Chat-optimized, 1.1B params
- `google/gemma-2b-it` - Google's 2B parameter model
- `sshleifer/tiny-gpt2` - Smaller/faster GPT-2 variant

---

## Architecture Components

### 1. AI Daemon (`lib/mindset/ai/daemon.ex`)
The core inference engine:
- GenServer-based background process
- Loads model once at startup
- Handles concurrent prediction requests
- Auto-detects EXLA availability (falls back to Evaluator if needed)

```elixir
# Configuration
repo = System.get_env("AI_MODEL_REPO") || "openai-community/gpt2"

# Serving setup with EXLA
serving = Bumblebee.Text.generation(model, tokenizer, generation_config,
  compile: [batch_size: 1, sequence_length: 64],
  defn_options: [compiler: EXLA]  # or Nx.Defn.Evaluator
)
```

### 2. Model Configuration (`.env`)
```bash
AI_MODEL_REPO=openai-community/gpt2
XLA_TARGET=cpu
```

### 3. Dependencies (`mix.exs`)
```elixir
{:nx, "~> 0.9"},
{:exla, "~> 0.9"},  # Linux/WSL only
{:bumblebee, "~> 0.6"},
```

---

## WSL Setup Guide

### Prerequisites
- Windows 10/11 with WSL2 enabled
- Ubuntu distribution installed

### Installation Steps

1. **Install mise (version manager)**:
```bash
curl https://mise.run | sh
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
echo 'eval "$($HOME/.local/bin/mise activate bash)"' >> ~/.bashrc
source ~/.bashrc
```

2. **Install Erlang & Elixir**:
```bash
mise use -g erlang@26.0 elixir@1.15.0
```

3. **Clone and setup project**:
```bash
cd ~/mindset  # or /mnt/c/... for Windows drive access
export XLA_TARGET=cpu
mix deps.get
mix compile
mix ecto.setup
```

4. **Start server**:
```bash
mix phx.server
```

5. **Access**: http://localhost:4000/chat

---

## Performance Benchmarks

| Platform | Compiler | Model | Response Time |
|----------|----------|-------|---------------|
| Windows  | Evaluator | GPT-2 | 2-5 minutes ❌ |
| WSL2     | EXLA      | GPT-2 | 3-4 seconds ✓ |
| WSL2     | EXLA      | TinyLlama-1.1B | ~5-8 seconds |

---

## Known Limitations

1. **GPT-2 is a completion model**, not chat-tuned:
   - Input: "Hello"
   - Output: ", I'm not sure if you're aware that..."
   - **Fix**: Use `TinyLlama-1.1B-Chat-v1.0` for conversational responses

2. **Windows native builds**: Still use `Nx.Defn.Evaluator` (slow)

3. **EXLA compilation**: First run downloads/compiles XLA (~5-10 minutes)

---

## Future Improvements

- [ ] Add model switching UI
- [ ] Implement streaming responses
- [ ] Add GPU support (CUDA) for faster inference
- [ ] Quantized model support (4-bit/8-bit) for larger models
- [ ] Windows EXLA support (if precompiled binaries become available)