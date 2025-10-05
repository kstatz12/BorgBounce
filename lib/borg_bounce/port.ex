defmodule BorgBounce.Port do
  @moduledoc """
  port helpers
  """
  def parse(port) when is_integer(port), do: port
  def parse(port), do: String.to_integer(port)
end
