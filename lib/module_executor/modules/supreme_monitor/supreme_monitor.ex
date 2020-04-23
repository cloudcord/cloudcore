defmodule DiscordGatewayGs.ModuleExecutor.Modules.SupremeMonitor do
  @behaviour DiscordGatewayGs.ModuleExecutor.CCModule

  alias DiscordGatewayGs.ModuleExecutor.Actions.DiscordActions

  def handle_outer_event({:restock, product}, channel_id, token) do
    %{"id" => style_id, "name" => name, "image_url_hi" => image, "sizes" => sizes}  = product |> Poison.decode!

    IO.inspect sizes
    DiscordActions.send_embed_to_channel(
      %{
        "thumbnail" => %{
          "url" => "https:" <> image
        },
        "title" => "Monitor",
        "fields" => Enum.map(sizes, fn s ->
          %{
            "name" => s["name"],
            "value" => "[[ATC]](http://atc.bz/p?a=a&b=&p=304371&st=#{style_id}&s=#{s["id"]}&c=uk)",
            "inline" => true
          }
        end)
      },
      "535097935923380246",
      "NDEwOTI4OTU4NTE1OTcwMDQ4.XNOHPg.e94qEP8W1PiJJ0L5hG35V0cv6ds"
    )
  end
end