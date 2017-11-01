require Logger
defmodule Ssselixir.Supervisor do
  import Ecto.Query
  use Supervisor
  alias Ssselixir.{PortPassword, Repo}

  def start_link(opts) do
    {:ok, supervisor} = Supervisor.start_link(__MODULE__, :ok, opts)
    :ets.insert(:app, {'supervisor', supervisor})
    start_servers()
  end

  def init(:ok) do
    children = [
      Ssselixir.Server
    ]

    Supervisor.init(children, strategy: :simple_one_for_one)
  end

  def start_servers do
    [{'supervisor', supervisor}] = :ets.lookup(:app, 'supervisor')
    case Mix.Project.config[:pp_store] do
      :file ->
        [{'port_password', port_passwords}] = :ets.lookup(:app_config, 'port_password')
        create_or_update_servers(:file, supervisor, port_passwords)
      :db ->
        port_passwords = Repo.all(from p in PortPassword, order_by: p.updated_at)
        create_or_update_servers(:db, supervisor, port_passwords)
    end

    if Mix.Project.config[:pp_store] == :db do
      Task.start_link(fn -> loop_update_servers(supervisor) end)
    end
    {:ok, supervisor}
  end

  defp loop_update_servers(supervisor) do
    [{'mtime', mtime}] = :ets.lookup(:app, 'mtime')
    datetime = mtime |> Ecto.DateTime.from_erl |> to_string
    port_passwords = Repo.all(
      from p in PortPassword,
      where: p.updated_at > ^datetime,
      order_by: p.updated_at)
    create_or_update_servers(:db, supervisor, port_passwords)

    :timer.sleep(60_000)
    loop_update_servers(supervisor)
  end

  defp create_or_update_servers(:file, supervisor, port_passwords) do
    Enum.each(port_passwords, fn {port, password} ->
      Logger.info "Start server on port: #{port}"
      Supervisor.start_child(supervisor, [:file, %{port: port, password: password}])
    end)
    {:ok, stat} = Application.get_env(:ssselixir, :app_config_file) |> File.stat
    :ets.insert(:app, {'mtime', stat.mtime})
  end

  defp create_or_update_servers(:db, supervisor, port_passwords) do
    Enum.each(port_passwords, fn port_password ->
      Logger.info "Start server on port: #{port_password.port}"
      Supervisor.start_child(supervisor, [:db, %{port_password: port_password}])
    end)
    last_record = List.last(port_passwords)
    if last_record != nil do
      {:ok, datetime} = Ecto.DateTime.cast(last_record.updated_at)
      :ets.insert(:app, {'mtime', Ecto.DateTime.to_erl(datetime) })
    else
      {:ok, datetime} = Ecto.DateTime.cast DateTime.utc_now
      :ets.insert(:app, {'mtime', Ecto.DateTime.to_erl(datetime) })
    end
  end
end
