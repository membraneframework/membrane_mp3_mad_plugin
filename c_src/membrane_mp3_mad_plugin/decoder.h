#pragma once

#include <membrane/membrane.h>
#define MEMBRANE_LOG_TAG "Membrane.MP3.MAD.DecoderNative"
#include <limits.h>
#include <mad.h>
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
