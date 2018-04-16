defmodule Telegrambot.MixProject do
  use Mix.Project

  def project do
    [
      app: :telegrambot,
      version: "0.1.0",
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Telegrambot, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:cowboy, "~> 1.1.2"},
      {:plug, "~> 1.3.4"},
      {:jason, "~> 1.0"},
      {:tesla, "1.0.0-beta.1"},
      {:timex, "~> 3.1"},
      {:rethinkdb, "~> 0.4.0"}
    ]
  end
end
