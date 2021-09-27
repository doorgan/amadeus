defmodule Amadeus.Commands.Play do
  @behaviour Amadeus.Command

  import Amadeus.Gettext

  alias Amadeus.Command
  alias Amadeus.DJ
  alias Amadeus.Youtube
  alias Nostrum.Api

  @impl Amadeus.Command
  def spec(name) do
    %{
      name: name,
      description: gettext("Play a song"),
      options: [
        %{
          type: 3,
          name: gettext("title_or_url"),
          description: gettext("A YouTube url or song title"),
          required: true
        }
      ]
    }
  end

  @impl Amadeus.Command
  def handle_interaction(interaction) do
    song_url = Command.get_option(interaction, gettext("title_or_url")).value

    case Youtube.parse_url(song_url) do
      :error ->
        song = Youtube.search(song_url) |> List.first()
        send_playing_song(interaction, song)

      %{type: :video, id: id} ->
        song = Youtube.get_song(id)
        send_playing_song(interaction, song)

      %{type: :playlist} = playlist ->
        handle_playlist(interaction, playlist)
    end
  end

  defp send_playing_song(interaction, song) do
    enqueued_by = interaction.member.user

    if song do
      song = %{song | enqueued_by: enqueued_by}

      message =
        case DJ.play(interaction, song) do
          :enqueued -> gettext("Added **%{title}** to the queue", title: song.title)
          :playing -> gettext("Now playing **%{title}**", title: song.title)
        end

      Api.create_interaction_response(interaction, %{type: 4, data: %{content: message}})
    else
      Api.create_interaction_response(interaction, %{
        type: 4,
        data: %{content: gettext("Could not find song")}
      })
    end
  end

  defp handle_playlist(interaction, playlist) do
    enqueued_by = interaction.member.user

    Api.create_interaction_response(interaction, %{type: 5})

    case Youtube.get_playlist_songs(playlist.id) do
      [] ->
        Api.create_interaction_response(interaction, %{
          type: 4,
          data: %{content: gettext("Could not find song")}
        })

      [song | rest] ->
        DJ.play(interaction, %{song | enqueued_by: enqueued_by})

        rest = Enum.map(rest, &%{&1 | enqueued_by: enqueued_by})
        DJ.enqueue(interaction, rest)

        message =
          gettext(
            """
            Added `%{count}` songs to the playlist!
            *Now playing **%{now_playing}***
            """,
            count: length(rest),
            now_playing: song.title
          )

        Api.create_followup_message(interaction.token, %{type: 4, content: message})
    end
  end
end
