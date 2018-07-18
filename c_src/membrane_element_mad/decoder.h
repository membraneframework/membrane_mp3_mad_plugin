/**
 * Membrane Element: MP3 decoder - Erlang native interface for libmad-based decoder
 */
#ifndef __DECODER_H__
#define __DECODER_H__

#include <stdio.h>
#include <erl_nif.h>
#include <membrane/membrane.h>
#define MEMBRANE_LOG_TAG "Membrane.Element.Mad.DecoderNative"
#include <membrane/log.h>
#include <limits.h>
#include <string.h>
#include <mad.h>

typedef struct _DecoderHandle DecoderHandle;

struct _DecoderHandle
{
  struct mad_stream* mad_stream;
  struct mad_frame* mad_frame;
  struct mad_synth* mad_synth;
};

#endif
