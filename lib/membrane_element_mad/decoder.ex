
defmodule Membrane.Element.Mad.Decoder do
  use Membrane.Element.Base.Filter
  alias Membrane.Element.Mad.DecoderNative

  @doc false
  def handle_prepare(_state) do
    case DecoderNative.create() do
      {:ok, native} ->
        {:ok, %{
          native: native,
          queue: << >>
        }}
      {:error, reason} ->
        {:error, reason, %{
          native: nil,
          queue: << >>
        }}
    end
  end


  def handle_buffer(_caps, data, %{native: native, queue: queue} = state) do
    to_decode = queue <> data
    {decoded_audio, bytes_used} = decode_buffer(native, to_decode)
    
    << _used :: binary-size(bytes_used), rest :: binary >> = to_decode
    
    {:ok, {sample_rate, channels}} = DecoderNative.get_stream_info(native) 
    new_caps = %Membrane.Caps.Audio.Raw{format: :s16le, sample_rate: sample_rate, channels: channels}
    
    {:send_buffer, {new_caps, decoded_audio}, %{state | queue: rest}}
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

      {:ok, {decoded_frame, frame_size}} ->
        << _used :: binary-size(frame_size), rest :: binary >> = buffer
        decode_buffer(native, rest, acc <> decoded_frame, bytes_used + frame_size)

      :buflen_error ->
        {acc, bytes_used}

      {:error, desc} ->
        {:error, desc}
    end
  end

end
