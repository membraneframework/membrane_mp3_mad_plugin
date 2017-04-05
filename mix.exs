defmodule Membrane.Element.Mad.Mixfile do
  use Mix.Project

  def project do
    [app: :membrane_element_mad,
     compilers: ~w(bundlex.lib) ++ Mix.compilers,
     version: "0.0.1",
     elixir: "~> 1.3",
     elixirc_paths: elixirc_paths(Mix.env),
     description: "Membrane Multimedia Framework (Mad Element)",
     maintainers: ["Marcin Lewandowski", "Mateusz Nowak"],
     licenses: ["LGPL"],
     name: "Membrane Element: Mad",
     source_url: "git@github.com:membraneframework/membrane-element-mad",
     preferred_cli_env: [espec: :test],
     deps: deps]
  end


  def application do
    [applications: [
      :membrane_core
    ], mod: {Membrane.Element.Mad, []}]
  end


  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_),     do: ["lib",]


  defp deps do
    [
      {:membrane_core, git: "git@github.com:membraneframework/membrane-core.git"},
      {:membrane_caps_audio_mpeg, git: "git@github.com:membraneframework/membrane-caps-audio-mpeg.git"},
      {:membrane_caps_audio_raw, git: "git@github.com:membraneframework/membrane-caps-audio-raw.git"},
      {:membrane_common_c, git: "git@github.com:membraneframework/membrane-common-c.git"},
      {:bundlex, git: "git@github.com:radiokit/bundlex.git"},
      {:espec, "~> 1.1.2", only: :test},
    ]
  end
end
