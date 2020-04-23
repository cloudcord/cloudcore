defmodule DiscordGatewayGs.Structs.Module do
  @type t :: %{
    enabled: boolean,
    icon: String.t() | nil,
    commands: Map.t(),
    description: String.t(),
    name: String.t(),
    internal_module: boolean| nil,
    internal_reference: String.t() | nil,
    gwe_sub: List.t() | nil
  }

  defstruct enabled: nil,
            commands: nil,
            description: nil,
            icon: nil,
            name: nil,
            internal_module: nil,
            internal_reference: nil,
            gwe_sub: nil
end