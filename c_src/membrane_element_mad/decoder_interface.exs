[
  module: Membrane.Element.Mad.Decoder.Native,
  functions: [
    create: [],
    decode_frame: [buffer: :buffer, state: :state]
  ],
  results: [
    create: [
      ok: [state: :state]
    ],
    decode: [
      ok: [buffer: :buffer, bytes_used: :long, sample_rate: :long, channels: :int],
      error: [buflen: [], malformed: [], recoverable: [bytes_to_skip: :int]]
    ]
  ]
]
