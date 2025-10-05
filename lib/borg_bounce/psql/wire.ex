defmodule BorgBounce.Psql.Wire do
  @moduledoc """
  Minimal PostgreSQL v3 wire helpers for a Simple-Query-only pooler.

  Notes:
  - Length fields include themselves but not the 1-byte type code.
  - Startup/SSL/Cancel are *untagged* (no type code).
  """

  # "Magic" request codes (per protocol)
  @ssl_request 80_877_103
  @cancel_request 80_877_102

  # === Client (frontend) messages ===

  # Untagged: [len::u32, protocol::u32, payload (key\0val\0... \0)]
  def match_startup_message(<<len::32, 196_608::32, rest::binary>>) when len >= 8 do
    {:startup, rest, len}
  end

  def match_startup_message(_), do: :no

  # Untagged: [len::u32, 80877103]
  def match_ssl_request(<<8::32, @ssl_request::32>>), do: :ssl_request
  def match_ssl_request(_), do: :no

  # Untagged: [len::u32, 80877102, pid::u32, secret::u32]
  def match_cancel_request(<<16::32, @cancel_request::32, pid::32, secret::32>>),
    do: {:cancel, pid, secret}

  def match_cancel_request(_), do: :no

  # Tagged simple query: ?Q, len, sql\0
  def match_query(<<?Q, len::32, sql_and_nul::binary>>) do
    {:query, len, sql_and_nul}
  end

  def match_query(_), do: :no

  # Extended protocol (we'll reject for MVP)
  # Parse Bind Describe Execute Sync Flush Close Function
  @extended ~c"PBDESXHCF"
  def is_extended?(<<tag, _rest::binary>>) when tag in @extended, do: true
  def is_extended?(_), do: false

  # === Server (backend) messages ===

  # BackendKeyData: ?K, len, pid::u32, secret::u32
  def match_backend_keydata(<<?K, 12::32, pid::32, secret::32>>), do: {:keydata, pid, secret}
  def match_backend_keydata(_), do: :no

  # ReadyForQuery: ?Z, len (=5), status::byte ("I", "T", or "E")
  def match_ready(<<?Z, 5::32, status>>), do: {:ready, status}
  def match_ready(_), do: :no

  # General message splitter: returns {one_msg, rest} if a full message is available
  # For tagged messages: [type::byte][len::u32][payload=(len-4) bytes]
  def take_one(<<type, len::32, rest::binary>>) when byte_size(rest) >= len - 4 do
    payload_size = len - 4
    <<payload::binary-size(payload_size), tail::binary>> = rest
    {<<type, len::32, payload::binary>>, tail}
  end

  # For untagged (handled separately by specific matchers), we don't split here
  def take_one(_incomplete), do: :incomplete

  # === Encoders for tiny responses ===

  # Respond "N" to SSLRequest (deny / tunnel-plain)
  def ssl_deny(), do: "N"

  # ErrorResponse (very small helper)
  # Fields are "S"everity, "C"ode, "M"essage ended by 0; terminated by 0
  def error_response(msg, code \\ "0A000", severity \\ "ERROR") do
    fields =
      ["S", severity, 0, "C", code, 0, "M", msg, 0, 0]
      |> IO.iodata_to_binary()

    len = 4 + byte_size(fields)
    [<<?E>>, <<len::32>>, fields]
  end
end
