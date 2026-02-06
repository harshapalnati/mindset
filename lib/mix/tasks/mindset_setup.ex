defmodule Mix.Tasks.Mindset.Setup do
  use Mix.Task
  require Logger

  @shortdoc "Interactive onboarding for Mindset AI - setup models, hardware, and configuration"

  @models [
    %{
      id: "gpt2",
      name: "GPT-2",
      repo: "openai-community/gpt2",
      size: "124M",
      description: "Fast text completion - good for testing",
      ram_gb: 1,
      type: "Text Completion",
      recommended: true
    },
    %{
      id: "tinyllama",
      name: "TinyLlama 1.1B Chat",
      repo: "TinyLlama/TinyLlama-1.1B-Chat-v1.0",
      size: "1.1B",
      description: "Chat-tuned - conversational responses",
      ram_gb: 3,
      type: "Chat Model",
      recommended: true
    },
    %{
      id: "gemma",
      name: "Gemma 2B Instruct",
      repo: "google/gemma-2b-it",
      size: "2B",
      description: "Google's model - higher quality responses",
      ram_gb: 5,
      type: "Instruction Tuned",
      recommended: false
    },
    %{
      id: "phi2",
      name: "Phi-2",
      repo: "microsoft/phi-2",
      size: "2.7B",
      description: "Microsoft's model - reasoning focused",
      ram_gb: 6,
      type: "Reasoning",
      recommended: false
    }
  ]

  def run(_) do
    # Ensure required apps are started
    Application.ensure_all_started(:owl)
    Application.ensure_all_started(:bumblebee)
    
    # Clear screen
    IO.write("\e[H\e[2J\e[3J")
    
    # Display welcome banner
    display_banner()
    
    # Prerequisites check
    check_prerequisites()
    
    # Hardware selection
    hardware = select_hardware()
    
    # Model selection
    model = select_model()
    
    # Configuration review
    review_configuration(hardware, model)
    
    # Apply configuration
    apply_configuration(hardware, model)
    
    # Download and test model
    download_and_test_model(model)
    
    # Final instructions
    display_final_instructions()
  end

  defp display_banner() do
    # Fancy ASCII Art Logo
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
    ║              Local AI Inference Engine                        ║
    ║                                                               ║
    ╚═══════════════════════════════════════════════════════════════╝
    
    """
    
    Owl.IO.puts(Owl.Data.tag(logo, :cyan))
    
    Owl.Box.new(
      [
        Owl.Data.tag("Welcome to Mindset AI Setup\n\n", :bright),
        "This wizard will guide you through:\n",
        "  ◆ Checking system requirements\n",
        "  ◆ Selecting your AI model\n",
        "  ◆ Configuring hardware acceleration\n",
        "  ◆ Downloading and testing the model\n\n",
        Owl.Data.tag("Press Enter to continue...", :light_black)
      ],
      border_style: :solid_rounded,
      border_color: :blue,
      padding_x: 2
    )
    |> Owl.IO.puts()
    
    IO.gets("")
  end

  defp check_prerequisites() do
    IO.write("\e[H\e[2J\e[3J")
    
    Owl.IO.puts([
      Owl.Data.tag("\n◆ ", :cyan),
      Owl.Data.tag("System Prerequisites Check\n", :bright)
    ])
    
    checks = [
      check_elixir_version(),
      check_erlang_version(),
      check_available_memory(),
      check_platform()
    ]
    
    all_passed = Enum.all?(checks, fn {status, _} -> status == :ok end)
    
    if all_passed do
      Owl.IO.puts(["\n", Owl.Data.tag("✔ All prerequisites met!\n", :green)])
      Owl.IO.puts([Owl.Data.tag("Press Enter to continue...", :light_black)])
      IO.gets("")
    else
      Owl.IO.puts(["\n", Owl.Data.tag("✗ Some prerequisites failed. Please fix them and try again.\n", :red)])
      System.halt(1)
    end
  end

  defp check_elixir_version() do
    version = System.version()
    required = Version.parse!("1.15.0")
    current = Version.parse!(version)
    
    if Version.compare(current, required) != :lt do
      Owl.IO.puts(["  ", Owl.Data.tag("✔", :green), " Elixir #{version}"])
      {:ok, version}
    else
      Owl.IO.puts(["  ", Owl.Data.tag("✗", :red), " Elixir #{version} (requires 1.15+)"])
      {:error, version}
    end
  end

  defp check_erlang_version() do
    otp_version = :erlang.system_info(:otp_release) |> to_string()
    Owl.IO.puts(["  ", Owl.Data.tag("✔", :green), " Erlang/OTP #{otp_version}"])
    {:ok, otp_version}
  end

  defp check_available_memory() do
    # Try to detect available memory
    mem_gb = get_available_memory_gb()
    
    if mem_gb >= 4 do
      Owl.IO.puts(["  ", Owl.Data.tag("✔", :green), " Available RAM: ~#{mem_gb}GB"])
      {:ok, mem_gb}
    else
      Owl.IO.puts(["  ", Owl.Data.tag("⚠", :yellow), " Available RAM: ~#{mem_gb}GB (8GB+ recommended)"])
      {:warning, mem_gb}
    end
  end

  defp check_platform() do
    case :os.type() do
      {:unix, :linux} ->
        Owl.IO.puts(["  ", Owl.Data.tag("✔", :green), " Platform: Linux (EXLA supported)"])
        {:ok, :linux}
      
      {:win32, _} ->
        Owl.IO.puts(["  ", Owl.Data.tag("⚠", :yellow), " Platform: Windows (WSL recommended for EXLA)"])
        Owl.IO.puts(["    ", Owl.Data.tag("→", :cyan), " For best performance, run in WSL2"])
        {:warning, :windows}
      
      _ ->
        Owl.IO.puts(["  ", Owl.Data.tag("✔", :green), " Platform: Unix-like"])
        {:ok, :unix}
    end
  end

  defp get_available_memory_gb() do
    try do
      case File.read("/proc/meminfo") do
        {:ok, content} ->
          # Extract MemAvailable in kB
          available_kb = 
            content
            |> String.split("\n")
            |> Enum.find(fn line -> String.starts_with?(line, "MemAvailable:") end)
            |> case do
              nil -> 
                # Fallback to MemFree
                content
                |> String.split("\n")
                |> Enum.find(fn line -> String.starts_with?(line, "MemFree:") end)
                |> extract_kb()
              line -> extract_kb(line)
            end
          
          div(available_kb, 1024 * 1024)  # Convert to GB
        
        {:error, _} ->
          8  # Default assumption
      end
    rescue
      _ -> 8  # Default if anything fails
    end
  end

  defp extract_kb(nil), do: 8 * 1024 * 1024  # 8GB default
  defp extract_kb(line) do
    line
    |> String.split()
    |> Enum.at(1)
    |> String.to_integer()
  rescue
    _ -> 8 * 1024 * 1024
  end

  defp select_hardware() do
    IO.write("\e[H\e[2J\e[3J")
    
    Owl.IO.puts([
      Owl.Data.tag("\n◆ ", :cyan),
      Owl.Data.tag("Hardware Configuration\n", :bright)
    ])
    
    Owl.IO.puts([Owl.Data.tag("Select your processing unit:\n", :light_black)])
    
    hardware = Owl.IO.select(
      [
        "🖥️  CPU (Standard) - Works on all platforms",
        "⚡ NVIDIA GPU (CUDA) - Requires CUDA 12.0+ and Linux"
      ],
      label: "Processing Unit"
    )
    
    xla_target = if hardware =~ "GPU", do: "cuda120", else: "cpu"
    
    Owl.IO.puts(["\n", Owl.Data.tag("✔ ", :green), "Selected: #{hardware}"])
    Owl.IO.puts([Owl.Data.tag("  XLA Target: #{xla_target}\n", :light_black)])
    
    %{type: if(hardware =~ "GPU", do: :gpu, else: :cpu), xla_target: xla_target}
  end

  defp select_model() do
    IO.write("\e[H\e[2J\e[3J")
    
    Owl.IO.puts([
      Owl.Data.tag("\n◆ ", :cyan),
      Owl.Data.tag("Model Selection\n", :bright)
    ])
    
    Owl.IO.puts([Owl.Data.tag("Choose your AI model:\n", :light_black)])
    
    # Display model options
    model_options = Enum.map(@models, fn model ->
      recommended = if model.recommended, do: Owl.Data.tag(" [Recommended]", :green), else: ""
      "#{model.name}#{recommended}\n   ├─ Size: #{model.size} | RAM: ~#{model.ram_gb}GB\n   ├─ Type: #{model.type}\n   └─ #{model.description}"
    end)
    
    selected = Owl.IO.select(model_options, label: "AI Model")
    
    # Extract model name from selection
    model_name = selected |> String.split("\n") |> List.first() |> String.replace(~r/\s+\[Recommended\].*$/, "")
    
    model = Enum.find(@models, fn m -> m.name == model_name end)
    
    Owl.IO.puts(["\n", Owl.Data.tag("✔ ", :green), "Selected: #{model.name}"])
    Owl.IO.puts([Owl.Data.tag("  Repository: #{model.repo}\n", :light_black)])
    
    model
  end

  defp review_configuration(hardware, model) do
    IO.write("\e[H\e[2J\e[3J")
    
    Owl.IO.puts([
      Owl.Data.tag("\n◆ ", :cyan),
      Owl.Data.tag("Configuration Review\n", :bright)
    ])
    
    config_box = Owl.Box.new(
      [
        Owl.Data.tag("Hardware\n", :bright),
        "  Processing: #{if hardware.type == :gpu, do: "NVIDIA GPU (CUDA)", else: "CPU"}\n",
        "  XLA Target: #{hardware.xla_target}\n\n",
        Owl.Data.tag("Model\n", :bright),
        "  Name: #{model.name}\n",
        "  Repository: #{model.repo}\n",
        "  Parameters: #{model.size}\n",
        "  RAM Required: ~#{model.ram_gb}GB\n",
        "  Type: #{model.type}\n\n",
        Owl.Data.tag("Files to Create\n", :bright),
        "  • .env (environment configuration)\n",
        "  • Cached model in ~/.cache/bumblebee/"
      ],
      border_style: :solid,
      border_color: :blue,
      padding_x: 2
    )
    
    Owl.IO.puts(config_box)
    
    Owl.IO.puts(["\n", Owl.Data.tag("Proceed with this configuration?", :bright)])
    
    confirm = Owl.IO.select(["✓ Yes, continue", "✗ No, start over"])
    
    if confirm =~ "No" do
      Owl.IO.puts(["\n", Owl.Data.tag("Restarting setup...", :yellow)])
      Process.sleep(1000)
      run([])
    end
  end

  defp apply_configuration(hardware, model) do
    IO.write("\e[H\e[2J\e[3J")
    
    Owl.IO.puts([
      Owl.Data.tag("\n◆ ", :cyan),
      Owl.Data.tag("Applying Configuration\n", :bright)
    ])
    
    # Create .env file
    env_content = """
    # Mindset AI Configuration
    # Generated by mix mindset.setup
    
    # Model Configuration
    AI_MODEL_REPO=#{model.repo}
    
    # Hardware Configuration
    XLA_TARGET=#{hardware.xla_target}
    
    # Database
    DB_PATH="./priv/repo/mindset_dev.db"
    
    # Generation Settings
    MAX_NEW_TOKENS=50
    TEMPERATURE=0.7
    """
    
    File.write!(".env", env_content)
    Owl.IO.puts(["  ", Owl.Data.tag("✔", :green), " Created .env file"])
    
    # Update config if needed
    Owl.IO.puts(["  ", Owl.Data.tag("✔", :green), " Configuration saved"])
    
    Owl.IO.puts(["\n", Owl.Data.tag("Press Enter to download the model...", :light_black)])
    IO.gets("")
  end

  defp download_and_test_model(model) do
    IO.write("\e[H\e[2J\e[3J")
    
    Owl.IO.puts([
      Owl.Data.tag("\n◆ ", :cyan),
      Owl.Data.tag("Downloading Model\n", :bright)
    ])
    
    Owl.IO.puts([Owl.Data.tag("Model: #{model.name}\n", :light_black)])
    Owl.IO.puts([Owl.Data.tag("Repository: #{model.repo}\n", :light_black)])
    Owl.IO.puts([Owl.Data.tag("\nThis may take a few minutes depending on your connection...\n", :yellow)])
    
    # Show progress
    Owl.IO.puts(["\n", Owl.Data.tag("Loading model components:", :bright)])
    
    steps = [
      {"Loading model spec", fn -> Bumblebee.load_spec({:hf, model.repo}) end},
      {"Loading model weights", fn -> Bumblebee.load_model({:hf, model.repo}) end},
      {"Loading tokenizer", fn -> Bumblebee.load_tokenizer({:hf, model.repo}) end},
      {"Loading generation config", fn -> Bumblebee.load_generation_config({:hf, model.repo}) end}
    ]
    
    results = 
      Enum.map(steps, fn {name, fun} ->
        Owl.IO.write(["  ⏳ ", name, "... "])
        
        case fun.() do
          {:ok, result} ->
            Owl.IO.puts([Owl.Data.tag("✓", :green)])
            {:ok, result}
          
          {:error, reason} ->
            Owl.IO.puts([Owl.Data.tag("✗ Failed", :red)])
            {:error, reason}
        end
      end)
    
    if Enum.all?(results, fn {status, _} -> status == :ok end) do
      Owl.IO.puts(["\n", Owl.Data.tag("✔ Model downloaded successfully!\n", :green)])
      
      # Test inference
      Owl.IO.puts([Owl.Data.tag("Testing inference...\n", :bright)])
      
      [{:ok, spec}, {:ok, model_weights}, {:ok, tokenizer}, {:ok, generation_config}] = results
      
      generation_config = %{generation_config | max_new_tokens: 20}
      
      serving = Bumblebee.Text.generation(model_weights, tokenizer, generation_config,
        compile: [batch_size: 1, sequence_length: 64],
        defn_options: [compiler: Nx.Defn.Evaluator]
      )
      
      Owl.IO.write(["  Running test inference... "])
      
      {time_us, output} = :timer.tc(fn ->
        Nx.Serving.run(serving, "Hello")
      end)
      
      time_ms = div(time_us, 1000)
      
      case output do
        %{results: [%{text: text} | _]} ->
          Owl.IO.puts([Owl.Data.tag("✓", :green)])
          Owl.IO.puts(["\n  ", Owl.Data.tag("Response time: #{time_ms}ms", :light_black)])
          Owl.IO.puts(["  ", Owl.Data.tag("Generated: \"#{String.trim(text)}\"", :light_black)])
        
        _ ->
          Owl.IO.puts([Owl.Data.tag("⚠ Unexpected output format", :yellow)])
      end
      
      Owl.IO.puts(["\n", Owl.Data.tag("✔ Model is ready to use!\n", :green)])
    else
      Owl.IO.puts(["\n", Owl.Data.tag("✗ Failed to load model. Please check your internet connection and try again.\n", :red)])
    end
    
    Owl.IO.puts([Owl.Data.tag("Press Enter to continue...", :light_black)])
    IO.gets("")
  end

  defp display_final_instructions() do
    IO.write("\e[H\e[2J\e[3J")
    
    Owl.IO.puts([
      Owl.Data.tag("\n◆ ", :cyan),
      Owl.Data.tag("Setup Complete! 🎉\n", :bright)
    ])
    
    instructions = Owl.Box.new(
      [
        Owl.Data.tag("You're all set! Here's how to start Mindset:\n\n", :bright),
        Owl.Data.tag("1. Start the server:\n", :bright),
        "   mix phx.server\n\n",
        Owl.Data.tag("2. Open your browser:\n", :bright),
        "   http://localhost:4000/chat\n\n",
        Owl.Data.tag("3. Start chatting!\n", :bright),
        "   Type a message and press Enter\n\n",
        Owl.Data.tag("Useful Commands:\n", :bright),
        "  • mix mindset.setup    - Run this setup again\n",
        "  • iex -S mix           - Interactive console\n",
        "  • mix test             - Run tests\n\n",
        Owl.Data.tag("Configuration:\n", :bright),
        "  • Edit .env to change model or hardware settings\n",
        "  • Models are cached in ~/.cache/bumblebee/"
      ],
      border_style: :solid_rounded,
      border_color: :green,
      padding_x: 2
    )
    
    Owl.IO.puts(instructions)
    
    Owl.IO.puts([
      "\n",
      Owl.Data.tag("═══════════════════════════════════════════\n", :cyan),
      Owl.Data.tag("  Mindset AI is ready to go!\n", :bright),
      Owl.Data.tag("═══════════════════════════════════════════\n", :cyan)
    ])
  end
end