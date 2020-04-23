defmodule DiscordGatewayGs.ModuleExecutor.Modules.UrbanDictionary do
  @behaviour DiscordGatewayGs.ModuleExecutor.CCModule

  alias DiscordGatewayGs.ModuleExecutor.Actions.DiscordActions

  def handle_command({command, args}, %{"authorization" => %{"discord_token" => token}} = bot_config, %{:data => %{"channel_id" => channel}} = discord_payload) do
    {_, %{"id" => message_to_edit}} = DiscordActions.send_message_to_channel(":mag_right: Looking up...", channel, token)

    query = args
    |> Enum.join(" ")
    |> URI.encode

    case HTTPoison.get("https://api.urbandictionary.com/v0/define?term=#{query}") do
      {_, %HTTPoison.Response{:body => b}} ->
        case Poison.decode!(b) do
          %{"list" => [d | _]} -> 
            msg = "**Urban Dictionary: `#{d["word"]}`**\nDefinition: *#{d["definition"]}*"
            DiscordActions.edit_message(msg, message_to_edit, channel, token)
          _ -> DiscordActions.edit_message(":x: That definition isn't in the Urban Dictionary!")
        end
      _ ->
        DiscordActions.edit_message(":x: Sorry, an error occurred fetching UrbanDictionary.", message_to_edit, channel, token)
    end
  end
end