
#! /bin/bash

. comm.lib

doStart

doForecastDef=1
durDef=3
genRawDef=0
genSegmentDef=0
genCountingDef=0
verifyDef=0
buyFixDef=0
selFixDef=-0.03
oprtB4Exit="cd $BKD"

function Help
{
    echo -ne "
    Usage: ${0} [--dur=N] [--start=YY-MM-DD] [--end=YY-MM-DD] [--build] [--genRaw] [--genSegment] [--genCounting] [--doForecast=N] [--verify [--buyFix=N] [--selFix=N]] [--help] list

        --dur, duration for segment data
        --start, limited the range when generate segment
        --end, limited the range when generate segment
        --genRaw, generate raw data
        --genSegment, generate segment data from raw data
        --genCounting, gencounting data from segment data
        --build, is the abbrevation of --genRaw --genSegment --genCounting --doForecast=0
        --doForecast, make forecasting
        --verify, do verifications
            -- buyFix=N, set buy price plus N
            -- selFix=N, set sell price pus N
        --help

    Note:
        If only one codeNum in the list file, make the output filename according the codeNum.

    Default: --dur=$durDef --doForecast=$doForecastDef
\n"
}

for i in "${@}"
do
    [[ ${i} == "--help" ]] && Help && doExit 0 "$oprtB4Exit"
    [[ ${i%%=*} == "--dur" ]] && dur=${i##*=} && continue
    [[ ${i%%=*} == "--doForecast" ]] && doForecast=${i##*=} && continue
    [[ ${i%%=*} == "--verify" ]] && verify=1 && continue
    [[ ${i%%=*} == "--buyFix" ]] && buyFix=${i##*=} && continue
    [[ ${i%%=*} == "--selFix" ]] && selFix=${i##*=} && continue
    [[ ${i} == "--genRaw" ]] && genRaw=1 && continue
    [[ ${i} == "--genSegment" ]] && genSegment=1 && continue
    [[ ${i} == "--genCounting" ]] && genCounting=1 && continue
    [[ ${i%%=*} == "--start" ]] &&  start=${i#*=} && continue ;
    [[ ${i%%=*} == "--end" ]] && end=${i#*=} && continue ;
    [[ ${i} == "--build" ]] && genRaw=1 && genSegment=1 && genCounting=1 && doForecast=0 && continue
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
doForecast=${doForecast:-$doForecastDef}
genRaw=${genRaw:-$genRawDef}
genSegment=${genSegment:-$genSegmentDef}
genCounting=${genCounting:-$genCountingDef}
verify=${verify:-$verifyDef}
buyFix=${buyFix:-$buyFixDef}
selFix=${selFix:-$selFixDef}
segData=.t$dur.segData
cntgData=.t$dur.counting
forecastData=.t$dur.forecast$postFilename${start:+.from.$start}${end:+.to.$end}

echo     *dur="$dur" >&2
echo     *start="$start" >&2
echo     *end="$end" >&2
echo     *genRaw="$genRaw"  >&2
echo     *genSegment="$genSegment"   >&2
echo     *genCounting="$genCounting" >&2
echo     *doForecast="$doForecast"   >&2
echo     *verify="$verify"  >&2
if [[ $verify -eq 1 ]] ; then
    echo     *buyFix="$buyFix"  >&2
    echo     *selFix="$selFix"  >&2
fi

#generate rawData and segment data
#if 1
if [[ $genSegment -eq 1 ]] ; then
    rm -rf $segData 
    [[ $? -ne 0 ]] && echo *! Cannot remove $segData >&2 && doExit -1 "$oprtB4Exit"
fi

for i in $codes
do
    [[ $genRaw -eq 1 ]] && ./1_genKLineSortingRawData.sh $i > sorting-raw/$i.raw
    [[ $genSegment -eq 1 ]] && ./2_genSegmentUpDnRate.sh --dur=$dur --offset=1 --disSrc $i >> "$segData" && echo *Append $i\'s data to "$segData" >&2
    [[ $genRaw -eq 1 || $genSegment -eq 1 ]] && echo "----"
done
#endif

#generate counting data
#if 1
if [[ $genCounting -eq 1 ]]; then
    echo "*NOTE, only the item which in the code list will be procceed in counting" >&2
    echo "#start=$start end=$end" > "$cntgData"
    echo $codes     | 
        awk ${start:+ -v start=$start}  \
            ${end:+ -v end=$end}        \
            '
            '"$awkFunction_split2"'

            {
                if("'"$segData"'" == FILENAME){
                    #                          1       2       3       4       5       6          7          8          9    10    11    12                     13
                    #[264k<132k<66k<22k<1k<5k]-3   6.40%   4.16%  -0.88%  -5.54%  -3.02% 2021-01-15 2021-01-19 2021-01-14 81.00 82.00 80.00 sorting-raw/603799.raw

                    if(start && $9<start) next ;
                    if(end && $9>end) next ;
                    if($1 ~ "#") next ;
                    if($8 ~ "NONE") next ;

                    if($NF in files) print ;

                }else if("-" == FILENAME){
                    codeNum = split2($0,a," ") ;
                    for(i=0; i<codeNum; i++) files["sorting-raw/" a[i] ".raw"] = 1 ;
                }
            }
            ' - $segData    |
        ./3_countingSegMentData.sh >> "$cntgData"

    echo *Save counting data to "$cntgData" >&2
fi
#endif


#generate seed-code-date info
#if 1
if [[ $doForecast -eq 1 ]] ; then
    echo $codes | 
    awk ${start:+ -v start=$start}  \
        ${end:+ -v end=$end}        \
        '
        '"$awkFunction_split2"'

        {
            if("'"$segData"'" == FILENAME){
                #                          1       2       3       4       5       6          7          8          9    10    11    12                     13
                #[264k<132k<66k<22k<1k<5k]-3   6.40%   4.16%  -0.88%  -5.54%  -3.02% 2021-01-15 2021-01-19 2021-01-14 81.00 82.00 80.00 sorting-raw/603799.raw

                if($1 ~ "#") next ;
                if(start && $9<start) next ;
                if(end && $9>end) next ;
                if($NF in files){
                    print forecastCont[$1],$9,$10,substr($NF,13,6),$1 ;
                }
            }else if("'"$cntgData"'" == FILENAME){
                #    1..........................................................................................................................................................NF
                #00002  UP/UN=  inf  UP=0002( 5.29%)  UN=0000(  5.29%)  DP=0001( 1.43%)  DN=0001(-3.82%)  AP/AN= 1.00  AP=0001( 2.63%)  AN=0001(-3.76%)  [22k<5k<264k<1k<66k<132k]

                if($1 !~ "#"){
                    seed = $NF ;
                    $NF = "" ;
                    forecastCont[seed] = $0 ;
                }
            }else if("-" == FILENAME){
                codeNum = split2($0,a," ") ;
                for(i=0; i<codeNum; i++) files["sorting-raw/" a[i] ".raw"] = 1 ;
            }
        }

        ' -  "$cntgData" "$segData" > "$forecastData"

    echo *Save forecast data to "$forecastData" >&2
fi
#endif

#if 1
if [[ $verify -eq 1 ]] ; then

    #generate processing table

    echo $codes | 
    awk ${start:+ -v start=$start}  \
        ${end:+ -v end=$end}        \
        '
        '"$awkFunction_split2"'

        BEGIN{
            print "#output:"
            print "#\t(1)forecastLowPrice(forecastLowCnt) (2)forecastHig(forecastHigCnt) (3)low (4)hig (5)date (6)closePrice (7)code (8)seed"
            print "#note:"
            print "#\tforecastHigCnt and forecastLowPrice are referrence values base on current close price, NOT for current day!!"
        }

        {
            if("'"$segData"'" == FILENAME){

                #                          1       2       3       4       5       6          7          8          9    10    11    12                     13
                #[264k<132k<66k<22k<1k<5k]-3   6.40%   4.16%  -0.88%  -5.54%  -3.02% 2021-01-15 2021-01-19 2021-01-14 81.00 82.00 80.00 sorting-raw/603799.raw

                if($1 ~ "#") next ;
                if(start && $9<start) next ;
                if(end && $9>end) next ;

                if($NF in files){
                    clsP = $10+0 ;
                    low = $12 ;
                    hig = $11 ;
                    date = $9 ;
                    code = substr($NF,13,6) ;
                    seed = $1 ;
                    cnt=$0 ;
                    $0 = forecastCont[seed] ;         # upCnt upAmp dnCnt dnAmp
                    upCnt = $1 ;
                    upAmp = $2 ;
                    upPrice = (100+upAmp)*clsP/100 ;
                    dnCnt = $3 ;
                    dnAmp = $4 ;
                    dnPrice = (100+dnAmp)*clsP/100 ;
                    print dnPrice "(" dnCnt "," dnAmp "%)", upPrice "(" upCnt "," upAmp "%)", low, hig, date, clsP, code, seed ;
                }

            }else if("'"$cntgData"'" == FILENAME){

                #    1..........................................................................................................................................................NF
                #00002  UP/UN=  inf  UP=0002( 5.29%)  UN=0000(  5.29%)  DP=0001( 1.43%)  DN=0001(-3.82%)  AP/AN= 1.00  AP=0001( 2.63%)  AN=0001(-3.76%)  [22k<5k<264k<1k<66k<132k]

                if($1 ~ "#") next ;

                seed = $NF ;

                #get UP info
                {
                    s = index($0,"UP=") ;
                    if(s>0){
                        e = index(substr($0, s+3), ")") ;
                        upStr = substr($0, s+3, e) ;        #from s+3, length equals to e
                        gsub(/\(|\)|%/, " ", upStr) ;
                    }else{
                        upStr = "" ;
                    }
                }

                #get DN info
                {
                    s = index($0,"DN=") ;
                    if(s>0){
                        e = index(substr($0, s+3), ")") ;
                        dnStr = substr($0, s+3, e) ;        #from s+3, length equals to e
                        gsub(/\(|\)|%/, " ", dnStr) ;
                    }else{
                        dnStr = "" ;
                    }
                }

                forecastCont[seed] = upStr " " dnStr ;      #upCnt upAmp dnCnt dnAmp

            }else if("-" == FILENAME){

                codeNum = split2($0,a," ") ;
                for(i=0; i<codeNum; i++) files["sorting-raw/" a[i] ".raw"] = 1 ;

            }
        }

        ' - "$cntgData" "$segData"      |

    awk -v dur=$dur                     \
        -v buyFix=$buyFix               \
        -v selFix=$selFix               \
        '

        '"$awkFunction_getMaxMin"'
        '"$awkFunction_around"'

        BEGIN{
            print "#input:"
            print "#\t(1)forecastLowPrice(forecastLowCnt) (2)forecastHig(forecastHigCnt) (3)low (4)hig (5)date (6)closePrice (7)code (8)seed"
            print "#note:"
            print "#\tforecastHigCnt and forecastLowPrice are referrence values base on current close price, NOT for current day!!"

            cnt = 0 ;
            money = 20000 ;
            stockNum = 0 ;

            infP = 9999.99 ;
            infN = -9999.99
        }

        ($1 !~ "#"){
            # generate processing table: forecastLowPrice forecastHigPrice low hig 

            fcstL = $1+0 ;
            fcstH = $2+0 ;
            low   = $3+0 ;
            hig   = $4+0 ;
            originCont[cnt] = $0 ;
            forecastLowArry[cnt] = fcstL ;
            forecastHigArry[cnt] = fcstH ;
            lowArry[cnt] = low ;
            higArry[cnt] = hig ;

            date[cnt] = $5 ;

            cnt ++ ;
        }

        END{
            # do buy and sell demonstration
            for(i=1; i<cnt-dur; i++){
                from = i - dur ;
                to   = i - 1 ;
                if(from < 0) from = 0 ;
                if(to < 0) to = 0 ;

                # before open
                {
                    if(stockNum){
                        getMaxMin(forecastHigArry, from, to, a) ;
                        selV = around(forecastHigArry[a["minIdx"]]*100)/100+selFix ;
                        print date[i],"set *SELL value to:", selV "(" selV-selFix "plus" selFix ")", "\t@", originCont[i] ;
                    }else{
                        getMaxMin(forecastLowArry, from, to, a) ;
                        buyV = (forecastLowArry[a["minIdx"]] == infP) ? infN : around(forecastLowArry[a["minIdx"]]*100)/100+buyFix ;
                        print date[i],"set *BUY  value to:", buyV "(" buyV-buyFix "plus" buyFix ")", "\t@", originCont[i] ;
                    }
                }

                # after close
                {
                    if(stockNum){
                        if(selV < higArry[i]){
                            if(selV < lowArry[i]) selV = lowArry[i] ;
                            money += stockNum * selV ;
                            print date[i],"sold  ",stockNum,"*",selV "(" selV-selFix "plus" selFix "). And now, we have", money ;
                            stockNum = 0 ;
                        }
                    }else{
                        if(buyV > lowArry[i]){
                            if(buyV > higArry[i]) buyV = higArry[i] ;
                            stockNum = around(money/buyV) ;
                            money -= buyV * stockNum ;
                            print date[i],"bought",stockNum,"*",buyV+0 "(" buyV-buyFix "plus" buyFix "). And now, we have", money ;
                        }
                    }

                    for(j=from; j<=to; j++){
                        if(higArry[i] >= forecastHigArry[j]){
                            forecastHigArry[j] = infP ;
                            forecastLowArry[j] = infP ;
                        }
                        if(lowArry[i] <= forecastLowArry[j]){
                            forecastLowArry[j] = infP ;
                        }
                    }

                    if(i-dur+1<i && i-dur+1>0){
                        forecastLowArry[i-dur+1] = infP ;
                    }
                }
            }
        }
        
        '
fi
#endif

doExit 0 "$oprtB4Exit"
