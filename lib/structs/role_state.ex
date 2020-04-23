defmodule DiscordGatewayGs.Structs.RoleState do
  @type t :: %{
    id: Number.t(),
    color: Number.t() | 0,
    hoist: boolean,
    managed: boolean,
    mentionable: boolean,
    name: String.t() | nil,
    permissions: Number.t(),
    position: Number.t()
  }

  defstruct id: nil,
            color: nil,
            hoist: nil,
            managed: nil,
            mentionable: nil,
            name: nil,
            permissions: nil,
            position: nil
end