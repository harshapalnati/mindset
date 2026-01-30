defmodule Mindset.Chat do
  alias Postgrex.Messages
  alias Mindset.Repo
  alias Mindset.Chat.Message



  def create_message(attrs \\ %{}) do
    %Message{}
    |> Message.changeset(attrs)
    |> Repo.insert()
  end


  def list_messages do
    Mindset.Repo.all(Message)
  end
end
