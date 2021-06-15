#! /bin/bash

awk '
    function split2(    \
        str,
        arry,
        sep,            \
                        \
        i,len)
    {
        len = split(str,arry,sep) ;

        if(len>0){
            for(i=1; i<=len; i++){
                arry[i-1] = arry[i] ;
            }
            delete arry[i] ;
        }

        return len ;
    }

    function getAvg(    \
        arry,           #1 dimension
        arryLen,
        dur,
        outArry,        \
                        \
        i,t,avg)
    {
        if(dur<=1){
            for(i=1;i<=arryLen;i++){
                outArry[i] = arry[i] ;
            }
            return ;
        }
    
        for(i=0;i<arryLen;i++){
    
            t += arry[i] ;
    
            if(i<dur){
                avg = t / (i+1) ;
            }else{
                t -= arry[i-dur] ;
                avg = t / dur ;
            }
    
            outArry[i] = avg ;
        }
    
        return ;
    }

    function getColAvg(     \
        arry,               # 2 dimentions
        rows,
        cols,
        colIdx,
        dur,
        outArry,
        overWrite,          \
                            \
        i,a)
    {
        if(dur<=1){
            for(i in arry){
                outArry[i] = arry[i] ;
            }
            return ;
        }

        for(i=0; i<rows; i++){
            a[i] = arry[i,colIdx] ;
        }

        getAvg(a,rows,dur,outArry) ;
        
        if(overWrite){
            for(i=0; i<rows; i++){
                arry[i,colIdx] = outArry[i] ;
            }
        }

        return ;
    }

    BEGIN{
        rows = 0 ;
        cols = 0 ;
        closePriceIdx = 1 ;
        k5dur = 5 ;
        k22dur = 22 ;
        k66dur = 66 ;
        k132dur = 132 ;
        k264dur = 264 ;
        kLineNum = 5 ;
        cnt = split2("0,1,2,3,4,7,8",colsIdx,",") ;

    }

    ($0!~"#"){
        rows ++ ;
        if(NF > cols) cols = NF ;

        for(i=0; i<NF; i++){
            content[rows-1,i] = $(i+1) ;
        }
    }

    END{
        getColAvg(content,rows,cols,closePriceIdx,k5dur,k5,0) ;
        getColAvg(content,rows,cols,closePriceIdx,k22dur,k22,0) ;
        getColAvg(content,rows,cols,closePriceIdx,k66dur,k66,0) ;
        getColAvg(content,rows,cols,closePriceIdx,k132dur,k132,0) ;
        getColAvg(content,rows,cols,closePriceIdx,k264dur,k264,0) ;

        for(i=0;i<rows;i++){
            for(j=0;j<cnt+kLineNum;j++){
                if(j<cnt){
                    printf("%s ",content[i,colsIdx[j]]) ;
                }else if(j==cnt+0){
                    printf("%.3f ",k5[i]) ;
                }else if(j==cnt+1){
                    printf("%.3f ",k22[i]) ;
                }else if(j==cnt+2){
                    printf("%.3f ",k66[i]) ;
                }else if(j==cnt+3){
                    printf("%.3f ",k132[i]) ;
                }else if(j==cnt+4){
                    printf("%.3f ",k264[i]) ;
                }else{
                    ;
                }
            }
            print "" ;
        }
        
    }
    ' $1
