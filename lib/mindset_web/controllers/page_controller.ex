defmodule MindsetWeb.PageController do
  use MindsetWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
