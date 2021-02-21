#! /bin/bash

# counting the result of each seed

. comm.lib

doStart


verbose=$1 ;
start=$2 ;
end=$3 ;
skipNewBorn=60 ;
orgFunds=20000 ;
taxRatPrt=0.001 ;
taxRatHandFee=0.00035 ;



# in .t3.segData, the data list by stocks, but we want:
#   * the data sorting by date
# if the dates are same, we want:
#   * list these data by stock number

#before arrange
#   (1)sorting (2)upAMPCeiling (3)upAMPFloor (4)dnAMPCeiling (5)dnAMPFloor (6)durAmp (7)dateStart (8)dateEnd (9)curDate (10)open (11)close (12)hig (13)low (14)srcFile
#after arrange
#   (1)srcFile (2)sorting (3)upAMPCeiling (4)upAMPFloor (5)dnAMPCeiling (6)dnAMPFloor (7)durAmp (8)dateStart (9)dateEnd (10)curDate (11)open (12)close (13)hig (14)low

# do arrange, 
#   skip new brone stock, 
#   skip the data not included in specified date, 
#   ignore "NONE"
#   move code to the head
# sort by curDate
# do demonstration

awk -v skipNewBorn=$skipNewBorn     \
    -v startDate=$start             \
    -v endDate=$end                 \
    '

    !/#/{
        fcstStart = $7 ;
        fcstEnd = $8 ;
        cur = $9 ;
        code = substr($14,13,6) ;
        cnt[code]++ ;

        if(cnt[code] <= skipNewBorn) next ;
        if(startDate && cur < startDate) next ;
        if(endDate && cur > endDate) next ;
        if(fcstStart == "NONE") next ;

        $14 = "" ;
        print code, $0 ;
    }

    '   .t3.segData     | ./segSort.sh -10    |

    awk -v verbose=$verbose             \
        -v orgFunds=$orgFunds           \
        -v taxRatPrt=$taxRatPrt         \
        -v taxRatHandFee=$taxRatHandFee \
        '

        BEGIN{
            OFMT="%.2f" ;
            stockNum = 0 ;
            orgFunds = orgFunds+0 ;
            taxRatPrt = taxRatPrt+0 ;
            taxRatHandFee = taxRatHandFee+0 ;
        }

        !/#/{
            seed = $2 ;
            ampDur = $7/100 ;
            fcstStart = $8 ;
            fcstEnd = $9 ;
            cur = $10 ;
            code = $1 ;
            clsP = $12 ;
            cnt[code]++ ;

            if(seed in aFunds){
                if(cur < aEnd[seed]){
                    if(verbose) print "#",cur,seed,"IGNORE, in processing [" aCur[seed] "~" aEnd[seed] ") \t@",$0 ;
                    next ;
                }
            }else{
                aFunds[seed] = orgFunds ;
            }
            
            aCur[seed] = cur ;
            aStart[seed] = fcstStart ;
            aEnd[seed] = fcstEnd ;
            if(verbose) print "#",cur,seed,"DEAL, [" aCur[seed] "~" aEnd[seed] "), \t@",$0 ;

            stockNum = int(aFunds[seed]/((1+taxRatHandFee)*clsP)) ;
            aFunds[seed] -= (stockNum*clsP)*(1+taxRatHandFee) ;
            aFunds[seed] = int(aFunds[seed]*100)/100.0 ;              # the smallest unit is 1 Fen.
            if(verbose) print "#",cur,seed,"BOUGHT",stockNum,"*",clsP,"and funds left",aFunds[seed] ;

            aFunds[seed] += (stockNum*clsP)*(1+ampDur)*(1-taxRatHandFee-taxRatPrt) ;
            aFunds[seed] = int(aFunds[seed]*100)/100.0 ;              # the smallest unit is 1 Fen.
            if(verbose) print "#",cur,seed,"SOLD",stockNum,"with up rates",ampDur*100"% and funds left",aFunds[seed] ;
        }

        END{
            for(i in aFunds){
                print aFunds[i],i ;
            }
        }

        '


doExit 0 








#grep 600966 .t3.segData |
#cat .t3.segData |

awk '
    function fClean()
    {
        delete cnt ;
        delete funds ;
        delete dirs ;
        return 0 ;
    }

    function fPrt(      \
                        \
        i)
    {
        for(i in cnt){
            print funds[i], dirs[i], cnt[i], code, i ;
        }
        return 0 ;
    }

    BEGIN{
        OFMT="%.2f" ;
        fundsOrg = 1 ;  #original funds
        code = "" ;
        codeCur = "" ;
    }

    !/#/{
#        codeCur = substr($NF, 13, 6) ;
        if(codeCur != code){
            fPrt() ;
            fClean() ;
            code = codeCur ;
        }
        cnt[$1] ++ ;
        if(!($1 in funds)) funds[$1] = fundsOrg ;
        funds[$1] = funds[$1] * (100+$6) / 100 ;
        dirs[$1] = ($6 > 0) ? dirs[$1]+1 : dirs[$1]-1 ;
        fPrt() ;
    }

    END{
        fPrt() ;
    }

    '

doExit













































durDef=3
oprtB4Exit="cd $BKD"

function Help
{
    echo -ne "
    Usage: ${0} [--dur=N] [--start=YY-MM-DD] [--end=YY-MM-DD] [--build] [--genRaw] [--genSegment] [--genCounting] [--doForecast=N] [--verify [--buyFix=N] [--selFix=N]] [--help] list

        --dur, duration for segment data
        --start, limited the range when generate segment
        --end, limited the range when generate segment
        --help

    Note:
        If only one codeNum in the list file, generate the output filename according the codeNum.

    Default: --dur=$durDef --doForecast=$doForecastDef
\n"
}

for i in "${@}"
do
    [[ ${i} == "--help" ]] && Help && doExit 0 "$oprtB4Exit"
    [[ ${i%%=*} == "--dur" ]] && dur=${i##*=} && continue
    [[ ${i%%=*} == "--start" ]] &&  start=${i#*=} && continue ;
    [[ ${i%%=*} == "--end" ]] && end=${i#*=} && continue ;
    [[ ${i:0:1} == "-" ]] && echo "*! Unknown option:$i">&2 && doExit -1 "$oprtB4Exit"
    [[ -n $list ]] && echo "*! Multipule list specified">&2 && doExit -1 "$oprtB4Exit"
    list=$i
done

[[ -n $list && ! -f $list ]] && echo "*! Cannot find or open [$list]">&2 && doExit -1 "$oprtB4Exit"
codes=$( awk '($1 !~ "#"){print $1}' $list )
codeNum=$(echo "$codes" | wc -w)
[[ $codeNum -le 0 ]] && echo "*! No processed item, terminal the program">&2 && doExit 0 "$oprtB4Exit"
[[ $codeNum -eq 1 ]] && postFilename=$postFilename.$codes
dur=${dur:-$durDef}
segData=.t$dur.segData
cntgData=.t$dur.counting
forecastData=.t$dur.forecast$postFilename${start:+.from.$start}${end:+.to.$end}

echo     *dur="$dur" >&2
echo     *start="$start" >&2
echo     *end="$end" >&2

#if 1

#generate processing table

echo $codes | 
awk ${start:+ -v start=$start}  \
    ${end:+ -v end=$end}        \
    '
    '"$awkFunction_split2"'

    BEGIN{
        print "#output:"
        print "#\t(1)low (2)hig (3)opn (4)cls (5)forecastLowPrice(forecastLowCnt) (6)forecastHig(forecastHigCnt) (7)upCnt/unCnt (8)date (9)code (10)seed"
        print "#note:"
        print "#\tforecastHigCnt and forecastLowPrice are referrence values base on current close price, NOT for current day!!"
    }

    {
        if("'"$segData"'" == FILENAME){

            # (1)sorting  (2)upP  (3)upN  (4)dnP  (5)dnN  (6)durAMP  (7)dateS  (8)dateE  (9)DateC  (10)opn  (11)cls  (12)hig  (13)low  (14)srcFile"

            if($1 ~ "#") next ;
            if(start && $9<start) next ;
            if(end && $9>end) next ;

            if($NF in files){
                opn = $10+0 ;
                cls = $11+0 ;
                low = $13+0 ;
                hig = $12+0 ;
                date = $9 ;
                code = substr($NF,13,6) ;
                seed = $1 ;
                $0 = forecastCont[seed] ;         # upCnt upAmp dnCnt dnAmp upCnt/unCnt
                upCnt = $1 ;
                upAmp = $2 ;
                upPrice = (100+upAmp)*cls/100 ;
                dnCnt = $3 ;
                dnAmp = $4 ;
                dnPrice = (100+dnAmp)*cls/100 ;
                upRate = $5 ;
                print low, hig, opn, cls, dnPrice "(" dnCnt "," dnAmp "%)", upPrice "(" upCnt "," upAmp "%)", upRate, date, code, seed ;
            }

        }else if("'"$cntgData"'" == FILENAME){

            #    1..........................................................................................................................................................NF
            #00002  UP/UN=  inf  UP=0002( 5.29%)  UN=0000(  5.29%)  DP=0001( 1.43%)  DN=0001(-3.82%)  AP/AN= 1.00  AP=0001( 2.63%)  AN=0001(-3.76%)  [22k<5k<264k<1k<66k<132k]
            if($1 ~ "#") next ;

            seed = $NF ;

            gsub(/(UP)|(UN)|(DP)|(DN)|(AP)|(AN)|=|\(|\)|\/|%/," ") ;
            #now, we get :
            #(1)cnt  (2)UPC/UNC (3)UPC (4)UPA (5)UNC (6)UNA (7)DPC (8)DPA (9)DNC (10)DNA (11)AP/AN (12) APC (13)APA (14)ANC (15)ANA ... (NF)seed

            forecastCont[seed] = $3 " " $4 " " $9 " " $10 " " $2 ;      #upCnt upAmp dnCnt dnAmp upCnt/unCnt

        }else if("-" == FILENAME){

            codeNum = split2($0,a," ") ;
            for(i=0; i<codeNum; i++) files["sorting-raw/" a[i] ".raw"] = 1 ;

        }
    }

    ' - "$cntgData" "$segData"

#endif

doExit 0 "$oprtB4Exit"
