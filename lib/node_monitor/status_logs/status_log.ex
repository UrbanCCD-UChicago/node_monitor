defmodule NodeMonitor.StatusLogs.StatusLog do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  schema "status_logs" do
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

  @reqd ~w| node_id timestamp |a

  @up_nc ~w| up_nc_sys up_nc_wm up_nc_cs up_nc_modem up_nc_wwan up_nc_lan up_nc_mic up_nc_samba |a

  @epoch ~w| epoch_nc epoch_ep |a

  @run_nc ~w| run_nc_rabbitmq run_nc_cs-plugin |a

  @fc ~w| fc_nc fc_ep fc_cs |a

  @cu ~w| cu_nc cu_ep cu_wm cu_cs |a

  @en ~w| en_nc en_ep en_cs |a

  @hb ~w| hb_nc hb_ep hb_cs |a

  @up_ep ~w| up_ep_sys up_ep_bcam up_ep_tcam up_ep_mic |a

  @run_ep ~w| run_ep_rabbitmq |a

  @other ~w| up_wm_sys net_wwan |a

  @attrs @reqd ++ @up_nc ++ @epoch ++ @run_nc ++ @fc ++ @cu ++ @en ++ @hb ++ @up_ep ++ @run_ep ++ @other

  @doc false
  def changeset(status_log, params) do
    status_log
    |> cast(params, @attrs)
    |> validate_required(@reqd)
    |> unique_constraint(:node_id, name: :status_logs_uniq)
  end
end
