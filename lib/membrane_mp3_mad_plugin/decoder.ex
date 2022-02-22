defmodule Membrane.MP3.MAD.Decoder do
  @moduledoc """
  Decodes MPEG audio to raw data in S24LE format
  """
  use Membrane.Filter
  require Membrane.Logger

  alias __MODULE__.Native
  alias Membrane.{Buffer, Logger, RemoteStream}
  alias Membrane.Caps.Audio.{MPEG, Raw}
  alias Membrane.Event.Discontinuity

  def_input_pad :input, demand_mode: :auto, caps: [RemoteStream, MPEG]

  def_output_pad :output, demand_mode: :auto, caps: {Raw, format: :s24le}

  @impl true
  def handle_init(_options) do
    {:ok, %{queue: <<>>, native: nil}}
  end

  @impl true
  def handle_prepared_to_playing(_ctx, state) do
    with {:ok, native} <- Native.create() do
      {:ok, %{state | native: native}}
    else
      {:error, reason} -> {{:error, reason}, state}
    end
  end

  @impl true
  def handle_caps(:input, _caps, _ctx, state) do
    {:ok, state}
  end

  @impl true
  def handle_process(:input, buffer, ctx, state) do
    to_decode = state.queue <> buffer.payload

    case decode_buffer(state.native, to_decode, ctx.pads.output.caps) do
      {:ok, {new_queue, actions}} ->
        {{:ok, actions}, %{state | queue: new_queue}}

      {:error, reason} ->
        {{:error, reason}, state}
    end
  end

  defp decode_buffer(native, buffer, caps, acc \\ [])

  defp decode_buffer(_native, <<>>, _caps, acc) do
    {:ok, {<<>>, Enum.reverse(acc)}}
  end

  defp decode_buffer(native, buffer, caps, acc) when byte_size(buffer) > 0 do
    with {:ok, {decoded_frame, frame_size, sample_rate, channels}} <-
           Native.decode_frame(buffer, native) do
      new_caps = %Raw{format: :s24le, sample_rate: sample_rate, channels: channels}

      caps_action = if caps == new_caps, do: [], else: [caps: {:output, new_caps}]
      buffer_action = [buffer: {:output, %Buffer{payload: decoded_frame}}]

      <<_used::binary-size(frame_size), rest::binary>> = buffer
      decode_buffer(native, rest, new_caps, buffer_action ++ caps_action ++ acc)
    else
      {:error, :buflen} ->
        {:ok, {buffer, Enum.reverse(acc)}}

      {:error, {:recoverable, bytes_to_skip}} ->
        Logger.warn("Skipping malformed frame (#{bytes_to_skip} bytes)")
        <<_used::binary-size(bytes_to_skip), new_buffer::binary>> = buffer

        case acc do
          [{:event, %Discontinuity{}} | _actions] ->
            # send only one discontinuity event in a row
            decode_buffer(native, new_buffer, caps, acc)

          _no_event_on_top ->
            discontinuity = [event: {:output, %Discontinuity{}}]
            decode_buffer(native, new_buffer, caps, discontinuity ++ acc)
        end

      {:error, :malformed} ->
        Logger.warn("Terminating stream because of malformed frame")
        {:error, :malformed}
    end
  end
end
