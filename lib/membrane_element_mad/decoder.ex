defmodule Membrane.Element.Mad.DecoderOptions do
  defstruct \
    sample_rate: 48000
end


defmodule Membrane.Element.Mad.Decoder do
  use Membrane.Element.Base.Filter
  alias Membrane.Element.Mad.DecoderNative
  alias Membrane.Element.Mad.DecoderOptions

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

  def handle_buffer(caps, data, %{native: native, queue: queue} = state) do
    to_decode = queue <> data
    {:ok, {decoded_audio, unused_bytes}} = DecoderNative.decode_buffer(native, to_decode)
    used_bytes = byte_size(to_decode) - unused_bytes
    << _used :: binary-size(used_bytes), rest :: binary >> = data  <> queue
    {:send_buffer, {caps, decoded_audio}, %{state | queue: rest}}
  end
end