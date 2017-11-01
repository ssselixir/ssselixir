defmodule Mix.Tasks.Ssselixir.Newuser do
  use Mix.Task

  def run(args) do
    {[port: port, password: password], _, _} =
      OptionParser.parse(args, switches: [port: :integer, password: :string])
    Application.ensure_all_started(:ecto)
    Ssselixir.start(:db)
    IO.puts "Creating configuration for port #{port}...."
    Ssselixir.PortPassword.create(%{port: port, password: password})
    IO.puts "Done"
  end
end
