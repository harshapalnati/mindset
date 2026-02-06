defmodule Mindset.Training.Registry do
  @moduledoc """
  Manages fine-tuned model registry.
  Tracks metadata about trained models and adapters.
  """
  require Logger

  @registry_file "priv/models/registry.json"

  @doc """
  Initialize the registry directory structure
  """
  def init do
    File.mkdir_p!("priv/models/adapters")
    File.mkdir_p!("priv/models/checkpoints")
    File.mkdir_p!("priv/training_data")
    
    unless File.exists?(@registry_file) do
      File.write!(@registry_file, Jason.encode!(%{
        models: [],
        version: "1.0",
        created_at: DateTime.utc_now() |> DateTime.to_iso8601()
      }, pretty: true))
    end
    
    :ok
  end

  @doc """
  Register a new fine-tuned model
  """
  def register(attrs) do
    init()
    
    registry = load_registry()
    
    model_entry = %{
      id: generate_id(),
      name: attrs.name,
      base_model: attrs.base_model,
      base_model_repo: attrs.base_model_repo,
      adapter_path: attrs.adapter_path,
      data_path: attrs.data_path,
      format_type: attrs.format_type,
      config: attrs.config,
      metrics: attrs.metrics,
      created_at: DateTime.utc_now() |> DateTime.to_iso8601(),
      is_active: false
    }
    
    updated_registry = %{registry | models: [model_entry | registry.models]}
    save_registry(updated_registry)
    
    {:ok, model_entry}
  end

  @doc """
  List all registered models
  """
  def list_models do
    init()
    registry = load_registry()
    registry.models
  end

  @doc """
  Get a specific model by ID
  """
  def get_model(model_id) do
    list_models()
    |> Enum.find(&(&1.id == model_id))
    |> case do
      nil -> {:error, "Model not found"}
      model -> {:ok, model}
    end
  end

  @doc """
  Get the currently active model
  """
  def get_active_model do
    list_models()
    |> Enum.find(& &1.is_active)
    |> case do
      nil -> {:error, "No active model"}
      model -> {:ok, model}
    end
  end

  @doc """
  Set a model as the active one
  """
  def set_active_model(model_id) do
    registry = load_registry()
    
    # Deactivate all models
    models = Enum.map(registry.models, fn model ->
      %{model | is_active: model.id == model_id}
    end)
    
    save_registry(%{registry | models: models})
    
    case get_model(model_id) do
      {:ok, model} -> {:ok, model}
      error -> error
    end
  end

  @doc """
  Delete a model from registry and optionally remove files
  """
  def delete_model(model_id, remove_files \\ true) do
    registry = load_registry()
    
    model = Enum.find(registry.models, &(&1.id == model_id))
    
    if model do
      # Remove files if requested
      if remove_files do
        File.rm_rf!(model.adapter_path)
      end
      
      # Remove from registry
      models = Enum.reject(registry.models, &(&1.id == model_id))
      save_registry(%{registry | models: models})
      
      :ok
    else
      {:error, "Model not found"}
    end
  end

  @doc """
  Update model metrics after training
  """
  def update_metrics(model_id, metrics) do
    registry = load_registry()
    
    models = Enum.map(registry.models, fn model ->
      if model.id == model_id do
        %{model | metrics: Map.merge(model.metrics || %{}, metrics)}
      else
        model
      end
    end)
    
    save_registry(%{registry | models: models})
    :ok
  end

  @doc """
  Get adapter path for active model, or nil if using base model
  """
  def get_active_adapter_path do
    case get_active_model() do
      {:ok, model} -> model.adapter_path
      {:error, _} -> nil
    end
  end

  @doc """
  Format models for CLI display
  """
  def format_for_cli do
    models = list_models()
    
    if models == [] do
      "No fine-tuned models found. Run `mix mindset.train` to create one."
    else
      models
      |> Enum.map(fn model ->
        status = if model.is_active, do: Owl.Data.tag(" [ACTIVE]", :green), else: ""
        created = String.slice(model.created_at, 0, 10)
        
        """
        #{model.name}#{status}
          ID: #{model.id}
          Base: #{model.base_model}
          Created: #{created}
          Final Loss: #{Map.get(model.metrics || %{}, "final_loss", "N/A")}
          Adapter: #{model.adapter_path}
        """
      end)
      |> Enum.join("\n")
    end
  end

  # Private functions

  defp load_registry do
    case File.read(@registry_file) do
      {:ok, content} ->
        case Jason.decode(content, keys: :atoms) do
          {:ok, registry} -> registry
          {:error, _} -> %{models: []}
        end
      
      {:error, _} ->
        %{models: []}
    end
  end

  defp save_registry(registry) do
    File.write!(@registry_file, Jason.encode!(registry, pretty: true))
  end

  defp generate_id do
    :crypto.strong_rand_bytes(8)
    |> Base.encode16(case: :lower)
    |> String.slice(0, 12)
  end
end