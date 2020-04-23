defmodule DiscordGatewayGs.NodeManager do
  use GenServer

  defstruct identifier: ""

  def start_link do
    GenServer.start_link(__MODULE__, [], name: :local_node_manager)
  end

  def init(_) do
    Application.get_env(:discord_gateway_gs, :internal_api) |> IO.inspect
    :ets.new(:available_bots, [:set, :public, :named_table])
    :ets.new(:bot_sessions, [:set, :public, :named_table])
    :ets.new(:node_info, [:set, :protected, :named_table])
    :ets.new(:modules, [:set, :public, :named_table])
    :ets.new(:commands, [:set, :public, :named_table])

    IO.puts("Node online!")

    identifier = case System.get_env("MY_POD_NAME") do
      nil -> "dev"
      other -> other
    end

    :ets.insert_new(:node_info, {"identifier", identifier})

    load_modules()
    schedule_periodic_update()

    {:ok, %__MODULE__{identifier: identifier}}
  end

  # Callbacks

  def handle_info({:safely_terminate_bot, id}, state) do
    Horde.Supervisor.terminate_child(DiscordGatewayGs.DistributedSupervisor, "bot_" <> id)
    {:noreply, state}
  end

  def handle_info({:safely_restart_bot, id}, state) do
    [{pid, _}] = Horde.Registry.lookup(DiscordGatewayGs.GSRegistry, "bot_" <> id)
    gen_state = :sys.get_state(pid)

    Horde.Supervisor.terminate_child(DiscordGatewayGs.DistributedSupervisor, "bot_" <> id)
    Horde.Supervisor.start_child(DiscordGatewayGs.DistributedSupervisor, %{id: id, start: {DiscordGatewayGs.TestBotGS, :start_link, [gen_state]}})
    {:noreply, state}
  end


  def handle_info(:do_firestore_update, state) do
    # TODO: only count matches of bot GenServers
    avail_bots_ets_info = :ets.info(:available_bots)
    DiscordGatewayGs.Statix.set_bots_running_gauge(avail_bots_ets_info[:size])
    internal_api_host = Application.get_env(:discord_gateway_gs, :internal_api)
    HTTPoison.post("http://localhost:8888/nodes/health", Poison.encode!(%{"identifier" => state.identifier, "bots_running" => avail_bots_ets_info[:size], "messages_per_second" => 1}), [{"Content-Type", "application/json"}])
    schedule_periodic_update()
    {:noreply, state}
  end

  # Internal API

  defp load_modules() do
    internal_api_host = Application.get_env(:discord_gateway_gs, :internal_api)
    {_, res} = HTTPoison.get("http://localhost:8888/modules/internal")
    modules = Poison.decode!(res.body)["modules"];
    Enum.each(modules, fn m ->
      Enum.each(m["commands"], fn {c, i} ->
        i = Map.put(i, "module", m["id"])
        :ets.insert_new(:commands, {c, i})
      end)
      :ets.insert_new(:modules, {m["internal_reference"], m})
    end)
    IO.puts inspect(modules)
  end

  defp schedule_periodic_update() do
    Process.send_after(self(), :do_firestore_update, 25000)
  end
end