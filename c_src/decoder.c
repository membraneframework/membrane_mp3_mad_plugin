#include "decoder.h"

#define MEMBRANE_LOG_TAG "Membrane.Element.Mad.DecoderNative"

ErlNifResourceType *RES_DECODER_HANDLE_TYPE;

void res_decoder_handle_destructor(ErlNifEnv* env, void* value) {
  DecoderHandle *handle = (DecoderHandle*) value;
  mad_stream_finish(handle->mad_stream);
  mad_frame_finish(handle->mad_frame);
  mad_synth_finish(handle->mad_synth);
  free(handle);
}

int load(ErlNifEnv* env, void** priv_data, ERL_NIF_TERM load_info) {
  int flags = ERL_NIF_RT_CREATE | ERL_NIF_RT_TAKEOVER;
  RES_DECODER_HANDLE_TYPE = 
    enif_open_resource_type(env, NULL, "DecoderHandle", res_decoder_handle_destructor, flags, NULL);
  return 0;
}


/**
 * Initializes mad_stream, mad_frame, mad_synth and returns decoder_handle resource,
 */
static ERL_NIF_TERM export_create(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) {
  DecoderHandle *handle = enif_alloc_resource(RES_DECODER_HANDLE_TYPE, sizeof(DecoderHandle));

  handle->mad_stream = malloc(sizeof(struct mad_stream));
  handle->mad_frame = malloc(sizeof(struct mad_frame));
  handle->mad_synth = malloc(sizeof(struct mad_synth));

  mad_stream_init(handle->mad_stream);
  mad_synth_init(handle->mad_synth);
  mad_frame_init(handle->mad_frame);

  MEMBRANE_DEBUG("Initialized mad decoder");

  ERL_NIF_TERM decoder_term = enif_make_resource(env, handle);
  enif_release_resource(handle);

  return membrane_util_make_ok_tuple(env, decoder_term);
}


unsigned short fixed_to_s16le(mad_fixed_t sample) {
  /* round */
  sample += (1L << (MAD_F_FRACBITS - 16));

  /* Clipping */
  if(sample>=MAD_F_ONE)
    return(SHRT_MAX);
  if(sample<=-MAD_F_ONE)
    return(-SHRT_MAX);

  /* quantize and scale */
  unsigned short be = sample >> (MAD_F_FRACBITS + 1 - 16);
  
  /* convert be to le */
  unsigned short le = be & 0xff << 8;
  le <<= 8;
  le += (be >> 8);
  
  return le;
}


static ERL_NIF_TERM create_mad_error(ErlNifEnv* env, const char* description, int recoverable) {
  ERL_NIF_TERM tuple[2] = {
    enif_make_atom(env, recoverable ? "recoverable_error" : "error"),
    enif_make_string(env, description, ERL_NIF_LATIN1) 
  };

  return enif_make_tuple_from_array(env, tuple, 2);
}

/*
 * Decodes one frame from input
 * 
 * Expects arguments:
 * - native resource
 * - buffer to decode
 *
 * Returns one of:
 * - tuple {:ok, {decoded_audio, bytes_used}}
 *    decoded_audio is a bitstring with interleaved channels
 * - :buflen_error - when input buffer is too small
 * - {:recoverable_error, description}
 * - {:error, description}
 */
static ERL_NIF_TERM export_decode_frame(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  DecoderHandle *handle;
  ErlNifBinary buffer;
  size_t bytes_used;

  struct mad_synth *mad_synth;
  struct mad_frame *mad_frame;
  struct mad_stream *mad_stream;

  if(!enif_get_resource(env, argv[0], RES_DECODER_HANDLE_TYPE, (void **) &handle)) {
    return membrane_util_make_error_args(env, "native", "Passed native decoder is not a valid resource");
  }

  mad_synth = handle->mad_synth;
  mad_stream = handle->mad_stream;
  mad_frame = handle->mad_frame;

  if(!enif_inspect_binary(env, argv[1], &buffer)) {
        return membrane_util_make_error_args(env, "buffer", "Passed buffer is not valid binary");
  }

  mad_stream_buffer(mad_stream, buffer.data, buffer.size);
  mad_stream->error=0;

  if(mad_frame_decode(mad_frame, mad_stream)) {
    // no enough buffer to decode next frame
    if(mad_stream->error == MAD_ERROR_BUFLEN) {    
      return enif_make_atom(env, "buflen_error");
    }
    else {
      char const *description = mad_stream_errorstr(mad_stream);
      mad_stream->error = 0;
      return create_mad_error(env, description, MAD_RECOVERABLE(mad_stream->error));
    }
  }

  mad_synth_frame(mad_synth, mad_frame);
  if(!mad_stream->next_frame){
    bytes_used = buffer.size;
  }
  else {
    bytes_used = mad_stream->next_frame - mad_stream->buffer;  
  }
  
  int channels = MAD_NCHANNELS(&(mad_frame->header));
  size_t decoded_frame_size = channels * mad_synth->pcm.length * sizeof(short);
  
  ERL_NIF_TERM binary_term, output_term;
  unsigned char *data_ptr;
  data_ptr = enif_make_new_binary(env, decoded_frame_size, &binary_term);

  for (int i=0; i<mad_synth->pcm.length; i++) {
    short pcm = fixed_to_s16le(mad_synth->pcm.samples[0][i]);
    *(data_ptr++) = pcm >> 8;
    *(data_ptr++) = pcm & 0xff;

    if(channels == 2) {
      pcm = fixed_to_s16le(mad_synth->pcm.samples[1][i]);
      *(data_ptr++) = pcm >> 8;
      *(data_ptr++) = pcm & 0xff;
    }
  }


  ERL_NIF_TERM out_arr[2] = {
    binary_term,
    enif_make_long(env, bytes_used)
  };
  output_term = enif_make_tuple_from_array(env, out_arr, 2);

  return membrane_util_make_ok_tuple(env, output_term);
}


static ErlNifFunc nif_funcs[] =
{
  {"create", 0, export_create},
  {"decode_frame", 2, export_decode_frame}
};

ERL_NIF_INIT(Elixir.Membrane.Element.Mad.DecoderNative, nif_funcs, load, NULL, NULL, NULL)
