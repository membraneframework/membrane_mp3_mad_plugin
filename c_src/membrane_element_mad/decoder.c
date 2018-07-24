#include "decoder.h"

//libmad produces 24-bit samples = 3 bytes
#define BYTES_PER_SAMPLE 3

static int fixed_to_s24le(mad_fixed_t sample);
static ERL_NIF_TERM create_mad_stream_error(ErlNifEnv* env, struct mad_stream* mad_stream);

/**
 * Initializes mad_stream, mad_frame, mad_synth and returns State resource
 * No arugments are expected
 * On success, should return {:ok, decoder_state}
 */
ERL_NIF_TERM create(ErlNifEnv* env) {
  State *state = enif_alloc_resource(STATE_RESOURCE_TYPE, sizeof(State));

  state->mad_stream = malloc(sizeof(struct mad_stream));
  state->mad_frame = malloc(sizeof(struct mad_frame));
  state->mad_synth = malloc(sizeof(struct mad_synth));

  mad_stream_init(state->mad_stream);
  mad_synth_init(state->mad_synth);
  mad_frame_init(state->mad_frame);

  return create_result(env, state);
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
ERL_NIF_TERM decode_frame(ErlNifEnv* env, ErlNifBinary buffer, State* state) {
  size_t bytes_used;

  struct mad_synth *mad_synth;
  struct mad_frame *mad_frame;
  struct mad_stream *mad_stream;

  mad_synth = state->mad_synth;
  mad_stream = state->mad_stream;
  mad_frame = state->mad_frame;

  mad_stream_buffer(mad_stream, buffer.data, buffer.size);

  if(mad_frame_decode(mad_frame, mad_stream)) {
    return create_mad_stream_error(env, mad_stream);
  }

  mad_synth_frame(mad_synth, mad_frame);

  if(!mad_stream->next_frame){
    bytes_used = buffer.size;
  }
  else {
    bytes_used = mad_stream->next_frame - mad_stream->buffer;
  }


  int channels = MAD_NCHANNELS(&(mad_frame->header));
  size_t decoded_frame_size = channels * mad_synth->pcm.length * BYTES_PER_SAMPLE;

  ERL_NIF_TERM binary_term;
  unsigned char *data_ptr;
  data_ptr = enif_make_new_binary(env, decoded_frame_size, &binary_term);


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

  return decode_success_result(env, binary_term, bytes_used, mad_synth->pcm.samplerate, channels);
}

void handle_destroy_state(ErlNifEnv* env, State* state) {
  if(state) {
    if(state->mad_stream){
      mad_stream_finish(state->mad_stream);
      free(state->mad_stream);
    }
    if(state->mad_frame){
      mad_frame_finish(state->mad_frame);
      free(state->mad_frame);
    }
    if(state->mad_synth){
      mad_synth_finish(state->mad_synth);
      free(state->mad_synth);
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


static ERL_NIF_TERM create_mad_stream_error(ErlNifEnv* env, struct mad_stream* mad_stream) {
  const char *description = mad_stream_errorstr(mad_stream);

  // no enough buffer to decode next frame
  if(mad_stream->error == MAD_ERROR_BUFLEN) {
    return decode_buflen_failure_result(env);
  }

  if(!MAD_RECOVERABLE(mad_stream->error)) {
    return decode_malformed_failure_result(env, description);
  }

  //error is recoverable
  mad_stream->error = 0;

  return decode_recoverable_failure_result(env, description, mad_stream->next_frame - mad_stream->buffer);
}
