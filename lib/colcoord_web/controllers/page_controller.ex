defmodule ColcoordWeb.PageController do
  use ColcoordWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
