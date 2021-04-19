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
      case GenServer.call(Server, :get_master, 10_000) do
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
    try do
      ext =
        conn.request_path |> URI.parse() |> Map.get(:path) |> Path.extname() |> String.downcase()

      if String.starts_with?(ext, ".m3u") do
        case GenServer.call(Server, {:get_playlist, conn.request_path}, 10_000) do
          nil ->
            send_resp(conn, 404, "not found")

          content ->
            conn
            |> put_resp_content_type("application/x-mpegURL")
            |> send_resp(200, content)
        end
      else
        send_resp(conn, 404, "unknown request to #{conn.request_path}")
      end
    rescue
      exception ->
        Logger.error(Exception.format(:error, exception, __STACKTRACE__))
        send_resp(conn, 400, "Bad Request")
    end
  end
end
