#! /bin/bash

. ~/tools/lib/comm.lib

#set -x 
declare -ri _cmdCodeDownload=$((1<<0))
declare -ri _cmdCodeUpdate=$((1<<1))
declare -ri _cmdCodeHotData=$((1<<2))
declare -i  _cmdCode=0

_keepRefresh=false
_opt=''
_boss=$PPID

doExit()
{
    # $1 is exitCode

    if [[ $1 == 0 ]] ; then
        : main task exit
        rm -rf StockData/$_stockCode.html.org 2>/dev/null
    elif [[ $1 == 1 ]] ; then
        : sub task exit, main 
        rm -rf StockData/$_stockCode.html.org 2>/dev/null
    elif [[ $1 == 2 ]] ; then
        : exit when interruptted
        rm -rf StockData/$_stockCode.html.org 2>/dev/null
    else
        : do nothing
    fi

    exit $1
}

sendSigToDispProc()
{
    #$1: stock code (7 digitals)

    local _i
    local _pids

    #find matched progress
    _pids=`ps | awk '(/stockChecking.*'$1'/ && !/awk/){print $1}'`
    for _i in $_pids
    do
        kill -SIGUSR1 $_i
    done
    return 0
}

#
#
#start the main routing
#----------------------

#parameters checking
for i in "$@"
do
    [[ $i == "--help" ]] &&
    echo "
    Usage:
        $0 [--download] [--update] [--hotData] [--auto] [--boss=pid] [--dateStart=YYYYMMDD] [--dateEnd=YYYYMMDD] stockCode

        --download: download history data (remove the old data first)
        --update: same as --download. Do not remove old data
        --hotData: refresh current data
        --dateStart: get the data from the dateStart
        --dateEnd: get the data till teh dateEnd
        --auto: --update + --hotData.

    Default:
        --auto
    " >&2 && exit 0

    [[ $i == "--download" ]] && ((_cmdCode|=_cmdCodeDownload)) && continue
    [[ $i == "--update" ]] && ((_cmdCode|=_cmdCodeUpdate)) && continue
    [[ $i == "--hotData" ]] && ((_cmdCode|=_cmdCodeHotData)) && _keepRefresh=true && continue
    [[ $i == "--auto" ]] && ((_cmdCode|=(_cmdCodeUpdate | _cmdCodeHotData) )) && _keepRefresh=true && continue
    [[ ${i%%=*} == "--dateStart" ]] && _dateStart=${i##*=} && continue
    [[ ${i%%=*} == "--dateEnd" ]] && _dateEnd=${i##*=} && continue
    [[ ${i:0:1} == '-' ]] && showErr "unknown option $i\n" && exit 0
    #[[ ${i%%=*} == "--boss" ]] && _boss=${i##*=} && continue
    _stockCode=$i
done

#before starting main routine, set a trap to process SIGINT SIGTERM and etc
trap " doExit 2" SIGINT SIGTERM SIGQUIT

#extract current stock origin data
grep "'${_stockCode:1}" StockData/${_stockCode:0:6}-.package.html.org 2>/dev/null > StockData/$_stockCode.html.org

((_cmdCode == 0 )) && _cmdCode=$((_cmdCodeUpdate|_cmdCodeHotData)) && _keepRefresh=true
((_cmdCode & _cmdCodeDownload)) && rm -rf StockData/$_stockCode.html.org{,.hot} 2>/dev/null
[[ -z $_dateStart && -f StockData/$_stockCode.html.org ]] && _dateStart=$(sed -n '${s/ .*//; s/-//g; p;}' StockData/$_stockCode.html.org)
_dateStart=${_dateStart:-19700101} 
_dateEnd=${_dateEnd:-$(date "+%Y%m%d")}

#get history data
if ((_cmdCode & (_cmdCodeDownload | _cmdCodeUpdate) )) ; then
    if [[ $_dateStart -ge $_dateEnd ]] ; then
        echo "*[$_stockCode]fresh meat, fresh milk" >&2
        echo $_dateStart $_dateEnd
    else
        echo "*[$_stockCode]update history data" >&2
        _timeStampReq=$(date '+%Y-%m-%d %H:%M:%S')
        _dataRcvd=$(
            curl -f http://quotes.money.163.com/service/chddata.html?code=${_stockCode}\&start=$_dateStart\&end=$_dateEnd 2>/dev/null |
            iconv -f GBK -t utf8 |
            sed -n '$d; 2,${ s/ //g; s/,,,/ 0 0 /g; s/,,/ 0 /g; s/,/ /g; s/None/0/g; p; }' | 
            awk '($4>0){print}' |
            tac
        )
        echo "[$_timeStampReq] $_dataRcvd" >> .curl
        echo "*[$_stockCode]copy history data to StockData/$_stockCode.html.org" >&2
        echo "$_dataRcvd" >> StockData/$_stockCode.html.org 2>/dev/null
        echo "*[$_stockCode]packing StockData/$_stockCode.html.org to StockData/${_stockCode:0:6}-.package.html.org" >&2
        sed -i'' "/'${_stockCode:1}/d" StockData/${_stockCode:0:6}-.package.html.org 2>/dev/null
        cat StockData/$_stockCode.html.org >> StockData/${_stockCode:0:6}-.package.html.org
    fi
fi

#prepare to start a task to get hot data
if ((_cmdCode & _cmdCodeHotData)); then
    _lastDate=$(sed -n '${s/ .*$//;s/-//g;p;}' StockData/$_stockCode.html.org)
    _lastDate=${_lastDate:-19700101}
    _crntDate=$(date "+%Y%m%d")
    [[ $_lastDate -ge $_crntDate ]] && :>StockData/$_stockCode.html.org.hot && echo "*[$_stockCode]no need to update hot data" >&2 && exit 0

    echo "*[$_stockCode]update hot data" >&2
    _newdate=${_lastDate:0:4}-${_lastDate:4:2}-${_lastDate:6}
    [[ ${_stockCode:0:1} == 0 ]] && _codeSina=sh${_stockCode:1} || _codeSina=sz${_stockCode:1}

    [[ $_keepRefresh == true ]] && 
        echo "*[$_stockCode]start a task to retieve hot data" >&2 || 
        echo "*[$_stockCode]copy hot data to StockData/$_stockCode.html.org.hot" >&2

    #before start a task to get hot data, we need set a trap to receive the message from the task.
    trap "doExit 0" SIGUSR2 

    #start the task
    _dataRcvdLast=$(tail -n 1 StockData/$_stockCode.html.org.hot 2>/dev/null)
    while (true)
    do
        # set a trap for this sub-shell
        [[ -z $_trapIsOk ]] && trap " doExit 2 " SIGINT SIGTERM SIGQUIT && _trapIsOk=1

        _timeStampReq=$(date '+%Y-%m-%d %H:%M:%S')
        _dataRcvd=$(
            curl -f http://hq.sinajs.cn/list=${_codeSina} 2>/dev/null |
            iconv -f GBK -t utf8 |
            sed -n 's/ //g;s/^.*="//;s/"\;$//;s/,/ /g;p' |
            awk '{ print $31,"'\'${_stockCode:1}'",$1,$4,$5,$6,$2,$3,$4-$3,100.0*($4-$3)/$3,0,$9,$10,0,0,0,$32 }'
        )

        echo "[$_timeStampReq] $_dataRcvd" >> .curl

        # ignore invalid data, save to xxx.hot, send a message to the dispaly_process
        if [[ $(echo "$_dataRcvd" | awk '{if($1~"'$_newdate'" || $4<=0){print 0;} else{print $12 * $13;} }') != 0 &&
              ${_dataRcvd% *} != ${_dataRcvdLast% *}  &&
              ${_dataRcvd##* } > ${_dataRcvdLast##* } ]]; then
            echo "$_dataRcvd" >> StockData/$_stockCode.html.org.hot
            _dataRcvdLast=$_dataRcvd
            sendSigToDispProc $_stockCode
        else
            touch StockData/$_stockCode.html.org.hot
        fi

        [[ $_keepRefresh == true ]] && (kill -s SIGUSR2 $$ ; sleep 15) || break
    done&

    #stay here, wait child processed quit (if $_keepRefresh is "true", wait child proecss send out the message:SIGUSR2)
    wait && doExit 1

fi
 
doExit 0

#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#how to get quick report 
#_page=xxx  curl -f "http://datainfo.hexun.com/wholemarket/html/yjkb.aspx?data_type=fld_released_date&page=$_page&tag=2"
#
#how to get history data
#http://quotes.money.163.com/service/chddata.html?code=${_val}&start=$(date "+%Y%m%d")&end=20150911&fields=TCLOSE;HIGH;LOW;TOPEN;LCLOSE;CHG;PCHG;VOTURNOVER;VATURNOVER 
#(1)日期,(2)股票代码,(3)名称,(4)收盘价,(5)最高价,(6)最低价,(7)开盘价,(8)前收盘,(9)涨跌额,(10)涨跌幅,(11)换手率,(12)成交量,(13)成交金额,(14)总市值,(15)流通市值,(16)成交笔数
#
#how to get current data
#http://hq.sinajs.cn/list=sh600151,sz000830,s_sh000001,s_sz399001,s_sz399106,s_sz399107,s_sz399108,sz002230
#var hq_str_sh600151="航天机电,8.040,8.030,7.920,8.040,7.890,7.920,7.930,5309239,42224730.000,33600,7.920,103461,7.910,137000,7.900,77400,7.890,98000,7.880,50800,7.930,45000,7.940,24700,7.950,47004,7.960,21000,7.970,2017-12-15,10:41:25,00";
#注：
#上证指数（指数名称）,2289.791（当前点数）,-16.065（涨跌额）,-0.70（涨跌幅度）,599419（总手）,5529858（成交金额）";
#1 "航天机电,名称
#2 7.08,今开
#3 7.09,昨收
#4 6.95,当前
#5 7.08,今日最高
#6 6.90,今日最低
#7 6.95,竞买价，即买一报价
#8 6.96,竞卖价，即卖一报价
#9 4368014,成交的股票数量，应除以100
#10 30484831,成交金额，单位为元
#11 2900 买一申请股数（29手），
#12 6.95  买一报价
#13 5700 买二申请
#14 6.94  买二报价
#15 11688  买三申请，
#166.93  买三报价  
#17 19700  买四申请，
#18 6.92  买四报价  
#19 28200  买五申请，
#20 6.91  买五报价  
#21 700  卖一申请，
#22 6.96  卖一报价  
#23 6000  卖二申请，
#24 6.97  卖二报价  
#25 26600  卖三申请，
#26 6.98  卖三报价  
#27 21701  卖四申请，
#28 6.99  卖四报价  
#29 104259  卖五申请，
#30 7.00  卖五报价  
#31 2012-06-12  日期  
#32 15:03:05 时间  
#set +x
