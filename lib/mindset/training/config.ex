defmodule Mindset.Training.Config do
  @moduledoc """
  Auto-detects training configuration based on model and hardware.
  """

  @models %{
    "gpt2" => %{
      name: "GPT-2",
      repo: "openai-community/gpt2",
      params: "124M",
      default_batch_size: 8,
      default_learning_rate: 0.0005,
      lora_rank: 8,
      lora_alpha: 16,
      context_length: 512
    },
    "tinyllama" => %{
      name: "TinyLlama 1.1B Chat",
      repo: "TinyLlama/TinyLlama-1.1B-Chat-v1.0",
      params: "1.1B",
      default_batch_size: 4,
      default_learning_rate: 0.0001,
      lora_rank: 16,
      lora_alpha: 32,
      context_length: 2048
    }
  }

  def auto_detect(model_id, hardware_type \\ :auto) do
    model = get_model(model_id)
    if is_nil(model) do
      {:error, "Unknown model: #{model_id}"}
    else
      hardware = detect_hardware(hardware_type)
      config = %{
        model_id: model_id,
        model_repo: model.repo,
        model_name: model.name,
        batch_size: model.default_batch_size,
        learning_rate: model.default_learning_rate,
        epochs: 3,
        lora_rank: model.lora_rank,
        lora_alpha: model.lora_alpha,
        hardware: hardware
      }
      {:ok, config}
    end
  end

  def get_model(model_id) do
    Map.get(@models, model_id)
  end

  def list_models do
    @models |> Enum.map(fn {id, config} -> Map.put(config, :id, id) end)
  end

  defp detect_hardware(:auto) do
    %{has_gpu: false, is_linux: true, memory_gb: 8, cpu_cores: System.schedulers_online()}
  end

  defp detect_hardware(:cpu) do
    %{has_gpu: false, is_linux: true, memory_gb: 8, cpu_cores: System.schedulers_online()}
  end

  defp detect_hardware(:gpu) do
    %{has_gpu: true, is_linux: true, memory_gb: 12, cpu_cores: System.schedulers_online()}
  end
end
