defmodule Amadeus.Commands.Repeat do
  @moduledoc false
  @behaviour Amadeus.Command

  import Amadeus.Gettext

  alias Amadeus.DJ
  alias Nostrum.Api

  @impl Amadeus.Command
  def spec(name) do
    %{
      name: name,
      description: gettext("Toggles the playlist repeat cycle.")
    }
  end

  @impl Amadeus.Command
  def handle_interaction(interaction) do
    repeat? = DJ.toggle_repeat(interaction.guild_id)

    message =
      if repeat? do
        gettext("Repeat set to: **ON**")
      else
        gettext("Repeat set to: **OFF**")
      end

    Api.create_interaction_response(interaction, %{
      type: 4,
      data: %{content: message}
    })
  end
end
