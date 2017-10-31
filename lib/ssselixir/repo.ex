defmodule SSSelixir.Repo do
  if Mix.Project.config[:pp_store] == :db do
    use Ecto.Repo, otp_app: :ssselixir
  end
end
