ERL_INCLUDE_PATH=/usr/local/Cellar/erlang/19.2/lib/erlang/usr/include/

linux: unix

darwin: unix

unix: priv/membrane_element_mad_decoder.so

priv/membrane_element_mad_decoder.so:
	cc -fPIC -I../membrane_common_c/include -I./deps/membrane_common_c/include -I$(ERL_INCLUDE_PATH) -lmad -rdynamic -undefined dynamic_lookup -shared -o membrane_element_mad_decoder.so c_src/decoder.c
