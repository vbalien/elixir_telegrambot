defmodule WeatherApi do
  @apikey Application.get_env(:telegrambot, :weather_key)
  use Tesla

  plug Tesla.Middleware.BaseUrl, "http://api.openweathermap.org/data/2.5"
  plug Tesla.Middleware.FormUrlencoded

  def info(%{"latitude" => lat, "longitude" => lon}) do
    {:ok, res} = get("/weather", query: %{
      appid: @apikey,
      lat: lat,
      lon: lon,
      units: "metric"
    })
    res.body |> Jason.decode!
  end
  
end

defmodule Telegrambot.Weather do
  use Telegrambot.Api
  use Timex

  def command(request_data, msg_arg \\ nil) do
    case msg_arg do
      nil ->
        send_message("""
        /weather
        이 메시지 답글로 위치를 보내주세요.
        """)
      _ ->
        WeatherApi.info(msg_arg) |> get_weather_info |> send_message
    end
  end

  def get_weather_info(data) do
    %{
      "main" => %{
        "temp" => temp,
        "temp_min" => temp_min,
        "temp_max" => temp_max
      },
      "weather" => [%{
        "description" => desc,
      }],
      "dt" => datetime,
      "name" => name
    } = data
    """
    날씨정보
    위치: #{name}
    기준시: #{
      datetime 
      |> DateTime.from_unix! 
      |> Timezone.convert("Asia/Seoul") 
      |> Timex.format!("{M}월 {D}일 {h24}시 {m}분")
    }
    온도: #{temp}
    최저온도: #{temp_min}
    최고온도: #{temp_max}
    설명: #{desc}
    """
  end
end
