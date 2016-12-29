defmodule Membrane.Element.Mad.DecoderNative do
  
  @on_load :load_nifs

  def load_nifs do
    :ok = :erlang.load_nif('./membrane_element_mad_decoder', 0)
  end

  @spec create() ::
  {:ok, any}
  def create(), do: raise "NIF fail"


  @spec decode_frame(any, bitstring) ::
  {:ok, {bitstring, non_neg_integer}} | :buflen_error | {:error, String} | {:recoverable_error, non_neg_integer, String} 
  def decode_frame(_native, _data), do: raise "NIF fail"

end