defmodule PlayDynamo.Segment do
  @moduledoc false

  alias ExAws.Dynamo
  require Logger

  @table_name "Segments"

  @segment_tags [
    "#EXTINF",
    "#EXT-X-BYTERANGE",
    "#EXT-X-DISCONTINUITY",
    "#EXT-X-KEY",
    "#EXT-X-MAP",
    "#EXT-X-PROGRAM-DATE-TIME",
    "#EXT-X-DATERANGE",
    "#EXT-X-BITRATE",
    "#EXT-X-GAP",
    "#EXT-X-PART"
  ]

  @derive [ExAws.Dynamo.Encodable]
  defstruct channel_variant_name: "",
            segment_name: "",
            time_seq: "",
            segment_tags: [],
            segment_original_full_url: ""

  def create_table! do
    case Dynamo.describe_table(@table_name) |> ExAws.request() do
      {:error, {"ResourceNotFoundException", _}} ->
        Logger.info(">> Create Table: #{@table_name}")

        Dynamo.create_table(
          @table_name,
          [channel_variant_name: :hash, segment_name: :range],
          [channel_variant_name: :string, segment_name: :string],
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
    now = DateTime.utc_now() |> DateTime.to_unix()
    channel_name = Keyword.get(args, :channel_name)
    variant_name = Keyword.get(args, :variant_name)
    base_url = Keyword.get(args, :channel_url) |> Path.dirname()

    segments =
      body
      |> String.split("\n")
      |> Enum.map(&String.trim/1)
      |> Enum.filter(&(&1 != ""))
      |> Enum.chunk_while(
        [],
        fn ele, acc ->
          cond do
            String.starts_with?(ele, @segment_tags) ->
              {:cont, [ele | acc]}

            !String.starts_with?(ele, "#") ->
              {:cont, Enum.reverse([ele | acc]), []}

            true ->
              {:cont, []}
          end
        end,
        fn
          acc -> {:cont, acc}
        end
      )
      |> Enum.with_index()
      |> Enum.map(fn {chunk, index} ->
        uri = chunk |> Enum.filter(&(!String.starts_with?(&1, "#"))) |> Enum.take(1) |> Enum.at(0)

        {segment_name, original_full_url} =
          case is_uri_absolute?(uri) do
            false ->
              {uri, Path.join(base_url, uri)}

            true ->
              ext = URI.parse(uri) |> Map.get(:path) |> Path.extname()
              {"#{:erlang.phash2(uri)}#{ext}", uri}
          end

        %__MODULE__{
          channel_variant_name: "#{channel_name}|#{variant_name}",
          segment_name: segment_name,
          time_seq: "#{now}_#{index |> Integer.to_string() |> String.pad_leading(3, "0")}",
          segment_original_full_url: original_full_url,
          segment_tags: chunk |> Enum.filter(&String.starts_with?(&1, "#"))
        }
      end)

    Enum.each(segments, fn segment ->
      Dynamo.put_item(@table_name, segment, opts) |> ExAws.request!()
    end)
  end

  defp is_uri_absolute?(uri) do
    %URI{host: host} = URI.parse(uri)
    host != nil
  end
end
