#include "decoder_res.h"

ERL_NIF_TERM create_result(ErlNifEnv* env, State* state) {
  ERL_NIF_TERM decoder_term = enif_make_resource(env, state);
  enif_release_resource(state);

  return membrane_util_make_ok_tuple(env, decoder_term);
}

ERL_NIF_TERM decode_success_result(ErlNifEnv* env, ERL_NIF_TERM binary, long bytes_used, long sample_rate, int channels) {
  return membrane_util_make_ok_tuple(env,
    enif_make_tuple4(
      env,
      binary,
      enif_make_long(env, bytes_used),
      enif_make_long(env, sample_rate),
      enif_make_int(env, channels)
    )
  );
}

ERL_NIF_TERM decode_buflen_failure_result(ErlNifEnv* env) {
  return membrane_util_make_error(env, enif_make_atom(env, "buflen"));
}

ERL_NIF_TERM decode_malformed_failure_result(ErlNifEnv* env, const char* description) {
  return membrane_util_make_error(env, enif_make_tuple2(
    env,
    enif_make_atom(env, "malformed"),
    enif_make_string(env, description, ERL_NIF_LATIN1)
  ));
}

ERL_NIF_TERM decode_recoverable_failure_result(ErlNifEnv* env, const char* description, int bytes_to_skip) {
  return membrane_util_make_error(env, enif_make_tuple3(
    env,
    enif_make_atom(env, "recoverable"),
    enif_make_string(env, description, ERL_NIF_LATIN1),
    enif_make_int(env, bytes_to_skip)
  ));
}
