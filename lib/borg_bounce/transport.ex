defmodule BorgBounce.Transport do
  @callback send(port(), iodata()) :: :ok | {:error, term()}
  @callback recv(port(), non_neg_integer(), timeout()) :: {:ok, binary()} | {:error, term()}
  @callback setopts(port(), list()) :: :ok | {:error, term()}
  @callback peername(port()) :: {:ok, {tuple(), :inet.port_number()}} | {:error, term()}
  @callback sockname(port()) :: {:ok, {tuple(), :inet.port_number()}} | {:error, term()}
  @callback close(port()) :: :ok

  defmodule TCP do
    @behaviour BorgBounce.Transport
    def send(s, i), do: :gen_tcp.send(s, i)
    def recv(s, n, t), do: :gen_tcp.recv(s, n, t)
    def setopts(s, o), do: :inet.setopts(s, o)
    def peername(s), do: :inet.peername(s)
    def sockname(s), do: :inet.sockname(s)
    def close(s), do: :gen_tcp.close(s)
  end
end
