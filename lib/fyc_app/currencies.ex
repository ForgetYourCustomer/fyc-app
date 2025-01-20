defmodule FycApp.Currencies do
  @moduledoc """
  Module for handling supported currencies in the system.
  """

  @supported_currencies ["BTC", "USDT"]

  @doc """
  Returns list of supported currencies.
  """
  def supported_currencies, do: @supported_currencies

  @doc """
  Checks if a currency is supported.
  """
  def supported?(currency) when is_binary(currency) do
    currency in @supported_currencies
  end
  def supported?(_), do: false
end
