defmodule Amadeus.Utils.Map do
  @moduledoc """
  Utilities to work with maps.
  """

  @doc """
  Puts the value in the specified key if the value is not `nil`

  ## Examples

      iex> maybe_put(%{a: 1}, :b, 2)
      %{a: 1, b: 2}

      iex> maybe_put(%{a: 1}, :b, nil)
      %{a: 1}
  """
  @spec maybe_put(map, any, any) :: map
  def maybe_put(map, _, nil), do: map
  def maybe_put(map, key, value), do: Map.put(map, key, value)
end
