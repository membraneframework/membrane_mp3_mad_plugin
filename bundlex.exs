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
        deps: [membrane_common_c: :membrane],
        sources: ["decoder.c"],
        pkg_configs: ["mad"]
      ]
    ]
  end
end
