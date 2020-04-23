defmodule DiscordGatewayGs.ModuleExecutor.ModuleMap do
  def modules do
    %{
      "cloudcord_info" => DiscordGatewayGs.ModuleExecutor.Modules.CloudCordInfo,
      "urban_dictionary" => DiscordGatewayGs.ModuleExecutor.Modules.UrbanDictionary,
      "music" => DiscordGatewayGs.ModuleExecutor.Modules.Music,
      "stockx_search" => DiscordGatewayGs.ModuleExecutor.Modules.StockX,
      "release_calendar" => DiscordGatewayGs.ModuleExecutor.Modules.ReleaseCalendar,
      "adidas_gen" => DiscordGatewayGs.ModuleExecutor.Modules.AdidasGen,
      "moderation" => DiscordGatewayGs.ModuleExecutor.Modules.Moderation
    }
  end
end