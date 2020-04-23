defmodule DiscordGatewayGs.TestBotGS do
  use GenServer
  require Logger

  alias DiscordGatewayGs.GatewayClient

  def start_link(bot_state) do
    GenServer.start_link(__MODULE__, bot_state, name: via_tuple(bot_state["bot_id"]))
  end

  def init(bot_state) do
    Logger.info("Bot GenServer init: #{bot_state["name"]}")

    # Start Gateway client for the bot
    {id, _} = Integer.parse(bot_state["bot_id"])

    internal_api_host = Application.get_env(:discord_gateway_gs, :internal_api)
    {_, res} = HTTPoison.get("http://localhost:8888/bots/" <> bot_state["bot_id"])
    config = Poison.decode!(res.body)["data"]

    modules = map_module_config_precedences(config["modules"])
    config = Map.put(config, "modules", modules)

    module_gwe_map =  map_modules_to_gwe_subs(config["modules"])
    module_gwe_list = concat_gwe_map(module_gwe_map)

    #Horde.Supervisor.start_child(DiscordGatewayGs.DistributedSupervisor, %{id: data["data"]["bot_id"], start: {DiscordGatewayGs.GatewayClient, :start_link, [data["data"]]}})
    {_, pid} = GatewayClient.start_link(%{:token => bot_state["token"], :presence => (config["interface"]["presence"] || %{"message" => ""}), :bot_id => id, :gwe_map => module_gwe_map, :gwe_list => module_gwe_list})
    
    # TEMP: Log to channel in test guild to confirm presence
    send self(), {:send_message, "HELLO_ACK from Elixir bot gateway process, GenServer PID: #{inspect(pid)}"}

    bot_state = Map.put(bot_state, :sharder_proc, pid)
    |> Map.put(:creator, config["creator"])
    :ets.insert(:available_bots, {bot_state["bot_id"], %{"config" => config, "token" => bot_state["token"]}})

    Process.flag(:trap_exit, true)

    if config["plan"] == "pro" do
      Process.send_after(self(), :billing_task, 10_000)
    end

    send self(), {:send_bot_status}
    Process.send_after self(), {:send_bot_stats}, 10_000

    {:ok, bot_state}
  end

  # Private

  defp schedule_billing_task do
    Process.send_after(self(), :billing_task, 3_600_000)
  end

  defp schedule_stats_update do
    Process.send_after(self(), {:send_bot_stats}, 300_000)
  end

  defp map_modules_to_gwe_subs(modules) do
    modules
    |> Enum.map(fn {k, v} ->
      with [{m, i}] <- :ets.lookup(:modules, k) do
        %{"internal_reference" => ir, "gwe_sub" => gwes} = i
        gwes = gwes |> Enum.map(&String.to_atom/1)

        {ir, gwes}
      end
    end)
  end

  @spec concat_gwe_map(List.t()) :: List.t()
  defp concat_gwe_map(gwe_map) do
    gwe_map
    |> Enum.map(fn t ->
      t |> elem(1)
    end)
    |> Enum.concat
    |> Enum.dedup
  end

  defp map_module_config_precedences(modules) do
    modules
    |> Enum.filter(fn {_, v} -> v["enabled"] end)
    |> Enum.map(fn {k, v} ->
      with [{m, i}] <- :ets.lookup(:modules, k) do
        dc = (i["default_config"] || %{})
        new_config = Map.merge((dc || %{}), (v["config"] || %{}))
        {k, %{"config" =>  new_config}}
      end
    end)
    |> Enum.into(%{})
  end

  # GenServer API

  @spec update_bot_config(String.t()) :: :ok
  def update_bot_config(bot_id) do
    IO.puts bot_id
    GenServer.cast via_tuple(bot_id), {:update_config}
  end

  def update_presence(bot_id, presence) do
    GenServer.cast via_tuple(bot_id), {:update_status, presence}
  end

  @spec request_voice_connection(String.t(), String.t(), String.t()) :: :ok
  def request_voice_connection(bot_id, guild_id, channel_id) do
    GenServer.cast via_tuple(bot_id), {:request_voice, channel_id, guild_id}
  end

  @spec destroy_voice_connection(String.t(), String.t()) :: :ok
  def destroy_voice_connection(bot_id, guild_id) do
    GenServer.cast via_tuple(bot_id), {:leave_voice, guild_id}
  end

  # GenServer callbacks

  def handle_info(:billing_task, state) do
    data = %{
      "creator" => state.creator,
      "amount" => 0.007
    }
    {_, res} = HTTPoison.post("http://localhost:8888/bots/" <> state["bot_id"] <> "/billing_charge", Poison.encode!(data), [{"Content-Type", "application/json"}])
    %{"exceeded" => exceeded?} = Poison.decode!(res.body)

    if exceeded? do
      Process.send(:local_node_manager, {:safely_terminate_bot, state["bot_id"]}, [])
    end

    schedule_billing_task()
    {:noreply, state}
  end

  def handle_info(:safe_term, state) do
    {:noreply, state}
  end
  
  def handle_info({:send_message, message}, state) do
    HTTPoison.post("https://discordapp.com/api/v6/channels/535097935923380246/messages", Poison.encode!(%{"content" => message}), [{"Authorization", "Bot " <> state["token"]}, {"Content-Type", "application/json"}])
    {:noreply, state}
  end

  def handle_cast({:update_config}, state) do
    internal_api_host = Application.get_env(:discord_gateway_gs, :internal_api)
    {_, res} = HTTPoison.get("http://localhost:8888/bots/" <> state["bot_id"])
    config = Poison.decode!(res.body)["data"]

    modules = map_module_config_precedences(config["modules"])
    config = Map.put(config, "modules", modules)

    module_gwe_map =  map_modules_to_gwe_subs(config["modules"])
    module_gwe_list = concat_gwe_map(module_gwe_map)
    
    send(state[:sharder_proc], {:update_gwe, module_gwe_map, module_gwe_list})

    :ets.insert(:available_bots, {state["bot_id"], %{"config" => config, "token" => state["token"]}})
    {:noreply, state}
  end

  def handle_cast({:update_status, presence}, state) do
    send(state[:sharder_proc], {:update_status, presence})
    {:noreply, state}
  end
  
  def handle_cast({:request_voice, channel, guild}, state) do
    send(state[:sharder_proc], {:start_voice_connection, %{:channel_id => channel, :guild_id => guild}})
    {:noreply, state}
  end

  def handle_cast({:leave_voice, guild}, state) do
    send(state[:sharder_proc], {:leave_voice_channel, guild})
    {:noreply, state}
  end

  def handle_info({:send_bot_stats}, state) do
    Task.start(fn ->
      {_, guilds} = GenServer.call(:local_redis_client, {:custom, ["LLEN", state["bot_id"] <> "_guilds"]})
      HTTPoison.post("http://localhost:8888/bots/" <> state["bot_id"] <> "/stats", Poison.encode!(%{"guild_count" => guilds}), [{"Content-Type", "application/json"}])
    end)
    schedule_stats_update()
    {:noreply, state}
  end

  def handle_info({:send_bot_status}, state) do
    [{_, node_name}] = :ets.lookup(:node_info, "identifier");
    internal_api_host = Application.get_env(:discord_gateway_gs, :internal_api)
    HTTPoison.post("http://localhost:8888/bots/" <> state["bot_id"] <> "/health", Poison.encode!(%{"node" => node_name, "pid" => inspect(self)}), [{"Content-Type", "application/json"}])
    GenServer.cast(:local_redis_client, {:publish, "cc-realtime-events", %{"action" => "bot_hello_ack", "data" => %{"creator": state.creator, "bot_id": state["bot_id"]}}})
    {:noreply, state}
  end

  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  def terminate(reason, state) do
    :ets.delete(:available_bots, state["bot_id"])
    GenServer.cast(:local_redis_client, {:del, "#{state["bot_id"]}_guilds"})
    HTTPoison.post("http://localhost:8888/bots/" <> state["bot_id"] <> "/terminated", [])
    GenServer.cast(:local_redis_client, {:publish, "cc-realtime-events", %{"action" => "bot_process_down", "data" => %{"creator": state.creator, "bot_id": state["bot_id"]}}})
  end

  def via_tuple(name), do: {:via, Horde.Registry, {DiscordGatewayGs.GSRegistry, "bot_" <> name}}
end