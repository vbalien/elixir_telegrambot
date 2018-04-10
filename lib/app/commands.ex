defmodule Telegrambot.Commands do
  use Telegrambot.Router
  use Telegrambot.Api

  command ["help"], "도움말" do
    Enum.reduce(commands(), "", fn(x, acc) -> 
      acc <> "/" <> x.command <> " - " <> x.description <> "\n"
    end)
    |> send_message
  end
end
