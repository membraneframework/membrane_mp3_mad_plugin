module Membrane.Element.Mad.Decoder.Native

spec create() :: {:ok :: label, state}

spec decode_frame(payload, offset :: int, state) ::
       {:ok :: label, {payload, bytes_used :: long, sample_rate :: long, channels :: int}}
       | {:error :: label, :buflen :: label}
       | {:error :: label, :malformed :: label}
       | {:error :: label, {:recoverable :: label, bytes_to_skip :: int}}
