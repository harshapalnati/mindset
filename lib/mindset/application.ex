defmodule Mindset.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do

     children = [
      # Start the Telemetry supervisor
      MindsetWeb.Telemetry,

      # Start the PubSub system for real-time AI streaming
      {Phoenix.PubSub, name: Mindset.PubSub},

      # Start the Ecto repository for saving your chat history
      Mindset.Repo,

      # Setup DNS clustering (standard Phoenix 1.7+ config)
      {DNSCluster, query: Application.get_env(:mindset, :dns_cluster_query) || :ignore},

      # --- THE BRAIN ---
      # Start the AI Daemon background process.
      # This loads the 2.2GB model into RAM once on boot.
      {Task.Supervisor, name: Mindset.TaskSupervisor},
      Mindset.Ai.Daemon,

      # Start the Endpoint (http/https server)
      MindsetWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Mindset.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    MindsetWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
