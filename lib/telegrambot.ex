defmodule Telegrambot do
  use Application
  require Logger

  def start(_type, _args) do
    import Supervisor.Spec

    children = [
      Plug.Adapters.Cowboy.child_spec(:http, Telegrambot.Poller, [], port: 1111),
      worker(Telegrambot.Matcher, []),
      worker(Telegrambot.Database, [[db: "telegrambot"]])
    ]

    Logger.info("Started application")
    Supervisor.start_link(children, strategy: :one_for_one)
  end

  def db_create do
    RethinkDB.Query.db_create("telegrambot")
    |> Telegrambot.Database.run |> IO.inspect
  end
end
