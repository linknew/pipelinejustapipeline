#! /bin/bash

source $(dirname $(readlink -f $0))/../lib/comm.lib


#@ for example:

#@ before serialize
# a    x x x
# a    x x x
# a    x x x
# b    x x x
# b    x x x
# c    x x x
# c    x x x
# c    x x x

#@ after serialize
# a    x x x
# a-1  x x x
# a-2  x x x
# b    x x x
# b-1  x x x
# c    x x x
# c-1  x x x
# c-2  x x x


echo -ne "*executing $0($$)\n" >&2

for i in "${@}"
do
    [[ ${i%%=*} == "--describtion" ]] && describtion=${i#*=} && continue
    [[ ${i%%=*} == "--format" ]] && printFmt=${i#*=} && continue
    [[ ${i%%=*} == "--seed" ]] && seedIdx=${i#*=} && continue
    [[ ${i:0:1} == "-" ]] && echo "unknown option:$i">&2 && doExit -1
done

seedIdx=${seedIdx:-1}
printFmt=${printFmt:-'"%s %s\n",$'"$seedIdx"',$0'}

echo *seedIdx="$seedIdx" >&2
echo *printFmt="$printFmt" >&2

awk                                 \
    -v seedIdx="$seedIdx"           \
    -v describtion="$describtion"   \
    '
    BEGIN{
        if(describtion) print describtion ;
    }

    !/#/{
        if(seed == $seedIdx){
            #update
            cnt ++ ;
            $seedIdx = $seedIdx"-"cnt ;
        }else{
            #set new seed
            cnt = 0 ;
            seed = $seedIdx
        }

        printf('"$printFmt"') ;
    }
    '

doExit 0
