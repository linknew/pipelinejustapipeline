#! /bin/bash

. comm.lib

for i in "$@"
do
    [[ $i == '--help' ]] && 
    echo "
    Usage:
        $0 [--help] [--print] [--printLastOne] [--showDaily] [--silent] [--classFile=classFilename] [--winOrder=N] [--fixType=F/B/N] stockCode
        " >&2 &&
    exit 0

    [[ $i == '--print' ]] && _print='--print' && _silent=1 && continue
    [[ $i == '--printLastOne' ]] && _print='--printLastOne' && _silent=1 && continue
    [[ $i == '--showDaily' ]] && _showDaily=1 && continue
    [[ $i == '--silent' ]] && _silent=1 && continue
    [[ ${i%%=*} == '--fixType' ]] && _fixType=${i##*=} && continue
    [[ ${i%%=*} == '--classFile' ]] && _classFile=${i##*=} && continue
    [[ ${i%%=*} == '--winOrder' ]] && _winOrder=${i##*=} && continue
    [[ -z ${i/--*/} ]] && showErr "unknown option:$i\n" >&2 && exit 0
    _stockCode=$i
done

doExit()
{
    rm -rf .t.$$ 2>/dev/null
    [[ $1 != 0 ]] && kill -s SIGQUIT $PPID
    exit $1
}

trap "doExit 1" SIGTERM SIGINT

[[ $_winOrder == '--winOrder' ]] && showErr "must specify order number for --winOrder, for example --winOrder=3" && doExit 0

_fixType=${_fixType:=B}
_classFile=${_classFile:='stock.list.class.tmp'}
_stockName=$(grep $_stockCode stock.list | sed 's/^.* //') 
_stockFile=.t.$$ && grep "'${_stockCode:1}" StockData/${_stockCode:0:6}-.package.html.org 2>/dev/null >.t.$$

while true 
do
    showMsg "\n*[$_stockCode]$_stockName: showStock $_print --classFile=$_classFile\n" >&2
    [[ -z $_silent ]] && echo save result to $_classFile >&2
    [[ -f $_stockFile ]] && _hisCnt=$(wc -l $_stockFile | awk '{print $1}') || _hisCnt=0
    [[ -f StockData/$_stockCode.html.org.hot ]] && _hotCnt=$(wc -l StockData/$_stockCode.html.org.hot| awk '{print $1}') || _hotCnt=0

    ./stockChecking     \
        $_print         \
        ${_fixType:+--fixType $_fixType}    \
        ${_showDaily:+--showDaily}      \
        ${_winOrder:+--winOrder ${_winOrder}}     \
        ${_stockName:-"NoName"}     \
        $_stockCode     \
        $_stockFile \
        $_hisCnt    \
        StockData/$_stockCode.html.org.hot   \
        $_hotCnt

    if [[ -z $_silent ]] ; then
        echo "
        please select a class for this stock
        1.new stock
        2.need observe(up)
        3.need observe(down)
        4.need observe(washing)
        5.wait to up
        6.need focus
        r.replay
        x.others" >/dev/tty
        read -s -n1 x </dev/tty
        echo "---" >/dev/tty
        [[ $x == r ]] && continue
        echo $_stockCode $_stockName '['$x']   @['$(date "+%Y-%m-%d %H:%M:%S")']' >> $_classFile
    fi

    break
done

doExit 0

