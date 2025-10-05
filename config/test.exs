import Config

config :borg_bounce, :psql_servers, [
  %{host: "localhost", port: "5432", user: "Postgres", database: "postgres", password: "Password"}
]
