
defmodule Membrane.Element.Mad.Decoder do
  use Membrane.Element.Base.Filter
  alias Membrane.Element.Mad.DecoderNative
  alias Membrane.{Buffer, Caps}
  use Membrane.Mixins.Log

  def_known_source_pads %{
    :source => {:always, :pull, [
      %Membrane.Caps.Audio.Raw{
        format: :s24le,
        sample_rate: 44100,
        channels: 2,
      }
    ]}
  }

  def_known_sink_pads %{
    :sink => {:always, :pull, [
      %Membrane.Caps.Audio.MPEG{
        channels: 2,
        sample_rate: 44100,
      }
    ]}
  }

  def handle_init(_) do
    {:ok, %{queue: <<>>, native: nil}}
  end

  @doc false
  def handle_prepare(:stopped, state) do
    with {:ok, native} <- DecoderNative.create
    do
      caps = %Caps.Audio.Raw{format: :s24le, sample_rate: 44100, channels: 2}
      {:ok, {[caps: {:source, caps}], %{state | native: native}}}
    end
  end
  def handle_prepare(_, state), do: {:ok, {[], state}}

  def handle_demand(:source, size, _, state) do
    {:ok, {[demand: {:sink, size}], state}}
  end

  def handle_process1(:sink, %Buffer{payload: data} = buffer, _, %{native: native, queue: queue} = state) do
    to_decode = queue <> data
    with {:ok, {decoded_audio, bytes_used}} when bytes_used > 0
      <- decode_buffer(native, to_decode)
    do
      << _used :: binary-size(bytes_used), rest :: binary >> = to_decode
      #TODO get audio spec from frame and send new caps
      {:ok, {[buffer: {:source, %Buffer{buffer | payload: decoded_audio}}], %{state | queue: rest}}}
    else
      {:ok, {<<>>, 0}} -> {:ok, {[], %{state | queue: to_decode}}}
      {:error, reason} -> {:error, reason}
    end

  end


  # first call
  defp decode_buffer(native, buffer) do
    decode_buffer(native, buffer, << >>, 0)
  end


  # empty buffer
  defp decode_buffer(_native, <<>>, acc,  bytes_used) do
    {:ok, {acc, bytes_used}}
  end


  # non empty buffer
  defp decode_buffer(native, buffer, acc, bytes_used) when byte_size(buffer) > 0 do
    #TODO consider case of changing sample_rate/channels - send modified caps
    with {:ok, {decoded_frame, frame_size, _sample_rate, _channels}}
      <- DecoderNative.decode_frame(native, buffer)
    do
        << _used :: binary-size(frame_size), rest :: binary >> = buffer
        decode_buffer(native, rest, acc <> decoded_frame, bytes_used + frame_size)
    else
      {:error, :buflen} ->
        {:ok, {acc, bytes_used}}

      {:error, {:recoverable, reason, bytes_to_skip}} ->
        warn_error "Skipping malformed frame", reason
        << _used :: binary-size(bytes_to_skip), new_buffer :: binary >> = buffer
        #TODO send discontinuity event
        decode_buffer(native, new_buffer, acc, bytes_used + bytes_to_skip)

      {:error, {:malformed, reason}} ->
        warn_error "Terminating stream becouse of malformed frame", reason
        {:error, reason}
    end
  end

end
