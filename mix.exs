require Logger
defmodule Ssselixir.Mixfile do
  use Mix.Project

  def project do
    [
      app: :ssselixir,
      version: "0.1.0",
      elixir: "~> 1.5",
      start_permanent: Mix.env == :prod,
      deps: deps(),
      pp_store: :file
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Ssselixir, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:logger_file_backend, "~> 0.0.10"},
      {:yamerl, "~> 0.4.0"},
      {:mariaex, "~> 0.8.2"},
      {:ecto, "~> 2.1"}
    ]
  end
end
