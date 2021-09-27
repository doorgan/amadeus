defmodule Amadeus.DJ.Song do
  @moduledoc """
  A song with url and metadata.
  """
  use TypedStruct

  alias Amadeus.DJ.Song
  alias Nostrum.Struct.User

  typedstruct do
    field :title, String.t()
    field :url, String.t(), enforce: true
    field :duration, String.t()
    field :enqueued_by, User.t()
  end

  @spec new(String.t()) :: Song.t()
  def new(url) when is_binary(url) do
    %__MODULE__{url: url}
  end

  @spec new(map()) :: Song.t()
  def new(%{url: url} = params) when is_binary(url) do
    struct!(__MODULE__, params)
  end
end
