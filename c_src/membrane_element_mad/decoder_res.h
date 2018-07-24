#pragma once

#include <stdio.h>
#include <erl_nif.h>
#include <membrane/membrane.h>
#include "decoder.h"

ERL_NIF_TERM decode_success_result(ErlNifEnv* env, ERL_NIF_TERM binary, long bytes_used, long sample_rate, int channels);
ERL_NIF_TERM create_result(ErlNifEnv* env, State* state);
ERL_NIF_TERM decode_buflen_failure_result(ErlNifEnv* env);
ERL_NIF_TERM decode_malformed_failure_result(ErlNifEnv* env, const char* description);
ERL_NIF_TERM decode_recoverable_failure_result(ErlNifEnv* env, const char* description, int bytes_to_skip);
