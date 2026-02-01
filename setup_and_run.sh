#!/bin/bash

echo "🚀 Starting Mindset AI Auto-Setup..."

# 1. Clean up potential EXLA/Windows conflicts
echo "🧹 Cleaning old builds..."
rm -rf _build/dev/lib/exla
rm -rf deps/exla

# 2. Install dependencies
echo "📦 Fetching dependencies..."
mix deps.get

# 3. Setup the database (if not already done)
echo "🗄️ Preparing database..."
mix ecto.setup

# 4. Set Environment Variables for Windows CPU
# We disable EXLA and force the Binary backend to prevent the 'archive' error
export NX_DEFAULT_BACKEND=Nx.BinaryBackend
export AI_MODE=CPU_ONLY

echo "✨ Environment configured for Windows CPU."

# 5. Compile and Start
echo "🔥 Compiling and launching Phoenix..."
# We use 'iex -S' so you can debug the AI process directly in the terminal
iex -S mix phx.server