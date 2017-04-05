#!/bin/sh
cc -fPIC -W -dynamiclib -undefined dynamic_lookup -o membrane_element_mad_decoder.so -I"/usr/local/Cellar/erlang/19.3/lib/erlang/usr/include" -I"../membrane_common_c/c_src" -I"./deps/membrane_common_c/c_src"  -I/usr/local/opt/mad/include -L/usr/local/opt/mad/lib -lmad -lm "c_src/decoder.c"
