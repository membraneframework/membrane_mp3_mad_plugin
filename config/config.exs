use Mix.Config

config :membrane_element_mad, :bundlex_lib,
  macosx: [
    nif: [
      membrane_element_mad_decoder: [
        includes: [
          "../membrane_common_c/c_src",
          "./deps/membrane_common_c/c_src",
        ],
        sources: [
          "decoder.c",
        ],
        libs: [
          "mad"
        ],
        pkg_configs: [
        ]
      ]
    ]
  ]
