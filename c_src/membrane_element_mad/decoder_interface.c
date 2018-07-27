#include "decoder_interface.h"

ERL_NIF_TERM create_ok_result(ErlNifEnv* env, State* state) {
  return enif_make_tuple2(
    env,
    enif_make_atom(env, "ok"),
    unifex_util_make_and_release_resource(env, state)
  );
}

ERL_NIF_TERM decode_ok_result(ErlNifEnv* env, ERL_NIF_TERM buffer, long bytes_used, long sample_rate, int channels) {
  return enif_make_tuple2(
    env,
    enif_make_atom(env, "ok"),
    enif_make_tuple_from_array(
      env,
      (ERL_NIF_TERM []) {
        buffer,
    		enif_make_long(env, bytes_used),
    		enif_make_long(env, sample_rate),
    		enif_make_int(env, channels)
      },
      4
    )
  );
}

ERL_NIF_TERM decode_error_buflen_result(ErlNifEnv* env) {
  return enif_make_tuple2(
    env,
    enif_make_atom(env, "error"),
    enif_make_atom(env, "buflen")
  );
}

ERL_NIF_TERM decode_error_malformed_result(ErlNifEnv* env) {
  return enif_make_tuple2(
    env,
    enif_make_atom(env, "error"),
    enif_make_atom(env, "malformed")
  );
}

ERL_NIF_TERM decode_error_recoverable_result(ErlNifEnv* env, int bytes_to_skip) {
  return enif_make_tuple2(
    env,
    enif_make_atom(env, "error"),
    enif_make_tuple2(
      env,
      enif_make_atom(env, "recoverable"),
      enif_make_int(env, bytes_to_skip)
    )
  );
}

static void destroy_state(ErlNifEnv* env, void* value) {
  State *state = (State*) value;
  handle_destroy_state(env, state);
}

int load(ErlNifEnv* env, void** priv_data, ERL_NIF_TERM load_info) {
  UNIFEX_UTIL_UNUSED(load_info);
  UNIFEX_UTIL_UNUSED(priv_data);

  int flags = ERL_NIF_RT_CREATE | ERL_NIF_RT_TAKEOVER;
  STATE_RESOURCE_TYPE =
   enif_open_resource_type(env, NULL, "State", destroy_state, flags, NULL);
  return 0;
}

static ERL_NIF_TERM export_create(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]){
  UNIFEX_UTIL_UNUSED(argc);
  UNIFEX_UTIL_UNUSED(argv);
  
  return create(env);
}
static ERL_NIF_TERM export_decode_frame(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]){
  UNIFEX_UTIL_UNUSED(argc);
  
  UNIFEX_UTIL_PARSE_BINARY_ARG(0, buffer)
	UNIFEX_UTIL_PARSE_RESOURCE_ARG(1, state, State, STATE_RESOURCE_TYPE)
  return decode_frame(env, buffer, state);
}

static ErlNifFunc nif_funcs[] =
{
  {"create", 0, export_create, 0},
	{"decode_frame", 2, export_decode_frame, 0}
};

ERL_NIF_INIT(Elixir.Membrane.Element.Mad.Decoder.Native.Nif, nif_funcs, load, NULL, NULL, NULL)

