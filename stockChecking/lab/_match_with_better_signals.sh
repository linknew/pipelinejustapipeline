#! /bin/bash

Usage()
{
    echo -ne "
    Usage:
        $(basename $0) <seg_data> [-|+]<fix> <YYY-MM-DD>

    Examples:
        $(basename $0) .t3.seg.lvl3  0              # get today's better signal stocks from .t3.seg.lvl4
        $(basename $0) .t3.seg.lvl3 -1              # get tomorrow's worse signal stocks from .t3.seg.lvl4
        $(basename $0) .t3.seg.lvl3 +2              # get the day after tomorrow's high risk signal stocks
        $(basename $0) .t3.seg.lvl3  0  2026-02-10  # get 2026-02-10's better signal stocks 
        $(basename $0) .t3.seg.lvl3  0  2026-02-.*  # get 2026-02's better signal stocks

    " >&2
}

seg_data=$1
fix=${2:-0}                         #@ 0:today 1:tomorrow 2:after_tomorrow ...
today=${3:-$(date +%Y-%m-%d)}
today=$(echo $today | sed 's/\./\\S/g')

#better_signals="
#[1k<5k<22k<66k<264k<132k]-4_[1k<5k<22k<66k<264k<132k]-5_[5k<1k<22k<66k<264k<132k]
#[1k<5k<264k<22k<132k<66k]_[1k<5k<264k<22k<132k<66k]-1_[5k<1k<264k<22k<132k<66k]
#[1k<5k<22k<264k<132k<66k]-1_[1k<5k<22k<264k<132k<66k]-2_[5k<1k<22k<264k<132k<66k]       #@+1145.97      13      3       0.77
#[1k<5k<22k<66k<264k<132k]-4_[5k<1k<22k<66k<264k<132k]_[5k<1k<22k<66k<264k<132k]-1       #@+2551.80      21      11      0.48
#[264k<1k<5k<132k<22k<66k]-2_[264k<1k<5k<132k<22k<66k]-3_[264k<1k<5k<132k<22k<66k]-4     #@+1255.45      22      14      0.36
#"

better_signals="
#[1k<5k<22k<264k<132k<66k]_[1k<5k<22k<264k<132k<66k]-1_[1k<5k<22k<264k<132k<66k]-2_[5k<1k<22k<264k<132k<66k]         #+15261.59  13  5  0.62
#[1k<5k<22k<66k<264k<132k]-3_[1k<5k<22k<66k<264k<132k]-4_[1k<5k<22k<66k<264k<132k]-5_[5k<1k<22k<66k<264k<132k]       #+10847.42  11  1  0.91
#
#[264k<1k<5k<132k<22k<66k]-1_[264k<1k<5k<132k<22k<66k]-2                                                             #+14402.59   208   102        0.51
[1k<5k<22k<264k<66k<132k]-2_[1k<5k<22k<264k<66k<132k]-3_[1k<5k<22k<264k<66k<132k]-4_[1k<5k<22k<264k<66k<132k]-5_[1k<5k<22k<264k<66k<132k]-6_[1k<5k<22k<264k<66k<132k]-7     #+10767.61  9  3  0.67 .better.signals..t22.segData.lvl6.all.2016
[0]_[-7?]                 #.better.signals.from.top.566.lst-dur5.lvl2.2025:[0]_[-7?]        28113.20    53     20         0.62
"

worse_signals="
[1k<5k<22k<264k<66k<132k]-3_[5k<1k<22k<264k<66k<132k]_[5k<1k<22k<264k<66k<132k]-1_[5k<1k<22k<264k<66k<132k]-2       #-1032.86   5   3  0.40
[264k<132k<1k<5k<22k<66k]-1_[264k<132k<5k<1k<22k<66k]_[264k<132k<5k<1k<22k<66k]-1_[264k<132k<1k<5k<22k<66k]         #-102.28    10  4  0.60
#
[264k<132k<5k<1k<22k<66k]-2_[264k<132k<1k<5k<22k<66k]   #-1947.96    12    7          0.42.dur3.better.signals.2011lvl2
[66k<22k<5k<1k<132k<264k]-4_[66k<22k<1k<5k<132k<264k]   #-1188.66    5     4          0.20.dur3.better.signals.2020lvl2
#
[66k<22k<5k<1k<132k<264k]_[66k<22k<5k<1k<132k<264k]-1_[66k<22k<5k<1k<132k<264k]-2_[66k<22k<5k<1k<132k<264k]-3_[66k<22k<5k<1k<132k<264k]-4_[66k<22k<1k<5k<132k<264k]     #-10246.83    4    4          0.00.better.signals.from.top.566.lst-dur22.lvl6.2011
[264k<132k<66k<22k<1k<5k]-1_[264k<132k<66k<22k<1k<5k]-2_[264k<132k<66k<22k<1k<5k]-3_[264k<132k<66k<22k<1k<5k]-4_[264k<132k<66k<22k<1k<5k]-5_[264k<132k<66k<22k<5k<1k]   #-10511.53    29   20         0.31.better.signals.from.top.566.lst-dur22.lvl6.2019
[264k<132k<66k<22k<1k<5k]-1_[264k<132k<66k<22k<1k<5k]-2_[264k<132k<66k<1k<22k<5k]_[264k<132k<66k<1k<22k<5k]-1_[264k<132k<66k<1k<22k<5k]-2_[264k<132k<66k<1k<5k<22k]     #-1016.80     3    2          0.33.better.signals.from.top.566.lst-dur22.lvl6.2016
[1k<5k<22k<132k<66k<264k]-1_[1k<5k<22k<132k<66k<264k]-2_[1k<5k<22k<132k<66k<264k]-3_[1k<5k<22k<132k<66k<264k]-4_[5k<1k<22k<132k<66k<264k]_[1k<5k<22k<132k<66k<264k]     #-1122.71     4    1          0.75.better.signals.from.top.566.lst-dur22.lvl6.2014
"

high_risk_signals="
#[1k<5k<22k<66k<132k<264k]-4_[5k<1k<22k<66k<132k<264k]_[5k<22k<1k<66k<132k<264k]_[5k<22k<1k<66k<132k<264k]-1         #61684.62   26    9          0.65
#[1k<5k<22k<66k<132k<264k]-1_[1k<5k<22k<66k<132k<264k]-2_[1k<5k<22k<66k<132k<264k]-3_[5k<1k<22k<66k<132k<264k]       #37432.57   113   34         0.70
#[1k<5k<22k<66k<132k<264k]-2_[1k<5k<22k<66k<132k<264k]-3_[5k<1k<22k<66k<132k<264k]_[5k<1k<22k<66k<132k<264k]-1       #37485.46   90    26         0.71
#[5k<1k<22k<66k<132k<264k]-1_[5k<1k<22k<66k<132k<264k]-2_[5k<1k<22k<66k<132k<264k]-3_[5k<22k<1k<66k<132k<264k]       #65934.97   77    30         0.61
#[5k<1k<22k<66k<132k<264k]_[5k<1k<22k<66k<132k<264k]-1_[5k<22k<1k<66k<132k<264k]_[5k<22k<1k<66k<132k<264k]-1         #59358.65   98    37         0.62
#
#[264k<132k<66k<22k<1k<5k]_[264k<132k<66k<22k<1k<5k]-1_[264k<132k<66k<22k<1k<5k]-2_[264k<132k<66k<22k<1k<5k]-3        #176391.61  835   394        0.53
#[264k<132k<66k<22k<5k<1k]_[264k<132k<66k<22k<5k<1k]-1_[264k<132k<66k<22k<5k<1k]-2_[264k<132k<66k<22k<5k<1k]-3        #333514.14  1962  987        0.50
#[1k<5k<22k<66k<132k<264k]-1_[1k<5k<22k<66k<132k<264k]-2_[1k<5k<22k<66k<132k<264k]-3_[1k<5k<22k<66k<132k<264k]-4      #302686.22  1051  506        0.52
#
[264k<132k<66k<22k<5k<1k]-1_[264k<132k<66k<22k<5k<1k]-2_[264k<132k<66k<22k<5k<1k]-3_[264k<132k<66k<22k<5k<1k]-4_[264k<132k<66k<22k<5k<1k]-5_[264k<132k<66k<22k<5k<1k]-6        #1231324.91  727   312        0.57
[264k<132k<66k<22k<5k<1k]_[264k<132k<66k<22k<5k<1k]-1_[264k<132k<66k<22k<5k<1k]-2_[264k<132k<66k<22k<5k<1k]-3_[264k<132k<66k<22k<5k<1k]-4_[264k<132k<66k<22k<5k<1k]-5          #1568977.48  1013  440        0.57
"

[[ $1 == -h || $1 == --help ]] && { Usage; exit; }

if [[ ${fix:0:1} == '-' ]]; then
    fix=${fix:1};
    price_trend="\033[32mBearish\033[0m";
    signals="$worse_signals";
elif [[ ${fix:0:1} == '+' ]]; then
    fix=${fix:1};
    price_trend="\033[31mBullish\033[0m";
    signals="$high_risk_signals";
else
    price_trend="\033[34mGood\033[0m";
    signals="$better_signals";
fi

sig_pats=$(echo "$signals" | sed 's/[ \t]*#.*//; /^[ \t]*$/d; s/\(_[^_]*\)\{'$fix'\}$//; s/$/ /;')
echo -en "\n* match $today's [$price_trend] stocks in $seg_data with\n\n$sig_pats\n\n===============\n\n" >&2
grep -Ff <(echo "$sig_pats") $seg_data  |
    grep " $today ....[^-]"             |
    awk '{ print $NF, "#"$1, $9;}'      | #cat - ; exit
    sed 's,^.*/, ,; s,.raw,,;'          |
    column -t


