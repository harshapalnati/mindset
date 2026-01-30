defmodule MindsetWeb.ChatLive do
  use MindsetWeb, :live_view
  alias Mindset.AI
  alias Mindset.Chat # Added alias to call your Chat context

  def mount(_params, _session, socket) do
    # Fetch all messages from the DB on load
    messages = Chat.list_messages()

    {:ok,
     assign(socket,
       messages: messages,
       response: "Waiting for your prompt ...",
       loading: false
     )}
  end

  def render(assigns) do
    ~H"""
    <div class="p-10 max-w-2xl mx-auto h-screen flex flex-col">
      <h1 class="text-3xl font-bold mb-6 text-indigo-600">Mindset AI</h1>

      <div id="chat-window" class="flex-1 overflow-y-auto p-4 mb-4 bg-gray-50 rounded-xl border border-gray-200 space-y-4">
        <%= for msg <- @messages do %>
          <div class={if msg.role == "user", do: "text-right", else: "text-left"}>
            <div class={
              "inline-block p-3 rounded-lg max-w-[80%] " <>
              if msg.role == "user", do: "bg-indigo-600 text-white", else: "bg-white text-gray-800 border"
            }>
              <p class="text-xs font-bold uppercase mb-1 opacity-70"><%= msg.role %></p>
              <p><%= msg.content %></p>
            </div>
          </div>
        <% end %>

        <%= if @loading do %>
          <div class="text-left animate-pulse">
            <div class="inline-block p-3 bg-gray-200 rounded-lg text-gray-500 italic">
              AI is thinking...
            </div>
          </div>
        <% end %>
      </div>

      <form phx-submit="ask_ai" class="flex gap-2 bg-white p-2 border-t">
        <input type="text" name="user_input" placeholder="Type something..."
               class="flex-1 p-2 border rounded-lg text-black focus:outline-none focus:ring-2 focus:ring-indigo-500"
               required autocomplete="off" />
        <button type="submit" disabled={@loading} class="bg-indigo-600 text-white px-6 py-2 rounded-lg hover:bg-indigo-700 disabled:bg-gray-400">
          Ask
        </button>
      </form>
    </div>
    """
  end

  def handle_event("ask_ai", %{"user_input" => input}, socket) do
    # 1. Save and immediately update the UI with the user message
    {:ok, user_msg} = Chat.create_message(%{role: "user", content: input})

    socket = assign(socket,
      messages: socket.assigns.messages ++ [user_msg],
      loading: true
    )

    # 2. Call the AI module
    case AI.generate_response(input) do
      {:ok, ai_text} ->
        # 3. Save AI response and update message list
        {:ok, ai_msg} = Chat.create_message(%{role: "assistant", content: ai_text})

        {:noreply,
         assign(socket,
           messages: socket.assigns.messages ++ [ai_msg],
           loading: false
         )}

      {:error, _reason} ->
        {:noreply, assign(socket, loading: false)}
    end
  end
end
