linux: unix

darwin: unix

unix: priv/membrane_element_mad_decoder.so

priv/membrane_element_mad_decoder.so:
	cc -fPIC -I../membrane_common_c/include -I./deps/membrane_common_c/include -I/usr/local/erlang/usr/include/ -lmad -rdynamic -undefined -shared -o membrane_element_mad_decoder.so c_src/decoder.c
