defmodule Telegrambot.Api do
  @token Application.get_env(:telegrambot, :token)

  defmacro __using__(_opts) do
    quote do
      require Logger
      import Telegrambot.Api

      use Tesla

      plug Tesla.Middleware.BaseUrl, "https://api.telegram.org/bot#{unquote(@token)}"
      plug Tesla.Middleware.JSON
    end
  end

  defmacro send_message(message) do
    quote bind_quoted: [message: message] do
      post("/sendMessage", %{
        chat_id: get_chat_id(),
        text: message
      })
    end
  end


  defmacro get_chat_id do
    quote do
      case var!(message) do
        %{"inline_query" => inline_query} when not is_nil(inline_query) ->
          inline_query.from.id
        %{"callback_query" => callback_query} when not is_nil(callback_query) ->
          callback_query.message.chat.id
        %{"message" => %{"chat" => %{"id" => id}}} when not is_nil(id) -> 
          id
        %{"edited_message" => %{"chat" => %{"id" => id}}} when not is_nil(id) -> 
          id
        a -> raise "No chat id found!" <> inspect(a)
      end
    end
  end
end
