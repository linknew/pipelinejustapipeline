#! /bin/bash

. comm.lib

doStart

segSortDef=1
orgSegOprDef=0
doSortingDef=1
ORG_SEG_OPR_CP=1
ORG_SEG_OPR_MV=2

function Help
{
    echo -ne "
    Usage: ${0} [[!]/regExp/] [-segSort] [--revert] [--cp2Head | --mv2Head] [--noSorting] [--help] textFile

        -segSort, specify which seg to sorting
        --cp2Head, copy the sorting segment to the head
        --mv2Head, move the sorting segment to the head
        --noSorting, do not operat sorting
        --revert, revert the resoult
        --help

    Note:
        -

    Default: $0 -$segSortDef
\n"
}

for i in "${@}"
do
    [[ ${i} == "--help" ]] && Help && doExit 0 "$oprtB4Exit"
    [[ ${i} == "--revert" ]] && revert=1 && continue ;
    [[ ${i} == "--cp2Head" ]] && orgSegOpr=$ORG_SEG_OPR_CP && continue ;
    [[ ${i} == "--mv2Head" ]] && orgSegOpr=$ORG_SEG_OPR_MV && continue ;
    [[ ${i} == "--noSorting" ]] && doSorting=0 && continue ;
    [[ ${i:0:1} == "/" ]]  && regex=$i && continue ;
    [[ ${i:0:2} == "!/" ]] && regex=${i:1} && ignore=1 && continue ;
    [[ ${i%%=*} == "--dur" ]] && dur=${i##*=} && continue
    [[ ${i%%=*} == "--start" ]] &&  start=${i#*=} && continue ;
    [[ ${i%%=*} == "--end" ]] && end=${i#*=} && continue ;
    [[ ${i:0:1} == "-" && ${i:1:1} > 0 && ${i:1:1} -le 9 ]] && segSort=${i##*-} && continue ;       #... cannot use -ge 0 && -le 9 , to avoid --unknown_options
    [[ ${i:0:1} == "-" ]] && echo "*! Unknown option:$i">&2 && doExit -1
    [[ -n $list ]] && echo "*! Multipule list specified">&2 && doExit -1
    list=$i
done

segSort=${segSort:-$segSortDef}
doSorting=${doSorting:-$doSortingDef}
orgSegOpr=${orgSegOpr:-$orgSegOprDef}

sed -n -E "$regex"${ignore:+d;}p\; $list |

    awk -v segSort="$segSort"       \
        -v orgSegOpr="$orgSegOpr"   \
        '

        BEGIN{
            OFMT="%.2f" ;
            fundsOrg = 1 ;  #original funds
            code = "" ;
            codeCur = "" ;
        }

        {
            _cont = $segSort ;
            if('"$ORG_SEG_OPR_MV"' == orgSegOpr) $segSort = "" ;
            $0 = _cont " " $0 ;

            print ;
        }

        END{
        }

        '   |

    if [[ $doSorting -eq 0 && $revert -eq 1 ]] ; then
        nl  | sort -n -r | sed -E 's/[0-9]+ *//'
    elif [[ $doSorting -eq 0 && $revert -eq 0 ]] ; then
        cat -
    else
        sort -n ${revert:+-r}
    fi      |
        
    if [[ $orgSegOpr -eq 0 ]] ; then
        sed -E 's/[^ ]+ *//'
    else
        cat -
    fi

doExit
