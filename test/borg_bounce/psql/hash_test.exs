defmodule BorgBounce.Psql.HashTest do
  use ExUnit.Case, async: true

  alias BorgBounce.Psql.{Server, Hash}

  describe "When Hashing A Server Definition" do
    test "Hashing a Server Results in A Key" do
      server = %Server{
        host: "localhost",
        port: "5432",
        user: "Postgres",
        database: "postgre",
        password: "Postgres"
      }

      hash = Hash.compute(server)
      assert hash != nil
    end

    test "Hashing 2 Servers With Different Passwords Results in Equal Hashes" do
      server_one = %Server{
        host: "localhost",
        port: "5432",
        user: "Postgres",
        database: "postgre",
        password: "Postgres"
      }

      hash_one = Hash.compute(server_one)

      server_two = %Server{
        host: "localhost",
        port: "5432",
        user: "Postgres",
        database: "postgre",
        password: "Postgres2"
      }

      hash_two = Hash.compute(server_two)
      assert hash_one == hash_two
    end

    test "Hashing 2 Servers with Different users Result in NonEqual Hashes" do
      server_one = %Server{
        host: "localhost",
        port: "5432",
        user: "Postgres",
        database: "postgre",
        password: "Postgres"
      }

      hash_one = Hash.compute(server_one)

      server_two = %Server{
        host: "localhost",
        port: "5432",
        user: "Postgres2",
        database: "postgre",
        password: "Postgres2"
      }

      hash_two = Hash.compute(server_two)
      assert hash_one != hash_two
    end
  end
end
