defmodule FycApp.WalletsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `FycApp.Wallets` context.
  """

  @doc """
  Generate a wallet.
  """
  def wallet_fixture(attrs \\ %{}) do
    {:ok, wallet} =
      attrs
      |> Enum.into(%{

      })
      |> FycApp.Wallets.create_wallet()

    wallet
  end
end
