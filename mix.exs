defmodule PlayDynamo.MixProject do
  use Mix.Project

  def project do
    [
      app: :play_dynamo,
      version: "0.1.0",
      elixir: "~> 1.11",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      config: "config/config.exs"
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {PlayDynamo.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_aws_dynamo, "~> 4.0"},
      {:jason, "~> 1.0"},
      {:hackney, "~> 1.9"},
      {:httpoison, "~> 1.7"},
      {:plug_cowboy, "~> 2.0"}
    ]
  end
end
