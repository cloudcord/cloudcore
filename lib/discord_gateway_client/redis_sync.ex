defmodule DiscordGatewayGs.RedisSync do
  use GenServer
  alias DiscordGatewayGs.Structs

  def start_link(state) do
    GenServer.start_link(__MODULE__, state, name: via_tuple(Integer.to_string(state)))
  end

  def init(guild) do
    schedule_key_expiry
    {:ok, %{id: guild}}
  end

  def send_guild_payload(guild_id, guild) do
    GenServer.cast via_tuple(guild_id), {:send_guild_payload, guild}
  end

  def guild_create(guild) do
    guild_state = struct(Structs.GuildState, guild)
    channels = guild.channels
    |> Enum.map(fn channel ->
      struct(Structs.ChannelState, channel)
    end)
    members = guild.members
    |> Enum.map(fn member ->
      voice? = guild.voice_states
      |> Enum.find(fn vc -> (vc.user_id == member.user.id) end)
      || nil

      member = Map.put(member, :voice, voice?)

      struct(Structs.MemberState, member)
    end)
    roles = guild.roles
    |> Enum.map(fn role ->
      struct(Structs.RoleState, role)
    end)

    DiscordGatewayGs.RedisConnector.insert_guild(guild_state, channels, members, roles)
  end

  def guild_member_add(%{data: data} = payload) do
    atomic_data = data |> Map.new(fn {k, v} -> {String.to_atom(k), v} end)

    member = struct(Structs.MemberState, atomic_data)
    
    GenServer.cast :local_redis_client, {:custom, ["HSET", Integer.to_string(data["guild_id"]), "member:" <> Integer.to_string(member.user["id"]), Poison.encode!(member)]}
  end

  def guild_member_remove(%{data: data} = payload) do
    GenServer.cast :local_redis_client, {:hdel, Integer.to_string(data["guild_id"]), Integer.to_string(data["user"]["id"])}
  end

  def guild_member_update(%{data: data} = payload) do
    {_, member} = GenServer.call :local_redis_client, {:hget, Integer.to_string(data["guild_id"]), "member:" <> Integer.to_string(data["user"]["id"])}
    member = member |> Poison.decode!

    new_member = member
    |> Map.put(:nick, data["nick"])
    |> Map.put(:roles, data["roles"])
    |> Map.put(:user, data["user"])
    |> Map.put(:voice, member["voice"])

    new_member = struct(Structs.MemberState, new_member)

    GenServer.cast :local_redis_client, {:custom, ["HSET", Integer.to_string(data["guild_id"]), "member:" <> Integer.to_string(new_member.user["id"]), Poison.encode!(new_member)]}
  end

  def guild_role_create_or_update(%{data: data} = payload) do
    atomic_data = data["role"] |> Map.new(fn {k, v} -> {String.to_atom(k), v} end)

    new_role = struct(Structs.RoleState, atomic_data)

    GenServer.cast :local_redis_client, {:custom, ["HSET", Integer.to_string(data["guild_id"]), "role:" <> Integer.to_string(new_role.id), Poison.encode!(new_role)]}
  end

  def voice_state_update(%{data: data} = payload) do
    {_, member} = GenServer.call :local_redis_client, {:hget, Integer.to_string(data.guild_id), "member:" <> Integer.to_string(data.user_id)}
    member = member |> Poison.decode!(as: %Structs.MemberState{})

    new_member = case data do
      %{:channel_id => nil} ->
         Map.merge(member, %{voice: nil})
      _ ->
        m = data["member"]
        data = Map.delete(data, "member")
        m = Map.put(m, :voice, data)
        struct(Structs.MemberState, m)
    end

    GenServer.cast :local_redis_client, {:custom, ["HSET", Integer.to_string(data.guild_id), "member:" <> Integer.to_string(member.user["id"]), Poison.encode!(new_member)]}
  end


  def handle_cast({:send_guild_payload, payload}, state) do
    
  end

  def handle_info(:set_key_expiry, state) do
    schedule_key_expiry()
    GenServer.cast :local_redis_client, {:expire, Integer.to_string(state.id), 600}
    {:noreply, state}
  end

  defp schedule_key_expiry do
    Process.send_after self(), :set_key_expiry, 500000
  end

  defp via_tuple(name), do: {:via, Horde.Registry, {DiscordGatewayGs.GSRegistry, name}}
end