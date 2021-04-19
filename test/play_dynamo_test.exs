defmodule PlayDynamoTest do
  use ExUnit.Case
  doctest PlayDynamo

  alias ExAws.Dynamo
  alias PlayDynamo.User

  test "greets the world" do
    case Dynamo.describe_table("Users2") |> ExAws.request() do
      {:error, {"ResourceNotFoundException", _}} ->
        IO.puts(">> Create New Table")
        # Create a provisioned users table with a primary key of email [String]
        # and 1 unit of read and write capacity
        Dynamo.create_table("Users2", "email", %{email: :string}, 1, 1)
        |> ExAws.request!()

      {:ok, res} ->
        IO.puts(">> test table OK: #{inspect(res)}")

      other ->
        IO.puts(">> other errors: #{inspect(other)}")
    end

    user = %User{email: "bubbadddd@foo.com", name: "Bubba1", age: 23, admin: false}
    user1 = %User{email: "bubbadddd111111@foo.com", name: "Bubba111", age: 23, admin: false}
    Dynamo.put_item("Users2", user) |> ExAws.request!()
    Dynamo.put_item("Users2", user1) |> ExAws.request!()

    result =
      Dynamo.get_item("Users2", %{email: user.email})
      |> ExAws.request!()
      |> Dynamo.decode_item(as: User)

    IO.puts(">> get user = #{inspect(result)}")

    result = Dynamo.scan("Users2") |> ExAws.request!()
    IO.puts(">> scan users = #{inspect(result)}")
  end
end
