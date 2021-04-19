defmodule PlayDynamo.User do
  @derive [ExAws.Dynamo.Encodable]
  defstruct [:email, :name, :age, :admin]
end
