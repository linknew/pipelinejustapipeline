#! /bin/bash

. ~/tools/lib/comm.lib

doStart

placeHolderDef="pLaCeHoLdEr"

function Help
{
    echo -ne "
    Usage: ${0} [--placeHolder=STRING] [--help] matrixFile

        --placeHolder
        --help

    Note:
        If space or whitespce is specified as placeholder, 
        the alignment of the matrix may be broken.

    Default: --placeHolder=\"$placeHolderDef\"
\n"
}

for i in "${@}"
do
    [[ ${i} == "--help" ]] && Help && doExit 0
    [[ ${i%%=*} == "--placeHolder" ]] && placeHolder=${i##*=} && continue
    [[ ${i:0:1} == "-" ]] && echo "*! Unknown option:$i">&2 && doExit -1
    [[ -n $matrixFile ]] && echo "*! Multipule matrixFile specified">&2 && doExit -1
    matrixFile=$i
done

placeHolder=${placeHolder:-$placeHolderDef}
_tmpStr=${placeHolder//[ 	]/}
[[ ${#_tmpStr} -ne ${#placeHolder} ]] && 
    showWarn "* placeHolder:'$placeHolder' contains spaces or whitespaces\n* may cause an unreliable aligment\n" >&2


awk -v placeHolder="$placeHolder" '

    (substr($1,1,1) != "#"){
        cntRow ++ ;
        if(NF > cntCol) cntCol = NF ;

        for(i=1; i<=NF; i++) matrix[cntRow,i] = $i ;
    }

    END{
        for(i=1; i<=cntCol; i++){
            for(j=1; j<=cntRow; j++){
                if(j SUBSEP i in matrix) printf matrix[j,i] " " ;
                else printf placeHolder " " ;
            }
            print "" ;
        }
    }

    ' $matrixFile

doExit
