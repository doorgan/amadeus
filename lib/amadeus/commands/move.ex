defmodule Amadeus.Commands.Move do
  @moduledoc false
  @behaviour Amadeus.Command

  import Amadeus.Gettext

  alias Amadeus.DJ
  alias Amadeus.Command
  alias Nostrum.Api

  @impl Amadeus.Command
  def spec(name) do
    %{
      name: name,
      description: gettext("Moves a song to a new position in the playlist"),
      options: [
        %{
          type: 4,
          name: gettext("from"),
          description: gettext("The position of the song to move"),
          required: true
        },
        %{
          type: 4,
          name: gettext("to"),
          description: gettext("The new position for the song"),
          required: true
        }
      ]
    }
  end

  @impl Amadeus.Command
  def handle_interaction(interaction) do
    from = Command.get_option(interaction, "from").value
    to = Command.get_option(interaction, "to").value

    error =
      cond do
        from < 0 -> gettext("The `from` position must be a positive integer")
        to < 0 -> gettext("The `to` position must be a positive integer")
        true -> nil
      end

    if error do
      Api.create_interaction_response(interaction, %{type: 4, data: %{content: error}})
    else
      DJ.move(interaction.guild_id, from - 1, to - 1)

      Api.create_interaction_response(interaction, %{
        type: 4,
        data: %{
          content:
            gettext("Moved song at position `%{from}` to position `%{to}`", from: from, to: to)
        }
      })
    end
  end
end
