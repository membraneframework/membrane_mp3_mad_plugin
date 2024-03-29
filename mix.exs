defmodule Membrane.MP3.MAD.Plugin.Mixfile do
  use Mix.Project

  @version "0.18.3"
  @github_url "https://github.com/membraneframework/membrane_mp3_mad_plugin"

  def project do
    [
      app: :membrane_mp3_mad_plugin,
      compilers: [:unifex, :bundlex] ++ Mix.compilers(),
      version: @version,
      elixir: "~> 1.12",
      elixirc_paths: elixirc_paths(Mix.env()),
      description: "Membrane MP3 decoder based on MAD",
      package: package(),
      name: "Membrane MP3 MAD plugin",
      source_url: @github_url,
      docs: docs(),
      homepage_url: "https://membraneframework.org",
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
      formatters: ["html"],
      source_ref: "v#{@version}"
    ]
  end

  defp package do
    [
      maintainers: ["Membrane Team"],
      licenses: ["Apache-2.0"],
      links: %{
        "GitHub" => @github_url,
        "Membrane Framework Homepage" => "https://membraneframework.org"
      },
      files: ["lib", "mix.exs", "README*", "LICENSE*", ".formatter.exs", "bundlex.exs", "c_src"]
    ]
  end

  defp deps do
    [
      {:membrane_core, "~> 1.0"},
      {:membrane_mpegaudio_format, "~> 0.3.0"},
      {:membrane_raw_audio_format, "~> 0.12.0"},
      {:membrane_common_c, "~> 0.16.0"},
      {:unifex, "~> 1.1.0"},
      {:bundlex, "~> 1.3"},
      {:membrane_precompiled_dependency_provider, "~> 0.1.0"},
      {:ex_doc, "~> 0.28", only: :dev, runtime: false},
      {:credo, "~> 1.6", only: :dev, runtime: false},
      {:dialyxir, "~> 1.1", only: :dev, runtime: false},
      # testing deps
      {:membrane_file_plugin, "~> 0.17.0", only: :test}
    ]
  end
end
