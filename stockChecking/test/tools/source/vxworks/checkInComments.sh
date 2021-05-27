#!  /bin/bash

#. comm.lib


function showHelp
{
    echo -ne "\nThis routine is used to check some items in comments
              \nUsage:      \
              \n    $0 pathname1 pathname2 ...
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

for((i=1; i<=argc; i++)) { files="$files ${argv[i]}" ; }
lineSep='\\012\\n' ;

comments=$(
#    getParagraph.sh --patHead='/\/\*|\/\//'         \
#                    --patTail='/\*\/|\/\//'         \
#                    --outputLineSep="$lineSep"      \
#                    $files

    (   getParagraph.sh --patHead='/\/\*/'          \
                    --patTail='/\*\//'              \
                    --outputLineSep="$lineSep"      \
                    $files

        getParagraph.sh --patHead='/\/\//'          \
                    --patTail='/\/\//'              \
                    --outputLineSep="$lineSep"      \
                    $files
    )
)


echo "$comments" |
awk -v thisScriptFilename="$0"        '

    function findNestComment(   \
        fragment,       # fragment of comments   \
        posType,        # 0:oneline comment                      \
                        # 1:first line of mult_line comments     \
                        # 2:middle of mult_line comments         \
                        # 3:last line of mult_line comments      \
                        \
                        # !!! below are local variables
                        \
        PS1,PS2,PE1     \
    )
    {
        # return 0:not find, 1:found, -1:wrong posType

        posType = posType + 0 ;
        if(posType<0 || posType>3) return -1 ;

        #print "+++++", fragment, "[" posType "]" ;
        gsub(/\/\/+/, " /* ", fragment) ;
        if(posType >= 2) fragment = "/* " fragment ;
        fragment = fragment " */" ;
        #print "-----", fragment ;

        PS1 = index(fragment, "/*") ;
        PS2 = index(substr(fragment, PS1+2), "/*") ; if(PS2) PS2 += PS1+2-1 ;
        PE1 = index(fragment, "*/") ;
        #print "***** PS1="PS1, "PS2="PS2, "PE1="PE1 ;

        return (PS2 && PS2 < PE1) ;
    }

    BEGIN{

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

                #cntCase ++ ;
                #lableCase[cntCase] = "[check \"keyword\" in COMMENTs]" ;
                #keywordsCase[cntCase] = "[ \\t]+keyword([ \t]|$)" ;
                #keywordsIgnrCase[cntCase] = "[ \\t]ignore[ \\t].*" keywordsCase[cntCase] ;
                #hitInfoCase[cntCase] = "* found \"keyword \".\"" ;
                #misInfoCase[cntCase] = "- No abnormalities found, Good J0b" ;
            }


            # case insenstive
            # please use lowercase keywords 
            {
                cnt = 0 ;

                cnt ++ ;
                lable[cnt] = "[check keyword \"should\" in COMMENTs]";
                keywords[cnt] = "[ \\t]+(should)([ \\t]|$)" ;
                hitInfo[cnt] = "* found \"should\"" ;
                misInfo[cnt] = "- No abnormalities found, Good J0b" ;

                cnt ++ ;
                lable[cnt] = "[check \"?\" in COMMENTs]";
                keywords[cnt] = "/\\*.*\\?.*\\*/|^[ \\t]?\\*.*\\?" ;
                hitInfo[cnt] = "* found \"?\"" ;
                misInfo[cnt] = "- No abnormalities found, Good J0b" ;

                cnt ++ ;
                lable[cnt] = "[check keyword \"yes/no\" in COMMENTs]";
                keywords[cnt] = "[ \\t]+(yes|no)[ \\t]*:" ;
                hitInfo[cnt] = "found \"yes/no\"" ;
                misInfo[cnt] = "- No abnormalities found, Good J0b" ;
            }
        }

    }

    {
        #print $0;

        filename = $0; sub(/.*@/, "", filename); sub(/::.*/, "", filename) ;
        paragFrm = $0; sub(/.*::/, "", paragFrm); sub(/-.*/, "", paragFrm) ;
        paragTo  = $0; sub(/.*::/, "", paragTo); sub(/.*-/, "", paragTo) ;

        # check in mass comments 
        {
        }

        # check in linenized comments
        {
            lineNum = split($0, lines, /'"$lineSep"'/) ;
            
            for(i=1; i<lineNum; i++){

                # the last line is the information line, no need to loop it

                lineNo = paragFrm + i - 1 ;
                nonCaseCont = tolower(lines[i]) ;
                #print "*****",lineNo, lines[i] ;

                #check nested comment
                {
                    if      (2 == lineNum  ) { posType = 0 ; }
                    else if (1 == i        ) { posType = 1 ; }
                    else if (lineNum-1 == i) { posType = 3 ; }
                    else                     { posType = 2 ; }
                    
                    retV = findNestComment(lines[i], posType) ;

                    if(-1 == retV){
                        print "* undefined posType in " thisScriptFilename "::findNestComment" > "/dev/stderr" ;
                    }else if(1 == retV){
                        rsltNested = rsltNested "[check nested comments]* found nested comments @ " filename ":" lineNo " # " lines[i] "\n" ;
                    }
                }

                #check the position of right aligment tags
                {
                    if(lines[i] ~ /\/\*[ \t]*[^ \t]+[ \t]*:[ \t]*[^ \t]+[ \t]*\*\//){
                        seed = nonCaseCont; sub(/[ \t]+$/, "", seed) ;

                        if(seed ~ /\/\*[ \t]*coverity/){
                            #coverity tag, no need right_alignment ;

                        }else if(length(seed) != 80){
                            rsltRAT = rsltRAT "[check RIGHT_ALIGNED tags]* found misaligned tag @ " filename ":" lineNo " # " lines[i] "\n" ;

                        }
                    }
                }

                #check keywords here
                {
                    #senstive check
                    {
                        for(j=1; j<=cntCase; j++){

                            if(lines[i] ~ keywordsCase[j]){

                                if(j in keywordsIgnrCase && lines[i] ~ keywordsIgnrCase[j]) continue ;

                                rsltCast[j] = rsltCast[j] lableCase[j] hitInfoCase[j] " @ " filename ":" lineNo " # " lines[i] "\n" ;
                            }
                        }
                    }

                    #insenstive check
                    {

                        for(j=1; j<=cnt; j++){

                            if(nonCaseCont ~ keywords[j]){

                                if(j in keywordsIgnr && nonCaseCont ~ keywordsIgnr[j]) continue ;

                                rslt[j] = rslt[j] lable[j] hitInfo[j] " @ " filename ":" lineNo " # " lines[i] "\n" ;
                            }
                        }
                    }
                }
            }
        }

        next ;
    }

    END{
        if(!rsltNested) print "[check nested comments]- No abnormalities found, Good J0b" ;
        else printf rsltNested ;

        if(!rsltRAT) print "[check RIGHT_ALIGNED tags]- No abnormalities found, Good J0b" ;
        else printf rsltRAT ;

        for(i=1; i<=cntCase; i++){
            if(rsltCase[i]) printf rsltCase[i] ;
            else print lableCase[i] misInfoCase[i] ;
        }

        for(i=1; i<=cnt; i++){
            if(rslt[i]) printf rslt[i] ;
            else print lable[i] misInfo[i] ;
        }
    }

    '


# check xxx

exit
