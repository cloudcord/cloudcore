defmodule DiscordGatewayGs.ModuleExecutor.Modules.CloudCordInfo do
  @behaviour DiscordGatewayGs.ModuleExecutor.CCModule

  alias DiscordGatewayGs.ModuleExecutor.Actions.DiscordActions

  def handle_command({"ccinfo", args}, %{"status" => %{"node" => node, "pid" => pid}, "name" => name, "authorization" => %{"discord_token" => token}} = bot_config, %{:data => %{"channel_id" => channel}} = discord_payload) do
    [{_, node_name}] = :ets.lookup(:node_info, "identifier");
    msg = "**CloudCord Info: `#{name}`**\nNode: `#{node_name}`"

    DiscordActions.send_message_to_channel(msg, channel, token)
  end
end