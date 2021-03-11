#! /bin/bash

. comm.lib

doStart

optExit="rm -f /tmp/.$$"

function Help
{
    echo -ne "
    Descript:
        -

    Usage: 
        $(basename ${0}) [[!]/regExp/] [--gaps=LIST [--gapsOnly]] [--help] textFile

    Options:
        --gaps, do alignment according GAPS and SPACE [need take a notice]
        --gapsOnly, do alignment according GAPS only
            for example:
            --gaps='@,#,JKLM'
                will align according '@' '#' 'JKLM' and ' '
            --gaps="@,#,JKLM" --gapsOnly
                will align according '@' '#' and 'JKLM'
        --help,

    Note:
        *) the LIST in --gasps=LIST, must be separated by ','
        *) In text content, only a word completely match a gaps element will regard as a GAP
           for example:
           with --gap='@,#,JKLM',
           the first '@' in
           'hello how @ are you, i am@home'
           is a GaP and the second '@' is not.

    Default:
        -
\n"
}

for i in "${@}"
do
    [[ ${i} == "--help" ]] && Help && doExit 0 "$optExit"
    [[ ${i%%=*} == "--gaps" ]] && gaps=${i#*=} && continue ;
    [[ ${i} == "--gapsOnly" ]] && gapsOnly=1 && continue ;
    [[ ${i:0:1} == "/" ]]  && regex=$i && continue ;
    [[ ${i:0:2} == "!/" ]] && regex=${i:1} && ignore=1 && continue ;
    [[ ${i:0:1} == "-" ]]  && echo "*! Unknown option:$i">&2 && doExit -1 "$optExit"
    [[ -n $list ]] && echo "*! Multipule list specified">&2 && doExit -1 "$optExit"
    textFile=$i
done

sed -n -E "$regex"${ignore:+d;}p\; $textFile > /tmp/.$$

awk -v gaps="$gaps"         \
    -v gapsOnly=$gapsOnly   \
    '

    BEGIN{
        i = split(gaps,aGapList,",") ;
        for(j=1; j<=i; j++){
            aGapIdx[aGapList[j]] = j ;
        }
    }

    {
        gapIdx = 0 ;
        j = 0 ;
        for(i=1; i<=NF; i++){
            len = length($i) ;
            if($i in aGapIdx){
                gapIdx = aGapIdx[$i] ;
                j = 0 ;
            }
            if(len > lenArry[gapIdx,j]) lenArry[gapIdx,j] = len ;
            j++ ;
        }
    }

    END{
        for(idx in lenArry){
            split(idx,arry,SUBSEP) ;
            if(arry[1] > maxGapIdx) maxGapIdx = arry[1] ;
            if(arry[2] > maxFldIdx[arry[1]]) maxFldIdx[arry[1]] = arry[2] ;
        }

        # print width of each column
        #for(i=0;i<=maxGapIdx;i++){
        #    for(j=0; j<=maxFldIdx[i]; j++) printf("%" lenArry[i,j] "d ",lenArry[i,j]) ;
        #    print "" ;
        #}

        while(getline < "/tmp/.'$$'"){
            gapIdx = 0 ;
            j = 0 ;
            for(i=1; i<=NF; i++){
                if($i in aGapIdx){
                    gapIdx = aGapIdx[$i] ;
                    j = 0 ;
                }
                aPrt[gapIdx,j] = $i ;
                j++ ;
            }
            for(i=0; i<=maxGapIdx; i++){
                for(j=0; j<=maxFldIdx[i]; j++){
                    len = lenArry[i,j] ;
                    printf("%" len "s ", aPrt[i,j]) ;
                }
            }
            print "" ;
            delete aPrt ;
        }
        close("/tmp/.'$$'") ;
    }

#    END{
#        for(i=1; i<=NR; i++){
#            for(j=1; j<=cntField; j++){
#                split(cont[i], arry) ;
#                fmt = "%" lenArry[j] "s " ;
#                printf(fmt, arry[j]) ;
#            }
#            print "" ;
#        }
#    }

    '   /tmp/.$$

doExit 0 "$optExit"
