defmodule PlayDynamo.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      PlayDynamo.Server,
      {Plug.Cowboy, scheme: :http, plug: PlayDynamo.HttpServer, options: [port: 8080]}
    ]

    opts = [strategy: :one_for_one, name: PlayDynamo.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
