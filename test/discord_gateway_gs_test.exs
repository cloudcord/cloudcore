defmodule DiscordGatewayGsTest do
  use ExUnit.Case
  doctest DiscordGatewayGs

  test "greets the world" do
    assert DiscordGatewayGs.hello() == :world
  end
end
