defmodule Mindset.CLI do
  @moduledoc """
  Main entry point for the Mindset CLI binary (escript).
  
  Usage: mindset [command] [options]
  
  Commands:
    setup              Run interactive setup wizard
    train              Fine-tune a model with your data
    start              Start the Mindset server
    console            Start interactive Elixir console
    status             Check server and model status
    models             List available fine-tuned models
    switch <model-id>  Switch to a different model
    stop               Stop the running server
    test               Run test inference
    help               Show help message
  """

  require Logger

  alias Mindset.Training.{Config, DataLoader, Registry, Engine, Progress}

  def main(args) do
    # Parse command line arguments
    {opts, remaining, invalid} = OptionParser.parse(args,
      switches: [
        data: :string,
        model: :string,
        format: :string,
        resume: :string,
        list: :boolean,
        switch: :string,
        help: :boolean
      ],
      aliases: [d: :data, m: :model, f: :format, r: :resume, l: :list, s: :switch, h: :help]
    )

    # Start required applications
    start_applications()

    # Dispatch to appropriate command
    command = List.first(remaining) || "help"
    
    case command do
      "setup" ->
        cmd_setup()
      
      "train" ->
        cmd_train(opts, Enum.drop(remaining, 1))
      
      "start" ->
        cmd_start()
      
      "console" ->
        cmd_console()
      
      "status" ->
        cmd_status()
      
      "models" ->
        cmd_models()
      
      "switch" ->
        cmd_switch(List.first(Enum.drop(remaining, 1)))
      
      "stop" ->
        cmd_stop()
      
      "test" ->
        cmd_test()
      
      "help" ->
        show_help()
      
      _ ->
        IO.puts("Unknown command: #{command}")
        IO.puts("Run 'mindset help' for usage")
        System.halt(1)
    end
  end

  defp start_applications do
    # Start applications needed for CLI
    {:ok, _} = Application.ensure_all_started(:owl)
    {:ok, _} = Application.ensure_all_started(:bumblebee)
    :ok
  end

  defp cmd_setup do
    IO.puts("Running Mindset setup wizard...")
    # Delegate to the Mix task
    Mix.Task.run("mindset.setup")
  end

  defp cmd_train(opts, _args) do
    cond do
      opts[:list] ->
        cmd_models()
      
      opts[:switch] ->
        cmd_switch(opts[:switch])
      
      opts[:data] && opts[:model] ->
        quick_train(opts[:data], opts[:model], opts[:format])
      
      true ->
        interactive_training()
    end
  end

  defp cmd_start do
    IO.puts("Starting Mindset server...")
    # Start the Phoenix application
    Application.ensure_all_started(:mindset)
    
    # Keep the process alive
    IO.puts("Server running at http://localhost:4000")
    IO.puts("Press Ctrl+C to stop")
    
    Process.sleep(:infinity)
  end

  defp cmd_console do
    IO.puts("Starting IEx console...")
    # This would need to be handled differently in escript
    IO.puts("Use 'iex -S mix' for interactive console")
  end

  defp cmd_status do
    IO.puts("Mindset Status Report")
    IO.puts("======================")
    
    # Elixir version
    IO.puts("Elixir: #{System.version()}")
    
    # Check registry
    case Registry.list_models() do
      [] ->
        IO.puts("Models: No fine-tuned models found")
      
      models ->
        IO.puts("Models: #{length(models)} fine-tuned model(s)")
        Enum.each(models, fn model ->
          status = if model.is_active, do: " [ACTIVE]", else: ""
          IO.puts("  - #{model.name}#{status}")
        end)
    end
    
    # Active model
    case Registry.get_active_model() do
      {:ok, model} ->
        IO.puts("Active Model: #{model.name}")
      
      {:error, _} ->
        IO.puts("Active Model: Using base model from .env")
    end
  end

  defp cmd_models do
    IO.puts(Registry.format_for_cli())
  end

  defp cmd_switch(nil) do
    IO.puts("Error: Please provide a model ID")
    IO.puts("Usage: mindset switch <model-id>")
    IO.puts("Run 'mindset models' to see available models")
    System.halt(1)
  end

  defp cmd_switch(model_id) do
    case Registry.set_active_model(model_id) do
      {:ok, model} ->
        IO.puts("✓ Switched to model: #{model.name}")
        IO.puts("Restart the server to use this model")
      
      {:error, reason} ->
        IO.puts("Error: #{reason}")
        System.halt(1)
    end
  end

  defp cmd_stop do
    IO.puts("Note: Use Ctrl+C to stop the server")
  end

  defp cmd_test do
    IO.puts("Testing AI inference...")
    
    # Start the application
    Application.ensure_all_started(:mindset)
    Process.sleep(2000)
    
    result = Mindset.Ai.Daemon.predict("Hello, how are you?")
    IO.inspect(result)
  end

  defp interactive_training do
    # Clear screen
    IO.write("\e[H\e[2J\e[3J")
    
    show_welcome()
    
    # Select format
    format_type = select_format()
    
    # Get data path
    data_path = prompt_data_path()
    
    case DataLoader.load(data_path, format_type) do
      {:ok, data_stats} ->
        IO.puts("Found #{data_stats.total_samples} training examples")
        
        # Preview
        DataLoader.preview(data_path, format_type, 3)
        
        # Cache data
        {:ok, cache_dir, cached_path} = DataLoader.cache_data(data_path, format_type)
        IO.puts("Data cached to: #{cache_dir}")
        
        # Select model
        model_id = select_model()
        {:ok, config} = Config.auto_detect(model_id, :auto)
        
        # Show config
        IO.puts("\nConfiguration:")
        IO.puts(Config.format_for_display(config))
        
        # Start training
        checkpoint_id = "#{model_id}_#{:os.system_time(:millisecond)}"
        IO.puts("\nStarting training with checkpoint ID: #{checkpoint_id}")
        
        case Engine.train(config, cached_path, format_type, checkpoint_id) do
          {:ok, final_state} ->
            # Save and register
            adapter_path = Engine.save_final_adapter(final_state, checkpoint_id, "#{model_id}-custom")
            
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
            
            Registry.set_active_model(model_entry.id)
            
            IO.puts("\n✓ Training complete!")
            IO.puts("Model saved and activated.")
            IO.puts("Start the server with: mindset start")
          
          {:error, reason} ->
            IO.puts("Training failed: #{reason}")
            System.halt(1)
        end
      
      {:error, reason} ->
        IO.puts("Error loading data: #{reason}")
        System.halt(1)
    end
  end

  defp quick_train(data_path, model_id, format_type) do
    format = if format_type == "qa", do: :qa, else: :instruction
    interactive_training()
  end

  defp show_welcome do
    IO.puts("""
    
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
    
    """)
  end

  defp select_format do
    IO.puts("\nSelect data format:")
    IO.puts("1. Instruction Tuning (prompt, response)")
    IO.puts("2. Q&A Format (question, answer)")
    
    case IO.gets("> ") |> String.trim() do
      "2" -> :qa
      _ -> :instruction
    end
  end

  defp prompt_data_path do
    IO.puts("\nEnter path to training data (CSV or JSONL):")
    path = IO.gets("> ") |> String.trim()
    
    if File.exists?(path) do
      path
    else
      IO.puts("File not found. Please try again.")
      prompt_data_path()
    end
  end

  defp select_model do
    IO.puts("\nSelect base model:")
    
    models = Config.list_models()
    Enum.each(models, fn model ->
      IO.puts("#{model.id}. #{model.name} (#{model.params})")
    end)
    
    selection = IO.gets("> ") |> String.trim()
    
    if Config.get_model(selection) do
      selection
    else
      IO.puts("Invalid selection. Please try again.")
      select_model()
    end
  end

  defp show_help do
    IO.puts("""
    Mindset AI CLI
    
    Usage: mindset <command> [options]
    
    Commands:
      setup              Run interactive setup wizard
      train              Fine-tune a model with your data
      start              Start the Mindset server
      console            Start interactive Elixir console
      status             Check server and model status
      models             List available fine-tuned models
      switch <model-id>  Switch to a different model
      stop               Stop the running server
      test               Run test inference
      help               Show this help message
    
    Examples:
      mindset setup                    # First-time setup
      mindset train                    # Interactive training wizard
      mindset train --data data.csv --model gpt2
      mindset start                    # Start server
      mindset status                   # Check system status
    """)
  end
end