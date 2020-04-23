defmodule DiscordGatewayGs.GatewayClient do
  # a lot of functionality here yoinked from: https://github.com/rmcafee/discord_ex/blob/master/lib/discord_ex/client/client.ex
  require Logger

  alias DiscordGatewayGs.GatewayClient.Heartbeat

  import DiscordGatewayGs.GatewayClient.Utility

  @behaviour :websocket_client
  
  def opcodes do
    %{
      :dispatch               => 0,
      :heartbeat              => 1,
      :identify               => 2,
      :status_update          => 3,
      :voice_state_update     => 4,
      :voice_server_ping      => 5,
      :resume                 => 6,
      :reconnect              => 7,
      :request_guild_members  => 8,
      :invalid_session        => 9,
      :hello                  => 10,
      :heartbeat_ack          => 11
    }
  end
  
  def start_link(opts) do
    opts = Map.put(opts, :client_id, opts[:bot_id])
    |> Map.put(:guilds, [])
    |> Map.put(:token, opts[:token])
    |> Map.put(:gwe_map, opts[:gwe_map])
    |> Map.put(:gwe_list, opts[:gwe_list])

    :crypto.start()
    :ssl.start()
    :websocket_client.start_link("wss://gateway.discord.gg/?encoding=etf", __MODULE__, opts)
  end

  def init(state) do
    # State sequence management process and set it's state
    {:ok, agent_seq_num} = Agent.start_link fn -> nil end

    new_state = state
      |> Map.put(:client_pid, self()) # Pass the client state to use it
      |> Map.put(:agent_seq_num, agent_seq_num) # Pass agent sequence num
      |> Map.put(:heartbeat_pid, nil) # Place for Heartbeat process pid

      IO.puts inspect(self())
    {:once, new_state}
  end

  def onconnect(_WSReq, state) do
    # Send identifier to discord gateway
    identify(state)
    {:ok, state}
  end

  def ondisconnect({:remote, :closed}, state) do
    # Reconnection with resume opcode should be attempted here
    {:close, {:remote, :closed}, state}
  end

  def voice_state_update(client_pid, guild_id, channel_id, user_id, options \\ %{}) do
    data = options |> Map.merge(%{guild_id: guild_id, channel_id: channel_id, user_id: user_id})
    send(client_pid, {:voice_state_update, data})
    :ok
  end

  def websocket_handle({:binary, payload}, _socket, state) do
    data = payload_decode(opcodes(), {:binary, payload})
    # Keeps the sequence tracker process updated
    _update_agent_sequence(data, state)

    # Handle data based on opcode sent by Discord
    _handle_data(data, state)
  end

  defp _handle_data(%{op: :hello} = data, state) do
    # Discord sends hello op immediately after connection
    # Start sending heartbeat with interval defined by the hello packet
    Logger.debug("Discord: Hello")
    {:ok, heartbeat_pid} = Heartbeat.start_link(
      state[:agent_seq_num],
      data.data.heartbeat_interval,
      self()
    )
    
    {:ok, %{state | heartbeat_pid: heartbeat_pid}}
  end

  defp _handle_data(%{op: :heartbeat_ack} = _data, state) do
    # Discord sends heartbeat_ack after we send a heartbeat
    # If ack is not received, the connection is stale
    Logger.debug("Discord: Heartbeat ACK")
    Heartbeat.ack(state[:heartbeat_pid])
    {:ok, state}
  end

  defp _handle_data(%{op: :dispatch, event_name: event_name} = data, state) do
    # Dispatch op carries actual content like channel messages
    DiscordGatewayGs.Statix.increment_gwe
    if event_name == :READY do
      # Client is ready
      #Logger.debug(fn -> "Discord: Dispatch #{event_name}" end)
    end
    event = normalize_atom(event_name)

    # Call event handler unless it is a static event
    if state[:handler] && !_static_event?(event) do
      state[:handler].handle_event({event, data}, state)
    else
      handle_event({event, data}, state)
    end
  end

  defp _handle_data(%{op: :reconnect} = _data, state) do
    Logger.warn("Discord enforced Reconnect")
    # Discord enforces reconnection. Websocket should be
    # reconnected and resume opcode sent to playback missed messages.
    # For now just kill the connection so that a supervisor can restart us.
    {:close, "Discord enforced reconnect", state}
  end

  defp _handle_data(%{op: :invalid_session} = _data, state) do
    Logger.warn("Discord: Invalid session")
    # On resume Discord will send invalid_session if our session id is too old
    # to be resumed.
    # For now just kill the connection so that a supervisor can restart us.
    {:close, "Invalid session", state}
  end

  def websocket_info(:start, _connection, state) do
    {:ok, state}
  end

  @doc "Look into state - grab key value and pass it back to calling process"
  def websocket_info({:get_state, key, pid}, _connection, state) do
    send(pid, {key, state[key]})
    {:ok, state}
  end

  @doc "Ability to update websocket client state"
  def websocket_info({:update_state, update_values}, _connection, state) do
    {:ok,  Map.merge(state, update_values)}
  end

  @doc "Remove key from state"
  def websocket_info({:clear_from_state, keys}, _connection, state) do
    new_state = Map.drop(state, keys)
    {:ok, new_state}
  end

  def websocket_info({:update_status, new_status}, _connection, state) do
    payload = payload_build(opcode(opcodes(), :status_update), new_status)
    :websocket_client.cast(self(), {:binary, payload})
    {:ok, state}
  end

  def websocket_info({:update_gwe, gwe_map, gwe_list}, _connection, state) do
    new_state = state
    |> Map.put(:gwe_map, gwe_map)
    |> Map.put(:gwe_list, gwe_list)

    {:ok, new_state}
  end

  #def websocket_info({:update_gwe, gwe_map, gwe_list}, _connection, state) do
  #  data = %{"idle_since" => idle_since, "game" => %{"name" => game_name}}
  #  send(state[:client_pid], {:update_status, data})
#
  #  {:ok, new_state}
  #end

  def websocket_info({:start_voice_connection, options}, _connection, state) do
    self_mute = if options[:self_mute] == nil, do: false, else: options[:self_mute]
    self_deaf = if options[:self_deaf] == nil, do: false, else: options[:self_mute]
    data = %{
      "channel_id" => options[:channel_id],
      "guild_id"   => options[:guild_id],
      "self_mute"  => self_mute,
      "self_deaf"  => self_deaf
    }
    payload = payload_build(opcode(opcodes(), :voice_state_update), data)
    :websocket_client.cast(self(), {:binary, payload})
    {:ok, state}
  end

  def websocket_info({:leave_voice_channel, guild_id}, _connection, state) do
    data = %{
      "channel_id" => nil,
      "guild_id"   => guild_id
    }
    payload = payload_build(opcode(opcodes(), :voice_state_update), data)
    :websocket_client.cast(self(), {:binary, payload})
    {:ok, state}
  end

  def websocket_info({:start_voice_connection_listener, caller}, _connection, state) do
    setup_pid = spawn(fn -> _voice_setup_gather_data(caller, %{}, state) end)
    updated_state = Map.merge(state, %{voice_setup: setup_pid})
    {:ok, updated_state}
  end

  def websocket_info({:start_voice_connection_listener, caller}, _connection, state) do
    setup_pid = spawn(fn -> _voice_setup_gather_data(caller, %{}, state) end)
    updated_state = Map.merge(state, %{voice_setup: setup_pid})
    {:ok, updated_state}
  end

  def websocket_info({:voice_state_update, opts}, _connection, state) do
    data = for {key, val} <- opts, into: %{}, do: {Atom.to_string(key), val}
    payload = payload_build(opcode(opcodes(), :voice_state_update), data)
    :websocket_client.cast(self(), {:binary, payload})
    {:ok, state}
  end

  def websocket_info(:heartbeat_stale, _connection, state) do
    # Heartbeat process reports stale connection. Websocket should be
    # reconnected and resume opcode sent to playback missed messages.
    # For now just kill the connection so that a supervisor can restart us.
    {:close, "Heartbeat stale", state}
  end

  def websocket_info(:expire_guilds_key, _connection, state) do
    GenServer.cast(:local_redis_client, {:expire, "#{state[:bot_id]}_guilds", 600})
    schedule_expire_guilds_key()
    {:ok, state}
  end

  @spec websocket_terminate(any(), any(), nil | keyword() | map()) :: :ok
  def websocket_terminate(reason, _conn_state, state) do
    Logger.info "Websocket closed in state #{inspect state} with reason #{inspect reason}"
    Logger.info "Killing seq_num process!"
    Process.exit(state[:agent_seq_num], :kill)
    Logger.info "Killing rest_client process!"
    Process.exit(state[:rest_client], :kill)
    Logger.info "Killing heartbeat process!"
    Process.exit(state[:heartbeat_pid], :kill)
    :ok
  end

  defp schedule_expire_guilds_key do
    Process.send_after(self(), :expire_guilds_key, 500_000)
  end

  def handle_event({:ready, payload}, state) do
    new_state = Map.put(state, :session_id, payload.data[:session_id])

    :ets.insert(:bot_sessions, {Integer.to_string(state[:bot_id]), payload.data[:session_id]})
    
    send self(), :expire_guilds_key
    {:ok, new_state}
  end

  def handle_event({:guild_create, payload}, state) do
    Horde.Supervisor.start_child(DiscordGatewayGs.DistributedSupervisor, %{id: Integer.to_string(payload.data.id), start: {DiscordGatewayGs.RedisSync, :start_link, [payload.data.id]}})
    Task.start fn ->
      GenServer.cast(:local_redis_client, {:custom, ["LREM", "#{state[:bot_id]}_guilds", "0", payload.data.id]})
      GenServer.cast(:local_redis_client, {:custom, ["LPUSH", "#{state[:bot_id]}_guilds", payload.data.id]})
      DiscordGatewayGs.RedisSync.guild_create(payload.data)
    end
    #if(payload.data[:id] == 535097935923380244) do
    #  #IO.inspect(payload)
    #end

    {:ok, state}
  end

  #def handle_event({:voice_state_update, payload}, state) do
  #  new_state = _update_voice_state(state, payload)
  #  {:ok, new_state}
  #end

  def handle_event({event, payload}, state) do
    if event in state[:gwe_list] do
      state[:gwe_map]
      |> Enum.filter(fn {_, v} ->
        event in v
      end)
      |> Enum.each(fn {k, _} ->
        Task.start fn ->
          DiscordGatewayGs.ModuleExecutor.ModuleMap.modules[k].handle_event(event, payload, Integer.to_string(state[:bot_id]))
        end
      end)
    end

    case event do
      :message_create ->
        Task.start fn ->
          DiscordGatewayGs.Statix.increment_messages
          DiscordGatewayGs.ModuleExecutor.CommandCenter2.handle_command(payload, {state[:token], state[:bot_id]})
        end
      :voice_state_update ->
        Task.start fn ->
          DiscordGatewayGs.RedisSync.voice_state_update(payload)
        end
      :guild_member_update ->
        Task.start fn ->
          DiscordGatewayGs.RedisSync.guild_member_update(payload)
        end
      e when e == :guild_role_create or e == :guild_role_update ->
        Task.start fn ->
          DiscordGatewayGs.RedisSync.guild_role_create_or_update(payload)
        end
      :guild_member_add ->
        Task.start fn ->
          DiscordGatewayGs.RedisSync.guild_member_add(payload)
        end
      :guild_member_remove ->
        Task.start fn ->
          DiscordGatewayGs.RedisSync.guild_member_remove(payload)
        end
      :guild_delete ->
        if(!payload.data["unavailable"]) do
          GenServer.cast(:local_redis_client, {:custom, ["LREM", "#{state[:bot_id]}_guilds", "0", payload.data["id"]]})
        end
      _ -> {:nostate}
    end
    {:ok, state}
  end

  def identify(state) do
    data = %{
      "token" => state[:token],
      "properties" => %{
        "$os" => "erlang-vm",
        "$browser" => "cloudcord-worker",
        "$device" => "cloudcord-genserver",
        "$referrer" => "",
        "$referring_domain" => ""
      },
      "presence" => %{
        "since" => nil,
        "game" => %{
          #"name" => "cloudcord.io",
          "name" => state[:presence]["message"],
          "type" => 0
        },
        "status" => "online",
      },
      "compress" => false,
      "large_threshold" => 250
    }
    payload = payload_build(opcode(opcodes(), :identify), data)
    :websocket_client.cast(self(), {:binary, payload})
  end

  @spec socket_url(map) :: String.t
  def socket_url(opts) do
    version  = opts[:version] || 6
    url = DiscordEx.RestClient.resource(opts[:rest_client], :get, "gateway")["url"]
      |> String.replace("gg/", "")
    String.to_charlist(url <> "?v=#{version}&encoding=etf")
  end

  defp _update_agent_sequence(data, state) do
    if state[:agent_seq_num] && data.seq_num do
      agent_update(state[:agent_seq_num], data.seq_num)
    end
  end

  defp _static_event?(event) do
    Enum.find(@static_events, fn(e) -> e == event end)
  end

  defp _update_voice_state(current_state, payload) do
    current_state
  end

  def _voice_setup_gather_data(caller_pid, data \\ %{}, state) do
    new_data = receive do
      {client_pid, received_data, _state} ->
        data
          |> Map.merge(received_data[:data])
          |> Map.merge(%{client_pid: client_pid})
    end

    voice_token = new_data[:token] || state[:voice_token]
    endpoint = new_data[:endpoint] || state[:endpoint]

    IO.puts inspect(new_data)
    if voice_token && new_data[:session_id] && endpoint do
      send(new_data[:client_pid], {:update_state, %{endpoint: endpoint, voice_token: voice_token}})
      send(new_data[:client_pid], {:clear_from_state, [:voice_setup]})
      send(caller_pid, Map.merge(new_data, %{endpoint: endpoint, token: voice_token}))
    else
      _voice_setup_gather_data(caller_pid, new_data, state)
    end
  end


  def _voice_valid_event(event, data, state) do
    event = Enum.find([:voice_server_update, :voice_state_update], fn(e) -> e == event end)
    case event do
      :voice_state_update  ->
        IO.puts inspect(data)
      :voice_server_update -> true
                         _ -> false
    end
  end

  @doc """
  Changes your status
  ## Parameters
    - new_status: map with new status
    Supported keys in that map: `:idle_since` and `:game_name`.
    If some of them are missing `nil` is used.
  ## Examples
      new_status = %{idle_since: 123456, game_name: "some game"}
      Client.status_update(state, new_status)
  """
  #@spec status_update(map, map) :: nil
  #def status_update(state, new_status) do
  #  idle_since = Map.get(new_status, :idle_since)
  #  game_name = Map.get(new_status, :game_name)
  #  data = %{"idle_since" => idle_since, "game" => %{"name" => game_name}}
  #  send(state[:client_pid], {:update_status, data})
  #  nil
  #end
end
