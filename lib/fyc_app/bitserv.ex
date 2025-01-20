defmodule FycApp.Bitserv do
  @moduledoc """
  Facade module for Bitserv functionality.
  Provides a simple interface to the Bitserv HTTP API.
  """

  alias FycApp.Bitserv.Client

  @doc """
  Gets a new deposit address from the Bitserv API.
  """
  defdelegate get_new_address(), to: Client
end
