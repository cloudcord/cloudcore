defmodule LavaPotion.Stage.Middle do
  use GenStage

  alias LavaPotion.Stage.Producer
  alias LavaPotion.Struct.{Player, Stats}

  require Logger

  @ets_lookup :lavapotion_ets_table

  def start_link() do
    GenStage.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(state) do
    {:producer_consumer, state, subscribe_to: [Producer]}
  end

  def handle_events(events, _from, state) do
    events = events
    |> Enum.map(
          fn data = %{"op" => opcode} ->
            handle(opcode, data)
          end
       )
    |> Enum.filter(&(&1 !== :ignore))
    {:noreply, events, state}
  end

  def handle("playerUpdate", %{"host" => host, "bot_id" => bot_id, "guildId" => guild_id, "state" => %{"time" => timestamp, "position" => position}}) do
    [{_, map = %{players: players = %{^guild_id => player = %Player{}}}}] = :ets.lookup(@ets_lookup, "#{bot_id}_#{host}")
    players = Map.put(players, guild_id, %Player{player | raw_position: position, raw_timestamp: timestamp})
    :ets.insert(@ets_lookup, {"#{bot_id}_#{host}", %{map | players: players}})
    :ignore
  end

  def handle("stats", data = %{"host" => host, "bot_id" => bot_id, "players" => players, "playingPlayers" => playing_players, "uptime" => uptime,
    "memory" => memory, "cpu" => cpu}) do
    frame_stats = data["frameStats"] # might not exist in map so can't match
    stats = %Stats{players: players, playing_players: playing_players, uptime: uptime, memory: memory, cpu: cpu, frame_stats: frame_stats}
    [{_, map}] = :ets.lookup(@ets_lookup, "#{bot_id}_#{host}")
    :ets.insert(@ets_lookup, {"#{bot_id}_#{host}", %{map | stats: stats}})
    :ignore
  end

  def handle("event", data = %{"host" => host, "bot_id" => bot_id, "type" => type, "guildId" => guild_id}) do
    case type do
      "TrackEndEvent" ->
        n = :ets.lookup(@ets_lookup, "#{bot_id}_#{host}")
        if match?([{_, map = %{players: players = %{^guild_id => player = %Player{}}}}], n) do
          [{_, map = %{players: players = %{^guild_id => player = %Player{}}}}] = n
          players = Map.put(players, guild_id, %Player{player | track: nil})
        :ets.insert(@ets_lookup, {"#{bot_id}_#{host}", %{map | players: players}})
        [:track_end, {host, bot_id, guild_id, data["track"], data["reason"]}] # list for use in Kernel.apply/3
        end
      "TrackExceptionEvent" ->
        error = data["error"]
        Logger.error "Error in Player for Guild ID: #{guild_id} | Message: #{error}"
        [:track_exception, {host, bot_id, guild_id, data["track"], error}]

      "TrackStuckEvent" ->
        Logger.warn "Track stuck for Player/Guild ID: #{guild_id}"
        [:track_stuck, {host, bot_id, guild_id, data["track"]}]

      "WebSocketClosedEvent" ->
        code = data["code"]
        reason = data["reason"]
        Logger.warn "Audio WebSocket Connection to Discord closed for Guild ID: #{guild_id}, Code: #{code}, Reason: #{reason}"
        [:websocket_closed, {host, bot_id, guild_id, code, reason}]
      _ ->
        :ignore
    end
  end

  def handle(_op, data), do: data # warning in consumer
end