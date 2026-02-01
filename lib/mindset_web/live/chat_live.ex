defmodule MindsetWeb.ChatLive do
  use MindsetWeb, :live_view
  alias Mindset.Chat

  def mount(_params, _session, socket) do
    # Fetch existing history from DB
    messages = Chat.list_messages()

    {:ok,
     assign(socket,
       messages: messages,
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

      <%!-- Note: Use phx-change if you want to clear input, or use a hook --%>
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
    # 1. Save and update UI with the user message immediately
    {:ok, user_msg} = Chat.create_message(%{role: "user", content: input})

    # 2. Capture the current process ID (The LiveView) to use inside the Task
    parent_pid = self()

    # 3. Start the AI task unlinked (so it doesn't crash the UI if it fails)
    Task.Supervisor.start_child(Mindset.TaskSupervisor, fn ->
      # Perform the heavy math
      case Mindset.Ai.Daemon.predict(input) do
        %{results: [%{text: ai_text}]} ->
          {:ok, ai_msg} = Chat.create_message(%{role: "assistant", content: ai_text})
          # Send message back to the LiveView process
          send(parent_pid, {:ai_finished, ai_msg})

        _error ->
          send(parent_pid, {:ai_error, "Model returned an empty response"})
      end
    end)

    {:noreply,
      socket
      |> assign(loading: true)
      |> assign(messages: socket.assigns.messages ++ [user_msg])
    }
  end

  def handle_info({:ai_finished, ai_msg}, socket) do
  Logger.info("📥 [UI] Received AI message for display: #{ai_msg.content}")

  {:noreply,
   assign(socket,
     messages: socket.assigns.messages ++ [ai_msg],
     loading: false
   )}
end

def handle_info({:ai_error, reason}, socket) do
  Logger.error("❌ [UI] AI Task failed. Reason: #{inspect(reason)}")
  {:noreply, assign(socket, loading: false)}
end
end
