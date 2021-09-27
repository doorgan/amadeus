defmodule Amadeus.Commands.Skip do
  @moduledoc false
  @behaviour Amadeus.Command

  import Amadeus.Gettext

  alias Amadeus.DJ
  alias Nostrum.Api

  @impl Amadeus.Command
  def spec(name) do
    %{
      name: name,
      description: gettext("Skips the current playing song")
    }
  end

  @impl Amadeus.Command
  def handle_interaction(interaction) do
    song = DJ.skip(interaction.guild_id)

    message =
      if song do
        gettext("Skipped **%{title}**", title: song.title)
      else
        gettext("There's no song playing!")
      end

    Api.create_interaction_response(interaction, %{
      type: 4,
      data: %{content: message}
    })
  end
end
