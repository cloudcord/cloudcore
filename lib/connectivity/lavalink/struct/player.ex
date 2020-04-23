defmodule LavaPotion.Struct.Player do
  alias LavaPotion.Struct.Node
  alias LavaPotion.Struct.Client

  defstruct [:node, :guild_id, :session_id, :token, :endpoint, :track, :volume, :is_real, :paused, :raw_timestamp, :raw_position]

  def initialize(player = %__MODULE__{node: %Node{address: address, client: %Client{user_id: user_id}}}) do
    WebSockex.cast(Node.pid("#{user_id}_#{address}"), {:voice_update, player})
  end

  def play(player = %__MODULE__{node: %Node{address: address, client: %Client{user_id: user_id}}}, track) when is_binary(track) do
    info = LavaPotion.Api.decode_track(track)
    WebSockex.cast(Node.pid("#{user_id}_#{address}"), {:play, player, {track, info}})
  end

  def play(player = %__MODULE__{node: %Node{address: old_address, client: %Client{user_id: user_id}}}, %{"track" => track, "info" => info = %{}}) do
    {:ok, node = %Node{address: address, client: %Client{user_id: user_id}}} = Node.best_node()
    if old_address !== address do
      set_node(player, node)
      WebSockex.cast(Node.pid("#{user_id}_#{address}"), {:play, player, {track, info}})
    else
      WebSockex.cast(Node.pid("#{user_id}_#{old_address}"), {:play, player, {track, info}})
    end
  end

  def volume(player = %__MODULE__{node: %Node{address: address, client: %Client{user_id: user_id}}}, volume) when is_number(volume) and volume >= 0 and volume <= 1000 do
    WebSockex.cast(Node.pid("#{user_id}_#{address}"), {:volume, player, volume})
  end

  def seek(player = %__MODULE__{node: %Node{address: address, client: %Client{user_id: user_id}}}, position) when is_number(position) and position >= 0 do
    WebSockex.cast(Node.pid("#{user_id}_#{address}"), {:seek, player, position})
  end

  def pause(player = %__MODULE__{node: %Node{address: address, client: %Client{user_id: user_id}}}), do: WebSockex.cast(Node.pid("#{user_id}_#{address}"), {:pause, player, true})
  def resume(player = %__MODULE__{node: %Node{address: address, client: %Client{user_id: user_id}}}), do: WebSockex.cast(Node.pid("#{user_id}_#{address}"), {:pause, player, false})
  def destroy(player = %__MODULE__{node: %Node{address: address, client: %Client{user_id: user_id}}}), do: WebSockex.cast(Node.pid("#{user_id}_#{address}"), {:destroy, player})
  def stop(player = %__MODULE__{node: %Node{address: address, client: %Client{user_id: user_id}}}), do: WebSockex.cast(Node.pid("#{user_id}_#{address}"), {:stop, player})

  def position(player = %__MODULE__{node: %Node{}, raw_position: raw_position, raw_timestamp: raw_timestamp})
    when not is_nil(raw_position) and not is_nil(raw_timestamp) do
    %__MODULE__{paused: paused, track: {_, %{"length" => length}}} = player
    if paused do
      min(raw_position, length)
    else
      min(raw_position + (:os.system_time(:millisecond) - raw_timestamp), length)
    end
  end

  def set_node(player = %__MODULE__{node: %Node{address: address, client: %Client{user_id: user_id}}, is_real: true}, node = %Node{}) do
    WebSockex.cast(Node.pid("#{user_id}_#{address}"), {:update_node, player, node})
  end
end