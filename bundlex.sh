#!/bin/sh
cc -fPIC -W -dynamiclib -undefined dynamic_lookup -o membrane_element_mad_decoder.so -I"/usr/local/Cellar/erlang/19.3/lib/erlang/usr/include" -I"../membrane_common_c/c_src" -I"./deps/membrane_common_c/c_src" -lmad  "c_src/decoder.c"
