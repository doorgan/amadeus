defmodule Amadeus.DJ do
  @moduledoc """
  Functions to play music and manage queues/playlists.
  """

  use GenServer

  alias Amadeus.DJ.State
  alias Nostrum.Snowflake
  alias Nostrum.Struct.Interaction
  alias Nostrum.Voice

  require Logger

  def start_link(guild_id) do
    GenServer.start_link(__MODULE__, guild_id, name: via_tuple(guild_id))
  end

  @impl GenServer
  def init(guild_id) do
    state = %State{
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
  @spec enqueue(Interaction.t(), [Song.t()] | Song.t()) :: :ok
  def enqueue(interaction, songs) when is_list(songs) do
    GenServer.call(get_dj(interaction.guild_id), {:enqueue, songs})
  end

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
    {:reply, :ok, State.enqueue(state, songs)}
  end

  def handle_call(:queue, _from, state) do
    {:reply, %{current_song: state.current_song, queue: state.queue}, state}
  end

  def handle_call({:play, interaction, song}, _from, state) do
    {status, state} = State.play(state, interaction, song)
    {:reply, status, state}
  end

  def handle_call({:play, interaction}, _from, state) do
    {status, state} = State.play(state, interaction)
    {:reply, status, state}
  end

  def handle_call(:stop, _from, state) do
    {:reply, :ok, State.stop(state)}
  end

  def handle_call(:pause, _from, state) do
    {:reply, :ok, State.pause(state)}
  end

  def handle_call(:skip, _from, state) do
    {:reply, state.current_song, State.skip(state)}
  end

  def handle_call(:shuffle, _from, state) do
    state = State.shuffle(state)

    {:reply, state.queue, state}
  end

  def handle_call({:move, from, to}, _from, state) do
    {:reply, :ok, State.move(state, from, to)}
  end

  def handle_call(:toggle_repeat, _from, state) do
    repeat? = not state.repeat?
    {:reply, repeat?, %{state | repeat?: repeat?}}
  end

  @impl GenServer
  def handle_info({:VOICE_SPEAKING_UPDATE, _}, state) do
    if not Voice.playing?(state.guild_id) and state.status == :playing do
      {:noreply, State.skip(state)}
    else
      {:noreply, state}
    end
  end

  def handle_info(:VOICE_DISCONNECTED, _) do
    Process.exit(self(), :normal)
  end

  def handle_info(_, state), do: {:noreply, state}

  defp via_tuple(name), do: {:via, Registry, {Amadeus.DJ.Registry, name}}

  def get_dj(guild_id) do
    case Amadeus.DJ.Supervisor.start_child(guild_id) do
      {:ok, pid} -> pid
      {:error, {:already_started, pid}} -> pid
      error -> error
    end
  end
end
