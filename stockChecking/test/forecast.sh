
#! /bin/bash

. ~/tools/lib/comm.lib

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
                    # (1)sorting  (2)upP  (3)upN  (4)dnP  (5)dnN  (6)durAMP  (7)dateS  (8)dateE  (9)DateC  (10)opn  (11)cls  (12)hig  (13)low  (14)srcFile"

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
                # (1)sorting  (2)upP  (3)upN  (4)dnP  (5)dnN  (6)durAMP  (7)dateS  (8)dateE  (9)DateC  (10)opn  (11)cls  (12)hig  (13)low  (14)srcFile"

                if($1 ~ "#") next ;
                if(start && $9<start) next ;
                if(end && $9>end) next ;
                if($NF in files){
                    print forecastCont[$1],$9,$11,substr($NF,13,6),$1 ;
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

        ' - "$cntgData" "$segData"      |

    awk -v dur=$dur                     \
        -v buyFix=$buyFix               \
        -v selFix=$selFix               \
        '

        '"$awkFunction_getMaxMin"'
        '"$awkFunction_around"'
        '"$awkFunction_tabOprSets"'

        function getForecastRange(          \
                    varIdxOfActDate,
                    dur,
                    rangeA,                 # has 2 elements: from and to
                                            \
                    from,to)
        {
            from = varIdxOfActDate - dur ;
            to = varIdxOfActDate - 1 ;
            if(from < 0) from = 0 ;
            if(to < 0) to = 0 ;
            rangeA["from"] = from ;
            rangeA["to"] = to ;

            return 0 ;
        }

        function strategy_2(                \
                    tab,
                    cnt,
                    dur,
                    selFix,
                    buyFix,
                    stockNum,
                    money,
                                            \
                    idx,rate,_selV,_buyV,a,from,to,i,j,INVLID,_buyVOrg,_selVOrg,_buyFixInfo,_selFixInfo )
        {
            # do buy and sell demonstration

            INVLID = "InVaLiD_NuM" ;

            for(i=1; i<cnt-dur; i++){
                getForecastRange(i, dur, fcstRng) ;
                from = fcstRng["from"] ;
                to = fcstRng["to"] ;

                # before open, set buy/sel
                {
                    if(stockNum){

                        if(-1 == getMinMaxElmInTab(tab, segForecastHig, from, segForecastHig, to, a, INVLID)){
                            _selVOrg = 9999 ;
                            _selV = 9999 ;
                        }else{
                           _selVOrg = a["min"] ;
                           _selV = around(_selVOrg*(1+selFix),2) ;
                        }
                        print tab[segDate,i],"set *SELL value " _selV "(" _selVOrg "fixBy" selFix ")", "\t@", tab[segContent,i] ;
                    }else{
                        idx = -1 ;
                        rate = 0 ;
                        for(j=from; j<=to; j++){
                            if(tab[segForecastHigCnt,j] <300) continue ;
                            if(tab[segUpRate,j] < 12.33) continue ;
                            if(rate < tab[segUpRate,j]){
                                rate = tab[segUpRate,j] ;
                                idx = j ;
                            }
                        }
                        if(-1 == idx){
                            _buyVOrg = 0 ;
                            _buyV = 0 ;
                        }else{
                            _buyVOrg = tab[segForecastLow,idx] ;
                            _buyV = around(_buyVOrg*(1+buyFix),2) ;
                        }
                        print tab[segDate,i],"set *BUY  value " _buyV "(" _buyVOrg "fixBy" buyFix ")", "\t@", tab[segContent,i] ;
                    }
                }

                # after close, check buy/sel and adjust forecast list
                {
                    if(stockNum){
                        if(_selV <= tab[segOpn,i]){
                            _selV = tab[segOpn,i] ;
                            money += stockNum * _selV ;
                            print tab[segDate,i],"sold  ",stockNum,"*",_selV "(" _selVOrg "fixByOpen) . Now, we have", money ;
                            stockNum = 0 ;
                        }else if(_buyV*0.8 >= tab[segOpn,i]){
                            _selV = tab[segOpn,i] ;
                            money += stockNum * _selV ;
                            print tab[segDate,i],"sold  ",stockNum,"*",_selV "(" _selVOrg "fixByOpen) . Now, we have", money ;
                            stockNum = 0 ;
                        }else if(_buyV*0.8 >= tab[segLow,i]){
                            _selV = _buyV*0.8 ;
                            money += stockNum * _selV ;
                            print tab[segDate,i],"sold  ",stockNum,"*",_selV "(" _selVOrg "fixBy0.8_buyV) . Now, we have", money ;
                            stockNum = 0 ;
                        }else if(_selV < tab[segHig,i]){
                            if(_selV < tab[segLow,i]) _selV = tab[segLow,i] ;
                            money += stockNum * _selV ;
                            print tab[segDate,i],"sold  ",stockNum,"*",_selV "(" _selVOrg "fixBy" selFix ") . Now, we have", money ;
                            stockNum = 0 ;
                        }
                    }else{
                        if(_buyV > tab[segLow,i]){
                            if(_buyV > tab[segHig,i]) _buyV = tab[segHig,i] ;
                            stockNum = int(money/_buyV) ;
                            money -= _buyV * stockNum ;
                            print tab[segDate,i],"bought",stockNum,"*",_buyV "(" _buyVOrg "fixBy" buyFix ") . Now, we have", money ;
                        }
                    }

                    for(j=from; j<=to; j++){
                        if(tab[segHig,i] >= tab[segForecastHig,j]){
                            tab[segForecastHig,j] = INVLID ;
                            tab[segForecastLow,j] = INVLID ;
                        }
                        if(tab[segLow,i] <= tab[segForecastLow,j]){
                            tab[segForecastLow,j] = INVLID ;
                        }
                    }

                    if(i-dur+1<i && i-dur+1>0){
                        tab[segForecastLow,i-dur+1] = INVLID ;
                    }
                }
            }

            return 0 ;
        }

        BEGIN{

            '"$awkCommDigDef"'

            print "#input:"
            print "#\t(1)low (2)hig (3)opn (4)cls (5)forecastLowPrice(forecastLowCnt) (6)forecastHig(forecastHigCnt) (7)upCnt/unCnt (8)date (9)code (10)seed"
            print "#note:"
            print "#\tforecastHigCnt and forecastLowPrice are referrence values base on current close price, NOT for current day!!"

            #note, we use segement name as the rows, that is easy way for multiple dimension arry operate.
            segCnt = 0 ;
            segLow = segCnt++ ;
            segHig = segCnt++ ;
            segOpn = segCnt++ ;
            segCls = segCnt++ ;
            segForecastLow = segCnt++ ;
            segForecastLowCnt = segCnt++ ;
            segForecastHig = segCnt++ ;
            segForecastHigCnt = segCnt++ ;
            segUpRate = segCnt++ ;
            segDate = segCnt++ ;
            segContent = segCnt++ ;
            tab["segNames"] = "Low,Hig,Opn,Cls,FcstLow,FcstLowCnt,FcstHig,FcstHigCnt,upRate,Date,Content" ;

            tabExtend = 0 ;
            tab["rows"] = segCnt ;
            tab["cols"] = tabExtend ;

            money = 20000 ;
            stockNum = 0 ;

        }

        ($1 !~ "#"){
            # generate processing table

            tab[segContent ,tabExtend] = $0 ;
            tab[segLow ,tabExtend] = $1+0 ;
            tab[segHig ,tabExtend] = $2+0 ;
            tab[segOpn ,tabExtend] = $3+0 ;
            tab[segCls ,tabExtend] = $4+0 ;
            tab[segForecastLow ,tabExtend] = $5+0 ;
            sub(/.*\(/,"",$5) ;
            tab[segForecastLowCnt ,tabExtend] = $5+0 ;
            tab[segForecastHig ,tabExtend] = $6+0 ;
            sub(/.*\(/,"",$6) ;
            tab[segForecastHigCnt ,tabExtend] = $6+0 ;
            tab[segUpRate ,tabExtend] = $7+0 ;
            tab[segDate,tabExtend] = $8 ;

            tabExtend ++ ;
            tab["cols"] = tabExtend ;
        }

        END{
            strategy_2(tab, tabExtend, dur, selFix, buyFix, stockNum, money) ;
        }

        '
fi
#endif

doExit 0 "$oprtB4Exit"
