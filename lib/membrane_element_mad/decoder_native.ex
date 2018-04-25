defmodule Membrane.Element.Mad.DecoderNative do
  require Bundlex.Loader

  @on_load :load_nifs

  @doc false
  def load_nifs do
    Bundlex.Loader.load_nif!(:membrane_element_mad, :decoder)
  end

  @doc """
  Initializes mad_stream, mad_frame, mad_synth and returns DecoderHandle resource
  No arugments are expected
  On success, should return {:ok, decoder_handle}
  """
  @spec create() :: {:ok, any}
  def create(), do: raise("NIF fail")

  @doc """
  Decodes one frame from input
  Expects 2 arguments:
   - native resource
   - buffer to decode

   Returns one of:
   - tuple {:ok, {decoded_audio, bytes_used, sample_rate, channels}} on success
      decoded_audio is a bitstring with interleaved channels
   - {:error, :buflen} - when input buffer is too small
   - {:error, {:recoverable, reason, bytes_to_skip}}
   - {:error, {:malformed, reason}}
  """
  @spec decode_frame(any, bitstring) ::
          {:ok, {bitstring, non_neg_integer, non_neg_integer, non_neg_integer}} | {:error, any}
  def decode_frame(_native, _data), do: raise("NIF fail")
end
