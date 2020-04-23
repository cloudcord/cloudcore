defmodule DiscordGatewayGs.RedisConnector do
  use GenServer

  alias DiscordGatewayGs.Structs

  def start_link do
    GenServer.start_link(__MODULE__, [], name: :local_redis_client)
  end

  def init(_) do
    [{_, node_name}] = :ets.lookup(:node_info, "identifier");
    state = %{"node" => node_name}
    redis_host = Application.get_env(:discord_gateway_gs, :redis_host)
    {:ok, conn} = Redix.PubSub.start_link(host: "localhost", port: 6379)
    {:ok, client} = Redix.start_link(host: "localhost", port: 6379)

    Redix.PubSub.subscribe(conn, "cc-core-events", self())
    Redix.PubSub.subscribe(conn, "supreme", self())
    
    state = Map.put(state, :client, client)
    {:ok, state}
  end
  
  @spec insert_guild(Structs.GuildState, Structs.ChannelState, State.MemberState, State.RoleState) :: :ok | no_return
  def insert_guild(guild_state, channels_state, members_state, roles_state) do
    guild_state = Map.put(guild_state, :id, Integer.to_string(guild_state.id))
    command = ["HMSET", guild_state.id, "guild", Poison.encode!(guild_state)]
    
    channels = channels_state
    |> Enum.map(fn c ->
        ["channel:#{c.id}", Poison.encode!(c)]
    end)
    |> List.flatten

    command = command ++ channels

    members = members_state
    |> Enum.map(fn m ->
      ["member:#{m.user.id}", Poison.encode!(m)]
    end)
    |> List.flatten

    command = command ++ members

    roles = roles_state
    |> Enum.map(fn r ->
        ["role:#{r.id}", Poison.encode!(r)]
    end)
    |> List.flatten
    
    command = command ++ roles

    GenServer.cast :local_redis_client, {:custom, command}
    GenServer.cast :local_redis_client, {:expire, guild_state.id, 600}
  end

  #
  # GenServer Callbacks
  #

  def handle_call({:custom, keylist}, _from, state) do
    value = Redix.command(state[:client], keylist)
    {:reply, value, state}
  end

  def handle_call({:get, key}, _from, state) do
    value = Redix.command(state[:client], ["GET", key])
    {:reply, value, state}
  end

  def handle_call({:hget, hash, key}, _from, state) do
    value = Redix.command(state[:client], ["HGET", hash, key])
    {:reply, value, state}
  end

  def handle_cast({:custom, keylist}, state) do
    Redix.command(state[:client], keylist)
    {:noreply, state}
  end

  def handle_cast({:set, key, value}, state) do
    Redix.command(state[:client], ["SET", key, value])
    {:noreply, state}
  end
  
  def handle_cast({:del, key}, state) do
    Redix.command(state[:client], ["DEL", key])
    {:noreply, state}
  end

  def handle_cast({:hdel, hash, key}, state) do
    Redix.command(state[:client], ["HDEL", hash, key])
    {:noreply, state}
  end

  def handle_cast({:append, key, value}, state) do
    Redix.command(state[:client], ["APPEND", key, value])
    {:noreply, state}
  end

  def handle_cast({:expire, key, seconds}, state) do
    Redix.command(state[:client], ["EXPIRE", key, seconds])
    {:noreply, state}
  end

  def handle_cast({:publish, channel, message}, state) do
    message = Poison.encode!(message)
    Redix.command(state[:client], ["PUBLISH", channel, message])
    {:noreply, state}
  end

  def handle_info({:redix_pubsub, _pubsub, _pid, :subscribed, %{channel: channel}}, state) do
    IO.puts "Redis: subscribed to #{channel}"
    {:noreply, state}
  end

  def handle_info({:redix_pubsub, _pubsub, _pid, :message, %{channel: channel, payload: payload}}, state) do
    IO.puts "Redis: received message #{payload}"
    case channel do
      "cc-core-events" ->
        node_name = state["node"]
        data = Poison.decode!(payload)
        case data["node"] do
          ^node_name -> do_action(data)
          nil -> do_action(data)
          _ -> {:incorrect_node}
        end
      "supreme" ->
        DiscordGatewayGs.ModuleExecutor.Modules.SupremeMonitor.handle_outer_event({:restock, payload}, "", "")
    end
    {:noreply, state}
  end

  defp do_action(data) do
    case data["action"] do
      "createNewBotGS" -> Horde.Supervisor.start_child(DiscordGatewayGs.DistributedSupervisor, %{id: "bot_" <> data["data"]["bot_id"], start: {DiscordGatewayGs.TestBotGS, :start_link, [data["data"]]}})
      "updateBotConfig" -> DiscordGatewayGs.TestBotGS.update_bot_config(data["data"]["bot_id"])
      "updatePresence" -> DiscordGatewayGs.TestBotGS.update_presence(data["data"]["bot_id"], %{"since" => nil, "game" => %{"name" => data["data"]["presence_message"], "type" => 0}, "status" => "online", "afk" => false})
      "restartBot" ->
        Process.send(:local_node_manager, {:safely_restart_bot, data["bot_id"]}, [])
      "stopBotOnNode" -> 
        Process.send(:local_node_manager, {:safely_terminate_bot, data["bot_id"]}, [])
      _ -> IO.puts "unknown_action"
    end
  end
end