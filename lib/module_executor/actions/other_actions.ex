defmodule DiscordGatewayGs.ModuleExecutor.Actions.OtherActions do
  alias DiscordGatewayGs.ModuleExecutor.Actions.DiscordActions

  def http_post(%{"url" => url} = params, payload, %{"id" => bot_id, "authorization" => %{"discord_token" => token}}, emitter) do
    [{_, node_name}] = :ets.lookup(:node_info, "identifier")
  
    payload = payload.data
    |> Map.put("id", Integer.to_string(payload.data["id"]))
    |> Map.put("channel_id", Integer.to_string(payload.data["channel_id"]))
    |> Map.put("guild_id", Integer.to_string(payload.data.guild_id))
    |> Map.put("author", Map.put(payload.data["author"], "id", Integer.to_string(payload.data["author"]["id"])))

    {_, %HTTPoison.Response{:body => b, :status_code => status}} = HTTPoison.post(
      url,
      Poison.encode!(payload),
      [
        {"X-CloudCord-BotID", bot_id},
        {"X-CloudCord-Emitter", emitter},
        {"X-CloudCord-APIBase", "https://api-dev.cloudcord.io"},
        {"X-CloudCord-Node", node_name},
        {"User-Agent", "cloudcord/1.1 (#{node_name})"},
        {"Content-Type", "application/json"}
      ],
      [
        recv_timeout: 5000
      ]
    )

    with status <- 200 do
      case Poison.decode!(b) do
        %{"action" => "SEND_MESSAGE_TO_CHANNEL", "parameters" => params} ->
          DiscordActions.send_message_to_channel(params["message"], params["channel_id"], token)
        %{"action" => "SEND_EMBED_TO_CHANNEL", "parameters" => params} ->
          DiscordActions.send_embed_to_channel(params["embed"], params["channel_id"], token)
        _ -> {:error, "invalid_action"}
      end
    end
  end
end