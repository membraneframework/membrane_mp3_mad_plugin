#pragma once

#include <erl_nif.h>
#include <membrane/membrane.h>
#define MEMBRANE_LOG_TAG "Membrane.Element.Mad.DecoderNative"
#include <membrane/log.h>
#include <limits.h>
#include <string.h>
#include <mad.h>

typedef struct _DecoderState State;

struct _DecoderState
{
  struct mad_stream* mad_stream;
  struct mad_frame* mad_frame;
  struct mad_synth* mad_synth;
};

#include "decoder_interface.h"
#include "decoder_res.h"

ERL_NIF_TERM create(ErlNifEnv* env);
ERL_NIF_TERM decode_frame(ErlNifEnv* env, ErlNifBinary buffer, State* state);
void handle_destroy_state(ErlNifEnv* env, State* state);
