# Membrane MP3 MAD plugin

[![Hex.pm](https://img.shields.io/hexpm/v/membrane_mp3_mad_plugin.svg)](https://hex.pm/packages/membrane_mp3_mad_plugin)
[![API Docs](https://img.shields.io/badge/api-docs-yellow.svg?style=flat)](https://hexdocs.pm/membrane_mp3_mad_plugin)
[![CircleCI](https://circleci.com/gh/membraneframework/membrane_mp3_mad_plugin.svg?style=svg)](https://circleci.com/gh/membraneframework/membrane_mp3_mad_plugin)

MP3 decoder based on MAD.

This package is a part of [Membrane Multimedia Framework](https://membraneframework.org).

Documentation is available at [HexDocs](https://hexdocs.pm/membrane_mp3_mad_plugin/)


## Installation

The package can be installed by adding membrane_mp3_mad_plugin to your list of dependencies in mix.exs:

```elixir
  {:membrane_mp3_mad_plugin, "~> 0.13.0"}
```

You also need to have [MAD](https://www.underbit.com/products/mad/) installed.

## Sample usage

Playing below pipeline should read `input.mp3`, decode and save raw payload to `output`:

```elixir
defmodule MadExamplePipeline do
  use Membrane.Pipeline

  alias Membrane.MP3.MAD
  alias Membrane.File

  @impl true
  def handle_init(_) do
    children = [
      src: %File.Source{location: "input.mp3"},
      decoder: MAD.Decoder,
      sink: %File.Sink{location: "output"}
    ]

    links = [
      link(:src)
      |> to(:decoder)
      |> to(:sink)
    ]

    spec = %ParentSpec{children: children, links: links}
    {{:ok, spec: spec, playback: :playing}, %{}}
  end
end
```

## Copyright and License

Copyright 2018, [Software Mansion](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=membrane_mp3_mad_plugin)

[![Software Mansion](https://logo.swmansion.com/logo?color=white&variant=desktop&width=200&tag=membrane-github)](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=membrane_mp3_mad_plugin)

Licensed under the [Apache License, Version 2.0](LICENSE)
