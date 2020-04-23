defmodule DiscordGatewayGs.ModuleExecutor.Match do
  def verify_command_match(command, args) do
    l = length(args)
    {min_args, max_args} = args
    min_args <= l
  end

  
end