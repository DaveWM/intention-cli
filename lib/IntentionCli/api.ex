defmodule IntentionCLI.API do
  use OK.Pipe
  import IntentionCLI.Utils

  def handle_response(res) do
    case res do
      %{status_code: 401} ->
        {:error, :unauthorized}

      %{status_code: 200} = r ->
        parse_json_body(r)

      res ->
        OK.for do
          body <- res |> parse_json_body()

          reason <-
            case Map.fetch(body, :reason) do
              {:ok, _} = ok ->
                ok

              :error ->
                IO.inspect(res)
                {:error, :unknown_error}
            end
        after
          {:error, reason}
        end
    end
  end

  def headers(token) do
    [Authorization: "Bearer #{token}", "Content-Type": "application/json"]
  end

  def request_intentions(token) do
    HTTPotion.get(
      "https://intention-api.herokuapp.com/intentions",
      headers: headers(token),
      ibrowse: [ssl_options: [{:verify, :verify_none}]]
    )
    |> handle_response()
  end

  def request_views(token) do
    HTTPotion.get(
      "https://intention-api.herokuapp.com/views",
      headers: headers(token),
      ibrowse: [ssl_options: [{:verify, :verify_none}]]
    )
    |> handle_response()
  end

  def create_intention(token, intention) do
    OK.for do
      json <- Jason.encode(intention)
    after
      HTTPotion.post(
        "https://intention-api.herokuapp.com/intentions",
        body: json,
        headers: headers(token),
        ibrowse: [ssl_options: [{:verify, :verify_none}]]
      )
      |> handle_response()
    end
  end

  def update_intention(token, id, updated_intention) do
    OK.for do
      json <- Jason.encode(updated_intention)
    after
      HTTPotion.put(
        "https://intention-api.herokuapp.com/intentions/#{id}",
        body: json,
        headers: headers(token),
        ibrowse: [ssl_options: [{:verify, :verify_none}]]
      )
      |> handle_response()
    end
  end

  def get_intention(token, id) do
    HTTPotion.get(
      "https://intention-api.herokuapp.com/intentions/#{id}",
      headers: headers(token),
      ibrowse: [ssl_options: [{:verify, :verify_none}]]
    )
    |> handle_response()
  end
end
