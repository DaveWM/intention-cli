defmodule IntentionCli do

  @moduledoc """
  Documentation for `IntentionCli`.
  """

  @doc """
  Hello world.

  ## Examples

  iex> IntentionCli.hello()
  :world

  """
  def main(argv) do
    Application.put_env(:elixir, :ansi_enabled, true)

    optimus = Optimus.new!(
      name: "intention",
      description: "CLI for Intention",
      version: "0.1.0",
      author: "Dave Martin mail@davemartin.me",
      allow_unknown_args: false,
      parse_double_dash: true,
      subcommands: [
        login: [
          name: "login",
          about: "Log in to Intention. Required to run other commands."
        ],
        list: [
          name: "list",
          about: "List your intentions in a tree format.",
          flags: [
            all: [
              short: "-a",
              long: "--all",
              help: "Show all intentions, including completed."
            ]
          ]
        ]
      ]
    )

    args = Optimus.parse!(optimus, argv)

    settings = load_settings()

    case args do
        %{args: %{}} -> Optimus.parse!(optimus, ["--help"])
      {[:login], _} -> auth(settings)
      {[:list], _} -> list_intentions(settings)
      other -> IO.inspect(other)
    end
  end

  def load_settings() do
    case "~/.intention/config.json" |> Path.expand() |> File.read() do
      {:error, _} -> %{}
      {:ok, content} -> Jason.decode!(content, %{keys: :atoms})
    end
  end

  def save_settings(new_settings) do
    path = "~/.intention/config.json" |> Path.expand()
    File.mkdir_p!(Path.dirname(path))
    case File.write(path, Jason.encode!(new_settings)) do
      {:error, reason} ->
        IO.puts(IO.ANSI.format([:bright, :red, "ERROR:", :reset, " Failed to save settings, reason: ", Kernel.inspect(reason)]))
        :error
      :ok -> :ok
    end
  end

  def auth(settings) do
    %{user_code: user_code, device_code: device_code, verification_uri_complete: uri} = request_device_code()
    IO.puts(IO.ANSI.format(["Go to: ", :bright, uri]))
    IO.puts(IO.ANSI.format(["User code is ", :orange, :bright, user_code]))

    token = CliSpinners.spin_fun(
      [frames: :dots,
       text: "Waiting for token...",
       done: "Got token"],
      fn -> poll_token(device_code) end
    )

    save_settings(Map.put(settings, :token, token))
    IO.puts("Login complete")
  end

  def list_intentions(settings) do
    case settings do
      %{token: token} -> 
        intentions = request_intentions(token)
        view = intentions_view(intentions |> Enum.filter(fn i -> i.status == "todo" end))

        view
        |> IO.ANSI.format()
        |> IO.puts()
      _ -> IO.puts(IO.ANSI.format(["Run ", :bright, '"intention login"', :reset, " first."]))
    end
  end

  def form_encoded_body(params) do
    params
    |> Enum.map(fn {key, value} -> key <> "=" <> value end)
    |> Enum.join("&")
  end

  def parse_json_body(response) do
    response
    |> Map.fetch!(:body)
    |> Jason.decode!(%{keys: :atoms})
  end

  def request_device_code() do
    body = form_encoded_body(
      [{"client_id", "iObILO32qS2c7CxAn7dcUp4eZtDm9jjj"},
       {"audience", "https://intention-api.herokuapp.com"}])
    HTTPoison.post!(
      "https://dwmartin41.eu.auth0.com/oauth/device/code",
      body,
      %{"Content-type": "application/x-www-form-urlencoded"}
    )
    |> parse_json_body()
  end

  def request_token(device_code) do
    body = [{"grant_type", "urn:ietf:params:oauth:grant-type:device_code"},
            {"device_code", device_code},
            {"client_id", "iObILO32qS2c7CxAn7dcUp4eZtDm9jjj"}]
            |> form_encoded_body()
    HTTPoison.post!(
      "https://dwmartin41.eu.auth0.com/oauth/token",
      body,
      %{"Content-type": "application/x-www-form-urlencoded"}
    )
    |> parse_json_body()
  end

  def poll_token(device_code) do
    case request_token(device_code) do
      %{access_token: token} -> token
      _ -> poll_token(device_code)
    end
  end

  def request_intentions(token) do
    HTTPoison.get!(
      "https://intention-api.herokuapp.com/intentions",
      %{Authorization: "Bearer #{token}"}
    )
    |> parse_json_body()
  end

  def intentions_view(intentions, parent \\ nil, indentation \\ 1) do
    level_colours = Stream.cycle([
      :blue, :cyan, :green, :red, :yellow
    ])

    intentions
    |> Enum.filter(fn i ->
      parents = i[:parents]
       cond do
        is_nil(parents) && is_nil(parent) -> true
        Enum.any?(parents || [], fn p -> p.id == parent end) -> true
        true -> false
      end
    end)
    |> Enum.map(fn i ->
      indent = String.duplicate(" ", indentation)
      children = intentions_view(intentions, i.id, indentation + 1)
      |> Enum.map(fn s -> [indent, Enum.fetch!(level_colours, indentation), "| ", s] end)
      label = [:reset, :bright, i.title, :faint, " (id ", to_string(i.id), ")"]
      [ label, children ]
      |> Enum.filter(fn s -> not(is_nil(s)) end)
      |> Enum.intersperse(["\n"])
    end)
  end
end
