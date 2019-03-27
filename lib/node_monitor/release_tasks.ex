defmodule NodeMonitor.ReleaseTasks do
  @startup_apps ~w| crypto ssl postgrex ecto ecto_sql |a

  @repos Application.get_env(:node_monitor, :ecto_repos, [])

  def migrate(_argv) do
    start_services()
    run_migrations()
    stop_services()
  end

  def seed(_argv) do
    start_services()
    run_migrations()
    run_seeds()
    stop_services()
  end

  #

  defp start_services do
    IO.puts("Starting dependencies...")

    @startup_apps
    |> Enum.each(&Application.ensure_all_started/1)

    IO.puts("Starting repos...")

    @repos
    |> Enum.each(& &1.start_link(pool_size: 2))
  end

  defp stop_services do
    IO.puts("Success!")
    :init.stop()
  end

  defp run_migrations do
    @repos
    |> Enum.each(&run_migrations_for/1)
  end

  defp run_migrations_for(repo) do
    app = Keyword.get(repo.config, :otp_app)

    IO.puts("Running migrations for #{app}")

    migrations_path = priv_path_for(repo, "migrations")
    Ecto.Migrator.run(repo, migrations_path, :up, all: true)
  end

  defp run_seeds do
    @repos
    |> Enum.each(&run_seeds_for/1)
  end

  defp run_seeds_for(repo) do
    seed_script = priv_path_for(repo, "seeds.exs")

    if File.exists?(seed_script) do
      IO.puts("Running seed script...")
      Code.eval_file(seed_script)
    end
  end

  defp priv_path_for(repo, filename) do
    app = Keyword.get(repo.config, :otp_app)

    repo_underscore =
      repo
      |> Module.split()
      |> List.last()
      |> Macro.underscore()

    priv_dir = "#{:code.priv_dir(app)}"

    Path.join([priv_dir, repo_underscore, filename])
  end
end
