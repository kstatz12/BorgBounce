defmodule BorgBounce.Psql.Connection do
  @type t :: %__MODULE__{
          socket: term(),
          transport: term(),
          state: :pre_ssl | :pre_startup | :ready,
          buffer: binary()
        }

  defstruct socket: nil, transport: nil, state: nil, buffer: <<>>
end
