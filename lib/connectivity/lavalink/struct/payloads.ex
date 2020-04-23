defmodule LavaPotion.Struct.VoiceUpdate do
  @derive [Poison.Encoder]
  defstruct [:guildId, :sessionId, :event, op: "voiceUpdate"]
end

defmodule LavaPotion.Struct.Play do
  @derive [Poison.Encoder]
  defstruct [:guildId, :track, op: "play"] # startTime and endTime disabled for now
end

defmodule LavaPotion.Struct.Stop do
  @derive [Poison.Encoder]
  defstruct [:guildId, op: "stop"]
end

defmodule LavaPotion.Struct.Destroy do
  @derive [Poison.Encoder]
  defstruct [:guildId, op: "destroy"]
end

defmodule LavaPotion.Struct.Volume do
  @derive [Poison.Encoder]
  defstruct [:guildId, :volume, op: "volume"]
end

defmodule LavaPotion.Struct.Pause do
  @derive [Poison.Encoder]
  defstruct [:guildId, :pause, op: "pause"]
end

defmodule LavaPotion.Struct.Seek do
  @derive [Poison.Encoder]
  defstruct [:guildId, :position, op: "seek"]
end

defmodule LavaPotion.Struct.Equalizer do
  @derive [Poison.Encoder]
  defstruct [:guildId, :bands, op: "equalizer"]
end

defmodule LavaPotion.Struct.LoadTrackResponse do
  @derive [Poison.Encoder]
  defstruct [:loadType, :playlistInfo, :tracks]
end

defmodule LavaPotion.Struct.AudioTrack do
  @derive [Poison.Encoder]
  defstruct [:title, :author, :length, :identifier, :uri, :isStream, :isSeekable, :position]
end

defmodule LavaPotion.Struct.Stats do
  @derive [Poison.Encoder]
  defstruct [:players, :playing_players, :uptime, :memory, :cpu, :frame_stats]
end