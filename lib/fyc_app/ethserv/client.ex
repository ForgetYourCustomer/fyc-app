defmodule FycApp.Ethserv.Client do
  @moduledoc """
  HTTP client for interacting with the Ethserv API.
  """

  @base_url "http://localhost:3002"

  @doc """
  Gets a new deposit address from the Bitserv API.
  """
  def get_new_address do
    case get("/new-address") do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        {:ok, Jason.decode!(body)}

      {:ok, %HTTPoison.Response{status_code: status_code}} ->
        {:error, "Unexpected status code: #{status_code}"}

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, "HTTP request failed: #{inspect(reason)}"}
    end
  end

  # Private functions

  defp get(path) do
    HTTPoison.get(@base_url <> path)
  end
end
