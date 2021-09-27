defmodule Amadeus.Commands.Stop do
  @moduledoc false
  @behaviour Amadeus.Command

  import Amadeus.Gettext

  alias Amadeus.DJ
  alias Nostrum.Api

  @impl Amadeus.Command
  def spec(name) do
    %{
      name: name,
      description: gettext("Stops playing and clears queue")
    }
  end

  @impl Amadeus.Command
  def handle_interaction(interaction) do
    if Nostrum.Voice.playing?(interaction.guild_id) do
      DJ.stop(interaction.guild_id)

      Api.create_interaction_response(interaction, %{
        type: 4,
        data: %{content: gettext("Ittekimasu!")}
      })
    else
      Api.create_interaction_response(interaction, %{
        type: 4,
        data: %{content: gettext("There's no song playing!")}
      })
    end
  end
end
