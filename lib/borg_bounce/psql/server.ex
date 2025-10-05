defmodule BorgBounce.Psql.Server do
  @moduledoc """
    server definition
  """

  @type t :: %__MODULE__{
          host: String.t(),
          port: String.t(),
          user: String.t(),
          database: String.t(),
          password: String.t(),
          ssl: :disable | :prefer | :require,
          ssl_opts: Keyword.t(),
          connect_timeout: pos_integer(),
          io_timeout: pos_integer()
        }

  @enforce_keys [:host, :port, :user, :database]
  defstruct host: nil,
            port: nil,
            user: nil,
            database: nil,
            password: nil,
            ssl: :prefer,
            ssl_opts: []
end
