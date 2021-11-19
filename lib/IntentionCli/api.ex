defmodule IntentionCLI.API do
  use OK.Pipe
  import IntentionCLI.Utils

  def handle_response(res) do
    case res do
      {:ok, %{status_code: 401}} -> {:error, :unauthorized}
      {:ok, %{status_code: 200}} = r  -> r ~>> parse_json_body()
      {:ok, res} -> OK.for do
          body <- res |> parse_json_body()
          reason <- case Map.fetch(body, :reason) do
                      {:ok, _} = ok -> ok
                      :error ->
                        IO.inspect(res)
                        {:error, :unknown_error}
                    end
        after
          {:error, reason}
        end
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

  def create_intention(token, intention) do
    OK.for do
      json <- Jason.encode(intention)
    after
      HTTPoison.post(
        "https://intention-api.herokuapp.com/intentions",
        json,
        %{Authorization: "Bearer #{token}",
          "Content-Type": "application/json"}
      )
      |> handle_response()
    end
  end

  def update_intention(token, id, updated_intention) do
    OK.for do
      json <- Jason.encode(updated_intention)
    after
      HTTPoison.put(
        "https://intention-api.herokuapp.com/intentions/#{id}",
        json,
        %{Authorization: "Bearer #{token}",
          "Content-Type": "application/json"}
      )
      |> handle_response()
    end
  end

  def get_intention(token, id) do
    HTTPoison.get(
      "https://intention-api.herokuapp.com/intentions/#{id}",
      %{Authorization: "Bearer #{token}",
        "Content-Type": "application/json"}
    )
    |> handle_response()
  end
end
