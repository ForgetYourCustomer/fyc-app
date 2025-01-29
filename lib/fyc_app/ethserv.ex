defmodule FycApp.Ethserv do
  @moduledoc """
  Facade module for Ethserv functionality.
  Provides a simple interface to the Ethserv HTTP API.
  """

  alias FycApp.Ethserv.Client

  @doc """
  Gets a new deposit address from the Bitserv API.
  """
  defdelegate get_new_address(), to: Client
end
