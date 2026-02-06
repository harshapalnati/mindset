defmodule Mindset.Training.Checkpoints do
  @moduledoc """
  Manages training checkpoints for resuming training.
  """
  require Logger

  @checkpoint_dir "priv/models/checkpoints"

  @doc """
  Initialize checkpoint directory
  """
  def init do
    File.mkdir_p!(@checkpoint_dir)
    :ok
  end

  @doc """
  Save a checkpoint during training
  """
  def save_checkpoint(checkpoint_id, step, state) do
    init()
    
    checkpoint_path = Path.join([@checkpoint_dir, "#{checkpoint_id}_#{step}"])
    File.mkdir_p!(checkpoint_path)
    
    # Save adapter weights
    adapter_path = Path.join(checkpoint_path, "adapter.safetensors")
    save_adapter_weights(state.adapter_params, adapter_path)
    
    # Save optimizer state
    optimizer_path = Path.join(checkpoint_path, "optimizer.bin")
    save_optimizer_state(state.optimizer_state, optimizer_path)
    
    # Save checkpoint metadata
    metadata = %{
      step: step,
      epoch: state.epoch,
      loss: state.loss,
      learning_rate: state.learning_rate,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      config: state.config
    }
    
    metadata_path = Path.join(checkpoint_path, "metadata.json")
    File.write!(metadata_path, Jason.encode!(metadata, pretty: true))
    
    # Cleanup old checkpoints (keep only last N)
    cleanup_old_checkpoints(checkpoint_id, state.config.save_total_limit)
    
    Logger.info("[Checkpoint] Saved at step #{step} to #{checkpoint_path}")
    
    {:ok, checkpoint_path}
  end

  @doc """
  Load the latest checkpoint for a training run
  """
  def load_latest_checkpoint(checkpoint_id) do
    checkpoint_id
    |> list_checkpoints()
    |> List.last()
    |> case do
      nil -> {:error, "No checkpoints found"}
      latest_checkpoint -> load_checkpoint(latest_checkpoint)
    end
  end

  @doc """
  Load a specific checkpoint
  """
  def load_checkpoint(checkpoint_path) do
    metadata_path = Path.join(checkpoint_path, "metadata.json")
    adapter_path = Path.join(checkpoint_path, "adapter.safetensors")
    optimizer_path = Path.join(checkpoint_path, "optimizer.bin")
    
    with {:ok, metadata} <- load_metadata(metadata_path),
         {:ok, adapter_params} <- load_adapter_weights(adapter_path),
         {:ok, optimizer_state} <- load_optimizer_state(optimizer_path) do
      
      state = %{
        step: metadata.step,
        epoch: metadata.epoch,
        loss: metadata.loss,
        learning_rate: metadata.learning_rate,
        adapter_params: adapter_params,
        optimizer_state: optimizer_state,
        config: metadata.config
      }
      
      {:ok, state}
    else
      error -> error
    end
  end

  @doc """
  List all checkpoints for a training run
  """
  def list_checkpoints(checkpoint_id) do
    init()
    
    @checkpoint_dir
    |> File.ls!()
    |> Enum.filter(&String.starts_with?(&1, "#{checkpoint_id}_"))
    |> Enum.sort()
    |> Enum.map(&Path.join(@checkpoint_dir, &1))
  end

  @doc """
  Check if a checkpoint exists for resuming
  """
  def has_checkpoint?(checkpoint_id) do
    list_checkpoints(checkpoint_id) != []
  end

  # Private functions

  defp save_adapter_weights(params, path) do
    # Convert to safetensors format
    tensors = 
      params
      |> Enum.map(fn {name, tensor} ->
        {to_string(name), tensor}
      end)
      |> Map.new()
    
    Safetensors.write_file!(path, tensors)
  end

  defp load_adapter_weights(path) do
    if File.exists?(path) do
      try do
        tensors = Safetensors.read_file!(path)
        {:ok, tensors}
      rescue
        e -> {:error, "Failed to load adapter: #{inspect(e)}"}
      end
    else
      {:error, "Adapter file not found: #{path}"}
    end
  end

  defp save_optimizer_state(state, path) do
    # Serialize optimizer state
    serialized = :erlang.term_to_binary(state)
    File.write!(path, serialized)
  end

  defp load_optimizer_state(path) do
    if File.exists?(path) do
      try do
        binary = File.read!(path)
        state = :erlang.binary_to_term(binary)
        {:ok, state}
      rescue
        e -> {:error, "Failed to load optimizer state: #{inspect(e)}"}
      end
    else
      {:error, "Optimizer state not found: #{path}"}
    end
  end

  defp load_metadata(path) do
    if File.exists?(path) do
      case File.read(path) do
        {:ok, content} -> 
          case Jason.decode(content, keys: :atoms) do
            {:ok, metadata} -> {:ok, metadata}
            error -> error
          end
        error -> error
      end
    else
      {:error, "Metadata not found: #{path}"}
    end
  end

  defp cleanup_old_checkpoints(checkpoint_id, keep_count) do
    checkpoints = list_checkpoints(checkpoint_id)
    
    if length(checkpoints) > keep_count do
      to_delete = checkpoints |> Enum.take(length(checkpoints) - keep_count)
      
      Enum.each(to_delete, fn path ->
        File.rm_rf!(path)
        Logger.debug("[Checkpoint] Removed old checkpoint: #{path}")
      end)
    end
  end
end