# Mindset User Guide

Complete documentation for running and using Mindset AI - a local LLM inference and fine-tuning platform.

## Table of Contents

1. [Introduction](#introduction)
2. [Installation](#installation)
3. [Quick Start](#quick-start)
4. [CLI Reference](#cli-reference)
5. [Fine-Tuning Guide](#fine-tuning-guide)
6. [Model Management](#model-management)
7. [Configuration](#configuration)
8. [Web Interface](#web-interface)
9. [Troubleshooting](#troubleshooting)
10. [Advanced Usage](#advanced-usage)

---

## Introduction

Mindset is a local AI inference server and fine-tuning platform built on Elixir and the BEAM virtual machine. It allows you to:

- Run open-source LLMs locally (GPT-2, TinyLlama, Gemma, etc.)
- Fine-tune models with your own data using LoRA
- Chat with models through a web interface
- Manage multiple fine-tuned models
- Deploy on CPU or GPU

### Key Features

- **Local-First**: All models run on your hardware, no API keys needed
- **Fine-Tuning**: Train custom models with your data
- **Fast Inference**: EXLA acceleration for 3-4 second responses
- **Simple CLI**: Easy-to-use command interface
- **Web UI**: Real-time chat with Phoenix LiveView
- **Model Registry**: Track and switch between models

---

## Installation

### System Requirements

**Minimum:**
- 8GB RAM
- 10GB free disk space
- CPU with AVX support

**Recommended:**
- 16GB+ RAM
- 50GB+ free disk space
- NVIDIA GPU with 12GB+ VRAM (for larger models)
- WSL2 (Windows users)

### Platform-Specific Installation

#### Linux (Native)

1. **Install Elixir and Erlang:**
```bash
# Ubuntu/Debian
wget https://packages.erlang-solutions.com/erlang-solutions_2.0_all.deb
sudo dpkg -i erlang-solutions_2.0_all.deb
sudo apt-get update
sudo apt-get install esl-erlang elixir

# Or use mise (recommended)
curl https://mise.run | sh
mise use -g erlang@26.0 elixir@1.15.0
```

2. **Clone and setup:**
```bash
git clone https://github.com/yourusername/mindset.git
cd mindset
export XLA_TARGET=cpu
mix deps.get
mix compile
mix ecto.setup
```

#### Windows (WSL2) - Recommended

1. **Enable WSL2:**
```powershell
# Run in PowerShell as Administrator
wsl --install -d Ubuntu
# Restart computer
```

2. **Setup Ubuntu:**
```bash
# Open Ubuntu terminal
curl https://mise.run | sh
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
echo 'eval "$($HOME/.local/bin/mise activate bash)"' >> ~/.bashrc
source ~/.bashrc
mise use -g erlang@26.0 elixir@1.15.0
```

3. **Install Mindset:**
```bash
cd ~/mindset
export XLA_TARGET=cpu
mix deps.get
mix compile
mix ecto.setup
```

#### macOS

```bash
# Install Homebrew if not installed
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install Elixir
brew install elixir

# Clone and setup
git clone https://github.com/yourusername/mindset.git
cd mindset
export XLA_TARGET=cpu
mix deps.get
mix compile
mix ecto.setup
```

### GPU Setup (Optional)

For NVIDIA GPU acceleration:

```bash
# Install CUDA toolkit
# Ubuntu
sudo apt-get install nvidia-cuda-toolkit

# Set environment variable
export XLA_TARGET=cuda120

# Recompile
mix deps.clean xla exla
mix deps.get
mix compile
```

---

## Quick Start

### 1. Start the Server

```bash
./mindset start
```

Or with mix:
```bash
mix phx.server
```

The server will be available at http://localhost:4000

### 2. Open the Chat Interface

Open your browser and go to: http://localhost:4000/chat

### 3. Start Chatting

- Type a message in the input box
- Press Enter or click "Ask"
- Wait 3-4 seconds for the AI response
- Your conversation history is automatically saved

### 4. Stop the Server

Press `Ctrl+C` twice or run:
```bash
./mindset stop
```

---

## CLI Reference

The `mindset` CLI provides all the tools you need to manage your AI system.

### Global Usage

```bash
mindset [command] [options]
```

### Commands

#### `setup` - Initial Configuration

Run the interactive setup wizard to configure your environment.

```bash
./mindset setup
```

**What it does:**
- Checks system requirements
- Detects available hardware
- Configures environment variables
- Downloads default model

#### `start` - Start the Server

Start the Mindset web server.

```bash
./mindset start
```

**Options:**
- Runs server on http://localhost:4000
- Automatically loads active model
- Creates log file in `log/dev.log`

#### `train` - Fine-Tune Models

Launch the fine-tuning wizard or train with direct options.

```bash
# Interactive wizard (recommended for first time)
./mindset train

# Quick train with options
./mindset train --data path/to/data.csv --model gpt2

# List all fine-tuned models
./mindset train --list

# Switch to a different model
./mindset train --switch <model-id>
```

**Data Format Options:**
- `--data, -d`: Path to training data file
- `--model, -m`: Base model to fine-tune (gpt2, tinyllama, gemma, phi2)
- `--format, -f`: Data format (instruction, qa)

#### `status` - System Status

Check the current status of your Mindset installation.

```bash
./mindset status
```

**Output includes:**
- Elixir version
- Server status (running/stopped)
- Number of fine-tuned models
- Active model information

#### `models` - List Models

Display all available models (base and fine-tuned).

```bash
./mindset models
```

**Example output:**
```
Fine-tuned models:

GPT-2 (Customer Support) [ACTIVE]
  ID: abc123def456
  Base: gpt2
  Final Loss: 1.2345
  Created: 2024-02-06
  
TinyLlama 1.1B (Custom)
  ID: xyz789uvw012
  Base: tinyllama
  Final Loss: 0.9876
  Created: 2024-02-05
```

#### `switch` - Change Active Model

Switch to a different fine-tuned model.

```bash
./mindset switch <model-id>
```

**Example:**
```bash
./mindset switch abc123def456
```

**Note:** You must restart the server after switching models.

#### `stop` - Stop Server

Stop the running Mindset server.

```bash
./mindset stop
```

#### `test` - Test Inference

Run a quick test to verify AI is working.

```bash
./mindset test
```

**Output:**
```
Testing AI inference...
Loading model...
Test prompt: "Hello, how are you?"
Response: "Hello! I'm doing well, thank you for asking..."
```

#### `console` - Interactive Console

Start an interactive Elixir shell (IEx) with Mindset loaded.

```bash
./mindset console
```

**Useful for:**
- Testing functions manually
- Debugging issues
- Exploring the codebase

**Example:**
```elixir
# Test model inference
Mindset.Ai.Daemon.predict("Hello")

# List registry entries
Mindset.Training.Registry.list_models()

# Check model info
Mindset.Ai.Daemon.get_model_info()
```

---

## Fine-Tuning Guide

Fine-tuning allows you to customize models with your own data for specific tasks.

### What is LoRA?

Mindset uses **LoRA (Low-Rank Adaptation)** for efficient fine-tuning:
- Only trains small adapter layers (not the full model)
- Reduces memory usage by 90%+
- Allows training on consumer hardware
- Easy to switch between different adapters

### Supported Data Formats

#### Format 1: Instruction (Recommended)

**CSV Structure:**
```csv
prompt,response
"Explain quantum physics","Quantum physics is the study of..."
"Write a Python function to calculate fibonacci","def fibonacci(n):..."
"Translate 'hello' to French","Bonjour"
```

**Best for:** General instruction following, chatbots, assistants

#### Format 2: Q&A

**CSV Structure:**
```csv
question,answer
"What is the refund policy?","You can return items within 30 days..."
"How do I reset my password?","Click on 'Forgot Password' and..."
```

**Best for:** FAQ systems, customer support bots

**Note:** Internally converted to instruction format

#### Format 3: JSONL

**Structure:**
```jsonl
{"prompt": "User: Hello\nAssistant:", "response": "Hi there!"}
{"prompt": "User: What is AI?\nAssistant:", "response": "AI stands for..."}
```

**Best for:** Multi-turn conversations, complex dialogues

### Creating Training Data

#### Step 1: Prepare Your Data

Create a CSV file with your domain-specific examples:

```bash
cat > my_data.csv << 'EOF'
prompt,response
"What are your business hours?","We are open Monday-Friday 9AM-6PM..."
"How do I track my order?","You can track your order by..."
"What payment methods do you accept?","We accept Visa, Mastercard..."
EOF
```

#### Step 2: Validate Data Quality

**Tips for good training data:**
- Minimum 50 examples (more is better)
- Clear, concise prompts
- Accurate, helpful responses
- Consistent formatting
- Cover all use cases

#### Step 3: Start Training

```bash
./mindset train
```

**Interactive Flow:**

1. **Select Format**
   ```
   Select data format:
   1. Instruction Tuning (prompt, response)
   2. Q&A Format (question, answer)
   > 1
   ```

2. **Enter File Path**
   ```
   Enter path to training data: my_data.csv
   ```

3. **Data Preview**
   ```
   Found 100 training examples
   
   Example 1:
   Prompt: What are your business hours?
   Response: We are open Monday-Friday 9AM-6PM...
   
   [Press Enter to continue]
   ```

4. **Select Base Model**
   ```
   Select base model:
   1. GPT-2 (124M) - Fast, good for testing
   2. TinyLlama 1.1B Chat - Balanced quality
   3. Gemma 2B - Higher quality
   > 2
   ```

5. **Review Configuration**
   ```
   Configuration Review
   ====================
   Model: TinyLlama 1.1B Chat
   Batch Size: 4
   Learning Rate: 0.0001
   Epochs: 3
   Est. Time: 15 minutes
   
   Proceed? [Yes/No]
   ```

6. **Training Progress**
   ```
   Training: tinyllama-customer-support
   ████████████████████████░░░░░░░░  67% (670/1000 steps)
   
   Loss: 1.234 ▼  │  LR: 0.0001
   Time: 8m 12s   │  ETA: 3m 45s
   
   [Loss graph displayed]
   
   [Ctrl+C to pause/save checkpoint]
   ```

7. **Training Complete**
   ```
   ✓ Training complete!
   Model saved and activated.
   Start the server with: mindset start
   ```

### Training Parameters

The system auto-configures optimal parameters based on your hardware:

| Parameter | Description | Auto-Value |
|-----------|-------------|------------|
| Batch Size | Samples per training step | 1-8 (based on RAM) |
| Learning Rate | Step size for updates | 5e-4 to 5e-5 |
| LoRA Rank | Adapter complexity | 8-32 |
| Epochs | Training iterations | 3 |
| Checkpoint Every | Save frequency | 100 steps |

### Monitoring Training

**During training you see:**
- Progress bar with percentage
- Current loss and trend (▼ improving, ▲ worsening)
- Learning rate
- Elapsed time and ETA
- Loss history graph
- Checkpoint notifications

**What to watch for:**
- Loss should decrease over time
- If loss plateaus, training is complete
- If loss increases, reduce learning rate

### After Training

**Your model is automatically:**
1. Saved to `priv/models/adapters/`
2. Registered in the model registry
3. Set as the active model
4. Ready to use immediately

**To use your fine-tuned model:**
```bash
./mindset start
# Visit http://localhost:4000/chat
```

### Resuming Training

If training is interrupted, it automatically resumes from the last checkpoint:

```bash
# Just run train again with the same data
./mindset train
# It will detect the checkpoint and ask to resume
```

---

## Model Management

### Understanding the Registry

The model registry (`priv/models/registry.json`) tracks all your models:

```json
{
  "models": [
    {
      "id": "abc123def456",
      "name": "GPT-2 (Customer Support)",
      "base_model": "gpt2",
      "adapter_path": "priv/models/adapters/gpt2_123456_final",
      "is_active": true,
      "metrics": {
        "final_loss": 1.2345
      }
    }
  ]
}
```

### Listing Models

```bash
./mindset models
```

Shows:
- Model name and ID
- Base model used
- Training date
- Final loss metric
- Active status

### Switching Models

```bash
# Get model ID from list
./mindset models

# Switch to specific model
./mindset switch abc123def456

# Restart server to apply
./mindset stop
./mindset start
```

### Deleting Models

Currently, manual deletion:

```bash
# Remove from registry
# Edit priv/models/registry.json

# Delete adapter files
rm -rf priv/models/adapters/<adapter-name>
```

### Model Storage Locations

```
priv/
├── models/
│   ├── adapters/           # Fine-tuned model weights
│   │   ├── gpt2_custom_final/
│   │   │   ├── adapter.safetensors
│   │   │   └── config.json
│   │   └── tinyllama_custom_final/
│   ├── checkpoints/        # Training checkpoints
│   │   ├── gpt2_123456_100/
│   │   └── gpt2_123456_200/
│   └── registry.json       # Model metadata
└── training_data/          # Cached training files
    └── 1707221234567/
        ├── data.csv
        └── metadata.json
```

---

## Configuration

### Environment Variables

Create a `.env` file in the project root:

```bash
# Model Configuration
AI_MODEL_REPO=openai-community/gpt2
# Options: gpt2, TinyLlama/TinyLlama-1.1B-Chat-v1.0, google/gemma-2b-it

# Hardware Configuration
XLA_TARGET=cpu
# Options: cpu, cuda120 (for NVIDIA GPU)

# Database
DB_PATH="./priv/repo/mindset_dev.db"

# Generation Settings
MAX_NEW_TOKENS=50
TEMPERATURE=0.7
```

### Loading Environment

The environment is automatically loaded when you:
- Run `./mindset start`
- Or manually: `export $(cat .env | xargs)`

### Configuration Priority

1. Fine-tuned model registry (highest)
2. `.env` file
3. Default values (lowest)

### Changing Models

**Method 1: Via CLI (Recommended)**
```bash
./mindset switch <model-id>
```

**Method 2: Via .env**
```bash
# Edit .env
AI_MODEL_REPO=TinyLlama/TinyLlama-1.1B-Chat-v1.0

# Restart server
./mindset stop
./mindset start
```

---

## Web Interface

### Chat Page

**URL:** http://localhost:4000/chat

**Features:**
- Real-time message updates
- Persistent chat history
- Loading indicators
- Responsive design

**Usage:**
1. Type message in input box
2. Press Enter or click "Ask"
3. View AI response
4. Scroll to see conversation history

### Model Indicator

The interface shows which model is active:
- Model name displayed in header
- Shows "Using: GPT-2 (Custom)" or base model

### Keyboard Shortcuts

- `Enter` - Send message
- `Ctrl+Enter` - New line in input
- `Esc` - Clear input

---

## Troubleshooting

### Common Issues

#### "mix: command not found"

**Cause:** Elixir not installed or not in PATH

**Solution:**
```bash
# Install Elixir
mise use -g erlang@26.0 elixir@1.15.0

# Or check installation
which elixir
elixir --version
```

#### "Port 4000 already in use"

**Cause:** Another server is running

**Solution:**
```bash
# Find and kill process
./mindset stop

# Or use different port
PORT=4001 mix phx.server
```

#### "Slow responses (2-5 minutes)"

**Cause:** Running on Windows without WSL or using CPU Evaluator

**Solution:**
```bash
# Use WSL2 (Windows users)
wsl -d Ubuntu
cd ~/mindset
./mindset start

# Or check compiler
./mindset status
# Should show: Compiler: EXLA
```

#### "Out of memory during training"

**Cause:** Model too large for available RAM

**Solutions:**
1. Use smaller model (GPT-2 instead of TinyLlama)
2. Reduce batch size
3. Use gradient accumulation
4. Add more RAM or use CPU-only mode

#### "Model not found" error

**Cause:** Registry corrupted or model deleted

**Solution:**
```bash
# Reset to base model
rm priv/models/registry.json
./mindset start
```

#### "Data format error"

**Cause:** CSV columns don't match expected format

**Solution:**
- Check CSV has correct headers (prompt/response or question/answer)
- Ensure no empty rows
- Verify encoding is UTF-8

### Getting Help

**Check logs:**
```bash
# Server logs
tail -f log/dev.log

# Console output
./mindset start 2>&1 | tee output.log
```

**Debug mode:**
```bash
# Start with debug logging
DEBUG=1 ./mindset start
```

**Test individual components:**
```bash
# Test AI
./mindset test

# Test data loading
./mindset console
> Mindset.Training.DataLoader.load("data.csv", :instruction)
```

---

## Advanced Usage

### Custom Training Scripts

Create custom training outside the wizard:

```elixir
# In IEx or script
alias Mindset.Training.{Config, Engine, Registry}

# Configure training
{:ok, config} = Config.auto_detect("gpt2", :auto)

# Custom config
config = %{config | 
  epochs: 5,
  learning_rate: 0.0002,
  lora_rank: 16
}

# Train
{:ok, state} = Engine.train(config, "data.csv", :instruction, "my_training")

# Save
adapter_path = Engine.save_final_adapter(state, "my_training", "my-model")

# Register
Registry.register(%{
  name: "My Custom Model",
  base_model: "gpt2",
  adapter_path: adapter_path,
  # ... other fields
})
```

### Batch Training Multiple Models

```bash
# Create script
cat > train_all.sh << 'EOF'
#!/bin/bash
models=("gpt2" "tinyllama")
for model in "${models[@]}"; do
  echo "Training $model..."
  ./mindset train --data data.csv --model $model
done
EOF

chmod +x train_all.sh
./train_all.sh
```

### Integration with External Systems

**API Access:**
```bash
# curl example
curl -X POST http://localhost:4000/api/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "Hello"}'
```

**WebSocket:**
Connect to `ws://localhost:4000/live/websocket` for real-time updates.

### Performance Tuning

**For faster inference:**
```bash
# Use GPU
export XLA_TARGET=cuda120

# Use smaller model
AI_MODEL_REPO=openai-community/gpt2

# Reduce max tokens
MAX_NEW_TOKENS=30
```

**For larger models:**
```bash
# Increase sequence length
# In config, set max_seq_length: 2048

# Use gradient checkpointing
# In training config, enable checkpointing
```

---

## Best Practices

### Data Preparation

✅ **Do:**
- Use at least 50 training examples
- Keep prompts clear and specific
- Cover diverse scenarios
- Use consistent formatting
- Validate data before training

❌ **Don't:**
- Include PII (personal information)
- Use copyrighted material
- Train on harmful content
- Have duplicate examples
- Use overly long prompts

### Model Selection

**Choose based on your needs:**

| Use Case | Recommended Model | Why |
|----------|------------------|-----|
| Testing/Development | GPT-2 | Fast, low resource |
| Customer Support | TinyLlama 1.1B | Chat-tuned, good balance |
| Content Creation | Gemma 2B | Higher quality output |
| Complex Reasoning | Phi-2 | Good at logic/tasks |

### Resource Management

**Monitor disk space:**
```bash
# Models are cached in ~/.cache/bumblebee/
du -sh ~/.cache/bumblebee/

# Clean old models
rm -rf ~/.cache/bumblebee/old-model-name
```

**Monitor memory:**
```bash
# Check RAM usage
free -h

# Check GPU memory (if using)
nvidia-smi
```

---

## Glossary

**LoRA (Low-Rank Adaptation)**: Efficient fine-tuning method that trains small adapter matrices instead of full model weights.

**EXLA**: Elixir binding for XLA (Accelerated Linear Algebra), Google's compiler for optimized ML operations.

**Bumblebee**: Elixir library for loading and running Hugging Face transformers models.

**Serving**: Nx.Serving provides batched inference with optimized performance.

**Adapter**: Trained LoRA weights that can be loaded on top of a base model.

**Checkpoint**: Saved state during training that allows resuming from that point.

**Registry**: JSON database tracking all fine-tuned models and their metadata.

---

## Next Steps

1. **Create your first training dataset**
2. **Run `./mindset train` to fine-tune**
3. **Test with `./mindset test`**
4. **Start chatting with `./mindset start`**

For updates and contributions, visit: https://github.com/yourusername/mindset

---

*Handcrafted with ❤️ on the BEAM*