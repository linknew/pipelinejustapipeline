#! /bin/bash

fileList=""

#preCondition=$(
#    getParagraph.sh --patHead='/^[ \t]*#[ \t]*(if|elif|else|endif)/'    \
#                    --patTail='/[^\\]$/'                                \
#                    --outputLineSep='\n'                                \
#                    $@
#)

# use absolute path
for i in $@
do
    [[ -f "$i" ]] && pn=$( cd $(dirname $i); pwd; )/$(basename $i) || pn=$i
    fileList="$fileList $pn"
done

awk -v libPathname="check.preDefines"       \
    '

    function printLog(      \
        msg,                # string, mandatory, message for print
                            \
        type,               # bit, optional, message type, 1:runtime log 2:debug log
        redirect,           # int, optional, redirect, 1:normal 2:error
                            \
        i)
    {
        print msg > "/dev/stderr" ;
    }

    function loadDefines(   \
        pathname,
        libPathname,
        outArry,
                            \
        _idx, i, cont, sgNum)
    {
        delete outArry ;
        getCont = "grep " pathname " " libPathname ;

        getCont | getline cont ; close(getCont) ;
        printLog ("loadDefines for " pathname " from " libPathname, 2 , 2) ;
        printLog ("orgCont=       {" cont "}", 2 , 2) ;
        sgNum = split(cont, outArry, " +") ;

        for(i=1; i<=sgNum; i++){
            if(i==1){
                outArry["pathname"] = outArry[i] ;

            }else{
                _idx = index(outArry[i], "=") ;

                if(_idx){
                    outArry[substr(outArry[i], 1, _idx-1)] = substr(outArry[i], _idx+1) ;
                }else{
                    outArry[outArry[i]] = 1 ;
                }
            }
        }

        for(i=1; i<=sgNum; i++){
            delete outArry[i] ;
        }

        for(i in outArry){
            printLog (i " = {" outArry[i] "}", 2 , 2) ;
        }

        return sgNum ;
    }

    # return a string to semulate pattern, used in awk function which needs pattern
    function str2Pat(       \
        string,             # string, mandatory, the string for pattern
                            \
        i)
    {
        gsub(/[\^$.\[\]|()*+?\\]/, "\\\\&", string) ;
        return string ;
    }

    BEGIN{
        keyword = "cert" ;      # lower case
        prefixCmd4Shell = "(( " ;
        suffixCmd4Shell = " )) && echo 1 || echo 0" ;

        nttnOprMth = "!= >= <= == > <" ;
        nttnOprLgc = "&& || !" ;
        nttnOprBit = "~ & |" ;
        nttnKwd = "elif else endif ifdef ifndef defined define undef # if" ;
        nttnBrks="( )" ;

        spliter = nttnOprMth " " nttnOprLgc " " nttnOprBit " " nttnKwd " " nttnBrks;
        spliter = str2Pat(spliter) ;
        gsub(/ /, "|", spliter) ;
        spliter = spliter "| " ;        # only one unit specified here.
        printLog ("spliter: {" spliter "}" ,2 , 2) ;

#        trspTab["!="] = "!=" ;
#        trspTab[">="] = ">=" ;
#        trspTab["<="] = "<=" ;
#        trspTab["=="] = "==" ;
#        trspTab[">"] = ">" ;
#        trspTab["<"] = "<" ;
#        trspTab["&&"] = "&&" ;
#        trspTab["||"] = "||" ;
#        trspTab["!"] = "!" ;
#        trspTab["~"] = "~" ;
#        trspTab["&"] = "&" ;
#        trspTab["|"] = "|" ;
#        trspTab["("] = "(" ;
#        trspTab[")"] = ")" ;

        trspTab["elif"] = "" ;
        trspTab["else"] = "" ;
        trspTab["endif"] = "" ;
        trspTab["ifdef"] = "" ;
        trspTab["ifndef"] = "!" ;
        trspTab["defined"] = "" ;
        trspTab["#"] = "" ;
        trspTab["if"] = "" ;
        trspTab["define"] = "" ;
        trspTab["undef"] = "" ;

#        trspTab["_WRS_KERNEL"] = 1 ;
#        trspTab["CERT"] = 1 ;
#        trspTab["CERTIFICATE"] = 1 ;
#        trspTab["FTPS_TLS_CERT_FILE"] = 1 ;
#        trspTab["IPEAP_USE_DEFAULT_KEY_AND_CERT"] = 1 ;
#        trspTab["IPIKE_PAYLOAD_CERT_H"] = 1 ;
#        trspTab["IPSCEP_CA_RA_CERT_TEST"] = 1 ;
#        trspTab["PVT_CERT"] = 1 ;
#        trspTab["TDK_CERT_COVERAGE_ON"] = 1 ;
#        trspTab["TRUSTED_CERT"] = 1 ;
#        trspTab["WRHV_CERT"] = 1 ;
#        trspTab["WRHV_CERT_DEBUG"] = 1 ;
#        trspTab["WRHV_CERT_INCLUDE_MEM_INFO"] = 1 ;
#        trspTab["_NO_WORKAROUND_HELIXCERT_LLTP_VXBPCIDEVBARSIZE"] = 1 ;
#        trspTab["_VX_CERT"] = 1 ;
#        trspTab["_WRS_CONFIG_CERT"] = 1 ;
#        trspTab["_WRS_CONFIG_CERTTESTS_TDK_DEBUG"] = 1 ;
#        trspTab["_WRS_CONFIG_CERT_DEBUG"] = 1 ;
#        trspTab["_WRS_CONFIG_CERT_INLINE_DISABLE"] = 1 ;
#        trspTab["_WRS_CONFIG_HELIXCERTTESTS"] = 1 ;
#        trspTab["_WRS_CONFIG_HELIX_CERT"] = 1 ;
#        trspTab["_WRS_VX_CERT_WRHV_GUEST"] = 1 ;
    }

    # do global initial
    (FNR == 1){
        continousLine = 0 ;
        preprocessLvl = 0 ;
        pathNoInEachPreprocessLvl[preprocessLvl] = 1 ;
        rslt[preprocessLvl,pathNoInEachPreprocessLvl[preprocessLvl]] = 1 ;
        pn = FILENAME; sub("^.*/helix/", "helix/", pn) ;
        loadSuccess = loadDefines(pn, libPathname, preDefineArry) ;
    }

    {
        # get preprocess content, find out the lines started with "#if/#elif/#else/#endif/#define/#undef"
        {
            if(continousLine)
            {
                contentOrg = contentOrg $0 ;
                content = content $0 ;

                if($0 ~ /\\$/){
                    contentOrg = contentOrg "\n" ;
                    sub(/\\$/, "", content) ;
                    next ;
                }else{
                    continousLine = 0 ;
                }

            }else {

                if($0 !~ /^[ \t]*#[ \t]*(if|elif|else|endif|define|undef)/) next ;

                contentOrg = $0 ;
                content = $0 ;

                if($0 ~ /\\$/){
                    continousLine = 1 ;
                    contentOrg = contentOrg "\n" ;
                    sub(/\\$/, "", content) ;
                    next ;
                }
            }
        }

        # remove redundancy
        {
            sub(/\/\*.*\*\//, "", content) ;         # remove c type comments rudely
            sub(/\/\/.*/, "", content) ;             # remove c++ type comments
            gsub(/\t/, " ", content) ;               # replace table with space
            gsub(/^[ \t]+|[ \t]+$/, "", content) ;   # remove spaces from head and tail
            gsub(/[ \t]+/, " ", content) ;           # reduce redundant sapces
        }

        # update preprocessLvl, pathNoInEachPreprocessLvl and preDefineArry
        {
            if(content ~ /^ ?# ?if/){
                preprocessLvl ++ ;
                #pathNoInEachPreprocessLvl[preprocessLvl] ++ ;
                pathNoInEachPreprocessLvl[preprocessLvl] = 1 ;

            }else if(content ~ /^ ?# ?elif/){
                pathNoInEachPreprocessLvl[preprocessLvl] ++ ;

            }else if(content ~ /^ ?# ?else/){
                pathNoInEachPreprocessLvl[preprocessLvl] ++ ;

            }else if(content ~ /^ ?# ?endif/){
                pathNoInEachPreprocessLvl[preprocessLvl] = 0 ;
                preprocessLvl -- ;

            }else if(content ~ /^ ?# ?(define) /){
                # fix preDefineArry
                key = content; sub(/^ ?# ?define /, "", key) ;
                val = key ;
                sub(/ .*/, "", key) ;
                if(!sub(/^[^ ]+ /, "", val)){ val = 1; }

                if(1 == rslt[preprocessLvl,pathNoInEachPreprocessLvl[preprocessLvl]] ){
                    # is a open path
                    preDefineArry["-D"key] = val ;
                    printLog ("define -D"key "= {" val "}" ,2 , 2) ;

                }else if(unknownCheckCondition == rslt[preprocessLvl,pathNoInEachPreprocessLvl[preprocessLvl]] ){
                    # unknown_rslt path
                    if( !("-D"key in preDefineArry) || preDefineArry["-D"key] != val ){
                        preDefineArry["-D"key] = "unknownDefVal" ;
                        printLog ("define -D"key "= {" val "}" ,2 , 2) ;
                    }

                }else{
                    # no need to update
                    printLog ("blocked path, no #define executed", 2, 2) ;
                }

                next ;

            }else if(content ~ /^ ?# ?(undef) /){
                # fix preDefineArry
                key = content; sub(/.* /, "", key) ;

                if(1 == rslt[preprocessLvl,pathNoInEachPreprocessLvl[preprocessLvl]] ){
                    # is a open path
                    preDefineArry["-D"key] = 0 ;
                    printLog ("undefine -D"key "={" preDefineArry["-D"key] "}", 2, 2) ;

                }else if(unknownCheckCondition == rslt[preprocessLvl,pathNoInEachPreprocessLvl[preprocessLvl]] ){
                    # unknown_rslt path
                    if( !("-D"key in preDefineArry) || preDefineArry["-D"key] != 0 ){
                        preDefineArry["-D"key] = "unknownDefVal" ;
                        printLog ("undefine -D"key "={" preDefineArry["-D"key] "}", 2, 2) ;
                    }

                }else{
                    # no need to update
                    printLog ("blocked path, no #undef executed", 2, 2) ;
                }

                next ;

            }else{
                # FLOW_ERROR_1
                printLog("must be wrong flow @ " "'"$0"'" ":FLOW_ERROR_1", 1, 2) ;

            }

            # prepared 
            #   contentOrg for refer to original statements
            #   and content for one_whole_linenized statement
            printLog ("\ncontentOrg=    {" contentOrg "} @ " FILENAME ":" FNR , 2 , 2) ;
            printLog ("content=       {" content "} @ " FILENAME ":" FNR , 2 , 2) ;
            printLog ("preprocessLvl= {" preprocessLvl "}" , 2 , 2) ;
            printLog ("pathOfLvl=     {" pathNoInEachPreprocessLvl[preprocessLvl] "}", 2, 2) ;
        }

        # transport to a awk conditional sentence
        {
            cdtnChecking = content ;
            gsub(spliter, " & ", cdtnChecking) ;    # wrap spliter with space
            gsub(/^ +| +$/, "", cdtnChecking) ;     # remove spaces from head and tail
            notationNum = split(cdtnChecking, notations, / +/) ;
            printLog("notationNum=   {" notationNum "}", 2, 2) ;
            cdtnChecking = "" ;

            for(i=1; i<=notationNum; i++){

                printLog("notations[" i "]=  {" notations[i] "}", 2, 2) ;

                if(notations[i] in trspTab){
                    cdtnChecking = cdtnChecking " " trspTab[notations[i]] ;

                }else if("-D"notations[i] in preDefineArry){
                    cdtnChecking = cdtnChecking " " preDefineArry["-D"notations[i]] ;

                }else{
                    if(!loadSuccess){
                        printLog("*found unknown notation {" notations[i] "}, set to /unknown/ @ " FILENAME ":" FNR " # " contentOrg, 1, 2) ;
                        cdtnChecking = cdtnChecking " unknown " ;

                    }else{
                        printLog("*found undefined notation {" notations[i] "}, set to /0/ @ " FILENAME ":" FNR " # " contentOrg, 1, 2) ;
                        cdtnChecking = cdtnChecking " 0 " ;
                    }
                }
            }

            printLog ("cdtnChecking=  {" cdtnChecking "} @ " FILENAME ":" FNR , 2 , 2) ;
        }

        # get rslt of current path
        {
            pathNo = pathNoInEachPreprocessLvl[preprocessLvl] ;

            # the parent path is blocked
            if( preprocessLvl > 1 &&
                rslt[ preprocessLvl-1, pathNoInEachPreprocessLvl[preprocessLvl-1] ] != 1){
                
                rslt[preprocessLvl,pathNo] = "brokenCheckCondition" ;
            }

            # missing condition
            else if(cdtnChecking ~ /^ +$/ && content ~ /^ ?# ?(if|elif)/){

                printLog("*need checking conditions @ " FILENAME ":" FNR " # " contentOrg, 1, 2) ;

                rslt[preprocessLvl,pathNo] = "missingCheckCondition" ;
            }
            
            # no need condition
            else if(cdtnChecking !~ /^ +$/ && content ~ /^ ?# ?(else|endif)/){

                printLog("*no checking conditions needed @ " FILENAME ":" FNR " # " contentOrg, 1, 2) ;

                rslt[preprocessLvl,pathNo] = "uselessCheckCondition" ;
            }
            
            # has unknown checking codition
            else if(cdtnChecking ~ "unknown"){  #!~ /^[+-*\/ ()><=!&|^0-9]+$/){
                rslt[preprocessLvl,pathNo] = "unknownCheckCondition" ;
            }
                
            # set rslt for #if #ifdef #ifndef #if defined #elif
            else if(content ~ /^ ?# ?(if|elif)/){

                cdtnChecking = prefixCmd4Shell cdtnChecking suffixCmd4Shell ;
                printLog("cdtnChecking=  {" cdtnChecking "}", 2, 2) ;

                cdtnChecking | getline rsltFromBash ;
                rslt[preprocessLvl,pathNo] = rsltFromBash ;
                close(cdtnChecking) ;
            }

            # set rslt for #else
            else if(content ~ /^ ?# ?else/){

                #revert the rsult of all previous path

                rslt[preprocessLvl,pathNo] = 0 ;

                for(i=1; i< pathNo; i++){
                    if(rslt[preprocessLvl,i]"" == 1){
                        rslt[preprocessLvl,pathNo] = 0 ;
                        break ;
                    }else if(rslt[preprocessLvl,i]"" == "0"){
                        continue  ;
                    }else{
                        rslt[preprocessLvl,pathNo] = "brokenCheckCondition" ;
                        break ;
                    }
                }

                if(i == pathNo) rslt[preprocessLvl,pathNo] = 1 ;
            }

            #set rslt for #endif
            else if(content ~ /^ ?# ?endif/){
                # do nothing
            }

            else{
                # FLOW_ERROR_3
                printLog("must be wrong flow @ " "'"$0"'" ":FLOW_ERROR_3", 1, 2) ;
            }

            printLog ("rsltCurPath=   {" rslt[preprocessLvl,pathNo] "}" , 2 , 2) ;
        }

    } ' $fileList

