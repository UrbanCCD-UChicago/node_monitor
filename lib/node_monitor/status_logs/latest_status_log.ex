defmodule NodeMonitor.StatusLogs.LatestStatusLog do
  use Ecto.Schema

  @primary_key false
  schema "latest_status_logs" do
    # grouping
    field :node_id,             :string
    field :timestamp,           :naive_datetime

    # nc uptimes
    field :up_nc_sys,           :integer,         default: nil
    field :up_nc_wm,            :integer,         default: nil
    field :up_nc_cs,            :integer,         default: nil
    field :up_nc_modem,         :integer,         default: nil
    field :up_nc_wwan,          :integer,         default: nil
    field :up_nc_lan,           :integer,         default: nil
    field :up_nc_mic,           :integer,         default: nil
    field :up_nc_samba,         :boolean,         default: nil

    # epoch
    field :epoch_nc,            :naive_datetime,  default: nil
    field :epoch_ep,            :naive_datetime,  default: nil

    # nc software flags
    field :run_nc_rabbitmq,     :boolean,         default: nil
    field :"run_nc_cs-plugin",  :boolean,         default: nil

    # fail counts
    field :fc_nc,               :integer,         default: nil
    field :fc_ep,               :integer,         default: nil
    field :fc_cs,               :integer,         default: nil

    # current usage
    field :cu_nc,               :integer,         default: nil
    field :cu_ep,               :integer,         default: nil
    field :cu_wm,               :integer,         default: nil
    field :cu_cs,               :integer,         default: nil

    # device en
    field :en_nc,               :boolean,         default: nil
    field :en_ep,               :boolean,         default: nil
    field :en_cs,               :boolean,         default: nil

    # heart beats
    field :hb_nc,               :boolean,         default: nil
    field :hb_ep,               :boolean,         default: nil
    field :hb_cs,               :boolean,         default: nil

    # edge processor uptimes
    field :up_ep_sys,           :integer,         default: nil
    field :up_ep_bcam,          :integer,         default: nil
    field :up_ep_tcam,          :integer,         default: nil
    field :up_ep_mic,           :integer,         default: nil

    # edge processor software flags
    field :run_ep_rabbitmq,     :boolean,         default: nil

    # other
    field :up_wm_sys,           :integer,         default: nil
    field :net_wwan,            :integer,         default: nil
  end
end
