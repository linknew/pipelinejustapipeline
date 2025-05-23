#! /bin/bash

function removePairs
# $1, pl, paire left
# $2, pr, paire right
# $3, 0:non-nested 1:nested 
{
    if [[ $nested -eq 1 ]] ; then
        awk -v pl="$1" -v pr="$2" '
            BEGIN{
                lenPl = split(pl, arryPl) ;
                lenPr = split(pr, arryPr) ;
            }
            {
                num = split($0, arry) ;
                ps = pe = cnt = 0 ;

                for(i=1; i<=num-lenPl+1; i++){

                    if(i <= num-lenPl+1){
                        for(j=1; j<=lenPl; j++){
                            if(arryPl[j] != arry[i+j-1]) break ;
                        }
                        if(j>lenPl){
                            cnt++ ; 
                            if(cnt == 1) ps = i ;
                        }
                    }

                    if(i <= num-lenPr+1){
                        for(k=1; k<=lenPr; k++){
                            if(arryPr[k] != arry[i+k-1]) break ;
                        }
                        if(k>lenPr){
                            cnt-- ;
                            if(cnt < 0){
                                cnt = 0 ;
                            }else if(cnt == 0){
                                pe = i+lenPr-1 ;
                                break ;
                            }else{
                                ;
                            }
                        }
                    }
                }

                if(ps && pe){
                    outStr = "" ;
                    for(i=1; i<=num; i++){
                        if(i>=ps && i<=pe) continue ;
                        outStr = outStr arry[i] ;
                    }
                }else{
                    outStr = $0 ;
                }

                print outStr ;

            }
            '
    else
        awk -v pl="$1" -v pr="$2" '
            {
                str = $0 ;
                out = "" ;

                while(str){
                    ps = index(str, pl) ;
                    if(!ps) break ;

                    pe = index(substr(str,ps+2), pr) ;
                    if(!pe) break ;

                    out = out substr(str,1,ps-1) ;
                    str = substr(str,ps+1+pe+2) ;
                }
                print out str ;
            }
            '
    fi
}

cfileList=$@
let i=0

while (( 1 ))
do 

    fl=$(echo "$cfileList" | awk -v s=$((i*100+1)) -v e=$((i*100+100)) 'BEGIN{RS="[ ]+";} (NR>=s && NR<=e){print;}')

    [[ -z "$fl" ]] && break ;
    [[ i -eq 1 ]] && break ;


    raw=$( 
        getParagraph.sh --patHead='/^\/\*\*\*\*\*\*/' --patTail='/^(    |\t)}/' --outputLineSep='\\012' $fl |
        removePairs '/*' '*/' 0
    )

    idxVoidFct=$(
        echo "$raw" |
        sed -E 's/\s*\\012\s*/ /g; s/\s{2,}/ /g; s/\)\s?\{.* @/){...} @/' |  # cat -; exit ;
        rev | #cat - ; exit ;
        removePairs ')' '(' 1 | #cat - ; exit ;
        rev | #cat - ; exit ;
        cat -n |
        grep -E 'void(\s|\))\s?[a-zA-Z_][a-zA-Z_0-9]*\{'  |  #cat - ; exit ;
        sed -E 's/^\s*([0-9]+).*/\1/'
    )

    echo "$raw" |
    awk -v idxVoidFct="$idxVoidFct"  '
        BEGIN{
            num = split(idxVoidFct, idxArry, "\n") ;
            for(i=1; i<=num; i++) idxArryHash[idxArry[i]] = 1 ;
        }

        (NR in idxArryHash){
            print ;
        }
        '   |
    sed -E 's/^.*return[^;]*;/return;/' |
    grep -Ev '^return[^}]*}[^}]*@[^@]+::[0-9]+-[0-9]+$' |
    sed -E 's/.*@\s*//; s/::[0-9]+-/::/; s/^/[check "latest_return" in function]* needs a "return @ "/'

    let i++ ;

done

