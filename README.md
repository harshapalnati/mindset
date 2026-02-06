# Mindset

![CI Status](https://img.shields.io/badge/build-passing-brightgreen)
![Elixir Version](https://img.shields.io/badge/elixir-1.15%2B-purple)
![Phoenix Version](https://img.shields.io/badge/phoenix-1.7%2B-orange)
![License](https://img.shields.io/badge/license-MIT-blue)

> **Note:** This project is handcrafted. Not vibe-coded. Built line-by-line to master the BEAM.

**Mindset** is a native AI inference server and chat application with fine-tuning capabilities, built on the BEAM (Erlang VM). Run local LLMs and customize them with your own data using LoRA fine-tuning.

📚 **Documentation:** [User Manual](guides/user_manual.md) | [Quick Reference](guides/quick_reference.md)

## Features

- 🤖 **Local AI Inference** - Run GPT-2, TinyLlama, Gemma, and more locally
- 🎯 **Fine-Tuning** - Train custom models with your data using LoRA
- ⚡ **Fast Performance** - EXLA acceleration for 3-4 second responses
- 💬 **Chat Interface** - Real-time chat with Phoenix LiveView
- 🛠️ **Simple CLI** - Easy-to-use command line interface
- 💾 **Model Registry** - Manage multiple fine-tuned models
- 🔧 **Flexible Data** - Support CSV and JSONL formats

## Architecture

### Phase 1: Foundation ✅
* **Storage**: SQLite3 for conversation history
* **UI**: Phoenix LiveView with real-time updates
* **API**: Context layer for clean data operations

### Phase 2: Native Inference ✅
* **Inference**: Local execution using `Nx`, `Bumblebee`, and `EXLA`
* **Models**: GPT-2, TinyLlama, Gemma (configurable)
* **Platform**: WSL2 (Windows) or native Linux
* **Performance**: ~3-4 second response times with EXLA acceleration

### Phase 3: Fine-Tuning ✅
* **LoRA Training**: Efficient fine-tuning with Low-Rank Adaptation
* **Data Pipeline**: CSV/JSONL support with auto-format detection
* **Model Registry**: Track and switch between fine-tuned models
* **CLI Wizard**: Interactive training with real-time progress

---

## Quick Start

### Prerequisites

**For WSL2 (Recommended for Windows):**
* Windows 10/11 with WSL2 enabled
* Ubuntu distribution
* mise (version manager) or asdf

**For Linux:**
* Ubuntu 22.04+ or equivalent
* Elixir 1.15+ and Erlang/OTP 26+

### Installation

#### WSL2 Setup (Windows Users)

1. **Install mise:**
```bash
curl https://mise.run | sh
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
echo 'eval "$($HOME/.local/bin/mise activate bash)"' >> ~/.bashrc
source ~/.bashrc
```

2. **Install Erlang & Elixir:**
```bash
mise use -g erlang@26.0 elixir@1.15.0
```

3. **Clone and setup:**
```bash
cd ~/mindset
export XLA_TARGET=cpu
mix deps.get
mix compile
mix ecto.setup
```

#### Linux Setup

```bash
export XLA_TARGET=cpu
mix deps.get
mix compile
mix ecto.setup
```

### Running with CLI

```bash
# Start the server
./mindset start

# Or use mix
mix phx.server
```

Visit http://localhost:4000/chat

---

## CLI Commands

Mindset includes a convenient CLI script for common operations:

```bash
./mindset [command] [options]
```

### Available Commands

| Command | Description | Example |
|---------|-------------|---------|
| `setup` | Interactive setup wizard | `./mindset setup` |
| `train` | Fine-tuning wizard | `./mindset train` |
| `start` | Start the server | `./mindset start` |
| `status` | Check system status | `./mindset status` |
| `models` | List fine-tuned models | `./mindset models` |
| `switch` | Switch active model | `./mindset switch <model-id>` |
| `stop` | Stop the server | `./mindset stop` |
| `test` | Test AI inference | `./mindset test` |

### Quick Training Example

```bash
# Interactive training wizard
./mindset train

# Or with direct options
./mindset train --data my_data.csv --model gpt2
```

---

## Fine-Tuning Guide

### 1. Prepare Your Data

**CSV Format (Instruction):**
```csv
prompt,response
"Explain quantum physics","Quantum physics is the study of..."
"Write a poem","Roses are red..."
```

**CSV Format (Q&A):**
```csv
question,answer
"What is the refund policy?","You can return items within 30 days..."
```

**JSONL Format:**
```jsonl
{"prompt": "User: Hello\nAssistant:", "response": "Hi there!"}
```

### 2. Run Training

```bash
./mindset train
```

The wizard will:
1. ✅ Detect data format automatically
2. ✅ Show preview of training examples
3. ✅ Let you choose a base model
4. ✅ Auto-configure training parameters
5. ✅ Show live progress with loss graphs
6. ✅ Save the fine-tuned model

### 3. Use Your Model

The fine-tuned model becomes active immediately:
```bash
./mindset start
```

Or switch between models:
```bash
./mindset models          # List all models
./mindset switch <id>     # Switch to specific model
```

### Available Base Models

| Model | Size | RAM | Type | Best For |
|-------|------|-----|------|----------|
| `gpt2` | 124M | ~1GB | Text completion | Fast testing |
| `tinyllama` | 1.1B | ~3GB | Chat-tuned | Conversations |
| `gemma` | 2B | ~5GB | Instruction | Quality responses |
| `phi2` | 2.7B | ~6GB | Reasoning | Complex tasks |

---

## Usage

### Chat Interface

1. Open http://localhost:4000/chat
2. Type your message
3. Get AI response in 3-4 seconds
4. Chat history persists automatically

### Model Management

```bash
# List all models (base and fine-tuned)
./mindset models

# Example output:
# GPT-2 (Custom) [ACTIVE]
#   ID: abc123def456
#   Base: gpt2
#   Final Loss: 1.2345
#
# TinyLlama 1.1B Chat
#   ID: xyz789uvw012
#   Base: tinyllama
```

### Configuration

Create `.env` file:
```bash
# Base model (used when no fine-tuned model is active)
AI_MODEL_REPO=openai-community/gpt2

# Hardware
XLA_TARGET=cpu
# XLA_TARGET=cuda120  # For NVIDIA GPU

# Database
DB_PATH="./priv/repo/mindset_dev.db"
```

---

## Platform Support

| Platform | Compiler | Status | Fine-Tuning | Performance |
|----------|----------|--------|-------------|-------------|
| WSL2 | EXLA | ✅ Full | ✅ Supported | ~3-4s |
| Linux | EXLA | ✅ Full | ✅ Supported | ~3-4s |
| Windows | Evaluator | ⚠️ Slow | ⚠️ Limited | 2-5min |

**Note:** Use WSL2 on Windows for full functionality and best performance.

---

## Project Structure

```
mindset/
├── lib/
│   ├── mindset/
│   │   ├── ai/
│   │   │   └── daemon.ex          # AI inference engine
│   │   ├── chat/                   # Chat system
│   │   │   ├── message.ex
│   │   │   └── chat.ex
│   │   ├── training/               # Fine-tuning system
│   │   │   ├── data_loader.ex     # Data validation
│   │   │   ├── config.ex          # Auto-configuration
│   │   │   ├── engine.ex          # Training loop
│   │   │   ├── registry.ex        # Model registry
│   │   │   ├── checkpoints.ex     # Save/resume
│   │   │   └── progress.ex        # Live progress
│   │   └── cli.ex                  # CLI entry point
│   ├── mindset_web/
│   │   └── live/
│   │       └── chat_live.ex        # Chat UI
│   └── mix/tasks/mindset/
│       ├── setup.ex                # Setup wizard
│       └── train.ex                # Training wizard
├── mindset                         # CLI script (bash)
├── mindset.bat                     # CLI script (Windows)
├── priv/
│   ├── models/
│   │   ├── adapters/               # Fine-tuned models
│   │   ├── checkpoints/            # Training checkpoints
│   │   └── registry.json           # Model metadata
│   └── training_data/              # Cached training files
└── .env                            # Configuration
```

---

## Development

### Running Tests
```bash
mix test
```

### Pre-commit Checks
```bash
mix precommit
```

### Interactive Console
```bash
iex -S mix

# Test AI inference
Mindset.Ai.Daemon.predict("Hello")

# Test training
Mindset.Training.DataLoader.load("data.csv", :instruction)
```

### Building Standalone Binary

```bash
# Build escript
mix escript.build

# Use standalone binary
./mindset-cli start
```

---

## Technical Details

### AI Architecture
- **GenServer**: AI Daemon loads model once at startup
- **LoRA**: Efficient fine-tuning with adapter layers
- **Task.Supervisor**: Non-blocking inference calls
- **Nx.Serving**: Batched inference with EXLA acceleration
- **Bumblebee**: Hugging Face model loading and tokenization

### Training Pipeline
1. **Data Loading**: CSV/JSONL parsing with validation
2. **Tokenization**: BPE tokenization with truncation
3. **LoRA Setup**: Low-rank adaptation matrices
4. **Training Loop**: Axon with gradient accumulation
5. **Checkpointing**: Save every N steps
6. **Registry**: Metadata tracking and model switching

### Database
- SQLite3 via `ecto_sqlite3`
- Messages table with `role` (user/assistant) and `content`
- Automatic persistence in chat flow

---

## Roadmap

- [x] Local model inference
- [x] EXLA acceleration
- [x] Chat-tuned model support
- [x] Fine-tuning with LoRA
- [x] CLI interface
- [x] Model registry
- [ ] Streaming responses
- [ ] Quantized models (4-bit/8-bit)
- [ ] Multi-GPU training
- [ ] Windows EXLA support

---

## License

MIT

---

## Contributing

This project is handcrafted for learning the BEAM ecosystem. Built line-by-line to understand:
- Phoenix LiveView for real-time UIs
- Elixir processes and supervision trees
- Nx for numerical computing
- Bumblebee for ML model management
- LoRA for efficient fine-tuning

Feel free to fork and experiment!

---

## Troubleshooting

### Server won't start
```bash
# Check if port is in use
./mindset stop
./mindset start
```

### Training fails
```bash
# Check data format
./mindset train
# Then select preview option
```

### Slow performance on Windows
Use WSL2 for full EXLA support and 10-50x speedup.

### Out of memory
- Use smaller models (GPT-2 instead of TinyLlama)
- Reduce batch size in training
- Use CPU-only mode

---

**Handcrafted with ❤️ on the BEAM**