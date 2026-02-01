# Use the official Elixir image
FROM elixir:1.17-alpine

# Install build essentials for Windows-compatibility layers
RUN apk add --no-cache build-base git postgresql-client

# Install Hex and Rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Create app directory
WORKDIR /app

# Copy dependency files first (for caching)
COPY mix.exs mix.lock ./
RUN mix deps.get

# Copy the rest of the code
COPY . .

# Set environment to skip hardware acceleration
ENV NX_DEFAULT_BACKEND=Nx.BinaryBackend
ENV AI_MODE=CPU_ONLY

# Compile the project
RUN mix compile

# Start the server
CMD ["mix", "phx.server"]