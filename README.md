# Membrane Multimedia Framework: Mad Element

This package provides elements that can be used to decode MPEG audio with libmad.

# Decoding caps

For now, decoder doesn't support decoding caps from MPEG frames. To receive valid caps on `sink` pad, decoder must be placed in the pipeline after `Membrane.Element.MPEGAudioParse.Parser`. 

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
