defmodule LavaPotion.Api do
  alias LavaPotion.Struct.{LoadTrackResponse, AudioTrack, Player, Node}

  def initialize(pid, guild_id, session_id, token, endpoint) when is_pid(pid) and is_binary(guild_id) and is_binary(session_id) and is_binary(token) and is_binary(endpoint) do
    WebSockex.cast(pid, {:voice_update, %Player{guild_id: guild_id, session_id: session_id, token: token, endpoint: endpoint, is_real: false}})
  end

  def initialize(pid, player = %Player{is_real: false}) when is_pid(pid) do
    WebSockex.cast(pid, {:voice_update, player})
  end

  def load_tracks(identifier) do
    {:ok, node} = Node.best_node()
    load_tracks(node, identifier)
  end

  def load_tracks(%Node{address: address, port: port, password: password}, identifier) do
    load_tracks(address, port, password, identifier)
  end

  def load_tracks(address, port, password, identifier) when is_binary(address) and is_number(port) and is_binary(password) and is_binary(identifier) do
    HTTPoison.get!("http://#{address}:#{port}/loadtracks?identifier=#{URI.encode(identifier)}", ["Authorization": password]).body
    |> Poison.decode!(as: %LoadTrackResponse{})
  end

  def decode_track(track) do
    {:ok, node} = Node.best_node()
    decode_track(node, track)
  end

  def decode_track(%Node{address: address, port: port, password: password}, track) do
    decode_track(address, port, password, track)
  end

  def decode_track(address, port, password, track) when is_binary(address) and is_number(port) and is_binary(password) and is_binary(track) do
    HTTPoison.get!("http://#{address}:#{port}/decodetrack?track=#{URI.encode(track)}", ["Authorization": password]).body
    |> Poison.decode!(as: %AudioTrack{})
  end
end