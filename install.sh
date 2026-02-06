#!/bin/bash

# Mindset AI - Installation Script
# This script automates the installation process

set -e

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║               Mindset AI Installer                            ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_step() {
    echo -e "${BLUE}[Step $1]${NC} $2"
}

print_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

# Check OS
detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo "linux"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]]; then
        echo "windows"
    else
        echo "unknown"
    fi
}

OS=$(detect_os)

echo "Detected OS: $OS"
echo ""

# Step 1: Check prerequisites
print_step "1" "Checking prerequisites..."

if ! command -v git &> /dev/null; then
    print_error "Git is required but not installed"
    exit 1
fi

print_success "Git found"

# Check for WSL on Windows
if [[ "$OS" == "windows" ]]; then
    print_warning "Windows detected. Please use WSL2 for best performance."
    print_info "Run: wsl --install -d Ubuntu"
    exit 1
fi

# Step 2: Install mise (if not present)
print_step "2" "Setting up mise version manager..."

if ! command -v mise &> /dev/null; then
    print_warning "mise not found. Installing..."
    curl https://mise.run | sh
    
    # Add to shell
    if [[ -f ~/.bashrc ]]; then
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
        echo 'eval "$($HOME/.local/bin/mise activate bash)"' >> ~/.bashrc
    fi
    
    if [[ -f ~/.zshrc ]]; then
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
        echo 'eval "$($HOME/.local/bin/mise activate zsh)"' >> ~/.zshrc
    fi
    
    export PATH="$HOME/.local/bin:$PATH"
    eval "$($HOME/.local/bin/mise activate bash)"
    
    print_success "mise installed"
else
    print_success "mise already installed"
fi

# Step 3: Install Erlang and Elixir
print_step "3" "Installing Erlang & Elixir..."

export PATH="$HOME/.local/bin:$PATH"
eval "$($HOME/.local/bin/mise activate bash)"

mise use -g erlang@26.0
mise use -g elixir@1.15.0

print_success "Erlang and Elixir installed"

# Verify installation
elixir --version

# Step 4: Setup project
print_step "4" "Setting up Mindset..."

if [[ ! -f "mix.exs" ]]; then
    print_error "Please run this script from the Mindset project directory"
    exit 1
fi

# Install dependencies
print_step "5" "Installing dependencies..."

export XLA_TARGET=cpu
mix local.hex --force
mix local.rebar --force
mix deps.get

print_success "Dependencies installed"

# Compile
print_step "6" "Compiling project..."

mix compile

print_success "Project compiled"

# Setup database
print_step "7" "Setting up database..."

mix ecto.setup

print_success "Database initialized"

# Make scripts executable
chmod +x mindset
chmod +x mindset.bat 2>/dev/null || true

print_success "CLI scripts configured"

# Step 5: Create sample data
print_step "8" "Creating sample training data..."

cat > sample_training.csv << 'EOF'
prompt,response
"Hello","Hi there! How can I help you today?"
"What is Mindset?","Mindset is a local AI inference and fine-tuning platform."
"How do I train a model?","Use the command: ./mindset train"
"What models are supported?","GPT-2, TinyLlama, Gemma, and Phi-2."
EOF

print_success "Sample data created: sample_training.csv"

# Step 6: Final instructions
echo ""
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║               Installation Complete!                          ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""
echo "Next steps:"
echo ""
echo "  1. Start the server:"
echo "     ./mindset start"
echo ""
echo "  2. Open your browser:"
echo "     http://localhost:4000/chat"
echo ""
echo "  3. Fine-tune a model:"
echo "     ./mindset train --data sample_training.csv --model gpt2"
echo ""
echo "  4. Read the documentation:"
echo "     cat guides/quick_reference.md"
echo "     cat guides/user_manual.md"
echo ""
echo "Need help? Run: ./mindset help"
echo ""
print_success "Mindset is ready to use!"

exit 0