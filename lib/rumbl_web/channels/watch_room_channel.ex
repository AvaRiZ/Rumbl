defmodule RumblWeb.WatchRoomChannel do
  use RumblWeb, :channel

  alias Rumbl.{Accounts, WatchAlong}
  alias RumblWeb.Presence

  @impl true
  def join("watch_room:" <> room_code, _params, socket) do
    user_id = socket.assigns.user_id
    normalized_code = room_code |> String.trim() |> String.upcase()

    case Accounts.get_user(user_id) do
      nil ->
        {:error, %{reason: "User not found"}}

      user ->
        case WatchAlong.get_room_by_code(normalized_code) do
          nil ->
            {:error, %{reason: "Room not found"}}

          room ->
            topic = "watch_room:#{room.code}"

            with {:ok, _member} <- WatchAlong.join_room(room, user, room_role(room, user)) do
              presence_meta = %{
                user_id: user.id,
                username: user.username,
                joined_at: DateTime.utc_now()
              }

              case Presence.track(socket, "user:#{user.id}", presence_meta) do
                {:ok, _presence} ->
                  :ok

                {:error, {:already_tracked, _pid, _topic, _key}} ->
                  :ok

                {:error, _reason} ->
                  :error
              end
              |> case do
                :ok ->
                  send(self(), {:after_join, topic})

                  {:ok,
                   %{
                     room: %{
                       id: room.id,
                       code: room.code,
                       status: room.status,
                       playing: room.playing,
                       current_ms: room.current_ms
                     }
                   }, assign(socket, :room, room)}

                :error ->
                  {:error, %{reason: "Unable to join room"}}
              end
            else
              {:error, _reason} ->
                {:error, %{reason: "Unable to join room"}}
            end
        end
    end
  end

  @impl true
  def handle_info({:after_join, topic}, socket) do
    push(socket, "presence_state", Presence.list(topic))
    {:noreply, socket}
  end

  @impl true
  def terminate(_reason, socket) do
    case {socket.assigns[:room], Accounts.get_user(socket.assigns.user_id)} do
      {nil, _} ->
        :ok

      {_room, nil} ->
        :ok

      {room, user} ->
        _ = WatchAlong.leave_room(room, user)
        :ok
    end
  end

  @impl true
  def handle_in("sync_playback", params, socket) do
    room = socket.assigns.room
    user_id = socket.assigns.user_id

    if room.host_id != user_id do
      {:reply, {:error, %{reason: "Only the host can sync playback"}}, socket}
    else
      with {:ok, action} <- parse_action(params["action"]),
           {:ok, current_ms} <- parse_current_ms(params["current_ms"]) do
        playing =
          case {action, params["playing"]} do
            {"play", _} -> true
            {"pause", _} -> false
            {_, value} when value in [true, "true"] -> true
            {_, value} when value in [false, "false"] -> false
            _ -> room.playing
          end

        update_attrs = %{
          "playing" => playing,
          "current_ms" => current_ms,
          "last_synced_at" => DateTime.utc_now()
        }

        case WatchAlong.update_room_playback(room, update_attrs) do
          {:ok, updated_room} ->
            payload = %{
              action: action,
              playing: updated_room.playing,
              current_ms: updated_room.current_ms,
              user_id: user_id
            }

            broadcast_from!(socket, "playback_synced", payload)
            {:reply, :ok, assign(socket, :room, updated_room)}

          {:error, _changeset} ->
            {:reply, {:error, %{reason: "Unable to update playback"}}, socket}
        end
      else
        {:error, reason} ->
          {:reply, {:error, %{reason: reason}}, socket}
      end
    end
  end

  @impl true
  def handle_in("chat_message", _params, socket) do
    # TODO: Implement room chat messages (or re-use annotations).
    {:reply, {:error, %{reason: "Not implemented yet"}}, socket}
  end

  defp room_role(room, user) do
    if room.host_id == user.id, do: "host", else: "viewer"
  end

  defp parse_action(action) when action in ["play", "pause", "seek", "state"], do: {:ok, action}
  defp parse_action(_), do: {:error, "Invalid playback action"}

  defp parse_current_ms(value) when is_integer(value) and value >= 0, do: {:ok, value}

  defp parse_current_ms(value) when is_binary(value) do
    case Integer.parse(value) do
      {parsed, ""} when parsed >= 0 -> {:ok, parsed}
      _ -> {:error, "Invalid playback timestamp"}
    end
  end

  defp parse_current_ms(_), do: {:error, "Invalid playback timestamp"}
end
