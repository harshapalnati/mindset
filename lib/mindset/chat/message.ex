defmodule Mindset.Chat.Message do
  use Ecto.Schema
  import Ecto.Changeset

  schema "messages" do
    field :role, :string
    field :content, :string

    timestamps()
  end

  def changeset(message, attrs) do
    message
    |> cast(attrs, [:role, :content])
    |> validate_required([:role, :content])
  end
end
