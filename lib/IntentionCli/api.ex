defmodule IntentionCLI.API do
  use OK.Pipe
  import IntentionCLI.Utils

  def handle_response(res) do
    case res do
      {:ok, %{status_code: 401}} -> {:error, :unauthorized}
      {:ok, _} = r -> r ~>> parse_json_body()
      {:error, _} = err -> err
    end
  end

  def request_intentions(token) do
    HTTPoison.get(
      "https://intention-api.herokuapp.com/intentions",
      %{Authorization: "Bearer #{token}"}
    )
    |> handle_response()
  end

  def request_views(token) do
    HTTPoison.get(
      "https://intention-api.herokuapp.com/views",
      %{Authorization: "Bearer #{token}"}
    )
    |> handle_response()
  end
end
