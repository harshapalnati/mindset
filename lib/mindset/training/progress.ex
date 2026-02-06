defmodule Mindset.Training.Progress do
  @moduledoc """
  Real-time progress tracking and display for training.
  Uses Owl for beautiful CLI output.
  """
  require Logger

  @doc """
  Initialize progress tracking state
  """
  def init(total_steps) do
    %{
      total_steps: total_steps,
      current_step: 0,
      current_epoch: 1,
      total_epochs: 3,
      loss_history: [],
      best_loss: :infinity,
      learning_rate: 0.0001,
      start_time: System.monotonic_time(:second),
      last_update: System.monotonic_time(:second),
      status: :running
    }
  end

  @doc """
  Update progress with new step information
  """
  def update(state, step, epoch, loss, learning_rate) do
    now = System.monotonic_time(:second)
    elapsed = now - state.start_time
    
    new_state = %{state |
      current_step: step,
      current_epoch: epoch,
      loss_history: [loss | state.loss_history] |> Enum.take(100),
      best_loss: min(loss, state.best_loss),
      learning_rate: learning_rate,
      last_update: now
    }
    
    # Calculate ETA
    steps_remaining = state.total_steps - step
    time_per_step = if step > 0, do: elapsed / step, else: 1
    eta_seconds = trunc(steps_remaining * time_per_step)
    
    new_state = Map.put(new_state, :eta_seconds, eta_seconds)
    
    display_progress(new_state)
    
    new_state
  end

  @doc """
  Display checkpoint saved notification
  """
  def checkpoint_saved(step, path) do
    Owl.IO.puts([
      "\n  ",
      Owl.Data.tag("💾 Checkpoint saved", :cyan),
      " at step #{step}"
    ])
    Owl.IO.puts(["     ", Owl.Data.tag(path, :light_black)])
  end

  @doc """
  Display training complete message
  """
  def training_complete(state, final_metrics) do
    total_time = System.monotonic_time(:second) - state.start_time
    minutes = div(total_time, 60)
    seconds = rem(total_time, 60)
    
    Owl.IO.puts(["\n"])
    
    Owl.Box.new(
      [
        Owl.Data.tag("Training Complete!\n\n", :green),
        "Final Loss: #{:erlang.float_to_binary(final_metrics.loss, decimals: 4)}\n",
        "Best Loss: #{:erlang.float_to_binary(state.best_loss, decimals: 4)}\n",
        "Total Time: #{minutes}m #{seconds}s\n",
        "Steps: #{state.current_step}/#{state.total_steps}"
      ],
      border_style: :solid_rounded,
      border_color: :green,
      padding_x: 2
    )
    |> Owl.IO.puts()
  end

  @doc """
  Display training paused message
  """
  def training_paused(state) do
    Owl.IO.puts(["\n", Owl.Data.tag("⏸️  Training paused. Press Enter to resume or Ctrl+C to exit.", :yellow)])
  end

  @doc """
  Display training resumed message
  """
  def training_resumed do
    Owl.IO.puts([Owl.Data.tag("▶️  Training resumed", :green), "\n"])
  end

  @doc """
  Format loss as a mini graph
  """
  def format_loss_graph(loss_history, width \\ 50) do
    if length(loss_history) < 2 do
      ""
    else
      losses = Enum.reverse(loss_history)
      min_loss = Enum.min(losses)
      max_loss = Enum.max(losses)
      range = max(max_loss - min_loss, 0.001)
      
      step_size = max(1, div(length(losses), width))
      
      sampled = 
        losses
        |> Enum.take_every(step_size)
        |> Enum.take(width)
      
      sampled
      |> Enum.map(fn loss ->
        normalized = (loss - min_loss) / range
        height = trunc(normalized * 8)
        graph_char(height)
      end)
      |> Enum.join()
    end
  end

  # Private functions

  defp display_progress(state) do
    # Clear previous lines
    IO.write("\e[2K\e[1G")
    
    percent = trunc(state.current_step / state.total_steps * 100)
    progress_bar = generate_progress_bar(percent, 40)
    
    # Format time
    elapsed = System.monotonic_time(:second) - state.start_time
    eta_min = div(state.eta_seconds || 0, 60)
    eta_sec = rem(state.eta_seconds || 0, 60)
    
    # Format loss
    current_loss = List.first(state.loss_history) || 0.0
    loss_str = :erlang.float_to_binary(current_loss, decimals: 4)
    
    # Determine trend
    loss_trend = 
      case state.loss_history do
        [current, previous | _] when current < previous -> Owl.Data.tag("▼", :green)
        [current, previous | _] when current > previous -> Owl.Data.tag("▲", :red)
        _ -> "─"
      end
    
    # Build display
    Owl.IO.puts([
      "\e[H\e[2J",  # Clear screen
      "\n",
      Owl.Data.tag("Training Progress\n", :cyan),
      "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n",
      "Model: Fine-tuning in progress\n",
      "Epoch: #{state.current_epoch}/#{state.total_epochs} | Step: #{state.current_step}/#{state.total_steps}\n\n",
      "#{progress_bar} #{percent}%\n\n",
      "Loss: #{loss_str} #{loss_trend} | Best: #{:erlang.float_to_binary(state.best_loss, decimals: 4)}\n",
      "LR: #{:erlang.float_to_binary(state.learning_rate, decimals: 6)}\n",
      "Time: #{format_time(elapsed)} elapsed, #{eta_min}m #{eta_sec}s remaining\n\n",
      Owl.Data.tag("Loss History:\n", :bright),
      format_loss_graph(state.loss_history, 50),
      "\n\n",
      Owl.Data.tag("[Ctrl+C to pause/save checkpoint]", :light_black)
    ])
  end

  defp generate_progress_bar(percent, width) do
    filled = trunc(percent / 100 * width)
    empty = width - filled
    
    "[" <> 
    String.duplicate("█", filled) <> 
    String.duplicate("░", empty) <> 
    "]"
  end

  defp format_time(seconds) do
    min = div(seconds, 60)
    sec = rem(seconds, 60)
    "#{min}m #{sec}s"
  end

  defp graph_char(0), do: "▁"
  defp graph_char(1), do: "▂"
  defp graph_char(2), do: "▃"
  defp graph_char(3), do: "▄"
  defp graph_char(4), do: "▅"
  defp graph_char(5), do: "▆"
  defp graph_char(6), do: "▇"
  defp graph_char(7), do: "█"
  defp graph_char(_), do: "█"
end