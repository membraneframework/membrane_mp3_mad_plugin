defmodule Membrane.MP3.MAD.BundlexProject do
  use Bundlex.Project

  def project() do
    [
      natives: natives()
    ]
  end

  def natives() do
    [
      decoder: [
        interface: :nif,
        deps: [membrane_common_c: :membrane],
        sources: ["decoder.c"],
        os_deps: [
          mad: [
            {:precompiled,
             Membrane.PrecompiledDependencyProvider.get_dependency_url(:mad, version: "0.15.1b")},
            :pkg_config
          ]
        ],
        preprocessor: Unifex
      ]
    ]
  end
end
