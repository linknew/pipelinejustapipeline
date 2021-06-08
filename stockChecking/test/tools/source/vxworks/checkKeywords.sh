#!  /bin/bash

#. comm.lib


# keywords checking, 
# lable: for popurse of classfication
# keywords: keyword/pattern for matching
# keywordsIgnr: keyword/pattern for invert-matching
# hitInfo: display something when matching hitted 
# misInfo: display something when matching missed

# case senstive
#{
    let idx=0

    lableCase[idx]='[check "setjmp\/longjmp"]';
    keywordsCase[idx]='\b(setjmp|longjmp)\b\s*\('  ;
    keywordsCaseIgnr[idx]='(^\s*\*|/\*).*'"${keywordsCase[idx]}" ;
    hitInfoCase[idx]='* found setjmp\/longjmp @' ;
    misInfoCase[idx]="- No abnormalities found, Good J0b" ;
    let idx++ ;

    lableCase[idx]='[check "strcat\/strcmp\/strcpy\/strlen"]';
    keywordsCase[idx]='\b(strcat|strcmp|strcpy|strlen)\b\s*\(' ;
    keywordsCaseIgnr[idx]='(^\s*\*|/\*).*'"${keywordsCase[idx]}" ;
    hitInfoCase[idx]='* found strcat\/strcmp\/strcpy\/strlen @' ;
    misInfoCase[idx]="- No abnormalities found, Good J0b" ;
    let idx++ ;

    lableCase[idx]='[check "sprintf\/alloca"]';
    keywordsCase[idx]='\b(sprintf|alloca)\b\s*\(' ;
    keywordsCaseIgnr[idx]='(^\s*\*|/\*).*'"${keywordsCase[idx]}" ;
    hitInfoCase[idx]='* found sprintf\/alloca @' ;
    misInfoCase[idx]="- No abnormalities found, Good J0b" ;
    let idx++ ;

    lableCase[idx]='[check "#if 0~"]';
    keywordsCase[idx]='^\s*#\s*if\s+[0-9]+' ;
    hitInfoCase[idx]='* found uncomfortable pre_define @' ;
    misInfoCase[idx]="- No abnormalities found, Good J0b" ;
    let idx++ ;

#}

# case insenstive
#{
    let idx=0

#    lable[idx]='[check "keywordExample" (insenstive)]';
#    keywords[idx]='\b(keywordExample)\b' ;
#    keywordsIgnr[idx]='(^.*\signore\s).*'"${keywords[idx]}" ;
#    hitInfo[idx]='* found keywordExample @' ;
#    misInfo[idx]="- No abnormalities found, Good J0b" ;
#    let idx++ ;
#}

files=""
splitLine="-------------------------------------------------------------"

for i in "$@"
do
    [[ ${i:0:12} == "--prefixDir=" ]] && preDir=${i#*=} && continue
    [[ ${i:0:1} == "-" ]] && echo "!!unknown option $i" >&2 && exit
    files="$files $i"
done

[[ -n $preDir ]] && echo -ne "prefix directory:\n\n    - $preDir\n\n"

# get result of case senstive
rsltCase=$(
    if [[ ${#keywordsCase[@]} -gt 0 ]] ; then
        pat='$ ^' ;

        for i in "${keywordsCase[@]}" ; do
            pat="$pat|$i"
        done

        grep -nEH "$pat" $files | ( [[ -n $preDir ]] && sed -E 's&'$preDir'&.../&' || cat - )
    fi
)

# get result of case insensitve
rslt=$(
    if [[ ${#keywords[@]} -gt 0 ]] ; then
        pat='$ ^' ;

        for i in "${keywords[@]}" ; do
            pat="$pat|$i"
        done

        grep -inEH "$pat" $files | ( [[ -n $preDir ]] && sed -E 's&'$preDir'&.../&' || cat - )
    fi
)


# process case senstive
for i in "${!keywordsCase[@]}" ; do

    cont=$(
        echo "$rsltCase" |
        grep -E "${keywordsCase[i]/^/^\\S+:[0-9]+:}"     |
        ( [[ -n ${keywordsCaseIgnr[i]} ]] && grep -vE "${keywordsCaseIgnr[i]/^/^\\S+:[0-9]+:}" || cat - )
    )

    if [[ -n $cont ]] ; then
        echo -e "$cont" | sed -E 's/(^\S+:[0-9]+):\s*/\1 # /; s/^/'"${lableCase[i]}${hitInfoCase[i]}"' /'
    else
        echo -ne "\n" | sed -E 's/^/'"${lableCase[i]}${misInfoCase[i]}"'/' ;
    fi

done

# process case insenstive
for i in "${!keywords[@]}" ; do

    cont=$(
        echo "$rslt" |
        grep -iE "${keywords[i]/^/^\\S+:[0-9]+:}" |
        ( [[ -n ${keywordsIgnr[i]} ]] && grep -ivE "${keywordsIgnr[i]/^/^\\S+:[0-9]+:}" || cat - )
    )

    if [[ -n $cont ]] ; then
        echo -ne "$cont" | sed -E 's/(^\S+:[0-9]+):\s*/\1 # /; s/^/'"${lable[i]}${hitInfo[i]}"' /'
    else
        echo -ne "\n" | sed -E 's/^/'"${lable[i]}${misInfo[i]}"'/' ;
    fi

done


exit
