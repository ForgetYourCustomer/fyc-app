defmodule FycApp.Deposits do
  @moduledoc """
  The Deposits context.
  Handles creation and retrieval of deposit addresses for different currencies.
  """

  import Ecto.Query, warn: false
  alias FycApp.Repo
  alias FycApp.Wallets.{Balance, Deposit}
  alias FycApp.Bitserv

  @doc """
  Creates a new deposit address for the given balance.
  """
  def create_deposit_address(%Balance{} = balance) do
    case get_new_address_from_api(balance.currency) do
      {:ok, address_data} ->
        %Deposit{}
        |> Deposit.changeset(%{
          address: address_data.address,
          metadata: address_data.metadata,
          balance_id: balance.id
        })
        |> Repo.insert()

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Gets the latest active deposit address for the given balance.
  Returns nil if no active address exists.
  """
  def get_latest_deposit_address(%Balance{} = balance) do
    query =
      from d in Deposit,
        where: d.balance_id == ^balance.id and d.is_active == true,
        order_by: [desc: d.inserted_at],
        limit: 1

    Repo.one(query)
  end

  @doc """
  Lists all deposit addresses for a balance.
  Optionally filter by active status.
  """
  def list_deposit_addresses(%Balance{} = balance, opts \\ []) do
    active_only = Keyword.get(opts, :active_only, false)

    query =
      from d in Deposit,
        where: d.balance_id == ^balance.id,
        order_by: [desc: d.inserted_at]

    query =
      if active_only do
        where(query, [d], d.is_active == true)
      else
        query
      end

    Repo.all(query)
  end

  @doc """
  Gets a deposit by its address.
  Returns {:ok, deposit} if found, {:error, :not_found} otherwise.
  """
  def get_deposit_by_address(address) when is_binary(address) do
    case Repo.get_by(Deposit, address: address) do
      nil -> {:error, :not_found}
      deposit -> {:ok, deposit}
    end
  end

  @doc """
  Updates the metadata of a deposit.
  Only allows updating the metadata field.
  """
  def update_deposit_metadata(%Deposit{} = deposit, metadata) do
    deposit
    |> Deposit.update_changeset(%{metadata: metadata, is_active: deposit.is_active})
    |> Repo.update()
  end

  @doc """
  Deactivates a deposit address.
  """
  def deactivate_deposit(%Deposit{} = deposit) do
    deposit
    |> Deposit.deactivate_changeset()
    |> Repo.update()
  end

  # Private functions

  defp get_new_address_from_api("BTC") do
    case Bitserv.get_new_address() do
      {:ok, %{"success" => true, "address" => address, "error" => nil}} ->
        {:ok, %{address: address, metadata: %{}}}

      {:ok, %{"success" => false, "error" => error}} ->
        {:error, "Failed to get BTC address: #{error}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp get_new_address_from_api("USDT") do
    # Implement USDT address generation here
    {:ok, %{address: "0x742d35Cc6634C0532925a3b844Bc454e4438f44e", metadata: %{}}}
  end
end
