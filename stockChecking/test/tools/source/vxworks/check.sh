#! /bin/bash

#. comm.lib


function showHelp
{
    echo -ne "\nThis routine is used to check whether the source code conforms to the CSTG
              \nUsage:      \
              \n    $0 CCR round component dirPrefix    \\      \
              \n               [--genReport] [--checkModificationCopyright] [--checkIllegals] [--doUnstableCheck] [--listCheckFilesOnly]
              \nArguments:  \
              \n    -
              \nOptions:    \
              \n    -
              \nDefault:    \
              \n    $0 [CCR] 1 wildComponent source/review-[CCR]-files --checkModificationCopyright --checkIllegals --doUnstableCheck
              \nNotes:  \
              \n    -
              \n "
}

function classifyCheckRslt
{
    #$1: list of ignored labels, split by "\n"

    #cat - ; return 0 ;

    local buf=$(cat -)
    local lables=$(echo "$buf" | sed -E 's/^\[|].*//g' | sort -u)   #sort lables
    local ignFcts=$1


    #do classify
    echo "$buf" |
    awk -v lables="$lables"     \
        -v ignFcts="$ignFcts"   \
        '
        BEGIN{
            keyNum = split(lables, keys, "\n") ;
            ignFctNum = split(ignFcts, igns, "\n") ;
            for(i=1; i<=ignFctNum; i++){
                ignFctsHash[igns[i]] = 1 ;
            }
            delete igns ;
        }

        {
            key = $0; gsub(/\[|].*/, "", key) ;
            value = $0; sub(/^[^\135]+]/, "", value) ;
            values[key] = values[key] "    " value "\n" ;
        }

        END{
            splitLine="-------------------------------------------------------------" ;
            
            for(i=1; i<=keyNum; i++){
                filler = substr(splitLine, 3+length(keys[i])+1+1) ;

                if(keys[i] in ignFctsHash){
                    print "\n\n-- " keys[i] " " filler "\n\n    - Skipped\n" ;
                }else{
                    print "\n\n-- " keys[i] " " filler "\n\n" values[keys[i]] ;
                }
            }
        }
        '
}

[[ $# -eq 0 ]] && showHelp && exit

for i in "$@"
do
    [[ $i == "--help" ]] && showHelp && exit
    [[ $i == "--checkModificationCopyright" ]] && funcCheckModCpr=1 && continue
    [[ $i == "--checkIllegals" ]] && funcCheckIllegals=1 && continue
    [[ $i == "--doUnstableCheck" ]] && funcUnstableCheck=1 && continue
    [[ $i == "--genReport" ]] && funcGenReport=1 && continue
    [[ $i == "--listCheckFilesOnly" ]] && funcListCheckFilesOnly=1 && continue
    [[ ${i:0:1} == "-" ]] && echo "!!unknown options $i" >&2 && exit
    argv[++argc]=$i
done

username=$(whoami)
ccr=${argv[1]}
round=R${argv[2]:-1}
component=${argv[3]:-wildComponent}
patPreDir=${argv[4]:-"sourceChecking/review-${ccr}-files/"}
[[ -z $funcCheckModCpr   &&
   -z $funcCheckIllegals &&
   -z $funcUnstableCheck &&
   -z $funcGenReport     &&
   -z $funcListCheckFilesOnly  ]] && funcCheckModCpr=1 funcCheckIllegals=1 funcUnstableCheck=1

filenameCopyright_modification=copyright_modification.${round//./_}.$component.$ccr.$username.txt
filenameIllegal=illegals.${round//./_}.$component.$ccr.$username.txt
filenameUnstableChecking=unstableChecking.${round//./_}.$component.$ccr.$username.txt
fileStatusOrg=$ccr.status.org
fileStatusDtl=status.${round//./_}.$component.$ccr.$username.txt
fileStatusSum=status.summary.${round//./_}.$component.$ccr.$username.txt

[[ -z $ccr ]] && echo "!!Please specify a CCR number." >&2 && exit

if [[ $funcCheckModCpr   -eq 1 || $funcCheckIllegals      -eq 1 ||
      $funcUnstableCheck -eq 1 || $funcListCheckFilesOnly -eq 1   ]] ; then

    if [[ -f $patPreDir ]] ; then
        files=$patPreDir
    else
        [[ ! -d $patPreDir ]] && echo "!!Cannot find $patPreDir" >&2 && exit
        files=$(find $patPreDir -type f -a \( -name "*.[ch]" -o -name "*.cpp" -o -name "*.hpp" -o -name "*.s" -o -name "*.inc" \) | sort -f)
    fi

    [[ -z $files ]] && echo "!!No C,C++ or asm source files found." >&2 && exit

    igrFcts=$( grep -h "^function=" check.ignores | sed -E 's/^function=["'\'']?|["'\'']?\s*$//g' )
    igrFls=$( grep -i "^$component.files=" check.ignores | sed 's/.*\.files=//' )
    [[ -n $igrFls ]] && files=$( echo "$files" | grep -v "$igrFls" )

    echo -e "\n*following files will be ignored"
    [[ -n "$igrFls" ]] && echo -e "$igrFls"  | sed 's/^/    /'
    echo -e "\n*following files will be processed"
    [[ -n "$files" ]]  && echo -e "$files\n"   | sed 's/^/    /'
fi

[[ $funcListCheckFilesOnly -eq 1 ]] && exit

# modification and copyright checking

if [[ $funcCheckModCpr -eq 1 ]] ; then
    echo "$files" |
    awk -v patPreDir=$patPreDir '

        BEGIN{
            lineSplit="------------------------------------------------------------------------------------------------------------------------------------------------------------------ @" ;
        }

        ($1 !~ /#/){

            filenameLocal = $1 ;
            filenameInStore = $1 ;
            nameNaked = $1 ;
            sub(".*/helix/", "helix/", filenameInStore) ;
            sub(/.*\//, "", nameNaked) ;
            #print filenameLocal,filenameInStore,nameNaked > "/dev/stderr" ;

            lenLineSplit = length(lineSplit) ;
            lenHeadTail = (lenLineSplit - length(filenameLocal) - 2) / 2 ;
            print substr(lineSplit, 1, lenHeadTail), filenameLocal, substr(lineSplit,lenLineSplit-lenHeadTail+1) ;

            checkingInBash = "./checkTheOrderOfHistoryList.sh "filenameLocal" ; ./checkCommits.sh "filenameInStore" "filenameLocal"; "  ;
            system(checkingInBash) ;
            close(checkingInBash) ;
        }

        '   |
    sed -E 's/ +$//;' | align.sh --gaps='@' --gapsOnly --widthLimit=90 >  \
    $filenameCopyright_modification &&
    echo "*check COPYRIGHT_MODIFICATION in $filenameCopyright_modification"
fi


# illegal checking
# tab, 80 limit, non-ascii, NOMANUAL-tag

if [[ $funcCheckIllegals -eq 1 ]] ; then
    echo -ne "prefix directory:\n\n    - $patPreDir\n\n" | sed -E 's@\S*/helix/@helix/@' > $filenameIllegal

    # execute checkers

    (
        ./checkIllegalChar.sh $files | classifyCheckRslt "$igrFcts"

        ./checkKeywords.sh    $files | classifyCheckRslt "$igrFcts"

        ./checkInComments.sh  $files | classifyCheckRslt "$igrFcts"

        ./checkInFunctionHeader.sh "$component" "$patPreDir" $files | classifyCheckRslt "$igrFcts"


    ) | sed -E 's@'$patPreDir'@.../@' | align.sh --gaps='@,#' --gapsOnly >> $filenameIllegal &&
    echo "*check ILLEGALS in               $filenameIllegal"
fi


# unstable checking  (checking in testing progress)

if [[ $funcUnstableCheck -eq 1 ]] ; then
    echo -ne "prefix directory:\n\n    - $patPreDir\n\n" | sed -E 's@\S*/helix/@helix/@' > $filenameUnstableChecking
    ./checkUnstable.sh $files | classifyCheckRslt "$igrFcts" |
        sed -E 's@'$patPreDir'@.../@' | align.sh --gaps='@,#' --gapsOnly >> $filenameUnstableChecking &&
        echo "*check UNSTABLECHECKING in       $filenameUnstableChecking"
fi


# generate status report

if [[ $funcGenReport -eq 1 ]] ; then
    [[ ! -f "$fileStatusOrg" ]] && echo "!!Cannot find $fileStatusOrg" >&2 && exit

    # generate status report

    ./genCCR_StatusFromCCR_WebPage.sh "$fileStatusOrg"   | sort -n | align.sh > $fileStatusDtl &&
    echo "*check STATUS in                 $fileStatusDtl"

    # generate summary status report

    cat "$fileStatusDtl"   |
    awk -v round=$round \
        -v dateAbb=$(date +%d%b%y | tr [A-Z] [a-z]) \
        '
        {
            if($1 ~ /#/) next ;
            sum[$1" ",$2" ",$3] += ($5 == "Accepted" || $5 == "NoComment") ? 0 : 1 ;
        }
        END{
            for(i in sum){
                split(i, subScript, SUBSEP) ;
                fileIdx = subScript[1] ;
                filename = subScript[2] ;
                reviewer = subScript[3] ;

                print fileIdx, round "-" reviewer ":" dateAbb "," ((sum[i] == 0) ? "PASS" : (sum[i] "left")) ;
            }
        }
        '   | sort -n > $fileStatusSum &&
    echo "*check SUMMARY_STATUS in         $fileStatusSum"
fi

#if [[ $funcCheckModCpr   -eq 1 || $funcCheckIllegals      -eq 1 ||
#      $funcUnstableCheck -eq 1 || $funcListCheckFilesOnly -eq 1   ]] ; then
#
#    if [[ ${patPreDir:0:1} != '/' ]] ; then
#        "$(pwd)/$patPreDir"
#    fi
#fi
echo ""

exit

