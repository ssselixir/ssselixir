defmodule SSSelixir.Supervisor do
  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, :ok, opts)
  end

  def init(:ok) do
    children = [
      SSSelixir.Server
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
