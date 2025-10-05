defmodule BorgBounce.Psql.Servers.ServerConnection do
  use GenServer
  require Logger

  alias BorgBounce.Psql.{Server, Socket}

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: opts[:name])
  end

  def init(%{server: server}) do
    case Socket.connect(server) do
      {:ok, conn} ->
        {:ok, %{connection: conn}}

      {:error, reason} ->
        Logger.error("Failed To Connecto To Server: #{inspect(reason)}")
        raise "Failed to Connect to Server #{inspect(server.host)}"
    end

    {:ok, %{server: server}}
  end
end
