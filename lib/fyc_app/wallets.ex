defmodule FycApp.Wallets do
  @moduledoc """
  The Wallets context.
  """

  import Ecto.Query, warn: false
  alias FycApp.Repo
  alias Ecto.Multi
  
  alias FycApp.Wallets.{Wallet, Balance}
  alias FycApp.Currencies

  @doc """
  Returns the list of wallets.

  ## Examples

      iex> list_wallets()
      [%Wallet{}, ...]

  """
  def list_wallets do
    Repo.all(Wallet)
  end

  @doc """
  Gets a single wallet.

  Raises `Ecto.NoResultsError` if the Wallet does not exist.

  ## Examples

      iex> get_wallet!(123)
      %Wallet{}

      iex> get_wallet!(456)
      ** (Ecto.NoResultsError)

  """
  def get_wallet!(id), do: Repo.get!(Wallet, id)

  @doc """
  Gets a wallet owned by a specific user.
  Returns nil if no wallet exists for the user.

  ## Examples

      iex> get_user_wallet(user_id)
      %Wallet{balances: [%Balance{}, ...]}

      iex> get_user_wallet(456)
      nil

  """
  def get_user_wallet(user_id) do
    wallet =
      Wallet
      |> where([w], w.user_id == ^user_id)
      |> preload(balances: :deposits)
      |> Repo.one()

    case wallet do
      nil ->
        {:ok, wallet} = create_wallet(%{user_id: user_id})
        %{wallet | balances: []}

      %Wallet{balances: nil} = w ->
        %{w | balances: []}

      wallet ->
        wallet
    end
  end

  @doc """
  Creates a wallet.

  ## Examples

      iex> create_wallet(%{field: value})
      {:ok, %Wallet{}}

      iex> create_wallet(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_wallet(attrs \\ %{}) do
    %Wallet{}
    |> Wallet.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a wallet.

  ## Examples

      iex> update_wallet(wallet, %{field: new_value})
      {:ok, %Wallet{}}

      iex> update_wallet(wallet, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_wallet(%Wallet{} = wallet, attrs) do
    wallet
    |> Wallet.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a wallet.

  ## Examples

      iex> delete_wallet(wallet)
      {:ok, %Wallet{}}

      iex> delete_wallet(wallet)
      {:error, %Ecto.Changeset{}}

  """
  def delete_wallet(%Wallet{} = wallet) do
    Repo.delete(wallet)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking wallet changes.

  ## Examples

      iex> change_wallet(wallet)
      %Ecto.Changeset{data: %Wallet{}}

  """
  def change_wallet(%Wallet{} = wallet, attrs \\ %{}) do
    Wallet.changeset(wallet, attrs)
  end

  @doc """
  Ensures all supported currencies have balances created for the wallet.
  Returns the wallet with all necessary balances created and preloaded.
  """
  def ensure_balances_created(%Wallet{} = wallet) do
    # Get existing currencies for this wallet
    existing_currencies = wallet.balances
    |> Enum.map(& &1.currency)
    |> MapSet.new()

    # Find which currencies need to be created
    currencies_to_create = Currencies.supported_currencies()
    |> Enum.reject(&MapSet.member?(existing_currencies, &1))

    case currencies_to_create do
      [] -> 
        # No new balances needed
        wallet

      currencies ->
        # Create balances for missing currencies using changesets
        balances = Enum.map(currencies, fn currency ->
          %Balance{}
          |> Balance.changeset(%{
            currency: currency,
            amount: 0,
            wallet_id: wallet.id
          })
          |> Repo.insert!()
        end)

        # Reload wallet with all balances
        Repo.preload(wallet, balances: :deposits)
    end
  end
end
