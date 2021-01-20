#! /bin/bash

. $(dirname $0)/comm.lib

echo -ne "*executing $0($$)\n" >&2

for i in "${@}"
do
    [[ $i == "--segment" ]] && segment=1 && continue ;
    [[ ${i:0:1} == "-" ]] && echo "unknown option:$i">&2 && doExit -1
    code=$i
done

[[ -z $code ]] && echo "no code specified">&2 && doExit -1
[[ ! -f data/$code.data ]] && echo "Cannot find data/$code.data" >&2 && doExit -1

echo "*[$code]" >&2

rawData=$(
    cat data/$code.data |

    awk '
        #do sorting: avg 5k 22k 66k 132k 264k

        '"$awkFunction_split2"'
        '"$awkFunction_qsort"'

        BEGIN{
            CONVFMT="%.2f"
            OFMT="%.2f"

            print "#input:"
            print "#(1)stockID, (2)closePrice, (3)power, (4)amplitude, (5)trueAmplitude, (6)rsi6"
            print "#\t(7)rsi12, (8)rsi24, (9)pwri6, (10)pwri12, (11)pwri24, (12)rsiFuture6, (13)pwriFuture12"
            print "#\t(14)exchange, (15)volume, (16)value, (17)liveValue, (18)date (19)rsiCustom (20)pwriCustom"
            print "#\t(21)xcgAvgICustom (22) gEgrData (23) highestAmp (24)open (25)hig (26)low (27)ystdClose"
            print "#\t(28)5kline (29)22kline (30)66kline (31)132kline (32)264kline (33)avg=1kline=$16/$15"
            print "#output:"
            print "#\t(1)[sorting] (2)amp (3)date (4)close (5)hig (6)low (7)open (8)amp (9)xchg (10)vol (11)val (12)1k=avg (13)5k (14)22k (15)66k (16)132k (17)264k"
            idxs=split2("32,27,28,29,30,31",sortIdxs,",") ; #base on 0
            split2("stockID,closePrice,power,amplitude,trueAmplitude,rsi6,rsi12,rsi24,pwri6,pwri12,pwri24,rsiFuture6,pwriFuture12,exchange,volume,value,liveValue,date,rsiCustom,pwriCustom,xcgAvgICustomg,EgrData,highestAmp,open,hig,low,ystdClose,5k,22k,66k,132k,264k,1k",names,",") ;
        }

        {
            if($1 ~ "#") next ;

            $33 = $16/$15 ;
            split2($0,a," ") ;
            for(i=0;i<idxs;i++) b[i]=sortIdxs[i] ;

            qsort(a,b,0,idxs-1) ;

            printf "[" ;
            for(i=0;i<idxs;i++){
                if(i==0) printf names[b[i]] ;
                else if(a[b[i]]+0>a[b[i-1]]+0) printf "<"names[b[i]] ;
                else printf "="names[b[i]] ;
            }
            print "]",$4,$18,$2,$25,$26,$24,$4,$14,$15,$16,$33,$28,$29,$30,$31,$32 ;
        }
        '
)

[[ -z $segment ]] && echo "$rawData" && doExit 0

echo "$rawData" |
awk '
#do segmentation
#input:
    #(1)[sorting] (2)amp
    #(3)date (4)close (5)hig (6)low (7)open (8)amp (9)xchg (10)vol (11)val (12)1k=avg
    #(13)5k (14)22k (15)66k (16)132k (17)264k

    BEGIN{
        print "#input:"
        print "#\t(1)[sorting] (2)amp (3)date (4)close (5)hig (6)low (7)open (8)amp (9)xchg (10)vol (11)val (12)1k=avg (13)5k (14)22k (15)66k (16)132k (17)264k" ;
        print "#output:"
        print "#\t(1)[sorting] (2)dur (3)open (4)close (5)hig (6)hig% (7)low (8)low% (9)from (10)to" ;
    }

    ($0!~"#"){

        if($1 == seed){
            #update
            cnt ++ ;
            cls = $4 ;
            to  = $3 ;
            if(hig+0<$5+0) hig = $5 ;
            if(low+0>$6+0) low = $6 ;
        }else{
            #update && complete a segment
            if(seed != ""){
                cls = $4 ;
                to  = $3 ;
                if(hig+0<$5+0) hig = $5 ;
                if(low+0>$6+0) low = $6 ;
                printf("%s %2d %5.2f %5.2f %5.2f %5.2f%% %5.2f %6.2f%% %s %s\n",
                        seed,cnt,opn,cls,hig,100.0*(hig-opn)/opn,low,100.0*(low-opn)/opn,from,to) ;
            }
            #set new
            seed = $1 ;
            cnt = 1 ;
            opn = $4 ;  #use close_price as the open_price of the segment
            cls = $4 ;
            hig = $4 ;
            low = $4 ;
            from = $3 ;
        }
    }

    END{
        printf("%s %2d %5.2f %5.2f %5.2f %5.2f%% %5.2f %6.2f%% %s %s\n",
               seed,cnt,opn,cls,hig,100.0*(hig-opn)/opn,low,100.0*(low-opn)/opn,from,to) ;
    }
    '

doExit 0 ;

