defmodule Mix.Tasks.Ssselixir.Start do
  use Mix.Task

  def run(_) do
    Mix.shell.cmd("elixir --detached -S mix run --no-halt")
  end
end
