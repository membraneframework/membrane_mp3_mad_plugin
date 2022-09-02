defmodule Membrane.MP3.MAD.DecoderIntegrationTest do
  use ExUnit.Case, async: true

  import Membrane.ParentSpec
  import Membrane.Testing.Assertions

  alias Membrane.MP3.MAD
  alias Membrane.File
  alias Membrane.Testing.Pipeline

  @tag :tmp_dir
  test "decoder decodes mp3 file correctly", %{tmp_dir: tmp_dir} do
    children = [
      src: %File.Source{location: "test/fixtures/input.mp3"},
      decoder: MAD.Decoder,
      sink: %File.Sink{location: "#{tmp_dir}/output"}
    ]

    {:ok, pipeline} = Pipeline.start_link(links: ParentSpec.link_linear(children))

    assert_pipeline_playback_changed(pipeline, :prepared, :playing)

    Pipeline.terminate(pipeline, blocking?: true)
  end
end
