defmodule DiscordGatewayGs.ModuleExecutor.CCModule do
  @callback handle_event(atom(), Map.t(), String.t()) :: :ok | nil
  @callback handle_command(tuple(), Map.t(), Map.t()) :: :ok | nil
  @optional_callbacks handle_event: 3, handle_command: 3
end