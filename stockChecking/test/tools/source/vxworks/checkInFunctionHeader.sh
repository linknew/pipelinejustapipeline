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
    grep -i "^$component" check.functionCategory | sed -E 's/^[^:]+:://' |
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
    getParagraph.sh --patHead='/^\/\*\*\*\*\*\*\*\*[*]+[ \t]*$/'  \
                    --patTail='/^[ \t]?\*\//'             \
                    --outputLineSep="$lineSep" \
                    $files
)


echo "$headers" |
awk -v functionCategories="$functionCategories"     \
    '

    BEGIN{

        # get function category info
        {
            funcNum = split(functionCategories,functionCategoriesArry,"\n") ;

            for(i=1; i<=funcNum; i++){
                #print functionCategoriesArry[i] >"/dev/stderr" ;
                key = functionCategoriesArry[i] ; sub(/=.*/, "", key) ;
                value = functionCategoriesArry[i] ; sub(/.*=/, "", value) ; sub(/[ \t].*/, "", value) ;
                funcCategory[key] = value ;
            }
        }

        # prepare linenized check
        {
            #>>vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
            #>>                                                                             <
            #>> we use a string to keep the keyword for matching, So!! need DOUBLE the "\"  <
            #>>                                                                             <
            #>>^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
            #
            #

            # case senstive
            {
                cntCase = 0 ;

                cntCase ++ ;
                lableCase[cntCase] = "[check \"->\" or \".\" in FUNCTION_HEADER]" ;
                keywordsCase[cntCase] = "(\\[|<)[a-zA-Z0-9_]+(-\\\\*>|\\\\*\\.)[a-zA-Z0-9_]+(]|>)" ;
                keywordsIgnrCase[cntCase] = "<[a-zA-Z0-9_]+.h>" ;
                hitInfoCase[cntCase] = "* found \"->\" or \".\"" ;
                misInfoCase[cntCase] = "- No abnormalities found, Good J0b" ;

                cntCase ++;
                lableCase[cntCase] = "[check redundant spaces in FUNCTION_HEADER]" ;
                keywordsCase[cntCase] = "^(/\\*| ?\\*[ \\t]).*[^ \\t,.:;!?][ \\t][ \\t]+[^ \\t]" ;
                hitInfoCase[cntCase] = "* found redundant sapces" ;
                misInfoCase[cntCase] = "- No abnormalities found, Good J0b" ;

                cntCase ++;
                lableCase[cntCase] = "[check \"\\ml\" tag in FUNCTION_HEADER]";
                keywordsCase[cntCase] = "\\\\ml";
                hitInfoCase[cntCase] = "* replace \\ml with \\ms" ;
                misInfoCase[cntCase] = "- No abnormalities found, Good J0b" ;
            }

            # case insenstive
            # please use lowercase keywords 
            {
                cnt = 0 ;

                cnt ++ ;
                lable[cnt] = "[check keyword \"this/the function\" in FUNCTION_HEADER]";
                keywords[cnt] = "([ \\t]+(this|the)[ \\t]+|[ \\t]?\\*[ \\t])function([ ,.:!@?\\175\\011\\051\\047\\042\\135]|$)" ;
                hitInfo[cnt] = "* found \"this/the function\"" ;
                misInfo[cnt] = "- No abnormalities found, Good J0b" ;

                cnt ++ ;
                lable[cnt] = "[check keyword \"this/the routine\" in FUNCTION_HEADER]";
                keywords[cnt] = "([ \\t]+(this|the)[ \\t]+|^[ \\t]?\\*[ \\t])routine([ ,.:!@?\\175\\011\\051\\047\\042\\135]|$)" ;
                hitInfo[cnt] = "found \"this/the routine\"" ;
                misInfo[cnt] = "- No abnormalities found, Good J0b" ;
            }
        }

    }

    {
        #print "#" $0 "#" > "/dev/stderr" ;

        pathname = $0; gsub(/.*'"$outputLineSep"'@[ \t]*|::.*$/, "", pathname) ;
        filename = $0; sub(/.*@[ \t]*.*\//, "", filename); sub(/::.*$/, "", filename) ;
        funcName = $0; sub(/[ \t]*-.*/, "", funcName); sub(/.*[ \t]+/, "", funcName) ;
        paragFrm = $0; sub(/.*::/, "", paragFrm); sub(/-.*/, "", paragFrm) ;
        paragTo  = $0; sub(/.*::/, "", paragTo); sub(/.*-/, "", paragTo) ;

        #print "pathname=@" pathname "@" > "/dev/stderr" ;
        #print "filename=@" filename "@" > "/dev/stderr" ;
        #print "funcName=@" funcName "@" > "/dev/stderr" ;
        #print "paragFrm=@" paragFrm "@" > "/dev/stderr" ;
        #print "paragTo=@" paragTo "@" > "/dev/stderr" ;

        # check in mass header
        {
            # check NOMANUAL tag
            {
                noManTag = match($0, /'"$outputLineSep"'[ \t]?\*[ \t]\\NOMANUAL/) ;
                key = pathname "::" funcName ;
                #print key, noManTag > "/dev/stderr" ;

                if(! (key in funcCategory) ){
                    rsltNomanualTag = rsltNomanualTag "[check \"\\NOMANUAL\" tag in FUNCTION_HEADER]* unclassified function @ " key ":" paragFrm "\n" ;

                }else if(funcCategory[key] == "manual_ignored"){
                    rsltNomanualTag = rsltNomanualTag "[check \"\\NOMANUAL\" tag in FUNCTION_HEADER]- {manual_ignored} ignore tag_checking @ " pathname ":" paragFrm " # " funcName "\n" ;

                }else if(funcCategory[key] == "API" && noManTag){
                    rsltNomanualTag = rsltNomanualTag "[check \"\\NOMANUAL\" tag in FUNCTION_HEADER]* found incorrect NOMANUAL tag @ " pathname ":" paragFrm " # " funcName "\n" ;

                }else if(funcCategory[key] != "API" && !noManTag ){
                    rsltNomanualTag = rsltNomanualTag "[check \"\\NOMANUAL\" tag in FUNCTION_HEADER]* need a NOMANUAL tag @ " pathname ":" paragFrm " # " funcName "\n" ;

                }
            }
        }

        # check in linenized header
        {
            lineNum = split($0, lines, /'"$lineSep"'/) ;

            for(i=1; i<lineNum; i++){

                lineNo = paragFrm + i - 1 ;
                #print lineNo, lines[i] ;

                # check senstive keywords
                {
                    for(j=1; j<=cntCase; j++){

                        if(lines[i] ~ keywordsCase[j]){

                            if(j in keywordsIgnrCase && lines[i] ~ keywordsIgnrCase[j]) continue ;

                            rsltCase[j] = rsltCase[j] lableCase[j] hitInfoCase[j] " @ " pathname ":" lineNo " # " lines[i] "\n" ;
                        }
                    }
                }

                # check insenstive keywords
                {
                    nonCaseCont = tolower(lines[i]) ;

                    for(j=1; j<=cnt; j++){

                        if(nonCaseCont ~ keywords[j]){

                            if(j in keywordsIgnr && nonCaseCont ~ keywordsIgnr[j]) continue ;

                            rslt[j] = rslt[j] lable[j] hitInfo[j] " @ " pathname ":" lineNo " # " lines[i] "\n" ;
                        }
                    }
                }
            }
        }

        next ;
    }

    END{
        # if no content for linenized checking, show some message
        {
            if(rsltNomanualTag){
                printf rsltNomanualTag | "sort" ;
                close("sort") ;
            }
            else{
                print "[check \"\\NOMANUAL\" tag in FUNCTION_HEADER]- No abnormalities found, Good J0b" ;
            }

            for(i=1; i<=cntCase; i++){
                if(rsltCase[i]) printf rsltCase[i] ;
                else print lableCase[i] misInfoCase[i] ;
            }

            for(i=1; i<=cnt; i++){
                if(rslt[i]) printf rslt[i] ;
                else print lable[i] misInfo[i] ;
            }
        }
    }

    '


# check xxx

exit
