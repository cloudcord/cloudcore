defmodule DiscordGatewayGs.Structs.MemberState do
  @type t :: %{
    roles: List.t(),
    user: Map.t(),
    nick: String.t() | nil,
    voice: Map.t() | nil
  }

  defstruct roles: nil,
            user: nil,
            nick: nil,
            voice: nil
end