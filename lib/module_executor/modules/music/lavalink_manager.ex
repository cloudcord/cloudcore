defmodule DiscordGatewayGs.ModuleExecutor.Modules.Music.LavalinkManager do
  defstruct [:bot_id, :default_client, :node, :node_pid, :volume]
  use GenServer

  def start_link(state) do
    GenServer.start_link(__MODULE__, state, name: {:via, Horde.Registry, {DiscordGatewayGs.GSRegistry, "lavalink_" <> state.bot_id}})
  end

  def init(state) do
    LavaPotion.start

    c = LavaPotion.Struct.Client.new(%{:user_id => state.bot_id, :default_port => 80})
    n = LavaPotion.Struct.Node.new(%{:client => c, :address => "34.74.87.236"})
    {_, nodepid} = LavaPotion.Struct.Node.start_link(n)
    
    {:ok, %__MODULE__{bot_id: state.bot_id, default_client: c, node: n, node_pid: nodepid, volume: 100}}
  end

  #
  # GenServer API
  #

  # Setters

  def initialize_guild(bot_id, guild, session, token, endpoint) do
    GenServer.cast via_tuple(bot_id), {:init_guild, %{guild: guild, session: session, token: token, endpoint: endpoint}}
  end

  def destroy_guild_voice(bot_id, guild) do
    GenServer.cast via_tuple(bot_id), {:destroy_guild_voice, guild}
  end

  def play_track(bot_id, guild, track) do
    GenServer.cast via_tuple(bot_id), {:play_track, %{guild: guild, track: track}}
  end

  def set_volume(bot_id, guild, volume) do
    GenServer.cast via_tuple(bot_id), {:set_volume, %{guild: guild, volume: volume}}
  end

  # Getters

  def get_volume(bot_id, guild) do
    GenServer.call via_tuple(bot_id), {:get_volume, guild}
  end

  def guild_is_playing?(bot_id, guild) do
    player? = GenServer.call via_tuple(bot_id), {:player_exists?, guild}

    Kernel.match?(%LavaPotion.Struct.Player{track: {_, _}}, player?)
  end

  def guild_player_presence?(bot_id, guild_id, channel_id, token) do
    case Horde.Registry.lookup(DiscordGatewayGs.GSRegistry, "lavalink_#{bot_id}") do
      [{pid, _}] ->
        case GenServer.call(pid, {:player_exists?, guild_id}) do
          %LavaPotion.Struct.Player{} -> {:ok, pid}
          _ ->
            Task.start fn ->
              DiscordGatewayGs.ModuleExecutor.Actions.DiscordActions.send_message_to_channel(":x: I need to be in a voice channel to do that. Use `!join`", channel_id, token)
            end
            {:error, "Guild does not have a player"}
        end
      _ ->
        Task.start fn ->
          DiscordGatewayGs.ModuleExecutor.Actions.DiscordActions.send_message_to_channel(":x: I need to be in a voice channel to do that. Use `!join`", channel_id, token)
        end
        {:error, "Lavalink manager for bot #{bot_id} does not exist."}
    end
  end

  # LavaPotion Event Callbacks

  def handle_track_event(event, {_host, bot_id, guild_id, _, _} = state) do
    if event == :track_end do
      DiscordGatewayGs.ModuleExecutor.Modules.Music.play_next_in_queue(bot_id, guild_id)
    end
    {:ok, state}
  end
  
  #
  # GenServer Callbacks
  #

  def handle_cast({:set_volume, %{:guild => guild, :volume => volume}}, state) do
    player = LavaPotion.Struct.Node.player(state.node, guild)

    LavaPotion.Struct.Player.volume(player, volume)
    {:noreply, %{state | volume: volume}}
  end

  def handle_cast({:init_guild, %{:guild => guild, :session => session, :token => token, :endpoint => endpoint} = opts}, state) do
    LavaPotion.Api.initialize(state.node_pid, guild, session, token, endpoint)

    {:noreply, state}
  end
  
  def handle_cast({:destroy_guild_voice, guild}, state) do
    player = LavaPotion.Struct.Node.player(state.node, guild)

    LavaPotion.Struct.Player.destroy(player)
    {:noreply, state}
  end

  def handle_cast({:play_track, %{:guild => guild, :track => track}}, state) do
    player = LavaPotion.Struct.Node.player(state.node, guild)
    
    LavaPotion.Struct.Player.play(player, track)
    {:noreply, state}
  end

  def handle_call({:get_volume, guild}, _from, state) do
    {:reply, state.volume, state}
  end

  def handle_call({:player_exists?, guild}, _from, state) do
    player = LavaPotion.Struct.Node.player(state.node, guild)

    {:reply, player, state}
  end

  def via_tuple(bot_id) do
    case Horde.Registry.lookup(DiscordGatewayGs.GSRegistry, "lavalink_" <> bot_id) do
      [{_, _}] -> {:via, Horde.Registry, {DiscordGatewayGs.GSRegistry, "lavalink_" <> bot_id}}
      _ ->
        Horde.Supervisor.start_child(DiscordGatewayGs.DistributedSupervisor, %{id: "lavalink_" <> bot_id, start: {DiscordGatewayGs.ModuleExecutor.Modules.Music.LavalinkManager, :start_link, [%{bot_id: bot_id}]}})
        {:via, Horde.Registry, {DiscordGatewayGs.GSRegistry, "lavalink_" <> bot_id}}
    end
  end
end