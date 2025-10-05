defmodule BorgBounce.Psql.Frame do
  @moduledoc """
  frame helpers
  """

  def recv_frame(%{mod: mod, sock: sock} = _t) do
    with {:ok, <<type, len::32>>} <- mod.recv(sock, 5, 30_000),
         {:ok, payload} <- mod.recv(sock, len - 4, 30_000) do
      {:ok, {type, <<len::32, payload::binary>>}}
    end
  end

  def send_frame(%{mod: mod, sock: sock}, type, payload)
      when is_integer(type) and is_binary(payload) do
    len = 4 + byte_size(payload)
    mod.send(sock, [<<type>>, <<len::32>>, payload])
  end

  def send_raw(%{mod: mod, sock: sock}, iodata), do: mod.send(sock, iodata)

  def close_if_open(_), do: :ok
end
