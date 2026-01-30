defmodule MindsetWeb.ChatLive do
  use MindsetWeb, :live_view
  alias Mindset.AI

  def mount(_params,_session,socket) do
    {:ok, assign(socket, response: "Waiting for your prompt ...", loading: false)}
  end

  def render(assigns) do
    ~H"""
    <div class="p-10 max-w-2xl mx-auto">
      <h1 class="text-3xl font-bold mb-6 text-indigo-600">Mindset AI</h1>

      <form phx-submit="ask_ai" class="flex gap-2 mb-8">
        <input type="text" name="user_input" placeholder="Type something..."
               class="flex-1 p-2 border rounded-lg text-black" required />
        <button type="submit" class="bg-indigo-600 text-white px-4 py-2 rounded-lg hover:bg-indigo-700">
          <%= if @loading, do: "Thinking...", else: "Ask" %>
        </button>
      </form>

      <div class="p-6 bg-white shadow-lg rounded-xl border border-gray-200">
        <h2 class="text-sm font-semibold text-gray-400 uppercase tracking-widest mb-2">AI Response</h2>
        <p class="text-gray-800 leading-relaxed italic">
          "<%= @response %>"
        </p>
      </div>
    </div>
    """
  end

  def handle_event("ask_ai", %{"user_input" => input}, socket) do


    #save user query
    Mindset.Chat.create_message(%{role: "user", content: input})

    socket = assign(socket, loading: true)

    # 2. Call the AI module
    case AI.generate_response(input) do
      {:ok, ai_text} ->
        Mindset.Chat.create_message(%{role: "assistant", content: ai_text})
        {:noreply, assign(socket, response: ai_text, loading: false)}

      {:error, _reason} ->

        {:noreply, assign(socket, response: "Error: Could not reach the LLM.", loading: false)}
    end
  end




end
