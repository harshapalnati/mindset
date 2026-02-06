# Phase 1: The Hybrid Wrapper & Storage Unit

## Project Overview
Mindset AI is a full-stack chat application built with **Elixir** and **Phoenix LiveView**. Phase 1 established the foundational **Storage Unit** and UI, enabling the application to persist chat history while serving as the foundation for local AI inference.

---

## Technical Implementation

### Backend & Database
* **Engine**: Elixir 1.15+ and Erlang/OTP 26+
* **Database**: SQLite3 via Ecto for lightweight, local persistence
* **Schema**: `Message` schema in `lib/mindset/chat/message.ex` with `role` and `content` fields
* **Context**: `Mindset.Chat` module provides clean API for database operations

### Real-time UI
* **LiveView**: Reactive chat interface in `MindsetWeb.ChatLive`
* **Features**:
  - Real-time message updates without page refreshes
  - Loading states during AI inference
  - Persistent chat history from database
  - Responsive design with Tailwind CSS

### AI Integration Pattern
The UI uses a **Task.Supervisor** pattern for non-blocking AI calls:
```elixir
Task.Supervisor.start_child(Mindset.TaskSupervisor, fn ->
  case Mindset.Ai.Daemon.predict(input) do
    %{results: [%{text: ai_text}]} ->
      {:ok, ai_msg} = Chat.create_message(%{role: "assistant", content: ai_text})
      send(parent_pid, {:ai_finished, ai_msg})
  end
end)
```

---

## Challenges & Resolutions

| Incident | Root Cause | Resolution |
| :--- | :--- | :--- |
| **Path Resolution** | Relative paths in `dev.exs` resolving inconsistently | Used `Path.expand/2` for absolute paths |
| **Missing Tables** | Empty migration file marked as complete | Manually defined schema and ran `mix ecto.reset` |
| **Postgrex Conflicts** | Pluralization typo (`Messages` vs `Message`) | Corrected naming in Chat context |
| **Environment Variables** | `.env` file not loading automatically | Integrated `dotenvy` for auto-loading |

---

## Development Process

### 1. Building the Database (Storage Unit)
Created the persistence layer first:
* **Schema**: `lib/mindset/chat/message.ex` defines message structure
* **Migration**: `priv/repo/migrations/` creates the database table
* **Testing**: Verified with IEx: `Mindset.Repo.insert!(%Mindset.Chat.Message{role: "user", content: "Test"})`

### 2. Organizing Logic (Context Layer)
Created `lib/mindset/chat.ex` as the API boundary:
* `list_messages/0` - Retrieve all messages
* `create_message/1` - Insert new message
* Clean separation between DB and UI layers

### 3. Building the UI (Web Unit)
Created `lib/mindset_web/live/chat_live.ex`:
* **Mount**: Loads history from database on connection
* **Event Handler**: `ask_ai` saves user message, triggers AI, displays response
* **State Management**: Tracks loading state for UX feedback

---

## Verification

1. **Database Integrity**: Confirmed table existence via `sqlite_master`
2. **I/O Test**: Manual inserts via IEx verified persistence
3. **UI Test**: `Chat.list_messages/0` populates chat window correctly
4. **AI Integration**: Messages flow from UI → Database → AI → Database → UI

---

## Transition to Phase 2

Phase 1 provided the stable foundation for Phase 2's native AI integration:
- ✅ Persistent chat history
- ✅ Real-time UI updates
- ✅ Non-blocking AI inference
- ✅ Task supervision for fault tolerance

The UI pattern established here (async AI calls with loading states) remained unchanged when switching from cloud APIs to local models.