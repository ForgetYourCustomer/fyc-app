defmodule FycApp.Bitserv.ListenerTest do
  use FycApp.DataCase, async: false
  alias FycApp.Bitserv.Listener
  require Logger

  # Using a different port for testing
  @zmq_port 5556

  setup do
    # Ensure Chumak application is started
    case Application.start(:chumak) do
      :ok -> :ok
      {:error, {:already_started, _}} -> :ok
    end

    # Create a publisher socket for testing
    {:ok, socket} = :chumak.socket(:pub)
    {:ok, _bind_pid} = :chumak.bind(socket, :tcp, ~c"127.0.0.1", @zmq_port)

    # Give some time for the bind to complete
    Process.sleep(10_000)

    # :ok = Listener.ensure_connected()

    on_exit(fn ->
      # Give time for cleanup
      Process.sleep(100)
      Application.stop(:chumak)
    end)

    %{pub_socket: socket}
  end

  test "listener receives messages correctly", %{pub_socket: socket} do
    # Set up a test process to receive notifications
    test_pid = self()

    # Get the existing listener process
    listener_pid = Process.whereis(Listener)
    IO.inspect("LISTENER PID: " <> inspect(listener_pid))

    assert is_pid(listener_pid), "Listener process should be running"

    # Set the test pid in the listener process
    Process.put(:test_pid, test_pid)

    # Give some time for the subscriber to connect
    Process.sleep(100)

    # Send a test message
    test_msg =
      Jason.encode!(%{
        "txid" => "test_tx_123",
        "address" => "test_address_456",
        "amount" => "1.23456789"
      })

    :ok = :chumak.send_multipart(socket, ["tx", test_msg])

    # Wait for the message to be processed
    assert_receive {:transaction_received, msg}, 1000
    assert msg["txid"] == "test_tx_123"
    assert msg["address"] == "test_address_456"
    assert msg["amount"] == "1.23456789"
  end
end
