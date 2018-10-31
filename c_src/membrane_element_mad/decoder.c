#include "decoder.h"

//libmad produces 24-bit samples = 3 bytes
#define BYTES_PER_SAMPLE 3

static int fixed_to_s24le(mad_fixed_t sample);
static UNIFEX_TERM create_mad_stream_error(UnifexEnv* env, struct mad_stream* mad_stream);

/**
 * Initializes mad_stream, mad_frame, mad_synth and returns State resource
 * No arugments are expected
 * On success, should return {:ok, decoder_state}
 */
UNIFEX_TERM create(UnifexEnv* env) {
  State *state = unifex_alloc_state(env);

  state->mad_stream = unifex_alloc(sizeof(struct mad_stream));
  state->mad_frame = unifex_alloc(sizeof(struct mad_frame));
  state->mad_synth = unifex_alloc(sizeof(struct mad_synth));

  mad_stream_init(state->mad_stream);
  mad_synth_init(state->mad_synth);
  mad_frame_init(state->mad_frame);

  UNIFEX_TERM res = create_result_ok(env, state);
  unifex_release_state(env, state);
  return res;
}

/*
 * Decodes one frame from input
 *
 * Expects arguments:
 * - native resource
 * - buffer to decode
 *
 * Returns one of:
 * - tuple {:ok, {decoded_audio, bytes_used, sample_rate, channels}}
 *    decoded_audio is a bitstring with interleaved channels
 * - {:error, :buflen} - when input buffer is too small
 * - {:error, {:recoverable, reason, bytes_to_skip}}
 * - {:error, {:malformed, reason}}
 */
UNIFEX_TERM decode_frame(UnifexEnv* env, UnifexPayload * in_payload, State* state) {
  UNIFEX_TERM result;
  size_t bytes_used;

  struct mad_synth *mad_synth;
  struct mad_frame *mad_frame;
  struct mad_stream *mad_stream;

  mad_synth = state->mad_synth;
  mad_stream = state->mad_stream;
  mad_frame = state->mad_frame;

  mad_stream_buffer(mad_stream, in_payload->data, in_payload->size);

  if(mad_frame_decode(mad_frame, mad_stream)) {
    return create_mad_stream_error(env, mad_stream);
  }

  mad_synth_frame(mad_synth, mad_frame);

  if(!mad_stream->next_frame){
    bytes_used = in_payload->size;
  }
  else {
    bytes_used = mad_stream->next_frame - mad_stream->buffer;
  }


  int channels = MAD_NCHANNELS(&(mad_frame->header));
  size_t decoded_frame_size = channels * mad_synth->pcm.length * BYTES_PER_SAMPLE;

  UnifexPayload * out_payload = unifex_payload_alloc(env, in_payload->type, decoded_frame_size);
  unsigned char* data_ptr = out_payload->data;


  for (int i=0; i<mad_synth->pcm.length; i++) {
    int pcm = fixed_to_s24le(mad_synth->pcm.samples[0][i]);
    *(data_ptr++) = (pcm >> 16) & 0xff;
    *(data_ptr++) = (pcm >> 8) & 0xff;
    *(data_ptr++) = pcm & 0xff;

    if(channels == 2) {
      pcm = fixed_to_s24le(mad_synth->pcm.samples[1][i]);
      *(data_ptr++) = (pcm >> 16) & 0xff;
      *(data_ptr++) = (pcm >> 8) & 0xff;
      *(data_ptr++) = pcm & 0xff;
    }
  }

  result = decode_frame_result_ok(env, out_payload, bytes_used, mad_synth->pcm.samplerate, channels);
  unifex_payload_release_ptr(&out_payload);
  return result;
}

void handle_destroy_state(UnifexEnv* env, State* state) {
  if(state) {
    if(state->mad_stream){
      mad_stream_finish(state->mad_stream);
      unifex_free(state->mad_stream);
    }
    if(state->mad_frame){
      mad_frame_finish(state->mad_frame);
      unifex_free(state->mad_frame);
    }
    if(state->mad_synth){
      mad_synth_finish(state->mad_synth);
      unifex_free(state->mad_synth);
    }
  } else {
    MEMBRANE_WARN(env, "MAD: Decoder state already released");
  }
}

static int fixed_to_s24le(mad_fixed_t sample) {
  /* round */
  sample += (1L << (MAD_F_FRACBITS - 24));

  /* Clipping */
  if(sample>=MAD_F_ONE)
    return(SHRT_MAX);
  if(sample<=-MAD_F_ONE)
    return(-SHRT_MAX);

  /* quantize and scale */
  int be = sample >> (MAD_F_FRACBITS + 1 - 24);

  /* convert be to le */
  unsigned short le = be & 0xff;
  le <<= 8;
  le += (be >> 8) & 0xff;
  le <<= 8;
  le += (be >> 16) & 0xff;

  return le;
}


static UNIFEX_TERM create_mad_stream_error(UnifexEnv* env, struct mad_stream* mad_stream) {
  const char *description = mad_stream_errorstr(mad_stream);

  // no enough buffer to decode next frame
  if(mad_stream->error == MAD_ERROR_BUFLEN) {
    return decode_frame_result_error_buflen(env);
  }

  if(!MAD_RECOVERABLE(mad_stream->error)) {
    MEMBRANE_WARN(env, "MAD recoverable error, reason: %s", description);
    return decode_frame_result_error_malformed(env);
  }

  //error is recoverable
  mad_stream->error = 0;

  MEMBRANE_WARN(env, "MAD error, reason: %s", description);
  return decode_frame_result_error_recoverable(env, mad_stream->next_frame - mad_stream->buffer);
}
