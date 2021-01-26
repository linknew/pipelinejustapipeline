#stockChecking
cmake_minimum_required(VERSION 2.8)
project( stockChecking )
find_package( OpenCV REQUIRED )
include_directories( ${OpenCV_INCLUDE_DIRS} )
add_executable( stockChecking stockChecking.cpp view.cpp)
target_link_libraries( stockChecking ${OpenCV_LIBS} )

##_genRelationShipMap
#cmake_minimum_required(VERSION 2.8)
#project( _genRelationShipMap )
#find_package( OpenCV REQUIRED )
#include_directories( ${OpenCV_INCLUDE_DIRS} )
#add_executable( _genRelationShipMap _genRelationShipMap.cpp )
#target_link_libraries( _genRelationShipMap ${OpenCV_LIBS} )

##drawLines
#cmake_minimum_required(VERSION 2.8)
#project( drawLines )
#find_package( OpenCV REQUIRED )
#include_directories( ${OpenCV_INCLUDE_DIRS} )
#add_executable( drawLines drawLines.cpp view.cpp)
#target_link_libraries( drawLines ${OpenCV_LIBS} )

