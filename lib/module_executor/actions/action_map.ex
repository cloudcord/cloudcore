defmodule DiscordGatewayGs.ModuleExecutor.Actions.ActionMap do
  alias DiscordGatewayGs.ModuleExecutor.Actions.{DiscordActions, OtherActions}

  def actions do
    %{
      "SEND_MESSAGE_TO_CHANNEL" => &DiscordActions.send_message_to_channel/3,
      "SEND_EMBED_TO_CHANNEL" => &DiscordActions.send_embed_to_channel/3,
      "HTTP_POST" => &OtherActions.http_post/4
    }
  end
end