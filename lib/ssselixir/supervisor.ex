require Logger
defmodule Ssselixir.Supervisor do
  use Supervisor

  def start_link(opts) do
    {:ok, supervisor} = Supervisor.start_link(__MODULE__, :ok, opts)
    start_servers(supervisor)
  end

  def init(:ok) do
    children = [
      Ssselixir.Server
    ]

    Supervisor.init(children, strategy: :simple_one_for_one)
  end

  def start_servers(supervisor) do
    case Mix.Project.config[:pp_store] do
      :file ->
        [{'port_password', port_passwords}] = :ets.lookup(:app_config, 'port_password')
        Enum.each(port_passwords, fn {port, password} ->
          Logger.info "Start server on port: #{port}"
          Supervisor.start_child(supervisor, [:file, %{port: port, password: password}])
        end)
      :db ->
        port_passwords = PortPassword |> Repo.all
        Enum.each(port_passwords, fn port_password ->
          Logger.info "Start server on port: #{port_password.port}"
          Supervisor.start_child(supervisor, [:db, %{port_password: port_password}])
        end)
    end
    {:ok, supervisor}
  end
end
