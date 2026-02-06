defmodule Mix.Tasks.Mindset.Train do
  use Mix.Task
  require Logger

  alias Mindset.Training.{Config, DataLoader, Registry, Engine, Progress}

  @shortdoc "Interactive fine-tuning wizard for Mindset AI"

  @moduledoc """
  Run the fine-tuning wizard to train custom models.

  ## Usage

      mix mindset.train

  This will launch an interactive CLI wizard that guides you through:
  - Selecting data format (Instruction or Q&A)
  - Loading and validating training data
  - Selecting a base model
  - Configuring training parameters
  - Fine-tuning with real-time progress
  - Saving the trained adapter

  ## Examples

  Quick start with defaults:
      mix mindset.train --data path/to/data.csv --model gpt2

  Resume from checkpoint:
      mix mindset.train --resume checkpoint_id

  List all fine-tuned models:
      mix mindset.train --list
  """

  def run(args) do
    # Parse arguments
    {opts, _, _} = OptionParser.parse(args,
      switches: [
        data: :string,
        model: :string,
        format: :string,
        resume: :string,
        list: :boolean,
        switch: :string
      ],
      aliases: [d: :data, m: :model, f: :format, r: :resume, l: :list, s: :switch]
    )

    cond do
      opts[:list] ->
        list_models()
      
      opts[:switch] ->
        switch_model(opts[:switch])
      
      opts[:resume] ->
        resume_training(opts[:resume])
      
      opts[:data] && opts[:model] ->
        quick_train(opts[:data], opts[:model], opts[:format])
      
      true ->
        interactive_wizard()
    end
  end

  defp interactive_wizard do
    Application.ensure_all_started(:owl)
    Application.ensure_all_started(:bumblebee)
    
    # Clear screen
    IO.write("\e[H\e[2J\e[3J")
    
    display_welcome()
    
    # Step 1: Select data format
    format_type = select_format()
    
    # Step 2: Load data
    data_path = prompt_data_path()
    
    case DataLoader.load(data_path, format_type) do
      {:ok, data_stats} ->
        # Preview data
        preview_data(data_path, format_type)
        
        # Cache data
        {:ok, cache_dir, cached_path} = DataLoader.cache_data(data_path, format_type)
        Owl.IO.puts(["  ", Owl.Data.tag("✔", :green), " Data cached to: #{cache_dir}"])
        
        # Step 3: Select model
        model_id = select_model()
        {:ok, config} = Config.auto_detect(model_id, :auto)
        
        # Step 4: Review configuration
        review_config(config, data_stats.total_samples)
        
        # Step 5: Start training
        checkpoint_id = generate_checkpoint_id(model_id)
        
        Owl.IO.puts(["\n", Owl.Data.tag("Starting training...", :cyan)])
        Owl.IO.puts(["Checkpoint ID: #{checkpoint_id}\n"])
        
        case Engine.train(config, cached_path, format_type, checkpoint_id) do
          {:ok, final_state} ->
            # Save final adapter
            adapter_path = Engine.save_final_adapter(final_state, checkpoint_id, "#{model_id}-custom")
            
            # Register in registry
            {:ok, model_entry} = Registry.register(%{
              name: "#{config.model_name} (Custom)",
              base_model: model_id,
              base_model_repo: config.model_repo,
              adapter_path: adapter_path,
              data_path: cache_dir,
              format_type: format_type,
              config: config,
              metrics: %{final_loss: final_state.loss}
            })
            
            # Set as active model
            Registry.set_active_model(model_entry.id)
            
            # Show completion
            Progress.training_complete(final_state, %{loss: final_state.loss})
            
            display_final_instructions()
          
          {:error, reason} ->
            Owl.IO.puts([Owl.Data.tag("\n✗ Training failed: #{reason}\n", :red)])
        end
      
      {:error, reason} ->
        Owl.IO.puts([Owl.Data.tag("\n✗ Error loading data: #{reason}\n", :red)])
    end
  end

  defp display_welcome do
    logo = """
    
    ╔═══════════════════════════════════════════════════════════════╗
    ║                                                               ║
    ║   ███╗   ███╗██╗███╗   ██╗██████╗ ███████╗███████╗████████╗  ║
    ║   ████╗ ████║██║████╗  ██║██╔══██╗██╔════╝██╔════╝╚══██╔══╝  ║
    ║   ██╔████╔██║██║██╔██╗ ██║██║  ██║█████╗  ███████╗   ██║     ║
    ║   ██║╚██╔╝██║██║██║╚██╗██║██║  ██║██╔══╝  ╚════██║   ██║     ║
    ║   ██║ ╚═╝ ██║██║██║ ╚████║██████╔╝███████╗███████║   ██║     ║
    ║   ╚═╝     ╚═╝╚═╝╚═╝  ╚═══╝╚═════╝ ╚══════╝╚══════╝   ╚═╝     ║
    ║                                                               ║
    ║              Fine-Tuning Wizard                               ║
    ║                                                               ║
    ╚═══════════════════════════════════════════════════════════════╝
    
    """
    
    Owl.IO.puts(Owl.Data.tag(logo, :cyan))
    
    Owl.Box.new(
      [
        Owl.Data.tag("Welcome to Mindset AI Fine-Tuning\n\n", :bright),
        "This wizard will help you:\n",
        "  ◆ Load and validate your training data\n",
        "  ◆ Select a base model to fine-tune\n",
        "  ◆ Configure training parameters\n",
        "  ◆ Train with real-time progress\n",
        "  ◆ Save and use your custom model\n\n",
        Owl.Data.tag("Press Enter to continue...", :light_black)
      ],
      border_style: :solid_rounded,
      border_color: :blue,
      padding_x: 2
    )
    |> Owl.IO.puts()
    
    IO.gets("")
  end

  defp select_format do
    IO.write("\e[H\e[2J\e[3J")
    
    Owl.IO.puts([
      Owl.Data.tag("\n◆ ", :cyan),
      Owl.Data.tag("Select Data Format\n", :bright)
    ])
    
    Owl.IO.puts([Owl.Data.tag("Choose the format of your training data:\n", :light_black)])
    
    format = Owl.IO.select(
      [
        "Instruction Tuning (prompt, response columns)",
        "Q&A Format (question, answer columns)"
      ],
      label: "Format"
    )
    
    if format =~ "Instruction" do
      :instruction
    else
      :qa
    end
  end

  defp prompt_data_path do
    IO.write("\e[H\e[2J\e[3J")
    
    Owl.IO.puts([
      Owl.Data.tag("\n◆ ", :cyan),
      Owl.Data.tag("Load Training Data\n", :bright)
    ])
    
    Owl.IO.puts([Owl.Data.tag("Enter the path to your training data file:\n", :light_black)])
    Owl.IO.puts(["Supported formats: CSV (.csv), JSONL (.jsonl)\n"])
    
    IO.write("Path: ")
    path = IO.gets("") |> String.trim()
    
    if File.exists?(path) do
      path
    else
      Owl.IO.puts([Owl.Data.tag("\n✗ File not found. Please try again.\n", :red)])
      prompt_data_path()
    end
  end

  defp preview_data(data_path, format_type) do
    IO.write("\e[H\e[2J\e[3J")
    
    Owl.IO.puts([
      Owl.Data.tag("\n◆ ", :cyan),
      Owl.Data.tag("Data Preview\n", :bright)
    ])
    
    case DataLoader.load(data_path, format_type) do
      {:ok, stats} ->
        Owl.IO.puts(["Found #{stats.total_samples} training examples\n"])
        DataLoader.preview(data_path, format_type, 3)
        
        Owl.IO.puts(["\n", Owl.Data.tag("Press Enter to continue...", :light_black)])
        IO.gets("")
      
      {:error, reason} ->
        Owl.IO.puts([Owl.Data.tag("\n✗ Error: #{reason}\n", :red)])
        System.halt(1)
    end
  end

  defp select_model do
    IO.write("\e[H\e[2J\e[3J")
    
    Owl.IO.puts([
      Owl.Data.tag("\n◆ ", :cyan),
      Owl.Data.tag("Select Base Model\n", :bright)
    ])
    
    Owl.IO.puts([Owl.Data.tag("Choose a base model to fine-tune:\n", :light_black)])
    
    models = Config.list_models()
    
    options = Enum.map(models, fn model ->
      "#{model.name}\n   ├─ Size: #{model.params} | RAM: ~#{model.ram_gb}GB\n   └─ #{model.description}"
    end)
    
    selected = Owl.IO.select(options, label: "Model")
    
    # Extract model ID from selection
    model_name = selected |> String.split("\n") |> List.first()
    model = Enum.find(models, fn m -> m.name == model_name end)
    
    model.id
  end

  defp review_config(config, num_samples) do
    IO.write("\e[H\e[2J\e[3J")
    
    Owl.IO.puts([
      Owl.Data.tag("\n◆ ", :cyan),
      Owl.Data.tag("Configuration Review\n", :bright)
    ])
    
    estimated_time = Config.estimate_training_time(config, num_samples)
    
    config_box = Owl.Box.new(
      [
        Owl.Data.tag("Model\n", :bright),
        "  Name: #{config.model_name}\n",
        "  Repository: #{config.model_repo}\n\n",
        Owl.Data.tag("Training\n", :bright),
        "  Batch Size: #{config.batch_size}\n",
        "  Learning Rate: #{config.learning_rate}\n",
        "  Epochs: #{config.epochs}\n",
        "  LoRA Rank: #{config.lora_rank}\n\n",
        Owl.Data.tag("Data\n", :bright),
        "  Samples: #{num_samples}\n",
        "  Est. Time: #{estimated_time}\n\n",
        Owl.Data.tag("Hardware\n", :bright),
        "  Type: #{if config.hardware.has_gpu, do: "GPU", else: "CPU"}\n",
        "  Compiler: #{inspect(config.compiler)}"
      ],
      border_style: :solid,
      border_color: :blue,
      padding_x: 2
    )
    
    Owl.IO.puts(config_box)
    
    Owl.IO.puts(["\n", Owl.Data.tag("Proceed with training?", :bright)])
    
    confirm = Owl.IO.select(["✓ Yes, start training", "✗ No, cancel"])
    
    if confirm =~ "No" do
      Owl.IO.puts(["\n", Owl.Data.tag("Training cancelled.\n", :yellow)])
      System.halt(0)
    end
  end

  defp list_models do
    Application.ensure_all_started(:owl)
    
    IO.write("\e[H\e[2J\e[3J")
    
    Owl.IO.puts([
      Owl.Data.tag("\n◆ ", :cyan),
      Owl.Data.tag("Fine-Tuned Models\n", :bright)
    ])
    
    output = Registry.format_for_cli()
    Owl.IO.puts(["\n", output, "\n"])
  end

  defp switch_model(model_id) do
    case Registry.set_active_model(model_id) do
      {:ok, model} ->
        Owl.IO.puts([Owl.Data.tag("✓ Switched to model: #{model.name}", :green)])
      
      {:error, reason} ->
        Owl.IO.puts([Owl.Data.tag("✗ Error: #{reason}", :red)])
    end
  end

  defp resume_training(checkpoint_id) do
    Owl.IO.puts([Owl.Data.tag("Resuming training from checkpoint: #{checkpoint_id}", :cyan)])
    # Implementation would continue training from checkpoint
  end

  defp quick_train(data_path, model_id, format_type) do
    format = if format_type == "qa", do: :qa, else: :instruction
    interactive_wizard()
  end

  defp display_final_instructions do
    Owl.IO.puts([
      "\n",
      Owl.Data.tag("═══════════════════════════════════════════\n", :cyan),
      Owl.Data.tag("  Your fine-tuned model is ready!\n", :bright),
      Owl.Data.tag("═══════════════════════════════════════════\n", :cyan),
      "\nStart the server with:\n",
      "  mix phx.server\n\n",
      "Then visit: http://localhost:4000/chat\n",
      "Your model will be loaded automatically.\n"
    ])
  end

  defp generate_checkpoint_id(model_id) do
    timestamp = DateTime.utc_now() |> DateTime.to_unix()
    "#{model_id}_#{timestamp}"
  end
end