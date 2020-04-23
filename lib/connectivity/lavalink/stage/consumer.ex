defmodule LavaPotion.Stage.Consumer do
  use GenStage

  alias LavaPotion.Stage.Middle

  require Logger

  def start_link(handler) do
    GenStage.start_link(__MODULE__, %{handler: handler, public: []}, name: __MODULE__)
  end

  def init(state), do: {:consumer, state, subscribe_to: [Middle]}

  def handle_events(events, _from, state) do
    new = handle(events, state)
    {:noreply, [], new}
  end

  def handle([], state), do: state
  def handle([args = [type, _args] | events], map = %{handler: handler}) do
    handler
    |> apply(:handle_track_event, args)
    |> case do
         {:ok, state} ->
          Logger.debug "Handled Event: #{inspect type}"
          handle(events, %{map | public: state})
         term ->
          raise "expected {:ok, state}, got #{inspect term}"
       end
  end
  def handle(_data, map) do
    Logger.warn "Unhandled Event: #{inspect map}"
  end
end