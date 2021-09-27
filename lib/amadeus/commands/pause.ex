defmodule Amadeus.Commands.Pause do
  @moduledoc false
  @behaviour Nosedrum.Command

  alias Amadeus.DJ

  @impl true
  def usage, do: ["queue"]

  @impl true
  def description, do: "shows the current queue"

  @impl true
  def parse_args(args), do: Enum.join(args, " ")

  @impl true
  def predicates, do: []

  @impl true
  def command(msg, _) do
    DJ.pause(msg.guild_id)
  end
end
