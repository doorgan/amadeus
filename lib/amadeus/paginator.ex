defmodule Amadeus.Paginator do
  use GenServer

  import Amadeus.Gettext

  alias Nostrum.Struct.Interaction

  def start_link(message_ref, pages) do
    GenServer.start_link(__MODULE__, pages,
      name: {:via, Registry, {Amadeus.Paginator.Registry, message_ref}}
    )
  end

  @impl GenServer
  def init([]), do: raise(ArgumentError, "The pages list can't be empty")

  def init(pages) when is_list(pages) do
    state = %{
      pages: Enum.with_index(pages, fn element, index -> {index + 1, element} end) |> Map.new(),
      current: 1
    }

    :timer.exit_after(:timer.minutes(15), self(), :normal)

    {:ok, state}
  end

  @spec create(Interaction.t(), [...]) :: :ok
  def create(interaction, [page | _] = pages) do
    {:ok, message_ref} = Snowflake.next_id()

    Amadeus.Paginator.Supervisor.start_child(message_ref, pages)

    Nostrum.Api.create_interaction_response(interaction, %{
      type: 4,
      data: render(message_ref, page, 1, length(pages))
    })

    :ok
  end

  @spec next(integer, Interaction.t()) :: :ok
  def next(message_ref, interaction) do
    with {:ok, paginator} <- get_paginator(message_ref),
         {:ok, state} <- GenServer.call(paginator, :next) do
      page = state.pages[state.current]

      Nostrum.Api.create_interaction_response(interaction, %{
        type: 7,
        data: render(message_ref, page, state.current, map_size(state.pages))
      })
    else
      _ ->
        Nostrum.Api.create_interaction_response(interaction, %{type: 7})
    end

    :ok
  end

  @spec prev(integer, Interaction.t()) :: :ok
  def prev(message_ref, interaction) do
    with {:ok, paginator} <- get_paginator(message_ref),
         {:ok, state} <- GenServer.call(paginator, :prev) do
      page = state.pages[state.current]

      Nostrum.Api.create_interaction_response(interaction, %{
        type: 7,
        data: render(message_ref, page, state.current, map_size(state.pages))
      })
    else
      _ ->
        Nostrum.Api.create_interaction_response(interaction, %{type: 7})
    end

    :ok
  end

  # CALLBACKS

  @impl GenServer
  def handle_call(:next, _from, state) do
    next = state.current + 1

    if state.pages[next] do
      state = %{state | current: next}
      {:reply, {:ok, state}, state}
    else
      {:reply, nil, state}
    end
  end

  def handle_call(:prev, _from, state) do
    prev = state.current - 1

    if state.pages[prev] do
      state = %{state | current: prev}
      {:reply, {:ok, state}, state}
    else
      {:reply, nil, state}
    end
  end

  defp get_paginator(message_ref) do
    case Registry.lookup(Amadeus.Paginator.Registry, message_ref) do
      [{paginator, _}] -> {:ok, paginator}
      _ -> {:error, :not_found}
    end
  end

  defp render(message_ref, page, current, total) do
    %{
      embeds: [page],
      components: [
        %{
          type: 1,
          components: [
            %{
              type: 2,
              style: 1,
              label: gettext("Previous"),
              disabled: current == 1,
              custom_id: "paginator:prev:#{message_ref}"
            },
            %{
              type: 2,
              style: 2,
              disabled: true,
              label: gettext("Page %{current} of %{total}", current: current, total: total),
              custom_id: "__counter__"
            },
            %{
              type: 2,
              style: 1,
              label: gettext("Next"),
              disabled: current == total,
              custom_id: "paginator:next:#{message_ref}"
            }
          ]
        }
      ]
    }
  end
end
