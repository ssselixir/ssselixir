# -*- coding: utf-8 -*-
#
# Copyright 2017 ssselixir
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may
# not use this file except in compliance with the License. You may obtain
# a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations
# under the License.
require Logger
defmodule Ssselixir do
  use Application

  if Mix.Project.config[:pp_store] == :db do
    def start(:db) do
      Supervisor.start_link([Ssselixir.Repo], strategy: :one_for_one)
    end
  end

  def start(_type, _args) do
    init_ets_tables()
    load_config()

    children = [
      Ssselixir.Supervisor
    ]

    if Mix.Project.config[:pp_store] == :db do
      children = [Ssselixir.Repo] ++ children
    end

    Supervisor.start_link(children, strategy: :one_for_one)
  end

  def init_ets_tables do
    :ets.new(:app_config, [:named_table])
    :ets.new(:app, [:named_table, :public])
    :ets.new(:processes, [:named_table, :public])
  end

  def load_config do
    if Mix.Project.config[:pp_store] == :file do
      :ets.insert(:app_config, {'port_password', fetch_setting('port_password')})
    end
    :ets.insert(:app_config, {'timeout', fetch_setting('timeout')})
  end

  def fetch_setting(key) do
    case Application.get_env(:ssselixir, :app_config_file)
      |>:yamerl_constr.file
      |> List.first
      |> List.keyfind(key, 0) do

      {key, data} ->
        Logger.info "Loading #{key}"
        data
      _ ->
        Logger.error "Invalid configurations"
        Process.exit(self(), :kill)
    end
  end
end
