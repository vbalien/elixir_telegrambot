defmodule Telegrambot.Memo do
  use Telegrambot.Api
  require RethinkDB.Lambda
  alias RethinkDB.Query, as: Query
  import RethinkDB.Lambda

  defmacro save_memo(name, value, user) do
    quote bind_quoted: [name: name, value: value, user: user] do
      is_exists = Query.table("memo")
                  |> Query.filter(%{name: name, user: user})
                  |> Query.count
                  |> Query.eq(1)
                  |> Telegrambot.Database.run
                  |> get_data

      if is_exists do
        Query.table("memo")
        |> Query.filter(%{user: user, name: name})
        |> Query.update(%{value: value})
        |> Telegrambot.Database.run
      else
        Query.table("memo")
        |> Query.insert(%{name: name, value: value, user: user})
        |> Telegrambot.Database.run
      end
    end
  end

  defmacro get_memo(name, user) do
    quote bind_quoted: [name: name, user: user] do
      Query.table("memo")
      |> Query.filter(%{user: user, name: name})
      |> Query.nth(0)
      |> Query.get_field("value")
      |> Query.default("빈 메모")
      |> Telegrambot.Database.run
      |> get_data
    end
  end

  defmacro list_memo(user) do
    quote do
      Query.table("memo")
      |> Query.filter(%{user: unquote(user)})
      |> Query.map(lambda fn(memo) -> "* " <> memo["name"] <> "\n" end)
      |> Telegrambot.Database.run
      |> get_data
    end
  end

  defmacro del_memo(name, user) do
    quote bind_quoted: [name: name, user: user] do
      Query.table("memo")
      |> Query.filter(%{user: user, name: name})
      |> Query.delete
      |> Telegrambot.Database.run
      |> get_data
    end
  end

  def command(request_data, msg_arg \\ nil) do
    user = request_data["message"]["from"]["username"]
    case parse(msg_arg) do
      nil ->
        """
        메모 명령어
        메모는 각 유저별로 식별되어 저장됩니다.

        /memo list - 메모 목록
        /memo del - 메모 제거
        /memo [제목; 띄어쓰기x] [내용] - 메모 저장
        /memo [제목; 띄어쓰기x] - 메모 가져오기
        """ |> send_message

      :list ->
        """
        메모 리스트
        #{list_memo(user)}
        """ |> send_message

      {name, value} ->
        case name do
          "del" ->
            if del_memo(value, user)["deleted"] >= 1 do
              "제거하였습니다."
            else
              "오류"
            end |> send_message

          _ ->
            save_memo(name, value, user)
            "저장하였습니다." |> send_message
        end

      name ->
        get_memo(name, user) |> send_message
    end
  end

  defp parse(nil), do: nil
  defp parse(arg)
  when is_binary(arg) do
    arg = String.trim(arg)
    case arg do
      "list" -> :list
      _ ->
        arg_codes = String.codepoints(arg)
        case Enum.find_index(arg_codes, fn(x) -> x == " " end) do
          nil -> arg
          pos ->
            {
              String.slice(arg, 0..(pos - 1)), 
              String.slice(arg, (pos + 1)..-1)
            }
        end
    end
  end

  def table_drop do
    Query.table_drop("memo")
    |> Telegrambot.Database.run
    |> IO.inspect
  end

  def table_create do
    Query.table_create("memo")
    |> Telegrambot.Database.run
    |> IO.inspect
  end

  def get_data(res), do: res.data
end

