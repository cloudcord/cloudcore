defmodule DiscordGatewayGs.ModuleExecutor.Modules.Music do
  @behaviour DiscordGatewayGs.ModuleExecutor.CCModule

  alias LavaPotion.Struct.LoadTrackResponse
  alias DiscordGatewayGs.ModuleExecutor.Actions.DiscordActions
  alias DiscordGatewayGs.ModuleExecutor.Modules.Music.LavalinkManager

  def handle_command({"join", _}, %{"authorization" => %{"discord_token" => token}, "id" => id} = bot_config, %{:data => %{"channel_id" => channel, :guild_id => guild, "author" => author}} = discord_payload) do
    {_, member} = GenServer.call :local_redis_client, {:hget, Integer.to_string(guild), "member:" <> Integer.to_string(author["id"])}

    %{"voice" => vc} = member |> Poison.decode!

    case vc do
      nil ->
        DiscordActions.send_message_to_channel(":x: You need to connect to a voice channel to use this command.", channel, token)
      _ ->
        DiscordGatewayGs.TestBotGS.request_voice_connection(id, guild, vc["channel_id"])
        DiscordActions.send_message_to_channel(":white_check_mark: Joined.", channel, token)
    end
  end

  def handle_command({"leave", _}, %{"authorization" => %{"discord_token" => token}, "id" => id} = bot_config, %{:data => %{"channel_id" => channel, :guild_id => guild}} = discord_payload) do
    DiscordGatewayGs.TestBotGS.destroy_voice_connection(id, guild)
    LavalinkManager.destroy_guild_voice(id, Integer.to_string(guild))

    DiscordActions.send_message_to_channel("Goodbye! :wave:", channel, token)
  end

  def handle_command({"volume", args}, %{"authorization" => %{"discord_token" => token}, "id" => id} = bot_config, %{:data => %{"channel_id" => channel, :guild_id => guild}} = discord_payload) do
    with {:ok, _} <- LavalinkManager.guild_player_presence?(id, Integer.to_string(guild), channel, token) do
      # Below is temp, don't worry lol
      command_opts = bot_config["modules"]["music"]["config"]["command_options"]["volume"]
      case args do
        [volume | _] ->
          volume = Integer.parse(volume)
          case volume do
            {v, _} when is_integer(v) and v <= 1000 and v >= 0 ->
              LavalinkManager.set_volume(id, Integer.to_string(guild), v)
              DiscordActions.send_message_to_channel(":loud_sound: Volume set to `#{v}`", channel, token)
            _ ->
              DiscordActions.send_message_to_channel(":x: Sorry! Volume must be between 0 and 1000 (default is 100)", channel, token)
          end
        _ ->
          volume = LavalinkManager.get_volume(id, Integer.to_string(guild))
          DiscordActions.send_message_to_channel(String.replace(command_opts["messages"]["CURRENT_VOLUME"]["message"], "{volume}", Integer.to_string(volume)), channel, token)
      end
    end
  end

  def handle_command({"clearqueue", _}, %{"authorization" => %{"discord_token" => token}, "id" => id} = bot_config, %{:data => %{"channel_id" => channel, :guild_id => guild}} = discord_payload) do
    with {:ok, _} <- LavalinkManager.guild_player_presence?(id, Integer.to_string(guild), channel, token) do
      clear_queue(id, Integer.to_string(guild))
      DiscordActions.send_message_to_channel(":notepad_spiral: The queue has been cleared.", channel, token)
    end
  end

  def handle_command({"skip", _}, %{"authorization" => %{"discord_token" => token}, "id" => id} = bot_config, %{:data => %{"channel_id" => channel, :guild_id => guild}} = discord_payload) do
    with {:ok, _} <- LavalinkManager.guild_player_presence?(id, Integer.to_string(guild), channel, token) do
      #play_next_in_queue(id, Integer.to_string(guild))
    end
  end

  def handle_command({"play", args}, %{"authorization" => %{"discord_token" => token}, "id" => id} = bot_config, %{:data => %{"channel_id" => channel, :guild_id => guild, "author" => author}} = discord_payload) do
    with {:ok, _} <- LavalinkManager.guild_player_presence?(id, Integer.to_string(guild), channel, token) do
      {_, %{"id" => message_to_edit}} = DiscordActions.send_message_to_channel(":mag_right: Searching...", channel, token)

      is_yt_id? = Regex.match?(~r/[a-zA-Z0-9_-]{11}/, Enum.at(args, 0))

      results = case is_yt_id? do
        true -> LavaPotion.Api.load_tracks(Enum.at(args, 0))
        false -> LavaPotion.Api.load_tracks("ytsearch:#{Enum.join(args, " ")}")
      end

      case results do
        %LoadTrackResponse{loadType: "SEARCH_RESULT", tracks: [%{"info" => %{"author" => author, "identifier" => yt_id, "title" => title, "length" => length, "uri" => uri}, "track" => encoded_track} = track | _]} ->
          DiscordActions.edit_message(":notepad_spiral: Added to queue: `#{title}`", message_to_edit, channel, token)
          #LavalinkManager.play_track(id, Integer.to_string(guild), encoded_track)
          add_to_queue(id, Integer.to_string(guild), %{"encoded_track" => encoded_track, "uri" => uri, "id" => yt_id, "length" => length, "title" => title, "channel" => channel})
          play_now_if_no_player(id, Integer.to_string(guild))
          #play_next_in_queue(id, Integer.to_string(guild))
        %LoadTrackResponse{loadType: "TRACK_LOADED", tracks: [%{"info" => %{"author" => author, "identifier" => yt_id, "title" => title, "length" => length, "uri" => uri}, "track" => encoded_track} = track | _]} ->
          DiscordActions.edit_message(":notepad_spiral: Added to queue: `#{title}`", message_to_edit, channel, token)
          #LavalinkManager.play_track(id, Integer.to_string(guild), encoded_track)
          add_to_queue(id, Integer.to_string(guild), %{"encoded_track" => encoded_track, "uri" => uri, "id" => yt_id, "length" => length, "title" => title, "channel" => channel})
          play_now_if_no_player(id, Integer.to_string(guild))
        _ -> IO.puts DiscordActions.edit_message("Sorry, an error occurred with Lavalink", message_to_edit, channel, token)
      end
    end
  end

  def handle_command({"queue", _}, %{"authorization" => %{"discord_token" => token}, "id" => id} = bot_config, %{:data => %{"channel_id" => channel, :guild_id => guild}} = discord_payload) do
    with {:ok, _} <- LavalinkManager.guild_player_presence?(id, Integer.to_string(guild), channel, token) do
      case get_full_queue(id, Integer.to_string(guild)) do
        {:ok, tracks} ->
          queue_string = tracks
          |> Enum.map(fn song ->
            "#{song["title"]}\n"
          end)
          DiscordActions.send_message_to_channel("Current queue:\n#{queue_string}", channel, token)
        {:error, err} ->
          DiscordActions.send_message_to_channel(":x: #{err}", channel, token)
      end
    end
  end

  def handle_event(:voice_server_update, %{:data => data} = payload, bot_id) do
    [{_, session}] = :ets.lookup(:bot_sessions, bot_id)

    with :dispatch <- payload.op do
        LavalinkManager.initialize_guild(bot_id, Integer.to_string(data.guild_id), session, data.token, data.endpoint)
    end
  end

  #
  # Private
  #

  def get_full_queue(bot_id, guild_id) when is_binary(guild_id) do
    {_, queue_buffer} = GenServer.call :local_redis_client, {:get, "#{bot_id}_#{guild_id}_musicqueue"}

    case queue_buffer do
      nil -> {:error, "No songs in the queue!"}
      _ ->
        track_maps = queue_buffer
        |> String.split("|", trim: true)
        |> Enum.map(fn b ->
          b
          |> Base.decode64!(padding: false)
          |> Poison.decode!
        end)
        {:ok, track_maps}
    end
  end

  def get_next_in_queue(bot_id, guild_id) when is_binary(guild_id) do
    {_, queue_buffer} = GenServer.call :local_redis_client, {:get, "#{bot_id}_#{guild_id}_musicqueue"}

    case queue_buffer do
      nil ->
        {:error, "No songs in queue"}
      _ ->
        track = queue_buffer
        |> String.split("|", trim: true)
        |> Enum.at(0)
        |> Base.decode64!(padding: false)
        |> IO.inspect
        |> Poison.decode!

        {:ok, track}
    end
  end

  def add_to_queue(bot_id, guild_id, track) when is_binary(guild_id) do
    track = track
    |> Poison.encode!
    |> Base.encode64(padding: false)

    GenServer.cast :local_redis_client, {:append, "#{bot_id}_#{guild_id}_musicqueue", track <> "|"}

    {:ok}
  end

  def nudge_queue(bot_id, guild_id) when is_binary(guild_id) do
    {_, queue_buffer} = GenServer.call :local_redis_client, {:get, "#{bot_id}_#{guild_id}_musicqueue"}

    track = queue_buffer
    |> String.split("|", trim: true)
    |> List.delete_at(0)
    |> Enum.join("|")
    |> IO.inspect

    #String.length(track) && GenServer.cast :local_redis_client, {:del, "#{bot_id}_#{guild_id}_musicqueue"} || GenServer.cast :local_redis_client, {:set, "#{bot_id}_#{guild_id}_musicqueue", track}
    case String.length(track) do 
      0 ->
        GenServer.cast :local_redis_client, {:del, "#{bot_id}_#{guild_id}_musicqueue"}
      _ ->
        GenServer.cast :local_redis_client, {:set, "#{bot_id}_#{guild_id}_musicqueue", track <> "|"}
    end

    {:ok}
  end

  def clear_queue(bot_id, guild_id) when is_binary(guild_id) do
    GenServer.cast :local_redis_client, {:del, "#{bot_id}_#{guild_id}_musicqueue"}
  end

  def play_next_in_queue(bot_id, guild_id) when is_binary(guild_id) do
    [{id, %{"config" => %{"authorization" => %{"discord_token" => token}}}}] = :ets.lookup(:available_bots, bot_id)

    ns = get_next_in_queue(bot_id, guild_id)

    case ns do
      {:ok, song} ->
        LavalinkManager.play_track(bot_id, guild_id, song["encoded_track"])

        DiscordActions.send_message_to_channel(":musical_note: Now playing: `#{song["title"]}`", song["channel"], token)
        nudge_queue(bot_id, guild_id)
      {:error, err} ->
        #DiscordActions.send_message_to_channel(":notepad_spiral: The queue is empty. Add more songs using `!play <song name or id>`\n*If no songs are added within 5 minutes I'll leave the channel*", song["channel"], token)
    end
  end

  def play_now_if_no_player(bot_id, guild_id) when is_binary(guild_id) do
    player? = LavalinkManager.guild_is_playing?(bot_id, guild_id)

    if(!player?) do
      play_next_in_queue(bot_id, guild_id)
    end
  end

end