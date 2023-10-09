#pragma once

#include <membrane/membrane.h>
#define MEMBRANE_LOG_TAG "Membrane.MP3.MAD.DecoderNative"
#include <limits.h>
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wall"
#pragma GCC diagnostic ignored "-Wextra" 
#include <mad.h>
#pragma GCC diagnostic pop
#include <membrane/log.h>
#include <string.h>
#include <unifex/unifex.h>

typedef struct _DecoderState State;

struct _DecoderState {
  struct mad_stream *mad_stream;
  struct mad_frame *mad_frame;
  struct mad_synth *mad_synth;
};

#include "_generated/decoder.h"
