defmodule DiscordGatewayGs.ModuleExecutor.Modules.AdidasGen do
  @behaviour DiscordGatewayGs.ModuleExecutor.DiscordActions

  alias DiscordGatewayGs.ModuleExecutor.Actions.DiscordActions

  def handle_command({"agen", args}, %{"authorization" => %{"discord_token" => token}} = bot_config, %{:data => %{"channel_id" => channel}} = discord_payload) do
    {_, %{"id" => message_to_edit}} = DiscordActions.send_message_to_channel(":control_knobs: Generating...", channel, token)

    case HTTPoison.post(
      "https://srs.adidas.com/scvRESTServices/account/createAccount",
      Poison.encode!(%{
        "source" => "90901",
        "countryOfSite" => "GB",
        "email" => List.first(args),
        "clientId" => "293FC0ECC43A4F5804C07A4ABC2FC833",
        "password" => "Password123",
        "minAgeConfirmation" => "Y",
        "version" => "13.0",
        "access_token_manager_id" => "jwt",
        "scope" => "pii mobile2web",
        "actionType" => "REGISTRATION"
      }),
      [
        {"Host", "srs.adidas.com"},
        {"Accept", "application/json"},
        {"Content-Type", "application/json"},
        {"Accept-Language", "en-gb"},
        {"User-Agent", "adidas/579 CFNetwork/894 Darwin/17.4.0"},
      ]) do
      {_, %HTTPoison.Response{:body => b}} ->
        case Poison.decode!(b) do
          %{"conditionCodeParameter" => %{"parameter" => [%{"name" => "eUCI"} | _]}} ->
            embed = %{
              "title" => "Adidas account generated",
              "description" => "#{List.first(args)}:Password123",
              "color" => 16777215
            }
    
            DiscordActions.edit_message_to_embed(embed, message_to_edit, channel, token)
          _ ->
            DiscordActions.edit_message(":x: Sorry, there has been an error. That email might already have an account.", message_to_edit, channel, token)
        end
      _ ->
        DiscordActions.edit_message(":x: Sorry, there has been an error.", message_to_edit, channel, token)
    end
  end
end