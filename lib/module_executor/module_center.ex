defmodule DiscordGatewayGs.ModuleExecutor.ModuleCenter do
  use Bitwise

  alias DiscordGatewayGs.ModuleExecutor.DiscordPermission

  @spec handle_moduled_command(tuple(), String.t(), tuple()) :: none()
  def handle_moduled_command({attempted_command, args} = command, command_info, {bot_config, discord_payload} = data) do
    GenServer.cast(:local_redis_client, {:publish, "cc-realtime-events", %{"action" => "command_executed", "data" => %{"creator": bot_config["creator"], "bot_id": bot_config["id"], "command_executed": attempted_command, author: Map.put(discord_payload.data["author"], "id", Integer.to_string(discord_payload.data["author"]["id"]))}}})
    %{"min_args" => min_args} = command_info
    module_config = bot_config["modules"][command_info["module"]]["config"]
    
    command_permissions = case module_config do
      %{"command_permissions" => %{^attempted_command => permissions}} ->
        permissions
      _ ->
        %{"type" => "everyone"}
    end
    
    case check_permissions(command_permissions, discord_payload) do
      {true, _} ->
        case length(args) do
          a when a >= min_args ->
            DiscordGatewayGs.ModuleExecutor.ModuleMap.modules[command_info["module"]].handle_command({attempted_command, args}, bot_config, discord_payload)
          _ ->
            command_usage = command_info["usage"]
            |> String.replace("(command)", bot_config["interface"]["command_prefix"] <> attempted_command)
    
            DiscordGatewayGs.ModuleExecutor.Actions.DiscordActions.send_message_to_channel(
              "Invalid command usage!\nUsage: `#{command_usage}`",
              discord_payload.data["channel_id"],
              bot_config["authorization"]["discord_token"]
            )
        end
      {false, msg} ->
        DiscordGatewayGs.ModuleExecutor.Actions.DiscordActions.send_message_to_channel(
          ":x: #{msg}",
          discord_payload.data["channel_id"],
          bot_config["authorization"]["discord_token"]
        )
    end
  end

  defp check_permissions(permissions_obj, payload) do
    case permissions_obj["type"] do
      "everyone" ->
        {true, ""}
      "named_role" ->
        member = payload.data["member"]
        #{_, [_, roles]} = GenServer.call :local_redis_client, {:custom, ["HSCAN", payload.data.guild_id, "0", "MATCH", "role:*", "COUNT", "1000"]}

        roles = member.roles
        |> Enum.map(fn r ->
          {_, role} = GenServer.call :local_redis_client, {:hget, payload.data.guild_id, "role:#{r}"}
          Poison.decode!(role)
        end)

        if Enum.any?(roles, fn r -> String.downcase(r["name"]) == String.downcase(permissions_obj["named_role"]) end) || member_has_admin?(roles) do
          {true, ""}
        else
          {false, "You need to be admin or have a role named `#{permissions_obj["named_role"]}` to do that."}
        end
      _ -> {true, ""}
    end
  end

  defp member_has_admin?(member_roles) do
    member_permissions =
      member_roles
      |> Enum.reduce(0, fn role, bitset_acc ->
        bitset_acc ||| role["permissions"]
      end)
      |> DiscordPermission.from_bitset()
      |> Enum.member?(:administrator)
  end
end