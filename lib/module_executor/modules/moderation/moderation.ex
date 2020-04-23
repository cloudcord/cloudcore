defmodule DiscordGatewayGs.ModuleExecutor.Modules.Moderation do
  @behaviour DiscordGatewayGs.ModuleExecutor.CCModule

  alias DiscordGatewayGs.ModuleExecutor.Actions.DiscordActions
  alias DiscordGatewayGs.ModuleExecutor.Snowflake

  #
  # Ban
  #

  def handle_command({"ban", args}, %{"authorization" => %{"discord_token" => token}} = bot_config, %{:data => %{:guild_id => guild_id, "channel_id" => channel, "mentions" => [user_to_ban | _]}} = discord_payload) do
    {_, %{"id" => message_to_edit}} = DiscordActions.send_message_to_channel(":shield: One moment...", channel, token)

    case DiscordActions.ban_user(user_to_ban["id"], guild_id, token) do
      {:ok} ->
        DiscordActions.edit_message(":shield: User `#{user_to_ban["username"]}\##{user_to_ban["discriminator"]}` has been banned", message_to_edit, channel, token)
      {:error, error} ->
        case error["code"] do
          50013 ->
            DiscordActions.edit_message(":x: I don't have permission to ban that user", message_to_edit, channel, token)
          _ ->
            DiscordActions.edit_message(":x: Sorry, an unknown error occurred", message_to_edit, channel, token)
        end
    end
  end

  def handle_command({"ban", [user_id? | _]}, %{"authorization" => %{"discord_token" => token}} = bot_config, %{:data => %{:guild_id => guild_id, "channel_id" => channel, "mentions" => []}} = discord_payload) do
    {_, %{"id" => message_to_edit}} = DiscordActions.send_message_to_channel(":shield: One moment...", channel, token)
   case DiscordActions.ban_user(user_id?, guild_id, token) do
     {:ok} ->
       DiscordActions.edit_message(":shield: User has been banned", message_to_edit, channel, token)
     {:error, error} ->
       case error["code"] do
         50013 ->
           DiscordActions.edit_message(":x: I don't have permission to ban that user", message_to_edit, channel, token)
         e when is_map(error) ->
           DiscordActions.edit_message(":x: Invalid user ID", message_to_edit, channel, token)
         _ ->
           DiscordActions.edit_message(":x: Sorry, an unknown error occurred", message_to_edit, channel, token)
       end
    end
  end

  #
  # Unban
  #

  def handle_command({"unban", args}, %{"authorization" => %{"discord_token" => token}} = bot_config, %{:data => %{:guild_id => guild_id, "channel_id" => channel, "mentions" => [user_to_unban | _]}} = discord_payload) do
    {_, %{"id" => message_to_edit}} = DiscordActions.send_message_to_channel(":shield: One moment...", channel, token)

    case DiscordActions.unban_user(user_to_unban["id"], guild_id, token) do
      {:ok} ->
        DiscordActions.edit_message(":shield: User `#{user_to_unban["username"]}\##{user_to_unban["discriminator"]}` has been unbanned", message_to_edit, channel, token)
      {:error, error} ->
        IO.inspect error
        case error["code"] do
          50013 ->
            DiscordActions.edit_message(":x: I don't have permission to unban that user", message_to_edit, channel, token)
          10026 ->
            DiscordActions.edit_message(":x: That user isn't banned", message_to_edit, channel, token)
          _ ->
            DiscordActions.edit_message(":x: Sorry, an unknown error occurred", message_to_edit, channel, token)
        end
    end
  end

  def handle_command({"unban", [user_id? | _]}, %{"authorization" => %{"discord_token" => token}} = bot_config, %{:data => %{:guild_id => guild_id, "channel_id" => channel, "mentions" => []}} = discord_payload) do
     {_, %{"id" => message_to_edit}} = DiscordActions.send_message_to_channel(":shield: One moment...", channel, token)
    case DiscordActions.unban_user(user_id?, guild_id, token) do
      {:ok} ->
        DiscordActions.edit_message(":shield: User has been unbanned", message_to_edit, channel, token)
      {:error, error} ->
        case error["code"] do
          50013 ->
            DiscordActions.edit_message(":x: I don't have permission to unban that user", message_to_edit, channel, token)
          10026 ->
            DiscordActions.edit_message(":x: That user isn't banned", message_to_edit, channel, token)
          e when is_map(error) ->
            DiscordActions.edit_message(":x: Invalid user ID", message_to_edit, channel, token)
          _ ->
            DiscordActions.edit_message(":x: Sorry, an unknown error occurred", message_to_edit, channel, token)
        end
    end
  end

  #
  # Kick
  #

  def handle_command({"kick", args}, %{"authorization" => %{"discord_token" => token}} = bot_config, %{:data => %{:guild_id => guild_id, "channel_id" => channel, "mentions" => [user_to_kick | _]}} = discord_payload) do
    {_, %{"id" => message_to_edit}} = DiscordActions.send_message_to_channel(":shield: One moment...", channel, token)

    case DiscordActions.kick_user(user_to_kick["id"], guild_id, token) do
      {:ok} ->
        DiscordActions.edit_message(":shield: User `#{user_to_kick["username"]}\##{user_to_kick["discriminator"]}` has been kicked", message_to_edit, channel, token)
      {:error, error} ->
        case error["code"] do
          50013 ->
            DiscordActions.edit_message(":x: I don't have permission to kick that user", message_to_edit, channel, token)
          _ ->
            DiscordActions.edit_message(":x: Sorry, an unknown error occurred", message_to_edit, channel, token)
        end
    end
  end

  def handle_command({"kick", [user_id? | _]}, %{"authorization" => %{"discord_token" => token}} = bot_config, %{:data => %{:guild_id => guild_id, "channel_id" => channel, "mentions" => []}} = discord_payload) do
    {_, %{"id" => message_to_edit}} = DiscordActions.send_message_to_channel(":shield: One moment...", channel, token)
   case DiscordActions.kick_user(user_id?, guild_id, token) do
     {:ok} ->
       DiscordActions.edit_message(":shield: User has been kicked", message_to_edit, channel, token)
     {:error, error} ->
       case error["code"] do
         50013 ->
           DiscordActions.edit_message(":x: I don't have permission to kick that user", message_to_edit, channel, token)
         e when is_map(error) ->
           DiscordActions.edit_message(":x: Invalid user ID", message_to_edit, channel, token)
         _ ->
           DiscordActions.edit_message(":x: Sorry, an unknown error occurred", message_to_edit, channel, token)
       end
    end
  end

  #
  # Purge
  #

  def handle_command({"purge", [amount? | _]}, %{"authorization" => %{"discord_token" => token}} = bot_config, %{:data => %{:guild_id => guild_id, "channel_id" => channel}} = discord_payload) do
    case Integer.parse(amount?) do
      {n, _} when is_number(n) and n < 101 and n > 1 ->
        {_, %{"id" => message_to_edit}} = DiscordActions.send_message_to_channel(":shield: One moment...", channel, token)

        case DiscordActions.fetch_messages(channel, token, n, message_to_edit) do
          {:ok, messages} ->
            message_ids = messages |> Enum.map(fn m -> m["id"] end)
            case DiscordActions.purge_messages(message_ids, channel, token) do
              {:ok} ->
                DiscordActions.edit_message(":shield: Purged `#{n}` messages", message_to_edit, channel, token)
              {:error, error} ->
                case error["code"] do
                  50013 ->
                    DiscordActions.edit_message(":x: I don't have permission to purge messages", message_to_edit, channel, token)
                  _ ->
                    DiscordActions.edit_message(":x: Sorry, an unknown error occurred", message_to_edit, channel, token)
                end
            end
          {:error} ->
            DiscordActions.edit_message(":x: Sorry, an unknown error occurred", message_to_edit, channel, token)
        end
      {n, _} when is_number(n) ->
        DiscordActions.send_message_to_channel(":x: Purge amount must be between 2 and 100", channel, token)
      _ ->
        DiscordActions.send_message_to_channel(":x: You must specify an amount of messages to purge", channel, token)
    end
  end
end