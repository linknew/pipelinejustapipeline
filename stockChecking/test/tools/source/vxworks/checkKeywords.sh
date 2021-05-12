#!  /bin/bash

#. comm.lib


# keywords checking, "title" just for display, keywordsCase/keywords for case senstive/insensitve matching, keywordsCaseIgnr/keywordsIgnr for revert matching

# case senstive
idx=0
titleCase[idx]='(setjmp|longjmp)';                keywordsCase[idx]='\b(setjmp|longjmp)\b\s*\('  ;              keywordsCaseIgnr[idx]='(^\s*\*|/\*).*'"${keywordsCase[0]}" ;    ((idx++)) ;
titleCase[idx]='(strcat|strcmp|strcpy|strlen)';   keywordsCase[idx]='\b(strcat|strcmp|strcpy|strlen)\b\s*\(' ;  keywordsCaseIgnr[idx]='(^\s*\*|/\*).*'"${keywordsCase[1]}" ;    ((idx++)) ;
titleCase[idx]='(sprintf|alloca)';                keywordsCase[idx]='\b(sprintf|alloca)\b\s*\(' ;               keywordsCaseIgnr[idx]='(^\s*\*|/\*).*'"${keywordsCase[2]}" ;    ((idx++)) ;

# case insenstive
idx=0
title[idx]='(should) in COMMENT';                 keywords[idx]='(/\*|^\s?\*).*\b(should)\b' ;                                                                                  ((idx++)) ;
title[idx]='(yes|no) in COMMENT';                 keywords[idx]='(/\*|^\s?\*).*\b(yes|no)\b\s*:' ;                                                                              ((idx++)) ;
title[idx]='((this|the) function) in HEADER';     keywords[idx]='^\s?\*\s(.*\b(this|the) function\b|\bfunction\b)' ;                                                            ((idx++)) ;
title[idx]='((this|the) routine) in HEADER';      keywords[idx]='^\s?\*\s(.*\b(this|the) routine\b|\broutine\b)' ;                                                              ((idx++)) ;
title[idx]='(->|.) in HEADER';                    keywords[idx]='^\s?\*.*(\[|<)[a-zA-Z0-9_]+(-\\*>|\.)[a-zA-Z_]+(]|>).*' ;    keywordsIgnr[idx]='<[a-zA-Z0-9_]+.h>' ;           ((idx++)) ;
title[idx]='redundant spaces in HEADER';          keywords[idx]='^\s?\*.*\b\s{2,}\b' ;                                                                                          ((idx++)) ;

files=""
splitLine="-------------------------------------------------------------"

for i in "$@"
do
    [[ ${i:0:12} == "--prefixDir=" ]] && preDir=${i#*=} && continue
    [[ ${i:0:1} == "-" ]] && echo "!!unknown option $i" >&2 && exit
    files="$files $i"
done

[[ -n $preDir ]] && echo -ne "prefix directory: $preDir\n\n"

#case senstive
rsltCase=$(
    if [[ ${#keywordsCase[@]} -gt 0 ]] ; then
        pat='$ ^' ;

        for i in "${keywordsCase[@]}" ; do
            pat="$pat|$i"
        done

        grep -nEH "$pat" $files | ( [[ -n $preDir ]] && sed -E 's&'$preDir'&.../&' || cat - )
    fi
)

#case insensitve
rslt=$(
    if [[ ${#keywords[@]} -gt 0 ]] ; then
        pat='$ ^' ;

        for i in "${keywords[@]}" ; do
            pat="$pat|$i"
        done

        grep -inEH "$pat" $files | ( [[ -n $preDir ]] && sed -E 's&'$preDir'&.../&' || cat - )
    fi
)


for i in "${!keywordsCase[@]}" ; do
    echo -e "--- ${titleCase[i]}[Case Senstive] ${splitLine:${#titleCase[i]}+15+1}\n"

    if [[ -n $rsltCase ]]; then
        echo "$rsltCase" | grep -E "${keywordsCase[i]/^/^\\S+:[0-9]+:}"     | 
            ( [[ -n ${keywordsCaseIgnr[i]} ]] && grep -vE "${keywordsCaseIgnr[i]/^/^\\S+:[0-9]+:}" || cat - )   |
            sed -E 's/(^\S+:[0-9]+):\s*/\1 # /'
    fi

    echo -ne "\n\n"
done

for i in "${!keywords[@]}" ; do
    echo -e "--- ${title[i]} ${splitLine:${#title[i]}+1}\n"

    if [[ -n $rslt ]]; then
        echo "$rslt" | grep -iE "${keywords[i]/^/^\\S+:[0-9]+:}" | 
            ( [[ -n ${keywordsIgnr[i]} ]] && grep -ivE "${keywordsIgnr[i]/^/^\\S+:[0-9]+:}" || cat - )  |
            sed -E 's/(^\S+:[0-9]+):\s*/\1 # /'
    fi

    echo -ne "\n\n"
done


exit
