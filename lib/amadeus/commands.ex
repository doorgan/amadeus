defmodule Amadeus.Commands do
  @commands %{
    "play" => Amadeus.Commands.Play,
    # "pause" => Amadeus.Commands.Pause,
    "skip" => Amadeus.Commands.Skip,
    "stop" => Amadeus.Commands.Stop,
    "queue" => Amadeus.Commands.Queue,
    "shuffle" => Amadeus.Commands.Shuffle,
    "move" => Amadeus.Commands.Move
  }

  @command_names for {name, _} <- @commands, do: name

  def register_commands() do
    commands = for {name, command} <- @commands, do: command.spec(name)

    if guild_id = Application.get_env(:amadeus, :command_registration) do
      Nostrum.Api.bulk_overwrite_guild_application_commands(guild_id, commands)
    else
      Nostrum.Api.bulk_overwrite_global_application_commands(commands)
    end
  end

  def handle_interaction(interaction) do
    if interaction.data.name in @command_names do
      @commands[interaction.data.name].handle_interaction(interaction)
    end

    case interaction.data.custom_id do
      "paginator:next:" <> message_ref ->
        {message_ref, _} = Integer.parse(message_ref)
        Amadeus.Paginator.next(message_ref, interaction)

      "paginator:prev:" <> message_ref ->
        {message_ref, _} = Integer.parse(message_ref)
        Amadeus.Paginator.prev(message_ref, interaction)

      _ ->
        :ok
    end
  end
end
