#! /bin/bash

#. comm.lib


function showHelp
{
    echo -ne "\nThis routine is used to check whether the source code conforms to the CSTG
              \nUsage:      \
              \n    $0 CCR round component dirPrefix    \\      \
              \n               [--genReport] [--checkModificationCopyright] [--checkIllegals] [--checkKeywords]
              \nArguments:  \
              \n    -
              \nOptions:    \
              \n    -
              \nDefault:    \
              \n    $0 [CCR] 1 wildComponent source/review-[CCR]-files --checkModificationCopyright --checkIllegals --checkKeywords
              \nNotes:  \
              \n    -
              \n "
}

[[ $# -eq 0 ]] && showHelp && exit

for i in "$@"
do
    [[ $i == "--help" ]] && showHelp && exit
    [[ $i == "--checkModificationCopyright" ]] && funcCheckModCpr=1 && continue
    [[ $i == "--checkIllegals" ]] && funcCheckIllegals=1 && continue
    [[ $i == "--checkKeywords" ]] && funcCheckKeywords=1 && continue
    [[ $i == "--genReport" ]] && funcGenReport=1 && continue
    [[ ${i:0:1} == "-" ]] && echo "!!unknown options $i" >&2 && exit
    argv[++argc]=$i
done

ccr=${argv[1]}
round=R${argv[2]:-1}
component=${argv[3]:-wildComponent}
patPreDir=${argv[4]:-"sourceChecking/review-${ccr}-files/"}
[[ -z $funcCheckModCpr && -z $funcCheckIllegals && -z $funcCheckKeywords && -z $funcGenReport ]] && funcCheckModCpr=1 funcCheckIllegals=1 funcCheckKeywords=1

filenameCopyright_modification=copyright_modification.${round//./_}.$component.$ccr.txt
filenameIllegal=illegals.${round//./_}.$component.$ccr.txt
fileKeywords=keywords.${round//./_}.$component.$ccr.txt
fileStatusOrg=$ccr.status.org
fileStatusDtl=status.${round//./_}.$component.$ccr.txt
fileStatusSum=status.summary.${round//./_}.$component.$ccr.txt

[[ -z $ccr ]] && echo "!!Please specify a CCR number." >&2 && exit

if [[ $funcCheckModCpr -eq 1 || $funcCheckIllegals -eq 1 || $funcCheckKeywords -eq 1 ]] ; then
    [[ ! -d $patPreDir ]] && echo "!!Cannot find $patPreDir" >&2 && exit

    files=$(find $patPreDir -type f -a \( -name "*.[ch]" -o -name "*.cpp" -o -name "*.hpp" -o -name "*.s" -o -name "*.inc" \) | sort -f)
    [[ -z $files ]] && echo "!!No C,C++ or asm source files found." >&2 && exit

    igrFls=$( grep -i "$component.files=" check.ignores | sed 's/.*\.files=//' )
    [[ -n $igrFls ]] && files=$( echo "$files" | grep -v "$igrFls" )

    echo -e "\n*following files will be ignored"
    [[ -n "$igrFls" ]] && echo -e "$igrFls"  | sed 's/^/    /'
    echo -e "\n*following files will be processed"
    [[ -n "$files" ]]  && echo -e "$files\n"   | sed 's/^/    /'
fi

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
    echo -ne "prefix directory: $patPreDir\n\n" | sed -E 's@\S*/helix/@helix/@' > $filenameIllegal

    # execute checkers

    ( 
        echo -ne "\n\n-- check non-ascii/table/80limitation --\n\n" ;
        ./checkIllegalChar.sh $files | sort

        echo -ne "\n\n-- check NOMANUAL tag --\n\n" ;
        ./checkInFunctionHeader.sh "$component" "$patPreDir" $files | sort

    ) | sed -E 's@'$patPreDir'@.../@' | align.sh --gaps='@,#' --gapsOnly >> $filenameIllegal &&
    echo "*check ILLEGALS in               $filenameIllegal"
fi


# illegal keywords checking

if [[ $funcCheckKeywords -eq 1 ]] ; then
    echo -ne "prefix directory: $patPreDir\n\n" | sed -E 's@\S*/helix/@helix/@' > $fileKeywords
    ./checkKeywords.sh $files | sed -E 's@'$patPreDir'@.../@; s@^[^-]@    &@;' | align.sh --gaps='@,#' --gapsOnly >> $fileKeywords &&
    echo "*check KEYWORDS in               $fileKeywords"
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

echo ""

exit

