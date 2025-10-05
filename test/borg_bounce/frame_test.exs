defmodule BorgBounce.Psql.FrameTest do
  use ExUnit.Case, async: true
  alias BorgBounce.Psql.Frame

  test "send_frame writes type + length + payload" do
    t = TestTransport.new()
    :ok = Frame.send_frame(t, ?X, "abc")
    sent = TestTransport.out_bytes(t.sock)
    # type
    assert <<?X, _len::32, "abc">> = sent
    # length is 4 (len field) + payload
    <<_t, len::32, payload::binary>> = sent
    assert len == 4 + byte_size(payload)
    assert payload == "abc"
  end

  test "recv_frame reads header and payload exactly" do
    # Prepare a valid frame: type 'Y', len=4+5, payload="hello"
    wire = <<?Y, (4 + 5)::32, "hello">>
    t = TestTransport.new(wire)

    assert {:ok, {?Y, <<len::32, payload::binary>>}} = Frame.recv_frame(t)
    assert len == 4 + 5
    assert payload == "hello"

    # buffer should now be empty; another recv fails
    assert {:error, :closed} = t.mod.recv(t.sock, 1, 10)
  end

  test "recv_frame handles multiple frames queued" do
    f1 = <<?A, (4 + 1)::32, "x">>
    f2 = <<?B, (4 + 2)::32, "yz">>
    t = TestTransport.new(f1 <> f2)

    assert {:ok, {?A, <<len1::32, "x">>}} = Frame.recv_frame(t)
    assert len1 == 5
    assert {:ok, {?B, <<len2::32, "yz">>}} = Frame.recv_frame(t)
    assert len2 == 6
  end

  test "send_raw passes through iodata" do
    t = TestTransport.new()
    :ok = Frame.send_raw(t, ["hi", <<0>>, "there"])
    assert TestTransport.out_bytes(t.sock) == "hi" <> <<0>> <> "there"
  end

  test "recv_frame error when truncated header" do
    t = TestTransport.new(<<?C, 0, 0, 0>>) # only 4 bytes, need 5
    assert {:error, :closed} = Frame.recv_frame(t)
  end

  test "recv_frame error when payload shorter than length" do
    # claims len = 4 + 10 but only provides 3 bytes payload
    t = TestTransport.new(<<?D, (4 + 10)::32, "abc">>)
    assert {:error, :closed} = Frame.recv_frame(t)
  end
end
