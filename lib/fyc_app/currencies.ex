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

  def satoshis_to_btc(satoshis) do
    Decimal.div(Decimal.new(satoshis), Decimal.new(100_000_000))
  end

  def btc_to_satoshis(btc) do
    Decimal.mult(Decimal.new(btc), Decimal.new(100_000_000))
    |> Decimal.to_integer()
  end

  def sunit_to_usdt(unit) do
    Decimal.div(Decimal.new(unit), Decimal.new(1_000_000))
  end

  def usdt_to_sunit(usdt) do
    Decimal.mult(Decimal.new(usdt), Decimal.new(1_000_000))
    |> Decimal.to_integer()
  end

  def total_price_sunit(sunit, satoshis) do
    satoshis_to_btc(satoshis)
    |> Decimal.mult(sunit)
    |> Decimal.to_integer()
  end

  def total_price_usdt(usdt, satoshis) do
    satoshis_to_btc(satoshis)
    |> Decimal.mult(usdt)
    |> Decimal.round(2)
    |> Decimal.normalize()
  end
end
