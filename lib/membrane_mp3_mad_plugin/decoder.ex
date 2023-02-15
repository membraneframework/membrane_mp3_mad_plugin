defmodule Membrane.MP3.MAD.Decoder do
  @moduledoc """
  Decodes MPEG audio to raw data in S24LE format
  """
  use Membrane.Filter
  require Membrane.Logger

  alias __MODULE__.Native
  alias Membrane.{Buffer, Logger, MPEGAudio, RawAudio, RemoteStream}
  alias Membrane.Event.Discontinuity

  # ['Buffer', 'Event', 'Logger', 'MPEGAudio', 'RawAudio', 'RemoteStream']

  def_input_pad :input, demand_mode: :auto, accepted_format: any_of(RemoteStream, MPEGAudio)

  def_output_pad :output, demand_mode: :auto, accepted_format: %RawAudio{sample_format: :s24le}

  @impl true
  def handle_init(_context, _options) do
    {[], %{queue: <<>>, native: nil}}
  end

  @impl true
  def handle_playing(_ctx, state) do
    with {:ok, native} <- Native.create() do
      {[], %{state | native: native}}
    else
      {:error, reason} -> raise "Error: #{inspect(reason)}"
    end
  end

  @impl true
  def handle_stream_format(:input, _stream_format, _ctx, state) do
    {[], state}
  end

  @impl true
  def handle_process(:input, buffer, ctx, state) do
    to_decode = state.queue <> buffer.payload

    case decode_buffer(state.native, to_decode, ctx.pads.output.stream_format) do
      {:ok, {new_queue, actions}} ->
        {actions, %{state | queue: new_queue}}

      {:error, reason} ->
        raise "Error: #{inspect(reason)}"
    end
  end

  defp decode_buffer(native, buffer, stream_format, acc \\ [])

  defp decode_buffer(_native, <<>>, _stream_format, acc) do
    {:ok, {<<>>, Enum.reverse(acc)}}
  end

  defp decode_buffer(native, buffer, stream_format, acc) when byte_size(buffer) > 0 do
    with {:ok, {decoded_frame, frame_size, sample_rate, channels}} <-
           Native.decode_frame(buffer, native) do
      new_stream_format = %RawAudio{
        sample_format: :s24le,
        sample_rate: sample_rate,
        channels: channels
      }

      stream_format_action =
        if stream_format == new_stream_format,
          do: [],
          else: [stream_format: {:output, new_stream_format}]

      buffer_action = [buffer: {:output, %Buffer{payload: decoded_frame}}]

      <<_used::binary-size(frame_size), rest::binary>> = buffer
      decode_buffer(native, rest, new_stream_format, buffer_action ++ stream_format_action ++ acc)
    else
      {:error, :buflen} ->
        {:ok, {buffer, Enum.reverse(acc)}}

      {:error, {:recoverable, bytes_to_skip}} ->
        Logger.warn("Skipping malformed frame (#{bytes_to_skip} bytes)")
        <<_used::binary-size(bytes_to_skip), new_buffer::binary>> = buffer

        # TODO: first case cannot be reached because acc is always empty, recover these lines if it is needed
        # case acc do

        #   [{:event, %Discontinuity{}} | _actions] ->
        #     # send only one discontinuity event in a row
        #     decode_buffer(native, new_buffer, stream_format, acc)

        #   _no_event_on_top ->
        #     discontinuity = [event: {:output, %Discontinuity{}}]
        #     decode_buffer(native, new_buffer, stream_format, discontinuity ++ acc)
        # end

        discontinuity = [event: {:output, %Discontinuity{}}]
        decode_buffer(native, new_buffer, stream_format, discontinuity ++ acc)

      {:error, :malformed} ->
        Logger.warn("Terminating stream because of malformed frame")
        {:error, :malformed}
    end
  end
end
