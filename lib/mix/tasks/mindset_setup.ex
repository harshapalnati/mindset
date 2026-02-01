defmodule Mix.Tasks.MindsetSetup do
  use Mix.Task

  @shortdoc "High-polish onboarding for Mindset AI"

  def run(_) do
    Application.ensure_all_started(:bumblebee)
    IO.write("\e[H\e[2J") # Clear screen

    # 1. OpenClaw Style Header
    Owl.IO.puts([
      Owl.Data.tag("\n 🛡️ Mindset AI 2026.1.31 ", :red),
      Owl.Data.tag(" (a5b4d22)", :light_black),
      " — \"The local brain for your Elixir stack.\"\n"
    ])

    " M I N D S E T "
    |> Owl.Box.new(border_style: :solid, border_color: :white, padding_x: 4)
    |> Owl.IO.puts()

    # 2. Section Header with Tree Connector (Fixed Color)
    Owl.IO.puts([
      "\n",
      Owl.Data.tag("│\n└─ ", :light_black),
      Owl.Data.tag("Mindset onboarding", :red)
    ])

    # 3. Security Box (Using :light_black for that muted look)
    Owl.Box.new([
      Owl.Data.tag("Security warning — please read.\n\n", :bright),
      "Mindset runs models locally. Ensure you have\n",
      "at least 8GB of free RAM before proceeding."
    ], border_style: :solid_rounded, border_color: :light_black)
    |> Owl.IO.puts()

    # 4. Tree Selections
    Owl.IO.puts([
      Owl.Data.tag("│\n", :light_black),
      Owl.Data.tag("◇ ", :green),
      "Identify processing unit?"
    ])

    _hardware = Owl.IO.select([
      "Local CPU (Standard)",
      "NVIDIA GPU (CUDA)"
    ])

    Owl.IO.puts([
      Owl.Data.tag("│\n", :light_black),
      Owl.Data.tag("◆ ", :cyan),
      "Select section to configure"
    ])

    model_choice = Owl.IO.select([
      "Workspace",
      "Model",
      "Daemon",
      "Health check",
      "Continue"
    ])

    handle_choice(model_choice)
  end

  defp handle_choice("Model") do
    model = Owl.IO.select(["TinyLlama-1.1B", "Gemma-2b"], label: "Select Brain:")
    download_model(model)
  end
  defp handle_choice("Continue"), do: Owl.IO.puts("\n🚀 Proceeding to Dashboard...")
  defp handle_choice(_), do: Owl.IO.puts("\nComing soon in Phase 3.")

  defp download_model(name) do
    repo = if name == "TinyLlama-1.1B", do: "TinyLlama/TinyLlama-1.1B-Chat-v1.0", else: "google/gemma-2b-it"
    Owl.IO.puts(["\n", Owl.Data.tag("│\n└─ 🚀 ", :light_black), "Initializing Download..."])
    {:ok, _} = Bumblebee.load_model({:hf, repo})
    Owl.IO.puts(["\n", Owl.Data.tag("✔ ", :green), "#{name} configured."])
  end
end
