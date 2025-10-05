defmodule BorgBounce.Psql.RanchProtocol do
  @behaviour :ranch_protocol
  alias BorgBounce.{Transport}
  alias BorgBounce.Psql.Servers.ClientConnection

  def start_link(ref, _socket, transport, _opts) do
    # Accept and take ownership of the socket
    {:ok, socket} = :ranch.handshake(ref)
    # Map Ranch’s transport to our shim
    transport_mod =
      case transport do
        :ranch_tcp ->
          Transport.TCP
          # TODO ssl
      end

    ClientConnection.start_link({socket, transport_mod})
  end
end
