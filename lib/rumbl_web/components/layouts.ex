defmodule RumblWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use RumblWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :current_user, :map, default: nil, doc: "the current logged in user"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <div
      id="sidebar-backdrop"
      class="fixed inset-0 z-[80] hidden bg-black/60"
      phx-click={
        JS.hide(to: "#sidebar-backdrop")
        |> JS.add_class("-translate-x-full", to: "#app-sidebar")
      }
    >
    </div>

    <aside
      id="app-sidebar"
      class="fixed inset-y-0 left-0 z-[90] w-64 -translate-x-full border-r border-base-300 bg-base-100 text-base-content shadow-2xl transition-transform duration-300 ease-in-out"
    >
      <%= if @current_user do %>
        <div class="flex h-full flex-col p-4">
          <div class="mb-4 flex items-center justify-between">
            <h2 class="text-lg font-semibold">Menu</h2>
            <button
              class="btn btn-sm btn-ghost"
              phx-click={
                JS.hide(to: "#sidebar-backdrop")
                |> JS.add_class("-translate-x-full", to: "#app-sidebar")
              }
            >
              <.icon name="hero-x-mark" class="h-5 w-5" />
            </button>
          </div>
          <nav class="space-y-2">
            <.link
              navigate={~p"/watch-rooms/join"}
              class="block rounded-lg px-3 py-2 hover:bg-base-200"
            >
              Join Watch Room
            </.link>
            <.link
              navigate={~p"/videos"}
              class="block rounded-lg px-3 py-2 hover:bg-base-200"
            >
              Create Watch Room
            </.link>
          </nav>
        </div>
      <% else %>
        <div class="flex h-full flex-col p-4">
          <div class="mb-4 flex items-center justify-between">
            <h2 class="text-lg font-semibold">Menu</h2>
            <button
              class="btn btn-sm btn-ghost"
              phx-click={
                JS.hide(to: "#sidebar-backdrop")
                |> JS.add_class("-translate-x-full", to: "#app-sidebar")
              }
            >
              <.icon name="hero-x-mark" class="h-5 w-5" />
            </button>
          </div>
          <p class="mb-3 text-sm text-base-content/70">
            Log in first before joining or creating a watch room.
          </p>
          <nav class="space-y-2">
            <.link
              navigate={~p"/sessions/new"}
              class="block rounded-lg px-3 py-2 hover:bg-base-200"
            >
              Log in
            </.link>
            <.link
              navigate={~p"/users/new"}
              class="block rounded-lg px-3 py-2 hover:bg-base-200"
            >
              No account yet?
            </.link>
          </nav>
        </div>
      <% end %>
    </aside>
    <header class="navbar relative border-b border-base-300 bg-base-100">
      <button
        id="sidebar-toggle"
        class="btn btn-square btn-ghost"
        phx-click={
          JS.show(to: "#sidebar-backdrop")
          |> JS.remove_class("-translate-x-full", to: "#app-sidebar")
        }
        aria-label="Toggle menu"
      >
        <.icon name="hero-bars-3" class="h-5 w-5" />
      </button>

      <div class="pointer-events-none absolute inset-0 flex items-center justify-center">
        <.link
          navigate={~p"/"}
          class="pointer-events-auto inline-flex items-center gap-2 text-lg font-bold"
        >
          <img
            src={~p"/images/logo.svg"}
            alt="Rumbl logo"
            class="h-7 w-7 object-contain"
          />
          <span class="text-xl font-bold text-brand">Rumbl</span>
        </.link>
      </div>

      <div class="flex-1" />

      <div class="flex-none">
        <ul class="flex items-center gap-2 px-1 sm:gap-3">
          <%= if @current_user do %>
            <li>
              <.link navigate={~p"/videos"} class="btn btn-ghost">
                My Videos
              </.link>
            </li>
            <li class="hidden text-sm sm:block">
              Hello, <strong>{@current_user.name}</strong>
            </li>
            <li class="relative">
              <button
                id="user-menu-toggle"
                class="link"
                phx-click={JS.toggle(to: "#user-menu-dropdown")}
                aria-label="User actions"
              >
                <.icon name="hero-ellipsis-horizontal" class="h-5 w-5" />
              </button>
              <div
                id="user-menu-dropdown"
                class="absolute right-0 top-full z-[95] mt-2 hidden min-w-56 overflow-hidden rounded-lg border border-base-300 bg-base-100 shadow-xl"
                phx-click-away={JS.hide(to: "#user-menu-dropdown")}
              >
                <.link
                  href={~p"/users/#{@current_user}"}
                  class="block px-3 py-2 text-sm hover:bg-base-200"
                >
                  Profile
                </.link>
                <div class="flex items-center w-full p-2 hover:bg-base-200 rounded mb-1.5">
                  <span class="inline-flex items-center text-sm">
                    <.icon name="hero-moon" class="w-4 h-4 me-1.5" /> Dark mode
                  </span>
                  <label class="inline-flex items-center cursor-pointer ms-auto">
                    <input
                      id="dark-mode-switch"
                      type="checkbox"
                      class="sr-only peer"
                      phx-hook="ThemeSwitch"
                    />
                    <div class="relative w-9 h-5 bg-base-300 peer-focus:outline-none peer-focus:ring-2 peer-focus:ring-base-content/30 rounded-full peer-checked:after:translate-x-full rtl:peer-checked:after:-translate-x-full after:content-[''] after:absolute after:top-[2px] after:start-[2px] after:bg-base-100 after:rounded-full after:h-4 after:w-4 after:transition-all peer-checked:bg-base-content" />
                    <span class="ms-3 text-sm font-medium sr-only">Toggle dark mode</span>
                  </label>
                </div>
                <.link
                  href="/sessions"
                  method="delete"
                  class="block px-3 py-2 text-sm hover:bg-base-200"
                >
                  Log out
                </.link>
              </div>
            </li>
          <% else %>
            <li>
              <.link
                navigate={~p"/sessions/new"}
                class="btn bg-[#FF9900] text-black hover:bg-[#FF9900]/80 btn-ghost "
              >
                Log in
              </.link>
            </li>
            <li>
              <.link
                navigate={~p"/users/new"}
                class="btn bg-[#FF9900] text-black hover:bg-[#FF9900]/80 btn-ghost"
              >
                Register
              </.link>
            </li>
          <% end %>
        </ul>
      </div>
    </header>

    <main class="px-4 py-10 sm:px-6 lg:px-8">
      <div class="mx-auto max-w-4xl space-y-4">
        {render_slot(@inner_block)}
      </div>
    </main>

    <.flash_group flash={@flash} />
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Provides dark vs light theme toggle based on themes defined in app.css.

  See <head> in root.html.heex which applies the theme before page load.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div class="card relative flex flex-row items-center border-2 border-base-300 bg-base-300 rounded-full">
      <div class="absolute w-1/3 h-full rounded-full border-1 border-base-200 bg-base-100 brightness-200 left-0 [[data-theme=light]_&]:left-1/3 [[data-theme=dark]_&]:left-2/3 transition-[left]" />

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="system"
      >
        <.icon name="hero-computer-desktop-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
      >
        <.icon name="hero-sun-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
      >
        <.icon name="hero-moon-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
    </div>
    """
  end
end
