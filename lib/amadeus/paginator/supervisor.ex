defmodule Amadeus.Paginator.Supervisor do
  use DynamicSupervisor

  alias Amadeus.Paginator

  def start_link(_) do
    DynamicSupervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def start_child(message_ref, pages) do
    DynamicSupervisor.start_child(__MODULE__, %{
      id: Paginator,
      start: {Paginator, :start_link, [message_ref, pages]},
      restart: :transient
    })
  end
end
