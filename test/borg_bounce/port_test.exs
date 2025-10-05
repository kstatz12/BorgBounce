defmodule BorgBounce.PortTest do
  use ExUnit.Case, async: true

  alias BorgBounce.Port

  describe "when handling potential port data" do
    test "integer ports are unmodified" do
      assert 5432 = Port.parse(5432)
    end

    test "string ports are returned as integers" do
      assert 5432 = Port.parse("5432")
    end
  end
end
