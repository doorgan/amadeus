defmodule Amadeus.DJ.Supervisor do
  use DynamicSupervisor

  alias Amadeus.DJ

  def start_link(_) do
    DynamicSupervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  @spec init(any) ::
          {:ok,
           %{
             extra_arguments: list,
             intensity: non_neg_integer,
             max_children: :infinity | non_neg_integer,
             period: pos_integer,
             strategy: :one_for_one
           }}
  def init(_) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def start_child(interaction) do
    DynamicSupervisor.start_child(__MODULE__, %{
      id: DJ,
      start: {DJ, :start_link, [interaction]},
      restart: :transient
    })
  end
end
