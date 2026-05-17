defmodule ColcoordWeb.GameLiveTest do
  use ColcoordWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Colcoord.Settings

  setup do
    Settings.get_or_create()
    :ok
  end

  describe "mount" do
    test "renders the page", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")
      assert html =~ "Colcoord"
      assert html =~ "Game Modes"
      assert html =~ "Friends"
      assert html =~ "Available Games"
    end

    test "renders mode checkboxes", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")
      assert html =~ "Base 3P"
      assert html =~ "Cities &amp; Knights 4P"
    end
  end

  describe "toggle_mode" do
    test "unchecking a mode removes it from selected_modes", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      # Mode 0 ("Base 3P") is selected by default — uncheck it
      view
      |> element("input[type=checkbox][phx-value-code='0']")
      |> render_click()

      settings = Settings.get_or_create()
      assert 0 not in Settings.decode_modes(settings)
    end

    test "checking a previously unchecked mode adds it back", %{conn: conn} do
      # Start with mode 0 deselected
      Settings.get_or_create()
      |> Settings.changeset(%{selected_modes: Jason.encode!([1, 2, 3])})
      |> Colcoord.Repo.update!()

      {:ok, view, _html} = live(conn, "/")

      view
      |> element("input[type=checkbox][phx-value-code='0']")
      |> render_click()

      settings = Settings.get_or_create()
      assert 0 in Settings.decode_modes(settings)
    end
  end

  describe "add_friend" do
    test "adds a friend and shows badge", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      view
      |> form("form[phx-submit=add_friend]", %{"name" => "alice"})
      |> render_submit()

      assert render(view) =~ "alice"

      settings = Settings.get_or_create()
      assert "alice" in Settings.decode_friends(settings)
    end

    test "ignores blank name", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      view
      |> form("form[phx-submit=add_friend]", %{"name" => "  "})
      |> render_submit()

      settings = Settings.get_or_create()
      assert Settings.decode_friends(settings) == []
    end

    test "does not add duplicate friend", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      view
      |> form("form[phx-submit=add_friend]", %{"name" => "alice"})
      |> render_submit()

      view
      |> form("form[phx-submit=add_friend]", %{"name" => "alice"})
      |> render_submit()

      settings = Settings.get_or_create()
      assert Settings.decode_friends(settings) == ["alice"]
    end
  end

  describe "remove_friend" do
    test "removes a friend and hides badge", %{conn: conn} do
      Settings.get_or_create()
      |> Settings.changeset(%{friends: Jason.encode!(["alice"])})
      |> Colcoord.Repo.update!()

      {:ok, view, _html} = live(conn, "/")
      assert render(view) =~ "alice"

      view
      |> element("button[phx-value-name=alice]")
      |> render_click()

      refute render(view) =~ "alice"

      settings = Settings.get_or_create()
      assert Settings.decode_friends(settings) == []
    end
  end

  describe "toggle_auto_join" do
    test "enables auto_join and persists", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      view
      |> element("input.toggle[phx-click=toggle_auto_join]")
      |> render_click()

      settings = Settings.get_or_create()
      assert settings.auto_join == true
    end

    test "disables auto_join when already enabled", %{conn: conn} do
      Settings.get_or_create()
      |> Settings.changeset(%{auto_join: true})
      |> Colcoord.Repo.update!()

      {:ok, view, _html} = live(conn, "/")

      view
      |> element("input.toggle[phx-click=toggle_auto_join]")
      |> render_click()

      settings = Settings.get_or_create()
      assert settings.auto_join == false
    end
  end

  describe "open_game" do
    test "pushes open_game event with correct url", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      # Inject a room directly into the LiveView process and drain its mailbox
      send(
        view.pid,
        {:rooms_update, [%{"id" => "abc123", "mode" => 6, "players" => [], "maxPlayers" => 4}]}
      )

      :sys.get_state(view.pid)

      assert render(view) =~ "abc123"

      view
      |> element("button[phx-value-id=abc123]")
      |> render_click()

      assert_push_event(view, "open_game", %{url: "https://colonist.io/#abc123"})
    end
  end

  describe "popup_blocked" do
    test "shows fallback link when popup is blocked", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      refute render(view) =~ "Popup blocked"

      send(view.pid, {:push_event, "popup_blocked", %{"url" => "https://colonist.io/#abc"}})

      render_hook(view, "popup_blocked", %{"url" => "https://colonist.io/#abc"})

      assert render(view) =~ "Popup blocked"
      assert render(view) =~ "https://colonist.io/#abc"
    end
  end
end
