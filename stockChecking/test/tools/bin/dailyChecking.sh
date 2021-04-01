#! /bin/bash

. comm.lib

# the data of input must be .hot data
function programForgettingAvgTTandVolUpVolDnValUpValDn()
{
    awk '
        {
            #ignore invalid data according timestamp
            if($17<=lastTimeStamp){
                print "invalid timestamp:",$1,lastTimeStamp,$17 >"/dev/stderr";
            } else{
                print $0 ;
                lastTimeStamp=$17 ;
            } 
        }' |
    ./_getDelta.sh --segments=12,13 --keepRaw |       #get value and volume for each 15 second
    awk -v awkStockId=$stockId '
        BEGIN{
#            max_volUpDivVolDn = 0 ;
#            min_volUpDivVolDn = 100000000 ;
#            max_price = 0 ;
#            min_price = 100000000 ;
            actionInit = 0 ;
            actionUp = 1 ; 
            actionDn = 2 ;
        }
        {
            #caculate average total

            AvgTT += $15/$13 ;
        }
        # count equalized deal price into privious action
        {
            #caculate volUp,volDn,valUp,valDn

            dealPrice = $14/$12 ;
            if(lastDealPrice == 0){
                lastDealPrice = dealPrice ;
                lastAction = actionInit ;
            }
            _diff = dealPrice - lastDealPrice ;

            if(_diff >= 0.001){
                volUp += $12 ;
                valUp += $14 ;
                lastDealPrice = dealPrice ;
                lastAction = actionUp ;
            }else if(_diff <= -0.001){
                volDn += $12 ;
                valDn += $14 ;
                lastDealPrice = dealPrice ;
                lastAction = actionDn ;
            }else{
                if(lastAction == actionUp){
                    volUp += $12 ;
                    valUp += $14 ;
                }else if(lastAction == actionDn){
                    volDn += $12 ;
                    valDn += $14 ;
                }else{
                    volUp += $12 ;
                    valUp += $14 ;
                    volDn += $12 ;
                    valDn += $14 ;
                }
                # keep lastDealPrice unchanged
                # keep lastAction unchanged
            }
        }
#        # count equalized deal price into next action
#        {
#            #caculate volUp,volDn,valUp,valDn
#
#            dealPrice = $14/$12 ;
#            if(lastDealPrice == 0){
#                lastDealPrice = dealPrice ;
#                volUp = volDn = valUp = valDn = 1 ;
#            }
#            _diff = dealPrice - lastDealPrice ;
#
#            if(_diff >= 0.001){
#                volUp += $12+volUnsaved ;
#                valUp += $14+valUnsaved ;
#                volUnsaved = valUnsaved = 0 ;
#                lastDealPrice = dealPrice ;
#            }else if(_diff <= -0.001){
#                volDn += $12+volUnsaved ;
#                valDn += $14+valUnsaved ;
#                volUnsaved = valUnsaved = 0 ;
#                lastDealPrice = dealPrice ;
#            }else{
#                volUnsaved += $12 ;
#                volUnsaved += $14 ;
#                # keep lastDealPrice unchanged
#            }
#        }
#        # count equalized deal price into UP and DN actions
#        {
#            #caculate volUp,volDn,valUp,valDn
#
#            dealPrice = $14/$12 ;
#            if(lastDealPrice == 0){
#                lastDealPrice = dealPrice ;
#            }
#            _diff = dealPrice - lastDealPrice ;
#
#            if(_diff >= 0.001){
#                volUp += $12 ;
#                valUp += $14 ;
#                lastDealPrice = dealPrice ;
#            }else if(_diff <= -0.001){
#                volDn += $12 ;
#                valDn += $14 ;
#                lastDealPrice = dealPrice ;
#            }else{
#                volUp += $12 ;
#                valUp += $14 ;
#                volDn += $12 ;
#                valDn += $14 ;
#                # keep lastDealPrice unchanged
#            }
#        }
#        {
#            # (1)日期,(2)股票代码,(3)名称,(4)收盘价,(5)最高价,(6)最低价,(7)开盘价,(8)前收盘,(9)涨跌额,(10)涨跌幅,
#            # (11)换手率,(12)成交量,(13)成交金额,(14)总市值,(15)流通市值,(16)成交笔数
#            #get max_valUp, max_valDn, max_volUp-volDn, max_valUp-valDn
#            #get min_valUp, min_valDn, min_volUp-volDn, min_valUp-valDn
#            volUpDivVolDn = volUp / volDn ;
#            if(NR>=48 && max_volUpDivVolDn+0 < volUpDivVolDn){ 
#                max_volUpDivVolDn = volUpDivVolDn; 
#                max_volUpDivVolDn_rec = $1.$2." ""max_volUpDivVolDn="max_volUpDivVolDn" ""price="$4 ;
#            }
#            if(NR>=48 && min_volUpDivVolDn+0 > volUpDivVolDn){ 
#                min_volUpDivVolDn = volUpDivVolDn;
#                min_volUpDivVolDn_rec = $1.$2." ""min_volUpDivVolDn="min_volUpDivVolDn" ""price="$4 ;
#            }
#            if(NR>=48 && max_price+0 < $4){
#                max_price = $4;
#                max_price_rec = $1.$2." ""max_price="max_price" ""volUp/volDn="volUp/volDn
#            }
#            if(NR>=48 && min_price+0 > $4){
#                min_price = $4;
#                min_price_rec = $1.$2." ""min_price="min_price" ""volUp/volDn="volUp/volDn
#            }
#        }
        END{
            # (1)open (2)cls (3)hig (4)low  (5)avgPri (6)avgAvgPri (7)ystdCls 
            # (8)vol (9)val (10)volUp-volDn (11)valUp-valDn (12)volUp/volDn (13)valUp/valDn (14)stockId (15)date[MUST BE THE END]
            volUp += volUnsaved ;
            volDn += volUnsaved ;
            valUp += valUnsaved ;
            valDn += valUnsaved ;

            printf("%.2f %.2f %.2f %.2f %.2f %.2f %.2f %f %f %f %f %f %f %s %s\n",
                    $7,$4,$5,$6,$15/$13,AvgTT/NR,$8,$13,$15,volUp-volDn,valUp-valDn,volUp/volDn,valUp/valDn,awkStockId,$1) ;
#            print max_volUpDivVolDn_rec ;
#            print min_volUpDivVolDn_rec ;
#            print max_price_rec ;
#            print min_price_rec ;
#            print
        } 
    '
}

#
#M
#A
#I
#N
# 
#R
#O
#U
#T
#I
#N
#E
# 
#S
#T
#A
#R
#T
#S
# 
#H
#E
#R
#E
#

if [[ $1 == "--help" ]] ; then
    echo "
    Usage:  ${0} 1 stock [print]
            ${0} 2 stock [lastNdays [print]]
            ${0} 3 stock [days:-10]
            ${0} 4 stockList
            ${0} 5 stock
            ${0} 6 stockList
            ${0} 7 stock
            
    Notice: function_id
            1: display history information of a stock
            2: display price info for each day of a stock
            3: use last 10 days DAILY_DATA to get AMP status of a stock
            4: find out the stock which need be focused
            5: same as function_2 but has 2 more analized datas
            6: get hotdegree
            7: do a forecasting on a stock according hotdegree
                 
        "
            
    exit
fi

# use last 10 days daily_data, get its AMP status
if [[ $1 == 3 ]] ; then
# $1: function_id
# $2: stockId
# $3: with days

    #display stock name
    stockId=${2:-300340}
    daysFunc3=${3:-10}
    grep $stockId stock.list >&2

    #_start=$(getActualDate ${_start:-1970-01-01})
    _gap=$(cat $(ls  tmp/StockData/.HotData/*$stockId* | tail -1) | awk 'END{print int($4/3)/100}')
    cat $(ls  tmp/StockData/.HotData/*$stockId* | tail -$daysFunc3) StockData/*$stockId.html.org.hot  |
    #cat StockData/*$stockId.html.org.hot  |
    ./analizeAmpStatus.sh --seed='$4' --weight='$12' --gap=$_gap  --data --details  --top=40

elif [[ $1 == 1 ]] ; then
# $1: function_id
# $2: stockId
# $3: printFlag.

    #display stock name
    stockId=${2:-300340}
    grep $stockId stock.list >&2

    printDataOnly=${3:-0}

    # (1)stockID, (2)closePrice, (3)power, (4)amplitude, (5)trueAmplitude, (6)rsi6
    # (7)rsi12, (8)rsi24, (9)pwri6, (10)pwri12, (11)pwri24, (12)rsiFuture6, (13)pwriFuture12
    # (14)exchange, (15)volume, (16)value, (17)liveValue, (18)date (19)rsiCustom (20)pwriCustom
    # (21)xcgAvgICustom (22) gEgrData (23) highestAmp (24)open (25)hig (26)low (27)ystdClose

    # get the SMOOTHED history data from playStockList.sh
    # use last 10 years data
    cont=$(./playStockList.sh --print <<< $stockId 2>/dev/null |
            tail -2640 |
            awk '(NR>66 && $0!~/nan/){
                    gsub(/-/,"",$18);
                    print $4,($25-$26)*100/$27,$14,$2,  substr($18,3),  $25,$26,$16/$15,  $27,$24 ;
                }')

    if [[ $printDataOnly != 0 ]] ; then
        echo "$cont" | ./_getAverage.sh --unitLen=2640 --segments=1,2 --keepRaw
    else
        # draw lines: (1)amp, (2)amp_avg10Years, (3)ampHL, (4)ampHL_avg10Years, (5)exchange, (6)closePrice, (7)date
        count=$(echo "$cont" | wc -l | awk '{print $1}')
        lineNum=7
        echo "$cont" |
            ./_getAverage.sh --unitLen=2640 --segments=1,2 --keepRaw   |
            ./drawLines $stockId - $lineNum $count --focus=5 --scale=1 --showlines=2,4,5,6
    fi

elif [[ $1 == 2 ]] ; then
# $1: function_id
# $2: stockId
# $3: extract last N days from daily database
# $4: printFlag

    #display stock name
    stockId=${2:-300340}
    grep $stockId stock.list >&2

    extractLastNdaysDailyData=${3:-1}
    printDataOnly=${4:-0}

    # (1)日期,(2)股票代码,(3)名称,(4)收盘价,(5)最高价,(6)最低价,(7)开盘价,(8)前收盘,(9)涨跌额,(10)涨跌幅,
    # (11)换手率,(12)成交量,(13)成交金额,(14)总市值,(15)流通市值,(16)成交笔数
    if [[ ${#stockId} -eq 6 ]] ; then
        [[ ${stockId:0:1} == '6' ]] && stockId="0$stockId" || stockId="1$stockId"
    fi

    if [[ -f .dailyChecking.$stockId.$(date +%Y-%m-%d) ]] ; then
        content=$(cat .dailyChecking.$stockId.$(date +%Y-%m-%d) )
        dateLastHis=$(echo "$content" | tail -1 | awk '{print $NF;}' )
    else
        rm .dailyChecking.$stockId.$(date +%Y)-* 2>/dev/null

        #get last N_day filenames of historyData and make include_argument for extracting
        includeFiles=$(tar -tf .hotData.tar --include="*$stockId*hot*" | tail -$extractLastNdaysDailyData)
        for i in $includeFiles; do includeArgs="$includeArgs --include=$i"; done
        tar -xf .HotData.tar $includeArgs -C tmp
        
        files=$(ls tmp/StockData/.HotData/*$stockId* | sort)
        dateLastHis=$(echo "$files" | tail -1 | sed 's/.*\.//')

        #extract data from history data
        content=$(
            for i in $files
            do
                cat $i | programForgettingAvgTTandVolUpVolDnValUpValDn
            done
        )
        [[ -n $content ]] && echo "$content" > .dailyChecking.$stockId.$(date +%Y-%m-%d)
    fi

    if [[ -f StockData/$stockId.html.org.hot ]]; then
        #extract data from hotData
        lastUpdate=$(
            cat StockData/$stockId.html.org.hot | programForgettingAvgTTandVolUpVolDnValUpValDn
        )
        dateLastUpdate=${lastUpdate##* }

        #merge hotData with hisData
        if [[ -z $content ]] ; then
            content=$lastUpdate
        else
            content=$(
                if [[ -n $lastUpdate && $dateLastUpdate == $dateLastHis ]] ; then
                    # overwrite last hisData with hotData
                    echo "$content" | sed '$d'
                    echo "$lastUpdate"
                else
                    # append hotData to hisData
                    echo "$content"
                    echo "$lastUpdate"
                fi
            )
        fi
    fi

    #print data only
    [[ $printDataOnly != 0 ]] && echo "$content" && exit 0

    #do drawing
    # (1)open (2)cls (3)hig (4)low  (5)avgPri (6)avgAvgPri (7)ystdCls
    # (8)vol (9)val (10)volUp-volDn (11)valUp-valDn (12)stockId (13)date[MUST BE THE END]
    if [[ -n $content ]] ; then
        linesInfo=$(echo "$content" | awk 'END{print NF-8,NR;}')
        echo "$content" | ./drawLines $stockId - $linesInfo --group=${linesInfo%% *} --focus=1 --scale=64
    else
        showAlrt "no content!\n" >&2
    fi

elif [[ $1 == 4 ]] ; then
# $1: function_id
# $2: stock_list_file

    for stockId in $(awk '($1!~"#"){print $1}' $2)
    do
        echo "*checking  "$stockId >&2

        # (1)stockID, (2)closePrice, (3)power, (4)amplitude, (5)trueAmplitude, (6)rsi6
        # (7)rsi12, (8)rsi24, (9)pwri6, (10)pwri12, (11)pwri24, (12)rsiFuture6, (13)pwriFuture12
        # (14)exchange, (15)volume, (16)value, (17)liveValue, (18)date (19)rsiCustom (20)pwriCustom
        # (21)xcgAvgICustom (22) gEgrData (23) highestAmp (24)open (25)hig (26)low (27)ystdClose

        # get the SMOOTHED history data from playStockList.sh
        # use last 10 years data
        cont=$(./playStockList.sh --print <<< $stockId 2>/dev/null |
                tail -2640 |
                awk '(NR>66 && $0!~/nan/){
                        gsub(/-/,"",$18);
                        print $4,($25-$26)*100/$27,$14,$2,  substr($18,3),  $25,$26,$16/$15,  $27,$24 ;
                    }')

        echo "$cont" |
            ./_getAverage.sh --unitLen=2640 --segments=1,2 --keepRaw |
            tail -400 |
            awk -v stockId=$stockId '
                {
                    if(NR==1) min=$2 ;
                    if($2<min) min=$2 ;
                    secondTail=tail ;
                    tail=$2 ;
                }
                END{
                    if($2==min && tail<=secondTail) system("grep " stockId " stock.list") ;
#                    if(tail<secondTail) system("grep " stockId " stock.list") ;
                }
            '
    done

elif [[ $1 == 5 ]] ; then
# $1: function_id
# $2: stockId
    # after executing ./dailyChecking.sh 2 $2 1, we get the data with format:
    #   (1)open (2)cls (3)hig (4)low  (5)avgPri (6)avgAvgPri (7)ystdCls 
    #   (8)vol (9)val (10)volUp-volDn (11)valUp-valDn (12)stockId (13)date[MUST BE THE END]
    content=$(./dailyChecking.sh 2 $2 1 1 | ./_getDelta.sh --segments=10,11 --doSum --keepRaw | awk '{print $1,$2,$3,$4,$5,$8,$11,$10;}')

    #do drawing
    # (1)open (2)cls (3)hig (4)low  (5)avgPri (6)vol (7)volUp-VolDn (8)sumOfVolup-VolDn
    if [[ -n $content ]] ; then
        linesInfo=$(echo "$content" | awk 'END{print NF,NR;}')
        echo "$content" | ./drawLines $2 - $linesInfo --scale=12 --group=5,3 --focus=6
    else
        showAlrt "no content!\n" >&2
    fi

elif [[ $1 == 6 ]] ; then
# $1: function_id
# $2: stocklist

    stockList=${2:-.hot}
    orgGoodRef=.dailyChecking.func6.orgGoodRef.$(date +%Y-%m-%d)
    orgBadRef=.dailyChecking.func6.orgBadRef.$(date +%Y-%m-%d)
    goodRef=.dailyChecking.func6.goodRef.$(date +%Y-%m-%d)
    badRef=.dailyChecking.func6.badRef.$(date +%Y-%m-%d)

    if [[ ! -f $goodRef ]] ; then
        rm .dailyChecking.func6.orgGoodRef* 2>/dev/null
        rm .dailyChecking.func6.goodRef* 2>/dev/null
        ./relationShipChecker.sh ampGE9.6_countGE5.info --rate=72 | tee $orgGoodRef
        cp $orgGoodRef $goodRef
        sed -i '' '/^ /d;s/\*//;s/\[/ [/' $goodRef
    fi

    if [[ ! -f $badRef ]] ; then
        rm .dailyChecking.func6.orgBadRef* 2>/dev/null
        rm .dailyChecking.func6.badRef* 2>/dev/null
        ./relationShipChecker.sh ampLE-9.6_countGE5.info --rate=52 | tee $orgBadRef
        cp $orgBadRef $badRef
        sed -i '' '/^ /d;s/\*//;s/\[/ [/' $badRef
    fi

    ./hotdegree.sh --goodRef=$goodRef --badRef=$badRef ${2:-.hot}

elif [[ $1 == 7 ]] ; then
# $1: function_id
# $2: stockId

    stockId=$2
    [[ ! -n $stockId ]] && showAlrt "no stockId specified\n" >&2 && exit

    # get forecastAmp
    content=$( ./analizeAmpStatus.sh --top=100 --gap=0.2 --details --days=-132  2>/dev/null <<< $stockId )

    echo "$content" 
    echo "--------------------------------"

    forecastAmp=$(
        echo "$content" |
        sed -E '$d;/#/d;s/\[|]|,/ /g' |
        awk '
            {
                data[NR,"amp"] = $3 ;
                data[NR,"cnt"] = $4 ;
            }

            END{
                t = 0 ;
                idx = 0 ;
                minDelta = 10000 ;
                maxDelta = 0 ;

                for(i=1; i<=NR; i++){
                    t += data[i,"amp"] ;
                    if(i<2) continue ;
                    delta = data[i-1,"cnt"] - data[i,"cnt"] ;
                    if(delta < minDelta) minDelta = delta ;
                    if(delta > maxDelta){
                        idx = i ;
                        maxDelta = delta ;
                    }
                    #print "maxDelta="maxDelta, "minDelta="minDelta, "delta="delta > "/dev/stderr" ;
                }

                if(minDelta==maxDelta || idx==0 || NR<=3){
                    rslt = int(t*100/NR)/100 "*" ;
                }else{
                    rslt = data[idx,"amp"] ;
                }

                print rslt ;
            }
            '
    )

    # format for playStockList_output
    # (1)stockID, (2)closePrice, (3)power, (4)amplitude, (5)trueAmplitude, (6)rsi6
    # (7)rsi12, (8)rsi24, (9)pwri6, (10)pwri12, (11)pwri24, (12)rsiFuture6, (13)pwriFuture12
    # (14)exchange, (15)volume, (16)value, (17)liveValue, (18)date (19)rsiCustom (20)pwriCustom
    # (21)xcgAvgICustom (22) gEgrData (23) highestAmp (24)open (25)hig (26)low (27)ystdClose
    ./playStockList.sh --printLastOne <<< $stockId 2>/dev/null | 
    awk -v awkForecastAmp=$forecastAmp '
        {
            high  = $25 ;
            low   = $26 ;
            ystdCP = $27 ;
            top = low + ystdCP*awkForecastAmp/100 ;
            bottom = high - ystdCP*awkForecastAmp/100 ;
            print "\n* high   = "high,"\n* low    = "low,"\n* ystdCP = "ystdCP,"\n* forecastAmp = "awkForecastAmp,"\n\n  top    = "top,"\n  bottom = "bottom"\n" ;
        }
        '


else
    :>/dev/null
fi

exit 0

