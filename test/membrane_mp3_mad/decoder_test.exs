defmodule Membrane.MP3.MAD.DecoderTest do
  use ExUnit.Case, async: true

  import Membrane.ChildrenSpec
  import Membrane.Testing.Assertions

  alias Membrane.{Buffer, RawAudio}
  alias Membrane.File.{Sink, Source}
  alias Membrane.MP3.MAD.Decoder
  alias Membrane.MP3.MAD.Decoder.Native
  alias Membrane.Testing.Pipeline

  @minimal_mpeg_frame <<255, 243, 20, 196, 0, 0, 0, 3, 72, 0, 0, 0, 0, 76, 65, 77, 69, 51, 46, 57,
                        54, 46, 49, 85, 255, 243, 20, 196, 11, 255, 243, 20, 196, 11, 0, 0, 3, 72,
                        0, 0, 0, 0, 85, 85, 85, 85, 85, 85, 85, 85, 85, 85, 85, 255, 243, 20, 196,
                        22, 0, 0, 3, 72, 0, 0, 0, 0, 85, 85, 85, 85, 85, 85, 85, 85, 85, 85, 85,
                        255, 243, 20, 196, 33, 0, 0, 3, 72, 0, 0, 0, 0, 85, 85, 85, 85, 85, 85,
                        85, 85, 85, 85, 85>>

  @minimal_sample_rate 24_000
  @minimal_frame_channels 1

  @in_path "test/fixtures/input.mp3"
  @ref_path "test/fixtures/output.raw"

  setup do
    context = %{pads: %{output: %{stream_format: nil}}}
    assert {:ok, native} = Native.create()
    state = %{native: native, queue: <<>>, id3_skipped: false}
    [context: context, state: state]
  end

  test "handle_init", ctx do
    assert {[], state} = Decoder.handle_init(%{}, %{})
    assert state.queue == ctx.state.queue
    assert state.native == nil
  end

  defp assert_sends_first_frame(state, context, incoming_buffer) do
    assert {actions, new_state} = Decoder.handle_buffer(:input, incoming_buffer, context, state)

    assert {:output, %Buffer{payload: payload}} = actions[:buffer]
    assert is_binary(payload)
    assert byte_size(payload) > 0

    assert {:output, %RawAudio{} = stream_format} = actions[:stream_format]

    assert stream_format == %RawAudio{
             sample_format: :s24le,
             sample_rate: @minimal_sample_rate,
             channels: @minimal_frame_channels
           }

    assert is_binary(payload)
    assert new_state.native == state.native
  end

  test "handle_buffer skips id3 tag", ctx do
    id3 =
      <<73, 68, 51, 4, 0, 0, 0, 0, 1, 0, 84, 88, 88, 88, 0, 0, 0, 18, 0, 0, 3, 109, 97, 106, 111,
        114, 95, 98, 114, 97, 110, 100, 0, 109, 112, 52, 50, 0, 84, 88, 88, 88, 0, 0, 0, 17, 0, 0,
        3, 109, 105, 110, 111, 114, 95, 118, 101, 114, 115, 105, 111, 110, 0, 48, 0, 84, 88, 88,
        88, 0, 0, 0, 28, 0, 0, 3, 99, 111, 109, 112, 97, 116, 105, 98, 108, 101, 95, 98, 114, 97,
        110, 100, 115, 0, 109, 112, 52, 50, 109, 112, 52, 49, 0, 84, 83, 83, 69, 0, 0, 0, 15, 0,
        0, 3, 76, 97, 118, 102, 53, 57, 46, 49, 54, 46, 49, 48, 48, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0>>

    <<partial_frame::20-binary, _rest::binary>> = @minimal_mpeg_frame
    buffer = %Buffer{payload: id3 <> partial_frame}

    assert {[], state} = Decoder.handle_buffer(:input, buffer, ctx.context, ctx.state)
    assert %{id3_skipped: true, queue: ^partial_frame} = state
  end

  test "handle_buffer with empty queue and whole frame in buffer", ctx do
    buffer = %Buffer{payload: @minimal_mpeg_frame}

    assert_sends_first_frame(ctx.state, ctx.context, buffer)
  end

  test "handle_buffer with buffer completing frame in queue", ctx do
    <<queue::20-bytes, rest::bytes>> = @minimal_mpeg_frame
    state = %{ctx.state | queue: queue}
    buffer = %Buffer{payload: rest}

    assert_sends_first_frame(state, ctx.context, buffer)
  end

  test "handle_buffer with partial frame in buffer", ctx do
    length = 4
    buffer = %Buffer{payload: @minimal_mpeg_frame |> binary_part(0, length)}

    assert {[], new_state} = Decoder.handle_buffer(:input, buffer, ctx.context, ctx.state)

    assert byte_size(new_state.queue) == length
    assert new_state.native == ctx.state.native
  end

  test "handle_buffer with partial frame in buffer and queue", ctx do
    <<queue::2-bytes, payload::2-bytes, _rest::bytes>> = @minimal_mpeg_frame
    state = %{ctx.state | queue: queue}
    buffer = %Buffer{payload: payload}

    assert {[], new_state} = Decoder.handle_buffer(:input, buffer, ctx.context, state)

    assert byte_size(new_state.queue) == 4
    assert new_state.native == ctx.state.native
  end

  @tag :tmp_dir
  test "Decoder decodes fixture correctly", ctx do
    out_path = Path.join(ctx.tmp_dir, "output.raw")

    pipeline =
      Pipeline.start_link_supervised!(
        spec:
          child(:source, %Source{location: @in_path})
          |> child(:decoder, Decoder)
          |> child(:sink, %Sink{location: out_path})
      )

    assert_end_of_stream(pipeline, :sink)
    Pipeline.terminate(pipeline)
    assert File.read(out_path) == File.read(@ref_path)
  end
end
