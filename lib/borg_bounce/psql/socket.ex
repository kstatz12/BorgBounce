defmodule BorgBounce.Psql.Socket do
  @moduledoc """
  socket handling code
  """

  require Logger

  alias BorgBounce.Port

  alias BorgBounce.Psql.{Frame, Server}

  @protocol_v3 196_608
  @ssl_request_code 80_877_103

  @spec connect(Server.t()) :: {:ok, map()} | {:error, term()}
  def connect(%Server{
        host: host,
        port: port,
        user: user,
        password: password,
        database: database,
        ssl: ssl,
        ssl_opts: ssl_opts
      }) do
    with {:ok, sock} <-
           :gen_tcp.connect(String.to_charlist(host), Port.parse(port), [
             :binary,
             active: false,
             keepalive: true,
             nodelay: true
           ]),
         {:ok, transport} <-
           maybe_upgrade_to_ssl(%{mod: :gen_tcp, sock: sock}, host, ssl, ssl_opts),
         :ok <- send_startup(transport, user, database),
         :ok <- authenticate(transport, user, password),
         {:ok, %{key: key, status: status}} <- read_until_ready_and_key(transport) do
      {:ok, %{transport: transport, key: key, status: status}}
    else
      {:error, reason} = err ->
        Logger.error("Connection Failed for #{inspect(reason)}")
        _ = Frame.close_if_open(err)
        err
    end
  end

  defp maybe_upgrade_to_ssl(transport, _host, :disable, _opts), do: {:ok, transport}

  defp maybe_upgrade_to_ssl(%{mod: :gen_tcp, sock: sock} = t, host, pref, ssl_opts)
       when pref in [:prefer, :require] do
    :ok = :gen_tcp.send(sock, <<8::32, @ssl_request_code::32>>)

    case :gen_tcp.recv(sock, 1, 10_000) do
      {:ok, "S"} ->
        opts =
          [active: false, verify: :verify_none, server_name_indication: String.to_charlist(host)] ++
            ssl_opts

        case :ssl.connect(sock, opts, 10_000) do
          {:ok, ssl_sock} -> {:ok, %{mod: :ssl, sock: ssl_sock}}
          {:error, reason} -> {:error, {:ssl_handshake_failed, reason}}
        end

      {:ok, "N"} ->
        case pref do
          :require -> {:error, :ssl_required_but_not_available}
          :prefer -> {:ok, t}
        end

      {:ok, other} ->
        {:error, {:unexpected_ssl_response, other}}

      {:error, reason} ->
        {:error, {:ssl_request_failed, reason}}
    end
  end

  defp send_startup(transport, user, db) do
    kv =
      ["user", <<0>>, user, <<0>>, "database", <<0>>, db, <<0>>, <<0>>] |> IO.iodata_to_binary()

    len = 8 + byte_size(kv)
    Frame.send_raw(transport, [<<len::32, @protocol_v3::32>>, kv])
  end

  defp authenticate(transport, _user, password) do
    with {:ok, {?R, <<_::32, 0::32>>}} <- Frame.recv_frame(transport) do
      # AuthenticationOk (no password required)
      :ok
    else
      {:ok, {?R, <<_::32, 3::32>>}} ->
        # AuthenticationCleartextPassword
        payload = IO.iodata_to_binary([password || "", 0])
        Frame.send_frame(transport, ?p, payload)
        drain_until_auth_ok(transport)

      {:ok, {?R, <<_::32, code::32, rest::binary>>}} ->
        {:error, {:unsupported_auth, code, rest}}

      other ->
        other
    end
  end

  defp drain_until_auth_ok(transport) do
    case Frame.recv_frame(transport) do
      {:ok, {?R, <<_::32, 0::32>>}} -> :ok
      {:ok, {_t, _payload}} -> drain_until_auth_ok(transport)
      error -> error
    end
  end

  defp read_until_ready_and_key(sock, acc_key \\ nil) do
    case Frame.recv_frame(sock) do
      {:ok, {?K, <<12::32, pid::32, secret::32>>}} ->
        read_until_ready_and_key(sock, {pid, secret})

      {:ok, {?Z, <<5::32, _status>>}} ->
        {:ok, acc_key || {:unknown, :unknown}}

      {:ok, {_other, _payload}} ->
        read_until_ready_and_key(sock, acc_key)

      error ->
        error
    end
  end
end
