defmodule DiscordGatewayGs do
  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    topologies = Application.get_env(:libcluster, :topologies)

    children = [
      {Horde.Registry, [name: DiscordGatewayGs.GSRegistry, keys: :unique]},
      {Horde.Supervisor, [name: DiscordGatewayGs.DistributedSupervisor, strategy: :one_for_one]},
      worker(DiscordGatewayGs.NodeManager, []),
      worker(DiscordGatewayGs.RedisConnector, []),
      #worker(DiscordGatewayGs.Connectivity.SupremeMonitor, []),
    ]

    #DiscordGatewayGs.Statix.connect()

    opts = [strategy: :one_for_one, name: DiscordGatewayGs.Supervisor]
    Supervisor.start_link(children, opts)
  end
end