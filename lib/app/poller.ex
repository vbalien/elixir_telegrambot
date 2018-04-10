defmodule Telegrambot.Poller do
  require Logger
  use Plug.Router

  plug Plug.Parsers, parsers: [:json],
    pass:  ["text/*"],
    json_decoder: Jason

  plug :match
  plug :dispatch

  post "/" do
    conn.body_params
    |> process_message

    send_resp(conn, 200, "ok:")
  end

  match(_, do: send_resp(conn, 404, "Not Found"))

  defp process_message(message) do
    Telegrambot.Matcher.match(message)
  end

end
