defmodule RumblWeb.UserLive do
  use RumblWeb, :live_view
  alias Rumbl.Accounts
  alias Rumbl.Multimedia
  alias Phoenix.LiveView.JS

  embed_templates "user_live/*"

  on_mount {RumblWeb.LiveUserAuth, :mount_current_user}

  @impl true
  def render(assigns), do: user_live(assigns)

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  @impl true
  def handle_event("save_profile", %{"user" => user_params}, socket) do
    case Accounts.update_user(socket.assigns.user, user_params) do
      {:ok, user} ->
        {:noreply,
         socket
         |> put_flash(:info, "Profile updated successfully")
         |> push_navigate(to: ~p"/users/#{user}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  @impl true
  def handle_event("save", %{"user" => user_params}, socket) do
    case Accounts.register_user(user_params) do
      {:ok, _user} ->
        {:noreply,
         socket
         |> put_flash(:info, "Account created successfully!")
         |> redirect(to: ~p"/sessions/new")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  @impl true
  def handle_event("delete_account", _params, socket) do
    current_user = socket.assigns.current_user
    viewed_user = socket.assigns.user

    if current_user.id && viewed_user && current_user.id == viewed_user.id do
      case Accounts.delete_user(socket.assigns.user) do
        {:ok, _user} ->
          {:noreply,
           socket
           |> put_flash(:info, "Account Deleted")
           |> push_navigate(to: ~p"/")}

        {:error, _reason} ->
          {:noreply, put_flash(socket, :error, "Could not delete account")}
      end
    end
  end

  defp apply_action(socket, action, %{"id" => id}) when action in [:show, :edit] do
    user = Accounts.get_user!(id)
    videos = Multimedia.list_user_videos(user)

    socket
    |> assign(:user, user)
    |> assign(:videos, videos)
    |> assign(:page_title, if(action == :show, do: "Show User", else: "Edit User"))
    |> assign(:form, to_form(Accounts.change_user(user)))
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "All Users")
    |> assign(:users, Accounts.list_users())
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New User")
    |> assign(:form, to_form(Accounts.change_user(%Rumbl.Accounts.User{})))
  end
end
