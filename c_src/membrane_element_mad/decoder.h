#pragma once

#include <erl_nif.h>
#include <membrane/membrane.h>
#define MEMBRANE_LOG_TAG "Membrane.Element.Mad.DecoderNative"
#include <membrane/log.h>
#include <limits.h>
#include <string.h>
#include <mad.h>
#include <unifex/unifex.h>

typedef struct _DecoderState State;

struct _DecoderState
{
  struct mad_stream* mad_stream;
  struct mad_frame* mad_frame;
  struct mad_synth* mad_synth;
};

#include "_generated/decoder.h"

UNIFEX_TERM create(UnifexEnv* env);
UNIFEX_TERM decode_frame(UnifexEnv* env, UnifexPayload buffer, State* state);
void handle_destroy_state(UnifexEnv* env, State* state);
