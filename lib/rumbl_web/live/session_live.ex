defmodule RumblWeb.SessionLive do
  use RumblWeb, :live_view
  alias Rumbl.Accounts

  embed_templates "session_live/*"

  on_mount {RumblWeb.LiveUserAuth, :mount_current_user}

  @impl true
  def render(assigns), do: session_live(assigns)

  @impl true
  @spec mount(any(), any(), map()) :: {:ok, map()}
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Log In")
     |> assign(:trigger_submit, false)
     |> assign(:error_message, nil)
     |> assign(:form, to_form(%{}, as: :session))}
  end

  @impl true
  def handle_event("save", %{"session" => %{"username" => user, "password" => pass}}, socket) do
    case Accounts.authenticate_by_username_and_pass(user, pass) do
      {:ok, _user} ->
        # This flag tells the HEEx template to submit the form to the Controller
        {:noreply, assign(socket, trigger_submit: true)}

      {:error, _reason} ->
        {:noreply, assign(socket, error_message: "Invalid username or password")}
    end
  end
end
