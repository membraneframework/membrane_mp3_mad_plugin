/**
 * Membrane Element: MP3 decoder - Erlang native interface for libmad-based decoder
 *
 * All Rights Reserved, (c) 2016 Marcin Lewandowski
 */
#ifndef __DECODER_H__
#define __DECODER_H__

#include <stdio.h>
#include <erl_nif.h>
#include <membrane/membrane.h>
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