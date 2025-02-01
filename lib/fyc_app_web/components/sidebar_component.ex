defmodule FycAppWeb.SidebarComponent do
  use Phoenix.Component

  def sidebar(assigns) do
    ~H"""
    <div class="sidebar-menu">
      <nav>
        <ul>
          <li><.link navigate="/wallet" class="sidebar-link">Wallet</.link></li>
          <li><.link navigate="/trade" class="sidebar-link">Trade</.link></li>
        </ul>
      </nav>
    </div>
    """
  end
end
