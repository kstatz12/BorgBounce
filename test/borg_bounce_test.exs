defmodule BorgBounceTest do
  use ExUnit.Case
  doctest BorgBounce

  test "greets the world" do
    assert BorgBounce.hello() == :world
  end
end
