#! /bin/bash

source $(dirname $(readlink -f $0))/../lib/comm.lib

Usage() {
    echo -en "
    Usage:

        $(basename $0) <code> [<pathname>|-]

        --pathname: specify a data file or create from 'playStock.sh --print <<< stock_code'
    " >&2
}

echo -ne "*executing $0($$)\n" >&2
[[ $1 == -h || $1 == --help ]] && Usage && doExit
sourceData=${2:--}

cat $sourceData |
awk '
    #@ do signalization, set to signal_1 if close_price==high_price, otherwise set to signal_0

    BEGIN{
        CONVFMT="%.2f"
        OFMT="%.2f"

        print "#input:"
        print "#(1)stockID, (2)closePrice, (3)power, (4)amplitude, (5)trueAmplitude, (6)rsi6"
        print "#(7)rsi12, (8)rsi24, (9)pwri6, (10)pwri12, (11)pwri24, (12)rsiFuture6, (13)pwriFuture12"
        print "#(14)exchange, (15)volume, (16)value, (17)liveValue, (18)date (19)rsiCustom (20)pwriCustom"
        print "#(21)xcgAvgICustom (22) gEgrData (23) highestAmp (24)open (25)hig (26)low (27)ystdClose"
        print "#(28)5kline (29)22kline (30)66kline (31)132kline (32)264kline (33)avg=1kline=$16/$15"
        print "#output:"
        print "#(1)[signal] amp date cls hig (6)low opn amp xch vol (11)val 1k 5k 22k 66k (16)132k 264k"
    }

    {
        if($1 ~ "#") next ;
        printf("[%d] ", ($2==$25 && $4>9.9)) ;
        print $4,$18,$2,$25,$26,$24,$4,$14,$15,$16,"dummy",28,$29,$30,$31,$32 ;
    }
    '
