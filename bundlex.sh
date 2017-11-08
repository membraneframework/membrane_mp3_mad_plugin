#!/bin/sh
mkdir -p priv/lib
cc -fPIC -W -dynamiclib -undefined dynamic_lookup -o priv/lib/membrane_element_mad_decoder.so -I"/usr/local/Cellar/erlang/20.0.5/lib/erlang/usr/include" -I"../membrane_common_c/c_src" -I"./deps/membrane_common_c/c_src"  -I/usr/local/opt/mad/include -L/usr/local/opt/mad/lib -lmad -lm "c_src/decoder.c"
