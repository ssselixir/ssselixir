defmodule Mix.Tasks.Ssselixir.Stop do
  use Mix.Task

  def run(_) do
    Mix.shell.cmd("killall -9 beam.smp")
  end
end
