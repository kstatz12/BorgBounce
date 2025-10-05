defmodule TestTransport do
  @moduledoc false
  # sock is an Agent that stores {:in_bytes, :out_iolist}
  def new(bytes \\ <<>>) do
    {:ok, pid} =
      Agent.start_link(fn -> %{in: bytes, out: []} end)

    %{mod: __MODULE__, sock: pid}
  end

  # Precise read of n bytes (like :gen_tcp.recv with exact size after header)
  def recv(pid, n, _timeout) when is_integer(n) and n >= 0 do
    Agent.get_and_update(pid, fn %{in: bin, out: out} = st ->
      cond do
        byte_size(bin) >= n ->
          <<chunk::binary-size(n), rest::binary>> = bin
          {{:ok, chunk}, %{st | in: rest, out: out}}

        true ->
          {{:error, :closed}, st}
      end
    end)
  end

  # Capture all sends in :out (iolist)
  def send(pid, iodata) do
    Agent.update(pid, fn %{in: bin, out: out} -> %{in: bin, out: [out, iodata]} end)
    :ok
  end

  def out_bytes(pid) do
    Agent.get(pid, fn %{out: out} -> IO.iodata_to_binary(out) end)
  end

  def push_in(pid, bytes) do
    Agent.update(pid, fn %{in: bin} = st -> %{st | in: bin <> bytes} end)
  end
end
