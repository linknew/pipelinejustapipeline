#! /bin/bash


for i in $@; do
    case $i in 
        -gen) gen_index_data=true;;
        -group=*) group=${i#*=};;
        -*) echo "** unknown option: $i"; exit;;
    esac
done


#@ 7code list
list=$(echo '
0000032  #上证能源  2003-12-31  1000  30
0000033  #上证材料  2003-12-31  1000  50
0000034  #上证工业  2003-12-31  1000  50
0000035  #上证可选  2003-12-31  1000  50
0000036  #上证消费  2003-12-31  1000  30
0000037  #上证医药  2003-12-31  1000  49
0000038  #上证金融  2003-12-31  1000  30
0000039  #上证信息  2003-12-31  1000  50
0000040  #上证通信  2003-12-31  1000  33
0000041  #上证公用  2003-12-31  1000  30
' | sed '/^[ \t]*$/d'
)
from=2009-01-09; to=2999-12-31


if  [[ $gen_index_data == true ]]; then
    [[ ! -d index_data ]] && { mkdir index_data || { echo "** error $?"; exit; } }
    playStockList.sh --update --print --output=index_data/{} <(echo "$list")
fi


data=.drawline.t
cmd=$(
    echo -en "paste "
    for i in $(echo "$list" | sed 's,^.,index_data/,; s/#.*//'); do
        echo -en "<(awk -v from=$from -v to=$to '(\$18>=from && \$18<to){print \$2}'  $i) "
    done
    echo     -en "<(awk -v from=$from -v to=$to '(\$18>=from && \$18<to){print \$18}' $i) "
); #echo "$cmd" | sed 's/<(/\n&/g'; exit
eval $cmd | sed 's/\(\s[0-9]\+\)-\([0-9]\+\)-\([0-9]\+\)\s*$/\1\2\3/' | column -t > $data; #exit;


#drawLines stockCode filename linesNum linesLength [--help] [--group=NumOfGrp1,NumOfGrp2,...] [--showlines=L1,L2,...] [--focus=N] [--scale=N]
n_lines=$(awk 'END{print NF}' $data)
length=$(awk  'END{print NR}' $data)
echo "$list" | nl
drawLines dummy_code $data $n_lines $length \
    --showlines=$( for ((i=1;i<$n_lines;i++)) { [[ $i -eq 1 ]] && printf $i || printf ",%d" $i; } ) \
    --scale=1   \
    --focus=2   \
    --group=${group:-$((n_lines-1)),1}

