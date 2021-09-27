defmodule Amadeus.Youtube do
  use Tesla

  alias Amadeus.DJ.Song

  adapter(Tesla.Adapter.Finch, name: Http)

  plug(Tesla.Middleware.BaseUrl, "https://youtube.googleapis.com/youtube/v3/")
  plug(Tesla.Middleware.Query, key: Application.fetch_env!(:amadeus, :youtube_api_key))
  plug(Tesla.Middleware.JSON)

  @duration_regex ~r/PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?/

  @youtube_hosts [
    "www.youtube.com",
    "music.youtube.com",
    "youtube.com",
    "youtu.be"
  ]

  def search(query) do
    response = get!("search", query: [part: "id", q: query, maxResults: 10])
    ids = for item <- response.body["items"], do: item["id"]["videoId"]

    # Stupid youtube api wont return the duration in search results so we have
    # to make an additional request to the videos endpoint
    response =
      get!("videos",
        query: [id: Enum.join(ids, ","), part: "contentDetails,snippet"]
      )

    Enum.map(response.body["items"], &format_song/1)
  end

  def get_song(id) do
    response = get!("videos", query: [id: id, part: "contentDetails,snippet"])

    %{"items" => [song]} = response.body

    format_song(song)
  end

  def get_playlist_songs(id, limit \\ 500) do
    Stream.resource(
      fn -> %{remaining: limit, next: nil} end,
      fn
        :done ->
          {:halt, nil}

        ctx ->
          response =
            get!("playlistItems",
              query: [
                playlistId: id,
                pageToken: ctx.next,
                part: "contentDetails,snippet",
                maxResults: min(50, ctx.remaining)
              ]
            )

          case response.body do
            %{"items" => []} ->
              {:halt, ctx}

            %{"items" => songs, "nextPageToken" => next} ->
              remaining = ctx.remaining - length(songs)
              songs = fetch_songs_with_durations(songs)
              {songs, %{ctx | next: next, remaining: remaining}}

            %{"items" => songs} ->
              {fetch_songs_with_durations(songs), :done}

            _ ->
              {:halt, ctx}
          end
      end,
      fn _ -> nil end
    )
    |> Enum.map(&format_song/1)
  end

  defp fetch_songs_with_durations(songs) do
    ids = Enum.map_join(songs, ",", & &1["contentDetails"]["videoId"])

    response =
      get!("videos",
        query: [id: ids, part: "contentDetails,snippet"]
      )

    response.body["items"]
  end

  defp format_song(song) do
    id = song["contentDetails"]["videoId"] || song["id"]

    Song.new(%{
      title: song["snippet"]["title"],
      duration: parse_duration(song["contentDetails"]["duration"]),
      url: "https://youtube.com/watch?v=#{id}",
      enqueued_by: nil
    })
  end

  defp parse_duration(duration) when is_binary(duration) do
    case Regex.run(@duration_regex, duration, capture: :all_but_first) do
      nil ->
        nil

      parts ->
        parts
        |> Enum.reject(&(&1 == ""))
        |> Enum.map_join(":", &String.pad_leading(&1, 2, "0"))
    end
  end

  defp parse_duration(_), do: nil

  def parse_url(url) when is_binary(url) do
    case URI.parse(url) do
      %{scheme: scheme, host: host} = uri
      when scheme in ["http", "https"] and host in @youtube_hosts ->
        get_uri_info(uri)

      _ ->
        :error
    end
  end

  defp get_uri_info(%{path: "/playlist"} = uri) do
    case URI.decode_query(uri.query) do
      %{"list" => id} ->
        %{type: :playlist, id: id}

      _ ->
        :error
    end
  end

  defp get_uri_info(%{path: "/watch"} = uri) do
    case URI.decode_query(uri.query) do
      %{"v" => video_id} ->
        %{type: :video, id: video_id}

      _ ->
        :error
    end
  end

  defp get_uri_info(%{host: "youtu.be", path: "/" <> id}), do: %{type: :video, id: id}
  defp get_uri_info(_), do: :error
end
