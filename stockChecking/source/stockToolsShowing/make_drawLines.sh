#! /bin/bash

cd $(dirname $(readlink -f $0))
g++ drawLines.cpp -g		    \
    -DTHREAD_SUPPORT		    \
    -I/usr/local/include/opencv4    \
    -L/usr/local/lib -lopencv_core -lopencv_highgui -lopencv_imgproc -lopencv_videoio	\
    -o drawLines
mv drawLines ../../bin
