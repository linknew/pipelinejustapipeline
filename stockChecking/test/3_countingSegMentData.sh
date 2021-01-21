#! /bin/bash

. $(dirname $0)/comm.lib

echo -ne "*executing $0($$)\n" >&2

awk '
    '"$awkFunction_qsort"'

#do counting
    BEGIN{
        print "#input:" ;
        print "#\t(1)sorting (2)upAMPCeiling (3)upAMPFloor (4)dnAMPCeiling (5)dnAMPFloor (6)durAmp (7)dateStart (8)dateEnd (9)curDate (10)close (11)srcFile"
        print "#output:" ;
        print "#\t(1)count (2)cntUP/cntUN (3)cntUP(ttUP/cntUP (4)cntUN(ttUN/cntUN) (5)cntDP(ttDP/cntDP) (6)cntDN(ttDN/cntDN) (7)cntAP/cntAN (8)cntAP(ttAP/cntAP) (9)cntAN(ttAN/cntAN) (10)serialized-sorting" ;
    }

    !/#/{
        cnt[$1] ++ ;
        ttUp[$1] += $2 ;
        ttDn[$1] += $5 ;

        if($2+0>0){
            cntUpP[$1] ++ ;
            upP[$1,cntUpP[$1]-1] = $2 ;
            ttUpP[$1] += $2 ;
        }else{
            cntUpN[$1] ++ ;
            upN[$1,cntUpN[$1]-1] = $2 ;
            ttUpN[$1] += $2 ;
        }

        if($5+0<0){
            cntDnN[$1] ++ ;
            dnN[$1,cntDnN[$1]-1] = $5 ;
            ttDnN[$1] += $5 ;
        }else{
            cntDnP[$1] ++ ;
            dnP[$1,cntDnP[$1]-1] = $5 ;
            ttDnP[$1] += $5 ;
        }

        if($6+0>0){
            cntDurAmpP[$1] ++ ;
            durAmpP[$1,cntDurAmpP[$1]-1] = $6 ;
            ttDurAmpP[$1] += $6 ;
        }else{
            cntDurAmpN[$1] ++ ;
            durAmpN[$1,cntDurAmpN[$1]-1] = $6 ;
            ttDurAmpN[$1] += $6 ;
        }
    }

    END{
        #get rid of the first 1/20 MAXs and 1/20 MINs
        for(seed in cnt){
            #process UpP
            {
                _maxNum = _minNum = int(cntUpP[seed]/20) ;
                _from = _minNum ;
                _to = cntUpP[seed]-1-_maxNum ;
                _cnt = _to-_from+1 ;
                _tt = 0 ;
                if(_cnt>0){
                    for(i=0; i<=cntUpP[seed]-1; i++) _indexArry[i] = seed SUBSEP i ;
                    qsort(upP,_indexArry,_from,_to) ;
                    for(i=_from; i<=_to; i++) _tt += upP[seed,i] ;
                    avrgUpP[seed] = _tt/_cnt ;
                }else{
                    avrgUpP[seed] = "-inf" ;
                }
                cntUpP[seed] = _cnt ;
            }

            #process UpN
            {
                _maxNum = _minNum = int(cntUpN[seed]/20) ;
                _from = _minNum ;
                _to = cntUpN[seed]-1-_maxNum ;
                _cnt = _to-_from+1 ;
                _tt = 0 ;
                if(_cnt>0){
                    for(i=0; i<=cntUpN[seed]-1; i++) _indexArry[i] = seed SUBSEP i ;
                    qsort(upN,_indexArry,_from,_to) ;
                    for(i=_from; i<=_to; i++) _tt += upN[seed,i] ;
                    avrgUpN[seed] = _tt/_cnt ;
                }else{
                    avrgUpN[seed] = "inf" ;
                }
                cntUpN[seed] = _cnt ;
            }

            #process DnP
            {
                _maxNum = _minNum = int(cntDnP[seed]/20) ;
                _from = _minNum ;
                _to = cntDnP[seed]-1-_maxNum ;
                _cnt = _to-_from+1 ;
                _tt = 0 ;
                if(_cnt>0){
                    for(i=0; i<=cntDnP[seed]-1; i++) _indexArry[i] = seed SUBSEP i ;
                    qsort(dnP,_indexArry,_from,_to) ;
                    for(i=_from; i<=_to; i++) _tt += dnP[seed,i] ;
                    avrgDnP[seed] = _tt/_cnt ;
                }else{
                    avrgDnP[seed] = "-inf" ;
                }
                cntDnP[seed] = _cnt ;
            }

            #process DnN
            {
                _maxNum = _minNum = int(cntDnN[seed]/20) ;
                _from = _minNum ;
                _to = cntDnN[seed]-1-_maxNum ;
                _cnt = _to-_from+1 ;
                _tt = 0 ;
                if(_cnt>0){
                    for(i=0; i<=cntDnN[seed]-1; i++) _indexArry[i] = seed SUBSEP i ;
                    qsort(dnN,_indexArry,_from,_to) ;
                    for(i=_from; i<=_to; i++) _tt += dnN[seed,i] ;
                    avrgDnN[seed] = _tt/_cnt ;
                }else{
                    avrgDnN[seed] = "inf" ;
                }
                cntDnN[seed] = _cnt ;
            }

            #process DurAmpP
            {
                _maxNum = _minNum = int(cntDurAmpP[seed]/20) ;
                _from = _minNum ;
                _to = cntDurAmpP[seed]-1-_maxNum ;
                _cnt = _to-_from+1 ;
                _tt = 0 ;
                if(_cnt>0){
                    for(i=0; i<=cntDurAmpP[seed]-1; i++) _indexArry[i] = seed SUBSEP i ;
                    qsort(durAmpP,_indexArry,_from,_to) ;
                    for(i=_from; i<=_to; i++) _tt += durAmpP[seed,i] ;
                    avrgDurAmpP[seed] = _tt/_cnt ;
                }else{
                    avrgDurAmpP[seed] = "-inf" ;
                }
                cntDurAmpP[seed] = _cnt ;
            }

            #process DurAmpN
            {
                _maxNum = _minNum = int(cntDurAmpN[seed]/20) ;
                _from = _minNum ;
                _to = cntDurAmpN[seed]-1-_maxNum ;
                _cnt = _to-_from+1 ;
                _tt = 0 ;
                if(_cnt>0){
                    for(i=0; i<=cntDurAmpN[seed]-1; i++) _indexArry[i] = seed SUBSEP i ;
                    qsort(durAmpN,_indexArry,_from,_to) ;
                    for(i=_from; i<=_to; i++) _tt += durAmpN[seed,i] ;
                    avrgDurAmpN[seed] = _tt/_cnt ;
                }else{
                    avrgDurAmpN[seed] = "inf" ;
                }
                cntDurAmpN[seed] = _cnt ;
            }

        }

        for(i in cnt) printf("%06d  UP/UN=%5.2f  UP=%06d(%5.2f%%)  UN=%06d(%5.2f%%)  DP=%06d(%5.2f%%)  DN=%06d(%5.2f%%)  AP/AN=%5.2f  AP=%06d(%5.2f%%)  AN=%06d(%5.2f%%)  %s\n",
                            cnt[i],
                            (cntUpN[i] ? cntUpP[i]/cntUpN[i] : "inf") ,
                            cntUpP[i], (i in avrgUpP) ? avrgUpP[i] : "-inf" ,
                            cntUpN[i], (i in avrgUpN) ? avrgUpN[i] : "inf" ,
                            cntDnP[i], (i in avrgDnP) ? avrgDnP[i] : "-inf" ,
                            cntDnN[i], (i in avrgDnN) ? avrgDnN[i] : "inf" ,
                            (cntDurAmpN[i] ? cntDurAmpP[i]/cntDurAmpN[i] : "inf") ,
                            cntDurAmpP[i], (i in avrgDurAmpP) ? avrgDurAmpP[i] : "-inf" ,
                            cntDurAmpN[i], (i in avrgDurAmpN) ? avrgDurAmpN[i] : "inf" ,
                            i) ;
    }
    '


doExit 0 ;


