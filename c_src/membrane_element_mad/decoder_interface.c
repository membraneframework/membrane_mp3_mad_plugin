#include "decoder_interface.h"

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
  
  UNIFEX_UTIL_PARSE_BINARY_ARG(0, dupa)
	UNIFEX_UTIL_PARSE_RESOURCE_ARG(1, state, State, STATE_RESOURCE_TYPE)
  return decode_frame(env, dupa, state);
}

static ErlNifFunc nif_funcs[] =
{
  {"create", 0, export_create, 0},
	{"decode_frame", 2, export_decode_frame, 0}
};

ERL_NIF_INIT(Elixir.Membrane.Element.Mad.Decoder.Native.Nif, nif_funcs, load, NULL, NULL, NULL)

