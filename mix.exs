defmodule Membrane.Element.Mad.Mixfile do
  use Mix.Project
  Application.put_env(:bundlex, :membrane_element_mad, __ENV__)

  @github_url "https://github.com/membraneframework/membrane-element-mad"

  def project do
    [
      app: :membrane_element_mad,
      compilers: ~w(bundlex) ++ Mix.compilers(),
      version: "0.1.0",
      elixir: "~> 1.6",
      elixirc_paths: elixirc_paths(Mix.env()),
      description: "Membrane Multimedia Framework (Mad Element)",
      package: package(),
      name: "Membrane Element: Mad",
      source_url: @github_url,
      docs: docs(),
      homepage_url: "https://membraneframework.org",
      preferred_cli_env: [espec: :test, format: :test],
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [],
      mod: {Membrane.Element.Mad, []}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp docs do
    [
      main: "readme",
      extras: ["README.md"]
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
      {:ex_doc, "~> 0.18", only: :dev, runtime: false},
      {:membrane_core, "~> 0.1"},
      {:membrane_caps_audio_mpeg, "~> 0.1"},
      {:membrane_caps_audio_raw, "~> 0.1"},
      {:membrane_common_c, "~> 0.1"},
      {:bundlex, "~> 0.1"},
      {:espec, "~> 1.5.0", only: :test}
    ]
  end
end
