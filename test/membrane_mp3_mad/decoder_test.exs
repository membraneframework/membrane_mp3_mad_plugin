defmodule Membrane.MP3.MAD.DecoderTest do
  use ExUnit.Case, async: true

  alias Membrane.Buffer
  alias Membrane.RawAudio
  alias Membrane.MP3.MAD.Decoder
  alias Membrane.MP3.MAD.Decoder.Native

  @minimal_mpeg_frame <<255, 243, 20, 196, 0, 0, 0, 3, 72, 0, 0, 0, 0, 76, 65, 77, 69, 51, 46, 57,
                        54, 46, 49, 85, 255, 243, 20, 196, 11, 255, 243, 20, 196, 11, 0, 0, 3, 72,
                        0, 0, 0, 0, 85, 85, 85, 85, 85, 85, 85, 85, 85, 85, 85, 255, 243, 20, 196,
                        22, 0, 0, 3, 72, 0, 0, 0, 0, 85, 85, 85, 85, 85, 85, 85, 85, 85, 85, 85,
                        255, 243, 20, 196, 33, 0, 0, 3, 72, 0, 0, 0, 0, 85, 85, 85, 85, 85, 85,
                        85, 85, 85, 85, 85>>

  @minimal_sample_rate 24_000
  @minimal_frame_channels 1

  setup do
    context = %{pads: %{output: %{caps: nil}}}
    assert {:ok, native} = Native.create()
    state = %{native: native, queue: ""}
    [context: context, state: state]
  end

  test "handle_init", ctx do
    assert {:ok, state} = Decoder.handle_init(%{})
    assert state.queue == ctx.state.queue
    assert state.native == nil
  end

  defp assert_sends_first_frame(state, context, incoming_buffer) do
    assert {{:ok, actions}, new_state} =
             Decoder.handle_process(:input, incoming_buffer, context, state)

    assert {:output, %Buffer{payload: payload}} = actions[:buffer]
    assert is_binary(payload)
    assert byte_size(payload) > 0

    assert {:output, %RawAudio{} = caps} = actions[:caps]

    assert caps == %RawAudio{
             sample_format: :s24le,
             sample_rate: @minimal_sample_rate,
             channels: @minimal_frame_channels
           }

    assert is_binary(payload)
    assert new_state.native == state.native
  end

  test "handle_process with empty queue and whole frame in buffer", ctx do
    buffer = %Buffer{payload: @minimal_mpeg_frame}

    assert_sends_first_frame(ctx.state, ctx.context, buffer)
  end

  test "handle_process with buffer completing frame in queue", ctx do
    <<queue::20-bytes, rest::bytes>> = @minimal_mpeg_frame
    state = %{ctx.state | queue: queue}
    buffer = %Buffer{payload: rest}

    assert_sends_first_frame(state, ctx.context, buffer)
  end

  test "handle_process with partial frame in buffer", ctx do
    length = 4
    buffer = %Buffer{payload: @minimal_mpeg_frame |> binary_part(0, length)}

    assert {{:ok, []}, new_state} = Decoder.handle_process(:input, buffer, ctx.context, ctx.state)

    assert byte_size(new_state.queue) == length
    assert new_state.native == ctx.state.native
  end

  test "handle_process with partial frame in buffer and queue", ctx do
    <<queue::2-bytes, payload::2-bytes, _rest::bytes>> = @minimal_mpeg_frame
    state = %{ctx.state | queue: queue}
    buffer = %Buffer{payload: payload}

    assert {{:ok, []}, new_state} = Decoder.handle_process(:input, buffer, ctx.context, state)

    assert byte_size(new_state.queue) == 4
    assert new_state.native == ctx.state.native
  end
end