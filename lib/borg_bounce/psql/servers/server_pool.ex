defmodule BorgBounce.Psql.Servers.Pool do
  use GenServer
  require Logger

  @ttl_ms 30_000

  alias BorgBounce.Psql.Hash
  alias BorgBounce.Psql.Servers.ServerConnection

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: opts[:name] || __MODULE__)
  end

  def lease_connection(
        available_connections \\ :available_connections,
        leased_connections \\ :leased_connections_table
      ) do
    case :ets.first(available_connections) do
      :"$end_of_table" ->
        {:error, :empty}

      key ->
        case :ets.take(available_connections, key) do
          [] ->
            lease_connection(available_connections)

          [{^key, node}] ->
            lease_until = System.monotonic_time(:millisecond) + @ttl_ms
            :ets.insert(leased_connections, {key, node, lease_until})
            {:ok, {key, node.pid}}
        end
    end
  end

  def release_connection(
        key,
        available_connections \\ :available_connections,
        leased_connections \\ :leased_connections_table
      ) do
    case :ets.take(leased_connections, key) do
      [{^key, node, _until}] ->
        :ets.insert(available_connections, {key, node})
        :ok

      [] ->
        {:error, :not_leased}
    end
  end

  @impl true
  def init(opts) do
    Process.flag(:trap_exit, true)

    available_connections =
      :ets.new(opts[:available_connections_table_name] || :available_connections, [
        :named_table,
        :set,
        :public,
        {:write_concurrency, true}
      ])

    leased_connections =
      :ets.new(opts[:leased_connections_table_name] || :leased_connections, [
        :named_table,
        :set,
        :public,
        {:write_concurrency, true}
      ])

    server = opts[:server]
    hash = Hash.compute(server)

    server
    |> do_create_nodes()
    |> Enum.reduce(0, fn n, acc ->
      :ets.insert(available_connections, {"#{acc}_#{hash}"})

      acc + 1
    end)

    {:ok,
     %{
       available_connections_table: available_connections,
       leased_connections_table: leased_connections,
       server: opts[:server]
     }}
  end

  @impl true
  def terminate(reason, state) do
    Logger.info("shutting down #{self()} for reason #{reason}")
    do_kill_nodes(state.table_name)
  end

  @impl true
  def handle_info({:DOWN, ref, :process, pid, reason}, state) do
    Logger.info("Process #{inspect(pid)} died: #{inspect(reason)}")
    {:ok, pid} = ServerConnection.start_link(%{name: pid})
    {:noreply, Map.delete(state.monitors, ref)}
  end

  def do_kill_nodes(table_name) do
    nodes = :ets.match_object(table_name, {:"$1", :"$2"})

    case nodes do
      [] ->
        :noop

      _ ->
        nodes
        |> Enum.each(fn n ->
          Logger.info("Shutting Down #{n.pid}:#{n.name} for server #{n.hash}")
          Process.exit(n.pid, :router_shutdown)
        end)
    end
  end

  defp do_create_nodes(server) do
    hash = Hash.compute(server)

    nodes =
      case server.pool_size do
        0 ->
          {:ok, []}

        size ->
          [1..size]
          |> Enum.map(fn idx ->
            name = :"#{hash}_#{idx}"
            {:ok, pid} = ServerConnection.start_link(%{name: name, server: server})
            Process.monitor(pid)

            %{
              name: name,
              pid: pid,
              hash: hash,
              server: server
            }
          end)
      end
  end

  def get_all(table_name \\ :psql_servers) do
    :ets.match_object(table_name, {:"$1", :"$2"})
  end

  def keys(table_name \\ :psql_servers) do
    :ets.match(table_name, {:"$1", :_}) |> Enum.flat_map(fn x -> x end)
  end

  defp get(table_name \\ :psql_servers, key) do
    :ets.lookup(table_name, key)
    |> case do
      [] -> {:error, :unregistered}
      [server] -> {:ok, server}
    end
  end
end
