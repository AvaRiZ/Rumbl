defmodule RumblWeb.RegistrationLive do
  use RumblWeb, :live_view
  alias Rumbl.Accounts
  alias Rumbl.Accounts.User

  embed_templates "registration_live/*"

  @impl true
  def render(assigns), do: registration_live(assigns)

  @impl true
  def mount(_params, _session, socket) do
    changeset = Accounts.User.registration_changeset(%User{}, %{})
    {:ok, assign(socket, form: to_form(changeset))}
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
        {:noreply,
         socket
         |> put_flash(:error, "Failed to create account. Please check the errors below.")
         |> assign(form: to_form(changeset))}
    end
  end
end
