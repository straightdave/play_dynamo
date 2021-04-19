defmodule PlayDynamo.Channel do
  @moduledoc false

  alias ExAws.Dynamo
  require Logger

  @table_name "Channels"

  @derive [Dynamo.Encodable]
  defstruct channel_name: "", variant_name: "", variant_original_full_url: "", variant_tags: []

  def create_table! do
    case Dynamo.describe_table(@table_name) |> ExAws.request() do
      {:error, {"ResourceNotFoundException", _}} ->
        Logger.info(">> Create Table: #{@table_name}")

        Dynamo.create_table(
          @table_name,
          [channel_name: :hash, variant_name: :range],
          [channel_name: :string, variant_name: :string],
          1,
          1
        )
        |> ExAws.request!()

      {:ok, _} ->
        Logger.info(">> Table #{@table_name} exists.")

      other ->
        Logger.error(">> Other errors: #{inspect(other)}")
    end
  end

  def parse_and_save!(args, body, opts \\ []) do
    chs =
      body
      |> String.split("#")
      |> Enum.map(&String.trim/1)
      |> Enum.filter(&String.starts_with?(&1, "EXT-X-STREAM-INF"))
      |> Enum.map(&String.split(&1, "\n"))
      |> Enum.map(fn [inf_tag, uri] ->
        {variant_name, original_full_url} =
          case is_uri_absolute?(uri) do
            false ->
              {uri, args |> Keyword.get(:url) |> Path.dirname() |> Path.join(uri)}

            true ->
              ext = URI.parse(uri) |> Map.get(:path) |> Path.extname()
              {"#{:erlang.phash2(uri)}#{ext}", uri}
          end

        %__MODULE__{
          channel_name: Keyword.get(args, :name),
          variant_name: variant_name,
          variant_original_full_url: original_full_url,
          variant_tags: ["#" <> inf_tag]
        }
      end)

    chs |> Enum.each(&(Dynamo.put_item(@table_name, &1, opts) |> ExAws.request!()))

    chs
  end

  def get(channel_name) do
    body =
      Dynamo.query(@table_name,
        expression_attribute_values: [desired_channel: channel_name],
        key_condition_expression: "channel_name = :desired_channel"
      )
      |> ExAws.request!()
      |> Map.get("Items")
      |> Enum.map(&Dynamo.decode_item(&1, as: __MODULE__))
      |> Enum.map(&((&1.variant_tags ++ [&1.variant_name]) |> Enum.join("\n")))
      |> Enum.join("\n")

    "#EXTM3U\n#{body}\n"
  end

  defp is_uri_absolute?(uri) do
    %URI{host: host} = URI.parse(uri)
    host != nil
  end
end
