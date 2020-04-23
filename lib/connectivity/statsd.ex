defmodule DiscordGatewayGs.Statix do
  use Instruments

  def node_name do
    System.get_env("MY_POD_NAME") || "dev"
  end

  def increment_messages() do
    Instruments.increment("#{node_name}.mps", 1)
  end

  def increment_gwe(),
    do: Instruments.increment("#{node_name}.gwe", 1)

  def set_bots_running_gauge(amount),
    do: Instruments.gauge("#{node_name}.bots_running", amount)
end