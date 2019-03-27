defmodule NodeMonitorWeb.NodesController do
  use NodeMonitorWeb, :controller
  require Logger
  import Ecto.Query
  alias NodeMonitor.{Repo, Nodes, BootEvents, DataLogs, StatusLogs}
  alias NodeMonitor.Nodes.Node
  alias NodeMonitor.BootEvents.{BootEvent, LatestBootEvent}
  alias NodeMonitor.DataLogs.{DataLog, LatestDataLog}
  alias NodeMonitor.StatusLogs.{StatusLog, LatestStatusLog}


  @doc false
  def overview(conn, _) do
    count_all_nodes =
      Nodes.list_nodes()
      |> Repo.all()
      |> Enum.count()

    # boot events
    too_many_reboots = BootEvents.detect_too_many_reboots()
    too_many_media_changes = BootEvents.detect_too_many_media_changes()
    no_boot_events = BootEvents.detect_no_boot_events()
    no_recent_boot_events = BootEvents.detect_no_recent_boot_events()

    # data logs
    too_few_sensors = DataLogs.detect_too_few_sensors()
    ratio_too_low = DataLogs.detect_ratio_too_low()
    not_enough_data = DataLogs.detect_not_enough_data()
    no_data_logs = DataLogs.detect_no_data_logs()
    no_recent_data_logs = DataLogs.detect_no_recent_data_logs()

    # status logs
    nc_time_drift = StatusLogs.detect_nc_time_drift()
    ep_time_drift = StatusLogs.detect_ep_time_drift()
    nc_uptime_too_short = StatusLogs.detect_nc_uptime_too_short()
    ep_uptime_too_short = StatusLogs.detect_ep_uptime_too_short()
    wm_uptime_too_short = StatusLogs.detect_wm_uptime_too_short()
    cs_uptime_too_short = StatusLogs.detect_cs_uptime_too_short()
    bcam_uptime_too_short = StatusLogs.detect_bcam_uptime_too_short()
    tcam_uptime_too_short = StatusLogs.detect_tcam_uptime_too_short()
    mic_uptime_too_short = StatusLogs.detect_mic_uptime_too_short()
    no_status_logs = StatusLogs.detect_no_status_logs()
    no_recent_status_logs = StatusLogs.detect_no_recent_status_logs()

    render conn, "overview.html",
      count_all_nodes: count_all_nodes,
      too_many_reboots: too_many_reboots,
      too_many_media_changes: too_many_media_changes,
      no_boot_events: no_boot_events,
      no_recent_boot_events: no_recent_boot_events,
      too_few_sensors: too_few_sensors,
      ratio_too_low: ratio_too_low,
      not_enough_data: not_enough_data,
      no_data_logs: no_data_logs,
      no_recent_data_logs: no_recent_data_logs,
      nc_time_drift: nc_time_drift,
      ep_time_drift: ep_time_drift,
      nc_uptime_too_short: nc_uptime_too_short,
      ep_uptime_too_short: ep_uptime_too_short,
      wm_uptime_too_short: wm_uptime_too_short,
      cs_uptime_too_short: cs_uptime_too_short,
      bcam_uptime_too_short: bcam_uptime_too_short,
      tcam_uptime_too_short: tcam_uptime_too_short,
      mic_uptime_too_short: mic_uptime_too_short,
      no_status_logs: no_status_logs,
      no_recent_status_logs: no_recent_status_logs
  end

  @doc false
  def all_nodes(conn, _) do
    %Postgrex.Result{columns: cols, rows: rows} =
      Repo.query! """
      SELECT
        n.id, n.vsn, n.address, n.lat, n.lon, n.description,
        b.timestamp bts, d.timestamp dts, s.timestamp sts
      FROM nodes n
        LEFT JOIN latest_boot_events b ON n.id = b.node_id
        LEFT JOIN latest_data_logs d ON n.id = d.node_id
        LEFT JOIN latest_status_logs s ON n.id = s.node_id
      WHERE
        n.end_timestamp IS NULL
      """

    cols =
      cols
      |> Enum.map(&String.to_atom/1)

    nodes =
      rows
      |> Enum.map(& Enum.zip(cols, &1))
      |> Enum.map(& Enum.into(&1, %{}))

    count = Enum.count(nodes)

    render conn, "index.html",
      nodes: nodes,
      count: count
  end

  @doc false
  def map(conn, _) do
    all_nodes =
      Nodes.list_nodes()
      |> Repo.all()

    # boot events
    no_recent_boot_events = BootEvents.detect_no_recent_boot_events() |> MapSet.new()

    # data logs
    too_few_sensors = DataLogs.detect_too_few_sensors() |> Enum.map(&Tuple.to_list/1) |> Enum.map(& Enum.at(&1, 0)) |> MapSet.new()

    # status logs
    nc_time_drift = StatusLogs.detect_nc_time_drift() |> Enum.map(&Tuple.to_list/1) |> Enum.map(& Enum.at(&1, 0)) |> MapSet.new()
    ep_time_drift = StatusLogs.detect_ep_time_drift() |> Enum.map(&Tuple.to_list/1) |> Enum.map(& Enum.at(&1, 0)) |> MapSet.new()
    bcam_uptime_too_short = StatusLogs.detect_bcam_uptime_too_short() |> Enum.map(&Tuple.to_list/1) |> Enum.map(& Enum.at(&1, 0)) |> MapSet.new()
    tcam_uptime_too_short = StatusLogs.detect_tcam_uptime_too_short() |> Enum.map(&Tuple.to_list/1) |> Enum.map(& Enum.at(&1, 0)) |> MapSet.new()
    mic_uptime_too_short = StatusLogs.detect_mic_uptime_too_short() |> Enum.map(&Tuple.to_list/1) |> Enum.map(& Enum.at(&1, 0)) |> MapSet.new()

    nodes =
      all_nodes
      |> Enum.map(fn node ->
        {score, missing_boot_events?} =
          if MapSet.member?(no_recent_boot_events, node.id) do
            {1, true}
          else
            {0, false}
          end

        {score, missing_sensors?} =
          if MapSet.member?(too_few_sensors, node.id) do
            {score + 1, true}
          else
            {score, false}
          end

        {score, nc_drift?} =
          if MapSet.member?(nc_time_drift, node.id) do
            {score + 1, true}
          else
            {score, false}
          end

        {score, ep_drift?} =
          if MapSet.member?(ep_time_drift, node.id) do
            {score + 1, true}
          else
            {score, false}
          end

        {score, no_bcam?} =
          if MapSet.member?(bcam_uptime_too_short, node.id) do
            {score + 1, true}
          else
            {score, false}
          end

        {score, no_tcam?} =
          if MapSet.member?(tcam_uptime_too_short, node.id) do
            {score + 1, true}
          else
            {score, false}
          end

        {score, no_mic?} =
          if MapSet.member?(mic_uptime_too_short, node.id) do
            {score + 1, true}
          else
            {score, false}
          end

        color =
          cond do
            score >= 5 -> "red"
            score >= 4 -> "orange"
            score >= 3 -> "yellow"
            score >= 2 -> "blue"
            true -> "green"
          end

        Logger.debug("#{node.id} #{score} #{color}")

        %{
          type: "Feature",
          geometry: %{
            type: "Point",
            coordinates: [node.lon, node.lat]
          },
          properties: %{
            # node metadata
            id: node.id,
            vsn: node.vsn,
            address: node.address,
            description: node.description,
            # computed qualities
            missing_boot_info: missing_boot_events?,
            missing_sensors: missing_sensors?,
            nc_drift: nc_drift?,
            ep_drift: ep_drift?,
            no_bcam: no_bcam?,
            no_tcam: no_tcam?,
            no_mic: no_mic?,
            # pin color
            color: color
          }
        }
      end)
      |> Jason.encode!()

    render conn, "map.html",
      nodes: nodes
  end

  @doc false
  def show(conn, %{"id" => id}) do
    node = Repo.get!(Node, id)

    # data logs
    latest_data_log =
      (from l in LatestDataLog)
      |> where([l], l.node_id == ^id)
      |> Repo.one()

    data_logs =
      (from l in DataLog)
      |> where([l], l.node_id == ^id)
      |> order_by([asc: :timestamp])
      |> Repo.all()

    data_log_labels =
      data_logs
      |> Enum.map(& &1.timestamp)
      |> Enum.map(&NaiveDateTime.to_string/1)
      |> Jason.encode!()

    data_log_sensors =
      data_logs
      |> Enum.map(& &1.data_unique_sensors)
      |> Jason.encode!()

    data_log_ratio =
      data_logs
      |> Enum.map(& &1.data_valid_ratio)
      |> Jason.encode!()

    data_log_valid =
      data_logs
      |> Enum.map(& &1.data_valid_total)
      |> Jason.encode!()

    # status logs
    latest_status_log =
      (from l in LatestStatusLog)
      |> where([l], l.node_id == ^id)
      |> Repo.one()

    status_logs =
      (from l in StatusLog)
      |> where([l], l.node_id == ^id)
      |> order_by([asc: :timestamp])
      |> Repo.all()

    status_log_labels =
      status_logs
      |> Enum.map(& &1.timestamp)
      |> Enum.map(&NaiveDateTime.to_string/1)
      |> Jason.encode!()

    nc_uptime =
      status_logs
      |> Enum.map(& &1.up_nc_sys)
      |> Jason.encode!()

    ep_uptime =
      status_logs
      |> Enum.map(& &1.up_ep_sys)
      |> Jason.encode!()

    wm_uptime =
      status_logs
      |> Enum.map(& &1.up_wm_sys)
      |> Jason.encode!()

    cs_uptime =
      status_logs
      |> Enum.map(& &1.up_nc_cs)
      |> Jason.encode!()

    bcam_uptime =
      status_logs
      |> Enum.map(& &1.up_ep_bcam)
      |> Jason.encode!()

    tcam_uptime =
      status_logs
      |> Enum.map(& &1.up_ep_tcam)
      |> Jason.encode!()

    mic_uptime =
      status_logs
      |> Enum.map(& &1.up_ep_mic)
      |> Jason.encode!()

    nc_fail_counts =
      status_logs
      |> Enum.map(& &1.fc_nc)
      |> Jason.encode!()

    ep_fail_counts =
      status_logs
      |> Enum.map(& &1.fc_ep)
      |> Jason.encode!()

    cs_fail_counts =
      status_logs
      |> Enum.map(& &1.fc_cs)
      |> Jason.encode!()

    nc_current_usage =
      status_logs
      |> Enum.map(& &1.cu_nc)
      |> Jason.encode!()

    ep_current_usage =
      status_logs
      |> Enum.map(& &1.cu_ep)
      |> Jason.encode!()

    wm_current_usage =
      status_logs
      |> Enum.map(& &1.cu_wm)
      |> Jason.encode!()

    cs_current_usage =
      status_logs
      |> Enum.map(& &1.cu_cs)
      |> Jason.encode!()

    # boot events
    latest_boot_event =
      (from b in LatestBootEvent)
      |> where([b], b.node_id == ^id)
      |> Repo.one()

    boot_events =
      (from b in BootEvent)
      |> where([b], b.node_id == ^id)
      |> order_by([asc: :timestamp])
      |> Repo.all()

    render conn, "show.html",
      node: node,
      latest_data_log: latest_data_log,
      data_logs: data_logs,
      data_log_labels: data_log_labels,
      data_log_sensors: data_log_sensors,
      data_log_ratio: data_log_ratio,
      data_log_valid: data_log_valid,
      latest_status_log: latest_status_log,
      status_logs: status_logs,
      status_log_labels: status_log_labels,
      nc_uptime: nc_uptime,
      ep_uptime: ep_uptime,
      wm_uptime: wm_uptime,
      cs_uptime: cs_uptime,
      bcam_uptime: bcam_uptime,
      tcam_uptime: tcam_uptime,
      mic_uptime: mic_uptime,
      nc_fail_counts: nc_fail_counts,
      ep_fail_counts: ep_fail_counts,
      cs_fail_counts: cs_fail_counts,
      nc_current_usage: nc_current_usage,
      ep_current_usage: ep_current_usage,
      wm_current_usage: wm_current_usage,
      cs_current_usage: cs_current_usage,
      latest_boot_event: latest_boot_event,
      boot_events: boot_events
  end
end
