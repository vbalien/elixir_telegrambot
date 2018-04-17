defmodule Anissia do
  use Tesla

  plug Tesla.Middleware.BaseUrl, "http://www.anissia.net/anitime"
  plug Tesla.Middleware.FormUrlencoded

  def list(week) do
    {:ok, res} = post("/list", %{w: Integer.to_string(week)})
    res.body |> Jason.decode
  end

  def cap(sub_id) do
    {:ok, res} = post("/cap", %{i: sub_id})
    res.body |> Jason.decode
  end

end

defmodule BlogParser do
  use Tesla
  plug Tesla.Middleware.FormUrlencoded
  plug Tesla.Middleware.Headers, [{"User-Agent", "curl/7.59.0"}]

  def get_attatch(blog) do
    get_attatch_url(blog) |> get_attatch_data
  end

  defp get_attatch_data(blog) do
    {:ok, res} = get(blog)

    unless res.status == 302 do
      %{
        name: res.headers |> get_name(blog),
        data: res.body
      }
      else
      {_, location} = res.headers |> List.keyfind("location", 0)
      get_attatch_data(location)
    end
  end

  defp get_name(headers, url) do
    filename = case headers |> List.keyfind("content-disposition", 0) do
      {_, filename} -> filename
      nil -> Path.basename(URI.parse(url).path)
    end
    Regex.named_captures(~r/filename="(?<filename>[^"]*)/, filename)["filename"]
  end

  defp get_attatch_url(blog) do
    {:ok, res} = get(blog) 
    unless res.status == 302 do
      get_attatch_url(res.body |> get_type, res.body) |> HtmlEntities.decode
    else
      {_, location} = res.headers |> List.keyfind("location", 0)
      get_attatch_url(location)
    end
  end

  defp get_attatch_url(nil, _), do: nil
  defp get_attatch_url(:tistory, body) do
    Regex.named_captures(~r/<span class="imageblock" style="display:inline-block;;height:auto;max-width:100%"><a href="(?<url>[^"]*)/, body)["url"]
  end
  defp get_attatch_url(:naver_main_frame, body) do
    result = Regex.named_captures(~r/<frame id="mainFrame" name="mainFrame" src="(?<url>[^"]*)/, body)
    get_attatch_url("https://blog.naver.com" <> result["url"])
  end
  defp get_attatch_url(:naver_screen_frame, body) do
    result = Regex.named_captures(~r/<frame id="screenFrame" name="screenFrame" src='(?<url>[^']*)/, body)
    get_attatch_url(result["url"])
  end
  defp get_attatch_url(:naver, body) do
    Regex.named_captures(~r/','encodedAttachFileUrl': '(?<url>[^']*)/, body)["url"]
  end
  defp get_attatch_url(:blogspot, body) do
    Regex.named_captures(~r/<a class="tx-link" href="(?<url>[^"]*)/, body)["url"]
  end

  defp get_type(body) do
    cond do
      String.match?(body, ~r/<span class="imageblock" style="display:inline-block;;height:auto;max-width:100%"><a href="/) ->
        :tistory
      String.match?(body, ~r/<frame id="mainFrame" name="mainFrame" src="/) ->
        :naver_main_frame
      String.match?(body, ~r/<frame id="screenFrame" name="screenFrame" src='/) ->
        :naver_screen_frame
      String.match?(body, ~r/','encodedAttachFileUrl': '/) ->
        :naver
      String.match?(body, ~r/<a class="tx-link" href="/) ->
        :blogspot
      true ->
        nil
    end
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
    {msg, keyboard, type} =
      case parse(msg_arg) do
        {:table, cur_week} -> do_table(cur_week)
        {:subtitle, cur_week} -> do_subtitle(cur_week, request_data)
        {:subdown, sub_id, ani_name} -> do_subdown(sub_id, ani_name)
      end

    case type do
      :auto -> send_data(msg, keyboard)
      :send -> send_message(msg, keyboard)
      :edit -> edit_message_text(msg, keyboard)
      :file -> send_document(msg.file, msg.caption, keyboard)
    end
    
  end 

  def do_table(cur_week) do
    now_week = Timex.local() 
               |> DateTime.to_date() 
               |> Date.day_of_week()
               |> rem(7)
    cur_week = cur_week |> to_weekcode(now_week)
    cur_week = if cur_week == nil, do: now_week, else: cur_week
    {:ok, anitable} = Anissia.list(cur_week)

    begin_char = """
    *#{cur_week |> to_weekstring}요일 애니 편성표*
    ━━━━━━━━━━━━━━━
    """

    {
      Enum.reduce(anitable, begin_char, fn(x, acc) ->
        acc <> time_format(x["t"]) <> " │ " <> subject_format(x["s"]) <> "\n"
      end),

      gen_keyboard(cur_week),
      :auto
    }
  end

  def do_subtitle(cur_week, request_data) do
    %{
      "id" => user_id,
      "first_name" => first_name,
      "last_name" => last_name
    } = request_data["callback_query"]["from"]

    {:ok, anitable} = Anissia.list(cur_week |> to_weekcode)

    {
      "[#{first_name} #{last_name}](tg://user?id=#{user_id})님, #{cur_week}요일의 자막을 받을 작품을 선택해주세요.",
      gen_keyboard(:ani_list, anitable),
      :send
    }
  end

  def do_subdown(sub_id, ani_name) do
    {:ok, sub_list} = Anissia.cap(sub_id)
    case sub_list do
      [] -> {"자막이 없습니다.", %{}, :send}
      [sub | _] ->
        {
          %{
            file: sub["a"] |> BlogParser.get_attatch,
            caption: """
            *#{ani_name}*
            #{sub["s"] |> parse_ep}화 자막
            제작자: #{sub["n"]}
            """
          },
          %{
            remove_keyboard: true
          },
          :file
        }
    end
  end

  def parse(nil), do: {:table, nil}
  def parse(msg_arg) do
    msg_arg = String.trim(msg_arg)

    if Enum.member?(@weekdata ++ ["어제", "내일", "오늘"], msg_arg) do
      {:table, msg_arg}
    else
      case msg_arg do
        "subtitle " <> cur_week ->
          {:subtitle, cur_week}
        "subdown " <> arg ->
          arg_split = String.split(arg, "\n")
          sub_id = arg_split |> Enum.at(0)
          ani_name = arg_split |> Enum.at(1)
          {:subdown, sub_id, ani_name}
      end
    end
  end

  defp parse_ep(epcode) do
    ep_major = epcode |> String.slice(0..3)
    {ep_major, _} = Integer.parse(ep_major)
    ep_minor = epcode |> String.slice(4..-1)
    if ep_minor == "0" do
      ep_major
    else
      "#{ep_major}.#{ep_minor}"
    end
  end

  def to_weekstring(weekcode), do: @weekdata |> Enum.at(weekcode)

  def to_weekcode(nil, _), do: nil
  def to_weekcode("어제", now_week), do: (now_week - 1) |> rem(7)
  def to_weekcode("내일", now_week), do: (now_week + 1) |> rem(7)
  def to_weekcode("오늘", now_week), do: now_week 
  def to_weekcode(weekstring, _), do: to_weekcode(weekstring)
  def to_weekcode(weekstring) do
    @weekdata
    |> Enum.find_index(fn(x) ->
      x == weekstring || x <> "요일" == weekstring
    end)
  end

  def gen_keyboard(:ani_list, anitable) do
    %{
      one_time_keyboard: true,
      selective: true,
      keyboard: Enum.map(anitable, fn(x) ->
        [%{text: "/anitable subdown #{x["i"]}\n#{x["s"]}"}]
      end) ++ [
        [%{text: "취소"}]
      ]
    }
  end
  def gen_keyboard(cur_week) do
    cur_week = cur_week |> to_weekstring
    %{
      inline_keyboard: [
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
        end),
        [
          %{
            text: "자막받기",
            callback_data: "/anitable subtitle " <> cur_week
          }
        ]
      ]
    }
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
