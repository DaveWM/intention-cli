defmodule IntentionCli.MixProject do
  use Mix.Project

  def project do
    [
      app: :intention_cli,
      version: "0.1.0",
      elixir: "~> 1.11",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      escript: [main_module: IntentionCLI, name: "intention"],
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      ansi_enabled: true
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:optimus, "~> 0.2"},
      {:cli_spinners, "~> 0.1.0"},
      {:castore, "~> 0.1.0"},
      {:jason, "~> 1.2"},
      {:httpotion, "~> 3.1.3"},
      {:ok, "~> 2.3"}
    ]
  end
end
