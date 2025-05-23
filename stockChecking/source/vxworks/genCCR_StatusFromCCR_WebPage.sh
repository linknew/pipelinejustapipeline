#! /bin/bash

#. comm.lib


awk -F"\t"      \
                \
    '

    function PRT(                   \
        status,                     # arry for print
                                    # following are local variables
        i, j, segNum, subScript     \
        )
    {
        for(i in status){
            segNum = split(i, subScript, SUBSEP) ;
            for(j=1; j<=segNum; j++) printf("%s ", subScript[j]) ;
            printf("%s\n", status[i]) ;
        }
    }

    BEGIN{
        print "# fileIdx filename reviewer commentLocation commentStatus" ;
    }

    {
        if(FNR == 1){
            # a new file will be procceed

            # print last
            PRT(status) ;

            # inital for new file
            {
                isHead = 1 ;
                reviewerNum = 0 ;
                commentStart = 3 ;  # this value is updated when find keyword "Files"
                fileIdx = 0 ;
                #reviewers[COMMENTPOS] = POS ;
                #status[REVIEW,FILENAME,LINELOCATION] = STATUS ;
                #files[IDX] = FILENAME ;                        #idx start from 1 ;

                delete reviewers ;
                delete files ;
                delete status ;
            }
        }

        if($0 ~ /^[ \t]*$/) next ;

        if(isHead){
            if($0 ~ /^[ \t]*Files[ \t]*$/){
                for(i=1; i<=NF; i++){
                    if("Files" == $i){
                        commentStart = i+1 ;
                        #print commentStart > "/dev/stderr" ;
                        break ;
                    }
                }
                next ;
            }

            if($2 == "Location "){
                isHead = 0 ;
                next ;
            }

            reviewerNum ++ ;
            reviewerPos = commentStart + reviewerNum - 1 ;      # the comment status for each reviewer is from segment 2
            reviewers[reviewerPos] = $1 ;
            sub(/ /, "", reviewers[reviewerPos]) ;
            next ;
        }

        if($(commentStart-1) ~ /^Folder/) next ;

        if($(commentStart-1) ~ /File/){
            curFile = $(commentStart-1) ; sub(/^.*File/, "", curFile) ;
            files[++fileIdx] = curFile ;
            #print $(commentStart-1), curFile > "/dev/stderr" ;
        }

        commentLocation = $(commentStart + reviewerNum) ;       # the location of comment recored by the segment after the last reviewer
        commentLocation = substr(commentLocation, 6) + 0 ;

        for(i = commentStart; i <= commentStart + reviewerNum - 1; i ++){
            reviewer = reviewers[i] ;
            status[fileIdx, files[fileIdx], reviewer, commentLocation] = ($i ~ /^[ \t]*$/) ? "NoComment" : $i ;
            #print reviewer, curFile, commentLocation, $i ;
        }
    }

    END{
        PRT(status) ;
    }

    '   "$1"

exit

