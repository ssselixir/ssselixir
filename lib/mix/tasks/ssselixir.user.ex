defmodule Mix.Tasks.Ssselixir.User do
  use Mix.Task
  import Ecto.Query
  alias Ssselixir.{PortPassword, Repo}

  def run(args) do
    unless Mix.Project.config[:pp_store] == :db do
      raise "Unsupport user operation, because pp_store is :file"
    end
    args
    |> parse_args
    |> create_or_update
  end

  defp ensure_started_db do
    Application.ensure_all_started(:ecto)
    Ssselixir.start(:db)
  end

  defp parse_args(args) do
    opts = [
      start_time: :string, range: :string,
      port: :integer, password: :string]

    case OptionParser.parse!(args, strict: opts) do
      {parsed, _} ->
        if parsed[:port] |> is_integer do
          start_time = parse_time(parsed[:start_time])
          end_time = get_endtime(start_time, parsed[:range])
        else
          raise "Port is required"
        end
        {:ok, start_time} = NaiveDateTime.from_erl(start_time)
        {:ok, end_time} = NaiveDateTime.from_erl(end_time)
        %{port: parsed[:port], password: parsed[:password], started_at: start_time, end_at: end_time}
    end
  end

  def get_endtime({date, time}, range) do
    case Regex.run(~r/([0-9]+)\.+(hour|day|month|year)/, range) do
      [_, count, "hour"] ->
        count = String.to_integer(count)
        {hour, minute, second} = time
        days = div(count + hour, 24)
        rest_hour = rem(count + hour, 24)
        {:ok, date} = Date.from_erl(date)
        end_date = Date.add(date, days) |> Date.to_erl
        {end_date, {rest_hour, minute, second}}
      [_, count, "day"] ->
        count = String.to_integer(count)
        {:ok, date} = Date.from_erl(date)
        end_date = Date.add(date, count) |> Date.to_erl
        {end_date, time}
      [_, count, "month"] ->
        count = String.to_integer(count)
        {year, month, day} = date
        year = year + div(count + month, 12)
        month = rem(count + month, 12)
        {{year, month, day}, time}
      [_, count, "year"] ->
        count = String.to_integer(count)
        {year, month, day} = date
        {{year + count, month, day}, time}
      _ ->
        if range == "forever" do
          {{9999, 12, 31}, {23, 59, 59}}
        else
          raise "Invalid range format"
        end
    end
  end

  def parse_time(str) do
    if str == "now" do
      {:ok, datetime} = DateTime.utc_now |> Ecto.DateTime.cast
      datetime |> Ecto.DateTime.to_erl
    else
      case Ecto.DateTime.cast(str) do
        {:ok, date_time} ->
          Ecto.DateTime.to_erl(date_time)
        :error ->
          case Ecto.Date.cast(str) do
            {:ok, date} ->
              {Ecto.Date.to_erl(date), {0,0,0}}
            :error ->
              raise "Invalid DateTime format"
          end
      end
    end
  end

  defp create_or_update(%{port: port, password: password, started_at: start_time, end_at: end_time}) do
    ensure_started_db()
    pp = Repo.one(from u in PortPassword, where: u.port == ^port)
    changed_cols = %{started_at: start_time, end_at: end_time}

    case pp do
      %{} ->
        if password |> is_binary do
          changed_cols = Map.put(changed_cols, :password, password)
        end
        {:ok, _} = pp
          |> PortPassword.changeset(changed_cols)
          |> Repo.update
        IO.puts "The existing record has been updated!"
      nil ->
        if password |> is_nil do
          raise "Password is required when creating record."
        end
        IO.puts "The record for port '#{port}' has been created"
        PortPassword.create(%{port: port, password: password})
    end
  end
end
