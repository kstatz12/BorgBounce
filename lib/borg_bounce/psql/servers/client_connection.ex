defmodule BorgBounce.Psql.Servers.ClientConnection do
  @moduledoc """
  One process per client socket. Simple-Query-only, transaction pooling.

  Flow:
    1) Accept TCP
    2) Handle SSLRequest -> reply "N"
    3) Receive StartupMessage and *relay* it using a pooled backend (auth already done)
    4) After ReadyForQuery (from backend), we're in :idle and can serve Queries
    5) For each client Query, attach a backend, proxy until ReadyForQuery, release backend
  """

  require Logger
  use GenServer

  alias BorgBounce.Psql.{Wire}
  alias BorgBounce.Psql.Servers.{Pool}

  def start_link({socket, transport_mod}),
    do: GenServer.start_link(__MODULE__, {socket, transport_mod})

  def init({socket, transport_mod}) do
    transport_mod.setopts(socket, [:binary, {:active, :once}])
    {:ok, %{client: socket, t: transport_mod, phase: :preauth, pool: nil, cancel_key: nil}}
  end

  def init(client_sock) do
    :ok = :inet.setopts(client_sock, active: :once)
    {:ok, %{client: client_sock, phase: :preauth, pool: nil, cancel_key: nil}}
  end
end
