defmodule Telegrambot.Matcher do
  use GenServer

  def start_link do
    GenServer.start_link __MODULE__, :ok, name: __MODULE__
  end

  def handle_cast(message, state) do
    Telegrambot.Commands.match_message message
    {:noreply, state}
  end

  def init(state), do: {:ok, state}
  def match(message), do: GenServer.cast __MODULE__, message

end
