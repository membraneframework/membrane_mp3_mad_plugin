# Membrane Multimedia Framework: Mad Element

This package provides elements that can be used to decode MPEG audio with libmad.

# Sample usage

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
      decoder: %Mad.Decoder{},
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
