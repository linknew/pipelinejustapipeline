#!  /bin/bash

ignErr=1 ;

sourceFileInStoce=$1
sourceFileLocal=$2


git log -- $sourceFileInStoce | 

awk '

    BEGIN{
        print "\n--- commit_log vs modify_history ---\n" ;
    }

    {
        _up = toupper($1) ;

        if($1 == "commit"){
            logIdx ++ ;
            commitId[logIdx] = $2 ;
        }else if($1 == "Author:"){
            author[logIdx] = $2 ;
            authorEmail[logIdx] =$NF ;
        }else if($1 == "Date:"){
            date[logIdx] = (($4+0<10)? 0$4 : $4) $3 substr($6,3,2) ;
        }else if(_up ~ /^CERT|^CCR/){
            sub(/:/, " ") ;
            $1 = "" ;
            ccr[logIdx] = ccr[logIdx] $0 ;
        }else if(_up ~ /^JIRA/){
            sub(/:/, " ") ;
            $1 = "" ;
            jira[logIdx] = jira[logIdx] $0 ;
        }else if(_up ~ /^PR/){
            sub(/:/, " ") ;
            $1 = "" ;
            pr[logIdx] = pr[logIdx] $0 ;
        }else if($0 ~ /^[ \t]*$/){
            next ;
        }else{
            commitInfo[logIdx] = commitInfo[logIdx] "\n" $0 ;
        }
    }

    END{
        idx = 1 ;
        for(i=1; i<=logIdx; i++){
            gsub(/^ +| +$/, "", jira[i]) ;
            gsub(/ +/, "/", jira[i]) ;
            #printf("[%s] %10s %10s %s %s\n\n", jira[i], date[i], author[i], authorEmail[i], commitInfo[i])  ;
            printf("%02d: %s %s [*%s] %s\n    * maybe %s is the US_ID\n    * please check %s\n\n", idx++, date[i], author[i], jira[i], commitInfo[i],jira[i],commitId[i])  ;
        }
    }

    ' > /tmp/.$$.gitlog

(echo -ne "\n\n"; sed -n '/^modification history/,/^\*\//{p;} ' $sourceFileLocal | 
    awk 'BEGIN{print "";} {if($1 ~ /^[0-3]/){print "@",$0,"[" (++idx) "]";}else{print "@",$0;} }' )    |   
paste /tmp/.$$.gitlog -
echo ""

rm -rf /tmp/.$$.gitlog 2>/dev/null

exit
