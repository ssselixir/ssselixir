defmodule Ssselixir.Repo.Migrations.AddStartedAndEndAtToPortPasswords do
  use Ecto.Migration

  def change do
    alter table(:port_passwords) do
      add :started_at, :naive_datetime
      add :end_at, :naive_datetime
    end
  end
end
