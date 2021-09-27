defmodule Amadeus.Commands.Queue do
  @moduledoc false
  @behaviour Amadeus.Command

  import Amadeus.Gettext

  alias Amadeus.DJ
  alias Nostrum.Api
  alias Nostrum.Struct.Embed
  alias Nostrum.Struct.User

  @impl Amadeus.Command
  def spec(name) do
    %{
      name: name,
      description: gettext("Shows the current playlist")
    }
  end

  @impl Amadeus.Command
  @spec handle_interaction(Nostrum.Struct.Interaction.t()) :: {:ok} | {:error, term}
  def handle_interaction(interaction) do
    %{current_song: current_song, queue: queue} = DJ.queue(interaction.guild_id)

    currently_playing =
      if current_song do
        gettext("Now playing *%{title}*", title: current_song.title)
      end

    songs =
      for {song, index} <- Enum.with_index(queue, 1) do
        "` #{index} ` `[#{song.duration}]` **#{song.title}** - #{User.mention(song.enqueued_by)}"
      end

    if songs != [] do
      pages =
        for songs <- Enum.chunk_every(songs, 10) do
          %Embed{
            title: currently_playing,
            description: """
            #{gettext("`%{count}` songs", count: Enum.count(queue))}

            #{Enum.join(songs, "\n")}
            """
          }
        end

      Amadeus.Paginator.create(interaction, pages)
    else
      playlist = %Embed{
        title: currently_playing,
        description: gettext("The playlist is currently empty.")
      }

      Api.create_interaction_response(interaction, %{
        type: 4,
        data: %{embeds: [playlist]}
      })
    end
  end
end
