defmodule Anissia do
  use Tesla

  plug Tesla.Middleware.BaseUrl, "http://www.anissia.net/anitime"
  plug Tesla.Middleware.FormUrlencoded

  def list(week) do
    {:ok, res} = post("/list", %{w: Integer.to_string(week)})
    res.body |> Jason.decode
  end

end

defmodule Telegrambot.Anitable do
  @weekdata [
    "일",
    "월",
    "화",
    "수",
    "목",
    "금",
    "토"
  ]
  use Telegrambot.Api

  def command(request_data, msg_arg \\ nil) do
    now_week = Timex.local() 
           |> DateTime.to_date() 
           |> Date.day_of_week()
           |> rem(7)
    cur_week = msg_arg |> to_weekcode(now_week)
    cur_week = if cur_week == nil, do: now_week, else: cur_week
    {:ok, anitable} = Anissia.list(cur_week)

    begin_char = """
    #{@weekdata |> Enum.at(cur_week)}요일 애니 편성표
    ━━━━━━━━━━━━━━━
    """
    Enum.reduce(anitable, begin_char, fn(x, acc) ->
      acc <> time_format(x["t"]) <> " │ " <> subject_format(x["s"]) <> "\n"
    end)
    |> send_data(%{
      inline_keyboard: gen_keyboard(cur_week)
    })
  end 

  def to_weekcode(nil, _), do: nil
  def to_weekcode(weekstring, now_week) do
    weekstring = String.trim(weekstring)
    case weekstring do
      "어제" -> (now_week - 1) |> rem(7)
      "내일" -> (now_week + 1) |> rem(7)
      "오늘" -> now_week
      _ ->
        @weekdata
        |> Enum.find_index(fn(x) ->
          x == weekstring || x <> "요일" == weekstring
        end)
    end
  end

  def gen_keyboard(cur_week) do
    cur_week = @weekdata |> Enum.at(cur_week)
    [
      Enum.map(@weekdata, fn(x) ->
        case x do
          ^cur_week ->
            %{
              text: "*" <> x,
              callback_data: "/anitable " <> x
            }
          _ ->
            %{
              text: x,
              callback_data: "/anitable " <> x
            }
        end
      end)
    ]
  end

  def subject_format(subject) do
    if String.length(subject) > 15 do
      (subject |> String.slice(0..15) |> String.trim()) <> "..."
    else 
      subject
    end
  end

  def time_format(time) do
    String.slice(time, 0..1) <> ":" <> String.slice(time, 2..3)
  end
end
