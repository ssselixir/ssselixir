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

defmodule Ssselixir.Server do
  alias Ssselixir.{Crypto, PortPassword, Repo}

  use GenServer

  def start_link(opts) do
    load_config()
    GenServer.start_link(__MODULE__, Mix.Project.config[:pp_store], opts)
  end

  def init(:file) do
    [{'port_password', port_passwords}] = :ets.lookup(:app_config, 'port_password')
    accept_list = []
    Enum.each(port_passwords, fn {port, password} ->
      Logger.info "Start server on port: #{port}"
      {:ok, accept_pid} = Task.start_link(
        fn ->
          loop_accept(listen(port), Crypto.gen_key(password))
        end
      )
      accept_list = accept_list ++ [accept_pid]
    end)
    {:ok, accept_list}
  end

  def init(:db) do
    port_passwords = PortPassword |> Repo.all
    accept_list = []
    Enum.each(port_passwords, fn port_password ->
      Logger.info "Start server on port: #{port_password.port}"
      {:ok, accept_pid} = Task.start_link(
        fn ->
          listen(port_password.port)
          |> loop_accept(
            port_password.password |> Crypto.base64_decoded_key
          )
        end)
      accept_list = accept_list ++ [accept_pid]
    end)
    {:ok, accept_list}
  end

  def start_handle(client) do
    Task.start(fn -> handle(client) end)
  end

  def start_loop_reply do
    Task.start_link(fn -> loop_reply() end)
  end

  def load_config do
    :ets.new(:app_config, [:named_table])
    :ets.insert(:app_config, {'port_password', fetch_setting('port_password')})
    :ets.insert(:app_config, {'timeout', fetch_setting('timeout')})
  end

  def fetch_setting(key) do
    case :yamerl_constr.file("config/app_config.yml") |> List.first |> List.keyfind(key, 0) do
      {key, data} ->
        Logger.info "Loading data"
        data
      _ ->
        Logger.error "Invalid configurations"
        Process.exit(self(), :kill)
    end
  end

  def listen(port) do
    opts = [:binary, active: false, reuseaddr: true]
    :gen_tcp.listen(port, opts)
  end

  def handle_accept(server, {:key, key}) do
    case accept(server) do
      {:ok, client} ->
        {:ok, pid} = start_handle(client)
        send pid, {:key, key}
        :ok
      {:error, _} -> {:error, :server_error}
    end
  end

  def loop_accept({:ok, server}=sevopts, key) do
    :ok = handle_accept(server, {:key, key})
    loop_accept(sevopts, key)
  end

  def accept(server) do
    :gen_tcp.accept(server)
  end

  def shutdown({:socket, socket}) do
    :gen_tcp.shutdown(socket, :read_write)
  end

  def create_remote_connection(addr, port) do
    [{'timeout', timeout}] = :ets.lookup(:app_config, 'timeout')
    opts = [:binary, active: false]
    :gen_tcp.connect(addr, port, opts, timeout * 1000)
  end

  def send_data(sock, data) do
    :gen_tcp.send(sock, data)
  end

  def recv_data(sock) do
    [{'timeout', timeout}] = :ets.lookup(:app_config, 'timeout')
    :gen_tcp.recv(sock, 0, timeout * 1000)
  end

  def parse_header(plain_data) do
    addrtype = plain_data |> binary_part(0, 1) |> to_i

    case addrtype do
      1 ->
        <<p1, p2, p3, p4>> = binary_part(plain_data, 1, 4)
        addr = :inet.ntoa({p1, p2, p3, p4})
        addrlen = 4
        port = plain_data |> binary_part(5, 2) |> to_i
        {:ok, addrtype, addrlen, addr, port}

      3 ->
        addrlen = plain_data |> binary_part(1, 1) |> to_i
        addr = plain_data |> binary_part(2, addrlen) |> to_charlist
        port = plain_data |> binary_part(2+addrlen, 2) |> to_i
        {:ok, addrtype, addrlen, addr, port}

      _ -> {:error, :invalid_header}
    end
  end

  def handle(sock) do
    receive do
      {:key, key} ->
        case recv_data(sock) do
          {:ok, encrypted_data} ->
            {plain_data, decrypt_options} =
              Crypto.decrypt(encrypted_data, %{key: key, iv: <<>>, rest: <<>>})
            case parse_header(plain_data) do
              {:ok, addrtype, addrlen, addr, port} ->
                case create_remote_connection(addr, port) do
                  {:ok, remote} ->
                    {:ok, {ip_addr, ip_port}} = :inet.peername(sock)
                    Logger.info "CONNECT TO #{addr}:#{port} FROM #{:inet.ntoa(ip_addr)}:#{ip_port}"
                    rest_data =
                      if addrtype == 1 do
                        :binary.part(plain_data, 3+addrlen, byte_size(plain_data)-(3+addrlen))
                      else
                        :binary.part(plain_data, 4+addrlen, byte_size(plain_data)-(4+addrlen))
                      end
                    if byte_size(rest_data) > 0, do: send_data(remote, rest_data)
                    handle_tcp(sock, remote, decrypt_options, Crypto.init_encrypt_options({:key, key}))

                  {:error, _} ->
                    shutdown({:socket, sock})
                    Logger.error "Connected failed or timeout"
                end
              {:error, :invalid_header} ->
                Logger.error "Invalid header"
                shutdown({:socket, sock})
            end
          {:error, _} ->
            Logger.error "Connected timeout or closed"
            shutdown({:socket, sock})
        end
      _ ->
        Logger.error "Wrong message received"
        shutdown({:socket, sock})
    end
  end

  def handle_tcp(client, remote, decrypt_options, encrypt_options) do
    {:ok, c2r_pid} = start_loop_reply()
    send c2r_pid, {:c2r, client, remote, decrypt_options, self()}
    {:ok, r2c_pid} = start_loop_reply()
    send r2c_pid, {:r2c, remote, client, encrypt_options, self()}
    receive do
      {:error, :closed} ->
        shutdown({:socket, client})
        shutdown({:socket, remote})
    end
  end

  def loop_reply do
    receive do
      {:c2r, client, remote, decrypt_options, caller} ->
        reply(:c2r, client, remote, decrypt_options, caller)
      {:r2c, remote, client, encrypt_options, caller} ->
        reply(:r2c, remote, client, encrypt_options, caller)
    end
  end

  defp to_i(data) do
    data |> Base.encode16 |> String.to_integer(16)
  end

  defp reply(direction, from, to, crypto_options, caller) do
    case recv_data(from) do
      {:ok, data} ->
        case direction do
          :c2r ->
            {plain_data, decrypt_options} = Crypto.decrypt(data, crypto_options)
            case send_data(to, plain_data) do
              :ok ->
                send(self(), {:c2r, from, to, decrypt_options, caller})
                loop_reply()
              {:error, _} ->
                send caller, {:error, :closed}
            end

          :r2c ->
            {encrypted_data, encrypt_options} = Crypto.encrypt(data, crypto_options)
            case send_data(to, encrypted_data) do
              :ok ->
                send(self(), {:r2c, from, to, encrypt_options, caller})
                loop_reply()
              {:error, _} ->
                send caller, {:error, :closed}
            end
        end
      _ ->
        send caller, {:error, :closed}
    end
  end
end
