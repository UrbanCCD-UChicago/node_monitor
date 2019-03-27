defmodule NodeMonitor.Utils do

  require Logger

  @doc "Downloads a resource to a temp file and returns the path"
  @spec download!(binary()) :: binary()
  def download!(url) do
    # get the resource
    body =
      case HTTPoison.get!(url) do
        %HTTPoison.Response{status_code: 200, body: body} ->
          body

        _ ->
          ""
      end

    # save the contents to a file
    {:ok, path} = Temp.path()
    File.write!(path, body)

    # return the file path
    Logger.info("downloaded #{url} to #{path}")
    path
  end
end
