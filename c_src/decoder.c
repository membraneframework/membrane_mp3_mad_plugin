#include <stdio.h>
#include <erl_nif.h>
#include <membrane/membrane.h>
#include <limits.h>
#include <string.h>
#include <mad.h>

#define MEMBRANE_LOG_TAG "Membrane.Element.Mad.DecoderNative"

typedef struct decoded_frame_def { 
    int   length;
    char* data;
    struct decoded_frame_def* next;
} decoded_audio;

ErlNifResourceType *RES_STREAM_TYPE;
ErlNifResourceType *RES_FRAME_TYPE;
ErlNifResourceType *RES_SYNTH_TYPE;

void res_stream_destructor(ErlNifEnv* env, void* stream) {
  MEMBRANE_DEBUG("Destroying stream %p", stream);
  mad_stream_finish((struct mad_stream *) stream);
}

void res_frame_destructor(ErlNifEnv* env, void* frame) {
  MEMBRANE_DEBUG("Destroying frame %p", frame);
  mad_frame_finish((struct mad_frame *) frame);
}

void res_synth_destructor(ErlNifEnv* env, void* synth) {
  MEMBRANE_DEBUG("Destroying synth %p", synth);
  mad_synth_finish((struct mad_synth *) synth);
}

int load(ErlNifEnv* env, void** priv_data, ERL_NIF_TERM load_info) {
  int flags = ERL_NIF_RT_CREATE | ERL_NIF_RT_TAKEOVER;
  RES_STREAM_TYPE = 
    enif_open_resource_type(env, NULL, "Stream", res_stream_destructor, flags, NULL);
  RES_FRAME_TYPE = 
    enif_open_resource_type(env, NULL, "Frame", res_frame_destructor, flags, NULL);
  RES_SYNTH_TYPE = 
    enif_open_resource_type(env, NULL, "Synth", res_synth_destructor, flags, NULL);
  return 0;
}


/**
 * Initializes mad_stream, mad_frame, mad_synth and returns tuple {:ok, native},
 * where native is a tuple of resources: {stream, frame, synth}
 */
static ERL_NIF_TERM export_create(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{

  struct mad_stream* mad_stream;
  struct mad_frame* mad_frame;
  struct mad_synth* mad_synth;

  mad_stream = enif_alloc_resource(RES_STREAM_TYPE, sizeof(struct mad_stream));
  mad_frame = enif_alloc_resource(RES_FRAME_TYPE, sizeof(struct mad_frame));
  mad_synth = enif_alloc_resource(RES_SYNTH_TYPE, sizeof(struct mad_synth));

  mad_stream_init(mad_stream);
  mad_synth_init(mad_synth);
  mad_frame_init(mad_frame);

  MEMBRANE_DEBUG("Initialized mad decoder (%p %p %p)", mad_stream, mad_frame, mad_synth);

  ERL_NIF_TERM stream_term = enif_make_resource(env, mad_stream);
  enif_release_resource(mad_stream);
  ERL_NIF_TERM frame_term = enif_make_resource(env, mad_frame);
  enif_release_resource(mad_frame);
  ERL_NIF_TERM synth_term = enif_make_resource(env, mad_synth);
  enif_release_resource(mad_synth);


  ERL_NIF_TERM tuple[3] = {
    stream_term,
    frame_term,
    synth_term
  };

  return membrane_util_make_ok_tuple(env, enif_make_tuple_from_array(env, tuple, 3));
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

/*
 * Expects arguments:
 * - native resource
 * - buffer to decode
 *
 * Returns one of:
 * - tuple {:ok, {decoded_audio, unused_bytes}}
 *    decoded_audio is a bitstring with interleaved channels 
 * - {:error, description}
 */
static ERL_NIF_TERM export_decode_buffer(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  struct mad_stream* mad_stream;
  struct mad_frame* mad_frame;
  struct mad_synth* mad_synth;
  ERL_NIF_TERM* tuple_arr;
  int arity;
  ErlNifBinary buffer;

  if (!enif_get_tuple(env, argv[0], &arity, (const ERL_NIF_TERM**) &tuple_arr)) {
    return membrane_util_make_error_args(env, "native", "Passed native tuple is not a valid tuple");
  }

  if(!enif_get_resource(env, tuple_arr[0], RES_STREAM_TYPE, (void **) &mad_stream)) {
    return membrane_util_make_error_args(env, "mad_stream", "Passed mad_stream is not a valid resource");
  }

  if(!enif_get_resource(env, tuple_arr[1], RES_FRAME_TYPE, (void **) &mad_frame)) {
    return membrane_util_make_error_args(env, "mad_frame", "Passed mad_frame is not a valid resource");
  }

  if(!enif_get_resource(env, tuple_arr[2], RES_SYNTH_TYPE, (void **) &mad_synth)) {
    return membrane_util_make_error_args(env, "mad_frame", "Passed mad_frame is not a valid resource");
  }
  MEMBRANE_DEBUG("Received mad decoder (%p %p %p)", mad_stream, mad_frame, mad_synth);

  if (!enif_inspect_binary(env, argv[1], &buffer)) {
        return membrane_util_make_error_args(env, "buffer", "Passed buffer is not valid binary");
  }

  mad_stream_buffer(mad_stream, buffer.data, buffer.size);
  
  int remaining = 0;
  int total_output_size = 0;
  decoded_audio* frame_list = NULL;
  decoded_audio* last_frame = NULL;

  mad_stream->error=0;

  while(1) {
    // no enough buffer to decode next frame
    if (mad_stream->error != 0) {
      if (mad_stream->error == MAD_ERROR_BUFLEN) {    
        if (mad_stream->next_frame != NULL) {
          remaining = mad_stream->bufend - mad_stream->next_frame;
        } else {
          remaining = 0;
        } 
        break;
      } 
      else {
        char const *error_str = mad_stream_errorstr(mad_stream);
        if(MAD_RECOVERABLE(mad_stream->error)) {
          fprintf(stderr, "Recoverable error: %s\n", error_str);
          mad_stream->error = 0;
        } else {
          ERL_NIF_TERM error_term = enif_make_string(env, error_str, ERL_NIF_LATIN1);
          return membrane_util_make_error(env, error_term);
        }
      }
    }

    if (mad_frame_decode(mad_frame, mad_stream)) {
      // error will be handled at the begining of the loop
      continue;
    }

    mad_synth_frame(mad_synth, mad_frame);

    unsigned char *data_ptr;
    int channels = MAD_NCHANNELS(&(mad_frame->header));

    long decoded_frame_size = channels * mad_synth->pcm.length * sizeof(short);
    total_output_size += decoded_frame_size;

    decoded_audio* decoded_frame = malloc(sizeof(decoded_audio));
    decoded_frame->data = data_ptr = malloc(decoded_frame_size);    
    decoded_frame->length = decoded_frame_size;

    for (int i=0; i<mad_synth->pcm.length; i++) {
      short pcm = fixed_to_s16le(mad_synth->pcm.samples[0][i]);
      *(data_ptr++) = pcm >> 8;
      *(data_ptr++) = pcm & 0xff;

      if (channels == 2) {
        pcm = fixed_to_s16le(mad_synth->pcm.samples[1][i]);
        *(data_ptr++) = pcm >> 8;
        *(data_ptr++) = pcm & 0xff;
      }
    }

    if (frame_list == NULL) {
      frame_list = last_frame = decoded_frame;
    } else {
      last_frame->next = decoded_frame;
      last_frame = decoded_frame;
    } 
  }

  ERL_NIF_TERM binary_term, output_term;
  unsigned char *output_ptr;
  output_ptr = enif_make_new_binary(env, total_output_size, &binary_term);


  // copy buffers to output_term and release memory
  while (frame_list != NULL) {
    output_ptr = memcpy(output_ptr, frame_list->data, frame_list->length);
    output_ptr += frame_list->length;

    

    free(frame_list->data);
    decoded_audio *tmp = frame_list;
    frame_list = frame_list->next;
    free(tmp);
  }

  ERL_NIF_TERM out_arr[2] = {
    binary_term,
    enif_make_long(env, remaining)
  };
  output_term = enif_make_tuple_from_array(env, out_arr, 2);


  return membrane_util_make_ok_tuple(env, output_term);
}


static ErlNifFunc nif_funcs[] =
{
  {"create", 0, export_create},
  {"decode_buffer", 2, export_decode_buffer}
};

ERL_NIF_INIT(Elixir.Membrane.Element.Mad.DecoderNative, nif_funcs, load, NULL, NULL, NULL)
