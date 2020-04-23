defmodule DiscordGatewayGs.MixProject do
  use Mix.Project

  def project do
    [
      app: :discord_gateway_gs,
      version: "0.1.0",
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger, :libcluster, :httpoison],
      mod: {DiscordGatewayGs, []}
    ]
  end

  defp deps do
    [
      {:websocket_client, "~> 1.2.4"},
      {:httpoison, "~> 1.4"},
      {:poison, "~> 3.1"},
      {:redix, ">= 0.9.0"},
      {:horde, "~> 0.4.0-rc.2"},
      {:libcluster, "~> 3.0.3"},
      {:distillery, "~> 2.0"},
      {:instruments, "~>1.1.1"},
      {:websockex, "~> 0.4.0"},
      {:gen_stage, "~> 0.14"}
    ]
  end
end
