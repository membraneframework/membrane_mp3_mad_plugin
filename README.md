# Membrane MP3 MAD plugin

[![CircleCI](https://circleci.com/gh/membraneframework/membrane_mp3_mad_plugin.svg?style=svg)](https://circleci.com/gh/membraneframework/membrane_mp3_mad_plugin)

MP3 decoder based on MAD.

This package is a part of [Membrane Multimedia Framework](https://membraneframework.org).

Documentation is available at [HexDocs](https://hexdocs.pm/membrane_mp3_mad_plugin/)


## Installation

Add the following line to your `deps` in `mix.exs`. Run `mix deps.get`.

```elixir
	{:membrane_mp3_mad_plugin, "~> 0.14.0"}
```

You also need to have [MAD](https://www.underbit.com/products/mad/) installed.

## Sample usage

Playing below pipeline should read `input.mp3`, decode and save raw payload to `output`:

```elixir
defmodule MadExamplePipeline do
  use Membrane.Pipeline
  alias Pipeline.Spec
  alias Membrane.MP3.MAD
  alias Membrane.Element.File

  @impl true
  def handle_init(_) do
    children = [
      src: %File.Source{location: "input.mp3"},
      decoder: MAD.Decoder,
      sink: %File.Sink{location: "output"},
    ]
    links = %{
      {:src, :source} => {:decoder, :sink},
      {:decoder, :source} => {:sink, :sink}
    }

    {{:ok, %Spec{children: children, links: links}}, %{}}
  end
end

```

## Copyright and License

Copyright 2018, [Software Mansion](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=membrane)

[![Software Mansion](https://logo.swmansion.com/logo?color=white&variant=desktop&width=200&tag=membrane-github)](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=membrane)

Licensed under the [Apache License, Version 2.0](LICENSE)
