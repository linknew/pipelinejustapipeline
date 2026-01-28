#! /bin/bash

Usage()
{
    echo -ne "
    Usage: $(basename $0)  <year>  [ <seg_data>  <list>  [<output_prefix>] ]

        year,           in which year,      4 digitals
        seg_data,       in which database,  default ./gold/.t3.segData.lvl4.all.forword
        list,                               default ./top566.lst
        output_prefix,                      default 'l4'
    \n"
}

[[ $1 == --help || $1 == -h ]] && { Usage; exit; }
[[ $# -lt 1 ]] && { Usage; exit; }

year=$1
forecast_data=${2:-/home/limin/forecast/gold/.t3.segData.lvl4.all.forword}
top_value=${3:-top566.lst}
output_prefix=${4:-lvl4}
better_signals_org=.t3.$year$output_prefix
better_signals=.dur3.better.signals.$year$output_prefix

echo "* gen $better_signals_org with $forecast_data"
getBetterSignals.sh 1 0.001 0.0003 $year-01-01 $((year+1))-01-01 $forecast_data $top_value > $better_signals_org
echo "* gen $better_signals from $better_signals_org"
grep '^\['  $better_signals_org  | column -t | sort -k2n > $better_signals

