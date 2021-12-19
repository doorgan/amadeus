defmodule Amadeus.Commands.Pause do
  @moduledoc false
  @behaviour Amadeus.Command

  import Amadeus.Gettext

  alias Amadeus.DJ
  alias Nostrum.Api

  @impl Amadeus.Command
  def spec(name) do
    %{
      name: name,
      description: gettext("Pauses the current song.")
    }
  end

  @impl Amadeus.Command
  def handle_interaction(interaction) do
    DJ.pause(interaction.guild_id)

    Api.create_interaction_response(interaction, %{
      type: 4,
      data: %{content: gettext("Song paused. Use `/play` again to resume!")}
    })
  end
end
