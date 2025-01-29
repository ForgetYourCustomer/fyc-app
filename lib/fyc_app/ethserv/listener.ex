defmodule FycApp.Ethserv.Listener do
  @moduledoc """
  ZeroMQ subscriber for listening to Bitserv transaction events.
  """

  use GenServer
  require Logger

  @zmq_host ~c"127.0.0.1"
  @zmq_port 5557

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    port = Keyword.get(opts, :zmq_port, @zmq_port)
    # Initialize ZeroMQ subscriber
    with {:ok, socket} <- :chumak.socket(:sub),
         :ok <- :chumak.subscribe(socket, "tx"),
         {:ok, connection_pid} <- :chumak.connect(socket, :tcp, @zmq_host, port) do
      # Start listening for messages
      schedule_receive()
      {:ok, %{zmq_socket: socket, connection_pid: connection_pid}}
    else
      error ->
        Logger.error("Failed to initialize ZMQ listener: #{inspect(error)}")
        {:stop, :zmq_init_failed}
    end
  end

  @impl true
  def handle_info(:receive_message, %{zmq_socket: socket} = state) do
    case :chumak.recv_multipart(socket) do
      {:ok, ["tx", message]} ->
        handle_transaction(message)

      {:ok, msg} ->
        Logger.warning("Received unexpected message format: #{inspect(msg)}")

      {:error, reason} ->
        Logger.error("ZMQ receive error: #{inspect(reason)}")
    end

    schedule_receive()
    {:noreply, state}
  end

  # Private functions

  defp schedule_receive do
    Process.send_after(self(), :receive_message, 0)
  end

  defp handle_transaction(message) do
    case Jason.decode(message) do
      {:ok, tx_data} ->
        deposit = tx_data["dpst"]["deposit"]

        IO.inspect(tx_data, label: "txdata")

        case FycApp.Wallets.process_deposit("USDT", %{"deposit" => deposit}) do
          {:ok, %{deposit_history: deposit_history, balance: balance}} ->
            Logger.info(
              "Transaction processed successfully. Balance updated to #{balance.amount} for #{balance.currency}"
            )

          {:error, :deposit_not_found} ->
            Logger.warning("Received transaction for unknown address: #{Enum.at(deposit, 0)}")

          {:error, :check_tx, :transaction_exists, _} ->
            Logger.info("Transaction already processed")

          {:error, reason} ->
            Logger.error("Failed to process deposit: #{inspect(reason)}")
        end

        :ok

      {:error, error} ->
        Logger.error("Failed to decode transaction: #{inspect(error)}")
        {:error, error}
    end
  end
end
