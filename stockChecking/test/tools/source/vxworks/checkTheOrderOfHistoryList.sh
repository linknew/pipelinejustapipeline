#!  /bin/bash

ignErr=1 ;

sourceFile=$1
checkingDateOrder=0

awk -v ignErr=$ignErr                           \
    -v checkingDateOrder=$checkingDateOrder     \
    '                                           \

    BEGIN{
        monAbbList="jan,feb,mar,apr,may,jun,jul,aug,sep,oct,nov,dec" ;
        split(monAbbList, aMonAbb, ",") ;
        for(i=1; i<=12; i++){
            hMon[aMonAbb[i]] = i ;
        }
    }

    #/^[ \t]*\*[ \t]*Copyright|^[ \t]*\/\*[ \t]*Copyright/{
    /^[ \t]*\/?\*[ \t]*Copyright/{
        copyrightOrg = $0 ;

        if($0 !~ "Wind"){
            while(getline){
                copyrightOrg = copyrightOrg "\n" $0 ;
                if($0 ~ /Wind|^[ \t]*\*[ \t]*$|^[ \t]*\*\//) break ;
            }
        }

        gsub(/[ \t]*\n[ \t]*\*[ \t]*/, " ", copyrightOrg) ;
        sub(/Wind.*/, "Wind River Systems, Inc.", copyrightOrg) ;

        next ;
    }

    /^modification history/{
        mdfHisStart=1 ;
        lastDate="999999" ;
        getline ;
        getline ;
        print "\n--- module copyright & history checking ---\n" ;
    }

    (mdfHisStart){
        if($0 ~ /\*\//){
            mdfHisStart=0 ;
            next ;
        }

        #print $0 ;

        # illegal history
        if($0 !~ /^[0-3][0-9][a-z][a-z][a-z][0-9][0-9],[a-z_][a-z_][a-z_ 0-9]  [^ \t\n\r]/ && $0 !~ /^             [^ \t\r\n]/){
            print "    * use \047ddmmmyy,ccc  \047 to start or 13 spaces for alignment, no TAB allowed @ line", FNR,"#","\047" $0 "\047" > "/dev/stdout" ;
            next ;
        }

        if($0 ~ /^ /) next ;    #continous entry

        mon = substr($1,3,3) ;
        if(!(mon in hMon)){
            print "    * month abbrevation is incorrect @",FILENAME "::" FNR,"#",$1 > "/dev/stdout" ;
            if(!ignErr) next ;
        }

        day2D = substr($1,1,2) ;
        mon2D = (hMon[mon]+0<10) ? "0" hMon[mon] : hMon[mon]"" ;
        year2D = substr($1,6,2) ;
        date = year2D mon2D day2D ;
        if(checkingDateOrder){
            if(date>lastDate){
                print "    * this entry does not arrange by date @",FILENAME "::" FNR,"#",$1,"[" date">"lastDate "]" > "/dev/stdout" ;
                if(!ignErr) next ;
            }
        }
        lastDate = date ;

        year = ("20"year2D >= "2031") ? "19"year2D : "20"year2D ;
        aYear[year] = 1 ;

    }

    END{
        start = 0 ;
        end = 0 ;
        firstComming = 1 ;

        copyrightGen = " * Copyright (c)" ;

        for(i=1931; i<=2031; i++){
            if(!aYear[i] && i !=2031) continue ;

            year = i+0 ;
            if(!start) start = i ;
            if(!end) end = i ;
            if(year-end>1){
                if(firstComming){
                    sp = " " ;
                    firstComming = 0 ; 
                }else{
                    sp = ", " ;
                }
                if(start == end) copyrightGen = copyrightGen sp start ;
                else copyrightGen = copyrightGen sp start "-" end ;
                start = year ;
            }
            end = year ;
        }

        copyrightGen = copyrightGen " Wind River Systems, Inc." ;

        if(copyrightOrg != copyrightGen) print copyrightOrg " [generated]\n" copyrightGen ;
    }

    ' $sourceFile

