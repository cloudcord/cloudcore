defmodule DiscordGatewayGs.Structs.GuildState do
  @type t :: %{
    id: Number.t(),
    icon: String.t() | nil,
    member_count: Number.t(),
    large: boolean,
    mfa_level: Number.t(),
    owner_id: Number.t(),
    premium_tier: Number.t() | nil,
    unavailable: boolean,
    verification_level: Number.t(),
    vanity_url_code: String.t() | nil
  }

  defstruct id: nil,
            icon: nil,
            member_count: nil,
            large: nil,
            name: nil,
            mfa_level: nil,
            owner_id: nil,
            premium_tier: nil,
            unavailable: nil,
            verification_level: nil,
            vanity_url_code: nil
end