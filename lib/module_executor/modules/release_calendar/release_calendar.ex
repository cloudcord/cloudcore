defmodule DiscordGatewayGs.ModuleExecutor.Modules.ReleaseCalendar do
  @behaviour DiscordGatewayGs.ModuleExecutor.DiscordActions

  alias DiscordGatewayGs.ModuleExecutor.Actions.DiscordActions

  def handle_command({"release", _}, %{"authorization" => %{"discord_token" => token}} = bot_config, %{:data => %{"channel_id" => channel}} = discord_payload) do
    case HTTPoison.get("https://solelinks.com/api/releases?page=1") do
      {_, %HTTPoison.Response{:body => b}} ->
        %{"data" => %{"data" => [i | _]}} = b |> Poison.decode!

        embed = %{
          "thumbnail" => %{
            "url" => i["title_image_url"],
          },
          "color" => 16777215,
          "fields" => [
            %{
              "name" => "Title",
              "value" => i["title"],
              "inline" => false
            },
            %{
              "name" => "Release Date",
              "value" => i["release_date"],
              "inline" => true
            },
            %{
              "name" => "Style Code",
              "value" => i["style_code"],
              "inline" => true
            },
            %{
              "name" => "Price",
              "value" => i["price"],
              "inline" => true,
            },
            %{
              "name" => "Last Sale",
              "value" => i["last_sale"],
              "inline" => true
            },
            %{
              "name" => "Color",
              "value" => i["color"],
              "inline" => true
            }
          ]
        }

        DiscordActions.send_embed_to_channel(embed, channel, token)
      _ ->
        DiscordActions.send_message_to_channel("Sorry, that product could not be found.", channel, token)
    end
  end
end