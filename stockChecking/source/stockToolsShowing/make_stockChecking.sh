#! /bin/bash

cd $(dirname $(readlink -f $0))
g++ stockChecking.cpp view.cpp -g   \
    -DTHREAD_SUPPORT		    \
    -I/usr/local/include/opencv4    \
    -L/usr/local/lib -lopencv_core -lopencv_highgui -lopencv_imgproc -lopencv_videoio	\
    -o stockChecking
mv stockChecking ../../bin
