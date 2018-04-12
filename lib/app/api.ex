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

  defmacro send_message(message, reply \\ %{} |> Macro.escape) do
    quote bind_quoted: [message: message, reply: reply] do
      post("/sendMessage", %{
        chat_id: get_chat_id(),
        text: message,
        reply_markup: reply
      })
    end
  end

  defmacro edit_message_text(message, reply \\ %{} |> Macro.escape) do
    quote bind_quoted: [message: message, reply: reply] do
      {chat_id, message_id} = get_chat_id()
      post("/editMessageText", %{
        chat_id: chat_id,
        message_id: message_id,
        text: message,
        reply_markup: reply
      })
    end
  end

  defmacro delete_message(chat_id, message_id) do
    quote do
      post("/deleteMessage", %{
        chat_id: unquote(chat_id),
        message_id: unquote(message_id)
      })
    end
  end

  defmacro send_data(message, reply \\ %{}) do
    quote bind_quoted: [message: message, reply: reply] do
      if is_callback?() do
        edit_message_text(message, reply)
      else
        send_message(message, reply)
      end
    end
  end


  defmacro get_chat_id do
    quote do
      case var!(request_data) do
        %{"inline_query" => inline_query} when not is_nil(inline_query) ->
          inline_query["from"]["id"]
        %{"callback_query" => callback_query} when not is_nil(callback_query) ->
          {
            callback_query["message"]["chat"]["id"],
            callback_query["message"]["message_id"]
          }
        %{"message" => %{"chat" => %{"id" => id}}} when not is_nil(id) -> 
          id
        %{"edited_message" => %{"chat" => %{"id" => id}}} when not is_nil(id) -> 
          id
        a -> raise "No chat id found!" <> inspect(a)
      end
    end
  end

  defmacro is_callback? do
    quote do
      case var!(request_data) do
        %{"callback_query" => _} ->
          true
        _ -> false
      end
    end
  end
end
