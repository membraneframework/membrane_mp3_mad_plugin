defmodule Membrane.MP3.MAD.BundlexProject do
  use Bundlex.Project

  def project() do
    [
      nifs: nifs(Bundlex.platform())
    ]
  end

  def nifs(_platform) do
    [
      decoder: [
        deps: [membrane_common_c: :membrane, unifex: :unifex],
        sources: ["_generated/decoder.c", "decoder.c"],
        pkg_configs: ["mad"]
      ]
    ]
  end
end
