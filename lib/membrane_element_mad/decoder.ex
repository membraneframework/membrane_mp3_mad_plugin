
defmodule Membrane.Element.Mad.Decoder do
  use Membrane.Element.Base.Filter
  alias Membrane.Element.Mad.DecoderNative

  def_known_source_pads %{
    :source => {:always, [
      %Membrane.Caps.Audio.Raw{
        format: :s24le,
        sample_rate: 44100,
        channels: 2,
      }
    ]}
  }

  def_known_sink_pads %{
    :sink => {:always, [
      %Membrane.Caps.Audio.MPEG{
        channels: 2,
        sample_rate: 44100,
      }
    ]}
  }

  @doc false
  def handle_prepare(_state) do
    case DecoderNative.create() do
      {:ok, native} ->
        {:ok, %{native: native, queue: << >>}}
      {:error, reason} ->
        {:error, reason, %{
          native: nil,
          queue: << >>
        }}
    end
  end


  def handle_buffer(:sink, _caps, %Membrane.Buffer{payload: data} = buffer, %{native: native, queue: queue} = state) do
    to_decode = queue <> data

    case decode_buffer(native, to_decode) do

      {:error, desc} ->
        {:error, desc}

      {decoded_audio, bytes_used} ->
        << _used :: binary-size(bytes_used), rest :: binary >> = to_decode
        #new_caps = %Membrane.Caps.Audio.Raw{format: :s24le, sample_rate: 44100, channels: 2} #TODO get audio spec from frame
        {:ok, [{:send, {:source, %Membrane.Buffer{buffer | payload: decoded_audio}}}], %{state | queue: rest}}

    end

  end


  # first call
  defp decode_buffer(native, buffer) do
    decode_buffer(native, buffer, << >>, 0)
  end


  # empty buffer
  defp decode_buffer(_native, <<>>, acc,  bytes_used) do
    {acc, bytes_used}
  end


  # non empty buffer
  defp decode_buffer(native, buffer, acc, bytes_used) when byte_size(buffer) > 0 do
    case DecoderNative.decode_frame(native, buffer) do
      {:ok, {decoded_frame, frame_size, sample_rate, channels}} ->
        << _used :: binary-size(frame_size), rest :: binary >> = buffer
        decode_buffer(native, rest, acc <> decoded_frame, bytes_used + frame_size)

      {:error, :buflen} ->
        {acc, bytes_used}

      {:error, {:recoverable, reason, bytes_to_skip}} ->
        IO.puts("recoverable error")
        << _used :: binary-size(bytes_to_skip), new_buffer :: binary >> = buffer
        #TODO send discontinuity event
        decode_buffer(native, new_buffer, acc, bytes_used + bytes_to_skip)

      {:error, {:malformed, reason}} ->
        {:error, reason}
    end
  end

end
