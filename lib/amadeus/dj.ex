defmodule Amadeus.DJ do
  @moduledoc """
  Functions to play music and manage queues/playlists.
  """

  use GenServer
  use TypedStruct

  alias Amadeus.DJ.Song
  alias Amadeus.Utils
  alias Nostrum.Voice
  alias Nostrum.Snowflake
  alias Nostrum.Struct.Message
  alias Nostrum.Struct.Interaction

  @type status :: :playing | :paused | :stopped

  typedstruct do
    field :guild_id, Snowflake.t(), enforce: true
    field :status, status, enforce: true
    field :queue, Qex.t(), enforce: true
    field :current_song, Song.t()
    field :repeat?, boolean(), enforce: true, default: false
  end

  def start_link(guild_id) do
    GenServer.start_link(__MODULE__, guild_id, name: via_tuple(guild_id))
  end

  @impl GenServer
  def init(guild_id) do
    state = %__MODULE__{
      guild_id: guild_id,
      status: :stopped,
      queue: Qex.new(),
      current_song: nil,
      repeat?: false
    }

    :pg.join({:guild, guild_id}, self())

    {:ok, state}
  end

  @doc """
  Enqueues a song to be played next.
  """
  @spec enqueue(Interaction.t(), [Song.t()]) :: :ok
  def enqueue(interaction, songs) when is_list(songs) do
    GenServer.call(get_dj(interaction.guild_id), {:enqueue, songs})
  end

  @spec enqueue(Interaction.t(), Song.t()) :: :ok
  def enqueue(interaction, song) do
    enqueue(interaction, [song])
  end

  @doc """
  Returns the list of songs added to the current playlist.
  """
  @spec queue(Snowflake.t()) :: %{current_song: Song.t() | nil, queue: Qex.t(Song.t())}
  def queue(guild_id) do
    GenServer.call(get_dj(guild_id), :queue)
  end

  @doc """
  Starts playing a song, or adds it to the end of the queue if there's one
  already playing.
  """
  @spec play(Interaction.t()) :: :ok
  def play(%{guild_id: guild_id} = interaction),
    do: GenServer.call(get_dj(guild_id), {:play, interaction})

  @spec play(Interaction.t(), Song.t()) :: :playing | :enqueued
  def play(%{guild_id: guild_id} = interaction, song),
    do: GenServer.call(get_dj(guild_id), {:play, interaction, song}, :timer.seconds(15))

  @doc """
  Stops playing the current song, but allows to resume it by caliing `play`.
  """
  @spec pause(Snowflake.t()) :: :ok
  def pause(guild_id), do: GenServer.call(get_dj(guild_id), :pause)

  @doc """
  Stops playing the current song and starts playing the next one.
  """
  @spec skip(Snowflake.t()) :: Song.t() | nil
  def skip(guild_id) do
    GenServer.call(get_dj(guild_id), :skip)
  end

  @doc """
  Stops playing the current song and clears the playlist queue.
  """
  @spec stop(Snowflake.t()) :: :ok
  def stop(guild_id) do
    GenServer.call(get_dj(guild_id), :stop)
  end

  @doc """
  Randomizes the playlist order.
  """
  @spec shuffle(Snowflake.t()) :: :ok
  def shuffle(guild_id) do
    GenServer.call(get_dj(guild_id), :shuffle)
  end

  @doc """
  Moves a song from the `from` position to the `to` position in the queue.
  """
  @spec move(Snowflake.t(), non_neg_integer(), non_neg_integer()) :: :ok
  def move(guild_id, from, to) do
    GenServer.call(get_dj(guild_id), {:move, from, to})
  end

  @spec toggle_repeat(Snowflake.t()) :: boolean()
  def toggle_repeat(guild_id) do
    GenServer.call(get_dj(guild_id), :toggle_repeat)
  end

  # CALLBACKS

  @impl GenServer
  def handle_call({:enqueue, songs}, _from, state) do
    queue =
      state.queue
      |> Enum.to_list()
      |> Utils.List.merge(songs)
      |> Qex.new()

    {:reply, :ok, %{state | queue: queue}}
  end

  def handle_call(:queue, _from, state) do
    {:reply, %{current_song: state.current_song, queue: state.queue}, state}
  end

  def handle_call({:play, interaction, song}, _from, state) do
    join_voice_channel(interaction)

    case state.status do
      status when status in [:playing, :paused] ->
        state = do_enqueue(state, song)
        {:reply, :enqueued, state}

      :stopped ->
        state = do_play(state, song)
        {:reply, :playing, state}
    end
  end

  def handle_call({:play, interaction}, _from, state) do
    join_voice_channel(interaction)

    case state.status do
      :paused ->
        state = do_resume(state)
        {:reply, :playing, state}

      _ ->
        {:reply, :playing, state}
    end
  end

  def handle_call(:stop, _from, state) do
    case state.status do
      status when status in [:playing, :paused] ->
        state = do_stop(state)
        state = put_in(state.queue, Qex.new())
        {:reply, :ok, state}

      :stopped ->
        {:reply, :ok, state}
    end
  end

  def handle_call(:pause, _from, state) do
    case state.status do
      :playing ->
        {:reply, :ok, do_pause(state)}

      _ ->
        {:reply, :ok, state}
    end
  end

  def handle_call(:skip, _from, state) do
    {:reply, state.current_song, do_skip(state)}
  end

  def handle_call(:shuffle, _from, state) do
    queue = Enum.shuffle(state.queue) |> Qex.new()

    {:reply, queue, %{state | queue: queue}}
  end

  def handle_call({:move, from, to}, _from, state) do
    queue =
      state.queue
      |> Enum.to_list()
      |> Enum.slide(from, to)
      |> Qex.new()

    {:reply, :ok, %{state | queue: queue}}
  end

  def handle_call(:toggle_repeat, _from, state) do
    repeat? = not state.repeat?
    {:reply, repeat?, %{state | repeat?: repeat?}}
  end

  @impl GenServer
  def handle_info({:VOICE_SPEAKING_UPDATE, _}, state) do
    if not Voice.playing?(state.guild_id) and state.status == :playing do
      {:noreply, do_skip(state)}
    else
      {:noreply, state}
    end
  end

  def handle_info(:VOICE_DISCONNECTED, _) do
    Process.exit(self(), :normal)
  end

  def handle_info(_, state), do: {:noreply, state}

  defp do_enqueue(state, song) do
    %{state | queue: Qex.push(state.queue, song)}
  end

  @spec do_skip(t) :: t
  defp do_skip(state) do
    case Qex.pop(state.queue) do
      {{:value, song}, queue} ->
        state = %{state | queue: queue}

        state =
          if state.repeat? do
            do_enqueue(state, state.current_song)
          else
            state
          end

        do_play(state, song)

      {:empty, _} ->
        if state.repeat? do
          do_play(state, state.current_song)
        else
          do_stop(state)
        end
    end
  end

  defp do_play(state, song) do
    play_song(state.guild_id, song)
    %{state | current_song: song, status: :playing}
  end

  defp do_stop(state) do
    Voice.leave_channel(state.guild_id)
    %{state | status: :stopped, current_song: nil}
  end

  defp do_pause(state) do
    Voice.pause(state.guild_id)
    %{state | status: :paused}
  end

  defp do_resume(state) do
    Voice.resume(state.guild_id)
    %{state | status: :playing}
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

  defp via_tuple(name), do: {:via, Registry, {Amadeus.DJ.Registry, name}}

  defp get_dj(guild_id) do
    case Amadeus.DJ.Supervisor.start_child(guild_id) do
      {:ok, pid} -> pid
      {:error, {:already_started, pid}} -> pid
      error -> error
    end
  end
end
