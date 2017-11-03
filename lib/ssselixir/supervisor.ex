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
        utc_now = Ecto.DateTime.utc |> to_string
        port_passwords =
          Repo.all(
            from p in PortPassword,
            where: p.end_at > ^utc_now,
            order_by: p.port)
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
    utc_now = Ecto.DateTime.utc |> to_string
    port_passwords =
      Repo.all(
        from p in PortPassword,
        where: p.updated_at > ^datetime and p.end_at > ^utc_now,
        order_by: p.updated_at)

    create_or_update_servers(:db, supervisor, port_passwords)

    outdated_port_passwords =
      Repo.all(
        from p in PortPassword,
        where: p.end_at >= ^datetime and p.end_at <= ^utc_now,
        order_by: p.updated_at)

    shutdown_servers(:db, supervisor, outdated_port_passwords)

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
      update_child_and_ets(supervisor, port_password)
    end)

    last_record = List.last(port_passwords)
    if last_record != nil do
      {:ok, datetime} = Ecto.DateTime.cast(last_record.updated_at)
      :ets.insert(:app, {'mtime', Ecto.DateTime.to_erl(datetime) })
    else
      datetime = Ecto.DateTime.utc
      :ets.insert(:app, {'mtime', Ecto.DateTime.to_erl(datetime) })
    end
  end

  defp shutdown_servers(:db, supervisor, port_passwords) do
    Enum.each(port_passwords, fn(port_password) ->
      terminate_child(supervisor, port_password.port)
    end)
  end

  defp terminate_child(supervisor, port) do
    # Terminate the previous child process if it is exists
    case :ets.lookup(:processes, port) do
      [{^port, prev_child}] ->
        Logger.info "Stop server on port: #{port}"
        :ok = Supervisor.terminate_child(supervisor, prev_child)
        true = :ets.delete(:processes, port)
      [] -> nil
    end
  end

  defp update_child_and_ets(supervisor, port_password) do
    port = port_password.port
    terminate_child(supervisor, port)
    # Start a child
    Logger.info "Start server on port: #{port}"
    {:ok, child} = supervisor |> Supervisor.start_child([:db, %{port_password: port_password}])
    :ets.insert(:processes, {port, child})
  end
end
