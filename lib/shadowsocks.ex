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
defmodule Shadowsocks do
  require Logger

  def start_handle(client) do
    Task.start(fn -> handle(client) end)
  end

  def start_loop_reply do
    Task.start_link(fn -> loop_reply() end)
  end

  def start(_type, _args) do
    {:ok, data} = port_password()
    Enum.each(data, fn {port, password} ->
      Task.start(
        fn ->
          {:ok, server} = listen(port)
          Logger.info "Start server on port: #{port}"
          loop_accept(server, gen_key(password))
        end
      )
    end)
    {:ok, self()}
  end

  def port_password do
    case :yamerl_constr.file("config/app_config.yml") |> List.first |> List.first do
      {'port_password', data} ->
        {:ok, data}
      _ ->
        Logger.error "Invalid configurations"
        Process.exit(self(), :kill)
    end
  end

  def listen(port) do
    opts = [:binary, active: false, reuseaddr: true]
    :gen_tcp.listen(port, opts)
  end

  def loop_accept(server, key) do
    case accept(server) do
      {:ok, client} ->
        {:ok, pid} = start_handle(client)
        send pid, {:key, key}
      _ ->
        Logger.error "Connection error"
    end
    loop_accept(server, key)
  end

  def accept(server) do
    :gen_tcp.accept(server)
  end

  def create_remote_connection(addr, port) do
    opts = [:binary, active: false]
    :gen_tcp.connect(addr, port, opts)
  end

  def send_data(sock, data) do
    :gen_tcp.send(sock, data)
  end

  def recv_data(sock) do
    :gen_tcp.recv(sock, 0)
  end

  def handle(sock) do
    receive do
      {:key, key} ->
        {:ok, encrypted_data} = recv_data(sock)
        {data, decrypt_options} = decrypt(encrypted_data, %{key: key, iv: <<>>, rest: <<>>})
        encrypt_options = %{key: key, iv: :crypto.strong_rand_bytes(16), rest: <<>>, iv_sent: false}
        addrtype = String.at(data, 0) |> Base.encode16 |> String.to_integer(16)
        addrlen = String.at(data, 1) |> Base.encode16 |> String.to_integer(16)
        port = String.slice(data, 2+addrlen, 2) |> Base.encode16 |> String.to_integer(16)
        result =
          case addrtype do
            1 ->
              {:ok, String.slice(data, 2, addrlen) |> String.to_charlist}
            3 ->
              {:ok, String.slice(data, 2, addrlen) |> String.to_charlist}
            _ ->
              {:error, :invalid_addrtype}
          end
        case result do
          {:ok, addr}->
            Logger.info("Connect to " <> to_string(addr) <> to_string(port))
            case create_remote_connection(addr, port) do
              {:ok, remote} ->
                rest_data = :binary.part(data, 4+addrlen, byte_size(data)-(4+addrlen))
                if byte_size(rest_data) > 0, do: send_data(remote, rest_data)
                handle_tcp(sock, remote, decrypt_options, encrypt_options)
              {:error, _} ->
                :gen_tcp.shutdown(sock, :read_write)
                Logger.warn "Connected failed"
            end
          {:error, :invalid_addrtype} ->
            Logger.error "Wrong type"
            :gen_tcp.shutdown(sock, :read_write)
        end
    end
  end

  def handle_tcp(client, remote, decrypt_options, encrypt_options) do
    {:ok, c2r_pid} = start_loop_reply()
    send c2r_pid, {:c2r, client, remote, decrypt_options, self()}
    {:ok, r2c_pid} = start_loop_reply()
    send r2c_pid, {:r2c, remote, client, encrypt_options, self()}
    receive do
      {:error, :closed} ->
        Logger.warn "Connection closed!"
        :gen_tcp.shutdown(client, :read_write)
        :gen_tcp.shutdown(remote, :read_write)
        Process.exit(c2r_pid, :kill)
        Process.exit(r2c_pid, :kill)
    end
  end

  def gen_key(seed) do
    _seed = to_string(seed)
    hashed_seed = :crypto.hash(:md5, _seed)
    hashed_seed <> :crypto.hash(:md5, hashed_seed <> _seed)
  end

  def encrypt(data, %{key: key, iv: iv, rest: rest, iv_sent: iv_sent}) do
    rest_len = byte_size(rest)
    data_len = byte_size(data)
    len = div((data_len + rest_len), 16) * 16
    <<data::binary-size(len), rest::binary>> = <<rest::binary, data::binary>>
    enc_data = :crypto.block_encrypt(:aes_cfb128, key, iv, data)
    new_iv = :binary.part(<<iv::binary, enc_data::binary>>, byte_size(enc_data)+16, -16)
    enc_rest = :crypto.block_encrypt(:aes_cfb128, key, new_iv, rest)
    encrypted_data = :binary.part(<<enc_data::binary, enc_rest::binary>>, rest_len, data_len)
    if iv_sent do
      { encrypted_data, %{key: key, iv: new_iv, rest: rest, iv_sent: iv_sent} }
    else
      { <<iv::binary, encrypted_data::binary>>, %{key: key, iv: new_iv, rest: rest, iv_sent: true}}
    end
  end

  def decrypt(data, %{key: key, iv: iv, rest: rest}) do
    if byte_size(iv) == 0 do
      iv = :binary.part(data, 0, 16)
      data = :binary.part(data, 16, byte_size(data)-16)
    end
    data_len = byte_size(data)
    rest_len = byte_size(rest)
    len = div((data_len+rest_len), 16) * 16
    <<data::binary-size(len), rest::binary>> = <<rest::binary, data::binary>>

    dec_data = :crypto.block_decrypt(:aes_cfb128, key, iv, data)
    iv = :binary.part(<<iv::binary, data::binary>>, byte_size(data)+16, -16)
    dec_rest = :crypto.block_decrypt(:aes_cfb128, key, iv, rest)
    decrypted_data = :binary.part(<<dec_data::binary, dec_rest::binary>>, rest_len, data_len)
    {decrypted_data, %{key: key, iv: iv, rest: rest}}
  end

  def loop_reply do
    receive do
      {:c2r, client, remote, decrypt_options, caller} ->
        reply(:c2r, client, remote, decrypt_options, caller)
      {:r2c, remote, client, encrypt_options, caller} ->
        reply(:r2c, remote, client, encrypt_options, caller)
    end
  end

  defp reply(direction, from, to, crypto_options, caller) do
    case recv_data(from) do
      {:ok, data} ->
        case direction do
          :c2r ->
            {plain_data, decrypt_options} = decrypt(data, crypto_options)
            case send_data(to, plain_data) do
              :ok -> send(self(), {:c2r, from, to, decrypt_options, caller})
              {:error, _} ->
                send caller, {:error, :closed}
            end

          :r2c ->
            {encrypted_data, encrypt_options} = encrypt(data, crypto_options)
            case send_data(to, encrypted_data) do
              :ok -> send(self(), {:r2c, from, to, encrypt_options, caller})
              {:error, _} ->
                send caller, {:error, :closed}
            end
        end
        loop_reply()
      _ ->
        send caller, {:error, :closed}
    end
  end
end
