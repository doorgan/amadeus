defmodule Amadeus.Utils.List do
  @moduledoc """
  Utilities to work with lists
  """

  @doc """
  Merges to lists intercalating their elements.any()

  ## Examples

      iex> a = [1, 2, 3, 4, 5]
      iex> b = [:a, :b, :c, :d, :e]
      iex> merge(a, b)
      [1, :a, 2, :b, 3, :c, 4, :d, 5, :e]

      iex> a = [1, 2, 3, 4, 5]
      iex> b = [:a, :b, :c, :d, :e, :f, :g]
      iex> merge(a, b)
      [1, :a, 2, :b, 3, :c, 4, :d, 5, :e, :f, :g]

      iex> a = [1, 2, 3, 4, 5, 6, 7]
      iex> b = [:a, :b, :c, :d, :e]
      iex> merge(a, b)
      [1, :a, 2, :b, 3, :c, 4, :d, 5, :e, 6, 7]
  """
  @spec merge(list, list) :: list
  def merge(left, right) when is_list(left) and is_list(right) do
    do_merge(left, right)
  end

  defp do_merge([], right), do: right
  defp do_merge(left, []), do: left
  defp do_merge([h1 | t1], [h2 | t2]), do: [h1, h2 | do_merge(t1, t2)]
end
