defmodule Telegrambot.Commands do
  use Telegrambot.Router
  use Telegrambot.Api

  command ["help"], "도움말" do
    Enum.reduce(commands(), "", fn(x, acc) -> 
      "/" <> x.command <> " - " <> x.description <> "\n" <> acc
    end)
    |> send_message
  end

  command ["anitable"], "애니편성표, 자막받기", Telegrambot.Anitable
  command ["weather"], "날씨정보", Telegrambot.Weather
  command ["memo"], "메모", Telegrambot.Memo
end
