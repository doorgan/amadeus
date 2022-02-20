defmodule Amadeus.DJ.State do
  @moduledoc false

  use TypedStruct

  alias Amadeus.DJ.Song
  alias Amadeus.Utils
  alias Nostrum.Voice
  alias Nostrum.Snowflake
  alias Nostrum.Struct.Message

  require Logger

  @type status :: :playing | :paused | :stopped

  typedstruct do
    field :guild_id, Snowflake.t(), enforce: true
    field :status, status, enforce: true
    field :queue, Qex.t(), enforce: true
    field :current_song, Song.t()
    field :repeat?, boolean(), enforce: true, default: false
  end

  @spec enqueue(t, Sont.t() | [Song.t()]) :: t
  def enqueue(state, songs) when is_list(songs) do
    queue =
      state.queue
      |> Enum.to_list()
      |> Utils.List.merge(songs)
      |> Qex.new()

    %{state | queue: queue}
  end

  def enqueue(state, song) do
    %{state | queue: Qex.push(state.queue, song)}
  end

  @spec play(t, Interaction.t()) :: {:playing, t}
  def play(state, interaction) do
    join_voice_channel(interaction)

    case state.status do
      :paused ->
        {:playing, resume(state)}

      _ ->
        {:playing, state}
    end
  end

  @spec play(t, Interaction.t(), Song.t()) :: {:playing | :enqueued, t}
  def play(state, interaction, song) do
    join_voice_channel(interaction)

    case state.status do
      status when status in [:playing, :paused] ->
        {:enqueued, enqueue(state, song)}

      :stopped ->
        {:playing, do_play(state, song)}
    end
  end

  defp do_play(state, song) do
    with {:error, reason} <- play_song(state.guild_id, song) do
      Logger.error("Failed to play song.", error_reason: reason, dj_state: state, dj_song: song)
    end

    %{state | current_song: song, status: :playing}
  end

  @spec stop(t) :: t
  def stop(state) do
    case state.status do
      status when status in [:playing, :paused] ->
        Voice.leave_channel(state.guild_id)
        %{state | queue: Qex.new(), status: :stopped, current_song: nil}

      :stopped ->
        state
    end
  end

  @spec pause(t) :: t
  def pause(state) do
    case state.status do
      :playing ->
        Voice.pause(state.guild_id)
        %{state | status: :paused}

      _ ->
        state
    end
  end

  @spec resume(t) :: t
  def resume(state) do
    Voice.resume(state.guild_id)
    %{state | status: :playing}
  end

  @spec skip(t) :: t
  def skip(state) do
    case Qex.pop(state.queue) do
      {{:value, song}, queue} ->
        state = %{state | queue: queue}

        state =
          if state.repeat? do
            enqueue(state, state.current_song)
          else
            state
          end

        IO.inspect("SKIPPING")

        do_play(state, song)

      {:empty, _} ->
        if state.repeat? do
          do_play(state, state.current_song)
        else
          stop(state)
        end
    end
  end

  @spec shuffle(t) :: t
  def shuffle(state) do
    queue = Enum.shuffle(state.queue) |> Qex.new()
    %{state | queue: queue}
  end

  @spec move(t, non_neg_integer(), non_neg_integer()) :: t
  def move(state, from, to) do
    queue =
      state.queue
      |> Enum.to_list()
      |> Enum.slide(from, to)
      |> Qex.new()

    %{state | queue: queue}
  end

  @spec join_voice_channel(Message.t()) :: :error | :ok
  def join_voice_channel(interaction) do
    case get_voice_channel(interaction.guild_id, interaction.member.user.id) do
      nil ->
        :error

      voice_channel_id ->
        Voice.join_channel(interaction.guild_id, voice_channel_id)
        :ok
    end
  end

  @spec play_song(Snowflake.t(), Song.t()) :: :ok | {:error, String.t()}
  def play_song(guild_id, song) do
    wait_until_voice_ready(guild_id)
    Voice.stop(guild_id)
    Process.sleep(10)
    Voice.play(guild_id, song.url, :ytdl)
  end

  def wait_until_voice_ready(guild_id) do
    if Voice.ready?(guild_id) do
      :ok
    else
      Process.sleep(10)
      wait_until_voice_ready(guild_id)
    end
  end

  @spec get_voice_channel(Snowflake.t(), Snowflake.t()) :: Snowflake.t() | nil
  def get_voice_channel(guild_id, user_id) do
    guild_id
    |> Nostrum.Cache.GuildCache.get!()
    |> Map.get(:voice_states)
    |> Enum.find(%{}, fn v -> v.user_id == user_id end)
    |> Map.get(:channel_id)
  end
end
