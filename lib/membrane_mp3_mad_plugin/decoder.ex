defmodule Membrane.MP3.MAD.Decoder do
  @moduledoc """
  Decodes MPEG audio to raw data in S24LE format
  """
  use Membrane.Filter
  require Membrane.Logger

  alias __MODULE__.Native
  alias Membrane.{Buffer, Logger, MPEGAudio, RawAudio, RemoteStream}
  alias Membrane.Event.Discontinuity

  @samples_per_frame 1152

  def_input_pad :input, accepted_format: any_of(RemoteStream, MPEGAudio)

  def_output_pad :output, accepted_format: %RawAudio{sample_format: :s24le}

  @impl true
  def handle_init(_context, _options) do
    {[], %{queue: <<>>, id3_skipped: false, native: nil}}
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
  def handle_buffer(:input, buffer, ctx, %{id3_skipped: false} = state) do
    payload = state.queue <> buffer.payload

    case skip_id3(payload) do
      {:skipped, rest} ->
        handle_buffer(:input, %Buffer{buffer | payload: rest}, ctx, %{
          state
          | id3_skipped: true,
            queue: <<>>
        })

      :skipping ->
        {[], %{state | queue: payload}}
    end
  end

  @impl true
  def handle_buffer(:input, buffer, ctx, state) do
    to_decode = state.queue <> buffer.payload

    case decode_buffer(state.native, to_decode, buffer.pts, ctx.pads.output.stream_format) do
      {:ok, {new_queue, actions}} ->
        {actions, %{state | queue: new_queue}}

      {:error, reason} ->
        raise "Error: #{inspect(reason)}"
    end
  end

  defp skip_id3(payload) do
    # taken from https://github.com/thechangelog/id3vx/blob/4e0349ea5bdb7f8bf8430b224151a7293fccb3fd/lib/id3vx.ex#L436
    result =
      case payload do
        <<"ID3", version::integer, _minor::integer, _flags::size(8), tag_size::binary-size(4),
          content::binary>>
        when version in [2, 3] ->
          {:tag, tag_size, content}

        <<"ID3", version::integer, _minor::integer, _unsynchronisation::size(1),
          _extended_header::size(1), _experimental::size(1), _footer::size(1), _unused::size(4),
          tag_size::binary-size(4), content::binary>>
        when version == 4 ->
          {:tag, tag_size, content}

        <<"ID3", _rest::binary>> when byte_size(payload) < 10 ->
          :skipping

        payload when byte_size(payload) < 3 ->
          :skipping

        # no id3
        payload ->
          {:skipped, payload}
      end

    with {:tag, tag_size, content} <- result do
      tag_size = decode_synchsafe_integer(tag_size)

      case content do
        <<_tag::binary-size(tag_size), rest::binary>> -> {:skipped, rest}
        _content -> :skipping
      end
    end
  end

  defp decode_synchsafe_integer(binary) do
    import Bitwise

    binary
    |> :binary.bin_to_list()
    |> Enum.reverse()
    |> Enum.with_index()
    |> Enum.reduce(0, fn {el, index}, acc -> acc ||| el <<< (index * 7) end)
  end

  defp decode_buffer(native, buffer, pts, stream_format, acc \\ [])

  defp decode_buffer(_native, <<>>, _pts, _stream_format, acc) do
    {:ok, {<<>>, Enum.reverse(acc)}}
  end

  defp decode_buffer(native, buffer, pts, stream_format, acc) when byte_size(buffer) > 0 do
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

      buffer_action = [buffer: {:output, %Buffer{payload: decoded_frame, pts: pts}}]

      <<_used::binary-size(frame_size), rest::binary>> = buffer

      next_pts =
        if pts == nil,
          do: nil,
          else: pts + RawAudio.frames_to_time(@samples_per_frame, new_stream_format)

      decode_buffer(
        native,
        rest,
        next_pts,
        new_stream_format,
        buffer_action ++ stream_format_action ++ acc
      )
    else
      {:error, :buflen} ->
        {:ok, {buffer, Enum.reverse(acc)}}

      {:error, {:recoverable, bytes_to_skip}} ->
        Logger.warning("Skipping malformed frame (#{bytes_to_skip} bytes)")
        <<_used::binary-size(bytes_to_skip), new_buffer::binary>> = buffer

        next_pts =
          if pts == nil,
            do: nil,
            else: pts + RawAudio.frames_to_time(@samples_per_frame, stream_format)

        case acc do
          [{:event, {:output, %Discontinuity{}}} | _actions] ->
            # send only one discontinuity event in a row
            decode_buffer(native, new_buffer, next_pts, stream_format, acc)

          _no_event_on_top ->
            discontinuity = [event: {:output, %Discontinuity{}}]
            decode_buffer(native, new_buffer, next_pts, stream_format, discontinuity ++ acc)
        end

      {:error, :malformed} ->
        Logger.warning("Terminating stream because of malformed frame")
        {:error, :malformed}
    end
  end
end
