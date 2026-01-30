# Mindset

![CI Status](https://img.shields.io/badge/build-passing-brightgreen)
![Elixir Version](https://img.shields.io/badge/elixir-1.15%2B-purple)
![Phoenix Version](https://img.shields.io/badge/phoenix-1.7%2B-orange)
![License](https://img.shields.io/badge/license-MIT-blue)

> **Note:** This project is handcrafted. Not vibe-coded. Built line-by-line to master the BEAM.

**Mindset** is a hybrid AI inference server and chat application built on the BEAM (Erlang VM).

It is designed to evaluate the viability of Elixir as a full-stack AI platform, transitioning from a cloud-api wrapper to a native, in-app inference engine using the Nx ecosystem.

## 🏗 Architecture

The project is split into two distinct evolutionary phases:

### Phase 1: The Hybrid Wrapper (Current)
* **Role:** Production-grade UI & State Management.
* **Inference:** Offloaded to OpenAI/Anthropic APIs.
* **Transport:** WebSocket (Phoenix LiveView) for <50ms latency UI updates.
* **Storage:** sqlite3 for conversation history.

### Phase 2: Native Inference (Planned)
* **Role:** In-App Intelligence.
* **Inference:** Local execution using `Nx`, `Axon`, and `Bumblebee`.
* **Model:** Quantized Llama 3 / Mistral 7B loaded into RAM.
* **Hardware:** leveraging `EXLA` (XLA compiler) for CPU/GPU acceleration.

---

## 🚀 Getting Started

### Prerequisites
* **Elixir**: v1.15+
* **Erlang/OTP**: v26+
* **PostgreSQL**: v14+
* **OpenAI API Key**: Required for Phase 1.

### Installation

1.  **Clone the repository:**
    ```bash
    git clone [https://github.com/YOUR_USERNAME/mindset.git](https://github.com/YOUR_USERNAME/mindset.git)
    cd mindset
    ```

2.  **Install dependencies:**
    ```bash
    mix deps.get
    ```

3.  **Setup the database:**
    ```bash
    mix ecto.setup
    ```

4.  **Configure Environment:**
    Create a `.env` file or export your key directly:
    ```bash
    export OPENAI_API_KEY="sk-..."
    ```

5.  **Start the Server:**
    ```bash
    mix phx.server
    ```

Visit [`localhost:4000`](http://localhost:4000) from your browser.

---

## 🛠 Usage

### Phase 1 (Cloud Mode)
Currently, the application defaults to **Cloud Mode**. Ensure your `OPENAI_API_KEY` is set. The chat interface at `/` will automatically route messages to the configured provider.

### Phase 2 (Local Mode)
*Note: This feature is currently behind a feature flag.*
To enable local inference, uncomment the `Nx`/`Bumblebee` dependencies in `mix.exs` and run:
```bash
mix mindset.load_model --name llama-3-8b