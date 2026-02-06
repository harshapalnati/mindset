defmodule Mindset.AiTest do
  use ExUnit.Case
  alias Mindset.AI

  describe "parse_repsosne/1" do
    test "extract text from a valid OpenAI JSON structure" do
      # A fake test data that looks OpenAI

      fake_reposne = %{
        status: 200,
        body: %{
          "choices" => [
            %{"message" => %{"content" => "I am awesome"}}
          ]
        }
      }

      result = AI.parse_response({:ok, fake_reposne})

      assert result == {:ok, "I am awesome"}
    end
  end
end
