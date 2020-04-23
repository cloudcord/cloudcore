defmodule LavaPotion.Stage do
  use Supervisor

  alias LavaPotion.Stage.{Producer, Middle}

  def start_link() do
    Supervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_arg) do
    children = [
      worker(Producer, []),
      worker(Middle, [])
    ]
    options = [
      strategy: :one_for_one,
      name: __MODULE__
    ]
    Supervisor.init(children, options)
  end
end