# Membrane MP3 MAD plugin

[![CircleCI](https://circleci.com/gh/membraneframework/membrane_mp3_mad_plugin.svg?style=svg)](https://circleci.com/gh/membraneframework/membrane_mp3_mad_plugin)

MP3 decoder based on MAD.

This package is a part of [Membrane Multimedia Framework](https://membraneframework.org).

Documentation is available at [HexDocs](https://hexdocs.pm/membrane_mp3_mad_plugin/)


## Installation

Add the following line to your `deps` in `mix.exs`. Run `mix deps.get`.

```elixir
	{:membrane_mp3_mad_plugin, "~> 0.18.3"}
```

This package depends on the [MAD](https://www.underbit.com/products/mad/) library. The precompiled build will be pulled and linked automatically. However, should there be any problems, consider installing it manually.

## Sample usage

Playing below pipeline should read `input.mp3` file, decode it and save a raw payload to the `output.raw` file:

```elixir
defmodule MadExamplePipeline do
  use Membrane.Pipeline

  alias Membrane.MP3.MAD
  alias Membrane.File

  @impl true
  def handle_init(_ctx, _opts) do
    structure = 
      child(:src, %File.Source{location: "input.mp3"})
      |> child(:decoder, MAD.Decoder)
      |> child(:sink, %File.Sink{location: "output.raw"})

    {[spec: structure], %{}}
  end
end

```

## Copyright and License

Copyright 2018, [Software Mansion](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=membrane)

[![Software Mansion](https://logo.swmansion.com/logo?color=white&variant=desktop&width=200&tag=membrane-github)](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=membrane)

Licensed under the [Apache License, Version 2.0](LICENSE)
