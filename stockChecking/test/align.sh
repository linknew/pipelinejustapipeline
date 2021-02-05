#! /bin/bash

. comm.lib
doStart

function Help
{
    echo -ne "
    Descript:
        -

    Usage: ${0} [regExp] [--help] textFile

        --help,

    Note:
        -

    Default:
        -
\n"
}

for i in "${@}"
do
    [[ ${i} == "--help" ]] && Help && doExit 0
    [[ ${i:0:1} == "/" ]]  && regex=$i && continue ;
    [[ ${i:0:2} == "!/" ]] && regex=${i:1} && ignore=1 && continue ;
    [[ ${i:0:1} == "-" ]]  && echo "*! Unknown option:$i">&2 && doExit -1
    [[ -n $list ]] && echo "*! Multipule list specified">&2 && doExit -1
    textFile=$i
done

sed -n -E "$regex"${ignore:+d;}p\; $textFile |
awk '
    BEGIN{
        cntField = 0 ;
    }

    {
        for(i=1; i<=NF; i++){
            len = length($i) ;
            if(len > lenArry[i]) lenArry[i] = len ;
        }

        cont[NR] = $0 ;
        if(NF > cntField) cntField = NF ;
    }

    END{
        for(i=1; i<=NR; i++){
            for(j=1; j<=cntField; j++){
                split(cont[i], arry) ;
                fmt = "%" lenArry[j] "s " ;
                printf(fmt, arry[j]) ;
            }
            print "" ;
        }
    }

    '

doExit
