defmodule Amadeus.Consumer do
  @moduledoc false
  use Nostrum.Consumer

  def start_link do
    Consumer.start_link(__MODULE__)
  end

  def handle_event({:READY, _data, _ws_state}) do
    Amadeus.Commands.register_commands()
  end

  def handle_event({:INTERACTION_CREATE, interaction, _ws_state}) do
    Amadeus.Commands.handle_interaction(interaction)
  end

  def handle_event({:VOICE_READY, event, _ws_state}) do
    broadcast(event.guild_id, {:VOICE_READY, event})
  end

  def handle_event({:VOICE_SPEAKING_UPDATE, event, _ws_state}) do
    broadcast(event.guild_id, {:VOICE_SPEAKING_UPDATE, event})
  end

  def handle_event({:VOICE_STATE_UPDATE, %{channel_id: nil} = event, _ws_state}) do
    broadcast(event.guild_id, :VOICE_DISCONNECTED)
  end

  def handle_event(_data) do
    :ok
  end

  def broadcast(guild_id, event) do
    for pid <- :pg.get_members({:guild, guild_id}) do
      send(pid, event)
    end
  end
end
