defmodule DiscordGatewayGs.Structs.ChannelState do
  @type t :: %{
    id: Number.t(),
    name: String.t(),
    nsfw: boolean,
    type: Number.t(),
    position: Number.t(),
    topic: String.t() | nil
  }

  defstruct id: nil,
            name: nil,
            nsfw: nil,
            type: nil,
            position: nil,
            topic: nil
end