defmodule NodeMonitor.BootEvents do
  require Logger
  import Ecto.Query
  alias NimbleCSV.RFC4180, as: CSV
  alias NodeMonitor.BootEvents.{BootEvent, LatestBootEvent}
  alias NodeMonitor.Repo
  alias NodeMonitor.Nodes

  @doc "Dowloads the /status/http-events.csv file and loads its contents into the database"
  @spec load_boot_events() :: :ok
  def load_boot_events do
    path =
      "https://www.mcs.anl.gov/research/projects/waggle/downloads/status/http-events.csv"
      |> NodeMonitor.Utils.download!()

    latest_event = Repo.one!(from b in BootEvent, select: max(b.timestamp))

    multi_insert =
      path
      |> File.stream!()
      |> CSV.parse_stream()
      |> Enum.reduce(Ecto.Multi.new(), fn [ts, node_id, bid, media], multi ->
        timestamp = Timex.parse!(ts, "{ISO:Extended}")

        case is_nil(latest_event) or NaiveDateTime.compare(timestamp, latest_event) == :gt do
          false ->
            multi

          true ->
            Ecto.Multi.insert(
              multi,
              "#{node_id}_#{ts}_#{bid}",
              BootEvent.changeset(%BootEvent{}, %{node_id: node_id, timestamp: timestamp, boot_id: bid, media: media})
            )
        end
      end)

    Repo.transaction(fn ->
      Repo.transaction(multi_insert)
      Repo.query!("REFRESH MATERIALIZED VIEW latest_boot_events")
    end, timeout: :infinity)

    File.rm!(path)
  end

  @doc "Returns a list of {node_id, count reboots} where the count is > 2 within the last 4 hours"
  @spec detect_too_many_reboots() :: list({binary(), integer()})
  def detect_too_many_reboots do
    Nodes.list_nodes()
    |> select([n], n.id)
    |> Repo.all()
    |> Enum.reduce([], fn node_id, acc ->
      case Repo.one(from e in LatestBootEvent, where: e.node_id == ^node_id) do
        nil ->
          acc

        latest ->
          num_reboots =
            (from e in BootEvent)
            |> where([e], e.node_id == ^node_id)
            |> where([e], fragment("? >= now() - interval '4 hours'", e.timestamp))
            |> where([e], e.boot_id != ^latest.boot_id)
            |> Repo.all()
            |> Enum.count()

          Logger.debug("#{node_id} #{num_reboots}")

          if num_reboots > 1 do
            acc ++ [{node_id, num_reboots}]
          else
            acc
          end
      end
    end)
  end

  @doc "Returns a list of {node_id, count sd, count mmc} where both counts are > 1 within the last 4 hours"
  @spec detect_too_many_media_changes() :: list({binary(), integer(), integer()})
  def detect_too_many_media_changes do
    Nodes.list_nodes()
    |> select([n], n.id)
    |> Repo.all()
    |> Enum.reduce([], fn node_id, acc ->
      media =
        (from e in BootEvent)
        |> where([e], e.node_id == ^node_id)
        |> where([e], fragment("? >= now() - interval '4 hours'", e.timestamp))
        |> order_by(desc: :timestamp)
        |> select([e], e.media)
        |> Repo.all()

      num_sd =
        media
        |> Enum.filter(& &1 == "sd")
        |> Enum.count()

      num_mmc =
        media
        |> Enum.filter(& &1 == "mmc")
        |> Enum.count()

      Logger.debug("#{node_id} #{num_sd} #{num_mmc}")

      if num_sd > 1 and num_mmc > 1 do
        acc ++ [{node_id, num_sd, num_mmc}]
      else
        acc
      end
    end)
  end

  @doc "Returns a list of node_id for nodes that have never posted a boot event"
  @spec detect_no_boot_events() :: list(binary())
  def detect_no_boot_events do
    Nodes.list_nodes()
    |> select([n], n.id)
    |> Repo.all()
    |> Enum.reduce([], fn node_id, acc ->
      num_events =
        Repo.all(from e in BootEvent, where: e.node_id == ^node_id)
        |> Enum.count()

      Logger.debug("#{node_id} #{num_events}")

      case num_events do
        0 ->
          acc ++ [node_id]

        _ ->
          acc
      end
    end)
  end

  @doc "Returns a list of node_id for nodes that don't have a recent boot event"
  @spec detect_no_recent_boot_events() :: list(binary())
  def detect_no_recent_boot_events do
    Nodes.list_nodes()
    |> select([n], n.id)
    |> Repo.all()
    |> Enum.reduce([], fn node_id, acc ->
      num_events =
        Repo.all(
          (from e in BootEvent)
          |> where([e], e.node_id == ^node_id)
          |> where([e], fragment("? >= now() - interval '4 hours'", e.timestamp))
        )
        |> Enum.count()

      Logger.debug("#{node_id} #{num_events}")

      case num_events do
        0 ->
          acc ++ [node_id]

        _ ->
          acc
      end
    end)
  end
end
