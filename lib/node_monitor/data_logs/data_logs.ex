NimbleCSV.define(DataLogParser, separator: " ", escape: "\"")

defmodule NodeMonitor.DataLogs do
  require Logger
  import Ecto.Query
  alias NodeMonitor.DataLogs.DataLog
  alias NodeMonitor.Nodes
  alias NodeMonitor.Repo

  @doc """
  For each live node, this will download the corresponding log from /status/recent
  and parse the lines to create per-timestamp records.
  """
  @spec load_data_logs() :: :ok
  def load_data_logs do
    Nodes.list_nodes()
    |> select([n], n.id)
    |> Repo.all()
    |> Enum.each(fn node_id ->
      path =
        "https://www.mcs.anl.gov/research/projects/waggle/downloads/status/recent/#{node_id}"
        |> NodeMonitor.Utils.download!()

      latest_log = Repo.one(from l in DataLog, where: l.node_id == ^node_id, select: max(l.timestamp))

      insert_multi =
        path
        |> File.stream!()
        |> DataLogParser.parse_stream()
        |> Enum.reduce([], fn [unix, _node_id, attr, value], acc ->
          {nix, _} = Integer.parse(unix)
          timestamp =
            Timex.from_unix(nix)
            |> Timex.to_naive_datetime()

          case is_nil(latest_log) or NaiveDateTime.compare(timestamp, latest_log) == :gt do
            false ->
              acc

            true ->
              unix_atom = :"#{unix}"

              log =
                case Keyword.get(acc, unix_atom) do
                  nil ->
                    [node_id: node_id, timestamp: timestamp]

                  found ->
                    found
                end

              log = Keyword.put(log, :"#{attr}", value)
              Keyword.put(acc, unix_atom, log)
          end
        end)
        |> Enum.reduce(Ecto.Multi.new(), fn {_, log_kw}, multi ->
          params = Enum.into(log_kw, %{})
          changeset = DataLog.changeset(%DataLog{}, params)

          case changeset.valid? do
            false ->
              multi

            true ->
              Ecto.Multi.insert(multi, "#{log_kw[:timestamp]}", changeset)
          end
        end)

      Repo.transaction(fn ->
        Repo.transaction(insert_multi)
        Repo.query!("REFRESH MATERIALIZED VIEW latest_data_logs")
      end)

      File.rm(path)
    end)
  end

  @doc "Returns a list of {node_id, num logs} where the total outage is at least an hour for less than 14 sensors over 4 hours"
  @spec detect_too_few_sensors() :: list({binary(), integer()})
  def detect_too_few_sensors do
    Nodes.list_nodes()
    |> select([n], n.id)
    |> Repo.all()
    |> Enum.reduce([], fn node_id, acc ->
      num_logs =
        (from l in DataLog)
        |> where([l], l.node_id == ^node_id)
        |> where([l], fragment("? >= now() - interval '4 hours'", l.timestamp))
        |> where([l], l.data_unique_sensors < 14)
        |> Repo.all()
        |> Enum.count()

      Logger.debug("#{node_id} #{num_logs}")

      case num_logs > 12 do  # 12 makes an hour of outage
        true ->
          acc ++ [{node_id, num_logs}]

        false ->
          acc
      end
    end)
  end

  @doc "Returns a list of {node_id, num logs} where the total outage is at least an hour for less than acceptable ratios over 4 hours"
  @spec detect_ratio_too_low() :: list({binary(), integer()})
  def detect_ratio_too_low do
    Nodes.list_nodes()
    |> select([n], n.id)
    |> Repo.all()
    |> Enum.reduce([], fn node_id, acc ->
      num_logs =
        (from l in DataLog)
        |> where([l], l.node_id == ^node_id)
        |> where([l], fragment("? >= now() - interval '4 hours'", l.timestamp))
        |> where([l], l.data_valid_ratio < 0.8)
        |> Repo.all()
        |> Enum.count()

      Logger.debug("#{node_id} #{num_logs}")

      case num_logs > 12 do  # 12 makes an hour of bad readings
        true ->
          acc ++ [{node_id, num_logs}]

        false ->
          acc
      end
    end)
  end

  @doc "Returns a list of {node_id, num logs} where the total outage is at least an hour for sufficient data over 4 hours"
  @spec detect_not_enough_data() :: list({binary(), integer()})
  def detect_not_enough_data do
    Nodes.list_nodes()
    |> select([n], n.id)
    |> Repo.all()
    |> Enum.reduce([], fn node_id, acc ->
      num_logs =
        (from l in DataLog)
        |> where([l], l.node_id == ^node_id)
        |> where([l], fragment("? >= now() - interval '4 hours'", l.timestamp))
        |> where([l], l.data_total < 100)
        |> Repo.all()
        |> Enum.count()

      Logger.debug("#{node_id} #{num_logs}")

      case num_logs > 12 do  # 12 makes an hour of insufficient data
        true ->
          acc ++ [{node_id, num_logs}]

        false ->
          acc
      end
    end)
  end

  @doc "Returns a list of node_id for nodes without any data logs"
  @spec detect_no_data_logs() :: list(binary())
  def detect_no_data_logs do
    Nodes.list_nodes()
    |> select([n], n.id)
    |> Repo.all()
    |> Enum.reduce([], fn node_id, acc ->
      num_logs =
        (from l in DataLog)
        |> where([l], l.node_id == ^node_id)
        |> Repo.all()
        |> Enum.count()

      Logger.debug("#{node_id} #{num_logs}")

      case num_logs do
        0 ->
          acc ++ [node_id]

        _ ->
          acc
      end
    end)
  end

  @doc "Returns a list of node_id for nodes without any data logs within the last 4 hours"
  @spec detect_no_recent_data_logs() :: list(binary())
  def detect_no_recent_data_logs do
    Nodes.list_nodes()
    |> select([n], n.id)
    |> Repo.all()
    |> Enum.reduce([], fn node_id, acc ->
      num_logs =
        (from l in DataLog)
        |> where([l], l.node_id == ^node_id)
        |> where([l], fragment("? >= now() - interval '4 hours'", l.timestamp))
        |> Repo.all()
        |> Enum.count()

      Logger.debug("#{node_id} #{num_logs}")

      case num_logs do
        0 ->
          acc ++ [node_id]

        _ ->
          acc
      end
    end)
  end
end
