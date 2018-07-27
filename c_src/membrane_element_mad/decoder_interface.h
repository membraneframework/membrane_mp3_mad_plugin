#pragma once

#include <stdio.h>
#include <erl_nif.h>
#include <unifex/util.h>
#include "decoder.h"

ErlNifResourceType *STATE_RESOURCE_TYPE;

ERL_NIF_TERM create_ok_result(ErlNifEnv* env, State* state);
ERL_NIF_TERM decode_ok_result(ErlNifEnv* env, ERL_NIF_TERM buffer, long bytes_used, long sample_rate, int channels);
ERL_NIF_TERM decode_error_buflen_result(ErlNifEnv* env);
ERL_NIF_TERM decode_error_malformed_result(ErlNifEnv* env);
ERL_NIF_TERM decode_error_recoverable_result(ErlNifEnv* env, int bytes_to_skip);
