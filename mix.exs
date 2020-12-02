defmodule Membrane.MP3.MAD.Plugin.Mixfile do
  use Mix.Project

  @version "0.5.0"
  @github_url "https://github.com/membraneframework/membrane_mp3_mad_plugin"

  def project do
    [
      app: :membrane_mp3_mad_plugin,
      compilers: [:unifex, :bundlex] ++ Mix.compilers(),
      version: @version,
      elixir: "~> 1.7",
      elixirc_paths: elixirc_paths(Mix.env()),
      description: "Membrane MP3 decoder based on MAD",
      package: package(),
      name: "Membrane MP3 MAD plugin",
      source_url: @github_url,
      docs: docs(),
      homepage_url: "https://membraneframework.org",
      preferred_cli_env: [espec: :test, format: :test],
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: []
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp docs do
    [
      main: "readme",
      extras: ["README.md", "LICENSE"],
      source_ref: "v#{@version}"
    ]
  end

  defp package do
    [
      maintainers: ["Membrane Team"],
      licenses: ["Apache 2.0"],
      links: %{
        "GitHub" => @github_url,
        "Membrane Framework Homepage" => "https://membraneframework.org"
      },
      files: ["lib", "mix.exs", "README*", "LICENSE*", ".formatter.exs", "bundlex.exs", "c_src"]
    ]
  end

  defp deps do
    [
      {:ex_doc, "~> 0.19", only: :dev, runtime: false},
      {:membrane_core, "~> 0.6.0"},
      {:membrane_caps_audio_mpeg, "~> 0.2.0"},
      {:membrane_caps_audio_raw, "~> 0.3.0"},
      {:membrane_common_c, "~> 0.5.0"},
      {:unifex, "~> 0.3.2"},
      {:espec, "~> 1.7", only: :test}
    ]
  end
end
