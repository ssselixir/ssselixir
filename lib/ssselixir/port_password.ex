defmodule Ssselixir.PortPassword do
  if Mix.Project.config[:pp_store] == :db do
    alias Ssselixir.Crypto

    use Ecto.Schema

    schema "port_passwords" do
      field :port, :integer
      field :password, :string
      timestamps
    end

    def changeset(record, params \\ %{}) do
      # Encrypt password before saving
      params = %{params | password: Crypto.gen_base64_encoded_key(params[:password])}
      record
      |> Ecto.Changeset.cast(params, [:port, :password])
      |> Ecto.Changeset.validate_required([:port, :password])
    end

    def create(%{port: _port, password: _password}=params) do
      %Ssselixir.PortPassword{}
      |> changeset(params)
      |> Ssselixir.Repo.insert
    end
  end
end
