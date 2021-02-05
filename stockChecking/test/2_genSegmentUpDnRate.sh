#! /bin/bash

. $(dirname $0)/comm.lib

defDur=3
defOffset=1

echo -ne "*executing $0($$)\n" >&2

for i in "${@}"
do
    [[ ${i%%=*} == "--dur" ]] && dur=${i##*=} && continue
    [[ ${i%%=*} == "--offset" ]] && offset=${i##*=} && continue
    [[ ${i} == "--disSrc" ]] && disSrc=1 && continue
    [[ ${i:0:1} == "-" ]] && echo "unknown option:$i">&2 && doExit -1
    code=$i
done

[[ -z $code ]] && echo "no code specified">&2 && doExit -1

sortingRaw="sorting-raw/$code.raw"
[[ ! -f $sortingRaw ]] && echo "cannot find $sortingRaw">&2 && doExit -1

dur=${dur:-$defDur}
offset=${offset:-$defOffset}
disSrc=${disSrc:-1}
describtion="#input:\n\
#\t(1)sorting (2)amp (3)date (4)close (5)hig (6)low (7)open (8)amp (9)xchg (10)vol (11)val (12)1k=avg (13)5k (14)22k (15)66k (16)132k (17)264k\n\
#output:\n\
#\t(1)sorting (2)upAMPCeiling (3)upAMPFloor (4)dnAMPCeiling (5)dnAMPFloor (6)durAmp (7)dateStart (8)dateEnd (9)curDate (10)open (11)close (12)hig (13)low (14)srcFile"

echo "*[$code]" >&2
echo *dur=$dur >&2
echo *offset=$offset >&2
echo *disSrc=$disSrc >&2
echo *source=$sortingRaw >&2


awk                             \
-v dur="$dur"                   \
-v offset="$offset"             \
-v disSrc="$disSrc"             \
-v sourceFile="$sortingRaw"     \
    '

    '"$awkFunction_getMaxMin"'
    '"$awkFunction_getSum"'

    function getSegData(        \
        dailyData,          #include  "date","xchg","vol","val","cls","hig","low"
        len,
        dur,
        offset,             #specified where to count from
        higCA,              #output arry, for high ceiling, base on 0
        higFA,              #output arry, for high floor, base on 0
        lowCA,              #output arry, for low ceiling, base on 0
        lowFA,              #output arry, for low floow, base on 0
        dateStart,          #output arry, base on 0
        dateEnd,            #output arry, base on 0
        durOpen,            #output arry, base on 0
        durClose,           #output arry, base on 0
        durAmp,             #output arry, base on 0
        durXchg,            #output arry, base on 0
        durVol,             #output arry, base on 0
        durVal,             #output arry, base on 0
                            \
        _from,_to,_lastIdx,_firstIdx,_outputA,_higCIdx,_higFIdx,_lowCIdx,_lowFIdx,i     \
    )
    {
        _firstIdx = (offset+0<0) ? (0-offset) : 0 ;
        _lastIdx  = (offset+0<0) ? (len-1) : (len-dur-offset) ;
        if(dur+0<1 || len+0<1 || _firstIdx+0<0 || _firstIdx+0>len-1 || _lastIdx+0<0 || _lastIdx+0>len-1) return -1 ;

        #update [0,_firstIdx-1]
        {
            for(i=_lastIdx+1; i<=len-1; i++){
                higCA[i] = "NONE" ;
                higFA[i] = "NONE" ;
                lowCA[i] = "NONE" ;
                lowFA[i] = "NONE" ;
                dateStart[i] = "NONE" ;
                dateEnd[i] = "NONE" ;
                durOpen[i] = "NONE" ;
                durClose[i] = "NONE" ;
                durAmp[i] = "NONE" ;
                durXchg[i] = "NONE" ;
                durVol[i] = "NONE" ;
                durVal[i] = "NONE" ;
            }
        }

        #update _firstIdx element
        {
            #print "===" ;
            _from = _firstIdx + offset ;
            _to = _firstIdx + offset + dur - 1 ;

            #update higCA,higFA,lowCA,lowFA
            {
                getMaxMin(dailyData,_from,_to,_outputA,0,"hig"SUBSEP) ;
                _higCIdx = _outputA["maxIdx"] ;
                _higFIdx = _outputA["minIdx"] ;
                higCA[_firstIdx] = 100*(dailyData["hig",_higCIdx] - dailyData["cls",_firstIdx])/dailyData["cls",_firstIdx] ;
                higFA[_firstIdx] = 100*(dailyData["hig",_higFIdx] - dailyData["cls",_firstIdx])/dailyData["cls",_firstIdx] ;
                getMaxMin(dailyData,_from,_to,_outputA,0,"low"SUBSEP) ;
                _lowCIdx = _outputA["maxIdx"] ;
                _lowFIdx = _outputA["minIdx"] ;
                lowCA[_firstIdx] = 100*(dailyData["low",_lowCIdx] - dailyData["cls",_firstIdx])/dailyData["cls",_firstIdx] ;
                lowFA[_firstIdx] = 100*(dailyData["low",_lowFIdx] - dailyData["cls",_firstIdx])/dailyData["cls",_firstIdx] ;
            }
            
            #update dateStart,dateEnd,durOpen,durClose,durAmp,durXchg,durVal,durVal
            {
                dateStart[_firstIdx] = dailyData["date",_from] ;
                dateEnd[_firstIdx] = dailyData["date",_to] ;
                durOpen[_firstIdx] = dailyData["cls",_firstIdx] ;
                durClose[_firstIdx] = dailyData["cls",_to] ;
                durAmp[_firstIdx] = 100*(durClose[_firstIdx]-durOpen[_firstIdx])/durOpen[_firstIdx] ;
                durXchg[_firstIdx] = getSum(dailyData,_from,_to,"xchg"SUBSEP) ;
                durVol[_firstIdx] = getSum(dailyData,_from,_to,"vol"SUBSEP) ;
                durVal[_firstIdx] = getSum(dailyData,_from,_to,"val"SUBSEP) ;
            }
        }

        #update [_firstIdx+1,_lastIdx]
        {
            for(i=_firstIdx+1; i<=_lastIdx+0; i++){

                _from = i + offset ;
                _to = i + offset + dur - 1 ;

                #update higCA,higFA,lowCA,lowFA
                {
                    #remove _from-1 and add _to
                    #print "update",i,"with",_from,"to",_to ;

                    if(dailyData["hig",_to]+0 >= dailyData["hig",_higCIdx]+0) _higCIdx = _to ;
                    if(dailyData["hig",_to]+0 <= dailyData["hig",_higFIdx]+0) _higFIdx = _to ;
                    if(dailyData["low",_to]+0 >= dailyData["low",_lowCIdx]+0) _lowCIdx = _to ;
                    if(dailyData["low",_to]+0 <= dailyData["low",_lowFIdx]+0) _lowFIdx = _to ;
                    if(_higCIdx == _from-1 || _higFIdx == _from-1){
                        getMaxMin(dailyData,_from,_to,_outputA,0,"hig"SUBSEP) ;
                        _higCIdx = _outputA["maxIdx"] ;
                        _higFIdx = _outputA["minIdx"] ;

                    }
                    if(_lowCIdx == _from-1 || _lowFIdx == _from-1){
                        getMaxMin(dailyData,_from,_to,_outputA,0,"low"SUBSEP) ;
                        _lowCIdx = _outputA["maxIdx"] ;
                        _lowFIdx = _outputA["minIdx"] ;
                    }

                    higCA[i] = 100*(dailyData["hig",_higCIdx]-dailyData["cls",i])/dailyData["cls",i] ;
                    higFA[i] = 100*(dailyData["hig",_higFIdx]-dailyData["cls",i])/dailyData["cls",i] ;
                    lowCA[i] = 100*(dailyData["low",_lowCIdx]-dailyData["cls",i])/dailyData["cls",i] ;
                    lowFA[i] = 100*(dailyData["low",_lowFIdx]-dailyData["cls",i])/dailyData["cls",i] ;
                    #print "     hig:" _higCIdx,_higFIdx, "[",dailyData["cls",i],dailyData["hig",_higCIdx], dailyData["hig",_higFIdx],"]", higCA[i],higFA[i] ;
                    #print "     low:" _lowCIdx,_lowFIdx, "[",dailyData["cls",i],dailyData["low",_lowCIdx], dailyData["low",_lowFIdx],"]", lowCA[i],lowFA[i] ;
                }

                #update dateStart,dateEnd,durOpen,durClose,durAmp,durXchg,durVal,durVal
                {
                    dateStart[i] = dailyData["date",_from] ;
                    dateEnd[i] = dailyData["date",_to] ;
                    durOpen[i] = dailyData["cls",i] ;
                    durClose[i] = dailyData["cls",_to] ;
                    durAmp[i] = 100*(durClose[i]-durOpen[i])/durOpen[i] ;
                    durXchg[i] = getSum(dailyData,_from,_to,"xchg"SUBSEP) ;
                    durVol[i] = getSum(dailyData,_from,_to,"vol"SUBSEP) ;
                    durVal[i] = getSum(dailyData,_from,_to,"val"SUBSEP) ;
                }
            }
        }

        #update [_lastIdx+1,len-1]
        {
            for(i=_lastIdx+1; i<=len-1; i++){
                higCA[i] = "NONE" ;
                higFA[i] = "NONE" ;
                lowCA[i] = "NONE" ;
                lowFA[i] = "NONE" ;
                dateStart[i] = "NONE" ;
                dateEnd[i] = "NONE" ;
                durOpen[i] = "NONE" ;
                durClose[i] = "NONE" ;
                durAmp[i] = "NONE" ;
                durXchg[i] = "NONE" ;
                durVol[i] = "NONE" ;
                durVal[i] = "NONE" ;
            }
        }

        return 0 ;
    }

    BEGIN{
        #print "#reading from " (sourceFile ? sourceFile : "-") ;
        #print "#input:" 
        #print "#    (1)sorting (2)amp (3)date (4)close (5)hig (6)low (7)open (8)amp (9)xchg (10)vol (11)val (12)1k=avg (13)5k (14)22k (15)66k (16)132k (17)264k" ;
        #print "#output:"
        #print "#    (1)sorting (2)amp (3)date (4)close (5)hig (6)low (7)open (8)amp (9)xchg (10)vol (11)val (12)1k=avg (13)5k (14)22k (15)66k (16)132k (17)264k" ;
        #print "#    (18)upAMPCeiling (19)upAMPFloor (20)dnAMPCeiling (21)dnAMPFloor (22)durAmp (23)dateStart (24)dateEnd" ;
        #print "#    [(30)srcFile]" ;

        cnt = 0 ;
    }
    
    {
        if($1 ~ "#") next ;

        dailyData["cls",cnt] = $4 ;
        dailyData["hig",cnt] = $5 ;
        dailyData["low",cnt] = $6 ;
        dailyData["date",cnt] = $3 ;
        dailyData["xchg",cnt] = $9 ;
        dailyData["vol",cnt] = $10 ;
        dailyData["val",cnt] = $11 ;
        content[cnt] = $0 ;
        cnt ++ ;
    }

    END{
        getSegData(dailyData,       #include  "date","xchg","vol","val","cls","hig","low"
                   cnt,dur,offset,
                   durHigCA,durHigFA,durLowCA,durLowFA,dateStart,dateEnd,durOpen,durClose,durAmp,durXchg,durVol,durVal) ;
        for(i=0; i<cnt; i++){
            srcFile = disSrc ? FILENAME : "" ;
            print content[i],durHigCA[i]"%",durHigFA[i]"%",durLowCA[i]"%",durLowFA[i]"%",durAmp[i],dateStart[i],dateEnd[i],durOpen[i],durClose[i],durXchg[i],durVol[i],durVal[i],srcFile ;
        }
    }
    ' $sortingRaw   |


./serialize.sh --seed=1 \
               --describtion="$describtion"    \
               --format='"%-27s %6.2f%% %6.2f%% %6.2f%% %6.2f%% %6.2f%% %10s %10s %10s %7.2f %7.2f %7.2f %7.2f %s\n",$1,$18,$19,$20,$21,$22,$23,$24,$3,$7,$4,$5,$6,$30'
#                        (1)sorting (2)upP (3)upN  (4)dnP (5)dnN (6)durAMP (7)dateS (8)dateE (9)DateC (10)opn (11)cls (12)hig (13)low (14)srcFile"

doExit 0 




