defmodule Membrane.Element.Mad.Decoder do
  @moduledoc """
  Decodes MPEG audio to raw data in S24LE format
  """
  use Membrane.Element.Base.Filter
  alias Membrane.Caps.Audio.{Raw, MPEG}
  alias __MODULE__.Native
  alias Membrane.{Buffer, Payload}
  use Membrane.Log

  def_known_source_pads source: {:always, :pull, {Raw, format: :s24le}}

  def_known_sink_pads sink: {:always, {:pull, demand_in: :buffers}, [:any, MPEG]}

  @impl true
  def handle_init(_) do
    {:ok, %{queue: nil, native: nil, source_caps: nil}}
  end

  @impl true
  def handle_prepare(:stopped, _, state) do
    with {:ok, native} <- Native.create() do
      {:ok, %{state | native: native}}
    else
      {:error, reason} -> {{:error, reason}, state}
    end
  end

  def handle_prepare(_, _, state), do: {:ok, state}

  @impl true
  def handle_demand(:source, size, :buffers, _, state) do
    {{:ok, demand: {:sink, size}}, state}
  end

  def handle_demand(:source, _size, :bytes, _, state) do
    {{:ok, demand: :sink}, state}
  end

  @impl true
  def handle_process1(:sink, buffer, ctx, %{queue: nil} = state) do
    queue = buffer.payload |> Payload.type() |> Payload.empty_of_type()
    handle_process1(:sink, buffer, ctx, %{state | queue: queue})
  end

  def handle_process1(:sink, buffer, _, state) do
    to_decode =
      if Payload.size(state.queue) == 0 do
        buffer.payload
      else
        Payload.concat(state.queue, buffer.payload)
      end

    debug(inspect({:handle_process, length: Payload.size(to_decode)}))

    case decode_buffer(state.native, state.source_caps, to_decode) do
      {:ok, {new_queue, commands, new_caps}} ->
        {{:ok, commands}, %{state | source_caps: new_caps, queue: new_queue}}

      {:error, reason} ->
        {{:error, reason}, state}
    end
  end

  # first call
  defp decode_buffer(native, previous_caps, buffer) do
    decode_buffer(native, buffer, 0, previous_caps, [])
  end

  # empty buffer
  defp decode_buffer(native, payload, offset, previous_caps, acc) do
    if Payload.size(payload) == offset do
      empty = payload |> Payload.type() |> Payload.empty_of_type()
      {:ok, {empty, Enum.reverse(acc), previous_caps}}
    else
      with {:ok, {decoded_frame, frame_size, sample_rate, channels}} <-
             Native.decode_frame(payload, offset, native) do
        new_caps = %Raw{format: :s24le, sample_rate: sample_rate, channels: channels}

        new_acc =
          case new_caps do
            ^previous_caps ->
              acc

            _ ->
              [{:caps, {:source, new_caps}} | acc]
          end

        new_acc = [{:buffer, {:source, %Buffer{payload: decoded_frame}}} | new_acc]

        decode_buffer(native, payload, offset + frame_size, new_caps, new_acc)
      else
        {:error, :buflen} ->
          partial_frame = Payload.drop(payload, offset)
          {:ok, {partial_frame, Enum.reverse(acc), previous_caps}}

        {:error, {:recoverable, bytes_to_skip}} ->
          warn("Skipping malformed frame (#{bytes_to_skip} bytes)")

          new_offset = offset + bytes_to_skip

          case acc do
            [{:event, _} | _] ->
              # send only one discontinuity event in a row
              decode_buffer(native, payload, new_offset, previous_caps, acc)

            _ ->
              discontinuity = {:event, {:source, Membrane.Event.discontinuity(nil)}}
              decode_buffer(native, payload, new_offset, previous_caps, [discontinuity | acc])
          end

        {:error, :malformed} ->
          warn("Terminating stream because of malformed frame")
          {:error, :malformed}
      end
    end
  end
end
