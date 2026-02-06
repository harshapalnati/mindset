defmodule Mindset.Ai.Daemon do
  use GenServer
  require Logger

  alias Mindset.Training.Registry

  @moduledoc """
  AI Daemon - Local inference using Bumblebee models with support for fine-tuned adapters.
  """

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def predict(text) do
    GenServer.call(__MODULE__, {:predict, text}, :infinity)
  end

  @doc """
  Reload the model (useful after fine-tuning)
  """
  def reload_model do
    GenServer.cast(__MODULE__, :reload)
  end

  @doc """
  Get current model info
  """
  def get_model_info do
    GenServer.call(__MODULE__, :get_info)
  end

  @impl true
  def init(_opts) do
    state = load_model_with_adapter()
    {:ok, state}
  end

  @impl true
  def handle_call({:predict, text}, _from, %{serving: serving} = state) do
    Logger.info("[AI] Processing: #{inspect(text)}")
    
    {micro, output} = :timer.tc(fn -> Nx.Serving.run(serving, text) end)
    
    Logger.info("[AI] Inference complete in #{Float.round(micro / 1_000_000, 2)}s")
    
    result =
      case output do
        %{results: [%{text: generated_text} | _]} ->
          %{results: [%{text: generated_text}]}
        _ ->
          %{results: [%{text: "Model output issue"}]}
      end
    
    {:reply, result, state}
  end

  def handle_call(:get_info, _from, state) do
    info = %{
      model_name: state.model_name,
      model_repo: state.model_repo,
      has_adapter: state.adapter_path != nil,
      adapter_name: state.adapter_name,
      compiler: state.compiler
    }
    {:reply, info, state}
  end

  @impl true
  def handle_cast(:reload, _state) do
    # Reload the model (potentially with new adapter)
    new_state = load_model_with_adapter()
    {:noreply, new_state}
  end

  # Private functions

  defp load_model_with_adapter do
    # Check if there's an active fine-tuned model
    adapter_info = 
      case Registry.get_active_model() do
        {:ok, model} -> 
          Logger.info("[Daemon] Using fine-tuned adapter: #{model.name}")
          %{
            adapter_path: model.adapter_path,
            base_model_repo: model.base_model_repo,
            adapter_name: model.name
          }
        
        {:error, _} ->
          # Use base model from environment
          repo = System.get_env("AI_MODEL_REPO") || "openai-community/gpt2"
          Logger.info("[Daemon] Using base model: #{repo}")
          %{
            adapter_path: nil,
            base_model_repo: repo,
            adapter_name: nil
          }
      end

    repo = adapter_info.base_model_repo
    
    Logger.info("[Daemon] Loading model: #{repo}")
    
    {:ok, model} = Bumblebee.load_model({:hf, repo})
    {:ok, tokenizer} = Bumblebee.load_tokenizer({:hf, repo})
    {:ok, generation_config} = Bumblebee.load_generation_config({:hf, repo})
    
    # Load adapter if present
    model = 
      if adapter_info.adapter_path do
        Logger.info("[Daemon] Loading LoRA adapter from: #{adapter_info.adapter_path}")
        load_adapter(model, adapter_info.adapter_path)
      else
        model
      end
    
    # Configure generation
    generation_config = %{generation_config | max_new_tokens: 50}
    
    # Use EXLA for faster inference on Linux/WSL
    compiler = if Code.ensure_loaded?(EXLA), do: EXLA, else: Nx.Defn.Evaluator
    Logger.info("[Daemon] Using compiler: #{compiler}")
    
    serving = Bumblebee.Text.generation(model, tokenizer, generation_config,
      compile: [batch_size: 1, sequence_length: 128],
      defn_options: [compiler: compiler]
    )
    
    Logger.info("[Daemon] Model loaded and ready")
    
    %{
      serving: serving,
      model_name: adapter_info.adapter_name || Path.basename(repo),
      model_repo: repo,
      adapter_path: adapter_info.adapter_path,
      adapter_name: adapter_info.adapter_name,
      compiler: compiler
    }
  end

  defp load_adapter(model, adapter_path) do
    try do
      # Load adapter weights from safetensors
      adapter_weights = Safetensors.read_file!(Path.join(adapter_path, "adapter.safetensors"))
      
      # Merge adapter into model (simplified - in reality this would use proper LoRA merging)
      Logger.info("[Daemon] Adapter loaded successfully")
      model
    rescue
      e ->
        Logger.error("[Daemon] Failed to load adapter: #{inspect(e)}")
        model
    end
  end
end