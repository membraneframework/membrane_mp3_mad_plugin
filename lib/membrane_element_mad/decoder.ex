defmodule Membrane.Element.Mad.Decoder do
  use Membrane.Element.Base.Filter
  alias Membrane.Caps.Audio.{Raw, MPEG}
  alias Membrane.Element.Mad.DecoderNative
  alias Membrane.Buffer
  use Membrane.Mixins.Log

  def_known_source_pads %{
    :source => {:always, :pull, :any}
  }

  def_known_sink_pads %{
    :sink => {:always, {:pull, demand_in: :buffers}, :any}
  }

  def handle_init(_) do
    {:ok, %{queue: <<>>, native: nil}}
  end

  @doc false
  def handle_prepare(:stopped, state) do
    with {:ok, native} <- DecoderNative.create() do
      {:ok, %{state | native: native}}
    else
      {:error, reason} -> {{:error, reason}, state}
    end
  end

  def handle_prepare(_, state), do: {:ok, state}

  def handle_caps(
        :sink,
        %MPEG{sample_rate: sample_rate, channels: channels},
        %{caps: %MPEG{sample_rate: sample_rate, channels: channels}},
        state
      ) do
    {:ok, state}
  end

  def handle_caps(
        :sink,
        %MPEG{sample_rate: sample_rate, channels: channels},
        _,
        state
      ) do
    raw = %Raw{format: :s24le, sample_rate: sample_rate, channels: channels}
    {{:ok, caps: {:source, raw}}, state}
  end

  def handle_demand(:source, size, :buffers, _, state) do
    {{:ok, demand: {:sink, size}}, state}
  end

  def handle_demand(:source, _size, :bytes, _, state) do
    {{:ok, demand: :sink}, state}
  end

  def handle_process1(
        :sink,
        %Buffer{payload: data} = buffer,
        _,
        %{native: native, queue: queue} = state
      ) do
    to_decode = queue <> data
    debug(inspect({:handle_process, length: byte_size(to_decode)}))

    with {:ok, {decoded_audio, bytes_used}} when bytes_used > 0 <-
           decode_buffer(native, to_decode) do
      <<_used::binary-size(bytes_used), rest::binary>> = to_decode
      # TODO get audio spec from frame and send new caps
      {{:ok, buffer: {:source, %Buffer{buffer | payload: decoded_audio}}}, %{state | queue: rest}}
    else
      {:ok, {<<>>, 0}} ->
        debug("MAD: no data was decoded, queue size #{byte_size(to_decode)}")
        {:ok, %{state | queue: to_decode}}

      {:error, reason} ->
        {{:error, reason}, state}
    end
  end

  # first call
  defp decode_buffer(native, buffer) do
    decode_buffer(native, buffer, <<>>, 0)
  end

  # empty buffer
  defp decode_buffer(_native, <<>>, acc, bytes_used) do
    {:ok, {acc, bytes_used}}
  end

  # non empty buffer
  defp decode_buffer(native, buffer, acc, bytes_used) when byte_size(buffer) > 0 do
    # TODO consider case of changing sample_rate/channels - send modified caps
    with {:ok, {decoded_frame, frame_size, _sample_rate, _channels}} <-
           DecoderNative.decode_frame(native, buffer) do
      <<_used::binary-size(frame_size), rest::binary>> = buffer
      decode_buffer(native, rest, acc <> decoded_frame, bytes_used + frame_size)
    else
      {:error, :buflen} ->
        {:ok, {acc, bytes_used}}

      {:error, {:recoverable, reason, bytes_to_skip}} ->
        warn_error("Skipping malformed frame", reason)
        <<_used::binary-size(bytes_to_skip), new_buffer::binary>> = buffer
        # TODO send discontinuity event
        decode_buffer(native, new_buffer, acc, bytes_used + bytes_to_skip)

      {:error, {:malformed, reason}} ->
        warn_error("Terminating stream because of malformed frame", reason)
        {:error, reason}
    end
  end
end
