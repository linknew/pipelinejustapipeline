#! /bin/bash

leftAlignDef=1
rightAlignDef=0
widthLimitDef=1000

function Help
{
    echo -ne "
    Descript:
        -

    Usage: 
        $(basename ${0}) [[!]/regExp/] [--gaps=LIST [--gapsOnly]] [--widthLimit=N] [--leftAlign | --rightAlign] [--help] textFile

    Options:
        --gaps, do alignment according GAPS and SPACE [need take a notice]
        --gapsOnly, do alignment according GAPS only
            for example:
            --gaps='@,#,JKLM'
                will align according '@' '#' 'JKLM' and ' '
            --gaps="@,#,JKLM" --gapsOnly
                will align according '@' '#' and 'JKLM'
        --leftAlign, set alignment type to left-alignment
        --rightAlign, set alignment type to right-alignment
        --widthLimit, set filed width limitation
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
        $0 --leftAlign --widthLimit=$widthLimitDef
\n"
}

for i in "${@}"
do
    [[ ${i} == "--help" ]] && Help && exit 0
    [[ ${i%%=*} == "--gaps" ]] && gaps=${i#*=} && continue ;
    [[ ${i} == "--gapsOnly" ]] && gapsOnly=1 && continue ;
    [[ ${i} == "--leftAlign" ]] && leftAlign=1 && continue ;
    [[ ${i} == "--rightAlign" ]] && rightAlign=1 && continue ;
    [[ ${i%%=*} == "--widthLimit" ]] && widthLimit=${i#*=} && continue ;
    [[ ${i:0:1} == "/" ]]  && regex=$i && continue ;
    [[ ${i:0:2} == "!/" ]] && regex=${i:1} && ignore=1 && continue ;
    [[ ${i:0:1} == "-" ]]  && echo "*! Unknown option:$i">&2 && exit -1
    [[ -n $list ]] && echo "*! Multipule list specified">&2 && exit -1
    textFile=$i
done

[[ $leftAlign -eq 1 ]] && rightAlign=0
[[ $rightAlign -eq 1 ]] && leftAlign=0

leftAlign=${leftAlign:-$leftAlignDef}
rightAlign=${rightAlign:-$rightAlignDef}
widthLimit=${widthLimit:-$widthLimitDef}

sed -n -E "$regex"${ignore:+d;}p\; $textFile |

awk -v gaps="$gaps"             \
    -v gapsOnly=$gapsOnly       \
    -v leftAlign=$leftAlign     \
    -v widthLimit=$widthLimit   \
    '

    BEGIN{
        gapNum = split(gaps,aGapList,",") ;
        for(i=1; i<=gapNum; i++) aGapIdx[aGapList[i]] = i ;

        if(!gapsOnly){
            sp = "[ \t\n]*" ;
        }else{
            sp = "TiLpS_LaCiGaM_Si_sIhT" ;
            for(i=1; i<=gapNum; i++) s = s "^("aGapList[i]")[ \t]|[ \t]("aGapList[i]")[ \t]|[ \t]("aGapList[i]")$|" ;
            s = s "^$" ;
            r = sp"&"sp ;
        }
        #print "[*]",sp,s,r > "/dev/stderr" ;
    }

    {
        if(gapsOnly){
            gsub(s, r) ;
            gsub("^"sp"[ \t]?|[ \t]?"sp"$", "") ;
        }
        #print "[*]\047" $0 "\047" > "/dev/stderr" ;
        itemNum = split($0, aItem, sp) ;
        #for(i=1;i<=itemNum;i++) print "[" aItem[i] "]" ;

        gapIdx = 0 ;
        j = 0 ;

        for(i=1; i<=itemNum; i++){

            tmpS = aItem[i] ;
            gsub(/^[ \t]*|[ \t]*$/, "", tmpS) ;
            if(tmpS in aGapIdx){
                aItem[i] = tmpS ;
                gapIdx = aGapIdx[aItem[i]] ;
                j = 0 ;
                #print "!![" aItem[i] "]" ;
            }

            len = length(aItem[i]) ;
            if(aaWidth[gapIdx,j]+0 < len){
                aaWidth[gapIdx,j] = (len > widthLimit ? widthLimit : len) ;
            }
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
                    if(leftAlign) _fmt = "%-" aaWidth[j,k] "s " ;
                    else          _fmt = "%"  aaWidth[j,k] "s " ;
                    printf(_fmt, aaaCont[i,j,k]) ;
                }
            }
            print "" ;
        }

    }

    '   | sed -E 's/\s+$//'

exit 0
