defmodule LavaPotion do
  use Application
  use Supervisor

  alias LavaPotion.Stage

  def start do
    children = [
      supervisor(Stage, [])
    ]
    options = [
      strategy: :one_for_one,
      name: __MODULE__
    ]
    Supervisor.start_link(children, options)
    LavaPotion.Stage.Consumer.start_link(DiscordGatewayGs.ModuleExecutor.Modules.Music.LavalinkManager)
  end

  defmacro __using__(_opts) do
    quote do
      alias LavaPotion.Struct.{Client, Node, Player}
      alias LavaPotion.Api

      require Logger

      def start_link() do
        LavaPotion.Stage.Consumer.start_link(__MODULE__)
      end

      def handle_track_event(event, state) do
        Logger.warn "Unhandled Event: #{inspect event}"
        {:ok, state}
      end

      defoverridable [handle_track_event: 2]
    end
  end
end