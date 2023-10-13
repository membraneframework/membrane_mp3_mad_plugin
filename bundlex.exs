defmodule Membrane.MP3.MAD.BundlexProject do
  use Bundlex.Project

  def project() do
    [
      natives: natives()
    ]
  end

  defp get_mad_url() do
    url_prefix =
      "https://github.com/membraneframework-precompiled/precompiled_mad/releases/latest/download/mad"

    case Bundlex.get_target() do
      %{os: "linux"} ->
        {:precompiled, "#{url_prefix}_linux.tar.gz"}

      %{architecture: "x86_64", os: "darwin" <> _rest_of_os_name} ->
        {:precompiled, "#{url_prefix}_macos_intel.tar.gz"}

      _other ->
        nil
    end
  end

  def natives() do
    [
      decoder: [
        interface: :nif,
        deps: [membrane_common_c: :membrane],
        sources: ["decoder.c"],
        os_deps: [{[get_mad_url(), :pkg_config], "mad"}],
        preprocessor: Unifex
      ]
    ]
  end
end
