defmodule DiscordGatewayGs.ModuleExecutor.Modules.StockX do
  @behaviour DiscordGatewayGs.ModuleExecutor.DiscordActions

  alias DiscordGatewayGs.ModuleExecutor.Actions.DiscordActions

  def handle_command({"stockx", args}, %{"authorization" => %{"discord_token" => token}} = bot_config, %{:data => %{"channel_id" => channel}} = discord_payload) do
    {_, %{"id" => message_to_edit}} = DiscordActions.send_message_to_channel(":mag_right: Searching...", channel, token)

    query = args
    |> Enum.join(" ")
    |> URI.encode

    case HTTPoison.post("https://xw7sbct9v6-dsn.algolia.net/1/indexes/products/query", Poison.encode!(%{"params" => "query={'#{args}'}&hitsPerPage=1"}), [{"x-algolia-api-key", "6bfb5abee4dcd8cea8f0ca1ca085c2b3"}, {"x-algolia-application-id", "XW7SBCT9V6"}]) do
      {_, %HTTPoison.Response{:body => b}} ->
        case Poison.decode!(b) do
          %{"hits" => [i | _]} ->
            embed = %{
              "thumbnail" => %{
                "url" => i["thumbnail_url"],
              },
              "color" => 8015747,
              "fields" => [
                %{
                  "name" => "Name",
                  "value" => i["name"],
                  "inline" => false
                },
                %{
                  "name" => "Style ID",
                  "value" => i["style_id"],
                  "inline" => true
                },
                %{
                  "name" => "Highest Bid",
                  "value" => "$#{i["highest_bid"]}",
                  "inline" => true
                },
                %{
                  "name" => "Lowest Ask",
                  "value" => "$#{i["lowest_ask"]}",
                  "inline" => true,
                },
                %{
                  "name" => "Last Sale",
                  "value" => "$#{i["last_sale"]}",
                  "inline" => true
                }
              ]
            }
    
            DiscordActions.edit_message_to_embed(embed, message_to_edit, channel, token)
          _ ->
            DiscordActions.edit_message(":x: Sorry, that product could not be found.", message_to_edit, channel, token)
        end
      _ ->
        DiscordActions.edit_message("Sorry, that product could not be found.", message_to_edit, channel, token)
    end
  end
end