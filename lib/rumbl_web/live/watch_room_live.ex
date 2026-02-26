defmodule RumblWeb.WatchRoomLive do
  use RumblWeb, :live_view

  alias Rumbl.WatchAlong

  embed_templates "watch_room_live/*"

  @impl true
  def render(assigns), do: watch_room_live(assigns)

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:room_form, to_form(%{"code" => ""}, as: :room))
     |> assign(:page_title, "Join Watch Room")}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  @impl true
  def handle_event("join_room", %{"room" => %{"code" => code}}, socket) do
    code =
      code
      |> to_string()
      |> String.trim()
      |> String.upcase()

    if code == "" do
      {:noreply, put_flash(socket, :error, "Enter a room code")}
    else
      {:noreply, push_navigate(socket, to: ~p"/watch-rooms/#{code}")}
    end
  end

  defp apply_action(socket, :join, _params) do
    socket
    |> assign(:page_title, "Join Watch Room")
  end

  defp apply_action(socket, :show, %{"code" => code}) do
    room_code =
      code
      |> to_string()
      |> String.trim()
      |> String.upcase()

    case WatchAlong.get_room_by_code(room_code) do
      nil ->
        socket
        |> put_flash(:error, "Room #{room_code} was not found")
        |> push_navigate(to: ~p"/watch-rooms/join")

      room ->
        case socket.assigns.current_user do
          nil ->
            socket
            |> put_flash(:error, "You must be logged in to join this room")
            |> push_navigate(to: ~p"/sessions/new")

          _current_user ->
            socket
            |> put_flash(:info, "Joined room #{room.code}")
            |> push_navigate(to: ~p"/watch/#{room.video}?#{[room_code: room.code]}")
        end
    end
  end
end
