defmodule PlayDynamo.HttpServer do
  @moduledoc false

  use Plug.Router

  alias PlayDynamo.Server
  require Logger

  plug(:match)
  plug(:dispatch)

  get "/" do
    send_resp(conn, 200, "hello")
  end

  get "/index.m3u8" do
    try do
      case GenServer.call(Server, :get_master) do
        nil ->
          send_resp(conn, 404, "not found")

        content ->
          conn
          |> put_resp_content_type("application/x-mpegURL")
          |> send_resp(200, content)
      end
    rescue
      exception ->
        Logger.error(Exception.format(:error, exception, __STACKTRACE__))
        send_resp(conn, 400, "Bad Request")
    end
  end

  match _ do
    send_resp(conn, 404, "")
  end
end
