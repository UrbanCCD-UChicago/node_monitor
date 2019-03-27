defmodule NodeMonitor.Nodes do
  require Logger
  import Ecto.Query
  alias NimbleCSV.RFC4180, as: CSV
  alias NodeMonitor.Nodes.Node
  alias NodeMonitor.Repo

  @doc "Creates a base queryset for live nodes"
  @spec list_nodes() :: Ecto.Queryable.t()
  def list_nodes, do: from n in Node, where: is_nil(n.end_timestamp)

  @doc """
  Downloads all the projects' recent tarballs and processes their
  nodes.csv files to create/update nodes in the database.
  """
  @spec load_recent_tarballs() :: :ok
  def load_recent_tarballs do
    tarball_paths =
      # ~w| NUCWR-MUGS GASP Waggle_Dronebears LinkNYC AoT_Seattle AoT_Portland AoT_NIU AoT_Syracuse AoT_Detroit Waggle_Others AoT_UNC AoT_UW AoT_Chicago AoT_Stanford AoT_Denver Waggle_Tokyo |
      ~w| AoT_Chicago |
      |> Enum.map(&("https://www.mcs.anl.gov/research/projects/waggle/downloads/datasets/#{&1}.complete.recent.tar"))
      |> Enum.map(&NodeMonitor.Utils.download!/1)

    csv_paths =
      tarball_paths
      |> Enum.map(&deflate_tarball/1)

    csv_paths
    |> Enum.each(fn path ->
      Logger.info("Ripping #{path}")
      path
      |> File.stream!()
      |> CSV.parse_stream()
      |> Stream.map(fn [node_id ,_ ,vsn ,address ,lat ,lon ,description ,start_ts ,end_ts] ->
        lat = parse_lonlat(lat)
        lon = parse_lonlat(lon)
        start_timestamp = parse_awful_timestamp(start_ts)
        end_timestamp = parse_awful_timestamp(end_ts)

        case Repo.get(Node, node_id) do
          nil ->
            %Node{id: node_id}
            |> Node.changeset(%{
              vsn: vsn,
              address: address,
              lon: lon,
              lat: lat,
              description: description,
              start_timestamp: start_timestamp,
              end_timestamp: end_timestamp
            })
            |> Repo.insert!()

          node ->
            node
            |> Node.changeset(%{
              vsn: vsn,
              address: address,
              lon: lon,
              lat: lat,
              description: description,
              start_timestamp: start_timestamp,
              end_timestamp: end_timestamp
            })
            |> Repo.update!()
        end
      end)
      |> Stream.run()
    end)

    tarball_paths
    |> Enum.each(&File.rm!/1)

    csv_paths
    |> Enum.map(&Path.dirname/1)
    |> Enum.each(&File.rm_rf!/1)
  end

  # helpers

  defp deflate_tarball(path) do
    parent_dirname = Path.dirname(path)

    # decompress the tarball
    Logger.info("decompressing tarball #{path}")
    {_, 0} = System.cmd("tar", ["xf", path, "-C", parent_dirname])

    # get the path to the nodes csv
    {paths, 0} = System.cmd("tar", ["tf", path])
    Logger.debug("extracted paths: #{inspect(paths)}")

    ext_dirname =
      String.split(paths, "\n")
      |> List.first()
    ext_dirname = Path.join([parent_dirname, ext_dirname])
    Logger.debug("extracted dirname: #{ext_dirname}")

    {paths, 0} = System.cmd("ls", [ext_dirname])
    Logger.debug("ls ext dirname: #{inspect(paths)}")

    nodes_csv = Path.join([ext_dirname, "nodes.csv"])
    Logger.info("nodes csv path: #{nodes_csv}")

    nodes_csv
  end

  defp parse_awful_timestamp(""), do: nil
  defp parse_awful_timestamp(value), do: Timex.parse!(value, "%Y/%m/%d %H:%M:%S", :strftime)

  defp parse_lonlat("0.0"), do: nil
  defp parse_lonlat(value), do: value
end
