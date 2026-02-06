defmodule Mindset.Training.Engine do
  @moduledoc """
  Training engine using LoRA (Low-Rank Adaptation) for efficient fine-tuning.
  Integrates with Axon for training loops and Bumblebee for model management.
  
  Based on Axon LoRA implementation patterns from DockYard and Bumblebee examples.
  """
  require Logger
  import Nx.Defn

  alias Mindset.Training.{Progress, Checkpoints, DataLoader}

  @doc """
  Start training with the given configuration and data.
  Returns {:ok, trained_state} or {:error, reason}
  """
  def train(config, data_path, format_type, checkpoint_id) do
    Logger.info("[Training] Starting training for #{config.model_name}")
    
    # Load model and tokenizer
    {:ok, model_info} = load_base_model(config.model_repo)
    {:ok, tokenizer} = Bumblebee.load_tokenizer({:hf, config.model_repo})
    
    # Load and prepare data
    {:ok, data_stats} = DataLoader.load(data_path, format_type)
    {train_data, _val_data} = split_data(data_stats.samples, config.train_split)
    
    # Create Axon model with LoRA
    {lora_model, lora_params, frozen_params} = create_lora_model(
      model_info.model, 
      model_info.params,
      config
    )
    
    # Prepare training data stream
    train_stream = create_data_stream(train_data, tokenizer, config)
    
    # Setup optimizer
    optimizer = create_optimizer(config)
    
    # Build training loop
    total_steps = calculate_total_steps(length(train_data), config)
    progress_state = Progress.init(total_steps)
    
    # Setup loss function for causal LM
    loss_fn = create_loss_function(model_info.model_type)
    
    # Train
    Logger.info("[Training] Starting training loop for #{total_steps} steps")
    
    trained_state = 
      lora_model
      |> Axon.Loop.trainer(loss_fn, optimizer, log: 1)
      |> Axon.Loop.handle(:iteration_completed, fn state ->
        # Update progress
        step = state.step
        epoch = state.epoch
        loss = state.loss
        lr = get_learning_rate(step, config)
        
        Progress.update(progress_state, step, epoch, loss, lr)
        
        # Save checkpoint periodically
        if rem(step, config.checkpoint_every) == 0 do
          checkpoint_state = %{
            step: step,
            epoch: epoch,
            loss: loss,
            learning_rate: lr,
            adapter_params: state.model_state,
            config: config
          }
          Checkpoints.save_checkpoint(checkpoint_id, step, checkpoint_state)
        end
        
        {:continue, state}
      end)
      |> Axon.Loop.run(
        train_stream, 
        lora_params, 
        epochs: config.epochs,
        compiler: config.compiler,
        device: :cuda
      )
    
    # Merge LoRA params with frozen params
    final_params = merge_lora_params(frozen_params, trained_state)
    
    {:ok, %{
      step: total_steps,
      epoch: config.epochs,
      loss: 0.0,  # Will be last loss from loop
      adapter_params: final_params,
      config: config,
      model_info: model_info
    }}
  end

  @doc """
  Save final adapter to registry
  """
  def save_final_adapter(state, checkpoint_id, name) do
    adapter_dir = Path.join(["priv", "models", "adapters", "#{checkpoint_id}_final"])
    File.mkdir_p!(adapter_dir)
    
    # Extract only LoRA parameters
    lora_params = 
      state.adapter_params
      |> Enum.filter(fn {name, _} -> String.contains?(to_string(name), "lora") end)
      |> Map.new()
    
    # Save as Elixir term for now (can convert to safetensors later)
    adapter_path = Path.join(adapter_dir, "adapter.bin")
    binary = :erlang.term_to_binary(lora_params)
    File.write!(adapter_path, binary)
    
    # Save config
    config_path = Path.join(adapter_dir, "config.json")
    File.write!(config_path, Jason.encode!(state.config, pretty: true))
    
    # Save metadata
    metadata = %{
      name: name,
      base_model: state.config.model_repo,
      checkpoint_id: checkpoint_id,
      created_at: DateTime.utc_now() |> DateTime.to_iso8601(),
      final_loss: state.loss
    }
    metadata_path = Path.join(adapter_dir, "metadata.json")
    File.write!(metadata_path, Jason.encode!(metadata, pretty: true))
    
    adapter_dir
  end

  # Private functions

  defp load_base_model(repo) do
    {:ok, model} = Bumblebee.load_model({:hf, repo})
    {:ok, params} = Bumblebee.load_params({:hf, repo})
    
    # Detect model type
    model_type = detect_model_type(model)
    
    %{
      model: model,
      params: params,
      model_type: model_type
    }
  end

  defp detect_model_type(model) do
    # Detect if it's a causal LM, seq2seq, etc.
    cond do
      Map.has_key?(model, :decoder) -> :seq2seq
      Map.has_key?(model, :lm_head) -> :causal_lm
      true -> :base
    end
  end

  defp create_lora_model(model, base_params, config) do
    rank = config.lora_rank
    alpha = config.lora_alpha
    dropout = config.lora_dropout
    
    # Create LoRA rewriter function
    lora_rewriter = fn [x], w, name, units ->
      # Only apply LoRA to target modules
      if should_apply_lora?(name, config.target_modules) do
        # Create LoRA layers: W_eff = W + (alpha/r) * B * A
        lora_a = Axon.param("#{name}.lora_a", fn -> 
          {units, rank} |> Nx.Random.key(42) |> Nx.Random.normal(0.0, 0.02) |> elem(0)
        end)
        
        lora_b = Axon.param("#{name}.lora_b", fn -> 
          {rank, units} |> Nx.Random.key(43) |> Nx.Random.normal(0.0, 0.02) |> elem(0) |> Nx.multiply(0.0)
        end)
        
        # Compute LoRA update: (alpha/r) * B * A
        lora_update = x 
          |> Axon.dense(lora_a, use_bias: false) 
          |> Axon.dense(lora_b, use_bias: false)
          |> Axon.multiply(alpha / rank)
        
        # Apply dropout
        lora_update = Axon.dropout(lora_update, rate: dropout)
        
        # Combine: base + LoRA
        base_out = Axon.dense(x, w, name: name)
        Axon.add(base_out, lora_update)
      else
        # Use original layer
        Axon.dense(x, w, name: name)
      end
    end
    
    # Apply LoRA to model graph
    lora_model = Axon.rewrite(model, [:dense], lora_rewriter)
    
    # Initialize LoRA parameters
    {init_fn, _predict_fn} = Axon.build(lora_model)
    lora_params = init_fn.()
    
    # Merge base params with LoRA params
    merged_params = 
      base_params
      |> Map.merge(lora_params)
      |> Enum.map(fn {k, v} -> 
        if String.contains?(to_string(k), "lora") do
          {k, v}
        else
          # Freeze base model params by wrapping in constant
          {k, Nx.Defn.Kernel.stop_grad(v)}
        end
      end)
      |> Map.new()
    
    # Separate frozen and trainable params
    frozen_params = Map.filter(base_params, fn {k, _} -> 
      not String.contains?(to_string(k), "lora")
    end)
    
    {lora_model, merged_params, frozen_params}
  end

  defp should_apply_lora?(layer_name, target_modules) do
    name_str = to_string(layer_name)
    Enum.any?(target_modules, fn target ->
      String.contains?(name_str, target)
    end)
  end

  defp create_data_stream(samples, tokenizer, config) do
    # Create infinite stream of batches
    Stream.cycle(samples)
    |> Stream.chunk_every(config.batch_size)
    |> Stream.map(fn batch ->
      # Prepare inputs
      prompts = Enum.map(batch, & &1.prompt)
      responses = Enum.map(batch, & &1.response)
      
      # Combine and tokenize
      texts = Enum.zip(prompts, responses) 
        |> Enum.map(fn {p, r} -> p <> " " <> r end)
      
      # Tokenize with Bumblebee
      tokenized = Bumblebee.apply_tokenizer(
        tokenizer, 
        texts, 
        length: config.max_seq_length,
        return_attention_mask: true,
        pad_direction: :right
      )
      
      # Convert to Nx tensors
      input_ids = Nx.tensor(tokenized["input_ids"])
      attention_mask = Nx.tensor(tokenized["attention_mask"])
      
      # Create labels (shifted inputs for causal LM)
      labels = input_ids |> Nx.slice([0, 1], [Nx.axis_size(input_ids, 0), Nx.axis_size(input_ids, 1) - 1])
      
      {%{
        "input_ids" => input_ids,
        "attention_mask" => attention_mask
      }, labels}
    end)
  end

  defp create_optimizer(config) do
    # Adam optimizer with learning rate scheduling
    :adam
    |> Polaris.Updates.build(%{
      learning_rate: config.learning_rate,
      b1: 0.9,
      b2: 0.999,
      eps: 1.0e-8,
      weight_decay: config.weight_decay
    })
  end

  defp create_loss_function(:causal_lm) do
    fn logits, labels ->
      # Shift logits to align with labels
      logits = Nx.slice(logits, [0, 0, 0], [Nx.axis_size(logits, 0), Nx.axis_size(logits, 1) - 1, Nx.axis_size(logits, 2)])
      
      # Reshape for cross entropy
      batch_size = Nx.axis_size(logits, 0)
      seq_len = Nx.axis_size(logits, 1)
      vocab_size = Nx.axis_size(logits, 2)
      
      logits = Nx.reshape(logits, {batch_size * seq_len, vocab_size})
      labels = Nx.reshape(labels, {batch_size * seq_len})
      
      # Cross entropy loss
      Axon.Losses.categorical_cross_entropy(labels, logits, reduction: :mean)
    end
  end

  defp create_loss_function(_) do
    # Default: MSE loss
    &Axon.Losses.mean_squared_error/2
  end

  defp split_data(samples, train_ratio) do
    total = length(samples)
    train_count = trunc(total * train_ratio)
    
    samples
    |> Enum.shuffle()
    |> Enum.split(train_count)
  end

  defp calculate_total_steps(num_samples, config) do
    steps_per_epoch = max(1, div(num_samples, config.batch_size))
    steps_per_epoch * config.epochs
  end

  defp get_learning_rate(step, config) do
    warmup_steps = config.warmup_steps
    total_steps = config.epochs * 1000
    
    cond do
      step < warmup_steps ->
        config.learning_rate * (step / warmup_steps)
      
      true ->
        decay_factor = max(0.1, 1.0 - (step - warmup_steps) / (total_steps - warmup_steps))
        config.learning_rate * decay_factor
    end
  end

  defp merge_lora_params(base_params, lora_params) do
    # Merge LoRA parameters back with base model
    base_params
    |> Map.merge(lora_params)
  end
end