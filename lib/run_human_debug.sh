#!/bin/bash

# enable multicast and add route for lcm out the top
# sudo ifconfig enxa0cec80e3ced multicast
# sudo route add -net 224.0.0.0 netmask 240.0.0.0 dev enxa0cec80e3ced

sudo ifconfig eth1 multicast
sudo route add -net 224.0.0.0 netmask 240.0.0.0 dev eth1

# configure libraries
sudo LD_LIBRARY_PATH=. ldconfig
#sudo LD_LIBRARY_PATH=. ldd ./robot
if [ -f ./libonnxruntime.so.1.16.1 ] && [ ! -e ./libonnxruntime.so.1 ]; then
    ln -s libonnxruntime.so.1.16.1 libonnxruntime.so.1
fi
sudo LD_LIBRARY_PATH=. "$@"
