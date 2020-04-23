defmodule DiscordGatewayGs.ModuleExecutor.Actions.DiscordActions do

  @spec send_message_to_channel(String.t(), String.t(), String.t()) :: {:ok} | nil
  def send_message_to_channel(message, channel, token) do
    message = message
    |> String.replace(~r/@(everyone|here)/, ~s"@\u200beveryone")

    {_, %HTTPoison.Response{:body => b}} = HTTPoison.post("https://discordapp.com/api/v6/channels/#{channel}/messages", Poison.encode!(%{"content" => message}), [{"Authorization", "Bot " <> token}, {"Content-Type", "application/json"}])
    
    discord_message = b
    |> Poison.decode!

    {:ok, discord_message}
  end

  def edit_message(new_content, message_id, channel, token) do
    new_content = new_content
    |> String.replace(~r/@(everyone|here)/, ~s"@\u200beveryone")

    {_, %HTTPoison.Response{:body => b}} = HTTPoison.patch("https://discordapp.com/api/v6/channels/#{channel}/messages/#{message_id}", Poison.encode!(%{"content" => new_content}), [{"Authorization", "Bot " <> token}, {"Content-Type", "application/json"}])

    discord_message = b
    |> Poison.decode!

    {:ok, discord_message}
  end

  def edit_message_to_embed(new_embed, message_id, channel, token) do
    {_, %HTTPoison.Response{:body => b}} = HTTPoison.patch("https://discordapp.com/api/v6/channels/#{channel}/messages/#{message_id}", Poison.encode!(%{"content" => "", "embed" => new_embed}), [{"Authorization", "Bot " <> token}, {"Content-Type", "application/json"}])

    discord_message = b
    |> Poison.decode!

    {:ok, discord_message}
  end

  def send_embed_to_channel(embed, channel, token) do
    {_, %HTTPoison.Response{:body => b}} = HTTPoison.post("https://discordapp.com/api/v6/channels/#{channel}/messages", Poison.encode!(%{"embed" => embed}), [{"Authorization", "Bot " <> token}, {"Content-Type", "application/json"}])

    {:ok, (b |> Poison.decode!)}
  end

  def ban_user(user_id, guild_id, token, reason? \\ "") do
     {_, resp} = HTTPoison.put("https://discordapp.com/api/v6/guilds/#{guild_id}/bans/#{user_id}?reason=#{reason?}", "", [{"Authorization", "Bot " <> token}, {"Content-Type", "application/json"}])

     case resp do
       %HTTPoison.Response{:status_code => 204} -> {:ok}
       %HTTPoison.Response{:body => b} -> {:error, Poison.decode!(b)}
     end
  end

  def unban_user(user_id, guild_id, token) do
    {_, resp} = HTTPoison.delete("https://discordapp.com/api/v6/guilds/#{guild_id}/bans/#{user_id}", [{"Authorization", "Bot " <> token}, {"Content-Type", "application/json"}])

    case resp do
      %HTTPoison.Response{:status_code => 204} -> {:ok}
      %HTTPoison.Response{:body => b} -> {:error, Poison.decode!(b)}
    end
  end

  def kick_user(user_id, guild_id, token) do
    {_, resp} = HTTPoison.delete("https://discordapp.com/api/v6/guilds/#{guild_id}/members/#{user_id}", [{"Authorization", "Bot " <> token}, {"Content-Type", "application/json"}])

    case resp do
      %HTTPoison.Response{:status_code => 204} -> {:ok}
      %HTTPoison.Response{:body => b} -> {:error, Poison.decode!(b)}
    end
  end

  def purge_messages(message_ids, channel_id, token) do
    {_, resp} = HTTPoison.post("https://discordapp.com/api/v6/channels/#{channel_id}/messages/bulk-delete", Poison.encode!(%{"messages" => message_ids}), [{"Authorization", "Bot " <> token}, {"Content-Type", "application/json"}])

    case resp do
      %HTTPoison.Response{:status_code => 204} -> {:ok}
      %HTTPoison.Response{:body => b} -> {:error, Poison.decode!(b)}
    end
  end

  def fetch_messages(channel_id, token, limit? \\ 100, before? \\ "") do
    {_, %HTTPoison.Response{:body => b}} = HTTPoison.get("https://discordapp.com/api/v6/channels/#{channel_id}/messages?limit=#{limit?}&before=#{before?}", [{"Authorization", "Bot " <> token}, {"Content-Type", "application/json"}])

    case Poison.decode!(b) do
        m when is_list(m) -> {:ok, m}
        _ -> {:error}
    end
  end

end