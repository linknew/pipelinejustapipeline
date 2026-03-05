#! /bin/bash

Usage()
{
    echo -ne "
    Usage: $(basename $0)  <year>  [ <seg_data>  <amp_idx>  <sig_list>  [<tag>] ]

        year,           in which year,      4 digitals
        seg_data,       in which database,  default ./gold/.t3.segData.lvl4.all.forword
        sig_list,                           default ./top.566.lst
    \n"
}

[[ $1 == --help || $1 == -h ]] && { Usage; exit; }
[[ $# -lt 1 ]] && { Usage; exit; }

year=$1
segData=${2:-/home/limin/forecast/gold/.t3.segData.lvl4.all.forword}
ampIdxInSegData=${3:-6}         #@ ampDur
#    ampIdxInSegData=${3:-2}    #@ ampUpCeiling
#    ampIdxInSegData=${3:-3}    #@ ampUpFloor
signal_list=${4:-top.566.lst}
tag=${tag:-$(basename $segData | sed 's/[^0-9]*\([0-9]\+\)[^0-9]*\([0-9]\+\).*/dur\1.lvl\2/' )}
better_signals_org=.better.signals.from.$signal_list${tag:+-$tag}.$year.org
better_signals=.better.signals.from.$signal_list${tag:+-$tag}.$year

echo "* gen $better_signals_org with $segData"
getBetterSignals.sh 1 0.001 0.0003 $year-01-01 $((year+1))-01-01 $segData $ampIdxInSegData $signal_list > $better_signals_org
echo "* gen $better_signals from $better_signals_org"
grep '^\['  $better_signals_org  | column -t | sort -k2n > $better_signals

