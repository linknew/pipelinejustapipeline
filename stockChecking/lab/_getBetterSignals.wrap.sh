year=${1:-2025}
forecast_data=/home/limin/forecast/gold/.t3.segData.lvl3.all.1991.to.2026
top_value=/home/limin/pipelinejustapipeline/stockChecking/TvalueGT87YI.lst

for i in {0,500,1000,1500}; do
    from=$i;
    to=$((from+500));
    better_signals_org=.t.$year.$from.to.$to;
    better_signals=.better.signals.$year.$from.to.$to;
    echo "** gen $better_signals_org with $forecast_data"
    getBetterSignals.sh 1 0.001 0.0003 $year-01-01 $((year+1))-01-01 $forecast_data <(head -n$to $top_value | tail -n500) > $better_signals_org
    echo "** gen $better_signals from $better_signals_org"
    grep '^\['  $better_signals_org  | column -t | sort -k2n > $better_signals
done

