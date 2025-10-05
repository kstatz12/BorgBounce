defmodule BorgBounce.Psql.FramePropTest do
  use ExUnit.Case
  use PropCheck
  alias BorgBounce.Psql.Frame

  property "recv_frame reads correctly under arbitrary chunking" do
    forall payload <- binary() do
      type = ?Z
      frame = <<type, (4 + byte_size(payload))::32, payload::binary>>
      chunks = random_chunks(frame)

      # Feed chunks progressively
      t = TestTransport.new()
      Enum.each(chunks, &TestTransport.push_in(t.sock, &1))

      case Frame.recv_frame(t) do
        {:ok, {^type, <<len::32, pl::binary>>}} ->
          (len == 4 + byte_size(pl)) and (pl == payload)
        _ ->
          false
      end
    end
  end

  defp random_chunks(bin) do
    sized s do
      # make up to s cuts (bounded) at random positions
      cutpoints = Enum.uniq(for _ <- 1..max(1, s), do: :rand.uniform(byte_size(bin) + 1)) |> Enum.sort()
      # turn cutpoints into slices
      {chunks, last} =
        Enum.reduce(cutpoints, {[], 0}, fn i, {acc, prev} ->
          if i <= byte_size(bin) do
            {acc ++ [:binary.part(bin, prev, i - prev)], i}
          else
            {acc, prev}
          end
        end)

      if last < byte_size(bin), do: chunks ++ [binary_part(bin, last, byte_size(bin) - last)], else: chunks
    end
  end
end
