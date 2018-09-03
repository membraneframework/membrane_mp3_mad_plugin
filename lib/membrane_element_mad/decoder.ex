defmodule Membrane.Element.Mad.Decoder do
  @moduledoc """
  Decodes MPEG audio to raw data in S24LE format
  """
  use Membrane.Element.Base.Filter
  alias Membrane.Caps.Audio.{Raw, MPEG}
  alias __MODULE__.Native
  alias Membrane.Buffer
  use Membrane.Log

  def_known_source_pads source: {:always, :pull, {Raw, format: :s24le}}

  def_known_sink_pads sink: {:always, {:pull, demand_in: :buffers}, [:any, MPEG]}

  @impl true
  def handle_init(_) do
    {:ok, %{queue: <<>>, native: nil, source_caps: nil}}
  end

  @impl true
  def handle_prepare(:stopped, _ctx, state) do
    with {:ok, native} <- Native.create() do
      {:ok, %{state | native: native}}
    else
      {:error, reason} -> {{:error, reason}, state}
    end
  end

  def handle_prepare(_, _ctx, state), do: {:ok, state}

  @impl true
  def handle_demand(:source, size, :buffers, _ctx, state) do
    {{:ok, demand: {:sink, size}}, state}
  end

  def handle_demand(:source, _size, :bytes, _ctx, state) do
    {{:ok, demand: :sink}, state}
  end

  @impl true
  def handle_process1(:sink, buffer, _ctx, state) do
    to_decode = state.queue <> buffer.payload
    debug(inspect({:handle_process, length: byte_size(to_decode)}))

    case decode_buffer(state.native, state.source_caps, to_decode) do
      {:ok, {new_queue, commands, new_caps}} ->
        {{:ok, commands}, %{state | source_caps: new_caps, queue: new_queue}}

      {:error, reason} ->
        {{:error, reason}, state}
    end
  end

  # first call
  defp decode_buffer(native, previous_caps, buffer) do
    decode_buffer(native, buffer, previous_caps, [])
  end

  # empty buffer
  defp decode_buffer(_native, <<>>, previous_caps, acc) do
    {:ok, {<<>>, Enum.reverse(acc), previous_caps}}
  end

  # non empty buffer
  defp decode_buffer(native, buffer, previous_caps, acc) when byte_size(buffer) > 0 do
    with {:ok, {decoded_frame, frame_size, sample_rate, channels}} <-
           Native.decode_frame(buffer, native) do
      new_caps = %Raw{format: :s24le, sample_rate: sample_rate, channels: channels}

      new_acc =
        case new_caps do
          ^previous_caps ->
            acc

          _ ->
            [{:caps, {:source, new_caps}} | acc]
        end

      new_acc = [{:buffer, {:source, %Buffer{payload: decoded_frame}}} | new_acc]

      <<_used::binary-size(frame_size), rest::binary>> = buffer
      decode_buffer(native, rest, new_caps, new_acc)
    else
      {:error, :buflen} ->
        {:ok, {buffer, Enum.reverse(acc), previous_caps}}

      {:error, {:recoverable, bytes_to_skip}} ->
        warn("Skipping malformed frame (#{bytes_to_skip} bytes)")
        <<_used::binary-size(bytes_to_skip), new_buffer::binary>> = buffer

        case acc do
          [{:event, _} | _] ->
            # send only one discontinuity event in a row
            decode_buffer(native, new_buffer, previous_caps, acc)

          _ ->
            discontinuity = {:event, {:source, Membrane.Event.discontinuity(nil)}}
            decode_buffer(native, new_buffer, previous_caps, [discontinuity | acc])
        end

      {:error, :malformed} ->
        warn("Terminating stream because of malformed frame")
        {:error, :malformed}
    end
  end
end
