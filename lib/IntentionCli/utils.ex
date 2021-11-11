defmodule IntentionCLI.Utils do
  use OK.Pipe

  def form_encoded_body(params) do
    params
    |> Enum.map(fn {key, value} -> key <> "=" <> value end)
    |> Enum.join("&")
  end

  def parse_json_body(response) do
    response
    |> Map.fetch(:body)
    ~>> Jason.decode(%{keys: :atoms})
  end

  def return(x) do
    {:ok, x}
  end

  def with_default(x, default) do
    case x do
      {:ok, ok} -> ok
      {:error, _} -> default
    end
  end

  def print_ansi(to_print) do
    to_print |> IO.ANSI.format() |> IO.puts()
  end
end
