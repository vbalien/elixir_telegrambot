defmodule Telegrambot.Router do
  @botname Application.get_env(:telegrambot, :botname)
  
  defmacro __using__(_opts) do
    quote do
      require Logger
      import Telegrambot.Router

      Module.register_attribute(__MODULE__, :commands, accumulate: true)
      @before_compile Telegrambot.Router

      def match_message(message) do
        try do
          apply __MODULE__, :do_match_message, [message]
        rescue
          err in FunctionClauseError ->
            Logger.log :warn, """
            매칭오류: #{ message |> inspect}
            """
        end
      end

    end
  end

  defmacro __before_compile__(_) do
    quote do
      def commands, do: @commands
    end
  end

  defp gen_command(command, description, handler) do
    quote do
      Module.put_attribute __MODULE__, :commands, %{
        command: unquote(command),
        description: unquote(description)
      }

      def do_match_message(%{
        "message" => %{
          "text" => "/" <> unquote(command)
        }
      } = var!(request_data)) do
        handle_message(unquote(handler), var!(request_data))
      end
      def do_match_message(%{
        "message" => %{
          "text" => "/" <> unquote(command) <> " " <> var!(msg_arg)
        }
      } = var!(request_data)) do
        handle_message(unquote(handler), var!(request_data), var!(msg_arg))
      end
      def do_match_message(%{
        "message" => %{
          "reply_to_message" => %{"text" => "/" <> unquote(command) <> _},
          "location" => var!(msg_arg)
        }
      } = var!(request_data)) do
        handle_message(unquote(handler), var!(request_data), var!(msg_arg))
      end

      def do_match_message(%{
        "message" => %{
          "text" => "/" <> unquote(command) <> "@" <> unquote(@botname)
        }
      } = var!(request_data)) do
        handle_message(unquote(handler), var!(request_data))
      end
      def do_match_message(%{
        "message" => %{
          "text" => "/" <> unquote(command) <> "@" <> unquote(@botname) <> " " <> var!(msg_arg)
        }
      } = var!(request_data)) do
        handle_message(unquote(handler), var!(request_data), var!(msg_arg))
      end

      def do_match_message(%{
        "callback_query" => %{
          "data" => "/" <> unquote(command)
        }
      } = var!(request_data)) do
        handle_message(unquote(handler), var!(request_data))
      end
      def do_match_message(%{
        "callback_query" => %{
          "data" => "/" <> unquote(command) <> " " <> var!(msg_arg)
        }
      } = var!(request_data)) do
        handle_message(unquote(handler), var!(request_data), var!(msg_arg))
      end
    end
  end

  defmacro command(commands, description, do: handler)
  when is_list(commands) do
    Enum.map commands, fn command ->
      gen_command(command, description, handler)
    end
  end

  defmacro command(command, description, do: handler) do
    gen_command(command, description, handler)
  end

  defmacro command(commands, description, module)
  when is_list(commands) do
    Enum.map commands, fn command ->
      gen_command(command, description, module)
    end
  end

  defmacro command(command, description, module) do
    gen_command(command, description, module)
  end

  def handle_message(module, message)
  when is_atom(module) do
    Task.start fn ->
      apply module, :command, [message]
    end
  end
  def handle_message(_, _), do: nil

  def handle_message(module, message, arg)
  when is_atom(module) do
    Task.start fn ->
      apply module, :command, [message, arg]
    end
  end

end
