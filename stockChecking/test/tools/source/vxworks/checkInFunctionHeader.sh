#!  /bin/bash

#. comm.lib


function showHelp
{
    echo -ne "\nThis routine is used to check some items in function header
              \nUsage:      \
              \n    $0 component preDir pathname1 pathname2 ...
              \nArguments:  \
              \n    -
              \nOptions:    \
              \n    -
              \nDefault:    \
              \n    -
              \nNotes:      \
              \n    -
              \n"
}

[[ $# -eq 0 ]] && showHelp && exit

for i in "$@"
do
    [[ $i == "--help" ]] && showHelp && exit
    [[ ${i:0:1} == "-" ]] && echo "!!unknown options $i" >&2 && exit
    argv[++argc]=$i
done

component=${argv[1]} ;
preDir=${argv[2]} ;
for((i=3; i<=argc; i++)) { files="$files ${argv[i]}" ; }

functionCategories=$(
    grep -i "$component" check.functionCategory | sed -E 's/^[^:]+:://' |
    awk -v preDir="$preDir"  \
        '
        {
            baseDir = $0; sub(/\/.*/, "", baseDir) ;
            pos = match(preDir, baseDir) ;
            print (pos>0) ? (substr(preDir,1,pos-1) $0) : (preDir $0) ;
        }
        '
)

lineSep='\\012\\n' ;

headers=$(
    getParagraph.sh --patHead='^\/\*\*\*\*\*\*\*\*[*]+[ \t]*$'  \
                    --patTail='^[ \t]?\*\/'             \
                    --outputLineSep="$lineSep" \
                    $files
)


echo "$headers" |
awk -v functionCategories="$functionCategories"     \
    '

    BEGIN{
        funcNum = split(functionCategories,functionCategoriesArry,"\n") ; 

        for(i=1; i<=funcNum; i++){
            #print functionCategoriesArry[i] >"/dev/stderr" ;
            key = functionCategoriesArry[i] ; sub(/=.*/, "", key) ;
            value = functionCategoriesArry[i] ; sub(/.*=/, "", value) ; sub(/[ \t].*/, "", value) ;
            funcCategory[key] = value ;
        }
    }

    {
        #print $0;

        pathname = $0; gsub(/.*'"$outputLineSep"'@|::.*/, "", pathname) ;
        funcName = $0; sub(/[ \t]*-.*/, "", funcName); sub(/.*[ \t]+/, "", funcName) ;
        paragFrm = $0; sub(/.*::/, "", paragFrm); sub(/-.*/, "", paragFrm) ;
        paragTo  = $0; sub(/.*::/, "", paragTo); sub(/.*-/, "", paragTo) ;

        # check in mass header 
        {
            # check NOMANUAL tag
            {
                noManTag = match($0, /'"$outputLineSep"'[ \t]?\*[ \t]\\NOMANUAL/) ;
                key = pathname "::" funcName ;
                #print key, noManTag > "/dev/stderr" ;

                if(! (key in funcCategory) ){
                    print "    * unclassified function " funcName " @ " key ":" paragFrm #> "/dev/stderr" ;

                }else if(funcCategory[key] == "manual_ignored"){
                    print "      [manual_ignored] ignore tag_checking @ " pathname ":" paragFrm " # " funcName ;

                }else if(funcCategory[key] == "API" && noManTag){
                    print "    * found incorrect NOMANUAL tag @ " pathname ":" paragFrm " # " funcName ;

                }else if(funcCategory[key] != "API" && !noManTag ){
                    print "    * need a NOMANUAL tag @ " pathname ":" paragFrm " # " funcName ;

                }
            }
        }

        # check in linenized header
        {
            lineNum = split($0, lines, /'"$lineSep"'/) ;
            
            for(i=1; i<=lineNum; i++){

                lineNo = paragFrm + lineNum - 1 ;
                #print lineNo, lines[i] ;

            }
        }

        next ;
    }

    '


# check xxx

exit
