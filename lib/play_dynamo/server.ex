defmodule PlayDynamo.Server do
  use GenServer

  @channel_name "fox_local_phoenix"
  @channel_url "https://c4af3793bf76b33c.mediapackage.us-west-2.amazonaws.com/out/v1/e421d95325e6477aa0f16b1bdac59de6/index.m3u8"

  # @channel_name "apple_example"
  # @channel_url "https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_ts/master.m3u8"

  alias PlayDynamo.{Channel, Segment, Variant}
  require Logger

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl GenServer
  def init(state) do
    if Mix.env() == :dev do
      Channel.create_table!()
      Variant.create_table!()
      Segment.create_table!()
    end

    Process.send_after(self(), :tick, 0)
    {:ok, state}
  end

  @impl GenServer
  def handle_call(:get_master, _from, state) do
    res = Channel.get(@channel_name)
    {:reply, res, state}
  end

  @impl GenServer
  def handle_call({:get_playlist, variant_name}, _from, state) do
    var_name = String.trim_leading(variant_name, "/")
    playlist_tags = Variant.get(@channel_name, var_name)
    segments = Segment.get_all(@channel_name, var_name)
    {:reply, "#{playlist_tags}\n#{segments}\n", state}
  end

  @impl GenServer
  def handle_info(:tick, state) do
    fetch_source()
    Process.send_after(self(), :tick, 10_000)
    {:noreply, state}
  end

  defp fetch_source do
    case HTTPoison.get(@channel_url) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        Channel.parse_and_save!([name: @channel_name, url: @channel_url], body)
        |> Enum.map(
          &Task.async(fn ->
            case HTTPoison.get(&1.variant_original_full_url) do
              {:ok, %HTTPoison.Response{status_code: 200, body: var_body}} ->
                Variant.parse_and_save!(
                  [
                    channel_name: @channel_name,
                    channel_url: @channel_url,
                    variant_name: &1.variant_name,
                    variant_url: &1.variant_original_full_url
                  ],
                  var_body
                )

                Segment.parse_and_save!(
                  [
                    channel_name: @channel_name,
                    channel_url: @channel_url,
                    variant_name: &1.variant_name,
                    variant_url: &1.variant_original_full_url
                  ],
                  var_body
                )

              err ->
                Logger.error("failed to download variant #{&1}: #{inspect(err)}")
            end
          end)
        )
        |> Enum.map(&Task.await(&1, 50_000))

      err ->
        Logger.error("failed to download master #{@channel_name}: #{inspect(err)}")
    end
  end
end
