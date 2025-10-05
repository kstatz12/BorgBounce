defmodule BorgBounce.Psql.Auth.SCRAM do
  @moduledoc false

  defstruct gs2: "n,,",
            client_nonce: nil,
            client_first_bare: nil,
            salted: nil,
            stored_key: nil,
            client_key: nil,
            server_key: nil,
            auth_message: nil

  @type t :: %__MODULE__{}

  # API
  def start(mechs, password, nonce_fun \\ &default_nonce/0) do
    if "SCRAM-SHA-256" in parse_mechanisms(mechs) do
      cn = nonce_fun.()
      cf_bare = "n=,r=" <> cn
      {:ok, %__MODULE__{client_nonce: cn, client_first_bare: cf_bare}, "n,," <> cf_bare, password}
    else
      {:error, :no_scram}
    end
  end

  def continue(%__MODULE__{gs2: gs2, client_first_bare: cf_bare} = st, server_first, password) do
    {:ok, s_nonce, salt, iter} = parse_server_first(server_first, st.client_nonce)

    salted = :crypto.pbkdf2_hmac(:sha256, password, salt, iter, 32)
    ckey = :crypto.mac(:hmac, :sha256, salted, "Client Key")
    skey = :crypto.mac(:hmac, :sha256, salted, "Server Key")
    stored = :crypto.hash(:sha256, ckey)

    cb64 = Base.encode64(gs2)
    cf_wo = "c=" <> cb64 <> ",r=" <> s_nonce
    auth = cf_bare <> "," <> server_first <> "," <> cf_wo
    sig = :crypto.mac(:hmac, :sha256, stored, auth)
    proof = bxor_bin(ckey, sig) |> Base.encode64()

    client_final = cf_wo <> ",p=" <> proof

    st = %__MODULE__{
      st
      | salted: salted,
        stored_key: stored,
        client_key: ckey,
        server_key: skey,
        auth_message: auth
    }

    {:ok, st, client_final}
  end

  def finish(%__MODULE__{server_key: skey, auth_message: auth}, server_final) do
    case parse_server_final(server_final) do
      {:ok, server_sig_b64} ->
        expected = :crypto.mac(:hmac, :sha256, skey, auth) |> Base.encode64()
        if expected == server_sig_b64, do: :ok, else: {:error, :bad_signature}

      {:error, r} ->
        {:error, r}
    end
  end

  # --- pure helpers (parsers, nonce, xor) ---

  def parse_mechanisms(bin),
    do: bin |> :binary.split(<<0>>, [:global]) |> Enum.reject(&(&1 == <<>>))

  def parse_server_first(sf, client_nonce) do
    m = parse_scram_kv(sf)

    with {:ok, s_nonce} <- fetch(m, "r"),
         true <- String.starts_with?(s_nonce, client_nonce) or {:error, :nonce_mismatch},
         {:ok, b64} <- fetch(m, "s"),
         {:ok, i_s} <- fetch(m, "i"),
         {iter, ""} <- Integer.parse(i_s) do
      {:ok, s_nonce, Base.decode64!(b64), iter}
    end
  end

  def parse_server_final(sf) do
    case parse_scram_kv(sf) do
      %{"v" => v} -> {:ok, v}
      _ -> {:error, :invalid_server_final}
    end
  end

  defp parse_scram_kv(bin) do
    bin
    |> IO.iodata_to_binary()
    |> String.split(",", trim: true)
    |> Enum.reduce(%{}, fn pair, acc ->
      case String.split(pair, "=", parts: 2) do
        [k, v] -> Map.put(acc, k, v)
        _ -> acc
      end
    end)
  end

  defp fetch(m, k) do
    case(Map.fetch(m, k)) do
      {:ok, v} -> {:ok, v}
      :error -> {:error, {:missing, k}}
    end
  end

  defp default_nonce, do: Base.encode64(:crypto.strong_rand_bytes(18), padding: false)

  defp bxor_bin(a, b),
    do:
      :binary.list_to_bin(
        :lists.zipwith(&:erlang.bxor/2, :binary.bin_to_list(a), :binary.bin_to_list(b))
      )
end
