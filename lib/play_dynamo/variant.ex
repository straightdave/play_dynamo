defmodule PlayDynamo.Variant do
  @moduledoc false

  alias ExAws.Dynamo
  require Logger

  @table_name "Variants"

  @playlist_tags [
    "#EXTM3U",
    "#EXT-X-VERSION",
    "#EXT-X-TARGETDURATION",
    "#EXT-X-MEDIA-SEQUENCE",
    "#EXT-X-DISCONTINUITY-SEQUENCE",
    "#EXT-X-ENDLIST",
    "#EXT-X-PLAYLIST-TYPE",
    "#EXT-X-I-FRAMES-ONLY",
    "#EXT-X-INDEPENDENT-SEGMENTS",
    "#EXT-X-START"
  ]

  @derive [ExAws.Dynamo.Encodable]
  defstruct channel_name: "",
            variant_name: "",
            variant_type: "",
            tags: []

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
    tags =
      body
      |> String.split("\n")
      |> Enum.map(&String.trim/1)
      |> Enum.filter(&String.starts_with?(&1, @playlist_tags))

    type =
      tags
      |> Enum.find("", &String.starts_with?(&1, "#EXT-X-PLAYLIST-TYPE"))
      |> String.trim_leading("#EXT-X-PLAYLIST-TYPE:")

    obj = %__MODULE__{
      channel_name: Keyword.get(args, :channel_name),
      variant_name: Keyword.get(args, :variant_name),
      variant_type: type,
      tags: tags
    }

    Dynamo.put_item(@table_name, obj, opts) |> ExAws.request!()
  end

  # def get(channel_name) do
  #   body =
  #     Dynamo.query(@table_name,
  #       expression_attribute_values: [desired_channel: channel_name],
  #       key_condition_expression: "channel_name = :desired_channel"
  #     )
  #     |> ExAws.request!()
  #     |> Map.get("Items")
  #     |> Enum.map(&Dynamo.decode_item(&1, as: __MODULE__))
  #     |> Enum.map(&((&1.variant_tags ++ [&1.variant_full_url]) |> Enum.join("\n")))
  #     |> Enum.join("\n")

  #   "#EXTM3U\n#{body}\n"
  # end
end
