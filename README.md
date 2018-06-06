# Membrane Multimedia Framework: Mad Element

This package provides [Membrane Multimedia Framework](https://membraneframework.org)
elements that can be used to decode MPEG audio using MAD library.

Documentation is available at [HexDocs](https://hexdocs.pm/membrane_element_mad/)


## Installation

Add the following line to your `deps` in `mix.exs`. Run `mix deps.get`.

```elixir
{:membrane_element_mad, "~> 0.1"}
```

You also need to have [MAD](https://www.underbit.com/products/mad/) installed.

## Sample usage

Playing below pipeline should read `input.mp3`, decode and save raw payload to `output`:

```elixir
defmodule MadExamplePipeline do
  use Membrane.Pipeline
  alias Pipeline.Spec
  alias Membrane.Element.{Mad, File}

  @impl true
  def handle_init(_) do
    children = [
      src: %File.Source{location: "input.mp3"},
      decoder: Mad.Decoder,
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
