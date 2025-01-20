defmodule FycAppWeb.DepositDetails do
  use FycAppWeb, :html

  embed_templates "deposit_details/*"

  attr :currency, :string, required: true
  attr :deposit_address, :string, required: true
  attr :class, :string, default: nil

  def deposit_details(assigns) do
    ~H"""
    <div class={["mt-4 p-4 bg-gray-50", @class]}>
      <div class="flex items-center justify-between mb-4">
        <h3 class="text-lg font-semibold">Deposit {@currency}</h3>
      </div>
      <div class="space-y-4">
        <div>
          <label class="block text-sm font-medium text-gray-700">Deposit Address</label>
          <div class="mt-1 relative">
            <input
              type="text"
              readonly
              value={@deposit_address}
              class="block w-full pr-10 border-gray-300 rounded-md shadow-sm focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm"
            />
            <button
              type="button"
              phx-click={JS.dispatch("clipcopy", to: "#copy-target")}
              data-clipboard-text={@deposit_address}
              class="absolute inset-y-0 right-0 px-3 flex items-center bg-gray-50 rounded-r-md border-l hover:bg-gray-100"
            >
              <.icon name="hero-clipboard" class="h-4 w-4" />
            </button>
          </div>
        </div>
        <div class="flex justify-center">
          <img
            src={"https://api.qrserver.com/v1/create-qr-code/?size=150x150&data=#{@deposit_address}"}
            alt={"QR Code for #{@currency} deposit"}
            class="w-32 h-32"
          />
        </div>
      </div>
    </div>
    """
  end
end
