defmodule Mindset.Repo do
  use Ecto.Repo,
    otp_app: :mindset,
    adapter: Ecto.Adapters.Postgres
end
