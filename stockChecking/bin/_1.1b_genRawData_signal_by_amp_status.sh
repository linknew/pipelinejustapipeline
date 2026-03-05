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

        open_ = $24+0;
        close_ = $2+0;
        high_ = $25+0;
        low_ = $26+0;
        amp_ = $4+0;
        ampP_ = ($25-$26)/$27*100;

        #@ rate
        if((amp_<=0 && amp_>-5)) {
            rate = "-0";
        }
        else if((amp_<=-5 && amp_>-6)) {
            rate = amp_;
        }
        else if((amp_<=-6 && amp_>-7)) {
            rate = amp_;
        }
        else if((amp_<=-7 && amp_>-8)) {
            rate = amp_;
        }
        else if((amp_<=-8 && amp_>-9)) {
            rate = amp_;
        }
        else if((amp_<=-9)) {
            rate = amp_;
        }
        else if((amp_>0 && amp_<5)) {
            rate = 1;
        }
        else if((amp_>=5 && amp_<6)) {
            rate = amp_;
        }
        else if((amp_>=6 && amp_<7)) {
            rate = amp_;
        }
        else if((amp_>=7 && amp_<8)) {
            rate = amp_;
        }
        else if((amp_>=8 && amp_<9)) {
            rate = amp_;
        }
        else if((amp_>=9)) {
            rate = amp_;
        }
        else {
            rate = -100;
        }

        #@ strength
#strength = amp_>-5&&amp_<5? "" : ampP_<7? "a" : "A";
        strength="";
#       strength = ampP_<7? "A<7" : ampP_<8? "A<8" : ampP_<9? "A<9" : "A>=9";

        #@ sharp #@ 11xx:一字板, 12xx:T, 13xx:倒T, 14xx:光头光脚, 15xx:光脚光头, 16xx:振幅不低于7%
        sharp = amp_>-5&&amp_<5? "" : high_==low_? "-" : open_==close_ && close_==high_? "T" : open_==close_ && close_==low_? "t" : open_==low_ && close_==high_? "^" : open_==high_ && close_==low_? "$" : "?";
#       sharp = amp_>-5&&amp_<5&&ampP_<7? "Sx" : high_==low_? "S-" : open_==close_ && close_==high_? "ST" : open_==close_ && close_==low_? "St" : open_==low_ && close_==high_? "S^" : open_==high_ && close_==low_? "S$" : "S?";


#        if((amp_>-5 && amp_<5)) {
#            key = key>0;
#        }
#        else if(amp_>0) {
#            key += high_==low_? 1100 : open_==close_ && close_==high_? 1200 : open_==close_ && close_==low_? 1300 : open_==low_ && close_==high_? 1400 : open_==high_ && close_==low_? 1500 : ampP_>=5? 1600 : 0;
#        }
#        else if(amp_<0) {
#            key -= high_==low_? 1100 : open_==close_ && close_==high_? 1200 : open_==close_ && close_==low_? 1300 : open_==low_ && close_==high_? 1400 : open_==high_ && close_==low_? 1500 : ampP_>=5? 1600 : 0;
#        }

        #if($18=="2005-04-22") print $18,open_,close_,high_,low_,amp_,ampP_,key> "/dev/tty"
        printf("[%d%s%s] ", rate, strength, sharp);
        print $4,$18,$2,$25,$26,$24,$4,$14,$15,$16,"dummy",28,$29,$30,$31,$32 ;
    }
    '
