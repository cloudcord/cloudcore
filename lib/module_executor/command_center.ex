defmodule DiscordGatewayGs.ModuleExecutor.CommandCenter2 do

  alias DiscordGatewayGs.ModuleExecutor.Checks

  def static_variable_map do
    %{
      "author:id" => {"discord_payload", &is_binary/1},
      "author:username" => {"discord_payload", &is_binary/1},
    }
  end

  def handle_command(payload, {bot_token, bot_id} = bot_data) do
    IO.puts "start lookup"
    if !payload.data["author"]["bot"] do
      Task.start fn ->
        GenServer.cast :local_redis_client, {:publish, "cc-messages", Poison.encode!(
          %{
            "content" => payload.data["content"],
            "author" => Map.merge(payload.data["author"], %{"id" => Integer.to_string(payload.data["author"]["id"])})
          }
        )}
      end
      [{id, %{"config" => bot_config}}] = :ets.lookup(:available_bots, Integer.to_string(bot_id))
      if String.starts_with?(payload.data["content"], bot_config["interface"]["command_prefix"]) do
        [attempted_command | args] = payload.data["content"] |> String.to_charlist() |> tl() |> to_string() |> String.split(" ")

        custom? = Map.get(bot_config["custom_commands"], attempted_command)

        if custom? != nil do
          handle_custom_command({attempted_command, args}, custom?["actions"], bot_config, payload) 
        else
          case :ets.lookup(:commands, attempted_command) do
            [{name, info}] ->
              if Map.has_key?(bot_config["modules"], info["module"]) do
                case bot_config["modules"][info["module"]] do
                  %{"config" => %{"disabled_commands" => dc}} ->
                    if(!Enum.member?(dc, attempted_command)) do
                      DiscordGatewayGs.ModuleExecutor.ModuleCenter.handle_moduled_command({attempted_command, args}, info, {bot_config, payload})
                    end
                  _ ->
                    DiscordGatewayGs.ModuleExecutor.ModuleCenter.handle_moduled_command({attempted_command, args}, info, {bot_config, payload})
                end
              end
            _ -> IO.puts "no_match"
          end
        end
      end
    end
  end


  # -=-=-=-=-=-=-=-=-=-=-
  #   PRIVATE FUNCTIONS
  # -=-=-=-=-=-=-=-=-=-=-

  defp find_var_tokens(message) do
    Regex.scan(~r/\<.*?\>/, message)
    |> Enum.map(fn t ->
      t
      |> Enum.at(0)
    end)
  end

  defp strip_tokens_to_vars(tokens, {bot_config, discord_payload}) do
    final_outputs = []

    tokens = tokens
    |> Enum.map(fn t ->
      t
      |> String.replace("<", "")
      |> String.replace(">", "")
    end)

    m = %{
      "discord_payload" => discord_payload,
      "bot_config" => bot_config
    }

    Enum.map(tokens, fn token ->
      {required, check} = static_variable_map[token]
      case token do
        "author:id" ->
          m[required].data["author"]["id"]
        "author:username" ->
          m[required].data["author"]["username"]
      end
    end)
  end

  # <author:username>

  defp handle_custom_command({command, args}, actions, bot_config, discord_payload) do
    GenServer.cast(:local_redis_client, {:publish, "cc-realtime-events", %{"action" => "command_executed", "data" => %{"creator": bot_config["creator"], "bot_id": bot_config["id"], "command_executed": command, author: discord_payload.data["author"]}}})
    Enum.each(actions, fn action ->
      [{action, info}] = action |> Map.to_list
      action_function = DiscordGatewayGs.ModuleExecutor.Actions.ActionMap.actions[action]

      case action do
        "SEND_MESSAGE_TO_CHANNEL" ->
          tokens = info["message"]
          |> find_var_tokens

          if length(tokens) > 0 do
            compiled = tokens
            |> strip_tokens_to_vars({bot_config, discord_payload})
            
            final_writable_message = tokens |> Enum.with_index(0) |> Enum.reduce(info["message"], fn {t, i}, acc -> String.replace(acc, t, Enum.at(compiled, i)) end) 

            action_function.(final_writable_message, discord_payload.data["channel_id"], bot_config["authorization"]["discord_token"])
          else
            action_function.(info["message"], discord_payload.data["channel_id"], bot_config["authorization"]["discord_token"])
          end
        "HTTP_POST" ->
          action_function.(info, discord_payload, bot_config, "command:#{command}")
      end
    end)
  end
end