defmodule Amadeus.Commands.Shuffle do
  @moduledoc false
  @behaviour Amadeus.Command

  import Amadeus.Gettext

  alias Amadeus.DJ
  alias Nostrum.Api

  @impl Amadeus.Command
  def spec(name) do
    %{
      name: name,
      description: gettext("Shuffles the queue songs")
    }
  end

  @impl Amadeus.Command
  def handle_interaction(interaction) do
    queue = DJ.shuffle(interaction.guild_id)
    queue_count = Enum.count(queue)

    message =
      if queue_count == 0 do
        gettext("There are no songs to shuffle.")
      else
        gettext("Shuffled %{count} songs!", count: queue_count)
      end

    Api.create_interaction_response(interaction, %{
      type: 4,
      data: %{content: message}
    })
  end
end
