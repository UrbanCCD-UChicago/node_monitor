NimbleCSV.define(StatusLogParser, separator: " ", escape: "\"")

defmodule NodeMonitor.StatusLogs do
  require Logger
  import Ecto.Query
  alias NodeMonitor.StatusLogs.StatusLog
  alias NodeMonitor.Nodes
  alias NodeMonitor.Repo


  @doc """
  For each live node, this will download the corresponding log from /status/log
  and parse the lines to create per-timestamp records.
  """
  @spec load_status_logs() :: :ok
  def load_status_logs do
    Nodes.list_nodes()
    |> select([n], n.id)
    |> Repo.all()
    |> Enum.each(fn node_id ->
      path =
        "https://www.mcs.anl.gov/research/projects/waggle/downloads/status/log/#{node_id}"
        |> NodeMonitor.Utils.download!()

      latest_log = Repo.one!(from l in StatusLog, where: l.node_id == ^node_id, select: max(l.timestamp))

      insert_multi =
        path
        |> File.stream!()
        |> StatusLogParser.parse_stream()
        |> Enum.reduce([], fn [unix | [_node_id | rest]], acc ->
          {nix, _} = Integer.parse(unix)
          timestamp =
            Timex.from_unix(nix)
            |> Timex.to_naive_datetime()

          case is_nil(latest_log) or NaiveDateTime.compare(timestamp, latest_log) == :gt do
            false ->
              acc

            true ->
              {attr, value} =
                case rest do
                  [metric | [device | [subsys, value]]] ->
                    {"#{metric}_#{device}_#{subsys}", value}

                  [metric | [device, value]] ->
                    {"#{metric}_#{device}", value}
                end

              value =
                case String.starts_with?(attr, "epoch") do
                  false ->
                    value

                  true ->
                    {value_as_int, _} = Integer.parse(value)

                    value_as_int
                    |> Timex.from_unix()
                    |> Timex.to_naive_datetime()
                end

              unix_atom = :"#{unix}"

              log =
                case Keyword.get(acc, unix_atom) do
                  nil -> [node_id: node_id, timestamp: timestamp]
                  found -> found
                end

              log = Keyword.put(log, :"#{attr}", value)

              Keyword.put(acc, unix_atom, log)
          end
        end)
        |> Enum.reduce(Ecto.Multi.new(), fn {_, log_kw}, multi ->
          params = Enum.into(log_kw, %{})
          changeset = StatusLog.changeset(%StatusLog{}, params)

          case changeset.valid? do
            false ->
              multi

            true ->
              Ecto.Multi.insert(multi, "#{log_kw[:timestamp]}", changeset)
          end
        end)

      Repo.transaction(fn ->
        Repo.transaction(insert_multi)
        Repo.query!("REFRESH MATERIALIZED VIEW latest_status_logs")
      end)

      File.rm(path)
    end)
  end

  @doc "Returns a list of {node_id, num logs} for logs wher the nc epoch drifts more than a minute from the real time over 4 hours"
  @spec detect_nc_time_drift() :: list({binary(), integer()})
  def detect_nc_time_drift do
    Nodes.list_nodes()
    |> select([n], n.id)
    |> Repo.all()
    |> Enum.reduce([], fn node_id, acc ->
      num_logs =
        get_recent_logs_for_node_id(node_id)
        |> where([l], fragment("? - ? > interval '1 minute'", l.timestamp, l.epoch_nc))
        |> Repo.all()
        |> Enum.count()

      Logger.debug("#{node_id} #{num_logs}")

      case num_logs do
        0 ->
          # double check that there are logs for this node
          any_logs? =
            get_recent_logs_for_node_id(node_id)
            |> Repo.all()
            |> Enum.count()

          case any_logs? do
            0 ->
              acc ++ [{node_id, nil}]

            _ ->
              acc
          end

        _ ->
          acc ++ [{node_id, num_logs}]
      end
    end)
  end

  @doc "Returns a list of {node_id, num logs} for logs wher the ep epoch drifts more than a minute from the real time over 4 hours"
  @spec detect_ep_time_drift() :: list({binary(), integer()})
  def detect_ep_time_drift do
    Nodes.list_nodes()
    |> select([n], n.id)
    |> Repo.all()
    |> Enum.reduce([], fn node_id, acc ->
      num_logs =
        get_recent_logs_for_node_id(node_id)
        |> where([l], fragment("? - ? > interval '1 minute'", l.timestamp, l.epoch_ep))
        |> Repo.all()
        |> Enum.count()

      Logger.debug("#{node_id} #{num_logs}")

      case num_logs do
        0 ->
          # double check that there are logs for this node
          any_logs? =
            get_recent_logs_for_node_id(node_id)
            |> Repo.all()
            |> Enum.count()

          case any_logs? do
            0 ->
              acc ++ [{node_id, nil}]

            _ ->
              acc
          end

        _ ->
          acc ++ [{node_id, num_logs}]
      end
    end)
  end

  @doc "Returns a list of {node_id, num logs} for logs wher the nc uptime is less than 5 minutes over 4 hours"
  @spec detect_nc_uptime_too_short() :: list({binary(), integer()})
  def detect_nc_uptime_too_short do
    Nodes.list_nodes()
    |> select([n], n.id)
    |> Repo.all()
    |> Enum.reduce([], fn node_id, acc ->
      num_logs =
        get_recent_logs_for_node_id(node_id)
        |> where([l], fragment("? < 300", l.up_nc_sys))
        |> Repo.all()
        |> Enum.count()

      Logger.debug("#{node_id} #{num_logs}")

      case num_logs do
        0 ->
          # double check that there are logs for this node
          any_logs? =
            get_recent_logs_for_node_id(node_id)
            |> Repo.all()
            |> Enum.count()

          case any_logs? do
            0 ->
              acc ++ [{node_id, nil}]

            _ ->
              acc
          end

        _ ->
          acc ++ [{node_id, num_logs}]
      end
    end)
  end

  @doc "Returns a list of {node_id, num logs} for logs wher the ep uptime is less than 5 minutes over 4 hours"
  @spec detect_ep_uptime_too_short() :: list({binary(), integer()})
  def detect_ep_uptime_too_short do
    Nodes.list_nodes()
    |> select([n], n.id)
    |> Repo.all()
    |> Enum.reduce([], fn node_id, acc ->
      num_logs =
        get_recent_logs_for_node_id(node_id)
        |> where([l], fragment("? < 300", l.up_ep_sys))
        |> Repo.all()
        |> Enum.count()

      Logger.debug("#{node_id} #{num_logs}")

      case num_logs do
        0 ->
          # double check that there are logs for this node
          any_logs? =
            get_recent_logs_for_node_id(node_id)
            |> Repo.all()
            |> Enum.count()

          case any_logs? do
            0 ->
              acc ++ [{node_id, nil}]

            _ ->
              acc
          end

        _ ->
          acc ++ [{node_id, num_logs}]
      end
    end)
  end

  @doc "Returns a list of {node_id, num logs} for logs wher the wm uptime is less than 5 minutes over 4 hours"
  @spec detect_wm_uptime_too_short() :: list({binary(), integer()})
  def detect_wm_uptime_too_short do
    Nodes.list_nodes()
    |> select([n], n.id)
    |> Repo.all()
    |> Enum.reduce([], fn node_id, acc ->
      num_logs =
        get_recent_logs_for_node_id(node_id)
        |> where([l], fragment("? < 300", l.up_wm_sys))
        |> Repo.all()
        |> Enum.count()

      Logger.debug("#{node_id} #{num_logs}")

      case num_logs do
        0 ->
          # double check that there are logs for this node
          any_logs? =
            get_recent_logs_for_node_id(node_id)
            |> Repo.all()
            |> Enum.count()

          case any_logs? do
            0 ->
              acc ++ [{node_id, nil}]

            _ ->
              acc
          end

        _ ->
          acc ++ [{node_id, num_logs}]
      end
    end)
  end

  @doc "Returns a list of {node_id, num logs} for logs wher the cs uptime is less than 5 minutes over 4 hours"
  @spec detect_cs_uptime_too_short() :: list({binary(), integer()})
  def detect_cs_uptime_too_short do
    Nodes.list_nodes()
    |> select([n], n.id)
    |> Repo.all()
    |> Enum.reduce([], fn node_id, acc ->
      num_logs =
        get_recent_logs_for_node_id(node_id)
        |> where([l], fragment("? < 300", l.up_nc_cs))
        |> Repo.all()
        |> Enum.count()

      Logger.debug("#{node_id} #{num_logs}")

      case num_logs do
        0 ->
          # double check that there are logs for this node
          any_logs? =
            get_recent_logs_for_node_id(node_id)
            |> Repo.all()
            |> Enum.count()

          case any_logs? do
            0 ->
              acc ++ [{node_id, nil}]

            _ ->
              acc
          end

        _ ->
          acc ++ [{node_id, num_logs}]
      end
    end)
  end

  @doc "Returns a list of {node_id, num logs} for logs wher the bcam uptime is less than 5 minutes over 4 hours"
  @spec detect_bcam_uptime_too_short() :: list({binary(), integer()})
  def detect_bcam_uptime_too_short do
    Nodes.list_nodes()
    |> select([n], n.id)
    |> Repo.all()
    |> Enum.reduce([], fn node_id, acc ->
      num_logs =
        get_recent_logs_for_node_id(node_id)
        |> where([l], fragment("? < 300", l.up_ep_bcam) or is_nil(l.up_ep_bcam))
        |> Repo.all()
        |> Enum.count()

      Logger.debug("#{node_id} #{num_logs}")

      case num_logs do
        0 ->
          # double check that there are logs for this node
          any_logs? =
            get_recent_logs_for_node_id(node_id)
            |> Repo.all()
            |> Enum.count()

          case any_logs? do
            0 ->
              acc ++ [{node_id, nil}]

            _ ->
              acc
          end

        _ ->
          acc ++ [{node_id, num_logs}]
      end
    end)
  end

  @doc "Returns a list of {node_id, num logs} for logs wher the tcam uptime is less than 5 minutes over 4 hours"
  @spec detect_tcam_uptime_too_short() :: list({binary(), integer()})
  def detect_tcam_uptime_too_short do
    Nodes.list_nodes()
    |> select([n], n.id)
    |> Repo.all()
    |> Enum.reduce([], fn node_id, acc ->
      num_logs =
        get_recent_logs_for_node_id(node_id)
        |> where([l], fragment("? < 300", l.up_ep_tcam) or is_nil(l.up_ep_tcam))
        |> Repo.all()
        |> Enum.count()

      Logger.debug("#{node_id} #{num_logs}")

      case num_logs do
        0 ->
          # double check that there are logs for this node
          any_logs? =
            get_recent_logs_for_node_id(node_id)
            |> Repo.all()
            |> Enum.count()

          case any_logs? do
            0 ->
              acc ++ [{node_id, nil}]

            _ ->
              acc
          end

        _ ->
          acc ++ [{node_id, num_logs}]
      end
    end)
  end

  @doc "Returns a list of {node_id, num logs} for logs wher the mic uptime is less than 5 minutes over 4 hours"
  @spec detect_mic_uptime_too_short() :: list({binary(), integer()})
  def detect_mic_uptime_too_short do
    Nodes.list_nodes()
    |> select([n], n.id)
    |> Repo.all()
    |> Enum.reduce([], fn node_id, acc ->
      num_logs =
        get_recent_logs_for_node_id(node_id)
        |> where([l], fragment("? < 300", l.up_ep_mic) or is_nil(l.up_ep_mic))
        |> Repo.all()
        |> Enum.count()

      Logger.debug("#{node_id} #{num_logs}")

      case num_logs do
        0 ->
          # double check that there are logs for this node
          any_logs? =
            get_recent_logs_for_node_id(node_id)
            |> Repo.all()
            |> Enum.count()

          case any_logs? do
            0 ->
              acc ++ [{node_id, nil}]

            _ ->
              acc
          end

        _ ->
          acc ++ [{node_id, num_logs}]
      end
    end)
  end

  @doc "Returns a list of node_id for nodes without any status logs"
  @spec detect_no_status_logs() :: list(binary())
  def detect_no_status_logs do
    Nodes.list_nodes()
    |> select([n], n.id)
    |> Repo.all()
    |> Enum.reduce([], fn node_id, acc ->
      num_logs =
        (from l in StatusLog)
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

  @doc "Returns a list of node_id for nodes without any status logs within the last 4 hours"
  @spec detect_no_recent_status_logs() :: list(binary())
  def detect_no_recent_status_logs do
    Nodes.list_nodes()
    |> select([n], n.id)
    |> Repo.all()
    |> Enum.reduce([], fn node_id, acc ->
      num_logs =
        get_recent_logs_for_node_id(node_id)
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

  # helpers

  defp get_recent_logs_for_node_id(node_id) do
    (from l in StatusLog)
    |> where([l], l.node_id == ^node_id)
    |> where([l], fragment("? >= now() - interval '4 hours'", l.timestamp))
  end
end
