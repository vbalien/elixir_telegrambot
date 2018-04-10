defmodule Telegrambot do
  use Application
  require Logger

  def start(_type, _args) do
    import Supervisor.Spec

    children = [
      Plug.Adapters.Cowboy.child_spec(:http, Telegrambot.Poller, [], port: 1111),
      worker(Telegrambot.Matcher, [])
    ]

    Logger.info("Started application")
    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
