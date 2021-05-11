#!  /bin/bash

for i in "$@"
do
    [[ $i == "--help" ]] && echo -en "\n* Usage: $(basename $0) [--patHead=AWK_PAT_STR] [--patTail=AWK_PAT_STR] --outputLineSep=STR file1 file2 ...\n\n" >&2 && exit 0
    [[ $i == "--showCondtions" ]] && showCondtions=1 && continue
    [[ ${i%%=*} == "--patHead" ]] && patHead=${i#*=} && continue
    [[ ${i%%=*} == "--patTail" ]] && patTail=${i#*=} && continue
    [[ ${i%%=*} == "--outputLineSep" ]] && outputLineSep=${i#*=} && continue
    [[ ${i:0:1} == "-" ]] && echo "!!unknown option: $i" >&2 && exit 1
    files=$files" "$i
done

patHead=${patHead:-"^"}
patTail=${patTail:-"$"}
outputLineSep=${outputLineSep:-'\n'}

if [[ $showCondtions -eq 1 ]] ; then
    echo "" >&2
    echo "* patHead = \"$patHead\"" >&2
    echo "* patTail = \"$patTail\"" >&2
    echo "* outputLineSep = \"$outputLineSep\"" >&2
    echo "" >&2
    echo "" >&2
fi

awk -v outputLineSep="$outputLineSep"   \
    '

    BEGIN{
    }

    (FNR==1){
        if(matchingStart) print "!!Incomplete matching" paraInfo > "/dev/stderr" ;
        matchingStart = 0 ;
    }

    /'"$patHead"'/{

        if(matchingStart) print "!!Incomplete matching" paraInfo > "/dev/stderr" ;

        paraInfo = "@" FILENAME "::" FNR ;
        body = "" ;
        matchingStart = FNR ;

        #next ; #continue to check patTail as the matching of patHead and patTail is same line
    }

    (matchingStart){

        if($0 ~ /'"$patTail"'/){

            paraInfo = paraInfo "-" FNR ;
            body = body $0 ;
            print body outputLineSep paraInfo ;
            matchingStart = 0 ;

        }else{
            body = body $0 outputLineSep ;

        }
    }

    END{
        if(matchingStart) print "!!Incomplete matching" paraInfo > "/dev/stderr" ;
    }

    ' $files

