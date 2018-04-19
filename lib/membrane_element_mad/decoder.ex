defmodule Membrane.Element.Mad.Decoder do
  @moduledoc """
  Decodes MPEG audio to raw data in S24LE format
  """
  use Membrane.Element.Base.Filter
  alias Membrane.Caps.Audio.{Raw, MPEG}
  alias Membrane.Element.Mad.DecoderNative
  alias Membrane.Buffer
  use Membrane.Mixins.Log

  def_options []

  def_known_source_pads [
    {:source, {:always, :pull, :any}}
  ]

  def_known_sink_pads sink: {:always, {:pull, demand_in: :buffers}, {Raw, format: :s24le}}

  @impl true
  def handle_init(_) do
    {:ok, %{queue: <<>>, native: nil, source_caps: nil}}
  end

  @impl true
  def handle_prepare(:stopped, state) do
    with {:ok, native} <- DecoderNative.create() do
      {:ok, %{state | native: native}}
    else
      {:error, reason} -> {{:error, reason}, state}
    end
  end

  def handle_prepare(_, state), do: {:ok, state}

  @impl true
  def handle_demand(:source, size, :buffers, _, state) do
    {{:ok, demand: {:sink, size}}, state}
  end

  def handle_demand(:source, _size, :bytes, _, state) do
    {{:ok, demand: :sink}, state}
  end

  @impl true
  def handle_process1(:sink, buffer, _, state) do
    to_decode = state.queue <> buffer.payload
    debug(inspect({:handle_process, length: byte_size(to_decode)}))

    case decode_buffer(state.native, state.source_caps, to_decode) do
      {:ok, {new_queue, commands, new_caps}} ->
        commands_reversed = commands |> Enum.reverse
        {{:ok, commands_reversed}, %{state | source_caps: new_caps, queue: new_queue}}

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
    {:ok, {<<>>, acc, previous_caps}}
  end

  # non empty buffer
  defp decode_buffer(native, buffer, previous_caps, acc) when byte_size(buffer) > 0 do
    with {:ok, {decoded_frame, frame_size, sample_rate, channels}} <-
           DecoderNative.decode_frame(native, buffer) do
      new_caps = %Raw{format: :s24le, sample_rate: sample_rate, channels: channels}

      new_acc =
        case new_caps do
          ^previous_caps -> acc
          _ ->
            [{:caps, {:source, new_caps}} | acc]
        end

      new_acc = [{:buffer, {:source, %Buffer{payload: decoded_frame}}} | new_acc]

      <<_used::binary-size(frame_size), rest::binary>> = buffer
      decode_buffer(native, rest, new_caps, new_acc)
    else
      {:error, :buflen} ->
        {:ok, {buffer, acc, previous_caps}}

      {:error, {:recoverable, reason, bytes_to_skip}} ->
        #warn_error("Skipping malformed frame", reason)
        <<_used::binary-size(bytes_to_skip), new_buffer::binary>> = buffer
        discontinuity = {:event, {:source, Membrane.Event.discontinuity(nil)}}
        decode_buffer(native, new_buffer, previous_caps, [discontinuity | acc])

      {:error, {:malformed, reason}} ->
        warn_error("Terminating stream because of malformed frame", reason)
        {:error, reason}
    end
  end
end
