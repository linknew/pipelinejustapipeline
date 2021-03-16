#! /bin/bash

pwd=$(dirname $0)
. ${pwd%bin}/lib/comm.lib

doStart

optExit=""

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

sed -n -E "$regex"${ignore:+d;}p\; $textFile |

awk -v gaps="$gaps"         \
    -v gapsOnly=$gapsOnly   \
    '

    BEGIN{
        gapNum = split(gaps,aGapList,",") ;
        for(i=1; i<=gapNum; i++) aGapIdx[aGapList[i]] = i ;

        if(!gapsOnly){
            sp = "[ \t\n]*" ;
        }else{
            sp = "SP" ;
            for(i=1; i<=gapNum; i++) s = s "^("aGapList[i]")[ \t]|[ \t]("aGapList[i]")[ \t]|[ \t]("aGapList[i]")$|" ;
            s = s "^$" ;
            r = sp"&"sp ;
        }
        #print "[*]",sp,s,r > "/dev/stderr" ;
    }

    {
        if(gapsOnly){
            gsub(s, r) ;
            gsub("^"sp"[ \t]*|[ \t]*"sp"$", "") ;
        }
        #print "[*]",$0 > "/dev/stderr" ;
        itemNum = split($0, aItem, "[ \t]*"sp"[ \t]*") ;

        gapIdx = 0 ;
        j = 0 ;

        for(i=1; i<=itemNum; i++){
            len = length(aItem[i]) ;
            if(aItem[i] in aGapIdx){
                gapIdx = aGapIdx[aItem[i]] ;
                j = 0 ;
            }
            if(aaWidth[gapIdx,j]+0 < len) aaWidth[gapIdx,j] = len ;
            if(aCol[gapIdx]+0 < j+1) aCol[gapIdx] = j+1 ;
            aaaCont[FNR,gapIdx,j] = aItem[i] ;
            j++ ;
        }
    }

    END{

        #for(i=0; i<=gapNum; i++){
        #    for(j=0; j<aCol[i]; j++) printf "seg"j"=["aaWidth[i,j]"] " ;
        #    printf " | " ;
        #}
        #print "" ;

        for(i=1; i<=NR; i++){
            for(j=0; j<=gapNum; j++){
                for(k=0; k<aCol[j]; k++){
                    printf("%"aaWidth[j,k]"s ", aaaCont[i,j,k]) ;
                }
            }
            print "" ;
        }

    }

    '  

doExit 0 "$optExit"
