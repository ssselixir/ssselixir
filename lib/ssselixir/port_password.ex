defmodule SSSelixir.PortPassword do
  if Mix.Project.config[:pp_store] == :db do
    alias SSSelixir.Crypto

    use Ecto.Schema

    schema "port_passwords" do
      field :port, :integer
      field :password, :string
    end

    def changeset(record, params \\ %{}) do
      # Encrypt password before saving
      params = %{params | password: Crypto.gen_base64_encoded_key(params[:password])}
      record
      |> Ecto.Changeset.cast(params, [:port, :password])
      |> Ecto.Changeset.validate_required([:port, :password])
    end

    def create(%{port: _port, password: _password}=params) do
      %SSSelixir.PortPassword{}
      |> changeset(params)
      |> SSSelixir.Repo.insert
    end
  end
end
