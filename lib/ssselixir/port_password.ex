defmodule Ssselixir.PortPassword do
  if Mix.Project.config[:pp_store] == :db do
    alias Ssselixir.Crypto

    use Ecto.Schema

    schema "port_passwords" do
      field :port, :integer
      field :password, :string
      field :started_at, :naive_datetime
      field :end_at, :naive_datetime
      timestamps()
    end

    def changeset(record, params \\ %{}) do
      # Encrypt password before saving
      if (params[:password] |> to_string |> String.length) > 0 do
        params = %{params | password: Crypto.gen_base64_encoded_key(params[:password])}
      end
      record
      |> Ecto.Changeset.cast(params, [:port, :password, :started_at, :end_at])
      |> Ecto.Changeset.validate_required([:port, :password, :started_at, :end_at])
    end

    def create(params) do
      %Ssselixir.PortPassword{}
      |> changeset(params)
      |> Ssselixir.Repo.insert
    end
  end
end
