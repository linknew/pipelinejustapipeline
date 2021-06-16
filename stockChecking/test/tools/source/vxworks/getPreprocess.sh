#! /bin/bash

[[ $WIND_PLATFORM != "helix" || $SHLVL -lt 2 ]] && echo -ne '\n!!go, back here after you have done "wrenv.sh -p helix"\n\n' >&2 && exit 3

helixBase=/ctu-cert1_02/mli2/workspace/vxworks/helix
CC=$helixBase/compilers/llvm-10.0.1.1/LINUX64/bin/clang
preprocInfoFile=check.preprocessInfo.data
fileList=""
fileListOrg=""
curDir=`pwd`
printSolidLineIdxes=${printSolidLineIdxes:-1}


# get options and fix prefix path
#{
    for i in "$@"  ; do
        [[ $i == "--printEmptyLineIdxes" ]] && printSolidLineIdxes=0 && continue ;
        [[ $i == "--genMidFile" ]] && genMidFile=1 && continue ;
        [[ $i == "--withNo" ]] && withNo=1 && continue ;

        [[ ! -f "$i" ]] && echo "!!cannot open the file $i" >&2 && continue ;

        [[ ${i:0:1} == "/" ]] && srcFile=$i || srcFile=$curDir/$i
        srcFile=$(echo $(cd ${srcFile%/*} && pwd)/${srcFile##*/})
        dstFile=${srcFile/*\/helix\//$helixBase/}

        # copy ccr files to helix project && update fileList
        cp $srcFile $dstFile && fileListOrg=$fileListOrg" "$srcFile && fileList=$fileList" "$dstFile

    done

    fileList=$(echo $fileList)              # remove redundant spaces
    fileListOrg=$(echo $fileListOrg)        # remove redundant spaces
    #echo "$fileList" ; exit
#}


preprocMassData=$(

awk -v preprocInfoFile="$preprocInfoFile"   \
    -v fileList="$fileList"                 \
    -v fileListOrg="$fileListOrg"           \
    -v sh="$SHELL"                          \
    -v CC="$CC"                             \
    '

    function printLog(      \
        msg,                # string, mandatory, message for print
                            \
        type,               # bit, optional, message type, 0:runtime log 1:debug log
        redirect,           # int, optional, redirect, 0:normal 1:error
        stayEndOfLine,      # int, optional, terminal behaviour, 0:newline 1:stay at the end
                            \
        i)
    {
        if(1 == type)       return ;

        if(!stayEndOfLine)   msg=msg "\n" ;

        if(0 == redirect)   printf msg ;
        else                printf msg > "/dev/stderr" ;
    }

    BEGIN{
        # load preprocess info
        {
            while( (getline < preprocInfoFile) > 0){

                if($0 ~ /^[ \t]*$/ || substr($0,1,1) == "#") continue ;

                tag = $0; gsub(/^\[|\].*/, "", tag);
                if(substr(tag, 1, 1) == "*"){
                    tag = substr(tag, 2) ;
                    tagNext = $0; gsub(/.* \[|\]$/, "", tagNext);
                    cmd = $0; gsub(/.*\] | \[.*/, "", cmd) ;

                }else{
                    tagNext = "" ;
                    cmd = $0; sub(/.*\] /, "", cmd) ;
                }

                gsub(/ \$CC /, " " CC " -E -C ", cmd) ;
                tags[tag] = tagNext ? tagNext : "" ;
                cmds[tag] = cmd ;
                printLog(tag "->" tags[tag], 1, 1) ;
                printLog(cmd, 1, 1) ;
            }
            close(preprocInfoFile) ;
        }

        # check each file
        {
            fileNum = split(fileList, files, / +/) ;
            fileNumOrg = split(fileListOrg, filesOrg, / +/) ;
            #print fileNum, fileNumOrg ; exit ;
            #assert(fileNum == fileNumOrg)

            for(i=1; i<=fileNum; i++){
                tagOrg = filesOrg[i] ;
                tag1ST = files[i] ;
                tag = tag1ST ;

                if(tag in tags){
                    tagNext = tags[tag] ;

                    #expand to last tag
                    while(tagNext){
                        printLog("*try to expand tag:" tag " to tag:" tagNext, 1, 1) ;

                        if(!(tag in cmds)){
                            printLog("!!cannot find index of " tag " in " preprocInfoFile, 0, 1) ;
                            break ;

                        }

                        printLog("*execute cmd:" cmds[tag],1,1) ;
                        print cmds[tag] | sh ;
                        if(close(sh) == 0){
                            printLog("*[success]expand tag:" tag " to tag:" tagNext, 1, 1) ;
                        }else{
                            printLog("*[failed]expand tag:" tag " to tag:" tagNext, 0, 1) ;
                        }
                        tag = tagNext ;
                        tagNext = tags[tag] ;
                    }

                    if(tag in cmds){
                        preprocess[tag1ST] = cmds[tag] ;
                        map2Org[tag1ST] = tagOrg ;
                    }
                        
                }else{
                    printLog("!!cannot find index of " tag " in " preprocInfoFile, 0, 1) ;
                }
            }

            for(tag in preprocess){
                printLog("*[preprocessing...]\n  tag=" tag "\n  tagOrg="map2Org[tag], 1, 1) ;
                print "#*generate preprocessing text [" map2Org[tag] "] -> [" tag "]" ;
                printLog("*" preprocess[tag],1,1) ;
                print preprocess[tag] | sh ;
                if(close(sh) == 0){
                    printLog("*[success]", 1, 1) ;
                }else{
                    printLog("*[failed]", 0, 1) ;
                }

            }
        }
    }
    '
)

#get file mapping info
preprocFileMap=$(
    echo "$preprocMassData" | 
    grep -E '^#\*generate preprocessing text' | 
    sed -E 's/.*(\[.*\]) -> (\[.*\]).*/\1 \2/'
)

#generate preproc content
#echo "$preprocMassData" > .t
echo "$preprocMassData" |   #cat - ; exit

awk -v preprocFileMap="$preprocFileMap"         \
    -v printSolidLineIdxes=$printSolidLineIdxes \
    -v genMidFile=$genMidFile                   \
    -v withNo=$withNo                           \
    '
    function printLog(      \
        msg,                # string, mandatory, message for print
                            \
        type,               # bit, optional, message type, 0:runtime log 1:debug log
        redirect,           # int, optional, redirect, 0:normal 1:error
                            \
        i)
    {
        if(1 == type)       return ;

        if(0 == redirect)   print msg ;
        else                print msg > "/dev/stderr" ;
    }

    function catLineIdxes(  \
        lineIdxes,          # string, mandatory, lines idx of a file
                            \
        s, e, rslt, num, arry, i, h, t)
    {
        s = "" ;
        e = "" ;
        rslt = "" ;

        #!!! gsub(/^ *| *$/, "", lineIdxes) ;  <-- awk bug, the pattern /^ */ of gsub matches all spaces in whole string !!!!
        sub(/^ */, "", lineIdxes) ; sub(/ *$/, "", lineIdxes) ;

        num = split(lineIdxes, arry, / +/) ;

        for(i=1; i<=num; i++){
            h = arry[i]; sub(/-.*/, "", h) ;
            t = arry[i]; sub(/.*-/, "", t) ;

            if(!e){
                s = h ;
                e = t ;
            }else if(h == e+1){
                e = t ;
            }else{
                rslt = rslt ((s==e) ? s : s "-" e) " " ;
                s = h ;
                e = t ;
            }
        }

        rslt = rslt ((s==e) ? s : s "-" e) " " ;
        sub(/^ */, "", rslt) ; sub(/ *$/, "", rslt) ;

        return rslt ;
    }

    BEGIN{
        tagStrHead = "^# [0-9]+ \"" ;
        tagStrTail = "\"($|.* [12]$)" ;
    }

    END{
        
        if(genMidFile && mdf) close(mdf) ;

        if(printSolidLineIdxes){

            #printout solid lines info

            for(pn in solidLineIdxs){
                printLog("*before concatenate:" pn "\n" solidLineIdxs[pn], 1, 1) ;
                catRslt = catLineIdxes(solidLineIdxs[pn]) ;
                printLog("*after concatenate: " pn "\n" catRslt "\n", 1, 1) ;
                print "[" pn "]" catRslt ;
            }

        }else{

            #printout empty lines info 

            for(pn in emptyLineIdxs){
                printLog("*before concatenate:" pn "\n" emptyLineIdxs[pn], 1, 1) ;
                catRslt = catLineIdxes(emptyLineIdxs[pn]) ;
                printLog("*after concatenate: " pn "\n" catRslt "\n", 1, 1) ;
                print "[" pn "]" catRslt ;
            }
        }

    }

    {
        printLog("rawPreprocCont: " $0, 1, 1) ;
    }

    /^#\*generate preprocessing text/{

        orgFile = $0; gsub(/.*text \[|\].*/, "", orgFile) ;
        mappedFile = $0; gsub(/.*\[|\] *$/, "", mappedFile) ;
        tag = mappedFile; sub(/.*\//, "", tag) ;
        posWrite = 1 ;
        emptyLineIdxs[orgFile] = "" ;
        solidLineIdxs[orgFile] = "" ;
        printLog("*generating preprocess content for " orgFile, 1, 1) ;
        printLog("*collect all content from tag: " tag, 1, 1) ;
        if(genMidFile){
            if(mdf) close(mdf) ;
            mdf = orgFile; gsub(/\//, "_", mdf) ;
            mdf = mdf ".mdf" ;
        }
        next ;
    }

    ($0 ~ tagStrHead tag tagStrTail){
        printLog("*found tag:" tag " @ " $0, 1, 1) ;
        startCollect = 1 ;
        posSrcCode = $0; gsub(/^# *| *".*/, "", posSrcCode) ;
        printLog("*enable startCollect, set write position:" posWrite " # " $0, 1, 1) ;

        filler = "" ;
        for(i=posWrite; i<posSrcCode; i++) filler = filler "\n" ;
        if(filler){
            emptyLineIdxs[orgFile] = emptyLineIdxs[orgFile] posWrite "-" posSrcCode-1 " " ;
            posWrite = posSrcCode ;
            if(genMidFile) printf filler > mdf ;
            printLog(filler,1,1,1) ;
        }

        next ;
    }

    /^# [0-9]+ /{
        startCollect = 0 ;
        printLog("*disable startCollect # " $0, 1, 1) ;
        next ;
    }

    (startCollect){
        if($0 ~ /^$/){
            emptyLineIdxs[orgFile] = emptyLineIdxs[orgFile] posWrite " " ;
        }else{
            solidLineIdxs[orgFile] = solidLineIdxs[orgFile] posWrite " " ;
        }
        _no = (withNo) ? (posWrite " ")  : ("") ;
        if(genMidFile) print _no $0 > mdf ;
        printLog(posWrite " " $0, 1, 1) ;
        posWrite ++ ;
    }

    '
