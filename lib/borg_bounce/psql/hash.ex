defmodule BorgBounce.Psql.Hash do
  alias BorgBounce.Psql.Server

  @spec compute(Server.t()) :: String.t()
  def compute(server) do
    str =
      server
      |> Map.take([:host, :port, :user, :database])
      |> Map.values()
      |> Enum.join(":")

    :crypto.hash(:sha256, str)
    |> Base.encode16(case: :lower)
  end
end
