defmodule Amadeus.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Starts a worker by calling: A.Worker.start_link(arg)
      # {Amadeus.Worker, arg}
      {Finch, name: Http},
      {Amadeus.ConsumerSupervisor, []},
      {Amadeus.Paginator.Supervisor, []},
      {Registry, [keys: :unique, name: Amadeus.Paginator.Registry]},
      {Amadeus.DJ.Supervisor, []},
      {Registry, [keys: :unique, name: Amadeus.DJ.Registry]}
    ]

    :pg.start_link()

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Amadeus.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
