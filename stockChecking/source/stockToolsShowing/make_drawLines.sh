#! /bin/bash

g++ drawLines.cpp -g -DTHREAD_SUPPORT `pkg-config --cflags --libs opencv4` -o drawLines
mv drawLines ../../bin
