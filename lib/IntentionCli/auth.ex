defmodule IntentionCLI.Auth do
  use OK.Pipe
  import IntentionCLI.Utils

  @client_id "iObILO32qS2c7CxAn7dcUp4eZtDm9jjj"

  def request_device_code() do
    body =
      form_encoded_body([
        {"client_id", @client_id},
        {"audience", "https://intention-api.herokuapp.com"}
      ])

    HTTPotion.post(
      "https://dwmartin41.eu.auth0.com/oauth/device/code",
      body: body,
      headers: ["Content-type": "application/x-www-form-urlencoded"],
      ibrowse: [ssl_options: [{:verify, :verify_none}]]
    )
    |> parse_json_body()
  end

  def request_token(device_code) do
    body =
      [
        {"grant_type", "urn:ietf:params:oauth:grant-type:device_code"},
        {"device_code", device_code},
        {"client_id", @client_id}
      ]
      |> form_encoded_body()

    HTTPotion.post(
      "https://dwmartin41.eu.auth0.com/oauth/token",
      body: body,
      headers: ["Content-type": "application/x-www-form-urlencoded"],
      ibrowse: [ssl_options: [{:verify, :verify_none}]]
    )
    |> parse_json_body()
  end

  def poll_token(device_code) do
    case request_token(device_code) do
      {:ok, %{access_token: token}} -> return(token)
      {:ok, _} -> poll_token(device_code)
      {:error, _} = err -> err
    end
  end
end
