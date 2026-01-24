#! /bin/bash
PID=$$

#@ this scripte may copy to a locally place, we cannot
#@ use $(dirname $0)/../lib/comm.lib to find the lib
#@ let find comm.lib from the $PATH
for i in $(echo $PATH | tr ':' ' '); do
    if [[ -r $i/../lib/comm.lib ]]; then
        source $i/../lib/comm.lib
        source_ok=1
        break
    fi
done;
[[ source_ok -ne 1 ]] && { echo "** cannot find lib/comm.lib" >&2; exit -1; }

declare -ri _cmdCodeDownload=$((1<<0))
declare -ri _cmdCodeUpdate=$((1<<1))
declare -ri _cmdCodeHotData=$((1<<2))
declare -ri _cmdCodeHotDataPeek=$((1<<3))
declare -i  _cmdCode=0

_keepRefresh=false
_opt=''
_owner=$PPID

doExit()
{
    # $1 is exitCode

#   if [[ -n $hot_data_pid ]]; then
#       kill -0 $hot_data_pid && kill -9 $hot_data_pid
#   fi

    if [[ $1 == 0 ]] ; then
        : main task exit
        rm -rf ~/StockData/$_stockCode.html.org 2>/dev/null
    elif [[ $1 == 1 ]] ; then
        : sub task exit, main
        rm -rf ~/StockData/$_stockCode.html.org 2>/dev/null
    elif [[ $1 == 2 ]] ; then
        : exit when interruptted
        rm -rf ~/StockData/$_stockCode.html.org 2>/dev/null
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
    _pids=`ps aux | awk '(/stockChecking .* '$1'/ && !/awk/){print $2}'`
    for _i in $_pids
    do
        echo "-----send SIGUSR1 to $_i" > /dev/tty
        kill -SIGUSR1 $_i
    done
    return 0
}

login()
{
    getHis.baostock.sh -login $_owner
    return $?
}

logout()
{
    getHis.baostock.sh -logout $_owner
    return $?
}

getHis()
{
    [[ ( ${#1} -ne 6 && ${#1} -ne 7 ) || ${#2} -ne 8 || ${#3} -ne 8 ]] &&
        echo "*Error, getHis code_6or7 startYYYYMMDD endYYYYMMDD" >&2 &&
        exit

    local code=$1
    local dateStart=$2
    local dateEnd=$3

    if [[ ${#code} -eq 6 ]]; then
        #@ 0xxxxxx for shanghai, 1xxxxxx for shenzheng
        [[ ${1:0:1} -eq 6 || ${1:0:1} -eq 9 ]] && code=0${code} || code=1${code};
    fi

#@  get history data from **baostock**
    getHis.baostock.sh $code $dateStart $dateEnd $_owner

#@  get history data from **tushare**
#   getHis.tushare.sh $code $dateStart $dateEnd

#@  get history data from **akshare**
#   getHis.akshare.sh $code $dateStart $dateEnd

#@  get history data from **163**
#   getHis.163.sh $code $dateStart $dateEnd

}


#
#
#start the main routing
#----------------------

#@ login and logout
[[ $1 == --login ]] && { login $2; exit $?; }
[[ $1 == --logout ]] && { logout $2; exit $?; }

#parameters checking
for i in "$@"
do
    [[ $i == "--help" ]] &&
    echo "
    Usage:
        $(basename $0) --update[|--download ] [--owner=pid] [--dateStart=YYYYMMDD] [--dateEnd=YYYYMMDD] stockCode_7
        $(basename $0) --hotData[|--hotDataPeek] [--owner=pid] [--dateStart=YYYYMMDD] [--dateEnd=YYYYMMDD] stockCode_7
        $(basename $0) --auto [--owner=pid] [--dateStart=YYYYMMDD] [--dateEnd=YYYYMMDD] stockCode_7

        --download: download history data (remove the old data first)
        --update: same as --download. Do not remove old data
        --hotData: keep refreshing current data
        --hotDataPeek: get current data, only have a peek, do not keep refreshing
        --dateStart: get the data from the dateStart
        --dateEnd: get the data till teh dateEnd
        --owner: the master, the caller, the manager
        --auto: --update + --hotData.

    Default:
        --auto
    " >&2 && exit 0

    [[ $i == "--download" ]] && ((_cmdCode|=_cmdCodeDownload)) && continue
    [[ $i == "--update" ]] && ((_cmdCode|=_cmdCodeUpdate)) && continue
    [[ $i == "--hotData" ]] && ((_cmdCode|=_cmdCodeHotData)) && _keepRefresh=true && continue
    [[ $i == "--hotDataPeek" ]] && ((_cmdCode|=_cmdCodeHotDataPeek)) && continue
    [[ $i == "--auto" ]] && ((_cmdCode|=(_cmdCodeUpdate | _cmdCodeHotData) )) && _keepRefresh=true && continue
    [[ ${i%%=*} == "--dateStart" ]] && _dateStart=${i##*=} && continue
    [[ ${i%%=*} == "--dateEnd" ]] && _dateEnd=${i##*=} && continue
    [[ ${i%%=*} == "--owner" ]] && _owner=${i##*=} && continue
    [[ ${i:0:1} == '-' ]] && showErr "unknown option $i\n" && exit 0
    _stockCode=$i
done

#before starting main routine, set a trap to process SIGINT SIGTERM and etc
trap " doExit 2" SIGINT SIGTERM SIGQUIT

#extract current stock origin data
grep "'${_stockCode:1}" ~/StockData/${_stockCode:0:6}-.package.html.org 2>/dev/null > ~/StockData/$_stockCode.html.org

((_cmdCode == 0 )) && _cmdCode=$((_cmdCodeUpdate|_cmdCodeHotData)) && _keepRefresh=true
((_cmdCode & _cmdCodeDownload)) && rm -rf ~/StockData/$_stockCode.html.org{,.hot} 2>/dev/null
[[ -z $_dateStart && -f ~/StockData/$_stockCode.html.org ]] && _dateStart=$(sed -n '${s/ .*//; s/-//g; p;}' ~/StockData/$_stockCode.html.org)
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

        #get history data
        _dateStartNext=$(getActualDate +1 $_dateStart | sed 's/-//g')
        _dataRcvd=$(getHis.baostock.sh $_stockCode $_dateStartNext $_dateEnd $_owner)

        echo "[$_timeStampReq] $_dataRcvd" >> .curl
        echo "*[$_stockCode]copy history data to ~/StockData/$_stockCode.html.org" >&2
        echo "$_dataRcvd" >> ~/StockData/$_stockCode.html.org 2>/dev/null
        echo "*[$_stockCode]packing ~/StockData/$_stockCode.html.org to ~/StockData/${_stockCode:0:6}-.package.html.org" >&2
        sed -i'' "/'${_stockCode:1}/d" ~/StockData/${_stockCode:0:6}-.package.html.org 2>/dev/null
        cat ~/StockData/$_stockCode.html.org >> ~/StockData/${_stockCode:0:6}-.package.html.org
    fi
fi

#prepare to start a task to get hot data
if ((_cmdCode & (_cmdCodeHotData|_cmdCodeHotDataPeek) )); then
    _lastDate=$(sed -n '${s/ .*$//;s/-//g;p;}' ~/StockData/$_stockCode.html.org)
    _lastDate=${_lastDate:-19700101}
    _crntDate=$(date "+%Y%m%d")
    [[ $_lastDate -ge $_crntDate ]] && {
        :>~/StockData/$_stockCode.html.org.hot
        echo "*[$_stockCode]no need to update hot data" >&2
        exit 0
    }

    echo "*[$_stockCode]update hot data" >&2
    _newdate=${_lastDate:0:4}-${_lastDate:4:2}-${_lastDate:6}

    [[ $_keepRefresh == true ]] &&
        echo "*[$_stockCode]start a task to retieve hot data" >&2 ||
        echo "*[$_stockCode]copy hot data to ~/StockData/$_stockCode.html.org.hot" >&2

    #start task
    #main routine shall wait task start
    #after started, task sends SIGUSR2 to main routine
    #set a trap to recieve SIGUSR2
    trap ":" SIGUSR2

    _dataRcvdLast=$(tail -n 1 ~/StockData/$_stockCode.html.org.hot 2>/dev/null)
    while (true)
    do
#       # set a trap for this sub-shell
#       [[ -z $_trapIsOk ]] && trap " doExit 2 " SIGINT SIGTERM SIGQUIT && _trapIsOk=1

        _timeStampReq=$(date '+%Y-%m-%d %H:%M:%S')
#       _dataRcvd=$(getHot.sina.sh $_stockCode)
        _dataRcvd=$(getHot.eastmoney.sh $_stockCode)

        echo "[$_timeStampReq] $_dataRcvd" >> .curl

        # ignore invalid data, save to xxx.hot, send a message to the dispaly_process
        if [[ $(echo "$_dataRcvd" | awk '{if($1~"'$_newdate'" || $4<=0){print 0;} else{print $12 * $13;} }') != 0 &&
              ${_dataRcvd% *} != ${_dataRcvdLast% *}  &&
              ${_dataRcvd##* } > ${_dataRcvdLast##* } ]]; then
            echo "$_dataRcvd" >> ~/StockData/$_stockCode.html.org.hot
            _dataRcvdLast=$_dataRcvd
            sendSigToDispProc $_stockCode
        else
            touch ~/StockData/$_stockCode.html.org.hot
        fi

        # say ok to parent
        [[ $_keepRefresh == true ]] && { kill -s SIGUSR2 $PID; sleep 15; } || break
    done& hot_data_pid=$!

    #stay here, wait child processed quit (if $_keepRefresh is "true", wait child proecss send out the message:SIGUSR2)
    wait
    doExit 1

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
