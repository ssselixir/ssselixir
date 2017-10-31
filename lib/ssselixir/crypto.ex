defmodule Ssselixir.Crypto do
  def gen_key(seed) do
    dup_seed = to_string(seed)
    hashed_seed = :crypto.hash(:md5, dup_seed)
    hashed_seed <> :crypto.hash(:md5, hashed_seed <> dup_seed)
  end

  def gen_base64_encoded_key(seed) do
    seed
    |> gen_key
    |> Base.encode64
  end

  def base64_decoded_key(encoded_key) do
    {:ok, key} = Base.decode64(encoded_key)
    key
  end

  def init_encrypt_options({:key, key}) do
    %{key: key, iv: :crypto.strong_rand_bytes(16), rest: <<>>, iv_sent: false}
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
end
