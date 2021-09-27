defmodule Amadeus.Utils.Nonce do
  @moduledoc false

  @doc """
  Generates a unique random string, useful for use as message reference for
  interactions.
  """
  @spec new() :: String.t()
  def new(), do: make_ref() |> :erlang.term_to_binary() |> Base.encode64()
end
