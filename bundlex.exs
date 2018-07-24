defmodule Membrane.Element.Mad.BundlexProject do
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
        sources: ["decoder_interface.c", "decoder_res.c", "decoder.c"],
        pkg_configs: ["mad"]
      ]
    ]
  end
end
