defmodule DiscordGatewayGs.Connectivity.SupremeMonitor do
  use WebSockex
  alias DiscordGatewayGs.ModuleExecutor.Actions.DiscordActions

  def start_link do
    WebSockex.start_link("ws://192.168.0.69:8080", __MODULE__, %{})
  end

  def handle_frame({type, msg}, state) do
    %{"pid" => id, "pname" => pname, "name" => name, "image_url_hi" => image, "size" => %{"name" => size_name}} = Poison.decode!(msg)
    IO.inspect name
    DiscordActions.send_embed_to_channel(
      %{
        "thumbnail" => %{
          "url" => image
        },
        "title" => pname,
        "fields" => [
          %{
            "name" => "Style",
            "value" => name,
            "inline" => true
          },
          %{
            "name" => "Size",
            "value" => size_name,
            "inline" => true
          },
          %{
            "name" => "Links",
            "value" => "[Product Link](https://www.supremenewyork.com/shop/#{id})",
            "inline" =>  true
          }
        ]
      },
      "535097935923380246",
      "NDEwOTI4OTU4NTE1OTcwMDQ4.XNOHPg.e94qEP8W1PiJJ0L5hG35V0cv6ds"
    )
    {:ok, state}
  end

  def handle_cast({:send, {type, msg} = frame}, state) do
    IO.puts "Sending #{type} frame with payload: #{msg}"
    {:reply, frame, state}
  end
end