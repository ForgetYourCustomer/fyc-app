defmodule FycAppWeb.Layouts.SidebarComponent do
  use FycAppWeb, :live_component

  def render(assigns) do
    ~H"""
    <div class="fixed top-0 left-0 h-screen w-64 bg-gray-900 text-white shadow-lg">
      <div class="flex flex-col h-full">
        <!-- Logo/Brand -->
        <div class="p-4 border-b border-gray-800">
          <h1 class="text-xl font-bold">FYC App</h1>
        </div>

        <!-- Navigation Items -->
        <nav class="flex-1 p-4">
          <ul class="space-y-2">
            <li>
              <.link
                navigate={~p"/wallet"}
                class="flex items-center p-2 rounded-lg hover:bg-gray-800 transition-colors"
              >
                <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 mr-3" viewBox="0 0 20 20" fill="currentColor">
                  <path d="M4 4a2 2 0 00-2 2v1h16V6a2 2 0 00-2-2H4z" />
                  <path fill-rule="evenodd" d="M18 9H2v5a2 2 0 002 2h12a2 2 0 002-2V9zM4 13a1 1 0 011-1h1a1 1 0 110 2H5a1 1 0 01-1-1zm5-1a1 1 0 100 2h1a1 1 0 100-2H9z" clip-rule="evenodd" />
                </svg>
                <span>Wallet</span>
              </.link>
            </li>
            <li>
              <.link
                navigate={~p"/trade"}
                class="flex items-center p-2 rounded-lg hover:bg-gray-800 transition-colors"
              >
                <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 mr-3" viewBox="0 0 20 20" fill="currentColor">
                  <path d="M2 11a1 1 0 011-1h2a1 1 0 011 1v5a1 1 0 01-1 1H3a1 1 0 01-1-1v-5zm6-4a1 1 0 011-1h2a1 1 0 011 1v9a1 1 0 01-1 1H9a1 1 0 01-1-1V7zm6-3a1 1 0 011-1h2a1 1 0 011 1v12a1 1 0 01-1 1h-2a1 1 0 01-1-1V4z" />
                </svg>
                <span>Trade</span>
              </.link>
            </li>
          </ul>
        </nav>

        <!-- User Section at Bottom -->
        <div class="p-4 border-t border-gray-800">
          <div class="flex items-center space-x-2">
            <div class="flex-1">
              <%= if @current_user do %>
                <p class="text-sm"><%= @current_user.email %></p>
                <div class="flex space-x-2 mt-2">
                  <.link
                    navigate={~p"/users/settings"}
                    class="text-xs text-gray-400 hover:text-white transition-colors"
                  >
                    Settings
                  </.link>
                  <span class="text-gray-600">•</span>
                  <.link
                    href={~p"/users/log_out"}
                    method="delete"
                    class="text-xs text-gray-400 hover:text-white transition-colors"
                  >
                    Log out
                  </.link>
                </div>
              <% else %>
                <div class="flex space-x-2">
                  <.link
                    navigate={~p"/users/log_in"}
                    class="text-sm text-gray-400 hover:text-white transition-colors"
                  >
                    Log in
                  </.link>
                  <span class="text-gray-600">•</span>
                  <.link
                    navigate={~p"/users/register"}
                    class="text-sm text-gray-400 hover:text-white transition-colors"
                  >
                    Register
                  </.link>
                </div>
              <% end %>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
