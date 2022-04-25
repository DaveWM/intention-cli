defmodule IntentionCLI do
  require OK
  use OK.Pipe
  import IntentionCLI.Utils
  alias IntentionCLI.Auth, as: Auth
  alias IntentionCLI.API, as: API

  @moduledoc """
  Documentation for `IntentionCLI`.
  """

  @doc """
  Hello world.

  ## Examples

  iex> IntentionCli.hello()
  :world

  """
  def main(argv) do
    Application.put_env(:elixir, :ansi_enabled, true)

    optimus =
      Optimus.new!(
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
            ],
            args: [
              view: [
                value_name: "view",
                help: "View to display",
                parser: fn s ->
                  case Integer.parse(s) do
                    {:error, _} -> {:error, "invalid view id - should be an integer"}
                    {i, _} -> {:ok, i}
                  end
                end,
                required: false
              ]
            ]
          ],
          show: [
            name: "show",
            about: "show a single intention",
            args: [
              id: [
                value_name: "id",
                help: "The ID of the intention to display",
                parser: fn s ->
                  case Integer.parse(s) do
                    {:error, _} -> {:error, "invalid intention id - should be an integer"}
                    {i, _} -> {:ok, i}
                  end
                end,
                required: true
              ]
            ]
          ],
          create: [
            name: "create",
            about: "create a new intention",
            options: [
              title: [
                value_name: "title",
                short: "-t",
                long: "--title",
                help: "The title of your intention",
                required: true
              ],
              description: [
                value_name: "description",
                short: "-d",
                long: "--desc",
                help: "The description of your intention",
                required: false
              ],
              parents: [
                value_name: "parents",
                short: "-p",
                long: "--parent",
                help: "The parent of your intention. Can specify multiple parents.",
                required: true,
                multiple: true,
                parser: fn s ->
                  case Integer.parse(s) do
                    {:error, _} -> {:error, "invalid parent id - should be an integer"}
                    {i, _} -> {:ok, i}
                  end
                end
              ]
            ]
          ],
          complete: [
            name: "complete",
            about: "set the intention status to completed",
            args: [
              id: [
                value_name: "id",
                help: "The ID of the intention to update",
                parser: fn s ->
                  case Integer.parse(s) do
                    {:error, _} -> {:error, "invalid intention id - should be an integer"}
                    {i, _} -> {:ok, i}
                  end
                end,
                required: true
              ]
            ]
          ],
          uncomplete: [
            name: "uncomplete",
            about: "set the intention status to todo",
            args: [
              id: [
                value_name: "id",
                help: "The ID of the intention to update",
                parser: fn s ->
                  case Integer.parse(s) do
                    {:error, _} -> {:error, "invalid intention id - should be an integer"}
                    {i, _} -> {:ok, i}
                  end
                end,
                required: true
              ]
            ]
          ],
          views: [
            name: "views",
            about: "List all views"
          ]
        ]
      )

    args = Optimus.parse!(optimus, argv)

    settings = load_settings()

    case args do
      %{args: %{}} ->
        Optimus.parse!(optimus, ["--help"])

      {[:login], args} ->
        settings |> with_default(%{}) |> auth(args)

      {[:list], args} ->
        settings ~>> token_required() ~>> list_intentions(args) |> handle_errors()

      {[:views], args} ->
        settings ~>> token_required() ~>> list_views(args) |> handle_errors()

      {[:create], args} ->
        settings ~>> token_required() ~>> create_intention(args) |> handle_errors()

      {[:show], args} ->
        settings ~>> token_required() ~>> show_intention(args) |> handle_errors()

      {[:complete], args} ->
        settings ~>> token_required() ~>> set_intention_status(args, "done") |> handle_errors()

      {[:uncomplete], args} ->
        settings ~>> token_required() ~>> set_intention_status(args, "todo") |> handle_errors()

      other ->
        IO.inspect(other)
    end
  end

  def handle_errors(result) do
    case result do
      {:error, :unauthorized} ->
        [
          :bright,
          :red,
          "ERROR: ",
          :reset,
          "auth token expired, please refresh using ",
          :bright,
          "intention login"
        ]
        |> IO.ANSI.format()
        |> IO.puts()

      {:error, err} ->
        [:bright, :red, "ERROR: ", :reset, "an error occurred - ", :bright, Kernel.inspect(err)]
        |> print_ansi()

      {:ok, _} ->
        nil
    end
  end

  def token_required(settings) do
    case settings do
      %{token: t} = ok when not is_nil(t) ->
        return(ok)

      _ ->
        print_ansi(["Run ", :bright, '"intention login"', :reset, " first."])
        {:error, :missing_token}
    end
  end

  def load_settings() do
    "~/.intention/config.json"
    |> Path.expand()
    |> File.read()
    ~>> Jason.decode(%{keys: :atoms})
  end

  def save_settings(new_settings) do
    path = "~/.intention/config.json" |> Path.expand()
    File.mkdir_p!(Path.dirname(path))

    OK.try do
      json <- Jason.encode(new_settings)
      write_result = File.write(path, json)
    after
      case write_result do
        :ok -> {:ok, nil}
        err -> err
      end
    rescue
      reason ->
        print_ansi([
          :bright,
          :red,
          "ERROR:",
          :reset,
          " Failed to save settings, reason: ",
          Kernel.inspect(reason)
        ])

        reason
    end
  end

  def auth(settings, _args) do
    OK.for do
      %{user_code: user_code, device_code: device_code, verification_uri_complete: uri} <-
        Auth.request_device_code()

      print_ansi(["Go to: ", :bright, uri])
      print_ansi(["User code is ", :blue, :bright, user_code])

      token <-
        CliSpinners.spin_fun(
          [frames: :dots, text: "Waiting for token...", done: "Got token"],
          fn -> Auth.poll_token(device_code) end
        )

      save_settings(Map.put(settings, :token, token))
    after
      IO.puts("Login complete")
    end
  end

  def list_intentions(%{token: token}, args) do
    OK.for do
      intentions_task = Task.async(fn -> API.request_intentions(token) end)

      view_root_id_task =
        Task.async(fn ->
          case args do
            %{args: %{view: view_id}} when not is_nil(view_id) ->
              view = API.request_views(token) ~> Enum.find(fn v -> v.id == view_id end)

              case view do
                {:ok, nil} ->
                  IO.puts(
                    IO.ANSI.format([
                      :yellow,
                      :bright,
                      "WARN: ",
                      :reset,
                      "View ",
                      :bright,
                      Kernel.inspect(view_id),
                      :reset,
                      " not found."
                    ])
                  )

                  nil

                {:ok, v} ->
                  v
                  |> Map.fetch!(:"root-node")
                  |> Map.fetch!(:id)

                _ ->
                  nil
              end

            _ ->
              nil
          end
        end)

      [intentions_result, view_root_id] = Task.await_many([intentions_task, view_root_id_task])
      intentions <- intentions_result

      to_show =
        case args.flags.all do
          true -> intentions
          false -> intentions |> Enum.filter(fn i -> i.status == "todo" end)
        end

      view = intentions_view(to_show, view_root_id)
    after
      print_ansi(view)
    end
  end

  def show_intention(%{token: token}, args) do
    OK.for do
      intention <- API.get_intention(token, args.args.id)
    after
      [
        [:faint, "Title:       ", :reset, :bright, intention.title],
        if Map.has_key?(intention, :description) do
          [:faint, "Description: ", :reset, intention.description]
        end,
        [
          :faint,
          "Status:      ",
          :reset,
          :bright,
          if intention.status == "todo" do
            [:cyan, "ToDo"]
          else
            [:green, "Done"]
          end
        ]
      ]
      |> Enum.filter(fn x -> not is_nil(x) end)
      |> Enum.intersperse(["\r\n", :reset])
      |> print_ansi()
    end
  end

  def create_intention(%{token: token}, %{options: %{title: t, description: d, parents: ps}}) do
    OK.for do
      intention =
        %{title: t, description: d, parents: ps}
        |> Enum.filter(fn {_k, v} -> not is_nil(v) end)
        |> Map.new()

      response <- API.create_intention(token, intention)
    after
      print_ansi(["Success! Created intention with id ", :bright, Kernel.inspect(response.id)])
    end
  end

  def set_intention_status(%{token: token}, %{args: %{id: id}}, status) do
    OK.for do
      intention <- API.get_intention(token, id)

      updated_intention =
        %{intention | status: status}
        |> Map.update(:parents, [], fn ps -> Enum.map(ps, fn p -> p.id end) end)

      _response <- API.update_intention(token, id, updated_intention)
    after
      IO.puts("Success!")
    end
  end

  def list_views(settings, _args) do
    API.request_views(settings.token)
    ~> Enum.map(fn v ->
      [:faint, "- ", :reset, :bright, v.title, :reset, " | ", :faint, Kernel.inspect(v.id), "\n"]
    end)
    ~> print_ansi()
  end

  def intentions_view(intentions, root_node_id \\ nil, parent \\ nil, indentation \\ 1) do
    level_colours =
      Stream.cycle([
        :yellow,
        :light_blue,
        :red,
        :light_green,
        :magenta
      ])

    intentions
    |> Enum.filter(fn i ->
      parents = i[:parents]

      cond do
        is_nil(root_node_id) && is_nil(parents) && is_nil(parent) -> true
        not is_nil(root_node_id) && is_nil(parent) && i.id == root_node_id -> true
        Enum.any?(parents || [], fn p -> p.id == parent end) -> true
        true -> false
      end
    end)
    |> Enum.map(fn i ->
      indent = String.duplicate(" ", indentation)

      children =
        intentions_view(intentions, root_node_id, i.id, indentation + 1)
        |> Enum.map(fn s ->
          [indent, Enum.fetch!(level_colours, indentation), :bright, "| ", s]
        end)

      label = [
        :reset,
        if(i.status == "todo", do: :bright, else: :crossed_out),
        i.title,
        :reset,
        :faint,
        " (id ",
        to_string(i.id),
        ")"
      ]

      [label, children]
      |> Enum.filter(fn s -> not is_nil(s) end)
      |> Enum.intersperse(["\n"])
    end)
  end
end
