# Mindset Quick Reference Card

## 🚀 Quick Start (5 minutes)

```bash
# 1. Install (one-time)
cd ~/mindset
export XLA_TARGET=cpu
mix deps.get && mix compile && mix ecto.setup

# 2. Start server
./mindset start

# 3. Open browser
# http://localhost:4000/chat
```

---

## 📋 Common Commands

| Task | Command |
|------|---------|
| **Start Server** | `./mindset start` |
| **Stop Server** | `./mindset stop` or `Ctrl+C` |
| **Check Status** | `./mindset status` |
| **Fine-Tune** | `./mindset train` |
| **List Models** | `./mindset models` |
| **Switch Model** | `./mindset switch <id>` |
| **Test AI** | `./mindset test` |
| **Console** | `./mindset console` |

---

## 🎯 Fine-Tuning in 3 Steps

### Step 1: Create Data
```bash
cat > training.csv << 'EOF'
prompt,response
"Hello","Hi there!"
"What is AI?","AI is Artificial Intelligence"
EOF
```

### Step 2: Train
```bash
./mindset train
# Select: 1 (Instruction)
# Path: training.csv
# Model: 1 (GPT-2) or 2 (TinyLlama)
# Confirm: Yes
```

### Step 3: Use
```bash
./mindset start
# Visit http://localhost:4000/chat
```

---

## 📊 Data Formats

### CSV - Instruction
```csv
prompt,response
"Explain X","X is..."
"How to Y?","To Y, do..."
```

### CSV - Q&A
```csv
question,answer
"What is X?","X is..."
```

### JSONL
```jsonl
{"prompt": "User: Hello\nBot:", "response": "Hi!"}
```

---

## 🔧 Troubleshooting

| Problem | Solution |
|---------|----------|
| **Port in use** | `./mindset stop` then start |
| **Slow responses** | Use WSL2, not Windows native |
| **Out of memory** | Use GPT-2 (smaller model) |
| **Model not found** | Delete `priv/models/registry.json` |
| **Import errors** | Run `mix deps.get` |

---

## ⚙️ Configuration

### `.env` file:
```bash
AI_MODEL_REPO=openai-community/gpt2
XLA_TARGET=cpu
DB_PATH="./priv/repo/mindset_dev.db"
```

### Available Models:
- `gpt2` - 124M params, fast
- `tinyllama` - 1.1B params, chat-tuned
- `gemma` - 2B params, high quality
- `phi2` - 2.7B params, reasoning

---

## 💡 Tips

**Minimum 50 training examples for fine-tuning**

**Use WSL2 on Windows for 10x speedup**

**Check status anytime:**
```bash
./mindset status
```

**Test without starting server:**
```bash
./mindset test
```

**Full documentation:**
```bash
cat guides/user_manual.md
```

---

## 🆘 Getting Help

1. Check status: `./mindset status`
2. View logs: `tail -f log/dev.log`
3. Test AI: `./mindset test`
4. Read manual: `guides/user_manual.md`

---

**Full Guide:** See `guides/user_manual.md` for complete documentation