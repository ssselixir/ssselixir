defmodule SSSelixir.PortPassword do
  if Mix.Project.config[:pp_store] == :db do
    use Ecto.Schema

    schema "port_passwords" do
      field :port, :integer
      field :password, :string
    end

    def changeset(record, params \\ %{}) do
      record
      |> Ecto.Changeset.cast(params, [:port, :password])
      |> Ecto.Changeset.validate_required([:port, :password])
    end
  end
end
