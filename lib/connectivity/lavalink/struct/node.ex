defmodule LavaPotion.Struct.Node do
  use WebSockex

  import Poison

  alias LavaPotion.Struct.{VoiceUpdate, Play, Pause, Stop, Destroy, Volume, Seek, Player, Stats}
  alias LavaPotion.Stage.Producer

  require Logger

  defstruct [:password, :port, :address, :client]

  @ets_lookup :lavapotion_ets_table
  @stats_max_int :math.pow(2, 31) - 1
  @stats_no_stats @stats_max_int - 1

  @typedoc """

  """
  @type t :: %__MODULE__{}

  def new(opts) do
    client = opts[:client]
    if client == nil do
      raise "client is nil"
    end

    address = opts[:address]
    if !is_binary(address) do
      raise "address is not a binary string"
    end

    port = opts[:port] || client.default_port
    if !is_number(port) do
      raise "port is not a number"
    end

    password = opts[:password] || client.default_password
    if !is_binary(password) do
      raise "password is not a binary string"
    end

    %__MODULE__{client: client, password: password, address: address, port: port}
  end

  def start_link(mod) do
    result = {:ok, pid} = WebSockex.start_link("ws://#{mod.address}:#{mod.port}", __MODULE__, %{},
      extra_headers: ["User-Id": mod.client.user_id, "Authorization": mod.password, "Num-Shards": mod.client.shard_count],
      handle_initial_conn_failure: true, async: true)
    if :ets.whereis(@ets_lookup) === :undefined, do: :ets.new(@ets_lookup, [:set, :public, :named_table])
    :ets.insert(@ets_lookup, {"#{mod.client.user_id}_#{mod.address}", %{node: mod, stats: nil, players: %{}, pid: pid}})
    result
  end

  def handle_connect(conn, _state) do
    Logger.info "Connected to #{conn.host}!"
    {:ok, conn}
  end

  def handle_disconnect(%{reason: {:local, _}, conn: conn}, state) do
    Logger.info "Client disconnected from #{conn.host}!"
    {:ok, state}
  end

  def handle_disconnect(%{reason: {:local, _, _}, conn: conn}, state) do
    Logger.info "Client disconnected from #{conn.host}!"
    {:ok, state}
  end

  def handle_disconnect(%{reason: {:remote, code, message}, attempt_number: attempt_number, conn: conn}, state) when attempt_number < 5 do
    # todo change to info if code = 1001 or 1000
    Logger.warn "Disconnected from #{conn.host} by server with code: #{code} and message: #{message}! Reconnecting..."
    {:reconnect, state}
  end

  def handle_disconnect(%{reason: {:remote, code, message}, conn: conn}, state) do
    # todo change to info if code == 1001 or 1000
    Logger.warn "Disconnected from #{conn.host} by server with code: #{code} and message: #{message}!"
    {:ok, state}
  end

  def handle_disconnect(%{reason: {:remote, :closed}, conn: conn}, state) do
    Logger.warn "Abruptly disconnected from #{conn.host} by server!"
    {:ok, state}
  end

  defp best_node_iter(current = {_node, record}, nodes) do
    if Enum.empty?(nodes) do
      current
    else
      node = List.first(nodes)
      nodes = List.delete_at(nodes, 0)
      result = case node do
        {_host, %{node: node = %__MODULE__{}, stats: nil}} -> {node, @stats_no_stats}
        {_host, %{node: node = %__MODULE__{}, stats: %Stats{playing_players: playing_players, cpu: %{"systemLoad" => system_load}, frame_stats: %{"nulled" => nulled, "deficit" => deficit}}}} ->
          {node, playing_players}
        {_host, %{node: node = %__MODULE__{}, stats: %Stats{playing_players: playing_players, cpu: %{"systemLoad" => system_load}, frame_stats: nil}}} ->
          {node, playing_players}
        {_host, %{node: node = %__MODULE__{}}} -> {node, @stats_no_stats}
        _ -> {:error, :malformed_data}
      end

      if result !== {:error, :malformed_data} && elem(result, 1) < record do
        best_node_iter(result, nodes)
      else
        best_node_iter(current, nodes)
      end
    end
  end
  
  def best_node() do
    list = :ets.tab2list(@ets_lookup) # woefully inefficient, might replace with select later?
    case best_node_iter({nil, @stats_max_int}, list) do
      {nil, _} -> {:error, :no_available_node}
      {node = %__MODULE__{}, _} -> {:ok, node}
      _ -> {:error, :malformed_return_value}
    end
  end

  def pid(%__MODULE__{address: address, client: %LavaPotion.Struct.Client{user_id: id}}), do: pid(address)

  def pid(address, bot_id) when is_binary(address) do
    [{_, %{pid: pid}}] = :ets.lookup(@ets_lookup, "#{bot_id}_#{address}")
    pid
  end

  def pid(node_full_identifier) when is_binary(node_full_identifier) do
    [{_, %{pid: pid}}] = :ets.lookup(@ets_lookup, node_full_identifier)
    pid
  end

  def node(address, bot_id) when is_binary(address) do
    [{_, %{node: node = %__MODULE__{}}}] = :ets.lookup(@ets_lookup, "#{bot_id}_#{address}")
    node
  end

  def players(%__MODULE__{address: address}), do: players(address)
  def players(address, bot_id) when is_binary(address) do
    [{_, %{players: players}}] = :ets.lookup(@ets_lookup, "#{bot_id}_#{address}")
    players
  end

  def player(%__MODULE__{address: address, client: %LavaPotion.Struct.Client{user_id: id}}, guild_id), do: player(address, guild_id, id)
  def player(address, guild_id, bot_id) when is_binary(address) and is_binary(guild_id) do
    IO.puts bot_id
    [{_, %{players: players}}] = :ets.lookup(@ets_lookup, "#{bot_id}_#{address}")
    players[guild_id]
  end

  def handle_cast({:voice_update, player = %Player{guild_id: guild_id, token: token, endpoint: endpoint, session_id: session_id, is_real: false}}, state) do
    event = %{guild_id: guild_id, token: token, endpoint: endpoint}
    update = encode!(%VoiceUpdate{guildId: guild_id, sessionId: session_id, event: event})
    [{_, map = %{node: node, players: players}}] = :ets.lookup(@ets_lookup, "#{state.extra_headers[:"User-Id"]}_#{state.host}")
    players = Map.put(players, guild_id, %Player{player | node: node, is_real: true})

    :ets.insert(@ets_lookup, {"#{state.extra_headers[:"User-Id"]}_#{state.host}", %{map | players: players}})
    {:reply, {:text, update}, state}
  end

  def handle_cast({:play, player = %Player{guild_id: guild_id, is_real: true}, data = {track, _info}}, state) do
    update = encode!(%Play{guildId: guild_id, track: track})
    [{_, map = %{players: players}}] = :ets.lookup(@ets_lookup, "#{state.extra_headers[:"User-Id"]}_#{state.host}")
    players = Map.put(players, guild_id, %Player{player | track: data})

    :ets.insert(@ets_lookup, {"#{state.extra_headers[:"User-Id"]}_#{state.host}", %{map | players: players}})
    {:reply, {:text, update}, state}
  end

  def handle_cast({:volume, player = %Player{guild_id: guild_id, is_real: true}, volume}, state) do
    update = encode!(%Volume{guildId: guild_id, volume: volume})
    [{_, map = %{players: players}}] = :ets.lookup(@ets_lookup, "#{state.extra_headers[:"User-Id"]}_#{state.host}")
    players = Map.put(players, guild_id, %Player{player | volume: volume})

    :ets.insert(@ets_lookup, {"#{state.extra_headers[:"User-Id"]}_#{state.host}", %{map | players: players}})
    {:reply, {:text, update}, state}
  end

  def handle_cast({:seek, %Player{guild_id: guild_id, is_real: true, track: {_data, %{"length" => length}}}, position}, state) do
    if position > length do
      Logger.warn("guild id: #{guild_id} | specified position (#{inspect position}) is larger than the length of the track (#{inspect length})")
      {:ok, state}
    else
      update = encode!(%Seek{guildId: guild_id, position: position})
      # updated upon player update
      {:reply, {:text, update}, state}
    end
  end

  def handle_cast({:pause, player = %Player{guild_id: guild_id, is_real: true, paused: paused}, pause}, state) do
    if pause == paused do
      {:ok, state}
    else
      update = encode!(%Pause{guildId: guild_id, pause: pause})
      [{_, map = %{players: players}}] = :ets.lookup(@ets_lookup, "#{state.extra_headers[:"User-Id"]}_#{state.host}")
      players = Map.put(players, guild_id, %Player{player | paused: pause})

      :ets.insert(@ets_lookup, {"#{state.extra_headers[:"User-Id"]}_#{state.host}", %{map | players: players}})
      {:reply, {:text, update}, state}
    end
  end

  def handle_cast({:destroy, %Player{guild_id: guild_id, is_real: true}}, state) do
    update = encode!(%Destroy{guildId: guild_id})
    [{_, map = %{players: players}}] = :ets.lookup(@ets_lookup, "#{state.extra_headers[:"User-Id"]}_#{state.host}")
    players = Map.delete(players, guild_id)

    :ets.insert(@ets_lookup, {"#{state.extra_headers[:"User-Id"]}_#{state.host}", %{map | players: players}})
    {:reply, {:text, update}, state}
  end

  def handle_cast({:stop, %Player{guild_id: guild_id, is_real: true, track: track}}, state) do
    if track == nil do
      Logger.warn "player for guild id #{guild_id} already isn't playing anything."
      {:ok, state}
    else
      update = encode!(%Stop{guildId: guild_id})
      # updated upon TrackEndEvent
      {:reply, {:text, update}, state}
    end
  end

  def handle_cast({:update_node, player = %Player{guild_id: guild_id, is_real: true, node: old_node = %__MODULE__{}}, new_node = %__MODULE__{}}, state) when new_node !== old_node do
    Player.destroy(player)
    [{_, map = %{players: players}}] = :ets.lookup(@ets_lookup, "#{state.client.user_id}_#{state.address}")
    player = %Player{player | node: new_node, is_real: false}
    players = Map.put(players, guild_id, player)

    Player.initialize(player)
    :ets.insert(@ets_lookup, {"#{state.extra_headers[:"User-Id"]}_#{state.host}", %{map | players: players}})
    {:ok, state}
  end

  def handle_cast({:update_node, %Player{guild_id: guild_id, is_real: true, node: old_node = %__MODULE__{}}, new_node = %__MODULE__{}}, state) when new_node === old_node do
    Logger.warn "player for guild id #{guild_id} attempt to update node to current node?"
    {:ok, state}
  end

  def terminate(_reason, state) do
    Logger.warn "Connection to #{state.host} terminated!"
    exit(:normal)
  end

  def handle_frame({:text, message}, state) do
    data = %{"op" => _op} = Poison.decode!(message)
    |> Map.merge(%{"host" => state.host, "bot_id" => state.extra_headers[:"User-Id"]})
    Producer.notify(data)
    {:ok, state}
  end
  def handle_frame(_frame, state), do: {:ok, state}
end