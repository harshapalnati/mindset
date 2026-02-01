defmodule Mindset.Ai.Daemon do
  use GenServer
  require Logger


  @moduledoc """
  This is background 'brain' of Mindset. Manages model state and inference.
  """
  def start_link(opts \\[]) do
    GenServer.start_link(__MODULE__, opts ,name: __MODULE__)
  end


  def predict(text) do
    GenServer.call(__MODULE__, {:predict, text}, :infinity)
  end

  @impl true
  def init(_opts) do
     repo = System.get_env("AI_MODEL_REPO") || "openai-community/gpt2"

     Logger.info(" [Daemon] Waking up native unit: #{repo}")


     #load model into mememory
     {:ok, _spec} = Bumblebee.load_spec({:hf, repo})
    {:ok, model} = Bumblebee.load_model({:hf, repo})
    {:ok, tokenizer} = Bumblebee.load_tokenizer({:hf, repo})
    {:ok, generation_config} = Bumblebee.load_generation_config({:hf, repo})

      # lib/mindset/ai/daemon.ex
serving = Bumblebee.Text.generation(model, tokenizer, generation_config,
  compile: [batch_size: 1, sequence_length: 32],
  defn_options: [compiler: Nx.Defn.Evaluator]
)

    {:ok, %{serving: serving}}

  end


  @impl true
  def handle_call({:predict, text}, _from, state) do
  Logger.info("[AI] Processing prompt: #{inspect(text)}")

  # Measure how long the math takes
  {micro, output} = :timer.tc(fn -> Nx.Serving.run(state.serving, text) end)

  Logger.info(" [AI] Inference complete in #{Float.round(micro / 1_000_000, 2)}s")
  Logger.debug(" [AI] Raw Output: #{inspect(output)}")

  {:reply, output, state}
end


end
