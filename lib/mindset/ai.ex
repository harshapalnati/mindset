defmodule Mindset.AI do
  require Logger

  def generate_response(prompt) do
    api_key = System.get_env("OPENAI_API_KEY")

    headers = [
      {"Authorization", "Bearer #{api_key}"},
      {"Content-Type", "application/json"}
    ]

    body = %{
      model: "gpt-4",
      messages: [%{role: "user", content: prompt}],
      temperature: 0.7
    }

    Req.post("https://api.openai.com/v1/chat/completions", headers: headers, json: body)
    |> parse_response()
  end

  def parse_response({:ok, %{status: 200, body: body}}) do
    response_text =
      body["choices"]
      |> List.first()
      |> get_in(["message", "content"])

    {:ok, response_text}
  end

  def parse_response({:ok, %{status: _status, body: body}}) do
    Logger.error("OpenAI Error: #{inspect(body)}")
    {:error, "API Error"}
  end

  def parse_response({:error, reason}) do
    Logger.error("Network Error: #{inspect(reason)}")
    {:error, "Network Error"}
  end
end
