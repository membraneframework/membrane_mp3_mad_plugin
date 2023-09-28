defmodule Membrane.MP3.MAD.BundlexProject do
  use Bundlex.Project

  def project() do
    [
      natives: natives()
    ]
  end

  defp get_mad_url() do
    system_architecture =
      case Bundlex.get_target() do
        %{os: "linux"} -> "linux"
        %{architecture: "x86_64", os: "darwin" <> _rest_of_os_name} -> "macos_intel"
        %{architecture: "aarch64", os: "darwin" <> _rest_of_os_name} -> "macos_m1"
        _other -> nil
      end

    {:precompiled,
     "https://github.com/membraneframework-precompiled/precompiled_mad/releases/latest/download/mad_#{system_architecture}.tar.gz"}
  end

  def natives() do
    [
      decoder: [
        interface: :nif,
        deps: [membrane_common_c: :membrane],
        sources: ["decoder.c"],
        os_deps: [{get_mad_url(), "mad"}],
        preprocessor: Unifex
      ]
    ]
  end
end
