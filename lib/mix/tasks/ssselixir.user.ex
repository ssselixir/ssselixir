defmodule Mix.Tasks.Ssselixir.User do
  use Mix.Task
  import Ecto.Query
  alias Ssselixir.{PortPassword, Repo}

  def run(args) do
    unless Mix.Project.config[:pp_store] == :db do
      raise "Unsupport user operation, because pp_store is :file"
    end
    {[port: port, password: password], _, _} =
      OptionParser.parse(args, switches: [port: :integer, password: :string])
    Application.ensure_all_started(:ecto)
    Ssselixir.start(:db)
    pp = Repo.one(from u in PortPassword, where: u.port == ^port)
    case pp do
      %{} ->
        {:ok, _} = pp
          |> PortPassword.changeset(%{password: password})
          |> Repo.update
        IO.puts "The existing record has been updated!"
      nil ->
        IO.puts "The record for port '#{port}' has been created"
        PortPassword.create(%{port: port, password: password})
    end
  end
end
